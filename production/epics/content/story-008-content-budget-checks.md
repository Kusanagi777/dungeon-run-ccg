# Story 008: Content checks F1–F5 in the validate command (starter curve, set share, curve, budget, text, coverage)

> **Epic**: Content (MVP batch)
> **Status**: Ready
> **Layer**: Feature (tooling)
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

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

- [ ] **AC-1 (Heroes checks — AC-5 starter clause)** GIVEN a fixture whose starter deck breaks Heroes F1, WHEN the checks run, THEN one `E_STARTER_CURVE` entry names the hero. GIVEN a `HeroDef.health` other than `player_starting_health`, THEN `W_HERO_HEALTH` is raised. GIVEN a set whose type share is outside `SET_SHARE ± share_tol`, THEN `W_SET_SHARE` names the set and type (AC-4). A conforming fixture raises none of the three.
- [ ] **AC-2 (Curve, budget, text — F2, F3, AC-9)** GIVEN a set whose average cost is outside `curve.avg_min`–`curve.avg_max`, or whose cost bucket misses its target by more than `curve.bucket_tol`, THEN `W_CURVE` is raised. GIVEN a card whose F3 points exceed its rarity's `budget.tol`, THEN `W_BUDGET` names the card with its computed points. GIVEN a `text.en` longer than `text_max_chars`, THEN `E_TEXT_LENGTH` names the card. Boundary tests: exactly 90 characters passes, 91 fails.
- [ ] **AC-3 (Coverage — F5, AC-7)** GIVEN a pool, WHEN F5 runs, THEN every op in `OPS_COVERED` (card-effects C5 minus `coverage.ops_exempt` and `modify_value`) that no collectible card uses is reported, and `modify_value` is checked against boss passives and treasures. An unused exempt op is `W_COVERAGE_UNUSED`, a DD-M09 keyword on fewer than `coverage.kw_min` collectible cards is reported, and hero-set bundle coverage is reported with its value. At the Alpha pool an unmet requirement is `E_COVERAGE`; at the MVP pool it is `W_COVERAGE`, as AC-7 states.
- [ ] **AC-4 (No literals — AC-21)** GIVEN `tools/content/**` and `src/**`, WHEN grepped for the F1–F6 constants (`CURVE_*`, `BUDGET_TOL`, `PRESSURE_*`, `PASSIVE_CAP`, `KW_MIN`, `BUNDLE_COVERAGE_MIN`, `TEXT_MAX_CHARS`, `PICK_RATE_*`) and their default values, THEN none appears as a literal, and changing a knob in a fixture `content_budgets.json` changes the check's outcome (the test proves this for `text_max_chars` and `curve.bucket_tol`).

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

- `tools/content/content_validator.gd`
- `tests/unit/content/content_budget_checks_test.gd`
- `tests/fixtures/data/content_checks_*/`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: `standard` — Logic tests are BLOCKING.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/content/content_budget_checks_test.gd` — must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content/story-007-validate-command-and-budgets-config.md`
- Unlocks: `production/epics/content/story-009-mvp-1-batch-close-audit-and-balance.md`
