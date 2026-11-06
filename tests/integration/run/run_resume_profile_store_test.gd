## Integration: resume against the real persistence stack (design/gdd/run-structure.md
## R7, R8, AC-17 to AC-21; meta-progression M1, M7, M8; ADR-0004). A real `MetaFacade`
## over a real `ProfileStore` in a scratch folder. A "launch" is a new store reading
## `profile.json` from disk, so numbers come back as floats and keys as strings.
extends GdUnitTestSuite

const ROOT: String = "user://tmp/run_resume_store/"
const HERO: String = RunRealFixture.HERO_ID
const SEED: String = "42"
## Above 2^53: a JSON number could not carry it, so only the hex may.
const WIDE_SEED: String = "F123456789ABCDEF"
const FLOOR_TWO: int = 2
const NO_LOSSES: int = 0


## A writer whose every write fails from W2 on.
class FailingWriter:
	extends AtomicFileWriter

	var failing: bool = false

	func _fails_at(step: String) -> bool:
		return failing and step == "W8"


var _db: CardDatabase = null
var _game: RunRealFixture = null
var _facades: Array[MetaFacade] = []


func before() -> void:
	_db = TreasureFixtures.shipped_database()


func after() -> void:
	_db = null


func before_test() -> void:
	_wipe()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))
	_game = RunRealFixture.new(_db)
	_game.boss_health = RunRealFixture.ONE_BLOW


func after_test() -> void:
	_game.release()
	_close()
	_wipe()


func _wipe() -> void:
	var path: String = ProjectSettings.globalize_path(ROOT)
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	for file: String in dir.get_files():
		@warning_ignore("return_value_discarded")
		dir.remove(file)
	var runs: DirAccess = DirAccess.open(path.path_join("runs"))
	if runs != null:
		for file: String in runs.get_files():
			@warning_ignore("return_value_discarded")
			runs.remove(file)
		@warning_ignore("return_value_discarded")
		dir.remove("runs")


func _close() -> void:
	for facade: MetaFacade in _facades:
		facade.store().release_lock()
	_facades.clear()


## The next launch: the last process is gone, the profile is read from disk.
func _launch(writer: AtomicFileWriter = null) -> MetaFacade:
	_close()
	var facade: MetaFacade = RunRealFixture.facade(_db, ROOT, writer)
	_facades.append(facade)
	var loaded: Dictionary = facade.load_profile()
	assert_bool(loaded.has("status")).is_true()
	return facade


func _started(seed_input: String = SEED) -> RunMachine:
	var run: RunMachine = _game.machine(_launch())
	assert_int(run.new_run(HERO, seed_input)).is_equal(OK)
	return run


## A new launch over the saved file, resumed.
func _relaunched(expected: Error = OK) -> RunMachine:
	var run: RunMachine = _game.machine(_launch())
	assert_int(run.resume()).is_equal(expected)
	return run


## Saves [param edit] of the slot's record as the file, then launches again.
func _edit_save(edit: Callable) -> void:
	var meta: MetaFacade = _launch()
	var record: Dictionary = meta.load_active_run()
	edit.call(record)
	assert_int(meta.save_active_run(record)).is_equal(OK)


func _win(run: RunMachine) -> void:
	_game.play_out(run, _game.begin(run))


# --- The shape a load gives back ---------------------------------------------

func test_the_file_holds_floats_and_string_keys_and_they_validate() -> void:
	# Arrange: the record as JSON gives it, before the store's own normalising
	var run: RunMachine = _started()
	var _driver: MatchDriver = _game.begin(run)

	# Act
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT.path_join("profile.json")))
	var raw: Dictionary = parsed.active_run

	# Assert: what this suite exists for
	assert_int(typeof(raw.floor)).is_equal(TYPE_FLOAT)
	assert_int(typeof(raw.band_split[0])).is_equal(TYPE_FLOAT)
	assert_int(typeof(raw.match_attempts["1"])).is_equal(TYPE_FLOAT)
	assert_int(typeof(raw.draft_state.schema_version)).is_equal(TYPE_FLOAT)
	assert_int(RunRecord.validate(raw, _db)).is_equal(OK)
	assert_int(RunRecord.from_dict(raw).attempts_on(1)).is_equal(1)


func test_the_store_hands_back_string_keys_and_whole_numbers() -> void:
	# Arrange
	var run: RunMachine = _started()
	var _driver: MatchDriver = _game.begin(run)

	# Act: ProfileSchema.normalised has run over the parsed file
	var loaded: Dictionary = _launch().load_active_run()

	# Assert
	assert_int(typeof(loaded.floor)).is_equal(TYPE_INT)
	assert_array(loaded.match_attempts.keys()).is_equal(["1"])


func test_a_loaded_record_validates() -> void:
	# Arrange
	var run: RunMachine = _started()
	_win(run)

	# Act
	var answer: Error = RunRecord.validate(_launch().load_active_run(), _db)

	# Assert
	assert_int(answer).is_equal(OK)


func test_from_dict_coerces_a_loaded_record_to_the_live_shape() -> void:
	# Arrange
	var run: RunMachine = _started()
	_win(run)
	var live: String = JSON.stringify(RunRecord.to_dict(run.state))
	var loaded: Dictionary = _launch().load_active_run()

	# Act
	var state: RunState = RunRecord.from_dict(loaded)

	# Assert
	assert_int(state.attempts_on(1)).is_equal(1)
	assert_int(state.run_seed).is_equal(run.state.run_seed)
	assert_str(JSON.stringify(RunRecord.to_dict(state))).is_equal(live)


func test_a_seed_past_two_to_the_53_survives_the_file() -> void:
	# Arrange
	var run: RunMachine = _started(WIDE_SEED)
	var expected: int = run.state.run_seed

	# Act
	var resumed: RunMachine = _relaunched()

	# Assert
	assert_int(resumed.state.run_seed).is_equal(expected)
	assert_str(resumed.state.run_seed_hex).is_equal(WIDE_SEED)


# --- R8.2 --------------------------------------------------------------------

func test_a_resume_at_s1_re_enters_the_boss_intro() -> void:
	# Arrange
	var run: RunMachine = _started()
	var sequence: Array = Array(run.state.boss_sequence).duplicate()

	# Act
	var resumed: RunMachine = _relaunched()

	# Assert
	assert_str(resumed.phase()).is_equal(RunState.STATUS_PRE_MATCH)
	assert_array(Array(resumed.state.boss_sequence)).is_equal(sequence)
	assert_int(RunHarness.events_of(resumed.run_log, RunCodes.EVENT_RUN_RESUMED).size()).is_equal(1)


func test_a_resume_at_s2_regenerates_the_treasure_offer() -> void:
	# Arrange
	var run: RunMachine = _started()
	_win(run)
	var before: Array = (run.current_offer().option_ids as Array).duplicate()
	var flags: Array = (run.current_offer().flags as Array).duplicate()

	# Act
	var resumed: RunMachine = _relaunched()

	# Assert
	assert_array(resumed.current_offer().option_ids).is_equal(before)
	assert_array(resumed.current_offer().flags).is_equal(flags)


func test_a_resume_at_s3_regenerates_the_bundle_offer() -> void:
	# Arrange
	var run: RunMachine = _started()
	_win(run)
	var taken: String = run.current_offer().option_ids[0]
	assert_int(run.draft_pick(&"treasure", taken)).is_equal(OK)
	var before: Array = (run.current_offer().option_ids as Array).duplicate()

	# Act
	var resumed: RunMachine = _relaunched()

	# Assert
	assert_str(str(resumed.state.reward_step)).is_equal(DraftRecord.KIND_BUNDLE)
	assert_array(resumed.current_offer().option_ids).is_equal(before)
	assert_array(Array(resumed.state.treasures)).is_equal([taken])
	assert_int(resumed.draft_pick(&"treasure", taken)).is_equal(RunCodes.E_DRAFT_DONE)


func test_a_quit_mid_match_restarts_it_as_attempt_two_with_the_same_deal() -> void:
	# Arrange
	var run: RunMachine = _started()
	_game.play_floor(run)
	var first: MatchDriver = _game.begin(run)
	var first_hand: Array = first.query().snapshot(MatchRecords.SIDE_PLAYER).hand.map(func(id: int) -> String: return first.query().entity(id).get("card_id", ""))

	# Act: no save on the way out
	var resumed: RunMachine = _relaunched()
	var second: MatchDriver = _game.begin(resumed)

	# Assert
	var second_hand: Array = second.query().snapshot(MatchRecords.SIDE_PLAYER).hand.map(func(id: int) -> String: return second.query().entity(id).get("card_id", ""))
	assert_int(resumed.state.attempts_on(FLOOR_TWO)).is_equal(2)
	assert_str(str(resumed.state.match_attempts.keys()[0])).is_equal("1")
	assert_array(second_hand).is_equal(first_hand)
	assert_int(int(RunHarness.events_of(resumed.run_log, RunCodes.EVENT_RUN_RESUMED)[0].payload.attempt)).is_equal(2)


func test_a_resumed_run_plays_on_to_the_same_record_as_one_never_interrupted() -> void:
	# Arrange: the interrupted run
	var interrupted: RunMachine = _started()
	_win(interrupted)
	var resumed: RunMachine = _relaunched()
	_game.take_drafts(resumed)
	_game.play_floor(resumed)
	var deck: Array = Array(resumed.state.deck).duplicate()
	assert_int(resumed.abandon()).is_equal(OK)

	# Act: the same picks, uninterrupted, on a clean profile
	var straight: RunMachine = _started()
	_game.play_floor(straight)
	_game.play_floor(straight)

	# Assert
	assert_array(Array(straight.state.deck)).is_equal(deck)


func test_suspend_then_resume_needs_no_write_and_keeps_the_file() -> void:
	# Arrange
	var run: RunMachine = _started()
	_win(run)
	var path: String = ROOT.path_join("profile.json")
	var before: String = FileAccess.get_file_as_string(path)

	# Act
	assert_int(run.suspend()).is_equal(OK)

	# Assert
	assert_str(FileAccess.get_file_as_string(path)).is_equal(before)


# --- R8.1 through the real store ---------------------------------------------

func test_a_mistyped_schema_version_on_disk_ends_as_save_corrupt_and_not_a_loss() -> void:
	# Arrange
	var run: RunMachine = _started()
	var id: String = run.state.run_id
	_edit_save(func(record: Dictionary) -> void: record["schema_version"] = "1")

	# Act
	var resumed: RunMachine = _relaunched(RunCodes.E_SCHEMA)

	# Assert
	var meta: MetaFacade = _facades.back()
	assert_str(resumed.phase()).is_equal(RunState.STATUS_ABANDONED)
	assert_str(meta.run_log_entry(id).result.abandon_reason).is_equal(RunState.REASON_SAVE_CORRUPT)
	assert_int(int(meta.stats_for_hero(HERO).runs_lost)).is_equal(NO_LOSSES)
	assert_object(meta.load_active_run()).is_null()


func test_a_mistyped_run_seed_hex_on_disk_ends_as_save_corrupt() -> void:
	# Arrange
	var run: RunMachine = _started()
	var id: String = run.state.run_id
	_edit_save(func(record: Dictionary) -> void: record["run_seed_hex"] = 42)

	# Act
	var _resumed: RunMachine = _relaunched(RunCodes.E_SCHEMA)

	# Assert
	assert_str((_facades.back() as MetaFacade).run_log_entry(id).result.abandon_reason).is_equal(RunState.REASON_SAVE_CORRUPT)


func test_a_seed_with_a_sign_on_disk_ends_as_save_corrupt() -> void:
	# Arrange
	var run: RunMachine = _started()
	var id: String = run.state.run_id
	_edit_save(func(record: Dictionary) -> void:
		record["run_seed_hex"] = "-00000000000002A"
		record.rng_snapshot["run_seed_hex"] = "-00000000000002A")

	# Act
	var _resumed: RunMachine = _relaunched(RunCodes.E_CORRUPT)

	# Assert
	assert_str((_facades.back() as MetaFacade).run_log_entry(id).result.abandon_reason).is_equal(RunState.REASON_SAVE_CORRUPT)


func test_another_data_version_on_disk_is_recorded_and_not_counted_as_a_loss() -> void:
	# Arrange
	var run: RunMachine = _started()
	var id: String = run.state.run_id
	_edit_save(func(record: Dictionary) -> void: record["data_version"] = "older")

	# Act
	var _resumed: RunMachine = _relaunched(RunCodes.E_DATA_VERSION)

	# Assert
	var meta: MetaFacade = _facades.back()
	assert_str(meta.run_log_entry(id).result.abandon_reason).is_equal(RunState.REASON_DATA_VERSION_MISMATCH)
	assert_int(int(meta.stats_for_hero(HERO).runs_lost)).is_equal(NO_LOSSES)
	assert_object(_launch().load_active_run()).is_null()


func test_a_shortened_boss_sequence_on_disk_is_archived_without_a_crash() -> void:
	# Arrange
	var run: RunMachine = _started()
	var id: String = run.state.run_id
	_edit_save(func(record: Dictionary) -> void: (record.boss_sequence as Array).pop_back())

	# Act
	var _resumed: RunMachine = _relaunched(RunCodes.E_CORRUPT)

	# Assert
	assert_str((_facades.back() as MetaFacade).run_log_entry(id).result.abandon_reason).is_equal(RunState.REASON_SAVE_CORRUPT)


func test_a_damaged_summary_on_disk_reaches_the_real_archive() -> void:
	# Arrange
	var run: RunMachine = _started()
	_game.play_floor(run)
	var id: String = run.state.run_id
	_edit_save(func(record: Dictionary) -> void: record.match_summaries[0]["damage_by_card"] = "gone")

	# Act
	var _resumed: RunMachine = _relaunched(RunCodes.E_CORRUPT)

	# Assert
	var meta: MetaFacade = _facades.back()
	assert_str(meta.run_log_entry(id).result.abandon_reason).is_equal(RunState.REASON_SAVE_CORRUPT)
	assert_object(meta.load_active_run()).is_null()


# --- Ending, and the slot ----------------------------------------------------

func test_an_abandon_is_archived_as_a_loss_and_empties_the_file() -> void:
	# Arrange
	var run: RunMachine = _started()
	var id: String = run.state.run_id

	# Act
	assert_int(run.abandon()).is_equal(OK)

	# Assert
	var meta: MetaFacade = _launch()
	assert_int(int(meta.stats_for_hero(HERO).runs_lost)).is_equal(1)
	assert_object(meta.run_log_entry(id)).is_not_null()
	assert_object(meta.load_active_run()).is_null()


func test_a_defeat_is_archived_with_the_summary_and_counts_as_a_loss() -> void:
	# Arrange
	var run: RunMachine = _started()
	var id: String = run.state.run_id

	# Act
	_game.concede(run, _game.begin(run))

	# Assert
	var entry: Variant = _launch().run_log_entry(id)
	assert_str(entry.result.outcome).is_equal(RunState.STATUS_DEFEAT)
	assert_int((entry.match_summaries as Array).size()).is_equal(1)


func test_a_new_run_over_a_saved_one_archives_the_old_as_the_players_loss() -> void:
	# Arrange
	var old: RunMachine = _started()
	var old_id: String = old.state.run_id
	var run: RunMachine = _game.machine(_launch())
	run.unix_clock = func() -> int: return int(old.state.started_at) + 1

	# Act
	assert_int(run.new_run(HERO, "43")).is_equal(OK)

	# Assert
	var meta: MetaFacade = _facades.back()
	assert_str(meta.run_log_entry(old_id).result.abandon_reason).is_equal(RunState.REASON_PLAYER)
	assert_str(str(meta.load_active_run().run_id)).is_equal(run.state.run_id)


func test_a_crash_between_archive_and_clear_does_not_play_the_finished_run_on() -> void:
	# Arrange: the slot still holds the last S-save of a run already in the log
	var run: RunMachine = _started()
	var saved: Dictionary = _facades.back().load_active_run()
	assert_int(run.abandon()).is_equal(OK)
	var meta: MetaFacade = _launch()
	assert_int(meta.save_active_run(saved)).is_equal(OK)

	# Act
	var resumed: RunMachine = _game.machine(meta)
	var answer: Error = resumed.resume()

	# Assert
	assert_int(answer).is_equal(RunCodes.E_NO_SAVE)
	assert_object(meta.load_active_run()).is_null()
	assert_int(meta.run_log_count()).is_equal(1)


func test_a_save_the_disk_refuses_warns_and_the_run_goes_on() -> void:
	# Arrange
	var writer := FailingWriter.new()
	var run: RunMachine = _game.machine(_launch(writer))
	assert_int(run.new_run(HERO, SEED)).is_equal(OK)
	var driver: MatchDriver = _game.begin(run)
	writer.failing = true

	# Act
	_game.play_out(run, driver)

	# Assert
	assert_str(run.phase()).is_equal(RunState.STATUS_POST_MATCH_REWARD)
	assert_int(RunHarness.warnings_of(run.run_log, RunCodes.W_SAVE_FAILED).size()).is_equal(1)

	# Act: the disk comes back at the next save point
	writer.failing = false
	_game.take_drafts(run)

	# Assert
	assert_int(int(RunHarness.events_of(run.run_log, RunCodes.EVENT_RUN_SAVED).back().payload.floor)).is_equal(FLOOR_TWO)
	assert_int(int(_relaunched().state.floor)).is_equal(FLOOR_TWO)


func test_the_continue_card_reads_a_loaded_record() -> void:
	# Arrange
	var run: RunMachine = _started()
	_game.play_floor(run)
	var launched: RunMachine = _game.machine(_launch())

	# Act
	var card: Variant = launched.read_model().saved_run

	# Assert
	assert_str(card.hero_id).is_equal(HERO)
	assert_int(typeof(card.floor)).is_equal(TYPE_INT)
	assert_int(int(card.floor)).is_equal(FLOOR_TWO)
	assert_int(int(card.floors_per_run)).is_equal(TestConstants.FLOORS_PER_RUN)
	assert_str(card.phase).is_equal(RunState.STATUS_PRE_MATCH)
