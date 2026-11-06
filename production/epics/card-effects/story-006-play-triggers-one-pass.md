# Story 006: Play triggers, `chosen` targeting and the one-pass contract

> **Epic**: Card Effects
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-04

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

- [x] **AC-08** GIVEN row 10 ("Battlecry: Destroy a friendly minion. Draw 2") with no friendly minion, WHEN played, THEN mana is paid, the minion is on board, and no `effect_resolved` and no `card_drawn` is emitted (the whole effect never starts — Edge Cases).
- [x] **AC-09** GIVEN row 10 with one friendly minion, WHEN played targeting it, THEN the log order is `card_played`, `minion_summoned`, exactly two `card_drawn`, `effect_resolved`, then `minion_died` (the death check runs after the pass — the sacrificed minion is *dying* while the draws happen), and `effect_resolved.ops` is `[destroy: applied, draw: applied ×2]`.
- [x] **AC-39** GIVEN any `effect_resolved` in the fixture matches, WHEN inspected, THEN it carries `effect_id, host_id, host_kind, source_id, owner, trigger, depth, fizzled, ops[]` with one `ops` entry per op in the effect (`{op, targets, values, outcome}` with `outcome` from the closed set `applied | partial | no_target | board_full | burned | fatigue | empty_pool | skipped | already_has | no_such_trigger`), and its `cause_seq` equals that of the command event (`card_played` / `spell_cast` / `hero_power_used`) or the `trigger_resolved` that started it.

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

- `src/gameplay/effects/effect_resolver.gd` — modified (`resolve` runs play points now; `_run_play_point`, `_run_pass`, the `effect_resolved` payload, `_condition_holds` frame)
- `src/gameplay/effects/ops.gd` — created (`EffectOps`: dispatch table for the 12 ops, `OUTCOMES`, `fold_outcomes`)
- `src/gameplay/effects/selectors.gd` — modified (`entities` for `self`, `chosen`, `owner_hero`, `enemy_hero`, `owner_weapon`, `enemy_weapon`; `side_of` / `is_side_selector` for `owner`, `opponent`; `kind_of`, `find`)
- `tests/unit/card_effects/card_effects_play_triggers_test.gd` — created (11 tests)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/card_effects/card_effects_play_triggers_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] Created — 11 tests, passing in the full suite

---

## Dependencies

- Depends on: `production/epics/card-effects/story-001-dsl-spike-five-hardest.md` (PROCEED verdict), `production/epics/card-effects/story-002-runtime-binding-config.md`, `production/epics/card-effects/story-004-validator-step-bound-targeting.md`, `production/epics/card-effects/story-005-fixture-set-database-injection.md` (fixture). Cross-epic: `production/epics/match-rules/` (command handlers firing `battlecry` / `on_cast` / `hero_power`, the primitives, the C10 loop, `emit` with `cause_seq`).
- Unlocks: `production/epics/card-effects/story-007-values-selectors-spell-damage.md`, `story-008-event-observers-queueing.md`, `story-010-discover-choose-one.md`, `story-011-hero-powers.md`

---

## Completion Notes
**Completed**: 2026-11-04 (started 01:40:49 UTC, ended 01:50:46 UTC; a container restart cost no work on this story)
**Criteria**: 3/3 passing (AC-08, AC-09, AC-39), no deferred items
- AC-08 — `test_row_10_with_no_friendly_minion_pays_mana_places_the_body_and_emits_no_effect`. **Contract with match-rules C6 step 3a, recorded as the story asks:** the engine never raises `battlecry` for a `required` `chosen` with no legal target (`RulesEngine._play_plan` returns `fizzles`, already on trunk from match-rules 010); the resolver adds no guard of its own.
- AC-09 — `test_row_10_on_a_friendly_minion_draws_twice_while_it_is_dying_then_it_dies` (log order `card_played, minion_summoned, card_drawn ×2, effect_resolved, minion_died`; `ops == [destroy: applied, draw: applied {count 2}]`), plus `test_an_op_after_destroy_still_reaches_the_dying_chosen_minion` (C3: `chosen` is a reference).
- AC-39 — `test_every_play_row_of_the_fixture_emits_one_well_formed_effect_resolved` (every C11 fixture host with a play trigger, derived from `cards_effects_test.json`: exactly the nine payload keys, one `ops` entry per op with `{op, targets, values, outcome}`, outcome in the closed set, `cause_seq` == the command's event), `test_a_spell_effect_resolved_carries_the_payload_and_the_spell_cast_cause`, `test_a_hero_power_effect_resolved_is_caused_by_hero_power_used`.
- One-pass contract: `test_an_op_with_no_target_does_not_stop_the_next_op`, `test_a_false_condition_fizzles_the_pass_with_every_op_skipped`; ops: `test_summon_places_each_copy_right_of_the_source_left_to_right`, `test_summon_onto_a_full_board_is_board_full_per_failed_copy`, `test_granting_a_keyword_already_held_is_already_has`.
- Watched fail: 10 of 11 failed against the story-002 stub `resolve()`; AC-08 passes there by construction, so it was mutated instead. One mutation per run, each restored: engine `_play_plan` never fizzles (AC-08 failed), `_engine._drain()` after every op (AC-09 and the dying-reference test failed), stop the pass after a `no_target` (no-target and fixture tests failed), conditions always true (fizzle test failed), summon ignores copies already placed (summon order failed), no `already_has` check (keyword test failed), no `board_full` record (full-board test failed), `on_cast` raised under the wrong cause (spell payload and fixture tests failed).
**Verification**: `godot --headless --path . --import` exit 0; full suite (`commands.test`, `-c`) 994 test cases, 0 failures, exit 0; smoke exit 0, no SCRIPT ERROR; `tools/lint/gates.sh` PASS, G1–G6 (corrected 2026-11-04, sprint-4 review X1: `gates.sh` ran G1–G6 only then; G7 did not exist, so this line was wrong. A hand run of its regex over `src/gameplay/effects/` found 0 hits, and the gate now exists), `no_global_rng.sh` 0 hits, `parse-check.sh` 31 checked, 0 failed. The suite's 85 SCRIPT ERROR lines are unchanged, all from other systems' negative tests.
**Run result**: N/A — nothing renders: the real resolver is not yet composed into a playable match (no `MatchDriver`), and the match UI's `effect_resolved` playback is match-ui's.
**Engine edits**: none (`rules_engine.gd` unchanged; two mutations there were restored).
**Deviations** (all ADVISORY):
- **Fizzled payload lists every op `skipped`** (targets `[]`, values `{}`) rather than `ops: []`: C1 says "no ops run" and AC-39 says "one `ops` entry per op in the effect"; both hold this way.
- **Condition frame only**: `all` / `any` / `not` / `is_owner_turn` are evaluated; `cmp` / `exists` / `test` / `holding` are story 007 and count as false until then (the effect fizzles rather than running unchecked — row 4 and every row-8/15/16/22/23 `conditional` resolve that way today).
- **Values are int literals** (`EffectOps._int`; a value expression is 0) and `damage` has no Spell Damage (F1) — story 007. `requested` equals `amount` here.
- **Unshipped ops are recorded `skipped`** and call nothing (`discover`, `choose_one`, `conditional`, `repeat`, `transform`, `return_to_hand`, counters, …), as are selectors outside this story's eight (`no_target`).
- **Side-scoped ops carry `targets: []`** and `values.side`; `summon` / `equip` list the new entity ids as `targets`. `mana` with no `duration` is permanent (`temporary` only for `this_turn`, C5).
- **Open for match-ui:** `MatchViewState` tests `effect_resolved.fizzled == true`, but the payload carries `null | "condition_false"` (card-effects Interactions), so a fizzle never animates. Not this story's file.
**Test Evidence**: `tests/unit/card_effects/card_effects_play_triggers_test.gd`
**Reviewed by**: self, no independent review (lean: LP-CODE-REVIEW and QL-TEST-COVERAGE skipped — Lean mode; `/code-review` not run) · `/code-review 2026-11-04 (independent, sprint-4 carry): APPROVED WITH SUGGESTIONS (2 should-fix)` — both closed on trunk by their owning stories: this_turn mana by match-rules 011, pinned end to end in 9645f27; computed values by card-effects 007 (the interim skipped guards 2075537 / 6081c85 were reverted at merge 5852be0)
