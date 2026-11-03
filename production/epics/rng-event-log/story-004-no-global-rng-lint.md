# Story 004: No-global-RNG lint (`tools/lint/no_global_rng.sh`) in CI

> **Epic**: RNG & Event Log
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-03

## Context

**GDD**: `design/gdd/rng-event-log.md`
**Requirement**: `TR-rng-event-log-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Seeded RNG Service and Event Log (also ADR-0001: Rules / Presentation Split — gate G6 is the same gate script family)
**ADR Decision Summary**: The CI lint `tools/lint/no_global_rng.sh` greps `src/` excluding `src/ui/` and `src/core/rng/` with the regex `(^|[^.\w])(randi|randf|randi_range|randf_range|seed|randomize)\(|\.shuffle\(\)|\.pick_random\(|RandomNumberGenerator\.new\(` (bare global `randi(`, `randf(`, `randi_range(`, `randf_range(`, `seed(`, `randomize(`, argument-less `.shuffle()`, `.pick_random(`, `RandomNumberGenerator.new(`; ADR-0003 erratum 2026-11-03, code review — never the injected `stream.randf()` / `stream.randi_range(…)` / `stream.shuffle(deck)`); any hit fails the build; the one permitted entropy call (Run Structure's run-creation command, F1 empty-seed branch) is allow-listed by path.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (general) / LOW for this story
**Engine Notes**: No engine API beyond `OS.execute` for the headless test runner; ripgrep 14.1.0 is installed and has no `gdscript` type, so use `rg --glob "*.gd"` (ADR-0001 Decision 6; engine-validation erratum: no look-around patterns).

Rule 7 is the determinism contract's enforcement point (TD-007: one shared sequence shifting every later draw). The gate is a distinctive token list, not a word, and is run once against a deliberately broken file before it is trusted (ADR-0001 Decision 6).

**Control Manifest Rules (this layer)**:
- Required: tests under `tests/unit/**` construct rules objects with `TestRngService` directly; `randi32()` is the only generator call and only inside `src/core/rng/`.
- Forbidden: never a global seeded RNG (`seed()` + `randi()` / `Array.shuffle()`); never draw in `_init`, in UI code, or in idle frames.
- Guardrail: none (tooling).

---

## Acceptance Criteria

*From GDD `design/gdd/rng-event-log.md` (rule 7, Acceptance Criteria "CI lint") and ADR-0003 Decision 10(b), scoped to this story:*

- [x] **GIVEN** the rules source tree (`src/` excluding `src/ui/` and `src/core/rng/`), **WHEN** `tools/lint/no_global_rng.sh` greps with the regex `(^|[^.\w])(randi|randf|randi_range|randf_range|seed|randomize)\(|\.shuffle\(\)|\.pick_random\(|RandomNumberGenerator\.new\(`, **THEN** it exits 0 with zero matches on the current tree, and exits non-zero naming file and line when a match exists. A call on an injected stream (`stream.randf()`, `stream.randi_range(1, 6)`, `stream.shuffle(deck)`) is never a match. The only allow-listed path is Run Structure's run-creation command file (the F1 empty-seed entropy call); the allow-list is a path list inside the script, not a pattern exemption.
- [x] **Trusted once broken:** `tests/unit/rng_event_log/rng_lint_test.gd` runs the script headless against a temporary fixture tree containing one deliberately offending file (`randi()` under a `gameplay/` path) and asserts a non-zero exit, then against a clean fixture tree — which includes the injected-stream calls `stream.randf()`, `stream.randi_range(1, 6)` and `stream.shuffle(deck)` — and asserts exit 0.
- [x] **CI-blocking:** `.github/workflows/tests.yml` runs `bash tools/lint/no_global_rng.sh` before the gdUnit4 run and a hit fails the job; no rules test under `tests/` uses global RNG (the same grep over `tests/unit/` and `tests/integration/`, excluding `tests/helpers/test_rng_stream.gd` and `tests/unit/rng_event_log/rng_engine_pins_test.gd`, returns zero matches).

> **AC amendment (2026-11-03, implementation):** the tests-scope grep as written failed on today's correct tree with two matches — `tests/unit/rng_event_log/rng_stream_test.gd:50` (`RandomNumberGenerator.new()`, the RngStream suite comparing the wrapper with a raw seeded generator, the same purpose as the engine-pin suite) and `tests/unit/card_effects/card_effects_dsl_spike_test.gd:109` (a `#` comment quoting the F4 example `randi_range(0,7)`). The scope is corrected, not the tests: the excluded list is `tests/unit/rng_event_log/rng_engine_pins_test.gd`, `tests/unit/rng_event_log/rng_stream_test.gd` and `tests/integration/rng_event_log/rng_lint_test.gd` (it holds the planted violations as data), and comment lines (`^\s*#`) are dropped from the tests-scope hits only. `tests/helpers/test_rng_stream.gd` is outside `tests/unit/` and `tests/integration/` already. The `src/` scope and the regex are exactly ADR-0003's erratum. Per the QA note the test lives at `tests/integration/rng_event_log/rng_lint_test.gd` (AC-2's `tests/unit/…` path superseded).

---

## Implementation Notes

*Derived from ADR-0003 Implementation Guidelines and Decision 10(b), ADR-0001 Decision 6:*

- `tools/lint/no_global_rng.sh`: `rg --glob "*.gd"` with the AC-1 regex (not a fixed-string list: `randf(` as a fixed string hits `stream.randf(`) over `src/`, `--glob '!src/ui/**' --glob '!src/core/rng/**'`, minus the allow-listed path(s); print hits; exit 1 on any hit. Keep it under the same conventions as the G1–G5 gate scripts the Boot & Composition Root epic adds under `tools/lint/` (one script per gate, look-around-free patterns).
- The allow-list names the Run Structure file that will hold `new_run` (`src/gameplay/run/run_machine.gd` per `architecture.md` §Directory layout) — until that file exists the entry is inert; document the reason beside it.
- `tests/unit/rng_event_log/rng_lint_test.gd`: build fixture trees under a temp directory (`DirAccess.make_dir_recursive_absolute`, `FileAccess` — allowed in tests), invoke the script with `OS.execute("bash", [...])` passing the tree root as an argument so the script's default root (`src/`) is overridable; assert exit codes. Helpers in `.claude/scripts/` emit observations; this lint is a CI gate and may fail the build (it is in `tools/`, not `.claude/scripts/`).
- Must not weaken the token list to avoid a hit: a hit in rules code is a bug to fix by injecting a stream.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Boot & Composition Root epic: gates G1–G5 and their CI wiring.
- Run Structure epic: the entropy call itself.

---

## Files

- `tools/lint/no_global_rng.sh` — created (ADR-0003 erratum regex over `src/` minus `src/ui/`, `src/core/rng/`, allow-list `src/gameplay/run/run_machine.gd`; tests scope `tests/unit/`, `tests/integration/` minus three listed suites, comment lines dropped; rg >= 14 guard; `[root]` argument)
- `.github/workflows/tests.yml` — modified (lint step runs `no_global_rng.sh` beside `gates.sh` and `parse-check.sh`, before gdUnit4)
- `tests/integration/rng_event_log/rng_lint_test.gd` (+ `.uid`) — created, 9 test functions (moved from `tests/unit/` per the QA note)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: standard` Logic tests are BLOCKING.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/rng_event_log/rng_lint_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] Created 2026-11-03 at `tests/integration/rng_event_log/rng_lint_test.gd` (QA note) — 9 test functions, passing (full suite `commands.test` 357/357, exit 0)

---

## Dependencies

- Depends on: `production/epics/rng-event-log/story-001-rng-stream-engine-pin-and-draw-primitives.md` (so `src/core/rng/` exists to be excluded and the tree is non-empty)
- Unlocks: None (every later rules epic runs under it)

> **QA note (2026-11-03, sprint-2 QA plan):** the lint test writes files and runs a subprocess, so it lives under `tests/integration/rng_event_log/`, not `tests/unit/` (testing standard: unit tests do no file I/O).

---

## Completion Notes

**Completed**: 2026-11-03
**Started / finished (UTC)**: 2026-11-03 21:11 — 2026-11-03 21:15
**Criteria**: 3/3 passing (none deferred)
**Deviations** (advisory):
- AC-3's tests-scope exclusion list was wrong for today's tree (see the dated AC amendment): two correct files matched. The scope was corrected in this story (two more excluded paths, comment lines dropped in the tests scope only); the `src/` scope and the regex are ADR-0003's erratum unchanged.
- Test path `tests/integration/rng_event_log/rng_lint_test.gd`, not `tests/unit/…` (QA note); fixtures are written under `user://rng_lint_fixture/` and deleted before and after each test.
- The script's argument is the project root (scanning `<root>/src` and `<root>/tests`), matching `gates.sh [root]`, rather than a `src/`-level root; same overridability.
- Open: `docs/engine-reference/godot/current-best-practices.md` §GDScript (4.7) says "the no-global-RNG lint must still catch the bare forms inside `src/core/rng/`", but ADR-0003 Decision 10(b) excludes `src/core/rng/` and the class's own `func randi_range(` definitions would be hits there. Followed the ADR; the `self.`-call rule inside `RngStream` stays covered by `rng_stream_test.gd`, not by this lint.
**Watched failing**: all 9 tests red with no script (exit 127); a planted `deck.shuffle()` in a scratch copy of the real `src/` + `tests/` → exit 1, `no_global_rng src/gameplay/match/rules_engine.gd:274:`. Nothing planted was committed.
**Verification**: `godot --headless --path . --import` exit 0; `commands.test` 357 test cases, 0 failures, exit 0 (24 SCRIPT ERROR lines, all the existing negative tests, unchanged from before the story); `commands.smoke` exit 0, no SCRIPT ERROR; `bash tools/lint/no_global_rng.sh` exit 0, 0 hits.
**Run result**: N/A — CI tooling; nothing a player can see changed.
**Test Evidence**: `tests/integration/rng_event_log/rng_lint_test.gd` (9 tests)
**Reviewed by**: self, no independent review (review_mode lean: QL-TEST-COVERAGE skipped — Lean mode; LP-CODE-REVIEW skipped — Lean mode)

> **Amendment (2026-11-03, rng-event-log 002 merge):** `tests/unit/rng_event_log/rng_service_test.gd` joins `TESTS_EXCLUDED` — it builds a raw seeded `RandomNumberGenerator` to compare the service against, the same reason `rng_stream_test.gd` is excluded.
