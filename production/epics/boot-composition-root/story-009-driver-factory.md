# Story 009: Boot supplies `driver_factory` — a per-task planner factory chosen by `planner_mode`

> **Epic**: Boot & Composition Root
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-11-04
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

Sprint 6 Goal Prerequisites row 8. ADR-0008 Decision 1 says `Boot` supplies the `driver_factory` that `RunMachine.begin_match()` calls, so the `PlannerTask` implementation and the settings snapshot are composition concerns, not `RunMachine`'s. Nothing builds it: `src/` has one doc-comment mention (`match_driver.gd`), and MUI-003 built its tests around `MatchDriver.new` directly because "no story builds `driver_factory`". Four picked stories name it (MUI-004 AC-2, BAI-016 AC-4, BAI-019 AC-3, BAI-018) and MUI-012 builds on it. `RunMachine` stays out of this story: the fixture launch and the harness do not need it, and the Run Structure epic has no stories.

The factory must serve two callers the docs seem to pull apart. ADR-0006 and the control manifest say `Boot`'s task factory makes a `WorkerPoolPlannerTask` by default; ADR-0008 Decision 11, the manifest and BAI-016 say the debug loader and the sim harness use the same factory "with `ImmediatePlannerTask`". Both hold once the factory builder takes an optional planner override (see Implementation Notes, "How both are served").

DD-X33 (owner, 2026-11-05) closes the remaining gap: shipped data cannot select a test helper. The `ai_profiles.json` validator stops accepting `planner_mode: "immediate"`, and tests and the harness pass a planner through the `driver_factory` override.

**GDD**: no Boot GDD. `design/gdd/run-structure.md` Interactions "Boss AI" (R3, R4, T5) · `design/gdd/boss-ai.md` C1.5, C11, F9 · `docs/architecture/architecture.md` §API Boundaries (Run Structure, Boss AI) and §Dependency injection and the composition root · `design/design-decisions.md` DD-X31, DD-X33
**Requirement**: `TR-run-structure-005` (the driver is built at `begin_match`, wrapped by Match UI), `TR-boss-ai-003` (planner off-thread or time-sliced, mechanism by ADR)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008: Match Driver Ownership and the Run ↔ Match ↔ UI Hand-off (Decision 1, Decision 11, Key Interfaces). Also ADR-0006: Boss AI Planner Threading (Implementation Guidelines: "`Boot`'s task factory must make a new `WorkerPoolPlannerTask` per call by default and a new `TimeSlicedPlannerTask` when `runtime.planner_mode == "time_sliced"` or the debug flag `--ai-sync` is present"); ADR-0001 (Decision 4: `Boot` is the one `src/core` file that may name gameplay and AI classes); ADR-0011 (Decision 4, the `boot(overrides)` seam)
**ADR Decision Summary**: `Boot` supplies `func(cfg): return MatchDriver.new(cfg, db, settings_snapshot, <Callable() -> a new PlannerTask per call>)` (DD-X31: one task object per plan, because `PlannerTask.start` runs once per object and `TimeSlicedPlannerTask` cannot be started twice). The default implementation is the worker pool; the time-sliced one is the `planner_mode` / `--ai-sync` fallback; `ImmediatePlannerTask` is tests and the sim harness only and lives under `tests/helpers/`.
**ADR Version**: 2026-11-03 (ADR-0008 errata through 2026-11-05 are in the text read; ADR-0006, ADR-0001, ADR-0011: 2026-11-03)

**Engine**: Godot 4.7.2 | **Risk**: HIGH by version (ADR-0008, ADR-0001); the APIs here (`Callable`, `RefCounted`, `OS.get_cmdline_user_args()`, `OS.is_debug_build()`) have no post-cutoff change listed. The threading behind `WorkerPoolPlannerTask` is NOT SOURCEABLE and belongs to BAI-017 / BAI-018.
**Engine Notes**: Lambdas capture locals by value (ADR-0008 Engine Compatibility, `current-best-practices.md` §GDScript 4.5+): the returned closure may capture the `CardDatabase`, the `MetaApi` and the planner `Callable` (references and values) but never a mutable local that a later call is meant to change. `WorkerPoolPlannerTask.new()` starts nothing; only `start()` touches the pool, so the tests here never start a worker (TD-012).

**Control Manifest Rules (Foundation layer, v2026-11-04)**:
- Required: `Boot` is a lazy, idempotent composition root; scene roots and `*_debug_loader.gd` are its only non-test callers and pass what they get down by argument (`RunMachine` receives the factory as an argument, it never names `Boot`). Boot responsibilities are exactly the "Boot does" rows of `production/epics/boot-composition-root/boot-responsibilities.md`, so this story adds one row.
- Required (Core, ADR-0006): default `WorkerPoolPlannerTask`; fallback `TimeSlicedPlannerTask`; `ImmediatePlannerTask` in `tests/unit/**` and the sim harness.
- Forbidden: `Boot` owns no game state (its script variables stay exactly `booted`, `_services`, `_result`; `boot_composition_test.gd::test_boot_holds_no_game_state_fields`). `Services` stays four handles and no behaviour. `src/**` never names `ImmediatePlannerTask` or a `tests/` path. The worker is never handed `Boot`, the driver, the live engine or a Node.
- Guardrail: data load ≤ 200 ms is unchanged; the factory is built on demand after `boot()`, reads `config("ai_profiles")` once and builds no driver until it is called.

---

## Acceptance Criteria

*From ADR-0008 Decision 1 and Decision 7, ADR-0006 Implementation Guidelines, DD-X31, DD-X33, scoped to this story:*

- [ ] GIVEN a `Ready` boot, WHEN `Boot.driver_factory().call(config)` is called twice with a valid `MatchConfig`, THEN each call returns a new `MatchDriver` built over `Services.card_database`, with the settings snapshot `Services.meta.get_settings()` taken at that call (a `set_setting(telegraph_mode, …)` made after the first call does not change the first driver, and the second driver's `BossAI` reads the new value); and GIVEN a `Failed` load or no `boot()` yet, THEN `driver_factory()` returns an empty `Callable` and logs an error rather than a factory over no data.
- [ ] GIVEN the planner `Callable` the factory hands each driver, WHEN it is called three times, THEN it returns three distinct objects; by `config("ai_profiles").runtime.planner_mode` they are `WorkerPoolPlannerTask` (`worker`, the shipped value), or `TimeSlicedPlannerTask` built with `int(slice_ms * 1000)` (`time_sliced`); and `--ai-sync` in the user args selects the time-sliced task in a debug build whatever the config says. No task is `start()`ed in this suite.
- [ ] GIVEN `Boot.driver_factory(planner_override)` with a `Callable() -> PlannerTask`, WHEN the driver plans, THEN every task comes from the override and `planner_mode` and `--ai-sync` are not consulted; and `src/**` contains no reference to `ImmediatePlannerTask` or to a `res://tests` path outside `##` doc-comment lines (grep), so the same factory works in an export whose preset excludes `tests/*`.
- [ ] GIVEN an `ai_profiles.json` whose `runtime.planner_mode` is `"immediate"`, WHEN `BossAI.validate_profiles_config` runs, THEN `_check_runtime` in `src/ai/boss_ai.gd` reports one `E_AI_UNKNOWN_FIELD` error row on `runtime.planner_mode`, so the load is a data error (DD-X33). The change is that `"immediate"` leaves `BossAI.PLANNER_MODES`, which then holds `worker` and `time_sliced`; both still validate, and the shipped `assets/data/ai_profiles.json` (`worker`) still loads clean.
- [ ] GIVEN the change is merged, THEN `Boot`'s script variables are unchanged, `Services` is unchanged, `_collect_validators()` and the `PENDING_*_OWNERS` lists show no diff, and gates G1–G7, the per-file parse check and the existing `tests/integration/boot/` suites pass.

---

## Implementation Notes

*Derived from ADR-0008 Decision 1 / 7 / 11 and ADR-0006 Implementation Guidelines:*

- **Shape** (the surface is stateless and derived from `_services`, which keeps `BOOT_FIELDS` true and `Services` free of behaviour; `services.gd` documents "four handles and no behaviour", which is why this is a method on `Boot` and not a `Services` field):
  `func driver_factory(planner_override: Callable = Callable(), cmdline_args: PackedStringArray = OS.get_cmdline_user_args()) -> Callable`, returning `func(config: Dictionary) -> MatchDriver` that calls `MatchDriver.new(config, db, meta.get_settings(), planner_factory)`. `cmdline_args` is a parameter only so a test can pass `--ai-sync` without a process argument.
- **Planner factory by mode** (read `db.config("ai_profiles").runtime` once when the builder runs, per "read `config(<name>)` once"): `planner_override` valid → use it; else `--ai-sync` (debug build) or `time_sliced` → `func() -> PlannerTask: return TimeSlicedPlannerTask.new(int(slice_ms * 1000))`; else `func() -> PlannerTask: return WorkerPoolPlannerTask.new()`. A new object per call, always.
- **How both are served** (resolution, from the docs):

  | Caller | Planner | Why it is available there |
  |---|---|---|
  | gdUnit suites, BAI-016 sim harness, `capture.sh` runs from the repo | `ImmediatePlannerTask` passed as `planner_override` | `tests/helpers/` exists in the repo; ADR-0006 forbids a worker under gdUnit |
  | Windows debug export (`-- --fixture=first_playable`), BAI-018, MUI-012 playtest | no override: `worker` by default, `--ai-sync` for a synchronous-ish run | `src/ai/` is exported; `tests/*` is **not** (the one preset's `exclude_filter`) |
  | BAI-017 | each of the three, by override | the one place a real worker runs under `tests/` |

  Consequence for MUI-004 (not edited here): its loader as specified names `ImmediatePlannerTask`, a `tests/helpers/` class, so in the exported debug build the loader script would fail to resolve it. The loader must receive the planner from its caller (tests and `capture.sh` pass the override; the export passes none) and never name the class. MUI-004 AC-2 reads "with `ImmediatePlannerTask`" and needs that wording changed at readiness; say so, do not edit it.
- **`planner_mode: "immediate"` is a data error (DD-X33).** Remove `"immediate"` from `BossAI.PLANNER_MODES` (`src/ai/boss_ai.gd`, about line 172); `_check_runtime` reads that list, so its existing `E_AI_UNKNOWN_FIELD` row and message then cover the value with no new branch. `Boot` therefore only ever sees `worker` or `time_sliced`. What moves with it, in the same commit:
  - `tests/fixtures/boss_ai/profiles_stub.json` sets `planner_mode` to `immediate` and the resolver suite validates it, so it moves to `worker`. It is a shared fixture (`tests/helpers/boss_ai_board.gd` reads it too), so this story is [S]. The other `tests/fixtures/data/*/ai_profiles.json` and the shipped file already read `worker`.
  - `tests/unit/boss_ai/boss_ai_profile_resolver_test.gd`: `test_validate_runtime_accepts_each_planner_mode` drops `immediate`, and `test_validate_runtime_rejects_anything_else` gains it.
  - `design/gdd/boss-ai.md` F9 `runtime` line drops `immediate` and keeps "(default worker)", which `boss_ai_profiles_data_test.gd` parses. ADR-0006's GDD-requirements row and `requirements-traceability.md` quote the old F9 list; they are technical-director's to refresh and are not edited here.
- **Settings snapshot**: `MetaApi.get_settings()` returns a deep copy, so it is the snapshot; the driver keeps it (`telegraph_mode` is applied to `BossAI` at construction, ADR-0008 Decision 7). Later changes reach a live driver only through `MatchController.on_setting_changed`.
- **File ownership**: `src/core/boot.gd` is orchestrator-owned in sprint lanes. This story adds one method and touches nothing in `_collect_validators()`, `PENDING_CONFIG_OWNERS` or `PENDING_RECORD_OWNERS`; the orchestrator merges it. The method names `MatchDriver`, `WorkerPoolPlannerTask` and `TimeSlicedPlannerTask`, which only `boot.gd` may do among `src/core` files (gate G3's exclusions, `boot-responsibilities.md`).
- Add one "Boot does" row to `boot-responsibilities.md` (the factory; guards TD-001 by being a function of `_services`, no stored state). The manifest's Foundation Required Patterns gain it at the next `/create-control-manifest update`; that run is separate.

**Open design questions — flagged, not decided here (owner / technical-director):**

1. **BAI-019's busy predicate against DD-X31.** BAI-019 AC-3 and its notes bind `db.set_reload_busy(task.is_live)` to the one task a driver holds. After DD-X31 a driver makes a new task per plan, so one bound `is_live` goes stale. This story does not wire a predicate (that is BAI-019's file list). BAI-019 needs its AC-3 and notes reworded at readiness to a predicate over "any task this driver's factory made is live", for example a small tracker object the planner factory closes over. Recommended; not decided.
2. **`--ai-sync` in a release build** is unstated in ADR-0006 ("the debug flag"). The AC covers the debug build only; ignoring the flag in release is assumed.
3. **Failed-load behaviour** of `driver_factory()` (an empty `Callable` and a logged error) mirrors `BootResult.ok = false` but is not written in ADR-0008. Confirm at readiness.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `RunMachine` and `begin_match()` (Run Structure epic, no stories yet): it receives the factory by argument.
- `MatchDebugLoader` and the `--fixture` path (`production/epics/match-ui/story-004-match-view-skeleton-and-fixture-loader.md`); the export preset split and `.pck` grep (`production/epics/match-ui/story-012-first-playable-windows-match.md`).
- `CardDatabase.set_reload_busy` and its wiring (`production/epics/boss-ai-match-driver/story-019-reload-busy-while-planning.md`).
- The Windows determinism and A30 run (`production/epics/boss-ai-match-driver/story-018-windows-planner-a30-and-determinism.md`).

---

## Files

- `src/core/boot.gd` (one new method; orchestrator-owned file, see Implementation Notes)
- `src/ai/boss_ai.gd` (`PLANNER_MODES` loses `immediate`, DD-X33)
- `tests/integration/boot/boot_driver_factory_test.gd`
- `tests/unit/boss_ai/boss_ai_profile_resolver_test.gd` (the two runtime tests)
- `tests/fixtures/boss_ai/profiles_stub.json` (`planner_mode` → `worker`)
- `design/gdd/boss-ai.md` (F9 `runtime` line)
- `production/epics/boot-composition-root/boot-responsibilities.md` (one row)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above (QL-STORY-READY skipped — Lean mode).*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/boot/boot_driver_factory_test.gd` — must exist and pass. Use `MatchDriverFixture` (`tests/helpers/match_driver_fixture.gd`) for the database and `MatchConfig`, and `FakePlannerTask` for the override. Assert planner class by `is`, never by starting it.
- Also: `tests/unit/boss_ai/boss_ai_profile_resolver_test.gd` passes with `immediate` on the rejected side.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/boot-composition-root/story-004-boot-composition-root.md`, `production/epics/boss-ai-match-driver/story-001-planner-task-seam.md`, `production/epics/boss-ai-match-driver/story-013-match-driver-construction-and-command-gate.md`, `production/epics/boss-ai-match-driver/story-014-match-driver-phase-schedule.md`, `production/epics/boss-ai-match-driver/story-015-match-driver-tick-replay-and-shutdown.md` (all done)
- Unlocks: `production/epics/match-ui/story-004-match-view-skeleton-and-fixture-loader.md` (AC-2), `production/epics/boss-ai-match-driver/story-016-sim-harness.md` (AC-4), `production/epics/boss-ai-match-driver/story-019-reload-busy-while-planning.md` (AC-3), `production/epics/boss-ai-match-driver/story-018-windows-planner-a30-and-determinism.md` (the worker selected in a windowed match), `production/epics/match-ui/story-012-first-playable-windows-match.md`
- **Sprint 6 placement**: before W1, lane 8 in the plan's Pre-W1 story lanes, merged at M0 ahead of lane work. MUI-004 (L1 W1), BAI-016 and BAI-019 (L4 W1) all consume it in W1, and a story only starts on another lane's work after an earlier merge point. About 1.5 links, a `general-purpose` agent in the gameplay-programmer role. Fallback: L6 W1, merged first at M1; then MUI-004 AC-2, BAI-016 AC-4 and BAI-019 AC-3 close in the W2 fix slots, not in W1. Merges ahead of every W1 lane (consumers build on its contract); [S] for the shared fixture.
