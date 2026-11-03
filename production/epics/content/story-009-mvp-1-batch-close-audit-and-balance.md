# Story 009: MVP-1 batch close — validate exits 0, `/content-audit` counts, `/balance-check` over sim and run logs

> **Epic**: Content (MVP batch)
> **Status**: Ready
> **Layer**: Feature (data)
> **Type**: Config/Data
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/content.md` (CN-6 steps 1, 3, 4, 5 — MVP-1 row; F4 Boss deck pressure by band; AC-1, AC-2, AC-6, AC-7, AC-12)
**Requirement**: `TR-content-001`, `TR-content-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Data format, effect schema/DSL and `config()` loading (validate exit contract); ADR-0003: Seeded RNG Service and Event Log (archived run logs as `/balance-check` input); ADR-0006: Boss AI Planner Threading (the immediate `PlannerTask` the sim harness uses)
**ADR Decision Summary**: A batch closes when `tools/content/validate.gd` exits 0. Match logs are archived as `user://logs/<run_id>/floor_<n>_attempt_<k>.json` (`to_json` header `{log_schema_version, engine_version, data_version, run_seed_hex, …}`) when `keep_match_logs` is set. The sim harness plans with the immediate `PlannerTask` implementation, which is deterministic per seed. `/balance-check` reads both.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH / NOT SOURCEABLE (ADR-0003 RNG/JSON, ADR-0006 threading — the harness uses the immediate seam, no worker)
**Engine Notes**: Sim outputs are produced headless by the boss-ai harness. Determinism per seed is that epic's test, and this story only consumes the outputs.

**Control Manifest Rules (Foundation, data)**:
- Required: logs and sim outputs carry `data_version`; `/balance-check` compares only runs whose `data_version` matches the data under test.
- Forbidden: never author a content-version string; helpers emit observations, never verdicts.
- Guardrail: data load ≤ `data_load_budget_ms` 200 on the full MVP set.

This story closes the MVP-1 batch against the CN-6 table: loads clean, `/balance-check` runs F2, F3, F4 (5 bosses via the sim harness) and F5 (MVP coverage), and `/content-audit` counts 40 / 5 / 10 / 10. It is also where TR-content-002 is met: archived run logs and sim outputs are the `/balance-check` inputs.

---

## Acceptance Criteria

*From GDD `design/gdd/content.md` (CN-6, AC-1, AC-2, AC-6, AC-7, AC-12), scoped to this story:*

- [ ] **AC-1 (Loads clean — AC-1)** GIVEN the full MVP set, WHEN `godot --headless --path . -s res://tools/content/validate.gd` runs, THEN it exits 0 with zero `error` entries. None of `W_DUP_NAME`, `W_FX_KEYWORD_MISMATCH`, `E_TEXT_LENGTH` or `W_POOL_SIZE` appears (`W_POOL_SIZE` is accepted only at MVP-0, CN-6.3), and the printed output is retained in `production/qa/`.
- [ ] **AC-2 (Counts — AC-2)** GIVEN the closed batch, WHEN `/content-audit` runs, THEN it reports 40 collectible cards (war 25, neutral 15), 3 tokens, 10 boss-only cards, 5 bosses (band 3 / 1 / 1), 10 bundles (8 war, 2 neutral) and 10 treasures, which equal the CN-1 MVP column.
- [ ] **AC-3 (Sim and pressure — AC-12, CN-6.4, TR-content-002)** GIVEN each of the 5 MVP bosses and the `default`-profile War hero script, WHEN the boss-ai sim harness runs ≥ 50 seeded matches per pairing into `production/qa/sim/<boss_id>_<date>.json`, THEN rejected AI commands = 0, and F4 `boss_pressure` is within its band target ± `pressure.tol` (1.0) or the deviation is recorded in this story. `/balance-check` reads those sim files plus any archived `user://logs/` run logs whose `data_version` matches, and reports F2 curve per set, F3 outliers and F4 by band.
- [ ] **AC-4 (Outliers and coverage — AC-6, AC-7 MVP clause)** GIVEN the `/balance-check` report, THEN every card outside `BUDGET_TOL` is listed and has an accepted-deviation note in the story that authored it (002, 003, 004 or 001), with no silent outliers. GIVEN the validate command's F5 output on the MVP pool, THEN the unmet ops are exactly those listed as `W_COVERAGE` in Implementation Notes below.

---

## Implementation Notes

*Derived from ADR-0002 / ADR-0003 / ADR-0006 Implementation Guidelines and CN-6:*

- The order is: validate (exit 0) → `/content-audit` → sim harness for 5 bosses → `/balance-check`. Record each run (command, exit code, report path) in `production/qa/smoke-[date].md`.
- MVP `W_COVERAGE` ops (fill from the F5 output at close; this list is the AC-7 MVP baseline): —
- Rebalancing found here goes back to the authoring story's data as a new change, citing the F3/F4 figure. It is never patched silently in this story.
- When this story closes, the card-database shipped-data test (card-database story 010) switches its expected counts from batch 0 to CN-1's MVP column.

---

## Out of Scope

- AC-13 (per-floor win rate vs `target_win_rate_by_floor`): VS / Alpha batch close. AC-19 (playtest puzzle naming): a playtest note after the MVP build exists (`/playtest-report`).
- Boss AI epic: the harness itself (story 016).

---

## Files

- `production/qa/smoke-[date].md`, `production/qa/validate-mvp-1-[date].txt`
- `production/qa/sim/<boss_id>_<date>.json` (5 files, produced by the harness)
- `production/qa/balance-check-[date].md`, `production/qa/content-audit-[date].md`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: `standard` — Config/Data evidence is ADVISORY.*

**Story Type**: Config/Data
**Required evidence**:
- Config/Data: smoke check pass (`production/qa/smoke-[date].md`) plus the retained validate output, sim files and the `/content-audit` and `/balance-check` reports.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content/story-002-mvp-1-war-set.md`, `production/epics/content/story-003-mvp-1-band-1-bosses-rat-king-gatekeeper.md`, `production/epics/content/story-004-mvp-1-bosses-rot-warden-hollow-king.md`, `production/epics/content/story-005-mvp-1-bundles.md`, `production/epics/content/story-006-mvp-1-treasures.md`, `production/epics/content/story-008-content-budget-checks.md`; `production/epics/boss-ai-match-driver/story-016-sim-harness.md`; `production/epics/rng-event-log/story-007-overflow-fault-and-config-knobs.md` (`keep_match_logs`)
- Unlocks: `production/epics/card-database/story-010-shipped-data-and-export-inclusion.md` (MVP counts); epic Definition of Done; gate entry condition 1 (DD-H06 batch validates)
