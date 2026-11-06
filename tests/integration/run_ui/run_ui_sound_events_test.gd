## Which audio events the shell raises, and in what order (run-ui Visual/Audio;
## interaction-patterns Sound Standards; draft-picker.md §8). The rig's `SfxLog` records
## the events: what they sound like is manual, and no file ships yet.
extends GdUnitTestSuite

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


func _start(settings: Dictionary = RunUiRig.INSTANT, meta: MetaApi = null) -> void:
	_rig = await RunUiRig.start(self, meta, settings)


func _events() -> Array[StringName]:
	return _rig.sfx.events


## The recorded events without the focus ticks, which any screen open adds.
func _without_hover() -> Array:
	return _events().filter(func(event: StringName) -> bool: return event != RunShell.SFX_HOVER)


func _clear() -> void:
	_events().clear()


## Walks a real run to its first bundle pick, returning the events after the menu.
func _walk(settings: Dictionary) -> Array:
	await _start(settings)
	if settings.get("anim_speed") != "instant":
		_rig.intent(&"skip")
		await _rig.settle()
	_clear()
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
	_rig.intent(&"pick", {"index": 0})
	await _rig.key(KEY_X)
	_rig.intent(&"skip")
	await _rig.settle()
	return _without_hover()


func test_the_menu_starts_the_ambient_loop() -> void:
	await _start()
	assert_array(_events()).contains([RunShell.MUSIC_AMBIENT])


func test_the_loop_stops_for_the_match_which_plays_its_own_and_comes_back() -> void:
	await _start()
	await _rig.to_boss()
	_clear()
	await _rig.lose_floor()
	assert_int(_events().find(RunUiRig.STOP_MUSIC)).is_greater_equal(0)
	assert_int(_events().find(RunShell.MUSIC_AMBIENT)).is_greater(_events().find(RunUiRig.STOP_MUSIC))


func test_a_run_raises_its_events_in_screen_order() -> void:
	# Act
	var events: Array = await _walk(RunUiRig.INSTANT)

	# Assert: music around the match aside
	assert_array(events).is_equal([&"run_start", &"boss_intro_1", RunUiRig.STOP_MUSIC, RunShell.MUSIC_AMBIENT, &"ui_draft_reveal", &"ui_pick", &"ui_draft_reveal"])


func test_reduce_motion_and_every_speed_raise_the_same_events() -> void:
	# Every sound is the audio half of a visible event, and those still happen
	var instant: Array = await _walk(RunUiRig.INSTANT)
	_rig.finish()
	var normal: Array = await _walk({"anim_speed": "normal"})
	_rig.finish()
	var reduced: Array = await _walk({"anim_speed": "normal", "reduce_motion": true})
	assert_array(normal).is_equal(instant)
	assert_array(reduced).is_equal(instant)


func test_the_pick_sound_comes_before_the_screen_the_pick_opens() -> void:
	# Arrange: at normal the next screen waits out the landing
	await _start({"anim_speed": "normal"})
	_rig.intent(&"skip")
	await _rig.settle()
	_rig.intent(&"new_run_requested")
	_rig.intent(&"skip")
	await _rig.settle()
	_rig.intent(&"start_run", {"hero_id": "hero_war", "seed_input": ""})
	_rig.intent(&"skip")
	await _rig.settle()
	_rig.intent(&"skip")
	await _rig.settle()
	await _rig.win_floor()
	_rig.intent(&"skip")
	await _rig.settle()
	_clear()

	# Act
	_rig.intent(&"pick", {"index": 0})

	# Assert: `ui_pick` now; the reveal only once the landing is over
	assert_array(_without_hover()).is_equal([&"ui_pick"])
	await _rig.key(KEY_X)
	assert_array(_without_hover()).is_equal([&"ui_pick", &"ui_draft_reveal"])


func test_a_refused_pick_is_silent() -> void:
	await _start()
	await _rig.to_boss()
	await _rig.win_floor()
	_clear()
	_rig.intent(&"pick", {"index": 9})
	assert_array(_events()).is_empty()


func test_the_boss_sting_follows_the_band() -> void:
	# Arrange
	await _start()
	await _rig.to_boss()
	_rig.controller.state.overlays.clear()
	var model: Dictionary = {"band": 3}

	# Act
	_clear()
	_rig.shell._raise_screen_sound(RunController.SCREEN_BOSS, model)

	# Assert
	assert_array(_events()).is_equal([&"boss_intro_3"])


func test_defeat_and_victory_raise_their_stingers() -> void:
	# Arrange
	await _start()
	await _rig.to_boss()
	_clear()

	# Act
	await _rig.lose_floor()

	# Assert
	assert_array(_without_hover()).contains([&"run_defeat"])
	assert_array(_without_hover()).not_contains([&"run_victory"])


func test_a_button_press_raises_select_then_the_screen_it_opens() -> void:
	await _start()
	_clear()
	await _rig.key(KEY_ENTER)
	await _rig.settle()
	assert_array(_without_hover()).is_equal([&"ui_select"])


func test_a_tab_raises_a_hover_tick() -> void:
	await _start()
	_clear()
	await _rig.key(KEY_TAB)
	assert_array(_events()).is_equal([&"ui_hover"])


func test_selecting_a_draft_option_raises_select_and_confirming_raises_pick() -> void:
	# Arrange (draft-picker.md §8: first Enter `ui_select`, second `ui_pick`)
	await _start()
	await _rig.to_boss()
	await _rig.win_floor()
	await _rig.key(KEY_1)
	_clear()

	# Act / Assert
	await _rig.key(KEY_ENTER)
	assert_array(_without_hover()).is_equal([&"ui_select"])
	_clear()
	await _rig.key(KEY_ENTER)
	assert_array(_without_hover()).contains([&"ui_pick"])
	assert_array(_without_hover()).not_contains([&"ui_select"])


func test_the_pick_button_raises_only_pick() -> void:
	# Arrange
	await _start()
	await _rig.to_boss()
	await _rig.win_floor()
	await _rig.key(KEY_1)
	await _rig.key(KEY_ENTER)
	_rig.top()._pick.grab_focus()
	_clear()

	# Act
	await _rig.key(KEY_ENTER)

	# Assert
	assert_array(_without_hover()).contains([&"ui_pick"])
	assert_array(_without_hover()).not_contains([&"ui_select"])


func test_a_hero_change_raises_its_sting_and_opening_the_screen_does_not() -> void:
	await _start()
	_clear()
	_rig.intent(&"new_run_requested")
	await _rig.settle()
	assert_array(_without_hover().filter(func(event: StringName) -> bool: return String(event).begins_with("hero_sting"))).is_empty()
	await _rig.key(KEY_2)
	await _rig.key(KEY_ENTER)
	var hero_id: String = str(_rig.top()._heroes[1].id)
	assert_array(_events()).contains([StringName("hero_sting_%s" % hero_id)])


func test_opening_a_dialog_raises_overlay() -> void:
	await _start()
	await _rig.to_boss()
	_clear()
	_rig.intent(&"open_pause")
	await _rig.settle()
	assert_array(_without_hover()).is_equal([RunShell.SFX_OVERLAY])


func test_a_slider_ticks_when_moved_and_not_when_built() -> void:
	# Arrange
	await _start()
	_clear()
	_rig.intent(&"open_settings")
	await _rig.settle()
	assert_array(_events()).not_contains([RunShell.SFX_TICK])
	var slider: HSlider = _rig.top().find_children("*", "HSlider", true, false)[0]

	# Act
	slider.value = 0.5

	# Assert
	assert_int(_events().count(RunShell.SFX_TICK)).is_equal(1)


func test_a_warning_toast_is_silent_and_an_unlock_chimes() -> void:
	# Arrange
	await _start()
	_clear()

	# Act
	_rig.controller.toast.emit(&"warning", {"title": "w"})
	await _rig.settle()

	# Assert
	assert_bool(_rig.shell._toasts.is_showing()).is_true()
	assert_array(_events()).is_empty()
	_rig.shell._toasts._dismiss()
	_rig.shell._toasts._gap_ms = 0.0
	_rig.controller.toast.emit(&"unlock", {"key": "u", "title": "t"})
	await _rig.settle()
	assert_array(_events()).is_equal([&"ui_unlock"])


func test_no_screen_plays_a_sound_itself() -> void:
	# ui-code rule 5: a screen raises an event, the shell plays it
	for path: String in DirAccess.get_files_at("res://src/ui/run/screens/"):
		if path.ends_with(".gd"):
			var text: String = FileAccess.get_file_as_string("res://src/ui/run/screens/".path_join(path))
			assert_str(text).override_failure_message(path).not_contains("AudioStreamPlayer")
			assert_str(text).override_failure_message(path).not_contains(".ogg")


func test_every_event_the_shell_raises_has_a_row_in_the_sfx_table() -> void:
	var events: Dictionary = RunUiRig.config().sfx.events
	for event: StringName in [RunShell.SFX_HOVER, RunShell.SFX_SELECT, RunShell.SFX_TICK, RunShell.SFX_PICK, RunShell.SFX_UNLOCK, RunShell.SFX_OVERLAY]:
		assert_bool(events.has(String(event))).override_failure_message(String(event)).is_true()
	for band: int in [1, 2, 3]:
		assert_bool(events.has(RunShell.SFX_BOSS_INTRO % band)).is_true()
	for id: String in RunUiRig.config().sfx.screens:
		assert_bool(events.has(str(RunUiRig.config().sfx.screens[id]))).override_failure_message(id).is_true()
