## Keyboard focus on the table (match-ui U5, O18; hud.md Focus Order; story 018): the `Tab`
## order, the default stop, succession when a focused card leaves, and inspect on focus.
extends GdUnitTestSuite

const RING_PX: int = 2
const RING_OFFSET_PX: int = 3


func _open(fixture: String, args: Array = []) -> MatchView:
	var view: MatchView = await MatchViewHarness.open(self, fixture, args)
	await MatchViewHarness.frames(view, 2)
	MatchViewHarness.run(view, MatchViewHarness.FRAME_S)
	return view


func _focus(view: MatchView) -> FocusPresenter:
	return view.get("_focus")


func _kinds(stops: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for stop: Dictionary in stops:
		if out.is_empty() or out.back() != str(stop.kind):
			out.append(str(stop.kind))
	return out


func _hero_stop(view: MatchView) -> Dictionary:
	return {"kind": InputRouter.SOURCE_ATTACKER, "id": int(view.view_state().side(&"player").hero.entity_id)}


func test_tab_walks_the_hud_order_and_wraps() -> void:
	# Arrange: a board on both sides, and treasures would sit after the portrait
	var view: MatchView = await _open("targeting_taunt")
	var focus: FocusPresenter = _focus(view)
	var stops: Array[Dictionary] = focus.stops()

	# Assert: hand, player row and portrait share a kind; the walk below tells them apart
	assert_array(_kinds(stops)).is_equal([
		InputRouter.SOURCE_CARD, InputRouter.SOURCE_ATTACKER, InputRouter.SOURCE_HERO_POWER, InputRouter.SOURCE_ATTACKER,
		InputRouter.STOP_END_TURN, FocusPresenter.KIND_FEED, FocusPresenter.KIND_MENU, FocusPresenter.KIND_BANNER,
		FocusPresenter.KIND_BOSS_TOKEN, FocusPresenter.KIND_BOSS_PORTRAIT,
	])
	assert_dict(stops[stops.find({"kind": InputRouter.SOURCE_HERO_POWER, "id": -1}) + 1]).is_equal(_hero_stop(view))

	# Act: a full lap from the first stop
	focus.focus_stop(stops[0], true)
	for i: int in stops.size():
		MatchViewHarness.action(view, &"ui_focus_next")

	# Assert
	assert_dict(focus.current()).is_equal(stops[0])
	MatchViewHarness.close(view)


func test_treasure_chips_sit_between_the_portrait_and_end_turn() -> void:
	# Arrange / Act
	var view: MatchView = await _open("treasure_tray")
	var stops: Array[Dictionary] = _focus(view).stops()
	var end_turn: int = stops.find({"kind": InputRouter.STOP_END_TURN, "id": 0})

	# Assert
	assert_dict(stops[end_turn - 1]).is_equal({"kind": FocusPresenter.KIND_TREASURE, "id": 1})
	assert_dict(stops[end_turn - 2]).is_equal({"kind": FocusPresenter.KIND_TREASURE, "id": 0})
	assert_dict(stops[end_turn - 3]).is_equal(_hero_stop(view))
	MatchViewHarness.close(view)


func test_focus_never_lands_on_a_pile_the_mana_bar_or_the_top_bar_text() -> void:
	# Arrange / Act
	var view: MatchView = await _open("targeting_taunt")
	var seen: Dictionary = {}
	for stop: Dictionary in _focus(view).stops():
		seen[str(stop.kind)] = true

	# Assert: exactly these kinds
	assert_array(seen.keys()).contains_exactly_in_any_order([
		InputRouter.SOURCE_CARD, InputRouter.SOURCE_ATTACKER, InputRouter.SOURCE_HERO_POWER, InputRouter.STOP_END_TURN,
		FocusPresenter.KIND_FEED, FocusPresenter.KIND_MENU, FocusPresenter.KIND_BANNER, FocusPresenter.KIND_BOSS_TOKEN,
		FocusPresenter.KIND_BOSS_PORTRAIT,
	])
	MatchViewHarness.close(view)


func test_on_entering_idle_focus_goes_to_the_left_most_playable_card() -> void:
	# Arrange / Act: slot 0 here is a spell the fixture cannot pay for or can
	var view: MatchView = await _open("turn1_player")
	var first: int = -1
	for card: Dictionary in view.ui_context().query.hand("player"):
		if card.playable and first == -1:
			first = int(card.instance_id)

	# Assert
	assert_dict(_focus(view).current()).is_equal({"kind": InputRouter.SOURCE_CARD, "id": first})
	MatchViewHarness.close(view)


func test_on_entering_idle_with_nothing_lit_focus_goes_to_end_turn() -> void:
	# Arrange / Act: nine cards it cannot pay for
	var view: MatchView = await _open("boss_turn_playback")

	# Assert
	assert_dict(_focus(view).current()).is_equal({"kind": InputRouter.STOP_END_TURN, "id": 0})
	MatchViewHarness.close(view)


func test_the_router_is_told_the_stop_so_enter_acts_on_it() -> void:
	# Arrange
	var view: MatchView = await _open("turn1_player")

	# Act
	MatchViewHarness.action(view, &"ui_accept")

	# Assert: the default stop is a playable card, and `Enter` opens it
	assert_str(String(view.router().view_state())).is_equal(String(InputRouter.STATE_KEY_TARGETING))
	MatchViewHarness.close(view)


func test_a_focused_card_leaving_the_hand_hands_focus_to_the_card_at_its_index() -> void:
	# Arrange: the middle of the hand, played at speed so `Idle` is entered afresh
	var view: MatchView = await MatchViewHarness.open(self, "treasure_tray", [], {"anim_speed": "fast"})
	MatchViewHarness.run(view, MatchViewHarness.FRAME_S)
	var focus: FocusPresenter = _focus(view)
	var hand: Array = view.view_state().side(&"player").hand
	var slot: int = 1
	var next_card: int = int(hand[slot + 1].instance_id)
	focus.focus_stop({"kind": InputRouter.SOURCE_CARD, "id": int(hand[slot].instance_id)}, true)
	var play: Dictionary = {}
	for command: Dictionary in MatchViewHarness.legal(view, MatchRecords.CMD_PLAY_CARD):
		if int(command.hand_index) == slot:
			play = command

	# Act
	view.router().command_requested.emit(play)
	MatchViewHarness.settle(view)

	# Assert
	assert_dict(focus.current()).is_equal({"kind": InputRouter.SOURCE_CARD, "id": next_card})
	MatchViewHarness.close(view)


func test_the_last_card_leaving_hands_focus_to_end_turn() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "treasure_tray", [], {"anim_speed": "fast"})
	MatchViewHarness.run(view, MatchViewHarness.FRAME_S)
	var focus: FocusPresenter = _focus(view)
	var hand: Array = view.view_state().side(&"player").hand
	var last: int = hand.size() - 1
	focus.focus_stop({"kind": InputRouter.SOURCE_CARD, "id": int(hand[last].instance_id)}, true)
	var play: Dictionary = {}
	for command: Dictionary in MatchViewHarness.legal(view, MatchRecords.CMD_PLAY_CARD):
		if int(command.hand_index) == last:
			play = command

	# Act
	view.router().command_requested.emit(play)
	MatchViewHarness.settle(view)

	# Assert
	assert_dict(focus.current()).is_equal({"kind": InputRouter.STOP_END_TURN, "id": 0})
	MatchViewHarness.close(view)


func test_o18_a_blocked_power_in_focus_opens_its_reason_with_no_hover() -> void:
	# Arrange / Act
	var view: MatchView = await _open("turn1_player", ["--pose=focus:hero_power"])
	var panel: HeroPresenter = view.find_child("PlayerPanel", true, false)
	var state: Dictionary = view.ui_context().query.hero_power_state("player")

	# Assert
	assert_str(str(state.state)).is_equal(MatchQuery.POWER_BLOCKED)
	assert_bool((panel.get("_tooltip") as Control).visible).is_true()
	assert_str((panel.get("_tooltip_text") as Label).text).contains(tr("reject." + str(state.reason_code)))
	assert_dict(_focus(view).current()).is_equal({"kind": InputRouter.SOURCE_HERO_POWER, "id": -1})
	MatchViewHarness.close(view)


func test_o18_the_ring_is_2_px_3_px_outside() -> void:
	# Arrange / Act
	var view: MatchView = await _open("turn1_player")

	# Assert
	assert_int(int(view.ui_context().config.focus.ring_px)).is_equal(RING_PX)
	assert_int(int(view.ui_context().config.focus.ring_offset_px)).is_equal(RING_OFFSET_PX)
	MatchViewHarness.close(view)


func test_o18_a_focused_card_shows_its_preview_also_at_instant() -> void:
	# Arrange / Act
	var view: MatchView = await _open("turn1_player", ["--pose=focus:0"])
	var id: int = MatchViewHarness.hand_id(view, 0)

	# Assert
	assert_int(int(view.hand().get("_hovered"))).is_equal(id)
	assert_float(view.hand().card(id).scale.x).is_equal(1.5)
	MatchViewHarness.close(view)


func test_a_focused_token_shows_the_inspect_and_a_hover_elsewhere_does_not_take_the_ring() -> void:
	# Arrange
	var view: MatchView = await _open("midgame_full_board")
	var token: int = int(view.view_state().side(&"boss").board[3].entity_id)
	view.call("_pose_focus", str(token))
	var held: Dictionary = _focus(view).current()

	# Act: a pointer over the player's hand
	MatchViewHarness.send(view, MatchViewHarness.motion(MatchViewHarness.card_point(view, MatchViewHarness.hand_id(view, 0))))

	# Assert: dual focus, 4.6: the ring stays where the keys left it
	assert_dict(_focus(view).current()).is_equal(held)
	assert_str(str(held.kind)).is_equal(FocusPresenter.KIND_BOSS_TOKEN)
	assert_bool((view.get("_inspect") as Control).visible).is_true()
	MatchViewHarness.close(view)


func test_the_default_stop_opens_no_inspect_so_a_mouse_player_sees_no_preview() -> void:
	# Arrange / Act
	var view: MatchView = await _open("turn1_player")

	# Assert
	assert_int(int(view.hand().get("_hovered"))).is_equal(-1)
	assert_dict(_focus(view).inspected()).is_empty()
	MatchViewHarness.close(view)


func test_the_ring_leaves_with_idle() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player", [], {"anim_speed": "normal"})
	MatchViewHarness.run(view, MatchViewHarness.FRAME_S)
	var active_in_idle: bool = _focus(view).get("_active")

	# Act
	MatchViewHarness.press_end_turn(view)
	MatchViewHarness.run(view, MatchViewHarness.FRAME_S)

	# Assert
	assert_bool(active_in_idle).is_true()
	assert_bool(_focus(view).get("_active")).is_false()
	MatchViewHarness.close(view)


func test_a_pad_direction_moves_focus_to_the_nearest_stop_that_way() -> void:
	# Arrange
	var view: MatchView = await _open("targeting_taunt")
	var focus: FocusPresenter = _focus(view)
	focus.focus_stop({"kind": InputRouter.STOP_END_TURN, "id": 0}, false)

	# Act: a synthetic `ui_up`; real pad hardware stays for the owner
	MatchViewHarness.action(view, &"ui_up")

	# Assert: straight up from End Turn is the boss's portrait
	assert_str(str(focus.current().kind)).is_equal(FocusPresenter.KIND_BOSS_PORTRAIT)
	MatchViewHarness.close(view)


func test_a_direction_with_nothing_that_way_leaves_focus_where_it_is() -> void:
	# Arrange
	var view: MatchView = await _open("targeting_taunt")
	var focus: FocusPresenter = _focus(view)
	focus.focus_stop({"kind": FocusPresenter.KIND_MENU, "id": 0}, false)
	var far_right: Dictionary = focus.current()

	# Act
	focus.move_direction(Vector2.RIGHT)

	# Assert
	assert_dict(focus.current()).is_equal(far_right)
	MatchViewHarness.close(view)
