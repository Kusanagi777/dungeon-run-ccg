# Story 012: Auras (`recompute_auras`), hand-cost auras and the enchantment lifecycle (F2, F3)

> **Epic**: Card Effects
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/card-effects.md`
**Requirement**: `TR-card-effects-002` (C7 auras are composed from the `apply_enchantment(…, is_aura: true)` primitive inside the engine's `recompute_auras()` callback; the epic's module list names `recompute_auras()` under this requirement)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Effect Resolver / Validator Boundary
**ADR Decision Summary**: The engine's C10 loop calls `resolver.recompute_auras()` after every step; the resolver re-applies every live aura through the enchantment primitive in canonical source order and never calls `recompute_auras()` itself between ops.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (by version; the APIs used predate 4.3 and are LOW)
**Engine Notes**: ADR-0007 Engine Compatibility — no post-cutoff APIs.

**Control Manifest Rules (this layer)**:
- Required: `RulesEngine` owns the C10 loop (death check → `recompute_auras()` → queue pop); the resolver mutates only through primitives
- Forbidden: never call the death check or `recompute_auras()` between ops; never write `enchantments[]` directly (gate G7)
- Guardrail: `recompute_cost ≤ 16 × 16` selector evaluations per recompute (F2); `submit()` ≤ 5 ms

---

## Acceptance Criteria

*From GDD `design/gdd/card-effects.md` (C7, F1 `hand_aura_delta`, F2, F3, Edge Cases "Buffs, auras and Silence"; AC-26, AC-27, AC-28, AC-29), scoped to this story:*

- [ ] **AC-26** GIVEN the friendly board `[row 26, row 26, vanilla 1/1, row 27]` left to right, WHEN auras are recomputed, THEN the 1/1 reads 5/3 (`+1 +1` attack from the two lords `+2` from adjacency = `+4`; health `+2`), each lord reads +1/+1 from the other only (row 27 is adjacent to neither), and row 27 reads +2/+2; one source never applies the same aura twice to one target.
- [ ] **AC-27** GIVEN row 26 buffing a damaged 2/2 (now 3/1 after 2 damage), WHEN row 26 is Silenced, THEN at the next recompute the 2/2 has `health ≤ 0` and dies in the following loop pass, with `silenced` → `auras_recomputed` → `minion_died` in the log (Silence on a recipient strips and re-applies — net no change).
- [ ] **AC-28** GIVEN a "+4/+4 until end of turn" on a 1/1 that then takes 4 damage, WHEN the owner's End step runs, THEN `enchantment_removed` then `minion_died` (F3: `damage_taken` unchanged, health `1 + 0 − 4`); a negative `buff` (`health: −2`) on a 3/3 with 2 damage kills the same way.
- [ ] **AC-29** GIVEN row 24 ("Your spells cost (1) less", `aura` with `zone: hand`) on board and a 3-cost spell in hand, WHEN `effective_cost` is read, THEN 2; with two copies of row 24 → 1; with a 1-cost spell and two copies → 0, never negative (F1 clamps once).

---

## Implementation Notes

*Derived from ADR-0007 Decision 1 and GDD C7, F2, F3:*

- `recompute_auras()`: the engine strips every `is_aura` enchantment (its side of the contract), then calls the resolver, which walks live aura sources in canonical source order — player board L→R, boss board, then treasure/passive auras hosted on the hero slot (story 013 adds the treasure host) — skips silenced sources, evaluates each aura's `targets` selector afresh (`not_self`, `adjacent`, `all_friendly_minions`, `hand` + filter), and calls `apply_enchantment(target, {attack_delta, health_delta, cost_delta, keywords_added, is_aura: true})` once per (source, target). Agree with match-rules whether the strip lives in the engine or the resolver asks for it through a primitive; record the choice on `/dev-story`.
- Stacking is additive across sources (F2); `max_health` then follows match-rules F6; the engine floors derived `attack` at 0.
- `zone: hand` auras and `passive_hand` are the `hand_aura_delta` term of F1 and are evaluated at every F1 read (match-rules asks `effective_cost`); the treasure "spells cost 1 less" is **not** an aura (story 014, a `modify_cost` fold).
- `buff` with `duration: until_end_of_turn` → `expires: end_of_turn`; removal is match-rules C4 End step 5 of the **recipient's controller** (an enemy recipient keeps it one turn longer — intended, cross-review C-16b). The resolver only sets `expires`.
- Auras never grant `battlecry` / `deathrattle`; only stats, `cost` and the `give_keyword` keyword set.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 013: `aura` with `keywords` from a treasure host (AC-32), transforms dropping enchantments
- Story 014: `modify_cost` folds (the third F1 term)
- match-rules: `recompute_auras()` call placement, F6 health arithmetic, End step 5 expiry, Silence's `damage_taken` rule

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/gameplay/effects/effect_resolver.gd` (`recompute_auras`, `hand_aura_delta`)
- `src/gameplay/effects/ops.gd` (`aura`, `buff` durations)
- `src/gameplay/effects/selectors.gd` (`adjacent`, `not_self`, `hand`)
- `tests/unit/card_effects/card_effects_auras_enchantments_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/card_effects/card_effects_auras_enchantments_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/card-effects/story-007-values-selectors-spell-damage.md` (selectors). Cross-epic: `production/epics/match-rules/` (C10 loop calling `recompute_auras()`, `apply_enchantment` with `is_aura`, F6, `effective_cost` F1, End step 5).
- Unlocks: `production/epics/card-effects/story-009-deathrattle-snapshot-counters.md` (AC-20), `story-013-transform-copy-keyword-aura.md`
