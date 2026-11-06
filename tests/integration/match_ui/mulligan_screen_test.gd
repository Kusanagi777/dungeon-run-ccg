## The mulligan screen (match-ui U8, O6; design/ux/mulligan.md §5.1, §6; story 009).
extends GdUnitTestSuite

const PX: float = 2.0
const CARD_1_5X := Vector2(225, 315)
const CARD_1X := Vector2(150, 210)
const BAND := Rect2(278, 202, 723, 315)
const SATCHEL_FIRST_X: float = 233.0
const SATCHEL_PITCH: float = 166.0
const ROW_TOP: float = 202.0
const SAFE_LEFT: float = 208.0
const SAFE_RIGHT: float = 1072.0
const PRINTED_PORTER: int = 5


func _open(fixture: String, settings: Dictionary = {}) -> MatchView:
	var view: MatchView = await MatchViewHarness.open(self, fixture, [], settings)
	MatchViewHarness.run(view, MatchViewHarness.FRAME_S)
	return view


func _cards(view: MatchView) -> Array[CardFrame]:
	var out: Array[CardFrame] = []
	out.assign(view.mulligan().get("_cards"))
	return out


func _mask(bits: int, n: int) -> Array[bool]:
	var mask: Array[bool] = []
	for i: int in n:
		mask.append(bits & (1 << i) == 0)
	return mask


func _replaced_of(view: MatchView) -> Array:
	for event: Dictionary in (view.get("_controller") as MatchController).events_since(0):
		if str(event.type) == "mulligan_resolved":
			return event.payload.replaced_instance_ids
	return ["no mulligan_resolved"]


func test_o6_three_cards_stand_in_the_band_over_a_dark_table_with_confirm_on() -> void:
	# Arrange / Act
	var view: MatchView = await _open("mulligan")
	var cards: Array[CardFrame] = _cards(view)

	# Assert
	assert_int(cards.size()).is_equal(3)
	for card: CardFrame in cards:
		var rect: Rect2 = Rect2(card.global_position, card.size * card.scale)
		assert_float(rect.size.distance_to(CARD_1_5X)).is_less_equal(PX)
		assert_bool(BAND.grow(PX).encloses(rect)).override_failure_message(str(rect)).is_true()
	assert_object((view.get("_table") as ColorRect).color).is_equal(view.ui_context().color("table_dark"))
	assert_bool((view.mulligan().get("_confirm") as Button).disabled).is_false()
	MatchViewHarness.close(view)


func test_each_of_the_eight_subsets_sends_exactly_that_mask_and_is_accepted() -> void:
	for bits: int in 8:
		# Arrange
		var view: MatchView = await _open("mulligan")
		var sent: Array[Dictionary] = MatchViewHarness.spy_commands(view)
		var offered: Array = view.view_state().pending_mulligan
		var want: Array[bool] = _mask(bits, 3)
		var replaced: Array = []

		# Act: click on even subsets, number keys on odd
		for i: int in 3:
			if not want[i]:
				replaced.append(offered[i])
				if bits % 2 == 0:
					view.mulligan().toggle(i)
				else:
					MatchViewHarness.action(view, StringName("hand_%d" % (i + 1)))
		view.mulligan().confirm()
		MatchViewHarness.settle(view)

		# Assert
		assert_int(sent.size()).override_failure_message("subset %d" % bits).is_equal(1)
		assert_array(sent[0].keep_mask).override_failure_message("subset %d" % bits).is_equal(want)
		assert_array(_replaced_of(view)).override_failure_message("subset %d" % bits).is_equal(replaced)
		assert_that(view.view_state().pending_mulligan).is_null()
		MatchViewHarness.close(view)


func test_a_hand_of_five_sends_a_mask_of_five_for_all_32_subsets() -> void:
	for bits: int in 32:
		# Arrange
		var view: MatchView = await _open("mulligan_satchel")
		var sent: Array[Dictionary] = MatchViewHarness.spy_commands(view)
		var want: Array[bool] = _mask(bits, 5)

		# Act
		for i: int in 5:
			if not want[i]:
				MatchViewHarness.action(view, StringName("hand_%d" % (i + 1)))
		view.mulligan().confirm()
		MatchViewHarness.settle(view)

		# Assert
		assert_array(sent[0].keep_mask).override_failure_message("subset %d" % bits).is_equal(want)
		assert_array(MatchViewHarness.event_types(view)).contains(["mulligan_resolved"])
		MatchViewHarness.close(view)


func test_five_cards_sit_at_1x_inside_the_safe_band() -> void:
	# Arrange / Act
	var view: MatchView = await _open("mulligan_satchel")
	var cards: Array[CardFrame] = _cards(view)

	# Assert
	assert_int(cards.size()).is_equal(5)
	for i: int in 5:
		var rect: Rect2 = Rect2(cards[i].global_position, cards[i].size * cards[i].scale)
		assert_float(rect.position.distance_to(Vector2(SATCHEL_FIRST_X + SATCHEL_PITCH * i, ROW_TOP))).override_failure_message(str(rect)).is_less_equal(PX)
		assert_float(rect.size.distance_to(CARD_1X)).is_less_equal(PX)
		assert_float(rect.position.x).is_greater_equal(SAFE_LEFT)
		assert_float(rect.end.x).is_less_equal(SAFE_RIGHT)
	MatchViewHarness.close(view)


func test_the_boss_is_never_offered_a_mulligan() -> void:
	# Arrange / Act
	var view: MatchView = await _open("mulligan")
	var offers: int = 0
	for event: Dictionary in (view.get("_controller") as MatchController).events_since(0):
		if str(event.type) == "mulligan_offered":
			offers += 1
			assert_str(str(event.payload.side)).is_equal("player")

	# Assert
	assert_int(offers).is_equal(1)
	MatchViewHarness.close(view)


func test_a_discounted_card_shows_its_effective_cost_with_the_modified_stamp() -> void:
	# Arrange / Act: Quartermaster's Ledger over a printed-5 card
	var view: MatchView = await _open("mulligan_discount")
	var card: CardFrame = _cards(view)[0]
	var effective: int = int(view.ui_context().query.hand("player")[0].effective_cost)

	# Assert
	assert_int(card.printed_cost()).is_equal(PRINTED_PORTER)
	assert_int(effective).is_less(PRINTED_PORTER)
	assert_str((card.get("_cost_text") as Label).text).is_equal(str(effective))
	assert_bool(card.cost_modified()).is_true()
	assert_object((card.get("_cost_text") as Label).get_theme_color(&"font_color")).is_equal(view.ui_context().color("state_buff"))
	MatchViewHarness.close(view)


func test_focusing_a_discounted_card_shows_its_printed_cost() -> void:
	# Arrange
	var view: MatchView = await _open("mulligan_discount")

	# Act: focus opens on card 1
	var line: Label = view.mulligan().get("_printed")

	# Assert: mulligan.md §5.1, card 1 of 3 puts the panel at x 511 on the row top
	assert_bool(line.visible).is_true()
	assert_str(line.text).is_equal(tr("mulligan.printed_cost") % PRINTED_PORTER)
	assert_float(line.position.x).is_equal_approx(511.0, 1.0)
	assert_float(line.position.y).is_equal(ROW_TOP)
	MatchViewHarness.close(view)


func test_card_3_takes_the_printed_line_on_its_left() -> void:
	# Arrange
	var view: MatchView = await _open("mulligan_discount")

	# Act: card 3 is the other Porter
	view.mulligan().handle_action(MatchInput.PREVIOUS, -1)
	view.mulligan().handle_action(MatchInput.PREVIOUS, -1)

	# Assert
	var line: Label = view.mulligan().get("_printed")
	assert_bool(line.visible).is_true()
	assert_float(line.position.x).is_equal_approx(408.0, 1.0)
	MatchViewHarness.close(view)


func test_focusing_a_card_at_its_printed_cost_shows_no_such_line() -> void:
	# Arrange
	var view: MatchView = await _open("mulligan_discount")

	# Act: card 2 is the Cellar Guard, whose cost the Ledger does not touch
	view.mulligan().handle_action(MatchInput.NEXT, -1)

	# Assert
	assert_bool((view.mulligan().get("_printed") as Label).visible).is_false()
	MatchViewHarness.close(view)


func test_the_discounted_number_is_the_same_in_the_fan_after_the_drain() -> void:
	# Arrange
	var view: MatchView = await _open("mulligan_discount")
	var id: int = int((view.view_state().pending_mulligan as Array)[0])
	var shown: String = (_cards(view)[0].get("_cost_text") as Label).text

	# Act
	view.mulligan().confirm()
	MatchViewHarness.settle(view)

	# Assert
	assert_str((view.hand().card(id).get("_cost_text") as Label).text).is_equal(shown)
	MatchViewHarness.close(view)


func test_mulligan_resolved_flips_for_0_3_s_and_the_view_runs_playback_to_idle() -> void:
	# Arrange
	var view: MatchView = await _open("mulligan", {"anim_speed": "normal"})
	var flips: Array[float] = []
	view.queue().step_started.connect(func(step: AnimStep, d: float) -> void:
		if step.kind == AnimStep.MULLIGAN_FLIP:
			flips.append(d))
	var states: Array[String] = [String(view.router().view_state())]
	view.mulligan().toggle(0)

	# Act
	view.mulligan().confirm()
	MatchViewHarness.run(view, MatchViewHarness.FRAME_S)
	states.append(String(view.router().view_state()))
	MatchViewHarness.settle(view)
	states.append(String(view.router().view_state()))

	# Assert
	assert_array(flips).is_equal([0.3])
	assert_array(states).is_equal([String(InputRouter.STATE_MULLIGAN), String(InputRouter.STATE_PLAYBACK), String(InputRouter.STATE_IDLE)])
	assert_array(MatchViewHarness.sync_lines(view)).is_empty()
	MatchViewHarness.close(view)


func test_a_redrawn_discounted_card_flips_up_at_its_effective_cost() -> void:
	# Arrange: mulligan.md §8 reads the cost again when the flip starts. All three go back,
	# so the redraw holds Porters whatever the seed does
	var view: MatchView = await _open("mulligan_discount", {"anim_speed": "normal"})
	for i: int in 3:
		view.mulligan().toggle(i)
	var frames: Array[CardFrame] = _cards(view)
	var started: Array[AnimStep] = []
	view.queue().step_started.connect(func(step: AnimStep, _d: float) -> void:
		if step.kind == AnimStep.MULLIGAN_FLIP:
			started.append(step))
	view.mulligan().confirm()

	# Act: to the flip, and through it on its own tweens
	var cap: int = 600
	while started.is_empty() and cap > 0:
		MatchViewHarness.run(view, MatchViewHarness.FRAME_S)
		cap -= 1
	var drawn: Array = view.ui_context().query.hand("player")
	for tween: Tween in (view.mulligan().get("_step_tweens") as Dictionary)[started[0]]:
		tween.custom_step(0.2)

	# Assert
	var discounted: int = 0
	for i: int in 3:
		assert_str((frames[i].get("_cost_text") as Label).text).is_equal(str(int(drawn[i].effective_cost)))
		if int(drawn[i].effective_cost) != frames[i].printed_cost():
			discounted += 1
	assert_int(discounted).override_failure_message("no Porter in the redraw").is_greater(0)
	view.queue().skip_all()
	MatchViewHarness.close(view)


func test_a_second_confirm_sends_nothing() -> void:
	# Arrange
	var view: MatchView = await _open("mulligan", {"anim_speed": "normal"})
	var sent: Array[Dictionary] = MatchViewHarness.spy_commands(view)

	# Act
	view.mulligan().confirm()
	view.mulligan().confirm()

	# Assert
	assert_int(sent.size()).is_equal(1)
	view.queue().skip_all()
	MatchViewHarness.close(view)


func test_keys_walk_the_cards_then_confirm_and_a_confirm_acts_on_the_stop() -> void:
	# Arrange
	var view: MatchView = await _open("mulligan")
	var sent: Array[Dictionary] = MatchViewHarness.spy_commands(view)

	# Act: `Enter` on card 1 toggles it, then to Confirm
	MatchViewHarness.action(view, &"ui_accept")
	var toggled: bool = view.mulligan().keep_mask()[0]
	MatchViewHarness.action(view, &"ui_focus_prev")
	var at_confirm: int = view.mulligan().focused()
	MatchViewHarness.action(view, &"ui_accept")

	# Assert
	assert_bool(toggled).is_false()
	assert_int(at_confirm).is_equal(3)
	assert_int(sent.size()).is_equal(1)
	assert_array(sent[0].keep_mask).is_equal([false, true, true])
	MatchViewHarness.close(view)


func test_the_screen_has_no_cancel_esc_goes_to_the_pause_menu() -> void:
	# Arrange
	var view: MatchView = await _open("mulligan")

	# Act
	MatchViewHarness.action(view, &"ui_cancel")

	# Assert
	assert_bool(view.mulligan().is_open()).is_true()
	assert_bool((view.get("_pause") as PauseMenu).is_open()).is_true()
	MatchViewHarness.close(view)


func test_a_number_past_the_cards_toggles_nothing() -> void:
	# Arrange
	var view: MatchView = await _open("mulligan")

	# Act
	MatchViewHarness.action(view, &"hand_7")

	# Assert
	assert_array(view.mulligan().keep_mask()).is_equal([true, true, true])
	MatchViewHarness.close(view)
