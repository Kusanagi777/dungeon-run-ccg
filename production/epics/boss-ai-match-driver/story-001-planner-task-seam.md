# Story 001: PlannerTask seam and its three implementations

> **Epic**: Boss AI + Match Driver
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-03

## Context

**GDD**: `design/gdd/boss-ai.md` (C1.5, C9)
**Requirement**: `TR-boss-ai-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Boss AI Planner Threading — `PlannerTask` Seam, Worker-Pool Default, Time-Sliced Fallback (also ADR-0001: Rules / Presentation Split for the `@abstract` / `RefCounted` rules)
**ADR Decision Summary**: The planner runs behind one `@abstract PlannerTask` seam (`start(work)`, `poll()`, `result()`, `is_live()`, `checkpoint()`) with three implementations: `WorkerPoolPlannerTask` (default, `WorkerThreadPool`), `TimeSlicedPlannerTask` (main-thread coroutine, yields at `checkpoint()` when the slice exceeds `slice_ms`) and `ImmediatePlannerTask` (runs `work` inside `start()`; the only one used by `tests/unit/**` and the sim harness).
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH / NOT SOURCEABLE
**Engine Notes**: Threading has no page in `docs/engine-reference/godot/`; `WorkerThreadPool.add_task / is_task_completed / wait_for_task_completion` exist on 4.7.2 by Probe A observation only. `@abstract` (4.5) is sourced; the 4.7 rule that every override of a typed method ends in an explicit `return` applies to every `PlannerTask` override (observed: `func result() -> Variant: pass` is a parse error). 2026-11-03 erratum: any function that awaits `checkpoint()` is a coroutine, so the task Callable is `func() -> Variant: return await boss_ai.plan_turn(sandbox)` built by `BossAI.plan_task(sandbox)` inside `src/ai/` (Story 008); only a dynamic `work.call()` escapes the static await check, which is why all three implementations work. Windows behaviour is unverified until Story 018.

**Control Manifest Rules (this layer)**:
- Required: Default `WorkerPoolPlannerTask`: `WorkerThreadPool.add_task(callable, false, "boss_ai")`, one `is_task_completed(id)` per `tick()`, `wait_for_task_completion(id)` exactly once after completion; fallback `TimeSlicedPlannerTask` when `runtime.planner_mode == "time_sliced"` or `--ai-sync`; `ImmediatePlannerTask` in `tests/unit/**` and the sim harness. `slice_ms`, `replay_budget_ms`, `planner_mode` come from the `ai_profiles.json` `runtime` block.
- Forbidden: Never call `WorkerThreadPool.is_task_completed` after `wait_for_task_completion` (`ERROR: Invalid Task ID`). Never a dedicated `Thread` per boss turn as the default. Never main-thread time-slicing as the sole implementation. `tests/unit/**` and the sim harness never start a worker (gdUnit4 runs headless; TD-012). Nothing in `src/ai/**` calls `signal.emit`, `log.append` on a live log, `get_tree()`, `Engine.get_main_loop()` or any `Node` method.
- Guardrail: Boss AI main thread ≤ 2 ms per frame — one `is_task_completed` per frame plus bounded replay.

---

## Acceptance Criteria

*From ADR-0006 Key Interfaces, Verification table and Validation Criteria, scoped to TR-boss-ai-003 (GDD C1.5 "off the main thread or time-sliced"):*

- [ ] `ImmediatePlannerTask.start(work)` runs `work.call()` inside `start()`; afterwards `poll()` returns `true`, `is_live()` is `false` and `result()` returns the work's value directly (a coroutine that never suspends because `checkpoint()` is a no-op returns its value, engine-validation claim 11).
- [ ] `TimeSlicedPlannerTask` with `slice_usec` from `runtime.slice_ms`: `start()` runs the coroutine until the first over-budget `checkpoint()`; each `poll()` resets the slice clock, resumes the coroutine synchronously via `_resume.emit()` and returns `_done`; the slice clock is an injected `clock: Callable` (default `Time.get_ticks_usec`); with a **scripted clock** that advances a fixed amount per `checkpoint()` call, the test asserts the coroutine yields at exactly the checkpoint where the scripted elapsed time first reaches `slice_usec`, and that `poll()` resumes it — no wall-clock assertion (testing standard: no time-dependent assertions; real slice length ≤ `slice_ms` + one evaluation is measured in the boss-ai perf job, Probe A 2.09–2.11 ms at 1,000-op chunks). *Revised 2026-11-03 per QA plan sprint 1.*
- [ ] `PlannerTask` is `@abstract` with `@abstract func start(work: Callable) -> void` and `@abstract func poll() -> bool`; a subclass missing an override fails to parse, `result()` returns `null` when the work errored, `is_live()` is `true` from `start()` until the task finished, and base `checkpoint()` is a plain no-op so `await planner.checkpoint()` returns immediately (the one `await` allowed under `src/ai/**`, gate G2b).
- [ ] `WorkerPoolPlannerTask.poll()` returns `false` while `is_task_completed(id)` is false, calls `wait_for_task_completion(id)` exactly once and then returns `true` on every later call without touching `WorkerThreadPool` (the id is released); the code path is proven by a fake-pool unit test here and by the real pool in Story 017 (`tests/unit/**` never starts a worker).

---

## Implementation Notes

*Derived from ADR-0006 Implementation Guidelines and Key Interfaces:*

- Files: `src/ai/planner_task.gd` (`@abstract class_name PlannerTask extends RefCounted`), `src/ai/worker_pool_planner_task.gd`, `src/ai/time_sliced_planner_task.gd`, `tests/helpers/immediate_planner_task.gd` (`class_name ImmediatePlannerTask`; the ADR places it with the test helpers because production never uses it). Shapes are given verbatim in ADR-0006 § Key Interfaces — copy them, including the `# poll BEFORE wait, never after` comment.
- `WorkerPoolPlannerTask.start`: `_task_id = WorkerThreadPool.add_task(_run.bind(work), false, "boss_ai")`; `_run(work)` sets `_result = work.call()` off-thread and touches only what `work` closes over (a clone, the `ai_<floor>` stream, the frozen `CardDatabase`). Keep the pool symbol inside `src/ai/*_planner_task.gd` only (ADR-0006 Validation Criteria grep gate; Story 012).
- `TimeSlicedPlannerTask`: `signal _resume`; `checkpoint()` awaits `_resume` when `_clock.call() - _slice_start_usec >= slice_usec` (`_clock` injected, default `Time.get_ticks_usec`), then `return`s; `_run(work)` is `_result = await work.call(); _done = true; _live = false`. `slice_usec` is injected from data (`runtime.slice_ms × 1000`), never a literal (A29).
- Every typed override ends in an explicit `return` (4.7 rule). Keep `checkpoint()` declared on the abstract base (dynamic dispatch) so a `REDUNDANT_AWAIT`-class warning cannot fire on the worker path.
- Unit-testing the worker-pool task without starting a worker: inject the pool calls behind three Callables (`add_task`, `is_task_completed`, `wait_for_task_completion`) defaulting to the `WorkerThreadPool` statics, and drive them with a scripted fake in the test; the real pool is exercised in Story 017's integration test.
- `Boot` selecting the implementation by `runtime.planner_mode` / `--ai-sync` belongs to the `boot-composition-root` epic; this story only exposes the three classes.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 008: `BossAI.plan_task(sandbox)` and the `await planner.checkpoint()` calls inside the planner loops.
- Story 015: `MatchDriver.tick()` polling and replay; `shutdown()`.
- Story 017: real `WorkerThreadPool` equivalence and the three-implementation determinism run.
- Story 018: Windows verification of `WorkerThreadPool`.

---

## Files

- `src/ai/planner_task.gd`
- `src/ai/worker_pool_planner_task.gd`
- `src/ai/time_sliced_planner_task.gd`
- `tests/helpers/immediate_planner_task.gd`
- `tests/unit/boss_ai/boss_ai_planner_task_test.gd`
- `.godot/global_script_class_cache.cfg` (regenerated by `--import`: the four new `class_name` entries)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/boss_ai/boss_ai_planner_task_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] Created — 30 test functions, passing (full suite exit 0, 2026-11-03)

---

## Dependencies

- Depends on: None inside this epic (needs ADR-0001's rules-tier conventions from the `boot-composition-root` epic only by convention, not by code)
- Unlocks: `production/epics/boss-ai-match-driver/story-008-plan-turn-loop-and-turn-plan.md`, `production/epics/boss-ai-match-driver/story-013-match-driver-construction-and-command-gate.md`, `production/epics/boss-ai-match-driver/story-017-planner-determinism-across-implementations.md`

---

## Completion Notes
**Completed**: 2026-11-03
**Criteria**: 4/4 passing (all in `tests/unit/boss_ai/boss_ai_planner_task_test.gd`) — AC-1 `::test_immediate_start_runs_coroutine_work_inside_start`, `::test_immediate_after_start_polls_true_not_live_and_returns_value`, `::test_immediate_is_live_while_work_runs`, `::test_immediate_before_start_polls_true_not_live_result_null`; AC-2 (scripted clock, no wall-clock assertion) `::test_time_sliced_start_yields_at_first_checkpoint_reaching_slice` (checkpoints at 250/500/750 return, the one at exactly 1000 suspends), `::test_time_sliced_poll_resets_slice_clock_and_resumes_synchronously`, `::test_time_sliced_final_poll_returns_true_with_value_not_live`, `::test_time_sliced_is_live_inside_every_slice`, `::test_time_sliced_poll_after_finish_returns_true_without_resuming`, `::test_time_sliced_work_under_one_slice_finishes_inside_start`, `::test_time_sliced_default_clock_runs_unreachable_slice_in_start`, `::test_time_sliced_constructor_takes_slice_budget`; AC-3 `::test_planner_task_script_reports_abstract`, `::test_planner_task_start_and_poll_are_abstract_and_the_rest_concrete`, `::test_planner_task_new_is_refused_at_parse_time`, `::test_subclass_missing_both_overrides_is_refused_at_parse_time`, `::test_subclass_missing_poll_override_is_refused_at_parse_time`, `::test_subclass_with_both_overrides_compiles`, `::test_base_checkpoint_returns_immediately_without_suspending`, `::test_*_errored_work_gives_null_result_and_finishes` (all three tasks); AC-4 (fake pool, no worker started) `::test_worker_start_submits_to_pool_at_normal_priority_as_boss_ai`, `::test_worker_poll_returns_false_while_task_not_completed`, `::test_worker_poll_waits_exactly_once_then_returns_true_with_value`, `::test_worker_polls_after_completion_never_touch_pool`, `::test_worker_before_start_polls_true_without_pool_calls`, `::test_worker_coroutine_work_returns_value_through_no_op_checkpoint`; plus `::test_same_work_gives_same_value_through_all_three_tasks`
**Deviations** (all ADVISORY):
- Shapes copied from ADR-0006 Key Interfaces with four additions the ACs need: the base declares `_result` / `_live` (the ADR's base reads them without declaring them); `ImmediatePlannerTask.start` sets `_live = true` before running the work (AC-3 "`is_live()` is `true` from `start()` until finished"); `TimeSlicedPlannerTask.poll` returns `true` when never started (`if _done or not _live`, matching the worker's `if not _live`), so all three agree on the QA plan's "poll() before start()" edge case; `WorkerPoolPlannerTask._init` takes the three pool calls as Callables defaulting to the real pool statics (story Implementation Notes).
- `TimeSlicedPlannerTask._init(budget_usec: int, clock: Callable = Time.get_ticks_usec)`: the caller converts `runtime.slice_ms × 1000`; no `ai_profiles.json` `runtime` block exists yet, and the composition-root selection belongs to the `boot-composition-root` epic.
- `_resume.emit()` in `src/ai/time_sliced_planner_task.gd` is the ADR's own shape; the manifest's "nothing in `src/ai/**` calls `signal.emit`" reads as public/subscriber signals. A private, self-connected resume signal is the one exception, and the signal name `_resume` (not past tense) is the ADR's.
- The QA plan's "subclass missing an override fails to parse" check is done in the suite by compiling source with `GDScript.reload()` (the `boot_meta_api_test.gd` precedent), not with `godot-parse-check.gd` on a fixture file.
- No worker test was placed under `tests/unit/**`: the story names none (the real pool is story 017's integration test), so nothing was moved.
**Test Evidence**: `tests/unit/boss_ai/boss_ai_planner_task_test.gd` (30 tests); full suite `commands.test` exit 0, 198 test cases, 0 failures, 0 orphans. Mutations observed failing (exit 100) then restored, one per run: poll() not resetting the slice clock; `>=` → `>` in `checkpoint()`; worker poll() without the `not _live` guard (polls after the wait); immediate start() without `_live = true`. ADR-0001 gates G1, G2, G2b (deny-list), G3, G6 over `src/ai/`: 0 hits; the pool symbol appears only in `src/ai/worker_pool_planner_task.gd`
**Run result**: N/A — three `RefCounted` classes with no scene, Node or rendered output and no caller yet (MatchDriver is story 013/015), so nothing a player can see changes
**Reviewed by**: self, no independent review (QL-TEST-COVERAGE skipped — Lean mode; LP-CODE-REVIEW skipped — Lean mode; `/code-review` not run; engine-specialist check NOT ASSESSED — no agent spawned)
