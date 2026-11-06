## The settings the shell applies (ADR-0011 Decision 4; run-ui U2 `settings`, `pause`):
## bus volumes against `default_bus_layout.tres`, `fullscreen`, gamma, text scale; the
## Controls page through the screen; the typed reset (AC-30); the ReadOnly banner and the
## load lines (U2 `main_menu`); AC-31's three segments.
extends GdUnitTestSuite

const BUS_LAYOUT: String = "res://default_bus_layout.tres"
const VOLUME_ROW: Dictionary = {"volume_master": "Master", "volume_music": "Music", "volume_sfx": "SFX"}
const HALF: float = 0.5
const STEP_VALUE: float = 0.35

var _rig: RunUiRig = null


func before() -> void:
	RunUiRig.install_input()


func after() -> void:
	RunUiRig.restore_input()
	RunUiRig.wipe_profiles()


func after_test() -> void:
	if _rig != null:
		_rig.finish()
		_rig = null
	RunUiRig.restore_input()
	RunUiRig.install_input()


func _start(meta: MetaApi = null, settings: Dictionary = RunUiRig.INSTANT) -> RunUiRig:
	_rig = await RunUiRig.start(self, meta, settings)
	return _rig


func _top() -> String:
	return String(_rig.controller.state.top())


func _fake() -> RunUiRig.FakeMeta:
	return _rig.meta


func _open_settings() -> void:
	_rig.intent(&"open_settings")
	await _rig.settle()


## The slider of [param key]'s row: the row is found by its label.
func _control_of(key: String, type: String) -> Control:
	var label_text: String = tr("settings.key.%s" % key)
	for label: Node in _rig.top().find_children("*", "Label", true, false):
		if (label as Label).text == label_text:
			return label.get_parent().find_children("*", type, true, false)[0]
	return null


func _db_of(bus: String) -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus))


func _press(button: BaseButton) -> void:
	button.grab_focus()
	await _rig.key(KEY_ENTER)
	await _rig.settle()


# --- The bus layout ---------------------------------------------------------------

func test_the_layout_names_every_bus_the_shell_and_the_player_use() -> void:
	# Arrange
	var layout: AudioBusLayout = load(BUS_LAYOUT)
	var sfx: Dictionary = RunUiRig.config().sfx

	# Assert
	assert_object(layout).is_not_null()
	assert_str(str(ProjectSettings.get_setting("audio/buses/default_bus_layout", BUS_LAYOUT))).is_equal(BUS_LAYOUT)
	for bus: String in RunShell.BUS_VOLUME.values():
		assert_int(AudioServer.get_bus_index(bus)).override_failure_message(bus).is_greater_equal(0)
	assert_int(AudioServer.get_bus_index(str(sfx.bus))).is_greater_equal(0)
	assert_int(AudioServer.get_bus_index(str(sfx.music_bus))).is_greater_equal(0)


func test_music_and_sfx_feed_master() -> void:
	assert_str(String(AudioServer.get_bus_send(AudioServer.get_bus_index("Music")))).is_equal("Master")
	assert_str(String(AudioServer.get_bus_send(AudioServer.get_bus_index("SFX")))).is_equal("Master")


func test_the_shell_applies_each_saved_volume_at_start() -> void:
	# Arrange / Act
	await _start(null, {"anim_speed": "instant", "volume_master": 0.8, "volume_music": HALF, "volume_sfx": 0.25})

	# Assert
	assert_float(_db_of("Master")).is_equal_approx(linear_to_db(0.8), 0.01)
	assert_float(_db_of("Music")).is_equal_approx(linear_to_db(HALF), 0.01)
	assert_float(_db_of("SFX")).is_equal_approx(linear_to_db(0.25), 0.01)


func test_each_settings_slider_changes_its_own_bus_and_only_it() -> void:
	# Arrange
	await _start()
	await _open_settings()

	for key: String in VOLUME_ROW:
		var others: Dictionary = {}
		for other: String in VOLUME_ROW.values():
			others[other] = _db_of(other)

		# Act
		var slider: HSlider = _control_of(key, "HSlider")
		slider.value = STEP_VALUE

		# Assert
		var bus: String = VOLUME_ROW[key]
		assert_float(_db_of(bus)).override_failure_message(key).is_equal_approx(linear_to_db(STEP_VALUE), 0.01)
		assert_float(float(_rig.meta.get_setting(StringName(key)))).is_equal_approx(STEP_VALUE, 0.001)
		for other: String in VOLUME_ROW.values():
			if other != bus:
				assert_float(_db_of(other)).is_equal_approx(float(others[other]), 0.001)


func test_a_slider_at_zero_silences_its_bus() -> void:
	await _start()
	await _open_settings()
	var slider: HSlider = _control_of("volume_sfx", "HSlider")
	slider.value = 0.0
	assert_float(db_to_linear(_db_of("SFX"))).is_equal_approx(0.0, 0.0001)


func test_a_slider_moves_by_keyboard_in_its_step() -> void:
	# Arrange
	await _start(null, {"anim_speed": "instant", "volume_music": HALF})
	await _open_settings()
	var slider: HSlider = _control_of("volume_music", "HSlider")
	slider.grab_focus()

	# Act
	await _rig.key(KEY_RIGHT)

	# Assert
	var step: float = float(RunUiRig.config().settings_steps.volume)
	assert_float(float(_rig.meta.get_setting(&"volume_music"))).is_equal_approx(HALF + step, 0.001)
	assert_float(_db_of("Music")).is_equal_approx(linear_to_db(HALF + step), 0.01)


func test_the_pause_music_slider_starts_at_the_record_and_changes_the_bus() -> void:
	# Arrange
	await _start(null, {"anim_speed": "instant", "volume_music": HALF})
	await _rig.to_boss()
	_rig.intent(&"open_pause")
	await _rig.settle()
	var slider: HSlider = _rig.top().find_children("*", "HSlider", true, false)[0]
	assert_float(slider.value).is_equal_approx(HALF, 0.001)

	# Act
	slider.value = STEP_VALUE

	# Assert
	assert_float(_db_of("Music")).is_equal_approx(linear_to_db(STEP_VALUE), 0.01)
	assert_float(float(_rig.meta.get_setting(&"volume_music"))).is_equal_approx(STEP_VALUE, 0.001)
	assert_array(_rig.rejected).is_empty()


# --- fullscreen ---------------------------------------------------------------------

func test_the_fullscreen_toggle_drives_the_window_both_ways() -> void:
	# Arrange: a headless root window reports no mode, so a detached one stands in
	await _start()
	var window: Window = auto_free(Window.new())
	_rig.shell.window = window
	await _open_settings()
	var box: CheckBox = _control_of("fullscreen", "CheckBox")

	# Act / Assert
	box.button_pressed = true
	assert_int(window.mode).is_equal(Window.MODE_FULLSCREEN)
	assert_bool(_rig.meta.get_setting(&"fullscreen")).is_true()
	box.button_pressed = false
	assert_int(window.mode).is_equal(Window.MODE_WINDOWED)


# --- Gamma, text scale, high contrast, motion -----------------------------------------

func test_gamma_reaches_the_canvas_modulate_and_no_token() -> void:
	await _start()
	await _open_settings()
	var token: Color = RunUiConfig.color(RunUiRig.config(), "bg_edge")
	var slider: HSlider = _control_of("gamma", "HSlider")
	slider.value = 1.2
	assert_float(_rig.shell._gamma.color.r).is_equal_approx(1.2, 0.001)
	assert_object(RunUiConfig.color(RunUiRig.config(), "bg_edge")).is_equal(token)


func test_ac31_text_scale_is_exactly_three_segments() -> void:
	# Arrange
	await _start()
	await _open_settings()
	var label_text: String = tr("settings.key.text_scale")
	var row: Node = null
	for label: Node in _rig.top().find_children("*", "Label", true, false):
		if (label as Label).text == label_text:
			row = label.get_parent()

	# Assert
	var buttons: Array = row.find_children("*", "Button", true, false).map(func(b: Button) -> String: return b.text)
	assert_array(buttons).is_equal(["100 %", "125 %", "150 %"])
	assert_array(row.find_children("*", "HSlider", true, false)).is_empty()


func test_ac31_no_intermediate_text_scale_can_be_stored() -> void:
	var stub: RunUiRig.FakeMeta = RunUiRig.FakeMeta.new(RunUiRig.database())
	var facade: MetaFacade = RunUiRig.facade("ac31")
	for meta: MetaApi in [stub, facade]:
		assert_int(meta.set_setting(&"text_scale", 1.3)).is_not_equal(OK)
		assert_int(meta.set_setting(&"text_scale", 2.0)).is_not_equal(OK)
		assert_int(meta.set_setting(&"text_scale", 1.25)).is_equal(OK)
		assert_float(float(meta.get_setting(&"text_scale"))).is_equal(1.25)


func test_a_text_scale_segment_rescales_the_theme_live() -> void:
	# Arrange
	await _start()
	await _open_settings()
	var body_px: int = int(RunUiRig.config().font_px.body)

	# Act
	await _press(RunUiRig.button(_rig.top(), "150 %"))

	# Assert
	assert_int(_rig.shell._stack.theme.default_font_size).is_equal(roundi(body_px * 1.5))
	assert_int(_rig.shell._toasts.theme.default_font_size).is_equal(roundi(body_px * 1.5))


func test_high_contrast_swaps_the_danger_token_in_the_theme() -> void:
	await _start()
	await _open_settings()
	var box: CheckBox = _control_of("high_contrast_states", "CheckBox")
	box.button_pressed = true
	var danger: Color = _rig.shell._stack.theme.get_color(&"font_color", RunUiTheme.LABEL_DANGER)
	assert_object(danger).is_equal(Color.html(str(RunUiRig.config().palette_high_contrast.state_danger)))


func test_anim_speed_and_reduce_motion_reach_the_transition_and_the_toasts() -> void:
	await _start()
	await _open_settings()
	await _press(RunUiRig.button(_rig.top(), tr("settings.anim_speed.fast")))
	assert_str(_rig.shell._transition._speed).is_equal("fast")
	assert_str(_rig.shell._toasts._speed).is_equal("fast")
	var box: CheckBox = _control_of("reduce_motion", "CheckBox")
	box.button_pressed = true
	assert_bool(_rig.shell._transition._reduce_motion).is_true()
	assert_bool(_rig.shell._toasts._reduce_motion).is_true()


func test_reset_profile_on_a_real_profile_reapplies_the_default_volumes() -> void:
	# Arrange
	var facade: MetaFacade = RunUiRig.facade("reset_buses")
	await _start(facade, {"anim_speed": "instant", "volume_music": 0.25})
	var token: String = str(RunUiRig.database().config("profile_defaults").knobs.reset_confirm_token)
	var default_music: float = float(RunUiRig.database().config("profile_defaults").volume_music)

	# Act
	assert_int(facade.reset_profile(token)).is_equal(OK)

	# Assert
	assert_float(_db_of("Music")).is_equal_approx(linear_to_db(default_music), 0.01)


# --- AC-30 ------------------------------------------------------------------------

func _open_reset() -> void:
	await _open_settings()
	_rig.intent(&"reset_profile_requested")
	await _rig.settle()


func test_ac30_confirm_stays_disabled_until_the_typed_field_equals_the_token() -> void:
	# Arrange
	await _start()
	await _open_reset()
	var token: String = str(RunUiRig.database().config("profile_defaults").knobs.reset_confirm_token)
	var field: LineEdit = _rig.top().find_children("*", "LineEdit", true, false)[0]
	var confirm: Button = RunUiRig.button(_rig.top(), tr("settings.reset.confirm"))
	assert_str(" ".join(RunUiRig.texts(_rig.top()))).contains(token)
	assert_bool(confirm.disabled).is_true()

	# Act / Assert
	field.text_changed.emit(token.left(token.length() - 1))
	assert_bool(confirm.disabled).is_true()
	field.text_changed.emit(token.to_lower() + "x")
	assert_bool(confirm.disabled).is_true()
	assert_int(_fake().count("reset_profile")).is_equal(0)
	field.text_changed.emit(token)
	assert_bool(confirm.disabled).is_false()
	assert_int(_fake().count("reset_profile")).is_equal(0)

	confirm.pressed.emit()
	await _rig.settle()
	assert_int(_fake().count("reset_profile")).is_equal(1)
	assert_str(str(_fake().calls[_fake().calls.size() - 1].args[0])).is_equal(token)
	assert_str(_top()).is_equal("main_menu")


func test_ac30_esc_and_cancel_call_nothing() -> void:
	await _start()
	await _open_reset()
	await _rig.key(KEY_ESCAPE)
	await _rig.settle()
	assert_str(_top()).is_equal("settings")
	_rig.intent(&"reset_profile_requested")
	await _rig.settle()
	_rig.intent(&"cancel")
	await _rig.settle()
	assert_int(_fake().count("reset_profile")).is_equal(0)


func test_clear_run_records_goes_through_confirm() -> void:
	await _start()
	await _open_settings()
	_rig.intent(&"clear_run_records_requested")
	await _rig.settle()
	assert_str(_top()).is_equal("confirm")
	assert_object(_rig.top().find_children("*", "LineEdit", true, false).front()).is_null()


# --- Controls -----------------------------------------------------------------------

func _open_controls() -> void:
	await _open_settings()
	_rig.intent(&"open_controls")
	await _rig.settle()


## The row `HBoxContainer` of [param action].
func _row(action: String) -> Control:
	var wanted: String = tr("controls.action.%s" % action)
	for label: Node in _rig.top().find_children("*", "Label", true, false):
		if (label as Label).text == wanted:
			return label.get_parent()
	return null


func _rebind_button(action: String) -> Button:
	return _row(action).find_children("*", "Button", true, false)[0]


func _keys_text(action: String) -> String:
	return (_row(action).get_child(1) as Label).text


func _rebind(action: String, keycode: Key) -> void:
	_rebind_button(action).pressed.emit()
	await _rig.key(keycode)
	await _rig.settle()


func test_a_rebind_through_the_screen_reaches_the_map_and_the_row() -> void:
	# Arrange
	await _start()
	await _open_controls()

	# Act
	await _rebind("option_1", KEY_Q)

	# Assert
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_Q
	key.pressed = true
	assert_bool(InputMap.event_is_action(key, &"option_1")).is_true()
	assert_str(_keys_text("option_1")).contains("Q")
	assert_str(_keys_text("option_1")).not_contains("1")
	var stored: Dictionary = _rig.meta.get_setting(&"bindings")
	assert_bool(stored.has("option_1")).is_true()


func test_a_rebound_key_works_on_a_draft() -> void:
	# Arrange
	await _start()
	await _open_controls()
	await _rebind("option_2", KEY_Q)
	_rig.intent(&"back")
	await _rig.settle()
	_rig.intent(&"back")
	await _rig.settle()
	await _rig.to_boss()
	await _rig.win_floor()

	# Act
	await _rig.key(KEY_2)
	var after_old: Control = _rig.focus()
	await _rig.key(KEY_Q)

	# Assert
	assert_object(after_old).is_null()
	assert_int((_rig.focus() as OptionPanel).index()).is_equal(1)


func test_a_keyboard_rebind_keeps_the_actions_gamepad_button() -> void:
	# Arrange
	await _start()
	await _open_controls()

	# Act
	await _rebind("ui_accept", KEY_Q)

	# Assert
	var pad: InputEventJoypadButton = InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	pad.pressed = true
	assert_bool(InputMap.event_is_action(pad, &"ui_accept")).is_true()


func test_a_pad_rebind_replaces_only_the_pad_button() -> void:
	# Arrange
	await _start()
	await _open_controls()
	_rebind_button("ui_accept").pressed.emit()

	# Act
	await _rig.pad(JOY_BUTTON_X)
	await _rig.settle()

	# Assert
	var old: InputEventJoypadButton = InputEventJoypadButton.new()
	old.button_index = JOY_BUTTON_A
	old.pressed = true
	var new_button: InputEventJoypadButton = old.duplicate()
	new_button.button_index = JOY_BUTTON_X
	assert_bool(InputMap.event_is_action(old, &"ui_accept")).is_false()
	assert_bool(InputMap.event_is_action(new_button, &"ui_accept")).is_true()
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	assert_bool(InputMap.event_is_action(key, &"ui_accept")).is_true()


func test_esc_cancels_a_capture_and_changes_nothing() -> void:
	# Arrange
	await _start()
	await _open_controls()
	_rebind_button("option_1").pressed.emit()
	assert_array(RunUiRig.texts(_rig.top())).contains([tr("controls.capture").format({"action": tr("controls.action.option_1")})])

	# Act
	await _rig.key(KEY_ESCAPE)
	await _rig.settle()

	# Assert: still on the page, nothing stored
	assert_str(_top()).is_equal("controls")
	assert_array(RunUiRig.texts(_rig.top())).contains([tr("controls.hint")])
	assert_int(_fake().count("set_setting")).is_equal(1)


func test_a_clash_within_a_group_is_marked_and_across_groups_is_not() -> void:
	# Arrange
	await _start()
	await _open_controls()

	# Act: option_2 onto option_1's key is a clash; hand_1 shares `1` with option_1 by design
	await _rebind("option_2", KEY_1)

	# Assert
	assert_array(RunUiRig.texts(_row("option_2"))).contains([tr("controls.conflict")])
	assert_array(RunUiRig.texts(_row("option_1"))).contains([tr("controls.conflict")])
	assert_array(RunUiRig.texts(_row("hand_1"))).not_contains([tr("controls.conflict")])


func test_reset_to_defaults_restores_the_map_and_the_rows() -> void:
	# Arrange
	await _start()
	await _open_controls()
	await _rebind("option_1", KEY_Q)

	# Act
	RunUiRig.button(_rig.top(), tr("controls.reset")).pressed.emit()
	await _rig.settle()

	# Assert
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_1
	key.pressed = true
	assert_bool(InputMap.event_is_action(key, &"option_1")).is_true()
	assert_str(_keys_text("option_1")).contains("1")
	assert_dict(_rig.meta.get_setting(&"bindings")).is_empty()


func test_the_page_lists_every_rebindable_action_and_never_cancel() -> void:
	await _start()
	await _open_controls()
	var groups: Dictionary = RunUiRig.config().controls.actions
	for group: String in groups:
		for action: String in groups[group]:
			assert_object(_row(action)).override_failure_message(action).is_not_null()
	assert_object(_rig.controller._models.controls().rows.filter(func(row: Dictionary) -> bool: return row.action == "ui_cancel").front()).is_null()


# --- ReadOnly banner, load lines ------------------------------------------------------

func _locked_meta(status: StringName) -> RunUiRig.FakeMeta:
	var meta: RunUiRig.FakeMeta = RunUiRig.FakeMeta.new(RunUiRig.database())
	meta.status = status
	meta.read_only = true
	return meta


func _banner() -> PanelContainer:
	return _rig.shell._banner


func _banner_text() -> String:
	return (_banner().get_node("Row").get_child(0) as Label).text


func _retry() -> Button:
	return _banner().get_node("Row").get_child(1)


func test_a_locked_profile_shows_the_banner_with_retry_on_the_menu() -> void:
	await _start(_locked_meta(&"E_LOCKED"))
	assert_bool(_banner().visible).is_true()
	assert_str(_banner_text()).is_equal(tr("banner.locked"))
	assert_bool(_retry().visible).is_true()


func test_a_newer_profile_shows_its_banner_with_no_retry() -> void:
	await _start(_locked_meta(&"E_SCHEMA_NEWER"))
	assert_str(_banner_text()).is_equal(tr("banner.newer"))
	assert_bool(_retry().visible).is_false()


func test_no_banner_on_a_writable_profile() -> void:
	await _start()
	assert_bool(_banner().visible).is_false()


func test_retry_that_gets_the_lock_clears_the_banner() -> void:
	# Arrange
	var meta: RunUiRig.FakeMeta = _locked_meta(&"E_LOCKED")
	await _start(meta)
	meta.status = &"OK"

	# Act
	_retry().pressed.emit()
	await _rig.settle()

	# Assert
	assert_int(meta.loads).is_equal(1)
	assert_bool(_banner().visible).is_false()


func test_retry_that_fails_keeps_the_banner() -> void:
	var meta: RunUiRig.FakeMeta = _locked_meta(&"E_LOCKED")
	meta.read_only_after_load = true
	await _start(meta)
	_retry().pressed.emit()
	await _rig.settle()
	assert_bool(_banner().visible).is_true()


func test_retry_is_a_tab_stop_on_the_menu() -> void:
	# U3: every intent is reachable by keyboard
	await _start(_locked_meta(&"E_LOCKED"))
	var reached: bool = false
	for _i: int in 8:
		await _rig.key(KEY_TAB)
		reached = reached or _rig.focus() == _retry()
	assert_bool(reached).is_true()


func test_the_banner_stays_on_every_base_but_a_match_and_new_run_still_works() -> void:
	# Arrange
	await _start(_locked_meta(&"E_LOCKED"))

	# Act / Assert
	await _rig.to_boss()
	assert_str(String(_rig.shell.screen())).is_equal("boss_intro")
	assert_bool(_banner().visible).is_true()
	assert_bool(_retry().visible).is_false()
	var view: Control = await _rig.begin()
	assert_bool(_banner().visible).is_false()
	await _rig.force_win(view)
	await _rig.continue_banner(view)
	assert_bool(_banner().visible).is_true()


func test_each_load_status_has_its_line_once_per_launch() -> void:
	for status: StringName in [&"RECOVERED_BAK", &"FRESH_AFTER_CORRUPT", &"E_SCHEMA_NEWER", &"E_LOCKED"]:
		# Arrange
		var meta: RunUiRig.FakeMeta = RunUiRig.FakeMeta.new(RunUiRig.database())
		meta.status = status
		await _start(meta)
		var line: String = tr("load.%s" % status)

		# Assert
		assert_str(line).is_not_equal("load.%s" % status)
		assert_array(RunUiRig.texts(_rig.top())).override_failure_message(String(status)).contains([line])

		# Away and back: gone
		_rig.intent(&"open_run_log")
		await _rig.settle()
		_rig.intent(&"back")
		await _rig.settle()
		assert_array(RunUiRig.texts(_rig.top())).not_contains([line])
		_rig.finish()
		_rig = null


func test_ok_and_fresh_have_no_load_line() -> void:
	for status: StringName in [&"OK", &"FRESH"]:
		var meta: RunUiRig.FakeMeta = RunUiRig.FakeMeta.new(RunUiRig.database())
		meta.status = status
		await _start(meta)
		var labels: int = RunUiRig.texts(_rig.top()).size()
		assert_int(labels).is_equal(2)
		_rig.finish()
		_rig = null


func test_the_stats_line_reads_the_profile() -> void:
	var meta: RunUiRig.FakeMeta = RunUiRig.FakeMeta.new(RunUiRig.database())
	meta.stats = {"runs_started": 7, "runs_won": 2, "best_floor_reached": 6}
	await _start(meta)
	assert_array(RunUiRig.texts(_rig.top())).contains([tr("menu.stats").format({"runs": 7, "wins": 2, "best": 6})])


func test_an_actionable_warning_repeats_on_the_next_menu_and_summary() -> void:
	# Arrange (U5)
	await _start()
	await _rig.to_boss()
	RunCodes.warn(_rig.run.run_log, RunCodes.W_SAVE_FAILED, {})

	# Act
	await _rig.lose_floor()

	# Assert
	var line: String = tr("warning.save_failed")
	assert_str(" ".join(RunUiRig.texts(_rig.top()))).contains(line)
	_rig.intent(&"go_main_menu")
	await _rig.settle()
	assert_array(RunUiRig.texts(_rig.top())).contains([line])


func test_a_quiet_warning_is_a_toast_and_no_status_line() -> void:
	await _start()
	await _rig.to_boss()
	RunCodes.warn(_rig.run.run_log, RunCodes.W_THEME_ADJACENT, {})
	await _rig.lose_floor()
	assert_str(" ".join(RunUiRig.texts(_rig.top()))).not_contains(tr("warning.theme_adjacent"))
	assert_array(_rig.toasts.map(func(row: Array) -> String: return str(row[1].title))).contains([tr("warning.theme_adjacent")])


# --- E_CORRUPT ----------------------------------------------------------------------

## A saved run whose record breaks an R1 invariant, on the resume prompt.
func _corrupt_on_prompt() -> void:
	await _start()
	await _rig.to_boss()
	_rig.intent(&"open_pause")
	await _rig.settle()
	_rig.intent(&"go_main_menu")
	await _rig.settle()
	var saved: Dictionary = _rig.meta._active_run
	saved["floor"] = int(saved.floors_per_run) + 1
	_rig.intent(&"continue_requested")
	await _rig.settle()


func test_ac13_e_corrupt_replaces_the_prompt_with_a_reason_and_one_button() -> void:
	# Arrange
	await _corrupt_on_prompt()

	# Act
	_rig.intent(&"continue")
	await _rig.settle()

	# Assert
	assert_str(_top()).is_equal("notice")
	assert_array(_rig.controller.state.overlays).is_equal([&"notice"])
	var body: String = tr("notice.resume.body").format({"reason": tr("notice.reason.E_CORRUPT")})
	assert_array(RunUiRig.texts(_rig.top())).contains([tr("notice.resume.title"), body])
	var buttons: Array = _rig.top().find_children("*", "Button", true, false).map(func(b: Button) -> String: return b.text)
	assert_array(buttons).is_equal([tr("menu.new_run")])
	assert_str((_rig.focus() as Button).text).is_equal(tr("menu.new_run"))


func test_ac13_no_abandon_is_sent_and_no_loss_is_recorded() -> void:
	# Arrange
	await _corrupt_on_prompt()

	# Act
	_rig.intent(&"continue")
	await _rig.settle()

	# Assert: the machine archived it as a system abandon, not the player's
	var archived: Array = _fake().calls.filter(func(row: Dictionary) -> bool: return row.method == "archive_run")
	assert_int(archived.size()).is_equal(1)
	assert_str(str(archived[0].args[0].result.abandon_reason)).is_equal(RunCodes.REASON_SAVE_CORRUPT)
	assert_object(_rig.meta.load_active_run()).is_null()


func test_ac13_esc_does_not_close_the_notice() -> void:
	await _corrupt_on_prompt()
	_rig.intent(&"continue")
	await _rig.settle()
	await _rig.key(KEY_ESCAPE)
	await _rig.settle()
	assert_str(_top()).is_equal("notice")


func test_ac13_new_run_opens_hero_select_and_the_continue_card_is_gone() -> void:
	# Arrange
	await _corrupt_on_prompt()
	_rig.intent(&"continue")
	await _rig.settle()

	# Act
	await _rig.key(KEY_ENTER)
	await _rig.settle()

	# Assert
	assert_str(String(_rig.shell.screen())).is_equal("hero_select")
	_rig.intent(&"back")
	await _rig.settle()
	assert_str(String(_rig.shell.screen())).is_equal("main_menu")
	var labels: Array = _rig.top().find_children("*", "Button", true, false).map(func(b: Button) -> String: return b.text)
	assert_str(str(labels[0])).is_equal(tr("menu.new_run"))


func test_every_resume_failure_code_has_a_reason() -> void:
	for code: Error in [RunCodes.E_NO_SAVE, RunCodes.E_SCHEMA, RunCodes.E_DATA_VERSION, RunCodes.E_CORRUPT, RunCodes.E_UNKNOWN_ID]:
		var key: String = "notice.reason.%s" % RunCodes.code_name(code)
		assert_bool(RunUiRig.config().strings.has(key)).override_failure_message(key).is_true()
