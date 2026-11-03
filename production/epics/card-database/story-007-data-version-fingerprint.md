# Story 007: `data_version` fingerprint (CR-9)

> **Epic**: Card Database
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-11-03
> **Last Updated**: — (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/card-database.md`
**Requirement**: `TR-card-database-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Data format, effect schema/DSL and `config()` loading
**ADR Decision Summary**: At stage 9 the loader computes `data_version` with one `HashingContext` (`HASH_SHA256`): for each manifest row in CR-1 order, `update(name.to_utf8_buffer())` then `update(JSON.stringify(parsed_body, "", true, true).to_utf8_buffer())`; `finish().hex_encode().substr(0, 16)`. Sorted keys and no indent make key order and whitespace irrelevant; `full_precision = true` keeps any float stable. `data_version` is always derived — never authored.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (ADR-0002 knowledge risk generally; `HashingContext`, `JSON.stringify(sort_keys, full_precision)` are 4.0-era, LOW — but `NOT SOURCEABLE` from the engine reference)
**Engine Notes**: `JSON.stringify` sort_keys / compact output and `HashingContext` SHA-256 on 4.7.2 are `NOT SOURCEABLE` (ADR-0002 Verification Required item 2) — the known-answer test proves them, and the epic's Definition of Done requires the same string on Linux CI and the owner's Windows machine. JSON numbers parse as `float`: `full_precision = true` keeps `1.0` stable across platforms; CR-3 data is integer-valued by schema.

**Control Manifest Rules (this layer)**:
- Required: Freeze and fingerprint at stage 9 — compute `data_version` with one `HashingContext` (`HASH_SHA256`) over `name` + `JSON.stringify(body, "", true, true)` per manifest row in CR-1 order, `finish().hex_encode().substr(0, 16)`; `data_version` is always derived. 64-bit values cross JSON as 16-hex strings (ADR-0003 consumes `data_version` in `RngService.snapshot()`).
- Forbidden: Never author a content-version string; never depend on file order or authoring order.
- Guardrail: Data load ≤ `data_load_budget_ms` 200 — one hash pass over ~150 KB of canonical JSON.

---

## Acceptance Criteria

*From GDD `design/gdd/card-database.md` (CR-9, Acceptance Criteria "Pools and determinism"), scoped to this story:*

- [ ] **GIVEN** the same records authored in two different file orders (and with keys in a different order and different whitespace), **WHEN** both roots are loaded, **THEN** every query returns identical sequences (same ids, same order) and `data_version()` returns the same 16-character lowercase-hex string; **GIVEN** one card's `attack` then changed by 1, **WHEN** reloaded, **THEN** `data_version()` differs.
- [ ] **GIVEN** the committed fixture root `tests/fixtures/data/fingerprint/`, **WHEN** loaded, **THEN** `data_version()` equals the committed known-answer string in the test (recorded from the first green run on Linux CI; the epic's Definition of Done re-checks it on the owner's Windows machine), and `DataLoader.fingerprint(bodies)` over the same bodies returns the same string as a static call with no database.
- [ ] **GIVEN** a database that is not `Ready` (`Unloaded`, `Failed`, or inside stage 7), **WHEN** `data_version()` is called, **THEN** it returns `""` with one logged error; **GIVEN** an optional set file that is absent (e.g. no `cards_decay.json`), **THEN** the fingerprint covers only the files loaded, in manifest order, and no file contains an authored version string (a grep over the fixture and shipped data roots finds no `data_version` / `content_version` key).

---

## Implementation Notes

*Derived from ADR-0002 Decision 5 and Key Interfaces:*

- `DataLoader.canonical_json(value: Variant) -> String` = `JSON.stringify(value, "", true, true)` (indent `""`, `sort_keys = true`, `full_precision = true`). `DataLoader.fingerprint(bodies: Array[Dictionary]) -> String`: `bodies` is `[{name, body}]` in manifest order; open one `HashingContext`, `start(HashingContext.HASH_SHA256)`, per entry `update(name.to_utf8_buffer())` then `update(canonical_json(body).to_utf8_buffer())`; `finish().hex_encode().substr(0, 16)`.
- Hash the **parsed** body (the whole envelope Dictionary as parsed, including `schema_version`), not the raw text — that is what makes key order and whitespace irrelevant. Files that are absent (optional set files) are skipped; a file that failed parsing never reaches stage 9 (the load is `Failed`).
- Store the result in the snapshot (`snapshot.data_version`); `CardDatabase.data_version()` returns it only when `state() == READY`, else `""` + `push_error`.
- Known-answer test: commit `tests/fixtures/data/fingerprint/` (small, every required file) and the expected 16-hex string as a constant in the test with a comment naming the machine and date it was recorded; a second fixture `fingerprint_reordered/` with the same records in different file/key order asserts equality; a third case mutates one `attack` in memory via a loader subclass or a `fingerprint_changed/` root and asserts inequality.
- Consumers (do not implement here, but keep the contract): `RngService(run_seed, data_version)` and `snapshot()` (ADR-0003), Run Structure's run record R8, Meta's `data_versions_seen[]` (M3.5), Treasures and Run UI display.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 006: the freeze and `index_of` the fingerprint sits beside.
- Story 010: asserting `data_version()` is non-empty in an **exported** build (export inclusion).
- RNG & Event Log / Run Structure / Meta epics: storing and comparing `data_version`.

---

## Files

- `src/core/data/data_loader.gd` (`canonical_json`, `fingerprint`, stage 9)
- `src/core/data/card_database.gd` (`data_version()`)
- `tests/fixtures/data/fingerprint/`, `tests/fixtures/data/fingerprint_reordered/`, `tests/fixtures/data/fingerprint_changed/`
- `tests/unit/card_database/card_database_fingerprint_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: `standard` — Logic tests are BLOCKING.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/card_database/card_database_fingerprint_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later). The epic's Definition of Done additionally requires the known-answer string to match on the owner's Windows machine — record that run in the story's close-out.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/card-database/story-006-freeze-and-queries.md`
- Unlocks: `production/epics/card-database/story-010-shipped-data-and-export-inclusion.md`; `rng-event-log` stories that take `data_version` in `RngService.snapshot()`
