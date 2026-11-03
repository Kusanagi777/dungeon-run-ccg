# Story 008: State machine, visible failure and debug `reload()` (States table, CR-8)

> **Epic**: Card Database
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: — (set by /dev-story when implementation begins)

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
- Forbidden: Never `assert()` on data or throw in release paths. Never reference `Boot` or `Services` from `src/core/**` (minus `boot.gd`). Never a service-locator autoload.
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

- `src/core/data/card_database.gd` (state machine, `reload()`, `E_NOT_LOADED`, `E_NOT_SUPPORTED`, `snapshot_handle()`, `last_reload_report()`)
- `src/core/data/validation_report.gd` (`to_text()` format)
- `tests/fixtures/data/three_errors/`
- `tests/unit/card_database/card_database_state_machine_test.gd`
- `tests/unit/card_database/card_database_reload_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: `standard` — Logic tests are BLOCKING.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/card_database/card_database_state_machine_test.gd`, `tests/unit/card_database/card_database_reload_test.gd` — must exist and pass (`/story-done` checks that they EXIST; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/card-database/story-006-freeze-and-queries.md`
- Unlocks: `production/epics/card-database/story-010-shipped-data-and-export-inclusion.md`; the boot epic's `data_error` routing; the content epic's `tools/content/validate.gd` story (reads `to_text()` and `state()`)
