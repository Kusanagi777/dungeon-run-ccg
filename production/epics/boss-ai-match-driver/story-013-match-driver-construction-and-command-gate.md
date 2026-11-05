# Story 013: MatchDriver — construction order, command gate and the concede slot

> **Epic**: Boss AI + Match Driver
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-04

## Context

**GDD**: `design/gdd/run-structure.md` Interactions "Boss AI" row (Run Structure owns the match driver; rules-side code wrapped by `MatchController`) · `design/gdd/boss-ai.md` C1.1 (constructed per match with `(boss_def, resolved_profile, band, ai_stream, op_values)`)
**Requirement**: `TR-run-structure-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008: Match Driver Ownership and the Run ↔ Match ↔ UI Hand-off (Decisions 1, 2); ADR-0006 (the queued concede discards the plan unreplayed)
**ADR Decision Summary**: One `MatchDriver` per match attempt, built by `driver_factory.call(config)` from `RunMachine.begin_match`; `_init(config, db, settings, planner_task)` builds `ProfileResolver.resolve` → `EffectResolver` → `RulesEngine` → `BossAI` → `engine.start(config)` → `_after_engine_step()`. `submit()` is the only path from outside the rules tier into `RulesEngine.submit`, stamps `issuer = "player"`, runs synchronously on the main thread; the engine itself answers `NOT_YOUR_TURN` / `CHOICE_PENDING` during a boss task; a `concede` while a task is live is queued in one slot (`ENGINE_BUSY / concede_queued`) and applied in `_on_task_done()` after the plan is discarded.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (by version; the driver's own APIs — `RefCounted`, `signal` on a `RefCounted`, `Callable`, `Dictionary` — have no post-cutoff change)
**Engine Notes**: Lambdas capture locals by value (sourced) — the queued concede, replay cursor and event cursor live in instance fields, never captured locals. `@abstract PlannerTask` is the seam the driver depends on (Story 001). `match_driver.gd` stays `await`-free: it calls `boss_ai.plan_task(sandbox)` and never `plan_turn` directly (erratum).

**Control Manifest Rules (this layer)**:
- Required: `MatchDriver` lives in `src/gameplay/run/`, obeys the rules tier (no Node, no autoload, no `await`), is the only caller of `RulesEngine.submit` from outside the rules tier, and stamps `issuer = "player"` on UI commands and `issuer = "boss"` on replayed plan commands. `MatchDriver._init(config, db, settings, planner_task)` builds, in order: `ProfileResolver.resolve(...)` → `EffectResolver.new(db, db.config("card_effects"))` → `RulesEngine.new(db, db.config("match_rules"), resolver)` → `BossAI.new(boss_def, resolved_profile, band, config.rng_ai, op_values, config.log)` → `engine.start(config)` → `_after_engine_step()`. A `concede` that arrives while a task is live is queued in a single slot and returns `{accepted: false, rejection: {code: ENGINE_BUSY, detail: "concede_queued"}}`; `_on_task_done()` discards the task's result before submitting it. `query() -> MatchQuery` is built once over the live engine and answers at all times; `is_planning()` is a UI hint, not a lock.
- Forbidden: Never Match UI owns the driver. Never `RulesEngine` drives the boss itself. Never invoke a Boss AI entry point inline from `submit` or `tick`. `MatchController` holds nothing but the driver reference.
- Guardrail: `RulesEngine.submit()` ≤ 5 ms worst case; the driver adds bookkeeping only.

---

## Readiness (`/story-readiness`, by hand, 2026-11-04)

**READY, with four readings recorded here** (sprint 5 lane 1 wave 2). Tier: workflow standard. ADR-0006 and ADR-0008 Accepted; TR-run-structure-005 active; stories 001, 002 and 008 Complete; `story-facts.sh --lint` clean. Advisory: the story embeds Manifest Version 2026-11-03, the manifest is 2026-11-04. Each reading below is settled by the docs; none is a new rule.

- **`player_hero_set`.** AC-1 and the embedded manifest rule omit it. F4 and the ADR-0008 erratum 2026-11-04 win: the driver passes it, read from the `HeroDef` of `config.player.hero_def_id` (`MatchConfig` carries no set).
- **First forecast.** AC-1 reads as if construction schedules it, but C3 stops at `Mulligan`. C3 wins for the timing. The story's Out of Scope gives the forecast row to story 014, and `BossAI` has no `forecast` until story 011, so here the half that can be tested is "no task after construction". "One after the mulligan" is **NOT ASSESSED until story 014**.
- **"Spy-recorded" order.** The seam is one overridable method per construction step, so a test subclass records them. Nothing production-only was added.
- **`MatchQuery`.** The story requires `query()`, MUI-003 creates the class in W3, and `match_driver.gd` has no other editor than story 014 in W3. So this story creates the file at the path the ADR-0008 erratum names, with the three engine pass-throughs, and passes `db` and `settings` so that MUI-003 need not touch the driver.

---

## Acceptance Criteria

*From ADR-0008 Decisions 1–2 and Validation Criteria (`match_driver_gate_test`), tracing run-structure's Interactions "Boss AI" row (TR-run-structure-005):*

- [x] GIVEN a `MatchConfig`, a `CardDatabase` double, a settings snapshot and a fake `PlannerTask`, WHEN `MatchDriver.new(config, db, settings, planner_task)` runs, THEN it constructs `ProfileResolver.resolve`, `EffectResolver`, `RulesEngine`, `BossAI` and calls `engine.start(config)` in that order (spy-recorded), then `_after_engine_step()` schedules the first forecast at `PlayerTurn.Main`; `legal_commands()` and `events_since(seq)` are pass-throughs and `subscribe(cb)` registers directly on the match `EventLog` (no buffer).
- [x] GIVEN a boss-turn task that stays live, WHEN the UI calls `submit(play_card)`, THEN the command reaches the live engine with `issuer = "player"` and the engine answers `NOT_YOUR_TURN` (`CHOICE_PENDING` during a boss Choice); no driver-side lock exists and `query()` still answers.
- [x] GIVEN the same live task, WHEN `submit(concede)` arrives, THEN the result is `{accepted: false, rejection: {code: ENGINE_BUSY, detail: "concede_queued"}, events: [-1, -1]}`; a second concede does not grow the slot; after `poll()` returns true the plan is discarded unreplayed, the concede is applied and `match_ended{reason: concede}` is emitted with no boss command in the log.
- [x] GIVEN no task live and a plan partly replayed, WHEN `submit(concede)` arrives, THEN it goes straight to the engine, the in-flight boss command has already completed, and the remaining plan is dropped; `is_planning()` is `false` afterwards.

---

## Implementation Notes

*Derived from ADR-0008 Implementation Guidelines:*

- File: `src/gameplay/run/match_driver.gd` (`class_name MatchDriver extends RefCounted`): `_init`, `submit`, `legal_commands`, `query`, `subscribe`, `events_since`, `hooks()` (read after `Ended` only), `is_planning()`, `signal match_ended(result: MatchResult)`. Fields: `_engine`, `_resolver`, `_boss_ai`, `_task: PlannerTask`, `_pending_plan`, `_replay_index`, `_queued_concede: Command`, `_forecast_turn: int`, `_settings`, `_telegraph_pending`.
- After every accepted or rejected `submit`, run `_after_engine_step()` (Story 014 fills its table; this story provides the skeleton with the `Ended` row deferred to Story 015).
- Construction of the match `EventLog` per attempt and `driver_factory` belong to `RunMachine.begin_match` (`run-structure` epic); this story takes `config.log` as given. `Boot`'s factory (`func(cfg): return MatchDriver.new(cfg, db, settings_snapshot, <PlannerTask>)`) is `boot-composition-root`'s.
- The fake `PlannerTask` for tests is a `tests/helpers/` double with scripted `poll()` answers; never a worker in `tests/unit/**`.
- Test path: ADR-0008 names `tests/unit/run/match_driver_gate_test.gd`; the epic's test root for driver logic is `tests/unit/match_driver/` — use `tests/unit/match_driver/match_driver_gate_test.gd` and note the path in the ADR's Validation Criteria on first `/story-done` (a one-line edit the owner approves).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 014: the `_after_engine_step()` schedule rows (forecast / plan / choose), stale premise, `on_setting_changed`.
- Story 015: `tick()`, replay, checksum, `match_ended` on `Ended`, `shutdown()`.
- `run-structure` epic: `RunMachine.begin_match`, fresh `EventLog`, `match_ended` connected first, `match_handoff_test.gd`.

---

## Files

*The code and test files this story changed.*

- `src/gameplay/run/match_driver.gd`
- `src/gameplay/match/match_query.gd` (the three pass-throughs; MUI-003 owns the rest; see Readiness)
- `tests/helpers/fake_planner_task.gd`
- `tests/helpers/match_driver_fixture.gd` (additive; shared by stories 014 and 015)
- `tests/helpers/test_event_log.gd` (additive: `size()`, as `EventLog`)
- `tests/unit/match_driver/match_driver_gate_test.gd`
- `docs/architecture/adr-0008-match-driver-ownership-and-handoff.md` (the test path in Validation Criteria, as this story asks)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/match_driver/match_driver_gate_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] Created, 17 test cases passing

---

## Dependencies

- Depends on: `production/epics/boss-ai-match-driver/story-001-planner-task-seam.md`, `production/epics/boss-ai-match-driver/story-002-profile-resolver-and-validator.md`, `production/epics/boss-ai-match-driver/story-008-plan-turn-loop-and-turn-plan.md`; `match-rules` epic's `RulesEngine` and `card-effects` epic's `EffectResolver` (cross-epic)
- Unlocks: `production/epics/boss-ai-match-driver/story-014-match-driver-phase-schedule.md`, `production/epics/boss-ai-match-driver/story-015-match-driver-tick-replay-and-shutdown.md`

---

## Completion Notes
**Completed**: 2026-11-05 (start 00:38 UTC, end 00:57 UTC; sprint 5 lane 1 wave 2, branch `s5/l1-w2`)
**Criteria**: 4/4 in `match_driver_gate_test.gd`, with one half deferred. AC-1's "first forecast after the mulligan" is NOT ASSESSED until story 014 (see Readiness): the test covers no task after construction.
**Tests seen failing**: the suite was written first and failed on missing code (exit 105, `Could not find base class "MatchDriver"`). Then 12 deliberate mutants of `match_driver.gd`, all killed: no issuer stamp, caller's command mutated, concede never queued, any command queued, `events` not `[-1, -1]`, concede lost at task end, plan kept at `Ended`, no step after `submit`, empty hero set, `BossAI` after `start`, `query()` rebuilt per call, a task taken as done without `poll()`. One test failed on first run because it was wrong: it sent `choose`, the AC says `play_card`; a `choose` from the wrong side is correctly `NOT_YOUR_TURN`.
**Verification**: import exit 0; `gates.sh` (G1 to G7, 0 hits), `no_global_rng.sh`, `parse-check.sh` exit 0; `commands.test` 1746 test cases, 0 errors, 0 failures, 0 orphans, exit 0; `godot --headless --quit-after 5` exit 0, no `SCRIPT ERROR`. The suite's 88 `SCRIPT ERROR` lines are none of them from the driver suite.
**Run result**: N/A: nothing reaches the screen; the driver has no view until MUI-004.
**Deviations** (advisory):
- **`tick()` step (a) is here**, not in story 015: AC-3 ("after `poll()` returns true") and the QA plan's two-tick case need it. Replay is story 015's.
- **`_start_plan_task()` exists but nothing in production calls it** until story 014's `BossTurn.Main` row. Tests call it through `MatchDriverFixture.start_plan`. It holds the `plan_task(sandbox, task)` call and the sandbox's ownership, so the row is one line.
- **`BossAI.new` takes eight arguments** (`db`, `keyword_values`), as story 008 recorded; the manifest shows six.
- **Commands, results and `MatchConfig` are Dictionaries**, so the signal is `match_ended(result: Dictionary)`.
- **`_forecast_turn` and `_telegraph_pending`** are left to story 014, which uses them.
- `submit` stamps a copy, so the caller's command is left as given.
**Open for story 014**: `PlannerTask.start` is "exactly once per task object" but the driver is handed one object for the whole match. `TimeSlicedPlannerTask` keeps `_done` across a second `start`, so it cannot run a second task. See the lane report.
**Review fixes (2026-11-05, `code-review-s5-w2-matchdriver.md`)**:
- **R-1, hidden information.** `MatchQuery.pending_choice()` handed the view a boss Choice's options, and the class example showed them, against match-ui "the player never sees the options". It now answers a boss Choice with `options` empty, keeping `side` for the "boss discovers" label, and the example checks `side`. `test_query_keeps_a_boss_choices_options_from_the_view` was seen failing first. `legal_commands()` still lists one boss `choose` per option during a boss Choice, so the option count, never an id, is visible until the owner answers the review's Q-5.
- **D-1, sealed log.** A rejected replay command whose own `command_rejected` hit the event cap ended the match, and `_diverge` then appended `ai_fault` to the sealed log. `_replay_one` now runs the step first, as ADR-0008 Decision 4 orders it, so `_ended` is set before `_diverge` runs. `test_a_rejected_replay_command_at_the_cap_ends_the_match_with_no_fault_appended` was seen failing first, on a log that counts appends after sealing.
**Reviewed by**: independent `/code-review`, 2026-11-05 (`production/reviews/2026-11-05/code-review-s5-w2-matchdriver.md`, full scope, at `2117aa3`): **CHANGES REQUIRED**, one defect (R-1), closed by `9ed7a6a` (Review fixes above). No separate re-review report exists. The report's Q-1 to Q-4 are for story 014; DD-X31 decides Q-1 to Q-3.
