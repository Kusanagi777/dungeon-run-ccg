## Integration: `ProfileLock`, the two-instances guard (design/gdd/meta-progression.md
## M6, F7; ADR-0004 Decision 6). Two locks on one scratch path, one injected clock.
## What a session does with it is `profile_store_instances_test.gd`.
extends GdUnitTestSuite

const STALE_S: int = 90
const INSTANCE_A: String = "instance_a"
const INSTANCE_B: String = "instance_b"

var _root: String
var _path: String
var _clock: ProfileFixtures.ManualClock


func before_test() -> void:
	_root = ProfileFixtures.new_root()
	_path = _root.path_join("profile.lock")
	_clock = ProfileFixtures.ManualClock.new()


func after_test() -> void:
	ProfileFixtures.remove_root(_root)


func _lock() -> ProfileLock:
	return ProfileLock.new(_path, STALE_S, _clock.read)


func _on_disk() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(_path))


func test_acquire_writes_instance_pid_and_heartbeat() -> void:
	# Act
	var outcome: Error = _lock().acquire(INSTANCE_A)

	# Assert
	assert_int(outcome).is_equal(OK)
	var held: Dictionary = _on_disk()
	assert_str(held.instance_id).is_equal(INSTANCE_A)
	assert_int(int(held.pid)).is_equal(OS.get_process_id())
	assert_int(int(held.heartbeat_at)).is_equal(_clock.now)


func test_acquire_refuses_a_live_lock_of_another_instance() -> void:
	# Arrange
	_lock().acquire(INSTANCE_A)
	_clock.advance(STALE_S - 1)

	# Act
	var outcome: Error = _lock().acquire(INSTANCE_B)

	# Assert (F7: one second inside the window)
	assert_int(outcome).is_equal(ERR_LOCKED)
	assert_str(_on_disk().instance_id).is_equal(INSTANCE_A)


func test_acquire_takes_over_at_exactly_lock_stale_s() -> void:
	# Arrange
	_lock().acquire(INSTANCE_A)
	_clock.advance(STALE_S)

	# Act
	var outcome: Error = _lock().acquire(INSTANCE_B)

	# Assert (F7: `<`, so the boundary is stale)
	assert_int(outcome).is_equal(OK)
	assert_str(_on_disk().instance_id).is_equal(INSTANCE_B)


func test_acquire_takes_over_an_unreadable_lock() -> void:
	# Arrange
	ProfileFixtures.write_text(_path, "{ not json")

	# Act
	var outcome: Error = _lock().acquire(INSTANCE_B)

	# Assert
	assert_int(outcome).is_equal(OK)
	assert_str(_on_disk().instance_id).is_equal(INSTANCE_B)


func test_acquire_takes_over_a_lock_with_no_heartbeat() -> void:
	# Arrange
	ProfileFixtures.write_text(_path, "{\"instance_id\": \"%s\"}" % INSTANCE_A)

	# Act / Assert
	assert_int(_lock().acquire(INSTANCE_B)).is_equal(OK)


func test_acquire_by_the_holder_is_ok() -> void:
	# Arrange
	var lock: ProfileLock = _lock()
	lock.acquire(INSTANCE_A)

	# Act / Assert
	assert_int(lock.acquire(INSTANCE_A)).is_equal(OK)


func test_heartbeat_refreshes_the_timestamp() -> void:
	# Arrange
	var lock: ProfileLock = _lock()
	lock.acquire(INSTANCE_A)
	_clock.advance(30)

	# Act
	var kept: bool = lock.heartbeat()

	# Assert
	assert_bool(kept).is_true()
	assert_int(int(_on_disk().heartbeat_at)).is_equal(_clock.now)


func test_heartbeat_keeps_a_live_lock_live_past_the_stale_window() -> void:
	# Arrange
	var lock: ProfileLock = _lock()
	lock.acquire(INSTANCE_A)

	# Act: three beats span more than lock_stale_s
	for _beat: int in 3:
		_clock.advance(STALE_S - 1)
		lock.heartbeat()

	# Assert
	assert_int(_lock().acquire(INSTANCE_B)).is_equal(ERR_LOCKED)


func test_heartbeat_reports_a_lock_taken_over_and_does_not_write() -> void:
	# Arrange
	var sleeper: ProfileLock = _lock()
	sleeper.acquire(INSTANCE_A)
	_clock.advance(STALE_S)
	_lock().acquire(INSTANCE_B)

	# Act
	var kept: bool = sleeper.heartbeat()

	# Assert
	assert_bool(kept).is_false()
	assert_str(_on_disk().instance_id).is_equal(INSTANCE_B)


func test_heartbeat_of_a_lock_never_held_writes_nothing() -> void:
	# Act
	var kept: bool = _lock().heartbeat()

	# Assert
	assert_bool(kept).is_true()
	assert_bool(FileAccess.file_exists(_path)).is_false()


func test_release_deletes_the_file_of_the_holder() -> void:
	# Arrange
	var lock: ProfileLock = _lock()
	lock.acquire(INSTANCE_A)

	# Act
	lock.release()

	# Assert
	assert_bool(FileAccess.file_exists(_path)).is_false()


func test_release_by_a_refused_instance_leaves_the_lock() -> void:
	# Arrange
	_lock().acquire(INSTANCE_A)
	var refused: ProfileLock = _lock()
	refused.acquire(INSTANCE_B)

	# Act
	refused.release()

	# Assert
	assert_str(_on_disk().instance_id).is_equal(INSTANCE_A)


func test_release_after_losing_the_lock_leaves_the_new_holder_alone() -> void:
	# Arrange
	var sleeper: ProfileLock = _lock()
	sleeper.acquire(INSTANCE_A)
	_clock.advance(STALE_S)
	_lock().acquire(INSTANCE_B)
	sleeper.heartbeat()

	# Act
	sleeper.release()

	# Assert
	assert_str(_on_disk().instance_id).is_equal(INSTANCE_B)
