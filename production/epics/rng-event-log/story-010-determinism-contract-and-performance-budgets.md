# Story 010: Determinism contract (F6 self-test) and performance budgets

> **Epic**: RNG & Event Log
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-03

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

- `tests/unit/rng_event_log/rng_event_log_determinism_test.gd` — 5 tests (blocking): F6 self-test, bound change and `cause_seq`-only change break `replay_equal`, mid-command snapshot refused, restore at 10,000 draws gives the same next 20
- `tests/performance/rng_event_log/rng_event_log_perf_test.gd` — 2 timed tests (non-blocking; moved out of `tests/unit/` per the sprint-3 QA plan)
- `src/core/log/event_log.gd` — append fast path for the 50 ms budget (`_freeze_plain_children` / `_freeze_plain`, cached `_sealing_type`, no delivery queue without subscribers)
- `tests/unit/rng_event_log/event_log_test.gd` — +1 regression test (coercing-copy payloads stored read-only)
- `project.yaml` — `commands.test` gains `-i res://tests/performance`
- `.github/workflows/tests.yml` — blocking step takes the new command; new non-blocking `performance` job
- `tests/README.md` — performance suites section

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: standard` Logic tests are BLOCKING.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/rng_event_log/rng_event_log_determinism_test.gd` and `tests/unit/rng_event_log/rng_event_log_perf_test.gd` — must exist and pass (`/story-done` checks that they EXIST; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] Created — determinism suite (5 tests) passing in the blocking run; perf suite at `tests/performance/rng_event_log/rng_event_log_perf_test.gd` (non-blocking): restore passes, the append budget fails (see Completion Notes)

---

## Dependencies

- Depends on: `production/epics/rng-event-log/story-003-snapshot-restore-and-command-guard.md`, `production/epics/rng-event-log/story-006-event-log-serialization-and-diagnostics.md`
- Unlocks: `production/epics/rng-event-log/story-011-replay-equivalence-integration.md`

---

## Completion Notes
**Completed**: 2026-11-03
**Started / ended (UTC)**: 2026-11-03T22:34:40Z – 2026-11-03T22:42:46Z
**Criteria**: 2/3 passing; AC-2 (append budget) **FAILS** on this container, non-blocking by the sprint-3 QA plan (Cross-cutting 2). Not deferred: the miss is measured and reported, not raised.

| Criterion | Covered by | Status |
|-----------|------------|--------|
| AC-1: F6 self-test — two `RngService(42, "test")` + `EventLog` pairs, same scripted command (`begin_command`, `match_1` / `ai_1` draws, `fork("sim_1")`, nested `cause_seq`, `end_command`) → `assert_replay_equal`, byte-identical `to_json()`, equal `snapshot()`; one changed draw bound breaks `replay_equal` | `rng_event_log_determinism_test.gd::test_the_same_scripted_sequence_twice_gives_replay_equal_byte_identical_logs`, `test_changing_one_draw_bound_breaks_replay_equal`, `test_a_cause_seq_difference_alone_breaks_replay_equal` (QA plan edge case), `test_a_snapshot_taken_mid_sequence_is_refused_and_the_log_is_unaffected` | COVERED |
| AC-2: 10,000 appends (~200-byte payloads) + `events_since(0)` < 50 ms headless | `tests/performance/rng_event_log/rng_event_log_perf_test.gd::test_ten_thousand_appends_and_events_since_zero_fit_in_50_ms` (non-blocking job) | **FAILS** — 50.8–60.2 ms over 7 runs after the fix (4-core Xeon 2.1 GHz container, debug editor binary); was ~207 ms before this story's fix |
| AC-3: restore at `draws = 10,000` < 5 ms; next 20 outputs equal | perf: `test_restore_of_a_ten_thousand_draw_stream_fits_in_5_ms` — 1.25–1.70 ms; blocking: `rng_event_log_determinism_test.gd::test_restore_at_ten_thousand_draws_gives_the_original_next_20_outputs` | COVERED |

**Deviations**:
- ADVISORY — **AC-2 append budget missed.** The perf suite first measured ~207 ms. Per the story ("the fix lands in the owning story's file"), `EventLog.append()` got a fast path: a rule 14 plain payload is copied with the native `duplicate(true)` and checked and frozen in one pass; anything else (a StringName, a non-JSON value, a typed container) takes the old coercing copy unchanged. The sealing type is looked up once, and the delivery queue is skipped when there are no subscribers. That brought it to 51–60 ms. Profiling puts the floor of the current design near 45 ms: about 2.6 µs per event to build the envelope Dictionary plus the deep copy and the freeze, which ADR-0003 Decision 5 requires. Options for the owner: accept ~60 ms (or a budget re-stated for the debug editor binary), measure an export build (release GDScript, not available in this container), or revisit the per-append deep copy / freeze in ADR-0003. The 50 ms threshold is unchanged and the test stays red in the non-blocking job.
- ADVISORY — the perf suite lives at `tests/performance/rng_event_log/rng_event_log_perf_test.gd`, not the story's `tests/unit/rng_event_log/`, per the sprint-3 QA plan. Exclusion uses option (a): `project.yaml` `commands.test` gains `-i res://tests/performance`. gdUnit4 6.2.3 matches `-i` as a substring of a suite's source path, so a directory works: observed 725 tests run, the perf suite not discovered. The `tests.yml` blocking step mirrors it. A new `performance` job (continue-on-error, one retry, `PERF` timings to the job summary, `gdunit4-perf-report` artifact) runs the folder. Its step body was dry-run locally: retry and summary worked, exit 100. `windows-export.yml` untouched. `tests/README.md` documents it. `.claude/docs/coding-standards.md` still quotes the framework's generic Godot CI command without `-i` (framework doc, not edited).
- ADVISORY — `src/core/log/event_log.gd` (story 005's file) changed for the budget fix; the existing event-log suites pass unchanged. `tests/unit/rng_event_log/event_log_test.gd` gains `test_payloads_taking_the_coercing_copy_are_stored_read_only_too`, which guards the coercing branch the fast path now sits beside (seen failing with that branch's freeze removed).
**Test Evidence**: `tests/unit/rng_event_log/rng_event_log_determinism_test.gd` — 5 tests. Seen failing: a non-deterministic generator (`_rng.randomize()` after seeding) failed 3 of them; the bound-change and mid-command tests assert the negative and pass against it by design. `tests/performance/rng_event_log/rng_event_log_perf_test.gd` — 2 tests, append test failing as reported. Full blocking suite 725/725, exit 0; 36 SCRIPT ERROR lines, all from existing negative tests (unchanged). Smoke exit 0, no SCRIPT ERROR. `tools/lint/gates.sh` PASS, `no_global_rng.sh` 0 hits, `parse-check.sh` 26/26.
**Run result**: N/A — test-only story plus a log-internals fix; nothing is drawn or launched.
**Engine check**: NOT ASSESSED — no specialist agent in this lane. `Time.get_ticks_usec()` is NOT SOURCEABLE (ADR-0006 claim 17), used as observed on 4.7.2. `Dictionary.duplicate(true)` / `is_typed()` / `make_read_only()` were observed on 4.7.2 by the event-log suites.
**Reviewed by**: self, no independent review (`review_mode: lean` — QL-TEST-COVERAGE and LP-CODE-REVIEW skipped; `/code-review` not run in this lane) · `/code-review 2026-11-04 (independent, sprint-4 carry): APPROVED WITH SUGGESTIONS (owner decision on the append budget)`
