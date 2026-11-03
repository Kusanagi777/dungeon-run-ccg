# Epic: Boss AI + Match Driver

> **Layer**: Core (Boss AI) with the Core-governed `MatchDriver` from Run Structure's directory
> **GDD**: design/gdd/boss-ai.md (Overview, Detailed Rules C1–C11, Formulas F7, F9, Acceptance Criteria A22, A30) · design/gdd/run-structure.md Interactions "Boss AI" row (the driver)
> **Architecture Module**: `BossAI` + `Planner` + `LethalSearch` + `Scorer` + `ProfileResolver` + `PlannerTask` (`src/ai/`) · `MatchDriver` (`src/gameplay/run/match_driver.gd`, Core Layer Rules apply)
> **Control Manifest**: Core Layer Rules (Manifest Version 2026-11-03)
> **Build Order**: 6 of 14 — plan E4, ADR-0008 then ADR-0006
> **Status**: Ready
> **Stories**: 18 (see the table below) — created 2026-11-03 by `/create-stories boss-ai-match-driver`

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | PlannerTask seam and its three implementations | Logic | Ready | ADR-0006 |
| 002 | ProfileResolver and the ai_profiles validator | Logic | Ready | ADR-0006, ADR-0002 |
| 003 | ai_profiles.json — archetypes, bands, runtime block and the five MVP overrides | Config/Data | Ready | ADR-0002, ADR-0006 |
| 004 | Scorer — F1 action score, F2 board value, F3 trade quality, F5 over-extension | Logic | Ready | ADR-0006 |
| 005 | Candidate set — op_value pre-filter, hero-power rule and position sensitivity | Logic | Ready | ADR-0006 |
| 006 | Tie-break set, fork labels and ai_<floor> draw accounting | Logic | Ready | ADR-0003, ADR-0006 |
| 007 | Lethal search — damage subset DFS, F4 prune, node budget, shallow mode | Logic | Ready | ADR-0006 |
| 008 | plan_turn — the C2 action loop, TurnPlan, plan_task and the caps | Logic | Ready | ADR-0006 |
| 009 | DEFENSIVE mode (F6 threat estimate) and sandbox hook fidelity | Logic | Ready | ADR-0006 |
| 010 | Choice phase — `choose` for Discover and choose_one | Logic | Ready | ADR-0006, ADR-0008 |
| 011 | Forecast and telegraphing — Intent, intent keys, kept, effective_mode | Logic | Ready | ADR-0008, ADR-0006 |
| 012 | Hidden-information purity (A4) and the src/ai CI gates (A29, thread symbols) | Logic | Ready | ADR-0001, ADR-0006 |
| 013 | MatchDriver — construction order, command gate and the concede slot | Logic | Ready | ADR-0008 |
| 014 | MatchDriver — phase schedule: forecast, plan and choose tasks, stale premise, telegraph setting | Logic | Ready | ADR-0008, ADR-0006 |
| 015 | MatchDriver — tick(), bounded replay with checksum, match_ended and shutdown | Integration | Ready | ADR-0006, ADR-0008 |
| 016 | Headless AI-vs-AI simulation harness (gate condition 6) | Integration | Ready | ADR-0006, ADR-0008 |
| 017 | Worker-vs-main-thread determinism and forecast concurrency (gate condition 9, Linux half) | Integration | Ready | ADR-0006 |
| 018 | Windows export — planner running, A30 frame budget and determinism on Windows (gate conditions 6 and 9) | Integration | Ready | ADR-0006 |

Dependency order: 001, 002 → 003 → 004 → 005, 006 → 007 → 008 → 009, 010, 011 → 012 · 013 (needs 001, 002, 008) → 014 (needs 010, 011), 015 → 016 → 017 → 018. Logic tests live under `tests/unit/boss_ai/` and `tests/unit/match_driver/`; Integration under `tests/integration/boss_ai/` and `tests/integration/match_driver/`. QL-STORY-READY skipped — Lean mode.

## Overview

Give the bosses a pilot and give a match an owner. `BossAI` is a `RefCounted` pure function of observable state, resolved `ai_profile` and `ai_<floor>` stream position: each boss turn it reads `legal_commands()` and `clone()`, runs the bounded lethal search, scores candidates with data-driven weights (default + archetype + band + boss override from `ai_profiles.json`), submits the best until `end_turn` wins, logs every decision with its top alternatives, and produces the truthful intent banner (`forecast`) under DD-X03's telegraph setting. `MatchDriver` is the rules-side object Run Structure owns and Match UI's `MatchController` merely wraps: it builds `RulesEngine`, `EffectResolver` and `BossAI` from one `MatchConfig`, schedules `forecast` / `play_turn` / `choose` at the phase transitions, polls the `PlannerTask` once per frame through `tick()`, and raises `match_ended`. The two are one epic because the first playable cannot run without both and because ADR-0006's threading seam (worker-pool default, time-sliced fallback, 2 ms main-thread cap, coroutine `plan_turn` per the 2026-11-03 erratum) is exercised only through the driver. Threading is NOT SOURCEABLE on 4.7.2 and unverified on Windows, so the sprint-1 spike runs the planner on the Windows export and the AI-vs-AI harness proves determinism per seed.

## Scope (MVP)

- `BossAI.forecast(engine) -> Intent`, `play_turn(engine)`, `choose(engine, request) -> int`; modes NORMAL / LETHAL / DEFENSIVE; `ai_intent_shown` / `ai_intent_committed` events
- `ProfileResolver` over `config("ai_profiles")` with the stage-7 validators for `ai_profile` and the config file
- `@abstract PlannerTask` with the worker-pool implementation and the main-thread time-sliced fallback; `replay_budget_ms` 2; no subscriber runs off-thread
- `MatchDriver.submit / legal_commands / query / tick / hooks`, `match_ended` signal, concede-while-planning rule, fresh match `EventLog` per attempt, `driver_factory` injection
- `tests/integration/boss_ai/sim_harness.gd` writing `production/qa/sim/<boss_id>_<date>.json`, deterministic per seed
- Profiles for the five MVP bosses (3 band 1 / 1 band 2 / 1 band 3, DD-H06)

Out of scope: profiles and archetype tuning for the eleven bosses beyond the MVP five (deferred list).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0008: Match Driver Ownership and the Run ↔ Match ↔ UI Hand-off | `MatchDriver` in `src/gameplay/run/`, built by `RunMachine.begin_match` (or a fixture), wrapped by `MatchController`; `tick()` contract; one-way scene hand-off; concede-while-planning | HIGH by version; threading belongs to ADR-0006 |
| ADR-0006: Boss AI Planner Threading — `PlannerTask` Seam, Worker-Pool Default, Time-Sliced Fallback | Planner off the main thread behind `PlannerTask`; ≤ 2 ms main-thread per frame; time-sliced fallback; byte-identical log vs main-thread run (A30); coroutine task Callable built by `BossAI.plan_task` (erratum) | **HIGH / NOT SOURCEABLE** (no threading page; Windows gated) |
| ADR-0001: Rules / Presentation Split | `src/ai/**` is rules tier: `RefCounted`, mutates only through `submit` | HIGH |
| ADR-0003: Seeded RNG Service and Event Log | Tie-breaks from `ai_<floor>` and its forks; `ai_decision` diagnostics on the log | HIGH / NOT SOURCEABLE |
| ADR-0002: Data format and `config()` loading | `ai_profiles.json` config and its validator at stage 7a | HIGH / LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-boss-ai-001 | C1: BossAI is a RefCounted pure function of (observable state, profile, stream position); reads only legal_commands() and clone(); never reads hidden information | ADR-0006 ✅ (also ADR-0001, 0003) |
| TR-boss-ai-002 | C1.4: entry points forecast(engine) -> Intent, play_turn(engine), choose(engine, request) -> int, all synchronous | ADR-0006 ✅ (also ADR-0008) |
| TR-boss-ai-003 | C1.5, C9, F7: at most 2 ms main-thread time per frame; planner off-thread or time-sliced (mechanism by ADR); budgets are counts, 50 ms per turn is the p95 acceptance target | ADR-0006 ✅ (also ADR-0008) |
| TR-boss-ai-004 | C8, DD-X03: telegraph events ai_intent_shown / ai_intent_committed with effective_mode = min(boss.intent_mode, settings.telegraph_mode) | ADR-0008 ✅ |
| TR-boss-ai-005 | C10, F9: ai_profiles.json config with resolved profile default + archetype + band + boss_override; validator injected at stage 7 | ADR-0006 ✅ (also ADR-0002) |
| TR-boss-ai-006 | C11: headless simulation harness tests/integration/boss_ai/sim_harness.gd writing production/qa/sim/<boss_id>_<date>.json | ADR-0006 ✅ |
| TR-run-structure-005 | Interactions (Boss AI): Run Structure owns the match driver that constructs RulesEngine and BossAI at begin_match and calls forecast / play_turn / choose at phase transitions; the driver is rules-side code wrapped by Match UI's MatchController | ADR-0008 ✅ (also ADR-0006) |

Requirements covered by Accepted ADRs: 7 / 7. Untraced Requirements: None.

## Gate Entry Conditions Carried

- **Condition 6** (sprint-1 spikes): Boss AI planner running on the Windows export; headless AI-vs-AI harness deterministic per seed — lead-programmer.
- **Condition 9**: ADR-0006's worker-vs-main-thread determinism test and A30 on Windows scheduled **before this epic closes** — technical-director.
- **Condition 5**: the first playable's band-1 boss is piloted by this planner.

## Definition of Done

- Every story implemented, reviewed and closed with `/story-done`
- Every acceptance criterion of design/gdd/boss-ai.md verified (30 criteria lines), including A22 and A30 on Windows
- The harness output for each MVP boss is retained under `production/qa/sim/` and identical across two runs of the same seed
- Logic and Integration stories have passing tests in the test root
- Visual/Feel and UI stories have retained screenshots in `production/qa/evidence/` (a lead sign-off too for Visual/Feel)
