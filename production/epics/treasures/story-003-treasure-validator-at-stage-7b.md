# Story 003: `TreasureValidator` — T7 codes at Card Database stage 7b, registered at Boot

> **Epic**: Treasures
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-04
> **Last Updated**: [set by /dev-story when implementation begins]
> **First Playable path**: no — the First Playable ships an empty `treasures.json`. It unblocks content story 006 (the 10 MVP treasures)

## Context

**GDD**: `design/gdd/treasures.md` (T1, T7, Edge Cases "Data and validation", AC-5) · `design/gdd/card-database.md` CR-3 (`TreasureDef`, `text` shape), CR-5 stage 7
**Requirement**: `TR-card-database-002` (carried: delegated validators incl. "treasure tags")
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Owner-scoped hook registry (`Treasures.validate_treasure_defs`, its closed code set); ADR-0002: Data format, effect schema/DSL and `config()` loading (the stage-7b calling convention)
**ADR Decision Summary**: `static func validate_treasure_defs(defs, db) -> Array` raises the closed set `E_TR_RARITY`, `E_TR_TAGS`, `E_TR_EFFECT_COUNT`, `E_TR_TOKEN_REF`, `W_TR_POWER`, `W_TR_TEXT` (ADR-0005). Stage 7b calls every record validator as `(host_kind, host_id, value, db, configs) -> Array` with `db` answering lookups. `Boot` registers a one-line adapter per owner, as it does for `effects` and `ai_profile` (ADR-0002 Decision 4).
**ADR Version**: 2026-11-03 (ADR-0005); 2026-11-03 (ADR-0002)

**Engine**: Godot 4.7.2 | **Risk**: HIGH (by version); LOW for the APIs
**Engine Notes**: ADR-0002 Engine Compatibility — lambdas capture by value (the adapter takes everything as arguments); typed-method overrides return explicitly (4.7).

**Control Manifest Rules (this layer)**:
- Required: each owner exposes a `static` validator registered at `Boot`; validators are pure and allocate their own report; stage-7 lookups only (`has`, `card`, …), never `config()` before `Ready`
- Forbidden: never make a missing validator pass silently in any build type; never add an `E_FX_*` code here (effect errors are `EffectValidator`'s); never mutate `RunState` from `src/gameplay/treasures/`
- Guardrail: data load ≤ `data_load_budget_ms` 200

`Boot.PENDING_RECORD_OWNERS = ["treasure"]` today: a pending validator that reports `W_VALIDATOR_PENDING` (an error in an exported build). Content story 006 depends on "the Treasures epic's validator story", and this is that story.

---

## Acceptance Criteria

*From GDD `design/gdd/treasures.md` (T7, AC-5) and `card-database.md` CR-3, scoped to this story:*

- [ ] **AC-5** GIVEN fixture records with (a) trigger `battlecry`, (b) a `summon` of a `set: boss` card, (c) tags `[war, decay]`, (d) `rarity: legendary`, WHEN loaded, THEN the report contains `E_FX_TRIGGER`, `E_TR_TOKEN_REF`, `E_TR_TAGS`, `E_TR_RARITY` respectively and the load is `Failed`.
- [ ] **AC-T7a (count and tags)** GIVEN a record with `effects: []`, and another with 4 effects (more than `max_effects_per_treasure` = 3 in `treasures_balance.json`), THEN each raises `E_TR_EFFECT_COUNT`; GIVEN a record with tags `[universal, frobnicate]` (an unknown tag) or with plan tags but no affinity tag, THEN `E_TR_TAGS`; GIVEN the 20-record fixture `tests/fixtures/data/treasures_v1.json`, THEN zero `E_TR_*` entries.
- [ ] **AC-T7b (text)** GIVEN a record whose `text` has no `en` (the one locale CR-3 ships), THEN `W_TR_TEXT` is reported and the load is `OK`.
- [ ] **AC-REG (registration)** GIVEN `Boot._collect_validators`, THEN `treasure` is the adapter over `Treasures.validate_treasure_defs` and `Boot.PENDING_RECORD_OWNERS` is empty (the pinned lists in `tests/integration/boot/boot_validator_map_test.gd` are updated); a load of a root with one valid treasure reports no `W_VALIDATOR_PENDING` for the `treasure` key.

---

## Implementation Notes

*Derived from ADR-0005 Key Interfaces, ADR-0002 Decision 4 (stage-7 calling convention), treasures T1 / T7:*

- `DataLoader` stage 7b calls the `treasure` key with the **whole record**: `[&"treasure", id, rec, db, configs]` (`data_loader.gd`, the per-record call list). `effects` and `unlock` on the same record go to their own validators. So Boot's adapter is `func(kind, id, rec, db, configs): return Treasures.validate_treasure_defs([rec], db, configs.get("treasures_balance", {}))`, or an equivalent per-record core. Keep ADR-0005's `validate_treasure_defs(defs, db)` name, and pass the `treasures_balance` body explicitly for `E_TR_EFFECT_COUNT`. Never call `config()` during stage 7. When that body failed 7a and is absent, follow the `_effects_adapter` precedent: one explicit `E_DELEGATED` entry per host, never a check against empty caps.
- Tags (T1): exactly one affinity from `war | decay | knowledge | universal`, plus 0–3 more from the plan set (`weapons, aggro, armour, deathrattle, sacrifice, husk, spells, spell_damage, draw`) and the archetype set (`economy, tempo, value, defensive, wild`). These vocabularies are format knowledge, like the loader's manifest. The 3-cap on non-affinity tags is T1's rule. Raise `E_TR_TAGS` for zero or two affinities and for any unknown tag.
- `E_TR_RARITY`: `rarity ∉ {common, rare}`. Legendary is a card rarity only.
- `E_TR_TOKEN_REF`: for each op `summon` / `add_to_hand` / `equip` with a `card_id` whose `db.card(card_id).set == "boss"`. Walk nested `conditional` branches. Living Armory's `from: {pool…}` has no `card_id` and is not checked here (its filter never yields tokens).
- `W_TR_TEXT`: `text.en` absent. CR-3's text shape is `{key, en}`, and `en` is the only locale it ships. When localization adds locales, the list becomes data and this check reads it; that is not in scope.
- Result entries use the 7b shape `{code, host_id, field, message}`, with severity from the prefix (`E_` error, `W_` warning), as the loader merges them.
- `W_TR_POWER` is in ADR-0005's closed set but is **not checked** by this story (story 013 is Blocked on a GDD gap). Say so in `validate_treasure_defs`'s doc comment and in Completion Notes, so that "not checked" cannot be read as "checked, in band".

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 013: `W_TR_POWER` (Blocked — the GDD gives no load-time way to compute F1)
- Story 010: `Treasures.validate_config` for `treasures_balance.json` (stage 7a)
- `EffectValidator` (`E_FX_*`, card-effects 003/004, Complete) and Meta's `unlock` validator: separate keys, already registered
- Content story 006: authoring the 10 MVP records

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/gameplay/treasures/treasures.gd` — `validate_treasure_defs` (and its per-record core)
- `src/core/boot.gd` — the `treasure` adapter; `PENDING_RECORD_OWNERS` emptied (Boot epic's one-line-per-owner pattern)
- `tests/unit/treasures/treasures_validator_test.gd`
- `tests/fixtures/data/treasures_invalid/` — AC-5 / AC-T7 fixture records
- `tests/integration/boot/boot_validator_map_test.gd` — pinned pending list updated

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/treasures/treasures_validator_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/treasures/story-001-installers-passive-and-collect-state.md` (the `Treasures` class and the 20-record fixture). Cross-epic (Complete): `production/epics/card-database/story-004-delegated-validators.md`, `production/epics/boot-composition-root/story-004-boot-composition-root.md`
- Unlocks: `production/epics/content/story-006-mvp-1-treasures.md` (its "Treasures epic's validator story"); the release guardrail (empty `PENDING_RECORD_OWNERS`)
