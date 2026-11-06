# Story 004: F5 hook-chain cost bound and the Node-free treasures tree

> **Epic**: Treasures
> **Status**: In Review
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-11-04
> **Last Updated**: [set by /dev-story when implementation begins]
> **First Playable path**: no

## Context

**GDD**: `design/gdd/treasures.md` (F5, T2.1, AC-14)
**Requirement**: `TR-treasures-004`; `TR-tech-debt-001` (carried: the TD-009 modifier half)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Owner-scoped hook registry
**ADR Decision Summary**: The fold iterates the existing `Array`, passes the existing `ctx` and returns an `int`, so it allocates nothing. `entry_count() ≤ 12` is asserted in debug. Budgets: a 12-entry fold < 0.05 ms, and three treasures add < 2 ms per match. No `HookRegistry` / `HookEntry` / `HookInstaller` / `Treasures` code references a Node, an autoload or `Boot` (the TD-009 defect).
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (language, by version); LOW for the APIs
**Engine Notes**: ADR-0005 Engine Compatibility — no engine API beyond `RefCounted` / containers. `Performance.OBJECT_COUNT` and `Performance.MEMORY_STATIC` are the GDD's allocation probes; confirm them against `docs/engine-reference/godot/` before use, and where the reference does not cover them, mark the probe `NOT SOURCEABLE` in the test and prove it by watching it fail on a deliberate allocation.

**Control Manifest Rules (this layer)**:
- Required: value folds mutate and allocate nothing; `entry_count()` asserted ≤ 12 in debug
- Forbidden: never allocate in the fold (no `duplicate()` of entries, no arrays per invocation); `HookRegistry`, `HookEntry`, `HookInstaller` never reference `RulesEngine`, `EventLog`, `MatchState`, a Node, an autoload or the registry
- Guardrail: hook fold — 12-entry fold < 0.05 ms; three treasures add < 2 ms per match; ≤ 12 entries per match

The sprint-4 retrospective's rule is that a budget set by an ADR or GDD gets its measurement in the same sprint as the first code that can exercise it. This story is that measurement for F5, and it runs once stories 001–002 and card-effects 014 are in.

---

## Acceptance Criteria

*From GDD `design/gdd/treasures.md` (F5, T2.1, AC-14) and the epic's Definition of Done, scoped to this story:*

- [ ] **AC-14** Performance (headless, gdUnit4, same machine for both arms): GIVEN a registry with 12 entries, WHEN `modify_cost` is folded 10,000 times, THEN the mean per fold is < 0.05 ms **and** the fold allocates nothing (`Performance.OBJECT_COUNT` / `MEMORY_STATIC` unchanged across the loop); GIVEN the same scripted 9-turn match run with 3 treasures and with an empty registry, THEN the 3-treasure arm's wall time is ≤ 1.05 × the empty arm's over the median of 5 runs.
- [ ] **AC-T2.1 (no Node, no autoload, no Boot)** GIVEN the lint gates (`tools/lint/gates.sh`), WHEN run, THEN a gate proves no file under `src/gameplay/treasures/**` (nor `hook_registry.gd` / `hook_installer.gd`) references `Node`, an autoload name or `Boot`; the gate is watched failing on a deliberate one-line violation, then restored (one mutation per run).

---

## Implementation Notes

*Derived from ADR-0005 Implementation Guidelines and Performance Implications:*

- Build the 12-entry registry from real installers: 3 treasures × 3 effects plus a passive, or the fixture's `modify_cost` treasures plus `boss_test_taxman`, repeated to 12. Run it through the real `apply_value_hook` (card-effects 014). A stub evaluator would measure nothing.
- The wall-time ratio uses the median of 5 and the same seed (`00000000000000A7`) and scripted command list in both arms. Do not compare against an absolute 2 ms on CI: the GDD replaced the reference machine with this ratio.
- Allocation probe: sample before and after the loop, outside the timed region. A real allocation must make the test fail (mutation: a `duplicate()` inside the fold), or the probe proves nothing (skill-authoring rule: a gate you have not watched fail is not a gate).
- The lint gate asserts distinctive tokens (`extends Node`, `get_tree(`, `Engine.get_main_loop(`, the project's autoload names from `project.godot`, `Boot.`), not a bare substring like "node" (which also matches comments).
- Record the measured numbers in `production/qa/perf-treasures-[date].md`, next to the match-rules perf note.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Card-effects 016: resolver-wide determinism and clone bounds
- Match-rules 018 / 019: `submit()` and `clone()` budgets

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `tests/unit/treasures/treasures_hook_chain_perf_test.gd`
- `tools/lint/gates.sh` — the treasures purity gate
- `production/qa/perf-treasures-[date].md`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/treasures/treasures_hook_chain_perf_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/treasures/story-001-installers-passive-and-collect-state.md`, `production/epics/treasures/story-002-installation-order-duplicates-and-clone.md`. Cross-epic: `production/epics/card-effects/story-014-value-hook-folds.md`
- Unlocks: the epic's Definition of Done grep item; TD-009 (modifier half) retirement evidence
