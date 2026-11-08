## Keyboard-only and gamepad-event runs (run-ui U3; AC-19; draft-picker.md §12). Nothing
## here calls an intent: every screen is reached and left by pressed keys or pad buttons,
## through `Viewport.push_input`. The ring's pixels stay manual; its rect and colour are
## asserted at each stop.
extends GdUnitTestSuite

var _rig: RunUiRig = null


func before() -> void:
	RunUiRig.install_input()


func after() -> void:
	RunUiRig.restore_input()


func after_test() -> void:
	if _rig != null:
		_rig.finish()
		_rig = null


func _start(settings: Dictionary = RunUiRig.INSTANT) -> void:
	_rig = await RunUiRig.start(self, null, settings)


func _base() -> String:
	return String(_rig.shell.screen())


func _top() -> String:
	return String(_rig.controller.state.top())


## Presses, then lets the swap land.
func _enter() -> void:
	await _rig.key(KEY_ENTER)
	await _rig.settle()


func _press(keycode: Key) -> void:
	await _rig.key(keycode)
	await _rig.settle()


func _pad_press(button: JoyButton) -> void:
	await _rig.pad(button)
	await _rig.settle()


## Tab until the focus holds a `Button` reading [param text].
func _tab_to(text: String) -> void:
	for _i: int in 40:
		var focused: Control = _rig.focus()
		if focused is Button and (focused as Button).text == text:
			return
		await _rig.key(KEY_TAB)
	assert_str("no Tab stop reads " + text).is_empty()


func _shoulder_to(text: String) -> void:
	for _i: int in 40:
		var focused: Control = _rig.focus()
		if focused is Button and (focused as Button).text == text:
			return
		await _rig.pad(JOY_BUTTON_RIGHT_SHOULDER)
	assert_str("no shoulder stop reads " + text).is_empty()


## The ring is on the focused control: 2 px, 3 px off it, `state_actionable`.
func _assert_ring() -> void:
	await get_tree().process_frame
	var ring: FocusRing = _rig.shell._ring
	var focused: Control = _rig.focus()
	assert_object(focused).is_not_null()
	assert_bool(ring._shown).is_true()
	assert_object(ring._rect).is_equal(focused.get_global_rect())
	assert_float(FocusRing.WIDTH_PX).is_equal(2.0)
	assert_float(FocusRing.OFFSET_PX).is_equal(3.0)
	assert_object(ring._ring_color).is_equal(RunUiConfig.color(RunUiRig.config(), "state_actionable"))


## Menu to the boss intro, by keys.
func _keys_to_boss() -> void:
	await _enter()
	assert_str(_base()).is_equal("hero_select")
	await _enter()
	assert_str(_base()).is_equal("boss_intro")


## From a boss intro through a won match to the first draft, by keys. The match's own
## controls are Match UI's, so the win is the rig's.
func _win_by_banner() -> void:
	await _enter()
	assert_str(_base()).is_equal("match")
	var view: Control = _rig.view()
	await _rig.force_win(view)
	await _rig.continue_banner(view)


# --- AC-19: the three-option screens --------------------------------------------------

func test_ac19_key_two_then_enter_selects_and_a_second_enter_picks_index_one() -> void:
	# Arrange
	await _start()
	await _keys_to_boss()
	await _win_by_banner()
	assert_str(_base()).is_equal("draft_treasure")
	assert_object(_rig.focus()).is_null()
	var ids: Array = _rig.run.current_offer().option_ids
	var screen: Screen = _rig.top()

	# Act
	await _rig.key(KEY_2)
	assert_int((_rig.focus() as OptionPanel).index()).is_equal(1)
	await _assert_ring()
	await _rig.key(KEY_ENTER)

	# Assert: selected, not yet picked (draft-picker.md "First Enter = select")
	assert_int(screen._selected).is_equal(1)
	assert_bool(screen._pick.disabled).is_false()
	assert_int(_rig.run.state.drafts.size()).is_equal(0)
	await _enter()
	assert_str(str(_rig.run.state.drafts[0].picked_id)).is_equal(str(ids[1]))
	assert_str(_base()).is_equal("draft_bundle")


func test_ac19_two_tabs_from_no_focus_reach_index_one() -> void:
	# Arrange
	await _start()
	await _keys_to_boss()
	await _win_by_banner()
	var ids: Array = _rig.run.current_offer().option_ids

	# Act
	await _rig.key(KEY_TAB)
	assert_int((_rig.focus() as OptionPanel).index()).is_equal(0)
	await _rig.key(KEY_TAB)
	assert_int((_rig.focus() as OptionPanel).index()).is_equal(1)
	await _assert_ring()
	await _rig.key(KEY_ENTER)
	await _enter()

	# Assert
	assert_str(str(_rig.run.state.drafts[0].picked_id)).is_equal(str(ids[1]))


func test_shift_tab_walks_back() -> void:
	await _start()
	await _keys_to_boss()
	await _win_by_banner()
	await _rig.key(KEY_TAB)
	await _rig.key(KEY_TAB)
	await _rig.key(KEY_TAB, true)
	assert_int((_rig.focus() as OptionPanel).index()).is_equal(0)


func test_tab_reaches_pick_after_the_options_and_enter_on_it_picks() -> void:
	# Arrange
	await _start()
	await _keys_to_boss()
	await _win_by_banner()
	await _rig.key(KEY_3)
	await _rig.key(KEY_ENTER)

	# Act
	await _tab_to(tr("draft.pick"))
	await _enter()

	# Assert
	assert_int(_rig.run.state.drafts.size()).is_equal(1)


func test_space_activates_a_focused_option_and_a_focused_button() -> void:
	await _start()
	await _keys_to_boss()
	await _win_by_banner()
	await _rig.key(KEY_1)
	await _rig.key(KEY_SPACE)
	assert_int(_rig.top()._selected).is_equal(0)
	await _press(KEY_SPACE)
	assert_int(_rig.run.state.drafts.size()).is_equal(1)


func test_ac19_hero_select_number_keys_select_then_start_button_begins_run() -> void:
	# Arrange
	await _start()
	await _enter()
	var screen: Screen = _rig.top()
	var second: String = str(screen._rows[1].id)

	# Act
	await _rig.key(KEY_2)
	assert_int((_rig.focus() as OptionPanel).index()).is_equal(1)
	await _rig.key(KEY_ENTER)
	assert_int(screen._current).is_equal(1)
	await _tab_to(tr("hero.start"))
	await _enter()

	# Assert
	assert_str(_rig.run.state.hero_id).is_equal(second)


func test_a_number_key_past_the_last_option_is_ignored() -> void:
	# Edge Cases: "focus does not wrap to a hidden slot"
	await _start()
	await _rig.key(KEY_3)
	assert_str(_base()).is_equal("main_menu")
	await _enter()
	var before: Control = _rig.focus()
	var heroes: int = (_rig.top()._rows as Array).size()
	if heroes < 3:
		await _rig.key(KEY_3)
		assert_object(_rig.focus()).is_same(before)


# --- AC-19: every screen by keys ------------------------------------------------------

func test_ac19_a_full_run_by_keys_only() -> void:
	# Arrange
	await _start()
	await _assert_ring()

	# Act / Assert: menu, hero select, boss intro
	await _keys_to_boss()
	await _assert_ring()
	assert_str((_rig.focus() as Button).text).is_equal(tr("boss.fight"))

	# Win floor 1, take both rewards
	await _win_by_banner()
	await _rig.key(KEY_1)
	await _rig.key(KEY_ENTER)
	await _enter()
	assert_str(_base()).is_equal("draft_bundle")
	await _rig.key(KEY_1)
	await _rig.key(KEY_ENTER)
	await _enter()
	assert_str(_base()).is_equal("boss_intro")

	# Lose floor 2, restart by Enter on the focused New Run
	await _enter()
	var view: Control = _rig.view()
	var _sent: Dictionary = view._controller.submit(MatchRecords.concede())
	await _rig.drain(view)
	await _rig.continue_banner(view)
	assert_str(_base()).is_equal("summary_defeat")
	await _assert_ring()
	assert_str((_rig.focus() as Button).text).is_equal(tr("summary.new_run"))
	await _enter()
	assert_str(_base()).is_equal("boss_intro")
	assert_int(int(_rig.controller.read_model().floor)).is_equal(1)


func test_ac19_escape_opens_pause_and_each_pause_row_is_reachable() -> void:
	# Arrange
	await _start()
	await _keys_to_boss()

	# Act / Assert: Esc on the intro, Resume is focused, Esc closes
	await _press(KEY_ESCAPE)
	assert_str(_top()).is_equal("pause")
	await _assert_ring()
	assert_str((_rig.focus() as Button).text).is_equal(tr("pause.resume"))
	await _press(KEY_ESCAPE)
	assert_str(_top()).is_equal("boss_intro")
	assert_str((_rig.focus() as Button).text).is_equal(tr("boss.fight"))

	# Settings from pause and back, keeping the pause
	await _press(KEY_ESCAPE)
	await _tab_to(tr("pause.settings"))
	await _enter()
	assert_str(_top()).is_equal("settings")
	await _assert_ring()
	await _press(KEY_ESCAPE)
	assert_str(_top()).is_equal("pause")

	# Glossary
	await _tab_to(tr("pause.glossary"))
	await _enter()
	assert_str(_top()).is_equal("glossary")
	await _press(KEY_ESCAPE)
	assert_str(_top()).is_equal("pause")

	# Abandon: Cancel holds the focus, Esc cancels, then Tab and Enter confirm
	await _tab_to(tr("pause.abandon"))
	await _enter()
	assert_str(_top()).is_equal("confirm")
	assert_str((_rig.focus() as Button).text).is_equal(tr("common.cancel"))
	await _assert_ring()
	await _press(KEY_ESCAPE)
	assert_str(_top()).is_equal("pause")
	await _tab_to(tr("pause.abandon"))
	await _enter()
	await _tab_to(tr("abandon.confirm"))
	await _enter()
	assert_str(_base()).is_equal("summary_abandoned")
	await _assert_ring()

	# Esc leaves the notice for the menu
	await _press(KEY_ESCAPE)
	assert_str(_base()).is_equal("main_menu")


func test_ac19_resume_prompt_by_keys() -> void:
	# Arrange
	await _start()
	await _keys_to_boss()
	await _press(KEY_ESCAPE)
	await _tab_to(tr("pause.quit"))
	await _enter()
	assert_str(_base()).is_equal("main_menu")

	# Act: Continue is first and focused
	await _enter()
	assert_str(_top()).is_equal("resume_prompt")
	await _assert_ring()
	await _press(KEY_ESCAPE)
	assert_str(_top()).is_equal("main_menu")
	await _enter()
	await _enter()

	# Assert
	assert_str(_base()).is_equal("boss_intro")


func test_ac19_menu_screens_by_keys() -> void:
	# Arrange
	await _start()

	# Act / Assert
	await _tab_to(tr("menu.run_log"))
	await _enter()
	assert_str(_base()).is_equal("run_log")
	await _assert_ring()
	await _press(KEY_ESCAPE)
	assert_str(_base()).is_equal("main_menu")
	await _tab_to(tr("menu.settings"))
	await _enter()
	assert_str(_top()).is_equal("settings")
	await _tab_to(tr("settings.controls"))
	await _enter()
	assert_str(_top()).is_equal("controls")
	await _assert_ring()
	await _press(KEY_ESCAPE)
	assert_str(_top()).is_equal("settings")
	await _press(KEY_ESCAPE)
	assert_str(_top()).is_equal("main_menu")


func test_ac19_the_ring_shows_at_every_stop_at_instant_and_at_normal() -> void:
	for speed: String in ["instant", "normal"]:
		await _start({"anim_speed": speed})
		await _rig.key(KEY_X)
		await _rig.settle()
		for _stop: int in 4:
			await _rig.key(KEY_TAB)
			await _assert_ring()
		_rig.finish()
		_rig = null


func test_the_deck_drawer_opens_by_key_and_esc_closes_it_first() -> void:
	# Arrange (Escape chain step 2)
	await _start()
	await _keys_to_boss()
	await _win_by_banner()
	var deck: String = tr("draft.deck").format({"n": int(_rig.controller.read_model().deck_size)})
	await _rig.key(KEY_TAB)
	await _tab_to(deck)

	# Act
	await _enter()
	assert_bool(_rig.top()._drawer.is_open()).is_true()
	await _press(KEY_ESCAPE)

	# Assert: the drawer shut, focus back on its toggle, no pause
	assert_bool(_rig.top()._drawer.is_open()).is_false()
	assert_str(_top()).is_equal("draft_treasure")
	assert_str((_rig.focus() as Button).text).is_equal(deck)


func test_any_key_skips_a_transition_and_the_key_does_nothing_else() -> void:
	# Arrange
	await _start({"anim_speed": "normal"})
	assert_bool(_rig.controller.state.transitioning).is_true()

	# Act
	await _rig.key(KEY_ENTER)

	# Assert: skipped, and Enter did not also press New Run
	assert_bool(_rig.controller.state.transitioning).is_false()
	assert_str(_base()).is_equal("main_menu")


func test_a_held_key_echo_does_not_skip() -> void:
	await _start({"anim_speed": "normal"})
	var echo: InputEventKey = InputEventKey.new()
	echo.keycode = KEY_X
	echo.pressed = true
	echo.echo = true
	_rig.shell.get_viewport().push_input(echo)
	assert_bool(_rig.controller.state.transitioning).is_true()


func test_confirm_takes_input_from_the_base_away() -> void:
	# ADR-0011 verification 1: `ui_accept` on the base during `confirm` produces no intent
	await _start()
	await _keys_to_boss()
	await _press(KEY_ESCAPE)
	await _tab_to(tr("pause.abandon"))
	await _enter()
	var base: Screen = _rig.shell._base
	var pause: Screen = _rig.shell._overlays[0]
	assert_int(base.focus_behavior_recursive).is_equal(Control.FOCUS_BEHAVIOR_DISABLED)
	assert_int(pause.focus_behavior_recursive).is_equal(Control.FOCUS_BEHAVIOR_DISABLED)
	assert_int(pause.mouse_behavior_recursive).is_equal(Control.MOUSE_BEHAVIOR_DISABLED)
	for _i: int in 8:
		await _rig.key(KEY_TAB)
		assert_bool(pause.is_ancestor_of(_rig.focus()) or base.is_ancestor_of(_rig.focus())).is_false()


# --- AC-19: the same by gamepad ---------------------------------------------------

func test_gamepad_a_presses_the_focused_button_through_to_a_match() -> void:
	await _start()
	await _pad_press(JOY_BUTTON_A)
	assert_str(_base()).is_equal("hero_select")
	await _pad_press(JOY_BUTTON_A)
	assert_str(_base()).is_equal("boss_intro")
	await _pad_press(JOY_BUTTON_A)
	assert_str(_base()).is_equal("match")


func test_gamepad_b_cancels_like_escape() -> void:
	await _start()
	await _pad_press(JOY_BUTTON_A)
	await _pad_press(JOY_BUTTON_A)
	await _pad_press(JOY_BUTTON_B)
	assert_str(_top()).is_equal("pause")
	await _pad_press(JOY_BUTTON_B)
	assert_str(_top()).is_equal("boss_intro")


func test_gamepad_shoulders_walk_tab_order_and_enter_a_draft() -> void:
	# Arrange
	await _start()
	await _keys_to_boss()
	await _win_by_banner()
	assert_object(_rig.focus()).is_null()
	var ids: Array = _rig.run.current_offer().option_ids

	# Act: the first shoulder is the entry, A selects, A picks
	await _rig.pad(JOY_BUTTON_RIGHT_SHOULDER)
	assert_int((_rig.focus() as OptionPanel).index()).is_equal(0)
	await _rig.pad(JOY_BUTTON_RIGHT_SHOULDER)
	assert_int((_rig.focus() as OptionPanel).index()).is_equal(1)
	await _rig.pad(JOY_BUTTON_LEFT_SHOULDER)
	await _rig.pad(JOY_BUTTON_RIGHT_SHOULDER)
	await _rig.pad(JOY_BUTTON_A)
	await _pad_press(JOY_BUTTON_A)

	# Assert
	assert_str(str(_rig.run.state.drafts[0].picked_id)).is_equal(str(ids[1]))


func test_gamepad_dpad_enters_a_draft_from_no_focus() -> void:
	await _start()
	await _keys_to_boss()
	await _win_by_banner()
	await _rig.pad(JOY_BUTTON_DPAD_RIGHT)
	assert_int((_rig.focus() as OptionPanel).index()).is_equal(0)


func test_gamepad_dpad_moves_down_the_main_menu() -> void:
	await _start()
	var first: Control = _rig.focus()
	await _rig.pad(JOY_BUTTON_DPAD_DOWN)
	assert_object(_rig.focus()).is_not_same(first)
	assert_str((_rig.focus() as Button).text).is_equal(tr("menu.run_log"))


func test_gamepad_reaches_pause_rows_and_the_abandon_confirm() -> void:
	await _start()
	await _pad_press(JOY_BUTTON_A)
	await _pad_press(JOY_BUTTON_A)
	await _pad_press(JOY_BUTTON_B)
	await _shoulder_to(tr("pause.abandon"))
	await _pad_press(JOY_BUTTON_A)
	assert_str(_top()).is_equal("confirm")
	await _shoulder_to(tr("abandon.confirm"))
	await _pad_press(JOY_BUTTON_A)
	assert_str(_base()).is_equal("summary_abandoned")


func test_a_pad_press_skips_a_transition() -> void:
	await _start({"anim_speed": "normal"})
	await _rig.pad(JOY_BUTTON_Y)
	assert_bool(_rig.controller.state.transitioning).is_false()
