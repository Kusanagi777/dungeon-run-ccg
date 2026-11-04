# Story 010: Discover and Choose One — `ChoiceRequest` and the continuation

> **Epic**: Card Effects
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-04

## Context

**GDD**: `design/gdd/card-effects.md`
**Requirement**: `TR-card-effects-003` (C8, C6: exactly one `ChoiceRequest`, continuation resumed by `choose`)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Effect Resolver / Validator Boundary
**ADR Decision Summary**: The resolver stores the Discover / Choose One continuation in `EffectRuntime.pending_choice`; the engine owns the `Choice` phase and `pending_choice.side`; `discover(side, options) -> ChoiceRequest` is a primitive and `resume(choice, option_index)` is called on `choose`; `discover_offered` / `discover_picked` go through `engine.emit`.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (by version; the APIs used predate 4.3 and are LOW)
**Engine Notes**: ADR-0007 Engine Compatibility — no post-cutoff APIs. The continuation is plain data (no Callable) so `clone()` and a future `restore(log)` carry it.

**Control Manifest Rules (this layer)**:
- Required: `EffectRuntime.pending_choice` is plain data in `MatchState.effects`; draws only through `engine.rng_match()`; Boss `Choice` with no task live → `boss_ai.choose(sandbox, pending)` then `engine.submit(choose{issuer: boss, option_index})` (ADR-0008 — the resolver only exposes the options)
- Forbidden: never compile effects to Callables (a continuation holding a Callable breaks `clone()`); never write match state directly (gate G7)
- Guardrail: `RulesEngine.submit()` ≤ 5 ms including the resume pass

---

## Acceptance Criteria

*From GDD `design/gdd/card-effects.md` (C5 `discover` / `choose_one`, C8, F4, Edge Cases "Choices"; AC-10, AC-11, AC-12), scoped to this story:*

- [x] **AC-10** GIVEN row 20 ("Discover a spell") and a War MVP pool of 40 cards with 9 spells, WHEN cast with seed 7, THEN `discover_offered.option_card_ids` has 3 distinct spell ids none of which is the casting spell, the engine is in `Choice`, exactly 3 stream draws were consumed (F4: `randi_range(0,7)`, `(0,6)`, `(0,5)` over the id-ascending candidate list), and after `choose(1)` that card is in hand and `discover_picked` precedes the next event; the log shows `choice_requested` then `discover_offered`, and on resume `choice_made` then `discover_picked`, all under one `cause_seq`.
- [x] **AC-11** GIVEN a Discover whose filter matches 2 cards, WHEN cast, THEN 2 options are offered; GIVEN a filter matching 0, THEN no `Choice` phase, op outcome `empty_pool`, and the following op in the same effect still runs; `pool: deck` on an empty deck is `empty_pool` with no fatigue; a pick into a full hand is still a pick and the engine burns it (`burned`).
- [x] **AC-12** GIVEN row 33 (Choose One, effect-level `chosen` `kind: any`) cast on an enemy 3/3, WHEN `choose(0)` (Smite), THEN `damage_dealt{amount: 2}` and no `healed`; WHEN `choose(1)` instead, THEN `healed` and no `damage_dealt`; `discover_offered.kind == choose_one` with `option_label_keys` `[opt.smite, opt.mend]`; and a `repeat` around a `discover` produces sequential choices, each after the previous `choose` (at most one `ChoiceRequest` outstanding, C8.4).

---

## Implementation Notes

*Derived from ADR-0007 Decision 1 and GDD C8, F4:*

- `discover` op: build `candidates = distinct_by_def_id(filter(base(pool), op.filter) \ {source.def_id})`, with `base(collectible) = db.collectible_pool(player_hero_set)` (both sides draw from the player's pool), `base(list) = op.list ∩ has(id)`, `base(deck)` / `base(hand)` = owner's instances; apply `DISCOVER_EXCLUDE_HAND` from config; keep id-ascending order before drawing; `n_options = min(DISCOVER_COUNT, |candidates|)`; `n_options` draws with removal. `n_options == 0` → outcome `empty_pool`, continue.
- Then `engine.discover(side, options)` (the primitive enters `Choice` and emits `choice_requested`); the resolver emits `discover_offered{side, source_id, effect_id, kind, option_card_ids | option_label_keys}` and stores `pending_choice = {effect_id, source snapshot, op_index, options, remaining_ops, then, host context}` — plain data. The pass is suspended: no `effect_resolved` yet, no RNG drawn while waiting.
- `resume(choice, option_index)` (called by the engine on `choose`): emit `discover_picked{side, picked_index, picked_card_id | picked_label_key}`; apply `then` (`add_to_hand` → `add_card_to_hand`, `summon` → `summon_minion`, `cast` → resolve that card's `cast` effect — v1 content never uses `then: cast`) or, for `choose_one`, run the option's `ops` inline; continue the same effect from `op_index + 1`; emit the one `effect_resolved`; clear `pending_choice`. The engine then runs the C10 loop.
- Boss side: `pending_choice.side = boss`; options still ride on `discover_offered` (the UI may hide them). `concede` during `Choice` drops the continuation (engine owns that path).
- `ChoiceRequest` shape `{side, kind: discover | choose_one, options: Array, source_id, effect_id}` (story 002 defined the script).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001 (spike) proved the mechanism on throwaway code; this is the production path
- match-rules: the `Choice` phase, `choice_requested` / `choice_made`, `CHOICE_PENDING` rejections, `concede`
- `production/epics/boss-ai-match-driver/`: how the boss picks
- `production/epics/match-ui/`: the Choice overlay

---

## Files

- `src/gameplay/effects/effect_resolver.gd` — pass suspension (work list, `_offer`), `resume`, `_apply_pick`, play-run tail, `player_hero_set` / `collectible_pool`, `unbind` drops a pending continuation
- `src/gameplay/effects/ops.gd` — `work` / `step` / `tag_condition` (replace `run_all`), F4 `pool_candidates` / `draw_options`, `add_to_hand` (`card_id` or `from: {pool, filter, list}`)
- `src/gameplay/match/rules_engine.gd` — one added line in `_do_choose`: `choice_made` under the paused step's `cause_seq` (out of the planned list; see Completion Notes)
- `tests/unit/card_effects/card_effects_choices_test.gd` (+ `.uid`) — 17 tests
- `tests/unit/card_effects/card_effects_play_triggers_test.gd` — the every-play-row test answers a Choice (row 33) and its fake database answers `collectible_pool` (out of the planned list)
- `src/gameplay/effects/choice_request.gd`, `src/gameplay/effects/effect_runtime.gd` — unchanged (the shapes from story 002 sufficed)

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/card_effects/card_effects_choices_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] Created — 17 tests, passing in the full suite

---

## Dependencies

- Depends on: `production/epics/card-effects/story-006-play-triggers-one-pass.md`, `production/epics/card-effects/story-007-values-selectors-spell-damage.md` (filters over pools). Cross-epic: `production/epics/match-rules/` (`discover(side, options)` primitive, `Choice` phase, `choose` command calling `resolver.resume`), `production/epics/card-database/` (`collectible_pool`, `has`).
- Unlocks: `production/epics/card-effects/story-016-determinism-clone-bounds-perf.md` (AC-37's replay deck contains row 20)

---

## Readiness (2026-11-04, `/story-readiness` by hand)

**Verdict: READY** (tier `full`). ADR-0007 Accepted; TR-card-effects-003 is in the registry; Manifest Version 2026-11-03 is current. Dependencies 006, 007 and match-rules 016 are Complete. Gaps, resolved from the docs at implementation time:
- **`player_hero_set` has no source in `MatchState`.** F4's `base(collectible)` needs the run's hero set. `MatchConfig.player.hero_def_id` is not kept after `start`. Resolved by an optional third `EffectResolver._init` argument (see Completion Notes).
- **NC-2 divergence watch.** Checked against MR-016's merged `_cast_spell`: the stages are host `on_cast` → `on_card_played` hooks → observers → `after_cast` → `spell_done`, so row 21 draws after `choose`. That agrees with C6.3 and nothing diverges.
- **No primitive moves a given deck or hand instance to hand or board** (F4 `base(deck)` / `base(hand)`: "pick moves it to hand"). An empty pool is fully specified (AC-11). A pick from those pools is recorded as unsupported (see Completion Notes).

---

## Completion Notes

**Completed**: 2026-11-04 (started 03:45 UTC, ended 04:05 UTC)
**Criteria**: 3/3 passing. Each AC has at least one test:
- AC-10: `test_row_20_discover_offers_three_distinct_spells_from_f4_draws` and `test_row_20_choose_one_puts_the_pick_in_hand_under_one_cause_seq`.
- AC-11: `test_a_filter_matching_two_…`, `test_a_filter_matching_none_…`, `test_a_deck_pool_on_an_empty_deck_…` and `test_a_pick_into_a_full_hand_…`.
- AC-12: `test_row_33_choose_zero_…`, `test_row_33_choose_one_…` and `test_a_repeat_around_a_discover_…`.
- QA plan NC-2: `test_discover_spell_resumes_remaining_ops_once_then_engine_after_cast`, plus `test_choose_one_option_ops_run_inline_then_rest_of_effect` and `test_concede_during_choice_drops_continuation`.
- Further seams: a later `cast` effect of the same host runs after `choose`; `then: summon`; `DISCOVER_EXCLUDE_HAND`; `add_to_hand from` (one F4 pick per copy); a boss Discover.

**Test Evidence**: `tests/unit/card_effects/card_effects_choices_test.gd`, 17 tests. The full suite is 1242/1242 with 0 failures, exit 0. There are 85 `SCRIPT ERROR` lines, all existing intentional negatives. Smoke exits 0.
**Mutation runs**: 7 mutants, each killed:
- the continuation drops `remaining_ops`;
- the pass does not suspend;
- F4 draws without removal;
- the owed play runs are dropped;
- the caster stays in the pool;
- `choice_made` is emitted at cause 0;
- `unbind` keeps the continuation.

**Run result**: N/A. This is a rules-layer change with no scene or UI surface; the Choice overlay belongs to match-ui.
**Reviewed by**: self, no independent review (`review_mode: lean`, LP-CODE-REVIEW and QL-TEST-COVERAGE skipped in lean mode; engine-specialist pass NOT ASSESSED, because no agent could be spawned). Run `/code-review` before the sprint close-out.

**Deviations** (ADVISORY unless marked):
1. **ADR-0007 Key Interfaces.** `EffectResolver._init(db, effects_config, player_hero_set := "")` gains an optional third argument. F4 needs the player's hero set, and `MatchState` does not carry it.
   - Composition code (MatchDriver, ADR-0008) must pass the run hero's `set`.
   - ADR-0007 Decision 3's `clone()` must pass `live_resolver.player_hero_set()` to the clone's resolver.
   - Without the argument, `pool: collectible` logs an error and is `empty_pool`.
   - An alternative is a hero-set field on `MatchState` (a match-rules C1 change).
2. **OUT OF SCOPE: `src/gameplay/match/rules_engine.gd` `_do_choose`.** One line was added, so that `choice_made` is emitted under the paused step's `cause_seq`, not cause 0.
   - This follows AC-10, card-effects Interactions and the rng-event-log catalogue (DD-X04: "all under one `cause_seq`").
   - MR-016's completion note describes `choice_made` as "(cause 0)".
3. **Instance pools.** A `discover` pick, or an `add_to_hand from` copy, over `pool: deck | hand` is outcome `skipped` with `values.unsupported`. It draws nothing for `add_to_hand`. Moving that instance needs a match-rules primitive.
4. **`then: cast`.** The picked spell's `cast` effects run as passes of their own once the Discover's pass has resolved, not inline before the effect's next op. This is because passes never nest. v1 content has no `then: cast`.
5. **`effect_resolved.ops` for Choose One.** The pass records a `choose_one` entry `{picked_index, label_key}`, followed by the option's op entries inline.
6. **`EffectOps.run_all` replaced** by the plain-data work list `work` / `step` / `tag_condition`. The `conditional` and `repeat` semantics and their `values.condition` tags are unchanged; all story-007 tests pass.
7. **OUT OF SCOPE: `tests/unit/card_effects/card_effects_play_triggers_test.gd`.** The story-006 every-play-row test was edited:
   - it answers a Choice (row 33);
   - its `_entry_count` counts `choose_one`;
   - its fake database answers `collectible_pool`.
8. **Guardrail "`submit()` ≤ 5 ms including the resume pass": NOT ASSESSED.** No match-rules or card-effects performance test exists; that is story 016's.
9. **MR-016 review N2 and N4 are taken up here.** `unbind` now clears a pending continuation (N2), and the production `resume` now exists (N4).
