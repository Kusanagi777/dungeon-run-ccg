# Epic: Meta Progression (persistence + stub-to-facade seam)

> **Layer**: Feature (rules half, `src/gameplay/meta/`); the persistence half `ProfileStore` is Foundation code (`src/core/save/`) per architecture.md §System Layer Map
> **GDD**: design/gdd/meta-progression.md (Overview, Detailed Rules M1, M4–M6, M8, M9, Formulas F5, Dependencies, Acceptance Criteria)
> **Architecture Module**: `ProfileStore` + `AtomicFileWriter` + `ProfileLock` + `ProfileMigrations` (`src/core/save/`) · `MetaApi` seam → `MetaStub` (MVP) / `MetaFacade` (deferred) (`src/gameplay/meta/`)
> **Control Manifest**: Foundation Layer Rules for `src/core/save/**`; Feature Layer Rules for `src/gameplay/meta/**` (Manifest Version 2026-11-03)
> **Build Order**: 13 of 14 — plan E8, ADR-0004 / ADR-0011
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories meta-progression`

## Overview

Land the one file that outlives a run and prove the seam that will swap the stub for the real thing. `ProfileStore` owns `user://profile.json` and its companions: the M4 atomic write (`.tmp` → flush → old to `.bak` → rename `.tmp` into place; `E_IO` leaves the previous files intact), the M5 load order (`profile.json` → `.bak` → fresh, corrupt copies kept, newer schema → `ReadOnly`, tamper tolerance with clamping and `profile_repaired` logging), the M6 `profile.lock` heartbeat (second instance `ReadOnly`, mutators `E_READONLY`), pure `migrate_v{k}_to_v{k+1}` functions, and the M9 settings record applied through `SettingsBus`. The MVP keeps `MetaStub` as `Services.meta` for the rules half (unlock evaluation, stats fold, run-log pages, notifications — the `MetaFacade`, deferred to the Vertical Slice), so this epic's job is the storage layer, the settings path, and a one-line `Boot` switch test that proves `MetaFacade` can replace `MetaStub` without touching a caller. `DirAccess.rename_absolute` atomicity is NOT SOURCEABLE and observed only on Linux, so the Windows atomic-write test gates closure.

## Scope (MVP)

- `AtomicFileWriter`, `ProfileStore` with `write_seq` and the `ReadOnly` state, `ProfileLock`, `ProfileMigrations` (v1 only), the M1.2 profile shape with `settings{}` and the bindings map `{}` placeholder (engine defaults)
- Settings persistence (`anim_speed`, `reduce_motion`, `telegraph_mode`, `action_delay_ms`) applied via `settings_changed{key, value}`; defaults from `config("profile_defaults")`
- `tests/unit/meta_progression/atomic_write_platform_test.gd` (ADR-0004 Probe B shape) run on Linux CI and on the owner's Windows machine
- `MetaApi` conformance test run against both `MetaStub` and a skeletal `MetaFacade` (persistence calls only) to prove the seam
- F5 / M4.3: profile within `max_profile_bytes` (2 MB); synchronous save within `max_save_ms` (50) at `run_log_cap`

Out of scope (deferred list — Vertical Slice / Alpha): `MetaFacade` rules half (`UnlockEvaluator`, `StatsFold`, 200-run archive, run-log pages, per-hero stats, unlock toasts, D-03 any-hero treasure key semantics), input-binding storage and `InputMap` application (TR-accessibility-requirements-001, ADR-0004 addendum).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0004: Save Format and Atomic Profile Write | One `user://profile.json`, M1.2 shape, M1.3 API, tmp → bak → rename, pure migrations, load order and corrupt copies, lock file, `@abstract MetaApi` + `MetaStub`; addendum: bindings in the profile settings record | **MEDIUM / NOT SOURCEABLE** (`rename_absolute` atomicity and fsync; Windows gated) |
| ADR-0011: Run UI Shell Pattern and the Meta Stub Injection Seam | `Boot.boot(overrides)` places one `MetaApi` in `Services.meta`; MVP ships `MetaStub`; the switch to `MetaFacade` is one line in `Boot` | HIGH |
| ADR-0003: Seeded RNG Service and Event Log | RNG snapshot shape stored in the active-run slot; 64-bit values as 16-hex strings | HIGH / NOT SOURCEABLE |
| ADR-0001: Rules / Presentation Split | `src/core/save/` is one of the two openers of `user://` | HIGH |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-meta-progression-001 | M1: one user://profile.json with the M1.2 shape and the M1.3 persistence API (save_active_run, load_active_run, clear_active_run, archive_run, is_hero_unlocked, unlocked_keys, settings, run log pages, notifications) | ADR-0004 ✅ (also ADR-0011) — run-log pages / notifications implemented by `MetaStub` defaults in the MVP |
| TR-meta-progression-002 | M4: atomic write .tmp -> flush -> rename old to .bak -> rename .tmp to profile.json; E_IO leaves the previous files intact; migrations migrate_v{k}_to_v{k+1} as pure functions | ADR-0004 ✅ |
| TR-meta-progression-003 | M5: load order profile.json -> .bak -> fresh; corrupt copies kept; newer schema -> ReadOnly; tamper tolerance with clamping and profile_repaired logging | ADR-0004 ✅ |
| TR-meta-progression-004 | M6: profile.lock heartbeat; a second instance loads ReadOnly, mutators return E_READONLY | ADR-0004 ✅ |
| TR-meta-progression-005 | M9, DD-X07: settings record owned here, defaults from config(profile_defaults), applied via settings_changed{key, value}; includes bindings {action: [InputEvent as Dictionary]} ({} = engine defaults, cancel/Esc never rebindable) applied to InputMap by Boot after the profile loads; the MVP ships an in-memory stub | ADR-0004 ✅ (also ADR-0009, 0011) — bindings half deferred to Alpha |
| TR-meta-progression-006 | F5, M4.3: profile within max_profile_bytes (2 MB); synchronous save within max_save_ms (50) at run_log_cap | ADR-0004 ✅ |
| TR-systems-index-001 (carried, shared with Boot) | Circular Dependencies: Run Structure <-> Meta - Meta exposes M1.3, Run Structure owns R1; the MVP ships a Meta stub | ADR-0004 ✅ (also ADR-0001, 0011) |
| TR-accessibility-requirements-001 (carried, **deferred to Alpha**) | Motor (Standard tier, Alpha): full input remapping for every action except cancel/Esc; bindings persist across restarts; storage decided by the ADR-0004 addendum (bindings map in M9) | ADR-0004 ✅ — on the deferred list; no MVP story |

Requirements covered by Accepted ADRs: 8 / 8. Untraced Requirements: None.

## Gate Entry Conditions Carried

- **Condition 3**: owner decision **D-03** (any-hero treasure unlock key) is due before this epic — it shapes the `unlock` field semantics the `MetaStub` defaults and the deferred `UnlockEvaluator` share.
- **Condition 9**: `atomic_write_platform_test.gd` (ADR-0004) scheduled on Windows **before this epic closes** — technical-director.

## Definition of Done

- Every story implemented, reviewed and closed with `/story-done`
- Every acceptance criterion of design/gdd/meta-progression.md that concerns M1, M4–M6, M9 and F5 verified (30 criteria lines; unlock / run-log rows deferred with the facade)
- The atomic-write test passes on Linux CI and on the owner's Windows machine with the evidence retained in `production/qa/evidence/`
- Logic and Integration stories have passing tests in the test root
- Visual/Feel and UI stories have retained screenshots in `production/qa/evidence/` (a lead sign-off too for Visual/Feel)
