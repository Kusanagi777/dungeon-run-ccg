# Story 019: CardDatabase.reload() refuses with E_BUSY while a PlannerTask is live

> **Epic**: Boss AI + Match Driver
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: S
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/boss-ai.md` C1.5 (the planner runs off the main thread or time-sliced, reading the frozen snapshot) · `design/gdd/card-database.md` CR-6 (queries are pure reads on a frozen snapshot) and States and Transitions (`READY | FAILED → RELOADING`, debug only)
**Requirement**: `TR-boss-ai-003`, `TR-card-database-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Boss AI Planner Threading (Implementation Guidelines: "`CardDatabase.reload()` **must** return `E_BUSY` while any `PlannerTask` is live (debug builds only; release returns `E_NOT_SUPPORTED` already)"; the thread-safety argument: the worker's only shared objects are the frozen `CardDatabase` snapshot and the `ai_<floor>` stream); ADR-0008 Decision 1 (`Boot` supplies `driver_factory` — "the `PlannerTask` implementation and the settings snapshot are composition concerns"); ADR-0002 (`reload()` debug-only, atomic swap); ADR-0001 (dependency direction: `src/core/**` names nothing in `src/ai/**` or `src/gameplay/**`; composition happens once, at the edge — architecture.md: "at runtime every arrow points down")
**ADR Decision Summary**: The planner's thread safety is by construction: the worker reads the frozen `CardDatabase` snapshot and nothing else that the main thread could change. A debug `reload()` swaps the snapshot, so it must refuse while any `PlannerTask` is live. `CardDatabase` is Foundation and must not know about planners, so the check is an injected `Callable() -> bool` busy predicate; the composition root's `driver_factory`, which constructs the `PlannerTask` it hands each `MatchDriver`, wires that task's `is_live` into the database.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (by version; ADR-0006 threading is NOT SOURCEABLE — but this story adds no threading: `Callable.call()`, `OS.is_debug_build()` and `RefCounted` have no post-cutoff change)
**Engine Notes**: The predicate is read on the main thread only: `reload()` is a main-thread debug call, and `PlannerTask._live` is written by `start()` / `poll()` on the main thread (worker) or inside `poll()`'s synchronous resume (time-sliced), never by the worker. The predicate is a bound-method `Callable` on the task (`task.is_live`), not a lambda, so it captures nothing; the task holds no reference to the database, so `db → task` forms no `RefCounted` cycle.

**Control Manifest Rules (this layer)**:
- Required: `CardDatabase.reload()` returns `E_BUSY` while any `PlannerTask` is live (debug builds). `reload()` builds a new snapshot and swaps atomically in debug builds; returns `E_NOT_SUPPORTED` in release (Foundation, ADR-0002). `MatchDebugLoader` and the boss-ai sim harness build their driver through the same `driver_factory` with `ImmediatePlannerTask`.
- Forbidden: Never let `src/core/**` name `PlannerTask`, `MatchDriver`, `BossAI` or any `src/ai/**` / `src/gameplay/**` class (dependency direction, ADR-0001). The worker is never handed `MatchDriver`, `Boot` or any `Node`.
- Guardrail: `reload()` holds two snapshots briefly (≤ 2 × `data_memory_budget_mb`); the busy check adds one `Callable.call()` before any work.

---

## Acceptance Criteria

*From ADR-0006 Implementation Guidelines and Risks ("`reload()` refuses while a task is live"), tracing TR-boss-ai-003 and TR-card-database-003:*

- [ ] GIVEN a `READY` debug-build `CardDatabase` over a spy loader with a busy predicate installed that returns `true`, WHEN `reload()` is called, THEN it returns a report whose one entry is `E_BUSY` (severity error), the loader is not run, and `state()`, the snapshot, `report()`, `data_version()` and `last_reload_report()` are unchanged.
- [ ] GIVEN the same database with the predicate returning `false`, or with none installed, WHEN `reload()` is called, THEN story 008's behaviour is unchanged (swap on success, previous snapshot kept on failure, `E_NOT_LOADED` before a finished `load()`); and GIVEN a release-build database with a predicate returning `true`, THEN the one entry is still `E_NOT_SUPPORTED`.
- [ ] GIVEN a `MatchDriver` built through the composition root's `driver_factory` with a fake `PlannerTask` whose `poll()` is scripted to stay `false`, WHEN a plan or forecast task is live and `db.reload()` is called, THEN it returns `E_BUSY` and `data_version()` is unchanged; WHEN `tick()` then sees `poll()` return `true`, THEN the next `reload()` runs and swaps (`READY`, new report); and `src/core/data/card_database.gd` names no `PlannerTask`, `MatchDriver`, `BossAI` or `src/ai/` path (grep, comment lines excluded).

---

## Implementation Notes

*Derived from ADR-0006 Implementation Guidelines and ADR-0008 Decision 1:*

- `src/core/data/validation_report.gd`: add `const E_BUSY: StringName = &"E_BUSY"` with a doc comment ("`reload()` while a Boss AI planner task is live; the one entry of the report it returns; nothing touched — ADR-0006").
- `src/core/data/card_database.gd`: add `var _reload_busy: Callable = Callable()` and `func set_reload_busy(busy: Callable) -> void` (doc comment with example; an empty `Callable` clears it). In `reload()`, check in this order: release → `E_NOT_SUPPORTED`; not `READY`/`FAILED` → `E_NOT_LOADED`; `_reload_busy.is_valid() and _reload_busy.call()` → `E_BUSY`; then the existing pipeline. Keep the class doc's States paragraph in step (`reload()` refuses while busy).
- The composition root's `driver_factory` (ADR-0008 Decision 1: `func(cfg): return MatchDriver.new(cfg, db, settings_snapshot, <PlannerTask per ADR-0006>)`) becomes: construct the `PlannerTask`, call `db.set_reload_busy(task.is_live)`, then build the driver with that task. Each new driver's task replaces the previous predicate; an ended match's task reports `is_live() == false`, so reload is allowed between matches. If `Boot`'s factory has not landed when this story starts, add the wiring where the factory is built and name the file in `/dev-story`'s Files list (a cross-epic touch to `boot-composition-root`'s file, approved with this story).
- The predicate is the task's `is_live`, not `MatchDriver.is_planning()`: ADR-0006 refuses only while a task is live; a plan pending replay with no task live reads the live engine on the main thread, which the atomic swap already covers (a match holds `snapshot_handle()`).
- Unit part (AC 1–2) lives beside story 008's tests: `tests/unit/card_database/card_database_reload_busy_test.gd`, with an injected `func(): return true` / `func(): return false` predicate — no AI class in that test.
- Integration part (AC 3): `tests/integration/match_driver/reload_busy_while_planning_test.gd`, using the `tests/helpers/fake_planner_task.gd` double from story 013 and a debug-build `CardDatabase` over a fixture root; never a worker (TD-012).
- Story 017's AC 3 assertion "GIVEN a live task in a debug build, WHEN `CardDatabase.reload()` is called, THEN it returns `E_BUSY`" depends on this story; its Implementation Notes say to mark that assertion pending against this story's path until it lands.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `card-database` story 008: the `reload()` state machine, atomic swap and `E_NOT_SUPPORTED` (already merged; this story only adds the busy refusal).
- Story 017: worker-vs-main-thread determinism and the forecast concurrency stress test (it re-asserts `E_BUSY` against a real worker).
- The debug overlay or key binding that calls `reload()` and shows its report.

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/core/data/validation_report.gd`
- `src/core/data/card_database.gd`
- `src/core/boot.gd` (the `driver_factory` wiring)
- `tests/unit/card_database/card_database_reload_busy_test.gd`
- `tests/integration/match_driver/reload_busy_while_planning_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/match_driver/reload_busy_while_planning_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)
- Unit (AC 1–2): `tests/unit/card_database/card_database_reload_busy_test.gd`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/card-database/story-008-state-machine-and-debug-reload.md` (`reload()`), `production/epics/boss-ai-match-driver/story-001-planner-task-seam.md` (`PlannerTask.is_live()`), `production/epics/boss-ai-match-driver/story-013-match-driver-construction-and-command-gate.md`, `production/epics/boss-ai-match-driver/story-014-match-driver-phase-schedule.md`, `production/epics/boss-ai-match-driver/story-015-match-driver-tick-replay-and-shutdown.md` (`MatchDriver` construction, task scheduling, `tick()`); `boot-composition-root` epic's `Boot` (the factory's home, cross-epic)
- Unlocks: `production/epics/boss-ai-match-driver/story-017-planner-determinism-across-implementations.md` (its `E_BUSY` assertion)
