# Story 014: Value triggers — `apply_value_hook` folds for cost, damage and max attacks

> **Epic**: Card Effects
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/card-effects.md`
**Requirement**: `TR-card-effects-004` (C9: value hooks as folds)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Owner-scoped hook registry (most direct); ADR-0007: Effect Resolver / Validator Boundary (`apply_value_hook` is the resolver's bound method registered at `bind`)
**ADR Decision Summary**: Value entries fold in installation order — entry *n*'s output is entry *n+1*'s input (`delta` adds, `set` replaces, `mul` multiplies); the fold mutates and allocates nothing; the **engine clamps exactly once after the whole fold**; `side` is passed on every invocation and the resolver evaluates the entry's `scope` relative to `entry.side`; a `condition` on a value trigger is re-evaluated on every fold call.
**ADR Version**: 2026-11-03 (ADR-0005); 2026-11-03 (ADR-0007)

**Engine**: Godot 4.7.2 | **Risk**: HIGH (language, by version); LOW for the APIs (`RefCounted`, `Dictionary`, `Array`, `StringName`, `Callable`)
**Engine Notes**: ADR-0005 Engine Compatibility — lambdas capture locals by value (sourced): the evaluator receives the entry and context as arguments and never closes over mutable locals; an override of a typed method returns explicitly (4.7). No `NOT SOURCEABLE` item (no sort; installation order is array order).

**Control Manifest Rules (this layer)**:
- Required: value folds — entry *n*'s output is entry *n+1*'s input; the fold mutates and allocates nothing; the engine clamps exactly once after the whole fold with bounds from `config("match_rules")`; `side` is passed on every invocation; evaluator Callables take everything they need as arguments
- Forbidden: never clamp inside the fold or inside a `modify_value` op (`1 − 1 − 1 → 0`, not `0 → 0`); never allocate in the fold; never special-case "player only" in engine code — scope is data; never sort hook entries or add a `priority`
- Guardrail: 12-entry fold < 0.05 ms; three treasures add < 2 ms per match; ≤ 12 entries per match

---

## Acceptance Criteria

*From GDD `design/gdd/card-effects.md` (C2 value class and scope keys, C5 `modify_value`, C9, Edge Cases "Hooks and passives"; AC-33, AC-34, AC-35), scoped to this story:*

- [ ] **AC-33** GIVEN row 36 (passive "+1 cost to enemy minions", `modify_cost` scope `card.side: enemy, type: minion`) and a row 39-style treasure "minions cost 1 less" installed, WHEN the player reads a 3-cost minion's `effective_cost`, THEN 3 (fold: treasure first −1, passive +1); a 0-cost minion reads 0 (clamped once by the engine, never inside the fold); row 39 itself (`scope.card.kind: hero_power`, `set: 0`) makes the hero power cost 0 and it is still once per turn.
- [ ] **AC-34** GIVEN row 40 (treasure "spells deal 1 more", `modify_damage` scope `source.type: spell`), WHEN row 18 is cast for 3 with 0 Spell Damage, THEN `damage_dealt.amount == 4` and `effect_resolved` carries `hook_delta`; WHEN row 44 (hero power) is used, THEN 1 (scope `type: spell` does not match a hero power).
- [ ] **AC-35** GIVEN row 43 (treasure "hero attacks twice", `modify_max_attacks` scope `who: owner_hero`, `set: 2`), WHEN the hero with a weapon attacks twice, THEN both accepted and the third is `CANNOT_ATTACK`; a `condition` on a value trigger (`owner.cards_played_this_turn == 0`, Treasures R-2) is re-evaluated on each fold call and leaves `context.value` unchanged when false.

---

## Implementation Notes

*Derived from ADR-0005 Decisions 3–4 and ADR-0007 Key Interfaces:*

- `func apply_value_hook(entry: HookEntry, side: StringName, value: int, ctx: Dictionary) -> int`: if `entry.effect.trigger` is not the point's value trigger → return `value`; evaluate `scope` relative to `entry.side` (`card: filter` — `card` without `kind` matches card instances only, `kind: hero_power` the hero power only, `kind: any` both; `source` / `target` filters for damage and heal; `who` for max attacks; `side` for starting hand); evaluate `condition` with `context.value = value`; false → return `value`; apply the single `modify_value` op: `delta` adds, `set` replaces, `mul` multiplies. Return the int. **No allocation**: no `duplicate()`, no arrays built; reuse `ctx`.
- The resolver never clamps here. The engine's call sites (ADR-0005 Key Interfaces) clamp once: cost ≥ 0, damage ≥ 0, heal ≥ 0, hand ∈ [0, HAND_SIZE], attacks ∈ [0, MAX_ATTACKS_CAP].
- `hook_delta` on `effect_resolved` (treasures Edge Cases): when a fold changed `requested`, the pass's `values` records `{requested, hook_delta, dealt}` so the feed can name the treasure.
- `modify_starting_hand_size` and `modify_heal` share the same code path; they are covered by match-rules' and treasures' tests, not by a GDD AC here — keep them in the dispatch so the catalogue matches `HookRegistry.VALUE_POINTS`.
- Match-tier state for a value hook (`once_per_turn` is meaningless on a fold; `per_turn` tallies are read-only here) lives in `EffectRuntime` keyed by treasure id; run-tier `entry.state` is read-only.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 015: trigger hooks (`run_hook_effect`) and hero-slot observers
- Story 012: hand auras (the second F1 term)
- match-rules: `HookRegistry.fold`, the clamp, `effective_cost` / F2 damage call sites; `production/epics/treasures/`: `installers_for`, magnitudes, `W_TR_POWER`

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/gameplay/effects/effect_resolver.gd` (`apply_value_hook`)
- `src/gameplay/effects/scope.gd` (value-trigger scope keys)
- `src/gameplay/effects/ops.gd` (`modify_value`)
- `tests/unit/card_effects/card_effects_value_hooks_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/card_effects/card_effects_value_hooks_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/card-effects/story-002-runtime-binding-config.md` (evaluators registered at `bind`), `production/epics/card-effects/story-008-event-observers-queueing.md` (`scope.gd`). Cross-epic: `production/epics/match-rules/` (`HookRegistry.fold`, the five value call sites and their clamps), `production/epics/treasures/` (`HookInstaller`, `passive_installer`).
- Unlocks: `production/epics/treasures/` value-hook treasures; `production/epics/card-effects/story-015-hook-trigger-steps-hero-slot-observers.md`
