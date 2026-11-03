# Story 011: Hero powers — Whetstone, Rot and Insight through the `hero_power` trigger

> **Epic**: Card Effects
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/card-effects.md`
**Requirement**: `TR-card-effects-002` (`hero_power` is a play trigger; DD-M13)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Effect Resolver / Validator Boundary
**ADR Decision Summary**: A hero power is a `hero_power`-triggered effect on a `HeroPowerDef` host, resolved as the first step of the `hero_power` command through primitives only; a hero power is "a spell-like effect that is not a spell" (no Spell Damage by default, F1); `conditional` reads live state inside the atomic pass (C6.0).
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (by version; the APIs used predate 4.3 and are LOW)
**Engine Notes**: ADR-0007 Engine Compatibility — no post-cutoff APIs.

**Control Manifest Rules (this layer)**:
- Required: mutate only through primitives (`equip_weapon`, `apply_enchantment`, `apply_damage`, `summon_minion`, `draw`); one effect pass = one C10 step
- Forbidden: never call the death check between ops (Rot's `is_dying` depends on it); never write match state directly (gate G7)
- Guardrail: `RulesEngine.submit()` ≤ 5 ms

---

## Acceptance Criteria

*From GDD `design/gdd/card-effects.md` (C11 rows 8, 16, 25; C3 `is_dying`, `deck_top`; C5 `buff` on deck cards, `summon position`; Edge Cases; AC-15, AC-43, AC-44), scoped to this story:*

- [ ] **AC-15** GIVEN row 8 (War hero power Whetstone) with no weapon, WHEN used, THEN `weapon_equipped` (1/2 `war_whetstone_blade`) and `effect_resolved.ops[0].values.branch == "else"`; WHEN used next turn with the Blade held, THEN `enchantment_applied{attack_delta: 1, expires: end_of_turn}` on the weapon and no equip (`branch == "then"`); at that End step the enchantment is removed (`enchantment_removed`).
- [ ] **AC-43** GIVEN row 16 (Rot) used on an enemy 2/1, WHEN resolved, THEN the log reads `damage_dealt{amount: 1}`, `minion_summoned{decay_husk}` at the rightmost friendly slot (`position: end`), `effect_resolved` (`ops[1].outcome == applied`), then `minion_died` for the target — the Husk arrives before the target's Deathrattle resolves; GIVEN an enemy 2/3 instead, THEN damage only, no `minion_summoned`, `ops[1].outcome == skipped`; GIVEN a 1/1 with Divine Shield, THEN `divine_shield_popped`, no summon (`is_dying` stays false).
- [ ] **AC-44** GIVEN row 25 (Insight) with a 3-cost spell on top of the deck, WHEN used, THEN `enchantment_applied{cost_delta: 1, expires: end_of_turn}` precedes `card_drawn`, that card's `effective_cost` reads 4 until the owner's End step and 3 after it; GIVEN an empty deck, THEN `ops[0].outcome == no_target` and one fatigue damage event, no enchantment.

---

## Implementation Notes

*Derived from ADR-0007 Decision 1 and GDD C11 rows 8 / 16 / 25:*

- Heroes H-3's sketch vocabulary maps 1:1 and adds nothing: `branch` → `conditional`, `has_weapon` → `{exists: owner_weapon}`, `enchant` → `buff`, `equip_weapon` → `equip`, `left_play` → `is_dying`, `bind/$drawn` → `buff` on `deck_top` then `draw`. No `targeting` field (C1 rule 1); the `hero_power` command supplies `target_id` for Rot and Brand.
- `conditional` logs the evaluated condition and the branch taken in `values` (`branch: then | else`); the branch not taken is one `skipped` entry.
- `summon` from a non-minion source (hero power) resolves `source_slot` / `right_of_source` to `end` (C5).
- `buff` with `cost` on a `deck_top` instance: the enchantment travels with the instance into hand (C5); expiry is match-rules C4 End step 5 (card instances in S's hand and deck are included — cross-review C-16a).
- The Spell Damage rule for hero powers is F1 (`auto` → host is not a spell → no scaling) and is already covered by story 007's AC-13; Brand (row 44) needs nothing new here.
- The hero-power host is `db.hero_power(id)`; `host_kind: hero_power` in `effect_resolved`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 006: play-trigger plumbing; Story 007: `conditional`, value refs
- Story 012: enchantment expiry (`until_end_of_turn`) in general — this story asserts it through the weapon and the drawn card only
- `production/epics/heroes/`: `hero_powers.json` content and hero identities; `production/epics/match-rules/`: the `hero_power` command, `HERO_POWER_USED`, Freeze not blocking powers

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/gameplay/effects/effect_resolver.gd` (`hero_power` host lookup)
- `src/gameplay/effects/ops.gd` (`equip`, `buff` on deck instances, `summon` position fallback)
- `src/gameplay/effects/selectors.gd` (`deck_top`, `is_dying` predicate)
- `tests/unit/card_effects/card_effects_hero_powers_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/card_effects/card_effects_hero_powers_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/card-effects/story-006-play-triggers-one-pass.md`, `production/epics/card-effects/story-007-values-selectors-spell-damage.md`. Cross-epic: `production/epics/match-rules/` (`hero_power` command, `equip_weapon`, `apply_enchantment` on card instances, End step 5 expiry, fatigue), `production/epics/heroes/` (the three `HeroPowerDef` records — the fixture from story 005 carries rows 8/16/25 until then).
- Unlocks: gate entry condition 5 (War starter deck resolves) together with story 006; `production/epics/heroes/` stories
