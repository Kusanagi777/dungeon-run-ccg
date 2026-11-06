## Run Structure R3-R6, T1-T21: the commands and the phases (design/gdd/run-structure.md
## AC-9 to AC-16, AC-33 to AC-35).
extends GdUnitTestSuite

const HERO: String = RunHarness.HERO_ID
const SEED: String = "42"
const TREASURE: StringName = &"treasure"
const BUNDLE: StringName = &"bundle"
const K_TREASURE: String = DraftRecord.KIND_TREASURE
const K_BUNDLE: String = DraftRecord.KIND_BUNDLE
const STATE_WITH_T1: Dictionary = {"schema_version": 1, "by_treasure": {"t1": {"n": 1}}}
const FLOOR_TWO: int = 2
const TREASURE_FLOOR: int = 3
const AFTER_TREASURE_FLOOR: int = 4
const FLOOR_FIVE: int = 5
const LAST_FLOOR: int = TestConstants.FLOORS_PER_RUN
const DECK_AT_FLOOR_4: int = 24
const DECK_AT_FLOOR_3: int = 21

var _h: RunHarness = null
var _run: RunMachine = null


func before_test() -> void:
	_h = RunHarness.new()
	_run = _h.machine()
	assert_int(_run.new_run(HERO, SEED)).is_equal(OK)


func after_test() -> void:
	_h.release()


func _events_after(seq: int) -> Array:
	return Array(_run.run_log.events_since(seq))


func _last_seq() -> int:
	return int(_run.run_log.events_since(0).back().seq)


func _seq_of(type: StringName) -> int:
	return int(RunHarness.events_of(_run.run_log, type).back().seq)


func _begin() -> MatchDriver:
	return _h.begin(_run)


# --- AC-9 --------------------------------------------------------------------

func test_begin_match_builds_the_floor_one_config() -> void:
	# Act
	var _driver: MatchDriver = _begin()

	# Assert
	var config: Dictionary = _h.configs[0]
	assert_int(int(config.floor)).is_equal(1)
	assert_array(config.player.deck).is_equal(Array(RunHarness.starter_deck()))
	assert_array(config.player.hook_installers).is_empty()
	assert_str(config.boss.boss_def_id).is_equal(_run.state.boss_sequence[0])
	assert_object(config.rng_match).is_same(_run.rng.stream("match_1"))
	assert_object(config.rng_ai).is_same(_run.rng.stream("ai_1"))
	assert_int(_run.state.attempts_on(1)).is_equal(1)
	assert_str(_run.phase()).is_equal(RunState.STATUS_IN_MATCH)


func test_begin_match_hands_a_copy_of_the_deck() -> void:
	# Arrange
	var _driver: MatchDriver = _begin()

	# Act
	(_h.configs[0].player.deck as Array).clear()

	# Assert
	assert_int(_run.state.deck.size()).is_equal(TestConstants.STARTER_DECK_SIZE)


func test_begin_match_outside_pre_match_is_e_bad_phase() -> void:
	# Arrange
	var _driver: MatchDriver = _begin()

	# Act
	var second: MatchDriver = _run.begin_match()

	# Assert
	assert_object(second).is_null()
	assert_int(_run.last_error).is_equal(RunCodes.E_BAD_PHASE)
	assert_int(_run.state.attempts_on(1)).is_equal(1)


# --- AC-10 -------------------------------------------------------------------

func test_win_on_a_plain_floor_goes_to_the_bundle_step_and_saves_after_the_summary() -> void:
	# Arrange
	_h.advance_to(_run, FLOOR_TWO)
	var _driver: MatchDriver = _begin()

	# Act
	_h.finish_win(_run)

	# Assert
	assert_str(_run.phase()).is_equal(RunState.STATUS_POST_MATCH_REWARD)
	assert_str(str(_run.state.reward_step)).is_equal(K_BUNDLE)
	var summary: Dictionary = _run.state.match_summaries.back()
	assert_str(summary.boss_id).is_equal(_run.state.boss_sequence[1])
	assert_int(int(summary.band)).is_equal(1)
	assert_int(int(summary.attempt)).is_equal(1)
	var saved: Dictionary = RunHarness.events_of(_run.run_log, RunCodes.EVENT_RUN_SAVED).back()
	assert_dict(saved.payload).is_equal({"floor": FLOOR_TWO, "phase": RunState.STATUS_POST_MATCH_REWARD})
	assert_int(int(saved.seq)).is_greater(_seq_of(RunCodes.EVENT_MATCH_SUMMARY))


func test_summary_is_the_r10_row() -> void:
	# Arrange
	var _driver: MatchDriver = _begin()
	_h.ticks = 4500

	# Act
	_h.finish_win(_run, 7, {"card_x": 5})

	# Assert
	var summary: Dictionary = _run.state.match_summaries[0]
	assert_int(int(summary.floor)).is_equal(1)
	assert_str(summary.result).is_equal(MatchRecords.RESULT_WIN)
	assert_str(summary.reason).is_equal(MatchRecords.REASON_HERO_DEAD)
	assert_int(int(summary.turns)).is_equal(7)
	assert_int(int(summary.duration_s)).is_equal(4)
	assert_dict(summary.damage_by_card).is_equal({"card_x": 5})
	assert_bool(summary.has("cards_played")).is_true()


# --- AC-11 -------------------------------------------------------------------

func test_win_on_a_treasure_floor_asks_for_the_treasure_first() -> void:
	# Arrange
	_h.advance_to(_run, TREASURE_FLOOR)
	var _driver: MatchDriver = _begin()

	# Act
	_h.finish_win(_run)

	# Assert
	assert_str(str(_run.state.reward_step)).is_equal(K_TREASURE)


func test_treasure_pick_records_grants_and_moves_to_the_bundle() -> void:
	# Arrange
	_h.advance_to(_run, TREASURE_FLOOR)
	var _driver: MatchDriver = _begin()
	_h.finish_win(_run)
	var id: String = _h.offered(_run)[1]
	var held: Array = Array(_run.state.treasures).duplicate()
	var picks_before: int = _h.draft.calls_of("pick").size()
	var saves_before: int = _h.save_attempts.size()

	# Act
	var answer: Error = _run.draft_pick(TREASURE, id)

	# Assert
	assert_int(answer).is_equal(OK)
	var pick_calls: Array = _h.draft.calls_of("pick").slice(picks_before)
	assert_int(pick_calls.size()).is_equal(1)
	assert_str(pick_calls[0].kind).is_equal(K_TREASURE)
	assert_str(str(pick_calls[0].id)).is_equal(id)
	assert_object(pick_calls[0].state).is_same(_run.state)
	assert_array(Array(_run.state.treasures)).is_equal(held + [id])
	assert_int(_seq_of(RunCodes.EVENT_TREASURE_GRANTED)).is_greater(RunHarness.events_of(_run.run_log, RunCodes.EVENT_DRAFT_PICKED).filter(func(e: Dictionary) -> bool: return e.payload.kind == K_TREASURE).back().seq)
	assert_str(str(_run.state.reward_step)).is_equal(K_BUNDLE)
	assert_int(_h.save_attempts.size()).is_equal(saves_before + 1)
	assert_str(str(_h.save_attempts.back().reward_step)).is_equal(K_BUNDLE)


func test_bundle_pick_grows_the_deck_and_enters_the_next_floor() -> void:
	# Arrange
	_h.advance_to(_run, TREASURE_FLOOR)
	var _driver: MatchDriver = _begin()
	_h.finish_win(_run)
	assert_int(_run.draft_pick(TREASURE, _h.offered(_run)[0])).is_equal(OK)
	var id: String = _h.offered(_run)[2]

	# Act
	var answer: Error = _run.draft_pick(BUNDLE, id)

	# Assert
	assert_int(answer).is_equal(OK)
	assert_int(_run.state.deck.size()).is_equal(DECK_AT_FLOOR_4)
	assert_array(Array(_run.state.deck.slice(DECK_AT_FLOOR_3))).is_equal(RunHarness.bundle_cards(id))
	assert_int(int(RunHarness.events_of(_run.run_log, RunCodes.EVENT_DECK_GREW).back().payload.deck_size)).is_equal(DECK_AT_FLOOR_4)
	assert_int(_run.state.floor).is_equal(AFTER_TREASURE_FLOOR)
	assert_str(_run.phase()).is_equal(RunState.STATUS_PRE_MATCH)
	assert_object(_run.state.reward_step).is_null()
	var entered: Dictionary = RunHarness.events_of(_run.run_log, RunCodes.EVENT_FLOOR_ENTERED).back().payload
	assert_int(int(entered.floor)).is_equal(AFTER_TREASURE_FLOOR)
	assert_int(int(entered.band)).is_equal(2)


# --- AC-12 and the rest of the draft guards ----------------------------------

func _at_treasure_step() -> void:
	var _driver: MatchDriver = _begin()
	_h.finish_win(_run)


func test_wrong_kind_is_e_draft_kind_with_no_change_and_no_event() -> void:
	# Arrange: floor 1 is a treasure floor
	_at_treasure_step()
	var seq: int = _last_seq()
	var before: Dictionary = RunRecord.to_dict(_run.state)

	# Act
	var answer: Error = _run.draft_pick(BUNDLE, _h.offered(_run)[0])

	# Assert
	assert_int(answer).is_equal(RunCodes.E_DRAFT_KIND)
	assert_array(_events_after(seq)).is_empty()
	assert_str(JSON.stringify(RunRecord.to_dict(_run.state))).is_equal(JSON.stringify(before))


func test_an_id_not_offered_is_e_not_offered_and_the_offer_stays_open() -> void:
	# Arrange
	_at_treasure_step()
	var offered: Array = _h.offered(_run)
	var outsider: String = RunHarness.pool_ids(K_TREASURE).filter(func(id: String) -> bool: return not offered.has(id))[0]

	# Act
	var answer: Error = _run.draft_pick(TREASURE, outsider)

	# Assert
	assert_int(answer).is_equal(RunCodes.E_NOT_OFFERED)
	assert_array(_h.offered(_run)).is_equal(offered)
	assert_int(_run.draft_pick(TREASURE, offered[0])).is_equal(OK)


func test_draft_pick_outside_the_reward_phase_is_e_bad_phase() -> void:
	# Act
	var answer: Error = _run.draft_pick(BUNDLE, "b1")

	# Assert
	assert_int(answer).is_equal(RunCodes.E_BAD_PHASE)


func test_a_second_treasure_pick_on_the_floor_is_e_draft_done() -> void:
	# Arrange
	_at_treasure_step()
	var id: String = _h.offered(_run)[0]
	assert_int(_run.draft_pick(TREASURE, id)).is_equal(OK)

	# Act
	var answer: Error = _run.draft_pick(TREASURE, id)

	# Assert
	assert_int(answer).is_equal(RunCodes.E_DRAFT_DONE)
	assert_array(Array(_run.state.treasures)).is_equal([id])


# --- AC-13: victory ----------------------------------------------------------

func _played_to_victory() -> void:
	_h.advance_to(_run, LAST_FLOOR)
	var _driver: MatchDriver = _begin()
	_h.finish_win(_run)


func test_win_on_the_last_floor_is_victory() -> void:
	# Act
	_played_to_victory()

	# Assert
	assert_str(_run.phase()).is_equal(RunState.STATUS_VICTORY)
	assert_int(int(_run.state.result.floors_cleared)).is_equal(LAST_FLOOR)
	assert_int(int(_run.state.result.floor_reached)).is_equal(LAST_FLOOR)
	assert_object(_run.state.result.ended_by).is_null()
	assert_str(RunHarness.event_types(_run.run_log).back()).is_equal(String(RunCodes.EVENT_RUN_ENDED))
	assert_str(str(RunHarness.events_of(_run.run_log, RunCodes.EVENT_RUN_ENDED)[0].payload.result)).is_equal(RunState.STATUS_VICTORY)


func test_victory_archives_once_with_the_36_card_deck_then_clears() -> void:
	# Act
	_played_to_victory()

	# Assert
	assert_int(_h.archived.size()).is_equal(1)
	assert_int((_h.archived[0].deck as Array).size()).is_equal(36)
	assert_int(_h.trace.count("clear_active_run")).is_equal(1)
	assert_int(_h.trace.rfind("clear_active_run")).is_greater(_h.trace.rfind("archive_run"))
	assert_object(_h.meta.load_active_run()).is_null()


func test_no_draft_follows_the_last_floor() -> void:
	# Act
	_played_to_victory()

	# Assert
	assert_object(_run.current_offer()).is_null()
	assert_array(Array(_run.state.drafts).filter(func(r: DraftRecord) -> bool: return r.floor == LAST_FLOOR)).is_empty()


# --- AC-14: defeat -----------------------------------------------------------

func test_loss_on_floor_one_is_a_normal_defeat() -> void:
	# Arrange
	var _driver: MatchDriver = _begin()

	# Act
	_h.finish_loss(_run)

	# Assert
	assert_str(_run.phase()).is_equal(RunState.STATUS_DEFEAT)
	assert_int(int(_run.state.result.floors_cleared)).is_equal(0)
	assert_int(int(_run.state.result.floor_reached)).is_equal(1)
	assert_str(str(_run.state.result.ended_by)).is_equal(_run.state.boss_sequence[0])
	assert_int(int(_run.state.totals.matches_played)).is_equal(1)
	assert_int(_h.archived.size()).is_equal(1)
	assert_str(_h.archived[0].status).is_equal(RunState.STATUS_DEFEAT)


func test_concede_is_a_defeat_with_its_reason_kept() -> void:
	# Arrange
	var _driver: MatchDriver = _begin()

	# Act
	_h.finish_loss(_run, MatchRecords.REASON_CONCEDE)

	# Assert
	assert_str(_run.phase()).is_equal(RunState.STATUS_DEFEAT)
	assert_object(_run.state.result.abandon_reason).is_null()
	assert_str(_run.state.match_summaries[0].reason).is_equal(MatchRecords.REASON_CONCEDE)


func test_turn_cap_defeat_also_warns() -> void:
	# Arrange
	var _driver: MatchDriver = _begin()
	var log: EventLog = _run.run_log

	# Act
	_h.finish_loss(_run, MatchRecords.REASON_TURN_CAP)

	# Assert
	assert_str(_run.phase()).is_equal(RunState.STATUS_DEFEAT)
	assert_int(RunHarness.warnings_of(log, RunCodes.W_TURN_CAP).size()).is_equal(1)


# --- AC-15: fault ------------------------------------------------------------

func test_fault_returns_to_pre_match_on_the_same_floor_with_no_summary() -> void:
	# Arrange
	var _driver: MatchDriver = _begin()

	# Act
	_h.finish_fault(_run)

	# Assert
	assert_str(_run.phase()).is_equal(RunState.STATUS_PRE_MATCH)
	assert_int(_run.state.floor).is_equal(1)
	assert_dict(RunHarness.events_of(_run.run_log, RunCodes.EVENT_MATCH_FAULTED)[0].payload).is_equal({"floor": 1, "attempt": 1})
	assert_array(Array(_run.state.match_summaries)).is_empty()
	assert_int(_run.state.attempts_on(1)).is_equal(1)


func test_retry_after_a_fault_is_attempt_two_on_rewound_streams() -> void:
	# Arrange
	var _driver: MatchDriver = _begin()
	var stream: RngStream = _h.configs[0].rng_match
	var first_draw: int = stream.randi32()
	_h.finish_fault(_run)

	# Act
	var _retry: MatchDriver = _begin()

	# Assert
	var retried: RngStream = _h.configs[1].rng_match
	assert_int(_run.state.attempts_on(1)).is_equal(2)
	assert_int(retried.draws).is_equal(0)
	assert_int(retried.randi32()).is_equal(first_draw)


# --- AC-16, AC-34: abandon ---------------------------------------------------

func test_abandon_from_pre_match_credits_the_floors_behind() -> void:
	# Arrange
	_h.advance_to(_run, FLOOR_FIVE)

	# Act
	var answer: Error = _run.abandon()

	# Assert
	assert_int(answer).is_equal(OK)
	assert_str(_run.phase()).is_equal(RunState.STATUS_ABANDONED)
	assert_str(str(_run.state.result.abandon_reason)).is_equal(RunState.REASON_PLAYER)
	assert_int(int(_run.state.result.floors_cleared)).is_equal(FLOOR_FIVE - 1)
	assert_int(int(_run.state.result.floor_reached)).is_equal(FLOOR_FIVE)
	assert_object(_run.state.result.ended_by).is_null()
	assert_int(_h.archived.size()).is_equal(1)


func test_abandon_in_a_match_is_e_bad_phase() -> void:
	# Arrange
	var _driver: MatchDriver = _begin()

	# Act
	var answer: Error = _run.abandon()

	# Assert
	assert_int(answer).is_equal(RunCodes.E_BAD_PHASE)
	assert_str(_run.phase()).is_equal(RunState.STATUS_IN_MATCH)
	assert_array(_h.archived).is_empty()


func test_abandon_from_the_reward_phase_credits_the_won_floor() -> void:
	# Arrange: floor 4 is won, its bundle undrafted
	_h.advance_to(_run, AFTER_TREASURE_FLOOR)
	var _driver: MatchDriver = _begin()
	_h.finish_win(_run)

	# Act
	assert_int(_run.abandon()).is_equal(OK)

	# Assert
	assert_int(int(_run.state.result.floors_cleared)).is_equal(AFTER_TREASURE_FLOOR)
	assert_int(int(_run.state.result.floor_reached)).is_equal(AFTER_TREASURE_FLOOR + 1)
	assert_object(_run.state.result.ended_by).is_null()


func test_abandon_from_pre_match_on_floor_four_is_three_and_four() -> void:
	# Arrange
	_h.advance_to(_run, AFTER_TREASURE_FLOOR)

	# Act
	assert_int(_run.abandon()).is_equal(OK)

	# Assert
	assert_int(int(_run.state.result.floors_cleared)).is_equal(AFTER_TREASURE_FLOOR - 1)
	assert_int(int(_run.state.result.floor_reached)).is_equal(AFTER_TREASURE_FLOOR)


# --- AC-33: an empty offer skips the step ------------------------------------

func _won_on_treasure_floor_with_empty(kinds: Array[String]) -> void:
	_h.advance_to(_run, TREASURE_FLOOR)
	_h.draft.empty_kinds = kinds
	var _driver: MatchDriver = _begin()
	_h.finish_win(_run)


func test_empty_treasure_offer_records_the_skip_and_moves_to_the_bundle() -> void:
	# Arrange
	_h.advance_to(_run, TREASURE_FLOOR)
	var grants_before: int = RunHarness.events_of(_run.run_log, RunCodes.EVENT_TREASURE_GRANTED).size()
	_h.draft.empty_kinds = [K_TREASURE]
	var _driver: MatchDriver = _begin()
	var saves_before: int = _h.save_attempts.size()

	# Act
	_h.finish_win(_run)

	# Assert
	var record: DraftRecord = _run.state.drafts.back()
	assert_dict(record.to_dict()).is_equal({"floor": TREASURE_FLOOR, "kind": K_TREASURE, "offered_ids": [], "picked_id": null, "card_ids_added": []})
	assert_int(RunHarness.events_of(_run.run_log, RunCodes.EVENT_TREASURE_GRANTED).size()).is_equal(grants_before)
	assert_str(str(_run.state.reward_step)).is_equal(K_BUNDLE)
	# S2, then S3 for the skip
	assert_int(_h.save_attempts.size()).is_equal(saves_before + 2)
	assert_int((_h.save_attempts.back().drafts as Array).size()).is_equal(_run.state.drafts.size())


func test_a_pick_for_a_skipped_step_is_e_draft_done() -> void:
	# Arrange
	_won_on_treasure_floor_with_empty([K_TREASURE])

	# Act
	var answer: Error = _run.draft_pick(TREASURE, "t1")

	# Assert
	assert_int(answer).is_equal(RunCodes.E_DRAFT_DONE)


func test_both_steps_empty_advances_with_no_deck_growth_and_a_valid_record() -> void:
	# Arrange
	_h.advance_to(_run, TREASURE_FLOOR)
	var grew_before: int = RunHarness.events_of(_run.run_log, RunCodes.EVENT_DECK_GREW).size()
	_h.draft.empty_kinds = [K_TREASURE, K_BUNDLE]
	var _driver: MatchDriver = _begin()

	# Act
	_h.finish_win(_run)

	# Assert
	assert_int(_run.state.floor).is_equal(AFTER_TREASURE_FLOOR)
	assert_str(_run.phase()).is_equal(RunState.STATUS_PRE_MATCH)
	assert_int(RunHarness.events_of(_run.run_log, RunCodes.EVENT_DECK_GREW).size()).is_equal(grew_before)
	assert_int(_run.state.deck.size()).is_equal(DECK_AT_FLOOR_3)
	assert_int(RunRecord.validate(_h.meta.load_active_run(), _h.db)).is_equal(OK)


# --- AC-35 -------------------------------------------------------------------

func test_collect_state_runs_once_before_the_s2_save_and_lands_in_it() -> void:
	# Arrange
	_h.advance_to(_run, FLOOR_TWO)
	_h.treasures.state_to_collect = STATE_WITH_T1
	var driver: MatchDriver = _begin()
	var calls_before: int = _h.treasures.collect_calls.size()
	var mark: int = _h.trace.size()

	# Act
	_h.finish_win(_run)

	# Assert
	var calls: Array = _h.treasures.collect_calls.slice(calls_before)
	assert_int(calls.size()).is_equal(1)
	assert_object(calls[0].hooks).is_same(driver.hooks())
	assert_str(calls[0].result.winner).is_equal(MatchRecords.SIDE_PLAYER)
	var tail: Array[String] = _h.trace.slice(mark)
	assert_int(tail.find("collect_state")).is_less(tail.find("save_active_run"))
	assert_dict(_h.meta.load_active_run().treasure_state).is_equal(STATE_WITH_T1)


func test_collect_state_also_runs_on_a_defeat_before_the_archive() -> void:
	# Arrange
	_h.treasures.state_to_collect = STATE_WITH_T1
	var _driver: MatchDriver = _begin()

	# Act
	_h.finish_loss(_run)

	# Assert
	assert_dict(_h.archived[0].treasure_state).is_equal(STATE_WITH_T1)


func test_collect_state_is_not_called_on_a_fault() -> void:
	# Arrange
	var _driver: MatchDriver = _begin()

	# Act
	_h.finish_fault(_run)

	# Assert
	assert_array(_h.treasures.collect_calls).is_empty()


# --- Transition table --------------------------------------------------------

func test_every_command_outside_its_phases_is_e_bad_phase() -> void:
	# Arrange: in_match refuses them all
	var _driver: MatchDriver = _begin()

	# Act
	var answers: Array = [_run.new_run(HERO, ""), _run.draft_pick(BUNDLE, "b1"), _run.resume(), _run.suspend(), _run.return_to_menu(), _run.abandon()]

	# Assert
	for answer: Error in answers:
		assert_int(answer).is_equal(RunCodes.E_BAD_PHASE)


func test_run_again_starts_a_new_run_from_a_defeat() -> void:
	# Arrange
	var _driver: MatchDriver = _begin()
	_h.finish_loss(_run)

	# Act
	var answer: Error = _run.new_run(HERO, "")

	# Assert
	assert_int(answer).is_equal(OK)
	assert_str(_run.phase()).is_equal(RunState.STATUS_PRE_MATCH)
	assert_int(_run.state.floor).is_equal(1)
	assert_str(_run.state.seed_source).is_equal(RunState.SEED_RANDOM)


func test_return_to_menu_leaves_no_run() -> void:
	# Arrange
	var _driver: MatchDriver = _begin()
	_h.finish_loss(_run)

	# Act
	var answer: Error = _run.return_to_menu()

	# Assert
	assert_int(answer).is_equal(OK)
	assert_object(_run.state).is_null()
	assert_str(_run.phase()).is_equal(RunMachine.PHASE_MENU)


func test_new_run_over_a_saved_run_ends_it_as_abandoned_by_the_player() -> void:
	# Arrange: a new launch at Menu, the old run on floor 2 in the slot
	_h.advance_to(_run, FLOOR_TWO)
	var old_id: String = _run.state.run_id
	var fresh: RunMachine = _h.machine()
	fresh.unix_clock = func() -> int: return 2000

	# Act
	var answer: Error = fresh.new_run(HERO, "43")

	# Assert
	assert_int(answer).is_equal(OK)
	assert_int(_h.archived.size()).is_equal(1)
	assert_str(_h.archived[0].run_id).is_equal(old_id)
	assert_str(_h.archived[0].result.outcome).is_equal(RunState.STATUS_ABANDONED)
	assert_str(_h.archived[0].result.abandon_reason).is_equal(RunState.REASON_PLAYER)
	assert_int(int(_h.archived[0].result.floors_cleared)).is_equal(1)
	assert_str(str(_h.meta.load_active_run().run_id)).is_equal(fresh.state.run_id)


func test_play_seconds_counts_only_matches_and_drafts() -> void:
	# Arrange: 3 s in the match, 2 s in the two drafts
	var _driver: MatchDriver = _begin()
	_h.ticks = 3000
	_h.finish_win(_run)
	_h.ticks = 4000
	assert_int(_run.draft_pick(TREASURE, _h.offered(_run)[0])).is_equal(OK)
	_h.ticks = 5000
	assert_int(_run.draft_pick(BUNDLE, _h.offered(_run)[0])).is_equal(OK)

	# Act: 50 s at the boss intro do not count
	_h.ticks = 55000
	assert_int(_run.abandon()).is_equal(OK)

	# Assert
	assert_int(_run.state.play_seconds).is_equal(5)
	assert_int(int(_run.state.totals.play_seconds)).is_equal(5)
