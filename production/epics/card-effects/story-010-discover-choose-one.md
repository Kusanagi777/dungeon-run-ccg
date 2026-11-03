# Story 010: Discover and Choose One — `ChoiceRequest` and the continuation

> **Epic**: Card Effects
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

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

- [ ] **AC-10** GIVEN row 20 ("Discover a spell") and a War MVP pool of 40 cards with 9 spells, WHEN cast with seed 7, THEN `discover_offered.option_card_ids` has 3 distinct spell ids none of which is the casting spell, the engine is in `Choice`, exactly 3 stream draws were consumed (F4: `randi_range(0,7)`, `(0,6)`, `(0,5)` over the id-ascending candidate list), and after `choose(1)` that card is in hand and `discover_picked` precedes the next event; the log shows `choice_requested` then `discover_offered`, and on resume `choice_made` then `discover_picked`, all under one `cause_seq`.
- [ ] **AC-11** GIVEN a Discover whose filter matches 2 cards, WHEN cast, THEN 2 options are offered; GIVEN a filter matching 0, THEN no `Choice` phase, op outcome `empty_pool`, and the following op in the same effect still runs; `pool: deck` on an empty deck is `empty_pool` with no fatigue; a pick into a full hand is still a pick and the engine burns it (`burned`).
- [ ] **AC-12** GIVEN row 33 (Choose One, effect-level `chosen` `kind: any`) cast on an enemy 3/3, WHEN `choose(0)` (Smite), THEN `damage_dealt{amount: 2}` and no `healed`; WHEN `choose(1)` instead, THEN `healed` and no `damage_dealt`; `discover_offered.kind == choose_one` with `option_label_keys` `[opt.smite, opt.mend]`; and a `repeat` around a `discover` produces sequential choices, each after the previous `choose` (at most one `ChoiceRequest` outstanding, C8.4).

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

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/gameplay/effects/ops.gd` (`discover`, `choose_one`, `add_to_hand` with `from: {pool, filter}`)
- `src/gameplay/effects/effect_resolver.gd` (`resume`, pass suspension)
- `src/gameplay/effects/choice_request.gd`
- `src/gameplay/effects/effect_runtime.gd` (`pending_choice`)
- `tests/unit/card_effects/card_effects_choices_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/card_effects/card_effects_choices_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/card-effects/story-006-play-triggers-one-pass.md`, `production/epics/card-effects/story-007-values-selectors-spell-damage.md` (filters over pools). Cross-epic: `production/epics/match-rules/` (`discover(side, options)` primitive, `Choice` phase, `choose` command calling `resolver.resume`), `production/epics/card-database/` (`collectible_pool`, `has`).
- Unlocks: `production/epics/card-effects/story-016-determinism-clone-bounds-perf.md` (AC-37's replay deck contains row 20)
