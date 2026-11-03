# Epic: Run Structure

> **Layer**: Feature
> **GDD**: design/gdd/run-structure.md (Overview, Detailed Rules R1–R8, States and transitions T1–T21, Interactions, Formulas, Edge Cases, Tuning Knobs `floors_per_run`, Acceptance Criteria)
> **Architecture Module**: `RunMachine` + `RunState` / `RunRecord` + `DraftRecord` (`src/gameplay/run/`; `MatchDriver` is built here but delivered by the Boss AI + Match Driver epic)
> **Control Manifest**: Feature Layer Rules (Manifest Version 2026-11-03)
> **Build Order**: 8 of 14 — plan E6 (Run + Draft + Treasures + Heroes), ADR-0008 / ADR-0004 / ADR-0003
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories run-structure`

## Overview

Build the outer game: the state machine that turns one hero and one seed into a gauntlet of boss matches with a draft after every win and ends on the first loss. `RunMachine` owns the in-memory `RunState` (R1: seed as `run_seed_hex`, hero, floor, boss sequence from the three bands, growing deck, treasures held, one summary per match, status) and nothing else writes it. It exposes the seven commands over the explicit transition table (`new_run`, `begin_match`, `draft_pick`, `abandon`, `resume`, `suspend`, `return_to_menu`; `E_BAD_PHASE` elsewhere), builds `MatchConfig` per R3 with a fresh match `EventLog` per attempt and the injected `driver_factory`, handles `MatchResult` including fault → `pre_match`, and reaches Meta's M1.3 persistence API at save points S1–S5 (`in_match` never saved; a saved `in_match` is coerced with `run_warning`). `floors_per_run` lets the same machine serve the MVP cut and the full eight floors.

## Scope (MVP)

- `RunState` schema with `validate()`, `RunRecord`, `DraftRecord`; `read_model()` for Run UI
- Transition table T1–T21, seven commands, `reward_step`, `play_seconds`
- `begin_match` → `MatchConfig` (hero def, deck, `Treasures.installers_for(...)` in pick order, boss def, health, passive installer, `ai_id`, streams `match_<f>` / `ai_<f>`, fresh match log); `_on_match_ended` → `reduce_to_summary`, `Treasures.collect_state`, T6–T9, run-scope events, driver dropped
- Boss sequence generation from `bosses_in_band` over the MVP pool (DD-H06: 3 band 1 / 1 band 2 / 1 band 3) with `floors_per_run` at its MVP value
- Save points through `MetaApi` (the `MetaStub` for the MVP); resume restores the RNG snapshot and reopens the run log
- `tests/helpers/RunFactory.make_match_config_for` swap marker: pass `Treasures.installers_for(...)` instead of raw ids

Out of scope: persistence across process restarts (needs `ProfileStore`, Meta Progression epic); mid-match restore from the event log (QQ-07, Vertical Slice design change); the full eight-floor run.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0008: Match Driver Ownership and the Run ↔ Match ↔ UI Hand-off | `RunMachine._init(db, meta, draft, treasures, run_config, driver_factory)`; `begin_match` builds `MatchConfig` and connects `match_ended` first; `_on_match_ended` sequence; `in_match` coercion (R8.3) | HIGH by version |
| ADR-0004: Save Format and Atomic Profile Write | Run save points S1–S5 through the M1.3 API; `RunRecord` opaque to Meta; `run_seed_hex` persisted form | MEDIUM / NOT SOURCEABLE (Windows gated) |
| ADR-0003: Seeded RNG Service and Event Log | `run_seed_from_input(input, entropy)` — the one permitted entropy call lives in the run-creation command; run-scope log; `snapshot` / `restore` on resume | HIGH / NOT SOURCEABLE |
| ADR-0011: Run UI Shell Pattern | `RunController` is the only caller of the seven commands; read models in, intents out | HIGH |
| ADR-0006: Boss AI Planner Threading | The driver the machine builds carries the `PlannerTask` | HIGH / NOT SOURCEABLE |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-run-structure-001 | R1: RunState record schema (JSON-only) with validate() invariants; run_seed persisted as the 16-hex run_seed_hex string only (int64 in memory, reconstructed on load); draft_state and treasure_state opaque blobs | ADR-0004 ✅ |
| TR-run-structure-002 | R2, R3, R4: new_run, begin_match building MatchConfig, MatchResult handling including fault -> pre_match | ADR-0008 ✅ |
| TR-run-structure-003 | States, T1-T21: explicit transition table over status; seven commands (new_run, begin_match, draft_pick, abandon, resume, suspend, return_to_menu); E_BAD_PHASE elsewhere | ADR-0008 ✅ (also ADR-0011) |
| TR-run-structure-004 | R7, R8: save points S1-S5 through Meta's persistence API; in_match never saved; resume restores the RNG snapshot and reopens the run log; resume after a mid-match quit = restart with the same streams | ADR-0008 ✅ (also ADR-0003, 0004, 0011) |
| TR-run-structure-005 | Interactions (Boss AI): Run Structure owns the match driver … wrapped by Match UI's MatchController — **delivered by the Boss AI + Match Driver epic**; this epic consumes it via `driver_factory` | ADR-0008 ✅ (also ADR-0006) |

Requirements covered by Accepted ADRs: 5 / 5. Untraced Requirements: None.

## Gate Entry Conditions Carried

- None named directly. Enables the Run UI epic (condition 11's hero-select / run-summary screens render this module's read model) and the Vertical Slice's save/resume.

## Definition of Done

- Every story implemented, reviewed and closed with `/story-done`
- Every acceptance criterion of design/gdd/run-structure.md verified (36 criteria lines)
- `tests/integration/run/` proves a seeded run reproduces its boss sequence and drafts given the same picks, and resume after `suspend` regenerates the identical offer
- Logic and Integration stories have passing tests in the test root
- Visual/Feel and UI stories have retained screenshots in `production/qa/evidence/` (a lead sign-off too for Visual/Feel)
