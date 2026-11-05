# Story 010: A committed Godot wrapper — `godot` resolution and a per-worktree `user://`

> **Epic**: Boot & Composition Root
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-11-04
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

Sprint 6 Goal Prerequisites row 13 and retro-5 action 4. On a developer machine `which godot` finds nothing, and the suites write fixed `user://` paths, so parallel lanes that share one user-data directory collide. In sprint 5 this was handled by a shim kept in the session scratchpad that set `APPDATA` per worktree and ran one machine's `Godot_v4.7.2-stable_win64_console.exe` by absolute path; `git ls-files` lists no wrapper. Suites that stage under `user://`: `boss_ai_profiles_data_test`, `card_effects_config_file_test`, `match_rules_config_file_test`, `event_log_config_file_test`, `rng_lint_test`, `card_database_reload_test`.

This story commits the wrapper so every lane and the owner run the same thing, with no path of any one machine in the repo. `project.yaml` `commands.*` keep saying `godot …` and run verbatim once the wrapper's directory is first on `PATH`.

**GDD**: no GDD (dev tooling). `tests/README.md` (how the suites run) · retro `production/retrospectives/retro-sprint-5-2026-11-05.md` action 4
**Requirement**: `TR-boot-???` — no registry row covers dev-environment tooling (the Boot epic lists only cross-cutting rows), so none is claimed; `/architecture-review` can add one if the owner wants it traced.
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: N/A — developer tooling, no architectural decision. Context only: ADR-0004 fixes `user://profile.json` and the files under `user://`, and ADR-0001 confines `user://` to `src/core/`, which is why the collision surface is the shared user-data directory and not any one system.
**ADR Version**: N/A

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM. Where Godot 4.7.2 resolves `user://` and where it looks for export templates on each OS is not documented under `docs/engine-reference/` (NOT SOURCEABLE there). The sprint-5 shim shows `APPDATA` moved `user://` on Windows; the self-check below proves it on each machine instead of assuming it.
**Engine Notes**: A console build (`…_console.exe`) is the one that prints to the terminal and returns exit codes to a calling shell on Windows; the shim used it. Exit codes pass through unchanged (139 on the TD-013 `--import` crash, and gdUnit4's own codes). Moving `APPDATA` also moves Godot's editor settings and `export_templates/`, so an isolated process finds no templates unless the wrapper makes the real ones visible (AC-3).

**Control Manifest Rules (Foundation layer, v2026-11-04)**:
- Required: only `src/core/**` opens `user://`; tests that stage under `user://` remove what they staged (`test-standards.md`: integration tests clean up).
- Forbidden: a machine's absolute path in any committed file; shell scripts with CRLF (`.gitattributes` keeps every text file LF).
- Guardrail: the wrapper adds no measurable start-up cost to a `--headless` run (one `git rev-parse` and a hash).

---

## Acceptance Criteria

*From sprint 6 row 13 and retro-5 action 4:*

- [ ] GIVEN `tools/bin/godot` first on `PATH`, WHEN `godot --version` is run, THEN it executes the binary named by `$GODOT_BIN`, else the `engine.path` a developer set in the gitignored `project.local.yaml` (the place `.claude/docs/run-and-observe.md` "Finding the engine" names), else the next `godot` / `godot.exe` on `PATH` (never itself), and returns that process's exit code and output unchanged; with neither it exits 127 and the message names `GODOT_BIN`. No committed file contains a user-profile path (grep for `/c/Users`, `C:\\Users`, `Downloads`, `/home/`).
- [ ] GIVEN two worktrees of this repository (or two different values of `GODOT_WORKTREE_KEY`), WHEN each runs `godot --headless --path . -s res://tools/ci/print_user_dir.gd` through the wrapper, THEN the two `OS.get_user_data_dir()` values differ, both lie outside the repository, a file written under `user://` in one is absent in the other, and two worktrees with the same directory name in different parents still get different keys (key = directory name + a short hash of the top-level path).
- [ ] GIVEN export templates installed in the real user-data location, WHEN `godot --headless --path . --export-debug 'Windows Desktop' <out>` runs through the wrapper from an isolated worktree, THEN the export finds them and succeeds; and `tools/bin/godot --self-check` always prints the resolved binary, its version, the isolated user directory and whether the 4.7.2 templates are visible, naming the install step when they are not (templates absent is reported, not a failure; with none installed this AC reads NOT ASSESSED for the export half).
- [ ] GIVEN `PATH="$PWD/tools/bin:$PATH"`, WHEN `commands.test` from `project.yaml` runs verbatim in two worktrees at the same time, THEN both finish with the same result and no suite reports a staged-`user://` clash; the clash is first reproduced without the wrapper, or its absence is recorded as NOT REPRODUCED; and `tests/README.md` gains a "Running Godot on a dev machine" section (resolution order, `GODOT_BIN`, `GODOT_USERDATA_ROOT`, `GODOT_WORKTREE_KEY`, bash required, PowerShell not covered).

---

## Implementation Notes

- `tools/bin/godot` is an extensionless bash script (mode 100755; LF through `.gitattributes`). Naming it `godot` is what lets `commands.*` run verbatim. It must skip itself when it searches `PATH`.
- **Isolation**: set `APPDATA` to `<root>/<key>` on Windows (Git Bash: `cygpath -w`), and `XDG_DATA_HOME` on Linux. `<root>` is `$GODOT_USERDATA_ROOT`, else a `dungeon-run-ccg-userdata` folder under the system temp directory; never inside the repository. `<key>` is `$GODOT_WORKTREE_KEY`, else `basename + short hash` of `git rev-parse --show-toplevel`. Do the Windows branch by detecting `OS`/`uname`, not by a path.
- **Templates (AC-3)**: with `APPDATA` moved, `…/Godot/export_templates/4.7.2.stable/` is empty. Make the real directory visible inside the isolated one (a junction on Windows needs no admin; a symlink on Linux) or point the wrapper at it another way the self-check can verify. Which mechanism Godot honours is not in the engine reference; the export run is the test.
- `tools/ci/print_user_dir.gd` is a 5-line `SceneTree` script that prints `OS.get_user_data_dir()` and quits. It lives under `tools/ci/` (not `src/`), so it is outside the rules tiers and the export.
- `tools/setup.sh` stays the Linux/CI installer. On Linux it already links `~/.local/bin/godot`; the wrapper resolves that through `PATH` and adds only isolation. Do not change `setup.sh` here.
- A test, `tests/integration/boot/godot_wrapper_test.gd`, runs the script through `OS.execute("bash", …)` with `GODOT_BIN` pointing at a stub script it writes under `user://`, to assert the resolution order, the exit-127 message, the key derivation and exit-code passthrough. The two-worktree and export runs are manual evidence (a retained transcript), because a gdUnit run cannot launch a second Godot with a different `APPDATA` reliably.
- The wrapper does not set `--path`; callers keep passing it.
- `engine.path` is read from `project.local.yaml` only, never from the committed `project.yaml`, which would put one machine's path in the repo. `project.yaml` has no `engine.path` today and `.claude/docs/effects-map.md` does not define the key; if the framework does not read it, the wrapper's small parser is the only reader, so keep it to one line of YAML and say so in the README section.

**Open points — flagged, not decided:**

1. **PowerShell/cmd.** A bash shebang script does not run from PowerShell or cmd. Lanes and the owner use Git Bash (the Bash tool); if the owner launches `godot` from PowerShell, a `.cmd` twin is needed. Not built here.
2. **Editor-settings isolation** moves with `APPDATA`: a fresh isolated directory has no editor settings. Believed harmless for `--headless` runs; the self-check run is where it shows.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The Windows screenshot path (`production/epics/boot-composition-root/story-011-windows-screenshot-capture.md`), which uses this wrapper's `godot`.
- Installing export templates on a machine (retro action 2, the owner's step); this story only reports whether they are visible.
- The CI debug-export artifact: `windows-export.yml` already exports and uploads `deckdelve-windows-debug-<sha>` (commit `bec8ede`, 2026-11-04). The debug/release preset split is `production/epics/match-ui/story-012-first-playable-windows-match.md`.

---

## Files

- `tools/bin/godot` (new)
- `tools/ci/print_user_dir.gd` (new)
- `tests/integration/boot/godot_wrapper_test.gd` (new)
- `tests/README.md` (new section)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above (QL-STORY-READY skipped — Lean mode).*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/boot/godot_wrapper_test.gd` — must exist and pass; plus a retained transcript of the two-worktree run and of `--self-check` in the story's Completion Notes.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (`tools/setup.sh`, `project.yaml commands.*` and `tests/README.md` exist)
- Unlocks: `production/epics/boot-composition-root/story-011-windows-screenshot-capture.md`; every sprint 6 lane that runs `commands.test`, an import or an export on Windows (MUI-004 to MUI-012, BAI-016 to BAI-019, MR-019 and MR-018 close-out)
- **Sprint 6 placement**: before W1, with story 011 in one tools lane (a `general-purpose` agent in the tools-programmer role, about 2 links together), merged before any lane worktree is cut so each lane starts with it. If it slips, lanes keep the scratchpad shim and the risk is the accepted one in the plan (row 13 fix (c)); then it can land in L5 or L6 W1 and lanes adopt it at M1. Config/tool merge: no [S] or [C] conflict with other stories.
