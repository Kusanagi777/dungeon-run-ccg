# Epic: Treasures

> **Layer**: Feature
> **GDD**: design/gdd/treasures.md (Overview, Detailed Rules T2–T7, Formulas F2, F5, Edge Cases, Dependencies, Acceptance Criteria)
> **Architecture Module**: `Treasures` + `HookInstaller` + `TreasureValidator` (`src/gameplay/treasures/`)
> **Control Manifest**: Feature Layer Rules (Manifest Version 2026-11-03); the registry it installs into is Core (ADR-0005)
> **Build Order**: 10 of 14 — plan E6, ADR-0005
> **Status**: Ready
> **Stories**: 13 stories (2026-11-04; 12 Ready, 1 Blocked) — see Stories below

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

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [Installers — `installers_for`, `passive_installer`, `collect_state`](story-001-installers-passive-and-collect-state.md) | Logic | Ready | ADR-0005 |
| 002 | [Live match — installation order, duplicate skip, no back-reference, clone](story-002-installation-order-duplicates-and-clone.md) | Integration | Ready | ADR-0005, ADR-0007 |
| 003 | [`TreasureValidator` — T7 codes at stage 7b, registered at Boot](story-003-treasure-validator-at-stage-7b.md) | Logic | Complete | ADR-0005, ADR-0002 |
| 004 | [F5 hook-chain cost bound and the Node-free treasures tree](story-004-hook-chain-cost-bound-and-purity.md) | Logic | Ready | ADR-0005 |
| 005 | [Cost-fold treasures — Worn Signet, Vanguard's Banner, stacking](story-005-cost-fold-treasures.md) | Integration | Ready | ADR-0005, ADR-0007 |
| 006 | [Hand-size and attack folds — Bottomless Satchel, Twin Grip](story-006-hand-size-and-attack-fold-treasures.md) | Integration | Ready | ADR-0005, ADR-0007 |
| 007 | [Trigger-hook treasures — Crown, Candle, Iron Constitution, Cloak](story-007-trigger-hook-treasures.md) | Integration | Ready | ADR-0005, ADR-0007 |
| 008 | [Aura treasures — Whetstone Wheel, Stampede Horn](story-008-aura-treasures.md) | Integration | Ready | ADR-0007, ADR-0005 |
| 009 | [`pool(unlocked_keys, exclude_ids)` — the one membership predicate](story-009-pool-membership-predicate.md) | Logic | Ready | ADR-0005 |
| 010 | [`Treasures.validate_config` and data-driven magnitudes](story-010-treasures-balance-validator-and-data-driven-magnitudes.md) | Logic | Ready | ADR-0002, ADR-0005 |
| 011 | [Restart and resume re-install — the caller's `run_warning`s](story-011-restart-and-resume-reinstall.md) | Integration | Ready | ADR-0005 |
| 012 | [Non-MVP spot checks — Grave Tithe, Living Armory, Focusing Prism, Mending Charm](story-012-non-mvp-treasure-spot-checks.md) | Integration | Ready | ADR-0005, ADR-0007 |
| 013 | [`W_TR_POWER` — F1 power-band warning](story-013-power-band-warning.md) | Logic | Blocked | ADR-0005 |

Blocked: 013 on a treasures GDD gap (T7 asks for a load-time F1 check; F1 is never computed and has no effect→value mapping) — not on an ADR. Scheduling: 011 waits on the Run Structure epic's `begin_match` / resume stories (none yet). Cross-epic unblocks: 001 → card-effects 014 (its "`HookInstaller` / `passive_installer`" need) and the First Playable boss passive (all three band-1 bosses carry one); 003 → content 006 and Boot's pending `treasure` record validator; 010 → Boot's pending `treasures_balance` config validator.

GDD acceptance-criteria coverage (30 lines): AC-1, AC-4, AC-10 → 001 (caller halves of AC-4 / AC-10 → 011) · AC-2, AC-3, AC-6, AC-7 → 002 · AC-5 → 003 · AC-8, AC-16, AC-17 → 005 · AC-9 → 011 · AC-11, AC-12 → 009 · AC-13, AC-19, AC-23 → 006 · AC-14 → 004 · AC-15, AC-18, AC-20, AC-21 → 007 · AC-22, AC-24 → 008 · AC-25–AC-28 → 012 · AC-29 → 013 · AC-30 → 010 (first half), 013 (second half). Story creation: QL-STORY-READY skipped — Lean mode.

## Definition of Done

- Every story implemented, reviewed and closed with `/story-done`
- Every acceptance criterion of design/gdd/treasures.md verified (30 criteria lines)
- `grep` proves no `src/gameplay/treasures/**` file references `Node`, an autoload or `Boot`
- Logic and Integration stories have passing tests in the test root
- Visual/Feel and UI stories have retained screenshots in `production/qa/evidence/` (a lead sign-off too for Visual/Feel)
