# Epic: Card Database

> **Layer**: Foundation
> **GDD**: design/gdd/card-database.md (Overview, Detailed Rules CR-1..CR-9, Formulas, Acceptance Criteria)
> **Architecture Module**: `CardDatabase` + `DataLoader` + `ValidationReport` + `config()` (`src/core/data/`)
> **Control Manifest**: Foundation Layer Rules (Manifest Version 2026-11-03)
> **Build Order**: 3 of 14 — plan E1 (Foundation), ADR-0002
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories card-database`

## Overview

Build the game's single reader of `assets/data/*.json`. `DataLoader` discovers files from the code-owned `FILE_MANIFEST`, parses with `JSON.new().parse()`, runs the nine CR-5 validation stages with the closed code set and the injected validator map (`{effects, ai_profile, unlock, treasure, configs{}}` — a missing validator is `E_DELEGATED`), then freezes the snapshot at stage 9 (`make_read_only`, id-ascending lists) and fingerprints it into `data_version` (first 16 hex of SHA-256 over the canonical serialisation). `CardDatabase` serves the CR-6 queries and `config(name)` bodies as pure reads; a Failed load has no main menu, only the `data_error` screen. It is Foundation because thirteen systems read the same ~200 records and nothing else may parse JSON (DD-T01); the MVP batch (DD-H06) and the headless `tools/content/validate.gd` command both load through it.

## Scope (MVP)

- `FILE_MANIFEST` rows for the DD-T01 files (card sets, heroes, hero_powers, bosses, treasures, bundles, per-system config files) with `SCHEMA_VERSION_CURRENT = 1`
- Nine-stage pipeline, `ValidationReport`, state machine `Unloaded/Loading/Ready/Failed/Reloading`, `reload()` in debug only
- CR-6 queries (`card`, `hero`, `hero_power`, `boss`, `treasure`, `bundle`, `has`, `cards_by_*`, `collectible_pool`, `bundle_pool`, `treasure_pool`, `bosses_in_band`, `heroes`, `config`, `data_version`, `report`)
- Load budget `data_load_budget_ms` (200) and `data_memory_budget_mb` (4) measured in a test
- `export_presets.cfg` `include_filter="assets/data/*.json"`; smoke check asserts non-empty `data_version()` in an exported build
- Accept-all validator stubs in `tests/helpers/` until Card Effects / Boss AI / Treasures / Meta land theirs

Out of scope: JSON Schema files per data file beyond the MVP set ("Can defer", ADR-0002); offline migration tooling for a future `schema_version`.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0002: Data format, effect schema/DSL and `config()` loading | JSON under `assets/data/` with `schema_version`; one `CardDatabase` through `DataLoader` from `FILE_MANIFEST`; nine-stage validation with injected static validators; frozen snapshot; SHA-256 `data_version`; `config(name)`; headless validate exit contract | HIGH (GDScript 4.5–4.7 generally; APIs used are pre-4.4 LOW, verified by tests) |
| ADR-0001: Rules / Presentation Split | Only `src/core/**` touches `FileAccess`; `CardDatabase` is composed by `Boot` and injected | HIGH |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-card-database-001 | CR-1: the Card Database is the only parser of assets/data/*.json; definition files {schema_version, records[]} and config files {schema_version, config{}} served via config(name) | ADR-0002 ✅ |
| TR-card-database-002 | CR-3, CR-5: nine-stage load pipeline with delegated validators injected at composition (effects, ai_profile, unlock, treasure tags, one per config file); a Failed load has no main menu (CR-8) | ADR-0002 ✅ (also ADR-0007, 0011) |
| TR-card-database-003 | CR-6: queries are pure reads on a frozen snapshot, results id-ascending (seeded draws depend on it) | ADR-0002 ✅ |
| TR-card-database-004 | CR-9: data_version = first 16 hex of SHA-256 over the canonical serialisation of every file, stable across machines | ADR-0002 ✅ |
| TR-card-database-005 | Formulas: Unloaded to Ready within data_load_budget_ms (200), snapshot within data_memory_budget_mb (4), synchronous at boot | ADR-0002 ✅ |
| TR-design-decisions-002 (carried) | DD-T01: all definitions are JSON under assets/data/ with snake_case keys and schema_version; the profile is user://profile.json | ADR-0002 ✅ (profile half: ADR-0004, Meta Progression epic) |

Requirements covered by Accepted ADRs: 6 / 6. Untraced Requirements: None.

## Gate Entry Conditions Carried

- None named directly. Enables **condition 5** (first playable needs the War starter deck and one band-1 boss loaded through this module) and **condition 1** (the DD-H06 batch validates here).

## Definition of Done

- Every story implemented, reviewed and closed with `/story-done`
- Every acceptance criterion of design/gdd/card-database.md verified
- `data_version` is identical on Linux CI and the owner's Windows machine for the same files
- Logic and Integration stories have passing tests in the test root
- Visual/Feel and UI stories have retained screenshots in `production/qa/evidence/` (a lead sign-off too for Visual/Feel)
