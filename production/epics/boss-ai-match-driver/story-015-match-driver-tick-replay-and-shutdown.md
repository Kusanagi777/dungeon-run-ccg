# Story 015: MatchDriver — tick(), bounded replay with checksum, match_ended and shutdown

> **Epic**: Boss AI + Match Driver
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-04

## Context

**GDD**: `design/gdd/boss-ai.md` C1.5 (2 ms per frame on the main thread), C9 (`ai_decision` on the same log, rule 12a) · `design/gdd/run-structure.md` Interactions "Boss AI" row
**Requirement**: `TR-boss-ai-003`, `TR-run-structure-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Boss AI Planner Threading (replay protocol, checksum, `replay_budget_ms`, `shutdown()`); ADR-0008 (Decisions 4, 5, 9: `tick()` contract, events reach the UI synchronously, lifetime); ADR-0003 (subscriber contract: once, in `seq` order, after append)
**ADR Decision Summary**: `tick()` once per frame: (a) if a task is live and `poll()` is true → `_on_task_done()`; (b) if a plan is pending → replay commands until exhausted or `replay_budget_ms` is spent (minimum one), carrying the rest; (c) return. Replay of one command = append its `ai_decision` (`cause_seq = 0`, `diagnostic: true`) then `engine.submit(cmd)` with `issuer = "boss"`, fold event types into the checksum, run `_after_engine_step()`; on `!accepted` or a final checksum mismatch → `ai_fault {reason: replay_divergence, at_index}` + `end_turn`. On `Ended`: drop any pending plan, `engine.end_match()`, emit the driver's own `match_ended` after the event reached subscribers. `shutdown()` blocks on `poll()` until a live task ends and discards its result.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH / NOT SOURCEABLE
**Engine Notes**: Frame pacing of `tick()` under a live task is NOT SOURCEABLE (Probe A measured headless frames at ≈ 6–7 ms, not 60 Hz) — A30 on the real `MatchView._process` is Story 018. `Time.get_ticks_usec()` for the replay budget is NOT SOURCEABLE (LOW; `Time` singleton is the sourced replacement for `OS.get_ticks_msec`). A `WorkerThreadPool` task cannot be cancelled, only awaited. `RefCounted` cycle teardown (`weakref` test) is NOT SOURCEABLE.

**Control Manifest Rules (this layer)**:
- Required: `MatchDriver.tick()` replays the commands into the live engine via `submit()` on the main thread, appending each `ai_decision` (`cause_seq = 0`, `diagnostic: true`) immediately before its command, and compares the event-type checksum after replay. `poll()` is called at most once per frame and never again after it returned `true`; replay is bounded by `replay_budget_ms` per tick (minimum one command) and carried to the next tick. On `Ended` the driver drops any pending plan, calls `engine.end_match()` and emits its own `match_ended(result)` only after the `match_ended` event has reached subscribers. `MatchDriver.shutdown()` blocks on `poll()` until a live task ends and discards its result; `MatchView._exit_tree` calls it. `subscribe(cb)` registers directly on the match `EventLog`; there is no event buffer.
- Forbidden: Never continue replaying after a rejected command or a checksum mismatch. Never connect `RulesEngine.match_ended` in production; never register a subscriber from a worker. Never call `WorkerThreadPool.is_task_completed` after `wait_for_task_completion`.
- Guardrail: Boss AI main thread ≤ 2 ms per frame — one `is_task_completed` per frame plus replay bounded by `replay_budget_ms` (data value governs; ADR-0006 default 2). Memory: one driver graph per attempt, no event buffer.

---

## Readiness (`/story-readiness`, by hand, 2026-11-04)

**READY, with three readings recorded here** (sprint 5 lane 1 wave 2). Tier: workflow standard. ADR-0003, ADR-0006 and ADR-0008 Accepted; TR-boss-ai-003 and TR-run-structure-005 active; story 013 Complete on this branch. Advisory: the story embeds Manifest Version 2026-11-03, the manifest is 2026-11-04.

- **The clock (QA plan gap, AC-1 and AC-4).** The design allows an injected clock: `TimeSlicedPlannerTask` already takes `clock: Callable = Time.get_ticks_usec`, and the coding standards ask for injection. `MatchDriver._init` gains the same optional fifth argument, so ADR-0008's four-argument call is unchanged and both criteria stay in the blocking suite with no wall-clock assertion.
- **The plan in these tests.** Story 014 owns the `BossTurn.Main` row and merges after this story, so tests start the task through `_start_plan_task()`.
- **`TurnPlan.checksum`** is already the shared static (story 008), so `turn_plan.gd` needs no change.

---

## Acceptance Criteria

*From ADR-0006 Implementation Guidelines / Verification and ADR-0008 Decisions 4–5, 9 and Validation Criteria, tracing boss-ai C1.5 / C9 and run-structure's "Boss AI" row:*

- [x] GIVEN a pending `TurnPlan` of N commands, WHEN `tick()` runs, THEN each replayed command is preceded by its `ai_decision` appended with `cause_seq = 0` and `payload.diagnostic = true`, submitted with `issuer = "boss"`, and followed by `_after_engine_step()`; replay stops when `replay_budget_ms` (from `config("ai_profiles").runtime`) is spent, having replayed at least one command, and resumes on the next `tick()`; `is_planning()` is `true` until the plan is exhausted; `poll()` is invoked at most once per `tick()` and never after it returned `true`.
- [x] GIVEN a plan whose command k is rejected by the live engine, or whose final event-type checksum differs from `TurnPlan.expected_checksum`, WHEN replay reaches it, THEN `ai_fault {reason: replay_divergence, at_index: k}` is appended, `end_turn` is submitted, no further plan command is replayed and the match continues.
- [x] GIVEN the live engine reaches `Ended` (by a replayed command, a player command or a concede), WHEN `_after_engine_step()` sees it, THEN any pending plan is dropped, `engine.end_match()` runs (resolver `unbind`), the driver's `match_ended(result)` fires only after a subscriber registered via `subscribe()` has already received the `match_ended` event, the driver accepts nothing further, and `RulesEngine.match_ended` has no connections.
- [x] GIVEN a live fake task, WHEN `shutdown()` is called, THEN it returns only after `poll()` is `true` and the result is discarded; afterwards the driver graph (driver → engine ↔ resolver, `BossAI`, task, match log) is freed once the last strong reference is dropped (`weakref` test), and `MatchDriver.tick()` in debug builds self-times and appends `ai_fault {reason: tick_over_budget}` when its own work exceeds the budget.

---

## Implementation Notes

*Derived from ADR-0006 and ADR-0008 Implementation Guidelines:*

- Extend `src/gameplay/run/match_driver.gd`: `tick()`, `_replay_some()`, `_checksum: int` (FNV-1a over event types, same function `TurnPlan` uses — expose it as a static on `src/ai/turn_plan.gd` so both sides share one implementation), `shutdown()`, the `Ended` row of `_after_engine_step()`, `hooks()` read-after-`Ended`.
- Budget read once at construction from `db.config("ai_profiles").runtime.replay_budget_ms` (data governs; the ADR-0008 Performance "4" is superseded by the file value).
- Self-timing: `Time.get_ticks_usec()` around the driver's own work (poll + replay bookkeeping, not subscriber time — that is Match UI's budget); debug-only (`OS.is_debug_build()`).
- `end_match()` then `match_ended.emit(result)`; detect `Ended` by polling `phase()` after each step. `RunMachine` connects first (`run-structure` epic); the test asserts ordering with two subscribers.
- Test path: `tests/integration/match_driver/match_driver_replay_test.gd` — it exercises the live `RulesEngine`, `EventLog` subscribers and the `match_ended` boundary with `ImmediatePlannerTask` and a fake task for the live-task cases; never a worker.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 013 / 014: construction, gate, schedule.
- Story 017: real `WorkerThreadPool` through this replay path.
- Story 018: A30 frame timing on the real view.
- `match-ui` epic: `MatchController.tick()` call site and `MatchView._exit_tree → shutdown()`.
- `run-structure` epic: `match_handoff_test.gd`.

---

## Files

*The code and test files this story changed.*

- `src/gameplay/run/match_driver.gd`
- `tests/integration/match_driver/match_driver_replay_test.gd`
- `tests/unit/match_driver/match_driver_gate_test.gd` (teardown now through `shutdown()`)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/match_driver/match_driver_replay_test.gd` OR playtest doc — the test is required here (the behaviours are deterministic and headless)

**Status**: [x] Created, 37 test cases passing

---

## Dependencies

- Depends on: `production/epics/boss-ai-match-driver/story-013-match-driver-construction-and-command-gate.md`
- Unlocks: `production/epics/boss-ai-match-driver/story-016-sim-harness.md`, `production/epics/boss-ai-match-driver/story-017-planner-determinism-across-implementations.md`

---

## Completion Notes
**Completed**: 2026-11-05 (start 00:57 UTC, end 01:07 UTC; sprint 5 lane 1 wave 2, branch `s5/l1-w2`)
**Criteria**: 4/4 in `match_driver_replay_test.gd`. The `weakref` teardown, marked NOT SOURCEABLE, was observed to hold on 4.7.2 headless for a live match and for an ended one, with the sandbox in the graph.
**Tests seen failing**: the suite ran first against the story 013 driver and failed to parse (exit 105: no `FAULT_REPLAY_DIVERGENCE`, too many arguments for `new()`). An earlier attempt at that run tested nothing, because the directory did not exist, and it was redone. Then 30 deliberate mutants of `match_driver.gd`. 28 died at once; `plan_kept_at_ended` and `ended_task_still_replays` survived, because one test ticked before asserting and another used an empty plan. Both tests were tightened and both mutants then died. Two tests were added beforehand for paths found by reading the code: a poll that spends the budget still replays one command, and a tick that ends the match appends nothing after it. `diff` against a saved copy confirmed no mutant was left.
**Verification**: import exit 0; `gates.sh` (G1 to G7, 0 hits), `no_global_rng.sh`, `parse-check.sh` exit 0; `commands.test` 1783 test cases, 0 errors, 0 failures, 0 orphans, exit 0, `SCRIPT ERROR` lines unchanged from story 013 at 88; `godot --headless --quit-after 5` exit 0, no `SCRIPT ERROR`.
**Run result**: N/A: nothing reaches the screen. Real boss turns did run: six rounds on the shipped data through `BossAI.plan_task` and `ImmediatePlannerTask` replay with no `ai_fault` and no `command_rejected`, and one seed gives a byte-identical `EventLog.to_json()`.
**Deviations** (advisory):
- **`_init` has an optional fifth argument, `clock`.** An addition to ADR-0008's Key Interfaces, not yet written there.
- **`at_index` of a final checksum mismatch is `commands.size()`.** The AC names a `k` that does not exist for a mismatch found at the end. This is `TurnPlan`'s own "past the last command" index. A reading, to confirm.
- **`tick_over_budget` compares with `replay_budget_ms`,** the one value in the data, and the driver's own work excludes time inside `engine.submit` and `log.append`: the note excludes subscriber time, which runs inside both, and ADR-0006 calls a slow `submit` engine time. A time-sliced `poll()` counts, so that planner can raise it near `slice_ms`.
- **`ai_fault {tick_over_budget}` depends on the wall clock,** so a debug log that carries one is not byte-identical to another run. Checksums skip it. Release builds never append it.
- **`end_turn` after a whole plan is refused.** The AC says it is submitted, so it is; if the plan's own `end_turn` already ran, the engine answers `NOT_YOUR_TURN` and logs one `command_rejected` with `side = boss`.
- **`shutdown()` also calls `engine.end_match()`,** which AC-4 needs: a match left unfinished still holds the engine and resolver in a cycle. A queued concede is discarded with the task.
- **A refused diagnostic append calls `engine.fault(event_cap)`.** Not in the story; ADR-0003 Decision 8 requires the log's overflow to be answered, and only the engine's own `emit` did so.
- **A `null` task result is ignored.** The work errored, and no document says what the boss does next. Story 014's `_on_task_done()` owns the dispatch.
**Limits of the replay test**: it proves the live engine matches the clone and that a seed repeats within one tree. It does not pin a log across commits; MR-019's goldens do that.
