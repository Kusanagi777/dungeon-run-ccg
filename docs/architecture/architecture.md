# Deckdelve (Dungeon Run CCG) — Master Architecture

## Document Status
- Version: 1
- Last Updated: 2026-11-03
- Engine: Godot 4.7.2 (GDScript; Forward+; 2D; `docs/engine-reference/godot/VERSION.md`)
- Workflow: `standard` (layer map + critical ADR list required; the fuller sections are written because all 13 GDDs are rich and Approved) · docs.density `balanced` · review_mode `lean` · automation `guided`
- GDDs Covered: card-database, rng-event-log, match-rules, card-effects, boss-ai, heroes, run-structure, reward-draft, treasures, meta-progression, match-ui, run-ui, content (13 of 13; `design/gdd/systems-index.md` v2026-11-03), plus `design/gdd/game-concept.md` and `design/design-decisions.md` (DD-T01..T05, DD-X01..X08)
- ADRs Referenced: none exist yet. `docs/architecture/modifier-hook-chain.md` is unnumbered reverse-documented prior art (DD-X08) and is superseded by ADR-0005 below.
- TR registry: `docs/architecture/tr-registry.yaml` is empty (`requirements: []`) — **every TR-ID in this document is provisional** until `/architecture-review` registers it.
- TD-ARCHITECTURE: 2026-11-03 — skipped — Lean mode
- LP-FEASIBILITY: 2026-11-03 — skipped — Lean mode
- Authored in a headless run with no `AskUserQuestion` answerer: every gated choice took the recommended option and is listed under **Decisions taken** at the end. `godot-specialist` was not spawned: the three open engine facts (threading, atomic rename, renderer under Xvfb) are NOT SOURCEABLE from `docs/engine-reference/godot/` and a specialist answering from pre-4.3 training data is exactly what VERSION.md warns against — they are closed by the headless probes named in the ADR list, not by opinion.

---

## Engine Knowledge Gap Summary

Engine: Godot 4.7.2 (pinned 4.7). LLM training covers ~4.3; 4.4 is thin; 4.5, 4.6, 4.7 are post-cutoff HIGH risk (VERSION.md). This is a 2D, single-player, turn-based card game: no 3D physics, no networking, no navigation, no skeletal animation, so most HIGH-risk headline changes do not touch it. What does:

| Domain | Risk | Post-cutoff facts this architecture relies on (source) | Systems affected |
|---|---|---|---|
| GDScript / Core | HIGH | An override of a typed method inherits the return type and needs an explicit `return` (4.7, `breaking-changes.md`, `current-best-practices.md`); lambdas capture locals by value, share state through a Dictionary (`current-best-practices.md`); `@abstract` classes and methods (4.5); variadic `...args` (4.5); `Object.is_class()` takes `StringName` (4.7); packed-array element writes no longer call the property setter (4.7) | every module; base classes `Screen`, `Presenter`, `Validator` use `@abstract`; event subscribers are lambdas |
| Core — RNG | **NOT SOURCEABLE** | `RandomNumberGenerator.seed` / `randi()` are not covered by the reference (rng-event-log rule 6 says the same); the design depends only on "same seed, same sequence within one engine version"; `tests/helpers/test_rng_stream.gd` verifies this on the installed 4.7.2 | RNG & Event Log (ADR-0003) |
| Core — file I/O | MEDIUM / **NOT SOURCEABLE** | `FileAccess.store_*` return `bool` since 4.4 (sourced, `breaking-changes.md` 4.3→4.4); rename atomicity of `DirAccess.rename_absolute()` on Windows and Linux is **not** in the reference (meta-progression M4.1) | Meta Progression (ADR-0004, probe) |
| Core — threading | **NOT SOURCEABLE** | No scripting or threading page exists under `docs/engine-reference/godot/modules/`; `WorkerThreadPool`, `Thread`, `Mutex` behaviour on 4.7 is unverified (boss-ai C1.5) | Boss AI planner (ADR-0006, probe) |
| UI | HIGH | Dual-focus system: mouse hover is separate from keyboard/gamepad focus (4.6, `modules/ui.md`, `modules/input.md`); `Control.offset_transform_*` for hover/press lifts inside containers (4.7, `modules/ui.md`); `RichTextLabel` image API renames (4.7); `FoldableContainer` (4.5); AccessKit screen-reader support (4.5); new-project stretch defaults changed in 4.7 but **this project keeps `canvas_items` / `keep`** (existing `project.godot`, DD-T05) | Match UI, Run UI (ADR-0009, ADR-0011) |
| Input | HIGH | Mouse/keyboard events report `InputEvent.DEVICE_ID_MOUSE` / `DEVICE_ID_KEYBOARD`, never `device == 0` (4.7, `modules/input.md`); SDL3 gamepad driver (4.5) | Match UI `InputRouter`, Run UI focus graph |
| Animation | MEDIUM | `Tween.tween_await()` (4.7, `modules/animation.md`); `AnimationMixer` base class (4.3) — the UI uses `Tween` only, no `AnimationTree` | Match UI `AnimationQueue` (ADR-0009) |
| Rendering | HIGH / **NOT SOURCEABLE** | Forward+ / Mobile / Compatibility selection and D3D12 default on Windows are sourced (`modules/rendering.md`); `CanvasItem` lines lose their antialiasing feather (4.7); whether Forward+ initialises under Xvfb on the CI runner is **not** in the reference (game-concept Technical Risks) | screenshot evidence rig (ADR-0010, probe) |
| Resources | MEDIUM | `duplicate_deep()` for nested Resources (4.5, `deprecated-apis.md`) — **not needed**: rules state holds Dictionaries/Arrays/RefCounted, never Resources, so `MatchState.clone()` is a hand-written copy | Match Rules |
| Tooling | sourced | gdUnit4 6.2.3 exit codes 0/100/101/103/105; a fresh clone needs `godot --headless --path . --import` first; `--check-only` is not a parse check when a script names an autoload — the framework's parse check is `.claude/scripts/godot-parse-check.gd` (`current-best-practices.md` § Command Line) | tests/, CI, composition root |

Domains with no post-cutoff exposure in this project: Physics (unused), Navigation (unused), Networking (none, anti-pillar), Audio (minimal SFX; the 4.7 `area_mask` default change does not apply to a plain `AudioStreamPlayer`).

**Decision taken (Phase 0d):** proceed and flag HIGH-risk domains throughout; the three NOT SOURCEABLE facts get a headless probe before their ADR is Accepted (gate-technical-setup condition, TD panel).

---

## Technical Requirements Baseline

Extracted from 13 GDDs | 71 requirements | 0 registered, 71 provisional (TR registry: empty). IDs run from `TR-<system>-001` per `bash .claude/scripts/registry.sh next-id tr <system>`; `/architecture-review` makes them permanent. The system slug is the GDD filename stem.

| Req ID (provisional) | GDD | Requirement | Domain |
|---|---|---|---|
| TR-card-database-001 | card-database CR-1 | The Card Database is the only parser of `assets/data/*.json`; definition files `{schema_version, records[]}` and config files `{schema_version, config{}}` served via `config(name)` | Core |
| TR-card-database-002 | CR-3, CR-5 | Nine-stage load pipeline with delegated validators injected at composition (effects, ai_profile, unlock, treasure tags, one per config file); `Failed` load has no main menu (CR-8) | Core |
| TR-card-database-003 | CR-6 | Queries are pure reads on a frozen snapshot, results id-ascending (seeded draws depend on it) | Core |
| TR-card-database-004 | CR-9 | `data_version` = first 16 hex of SHA-256 over canonical serialisation of every file, stable across machines | Core |
| TR-card-database-005 | Formulas | `Unloaded → Ready` ≤ `data_load_budget_ms` (200), snapshot ≤ `data_memory_budget_mb` (4), synchronous at boot | Core / perf |
| TR-rng-event-log-001 | rules 1–6 | One `RngService(run_seed, data_version)`; memoised named streams `run`, `match_<f>`, `draft_<f>`, `ai_<f>`; `fork(label)`; draw API `randi_range`, `randf`, `shuffle`, `weighted_pick` | Core |
| TR-rng-event-log-002 | rule 7 | No code under the rules tree calls global RNG; randomness is an injected parameter | Core |
| TR-rng-event-log-003 | rules 9–10 | Replay equivalence per command sequence; `snapshot()` / `restore()` rebuild streams from `draws` counts | Core / Save |
| TR-rng-event-log-004 | rules 11–15 | Append-only log `{seq, turn, type, payload, cause_seq}`, one event per mutation, JSON-only payloads, sealed on `match_ended` / `run_ended`, `subscribe` / `events_since` | Core |
| TR-rng-event-log-005 | rule 12a | Diagnostic events (`command_rejected`, `ai_decision`, …) go on the same log with `payload.diagnostic = true` | Core |
| TR-rng-event-log-006 | F7, rule 18 | `max_match_events = log_memory_budget_bytes / avg_event_bytes` (10,000 at 2 MB); overflow is a fault; raw match logs to `user://logs/<run_id>/floor_<n>_attempt_<k>.json` when `keep_match_logs` | Core / perf |
| TR-match-rules-001 | C1 | `RulesEngine` owns one `MatchState`; plain data, no Node references; derived values never stored | Core |
| TR-match-rules-002 | C2 | `submit(command) → CommandResult`, `legal_commands()`; illegal moves are data (closed rejection code set); synchronous; re-entrant `submit` → `ENGINE_BUSY` | Core |
| TR-match-rules-003 | C2, C3 | `MatchState.clone()` deep copy carrying the `HookRegistry`, a detached scratch log and a copied `rng_match` state; engine never seeds a stream | Core |
| TR-match-rules-004 | C3 | `MatchConfig {floor, band, rng_match, rng_ai, log, player{hero_def_id, deck, hook_installers}, boss{boss_def_id, deck, health, hook_installers, ai_id}}` is the only input | Core |
| TR-match-rules-005 | Interactions | The primitive API (`draw`, `apply_damage`, … `discard`) is the only way match state mutates; each call emits one event | Core |
| TR-match-rules-006 | Interactions, C10 | 15 trigger points fired by the engine; 12 hook points with fold-then-clamp semantics; C10 resolution loop with `RESOLUTION_STEP_CAP` | Core |
| TR-match-rules-007 | C14, C15 | `MatchResult {result win/loss/fault, winner, reason, floor, turns, turns_per_side, stats, final health}`; C15 is the authoritative event vocabulary (DD-X04) | Core |
| TR-match-rules-008 | Input Responsiveness | `submit()` ≤ 5 ms worst case, `legal_commands()` ≤ 2 ms | perf |
| TR-card-effects-001 | C1 | Effect objects are plain JSON (`trigger, scope, condition, targets, ops[], once_per_turn`); `targeting_spec(def_id)` is derived from the one `chosen` play selector, never stored | Core |
| TR-card-effects-002 | C5, C6 | Resolver composes card text from engine primitives only; one effect pass = one C10 step; binding at `RulesEngine.start` | Core |
| TR-card-effects-003 | C8, C6 | Discover / Choose One raise exactly one `ChoiceRequest`, pausing resolution with a continuation resumed by `choose` | Core |
| TR-card-effects-004 | C9 | Treasure and passive effects bind to hook points (trigger hooks as synchronous steps; value hooks as folds) or run as hero-slot observers | Core |
| TR-card-effects-005 | C10 | `validate_effects(host_kind, host_id, effects[]) → report[]` with the closed `E_FX_*` set, injected into Card Database stage 7 | Core |
| TR-card-effects-006 | F6 | Static step bound per effect ≤ `EFFECT_STATIC_STEP_LIMIT` (250); `MAX_OPS_PER_EFFECT` 8 | Core |
| TR-boss-ai-001 | C1 | `BossAI` is a `RefCounted` pure function of (observable state, profile, stream position); reads only `legal_commands()` and `clone()`; never reads hidden information | Core |
| TR-boss-ai-002 | C1.4 | Entry points `forecast(engine) → Intent`, `play_turn(engine)`, `choose(engine, request) → int`, all synchronous | Core |
| TR-boss-ai-003 | C1.5, C9, F7 | ≤ 2 ms main-thread time per frame; planner off-thread or time-sliced (mechanism by ADR); budgets are counts, 50 ms per turn is the p95 acceptance target | Core / threading |
| TR-boss-ai-004 | C8, DD-X03 | Telegraph events `ai_intent_shown` / `ai_intent_committed` with `effective_mode = min(boss.intent_mode, settings.telegraph_mode)` | Core |
| TR-boss-ai-005 | C10, F9 | `ai_profiles.json` config with resolved profile `default ⊕ archetype ⊕ band ⊕ boss_override`; validator injected at stage 7 | Core / Data |
| TR-boss-ai-006 | C11 | Headless simulation harness `tests/integration/boss_ai/sim_harness.gd` writing `production/qa/sim/<boss_id>_<date>.json` | Test |
| TR-heroes-001 | H-1, H-3 | Heroes are `HeroDef` data; hero powers are `hero_power`-trigger effects (DD-M13); nothing hero-specific in code | Feature / Data |
| TR-run-structure-001 | R1 | `RunState` record schema (JSON-only) with `validate()` invariants; `draft_state` and `treasure_state` opaque blobs | Feature |
| TR-run-structure-002 | R2, R3, R4 | `new_run`, `begin_match` building `MatchConfig`, `MatchResult` handling incl. fault → `pre_match` | Feature |
| TR-run-structure-003 | States, T1–T21 | Explicit transition table over `status`; seven commands (`new_run`, `begin_match`, `draft_pick`, `abandon`, `resume`, `suspend`, `return_to_menu`); `E_BAD_PHASE` elsewhere | Feature |
| TR-run-structure-004 | R7, R8 | Save points S1–S5 through Meta's persistence API; `in_match` never saved; resume restores RNG snapshot and reopens the run log; resume after mid-match quit = restart with the same streams | Feature / Save |
| TR-run-structure-005 | Interactions "Boss AI" | Run Structure owns the **match driver** that constructs `RulesEngine` and `BossAI` at `begin_match` and calls `forecast` / `play_turn` / `choose` at phase transitions; the driver is rules-side code wrapped by Match UI's `MatchController` | Core |
| TR-reward-draft-001 | D1 | `init_run(run_state) → draft_state`, `offer(kind, run_state, stream) → Offer{option_ids[], flags[]}`, `pick(kind, id, offer, run_state) → Pick`; `offer` is a pure function of (run_state, stream position) and mutates nothing | Feature |
| TR-reward-draft-002 | D3, D7 | Exclusion and pity derived from `run_state.drafts[]`; unlock-filtered treasure pool snapshotted once at `init_run` | Feature |
| TR-treasures-001 | T2 | `HookRegistry` per match on `MatchState.hooks`: ordered `HookEntry {host_kind, host_id, side, effect_id, effect}` per hook point; installation order only; owner-scoped by `side`; no autoload, no back-reference | Core |
| TR-treasures-002 | T3 | `installers_for(treasure_ids) → HookInstaller[]` pure and idempotent; duplicate host skipped with `hook_install_skipped` | Feature |
| TR-treasures-003 | T4, T6 | `collect_state(hooks, match_result) → Dictionary` after `match_ended`; `pool(unlocked_keys, exclude_ids)` membership predicate, id-ascending | Feature |
| TR-treasures-004 | F5 | 12-entry fold < 0.05 ms; three installed treasures add < 2 ms per match; no allocation in the fold | perf |
| TR-meta-progression-001 | M1 | One `user://profile.json` with the M1.2 shape and the M1.3 persistence API (`save_active_run`, `load_active_run`, `clear_active_run`, `archive_run`, `is_hero_unlocked`, `unlocked_keys`, settings, run log pages, notifications) | Foundation / Save |
| TR-meta-progression-002 | M4 | Atomic write: `.tmp` → flush → rename old to `.bak` → rename `.tmp` to `profile.json`; `E_IO` leaves the previous files intact; migrations `migrate_v{k}_to_v{k+1}` as pure functions | Foundation / Save |
| TR-meta-progression-003 | M5 | Load order `profile.json` → `.bak` → fresh; corrupt copies kept; newer schema → `ReadOnly`; tamper tolerance with clamping and `profile_repaired` logging | Foundation / Save |
| TR-meta-progression-004 | M6 | `profile.lock` heartbeat; second instance loads `ReadOnly`, mutators return `E_READONLY` | Foundation / Save |
| TR-meta-progression-005 | M9, DD-X07 | Settings record owned here, defaults from `config("profile_defaults")`, applied via `settings_changed{key, value}`; MVP ships an in-memory stub (systems-index Circular Dependencies) | Foundation |
| TR-meta-progression-006 | F5, M4.3 | Profile ≤ `max_profile_bytes` (2 MB); synchronous save ≤ `max_save_ms` (50) at `run_log_cap` | perf |
| TR-match-ui-001 | U1, U2 | `MatchView` scene + `MatchController` (injected) + `MatchQuery` + `MatchViewState` + `AnimationQueue` + presenters + `InputRouter`; three channels only: commands in, events out, queries out | Presentation |
| TR-match-ui-002 | U3, U4 | Presentation model is a projection of events; `AnimStep` FIFO grouped by command root (`cause_seq = 0`), coalescing, speed divisor, skip-all ≤ 100 ms, idle invariant (presenters == view-state) | Presentation |
| TR-match-ui-003 | U6 | Boss turn is already in the log when the UI sees it; UI paces the burst, compressing to `max_turn_playback_s` | Presentation |
| TR-match-ui-004 | U11 | Debug entry points `--fixture=<name>`, `--pose`, `--pause-at`, `--anim-speed`, `--ai-debug` via `OS.get_cmdline_user_args()`; fixtures `tests/fixtures/match_ui/<name>.json` run the **real engine**; `MatchDebugLoader` absent from release exports | Presentation / Test |
| TR-match-ui-005 | Input Responsiveness | Latency table: pickup 16 ms, drag 16 ms, release→first event 50 ms, rejection 50 ms, skip 100 ms, End Turn→intent 300 ms, hover 100 ms | perf |
| TR-match-ui-006 | Interactions "Run UI" | Hand-off: Run UI swaps `MatchView` in at `begin_match` with `MatchConfig` + `MatchController`; Match UI emits `match_view_finished(result)` after the end banner | Presentation |
| TR-run-ui-001 | U1 | `RunShell` root scene with screen stack and `ShellState`; `RunController` is the only object talking to Run Structure, Reward Draft and Meta; screens get read models and send `intent(name, args)`; every visible mutation renders from an event | Presentation |
| TR-run-ui-002 | U2 | Screen inventory with the complete intent → command map; `data_error` screen over a `Failed` load | Presentation |
| TR-run-ui-003 | U3 | Mouse primary, keyboard complete; focus ring separate from hover (4.6 dual focus); gamepad maps to the focus graph | Presentation / Input |
| TR-run-ui-004 | U10 | `--run-ui-screen=<id> --run-ui-fixture=<name>` loads `tests/fixtures/run_ui/<name>.json` into an in-memory Meta stub | Presentation / Test |
| TR-run-ui-005 | F1 | Restart ≤ `restart_budget_ms` (5000); `new_run` ≤ 200 ms, `intro_ready` ≤ 300 ms, `select_ready` ≤ 300 ms | perf |
| TR-content-001 | CN-6 | Every batch loads with zero errors through a headless validate command (`tools/content/validate.gd`) that prints the report and exits non-zero; `content_budgets.json` is tooling-only | Tooling |
| TR-content-002 | CN-6.4 | Archived run logs and sim outputs are the inputs of `/balance-check` | Tooling |
| TR-game-concept-001 | Technical Considerations | Headless test and screenshot evidence on Linux CI (Xvfb); Forward+ may need the Compatibility renderer for capture | Rendering / Test |
| TR-design-decisions-001 | DD-T02 | Match and run rules are `RefCounted` GDScript with no Node references; UI subscribes to events and issues commands | Architecture |
| TR-design-decisions-002 | DD-T01 | All definitions are JSON under `assets/data/` with snake_case keys and `schema_version`; the profile is `user://profile.json` | Data |
| TR-design-decisions-003 | DD-T05 | 1280x720 logical, `canvas_items` stretch, mouse primary, keyboard shortcuts | Presentation |
| TR-systems-index-001 | Circular Dependencies | Run Structure ↔ Meta: Meta exposes M1.3, Run Structure owns R1; MVP ships a Meta stub | Architecture |
| TR-systems-index-002 | Circular Dependencies | Match UI ↔ Run UI: one-way scene hand-off; the reverse edge is a signal only | Architecture |
| TR-systems-index-003 | Circular Dependencies | Treasures ↔ Reward Draft: Treasures owns definitions and the chain; Reward Draft reads the pool and the run writes `treasure_granted` | Architecture |
| TR-tech-debt-001 | TD-001..012 | The production tree rules out each prototype root cause (mapping table below) | Architecture |

No GDD contributed nothing: Heroes and Content are data-only systems and contribute data/tooling rows by design.

---

## Architecture Principles

1. **Rules are data in, data out.** Everything under `src/gameplay/` and `src/ai/` is `RefCounted`, takes its dependencies as constructor arguments, references no Node, no autoload and no scene, and runs headless under gdUnit4 (DD-T02, TD-001/005/006). A rule that needs the scene tree is a design error.
2. **One mutation, one event, one log.** Every state change goes through an engine primitive that appends exactly one `{seq, turn, type, payload, cause_seq}` event; the UI renders from events and never from engine state; diagnostics share the log (DD-T04, Pillar 4).
3. **Randomness is a parameter.** One `RngService` per run, named memoised streams handed down through `MatchConfig` and `offer()`; nothing in the rules tree touches global RNG; tests inject literal seeds (DD-T03, TD-007).
4. **Commands in, events out, queries read copies.** Human input, Boss AI and Run Structure all talk to the engine through `submit()`; the UI's only other channel is a read-only query returning values (TD-006, match-ui U2). Illegal moves are data, never exceptions.
5. **Data owns the numbers; code owns the verbs.** Definitions and every tuning knob live in `assets/data/*.json` and reach code only through `CardDatabase.config()`; `schema_version_current` is the one exempt literal (DD-T01, card-database CR-5, TD-008).
6. **Composition happens once, at the edge.** A single thin `Boot` autoload composes services and injects them; it owns no game state and no rules; rules code never names it (section "Dependency injection and the composition root").

---

## System Layer Map

```
┌───────────────────────────────────────────────────────────────────────────────┐
│ PRESENTATION  src/ui/                                        owner: ui-programmer │
│   Match UI  (match_view.tscn, MatchController, MatchQuery, MatchViewState,       │
│              AnimationQueue, presenters, InputRouter, MatchDebugLoader)           │
│   Run UI    (run_shell.tscn, RunController, screens, ShellState, toasts,         │
│              RunDebugLoader)                                                     │
│   src/scenes/  main.tscn (boot scene) · composition entry only                   │
├───────────────────────────────────────────────────────────────────────────────┤
│ FEATURE       src/gameplay/run/, draft/, treasures/, heroes/   gameplay-programmer│
│   Run Structure (RunMachine, RunState/RunRecord, MatchDriver)                     │
│   Reward Draft  (RewardDraft)        Treasures (Treasures, HookInstaller)         │
│   Heroes        (data access only)   Content   (assets/data/*.json + tools/)      │
├───────────────────────────────────────────────────────────────────────────────┤
│ CORE          src/gameplay/match/, effects/  ·  src/ai/   gameplay-/ai-programmer │
│   Match Rules   (RulesEngine, MatchState, primitives, HookRegistry)               │
│   Card Effects  (EffectResolver, EffectValidator, EffectRuntime)                  │
│   Boss AI       (BossAI planner, PlannerTask — threading seam)                    │
├───────────────────────────────────────────────────────────────────────────────┤
│ FOUNDATION    src/core/                                   owner: engine-programmer │
│   Card Database (CardDatabase loader + config())   RNG & Event Log (RngService,   │
│   RngStream, EventLog)   Meta Progression persistence (ProfileStore, atomic       │
│   write, lock, migrations)   SettingsBus   Boot (composition root autoload)       │
├───────────────────────────────────────────────────────────────────────────────┤
│ PLATFORM      Godot 4.7.2 · GDScript · Forward+ (capture renderer per ADR-0010)   │
│               FileAccess/DirAccess · RandomNumberGenerator · Tween · Control ·    │
│               OS.get_cmdline_user_args · (WorkerThreadPool — ADR-0006 probe)      │
└───────────────────────────────────────────────────────────────────────────────┘
          dependencies point DOWN only; events and signals travel UP only
```

Meta Progression is a Feature-layer system in the GDD index, but its **persistence half** (file format, atomic write, lock, migrations — the `ProfileStore`) is Foundation: Run Structure cannot save without it and it wraps platform file APIs. Its **rules half** (unlock evaluation, statistics fold) stays Feature in `src/gameplay/meta/`. Content is authored data plus tooling and has no runtime module of its own.

### System → layer → directory → owning agent

| System | Layer | Directory (code root `src/`, Godot row of `directory-structure.md`) | Primary classes | Owning agent | Reviewer |
|---|---|---|---|---|---|
| Card Database | Foundation | `src/core/data/` | `CardDatabase`, `DataLoader`, `ValidationReport`, record Dictionaries (CardDef, HeroDef, HeroPowerDef, BossDef, TreasureDef, BundleDef) | engine-programmer | godot-gdscript-specialist |
| RNG & Event Log | Foundation | `src/core/rng/`, `src/core/log/` | `RngService`, `RngStream`, `EventLog` | engine-programmer | godot-gdscript-specialist |
| Meta Progression (persistence) | Foundation | `src/core/save/` | `ProfileStore`, `AtomicFileWriter`, `ProfileLock`, `ProfileMigrations`, `SettingsBus` | engine-programmer | technical-director |
| Boot / composition root | Foundation | `src/core/boot.gd` (the one autoload) | `Boot` | engine-programmer | technical-director |
| Match Rules | Core | `src/gameplay/match/` | `RulesEngine`, `MatchState`, `PlayerState`, `Character`, `Enchantment`, `Weapon`, `CardInstance`, `MatchConfig`, `CommandResult`, `MatchResult`, `HookRegistry`, `HookEntry` | gameplay-programmer | lead-programmer |
| Card Effects | Core | `src/gameplay/effects/` | `EffectResolver`, `EffectValidator`, `EffectRuntime`, `Selectors`, `Ops`, `ChoiceRequest` | gameplay-programmer | lead-programmer |
| Boss AI | Core | `src/ai/` | `BossAI`, `Planner`, `LethalSearch`, `Scorer`, `ProfileResolver`, `PlannerTask` | ai-programmer | lead-programmer |
| Heroes | Feature | `src/gameplay/heroes/` | `Heroes` (thin data access over `CardDatabase`) | gameplay-programmer | systems-designer |
| Run Structure | Feature | `src/gameplay/run/` | `RunMachine`, `RunState`, `RunRecord`, `DraftRecord`, `MatchDriver` | gameplay-programmer | lead-programmer |
| Reward Draft | Feature | `src/gameplay/draft/` | `RewardDraft`, `Offer`, `Pick` | gameplay-programmer | economy-designer |
| Treasures | Feature | `src/gameplay/treasures/` | `Treasures`, `HookInstaller`, `TreasureValidator` | gameplay-programmer | systems-designer |
| Meta Progression (rules) | Feature | `src/gameplay/meta/` | `UnlockEvaluator`, `StatsFold`, `MetaProgression` (facade over `ProfileStore`), `MetaStub` | gameplay-programmer | systems-designer |
| Match UI | Presentation | `src/ui/match/` | `MatchView`, `MatchController`, `MatchQuery`, `MatchViewState`, `AnimationQueue`, `HandPresenter`, `BoardPresenter`, `HeroPresenter`, `FeedPresenter`, `OverlayPresenter`, `TargetingArrow`, `InputRouter`, `MatchDebugLoader` | ui-programmer | ux-designer |
| Run UI | Presentation | `src/ui/run/`, `src/ui/shared/` | `RunShell`, `RunController`, `ShellState`, `Screen` (base), one script per U2 screen, `ToastLayer`, `RunDebugLoader` | ui-programmer | ux-designer |
| Content | Feature (data) | `assets/data/*.json`, `tools/content/validate.gd` | — | systems-designer / game-designer (data), tools-programmer (validator) | economy-designer |

### Directory layout

```
src/
  core/
    boot.gd                 # Boot autoload — composition root, no game state
    data/                   # CardDatabase, DataLoader, ValidationReport
    rng/                    # RngService, RngStream
    log/                    # EventLog
    save/                   # ProfileStore, AtomicFileWriter, ProfileLock, ProfileMigrations, SettingsBus
  gameplay/                 # pure RefCounted rules — no Node, no autoload reference
    match/                  # RulesEngine, MatchState & records, HookRegistry
    effects/                # EffectResolver, EffectValidator, EffectRuntime
    run/                    # RunMachine, RunState/RunRecord, MatchDriver
    draft/                  # RewardDraft
    treasures/              # Treasures, HookInstaller, TreasureValidator
    heroes/                 # Heroes data access
    meta/                   # UnlockEvaluator, StatsFold, MetaProgression facade, MetaStub
  ai/                       # BossAI, Planner, LethalSearch, Scorer, ProfileResolver, PlannerTask
  ui/                       # display-only; may hold Nodes; never mutates state outside submit()
    match/                  # match_view.tscn + presenters
    run/                    # run_shell.tscn + screens
    shared/                 # theme resource, focus helpers, card frame scene
  scenes/
    main.tscn               # run/main_scene — calls Boot.boot() then opens RunShell
assets/data/                # DD-T01 JSON files (definition + config), schema_version 1
tests/
  unit/<system>/            # [system]_[feature]_test.gd per test-standards.md
  integration/<system>/     # boss_ai/sim_harness.gd, run save/resume, Match↔Run hand-off
  fixtures/match_ui/*.json  # U11 fixtures (MatchConfig + scripted commands)
  fixtures/run_ui/*.json    # U10 fixtures (profile + RunRecord + offer)
  helpers/                  # TestConstants, factories, doubles (TODO(E1/E2) swap markers)
  smoke/
tools/content/validate.gd   # headless validate command (content CN-6.3)
production/qa/evidence/     # retained screenshots; production/qa/sim/ harness output
user://                     # profile.json, profile.bak, profile.json.tmp, profile.lock,
                            # profile.corrupt-<ts>.json, runs/<run_id>.json, logs/<run_id>/floor_<n>_attempt_<k>.json
```

`.claude/rules/engine-code.md` governs `src/core/**`, `gameplay-code.md` governs `src/gameplay/**`, `ai-code.md` governs `src/ai/**`, `ui-code.md` governs `src/ui/**`, `data-files.md` governs `assets/data/**/*.json`, `test-standards.md` governs `tests/**`. The directory split is chosen so each rule file applies to exactly the code it was written for.

**Engine awareness check (Core and Foundation):** Card Database touches file I/O (`FileAccess`, sourced 4.4 `bool` returns) and `JSON` (LOW); RNG touches `RandomNumberGenerator` (NOT SOURCEABLE — verified empirically by `tests/helpers/test_rng_stream.gd` self-test on 4.7.2); ProfileStore touches `DirAccess.rename_absolute` (NOT SOURCEABLE atomicity, ADR-0004 probe); Boss AI touches threading (NOT SOURCEABLE, ADR-0006 probe); Match Rules and Card Effects touch no engine API beyond `RefCounted`, `Dictionary`, `Array`, `StringName` (LOW).

---

## Module Ownership

### Foundation layer

| Module | Owns | Exposes | Consumes | Engine APIs (version, risk) |
|---|---|---|---|---|
| `CardDatabase` | The frozen definition snapshot, the frozen config bodies, `data_version`, the `ValidationReport`, state `Unloaded/Loading/Ready/Failed/Reloading` | CR-6 queries (`card`, `hero`, `hero_power`, `boss`, `treasure`, `bundle`, `has`, `cards_by_*`, `collectible_pool`, `bundle_pool`, `treasure_pool`, `bosses_in_band`, `heroes`, `config`, `data_version`, `report`), `load(validators)`, `reload()` (debug) | `assets/data/*.json`; injected validators from Card Effects, Boss AI, Meta, Treasures and every config owner | `FileAccess` (4.4 `bool` returns, sourced), `JSON.parse_string` (LOW), `HashingContext` SHA-256 for CR-9 (LOW, pre-cutoff) |
| `RngService` / `RngStream` | `run_seed`, `data_version`, memoised streams and their `draws` | `stream(name)`, `snapshot()`, `restore(snapshot)`; per stream `randi_range`, `randf`, `shuffle`, `weighted_pick`, `fork`, `draws` | nothing | `RandomNumberGenerator` (**NOT SOURCEABLE**; verified by helper self-test) |
| `EventLog` | The append-only event array, `current_turn`, `Open/Faulted/Sealed`, `max_events`, subscribers | `append(type, payload, cause_seq) → seq`, `set_turn(n)`, `subscribe(cb)`, `events_since(seq)`, `snapshot()`, `to_json()`, `from_json()`, `reduce_to_summary()` | `log_memory_budget_bytes`, `keep_match_logs` from `config("rng_event_log")` | `FileAccess` for `user://logs/` writes (LOW); `Callable` subscribers (lambdas capture by value — `current-best-practices.md`) |
| `ProfileStore` (+ `AtomicFileWriter`, `ProfileLock`, `ProfileMigrations`) | `user://profile.json` and companions, `write_seq`, `ReadOnly` state, the `settings{}` record | The M1.3 persistence API; `settings_changed{key, value}` through `SettingsBus` | `config("profile_defaults")`; `RunRecord` dicts from Run Structure (opaque) | `FileAccess.store_string → bool` (4.4, sourced), `DirAccess.rename_absolute` (**atomicity NOT SOURCEABLE**, ADR-0004 probe), `Time.get_unix_time_from_system` (LOW), `OS.get_process_id` for the lock (LOW) |
| `SettingsBus` | Nothing — a `RefCounted` with one signal | `settings_changed(key: StringName, value: Variant)` | `ProfileStore` emits; Match UI, Run UI, Boss AI subscribe | Godot signals (LOW) |
| `Boot` (autoload) | Service handles only: `card_database`, `profile_store`, `settings_bus`, `booted` flag | `boot() → BootResult`, `services() → Services` (a plain RefCounted bag) | all of the above | `Node` autoload (LOW); `OS.get_cmdline_user_args()` (LOW, pre-cutoff) |

### Core layer

| Module | Owns | Exposes | Consumes | Engine APIs |
|---|---|---|---|---|
| `RulesEngine` + `MatchState` | The one `MatchState` per match (C1), phase machine, `next_entity_id`, the C10 loop, `win_loss_check`, the `HookRegistry` instance | `start(config)`, `submit(command) → CommandResult`, `legal_commands()`, `phase()`, `pending_choice()`, `result()`, `state_snapshot(entity_id)` (value copies for `MatchQuery`), `clone()`; the primitive API and trigger points to `EffectResolver` | `MatchConfig`; `CardDatabase` reads; `rng_match`; `log`; `EffectResolver` callbacks; `config("match_rules")` | none beyond `RefCounted`/`Dictionary` (LOW) |
| `EffectResolver` + `EffectRuntime` | Effect index per card instance, `counters[source_id][key]`, `once_marks`, the trigger queue, the Choice continuation | `resolve(trigger_point, ctx)`, `legal_targets(def_id, source) → entity_id[]`, `targeting_spec(def_id)`, `recompute_auras()`, `bind(engine, installers)`, `ChoiceRequest` | engine primitives, `MatchState` read access, `rng_match` through the engine, `CardDatabase` (`has`, `card`, pools), `config("card_effects")` | none (LOW) |
| `EffectValidator` | The `E_FX_*` / `W_FX_*` code set and the static step bound | `validate_effects(host_kind, host_id, effects[]) → report[]` | `CardDatabase.has(id)`, `card(id).type`; `config("card_effects")` caps | none (LOW) |
| `HookRegistry` / `HookEntry` | Per hook point an ordered `HookEntry[]`; nothing else | `install(installer) → bool`, `entries(hook_point, side)`, `fold(hook_point, side, value, ctx)`, `run_triggers(hook_point, side, ctx)`, `copy()` | `HookInstaller`s from `MatchConfig` | none (LOW) |
| `BossAI` + `Planner` | Resolved profile, `aoe_seen`, the per-turn plan, mode (NORMAL/LETHAL/DEFENSIVE) | `forecast(engine) → Intent`, `play_turn(engine)`, `choose(engine, request) → int`; `ai_profile` validator and `ai_profiles.json` config validator | `legal_commands()`, `clone()`, `submit()`, `ai_stream` and its forks, `log` for `ai_*` events, `settings.telegraph_mode`, `config("ai_profiles")` | none in the planner (LOW); `PlannerTask` wraps the threading mechanism (**NOT SOURCEABLE**, ADR-0006) |

### Feature layer

| Module | Owns | Exposes | Consumes | Engine APIs |
|---|---|---|---|---|
| `RunMachine` + `RunState` | The in-memory `RunState` (R1), `status`/`reward_step`, the transition table T1–T21, the run-scope `EventLog`, the `RngService` for the run, `play_seconds` | The seven commands; `read_model() → Dictionary`; `MatchDriver` factory at `begin_match`; `match_ended` handling (R4) | `CardDatabase` (`bosses_in_band`, `hero`, `boss`, `data_version`), `RngService`, `RewardDraft`, `Treasures`, `MetaProgression` (M1.3 subset), `config("run_structure")`, `Time.get_ticks_msec` for `play_seconds` (LOW) | none in rules (LOW) |
| `MatchDriver` | The live `RulesEngine`, `EffectResolver`, `BossAI` and `PlannerTask` of one match; the phase-transition schedule (forecast on `PlayerTurn.Main`, `play_turn` on `BossTurn.Main`, `choose` on boss `Choice`) | `submit(cmd)` pass-through for PLAYER commands, `legal_commands()`, `query()`, `tick()` (polls the planner task once per frame), `match_ended` signal → `RunMachine` | `MatchConfig`; `BossAI`; `RulesEngine` | none in the driver itself; `PlannerTask` isolates the engine threading API |
| `RewardDraft` | Nothing persistent (the run record is the memory); the D4–D9 weighting formulas | `init_run(run_state) → draft_state`, `offer(kind, run_state, stream) → Offer`, `pick(kind, id, offer, run_state) → Pick`; per-option `n_tag` / `affine` read model | `CardDatabase` pools, `Treasures.pool()`, `MetaProgression.unlocked_keys()` (at `init_run` only), `draft_<floor>` stream, run log, `config("reward_draft")` | none (LOW) |
| `Treasures` | The `HookInstaller` shape, the T7 validator, the `treasure_state` schema | `installers_for(ids) → HookInstaller[]`, `collect_state(hooks, result) → Dictionary`, `pool(unlocked_keys, exclude_ids) → TreasureDef[]`, `validate_treasure_defs` | `CardDatabase.treasure_pool()`, `has`, `config("treasures_balance")` | none (LOW) |
| `Heroes` | Nothing — data access | `hero(id)`, `launch_heroes()`, `plan_tags(hero_id)` | `CardDatabase` | none |
| `MetaProgression` facade + `MetaStub` | Unlock evaluation (F1), stats fold (F2), notifications queue; the stub holds the same API in memory with defaults | The M1.3 API as the single interface both the real facade and the stub implement (`@abstract` base `MetaApi`, 4.5 — sourced) | `ProfileStore`, `CardDatabase` (`unlock` fields, `has`, `boss`), `config("profile_defaults")` | none (LOW) |

### Presentation layer

| Module | Owns | Exposes | Consumes | Engine APIs |
|---|---|---|---|---|
| `MatchView` + presenters + `InputRouter` | Scene tree, presenter nodes, the subscription, `--fixture` handling in debug builds | `match_view_finished(result)` signal; `set_controller(MatchController)` | `MatchController`, `MatchViewState`, `AnimationQueue`, `SettingsBus`, theme | `Control` tree, `Tween` (+ `tween_await` 4.7, sourced), `Control.offset_transform_*` for hover lifts in containers (4.7, sourced), dual-focus rules (4.6, sourced), `InputEvent.DEVICE_ID_*` (4.7, sourced), `OS.get_cmdline_user_args()` |
| `MatchController` + `MatchQuery` | The `MatchDriver` handle; nothing else | `submit`, `legal_commands`, `query()`; `MatchQuery` returns value copies (U2 table) | `MatchDriver` | none |
| `MatchViewState` + `AnimationQueue` | Projection of every event seen; the `AnimStep` FIFO, groups, speed divisor, skip | `apply(event)`, `snapshot()`; `enqueue(step)`, `skip_all()`, `is_idle` | events; `config("match_ui")` durations; `anim_speed`, `reduce_motion`, `action_delay_ms` | process ticks for timing (U4.8 — never `await` chains in rules code) |
| `RunShell` + `RunController` + screens | Screen stack, `ShellState`, toast queue, transition timer, debug fixture loading | `intent(name, args)` from screens; `match_view_finished` consumer | `RunMachine`, `RewardDraft` read model, `MetaApi`, `CardDatabase` display fields, run-scope events, `SettingsBus` | `Control`, focus neighbours (4.6 dual focus), `DisplayServer.clipboard_set` for Copy seed (LOW), `tr()` |

### Dependency diagram

```
                 ┌──────────────┐        ┌──────────────┐
                 │   MatchView  │        │   RunShell   │   PRESENTATION
                 │ (presenters) │        │  (screens)   │
                 └──────┬───────┘        └──────┬───────┘
          events ▲      │ commands        events ▲      │ intents→commands
                 │      ▼                        │      ▼
            ┌────┴──────────────┐          ┌─────┴──────────────┐
            │  MatchController  │◄─────────┤   RunController    │  (hand-off: MatchConfig + driver in,
            │   + MatchQuery    │ wraps    └─────┬──────────────┘   match_view_finished back)
            └────────┬──────────┘                │
                     │                           ▼
            ┌────────▼──────────┐      ┌─────────────────────┐    ┌──────────────┐
            │    MatchDriver    │◄─────┤      RunMachine     ├───►│ RewardDraft  │  FEATURE
            │ (engine+resolver  │builds│  RunState/RunRecord │    └──────┬───────┘
            │  +BossAI+task)    │      └───┬──────────┬──────┘           │ pool()
            └───┬─────────┬─────┘          │          │                  ▼
                │         │                │          │           ┌──────────────┐
                ▼         ▼                │          │           │  Treasures   │
        ┌───────────┐ ┌────────┐           │          │           │ installers   │
        │RulesEngine│ │ BossAI │  CORE     │          │           └──────┬───────┘
        │ MatchState│ │Planner │           │          │                  │ HookInstaller[]
        │HookRegistry◄┼────────┘           │          │                  │ (via MatchConfig)
        └─────┬─────┘ clone()/submit()     │          │                  │
              │ primitives ▲ resolve()     │          ▼                  │
        ┌─────▼────────────┴┐              │   ┌─────────────┐           │
        │  EffectResolver   │              │   │MetaProgress.│           │
        │  EffectValidator  │              │   │ facade/stub │           │
        └─────┬─────────────┘              │   └──────┬──────┘           │
              │                            │          │                  │
   ═══════════╪════════════════════════════╪══════════╪══════════════════╪═══════ FOUNDATION
              ▼                            ▼          ▼                  ▼
   ┌──────────────────┐  ┌──────────────────────┐  ┌──────────────┐  ┌──────────┐
   │   CardDatabase   │  │ RngService / EventLog│  │ ProfileStore │  │SettingsBus│
   │  (only JSON I/O) │  │ (streams, append-only)│  │ (user://)    │  │          │
   └──────────────────┘  └──────────────────────┘  └──────────────┘  └──────────┘
                                   ▲ composed and injected once by Boot (autoload)
```

Validators flow **upward** at composition time only (Card Effects, Boss AI, Treasures, Meta each hand `CardDatabase.load()` a validator Callable); at runtime every arrow points down.

---

## Dependency injection and the composition root

**Decision: exactly one autoload, `Boot` (`src/core/boot.gd`), and it is a composition root, not a service locator for rules.**

What `Boot` does and does not do:

| `Boot` does | `Boot` never does |
|---|---|
| On `boot()` (called by `main.tscn`, or by a debug loader): construct `CardDatabase` and call `load()` with the validators collected from `EffectValidator`, `BossAI`, `Treasures`, `MetaProgression` and each config owner; construct `ProfileStore` and `load_profile()`; construct `SettingsBus`; hand back a `Services` bag | Hold a `MatchState`, `RunState`, deck, gold, "current floor" or any other game state (TD-001, TD-009) |
| Expose `services()` to **scene roots only** (`MatchView._ready`, `RunShell._ready`, `main.tscn`) and to debug loaders, which may replace entries with fixtures/stubs | Be referenced from `src/gameplay/**`, `src/ai/**` or `src/core/**` other than itself — rules classes receive everything through constructor arguments (DD-T02, `gameplay-code.md` "no static singletons") |
| Stay idle in `_ready()` so a headless gdUnit4 run that happens to instantiate autoloads pays nothing (lazy `boot()`) | Run `load()` in `_ready()` or own process ticks for rules; `MatchDriver.tick()` is driven by `MatchView._process` |
| Be the one entry in `project.godot [autoload]` | Have siblings — a second autoload is an architecture change |

Why an autoload at all, against DD-T02 / TD-001 / TD-009: DD-T02 constrains the *rules* ("`RefCounted`, no Node references"), not the edge that hands the rules their dependencies; TD-001's defect was a singleton that **owned rules and mutable state**, TD-009's was **untyped global run state** — both are ruled out by the table above and by the grep gate below, not by the absence of an autoload. The alternative — no autoload, `main.tscn` as the only root — was rejected because match-ui U11 and run-ui U10 launch `match_view.tscn` / `run_shell.tscn` **directly** for screenshot fixtures; without a tree-level root each debug loader would re-implement composition and the evidence path would diverge from the shipped boot path. A service locator reachable from anywhere (the prototype's shape) was rejected for the same reasons TD-001 exists.

Enforcement (control-manifest rules, `/create-control-manifest`): (1) `Boot` and `Services` may appear only in `src/scenes/`, `src/ui/**/*_view.gd`, `src/ui/**/run_shell.gd`, `*_debug_loader.gd` and `tests/`; (2) every class under `src/gameplay/**` and `src/ai/**` takes its collaborators in `_init(...)` or an explicit `bind(...)`; (3) `tests/unit/**` constructs rules objects with `TestRngService`, `TestEventLog` and factory records directly — never through `Boot`; (4) the parse check runs per file with `.claude/scripts/godot-parse-check.gd`, so rules files must parse with no autoload present.

Interfaces that need two implementations use `@abstract` base classes (GDScript 4.5+, sourced): `MetaApi` (real facade / `MetaStub`), `Screen`, `Presenter`, `PlannerTask`. Overrides of typed methods on them return explicitly (4.7 inherited-return rule).

---

## Data Flow

### 1. Player command path (the "frame update" of a turn-based game)

```
Input (mouse/keyboard/gamepad)
  │ InputRouter: event → intent (drag release on target, Enter on focused card…)
  ▼
MatchView ──► MatchController.submit(Command)        [sync call, main thread]
                 │ (flushes AnimationQueue first — U4.7)
                 ▼
            MatchDriver.submit ──► RulesEngine.submit(cmd)
                                      │ validate in full → CommandResult{accepted, rejection, events[first,last]}
                                      │ mutate through primitives ─► EventLog.append(...) ─► subscribers
                                      │ EffectResolver.resolve(trigger, ctx) re-enters via primitives
                                      ▼
            CommandResult back to MatchView (≤ 5 ms budget)
  ▲
EventLog.subscribe callback ─► MatchViewState.apply(event) ─► AnimationQueue.enqueue(AnimStep)
                                                              │ grouped by cause_seq root; process-tick timer
                                                              ▼
                                                          Presenters.apply_final() == view-state when idle
```

Producer/consumer and kind: `submit` is a synchronous call; events are a synchronous callback (same frame, same thread); presenters read `MatchViewState` (shared read-only state); `MatchQuery` returns value copies on hover only. No thread boundary.

### 2. Boss turn path (the one thread boundary)

```
RulesEngine: PlayerTurn.End → BossTurn.Start → BossTurn.Main   (turn_started{side: boss} appended)
MatchDriver.on_phase(BossTurn.Main):
    PlannerTask.start(func(): boss_ai.play_turn(engine.clone()) → TurnPlan)   ← over a clone, per ADR-0006
MatchView._process → MatchDriver.tick()  (≤ 2 ms main-thread per frame; polls task; UI shows "boss thinking")
PlannerTask completes → tick() replays the TurnPlan's commands into the live engine on the main thread
(ai_decision before each; ai_fault{replay_divergence} on checksum mismatch); subscribers fire as normal
MatchView then paces the burst it holds (U6): intent banner → command groups with ai_action_delay gaps,
compressed to max_turn_playback_s; skip-all drains in one frame.
```

Rules for the boundary (independent of the mechanism; fixed by ADR-0006 / ADR-0008): the planner runs over `RulesEngine.clone()`; the live engine is main-thread only — `MatchDriver.tick()` replays the returned `TurnPlan` into it, so every live append and every `EventLog` subscriber runs on the main thread (UI code never runs off-thread); a `concede` that arrives while a task is live is queued and applied when the task returns (match-rules C14); the engine, the resolver and `BossAI` touch no Node and no autoload, so a clone is safe to plan on off the main thread by construction; `forecast` uses the same seam. If the probe shows worker threads unusable, the same seam time-slices `play_turn` across frames (the planner's node budgets are counts, so results are identical either way — boss-ai C1.5).

### 3. Run flow and the Run ↔ Match ↔ UI hand-off

```
RunShell(boss_intro) ─intent begin_match─► RunController ─► RunMachine.begin_match()
   RunMachine: match_attempts[f] += 1; status = in_match
               config = MatchConfig{floor, band, rng.stream("match_f"), rng.stream("ai_f"), log,
                                    player{hero_def_id, deck copy, Treasures.installers_for(treasures)},
                                    boss{boss_def_id, deck, boss_health(f), [passive installer], ai_profile}}
               driver = MatchDriver.new(config, card_database, settings)   # builds RulesEngine, EffectResolver, BossAI
               driver.match_ended.connect(_on_match_ended)                 # RunMachine processes R4 first
   RunController ◄─ (driver) ─ RunShell swaps in MatchView (Run UI hidden, not freed)
                               MatchView.set_controller(MatchController.new(driver)); subscribe(events_since(0))
   ... match ...
   RulesEngine → match_ended → RunMachine._on_match_ended (T6–T9: summary, save S2/S5, next status)
   MatchView end banner → click or 4 s → match_view_finished(result) → RunShell reads the next run-scope
   event (run_floor_entered / draft_offered / run_ended) and shows the matching screen.
```

The reverse edge Match UI → Run UI is **one signal** carrying the `MatchResult` already processed by Run Structure; Match UI knows nothing about floors or drafts (systems-index Circular Dependencies).

### 4. Save / load path

| Step | Producer → consumer | Kind | Data |
|---|---|---|---|
| S1–S4 saves | `RunMachine` → `MetaApi.save_active_run(RunRecord.to_dict())` → `ProfileStore` | sync call | `RunRecord` incl. `rng_snapshot` (`RngService.snapshot()`) and `run_log` (`EventLog.to_json()`); `in_match` never saved |
| Atomic write | `ProfileStore` → `AtomicFileWriter` | sync, main thread, ≤ 50 ms | serialise → `profile.json.tmp` → flush → rename to `.bak` / `.json`; `E_IO` leaves the old files |
| S5 archive | `RunMachine` → `archive_run(record)` → `StatsFold` + `UnlockEvaluator` → `ProfileStore` | sync | `{ok, unlocks_granted[]}`; `user://runs/<run_id>.json` |
| Resume | `RunShell(main_menu)` → `load_active_run()` → `RunRecord.validate()` → `RngService.restore(snapshot)` → `EventLog.from_json(run_log)` (new instance) | sync | errors become `abandoned/{data_version_mismatch, save_corrupt}` |
| Settings | `RunShell(settings)` → `set_setting` → `ProfileStore` (debounced 500 ms) → `SettingsBus.settings_changed` → Match UI / Boss AI | sync + signal | DD-X07 keys |
| Match logs | `EventLog` on `match_ended` → `user://logs/<run_id>/floor_<n>_attempt_<k>.json` when `keep_match_logs` | sync write | raw match log; the run log keeps `match_summary` |

Serialisation ownership: Run Structure owns the `RunRecord` schema and `validate()`; Meta owns file format, path, atomic write and migrations of `schema_version`, `RUN_RECORD_SCHEMA_VERSION` and `log_schema_version`; RNG & Event Log owns `to_json()`. Nothing is pickled: every persisted value is JSON-representable (rng-event-log rule 14).

### 5. Initialisation order

```
1. main.tscn _ready → Boot.boot()
2.   CardDatabase.load({effects: EffectValidator.validate_effects, ai_profile: BossAI.validate_profile_key,
                        unlock: MetaProgression.validate_unlock_defs, treasure: Treasures.validate_treasure_defs,
                        configs: {match_rules: …, card_effects: …, ai_profiles: …, run_structure: …,
                                  reward_draft: …, treasures_balance: …, heroes_balance: …, match_ui: …,
                                  run_ui: …, profile_defaults: …, content_budgets: …}})
        → Failed ⇒ RunShell opens data_error (CR-8); headless ⇒ print report, exit non-zero
3.   ProfileStore.load_profile() → status (OK | RECOVERED_BAK | FRESH | FRESH_AFTER_CORRUPT | E_SCHEMA_NEWER | E_LOCKED)
       MVP: MetaStub instead (systems-index gate condition) — same MetaApi
4.   SettingsBus created; ProfileStore publishes the settings record once
5. RunShell opens main_menu (Continue card from load_active_run())
6. Per run: RngService(run_seed, data_version) + run EventLog created by RunMachine.new_run / resume
7. Per match: MatchDriver builds RulesEngine → EffectResolver.bind(engine, installers) → BossAI; RulesEngine.start(config)
```

Data load is synchronous and must finish inside `data_load_budget_ms` (200) — a boot stall budget, measured by the performance test (card-database Formulas).

### 6. Data load path

`assets/data/*.json` → `DataLoader` (discover by DD-T01 name list → parse → envelope → schema → uniqueness → cross-refs → delegated validators → budget warnings → freeze + `data_version`) → `CardDatabase` snapshot. Config bodies are frozen Dictionaries read **once** by each owner at its own construction (`config("match_rules")` etc.); owners keep a reference, never re-query per frame. `tools/content/validate.gd` runs the same loader headless and exits non-zero on any error (content CN-6.3).

---

## API Boundaries

Written as GDScript signatures; names follow the GDDs and `tests/helpers/` (so the `TODO(E1/E2)` swap from `TestRngService` / `TestRngStream` / `TestEventLog` / factory Dictionaries to the production classes is a type change, not a rename). Sides are the strings `"player"` / `"boss"` (rng-event-log §D; `MatchFactory.SIDE_PLAYER`). Record shapes are typed `RefCounted` classes with `to_dict()` / `from_dict()` that produce exactly the factory field names; a plain Dictionary is accepted wherever a record is read.

### Foundation

```gdscript
# src/core/rng/rng_service.gd — rng-event-log rules 1–6, 10; F2/F3/F5
class_name RngService extends RefCounted
func _init(run_seed: int, data_version: String) -> void
func stream(name: String) -> RngStream          # memoised; name matches ^[a-z]+(_[0-9]+)?(/[a-z0-9_]+)*$
func snapshot() -> Dictionary                   # {run_seed, data_version, streams: {name: draws}}
func restore(snapshot: Dictionary) -> Error     # ERR_INVALID_DATA on data_version mismatch

class_name RngStream extends RefCounted         # one RandomNumberGenerator per stream (NOT SOURCEABLE: seed semantics verified on 4.7.2)
var name: String; var draws: int
func randi_range(lo: int, hi: int) -> int       # 1 draw; span ≤ 65,536
func randf() -> float                           # 1 draw; weight normalisation only
func shuffle(array: Array) -> void              # Fisher–Yates, n − 1 draws
func weighted_pick(weights: Array) -> int       # 1 draw; integer weights, total > 0
func fork(label: String) -> RngStream           # 1 parent draw on first call; memoised "<name>/<label>"

# src/core/log/event_log.gd — rng-event-log rules 11–18
class_name EventLog extends RefCounted
func append(type: StringName, payload: Dictionary, cause_seq: int = 0) -> int   # returns seq; -1 when sealed/dropped
func set_turn(turn: int) -> void
func subscribe(callback: Callable) -> void      # callback(event: Dictionary) once per event, in seq order, after append
func events_since(seq: int) -> Array[Dictionary]
func snapshot() -> Dictionary; func to_json() -> String; static func from_json(text: String) -> EventLog
func reduce_to_summary() -> Dictionary          # match_summary incl. damage_by_card (rule 19)
signal overflowed(cap: int, seq: int)           # the Faulted transition; the engine answers with match_ended(fault)

# src/core/data/card_database.gd — card-database CR-1..CR-9
class_name CardDatabase extends RefCounted
func load(validators: Dictionary) -> ValidationReport      # {record_kind|config_name: Callable}
func reload() -> ValidationReport                          # debug builds only; E_NOT_SUPPORTED in release
func card(id: String) -> Dictionary;  func hero(id: String) -> Dictionary;  func hero_power(id: String) -> Dictionary
func boss(id: String) -> Dictionary;  func treasure(id: String) -> Dictionary;  func bundle(id: String) -> Dictionary
func has(id: String) -> bool
func cards_by_set(s: String) -> Array; func cards_by_type(t: String) -> Array; func cards_by_tag(t: String) -> Array
func cards_by_cost(c: int) -> Array;   func cards_by_rarity(r: String) -> Array
func collectible_pool(hero_set: String) -> Array; func bundle_pool(hero_set: String) -> Array
func treasure_pool() -> Array; func bosses_in_band(band: int) -> Array; func heroes() -> Array   # all id-ascending
func config(name: String) -> Dictionary                    # frozen body of <name>.json; null + logged error if unknown
func data_version() -> String; func report() -> ValidationReport; func state() -> State

# src/core/save/profile_store.gd — meta-progression M1.3 (persistence subset); MetaApi adds the rules half
class_name ProfileStore extends RefCounted
func load_profile() -> Dictionary               # {status, profile}
func save_profile() -> Error                    # OK | E_IO | E_READONLY — atomic (M4)
func save_active_run(record: Dictionary) -> Error; func load_active_run() -> Variant; func clear_active_run() -> void
func set_setting(key: StringName, value: Variant) -> Error; func get_setting(key: StringName) -> Variant; func get_settings() -> Dictionary
func archive_run(record: Dictionary) -> Dictionary        # {ok, unlocks_granted[]} — delegates fold/unlocks to MetaProgression
func run_log(offset: int, limit: int) -> Array; func run_log_entry(run_id: String) -> Variant
func pending_notifications() -> Array; func ack_notification(key: String) -> void
func reset_profile(confirm_token: String) -> Error
var settings_bus: SettingsBus                    # settings_changed(key, value)

# src/core/boot.gd — the one autoload
class_name Boot extends Node
func boot(overrides: Dictionary = {}) -> BootResult    # idempotent; overrides let debug loaders inject fixtures/stubs
func services() -> Services                            # {card_database, profile_store, meta: MetaApi, settings_bus}
```

### Core — Match Rules (match-rules C1–C3, C14, Interactions)

```gdscript
class_name RulesEngine extends RefCounted
func _init(db: CardDatabase, rules_config: Dictionary, resolver: EffectResolver) -> void
func start(config: MatchConfig) -> void          # C3 steps 1–8; binds resolver; installs hooks before on_match_start
func submit(command: Command) -> CommandResult   # synchronous; nested submit → ENGINE_BUSY
func legal_commands() -> Array[Command]
func phase() -> Phase; func active_side() -> StringName; func pending_choice() -> Variant; func result() -> Variant
func clone() -> RulesEngine                      # deep copy: state, HookRegistry entries, continuation, scratch log, rng_match copy
func snapshot_entity(entity_id: int) -> Dictionary   # value copy for MatchQuery; never a live object
signal match_ended(result: MatchResult)          # also appended as the match_ended event

# Records (tests/helpers/match_factory.gd field names are normative)
class_name MatchConfig   # {floor, band, rng_match: RngStream, rng_ai: RngStream, log: EventLog,
                         #  player: {hero_def_id, deck: Array[String], hook_installers: Array[HookInstaller]},
                         #  boss:   {boss_def_id, deck, health, hook_installers, ai_id}}
class_name Command       # {type: mulligan|play_card|attack|use_hero_power|choose|end_turn|concede, issuer, keep_mask, hand_index, position, target_id, attacker_id, option_index}
class_name CommandResult # {accepted: bool, rejection: null | {code: StringName, detail: String}, events: [seq_first, seq_last]}
class_name MatchResult   # {result: win|loss|fault, winner: player|boss|null, reason, floor, turns, turns_per_side, stats{player, boss}, final_health{player, boss}}
class_name MatchState    # C1: turn, active_side, phase, players{player, boss}: PlayerState, pending_choice, result, next_entity_id, hooks: HookRegistry, floor, band
# PlayerState, Character, Enchantment, Weapon, CardInstance — exactly C1; derived values are functions, never fields.

# Primitive API — the only mutators; each emits one event (match-rules Interactions)
func draw(side, n); func apply_damage(target, amount, source); func apply_heal(target, amount, source); func apply_armor(side, amount)
func apply_enchantment(target, enchantment); func remove_enchantment(target, id); func summon_minion(side, def_id, position)
func destroy(target); func silence(target); func freeze(target); func add_keyword(target, kw); func remove_keyword(target, kw)
func return_to_hand(target); func transform(target, def_id); func add_mana(side, n, temporary); func equip_weapon(side, def_id)
func discover(side, options) -> ChoiceRequest; func add_card_to_hand(side, def_id); func add_card_to_deck(side, def_id, position)
func set_stats(target, attack, health); func modify_durability(weapon, delta); func refresh_hero_power(side); func discard(side, which)

# Hook table — 12 points, installation order, fold-then-clamp (match-rules Interactions; treasures T2)
class_name HookRegistry extends RefCounted
func install(installer: HookInstaller) -> bool                   # false + hook_install_skipped on duplicate host_id
func fold(point: StringName, side: StringName, value: int, ctx: Dictionary) -> int   # modify_cost/damage/heal/starting_hand_size/max_attacks
func run_triggers(point: StringName, side: StringName, ctx: Dictionary) -> void      # on_match_start/turn_start/turn_end/card_played/minion_summoned/hero_damaged/draw
func copy() -> HookRegistry                                      # entries are plain data (clone())
class_name HookEntry     # {host_kind: treasure|passive, host_id, side, effect_id, effect: Dictionary}
class_name HookInstaller # {host_kind, host_id, side, effects: Array, state: Dictionary}   (treasures T3.2)
```

Invariants callers respect: commands are validated before any mutation; `MatchState` is never exposed — `MatchQuery` and Boss AI see copies; nothing outside the engine calls a primitive except `EffectResolver`; rejection codes are the closed C2 set (`MatchFactory.REJECTION_CODES`).

### Core — Card Effects (card-effects C1, C5–C10)

```gdscript
class_name EffectResolver extends RefCounted
func _init(db: CardDatabase, effects_config: Dictionary) -> void
func bind(engine: RulesEngine, installers: Array[HookInstaller]) -> void   # C6.1 at RulesEngine.start
func resolve(trigger_point: StringName, ctx: Dictionary) -> void           # queues or runs effects; one pass = one C10 step
func legal_targets(def_id: String, source: Dictionary) -> Array[int]
func targeting_spec(def_id: String) -> Dictionary                          # {mode: none|optional|required, filter}
func recompute_auras() -> void
func resume(choice: ChoiceRequest, option_index: int) -> void              # `choose` continuation
class_name ChoiceRequest  # {side, kind: discover|choose_one, options: Array, source_id, effect_id}

class_name EffectValidator extends RefCounted
static func validate_effects(host_kind: StringName, host_id: String, effects: Array, db: CardDatabase, caps: Dictionary) -> Array   # [{code, host_id, effect_id, path, message}]
```

Boundary rule (ADR-0007): the resolver reads `MatchState` and writes **only** through primitives; the engine decides *when* a trigger point fires and *what order* candidates are considered (board order, player first); the resolver decides *who responds* and *in what order among responders*. The validator is a static, side-effect-free function injected at composition so unit tests can stub it (CR-5).

### Core — Boss AI (boss-ai C1, C9)

```gdscript
class_name BossAI extends RefCounted
func _init(boss_def: Dictionary, resolved_profile: Dictionary, band: int, ai_stream: RngStream, op_values: Dictionary, log: EventLog) -> void
func forecast(engine: RulesEngine) -> Intent          # at PlayerTurn.Main; uses ai_stream.fork("forecast_<turn>")
func play_turn(engine: RulesEngine) -> void           # returns when the engine leaves BossTurn.Main
func choose(engine: RulesEngine, request: ChoiceRequest) -> int
func set_telegraph_mode(mode: StringName) -> void     # from settings_changed; effective_mode = min(intent_mode, mode)
static func validate_profile_key(key: String, profiles: Dictionary) -> Array
static func validate_profiles_config(body: Dictionary) -> Array

@abstract class_name PlannerTask extends RefCounted   # ADR-0006 seam — one implementation after the probe
@abstract func start(work: Callable) -> void
@abstract func poll() -> bool                          # true when finished; called once per frame by MatchDriver.tick()
```

### Feature

```gdscript
class_name RunMachine extends RefCounted               # run-structure R1–R10, T1–T21
func _init(db: CardDatabase, meta: MetaApi, draft: RewardDraft, treasures: Treasures, run_config: Dictionary, driver_factory: Callable) -> void
func new_run(hero_id: String, seed_input: String) -> Error         # E_HERO_LOCKED, E_BAD_PHASE
func begin_match() -> MatchDriver                                   # builds MatchConfig (R3)
func draft_pick(kind: StringName, id: Variant) -> Error             # E_NOT_OFFERED | E_DRAFT_DONE | E_DRAFT_KIND | E_UNKNOWN_ID
func abandon() -> Error; func resume() -> Error; func suspend() -> Error; func return_to_menu() -> Error
func read_model() -> Dictionary                                     # floor, band, boss_sequence[0..floor−1], deck, treasures, run_seed_hex, attempt, summary data
func current_offer() -> Variant                                     # the pending Offer read model (option_ids, flags, n_tag/affine)
var run_log: EventLog; var rng: RngService; var state: RunState
class_name RunState / RunRecord  # R1 fields exactly (tests/helpers/run_factory.gd); RunRecord.validate(dict) -> OK | E_SCHEMA | E_DATA_VERSION | E_CORRUPT | E_UNKNOWN_ID

class_name MatchDriver extends RefCounted              # owned by Run Structure (ADR-0008)
func _init(config: MatchConfig, db: CardDatabase, settings: Dictionary, planner_task: PlannerTask) -> void
func submit(command: Command) -> CommandResult        # PLAYER commands; rejects while the planner task is live (except concede, queued)
func legal_commands() -> Array[Command]; func query() -> MatchQuery
func tick() -> void                                   # called from MatchView._process; ≤ 2 ms; polls PlannerTask; replays the TurnPlan into the live engine (ADR-0006/0008)
func subscribe(callback: Callable) -> void; func events_since(seq: int) -> Array
signal match_ended(result: MatchResult)

class_name RewardDraft extends RefCounted              # reward-draft D1
func _init(db: CardDatabase, treasures: Treasures, meta: MetaApi, draft_config: Dictionary) -> void
func init_run(run_state: RunState) -> Dictionary                              # draft_state {schema_version: 1, treasure_pool[]}; 0 draws
func offer(kind: StringName, run_state: RunState, stream: RngStream) -> Offer  # pure in (run_state, stream position); emits draft_offered
func pick(kind: StringName, id: String, offer: Offer, run_state: RunState) -> Pick   # emits draft_picked; mutates nothing
class_name Offer  # {option_ids: Array[String], flags: Array[StringName], per_option: [{n_tag, affine}]}
class_name Pick   # {picked_id, option_index, card_ids_added[]}

class_name Treasures extends RefCounted                # treasures T3–T7
func _init(db: CardDatabase, balance_config: Dictionary) -> void
func installers_for(treasure_ids: Array, treasure_state: Dictionary) -> Array[HookInstaller]   # pure, idempotent, pick order
func collect_state(hooks: HookRegistry, result: MatchResult) -> Dictionary                     # {schema_version: 1, by_treasure: {}}
func pool(unlocked_keys: Dictionary, exclude_ids: Array) -> Array                              # id-ascending TreasureDef[]
static func validate_treasure_defs(defs: Array, db: CardDatabase) -> Array                     # E_TR_*

@abstract class_name MetaApi extends RefCounted        # meta-progression M1.3 — real facade and MetaStub
@abstract func is_hero_unlocked(hero_id: String) -> bool
@abstract func unlocked_keys() -> Dictionary           # Set semantics: {key: true}
@abstract func is_treasure_unlocked(id: String) -> bool
@abstract func save_active_run(record: Dictionary) -> Error
@abstract func load_active_run() -> Variant
@abstract func clear_active_run() -> void
@abstract func archive_run(record: Dictionary) -> Dictionary
@abstract func stats_for_hero(hero_id: String) -> Dictionary;  @abstract func last_hero_id() -> Variant
@abstract func unlock_progress(key: String) -> Dictionary;     @abstract func unlock_hint(key_or_id: String) -> Dictionary
@abstract func get_settings() -> Dictionary;  @abstract func set_setting(key: StringName, value: Variant) -> Error
@abstract func run_log(offset: int, limit: int) -> Array;  @abstract func run_log_entry(run_id: String) -> Variant
@abstract func pending_notifications() -> Array;  @abstract func ack_notification(key: String) -> void
@abstract func reset_profile(confirm_token: String) -> Error
@abstract func load_status() -> StringName             # OK | RECOVERED_BAK | FRESH | FRESH_AFTER_CORRUPT | E_SCHEMA_NEWER | E_LOCKED
signal unlock_granted(key: String, kind: StringName, id: String, by_run_id: String, retro: bool)
var settings_bus: SettingsBus
static func validate_unlock_defs(defs: Array, db: CardDatabase) -> Array
```

`MetaStub` (MVP, systems-index gate condition): all heroes unlocked, `unlocked_keys()` = every key in data, saves held in memory (optionally mirrored to `user://` by the real `ProfileStore` once ADR-0004 lands), session-local settings from `config("profile_defaults")`, empty run log, no notifications. Run UI's "Continue" is absent while the stub is injected (run-ui Dependencies). The seam is the `MetaApi` constructor argument of `RunMachine`, `RewardDraft`, `RunController`; `Boot.boot({meta: MetaStub.new(...)})` selects it.

### Presentation

```gdscript
# Match UI (match-ui U1, U2)
class_name MatchController extends RefCounted
func _init(driver: MatchDriver) -> void
func submit(command: Command) -> CommandResult; func legal_commands() -> Array[Command]; func query() -> MatchQuery
func subscribe(cb: Callable) -> void; func events_since(seq: int) -> Array; func tick() -> void
class_name MatchQuery extends RefCounted               # all ≤ 2 ms, value copies only
func phase() -> Dictionary; func pending_choice() -> Variant; func entity(instance_id: int) -> Dictionary
func hand(side: StringName) -> Array; func card_text(card_id: String) -> Dictionary; func legal_commands() -> Array
func hero_power_state(side: StringName) -> Dictionary

class_name MatchView extends Control                   # src/ui/match/match_view.tscn root
func set_controller(controller: MatchController) -> void
signal match_view_finished(result: MatchResult)        # after the end banner (click or MATCH_END_AUTO_S)
# MatchViewState.apply(event), AnimationQueue.enqueue(AnimStep{kind, entity_ids, base_duration_s, apply_final: Callable, group_id, parallel_ok}),
# AnimationQueue.skip_all(), InputRouter.intent(...) — U3–U5; MatchDebugLoader reads OS.get_cmdline_user_args() in debug builds only (U11)

# Run UI (run-ui U1, U2)
class_name RunShell extends Control                    # src/ui/run/run_shell.tscn root; screen stack + ShellState + ToastLayer
class_name RunController extends RefCounted
func _init(run: RunMachine, draft: RewardDraft, meta: MetaApi, db: CardDatabase, ui_config: Dictionary) -> void
func intent(name: StringName, args: Dictionary) -> void   # validates ShellState, maps to a command (U2) or emits ui_intent_rejected
func read_model() -> Dictionary
signal screen_requested(id: StringName, read_model: Dictionary); signal match_requested(driver: MatchDriver); signal toast(kind, payload)
@abstract class_name Screen extends Control
@abstract func bind(read_model: Dictionary) -> void     # display-only; sends intents through the controller
```

**Engine type check:** `Control`, `Node`, `Tween`, `Signal`, `Callable`, `StringName`, `RefCounted` all exist unchanged in 4.7; `Control.accessibility_live` and `RichTextLabel.add_image` changed in 4.7 (sourced) and are the two UI APIs whose 4.7 signatures the presenters must follow if used (`FeedPresenter` uses `RichTextLabel` for the feed; it must not call `add_image` with `*_in_percent`).

---

## Threading model (placeholder — resolved by ADR-0006)

| Thread | Runs | Rule |
|---|---|---|
| Main | Everything except the Boss AI planner: input, `submit` for player commands, `EventLog` subscribers, `AnimationQueue`, presenters, `ProfileStore` writes (synchronous, ≤ 50 ms), data load at boot | `ui-code.md`: UI never blocks the game thread; `ai-code.md`: AI ≤ 2 ms per frame |
| Planner (`PlannerTask`) | The Boss AI planner over `RulesEngine.clone()`; the live engine is main-thread only; `forecast` uses the same seam (ADR-0006) | No Node, no autoload, no signal emission and no live-log append from the worker; `MatchDriver.tick()` replays the returned plan into the live engine on the main thread; the task exposes only `start` / `poll` / `result` |

Candidates for the mechanism: `WorkerThreadPool.add_task` + `is_task_completed` polling; a dedicated `Thread`; or main-thread time-slicing (`play_turn` split at command boundaries, resumed per frame). **NOT SOURCEABLE** — no threading page in the engine reference. Decided by the headless probe `docs/architecture/spikes/2026-11-03-engine-probes.md` (to be written with ADR-0006): run a band-3 worst-case `play_turn` (F7 ≈ 60 ms) on a `WorkerThreadPool` task from a `-s` script, assert the main loop keeps ticking, no GDScript thread-safety error is printed, and the resulting event log is byte-identical to the same turn run on the main thread (boss-ai A30). Until the probe passes, `PlannerTask` has one implementation: main-thread time-slicing, which is correct by construction and only risks a frame hitch.

---

## Persistence paths (`user://`)

| Path | Owner | Written when | Read when |
|---|---|---|---|
| `user://profile.json` | ProfileStore | every mutator (M4.2), atomic | `load_profile()` at boot |
| `user://profile.bak` | ProfileStore | the previous good version, on every write | fallback at load (M5.1) |
| `user://profile.json.tmp` | ProfileStore | write staging | never read; deleted on `E_IO` |
| `user://profile.lock` | ProfileLock | `{instance_id, pid, heartbeat_at}` at load, heartbeat every 30 s | second-instance detection (M6) |
| `user://profile.corrupt-<unix_ts>.json` | ProfileStore | a file that parsed but failed validation | never (bug reports) |
| `user://runs/<run_id>.json` | ProfileStore (M8) | `archive_run` | Run Log detail / `/balance-check` |
| `user://logs/<run_id>/floor_<n>_attempt_<k>.json` | EventLog (rule 18) | `match_ended` when `keep_match_logs` | replay viewer, `/balance-check` |
| `production/qa/sim/<boss_id>_<date>.json` (repo, not `user://`) | sim harness | harness run | Content tuning |

Only `src/core/save/` and `src/core/log/` open files under `user://`; only `src/core/data/` opens `res://assets/data/`. `assets/data/profile_defaults.json` is content data (defaults), distinct from `user://profile.json` (card-database CR-1).

---

## Screenshot capture and the fixtures seam

Evidence for Visual/Feel and UI stories is a retained PNG under `production/qa/evidence/<story-slug>/` captured per `.claude/docs/run-and-observe.md` with `godot --path . --windowed --resolution 1280x720 --write-movie <path>.png --quit-after <N> <scene>.tscn -- <args>`; frames record at the project viewport (1280x720 — `project.godot`), and on Linux CI the launch runs under `xvfb-run` (`--headless` is never a substitute). Whether Forward+ initialises under Xvfb on the runner is **NOT SOURCEABLE** (game-concept Technical Risks) and is ADR-0010's probe: if it does not, the capture launch passes `--rendering-method gl_compatibility` (Compatibility = OpenGL 3.3 per `modules/rendering.md`) while the shipped build keeps Forward+; the ADR decides which, and records that any pixel-level difference between renderers is accepted for layout evidence.

The seam that makes every screen reachable unattended:

| Entry | Reads | Loads | Guarantees |
|---|---|---|---|
| `MatchDebugLoader` (match-ui U11; `src/ui/match/match_debug_loader.gd`) | `--fixture=<name>`, `--pose`, `--pause-at`, `--anim-speed`, `--ai-debug` from `OS.get_cmdline_user_args()` | `tests/fixtures/match_ui/<name>.json` = a `MatchConfig` (hero, boss, seed) + scripted command list; calls `Boot.boot()`, builds a real `MatchDriver`, runs the commands headlessly, then `MatchView` projects `events_since(0)` with animations instant | a screenshot can never show a state the rules cannot reach; the loader is excluded from release exports (feature tag `debug` / `OS.is_debug_build()`) |
| `RunDebugLoader` (run-ui U10; `src/ui/run/run_debug_loader.gd`) | `--run-ui-screen=<id> --run-ui-fixture=<name>` | `tests/fixtures/run_ui/<name>.json` = profile + optional `RunRecord` + optional offer into a `MetaStub`, via `Boot.boot({meta: stub})`; opens the screen with no transition | the same `MetaApi` seam the MVP ships with — no second code path |

The twenty match fixtures and nine run fixtures the GDDs require are stories' deliverables; `/qa-plan` lists them. Fixtures are also the integration tests' inputs (`tests/integration/match_ui/`, `tests/integration/run_ui/`), so the evidence launch and the test suite share one file format.

---

## Performance budgets

| Budget | Value | Source | Verified by |
|---|---|---|---|
| Target framerate / frame budget | 60 fps / 16.6 ms | `technical-preferences.md` (setup-engine default) | `/perf-profile` once a scene exists |
| `RulesEngine.submit()` (engine only) | ≤ 5 ms worst case (50-step Deathrattle chain) | match-rules Input Responsiveness | unit perf test over a scripted chain |
| `RulesEngine.legal_commands()` | ≤ 2 ms (called per hover and per AI node) | match-rules Input Responsiveness | unit perf test on a 7 v 7 board, 10-card hand |
| `MatchQuery.*` | ≤ 2 ms each | match-ui U2 | unit perf test |
| Boss AI main-thread time | ≤ 2 ms per frame | `.claude/rules/ai-code.md`; boss-ai C1.5 | boss-ai A30 (frame timing under the planner task) |
| Boss AI planner per turn | 50 ms p95 target (`planner_target_ms`); budgets are counts: `lethal_max_nodes` 50/500/4000, `max_evals_per_action` 40/120/250, `max_actions_per_turn` 30 | boss-ai C9, F7 | sim harness p50/p95 (A22) |
| Hook chain | 12-entry fold < 0.05 ms; 3 treasures add < 2 ms per match; no allocation in the fold | treasures F5 | unit perf test |
| UI input latency | pickup 16 ms · drag 16 ms · release → first visual event 50 ms · rejection → shake 50 ms · skip-all → display = view-state 100 ms · End Turn → intent beat 300 ms · hover → preview 100 ms | match-ui Input Responsiveness | integration test with `scene_runner()` timing + evidence |
| Boss turn playback | gaps from `action_delay_ms` (600 default), compressed to `max_turn_playback_s`; intent banner `intent_banner_s` | match-ui U6, F4 | fixture `boss_turn_playback` |
| Run UI restart | ≤ `restart_budget_ms` 5000 (path A 1350 ms at defaults); `new_run` ≤ 200 ms, `intro_ready` ≤ 300 ms, `select_ready` ≤ 300 ms; transitions `transition_ms.fade` 250 | run-ui F1, F2 | measured per build |
| Data load | `Unloaded → Ready` ≤ `data_load_budget_ms` 200; snapshot ≤ `data_memory_budget_mb` 4; ~900 O(1) checks at v1 | card-database Formulas | performance test asserts the measured load time |
| Event log memory | `log_memory_budget_bytes` 2,000,000 → `max_match_events` 10,000; typical match 300–2,000 events (60–400 KB) | rng-event-log F7 | unit test on the overflow path; `avg_event_bytes` re-measured on real logs |
| Profile save | synchronous ≤ `max_save_ms` 50 at `run_log_cap` 200; file ≤ `max_profile_bytes` 2 MB (≈ 1.7 MB estimated) | meta-progression M4.3, F5 | measured at Vertical Slice |
| Draw calls | **NOT SOURCEABLE / TBD** — no sourced figure for a Godot 4.7 2D project; `technical-preferences.md` says "set once target hardware is known" | — | set after the first Match UI story is profiled; record here |
| Memory ceiling | **NOT SOURCEABLE / TBD** — `technical-preferences.md` placeholder | — | as above |
| Minimum spec | **TBD** — "mid-range desktop, SSD" is the only phrase in any GDD (card-database Formulas) | — | producer decision before Pre-Production gate |

---

## Tech-debt retirement mapping

Every TD item's root cause is ruled out by a rule in this document or by an ADR; stories cite the TD-ID they retire (`docs/tech-debt-register.md`).

| TD | Root cause in the prototype | Architectural rule that rules it out | ADR |
|---|---|---|---|
| TD-001 | `GameManager` autoload god object owning rules, mana, combat, run state | Rules are `RefCounted` under `src/gameplay/` with constructor injection; `Boot` owns no game state and is referenced only by scene roots; one autoload entry, grep-gated | ADR-0001 |
| TD-002 | Calls to rules functions that do not exist (half-finished rename) | The rules API is defined first (this document's API Boundaries, match-rules C2/Interactions) and typed; `legal_commands()` / `submit()` / primitives are the complete surface; `.claude/scripts/godot-parse-check.gd` runs per file in CI | ADR-0001, ADR-0007 |
| TD-003 | Board never registered; minions exist only as scene children | `MatchState.players[side].board` is the only board; presenters are projections of events, never a source of truth (U4.6 idle invariant) | ADR-0001, ADR-0009 |
| TD-004 | No effect implemented; `CardEffectBase` never subclassed | Effects are JSON data resolved by `EffectResolver` through engine primitives; the validator rejects anything unexpressible at load; no code-per-card | ADR-0002, ADR-0007 |
| TD-005 | `Minion` is a `Control` owning stats and freeing itself; death resolves twice | Characters are data in `MatchState`; death resolves once in the C10 loop; nothing under `src/gameplay/` extends `Node`; `queue_free` appears only in `src/ui/` | ADR-0001 |
| TD-006 | UI mutates game state; AI reparents nodes; cards owned by player 0 | All input, human and AI, goes through `submit()`; `MatchQuery` returns copies; `HookEntry.side` and `Command.issuer` carry ownership | ADR-0001, ADR-0008, ADR-0009 |
| TD-007 | Unseeded global RNG everywhere | `RngService` with named streams injected via `MatchConfig` / `offer()`; rule 7 grep gate on `randi`, `randf`, `randomize`, `shuffle`, `pick_random` under `src/gameplay/`, `src/ai/` | ADR-0003 |
| TD-008 | Card data without schema; decks referencing undefined ids | CR-5 nine-stage load with cross-reference checks; `Failed` has no main menu; `tools/content/validate.gd` in CI | ADR-0002 |
| TD-009 | Run state in `set_meta` strings; modifier back-reference to a singleton; modifiers unscoped | Typed `RunState` owned by `RunMachine`; `HookRegistry` per match on `MatchState.hooks`, entries plain data with `side`, no back-reference, installation order only | ADR-0005, ADR-0008 |
| TD-010 | Dead scenes and scripts, duplicate combat resolvers | Nothing is ported; one resolver (`EffectResolver`), one combat path (C8); `/asset-audit` and the parse check catch orphans | ADR-0001 |
| TD-011 | Wrong mulligan counts hardcoded | `STARTING_HAND_PLAYER` 3 / boss 4 / `MULLIGAN_ROUNDS` 1 come from `config("match_rules")`; `mulligan(keep_mask)` replaces any subset (C3.7) | ADR-0002 |
| TD-012 | No tests | gdUnit4 scaffolded (`tests/README.md`); every Logic story ships a unit test; helpers already model the contracts; headless rules make this possible | ADR-0001, ADR-0003 |

---

## ADR Audit

No numbered ADR exists (`docs/architecture/adr-*.md`: none). The one prior-art document:

| Document | Engine Compat | Version | GDD Linkage | Conflicts with this architecture | Valid |
|---|---|---|---|---|---|
| `modifier-hook-chain.md` (reverse-documented, unnumbered per DD-X08) | section present (autoload, `duplicate(true)`, `sort_custom`) | 4.7.2 noted; prototype on 4.5 | none ("GDD Requirements Addressed: none yet") | Global singleton, `Node`-typed hooks, `priority` ordering with undefined ties, back-reference — all contradicted by treasures T2 and this document | ⚠️ prior art only; superseded by ADR-0005 |

Traceability coverage: 0 of 71 provisional requirements are covered by an Accepted ADR; every requirement maps to one of the eleven ADRs below (the "Serves" column), so the gap count equals the baseline and the Required ADR list is complete.

---

## Required ADRs

Numbered per DD-X08 (0001–0004 fixed; 0005+ in gate-check order). `Layer` is the ADR's own layer (ADR template rule): Foundation-layer ADRs are **critical** at `standard` — `/create-stories` stops without them. Each entry: context, the GDD sections it serves, the TD items it retires, and whether an engine probe must pass before it can be Accepted.

### Must have before coding starts (Foundation and Core)

**ADR-0001 — Rules / presentation split** · Layer: Foundation · Domain: Core · probe: no
Context: every prototype defect in TD-001/003/005/006 came from rules living in Nodes and a singleton. This ADR makes DD-T02 binding: `src/gameplay/` and `src/ai/` are `RefCounted`, constructor-injected, headless; `src/ui/` is display-only over events and commands; `Boot` is the one autoload and a composition root only, with the grep gates above. It fixes the directory layout, the layer map, the command/event/query channels and the per-layer rule files. Serves: match-rules C1, C2, Interactions; match-ui U1, U2; run-ui U1; systems-index Circular Dependencies; DD-T02. Retires: TD-001, TD-003, TD-005, TD-006, TD-010, TD-012 (enabler). Depends on: none. Enables: every other ADR.

**ADR-0002 — Data format, effect schema/DSL and `config()` loading** · Layer: Foundation · Domain: Core · probe: no
Context: DD-T01 fixes JSON under `assets/data/` with `schema_version`; card-database CR-1..CR-9 define the loader, envelopes, id namespace, nine-stage pipeline with injected validators, id-ascending queries, `data_version` and the config class; card-effects C1–C5 define the effect object that every card, hero power, treasure and boss passive is written in. The ADR decides: file discovery by name list, `schema_version_current` as the one code literal, the validator injection map, the JSON Schema location per file (`data-files.md`), `FileAccess` + `JSON.parse_string` (LOW) and `HashingContext` SHA-256 for CR-9, and the headless validate command exit contract. Serves: card-database CR-1..CR-9, Formulas; card-effects C1, C5, C10; content CN-6; heroes H-1; DD-T01. Retires: TD-004 (schema half), TD-008, TD-011. Depends on: ADR-0001.

**ADR-0003 — Seeded RNG service and event log** · Layer: Foundation · Domain: Core · probe: **yes, light** (verify `RandomNumberGenerator.seed` determinism and int64 wraparound on 4.7.2 — the `tests/helpers/test_rng_stream.gd` self-test already does this; the ADR records its result)
Context: Pillar 4 and DD-T03/T04 need one seeded service with named memoised streams, `fork`, `snapshot`/`restore`, and an append-only log with `cause_seq`, diagnostic events on the same channel, sealing, overflow fault and `to_json`. The ADR fixes F1–F7 (FNV-1a 64 + SplitMix64 as in the helper), the draw API, the subscriber contract (synchronous, main thread, lambdas capture by value), the 2 MB log budget and the `user://logs/` archive. Serves: rng-event-log rules 1–19, F1–F7; match-rules C15; DD-T03, DD-T04, DD-R09. Retires: TD-007, TD-012 (determinism half). Depends on: ADR-0001.

**ADR-0004 — Save format and atomic profile write** · Layer: Foundation · Domain: Core · probe: **yes** (atomic rename: `DirAccess.rename_absolute` over an existing file on Windows and Linux — NOT SOURCEABLE; the probe writes, renames, kills mid-sequence and asserts `profile.json` or `.bak` is always a complete file)
Context: meta-progression M1 (one file, M1.2 shape, M1.3 API), M4 (tmp → bak → rename, `FileAccess.store_* → bool` sourced 4.4, migrations as pure functions), M5 (load order, corrupt copies, newer-schema `ReadOnly`, tamper tolerance), M6 (lock file) and run-structure R7/R8 (save points, `in_match` never saved, resume semantics). The ADR also fixes the `MetaApi` abstract base and the `MetaStub` the MVP ships. Serves: meta-progression M1, M4–M6, M8, M9, F5; run-structure R1, R7, R8; DD-R08; systems-index Run ↔ Meta resolution. Retires: TD-009 (run-state half). Depends on: ADR-0001, ADR-0003 (snapshot shape).

**ADR-0005 — Owner-scoped hook registry** (supersedes `modifier-hook-chain.md`) · Layer: Core · Domain: Core · probe: no
Context: treasures T2–T4 replace the prototype's global, priority-ordered, Node-typed modifier manager with a per-match `HookRegistry` on `MatchState.hooks`: twelve hook points from match-rules' table, `HookEntry` plain data with `side`, installation order only (pick order, effects in array order, passive last), trigger hooks as synchronous steps, value hooks as folds clamped once by the engine, duplicate installers skipped with an event, entries copied by value in `clone()`. Serves: treasures T2, T3, T4, T5, F2, F5; match-rules Interactions hook table; card-effects C9; boss-ai provisional A20. Retires: TD-009 (modifier half). Depends on: ADR-0001, ADR-0007 (hook effects are DSL effects). Supersedes: `docs/architecture/modifier-hook-chain.md` (stays unnumbered).

**ADR-0006 — Boss AI planner threading / time-slicing** · Layer: Core · Domain: Core · probe: **yes** (`WorkerThreadPool` / `Thread` from GDScript on 4.7.2 headless: main loop keeps ticking during a 60 ms `play_turn`, no thread-safety errors, byte-identical log vs main-thread run — boss-ai A30)
Context: `ai-code.md` caps AI at 2 ms per frame on the main thread while boss-ai F7's band-3 worst case is ≈ 60 ms per turn; boss-ai C1.5 requires the driver to run `play_turn` / `forecast` off the main thread or time-sliced and leaves the mechanism to this ADR. The architecture already isolates it behind `PlannerTask` with the buffering rule (no subscriber runs off-thread). Serves: boss-ai C1.5, C2, C9, F7, A22, A30; match-ui U6; `.claude/rules/ai-code.md`. Retires: none directly (TD-006's AI half is ADR-0001). Depends on: ADR-0001, ADR-0008. Default until the probe passes: main-thread time-slicing.

**ADR-0007 — Effect resolver / validator boundary** · Layer: Core · Domain: Core · probe: no
Context: card-effects C1 rule 1 (targeting derived, never stored), C5 (ops → primitives, failure semantics), C6 (one pass = one step, binding at `start`, the queue, `recompute_auras`), C8 (one `ChoiceRequest` per Discover with a continuation), C9 (hook binding order) and C10 (`validate_effects` injected into CR-5 stage 7, closed error set, stub in tests). The ADR fixes who owns what between `RulesEngine` and `EffectResolver`, the `EffectRuntime` fields that travel inside `MatchState` (counters, once-marks, continuation), and that the validator is a static pure function. Serves: card-effects C1, C5–C10, F6; match-rules C6, C10, Dependencies; heroes H-3; treasures T7. Retires: TD-002 (typed API first), TD-004 (resolution half). Depends on: ADR-0001, ADR-0002.

**ADR-0008 — Match driver ownership and the Run ↔ Match ↔ UI hand-off** · Layer: Core · Domain: Core · probe: no
Context: run-structure Interactions (Boss AI row, cross-review C-17) places the match driver — the object that builds `RulesEngine`, `EffectResolver` and `BossAI` from `MatchConfig` and calls `forecast` / `play_turn` / `choose` at the phase transitions — in rules-side code owned by Run Structure, wrapped but not owned by Match UI's `MatchController`; match-ui Interactions and run-ui U2 define the one-way scene hand-off (`MatchConfig` + driver in, `match_view_finished(result)` back after Run Structure has processed `match_ended`). The ADR fixes `MatchDriver`'s API, its `tick()` contract, the concede-while-planning rule, and the hand-off sequence in Data Flow §3. Serves: run-structure R3, R4, T5–T9, Interactions; match-ui U1, U2, U6, Interactions "Run Structure"/"Run UI"; run-ui U2 `match` row; boss-ai C1.4; systems-index Match UI ↔ Run UI resolution. Retires: TD-006 (AI as a command issuer), TD-009 (run state owner). Depends on: ADR-0001.

**ADR-0010 — Renderer choice vs Xvfb screenshot capture** · Layer: Foundation · Domain: Rendering · probe: **yes** (on the CI image: `xvfb-run godot --path . --windowed --write-movie ... --quit-after 60 <scene>` with Forward+; if it fails or renders black, repeat with `--rendering-method gl_compatibility`; retain both frames)
Context: `project.godot` pins Forward+ (desktop, D3D12 default on Windows since 4.6 — sourced); coding-standards require a retained screenshot per Visual/UI story and `run-and-observe.md` requires `xvfb-run` on Linux CI; game-concept Technical Risks flag that Forward+ under Xvfb may need the Compatibility renderer. The ADR decides the shipped renderer, the capture renderer, whether they differ, and the evidence rig's exact launch line and frame-selection rule. It is Foundation because the test rig (gate exit criterion 3) cannot complete without it. Serves: game-concept Technical Considerations/Risks; match-ui U11; run-ui U10; coding-standards "A parse check is not a run"; gate-technical-setup exit criterion 3. Retires: TD-012 (evidence half). Depends on: none. Carry-forward from the Technical Setup gate.

### Should have before the relevant system is built (Presentation)

**ADR-0009 — Match UI animation queue / tween approach and scene partition** · Layer: Presentation · Domain: UI / Animation · probe: no (APIs sourced)
Context: match-ui U1 (parts), U3 (projection), U4 (`AnimStep` FIFO, groups by `cause_seq` root, coalescing, speed divisor, skip-all ≤ 100 ms, idle invariant asserted in debug), U6 (boss burst pacing), U12 ("scene/node architecture and the tween library choice are ADRs"). The ADR picks `Tween` (with `tween_await()` 4.7 where a step waits on a signal — sourced) over `AnimationPlayer`, uses `Control.offset_transform_*` (4.7, sourced) for hover/press lifts inside containers so layout containers do not reset them, fixes the presenter scene split (`match_view.tscn` root + one scene per presenter + card frame scene shared with Run UI), the process-tick timer rule (U4.8), and dual-focus handling (4.6). Serves: match-ui U1, U3–U7, U9, F3, F4, Input Responsiveness; match-rules Game Feel; DD-X07 `anim_speed`/`reduce_motion`. Retires: TD-003 (view as projection), TD-006 (display-only). Depends on: ADR-0001, ADR-0003, ADR-0008.

**ADR-0011 — Run UI shell pattern and the Meta stub injection seam** · Layer: Presentation · Domain: UI · probe: no
Context: run-ui U1 (one `RunShell`, screen stack, `ShellState`, `RunController` as the sole talker to Run Structure / Reward Draft / Meta, read models in, intents out, every visible mutation from an event), U2 (screen inventory and intent → command map), U4 (transition input lock, `committed` sub-state), U5 (toast queue and `ack_notification`), U10 (fixtures into a `MetaStub`); meta-progression Dependencies (MVP in-memory stub; Hard from Vertical Slice). Kept separate from ADR-0008 and ADR-0009 rather than merged: it governs a different layer and GDD than 0008 (Core / run-structure), a different scene tree and interaction model than 0009 (screens and focus graph, not an animation queue), and it carries the one decision the MVP depends on that neither of them does — the `MetaApi` seam through which `MetaStub` is injected. The skill's criteria group by layer and priority, not by document count, and `/create-control-manifest` extracts rules per ADR, so a merged ADR would blur which rules apply under `src/ui/run/`. Serves: run-ui U1–U10, F1–F4; meta-progression M1.3, M9, Dependencies; reward-draft UI Requirements; DD-X02, DD-X07. Retires: TD-009 (no `set_meta` run state in screens), TD-006. Depends on: ADR-0001, ADR-0004 (`MetaApi`), ADR-0008.

### Can defer to implementation

- Per-presenter scene files, theme resource structure and icon art (`/ux-design`, art bible).
- The `tools/content/validate.gd` JSON Schema files per data file (MVP-1 validator story under ADR-0002).
- `keep_match_logs` default per build type and the replay viewer (Vertical Slice).
- Export presets and `commands.build` (test rig story; no ADR).

Priority order for `/architecture-decision`: 0001 → 0002 → 0003 → 0004 → 0010 (Foundation, critical) → 0007 → 0005 → 0008 → 0006 → 0009 → 0011.

---

## Open Questions

| ID | Summary | Priority | Resolution path |
|---|---|---|---|
| QQ-01 | Threading mechanism for the planner (`WorkerThreadPool` vs `Thread` vs time-slicing); whether GDScript `RefCounted` graphs may be touched from a worker without the main thread reading them | High | ADR-0006 probe (`docs/architecture/spikes/2026-11-03-engine-probes.md`) |
| QQ-02 | Atomicity of `DirAccess.rename_absolute` over an existing target on Windows and Linux | High | ADR-0004 probe |
| QQ-03 | Forward+ under `xvfb-run` on the CI image; capture renderer vs shipped renderer | High | ADR-0010 probe |
| QQ-04 | Does a `godot -s GdUnitCmdTool.gd` run instantiate autoloads? Determines whether `Boot` must be lazy (it is designed lazy either way) | Medium | one-line probe in the same spike file; NOT SOURCEABLE |
| QQ-05 | Draw-call and memory ceilings, minimum spec | Medium | producer + `/perf-profile` after the first Match UI story; record in Performance budgets |
| QQ-06 | `RandomNumberGenerator` algorithm stability across 4.7.x patches (replay equivalence is per engine version by design) | Low | ADR-0003 records the helper self-test result; re-run on every engine bump |
| QQ-07 | Mid-match restore from the event log (run-structure R8.3 defers; `EffectRuntime` rides in `MatchState` for it) | Low | Vertical Slice design change, not architecture |
| QQ-08 | Whether `Treasures.pool()` is called by `RewardDraft.init_run` or the predicate is applied inline over `treasure_pool()` (reward-draft Interactions leaves it to architecture) | Low | **Decided here**: `RewardDraft.init_run` calls `Treasures.pool(unlocked_keys, [])` so the predicate has one implementation; ADR-0005 records it |

---

## Decisions taken (guided mode; no answerer present)

1. Phase 0d — proceed and flag HIGH-risk domains; probes gate the three NOT SOURCEABLE ADRs (recommended option A).
2. Phase 0e — no existing `architecture.md`; full walkthrough.
3. One autoload (`Boot`) as a lazy composition root, grep-gated; rules never reference it (recommended over "no autoload" because U10/U11 direct scene launches need a tree-level root, and over a service locator because of TD-001).
4. Meta Progression split: persistence (`ProfileStore`) in Foundation `src/core/save/`, rules (`UnlockEvaluator`, `StatsFold`) in Feature `src/gameplay/meta/`; one `@abstract MetaApi` implemented by the facade and `MetaStub`.
5. `MatchDriver` lives in `src/gameplay/run/` (Run Structure's ownership per cross-review C-17), wrapped by `MatchController` in `src/ui/match/`.
6. `PlannerTask` abstract seam with main-thread time-slicing as the default implementation until the ADR-0006 probe passes; event subscribers never run off the main thread.
7. ADR-0011 kept as a separate ADR (justified in its entry); ADR-0010 classed Foundation (critical) because the evidence rig is a gate exit criterion; ADR-0009 and ADR-0011 are Presentation (non-critical, required before their epics).
8. Treasure pool predicate called from `RewardDraft.init_run` (QQ-08).
9. Class and field names aligned with `tests/helpers/` (`RngService`, `RngStream`, `EventLog`, `MatchConfig`, `CommandResult`, `MatchResult`, `RunState`/`RunRecord`, `DraftRecord`, `Offer`, `Pick`, sides `"player"`/`"boss"`); the production `MatchState.hooks` is a `HookRegistry` object where `MatchFactory` currently uses `[]`, and `RunFactory.make_match_config_for` must pass `Treasures.installers_for(...)` instead of raw ids — both covered by the helpers' `TODO(E1/E2)` swap markers.
10. Draw calls, memory ceiling and minimum spec recorded as NOT SOURCEABLE / TBD rather than invented.

## Next steps

`/architecture-decision` for ADR-0001..0004 and 0010 first (Foundation), then 0007, 0005, 0008, 0006, 0009, 0011; write `docs/architecture/spikes/2026-11-03-engine-probes.md` alongside 0004/0006/0010; `/create-control-manifest`; `/architecture-review` (registers the 71 provisional TR-IDs); `/ux-review` on the per-screen specs; test-rig completion (export preset, main-scene stub so `commands.smoke` exits, one integration test, one proven Xvfb screenshot into `production/qa/evidence/`); `/gate-check pre-production`.
