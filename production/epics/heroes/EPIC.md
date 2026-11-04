# Epic: Heroes

> **Layer**: Feature
> **GDD**: design/gdd/heroes.md (Overview, Detailed Rules H-1, H-3, H-7, Acceptance Criteria)
> **Architecture Module**: `Heroes` — thin data access over `CardDatabase` (`src/gameplay/heroes/`)
> **Control Manifest**: Feature Layer Rules (Manifest Version 2026-11-03)
> **Build Order**: 11 of 14 — plan E6, ADR-0002
> **Status**: Ready
> **Stories**: 4 stories (2026-11-04) — see Stories below

## Overview

A hero is pure data: a `HeroDef` in `heroes.json` (name, colour, 30 health, 15-card starter deck, ~25-card set) pointing at a `HeroPowerDef` in `hero_powers.json` whose effect is a `hero_power`-trigger DSL effect, exactly like a spell (DD-M13). The module is the small accessor the run and the UI use — `hero(id)`, `launch_heroes()`, `plan_tags(hero_id)` — with nothing hero-specific in code. The MVP ships **War only** (DD-H06): Whetstone, the War starter deck and the War set; Decay and Knowledge (DD-H01) and the post-v1 unlock heroes (Fortune, Order, Shadow — DD-H02) are data the same accessor serves later. This epic is small and sits with the run-level group because hero select is where it is read; the War records themselves are authored in the Content epic's first batch, which the first playable pulls forward.

## Scope (MVP)

- `Heroes` accessor and its unit tests against `tests/helpers/` factory records
- H-1 / H-3 validation: a hero's starter deck ids exist, are in its set or Neutral, and its hero power validates through `EffectValidator`
- `plan_tags(hero_id)` for Reward Draft's theme weighting
- `is_hero_unlocked` consulted through `MetaApi` (always true for War under the `MetaStub`)

Out of scope (deferred list): Decay and Knowledge data and balance; Fortune / Order / Shadow (post-v1); hero unlock conditions (H-7, Meta Progression facade).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0002: Data format, effect schema/DSL and `config()` loading | `HeroDef` / `HeroPowerDef` records in the `FILE_MANIFEST`; hero powers are effects in the shared schema; nothing hero-specific in code | HIGH (general) / LOW (APIs) |
| ADR-0007: Effect Resolver / Validator Boundary | Hero power effects resolve through the same resolver (heroes H-3) | HIGH by version; APIs LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-heroes-001 | H-1, H-3: heroes are HeroDef data; hero powers are hero_power-trigger effects (DD-M13); nothing hero-specific in code | ADR-0002 ✅ |

Requirements covered by Accepted ADRs: 1 / 1. Untraced Requirements: None.

## Gate Entry Conditions Carried

- **Condition 1**: War hero only (DD-H06).
- **Condition 5**: the first playable is a War match; War's `HeroDef`, Whetstone and starter deck are the first content stories.

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [War hero seated from its `HeroDef` — Whetstone on shipped data](story-001-war-hero-seated-from-herodef.md) | Integration | Ready | ADR-0002, ADR-0007 |
| 002 | [`Heroes` accessor — `hero`, `launch_heroes`, `plan_tags`](story-002-heroes-accessor.md) | Logic | Ready | ADR-0002 |
| 003 | [Heroes F2 plan-card count and F5 signature synergy](story-003-plan-card-and-synergy-checks.md) | Logic | Ready | ADR-0002 |
| 004 | [`Heroes.validate_config` — `heroes_balance.json` validator at Boot](story-004-heroes-balance-config-validator.md) | Logic | Ready | ADR-0002 |

First Playable (sprint 6, one War match against one band-1 boss) path: **001, 002**. Boss-ai story 016 needs both: the War starter deck, and the hero seated with its health and Whetstone from data.

GDD acceptance-criteria coverage (19 lines): AC-1 → 002 · AC-2, AC-4 → content story 008 (Complete: `E_STARTER_CURVE`, `W_SET_SHARE`) · AC-3, AC-5 → 003 · AC-6 → 002 · AC-7, AC-8, AC-19 → 001 · AC-9 to AC-14 (Rot, Insight) → deferred with Decay / Knowledge (DD-H06; resolution already proven on fixture rows by card-effects 011) · AC-15 (cost-0 power still once per turn) → card-effects story 014 AC-33 (row 39 `set 0`) and treasures story 005 (Worn Signet) · AC-16 → data half 002, screen half Run UI epic, `E_HERO_LOCKED` Run Structure epic · AC-17, AC-18 → Run UI / Match UI epics (screenshots). Story creation: QL-STORY-READY skipped — Lean mode.

## Definition of Done

- Every story implemented, reviewed and closed with `/story-done`
- Every acceptance criterion of design/gdd/heroes.md verified for War (19 criteria lines; Decay / Knowledge rows deferred)
- Logic and Integration stories have passing tests in the test root
- Visual/Feel and UI stories have retained screenshots in `production/qa/evidence/` (a lead sign-off too for Visual/Feel)
