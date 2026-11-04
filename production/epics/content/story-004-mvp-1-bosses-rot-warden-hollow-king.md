# Story 004: MVP-1 — The Rot Warden (band 2) and The Hollow King (band 3) (+ `decay_husk`)

> **Epic**: Content (MVP batch)
> **Status**: Complete
> **Layer**: Feature (data)
> **Type**: Config/Data
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-04

## Context

**GDD**: `design/gdd/content.md` (CN-3 B1/B2/B3 rows `boss_rot_warden`, `boss_hollow_king`; CN-6 MVP-1 row — `decay_husk` in a one-record `cards_decay.json`; AC-10, AC-11, AC-16) · `design/gdd/boss-ai.md` F9 example (Rot Warden override)
**Requirement**: `TR-content-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Data format, effect schema/DSL and `config()` loading; ADR-0006: Boss AI Planner Threading; ADR-0007: Effect Resolver / Validator Boundary
**ADR Decision Summary**: BossDefs, boss cards and the token are CR-3 rows under CR-1 envelopes. `ai_profile` resolves through the Boss AI validator. A passive's event triggers on a passive host are observers (card-effects C9), checked by `EffectValidator.validate_effects`.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (by version) / LOW (no API used by data)
**Engine Notes**: none for data. `cards_decay.json` is an optional `FILE_MANIFEST` row (Alpha set). A one-record file is still a `decay` set present: check that card-database stage 8 raises no `E_COUNT` / `W_POOL_SIZE` for a hero set with no HeroDef (it computes pools per hero set **in `heroes.json`**, card-database story 005).

**Control Manifest Rules (Foundation, data)**:
- Required: `passive` / `effects[]` plain JSON; Boss AI numbers only in `ai_profiles.json`.
- Forbidden: never a `hidden` intent override; never a Decay HeroDef at MVP (CN-6).
- Guardrail: data load ≤ `data_load_budget_ms` 200.

These are the band-2 and band-3 MVP bosses, the run's knowledge spike (floor 4) and its climax. Both use the explicit MVP recipes CN-3 B2 writes for a pool that has no Decay set. Hollow King's deck uses two War cards from story 002.

---

## Acceptance Criteria

*From GDD `design/gdd/content.md` (CN-3, AC-10, AC-11, AC-16), scoped to this story:*

- [x] **AC-1 (BossDefs — AC-10)** GIVEN `bosses.json`, THEN `boss_rot_warden` (band 2, health 40, passive `on_minion_died{who: friendly_minion}` → `enemy_hero` → `damage 1`, tags `["deathrattle"]`) and `boss_hollow_king` (band 3, health 50, passive `turn_start{side: owner}` → `all_friendly_minions` → `buff +1/+1`, tags `["wall"]`) match CN-3 B1. Both have `hero_power` null, `passive_text` and an `intro_text` placeholder. Their `ai_profile` keys resolve through the overrides `{extends: passive_driven, synergy_tags: [deathrattle], weights: {w_self: 1.5}}` / `{extends: control, weights: {w_board: 3.0}}` with zero `E_AI_*`.
- [x] **AC-2 (Decks — CN-3 B2 MVP recipes)** GIVEN each deck, THEN it has exactly 30 non-token ids from MVP-1 or earlier. Hollow King's is `boss_hollow_knight` ×2, `boss_crown_of_thorns` ×2, `war_shield_maiden` ×2, `war_shieldwall_veteran` ×2 and 2× each of the 11 neutrals its B2 row names. Rot Warden's is `boss_rot_zombie` ×3, `boss_mass_rites` ×3 and 2× each of 12 MVP neutrals led by `neutral_gravekeeper` and `neutral_shield_golem`, with the other 10 recorded in Implementation Notes before implementation.
- [x] **AC-3 (Cards and token — AC-11, AC-16)** GIVEN `cards_boss.json`, THEN the four boss cards match CN-3 B3. GIVEN `cards_decay.json`, THEN it holds exactly one record, `decay_husk` (minion 1/1, `token: true`). That token is referenced by `boss_rot_zombie`'s `summon` and is in no deck, bundle or pool. Every new `effects[]` / `passive` validates with zero `E_FX_*` (`boss_mass_rites` uses `all_friendly_minions`, and Rot Warden's `on_minion_died` on a passive host is legal per card-effects C9). The load stays `Ready`, and the smoke check records the report.

---

## Implementation Notes

*Derived from ADR-0002 / ADR-0006 Implementation Guidelines and CN-3:*

- **Open point the GDD does not settle: Rot Warden's 12 neutrals.** B2 names 2 of the 12 ("led by `neutral_gravekeeper` … and `neutral_shield_golem`"). Before `/dev-story`, the owner or game-designer names the other 10 of the 13 remaining MVP neutrals here, following the B2 teaching note (sweepers hurt you; Silence and single big trades do not). Others (game-designer, lane 5, 2026-11-04): `neutral_torch_imp`, `neutral_tunnel_rat`, `neutral_cellar_guard`, `neutral_lantern_bearer`, `neutral_bulwark_smith`, `neutral_dungeon_delver`, `neutral_hush_owl`, `neutral_spark_fiend`, `neutral_banner_captain`, `neutral_wolf_rider`. The reasoning: cheap, many-bodied minions die often, so every trade pings you and a sweeper pings you several times. That is the floor-4 lesson. Hush Owl stays in: a Silence the boss plays does not cancel its own passive. Left out: `neutral_ogre_porter` (one big body that rarely dies) and `neutral_smite_or_mend` (Choose One; the boss can't score it before BAI-010, same as Rat King).
- **`neutral_gravekeeper` slots** (resolved at readiness, 2026-11-04): Gravekeeper is still deferred (story 001: no Boss AI `op_values` row for `add_counter`), so both decks use the content Edge Cases same-batch fallback.
  - **Hollow King**: `boss_hollow_knight` ×3 and `boss_crown_of_thorns` ×3, as story 003 did for Gatekeeper.
  - **Rot Warden**: both its boss cards are already at the ×3 cap, so the two slots go to an MVP neutral from the same batch, `neutral_crypt_brute` ×2. This is the fallback's "neutrals from that batch or earlier" branch.
  - Restoring Gravekeeper is a two-slot swap back in each deck.
- When Alpha-A ships Decay, Decay deathrattle cards replace neutrals in Rot Warden's deck, and at VS three neutrals in Hollow King's deck are replaced (content Edge Cases). Both are later batches: do not pre-author them.
- `decay_husk` is also Grave Tithe's summon (Alpha-A) and Rot's (Alpha-A). At MVP its only referent is `boss_rot_zombie`, which is enough to keep it from being orphaned.

---

## Out of Scope

- Stories 001 / 003: the band-1 bosses. Alpha-A: the rest of `cards_decay.json`.

---

## Files

- `assets/data/bosses.json`: `boss_rot_warden`, `boss_hollow_king`
- `assets/data/cards_boss.json`: `boss_rot_zombie`, `boss_mass_rites`, `boss_hollow_knight`, `boss_crown_of_thorns`
- `assets/data/cards_decay.json` (new): `decay_husk` only
- `production/qa/smoke-2026-11-04-content-mvp1-band23-bosses.md`: Config/Data smoke record
- `tests/integration/content/content_mvp1_data_test.gd`: 9 tests added (AC-1…AC-3); two story-003 totals raised (5 bosses, 11 boss-set cards)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: `standard` — Config/Data evidence is ADVISORY.*

**Story Type**: Config/Data
**Required evidence**:
- Config/Data: smoke check pass (`production/qa/smoke-[date].md`).

**Status**: [x] `production/qa/smoke-2026-11-04-content-mvp1-band23-bosses.md` (PASS) + `tests/integration/content/content_mvp1_data_test.gd` (9 story-004 tests, passing)

---

## Dependencies

- Depends on: `production/epics/content/story-002-mvp-1-war-set.md`; `production/epics/content/story-001-batch-0-first-playable-data-set.md`; `production/epics/boss-ai-match-driver/story-003-ai-profiles-mvp-data.md`
- Unlocks: `production/epics/content/story-009-mvp-1-batch-close-audit-and-balance.md`

---

## Readiness

**`/story-readiness` (by hand, 2026-11-04): NEEDS WORK → resolved from the docs → READY.** Tier: workflow standard (content).

**Passing:**
- CN-3 B1/B2/B3 rows and AC-10/11/16 are quoted.
- ADR-0002, ADR-0006 and ADR-0007 are Accepted; TR-content-001 is active.
- Manifest Version 2026-11-03 is current. Estimate is M. Out of Scope is stated.
- Dependencies are Complete: content 001 and 002, boss-ai 003.
- No marker rows. No asset references.
- 3 criteria; Config/Data, with Test Evidence naming the smoke record.

**Gaps found, and how each was cleared:**
- *Self-contained / open point*: Rot Warden's other 10 neutrals were unnamed ("Others: —"). The lane, acting as game-designer (the note's named owner), named them in Implementation Notes from the B2 teaching note.
- *Testable as written*: both AC-2 recipes include `neutral_gravekeeper`, which can't ship (story 001 deviation; `ai_profiles.json` is out of scope). Cleared with the content Edge Cases same-batch fallback (Implementation Notes) and recorded as deviations.
- *AC-1 "zero `E_AI_*`"*: Boot registers the stage-7b `ai_profile` validator on trunk (sprint-4 L4), so this is now checked through the load. Nothing to resolve.
- *Engine Notes*: the `decay` set with no HeroDef was checked. Stage 8 raises nothing for it (test).

QL-STORY-READY skipped — Lean mode.

## Completion Notes
**Completed**: 2026-11-04
**Started / ended (UTC)**: 2026-11-04T03:51:30Z – 2026-11-04T03:56:42Z
**Criteria**: 3/3 passing. AC-2 has the deviations below.

**Deviations**:
- **Hollow King deck (AC-2)**: `neutral_gravekeeper` ×2 → `boss_hollow_knight` and `boss_crown_of_thorns` at ×3 each (content Edge Cases fallback).
- **Rot Warden deck (AC-2)**: `neutral_gravekeeper` ×2 → `neutral_crypt_brute` ×2. Both boss cards are already at ×3, so the fallback's neutral branch applies.
- **Why, and how to restore**: both deviations come from Gravekeeper staying deferred (story 001). To restore, add the Gravekeeper record once Boss AI values `add_counter`, then swap the slots back. *(2026-11-04, DD-X20: Boss AI now values `add_counter`; both swaps are content story 010.)*
- **Boss-card names**: `Rot Zombie`, `Mass Rites`, `Hollow Knight`, `Crown of Thorns` come from the ids, because CN-3 B3 has no Name column. The token is named `Husk`, from its CN-2 card text.
- **Intro text**: the `intro_text` lines are placeholders (content Open Questions "Intro lines").
- **`boss_rot_zombie` summon position**: `source_slot`, from card-effects C11 row 9, the Deathrattle-summon shape. B3 does not name a position.

**Validate command**: `Ready — 0 errors, 51 warnings (content checks 0 errors, 43 warnings), 69 records`. Before: 51 / 43, 62 records.

**Content story 008 checks (F1–F5)**:
- **No new `W_BUDGET` or `W_CURVE` row.** F2 and F3 read collectible cards only, and this story adds only boss cards and a token.
- **Boss `W_SET_SHARE` (F1)**: it improves (minion share 0.83 → 0.70, spell share 0.17 → 0.30) but is still outside ± 0.08. The 10-card MVP boss set has 3 spells, while the full v1 B3 table, at 17 M / 14 S / 1 W, sits inside the target. Triaged at the batch close (story 009).
- **F5**: unchanged.
- **F4**: not a load-time check; story 009.

**Test Evidence**:
- `production/qa/smoke-2026-11-04-content-mvp1-band23-bosses.md` (PASS).
- `content_mvp1_data_test.gd`: 9 tests added, all seen failing before the records existed. The `E_AI_*` gate was also seen failing on a mutated `ai_profile` key: the load goes `Failed` with `E_AI_PROFILE_UNKNOWN`.
- Full suite: 1238 test cases, 0 failures, exit 0. Smoke exit 0.

**Run result**: N/A, data only. No scene loads these bosses until the match driver and match-ui stories.

**Not here**:
- F4 pressure and the sim harness (story 009).
- At Alpha-A, Decay deathrattle cards replace Rot Warden's neutrals; at VS, three walls replace three of Hollow King's neutrals (content Edge Cases).

**Mass Rites at runtime (2026-11-04, sprint-4 review S5, L7 fix buffer)**: `boss_mass_rites` no longer records `skipped`. The `retrigger` op is built from the card-effects C5 row, with no story; `card_effects_retrigger_test.gd` covers it on the shipped data (QA plan NC-1). The data is unchanged. Two details stay open for game-designer, because neither GDD defines them. The tests do not pin either one:
- **Op outcome when only some targets have a Deathrattle.** C5 names only `no_target` and `no_such_trigger`. The op uses the shared `EffectOps.fold_outcomes`, as every targeted op does, so a mixed board reads `partial` today.
- **Where a `source_slot` summon lands while its source is still on the board.** Match-rules C10 defines only "the dead minion's former index", and C5 only a source that is not in play. `_op_summon` is unchanged: the Husk goes in at the Zombie's current index, pushing the Zombie right. This decides where Mass Rites' Husks appear, and a retriggered Rot Warden board is the first thing to reach it.

**Reviewed by**: independent `/code-review` 2026-11-04 (by hand, `production/reviews/2026-11-04/code-review-s4-unreviewed.md`): **APPROVED WITH SUGGESTIONS** (data; specialist pass N/A). 0 blocking. Should-fix S5 (cross-epic): fixed in the L7 W1 fix buffer; see the Mass Rites note above. Lane record before that review: self, no independent review (lean: QL-TEST-COVERAGE and LP-CODE-REVIEW skipped). Game-designer sign-off NOT ASSESSED (no agent).
**Owner sign-off (2026-11-04, DD-X24)**: Jacob accepts Rot Warden and Hollow King as shipped. This covers Rot Warden's 10 named neutrals and its two exclusions (`neutral_ogre_porter`, `neutral_smite_or_mend`), and both decks' Edge Cases fallbacks, which are superseded for Gravekeeper by DD-X20: content story 010 swaps them back. This replaces the NOT ASSESSED game-designer sign-off above.
