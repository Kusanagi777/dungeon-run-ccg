# Story 002: RngService — seed derivation (F1–F3) and memoised named streams

> **Epic**: RNG & Event Log
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

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

- `src/core/rng/rng_service.gd`
- `src/core/rng/rng_stream.gd` (fork → `RngService.fork_seed`)
- `tests/unit/rng_event_log/rng_service_test.gd`
- `tests/helpers/test_rng_service.gd`, `tests/helpers/test_rng_stream.gd` (TODO(E1) swap)
- `tests/unit/framework/test_helpers_test.gd` (pins moved out)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: standard` Logic tests are BLOCKING.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/rng_event_log/rng_service_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/rng-event-log/story-001-rng-stream-engine-pin-and-draw-primitives.md`
- Unlocks: `production/epics/rng-event-log/story-003-snapshot-restore-and-command-guard.md`
