## Integration: settings, notifications and reset on real files
## (design/gdd/meta-progression.md M1.1, M3.6, M4.2, M9; AC-26's store half; ADR-0004
## Decision 8 "Save points and debounce").
extends GdUnitTestSuite

var _root: String
var _clock: ProfileFixtures.ManualClock
var _published: Array


func before_test() -> void:
	_root = ProfileFixtures.new_root()
	_clock = ProfileFixtures.ManualClock.new()
	_published = []


func after_test() -> void:
	ProfileFixtures.remove_root(_root)


func _path(file: String) -> String:
	return _root.path_join(file)


func _store() -> ProfileStore:
	var store: ProfileStore = ProfileFixtures.store(_root, _clock)
	store.load_profile()
	store.settings_bus.settings_changed.connect(func(key: StringName, value: Variant) -> void: _published.append([key, value]))
	return store


func _restart(store: ProfileStore) -> ProfileStore:
	store.release_lock()
	var next: ProfileStore = ProfileFixtures.store(_root, _clock)
	next.load_profile()
	return next


func _on_disk() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(_path("profile.json")))


# --- set_setting ---------------------------------------------------------------

func test_set_setting_stores_and_publishes_once() -> void:
	# Arrange
	var store: ProfileStore = _store()

	# Act
	var outcome: Error = store.set_setting(&"gamma", 1.2)

	# Assert
	assert_int(outcome).is_equal(OK)
	assert_float(store.get_setting(&"gamma")).is_equal(1.2)
	assert_array(_published).is_equal([[&"gamma", 1.2]])


func test_set_setting_out_of_range_stores_and_publishes_nothing() -> void:
	# Arrange
	var store: ProfileStore = _store()

	# Act
	var outcome: Error = store.set_setting(&"gamma", 2.0)

	# Assert
	assert_int(outcome).is_equal(SaveErrors.E_RANGE)
	assert_float(store.get_setting(&"gamma")).is_equal(ProfileFixtures.settings_defaults().gamma)
	assert_array(_published).is_empty()


func test_set_setting_unknown_key_is_e_range() -> void:
	# Act / Assert
	assert_int(_store().set_setting(&"no_such_key", 1)).is_equal(SaveErrors.E_RANGE)


func test_set_setting_debounces_the_write() -> void:
	# Arrange
	var store: ProfileStore = _store()
	var dirty: Array = []
	store.settings_dirty.connect(func() -> void: dirty.append(1))

	# Act
	store.set_setting(&"gamma", 1.2)
	store.set_setting(&"gamma", 1.3)

	# Assert: the owner's timer is asked, no write yet
	assert_int(dirty.size()).is_equal(2)
	assert_bool(FileAccess.file_exists(_path("profile.json"))).is_false()


func test_flush_settings_writes_the_pending_change_once() -> void:
	# Arrange
	var store: ProfileStore = _store()
	store.set_setting(&"gamma", 1.2)

	# Act
	var first: Error = store.flush_settings()
	var seq: int = int(_on_disk().write_seq)
	var second: Error = store.flush_settings()

	# Assert
	assert_int(first).is_equal(OK)
	assert_int(second).is_equal(OK)
	assert_float(_on_disk().settings.gamma).is_equal(1.2)
	assert_int(int(_on_disk().write_seq)).is_equal(seq)


func test_flush_settings_with_nothing_pending_writes_nothing() -> void:
	# Arrange
	var store: ProfileStore = _store()

	# Act
	var outcome: Error = store.flush_settings()

	# Assert
	assert_int(outcome).is_equal(OK)
	assert_bool(FileAccess.file_exists(_path("profile.json"))).is_false()


func test_save_active_run_carries_a_pending_setting_in_the_same_write() -> void:
	# Arrange (ADR-0004 Decision 8)
	var store: ProfileStore = _store()
	store.set_setting(&"gamma", 1.2)

	# Act
	store.save_active_run({"run_id": "run_a"})
	var seq: int = int(_on_disk().write_seq)
	store.flush_settings()

	# Assert
	assert_float(_on_disk().settings.gamma).is_equal(1.2)
	assert_int(int(_on_disk().write_seq)).is_equal(seq)


func test_failed_flush_stays_pending() -> void:
	# Arrange
	var writer: ProfileFixtures.FaultWriter = ProfileFixtures.FaultWriter.new()
	var store: ProfileStore = ProfileFixtures.store(_root, _clock, {}, writer)
	store.load_profile()
	store.set_setting(&"gamma", 1.2)
	writer.fail_at("W4")
	var failed: Error = store.flush_settings()
	writer.clear()

	# Act
	var retried: Error = store.flush_settings()

	# Assert
	assert_int(failed).is_equal(SaveErrors.E_IO)
	assert_int(retried).is_equal(OK)
	assert_float(_on_disk().settings.gamma).is_equal(1.2)


func test_clean_exit_flushes_a_pending_setting() -> void:
	# Arrange
	var store: ProfileStore = _store()
	store.set_setting(&"gamma", 1.2)

	# Act
	var next: ProfileStore = _restart(store)

	# Assert
	assert_float(next.get_setting(&"gamma")).is_equal(1.2)


func test_get_setting_of_a_map_and_get_settings_hand_out_copies() -> void:
	# Arrange
	var store: ProfileStore = _store()
	store.set_setting(&"bindings", {"ui_accept": []})

	# Act
	store.get_setting(&"bindings")["ui_left"] = []
	store.get_settings()["gamma"] = 1.3

	# Assert
	assert_array(store.get_setting(&"bindings").keys()).is_equal(["ui_accept"])
	assert_float(store.get_setting(&"gamma")).is_equal(ProfileFixtures.settings_defaults().gamma)


func test_get_setting_of_an_unknown_key_is_null() -> void:
	# Act / Assert
	assert_that(_store().get_setting(&"no_such_key")).is_null()


func test_publish_settings_sends_every_setting_once() -> void:
	# Arrange
	var store: ProfileStore = _store()

	# Act
	store.publish_settings()

	# Assert: a late consumer can ask the bus; `bindings` is M9's too, absent from the defaults
	assert_int(_published.size()).is_equal(ProfileFixtures.settings_defaults().size() + 1)
	assert_float(store.settings_bus.get_setting(&"gamma")).is_equal(ProfileFixtures.settings_defaults().gamma)
	assert_dict(store.settings_bus.get_setting(&"bindings")).is_empty()


# --- Notifications -------------------------------------------------------------

func _with_queue(keys: Array) -> ProfileStore:
	var queue: Array = keys.map(func(key: String) -> Dictionary:
		return {"key": key, "kind": "treasure", "id": "treasure_x", "by_run_id": "run_a"})
	ProfileFixtures.write_profile(_root, ProfileFixtures.profile_dict({"pending_notifications": queue}))
	return _store()


func test_ack_persists_so_the_queue_is_empty_after_a_restart() -> void:
	# Arrange
	var store: ProfileStore = _with_queue(["key_a"])

	# Act
	store.ack_notification("key_a")
	var next: ProfileStore = _restart(store)

	# Assert (AC-26)
	assert_array(next.pending_notifications()).is_empty()


func test_entry_not_acked_is_still_queued_after_a_crash() -> void:
	# Arrange
	_with_queue(["key_a"])

	# Act: no ack and no clean exit; the crashed lock has gone stale
	_clock.advance(ProfileFixtures.knobs().lock_stale_s)
	var next: ProfileStore = ProfileFixtures.store(_root, _clock)
	next.load_profile()

	# Assert (AC-26)
	assert_array(next.pending_notifications().map(func(entry: Dictionary) -> String: return entry.key)).is_equal(["key_a"])


func test_ack_drains_only_its_key_and_keeps_the_order() -> void:
	# Arrange
	var store: ProfileStore = _with_queue(["key_a", "key_b", "key_c"])

	# Act
	store.ack_notification("key_b")

	# Assert
	assert_array(store.pending_notifications().map(func(entry: Dictionary) -> String: return entry.key)).is_equal(["key_a", "key_c"])


func test_ack_of_an_unknown_key_writes_nothing() -> void:
	# Arrange
	var store: ProfileStore = _with_queue(["key_a"])
	var seq: int = store.live_profile().write_seq

	# Act
	store.ack_notification("key_nope")

	# Assert
	assert_int(store.live_profile().write_seq).is_equal(seq)


func test_pending_notifications_hands_out_a_copy() -> void:
	# Arrange
	var store: ProfileStore = _with_queue(["key_a"])

	# Act
	store.pending_notifications().clear()

	# Assert
	assert_int(store.pending_notifications().size()).is_equal(1)


# --- reset_profile -------------------------------------------------------------

func test_reset_with_the_wrong_token_changes_nothing() -> void:
	# Arrange
	var store: ProfileStore = _store()
	store.save_active_run({"run_id": "run_a"})
	var seq: int = int(_on_disk().write_seq)

	# Act
	var outcome: Error = store.reset_profile("reset")

	# Assert
	assert_int(outcome).is_equal(SaveErrors.E_RANGE)
	assert_int(int(_on_disk().write_seq)).is_equal(seq)
	assert_str(store.load_active_run().run_id).is_equal("run_a")


func test_reset_starts_a_fresh_profile_and_rotates_the_old_one() -> void:
	# Arrange
	var store: ProfileStore = _store()
	store.archive_run(ProfileFixtures.victory("run_a"))
	store.save_active_run({"run_id": "run_b"})
	var old_id: String = store.live_profile().profile_id
	var old_bytes: Array = Array(ProfileFixtures.read_bytes(_path("profile.json")))

	# Act
	var outcome: Error = store.reset_profile(ProfileFixtures.RESET_TOKEN)

	# Assert
	assert_int(outcome).is_equal(OK)
	assert_int(store.run_log_count()).is_equal(0)
	assert_that(store.load_active_run()).is_null()
	assert_str(store.live_profile().profile_id).is_not_equal(old_id)
	assert_array(Array(ProfileFixtures.read_bytes(_path("profile.bak")))).is_equal(old_bytes)


func test_reset_continues_write_seq() -> void:
	# Arrange
	var store: ProfileStore = _store()
	store.save_profile()
	var seq: int = int(_on_disk().write_seq)

	# Act
	store.reset_profile(ProfileFixtures.RESET_TOKEN)

	# Assert (M1.2 "+1 per successful write")
	assert_int(int(_on_disk().write_seq)).is_equal(seq + 1)


func test_reset_returns_settings_to_the_defaults() -> void:
	# Arrange
	var store: ProfileStore = _store()
	store.set_setting(&"gamma", 1.2)

	# Act
	store.reset_profile(ProfileFixtures.RESET_TOKEN)

	# Assert
	assert_dict(store.get_settings()).is_equal(ProfileFixtures.settings_defaults())
