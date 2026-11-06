## The Choice overlay on real fixtures (match-ui O7, U9; story 013 AC-2, AC-3).
extends GdUnitTestSuite

const ROW := Rect2(278, 202, 723, 315)
const PX: float = 2.0
const THREE: int = 3
const BOSS_LABEL_S: float = 0.4


func _open(fixture: String, settings: Dictionary = {}) -> MatchView:
	var view: MatchView = await MatchViewHarness.open(self, fixture, [], settings)
	MatchViewHarness.run(view, MatchViewHarness.FRAME_S)
	return view


func _click_option(view: MatchView, index: int) -> void:
	view.choice().call("_on_option_input", MatchViewHarness.mouse_button(Vector2.ZERO, MOUSE_BUTTON_LEFT, true, false), index)


func test_o7_three_cards_sit_in_the_row_over_a_dim_table_with_end_turn_off() -> void:
	# Arrange / Act
	var view: MatchView = await _open("choice_discover")
	var rects: Array = view.choice().get("_rects")

	# Assert
	assert_int(rects.size()).is_equal(THREE)
	for rect: Rect2 in rects:
		assert_float(rect.size.x).is_equal(225.0)
		assert_float(rect.size.y).is_equal(315.0)
		assert_bool(ROW.grow(PX).encloses(rect)).override_failure_message(str(rect)).is_true()
	assert_object((view.get("_table") as ColorRect).color).is_equal(view.ui_context().color("table_dark"))
	assert_bool((view.get("_end_turn") as Button).disabled).is_true()
	MatchViewHarness.close(view)


func test_o7_choose_one_draws_labelled_plates() -> void:
	# Arrange / Act
	var view: MatchView = await _open("choice_choose_one")
	var options: Array = view.choice().get("_options")

	# Assert: two options on this card, each a plate
	assert_int(options.size()).is_equal(view.view_state().pending_choice.options.size())
	for option: Control in options:
		assert_object(option).is_instanceof(Panel)
		assert_str((option.get_child(0) as Label).text).is_not_empty()
	MatchViewHarness.close(view)


func test_a_click_selects_and_confirm_sends_exactly_one_choose() -> void:
	# Arrange
	var view: MatchView = await _open("choice_discover")
	var sent: Array[Dictionary] = MatchViewHarness.spy_commands(view)
	var confirm: Button = view.choice().get("_confirm")
	var off_before: bool = confirm.disabled
	var emitted: Array[int] = []
	view.choice().chosen.connect(func(index: int) -> void: emitted.append(index))

	# Act
	_click_option(view, 1)
	confirm.pressed.emit()
	confirm.pressed.emit()
	MatchViewHarness.settle(view)

	# Assert: the overlay holds it itself, not only the router behind it
	assert_bool(off_before).is_true()
	assert_int(sent.size()).is_equal(1)
	assert_array(emitted).is_equal([1])
	assert_str(str(sent[0].type)).is_equal(MatchRecords.CMD_CHOOSE)
	assert_int(int(sent[0].option_index)).is_equal(1)
	assert_that(view.view_state().pending_choice).is_null()
	assert_bool(view.choice().is_open()).is_false()
	MatchViewHarness.close(view)


func test_a_number_key_selects_and_enter_sends() -> void:
	# Arrange
	var view: MatchView = await _open("choice_discover")
	var sent: Array[Dictionary] = MatchViewHarness.spy_commands(view)

	# Act
	MatchViewHarness.action(view, &"hand_3")
	var picked: int = view.choice().selected()
	MatchViewHarness.action(view, &"ui_accept")

	# Assert
	assert_int(picked).is_equal(2)
	assert_int(sent.size()).is_equal(1)
	assert_int(int(sent[0].option_index)).is_equal(2)
	MatchViewHarness.close(view)


func test_enter_on_an_unselected_focus_selects_before_it_sends() -> void:
	# Arrange
	var view: MatchView = await _open("choice_discover")
	var sent: Array[Dictionary] = MatchViewHarness.spy_commands(view)

	# Act
	MatchViewHarness.action(view, &"ui_right")
	MatchViewHarness.action(view, &"ui_accept")

	# Assert
	assert_int(view.choice().selected()).is_equal(1)
	assert_array(sent).is_empty()
	MatchViewHarness.close(view)


func test_a_number_past_the_options_selects_nothing() -> void:
	# Arrange
	var view: MatchView = await _open("choice_choose_one")

	# Act
	MatchViewHarness.action(view, &"hand_3")

	# Assert: two plates
	assert_int(view.choice().selected()).is_equal(OverlayPresenter.NO_OPTION)
	MatchViewHarness.close(view)


func test_the_close_plays_its_0_15_s_step_at_normal() -> void:
	# Arrange
	var view: MatchView = await _open("choice_discover", {"anim_speed": "normal"})
	var durations: Dictionary = {}
	view.queue().step_started.connect(func(step: AnimStep, d: float) -> void: durations[step.kind] = d)
	_click_option(view, 0)

	# Act
	(view.choice().get("_confirm") as Button).pressed.emit()
	MatchViewHarness.settle(view)

	# Assert
	assert_float(float(durations[AnimStep.OVERLAY_CLOSE])).is_equal_approx(0.15, 0.001)
	MatchViewHarness.close(view)


func test_a_boss_choice_shows_the_label_for_its_step_and_draws_no_options() -> void:
	# Arrange
	var view: MatchView = await _open("turn1_player", {"anim_speed": "normal"})
	var durations: Dictionary = {}
	view.queue().step_started.connect(func(step: AnimStep, d: float) -> void: durations[step.kind] = d)

	# Act
	MatchViewHarness.inject(view, "discover_offered", {"side": "boss", "kind": "discover", "option_card_ids": ["a", "b", "c"], "source_id": 9, "effect_id": "e"})
	MatchViewHarness.inject(view, "choice_requested", {"side": "boss", "kind": "discover", "options": ["a", "b", "c"], "source_id": 9, "effect_id": "e"})
	MatchViewHarness.run(view, MatchViewHarness.FRAME_S)
	var shown: bool = (view.find_child("IntentBanner", true, false).get("_discovers") as Label).visible

	# Assert
	assert_float(float(durations[AnimStep.BOSS_DISCOVERS])).is_equal_approx(BOSS_LABEL_S, 0.001)
	assert_bool(shown).is_true()
	assert_bool(view.choice().is_open()).is_false()
	assert_array(view.choice().get("_options")).is_empty()
	view.queue().skip_all()
	assert_bool((view.find_child("IntentBanner", true, false).get("_discovers") as Label).visible).is_false()
	MatchViewHarness.close(view)
