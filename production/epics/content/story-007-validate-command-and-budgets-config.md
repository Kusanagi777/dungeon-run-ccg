# Story 007: `tools/content/validate.gd` headless command, exit contract and `content_budgets` validator

> **Epic**: Content (MVP batch)
> **Status**: Ready
> **Layer**: Feature (tooling)
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/content.md` (CN-6 steps 2–3, AC-1, AC-21) · `design/gdd/card-database.md` (CR-5, CR-8 — "the headless validate command prints the report and exits non-zero")
**Requirement**: `TR-content-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Data format, effect schema/DSL and `config()` loading (Key Interfaces: `tools/content/validate.gd`; Decision 7 and 9)
**ADR Decision Summary**: `tools/content/validate.gd` is a SceneTree script that composes the same `DataLoader` the game uses, plus the same static validator map, without `Boot`. It prints `ValidationReport.to_text()` and exits **0** when `Ready` (warnings printed), **1** when `Failed` (report printed) and **2** when it could not run (bad root, no project). It is the only place outside `CardDatabase` allowed to compose the loader. JSON Schema files land at `tools/content/schemas/<file>.schema.json` with this MVP-1 story and must agree with the loader, not replace it.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (ADR-0002 general) / LOW (APIs)
**Engine Notes**: `godot --headless --path . -s res://tools/content/validate.gd [-- --data-root res://assets/data/]`. User args arrive via `OS.get_cmdline_user_args()`, and the exit code is set with `quit(code)` from `_initialize()`/`_process`. Both are pre-4.4 and LOW risk, but verify the exit code on 4.7.2 headless in the test (observed, not assumed). Overrides of typed methods must `return` explicitly (4.7 rule).

**Control Manifest Rules (Foundation, data)**:
- Required: the validate command composes `DataLoader` with the static validators (`configs.content_budgets → ContentValidator.validate_config`); a failed load exits 1.
- Forbidden: no JSON parse outside `CardDatabase` / `DataLoader`. The command must not open `assets/data/*.json` itself, and helpers in `.claude/scripts/`-style tooling emit observations, never verdicts.
- Guardrail: the command's load obeys the same `data_load_budget_ms` 200 as boot.

This is the CN-6.3 gate every batch closes on, and the CI hook the TD-008 retirement names (architecture.md). Story 008 adds the content checks that run inside it.

---

## Acceptance Criteria

*From GDD `design/gdd/content.md` CN-6.2/6.3, ADR-0002 Key Interfaces, scoped to this story:*

- [ ] **AC-1 (Exit contract)** GIVEN a data root, WHEN `validate.gd` runs headless, THEN it composes `DataLoader` + `CardDatabase` with the static validator map `Boot` registers (no `Boot`, no second parser), prints `ValidationReport.to_text()`, and returns **0** for a fixture root that loads `Ready` (warnings printed), **1** for a fixture root with any error (e.g. `E_MISSING_FILE`, `E_UNKNOWN_REF`), and **2** for a non-existent root.
- [ ] **AC-2 (`content_budgets` validator)** GIVEN `ContentValidator.validate_config(body, db)` (static, registered under `configs.content_budgets`), WHEN it receives the shipped `content_budgets.json` body, THEN it returns `[]`. WHEN a CN-6 step 2 key is missing, has the wrong type or is out of its Tuning Knobs safe range, or an unknown key is present, THEN it returns one entry `{code, host_id: null, field, message}` naming the key.
- [ ] **AC-3 (Schemas agree with the loader)** GIVEN `tools/content/schemas/<file>.schema.json` for every DD-T01 definition file and for `content_budgets.json`, THEN each record schema's `required` and `properties` lists equal the CR-3 field list the loader enforces for that record type (the test compares them), and every shipped `assets/data/*.json` conforms to its schema.

---

## Implementation Notes

*Derived from ADR-0002 Implementation Guidelines:*

- Split the command into a thin SceneTree entry (`validate.gd`: parse args, call, `quit(code)`) and a testable `ContentValidateCommand.run(data_root: String, validators: Dictionary) -> Dictionary` returning `{exit_code, report_text}`. The unit test drives `run()` over `tests/fixtures/data/<case>/` roots. Inject the loader root, as card-database tests do, rather than spawning a process.
- Build the validator map from the owners' `static func`s listed in ADR-0002 Key Interfaces. Where an owner class has not landed yet, the command fails with exit 1 and `E_DELEGATED` (a missing validator is an error in every build). Tests inject accepting stubs explicitly.
- `ContentValidator` (`class_name`, static functions only) holds `validate_config` here and the F1–F5 checks in story 008. `Boot` registers `validate_config`, so place the class where both `Boot` and the command can preload it (`tools/content/content_validator.gd` is planned). Confirm with the boot epic that `tools/` ships in the export, or move it to `src/tools/content/`.
- CI: add the command to the test workflow after the gdUnit4 run (exit non-zero fails the job).

---

## Out of Scope

- Story 008: `E_STARTER_CURVE`, `W_SET_SHARE`, `W_HERO_HEALTH`, `W_CURVE`, `W_BUDGET`, `E_TEXT_LENGTH`, `E_COVERAGE`.
- Card Database epic: `ValidationReport.to_text()` (story 008 there), the loader stages.

---

## Files

- `tools/content/validate.gd`, `tools/content/content_validate_command.gd`, `tools/content/content_validator.gd`
- `tools/content/schemas/*.schema.json`
- `tests/unit/content/content_validate_command_test.gd`
- `tests/fixtures/data/content_validate_*/` (ready, failed, schema cases)
- `.github/workflows/tests.yml` (validate step)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: `standard` — Logic tests are BLOCKING.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/content/content_validate_command_test.gd` — must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/card-database/story-008-state-machine-and-debug-reload.md` (`to_text()`, `state()`); `production/epics/card-database/story-004-delegated-validators.md`; `production/epics/content/story-001-batch-0-first-playable-data-set.md` (the shipped `content_budgets.json`)
- Unlocks: `production/epics/content/story-008-content-budget-checks.md`, `production/epics/content/story-009-mvp-1-batch-close-audit-and-balance.md`
