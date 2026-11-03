# Story 001: Spike — the five hardest DSL effect types (gate condition 6)

> **Epic**: Card Effects
> **Status**: In Progress
> **Layer**: Core
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-03

## Context

**GDD**: `design/gdd/card-effects.md`
**Requirement**: `TR-card-effects-002` (also exercises `TR-card-effects-003`, `TR-card-effects-001`)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Effect Resolver / Validator Boundary (also ADR-0002: effect schema is plain JSON)
**ADR Decision Summary**: The engine owns time and order, the resolver owns meaning: `EffectResolver` reads live state through `engine.state()`, mutates only through engine primitives, draws only through `engine.rng_match()`, keeps its only state as plain data in `MatchState.effects`, and one effect pass is one C10 step.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (by version; the APIs used predate 4.3 and are LOW)
**Engine Notes**: ADR-0007 Engine Compatibility — no post-cutoff APIs (`RefCounted`, `Dictionary`, `Array`, `StringName`, `Callable`, `static func`). Two sourced 4.7 rules apply to how code is written: an override of a typed method returns explicitly; lambdas capture locals by value, so evaluators are bound methods, never closures over mutable state.

**Control Manifest Rules (this layer)**:
- Required: `EffectResolver` mutates match state only through engine primitives, emits only through `engine.emit`, draws only through `engine.rng_match()`; one effect pass = one C10 step
- Forbidden: never compile effects to GDScript Callables at load; never write match state directly from `src/gameplay/effects/**` (grep gate G7); never let the resolver own the C10 loop
- Guardrail: `RulesEngine.submit()` ≤ 5 ms worst case including resolver passes

### Why this story exists

The systems index names DSL expressiveness the project's top technical risk, and the Pre-Production gate (`production/gate-checks/gate-pre-production-2026-11-03.md`, entry condition 6, owner lead-programmer) requires sprint 1 to spike the five hardest DSL effect types headless before the bulk of the ops land. **Spike code is throwaway**: it may live in a `spike/` subfolder, skip the full validator, and use a stub engine exposing only the primitives these five rows need if match-rules' `RulesEngine` has not merged yet. Stories 002–016 do not depend on the spike's code shape, only on its verdict.

**The five effect types** (this run's selection from C11 and the MVP card list — the gate names the count, not the rows; the lead-programmer may swap one before `/story-readiness`, naming the replacement here):

| # | C11 row | Why it is hard | GDD AC it must reproduce |
|---|---|---|---|
| 1 | 20 — "Discover a spell" | Pauses resolution mid-pass: `ChoiceRequest`, continuation in `EffectRuntime.pending_choice`, F4 draws, resume by `choose` (C8) | AC-10, AC-11 |
| 2 | 33 — Choose One "Deal 2 / Restore 4" | Same continuation with `kind: choose_one`, options sharing one effect-level `chosen` target (C8.3) | AC-12 |
| 3 | 16 — Rot "Deal 1. If it dies, summon a Husk" | `is_dying` read inside one atomic pass, before the death check; Husk arrives before the target's Deathrattle (C6.0, C3) | AC-43 |
| 4 | 45 — "Deathrattle: 1 damage per minion that died while this was in play" | Two effects on one host; `add_counter` into `EffectRuntime.counters`; Deathrattle reads the raise-time snapshot (C6.5) | AC-46 |
| 5 | 26 + 27 — aura lord and adjacency aura, stacked | Standing claims recomputed every step in canonical source order; F2 stacking; neighbours change (C7) | AC-26 |

Rejected as "hard" candidates: value folds (ADR-0005's mechanism, mechanical), `repeat` with random selection (F5 is a straight draw loop).

---

## Acceptance Criteria

*From GDD `design/gdd/card-effects.md` (C6.0, C7, C8, F2, F4; AC-10, AC-12, AC-26, AC-43, AC-46) and gate entry condition 6, scoped to this story:*

- [ ] **AC-S1** GIVEN the five effect objects above encoded **verbatim** from C11 (no `targeting` field, no new op or trigger), WHEN each is resolved headless in gdUnit4 with an injected fixed seed (no Node, no scene), THEN each produces the event order its named GDD AC states — row 20: `discover_offered` with 3 distinct spell ids, engine in `Choice`, exactly 3 stream draws, card in hand after `choose(1)`; row 33: `choose(0)` → `damage_dealt{amount: 2}` and no `healed`, `choose(1)` → `healed` and no `damage_dealt`; row 16: `damage_dealt`, `minion_summoned{decay_husk}`, `effect_resolved`, then `minion_died`, and no summon on a 2/3; row 45: `damage_dealt{amount: 3}` after three deaths, read from the snapshot's `counter.seen`; rows 26+27 on `[26, 26, vanilla 1/1, 27]`: the 1/1 reads 5/3, each lord +1/+1, row 27 +2/+2.
- [ ] **AC-S2** GIVEN the five results, WHEN the spike closes, THEN `docs/architecture/spikes/2026-11-DD-dsl-effect-spike.md` records a **PROCEED** or **PIVOT** outcome: PROCEED means all five resolved per C6.0 (one pass, no death check between ops) and C8 (one outstanding `ChoiceRequest`) with **no DSL change**; PIVOT names each C1–C9 rule, selector or op that must change, the GDD section, and hands it to `/propagate-design-change`. On PIVOT, stories 006–016 of this epic are re-marked Blocked until the GDD change lands.
- [ ] **AC-S3** GIVEN the spike's code, WHEN this story closes, THEN everything it wrote under `src/gameplay/effects/` is either deleted or promoted explicitly by story 002/006 (noted in that story's Files), grep gate G7 reports zero hits on whatever remains, and no production class, scene or data file depends on the spike folder.

---

## Implementation Notes

*Derived from ADR-0007 Implementation Guidelines and C6/C8:*

- Even in throwaway code, keep the boundary: the spike resolver calls primitives (`apply_damage`, `summon_minion`, `discover`, `add_card_to_hand`, `apply_enchantment`) and `engine.emit`; it never assigns a `MatchState` field. A spike that passes by cheating the boundary proves nothing about the risk.
- Row 20 / 33: the continuation is `{effect_id, source snapshot, op_index, options, remaining ops}` stored as plain data in `EffectRuntime.pending_choice`; `resume(choice, option_index)` applies `then` (or the option's `ops`) and continues from `op_index + 1`. No RNG is drawn while waiting (C8.1).
- Row 16: `conditional.if = {"test": ["target", {"is_dying": true}]}` reads the live target between op 1 and the death check; a popped Divine Shield leaves `health` unchanged → `false` (C3 `is_dying`).
- Row 45: `EffectRuntime.counters[source_id][key]`, `counter_changed` emitted per change; the Deathrattle snapshot (C6.5) copies `counters` at raise time.
- Rows 26+27: `recompute_auras()` strips every `is_aura` enchantment and re-applies live auras in canonical source order; one source never applies the same aura twice to one target; two sources stack (F2).
- If match-rules' `RulesEngine` is not merged when the spike starts, build a **stub engine** in the spike folder exposing only `state()`, `emit()`, `rng_match()` (a `TestRngStream`), `discover()`, and the primitives listed above; `MatchFactory` and `CardFactory` already supply the data shapes. Record in the spike doc which engine the spike ran against.
- Use `TestRngStream.scripted(...)` for the F4 draws so AC-10's "exactly 3 draws" is asserted via `draws`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: the production `EffectRuntime`, `bind`/`unbind` lifecycle, `card_effects.json`
- Story 003–005: `EffectValidator` and the fixture set
- Story 010: production Discover / Choose One (the full F4 pool rules, `empty_pool`, boss-side choice)
- Story 012: production auras, Silence and expiry lifecycle

---

## Files

- `src/gameplay/effects/spike/spike_effect_resolver.gd` — created (throwaway spike resolver; deleted from `src/` at close — AC-S3)
- `src/gameplay/effects/spike/spike_stub_engine.gd` — created (throwaway stub engine; deleted from `src/` at close — AC-S3)
- `tests/unit/card_effects/card_effects_dsl_spike_test.gd` — created (17 test functions)
- `docs/architecture/spikes/2026-11-03-dsl-effect-spike.md` — created (the PROCEED/PIVOT record)

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/card_effects/card_effects_dsl_spike_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)
- Plus the spike record with its PROCEED/PIVOT line (AC-S2)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None within this epic (the spike is first by design). Cross-epic: `production/epics/match-rules/` (RulesEngine primitives and `discover()` — a stub engine is allowed if those stories are not done), `production/epics/rng-event-log/` (`TestRngStream` already exists in `tests/helpers/`); story paths are assigned by those epics' concurrent `/create-stories` runs.
- Unlocks: `production/epics/card-effects/story-006-play-triggers-one-pass.md` through `story-016-determinism-clone-bounds-perf.md` (a PIVOT re-blocks them)
