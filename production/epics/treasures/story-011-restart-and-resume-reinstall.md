# Story 011: Restart and resume re-install from the id list — the caller's `run_warning`s

> **Epic**: Treasures
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-11-04
> **Last Updated**: [set by /dev-story when implementation begins]
> **First Playable path**: no

## Context

**GDD**: `design/gdd/treasures.md` (T3.4, T4, T5.2, States "Installed", Edge Cases "State and persistence", AC-9, AC-10 resume half, AC-4 caller half) · `design/gdd/run-structure.md` R3, R4, R8.3, R8.5
**Requirement**: `TR-treasures-002`, `TR-treasures-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Owner-scoped hook registry (most direct); ADR-0008 governs `RunMachine` (the caller), per the control manifest's Feature rules
**ADR Decision Summary**: Nothing about treasures survives a match except the id list and `collect_state`'s blob. `RunMachine.begin_match` re-runs `installers_for(treasures[], treasure_state)` on every attempt, with a fresh match `EventLog` and the same `match_<floor>` / `ai_<floor>` streams restored at `draws = 0`. The caller logs `run_warning{duplicate_treasure}` and `run_warning{treasure_state_reset}`.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (language, by version); LOW for the APIs
**Engine Notes**: ADR-0005 Engine Compatibility — no post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: `RunMachine.begin_match()` builds `MatchConfig` per R3 with a fresh match `EventLog` per attempt; a `RunState` of `in_match` found in a save is coerced to `pre_match` with `run_warning{coerced_status}` and the streams restored at `draws = 0` (R8.3); `RunMachine._on_match_ended` calls `Treasures.collect_state(driver.hooks(), result)`
- Forbidden: never save, serialise or pause a live match from `RunMachine`; never mutate `RunState` from `src/gameplay/treasures/`
- Guardrail: restart flow ≤ `restart_budget_ms` 5000

**Scheduling note:** this story's caller is `RunMachine`, which the **Run Structure epic** builds, and that epic has no stories yet. The story is Ready on ADR grounds (ADR-0005 / ADR-0008 Accepted). It is not schedulable until `/create-stories run-structure` writes the `begin_match` and resume stories it depends on; `/story-readiness` should name them then.

---

## Acceptance Criteria

*From GDD `design/gdd/treasures.md` (AC-9, AC-10, AC-4), scoped to this story:*

- [ ] **AC-9** GIVEN seed `00000000000000A7` and `[treasure_hollow_crown, treasure_thornhide_cloak]`, WHEN the match is begun, quit after the player's second command, resumed and restarted, THEN the two logs are identical up to the first player command (`deck_shuffled`, `mana_added`, `card_drawn` sequences match) and the restarted registry equals the first.
- [ ] **AC-10 (resume half)** GIVEN a saved `treasure_state` with `schema_version: 99`, WHEN the run is resumed and `begin_match` runs, THEN `run_warning{treasure_state_reset}` is appended to the run-scope log and the installers equal a stateless run's.
- [ ] **AC-4 (caller half)** GIVEN a hand-edited save whose `treasures[]` is `[signet, crown, signet]`, WHEN `begin_match` runs, THEN exactly one `run_warning{code: duplicate_treasure, treasure_id: treasure_worn_signet}` is appended and the match installs two treasure hosts.

---

## Implementation Notes

*Derived from ADR-0005 Decision rules 5 and 8, and the manifest's Feature rows for `RunMachine` (ADR-0008):*

- The restart path is run-structure R8.3: an `in_match` save is coerced to `pre_match`, and the next `begin_match` increments `match_attempts[floor]` and restores the streams at `draws = 0`. Treasures adds nothing to that path: the same ids in the same order give an equal registry (T3.4), which is what AC-9 asserts.
- Compare registries with `HookRegistry.entries(point)` per point, plus `hosts()`. Compare logs by event type and payload up to the first player command.
- The warnings come from story 001's dropped-duplicate / reset report. `RunMachine` appends them to the **run-scope** log, not the match log.
- If the Run Structure epic splits `begin_match` and resume across stories, depend on both, and keep this story's tests in `tests/integration/treasures/` with the run-level fixtures from `tests/helpers/run_factory.gd`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: the pure `installers_for` / `collect_state` behaviour
- Run Structure epic: `RunMachine` itself, saves S2/S3, `match_attempts`

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `tests/integration/treasures/treasures_restart_resume_test.gd`
- `src/gameplay/run/run_machine.gd` — only the two `run_warning` appends, if the Run Structure stories have not already added them

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/treasures/treasures_restart_resume_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/treasures/story-001-installers-passive-and-collect-state.md`, `production/epics/treasures/story-007-trigger-hook-treasures.md` (Crown, Cloak). Cross-epic: the Run Structure epic's `begin_match` and resume stories (paths not yet assigned — `/create-stories run-structure`)
- Unlocks: the epic's save/resume idempotence guarantee (T3, T4)
