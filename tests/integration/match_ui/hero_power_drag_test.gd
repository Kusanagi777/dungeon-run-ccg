## The hero power dragged to the cast zone (match-ui States `Dragging`, U5; targeting.md §6,
## §7.4; story 025 AC-1 to AC-3). `treasure_tray` has the power `Ready`, `turn1_player` has it
## `Blocked`, and `first_playable` reaches it on the player's second turn.
extends GdUnitTestSuite

const IN_ZONE := Vector2(800, 220)
const OUTSIDE := Vector2(1120, 120)
const SMALL_MOVE := Vector2(4, 0)


func _ready_view() -> MatchView:
	var view: MatchView = await MatchViewHarness.open(self, "treasure_tray")
	await MatchViewHarness.frames(view, 2)
	MatchViewHarness.run(view, MatchViewHarness.FRAME_S)
	return view


func _power_at(view: MatchView) -> Vector2:
	return (view.find_child("PlayerPanel", true, false) as HeroPresenter).power_rect().get_center()


func _lift(view: MatchView, to: Vector2) -> void:
	MatchViewHarness.send(view, MatchViewHarness.mouse_button(_power_at(view), MOUSE_BUTTON_LEFT, true, false))
	MatchViewHarness.send(view, MatchViewHarness.motion(to))


func test_a_press_and_move_enters_dragging_with_the_zone_lit_and_no_arrow() -> void:
	# Arrange
	var view: MatchView = await _ready_view()
	var arrow: TargetingArrow = view.find_child("TargetingArrow", true, false)
	var panel: HeroPresenter = view.find_child("PlayerPanel", true, false)
	var rest: Vector2 = (panel.get("_power") as Control).position

	# Act
	_lift(view, IN_ZONE)
	view.call("_process", 0.0)

	# Assert
	assert_str(String(view.router().view_state())).is_equal(String(InputRouter.STATE_DRAGGING))
	assert_str(String(view.router().session().phase)).is_equal(String(InputRouter.SESSION_CAST))
	assert_object(arrow.get("_zone")).is_equal(view.ui_context().rect("cast_zone"))
	assert_bool(arrow.is_active()).is_false()
	assert_bool((view.get("_end_turn") as Button).disabled).is_true()
	assert_float(rest.y - (panel.get("_power") as Control).position.y).is_equal(float(view.ui_context().config.hero.power_lift_px))
	view.router().intent(InputRouter.INTENT_CANCEL)
	MatchViewHarness.close(view)


func test_a_release_in_the_zone_casts_once_with_no_target() -> void:
	# Arrange
	var view: MatchView = await _ready_view()
	var sent: Array[Dictionary] = MatchViewHarness.spy_commands(view)

	# Act
	MatchViewHarness.drag(view, _power_at(view), IN_ZONE)
	MatchViewHarness.settle(view)

	# Assert
	assert_int(sent.size()).is_equal(1)
	assert_str(str(sent[0].type)).is_equal(MatchRecords.CMD_USE_HERO_POWER)
	assert_that(sent[0].get("target_id")).is_null()
	assert_array(MatchViewHarness.event_types(view)).contains(["hero_power_used"])
	MatchViewHarness.close(view)


func test_a_release_over_a_friendly_token_in_the_zone_still_casts() -> void:
	# Arrange: the attacker sits inside the cast zone, and a release never re-selects
	var view: MatchView = await MatchViewHarness.open(self, "targeting_taunt")
	await MatchViewHarness.frames(view, 2)
	MatchViewHarness.run(view, MatchViewHarness.FRAME_S)
	var row: BoardPresenter = view.find_child("PlayerRow", true, false)
	var token: Vector2 = row.center_of(int(view.view_state().side(&"player").board[0].entity_id))
	var sent: Array[Dictionary] = MatchViewHarness.spy_commands(view)

	# Act
	MatchViewHarness.drag(view, _power_at(view), token)

	# Assert
	assert_int(sent.size()).is_equal(1)
	assert_str(str(sent[0].type)).is_equal(MatchRecords.CMD_USE_HERO_POWER)
	MatchViewHarness.close(view)


func test_a_release_outside_the_zone_cancels_with_no_event() -> void:
	# Arrange
	var view: MatchView = await _ready_view()
	var before: int = MatchViewHarness.event_types(view).size()
	var sent: Array[Dictionary] = MatchViewHarness.spy_commands(view)

	# Act
	MatchViewHarness.drag(view, _power_at(view), OUTSIDE)

	# Assert
	assert_array(sent).is_empty()
	assert_int(MatchViewHarness.event_types(view).size()).is_equal(before)
	MatchViewHarness.close(view)


func test_rmb_and_esc_cancel_the_drag() -> void:
	for cancel: Callable in [
		func(view: MatchView) -> void: MatchViewHarness.send(view, MatchViewHarness.mouse_button(IN_ZONE, MOUSE_BUTTON_RIGHT, true, false)),
		func(view: MatchView) -> void: MatchViewHarness.action(view, &"ui_cancel"),
	]:
		# Arrange
		var view: MatchView = await _ready_view()
		var sent: Array[Dictionary] = MatchViewHarness.spy_commands(view)
		_lift(view, IN_ZONE)

		# Act
		cancel.call(view)
		MatchViewHarness.send(view, MatchViewHarness.mouse_button(IN_ZONE, MOUSE_BUTTON_LEFT, false, false))

		# Assert
		assert_array(sent).is_empty()
		assert_bool(view.router().in_session()).is_false()
		MatchViewHarness.close(view)


func test_a_press_and_release_under_the_threshold_submits_nothing() -> void:
	# Arrange
	var view: MatchView = await _ready_view()
	var sent: Array[Dictionary] = MatchViewHarness.spy_commands(view)
	var at: Vector2 = _power_at(view)

	# Act
	MatchViewHarness.send(view, MatchViewHarness.mouse_button(at, MOUSE_BUTTON_LEFT, true, false))
	MatchViewHarness.send(view, MatchViewHarness.motion(at + SMALL_MOVE))
	MatchViewHarness.send(view, MatchViewHarness.mouse_button(at + SMALL_MOVE, MOUSE_BUTTON_LEFT, false, false))

	# Assert
	assert_array(sent).is_empty()
	assert_bool(view.router().dragging()).is_false()
	MatchViewHarness.close(view)


func test_a_blocked_power_starts_no_drag_and_builds_no_command() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player")
	await MatchViewHarness.frames(view, 2)
	MatchViewHarness.run(view, MatchViewHarness.FRAME_S)
	var arrow: TargetingArrow = view.find_child("TargetingArrow", true, false)
	var sent: Array[Dictionary] = MatchViewHarness.spy_commands(view)

	# Act
	_lift(view, IN_ZONE)

	# Assert
	assert_bool(view.router().dragging()).is_false()
	assert_object(arrow.get("_zone")).is_equal(Rect2())
	assert_array(sent).is_empty()
	MatchViewHarness.close(view)


func test_a_used_power_starts_no_drag() -> void:
	# Arrange
	var view: MatchView = await _ready_view()
	MatchViewHarness.drag(view, _power_at(view), IN_ZONE)
	MatchViewHarness.settle(view)
	MatchViewHarness.run(view, MatchViewHarness.FRAME_S)

	# Act
	_lift(view, IN_ZONE)

	# Assert
	assert_bool(view.router().dragging()).is_false()
	MatchViewHarness.close(view)


func test_no_drag_starts_outside_idle() -> void:
	# Arrange: the boss's turn
	var view: MatchView = await MatchViewHarness.open(self, "treasure_tray", [], {"anim_speed": "normal"})
	await MatchViewHarness.frames(view, 2)
	MatchViewHarness.run(view, MatchViewHarness.FRAME_S)
	MatchViewHarness.press_end_turn(view)
	MatchViewHarness.run(view, MatchViewHarness.FRAME_S)

	# Act
	view.router().intent(InputRouter.INTENT_DRAG_START, {"source": {"kind": InputRouter.SOURCE_HERO_POWER, "id": -1}, "pos": IN_ZONE})

	# Assert
	assert_bool(view.router().in_session()).is_false()
	MatchViewHarness.close(view)


func test_router_intents_on_first_playable_cast_the_power_and_it_reaches_the_view() -> void:
	# Arrange: keep the opening hand, pass one turn, and arrive at two mana
	var view: MatchView = await MatchViewHarness.open(self, "first_playable")
	await MatchViewHarness.frames(view, 2)
	view.router().intent(InputRouter.INTENT_MULLIGAN_CONFIRM, {"keep_mask": [true, true, true]})
	MatchViewHarness.settle(view)
	MatchViewHarness.run(view, MatchViewHarness.FRAME_S)
	view.router().intent(InputRouter.INTENT_END_TURN)
	MatchViewHarness.settle(view)
	MatchViewHarness.run(view, MatchViewHarness.FRAME_S)
	var source: Dictionary = {"kind": InputRouter.SOURCE_HERO_POWER, "id": -1}

	# Act
	view.router().intent(InputRouter.INTENT_DRAG_START, {"source": source, "pos": _power_at(view)})
	view.router().intent(InputRouter.INTENT_DRAG_MOVE, {"pos": IN_ZONE})
	view.router().intent(InputRouter.INTENT_DRAG_RELEASE, {"pos": IN_ZONE})
	MatchViewHarness.settle(view)

	# Assert
	assert_array(MatchViewHarness.event_types(view)).contains(["hero_power_used"])
	assert_str(str(view.view_state().side(&"player").hero.power_state)).is_equal(MatchViewState.POWER_USED)
	MatchViewHarness.close(view)
