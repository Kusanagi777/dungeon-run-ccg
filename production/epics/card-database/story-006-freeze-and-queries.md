# Story 006: Freeze and CR-6 queries (CR-5 stage 9, CR-6, CR-7)

> **Epic**: Card Database
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: — (set by /dev-story when implementation begins)

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

- [ ] **GIVEN** a fixture with 4 War cards (one token), 3 neutral cards and 2 boss-set cards, **WHEN** `collectible_pool("war")` is called on a `Ready` database, **THEN** it returns exactly the 6 non-token War+neutral cards sorted by id ascending; `cards_by_set` / `cards_by_type` / `cards_by_tag` / `cards_by_cost` / `cards_by_rarity` include tokens and are id-ascending; `bundle_pool("war")` is `set ∈ {war, neutral}`; `treasure_pool()`, `bosses_in_band(band)` and `heroes()` (locked included) are id-ascending regardless of file order.
- [ ] **GIVEN** a `Ready` database, **WHEN** `card("no_such_id")` is called, **THEN** it returns `null` and logs one error line, and in a debug build an assert fires; `has("no_such_id")` is `false`; `card(id)` for a known id is `records[index_of[id]]` — O(1), no allocation — and the same Dictionary instance on every call.
- [ ] **GIVEN** a loaded fixture root containing every manifest config file, **WHEN** loaded, **THEN** `config("match_rules")`, `config("card_effects")`, `config("ai_profiles")`, `config("run_structure")`, `config("reward_draft")`, `config("treasures_balance")`, `config("heroes_balance")`, `config("match_ui")`, `config("run_ui")`, `config("profile_defaults")`, `config("card_database")`, `config("content_budgets")` and `config("rng_event_log")` each return a non-null frozen Dictionary, and `config("no_such")` returns `null` with one logged error.
- [ ] **GIVEN** a `Ready` database, **WHEN** a test writes to a returned record, to a nested `effects[0]` inside it, to an element of a returned pool Array and to a returned config body, **THEN** every write is refused (read-only) and `duplicate(true)` of the record yields a writable copy; `report()` holds warnings only after a clean load.

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

- `src/core/data/data_loader.gd` (stage 9 freeze)
- `src/core/data/card_database.gd` (CR-6 queries, `config`, snapshot swap)
- `tests/fixtures/data/pools/`, `tests/fixtures/data/full_configs/`
- `tests/unit/card_database/card_database_queries_test.gd`
- `tests/unit/card_database/card_database_freeze_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: `standard` — Logic tests are BLOCKING.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/card_database/card_database_queries_test.gd`, `tests/unit/card_database/card_database_freeze_test.gd` — must exist and pass (`/story-done` checks that they EXIST; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/card-database/story-004-delegated-validators.md`, `production/epics/card-database/story-005-budget-warnings-and-pool-thresholds.md`
- Unlocks: `production/epics/card-database/story-007-data-version-fingerprint.md`, `production/epics/card-database/story-008-state-machine-and-debug-reload.md`, `production/epics/card-database/story-009-load-and-memory-budget.md`; every consumer epic's first story that reads `card()` / `config()`
