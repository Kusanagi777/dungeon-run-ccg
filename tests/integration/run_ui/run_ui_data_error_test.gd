## `data_error` drawn from `RunShell.FALLBACK_CONFIG` (S2, AC-8; TD-008): the one screen
## that reports bad data must not depend on good data, so here the broken file is
## `run_ui.json` itself.
extends GdUnitTestSuite

const SHELL_SCENE: PackedScene = preload("res://src/ui/run/run_shell.tscn")
const BAD_CONFIG_ROOT: String = "res://tests/fixtures/data/minimal/"
const SCREEN_SCENE: String = "res://src/ui/run/screens/data_error.tscn"
const ROW_COUNT: int = 12


func _failed_on_run_ui() -> CardDatabase:
	var db: CardDatabase = CardDatabase.new(DataLoader.new(BAD_CONFIG_ROOT))
	var validators: Dictionary = ValidatorStubs.accept_all()
	# The real validator, on a body with a knob out of range and its fonts gone
	validators.configs.run_ui = func(body: Dictionary, loaded: Variant) -> Array:
		var bad: Dictionary = body.duplicate(true)
		bad.node_d = 99
		bad.erase("font_px")
		return RunUiConfig.validate_config(bad, loaded)
	var _report: ValidationReport = db.load(validators)
	return db


func _shell(db: CardDatabase) -> RunShell:
	var services: Services = Services.new()
	services.card_database = db
	var shell: RunShell = auto_free(SHELL_SCENE.instantiate())
	shell.bind(services)
	add_child(shell)
	await get_tree().process_frame
	return shell


func _screen(shell: RunShell) -> Screen:
	return shell._top()


func _key(shell: RunShell, keycode: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	shell.get_viewport().push_input(event)
	await get_tree().process_frame


func test_a_bad_run_ui_config_fails_the_load() -> void:
	var db: CardDatabase = _failed_on_run_ui()
	assert_int(db.state()).is_equal(CardDatabase.State.FAILED)
	var files: Array = db.report().errors().map(func(row: Dictionary) -> String: return str(row.get("file", "")))
	assert_array(files).contains(["run_ui.json"])


func test_the_screen_draws_from_the_fallback_with_every_row() -> void:
	# Arrange
	var db: CardDatabase = _failed_on_run_ui()
	var rows: Array = RunReadModels.data_error(db.report()).rows

	# Act
	var shell: RunShell = await _shell(db)

	# Assert
	assert_str(String(shell.screen())).is_equal("data_error")
	assert_object(shell.controller()).is_null()
	assert_dict(_screen(shell).cfg).is_equal(RunShell.FALLBACK_CONFIG)
	var text: Array[String] = RunUiRig.texts(_screen(shell))
	assert_array(text).contains([RunShell.FALLBACK_CONFIG.strings["error.title"]])
	assert_array(text).contains([str(RunShell.FALLBACK_CONFIG.strings["error.count"]).format({"n": rows.size()})])
	for row: Dictionary in rows:
		assert_array(text).contains(["%s  %s  [%s]  %s" % [row.file, row.id, row.code, row.message]])


func test_only_copy_report_and_quit_exist_and_quit_is_focused() -> void:
	var shell: RunShell = await _shell(_failed_on_run_ui())
	var buttons: Array = _screen(shell).find_children("*", "Button", true, false).map(func(b: Button) -> String: return b.text)
	assert_array(buttons).is_equal([RunShell.FALLBACK_CONFIG.strings["error.copy"], RunShell.FALLBACK_CONFIG.strings["menu.quit"]])
	assert_str((shell.get_viewport().gui_get_focus_owner() as Button).text).is_equal(RunShell.FALLBACK_CONFIG.strings["menu.quit"])


func test_the_fallback_holds_every_string_and_token_the_screen_asks_for() -> void:
	# A prior suite's `RunText` would hide a missing key, so the body is read directly.
	var strings: Dictionary = RunShell.FALLBACK_CONFIG.strings
	for key: String in ["error.title", "error.count", "error.copy", "menu.quit"]:
		assert_bool(strings.has(key)).override_failure_message(key).is_true()
	for role: String in RunUiConfig.FONT_ROLES:
		assert_bool((RunShell.FALLBACK_CONFIG.font_px as Dictionary).has(role)).override_failure_message(role).is_true()
	var palette: Dictionary = RunShell.FALLBACK_CONFIG.palette
	var tokens: Array = RunUiTheme.PANEL_ROLES.values()
	for role: StringName in RunUiTheme.LABEL_ROLES:
		tokens.append(RunUiTheme.LABEL_ROLES[role][1])
	tokens.append_array(["state_actionable", "bg_edge", "neutral", "text_muted"])
	for token: String in tokens:
		assert_bool(palette.has(token)).override_failure_message(token).is_true()


func test_the_fallback_matches_the_shipped_values() -> void:
	# A drifted copy would draw the error screen in the wrong colours and sizes
	var cfg: Dictionary = RunUiRig.config()
	for token: String in RunShell.FALLBACK_CONFIG.palette:
		assert_str(str(RunShell.FALLBACK_CONFIG.palette[token])).override_failure_message(token).is_equal(str(cfg.palette[token]))
	for role: String in RunShell.FALLBACK_CONFIG.font_px:
		assert_int(int(RunShell.FALLBACK_CONFIG.font_px[role])).override_failure_message(role).is_equal(int(cfg.font_px[role]))
	for key: String in RunShell.FALLBACK_CONFIG.strings:
		assert_str(str(RunShell.FALLBACK_CONFIG.strings[key])).override_failure_message(key).is_equal(str(cfg.strings[key]))


func test_the_ring_and_the_theme_come_from_the_fallback_not_magenta() -> void:
	var shell: RunShell = await _shell(_failed_on_run_ui())
	assert_object(shell._ring._ring_color).is_equal(Color.html(str(RunShell.FALLBACK_CONFIG.palette.state_actionable)))
	var theme: Theme = shell._stack.theme
	for role: StringName in RunUiTheme.LABEL_ROLES:
		assert_object(theme.get_color(&"font_color", role)).override_failure_message(String(role)).is_not_equal(Color.MAGENTA)


func test_no_key_reaches_another_screen() -> void:
	# Arrange (AC-8)
	var shell: RunShell = await _shell(_failed_on_run_ui())
	var screen: Screen = _screen(shell)

	# Act: not Enter, which is on Quit
	for keycode: Key in [KEY_ESCAPE, KEY_1, KEY_2, KEY_3, KEY_TAB, KEY_SPACE, KEY_UP]:
		await _key(shell, keycode)

	# Assert
	assert_object(_screen(shell)).is_same(screen)
	assert_str(String(shell.screen())).is_equal("data_error")


func test_quit_sends_quit_requested() -> void:
	# Arrange: on its own, so the press does not end the test run
	var screen: Screen = auto_free((load(SCREEN_SCENE) as PackedScene).instantiate())
	screen.cfg = RunShell.FALLBACK_CONFIG
	add_child(screen)
	screen.bind({"rows": [], "report_text": ""})
	var sent: Array = []
	screen.intent_requested.connect(func(name: StringName, _args: Dictionary) -> void: sent.append(name))

	# Act
	(screen.default_focus() as Button).pressed.emit()

	# Assert
	assert_array(sent).is_equal([&"quit_requested"])


func test_twelve_rows_render_from_the_sample_shape() -> void:
	# Arrange (AC-8's fixture): no controller, as `RunDebugLoader.open` finds on a failed load
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/run_ui/data_error_sample.json"))
	var shell: RunShell = await _shell(_failed_on_run_ui())

	# Act
	shell.open_base(RunController.SCREEN_DATA_ERROR, parsed.overrides, RunShell.NO_TRANSITION)
	await get_tree().process_frame

	# Assert
	var rows: Array = RunUiRig.texts(_screen(shell)).filter(func(text: String) -> bool: return text.contains("  ["))
	assert_int(rows.size()).is_equal(ROW_COUNT)
	assert_int(_screen(shell).find_children("*", "Button", true, false).size()).is_equal(2)
