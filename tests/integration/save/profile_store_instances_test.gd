## Integration: two sessions on one profile (design/gdd/meta-progression.md M6, F7,
## States "Profile: ReadOnly", Edge Cases; AC-9). Each store is a process: its own
## instance id, the one lock path, one clock the test moves.
extends GdUnitTestSuite

const LIVE_AGE_S: int = 10
const STALE_AGE_S: int = 100
const STALE_S: int = 90

var _root: String
var _clock: ProfileFixtures.ManualClock


func before_test() -> void:
	_root = ProfileFixtures.new_root()
	_clock = ProfileFixtures.ManualClock.new()


func after_test() -> void:
	ProfileFixtures.remove_root(_root)


func _path(file: String) -> String:
	return _root.path_join(file)


func _store(migrations: ProfileMigrations = null) -> ProfileStore:
	return ProfileFixtures.store(_root, _clock, {}, null, migrations)


func _lock_on_disk() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(_path("profile.lock")))


func _bytes(file: String) -> Array:
	return Array(ProfileFixtures.read_bytes(_path(file)))


## A first session that owns the profile and has written it.
func _owner() -> ProfileStore:
	var owner: ProfileStore = _store()
	owner.load_profile()
	owner.save_active_run({"run_id": "run_owner"})
	owner.save_profile()
	return owner


# --- AC-9 ----------------------------------------------------------------------

func test_load_with_a_live_lock_is_e_locked_and_read_only() -> void:
	# Arrange: heartbeat 10 s old
	ProfileFixtures.write_foreign_lock(_root, _clock, LIVE_AGE_S)
	var second: ProfileStore = _store()

	# Act
	var loaded: Dictionary = second.load_profile()

	# Assert
	assert_str(String(loaded.status)).is_equal(String(SaveErrors.STATUS_LOCKED))
	assert_bool(second.is_read_only()).is_true()
	assert_str(_lock_on_disk().instance_id).is_equal("other_instance")


func test_load_with_a_stale_lock_is_ok_and_carries_the_new_instance() -> void:
	# Arrange: heartbeat 100 s old, over a real profile
	ProfileFixtures.write_profile(_root, ProfileFixtures.profile_dict())
	ProfileFixtures.write_foreign_lock(_root, _clock, STALE_AGE_S)
	var store: ProfileStore = _store()

	# Act
	var loaded: Dictionary = store.load_profile()

	# Assert
	assert_str(String(loaded.status)).is_equal(String(SaveErrors.STATUS_OK))
	assert_bool(store.is_read_only()).is_false()
	assert_str(_lock_on_disk().instance_id).is_equal(store._instance_id)


func test_load_f7_examples_forty_seconds_is_live() -> void:
	# Arrange (F7's example)
	ProfileFixtures.write_foreign_lock(_root, _clock, 40)

	# Act / Assert
	assert_str(String(_store().load_profile().status)).is_equal(String(SaveErrors.STATUS_LOCKED))


func test_load_with_a_lock_at_exactly_the_stale_age_takes_it_over() -> void:
	# Arrange
	ProfileFixtures.write_foreign_lock(_root, _clock, STALE_S)

	# Act / Assert
	assert_bool(_store().load_profile().status == SaveErrors.STATUS_LOCKED).is_false()


# --- Second instance: read-only ------------------------------------------------

func test_second_instance_reads_the_owners_file() -> void:
	# Arrange
	var owner: ProfileStore = _owner()
	var second: ProfileStore = _store()

	# Act
	var loaded: Dictionary = second.load_profile()

	# Assert: "it can play", from the owner's data
	assert_str(String(loaded.status)).is_equal(String(SaveErrors.STATUS_LOCKED))
	assert_str(loaded.profile.profile_id).is_equal(owner.live_profile().profile_id)
	assert_str(second.load_active_run().run_id).is_equal("run_owner")


func test_second_instance_every_mutator_is_refused_and_no_file_moves() -> void:
	# Arrange
	var owner: ProfileStore = _owner()
	var files_before: Array = Array(DirAccess.get_files_at(_root))
	var profile_before: Array = _bytes("profile.json")
	var backup_before: Array = _bytes("profile.bak")
	var lock_before: Array = _bytes("profile.lock")
	var second: ProfileStore = _store()
	second.load_profile()

	# Act
	var saved: Error = second.save_profile()
	var run: Error = second.save_active_run({"run_id": "run_second"})
	var setting: Error = second.set_setting(&"gamma", 1.2)
	var archived: Dictionary = second.archive_run(ProfileFixtures.victory("run_second"))
	var reset: Error = second.reset_profile(ProfileFixtures.RESET_TOKEN)
	var cleared: Error = second.clear_run_records()
	second.clear_active_run()
	second.ack_notification("a_key")
	second.flush_settings()
	second.heartbeat()

	# Assert
	assert_int(saved).is_equal(SaveErrors.E_READONLY)
	assert_int(run).is_equal(SaveErrors.E_READONLY)
	assert_int(setting).is_equal(SaveErrors.E_READONLY)
	assert_bool(archived.ok).is_false()
	assert_int(reset).is_equal(SaveErrors.E_READONLY)
	assert_int(cleared).is_equal(SaveErrors.E_READONLY)
	assert_array(_bytes("profile.json")).is_equal(profile_before)
	assert_array(_bytes("profile.bak")).is_equal(backup_before)
	assert_array(_bytes("profile.lock")).is_equal(lock_before)
	assert_array(Array(DirAccess.get_files_at(_root))).contains_exactly_in_any_order(files_before)
	assert_bool(DirAccess.dir_exists_absolute(_path(ProfileStore.RUNS_DIR))).is_false()
	assert_bool(owner.is_read_only()).is_false()


func test_second_instance_keeps_changes_for_the_session() -> void:
	# Arrange
	_owner()
	var second: ProfileStore = _store()
	second.load_profile()

	# Act
	second.save_active_run({"run_id": "run_second"})
	second.set_setting(&"gamma", 1.2)

	# Assert (States: "In-memory profile behaves normally")
	assert_str(second.load_active_run().run_id).is_equal("run_second")
	assert_float(second.get_setting(&"gamma")).is_equal(1.2)


func test_second_instance_leaves_a_broken_file_uncopied() -> void:
	# Arrange: M6 before M5, so a refused instance touches nothing
	ProfileFixtures.write_text(_path("profile.json"), "{ broken")
	ProfileFixtures.write_foreign_lock(_root, _clock, LIVE_AGE_S)

	# Act
	_store().load_profile()

	# Assert
	assert_array(ProfileFixtures.files_with_prefix(_root, "profile.corrupt")).is_empty()


func test_second_instance_migrates_in_memory_only() -> void:
	# Arrange
	ProfileFixtures.write_profile(_root, ProfileFixtures.profile_dict())
	var before: Array = _bytes("profile.json")
	ProfileFixtures.write_foreign_lock(_root, _clock, LIVE_AGE_S)
	var chain: ProfileMigrations = ProfileMigrations.new({1: ProfileFixtures.worked_v1_to_v2}, 2)
	var second: ProfileStore = _store(chain)

	# Act
	var loaded: Dictionary = second.load_profile()

	# Assert (States "Profile: Loading")
	assert_int(loaded.profile.schema_version).is_equal(2)
	assert_array(_bytes("profile.json")).is_equal(before)
	assert_bool(FileAccess.file_exists(_path("profile.bak"))).is_false()


func test_second_instance_exit_leaves_the_owners_lock() -> void:
	# Arrange
	var owner: ProfileStore = _owner()
	var second: ProfileStore = _store()
	second.load_profile()

	# Act
	second.release_lock()

	# Assert
	assert_str(_lock_on_disk().instance_id).is_equal(owner._instance_id)


func test_retry_while_the_lock_is_live_stays_read_only() -> void:
	# Arrange
	_owner()
	var second: ProfileStore = _store()
	second.load_profile()

	# Act
	var again: Dictionary = second.load_profile()

	# Assert
	assert_str(String(again.status)).is_equal(String(SaveErrors.STATUS_LOCKED))
	assert_bool(second.is_read_only()).is_true()


func test_retry_after_the_lock_went_stale_loads_ready() -> void:
	# Arrange: the owner crashed, the banner's Retry is pressed after the window (M6.2)
	_owner()
	var second: ProfileStore = _store()
	second.load_profile()
	_clock.advance(STALE_S)

	# Act
	var again: Dictionary = second.load_profile()

	# Assert
	assert_str(String(again.status)).is_equal(String(SaveErrors.STATUS_OK))
	assert_bool(second.is_read_only()).is_false()
	assert_int(second.save_profile()).is_equal(OK)


func test_clean_exit_lets_the_next_launch_load_ready_at_once() -> void:
	# Arrange
	var owner: ProfileStore = _owner()

	# Act
	owner.release_lock()
	var loaded: Dictionary = _store().load_profile()

	# Assert
	assert_bool(FileAccess.file_exists(_path("profile.lock"))).is_true()
	assert_str(String(loaded.status)).is_equal(String(SaveErrors.STATUS_OK))


# --- Heartbeat -----------------------------------------------------------------

func test_heartbeat_keeps_the_session_writable() -> void:
	# Arrange
	var owner: ProfileStore = _owner()
	_clock.advance(30)

	# Act
	owner.heartbeat()

	# Assert
	assert_bool(owner.is_read_only()).is_false()
	assert_int(int(_lock_on_disk().heartbeat_at)).is_equal(_clock.now)


func test_heartbeat_takeover_turns_the_sleeping_session_read_only() -> void:
	# Arrange: this instance slept past lock_stale_s and another took over
	var sleeper: ProfileStore = _owner()
	_clock.advance(STALE_S)
	var taker: ProfileStore = _store()
	taker.load_profile()

	# Act
	sleeper.heartbeat()

	# Assert
	assert_bool(sleeper.is_read_only()).is_true()
	assert_str(String(sleeper.load_status())).is_equal(String(SaveErrors.STATUS_LOCKED))
	assert_str(_lock_on_disk().instance_id).is_equal(taker._instance_id)


func test_heartbeat_takeover_stops_every_later_write() -> void:
	# Arrange
	var sleeper: ProfileStore = _owner()
	_clock.advance(STALE_S)
	var taker: ProfileStore = _store()
	taker.load_profile()
	taker.save_active_run({"run_id": "run_taker"})
	sleeper.heartbeat()
	var before: Array = _bytes("profile.json")

	# Act
	var outcome: Error = sleeper.save_active_run({"run_id": "run_sleeper"})
	sleeper.set_setting(&"gamma", 1.2)
	sleeper.release_lock()

	# Assert: no last-writer-wins, and the new holder keeps its lock
	assert_int(outcome).is_equal(SaveErrors.E_READONLY)
	assert_array(_bytes("profile.json")).is_equal(before)
	assert_str(_lock_on_disk().instance_id).is_equal(taker._instance_id)
	assert_bool(taker.is_read_only()).is_false()


func test_session_read_only_by_takeover_writes_nothing_on_exit_flush() -> void:
	# Arrange: a setting pending when the lock was lost
	var sleeper: ProfileStore = _owner()
	sleeper.set_setting(&"gamma", 1.2)
	_clock.advance(STALE_S)
	var taker: ProfileStore = _store()
	taker.load_profile()
	sleeper.heartbeat()
	var before: Array = _bytes("profile.json")

	# Act
	sleeper.release_lock()

	# Assert
	assert_array(_bytes("profile.json")).is_equal(before)
