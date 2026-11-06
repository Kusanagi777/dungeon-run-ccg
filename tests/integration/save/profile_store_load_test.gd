## Integration: the load side of `ProfileStore` on real files in a scratch directory
## (design/gdd/meta-progression.md M1, M5; AC-1, AC-5, AC-6, AC-7, AC-14, AC-18;
## ADR-0004 Decision 4; Edge Cases "Files and the OS").
extends GdUnitTestSuite

## Captures every warning while a store repairs a profile: AC-18 counts the lines.
class WarningLog:
	extends Logger

	var lines: Array[String] = []

	func _log_error(_function: String, _file: String, _line: int, message: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		lines.append("%s %s" % [message, rationale])

	func count_of(text: String) -> int:
		return lines.filter(func(line: String) -> bool: return line.contains(text)).size()


var _root: String
var _clock: ProfileFixtures.ManualClock


func before_test() -> void:
	_root = ProfileFixtures.new_root()
	_clock = ProfileFixtures.ManualClock.new()


func after_test() -> void:
	ProfileFixtures.remove_root(_root)


func _path(file: String) -> String:
	return _root.path_join(file)


func _store(knob_overrides: Dictionary = {}) -> ProfileStore:
	return ProfileFixtures.store(_root, _clock, knob_overrides)


func _exists(file: String) -> bool:
	return FileAccess.file_exists(_path(file))


# --- AC-1 ----------------------------------------------------------------------

func test_load_fresh_install_is_fresh_with_an_empty_m1_2_profile() -> void:
	# Act
	var loaded: Dictionary = _store().load_profile()

	# Assert
	assert_str(String(loaded.status)).is_equal(String(SaveErrors.STATUS_FRESH))
	var profile: Dictionary = loaded.profile
	assert_int(profile.schema_version).is_equal(1)
	assert_int((profile.profile_id as String).length()).is_equal(32)
	assert_bool((profile.profile_id as String).is_valid_hex_number()).is_true()
	assert_array(profile.run_log).is_empty()
	assert_that(profile.active_run).is_null()


func test_load_fresh_install_writes_no_profile_until_the_first_mutator() -> void:
	# Arrange
	var store: ProfileStore = _store()

	# Act
	store.load_profile()
	var after_load: bool = _exists("profile.json")
	store.save_active_run({"run_id": "run_a"})

	# Assert
	assert_bool(after_load).is_false()
	assert_bool(_exists("profile.json")).is_true()


func test_load_a_ready_store_answers_from_memory() -> void:
	# Arrange
	var store: ProfileStore = _store()
	store.load_profile()
	store.save_active_run({"run_id": "run_a"})
	ProfileFixtures.write_text(_path("profile.json"), "changed behind the store's back")

	# Act
	var loaded: Dictionary = store.load_profile()

	# Assert (M1.3 runs once per session)
	assert_dict(loaded.profile.active_run).is_equal({"run_id": "run_a"})


func test_load_a_valid_file_is_ok() -> void:
	# Arrange
	var stored: Dictionary = ProfileFixtures.profile_dict({"write_seq": 7})
	ProfileFixtures.write_profile(_root, stored)

	# Act
	var loaded: Dictionary = _store().load_profile()

	# Assert
	assert_str(String(loaded.status)).is_equal(String(SaveErrors.STATUS_OK))
	assert_int(loaded.profile.write_seq).is_equal(7)
	assert_str(loaded.profile.profile_id).is_equal(stored.profile_id)


func test_load_turns_json_floats_back_into_ints() -> void:
	# Arrange
	ProfileFixtures.write_profile(_root, ProfileFixtures.profile_dict({"write_seq": 7}))

	# Act
	var loaded: Dictionary = _store().load_profile()

	# Assert (ADR-0004 Decision 1)
	assert_bool(loaded.profile.write_seq is int).is_true()
	assert_bool(loaded.profile.schema_version is int).is_true()


# --- AC-5 ----------------------------------------------------------------------

func test_load_truncated_profile_recovers_from_the_backup() -> void:
	# Arrange
	var good: Dictionary = ProfileFixtures.profile_dict({"write_seq": 4})
	ProfileFixtures.write_profile(_root, good, "profile.bak")
	var text: String = JSON.stringify(ProfileFixtures.profile_dict({"write_seq": 5}), "\t")
	ProfileFixtures.write_text(_path("profile.json"), text.substr(0, text.length() / 2))

	# Act
	var loaded: Dictionary = _store().load_profile()

	# Assert
	assert_str(String(loaded.status)).is_equal(String(SaveErrors.STATUS_RECOVERED_BAK))
	assert_int(loaded.profile.write_seq).is_equal(4)
	assert_str(loaded.profile.profile_id).is_equal(good.profile_id)


func test_load_truncated_profile_keeps_a_byte_exact_corrupt_copy() -> void:
	# Arrange
	ProfileFixtures.write_profile(_root, ProfileFixtures.profile_dict(), "profile.bak")
	ProfileFixtures.write_text(_path("profile.json"), "{\"schema_version\": 1, \"profile_")
	var truncated: PackedByteArray = ProfileFixtures.read_bytes(_path("profile.json"))

	# Act
	_store().load_profile()

	# Assert
	var copy: String = "profile.corrupt-%d.json" % _clock.now
	assert_bool(_exists(copy)).is_true()
	assert_array(Array(ProfileFixtures.read_bytes(_path(copy)))).is_equal(Array(truncated))


func test_load_missing_schema_version_counts_as_unreadable() -> void:
	# Arrange
	ProfileFixtures.write_profile(_root, ProfileFixtures.profile_dict(), "profile.bak")
	ProfileFixtures.write_text(_path("profile.json"), "{\"profile_id\": \"abc\"}")

	# Act
	var loaded: Dictionary = _store().load_profile()

	# Assert (M5.1)
	assert_str(String(loaded.status)).is_equal(String(SaveErrors.STATUS_RECOVERED_BAK))
	assert_bool(_exists("profile.corrupt-%d.json" % _clock.now)).is_true()


func test_load_non_object_json_counts_as_unreadable() -> void:
	# Arrange
	ProfileFixtures.write_text(_path("profile.json"), "[1, 2, 3]")

	# Act
	var loaded: Dictionary = _store().load_profile()

	# Assert
	assert_str(String(loaded.status)).is_equal(String(SaveErrors.STATUS_FRESH_AFTER_CORRUPT))


func test_load_missing_profile_with_a_backup_recovers_and_keeps_no_corrupt_copy() -> void:
	# Arrange
	ProfileFixtures.write_profile(_root, ProfileFixtures.profile_dict({"write_seq": 4}), "profile.bak")

	# Act
	var loaded: Dictionary = _store().load_profile()

	# Assert (Edge Cases "profile.json is missing but profile.bak exists")
	assert_str(String(loaded.status)).is_equal(String(SaveErrors.STATUS_RECOVERED_BAK))
	assert_int(loaded.profile.write_seq).is_equal(4)
	assert_array(ProfileFixtures.files_with_prefix(_root, "profile.corrupt")).is_empty()


# --- AC-6 ----------------------------------------------------------------------

func test_load_both_files_unreadable_starts_fresh_after_corrupt() -> void:
	# Arrange
	ProfileFixtures.write_text(_path("profile.json"), "{ broken json")
	ProfileFixtures.write_text(_path("profile.bak"), "also broken")

	# Act
	var loaded: Dictionary = _store().load_profile()

	# Assert
	assert_str(String(loaded.status)).is_equal(String(SaveErrors.STATUS_FRESH_AFTER_CORRUPT))
	assert_int(loaded.profile.write_seq).is_equal(0)


func test_load_both_files_unreadable_keeps_two_copies_and_deletes_nothing() -> void:
	# Arrange
	ProfileFixtures.write_text(_path("profile.json"), "{ broken json")
	ProfileFixtures.write_text(_path("profile.bak"), "also broken")

	# Act
	_store().load_profile()

	# Assert
	assert_str(FileAccess.get_file_as_string(_path("profile.corrupt-%d.json" % _clock.now))).is_equal("{ broken json")
	assert_str(FileAccess.get_file_as_string(_path("profile.bak.corrupt-%d.json" % _clock.now))).is_equal("also broken")
	assert_str(FileAccess.get_file_as_string(_path("profile.json"))).is_equal("{ broken json")
	assert_str(FileAccess.get_file_as_string(_path("profile.bak"))).is_equal("also broken")


# --- AC-7 ----------------------------------------------------------------------

func test_load_newer_schema_is_read_only_on_a_fresh_memory_profile() -> void:
	# Arrange
	ProfileFixtures.write_profile(_root, ProfileFixtures.profile_dict({"schema_version": 99, "write_seq": 3}))
	var store: ProfileStore = _store()

	# Act
	var loaded: Dictionary = store.load_profile()

	# Assert
	assert_str(String(loaded.status)).is_equal(String(SaveErrors.STATUS_SCHEMA_NEWER))
	assert_bool(store.is_read_only()).is_true()
	assert_int(loaded.profile.write_seq).is_equal(0)
	assert_int(loaded.profile.schema_version).is_equal(ProfileStore.PROFILE_SCHEMA_VERSION)


func test_load_newer_schema_never_touches_the_file() -> void:
	# Arrange
	ProfileFixtures.write_profile(_root, ProfileFixtures.profile_dict({"schema_version": 99}))
	var before: PackedByteArray = ProfileFixtures.read_bytes(_path("profile.json"))
	var mtime: int = FileAccess.get_modified_time(_path("profile.json"))
	var store: ProfileStore = _store()
	store.load_profile()

	# Act
	var setting: Error = store.set_setting(&"gamma", 1.2)
	var run: Error = store.save_active_run({"run_id": "run_a"})
	store.flush_settings()
	store.release_lock()

	# Assert
	assert_int(setting).is_equal(SaveErrors.E_READONLY)
	assert_int(run).is_equal(SaveErrors.E_READONLY)
	assert_array(Array(ProfileFixtures.read_bytes(_path("profile.json")))).is_equal(Array(before))
	assert_int(FileAccess.get_modified_time(_path("profile.json"))).is_equal(mtime)
	assert_bool(_exists("profile.bak")).is_false()
	assert_array(ProfileFixtures.files_with_prefix(_root, "profile.corrupt")).is_empty()


func test_load_newer_schema_never_leaves_read_only() -> void:
	# Arrange
	ProfileFixtures.write_profile(_root, ProfileFixtures.profile_dict({"schema_version": 99}))
	var store: ProfileStore = _store()
	store.load_profile()

	# Act
	var again: Dictionary = store.load_profile()

	# Assert (States: "`E_SCHEMA_NEWER` never exits")
	assert_str(String(again.status)).is_equal(String(SaveErrors.STATUS_SCHEMA_NEWER))
	assert_bool(store.is_read_only()).is_true()


func test_load_newer_backup_behind_a_broken_profile_is_also_left_alone() -> void:
	# Arrange
	ProfileFixtures.write_text(_path("profile.json"), "{ broken")
	ProfileFixtures.write_profile(_root, ProfileFixtures.profile_dict({"schema_version": 99}), "profile.bak")
	var before: PackedByteArray = ProfileFixtures.read_bytes(_path("profile.bak"))
	var store: ProfileStore = _store()

	# Act
	var loaded: Dictionary = store.load_profile()
	store.save_profile()

	# Assert (M5.2: a downgrade must never destroy the newer profile)
	assert_str(String(loaded.status)).is_equal(String(SaveErrors.STATUS_SCHEMA_NEWER))
	assert_array(Array(ProfileFixtures.read_bytes(_path("profile.bak")))).is_equal(Array(before))


# --- AC-14 ---------------------------------------------------------------------

func test_load_active_run_already_archived_is_cleared_silently() -> void:
	# Arrange
	var entry: Dictionary = ProfileFixtures.victory("run_a")
	var stats: Dictionary = ProfileFixtures.stats({"runs_started": 1, "runs_won": 1})
	ProfileFixtures.write_profile(_root, ProfileFixtures.profile_dict({"run_log": [entry], "active_run": entry, "stats": stats}))
	var store: ProfileStore = _store()

	# Act
	var loaded: Dictionary = store.load_profile()

	# Assert: no second archive, no second fold
	assert_that(loaded.profile.active_run).is_null()
	assert_that(store.load_active_run()).is_null()
	assert_int(loaded.profile.run_log.size()).is_equal(1)
	assert_int(loaded.profile.stats.runs_started).is_equal(1)
	assert_int(loaded.profile.stats.runs_won).is_equal(1)


func test_load_active_run_not_in_the_log_stays() -> void:
	# Arrange
	ProfileFixtures.write_profile(_root, ProfileFixtures.profile_dict({"run_log": [ProfileFixtures.victory("run_a")],
		"active_run": ProfileFixtures.victory("run_b")}))

	# Act
	var loaded: Dictionary = _store().load_profile()

	# Assert
	assert_str(loaded.profile.active_run.run_id).is_equal("run_b")


# --- AC-18 ---------------------------------------------------------------------

func _tampered() -> Dictionary:
	var hero: Dictionary = ProfileSchema.empty_hero_stats()
	hero["best_floor_reached"] = 40
	var profile: Dictionary = ProfileFixtures.profile_dict({"unlocks": {"a_key": {"unlocked": true, "at": 5, "by_run_id": null, "retro": false}}})
	profile.stats["runs_won"] = -3
	profile.stats.heroes[ProfileFixtures.HERO_WAR] = hero
	profile.settings["volume_master"] = 7
	return profile


func test_load_ac18_repairs_three_values_and_reports_three() -> void:
	# Arrange
	ProfileFixtures.write_profile(_root, _tampered())
	var store: ProfileStore = _store()

	# Act
	var loaded: Dictionary = store.load_profile()

	# Assert
	assert_int(loaded.profile.stats.runs_won).is_equal(0)
	assert_int(loaded.profile.stats.heroes[ProfileFixtures.HERO_WAR].best_floor_reached).is_equal(12)
	assert_float(loaded.profile.settings.volume_master).is_equal(1.0)
	assert_int(loaded.repairs).is_equal(3)
	assert_int(store.load_repairs()).is_equal(3)
	assert_bool(loaded.profile.unlocks.a_key.unlocked).is_true()


func test_load_ac18_logs_three_profile_repaired_lines() -> void:
	# Arrange
	ProfileFixtures.write_profile(_root, _tampered())
	var log: WarningLog = WarningLog.new()
	OS.add_logger(log)

	# Act
	_store().load_profile()
	OS.remove_logger(log)

	# Assert
	assert_int(log.count_of("profile_repaired")).is_equal(3)
	assert_int(log.count_of("stats.runs_won")).is_equal(1)
	assert_int(log.count_of("settings.volume_master")).is_equal(1)


func test_load_clean_file_repairs_nothing() -> void:
	# Arrange
	ProfileFixtures.write_profile(_root, ProfileFixtures.profile_dict())

	# Act / Assert
	assert_int(_store().load_profile().repairs).is_equal(0)


# --- F5 ------------------------------------------------------------------------

func test_load_over_max_profile_bytes_warns_and_still_loads() -> void:
	# Arrange
	var text: String = ProfileFixtures.write_profile(_root, ProfileFixtures.profile_dict())
	var log: WarningLog = WarningLog.new()
	OS.add_logger(log)

	# Act
	var loaded: Dictionary = _store({"max_profile_bytes": text.length() - 1}).load_profile()
	OS.remove_logger(log)

	# Assert ("a diagnostic, never a behaviour change")
	assert_int(log.count_of("W_PROFILE_SIZE")).is_equal(1)
	assert_str(String(loaded.status)).is_equal(String(SaveErrors.STATUS_OK))


func test_load_at_max_profile_bytes_does_not_warn() -> void:
	# Arrange
	var text: String = ProfileFixtures.write_profile(_root, ProfileFixtures.profile_dict())
	var log: WarningLog = WarningLog.new()
	OS.add_logger(log)

	# Act
	_store({"max_profile_bytes": text.to_utf8_buffer().size()}).load_profile()
	OS.remove_logger(log)

	# Assert
	assert_int(log.count_of("W_PROFILE_SIZE")).is_equal(0)


# --- M1.1 ----------------------------------------------------------------------

func test_stale_stage_file_is_never_read() -> void:
	# Arrange: a crash left a newer-looking stage beside a good profile
	ProfileFixtures.write_profile(_root, ProfileFixtures.profile_dict({"write_seq": 2}))
	ProfileFixtures.write_profile(_root, ProfileFixtures.profile_dict({"write_seq": 9}), "profile.json.tmp")

	# Act
	var loaded: Dictionary = _store().load_profile()

	# Assert
	assert_int(loaded.profile.write_seq).is_equal(2)
