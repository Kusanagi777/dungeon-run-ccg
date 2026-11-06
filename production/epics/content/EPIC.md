# Epic: Content (MVP batch)

> **Layer**: Feature (data)
> **GDD**: design/gdd/content.md (Overview, Detailed Rules CN-1..CN-6 batch pipeline, the MVP batch tables, C11 archetype rows, Acceptance Criteria) · design/gdd/heroes.md (War), design/gdd/treasures.md (v1 pool), design/gdd/reward-draft.md (bundle themes), design/gdd/boss-ai.md (profiles)
> **Architecture Module**: `assets/data/*.json` + `tools/content/validate.gd` (no runtime module of its own)
> **Control Manifest**: Foundation Layer Rules for data (`data-files.md` governs `assets/data/**/*.json`); Manifest Version 2026-11-03
> **Build Order**: 14 of 14 — plan E9; its first batch (War starter + one band-1 boss) is pulled forward into sprints 1–2 by the first playable
> **Status**: Ready
> **Stories**: 10 stories — see Stories below (story 010 added 2026-11-04, DD-X20)

## Overview

Author the data the MVP plays: per DD-H06, War only, five bosses (3 band 1 / 1 band 2 / 1 band 3) with a passive each, ~40 collectible cards (War + Neutral) plus ~10 boss-only cards, 10 treasures and 10 themed bundles, every card text expressible in the Card Effects v1 DSL and naming its C11 archetype row. Content writes no code: Config/Data stories author the JSON from the GDD tables, a batch is done when `tools/content/validate.gd` loads it headless with zero errors and exits 0, and balance comes from `/balance-check` over archived run logs and the Boss AI sim outputs, with `/content-audit` counting planned versus built. Content is the systems index's largest scope risk, so the batch order is explicit: batch 0 is the first playable's minimum (War `HeroDef` + Whetstone + 15-card starter, one band-1 boss deck + passive + profile), then the remaining MVP cards, bosses, treasures and bundles.

## Scope (MVP — DD-H06)

- Batch 0: War hero, hero power, starter deck; one band-1 boss (deck, passive, `ai_profile` override); the per-system config files the Foundation epics read
- Batch 1: the rest of the ~40 collectible cards (War set + Neutral) and ~10 boss-only cards; the remaining four MVP bosses
- Batch 2: 10 treasures (DD-R05 needs 9 distinct per run) and 10 bundles with theme tags covering War's plan tags
- `tools/content/validate.gd` headless command (CN-6.3) and `content_budgets.json` (tooling-only); `/balance-check` inputs wired (CN-6.4)

Out of scope (deferred list — Vertical Slice → Alpha): Decay and Knowledge sets, the remaining 80 cards to 120, bosses 6–16, treasures 11–20, bundles 11–36, hard-band modifiers (Full Vision).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0002: Data format, effect schema/DSL and `config()` loading | JSON under `assets/data/` with `schema_version`, snake_case keys, the effect object schema, the `FILE_MANIFEST`, the headless validate exit contract | HIGH (general) / LOW (APIs) |
| ADR-0003: Seeded RNG Service and Event Log | Archived run logs (`user://logs/`) and sim outputs are the `/balance-check` inputs | HIGH / NOT SOURCEABLE |
| ADR-0007: Effect Resolver / Validator Boundary | Every authored `effects[]` must pass `validate_effects` with the closed `E_FX_*` set | HIGH by version; APIs LOW |
| ADR-0006: Boss AI Planner Threading | `ai_profiles.json` default + archetype + band + boss override for the MVP bosses | HIGH / NOT SOURCEABLE |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-content-001 | CN-6: every batch loads with zero errors through a headless validate command (tools/content/validate.gd) that prints the report and exits non-zero; content_budgets.json is tooling-only | ADR-0002 ✅ |
| TR-content-002 | CN-6.4: archived run logs and sim outputs are the inputs of /balance-check | ADR-0003 ✅ |

Requirements covered by Accepted ADRs: 2 / 2. Untraced Requirements: None.

## Gate Entry Conditions Carried

- **Condition 1**: MVP systems and content only (DD-H06 cut); everything beyond is on the deferred list in `production/epics/index.md`.
- **Condition 5**: batch 0 is a sprint-1 deliverable for the first playable.
- **Condition 6**: the five hardest DSL effects spiked in the Card Effects epic are chosen from this epic's MVP card list.

## Definition of Done

- Every story implemented, reviewed and closed with `/story-done`
- Every acceptance criterion of design/gdd/content.md for the MVP batch verified (21 criteria lines)
- `tools/content/validate.gd` exits 0 on the full MVP set; `/content-audit` reports planned = built for DD-H06 counts; `/balance-check` has run once over sim output for all five bosses
- Config/Data stories carry a smoke-check pass in `production/qa/smoke-[date].md`
- Logic and Integration stories have passing tests in the test root
- Visual/Feel and UI stories have retained screenshots in `production/qa/evidence/` (a lead sign-off too for Visual/Feel)

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Batch 0 — first-playable data set (War starter, The Torchbearer, every DD-T01 file) | Config/Data | Ready | ADR-0002, ADR-0007, ADR-0006 |
| 002 | MVP-1 — complete the War set (25 cards) | Config/Data | Ready | ADR-0002, ADR-0007 |
| 003 | MVP-1 — band-1 bosses The Rat King and The Gatekeeper (+ `boss_rat`, Smite or Mend) | Config/Data | Ready | ADR-0002, ADR-0006, ADR-0007 |
| 004 | MVP-1 — The Rot Warden and The Hollow King (+ `decay_husk`) | Config/Data | Ready | ADR-0002, ADR-0006, ADR-0007 |
| 005 | MVP-1 — the 10 MVP bundles | Config/Data | Ready | ADR-0002 |
| 006 | MVP-1 — the 10 MVP treasures | Config/Data | Ready | ADR-0002, ADR-0007 |
| 007 | `tools/content/validate.gd` headless command, exit contract and `content_budgets` validator | Logic | Ready | ADR-0002 |
| 008 | Content checks F1–F5 in the validate command | Logic | Ready | ADR-0002 |
| 009 | MVP-1 batch close — validate exits 0, `/content-audit`, `/balance-check` | Config/Data | Ready | ADR-0002, ADR-0003, ADR-0006 |
| 010 | Gravekeeper returns to the boss decks (`add_counter` `op_values` row, `neutral_gravekeeper`, four deck swaps) — added 2026-11-04, DD-X20 | Config/Data | Ready | ADR-0002, ADR-0006, ADR-0007 |

Review: QL-STORY-READY skipped — Lean mode.
