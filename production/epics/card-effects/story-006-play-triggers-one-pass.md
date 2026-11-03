# Story 006: Play triggers, `chosen` targeting and the one-pass contract

> **Epic**: Card Effects
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/card-effects.md`
**Requirement**: `TR-card-effects-002` (C5, C6: primitives only; one pass = one C10 step), `TR-card-effects-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Effect Resolver / Validator Boundary
**ADR Decision Summary**: `resolver.resolve(point, ctx)` receives `ctx.candidates` in engine order; the resolver decides who responds and runs play triggers now; one pass = condition → ops → selectors → primitives → exactly one `effect_resolved` via `engine.emit`, with the engine's `cause_seq`; the resolver never calls the death check or `recompute_auras()` between ops.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (by version; the APIs used predate 4.3 and are LOW)
**Engine Notes**: ADR-0007 Engine Compatibility — no post-cutoff APIs. Evaluators and op handlers are bound methods (lambdas capture by value, sourced).

**Control Manifest Rules (this layer)**:
- Required: `EffectResolver` mutates match state only through engine primitives, emits only through `engine.emit(type, payload)`; one effect pass = one C10 step; the resolver orders effects only within one entity
- Forbidden: never write match state directly from `src/gameplay/effects/**` (gate G7); never call the death check or `recompute_auras()` between ops; never re-sort candidates across entities
- Guardrail: `RulesEngine.submit()` ≤ 5 ms worst case (50-step Deathrattle chain, includes resolver passes)

---

## Acceptance Criteria

*From GDD `design/gdd/card-effects.md` (C2 play class, C3 `chosen`, C6.0, C6.4, C6.6, Interactions payload; AC-08, AC-09, AC-39), scoped to this story:*

- [ ] **AC-08** GIVEN row 10 ("Battlecry: Destroy a friendly minion. Draw 2") with no friendly minion, WHEN played, THEN mana is paid, the minion is on board, and no `effect_resolved` and no `card_drawn` is emitted (the whole effect never starts — Edge Cases).
- [ ] **AC-09** GIVEN row 10 with one friendly minion, WHEN played targeting it, THEN the log order is `card_played`, `minion_summoned`, exactly two `card_drawn`, `effect_resolved`, then `minion_died` (the death check runs after the pass — the sacrificed minion is *dying* while the draws happen), and `effect_resolved.ops` is `[destroy: applied, draw: applied ×2]`.
- [ ] **AC-39** GIVEN any `effect_resolved` in the fixture matches, WHEN inspected, THEN it carries `effect_id, host_id, host_kind, source_id, owner, trigger, depth, fizzled, ops[]` with one `ops` entry per op in the effect (`{op, targets, values, outcome}` with `outcome` from the closed set `applied | partial | no_target | board_full | burned | fatigue | empty_pool | skipped | already_has | no_such_trigger`), and its `cause_seq` equals that of the command event (`card_played` / `spell_cast` / `hero_power_used`) or the `trigger_resolved` that started it.

---

## Implementation Notes

*Derived from ADR-0007 Decisions 1, 5–6 and GDD C6:*

- `resolve(trigger_point, ctx)`: for a play point (`battlecry`, `on_cast`, `hero_power`) the single candidate is the host; look up `db.card(def_id).effects` (memo), keep effects whose trigger binds to the point, run each **now** in `effects[]` order. Event points are story 008 (queue, not run).
- One pass: evaluate `condition` once (false → `fizzled: condition_false`, no ops) → for each op in order: resolve its selector (op-level `targets` overrides effect-level) against the live board in canonical order → call the primitive per target → record `{op, targets, values, outcome}` → after the last op, `engine.emit(&"effect_resolved", payload)`. Ops are independent; `no_target` never stops the next op.
- `chosen` resolves to `ctx.target_id` (supplied by the command). A Battlecry whose `chosen` has no legal target: the engine already knows (`targeting_spec` + `legal_targets`, story 004) and does not call `resolve` for the Battlecry — or calls it and the resolver returns without emitting; either way nothing is emitted (AC-08). Agree the exact contract with match-rules' C6 step 3a implementer and record it in the story on `/dev-story`.
- `destroy` sets `pending_destroy` through the primitive; the sacrificed minion is still in play while `draw` runs; the engine's death check after the pass emits `minion_died` (AC-09 order).
- `depth` = length of the `cause_seq` chain back to the command (0 for the command's own play effect); the engine supplies the current `cause_seq` to `emit`.
- Ops land in `src/gameplay/effects/ops.gd` as a dispatch table `op name → bound method`; this story ships `damage`, `heal`, `buff`, `destroy`, `draw`, `armor`, `equip`, `summon`, `silence`, `freeze`, `give_keyword`, `mana` (the primitives match-rules exposes); `discover` / `choose_one` are story 010; `conditional` / `repeat` / counters / transforms are stories 007, 009, 013.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 007: value expressions beyond int literals, Spell Damage scaling (F1), random and area selectors, `conditional`, `repeat`
- Story 008–009: event triggers, queueing, snapshot, `once_per_turn`
- Story 010: `discover`, `choose_one`
- Story 004 owns `legal_targets`; match-rules owns the `NO_LEGAL_TARGET` rejection

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/gameplay/effects/effect_resolver.gd` (`resolve` for play points, `_run_pass`, `effect_resolved` payload)
- `src/gameplay/effects/ops.gd`
- `src/gameplay/effects/selectors.gd` (`self`, `chosen`, `owner_hero`, `enemy_hero`, `owner_weapon`, `enemy_weapon`, `owner`, `opponent`)
- `tests/unit/card_effects/card_effects_play_triggers_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/card_effects/card_effects_play_triggers_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/card-effects/story-001-dsl-spike-five-hardest.md` (PROCEED verdict), `production/epics/card-effects/story-002-runtime-binding-config.md`, `production/epics/card-effects/story-004-validator-step-bound-targeting.md`, `production/epics/card-effects/story-005-fixture-set-database-injection.md` (fixture). Cross-epic: `production/epics/match-rules/` (command handlers firing `battlecry` / `on_cast` / `hero_power`, the primitives, the C10 loop, `emit` with `cause_seq`).
- Unlocks: `production/epics/card-effects/story-007-values-selectors-spell-damage.md`, `story-008-event-observers-queueing.md`, `story-010-discover-choose-one.md`, `story-011-hero-powers.md`
