# ADR-0008: Match Driver Ownership and the Run ↔ Match ↔ UI Hand-off

## Status

Accepted

> **Who may move this to `Accepted`: the user, or `technical-director` on the
> user's explicit confirmation. No other agent, and no skill on its own.**
> Stories referencing a `Proposed` ADR are set `Blocked`, and epics require
> `Accepted`, so the field needs a named owner.

Review record for this authoring run (2026-11-03, `/architecture-decision`,
headless, `automation: guided`, `review_mode: lean`, `workflow: standard`):

- **TD-ADR skipped — Lean mode.**
- **Engine specialist validation: NOT ASSESSED** — not spawned in this headless
  run (see ADR-0001 Status). The one engine fact this ADR leans on — that a
  planner task can run off the main thread and be polled per frame — is `NOT
  SOURCEABLE` from the reference and is ADR-0006's probe; this ADR is written so
  that every `PlannerTask` implementation ADR-0006 names (worker pool,
  time-sliced, immediate) satisfies it.
- **GDD sync: checked 6 referenced GDDs** (`run-structure`, `match-ui`,
  `run-ui`, `boss-ai`, `match-rules`, `systems-index`) — no rename.
  **Cross-ADR alignment (2026-11-03):** this ADR adopts ADR-0006's protocol —
  the planner works on a `RulesEngine.clone()` and the driver **replays** the
  returned `TurnPlan` on the live engine on the main thread — and ADR-0006's
  driver additions (`shutdown()`, `PlannerTask.result()`, `replay_budget_ms`).
  **Additions** to `architecture.md` §API Boundaries reported below:
  `MatchDriver.hooks()`, `on_setting_changed()`, `is_planning()`, `shutdown()`.
  One **pre-existing GDD inconsistency** surfaced, not caused by this ADR:
  run-structure R4 lists `seed` in `MatchResult` while match-rules C14 says the
  record carries no seed; `architecture.md` follows C14 and so does this ADR
  (open point for `/consistency-check`).
- Numbering fixed by DD-X08.
- **TD review 2026-11-03 (acceptance pass over ADR-0001..0011):** Decision 1's
  `EventLog.new(db.config("rng_event_log"))` did not match ADR-0003's
  `EventLog._init(max_events, scope, meta)` or its rule that the composition root
  computes `max_events`; corrected to that constructor. This ADR's driver gate
  (engine answers `NOT_YOUR_TURN` / `CHOICE_PENDING`; only `concede` is queued,
  `ENGINE_BUSY/concede_queued`; `is_planning()` true while any task is live or a
  plan is pending; no event buffer) is kept as the authority; ADR-0006's
  reconciliation text and ADR-0003 rule 7 were aligned to it, and
  `architecture.md` §Data Flow 2 / §Threading now say the planner runs over a
  clone. Dependency ADR-0001 Accepted first; ADR-0007 (ordering note) also
  Accepted first.
- **Accepted 2026-11-03 by technical-director** on the owner's standing approval of the project plan (plan approved 2026-11-03; "accept each" step). Owner may revert to Proposed.
- **Erratum 2026-11-03 (match-ui story authoring)**: `MatchQuery` is a rules-tier read model — `class_name MatchQuery extends RefCounted` in `src/gameplay/match/match_query.gd`, Node-free, built by `MatchDriver.query()` over the live engine and returning value copies. `MatchController` (in `src/ui/match/`) only forwards it. This keeps ADR-0001's one-way dependency (rules never import `src/ui/**`); architecture.md's module table listing `MatchQuery` under Match UI is corrected to Match Rules / driver accordingly.
- **Erratum 2026-11-04 (card-effects story 010)**: the resolver is built as `EffectResolver.new(db, db.config("card_effects"), player_hero_set)` — the third argument is the run hero's set, which Discover's collectible pool needs (ADR-0007 erratum 2026-11-04). The two-argument form in Decision 1 below predates it; `RulesEngine.clone()` passes the same set to the clone's resolver.
- **Post-review fixes 2026-11-03** (`/architecture-review` report
  `architecture-review-2026-11-03.md`, verdict CONCERNS): §Performance
  Implications `replay_budget_ms` default corrected 4 → **2 ms** (matches
  ADR-0006, registry `boss_ai_main_thread` and boss-ai F9 `runtime`); the 🟡
  ADR-0006 vs ADR-0008 drift is closed. Soft dependencies ADR-0007 / ADR-0004
  / ADR-0005 declared under `Depends On`. `TR-boss-ai-004` row added to the
  GDD Requirements table. No decision changed.

## Date

2026-11-03

## Last Verified

2026-11-03 — against Godot 4.7.2, `architecture.md` v1 (§Data Flow 2–3, §API
Boundaries Feature/Presentation, §Threading model placeholder), ADR-0006
(Proposed, same day) and the 2026-11-03 engine probes (Probe A).

## Decision Makers

Jacob (owner; standing approval) · `/architecture-decision` (author) ·
`technical-director` (acceptance, pending).

## Summary

Three systems meet at a match — Run Structure builds it, Boss AI plays one side,
Match UI shows it — and the prototype let the UI own the engine and the AI move
nodes (TD-006, TD-009). This ADR puts one rules-side object, `MatchDriver`
(`src/gameplay/run/`), under Run Structure's ownership: `RunMachine.begin_match()`
constructs it from `MatchConfig` through an injected factory; it builds
`RulesEngine`, `EffectResolver` and `BossAI`, hands the planner a clone through
the `PlannerTask` seam at the phase transitions, replays the returned plan into
the live engine on the main thread inside `tick()`, is the only path from
outside the rules tier into `RulesEngine.submit`, and reports
`match_ended(result)` to `RunMachine` before anything else hears it. Match UI's
`MatchController` wraps the driver and owns nothing; the hand-off is
`MatchConfig` + driver in, `match_view_finished(result)` back after the end
banner (run-ui S11); there is no suspend inside a match — the only exits are
`match_ended` or process exit, and resume restarts the floor with the same
streams (run-structure R8.3).

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (pinned 4.7) |
| **Domain** | Core (rules orchestration; one `Node._process` call site in the UI) |
| **Layer** | Core |
| **Knowledge Risk** | HIGH by version (`VERSION.md`); the APIs the driver itself uses (`RefCounted`, `signal` on a `RefCounted`, `Callable`, `Dictionary`) have no post-cutoff change in `breaking-changes.md`. The threading mechanism behind `PlannerTask` is **NOT SOURCEABLE** and belongs to ADR-0006 |
| **References Consulted** | `VERSION.md`, `breaking-changes.md`, `current-best-practices.md` §GDScript 4.5+ (lambda capture by value — the driver's queued concede, replay cursor and event cursor live in instance fields, never captured locals), `docs/architecture/spikes/2026-11-03-engine-probes.md` Probe A (observed facts only) |
| **Post-Cutoff APIs Used** | None directly. `@abstract PlannerTask` (4.5, sourced) is the seam the driver depends on |
| **Verification Required** | (1) `tests/integration/run_structure/match_handoff_test.gd`: `begin_match` → scripted commands → `match_ended` reaches `RunMachine` before any later-connected listener, and `RunMachine` status has moved (T6–T9) before `match_view_finished` is raised; (2) `NOT SOURCEABLE — frame pacing of `tick()` under a live task` (Probe A measured headless frames at ≈6–7 ms, not 60 Hz): boss-ai A30 measures main-thread AI time per frame ≤ 2 ms with the real `MatchView._process`, replay bounded by `replay_budget_ms`; (3) `weakref` teardown: driver graph freed after `match_view_finished` |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (tier rules; `MatchController` as the UI's only command channel); soft: ADR-0007 (construction order engine → `resolver.bind` → hooks, per the Ordering Note), ADR-0004 (`save_active_run` at S1–S4 is the `MetaApi` the driver's `match_ended` hand-off leads into), ADR-0005 (`hook_installers` in `MatchConfig` and `hooks()` for `collect_state`) — soft edges declared 2026-11-03 per the architecture-review advisory; the acceptance order already honoured them |
| **Enables** | ADR-0006 (the `PlannerTask` seam, the clone-and-replay protocol's driver side and the "no subscriber off-thread" rule are fixed here; 0006 picks the mechanism), ADR-0009 (Match UI consumes `MatchController` + `tick()`), ADR-0011 (Run UI shell consumes `match_requested` / `match_view_finished`) |
| **Blocks** | Run Structure epic (R3/R4/T5–T9 stories), Match UI epic (`MatchView.set_controller`, boss-turn playback), Boss AI integration stories (`forecast`/`plan_turn`/`choose` call sites) |
| **Ordering Note** | ADR-0007 should be Accepted first so `MatchDriver`'s construction order (engine → `resolver.bind` → hooks) is settled; ADR-0006 may be Accepted after this one — the driver runs against `ImmediatePlannerTask` until then and its code does not change with the mechanism |

## Context

### Problem Statement

run-structure Interactions ("Boss AI" row, cross-review C-17) places "the match
driver — the object that constructs the engine, the `BossAI` and calls
`forecast`/`play_turn`/`choose` at the phase transitions" in rules-side code owned
by Run Structure, wrapped but not owned by Match UI's `MatchController`.
match-ui U1/U2/U6 and run-ui U2 (`match` row) / S11 define a one-way scene
hand-off and a single return signal. boss-ai C1.5 requires the driver to keep the
main thread under 2 ms per frame while a boss turn plans. Nobody had yet written
down the driver's API, its `tick()` contract, what happens to a player command
(including `concede`) while the planner is live, who creates the match event log,
when the driver is released, and what "suspend" means inside a match.

### Current State

No code. `architecture.md` §Data Flow 2–3 sketches the paths; §API Boundaries
gives `MatchDriver._init(config, db, settings, planner_task)`, `submit`,
`legal_commands`, `query`, `tick`, `subscribe`, `events_since`, `signal
match_ended`; `RunMachine._init(..., driver_factory: Callable)` and
`begin_match() -> MatchDriver`; `MatchController._init(driver)`;
`RunController.signal match_requested(driver)`; `MatchView.set_controller()` and
`signal match_view_finished(result)`. ADR-0006 (Proposed) fixes
`PlannerTask.start(work)/poll()/result()`, `BossAI.plan_turn(sandbox) ->
TurnPlan`, `TurnPlan {commands[], diagnostics[], expected_checksum, …}`, the
replay-with-checksum rule and `MatchDriver.shutdown()`. Probe A (2026-11-03)
verified `WorkerThreadPool.add_task` + per-frame `is_task_completed` +
`wait_for_task_completion`, `Thread.new().start`, and ~1k-op coroutine chunks
all return a byte-identical result for a `RefCounted`-only planner.

### Constraints

- match-rules C2: `submit` is synchronous; nested `submit` → `ENGINE_BUSY`; the
  rejection-code set is closed. C14: `concede` is legal in every phase except
  `Ended`, and during the boss's turn the in-flight command completes first.
- boss-ai C1.4/C1.5: `forecast` at `PlayerTurn.Main`, `play_turn` at
  `BossTurn.Main`, `choose` whenever `phase == Choice` and `pending_choice.side ==
  boss` (including mid-`play_turn`); ≤ 2 ms main-thread per frame; the Match UI
  paces the burst (U6).
- ADR-0006: the worker touches a **clone**, never the live engine or live log;
  every live mutation (`submit`, `log.append`, `match_ended`) happens on the
  main thread; the player keeps playing during `forecast`; `concede` while a
  task is live is queued, then the plan is discarded unreplayed.
- match-ui U2: three channels only; U6: by `turn_started{side: boss}` the whole
  turn *may* already be in the log; U9: Match UI never navigates and knows
  nothing about floors; `match_view_finished(result)` after a click or 4 s.
- run-ui `match` row / S11: Run UI hidden, not freed; run-scope events arriving
  while the banner shows are buffered and applied at `match_view_finished`.
- run-structure R3/R4/R7/R8: `in_match` is never saved; `suspend` is rejected in
  `in_match`; resume after a mid-match quit restarts the floor with the same
  streams at `draws = 0`; `Treasures.collect_state(hooks, match_result)` before S2.
- rng-event-log / ADR-0003: a match log is sealed on `match_ended` and archived
  to `user://logs/` when `keep_match_logs`; subscribers are synchronous, main
  thread, delivered once in `seq` order after append.
- ADR-0001: rules tier has no Node, no signal emission from a worker; `Boot`
  never holds game state; `MatchView._process` is the only process tick.

### Requirements

- TR-run-structure-002 (`begin_match` builds `MatchConfig`; `MatchResult`
  handling incl. fault → `pre_match`), TR-run-structure-005 (driver ownership),
  TR-match-ui-003 (boss turn already in the log), TR-match-ui-006 (hand-off),
  TR-run-ui-002 (`match` row), TR-boss-ai-002/003, TR-systems-index-002.
- Every `PlannerTask` implementation ADR-0006 names must satisfy the same driver
  contract without a driver change.

## Decision

**One driver per match attempt, constructed by Run Structure, polled by the UI,
the only object that submits to the live engine, and the one that replays the
boss's plan.**

1. **Ownership and construction.** `RunMachine.begin_match()` (T5) builds
   `MatchConfig` per R3, creates a **fresh match `EventLog`** for this attempt
   (`EventLog.new(max_match_events, "match", meta)` — ADR-0003's constructor;
   `max_match_events` is computed once by the composition root from
   `config("rng_event_log")` (F7) and reaches `RunMachine` in `run_config`; the run-scope log is a different
   instance — a sealed log is never reopened, and the match log is sealed on
   `match_ended`) and calls the injected `driver_factory.call(config) ->
   MatchDriver`. `Boot` supplies the factory (`func(cfg): return
   MatchDriver.new(cfg, db, settings_snapshot, <PlannerTask per ADR-0006>)`) so
   the `PlannerTask` implementation and the settings snapshot are composition
   concerns, not `RunMachine`'s. `MatchDriver._init` performs, in order:
   `ProfileResolver.resolve(db.config("ai_profiles"), boss_def, band)`;
   `EffectResolver.new(db, db.config("card_effects"))`; `RulesEngine.new(db,
   db.config("match_rules"), resolver)`; `BossAI.new(boss_def, resolved_profile,
   band, config.rng_ai, op_values, config.log)`; `engine.start(config)` (which
   binds the resolver and installs `player.hook_installers` then
   `boss.hook_installers` before `on_match_start` — ADR-0007/0005); then
   `_after_engine_step()` (below). `RunMachine` keeps the driver in `_driver` and
   connects `driver.match_ended` **first**, before anyone else can.
2. **Command gate.** `MatchDriver.submit(command)` is the only path from outside
   the rules tier into `RulesEngine.submit`. It stamps `command.issuer =
   "player"` (the UI cannot issue a boss command — TD-006) and calls
   `engine.submit` synchronously on the main thread — the live engine is always
   main-thread-owned, so a player command is never blocked by a running task:
   during a **forecast** task the command simply goes through (the task's
   result is validated against the engine's state when it returns); during a
   **boss-turn** or **boss-choice** task the engine itself answers
   `NOT_YOUR_TURN` / `CHOICE_PENDING` for anything but `concede`. The one driver
   rule on top of the engine: a `concede` that arrives while a task is live is
   **queued** (one slot) and returns `{accepted: false, rejection: {code:
   ENGINE_BUSY, detail: "concede_queued"}, events: [-1, -1]}` — it is applied in
   `_on_task_done()` after the plan is discarded (ADR-0006), so no boss command
   is executed after the player conceded; `ENGINE_BUSY` is reused because the C2
   set is closed, and `detail` names the driver case. A `concede` that arrives
   **during replay** (no task live, plan partly replayed) goes straight to the
   engine — the in-flight boss command has already completed synchronously
   (C14) — and the rest of the plan is dropped. After every accepted or rejected
   `submit`, the driver runs `_after_engine_step()`.
3. **Phase schedule (`_after_engine_step()`, main thread, after every engine
   step and after every replayed command).** Reads `engine.phase()`,
   `engine.active_side()`, `engine.pending_choice()`:

   | Observed | Driver action |
   |---|---|
   | `PlayerTurn.Main` and no forecast started for `engine.turn` | `sandbox = engine.clone()`; task: `boss_ai.forecast(sandbox) -> Intent` |
   | `BossTurn.Main` and no plan pending | `sandbox = engine.clone()`; task: `boss_ai.plan_turn(sandbox) -> TurnPlan` (the C2 loop incl. boss `choose` inside the sandbox) |
   | `Choice` with `pending_choice.side == "boss"` and no task live (a player action raised a boss Discover, or a replayed command did) | `sandbox = engine.clone()`; task: `boss_ai.choose(sandbox, pending) -> int`; on return, `engine.submit(choose{issuer: boss, option_index})` on the main thread |
   | `Ended` | drop any pending plan; `engine.end_match()` (resolver `unbind`); emit `match_ended(engine.result())`; the driver accepts nothing further |
   | anything else | nothing — wait for the player |

   Every task runs through the same seam: `planner_task.start(work: Callable)`,
   polled by `tick()` via `planner_task.poll() -> bool`, result read once via
   `planner_task.result()`. The worker is handed the clone, the `ai_<floor>`
   stream and the frozen `CardDatabase` — never the live engine, the live log,
   the driver, a Node or `Boot` (ADR-0006).
4. **`tick()` contract.** Called once per frame from `MatchView._process` through
   `MatchController.tick()`. In order: (a) if a task is live and
   `planner_task.poll()` is true → `_on_task_done()`; (b) if a plan is pending →
   replay commands until the plan is exhausted or `replay_budget_ms`
   (`config("ai_profiles").runtime`, ADR-0006) is spent, carrying the rest to the
   next tick; (c) return. `_on_task_done()`: read `result()`; if a `concede` is
   queued → discard the result, submit the concede, done; if the premise is stale
   (the engine's `turn`/`phase` moved since the clone was taken — e.g. the player
   ended the turn before the forecast returned) → discard, append nothing (boss-ai
   C8 tolerates "plan changed"); otherwise: a forecast → append `ai_intent_shown`
   on the main thread; a boss choice → submit it; a `TurnPlan` → begin replay.
   Replay of one command = append its `ai_decision` diagnostic (`cause_seq = 0`,
   `diagnostic: true`) then `engine.submit(cmd)` with `issuer = "boss"`, fold the
   event types into the running checksum, run `_after_engine_step()`; on
   `!accepted` or, at the end, a checksum mismatch → append `ai_fault {reason:
   replay_divergence, at_index}` and submit `end_turn` (ADR-0006). The driver's
   own per-tick work is one poll plus bounded replay (≤ 2 ms AI per frame,
   boss-ai A30); the time subscribers spend projecting the resulting events is
   Match UI's budget (ADR-0009).
5. **Events reach the UI synchronously on the main thread.** Because every live
   append happens on the main thread, the driver's `subscribe(cb)` registers
   `cb` on the match `EventLog` directly (ADR-0003 subscriber contract: once, in
   `seq` order, after append) and `events_since(seq)` is a pass-through to
   `log.events_since(seq)`. There is no buffer and no replay of events — the
   only "replay" is of commands (Decision 4). The clone's scratch log is never
   visible to the UI. No engine signal is connected in production: the driver
   detects `Ended` by polling `phase()` after each step and emits its own
   `match_ended` once the `match_ended` event has already reached subscribers;
   `RulesEngine.match_ended` stays a unit-test convenience.
6. **Queries.** `query() -> MatchQuery` is built once over the live engine, the
   database and the settings; it answers at all times (the live engine is never
   touched by a worker). `is_planning()` on the driver lets the UI show "boss
   thinking" (U6.1) while a task is live; it is not a lock.
7. **Settings during a match.** The driver takes a settings snapshot at
   construction (`anim_speed` etc. are the UI's; `telegraph_mode` is Boss AI's).
   `MatchView` forwards `settings_changed` to
   `MatchController.on_setting_changed(key, value)` → driver: `telegraph_mode` is
   applied with `boss_ai.set_telegraph_mode(value)` when no task is live, else
   deferred to `_on_task_done()` (the live `BossAI` object is shared with the
   worker only through its immutable profile; the mode is read when the next
   forecast starts). No other key reaches the rules.
8. **Hand-off sequence (Data Flow §3, made exact).**

   ```
   RunShell(boss_intro) ─ intent begin_match ─► RunController ─► RunMachine.begin_match()   # T5: match_attempts[f] += 1; status = in_match
     RunMachine: config, fresh match EventLog, driver = driver_factory.call(config); driver.match_ended.connect(_on_match_ended)
     RunController.match_requested.emit(driver)
   RunShell: hide Run UI (not freed); MatchView.set_controller(MatchController.new(driver)); MatchView projects events_since(0), then subscribes
   MatchView._process → controller.tick()                      # every frame while the view is shown
   ... player submits · forecast/plan tasks run on clones · plans replayed on the main thread · events flow synchronously ...
   driver: phase == Ended → end_match → match_ended.emit(result)
     RunMachine._on_match_ended(result): match_summary = match_log.reduce_to_summary(); treasure_state = Treasures.collect_state(driver.hooks(), result);
                                          T6–T9 (save S2/S5 or S1-shape); emits run_floor_entered / draft_offered / run_ended; _driver = null
     RunShell buffers those run-scope events (S11 rule)
   MatchView: finishes draining, end banner, click or MATCH_END_AUTO_S (4 s) → match_view_finished(result)
   RunShell: MatchView._exit_tree → controller.shutdown(); free/hide MatchView; drop the controller (last strong ref to the driver);
             apply buffered events in seq order → next screen (S11/S11b/S12/S13/S16)
   ```

   Match UI never navigates and never reads `RunState`; the reverse edge is the
   one signal carrying the `MatchResult` Run Structure already processed
   (systems-index Circular Dependencies).
9. **Lifetime and shutdown.** Constructed at T5; `RunMachine` drops its reference
   inside `_on_match_ended` after `collect_state`; the `MatchController` held by
   `MatchView` keeps the driver alive for the banner (queries still answer);
   `MatchView._exit_tree` calls `shutdown()` — if a task is still live (a
   `WorkerThreadPool` task cannot be cancelled, only awaited — ADR-0006) it
   blocks until `poll()` is true and discards the result — then `RunShell` drops
   the controller at `match_view_finished`. The driver graph (driver → engine ↔
   resolver, BossAI, task, match log) is then unreferenced and freed;
   `end_match()`'s `unbind()` broke the engine↔resolver cycle. A fault (T9)
   follows the same path; the next `begin_match` builds a new driver with the
   same `match_<floor>` / `ai_<floor>` streams, which `RunMachine` restores at
   `draws = 0` per R8.3.
10. **Suspend / resume contract.** There is **no** suspend, pause or save inside a
    match: `RunMachine.suspend()` returns `E_BAD_PHASE` in `in_match`
    (run-structure Rejections); the driver has no `suspend()`; Match UI's pause
    menu offers concede and display settings only (match-ui U9). The only exits
    from `in_match` are `match_ended` (win / loss incl. concede / fault) and
    process exit (T10), after which nothing is saved and `resume()` lands in
    `pre_match` for the same floor; `begin_match` then increments
    `match_attempts[floor]` and replays the same streams (R8.3). A `RunState` of
    `in_match` found in a save is coerced to `pre_match` with
    `run_warning{coerced_status}` (R8.6).
11. **Fixtures and the harness use the same driver.** `MatchDebugLoader`
    (match-ui U11) calls `Boot.boot()`, builds the fixture's `MatchConfig`, calls
    the same `driver_factory` (with `ImmediatePlannerTask` — ADR-0006), submits
    the scripted commands through `driver.submit`, calls `tick()` until
    `is_planning()` is false and no plan is pending, and hands
    `MatchController.new(driver)` to `MatchView` — no second driver, no
    hand-built view state. The boss-ai sim harness drives two `MatchDriver`s
    the same way. `RunDebugLoader` never builds a driver (run-ui U10).

### Architecture Diagram

```
                      intents                 commands (7)              builds at T5
  RunShell ─────────► RunController ─────────► RunMachine ─────────► driver_factory ──► MatchDriver (src/gameplay/run/)
     ▲  ▲  match_requested(driver)  ◄──────────┘    ▲ match_ended(result)  ◄──────────────────┤   _init: ProfileResolver → EffectResolver
     │  │                                            │ (first connection)                      │          → RulesEngine → BossAI → start(config)
     │  │ hides Run UI, keeps it                     │                                          │
     │  └── MatchView.set_controller(MatchController.new(driver))                              │ submit(player cmd) ─ issuer=player ─► live RulesEngine.submit (main thread)
     │          │ _process → controller.tick() ──────────────────────────────────────────────► │ tick(): poll PlannerTask → validate premise → replay TurnPlan (≤ replay_budget_ms)
     │          │ subscribe / events_since ◄── match EventLog (all appends on the main thread) ┤ task work: forecast / plan_turn / choose on engine.clone()  ──► worker (ADR-0006)
     │          │ query() ◄── MatchQuery over the live engine (always answers) ────────────────┤ never: a subscriber on a worker, a connected engine signal
     └──────────┴── match_view_finished(result)  (after the end banner; _exit_tree → shutdown(); RunShell applies buffered run-scope events — S11)
```

### Key Interfaces

```gdscript
# src/gameplay/run/match_driver.gd — owned by Run Structure (architecture.md §Feature); additions marked
class_name MatchDriver extends RefCounted
func _init(config: MatchConfig, db: CardDatabase, settings: Dictionary, planner_task: PlannerTask) -> void
func submit(command: Command) -> CommandResult        # PLAYER commands, synchronous on the live engine; concede while a task is live → queued (ENGINE_BUSY/concede_queued)
func legal_commands() -> Array[Command]               # pass-through to the live engine
func query() -> MatchQuery
func tick() -> void                                   # once per frame via MatchController; one poll + replay ≤ replay_budget_ms (ADR-0006)
func subscribe(callback: Callable) -> void            # registers on the match EventLog; main thread, seq order (ADR-0003)
func events_since(seq: int) -> Array                  # pass-through to the match EventLog
func hooks() -> HookRegistry                          # ADDITION: read after Ended only — RunMachine → Treasures.collect_state
func on_setting_changed(key: StringName, value: Variant) -> void   # ADDITION: telegraph_mode → BossAI; deferred while a task is live
func is_planning() -> bool                            # ADDITION: true while a PlannerTask is live or a plan is pending replay (UI "boss thinking"; fixtures)
func shutdown() -> void                               # ADDITION (ADR-0006): blocks until a live task ends, discards its result; MatchView._exit_tree calls it
signal match_ended(result: MatchResult)               # emitted on the main thread after the match_ended event reached subscribers

# src/gameplay/run/run_machine.gd (run-structure R3, R4, T5–T9) — unchanged from architecture.md
class_name RunMachine extends RefCounted
func _init(db: CardDatabase, meta: MetaApi, draft: RewardDraft, treasures: Treasures, run_config: Dictionary, driver_factory: Callable) -> void
func begin_match() -> MatchDriver                     # builds MatchConfig + a fresh match EventLog; connects match_ended first

# src/ai/planner_task.gd — the ADR-0006 seam (owned there; shape repeated for the driver's sake)
@abstract class_name PlannerTask extends RefCounted
@abstract func start(work: Callable) -> void          # work: Callable() -> Variant; exactly once per task object
@abstract func poll() -> bool                          # true once finished; MatchDriver.tick() calls it once per frame, never after it returned true
func result() -> Variant                               # valid only after poll() returned true (ADR-0006)
# BossAI.plan_turn(sandbox: RulesEngine) -> TurnPlan · forecast(sandbox) -> Intent · choose(sandbox, request) -> int  (ADR-0006, boss-ai C1.4)

# src/ui/match/match_controller.gd, match_query.gd (match-ui U1, U2) — wraps, owns nothing
class_name MatchController extends RefCounted
func _init(driver: MatchDriver) -> void
func submit(command: Command) -> CommandResult; func legal_commands() -> Array[Command]; func query() -> MatchQuery
func subscribe(cb: Callable) -> void; func events_since(seq: int) -> Array; func tick() -> void
func on_setting_changed(key: StringName, value: Variant) -> void; func shutdown() -> void; func is_planning() -> bool   # ADDITION: pass-throughs
class_name MatchQuery extends RefCounted               # per architecture.md: phase(), pending_choice(), entity(), hand(), card_text(), legal_commands(), hero_power_state(); value copies; ≤ 2 ms

# src/ui/run/run_controller.gd, src/ui/match/match_view.gd (hand-off) — unchanged
signal match_requested(driver: MatchDriver)            # RunController → RunShell
func set_controller(controller: MatchController) -> void   # MatchView
signal match_view_finished(result: MatchResult)        # MatchView → RunShell, after the end banner
```

### Implementation Guidelines

- `MatchDriver` **must** live in `src/gameplay/run/` and obey ADR-0001's rules
  tier (no Node, no autoload, no `await`); the process tick **must** reach it only
  through `MatchController.tick()` from `MatchView._process`.
- `RunMachine.begin_match()` **must** create a fresh match `EventLog` per attempt
  and **must** connect `driver.match_ended` before returning the driver.
- Only `MatchDriver` may call `RulesEngine.submit` from outside the rules tier;
  it **must** stamp `issuer = "player"` on UI commands and `issuer = "boss"` on
  replayed plan commands; a `concede` while a task is live **must** be queued in
  a single slot, and `_on_task_done()` **must** discard the task's result before
  submitting it.
- The worker **must** receive `engine.clone()`, never the live engine or live
  log; the driver **must never** register a subscriber from a worker, **must
  never** connect `RulesEngine.match_ended`, and **must** emit its own
  `match_ended` only after the `match_ended` event has reached subscribers.
- Every Boss AI entry point **must** be invoked only through
  `PlannerTask.start`, never inline from `submit` or `tick`; `poll()` **must** be
  called at most once per frame and never again after it returned true; replay
  **must** be bounded by `replay_budget_ms` per tick and **must** stop with
  `ai_fault{replay_divergence}` + `end_turn` on a rejected command or a checksum
  mismatch (ADR-0006).
- A task result whose premise is stale (`turn`/`phase` moved since the clone)
  **must** be discarded silently; a forecast's `ai_intent_shown` **must** be
  appended on the main thread by the driver, never by the worker.
- `RunMachine` **must** process `match_ended` (summary, `collect_state`, save,
  status) before `RunShell` sees `match_view_finished`; `RunShell` **must** buffer
  run-scope events during the banner and apply them in `seq` order at
  `match_view_finished` (S11); `MatchView._exit_tree` **must** call `shutdown()`.
- `MatchView` **must never** read `RunState`, navigate, or know about floors;
  `MatchController` **must** hold nothing but the driver reference.
- `RunMachine.suspend()` **must** return `E_BAD_PHASE` in `in_match`; no code
  **may** save, serialise or pause a live match (R7: `in_match` is never saved).
- `MatchDebugLoader` and the sim harness **must** build their driver through the
  same `driver_factory` with `ImmediatePlannerTask` and submit commands through
  `driver.submit` (U11; boss-ai C11).

## Alternatives Considered

### Alternative 1: Match UI owns the driver (`MatchController` constructs the engine)

- **Description**: `RunMachine.begin_match()` returns only `MatchConfig`;
  `MatchController` builds `RulesEngine`/`BossAI` and reports the result back.
- **Pros**: Fewer rules-side classes; the UI already calls `tick()`.
- **Cons**: Puts engine and AI construction in `src/ui/**` (ui-code: display
  only); headless simulation (boss-ai C11 harness, run integration tests) would
  need a UI or a second driver; it is TD-006's shape (UI as the authority over
  the AI's moves).
- **Estimated Effort**: Lower initially.
- **Rejection Reason**: run-structure Interactions (cross-review C-17) and
  match-ui U2 ("boss commands are the Boss AI's, driven by Run Structure's match
  driver, never by this system") already decided against it.

### Alternative 2: `RulesEngine` drives the boss itself (AI injected into the engine)

- **Description**: `MatchConfig.boss.ai` carries a `BossAI`; the engine calls
  `play_turn` inside `submit(end_turn)`.
- **Pros**: One object; no scheduling code.
- **Cons**: Makes the engine depend on `src/ai/` (layer inversion; `ai-code.md`
  2 ms rule would bind the engine); a synchronous `play_turn` inside `submit`
  blocks the main thread ≈ 60 ms at band 3 (boss-ai F7); the engine could no
  longer be tested without an AI; `clone()` would carry an AI.
- **Estimated Effort**: Equal.
- **Rejection Reason**: boss-ai Interactions: "the AI is just another command
  issuer"; the 2 ms budget needs a seam the engine must not know about.

### Alternative 3: The task runs `play_turn` on the **live** engine; the main thread does not touch it meanwhile

- **Description**: The driver hands the live `RulesEngine` to the worker, polls
  it, and forwards `events_since(cursor)` to subscribers when the task returns
  (the shape `architecture.md` §Threading model sketched, and this ADR's first
  draft).
- **Pros**: No replay, no checksum, no `TurnPlan`; the boss turn is in the log
  the moment the task ends.
- **Cons**: The live engine emits `match_ended` (a signal) and appends to a log
  with main-thread subscribers — both off-thread; `forecast` must run while the
  player acts, so the live engine cannot be handed over at `PlayerTurn.Main`;
  `MatchQuery` would have to go dark while a task is live; the UI's `subscribe`
  could not go straight to the log. Thread-safety of a shared live graph is
  `NOT SOURCEABLE`.
- **Estimated Effort**: Lower driver code, higher invariant surface.
- **Rejection Reason**: ADR-0006 (same day) chose plan-on-clone + replay for
  exactly these reasons; one protocol across the two ADRs is worth the replay
  code. Replay equivalence is already a Pillar 4 guarantee (rng-event-log rules
  9–10) and the checksum turns a silent divergence into an `ai_fault`.

### Alternative 4: Suspend mid-match by serialising the event log (restore on resume)

- **Description**: `suspend()` in `in_match` saves the match log; `resume` replays
  it into a new engine.
- **Pros**: No lost progress on quit.
- **Cons**: run-structure R8.3 and its Open Questions defer mid-match restore to
  Vertical Slice; it needs replay-equivalence guarantees proven first; a re-roll
  exploit must be ruled out.
- **Estimated Effort**: Significant.
- **Rejection Reason**: Out of scope by the GDD's own decision; this ADR keeps
  `EffectRuntime` inside `MatchState` (ADR-0007) so the door stays open.

## Consequences

### Positive

- One driver serves play, fixtures, the sim harness and integration tests — the
  evidence path is the shipped path.
- The threading decision (ADR-0006) is contained: the driver, the UI and Run
  Structure are correct for a worker thread, time-slicing or the immediate task
  without change; all live mutation is main-thread by construction, so
  `MatchQuery` and `subscribe` need no busy state.
- TD-006's AI half (AI moves through `submit` with `issuer = "boss"`, UI cannot
  issue boss commands) and TD-009's owner half (run state typed and owned by
  `RunMachine`, match state owned by the engine, nothing global) are structural.

### Negative

- Replay code with a checksum and an `ai_fault` path exists purely to keep the
  worker off the live engine; `replay_budget_ms` and `planner_mode` are two more
  data knobs (ADR-0006's `runtime` block).
- `ENGINE_BUSY` now carries two meanings distinguished only by `detail`
  (`concede_queued` vs the engine's re-entrancy case); the UI copy keys off
  `detail`.
- Four additions to `architecture.md` §API Boundaries (`hooks()`,
  `on_setting_changed()`, `is_planning()`, `shutdown()`), and §Threading model /
  §Data Flow 2 need the ADR-0006 wording ("over a clone", "replayed as
  commands") — to be folded in by `/architecture-review` or
  `/propagate-design-change`.

### Neutral

- The match `EventLog` is per attempt and distinct from the run log; the run log
  keeps `match_summary` (already the GDDs' intent, now explicit).
- `RulesEngine.match_ended` signal stays declared for unit tests but is never
  connected in production.
- match-ui U6's "by `turn_started{side: boss}` the whole turn *may* already be in
  the log" is read literally: with replay spanning ticks the turn arrives over a
  few frames, which the UI's pacing already tolerates.

## Risks

- **A programmer connects the engine signal "because it is there"** → ordering
  bug (RunMachine would hear `match_ended` before the UI projected the event).
  Mitigation: control-manifest Forbidden row; integration test asserts the
  signal has no connections after `begin_match`.
- **Queued concede after the plan would have won** → the plan is discarded
  unreplayed and the concede is applied; the player loses by concede, not by the
  boss's unseen lethal — accepted (C14 says the boss's *in-flight* command
  completes; a plan not yet submitted is not in flight — ADR-0006).
- **Replay divergence** (hook or RNG state differs between clone and live) →
  `ai_fault{replay_divergence}` + `end_turn`, visible in the log; the A30
  equivalence test and ADR-0005's clone-rebind assertion guard it.
- **Driver leaked by a forgotten controller reference** (e.g. `InputRouter`
  caches it). Mitigation: `weakref` teardown test after `match_view_finished`.
- **Run-scope events applied before the banner** (RunShell skips buffering) →
  the player sees the draft screen under the banner. Mitigation: run-ui AC-29
  style integration test; S11 rule in the control manifest.
- **`tick()` not called** (MatchView hidden or paused by the tree) → the plan
  never replays. Mitigation: `MatchView._process` runs while the view is the
  active screen; fixture runs call `tick()` until `is_planning()` is false;
  `shutdown()` on `_exit_tree` never leaves a worker orphaned.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| run-structure.md R3, R4 (TR-run-structure-002) | `begin_match` builds `MatchConfig`; `MatchResult` handling incl. fault → `pre_match`; `collect_state` before S2 | Decisions 1, 8, 9; `hooks()` |
| run-structure.md States T5–T9, Rejections (TR-run-structure-003) | `in_match` entered at `begin_match`, left only by `match_ended`; `suspend`/`abandon` rejected in `in_match` | Decisions 3, 10 |
| run-structure.md R7, R8 (TR-run-structure-004) | `in_match` never saved; resume restarts the floor with the same streams | Decision 10 |
| run-structure.md Interactions "Boss AI" (TR-run-structure-005) | Run Structure owns the driver that constructs engine and `BossAI` and calls `forecast`/`play_turn`/`choose`; wrapped, not owned, by `MatchController` | Decisions 1–4, 8 |
| match-rules.md C2, C14 (TR-match-rules-002, -007) | Synchronous `submit`; closed rejection set; concede legal during the boss turn, in-flight command completes first; `MatchResult` shape | Decision 2 (gate, queued concede, concede during replay), 3 (`Ended` row) |
| match-ui.md U1, U2 (TR-match-ui-001) | `MatchController` injected, owns the engine handle only; three channels | `MatchController` wraps the driver; Decisions 5, 6 |
| match-ui.md U6 (TR-match-ui-003) | Boss turn in the log before the UI paces it; the UI paces the burst | Decisions 3–5 (replayed on the main thread, bounded per tick) |
| match-ui.md Interactions "Run Structure" / "Run UI" (TR-match-ui-006) | Scene swap at `begin_match` with `MatchConfig` + `MatchController`; `match_view_finished(result)` after the banner | Decision 8 |
| match-ui.md U11 (TR-match-ui-004) | Fixtures run the real engine | Decision 11 |
| run-ui.md U2 `match` row, S11 (TR-run-ui-002) | Run UI hidden not freed; control returns on `match_view_finished`; run-scope events buffered | Decision 8 |
| boss-ai.md C1.4 (TR-boss-ai-002) | `forecast` at `PlayerTurn.Main`, `play_turn` at `BossTurn.Main`, `choose` whenever a boss choice is pending | Decision 3 schedule (via clone + replay, ADR-0006) |
| boss-ai.md C1.5, C9 (TR-boss-ai-003) | ≤ 2 ms main-thread per frame; off-thread or time-sliced; budgets are counts | `PlannerTask` seam; `tick()` contract with `replay_budget_ms` |
| systems-index.md Circular Dependencies (TR-systems-index-002) | Match UI ↔ Run UI: one-way scene hand-off; reverse edge a signal only | Decision 8 |
| boss-ai.md C8, DD-X03 (TR-boss-ai-004) | Telegraph events `ai_intent_shown` / `ai_intent_committed` with `effective_mode = min(boss.intent_mode, settings.telegraph_mode)` | Plumbing only: Decision 3 appends `ai_intent_shown` on the main thread from `tick()`; Decision 7 forwards `settings.telegraph_mode` to `BossAI` via `on_setting_changed()`; the `min()` rule itself is `BossAI` logic (boss-ai C8.4), not an architecture decision |

## TD Items Retired

| TD | Prototype root cause | Rule here that rules it out |
|---|---|---|
| TD-006 (AI half; UI half is ADR-0001/0009) | The AI played by reparenting `Control` nodes; cards owned by player 0 | Boss AI plans on a clone and its commands reach the live engine only through the driver's replay with `issuer = "boss"`; the UI's commands are stamped `issuer = "player"`; the UI cannot reach the engine except through the driver |
| TD-009 (owner half; modifier half is ADR-0005, run-record half ADR-0004) | Run state in `set_meta` string keys with no owner; match flow in a singleton | `RunMachine` owns the typed `RunState` and the driver's lifetime; the engine owns `MatchState`; the driver is constructed per attempt and freed after the banner — nothing survives as a global |

## Performance Implications

- **CPU**: `tick()` = one `poll()` + replay bounded by `replay_budget_ms`
  (ADR-0006 default 2 ms per `ai_profiles.json` `runtime.replay_budget_ms`, data-driven; A30 asserts the 2 ms AI share; corrected 2026-11-03 from a stale 4 ms). Each
  replayed command is a normal `submit` (≤ 5 ms worst case, typically far less).
  One `clone()` per forecast and per boss turn on the main thread, in addition to
  the planner's own sandboxes (boss-ai F7 budgets).
- **Memory**: one driver graph per attempt plus one clone per live task, freed
  with the task; no event buffer.
- **Load Time**: none.
- **Network**: N/A.

## Migration Plan

Greenfield. Order: (1) `MatchDriver` with `ImmediatePlannerTask` (ADR-0006) so
all contract tests run single-threaded and replay happens inside the same
`tick()`; (2) `RunMachine.begin_match` + `_on_match_ended` integration test with
a scripted `BossAI` double returning fixed `TurnPlan`s; (3) `MatchController` /
`MatchView.set_controller` / `RunShell` buffering (ADR-0009/0011 stories); (4)
swap in `WorkerPoolPlannerTask` — no driver change expected (ADR-0006's own
acceptance test).

**Rollback plan**: the driver is one class behind `driver_factory`; a different
driver (e.g. inline boss turns for a debug build) is a factory swap.
`ImmediatePlannerTask` is the permanent fallback if ADR-0006's mechanism
regresses.

## Validation Criteria

- `tests/integration/run_structure/match_handoff_test.gd`: `begin_match` →
  scripted win → `RunMachine` status is `post_match_reward` and S2 saved
  **before** a later-connected listener receives `match_ended`; `_driver` is null
  afterwards.
- `tests/unit/run/match_driver_gate_test.gd`: with a fake `PlannerTask` that
  stays live during a boss turn, `submit(play_card)` → engine `NOT_YOUR_TURN`;
  `submit(concede)` → `ENGINE_BUSY/concede_queued`; after `poll()` returns true
  the plan is discarded, the concede applied and `match_ended{reason: concede}`
  emitted with no boss command in the log; a concede during replay ends the turn
  with the remaining plan dropped.
- `tests/unit/run/match_driver_schedule_test.gd`: forecast started exactly once
  per player turn and discarded when the turn ended first; a boss Choice raised
  by a player action starts a `choose` task and the choice is submitted on the
  main thread; a `TurnPlan` with a rejected command produces
  `ai_fault{replay_divergence}` then `end_turn`.
- Equivalence: the same scripted match with `ImmediatePlannerTask` and with
  ADR-0006's worker implementation yields byte-identical event logs (boss-ai
  A30; Probe A pattern).
- `weakref` teardown after `match_view_finished`; `RulesEngine.match_ended` has
  no connections in production; `shutdown()` with a live fake task returns only
  after `poll()` is true.
- Fixture launch (`--fixture=<name>`) goes through `driver_factory` and produces
  the retained PNG (U11, ADR-0010).

## Verification / How We Know

| Claim | Source | Status |
|---|---|---|
| A `RefCounted`-only planner returns a deterministic result from `WorkerThreadPool.add_task` + `is_task_completed` + `wait_for_task_completion`, from `Thread.new().start(...)`, and from ~1k-op time-sliced chunks (max slice ≈ 2.1 ms) | `docs/architecture/spikes/2026-11-03-engine-probes.md` Probe A (observed, 4.7.2 Linux, 4 cores) | observed; mechanism choice is ADR-0006's |
| `is_task_completed` after `wait_for_task_completion` errors (`Invalid Task ID`) — so `poll()` is never called after it returned true | Probe A, warnings | observed; encoded in the guidelines |
| Headless frame pacing ≈ 6–7 ms/frame, not 60 Hz — frame counts are not wall-clock comparable | Probe A | observed; A30 measures on the real view |
| `signal` on a `RefCounted`, `Callable`, `Dictionary` unchanged post-cutoff | `breaking-changes.md` 4.4→4.7 (no rows) | sourced by absence |
| `@abstract` base for `PlannerTask` | `current-best-practices.md` §GDScript 4.5+ | sourced |
| Replay of a command sequence on an equal `rng_match` position reproduces the events | rng-event-log rules 9–10 (design); match-rules C2 `clone()` contract | design-sourced; proven by the A30 equivalence test and the per-turn checksum at runtime |
| Concurrent read-only access to the frozen `CardDatabase` from the worker | — | **NOT SOURCEABLE**; ADR-0006's Verification owns it; this ADR adds nothing shared beyond what ADR-0006 lists |
| `RefCounted` cycle collection | — | **NOT SOURCEABLE**; `weakref` teardown test |

## Related

- Depends on ADR-0001; coordinates with ADR-0006 (clone-and-replay protocol,
  `PlannerTask`, `shutdown()`, `replay_budget_ms`), ADR-0007 (construction
  order, `end_match`/`unbind`), ADR-0003 (match log per attempt, subscriber
  contract), ADR-0005 (`hooks()` → `collect_state`; clone rebind), ADR-0004
  (`in_match` never saved).
- Enables ADR-0009 (Match UI consumes `MatchController`), ADR-0011 (Run UI
  shell consumes `match_requested` / `match_view_finished`).
- `design/gdd/run-structure.md` R3, R4, R7, R8, States T5–T10, Interactions;
  `design/gdd/match-ui.md` U1, U2, U6, U9, U11, Interactions;
  `design/gdd/run-ui.md` U2 `match`, S11/S11b, S23; `design/gdd/boss-ai.md` C1.4,
  C1.5, C9, Interactions; `design/gdd/match-rules.md` C2, C14;
  `design/gdd/systems-index.md` Circular Dependencies.
- `docs/architecture/architecture.md` §Data Flow 2–3, §Threading model, §API
  Boundaries (Feature, Presentation), §Tech-debt retirement mapping;
  `docs/architecture/spikes/2026-11-03-engine-probes.md` Probe A.
- `docs/tech-debt-register.md` TD-006, TD-009.
- Code (once implemented): `src/gameplay/run/match_driver.gd`, `run_machine.gd`,
  `src/ai/planner_task.gd`, `src/ui/match/match_controller.gd`, `match_query.gd`,
  `match_view.gd`, `src/ui/run/run_controller.gd`, `run_shell.gd`.
