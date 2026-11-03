# ADR-0008: Match Driver Ownership and the Run ↔ Match ↔ UI Hand-off

## Status

Proposed

> **Who may move this to `Accepted`: the user, or `technical-director` on the
> user's explicit confirmation. No other agent, and no skill on its own.**
> Stories referencing a `Proposed` ADR are set `Blocked`, and epics require
> `Accepted`, so the field needs a named owner.

Review record for this authoring run (2026-11-03, `/architecture-decision`,
headless, `automation: guided`, `review_mode: lean`, `workflow: standard`):

- **TD-ADR skipped — Lean mode.**
- **Engine specialist validation: NOT ASSESSED** — not spawned in this headless
  run (see ADR-0001 Status). The one engine fact this ADR leans on — that a
  worker thread exists and is polled per frame — is `NOT SOURCEABLE` from the
  reference and is ADR-0006's probe; this ADR is written so that both outcomes
  of that probe satisfy it (`PlannerTask` seam).
- **GDD sync: checked 6 referenced GDDs** (`run-structure`, `match-ui`,
  `run-ui`, `boss-ai`, `match-rules`, `systems-index`) — no rename.
  **Additions** to `architecture.md` §API Boundaries reported below:
  `MatchDriver.hooks()`, `MatchDriver.on_setting_changed()`,
  `MatchQuery.is_busy()`. One **pre-existing GDD inconsistency** surfaced, not
  caused by this ADR: run-structure R4 lists `seed` in `MatchResult` while
  match-rules C14 says the record carries no seed; `architecture.md` follows
  C14 and so does this ADR (open point for `/consistency-check`).
- Numbering fixed by DD-X08.

## Date

2026-11-03

## Last Verified

2026-11-03 — against Godot 4.7.2, `architecture.md` v1 (§Data Flow 2–3, §API
Boundaries Feature/Presentation, §Threading model placeholder) and the
2026-11-03 engine probes (Probe A).

## Decision Makers

Jacob (owner; standing approval) · `/architecture-decision` (author) ·
`technical-director` (acceptance, pending).

## Summary

Three systems meet at a match — Run Structure builds it, Boss AI plays one side,
Match UI shows it — and the prototype let the UI own the engine and the AI move
nodes (TD-006, TD-009). This ADR puts one rules-side object, `MatchDriver`
(`src/gameplay/run/`), under Run Structure's ownership: `RunMachine.begin_match()`
constructs it from `MatchConfig`; it builds `RulesEngine`, `EffectResolver` and
`BossAI`, installs the treasure and passive hooks through the engine, runs the
Boss AI at the phase transitions through the `PlannerTask` seam, forwards events
to the UI on the main thread only, and reports `match_ended(result)` to
`RunMachine` before anything else hears it. Match UI's `MatchController` wraps the
driver and owns nothing; the hand-off is `MatchConfig` + driver in,
`match_view_finished(result)` back after the end banner (run-ui S11); there is no
suspend inside a match — the only exits are `match_ended` or process exit, and
resume restarts the floor with the same streams (run-structure R8.3).

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (pinned 4.7) |
| **Domain** | Core (rules orchestration; one `Node._process` call site in the UI) |
| **Layer** | Core |
| **Knowledge Risk** | HIGH by version (`VERSION.md`); the APIs the driver itself uses (`RefCounted`, `signal` on a `RefCounted`, `Callable`, `Dictionary`) have no post-cutoff change in `breaking-changes.md`. The threading mechanism behind `PlannerTask` is **NOT SOURCEABLE** and belongs to ADR-0006 |
| **References Consulted** | `VERSION.md`, `breaking-changes.md`, `current-best-practices.md` §GDScript 4.5+ (lambda capture by value — the driver's queued concede and event cursor live in instance fields, not captured locals), `docs/architecture/spikes/2026-11-03-engine-probes.md` Probe A (observed facts only) |
| **Post-Cutoff APIs Used** | None directly. `@abstract PlannerTask` (4.5, sourced) is the seam the driver depends on |
| **Verification Required** | (1) `tests/integration/run_structure/match_handoff_test.gd`: `begin_match` → scripted commands → `match_ended` reaches `RunMachine` before any subscriber added after it, and `RunMachine` status has moved (T6–T9) before `match_view_finished` is raised; (2) `NOT SOURCEABLE — frame pacing of `tick()` under a live task` (Probe A measured headless frames at ≈6–7 ms, not 60 Hz): boss-ai A30 measures main-thread time per frame ≤ 2 ms with the real `MatchView._process`; (3) `weakref` teardown: driver graph freed after `match_view_finished` |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (tier rules; `MatchController` as the UI's only command channel) |
| **Enables** | ADR-0006 (the `PlannerTask` seam and the "no subscriber off-thread" rule are fixed here; 0006 picks the mechanism), ADR-0009 (Match UI consumes `MatchController` + `tick()`), ADR-0011 (Run UI shell consumes `match_requested` / `match_view_finished`) |
| **Blocks** | Run Structure epic (R3/R4/T5–T9 stories), Match UI epic (`MatchView.set_controller`, boss-turn playback), Boss AI integration stories (`forecast`/`play_turn`/`choose` call sites) |
| **Ordering Note** | ADR-0007 should be Accepted first so `MatchDriver`'s construction order (engine → `resolver.bind` → hooks) is settled; ADR-0006 may be Accepted after this one — the driver compiles against `PlannerTask` with the main-thread time-slicing implementation until then |

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
`signal match_view_finished(result)`. Probe A (2026-11-03) verified
`WorkerThreadPool.add_task` + per-frame `is_task_completed` +
`wait_for_task_completion`, `Thread.new().start`, and ~1k-op coroutine chunks all
return a byte-identical result for a `RefCounted`-only planner.

### Constraints

- match-rules C2: `submit` is synchronous; nested `submit` → `ENGINE_BUSY`; the
  rejection-code set is closed. C14: `concede` is legal in every phase except
  `Ended`, and during the boss's turn the in-flight command completes first.
- boss-ai C1.4/C1.5: `forecast` at `PlayerTurn.Main`, `play_turn` at
  `BossTurn.Main`, `choose` whenever `phase == Choice` and `pending_choice.side ==
  boss` (including mid-`play_turn`); ≤ 2 ms main-thread per frame; events land
  in the log at once; Match UI paces the burst (U6).
- match-ui U2: three channels only; U6: by `turn_started{side: boss}` the whole
  turn may already be in the log; U9: Match UI never navigates and knows nothing
  about floors; `match_view_finished(result)` after a click or 4 s.
- run-ui `match` row / S11: Run UI hidden, not freed; run-scope events arriving
  while the banner shows are buffered and applied at `match_view_finished`.
- run-structure R3/R4/R7/R8: `in_match` is never saved; `suspend` is rejected in
  `in_match`; resume after a mid-match quit restarts the floor with the same
  streams at `draws = 0`; `Treasures.collect_state(hooks, match_result)` before S2.
- rng-event-log: a match log is sealed on `match_ended` and archived to
  `user://logs/` when `keep_match_logs`; subscribers are synchronous and run on
  the main thread (ADR-0003).
- ADR-0001: rules tier has no Node, no signal emission from a worker; `Boot`
  never holds game state; `MatchView._process` is the only process tick.

### Requirements

- TR-run-structure-002 (`begin_match` builds `MatchConfig`; `MatchResult`
  handling incl. fault → `pre_match`), TR-run-structure-005 (driver ownership),
  TR-match-ui-003 (boss turn already in the log), TR-match-ui-006 (hand-off),
  TR-run-ui-002 (`match` row), TR-boss-ai-002/003, TR-systems-index-002.
- Both outcomes of ADR-0006's probe (worker thread or time-slicing) must satisfy
  the same driver contract.

## Decision

**One driver per match attempt, constructed by Run Structure, polled by the UI,
authoritative over who may talk to the engine and when.**

1. **Ownership and construction.** `RunMachine.begin_match()` (T5) builds
   `MatchConfig` per R3, creates a **fresh match `EventLog`** for this attempt
   (`EventLog.new(db.config("rng_event_log"))`; the run-scope log is a different
   instance — a sealed log is never reopened, and rng-event-log seals the match
   log on `match_ended`) and calls the injected `driver_factory.call(config) ->
   MatchDriver`. `Boot` supplies the factory (`func(cfg): return
   MatchDriver.new(cfg, db, settings_snapshot, PlannerTaskImpl.new())`) so the
   `PlannerTask` implementation and the settings snapshot are composition
   concerns, not `RunMachine`'s. `MatchDriver._init` performs, in order:
   `ProfileResolver.resolve(db.config("ai_profiles"), boss_def, band)`;
   `EffectResolver.new(db, db.config("card_effects"))`; `RulesEngine.new(db,
   db.config("match_rules"), resolver)`; `BossAI.new(boss_def, resolved_profile,
   band, config.rng_ai, op_values, config.log)`; `engine.start(config)` (which
   binds the resolver and installs `player.hook_installers` then
   `boss.hook_installers` before `on_match_start` — ADR-0007); then
   `_after_engine_step()` (below). `RunMachine` keeps the driver in `_driver` and
   connects `driver.match_ended` **first**, before anyone else can.
2. **Command gate.** `MatchDriver.submit(command)` is the only path from outside
   the rules tier into `RulesEngine.submit`. It stamps `command.issuer = "player"`
   (the UI cannot issue a boss command — TD-006). If a `PlannerTask` is live: a
   non-`concede` command returns `{accepted: false, rejection: {code: ENGINE_BUSY,
   detail: "planner_live"}, events: [-1, -1]}` without touching the engine or the
   log (both are in use by the task); a `concede` is **queued** (one slot) and
   returns `{accepted: false, rejection: {code: ENGINE_BUSY, detail:
   "concede_queued"}}` — the eventual `match_ended` event is the UI's truth.
   `ENGINE_BUSY` is reused because the C2 set is closed; `detail` distinguishes
   the two driver cases from the engine's re-entrancy case. If no task is live:
   `engine.submit(command)`, then forward events, then `_after_engine_step()`.
3. **Phase schedule (`_after_engine_step()`, main thread, after every engine
   step).** Reads `engine.phase()`, `engine.active_side()`, `engine.pending_choice()`:

   | Observed | Driver action |
   |---|---|
   | `PlayerTurn.Main` and no `Intent` yet for `engine.turn` | start task: `boss_ai.forecast(engine)` |
   | `BossTurn.Main` | start task: `_boss_turn()` = loop { `boss_ai.play_turn(engine)`; while `phase == Choice and pending_choice.side == "boss"`: `engine.submit(choose(boss_ai.choose(engine, pending)))` } until `phase != BossTurn.Main` and no boss choice pending |
   | `Choice` with `pending_choice.side == "boss"` outside the boss turn (a player action raised a boss Discover) | start task: `engine.submit(choose(boss_ai.choose(engine, pending)))` |
   | `Ended` | forward remaining events; `engine.end_match()` (resolver `unbind`); emit `match_ended(engine.result())`; the driver accepts nothing further |
   | anything else | nothing — wait for the player |

   Every task runs through the same seam: `planner_task.start(work: Callable)`,
   polled by `tick()` via `planner_task.poll() -> bool`. While a task is live the
   main thread **does not touch** `RulesEngine`, `EffectResolver`, `BossAI` or the
   match `EventLog` (Probe A verified only a `RefCounted` graph untouched by the
   main thread; the driver makes that the invariant whatever ADR-0006 picks).
4. **`tick()` contract.** Called once per frame from `MatchView._process` through
   `MatchController.tick()`. If no task is live it returns immediately. If a task
   is live: `if planner_task.poll(): _on_task_done()`. `_on_task_done()` forwards
   `log.events_since(_cursor)` to subscribers, applies a queued `concede` (a
   `MATCH_ENDED` rejection from the engine is swallowed — the boss already won),
   applies a deferred setting (below), then `_after_engine_step()`. The driver's
   own work per `tick()` is one poll plus bookkeeping (≤ 2 ms, boss-ai A30); the
   time subscribers spend applying the forwarded burst is Match UI's budget
   (ADR-0009), and the UI may spread projection over frames.
5. **Events reach the UI on the main thread only.** The driver **never** calls
   `EventLog.subscribe`; it keeps `_cursor` (last forwarded `seq`) and
   `_delivered: Array[Dictionary]` (references to the forwarded event
   Dictionaries, not copies). `subscribe(cb)` registers a UI callback;
   `events_since(seq)` answers from `_delivered`, so it is safe to call while a
   task is live and always returns exactly what subscribers have seen. Forwarding
   happens after each main-thread `submit` returns and in `_on_task_done()`. No
   engine signal is connected in production: `RulesEngine.match_ended` would fire
   on the worker when the boss wins mid-task, so the driver detects `Ended` by
   polling `phase()` and emits its own `match_ended` on the main thread; the
   engine's signal remains a unit-test convenience.
6. **Queries.** `query() -> MatchQuery` is built once over the engine, the
   database and the settings. While a task is live `MatchQuery.is_busy()` is true
   and the engine-backed queries (`phase`, `pending_choice`, `entity`, `hand`,
   `legal_commands`, `hero_power_state`) return `{}` / `[]` / `null`; `card_text`
   (database only) always answers. The UI renders numbers from the projection
   (U2/U3) and locks controls on `turn_started{side: boss}` (U6.1), so the busy
   window ("boss thinking") costs it nothing visible.
7. **Settings during a match.** The driver takes a settings snapshot at
   construction (`anim_speed` etc. are the UI's; `telegraph_mode` is Boss AI's).
   `MatchView` forwards `settings_changed` to `MatchController.on_setting_changed(key,
   value)` → driver: if `key == telegraph_mode`, call
   `boss_ai.set_telegraph_mode(value)` now when no task is live, else defer it to
   `_on_task_done()`. No other key reaches the rules.
8. **Hand-off sequence (Data Flow §3, made exact).**

   ```
   RunShell(boss_intro) ─ intent begin_match ─► RunController ─► RunMachine.begin_match()   # T5: match_attempts[f] += 1; status = in_match
     RunMachine: config, fresh match EventLog, driver = driver_factory.call(config); driver.match_ended.connect(_on_match_ended)
     RunController.match_requested.emit(driver)
   RunShell: hide Run UI (not freed); MatchView.set_controller(MatchController.new(driver)); MatchView subscribes, projects events_since(0)
   MatchView._process → controller.tick()                      # every frame while the view is shown
   ... player submits · tasks run · bursts forwarded ...
   driver: phase == Ended → forward → end_match → match_ended.emit(result)
     RunMachine._on_match_ended(result): match_summary = match_log.reduce_to_summary(); treasure_state = Treasures.collect_state(driver.hooks(), result);
                                          T6–T9 (save S2/S5 or S1-shape); emits run_floor_entered / draft_offered / run_ended; _driver = null
     RunShell buffers those run-scope events (S11 rule)
   MatchView: finishes draining, end banner, click or MATCH_END_AUTO_S (4 s) → match_view_finished(result)
   RunShell: free/hide MatchView, drop the controller (last strong ref to the driver), apply buffered events in seq order → next screen (S11/S11b/S12/S13/S16)
   ```

   Match UI never navigates and never reads `RunState`; the reverse edge is the
   one signal carrying the `MatchResult` Run Structure already processed
   (systems-index Circular Dependencies).
9. **Lifetime.** Constructed at T5; `RunMachine` drops its reference inside
   `_on_match_ended` after `collect_state`; the `MatchController` held by
   `MatchView` keeps the driver alive for the banner (queries still answer);
   `RunShell` drops the controller at `match_view_finished`. The driver graph
   (driver → engine ↔ resolver, BossAI, task, match log) is then unreferenced and
   freed; `end_match()`'s `unbind()` broke the engine↔resolver cycle. A fault
   (T9) follows the same path; the next `begin_match` builds a new driver with the
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
11. **Fixtures use the same driver.** `MatchDebugLoader` (match-ui U11) calls
    `Boot.boot()`, builds the fixture's `MatchConfig`, calls the same
    `driver_factory`, submits the scripted commands through `driver.submit`, and
    hands `MatchController.new(driver)` to `MatchView` — no second driver, no
    hand-built view state. `RunDebugLoader` never builds a driver (run-ui U10).

### Architecture Diagram

```
                      intents                 commands (7)              builds at T5
  RunShell ─────────► RunController ─────────► RunMachine ─────────► driver_factory ──► MatchDriver (src/gameplay/run/)
     ▲  ▲  match_requested(driver)  ◄──────────┘    ▲ match_ended(result)  ◄──────────────────┤   _init: ProfileResolver → EffectResolver
     │  │                                            │ (first connection)                      │          → RulesEngine → BossAI → start(config)
     │  │ hides Run UI, keeps it                     │                                          │
     │  └── MatchView.set_controller(MatchController.new(driver))                              │ submit(player cmd) ── gate ──► RulesEngine.submit
     │          │ _process → controller.tick() ──────────────────────────────────────────────► │ tick(): poll PlannerTask → forward events → schedule
     │          │ subscribe / events_since ◄──────────── main-thread forwarding only ──────────┤ PlannerTask.start(forecast | _boss_turn | boss choose)
     │          │ query() ◄── MatchQuery (is_busy while a task is live) ───────────────────────┤ never a subscriber; never a worker-side signal
     └──────────┴── match_view_finished(result)  (after the end banner; RunShell applies buffered run-scope events — S11)
```

### Key Interfaces

```gdscript
# src/gameplay/run/match_driver.gd — owned by Run Structure (architecture.md §Feature); additions marked
class_name MatchDriver extends RefCounted
func _init(config: MatchConfig, db: CardDatabase, settings: Dictionary, planner_task: PlannerTask) -> void
func submit(command: Command) -> CommandResult        # PLAYER commands; ENGINE_BUSY/planner_live while a task is live; concede queued (ENGINE_BUSY/concede_queued)
func legal_commands() -> Array[Command]               # [] while a task is live
func query() -> MatchQuery
func tick() -> void                                   # once per frame from MatchView._process via MatchController; ≤ 2 ms own work
func subscribe(callback: Callable) -> void            # callback(event: Dictionary), main thread, seq order
func events_since(seq: int) -> Array                  # from the driver's delivered list; safe while a task is live
func hooks() -> HookRegistry                          # ADDITION: read after Ended only — RunMachine → Treasures.collect_state
func on_setting_changed(key: StringName, value: Variant) -> void   # ADDITION: telegraph_mode → BossAI; deferred while a task is live
func is_planning() -> bool                            # ADDITION: true while a PlannerTask is live (UI "boss thinking" label; tests)
signal match_ended(result: MatchResult)               # emitted on the main thread after the Ended events were forwarded

# src/gameplay/run/run_machine.gd (run-structure R3, R4, T5–T9) — unchanged from architecture.md
class_name RunMachine extends RefCounted
func _init(db: CardDatabase, meta: MetaApi, draft: RewardDraft, treasures: Treasures, run_config: Dictionary, driver_factory: Callable) -> void
func begin_match() -> MatchDriver                     # builds MatchConfig + a fresh match EventLog; connects match_ended first

# src/ai/planner_task.gd — the ADR-0006 seam (architecture.md §Core — Boss AI)
@abstract class_name PlannerTask extends RefCounted
@abstract func start(work: Callable) -> void
@abstract func poll() -> bool                          # true once finished; MatchDriver.tick() calls it once per frame

# src/ui/match/match_controller.gd, match_query.gd (match-ui U1, U2) — wraps, owns nothing
class_name MatchController extends RefCounted
func _init(driver: MatchDriver) -> void
func submit(command: Command) -> CommandResult; func legal_commands() -> Array[Command]; func query() -> MatchQuery
func subscribe(cb: Callable) -> void; func events_since(seq: int) -> Array; func tick() -> void
func on_setting_changed(key: StringName, value: Variant) -> void   # ADDITION: pass-through
class_name MatchQuery extends RefCounted
func is_busy() -> bool                                 # ADDITION: true while a task is live; engine-backed queries answer {} / [] / null then
# phase(), pending_choice(), entity(), hand(), card_text(), legal_commands(), hero_power_state() per architecture.md

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
  it **must** stamp `issuer = "player"` and **must** reject (`ENGINE_BUSY`) every
  command but `concede` while a task is live; `concede` **must** be queued in a
  single slot and applied in `_on_task_done()`.
- While a `PlannerTask` is live, main-thread code **must never** read or write
  `RulesEngine`, `EffectResolver`, `BossAI` or the match `EventLog`;
  `MatchQuery.is_busy()` **must** be true and engine-backed queries **must** return
  empty values.
- The driver **must never** register an `EventLog` subscriber and **must never**
  connect `RulesEngine.match_ended`; it forwards events itself and emits its own
  `match_ended` on the main thread after forwarding the `Ended` events.
- Boss AI entry points **must** be invoked only through `PlannerTask.start`, never
  inline from `submit` or `tick`, so the mechanism ADR-0006 selects applies
  uniformly to `forecast`, `play_turn` and `choose`.
- `RunMachine` **must** process `match_ended` (summary, `collect_state`, save,
  status) before `RunShell` sees `match_view_finished`; `RunShell` **must** buffer
  run-scope events during the banner and apply them in `seq` order at
  `match_view_finished` (S11).
- `MatchView` **must never** read `RunState`, navigate, or know about floors;
  `MatchController` **must** hold nothing but the driver reference.
- `RunMachine.suspend()` **must** return `E_BAD_PHASE` in `in_match`; no code
  **may** save, serialise or pause a live match (R7: `in_match` is never saved).
- `MatchDebugLoader` **must** build its driver through the same `driver_factory`
  and submit fixture commands through `driver.submit` (U11).

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
- **Cons**: Makes the engine depend on `src/ai/` (layer inversion, `ai-code.md`
  2 ms rule would bind the engine); a synchronous `play_turn` inside `submit`
  blocks the main thread ≈ 60 ms at band 3 (boss-ai F7); the engine could no
  longer be tested without an AI; `clone()` would carry an AI.
- **Estimated Effort**: Equal.
- **Rejection Reason**: boss-ai Interactions: "the AI is just another command
  issuer"; the 2 ms budget needs a seam the engine must not know about.

### Alternative 3: Driver subscribes to the `EventLog` and relays through a thread-safe buffer

- **Description**: Register one `EventLog.subscribe` callback that appends to a
  `Mutex`-guarded buffer from whatever thread appends; `tick()` drains it.
- **Pros**: Events flow during the task (a progress feed while the boss thinks).
- **Cons**: `Mutex` semantics on 4.7 are `NOT SOURCEABLE`; a callback running on
  the worker is exactly what the threading rule forbids; the UI cannot show
  boss actions before the plan is complete anyway (U6 paces a burst).
- **Estimated Effort**: Higher, with an unverified primitive.
- **Rejection Reason**: Adds an engine-level unknown for no player-visible gain;
  the cursor-and-forward design needs nothing from the threading API beyond
  `poll()`.

### Alternative 4: Suspend mid-match by serialising the event log (restore on resume)

- **Description**: `suspend()` in `in_match` saves the match log; `resume` replays
  it into a new engine.
- **Pros**: No lost progress on quit.
- **Cons**: run-structure R8.3 and its Open Questions defer mid-match restore to
  Vertical Slice; it needs replay-equivalence guarantees (rng-event-log rule 9)
  proven first; a re-roll exploit must be ruled out.
- **Estimated Effort**: Significant.
- **Rejection Reason**: Out of scope by the GDD's own decision; this ADR keeps
  `EffectRuntime` inside `MatchState` (ADR-0007) so the door stays open.

## Consequences

### Positive

- One driver serves play, fixtures, the sim harness and integration tests — the
  evidence path is the shipped path.
- The threading decision (ADR-0006) is contained: the driver, the UI and Run
  Structure are correct for a worker thread or for time-slicing without change.
- TD-006's AI half (AI moves through `submit` with `issuer = "boss"`, UI cannot
  issue boss commands) and TD-009's owner half (run state typed and owned by
  `RunMachine`, match state owned by the engine, nothing global) are structural.

### Negative

- A short input-dead window at the start of every player turn while `forecast`
  runs (rejections `planner_live`); forecast is cheap by design (boss-ai F7) and
  the UI shows "boss thinking" from `is_planning()`.
- `ENGINE_BUSY` carries three meanings distinguished only by `detail`; the UI
  copy keys off `detail`.
- Three additions to `architecture.md` §API Boundaries (`hooks()`,
  `on_setting_changed()`, `is_busy()`) to be folded in by `/architecture-review`.

### Neutral

- The match `EventLog` is per attempt and distinct from the run log; the run log
  keeps `match_summary` (already the GDDs' intent, now explicit).
- `RulesEngine.match_ended` signal stays declared for unit tests but is never
  connected in production.

## Risks

- **A programmer connects the engine signal "because it is there"** → fires on
  the worker thread. Mitigation: control-manifest Forbidden row; integration
  test asserts the signal has no connections after `begin_match`.
- **Queued concede after the boss already won** → engine `MATCH_ENDED`; swallowed
  by design, the UI's banner follows the logged `match_ended`.
- **Driver leaked by a forgotten controller reference** (e.g. `InputRouter` caches
  it). Mitigation: `weakref` teardown test after `match_view_finished`.
- **Run-scope events applied before the banner** (RunShell skips buffering) →
  the player sees the draft screen under the banner. Mitigation: run-ui AC-29
  style integration test; S11 rule in the control manifest.
- **`tick()` not called** (MatchView hidden or paused by the tree) → the task
  never completes from the UI's point of view. Mitigation: `MatchView._process`
  runs with `process_mode` always while the view is the active screen; fixture
  runs call `tick()` in a loop until `is_planning()` is false.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| run-structure.md R3, R4 (TR-run-structure-002) | `begin_match` builds `MatchConfig`; `MatchResult` handling incl. fault → `pre_match`; `collect_state` before S2 | Decisions 1, 8, 9; `hooks()` |
| run-structure.md States T5–T9, Rejections (TR-run-structure-003) | `in_match` entered at `begin_match`, left only by `match_ended`; `suspend`/`abandon` rejected in `in_match` | Decisions 3, 10 |
| run-structure.md R7, R8 (TR-run-structure-004) | `in_match` never saved; resume restarts the floor with the same streams | Decision 10 |
| run-structure.md Interactions "Boss AI" (TR-run-structure-005) | Run Structure owns the driver that constructs engine and `BossAI` and calls `forecast`/`play_turn`/`choose`; wrapped, not owned, by `MatchController` | Decisions 1–3, 8 |
| match-rules.md C2, C14 (TR-match-rules-002, -007) | Synchronous `submit`; closed rejection set; concede legal during the boss turn, in-flight command completes first; `MatchResult` shape | Decision 2 (gate, queued concede), 3 (`Ended` row) |
| match-ui.md U1, U2 (TR-match-ui-001) | `MatchController` injected, owns the engine handle only; three channels | `MatchController` wraps the driver; Decision 5, 6 |
| match-ui.md U6 (TR-match-ui-003) | Boss turn already in the log when the UI sees it; UI paces the burst | Decisions 3–5 |
| match-ui.md Interactions "Run Structure" / "Run UI" (TR-match-ui-006) | Scene swap at `begin_match` with `MatchConfig` + `MatchController`; `match_view_finished(result)` after the banner | Decision 8 |
| match-ui.md U11 (TR-match-ui-004) | Fixtures run the real engine | Decision 11 |
| run-ui.md U2 `match` row, S11 (TR-run-ui-002) | Run UI hidden not freed; control returns on `match_view_finished`; run-scope events buffered | Decision 8 |
| boss-ai.md C1.4 (TR-boss-ai-002) | `forecast` at `PlayerTurn.Main`, `play_turn` at `BossTurn.Main`, `choose` whenever a boss choice is pending | Decision 3 schedule |
| boss-ai.md C1.5, C9 (TR-boss-ai-003) | ≤ 2 ms main-thread per frame; off-thread or time-sliced; budgets are counts | `PlannerTask` seam; `tick()` contract |
| systems-index.md Circular Dependencies (TR-systems-index-002) | Match UI ↔ Run UI: one-way scene hand-off; reverse edge a signal only | Decision 8 |

## TD Items Retired

| TD | Prototype root cause | Rule here that rules it out |
|---|---|---|
| TD-006 (AI half; UI half is ADR-0001/0009) | The AI played by reparenting `Control` nodes; cards owned by player 0 | Boss AI acts only through `engine.submit` inside a `PlannerTask`; the UI's commands are stamped `issuer = "player"` by the driver; the UI cannot reach the engine except through the driver |
| TD-009 (owner half; modifier half is ADR-0005, run-record half ADR-0004) | Run state in `set_meta` string keys with no owner; match flow in a singleton | `RunMachine` owns the typed `RunState` and the driver's lifetime; the engine owns `MatchState`; the driver is constructed per attempt and freed after the banner — nothing survives as a global |

## Performance Implications

- **CPU**: `tick()` own work = one `poll()` + cursor bookkeeping per frame (≤ 2 ms,
  A30). Forwarding a boss turn's burst (typically tens to a few hundred events)
  happens in the completion frame; subscriber cost is ADR-0009's. Player `submit`
  path unchanged from the engine's ≤ 5 ms.
- **Memory**: `_delivered` holds references to event Dictionaries already owned
  by the log (≈ 8 bytes each, ≤ `max_match_events` 10,000); one driver graph per
  attempt, freed after the banner.
- **Load Time**: none.
- **Network**: N/A.

## Migration Plan

Greenfield. Order: (1) `MatchDriver` with a **synchronous** `PlannerTask`
implementation (`start` runs `work` immediately, `poll` returns true) so all
contract tests run single-threaded; (2) `RunMachine.begin_match` + `_on_match_ended`
integration test with a scripted `BossAI` double; (3) `MatchController` /
`MatchView.set_controller` / `RunShell` buffering (ADR-0009/0011 stories); (4)
swap in ADR-0006's `PlannerTask` — no driver change expected.

**Rollback plan**: the driver is one class behind `driver_factory`; a different
driver (e.g. inline boss turns for a debug build) is a factory swap. The
synchronous `PlannerTask` is the permanent fallback if ADR-0006's mechanism
regresses.

## Validation Criteria

- `tests/integration/run_structure/match_handoff_test.gd`: `begin_match` →
  scripted win → `RunMachine` status is `post_match_reward` and S2 saved
  **before** a late subscriber receives `match_ended`; `_driver` is null afterwards.
- `tests/unit/run/match_driver_gate_test.gd`: with a fake `PlannerTask` that
  stays live, `submit(play_card)` → `ENGINE_BUSY/planner_live`, no engine call;
  `submit(concede)` → `ENGINE_BUSY/concede_queued`; after `poll()` returns true,
  concede applied and `match_ended{reason: concede}` emitted; a queued concede
  after a boss win is swallowed.
- `tests/unit/run/match_driver_schedule_test.gd`: `forecast` started exactly once
  per player turn; boss turn task loops through a boss Discover; boss Choice
  raised during the player's turn starts a `choose` task.
- Equivalence: the same scripted match with the synchronous `PlannerTask` and
  with ADR-0006's implementation yields byte-identical event logs (boss-ai A30;
  Probe A pattern).
- `weakref` teardown after `match_view_finished`; `RulesEngine.match_ended` has
  no connections in production.
- Fixture launch (`--fixture=<name>`) goes through `driver_factory` and produces
  the retained PNG (U11, ADR-0010).

## Verification / How We Know

| Claim | Source | Status |
|---|---|---|
| A `RefCounted`-only planner returns a deterministic result from `WorkerThreadPool.add_task` + `is_task_completed` + `wait_for_task_completion`, from `Thread.new().start(...)`, and from ~1k-op time-sliced chunks (max slice ≈ 2.1 ms) | `docs/architecture/spikes/2026-11-03-engine-probes.md` Probe A (observed, 4.7.2 Linux, 4 cores) | observed; mechanism choice is ADR-0006's |
| `is_task_completed` after `wait_for_task_completion` errors (`Invalid Task ID`) — so `poll()` must stop after completion | Probe A, warnings | observed; encoded as "`poll()` once true is never called again" |
| Headless frame pacing ≈ 6–7 ms/frame, not 60 Hz — frame counts are not wall-clock comparable | Probe A | observed; A30 measures on the real view |
| `signal` on a `RefCounted`, `Callable`, `Dictionary` unchanged post-cutoff | `breaking-changes.md` 4.4→4.7 (no rows) | sourced by absence |
| `@abstract` base for `PlannerTask` | `current-best-practices.md` §GDScript 4.5+ | sourced |
| Thread-safety of GDScript `RefCounted` graphs when the main thread does not touch them | — | **NOT SOURCEABLE** from the reference; Probe A observed no warning for Dictionary/Array/RefCounted use; this ADR's invariant (main thread touches nothing while a task is live) is what the equivalence test proves |
| `RefCounted` cycle collection | — | **NOT SOURCEABLE**; `weakref` teardown test |

## Related

- Depends on ADR-0001; coordinates with ADR-0007 (construction order,
  `end_match`/`unbind`), ADR-0003 (match log per attempt, subscriber contract),
  ADR-0005 (`hooks()` → `collect_state`), ADR-0004 (`in_match` never saved).
- Enables ADR-0006 (`PlannerTask` mechanism), ADR-0009 (Match UI consumes
  `MatchController`), ADR-0011 (Run UI shell consumes `match_requested` /
  `match_view_finished`).
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
