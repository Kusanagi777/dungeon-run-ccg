# Story 006: Freeze and CR-6 queries (CR-5 stage 9, CR-6, CR-7)

> **Epic**: Card Database
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-03

## Context

**GDD**: `design/gdd/card-database.md`
**Requirement**: `TR-card-database-003` (primary), `TR-card-database-001` (`config(name)` serving)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Data format, effect schema/DSL and `config()` loading
**ADR Decision Summary**: With zero errors the loader sorts every record list by id, builds `index_of` once, calls `make_read_only()` recursively on every record and config body, and the state becomes `Ready`. Queries and `config()` are pure reads on that frozen snapshot: records come back as the frozen Dictionary, pools as a frozen id-ascending Array; an unknown id or config name returns `null` and `push_error`s, never throws. Owners that need mutable copies take `duplicate(true)`.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (ADR-0002 knowledge risk generally; `Dictionary.make_read_only()` / `Array.make_read_only()` are 4.0-era, LOW — but nesting semantics are `NOT SOURCEABLE`)
**Engine Notes**: Whether `make_read_only()` applies to nested containers is `NOT SOURCEABLE` from the engine reference (ADR-0002 Verification Required item 3) — the loader walks recursively and this story's freeze test asserts a nested write is refused. The `deprecated-apis.md` `duplicate()` → `duplicate_deep()` row concerns nested *Resources*, which never occur here; plain containers use `duplicate(true)`. `assert()` is compiled out in release — the debug assert on unknown ids must sit beside the `push_error`, never replace it.

**Control Manifest Rules (this layer)**:
- Required: Freeze at stage 9 — sort every record list by id, `make_read_only()` recursively on every record and config body. Queries are pure reads on the frozen snapshot; unknown id or config name returns `null` + `push_error`. Treat every returned Dictionary/Array as read-only; a system that mutates takes `duplicate(true)` first. Read `config(<name>)` once in the owner's `_init(...)` and keep the reference.
- Forbidden: Never depend on file order or authoring order. Never call `config()` per frame, per command or per hook invocation. Never `assert()` on data or throw in release paths.
- Guardrail: Frozen snapshot ≤ `data_memory_budget_mb` 4; lookups O(1) via `index_of`, no allocation.

---

## Acceptance Criteria

*From GDD `design/gdd/card-database.md` (CR-5 stage 9, CR-6, CR-7, Formulas "Lookup", Acceptance Criteria), scoped to this story:*

- [x] **GIVEN** a fixture with 4 War cards (one token), 3 neutral cards and 2 boss-set cards, **WHEN** `collectible_pool("war")` is called on a `Ready` database, **THEN** it returns exactly the 6 non-token War+neutral cards sorted by id ascending; `cards_by_set` / `cards_by_type` / `cards_by_tag` / `cards_by_cost` / `cards_by_rarity` include tokens and are id-ascending; `bundle_pool("war")` is `set ∈ {war, neutral}`; `treasure_pool()`, `bosses_in_band(band)` and `heroes()` (locked included) are id-ascending regardless of file order.
- [x] **GIVEN** a `Ready` database, **WHEN** `card("no_such_id")` is called, **THEN** it returns `null` and logs one error line, and in a debug build an assert fires; `has("no_such_id")` is `false`; `card(id)` for a known id is `records[index_of[id]]` — O(1), no allocation — and the same Dictionary instance on every call.
- [x] **GIVEN** a loaded fixture root containing every manifest config file, **WHEN** loaded, **THEN** `config("match_rules")`, `config("card_effects")`, `config("ai_profiles")`, `config("run_structure")`, `config("reward_draft")`, `config("treasures_balance")`, `config("heroes_balance")`, `config("match_ui")`, `config("run_ui")`, `config("profile_defaults")`, `config("card_database")`, `config("content_budgets")` and `config("rng_event_log")` each return a non-null frozen Dictionary, and `config("no_such")` returns `null` with one logged error.
- [x] **GIVEN** a `Ready` database, **WHEN** a test writes to a returned record, to a nested `effects[0]` inside it, to an element of a returned pool Array and to a returned config body, **THEN** every write is refused (read-only) and `duplicate(true)` of the record yields a writable copy; `report()` holds warnings only after a clean load.

---

## Implementation Notes

*Derived from ADR-0002 Decision 5–6, Key Interfaces and Implementation Guidelines; card-database Formulas "Lookup":*

- Stage 9 (in `DataLoader.run`): only when `report.has_errors() == false`. Take the staged per-type lists from Story 003 (already id-sorted), build the snapshot `{records_by_type, index_of, config_bodies, report}`; walk every record Dictionary and every config body recursively (`Dictionary` → each value; `Array` → each element) calling `make_read_only()` bottom-up, then on the containers themselves and on the per-type Arrays. `data_version` is added to the snapshot by Story 007 — leave the key present and empty here.
- `CardDatabase.load()` swaps `_snapshot` in and sets `READY`; on errors `_snapshot` stays `null` and the state is `FAILED`.
- Queries, exactly the Key Interfaces set: `card/hero/hero_power/boss/treasure/bundle(id) -> Dictionary` (frozen record or `null` + `push_error("E_NOT_LOADED"...)`-class message naming the id); `has(id) -> bool`; `cards_by_set/type/tag/cost/rarity -> Array`; `collectible_pool(hero_set)` (`set ∈ {hero_set, neutral}`, `token == false`, `boss` never); `bundle_pool(hero_set)`; `treasure_pool()`; `bosses_in_band(band)`; `heroes()`; `config(name) -> Dictionary`; `report()`; `state()`. Pools return a frozen Array — precompute the common ones at freeze (per hero set present, per band) so a query is a lookup, not a filter; the `cards_by_*` filters may compute on demand and freeze the result (they are not hot paths — Reward Draft calls them per draft, not per frame).
- The lookup source accessor from Story 004 now returns the frozen snapshot when `state() == READY` and the staged lists only while `_stage7_lookups_open`.
- Unknown id: `push_error` once, `assert(false, ...)` guarded so release builds still return `null` (the GDD: "callers that must have a record assert in debug").
- Freeze test writes: `record["cost"] = 9`, `record["effects"][0]["op"] = "x"`, `pool[0] = {}`, `config_body["k"] = 1` — assert each leaves the value unchanged and emits the engine's read-only error (use `GdUnitTestSuite` error-expectation helpers or compare before/after).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 007: `data_version()` and `fingerprint`.
- Story 008: `E_NOT_LOADED` for queries in `Unloaded` / `Failed`, `reload()` swapping snapshots.
- Story 009: measuring the snapshot's resident size against `data_memory_budget_mb`.
- Consumers (Match Rules, Reward Draft, Run Structure, UI): they take `duplicate(true)` when they need mutable copies; nothing here provides mutable views.

---

## Files

- `src/core/data/data_loader.gd` (stage 9 freeze: `_freeze`, `_freeze_deep`, precomputed pools; `in_collectible_pool` / `in_bundle_pool`; staging key `records` → `records_by_type`)
- `src/core/data/card_database.gd` (CR-6 queries over the frozen snapshot, `config` from `config_bodies`, unknown-id assert in `Ready`, snapshot swap)
- `tests/fixtures/data/pools/` (new: 4 War incl. one token, 3 neutral, 2 boss cards; 2 heroes incl. a locked one; bosses in bands 1-2; every manifest config file)
- `tests/unit/card_database/card_database_queries_test.gd` (new, 22 tests)
- `tests/unit/card_database/card_database_freeze_test.gd` (new, 9 tests)
- Contract fixes ([C] story): `src/gameplay/meta/meta_stub.gd` (db typed `CardDatabase`), `tests/unit/boot/boot_meta_stub_test.gd` (`FakeCardDatabase extends CardDatabase`), `tests/integration/boot/boot_composition_test.gd` (`ConfigCardDatabase` workaround removed), `tests/unit/card_database/card_database_pipeline_test.gd`, `tests/unit/card_database/card_database_references_test.gd`, `tests/integration/boss_ai/boss_ai_profiles_data_test.gd`, `tests/integration/match_rules/match_rules_config_file_test.gd`, `tests/integration/rng_event_log/event_log_config_file_test.gd` (snapshot shape)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: `standard` — Logic tests are BLOCKING.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/card_database/card_database_queries_test.gd`, `tests/unit/card_database/card_database_freeze_test.gd` — must exist and pass (`/story-done` checks that they EXIST; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] Created and passing (2026-11-03: 22 + 9 tests; full suite 724/724)

---

## Dependencies

- Depends on: `production/epics/card-database/story-004-delegated-validators.md`, `production/epics/card-database/story-005-budget-warnings-and-pool-thresholds.md`
- Unlocks: `production/epics/card-database/story-007-data-version-fingerprint.md`, `production/epics/card-database/story-008-state-machine-and-debug-reload.md`, `production/epics/card-database/story-009-load-and-memory-budget.md`; every consumer epic's first story that reads `card()` / `config()`

---

## Completion Notes
**Completed**: 2026-11-03 (started 22:21:46 UTC, ended 22:35:01 UTC, both by `date -u`)
**Verification**: `godot --headless --path . --import` exit 0; `commands.test` 724 test cases, 0 errors, 0 failures, exit 0 (only the intentional negative-test SCRIPT ERRORs); `commands.smoke` exit 0, no SCRIPT ERROR. Mutation check: a shallow (non-recursive) freeze turns 6 of the 9 freeze tests red.
**Criteria**: 4/4 passing (none deferred)
- AC-1 — `card_database_queries_test.gd`: `test_collectible_pool_war_is_the_six_non_token_war_and_neutral_cards_by_id`, `test_cards_by_{set,type,tag,cost,rarity}_*`, `test_bundle_pool_*`, `test_treasure_pool_*`, `test_bosses_in_band_*`, `test_heroes_include_the_locked_hero_by_id`, `test_collectible_pool_never_includes_boss_cards`, `test_precomputed_pools_are_the_same_frozen_array_on_every_call`
- AC-2 — `test_card_for_an_unknown_id_returns_null_logs_and_asserts_in_debug`, `test_typed_lookup_of_an_id_of_another_type_returns_null`, `test_has_is_true_for_any_record_type_and_false_for_an_unknown_id`, `test_card_for_a_known_id_is_records_at_index_of_and_the_same_instance_each_call`
- AC-3 — `test_config_serves_every_manifest_config_as_a_frozen_dictionary`, `test_config_names_cover_every_manifest_config_row`, `test_config_of_an_unknown_name_returns_null_with_one_logged_error`
- AC-4 — `card_database_freeze_test.gd` (record, nested `effects[0]` / `ops[0]`, pool element, config body and its nested Array; whole-snapshot walk; `duplicate(true)` writable; warnings-only report)
**Engine finding**: `Dictionary.make_read_only()` is **not** recursive on 4.7.2 (probe 2026-11-03: nested Array / Dictionary stay writable) — closes ADR-0002 Verification Required item 3; the loader walks (`DataLoader._freeze_deep`). A refused write is the script error `Invalid assignment on read-only value (on base: '<type>').`
**Deviations**:
- ADVISORY — no `tests/fixtures/data/full_configs/` root: `pools/` carries every manifest config file, so it is the AC-3 root (one fixture, no duplicate).
- ADVISORY — AC-2 "logs one error line": in a debug build gdUnit4 reports the assert's script error, so the push_error cannot be asserted separately there; the assert sits after the push_error in the same function, so its firing proves the push_error ran (release: `is_push_error`).
- ADVISORY — unknown-id assert fires in `Ready` only; during stage 7 an unknown id is data under validation and is logged only (control manifest: never assert on data).
- ADVISORY — snapshot also carries `pools` (precomputed CR-6 pools); staging key `records` renamed `records_by_type` to match the snapshot.
- ADVISORY — `collectible_pool()` previously included `boss` cards for `collectible_pool("boss")`; now never (CR-6), via `DataLoader.in_collectible_pool`, which stage 8 also uses.
- OUT OF SCOPE (directed, [C] story) — contract fixes in `meta_stub.gd`, `boot_meta_stub_test.gd`, `boot_composition_test.gd` and four tests reading `snapshot.configs` / `staging.records`.
**Test Evidence**: `tests/unit/card_database/card_database_queries_test.gd`, `tests/unit/card_database/card_database_freeze_test.gd`
**Run result**: N/A — the database has no screen; nothing it does is drawn until Run UI's `data_error` screen (boot epic)
**Reviewed by**: self, no independent review (QL-TEST-COVERAGE / LP-CODE-REVIEW skipped — Lean mode)
