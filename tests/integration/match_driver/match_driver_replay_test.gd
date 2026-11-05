## Integration: `MatchDriver.tick()`, bounded replay, the checksum, `Ended` and
## `shutdown()` (story boss-ai-match-driver/story-015; ADR-0006 replay protocol,
## ADR-0008 Decisions 4, 5, 9, ADR-0003 subscriber contract; boss-ai C1.5, C9;
## TR-boss-ai-003, TR-run-structure-005).
##
## Everything runs the live `RulesEngine` and the production `EventLog`. Hand-made
## [TurnPlan]s come back through a [FakePlannerTask] on [MatchDriverFixture]'s
## database; the last section plays real boss turns on the shipped data through
## `BossAI.plan_task` and [ImmediatePlannerTask]. No worker starts, and no assertion
## reads the real clock: the driver's injected clock is a [FakeClock], which a
## subscriber or the fake task advances.
extends GdUnitTestSuite

const BOOT_SCRIPT := preload("res://src/core/boot.gd")
const SHIPPED_ROOT: String = "res://assets/data/"
const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const SIDE_BOSS: String = MatchRecords.SIDE_BOSS
const FAULT_EVENT: StringName = &"ai_fault"
const DECISION_EVENT: StringName = &"ai_decision"
const USEC_PER_MSEC: int = 1000
## A hand index no hand reaches: the live engine rejects the command.
const BAD_HAND_INDEX: int = 99
## Rounds of the real-planner matches: enough for boards and attacks to appear.
const REAL_ROUNDS: int = 6
## The shipped band-1 boss the real-planner matches play.
const REAL_BOSS: String = "boss_torchbearer"
const REAL_SEED: int = 11


## A clock a test moves by hand.
class FakeClock:
	extends RefCounted

	var now: int = 0
	## Added on every read: time that passes by itself.
	var step: int = 0

	func read() -> int:
		now += step
		return now


## A log that counts appends made after it sealed, which are a caller bug, and
## refuses them without the debug assert, so a test reads the count.
class SealWatchLog:
	extends EventLog

	var appends_after_seal: int = 0

	func append(type: StringName, payload: Dictionary, cause_seq: int = 0) -> int:
		if is_sealed():
			appends_after_seal += 1
			return -1
		return super(type, payload, cause_seq)


## An engine that counts [method end_match] and [method submit].
class CountingEngine:
	extends RulesEngine

	var end_match_calls: int = 0
	var submits: int = 0

	func end_match() -> void:
		end_match_calls += 1
		super()

	func submit(command: Dictionary) -> Dictionary:
		submits += 1
		return super(command)


## A driver that counts steps and builds a [CountingEngine].
class SpyDriver:
	extends MatchDriver

	var steps: int = 0

	func _init(config: Dictionary, db: CardDatabase, settings: Dictionary, task: PlannerTask, clock: Callable) -> void:
		super(config, db, settings, task, clock)

	func _build_engine(db: CardDatabase, resolver: EffectResolver) -> RulesEngine:
		return CountingEngine.new(db, db.config("match_rules"), resolver)

	func _after_engine_step() -> void:
		steps += 1
		super()


var _db: MatchDriverFixture.FixtureDatabase
var _log: EventLog
var _task: FakePlannerTask
var _clock: FakeClock
var _driver: SpyDriver


func before_test() -> void:
	_db = MatchDriverFixture.database()
	_log = EventLog.new(TestConstants.MAX_MATCH_EVENTS, EventLog.SCOPE_MATCH)
	_task = FakePlannerTask.new()
	_clock = FakeClock.new()
	_driver = null


func after_test() -> void:
	if _driver != null:
		_driver.shutdown()
	_driver = null


func _build(player_deck: Array = [], boss_deck: Array = []) -> SpyDriver:
	_driver = SpyDriver.new(MatchDriverFixture.match_config(_log, player_deck, boss_deck), _db, {}, _task, _clock.read)
	return _driver


func _types(type: StringName) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for event: Dictionary in _log.events_since(0):
		if event.type == String(type):
			found.append(event)
	return found


func _count(type: StringName) -> int:
	return _types(type).size()


## The configured budget in microseconds, read as the driver reads it.
func _budget_usec() -> int:
	return int(_db.bodies.ai_profiles.runtime.replay_budget_ms) * USEC_PER_MSEC


## Every `ai_decision` costs [param usec] on the clock. It reaches subscribers
## inside the driver's append, as projecting an event does.
func _charge_each_decision(usec: int) -> void:
	var clock: FakeClock = _clock
	_driver.subscribe(func(event: Dictionary) -> void:
		if event.type == String(DECISION_EVENT):
			clock.now += usec
	)


## A driver at the boss's Main, a plan of [param commands] returned at the first
## tick.
func _boss_plan(commands: Array) -> TurnPlan:
	_build()
	MatchDriverFixture.to_boss_main(_driver)
	var plan: TurnPlan = MatchDriverFixture.scripted_plan(_driver, commands)
	MatchDriverFixture.start_plan(_driver, _task, plan)
	return plan


## An awake 1/1 of the boss's, the player's hero at 1 health: `attack` is lethal.
func _boss_lethal_ready() -> Dictionary:
	var state: MatchState = _driver._engine.state()
	var minion: Dictionary = BossAiBoard.place(_driver._engine, _db, SIDE_BOSS, MatchDriverFixture.VANILLA)
	var hero: Dictionary = state.players[SIDE_PLAYER].hero
	hero.damage_taken = _driver._engine.max_health(hero) - 1
	return MatchRecords.attack(SIDE_BOSS, int(minion.entity_id), int(hero.entity_id))


## The order two channels saw the end: `event` from a subscriber, `signal` from
## the driver. Shared through the returned Array: lambdas capture by value.
func _record_end_order() -> Array[String]:
	var order: Array[String] = []
	_driver.subscribe(func(event: Dictionary) -> void:
		if event.type == "match_ended":
			order.append("event")
	)
	_driver.match_ended.connect(func(_result: Dictionary) -> void: order.append("signal"))
	return order


func _assert_ended_cleanly(order: Array[String], reason: String) -> void:
	assert_array(order).is_equal(["event", "signal"])
	assert_str(str(_driver._engine.result().reason)).is_equal(reason)
	assert_bool(_driver.is_planning()).is_false()
	assert_int((_driver._engine as CountingEngine).end_match_calls).is_equal(1)
	assert_object(_driver._resolver.bound_engine()).is_null()
	assert_array(_driver._engine.match_ended.get_connections()).is_empty()


# --- Replay --------------------------------------------------------------------


func test_each_replayed_command_follows_its_ai_decision_at_cause_zero() -> void:
	# Arrange
	var seq_before: int = 0
	_boss_plan(MatchDriverFixture.boss_plays(2))
	seq_before = _log.size()

	# Act
	_driver.tick()

	# Assert
	var replayed: Array[Dictionary] = _log.events_since(seq_before)
	assert_str(str(replayed[0].type)).is_equal(String(DECISION_EVENT))
	assert_int(int(replayed[0].cause_seq)).is_equal(0)
	assert_bool(bool(replayed[0].payload.diagnostic)).is_true()
	assert_int(int(replayed[0].payload.chosen)).is_equal(0)
	assert_bool(replayed[0].payload.has(TurnPlan.EVENT_KEY)).is_false()
	assert_bool(replayed[0].payload.has(TurnPlan.COMMAND_INDEX_KEY)).is_false()
	var decisions: Array[Dictionary] = _types(DECISION_EVENT)
	var plays: Array[Dictionary] = _types(&"card_played")
	assert_int(decisions.size()).is_equal(2)
	assert_int(plays.size()).is_equal(2)
	assert_bool(int(decisions[0].seq) < int(plays[0].seq)).is_true()
	assert_bool(int(plays[0].seq) < int(decisions[1].seq)).is_true()
	assert_bool(int(decisions[1].seq) < int(plays[1].seq)).is_true()


func test_a_replayed_command_is_submitted_as_the_boss_whatever_the_plan_says() -> void:
	# Arrange: the plan's own issuer is wrong
	var plan: TurnPlan = _boss_plan(MatchDriverFixture.boss_plays(1))
	plan.commands[0] = MatchRecords.play_card(SIDE_PLAYER, 0, 0)

	# Act
	_driver.tick()

	# Assert
	assert_int(_count(&"card_played")).is_equal(1)
	assert_str(str(_types(&"card_played")[0].payload.side)).is_equal(SIDE_BOSS)
	assert_int(_count(FAULT_EVENT)).is_equal(0)


func test_every_replayed_command_runs_the_step_after_it() -> void:
	# Arrange
	_boss_plan(MatchDriverFixture.boss_plays(3))
	var steps_before: int = _driver.steps

	# Act
	_driver.tick()

	# Assert
	assert_int(_driver.steps - steps_before).is_equal(3)


func test_diagnostics_past_the_last_command_follow_it() -> void:
	# Arrange
	var plan: TurnPlan = _boss_plan(MatchDriverFixture.boss_plays(1))
	plan.diagnostics.append({
		TurnPlan.EVENT_KEY: "ai_plan_aborted",
		TurnPlan.COMMAND_INDEX_KEY: 1,
		TurnPlan.DIAGNOSTIC_KEY: true,
	})

	# Act
	_driver.tick()

	# Assert
	var aborted: Array[Dictionary] = _types(&"ai_plan_aborted")
	assert_int(aborted.size()).is_equal(1)
	assert_bool(int(aborted[0].seq) > int(_types(&"card_played")[0].seq)).is_true()
	assert_int(_count(FAULT_EVENT)).is_equal(0)


func test_a_true_plan_replays_with_no_fault_and_ends_planning() -> void:
	# Arrange
	var commands: Array = MatchDriverFixture.boss_plays(2)
	commands.append(MatchRecords.end_turn(SIDE_BOSS))
	_boss_plan(commands)

	# Act
	_driver.tick()

	# Assert
	assert_int(_count(FAULT_EVENT)).is_equal(0)
	assert_int(_count(&"command_rejected")).is_equal(0)
	assert_bool(_driver.is_planning()).is_false()
	assert_str(String(_driver._engine.active_side())).is_equal(SIDE_PLAYER)


func test_a_plan_with_no_commands_is_done_at_once() -> void:
	# Arrange: `plan_turn` outside the boss's Main returns one
	_boss_plan([])

	# Act
	_driver.tick()

	# Assert
	assert_bool(_driver.is_planning()).is_false()
	assert_int(_count(FAULT_EVENT)).is_equal(0)


func test_poll_runs_once_per_tick_and_never_after_it_answered_true() -> void:
	# Arrange
	_build()
	MatchDriverFixture.to_boss_main(_driver)
	_task.polls_before_done = 2
	MatchDriverFixture.start_plan(_driver, _task, MatchDriverFixture.scripted_plan(_driver, MatchDriverFixture.boss_plays(1)))

	# Act and Assert
	_driver.tick()
	assert_int(_task.polls).is_equal(1)
	_driver.tick()
	assert_int(_task.polls).is_equal(2)
	_driver.tick()
	assert_int(_task.polls).is_equal(3)
	_driver.tick()
	_driver.tick()
	assert_int(_task.polls).is_equal(3)
	assert_int(_task.polls_after_done).is_equal(0)


# --- The budget ----------------------------------------------------------------


func test_a_stopped_clock_replays_the_whole_plan_in_one_tick() -> void:
	# Arrange
	_boss_plan(MatchDriverFixture.boss_plays(4))

	# Act
	_driver.tick()

	# Assert
	assert_int(_count(&"card_played")).is_equal(4)


func test_replay_stops_when_the_budget_is_spent_and_resumes_next_tick() -> void:
	# Arrange: three quarters of the budget per command, so two commands spend it
	_boss_plan(MatchDriverFixture.boss_plays(4))
	_charge_each_decision(_budget_usec() * 3 / 4)

	# Act and Assert
	_driver.tick()
	assert_int(_count(&"card_played")).is_equal(2)
	assert_bool(_driver.is_planning()).is_true()
	_driver.tick()
	assert_int(_count(&"card_played")).is_equal(4)
	assert_bool(_driver.is_planning()).is_false()
	assert_int(_count(FAULT_EVENT)).is_equal(0)


func test_a_spent_budget_still_replays_one_command_per_tick() -> void:
	# Arrange
	_boss_plan(MatchDriverFixture.boss_plays(2))
	_charge_each_decision(_budget_usec() * 10)

	# Act and Assert
	_driver.tick()
	assert_int(_count(&"card_played")).is_equal(1)
	_driver.tick()
	assert_int(_count(&"card_played")).is_equal(2)


func test_a_poll_that_spent_the_budget_still_replays_one_command() -> void:
	# Arrange
	_boss_plan(MatchDriverFixture.boss_plays(2))
	var clock: FakeClock = _clock
	var spent: int = _budget_usec()
	_task.on_poll = func() -> void: clock.now += spent

	# Act
	_driver.tick()

	# Assert
	assert_int(_count(&"card_played")).is_equal(1)
	assert_bool(_driver.is_planning()).is_true()


func test_the_budget_comes_from_the_data_not_a_literal() -> void:
	# Arrange: 5 ms in the data, 3 ms per command: two commands fit, not one
	_db.bodies.ai_profiles.runtime.replay_budget_ms = 5
	_boss_plan(MatchDriverFixture.boss_plays(3))
	_charge_each_decision(3 * USEC_PER_MSEC)

	# Act
	_driver.tick()

	# Assert
	assert_int(_count(&"card_played")).is_equal(2)


func test_a_poll_past_the_budget_appends_tick_over_budget() -> void:
	# Arrange: the driver's own work, in a debug build (this run is one)
	_build()
	MatchDriverFixture.to_boss_main(_driver)
	_task.polls_before_done = 1
	MatchDriverFixture.start_plan(_driver, _task, TurnPlan.new())
	var clock: FakeClock = _clock
	var over: int = _budget_usec() + 1
	_task.on_poll = func() -> void: clock.now += over

	# Act
	_driver.tick()

	# Assert
	var faults: Array[Dictionary] = _types(FAULT_EVENT)
	assert_int(faults.size()).is_equal(1)
	assert_str(str(faults[0].payload.reason)).is_equal(MatchDriver.FAULT_TICK_OVER_BUDGET)
	assert_bool(bool(faults[0].payload.diagnostic)).is_true()
	assert_int(int(faults[0].cause_seq)).is_equal(0)


func test_a_poll_inside_the_budget_appends_nothing() -> void:
	# Arrange
	_build()
	MatchDriverFixture.to_boss_main(_driver)
	_task.polls_before_done = 1
	MatchDriverFixture.start_plan(_driver, _task, TurnPlan.new())
	var clock: FakeClock = _clock
	var within: int = _budget_usec()
	_task.on_poll = func() -> void: clock.now += within

	# Act
	_driver.tick()

	# Assert
	assert_int(_count(FAULT_EVENT)).is_equal(0)


func test_engine_and_subscriber_time_is_not_the_drivers_own_work() -> void:
	# Arrange: every event costs ten budgets, inside the engine or the append
	_boss_plan(MatchDriverFixture.boss_plays(2))
	var clock: FakeClock = _clock
	var cost: int = _budget_usec() * 10
	_driver.subscribe(func(_event: Dictionary) -> void: clock.now += cost)

	# Act
	_driver.tick()
	_driver.tick()

	# Assert: that is Match UI's and the engine's budget (ADR-0006, ADR-0008)
	assert_int(_count(&"card_played")).is_equal(2)
	assert_int(_count(FAULT_EVENT)).is_equal(0)


# --- Divergence ----------------------------------------------------------------


func test_a_rejected_command_faults_ends_the_turn_and_replays_no_more() -> void:
	# Arrange
	var commands: Array = MatchDriverFixture.boss_plays(1)
	commands.append(MatchRecords.play_card(SIDE_BOSS, BAD_HAND_INDEX, 0))
	commands.append_array(MatchDriverFixture.boss_plays(1))
	_boss_plan(commands)

	# Act
	_driver.tick()

	# Assert
	var faults: Array[Dictionary] = _types(FAULT_EVENT)
	assert_int(faults.size()).is_equal(1)
	assert_str(str(faults[0].payload.reason)).is_equal(MatchDriver.FAULT_REPLAY_DIVERGENCE)
	assert_int(int(faults[0].payload.at_index)).is_equal(1)
	assert_bool(bool(faults[0].payload.diagnostic)).is_true()
	assert_int(_count(&"card_played")).is_equal(1)
	assert_int(_count(DECISION_EVENT)).is_equal(2)
	assert_str(String(_driver._engine.active_side())).is_equal(SIDE_PLAYER)
	assert_str(_driver.query().phase()).is_equal(MatchState.PHASE_MAIN)
	assert_bool(_driver.is_planning()).is_false()


func test_a_checksum_mismatch_faults_at_the_end_and_ends_the_turn() -> void:
	# Arrange
	var plan: TurnPlan = _boss_plan(MatchDriverFixture.boss_plays(2))
	plan.expected_checksum += 1

	# Act
	_driver.tick()

	# Assert: nothing is left to replay; `at_index` is one past the last command
	var faults: Array[Dictionary] = _types(FAULT_EVENT)
	assert_int(faults.size()).is_equal(1)
	assert_str(str(faults[0].payload.reason)).is_equal(MatchDriver.FAULT_REPLAY_DIVERGENCE)
	assert_int(int(faults[0].payload.at_index)).is_equal(plan.commands.size())
	assert_int(_count(&"card_played")).is_equal(2)
	assert_str(String(_driver._engine.active_side())).is_equal(SIDE_PLAYER)
	assert_str(_driver.query().phase()).is_equal(MatchState.PHASE_MAIN)


func test_a_mismatch_after_the_plans_own_end_turn_leaves_the_match_running() -> void:
	# Arrange
	var commands: Array = MatchDriverFixture.boss_plays(1)
	commands.append(MatchRecords.end_turn(SIDE_BOSS))
	var plan: TurnPlan = _boss_plan(commands)
	plan.expected_checksum += 1

	# Act
	_driver.tick()

	# Assert: the driver's `end_turn` is refused, and the player's turn stands
	assert_int(_count(FAULT_EVENT)).is_equal(1)
	assert_int(_count(&"command_rejected")).is_equal(1)
	assert_str(String(_driver._engine.active_side())).is_equal(SIDE_PLAYER)
	assert_str(_driver.query().phase()).is_equal(MatchState.PHASE_MAIN)
	assert_bool(_driver.is_planning()).is_false()


func test_a_true_plan_spread_over_two_ticks_stays_clean() -> void:
	# Arrange: the checksum must cover both ticks
	_boss_plan(MatchDriverFixture.boss_plays(2))
	_charge_each_decision(_budget_usec() * 10)

	# Act
	_driver.tick()
	_driver.tick()

	# Assert
	assert_int(_count(FAULT_EVENT)).is_equal(0)


func test_a_player_command_refused_during_replay_does_not_disturb_the_checksum() -> void:
	# Arrange
	_boss_plan(MatchDriverFixture.boss_plays(2))
	_charge_each_decision(_budget_usec() * 10)
	_driver.tick()

	# Act: `command_rejected` lands between two replayed commands
	var refused: Dictionary = _driver.submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0))
	_driver.tick()

	# Assert
	assert_bool(refused.accepted).is_false()
	assert_int(_count(FAULT_EVENT)).is_equal(0)


# --- Ended ---------------------------------------------------------------------


func test_a_replayed_lethal_ends_the_match_and_drops_the_plan() -> void:
	# Arrange
	_build()
	MatchDriverFixture.to_boss_main(_driver)
	var commands: Array = [_boss_lethal_ready()]
	commands.append_array(MatchDriverFixture.boss_plays(2))
	var plan: TurnPlan = MatchDriverFixture.scripted_plan(_driver, commands)
	MatchDriverFixture.start_plan(_driver, _task, plan)
	var order: Array[String] = _record_end_order()

	# Act
	_driver.tick()

	# Assert
	_assert_ended_cleanly(order, MatchRecords.REASON_HERO_DEAD)
	assert_int(_count(&"card_played")).is_equal(0)
	assert_int(_count(DECISION_EVENT)).is_equal(1)
	assert_int(_count(FAULT_EVENT)).is_equal(0)


func test_a_player_lethal_ends_the_match() -> void:
	# Arrange
	_build()
	MatchDriverFixture.past_mulligan(_driver)
	var state: MatchState = _driver._engine.state()
	var minion: Dictionary = BossAiBoard.place(_driver._engine, _db, SIDE_PLAYER, MatchDriverFixture.VANILLA)
	var hero: Dictionary = state.players[SIDE_BOSS].hero
	hero.damage_taken = _driver._engine.max_health(hero) - 1
	var order: Array[String] = _record_end_order()

	# Act
	var result: Dictionary = _driver.submit(MatchRecords.attack(SIDE_PLAYER, int(minion.entity_id), int(hero.entity_id)))

	# Assert
	assert_bool(result.accepted).is_true()
	_assert_ended_cleanly(order, MatchRecords.REASON_HERO_DEAD)


func test_a_direct_concede_ends_the_match() -> void:
	# Arrange
	_build()
	var order: Array[String] = _record_end_order()

	# Act
	@warning_ignore("return_value_discarded")
	_driver.submit(MatchRecords.concede())

	# Assert
	_assert_ended_cleanly(order, MatchRecords.REASON_CONCEDE)


func test_a_queued_concede_ends_the_match_through_the_same_row() -> void:
	# Arrange
	_build()
	MatchDriverFixture.to_boss_main(_driver)
	_task.polls_before_done = 1
	MatchDriverFixture.start_plan(_driver, _task, MatchDriverFixture.scripted_plan(_driver, MatchDriverFixture.boss_plays(1)))
	var order: Array[String] = _record_end_order()
	@warning_ignore("return_value_discarded")
	_driver.submit(MatchRecords.concede())

	# Act
	_driver.tick()
	_driver.tick()

	# Assert
	_assert_ended_cleanly(order, MatchRecords.REASON_CONCEDE)
	assert_int(_count(DECISION_EVENT)).is_equal(0)


func test_a_concede_mid_replay_ends_the_match_and_drops_the_rest() -> void:
	# Arrange
	_boss_plan(MatchDriverFixture.boss_plays(3))
	_charge_each_decision(_budget_usec() * 10)
	_driver.tick()
	var order: Array[String] = _record_end_order()

	# Act
	var result: Dictionary = _driver.submit(MatchRecords.concede())

	# Assert: dropped at once, not by a later tick
	assert_bool(result.accepted).is_true()
	_assert_ended_cleanly(order, MatchRecords.REASON_CONCEDE)
	_driver.tick()
	assert_int(_count(&"card_played")).is_equal(1)


func test_after_ended_the_driver_accepts_nothing_and_fires_no_second_end() -> void:
	# Arrange
	_build()
	var ends: Array[int] = []
	_driver.match_ended.connect(func(_result: Dictionary) -> void: ends.append(1))
	@warning_ignore("return_value_discarded")
	_driver.submit(MatchRecords.concede())
	var events_before: int = _log.size()

	# Act
	var result: Dictionary = _driver.submit(MatchRecords.end_turn(SIDE_PLAYER))
	var concede: Dictionary = _driver.submit(MatchRecords.concede())
	_driver.tick()

	# Assert
	assert_str(str(result.rejection.code)).is_equal(RulesEngine.R_MATCH_ENDED)
	assert_str(str(concede.rejection.code)).is_equal(RulesEngine.R_MATCH_ENDED)
	assert_int(ends.size()).is_equal(1)
	assert_int(_log.size()).is_equal(events_before)
	assert_array(_driver.legal_commands()).is_empty()


func test_the_signal_carries_the_engines_result_and_hooks_stay_readable() -> void:
	# Arrange
	_build()
	var results: Array[Dictionary] = []
	_driver.match_ended.connect(func(result: Dictionary) -> void: results.append(result))

	# Act
	@warning_ignore("return_value_discarded")
	_driver.submit(MatchRecords.concede())

	# Assert
	assert_dict(results[0]).is_equal(_driver._engine.result())
	assert_object(_driver.hooks()).is_not_null()
	assert_object(_driver.query()).is_not_null()
	assert_str(_driver.query().phase()).is_equal(MatchState.PHASE_ENDED)


func test_a_task_still_live_at_ended_is_discarded_when_it_returns() -> void:
	# Arrange: a task runs through the player's turn, as a forecast does
	_build()
	MatchDriverFixture.past_mulligan(_driver)
	var plan: TurnPlan = MatchDriverFixture.scripted_plan(_driver, MatchDriverFixture.boss_plays(1))
	_task.polls_before_done = 1
	MatchDriverFixture.start_plan(_driver, _task, plan)
	var state: MatchState = _driver._engine.state()
	var minion: Dictionary = BossAiBoard.place(_driver._engine, _db, SIDE_PLAYER, MatchDriverFixture.VANILLA)
	var hero: Dictionary = state.players[SIDE_BOSS].hero
	hero.damage_taken = _driver._engine.max_health(hero) - 1
	@warning_ignore("return_value_discarded")
	_driver.submit(MatchRecords.attack(SIDE_PLAYER, int(minion.entity_id), int(hero.entity_id)))
	var late: Dictionary = _driver.submit(MatchRecords.concede())
	var events_before: int = _log.size()
	var engine: CountingEngine = _driver._engine
	var submits_before: int = engine.submits

	# Act
	_driver.tick()
	_driver.tick()

	# Assert: no plan command reaches the engine
	assert_str(str(late.rejection.code)).is_equal(RulesEngine.R_MATCH_ENDED)
	assert_bool(_driver.is_planning()).is_false()
	assert_int(_log.size()).is_equal(events_before)
	assert_int(engine.submits).is_equal(submits_before)


func test_a_tick_that_ends_the_match_appends_nothing_after_the_end() -> void:
	# Arrange: the tick is over budget and applies a queued concede
	_build()
	MatchDriverFixture.to_boss_main(_driver)
	MatchDriverFixture.start_plan(_driver, _task, TurnPlan.new())
	@warning_ignore("return_value_discarded")
	_driver.submit(MatchRecords.concede())
	var clock: FakeClock = _clock
	var over: int = _budget_usec() + 1
	_task.on_poll = func() -> void: clock.now += over

	# Act
	_driver.tick()

	# Assert: the log sealed on `match_ended`
	var events: Array[Dictionary] = _log.events_since(0)
	assert_str(str(events[events.size() - 1].type)).is_equal("match_ended")
	assert_int(_count(FAULT_EVENT)).is_equal(0)


## How many events a match has logged at the boss's Main: a log capped at this has
## no room left there (rng-event-log rule 16).
func _events_at_boss_main() -> int:
	var measure: EventLog = EventLog.new(TestConstants.MAX_MATCH_EVENTS, EventLog.SCOPE_MATCH)
	var probe: MatchDriver = MatchDriver.new(MatchDriverFixture.match_config(measure), _db, {}, FakePlannerTask.new(), _clock.read)
	MatchDriverFixture.to_boss_main(probe)
	var events: int = measure.size()
	probe.shutdown()
	return events


func test_a_rejected_replay_command_at_the_cap_ends_the_match_with_no_fault_appended() -> void:
	# Arrange: the engine's own `command_rejected` is the append the log refuses
	var log: SealWatchLog = SealWatchLog.new(_events_at_boss_main(), EventLog.SCOPE_MATCH)
	_log = log
	_build()
	MatchDriverFixture.to_boss_main(_driver)
	var plan: TurnPlan = TurnPlan.new()
	plan.commands = [MatchRecords.play_card(SIDE_BOSS, BAD_HAND_INDEX, 0)]
	MatchDriverFixture.start_plan(_driver, _task, plan)
	var results: Array[Dictionary] = []
	_driver.match_ended.connect(func(result: Dictionary) -> void: results.append(result))

	# Act
	_driver.tick()

	# Assert
	assert_int(log.appends_after_seal).is_equal(0)
	assert_int(results.size()).is_equal(1)
	assert_str(str(results[0].reason)).is_equal(MatchRecords.REASON_EVENT_CAP)
	assert_bool(log.is_sealed()).is_true()
	assert_bool(_driver.is_planning()).is_false()


func test_a_refused_diagnostic_append_is_the_event_cap_fault() -> void:
	# Arrange
	_log = EventLog.new(_events_at_boss_main(), EventLog.SCOPE_MATCH)
	_build()
	MatchDriverFixture.to_boss_main(_driver)
	var plan: TurnPlan = TurnPlan.new()
	plan.commands = MatchDriverFixture.boss_plays(1)
	plan.diagnostics.append({TurnPlan.EVENT_KEY: String(DECISION_EVENT), TurnPlan.COMMAND_INDEX_KEY: 0, TurnPlan.DIAGNOSTIC_KEY: true})
	MatchDriverFixture.start_plan(_driver, _task, plan)
	var results: Array[Dictionary] = []
	_driver.match_ended.connect(func(result: Dictionary) -> void: results.append(result))

	# Act
	_driver.tick()

	# Assert
	assert_int(results.size()).is_equal(1)
	assert_str(str(results[0].reason)).is_equal(MatchRecords.REASON_EVENT_CAP)
	assert_bool(_log.is_sealed()).is_true()
	assert_int(_count(&"card_played")).is_equal(0)
	assert_bool(_driver.is_planning()).is_false()


# --- Shutdown ------------------------------------------------------------------


func test_shutdown_returns_only_after_the_task_ended_and_discards_its_result() -> void:
	# Arrange
	_build()
	MatchDriverFixture.to_boss_main(_driver)
	_task.polls_before_done = 3
	MatchDriverFixture.start_plan(_driver, _task, MatchDriverFixture.scripted_plan(_driver, MatchDriverFixture.boss_plays(1)))

	# Act
	_driver.shutdown()

	# Assert
	assert_int(_task.polls).is_equal(4)
	assert_int(_task.polls_after_done).is_equal(0)
	assert_bool(_task.is_live()).is_false()
	assert_bool(_driver.is_planning()).is_false()
	assert_int(_count(DECISION_EVENT)).is_equal(0)
	assert_object(_driver._sandbox).is_null()


func test_shutdown_with_no_task_does_not_poll() -> void:
	# Arrange
	_build()

	# Act
	_driver.shutdown()

	# Assert
	assert_int(_task.polls).is_equal(0)


func test_shutdown_twice_is_harmless_and_a_later_submit_is_refused() -> void:
	# Arrange
	_build()
	_driver.shutdown()

	# Act
	_driver.shutdown()
	var result: Dictionary = _driver.submit(MatchRecords.concede())

	# Assert
	assert_str(str(result.rejection.code)).is_equal(RulesEngine.R_MATCH_ENDED)


## Weak references to the whole graph of a driver left as [param leave] says, with
## every strong reference gone once this returns.
func _graph_after(end_the_match: bool) -> Array[WeakRef]:
	var log: EventLog = EventLog.new(TestConstants.MAX_MATCH_EVENTS, EventLog.SCOPE_MATCH)
	var task: FakePlannerTask = FakePlannerTask.new()
	var driver: MatchDriver = MatchDriver.new(MatchDriverFixture.match_config(log), _db, {}, task)
	MatchDriverFixture.to_boss_main(driver)
	task.polls_before_done = 2
	MatchDriverFixture.start_plan(driver, task, MatchDriverFixture.scripted_plan(driver, MatchDriverFixture.boss_plays(1)))
	var refs: Array[WeakRef] = [
		weakref(driver), weakref(driver._engine), weakref(driver._resolver), weakref(driver._boss_ai),
		weakref(driver._sandbox), weakref(driver._query), weakref(task), weakref(log),
	]
	if end_the_match:
		@warning_ignore("return_value_discarded")
		driver.submit(MatchRecords.concede())
		driver.tick()
		driver.tick()
		driver.tick()
	driver.shutdown()
	return refs


func test_the_driver_graph_is_freed_after_shutdown_of_a_live_match() -> void:
	# Act
	var refs: Array[WeakRef] = _graph_after(false)

	# Assert
	for ref: WeakRef in refs:
		assert_object(ref.get_ref()).is_null()


func test_the_driver_graph_is_freed_after_shutdown_of_an_ended_match() -> void:
	# Act
	var refs: Array[WeakRef] = _graph_after(true)

	# Assert
	for ref: WeakRef in refs:
		assert_object(ref.get_ref()).is_null()


# --- Real boss turns on the shipped data ---------------------------------------


func _shipped() -> CardDatabase:
	var boot: Node = auto_free(BOOT_SCRIPT.new())
	var db: CardDatabase = CardDatabase.new(DataLoader.new(SHIPPED_ROOT))
	db.load(boot._collect_validators(null, true))
	return db


## A match on the shipped data, [constant REAL_ROUNDS] rounds in which the player
## passes and the boss plans through `BossAI.plan_task`. The clock is [param clock].
## Returns the log; the driver is shut down.
func _real_match(db: CardDatabase, clock: FakeClock) -> EventLog:
	var boss_def: Dictionary = db.boss(REAL_BOSS)
	var hero: Dictionary = db.hero("hero_war")
	var log: EventLog = EventLog.new(TestConstants.MAX_MATCH_EVENTS, EventLog.SCOPE_MATCH)
	var config: Dictionary = MatchFactory.make_started_config(TestRngService.new(REAL_SEED), null, {
		"log": log,
		"player": {"deck": hero.starter_deck},
		"boss": {"boss_def_id": REAL_BOSS, "deck": boss_def.deck, "health": boss_def.health, "ai_id": boss_def.ai_profile},
	})
	var driver: MatchDriver = MatchDriver.new(config, db, {}, ImmediatePlannerTask.new(), clock.read)
	MatchDriverFixture.past_mulligan(driver)
	for _round: int in REAL_ROUNDS:
		var ended: Dictionary = driver.submit(MatchRecords.end_turn(SIDE_PLAYER))
		assert_bool(ended.accepted).is_true()
		if not driver.is_planning():
			driver._start_plan_task()
		while driver.is_planning():
			driver.tick()
		if driver.query().phase() == MatchState.PHASE_ENDED:
			break
	driver.shutdown()
	return log


func test_real_boss_turns_replay_with_no_divergence() -> void:
	# Act
	var log: EventLog = _real_match(_shipped(), FakeClock.new())

	# Assert: the plans were real, and the live engine matched every one of them
	var types: Array[String] = []
	for event: Dictionary in log.events_since(0):
		types.append(str(event.type))
	assert_bool(types.count("ai_decision") > REAL_ROUNDS).is_true()
	assert_bool(types.count("card_played") > 0).is_true()
	assert_int(types.count("ai_fault")).is_equal(0)
	assert_int(types.count("command_rejected")).is_equal(0)


func test_one_seed_gives_a_byte_identical_log_however_replay_is_sliced() -> void:
	# Arrange
	var db: CardDatabase = _shipped()
	var sliced: FakeClock = FakeClock.new()
	sliced.step = int(db.config("ai_profiles").runtime.replay_budget_ms) * USEC_PER_MSEC

	# Act: all in one tick, then one command per tick
	var whole: EventLog = _real_match(db, FakeClock.new())
	var again: EventLog = _real_match(db, FakeClock.new())
	var stepped: EventLog = _real_match(db, sliced)

	# Assert: a wall-clock budget paces the replay and never changes it. A fault from
	# the stepping clock is the one difference allowed, and it carries no game state.
	assert_str(again.to_json()).is_equal(whole.to_json())
	assert_int(TurnPlan.checksum(stepped.events_since(0))).is_equal(TurnPlan.checksum(whole.events_since(0)))
