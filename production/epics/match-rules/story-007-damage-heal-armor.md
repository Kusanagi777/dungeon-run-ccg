# Story 007: Damage, healing and armour pipeline

> **Epic**: Match Rules
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-03

## Context

**GDD**: `design/gdd/match-rules.md` (C9 Damage, healing and armour; F2 Damage application; Interactions `modify_damage`, `modify_heal`, `on_hero_damaged`; C12 Divine Shield, Poisonous, Lifesteal rows)
**Requirement**: `TR-match-rules-005` (`apply_damage`, `apply_heal`, `apply_armor`), `TR-match-rules-006` (fold-then-clamp on `modify_damage` / `modify_heal`; `on_hero_damaged`)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Owner-scoped hook registry (Decision 4 — the engine clamps once after the fold; Key Interfaces engine call sites); also ADR-0007 (primitives emit one event; `on_damage` is a trigger point the engine fires)
**ADR Decision Summary**: Value entries fold — entry *n*'s output is entry *n+1*'s input — and **the engine clamps once after the whole fold** with the floor-0 rules of F1/F2: `dmg = maxi(0, hooks.fold(&"modify_damage", source_side, requested, {source, target}))`, `heal = maxi(0, hooks.fold(&"modify_heal", …))`. A clamp between entries is a defect.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: HIGH by version; APIs used predate 4.3. The fold evaluator Callables receive entry, side, value and ctx as arguments (lambdas capture by value — sourced); nothing is allocated per invocation.

F2 is the one pipeline every point of damage passes through — attack, spell, fatigue, hero power, trigger — and the log explains every number it produces: `damage_dealt {source, target, requested, prevented, armor_absorbed, dealt, health_after}`. Divine Shield, armour, Poisonous and Lifesteal are resolved inside the same step, before any death check, which is why a Poisonous attacker killed by its defender still poisons it (Edge Cases).

**Control Manifest Rules (this layer)**:
- Required: value folds — the fold mutates and allocates nothing; the engine clamps exactly once after the whole fold with bounds from `config("match_rules")` (≥ 0 for cost/damage/heal) (ADR-0005); hook catalogue trigger points include `on_hero_damaged`; value points `modify_damage`, `modify_heal` (ADR-0005); `side` is passed on every invocation (ADR-0005)
- Forbidden: never clamp inside the fold or inside a `modify_value` op (`1 − 1 − 1 → 0`, not `0 → 0`) (ADR-0005); never allocate in the fold (ADR-0005); never call the death check or `recompute_auras()` between ops (ADR-0007)
- Guardrail: hook fold — 12-entry fold < 0.05 ms (ADR-0005); `submit()` ≤ 5 ms worst case (ADR-0007)

---

## Acceptance Criteria

*From GDD `design/gdd/match-rules.md`, scoped to this story:*

- [x] AC-23 **GIVEN** a boss hero with 2 armour, **WHEN** it takes 5 from a Lifesteal source, **THEN** `armor == 0`, health fell by 3, and the player's hero healed 5 (F2: `armor_absorbed = 2`, `to_health = 3`, `dealt = 5`); the events are `damage_dealt{requested 5, prevented 0, armor_absorbed 2, dealt 5, health_after}`, `armor_lost{amount 2}`, `healed{amount 5}`, then `on_hero_damaged` hook invocations with `amount_dealt = 5`; `stats.damage_dealt_by_card` and `stats.damage_taken` moved by `dealt`.
- [x] AC-44 **GIVEN** a `modify_heal` hook returning −3, **WHEN** a 2-point heal resolves, **THEN** `healed {amount: 0}` is emitted (never damage — the engine floors the fold once at 0) and `damage_taken` is unchanged; **AND GIVEN** a `modify_damage` chain of `delta −1, delta −1, delta −1` on a requested 1, **THEN** the fold result is −2 and the engine's single clamp makes `amount = 0` (observed by the evaluator inputs: `1, 0, −1`, never clamped between entries).
- [x] C9 Divine Shield **GIVEN** a Divine Shield minion, **WHEN** `apply_damage(minion, 4, source)` runs, **THEN** `divine_shield_popped` is emitted, `dealt == 0`, `prevented == 4`, no `damage_taken` change, no `on_damage` trigger, no Poisonous mark and no Lifesteal heal; **AND WHEN** a 0-damage hit arrives, **THEN** the shield is **not** popped and no event beyond `damage_dealt{dealt 0}` is emitted.
- [x] C9 Poisonous and healing **GIVEN** a Poisonous source, **WHEN** it deals 1 to a 5-health minion and 1 to a hero, **THEN** the minion has `pending_destroy == true` (dies in the next death check regardless of health) and the hero does not; **AND GIVEN** a hero at `damage_taken 3`, **WHEN** `apply_heal(hero, 10)` resolves, **THEN** `restored == 3`, `damage_taken == 0`, `healed{amount: 3}` (health never exceeds `max_health`; a full-health target heals 0 and still emits `healed`); `apply_armor(side, 4)` → `armor += 4`, uncapped, `armor_gained`.

---

## Implementation Notes

*Derived from ADR-0005 Decision 4 / Key Interfaces, ADR-0007 Decision 5–6 and GDD C9 / F2:*

- `apply_damage(target, requested, source)` is F2 evaluated in one step, in this order: `amount = maxi(0, hooks.fold(&"modify_damage", source_side, requested, ctx))` (the engine's one clamp) → if `target.divine_shield and amount > 0`: `prevented = amount; amount = 0; remove the shield keyword; emit divine_shield_popped` → `armor_absorbed = min(target.armor, amount)` (heroes only; 0 for minions), `target.armor -= armor_absorbed`, emit `armor_lost` when > 0 → `to_health = amount − armor_absorbed`, `target.damage_taken += to_health` → `dealt = armor_absorbed + to_health` → emit `damage_dealt{source, target, requested, prevented, armor_absorbed, dealt, health_after}` (`health_after` may be negative) → if `source.poisonous and target is minion and dealt > 0`: `pending_destroy = true` (heroes immune) → if `source.lifesteal and dealt > 0`: `apply_heal(source.controller.hero, dealt, source)` (armour absorbed counts as dealt; Lifesteal on a weapon applies to the hero's attacks) → if target is a hero and `dealt > 0`: `hooks.run_triggers(&"on_hero_damaged", target.controller, {amount_dealt, source})` → raise (queue, story 009) `on_damage(target, dealt, source)` triggers only when `dealt > 0`. Stats: `source` controller's `stats.damage_dealt_by_card[def_id] += dealt`, target controller's `stats.damage_taken += dealt`. `source = FATIGUE` is a sentinel with no keywords and no stats attribution beyond `damage_taken`.
- `apply_heal(target, amount, source)`: `amount = maxi(0, hooks.fold(&"modify_heal", source_side, amount, ctx))` → `restored = min(amount, damage_taken)`, `damage_taken −= restored` → emit `healed{source, target, requested, amount: restored}` **always** (a 0 heal still emits; `on_heal` observers see it) → raise `on_heal` triggers. No `healed` event is produced by Lifesteal when `dealt == 0` because `apply_heal` is not called then (Edge Cases).
- `apply_armor(side, amount)`: `armor += amount`, uncapped, `armor_gained`.
- `has_divine_shield` / `poisonous` / `lifesteal` are keyword reads (`MatchFactory.has_keyword` semantics — definition keywords plus `keywords_added` from enchantments); a weapon's keywords count for the hero attacking with it (story 013 passes the weapon as part of `source`).
- `ctx` for the folds is a reused Dictionary `{source, target}`; never built fresh per call in a hot path if avoidable — the fold itself must not allocate.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 009: the death check that consumes `pending_destroy` and `health ≤ 0`; queued `on_damage` resolution
- Story 011: the `modify_cost` fold and its clamp
- Story 013 / 014: combat's call into `apply_damage` (simultaneous damage, weapon durability, shields in combat)
- Story 015: Silence's F6 clamp on `damage_taken`

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/gameplay/match/rules_engine.gd` — `apply_damage` complete (F2 in one step: `modify_damage` fold then one `maxi(0, …)` clamp, Divine Shield pop, armour with `armor_lost`, `damage_dealt`, stats, Poisonous mark, Lifesteal heal, `on_hero_damaged` hooks, `on_damage` raise); `apply_heal` complete (`modify_heal` fold floored once, `on_heal` raise); reused fold contexts `_damage_ctx` / `_heal_ctx`; `_source_has`; `_record_damage_stats` takes the resolved sides
- `tests/helpers/test_effect_resolver.gd` — `hook_calls` entries carry `point` and a `ctx` copy; `fold_inputs(point)` and `run_contexts(point)` helpers
- `tests/unit/match_rules/match_rules_damage_test.gd` — 13 test functions

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/match_rules/match_rules_damage_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later). `qa.level: standard` — BLOCKING.

**Status**: [x] Created and passing (13 test functions)

---

## Dependencies

- Depends on: `production/epics/match-rules/story-006-primitives-draw-burn-fatigue.md`, `production/epics/match-rules/story-002-hook-registry.md`
- Unlocks: `production/epics/match-rules/story-008-win-loss-concede-result.md`

## Completion Notes
**Completed**: 2026-11-03 (started 22:40:09 UTC, ended 22:44:17 UTC)
**Criteria**: 4/4 passing — AC-23 (`test_lifesteal_hit_on_an_armoured_hero_absorbs_heals_dealt_and_fires_on_hero_damaged`, `test_lifesteal_on_a_weapon_heals_the_hero_holding_it`), AC-44 (`test_modify_heal_below_zero_heals_zero_and_never_damages`, `test_modify_damage_chain_is_folded_unclamped_then_clamped_once`, `test_modify_damage_may_raise_the_amount_above_the_request`, `test_boss_modify_damage_hook_does_not_fold_player_sourced_damage`), C9 Divine Shield (`test_divine_shield_prevents_the_hit_and_blocks_poison_lifesteal_and_on_damage`, `test_zero_damage_does_not_pop_divine_shield`), C9 Poisonous and healing (`test_poisonous_marks_a_damaged_minion_but_not_a_hero`, `test_damage_dealt_raises_on_damage_and_a_zero_hit_does_not`, `test_on_hero_damaged_does_not_run_for_a_minion_or_a_zero_hit`, `test_heal_restores_at_most_damage_taken_and_a_full_target_still_emits`, `test_apply_armor_is_uncapped`). Watched fail: 10 of 13 against the story-006 engine (the three that passed pin behaviour 006 already had — 0 damage pops nothing, no hook on a minion, armour uncapped); mutant clamping inside `HookRegistry.fold` (`maxi(0, …)` per entry) fails the AC-44 chain test (inputs `1, 0, 0`).
**Deviations** (advisory):
- Event order is the mutation order of the Implementation Notes — `armor_lost`, then `damage_dealt`, then `healed`, then the `on_hero_damaged` hooks — where AC-23 lists `damage_dealt` before `armor_lost`; each event follows its own mutation (ADR-0003).
- `divine_shield_popped` payload is `{entity_id, prevented}`; `armor_lost` is `{side, entity_id, amount, armor}` (C15 names the events, not their payloads).
- Fold side for a source with no side (`SOURCE_FATIGUE`, null, a source no longer in any zone) is the target's controller. Open question for Treasures: should a player's friendly `modify_damage` hook apply to fatigue the player takes?
- A spell's Lifesteal/Poisonous reads its card instance's definition keywords through `db.card()`; a spell in the `resolving` zone is in no zone list yet (story 010 decides where a cast card lives).
- `on_damage` / `on_heal` triggers are raised into the engine's queue Q; their resolution is the C10 loop (story 009).
**Test Evidence**: `tests/unit/match_rules/match_rules_damage_test.gd` (13 tests); full suite 736 test cases, 0 failures, exit 0, 36 SCRIPT ERROR lines (baseline intentional negatives); smoke exit 0, no SCRIPT ERROR; parse check exit 0.
**Run result**: N/A — the story changes the headless damage pipeline and event log only; no scene, node or screen renders it (Match UI is a later epic).
**Reviewed by**: self, no independent review (LP-CODE-REVIEW skipped — Lean mode; QL-TEST-COVERAGE skipped — Lean mode)
