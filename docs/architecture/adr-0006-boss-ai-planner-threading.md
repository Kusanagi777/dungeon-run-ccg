# ADR-0006: Boss AI Planner Threading — `PlannerTask` Seam, Worker-Pool Default, Time-Sliced Fallback

## Status

Accepted

> **Who may move this to `Accepted`: the user, or `technical-director` on the
> user's explicit confirmation. No other agent, and no skill on its own.**
> Stories referencing a `Proposed` ADR are set `Blocked`, and epics require
> `Accepted`, so the field needs a named owner. `technical-director` is the role
> `coordination-rules.md` escalates technical conflicts to.

Review record for this authoring run (2026-11-03, `review_mode: lean`,
`automation: guided`, `workflow: standard`, `docs.density: balanced`):

- **TD-ADR gate skipped — Lean mode.** `technical-director` was not spawned.
- **Engine validation: NOT ASSESSED** — no `Agent` tool was available to this
  run, so `godot-specialist` was not spawned. `docs/engine-reference/godot/`
  (`VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`,
  `current-best-practices.md`) was read directly; the threading claims below
  rest on the probe file, not on the reference, and are marked so.
- **GDD sync: checked 4 referenced GDDs** (`boss-ai.md`, `match-rules.md`,
  `match-ui.md`, `rng-event-log.md`): no naming inconsistencies. `PlannerTask`,
  `BossAI.forecast / play_turn / choose`, `MatchDriver.tick()`,
  `RulesEngine.clone()` and the `ai_decision` / `ai_fault` event names match the
  GDDs and `architecture.md` §API Boundaries verbatim.
- **Registry conflict check (Step 3a):** `docs/registry/architecture.yaml` has
  no entries (all five sections are `[]`), so no stance can conflict. Registry
  rows this ADR would add are listed in the authoring report, not written
  (`/architecture-review` owns the registries).
- **Numbering:** fixed by `design/design-decisions.md` DD-X08 and
  `architecture.md` §Required ADRs.
- **TD review 2026-11-03 (acceptance pass over ADR-0001..0011):** the
  clone-and-replay protocol is unchanged and is what ADR-0008 and (now)
  `architecture.md` describe. Changes in this ADR: the ADR-0008 reconciliation
  bullets and the `MatchDriver` interface comments said boss-turn `submit`
  returns `ENGINE_BUSY / planner_live`, named a `MatchQuery.is_busy()`, limited
  `is_planning()` to boss tasks and kept an event "forwarding/buffering" step —
  all of which contradicted ADR-0008 as adopted (ADR-0008 owns the driver API);
  aligned to ADR-0008. "`architecture.md` is not edited" notes updated, since it
  now is. TD paragraph now matches the `architecture.md` mapping. Dependencies
  ADR-0001 and ADR-0008 were Accepted first (ADR-0008 before this one, per both
  ADRs' dependency rows — not the reverse).
- **Erratum 2026-11-03 (engine validation, `docs/architecture/engine-validation-2026-11-03.md`)**: on 4.7.2 `plan_turn` is a coroutine (it awaits `checkpoint()`), so the task Callable must be `func() -> Variant: return await boss_ai.plan_turn(sandbox)`; it is built inside `src/ai/` by `BossAI.plan_task(sandbox) -> Callable` so `match_driver.gd` stays `await`-free. Verified in all three task shapes (worker, immediate, time-sliced). Verification adds a parse-check test for the call shape.
- **Accepted 2026-11-03 by technical-director** on the owner's standing approval of the project plan (plan approved 2026-11-03; "accept each" step). Owner may revert to Proposed.

## Date

2026-11-03

## Last Verified

2026-11-03 — against Godot 4.7.2 (installed, `VERSION.md` pin) and the GDDs as
approved on 2026-11-03.

## Decision Makers

Jacob (Head of Design, owner) — standing approval for guided mode;
`/architecture-decision` run (authoring); `technical-director` (acceptance, on
the owner's confirmation). No director or specialist agent reviewed this draft
(see Status).

## Summary

`.claude/rules/ai-code.md` caps AI main-thread time at 2 ms per frame while
boss-ai F7's band-3 worst case is ≈ 60–80 ms of planning per boss turn, so the
planner cannot run inline. This ADR fixes the `PlannerTask` seam that
`MatchDriver` drives and chooses its default implementation: the Boss AI plans
on a `RulesEngine.clone()` snapshot inside a `WorkerThreadPool` task (polled once
per frame with `is_task_completed`, released with `wait_for_task_completion`),
returns a `TurnPlan`, and the driver replays that plan into the live engine on
the main thread — where every event, including `ai_decision`, is logged. A
time-sliced coroutine implementation of the same seam is the fallback, and an
immediate implementation serves tests and the sim harness.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (installed 4.7.2 stable, Linux x86_64 — `VERSION.md`) |
| **Domain** | Core (threading / scripting) |
| **Layer** | Core |
| **Knowledge Risk** | **HIGH** — `VERSION.md` rates 4.5–4.7 HIGH; threading has **no page at all** in `docs/engine-reference/godot/` (`modules/` has no scripting or threading file). Every engine claim below is either observed in the probe or marked NOT SOURCEABLE |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md` (4.4→4.7 tables — no threading rows), `deprecated-apis.md` (no threading rows), `current-best-practices.md` (GDScript 4.5+ `@abstract`, 4.7 typed-return override rule, lambda capture-by-value); `docs/architecture/spikes/2026-11-03-engine-probes.md` Probe A and §Verified API list |
| **Post-Cutoff APIs Used** | `@abstract` class / method (4.5, sourced: `current-best-practices.md` § GDScript 4.5+). The 4.7 rule "an override of a typed method inherits its return type and needs an explicit `return`" (sourced: `breaking-changes.md` 4.6→4.7 GDScript row) applies to every `PlannerTask` override. `WorkerThreadPool.add_task / is_task_completed / wait_for_task_completion`, `Thread.start / is_alive / wait_to_finish`, `OS.get_thread_caller_id / get_main_thread_id` exist on 4.7.2 **by observation only** (probe A; NOT SOURCEABLE from the reference) |
| **Verification Required** | (1) A30 on the target machine: 20 band-3 boss rounds in a debug build, profiler attached, no frame charges > 2 ms to `src/ai/**`; (2) the determinism test below: worker plan == main-thread plan byte-for-byte over 1,000 seeded turns; (3) the same two on **Windows** (the `commands.build` preset target) — probe A ran on Linux only, so Windows `WorkerThreadPool` behaviour is NOT SOURCEABLE until that run; (4) concurrent read-only access to the frozen `CardDatabase` snapshot from a worker while the main thread reads it (forecast during the player's turn) — NOT SOURCEABLE; stress test below |

> If Knowledge Risk is MEDIUM or HIGH, this ADR must be re-validated when the
> project upgrades engine versions: re-run probe A and the tests in
> § Verification, then update **Last Verified** or supersede.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (rules / presentation split — `BossAI`, `RulesEngine` are `RefCounted`, Node-free, constructor-injected; this is what makes off-thread execution safe by construction), ADR-0008 (match driver ownership — `MatchDriver` is the only caller of `PlannerTask`). Both written 2026-11-03; both Accepted 2026-11-03 before this ADR |
| **Enables** | ADR-0009 (Match UI boss-turn playback assumes the whole turn, or a prefix of it, is already in the log when the UI sees it — U6) |
| **Blocks** | Every Boss AI story that calls `play_turn` / `forecast` from the driver; the `boss_turn_playback` fixture story (match-ui U11); the A30 and A22 acceptance stories |
| **Ordering Note** | ADR-0003 (RNG + event log) is a transitive dependency through ADR-0008: `RulesEngine.clone()` must copy `rng_match` state (TR-match-rules-003) for the replay below to be sound. Implement `PlannerTask` + `ImmediatePlannerTask` first (no engine risk), then `WorkerPoolPlannerTask`, then `TimeSlicedPlannerTask` only if (3) in Verification Required fails on Windows |

## Context

### Problem Statement

Boss AI's `play_turn(engine)` decides and executes a whole boss turn in one
synchronous call (boss-ai C1.4, C2). Its budgets are counts, not milliseconds
(C9), and F7 puts the band-3 worst case at `(8·250 + 4000)·0.01 ms ≈ 60 ms`;
probe A measured a comparable 2 M-op workload at 70–80 ms on this machine. The
project rule `.claude/rules/ai-code.md` ("AI update budget: 2 ms per frame
maximum") and boss-ai C1.5 forbid holding the main thread for that long, and
C1.5 explicitly leaves the mechanism — worker task or time-slicing — to this
ADR. `architecture.md` §Threading model is a placeholder that this ADR
resolves (open question QQ-01).

### Current State

No production code exists. The prototype ran its AI inline on the main thread
with Node reparenting (TD-006); its AI half is retired by ADR-0001 (all input,
human and AI, goes through `submit()`), not here. `architecture.md` §API
Boundaries already declares the seam — `@abstract class_name PlannerTask` with
`start(work: Callable)` and `poll() -> bool` — and §Data Flow 2 the driver
protocol; this ADR fills both in and corrects one wording in §Data Flow 2 (see
Decision, "What the worker touches").

### Constraints

- **Determinism (Pillar 4, DD-R09, boss-ai A1–A3):** identical state, profile and
  seed must produce identical commands on and off the main thread; the event log
  must be byte-identical either way (boss-ai A30 wording in `architecture.md`).
- **No Node, no autoload, no signal emission from the worker** (`architecture.md`
  §Threading model). `RulesEngine.match_ended` is a signal, and `EventLog`
  subscribers are synchronous callbacks that run UI code — neither may fire
  off-thread.
- **`EventLog` subscribers run on the main thread only** (`architecture.md`
  §Data Flow 2; rng-event-log rule 13 subscriber contract).
- **Budgets:** ≤ 2 ms main-thread AI per frame; `submit()` ≤ 5 ms worst case;
  50 ms p95 planner per turn (A22, a count-tuning target, not a runtime switch).
- **Engine reference has nothing on threading** — probe A is the only local
  evidence, single machine, 4 cores, Linux.
- **The player keeps playing during `forecast`:** `forecast(engine)` runs at
  `PlayerTurn.Main` (C1.4) while the player may submit commands, so the planner
  cannot hold exclusive access to the live engine during a forecast.

### Requirements

- Must expose exactly `start(work)` / `poll()` to the driver plus a result
  accessor; the driver's code must not change between implementations.
- Must keep every live mutation — `submit`, `log.append`, `match_ended` — on the
  main thread.
- Must log `ai_decision`, `ai_plan_aborted`, `ai_fault` as `diagnostic: true`
  events on the same log (rng-event-log rule 12a) with correct `seq` ordering
  relative to the commands they describe.
- Must support concede while a task is live (match-rules C14; ADR-0008 queue
  rule).
- Must run headless under gdUnit4 and in the sim harness (boss-ai C11) with no
  thread at all.

## Decision

**The Boss AI plans on a snapshot and the driver replays the plan.** The
driver hands the planner a `RulesEngine.clone()` (deep copy: state, hook
entries, continuation, scratch log, copied `rng_match` state — TR-match-rules-003)
plus the live `ai_<floor>` stream, which nothing else reads. `BossAI.play_turn`
runs unchanged against the clone — it calls `legal_commands()`, `clone()` for
its sandboxes and `submit()` on the clone — and the task's result is a
`TurnPlan`: the ordered commands the clone accepted, the `ai_decision` /
`ai_plan_aborted` payloads emitted while planning, and a checksum of the clone's
scratch-log event types. On the main thread, `MatchDriver.tick()` replays the
plan's commands into the live engine through `submit()`, appending each
`ai_decision` just before its command. Because the clone carries the same
`rng_match` position and the same hooks, the live engine produces the same
events (rng-event-log rules 9–10, replay equivalence per command sequence); the
driver verifies this by comparing event-type checksums and raises `ai_fault
{reason: replay_divergence}` then submits `end_turn` if they differ.

**Default implementation: `WorkerPoolPlannerTask`** —
`WorkerThreadPool.add_task(callable, false, "boss_ai")`, one
`WorkerThreadPool.is_task_completed(id)` per `tick()`, and
`WorkerThreadPool.wait_for_task_completion(id)` exactly once after completion
(probe A: deterministic checksum `1045393980` across all runs, 70–90 ms
off-thread, 14–16 frames polled, no stderr output once the poll-after-wait
error was fixed). **Fallback: `TimeSlicedPlannerTask`** — the same `work`
Callable run as a coroutine on the main thread, yielding at `checkpoint()` calls
whenever the current slice exceeds `slice_ms` (probe A: 1,000-op chunks hold
2.09–2.11 ms, 20,000-op chunks overshoot to 3.6–4.8 ms). **Test / harness
implementation: `ImmediatePlannerTask`** — runs `work` inside `start()`.

`forecast(engine)` uses the same seam with the same clone rule; its result is an
`Intent`, and the driver appends `ai_intent_shown` on the main thread when the
task returns. The player's commands keep flowing to the live engine meanwhile;
if the player ends the turn before the forecast returns, the driver discards the
forecast result and emits nothing (boss-ai C8 already tolerates "plan changed").

### What the worker touches (the one correction to `architecture.md`)

`architecture.md` §Threading model and §Data Flow 2 say the task runs "over the
live `RulesEngine` (which the main thread does not touch while the task runs)".
This ADR narrows that: the worker touches **a clone**, never the live engine,
because (a) the live engine emits `match_ended` (a signal) and appends to a log
with main-thread subscribers, both forbidden off-thread by the same section, and
(b) `forecast` must run while the player acts. The driver and the "work
reaches the live engine on the main thread in `tick()`" rule stay; what is
replayed is the plan's commands, not buffered events (ADR-0008 Decision 5).
`architecture.md` §Data Flow 2 and §Threading model were aligned to this wording
on acceptance (2026-11-03).

**Reconciliation with ADR-0008** (written the same day, `Proposed`). ADR-0008
Decision 3 and its guideline say that while a task is live "main-thread code
must never read or write `RulesEngine`, `EffectResolver`, `BossAI` or the match
`EventLog`" and that `_boss_turn()` calls `boss_ai.play_turn(engine)`. Under
this ADR those read as follows, and ADR-0008 should adopt the wording on
acceptance of either:

- **Boss-turn and boss-choice tasks** (as ADR-0008 Decision 2 adopted it):
  player `submit` goes to the live engine, which answers `NOT_YOUR_TURN` /
  `CHOICE_PENDING` because it is in `BossTurn.Main` or a boss `Choice`; only
  `concede` is queued by the driver (`ENGINE_BUSY / concede_queued`). The task
  body is `plan_turn(engine.clone())`, and `_on_task_done()` replays the plan
  into the live engine, whose subscribers fire synchronously (no event buffer —
  ADR-0008 Decision 5).
- **Forecast tasks** (`PlayerTurn.Main`): no gate — the task owns a clone, so
  player `submit` and `MatchQuery` proceed normally against the live engine. If the player's command moves the engine
  out of `PlayerTurn.Main` (end turn, concede) before the forecast returns, the
  driver discards the result and appends nothing. This is the one behavioural
  difference from ADR-0008 as written and the reason the clone design is
  chosen (boss-ai C1.4 runs `forecast` while the player acts).
- ADR-0008's "the driver's own work per `tick()` is one poll plus bookkeeping
  (≤ 2 ms)" holds with `replay_budget_ms` defaulting to **2**: replay continues
  on the next tick once the budget is spent (minimum one command per tick, so a
  single worst-case 5 ms `submit` — match-rules budget — may still overrun one
  frame; that is engine time, not `src/ai/**` time).

### Architecture Diagram

```
main thread                                   worker (WorkerThreadPool)
───────────                                   ─────────────────────────
RulesEngine: PlayerTurn.End → BossTurn.Main
MatchDriver.on_phase(BossTurn.Main):
   sandbox = engine.clone()            ──┐
   task.start(boss_ai.plan_task(sandbox)) │ ownership of `sandbox` and the
     = func() -> Variant:              ────┼──► boss_ai.plan_turn(sandbox):
         return await boss_ai.plan_turn(sandbox)   (coroutine: it awaits checkpoint())
                                        │       loop of boss-ai C2 against `sandbox`
MatchView._process → driver.tick():     │       (legal_commands, clone() sandboxes,
   if task.poll():  ◄── is_task_completed┘        submit on the clone, choose())
      plan = task.result()                      collects TurnPlan{commands[], diagnostics[],
      wait_for_task_completion(id)                          expected_checksum}
      replay(plan):                             never: Node, autoload, signal.emit,
        for each (diag, cmd):                          the live engine, the live log
          log.append("ai_decision", diag)      ◄── returns TurnPlan (Variant)
          r = engine.submit(cmd)   # live; events → EventLog → subscribers (main thread)
          assert r.accepted; checksum ⊕= event types
        if checksum != plan.expected_checksum: log.append("ai_fault", …); engine.submit(end_turn)
      replay may span ticks (replay_budget_ms); UI paces the burst (match-ui U6)
   else: UI shows "boss thinking" (U6.1 controls already locked)
```

Thread-safety argument (by construction, not by locking): the worker owns the
clone exclusively; the only shared objects it reads are the frozen
`CardDatabase` snapshot (read-only after `load()`; `reload()` is debug-only and
must refuse while a task is live) and the `ai_<floor>` `RngStream`, which the
main thread never touches. `RefCounted` reference counts are atomic in Godot 4
(training-data claim, LOW risk; the probe observed no warnings sharing a
`RefCounted` graph across the boundary). Concurrent read-only `Dictionary`
access is **NOT SOURCEABLE** — see Verification.

### Key Interfaces

Names and signatures match `architecture.md` §API Boundaries; additions are
marked `# new`.

```gdscript
# src/ai/planner_task.gd — the seam (architecture.md §API Boundaries, Core — Boss AI)
@abstract class_name PlannerTask extends RefCounted
@abstract func start(work: Callable) -> void      # work: Callable() -> Variant; exactly once per task object
@abstract func poll() -> bool                     # true once finished; called once per frame by MatchDriver.tick()
func result() -> Variant:                         # new — valid only after poll() returned true; null = the work errored
    return _result
func is_live() -> bool:                           # new — started and not yet finished
    return _live
func checkpoint() -> void:                        # new — cooperative yield point; BossAI awaits it between
    pass                                          #       candidate evaluations and lethal-search nodes.
                                                  #       Base and worker implementations: plain no-op (no await),
                                                  #       so `await planner.checkpoint()` returns immediately.
# 4.7 rule (sourced): every override of a typed method above ends in an explicit `return`.

# src/ai/worker_pool_planner_task.gd — DEFAULT
class_name WorkerPoolPlannerTask extends PlannerTask
var _task_id: int = -1
func start(work: Callable) -> void:
    _live = true
    _task_id = WorkerThreadPool.add_task(_run.bind(work), false, "boss_ai")   # observed signature (probe A)
func poll() -> bool:
    if not _live: return true
    if not WorkerThreadPool.is_task_completed(_task_id): return false         # poll BEFORE wait, never after
    WorkerThreadPool.wait_for_task_completion(_task_id)                       # releases the id (probe A: ERROR if polled after)
    _task_id = -1; _live = false
    return true
func _run(work: Callable) -> void:
    _result = work.call()                                                      # off-thread; touches only the clone

# src/ai/time_sliced_planner_task.gd — FALLBACK (same seam, main thread)
class_name TimeSlicedPlannerTask extends PlannerTask
signal _resume
var slice_usec: int                                                            # from config, see Tuning
var _slice_start_usec: int
var _done := false
func start(work: Callable) -> void:
    _live = true; _slice_start_usec = Time.get_ticks_usec()
    _run(work)                                                                 # coroutine; runs until the first over-budget checkpoint
func poll() -> bool:
    if _done: return true
    _slice_start_usec = Time.get_ticks_usec()
    _resume.emit()                                                             # resumes the coroutine synchronously inside poll()
    return _done
func checkpoint() -> void:
    if Time.get_ticks_usec() - _slice_start_usec >= slice_usec:
        await _resume
    return
func _run(work: Callable) -> void:
    _result = await work.call(); _done = true; _live = false

# tests/helpers/immediate_planner_task.gd and the sim harness
class_name ImmediatePlannerTask extends PlannerTask
func start(work: Callable) -> void: _result = work.call(); _live = false
func poll() -> bool: return true

# src/ai/boss_ai.gd — additions (boss-ai C1.4 entry points unchanged)
class_name BossAI extends RefCounted
func plan_turn(sandbox: RulesEngine) -> TurnPlan        # new — the C2 loop against the clone; what play_turn runs inside the task
func play_turn(engine: RulesEngine) -> void             # unchanged contract (C1.4); = plan_turn on engine.clone() + MatchDriver.replay — kept for the harness
func forecast(engine: RulesEngine) -> Intent            # unchanged; the driver passes a clone
class_name TurnPlan extends RefCounted                   # new — plain data, JSON-representable (rng-event-log rule 14)
# {commands: Array[Command], diagnostics: Array[Dictionary] (one ai_decision per command, plus ai_plan_aborted),
#  expected_checksum: int (FNV-1a over the clone's scratch-log event types), ai_draws: int, mode_trace: Array[StringName]}

# src/gameplay/run/match_driver.gd — the protocol this ADR fixes (API owned by ADR-0008)
class_name MatchDriver extends RefCounted
func _init(config: MatchConfig, db: CardDatabase, settings: Dictionary, planner_task: PlannerTask) -> void
func tick() -> void              # ≤ 2 ms of AI work: one poll(); replay bounded by replay_budget_ms, carried to the next tick
func submit(command: Command) -> CommandResult   # always to the live engine (main thread); concede while any task is live → queued, ENGINE_BUSY/concede_queued (ADR-0008 Decision 2)
func is_planning() -> bool                       # ADR-0008 addition (owned there): true while any task is live or a plan is pending replay
func shutdown() -> void          # new — if a task is live, blocks on poll()/wait until it ends; MatchView calls it on _exit_tree
```

### Implementation Guidelines

- The worker **must** receive a `RulesEngine.clone()` and **must never** be
  handed the live `RulesEngine`, the live `EventLog`, `MatchDriver`,
  `MatchView`, `Boot` or any `Node`.
- Nothing in `src/ai/**` **must ever** call `signal.emit`, `log.append` on a
  live log, `get_tree()`, `Engine.get_main_loop()` or any `Node` method. The
  only log the planner writes is the clone's detached scratch log.
- The driver **must** append every `ai_decision` / `ai_plan_aborted` / `ai_fault`
  on the main thread, in `tick()`, immediately before the command it describes
  (`cause_seq = 0`, `payload.diagnostic = true` — rng-event-log rule 12a).
- `MatchDriver.tick()` **must** call `poll()` at most once per frame and
  **must never** call `WorkerThreadPool.is_task_completed` after
  `wait_for_task_completion` (probe A: `ERROR: Invalid Task ID`).
- The driver **must** compare the live event-type checksum with
  `TurnPlan.expected_checksum` after replay; on mismatch it **must** append
  `ai_fault {reason: replay_divergence, at_index}` and submit `end_turn`, never
  continue replaying.
- Replay **must** be bounded by `replay_budget_ms` per tick and continue on the
  next tick; the UI never depends on the whole turn being present in one frame
  (match-ui U6 says the turn "may" already be in the log).
- `concede` received while a task is live **must** be queued; when the task
  returns the driver **must** discard the plan unreplayed and submit `concede`
  (nothing is in flight on the live engine, so match-rules C14 is satisfied with
  no boss command executed).
- `CardDatabase.reload()` **must** return `E_BUSY` while any `PlannerTask` is
  live (debug builds only; release returns `E_NOT_SUPPORTED` already).
- `BossAI` **must** `await planner.checkpoint()` between candidate evaluations
  (C4–C6 `score_all`) and between lethal-search nodes (C3); the worker
  implementation makes this a no-op, the time-sliced one a yield.
- `MatchView._exit_tree` **must** call `MatchDriver.shutdown()`; a
  `WorkerThreadPool` task cannot be cancelled, only awaited.
- `Boot` **must** construct `WorkerPoolPlannerTask` by default and
  `TimeSlicedPlannerTask` when `config("ai_profiles").runtime.planner_mode ==
  "time_sliced"` or the debug flag `--ai-sync` is present; `tests/unit/**` and
  the sim harness **must** inject `ImmediatePlannerTask` and **must never**
  start a worker (gdUnit4 runs headless; TD-012).
- All numbers (`slice_ms`, `replay_budget_ms`, `planner_mode`) **must** come
  from data (`ai_profiles.json` `runtime` block — see Tuning note below), never
  from literals (boss-ai A29).

**Tuning note (open point for the data owner):** boss-ai F9 defines
`ai_profiles.json` with `presentation` and profile blocks. This ADR proposes a
sibling `runtime {planner_mode: "worker" | "time_sliced", slice_ms: 1.5,
replay_budget_ms: 2}` block validated by `BossAI.validate_profiles_config`. If
the data owner prefers another home (ADR-0002 config loading), only the
`config()` name changes.

## Alternatives Considered

### Alternative 1: Run `play_turn` against the live engine on the worker (the `architecture.md` placeholder wording)
- **Description**: Hand the live `RulesEngine` to the task; the main thread does not touch it until `poll()` returns; events land in the live log directly.
- **Pros**: No `TurnPlan`, no replay, no checksum; the AI code is exactly boss-ai C2 as written.
- **Cons**: `RulesEngine.match_ended` would be emitted from the worker and `EventLog.append` would run subscribers off-thread — both forbidden by `architecture.md` §Threading model (and the buffering rule would have to move into `EventLog`); `forecast` at `PlayerTurn.Main` would have to lock out player input for up to 80 ms per turn (C1.4 runs it while the player acts); concede-while-planning would need the engine to be re-entrant across threads. Thread-safety would rest on discipline across two classes instead of on ownership of a copy.
- **Estimated Effort**: Lower initial code, higher correctness burden.
- **Rejection Reason**: Violates two written threading rules and the `forecast` concurrency requirement; the snapshot design costs one checksum compare and a `TurnPlan` record to remove all three problems.

### Alternative 2: Dedicated `Thread` per boss turn
- **Description**: `Thread.new()`, `start(callable, Thread.PRIORITY_NORMAL)`, `is_alive()` per frame, `wait_to_finish()` — probe A verified it works identically (74–76 ms, 13 frames).
- **Pros**: Owned lifecycle; priority control; no dependency on the pool's scheduling.
- **Cons**: Thread creation per turn; the driver owns thread lifetime and must `wait_to_finish()` on every exit path or leak a thread (an un-joined `Thread` is an error on free in Godot 4 — training-data claim, NOT SOURCEABLE); no measured benefit over the pool in probe A.
- **Estimated Effort**: Slightly more than the pool (lifecycle code and teardown tests).
- **Rejection Reason**: Same result, more lifecycle to get wrong; the pool keeps per-frame main-thread cost to one poll and has nothing to join except the one `wait_for_task_completion`. Kept as a drop-in `ThreadPlannerTask` behind the same seam if the pool misbehaves on Windows.

### Alternative 3: Main-thread time-slicing only (no worker)
- **Description**: `TimeSlicedPlannerTask` as the sole implementation.
- **Pros**: No threads, no NOT SOURCEABLE threading claims, trivially deterministic, identical on every platform.
- **Cons**: Probe A: 1,000-op chunks are needed to stay under 2 ms, i.e. a checkpoint roughly every sandbox evaluation; a single worst-case `submit` (5 ms, 50-step chain) overshoots the 2 ms slice by construction; a band-3 turn then spends ~40–80 frames (0.7–1.3 s at 60 Hz) "thinking" before the first command replays, against the 300 ms "End Turn → intent commit beat" latency target (match-ui Input Responsiveness) — the commit beat can play first, but the first action group waits.
- **Estimated Effort**: Equal (it is built anyway as the fallback).
- **Rejection Reason**: Meets the letter of the 2 ms rule only with a resumable inner loop and still cannot bound one `submit`; the worker meets it with one poll per frame. Retained as the fallback because it is correct by construction.

### Alternative 4: Compute only the first command per task, re-plan per command
- **Description**: Each task returns one command; the driver submits it live and starts a new task for the next.
- **Pros**: No replay-equivalence dependency; smaller tasks.
- **Cons**: Up to 30 task round-trips per turn (one or more frames each) stretches a turn across seconds; the lethal plan (C3) is computed once per turn and would be recomputed per step or carried in driver state; `ai_decision` ordering is unchanged, so it buys nothing there.
- **Estimated Effort**: Higher (driver-side plan state).
- **Rejection Reason**: Latency and complexity; the clone already guarantees replay equivalence, so a full-turn plan is safe.

## Consequences

### Positive
- The 2 ms main-thread rule is met with one `is_task_completed` call per frame; AI cost per frame is measurable and tiny (A30).
- Every live mutation, signal and log append stays on the main thread — the threading rules in `architecture.md` hold without locks.
- The planner is a pure function of a snapshot: `TurnPlan` is JSON-representable and can be written next to `ai_decision` for bug reports and the replay viewer.
- One seam, three implementations; tests and the harness never start a thread; the fallback needs no driver change.
- `forecast` runs while the player plays, so the intent banner is ready by the time the player ends the turn in most cases.

### Negative
- A `TurnPlan` record and a replay step exist that boss-ai C2 did not describe; `BossAI` gains `plan_turn` and `checkpoint()` calls in its inner loops.
- Replay correctness depends on `clone()` fidelity (hooks, continuation, `rng_match` position). A fidelity bug surfaces as `ai_fault {replay_divergence}` rather than a wrong move — visible, but a new failure mode to test (A20 covers hooks already).
- Threading on 4.7.2 remains NOT SOURCEABLE from the engine reference; the evidence is one probe on one Linux machine until the Windows run in Verification.
- `WorkerThreadPool` tasks cannot be cancelled: quitting a scene mid-plan blocks for up to one planner run (≤ ~150 ms observed cold).

### Neutral
- `play_turn(engine)` keeps its C1.4 contract for the harness, implemented as `plan_turn(engine.clone())` + immediate replay; nothing outside the driver and the harness calls it.
- The driver may spread replay over several ticks; the UI already paces the burst (match-ui U6) and never assumed one frame.

## Risks
- **Worker misbehaves on Windows / other CPUs** (NOT SOURCEABLE). Mitigation: `TimeSlicedPlannerTask` behind the same seam, selectable by data; A30 and the determinism test run on both platforms before acceptance of the Boss AI epic.
- **Concurrent read of the frozen `CardDatabase` from two threads** (NOT SOURCEABLE). Mitigation: `CardDatabase` writes nothing after `load()`; `reload()` refuses while a task is live; the stress test in Verification runs forecast + hover queries for 10,000 iterations and asserts no error output and identical results.
- **Script error inside the worker** leaves `result()` null and prints to stderr. Mitigation: the driver treats a null plan as `ai_fault {reason: planner_error}` and submits `end_turn`; the test suite greps stderr in CI.
- **Replay divergence from a `clone()` fidelity gap** (e.g. an `EffectRuntime` field not copied). Mitigation: the checksum makes it loud; A20 (hooks in the clone) and a 1,000-match zero-divergence test (A23 shape) gate the story.
- **Cold first run of the pool is slow** (140 ms observed once). Mitigation: it is off-thread; only the "boss thinking" state lasts longer, well inside `max_turn_playback_s`.
- **Lambda capture by value** (sourced, `current-best-practices.md`): the `work` Callable must carry the clone and `BossAI` by reference-type capture, which is how `RefCounted` arguments behave; a test asserts the task returns the planner's result, not a stale copy.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| boss-ai.md | TR-boss-ai-003 — C1.5, C9, F7: ≤ 2 ms main-thread per frame; planner off-thread or time-sliced; budgets are counts | `WorkerPoolPlannerTask` default, one poll per frame; `TimeSlicedPlannerTask` fallback; budgets untouched (counts live in the plan loop) |
| boss-ai.md | TR-boss-ai-001 — C1: pure function of (observable state, profile, stream position); reads only `legal_commands()` / `clone()` | The planner is handed a clone and the `ai_<floor>` stream only; identical plan on and off the main thread, proven by the determinism test |
| boss-ai.md | TR-boss-ai-002 — C1.4: `forecast`, `play_turn`, `choose` synchronous entry points | Kept; `plan_turn` is the task body; `play_turn` remains for the harness; `choose` is answered inside the plan loop and replayed as a `choose` command |
| boss-ai.md | TR-boss-ai-006 — C11 headless sim harness | `ImmediatePlannerTask`; no thread in headless runs |
| boss-ai.md | A22 (50 ms p95), A30 (2 ms frame budget, `ai_decision` present) | A30 is the acceptance test of this ADR; `ai_decision` appended on the main thread before each replayed command |
| match-rules.md | TR-match-rules-003 — C2/C3 `clone()` deep copy incl. hooks, continuation, scratch log, copied `rng_match` | The replay design depends on it and makes any gap observable (`replay_divergence`) |
| match-rules.md | TR-match-rules-002 — `submit` synchronous; re-entrant → `ENGINE_BUSY` | Replay calls `submit` only from `tick()` on the main thread; driver rejects player `submit` while a task is live |
| rng-event-log.md | TR-rng-event-log-005 — rule 12a diagnostic events on the same log | `ai_decision` / `ai_plan_aborted` / `ai_fault` appended by the driver with `diagnostic: true` |
| rng-event-log.md | TR-rng-event-log-003 — replay equivalence per command sequence | The property the replay step relies on; checksum verifies it per turn |
| match-ui.md | TR-match-ui-003 — U6: boss turn already in the log when the UI sees it; UI paces the burst | Replay lands the burst in the log from `tick()`; possibly across a few ticks (U6 "may already be") |
| run-structure.md | TR-run-structure-005 — Run Structure owns the match driver that calls `forecast` / `play_turn` / `choose` | The driver protocol above is what ADR-0008's `MatchDriver` implements |
| design-decisions.md | TR-design-decisions-001 — DD-T02 rules are `RefCounted`, no Node references | The property that makes off-thread execution safe by construction |
| boss-ai.md | TR-boss-ai-005 — C10, F9: `ai_profiles.json` config, resolved profile, stage-7 validator; `runtime{planner_mode worker\|time_sliced\|immediate (default worker), slice_ms 2, replay_budget_ms 2}` | The `runtime` block this ADR proposed now has a data owner: boss-ai F9 (added 2026-11-03), loaded by ADR-0002's `config("ai_profiles")`; `planner_mode` selects `WorkerPoolPlannerTask` / `TimeSlicedPlannerTask` / `ImmediatePlannerTask`, `slice_ms` bounds the time-sliced step, `replay_budget_ms` bounds `MatchDriver.tick()` replay (ADR-0008) |

## TD Items Retired

None directly — `architecture.md` §Tech-debt retirement maps TD-006 to
ADR-0001/0008/0009; its AI half ("AI reparents nodes") is ADR-0001 (all input
through `submit()`) completed by ADR-0008. This ADR
reinforces it: the AI's commands reach the live engine only through the
driver's `submit()` replay on the main thread.

## Verification / How We Know

| Claim | Evidence today | Test that proves it going forward |
|---|---|---|
| `WorkerThreadPool.add_task` / `is_task_completed` / `wait_for_task_completion` exist and work on 4.7.2; RefCounted-only work returns a deterministic result off-thread | **Observed**: `docs/architecture/spikes/2026-11-03-engine-probes.md` Probe A, rows "Worker pool, blocking wait" and "Worker pool, polled per frame"; commands `cd probe_a && godot --headless --path . --import` then `godot --headless --path .`; checksum `1045393980` in every run; `OS.get_thread_caller_id() != OS.get_main_thread_id()` | `tests/unit/boss_ai/test_worker_pool_planner_task.gd`: a `RefCounted` workload through `WorkerPoolPlannerTask` equals the same workload through `ImmediatePlannerTask`; `poll()` never calls `is_task_completed` after wait (stderr empty) |
| Time-slicing holds 2 ms only with ~1k-op chunks | **Observed**: Probe A rows "Time-sliced coroutine" (20,000 iters → 3.6–4.8 ms; 1,000 iters → 2.09–2.11 ms) | `tests/unit/boss_ai/test_time_sliced_planner_task.gd`: max slice ≤ `slice_ms` + one evaluation for a band-3 fixture |
| Worker plan == main-thread plan, byte for byte | Not yet run on real `BossAI` (no code) | `tests/integration/boss_ai/test_planner_determinism.gd`: 1,000 seeded band-1..3 turns, `TurnPlan.to_dict()` and the replayed live log identical across `Worker`, `TimeSliced`, `Immediate`; zero `ai_fault {replay_divergence}` |
| ≤ 2 ms main-thread AI per frame | Not yet measurable | boss-ai A30: 20 band-3 rounds, debug build, profiler — no frame > 2 ms in `src/ai/**`; `MatchDriver.tick()` self-times and logs `ai_fault {reason: tick_over_budget}` in debug builds when exceeded |
| Windows behaviour of `WorkerThreadPool` | **NOT SOURCEABLE** — probe A ran on Linux only; no engine-reference page | Repeat the determinism test and A30 on the Windows export (`commands.build` preset) before the Boss AI epic closes |
| Concurrent read-only access to the frozen `CardDatabase` from worker + main thread | **NOT SOURCEABLE** | `tests/integration/boss_ai/test_forecast_concurrency.gd`: forecast tasks running while the main thread calls `MatchQuery.card_text` 10,000×; identical results, no error output |
| `await` on a non-coroutine `checkpoint()` returns immediately so the worker variant runs synchronously | Training-data claim (GDScript 2.0, LOW risk; not in the reference) | Covered by the worker unit test above: the task completes in one `poll()` sequence with no yield |
| `clone()` carries hooks and continuation | Confirmed in boss-ai Open Questions (2026-11-03): `hooks` is a `MatchState` field, `clone()` is a deep copy | boss-ai A20 (passive doubling heal scored correctly from the sandbox) |

## Performance Implications
- **CPU**: main thread — one `is_task_completed` per frame while planning (sub-microsecond), plus replay bounded by `replay_budget_ms` (2 ms default; typical turn ≪ 1 ms); worker — 50 ms p95 target per turn (A22), ≈ 60–80 ms band-3 worst case, on a pool thread. Forecast doubles the per-round worker cost (F7 note) — off-thread, so it costs frames nothing.
- **Memory**: one extra `RulesEngine` clone per planned turn (the planner's own sandboxes already clone per evaluation); one `TurnPlan` (≤ 30 commands + ≤ 30 diagnostics, a few KB). Released when replay ends.
- **Load Time**: none.
- **Network**: n/a.

## Migration Plan

Greenfield: no existing production code. Order of stories: `PlannerTask` +
`ImmediatePlannerTask` + `TurnPlan` and the driver replay path (fully
testable headless) → `WorkerPoolPlannerTask` with the determinism test → A30
measurement → `TimeSlicedPlannerTask` (built as the fallback; selectable by
data). `architecture.md` §Threading model / §Data Flow 2 wording was updated
on acceptance, 2026-11-03 (clone, not live engine).

**Rollback plan**: set `runtime.planner_mode = "time_sliced"` in
`ai_profiles.json` — no code change, same seam, same results (slower first
action). If the clone-and-replay design itself proves wrong (persistent
`replay_divergence` from a `clone()` fidelity problem that cannot be fixed),
supersede with an ADR adopting Alternative 1 and move the buffering rule into
`EventLog`.

## Validation Criteria

- boss-ai A30 passes on Linux and Windows debug builds.
- boss-ai A22: 50 ms p95 planner time at band 3 in the harness (off-thread time, measured inside the task).
- 1,000-match determinism run: zero `ai_fault`, identical logs across the three `PlannerTask` implementations.
- match-ui Input Responsiveness: "End Turn → boss intent commit beat visible ≤ 300 ms" holds with the worker (the commit beat is view-state from `ai_intent_committed`, appended at replay start).
- No `WorkerThreadPool` or `Thread` symbol appears outside `src/ai/*_planner_task.gd` (grep gate for `/create-control-manifest`).

## Related
- Depends on: ADR-0001 (rules / presentation split), ADR-0008 (match driver ownership and the Run ↔ Match ↔ UI hand-off); transitively ADR-0003 (RNG + event log — `clone()` copies `rng_match`).
- Enables: ADR-0009 (Match UI animation queue — boss-turn burst pacing).
- `docs/architecture/architecture.md` §Threading model (placeholder resolved here), §Data Flow 2, §API Boundaries Core — Boss AI, §Open Questions QQ-01.
- `docs/architecture/spikes/2026-11-03-engine-probes.md` Probe A and §Verified API list.
- `design/gdd/boss-ai.md` C1.4–C1.5, C2, C9, F7, A22, A30; `design/gdd/match-rules.md` C2, C3, C14; `design/gdd/rng-event-log.md` rules 9–10, 12a; `design/gdd/match-ui.md` U6.
- `.claude/rules/ai-code.md` (2 ms per frame; log every transition).
- Code (once implemented): `src/ai/planner_task.gd`, `src/ai/worker_pool_planner_task.gd`, `src/ai/time_sliced_planner_task.gd`, `src/ai/boss_ai.gd`, `src/gameplay/run/match_driver.gd`, `tests/helpers/immediate_planner_task.gd`.
