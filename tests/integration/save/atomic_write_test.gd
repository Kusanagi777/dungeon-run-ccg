## Integration: the M4 write sequence under fault injection (ADR-0004 Decision 3 and
## Verification, "survives a failure injected at each step W2-W8"). A real scratch
## directory, a real `AtomicFileWriter`, one step made to fail through `_fails_at`.
##
## The invariant of every case: `profile.json` or `profile.bak` is complete, and no
## `.tmp` is left. Before W7 both files are byte-identical to before (M4.1, AC-4).
extends GdUnitTestSuite

const OLD_TEXT: String = "{\"generation\": \"old\"}"
const OLDER_TEXT: String = "{\"generation\": \"older\"}"
const NEW_TEXT: String = "{\"generation\": \"new\"}"

var _root: String
var _writer: ProfileFixtures.FaultWriter
var _final: String
var _bak: String
var _tmp: String


func before_test() -> void:
	_root = ProfileFixtures.new_root()
	_writer = ProfileFixtures.FaultWriter.new()
	_final = _root.path_join("profile.json")
	_bak = _root.path_join("profile.bak")
	_tmp = _final + AtomicFileWriter.TMP_SUFFIX
	ProfileFixtures.write_text(_final, OLD_TEXT)
	ProfileFixtures.write_text(_bak, OLDER_TEXT)


func after_test() -> void:
	ProfileFixtures.remove_root(_root)


func _text(path: String) -> String:
	return FileAccess.get_file_as_string(path)


## A failure before W7: nothing moved, the stage gone, the step named.
func _assert_failure_left_files_alone(step: String) -> void:
	_writer.fail_at(step)

	var outcome: Error = _writer.write(_final, NEW_TEXT, _bak)

	assert_int(outcome).is_equal(SaveErrors.E_IO)
	assert_str(_text(_final)).is_equal(OLD_TEXT)
	assert_str(_text(_bak)).is_equal(OLDER_TEXT)
	assert_bool(FileAccess.file_exists(_tmp)).is_false()
	assert_str(_writer.last_error_detail()).contains(step)


func test_failure_at_w2_leaves_previous_profile_intact() -> void:
	_assert_failure_left_files_alone("W2")


func test_failure_at_w3_leaves_previous_profile_intact() -> void:
	_assert_failure_left_files_alone("W3")


func test_failure_at_w4_leaves_previous_profile_intact() -> void:
	_assert_failure_left_files_alone("W4")


func test_failure_at_w5_leaves_previous_profile_intact() -> void:
	_assert_failure_left_files_alone("W5")


func test_failure_at_w6_leaves_previous_profile_intact() -> void:
	_assert_failure_left_files_alone("W6")


func test_failure_at_w7_keeps_the_final_file_and_removes_the_stage() -> void:
	# Arrange: both rename attempts fail
	_writer.fail_at("W7")

	# Act
	var outcome: Error = _writer.write(_final, NEW_TEXT, _bak)

	# Assert: ADR-0004 W7, "still failing -> E_IO (final untouched)"; only the
	# backup-of-the-backup may go
	assert_int(outcome).is_equal(SaveErrors.E_IO)
	assert_str(_text(_final)).is_equal(OLD_TEXT)
	assert_bool(FileAccess.file_exists(_tmp)).is_false()
	assert_str(_writer.last_error_detail()).contains("W7")


func test_first_w7_failure_deletes_the_old_backup_and_retries_once() -> void:
	# Arrange: the first rename over the old backup fails, as on a platform that
	# refuses rename-over-existing
	_writer.fail_at("W7", 1)

	# Act
	var outcome: Error = _writer.write(_final, NEW_TEXT, _bak)

	# Assert
	assert_int(outcome).is_equal(OK)
	assert_str(_text(_final)).is_equal(NEW_TEXT)
	assert_str(_text(_bak)).is_equal(OLD_TEXT)
	assert_bool(FileAccess.file_exists(_tmp)).is_false()


func test_failure_at_w8_moves_the_old_file_back() -> void:
	# Arrange
	_writer.fail_at("W8")

	# Act
	var outcome: Error = _writer.write(_final, NEW_TEXT, _bak)

	# Assert
	assert_int(outcome).is_equal(SaveErrors.E_IO)
	assert_str(_text(_final)).is_equal(OLD_TEXT)
	assert_bool(FileAccess.file_exists(_tmp)).is_false()
	assert_str(_writer.last_error_detail()).contains("W8")


func test_failure_at_w8_with_no_previous_file_leaves_nothing_behind() -> void:
	# Arrange
	DirAccess.remove_absolute(_final)
	_writer.fail_at("W8")

	# Act
	var outcome: Error = _writer.write(_final, NEW_TEXT, _bak)

	# Assert: nothing rotated, so the backup is not moved into the final path
	assert_int(outcome).is_equal(SaveErrors.E_IO)
	assert_bool(FileAccess.file_exists(_final)).is_false()
	assert_str(_text(_bak)).is_equal(OLDER_TEXT)
	assert_bool(FileAccess.file_exists(_tmp)).is_false()


func test_write_with_no_fault_clears_the_error_detail() -> void:
	# Arrange
	_writer.fail_at("W4", 1)
	_writer.write(_final, NEW_TEXT, _bak)

	# Act
	var outcome: Error = _writer.write(_final, NEW_TEXT, _bak)

	# Assert
	assert_int(outcome).is_equal(OK)
	assert_str(_writer.last_error_detail()).is_empty()


func test_write_after_a_failed_write_commits_in_full() -> void:
	# Arrange
	_writer.fail_at("W5", 1)
	_writer.write(_final, NEW_TEXT, _bak)

	# Act
	var outcome: Error = _writer.write(_final, NEW_TEXT, _bak)

	# Assert
	assert_int(outcome).is_equal(OK)
	assert_str(_text(_final)).is_equal(NEW_TEXT)
	assert_str(_text(_bak)).is_equal(OLD_TEXT)
