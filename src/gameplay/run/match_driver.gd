## One match attempt, rules side (ADR-0008; ADR-0006 for the planner protocol;
## design/gdd/run-structure.md Interactions "Boss AI"; TR-run-structure-005).
##
## `RunMachine.begin_match()` builds one through the injected `driver_factory`. It
## owns the live `RulesEngine`, its `EffectResolver` and the `BossAI`, and it is the
## only path from outside the rules tier into `RulesEngine.submit`. Rules tier: no
## Node, no autoload, and no coroutine here, so a task's work is always a Callable
## built in `src/ai/` ([method BossAI.plan_task]).
##
## **The gate** ([method submit]) stamps `issuer = "player"` and goes straight to
## the live engine, which answers `NOT_YOUR_TURN` / `CHOICE_PENDING` itself: there
## is no driver-side lock, and [method is_planning] is a UI hint. The one rule on top
## is the concede slot: a `concede` while a task is live waits in
## [member _queued_concede] and is applied when the task returns, its result
## discarded, so no boss command runs after the player conceded.
##
## **A task** is live from [method _start_plan_task] until [method _on_task_done]
## has taken its result, and owns [member _sandbox], which ends with it. Which task
## starts when is the [method _after_engine_step] table (story 014).
##
## Commands and results are the plain Dictionaries of [MatchRecords], and
## `MatchConfig` is a Dictionary (run-structure R3).
## [codeblock]
## var driver := MatchDriver.new(config, db, settings, planner_task)
## driver.subscribe(view.on_event)
## var result: Dictionary = driver.submit(MatchRecords.mulligan(keep_mask))
## # each frame:
## driver.tick()
## [/codeblock]
class_name MatchDriver
extends RefCounted

## Emitted once on the main thread, after the `match_ended` event reached the
## log's subscribers. [param result] is the C14 `MatchResult`.
signal match_ended(result: Dictionary)

## `rejection.detail` of a queued concede (`ENGINE_BUSY` is reused because the C2
## set is closed; ADR-0008 Decision 2).
const DETAIL_CONCEDE_QUEUED: String = "concede_queued"

var _log: Variant = null
var _settings: Dictionary = {}
var _planner_task: PlannerTask = null
var _resolver: EffectResolver = null
var _engine: RulesEngine = null
var _boss_ai: BossAI = null
var _query: MatchQuery = null
## The running task, [member _planner_task] while one is live, else null.
var _task: PlannerTask = null
## The clone the running task works on; ended when the task is released.
var _sandbox: RulesEngine = null
## The plan being replayed, and the next command in it.
var _pending_plan: TurnPlan = null
var _replay_index: int = 0
## The one concede slot; empty when nothing is queued. A field, never a captured
## local: lambdas capture by value.
var _queued_concede: Dictionary = {}


## Builds the match in the ADR-0008 Decision 1 order, then `engine.start(config)`
## and the first [method _after_engine_step]. [param config] is the `MatchConfig`;
## its `log` is the fresh match log. [param db] is the frozen database,
## [param settings] the settings snapshot and [param planner_task] the task the
## composition root picked (ADR-0006).
## [codeblock]
## var driver := MatchDriver.new(config, db, settings_snapshot, WorkerPoolPlannerTask.new())
## [/codeblock]
func _init(config: Dictionary, db: CardDatabase, settings: Dictionary, planner_task: PlannerTask) -> void:
	_log = config.log
	_settings = settings
	_planner_task = planner_task
	var profiles: Dictionary = db.config("ai_profiles")
	var boss_def: Dictionary = db.boss(str(config.boss.boss_def_id))
	var profile: Dictionary = _resolve_profile(profiles, boss_def, int(config.band))
	_resolver = _build_resolver(db, _hero_set(db, str(config.player.hero_def_id)))
	_engine = _build_engine(db, _resolver)
	_boss_ai = _build_boss_ai(boss_def, profile, config, db, profiles)
	_query = MatchQuery.new(_engine, db, settings)
	_engine.start(config)
	_after_engine_step()


## The player's way in (ADR-0008 Decision 2): [param command] goes to the live
## engine as `issuer = "player"`, and its `CommandResult` comes back. Synchronous,
## main thread. A `concede` while a task is live is queued and answered
## `ENGINE_BUSY / concede_queued` with `events: [-1, -1]`; a second one takes the
## same slot. [param command] itself is left as given.
## [codeblock]
## var result: Dictionary = driver.submit(MatchRecords.play_card("player", 0, 2))
## if not result.accepted: show(result.rejection.code)
## [/codeblock]
func submit(command: Dictionary) -> Dictionary:
	var stamped: Dictionary = command.duplicate(true)
	stamped["issuer"] = MatchRecords.SIDE_PLAYER
	if _task != null and str(stamped.get("type", "")) == MatchRecords.CMD_CONCEDE:
		_queued_concede = stamped
		return MatchRecords.command_result(false, RulesEngine.R_ENGINE_BUSY, DETAIL_CONCEDE_QUEUED, -1, -1)
	var result: Dictionary = _engine.submit(stamped)
	_after_engine_step()
	return result


## The commands the live engine would accept now.
func legal_commands() -> Array:
	return _engine.legal_commands()


## The read model over the live engine, built once; it answers at all times.
func query() -> MatchQuery:
	return _query


## Registers [param callback] on the match log itself (ADR-0003: once per event, in
## `seq` order, after the append). There is no buffer here.
func subscribe(callback: Callable) -> void:
	_log.subscribe(callback)


## Every event of the match log after [param seq].
func events_since(seq: int) -> Array:
	return _log.events_since(seq)


## The match's hook registry, for `Treasures.collect_state`. Read after `Ended` only.
func hooks() -> HookRegistry:
	return _engine.state().hooks


## `true` while a task is live or a plan is pending replay: the UI's "boss thinking"
## hint, not a lock.
func is_planning() -> bool:
	return _task != null or _pending_plan != null


## Once per frame: polls a live task, at most once, and takes its result when it
## finished.
func tick() -> void:
	if _task != null and _task.poll():
		_on_task_done()


## Runs after every engine step and replayed command, and decides what the driver
## does next from the engine's phase (ADR-0008 Decision 3).
## Story 014 adds the forecast, plan and choose rows of the table.
func _after_engine_step() -> void:
	if _engine.phase() == MatchState.PHASE_ENDED:
		_pending_plan = null


## Starts the boss's planner on a clone (ADR-0006). `BossTurn.Main` calls this once
## story 014's row exists.
func _start_plan_task() -> void:
	_sandbox = _engine.clone()
	_task = _planner_task
	_task.start(_boss_ai.plan_task(_sandbox, _task))


## A finished task: a queued concede discards its result and is submitted.
func _on_task_done() -> void:
	_release_task()
	if not _queued_concede.is_empty():
		var concede: Dictionary = _queued_concede
		_queued_concede = {}
		@warning_ignore("return_value_discarded")
		_engine.submit(concede)
		_after_engine_step()


## Ends the task's sandbox, which the driver owns (`BossAI.plan_task`).
func _release_task() -> void:
	_task = null
	if _sandbox != null:
		_sandbox.end_match()
		_sandbox = null


## The run hero's set, which `MatchState` does not carry (card-effects F4). A
## `hero_def_id` with no record gives `""`: `engine.start` reports it (C3 step 2).
static func _hero_set(db: CardDatabase, hero_def_id: String) -> String:
	for record: Dictionary in db.heroes():
		if record.id == hero_def_id:
			return str(record.set)
	return ""


# The construction steps, one method each so a test can record their order.


func _resolve_profile(profiles: Dictionary, boss_def: Dictionary, band: int) -> Dictionary:
	return ProfileResolver.resolve(profiles, boss_def, band)


func _build_resolver(db: CardDatabase, hero_set: String) -> EffectResolver:
	return EffectResolver.new(db, db.config("card_effects"), hero_set)


func _build_engine(db: CardDatabase, resolver: EffectResolver) -> RulesEngine:
	return RulesEngine.new(db, db.config("match_rules"), resolver)


func _build_boss_ai(boss_def: Dictionary, profile: Dictionary, config: Dictionary, db: CardDatabase, profiles: Dictionary) -> BossAI:
	return BossAI.new(boss_def, profile, int(config.band), config.rng_ai, profiles.op_values, config.log, db, profiles.keyword_values)
