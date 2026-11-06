# Story 014: MatchDriver — phase schedule: forecast, plan and choose tasks, stale premise, telegraph setting

> **Epic**: Boss AI + Match Driver
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-05
> **Readiness**: READY (2026-11-05, by hand: stories 010, 011, 013, 015 merged; ADR-0006 and ADR-0008 Accepted; DD-X31 overrides AC-2's single task and AC-3's choose task, and review Q-1 to Q-4 are settled by it or by ADR-0006, see Completion Notes)

## Context

**GDD**: `design/gdd/run-structure.md` Interactions "Boss AI" row (the driver calls `forecast` / `play_turn` / `choose` at Match Rules' phase transitions) · `design/gdd/boss-ai.md` C1.4, C8.1, Edge Cases "Choice raised during the player's turn for the boss"
**Requirement**: `TR-run-structure-005`, `TR-boss-ai-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008: Match Driver Ownership and the Run ↔ Match ↔ UI Hand-off (Decisions 3, 4 `_on_task_done`, 7); ADR-0006 (forecast tasks have no gate; a stale forecast is discarded; task Callable built by `BossAI.plan_task`)
**ADR Decision Summary**: `_after_engine_step()` runs after every engine step and replayed command and reads `phase()` / `active_side()` / `pending_choice()`: `PlayerTurn.Main` with no forecast for this turn → clone + forecast task; `BossTurn.Main` with no plan pending → clone + plan task; boss `Choice` with no task live → clone + choose task then `submit(choose{issuer: boss})` on the main thread; anything else → wait. Every Boss AI entry point runs only through `PlannerTask.start`. `_on_task_done()` discards a stale premise silently. `telegraph_mode` is applied immediately when no task is live, else deferred.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH / NOT SOURCEABLE
**Engine Notes**: Erratum 2026-11-03 — the plan task Callable is `boss_ai.plan_task(sandbox, planner_task)` (returns `func() -> Variant: return await boss_ai.plan_turn(sandbox)`); the driver never writes `await`. Forecast and choose task Callables follow the same pattern (`BossAI.forecast_task(sandbox, planner_task)`, `BossAI.choose_task(sandbox, pending, planner_task)` built in `src/ai/`; the task is required, as on `plan_task`, and both landed with story 011: 2026-11-05, BAI-008 D-1). Concurrent read-only `CardDatabase` access during a forecast is NOT SOURCEABLE (Story 017).

**Control Manifest Rules (this layer)**:
- Required: `_after_engine_step()` runs after every engine step and every replayed command and reads `phase()` / `active_side()` / `pending_choice()` to schedule forecast, plan or choose tasks. `forecast` runs on a clone at `PlayerTurn.Main` with no gate on player input; a stale premise (`turn` / `phase` moved since the clone) is discarded silently; `ai_intent_shown` is appended by the driver on the main thread. Boss `Choice` with no task live → task `boss_ai.choose(sandbox, pending) -> int`, then `engine.submit(choose{issuer: boss, option_index})` on the main thread. Settings: `telegraph_mode` applied via `on_setting_changed` → `boss_ai.set_telegraph_mode` when no task is live, else deferred to `_on_task_done()`; no other key reaches the rules.
- Forbidden: Never invoke a Boss AI entry point inline from `submit` or `tick` — only through `PlannerTask.start`. The worker is never handed the live `RulesEngine`, the live `EventLog`, `MatchDriver`, `MatchView`, `Boot` or any `Node`.
- Guardrail: Forecast doubles the per-round worker cost off-thread; nothing on the main thread beyond one poll.

---

## Acceptance Criteria

*From ADR-0008 Decisions 3, 4, 7 and Validation Criteria (`match_driver_schedule_test`), tracing TR-run-structure-005 and boss-ai C1.4:*

- [x] GIVEN `PlayerTurn.Main` begins for `engine.turn = t`, WHEN `_after_engine_step()` runs (and again after further player commands in the same turn), THEN exactly one forecast task is started for turn `t` with `sandbox = engine.clone()`; WHEN it completes with the engine still in `PlayerTurn.Main` of turn `t`, THEN `ai_intent_shown` is appended on the main thread (unless `effective_mode = hidden`); WHEN the player ended the turn first, THEN the result is discarded and nothing is appended.
- [x] GIVEN `BossTurn.Main` with no plan pending, WHEN `_after_engine_step()` runs, THEN a plan task (a fresh task from the factory: 2026-11-04, DD-X31) is started through `planner_task.start(boss_ai.plan_task(engine.clone(), planner_task))` (the task is required: `checkpoint()` yields on it; code review 2026-11-04, BAI-008 D-1) and no `BossAI` method is called inline from `submit` or `tick`; the worker receives only the clone, the `ai_<floor>` stream and the frozen `CardDatabase`.
- [x] **(2026-11-04, DD-X31; was a `choose` task)** GIVEN a player action raises a boss `Choice` (`pending_choice.side == "boss"`) with no task live and no plan pending, WHEN `_after_engine_step()` runs, THEN a **plan** task starts on a clone, its plan opens with the `choose`, and the replay submits it on the main thread and `_after_engine_step()` runs again; a Choice raised by a replayed command starts no task: the plan pending holds its `choose`.
- [x] **(2026-11-04, DD-X31)** GIVEN a task whose premise held returns null, or a plan with no commands, WHEN `_on_task_done()` runs, THEN `ai_fault` is logged and the boss's turn ends safely, and the match never hangs.
- [x] GIVEN `on_setting_changed("telegraph_mode", v)`, WHEN no task is live, THEN `boss_ai.set_telegraph_mode(v)` is called immediately; WHEN a task is live, THEN it is applied in `_on_task_done()` before the next task starts; any other key is ignored by the driver.

---

## Implementation Notes

*Derived from ADR-0008 Implementation Guidelines and Decision 3's table:*

- Extend `src/gameplay/run/match_driver.gd` (Story 013): `_after_engine_step()` implements the four-row table verbatim; `_start_task(kind, work: Callable, premise: {turn, phase})`; `_on_task_done()`: read `result()` once; queued concede → discard, submit concede; stale premise → discard; forecast → `boss_ai.note_forecast(intent)` + append `ai_intent_shown` if `effective_mode != hidden`; boss choice → submit; `TurnPlan` → set pending plan (replay is Story 015). Apply `_telegraph_pending` here.
- `src/ai/boss_ai.gd` already has `forecast_task(sandbox, planner) -> Callable`, `choose_task(sandbox, pending, planner) -> Callable` and `note_forecast(intent)`, siblings of `plan_task` (the erratum's `await` shape lives in `src/ai/`). They landed with story 011 (2026-11-05, wave-1 review): this story calls them. A choose task's result is the index; its decision is `BossAI.last_choice`.
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
- `src/ai/boss_ai.gd`, `src/ai/scorer.gd` (doc), `src/ai/planner_task.gd`, `src/ai/time_sliced_planner_task.gd`
- `tests/unit/match_driver/match_driver_schedule_test.gd` (new)
- `tests/unit/match_driver/match_driver_gate_test.gd`, `tests/integration/match_driver/match_driver_replay_test.gd`
- `tests/unit/boss_ai/boss_ai_choose_test.gd`, `boss_ai_plan_turn_test.gd`, `boss_ai_plan_task_shape_test.gd`
- `tests/helpers/match_driver_fixture.gd`, `tests/helpers/fake_planner_task.gd`
- `docs/architecture/adr-0008-match-driver-ownership-and-handoff.md`, `adr-0006-boss-ai-planner-threading.md`, `design/gdd/boss-ai.md`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/match_driver/match_driver_schedule_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] Created: 47 test cases, passing

---

## Dependencies

- Depends on: `production/epics/boss-ai-match-driver/story-013-match-driver-construction-and-command-gate.md`, `production/epics/boss-ai-match-driver/story-010-choice-phase.md`, `production/epics/boss-ai-match-driver/story-011-forecast-and-telegraphing.md`
- Unlocks: `production/epics/boss-ai-match-driver/story-016-sim-harness.md`

---

## Completion Notes
**Completed**: 2026-11-05 (start 04:10 UTC, end 05:13 UTC; sprint 5 lane 2 wave 3, branch `s5/l2-w3`)
**Criteria**: 5/5 in `match_driver_schedule_test.gd`, AC-2 and AC-3 as DD-X31 changed them, plus the DD-X31 fault criterion. Closed here from earlier stories: BAI-013 AC-1's "first forecast after the mulligan" (`test_no_task_runs_in_the_mulligan_and_one_forecast_starts_after_it`) and A19's append (`test_a19_*`, five tests through the driver on the real planner).
**Tests seen failing**: the schedule suite first failed on missing code (exit 105, no `FAULT_NULL_RESULT`). Then 42 deliberate mutants of `match_driver.gd` and `boss_ai.gd`: 39 killed first time (two by hanging: an empty plan replayed, a forecast on every step). `shutdown_keeps_scheduling` and `plan_draws_overwritten` survived because the tests were weak (a shutdown at the player's Main, where nothing would be scheduled; a Discover whose options collapse with no draw); both tests were tightened and both mutants then died. `null_forecast_gives_up` survives as an equivalent mutant: at the player's Main `_give_up` does only what `_append_fault` does. `diff` against saved copies confirmed no mutant was left.
**Verification**: import, `gates.sh`, `no_global_rng.sh`, `parse-check.sh` exit 0; `commands.test` Overall Summary 2125 test cases, 0 errors, 0 failures, 0 orphans, exit 0; `commands.smoke` exit 0, no `SCRIPT ERROR`.
**Run result**: N/A: nothing reaches the screen until MUI-004. Real boss turns ran through the schedule alone: `test_the_boss_takes_its_turns_with_nothing_but_commands_and_ticks` and the shipped-data matches in `match_driver_replay_test.gd`, which no longer start a task by hand.

**Deviations** (advisory; a DD row beats the story):
- **A boss Choice with no plan pending starts a plan task.** DD-X31 drops the choose task because "choices are answered inside the plan", but on the player's turn, or from a boss Start step, no plan exists, and with the row gone the match would hang on `CHOICE_PENDING` (boss-ai Edge Cases, `test_a_boss_choice_raised_on_the_players_turn_returns_to_the_players_main`). So the row stays and starts a plan, and `plan_turn` opens by answering. On the player's turn the plan is the `choose` alone: no `sim_<turn>` fork, no intent committed, the forecast unspent. This keeps DD-X31's sentence and "never hang" both true; **the owner should confirm this reading**.
- **`BossAI.choose_task` is removed**, its behaviour tests moved onto `plan_task` rather than dropped, and the shape test now asserts it is gone.
- **A boss Choice is closed on its first option when the planner failed to answer it**, before `end_turn`, which the engine refuses during a Choice. `_diverge` does the same (review Q-3). A null forecast is the fault alone: no boss turn exists to end.
- **New `ai_fault.reason` values**: `null_result`, `empty_plan` (driver), `choice_unanswered` (planner). Recorded in the boss-ai Edge Cases.
- **`test_a_plan_with_no_commands_is_done_at_once` asserted the silence DD-X31 removes.** It is now `test_a_plan_with_no_commands_is_a_fault_and_the_boss_turn_ends`.
- **Existing suites changed for the schedule**: `is_planning()` is true during a forecast, so five assertions read `_pending_plan` where they meant "the plan is over", and `test_a_player_lethal_ends_the_match` ticks once to collect the forecast. Two concede tests call `_release_task()` to keep their "no task live" premise. `to_boss_main` ticks once, and `start_plan` scripts the running task instead of starting one, as its own doc said it would; shared helpers otherwise only gained additions.
- **`tick_over_budget` (review Q-4), settled by ADR-0006**: `slice_ms` bounds the slice and `replay_budget_ms` bounds replay, so a time-sliced `poll()` no longer counts as the driver's own work, and neither do a task's `clone()` and `start()`. Worker polls still count. New `PlannerTask.slices_main_thread()`.
- **A premise is `{turn, side, phase}`**: `PHASE_MAIN` names both sides' Main, so `turn` and `phase` alone would not see a side change.
- **`shutdown()` sets `_ended`**, so nothing is scheduled on a torn-down engine (review N-5).
- A plan that stops at the boss's Main with commands replayed lets the row plan again, verbatim from ADR-0008. An empty plan ends that, and `event_cap` is the floor if the engine ever refused `end_turn`.

**Assumed for `driver_factory`** (not built): it passes `Callable() -> PlannerTask`, a new task of the `runtime.planner_mode` implementation per call, and `TimeSlicedPlannerTask.new(int(slice_ms * 1000))` for that mode. The settings snapshot carries `telegraph_mode` under that key.

**Open, for the owner**:
- `kept` with no forecast is `false`, so a player who ends the turn before the forecast returns gets "plan changed" with no banner shown (BAI-011's open item; left as it is).
- A plan re-run after the player's Choice on the boss's turn commits a second `ai_intent_committed`, with `kept` false.
- At `slice_ms` 2 a slice runs 2.09-2.11 ms (Probe A), so the time-sliced fallback cannot meet A30's 2 ms. ADR-0006's Tuning note proposed 1.5; F9 says 2.
- `docs/architecture/control-manifest.md` still lists choose tasks (line 199, and the story's quoted rule): it needs regenerating from the ADR errata. `design/gdd/run-structure.md` rows 429 and 719 still say the driver calls `choose`.

**Test Evidence**: `tests/unit/match_driver/match_driver_schedule_test.gd`
**Reviewed by**: pending, the orchestrator's independent review at M3.
