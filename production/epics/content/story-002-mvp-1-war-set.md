# Story 002: MVP-1 — complete the War set (25 cards)

> **Epic**: Content (MVP batch)
> **Status**: Complete
> **Layer**: Feature (data)
> **Type**: Config/Data
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-04

## Context

**GDD**: `design/gdd/content.md` (CN-2 War table and curve summary, F1–F3, AC-4/6/9/11) · `design/gdd/heroes.md` (H-5 signature cards, F4 set composition)
**Requirement**: `TR-content-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Data format, effect schema/DSL and `config()` loading; ADR-0007: Effect Resolver / Validator Boundary
**ADR Decision Summary**: Cards are CR-3 `CardDef` rows in `cards_war.json` under the CR-1 envelope, loaded only by `CardDatabase`. Each `effects[]` is plain JSON that the static `EffectValidator.validate_effects` checks with the closed `E_FX_*` set. A text the DSL cannot express is a card-effects GDD change, never code.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (ADR-0002 general) / LOW (APIs)
**Engine Notes**: No engine API touched; JSON numbers arrive as `float`, so author integers without a fractional part.

**Control Manifest Rules (Foundation, data)**:
- Required: `effects[]` are plain JSON with no code references; every read goes through `CardDatabase`.
- Forbidden: never GDScript constants as game data; never rename an id once a story cites it (CN-6 step 9).
- Guardrail: data load ≤ `data_load_budget_ms` 200.

Batch 0 (story 001) shipped the 7 starters and `war_iron_resolve`. This story authors the other 17 War cards in the CN-2 War table (25 in all: 13 M / 6 S / 6 W), among them the H-5 signature cards that story 005's bundles and Hollow King's MVP deck (story 004) reference.

---

## Acceptance Criteria

*From GDD `design/gdd/content.md` (CN-2, AC-4, AC-6, AC-9, AC-11), scoped to this story:*

- [ ] **AC-1 (Records)** GIVEN `cards_war.json`, WHEN loaded, THEN it holds exactly 25 non-token War cards plus the token `war_whetstone_blade`. Each card matches its CN-2 row (id, name, type, cost, stats, keywords, text, rarity, tags), including the signature cards `war_duelists_edge`, `war_pit_champion` and `war_cleave_through`, and the load stays `Ready` with zero errors.
- [ ] **AC-2 (Effects and text — AC-9 data half, AC-11)** GIVEN every War card's `effects[]`, WHEN validated, THEN zero `E_FX_*` errors. Every `text.en` is ≤ 90 characters and follows the CN-6 step 6 style guide, and neither `W_DUP_NAME` nor `W_FX_KEYWORD_MISMATCH` is raised for the War set.
- [ ] **AC-3 (Set balance — AC-4, AC-6)** GIVEN the 25 War cards, WHEN F1 and F2 are evaluated, THEN every type share is within `SET_SHARE[war] ± share_tol` (`heroes_balance.json` / `content_budgets.json`) and the curve matches the CN-2 War summary (avg 3.16 and its buckets). WHEN F3 is evaluated, THEN every card outside `BUDGET_TOL` is listed in this story's Implementation Notes with an accepted-deviation note. Story 008's checks evaluate this once they land; until then it is evaluated by hand and recorded in the smoke file.

---

## Implementation Notes

*Derived from ADR-0002 / ADR-0007 Implementation Guidelines and CN-2:*

- Append the 17 cards to `assets/data/cards_war.json`. Never edit or reorder the batch-0 records (ids are permanent; the loader sorts by id, so file order is irrelevant).
- Write `effects` from each card's C11 row column. Patterns with a dedicated row (`2 + 4` for `war_blade_apprentice`, `armor, draw`, …) use exactly that row's op shape. Windfury on the hero via `buff keywords until_end_of_turn` for `war_pit_champion` is legal (content OQ resolved: Match Rules `has_windfury`).
- `war_shield_maiden` and `war_shieldwall_veteran` must land here: story 004's Hollow King MVP deck uses them.
- Accepted F3 deviations (fill in at implementation; an empty list is a valid outcome), evaluated by hand 2026-11-04 (`production/qa/smoke-2026-11-04-content-mvp1-war.md`, F3 table):
  - `war_cleave_through` (rare, +3.0 vs tol 2.0): 9.0 on the expected weapon branch (3 × AoE 3.0), 6.0 = budget without a weapon. Accepted: it is the sweeper CN-3 B2 names as War's answer to The Gatekeeper and The Hollow King, and the overshoot exists only while War holds a weapon (Pillar 1 plan payoff). Revisit at `/balance-check` (story 009).
  - `war_duelists_edge` (rare, +3.0 vs tol 2.0): 3/3 = 9 plus 2 Armor on each of 3 swings (3.0). Accepted: the armour plan's signature payoff (Heroes H-5), and the value assumes the hero swings all three times into an open board. Revisit at `/balance-check` (story 009).
- Use the CN-2 tags exactly. `war_iron_vanguard` keeps `armour` (Heroes OQ C-03, `PLAN_MAX` 7).

---

## Out of Scope

- Story 001: the 7 starters, `war_iron_resolve`, the token.
- Story 005: the War bundles that reference these cards.
- Story 008: the automated F1–F3 checks.

---

## Files

- `assets/data/cards_war.json` — 17 MVP-1 War records appended (batch-0 records unchanged)
- `production/qa/smoke-2026-11-04-content-mvp1-war.md` — Config/Data smoke record
- `tests/integration/content/content_mvp1_data_test.gd` (+ `.uid`) — new, 8 tests (AC-1…AC-3)
- `tests/integration/content/content_batch0_data_test.gd` — two shipped-data pins relaxed to the batch-0 subset (the War set and the `W_POOL_SIZE` file list)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: `standard` — Config/Data evidence is ADVISORY.*

**Story Type**: Config/Data
**Required evidence**:
- Config/Data: smoke check pass (`production/qa/smoke-[date].md`) with the load report and the F1–F3 figures.

**Status**: [x] `production/qa/smoke-2026-11-04-content-mvp1-war.md` (PASS) + `tests/integration/content/content_mvp1_data_test.gd` (8 tests, passing)

---

## Dependencies

- Depends on: `production/epics/content/story-001-batch-0-first-playable-data-set.md`; `production/epics/card-effects/story-004-validator-step-bound-targeting.md` (full validator)
- Unlocks: `production/epics/content/story-004-mvp-1-bosses-rot-warden-hollow-king.md`, `production/epics/content/story-005-mvp-1-bundles.md`

---

## Readiness

**`/story-readiness` (by hand, 2026-11-04): READY.** Tier: workflow standard (content). Design: CN-2 War rows quoted in AC-1; criteria self-contained and testable. Architecture: ADR-0002 / ADR-0007 Accepted; TR-content-001 active; Manifest Version 2026-11-03 = current. Scope: estimate M, Out of Scope stated, dependencies (content 001, card-effects 004) Complete. No open markers (lint 0). Assets: no asset references. DoD: 3 criteria (balanced min 1), Config/Data type, Test Evidence names the smoke record. QL-STORY-READY skipped — Lean mode.

## Completion Notes
**Completed**: 2026-11-04
**Started / ended (UTC)**: 2026-11-04T02:44:25Z – 2026-11-04T02:53:54Z (lane start, readiness and GDD reading included)
**Criteria**: 3/3 passing — AC-1 and AC-2 by `content_mvp1_data_test.gd`; AC-3 F1/F2 by the same file, F3 by hand in the smoke record with the two accepted deviations above
**Deviations**:
- F3: `war_cleave_through` and `war_duelists_edge` are outside `BUDGET_TOL` (+3.0 each, rare tol 2.0); accepted with reasons in Implementation Notes. The F3 figures rest on stated modelling assumptions (expected weapon Attack 2, three friendly bodies), since story 008's checks are not on this branch.
- `tests/integration/content/content_batch0_data_test.gd` edited (outside the story's Files list): it pinned the shipped War set to the 8 batch-0 cards and `W_POOL_SIZE` to three files; it now checks the batch-0 rows are still present and expects `W_POOL_SIZE` only for `bundles.json` and `treasures.json`. No `data_version` known-answer test depends on the shipped data.
**Validate command**: `Ready — 0 errors, 10 warnings, 47 records` (before: 11 warnings, 30 records); `W_POOL_SIZE` 3 → 2 (the War collectible pool, 38 ≥ 30, no longer warns).
**Test Evidence**: `production/qa/smoke-2026-11-04-content-mvp1-war.md` (PASS); `tests/integration/content/content_mvp1_data_test.gd` (8 tests; seen failing against the batch-0 data before the records were added). Full suite 1086 test cases, 0 failures, exit 0; smoke exit 0.
**Run result**: N/A — data only; no scene loads these cards until match-ui stories, and the smoke run (main scene) stays clean.
**Reviewed by**: self, no independent review (lean — QL-TEST-COVERAGE and LP-CODE-REVIEW skipped); game-designer sign-off NOT ASSESSED (no agent)
**Owner sign-off (2026-11-04, DD-X24)**: Jacob accepts the War set as shipped, including `war_cleave_through` and `war_duelists_edge` over the F3 budget (+3.0 vs rare tol 2.0) for the reasons in Implementation Notes. Both are to be revisited at `/balance-check` (content story 009). This replaces the NOT ASSESSED game-designer sign-off above.
