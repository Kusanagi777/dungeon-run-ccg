# Epic: Reward Draft

> **Layer**: Feature
> **GDD**: design/gdd/reward-draft.md (Overview, Detailed Rules D1–D9, Formulas D4–D9 weighting and pity, Edge Cases, Interactions, UI Requirements, Acceptance Criteria) · design/ux/draft-picker.md (APPROVED round 3)
> **Architecture Module**: `RewardDraft` + `Offer` + `Pick` (`src/gameplay/draft/`)
> **Control Manifest**: Feature Layer Rules (Manifest Version 2026-11-03)
> **Build Order**: 9 of 14 — plan E6, ADR-0005 / ADR-0003 / ADR-0011
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories reward-draft`

## Overview

Turn a won match into deck growth. After every win the run asks for three authored bundles (three fixed cards sharing a theme tag, DD-R04) and the player takes exactly one; on treasure floors (DD-R05) three distinct passive treasures are offered first. `RewardDraft` keeps nothing of its own: `init_run(run_state)` snapshots the unlock-filtered treasure pool once through `Treasures.pool(unlocked_keys, [])` (QQ-08), `offer(kind, run_state, stream)` is a pure function of the run record and the `draft_<floor>` stream (weighted toward themes already in the deck, bent by band toward the next bosses' curve, forced to cover two themes, backed by the pity rule derived from `run_state.drafts[]`), and `pick(...)` returns the `Pick` the run records. Pillar 1 ("the draft is the game") lives here, and the systems index names "take the strongest" collapse as its design risk, so pick-rate logging feeds `/balance-check`.

## Scope (MVP)

- `init_run`, `offer`, `pick`; `Offer{option_ids[], flags[]}` with the per-option `n_tag` / `affine` read model Run UI renders
- Weighting formulas D4–D9 from `config("reward_draft")`; exclusion and pity from `run_state.drafts[]`
- The MVP pool: 10 bundles and 10 treasures (DD-H06; DD-R05 needs 9 distinct treasures per run)
- `treasure_granted` / draft events on the run log for `/balance-check` inputs

Out of scope: the 26 bundles and 10 treasures beyond the MVP pool (Content, deferred list); skip and removal (not in v1 by design).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0005: Owner-scoped hook registry | `Treasures.pool()` is the single membership predicate and `RewardDraft.init_run` calls it; Treasures owns definitions, Reward Draft reads the pool (systems-index resolution) | LOW (APIs) / HIGH (language) |
| ADR-0003: Seeded RNG Service and Event Log | `draft_<floor>` stream; `weighted_pick`; offer reproducible from stream position; resume regenerates the identical offer | HIGH / NOT SOURCEABLE |
| ADR-0011: Run UI Shell Pattern | Read model consumed by the draft-picker screen; `pick(index)` intent → `draft_pick` command | HIGH |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-reward-draft-001 | D1: init_run(run_state) -> draft_state, offer(kind, run_state, stream) -> Offer{option_ids[], flags[]}, pick(kind, id, offer, run_state) -> Pick; offer is a pure function of (run_state, stream position) and mutates nothing | ADR-0003 ✅ (also ADR-0005, 0011) |
| TR-reward-draft-002 | D3, D7: exclusion and pity derived from run_state.drafts[]; unlock-filtered treasure pool snapshotted once at init_run | ADR-0003 ✅ (also ADR-0005) |
| TR-systems-index-003 (carried, shared with Treasures) | Circular Dependencies: Treasures <-> Reward Draft - Treasures owns definitions and the chain; Reward Draft reads the pool and the run writes treasure_granted | ADR-0005 ✅ |

Requirements covered by Accepted ADRs: 3 / 3. Untraced Requirements: None.

## Gate Entry Conditions Carried

- **Condition 11**: `design/ux/draft-picker.md` is APPROVED (round 3); the Run UI stories that render this module cite it.

## Salvage from the archived prototype (`prototypes/hearthstone-clone-2026-01/`, never imported)

- `scripts/victory_selection.gd` + `scenes/victory_selection.tscn` — the post-win pick-1-of-N flow is the bundle draft's ancestor; layout ideas only, logic re-derived from D1–D9

## Definition of Done

- Every story implemented, reviewed and closed with `/story-done`
- Every acceptance criterion of design/gdd/reward-draft.md verified (32 criteria lines)
- A seeded run with scripted picks reproduces every offer twice; the two-theme and pity invariants hold over a 1,000-run headless sweep
- Logic and Integration stories have passing tests in the test root
- Visual/Feel and UI stories have retained screenshots in `production/qa/evidence/` (a lead sign-off too for Visual/Feel)
