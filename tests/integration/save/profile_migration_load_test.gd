## Integration: the migration chain through a real load, steps injected
## (design/gdd/meta-progression.md M4.4, AC-8; ADR-0004 Decision 7). AC-8's
## `PROFILE_SCHEMA_VERSION == 2` build is a chain targeting 2: the constant itself
## stays 1 until a real migration ships.
extends GdUnitTestSuite

const TARGET_V2: int = 2
const TARGET_V3: int = 3
const TURNS_SLOW: int = 70
const TURNS_FAST: int = 55
const TURNS_CUSTOM: int = 30

var _root: String
var _clock: ProfileFixtures.ManualClock
var _step_calls: Array


func before_test() -> void:
	_root = ProfileFixtures.new_root()
	_clock = ProfileFixtures.ManualClock.new()
	_step_calls = []


func after_test() -> void:
	ProfileFixtures.remove_root(_root)


func _path(file: String) -> String:
	return _root.path_join(file)


func _counted_step(profile: Dictionary) -> Dictionary:
	_step_calls.append(int(profile.schema_version))
	return ProfileFixtures.worked_v1_to_v2(profile)


func _v2_to_v3(profile: Dictionary) -> Dictionary:
	_step_calls.append(int(profile.schema_version))
	var out: Dictionary = profile.duplicate(true)
	out["schema_version"] = TARGET_V3
	out["added_in_v3"] = true
	return out


func _v2_store() -> ProfileStore:
	return ProfileFixtures.store(_root, _clock, {}, null, ProfileMigrations.new({1: _counted_step}, TARGET_V2))


## AC-8's fixture: two random-seed and one custom victory for War.
func _write_v1_fixture() -> Array:
	var hero: Dictionary = ProfileSchema.empty_hero_stats()
	hero["runs_won"] = 3
	hero["runs_started"] = 3
	var stats: Dictionary = ProfileFixtures.stats({"runs_started": 3, "runs_won": 3, "heroes": {ProfileFixtures.HERO_WAR: hero}})
	ProfileFixtures.write_profile(_root, ProfileFixtures.profile_dict({"stats": stats, "run_log": [
		ProfileFixtures.victory("run_a", ProfileFixtures.HERO_WAR, TURNS_SLOW),
		ProfileFixtures.victory("run_b", ProfileFixtures.HERO_WAR, TURNS_FAST),
		ProfileFixtures.victory("run_c", ProfileFixtures.HERO_WAR, TURNS_CUSTOM, 600, "custom"),
	]}))
	return Array(ProfileFixtures.read_bytes(_path("profile.json")))


func test_load_ac8_migrates_to_v2_with_the_smaller_random_seed_turns() -> void:
	# Arrange
	_write_v1_fixture()

	# Act
	var loaded: Dictionary = _v2_store().load_profile()

	# Assert
	assert_str(String(loaded.status)).is_equal(String(SaveErrors.STATUS_OK))
	assert_int(loaded.profile.schema_version).is_equal(TARGET_V2)
	assert_int(loaded.profile.stats.heroes[ProfileFixtures.HERO_WAR].best_turns_victory).is_equal(TURNS_FAST)


func test_load_ac8_writes_once_and_the_pre_migration_file_becomes_the_backup() -> void:
	# Arrange
	var v1_bytes: Array = _write_v1_fixture()

	# Act
	var store: ProfileStore = _v2_store()
	store.load_profile()

	# Assert
	assert_array(Array(ProfileFixtures.read_bytes(_path("profile.bak")))).is_equal(v1_bytes)
	var on_disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_path("profile.json")))
	assert_int(int(on_disk.schema_version)).is_equal(TARGET_V2)
	assert_int(int(on_disk.write_seq)).is_equal(1)


func test_load_ac8_loading_the_result_again_applies_no_migration() -> void:
	# Arrange
	_write_v1_fixture()
	var first: ProfileStore = _v2_store()
	first.load_profile()
	first.release_lock()
	var seq: int = first.live_profile().write_seq
	_step_calls.clear()

	# Act
	var loaded: Dictionary = _v2_store().load_profile()

	# Assert
	assert_array(_step_calls).is_empty()
	assert_int(loaded.profile.write_seq).is_equal(seq)
	assert_int(loaded.profile.schema_version).is_equal(TARGET_V2)


func test_load_chain_applies_every_step_in_sequence_and_writes_once() -> void:
	# Arrange
	_write_v1_fixture()
	var chain: ProfileMigrations = ProfileMigrations.new({1: _counted_step, 2: _v2_to_v3}, TARGET_V3)
	var store: ProfileStore = ProfileFixtures.store(_root, _clock, {}, null, chain)

	# Act
	var loaded: Dictionary = store.load_profile()

	# Assert
	assert_array(_step_calls).is_equal([1, TARGET_V2])
	assert_int(loaded.profile.schema_version).is_equal(TARGET_V3)
	assert_bool(loaded.profile.added_in_v3).is_true()
	assert_int(loaded.profile.write_seq).is_equal(1)


func test_load_with_no_path_to_the_target_keeps_the_file_and_starts_fresh() -> void:
	# Arrange: a build that lost its step, so the file is not migratable
	var v1_bytes: Array = _write_v1_fixture()
	var chain: ProfileMigrations = ProfileMigrations.new({}, TARGET_V2)

	# Act
	var loaded: Dictionary = ProfileFixtures.store(_root, _clock, {}, null, chain).load_profile()

	# Assert
	assert_str(String(loaded.status)).is_equal(String(SaveErrors.STATUS_FRESH_AFTER_CORRUPT))
	assert_array(Array(ProfileFixtures.read_bytes(_path("profile.json")))).is_equal(v1_bytes)
	assert_int(ProfileFixtures.files_with_prefix(_root, "profile.corrupt").size()).is_equal(1)


func test_load_a_fresh_profile_starts_at_the_chain_target() -> void:
	# Act
	var loaded: Dictionary = _v2_store().load_profile()

	# Assert
	assert_int(loaded.profile.schema_version).is_equal(TARGET_V2)


func test_load_a_backup_older_than_the_build_migrates_too() -> void:
	# Arrange: a truncated final and a v1 backup
	ProfileFixtures.write_profile(_root, ProfileFixtures.profile_dict(), "profile.bak")
	ProfileFixtures.write_text(_path("profile.json"), "{ truncated")
	var backup: Array = Array(ProfileFixtures.read_bytes(_path("profile.bak")))

	# Act
	var loaded: Dictionary = _v2_store().load_profile()

	# Assert: the corrupt final must not rotate over the good v1 backup
	assert_str(String(loaded.status)).is_equal(String(SaveErrors.STATUS_RECOVERED_BAK))
	assert_int(loaded.profile.schema_version).is_equal(TARGET_V2)
	assert_array(Array(ProfileFixtures.read_bytes(_path("profile.bak")))).is_equal(backup)


func test_load_at_the_target_writes_nothing() -> void:
	# Arrange
	ProfileFixtures.write_profile(_root, ProfileFixtures.profile_dict({"schema_version": TARGET_V2}))
	var before: Array = Array(ProfileFixtures.read_bytes(_path("profile.json")))

	# Act
	_v2_store().load_profile()

	# Assert
	assert_array(Array(ProfileFixtures.read_bytes(_path("profile.json")))).is_equal(before)
	assert_bool(FileAccess.file_exists(_path("profile.bak"))).is_false()
