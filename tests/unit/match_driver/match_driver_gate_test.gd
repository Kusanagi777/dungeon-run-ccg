## Unit tests for `MatchDriver`: construction order, the command gate and the
## concede slot (story boss-ai-match-driver/story-013; ADR-0008 Decisions 1-2,
## Validation Criteria `match_driver_gate_test`; ADR-0006; TR-run-structure-005).
##
## The driver is built over [MatchDriverFixture]'s database double, on the
## production `EffectResolver`, `RulesEngine` and `BossAI`. Tasks are
## [FakePlannerTask]s: no worker starts here. The schedule rows are story 014's,
## so a boss task is started by [method MatchDriverFixture.start_plan].
extends GdUnitTestSuite

const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const SIDE_BOSS: String = MatchRecords.SIDE_BOSS
## Far more polls than a test ticks: the task stays live until `finish()`.
const STAYS_LIVE: int = 1000

var _db: MatchDriverFixture.FixtureDatabase
var _log: TestEventLog
var _task: FakePlannerTask
var _driver: MatchDriver


## An engine that records [method start] in [member order].
class SpyEngine:
	extends RulesEngine

	var order: Array[String] = []

	func start(config: Dictionary) -> void:
		order.append("start")
		super(config)


## A driver that records each construction step it runs.
class SpyDriver:
	extends MatchDriver

	var order: Array[String] = []

	func _init(config: Dictionary, db: CardDatabase, settings: Dictionary, task: PlannerTask) -> void:
		super(config, db, settings, task)

	func _resolve_profile(profiles: Dictionary, boss_def: Dictionary, band: int) -> Dictionary:
		order.append("profile")
		return super(profiles, boss_def, band)

	func _build_resolver(db: CardDatabase, hero_set: String) -> EffectResolver:
		order.append("resolver")
		return super(db, hero_set)

	func _build_engine(db: CardDatabase, resolver: EffectResolver) -> RulesEngine:
		order.append("engine")
		var engine := SpyEngine.new(db, db.config("match_rules"), resolver)
		engine.order = order
		return engine

	func _build_boss_ai(boss_def: Dictionary, profile: Dictionary, config: Dictionary, db: CardDatabase, profiles: Dictionary) -> BossAI:
		order.append("boss_ai")
		return super(boss_def, profile, config, db, profiles)

	func _after_engine_step() -> void:
		order.append("step")
		super()


func before_test() -> void:
	_db = MatchDriverFixture.database()
	_log = TestEventLog.new()
	_task = FakePlannerTask.new()
	_driver = null


func after_test() -> void:
	if _driver != null:
		_driver.shutdown()
	_driver = null


func _build(player_deck: Array = [], boss_deck: Array = []) -> MatchDriver:
	_driver = MatchDriver.new(MatchDriverFixture.match_config(_log, player_deck, boss_deck), _db, {}, _task)
	return _driver


## A driver at the boss's Main with a plan of [param plays] boss plays in a task
## that stays live until told otherwise.
func _with_live_plan(plays: int = 1) -> TurnPlan:
	_build()
	MatchDriverFixture.to_boss_main(_driver)
	var plan: TurnPlan = MatchDriverFixture.scripted_plan(_driver, MatchDriverFixture.boss_plays(plays))
	_task.polls_before_done = STAYS_LIVE
	MatchDriverFixture.start_plan(_driver, _task, plan)
	return plan


func _finish_task() -> void:
	_task.finish()
	_driver.tick()


# --- Construction --------------------------------------------------------------


func test_construction_runs_profile_resolver_engine_boss_ai_start_then_the_step() -> void:
	# Act
	var spy := SpyDriver.new(MatchDriverFixture.match_config(_log), _db, {}, _task)
	_driver = spy

	# Assert
	assert_array(spy.order).is_equal(["profile", "resolver", "engine", "boss_ai", "start", "step"])


func test_construction_stops_at_mulligan_with_no_task_started() -> void:
	# Act
	_build()

	# Assert: match-rules C3 ends setup in Mulligan, so there is nothing to forecast.
	assert_str(_driver.query().phase()).is_equal(MatchState.PHASE_MULLIGAN)
	assert_int(_task.starts).is_equal(0)
	assert_bool(_driver.is_planning()).is_false()


func test_legal_commands_is_the_engines_list() -> void:
	# Arrange
	_build()

	# Act
	var commands: Array = _driver.legal_commands()

	# Assert
	assert_array(commands).is_equal(_driver._engine.legal_commands())
	assert_str(str(commands[0].type)).is_equal(MatchRecords.CMD_MULLIGAN)


func test_events_since_is_the_match_logs_slice() -> void:
	# Arrange
	_build()
	var cut: int = _log.size() - 1

	# Act
	var events: Array = _driver.events_since(cut)

	# Assert
	assert_int(events.size()).is_equal(1)
	assert_int(int(events[0].seq)).is_equal(_log.size())


func test_subscribe_delivers_each_later_event_once_in_seq_order() -> void:
	# Arrange
	_build()
	var seen: Array[int] = []
	var first_new: int = _log.size() + 1

	# Act
	_driver.subscribe(func(event: Dictionary) -> void: seen.append(int(event.seq)))
	MatchDriverFixture.past_mulligan(_driver)

	# Assert: straight off the log, nothing replayed from before the subscription
	var expected: Array[int] = []
	for seq: int in range(first_new, _log.size() + 1):
		expected.append(seq)
	assert_array(seen).is_equal(expected)


func test_a_discover_in_a_driver_built_match_offers_from_the_heros_set() -> void:
	# Arrange
	_build(MatchDriverFixture.deck_of(MatchDriverFixture.DISCOVER))
	MatchDriverFixture.past_mulligan(_driver)

	# Act
	var played: Dictionary = _driver.submit(MatchRecords.play_card(SIDE_PLAYER, 0))

	# Assert: card-effects F4, the third `EffectResolver` argument
	assert_bool(played.accepted).is_true()
	assert_array(_db.pool_requests).contains([MatchDriverFixture.HERO_SET])
	assert_str(_driver.query().phase()).is_equal(MatchState.PHASE_CHOICE)
	assert_int((_driver.query().pending_choice().options as Array).size()).is_equal(MatchDriverFixture.POOL.size())


func test_query_keeps_a_boss_choices_options_from_the_view() -> void:
	# Arrange: the boss's Discover is pending, its options real on the engine
	_build([], MatchDriverFixture.deck_of(MatchDriverFixture.DISCOVER))
	MatchDriverFixture.to_boss_main(_driver)
	assert_bool(_driver._engine.submit(MatchRecords.play_card(SIDE_BOSS, 0)).accepted).is_true()
	assert_bool((_driver._engine.pending_choice().options as Array).is_empty()).is_false()

	# Act
	var choice: Dictionary = _driver.query().pending_choice()

	# Assert: match-ui "the player never sees the options"; the label still has its side
	assert_str(str(choice.side)).is_equal(SIDE_BOSS)
	assert_array(choice.options).is_empty()
	assert_bool(str(choice).contains(MatchDriverFixture.POOL[0])).is_false()


func test_query_leaves_no_choice_as_null() -> void:
	# Arrange
	_build()

	# Act
	var choice: Variant = _driver.query().pending_choice()

	# Assert
	assert_object(choice).is_null()


# --- The gate ------------------------------------------------------------------


func test_a_player_command_during_a_boss_task_reaches_the_engine_as_not_your_turn() -> void:
	# Arrange
	_with_live_plan()

	# Act
	var result: Dictionary = _driver.submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0))

	# Assert
	assert_bool(result.accepted).is_false()
	assert_str(str(result.rejection.code)).is_equal(RulesEngine.R_NOT_YOUR_TURN)
	var rejected: Dictionary = _log.last()
	assert_str(str(rejected.type)).is_equal("command_rejected")
	assert_str(str(rejected.payload.command.issuer)).is_equal(SIDE_PLAYER)


func test_query_answers_while_a_boss_task_is_live() -> void:
	# Arrange
	_with_live_plan()

	# Act
	var query: MatchQuery = _driver.query()

	# Assert: is_planning is a hint, not a lock
	assert_bool(_driver.is_planning()).is_true()
	assert_str(query.phase()).is_equal(MatchState.PHASE_MAIN)
	assert_bool(query.legal_commands().is_empty()).is_false()
	assert_object(_driver.query()).is_same(query)


func test_a_player_command_during_a_boss_choice_task_is_choice_pending() -> void:
	# Arrange: the boss's Discover is pending on the live engine, a task is live
	_build([], MatchDriverFixture.deck_of(MatchDriverFixture.DISCOVER))
	MatchDriverFixture.to_boss_main(_driver)
	assert_bool(_driver._engine.submit(MatchRecords.play_card(SIDE_BOSS, 0)).accepted).is_true()
	_task.polls_before_done = STAYS_LIVE
	MatchDriverFixture.start_plan(_driver, _task, TurnPlan.new())

	# Act
	var result: Dictionary = _driver.submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0))

	# Assert
	assert_str(str(result.rejection.code)).is_equal(RulesEngine.R_CHOICE_PENDING)


func test_submit_stamps_the_player_whatever_the_command_says() -> void:
	# Arrange: TD-006, the UI cannot issue a boss command
	_build()
	MatchDriverFixture.to_boss_main(_driver)
	var forged: Dictionary = MatchRecords.end_turn(SIDE_BOSS)

	# Act
	var result: Dictionary = _driver.submit(forged)

	# Assert
	assert_str(str(result.rejection.code)).is_equal(RulesEngine.R_NOT_YOUR_TURN)
	assert_str(str(_log.last().payload.command.issuer)).is_equal(SIDE_PLAYER)
	assert_str(str(forged.issuer)).is_equal(SIDE_BOSS)


func test_a_stray_argument_is_refused_through_the_driver() -> void:
	# Arrange: DD-X17, `submit` accepts only what `legal_commands()` lists
	_build(MatchDriverFixture.deck_of(MatchDriverFixture.DISCOVER))
	MatchDriverFixture.past_mulligan(_driver)

	# Act
	var result: Dictionary = _driver.submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0))

	# Assert
	assert_str(str(result.rejection.code)).is_equal(RulesEngine.R_INVALID_POSITION)


# --- The concede slot ----------------------------------------------------------


func test_a_concede_while_a_task_is_live_is_queued() -> void:
	# Arrange
	_with_live_plan()
	var seq_before: int = _log.size()

	# Act
	var result: Dictionary = _driver.submit(MatchRecords.concede())

	# Assert
	assert_bool(result.accepted).is_false()
	assert_str(str(result.rejection.code)).is_equal(RulesEngine.R_ENGINE_BUSY)
	assert_str(str(result.rejection.detail)).is_equal(MatchDriver.DETAIL_CONCEDE_QUEUED)
	assert_array(result.events).is_equal([-1, -1])
	assert_int(_log.size()).is_equal(seq_before)
	assert_str(_driver.query().phase()).is_equal(MatchState.PHASE_MAIN)


func test_a_second_concede_does_not_grow_the_slot() -> void:
	# Arrange
	_with_live_plan()
	@warning_ignore("return_value_discarded")
	_driver.submit(MatchRecords.concede())

	# Act
	var second: Dictionary = _driver.submit(MatchRecords.concede())
	_finish_task()

	# Assert: one concede applied, nothing refused
	assert_str(str(second.rejection.detail)).is_equal(MatchDriver.DETAIL_CONCEDE_QUEUED)
	assert_int(_log.count(&"match_ended")).is_equal(1)
	assert_int(_log.count(&"command_rejected")).is_equal(0)


func test_a_queued_concede_discards_the_plan_and_ends_the_match_when_the_task_returns() -> void:
	# Arrange
	_with_live_plan(3)
	@warning_ignore("return_value_discarded")
	_driver.submit(MatchRecords.concede())

	# Act
	_finish_task()

	# Assert
	var ended: Dictionary = _log.first(&"match_ended")
	assert_str(str(ended.payload.reason)).is_equal(MatchRecords.REASON_CONCEDE)
	assert_int(_log.count(&"ai_decision")).is_equal(0)
	assert_int(_log.count(&"card_played")).is_equal(0)
	assert_bool(_driver.is_planning()).is_false()


func test_a_queued_concede_survives_ticks_while_the_task_stays_live() -> void:
	# Arrange
	_with_live_plan()
	@warning_ignore("return_value_discarded")
	_driver.submit(MatchRecords.concede())

	# Act
	_driver.tick()
	_driver.tick()

	# Assert: still queued, then applied
	assert_int(_log.count(&"match_ended")).is_equal(0)
	_finish_task()
	assert_int(_log.count(&"match_ended")).is_equal(1)


func test_a_concede_with_no_task_live_and_a_plan_part_replayed_drops_the_rest() -> void:
	# Arrange: command 0 of 3 has completed; replay itself is story 015's
	_build()
	MatchDriverFixture.to_boss_main(_driver)
	var plan: TurnPlan = MatchDriverFixture.scripted_plan(_driver, MatchDriverFixture.boss_plays(3))
	assert_bool(_driver._engine.submit(plan.commands[0]).accepted).is_true()
	_driver._pending_plan = plan
	_driver._replay_index = 1
	assert_bool(_driver.is_planning()).is_true()

	# Act
	var result: Dictionary = _driver.submit(MatchRecords.concede())

	# Assert
	assert_bool(result.accepted).is_true()
	assert_str(str(_log.first(&"match_ended").payload.reason)).is_equal(MatchRecords.REASON_CONCEDE)
	assert_int(_log.count(&"card_played")).is_equal(1)
	assert_bool(_driver.is_planning()).is_false()


func test_a_concede_during_a_boss_choice_with_no_task_drops_the_choice() -> void:
	# Arrange
	_build([], MatchDriverFixture.deck_of(MatchDriverFixture.DISCOVER))
	MatchDriverFixture.to_boss_main(_driver)
	assert_bool(_driver._engine.submit(MatchRecords.play_card(SIDE_BOSS, 0)).accepted).is_true()
	assert_str(_driver.query().phase()).is_equal(MatchState.PHASE_CHOICE)

	# Act
	var result: Dictionary = _driver.submit(MatchRecords.concede())

	# Assert
	assert_bool(result.accepted).is_true()
	assert_str(str(_log.first(&"match_ended").payload.reason)).is_equal(MatchRecords.REASON_CONCEDE)
	assert_int(_log.count(&"discover_picked")).is_equal(0)
