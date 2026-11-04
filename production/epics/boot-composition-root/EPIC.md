# Epic: Boot & Composition Root

> **Layer**: Foundation
> **GDD**: — (no system GDD; `docs/architecture/architecture.md` §Dependency injection and the composition root, §Data Flow 5 Initialisation order, §Module Ownership Foundation rows `Boot`, `SettingsBus`)
> **Architecture Module**: `Boot` (`src/core/boot.gd`, the one autoload) + `Services` bag + `SettingsBus` + the `@abstract MetaApi` seam with the MVP `MetaStub`
> **Control Manifest**: Foundation Layer Rules (Manifest Version 2026-11-04)
> **Build Order**: 1 of 14 — plan E1 (Foundation), riskiest-first per ADR order 0001
> **Status**: Ready
> **Stories**: 8 (001-007 created 2026-11-03 by `/create-stories boot-composition-root`; see the Stories table below)

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | SettingsBus | Logic | Ready | ADR-0004, ADR-0011 |
| 002 | MetaApi abstract seam | Logic | Ready | ADR-0004, ADR-0011, ADR-0001 |
| 003 | MetaStub — the MVP MetaApi implementation | Logic | Ready | ADR-0011, ADR-0004 |
| 004 | Boot — the one autoload and lazy composition root | Integration | Ready | ADR-0001, ADR-0011 |
| 005 | Grep gates G1–G6 and the per-file parse check in CI | Integration | Ready | ADR-0001 |
| 006 | main.tscn composition entry and the RunShell stub | UI | Ready | ADR-0001, ADR-0011, ADR-0010 |
| 007 | Boot responsibilities list for the control manifest (gate condition 12) | Config/Data | Complete (manifest update pending) | ADR-0001 |
| 008 | Windows Desktop export in CI, uploaded as an artifact (gate condition 8) | Config/Data | Complete (CI run pending) | ADR-0010, ADR-0001 |

Order: 001 → 002 → 003 → 004 → {005, 006} → 007. Cross-epic: 003 and 004 need the `card-database` epic's `CardDatabase` / `ValidationReport` and `profile_defaults.json`; until then their tests inject a `card_database` override. QL-STORY-READY skipped — Lean mode.

## Overview

Stand up the one autoload the production tree allows: a lazy composition root whose `_ready()` does nothing and whose idempotent `boot(overrides) -> BootResult` constructs `CardDatabase`, the profile/meta service (`MetaStub` for the MVP, through the `@abstract MetaApi` base) and `SettingsBus`, then hands them down by argument to scene roots and `*_debug_loader.gd` only. The epic also lands the ADR-0001 enforcement that keeps rules code out of Nodes and singletons: the G1–G5 grep gates (RefCounted rules tier, `project.godot [autoload]` holds exactly `Boot`, no `Boot.services()` below scene roots, `queue_free` only under `src/ui/`), the per-file `godot-parse-check.gd` rule, `main.tscn` as the composition entry, and `tests/helpers/` construction without `Boot`. It is first because every other epic injects through it and because TD-001 (the prototype's global singleton) regrows here if nothing guards it.

## Scope (MVP)

- `Boot.boot(overrides)`, `services()`, `BootResult`, `Services {card_database, profile_store, meta: MetaApi, settings_bus}` (ADR-0001 Decision; control manifest Foundation Required Patterns)
- `@abstract class_name MetaApi` with the full M1.3 surface and `MetaStub` (in-memory defaults from `config("profile_defaults")`) so `Boot.boot({meta: MetaStub.new(...)})` works for fixtures (ADR-0004, ADR-0011; TR-systems-index-001)
- `SettingsBus` (`settings_changed(key, value)`) — a `RefCounted` with one signal
- `src/scenes/main.tscn` calling `Boot.boot()` then opening `RunShell` (stub screen until Run UI lands)
- Grep gates G1–G5 wired into CI as `tools/lint/` checks (ADR-0001 G2b erratum: look-around-free deny list, rg 14.1.0)
- Boot responsibilities listed for the control manifest's next revision (gate condition 12)

Out of scope (deferred list in `production/epics/index.md`): `MetaFacade` wiring (the one-line switch stays a TODO against the Meta Progression epic), input-binding application to `InputMap` after profile load (Alpha, TR-accessibility-requirements-001).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0001: Rules / Presentation Split | `src/gameplay/`, `src/ai/`, `src/core/` are `RefCounted` and constructor-injected; `src/ui/` is display-only over commands/events/queries; `Boot` is the one autoload and a lazy composition root, grep-gated | HIGH (4.5–4.7 GDScript features; G2b erratum applied 2026-11-03) |
| ADR-0004: Save Format and Atomic Profile Write | Fixes the `MetaApi` abstract base and the `MetaStub` the MVP ships (persistence itself is the Meta Progression epic) | MEDIUM / NOT SOURCEABLE (rename atomicity; Windows gated) |
| ADR-0011: Run UI Shell Pattern and the Meta Stub Injection Seam | `Boot.boot(overrides)` places one `MetaApi` implementation in `Services.meta`; MVP ships `MetaStub` | HIGH (UI 4.5–4.7) |

## GDD Requirements

Cross-cutting requirements carried by this epic (no system-slugged TR-ID names Boot; these are the registry rows the composition root exists to satisfy):

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-design-decisions-001 | DD-T02: match and run rules are RefCounted GDScript with no Node references; the UI subscribes to events and issues commands | ADR-0001 ✅ (also ADR-0006) |
| TR-tech-debt-001 | TD-001..012: the production tree rules out each prototype root cause (architecture.md tech-debt retirement mapping) | ADR-0001 ✅ (also ADR-0002, 0005, 0010) |
| TR-systems-index-001 | Circular Dependencies: Run Structure <-> Meta — Meta exposes M1.3, Run Structure owns R1; the MVP ships a Meta stub | ADR-0001 ✅ (also ADR-0004, 0011) |

Requirements covered by Accepted ADRs: 3 / 3. Untraced Requirements: None.

## Gate Entry Conditions Carried

- **Condition 2** (epic order follows ADR order, riskiest first): this epic is ADR-0001's, first in the order.
- **Condition 12**: `Boot` responsibilities listed in the control manifest on its next revision — the last story of this epic drafts that list for `/create-control-manifest update`.
  - **Handed over 2026-11-04** (story 007): `production/epics/boot-composition-root/boot-responsibilities.md` — "Boot does" / "Boot never does" tables matched to `src/core/boot.gd` at trunk `c9cd55b`, with proposed Foundation Required / Forbidden rows. Open with the technical-director: the `/create-control-manifest update` run (separate approval); the manifest stays at Manifest Version 2026-11-03 until it runs, and condition 12 closes when the revised manifest carries the rows.

## Definition of Done

- Every story implemented, reviewed and closed with `/story-done`
- ADR-0001 gates G1–G5 pass in CI; `project.godot [autoload]` contains exactly `Boot`; every file under `src/gameplay/**`, `src/ai/**`, `src/core/**` passes `.claude/scripts/godot-parse-check.gd` alone
- `tests/integration/boot/` proves `boot()` idempotence, `BootResult` on a Failed data load, and `boot({meta: MetaStub.new(...)})` override
- Logic and Integration stories have passing tests in the test root
- Visual/Feel and UI stories have retained screenshots in `production/qa/evidence/` (a lead sign-off too for Visual/Feel)
