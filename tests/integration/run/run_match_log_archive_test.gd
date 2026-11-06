## Integration: `RunMachine` files every finished match log (design/gdd/rng-event-log.md
## rule 18, Tuning Knobs `keep_match_logs`; ADR-0003 Decision 9; run-structure R4). A real
## `EventLogArchive` and `AtomicFileWriter` under a scratch root. A real overflow comes
## from a real log cap and a real `RulesEngine`.
extends GdUnitTestSuite

const ROOT: String = "user://tmp/run_match_logs/"
const HERO: String = RunHarness.HERO_ID
const SEED: String = "42"
const FAULTS: String = EventLogArchive.FAULTS_FOLDER
## Commands enough to overflow a log capped just past the deal.
const OVERFLOW_COMMANDS: int = 40


## A writer that refuses every write.
class RefusingWriter:
	extends AtomicFileWriter

	var writes: int = 0

	func write(_final_path: String, _text: String, _backup_path: String = "") -> Error:
		writes += 1
		return SaveErrors.E_IO


var _h: RunHarness = null


func before_test() -> void:
	_wipe(ROOT)
	_h = RunHarness.new()


func after_test() -> void:
	_h.release()
	_wipe(ROOT)


func _wipe(folder: String) -> void:
	var path: String = ProjectSettings.globalize_path(folder)
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_wipe(folder.path_join(sub))
	for file: String in dir.get_files():
		@warning_ignore("return_value_discarded")
		dir.remove(file)
	@warning_ignore("return_value_discarded")
	DirAccess.remove_absolute(path)


func _run_with(keep: bool, overrides: Dictionary = {}, writer: AtomicFileWriter = null) -> RunMachine:
	var archive := EventLogArchive.new(writer if writer != null else AtomicFileWriter.new(), keep, ROOT)
	var run: RunMachine = _h.machine(overrides, archive)
	assert_int(run.new_run(HERO, SEED)).is_equal(OK)
	return run


func _regular(run: RunMachine, floor_number: int, attempt: int) -> String:
	return ROOT.path_join(run.state.run_id).path_join(EventLogArchive.FILE_NAME % [floor_number, attempt])


func _fault_copy(run: RunMachine, floor_number: int, attempt: int) -> String:
	return ROOT.path_join(FAULTS).path_join("%s_%s" % [run.state.run_id, EventLogArchive.FILE_NAME % [floor_number, attempt]])


## How many events the fixture board logs before the first command.
func _events_at_the_deal() -> int:
	var probe := RunHarness.new()
	var run: RunMachine = probe.machine()
	assert_int(run.new_run(HERO, SEED)).is_equal(OK)
	var _driver: MatchDriver = probe.begin(run)
	var size: int = (probe.configs[0].log as EventLog).size()
	probe.release()
	return size


## Plays commands until the capped log overflows and the engine ends the match.
func _overflow_the_match(run: RunMachine) -> void:
	var driver: MatchDriver = _h.begin(run)
	for _i: int in OVERFLOW_COMMANDS:
		if run.phase() != RunState.STATUS_IN_MATCH:
			return
		var legal: Array = driver.legal_commands().filter(func(c: Dictionary) -> bool: return str(c.issuer) == MatchRecords.SIDE_PLAYER)
		if legal.is_empty():
			return
		@warning_ignore("return_value_discarded")
		driver.submit(legal.back())


# --- Regular copies ----------------------------------------------------------

func test_a_finished_match_is_filed_under_the_run_by_floor_and_attempt() -> void:
	# Arrange
	var run: RunMachine = _run_with(true)
	var _driver: MatchDriver = _h.begin(run)

	# Act
	_h.finish_win(run)

	# Assert
	assert_bool(FileAccess.file_exists(_regular(run, 1, 1))).is_true()
	assert_bool(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(ROOT.path_join(FAULTS)))).is_false()


func test_the_filed_log_is_the_sealed_match_log_and_parses() -> void:
	# Arrange
	var run: RunMachine = _run_with(true)
	var _driver: MatchDriver = _h.begin(run)
	var live: EventLog = _h.configs[0].log

	# Act
	_h.finish_win(run)

	# Assert
	var filed: EventLog = EventLog.from_json(FileAccess.get_file_as_string(_regular(run, 1, 1)))
	assert_object(filed).is_not_null()
	assert_bool(filed.is_sealed()).is_true()
	assert_str(filed.scope()).is_equal(EventLog.SCOPE_MATCH)
	assert_int(filed.size()).is_equal(live.size())
	assert_str(str(filed.events_since(0).back().type)).is_equal("match_ended")


func test_a_defeat_is_filed_too() -> void:
	# Arrange
	var run: RunMachine = _run_with(true)
	var _driver: MatchDriver = _h.begin(run)
	var path: String = _regular(run, 1, 1)

	# Act
	_h.finish_loss(run)

	# Assert
	assert_bool(FileAccess.file_exists(path)).is_true()


func test_a_faulted_attempt_and_its_retry_get_a_file_each() -> void:
	# Arrange
	var run: RunMachine = _run_with(true)
	var _first: MatchDriver = _h.begin(run)
	_h.finish_fault(run)

	# Act
	var _second: MatchDriver = _h.begin(run)
	_h.finish_win(run)

	# Assert
	assert_bool(FileAccess.file_exists(_regular(run, 1, 1))).is_true()
	assert_bool(FileAccess.file_exists(_regular(run, 1, 2))).is_true()


func test_a_fault_with_no_overflow_writes_no_fault_copy() -> void:
	# Arrange
	var run: RunMachine = _run_with(true)
	var _driver: MatchDriver = _h.begin(run)

	# Act
	_h.finish_fault(run)

	# Assert
	assert_bool(FileAccess.file_exists(_fault_copy(run, 1, 1))).is_false()


# --- keep_match_logs off -----------------------------------------------------

func test_with_keep_match_logs_off_nothing_is_written() -> void:
	# Arrange
	var run: RunMachine = _run_with(false)
	var _driver: MatchDriver = _h.begin(run)

	# Act
	_h.finish_win(run)

	# Assert
	assert_bool(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(ROOT))).is_false()
	assert_str(run.phase()).is_equal(RunState.STATUS_POST_MATCH_REWARD)


func test_with_keep_match_logs_off_a_refusing_writer_is_never_called() -> void:
	# Arrange
	var writer := RefusingWriter.new()
	var run: RunMachine = _run_with(false, {}, writer)
	var _driver: MatchDriver = _h.begin(run)

	# Act
	_h.finish_loss(run)

	# Assert
	assert_int(writer.writes).is_equal(0)


func test_no_archive_at_all_is_legal() -> void:
	# Arrange
	var run: RunMachine = _h.machine()
	assert_int(run.new_run(HERO, SEED)).is_equal(OK)
	var _driver: MatchDriver = _h.begin(run)

	# Act
	_h.finish_win(run)

	# Assert
	assert_str(run.phase()).is_equal(RunState.STATUS_POST_MATCH_REWARD)


# --- Overflow ----------------------------------------------------------------

func test_a_real_overflow_faults_the_match_and_files_both_copies() -> void:
	# Arrange
	var run: RunMachine = _run_with(true, {"max_match_events": _events_at_the_deal() + 2})

	# Act
	_overflow_the_match(run)

	# Assert
	assert_str(run.phase()).is_equal(RunState.STATUS_PRE_MATCH)
	assert_int(RunHarness.events_of(run.run_log, RunCodes.EVENT_MATCH_FAULTED).size()).is_equal(1)
	assert_bool(FileAccess.file_exists(_regular(run, 1, 1))).is_true()
	assert_bool(FileAccess.file_exists(_fault_copy(run, 1, 1))).is_true()


func test_an_overflow_is_filed_even_with_keep_match_logs_off() -> void:
	# Arrange
	var run: RunMachine = _run_with(false, {"max_match_events": _events_at_the_deal() + 2})

	# Act
	_overflow_the_match(run)

	# Assert
	assert_bool(FileAccess.file_exists(_fault_copy(run, 1, 1))).is_true()
	assert_bool(FileAccess.file_exists(_regular(run, 1, 1))).is_false()


func test_the_fault_copy_holds_the_overflow_and_the_fault_ending() -> void:
	# Arrange
	var run: RunMachine = _run_with(false, {"max_match_events": _events_at_the_deal() + 2})

	# Act
	_overflow_the_match(run)

	# Assert
	var filed: EventLog = EventLog.from_json(FileAccess.get_file_as_string(_fault_copy(run, 1, 1)))
	var types: Array = RunHarness.event_types(filed)
	assert_bool(types.has(EventLogArchive.EVENT_OVERFLOW)).is_true()
	assert_str(str(types.back())).is_equal("match_ended")
	assert_str(str(filed.events_since(0).back().payload.result)).is_equal(MatchRecords.RESULT_FAULT)


# --- A failed write ----------------------------------------------------------

func test_a_write_failure_does_not_stop_the_run() -> void:
	# Arrange
	var writer := RefusingWriter.new()
	var run: RunMachine = _run_with(true, {}, writer)
	var _driver: MatchDriver = _h.begin(run)

	# Act
	_h.finish_win(run)

	# Assert
	assert_int(writer.writes).is_equal(1)
	assert_str(run.phase()).is_equal(RunState.STATUS_POST_MATCH_REWARD)
	assert_int(run.state.match_summaries.size()).is_equal(1)


func test_a_write_failure_on_a_fault_still_returns_to_pre_match() -> void:
	# Arrange
	var writer := RefusingWriter.new()
	var run: RunMachine = _run_with(true, {"max_match_events": _events_at_the_deal() + 2}, writer)

	# Act
	_overflow_the_match(run)

	# Assert: both copies were tried, the regular failure did not stop the fault one
	assert_int(writer.writes).is_equal(2)
	assert_str(run.phase()).is_equal(RunState.STATUS_PRE_MATCH)


# --- The composition's setting -----------------------------------------------

func test_keep_for_build_reads_the_shipped_debug_and_release_values() -> void:
	# Arrange
	var body: Dictionary = RunHarness.shipped_body("res://assets/data/rng_event_log.json")

	# Act
	var debug: bool = EventLogArchive.keep_for_build(body, true)
	var release: bool = EventLogArchive.keep_for_build(body, false)

	# Assert: rng-event-log Tuning Knobs
	assert_bool(debug).is_true()
	assert_bool(release).is_false()
