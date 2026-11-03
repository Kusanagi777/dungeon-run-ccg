# Story 015: MatchDriver — tick(), bounded replay with checksum, match_ended and shutdown

> **Epic**: Boss AI + Match Driver
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

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

## Acceptance Criteria

*From ADR-0006 Implementation Guidelines / Verification and ADR-0008 Decisions 4–5, 9 and Validation Criteria, tracing boss-ai C1.5 / C9 and run-structure's "Boss AI" row:*

- [ ] GIVEN a pending `TurnPlan` of N commands, WHEN `tick()` runs, THEN each replayed command is preceded by its `ai_decision` appended with `cause_seq = 0` and `payload.diagnostic = true`, submitted with `issuer = "boss"`, and followed by `_after_engine_step()`; replay stops when `replay_budget_ms` (from `config("ai_profiles").runtime`) is spent, having replayed at least one command, and resumes on the next `tick()`; `is_planning()` is `true` until the plan is exhausted; `poll()` is invoked at most once per `tick()` and never after it returned `true`.
- [ ] GIVEN a plan whose command k is rejected by the live engine, or whose final event-type checksum differs from `TurnPlan.expected_checksum`, WHEN replay reaches it, THEN `ai_fault {reason: replay_divergence, at_index: k}` is appended, `end_turn` is submitted, no further plan command is replayed and the match continues.
- [ ] GIVEN the live engine reaches `Ended` (by a replayed command, a player command or a concede), WHEN `_after_engine_step()` sees it, THEN any pending plan is dropped, `engine.end_match()` runs (resolver `unbind`), the driver's `match_ended(result)` fires only after a subscriber registered via `subscribe()` has already received the `match_ended` event, the driver accepts nothing further, and `RulesEngine.match_ended` has no connections.
- [ ] GIVEN a live fake task, WHEN `shutdown()` is called, THEN it returns only after `poll()` is `true` and the result is discarded; afterwards the driver graph (driver → engine ↔ resolver, `BossAI`, task, match log) is freed once the last strong reference is dropped (`weakref` test), and `MatchDriver.tick()` in debug builds self-times and appends `ai_fault {reason: tick_over_budget}` when its own work exceeds the budget.

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

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/gameplay/run/match_driver.gd`
- `src/ai/turn_plan.gd` (shared checksum static)
- `tests/integration/match_driver/match_driver_replay_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/match_driver/match_driver_replay_test.gd` OR playtest doc — the test is required here (the behaviours are deterministic and headless)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/boss-ai-match-driver/story-013-match-driver-construction-and-command-gate.md`
- Unlocks: `production/epics/boss-ai-match-driver/story-016-sim-harness.md`, `production/epics/boss-ai-match-driver/story-017-planner-determinism-across-implementations.md`
