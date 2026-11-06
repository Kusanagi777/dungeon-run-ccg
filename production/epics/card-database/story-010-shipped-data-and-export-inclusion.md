# Story 010: Shipped data boots `Ready` and ships in the export (CR-1, CR-8, Export inclusion)

> **Epic**: Card Database
> **Status**: In Review
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: — (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/card-database.md`
**Requirement**: `TR-card-database-001`, `TR-card-database-005`, `TR-design-decisions-002` (carried: DD-T01 — all definitions are JSON under `assets/data/`)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Data format, effect schema/DSL and `config()` loading (Decision 10, export inclusion); ADR-0001: Rules / Presentation Split (`Boot.boot()` constructs `CardDatabase` and calls `load(validators)` once, synchronously)
**ADR Decision Summary**: `.json` files are not scenes or imported resources, so `export_presets.cfg` carries `include_filter="assets/data/*.json"` to guarantee the PCK holds them regardless of export mode; default export inclusion of `.json` is `NOT SOURCEABLE`, so the smoke check reads `data_version()` from an exported build. The shipped data set loads through `Boot` to `Ready` with zero errors.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (ADR-0002 knowledge risk; export-preset semantics `NOT SOURCEABLE` — verified by running the export)
**Engine Notes**: ADR-0002 Verification Required item 4 (`assets/data/*.json` present in the exported PCK). The Windows export is verified locally (`commands.build`, `tests/README.md`) but **not run in CI** (no export templates on the runner) — the exported-build check is a documented local smoke run until an export job exists. The first export after a fresh import may exit 134 after writing a complete file; run `--import` first and retry once.

**Control Manifest Rules (this layer)**:
- Required: `export_presets.cfg` keeps `include_filter="assets/data/*.json"`; the smoke check asserts `data_version()` is non-empty in an exported build. `Boot` is the one autoload and a lazy composition root; scene roots pass services down by argument.
- Forbidden: Never a second composition path; never `load("res://assets/data/…")` outside `CardDatabase`.
- Guardrail: Data load (`Boot.boot()` → `CardDatabase` `Unloaded → Ready`) ≤ `data_load_budget_ms` 200, synchronous at boot.

---

## Acceptance Criteria

*From GDD `design/gdd/card-database.md` (CR-1, CR-8, Acceptance Criteria "Loading and failure"), the epic Scope (export inclusion) and ADR-0002 Decision 10, scoped to this story:*

- [ ] **GIVEN** the shipped data set under `assets/data/`, **WHEN** the game boots (`Boot.boot()` with the production validator map), **THEN** state is `Ready`, `report()` has zero errors, and the per-type record counts (cards per set, tokens, bosses, treasures, bundles) equal `design/gdd/content.md` CN-1's scope table for the shipped batch (MVP: 40 collectible — war 25 + neutral 15 —, 3 tokens, 10 boss-only, 5 bosses, 10 treasures, 10 bundles; CN-1 is the source of truth if the batch changes — the test reads the expected counts from one constants block citing CN-1).
- [ ] **GIVEN** the shipped data set, **WHEN** loaded, **THEN** `config("match_rules")`, `config("card_effects")`, `config("ai_profiles")`, `config("run_structure")`, `config("reward_draft")`, `config("treasures_balance")`, `config("heroes_balance")`, `config("match_ui")`, `config("run_ui")`, `config("profile_defaults")`, `config("card_database")`, `config("content_budgets")` and `config("rng_event_log")` each return a non-null frozen Dictionary, and every warning left in `report()` is one CN-6 step 3 allows for the batch (`W_POOL_SIZE` only at MVP-0; none at MVP-1).
- [ ] **GIVEN** `export_presets.cfg`, **THEN** the `Windows Desktop` preset has `include_filter="assets/data/*.json"`; **GIVEN** an exported build (`commands.build`), **WHEN** it is launched headless with the smoke argument, **THEN** it prints a non-empty 16-hex `data_version()` equal to the one the editor build prints for the same files, and that run is recorded in `production/qa/smoke-<date>.md`.

---

## Implementation Notes

*Derived from ADR-0002 Decision 7 and 10, ADR-0001 Decision (Boot), tests/README.md "Export is not run in CI":*

- `tests/integration/card_database/card_database_shipped_data_test.gd`: construct the database the way `Boot` does (call `Boot.boot()` if the boot epic's story has landed, else `DataLoader.new("res://assets/data/")` + `CardDatabase.new(loader)` with the same validator map `Boot` uses — never a third composition), assert `state() == READY`, `report().errors().is_empty()`, the CN-1 counts via `cards_by_set("war").filter(token == false).size()` etc., and every `config(name)` from `DataLoader.FILE_MANIFEST`'s config rows non-null and read-only. Expected counts live in one `const` block at the top of the test citing content CN-1 (they change per batch; the test, not the loader, owns them).
- Edit `export_presets.cfg`: set `include_filter="assets/data/*.json"` on the `Windows Desktop` preset (currently `""`). Keep `export_filter="all_resources"`.
- Exported-build smoke: add a `--print-data-version` (or reuse the boot scene's headless path) that prints `data_version()` and quits; run `godot --headless --path . --import` → `commands.build` → `build/windows/deckdelve.exe --headless --print-data-version` on the owner's Windows machine (the Linux runner cannot execute the Windows binary; `--export-pack` to a `.pck` loaded by the Linux editor binary is an acceptable CI-side proxy if one is added later). Record the command, exit code and printed string in `production/qa/smoke-<date>.md`. Until a CI export job exists this is a documented smoke run, which the Integration evidence row allows.
- Extend `tests/smoke/critical-paths.md` with the row "exported build prints non-empty `data_version()`".
- The CN-1 counts and CN-6 warning allowances are content's; if they differ at implementation time, the content GDD wins and the test constants are updated with a citation — never the loader.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Content epic: authoring the records; `tools/content/validate.gd` exit contract.
- Boot epic: `Boot.boot()` itself and the production validator map.
- Run UI epic: the `data_error` screen shown over a `Failed` load.
- Story 009: the timed budget assertion (this story asserts correctness of the shipped set, not timing).
- Adding an export job to `tests.yml` (polish / release prep, gate conditions 8 and 10).

---

## Files

- `export_presets.cfg` (`include_filter`)
- `src/core/boot.gd` or `src/scenes/boot.tscn` script (the `--print-data-version` headless path — coordinate with the boot epic; if `Boot` is not yet landed, a minimal `tools/print_data_version.gd` SceneTree script composing `DataLoader` is acceptable, the same allowance as `tools/content/validate.gd`)
- `tests/integration/card_database/card_database_shipped_data_test.gd`
- `tests/smoke/critical-paths.md`
- `production/qa/smoke-<date>.md` (the exported-build run)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: `standard` — Integration tests are BLOCKING.*

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/card_database/card_database_shipped_data_test.gd` (AC 1–2) — must exist and pass; AC 3's exported-build check is a documented smoke run in `production/qa/smoke-<date>.md` (the Integration row allows "integration test OR documented playtest"), recorded with the owner's Windows run.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/card-database/story-007-data-version-fingerprint.md`, `production/epics/card-database/story-008-state-machine-and-debug-reload.md`, `production/epics/card-database/story-009-load-and-memory-budget.md`; boot epic's `Boot.boot()` story (path assigned by `/create-stories boot-composition-root`); content epic MVP-0 and MVP-1 batch stories (paths assigned by `/create-stories content`)
- Unlocks: gate entry condition 5 (first playable loads the War starter deck and one band-1 boss through this module) and condition 1 (the DD-H06 batch validates here); `/smoke-check`
