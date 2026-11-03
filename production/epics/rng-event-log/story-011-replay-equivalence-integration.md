# Story 011: Replay equivalence across systems (seed 42, hero War — boss sequence and first offers)

> **Epic**: RNG & Event Log
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/rng-event-log.md`
**Requirement**: `TR-rng-event-log-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Seeded RNG Service and Event Log (also ADR-0006: Boss AI Planner Threading — the worker plans on a clone with a scratch log; the live log is written only on `tick()`)
**ADR Decision Summary**: Two executions with the same `run_seed`, hero, `data_version`, engine version and command sequence produce byte-identical event logs (F6); the guarantee is per command sequence. The integration proof is `tests/integration/rng_event_log/replay_equivalence_test.gd`, which needs Run Structure and Reward Draft.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH / NOT SOURCEABLE
**Engine Notes**: Replay is scoped to one engine version by design (rule 9); a changed `RandomNumberGenerator` algorithm breaks replay of archived logs and is caught first by Story 001's pin. The worker-thread determinism half (planner on a clone, replay on `tick()`) is ADR-0006's and is gated on Windows (gate condition 9).

This is the epic's end-to-end acceptance criterion (GDD AC 3) and the property gate entry condition 6 names for the headless AI-vs-AI harness: a seeded run reproduces its boss sequence and its first draft given the same commands. It cannot run until `RunMachine` (Run Structure) and `RewardDraft` (Reward Draft) exist, so it is scheduled last and its dependencies cross epics; the ADR is Accepted, so the story is Ready rather than Blocked.

**Control Manifest Rules (this layer)**:
- Required: `RngService` / `EventLog` constructed by `RunMachine` / `MatchDriver` and by tests directly; draw only while a command is being processed; emit exactly one event per state mutation; tests under `tests/**` construct rules objects directly, never through `Boot`.
- Forbidden: never append to or subscribe to the live log from a worker thread; never a global seeded RNG; never reference `Boot` from rules code.
- Guardrail: none specific (functional proof).

---

## Acceptance Criteria

*From GDD `design/gdd/rng-event-log.md` (rule 9, F6, Acceptance Criteria 3) and gate entry condition 6, scoped to this story:*

- [ ] **GIVEN** two runs created with seed 42 and hero War, **WHEN** both reach floor 1 and win it with the same command sequence, **THEN** `run_started.boss_ids[]` and the floor-1 `draft_offered.option_ids[]` are equal between the two logs (integration test with Run Structure and Reward Draft).
- [ ] **GIVEN** the same two runs, **WHEN** their floor-1 match logs and run logs are serialised, **THEN** `EventLogAssertions.assert_replay_equal` holds for each pair and the `to_json()` strings are byte-identical; a third run with one different player command diverges at or after that command's first event (and the test states that later AI decisions are not expected to match — DD-R09 limit).

---

## Implementation Notes

*Derived from ADR-0003 Implementation Guidelines and Decision 10(c), ADR-0006:*

- Drive both runs through `RunMachine` commands (`new_run` with input `"42"`, `begin_match`, scripted match commands via `MatchDriver`, `draft_pick`), constructing every service directly — never through `Boot`.
- Use the MVP data (`CardDatabase` loaded from `assets/data/`) so `data_version` is identical in both runs; assert the header `data_version` and `engine_version` match before comparing events.
- Compare with `EventLogAssertions.assert_replay_equal` (F6 canonical form); do not compare raw Dictionaries.
- The planner thread must not touch the live log — if `MatchDriver` is available only in its main-thread form at the time of writing, run with the synchronous driver and note it; the threaded proof is ADR-0006's gate (condition 9).
- No production code is expected in this epic's folders; defects it finds belong to the owning story of the system that drew or emitted out of order.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 010: the self-contained F6 proof (no other systems).
- Run Structure epic: `new_run`, the boss sequence from the `run` stream, `resume` regenerating the identical offer.
- Reward Draft epic: `draft_offered` from the `draft_<floor>` stream.
- Boss AI + Match Driver epic: the headless AI-vs-AI harness and worker-vs-main-thread determinism.
- Manual AC (death screen shows a 16-hex seed; typing it reproduces the run — DD-R09): Run UI epic.

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `tests/integration/rng_event_log/replay_equivalence_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: standard` Integration tests are BLOCKING.*

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/rng_event_log/replay_equivalence_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/rng-event-log/story-003-snapshot-restore-and-command-guard.md`, `production/epics/rng-event-log/story-006-event-log-serialization-and-diagnostics.md`, `production/epics/rng-event-log/story-010-determinism-contract-and-performance-budgets.md`; cross-epic: the `RunMachine` / `new_run` stories of `production/epics/run-structure/EPIC.md`, the offer-generation stories of `production/epics/reward-draft/EPIC.md`, and a playable floor-1 match from `production/epics/match-rules/EPIC.md` (none created yet)
- Unlocks: None (closes the epic's Definition of Done and gate entry condition 6's determinism property)
