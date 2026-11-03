# Story 008: State machine, visible failure and debug `reload()` (States table, CR-8)

> **Epic**: Card Database
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-03

## Context

**GDD**: `design/gdd/card-database.md`
**Requirement**: `TR-card-database-002` (CR-8: a Failed load has no main menu; the full pipeline collects every error)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Data format, effect schema/DSL and `config()` loading (Decision 7–8); ADR-0001: Rules / Presentation Split (`Boot` hands the report to the scene root; `CardDatabase` never touches a Node); ADR-0011: Run UI shell (consumes the report as the `data_error` read model)
**ADR Decision Summary**: `load()` returns the `ValidationReport`; on errors `state()` is `Failed` and there is no "load what passed" path — `Boot` hands the report to `RunShell` for the `data_error` screen and the headless validate command prints it and exits 1. `reload()` builds a new snapshot in a debug build and swaps it atomically on success (a match holds the handle it started with); on failure the previous snapshot stays active; in release it returns `E_NOT_SUPPORTED`.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (ADR-0002 knowledge risk generally; `OS.is_debug_build()`, `push_error` are pre-4.4, LOW)
**Engine Notes**: `OS.is_debug_build()` gates `reload()` only — it must **not** relax the missing-validator rule (Story 004). `assert()` is stripped in release; every "debug assert" here sits beside a release-safe `null`/empty return.

**Control Manifest Rules (this layer)**:
- Required: `load()` failure is visible (`state() == Failed`, `data_error` screen, validate command exits 1). `reload()` builds a new snapshot and swaps atomically in debug builds; returns `E_NOT_SUPPORTED` in release. Scene roots are the only non-test callers of `Boot.services()`; `CardDatabase` is composed by `Boot` and injected.
- Forbidden: Never `assert()` on data or throw in release paths. Never reference `Boot` or `Services` from `src/core/**` (minus `boot.gd`, `services.gd`, `boot_result.gd` and `##` doc-comment lines — G3 erratum 2026-11-03). Never a service-locator autoload.
- Guardrail: `reload()` in debug briefly holds two snapshots (≤ 2 × `data_memory_budget_mb`).

---

## Acceptance Criteria

*From GDD `design/gdd/card-database.md` (States and Transitions, CR-8, Edge Cases "Runtime", Acceptance Criteria "Loading and failure", "Delegation and runtime"), scoped to this story:*

- [ ] **GIVEN** three files each with one distinct error (a parse error, an unknown keyword, a missing starter-deck card), **WHEN** loading, **THEN** all three errors appear in one report (no fail-fast), state is `Failed`, `report()` holds the full report, `ValidationReport.to_text()` lists every entry with file, record id, field and code, and no record is queryable (`card(id)` is `null`, every pool is empty).
- [ ] **GIVEN** a database in `Unloaded` or `Failed`, **WHEN** any query, `config(name)` or `data_version()` is called, **THEN** a release build returns `null` / empty / `""` and logs `E_NOT_LOADED` once per call, and a debug build asserts; **GIVEN** `load()` is called a second time on a `Ready` release database, **THEN** nothing changes (a release build loads exactly once per process).
- [ ] **GIVEN** a debug build in `Ready` with a consumer holding the snapshot handle it started with (a match in progress), **WHEN** a card's `attack` is edited in the fixture root and `reload()` is called, **THEN** the state passes through `Reloading` to `Ready`, the consumer's handle still reads the old value, a fresh `card(id)` reads the new one, and the returned report names the record count; **GIVEN** a release build, **WHEN** `reload()` is called, **THEN** it returns a report whose single entry is `E_NOT_SUPPORTED` and the state is unchanged.
- [ ] **GIVEN** a debug build in `Ready`, **WHEN** `reload()` runs against a root with a parse error, **THEN** the previous snapshot remains queryable (`state()` returns to `Ready`, `data_version()` unchanged) and the new report is returned by `reload()` and exposed as `last_reload_report()` for the debug overlay; **GIVEN** a debug build in `Failed`, **WHEN** `reload()` succeeds, **THEN** state is `Ready`.

---

## Implementation Notes

*Derived from ADR-0002 Decision 7–8 and card-database States table:*

- State transitions, exactly: `UNLOADED → LOADING` on `load()`; `LOADING → READY | FAILED`; `READY | FAILED → RELOADING` on `reload()` in a debug build only; `RELOADING → READY` (success: swap `_snapshot` to the new one) or back to the previous state (`READY` keeps the old snapshot; `FAILED` stays `FAILED`). `READY → LOADING` never happens: a second `load()` in release is a no-op returning the existing report; in debug it may be treated as `reload()` — document which in the code comment.
- Snapshot handle semantics: the snapshot is one `RefCounted`/Dictionary; `reload()` builds a **new** object and replaces `_snapshot` atomically (single assignment). A consumer that captured the old object (e.g. `MatchDriver` holding `db.snapshot_handle()` at match start, or simply a record Dictionary) keeps reading the old data. Expose a minimal `snapshot_handle() -> Dictionary` (frozen) so a running match can pin it; the GDD says "a match in progress keeps the snapshot handle it started with" — the pinning is the match's job, this story only guarantees the old object is never mutated.
- `E_NOT_LOADED`: one `push_error` per illegal call naming the method and the state; debug `assert`. The stage-7 exception (Story 004) is the only time `Loading` answers lookups.
- `E_NOT_SUPPORTED`: `reload()` when `not OS.is_debug_build()` returns a `ValidationReport` with one entry `{severity: error, code: E_NOT_SUPPORTED, file: "", …}` and touches nothing.
- `ValidationReport.to_text()`: one line per entry, `[severity] code file#record_id.field — message`, errors first then warnings, in `entries()` order — this is the text the `data_error` screen (Run UI, ADR-0011 S2) and `tools/content/validate.gd` (content epic) print; keep it stable.
- CR-8's "desktop build shows the data-error screen instead of the main menu; headless exits non-zero" is verified end to end by the boot / run-ui / content epics; this story delivers the contract they rely on: `load()` returns the report, `state() == FAILED`, `report().has_errors()`, `to_text()`.
- Tests: debug-vs-release paths — gdUnit4 runs in a debug (editor) build, so test the release branch by injecting the build flag (`DataLoader._init(root, is_debug: bool = OS.is_debug_build())` or a `set_debug_build(bool)` test hook on `CardDatabase`) rather than relying on `OS.is_debug_build()` directly. The reload fixture edits a copy of the root under `user://` or a scratch dir the test creates and removes (integration-style cleanup inside the unit test is acceptable here; the test owns the files).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Run UI epic: the `data_error` screen rendering `to_text()` and the debug overlay showing the reload report / record count.
- Boot epic: `Boot.boot()` routing a `Failed` report to `RunShell` and never composing the main menu over it.
- Content epic: `tools/content/validate.gd` exit 0 / 1 / 2.
- Story 006: the queries themselves.

---

## Files

- `src/core/data/card_database.gd` (state machine; `_init(loader, debug_build = OS.is_debug_build())`; second `load()` a no-op; `reload()`; `E_NOT_LOADED` log + debug assert for every query, `config`, `data_version`, `snapshot_handle` outside `Ready`; `snapshot_handle()`; `last_reload_report()`; `NOT_LOADED_MESSAGE`; asserts gated on the injected flag)
- `src/core/data/validation_report.gd` (`to_text()` format; `E_NOT_LOADED`, `E_NOT_SUPPORTED`; `record_count()` / `set_record_count()`)
- `src/core/data/data_loader.gd` (stage 9 sets the report's record count)
- `tests/fixtures/data/three_errors/` (new: copy of `clean/`; `match_ui.json` unparseable, `neutral_bog_lurker` keyword `bogus`, `hero_war.starter_deck[14]` → `neutral_ghost`)
- `tests/unit/card_database/card_database_state_machine_test.gd` (new, 15 tests)
- `tests/unit/card_database/card_database_reload_test.gd` (new, 9 tests)
- Contract fixes ([C] story): `tests/unit/card_database/card_database_pipeline_test.gd` (`to_text` test → new format, renamed `test_report_to_text_lists_each_entry`), `tests/unit/card_database/card_database_fingerprint_test.gd` (two not-Ready tests → `E_NOT_LOADED` message, release-flagged db)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: `standard` — Logic tests are BLOCKING.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/card_database/card_database_state_machine_test.gd`, `tests/unit/card_database/card_database_reload_test.gd` — must exist and pass (`/story-done` checks that they EXIST; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] Created and passing (2026-11-03: 15 + 9 tests; full suite 856/856)

---

## Dependencies

- Depends on: `production/epics/card-database/story-006-freeze-and-queries.md`
- Unlocks: `production/epics/card-database/story-010-shipped-data-and-export-inclusion.md`; the boot epic's `data_error` routing; the content epic's `tools/content/validate.gd` story (reads `to_text()` and `state()`)

---

## Completion Notes
**Completed**: 2026-11-03 (started 23:09:15 UTC, ended 23:16:18 UTC, both by `date -u`)
**Verification**: `godot --headless --path . --import` exit 0; parse check of the 7 changed scripts exit 0; `commands.test` 856 test cases, 0 errors, 0 failures, exit 0 (also 0 failures with `-c`); the only new SCRIPT ERRORs are the 40 intentional debug-branch `Assertion failed: E_NOT_LOADED …` lines; `commands.smoke` exit 0, no SCRIPT ERROR; the reload tests' `user://cdb2_reload_test/` scratch root is gone after the run. Seen failing first: both suites failed to parse before `CardDatabase.new(loader, debug_build)` existed; mutations, one per run, each turned the named tests red — release guard removed from `reload()` (`test_release_reload_returns_e_not_supported_and_changes_nothing`), second `load()` re-runs (both second-load tests), failed reload from `Ready` drops the snapshot (`test_debug_reload_with_a_parse_error_keeps_the_previous_snapshot`), `to_text()` in plain `entries()` order (`test_to_text_is_one_line_per_entry_errors_first_in_entries_order`).
**Criteria**: 4/4 passing (none deferred)
- AC-1 — `card_database_state_machine_test.gd`: `test_three_files_with_one_error_each_give_one_report_with_all_three` (exactly the three errors, `Failed`, `report()` is the returned report), `test_three_errors_report_text_lists_each_entry_with_file_record_field_and_code`, `test_failed_database_answers_no_query_in_a_release_build` / `…_asserts_on_a_query_in_a_debug_build` (`card(id)` null, every pool empty), `test_to_text_*` (2), `test_failed_report_has_no_record_count`
- AC-2 — `test_unloaded_database_answers_no_query_in_a_release_build`, `test_unloaded_database_asserts_on_a_query_in_a_debug_build` (all 17 queries + `config`, `data_version`, `snapshot_handle`; one `E_NOT_LOADED` each), `test_second_load_on_a_ready_release_database_changes_nothing`, `test_second_load_on_a_debug_database_is_also_a_no_op`, `test_unknown_id_in_ready_is_not_an_e_not_loaded_error`, `test_load_passes_through_loading_to_ready`
- AC-3 — `card_database_reload_test.gd`: `test_debug_reload_swaps_in_the_edited_value_and_the_held_handle_keeps_the_old`, `test_debug_reload_passes_through_reloading`, `test_debug_reload_report_names_the_record_count`, `test_debug_reload_changes_data_version_when_a_value_changes`, `test_release_reload_returns_e_not_supported_and_changes_nothing`; `card_database_state_machine_test.gd::test_snapshot_handle_in_ready_is_the_frozen_snapshot`, `test_ready_report_names_the_record_count`
- AC-4 — `test_debug_reload_with_a_parse_error_keeps_the_previous_snapshot` (`Ready`, `data_version()` unchanged, `last_reload_report()`), `test_debug_reload_from_failed_that_succeeds_is_ready`, `test_debug_reload_from_failed_that_fails_stays_failed_with_the_new_report`
**Deviations**:
- ADVISORY — **`to_text()` has no header line now** ("one line per entry", Implementation Notes); the count line the story-002 format printed is gone, so the `data_error` screen / validate command print their own summary (`errors().size()`, `warnings().size()`, `record_count()`). Fields without a record id render `file.field` (e.g. `heroes.json.schema_version`).
- ADVISORY — "the returned report names the record count": `ValidationReport.record_count()` (set by the loader at stage 9, `-1` when the load did not freeze) rather than a report entry — the six-key entry shape has no info severity.
- ADVISORY — a second `load()` is a no-op in a debug build too (the story allowed "may be treated as reload()"; documented in the class doc). `reload()` before any finished `load()` returns a one-entry `E_NOT_LOADED` report (not specified by the story).
- ADVISORY — after a failed reload from `Failed`, `report()` becomes the new report (the data-error screen shows the latest); from `Ready` it keeps the active snapshot's warnings-only report and the new one is `last_reload_report()`.
- ADVISORY — build type injected as `CardDatabase._init(loader, debug_build = OS.is_debug_build())`; it also gates the existing unknown-id and stage-7 asserts (behaviour in a real debug build unchanged). `has()` logs `E_NOT_LOADED` before `Ready` (AC-2 "any query"), which is where the 006 review's preference "`has()` never logs" stops: it never logs for an unknown id.
- OUT OF SCOPE (not implemented, flagged) — control manifest Core layer: "`CardDatabase.reload()` returns `E_BUSY` while any `PlannerTask` is live" (ADR-0006) has no story here; `reload()` does not check planners.
- OUT OF SCOPE (directed, [C] story) — contract fixes in `card_database_pipeline_test.gd` and `card_database_fingerprint_test.gd`.
**Test Evidence**: `tests/unit/card_database/card_database_state_machine_test.gd`, `tests/unit/card_database/card_database_reload_test.gd`
**Run result**: N/A — the database draws nothing; the `data_error` screen that renders `to_text()` and the reload overlay are Run UI / boot epic stories
**Reviewed by**: self, no independent review (QL-TEST-COVERAGE / LP-CODE-REVIEW skipped — Lean mode; `/code-review` due at M2)
