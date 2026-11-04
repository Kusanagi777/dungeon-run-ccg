# Epic: Card Effects

> **Layer**: Core
> **GDD**: design/gdd/card-effects.md (`full` section set per `system_overrides`; Overview, Detailed Rules C1–C11, Formulas F6, Edge Cases, Dependencies, Tuning Knobs, Acceptance Criteria)
> **Architecture Module**: `EffectResolver` + `EffectValidator` + `EffectRuntime` + `Selectors` + `Ops` + `ChoiceRequest` (`src/gameplay/effects/`)
> **Control Manifest**: Core Layer Rules (Manifest Version 2026-11-03)
> **Build Order**: 5 of 14 — plan E3, ADR-0007 / ADR-0002 / ADR-0005
> **Status**: Ready
> **Stories**: 17 (15 Logic, 2 Integration; 0 Blocked) — created 2026-11-03 by `/create-stories card-effects`; story 017 added 2026-11-04 (DD-X21); QL-STORY-READY skipped — Lean mode

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Spike — the five hardest DSL effect types (gate condition 6; throwaway allowed; PROCEED/PIVOT) | Logic | Ready | ADR-0007 |
| 002 | EffectRuntime, resolver binding lifecycle and `card_effects.json` | Logic | Ready | ADR-0007 |
| 003 | EffectValidator — schema, trigger, selector, op and reference checks | Logic | Ready | ADR-0007, ADR-0002 |
| 004 | F6 static step bound, `E_FX_BUDGET` and derived `targeting_spec` | Logic | Ready | ADR-0007 |
| 005 | C11 fixture set and validator injection into Card Database stage 7 | Integration | Ready | ADR-0002, ADR-0007 |
| 006 | Play triggers, `chosen` targeting and the one-pass contract | Logic | Ready | ADR-0007 |
| 007 | Value expressions, conditions, Spell Damage (F1) and area / random selectors (F5) | Logic | Ready | ADR-0007 |
| 008 | Event triggers — responder selection, scope and queueing order | Logic | Ready | ADR-0007 |
| 009 | Raise-time snapshot, `once_per_turn`, Silence-after-queue and counters | Logic | Ready | ADR-0007 |
| 010 | Discover and Choose One — `ChoiceRequest` and the continuation | Logic | Ready | ADR-0007 |
| 011 | Hero powers — Whetstone, Rot and Insight through the `hero_power` trigger | Logic | Ready | ADR-0007 |
| 012 | Auras (`recompute_auras`), hand-cost auras and the enchantment lifecycle (F2, F3) | Logic | Ready | ADR-0007 |
| 013 | Transform, copy-to-hand, bounce and keyword auras from a treasure host | Logic | Ready | ADR-0007, ADR-0005 |
| 014 | Value triggers — `apply_value_hook` folds for cost, damage and max attacks | Logic | Ready | ADR-0005, ADR-0007 |
| 015 | Trigger hooks as synchronous steps and hero-slot observers (treasures, boss passives) | Logic | Ready | ADR-0005, ADR-0007 |
| 016 | Determinism replay, clone isolation, runtime bounds and performance budgets | Integration | Ready | ADR-0007 |
| 017 | EffectValidator — Silence before destroy on one target (`E_FX_OP`) — added 2026-11-04, DD-X21 | Logic | Ready | ADR-0007 |

GDD AC coverage: AC-01 → 005; AC-02/03/04/06 → 003; AC-05/07 → 004; AC-08/09/39 → 006; AC-13/14/23/24 → 007; AC-17/18/22 → 008; AC-19/20/21/46 → 009; AC-10/11/12 → 010; AC-15/43/44 → 011; AC-26/27/28/29 → 012; AC-30/31/32 → 013; AC-33/34/35 → 014; AC-16/25/36/45 → 015; AC-37/38/40/42 → 016; AC-41 → 002; AC-47 → 017 (2026-11-04, DD-X21). All 47 covered. Story 009 also takes match-rules AC-46 and its `silence` primitive change (2026-11-04, DD-X21). Dependency order: 001 (spike, first) → 002, 003 → 004 → 005 → 006 → 007 ⇄ 008 → 009, 010, 011 → 012 → 013; 014 → 015 (after 002, 008, 009) → 016 last.

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
