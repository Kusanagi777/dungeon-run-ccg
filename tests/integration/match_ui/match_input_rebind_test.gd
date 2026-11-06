## Rebinds in a match (accessibility Motor "Full input remapping"; ADR-0004 addendum;
## `MatchInput`, `InputBindings`): a rebound action works at once, its old key goes dead,
## and that holds on the `Ended` path too. Key events go in as the view receives them.
extends GdUnitTestSuite

const NEW_KEY: Key = KEY_K
const ARM_S: float = 0.3
const FRAME_S: float = 1.0 / 60.0

var _bindings: InputBindings


func before_test() -> void:
	_bindings = InputBindings.new()


func after_test() -> void:
	_bindings.apply({})


func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


func _bind(action: String, keycode: Key) -> void:
	var stored: Dictionary = InputBindings.to_dict(_key(keycode))
	_bindings.apply({action: [stored]})


func _open(fixture: String) -> MatchView:
	var view: MatchView = await MatchViewHarness.open(self, fixture)
	MatchViewHarness.run(view, FRAME_S)
	return view


func test_a_rebound_feed_toggle_opens_the_drawer_and_the_old_key_is_dead() -> void:
	# Arrange
	var view: MatchView = await _open("turn1_player")
	_bind("feed_toggle", NEW_KEY)

	# Act
	MatchViewHarness.send(view, _key(KEY_L))
	var after_old: bool = view.feed().is_open()
	MatchViewHarness.send(view, _key(NEW_KEY))

	# Assert
	assert_bool(after_old).is_false()
	assert_bool(view.feed().is_open()).is_true()
	MatchViewHarness.close(view)


func test_the_rebound_key_closes_the_drawer_too() -> void:
	# Arrange
	var view: MatchView = await _open("turn1_player")
	_bind("feed_toggle", NEW_KEY)
	view.feed().open()

	# Act
	MatchViewHarness.send(view, _key(NEW_KEY))

	# Assert
	assert_bool(view.feed().is_open()).is_false()
	MatchViewHarness.close(view)


func test_a_rebound_feed_toggle_works_in_ended_and_the_old_key_does_not() -> void:
	# Arrange
	var view: MatchView = await _open("match_end_victory")
	MatchViewHarness.settle(view)
	_bind("feed_toggle", NEW_KEY)

	# Act
	MatchViewHarness.send(view, _key(KEY_L))
	var after_old: bool = view.feed().is_open()
	MatchViewHarness.send(view, _key(NEW_KEY))

	# Assert
	assert_bool(after_old).is_false()
	assert_bool(view.feed().is_open()).is_true()
	MatchViewHarness.close(view)


func test_a_rebound_feed_toggle_works_during_the_boss_turn() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player", [], {"anim_speed": "normal"})
	MatchViewHarness.run(view, FRAME_S)
	_bind("feed_toggle", NEW_KEY)
	MatchViewHarness.press_end_turn(view)
	MatchViewHarness.run(view, FRAME_S)

	# Act
	MatchViewHarness.send(view, _key(NEW_KEY))

	# Assert
	assert_bool(view.feed().is_open()).is_true()
	view.queue().skip_all()
	MatchViewHarness.close(view)


func test_a_rebound_hand_slot_picks_that_card() -> void:
	# Arrange
	var view: MatchView = await _open("treasure_tray")
	_bind("hand_2", NEW_KEY)

	# Act
	MatchViewHarness.send(view, _key(NEW_KEY))

	# Assert
	assert_int(int(view.router().session().source.id)).is_equal(MatchViewHarness.hand_id(view, 1))
	view.router().intent(InputRouter.INTENT_CANCEL)
	MatchViewHarness.close(view)


func test_a_rebound_hero_power_key_opens_it() -> void:
	# Arrange
	var view: MatchView = await _open("treasure_tray")
	_bind("hero_power", NEW_KEY)

	# Act
	MatchViewHarness.send(view, _key(KEY_H))
	var by_old: bool = view.router().in_session()
	MatchViewHarness.send(view, _key(NEW_KEY))

	# Assert
	assert_bool(by_old).is_false()
	assert_str(str(view.router().session().source.kind)).is_equal(InputRouter.SOURCE_HERO_POWER)
	view.router().intent(InputRouter.INTENT_CANCEL)
	MatchViewHarness.close(view)


func test_a_rebound_end_turn_key_ends_the_turn_like_space() -> void:
	# Arrange: focus on End Turn, past the arm guard
	var view: MatchView = await _open("boss_turn_playback")
	view.router().set_end_turn_arm(0)
	_bind("end_turn", NEW_KEY)
	var sent: Array[Dictionary] = MatchViewHarness.spy_commands(view)

	# Act
	MatchViewHarness.send(view, _key(NEW_KEY))

	# Assert
	assert_int(sent.size()).is_equal(1)
	assert_str(str(sent[0].type)).is_equal(MatchRecords.CMD_END_TURN)
	MatchViewHarness.close(view)


func test_a_rebound_skip_key_skips_a_busy_queue() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player", [], {"anim_speed": "normal"})
	MatchViewHarness.run(view, FRAME_S)
	_bind("skip", NEW_KEY)
	MatchViewHarness.press_end_turn(view)
	MatchViewHarness.run(view, FRAME_S)
	assert_bool(view.queue().is_idle()).is_false()

	# Act
	MatchViewHarness.send(view, _key(NEW_KEY))

	# Assert
	assert_bool(view.queue().is_idle()).is_true()
	MatchViewHarness.close(view)


func test_with_skip_rebound_space_never_becomes_a_confirm() -> void:
	# Arrange: `Space` also sits on `ui_accept`, and a focused card opens on `Enter` alone
	var view: MatchView = await _open("turn1_player")
	_bind("skip", NEW_KEY)

	# Act
	MatchViewHarness.send(view, _key(KEY_SPACE))

	# Assert: targeting.md §7.2, `Space` is not confirm
	assert_bool(view.router().in_session()).is_false()
	MatchViewHarness.close(view)


func test_esc_cannot_be_rebound() -> void:
	# Arrange
	var view: MatchView = await _open("turn1_player")
	_bind("ui_cancel", NEW_KEY)

	# Act
	MatchViewHarness.send(view, _key(NEW_KEY))
	var by_new: bool = (view.get("_pause") as PauseMenu).is_open()
	MatchViewHarness.send(view, _key(KEY_ESCAPE))

	# Assert
	assert_bool(by_new).is_false()
	assert_bool((view.get("_pause") as PauseMenu).is_open()).is_true()
	MatchViewHarness.close(view)


func test_a_key_echo_is_no_second_press() -> void:
	# Arrange
	var view: MatchView = await _open("turn1_player")
	var echo: InputEventKey = _key(KEY_L)
	echo.echo = true

	# Act
	MatchViewHarness.send(view, echo)

	# Assert
	assert_bool(view.feed().is_open()).is_false()
	MatchViewHarness.close(view)


func test_ended_takes_enter_as_a_continue_after_the_guard_and_the_mouse_too() -> void:
	# Arrange
	var view: MatchView = await _open("match_end_victory")
	MatchViewHarness.settle(view)
	var finished: Array[Dictionary] = []
	view.match_view_finished.connect(func(result: Dictionary) -> void: finished.append(result))
	MatchViewHarness.run(view, ARM_S + FRAME_S)

	# Act
	MatchViewHarness.send(view, _key(KEY_ENTER))

	# Assert
	assert_int(finished.size()).is_equal(1)
	MatchViewHarness.close(view)
