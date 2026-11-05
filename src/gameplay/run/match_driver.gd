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
## **Replay** ([method tick]) runs a returned [TurnPlan] into the live engine on the
## main thread: each command's diagnostics at `cause_seq = 0`, then the command as
## `issuer = "boss"`, then [method _after_engine_step]. It stops for the frame once
## `replay_budget_ms` is spent, after at least one command. A rejected command, or a
## checksum that differs at the end, is `ai_fault {replay_divergence}` and `end_turn`.
##
## **`Ended`** is seen by polling `phase()` after each step: the plan is dropped, the
## engine torn down, and [signal match_ended] fires. The event has by then reached
## every subscriber, because the log delivers it inside the append. No engine signal
## is connected.
##
## **The clock** is injected, as on [TimeSlicedPlannerTask], so a test drives the
## budget. It paces replay and never changes what is replayed.
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
## `ai_fault.reason`: the live engine refused a plan command, or the replay's
## checksum differs (ADR-0006).
const FAULT_REPLAY_DIVERGENCE: String = "replay_divergence"
## `ai_fault.reason`: in a debug build, the driver's own work in one [method tick]
## passed the budget (boss-ai A30).
const FAULT_TICK_OVER_BUDGET: String = "tick_over_budget"
const USEC_PER_MSEC: int = 1000

var _log: Variant = null
var _settings: Dictionary = {}
var _planner_task: PlannerTask = null
## A `Callable() -> int` of microseconds.
var _clock: Callable
## `runtime.replay_budget_ms`, read once at construction.
var _replay_budget_usec: int = 0
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
## The log's last `seq` when the plan began: what it gained since is the replay.
var _replay_start_seq: int = 0
## The one concede slot; empty when nothing is queued. A field, never a captured
## local: lambdas capture by value.
var _queued_concede: Dictionary = {}
## `true` once `Ended` was handled: nothing further is accepted or appended.
var _ended: bool = false
## This tick's time inside the engine and the log, whose subscribers are Match UI's
## budget and not the driver's own work.
var _outside_usec: int = 0


## Builds the match in the ADR-0008 Decision 1 order, then `engine.start(config)`
## and the first [method _after_engine_step]. [param config] is the `MatchConfig`;
## its `log` is the fresh match log. [param db] is the frozen database,
## [param settings] the settings snapshot and [param planner_task] the task the
## composition root picked (ADR-0006). [param clock] gives microseconds; only a test
## passes one.
## [codeblock]
## var driver := MatchDriver.new(config, db, settings_snapshot, WorkerPoolPlannerTask.new())
## [/codeblock]
func _init(config: Dictionary, db: CardDatabase, settings: Dictionary, planner_task: PlannerTask, clock: Callable = Time.get_ticks_usec) -> void:
	_log = config.log
	_settings = settings
	_planner_task = planner_task
	_clock = clock
	var profiles: Dictionary = db.config("ai_profiles")
	_replay_budget_usec = int(float(profiles.runtime.replay_budget_ms) * USEC_PER_MSEC)
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
	if _task != null and not _ended and str(stamped.get("type", "")) == MatchRecords.CMD_CONCEDE:
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


## Once per frame, through `MatchController.tick()` (ADR-0008 Decision 4): polls a
## live task, at most once, and takes its result when it finished; then replays a
## pending plan until it is exhausted or `replay_budget_ms` is spent, carrying the
## rest to the next tick. In a debug build it times its own work.
func tick() -> void:
	var started: int = _clock.call()
	_outside_usec = 0
	if _task != null and _task.poll():
		_on_task_done()
	if _pending_plan != null:
		_replay_some(started)
	if OS.is_debug_build() and _clock.call() - started - _outside_usec > _replay_budget_usec:
		_append_diagnostic(BossAI.EVENT_FAULT, {"reason": FAULT_TICK_OVER_BUDGET, TurnPlan.DIAGNOSTIC_KEY: true})


## Ends the driver's use of the planner; `MatchView._exit_tree` calls it. A
## `WorkerThreadPool` task cannot be cancelled, so this blocks until a live task
## finished, and discards its result. It also tears the engine down, since a match
## left unfinished still holds the engine and resolver in a cycle. Safe to repeat.
## [codeblock]
## func _exit_tree() -> void:
##     controller.shutdown()
## [/codeblock]
func shutdown() -> void:
	if _task != null:
		while not _task.poll():
			pass
		_release_task()
	_queued_concede = {}
	_pending_plan = null
	_engine.end_match()


## Runs after every engine step and replayed command, and decides what the driver
## does next from the engine's phase (ADR-0008 Decision 3): at `Ended` it drops any
## plan, tears the engine down and emits [signal match_ended], once.
## Story 014 adds the forecast, plan and choose rows of the table.
func _after_engine_step() -> void:
	if _ended or _engine.phase() != MatchState.PHASE_ENDED:
		return
	_ended = true
	_pending_plan = null
	_queued_concede = {}
	_engine.end_match()
	match_ended.emit(_engine.result())


## Starts the boss's planner on a clone (ADR-0006). `BossTurn.Main` calls this once
## story 014's row exists.
func _start_plan_task() -> void:
	_sandbox = _engine.clone()
	_task = _planner_task
	_task.start(_boss_ai.plan_task(_sandbox, _task))


## A finished task: a queued concede discards its result and is submitted; a plan
## begins replay. A match that ended meanwhile discards it too.
func _on_task_done() -> void:
	var outcome: Variant = _task.result()
	_release_task()
	if not _queued_concede.is_empty():
		var concede: Dictionary = _queued_concede
		_queued_concede = {}
		@warning_ignore("return_value_discarded")
		_submit_live(concede)
		_after_engine_step()
	elif outcome is TurnPlan and not _ended:
		_pending_plan = outcome
		_replay_index = 0
		_replay_start_seq = _log.size()


## Replays at least one step of the plan, then more until the budget of the tick
## that began at [param started] is spent.
func _replay_some(started: int) -> void:
	_replay_one()
	while _pending_plan != null and _clock.call() - started < _replay_budget_usec:
		_replay_one()


## One command of the pending plan: its diagnostics, the command, the step. After
## the last one, the diagnostics that follow it and the checksum.
func _replay_one() -> void:
	var plan: TurnPlan = _pending_plan
	var index: int = _replay_index
	_append_diagnostics_before(plan, index)
	if _pending_plan == null or index == plan.commands.size():
		_pending_plan = null
		return
	var command: Dictionary = (plan.commands[index] as Dictionary).duplicate(true)
	command["issuer"] = MatchRecords.SIDE_BOSS
	var result: Dictionary = _submit_live(command)
	_replay_index = index + 1
	# The step comes first: a rejection can itself hit the event cap and end the
	# match, and the log is then sealed against the fault.
	_after_engine_step()
	if not result.accepted:
		_diverge(index)
	elif _replay_index == plan.commands.size():
		_finish_replay(plan)


## The plan is exhausted: anything routed past its last command, then the checksum
## of what the live log gained, which diagnostics do not count towards.
func _finish_replay(plan: TurnPlan) -> void:
	_append_diagnostics_before(plan, plan.commands.size())
	if _pending_plan == null:
		return
	_pending_plan = null
	if TurnPlan.checksum(_log.events_since(_replay_start_seq)) != plan.expected_checksum:
		_diverge(plan.commands.size())


## ADR-0006: stop replaying, say so, and end the boss's turn. [param at_index] is the
## rejected command, or one past the last for a checksum mismatch. After a whole
## plan the turn may be over already, and the engine then refuses the `end_turn`.
func _diverge(at_index: int) -> void:
	_pending_plan = null
	_append_diagnostic(BossAI.EVENT_FAULT, {
		"reason": FAULT_REPLAY_DIVERGENCE,
		"at_index": at_index,
		TurnPlan.DIAGNOSTIC_KEY: true,
	})
	if _ended:
		return
	@warning_ignore("return_value_discarded")
	_submit_live(MatchRecords.end_turn(MatchRecords.SIDE_BOSS))
	_after_engine_step()


func _append_diagnostics_before(plan: TurnPlan, index: int) -> void:
	for diagnostic: Dictionary in plan.diagnostics_before(index):
		_append_diagnostic(StringName(str(diagnostic[TurnPlan.EVENT_KEY])), TurnPlan.event_payload(diagnostic))


## Appends a diagnostic at `cause_seq = 0` (rng-event-log rule 12a), unless the match
## ended and the log is sealed. A refused append is the log's overflow, which the
## engine answers with its `event_cap` fault (ADR-0003 Decision 8), as it does for an
## event of its own.
func _append_diagnostic(type: StringName, payload: Dictionary) -> void:
	if _ended:
		return
	var before: int = _clock.call()
	var seq: int = _log.append(type, payload, 0)
	_outside_usec += _clock.call() - before
	if seq < 0:
		_engine.fault(MatchRecords.REASON_EVENT_CAP)
		_after_engine_step()


## `engine.submit` with its time, and so its subscribers' time, kept out of the
## driver's own work.
func _submit_live(command: Dictionary) -> Dictionary:
	var before: int = _clock.call()
	var result: Dictionary = _engine.submit(command)
	_outside_usec += _clock.call() - before
	return result


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
