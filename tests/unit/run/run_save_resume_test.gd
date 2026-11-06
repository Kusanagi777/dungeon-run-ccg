## Run Structure R7-R8: save points, resume and suspend (design/gdd/run-structure.md
## AC-17 to AC-23, AC-32, AC-36, Edge Cases "Saving, quitting, resuming"). A resume is a
## new `RunMachine` over the same slot, whose record has been through JSON, as a record
## loaded from disk has.
extends GdUnitTestSuite

const HERO: String = RunHarness.HERO_ID
const SEED: String = "42"
const TREASURE: StringName = &"treasure"
const BUNDLE: StringName = &"bundle"
const K_BUNDLE: String = DraftRecord.KIND_BUNDLE
const K_TREASURE: String = DraftRecord.KIND_TREASURE
const FLOOR_TWO: int = 2
const FLOOR_THREE: int = 3
const FLOOR_FOUR: int = 4
const ONLY_FLOOR_THREE: Dictionary = {"treasure_floors": [3]}
const DRAFT_STATE: Dictionary = {"schema_version": 1, "treasure_pool": ["t1", "t2", "t3"]}
const EMPTY_TREASURE_STATE: Dictionary = {"schema_version": 1, "by_treasure": {}}

var _h: RunHarness = null
var _run: RunMachine = null


func before_test() -> void:
	_h = RunHarness.new()


func after_test() -> void:
	_h.release()


func _start(overrides: Dictionary = {}) -> void:
	_run = _h.machine(overrides)
	assert_int(_run.new_run(HERO, SEED)).is_equal(OK)


## The next launch: the slot as disk gives it back, a new machine, resumed.
func _relaunch(overrides: Dictionary = {}, expected: Error = OK) -> RunMachine:
	_h.meta.reload_slot_as_json()
	var run: RunMachine = _h.machine(overrides)
	assert_int(run.resume()).is_equal(expected)
	return run


func _begin_and_win(run: RunMachine) -> void:
	var _driver: MatchDriver = _h.begin(run)
	_h.finish_win(run)


## The slot holds a saved run; [param edit] changes it as a tampered file would.
func _edited_slot(edit: Callable) -> void:
	_h.meta.reload_slot_as_json()
	var record: Dictionary = _h.meta.load_active_run()
	edit.call(record)
	_h.meta.set_slot(record)


# --- AC-17 -------------------------------------------------------------------

func _at_s3_on_floor_three() -> String:
	_start(ONLY_FLOOR_THREE)
	_h.advance_to(_run, FLOOR_THREE)
	_begin_and_win(_run)
	var id: String = _h.offered(_run)[0]
	assert_int(_run.draft_pick(TREASURE, id)).is_equal(OK)
	return id


func test_a_repeated_treasure_pick_after_resume_is_e_draft_done() -> void:
	# Arrange
	var id: String = _at_s3_on_floor_three()
	var run: RunMachine = _relaunch(ONLY_FLOOR_THREE)

	# Act
	var answer: Error = run.draft_pick(TREASURE, id)

	# Assert
	assert_int(answer).is_equal(RunCodes.E_DRAFT_DONE)
	assert_array(Array(run.state.treasures)).is_equal([id])


func test_a_resumed_treasure_installs_exactly_once_at_the_next_match() -> void:
	# Arrange
	var id: String = _at_s3_on_floor_three()
	var run: RunMachine = _relaunch(ONLY_FLOOR_THREE)
	assert_int(run.draft_pick(BUNDLE, _h.offered(run)[0])).is_equal(OK)
	var calls_before: int = _h.treasures.installer_calls.size()

	# Act
	var _driver: MatchDriver = _h.begin(run)

	# Assert
	var calls: Array = _h.treasures.installer_calls.slice(calls_before)
	assert_int(calls.size()).is_equal(1)
	assert_array(calls[0]).is_equal([id])


# --- AC-18 -------------------------------------------------------------------

func test_a_run_saved_at_s2_regenerates_the_treasure_offer_from_draws_zero() -> void:
	# Arrange
	_start()
	_h.advance_to(_run, FLOOR_THREE)
	_begin_and_win(_run)
	var before: Array = _h.offered(_run).duplicate()

	# Act
	var run: RunMachine = _relaunch()

	# Assert
	assert_str(str(run.state.reward_step)).is_equal(K_TREASURE)
	assert_array(_h.offered(run)).is_equal(before)
	assert_int(int(_h.draft.calls_of("offer").back().draws_before)).is_equal(0)


func test_a_run_saved_at_s3_regenerates_the_bundle_offer() -> void:
	# Arrange
	_start()
	_h.advance_to(_run, FLOOR_THREE)
	_begin_and_win(_run)
	assert_int(_run.draft_pick(TREASURE, _h.offered(_run)[0])).is_equal(OK)
	var before: Array = _h.offered(_run).duplicate()

	# Act
	var run: RunMachine = _relaunch()

	# Assert
	assert_str(str(run.state.reward_step)).is_equal(K_BUNDLE)
	assert_array(_h.offered(run)).is_equal(before)
	assert_int(int(_h.draft.calls_of("offer").back().draws_before)).is_equal(RunHarness.OFFER_SIZE)


# --- AC-19 -------------------------------------------------------------------

func test_a_quit_mid_match_resumes_at_pre_match_as_attempt_two() -> void:
	# Arrange
	_start()
	_h.advance_to(_run, FLOOR_FOUR)
	var _driver: MatchDriver = _h.begin(_run)

	# Act: the process is gone, nothing was called
	var run: RunMachine = _relaunch()

	# Assert
	assert_str(run.phase()).is_equal(RunState.STATUS_PRE_MATCH)
	assert_int(run.state.floor).is_equal(FLOOR_FOUR)
	assert_dict(RunHarness.events_of(run.run_log, RunCodes.EVENT_RUN_RESUMED).back().payload).is_equal({"floor": FLOOR_FOUR, "phase": RunState.STATUS_PRE_MATCH, "attempt": 2})


func test_the_restarted_match_gets_the_first_attempts_streams_at_draws_zero() -> void:
	# Arrange
	_start()
	_h.advance_to(_run, FLOOR_FOUR)
	var _first: MatchDriver = _h.begin(_run)
	var first: RngStream = _h.configs.back().rng_match
	var first_ai: RngStream = _h.configs.back().rng_ai
	var first_order: Array = [1, 2, 3, 4, 5, 6]
	first.shuffle(first_order)
	var first_ai_draw: int = first_ai.randi32()
	var run: RunMachine = _relaunch()

	# Act
	var _second: MatchDriver = _h.begin(run)

	# Assert
	var again: RngStream = _h.configs.back().rng_match
	var again_order: Array = [1, 2, 3, 4, 5, 6]
	assert_int(again.draws).is_equal(0)
	again.shuffle(again_order)
	assert_array(again_order).is_equal(first_order)
	assert_int((_h.configs.back().rng_ai as RngStream).randi32()).is_equal(first_ai_draw)
	assert_int(run.state.attempts_on(FLOOR_FOUR)).is_equal(2)


# --- AC-20, AC-21 and the R8.1 table -----------------------------------------

func _resume_refused(code: Error) -> RunMachine:
	var run: RunMachine = _h.machine()
	assert_int(run.resume()).is_equal(code)
	return run


func test_another_data_version_is_archived_as_a_mismatch_and_not_a_loss() -> void:
	# Arrange
	_start()
	_edited_slot(func(record: Dictionary) -> void: record["data_version"] = "older-data")

	# Act
	var run: RunMachine = _resume_refused(RunCodes.E_DATA_VERSION)

	# Assert
	assert_int(_h.archived.size()).is_equal(1)
	assert_str(_h.archived[0].result.outcome).is_equal(RunState.STATUS_ABANDONED)
	assert_str(_h.archived[0].result.abandon_reason).is_equal(RunState.REASON_DATA_VERSION_MISMATCH)
	assert_object(_h.meta.load_active_run()).is_null()
	assert_str(run.phase()).is_equal(RunState.STATUS_ABANDONED)


func test_a_corrupted_boss_sequence_is_archived_as_save_corrupt() -> void:
	# Arrange
	_start()
	_edited_slot(func(record: Dictionary) -> void: (record.boss_sequence as Array).pop_back())

	# Act
	var _run2: RunMachine = _resume_refused(RunCodes.E_CORRUPT)

	# Assert
	assert_str(_h.archived[0].result.abandon_reason).is_equal(RunState.REASON_SAVE_CORRUPT)
	assert_object(_h.meta.load_active_run()).is_null()


func test_an_id_that_no_longer_resolves_is_a_data_version_mismatch() -> void:
	# Arrange
	_start()
	_edited_slot(func(record: Dictionary) -> void: record.deck[0] = "card_removed_from_the_game")

	# Act
	var _run2: RunMachine = _resume_refused(RunCodes.E_UNKNOWN_ID)

	# Assert
	assert_str(_h.archived[0].result.abandon_reason).is_equal(RunState.REASON_DATA_VERSION_MISMATCH)


func test_a_wrong_schema_version_is_archived_as_save_corrupt() -> void:
	# Arrange
	_start()
	_edited_slot(func(record: Dictionary) -> void: record["schema_version"] = 2)

	# Act
	var _run2: RunMachine = _resume_refused(RunCodes.E_SCHEMA)

	# Assert
	assert_str(_h.archived[0].result.abandon_reason).is_equal(RunState.REASON_SAVE_CORRUPT)


func test_a_record_with_no_identity_is_cleared_with_nothing_archived() -> void:
	# Arrange
	_h.meta.set_slot({"floor": 3, "schema_version": 1})

	# Act
	var run: RunMachine = _resume_refused(RunCodes.E_SCHEMA)

	# Assert
	assert_array(_h.archived).is_empty()
	assert_object(_h.meta.load_active_run()).is_null()
	assert_str(run.phase()).is_equal(RunMachine.PHASE_MENU)


func test_a_record_with_only_a_run_id_is_still_archived() -> void:
	# Arrange
	_h.meta.set_slot({"run_id": "0000000000000001-5"})

	# Act
	var _run2: RunMachine = _resume_refused(RunCodes.E_SCHEMA)

	# Assert
	assert_int(_h.archived.size()).is_equal(1)
	assert_str(_h.archived[0].result.abandon_reason).is_equal(RunState.REASON_SAVE_CORRUPT)


func test_an_empty_slot_is_e_no_save() -> void:
	# Arrange
	var run: RunMachine = _h.machine()

	# Act
	var answer: Error = run.resume()

	# Assert
	assert_int(answer).is_equal(RunCodes.E_NO_SAVE)
	assert_str(run.phase()).is_equal(RunMachine.PHASE_MENU)


func test_a_slot_that_is_not_an_object_is_cleared_as_corrupt() -> void:
	# Arrange
	_h.meta.set_slot("not a record")

	# Act
	var _run2: RunMachine = _resume_refused(RunCodes.E_CORRUPT)

	# Assert
	assert_object(_h.meta.load_active_run()).is_null()


func test_a_malformed_summary_ends_as_save_corrupt_and_does_not_crash() -> void:
	# Arrange: AC-21's "the game does not crash", on a row `totals` will fold
	_start()
	_h.play_floor(_run)
	_edited_slot(func(record: Dictionary) -> void: record.match_summaries[0]["turns"] = ["not", "a", "number"])

	# Act
	var _run2: RunMachine = _resume_refused(RunCodes.E_CORRUPT)

	# Assert
	assert_str(_h.archived[0].result.abandon_reason).is_equal(RunState.REASON_SAVE_CORRUPT)
	assert_object(_h.meta.load_active_run()).is_null()


func test_a_draft_row_with_no_picked_id_ends_as_save_corrupt_and_does_not_crash() -> void:
	# Arrange
	_start()
	_h.play_floor(_run)
	_edited_slot(func(record: Dictionary) -> void: (record.drafts[0] as Dictionary).erase("picked_id"))

	# Act
	var _run2: RunMachine = _resume_refused(RunCodes.E_CORRUPT)

	# Assert
	assert_str(_h.archived[0].result.abandon_reason).is_equal(RunState.REASON_SAVE_CORRUPT)


func test_a_run_log_that_will_not_reopen_ends_as_save_corrupt() -> void:
	# Arrange
	_start()
	_edited_slot(func(record: Dictionary) -> void: record.run_log["log_schema_version"] = 99)

	# Act
	var _run2: RunMachine = _resume_refused(RunCodes.E_CORRUPT)

	# Assert
	assert_str(_h.archived[0].result.abandon_reason).is_equal(RunState.REASON_SAVE_CORRUPT)


func test_a_sealed_run_log_is_never_reopened() -> void:
	# Arrange: a save whose log already holds its `run_ended`
	_start()
	_edited_slot(func(record: Dictionary) -> void:
		var events: Array = record.run_log.events
		events.append({"seq": events.size() + 1, "turn": 0, "type": "run_ended", "payload": {}, "cause_seq": 0}))

	# Act
	var _run2: RunMachine = _resume_refused(RunCodes.E_CORRUPT)

	# Assert
	assert_int(_h.archived.size()).is_equal(1)


func test_a_saved_terminal_status_is_not_played_on() -> void:
	# Arrange
	_start()
	_edited_slot(func(record: Dictionary) -> void: record["status"] = RunState.STATUS_DEFEAT)

	# Act
	var _run2: RunMachine = _resume_refused(RunCodes.E_CORRUPT)

	# Assert
	assert_str(_h.archived[0].result.abandon_reason).is_equal(RunState.REASON_SAVE_CORRUPT)


# --- AC-22 -------------------------------------------------------------------

func test_a_failed_save_warns_once_goes_on_and_the_next_save_point_retries() -> void:
	# Arrange
	_start()
	_h.advance_to(_run, FLOOR_TWO)
	var _driver: MatchDriver = _h.begin(_run)
	_h.meta.save_answers = [SaveErrors.E_IO]
	var saved_before: int = RunHarness.events_of(_run.run_log, RunCodes.EVENT_RUN_SAVED).size()

	# Act: S2 fails, the bundle pick reaches S4
	_h.finish_win(_run)
	var pick: Error = _run.draft_pick(BUNDLE, _h.offered(_run)[0])

	# Assert
	assert_int(pick).is_equal(OK)
	var warnings: Array = RunHarness.warnings_of(_run.run_log, RunCodes.W_SAVE_FAILED)
	assert_int(warnings.size()).is_equal(1)
	assert_int(int(warnings[0].payload.detail.floor)).is_equal(FLOOR_TWO)
	var saved: Array = RunHarness.events_of(_run.run_log, RunCodes.EVENT_RUN_SAVED).slice(saved_before)
	assert_int(saved.size()).is_equal(1)
	assert_dict(saved[0].payload).is_equal({"floor": FLOOR_TWO + 1, "phase": RunState.STATUS_PRE_MATCH})


func test_a_quit_after_a_failed_save_lands_at_the_last_good_save() -> void:
	# Arrange
	_start()
	_h.advance_to(_run, FLOOR_TWO)
	var _driver: MatchDriver = _h.begin(_run)
	_h.meta.save_answers = [SaveErrors.E_READONLY]
	_h.finish_win(_run)

	# Act
	var run: RunMachine = _relaunch()

	# Assert: the begin_match record, at pre_match on the floor
	assert_str(run.phase()).is_equal(RunState.STATUS_PRE_MATCH)
	assert_int(run.state.floor).is_equal(FLOOR_TWO)


# --- AC-23 -------------------------------------------------------------------

func test_a_locked_hero_refuses_new_run() -> void:
	# Arrange
	_h.meta.locked = [HERO]
	var run: RunMachine = _h.machine()

	# Act
	var answer: Error = run.new_run(HERO, SEED)

	# Assert
	assert_int(answer).is_equal(RunCodes.E_HERO_LOCKED)
	assert_object(run.state).is_null()
	assert_array(_h.save_attempts).is_empty()


func test_an_unknown_hero_refuses_new_run() -> void:
	# Arrange
	var run: RunMachine = _h.machine()

	# Act
	var answer: Error = run.new_run("hero_nobody", SEED)

	# Assert
	assert_int(answer).is_equal(RunCodes.E_UNKNOWN_ID)


func test_a_locked_hero_resumes_with_a_warning() -> void:
	# Arrange
	_start()
	_h.meta.locked = [HERO]

	# Act
	var run: RunMachine = _relaunch()

	# Assert
	assert_str(run.phase()).is_equal(RunState.STATUS_PRE_MATCH)
	assert_int(RunHarness.warnings_of(run.run_log, RunCodes.W_HERO_LOCKED_AT_RESUME).size()).is_equal(1)


# --- AC-32 -------------------------------------------------------------------

func test_init_run_runs_once_after_the_rng_and_before_run_started() -> void:
	# Arrange: the stub sees the run as it stands at the call
	var run: RunMachine = _h.machine()
	var seen: Array = []
	run.run_log_opened.connect(func(log: EventLog) -> void: seen.append(log.size()))

	# Act
	assert_int(run.new_run(HERO, SEED)).is_equal(OK)

	# Assert
	var calls: Array = _h.draft.calls_of("init_run")
	assert_int(calls.size()).is_equal(1)
	assert_object(run.rng).is_not_null()
	assert_int(_h.trace.find("init_run")).is_less(_h.trace.find("save_active_run"))
	assert_str(RunHarness.event_types(run.run_log)[0]).is_equal(String(RunCodes.EVENT_RUN_STARTED))
	assert_array(seen).is_equal([0])


func test_the_s1_save_holds_draft_state_and_an_empty_treasure_state() -> void:
	# Act
	_start()

	# Assert
	var saved: Dictionary = _h.save_attempts[0]
	assert_dict(saved.draft_state).is_equal(DRAFT_STATE)
	assert_dict(saved.treasure_state).is_equal(EMPTY_TREASURE_STATE)
	assert_str(saved.status).is_equal(RunState.STATUS_PRE_MATCH)
	assert_int(int(saved.floor)).is_equal(1)


func test_an_empty_draft_state_is_rebuilt_before_the_offer_with_one_warning() -> void:
	# Arrange: an S2 save whose draft_state is {}
	_start()
	_begin_and_win(_run)
	_edited_slot(func(record: Dictionary) -> void: record["draft_state"] = {})
	var inits_before: int = _h.draft.calls_of("init_run").size()
	var mark: int = _h.trace.size()

	# Act
	var run: RunMachine = _relaunch()

	# Assert
	assert_int(_h.draft.calls_of("init_run").size()).is_equal(inits_before + 1)
	var tail: Array[String] = _h.trace.slice(mark)
	assert_int(tail.find("init_run")).is_less(tail.find("offer:%s" % K_TREASURE))
	assert_int(RunHarness.warnings_of(run.run_log, RunCodes.W_DRAFT_STATE_INIT_LATE).size()).is_equal(1)
	assert_dict(run.state.draft_state).is_equal(DRAFT_STATE)


func test_a_draft_state_of_an_unknown_version_is_rebuilt_too() -> void:
	# Arrange
	_start()
	_edited_slot(func(record: Dictionary) -> void: record.draft_state["schema_version"] = 2)

	# Act
	var run: RunMachine = _relaunch()

	# Assert
	assert_int(RunHarness.warnings_of(run.run_log, RunCodes.W_DRAFT_STATE_INIT_LATE).size()).is_equal(1)


func test_a_usable_draft_state_is_left_alone_on_resume() -> void:
	# Arrange
	_start()
	var inits_before: int = _h.draft.calls_of("init_run").size()

	# Act
	var run: RunMachine = _relaunch()

	# Assert
	assert_int(_h.draft.calls_of("init_run").size()).is_equal(inits_before)
	assert_array(RunHarness.warnings_of(run.run_log, RunCodes.W_DRAFT_STATE_INIT_LATE)).is_empty()


# --- AC-36 -------------------------------------------------------------------

func _suspended_at_s3() -> Array:
	_start()
	_h.advance_to(_run, FLOOR_THREE)
	_begin_and_win(_run)
	assert_int(_run.draft_pick(TREASURE, _h.offered(_run)[0])).is_equal(OK)
	return _h.offered(_run).duplicate()


func test_suspend_emits_nothing_saves_nothing_and_leaves_the_slot() -> void:
	# Arrange
	var _offer: Array = _suspended_at_s3()
	var log: EventLog = _run.run_log
	var events: int = log.size()
	var saves: int = _h.save_attempts.size()
	var slot: String = JSON.stringify(_h.meta.load_active_run())

	# Act
	var answer: Error = _run.suspend()

	# Assert
	assert_int(answer).is_equal(OK)
	assert_int(log.size()).is_equal(events)
	assert_int(_h.save_attempts.size()).is_equal(saves)
	assert_object(_run.state).is_null()
	assert_str(_run.phase()).is_equal(RunMachine.PHASE_MENU)
	assert_str(JSON.stringify(_h.meta.load_active_run())).is_equal(slot)


func test_resume_after_suspend_reenters_the_bundle_step_with_the_identical_offer() -> void:
	# Arrange
	var before: Array = _suspended_at_s3()
	assert_int(_run.suspend()).is_equal(OK)

	# Act: the same machine, as Continue does
	var answer: Error = _run.resume()

	# Assert
	assert_int(answer).is_equal(OK)
	assert_str(_run.phase()).is_equal(RunState.STATUS_POST_MATCH_REWARD)
	assert_str(str(_run.state.reward_step)).is_equal(K_BUNDLE)
	assert_int(_run.state.floor).is_equal(FLOOR_THREE)
	assert_array(_h.offered(_run)).is_equal(before)


func test_suspend_in_a_match_is_e_bad_phase_with_no_change() -> void:
	# Arrange
	_start()
	var _driver: MatchDriver = _h.begin(_run)

	# Act
	var answer: Error = _run.suspend()

	# Assert
	assert_int(answer).is_equal(RunCodes.E_BAD_PHASE)
	assert_str(_run.phase()).is_equal(RunState.STATUS_IN_MATCH)


func test_suspend_after_a_defeat_is_e_bad_phase_with_no_change() -> void:
	# Arrange
	_start()
	var _driver: MatchDriver = _h.begin(_run)
	_h.finish_loss(_run)

	# Act
	var answer: Error = _run.suspend()

	# Assert
	assert_int(answer).is_equal(RunCodes.E_BAD_PHASE)
	assert_str(_run.phase()).is_equal(RunState.STATUS_DEFEAT)


# --- R8.2, R8.6, and the crash window of R6 ----------------------------------

func test_a_saved_in_match_status_is_coerced_with_a_warning() -> void:
	# Arrange
	_start()
	_edited_slot(func(record: Dictionary) -> void: record["status"] = RunState.STATUS_IN_MATCH)

	# Act
	var run: RunMachine = _relaunch()

	# Assert
	assert_str(run.phase()).is_equal(RunState.STATUS_PRE_MATCH)
	assert_int(RunHarness.warnings_of(run.run_log, RunCodes.W_COERCED_STATUS).size()).is_equal(1)


func test_an_engine_version_change_warns_and_resumes() -> void:
	# Arrange
	_start()
	_edited_slot(func(record: Dictionary) -> void: record["engine_version"] = "older-engine")

	# Act
	var run: RunMachine = _relaunch()

	# Assert
	var warnings: Array = RunHarness.warnings_of(run.run_log, RunCodes.W_ENGINE_VERSION_CHANGED)
	assert_int(warnings.size()).is_equal(1)
	assert_dict(warnings[0].payload.detail).is_equal({"saved": "older-engine", "installed": RunHarness.ENGINE_VERSION})


func test_a_resumed_log_continues_the_saved_events_on_a_new_instance() -> void:
	# Arrange
	_start()
	var old_log: EventLog = _run.run_log
	var saved_events: int = (_h.meta.load_active_run().run_log.events as Array).size()

	# Act
	var run: RunMachine = _relaunch()

	# Assert
	assert_object(run.run_log).is_not_same(old_log)
	assert_int(int(RunHarness.events_of(run.run_log, RunCodes.EVENT_RUN_RESUMED)[0].seq)).is_equal(saved_events + 1)


func test_a_resumed_run_keeps_the_layout_it_started_with() -> void:
	# Arrange: the data moved to a 4-floor run while it was saved
	_start()

	# Act
	var run: RunMachine = _relaunch({"floors_per_run": 4, "band_split": [2, 1, 1]})

	# Assert
	assert_int(run.state.floors_per_run).is_equal(TestConstants.FLOORS_PER_RUN)
	assert_array(Array(run.state.band_split)).is_equal(Array(TestConstants.BAND_SPLIT))


func test_a_run_already_archived_is_dropped_from_the_slot_and_not_played_on() -> void:
	# Arrange: the crash between archive_run and clear_active_run
	_start()
	var meta := ArchivedMeta.new(_h.db, _h)
	meta.set_slot(_h.meta.load_active_run())
	var run := RunHarness.SpyMachine.new(_h.db, meta, _h.draft, _h.treasures, RunHarness.run_config(), Callable())

	# Act
	var answer: Error = run.resume()

	# Assert
	assert_int(answer).is_equal(RunCodes.E_NO_SAVE)
	assert_object(meta.load_active_run()).is_null()
	assert_array(_h.archived).is_empty()


## A Meta that already holds every run in its log.
class ArchivedMeta:
	extends RunHarness.StubMeta

	func run_log_entry(run_id: String) -> Variant:
		return {"run_id": run_id}
