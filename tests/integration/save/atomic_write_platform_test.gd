## Integration: what the operating system really does with the M4 renames (ADR-0004
## Engine Compatibility and Verification; meta-progression epic gate condition 9).
## `DirAccess.rename_absolute` atomicity is NOT SOURCEABLE, so these run real renames
## on real files with no fault injected, and the result on Windows is the evidence the
## gate asks for (`production/qa/evidence/save-platform-windows/`).
##
## The two `Windows only` tests hold a file open across a write, the shape of an
## antivirus or indexer lock; other platforms have no such refusal to prove.
extends GdUnitTestSuite

const ROUNDS: int = 50
const NON_ASCII_TEXT: String = "{\"name\": \"Maître d'Ætherhöhle 龍\"}"

var _root: String
var _writer: AtomicFileWriter
var _final: String
var _bak: String
var _tmp: String


func before_test() -> void:
	_root = ProfileFixtures.new_root()
	_writer = AtomicFileWriter.new()
	_final = _root.path_join("profile.json")
	_bak = _root.path_join("profile.bak")
	_tmp = _final + AtomicFileWriter.TMP_SUFFIX


func after_test() -> void:
	ProfileFixtures.remove_root(_root)


func _text(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func test_first_write_creates_the_final_file_and_no_backup() -> void:
	# Act
	var outcome: Error = _writer.write(_final, "first", _bak)

	# Assert
	assert_int(outcome).is_equal(OK)
	assert_str(_text(_final)).is_equal("first")
	assert_bool(FileAccess.file_exists(_bak)).is_false()
	assert_bool(FileAccess.file_exists(_tmp)).is_false()


func test_second_write_moves_the_first_to_the_backup() -> void:
	# Arrange
	_writer.write(_final, "first", _bak)

	# Act
	var outcome: Error = _writer.write(_final, "second", _bak)

	# Assert
	assert_int(outcome).is_equal(OK)
	assert_str(_text(_final)).is_equal("second")
	assert_str(_text(_bak)).is_equal("first")


func test_bak_rotation_over_existing_bak() -> void:
	# Arrange: the one rename over an existing file (ADR-0004 W7)
	_writer.write(_final, "first", _bak)
	_writer.write(_final, "second", _bak)

	# Act
	var outcome: Error = _writer.write(_final, "third", _bak)

	# Assert
	assert_int(outcome).is_equal(OK)
	assert_str(_writer.last_error_detail()).is_empty()
	assert_str(_text(_final)).is_equal("third")
	assert_str(_text(_bak)).is_equal("second")
	assert_bool(FileAccess.file_exists(_tmp)).is_false()


func test_repeated_writes_always_leave_the_previous_generation_in_the_backup() -> void:
	# Arrange
	_writer.write(_final, "generation -1", _bak)

	# Act / Assert
	for generation: int in ROUNDS:
		assert_int(_writer.write(_final, "generation %d" % generation, _bak)).is_equal(OK)
		assert_str(_text(_final)).is_equal("generation %d" % generation)
		assert_str(_text(_bak)).is_equal("generation %d" % (generation - 1))
	assert_bool(FileAccess.file_exists(_tmp)).is_false()


func test_write_without_a_backup_replaces_an_existing_file() -> void:
	# Arrange: the lock and `RECOVERED_BAK` shape, a rename onto an existing target
	_writer.write(_final, "first")

	# Act
	var outcome: Error = _writer.write(_final, "second")

	# Assert
	assert_int(outcome).is_equal(OK)
	assert_str(_text(_final)).is_equal("second")
	assert_bool(FileAccess.file_exists(_tmp)).is_false()


func test_write_creates_a_missing_directory() -> void:
	# Arrange: ADR-0004 "Missing user://runs/ is created"
	var nested: String = _root.path_join("runs").path_join("run_a.json")

	# Act
	var outcome: Error = _writer.write(nested, "record")

	# Assert
	assert_int(outcome).is_equal(OK)
	assert_str(_text(nested)).is_equal("record")


func test_size_check_counts_bytes_not_characters() -> void:
	# Act: a W6 that compared characters would fail this text
	var outcome: Error = _writer.write(_final, NON_ASCII_TEXT, _bak)

	# Assert
	assert_int(outcome).is_equal(OK)
	assert_str(_text(_final)).is_equal(NON_ASCII_TEXT)


func test_stale_stage_from_a_crash_is_overwritten_and_removed() -> void:
	# Arrange
	ProfileFixtures.write_text(_tmp, "left by a crash, and longer than the text about to be written")

	# Act
	var outcome: Error = _writer.write(_final, "fresh", _bak)

	# Assert
	assert_int(outcome).is_equal(OK)
	assert_str(_text(_final)).is_equal("fresh")
	assert_bool(FileAccess.file_exists(_tmp)).is_false()


func test_windows_only_open_backup_never_costs_the_profile() -> void:
	if OS.get_name() != "Windows":
		return
	# Arrange: a reader on `.bak`, as an indexer would hold it
	_writer.write(_final, "first", _bak)
	_writer.write(_final, "second", _bak)
	var reader: FileAccess = FileAccess.open(_bak, FileAccess.READ)

	# Act
	var outcome: Error = _writer.write(_final, "third", _bak)
	reader.close()

	# Assert: either the write went through or `profile.json` is as it was
	var expected: String = "third" if outcome == OK else "second"
	assert_str(_text(_final)).is_equal(expected)
	assert_bool(FileAccess.file_exists(_tmp)).is_false()
	assert_int(_writer.write(_final, "fourth", _bak)).is_equal(OK)
	assert_str(_text(_final)).is_equal("fourth")


func test_windows_only_open_profile_never_costs_the_profile() -> void:
	if OS.get_name() != "Windows":
		return
	# Arrange: a reader on the final file, which W7 has to move
	_writer.write(_final, "first", _bak)
	_writer.write(_final, "second", _bak)
	var reader: FileAccess = FileAccess.open(_final, FileAccess.READ)

	# Act
	var outcome: Error = _writer.write(_final, "third", _bak)
	reader.close()

	# Assert
	var expected: String = "third" if outcome == OK else "second"
	assert_str(_text(_final)).is_equal(expected)
	assert_bool(FileAccess.file_exists(_tmp)).is_false()
	assert_int(_writer.write(_final, "fourth", _bak)).is_equal(OK)
	assert_str(_text(_final)).is_equal("fourth")
