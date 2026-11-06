## Integration: AC-30, no hardcoded values (design/gdd/meta-progression.md Tuning Knobs,
## M9). Each knob is proved read from data the only way that can fail: set it away from
## its default and watch the behaviour move. The shipped file is then held to the table,
## and a scan holds the code to "`PROFILE_SCHEMA_VERSION` is the one code constant".
##
## Knobs whose behaviour is pinned elsewhere are named here so the table stays complete:
## `io_retry_ms` and `backup_count` in `profile_store_write_test.gd`, the condition limits
## in `unlock_validate_defs_test.gd` and `meta_unlock_stage7_test.gd`.
extends GdUnitTestSuite

const DEFAULTS_FILE: String = "res://assets/data/profile_defaults.json"
const CODE_DIRS: Array[String] = ["res://src/core/save/", "res://src/gameplay/meta/"]
## The Tuning Knobs table, as shipped.
const KNOB_TABLE: Dictionary = {
	"run_log_cap": 200,
	"archive_top_cards": 10,
	"max_profile_bytes": 2097152,
	"max_save_ms": 50,
	"backup_count": 1,
	"io_retry_ms": 250,
	"settings_write_debounce_ms": 500,
	"lock_heartbeat_s": 30,
	"lock_stale_s": 90,
	"max_condition_depth": 3,
	"max_condition_n": 999,
	"max_condition_fan_out": 8,
	"max_floor_clamp": 12,
	"max_repairs_before_rebuild": 25,
}
## Numbers a knob's value would be, which the code must not spell. `0`, `1` and `2` are
## arithmetic everywhere; these are not.
const KNOB_LITERALS: Array[String] = ["200", "250", "500", "2097152", "999999", "100000000"]

var _root: String
var _clock: ProfileFixtures.ManualClock


func before_test() -> void:
	_root = ProfileFixtures.new_root()
	_clock = ProfileFixtures.ManualClock.new()


func after_test() -> void:
	ProfileFixtures.remove_root(_root)


func _shipped() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(DEFAULTS_FILE)).config


func _loaded_store(knob_overrides: Dictionary) -> ProfileStore:
	var store: ProfileStore = ProfileFixtures.store(_root, _clock, knob_overrides)
	store.load_profile()
	return store


## Every `.gd` under [param dir], recursively.
func _scripts_under(dir: String) -> Array[String]:
	var paths: Array[String] = []
	for file: String in DirAccess.get_files_at(dir):
		if file.get_extension() == "gd":
			paths.append(dir.path_join(file))
	for sub: String in DirAccess.get_directories_at(dir):
		paths.append_array(_scripts_under(dir.path_join(sub)))
	return paths


# --- The shipped file ----------------------------------------------------------

func test_shipped_knobs_are_the_tuning_knobs_table() -> void:
	# Act
	var knobs: Dictionary = _shipped()[ProfileStore.KNOBS_KEY]

	# Assert
	for knob: String in KNOB_TABLE:
		assert_int(int(knobs[knob])).override_failure_message(knob).is_equal(KNOB_TABLE[knob])


func test_shipped_settings_are_the_m9_defaults() -> void:
	# Act
	var settings: Dictionary = ProfileStore.settings_defaults(_shipped())

	# Assert: value by value, since JSON gives every number as a float
	var expected: Dictionary = ProfileFixtures.settings_defaults()
	assert_array(settings.keys()).contains_exactly_in_any_order(expected.keys())
	for key: String in expected:
		assert_bool(settings[key] == expected[key]).override_failure_message(key).is_true()


func test_shipped_file_passes_its_own_validator() -> void:
	# Act / Assert
	assert_array(ProfileDefaults.validate_config(_shipped(), null)).is_empty()


func test_shipped_file_carries_no_bindings() -> void:
	# Act / Assert (ADR-0004 addendum 1)
	assert_bool(_shipped().has("bindings")).is_false()


# --- Each knob moves the behaviour ---------------------------------------------

func test_run_log_cap_comes_from_the_knob() -> void:
	# Arrange
	var store: ProfileStore = _loaded_store({"run_log_cap": 2})

	# Act
	for index: int in 3:
		store.archive_run(ProfileFixtures.victory("run_%d" % index))

	# Assert
	assert_int(store.run_log_count()).is_equal(2)


func test_archive_top_cards_comes_from_the_knob() -> void:
	# Arrange
	var store: ProfileStore = _loaded_store({"archive_top_cards": 5})

	# Act
	var entry: Dictionary = store.archived_form(ProfileFixtures.full_record("run_a"))

	# Assert
	assert_int(entry.match_summaries[0].damage_by_card.size()).is_equal(5 + 1)


func test_max_repairs_comes_from_the_knob() -> void:
	# Act / Assert
	assert_int(_loaded_store({"max_repairs_before_rebuild": 7}).max_repairs()).is_equal(7)


func test_max_floor_clamp_comes_from_the_knob() -> void:
	# Arrange
	var profile: Dictionary = ProfileFixtures.profile_dict()
	var hero: Dictionary = ProfileSchema.empty_hero_stats()
	hero["best_floor_reached"] = 40
	profile.stats.heroes[ProfileFixtures.HERO_WAR] = hero

	# Act
	ProfileSchema.repair(profile, ProfileFixtures.settings_defaults(), ProfileFixtures.knobs({"max_floor_clamp": 9}))

	# Assert
	assert_int(profile.stats.heroes[ProfileFixtures.HERO_WAR].best_floor_reached).is_equal(9)


func test_count_and_duration_clamps_come_from_the_knobs() -> void:
	# Arrange
	var profile: Dictionary = ProfileFixtures.profile_dict()
	profile.stats["total_turns"] = 5000
	profile.stats["total_play_seconds"] = 5000

	# Act
	ProfileSchema.repair(profile, ProfileFixtures.settings_defaults(), ProfileFixtures.knobs({"max_count": 100, "max_duration_s": 200}))

	# Assert
	assert_int(profile.stats.total_turns).is_equal(100)
	assert_int(profile.stats.total_play_seconds).is_equal(200)


func test_lock_stale_s_comes_from_the_knob() -> void:
	# Arrange: 40 s is stale under a 30 s knob, live at the default
	ProfileFixtures.write_foreign_lock(_root, _clock, 40)
	var store: ProfileStore = ProfileFixtures.store(_root, _clock, {"lock_stale_s": 30})

	# Act
	var loaded: Dictionary = store.load_profile()

	# Assert
	assert_bool(loaded.status == SaveErrors.STATUS_LOCKED).is_false()


func test_timers_read_the_debounce_and_heartbeat_knobs() -> void:
	# Arrange
	var store: ProfileStore = _loaded_store({"settings_write_debounce_ms": 123, "lock_heartbeat_s": 45})

	# Act / Assert
	assert_int(store.debounce_ms()).is_equal(123)
	assert_int(store.heartbeat_s()).is_equal(45)


func test_reset_token_comes_from_the_knob() -> void:
	# Arrange
	var store: ProfileStore = _loaded_store({"reset_confirm_token": "WIPE"})

	# Act / Assert
	assert_int(store.reset_profile(ProfileFixtures.RESET_TOKEN)).is_equal(SaveErrors.E_RANGE)
	assert_int(store.reset_profile("WIPE")).is_equal(OK)


func test_max_save_ms_comes_from_the_knob() -> void:
	# Arrange: a budget nothing can meet warns, a generous one does not
	var log: SlowSaveLog = SlowSaveLog.new()
	var strict: ProfileStore = _loaded_store({"max_save_ms": -1})
	var outcome: Error = OK

	# Act
	OS.add_logger(log)
	outcome = strict.save_profile()
	var strict_warnings: int = log.warnings
	strict.release_lock()
	log.warnings = 0
	_loaded_store({"max_save_ms": 100000}).save_profile()
	OS.remove_logger(log)

	# Assert: a diagnostic, the write stands
	assert_int(outcome).is_equal(OK)
	assert_int(strict_warnings).is_equal(1)
	assert_int(log.warnings).is_equal(0)


func test_from_config_takes_the_lock_window_and_knobs_from_the_body() -> void:
	# Arrange: built only, so `user://profile.json` is never read
	var body: Dictionary = ProfileFixtures.defaults_body({"lock_stale_s": 77, "settings_write_debounce_ms": 11})

	# Act
	var store: ProfileStore = ProfileStore.from_config(body)

	# Assert
	assert_int(store._lock._stale_s).is_equal(77)
	assert_int(store.debounce_ms()).is_equal(11)


func test_settings_defaults_come_from_the_body_not_from_code() -> void:
	# Arrange
	var body: Dictionary = ProfileFixtures.defaults_body()
	body["gamma"] = 1.1
	var defaults: Dictionary = ProfileStore.settings_defaults(body)
	var clock_read: Callable = _clock.read
	var lock: ProfileLock = ProfileLock.new(_root.path_join("profile.lock"), 90, clock_read)
	var store: ProfileStore = ProfileStore.new(defaults, body[ProfileStore.KNOBS_KEY], AtomicFileWriter.new(), lock, clock_read, _root)

	# Act
	store.load_profile()

	# Assert
	assert_float(store.get_setting(&"gamma")).is_equal(1.1)
	assert_bool(defaults.has(ProfileStore.KNOBS_KEY)).is_false()


func test_compose_reads_abandon_counts_as_loss_from_run_structure() -> void:
	# Arrange: Run Structure's knob, not duplicated (M7.2)
	var db: KnobDatabase = KnobDatabase.new({"abandon_counts_as_loss": false})

	# Act
	var meta: MetaFacade = MetaFacade.compose(db)

	# Assert
	assert_bool(meta._fold.is_void(ProfileFixtures.abandoned("run_a", ProfileFixtures.HERO_WAR, 2, "player"))).is_true()


func test_compose_reads_the_condition_limits_from_the_body() -> void:
	# Arrange
	var db: KnobDatabase = KnobDatabase.new({})
	db.knob_overrides = {"max_condition_depth": 5}
	var deep: Dictionary = ProfileFixtures.runs_won(1)
	for _level: int in 4:
		deep = {"type": "all_of", "of": [deep]}

	# Act
	var rows: Array = MetaFacade.compose(db).validate_unlock_defs([{"host_kind": &"treasure", "host_id": "treasure_x",
		"unlock": {"key": "a_key", "condition": deep}}])

	# Assert: five levels pass only under the data's limit
	assert_array(rows).is_empty()


## Counts the over-budget warning of a write.
class SlowSaveLog:
	extends Logger

	var warnings: int = 0

	func _log_error(_function: String, _file: String, _line: int, message: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if (message + rationale).contains("over max_save_ms"):
			warnings += 1


## A database with a `run_structure` body and the fixture `profile_defaults`.
class KnobDatabase:
	extends ProfileFixtures.UnlockDatabase

	var knob_overrides: Dictionary = {}
	var _run_structure: Dictionary

	func _init(run_structure: Dictionary) -> void:
		super(ProfileFixtures.m10_heroes(), ProfileFixtures.m10_treasures())
		_run_structure = run_structure

	func config(config_name: String) -> Variant:
		if config_name == "run_structure":
			return _run_structure
		return ProfileFixtures.defaults_body(knob_overrides)


# --- The one code constant -----------------------------------------------------

func test_save_and_meta_code_spells_no_knob_value() -> void:
	# Arrange
	var pattern: RegEx = RegEx.create_from_string("(?<![\\w.\"])(%s)(?![\\w.])" % "|".join(KNOB_LITERALS))
	var hits: Array[String] = []

	# Act
	for dir: String in CODE_DIRS:
		for path: String in _scripts_under(dir):
			var number: int = 0
			for line: String in FileAccess.get_file_as_string(path).split("\n"):
				number += 1
				var code: String = line.get_slice("#", 0)
				if pattern.search(code) != null and not code.contains("MAX_EXACT_INT") and not path.ends_with("profile_defaults.gd"):
					hits.append("%s:%d %s" % [path, number, line.strip_edges()])

	# Assert: `profile_defaults.gd` holds the safe ranges, which are the validator's own table
	assert_array(hits).is_empty()


func test_profile_schema_version_is_the_only_int_const_of_the_store() -> void:
	# Arrange
	var script: GDScript = load("res://src/core/save/profile_store.gd")

	# Act
	var ints: Array = []
	var constants: Dictionary = script.get_script_constant_map()
	for name: String in constants:
		if constants[name] is int and not name == "State":
			ints.append(name)

	# Assert
	assert_array(ints).is_equal(["PROFILE_SCHEMA_VERSION"])
