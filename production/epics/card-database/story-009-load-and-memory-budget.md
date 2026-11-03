# Story 009: Load and memory budget test (Formulas "Validation cost and load budget")

> **Epic**: Card Database
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-11-03
> **Last Updated**: — (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/card-database.md`
**Requirement**: `TR-card-database-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Data format, effect schema/DSL and `config()` loading (Performance Implications; Validation Criteria `card_database_load_budget_test.gd`)
**ADR Decision Summary**: One synchronous parse plus ~900 O(1) checks at v1; budget `data_load_budget_ms` 200, expected < 50 ms; frozen snapshot ≤ `data_memory_budget_mb` 4; the data load runs at boot ahead of the profile load and is the one place a boot stall can originate. `Unloaded → Ready` ≤ 200 ms on the reference machine is `NOT SOURCEABLE` and proven by this test.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (ADR-0002 knowledge risk generally; `Time.get_ticks_usec()`, `OS.get_static_memory_usage()` / `Performance.get_monitor(Performance.MEMORY_STATIC)` are pre-4.4, LOW)
**Engine Notes**: ADR-0002 Verification Required item 5 — the budget on the reference machine. Static-memory deltas on Godot are coarse (allocator pools); measure the delta across `load()` after a `GC`-free warm-up and treat a result within the budget as the pass condition, logging both numbers as the GDD requires. CI (llvmpipe, shared runner) is slower than the target hardware; the threshold is the knob's value, the expected figure is < 50 ms.

**Control Manifest Rules (this layer)**:
- Required: Tests under `tests/unit/**` construct rules objects directly, never through `Boot`.
- Forbidden: Never hardcode `data_load_budget_ms` or `data_memory_budget_mb` in the test — read them from `config("card_database")` after the load (or `TestConstants.DATA_LOAD_BUDGET_MS` / `DATA_MEMORY_BUDGET_MB`, which must mirror the shipped `card_database.json`).
- Guardrail: Data load (`Boot.boot()` → `CardDatabase` `Unloaded → Ready`) ≤ `data_load_budget_ms` 200 (expected < 50 ms), synchronous at boot; frozen snapshot ≤ `data_memory_budget_mb` 4.

---

## Acceptance Criteria

*From GDD `design/gdd/card-database.md` (Formulas "Validation cost and load budget", States `Loading`, Acceptance Criteria "Performance and standards"), scoped to this story:*

- [ ] Performance: **GIVEN** the shipped MVP data set under `assets/data/` (release build, SSD, target hardware — CI is the floor, the owner's machine the reference), **WHEN** `load()` runs with the full validator map, **THEN** `Unloaded → Ready` completes in ≤ `data_load_budget_ms` (200 ms) measured with `Time.get_ticks_usec()` around `load()`, and the test fails above the threshold and logs the measured milliseconds.
- [ ] **GIVEN** the same load, **THEN** the frozen snapshot's resident size (static-memory delta across `load()`, or a canonical-JSON byte count of the snapshot as the documented proxy if the delta is not measurable headlessly) is ≤ `data_memory_budget_mb` (4 MB), the test fails above it and logs the measured number.
- [ ] **GIVEN** `load()` is called from the test's main thread, **THEN** it returns only after `state()` is `Ready` or `Failed` (synchronous — no `await`, no thread, no signal), and the measured `validation_checks = n_records + n_refs` count the loader reports in debug matches the Formulas estimate for the data set within the test's tolerance (logged, not asserted as an exact number).

---

## Implementation Notes

*Derived from ADR-0002 Performance Implications and Validation Criteria:*

- `tests/unit/card_database/card_database_load_budget_test.gd`: construct `DataLoader.new("res://assets/data/")` and `CardDatabase.new(loader)` directly; inject `ValidatorStubs.accept_all()` **plus** the real validators that exist at the time (start with stubs; `/dev-story` notes which real validators were in the map — the budget must hold with the real ones too, so re-run when Card Effects lands its validator). Warm up once with a throwaway load against the same root (file cache), then time the measured load.
- Read the thresholds from `db.config("card_database")` after the load; add `TestConstants.DATA_LOAD_BUDGET_MS` / `DATA_MEMORY_BUDGET_MB` mirroring the shipped file (each constant names its source, per the helper's convention).
- Memory: `Performance.get_monitor(Performance.MEMORY_STATIC)` before and after; if the delta is unusable headlessly, document the proxy (`DataLoader.canonical_json(snapshot).length()`) in the test's doc comment and the story close-out. Either way, log both numbers with `print_rich`/gdUnit4 reporting so the figure is in the CI artifact.
- Synchronous: no `await` in `load()`; assert `state()` immediately after the call.
- Debug counters: have `DataLoader` count records and references checked (`n_records`, `n_refs`) into the `LoadResult` for the test to log; cheap integers, no behaviour change.
- This test runs against the **shipped** data, so it is skipped (gdUnit4 `@warning_ignore`/skip with reason) until `assets/data/` holds the content MVP-0 batch — keep the skip reason explicit so `/smoke-check` sees why.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Content epic: authoring `assets/data/*.json` (MVP-0 / MVP-1 batches).
- Story 010: `Boot`-driven load on the shipped set and the exported-build smoke check.
- Boot epic: where in the boot sequence the load runs (ahead of the profile load).

---

## Files

- `src/core/data/data_loader.gd` (debug `n_records` / `n_refs` counters in `LoadResult`)
- `tests/helpers/test_constants.gd` (`DATA_LOAD_BUDGET_MS`, `DATA_MEMORY_BUDGET_MB`)
- `tests/unit/card_database/card_database_load_budget_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: `standard` — Logic tests are BLOCKING. Performance tests must specify acceptable thresholds and fail if exceeded (`.claude/rules/test-standards.md`).*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/card_database/card_database_load_budget_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later); the logged numbers from the owner's reference machine go in the close-out note.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/card-database/story-006-freeze-and-queries.md`; content epic MVP-0 batch story (the shipped `assets/data/` set — path assigned by `/create-stories content`)
- Unlocks: `production/epics/card-database/story-010-shipped-data-and-export-inclusion.md`
