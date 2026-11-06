# Story 006: Hand-size and attack-count folds — Bottomless Satchel, Twin Grip, the post-fold clamps

> **Epic**: Treasures
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-11-04
> **Last Updated**: 2026-11-05
> **Readiness**: READY (2026-11-05, by hand: story 001 and CE-014 Complete, match-rules 003, 004 and 012 Complete, manifest 2026-11-04 current, TR-treasures-001 active. AC-19 and AC-23's missing GIVENs come from T8/T9 and the AC preamble; QL-STORY-READY skipped, Lean mode)
> **First Playable path**: no

## Context

**GDD**: `design/gdd/treasures.md` (T8 rows 7, 12; T9; F2, F3; Edge Cases "Value folds and clamps"; AC-13, AC-19, AC-23)
**Requirement**: `TR-treasures-001` (T2.2 value hooks)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Owner-scoped hook registry (most direct); ADR-0007: Effect Resolver / Validator Boundary
**ADR Decision Summary**: `modify_starting_hand_size` and `modify_max_attacks` fold like cost: treasures first, the passive last. The engine clamps once afterwards, `hand ∈ [0, HAND_SIZE]` and `attacks ∈ [0, MAX_ATTACKS_CAP]`, with bounds from `config("match_rules")`. The base for max attacks is 2 with Windfury, else 1.
**ADR Version**: 2026-11-03 (ADR-0005); 2026-11-03 (ADR-0007)

**Engine**: Godot 4.7.2 | **Risk**: HIGH (language, by version); LOW for the APIs
**Engine Notes**: ADR-0005 Engine Compatibility — no post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: the engine clamps exactly once after the fold (`HAND_SIZE`, `MAX_ATTACKS_CAP` from `config("match_rules")`); a `set` replaces the running value and later `delta`s apply on top
- Forbidden: never clamp inside the fold; never a numeric gameplay literal (2, 4, 10 are data)
- Guardrail: 12-entry fold < 0.05 ms (story 004)

---

## Acceptance Criteria

*From GDD `design/gdd/treasures.md` (AC-13, AC-19, AC-23), scoped to this story:*

- [x] **AC-19** Bottomless Satchel: THEN `mulligan_offered` lists 5 cards, a `keep_mask` of length 5 is accepted and one of length 3 is `INVALID_MASK`; the boss still draws 4.
- [x] **AC-13** GIVEN `[treasure_bottomless_satchel]` and a passive `modify_starting_hand_size delta +6`, WHEN starting hands are dealt, THEN the player's hand is exactly 10 (`clamp(3 + 2 + 6, 0, HAND_SIZE)`), no `card_burned` is emitted during C3 step 5, and the match reaches `Mulligan` without a fault.
- [x] **AC-23** Twin Grip: GIVEN a weapon with 2 durability, THEN the hero attacks twice in one turn (two `attack_resolved`), the weapon is destroyed at the second swing, and a third `attack` is rejected; GIVEN a Windfury weapon, THEN still two attacks (`set 2` replaces the base 2; no third swing).

---

## Implementation Notes

*Derived from ADR-0005 Key Interfaces (engine call sites) and treasures F2 / F3:*

- The two call sites exist (match-rules 003: `_starting_hand_size`; match-rules 012/013: max attacks). This story drives them with the T8 records through `installers_for`, on seed `00000000000000A7`, hero `hero_war`.
- AC-13's passive is a fixture boss (one `modify_starting_hand_size` `delta +6` effect, side boss) built through `Treasures.passive_installer`. The passive must be scoped to the **player's** hand (`scope.side: opponent` from the boss), because a scope relative to `entry.side` is data. Without that the passive changes the boss's own hand, and the test proves nothing.
- AC-23: "rejected" is the C2 code `legal_commands()` reports for a hero with no attacks left (card-effects AC-35 uses `CANNOT_ATTACK`). Assert the code the engine emits; do not add one (DD-X17: the C2 rejection set is closed). After the second swing destroys the weapon, the hero has 0 Attack. Edge Cases names the related case (first swing destroys the weapon, `attacks_remaining` 1 with no legal attack); cover it as a beyond-AC test.
- DD-X15: the hero, not the weapon, is the `damage_dealt` source on a swing.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 005: cost folds; Story 007: trigger hooks
- Match-rules 004 (Complete): the mulligan mask rules

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `tests/integration/treasures/treasures_hand_and_attack_folds_test.gd`
- No production file changed: no case failed

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/treasures/treasures_hand_and_attack_folds_test.gd` — must exist and pass

**Status**: [x] Created, 23 tests, passing

---

## Dependencies

- Depends on: `production/epics/treasures/story-001-installers-passive-and-collect-state.md`. Cross-epic: `production/epics/card-effects/story-014-value-hook-folds.md`; Complete: `production/epics/match-rules/story-003-match-setup.md`, `production/epics/match-rules/story-004-command-channel-and-mulligan.md`, `production/epics/match-rules/story-012-attack-legality.md`
- Unlocks: content story 006 behaviour sign-off for rows 7 and 12

---

## Completion Notes

**Completed**: 2026-11-05
**Start / end (UTC)**: 2026-11-05T04:13:30Z to 2026-11-05T04:30:54Z (the test file was drafted earlier, while story 005's mutants ran)
**Criteria**: 3/3 passing
**Test Evidence**: `tests/integration/treasures/treasures_hand_and_attack_folds_test.gd`, 23 tests
**Run result**: N/A: no scene or screen, and nothing player-observable changed. Full suite 2116 tests, 0 failures; smoke exit 0
**Reviewed by**: pending, the orchestrator's independent `/code-review` at the end of the wave

**Seen failing.** All 23 passed on first run because the call sites already existed, so each was seen failing against a deliberate mutant in `rules_engine.gd`, `ops.gd` or `scope.gd`, restored after each run. Eighteen mutants: no hand fold, no hand clamp, a full hand skipping the offer, the mask checked against the rule, the legal mask at the rule's length, no mulligan redraw, the hand scope ignoring side, two extra cards for every player hand, `set` read as `delta`, base attacks always two, no attack fold, `who` ignored, no attack clamp, the zero-Attack term dropped, the count term dropped, both dropped, the weapon as damage source, no durability loss.

**Finding.** `test_ac13_satchel_and_passive_fill_the_hand_exactly_to_hand_size` still passes with the hand clamp removed: `_draw` burns the 11th card, so the hand stops at 10 anyway. `test_ac13_no_card_burns_during_the_deal` is the case that proves the clamp, and it alone failed that mutant.

**Deviations (ADVISORY).**
- The clean root's `match_rules.json` and `card_effects.json` hold no knobs, so the bodies are `MatchFactory.make_rules_config()` and the inline config the card-effects suites use. Bounds are read back with `RulesEngine.rule`, so no test names 10 or 4.
- The weapon reaches the hand by a state edit and is equipped by a real `play_card`. Scripted weapons load through `TreasureFixtures.database(ids, cards)`, added in story 005.

**Beyond the ACs**: the Edge Cases 1-durability case (story Implementation Notes); DD-X15's swing source; a third swing stopped by the count alone, with durability left; Twin Grip reaching neither a minion nor the boss hero; the `max_attacks_cap` clamp; a partial mulligan of the five; the 10-card mask; the controls without Satchel, with the passive alone and without Twin Grip.
