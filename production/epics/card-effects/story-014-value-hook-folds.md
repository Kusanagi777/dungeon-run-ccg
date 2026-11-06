# Story 014: Value triggers — `apply_value_hook` folds for cost, damage and max attacks

> **Epic**: Card Effects
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-04
> **Last Updated**: 2026-11-04 (implemented, sprint 5 L5 W2)

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

- [x] **AC-33** GIVEN row 36 (passive "+1 cost to enemy minions", `modify_cost` scope `card.side: enemy, type: minion`) and a row 39-style treasure "minions cost 1 less" installed, WHEN the player reads a 3-cost minion's `effective_cost`, THEN 3 (fold: treasure first −1, passive +1); a 0-cost minion reads 0 (clamped once by the engine, never inside the fold); row 39 itself (`scope.card.kind: hero_power`, `set: 0`) makes the hero power cost 0 and it is still once per turn.
- [x] **AC-34** GIVEN row 40 (treasure "spells deal 1 more", `modify_damage` scope `source.type: spell`), WHEN row 18 is cast for 3 with 0 Spell Damage, THEN `damage_dealt.dealt == 4` and `effect_resolved` carries `hook_delta`; WHEN row 44 (hero power) is used, THEN 1 (scope `type: spell` does not match a hero power).
- [x] **AC-35** GIVEN row 43 (treasure "hero attacks twice", `modify_max_attacks` scope `who: owner_hero`, `set: 2`), WHEN the hero with a weapon attacks twice, THEN both accepted and the third is `CANNOT_ATTACK`; a `condition` on a value trigger (`owner.cards_played_this_turn == 0`, Treasures R-2) is re-evaluated on each fold call and leaves `context.value` unchanged when false.

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

- `src/gameplay/effects/effect_resolver.gd` (`apply_value_hook`, `_fold_run`, `_fold_view`)
- `src/gameplay/effects/scope.gd` (`matches_value`)
- `src/gameplay/effects/ops.gd` (`modify_value`, `hook_delta` on `damage` / `heal`)
- `tests/unit/card_effects/card_effects_value_hooks_test.gd`
- `tests/unit/card_effects/card_effects_runtime_binding_test.gd` (the story-002 pass-through pin, see Completion Notes)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/card_effects/card_effects_value_hooks_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] Created: 40 tests

---

## Dependencies

- Depends on: `production/epics/card-effects/story-002-runtime-binding-config.md` (evaluators registered at `bind`), `production/epics/card-effects/story-008-event-observers-queueing.md` (`scope.gd`). Cross-epic: `production/epics/match-rules/` (`HookRegistry.fold`, the five value call sites and their clamps), `production/epics/treasures/` (`HookInstaller`, `passive_installer`).
- Unlocks: `production/epics/treasures/` value-hook treasures; `production/epics/card-effects/story-015-hook-trigger-steps-hero-slot-observers.md`

---

## Readiness (2026-11-04, by hand, sprint 5 L5 W2)

**Verdict: READY**, after three gaps were resolved from the docs. Workflow `full` (card-effects override).

- Passing: requirement traced (C2, C5, C9, AC-33/34/35); ADR-0005 and ADR-0007 Accepted; TR-card-effects-004 active; stories 002 and 008 Complete; `HookInstaller` and `Treasures.passive_installer` are on trunk, so the yaml blocker has cleared; 3 criteria; Logic evidence path named.
- **Manifest Version (was NEEDS WORK at `full`)**: the story read 2026-11-03, the manifest 2026-11-04. The value-fold rows are unchanged. Set to 2026-11-04.
- **AC-34 `damage_dealt.amount`**: corrected to `dealt` (the engine's field; card-effects AC-34; QA plan "GDD and story contradictions").
- **`hook_delta` home**: "in no event or code today" (QA plan). ADR-0005 Events and the story name `effect_resolved`, and treasures AC-27 names `effect_resolved.values`, so it goes in `ops[i].values`.
- `HookRegistry.install` drops `turn_start`, `turn_end` and `on_damage_taken`. Every value trigger maps to itself, so this story does not need that mapping: left to story 015.
- QL-STORY-READY skipped — Lean mode.

---

## Completion Notes

**Completed**: 2026-11-04
**Started / ended (UTC)**: 00:43:24 / 01:03:32 (2026-11-05 UTC)
**Criteria**: 3/3 passing, all by automated test (none deferred)
**Test Evidence**: `tests/unit/card_effects/card_effects_value_hooks_test.gd` (40)
**Reviewed by**: independent `/code-review`, 2026-11-05 (`production/reviews/2026-11-05/code-review-s5-w2-effects-treasures.md`, full scope, `d9932c7`): **APPROVED WITH SUGGESTIONS**, 0 required. Q2 is decided by DD-X29 (`26f7f47`). Open: Q1 (an absent `side` in a value filter), S2, P1, the ADR-0005 drift.
**Run result**: N/A — a Logic story changes nothing visible; the full suite and `godot --headless --quit-after 5` are the evidence.

**Traceability**

| Criterion | Covered by |
|-----------|------------|
| AC-33 | `test_ac33_*`, `test_card_scope_*`, `test_scope_reads_relative_to_the_entry_side`, `test_the_folded_cost_is_what_is_paid`, `test_a_clone_folds_through_its_own_resolver_to_the_same_cost` |
| AC-34 | `test_ac34_*`, `test_no_hook_delta_when_no_fold_changed_the_value`, `test_hook_delta_is_recorded_per_target_of_an_area_op`, `test_a_target_filter_changes_only_the_targets_it_matches`, `test_the_source_filter_side_is_relative_to_the_entry_side`, `test_a_minion_source_filter_matches_a_combat_hit` |
| AC-35 | `test_ac35_*`, `test_who_*` |
| QA plan edge items | `mul`, `set` order, disagreeing hooks, `modify_heal` through the real resolver, fatigue (source and target filters), `context.value`, starting hand |

**Seen failing first.** Against the pass-through `apply_value_hook`, 28 of the first 40 tests failed (4 of them first on a test bug, a missing play position, fixed before the code landed). The rest guard behaviour a pass-through already shows, so each was seen failing against a deliberate mutant, restored after the run (`git diff` clean of them): clamp inside `modify_value`, scope always true, a non-value trigger matching, `hook_delta` always written, only negative deltas applied, scope read from the fold's side, a null source matching a filter, the hero power matching a filter without `kind`, the condition ignored, and the fold doing nothing. Every mutant was killed. `test_ac35_without_the_treasure` was dropped: it pinned engine behaviour no change here could break, so nothing in this lane could show it failing.

**Deviations**

- **`damage_dealt.amount` → `dealt`** (AC-34): the engine's field, as the GDD's AC-34 has it.
- **`hook_delta` is per target.** `values.hook_delta` and `values.dealt` (`values.restored` for `heal`) are arrays parallel to `targets`, because a `target:` scope can differ per target and treasures AC-27 asks for it "per target". The story's sketch `{requested, hook_delta, dealt}` reads as scalars. Neither key exists when no fold changed anything, so a log with no hooks keeps its shape. Treasures 012's AC-27 reads `values.hook_delta[i]`.
- **`hook_delta` is read by folding once ahead of the primitive** in `ops.gd`, not captured from the engine's fold, so `apply_value_hook` stays free of side effects and `rules_engine.gd` is untouched. Folds are pure, so the two reads agree. The value is the raw net, before the clamp (treasures Edge Cases: `−2`).
- **`test_base_resolver_evaluators_are_identity_until_stories_014_and_015`** pinned the placeholder this story replaces and said so in its name. It is now `test_base_resolver_value_hook_outside_its_scope_returns_its_input`.
- **An absent `who` on `modify_max_attacks` reads `any`.** C2 gives no default. Absent filters elsewhere in value scope mean no restriction, and no shipped or planned record omits it.

**Open, not settled here**

- **DD-X26 gap, reported to the orchestrator (2026-11-04).** A non-aura `modify_cost` hook never reaches `MatchViewState.hand[].effective_cost`. Measured: with a Banner-shaped hook, the engine's cost for a held card went 2 → 3 across a `play_card`, and a draw and that play logged no `auras_recomputed` at all. `_recompute_auras` diffs `effective_cost` before and after one recompute, and a hook gives the same answer on both sides. An entry does carry the fold when an aura moves the card (`test_an_auras_recomputed_hand_entry_carries_the_folded_cost`). The docs do not settle the mechanism: DD-X26 covers aura changes only; treasures UI Requirements and `hand.md` have the UI read `hand()` / state; match-ui U2 forbids polling a query for numbers; story MUI-006 shows the printed cost until an entry sets it. Treasures rates the discount display **Must**. Any engine fix is `rules_engine.gd`, MR-019's alone this wave. No AC of this story depends on it. The hero-power button has the same gap, and no event carries its cost at all.
- **`hook_delta` on the F1 cost event** (treasures AC-8 and Edge Cases, "the F1 event"): no such event is defined and `card_played` / `mana_spent` are `rules_engine.gd`'s. Treasures 005 records where its AC-8 lands.
- **A source that has left play matches no `source` filter** (a queued Deathrattle's damage): the fold's `ctx` has no snapshot and C2 does not say. No v1 record is affected: the only `source` filter is Focusing Prism's `type: spell`.
