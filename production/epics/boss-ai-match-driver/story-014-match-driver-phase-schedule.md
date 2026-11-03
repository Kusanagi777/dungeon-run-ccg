# Story 014: MatchDriver — phase schedule: forecast, plan and choose tasks, stale premise, telegraph setting

> **Epic**: Boss AI + Match Driver
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/run-structure.md` Interactions "Boss AI" row (the driver calls `forecast` / `play_turn` / `choose` at Match Rules' phase transitions) · `design/gdd/boss-ai.md` C1.4, C8.1, Edge Cases "Choice raised during the player's turn for the boss"
**Requirement**: `TR-run-structure-005`, `TR-boss-ai-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008: Match Driver Ownership and the Run ↔ Match ↔ UI Hand-off (Decisions 3, 4 `_on_task_done`, 7); ADR-0006 (forecast tasks have no gate; a stale forecast is discarded; task Callable built by `BossAI.plan_task`)
**ADR Decision Summary**: `_after_engine_step()` runs after every engine step and replayed command and reads `phase()` / `active_side()` / `pending_choice()`: `PlayerTurn.Main` with no forecast for this turn → clone + forecast task; `BossTurn.Main` with no plan pending → clone + plan task; boss `Choice` with no task live → clone + choose task then `submit(choose{issuer: boss})` on the main thread; anything else → wait. Every Boss AI entry point runs only through `PlannerTask.start`. `_on_task_done()` discards a stale premise silently. `telegraph_mode` is applied immediately when no task is live, else deferred.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH / NOT SOURCEABLE
**Engine Notes**: Erratum 2026-11-03 — the plan task Callable is `boss_ai.plan_task(sandbox)` (returns `func() -> Variant: return await boss_ai.plan_turn(sandbox)`); the driver never writes `await`. Forecast and choose task Callables follow the same pattern (`BossAI.forecast_task(sandbox)`, `BossAI.choose_task(sandbox, pending)` built in `src/ai/`). Concurrent read-only `CardDatabase` access during a forecast is NOT SOURCEABLE (Story 017).

**Control Manifest Rules (this layer)**:
- Required: `_after_engine_step()` runs after every engine step and every replayed command and reads `phase()` / `active_side()` / `pending_choice()` to schedule forecast, plan or choose tasks. `forecast` runs on a clone at `PlayerTurn.Main` with no gate on player input; a stale premise (`turn` / `phase` moved since the clone) is discarded silently; `ai_intent_shown` is appended by the driver on the main thread. Boss `Choice` with no task live → task `boss_ai.choose(sandbox, pending) -> int`, then `engine.submit(choose{issuer: boss, option_index})` on the main thread. Settings: `telegraph_mode` applied via `on_setting_changed` → `boss_ai.set_telegraph_mode` when no task is live, else deferred to `_on_task_done()`; no other key reaches the rules.
- Forbidden: Never invoke a Boss AI entry point inline from `submit` or `tick` — only through `PlannerTask.start`. The worker is never handed the live `RulesEngine`, the live `EventLog`, `MatchDriver`, `MatchView`, `Boot` or any `Node`.
- Guardrail: Forecast doubles the per-round worker cost off-thread; nothing on the main thread beyond one poll.

---

## Acceptance Criteria

*From ADR-0008 Decisions 3, 4, 7 and Validation Criteria (`match_driver_schedule_test`), tracing TR-run-structure-005 and boss-ai C1.4:*

- [ ] GIVEN `PlayerTurn.Main` begins for `engine.turn = t`, WHEN `_after_engine_step()` runs (and again after further player commands in the same turn), THEN exactly one forecast task is started for turn `t` with `sandbox = engine.clone()`; WHEN it completes with the engine still in `PlayerTurn.Main` of turn `t`, THEN `ai_intent_shown` is appended on the main thread (unless `effective_mode = hidden`); WHEN the player ended the turn first, THEN the result is discarded and nothing is appended.
- [ ] GIVEN `BossTurn.Main` with no plan pending, WHEN `_after_engine_step()` runs, THEN a plan task is started through `planner_task.start(boss_ai.plan_task(engine.clone()))` and no `BossAI` method is called inline from `submit` or `tick`; the worker receives only the clone, the `ai_<floor>` stream and the frozen `CardDatabase`.
- [ ] GIVEN a player action raises a boss `Choice` (`pending_choice.side == "boss"`) with no task live, WHEN `_after_engine_step()` runs, THEN a `choose` task starts on a clone and, on return, `engine.submit(choose{issuer: boss, option_index})` is called on the main thread and `_after_engine_step()` runs again; a Choice raised by a replayed command is handled the same way.
- [ ] GIVEN `on_setting_changed("telegraph_mode", v)`, WHEN no task is live, THEN `boss_ai.set_telegraph_mode(v)` is called immediately; WHEN a task is live, THEN it is applied in `_on_task_done()` before the next task starts; any other key is ignored by the driver.

---

## Implementation Notes

*Derived from ADR-0008 Implementation Guidelines and Decision 3's table:*

- Extend `src/gameplay/run/match_driver.gd` (Story 013): `_after_engine_step()` implements the four-row table verbatim; `_start_task(kind, work: Callable, premise: {turn, phase})`; `_on_task_done()`: read `result()` once; queued concede → discard, submit concede; stale premise → discard; forecast → `boss_ai.note_forecast(intent)` + append `ai_intent_shown` if `effective_mode != hidden`; boss choice → submit; `TurnPlan` → set pending plan (replay is Story 015). Apply `_telegraph_pending` here.
- Add to `src/ai/boss_ai.gd`: `forecast_task(sandbox) -> Callable` and `choose_task(sandbox, pending) -> Callable`, siblings of `plan_task` (the erratum's `await` shape lives in `src/ai/`).
- "No forecast started for `engine.turn`" is a field `_forecast_turn`; reset when the turn advances.
- Tests drive a fake `PlannerTask` whose `poll()` answers are scripted so the test controls when the task "returns" relative to player commands; assert through the `TestEventLog` double and spies on `BossAI` entry points. Path: `tests/unit/match_driver/match_driver_schedule_test.gd` (ADR-0008 names `tests/unit/run/`; see Story 013 note).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 015: `tick()` polling, replay of a `TurnPlan`, checksum, `Ended` row, `shutdown()`.
- Story 011: the content of `Intent` and `effective_mode`.
- `match-ui` epic: `MatchController.on_setting_changed` pass-through and `MatchView` forwarding `settings_changed`.

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/gameplay/run/match_driver.gd`
- `src/ai/boss_ai.gd` (`forecast_task`, `choose_task`)
- `tests/unit/match_driver/match_driver_schedule_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/match_driver/match_driver_schedule_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/boss-ai-match-driver/story-013-match-driver-construction-and-command-gate.md`, `production/epics/boss-ai-match-driver/story-010-choice-phase.md`, `production/epics/boss-ai-match-driver/story-011-forecast-and-telegraphing.md`
- Unlocks: `production/epics/boss-ai-match-driver/story-016-sim-harness.md`
