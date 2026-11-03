# Story 001: File manifest, parse and envelope (CR-5 stages 1–3)

> **Epic**: Card Database
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: — (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/card-database.md`
**Requirement**: `TR-card-database-001` (primary), `TR-design-decisions-002` (carried: DD-T01 file list), `TR-card-database-002` (stages 1–3 of the pipeline)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Data format, effect schema/DSL and `config()` loading (also ADR-0001: Rules / Presentation Split — only `src/core/**` touches `FileAccess`)
**ADR Decision Summary**: All game data is JSON under `assets/data/`, read by exactly one class chain — `CardDatabase` → `DataLoader` — which discovers files from the code-owned `FILE_MANIFEST` (never a directory scan), parses with `JSON.new().parse()` for line/message, and checks the envelope against `SCHEMA_VERSION_CURRENT = 1`, the one exempt code literal.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (ADR-0002 knowledge risk for GDScript/Core generally; the APIs this story uses — `FileAccess.open`, `get_open_error`, `JSON.new().parse`, `get_error_line` — are pre-4.4, LOW, verified by tests)
**Engine Notes**: `JSON.parse()` error line/message on a malformed file is `NOT SOURCEABLE` from the engine reference (ADR-0002 Verification Required item 1) — this story's parse-error test is the proof. A `null` from `FileAccess.open` must report `FileAccess.get_open_error()` (Probe B observed `ERR_FILE_NOT_FOUND = 7`). Overrides of typed methods need an explicit `return` (4.7 rule).

**Control Manifest Rules (this layer)**:
- Required: All game data is JSON under `assets/data/`, loaded by one `CardDatabase` through `DataLoader` from the code-owned `FILE_MANIFEST` (DD-T01 rows `{name, class, record_type, required, owner}`); a `.json` not in the manifest is `W_UNKNOWN_FILE`. Parse with `JSON.new()` + `parse(text)`; a `null` from `FileAccess.open` reports `get_open_error()` as `E_MISSING_FILE`. `SCHEMA_VERSION_CURRENT = 1` is a `const` in `DataLoader`; both older and newer `schema_version` fail. Every class under `src/core/**` `extends RefCounted`; collaborators arrive through `_init(...)`.
- Forbidden: Never a per-system loader or any JSON parse outside `CardDatabase` (`FileAccess.open("res://assets/data/…")`, `JSON.parse_string`, `JSON.new().parse`, `load("res://assets/data/…")` appear nowhere else in `src/`; `tools/content/validate.gd` is allowed). Never one bundled `game_data.json`. Never a numeric gameplay default in loader code — `SCHEMA_VERSION_CURRENT` and `FILE_MANIFEST` are the only data-shaped literals in `src/core/data/`. Never reference `Boot` from `src/core/**`.
- Guardrail: Data load `Unloaded → Ready` ≤ `data_load_budget_ms` 200 (expected < 50 ms), synchronous at boot.

---

## Acceptance Criteria

*From GDD `design/gdd/card-database.md` (CR-1, CR-5 stages 1–3, Edge Cases "Versions and files", "Performance and standards"), scoped to this story:*

- [ ] **GIVEN** `DataLoader.FILE_MANIFEST`, **THEN** it carries one row `{name, class, record_type, required, owner}` per DD-T01 / CR-1 file — definition: `cards_<set>.json` (`war`, `neutral`, `boss` required; `decay`, `knowledge`, `fortune`, `order`, `shadow` optional), `heroes`, `hero_powers`, `bosses`, `treasures`, `bundles`; config: `match_rules`, `card_effects`, `ai_profiles`, `run_structure`, `reward_draft`, `treasures_balance`, `heroes_balance`, `match_ui`, `run_ui`, `profile_defaults`, `card_database`, `content_budgets`, `rng_event_log` — and **GIVEN** a fixture root where `card_database.json` is missing, **WHEN** loading, **THEN** `E_MISSING_FILE` names it (no built-in defaults path) and state is `Failed`; **GIVEN** an unexpected `.json` in the root, **THEN** `W_UNKNOWN_FILE` names it and it is not loaded.
- [ ] **GIVEN** a file with malformed JSON, **WHEN** loading, **THEN** the report contains `E_PARSE` naming the file and a non-zero line (and the parser's message where it gives one), and the pipeline continues to the other files (no fail-fast); report entries have the shape `{severity, code, file, record_id|null, field|null, message}` and `entries()` is sorted by file then record id.
- [ ] **GIVEN** a file whose `schema_version` is 0, and another run where it is 2, **WHEN** loading, **THEN** each produces `E_SCHEMA_VERSION` with found and expected (1) values and state `Failed`; **GIVEN** a definition file whose `records` is not an array, or a config file carrying `records` instead of `config`, **THEN** `E_PARSE` names the file.
- [ ] No hardcoded values / single parser: `SCHEMA_VERSION_CURRENT` is the one declared code constant (`TestConstants.SCHEMA_VERSION_CURRENT` mirrors it), and a grep-based test asserts that no file under `src/` outside `src/core/data/` contains `FileAccess.open("res://assets/data/`, `JSON.parse_string`, `JSON.new().parse` or `load("res://assets/data/`.

---

## Implementation Notes

*Derived from ADR-0002 Decision 1–3 and Implementation Guidelines:*

- Create `src/core/data/validation_report.gd` (`class_name ValidationReport extends RefCounted`): `add(severity: StringName, code: StringName, file: String, record_id: Variant, field: Variant, message: String)`, `entries() -> Array[Dictionary]` (sorted by file, then record id), `errors()`, `warnings()`, `has_errors()`, `to_text()` (what the `data_error` screen and the validate command print).
- Create `src/core/data/data_loader.gd` (`class_name DataLoader extends RefCounted`): `const SCHEMA_VERSION_CURRENT: int = 1`; `const FILE_MANIFEST: Array[Dictionary]` mirroring the CR-1 table in CR-1 order (the fingerprint in Story 007 walks it in this order — keep the order stable); `_init(root: String = "res://assets/data/")` so tests point it at `tests/fixtures/data/<case>/`; `run(validators: Dictionary) -> LoadResult` (`{report: ValidationReport, snapshot: Dictionary|null}`). Discover files **by manifest name**, never `DirAccess` listing for loading; list the directory only to raise `W_UNKNOWN_FILE`.
- Stage 2: `FileAccess.open(root + name, FileAccess.READ)`; `null` → `E_MISSING_FILE` with `FileAccess.get_open_error()` in the message (only an error for `required: true` rows; an optional set file that is absent is silently skipped). Text → `JSON.new()`, `parse(text)`; on a non-OK result add `E_PARSE` with `get_error_line()` and `get_error_message()`.
- Stage 3: `schema_version` must equal `SCHEMA_VERSION_CURRENT` (older **and** newer fail — offline migration lives in `tools/`, never here); a definition file needs `records` as an Array, a config file `config` as a Dictionary, else `E_PARSE`. A file that fails stage 2 or 3 is excluded from later stages; the rest continue.
- Create `src/core/data/card_database.gd` (`class_name CardDatabase extends RefCounted`): `enum State { UNLOADED, LOADING, READY, FAILED, RELOADING }`, `_init(loader: DataLoader = null)`, `load(validators: Dictionary) -> ValidationReport`, `state()`, `report()`. In this story `load()` runs the loader and sets `FAILED` on any error, `READY` on none (the freeze and `index_of` come in Story 006; keep a clear seam). Stages 4–8 are added by Stories 002–005; wire the stage sequence now so each later story slots one stage in.
- Use the `JSON.parse_string` → `float` caveat: coerce `schema_version` with `int()` before comparing.
- Fixtures: `tests/fixtures/data/<case>/` holding small JSON sets built from `CardFactory.make_definition_file` / `make_config_file`; never the shipped data. Every fixture root used by a "clean" case must contain **every required manifest file** or `E_MISSING_FILE` fires — build a `make_minimal_root()` helper in the test suite (or a committed `tests/fixtures/data/minimal/`) and derive the broken cases from it.
- The grep gate test shells out through `OS.execute("rg", …)` or walks `src/` with `DirAccess` + `FileAccess` **from the test** (tests may read files; `src/core/data/` is the only production reader of `assets/data/`).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: per-record schema checks (stage 4) and the `card_database.json` knob self-check.
- Story 003: id uniqueness and cross-references (stages 5–6).
- Story 004: delegated validators and the stage-7 lookup exception.
- Story 006: freeze, `index_of`, CR-6 queries and `config(name)`.
- Story 007: `data_version`.
- Story 008: `Reloading`, `E_NOT_LOADED`, `E_NOT_SUPPORTED`.
- Boot epic: `Boot.boot()` constructing `CardDatabase` and calling `load(validators)`.
- Content epic: `tools/content/validate.gd` (CN-6.3) and the shipped `assets/data/*.json`.

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the planned ones; `/dev-story` replaces the list with the files it changed; `/story-done` checks scope against it.*

- `src/core/data/validation_report.gd`
- `src/core/data/data_loader.gd`
- `src/core/data/card_database.gd`
- `tests/fixtures/data/minimal/*.json` (one file per required manifest row)
- `tests/fixtures/data/parse_error/`, `tests/fixtures/data/schema_version_0/`, `tests/fixtures/data/schema_version_2/`, `tests/fixtures/data/unknown_file/`, `tests/fixtures/data/missing_config/`
- `tests/unit/card_database/card_database_pipeline_test.gd`
- `tests/unit/card_database/card_database_parse_error_test.gd`
- `tests/unit/card_database/card_database_single_parser_test.gd` (grep gate)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: `standard` — Logic tests are BLOCKING.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/card_database/card_database_pipeline_test.gd`, `tests/unit/card_database/card_database_parse_error_test.gd`, `tests/unit/card_database/card_database_single_parser_test.gd` — must exist and pass (`/story-done` checks that they EXIST; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (first story of the epic; `tests/helpers/card_factory.gd` and `test_constants.gd` already exist)
- Unlocks: `production/epics/card-database/story-002-record-schema-validation.md`, `production/epics/card-database/story-003-uniqueness-and-cross-references.md`
