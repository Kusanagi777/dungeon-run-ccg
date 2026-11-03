# Story 009: Raise-time snapshot, `once_per_turn`, Silence-after-queue and counters

> **Epic**: Card Effects
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/card-effects.md`
**Requirement**: `TR-card-effects-002`, `TR-card-effects-001` (`once_per_turn` in the schema; runtime as plain data)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Effect Resolver / Validator Boundary
**ADR Decision Summary**: `EffectRuntime {once_marks, counters, per_turn, pending_choice}` is the resolver's only state, plain data in `MatchState.effects`; `counter_changed` is emitted for each counter change through `engine.emit`; `once_per_turn` marks and tallies are derivable from the log and emit nothing.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (by version; the APIs used predate 4.3 and are LOW)
**Engine Notes**: ADR-0007 Engine Compatibility — no post-cutoff APIs. The snapshot is a `Dictionary` produced with `duplicate(true)` of plain containers only.

**Control Manifest Rules (this layer)**:
- Required: `EffectRuntime` is plain data (Dictionaries, Arrays, ints, Strings); `counter_changed` is emitted for each counter change
- Forbidden: `EffectRuntime` never holds a Callable, a Node or an object reference; never write match state directly (gate G7)
- Guardrail: `clone()` copies `EffectRuntime` by value — keep snapshots small (the C6.5 field list, nothing more)

---

## Acceptance Criteria

*From GDD `design/gdd/card-effects.md` (C5 `add_counter` / `set_counter`, C6.5, C6.7, Edge Cases; AC-19, AC-20, AC-21, AC-46), scoped to this story:*

- [ ] **AC-19** GIVEN row 11 ("Whenever a friendly minion dies, gain +1/+1") and two friendly minions dying in one death check, WHEN the loop completes, THEN row 11 has +2/+2 (two queued triggers, two `effect_resolved`); GIVEN the same effect with `once_per_turn: true`, THEN +1/+1 and exactly one `trigger_queued` (the mark is set when queued, keyed `(effect_id, source entity_id, match.turn)`; the second raise is dropped silently).
- [ ] **AC-20** GIVEN row 12 (Deathrattle: damage = `source.attack`) buffed to 5 Attack by an aura lord that dies in the same step, WHEN both die, THEN the enemy hero takes 5 (the raise-time snapshot), not the base Attack.
- [ ] **AC-21** GIVEN a minion Silenced while its Deathrattle is already queued (`destroy` then `silence` on a `pending_destroy` target in one effect), WHEN the loop completes, THEN the Deathrattle still resolves (queued = earned); GIVEN Silence **before** death, THEN no `trigger_queued` for it.
- [ ] **AC-46** GIVEN row 45 after three minions (either side) died while it was in play, WHEN it dies, THEN `damage_dealt{amount: 3}` on the enemy hero read from `counter.seen` in the raise-time snapshot, with three prior `counter_changed{source_id, key: seen, value}` events; GIVEN the same minion bounced to hand and replayed, THEN its counter reads 0 (counters die with the `entity_id`).

---

## Implementation Notes

*Derived from ADR-0007 Decisions 1, 5 and GDD C6.5, C6.7:*

- Snapshot at queue time: `{source_id, def_id, owner, attack, health, max_health, board_index, keywords, counters}` (C6.5), stored on the queued trigger record the engine holds (plain data). `source.*` and `counter.*` refs read live while the source is still the same `entity_id` in play, else the snapshot. `transform` mid-effect: later ops' `self` is the new entity; queued triggers of the old entity resolve from their snapshot (story 013 tests the transform half).
- `once_marks[effect_id + ":" + source_id + ":" + turn] = true` set when the effect is queued or run; no reset needed (the turn counter moves on). Keyed by treasure/passive id for hook hosts (story 015).
- `counters[source_id][key]` via `add_counter` / `set_counter`; `engine.emit(&"counter_changed", {source_id, key, value})` per change; a read of a never-set counter is 0. A `set_counter` with a `{count: selector}` value (row 46) evaluates the selector against the live board before the following `destroy`.
- Silence: the resolver checks `silenced` when deciding who responds (story 008); it never removes an already-queued trigger. Match-rules' Silence primitive owns the `silenced` flag; this story only reads it.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 008: responder selection and queueing itself
- Story 012: the aura lord dying (recompute) — AC-20 needs auras to exist; land 012 before closing AC-20 or stub the +5 with a `buff` and note it
- Story 013: `transform` and `return_to_hand` behaviour beyond the counter reset
- Story 016: AC-40 (clone with a queued trigger and a counter)

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/gameplay/effects/effect_resolver.gd` (snapshot capture, `once_per_turn` marks)
- `src/gameplay/effects/effect_runtime.gd` (`once_marks`, `counters` helpers)
- `src/gameplay/effects/ops.gd` (`add_counter`, `set_counter`)
- `src/gameplay/effects/values.gd` (snapshot-aware `source.*` / `counter.*` refs)
- `tests/unit/card_effects/card_effects_deathrattle_snapshot_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/card_effects/card_effects_deathrattle_snapshot_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/card-effects/story-008-event-observers-queueing.md`, `production/epics/card-effects/story-007-values-selectors-spell-damage.md`; AC-20 also `production/epics/card-effects/story-012-auras-enchantments.md`. Cross-epic: `production/epics/match-rules/` (death check, DD-M11 Deathrattle order, `silence` / `destroy` / `return_to_hand` primitives).
- Unlocks: `production/epics/card-effects/story-013-transform-copy-keyword-aura.md`, `story-015-hook-trigger-steps-hero-slot-observers.md`, `story-016-determinism-clone-bounds-perf.md`
