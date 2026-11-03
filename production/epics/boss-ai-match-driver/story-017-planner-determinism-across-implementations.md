# Story 017: Worker-vs-main-thread determinism and forecast concurrency (gate condition 9, Linux half)

> **Epic**: Boss AI + Match Driver
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/boss-ai.md` C1.5 ("the result is identical on and off the main thread"), C9, A1, A30 (its determinism clause)
**Requirement**: `TR-boss-ai-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Boss AI Planner Threading (Verification table rows 1, 3, 6; Validation Criteria "1,000-match determinism run … identical logs across the three `PlannerTask` implementations"); ADR-0008 (Validation "Equivalence: the same scripted match with `ImmediatePlannerTask` and with ADR-0006's worker implementation yields byte-identical event logs")
**ADR Decision Summary**: Because the planner is a pure function of a snapshot and budgets are counts, the `TurnPlan` and the replayed live log must be byte-identical whether the task ran on a `WorkerThreadPool` thread, time-sliced on the main thread or immediately. The thread-safety argument (worker owns the clone; shared objects are the frozen `CardDatabase` and the `ai_<floor>` stream) is by construction, and concurrent read-only `Dictionary` access is NOT SOURCEABLE — proven by stress test.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH / NOT SOURCEABLE
**Engine Notes**: This is the one place a real `WorkerThreadPool` task runs under `tests/`; it is therefore an **integration** suite, not `tests/unit/**` (ADR-0006 lists `tests/unit/boss_ai/test_worker_pool_planner_task.gd` for the pool equivalence, which conflicts with its own "tests/unit/** never start a worker" guideline — resolved here by placing the worker run in `tests/integration/boss_ai/`). gdUnit4 headless with `--ignoreHeadlessMode` ran Probe A's pool pattern; CI `ubuntu-latest` has ≥ 2 cores. Check stderr is empty (no `Invalid Task ID`, no leaked-instance warnings at exit under `--debug`). `RefCounted` atomic refcounts: NOT SOURCEABLE, covered by the stress run.

**Control Manifest Rules (this layer)**:
- Required: Default `WorkerPoolPlannerTask` protocol (one `is_task_completed` per `tick()`, `wait_for_task_completion` exactly once). `CardDatabase.reload()` returns `E_BUSY` while any `PlannerTask` is live (debug builds).
- Forbidden: `tests/unit/**` and the sim harness never start a worker. Never call `is_task_completed` after `wait_for_task_completion`. The worker is never handed the live engine, live log, driver, view, `Boot` or a `Node`.
- Guardrail: Boss AI main thread ≤ 2 ms per frame; worker 50 ms p95 per turn.

---

## Acceptance Criteria

*From ADR-0006 Verification table and Validation Criteria, scoped to TR-boss-ai-003 (GDD C1.5, A1, A30 determinism clause):*

- [ ] GIVEN 1,000 seeded band-1..3 boss turns (fixtures from Story 016's harness), WHEN each is planned and replayed through the real `MatchDriver` with `WorkerPoolPlannerTask`, `TimeSlicedPlannerTask` and `ImmediatePlannerTask` in turn, THEN `TurnPlan.to_dict()` and the replayed live `EventLog` (canonical JSON) are byte-identical across the three, with zero `ai_fault {replay_divergence}` and zero `ai_fault` of any kind.
- [ ] GIVEN a `RefCounted`-only workload, WHEN run through `WorkerPoolPlannerTask` polled once per frame until `poll()` is true, THEN its result equals the same workload through `ImmediatePlannerTask`, `OS.get_thread_caller_id() != OS.get_main_thread_id()` inside the task, stderr is empty (no `Invalid Task ID`), and the task completes in one `poll()` sequence with no yield on the worker path (`await checkpoint()` returns immediately).
- [ ] GIVEN forecast tasks running on the worker, WHEN the main thread calls `MatchQuery.card_text` 10,000× concurrently, THEN every result is identical to a single-threaded run and no error output appears; and GIVEN a live task in a debug build, WHEN `CardDatabase.reload()` is called, THEN it returns `E_BUSY`.

---

## Implementation Notes

*Derived from ADR-0006 Verification / Validation Criteria:*

- Files: `tests/integration/boss_ai/boss_ai_planner_determinism_test.gd` (ADR name `test_planner_determinism.gd`; project naming is `[system]_[feature]_test.gd`), `tests/integration/boss_ai/boss_ai_worker_pool_planner_task_test.gd` (ADR name `test_worker_pool_planner_task.gd`, moved out of `tests/unit/`), `tests/integration/boss_ai/boss_ai_forecast_concurrency_test.gd` (ADR name `test_forecast_concurrency.gd`). Record the three path/name differences in ADR-0006's Verification table on first `/story-done` (owner-approved one-line edits).
- The 1,000-turn run is behind an env flag in CI (`SIM_FULL=1`) with a 50-turn sample always on, mirroring Story 016; the full run is also what Story 018 repeats on Windows.
- Driving the worker variant in a gdUnit4 suite: the suite's own `await get_tree().process_frame` between `driver.tick()` calls plays `MatchView._process`'s role (Probe A's "polled per frame" pattern). Use `auto_free` on any Node the suite creates; keep the orphan count 0 (exit 101 fails CI).
- `reload()` `E_BUSY` is `CardDatabase` code (`card-database` epic) reading a `PlannerTask.is_live()` registry the driver exposes; if that hook is not landed yet, mark that single assertion pending with the blocking story path rather than stubbing it here.
- Gate condition 9 (technical-director): this story is the Linux half; Story 018 repeats it on the Windows export.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: the task implementations.
- Story 015: the replay path (exercised here, not changed).
- Story 018: the Windows repetition and A30 frame timing.

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `tests/integration/boss_ai/boss_ai_planner_determinism_test.gd`
- `tests/integration/boss_ai/boss_ai_worker_pool_planner_task_test.gd`
- `tests/integration/boss_ai/boss_ai_forecast_concurrency_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/boss_ai/boss_ai_planner_determinism_test.gd` (plus the two companion suites above) — required

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/boss-ai-match-driver/story-001-planner-task-seam.md`, `production/epics/boss-ai-match-driver/story-015-match-driver-tick-replay-and-shutdown.md`, `production/epics/boss-ai-match-driver/story-016-sim-harness.md`
- Unlocks: `production/epics/boss-ai-match-driver/story-018-windows-planner-a30-and-determinism.md`
