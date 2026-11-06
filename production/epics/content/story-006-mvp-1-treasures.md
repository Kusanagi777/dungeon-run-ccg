# Story 006: MVP-1 — the 10 MVP treasures

> **Epic**: Content (MVP batch)
> **Status**: In Review
> **Layer**: Feature (data)
> **Type**: Config/Data
> **Estimate**: S
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/content.md` (CN-5 MVP-1 row) · `design/gdd/treasures.md` (T8 table — the authority for every treasure field) · `design/gdd/card-database.md` (CR-3 TreasureDef, Formulas "Minimum treasure pool")
**Requirement**: `TR-content-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Data format, effect schema/DSL and `config()` loading; ADR-0007: Effect Resolver / Validator Boundary (treasure hook `effects[]`)
**ADR Decision Summary**: `TreasureDef` rows (`id`, `name`, `rarity`, `tags`, `effects`, `unlock`, `text`) in `treasures.json` are validated by the injected Treasures validator (`E_TR_*`), the Effect validator (`E_FX_*`) and the Meta Progression `unlock` validator at stage 7b.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (ADR-0002 general) / LOW (APIs)
**Engine Notes**: none (data only).

**Control Manifest Rules (Foundation, data)**:
- Required: `effects[]` plain JSON; `Treasures.pool(unlocked_keys, exclude_ids)` is the one membership predicate (Feature layer, ADR-0005), never a list in data.
- Forbidden: never GDScript constants as data.
- Guardrail: data load ≤ `data_load_budget_ms` 200.

Batch 0 shipped an empty `treasures.json`, which the first playable's single match never reads. This story authors the 10 MVP treasures CN-5 names, transcribed from Treasures T8, and with them the treasure-pool `W_POOL_SIZE` that batch 0 accepted goes away.

---

## Acceptance Criteria

*From GDD `design/gdd/content.md` CN-5 and `treasures.md` T8, card-database Formulas, scoped to this story:*

- [ ] **AC-1 (Records)** GIVEN `treasures.json`, WHEN loaded, THEN it holds exactly the 10 CN-5 MVP-1 ids: `treasure_hollow_crown`, `treasure_worn_signet`, `treasure_vanguards_banner`, `treasure_bottomless_satchel`, `treasure_iron_constitution`, `treasure_thornhide_cloak`, `treasure_stampede_horn`, `treasure_whetstone_wheel`, `treasure_twin_grip`, `treasure_scholars_candle`. Every field matches its T8 row (name, rarity, affinity and plan tags, hook `effects`, text). The validators report zero `E_TR_*` and zero `E_FX_*`.
- [ ] **AC-2 (Pool)** GIVEN the loaded pool, THEN all 10 have `unlock` null, `treasure_pool()` has 10 ≥ `min_treasure_pool` 9 (DD-R05 / DD-H06), so treasures raise no `W_POOL_SIZE`, and 7 carry the `universal` affinity (Reward Draft F6 recommended 7).
- [ ] **AC-3 (Deferred unlock — DD-X12)** GIVEN the MVP data, THEN `treasure_living_armory`, the one v1 treasure that unlocks on `first_victory` (`runs_won ≥ 1`), is absent, because it is Alpha-B (CN-5). No MVP record carries an `unlock` key, so the Meta Progression unlock validator reports zero errors. The smoke check records the load report.

---

## Implementation Notes

*Derived from ADR-0002 / ADR-0007 Implementation Guidelines and Treasures T8:*

- Copy each record from the T8 row and its JSON sketch (`treasures.md` T8 table and the effect examples under it). Content does not redesign treasures: a field that does not validate is a Treasures GDD change.
- `treasure_scholars_candle` has Knowledge affinity but is a draw hook any hero can hold (CN-5 note), so it is not filtered out of War runs.
- DD-X12's `first_victory` key arrives with `treasure_living_armory` in the Alpha-B treasure story. Do not add it here: a record outside its batch breaks the CN-1 counts that `/content-audit` checks.

---

## Out of Scope

- Treasures epic: `Treasures.validate_treasure_defs`, the hook runtime, `treasures_balance.json` ownership.
- VS / Alpha treasures 11–20 (deferred list).

---

## Files

- `assets/data/treasures.json`
- `production/qa/smoke-[date].md`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: `standard` — Config/Data evidence is ADVISORY.*

**Story Type**: Config/Data
**Required evidence**:
- Config/Data: smoke check pass (`production/qa/smoke-[date].md`).

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content/story-001-batch-0-first-playable-data-set.md`; the Treasures epic's validator story (path not yet assigned — `/create-stories treasures`); `production/epics/card-effects/story-015-hook-trigger-steps-hero-slot-observers.md` (hook-trigger validation)
- Unlocks: `production/epics/content/story-009-mvp-1-batch-close-audit-and-balance.md`
