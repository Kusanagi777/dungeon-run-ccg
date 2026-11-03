# Story 005: MVP-1 — the 10 MVP bundles (8 War + 2 neutral)

> **Epic**: Content (MVP batch)
> **Status**: Ready
> **Layer**: Feature (data)
> **Type**: Config/Data
> **Estimate**: S
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/content.md` (CN-4 bundle table, AC-14, AC-15) · `design/gdd/card-database.md` (CR-3 BundleDef, Formulas "Bundle pool size") · `design/gdd/reward-draft.md` (`bundle_pool_min`)
**Requirement**: `TR-content-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Data format, effect schema/DSL and `config()` loading
**ADR Decision Summary**: `BundleDef` rows (`id`, `name`, `set`, `theme`, `cards` = 3 ids, `unlock`, `text`) in `bundles.json` are cross-checked at CR-5 step 6 (`E_COUNT`, `E_TOKEN_IN_LIST`, `E_TAG_MISMATCH`). Loader thresholds come from `card_database.json`, never from literals.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (ADR-0002 general) / LOW (APIs)
**Engine Notes**: none (data only).

**Control Manifest Rules (Foundation, data)**:
- Required: every loader threshold is read from `card_database.json`.
- Forbidden: never a numeric gameplay default in loader code; never GDScript constants as data.
- Guardrail: data load ≤ `data_load_budget_ms` 200.

Batch 0 shipped `bundle_neutral_wall`, `bundle_neutral_tempo` and `bundle_war_armour_1`. This story adds the other seven War bundles in CN-4, so Reward Draft has the full MVP pool of 10, and raises `min_bundle_pool` so the loader warns below the pool the MVP draft actually needs.

---

## Acceptance Criteria

*From GDD `design/gdd/content.md` (CN-4, AC-14, AC-15 MVP subset), card-database Formulas, scoped to this story:*

- [ ] **AC-1 (Records — AC-14)** GIVEN `bundles.json`, WHEN loaded, THEN it holds the 10 CN-4 MVP bundles (8 `war`, 2 `neutral`), each with the CN-4 name, theme and three cards, `unlock` null and a one-line `text` pitch. Each bundle's cards share its set and carry its theme tag, and no `E_COUNT`, `E_TOKEN_IN_LIST` or `E_TAG_MISMATCH` is raised.
- [ ] **AC-2 (Coverage and bands — AC-14, AC-15)** GIVEN the MVP pool, THEN every War signature card (`war_duelists_edge`, `war_pit_champion`, `war_cleave_through`) is in ≥ 1 bundle, every War plan tag (`weapons`, `aggro`, `armour`) has ≥ 2 bundles, and the F2 band split of War's bundles is 3 early / 3 mid / 2 late, as the CN-4 table lists.
- [ ] **AC-3 (Pool threshold)** GIVEN `card_database.json`, THEN `min_bundle_pool` is ≥ Reward Draft's registered `bundle_pool_min` for MVP (9). The War bundle pool (8 + 2 = 10) raises no `W_POOL_SIZE`, and the smoke check records the load report.

---

## Implementation Notes

*Derived from ADR-0002 Implementation Guidelines and CN-4:*

- New rows: `bundle_war_weapons_1` (Whetted Steel), `bundle_war_weapons_2` (Armoury), `bundle_war_weapons_3` (Kingsguard), `bundle_war_aggro_1` (First Blood), `bundle_war_aggro_2` (The Pit), `bundle_war_aggro_3` (Warband), `bundle_war_armour_2` (Bulwark). Take the card lists verbatim from CN-4.
- Story 001 seeded `card_database.json` with its Formulas defaults. This story checks `min_bundle_pool` against `reward-draft.md`'s `bundle_pool_min` and edits only that key, if it needs changing.
- `bundle.<id>.name` / `bundle.<id>.text` keys are derived (CN-6 step 6). Store `text` as `{key, en}`.

---

## Out of Scope

- VS / Alpha bundles 11–36 (deferred list). Reward Draft epic: weighting and pity rules.

---

## Files

- `assets/data/bundles.json`, `assets/data/card_database.json`
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

- Depends on: `production/epics/content/story-002-mvp-1-war-set.md`; `production/epics/content/story-001-batch-0-first-playable-data-set.md`
- Unlocks: `production/epics/content/story-009-mvp-1-batch-close-audit-and-balance.md`
