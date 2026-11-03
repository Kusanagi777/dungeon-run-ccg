# Epic: Card Effects

> **Layer**: Core
> **GDD**: design/gdd/card-effects.md (`full` section set per `system_overrides`; Overview, Detailed Rules C1–C11, Formulas F6, Edge Cases, Dependencies, Tuning Knobs, Acceptance Criteria)
> **Architecture Module**: `EffectResolver` + `EffectValidator` + `EffectRuntime` + `Selectors` + `Ops` + `ChoiceRequest` (`src/gameplay/effects/`)
> **Control Manifest**: Core Layer Rules (Manifest Version 2026-11-03)
> **Build Order**: 5 of 14 — plan E3, ADR-0007 / ADR-0002 / ADR-0005
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories card-effects`

## Overview

Build the language every card, hero power, boss passive and treasure is written in and the machine that runs it. An effect is plain JSON — trigger, optional condition, target selector, ordered `ops[]`, `once_per_turn` — and `targeting_spec(def_id)` is derived from the one play selector, never stored (C1). `EffectResolver` binds at `RulesEngine.start`, listens at the engine's trigger and hook points, composes card text from engine primitives only (C5), takes one effect pass per C10 step (C6), raises exactly one `ChoiceRequest` per Discover / Choose One with a continuation resumed by `choose` (C8), binds treasure and passive effects to hook points as synchronous steps or folds (C9), draws only through `engine.rng_match()` and emits one `effect_resolved` per effect. `EffectValidator.validate_effects` is a static pure function with the closed `E_FX_*` / `W_FX_*` set, injected into Card Database stage 7 so an unexpressible card fails the build. The systems index names DSL expressiveness the top technical risk, so sprint 1 spikes the five hardest effect types before the rest of the ops land.

## Scope (MVP)

- `EffectRuntime {once_marks, counters, per_turn, pending_choice}` as plain data in `MatchState.effects`, copied by value in `clone()`
- Triggers, selectors and ops needed by the MVP card list (content.md MVP batch; C11 coverage table rows for War + Neutral), hero powers (`hero_power` trigger, DD-M13), boss passives (band-1..3 MVP bosses) and the 10 MVP treasures
- `derive_targeting_spec` memoised per `def_id`; `legal_targets(def_id, source)`; `recompute_auras()`
- `EffectValidator` + the five-parameter accept-all stub for tests; `EFFECT_STATIC_STEP_LIMIT` 250, `MAX_OPS_PER_EFFECT` 8 from `config("card_effects")`
- Sprint-1 spike: the five hardest DSL effect types (gate condition 6) proven headless before the remaining ops

Out of scope: ops the full 120-card pool needs beyond the MVP batch (deferred list); v2 deferrals named in card-effects.md §C11.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0007: Effect Resolver / Validator Boundary | Resolver mutates only through primitives, emits only through `engine.emit`, draws only through `engine.rng_match()`; `EffectRuntime` rides in `MatchState`; validator is static and pure; one pass = one C10 step | HIGH by version; APIs pre-4.3 (LOW) |
| ADR-0002: Data format, effect schema/DSL and `config()` loading | Effect object schema; `effects[]` and `passive` are plain JSON with no code references; validator injection at stage 7b `call(host_kind, host_id, value, db, configs)` | HIGH (general) / LOW (APIs) |
| ADR-0005: Owner-scoped hook registry | Hook effects are DSL effects; resolver registers `set_evaluators(apply_value_hook, run_hook_effect)` at `bind`; ordering within one entity only | LOW (APIs) / HIGH (language) |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-card-effects-001 | C1: effect objects are plain JSON (trigger, scope, condition, targets, ops[], once_per_turn); targeting_spec(def_id) is derived from the one chosen play selector, never stored | ADR-0007 ✅ (also ADR-0002) |
| TR-card-effects-002 | C5, C6: the resolver composes card text from engine primitives only; one effect pass = one C10 step; binding at RulesEngine.start | ADR-0007 ✅ |
| TR-card-effects-003 | C8, C6: Discover / Choose One raise exactly one ChoiceRequest, pausing resolution with a continuation resumed by choose | ADR-0007 ✅ |
| TR-card-effects-004 | C9: treasure and passive effects bind to hook points (trigger hooks as synchronous steps; value hooks as folds) or run as hero-slot observers | ADR-0007 ✅ (also ADR-0005) |
| TR-card-effects-005 | C10: validate_effects(host_kind, host_id, effects[]) -> report[] with the closed E_FX_* set, injected into Card Database stage 7 | ADR-0007 ✅ (also ADR-0002) |
| TR-card-effects-006 | F6: static step bound per effect within EFFECT_STATIC_STEP_LIMIT (250); MAX_OPS_PER_EFFECT 8 | ADR-0007 ✅ |

Requirements covered by Accepted ADRs: 6 / 6. Untraced Requirements: None.

## Gate Entry Conditions Carried

- **Condition 6** (sprint-1 spike): the five hardest DSL effect types, chosen from card-effects.md §C11 and the MVP card list, implemented and unit-tested headless before the bulk of the ops — lead-programmer.
- **Condition 5**: the War starter deck's effects resolve correctly for the first playable.

## Definition of Done

- Every story implemented, reviewed and closed with `/story-done`
- Every acceptance criterion of design/gdd/card-effects.md verified (46 criteria lines)
- Every MVP-batch card, hero power, boss passive and treasure passes `validate_effects` with zero errors through the Card Database
- Logic and Integration stories have passing tests in the test root
- Visual/Feel and UI stories have retained screenshots in `production/qa/evidence/` (a lead sign-off too for Visual/Feel)
