# Story 010: Gravekeeper returns to the boss decks

> **Epic**: Content (MVP batch)
> **Status**: Ready
> **Layer**: Feature (data)
> **Type**: Config/Data
> **Estimate**: S
> **Manifest Version**: 2026-11-04
> **Last Updated**: 2026-11-04 (created, DD-X20)

## Context

**GDD**: `design/gdd/content.md` (CN-2 row `neutral_gravekeeper`; CN-3 B2 recipes for `boss_gatekeeper`, `boss_hollow_king`, `boss_rot_warden`, `boss_torchbearer`; Edge Cases "If a boss deck recipe cannot reach 30 ids", superseded for Gravekeeper 2026-11-04, DD-X20; AC-10, AC-11) · `design/gdd/boss-ai.md` (C6 `add_counter` row, F9 note) · `design/gdd/card-effects.md` (C11 row 45)
**Requirement**: `TR-content-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Data format, effect schema/DSL and `config()` loading; ADR-0006: Boss AI Planner Threading (`ai_profiles.json`); ADR-0007: Effect Resolver / Validator Boundary
**ADR Decision Summary**: Cards and `ai_profiles.json` are CR-1 envelopes under `assets/data/`. Every `effects[]` passes `validate_effects` with the closed `E_FX_*` set. Boss AI values each op from the `op_values` table; an op with no row reports `E_AI_OP_UNVALUED`, which fails the load today.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (by version) / LOW (no API used by data)
**Engine Notes**: none for data.

**Control Manifest Rules (Foundation, data)**:
- Required: Boss AI numbers only in `ai_profiles.json`; card effects copied from card-effects C11 row 45.
- Forbidden: never a literal op value in code.
- Guardrail: data load ≤ `data_load_budget_ms` 200.

**Why (owner decision DD-X20, 2026-11-04).** `neutral_gravekeeper` was deferred in sprint 4 because `ai_profiles.json` had no `op_values` row for `add_counter` (content story 001). Four boss decks used the content Edge Cases same-batch fallback in its place. The owner decided Boss AI values `add_counter`. Boss-ai C6 now gives the row as `add_counter 0.5`. This story ships the row, the card and the four swaps back.

---

## Acceptance Criteria

*From DD-X20 and GDD `design/gdd/content.md` (CN-2, CN-3 B2, AC-10, AC-11), `design/gdd/boss-ai.md` C6 / F9:*

- [ ] **AC-1 (`op_values` row)** GIVEN `assets/data/ai_profiles.json`, THEN `op_values` has `"add_counter": 0.5` and its other 19 rows are unchanged. GIVEN `design/gdd/boss-ai.md` F9, THEN `add_counter 0.5` sits in the `op_values:` list, and the note under the block saying the list "does not yet carry" it is removed. `BossAI.validate_profiles_config` returns zero rows.
- [ ] **AC-2 (Card)** GIVEN `assets/data/cards_neutral.json`, THEN `neutral_gravekeeper` is present per CN-2: minion, cost 3, 2/3, rarity R, keyword `deathrattle`, `text.en` = the CN-2 text, `effects[]` = card-effects C11 row 45 verbatim (`on_minion_died {who: any_minion}` → `add_counter seen 1`; `deathrattle` → `enemy_hero` → `damage {ref: counter.seen}`). It validates with zero `E_FX_*` and zero `E_AI_OP_UNVALUED`. The collectible neutral set is 15 (CN-1 MVP column).
- [ ] **AC-3 (Decks back on their B2 recipes)** GIVEN `bosses.json`, THEN each deck has 30 non-token ids and undoes its recorded fallback:
  - Gatekeeper (story 003): `boss_iron_gate` ×3 → ×2, `boss_gate_warden` ×3 → ×2, `neutral_gravekeeper` ×2.
  - Hollow King (story 004): `boss_hollow_knight` ×3 → ×2, `boss_crown_of_thorns` ×3 → ×2, `neutral_gravekeeper` ×2.
  - Rot Warden (story 004): `neutral_crypt_brute` ×2 → `neutral_gravekeeper` ×2. The other 10 named neutrals and both exclusions are unchanged (DD-X24).
  - The Torchbearer (story 001): `neutral_ogre_porter` ×2 → `neutral_gravekeeper` ×2. *Included because DD-X20 returns Gravekeeper to "the boss decks that dropped it", and this deck dropped it for the same reason. DD-X20's own list names only the other three. The owner may strike this line; if so, the Torchbearer deviation stays as recorded in story 001.*
  - Rat King is unchanged: leaving Gravekeeper out of its 13 neutrals was a recipe choice, accepted as shipped (DD-X24).
- [ ] **AC-4 (Validator clean)** GIVEN the full data set, WHEN `godot --headless --path . -s res://tools/content/validate.gd` runs, THEN it exits 0 with zero `error` entries and no warning code that the latest content smoke record (`production/qa/smoke-2026-11-04-content-mvp1-*.md`) lacks. Changed values in existing rows (e.g. the neutral `W_SET_SHARE` / curve rows after a 15th neutral) are diffed and recorded. The output is retained in the smoke record.

---

## Implementation Notes

- Order: `ai_profiles.json` row and the boss-ai F9 list in one change (AC-1). The pinning test would go red if one landed without the other. Then the card (AC-2), then the decks (AC-3), then validate (AC-4).
- The row value comes from boss-ai C6 (2026-11-04, DD-X20). It is not tuned here; a different value is a boss-ai GDD change.
- `set_counter` stays unvalued: no shipped card uses it.
- Runtime behaviour of the counter Deathrattle (the raise-time snapshot, C6.5) is card-effects story 009. This story only needs the card to load and validate, as story 001 did for its pulled-forward effects.
- Tests that pin the sprint-4 state change with the data (edits outside data, in scope here):
  - `tests/integration/boss_ai/boss_ai_profiles_data_test.gd::test_op_values_are_f9s_nineteen_card_effects_ops_with_its_values`: 19 → 20, renamed.
  - `tests/integration/content/content_mvp1_data_test.gd`: the Gatekeeper, Rot Warden and Hollow King deck tests named `…_with_the_gravekeeper_slots_on_…` and the 14-neutral assertion (→ 15).
  - `tests/integration/content/content_batch0_data_test.gd`: the batch-0 neutral list comment and the Torchbearer deck pin.
  - Watch each one fail on the old data before trusting it.

---

## Out of Scope

- Rat King's deck (DD-X24). `bundle_neutral_pings_2` (Alpha-B), which also lists Gravekeeper.
- The Boss AI Edge Cases line "valued 1.0, `E_AI_OP_UNVALUED` logged", which reads as a warning while the validator treats it as an error (story 001). This is a separate boss-ai question and is not settled here.
- `/balance-check` F4 re-run for the four decks: story 009 runs it at batch close.

---

## Files

- `assets/data/ai_profiles.json`, `assets/data/cards_neutral.json`, `assets/data/bosses.json`
- `design/gdd/boss-ai.md` (F9 list and note only)
- The three test files above
- `production/qa/smoke-[date].md`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: `standard` — Config/Data evidence is ADVISORY.*

**Story Type**: Config/Data
**Required evidence**:
- Config/Data: smoke check pass (`production/qa/smoke-[date].md`) with the validate output; the updated data tests pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/content/story-001-batch-0-first-playable-data-set.md`, `production/epics/content/story-003-mvp-1-band-1-bosses-rat-king-gatekeeper.md`, `production/epics/content/story-004-mvp-1-bosses-rot-warden-hollow-king.md` (all Complete); `production/epics/boss-ai-match-driver/story-003-ai-profiles-mvp-data.md` (Complete)
- Runtime (not blocking): `production/epics/card-effects/story-009-deathrattle-snapshot-counters.md`
- Unlocks: `production/epics/content/story-009-mvp-1-batch-close-audit-and-balance.md` (AC-2's neutral 15)
