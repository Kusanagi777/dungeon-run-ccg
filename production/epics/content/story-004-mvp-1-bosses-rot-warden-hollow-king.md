# Story 004: MVP-1 — The Rot Warden (band 2) and The Hollow King (band 3) (+ `decay_husk`)

> **Epic**: Content (MVP batch)
> **Status**: Ready
> **Layer**: Feature (data)
> **Type**: Config/Data
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

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

- [ ] **AC-1 (BossDefs — AC-10)** GIVEN `bosses.json`, THEN `boss_rot_warden` (band 2, health 40, passive `on_minion_died{who: friendly_minion}` → `enemy_hero` → `damage 1`, tags `["deathrattle"]`) and `boss_hollow_king` (band 3, health 50, passive `turn_start{side: owner}` → `all_friendly_minions` → `buff +1/+1`, tags `["wall"]`) match CN-3 B1. Both have `hero_power` null, `passive_text` and an `intro_text` placeholder. Their `ai_profile` keys resolve through the overrides `{extends: passive_driven, synergy_tags: [deathrattle], weights: {w_self: 1.5}}` / `{extends: control, weights: {w_board: 3.0}}` with zero `E_AI_*`.
- [ ] **AC-2 (Decks — CN-3 B2 MVP recipes)** GIVEN each deck, THEN it has exactly 30 non-token ids from MVP-1 or earlier. Hollow King's is `boss_hollow_knight` ×2, `boss_crown_of_thorns` ×2, `war_shield_maiden` ×2, `war_shieldwall_veteran` ×2 and 2× each of the 11 neutrals its B2 row names. Rot Warden's is `boss_rot_zombie` ×3, `boss_mass_rites` ×3 and 2× each of 12 MVP neutrals led by `neutral_gravekeeper` and `neutral_shield_golem`, with the other 10 recorded in Implementation Notes before implementation.
- [ ] **AC-3 (Cards and token — AC-11, AC-16)** GIVEN `cards_boss.json`, THEN the four boss cards match CN-3 B3. GIVEN `cards_decay.json`, THEN it holds exactly one record, `decay_husk` (minion 1/1, `token: true`). That token is referenced by `boss_rot_zombie`'s `summon` and is in no deck, bundle or pool. Every new `effects[]` / `passive` validates with zero `E_FX_*` (`boss_mass_rites` uses `all_friendly_minions`, and Rot Warden's `on_minion_died` on a passive host is legal per card-effects C9). The load stays `Ready`, and the smoke check records the report.

---

## Implementation Notes

*Derived from ADR-0002 / ADR-0006 Implementation Guidelines and CN-3:*

- **Open point the GDD does not settle: Rot Warden's 12 neutrals.** B2 names 2 of the 12 ("led by `neutral_gravekeeper` … and `neutral_shield_golem`"). Before `/dev-story`, the owner or game-designer names the other 10 of the 13 remaining MVP neutrals here, following the B2 teaching note (sweepers hurt you; Silence and single big trades do not). Others: —.
- When Alpha-A ships Decay, Decay deathrattle cards replace neutrals in Rot Warden's deck, and at VS three neutrals in Hollow King's deck are replaced (content Edge Cases). Both are later batches: do not pre-author them.
- `decay_husk` is also Grave Tithe's summon (Alpha-A) and Rot's (Alpha-A). At MVP its only referent is `boss_rot_zombie`, which is enough to keep it from being orphaned.

---

## Out of Scope

- Stories 001 / 003: the band-1 bosses. Alpha-A: the rest of `cards_decay.json`.

---

## Files

- `assets/data/bosses.json`, `assets/data/cards_boss.json`, `assets/data/cards_decay.json`
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

- Depends on: `production/epics/content/story-002-mvp-1-war-set.md`; `production/epics/content/story-001-batch-0-first-playable-data-set.md`; `production/epics/boss-ai-match-driver/story-003-ai-profiles-mvp-data.md`
- Unlocks: `production/epics/content/story-009-mvp-1-batch-close-audit-and-balance.md`
