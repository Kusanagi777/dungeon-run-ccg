# Story 007: Value expressions, conditions, Spell Damage (F1) and area / random selectors (F5)

> **Epic**: Card Effects
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-04

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

- `src/gameplay/effects/values.gd` — created (`EffectValues`: `eval`, `ref` over the C4 path set, `entity`, `holds` — `cmp`, `exists`, `test`, `holding`, `is_owner_turn`, `all` / `any` / `not`)
- `src/gameplay/effects/selectors.gd` — modified (area, random F5, neighbour, hand and deck pools; `pool`, `pick_count`, `hand_cards`; value-expression predicates)
- `src/gameplay/effects/ops.gd` — modified (value params evaluated in `run` with the non-negative clamp; `run_all` for `conditional` / `repeat`; F1 Spell Damage in `damage`; `_int` doc comment only)
- `src/gameplay/effects/effect_runtime.gd` — modified (`per_turn` tallies: `tally`, `bump`, `reset_turn`)
- `src/gameplay/effects/effect_resolver.gd` — modified (pass context carries the resolver; `run_all`; conditions through `EffectValues`; `_keep_tallies`)
- `tests/unit/card_effects/card_effects_values_selectors_test.gd` — created (12 tests)
- `tests/unit/card_effects/card_effects_play_triggers_test.gd` — modified (expected `ops` entries counted through `conditional` / `repeat`)

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/card_effects/card_effects_values_selectors_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] Created — 12 tests, passing in the full suite

---

## Dependencies

- Depends on: `production/epics/card-effects/story-006-play-triggers-one-pass.md`; AC-23 and AC-24 also need `production/epics/card-effects/story-008-event-observers-queueing.md` (turn triggers are queued event triggers). Cross-epic: `production/epics/match-rules/` (F7 `spell_damage`, `turn_start` / `turn_end` trigger points), `production/epics/rng-event-log/` (the `match_<floor>` stream).
- Unlocks: `production/epics/card-effects/story-009-deathrattle-snapshot-counters.md`, `story-011-hero-powers.md`, `story-012-auras-enchantments.md`

## Readiness

`/story-readiness` (by hand, 2026-11-04, Tier: workflow full, review lean): **READY**.
Design Completeness: GDD C3/C4/C5/F1/F5 traced, ACs testable. Architecture Completeness:
ADR-0007 Accepted (version 2026-11-03 = story); TR-card-effects-002 active; Manifest Version
current. Scope Clarity: estimate M, Out of Scope and dependencies stated. Open Questions: no
markers; story 006 Complete, story 008 Complete on this lane (71d7842). Asset References: none.
Definition of Done: 4 ACs, Logic type, test evidence path, perf guardrail (story 016).
QL-STORY-READY skipped — Lean mode.

## Completion Notes
**Completed**: 2026-11-04 (started 03:02:17 UTC, ended 03:10 UTC)
**Criteria**: 4/4 passing (AC-13, AC-14, AC-23, AC-24), no deferred items
- AC-13 — `test_a_hero_power_deal_1_does_not_scale_with_spell_damage`, `test_a_spell_deal_3_scales_with_two_spell_damage_minions_to_5` (`effect_resolved.ops[0].values {amount: 3, requested: 5}`).
- AC-14 — `test_row_19_deals_3_to_each_enemy_minion_left_to_right_then_the_hero`.
- AC-23 — `test_row_22_with_four_cards_fizzles_condition_false_and_deals_nothing`, `test_row_22_with_five_cards_hits_one_random_enemy_character_with_one_draw` (one recorded `randi_range` on the injected `TestRngStream`).
- AC-24 — `test_row_34_repeat_kills_the_only_enemy_minion_then_finds_no_target` (`applied`, `no_target`; the hero never hit), `test_a_negative_computed_damage_amount_is_clamped_to_0_and_logged` (`clamped_from: -2`, `apply_damage(…, 0)` still called).
- Beyond the ACs: `{count}` with `not_self`, `adjacent of: target`, `conditional` logging the branch not taken `skipped` with `values.condition`, per-turn tallies and their Start-step reset.
- Watched fail: 10 of 12 failed before the code; the 2 that passed by construction were mutated, one mutation per run, each restored: `auto` always scales (hero-power test failed), `cmp >=` always true (four-card fizzle and tally tests failed).
**Verification**: `godot --headless --path . --import` exit 0; full suite (`commands.test`) 1099/1099, exit 0, 85 SCRIPT ERROR lines (the story-006 baseline, all from other systems' negative tests); smoke exit 0, no SCRIPT ERROR; `tools/lint/gates.sh` PASS, G1–G6 (corrected 2026-11-04, sprint-4 review X1: `gates.sh` ran G1–G6 only then; G7 did not exist, so this line was wrong. A hand run of its regex over `src/gameplay/effects/` found 0 hits, and the gate now exists), `no_global_rng.sh` 0 hits; parse check of the 6 changed scripts ok.
**Run result**: N/A — nothing renders: the real resolver is not yet composed into a playable match (no `MatchDriver`).
**Engine edits**: none. F7 is read through `engine.spell_damage(owner)`; draws only through `engine.rng_match()`.
**Deviations** (all ADVISORY):
- **`damage_dealt.amount` in AC-13/14/23 is C15's `requested` / `dealt`** (DD-X04: match-rules C15 is authoritative; `damage_dealt` carries no `amount`). The tests assert both, and they are equal because no shield or armour is involved.
- **ops.gd `_int` site (sprint-3 review note, Lane 4 concurrently)**: computed values are evaluated in `EffectOps.run` before dispatch, so no non-literal reaches `_int`. At that site only its two doc-comment lines changed, so the orchestrator can reconcile with Lane 4's `skipped` guard (now unreachable for computed values).
- **`{count}` / `{exists}` over a random selector draw nothing**: they read the pool (`min(n, |pool|)`), keeping determinism independent of value reads.
- **`conditional` / `repeat` log no entry of their own**: `ops` lists one entry per leaf op (C5 "one ops entry per inner op executed"), and story 006's every-play-row test now counts expected entries that way (rows 8, 15, 23).
- **Hand / deck selectors yield card instance ids**, but ops still accept only in-play kinds (`LEGAL_KINDS`), so `buff cost` on hand or deck cards stays `skipped` until story 011. `summon position: chosen_slot` is not implemented (the engine passes no slot to the resolver).
- **`source.*` / `trigger_*` refs read live**, and a departed `source` reads the queue snapshot. `trigger_subject` snapshots are story 009's.
**Test Evidence**: `tests/unit/card_effects/card_effects_values_selectors_test.gd`
**Reviewed by**: not reviewed — `/code-review` NOT ASSESSED (agent-requiring gate, lean lane run)
