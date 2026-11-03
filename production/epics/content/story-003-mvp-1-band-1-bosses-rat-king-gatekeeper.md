# Story 003: MVP-1 — band-1 bosses The Rat King and The Gatekeeper (+ `boss_rat`, Smite or Mend)

> **Epic**: Content (MVP batch)
> **Status**: Ready
> **Layer**: Feature (data)
> **Type**: Config/Data
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/content.md` (CN-3 B1/B2/B3 rows `boss_rat_king`, `boss_gatekeeper`; CN-2 `neutral_smite_or_mend`; tokens line; AC-10, AC-11, AC-16) · `design/gdd/boss-ai.md` C10 (profile keys)
**Requirement**: `TR-content-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Data format, effect schema/DSL and `config()` loading; ADR-0006: Boss AI Planner Threading (profile resolution `default ⊕ archetype ⊕ band ⊕ boss override`); ADR-0007: Effect Resolver / Validator Boundary
**ADR Decision Summary**: `BossDef` rows in `bosses.json` (CR-3) carry an opaque `ai_profile` key, which the Boss AI validator resolves against `ai_profiles.json`, and a `passive` that `EffectValidator.validate_effects` checks. Decks are id lists cross-checked at CR-5 step 6 (`E_UNKNOWN_REF`, `E_TOKEN_IN_LIST`).
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (ADR-0006 / ADR-0002 by version) / LOW (no API used by data)
**Engine Notes**: none for data. Profile resolution runs in the Boss AI validator (boss-ai-match-driver story 002).

**Control Manifest Rules (Foundation, data)**:
- Required: `passive` and `effects[]` are plain JSON; all Boss AI numbers come from `ai_profiles.json` (never from `bosses.json`).
- Forbidden: no boss uses `intent_mode: hidden` (CN-3, cross-review D-04).
- Guardrail: data load ≤ `data_load_budget_ms` 200.

These are the other two MVP band-1 bosses: Rat King (swarm) and Gatekeeper (wall). With Torchbearer from batch 0 the band-1 pool is 3, so the MVP run (`band_split [2, 1, 1]`) draws 2 of the 3 and the boss sequence varies (D-06). The story also adds the last MVP neutral, which Gatekeeper's recipe uses, and the `boss_rat` token, which Rat King summons.

---

## Acceptance Criteria

*From GDD `design/gdd/content.md` (CN-3, AC-10, AC-11, AC-16), scoped to this story:*

- [ ] **AC-1 (BossDefs — AC-10)** GIVEN `bosses.json`, WHEN loaded, THEN `boss_rat_king` and `boss_gatekeeper` match their CN-3 B1 rows. Each has band 1, health 30, `hero_power` null, the B1 passive with its `passive_text`, theme tags `["swarm"]` / `["wall"]`, an `intro_text` placeholder naming the passive, and an `ai_profile` that resolves through the `ai_profiles.json` overrides (`{extends: aggro}` / `{extends: control}`) with zero `E_AI_*`.
- [ ] **AC-2 (Decks — CN-3 B2, AC-10)** GIVEN each boss's `deck`, THEN it has exactly 30 non-token ids from batch MVP-1 or earlier. Gatekeeper's is 2× `boss_iron_gate`, 2× `boss_gate_warden` and 2× each of the 13 neutrals its B2 row names. Rat King's is 2× `boss_rat_pack`, 2× `boss_rat_matriarch` and 2× each of 13 MVP neutrals ≤ 5 cost, with the two excluded neutrals recorded in Implementation Notes before implementation.
- [ ] **AC-3 (Cards and token — AC-11, AC-16)** GIVEN `cards_boss.json` and `cards_neutral.json`, THEN the four boss cards match CN-3 B3 (set `boss`, `common`); the token `boss_rat` (minion 1/1, tag `rat`, `token: true`) is referenced by the Rat King passive's and `boss_rat_pack`'s `summon` ops and appears in no deck, bundle or pool; `neutral_smite_or_mend` matches its CN-2 row (Choose One, row 33), bringing the neutral set to 15. Every new `effects[]` / `passive` validates with zero `E_FX_*`, `boss_rat_matriarch`'s board `tag` filter included (card-effects C3, OQ resolved). The load stays `Ready`, and the smoke check records the report.

---

## Implementation Notes

*Derived from ADR-0002 / ADR-0006 Implementation Guidelines and CN-3:*

- Passives: Rat King `turn_start{side: owner}` → `summon boss_rat ×1 position: end` (C11 row 9); Gatekeeper `aura` → `all_friendly_minions` → `aura keywords: [taunt]` (row 42).
- **Open point the GDD does not settle: Rat King's 13 neutrals.** B2 says "2× 13 MVP neutrals ≤ 5 cost", and all 15 MVP neutrals cost ≤ 5, so two must be left out. Before `/dev-story`, the owner or game-designer names them here, following the B2 teaching note: small minions trade into Taunt, and `w_trade 0.2` feeds Rats into Taunts. Excluded: — / —.
- `boss_rat` lives in `cards_boss.json` (its `boss_` prefix must match the file's set, CR-2 `E_SET_MISMATCH`). CR-2 requires its id not to collide with any BossDef id.
- `ai_profile` values are the boss ids, which key the boss-ai story 003 `boss_overrides`. This story never edits `ai_profiles.json`.

---

## Out of Scope

- Story 001: The Torchbearer. Story 004: Rot Warden, Hollow King, `decay_husk`.
- Boss AI epic: `ai_profiles.json` and the resolver; Card Effects epic: runtime of `summon` / aura.

---

## Files

- `assets/data/bosses.json`, `assets/data/cards_boss.json`, `assets/data/cards_neutral.json`
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

- Depends on: `production/epics/content/story-001-batch-0-first-playable-data-set.md`; `production/epics/boss-ai-match-driver/story-002-profile-resolver-and-validator.md`, `production/epics/boss-ai-match-driver/story-003-ai-profiles-mvp-data.md`
- Unlocks: `production/epics/content/story-009-mvp-1-batch-close-audit-and-balance.md`
