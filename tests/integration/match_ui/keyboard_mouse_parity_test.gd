## O17, headless half (match-ui U5; story 017 AC-4): every action on `turn1_player`,
## `targeting_taunt` and `mulligan`, reached by keys alone and by mouse alone, leaves the
## same `MatchViewState` and the same `InputRouter` state. The capture half and real pad
## hardware stay with the owner.
extends GdUnitTestSuite


func _open(fixture: String) -> MatchView:
	var view: MatchView = await MatchViewHarness.open(self, fixture)
	await MatchViewHarness.frames(view, 2)
	MatchViewHarness.run(view, MatchViewHarness.FRAME_S)
	return view


func _state(view: MatchView) -> Dictionary:
	MatchViewHarness.settle(view)
	MatchViewHarness.run(view, MatchViewHarness.FRAME_S)
	var session: Dictionary = view.router().session()
	return {
		"view": view.view_state().snapshot(), "router": String(view.router().view_state()),
		"phase": String(session.get("phase", "")), "source": session.get("source", {}),
	}


## [param moves] says the action leaves a mark: a pair of no-ops must not pass as parity.
func _assert_parity(fixture: String, by_keys: Callable, by_mouse: Callable, moves: bool = true) -> void:
	# Arrange
	var keys: MatchView = await _open(fixture)
	var mouse: MatchView = await _open(fixture)
	var before: Dictionary = _state(keys)

	# Act
	by_keys.call(keys)
	by_mouse.call(mouse)
	var key_state: Dictionary = _state(keys)
	var mouse_state: Dictionary = _state(mouse)

	# Assert
	assert_dict(key_state).is_equal(mouse_state)
	assert_array(MatchViewHarness.event_types(keys)).is_equal(MatchViewHarness.event_types(mouse))
	assert_bool(key_state != before).override_failure_message("the action changed nothing").is_equal(moves)
	MatchViewHarness.close(keys)
	MatchViewHarness.close(mouse)


func _power_point(view: MatchView) -> Vector2:
	return (view.find_child("PlayerPanel", true, false) as HeroPresenter).power_rect().get_center()


func _token_point(view: MatchView, row: String, id: int) -> Vector2:
	return (view.find_child(row, true, false) as BoardPresenter).center_of(id)


func _first_playable_slot(view: MatchView) -> int:
	var hand: Array = view.ui_context().query.hand("player")
	for i: int in hand.size():
		if hand[i].playable and not MatchViewHarness.legal(view, MatchRecords.CMD_PLAY_CARD).filter(
			func(c: Dictionary) -> bool: return int(c.hand_index) == i and c.get("position") != null).is_empty():
			return i
	return -1


func test_o17_playing_a_minion_on_turn1_player() -> void:
	await _assert_parity("turn1_player",
		func(view: MatchView) -> void:
			var slot: int = _first_playable_slot(view)
			MatchViewHarness.action(view, StringName("hand_%d" % (slot + 1)))
			MatchViewHarness.action(view, &"ui_accept"),
		func(view: MatchView) -> void:
			var at: Vector2 = MatchViewHarness.card_point(view, MatchViewHarness.hand_id(view, _first_playable_slot(view)))
			MatchViewHarness.click(view, at)
			MatchViewHarness.click(view, Vector2(640, 400)))


func test_o17_selecting_a_card_leaves_the_same_session_either_way() -> void:
	await _assert_parity("turn1_player",
		func(view: MatchView) -> void:
			MatchViewHarness.action(view, StringName("hand_%d" % (_first_playable_slot(view) + 1))),
		func(view: MatchView) -> void:
			MatchViewHarness.click(view, MatchViewHarness.card_point(view, MatchViewHarness.hand_id(view, _first_playable_slot(view)))))


func test_o17_cancelling_a_selection_with_esc_and_with_rmb() -> void:
	await _assert_parity("turn1_player",
		func(view: MatchView) -> void:
			MatchViewHarness.action(view, StringName("hand_%d" % (_first_playable_slot(view) + 1)))
			MatchViewHarness.action(view, &"ui_cancel"),
		func(view: MatchView) -> void:
			MatchViewHarness.click(view, MatchViewHarness.card_point(view, MatchViewHarness.hand_id(view, _first_playable_slot(view))))
			MatchViewHarness.click(view, Vector2(640, 400), MOUSE_BUTTON_RIGHT),
		false)


func test_o17_ending_the_turn() -> void:
	await _assert_parity("turn1_player",
		func(view: MatchView) -> void:
			view.get("_focus").call("focus_stop", {"kind": InputRouter.STOP_END_TURN, "id": 0}, false)
			view.router().set_end_turn_arm(0)
			MatchViewHarness.action(view, &"skip"),
		func(view: MatchView) -> void:
			MatchViewHarness.press_end_turn(view))


func test_o17_attacking_the_taunt() -> void:
	await _assert_parity("targeting_taunt",
		func(view: MatchView) -> void:
			MatchViewHarness.action(view, &"attacker_mode")
			MatchViewHarness.action(view, &"hand_1")
			MatchViewHarness.action(view, &"ui_accept"),
		func(view: MatchView) -> void:
			var attacker: int = int(view.view_state().side(&"player").board[0].entity_id)
			var taunt: int = int(view.view_state().side(&"boss").board[2].entity_id)
			MatchViewHarness.click(view, _token_point(view, "PlayerRow", attacker))
			MatchViewHarness.click(view, _token_point(view, "BossRow", taunt)))


func test_o17_casting_the_hero_power() -> void:
	await _assert_parity("targeting_taunt",
		func(view: MatchView) -> void:
			MatchViewHarness.action(view, &"hero_power")
			MatchViewHarness.action(view, &"ui_accept"),
		func(view: MatchView) -> void:
			MatchViewHarness.click(view, _power_point(view))
			MatchViewHarness.click(view, _power_point(view)))


func test_o17_a_mulligan_with_two_cards_replaced() -> void:
	await _assert_parity("mulligan",
		func(view: MatchView) -> void:
			MatchViewHarness.action(view, &"hand_1")
			MatchViewHarness.action(view, &"hand_3")
			MatchViewHarness.action(view, &"ui_focus_prev")
			MatchViewHarness.action(view, &"ui_focus_next")
			MatchViewHarness.action(view, &"ui_focus_next")
			MatchViewHarness.action(view, &"ui_accept"),
		func(view: MatchView) -> void:
			(view.mulligan().get("_pills") as Array)[0].pressed.emit()
			(view.mulligan().get("_pills") as Array)[2].pressed.emit()
			(view.mulligan().get("_confirm") as Button).pressed.emit())


func test_o17_tabbing_targets_reaches_every_stop_a_mouse_can() -> void:
	# Arrange
	var view: MatchView = await _open("targeting_taunt")
	MatchViewHarness.action(view, &"hero_power")
	MatchViewHarness.action(view, &"ui_cancel")
	var attacker: int = int(view.view_state().side(&"player").board[0].entity_id)
	view.router().intent(InputRouter.INTENT_SELECT, {"source": {"kind": InputRouter.SOURCE_ATTACKER, "id": attacker}, "pos": Vector2.ZERO, "entered_by": TargetingSession.ENTERED_KEY})
	var targets: Dictionary = view.router().session().targets
	var seen: Dictionary = {}

	# Act
	for i: int in targets.size():
		seen[int(view.router().session().hovered)] = true
		MatchViewHarness.action(view, &"ui_focus_next")

	# Assert
	assert_dict(seen).is_equal(targets)
	view.router().intent(InputRouter.INTENT_CANCEL)
	MatchViewHarness.close(view)
