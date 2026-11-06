# Story 005: Grep gates G1–G6 and the per-file parse check in CI

> **Epic**: Boot & Composition Root
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-03

## Context

**GDD**: — (no system GDD; `docs/architecture/architecture.md` §Dependency injection and the composition root "Enforcement" paragraph; §Tech-debt retirement mapping rows TD-001, TD-002, TD-005, TD-006, TD-007, TD-010; `docs/tech-debt-register.md`)
**Requirement**: `TR-tech-debt-001` (also `TR-design-decisions-001`)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Rules / Presentation Split (Decision 6 — the gate table, incl. the G2b erratum of 2026-11-03; Implementation Guidelines — per-file parse check)
**ADR Decision Summary**: Six grep gates (`rg --glob "*.gd"`) and a per-file parse check enforce the rules / presentation split in CI: no Node in rules (G1), no tree access or coroutines in rules (G2, G2b), no composition root in rules (G3), exactly one autoload named `Boot` (G4), UI never mutates state (G5), no global RNG in rules (G6, owned by ADR-0003); each gate is a distinctive token and the gate script is run once against a deliberately broken file before it is trusted.
**ADR Version**: 2026-11-03 (ADR-0001 `Last Verified` 2026-11-03 — the G2b erratum is in that version)

**Engine**: Godot 4.7.2 | **Risk**: HIGH (ADR-0001's rating; the gate script's own engine exposure is `godot --headless -s` + `--import`, both LOW, and ripgrep 14.1.0 regex syntax — not an engine API)
**Engine Notes**: ripgrep 14 rejects look-around (`(?!…)`, exit 2) — the G2b `src/ai/**` rule is the look-around-free deny list (engine validation 2026-11-03, ADR-0001 erratum). `.claude/scripts/godot-parse-check.gd` must run after `godot --headless --path . --import` (class cache) and loads scripts in `_initialize()` so autoload lookups resolve; `--check-only` is not equivalent (it compiles with no autoloads registered). The first import on a clean machine may exit 139; `tests.yml` already imports twice. ADR-0001 verification 2: the per-file check is what proves rules files load with no autoload present.

**Control Manifest Rules (this layer)**:
- Required: Every rules file passes `.claude/scripts/godot-parse-check.gd` on its own (no autoload present) — ADR-0001
- Required: `project.godot [autoload]` contains exactly `Boot` (gate G4) — ADR-0001
- Forbidden: Never reference `Boot` or `Services` from `src/gameplay/**`, `src/ai/**`, `src/core/**` (minus `boot.gd`, `services.gd`, `boot_result.gd`; doc-comment lines `^\s*##` dropped) — gate G3; never rules as `Node`s (G1); never a global seeded RNG (G6) — ADR-0001, ADR-0003
- Forbidden: Never a second autoload — gate G4 — ADR-0001
- Guardrail: none (CI tooling; no frame budget)

---

## Acceptance Criteria

*From ADR-0001 Decision 6 (gate table) and Implementation Guidelines, and `docs/architecture/architecture.md` §Dependency injection "Enforcement", scoped to this story:*

- [x] `tools/lint/gates.sh` runs G1, G2, G2b, G3, G5 and G6 with `rg --glob "*.gd"` over exactly the scopes in ADR-0001 Decision 6 (G2/G2b exclude `src/core/boot.gd`; G3 excludes `src/core/boot.gd`, `src/core/services.gd` and `src/core/boot_result.gd` and drops hit lines that are doc comments — `rg … | rg -v '^[^:]+:[0-9]+:\s*##'`, since ripgrep 14 has no look-around; G6 is `(^|[^.\w])(randi|randf|randi_range|randf_range|seed|randomize)\(|\.shuffle\(\)|pick_random\(`, so `stream.randf()` / `stream.randi_range(…)` / `stream.shuffle(deck)` are not hits and bare `randi_range(` / `randf_range(` / `seed(` are (ADR-0001 erratum 2026-11-03, code review); G2b under `src/gameplay/**` and `src/core/**` is `\bawait\b`, under `src/ai/**` it is the look-around-free deny list `\bawait\b.*(get_tree|process_frame|physics_frame|create_timer|\.timeout|\.finished|tween|signal)`), prints every hit as `<gate> <file>:<line>` and exits non-zero on any hit, zero on a clean tree; it refuses to run (exit 2 with a message) when `rg` is absent or older than 14.
- [x] G4 asserts exactly one `^[A-Za-z_]+=` line under `[autoload]` in `project.godot`, named `Boot`; G5 asserts zero hits of `MatchState|RunState` under `src/ui/**` and `\.submit\(` only in `*_controller.gd`, `*_driver.gd` and `*_view.gd` there.
- [x] `tools/lint/parse-check.sh` runs `.claude/scripts/godot-parse-check.gd` once per script (one `godot --headless --path . -s … -- <one path>` invocation per file, so each file is proven alone) over every `.gd` under `src/gameplay/**`, `src/ai/**` and `src/core/**`, and fails on any `PARSE FAIL` line or non-zero exit.
- [x] Every gate has been watched failing: `tests/integration/boot/boot_lint_gates_test.gd` runs `gates.sh` (via `OS.execute`) against each deliberately broken fixture under `tests/fixtures/lint/<gate>/` and asserts a non-zero exit naming that gate, then against the real tree and asserts zero; `.github/workflows/tests.yml` runs both scripts as one blocking step after the import and before the gdUnit4 run.

---

## Implementation Notes

*Derived from ADR-0001 Decision 6 and Implementation Guidelines:*

- Gate table to transcribe exactly (ADR-0001 Decision 6; read it from the ADR at implementation, do not retype from this story): G1 `extends (Node|Control|Node2D|CanvasItem|Timer)` in `src/gameplay/**`, `src/ai/**`; G2 `get_tree\(|get_node\(|\$[A-Za-z%]|%[A-Z]|queue_free|add_child` in `src/gameplay/**`, `src/ai/**`, `src/core/**` minus `boot.gd`; G2b as in AC-1; G3 `\bBoot\b|\bServices\b` in the G2 scope minus also `services.gd` and `boot_result.gd`, doc-comment lines (`^\s*##`) dropped; G4 autoload count; G5 UI patterns; G6 `(^|[^.\w])(randi|randf|randi_range|randf_range|seed|randomize)\(|\.shuffle\(\)|pick_random\(` in `src/gameplay/**`, `src/ai/**` (owned by ADR-0003, same script; both corrected by the ADR-0001 erratum 2026-11-03, code review). The G3 and G6 fixtures each include a must-not-hit line (`## Boot` doc comment; `stream.randf()`) beside the planted violation.
- Scope the fixture run with an explicit root argument (`gates.sh [root]`, default `.`), so the test can point the script at `tests/fixtures/lint/<gate>/` laid out as a miniature `src/` tree plus a `project.godot` with two autoloads for G4. Fixtures are data for the test; `production/.gdignore`-style exclusion is not needed (they are `.gd` files Godot may import harmlessly) — but keep them out of the real gate scope by path.
- Empty scopes: on the day this lands `src/gameplay/` and `src/ai/` may hold only `meta_api.gd` / `meta_stub.gd`; `rg` on a non-existent directory exits 2 — guard each scope with an existence check and treat an absent directory as 0 hits.
- `ubuntu-latest` ships ripgrep; the version guard (≥ 14, for the regex engine the erratum was validated on) prints the installed version so a runner image change is visible in the log. `tools/setup.sh` is not changed unless `rg` turns out to be missing on the runner.
- `parse-check.sh` depends on the class cache: run it in `tests.yml` after the two `--import` steps. It passes each path with the `res://` prefix the script expects and collects exit codes; print `ok:` lines too so the step log shows what was checked.
- Do not fold the gates into a gdUnit4 suite as the only runner: CI must fail on a gate hit even when no test discovers it. The gdUnit4 integration test exists to prove the script's own behaviour (the "watched fail"), not to replace the CI step.
- `.claude/rules/test-standards.md`: integration tests clean up after themselves — `OS.execute` leaves nothing behind here; use no `user://` paths.
- TD rows this story retires (architecture.md §Tech-debt retirement mapping): TD-001 (grep-gated single autoload), TD-002 (parse check per file in CI), TD-005 (G1 + `queue_free` only under `src/ui/`), TD-006 (G5), TD-007 (G6), TD-010 (parse check catches orphans). Cite them in the commit body.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 004: `boot.gd` and the `[autoload]` entry the G4 gate expects.
- ADR-0002's data gates (`tools/content/validate.gd`, "no JSON parse outside `CardDatabase`") — Card Database epic.
- Windows export job in CI (gate condition 8) — Match UI epic / `/release-checklist`.
- ADR-0006's `await <planner>.checkpoint()` allow-list semantics beyond the deny-list regex — Boss AI epic validates its own coroutine shape against G2b when its first file lands.

---

## Files

- `tools/lint/gates.sh` — created (G1, G2, G2b, G3, G4, G5, G6; `[root]` argument; rg >= 14 guard)
- `tools/lint/parse-check.sh` — created (one `godot-parse-check.gd` run per file under `src/gameplay`, `src/ai`, `src/core`)
- `.github/workflows/tests.yml` — modified (step "Install ripgrep >= 14"; blocking step "Lint gates G1-G6 and per-file parse check" after the imports, before gdUnit4)
- `tests/integration/boot/boot_lint_gates_test.gd` (+ `.uid`) — created, 11 test functions
- `tests/fixtures/lint/` — created: `.gdignore`; `g1`, `g2`, `g2b`, `g3`, `g4`, `g4_wrong_name`, `g5`, `g6` miniature trees (each a `project.godot` and/or `src/` with one planted violation plus must-not-hit files); `fake_rg13/rg` (version-guard fixture)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level` (`standard`): tests must exist and pass.*

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/boot/boot_lint_gates_test.gd` — must exist and pass; plus a green `tests.yml` run whose lint step log shows each gate reported 0 hits and each rules file `ok:`

**Status**: [x] Created 2026-11-03 — 11 test functions, passing (full suite `commands.test` 348/348, exit 0); the green `tests.yml` run is pending the first push (not pushed from the lane)

---

## Dependencies

- Depends on: `production/epics/boot-composition-root/story-004-boot-composition-root.md` (G4 needs the real `[autoload]` entry; G3's `boot.gd` exclusion needs the file)
- Unlocks: `production/epics/boot-composition-root/story-007-boot-responsibilities-manifest.md`; every rules story in later epics (they are built against a green gate step)

> **QA note (2026-11-03, sprint-2 QA plan):** the CI job installs ripgrep ≥ 14 explicitly and prints `rg --version`; patterns per the ADR-0001 G2b/G3/G6 errata.

---

## Completion Notes

**Completed**: 2026-11-03
**Started / finished (UTC)**: 2026-11-03 21:00 — 2026-11-03 21:11
**Criteria**: 4/4 passing (none deferred)
**Deviations** (advisory):
- Fixtures sit behind `tests/fixtures/lint/.gdignore` although the Implementation Notes call that unnecessary: the planted files are deliberately wrong (a second `Services` class_name, scripts naming types that do not exist) and must not be imported, parsed or registered by Godot.
- Beyond the AC, `gates.sh` exits 2 (never 0) when rg itself errors or the root is missing, and prints `<gate> hits: <n>` for every gate so a gate that did not run is visible in the log; G4 also fails a single autoload not named `Boot` (fixture `g4_wrong_name`); the rg-missing and rg-13 refusals are tested (`fake_rg13/rg`).
- The CI ripgrep step installs from the Ubuntu archive unconditionally (QA note) rather than relying on the runner image as the Implementation Notes assumed; `tools/setup.sh` unchanged.
- The data-read gate (ADR-0002, `JSON.new(` / `JSON.parse_string`) is not in `gates.sh` — Out of Scope here; it stays the gdUnit4 suite `tests/unit/card_database/card_database_single_parser_test.gd`.
- Pending: the first green `tests.yml` run (the lane does not push); the same steps ran locally with ripgrep 14.1.0 and Godot 4.7.2.
**Patterns**: transcribed from ADR-0001 Decision 6 with its 2026-11-03 errata and the control manifest gate table; all 0 hits on the current tree, so no pattern correction was needed.
**Watched failing**: every gate on its fixture (the suite) and again on a planted violation in a scratch copy of the real `src/` + `project.godot` (G1 `extends Control`, G2 `queue_free()`, G2b `await` in `src/core/rng/` and `await get_tree().create_timer(…).timeout` in `src/ai/`, G3 `Services` in `meta_stub.gd`, G4 a second autoload, G5 `RunState` and `.submit(` in `boot_screen.gd`, G6 `randi_range(1, 6)` in `match_state.gd`) — each exit 1 naming its gate; `parse-check.sh` on a scratch copy of the project with a planted syntax error — exit 1, `PARSE FAIL: res://src/gameplay/match/broken_rule.gd`, 19 checked. Nothing planted was committed.
**Verification**: `godot --headless --path . --import` exit 0; `commands.test` 348 test cases, 0 failures, exit 0 (SCRIPT ERRORs only the existing negative tests); `commands.smoke` exit 0, no SCRIPT ERROR; `bash tools/lint/gates.sh` exit 0 (every gate 0 hits); `bash tools/lint/parse-check.sh` 18 checked, 0 failed.
**Run result**: N/A — CI tooling; nothing a player can see changed (no scene, script under `src/` or asset touched).
**TD retired**: TD-001, TD-002, TD-005, TD-006, TD-007, TD-010 (architecture.md §Tech-debt retirement mapping).
**Test Evidence**: `tests/integration/boot/boot_lint_gates_test.gd` (11 tests)
**Reviewed by**: self, no independent review (review_mode lean: QL-TEST-COVERAGE skipped — Lean mode; LP-CODE-REVIEW skipped — Lean mode; `/code-review` not run in the lane)
