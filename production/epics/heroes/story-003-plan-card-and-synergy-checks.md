# Story 003: Heroes F2 plan-card count and F5 signature synergy

> **Epic**: Heroes
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-11-04
> **Last Updated**: 2026-11-04
> **First Playable path**: no

## Context

**GDD**: `design/gdd/heroes.md` (F2, F5, H-4, H-5, AC-3, AC-5)
**Requirement**: `TR-heroes-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Data format, effect schema/DSL and `config()` loading
**ADR Decision Summary**: Formula constants are config bodies read once by their owner (`heroes_balance.json`: `plan_min`, `plan_max`, `plan_tags`, `synergy_min`), and card tags come from the frozen card records. No hero value is a code literal.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (by version; APIs LOW)
**Engine Notes**: ADR-0002 Engine Compatibility — no post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: constants from `config("heroes_balance")`, read once at construction; static, pure checks that `ContentValidator` can compose without `Boot`
- Forbidden: never a numeric gameplay literal in run code; never re-parse data outside `CardDatabase`
- Guardrail: none specific (design-time checks, O(set size²) at most ~40 × 40)

Heroes F1 (`E_STARTER_CURVE`) and F4 (`W_SET_SHARE`) already run in the content validate command (content story 008, Complete). F2 and F5 are the two Heroes formulas with no code yet. On the shipped data, War scores F2 = 7 and its three signature cards score F5 = 17, 19 and 19 (checked by hand while writing this story), so both ACs should pass on the first green run.

---

## Acceptance Criteria

*From GDD `design/gdd/heroes.md` (F2, F5, AC-3, AC-5), scoped to this story:*

- [x] **AC-3** GIVEN each launch starter present in the content batch (`hero_war` at MVP-0), WHEN F2 is evaluated, THEN `plan_cards ∈ [plan_min, plan_max]` = [4, 7] (War 7, counting Content's `armour` tag on `war_iron_vanguard`); GIVEN a fixture starter with 8 plan cards, THEN the result is reported out of band.
- [x] **AC-F2 (F2 counting rule)** GIVEN a fixture starter card carrying two plan tags (e.g. `[weapons, aggro]`), WHEN F2 is evaluated, THEN that card counts once; a card with no tag in `plan_tags[hero.set]` (e.g. a neutral without a War tag) does not count; duplicates in the starter count per copy (F2 counts cards in the 15).
- [x] **AC-5** GIVEN the H-5 signature cards of each hero present (War: `war_duelists_edge`, `war_pit_champion`, `war_cleave_through` at MVP; all nine from Alpha-B), WHEN F5 is evaluated over `set(hero) ∪ starter(hero)` excluding the card itself, THEN each has `synergy ≥ synergy_min` (5); GIVEN a fixture signature card whose tags no other card shares, THEN synergy is 0 and it is reported below `synergy_min`.

---

## Implementation Notes

*Derived from ADR-0002 Implementation Guidelines and Heroes F2 / F5:*

- Add static functions to `Heroes` (story 002's class) that take their inputs as parameters: `plan_card_count(starter_ids: Array, plan_tags: Array, db) -> int` and `synergy(card_id: String, hero_id: String, db) -> int`, plus a band check that reads `plan_min`, `plan_max` and `synergy_min` from the `heroes_balance` body passed in. Keep them pure, so the content validate command can compose them later the way it composes `ContentValidator`'s F1–F5.
- F2: `plan_cards = |{i : tags(card_i) ∩ PLAN_TAGS(hero) ≠ ∅}|` over the 15 entries; `PLAN_TAGS(hero) = heroes_balance.plan_tags[hero.set]`.
- F5: `synergy(card) = |{c ∈ set(hero) ∪ starter(hero), c ≠ card : tags(c) ∩ tags(card) ≠ ∅}|`. Count distinct card ids (the union is a set). `set(hero)` is `db.cards_by_set(hero.set)` without tokens; the starter's neutrals join through the union.
- **Signature cards are not marked in data.** H-5 names them in prose and no record field flags them, so the test carries the H-5 ids as named constants that cite H-5 (the "exact value IS the point" exception in coding-standards).
- **GDD gap, not blocking:** F2 and F5 name no report code or severity, while F1 has `E_STARTER_CURVE` and F4 has `W_SET_SHARE`. So this story returns values and an in-band verdict, and does not add a code to the validate command's report. Wiring F2/F5 into `tools/content/validate.gd` waits on a heroes GDD revision that names the codes and a signature marker (`/quick-design`). Record this in the story's Completion Notes.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Content story 008 (Complete): F1 `E_STARTER_CURVE`, F4 `W_SET_SHARE`, `W_HERO_HEALTH` (GDD AC-2 and AC-4 are verified there)
- Story 004: validating the `heroes_balance.json` body itself
- F3 hero power value: a design-time estimate for `/balance-check`, with no runtime or load-time check in the GDD

---

## Files

- `src/gameplay/heroes/heroes.gd`: F2 / F5 static functions (`plan_card_count`, `plan_cards_in_band`, `synergy`, `synergy_in_band`)
- `tests/unit/heroes/heroes_plan_and_synergy_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/heroes/heroes_plan_and_synergy_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] Created, 17 tests, passing

---

## Dependencies

- Depends on: `production/epics/heroes/story-002-heroes-accessor.md`
- Unlocks: None (a later validate-command wiring once the GDD names the F2/F5 codes)

---

## Completion Notes
**Completed**: 2026-11-04
**Start / end (UTC)**: 2026-11-04T19:50:56Z to 2026-11-04T19:57:11Z
**Readiness**: READY (2026-11-04). ADR-0002 Accepted at the story's version, manifest 2026-11-04 matches, story 002 Complete.
**Criteria**: 3/3 passing
**Test Evidence**: `tests/unit/heroes/heroes_plan_and_synergy_test.gd`, 17 tests. Full suite 1458 cases, 0 failures.
**Seen failing**: all 17, each on its own assertion, against stub functions returning -1 and false (the missing code).
**Figures**: F2 War 7; F5 `war_duelists_edge` 17, `war_pit_champion` 19, `war_cleave_through` 19. Recounted independently from the JSON with a script; they match the story's hand check.
**Run result**: N/A: design-time formulas with no runtime or screen caller yet.
**Deviations**:
- ADVISORY: the band check is two functions, `plan_cards_in_band` and `synergy_in_band`, where the notes say "a band check": F2 has two bounds and F5 one.
- ADVISORY: the shipped-data cases load `assets/data/` from a unit test, because the story names this one file. `boss_ai_profile_resolver_test.gd` reads committed data the same way.
- The QA plan's "add 3, below `plan_min`" is covered.
**GDD gap (from the story, not blocking)**: F2 and F5 name no report code or severity, while F1 has `E_STARTER_CURVE` and F4 has `W_SET_SHARE`, and no record marks a signature card. So these return values and an in-band verdict and add nothing to the validate command's report. Wiring them into `tools/content/validate.gd` waits on a heroes GDD revision naming the codes and a signature marker (`/quick-design`).
**Reviewed by**: independent `/code-review`, 2026-11-04 (`production/reviews/2026-11-04/code-review-s5-w1-heroes-treasures.md`, summary scope: correctness and contract risk only): **APPROVED WITH SUGGESTIONS**. Open: `synergy`'s doc nit, and the design question that nothing runs F2 and F5 in `validate.gd`
