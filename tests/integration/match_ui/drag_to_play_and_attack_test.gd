## Drag to play and attack, on real fixtures (match-ui U5, U7, O4, O5; targeting.md §5.2, §6;
## story 008). The pointer goes in past the GUI: see [MatchViewHarness].
extends GdUnitTestSuite

const CENTRE := Vector2(640, 360)
const NOWHERE := Vector2(1120, 120)
const CAST_INSIDE := Vector2(800, 220)
const ROW_INSIDE := Vector2(640, 400)
const PARK_TOP_Y: float = 438.0
const FIRST_PICKUP_PX: float = 30.0


func _open(fixture: String, settings: Dictionary = {}) -> MatchView:
	var view: MatchView = await MatchViewHarness.open(self, fixture, [], settings)
	await MatchViewHarness.frames(view, 2)
	MatchViewHarness.run(view, MatchViewHarness.FRAME_S)
	return view


func _token_centre(view: MatchView, row: String, index: int) -> Vector2:
	var side: StringName = &"player" if row == "PlayerRow" else &"boss"
	var id: int = int(view.view_state().side(side).board[index].entity_id)
	return (view.find_child(row, true, false) as BoardPresenter).center_of(id)


func _card_of(view: MatchView, card_id: String) -> int:
	for card: Dictionary in view.view_state().side(&"player").hand:
		if str(card.card_id) == card_id:
			return int(card.instance_id)
	return -1


func _start_drag(view: MatchView, from: Vector2, to: Vector2) -> void:
	MatchViewHarness.send(view, MatchViewHarness.mouse_button(from, MOUSE_BUTTON_LEFT, true, false))
	MatchViewHarness.send(view, MatchViewHarness.motion(to))


func test_a_minion_lifts_on_pickup_and_follows_the_pointer_exactly() -> void:
	# Arrange
	var view: MatchView = await _open("treasure_tray")
	var id: int = _card_of(view, "neutral_tunnel_rat")
	var from: Vector2 = MatchViewHarness.card_point(view, id)

	# Act
	_start_drag(view, from, CENTRE)
	var card: CardFrame = view.hand().card(id)

	# Assert: centred on the pointer, upright, this frame
	assert_str(String(view.router().view_state())).is_equal(String(InputRouter.STATE_DRAGGING))
	assert_object(card.get_global_rect().get_center()).is_equal(CENTRE)
	assert_float(card.rotation_degrees).is_equal(0.0)
	assert_str(String(view.router().session().phase)).is_equal(String(InputRouter.SESSION_POSITION))
	view.router().intent(InputRouter.INTENT_CANCEL)
	MatchViewHarness.close(view)


func test_a_minion_released_in_the_row_plays_once_and_the_first_step_starts_at_once() -> void:
	# Arrange
	var view: MatchView = await _open("treasure_tray", {"anim_speed": "normal"})
	var id: int = _card_of(view, "neutral_tunnel_rat")
	var sent: Array[Dictionary] = MatchViewHarness.spy_commands(view)
	var started: Array[String] = []
	view.queue().step_started.connect(func(step: AnimStep, _d: float) -> void: started.append(String(step.kind)))

	# Act
	MatchViewHarness.drag(view, MatchViewHarness.card_point(view, id), ROW_INSIDE)
	view.call("_process", 0.0)

	# Assert: no clock has passed, so the ≤ 50 ms budget is met by construction here
	assert_int(sent.size()).is_equal(1)
	assert_str(str(sent[0].type)).is_equal(MatchRecords.CMD_PLAY_CARD)
	assert_array(started).is_not_empty()
	MatchViewHarness.settle(view)
	assert_int(view.view_state().side(&"player").board.size()).is_equal(1)
	assert_array(MatchViewHarness.sync_lines(view)).is_empty()
	MatchViewHarness.close(view)


func test_a_cancelled_drag_sends_nothing_and_the_card_goes_home() -> void:
	# Arrange
	var view: MatchView = await _open("treasure_tray")
	var id: int = _card_of(view, "neutral_tunnel_rat")
	var sent: Array[Dictionary] = MatchViewHarness.spy_commands(view)
	var events_before: int = MatchViewHarness.event_types(view).size()

	# Act
	MatchViewHarness.drag(view, MatchViewHarness.card_point(view, id), NOWHERE)

	# Assert
	assert_array(sent).is_empty()
	assert_int(MatchViewHarness.event_types(view).size()).is_equal(events_before)
	assert_int(int(view.hand().get("_dragged"))).is_equal(-1)
	MatchViewHarness.close(view)


func test_an_untargeted_card_shows_the_cast_zone_only_while_dragged() -> void:
	# Arrange: the fixture's spell has no target entry
	var view: MatchView = await _open("treasure_tray")
	var arrow: TargetingArrow = view.find_child("TargetingArrow", true, false)
	var id: int = _card_of(view, "war_sharpen")
	var source: Dictionary = {"kind": InputRouter.SOURCE_CARD, "id": id}

	# Act
	view.router().intent(InputRouter.INTENT_DRAG_START, {"source": source, "pos": CAST_INSIDE})
	var zone: Rect2 = arrow.get("_zone")
	var phase: StringName = view.router().session().phase
	view.router().intent(InputRouter.INTENT_CANCEL)

	# Assert
	assert_str(String(phase)).is_equal(String(InputRouter.SESSION_CAST))
	assert_object(zone).is_equal(Rect2(301, 176, 678, 284))
	assert_object(arrow.get("_zone")).is_equal(Rect2())
	MatchViewHarness.close(view)


func test_a_targeted_spell_parks_at_top_y_438_upright_with_the_arrow_from_it() -> void:
	# Arrange: the fixture's deck gives a spell with targets
	var view: MatchView = await _open("targeting_taunt")
	var hand_ids: Array = view.hand().get("_order")
	var entries: Array[Dictionary] = MatchViewHarness.legal(view, MatchRecords.CMD_USE_HERO_POWER)
	var card: int = int(hand_ids[0])
	var slot_x: float = float((view.hand().get("_slots") as Dictionary)[card].x)
	var session_source: Dictionary = {"kind": InputRouter.SOURCE_CARD, "id": card}

	# Act: a parked source, as a Phase T session parks it
	view.hand().begin_drag(card, true)
	var frame: CardFrame = view.hand().card(card)

	# Assert
	assert_float(frame.position.y).is_equal(PARK_TOP_Y)
	assert_float(frame.position.x + frame.size.x / 2.0).is_equal(slot_x)
	assert_float(frame.rotation_degrees).is_equal(0.0)
	assert_float(frame.scale.x).is_equal(1.0)
	assert_int(entries.size()).is_equal(1)
	assert_int(int(session_source.id)).is_equal(card)
	view.hand().end_drag(false)
	MatchViewHarness.close(view)


func test_o4_under_a_taunt_only_the_taunt_is_outlined_and_the_hero_is_not() -> void:
	# Arrange
	var view: MatchView = await _open("targeting_taunt")
	var attacker: int = int(view.view_state().side(&"player").board[0].entity_id)
	var boss_row: BoardPresenter = view.find_child("BossRow", true, false)
	var boss_panel: HeroPresenter = view.find_child("BossPanel", true, false)

	# Act
	view.pose_drag(attacker)

	# Assert
	var arrow: TargetingArrow = view.find_child("TargetingArrow", true, false)
	assert_bool(arrow.is_active()).is_true()
	assert_object(arrow.ends()[1]).is_equal(CENTRE)
	for token: Dictionary in view.view_state().side(&"boss").board:
		var lit: bool = boss_row.token(int(token.entity_id)).get("_target")
		assert_bool(lit).override_failure_message(str(token.card_id)).is_equal((token.keywords as Array).has("taunt"))
	var style: StyleBoxFlat = boss_panel.get("_portrait_style")
	assert_object(style.border_color).is_not_equal(view.ui_context().color("state_target"))
	view.router().intent(InputRouter.INTENT_CANCEL)
	MatchViewHarness.close(view)


func test_the_arrow_is_a_quadratic_lifted_above_its_midpoint() -> void:
	# Act
	var points: PackedVector2Array = TargetingArrow.curve(Vector2(0, 100), Vector2(100, 100), 50.0, 20)

	# Assert: ends on its ends; a quadratic peaks at half its control's height
	assert_object(points[0]).is_equal(Vector2(0, 100))
	assert_object(points[points.size() - 1]).is_equal(Vector2(100, 100))
	assert_float(points[10].y).is_equal_approx(75.0, 0.01)


func test_a_drag_releases_an_attack_on_the_taunt_once() -> void:
	# Arrange
	var view: MatchView = await _open("targeting_taunt")
	var sent: Array[Dictionary] = MatchViewHarness.spy_commands(view)
	var taunt: int = int(view.view_state().side(&"boss").board[2].entity_id)

	# Act
	MatchViewHarness.drag(view, _token_centre(view, "PlayerRow", 0), _token_centre(view, "BossRow", 2))
	MatchViewHarness.settle(view)

	# Assert
	assert_int(sent.size()).is_equal(1)
	assert_str(str(sent[0].type)).is_equal(MatchRecords.CMD_ATTACK)
	assert_int(int(sent[0].target_id)).is_equal(taunt)
	assert_array(MatchViewHarness.event_types(view)).contains(["attack_declared"])
	MatchViewHarness.close(view)


func test_a_drag_released_on_a_non_taunt_past_the_taunt_attacks_nothing() -> void:
	# Arrange
	var view: MatchView = await _open("targeting_taunt")
	var sent: Array[Dictionary] = MatchViewHarness.spy_commands(view)

	# Act
	MatchViewHarness.drag(view, _token_centre(view, "PlayerRow", 0), _token_centre(view, "BossRow", 0))

	# Assert
	assert_array(sent).is_empty()
	MatchViewHarness.close(view)


func test_o5_a_stealth_minion_keeps_its_badge_and_takes_no_outline() -> void:
	# Arrange / Act: the fixture's own pose is a drag
	var view: MatchView = await MatchViewHarness.open(self, "targeting_stealth")
	await MatchViewHarness.frames(view, 2)
	var row: BoardPresenter = view.find_child("BossRow", true, false)
	var stealth: Dictionary = view.view_state().side(&"boss").board[0]
	var other: Dictionary = view.view_state().side(&"boss").board[1]

	# Assert
	assert_str(String(view.router().view_state())).is_equal(String(InputRouter.STATE_DRAGGING))
	assert_bool((stealth.keywords as Array).has("stealth")).is_true()
	assert_bool(row.token(int(stealth.entity_id)).get("_target")).is_false()
	assert_bool(row.token(int(other.entity_id)).get("_target")).is_true()
	assert_str((row.token(int(stealth.entity_id)).get("_badges") as Label).text).contains(view.ui_context().glyph("stealth"))
	assert_bool((view.router().session().targets as Dictionary).has(int(stealth.entity_id))).is_false()
	view.router().intent(InputRouter.INTENT_CANCEL)
	MatchViewHarness.close(view)


func test_the_outlines_go_when_the_session_ends() -> void:
	# Arrange
	var view: MatchView = await _open("targeting_taunt")
	var attacker: int = int(view.view_state().side(&"player").board[0].entity_id)
	var taunt: int = int(view.view_state().side(&"boss").board[2].entity_id)
	view.pose_drag(attacker)

	# Act
	view.router().intent(InputRouter.INTENT_CANCEL)

	# Assert
	var row: BoardPresenter = view.find_child("BossRow", true, false)
	assert_bool(row.token(taunt).get("_target")).is_false()
	assert_bool((view.find_child("TargetingArrow", true, false) as TargetingArrow).is_active()).is_false()
	MatchViewHarness.close(view)


func test_a_press_on_an_unplayable_hand_card_starts_no_drag() -> void:
	# Arrange: two-mana cards in the hand on one mana, or none playable at all
	var view: MatchView = await _open("boss_turn_playback")
	var id: int = MatchViewHarness.hand_id(view, 0)

	# Act
	_start_drag(view, MatchViewHarness.card_point(view, id), MatchViewHarness.card_point(view, id) + Vector2(0, -FIRST_PICKUP_PX))

	# Assert
	assert_bool(view.router().in_session()).is_false()
	MatchViewHarness.close(view)
