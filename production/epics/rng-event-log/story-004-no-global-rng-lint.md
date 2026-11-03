# Story 004: No-global-RNG lint (`tools/lint/no_global_rng.sh`) in CI

> **Epic**: RNG & Event Log
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/rng-event-log.md`
**Requirement**: `TR-rng-event-log-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Seeded RNG Service and Event Log (also ADR-0001: Rules / Presentation Split — gate G6 is the same gate script family)
**ADR Decision Summary**: The CI lint `tools/lint/no_global_rng.sh` greps `src/` excluding `src/ui/` and `src/core/rng/` for `randi(`, `randf(`, `randi_range(`, `randomize(`, `.shuffle(`, `.pick_random(`, `RandomNumberGenerator.new(`; any hit fails the build; the one permitted entropy call (Run Structure's run-creation command, F1 empty-seed branch) is allow-listed by path.
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

- [ ] **GIVEN** the rules source tree (`src/` excluding `src/ui/` and `src/core/rng/`), **WHEN** `tools/lint/no_global_rng.sh` greps for `randi(`, `randf(`, `randi_range(`, `randomize(`, `.shuffle(`, `.pick_random(` and `RandomNumberGenerator.new(`, **THEN** it exits 0 with zero matches on the current tree, and exits non-zero naming file and line when a match exists. The only allow-listed path is Run Structure's run-creation command file (the F1 empty-seed entropy call); the allow-list is a path list inside the script, not a pattern exemption.
- [ ] **Trusted once broken:** `tests/unit/rng_event_log/rng_lint_test.gd` runs the script headless against a temporary fixture tree containing one deliberately offending file (`randi()` under a `gameplay/` path) and asserts a non-zero exit, then against a clean fixture tree and asserts exit 0.
- [ ] **CI-blocking:** `.github/workflows/tests.yml` runs `bash tools/lint/no_global_rng.sh` before the gdUnit4 run and a hit fails the job; no rules test under `tests/` uses global RNG (the same grep over `tests/unit/` and `tests/integration/`, excluding `tests/helpers/test_rng_stream.gd` and `tests/unit/rng_event_log/rng_engine_pins_test.gd`, returns zero matches).

---

## Implementation Notes

*Derived from ADR-0003 Implementation Guidelines and Decision 10(b), ADR-0001 Decision 6:*

- `tools/lint/no_global_rng.sh`: `rg --glob "*.gd"` with a fixed-string token list over `src/`, `--glob '!src/ui/**' --glob '!src/core/rng/**'`, minus the allow-listed path(s); print hits; exit 1 on any hit. Keep it under the same conventions as the G1–G5 gate scripts the Boot & Composition Root epic adds under `tools/lint/` (one script per gate, look-around-free patterns).
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

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `tools/lint/no_global_rng.sh`
- `.github/workflows/tests.yml`
- `tests/unit/rng_event_log/rng_lint_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: standard` Logic tests are BLOCKING.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/rng_event_log/rng_lint_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/rng-event-log/story-001-rng-stream-engine-pin-and-draw-primitives.md` (so `src/core/rng/` exists to be excluded and the tree is non-empty)
- Unlocks: None (every later rules epic runs under it)
