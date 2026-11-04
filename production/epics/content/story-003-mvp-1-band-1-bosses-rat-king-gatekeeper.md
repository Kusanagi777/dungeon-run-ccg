# Story 003: MVP-1 — band-1 bosses The Rat King and The Gatekeeper (+ `boss_rat`, Smite or Mend)

> **Epic**: Content (MVP batch)
> **Status**: Complete
> **Layer**: Feature (data)
> **Type**: Config/Data
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-04

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
- **Open point the GDD does not settle: Rat King's 13 neutrals.** B2 says "2× 13 MVP neutrals ≤ 5 cost", and all 15 MVP neutrals cost ≤ 5, so two must be left out. Before `/dev-story`, the owner or game-designer names them here, following the B2 teaching note: small minions trade into Taunt, and `w_trade 0.2` feeds Rats into Taunts. Excluded: `neutral_gravekeeper` / `neutral_smite_or_mend` (game-designer, lane 5, 2026-11-04). Gravekeeper is not shippable yet (story 001 deviation: `add_counter` has no `op_values` row). Smite or Mend is the only spell among the 15; leaving it out keeps the swarm deck all bodies, so the floor-1 lesson is "trade minions into Rats and Taunts", and the boss never holds a Choose One it cannot yet score (BAI-010).
- **Gatekeeper's `neutral_gravekeeper` slots** (resolved at readiness, 2026-11-04): Gravekeeper stays deferred, so its two B2 slots take the content Edge Cases same-batch fallback, "duplicates up to ×3 of a boss card": `boss_iron_gate` ×3, `boss_gate_warden` ×3, plus the other 12 recipe neutrals ×2. The deck stays inside the recipe's ids, so restoring Gravekeeper is a two-slot swap back.
- `boss_rat` lives in `cards_boss.json` (its `boss_` prefix must match the file's set, CR-2 `E_SET_MISMATCH`). CR-2 requires its id not to collide with any BossDef id.
- `ai_profile` values are the boss ids, which key the boss-ai story 003 `boss_overrides`. This story never edits `ai_profiles.json`.

---

## Out of Scope

- Story 001: The Torchbearer. Story 004: Rot Warden, Hollow King, `decay_husk`.
- Boss AI epic: `ai_profiles.json` and the resolver; Card Effects epic: runtime of `summon` / aura.

---

## Files

- `assets/data/bosses.json` — `boss_rat_king`, `boss_gatekeeper`
- `assets/data/cards_boss.json` — `boss_rat_pack`, `boss_rat_matriarch`, `boss_iron_gate`, `boss_gate_warden`, token `boss_rat`
- `assets/data/cards_neutral.json` — `neutral_smite_or_mend`
- `production/qa/smoke-2026-11-04-content-mvp1-band1-bosses.md` — Config/Data smoke record
- `tests/integration/content/content_mvp1_data_test.gd` — 10 tests added (AC-1…AC-3)
- `tests/integration/content/content_batch0_data_test.gd` — three shipped-data pins relaxed to the batch-0 subset (neutral set, band 1, boss set)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: `standard` — Config/Data evidence is ADVISORY.*

**Story Type**: Config/Data
**Required evidence**:
- Config/Data: smoke check pass (`production/qa/smoke-[date].md`).

**Status**: [x] `production/qa/smoke-2026-11-04-content-mvp1-band1-bosses.md` (PASS) + `tests/integration/content/content_mvp1_data_test.gd` (10 story-003 tests, passing)

---

## Dependencies

- Depends on: `production/epics/content/story-001-batch-0-first-playable-data-set.md`; `production/epics/boss-ai-match-driver/story-002-profile-resolver-and-validator.md`, `production/epics/boss-ai-match-driver/story-003-ai-profiles-mvp-data.md`
- Unlocks: `production/epics/content/story-009-mvp-1-batch-close-audit-and-balance.md`

---

## Readiness

**`/story-readiness` (by hand, 2026-11-04): NEEDS WORK → resolved from the docs → READY.** Tier: workflow standard (content). Passing: CN-3 B1/B2/B3 rows quoted; ADR-0002 / ADR-0006 / ADR-0007 Accepted; TR-content-001 active; Manifest Version 2026-11-03 = current; estimate M; Out of Scope stated; dependencies (content 001, boss-ai 002, 003) Complete; no marker rows (lint 0); no asset references; 3 criteria, Config/Data, Test Evidence names the smoke record. Gaps found and how they were cleared:
- *Self-contained / open point*: Rat King's two excluded neutrals were unnamed ("— / —"). Named in Implementation Notes by the lane acting as game-designer (the note's named owner), from the B2 teaching note.
- *Testable as written*: AC-2's Gatekeeper recipe and AC-3's "neutral set to 15" both include `neutral_gravekeeper`, which cannot ship (story 001 deviation; `ai_profiles.json` is out of scope). Cleared with the content Edge Cases same-batch fallback (Implementation Notes) and recorded as deviations.
- *AC-1 "zero `E_AI_*`"*: the stage-7b registration is not on this branch (lane 4 adds it to `boot.gd` in parallel). Per the orchestrator's brief, proven by running `BossAI.validate_ai_profile` directly over the shipped boss rows in a test; Boot's registration lands at merge.
QL-STORY-READY skipped — Lean mode.

## Completion Notes
**Completed**: 2026-11-04
**Started / ended (UTC)**: 2026-11-04T03:02:22Z – 2026-11-04T03:07:47Z (readiness reading overlapped story 002, from 2026-11-04T02:44Z)
**Criteria**: 3/3 passing — AC-1 by direct validator run (the Boot registration lands at merge), AC-2 and AC-3 with the deviations below
**Deviations**:
- **Gatekeeper deck (AC-2)**: `neutral_gravekeeper` ×2 → `boss_iron_gate` and `boss_gate_warden` at ×3 each (content Edge Cases fallback), because Gravekeeper stays deferred (story 001). To restore: once Boss AI values `add_counter`, add the Gravekeeper record and swap the two slots back. *(2026-11-04, DD-X20: Boss AI now values `add_counter`; the swap is content story 010. Rat King's exclusion stands, DD-X24.)*
- **Neutral set 14, not 15 (AC-3)**: same cause.
- **AC-1 "zero `E_AI_*`" through the load**: Boot still lists `ai_profile` in `PENDING_RECORD_OWNERS` on this branch, so the load shows one `W_VALIDATOR_PENDING` row on `bosses.json`. `BossAI.validate_profiles_config` + `validate_ai_profile` over all three shipped bosses return zero rows (test, seen failing on a mutated key). With lane 4's line `map["ai_profile"] = BossAI.validate_ai_profile` trialled and reverted, validate reads `Ready — 0 errors, 9 warnings`.
- Boss-card display names (`Rat Pack`, `Rat Matriarch`, `Iron Gate`, `Gate Warden`) come from the ids: CN-3 B3 has no Name column. The `intro_text` lines are placeholders (content Open Questions "Intro lines").
- `tests/integration/content/content_batch0_data_test.gd` edited (outside the Files list): its exact pins on the neutral set, band 1 and the boss set now check that the batch-0 rows are still present.
**Validate command**: `Ready — 0 errors, 10 warnings, 55 records` (before: 10 warnings, 47 records). `W_POOL_SIZE` unchanged at 2: this story adds no bundle or treasure, and the collectible pool was already clear after story 002.
**Not here**: F4 pressure and the sim harness (story 009); Gatekeeper's Smite or Mend needs BAI-010 `choose` scoring at runtime.
**Test Evidence**: `production/qa/smoke-2026-11-04-content-mvp1-band1-bosses.md` (PASS); `tests/integration/content/content_mvp1_data_test.gd` (+10 tests, all seen failing before the records were added). Full suite 1096 test cases, 0 failures, exit 0; smoke exit 0.
**Run result**: N/A — data only; no scene loads these bosses until the match driver and match-ui stories, and the smoke run stays clean.
**Reviewed by**: self, no independent review (lean — QL-TEST-COVERAGE and LP-CODE-REVIEW skipped); game-designer sign-off NOT ASSESSED (no agent)
**Owner sign-off (2026-11-04, DD-X24)**: Jacob accepts both band-1 bosses as shipped. This covers Rat King's two excluded neutrals (`neutral_gravekeeper`, `neutral_smite_or_mend`), which stand as a recipe choice, and Gatekeeper's Edge Cases fallback, which is superseded for Gravekeeper by DD-X20: content story 010 swaps it back. This replaces the NOT ASSESSED game-designer sign-off above.
