## The shell's draft flow (run-ui U8, S14, S15; draft-picker.md): the next screen opens
## after the `fly_to_strip` landing or on any press; the fly-to-strip's end state; the
## deck tick; what `reduce_motion` and `instant` change.
extends GdUnitTestSuite

const BUNDLE_MODEL_DECK: int = 24
const BUNDLE_AFTER: int = 27

var _rig: RunUiRig = null


func before() -> void:
	RunUiRig.install_input()


func after() -> void:
	RunUiRig.restore_input()


func after_test() -> void:
	if _rig != null:
		_rig.finish()
		_rig = null


## A real run on its first draft with [param settings], every transition ended.
func _to_draft(settings: Dictionary) -> void:
	_rig = await RunUiRig.start(self, null, settings)
	_rig.intent(&"skip")
	await _rig.settle()
	_rig.intent(&"new_run_requested")
	_rig.intent(&"skip")
	await _rig.settle()
	_rig.intent(&"start_run", {"hero_id": "hero_war", "seed_input": "deckdelve"})
	_rig.intent(&"skip")
	await _rig.settle()
	_rig.intent(&"skip")
	await _rig.settle()
	await _rig.win_floor()
	_rig.intent(&"skip")
	await _rig.settle()


func _shown() -> String:
	return _rig.top().name


## Waits on the clock for the running landing, up to [param limit_ms].
func _wait_landing(limit_ms: int = 2000) -> void:
	var start: int = Time.get_ticks_msec()
	while _rig.shell._landing and Time.get_ticks_msec() - start < limit_ms:
		await get_tree().process_frame


func test_a_pick_holds_the_next_screen_until_the_landing_ends() -> void:
	# Arrange
	await _to_draft({"anim_speed": "normal"})
	var picked: Screen = _rig.top()

	# Act
	_rig.intent(&"pick", {"index": 0})
	await get_tree().process_frame

	# Assert: the old screen stays up through the landing, then the bundle draft opens
	assert_bool(_rig.shell._landing).is_true()
	assert_object(_rig.top()).is_same(picked)
	await _wait_landing()
	assert_bool(_rig.shell._landing).is_false()
	assert_object(_rig.top()).is_not_same(picked)
	assert_str(String(_rig.shell.screen())).is_equal("draft_bundle")


func test_the_landing_takes_fly_to_strip_ms() -> void:
	# Arrange
	await _to_draft({"anim_speed": "normal"})
	var expected_ms: int = RunUiConfig.t_transition(RunUiRig.config(), RunUiConfig.KIND_FLY_TO_STRIP, "normal", false)

	# Act
	var start: int = Time.get_ticks_msec()
	_rig.intent(&"pick", {"index": 0})
	await _wait_landing()
	var took: int = Time.get_ticks_msec() - start

	# Assert: at least the tween's length; the top is only a frame-rate margin
	assert_int(took).is_greater_equal(expected_ms - 20)
	assert_int(took).is_less(expected_ms + 300)


func test_any_key_ends_the_landing_at_once() -> void:
	# Arrange
	await _to_draft({"anim_speed": "normal"})
	_rig.intent(&"pick", {"index": 0})
	assert_bool(_rig.shell._landing).is_true()
	var picked: Screen = _rig.top()

	# Act
	await _rig.key(KEY_X)

	# Assert
	assert_bool(_rig.shell._landing).is_false()
	assert_object(_rig.top()).is_not_same(picked)
	assert_str(String(_rig.shell.screen())).is_equal("draft_bundle")


func test_a_mouse_press_and_a_pad_press_end_the_landing_too() -> void:
	# Arrange
	await _to_draft({"anim_speed": "normal"})
	_rig.intent(&"pick", {"index": 0})

	# Act
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(4, 4)
	await _rig.push(click)
	var up: InputEventMouseButton = click.duplicate()
	up.pressed = false
	await _rig.push(up)

	# Assert
	assert_bool(_rig.shell._landing).is_false()
	assert_str(String(_rig.shell.screen())).is_equal("draft_bundle")

	# Same again by pad, on the bundle
	_rig.intent(&"skip")
	await _rig.settle()
	_rig.intent(&"pick", {"index": 0})
	assert_bool(_rig.shell._landing).is_true()
	await _rig.pad(JOY_BUTTON_X)
	assert_bool(_rig.shell._landing).is_false()
	assert_str(String(_rig.shell.screen())).is_equal("boss_intro")


func test_the_press_that_ends_a_landing_reaches_no_control() -> void:
	# Arrange: the swap must not turn the skip into a press on the new screen
	await _to_draft({"anim_speed": "normal"})
	_rig.intent(&"pick", {"index": 0})
	var drafts: int = _rig.run.state.drafts.size()

	# Act
	await _rig.key(KEY_ENTER)
	await _rig.settle()

	# Assert
	assert_int(_rig.run.state.drafts.size()).is_equal(drafts)
	assert_array(_rig.rejected).is_empty()


func test_at_instant_no_landing_runs_and_the_next_screen_is_up_at_once() -> void:
	await _to_draft(RunUiRig.INSTANT)
	_rig.intent(&"pick", {"index": 0})
	assert_bool(_rig.shell._landing).is_false()
	assert_str(String(_rig.shell.screen())).is_equal("draft_bundle")
	assert_object(_rig.top().find_children("*", "OptionPanel", true, false)).is_not_null()


func test_a_treasure_lands_on_the_next_chip_and_ticks_no_deck() -> void:
	# Arrange
	await _to_draft({"anim_speed": "normal"})
	var screen: Screen = _rig.top()
	var strip: ProgressStrip = screen._strip
	var deck_text: String = strip._deck.text
	var target: Vector2 = strip.landing_point(false)
	var panel: OptionPanel = screen._panels[0]
	var ghosts: Array = []
	screen.child_entered_tree.connect(func(node: Node) -> void:
		if node.get_class() == "PanelContainer" and not node is OptionPanel:
			ghosts.append(node))
	var ended: Array = [false]
	var ghost_end: Array = []
	screen.landing_finished.connect(func() -> void:
		ended[0] = true
		ghost_end.append_array([ghosts[0].position + ghosts[0].size / 2.0, ghosts[0].scale, ghosts[0].modulate.a, strip._deck.text, panel.modulate.a]))

	# Act
	_rig.intent(&"pick", {"index": 0})
	await _wait_landing()

	# Assert: the ghost's centre is on the chip, shrunk, gone; the source stays hidden
	assert_bool(ended[0]).is_true()
	assert_int(ghosts.size()).is_equal(1)
	assert_vector(ghost_end[0]).is_equal_approx(target, Vector2(0.5, 0.5))
	assert_vector(ghost_end[1]).is_equal_approx(Vector2.ONE * 0.1, Vector2(0.001, 0.001))
	assert_float(ghost_end[2]).is_equal_approx(0.0, 0.001)
	assert_str(ghost_end[3]).is_equal(deck_text)
	assert_float(ghost_end[4]).is_equal(0.0)


func test_a_bundle_lands_on_the_deck_count_and_the_count_ends_on_the_new_size() -> void:
	# Arrange
	await _to_draft({"anim_speed": "normal"})
	_rig.intent(&"pick", {"index": 0})
	await _wait_landing()
	_rig.intent(&"skip")
	await _rig.settle()
	var screen: Screen = _rig.top()
	var strip: ProgressStrip = screen._strip
	var target: Vector2 = strip.landing_point(true)
	var size_before: int = int(_rig.controller.read_model().deck_size)
	var ghosts: Array = []
	screen.child_entered_tree.connect(func(node: Node) -> void:
		if node.get_class() == "PanelContainer" and not node is OptionPanel:
			ghosts.append(node))
	var seen: Array = []
	var ticks: Array[String] = []
	screen.landing_finished.connect(func() -> void:
		seen.append_array([ghosts[0].position + ghosts[0].size / 2.0, ghosts[0].scale, strip._deck.text]))

	# Act
	_rig.intent(&"pick", {"index": 1})
	while _rig.shell._landing:
		if not ticks.has(strip._deck.text):
			ticks.append(strip._deck.text)
		await get_tree().process_frame

	# Assert: count ends at the bundle's size, passing through the numbers on the way
	var expected: String = tr("strip.deck").format({"n": size_before + 3})
	assert_vector(seen[0]).is_equal_approx(target, Vector2(0.5, 0.5))
	assert_vector(seen[1]).is_equal_approx(Vector2.ONE * 0.1, Vector2(0.001, 0.001))
	assert_str(seen[2]).is_equal(expected)
	assert_str(ticks[0]).is_equal(tr("strip.deck").format({"n": size_before}))
	assert_int(int(_rig.controller.read_model().deck_size)).is_equal(size_before + 3)


func test_reduce_motion_fades_in_place_at_half_time_and_still_ticks_the_deck() -> void:
	# Arrange: run-ui Tuning Knobs: fly-to-strip becomes a fade at half duration
	await _to_draft({"anim_speed": "normal", "reduce_motion": true})
	var screen: Screen = _rig.top()
	var start_rect: Rect2 = (screen._panels[0] as Control).get_rect()
	var ghosts: Array = []
	screen.child_entered_tree.connect(func(node: Node) -> void:
		if node.get_class() == "PanelContainer" and not node is OptionPanel:
			ghosts.append(node))
	var seen: Array = []
	screen.landing_finished.connect(func() -> void:
		seen.append_array([ghosts[0].position, ghosts[0].scale, ghosts[0].modulate.a]))
	var expected_ms: int = RunUiConfig.t_transition(RunUiRig.config(), RunUiConfig.KIND_FLY_TO_STRIP, "normal", true)

	# Act
	var began: int = Time.get_ticks_msec()
	_rig.intent(&"pick", {"index": 0})
	await _wait_landing()
	var took: int = Time.get_ticks_msec() - began

	# Assert
	assert_vector(seen[0]).is_equal(start_rect.position)
	assert_vector(seen[1]).is_equal(Vector2.ONE)
	assert_float(seen[2]).is_equal_approx(0.0, 0.001)
	assert_int(took).is_less(expected_ms + 150)


func test_a_skip_on_a_draft_plays_no_landing() -> void:
	# Arrange (Edge Cases: "no fly-to-strip plays"): allow_skip is off in the shipped data
	await _to_draft({"anim_speed": "normal"})
	var landed: Array = []
	_rig.controller.pick_landed.connect(func(index: int, size: int) -> void: landed.append([index, size]))
	_rig.run._draft._config = _rig.run._draft._config.duplicate(true)
	_rig.run._draft._config["allow_skip"] = true

	# Act
	_rig.controller._skip_pick()
	await _rig.settle()

	# Assert
	assert_array(landed).is_empty()
	assert_bool(_rig.shell._landing).is_false()
	assert_str(String(_rig.shell.screen())).is_equal("draft_bundle")


func test_committed_dims_the_others_and_keeps_the_pick_lit() -> void:
	# Arrange
	await _to_draft({"anim_speed": "normal"})
	var screen: Screen = _rig.top()
	screen.handle_option_key(1)
	await get_tree().process_frame

	# Act
	screen.set_committed(true)

	# Assert
	assert_float((screen._panels[0] as Control).modulate.a).is_equal_approx(UiKit.DIM_ALPHA, 0.001)
	assert_float((screen._panels[1] as Control).modulate.a).is_equal(1.0)
	assert_bool(screen._pick.disabled).is_true()


func test_a_treasure_pick_updates_the_strip_on_the_next_screen() -> void:
	await _to_draft(RunUiRig.INSTANT)
	_rig.intent(&"pick", {"index": 0})
	await _rig.settle()
	assert_int((_rig.top()._strip.focus_stops() as Array).filter(func(stop: Control) -> bool: return stop is Button).size()).is_equal(1)


func test_a_bundle_pick_lands_on_the_next_floors_intro_with_the_new_deck() -> void:
	await _to_draft(RunUiRig.INSTANT)
	var size_before: int = int(_rig.controller.read_model().deck_size)
	_rig.intent(&"pick", {"index": 0})
	await _rig.settle()
	_rig.intent(&"pick", {"index": 0})
	await _rig.settle()
	assert_str(String(_rig.shell.screen())).is_equal("boss_intro")
	assert_array(RunUiRig.texts(_rig.top())).contains([tr("boss.floor").format({"n": 2, "f": 8}), tr("strip.deck").format({"n": size_before + 3})])
