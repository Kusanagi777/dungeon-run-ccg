## Unit tests for `MatchDriver`'s phase schedule: forecast and plan tasks, the stale
## premise, the telegraph setting and the safe end of a boss turn (story
## boss-ai-match-driver/story-014; ADR-0008 Decisions 3, 4, 7 and their DD-X31 erratum;
## ADR-0006; boss-ai C1.4, C8.1, C8.4, A19, Edge Cases; TR-run-structure-005,
## TR-boss-ai-002).
##
## Most tests script [FakePlannerTask]s from a [MatchDriverFixture.TaskFactory], so a
## test decides when a task returns relative to the player's commands. Those whose
## subject is what the planner does run the real `BossAI` through
## [ImmediatePlannerTask] or [TimeSlicedPlannerTask]. No worker starts, and no
## assertion reads the real clock.
extends GdUnitTestSuite

const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const SIDE_BOSS: String = MatchRecords.SIDE_BOSS
const FAULT_EVENT: StringName = &"ai_fault"
const SHOWN_EVENT: StringName = &"ai_intent_shown"
const COMMITTED_EVENT: StringName = &"ai_intent_committed"
const PICKED_EVENT: StringName = &"discover_picked"
const USEC_PER_MSEC: int = 1000
## A hand index no hand reaches: the live engine rejects the command.
const BAD_HAND_INDEX: int = 99
## More ticks than any planned turn here takes: a loop past this is a hang.
const TICK_LIMIT: int = 2000
## Boss cards A19's board plays: its attackers 4 + 3, and a hand it cannot afford, so
## attacks are all the plan holds.
const ATTACKER_4: String = "schedule_attacker_4"
const ATTACKER_3: String = "schedule_attacker_3"
const OUT_OF_REACH: String = "schedule_out_of_reach"
const OUT_OF_REACH_COST: int = 10
## The `boss_overrides` key an A19 test installs.
const OVERRIDE: String = "schedule_override"
const ROUNDS: int = 3


## A clock a test moves by hand.
class FakeClock:
	extends RefCounted

	var now: int = 0

	func read() -> int:
		return now


## A `BossAI` that records each entry point it is asked for, in order.
class SpyBossAI:
	extends BossAI

	var calls: Array[String] = []
	var sandboxes: Array[RulesEngine] = []
	var telegraph: Array[String] = []
	var forecasts: Array[Intent] = []

	func _init(boss_def: Dictionary, profile: Dictionary, band: int, stream: RngStream, op_values: Dictionary, log: Variant, db: Variant, keyword_values: Dictionary) -> void:
		super(boss_def, profile, band, stream, op_values, log, db, keyword_values)

	func plan_task(sandbox: RulesEngine, planner: PlannerTask) -> Callable:
		calls.append("plan_task")
		sandboxes.append(sandbox)
		return super(sandbox, planner)

	func forecast_task(sandbox: RulesEngine, planner: PlannerTask) -> Callable:
		calls.append("forecast_task")
		sandboxes.append(sandbox)
		return super(sandbox, planner)

	func plan_turn(sandbox: RulesEngine, planner: PlannerTask = null) -> TurnPlan:
		calls.append("plan_turn")
		return await super(sandbox, planner)

	func forecast(sandbox: RulesEngine, planner: PlannerTask = null, side: String = MatchRecords.SIDE_BOSS) -> Intent:
		calls.append("forecast")
		return await super(sandbox, planner, side)

	func choose(sandbox: RulesEngine, request: Dictionary, mode: StringName = Scorer.MODE_NORMAL) -> int:
		calls.append("choose")
		return super(sandbox, request, mode)

	func note_forecast(intent: Intent) -> void:
		calls.append("note_forecast")
		forecasts.append(intent)
		super(intent)

	func set_telegraph_mode(mode: String) -> void:
		calls.append("set_telegraph_mode")
		telegraph.append(mode)
		super(mode)


## A driver over a [SpyBossAI].
class SpyDriver:
	extends MatchDriver

	func _init(config: Dictionary, db: CardDatabase, settings: Dictionary, factory: Callable, clock: Callable) -> void:
		super(config, db, settings, factory, clock)

	func _build_boss_ai(boss_def: Dictionary, profile: Dictionary, config: Dictionary, db: CardDatabase, profiles: Dictionary) -> BossAI:
		return SpyBossAI.new(boss_def, profile, int(config.band), config.rng_ai, profiles.op_values, config.log, db, profiles.keyword_values)

	func spy() -> SpyBossAI:
		return _boss_ai


## An engine that refuses every boss `end_turn`, logging nothing.
class StubbornEngine:
	extends RulesEngine

	func submit(command: Dictionary) -> Dictionary:
		if str(command.type) == MatchRecords.CMD_END_TURN and str(command.issuer) == MatchRecords.SIDE_BOSS:
			return MatchRecords.command_result(false, R_NOT_YOUR_TURN, "", -1, -1)
		return super(command)


## A [SpyDriver] over a [StubbornEngine].
class StubbornDriver:
	extends SpyDriver

	func _init(config: Dictionary, db: CardDatabase, settings: Dictionary, factory: Callable, clock: Callable) -> void:
		super(config, db, settings, factory, clock)

	func _build_engine(db: CardDatabase, resolver: EffectResolver) -> RulesEngine:
		return StubbornEngine.new(db, db.config("match_rules"), resolver)


var _db: MatchDriverFixture.FixtureDatabase
var _log: TestEventLog
var _tasks: MatchDriverFixture.TaskFactory
var _clock: FakeClock
var _driver: SpyDriver


func before_test() -> void:
	_db = MatchDriverFixture.database()
	_log = TestEventLog.new()
	_tasks = MatchDriverFixture.TaskFactory.new()
	_clock = FakeClock.new()
	_driver = null


func after_test() -> void:
	if _driver != null:
		_driver.shutdown()
	_driver = null


## A driver on scripted tasks.
func _build(player_deck: Array = [], boss_deck: Array = [], settings: Dictionary = {}) -> SpyDriver:
	return _build_on(_tasks.make, player_deck, boss_deck, settings)


func _build_on(factory: Callable, player_deck: Array = [], boss_deck: Array = [], settings: Dictionary = {}) -> SpyDriver:
	_driver = SpyDriver.new(MatchDriverFixture.match_config(_log, player_deck, boss_deck), _db, settings, factory, _clock.read)
	return _driver


## A driver on the real planner, run to the end inside each `start`.
func _build_real(player_deck: Array = [], boss_deck: Array = [], settings: Dictionary = {}) -> SpyDriver:
	return _build_on(func() -> PlannerTask: return ImmediatePlannerTask.new(), player_deck, boss_deck, settings)


func _intent(mode: String = Intent.MODE_FULL) -> Intent:
	return Intent.new(MatchDriverFixture.BOSS_ID, Intent.KEY_ATTACK_FACE, null, 3, mode)


func _turn() -> int:
	return int(_driver._engine.state().turn)


## Past the mulligan with the turn's forecast returned, so no task is live.
func _at_player_main_idle() -> void:
	MatchDriverFixture.past_mulligan(_driver)
	_tasks.last().scripted_result = _intent()
	_driver.tick()


func _tick_until_idle() -> void:
	for _i: int in TICK_LIMIT:
		if not _driver.is_planning():
			return
		_driver.tick()
	fail("the driver is still planning after %d ticks" % TICK_LIMIT)


func _fault_reasons() -> Array[String]:
	var reasons: Array[String] = []
	for event: Dictionary in _log.of_type(FAULT_EVENT):
		reasons.append(str(event.payload.reason))
	return reasons


func _assert_players_main() -> void:
	assert_str(_driver.query().phase()).is_equal(MatchState.PHASE_MAIN)
	assert_str(String(_driver._engine.active_side())).is_equal(SIDE_PLAYER)


## A boss [constant MatchDriverFixture.RATTLE] and a player's attacker that kills it:
## the attack raises the boss's Discover on the player's turn.
func _boss_rattle_attack() -> Dictionary:
	var rattle: Dictionary = BossAiBoard.place(_driver._engine, _db, SIDE_BOSS, MatchDriverFixture.RATTLE)
	var attacker: Dictionary = BossAiBoard.place(_driver._engine, _db, SIDE_PLAYER, MatchDriverFixture.VANILLA)
	return MatchRecords.attack(SIDE_PLAYER, int(attacker.entity_id), int(rattle.entity_id))


# --- Forecast -------------------------------------------------------------------


func test_no_task_runs_in_the_mulligan_and_one_forecast_starts_after_it() -> void:
	# Arrange: BAI-013 AC-1's other half; match-rules C3 ends setup in `Mulligan`
	_build()
	assert_int(_tasks.made.size()).is_equal(0)
	assert_array(_driver.spy().calls).is_empty()

	# Act
	MatchDriverFixture.past_mulligan(_driver)

	# Assert
	assert_int(_tasks.made.size()).is_equal(1)
	assert_int(_tasks.last().starts).is_equal(1)
	assert_array(_driver.spy().calls).is_equal(["forecast_task"])
	assert_bool(_driver.is_planning()).is_true()


func test_further_player_commands_in_the_turn_start_no_second_forecast() -> void:
	# Arrange
	_build()
	MatchDriverFixture.past_mulligan(_driver)

	# Act: one while the task is live, one after it returned
	assert_bool(_driver.submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0)).accepted).is_true()
	_tasks.last().scripted_result = _intent()
	_driver.tick()
	assert_bool(_driver.submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0)).accepted).is_true()

	# Assert
	assert_int(_tasks.made.size()).is_equal(1)
	assert_bool(_driver.is_planning()).is_false()


func test_a_forecast_works_on_a_clone_never_the_live_engine() -> void:
	# Arrange
	_build()

	# Act
	MatchDriverFixture.past_mulligan(_driver)

	# Assert
	var sandbox: RulesEngine = _driver.spy().sandboxes[0]
	assert_bool(is_same(sandbox, _driver._engine)).is_false()
	assert_bool(is_same(sandbox, _driver._sandbox)).is_true()
	assert_bool(is_same(sandbox.state(), _driver._engine.state())).is_false()


func test_a_forecast_with_its_premise_held_is_noted_and_appended_at_cause_zero() -> void:
	# Arrange
	_build()
	MatchDriverFixture.past_mulligan(_driver)
	var intent: Intent = _intent()
	_tasks.last().scripted_result = intent

	# Act
	_driver.tick()

	# Assert
	assert_int(_log.count(SHOWN_EVENT)).is_equal(1)
	var shown: Dictionary = _log.first(SHOWN_EVENT)
	assert_dict(shown.payload).is_equal(intent.to_dict())
	assert_int(int(shown.cause_seq)).is_equal(0)
	assert_array(_driver.spy().forecasts).is_equal([intent])
	assert_object(_driver._sandbox).is_null()


func test_a_hidden_forecast_is_noted_but_not_appended() -> void:
	# Arrange
	_build()
	MatchDriverFixture.past_mulligan(_driver)
	var intent: Intent = _intent(Intent.MODE_HIDDEN)
	_tasks.last().scripted_result = intent

	# Act
	_driver.tick()

	# Assert
	assert_int(_log.count(SHOWN_EVENT)).is_equal(0)
	assert_array(_driver.spy().forecasts).is_equal([intent])


func test_a_forecast_outlived_by_the_players_turn_is_discarded_silently() -> void:
	# Arrange
	_build()
	MatchDriverFixture.past_mulligan(_driver)
	_tasks.last().scripted_result = _intent()
	assert_bool(_driver.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()
	var events_before: int = _log.size()

	# Act
	_driver.tick()

	# Assert: the plan row fires, and nothing of the forecast reaches the log
	assert_int(_log.size()).is_equal(events_before)
	assert_array(_driver.spy().forecasts).is_empty()
	assert_array(_driver.spy().calls).is_equal(["forecast_task", "plan_task"])


func test_a_forecast_outlived_by_a_change_of_phase_on_the_same_turn_is_discarded() -> void:
	# Arrange: the player's own Discover moves the phase to Choice mid-forecast
	_build(MatchDriverFixture.deck_of(MatchDriverFixture.DISCOVER))
	MatchDriverFixture.past_mulligan(_driver)
	_tasks.last().scripted_result = _intent()
	assert_bool(_driver.submit(MatchRecords.play_card(SIDE_PLAYER, 0)).accepted).is_true()
	assert_str(_driver.query().phase()).is_equal(MatchState.PHASE_CHOICE)

	# Act
	_driver.tick()

	# Assert: a Choice of the player's own is theirs to answer; the driver waits
	assert_int(_log.count(SHOWN_EVENT)).is_equal(0)
	assert_array(_driver.spy().forecasts).is_empty()
	assert_bool(_driver.is_planning()).is_false()


func test_a_boss_main_with_the_same_turn_number_is_a_moved_premise() -> void:
	# Arrange: `PHASE_MAIN` names both sides' Main, so a premise needs the side too
	_build()
	MatchDriverFixture.past_mulligan(_driver)
	var premise: Dictionary = _driver._premise.duplicate()
	var state: MatchState = _driver._engine.state()

	# Act
	state.active_side = SIDE_BOSS
	var moved: bool = _driver._premise_moved(premise)
	state.active_side = SIDE_PLAYER

	# Assert
	assert_bool(moved).is_true()
	assert_bool(_driver._premise_moved(premise)).is_false()


func test_each_player_turn_gets_its_own_forecast() -> void:
	# Arrange
	_build()
	MatchDriverFixture.to_boss_main(_driver)
	_tasks.last().scripted_result = MatchDriverFixture.scripted_plan(_driver, [MatchRecords.end_turn(SIDE_BOSS)])
	var made_before: int = _tasks.made.size()

	# Act: the plan's `end_turn` reaches the player's next Main
	_driver.tick()

	# Assert
	_assert_players_main()
	assert_int(_tasks.made.size()).is_equal(made_before + 1)
	assert_str(_driver.spy().calls.back()).is_equal("forecast_task")
	assert_bool(_driver.is_planning()).is_true()


# --- A19 through the driver -----------------------------------------------------


func _a19_board(settings: Dictionary = {}) -> void:
	_db.records[ATTACKER_4] = CardFactory.make_minion(ATTACKER_4, 1, 4, 4)
	_db.records[ATTACKER_3] = CardFactory.make_minion(ATTACKER_3, 1, 3, 4)
	_db.records[OUT_OF_REACH] = CardFactory.make_minion(OUT_OF_REACH, OUT_OF_REACH_COST, 1, 1)
	_build_real([], MatchDriverFixture.deck_of(OUT_OF_REACH), settings)
	BossAiBoard.place(_driver._engine, _db, SIDE_BOSS, ATTACKER_4)
	BossAiBoard.place(_driver._engine, _db, SIDE_BOSS, ATTACKER_3)
	MatchDriverFixture.past_mulligan(_driver)
	_driver.tick()


## The fixture boss plays [param mode] through a `boss_overrides` entry (C8.4).
func _override_intent_mode(mode: String) -> void:
	_db.bodies.ai_profiles.boss_overrides[OVERRIDE] = {"extends": BossAI.DEFAULT_PROFILE, "intent_mode": mode}
	_db.records[MatchDriverFixture.BOSS_ID].ai_profile = OVERRIDE


func test_a19_the_driver_appends_the_full_intent_when_the_players_turn_starts() -> void:
	# Act
	_a19_board()

	# Assert
	assert_int(_log.count(SHOWN_EVENT)).is_equal(1)
	assert_dict(_log.first(SHOWN_EVENT).payload).is_equal({
		"boss_id": MatchDriverFixture.BOSS_ID,
		"intent_key": Intent.KEY_ATTACK_FACE,
		"target_id": null,
		"amount": 7,
		"effective_mode": Intent.MODE_FULL,
	})


func test_a19_telegraph_brief_from_the_snapshot_appends_the_class_alone() -> void:
	# Act: the settings snapshot reaches the AI at construction (ADR-0008 Decision 7)
	_a19_board({"telegraph_mode": BossAI.TELEGRAPH_BRIEF})

	# Assert
	var shown: Dictionary = _log.first(SHOWN_EVENT).payload
	assert_str(str(shown.effective_mode)).is_equal(Intent.MODE_CLASS_ONLY)
	assert_that(shown.amount).is_null()
	assert_that(shown.target_id).is_null()


func test_a19_a_class_only_boss_appends_the_class_alone() -> void:
	# Arrange
	_override_intent_mode(Intent.MODE_CLASS_ONLY)

	# Act
	_a19_board()

	# Assert
	var shown: Dictionary = _log.first(SHOWN_EVENT).payload
	assert_str(str(shown.intent_key)).is_equal(Intent.KEY_ATTACK_FACE)
	assert_str(str(shown.effective_mode)).is_equal(Intent.MODE_CLASS_ONLY)
	assert_that(shown.amount).is_null()


func test_a19_telegraph_off_appends_no_shown_intent_and_the_commit_still_lands() -> void:
	# Arrange
	_a19_board({"telegraph_mode": BossAI.TELEGRAPH_OFF})

	# Act
	assert_bool(_driver.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()
	_tick_until_idle()

	# Assert
	assert_int(_log.count(SHOWN_EVENT)).is_equal(0)
	assert_int(_log.count(COMMITTED_EVENT)).is_equal(1)
	assert_str(str(_log.first(COMMITTED_EVENT).payload.effective_mode)).is_equal(Intent.MODE_HIDDEN)


func test_a19_a_hidden_boss_appends_no_shown_intent() -> void:
	# Arrange
	_override_intent_mode(Intent.MODE_HIDDEN)

	# Act
	_a19_board()

	# Assert
	assert_int(_log.count(SHOWN_EVENT)).is_equal(0)


# --- Plan -----------------------------------------------------------------------


func test_a_stale_forecast_returning_lets_the_plan_row_fire_on_a_clone() -> void:
	# Arrange
	_build()
	MatchDriverFixture.past_mulligan(_driver)
	assert_bool(_driver.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()
	assert_int(_tasks.made.size()).is_equal(1)

	# Act
	_driver.tick()

	# Assert: one task at a time, so the plan waited for the forecast
	assert_int(_tasks.made.size()).is_equal(2)
	var sandbox: RulesEngine = _driver.spy().sandboxes[1]
	assert_bool(is_same(sandbox, _driver._engine)).is_false()
	assert_bool(is_same(sandbox, _driver._sandbox)).is_true()


func test_no_boss_ai_entry_point_runs_inline_from_submit_or_tick() -> void:
	# Arrange: scripted tasks never run their work, so an entry point counted is inline
	_build()

	# Act
	MatchDriverFixture.to_boss_main(_driver)
	_tasks.last().scripted_result = MatchDriverFixture.scripted_plan(_driver, [MatchRecords.end_turn(SIDE_BOSS)])
	_driver.tick()

	# Assert
	var calls: Array[String] = _driver.spy().calls
	assert_int(calls.count("plan_turn")).is_equal(0)
	assert_int(calls.count("forecast")).is_equal(0)
	assert_int(calls.count("choose")).is_equal(0)
	assert_int(calls.count("plan_task")).is_equal(1)


func test_every_task_is_a_fresh_object_started_once() -> void:
	# Arrange: DD-X31
	_build()

	# Act: a forecast, a plan, the next forecast
	MatchDriverFixture.to_boss_main(_driver)
	_tasks.last().scripted_result = MatchDriverFixture.scripted_plan(_driver, [MatchRecords.end_turn(SIDE_BOSS)])
	_driver.tick()

	# Assert
	assert_int(_tasks.made.size()).is_equal(3)
	for task: FakePlannerTask in _tasks.made:
		assert_int(task.starts).is_equal(1)
	assert_bool(is_same(_tasks.made[0], _tasks.made[1])).is_false()
	assert_bool(is_same(_tasks.made[1], _tasks.made[2])).is_false()


func test_no_plan_starts_while_one_is_being_replayed() -> void:
	# Arrange: a spent budget leaves the plan part-replayed at the boss's Main
	_build()
	MatchDriverFixture.to_boss_main(_driver)
	var commands: Array = MatchDriverFixture.boss_plays(2)
	commands.append(MatchRecords.end_turn(SIDE_BOSS))
	_tasks.last().scripted_result = MatchDriverFixture.scripted_plan(_driver, commands)
	var clock: FakeClock = _clock
	var budget: int = int(_db.bodies.ai_profiles.runtime.replay_budget_ms) * USEC_PER_MSEC
	_driver.subscribe(func(event: Dictionary) -> void:
		if event.type == "ai_decision":
			clock.now += budget
	)
	var made_before: int = _tasks.made.size()

	# Act
	_driver.tick()

	# Assert
	assert_int(_log.count(&"card_played")).is_equal(1)
	assert_int(_tasks.made.size()).is_equal(made_before)
	assert_object(_driver._pending_plan).is_not_null()


func test_a_plan_that_stops_short_of_end_turn_leaves_the_row_to_plan_again() -> void:
	# Arrange
	_build()
	MatchDriverFixture.to_boss_main(_driver)
	_tasks.last().scripted_result = MatchDriverFixture.scripted_plan(_driver, MatchDriverFixture.boss_plays(1))
	var made_before: int = _tasks.made.size()

	# Act
	_driver.tick()

	# Assert: the boss's Main with no plan pending is the row, whatever came before it
	assert_int(_tasks.made.size()).is_equal(made_before + 1)
	assert_int(_log.count(FAULT_EVENT)).is_equal(0)


func test_the_boss_takes_its_turns_with_nothing_but_commands_and_ticks() -> void:
	# Arrange: no test hook starts a task; this is the row wired end to end
	_build_real()
	MatchDriverFixture.past_mulligan(_driver)
	_tick_until_idle()
	var first_turn: int = _turn()

	# Act
	for _round: int in ROUNDS:
		assert_bool(_driver.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()
		_tick_until_idle()

	# Assert
	_assert_players_main()
	assert_bool(_turn() > first_turn).is_true()
	assert_int(_log.count(COMMITTED_EVENT)).is_equal(ROUNDS)
	assert_bool(_log.count(&"ai_decision") >= ROUNDS).is_true()
	assert_int(_log.count(SHOWN_EVENT)).is_equal(ROUNDS + 1)
	assert_int(_log.count(&"command_rejected")).is_equal(0)
	assert_array(_fault_reasons()).is_empty()


func test_time_sliced_tasks_plan_every_turn_of_a_match() -> void:
	# Arrange: the bug DD-X31 retires: one object cannot be started twice, and a
	# second `start` on it answers `poll()` with the first task's result
	var clock: FakeClock = _clock
	var made: Array[TimeSlicedPlannerTask] = []
	var slice_clock: Callable = func() -> int:
		clock.now += 1
		return clock.now
	var factory: Callable = func() -> PlannerTask:
		var task: TimeSlicedPlannerTask = TimeSlicedPlannerTask.new(1, slice_clock)
		made.append(task)
		return task
	_build_on(factory)
	MatchDriverFixture.past_mulligan(_driver)
	_tick_until_idle()

	# Act
	for _round: int in ROUNDS:
		assert_bool(_driver.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()
		_tick_until_idle()

	# Assert
	_assert_players_main()
	assert_int(_log.count(COMMITTED_EVENT)).is_equal(ROUNDS)
	assert_int(_log.count(&"command_rejected")).is_equal(0)
	assert_bool(_fault_reasons().has(MatchDriver.FAULT_NULL_RESULT)).is_false()
	assert_bool(_fault_reasons().has(MatchDriver.FAULT_EMPTY_PLAN)).is_false()
	assert_bool(made.size() >= 2 * ROUNDS).is_true()


# --- Choices (DD-X31: answered inside the plan) ----------------------------------


func test_a_boss_choice_on_the_players_turn_is_answered_inside_a_plan() -> void:
	# Arrange
	_build_real()
	MatchDriverFixture.past_mulligan(_driver)
	_tick_until_idle()
	var turn: int = _turn()
	var attack: Dictionary = _boss_rattle_attack()

	# Act
	var result: Dictionary = _driver.submit(attack)
	assert_str(_driver.query().phase()).is_equal(MatchState.PHASE_CHOICE)
	_tick_until_idle()

	# Assert: the Choice is gone, the player's turn stands, and it is still theirs
	assert_bool(result.accepted).is_true()
	assert_int(_log.count(PICKED_EVENT)).is_equal(1)
	_assert_players_main()
	assert_int(_turn()).is_equal(turn)
	assert_array(_fault_reasons()).is_empty()
	assert_int(_log.count(&"command_rejected")).is_equal(0)


func test_a_boss_choice_answered_on_the_players_turn_returns_the_driver_to_waiting() -> void:
	# Arrange: QA edge: back to waiting, not on to a plan of a whole turn
	_build_real()
	MatchDriverFixture.past_mulligan(_driver)
	_tick_until_idle()
	var attack: Dictionary = _boss_rattle_attack()
	var calls: Array[String] = _driver.spy().calls
	calls.clear()

	# Act
	assert_bool(_driver.submit(attack).accepted).is_true()
	_tick_until_idle()

	# Assert: one plan, which held the choice alone, and no intent committed by it
	assert_array(calls).is_equal(["plan_task", "plan_turn"])
	assert_int(_log.count(COMMITTED_EVENT)).is_equal(0)
	assert_bool(_driver.is_planning()).is_false()


func test_a_boss_choice_raised_under_a_live_forecast_waits_for_it() -> void:
	# Arrange
	_build()
	MatchDriverFixture.past_mulligan(_driver)
	var attack: Dictionary = _boss_rattle_attack()
	assert_bool(_driver.submit(attack).accepted).is_true()
	assert_int(_tasks.made.size()).is_equal(1)
	_tasks.last().scripted_result = _intent()

	# Act
	_driver.tick()

	# Assert: the forecast's premise moved; the plan comes after it
	assert_int(_log.count(SHOWN_EVENT)).is_equal(0)
	assert_int(_tasks.made.size()).is_equal(2)
	assert_array(_driver.spy().calls).is_equal(["forecast_task", "plan_task"])


func test_a_choice_raised_by_a_replayed_command_is_answered_by_the_plans_own_next_command() -> void:
	# Arrange: ADR-0008's old row would have started a task here and drawn twice
	_build([], MatchDriverFixture.deck_of(MatchDriverFixture.DISCOVER))
	MatchDriverFixture.to_boss_main(_driver)
	_tasks.last().scripted_result = MatchDriverFixture.scripted_plan(_driver, [
		MatchRecords.play_card(SIDE_BOSS, 0),
		MatchRecords.choose(SIDE_BOSS, 0),
		MatchRecords.end_turn(SIDE_BOSS),
	])
	var calls: Array[String] = _driver.spy().calls
	calls.clear()

	# Act
	_driver.tick()

	# Assert: no plan task between them; the one call is the next turn's forecast
	assert_int(_log.count(PICKED_EVENT)).is_equal(1)
	assert_array(calls).is_equal(["forecast_task"])
	assert_array(_fault_reasons()).is_empty()
	_assert_players_main()


func test_a_players_choice_on_the_boss_turn_waits_for_the_player_then_the_boss_plans_on() -> void:
	# Arrange: the boss's attack kills the player's Deathrattle Discover
	_build()
	MatchDriverFixture.past_mulligan(_driver)
	var rattle: Dictionary = BossAiBoard.place(_driver._engine, _db, SIDE_PLAYER, MatchDriverFixture.RATTLE)
	var attacker: Dictionary = BossAiBoard.place(_driver._engine, _db, SIDE_BOSS, MatchDriverFixture.VANILLA)
	assert_bool(_driver.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()
	_driver.tick()
	_tasks.last().scripted_result = MatchDriverFixture.scripted_plan(_driver, [
		MatchRecords.attack(SIDE_BOSS, int(attacker.entity_id), int(rattle.entity_id)),
	])
	var made_before: int = _tasks.made.size()

	# Act and Assert: nothing for the driver to do while the Choice is the player's
	_driver.tick()
	assert_str(str(_driver.query().pending_choice().side)).is_equal(SIDE_PLAYER)
	assert_int(_tasks.made.size()).is_equal(made_before)
	assert_bool(_driver.is_planning()).is_false()

	# Act and Assert: the boss's Main is back, with no plan pending
	assert_bool(_driver.submit(MatchRecords.choose(SIDE_PLAYER, 0)).accepted).is_true()
	assert_int(_tasks.made.size()).is_equal(made_before + 1)
	assert_array(_fault_reasons()).is_empty()


# --- Faults (DD-X31: logged, and the boss turn ends; never a hang) ----------------


func test_a_null_plan_logs_ai_fault_and_ends_the_boss_turn() -> void:
	# Arrange
	_build()
	MatchDriverFixture.to_boss_main(_driver)
	_tasks.last().scripted_result = null

	# Act
	_driver.tick()

	# Assert
	assert_array(_fault_reasons()).is_equal([MatchDriver.FAULT_NULL_RESULT])
	var fault: Dictionary = _log.first(FAULT_EVENT)
	assert_bool(bool(fault.payload.diagnostic)).is_true()
	assert_int(int(fault.cause_seq)).is_equal(0)
	_assert_players_main()
	assert_int(_log.count(&"command_rejected")).is_equal(0)
	assert_str(_driver.spy().calls.back()).is_equal("forecast_task")


func test_an_empty_plan_logs_ai_fault_and_ends_the_boss_turn() -> void:
	# Arrange
	_build()
	MatchDriverFixture.to_boss_main(_driver)
	_tasks.last().scripted_result = TurnPlan.new()

	# Act
	_driver.tick()

	# Assert
	assert_array(_fault_reasons()).is_equal([MatchDriver.FAULT_EMPTY_PLAN])
	_assert_players_main()
	assert_int(_log.count(&"command_rejected")).is_equal(0)
	assert_str(_driver.spy().calls.back()).is_equal("forecast_task")


func test_an_empty_plans_own_diagnostics_are_logged_before_the_fault() -> void:
	# Arrange: the planner's `end_turn_rejected` is one such plan
	_build()
	MatchDriverFixture.to_boss_main(_driver)
	var plan: TurnPlan = TurnPlan.new()
	plan.diagnostics.append({
		TurnPlan.EVENT_KEY: BossAI.EVENT_FAULT,
		"reason": BossAI.FAULT_END_TURN_REJECTED,
		TurnPlan.COMMAND_INDEX_KEY: 0,
		TurnPlan.DIAGNOSTIC_KEY: true,
	})
	_tasks.last().scripted_result = plan

	# Act
	_driver.tick()

	# Assert
	assert_array(_fault_reasons()).is_equal([BossAI.FAULT_END_TURN_REJECTED, MatchDriver.FAULT_EMPTY_PLAN])


func test_a_null_plan_for_a_boss_choice_on_the_boss_turn_takes_the_first_option_and_ends_the_turn() -> void:
	# Arrange: a plan that stopped at the Choice; `end_turn` alone would be refused
	_build([], MatchDriverFixture.deck_of(MatchDriverFixture.DISCOVER))
	MatchDriverFixture.to_boss_main(_driver)
	_tasks.last().scripted_result = MatchDriverFixture.scripted_plan(_driver, [MatchRecords.play_card(SIDE_BOSS, 0)])
	_driver.tick()
	assert_str(_driver.query().phase()).is_equal(MatchState.PHASE_CHOICE)
	_tasks.last().scripted_result = null

	# Act
	_driver.tick()

	# Assert
	assert_array(_fault_reasons()).is_equal([MatchDriver.FAULT_NULL_RESULT])
	assert_int(_log.count(PICKED_EVENT)).is_equal(1)
	assert_int(_log.count(&"command_rejected")).is_equal(0)
	_assert_players_main()


func test_an_empty_plan_for_a_boss_choice_on_the_players_turn_leaves_the_players_turn_standing() -> void:
	# Arrange
	_build()
	_at_player_main_idle()
	var turn: int = _turn()
	assert_bool(_driver.submit(_boss_rattle_attack()).accepted).is_true()
	_tasks.last().scripted_result = TurnPlan.new()

	# Act
	_driver.tick()

	# Assert: the player is not locked out, and no boss `end_turn` is refused
	assert_array(_fault_reasons()).is_equal([MatchDriver.FAULT_EMPTY_PLAN])
	assert_int(_log.count(PICKED_EVENT)).is_equal(1)
	assert_int(_log.count(&"command_rejected")).is_equal(0)
	_assert_players_main()
	assert_int(_turn()).is_equal(turn)
	assert_bool(_driver.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()


func test_a_null_forecast_logs_ai_fault_and_the_players_turn_goes_on() -> void:
	# Arrange
	_build()
	MatchDriverFixture.past_mulligan(_driver)
	_tasks.last().scripted_result = null

	# Act
	_driver.tick()

	# Assert
	assert_array(_fault_reasons()).is_equal([MatchDriver.FAULT_NULL_RESULT])
	assert_int(_log.count(SHOWN_EVENT)).is_equal(0)
	assert_array(_driver.spy().forecasts).is_empty()
	assert_int(_log.count(&"command_rejected")).is_equal(0)
	_assert_players_main()
	assert_bool(_driver.is_planning()).is_false()


func test_a_stale_null_result_is_discarded_with_no_fault() -> void:
	# Arrange
	_build()
	MatchDriverFixture.past_mulligan(_driver)
	assert_bool(_driver.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()
	_tasks.last().scripted_result = null

	# Act
	_driver.tick()

	# Assert
	assert_int(_log.count(FAULT_EVENT)).is_equal(0)


func test_a_null_plan_with_a_concede_queued_applies_the_concede_and_logs_no_fault() -> void:
	# Arrange
	_build()
	MatchDriverFixture.to_boss_main(_driver)
	_tasks.last().scripted_result = null
	@warning_ignore("return_value_discarded")
	_driver.submit(MatchRecords.concede())

	# Act
	_driver.tick()

	# Assert
	assert_int(_log.count(FAULT_EVENT)).is_equal(0)
	assert_str(str(_log.first(&"match_ended").payload.reason)).is_equal(MatchRecords.REASON_CONCEDE)


func test_a_divergence_during_a_boss_choice_closes_the_choice_and_ends_the_turn() -> void:
	# Arrange: review Q-3: `end_turn` alone is refused with `CHOICE_PENDING`
	_build([], MatchDriverFixture.deck_of(MatchDriverFixture.DISCOVER))
	MatchDriverFixture.to_boss_main(_driver)
	var plan: TurnPlan = MatchDriverFixture.scripted_plan(_driver, [MatchRecords.play_card(SIDE_BOSS, 0)])
	plan.commands.append(MatchRecords.play_card(SIDE_BOSS, BAD_HAND_INDEX, 0))
	_tasks.last().scripted_result = plan

	# Act
	_driver.tick()

	# Assert
	assert_array(_fault_reasons()).is_equal([MatchDriver.FAULT_REPLAY_DIVERGENCE])
	assert_int(_log.count(PICKED_EVENT)).is_equal(1)
	assert_object(_driver._pending_plan).is_null()
	_assert_players_main()


func test_a_turn_the_engine_will_not_end_runs_into_the_event_cap_and_never_hangs() -> void:
	# Arrange: the one case nothing can finish: every boss `end_turn` is refused and
	# every plan is empty. Each pass logs, so the log's cap is the floor under it
	var measure: EventLog = EventLog.new(TestConstants.MAX_MATCH_EVENTS, EventLog.SCOPE_MATCH)
	var probe: MatchDriver = MatchDriver.new(MatchDriverFixture.match_config(measure), _db, {}, _tasks.make, _clock.read)
	MatchDriverFixture.to_boss_main(probe)
	var room: int = measure.size() + ROUNDS
	probe.shutdown()
	var log: EventLog = EventLog.new(room, EventLog.SCOPE_MATCH)
	_driver = StubbornDriver.new(MatchDriverFixture.match_config(log), _db, {}, _tasks.make, _clock.read)
	var results: Array[Dictionary] = []
	_driver.match_ended.connect(func(result: Dictionary) -> void: results.append(result))
	MatchDriverFixture.to_boss_main(_driver)

	# Act
	for _i: int in TICK_LIMIT:
		if not results.is_empty():
			break
		_tasks.last().scripted_result = TurnPlan.new()
		_driver.tick()

	# Assert
	assert_int(results.size()).is_equal(1)
	assert_str(str(results[0].reason)).is_equal(MatchRecords.REASON_EVENT_CAP)


# --- Telegraph setting ----------------------------------------------------------


func test_a_telegraph_change_with_no_task_live_applies_at_once() -> void:
	# Arrange
	_build()
	_at_player_main_idle()

	# Act
	_driver.on_setting_changed(&"telegraph_mode", BossAI.TELEGRAPH_BRIEF)

	# Assert
	assert_array(_driver.spy().telegraph).is_equal([BossAI.TELEGRAPH_BRIEF])


func test_a_telegraph_change_during_a_task_waits_for_it_and_lands_before_the_next_one() -> void:
	# Arrange
	_build()
	MatchDriverFixture.past_mulligan(_driver)
	assert_bool(_driver.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()

	# Act
	_driver.on_setting_changed(&"telegraph_mode", BossAI.TELEGRAPH_BRIEF)
	assert_array(_driver.spy().telegraph).is_empty()
	_driver.tick()

	# Assert
	assert_array(_driver.spy().calls).is_equal(["forecast_task", "set_telegraph_mode", "plan_task"])
	assert_array(_driver.spy().telegraph).is_equal([BossAI.TELEGRAPH_BRIEF])


func test_the_last_telegraph_change_during_a_task_is_the_one_applied() -> void:
	# Arrange
	_build()
	MatchDriverFixture.past_mulligan(_driver)

	# Act
	_driver.on_setting_changed(&"telegraph_mode", BossAI.TELEGRAPH_BRIEF)
	_driver.on_setting_changed(&"telegraph_mode", BossAI.TELEGRAPH_OFF)
	_tasks.last().scripted_result = _intent()
	_driver.tick()

	# Assert
	assert_array(_driver.spy().telegraph).is_equal([BossAI.TELEGRAPH_OFF])


func test_telegraph_off_during_a_forecast_keeps_that_forecast_off_the_log() -> void:
	# Arrange: the Intent was built under `full`, but the player has said off
	_build()
	MatchDriverFixture.past_mulligan(_driver)
	var intent: Intent = _intent(Intent.MODE_FULL)
	_tasks.last().scripted_result = intent

	# Act
	_driver.on_setting_changed(&"telegraph_mode", BossAI.TELEGRAPH_OFF)
	_driver.tick()

	# Assert
	assert_int(_log.count(SHOWN_EVENT)).is_equal(0)
	assert_array(_driver.spy().forecasts).is_equal([intent])


func test_any_other_setting_is_ignored() -> void:
	# Arrange
	_build()
	_at_player_main_idle()

	# Act
	_driver.on_setting_changed(&"anim_speed", BossAI.TELEGRAPH_BRIEF)

	# Assert
	assert_array(_driver.spy().telegraph).is_empty()


func test_no_telegraph_key_in_the_snapshot_leaves_the_ai_alone() -> void:
	# Act
	_build()

	# Assert: C8.4: absent is `full`, which the AI already holds
	assert_array(_driver.spy().telegraph).is_empty()


# --- The tick budget (review Q-4; ADR-0006) --------------------------------------


func test_a_time_sliced_slice_is_not_the_drivers_own_work() -> void:
	# Arrange: `slice_ms` bounds the slice, `replay_budget_ms` the replay. Every
	# read of the slice clock spends more than the replay budget, as a slice does
	var clock: FakeClock = _clock
	var over: int = int(_db.bodies.ai_profiles.runtime.replay_budget_ms) * USEC_PER_MSEC + 1
	var slice_clock: Callable = func() -> int:
		clock.now += over
		return clock.now
	_build_on(func() -> PlannerTask: return TimeSlicedPlannerTask.new(1, slice_clock))
	MatchDriverFixture.past_mulligan(_driver)
	assert_bool(_driver._task.is_live()).is_true()

	# Act
	_driver.tick()

	# Assert: the task suspended again, so a whole slice ran inside that poll
	assert_bool(_driver._task != null and _driver._task.is_live()).is_true()
	assert_array(_fault_reasons()).is_empty()


func test_the_clone_and_start_of_a_task_are_not_the_drivers_own_work() -> void:
	# Arrange: a stale forecast returns and the plan row runs inside the tick
	_build()
	MatchDriverFixture.past_mulligan(_driver)
	assert_bool(_driver.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()
	var clock: FakeClock = _clock
	var over: int = int(_db.bodies.ai_profiles.runtime.replay_budget_ms) * USEC_PER_MSEC + 1
	var factory_cost: Callable = func() -> PlannerTask:
		clock.now += over
		return _tasks.make()
	_driver._planner_factory = factory_cost

	# Act
	_driver.tick()

	# Assert
	assert_array(_fault_reasons()).is_empty()


func test_a_slow_poll_on_a_task_that_does_not_slice_is_still_the_drivers_own_work() -> void:
	# Arrange
	_build()
	MatchDriverFixture.past_mulligan(_driver)
	var clock: FakeClock = _clock
	var over: int = int(_db.bodies.ai_profiles.runtime.replay_budget_ms) * USEC_PER_MSEC + 1
	_tasks.last().polls_before_done = 1
	_tasks.last().rearm()
	_tasks.last().on_poll = func() -> void: clock.now += over

	# Act
	_driver.tick()

	# Assert
	assert_array(_fault_reasons()).is_equal([MatchDriver.FAULT_TICK_OVER_BUDGET])


# --- Lifetime -------------------------------------------------------------------


func test_nothing_is_scheduled_after_a_live_match_was_shut_down() -> void:
	# Arrange: at the boss's Main, where the plan row would otherwise fire on a
	# torn-down engine
	_build()
	MatchDriverFixture.to_boss_main(_driver)
	_driver.shutdown()
	var made_before: int = _tasks.made.size()

	# Act
	var result: Dictionary = _driver.submit(MatchRecords.end_turn(SIDE_PLAYER))
	_driver.tick()

	# Assert
	assert_str(str(result.rejection.code)).is_equal(RulesEngine.R_MATCH_ENDED)
	assert_int(_tasks.made.size()).is_equal(made_before)


func test_shutdown_ends_a_live_tasks_sandbox() -> void:
	# Arrange
	_build()
	MatchDriverFixture.past_mulligan(_driver)
	var sandbox: RulesEngine = _driver._sandbox

	# Act
	_driver.shutdown()

	# Assert
	assert_object(_driver._sandbox).is_null()
	assert_str(str(sandbox.submit(MatchRecords.end_turn(SIDE_PLAYER)).rejection.code)).is_equal(RulesEngine.R_MATCH_ENDED)
