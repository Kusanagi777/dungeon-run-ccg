# Story 001: RngStream — engine golden pin and F4 draw primitives

> **Epic**: RNG & Event Log
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-03

## Context

**GDD**: `design/gdd/rng-event-log.md`
**Requirement**: `TR-rng-event-log-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Seeded RNG Service and Event Log (also ADR-0001: Rules / Presentation Split)
**ADR Decision Summary**: One `RandomNumberGenerator` per stream, `seed` set once; `randi32()` (= `RandomNumberGenerator.randi()`) is the only generator call and every F4 primitive is defined over it so `draws` is exact and engine-independent; `fork(label)` consumes one parent draw on first call and is memoised.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH / NOT SOURCEABLE
**Engine Notes**: `RandomNumberGenerator`, `int` overflow and `JSON` have no page under `docs/engine-reference/godot/`; closed by the headless probe (ADR-0003 Verification, probe D: same seed ⇒ same `randi()` sequence; `randi()` ∈ `[0, 2^32 − 1]`; re-observed 2026-11-03: `seed = 42` → `492690617, 1919685028, 3561993920`). This story turns that probe into the permanent pin test (gate entry condition 7). Typed arrays (`Array[int]`) required; overrides of typed methods end in an explicit `return` (4.7 rule).

This is the first RNG story and the first file under `src/core/rng/`. It builds the stream object alone — `RngService` (seed derivation F1–F3, memoisation) is Story 002 — so the engine pin lands before anything depends on the generator. `tests/helpers/test_rng_stream.gd` already implements the same F4 contract as a double; its draw-count behaviour is the reference for this class, and its helper self-test pins move here in Story 002.

**Control Manifest Rules (this layer)**:
- Required: `RngService` / `RngStream` (`src/core/rng/`) are concrete `RefCounted` classes constructed by `RunMachine` / `MatchDriver` and by tests directly; one `RandomNumberGenerator` per stream, `seed` set once; `randi32()` is the only generator call; `fork(label)` consumes one parent draw on first call and is memoised; every primitive consumes exactly its F4 draw count.
- Forbidden: never a global seeded RNG (`seed()` + `randi()` / `Array.shuffle()`); never one `RandomNumberGenerator` with streams as counters; never a hand-written PRNG in GDScript; never a "free" draw for convenience; never draw in `_init`.
- Guardrail: `RngStream.restore` ≤ 5 ms per stream at 10,000 draws (measured in Story 010).

---

## Acceptance Criteria

*From GDD `design/gdd/rng-event-log.md` (rule 4–6, F4, Edge Cases) and gate entry condition 7, scoped to this story:*

- [ ] **Golden-sequence engine pin (gate condition 7, ADR-0003 Verification):** `tests/unit/rng_event_log/rng_engine_pins_test.gd` seeds two `RandomNumberGenerator` instances with `42`, draws 100 `randi()` values from each, asserts the two sequences are identical and that the first three values are `492690617, 1919685028, 3561993920` (observed on 4.7.2, 2026-11-03), and asserts every value lies in `[0, 2^32 − 1]`. A failure names the engine version, not the code.
- [ ] **GIVEN** `weighted_pick([5, 0, 15])` over 10,000 draws from a stream seeded with `42`, **WHEN** counted, **THEN** index 1 is never picked and index 2 is picked 7,200 – 7,800 times (F4; 1 draw per pick, so `draws == 10,000` afterwards).
- [ ] **GIVEN** a stream, **WHEN** `fork("x")` is called twice, **THEN** the same object is returned, it is named `<parent>/x`, and the parent's `draws` rose by exactly 1 in total (rule 5, F3, Edge Cases).
- [ ] **Draw counts are exact (F4, Edge Cases):** `randi_range`, `randf` and `weighted_pick` consume 1 draw; `shuffle(a)` consumes exactly `n − 1` draws and 0 for 0 or 1 elements (Fisher–Yates, `j = randi_range(0, i)` for `i = n − 1 … 1`); `randi_range` with `lo > hi` or span above 65,536 returns `lo` with no draw in release (assert in debug); `weighted_pick` with an empty array, a negative weight, a total of 0 or above 65,536 returns `-1` with no draw in release (assert in debug). The F4 example trace (`shuffle([A,B,C,D])` with `j = 1, 0, 1` → `[C,D,A,B]`, 3 draws; `weighted_pick([5,0,15])` with `r = 7` → index 2) holds when `randi32()` is scripted.

---

## Implementation Notes

*Derived from ADR-0003 Implementation Guidelines and Decision 1–2:*

- `src/core/rng/rng_stream.gd`: `class_name RngStream extends RefCounted`; `var name: String`, `var draws: int`; one `RandomNumberGenerator` created in `_init(name, seed)` with `seed` set once. `_init` performs no draw.
- `randi32() -> int` is `RandomNumberGenerator.randi()` and increments `draws`; it is the only method that touches the generator and is NOT for rules code (lint-gated outside `src/core/rng/` by Story 004).
- F4 definitions, literally: `randi_range(lo, hi) = lo + (randi32() mod (hi − lo + 1))`; `randf() = randi32() / 2^32` (`[0, 1)`, weight normalisation only); `shuffle` in place; `weighted_pick`: `total = Σ w; r = randi_range(0, total − 1)`; return the smallest `i` with cumulative `> r`.
- `fork(label) -> RngStream`: on first call draw one `randi32()` from the parent, seed the child with `fork_seed(parent_draw, parent_name, label)` (F3 — the static derivation lives in `RngService`, Story 002; until then call the same FNV-1a 64 + SplitMix64 arithmetic, written in signed `int` with `>>>` emulated as `(x >> n) & ((1 << (64 - n)) - 1)`, exactly as `TestRngStream.fnv1a64` / `mix64` / `ushr64`); memoise by `"<name>/<label>"` and return the same child on later calls.
- Must keep `draws` exact: every primitive consumes the F4 count and nothing else; the invalid-input branches consume nothing.
- Must type every Array (`Array[int]`) and end every typed override with an explicit `return` (4.7 inherited-return rule).
- The pin test is the durable record of probe D (engine-validation-2026-11-03.md asked for it): once it lands, the scratch probe file is no longer needed. Keep the pinned constants in the test with a dated comment; on an engine bump a mismatch is re-recorded with a dated note (ADR-0003 Validation Criteria).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: `RngService`, F1 input parsing, F2 stream-seed derivation, stream memoisation, hex helpers, moving the helper seed pins.
- Story 003: `snapshot()` / `restore()` by reseed-and-discard, `begin_command()` / `end_command()`.
- Story 004: the `no_global_rng.sh` lint and its headless test.
- Story 010: the 5 ms `restore` performance test.

---

## Files

- `src/core/rng/rng_stream.gd`
- `tests/unit/rng_event_log/rng_engine_pins_test.gd`
- `tests/unit/rng_event_log/rng_stream_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: standard` Logic tests are BLOCKING.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/rng_event_log/rng_engine_pins_test.gd` and `tests/unit/rng_event_log/rng_stream_test.gd` — must exist and pass (`/story-done` checks that they EXIST; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] Created 2026-11-03 — 31 test functions (4 pin + 27 stream); full suite `commands.test` 97/97 passed, exit 0

---

## Dependencies

- Depends on: None
- Unlocks: `production/epics/rng-event-log/story-002-rng-service-seed-derivation-and-streams.md`, `production/epics/rng-event-log/story-004-no-global-rng-lint.md`

---

## Completion Notes
**Completed**: 2026-11-03
**Criteria**: 4/4 passing (none deferred)
- Golden pin — `rng_engine_pins_test.gd` (4 tests): 100-value seed-42 sequence pinned in full, recorded on 4.7.2.stable.official.ed1daf0bf; first five `492690617, 1919685028, 3561993920, 683038915, 1183706632`.
- `weighted_pick([5, 0, 15])` × 10,000 — `rng_stream_test.gd::test_weighted_pick_ten_thousand_draws_match_weights`.
- `fork("x")` twice — `test_fork_twice_returns_same_child_and_costs_one_parent_draw` (+ F3 seed cross-checked against `TestRngStream.fork_seed`).
- Exact draw counts, invalid inputs and the F4 trace — the `randi_range` / `randf` / `shuffle` / `weighted_pick` tests in `rng_stream_test.gd`. Invalid inputs assert in debug (the assert sits in `_reject`, so the caller still returns its fallback with no draw) and `push_error` in release; tests check the return value and `draws` in both build types.
**Deviations**: None blocking. Engine finding (ADVISORY): on 4.7.2 a bare `randi_range(...)` call inside a class that defines `randi_range` resolves to the `@GlobalScope` utility — the global RNG, no draw counted. Observed failing (F4 trace: `draws == 0`, array shuffled by the global RNG) before `shuffle` / `weighted_pick` were changed to `self.randi_range(...)`. Relevant to Story 004's lint (a bare call inside `src/core/rng/` is exempt from it) and to `docs/engine-reference/godot/` (not edited — out of scope).
**Test Evidence**: `tests/unit/rng_event_log/rng_engine_pins_test.gd`, `tests/unit/rng_event_log/rng_stream_test.gd`
**Run result**: N/A — `RngStream` is a `RefCounted` class with no scene, node or output a player can see; it is first drawn from by Story 002+ consumers.
**Reviewed by**: self, no independent review (Lean mode: QL-TEST-COVERAGE and LP-CODE-REVIEW skipped; engine-specialist check NOT ASSESSED — no agent available; `/code-review` still to run before sprint close-out)
