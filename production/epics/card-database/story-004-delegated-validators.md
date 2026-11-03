# Story 004: Delegated validators and the stage-7 lookup exception (CR-5 stage 7)

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

**ADR Governing Implementation**: ADR-0002: Data format, effect schema/DSL and `config()` loading (Decision 4, stage-7 calling convention); ADR-0007: Effect Resolver / Validator Boundary (the `effects` validator is a `static`, pure function injected here)
**ADR Decision Summary**: Validators arrive as `load(validators: Dictionary)` shaped `{effects, ai_profile, unlock, treasure: Callable, configs: {<name>: Callable}}`. Stage 7a calls each config validator as `call(body, db)`; 7b calls each record validator as `call(host_kind, host_id, value, db, configs)` with the read-only config bodies that passed 7a. Every returned entry is merged with severity `E_DELEGATED` plus the owner's code. A missing validator for any record field or externally owned config file is itself `E_DELEGATED` in **every** build type. During stage 7 the database is `Loading` and answers lookup queries from the staged id-sorted records — the one exception to "queries are illegal before `Ready`" (States table, ADR-0002 2026-11-03); `config()` and `data_version()` stay illegal.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (ADR-0002 / ADR-0007 knowledge risk by version; `Callable.call`, `static func` are pre-4.4, LOW)
**Engine Notes**: Lambdas capture locals by value (4.5+, sourced) — a stub validator that records calls must close over a Dictionary, not a local counter. A five-argument record validator must be called with five arguments (a four-parameter lambda fails at call time — ADR-0007 Context). `OS.is_debug_build()` must **not** relax the missing-validator rule.

**Control Manifest Rules (this layer)**:
- Required: Register a validator for every record field and every externally owned config file via `load(validators: Dictionary)`; stage 7a calls config validators as `call(body, db)`, stage 7b calls record validators as `call(host_kind, host_id, value, db, configs)`; a missing validator is `E_DELEGATED` in every build type; every validator is a `static func`; tests inject `func(...): return []` stubs explicitly. Tests under `tests/unit/**` construct rules objects directly, never through `Boot`.
- Forbidden: Never let a missing validator pass silently in any build; `OS.is_debug_build()` does not relax it. Never a numeric gameplay default in loader code — a missing knob is `E_DELEGATED` from the owner's validator, not a fallback. Never reference `Boot` from `src/core/**`.
- Guardrail: Data load ≤ `data_load_budget_ms` 200 — the delegated validators run inside it (~900 O(1) checks at v1).

---

## Acceptance Criteria

*From GDD `design/gdd/card-database.md` (CR-5 stage 7, States table exception, Edge Cases "Runtime", Acceptance Criteria "Delegation and runtime"), scoped to this story:*

- [ ] **GIVEN** a stub effects validator that rejects any effect with `op: "bogus"`, **WHEN** a card with that effect loads, **THEN** the report contains `E_DELEGATED` with the stub's code and the card id, and the stub was called as `(host_kind, host_id, effects, db, configs)` with `configs["card_effects"]` being the parsed `card_effects.json` body.
- [ ] **GIVEN** a load with no `ai_profile` validator registered (release-configured — the same result in a debug build), **WHEN** loading, **THEN** `E_DELEGATED` names the missing owner (`ai_profile`) and state is `Failed`; **GIVEN** a full stub map, **THEN** no `E_DELEGATED` is raised.
- [ ] **GIVEN** a load where `match_rules.json` is present but `configs` has no `match_rules` validator, **WHEN** loading, **THEN** `E_DELEGATED` names `match_rules.json` and state is `Failed`; **GIVEN** every manifest config file except `card_database.json` has a registered validator and one of them returns `[{code: "E_X", ...}]`, **THEN** that entry appears with severity `E_DELEGATED` and the owner's code, naming the file; `card_database.json` needs no validator (Story 002 self-checks it).
- [ ] **GIVEN** a record validator stub that calls `db.has(id)`, `db.card(id)` and `db.collectible_pool("war")` during stage 7, **WHEN** loading a clean fixture, **THEN** the calls answer from the staged id-sorted records that passed stage 6 and the load reaches `Ready`; **GIVEN** the same stub calls `db.config("match_rules")` or `db.data_version()` during stage 7, **THEN** the call returns `null` / `""` with one logged error (illegal before `Ready`), and in a debug build the `_stage7_lookups_open` guard asserts.

---

## Implementation Notes

*Derived from ADR-0002 Decision 4 and Key Interfaces; ADR-0007 Decision 8:*

- `CardDatabase.load(validators)` passes the map to `DataLoader.run(validators)`. Required keys: `effects`, `ai_profile`, `unlock`, `treasure` (record validators) and `configs: {<name>: Callable}` with one entry per manifest config row whose owner is external (every config file except `card_database`). Check presence **before** calling: each absent key is one `E_DELEGATED` entry naming the owner / file; do not short-circuit — still run the validators that are present.
- 7a: for each config row in manifest order, `configs[name].call(body, db) -> Array`; `body` is the parsed, read-only (not yet frozen) config Dictionary. Collect the passing bodies into a `configs_bodies: Dictionary` (`{match_rules: {...}, card_effects: {...}, …}`).
- 7b: for each staged record, call the record validators that apply to it: `effects` for CardDef `effects[]`, HeroPowerDef `effects[]`, TreasureDef `effects[]` and BossDef `passive` (host kinds `card`, `hero_power`, `treasure`, `boss`); `ai_profile` for BossDef `ai_profile`; `unlock` for HeroDef / TreasureDef / BundleDef `unlock` (incl. `null` — the owner decides); `treasure` for TreasureDef (`rarity`, `tags`, effect count — its `E_TR_*` set). Signature: `call(host_kind: StringName, host_id: String, value: Variant, db: CardDatabase, configs: Dictionary) -> Array`. Order per record: `effects` first, then `treasure` (treasures T7).
- Merge: each returned `{code, host_id|null, field, message}` becomes a report entry with `severity = error`, `code = E_DELEGATED`, and the owner's code preserved in the message (format `E_DELEGATED(<owner_code>)`, or an extra `owner_code` key — pick one and document it in `ValidationReport`).
- Stage-7 lookups: before 7a set `_stage7_lookups_open = true` and point the lookup methods (`has`, `card`, `hero`, `hero_power`, `boss`, `treasure`, `bundle`, `cards_by_*`, `collectible_pool`, `bundle_pool`, `treasure_pool`, `bosses_in_band`, `heroes`) at the staged sorted lists / `index_of` from Story 003; clear the flag after 7b. `config()` and `data_version()` check `state() == READY` only. Story 006 replaces the staged source with the frozen snapshot; keep one private accessor so both paths share code.
- `Boot`'s real adapters (`effects → EffectValidator.validate_effects(kind, id, fx, db, configs["card_effects"])`, `ai_profile → BossAI.validate_profile_key(key, configs["ai_profiles"])`, …) are the boot epic's and the owning epics'; this story ships **accept-all stubs** in `tests/helpers/validator_stubs.gd` (`class_name ValidatorStubs extends RefCounted`): `static func accept_all() -> Dictionary` returning the full map with every `configs` name from `DataLoader.FILE_MANIFEST`, `static func rejecting_effects(op: String, code: String) -> Callable`, and a `recording(calls: Dictionary) -> Callable` that appends `(host_kind, host_id)` to a Dictionary-held list (by-value lambda rule). Until Card Effects / Boss AI / Treasures / Meta land theirs, `Boot` composes these stubs (epic Scope bullet 6).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Card Effects epic: the real `EffectValidator.validate_effects` and `validate_config`; Boss AI, Treasures, Meta Progression, Match Rules and the other owners' validators.
- Boot epic: binding the real validator map in `Boot.boot()`.
- Story 006: the frozen snapshot behind the public queries after `Ready`.
- Story 008: `E_NOT_LOADED` for queries outside stage 7 before `Ready`.

---

## Files

- `src/core/data/data_loader.gd` (stage 7a/7b)
- `src/core/data/card_database.gd` (`_stage7_lookups_open`, staged lookup source)
- `tests/helpers/validator_stubs.gd`
- `tests/fixtures/data/delegated_*/`
- `tests/unit/card_database/card_database_validators_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: `standard` — Logic tests are BLOCKING.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/card_database/card_database_validators_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/card-database/story-003-uniqueness-and-cross-references.md`
- Unlocks: `production/epics/card-database/story-006-freeze-and-queries.md`; the boot epic's `Boot.boot()` composition (consumes `ValidatorStubs.accept_all()`)
