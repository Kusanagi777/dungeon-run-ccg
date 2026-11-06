## The intent banner and the boss turn on screen (match-ui O8, O9, U6; DD-X23; hud.md §12;
## story 015). The pacing maths has its own suite, `boss_turn_pacing_test`: this one is what
## the player sees of it.
extends GdUnitTestSuite

const PLATE := Rect2(980, 52, 276, 36)
const HINT := Rect2(980, 90, 152, 20)
const BOSS_TURN_SEQ: int = 203
const FRAME_S: float = 1.0 / 60.0
const BEAT_S: float = 0.3
const THINKING_S: float = 0.5
const HINT_DELAY_S: float = 1.0
const PLAN_CHANGED_S: float = 1.2
## The turn counts both sides: the view has run on to the player's next one by now.
const BOSS_FIRST_TURN: int = 2


func _banner(view: MatchView) -> IntentBanner:
	return view.find_child("IntentBanner", true, false)


func test_o8_a_full_intent_shows_icon_label_and_reticle_at_the_plate_rect() -> void:
	# Arrange / Act
	var view: MatchView = await MatchViewHarness.open(self, "boss_intent_full")
	await MatchViewHarness.frames(view, 2)
	MatchViewHarness.run(view, FRAME_S)
	var banner: IntentBanner = _banner(view)
	var intent: Dictionary = view.view_state().intent

	# Assert
	assert_object(banner.plate_rect()).is_equal(PLATE)
	assert_str((banner.get("_icon") as Label).text).is_not_empty()
	assert_str(banner.label_text()).is_equal(tr("intent.%s" % str(intent.intent_key)))
	assert_bool((banner.get("_reticle") as Control).visible).is_true()
	var reticle: Control = banner.get("_reticle")
	assert_object(reticle.position + reticle.size / 2.0).is_equal(view.call("_locate", int(intent.target_id)))
	MatchViewHarness.close(view)


func test_o8_a_full_intent_shows_its_amount() -> void:
	# Arrange / Act: this forecast is `attack_face` for 5
	var view: MatchView = await MatchViewHarness.open(self, "boss_turn_playback")

	# Assert
	assert_str((_banner(view).get("_amount") as Label).text).is_equal(str(int(view.view_state().intent.amount)))
	MatchViewHarness.close(view)


func test_o8_kept_false_shows_plan_changed_for_its_time_then_the_new_intent() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "boss_intent_plan_changed", [], {"anim_speed": "normal"})
	MatchViewHarness.run(view, FRAME_S)
	var banner: IntentBanner = _banner(view)
	var payload: Dictionary = {"boss_id": "boss_torchbearer", "intent_key": "develop_board", "target_id": null, "amount": null, "kept": false, "effective_mode": "full"}

	# Act
	MatchViewHarness.inject(view, "ai_intent_committed", payload)
	MatchViewHarness.settle(view)
	var during: String = banner.label_text()
	MatchViewHarness.run(view, PLAN_CHANGED_S + FRAME_S)

	# Assert
	assert_str(during).is_equal(tr(IntentBanner.KEY_PLAN_CHANGED))
	assert_str(banner.label_text()).is_equal(tr("intent.develop_board"))
	assert_bool(view.sfx.played(SfxStub.CUE_PLAN_CHANGED)).is_true()
	MatchViewHarness.close(view)


func test_o8_hidden_shows_a_question_plate_with_no_amount_or_reticle() -> void:
	# Arrange / Act
	var view: MatchView = await MatchViewHarness.open(self, "boss_intent_hidden")
	MatchViewHarness.run(view, FRAME_S)
	var banner: IntentBanner = _banner(view)

	# Assert
	assert_bool(banner.is_hidden_plate()).is_true()
	assert_object(banner.plate_rect()).is_equal(PLATE)
	assert_str((banner.get("_amount") as Label).text).is_empty()
	assert_str(banner.label_text()).is_empty()
	assert_bool((banner.get("_reticle") as Control).visible).is_false()
	MatchViewHarness.close(view)


func test_o9_paused_in_the_boss_turn_the_table_reads_as_locked() -> void:
	# Arrange / Act
	var view: MatchView = await MatchViewHarness.open(self, "boss_turn_playback", ["--pause-at=%d" % BOSS_TURN_SEQ])
	MatchViewHarness.run(view, FRAME_S)

	# Assert
	assert_bool((view.get("_end_turn") as Button).disabled).is_true()
	assert_bool((view.hand().get("_zone_dim") as Control).visible).is_true()
	assert_float((view.hand().get("_zone_dim") as ColorRect).color.a).is_equal_approx(0.6, 0.001)
	assert_dict(view.hand().get("_playable")).is_empty()
	for token: Dictionary in view.view_state().side(&"player").board:
		var row: BoardPresenter = view.find_child("PlayerRow", true, false)
		assert_bool(row.token(int(token.entity_id)).get("_lit")).is_false()
	assert_str(String(view.router().view_state())).is_equal(String(InputRouter.STATE_BOSS_TURN))
	view.queue().skip_all()
	MatchViewHarness.close(view)


func test_o9_the_skip_hint_takes_its_rect_once_1_s_has_passed() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "boss_turn_playback", ["--pause-at=%d" % BOSS_TURN_SEQ])
	var banner: IntentBanner = _banner(view)
	MatchViewHarness.run(view, HINT_DELAY_S - FRAME_S * 3.0)
	var early: bool = banner.get("_hint_on")

	# Act
	MatchViewHarness.run(view, FRAME_S * 4.0)

	# Assert
	assert_bool(early).is_false()
	assert_bool(banner.get("_hint_on")).is_true()
	assert_object((banner.get("_hint") as Control).get_global_rect()).is_equal(HINT)
	view.queue().skip_all()
	MatchViewHarness.close(view)


func test_the_commit_beat_shows_on_the_end_turn_frame() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player", [], {"anim_speed": "normal"})
	MatchViewHarness.run(view, FRAME_S)
	var banner: IntentBanner = _banner(view)

	# Act: one frame of the clock
	MatchViewHarness.press_end_turn(view)
	MatchViewHarness.run(view, FRAME_S)

	# Assert: the plate has brightened, over the forecast it still shows
	assert_bool(banner.get("_bright")).is_true()
	assert_bool((banner.get("_plate") as Control).visible).is_true()
	assert_str(banner.label_text()).is_equal(tr("intent.%s" % str(view.view_state().intent.intent_key)))
	view.queue().skip_all()
	MatchViewHarness.close(view)


func test_playback_starts_no_sooner_than_the_beat() -> void:
	# Arrange: a boss with a plan ready at once
	var view: MatchView = await MatchViewHarness.open(self, "boss_turn_playback", [], {"anim_speed": "normal"})
	MatchViewHarness.run(view, FRAME_S)
	var elapsed: Array[float] = [0.0]
	var first_plan_step: Array[float] = []
	view.queue().step_started.connect(func(step: AnimStep, _d: float) -> void:
		if first_plan_step.is_empty() and step.seq > 0 and view.queue().boss_turn_active() and not view.queue().commit_beat_active() and step.kind != AnimStep.TURN_BANNER:
			first_plan_step.append(elapsed[0]))

	# Act
	MatchViewHarness.press_end_turn(view)
	for i: int in 180:
		MatchViewHarness.run(view, FRAME_S)
		elapsed[0] += FRAME_S

	# Assert
	assert_array(first_plan_step).is_not_empty()
	assert_float(first_plan_step[0]).is_greater_equal(BEAT_S - FRAME_S)
	view.queue().skip_all()
	MatchViewHarness.close(view)


func test_a_planner_held_past_the_cap_shows_thinking_until_the_plan_arrives() -> void:
	# Arrange
	var gate: Dictionary = {"held": false}
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player", [], {"anim_speed": "normal"}, MatchViewHarness.gated_planner(gate))
	MatchViewHarness.run(view, FRAME_S)
	var banner: IntentBanner = _banner(view)
	gate.held = true
	MatchViewHarness.press_end_turn(view)

	# Act
	MatchViewHarness.run(view, THINKING_S - FRAME_S * 3.0)
	var early: String = banner.label_text()
	MatchViewHarness.run(view, FRAME_S * 6.0)
	var late: String = banner.label_text()
	gate.held = false
	MatchViewHarness.settle(view)

	# Assert
	assert_str(early).is_not_equal(tr(IntentBanner.KEY_THINKING))
	assert_str(late).is_equal(tr(IntentBanner.KEY_THINKING))
	assert_str(banner.label_text()).is_not_equal(tr(IntentBanner.KEY_THINKING))
	assert_array(MatchViewHarness.sync_lines(view)).is_empty()
	MatchViewHarness.close(view)


func test_skip_all_leaves_every_presenter_on_the_view_state_and_the_banner_final() -> void:
	for input: Callable in [
		func(view: MatchView) -> void: MatchViewHarness.click(view, Vector2(640, 300)),
		func(view: MatchView) -> void: MatchViewHarness.action(view, &"skip"),
		func(view: MatchView) -> void: MatchViewHarness.action(view, &"ui_accept"),
	]:
		# Arrange
		var view: MatchView = await MatchViewHarness.open(self, "boss_turn_playback", [], {"anim_speed": "normal"})
		MatchViewHarness.run(view, FRAME_S)
		MatchViewHarness.press_end_turn(view)
		MatchViewHarness.run(view, 0.5)

		# Act
		input.call(view)
		MatchViewHarness.run(view, 0.0)
		MatchViewHarness.settle(view)

		# Assert
		assert_array(MatchViewHarness.sync_lines(view)).is_empty()
		var banner: IntentBanner = _banner(view)
		assert_bool(banner.get("_bright")).is_false()
		assert_bool((banner.get("_turn_plate") as Control).visible).is_false()
		assert_str((view.get("_turn_label") as Label).text).is_not_empty()
		MatchViewHarness.close(view)


func test_the_hand_dim_comes_and_goes_with_the_boss_turn() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player", [], {"anim_speed": "fast"})
	MatchViewHarness.run(view, FRAME_S)
	var dim: Control = view.hand().get("_zone_dim")
	var before: bool = dim.visible

	# Act
	MatchViewHarness.press_end_turn(view)
	MatchViewHarness.run(view, FRAME_S)
	var during: bool = dim.visible
	MatchViewHarness.settle(view)

	# Assert
	assert_bool(before).is_false()
	assert_bool(during).is_true()
	assert_bool(dim.visible).is_false()
	MatchViewHarness.close(view)


func test_the_turn_banner_reads_the_turn_it_opens() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player", [], {"anim_speed": "normal"})
	MatchViewHarness.run(view, FRAME_S)

	# Act
	MatchViewHarness.press_end_turn(view)
	MatchViewHarness.run(view, FRAME_S)

	# Assert
	var banner: IntentBanner = _banner(view)
	assert_bool((banner.get("_turn_plate") as Control).visible).is_true()
	assert_str((banner.get("_turn_text") as Label).text).is_equal(tr("hud.turn_banner") % BOSS_FIRST_TURN)
	view.queue().skip_all()
	MatchViewHarness.close(view)
