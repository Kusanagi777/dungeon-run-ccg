# Story 007: Value expressions, conditions, Spell Damage (F1) and area / random selectors (F5)

> **Epic**: Card Effects
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/card-effects.md`
**Requirement**: `TR-card-effects-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Effect Resolver / Validator Boundary
**ADR Decision Summary**: The resolver asks the engine for draws — `engine.rng_match()` returns the injected `RngStream` and the resolver calls `randi_range` on it directly, in resolution order, with the counts F4/F5 define; nothing under `src/gameplay/effects/**` names `RandomNumberGenerator` or a global RNG function.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (by version; the APIs used predate 4.3 and are LOW)
**Engine Notes**: ADR-0007 Engine Compatibility — no post-cutoff APIs. Integer value expressions evaluated recursively over Dictionaries.

**Control Manifest Rules (this layer)**:
- Required: draws only through `engine.rng_match()`; one effect pass = one C10 step
- Forbidden: `RandomNumberGenerator` under `src/gameplay/effects/**` (gate G7); never call the death check between ops (a `repeat` iteration that kills a minion leaves it dying, not removed)
- Guardrail: a 16-target op with value expressions resolves under 2 ms (asserted in story 016)

---

## Acceptance Criteria

*From GDD `design/gdd/card-effects.md` (C3 selectors and filter grammar, C4, C5 `conditional` / `repeat`, F1, F5; AC-13, AC-14, AC-23, AC-24), scoped to this story:*

- [ ] **AC-13** GIVEN row 44 (hero power "Deal 1") and two Spell Damage +1 minions, WHEN used on the enemy hero, THEN `damage_dealt.amount == 1`; GIVEN row 18 (spell "Deal 3") cast instead, THEN `amount == 5` and `effect_resolved.ops[0].values.requested == 5` (F1: `auto` scales iff the host is a `spell`; re-read per op).
- [ ] **AC-14** GIVEN row 19 ("Deal 2 to all enemies") with +1 Spell Damage and an enemy board of 3 plus hero, WHEN cast, THEN four `damage_dealt{amount: 3}` in canonical order (board left to right, then hero).
- [ ] **AC-23** GIVEN row 22 (turn_end, `condition: owner.hand_size >= 5`, `random_enemy_character`) with 4 cards in hand, WHEN the owner's End step runs, THEN `effect_resolved{fizzled: condition_false}` and no damage; with 5 cards, THEN one `damage_dealt{amount: 3}` on a random enemy character chosen with exactly one stream draw (`TestRngStream.draws`).
- [ ] **AC-24** GIVEN row 34 (`repeat` ×2 of `damage` on `random_enemy_minion`) and a single enemy minion at 1 health, WHEN the Start step runs, THEN `effect_resolved.ops` has two entries: the first `applied` (minion dies), the second `no_target` (the dying minion is no longer selectable, C6.0); the hero is never hit; and a value expression yielding a negative `damage` amount is clamped to 0 with `values.clamped_from` logged.

---

## Implementation Notes

*Derived from ADR-0007 Decision 7 and GDD C3–C5, F1, F5:*

- `values.gd`: `eval(expr, ctx) -> int` over `int | {ref} | {count} | {add} | {sub} | {mul} | {min} | {max} | {clamp}`; the ref path set is C4's closed list (the validator already rejected unknown paths; the resolver may `assert` in debug). `source.*` / `counter.*` read live while the source is the same `entity_id` in play, else the snapshot (story 009 supplies the snapshot; this story reads live).
- Conditions: `cmp`, `exists`, `test`, `holding`, `is_owner_turn`, `all`, `any`, `not`. Per-turn tallies (`cards_played_this_turn`, …) are `EffectRuntime.per_turn[side]` kept by the resolver from the trigger points it already sees and reset at that side's Start step (C6.8).
- Selectors (`selectors.gd`): canonical order = player board L→R, boss board L→R, player hero, boss hero, weapons, hand/deck positions; never yield a dying entity (`health ≤ 0` or `pending_destroy`); filter predicates per C3 (AND). `random_*`: F5 — `k = min(n, |cands|)`, `k` draws of `randi_range(0, |cands| − 1)` with removal; zero draws for an empty list. `adjacent` / `left_neighbour` / `right_neighbour` with `of: self | target | trigger_subject`.
- F1: `requested = amount + (scales ? spell_damage(owner) : 0)`; `scales = op.spell_damage == true or (op.spell_damage == auto and host.type == spell)`; `SPELL_DAMAGE_DEFAULT` from config decides what `auto` means when the field is absent. `spell_damage(owner)` is match-rules F7 — read it through the engine, do not recompute.
- `repeat`: each iteration re-resolves selectors against the live board; `conditional`: the branch not taken is logged `skipped`; both record one `ops` entry per inner op executed (AC-24 shows two entries for the two iterations).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 008: queueing `turn_end` / `turn_start` observers (this story's AC-23/24 run through story 008's queue — sequence the two stories together or land 008 first)
- Story 009: raise-time snapshot for `source.*` / `counter.*` refs
- Story 012: `aura` selectors and recompute
- Story 014: `modify_damage` folds that also change `amount`

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/gameplay/effects/values.gd`
- `src/gameplay/effects/selectors.gd` (all C3 selectors and predicates)
- `src/gameplay/effects/ops.gd` (`conditional`, `repeat`, Spell Damage in `damage`)
- `src/gameplay/effects/effect_runtime.gd` (`per_turn` tallies)
- `tests/unit/card_effects/card_effects_values_selectors_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/card_effects/card_effects_values_selectors_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/card-effects/story-006-play-triggers-one-pass.md`; AC-23 and AC-24 also need `production/epics/card-effects/story-008-event-observers-queueing.md` (turn triggers are queued event triggers). Cross-epic: `production/epics/match-rules/` (F7 `spell_damage`, `turn_start` / `turn_end` trigger points), `production/epics/rng-event-log/` (the `match_<floor>` stream).
- Unlocks: `production/epics/card-effects/story-009-deathrattle-snapshot-counters.md`, `story-011-hero-powers.md`, `story-012-auras-enchantments.md`
