## Integration: match logs filed under `user://logs/` (rng-event-log rule 18, Tuning Knobs
## `keep_match_logs`; ADR-0003 Decision 9; ADR-0004; story 009).
##
## Real files through the real [AtomicFileWriter], under a private root that [method
## after_test] removes, passed by the archive's test-only root argument. A write failure
## is simulated both ways the story allows: a writer told to fail, and a folder that
## cannot be made.
extends GdUnitTestSuite

const ROOT: String = "user://log_archive_test/"
const RUN_ID: String = "00000000000000ff-1700000000"
const FLOOR: int = 3
const ATTEMPT: int = 2
const MAX_EVENTS: int = 100
## Small enough to overflow: one event, then `log_overflow`.
const TINY_MAX_EVENTS: int = 2
const REGULAR_NAME: String = "floor_3_attempt_2.json"


## Fails at every stage of its write.
class BrokenWriter:
	extends AtomicFileWriter

	func _fails_at(_step: String) -> bool:
		return true


func after_test() -> void:
	_remove(ROOT)


func _remove(folder: String) -> void:
	if not DirAccess.dir_exists_absolute(folder):
		return
	for sub: String in DirAccess.get_directories_at(folder):
		_remove(folder.path_join(sub))
	for file_name: String in DirAccess.get_files_at(folder):
		@warning_ignore("return_value_discarded")
		DirAccess.remove_absolute(folder.path_join(file_name))
	@warning_ignore("return_value_discarded")
	DirAccess.remove_absolute(folder)


func _sealed_log() -> EventLog:
	var log: EventLog = EventLog.new(MAX_EVENTS, EventLog.SCOPE_MATCH, {"floor": FLOOR})
	@warning_ignore("return_value_discarded")
	log.append(&"card_drawn", {"side": "player"}, 0)
	@warning_ignore("return_value_discarded")
	log.append(&"match_ended", {"result": "win", "reason": "hero_dead"}, 0)
	return log


## A log that reached `log_overflow` and was sealed by its `match_ended`.
func _overflowed_log() -> EventLog:
	var log: EventLog = EventLog.new(TINY_MAX_EVENTS, EventLog.SCOPE_MATCH, {"floor": FLOOR})
	for _i: int in TINY_MAX_EVENTS + 1:
		@warning_ignore("return_value_discarded")
		log.append(&"card_drawn", {"side": "player"}, 0)
	@warning_ignore("return_value_discarded")
	log.append(&"match_ended", {"result": "fault", "reason": "event_cap"}, 0)
	return log


func _archive(keep: bool, writer: AtomicFileWriter = AtomicFileWriter.new(), root: String = ROOT) -> EventLogArchive:
	return EventLogArchive.new(writer, keep, root)


func _regular_path() -> String:
	return ROOT.path_join(RUN_ID).path_join(REGULAR_NAME)


func _faults_path() -> String:
	return ROOT.path_join(EventLogArchive.FAULTS_FOLDER).path_join("%s_%s" % [RUN_ID, REGULAR_NAME])


func test_a_kept_log_is_written_equal_to_to_json() -> void:
	# Arrange
	var log: EventLog = _sealed_log()

	# Act
	var error: Error = _archive(true).archive_match(log, RUN_ID, FLOOR, ATTEMPT)

	# Assert
	assert_int(error).is_equal(OK)
	assert_str(FileAccess.get_file_as_string(_regular_path())).is_equal(log.to_json())


func test_a_kept_log_leaves_no_staging_file() -> void:
	# Act
	@warning_ignore("return_value_discarded")
	_archive(true).archive_match(_sealed_log(), RUN_ID, FLOOR, ATTEMPT)

	# Assert
	assert_bool(FileAccess.file_exists(_regular_path() + AtomicFileWriter.TMP_SUFFIX)).is_false()


func test_a_kept_log_reads_back_replay_equal() -> void:
	# Arrange
	var log: EventLog = _sealed_log()
	@warning_ignore("return_value_discarded")
	_archive(true).archive_match(log, RUN_ID, FLOOR, ATTEMPT)

	# Act
	var read_back: EventLog = EventLog.from_json(FileAccess.get_file_as_string(_regular_path()))

	# Assert
	assert_object(read_back).is_not_null()
	EventLogAssertions.assert_replay_equal(log, read_back)


func test_keep_false_writes_nothing_and_makes_no_folder() -> void:
	# Act
	var error: Error = _archive(false).archive_match(_sealed_log(), RUN_ID, FLOOR, ATTEMPT)

	# Assert
	assert_int(error).is_equal(OK)
	assert_bool(DirAccess.dir_exists_absolute(ROOT)).is_false()


func test_an_overflowed_log_goes_to_faults_even_with_keep_false() -> void:
	# Arrange
	var log: EventLog = _overflowed_log()

	# Act
	var error: Error = _archive(false).archive_match(log, RUN_ID, FLOOR, ATTEMPT)

	# Assert
	assert_int(error).is_equal(OK)
	assert_str(FileAccess.get_file_as_string(_faults_path())).is_equal(log.to_json())
	assert_bool(FileAccess.file_exists(_regular_path())).is_false()


func test_an_overflowed_log_gets_both_copies_with_keep_true() -> void:
	# Act
	@warning_ignore("return_value_discarded")
	_archive(true).archive_match(_overflowed_log(), RUN_ID, FLOOR, ATTEMPT)

	# Assert
	assert_bool(FileAccess.file_exists(_regular_path())).is_true()
	assert_bool(FileAccess.file_exists(_faults_path())).is_true()


func test_a_failed_write_returns_its_error_and_leaves_no_file() -> void:
	# Arrange
	var log: EventLog = _sealed_log()
	var text: String = log.to_json()

	# Act
	var error: Error = _archive(true, BrokenWriter.new()).archive_match(log, RUN_ID, FLOOR, ATTEMPT)

	# Assert — visible, not fatal: the log is as it was
	assert_int(error).is_not_equal(OK)
	assert_bool(FileAccess.file_exists(_regular_path())).is_false()
	assert_str(log.to_json()).is_equal(text)


func test_a_folder_that_cannot_be_made_returns_an_error() -> void:
	# Arrange — a file where the root's folder should be
	DirAccess.make_dir_recursive_absolute(ROOT)
	var blocker: FileAccess = FileAccess.open(ROOT.path_join("blocker"), FileAccess.WRITE)
	blocker.close()

	# Act
	var error: Error = _archive(true, AtomicFileWriter.new(), ROOT.path_join("blocker")).archive_match(_sealed_log(), RUN_ID, FLOOR, ATTEMPT)

	# Assert
	assert_int(error).is_not_equal(OK)


func test_a_failed_regular_copy_does_not_stop_the_faults_copy() -> void:
	# Arrange — the faults copy is the log's only way out: a writer failing only the first
	var writer: FailsOnce = FailsOnce.new()
	var log: EventLog = _overflowed_log()

	# Act
	var error: Error = _archive(true, writer).archive_match(log, RUN_ID, FLOOR, ATTEMPT)

	# Assert
	assert_int(error).is_not_equal(OK)
	assert_bool(FileAccess.file_exists(_faults_path())).is_true()


## Fails its first write.
class FailsOnce:
	extends AtomicFileWriter

	var _writes: int = 0

	func write(final_path: String, text: String, backup_path: String = "") -> Error:
		_writes += 1
		if _writes == 1:
			return ERR_FILE_CANT_WRITE
		return super(final_path, text, backup_path)


func test_keep_for_build_reads_the_setting_of_each_build_type() -> void:
	# Arrange
	var config: Dictionary = {"keep_match_logs": {"debug": true, "release": false}}

	# Act / Assert
	assert_bool(EventLogArchive.keep_for_build(config, true)).is_true()
	assert_bool(EventLogArchive.keep_for_build(config, false)).is_false()
	assert_bool(EventLogArchive.keep_for_build({}, true)).is_false()
