# Story 005: MVP-1 — the 10 MVP bundles (8 War + 2 neutral)

> **Epic**: Content (MVP batch)
> **Status**: Complete
> **Layer**: Feature (data)
> **Type**: Config/Data
> **Estimate**: S
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-04

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

- [x] **AC-1 (Records — AC-14)** GIVEN `bundles.json`, WHEN loaded, THEN it holds the 10 CN-4 MVP bundles (8 `war`, 2 `neutral`), each with the CN-4 name, theme and three cards, `unlock` null and a one-line `text` pitch. Each bundle's cards share its set and carry its theme tag, and no `E_COUNT`, `E_TOKEN_IN_LIST` or `E_TAG_MISMATCH` is raised.
- [x] **AC-2 (Coverage and bands — AC-14, AC-15)** GIVEN the MVP pool, THEN every War signature card (`war_duelists_edge`, `war_pit_champion`, `war_cleave_through`) is in ≥ 1 bundle, every War plan tag (`weapons`, `aggro`, `armour`) has ≥ 2 bundles, and the F2 band split of War's bundles is 3 early / 3 mid / 2 late, as the CN-4 table lists.
- [x] **AC-3 (Pool threshold)** GIVEN `card_database.json`, THEN `min_bundle_pool` is ≥ Reward Draft's registered `bundle_pool_min` for MVP (9). The War bundle pool (8 + 2 = 10) raises no `W_POOL_SIZE`, and the smoke check records the load report.

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

- `assets/data/bundles.json`: +7 CN-4 War bundles
- `assets/data/card_database.json`: unchanged (`min_bundle_pool` 10 already ≥ 9)
- `production/qa/smoke-2026-11-04-content-mvp1-bundles.md`: Config/Data smoke record
- `tests/integration/content/content_mvp1_data_test.gd`: 4 tests added (AC-1…AC-3)
- `tests/integration/content/content_batch0_data_test.gd`: two batch-0 pins relaxed (bundle ids; `W_POOL_SIZE` files)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: `standard` — Config/Data evidence is ADVISORY.*

**Story Type**: Config/Data
**Required evidence**:
- Config/Data: smoke check pass (`production/qa/smoke-[date].md`).

**Status**: [x] `production/qa/smoke-2026-11-04-content-mvp1-bundles.md` (PASS) + `tests/integration/content/content_mvp1_data_test.gd` (4 story-005 tests, passing)

---

## Dependencies

- Depends on: `production/epics/content/story-002-mvp-1-war-set.md`; `production/epics/content/story-001-batch-0-first-playable-data-set.md`
- Unlocks: `production/epics/content/story-009-mvp-1-batch-close-audit-and-balance.md`

---

## Readiness

**`/story-readiness` (by hand, 2026-11-04): NEEDS WORK → resolved from the docs → READY.** Tier: workflow standard (content).
- *Passing*: CN-4 rows and AC-14/15 quoted; ADR-0002 Accepted; TR-content-001 active; Manifest Version 2026-11-03 is current; estimate S; Out of Scope stated; dependencies (content 001, 002) Complete; no open markers; no asset references; 3 criteria; Config/Data with Test Evidence naming the smoke record.
- *Gap found (testable as written)*: AC-3 compares against Reward Draft's **registered** `bundle_pool_min`, which does not exist. `reward_draft` is still a pending config owner, and its epic has no stories.
- *How it was cleared*: sprint-004 Goal Prerequisites option (a), named by the orchestrator. AC-3 is checked in a test against the GDD value 9 (reward-draft F5 at `F = 4`, `W = 2`), and the smoke record says so. This is recorded as a deviation.

QL-STORY-READY skipped — Lean mode.

## Completion Notes
**Completed**: 2026-11-04
**Started / ended (UTC)**: 2026-11-04T03:45:46Z – 2026-11-04T03:51:18Z
**Criteria**: 3/3 passing. AC-3 was checked against the GDD value (deviation below).
**Deviations**:
- **AC-3 "registered `bundle_pool_min`"**: Reward Draft has not registered the key. `reward_draft.json` is still `W_VALIDATOR_PENDING`. The test checks the GDD value 9 instead, in two ways: the constant `REWARD_DRAFT_MVP_BUNDLE_POOL_MIN`, and Reward Draft F5 evaluated over the shipped `floors_per_run` / `reoffer_after_floors`. When Reward Draft registers the key, swap the constant for the registered value.
- `min_bundle_pool` is unchanged at 10, not raised. It already sits at or above 9, and the story allows the edit only "if it needs changing". A value of 10 = the MVP pool, so the loader warns as soon as one bundle goes missing.
- The bundle `text.en` pitches are the lane's own one-liners. CN-4 gives the name as the "`text.en` pitch" column header but no pitch sentence.
- `tests/integration/content/content_batch0_data_test.gd` was edited outside the Files list. Its exact bundle-id pin and its `W_POOL_SIZE` file list were relaxed to the batch-0 subset.
**Validate command**: `Ready — 0 errors, 51 warnings (content checks 0 errors, 43 warnings), 62 records`. Before: 53 / 44, 55 records.
- `W_POOL_SIZE` fell 2 → 1. Only the treasure row is left, for story 006.
- Content story 008 (F1–F5): F5 War bundle coverage 0.06 → 0.94 clears its `W_COVERAGE` row. There is no new `W_BUDGET` or `W_CURVE` row, because F1–F3 do not read bundles.
**Test Evidence**: `production/qa/smoke-2026-11-04-content-mvp1-bundles.md` (PASS). `content_mvp1_data_test.gd` gained 4 tests, all seen failing on the batch-0 bundles. Full suite: 1229 test cases, 0 failures, exit 0. Smoke exit 0.
**Run result**: N/A, data only. No scene drafts bundles until the reward-draft and run-ui stories.
**Reviewed by**: self, no independent review (lean: QL-TEST-COVERAGE and LP-CODE-REVIEW skipped). Game-designer sign-off NOT ASSESSED (no agent).
**Owner sign-off (2026-11-04, DD-X24)**: Jacob accepts the 10 MVP bundles as shipped. This includes the lane-written `text.en` pitches and `min_bundle_pool` unchanged at 10. This replaces the NOT ASSESSED game-designer sign-off above.
