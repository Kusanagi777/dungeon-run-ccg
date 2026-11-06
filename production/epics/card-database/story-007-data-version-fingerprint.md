# Story 007: `data_version` fingerprint (CR-9)

> **Epic**: Card Database
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-03

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

- `src/core/data/data_loader.gd` (`canonical_json`, `fingerprint`, `_records_in_id_order`, stage 9 `snapshot.data_version`)
- `src/core/data/card_database.gd` (`data_version()` reads `snapshot.data_version`; `_data_version` field removed)
- `tests/fixtures/data/fingerprint/` (new: byte copy of `clean/`, every required file, no optional set file)
- `tests/fixtures/data/fingerprint_reordered/` (new: same parsed content, `records` reversed, keys reversed at every depth, 4-space indent)
- `tests/fixtures/data/fingerprint_changed/` (new: `war_shield_bearer.attack` 1 → 2)
- `tests/unit/card_database/card_database_fingerprint_test.gd` (new, 18 tests)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: `standard` — Logic tests are BLOCKING.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/card_database/card_database_fingerprint_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later). The epic's Definition of Done additionally requires the known-answer string to match on the owner's Windows machine — record that run in the story's close-out.

**Status**: [x] Created and passing (2026-11-03: 18 tests; full suite 832/832)

---

## Dependencies

- Depends on: `production/epics/card-database/story-006-freeze-and-queries.md`
- Unlocks: `production/epics/card-database/story-010-shipped-data-and-export-inclusion.md`; `rng-event-log` stories that take `data_version` in `RngService.snapshot()`

---

## Completion Notes
**Completed**: 2026-11-03 (started 23:01:05 UTC, ended 23:07:32 UTC, both by `date -u`)
**Verification**: `godot --headless --path . --import` exit 0; parse check of the three changed scripts exit 0; `commands.test` 832 test cases, 0 errors, 0 failures, exit 0 (only the intentional negative-test errors); `commands.smoke` exit 0, no SCRIPT ERROR. Seen failing first: the suite did not parse before `canonical_json` / `fingerprint` existed; mutation "hash the parsed body without id-sorting `records`" turned 4 tests red (reordered equality, known answer, static = loaded, record order), mutation "drop the `name` update" turned 3 red (known answer, static = loaded, SHA-256 KAT).
**Criteria**: 3/3 passing (none deferred)
- AC-1 — `test_reordered_root_gives_identical_query_sequences`, `test_reordered_root_gives_the_same_data_version`, `test_data_version_is_sixteen_lowercase_hex_characters`, `test_one_attack_changed_by_one_gives_a_different_data_version`, `test_reordered_fixture_really_differs_in_record_order_keys_and_whitespace` (guards against a vacuous fixture)
- AC-2 — `test_data_version_of_the_fingerprint_root_is_the_known_answer`, `test_static_fingerprint_over_the_same_bodies_equals_data_version`, `test_static_fingerprint_is_sha256_of_name_then_canonical_body`, `test_static_fingerprint_depends_on_entry_order`, `test_canonical_json_*` (2)
- AC-3 — `test_data_version_when_unloaded_returns_empty_with_one_logged_error`, `test_data_version_when_failed_returns_empty_with_one_logged_error` (stage 7: `card_database_validators_test.gd::test_data_version_during_stage_7_returns_empty_and_the_guard_fires`, story 004), `test_fingerprint_covers_only_the_files_loaded`, `test_snapshot_carries_the_data_version`, `test_version_key_matcher_finds_an_authored_version_key`, `test_no_fixture_or_shipped_data_file_authors_a_version_string`
**Known answer**: `fingerprint/` → `4667ce6e5d01302f`, recorded 2026-11-03 on Linux x86_64, Godot 4.7.2.stable.official.ed1daf0bf (the CI container). It was computed first by an independent Python reference (`hashlib.sha256` over `name` + compact sorted-key JSON with numbers as `N.0`, records id-sorted, manifest order) and the first green run matched it; SHA-256("abc") from `HashingContext` also matched the published digest. **Open: the epic Definition of Done's re-check on the owner's Windows machine** — run `card_database_fingerprint_test.gd` there and record the result here.
**Engine finding** (closes the Linux half of ADR-0002 Verification Required item 2): on 4.7.2 `JSON.stringify(v, "", true, true)` is compact (no spaces), sorts keys at every depth, keeps list order, renders a parsed (float) `2` as `2.0`, an int as `2`, `0.1` as `0.1`, `1e20` as `1e+20`, non-ASCII unescaped; a read-only container serialises like a writable one.
**Deviations**:
- ADVISORY — **records are hashed in id order.** ADR-0002 Decision 5 hashes "the parsed body"; with that rule alone, AC-1 ("the same records authored in two different file orders … the same `data_version()`") fails — reversing a file's `records` changed the hash (observed: Python reference `b9e82f1b…` vs `71c434bd…`). `DataLoader.fingerprint` therefore sorts a definition envelope's top-level `records` by id before `canonical_json` (the CR-6 order; control manifest "never depend on file order or authoring order"); every other list (starter decks, bundle cards, effects) keeps its order. ADR-0002 Decision 5 / control manifest line 47 / CR-9 need a one-line erratum to say so (owner / technical-director; not edited here).
- ADVISORY — the test parses fixture files itself (`JSON.parse_string` in `tests/`, outside the single-parser gate, which scans `src/`) to build the static-call bodies.
**Test Evidence**: `tests/unit/card_database/card_database_fingerprint_test.gd`
**Run result**: N/A — the fingerprint is a string with no screen; it is first displayed by Treasures / Run UI (their epics)
**Reviewed by**: self, no independent review (QL-TEST-COVERAGE / LP-CODE-REVIEW skipped — Lean mode; `/code-review` due at M2) · `/code-review 2026-11-04 (independent, sprint-4 carry): APPROVED`
