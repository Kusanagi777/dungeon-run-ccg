# Story 008: Content checks F1–F5 in the validate command (starter curve, set share, curve, budget, text, coverage)

> **Epic**: Content (MVP batch)
> **Status**: Complete
> **Layer**: Feature (tooling)
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-04

## Context

**GDD**: `design/gdd/content.md` (CN-6 step 3 code list; Formulas F1 Set composition, F2 Curve targets, F3 Vanilla stat budget and taxes, F5 Coverage check; Tuning Knobs; AC-4, AC-5, AC-7, AC-9, AC-21) · `design/gdd/heroes.md` (F1 starter curve, Edge Cases `W_HERO_HEALTH`)
**Requirement**: `TR-content-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Data format, effect schema/DSL and `config()` loading
**ADR Decision Summary**: Tooling reads its constants from config bodies (`content_budgets.json`, `heroes_balance.json`), never from literals. The validate command composes the loader and reports entries in the CR-5 report shape `{severity, code, file, record_id, field, message}`.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (ADR-0002 general) / LOW (APIs)
**Engine Notes**: Numbers from config bodies arrive as `float`; compare costs and counts after `int()`. Floating comparisons on shares and averages use the knob's tolerance and nothing else.

**Control Manifest Rules (Foundation, data)**:
- Required: every F1–F6 constant is read from `content_budgets.json` / `heroes_balance.json` (passed in as the config bodies).
- Forbidden: never a numeric gameplay default in code; the checks emit observations (report entries), never verdicts.
- Guardrail: the checks add O(records) work and keep the command's load within `data_load_budget_ms`.

CN-6 step 3 lists the codes the Content validator adds on top of the loader. They run inside the story 007 command after the database is `Ready`, and the batch-close stories use them in place of hand checks.

---

## Acceptance Criteria

*From GDD `design/gdd/content.md` CN-6.3, F1–F5, AC-4/5/7/9/21, scoped to this story:*

- [x] **AC-1 (Heroes checks — AC-5 starter clause)** GIVEN a fixture whose starter deck breaks Heroes F1, WHEN the checks run, THEN one `E_STARTER_CURVE` entry names the hero. GIVEN a `HeroDef.health` other than `player_starting_health`, THEN `W_HERO_HEALTH` is raised. GIVEN a set whose type share is outside `SET_SHARE ± share_tol`, THEN `W_SET_SHARE` names the set and type (AC-4). A conforming fixture raises none of the three.
- [x] **AC-2 (Curve, budget, text — F2, F3, AC-9)** GIVEN a set whose average cost is outside `curve.avg_min`–`curve.avg_max`, or whose cost bucket misses its target by more than `curve.bucket_tol`, THEN `W_CURVE` is raised. GIVEN a card whose F3 points exceed its rarity's `budget.tol`, THEN `W_BUDGET` names the card with its computed points. GIVEN a `text.en` longer than `text_max_chars`, THEN `E_TEXT_LENGTH` names the card. Boundary tests: exactly 90 characters passes, 91 fails.
- [x] **AC-3 (Coverage — F5, AC-7)** GIVEN a pool, WHEN F5 runs, THEN every op in `OPS_COVERED` (card-effects C5 minus `coverage.ops_exempt` and `modify_value`) that no collectible card uses is reported, and `modify_value` is checked against boss passives and treasures. An unused exempt op is `W_COVERAGE_UNUSED`, a DD-M09 keyword on fewer than `coverage.kw_min` collectible cards is reported, and hero-set bundle coverage is reported with its value. At the Alpha pool an unmet requirement is `E_COVERAGE`; at the MVP pool it is `W_COVERAGE`, as AC-7 states.
- [x] **AC-4 (No literals — AC-21)** GIVEN `tools/content/**` and `src/**`, WHEN grepped for the F1–F6 constants (`CURVE_*`, `BUDGET_TOL`, `PRESSURE_*`, `PASSIVE_CAP`, `KW_MIN`, `BUNDLE_COVERAGE_MIN`, `TEXT_MAX_CHARS`, `PICK_RATE_*`) and their default values, THEN none appears as a literal, and changing a knob in a fixture `content_budgets.json` changes the check's outcome (the test proves this for `text_max_chars` and `curve.bucket_tol`).

---

## Implementation Notes

*Derived from ADR-0002 Implementation Guidelines and content Formulas:*

- Write each check as a `static func` on `ContentValidator` taking `(db: CardDatabase, budgets: Dictionary, heroes_balance: Dictionary) -> Array[Dictionary]` that returns report entries. The command merges them into its printed report. Severity follows the code prefix (`E_` error → exit 1, `W_` warning → exit 0).
- Read each formula's variables from its Formulas subsection (F1–F5) and the key map in CN-6 step 2 (`curve.*` F2, `budget.*` F3, `coverage.*` F5). Hero-set rows (`SET_SHARE[war]`, `PLAN_MIN/MAX`, the starter curve) come from `heroes_balance.json` and are not duplicated in `content_budgets.json`.
- Which pool is being checked (MVP vs Alpha) is derived from the sets present (no `decay`/`knowledge` HeroDef = MVP), never from a flag in the data.
- Fixtures live under `tests/fixtures/data/content_checks_*/` or are built in-test with `CardFactory`. No test reads the shipped `assets/data/`.

---

## Out of Scope

- Story 007: command entry, exit codes, `validate_config`.
- F4 boss pressure and F6 volume: they are sim/report metrics read by `/balance-check` (story 009), not validate-command codes.

---

## Files

- `src/tools/content/content_validator.gd` (the story listed `tools/content/`; the class moved to `src/tools/content/` in story 007 because `Boot` registers it and `export_presets.cfg` excludes `tools/*`) — F1-F5 checks, `pool_of`, `run_checks`
- `tools/content/content_validate_command.gd` — merges the check entries into the printed report; exit 1 on any `E_` entry
- `tests/unit/content/content_budget_checks_test.gd` (40 tests)
- `tests/fixtures/data/content_checks_base/`, `tests/fixtures/data/content_checks_knobs/` (same records; only `text_max_chars` 90 → 80 and `curve.bucket_tol` 0.08 → 0.15 differ)
- `tests/unit/content/content_validate_command_test.gd`, `tests/integration/content/content_validate_process_test.gd` (story 007 tests: the expected printed report is now the load report merged with the checks)

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: `standard` — Logic tests are BLOCKING.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/content/content_budget_checks_test.gd` — must exist and pass.

**Status**: [x] `tests/unit/content/content_budget_checks_test.gd` (40 tests), passing

---

## Dependencies

- Depends on: `production/epics/content/story-007-validate-command-and-budgets-config.md`
- Unlocks: `production/epics/content/story-009-mvp-1-batch-close-audit-and-balance.md`

## Completion Notes
**Completed**: 2026-11-04
**Started / ended (UTC)**: 2026-11-04T02:44:30Z – 2026-11-04T03:01:11Z (the run was resumed twice at the per-run turn limit; the lane worktree was removed in between and recreated at `.claude/worktrees/l6-content-checks` on the same branch, with nothing lost)
**Readiness (by hand, 2026-11-04)**: READY. ADR-0002 Accepted; manifest 2026-11-03 on both sides; story 007 Complete; 4 criteria, no open markers. One gap resolved from the docs: `## Files` named `tools/content/content_validator.gd`, but the class has lived at `src/tools/content/` since story 007.
**Criteria**: 4/4 passing
**Deviations**:
- The checks take a plain pool view, `check_*(pool, budgets, heroes_balance)`, not `(db, …)`. `ContentValidator.pool_of(db)` builds the view from a `Ready` database's snapshot, and `run_checks(db, budgets, heroes_balance)` is the `db` entry point. This lets in-test `CardFactory` pools reach every check without files.
- `W_HERO_HEALTH` compares against `match_rules.starting_health_player` (the shipped key). The GDD calls it `player_starting_health`.
- Hero sets read `heroes_balance.set_share` and `set_share_tol`; neutral and boss read `content_budgets.set_share` and `share_tol` (CN-6 step 2: hero rows are not duplicated).
- F2 is applied to collectible sets only (non-token, not `boss`). F3 and F5 use collectible cards. `E_TEXT_LENGTH` covers every CardDef, tokens and boss cards included.
- F3 model choices the GDD leaves open: a fixed single enemy target (`enemy_hero`, `opponent`) takes the `damage_random` rate; `conditional` is valued at its `then` branch and `choose_one` at its best option; heal, buff, give_keyword, freeze, silence and transform are valued on single-target selectors only; `destroy` on a friendly target is `self_destroy`. Any op or shape without a rate (aura, multi-target buff, value expressions, …) makes the card `W_BUDGET` "not checked", with the reasons and the partial value. It never passes.
- An absent or unreadable knob reports "not checked" under the check's own code, never a pass. Note that `heroes_balance` still has only a pending stage-7a validator.
- F5 neutral bundle coverage has no threshold at v1 and emits no entry. Hero-set coverage is reported, with its value, only when under `bundle_coverage_min`.
- Keyword and bundle coverage misses use `E_COVERAGE` / `W_COVERAGE` (the GDD names no separate code).
- AC-4 scan: it greps declarations of the named constants, plus the distinctive defaults (2.9, 3.4, 0.16, 0.22, 0.24, 0.18, 0.08, 11.5, 0.55, 0.9, 90) in code with comments stripped. The other defaults are also safe-range bounds or common numbers, so they stay a documented list (skill-authoring rule 5). The gate was seen failing on a planted `const TEXT_MAX_CHARS`.
- Story 007's command contract changed as this story requires: after a `Ready` load the printed report is the load report merged with the check entries, and the exit code is 1 on any `E_` entry. Two story-007 tests now compare against that exact merged text.
**Shipped data (`assets/data/`, 2026-11-04, before lane 5's War/boss data)**: `validate.gd` exits 0. Content checks: 0 errors, 51 warnings: W_COVERAGE 30 (17 ops, 12 keywords, `modify_value`), W_COVERAGE_UNUSED 5, W_CURVE 8 (war, neutral), W_SET_SHARE 5 (war spell/weapon, neutral minion/spell, boss spell), W_BUDGET 3 (all "not checked": `neutral_banner_captain` aura, `neutral_spark_fiend` damage with no targets, `war_warcry` multi-target buff). No E_STARTER_CURVE, W_HERO_HEALTH or E_TEXT_LENGTH.
**Test Evidence**: `tests/unit/content/content_budget_checks_test.gd` (40 tests; seen failing to parse before the checks existed, and the AC-4 gate seen failing under mutation). Full suite 1118 test cases, 0 failures, exit 0. Smoke exit 0. The only SCRIPT ERROR lines are from pre-existing negative-test suites.
**Reviewed by**: lean — review gates skipped (QL-TEST-COVERAGE / LP-CODE-REVIEW skipped — Lean mode)
