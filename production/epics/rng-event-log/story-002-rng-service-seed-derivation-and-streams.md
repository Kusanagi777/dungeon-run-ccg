# Story 002: RngService — seed derivation (F1–F3) and memoised named streams

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
**ADR Decision Summary**: One injected `RefCounted` service created with `(run_seed, data_version)`; `stream(name)` validates the rule 3 pattern, creates on first use and returns the same object thereafter; stream seeds are FNV-1a 64 over `le_bytes8(run_seed) ++ utf8(name)` then the SplitMix64 finaliser, computed in signed `int`; 64-bit values cross JSON as 16-hex strings.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH / NOT SOURCEABLE
**Engine Notes**: Signed-int64 wraparound of the F2/F3 constants is not sourceable from the engine reference; observed 2026-11-03 (probe D7) — the GDD example values were reproduced bit-exactly, and `TestRngStream` already carries that arithmetic. `JSON.parse_string` returns `float` for every number and loses precision above 2^53 (probe E) — hence `run_seed_hex`. Typed Arrays; explicit `return` on typed overrides (4.7).

The service is the object every rules module receives (DD-T03). This story gives it seed derivation, stream naming, memoisation and the hex helpers; `snapshot()` / `restore()` are Story 003. `tests/helpers/test_rng_service.gd` is the behavioural reference; its `TODO(E1 story)` swap (seeded mode → production class) is a type change made here, keeping the scripted and constant modes as doubles (ADR-0001 Implementation Guidelines).

**Control Manifest Rules (this layer)**:
- Required: every class under `src/core/**` `extends RefCounted`, collaborators through `_init(...)`; `stream(name)` is memoised; seeds are FNV-1a 64 + SplitMix64 finaliser in signed `int` with `>>>` emulated; 64-bit values cross JSON as 16-hex strings (`run_seed_hex`); tests under `tests/unit/**` construct `TestRngService` / rules objects directly, never through `Boot`.
- Forbidden: never a global seeded RNG; never one `RandomNumberGenerator` with streams as counters; never reference `Boot` or `Services` from `src/core/**`; never trust `JSON.parse_string` to return an `int`; never draw in `_init`.
- Guardrail: none specific beyond Story 010's budgets.

---

## Acceptance Criteria

*From GDD `design/gdd/rng-event-log.md` (rules 1–3, 6; F1, F2, F3; Edge Cases "Seeds", "Streams"), scoped to this story:*

- [ ] **GIVEN** two services created with `run_seed = 42`, **WHEN** `stream("run").randi_range(0, 65535)` is called 100 times on each, **THEN** the two 100-value sequences are identical and each stream reports `draws == 100` (F2, F4, rule 6).
- [ ] **GIVEN** `run_seed = 42`, **WHEN** `stream_seed` is computed for `run`, `match_1`, `match_2`, `draft_1`, `ai_1`, **THEN** the values equal the F2 example exactly (`60FB31FFA0FECE9A`, `8E28D71DC7508C82`, `3FC25FB4D7E5C7F5`, `FFC74EA120AA040F`, `89527D2C36D9A252`), and `run_seed = 0` gives `run → 8AE616A7F56EA560` (Edge Cases: seed 0 is valid).
- [ ] **F1 run seed from input:** `run_seed_from_input("42", entropy)` → `000000000000002A`; `"-1"` → `FFFFFFFFFFFFFFFF`; `"deckdelve"` → `48A10CC0B2ED54EC`; a 16-hex input (with or without `0x`) parses to the same bits; an empty or whitespace input calls the injected `entropy` Callable exactly once and every other input never calls it. `to_hex_u64(parse_hex_u64(h)) == h` for the three examples and for a value above 2^53.
- [ ] **Memoisation and names (rules 2–3, Edge Cases):** `stream("match_3")` called twice returns the same object with its draw position intact; a name outside `^[a-z]+(_[0-9]+)?(/[a-z0-9_]+)*$` pushes an error and is still served; `fork("x")` on a service stream is reachable as the memoised `"<parent>/x"` seeded by F3.

---

## Implementation Notes

*Derived from ADR-0003 Implementation Guidelines and Decision 1–2, 4, 10(d):*

- `src/core/rng/rng_service.gd`: `class_name RngService extends RefCounted`; `_init(run_seed: int, data_version: String)`; `stream(name: String) -> RngStream` memoised in a Dictionary. No draw in `_init`.
- Static derivations: `stream_seed_for(run_seed, name) = mix64(fnv1a64(le_bytes8(run_seed) ++ utf8(name)))`; `fork_seed(parent_draw, parent_name, label) = mix64(fnv1a64(le_bytes8(parent_draw) ++ utf8(parent_name + "/" + label)))`; `fnv1a64` offset basis `0xCBF29CE484222325` and prime `0x00000100000001B3`, SplitMix64 multipliers `0xBF58476D1CE4E5B9` / `0x94D049BB133111EB`, all written as their signed equivalents; `>>>` as `(x >> n) & ((1 << (64 - n)) - 1)`. Story 001's `RngStream.fork` calls `RngService.fork_seed` once this exists.
- `run_seed_from_input(input: String, entropy: Callable) -> int` (F1): trim; empty → `entropy.call()` (the only permitted global-entropy call in the project, and it lives in Run Structure's run-creation command — this service only invokes the Callable it is handed); `^(0x)?[0-9A-Fa-f]{16}$` → `parse_hex_u64`; `^-?[0-9]{1,19}$` → `parse_i64 mod 2^64` (negative decimal becomes the two's-complement pattern); otherwise `fnv1a64(utf8(input))`.
- `to_hex_u64(v) -> String` (16 uppercase hex digits, unsigned view) and `parse_hex_u64(hex16) -> int`; these are the project-wide form for every persisted 64-bit value (ADR-0004 inherits the rule).
- Must never obtain the service through `Boot`, a static or an autoload; `RunMachine` / `MatchDriver` construct it on the rules side, tests construct it directly with a literal seed.
- Move the helper self-test's F1/F2 example pins (`test_stream_seed_matches_gdd_f2_examples`, `test_run_seed_from_input_matches_gdd_f1_examples` in `tests/unit/framework/test_helpers_test.gd`) into `tests/unit/rng_event_log/rng_service_test.gd` so they run against the production class on every engine bump (ADR-0003 Decision 10(d)); leave the helper's own double tests in place.
- Swap `TestRngService.stream()` / `TestRngStream.seeded()` to construct the production `RngStream` (type change, not a rename — ADR-0001); keep `scripted` and `constant` modes as doubles.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: `RngStream` draw primitives and the engine pin.
- Story 003: `snapshot()` / `restore()`, `begin_command()` / `end_command()`, `snapshot_to_json_dict()` / `snapshot_from_json_dict()`.
- Run Structure epic: the one entropy call (`new_run` command) and the hero-select seed field.

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/core/rng/rng_service.gd` — created (`_init(run_seed, data_version)`, memoised `stream()`, `has_stream()`, `_make_stream()` seam; statics `run_seed_from_input`, `stream_seed_for`, `fork_seed`, `fnv1a64`, `mix64`, `ushr64`, `le_bytes8`, `to_hex_u64`, `parse_hex_u64`, `is_valid_stream_name`)
- `src/core/rng/rng_stream.gd` — modified (fork seeds via `RngService.fork_seed`; `_make_child()` seam; the private F3 arithmetic and the FNV / SplitMix constants moved to `RngService`)
- `tests/unit/rng_event_log/rng_service_test.gd` — created (19 test functions, incl. the F1/F2 pins moved from the helper self-test)
- `tests/helpers/test_rng_service.gd` — `TestRngService extends RngService` (TODO(E1) swap)
- `tests/helpers/test_rng_stream.gd` — `TestRngStream extends RngStream`; seeded mode is the production generator, scripted/constant kept as doubles (TODO(E1) swap)
- `tests/unit/framework/test_helpers_test.gd` — F1/F2 pins moved out; 2 tests added (delegation, production types)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: standard` Logic tests are BLOCKING.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/rng_event_log/rng_service_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] Created — `tests/unit/rng_event_log/rng_service_test.gd` (19 tests, passing)

---

## Dependencies

- Depends on: `production/epics/rng-event-log/story-001-rng-stream-engine-pin-and-draw-primitives.md`
- Unlocks: `production/epics/rng-event-log/story-003-snapshot-restore-and-command-guard.md`

---

## Completion Notes
**Completed**: 2026-11-03
**Started / ended (UTC)**: 2026-11-03T21:21:38Z – 2026-11-03T21:29:00Z
**Criteria**: 4/4 passing (all covered by unit tests; no deferred items)

| Criterion | Covered by | Status |
|-----------|------------|--------|
| AC-1: two services seeded 42 → identical 100-value `randi_range(0, 65535)` sequences, `draws == 100` | `rng_service_test.gd::test_two_services_seeded_42_draw_identical_100_value_run_sequences`, `test_service_stream_is_seeded_by_f2_stream_seed`, `test_construction_takes_no_draw_and_keeps_seed_and_data_version` | COVERED |
| AC-2: F2 example seeds for `run`, `match_1`, `match_2`, `draft_1`, `ai_1`; seed 0 → `8AE616A7F56EA560` | `test_stream_seed_matches_gdd_f2_examples`, `test_seed_zero_is_valid_and_matches_the_f2_example`, `test_fnv1a64_intermediate_matches_the_f2_example` | COVERED |
| AC-3: F1 examples, hex with/without `0x`, entropy called exactly once for empty/whitespace and never otherwise, hex round trip incl. > 2^53 | `test_run_seed_from_input_matches_gdd_f1_examples`, `test_sixteen_hex_digits_with_or_without_0x_parse_to_the_same_bits`, `test_decimal_input_is_taken_mod_two_pow_64`, `test_a_twenty_digit_number_and_other_text_take_the_fnv_branch`, `test_empty_or_whitespace_input_calls_entropy_exactly_once`, `test_non_empty_input_never_calls_entropy`, `test_hex_round_trip_holds_for_the_f1_examples_and_above_two_pow_53`, `test_parse_hex_u64_rejects_anything_but_sixteen_hex_digits` | COVERED |
| AC-4: memoised `stream("match_3")`, bad name pushes an error and is served, `fork("x")` memoised as `"<parent>/x"` seeded by F3 | `test_the_same_stream_name_returns_the_same_object_with_its_position_intact`, `test_a_name_outside_the_rule_3_pattern_is_reported_and_still_served`, `test_rule_3_names_in_the_v1_table_are_valid`, `test_fork_on_a_service_stream_is_the_memoised_child_seeded_by_f3`, `test_fork_seed_is_the_f3_formula` | COVERED |

**Deviations**:
- ADVISORY — helper swap by inheritance: `TestRngStream extends RngStream`, `TestRngService extends RngService` (ADR-0003 Migration Plan: "wrap or extend"). Seeded mode is now the production generator, draw primitives and fork rule; scripted/constant remain doubles overriding `randi32()`; `calls` records top-level calls only. Two construction seams were added to production for this — `RngService._make_stream()` and `RngStream._make_child()` (a scripted parent forks a scripted child). Existing callers are unchanged (`MatchFactory`, `RunFactory`, the card-effects spike, the match-rules data-model tests, the helper self-test). Behaviour change for doubles: bad ranges / weights / fork labels now assert in debug (production rule) instead of `push_error`; no existing test relied on the old form.
- ADVISORY — `RngStream`'s public `FNV_OFFSET_BASIS` / `FNV_PRIME` / `MIX_MULT_A` / `MIX_MULT_B` moved to `RngService` (no caller referenced them on `RngStream`); `RngService` also gains `has_stream()`, `is_valid_stream_name()` and public `run_seed` / `data_version` fields (the helper's surface).
- ADVISORY — `parse_hex_u64` rejects anything but exactly 16 hex digits with `push_error` and returns 0 (data fault, never an assert); the decimal F1 branch is computed by explicit wrapping digit accumulation (mod 2^64) rather than relying on `String.to_int()`'s unsourced overflow behaviour (observed to agree on 4.7.2).
- Open (story 003): `stream("ai_1/x")` asked of the service directly is an F2 stream, not the F3 fork `stream("ai_1").fork("x")` of the same name; rule 3 allows the name. Snapshot/restore of fork streams should settle which one a name means.
**Test Evidence**: `tests/unit/rng_event_log/rng_service_test.gd` — 19 tests; mutations (memoisation off, entropy called twice) seen failing (exit 100) before restore; a `String.to_int()` mutation of the decimal branch passed (equivalent on 4.7.2 — the test pins the behaviour either way). Full suite 418/418 passed, exit 0; 30 SCRIPT ERRORs, none new (baseline intentional negatives). Smoke exit 0, no SCRIPT ERROR.
**Run result**: N/A — the service has no scene, node or screen; nothing is drawn or launched (the seed field and its hex display are Run UI's).
**Engine check**: NOT ASSESSED — no specialist agent in this lane; int64 wraparound is pinned by the F2 example tests on 4.7.2; subclass override with a covariant return type and `super()` calls observed to parse and run on 4.7.2.
**Reviewed by**: self, no independent review (`review_mode: lean` — QL-TEST-COVERAGE and LP-CODE-REVIEW skipped; `/code-review` not run in this lane)

**Code review fixes** (2026-11-03, started 2026-11-03T22:02:30Z, finished 2026-11-03T22:06:00Z UTC; `/code-review` sprint 2, RNG-002 on `fix/review-sprint2`):
- should-fix fixed — `TestRngStream.restore()` clears the fork memo (`_forks`); production `RngStream` caches forks but has no `restore()` yet (story 003), so its `_forks` doc now states that restore must clear it. New test `test_fork_after_stream_restore_matches_a_fresh_run` (`tests/unit/framework/test_helpers_test.gd`).
- nit fixed — `RngService.run_seed` / `data_version` are read-only properties over private fields (a write is `push_error` and ignored); `TestRngService.restore` writes the backing field. New test `test_run_seed_and_data_version_are_read_only`.
- judgement applied — `stream(name)` takes root names only (`ROOT_STREAM_NAME_PATTERN` `^[a-z]+(_[0-9]+)?$`): a `/` name is refused like `fork("a/b")` (`_reject`, `null`, no stream). Other off-pattern names keep "logged, still served" (Decision 2). Rule added to rng-event-log GDD rule 3; dated erratum in ADR-0003's Status block. New tests `test_stream_refuses_a_fork_path_name_and_creates_no_stream` (negative, 4 names) and `test_the_fork_path_name_is_reachable_only_through_fork`; suite now 22. Seen failing against the unfixed code first.
