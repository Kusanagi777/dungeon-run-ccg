## Fixtures for the `MatchDriver` suites (boss-ai-match-driver stories 013, 015).
##
## [FixtureDatabase] is a `CardDatabase` double that also serves what the driver
## reads at construction: the `ai_profiles`, `card_effects` and `match_rules`
## bodies, one BossDef and one HeroDef. [method match_config] builds a `MatchConfig`
## over its cards, [method scripted_plan] a hand-made [TurnPlan] whose checksum
## comes from running it on a clone.
## [codeblock]
## var db := MatchDriverFixture.database()
## var task := FakePlannerTask.new()
## var driver := MatchDriver.new(MatchDriverFixture.match_config(TestEventLog.new()), db, {}, MatchDriverFixture.same_task(task))
## MatchDriverFixture.to_boss_main(driver)
## MatchDriverFixture.start_plan(driver, task, MatchDriverFixture.scripted_plan(driver, [
##     MatchRecords.end_turn(MatchRecords.SIDE_BOSS),
## ]))
## [/codeblock]
class_name MatchDriverFixture
extends RefCounted

const HERO_ID: String = "hero_war"
const HERO_SET: String = "war"
const BOSS_ID: String = "boss_test"
const POWER_ID: String = "power_test"
## A 0-cost 1/1: a boss can play several in one turn at any mana.
const VANILLA: String = "fixture_driver_vanilla"
## A 0-cost spell that Discovers from `pool: collectible`.
const DISCOVER: String = "fixture_driver_discover"
## A 0-cost 1/1 whose Deathrattle Discovers: killed on the other side's turn, its
## owner owes a Choice there (boss-ai Edge Cases).
const RATTLE: String = "fixture_driver_rattle"
## What `collectible_pool` answers; the Discover offers from these.
const POOL: Array[String] = ["fixture_driver_pool_a", "fixture_driver_pool_b", "fixture_driver_pool_c"]
## Cards per deck: the starting hands plus a few turns of draws, no fatigue.
const DECK_SIZE: int = 20
const SEED: int = 5
const EVENT_DECISION: String = "ai_decision"


## A `CardDatabase` that answers the driver's construction reads from memory.
class FixtureDatabase:
	extends BossAiBoard.FakeCardDatabase

	## `config()` bodies by name.
	var bodies: Dictionary = {}
	## Every set `collectible_pool` was asked for, in order.
	var pool_requests: Array[String] = []

	func _init(by_id: Dictionary) -> void:
		super(by_id)

	func config(config_name: String) -> Variant:
		return bodies.get(config_name)

	func boss(id: String) -> Variant:
		return records.get(id)

	func heroes() -> Array:
		return [records[HERO_ID]]

	func collectible_pool(hero_set: String, collection_id: String = "") -> Array:
		pool_requests.append(hero_set)
		var pool: Array = []
		for id: String in POOL:
			pool.append(records[id])
		return pool


## A task factory for a driver, as DD-X31 has it: a fresh [FakePlannerTask] per call,
## each one kept, so a test scripts the task the driver has just started.
class TaskFactory:
	extends RefCounted

	## Every task made, oldest first.
	var made: Array[FakePlannerTask] = []

	func make() -> PlannerTask:
		var task := FakePlannerTask.new()
		made.append(task)
		return task

	## The task made last, which is the driver's running one if any is.
	func last() -> FakePlannerTask:
		return made.back()


## A [FixtureDatabase] with [param rules_overrides] on `match_rules`.
static func database(rules_overrides: Dictionary = {}) -> FixtureDatabase:
	var discover_op: Dictionary = CardFactory.make_op("discover", {"pool": "collectible"})
	var by_id: Dictionary = {
		HERO_ID: CardFactory.make_hero_def(HERO_ID, HERO_SET),
		BOSS_ID: CardFactory.make_boss_def(BOSS_ID, 1),
		POWER_ID: CardFactory.make_hero_power_def(POWER_ID),
		VANILLA: CardFactory.make_minion(VANILLA, 0, 1, 1),
		DISCOVER: CardFactory.make_spell(DISCOVER, 0, [CardFactory.make_effect("cast", [discover_op])]),
		RATTLE: CardFactory.make_minion(RATTLE, 0, 1, 1, ["deathrattle"], {"effects": [CardFactory.make_effect("deathrattle", [discover_op])]}),
	}
	for id: String in POOL:
		by_id[id] = CardFactory.make_minion(id, 1, 1, 1)
	var db := FixtureDatabase.new(by_id)
	db.bodies = {
		"ai_profiles": BossAiBoard.stub_config(),
		"card_effects": BossAiBoard.effects_config(),
		"match_rules": MatchFactory.make_rules_config(rules_overrides),
	}
	return db


## [param count] copies of [param card_id].
static func deck_of(card_id: String, count: int = DECK_SIZE) -> Array:
	var deck: Array = []
	for _i: int in count:
		deck.append(card_id)
	return deck


## A `MatchConfig` on [param log] (a `TestEventLog` or an `EventLog`) with
## [param player_deck] and [param boss_deck], [constant VANILLA] when empty.
static func match_config(log: Variant, player_deck: Array = [], boss_deck: Array = []) -> Dictionary:
	return MatchFactory.make_started_config(TestRngService.new(SEED), null, {
		"log": log,
		"player": {"deck": player_deck if not player_deck.is_empty() else deck_of(VANILLA)},
		"boss": {"boss_def_id": BOSS_ID, "deck": boss_deck if not boss_deck.is_empty() else deck_of(VANILLA)},
	})


## A factory that always answers [param task], for a suite that drives one
## [FakePlannerTask], which unlike a real task can restart. Production factories make
## a fresh task per call (DD-X31).
static func same_task(task: PlannerTask) -> Callable:
	return func() -> PlannerTask: return task


## Keeps every card, leaving the player at Main of turn 1.
static func past_mulligan(driver: MatchDriver) -> void:
	var kept: Dictionary = driver.submit(driver.legal_commands()[0])
	GameAssertions.fail_if(not kept.accepted, "mulligan rejected")


## The keep-all mulligan and the player's `end_turn`, through the driver, then one
## tick: the turn's forecast returns stale and the `BossTurn.Main` row starts the plan
## task, live when this returns.
static func to_boss_main(driver: MatchDriver) -> void:
	past_mulligan(driver)
	var ended: Dictionary = driver.submit(MatchRecords.end_turn(MatchRecords.SIDE_PLAYER))
	GameAssertions.fail_if(not ended.accepted, "player end_turn rejected")
	driver.tick()


## [param count] boss plays of the leftmost hand card.
static func boss_plays(count: int) -> Array:
	var commands: Array = []
	for _i: int in count:
		commands.append(MatchRecords.play_card(MatchRecords.SIDE_BOSS, 0, 0))
	return commands


## A [TurnPlan] of [param commands], one `ai_decision` before each, whose
## `expected_checksum` is what those commands log on a clone of the driver's
## engine: a true plan, as the planner would return it.
static func scripted_plan(driver: MatchDriver, commands: Array) -> TurnPlan:
	var plan: TurnPlan = TurnPlan.new()
	var sandbox: RulesEngine = driver._engine.clone()
	for index: int in commands.size():
		plan.commands.append(commands[index])
		plan.diagnostics.append({
			TurnPlan.EVENT_KEY: EVENT_DECISION,
			TurnPlan.COMMAND_INDEX_KEY: index,
			TurnPlan.DIAGNOSTIC_KEY: true,
			"chosen": index,
		})
		@warning_ignore("return_value_discarded")
		sandbox.submit((commands[index] as Dictionary).duplicate(true))
	plan.expected_checksum = TurnPlan.checksum(sandbox.state().log.events_since(0))
	sandbox.end_match()
	return plan


## Scripts the running [param task] (a [FakePlannerTask]) to return [param plan] after
## its [member FakePlannerTask.polls_before_done]. The schedule started the task
## ([method to_boss_main]), so nothing is started here.
static func start_plan(_driver: MatchDriver, task: FakePlannerTask, plan: TurnPlan) -> void:
	task.scripted_result = plan
	task.rearm()
