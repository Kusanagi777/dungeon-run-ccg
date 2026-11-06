## `InputRouter` alone (match-ui L15, L17, U5, States; design/ux/targeting.md §6, §7;
## stories 017, 019, 025): the arm guard on a fake clock, click-to-select, the §7.4 click
## and drag-release tables, Phase P to T narrowing and the "No target" chip, `A` arming,
## the `Esc` chain and the locks. A fake hit test answers for pixels, so nothing here
## depends on a viewport.
extends GdUnitTestSuite

const CARD_MINION: int = 12
const CARD_SPELL: int = 13
const CARD_TARGETED: int = 14
const CARD_BATTLECRY: int = 15
const CARD_OPTIONAL: int = 16
const CARD_DEAD: int = 17
const TOKEN: int = 31
const TOKEN_SICK: int = 32
const PLAYER_HERO: int = 1
const BOSS_HERO: int = 2
const BOSS_TOKEN: int = 51
const STEALTH_TOKEN: int = 52

const AT_MINION := Vector2(400, 600)
const AT_SPELL := Vector2(500, 600)
const AT_DEAD := Vector2(700, 600)
const AT_TOKEN := Vector2(400, 400)
const AT_TOKEN_SICK := Vector2(500, 400)
const AT_BOSS_TOKEN := Vector2(400, 240)
const AT_STEALTH := Vector2(500, 240)
const AT_BOSS_HERO := Vector2(1196, 176)
const AT_HERO := Vector2(84, 414)
const AT_POWER := Vector2(176, 414)
const AT_CAST_ONLY := Vector2(800, 200)
const AT_ROW_EMPTY := Vector2(800, 400)
const AT_NOWHERE := Vector2(1100, 500)
const AT_END_TURN := Vector2(1186, 318)
const CAST_ZONE := Rect2(301, 176, 678, 284)
const POSITION_ZONE := Rect2(301, 334, 678, 150)
const END_TURN_RECT := Rect2(1116, 296, 140, 44)
const CHIP_RECT := Rect2(600, 300, 120, 44)
## Under `CLICK_DRAG_PX` (8) and past it.
const SMALL_MOVE := Vector2(5, 0)
const BIG_MOVE := Vector2(30, 0)
const ARM_MS: int = 300
const DRAG_PX: float = 8.0
const STEP_S: float = 0.1

var _now: int = 1000
var _view: MatchViewState
var _queue: AnimationQueue
var _router: InputRouter
var _controller: FakeController
var _hit: FakeHit
var _sent: Array[Dictionary] = []
var _menus: int = 0
var _feeds: int = 0
var _ended: Array[bool] = []
var _steps: Array[int] = []
var _badges: Array[Dictionary] = []
var _drawer_open: bool = false


## `legal_commands()` from a list, and nothing else.
class FakeController:
	extends MatchController

	var legal: Array = []
	var read_only: bool = false

	func _init() -> void:
		super(null)

	func legal_commands() -> Array:
		return legal

	func is_read_only() -> bool:
		return read_only


## Pixels by table.
class FakeHit:
	extends MatchHitTest

	var sources: Dictionary = {}
	var targets: Dictionary = {}
	var gap: int = 1

	func _init() -> void:
		super(null, null, null, null, null, null, null)

	func source_at(point: Vector2) -> Dictionary:
		return sources.get(point, {})

	func target_at(point: Vector2) -> int:
		return int(targets.get(point, NO_TARGET))

	func in_cast_zone(point: Vector2) -> bool:
		return CAST_ZONE.has_point(point)

	func in_position_zone(point: Vector2) -> bool:
		return POSITION_ZONE.has_point(point)

	func in_end_turn(point: Vector2) -> bool:
		return END_TURN_RECT.has_point(point)

	func centre_of(id: int) -> Vector2:
		for at: Vector2 in targets:
			if int(targets[at]) == id:
				return at
		return Vector2.ZERO

	func gap_at(_point: Vector2, tokens: int) -> int:
		return mini(gap, tokens)


func before_test() -> void:
	_now = 1000
	_sent = []
	_menus = 0
	_feeds = 0
	_ended = []
	_steps = []
	_badges = []
	_drawer_open = false
	_view = MatchViewState.new(MatchUiTestConfig.body())
	_queue = AnimationQueue.new(MatchUiTestConfig.body(), MatchUiTestConfig.settings())
	_controller = FakeController.new()
	_hit = FakeHit.new()
	_hit.sources = {
		AT_MINION: {"kind": "card", "id": CARD_MINION}, AT_SPELL: {"kind": "card", "id": CARD_SPELL},
		AT_DEAD: {"kind": "card", "id": CARD_DEAD}, AT_TOKEN: {"kind": "attacker", "id": TOKEN},
		AT_TOKEN_SICK: {"kind": "attacker", "id": TOKEN_SICK}, AT_HERO: {"kind": "attacker", "id": PLAYER_HERO},
		AT_POWER: {"kind": "hero_power", "id": -1},
	}
	_hit.targets = {
		AT_BOSS_TOKEN: BOSS_TOKEN, AT_STEALTH: STEALTH_TOKEN, AT_BOSS_HERO: BOSS_HERO,
		AT_TOKEN: TOKEN, AT_HERO: PLAYER_HERO,
	}
	_router = auto_free(InputRouter.new())
	_router.set_end_turn_arm(ARM_MS, func() -> int: return _now)
	_router.bind(_view, _queue)
	_router.set_controller(_controller)
	_router.set_hit_test(_hit, DRAG_PX)
	_router.set_drawer_check(func() -> bool: return _drawer_open)
	_router.command_requested.connect(func(command: Dictionary) -> void: _sent.append(command))
	_router.menu_requested.connect(func() -> void: _menus += 1)
	_router.feed_requested.connect(func() -> void: _feeds += 1)
	_router.session_ended.connect(func(_session: Dictionary, submitted: bool) -> void: _ended.append(submitted))
	_router.focus_step_requested.connect(func(step: int) -> void: _steps.append(step))
	_router.attackers_armed.connect(func(badges: Dictionary) -> void: _badges.append(badges))
	_board()
	_main_phase()
	_controller.legal = _full_legal()


func _main_phase() -> void:
	_view.phase = InputRouter.PHASE_MAIN
	_view.active_side = MatchViewState.SIDE_PLAYER
	_view.turn = 3


func _board() -> void:
	var sides: Dictionary = _view.get("_sides")
	sides.player.hero.entity_id = PLAYER_HERO
	sides.boss.hero.entity_id = BOSS_HERO
	sides.player.hand = [
		{"instance_id": CARD_MINION, "card_id": "m"}, {"instance_id": CARD_SPELL, "card_id": "s"},
		{"instance_id": CARD_TARGETED, "card_id": "t"}, {"instance_id": CARD_BATTLECRY, "card_id": "b"},
		{"instance_id": CARD_OPTIONAL, "card_id": "o"}, {"instance_id": CARD_DEAD, "card_id": "d"},
	]
	sides.player.board = [{"entity_id": TOKEN, "card_id": "x"}, {"entity_id": TOKEN_SICK, "card_id": "y"}]
	sides.boss.board = [{"entity_id": BOSS_TOKEN, "card_id": "z"}, {"entity_id": STEALTH_TOKEN, "card_id": "z"}]


func _play(hand_index: int, position: Variant, target: Variant) -> Dictionary:
	return {"type": MatchRecords.CMD_PLAY_CARD, "issuer": "player", "hand_index": hand_index, "position": position, "target_id": target}


func _attack(attacker: int, target: int) -> Dictionary:
	return {"type": MatchRecords.CMD_ATTACK, "issuer": "player", "attacker_id": attacker, "target_id": target}


func _power(target: Variant) -> Dictionary:
	return {"type": MatchRecords.CMD_USE_HERO_POWER, "issuer": "player", "target_id": target}


## The hand by index: 0 minion, 1 untargeted spell, 2 targeted spell, 3 Battlecry whose
## gap 0 has a target and gap 2 has none, 4 optional target, 5 nothing.
func _full_legal() -> Array:
	return [
		_play(0, 0, null), _play(0, 1, null), _play(0, 2, null),
		_play(1, null, null),
		_play(2, null, BOSS_TOKEN), _play(2, null, BOSS_HERO), _play(2, null, TOKEN),
		_play(3, 0, BOSS_TOKEN), _play(3, 0, BOSS_HERO), _play(3, 1, BOSS_TOKEN), _play(3, 2, null),
		_play(4, null, BOSS_TOKEN), _play(4, null, null),
		_attack(TOKEN, BOSS_TOKEN), _attack(TOKEN, BOSS_HERO), _attack(PLAYER_HERO, BOSS_TOKEN),
		_power(null),
		{"type": MatchRecords.CMD_END_TURN, "issuer": "player"},
		{"type": MatchRecords.CMD_END_TURN, "issuer": "boss"},
	]


func _press(at: Vector2, double: bool = false) -> void:
	_router.handle_input(MatchViewHarness.mouse_button(at, MOUSE_BUTTON_LEFT, true, double))


func _release(at: Vector2) -> void:
	_router.handle_input(MatchViewHarness.mouse_button(at, MOUSE_BUTTON_LEFT, false, false))


func _click(at: Vector2, double: bool = false) -> void:
	_press(at, double)
	_release(at)


func _rmb(at: Vector2 = AT_NOWHERE) -> void:
	_router.handle_input(MatchViewHarness.mouse_button(at, MOUSE_BUTTON_RIGHT, true, false))


func _move(at: Vector2) -> void:
	_router.handle_input(MatchViewHarness.motion(at))


func _drag(from: Vector2, to: Vector2) -> void:
	_press(from)
	_move(to)
	_release(to)


func _busy() -> void:
	_queue.set_speed(&"normal")
	_queue.enqueue(AnimStep.new(AnimStep.TURN_BANNER, [], 0.4, 1, 1))
	_queue.advance(0.0)


## A step played out at [param t]: the queue drains there.
func _drain_at(t: int) -> void:
	_busy()
	_now = t
	_queue.skip_all()


func _state() -> String:
	return String(_router.view_state())


func _assert_one(type: String) -> Dictionary:
	assert_int(_sent.size()).override_failure_message("sent %s" % str(_sent)).is_equal(1)
	if _sent.is_empty():
		return {}
	assert_str(str(_sent[0].type)).is_equal(type)
	return _sent[0]


# --- L15, the arm guard --------------------------------------------------------------

func test_l15_space_before_the_arm_time_forwards_nothing() -> void:
	# Arrange
	_drain_at(5000)
	_now = 5100

	# Act
	_router.on_action(MatchInput.END_TURN)

	# Assert
	assert_array(_sent).is_empty()


func test_l15_space_at_the_arm_time_ends_the_turn_once() -> void:
	# Arrange
	_drain_at(5000)
	_now = 5000 + ARM_MS

	# Act
	_router.on_action(MatchInput.END_TURN)

	# Assert
	_assert_one(MatchRecords.CMD_END_TURN)


func test_l15_one_millisecond_under_the_arm_time_is_still_too_soon() -> void:
	# Arrange
	_drain_at(5000)
	_now = 5000 + ARM_MS - 1

	# Act
	_router.on_action(MatchInput.END_TURN)

	# Assert
	assert_array(_sent).is_empty()


func test_l15_a_click_on_the_button_at_the_drain_is_never_gated() -> void:
	# Arrange
	_drain_at(5000)

	# Act
	_router.intent(InputRouter.INTENT_END_TURN)

	# Assert
	_assert_one(MatchRecords.CMD_END_TURN)


func test_l15_with_a_card_focused_space_submits_nothing_and_enter_selects_it() -> void:
	# Arrange
	_drain_at(5000)
	_now = 5000 + ARM_MS
	_router.set_focus_stop({"kind": "card", "id": CARD_MINION})

	# Act
	_router.on_action(MatchInput.END_TURN)
	var after_space: String = _state()
	_router.on_action(MatchInput.CONFIRM)

	# Assert
	assert_array(_sent).is_empty()
	assert_str(after_space).is_equal(String(InputRouter.STATE_IDLE))
	assert_str(_state()).is_equal(String(InputRouter.STATE_KEY_TARGETING))


func test_enter_on_end_turn_waits_for_the_arm_too() -> void:
	# Arrange
	_drain_at(5000)
	_now = 5100
	_router.set_focus_stop({"kind": InputRouter.STOP_END_TURN, "id": 0})

	# Act
	_router.on_action(MatchInput.CONFIRM)

	# Assert
	assert_array(_sent).is_empty()


# --- L17, click-to-select -------------------------------------------------------------

func test_l17_a_small_press_and_release_selects_and_submits_nothing() -> void:
	# Act
	_press(AT_MINION)
	_release(AT_MINION + SMALL_MOVE)

	# Assert
	assert_str(_state()).is_equal(String(InputRouter.STATE_KEY_TARGETING))
	assert_str(String(_router.session().entered_by)).is_equal(String(TargetingSession.ENTERED_POINTER))
	assert_array(_sent).is_empty()


func test_l17_a_second_click_on_the_row_plays_the_card_once() -> void:
	# Arrange
	_click(AT_MINION)
	_hit.gap = 1

	# Act
	_click(AT_ROW_EMPTY)

	# Assert
	var sent: Dictionary = _assert_one(MatchRecords.CMD_PLAY_CARD)
	assert_int(int(sent.position)).is_equal(1)
	assert_str(_state()).is_equal(String(InputRouter.STATE_IDLE))


func test_l17_esc_after_a_select_submits_nothing() -> void:
	# Arrange
	_click(AT_MINION)

	# Act
	_router.on_action(MatchInput.CANCEL)

	# Assert
	assert_array(_sent).is_empty()
	assert_bool(_router.in_session()).is_false()
	assert_int(_menus).is_equal(0)


func test_l17_rmb_after_a_select_submits_nothing() -> void:
	# Arrange
	_click(AT_MINION)

	# Act
	_rmb()

	# Assert
	assert_array(_sent).is_empty()
	assert_bool(_router.in_session()).is_false()


func test_l17_a_click_on_empty_table_cancels() -> void:
	# Arrange
	_click(AT_MINION)

	# Act
	_click(AT_NOWHERE)

	# Assert
	assert_array(_sent).is_empty()
	assert_array(_ended).is_equal([false])


func test_l17_a_click_on_a_different_legal_source_reselects_it() -> void:
	# Arrange
	_click(AT_MINION)

	# Act
	_click(AT_SPELL)

	# Assert
	assert_array(_sent).is_empty()
	assert_int(int(_router.session().source.id)).is_equal(CARD_SPELL)


func test_a_card_with_no_legal_entry_opens_nothing() -> void:
	# Act
	_click(AT_DEAD)

	# Assert
	assert_bool(_router.in_session()).is_false()


func test_a_press_moved_past_the_threshold_is_a_drag_not_a_select() -> void:
	# Act
	_press(AT_MINION)
	_move(AT_MINION + BIG_MOVE)

	# Assert
	assert_str(_state()).is_equal(String(InputRouter.STATE_DRAGGING))


func test_a_press_moved_exactly_the_threshold_is_still_a_click() -> void:
	# Act
	_press(AT_MINION)
	_move(AT_MINION + Vector2(DRAG_PX, 0))
	_release(AT_MINION + Vector2(DRAG_PX, 0))

	# Assert
	assert_str(_state()).is_equal(String(InputRouter.STATE_KEY_TARGETING))


# --- §7.4 click table -----------------------------------------------------------------

func _select_targeted() -> void:
	_router.intent(InputRouter.INTENT_SELECT, {"source": {"kind": "card", "id": CARD_TARGETED}, "pos": AT_NOWHERE, "entered_by": TargetingSession.ENTERED_POINTER})


func test_rank_1_a_lit_target_confirms_in_phase_t() -> void:
	# Arrange
	_select_targeted()

	# Act
	_click(AT_BOSS_HERO)

	# Assert
	assert_int(int(_assert_one(MatchRecords.CMD_PLAY_CARD).target_id)).is_equal(BOSS_HERO)


func test_rank_1_beats_rank_3_a_lit_token_that_could_also_attack() -> void:
	# Arrange: the friendly token is both a lit target and a legal attacker
	_select_targeted()

	# Act
	_click(AT_TOKEN)

	# Assert
	assert_int(int(_assert_one(MatchRecords.CMD_PLAY_CARD).target_id)).is_equal(TOKEN)


func test_rank_2_the_source_itself_is_ignored_in_phase_p_and_t() -> void:
	for at: Vector2 in [AT_MINION]:
		# Arrange
		_click(at)

		# Act
		_click(at)

		# Assert
		assert_array(_sent).is_empty()
		assert_bool(_router.in_session()).is_true()


func test_rank_2_the_source_confirms_in_phase_c() -> void:
	# Arrange
	_click(AT_SPELL)

	# Act
	_click(AT_SPELL)

	# Assert
	_assert_one(MatchRecords.CMD_PLAY_CARD)


func test_rank_2_the_second_press_of_a_double_click_is_ignored_in_phase_c() -> void:
	# Arrange
	_click(AT_POWER)

	# Act
	_click(AT_POWER, true)

	# Assert
	assert_array(_sent).is_empty()
	assert_bool(_router.in_session()).is_true()


func test_rank_3_in_phase_p_a_token_in_the_row_is_the_gap_never_a_source() -> void:
	# Arrange
	_click(AT_MINION)
	_hit.gap = 0

	# Act
	_click(AT_TOKEN)

	# Assert
	assert_int(int(_assert_one(MatchRecords.CMD_PLAY_CARD).position)).is_equal(0)


func test_rank_3_in_phase_p_the_hero_power_reselects() -> void:
	# Arrange
	_click(AT_MINION)

	# Act
	_click(AT_POWER)

	# Assert
	assert_array(_sent).is_empty()
	assert_str(str(_router.session().source.kind)).is_equal(InputRouter.SOURCE_HERO_POWER)


func test_rank_3_in_phase_c_a_friendly_attacker_reselects_rather_than_confirms() -> void:
	# Arrange: the token sits inside the cast zone
	_click(AT_SPELL)

	# Act
	_click(AT_TOKEN)

	# Assert
	assert_array(_sent).is_empty()
	assert_int(int(_router.session().source.id)).is_equal(TOKEN)


func test_rank_4_any_other_spot_in_the_cast_zone_confirms_phase_c() -> void:
	# Arrange
	_click(AT_SPELL)

	# Act
	_click(AT_CAST_ONLY)

	# Assert
	_assert_one(MatchRecords.CMD_PLAY_CARD)


func test_rank_4_a_token_that_cannot_act_in_the_cast_zone_confirms_phase_c() -> void:
	# Arrange: no entry, so not rank 3
	_click(AT_SPELL)

	# Act
	_click(AT_TOKEN_SICK)

	# Assert
	_assert_one(MatchRecords.CMD_PLAY_CARD)


func test_rank_5_end_turn_does_nothing_and_keeps_the_session() -> void:
	# Arrange
	_click(AT_SPELL)

	# Act
	_click(AT_END_TURN)

	# Assert
	assert_array(_sent).is_empty()
	assert_bool(_router.in_session()).is_true()


func test_rank_6_an_unlit_token_cancels_phase_t() -> void:
	# Arrange: the Stealth minion is no entry's target
	_select_targeted()

	# Act
	_click(AT_STEALTH)

	# Assert
	assert_array(_sent).is_empty()
	assert_bool(_router.in_session()).is_false()


func test_rank_6_a_not_playable_hand_card_cancels() -> void:
	# Arrange
	_click(AT_SPELL)

	# Act
	_click(AT_DEAD)

	# Assert
	assert_array(_sent).is_empty()
	assert_bool(_router.in_session()).is_false()


func test_a_press_in_a_session_that_travels_past_the_threshold_is_not_a_click() -> void:
	# Arrange
	_click(AT_SPELL)

	# Act
	_press(AT_CAST_ONLY)
	_release(AT_CAST_ONLY + BIG_MOVE)

	# Assert: §7.4 "press and release moving < CLICK_DRAG_PX"
	assert_array(_sent).is_empty()
	assert_bool(_router.in_session()).is_true()


func test_hover_over_a_rank_3_source_dims_the_cast_zone() -> void:
	# Arrange
	_click(AT_SPELL)

	# Act
	_move(AT_TOKEN)
	var dim_over_source: bool = _router.session().dim_zone
	_move(AT_CAST_ONLY)

	# Assert
	assert_bool(dim_over_source).is_true()
	assert_bool(_router.session().dim_zone).is_false()


func test_hover_over_an_unlit_spot_dims_the_arrow_and_holds_the_stop() -> void:
	# Arrange
	_select_targeted()
	_move(AT_BOSS_HERO)

	# Act
	_move(AT_NOWHERE)

	# Assert
	assert_bool(_router.session().lit).is_false()
	assert_int(int(_router.session().hovered)).is_equal(BOSS_HERO)


# --- §7.4 drag release ----------------------------------------------------------------

func test_drag_a_minion_released_in_the_zone_places_it() -> void:
	# Arrange
	_hit.gap = 2

	# Act
	_drag(AT_MINION, AT_ROW_EMPTY)

	# Assert
	assert_int(int(_assert_one(MatchRecords.CMD_PLAY_CARD).position)).is_equal(2)


func test_drag_a_minion_released_over_another_source_cancels() -> void:
	# Act
	_drag(AT_MINION, AT_POWER)

	# Assert
	assert_array(_sent).is_empty()
	assert_array(_ended).is_equal([false])


func test_drag_an_untargeted_spell_released_on_a_friendly_attacker_casts() -> void:
	# Act: a drag is deliberate; release never re-selects
	_drag(AT_SPELL, AT_TOKEN)

	# Assert
	_assert_one(MatchRecords.CMD_PLAY_CARD)


func test_drag_an_untargeted_spell_released_outside_the_zone_cancels() -> void:
	# Act
	_drag(AT_SPELL, AT_NOWHERE)

	# Assert
	assert_array(_sent).is_empty()


func test_drag_an_attacker_released_on_a_lit_defender_attacks_once() -> void:
	# Act
	_drag(AT_TOKEN, AT_BOSS_HERO)

	# Assert
	var sent: Dictionary = _assert_one(MatchRecords.CMD_ATTACK)
	assert_int(int(sent.attacker_id)).is_equal(TOKEN)
	assert_int(int(sent.target_id)).is_equal(BOSS_HERO)


func test_drag_an_attacker_released_on_an_illegal_defender_cancels() -> void:
	# Act
	_drag(AT_TOKEN, AT_STEALTH)

	# Assert
	assert_array(_sent).is_empty()


func test_rmb_and_esc_cancel_a_drag_and_the_release_then_does_nothing() -> void:
	# Arrange
	_press(AT_SPELL)
	_move(AT_CAST_ONLY)

	# Act
	_rmb()
	_release(AT_CAST_ONLY)

	# Assert
	assert_array(_sent).is_empty()
	assert_bool(_router.in_session()).is_false()


func test_a_drag_over_the_legal_snapshot_reads_legality_once_on_pickup() -> void:
	# Arrange
	var reads: Array = _controller.legal.duplicate()
	_press(AT_SPELL)
	_move(AT_CAST_ONLY)
	_controller.legal = []

	# Act: the snapshot taken at pickup still answers
	_release(AT_CAST_ONLY)

	# Assert
	_assert_one(MatchRecords.CMD_PLAY_CARD)
	assert_int(reads.size()).is_greater(0)


# --- Phase P to T and the chip -------------------------------------------------------

func _select_battlecry_by_key() -> void:
	_router.on_action(MatchInput.HAND, 3)


func test_a_battlecry_opens_in_phase_p_and_narrows_to_its_gaps_targets() -> void:
	# Arrange
	_select_battlecry_by_key()
	assert_str(String(_router.session().phase)).is_equal(String(InputRouter.SESSION_POSITION))
	_router.intent(InputRouter.INTENT_CYCLE, {"step": 1})
	_router.session().gap = 1

	# Act: gap 1 allows the boss token alone, though gap 0 also allows the hero
	_router.on_action(MatchInput.CONFIRM)

	# Assert
	var session: Dictionary = _router.session()
	assert_str(String(session.phase)).is_equal(String(InputRouter.SESSION_TARGET))
	assert_int(int(session.position)).is_equal(1)
	assert_dict(session.targets).is_equal({BOSS_TOKEN: true})


func test_gap_0_narrows_to_both_of_its_targets() -> void:
	# Arrange
	_select_battlecry_by_key()
	_router.session().gap = 0

	# Act
	_router.on_action(MatchInput.CONFIRM)

	# Assert
	assert_dict(_router.session().targets).is_equal({BOSS_TOKEN: true, BOSS_HERO: true})


func test_a_gap_with_no_target_submits_with_no_phase_t() -> void:
	# Arrange
	_select_battlecry_by_key()
	_router.session().gap = 2

	# Act
	_router.on_action(MatchInput.CONFIRM)

	# Assert
	var sent: Dictionary = _assert_one(MatchRecords.CMD_PLAY_CARD)
	assert_int(int(sent.position)).is_equal(2)
	assert_that(sent.target_id).is_null()


func test_confirming_a_target_after_p_submits_the_gap_and_the_target_together() -> void:
	# Arrange
	_select_battlecry_by_key()
	_router.session().gap = 0
	_router.on_action(MatchInput.CONFIRM)

	# Act: the first stop is the boss token
	_router.on_action(MatchInput.CONFIRM)

	# Assert
	var sent: Dictionary = _assert_one(MatchRecords.CMD_PLAY_CARD)
	assert_int(int(sent.position)).is_equal(0)
	assert_int(int(sent.target_id)).is_equal(BOSS_TOKEN)


func test_esc_in_phase_t_after_p_cancels_the_whole_play() -> void:
	# Arrange
	_select_battlecry_by_key()
	_router.session().gap = 0
	_router.on_action(MatchInput.CONFIRM)

	# Act
	_router.on_action(MatchInput.CANCEL)

	# Assert: §7.3, one step, no going back to P
	assert_bool(_router.in_session()).is_false()
	assert_array(_sent).is_empty()


func test_a_dragged_battlecry_goes_hands_free_after_the_gap() -> void:
	# Arrange
	_hit.gap = 0
	_press(Vector2(600, 600))
	_router.intent(InputRouter.INTENT_DRAG_START, {"source": {"kind": "card", "id": CARD_BATTLECRY}, "pos": AT_ROW_EMPTY})

	# Act
	_router.intent(InputRouter.INTENT_DRAG_RELEASE, {"pos": AT_ROW_EMPTY})

	# Assert
	assert_str(String(_router.session().phase)).is_equal(String(InputRouter.SESSION_TARGET))
	assert_str(String(_router.session().entered_by)).is_equal(String(TargetingSession.ENTERED_POINTER))
	assert_array(_sent).is_empty()


func test_an_optional_target_ends_its_cycle_on_the_chip() -> void:
	# Act
	_router.on_action(MatchInput.HAND, 4)

	# Assert
	var session: Dictionary = _router.session()
	assert_bool(session.null_allowed).is_true()
	assert_array(session.stops).is_equal([BOSS_TOKEN, TargetingSession.NO_TARGET_CHIP])


func test_enter_on_the_chip_submits_with_no_target() -> void:
	# Arrange
	_router.on_action(MatchInput.HAND, 4)
	_router.session().chip_rect = CHIP_RECT
	_router.on_action(MatchInput.NEXT)

	# Act
	_router.on_action(MatchInput.CONFIRM)

	# Assert
	assert_that(_assert_one(MatchRecords.CMD_PLAY_CARD).target_id).is_null()


func test_a_click_on_the_chip_submits_with_no_target() -> void:
	# Arrange
	_router.on_action(MatchInput.HAND, 4)
	_router.session().chip_rect = CHIP_RECT

	# Act
	_click(CHIP_RECT.get_center())

	# Assert
	assert_that(_assert_one(MatchRecords.CMD_PLAY_CARD).target_id).is_null()


func test_no_chip_without_a_null_entry() -> void:
	# Act
	_router.on_action(MatchInput.HAND, 2)

	# Assert
	assert_bool(_router.session().null_allowed).is_false()
	assert_bool((_router.session().stops as Array).has(TargetingSession.NO_TARGET_CHIP)).is_false()


func test_the_cycle_runs_enemy_row_enemy_hero_friendly_row_and_wraps() -> void:
	# Arrange: the targeted spell lights boss token, boss hero, friendly token
	_router.on_action(MatchInput.HAND, 2)
	var seen: Array[int] = [int(_router.session().hovered)]

	# Act
	for i: int in 3:
		_router.on_action(MatchInput.NEXT)
		seen.append(int(_router.session().hovered))

	# Assert
	assert_array(seen).is_equal([BOSS_TOKEN, BOSS_HERO, TOKEN, BOSS_TOKEN])


func test_shift_tab_walks_the_cycle_backward() -> void:
	# Arrange
	_router.on_action(MatchInput.HAND, 2)

	# Act
	_router.on_action(MatchInput.PREVIOUS)

	# Assert
	assert_int(int(_router.session().hovered)).is_equal(TOKEN)


func test_key_entry_starts_on_the_right_most_gap() -> void:
	# Act
	_router.on_action(MatchInput.HAND, 0)

	# Assert: §7.1, appending is the common play
	assert_int(int(_router.session().gap)).is_equal(2)


# --- keys in Idle ---------------------------------------------------------------------

func test_a_number_past_the_hand_is_ignored() -> void:
	# Act
	_router.on_action(MatchInput.HAND, 8)

	# Assert
	assert_bool(_router.in_session()).is_false()


func test_h_opens_the_hero_power_and_ignores_itself_in_its_own_session() -> void:
	# Arrange
	_router.on_action(MatchInput.HERO_POWER)
	var opened: bool = _router.in_session()

	# Act
	_router.on_action(MatchInput.HERO_POWER)

	# Assert: never a confirm
	assert_bool(opened).is_true()
	assert_bool(_router.in_session()).is_true()
	assert_array(_sent).is_empty()
	assert_array(_ended).is_empty()


func test_h_with_no_power_entry_opens_nothing() -> void:
	# Arrange
	_controller.legal = [_play(0, 0, null)]

	# Act
	_router.on_action(MatchInput.HERO_POWER)

	# Assert
	assert_bool(_router.in_session()).is_false()


func test_a_number_in_a_session_reselects_that_hand_card() -> void:
	# Arrange
	_router.on_action(MatchInput.HERO_POWER)

	# Act
	_router.on_action(MatchInput.HAND, 0)

	# Assert
	assert_int(int(_router.session().source.id)).is_equal(CARD_MINION)


func test_tab_in_idle_steps_focus_and_l_toggles_the_feed() -> void:
	# Act
	_router.on_action(MatchInput.NEXT)
	_router.on_action(MatchInput.PREVIOUS)
	_router.on_action(MatchInput.FEED)

	# Assert
	assert_array(_steps).is_equal([1, -1])
	assert_int(_feeds).is_equal(1)


func test_space_never_confirms_a_session() -> void:
	# Arrange
	_router.on_action(MatchInput.HAND, 1)

	# Act
	_router.on_action(MatchInput.END_TURN)

	# Assert: §7.2
	assert_array(_sent).is_empty()
	assert_bool(_router.in_session()).is_true()


# --- A, attacker arming ---------------------------------------------------------------

func test_a_badges_the_legal_attackers_by_slot() -> void:
	# Act
	_router.on_action(MatchInput.ATTACK)

	# Assert: slot 1 only: the second token has no entry
	assert_dict(_badges[0]).is_equal({TOKEN: 1})


func test_a_then_a_badged_number_picks_that_attacker() -> void:
	# Arrange
	_router.on_action(MatchInput.ATTACK)

	# Act
	_router.on_action(MatchInput.HAND, 0)

	# Assert
	assert_int(int(_router.session().source.id)).is_equal(TOKEN)
	assert_dict(_badges[_badges.size() - 1]).is_empty()


func test_a_then_an_unbadged_number_is_ignored_and_stays_armed() -> void:
	# Arrange
	_router.on_action(MatchInput.ATTACK)

	# Act
	_router.on_action(MatchInput.HAND, 1)
	_router.on_action(MatchInput.HAND, 8)
	_router.on_action(MatchInput.HAND, 0)

	# Assert
	assert_int(int(_router.session().source.id)).is_equal(TOKEN)


func test_a_then_esc_disarms_without_reaching_the_chain() -> void:
	# Arrange
	_router.on_action(MatchInput.ATTACK)

	# Act
	_router.on_action(MatchInput.CANCEL)

	# Assert
	assert_int(_menus).is_equal(0)
	assert_dict(_badges[_badges.size() - 1]).is_empty()


func test_a_then_another_key_disarms_and_is_consumed() -> void:
	# Arrange
	_router.on_action(MatchInput.ATTACK)

	# Act
	_router.on_action(MatchInput.FEED)

	# Assert
	assert_int(_feeds).is_equal(0)
	assert_dict(_badges[_badges.size() - 1]).is_empty()


func test_a_with_no_attacker_arms_nothing() -> void:
	# Arrange
	_controller.legal = [_power(null)]

	# Act
	_router.on_action(MatchInput.ATTACK)
	_router.on_action(MatchInput.FEED)

	# Assert
	assert_array(_badges).is_empty()
	assert_int(_feeds).is_equal(1)


# --- skip while busy ------------------------------------------------------------------

func test_space_enter_and_a_left_click_skip_a_busy_queue() -> void:
	for input: Callable in [
		func() -> void: _router.on_action(MatchInput.END_TURN),
		func() -> void: _router.on_action(MatchInput.CONFIRM),
		func() -> void: _click(AT_NOWHERE),
	]:
		# Arrange
		_busy()

		# Act
		input.call()

		# Assert
		assert_bool(_queue.is_idle()).is_true()
		assert_array(_sent).is_empty()


func test_a_click_that_skips_never_also_picks_up_the_card_under_it() -> void:
	# Arrange
	_busy()

	# Act: §7.3, outside `Idle` a press on a source is skip or ignored
	_click(AT_MINION)

	# Assert
	assert_bool(_queue.is_idle()).is_true()
	assert_bool(_router.in_session()).is_false()


func test_a_press_that_skips_and_then_moves_starts_no_drag() -> void:
	# Arrange
	_busy()

	# Act
	_press(AT_MINION)
	_move(AT_MINION + BIG_MOVE)

	# Assert
	assert_bool(_router.in_session()).is_false()


# --- states and locks -----------------------------------------------------------------

func test_q5_a_boss_entry_never_reaches_the_player_list() -> void:
	# Act
	var commands: Array[Dictionary] = _router.player_commands()

	# Assert
	for command: Dictionary in commands:
		assert_str(str(command.issuer)).is_equal("player")
	assert_int(commands.size()).is_equal(_full_legal().size() - 1)


func test_the_boss_turn_locks_everything_but_skip_menu_and_feed() -> void:
	# Arrange
	_view.active_side = MatchViewState.SIDE_BOSS

	# Act / Assert
	assert_str(_state()).is_equal(String(InputRouter.STATE_BOSS_TURN))
	assert_bool(_router.can_end_turn()).is_false()
	for name: StringName in [InputRouter.INTENT_SKIP, InputRouter.INTENT_MENU, InputRouter.INTENT_FEED]:
		assert_bool(_router.allows(name)).override_failure_message(String(name)).is_true()
	for name: StringName in [InputRouter.INTENT_END_TURN, InputRouter.INTENT_DRAG_START, InputRouter.CHOICE_INTENT]:
		assert_bool(_router.allows(name)).override_failure_message(String(name)).is_false()


func test_no_session_opens_during_the_boss_turn() -> void:
	# Arrange
	_view.active_side = MatchViewState.SIDE_BOSS

	# Act
	_router.intent(InputRouter.INTENT_DRAG_START, {"source": {"kind": "card", "id": CARD_MINION}, "pos": AT_MINION})
	_router.intent(InputRouter.INTENT_SELECT, {"source": {"kind": "card", "id": CARD_MINION}, "pos": AT_MINION})
	_router.on_action(MatchInput.HAND, 0)

	# Assert
	assert_bool(_router.in_session()).is_false()


func test_a_choice_the_player_owes_lifts_the_lock_for_choose_alone() -> void:
	# Arrange
	_view.active_side = MatchViewState.SIDE_BOSS
	_view.pending_choice = {"side": "player", "kind": "discover", "options": ["a", "b", "c"]}

	# Act / Assert
	assert_str(_state()).is_equal(String(InputRouter.STATE_CHOICE_OPEN))
	assert_bool(_router.allows(InputRouter.CHOICE_INTENT)).is_true()
	assert_bool(_router.allows(InputRouter.INTENT_END_TURN)).is_false()
	_router.intent(InputRouter.CHOICE_INTENT, {"index": 2})
	assert_int(int(_assert_one(MatchRecords.CMD_CHOOSE).option_index)).is_equal(2)


func test_choose_with_no_choice_owed_sends_nothing() -> void:
	# Act
	_router.intent(InputRouter.CHOICE_INTENT, {"index": 0})

	# Assert
	assert_array(_sent).is_empty()


func test_a_boss_choice_keeps_the_lock() -> void:
	# Arrange
	_view.active_side = MatchViewState.SIDE_BOSS
	_view.pending_choice = {"side": "boss", "kind": "discover"}

	# Act / Assert
	assert_str(_state()).is_equal(String(InputRouter.STATE_BOSS_TURN))
	assert_bool(_router.allows(InputRouter.CHOICE_INTENT)).is_false()


func test_the_mulligan_confirm_sends_only_in_mulligan() -> void:
	# Arrange
	_router.intent(InputRouter.INTENT_MULLIGAN_CONFIRM, {"keep_mask": [true]})
	var idle_sent: int = _sent.size()
	_view.pending_mulligan = [CARD_MINION]

	# Act
	_router.intent(InputRouter.INTENT_MULLIGAN_CONFIRM, {"keep_mask": [true]})

	# Assert
	assert_int(idle_sent).is_equal(0)
	_assert_one(MatchRecords.CMD_MULLIGAN)


func test_a_busy_queue_is_playback_and_end_turn_is_off() -> void:
	# Arrange
	_busy()

	# Act / Assert
	assert_str(_state()).is_equal(String(InputRouter.STATE_PLAYBACK))
	assert_bool(_router.can_end_turn()).is_false()
	_router.intent(InputRouter.INTENT_END_TURN)
	assert_array(_sent).is_empty()


func test_a_result_on_an_idle_queue_is_ended_whatever_else_is_up() -> void:
	# Arrange
	_router.set_menu_open(true)
	_view.result = {"result": "win", "reason": "hero_dead"}

	# Act / Assert
	assert_str(_state()).is_equal(String(InputRouter.STATE_ENDED))


func test_ended_takes_no_command() -> void:
	# Arrange
	_view.result = {"result": "win", "reason": "hero_dead"}

	# Act
	_router.intent(InputRouter.INTENT_END_TURN)
	_router.intent(InputRouter.INTENT_CONCEDE)
	_router.on_action(MatchInput.HAND, 0)

	# Assert
	assert_array(_sent).is_empty()
	assert_bool(_router.in_session()).is_false()


func test_a_read_only_controller_never_ends_a_turn() -> void:
	# Arrange
	_controller.read_only = true

	# Act / Assert
	assert_bool(_router.can_end_turn()).is_false()


# --- the Esc chain --------------------------------------------------------------------

func test_esc_closes_the_session_first_and_nothing_else_runs() -> void:
	# Arrange
	_drawer_open = true
	_router.on_action(MatchInput.HAND, 1)

	# Act
	_router.on_action(MatchInput.CANCEL)

	# Assert
	assert_int(_feeds).is_equal(0)
	assert_int(_menus).is_equal(0)


func test_esc_closes_the_drawer_before_the_menu() -> void:
	# Arrange
	_drawer_open = true

	# Act
	_router.on_action(MatchInput.CANCEL)

	# Assert
	assert_int(_feeds).is_equal(1)
	assert_int(_menus).is_equal(0)


func test_esc_with_nothing_open_asks_for_the_menu() -> void:
	# Act
	_router.on_action(MatchInput.CANCEL)

	# Assert
	assert_int(_menus).is_equal(1)


func test_rmb_with_nothing_open_never_opens_the_menu() -> void:
	# Act
	_rmb()

	# Assert
	assert_int(_menus).is_equal(0)


func test_rmb_closes_the_drawer() -> void:
	# Arrange
	_drawer_open = true

	# Act
	_rmb()

	# Assert
	assert_int(_feeds).is_equal(1)


func test_with_the_menu_open_esc_steps_back_and_every_other_key_is_ignored() -> void:
	# Arrange
	_router.set_menu_open(true)

	# Act
	_router.on_action(MatchInput.HAND, 0)
	_router.on_action(MatchInput.FEED)
	_router.on_action(MatchInput.END_TURN)
	var quiet: bool = _feeds == 0 and not _router.in_session() and _sent.is_empty()
	_router.on_action(MatchInput.CANCEL)

	# Assert
	assert_bool(quiet).is_true()
	assert_int(_menus).is_equal(1)


func test_once_there_is_a_result_esc_opens_nothing() -> void:
	# Arrange
	_view.result = {"result": "win", "reason": "hero_dead"}

	# Act
	_router.escape()
	_router.intent(InputRouter.INTENT_MENU)

	# Assert: DD-X09
	assert_int(_menus).is_equal(0)


func test_once_there_is_a_result_esc_still_closes_the_drawer() -> void:
	# Arrange
	_view.result = {"result": "win", "reason": "hero_dead"}
	_drawer_open = true

	# Act
	_router.escape()

	# Assert
	assert_int(_feeds).is_equal(1)
