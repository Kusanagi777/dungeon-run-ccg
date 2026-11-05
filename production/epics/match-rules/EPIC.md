# Epic: Match Rules

> **Layer**: Core
> **GDD**: design/gdd/match-rules.md (`full` section set per `system_overrides`; Overview, Detailed Rules C1–C3, C6, C10, C14, C15, Interactions hook/trigger tables, Formulas, Edge Cases, Input Responsiveness, Acceptance Criteria)
> **Architecture Module**: `RulesEngine` + `MatchState` + records + primitive API + `HookRegistry` / `HookEntry` (`src/gameplay/match/`)
> **Control Manifest**: Core Layer Rules (Manifest Version 2026-11-03)
> **Build Order**: 4 of 14 — plan E2, ADR-0007 / ADR-0005 / ADR-0001
> **Status**: Ready
> **Stories**: 18 (see Stories table below) — created 2026-11-03 by `/create-stories match-rules`

## Overview

Build the referee of one duel as a pure, engine-free `RulesEngine` over a plain `MatchState` (C1): the phase machine, mana crystals, draw, hand and board limits, playing minions, spells and weapons, attacking, damage and armour math, the fifteen v1 keywords (DD-M09), death and trigger ordering, hand burn, fatigue and the win/loss decision. Callers send the seven commands (`mulligan`, `play_card`, `attack`, `use_hero_power`, `choose`, `end_turn`, `concede`) through `submit(command) -> CommandResult` and get typed rejections, never errors; the 24 primitives are the only mutators and each emits one event. The engine fires the 15 trigger points and folds the 12 value hook points through the per-match `HookRegistry` (fold-then-clamp), runs the C10 loop under `RESOLUTION_STEP_CAP`, and never decides what a card does — that is the Card Effects resolver bound at `start`. `MatchConfig` is its only input, `clone()` deep-copies state, hooks and a detached scratch log for the Boss AI, and `MatchResult` carries the C15 event vocabulary (DD-X04). Seven systems depend on it; it is the project's first bottleneck and the first thing the first playable needs.

## Scope (MVP)

- `MatchConfig`, `MatchState`, `PlayerState`, `Character`, `Enchantment`, `Weapon`, `CardInstance`, `CommandResult`, `MatchResult` (field names per `tests/helpers/match_factory.gd`)
- `RulesEngine._init(db, rules_config, resolver)`, `start`, `submit`, `legal_commands`, `phase`, `pending_choice`, `result`, `state_snapshot`, `clone`
- Primitive API (24), 15 trigger points, 12 hook points, `HookRegistry.install/entries/fold/run_triggers/copy` with installation-order semantics (ADR-0005)
- Keywords: Taunt, Divine Shield, Charge, Rush, Windfury, Stealth and the rest of DD-M09's fifteen
- `ENGINE_BUSY` on re-entrant submit; `submit()` ≤ 5 ms, `legal_commands()` ≤ 2 ms measured headless
- `tests/helpers/` swap markers `TODO(E1/E2)`: `MatchFactory` gets a real `HookRegistry` where it used `[]`

Out of scope: nothing in match-rules is deferred; hard-band modifiers (Full Vision) are a Treasures / Content matter.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0007: Effect Resolver / Validator Boundary | `RulesEngine` owns `MatchState`, phase machine, `win_loss_check`, the C10 loop and the 24 primitives; `resolver.bind(...)` at `start`, `unbind()` at `Ended`; `clone()` binds a fresh resolver with no installers | HIGH by version; APIs pre-4.3 (LOW) |
| ADR-0005: Owner-scoped hook registry | `HookRegistry` on `MatchState.hooks`, `HookEntry {host_kind, host_id, side, effect_id, effect, state}`, installation order only, value hooks fold-then-clamp, copied by value in `clone()` | LOW (APIs) / HIGH (language) |
| ADR-0001: Rules / Presentation Split | Rules tier is `RefCounted`, headless, injected; the single command channel | HIGH |
| ADR-0003: Seeded RNG Service and Event Log | One event per mutation after the mutation with `cause_seq`; `rng_match` injected via `MatchConfig`; the engine never seeds | HIGH / NOT SOURCEABLE |
| ADR-0006: Boss AI Planner Threading | `clone()` and `submit()` are the only AI surface; scratch log detached | HIGH / NOT SOURCEABLE |
| ADR-0008: Match Driver Ownership | `MatchDriver` constructs the engine from `MatchConfig`; concede-while-planning rule | HIGH by version |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-match-rules-001 | C1: RulesEngine owns one MatchState; plain data, no Node references; derived values never stored | ADR-0001 ✅ |
| TR-match-rules-002 | C2: submit(command) -> CommandResult, legal_commands(); illegal moves are data (closed rejection code set); synchronous; re-entrant submit -> ENGINE_BUSY | ADR-0001 ✅ (also ADR-0006, 0008) |
| TR-match-rules-003 | C2, C3: MatchState.clone() deep copy carrying the HookRegistry, a detached scratch log and a copied rng_match state; the engine never seeds a stream | ADR-0005 ✅ (also ADR-0006) |
| TR-match-rules-004 | C3: MatchConfig {floor, band, rng_match, rng_ai, log, player{hero_def_id, deck, hook_installers}, boss{boss_def_id, deck, health, hook_installers, ai_id}} is the only input | ADR-0003 ✅ |
| TR-match-rules-005 | Interactions: the primitive API (draw, apply_damage, ... discard) is the only way match state mutates; each call emits one event | ADR-0001 ✅ (also ADR-0007) |
| TR-match-rules-006 | Interactions, C10: 15 trigger points fired by the engine; 12 hook points with fold-then-clamp semantics; C10 resolution loop with RESOLUTION_STEP_CAP | ADR-0007 ✅ (also ADR-0005) |
| TR-match-rules-007 | C14, C15: MatchResult {result win/loss/fault, winner, reason, floor, turns, turns_per_side, stats, final health}; C15 is the authoritative event vocabulary (DD-X04) | ADR-0003 ✅ |
| TR-match-rules-008 | Input Responsiveness: submit() within 5 ms worst case, legal_commands() within 2 ms | ADR-0007 ✅ (also ADR-0009) |

Requirements covered by Accepted ADRs: 8 / 8. Untraced Requirements: None.

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Match data model, derived values and rules config | Logic | Ready | ADR-0001 |
| 002 | HookRegistry: install order, fold, copy | Logic | Ready | ADR-0005 |
| 003 | Match setup: bind, heroes, shuffle, starting hands | Logic | Ready | ADR-0007 |
| 004 | Command channel, rejection codes and mulligan | Logic | Ready | ADR-0001 |
| 005 | Turn structure, mana curve and turn cap | Logic | Ready | ADR-0007 |
| 006 | Primitive API, draw, burn and fatigue | Logic | Ready | ADR-0007 |
| 007 | Damage, healing and armour pipeline | Logic | Ready | ADR-0005 |
| 008 | Win, loss, concede and MatchResult | Logic | Ready | ADR-0007 |
| 009 | Resolution loop: death check, trigger queue, auras, step cap | Logic | Ready | ADR-0007 |
| 010 | Playing minions, spells, weapons and the hero power | Logic | Ready | ADR-0007 |
| 011 | Effective cost, mana payment and temporary crystals | Logic | Ready | ADR-0005 |
| 012 | Attack legality predicate | Logic | Ready | ADR-0007 |
| 013 | Attack resolution and simultaneous damage | Logic | Ready | ADR-0007 |
| 014 | Windfury, Stealth and Divine Shield in combat | Logic | Ready | ADR-0007 |
| 015 | Freeze, thaw and Silence | Logic | Ready | ADR-0007 |
| 016 | Choice phase and Discover continuation | Logic | Ready | ADR-0007 |
| 017 | clone() sandbox and replay equivalence | Logic | Ready | ADR-0005 |
| 018 | Performance budgets: submit and legal_commands | Logic | Ready | ADR-0007 |
| 019 | Rules engine performance pass | Logic | Ready | ADR-0007 |
| 020 | minion_summoned carries keywords[], match_started carries the starting hero health, one reviewed golden regeneration | Logic | Ready | ADR-0003, ADR-0007, ADR-0001 |

Dependency order: 001, 002 → 003 → 004 → 005 → 006 → 007 → 008 → 009 → 010 → {011, 012, 016} → 012 → 013 → {014, 015} → 017 → 018. All 45 GDD acceptance criteria are covered (AC-41 in 001; AC-40 in 018). AC-46 (destroy then Silence: the Deathrattle fires; added 2026-11-04, DD-X21) is covered by `production/epics/card-effects/story-009-deathrattle-snapshot-counters.md`, which takes the `silence` primitive change. Gate entry condition 3 (N-05) is satisfied by DD-X11 — story 013 cites it. QL-STORY-READY skipped — Lean mode.

## Gate Entry Conditions Carried

- **Condition 3**: owner decision **N-05** (defender-hero weapon damage) is due before the match-rules combat story enters a sprint — `/story-readiness` blocks that story until `design/design-decisions.md` carries it.
- **Condition 5**: first playable (one War match vs one band-1 boss) needs this epic's command set and keyword subset complete enough for the War starter deck within sprints 1–2.

## Definition of Done

- Every story implemented, reviewed and closed with `/story-done`
- Every acceptance criterion of design/gdd/match-rules.md verified (45 criteria lines)
- Replay equivalence: the same `MatchConfig` + command sequence yields a byte-identical event log twice
- Logic and Integration stories have passing tests in the test root
- Visual/Feel and UI stories have retained screenshots in `production/qa/evidence/` (a lead sign-off too for Visual/Feel)
