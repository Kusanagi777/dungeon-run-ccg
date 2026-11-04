# Story 003: Snapshot and restore by reseed-and-discard, command guard, hex snapshot form

> **Epic**: RNG & Event Log
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-03

## Context

**GDD**: `design/gdd/rng-event-log.md`
**Requirement**: `TR-rng-event-log-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Seeded RNG Service and Event Log (also ADR-0004: Save Format and Atomic Profile Write — inherits the hex rule)
**ADR Decision Summary**: `snapshot()` = `{run_seed, data_version, streams: {name: draws}}`; `restore()` rejects a `data_version` mismatch with `ERR_INVALID_DATA` and creates nothing, else rebuilds each stream by reseeding and discarding `draws` outputs (F5) — never by persisting `RandomNumberGenerator.state`; `snapshot()` is refused between `begin_command()` / `end_command()`; `snapshot_to_json_dict()` / `snapshot_from_json_dict()` convert `run_seed` ↔ `run_seed_hex`.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH / NOT SOURCEABLE
**Engine Notes**: Reseed-and-discard reproduces the same next outputs as a `state` restore (probe D4/D5, observed 2026-11-03); the discard form is kept because `draws` is a small, human-readable count JSON carries exactly, whereas `state` is an opaque 64-bit value `JSON.parse_string` corrupts above 2^53 (probe E). Integral floats must be coerced back to `int` on load.

This is how a saved run (DD-R08) resumes mid-sequence and how a faulted floor restarts at `draws = 0` (run-structure R8.3). The `begin_command()` / `end_command()` guard keeps a draw sequence from being split across a save.

**Control Manifest Rules (this layer)**:
- Required: snapshot and restore by reseed-and-discard; `restore()` rejects a `data_version` mismatch with `ERR_INVALID_DATA`; `snapshot()` is refused between `begin_command()` / `end_command()`; 64-bit values cross JSON as 16-hex strings, small integers coerced back with `int()` on load.
- Forbidden: never persist `RandomNumberGenerator.state` as the snapshot (permitted only as an optimisation a test proves equal); never trust `JSON.parse_string` to return an `int`.
- Guardrail: `RngStream.restore` ≤ 5 ms per stream at 10,000 draws (measured in Story 010).

---

## Acceptance Criteria

*From GDD `design/gdd/rng-event-log.md` (rule 10, F5; Edge Cases "Streams", "Persistence"), scoped to this story:*

- [ ] **GIVEN** a 15-card deck and a stream snapshot, **WHEN** the deck is shuffled, the stream restored, and the same deck shuffled again, **THEN** both orders are identical and `draws` increased by 14 each time (F4, F5).
- [ ] **GIVEN** a stream with `draws = 37`, **WHEN** `snapshot()` then `restore()` into a fresh service, **THEN** the next 20 outputs match the original's next 20; the snapshot has the shape `{run_seed: int, data_version: String, streams: {name: draws}}` and a fork (`"<parent>/<label>"`) appears in `streams` under its full name and is restored too.
- [ ] **GIVEN** a snapshot with `data_version = "1.0"` and installed data `"1.1"`, **WHEN** `restore()` is called, **THEN** it returns `ERR_INVALID_DATA` and no stream is created.
- [ ] **Command guard and hex form:** `snapshot()` called between `begin_command()` and `end_command()` returns an empty Dictionary and pushes an error (Edge Cases "mid-command"); `snapshot_to_json_dict()` replaces `run_seed` with `run_seed_hex` (16 uppercase hex) and `snapshot_from_json_dict()` parses it back and coerces every `draws` to `int` — a round trip through `JSON.stringify` / `JSON.parse_string` with a `run_seed` above 2^53 restores the exact seed and the same next outputs.

---

## Implementation Notes

*Derived from ADR-0003 Implementation Guidelines and Decision 3–4:*

- `RngService.snapshot() -> Dictionary`: iterate the memoised streams (forks included, keyed by full name) and record `draws`; keep `run_seed` as `int` in memory.
- `RngService.restore(snapshot: Dictionary) -> Error`: compare `data_version` first; on mismatch return `ERR_INVALID_DATA` having created nothing. Otherwise, for each `{name: draws}`: create the stream with its F2 seed (or its F3 seed for a fork — the parent draw that seeded it is reproduced by restoring the parent first and replaying its fork call at the recorded position; simplest is to store forks by full name and reseed them through the parent's memoised fork path), then discard `draws` `randi32()` outputs (`RngStream.restore(target_draws)`, F5: `generator.seed = stream_seed; repeat draws times: randi32()`).
- `begin_command()` / `end_command()`: a counter or flag; `snapshot()` while open → `{}` + `push_error`. The engine (`MatchDriver`) and `RunMachine` call them around command processing; this story only provides and tests them.
- `snapshot_to_json_dict()` / `static snapshot_from_json_dict(d)`: `run_seed` ↔ `run_seed_hex` via Story 002's `to_hex_u64` / `parse_hex_u64`; coerce integral floats back to `int` (as `TestEventLog._coerce_integral_floats` does).
- An implementation may additionally copy `RandomNumberGenerator.state` as an optimisation only if a test shows both methods yield identical next outputs (F5, ADR Alternative 3); the persisted value stays `draws`.
- Must type every Array and end typed overrides with an explicit `return` (4.7).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 010: the `restore()` at 10,000 draws < 5 ms performance test.
- Run Structure epic: calling `snapshot()` at save points S1–S5, `restore()` on `resume`, the `abandoned` outcome on `data_version` mismatch, `begin_command()` / `end_command()` call sites.
- Meta Progression epic: writing the snapshot into the profile (`AtomicFileWriter`).

---

## Files

- `src/core/rng/rng_service.gd` — `begin_command()` / `end_command()`, `snapshot()`, `restore()`, `snapshot_to_json_dict()`, `static snapshot_from_json_dict()`
- `src/core/rng/rng_stream.gd` — `restore(target_draws)` (F5, clears the fork memo), `forked_at`, `_skip_to()`
- `tests/helpers/test_rng_service.gd` — interim `snapshot()` / `restore()` removed (production now)
- `tests/helpers/test_rng_stream.gd` — `restore()` delegates to production
- `tests/unit/rng_event_log/rng_snapshot_restore_test.gd` — 19 tests

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: standard` Logic tests are BLOCKING.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/rng_event_log/rng_snapshot_restore_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later). ADR-0003's Verification table files these cases under `rng_service_test.gd`; this story keeps them in their own suite so each story has one test file.

**Status**: [x] Created — 19 tests, passing

---

## Dependencies

- Depends on: `production/epics/rng-event-log/story-002-rng-service-seed-derivation-and-streams.md`
- Unlocks: `production/epics/rng-event-log/story-010-determinism-contract-and-performance-budgets.md`, `production/epics/rng-event-log/story-011-replay-equivalence-integration.md`

---

## Completion Notes
**Completed**: 2026-11-03
**Started / ended (UTC)**: 2026-11-03T22:21:58Z – 2026-11-03T22:30:44Z
**Criteria**: 4/4 passing (all covered by unit tests; no deferred items)

| Criterion | Covered by | Status |
|-----------|------------|--------|
| AC-1: 15-card shuffle, restore, shuffle → identical orders, `draws` +14 each time | `rng_snapshot_restore_test.gd::test_shuffle_restore_shuffle_gives_identical_orders_and_n_minus_1_draws_each`, `test_shuffle_of_zero_or_one_element_consumes_no_draws` | COVERED |
| AC-2: `draws = 37` → snapshot → restore into a fresh service → same next 20; shape; a fork under its full name, restored too | `test_restore_at_37_draws_into_a_fresh_service_gives_the_same_next_20_outputs`, `test_snapshot_shape_is_run_seed_data_version_and_stream_draws`, `test_restore_at_zero_draws_replays_the_stream_from_its_first_output`, `test_a_fork_is_snapshotted_under_its_full_name_and_restored_through_its_parent` (also asserts no `/` name reaches `stream()`), `test_the_restored_fork_is_memoised_so_forking_again_takes_no_parent_draw`, `test_a_fork_after_restore_matches_a_fresh_run_not_the_stale_child`, `test_restore_in_place_keeps_held_stream_references_and_drops_streams_the_snapshot_lacks`, `test_stream_restore_reseeds_discards_and_clears_its_fork_memo` | COVERED |
| AC-3: `data_version` "1.0" vs "1.1" → `ERR_INVALID_DATA`, no stream created | `test_restore_rejects_a_data_version_mismatch_and_creates_no_stream`, `test_restore_rejects_a_snapshot_of_another_run_seed_and_leaves_streams_untouched`, `test_restore_rejects_malformed_stream_entries_and_creates_no_stream` | COVERED |
| AC-4: `snapshot()` mid-command → `{}` + error; `run_seed_hex` (16 upper hex); JSON round trip above 2^53 → exact seed, `int` draws, same next outputs | `test_snapshot_between_begin_and_end_command_is_refused_with_an_error`, `test_nested_commands_keep_the_guard_until_the_outermost_end`, `test_end_command_without_begin_is_reported_and_does_not_unbalance_the_guard`, `test_json_dict_carries_run_seed_as_16_uppercase_hex`, `test_json_round_trip_above_two_pow_53_restores_the_exact_seed_and_next_outputs`, `test_snapshot_from_json_dict_refuses_a_missing_or_malformed_seed` | COVERED |

**Deviations**:
- ADVISORY — the snapshot carries a fourth key, `fork_points: {"<parent>/<label>": parent_draws_before_fork}`. A fork's F3 seed is the parent draw it consumed, so `draws` alone cannot rebuild it; `restore()` replays `stream(parent).fork(label)` at the recorded parent position (the story's Implementation Notes: "replaying its fork call at the recorded position"). `RngStream` gains a public `forked_at` (set by `fork()`, -1 for a root). ADR-0003 Decision 3 / Key Interfaces and GDD rule 10 name only `{run_seed(_hex), data_version, streams}`: they need an erratum to add `fork_points` (not edited here — out of this story's scope).
- ADVISORY — in-memory `snapshot()` keeps `run_seed: int` (story AC-2, ADR-0003 Decision 4, QA plan); the persisted form `snapshot_to_json_dict()` is `{run_seed_hex, data_version, streams, fork_points}`. GDD rule 10 / TR-rng-event-log-003 / run-structure `rng_snapshot` describe the persisted form; rule 10's wording "`snapshot()` returns `{run_seed_hex, …}`" reads as the in-memory call and could be tightened.
- ADVISORY — `restore()` also returns `ERR_INVALID_DATA` (with `push_error`, creating nothing) when `snap.run_seed` is not the service's seed (rule 1: the seed is fixed at construction and read-only; the interim double adopted the snapshot's seed instead) and for malformed entries (non-`int` or negative draws, orphan fork, missing / out-of-range / shared fork point). A `data_version` mismatch is silent (an expected outcome Run Structure handles).
- ADVISORY — `restore()` works in place: a root already served keeps its object (held `MatchConfig` references stay valid), every cached fork is dropped and re-taken, and streams absent from the snapshot are removed.
- ADVISORY — `TestRngService`'s interim `snapshot()` / `restore()` are removed (the production ones now serve it; `install()`ed doubles are restored in place); `TestRngStream.restore()` clears its `calls` and script index and delegates to production `RngStream.restore()`. The helper self-test passes unchanged.
- Not implemented (optional per story): the `RandomNumberGenerator.state` copy optimisation.
**Test Evidence**: `tests/unit/rng_event_log/rng_snapshot_restore_test.gd` — 19 tests. Seen failing first: the suite did not parse against the unchanged code (missing API, exit 105); after implementation three mutations (fork replay without its recorded position, fork memo not cleared on restore, command guard disabled) failed 14 tests, then passed restored. Full suite 712/712, exit 0; 36 SCRIPT ERROR lines, all from existing negative tests (none from this suite). Smoke exit 0, no SCRIPT ERROR.
**Run result**: N/A — the service has no scene, node or screen; save/resume call sites are the Run Structure epic's.
**Engine check**: NOT ASSESSED — no specialist agent in this lane; reseeding `RandomNumberGenerator.seed` to replay a sequence is pinned by the restore tests on 4.7.2 (ADR-0003 probe D4/D5).
**Reviewed by**: self, no independent review (`review_mode: lean` — QL-TEST-COVERAGE and LP-CODE-REVIEW skipped; `/code-review` not run in this lane) · `/code-review 2026-11-04 (independent, sprint-4 carry): APPROVED WITH SUGGESTIONS`
