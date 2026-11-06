## One match attempt, rules side (ADR-0008; ADR-0006 for the planner protocol;
## design/gdd/run-structure.md Interactions "Boss AI"; TR-run-structure-005).
##
## `RunMachine.begin_match()` builds one through the injected `driver_factory`. It
## owns the live `RulesEngine`, its `EffectResolver` and the `BossAI`, and it is the
## only path from outside the rules tier into `RulesEngine.submit`. Rules tier: no
## Node, no autoload, and no coroutine here, so a task's work is always a Callable
## built in `src/ai/` ([method BossAI.plan_task], [method BossAI.forecast_task]).
##
## **The gate** ([method submit]) stamps `issuer = "player"` and goes straight to
## the live engine, which answers `NOT_YOUR_TURN` / `CHOICE_PENDING` itself: there
## is no driver-side lock, and [method is_planning] is a UI hint. The one rule on top
## is the concede slot: a `concede` while a task is live waits in
## [member _queued_concede] and is applied when the task returns, its result
## discarded, so no boss command runs after the player conceded.
##
## **A task** is live from [method _start_task] until [method _on_task_done] has
## taken its result, and owns [member _sandbox], which ends with it. There is one at a
## time, and each is a fresh [PlannerTask] from the injected factory: `start` runs once
## per object (DD-X31). A forecast still running when the player ends the turn holds
## the plan back until it returns, stale: both read the `ai_<floor>` stream.
##
## **The schedule** ([method _after_engine_step], ADR-0008 Decision 3 and its DD-X31
## erratum), with no task live and no plan pending:
## [codeblock]
## Ended                         drop the plan, tear down, emit match_ended
## Main, player, not forecast    forecast task on a clone
## Main, boss                    plan task on a clone
## Choice, side boss             plan task on a clone
## anything else                 wait for the player
## [/codeblock]
## There is no choose task: a boss Choice is answered inside a plan. One raised by a
## plan's own command has that plan's `choose` next in line, so it waits with the plan
## pending. One raised off the boss's plan (a boss Deathrattle on the player's turn, a
## boss Start-step trigger) has no plan yet, so the row starts one, which opens by
## answering it ([method BossAI.plan_turn]).
##
## **No way forward is a fault, never a hang.** A null result, an empty plan, a
## divergence: `ai_fault`, then the boss's open Choice closed on its first option,
## since the engine refuses `end_turn` until it is, then `end_turn`
## ([method _give_up], [method _diverge]). A forecast has no turn to end, so a null one
## is the fault alone.
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
## var driver := MatchDriver.new(config, db, settings, func() -> PlannerTask: return WorkerPoolPlannerTask.new())
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
## `ai_fault.reason`: a task with a live premise gave no result, which is how the seam
## reports work that errored (ADR-0006; DD-X31).
const FAULT_NULL_RESULT: String = "null_result"
## `ai_fault.reason`: a plan with no commands, so nothing can move the boss on (DD-X31).
const FAULT_EMPTY_PLAN: String = "empty_plan"
## The one setting that reaches the rules (ADR-0008 Decision 7).
const SETTING_TELEGRAPH: StringName = &"telegraph_mode"
## What a running task is working on.
const TASK_FORECAST: StringName = &"forecast"
const TASK_PLAN: StringName = &"plan"
## The option a Choice is closed on when no plan answered it: the engine lists every
## request's options from here.
const FIRST_OPTION: int = 0
## [member _forecast_turn] before the first forecast.
const NO_TURN: int = -1
const USEC_PER_MSEC: int = 1000

var _log: Variant = null
var _settings: Dictionary = {}
## A `Callable() -> PlannerTask`, called once per task (DD-X31).
var _planner_factory: Callable
## A `Callable() -> int` of microseconds.
var _clock: Callable
## `runtime.replay_budget_ms`, read once at construction.
var _replay_budget_usec: int = 0
var _resolver: EffectResolver = null
var _engine: RulesEngine = null
var _boss_ai: BossAI = null
var _query: MatchQuery = null
## The running task; null when none is live.
var _task: PlannerTask = null
## [constant TASK_FORECAST] or [constant TASK_PLAN], while a task is live.
var _task_kind: StringName = &""
## The engine's `{turn, side, phase}` when the running task's clone was taken.
var _premise: Dictionary = {}
## The clone the running task works on; ended when the task is released.
var _sandbox: RulesEngine = null
## The turn the last forecast was started for: one per player turn.
var _forecast_turn: int = NO_TURN
## A `telegraph_mode` that arrived while a task was live; null when none waits.
var _telegraph_pending: Variant = null
## The plan being replayed, and the next command in it.
var _pending_plan: TurnPlan = null
var _replay_index: int = 0
## The log's last `seq` when the plan began: what it gained since is the replay.
var _replay_start_seq: int = 0
## The one concede slot; empty when nothing is queued. A field, never a captured
## local: lambdas capture by value.
var _queued_concede: Dictionary = {}
## `true` once `Ended` was handled or the driver was shut down: nothing further is
## scheduled or appended.
var _ended: bool = false
## This tick's time outside the driver's own work: inside the engine and the log,
## whose subscribers are Match UI's budget, and inside a time-sliced task, which
## `slice_ms` bounds (ADR-0006).
var _outside_usec: int = 0


## Builds the match in the ADR-0008 Decision 1 order, then `engine.start(config)`
## and the first [method _after_engine_step]. [param config] is the `MatchConfig`;
## its `log` is the fresh match log. [param db] is the frozen database,
## [param settings] the settings snapshot, whose `telegraph_mode` the AI takes here,
## and [param planner_factory] a `Callable() -> PlannerTask` from the composition root
## that gives a **new** task of the implementation it picked (ADR-0006; DD-X31).
## [param clock] gives microseconds; only a test passes one.
## [codeblock]
## var driver := MatchDriver.new(config, db, settings_snapshot, func() -> PlannerTask: return WorkerPoolPlannerTask.new())
## [/codeblock]
func _init(config: Dictionary, db: CardDatabase, settings: Dictionary, planner_factory: Callable, clock: Callable = Time.get_ticks_usec) -> void:
	_log = config.log
	_settings = settings
	_planner_factory = planner_factory
	_clock = clock
	var profiles: Dictionary = db.config("ai_profiles")
	_replay_budget_usec = int(float(profiles.runtime.replay_budget_ms) * USEC_PER_MSEC)
	var boss_def: Dictionary = db.boss(str(config.boss.boss_def_id))
	var profile: Dictionary = _resolve_profile(profiles, boss_def, int(config.band))
	_resolver = _build_resolver(db, _hero_set(db, str(config.player.hero_def_id)))
	_engine = _build_engine(db, _resolver)
	_boss_ai = _build_boss_ai(boss_def, profile, config, db, profiles)
	if settings.has(SETTING_TELEGRAPH):
		_boss_ai.set_telegraph_mode(str(settings[SETTING_TELEGRAPH]))
	_query = MatchQuery.new(_engine, db, settings)
	_engine.start(_with_boss_power(config, boss_def))
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
	return _engine.hooks()


## `true` while a task is live or a plan is pending replay, a forecast on the player's
## turn included: the UI's "boss thinking" hint, read with the side to move, and not a
## lock.
func is_planning() -> bool:
	return _task != null or _pending_plan != null


## A setting changed during the match (ADR-0008 Decision 7). [param value] of
## `telegraph_mode` reaches the AI now, or when the live task returns and before the
## next one starts, the last value winning. Every other key is the UI's.
## [codeblock]
## driver.on_setting_changed(&"telegraph_mode", "brief")
## [/codeblock]
func on_setting_changed(key: StringName, value: Variant) -> void:
	if key != SETTING_TELEGRAPH:
		return
	if _task == null:
		_boss_ai.set_telegraph_mode(str(value))
	else:
		_telegraph_pending = value


## Once per frame, through `MatchController.tick()` (ADR-0008 Decision 4): polls a
## live task, at most once, and takes its result when it finished; then replays a
## pending plan until it is exhausted or `replay_budget_ms` is spent, carrying the
## rest to the next tick. In a debug build it times its own work.
func tick() -> void:
	var started: int = _clock.call()
	_outside_usec = 0
	if _task != null and _poll_task():
		_on_task_done()
	if _pending_plan != null:
		_replay_some(started)
	if OS.is_debug_build() and _clock.call() - started - _outside_usec > _replay_budget_usec:
		_append_fault(FAULT_TICK_OVER_BUDGET)


## Ends the driver's use of the planner; `MatchView._exit_tree` calls it. A
## `WorkerThreadPool` task cannot be cancelled, so this blocks until a live task
## finished, and discards its result. It also tears the engine down, since a match
## left unfinished still holds the engine and resolver in a cycle, and nothing is
## scheduled after it. Safe to repeat.
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
	_ended = true
	_engine.end_match()


## Runs after every engine step and replayed command, and decides what the driver
## does next from the engine's phase (ADR-0008 Decision 3): at `Ended` it drops any
## plan, tears the engine down and emits [signal match_ended], once; before it, the
## rest of the table is [method _schedule].
func _after_engine_step() -> void:
	if _ended:
		return
	if _engine.phase() != MatchState.PHASE_ENDED:
		_schedule()
		return
	_ended = true
	_pending_plan = null
	_queued_concede = {}
	_engine.end_match()
	match_ended.emit(_engine.result())


## The rows of the table below `Ended` (see the class doc): nothing while a task is
## live or a plan is pending, and that is what keeps a replayed command's Choice for the
## plan's own `choose`.
func _schedule() -> void:
	if _task != null or _pending_plan != null:
		return
	match _engine.phase():
		MatchState.PHASE_MAIN:
			if String(_engine.active_side()) == MatchRecords.SIDE_BOSS:
				_start_task(TASK_PLAN)
			elif _forecast_turn != _engine.turn():
				_forecast_turn = _engine.turn()
				_start_task(TASK_FORECAST)
		MatchState.PHASE_CHOICE:
			if _boss_owes_choice():
				_start_task(TASK_PLAN)


## Starts a fresh task of [param kind] on a clone (ADR-0006), its premise noted. The
## clone is engine time, and a time-sliced task's first slice runs inside `start`, so
## neither is the driver's own work.
func _start_task(kind: StringName) -> void:
	var before: int = _clock.call()
	_sandbox = _engine.clone()
	_task = _planner_factory.call()
	_task_kind = kind
	_premise = _premise_now()
	_task.start(_boss_ai.forecast_task(_sandbox, _task) if kind == TASK_FORECAST else _boss_ai.plan_task(_sandbox, _task))
	_outside_usec += _clock.call() - before


## What a task's clone took for granted. The side counts: `PHASE_MAIN` names both
## sides' Main.
func _premise_now() -> Dictionary:
	return {"turn": _engine.turn(), "side": String(_engine.active_side()), "phase": _engine.phase()}


func _premise_moved(premise: Dictionary) -> bool:
	return premise != _premise_now()


## The live task's one poll of the tick. A task that slices spends its slice inside
## the call: that is `slice_ms`'s to bound, not [member _replay_budget_usec] (ADR-0006).
func _poll_task() -> bool:
	if not _task.slices_main_thread():
		return _task.poll()
	var before: int = _clock.call()
	var done: bool = _task.poll()
	_outside_usec += _clock.call() - before
	return done


## A finished task (ADR-0008 Decision 4), its result read once. A waiting
## `telegraph_mode` goes in first. A queued concede discards the result and is
## submitted; a match that ended discards it; so does a moved premise, silently. Then
## the result is taken, and unless a plan begins replay, whose own steps do this, the
## schedule looks again: a discarded forecast is what lets the plan start.
func _on_task_done() -> void:
	var outcome: Variant = _task.result()
	var kind: StringName = _task_kind
	var premise: Dictionary = _premise
	_release_task()
	_apply_pending_telegraph()
	if not _queued_concede.is_empty():
		var concede: Dictionary = _queued_concede
		_queued_concede = {}
		@warning_ignore("return_value_discarded")
		_submit_live(concede)
	elif _ended:
		return
	elif not _premise_moved(premise):
		if kind == TASK_FORECAST:
			_take_forecast(outcome)
		else:
			_take_plan(outcome)
	if _pending_plan == null:
		_after_engine_step()


func _apply_pending_telegraph() -> void:
	if _telegraph_pending == null:
		return
	_boss_ai.set_telegraph_mode(str(_telegraph_pending))
	_telegraph_pending = null


## A forecast whose premise held: the AI keeps it, and the player sees it unless the
## boss hides it or the player has turned it off since it was built (C8.4).
func _take_forecast(outcome: Variant) -> void:
	if not outcome is Intent:
		_append_fault(FAULT_NULL_RESULT)
		return
	var intent: Intent = outcome
	_boss_ai.note_forecast(intent)
	if intent.is_shown() and _boss_ai.effective_mode() != Intent.MODE_HIDDEN:
		_append_event(BossAI.EVENT_INTENT_SHOWN, intent.to_dict())


## A plan whose premise held begins replay; with nothing in it, the boss has no way
## forward. Its diagnostics still say why.
func _take_plan(outcome: Variant) -> void:
	if not outcome is TurnPlan:
		_give_up(FAULT_NULL_RESULT)
		return
	var plan: TurnPlan = outcome
	if plan.commands.is_empty():
		_append_diagnostics_before(plan, 0)
		_give_up(FAULT_EMPTY_PLAN)
		return
	_pending_plan = plan
	_replay_index = 0
	_replay_start_seq = _log.size()


## DD-X31: says so, closes a boss Choice and ends the boss's turn if it is the boss's.
## A Choice raised on the player's turn leaves no boss turn to end. The caller steps.
## Should the engine ever refuse the `end_turn`, the row plans again and logs again, so
## the event cap is the floor under this: it can loop, but not hang.
func _give_up(reason: String) -> void:
	_append_fault(reason)
	_close_boss_choices()
	if _ended or _engine.phase() != MatchState.PHASE_MAIN or String(_engine.active_side()) != MatchRecords.SIDE_BOSS:
		return
	@warning_ignore("return_value_discarded")
	_submit_live(MatchRecords.end_turn(MatchRecords.SIDE_BOSS))


## Takes the first option of every boss Choice standing in the way, which only a plan
## that failed to answer it leaves open. Stops at a refusal.
func _close_boss_choices() -> void:
	while not _ended and _boss_owes_choice():
		if not _submit_live(MatchRecords.choose(MatchRecords.SIDE_BOSS, FIRST_OPTION)).accepted:
			return


func _boss_owes_choice() -> bool:
	var pending: Variant = _engine.pending_choice()
	return _engine.phase() == MatchState.PHASE_CHOICE and pending is Dictionary and str(pending.side) == MatchRecords.SIDE_BOSS


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
	if _pending_plan == null:
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
## of what the live log gained, which diagnostics do not count towards. The last step
## ran with the plan still pending, so the schedule looks again here.
func _finish_replay(plan: TurnPlan) -> void:
	_append_diagnostics_before(plan, plan.commands.size())
	if _pending_plan == null:
		return
	_pending_plan = null
	if TurnPlan.checksum(_log.events_since(_replay_start_seq)) != plan.expected_checksum:
		_diverge(plan.commands.size())
	elif not _ended:
		_schedule()


## ADR-0006: stop replaying, say so, and end the boss's turn, with any boss Choice
## closed first or the engine refuses it. [param at_index] is the rejected command, or
## one past the last for a checksum mismatch. After a whole plan the turn may be over
## already, and the engine then refuses the `end_turn`.
func _diverge(at_index: int) -> void:
	_pending_plan = null
	_append_event(BossAI.EVENT_FAULT, {
		"reason": FAULT_REPLAY_DIVERGENCE,
		"at_index": at_index,
		TurnPlan.DIAGNOSTIC_KEY: true,
	})
	_close_boss_choices()
	if _ended:
		return
	@warning_ignore("return_value_discarded")
	_submit_live(MatchRecords.end_turn(MatchRecords.SIDE_BOSS))
	_after_engine_step()


func _append_diagnostics_before(plan: TurnPlan, index: int) -> void:
	for diagnostic: Dictionary in plan.diagnostics_before(index):
		_append_event(StringName(str(diagnostic[TurnPlan.EVENT_KEY])), TurnPlan.event_payload(diagnostic))


## An `ai_fault` with only a reason.
func _append_fault(reason: String) -> void:
	_append_event(BossAI.EVENT_FAULT, {"reason": reason, TurnPlan.DIAGNOSTIC_KEY: true})


## Appends an AI event at `cause_seq = 0` (rng-event-log rule 12a), unless the match
## ended and the log is sealed. A refused append is the log's overflow, which the
## engine answers with its `event_cap` fault (ADR-0003 Decision 8), as it does for an
## event of its own.
func _append_event(type: StringName, payload: Dictionary) -> void:
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
	_task_kind = &""
	_premise = {}
	if _sandbox != null:
		_sandbox.end_match()
		_sandbox = null


## [param config] with `boss.hero_power` from [param boss_def], on copies: the engine
## seats the boss's power from it, and `MatchConfig` is the caller's. A `null` power is
## a boss with none (match-rules C7).
static func _with_boss_power(config: Dictionary, boss_def: Dictionary) -> Dictionary:
	var seated: Dictionary = config.duplicate()
	var boss: Dictionary = (config.boss as Dictionary).duplicate()
	boss["hero_power"] = boss_def.get("hero_power")
	seated["boss"] = boss
	return seated


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
