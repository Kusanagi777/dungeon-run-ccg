## Integration: the write side of `ProfileStore` on real files in a scratch directory
## (design/gdd/meta-progression.md M1, M4, Write states; AC-2, AC-3, AC-4; `backup_count`;
## Edge Cases "disk is full", "deleted while the game runs"; `RECOVERED_BAK` rotation).
extends GdUnitTestSuite

const RETRY_MS: int = 30
const STAGED_STEPS: Array[String] = ["W2", "W3", "W4", "W5", "W6"]
const ALL_STEPS: Array[String] = ["W2", "W3", "W4", "W5", "W6", "W7", "W8"]

var _root: String
var _clock: ProfileFixtures.ManualClock
var _writer: ProfileFixtures.FaultWriter


func before_test() -> void:
	_root = ProfileFixtures.new_root()
	_clock = ProfileFixtures.ManualClock.new()
	_writer = ProfileFixtures.FaultWriter.new()


func after_test() -> void:
	ProfileFixtures.remove_root(_root)


func _path(file: String) -> String:
	return _root.path_join(file)


func _store(knob_overrides: Dictionary = {}) -> ProfileStore:
	return ProfileFixtures.store(_root, _clock, knob_overrides, _writer)


func _loaded_store(knob_overrides: Dictionary = {}) -> ProfileStore:
	var store: ProfileStore = _store(knob_overrides)
	store.load_profile()
	return store


## A clean exit and a new process over the same files.
func _restart(store: ProfileStore) -> ProfileStore:
	store.release_lock()
	return ProfileFixtures.store(_root, _clock)


func _bytes(file: String) -> Array:
	return Array(ProfileFixtures.read_bytes(_path(file)))


func _seq_on_disk(file: String = "profile.json") -> int:
	return int(JSON.parse_string(FileAccess.get_file_as_string(_path(file))).write_seq)


func _file_exists(file: String) -> bool:
	return FileAccess.file_exists(_path(file))


# --- M1.1 ----------------------------------------------------------------------

func test_save_writes_pretty_json_with_schema_version_as_first_key() -> void:
	# Act
	_loaded_store().save_profile()

	# Assert
	var text: String = FileAccess.get_file_as_string(_path("profile.json"))
	assert_bool(text.begins_with("{\n\t\"schema_version\"")).is_true()


## What one `stringify` of the whole profile gives, as M1.1 specifies the file.
func _plain_text(store: ProfileStore) -> String:
	var profile: Dictionary = store.live_profile()
	var ordered: Dictionary = {"schema_version": profile.schema_version}
	ordered.merge(profile)
	return JSON.stringify(ordered, "\t", false, true)


func _file_text() -> String:
	return FileAccess.get_file_as_string(_path("profile.json"))


func test_file_with_a_run_log_is_byte_for_byte_a_plain_stringify() -> void:
	# Arrange
	var store: ProfileStore = _loaded_store()
	store.archive_run(ProfileFixtures.full_record("run_a"))
	store.archive_run(ProfileFixtures.victory("run_b"))

	# Act
	store.save_active_run({"run_id": "run_c", "ratio": 0.1})

	# Assert
	assert_str(_file_text()).is_equal(_plain_text(store))


func test_file_stays_exact_through_load_prune_and_reset() -> void:
	# Arrange: every event that changes the log under the held entry texts
	var store: ProfileStore = _loaded_store({"run_log_cap": 2})
	for run_id: String in ["run_a", "run_b", "run_c"]:
		store.archive_run(ProfileFixtures.victory(run_id))

	# Act / Assert: pruned
	assert_str(_file_text()).is_equal(_plain_text(store))
	assert_str(_file_text()).not_contains("run_a")

	# Act / Assert: a new session prints what it loaded
	store.release_lock()
	store = _loaded_store({"run_log_cap": 2})
	store.archive_run(ProfileFixtures.victory("run_d"))
	assert_str(_file_text()).is_equal(_plain_text(store))
	assert_str(_file_text()).not_contains("run_b")

	# Act / Assert: a reset holds nothing over
	store.reset_profile(ProfileFixtures.RESET_TOKEN)
	assert_str(_file_text()).not_contains("run_d")
	store.archive_run(ProfileFixtures.victory("run_e"))
	assert_str(_file_text()).is_equal(_plain_text(store))
	assert_int(store.run_log_count()).is_equal(1)


func test_log_slot_text_inside_an_opaque_blob_does_not_move_the_log() -> void:
	# Arrange: run_log precedes active_run, so the first match is the real slot
	var store: ProfileStore = _loaded_store()
	store.archive_run(ProfileFixtures.victory("run_a"))

	# Act
	store.save_active_run({"run_id": "run_b", "note": ProfileStore.LOG_SLOT})

	# Assert
	assert_str(_file_text()).is_equal(_plain_text(store))


# --- AC-2 ----------------------------------------------------------------------

func test_save_then_load_is_equal_key_for_key() -> void:
	# Arrange: unknown keys in settings, a 36-card active run, a 64-bit hex seed
	var store: ProfileStore = _loaded_store()
	var settings: Dictionary = store.live_profile().settings
	settings["future_flag"] = true
	settings["future_ratio"] = 0.1
	settings["future_map"] = {"a": [1, 2], "b": null}
	settings["volume_music"] = 0.35
	var blob: Dictionary = ProfileFixtures.full_record("run_a")
	blob["run_seed_hex"] = "ffffffffffffff01"
	blob["ratio"] = 2.5
	store.save_active_run(blob)
	var saved: Dictionary = store.live_profile().duplicate(true)

	# Act
	var loaded: Dictionary = _restart(store).load_profile()

	# Assert
	assert_str(String(loaded.status)).is_equal(String(SaveErrors.STATUS_OK))
	assert_int(loaded.repairs).is_equal(0)
	assert_array(loaded.profile.keys()).contains_exactly_in_any_order(saved.keys())
	for key: String in saved:
		assert_that(loaded.profile[key]).override_failure_message(key).is_equal(saved[key])
	assert_int(loaded.profile.active_run.deck.size()).is_equal(ProfileFixtures.DECK_SIZE)


# --- AC-3 ----------------------------------------------------------------------

func test_save_moves_the_previous_file_to_the_backup_byte_for_byte() -> void:
	# Arrange
	var store: ProfileStore = _loaded_store()
	store.save_profile()
	var previous: Array = _bytes("profile.json")

	# Act
	var outcome: Error = store.save_profile()

	# Assert
	assert_int(outcome).is_equal(OK)
	assert_array(_bytes("profile.bak")).is_equal(previous)
	assert_bool(_file_exists("profile.json.tmp")).is_false()


func test_save_increases_write_seq_by_one() -> void:
	# Arrange
	var store: ProfileStore = _loaded_store()
	store.save_profile()
	var before: int = _seq_on_disk()

	# Act
	store.save_profile()

	# Assert
	assert_int(_seq_on_disk()).is_equal(before + 1)
	assert_int(store.live_profile().write_seq).is_equal(before + 1)


func test_save_stamps_updated_at_from_the_clock() -> void:
	# Arrange
	var store: ProfileStore = _loaded_store()
	_clock.advance(100)

	# Act
	store.save_profile()

	# Assert
	assert_int(store.live_profile().updated_at).is_equal(_clock.now)


func test_save_before_a_load_is_an_error_and_writes_nothing() -> void:
	# Arrange
	var store: ProfileStore = _store()

	# Act
	var outcome: Error = store.save_profile()

	# Assert
	assert_int(outcome).is_equal(SaveErrors.E_IO)
	assert_bool(_file_exists("profile.json")).is_false()


# --- AC-4 ----------------------------------------------------------------------

func test_failed_stage_retries_once_after_io_retry_ms_then_returns_e_io() -> void:
	# Arrange
	var store: ProfileStore = _loaded_store({"io_retry_ms": RETRY_MS})
	store.save_profile()
	store.save_profile()
	var profile_before: Array = _bytes("profile.json")
	var backup_before: Array = _bytes("profile.bak")
	_writer.write_calls = 0
	_writer.fail_at("W4")
	var started: int = Time.get_ticks_msec()

	# Act
	var outcome: Error = store.save_profile()

	# Assert
	assert_int(outcome).is_equal(SaveErrors.E_IO)
	assert_int(_writer.write_calls).is_equal(2)
	assert_int(Time.get_ticks_msec() - started).is_greater_equal(RETRY_MS)
	assert_array(_bytes("profile.json")).is_equal(profile_before)
	assert_array(_bytes("profile.bak")).is_equal(backup_before)
	assert_bool(_file_exists("profile.json.tmp")).is_false()


func test_every_staged_step_failure_leaves_both_files_identical() -> void:
	# Arrange
	var store: ProfileStore = _loaded_store()
	store.save_profile()
	store.save_profile()
	var profile_before: Array = _bytes("profile.json")
	var backup_before: Array = _bytes("profile.bak")

	for step: String in STAGED_STEPS:
		# Act
		_writer.clear()
		_writer.fail_at(step)
		var outcome: Error = store.save_profile()

		# Assert
		assert_int(outcome).override_failure_message(step).is_equal(SaveErrors.E_IO)
		assert_array(_bytes("profile.json")).override_failure_message(step).is_equal(profile_before)
		assert_array(_bytes("profile.bak")).override_failure_message(step).is_equal(backup_before)
		assert_bool(_file_exists("profile.json.tmp")).override_failure_message(step).is_false()


func test_one_failure_then_success_saves_on_the_retry() -> void:
	# Arrange
	var store: ProfileStore = _loaded_store()
	store.save_profile()
	var before: int = _seq_on_disk()
	_writer.fail_at("W3", 1)

	# Act
	var outcome: Error = store.save_profile()

	# Assert
	assert_int(outcome).is_equal(OK)
	assert_int(_seq_on_disk()).is_equal(before + 1)


func test_io_retry_ms_zero_means_no_retry() -> void:
	# Arrange (Tuning Knobs: "0 = no retry")
	var store: ProfileStore = _loaded_store({"io_retry_ms": 0})
	_writer.write_calls = 0
	_writer.fail_at("W4")

	# Act
	var outcome: Error = store.save_profile()

	# Assert
	assert_int(outcome).is_equal(SaveErrors.E_IO)
	assert_int(_writer.write_calls).is_equal(1)


func test_failed_write_leaves_write_seq_alone_in_memory() -> void:
	# Arrange
	var store: ProfileStore = _loaded_store()
	store.save_profile()
	var before: int = store.live_profile().write_seq
	_writer.fail_at("W4")

	# Act
	store.save_profile()

	# Assert (States: "`write_seq` +1 in memory only after success")
	assert_int(store.live_profile().write_seq).is_equal(before)


func test_failure_at_any_step_leaves_a_loadable_previous_profile() -> void:
	# Arrange: ADR-0004 Verification, "never neither"
	for step: String in ALL_STEPS:
		var root: String = ProfileFixtures.new_root()
		var writer: ProfileFixtures.FaultWriter = ProfileFixtures.FaultWriter.new()
		var store: ProfileStore = ProfileFixtures.store(root, _clock, {}, writer)
		store.load_profile()
		store.save_active_run({"run_id": "run_kept"})
		store.save_profile()
		writer.fail_at(step)

		# Act
		var outcome: Error = store.save_active_run({"run_id": "run_lost"})
		store.release_lock()
		var loaded: Dictionary = ProfileFixtures.store(root, _clock).load_profile()

		# Assert
		assert_int(outcome).override_failure_message(step).is_equal(SaveErrors.E_IO)
		assert_str(String(loaded.status)).override_failure_message(step).is_equal(String(SaveErrors.STATUS_OK))
		assert_str(loaded.profile.active_run.run_id).override_failure_message(step).is_equal("run_kept")
		ProfileFixtures.remove_root(root)


func test_disk_full_keeps_the_change_in_memory_and_the_next_mutator_writes_it() -> void:
	# Arrange
	var store: ProfileStore = _loaded_store()
	store.save_profile()
	_writer.fail_at("W4")
	store.save_active_run({"run_id": "run_a"})
	_writer.clear()

	# Act: an unrelated mutator retries the whole write
	var outcome: Error = store.save_profile()

	# Assert (Edge Cases "disk is full")
	assert_int(outcome).is_equal(OK)
	var on_disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_path("profile.json")))
	assert_str(on_disk.active_run.run_id).is_equal("run_a")


# --- RECOVERED_BAK -------------------------------------------------------------

func _recovered_store() -> ProfileStore:
	ProfileFixtures.write_profile(_root, ProfileFixtures.profile_dict({"write_seq": 4}), "profile.bak")
	ProfileFixtures.write_text(_path("profile.json"), "{\"schema_version\": 1, \"prof")
	return _loaded_store()


func test_first_save_after_recovered_bak_skips_rotation() -> void:
	# Arrange: the file at the final path is the corrupt one
	var store: ProfileStore = _recovered_store()
	var good_backup: Array = _bytes("profile.bak")

	# Act
	var outcome: Error = store.save_profile()

	# Assert: the corrupt file must not rotate over the only good copy
	assert_int(outcome).is_equal(OK)
	assert_array(_bytes("profile.bak")).is_equal(good_backup)
	assert_int(_seq_on_disk()).is_equal(5)
	assert_bool(_file_exists("profile.json.tmp")).is_false()


func test_failed_first_save_after_recovered_bak_still_skips_rotation_on_the_next() -> void:
	# Arrange
	var store: ProfileStore = _recovered_store()
	var good_backup: Array = _bytes("profile.bak")
	_writer.fail_at("W4")
	store.save_profile()
	_writer.clear()

	# Act
	store.save_profile()

	# Assert
	assert_array(_bytes("profile.bak")).is_equal(good_backup)


func test_second_save_after_recovered_bak_rotates_as_usual() -> void:
	# Arrange
	var store: ProfileStore = _recovered_store()
	store.save_profile()
	var first_good: Array = _bytes("profile.json")

	# Act
	store.save_profile()

	# Assert
	assert_array(_bytes("profile.bak")).is_equal(first_good)


func test_recovered_from_a_missing_profile_writes_it_on_the_next_mutation() -> void:
	# Arrange
	ProfileFixtures.write_profile(_root, ProfileFixtures.profile_dict({"write_seq": 4}), "profile.bak")
	var store: ProfileStore = _loaded_store()
	var backup: Array = _bytes("profile.bak")
	var written_on_load: bool = _file_exists("profile.json")

	# Act
	store.save_active_run({"run_id": "run_a"})

	# Assert
	assert_bool(written_on_load).is_false()
	assert_int(_seq_on_disk()).is_equal(5)
	assert_array(_bytes("profile.bak")).is_equal(backup)


# --- Edge Cases ----------------------------------------------------------------

func test_profile_deleted_while_running_is_recreated_by_the_next_write() -> void:
	# Arrange
	var store: ProfileStore = _loaded_store()
	store.save_active_run({"run_id": "run_a"})
	DirAccess.remove_absolute(_path("profile.json"))

	# Act
	var outcome: Error = store.save_profile()

	# Assert
	assert_int(outcome).is_equal(OK)
	assert_str(_restart(store).load_profile().profile.active_run.run_id).is_equal("run_a")


# --- backup_count --------------------------------------------------------------

func test_backup_count_two_keeps_a_second_generation() -> void:
	# Arrange
	var store: ProfileStore = _loaded_store({"backup_count": 2})
	store.save_profile()
	var oldest: Array = _bytes("profile.json")
	store.save_profile()
	var middle: Array = _bytes("profile.json")

	# Act
	store.save_profile()

	# Assert
	assert_array(_bytes("profile.bak")).is_equal(middle)
	assert_array(_bytes("profile.bak2")).is_equal(oldest)


func test_backup_count_one_keeps_only_profile_bak() -> void:
	# Arrange
	var store: ProfileStore = _loaded_store({"backup_count": 1})

	# Act
	for _write: int in 4:
		store.save_profile()

	# Assert
	assert_bool(_file_exists("profile.bak")).is_true()
	assert_bool(_file_exists("profile.bak2")).is_false()


func test_backup_count_three_shifts_each_generation_down() -> void:
	# Arrange
	var store: ProfileStore = _loaded_store({"backup_count": 3})
	var generations: Array = []
	for _write: int in 4:
		store.save_profile()
		generations.append(_bytes("profile.json"))

	# Act
	store.save_profile()

	# Assert
	assert_array(_bytes("profile.bak")).is_equal(generations[3])
	assert_array(_bytes("profile.bak2")).is_equal(generations[2])
	assert_array(_bytes("profile.bak3")).is_equal(generations[1])
