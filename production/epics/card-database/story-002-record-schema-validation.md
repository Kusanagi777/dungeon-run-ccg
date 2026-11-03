# Story 002: Record schema validation (CR-3, CR-5 stage 4)

> **Epic**: Card Database
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: — (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/card-database.md`
**Requirement**: `TR-card-database-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Data format, effect schema/DSL and `config()` loading
**ADR Decision Summary**: Stage 4 runs in `DataLoader` over plain Dictionaries with the closed code set from card-database CR-5 and Edge Cases; the loader never inspects `effects[]`, `passive` or any config body beyond "is an array / is an object" (those are stage-7 owners), except `card_database.json`, whose five integer knobs it schema-checks itself.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (ADR-0002 knowledge risk generally; APIs used — `Dictionary`, `Array`, `RegEx`, `typeof` — are pre-4.4, LOW)
**Engine Notes**: `JSON` parses every number as `float` — compare integer fields with `is_equal_approx(floor(x), x)`-style checks or `int()` after a type check, never `typeof(x) == TYPE_INT`. No post-cutoff API is needed.

**Control Manifest Rules (this layer)**:
- Required: Validate in the nine CR-5 stages with the closed code set. `effects[]`, `passive` and config bodies are plain JSON with no code references (opaque here). Every class under `src/core/**` `extends RefCounted`.
- Forbidden: Never a numeric gameplay default in loader code (the knob **ranges** in Formulas are format knowledge; the knob **values** come from `card_database.json`). Never `assert()` on data in release paths — data faults are `ValidationReport` entries.
- Guardrail: Data load ≤ `data_load_budget_ms` 200 — stage 4 is O(n_records); keep it allocation-light.

---

## Acceptance Criteria

*From GDD `design/gdd/card-database.md` (CR-2, CR-3, CR-5 stage 4, Edge Cases "Enums and shapes", Acceptance Criteria), scoped to this story:*

- [ ] **GIVEN** a record with field `durabilty`, **WHEN** loading, **THEN** `E_UNKNOWN_FIELD` names the file, record id and field; **GIVEN** a spell with `attack`, a minion lacking `health`, a weapon lacking `durability`, a minion `health: 0`, a `cost` of 11, a `keywords` entry outside the DD-M09 list, a repeated keyword, `spell_damage: 2` without the `spell_damage` keyword, an id violating `^[a-z][a-z0-9_]{2,47}$`, a card whose id prefix disagrees with `set` or its file, and a `text.key` that is not `card.<id>.text`, **THEN** each raises its CR-3 / Edge Cases code (`E_UNKNOWN_FIELD`, `E_MISSING_FIELD`, `E_SCHEMA`, `E_BAD_ENUM`, `E_SET_MISMATCH`, `E_TEXT_KEY`) naming file, record id and field, all in one report.
- [ ] **GIVEN** `card_database.json` with `min_bundle_pool: 2` (below its 3–30 range), **WHEN** loading, **THEN** `E_SCHEMA` names the file and the key and state is `Failed`; **GIVEN** its five knobs (`min_collectible_pool` 10–100, `min_bundle_pool` 3–30, `max_records`, `data_load_budget_ms` 50–1000, `data_memory_budget_mb` 1–32) in range, **THEN** no entry is raised for it, and no other config body is schema-checked at this stage.
- [ ] **GIVEN** a hero record with `unlock: "unlock.hero_fortune"` (a bare string) and a bundle record with `unlock: {key: "bundle_x", condition: {type: "always"}}`, **WHEN** loading, **THEN** the hero raises a schema error naming `unlock` (expected object or `null` — DD-X01) and the bundle passes the schema stage (its `unlock` is handed to stage 7, Story 004); **GIVEN** every bundle with `unlock: null`, **THEN** no error or warning is raised; **GIVEN** a hero with `hero_power: null`, **THEN** `E_MISSING_FIELD`.
- [ ] **GIVEN** a treasure with `tags: ["war", "weapons"]` and a boss with `passive` set and `passive_text` present, **WHEN** loading, **THEN** no schema error is raised; **GIVEN** the same boss with `passive_text` removed, **THEN** `E_MISSING_FIELD` names the boss and `passive_text`; **GIVEN** a boss with `passive: null` and a `passive_text`, **THEN** `E_UNKNOWN_FIELD`; **GIVEN** a boss with `passive: null` **and** `hero_power: null`, **THEN** `E_SCHEMA`.

---

## Implementation Notes

*Derived from ADR-0002 Decision 3 and card-database CR-3:*

- Implement stage 4 as per-record-type schema tables inside `src/core/data/data_loader.gd` (or a sibling `src/core/data/record_schemas.gd`, `RefCounted`, `static func`s): one table per `record_type` (`CardDef`, `HeroDef`, `HeroPowerDef`, `BossDef`, `TreasureDef`, `BundleDef`) listing field → `{type, required | by-type rule, range | enum | pattern}` exactly as CR-3 states them. The enum lists (sets, types, rarities, keywords) are the CR-4 lists; `CardFactory.SETS / TYPES / RARITIES / KEYWORDS` mirror them for tests.
- Fields not in the type's table are `E_UNKNOWN_FIELD` (typos must not be ignored). CardDef by-type rules: `attack` minion+weapon, `health` minion only (1–99), `durability` weapon only (1–9); `spell_damage` 0–5 default 0 and must agree with the keyword; `token` default `false`; `art` default `cards/<id>` (defaults are **format** defaults for optional presentation fields, not gameplay numbers).
- `set` must equal the file's set (`cards_<set>.json`) and the id prefix (`<set>_`) — both are `E_SET_MISMATCH`. Other id prefixes per CR-2 (`hero_`, `power_`, `boss_`, `treasure_`, `bundle_<set>_`).
- `unlock` on HeroDef / TreasureDef / BundleDef: `null` or a Dictionary with `key: String` and `condition: Dictionary`; the body of `condition` is opaque (Meta Progression's validator, stage 7). BossDef: `passive` null-or-object, `passive_text` required iff `passive` is non-null; `hero_power` may be `null` only when `passive` is non-null; `band` 1–3; `deck` ≥ 1 string; `tags` `^[a-z_]+$`. BundleDef `set` is a hero set or `neutral`, never `boss`; `cards` is an Array of String (count is Story 003's `E_COUNT`). TreasureDef `rarity` is `common | rare` in v1.
- `card_database.json` is the one config body checked here: exactly the five integer knobs, each inside its Formulas range; a missing knob or extra key is `E_SCHEMA` naming file and key. Every other config body passes through untouched to stage 7a.
- A record that fails stage 4 is excluded from stages 5–9 but the rest continue (one report lists everything).
- Fixtures: build each bad record with `CardFactory.make_card_def({...})` overrides on top of the Story 001 minimal root; `CardFactory.validate_card_def` is an observation helper for tests, not the production check.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: `E_DUP_ID`, `E_UNKNOWN_REF`, `E_COUNT`, `E_TOKEN_IN_LIST`, `E_TAG_MISMATCH` (stages 5–6).
- Story 004: `effects[]`, `passive`, `ai_profile`, `unlock` bodies and every other config body (stage 7 owners).
- Story 005: `W_BAND_HEALTH`, `W_DUP_NAME`, `W_POOL_SIZE` (stage 8).
- Content epic: authoring the real records; `tools/content/schemas/*.schema.json` land with its MVP-1 validator story and must agree with this stage, not replace it.

---

## Files

- `src/core/data/data_loader.gd` (stage 4)
- `src/core/data/record_schemas.gd` (optional split; `static func`s only)
- `tests/fixtures/data/schema_*/` (one small root per AC case, derived from `minimal/`)
- `tests/unit/card_database/card_database_schema_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: `standard` — Logic tests are BLOCKING.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/card_database/card_database_schema_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/card-database/story-001-manifest-parse-envelope.md`
- Unlocks: `production/epics/card-database/story-003-uniqueness-and-cross-references.md`, `production/epics/card-database/story-005-budget-warnings-and-pool-thresholds.md`
