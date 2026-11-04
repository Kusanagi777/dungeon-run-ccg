# Story 005: Cost-fold treasures — Worn Signet, Vanguard's Banner, stacked discounts

> **Epic**: Treasures
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-11-04
> **Last Updated**: [set by /dev-story when implementation begins]
> **First Playable path**: no

## Context

**GDD**: `design/gdd/treasures.md` (T8 rows 2, 4, 17; T9; F2; Edge Cases "Value folds and clamps"; AC-8, AC-16, AC-17)
**Requirement**: `TR-treasures-001` (T2.2 value hooks fold in installation order)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Owner-scoped hook registry (most direct); ADR-0007: Effect Resolver / Validator Boundary (`apply_value_hook`)
**ADR Decision Summary**: In a value fold, entry *n*'s output is entry *n+1*'s input (`delta` adds, `set` replaces). The engine clamps exactly once after the whole fold, and the resolver evaluates `scope` relative to `entry.side`. `scope.card` without `kind` matches card instances only and `kind: hero_power` matches the power only (R-13). A `condition` on a value trigger is re-evaluated on every fold call (R-2).
**ADR Version**: 2026-11-03 (ADR-0005); 2026-11-03 (ADR-0007)

**Engine**: Godot 4.7.2 | **Risk**: HIGH (language, by version); LOW for the APIs
**Engine Notes**: ADR-0005 Engine Compatibility — no post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: the engine clamps once after the fold with bounds from `config("match_rules")`; `side` passed on every invocation; magnitudes come from `treasures.json`
- Forbidden: never clamp inside the fold or a `modify_value` op (`1 − 1 − 1 → 0`, not `0 → 0`); never special-case "player only" in engine code
- Guardrail: 12-entry fold < 0.05 ms (story 004)

Card-effects 014 builds the fold evaluator against fixture rows. This story proves the three cost treasures from the T8 records, as the player sees them: the displayed cost, the mana paid and the hero-power button.

---

## Acceptance Criteria

*From GDD `design/gdd/treasures.md` (AC-8, AC-16, AC-17), scoped to this story:*

- [ ] **AC-16** Worn Signet: THEN the hero-power button shows 1 (`hero_power_cost("player") == 1`); using it spends 1 mana; a second use the same turn is rejected `HERO_POWER_USED`; against `boss_test_taxman` it shows 2.
- [ ] **AC-17** Vanguard's Banner: GIVEN player turn 4 (4 mana) with a 3-cost minion and a 2-cost spell in hand, THEN both show −1 before any play; after playing the minion for 2, the spell shows 2 and is playable, ending at 0 mana; the hero-power cost is unaffected throughout (card-effects C2: `scope.card` without `kind` matches card instances only — R-13).
- [ ] **AC-8** GIVEN `[treasure_vanguards_banner, treasure_dogeared_grimoire]` and a 1-cost spell as the first card of the turn, THEN its displayed and paid cost is 0 and the F1 event logs `hook_delta: −2` (fold `1 − 1 − 1 = −1`, floored to 0 once).

---

## Implementation Notes

*Derived from ADR-0005 Decision rule 4 and Key Interfaces (engine call sites):*

- Every case builds `MatchConfig.player.hook_installers` with `installers_for` (story 001) over the 20-record fixture, on seed `00000000000000A7` and hero `hero_war` (GDD AC preamble). Hands are scripted.
- "Displayed cost" is `RulesEngine.effective_cost` / `hero_power_cost`, the same value `legal_commands()` uses. "Paid" is the `mana_current` delta after the accepted `play_card` / `use_hero_power`.
- Banner's condition `owner.cards_played_this_turn == 0` is read at each F1 evaluation. After one play it is false, so the fold returns the value unchanged and no clamp is involved. A 0-cost card still counts as played (Edge Cases).
- AC-8's `hook_delta` is the F1 event field card-effects 014 adds (`effect_resolved.values` / the cost event). Assert the field the engine emits, and record in Completion Notes if its home differs.
- Dog-eared Grimoire is not an MVP treasure (unlock `hero_knowledge_first_win`). It is used here only as a fixture record; nothing ships it.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 006: hand-size and max-attacks folds; Story 007: trigger hooks; Story 008: auras
- Card-effects 014: the evaluator and the `hook_delta` field; match-rules 011 (Complete): `effective_cost` and the clamp

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `tests/integration/treasures/treasures_cost_folds_test.gd`
- No production file planned (behaviour is card-effects 014 and match-rules 011; a failing case is fixed where it lives)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/treasures/treasures_cost_folds_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/treasures/story-001-installers-passive-and-collect-state.md`. Cross-epic: `production/epics/card-effects/story-014-value-hook-folds.md`; Complete: `production/epics/match-rules/story-011-effective-cost-and-temporary-mana.md`, `production/epics/match-rules/story-010-play-card-and-hero-power.md`
- Unlocks: content story 006 behaviour sign-off for rows 2 and 4; Heroes GDD AC-15 coverage (a cost-reduced power is still once per turn)
