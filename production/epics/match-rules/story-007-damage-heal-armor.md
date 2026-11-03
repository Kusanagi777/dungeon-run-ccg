# Story 007: Damage, healing and armour pipeline

> **Epic**: Match Rules
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

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

- [ ] AC-23 **GIVEN** a boss hero with 2 armour, **WHEN** it takes 5 from a Lifesteal source, **THEN** `armor == 0`, health fell by 3, and the player's hero healed 5 (F2: `armor_absorbed = 2`, `to_health = 3`, `dealt = 5`); the events are `damage_dealt{requested 5, prevented 0, armor_absorbed 2, dealt 5, health_after}`, `armor_lost{amount 2}`, `healed{amount 5}`, then `on_hero_damaged` hook invocations with `amount_dealt = 5`; `stats.damage_dealt_by_card` and `stats.damage_taken` moved by `dealt`.
- [ ] AC-44 **GIVEN** a `modify_heal` hook returning −3, **WHEN** a 2-point heal resolves, **THEN** `healed {amount: 0}` is emitted (never damage — the engine floors the fold once at 0) and `damage_taken` is unchanged; **AND GIVEN** a `modify_damage` chain of `delta −1, delta −1, delta −1` on a requested 1, **THEN** the fold result is −2 and the engine's single clamp makes `amount = 0` (observed by the evaluator inputs: `1, 0, −1`, never clamped between entries).
- [ ] C9 Divine Shield **GIVEN** a Divine Shield minion, **WHEN** `apply_damage(minion, 4, source)` runs, **THEN** `divine_shield_popped` is emitted, `dealt == 0`, `prevented == 4`, no `damage_taken` change, no `on_damage` trigger, no Poisonous mark and no Lifesteal heal; **AND WHEN** a 0-damage hit arrives, **THEN** the shield is **not** popped and no event beyond `damage_dealt{dealt 0}` is emitted.
- [ ] C9 Poisonous and healing **GIVEN** a Poisonous source, **WHEN** it deals 1 to a 5-health minion and 1 to a hero, **THEN** the minion has `pending_destroy == true` (dies in the next death check regardless of health) and the hero does not; **AND GIVEN** a hero at `damage_taken 3`, **WHEN** `apply_heal(hero, 10)` resolves, **THEN** `restored == 3`, `damage_taken == 0`, `healed{amount: 3}` (health never exceeds `max_health`; a full-health target heals 0 and still emits `healed`); `apply_armor(side, 4)` → `armor += 4`, uncapped, `armor_gained`.

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

- `src/gameplay/match/rules_engine.gd` (`apply_damage`, `apply_heal`, `apply_armor` complete; fold call sites with the single clamp)
- `tests/helpers/test_effect_resolver.gd` (record fold inputs per entry for the no-clamp-inside assertion)
- `tests/unit/match_rules/match_rules_damage_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/match_rules/match_rules_damage_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later). `qa.level: standard` — BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/match-rules/story-006-primitives-draw-burn-fatigue.md`, `production/epics/match-rules/story-002-hook-registry.md`
- Unlocks: `production/epics/match-rules/story-008-win-loss-concede-result.md`
