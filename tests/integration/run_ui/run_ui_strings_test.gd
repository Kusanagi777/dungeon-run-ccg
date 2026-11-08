## AC-22: no literal English in `src/ui/run/**`, and the reverse: every key the scripts
## and the run codes ask for is in `config("run_ui").strings`, so nothing renders as a raw
## key. A source scan, so it reads files by design.
extends GdUnitTestSuite

const SRC_ROOT: String = "res://src/ui/run/"
## A call that shows its argument, with a literal of letters and a space in it.
const SHOWN_LITERAL: String = "(UiKit\\.(label|button)\\(|\\.text\\s*=\\s*|\\.tooltip_text\\s*=\\s*|placeholder_text\\s*=\\s*)\"[^\"]*[A-Za-z]{2,}[^\"]*\""
const KEY_CALL: String = "(?:\\btr|RunText\\.t)\\(\"([a-z_]+(?:\\.[a-z_0-9]+)+)\""


func _scripts(folder: String) -> Array[String]:
	var found: Array[String] = []
	for file: String in DirAccess.get_files_at(folder):
		if file.ends_with(".gd"):
			found.append(folder.path_join(file))
	for sub: String in DirAccess.get_directories_at(folder):
		found.append_array(_scripts(folder.path_join(sub)))
	return found


func _strings() -> Dictionary:
	return RunUiRig.config().strings


func _constants_starting(prefix: String) -> Array:
	var constants: Dictionary = (load("res://src/gameplay/run/run_codes.gd") as GDScript).get_script_constant_map()
	var values: Array = []
	for name: String in constants:
		if name.begins_with(prefix):
			values.append(constants[name])
	return values


func test_ac22_no_script_passes_a_literal_to_the_screen() -> void:
	var pattern: RegEx = RegEx.create_from_string(SHOWN_LITERAL)
	var hits: Array[String] = []
	for path: String in _scripts(SRC_ROOT):
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for i: int in lines.size():
			var line: String = lines[i].strip_edges()
			if not line.begins_with("#") and pattern.search(line) != null:
				hits.append("%s:%d %s" % [path, i + 1, line])
	assert_array(hits).is_empty()


func test_the_scan_catches_a_literal_when_there_is_one() -> void:
	var pattern: RegEx = RegEx.create_from_string(SHOWN_LITERAL)
	assert_object(pattern.search("add_child(UiKit.label(\"Start game\"))")).is_not_null()
	assert_object(pattern.search("label.text = \"Paused\"")).is_not_null()
	assert_object(pattern.search("UiKit.label(tr(\"pause.title\"))")).is_null()


func test_every_literal_key_a_script_asks_for_has_a_string() -> void:
	var pattern: RegEx = RegEx.create_from_string(KEY_CALL)
	var missing: Array[String] = []
	for path: String in _scripts(SRC_ROOT):
		for found: RegExMatch in pattern.search_all(FileAccess.get_file_as_string(path)):
			if not _strings().has(found.get_string(1)):
				missing.append("%s: %s" % [path.get_file(), found.get_string(1)])
	assert_array(missing).is_empty()


func test_every_run_warning_has_a_string() -> void:
	for code: Variant in _constants_starting("W_"):
		var key: String = "warning.%s" % str(code)
		assert_bool(_strings().has(key)).override_failure_message(key).is_true()
	assert_bool(_strings().has("warning.%s" % RunController.FAULT_WARNING)).is_true()
	assert_bool(_strings().has("warning.%s" % RunController.MISSING_WARNING)).is_true()


func test_every_rejection_a_command_can_return_has_a_string() -> void:
	# U8, S8: the codes `new_run`, `begin_match` and `draft_pick` return to the UI
	for code: Error in [RunCodes.E_BAD_PHASE, RunCodes.E_CONFIG, RunCodes.E_HERO_LOCKED, RunCodes.E_UNKNOWN_ID, RunCodes.E_NOT_OFFERED, RunCodes.E_DRAFT_DONE, RunCodes.E_DRAFT_KIND]:
		var key: String = "rejected.%s" % RunCodes.code_name(code)
		assert_bool(_strings().has(key)).override_failure_message(key).is_true()


func test_every_settings_row_and_choice_has_a_string() -> void:
	for key: String in ["volume_master", "volume_music", "volume_sfx", "fullscreen", "action_delay_ms", "anim_speed", "reduce_motion", "text_scale", "telegraph_mode", "high_contrast_states", "gamma", "keep_run_records"]:
		assert_bool(_strings().has("settings.key.%s" % key)).override_failure_message(key).is_true()
	for choice: String in ["anim_speed.instant", "anim_speed.fast", "anim_speed.normal", "telegraph_mode.full", "telegraph_mode.brief", "telegraph_mode.off"]:
		assert_bool(_strings().has("settings.%s" % choice)).override_failure_message(choice).is_true()


func test_every_rebindable_action_and_glossary_keyword_has_its_strings() -> void:
	var cfg: Dictionary = RunUiRig.config()
	for group: String in cfg.controls.actions:
		for action: String in cfg.controls.actions[group]:
			assert_bool(_strings().has("controls.action.%s" % action)).override_failure_message(action).is_true()
	for keyword: String in cfg.glossary.keywords:
		assert_bool(_strings().has("glossary.%s.name" % keyword)).override_failure_message(keyword).is_true()
		assert_bool(_strings().has("glossary.%s.text" % keyword)).override_failure_message(keyword).is_true()


func test_every_phase_load_status_and_reason_has_a_string() -> void:
	for phase: String in [RunState.STATUS_PRE_MATCH, RunState.STATUS_IN_MATCH, RunState.STATUS_POST_MATCH_REWARD]:
		assert_bool(_strings().has("phase.%s" % phase)).override_failure_message(phase).is_true()
	for status: StringName in [SaveErrors.STATUS_RECOVERED_BAK, SaveErrors.STATUS_FRESH_AFTER_CORRUPT, SaveErrors.STATUS_SCHEMA_NEWER, SaveErrors.STATUS_LOCKED]:
		assert_bool(_strings().has("load.%s" % status)).override_failure_message(String(status)).is_true()
	for reason: String in [RunCodes.REASON_PLAYER, RunCodes.REASON_DATA_VERSION_MISMATCH, RunCodes.REASON_SAVE_CORRUPT]:
		assert_bool(_strings().has("summary.abandoned.%s" % reason)).override_failure_message(reason).is_true()
	for outcome: String in ["victory", "defeat"]:
		for why: String in ["hero_dead", "both_dead", "concede", "turn_cap"]:
			assert_bool(_strings().has("summary.reason.%s.%s" % [outcome, why])).override_failure_message(why).is_true()


func test_every_theme_and_rarity_in_the_data_has_a_string() -> void:
	var db: CardDatabase = RunUiRig.database()
	for treasure: Dictionary in db.treasure_pool():
		assert_bool(_strings().has("rarity.%s" % str(treasure.get("rarity", "common")))).override_failure_message(str(treasure.id)).is_true()
	for hero: Dictionary in db.heroes():
		for bundle: Dictionary in db.bundle_pool(str(hero.set)):
			assert_bool(_strings().has("theme.%s" % str(bundle.theme))).override_failure_message(str(bundle.id)).is_true()


func test_every_hero_set_has_a_blurb_and_a_colour() -> void:
	var db: CardDatabase = RunUiRig.database()
	for hero: Dictionary in db.heroes():
		var set_id: String = str(hero.get("set", ""))
		assert_bool(_strings().has("hero.blurb.%s" % set_id)).override_failure_message(set_id).is_true()
		assert_bool(RunUiRig.config().palette.has(set_id)).override_failure_message(set_id).is_true()


func test_every_unlock_condition_a_hint_can_name_has_a_string() -> void:
	for kind: String in ["always", "all_of", "any_of", "boss_defeated", "floor_reached", "runs_won", "treasure_picked"]:
		assert_bool(_strings().has("unlock.condition.%s" % kind)).override_failure_message(kind).is_true()
	for kind: String in ["hero", "treasure", "bundle"]:
		assert_bool(_strings().has("unlock.toast.%s" % kind)).override_failure_message(kind).is_true()
