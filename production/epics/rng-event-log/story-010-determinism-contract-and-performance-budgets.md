# Story 010: Determinism contract (F6 self-test) and performance budgets

> **Epic**: RNG & Event Log
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/rng-event-log.md`
**Requirement**: `TR-rng-event-log-003` (also `TR-rng-event-log-006` for the budgets)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Seeded RNG Service and Event Log
**ADR Decision Summary**: The suite-level determinism rule is F6: a test that runs a scripted command sequence twice asserts `EventLogAssertions.replay_equal(a, b)`; `restore` of 10,000 draws is bounded by the 5 ms AC and `EventLog` by the 50 ms AC, both measured by a perf test whose thresholds fail the test.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH / NOT SOURCEABLE
**Engine Notes**: `Time.get_ticks_usec()` is NOT SOURCEABLE (LOW risk, ADR-0006 claim 17); the F5 cost is O(draws) in GDScript. Budgets are measured headless on the CI runner; a budget that cannot hold is reported, not silently raised.

This story closes the Verification table rows that span the two halves of the system: the self-contained F6 proof (two identical scripted sequences of draws and appends give byte-identical logs — the property gate entry condition 6's headless AI-vs-AI harness will rely on) and the two performance guardrails the control manifest lists for this layer. The testing standard's "no time-dependent assertions" rule yields here to the GDD's explicit performance AC and ADR-0003's "thresholds fail the test"; the test is marked as the performance suite so `/test-flakiness` can quarantine it if the runner proves noisy.

**Control Manifest Rules (this layer)**:
- Required: draw only while a command is being processed; every primitive consumes exactly its F4 draw count; emit exactly one event per state mutation.
- Forbidden: never a "free" draw for convenience; never a background-thread save or append.
- Guardrail: `RngStream.restore` ≤ 5 ms per stream at 10,000 draws; `EventLog` 10,000 appends within the 50 ms AC.

---

## Acceptance Criteria

*From GDD `design/gdd/rng-event-log.md` (rule 9, F6; Acceptance Criteria "Performance"), scoped to this story:*

- [ ] **F6 self-test (rule 9):** **GIVEN** two `RngService(42, "test")` + `EventLog` pairs, **WHEN** the same scripted sequence of `begin_command()` / draws on `match_1` and `ai_1` (including one `fork("sim_1")`) / appends with nested `cause_seq` / `end_command()` is executed on each, **THEN** `EventLogAssertions.assert_replay_equal(a, b)` holds, the two `to_json()` strings are byte-identical, and the two `snapshot()` Dictionaries are equal; changing one draw bound in the second sequence breaks `replay_equal`.
- [ ] **Performance:** appending 10,000 events (payloads ~200 bytes) and reading `events_since(0)` completes in under 50 ms headless.
- [ ] **Performance:** `restore()` of a stream with `draws = 10,000` completes in under 5 ms headless; the restored stream's next 20 outputs equal the original's.

---

## Implementation Notes

*Derived from ADR-0003 Implementation Guidelines and Decision 10(c), Performance Implications:*

- No production code is expected; this story is tests. If a budget fails, the fix lands in the owning story's file (`rng_stream.gd` for restore, `event_log.gd` for append) and this suite is the proof.
- Timing with `Time.get_ticks_usec()` around the measured block only; construct fixtures outside the window; run the measured block once (no warm-up tricks that hide the real first-call cost — the AC is per call).
- Name the suite `rng_event_log_perf_test.gd` (ADR-0003 Verification table) and tag it in the file header as the performance suite.
- The F6 self-test uses literal seeds and scripted sequences only (no time, no global RNG — Story 004's lint covers `tests/` too).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 011: the cross-system replay-equivalence integration test (GDD AC 3).
- Boss AI + Match Driver epic: the headless AI-vs-AI harness itself (gate condition 6).

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `tests/unit/rng_event_log/rng_event_log_perf_test.gd`
- `tests/unit/rng_event_log/rng_event_log_determinism_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: standard` Logic tests are BLOCKING.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/rng_event_log/rng_event_log_determinism_test.gd` and `tests/unit/rng_event_log/rng_event_log_perf_test.gd` — must exist and pass (`/story-done` checks that they EXIST; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/rng-event-log/story-003-snapshot-restore-and-command-guard.md`, `production/epics/rng-event-log/story-006-event-log-serialization-and-diagnostics.md`
- Unlocks: `production/epics/rng-event-log/story-011-replay-equivalence-integration.md`
