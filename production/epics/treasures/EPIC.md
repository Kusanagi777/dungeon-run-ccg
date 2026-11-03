# Epic: Treasures

> **Layer**: Feature
> **GDD**: design/gdd/treasures.md (Overview, Detailed Rules T2–T7, Formulas F2, F5, Edge Cases, Dependencies, Acceptance Criteria)
> **Architecture Module**: `Treasures` + `HookInstaller` + `TreasureValidator` (`src/gameplay/treasures/`)
> **Control Manifest**: Feature Layer Rules (Manifest Version 2026-11-03); the registry it installs into is Core (ADR-0005)
> **Build Order**: 10 of 14 — plan E6, ADR-0005
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories treasures`

## Overview

Make passive, run-long rule changes real. A treasure is a `TreasureDef` whose `effects[]` use the hook-hosted triggers of the Card Effects DSL; at every match start Run Structure hands `Treasures.installers_for(treasure_ids, treasure_state)` the picked ids in pick order and gets one pure, idempotent `HookInstaller` per treasure, which `RulesEngine.start` installs into the match's own `HookRegistry` — treasures first in pick order, the boss passive (`passive_installer(boss_def)`, side `"boss"`) last. Nothing is applied at pick time and nothing survives the match except the id list plus `collect_state(hooks, result)`, which is what keeps save/resume and restart idempotent. `pool(unlocked_keys, exclude_ids)` is the single membership predicate Reward Draft snapshots. This retires TD-009 — the prototype's global, singleton-backed `ModifierManager` — with a per-match, owner-scoped chain that holds no Node and no back-reference.

## Scope (MVP)

- `installers_for` (duplicate id → first kept + `run_warning{duplicate_treasure}`; unknown `treasure_state.schema_version` → reset), `collect_state` (v1 `{schema_version: 1, by_treasure: {}}`), `pool`, `passive_installer`
- `TreasureValidator` (T7) injected at Card Database stage 7 (`treasure` key)
- The 10 MVP treasures' definitions validated end to end (authored under Content)
- F5 performance: a 12-entry fold under 0.05 ms, three installed treasures under 2 ms per match, no allocation in the fold

Out of scope: the 10 treasures beyond the MVP pool and unlock-gated treasures (Content / Meta Progression, deferred list).

## Salvage from the archived prototype (`prototypes/hearthstone-clone-2026-01/`, never imported)

- `scripts/modifier_registry.gd`, `scripts/modifier.gd`, `scripts/modifier_display.gd` — prior art only (`docs/architecture/modifier-hook-chain.md`, superseded by ADR-0005): global singleton, `Node`-typed hooks, `priority` ordering with undefined ties and back-references are all contradicted by T2 and must not be copied

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0005: Owner-scoped hook registry (supersedes `modifier-hook-chain.md`) | Per-match `HookRegistry`; `HookEntry` plain data with `side`; installation order only; trigger hooks synchronous steps, value hooks folds clamped once by the engine; duplicates skipped with `hook_install_skipped`; `Treasures.pool()` single predicate; `treasure_state` read only in `installers_for`, written only in `collect_state` | LOW (APIs) / HIGH (language) |
| ADR-0007: Effect Resolver / Validator Boundary | Hook effects are DSL effects evaluated by the resolver's `apply_value_hook` / `run_hook_effect` | HIGH by version; APIs LOW |
| ADR-0002: Data format and `config()` loading | `TreasureDef` records; `treasure` validator at stage 7b; `config("treasures_balance")` | HIGH / LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-treasures-001 | T2: HookRegistry per match on MatchState.hooks: ordered HookEntry {host_kind, host_id, side, effect_id, effect} per hook point; installation order only; owner-scoped by side; no autoload, no back-reference | ADR-0005 ✅ |
| TR-treasures-002 | T3: installers_for(treasure_ids) -> HookInstaller[] pure and idempotent; duplicate host skipped with hook_install_skipped | ADR-0005 ✅ |
| TR-treasures-003 | T4, T6: collect_state(hooks, match_result) -> Dictionary after match_ended; pool(unlocked_keys, exclude_ids) membership predicate, id-ascending | ADR-0005 ✅ |
| TR-treasures-004 | F5: 12-entry fold under 0.05 ms; three installed treasures add under 2 ms per match; no allocation in the fold | ADR-0005 ✅ |
| TR-systems-index-003 (carried, shared with Reward Draft) | Circular Dependencies: Treasures <-> Reward Draft - Treasures owns definitions and the chain; Reward Draft reads the pool and the run writes treasure_granted | ADR-0005 ✅ |

Requirements covered by Accepted ADRs: 5 / 5. Untraced Requirements: None.

## Gate Entry Conditions Carried

- None named directly. Carries the TD-009 retirement (`TR-tech-debt-001` half) that the Technical Setup gate closed against ADR-0005.

## Definition of Done

- Every story implemented, reviewed and closed with `/story-done`
- Every acceptance criterion of design/gdd/treasures.md verified (30 criteria lines)
- `grep` proves no `src/gameplay/treasures/**` file references `Node`, an autoload or `Boot`
- Logic and Integration stories have passing tests in the test root
- Visual/Feel and UI stories have retained screenshots in `production/qa/evidence/` (a lead sign-off too for Visual/Feel)
