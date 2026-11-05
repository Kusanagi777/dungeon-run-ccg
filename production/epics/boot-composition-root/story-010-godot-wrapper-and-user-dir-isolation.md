# Story 010: A committed Godot wrapper — `godot` resolution and a per-worktree `user://`

> **Epic**: Boot & Composition Root
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-11-04
> **Last Updated**: 2026-11-05
> **Readiness**: 2026-11-05 `/story-readiness` (by hand, sprint 6 pre-wave lane): **READY**. No GDD and no TR-ID, both stated with a reason (dev tooling; `no_tr_id` lint is the story's own recorded gap, advisory). ADR N/A with a reason; ADR-0001 and ADR-0004, cited as context, are Accepted. Manifest Version 2026-11-04 = manifest. Dependencies: none. 4 ACs, each observable. Two findings resolved from the docs, not gaps in the ACs: the Implementation Note's "if the framework does not read `engine.path`" is false for `project.yaml` (`test-run.sh` reads it through `yaml-get.awk`), so the wrapper reuses that reader; and `.gitignore`'s `bin/` would hide `tools/bin/godot`, so the un-ignore joins the Files list. QL-STORY-READY skipped — Lean mode.

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

- [x] GIVEN `tools/bin/godot` first on `PATH`, WHEN `godot --version` is run, THEN it executes the binary named by `$GODOT_BIN`, else the `engine.path` a developer set in the gitignored `project.local.yaml` (the place `.claude/docs/run-and-observe.md` "Finding the engine" names), else the next `godot` / `godot.exe` on `PATH` (never itself), and returns that process's exit code and output unchanged; with neither it exits 127 and the message names `GODOT_BIN`. No committed file contains a user-profile path (grep for `/c/Users`, `C:\\Users`, `Downloads`, `/home/`).
- [x] GIVEN two worktrees of this repository (or two different values of `GODOT_WORKTREE_KEY`), WHEN each runs `godot --headless --path . -s res://tools/ci/print_user_dir.gd` through the wrapper, THEN the two `OS.get_user_data_dir()` values differ, both lie outside the repository, a file written under `user://` in one is absent in the other, and two worktrees with the same directory name in different parents still get different keys (key = directory name + a short hash of the top-level path).
- [x] GIVEN export templates installed in the real user-data location, WHEN `godot --headless --path . --export-debug 'Windows Desktop' <out>` runs through the wrapper from an isolated worktree, THEN the export finds them and succeeds; and `tools/bin/godot --self-check` always prints the resolved binary, its version, the isolated user directory and whether the 4.7.2 templates are visible, naming the install step when they are not (templates absent is reported, not a failure; with none installed this AC reads NOT ASSESSED for the export half).
- [x] GIVEN `PATH="$PWD/tools/bin:$PATH"`, WHEN `commands.test` from `project.yaml` runs verbatim in two worktrees at the same time, THEN both finish with the same result and no suite reports a staged-`user://` clash; the clash is first reproduced without the wrapper, or its absence is recorded as NOT REPRODUCED; and `tests/README.md` gains a "Running Godot on a dev machine" section (resolution order, `GODOT_BIN`, `GODOT_USERDATA_ROOT`, `GODOT_WORKTREE_KEY`, bash required, PowerShell not covered).

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
- `tools/ci/print_user_dir.gd` (new, with its `.uid`)
- `tests/integration/boot/godot_wrapper_test.gd` (new, with its `.uid`)
- `tests/README.md` (new section)
- `.gitignore` (added 2026-11-05: `bin/` hid the wrapper, so `!tools/bin/` un-ignores it)
- `tools/setup.sh` (added 2026-11-05: one comment line in the header, no behaviour change; see Completion Notes)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above (QL-STORY-READY skipped — Lean mode).*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/boot/godot_wrapper_test.gd` — must exist and pass; plus a retained transcript of the two-worktree run and of `--self-check` in the story's Completion Notes.

**Status**: [x] Created; see Completion Notes

---

## Dependencies

- Depends on: None (`tools/setup.sh`, `project.yaml commands.*` and `tests/README.md` exist)
- Unlocks: `production/epics/boot-composition-root/story-011-windows-screenshot-capture.md`; every sprint 6 lane that runs `commands.test`, an import or an export on Windows (MUI-004 to MUI-012, BAI-016 to BAI-019, MR-019 and MR-018 close-out)
- **Sprint 6 placement**: before W1, with story 011 in one tools lane (a `general-purpose` agent in the tools-programmer role, about 2 links together), merged before any lane worktree is cut so each lane starts with it. If it slips, lanes keep the scratchpad shim and the risk is the accepted one in the plan (row 13 fix (c)); then it can land in L5 or L6 W1 and lanes adopt it at M1. Config/tool merge: no [S] or [C] conflict with other stories.

---

## Completion Notes
**Completed**: 2026-11-05
**Started / ended (UTC)**: 2026-11-05T16:28:55Z – 2026-11-05T17:28:06Z
**Criteria**: 4/4 passing, with AC-3's export half NOT ASSESSED (no 4.7.2 templates installed here, as the AC allows); the link it depends on is proven below
**Deviations**:
- **`.gitignore` changed (not in the story's original Files).** The `bin/` rule hid `tools/bin/godot`; `!tools/bin/` un-ignores it, beside the existing gdUnit4 exception.
- **`tools/setup.sh` gained one comment line, against the Implementation Note "Do not change `setup.sh` here".** The sprint 6 lane brief asked for the note: the header's "on Windows install Godot by hand" left a Windows developer with no next step. No behaviour changes, but `windows-export.yml` keys its template cache on `hashFiles('tools/setup.sh')`, so that job re-downloads the templates once.
- **AC-1's "no committed file" is read as the files this story owns.** `godot_wrapper_test.gd` holds `tools/`, `project.yaml` and `tests/README.md` to it. A repo-wide grep cannot be empty: this story quotes the patterns, and existing hits are left alone as out of scope (generic examples in `.claude/hooks/` and `.claude/skills/setup-engine/`, the cloud container's path in `production/qa/evidence/rig-check-2026-11-03/README.md` and `production/reviews/2026-11-04/lane-rules.md`, and vendored `addons/gdUnit4/test/`).
- **`engine.path` is read with `.claude/scripts/yaml-get.awk`, not a new one-line parser.** The note's condition ("if the framework does not read it") is false for `project.yaml`, where `test-run.sh` reads the key. The shared reader takes the nested form as well as one line. The wrapper is still the only reader of the key in `project.local.yaml`.
- **Additions the ACs did not name, each needed to work and each tested:** `project.local.yaml` falls back to the main checkout's, because a plain `git worktree add` has none; every copy of the wrapper is skipped on `PATH`, by a marker line, because two worktrees' `tools/bin` on one `PATH` would otherwise run each other for ever; an engine named by `GODOT_BIN` or `engine.path` that cannot run exits 127 rather than falling through; a root inside the repository exits 2; `--self-check` exits 1 when the engine ignores the isolation; `GODOT_WRAPPER_REAL_USERDATA` carries the real location to a wrapper started inside an isolated Godot.
- **The clash was reproduced with a shared `GODOT_WORKTREE_KEY`, not by running unwrapped.** It gives two runs the same user directory, which is the condition under test, without touching the real one that other lanes and the owner may be using.
- **Linux branch not run on Linux.** No Linux here. A scratch copy with the Windows branch forced off moved `XDG_DATA_HOME`, left `APPDATA` alone, reached the templates and passed the exit code through; `ln -s` is a copy in Git Bash, so the symlink itself is first exercised when this suite runs in CI. `tests.yml` does not use the wrapper for its own engine runs.
- **Guardrail not met as worded.** On Git Bash the wrapper adds about 0.2 s per launch against about 1.3 s for a headless engine script (stub direct 57 ms, through the wrapper 270 ms; `git rev-parse` alone 45 ms, `cygpath` 37 ms; measured with other lanes running). Most of it is the forks this story specifies; dropping `basename` and an every-run `mkdir` saved 75 ms. A `parse-check.sh` run (52 launches) pays about 10 s; a suite run pays it once.
- **Finding, built in:** Godot creates an empty `export_templates/` in a fresh data folder on first import, so without handling, templates installed later would never be linked. The wrapper replaces an empty folder and leaves one holding files.
- **Open point 2 resolved:** a fresh isolated directory has no editor settings, and `--import`, `--self-check`, the suite and an export attempt all ran without them. **Open point 1 stands:** PowerShell and cmd are not covered.
- **Open:** a hand-written `engine.path` in `project.local.yaml` makes `validate_local_scope` warn on skills' `notes:` line ("not locally overridable"), because the key is not on the `/settings --local` whitelist. The README says so and recommends `GODOT_BIN`; adding the key to the whitelist is a framework decision.

**Test Evidence**: `tests/integration/boot/godot_wrapper_test.gd`, 32 tests. 28 were seen failing against the missing wrapper. The other 4 passed vacuously there, so each was seen failing against a deliberate mutant, as were 6 more behaviours: reads committed `project.yaml`; key from the current directory; replaces a templates folder holding files; planted user-profile path; skips only itself (hangs, caught by the harness timeout); a folder counts as runnable; keeps the empty first-import folder; trusts inherited `APPDATA`; no main-checkout fallback; no inside-repository refusal. All 10 were caught and none is left. They ran before the two fork trims above, which the full suite covers. Gate on the final tree: import exit 0; `gates.sh`, `no_global_rng.sh`, `parse-check.sh` (52 checked, 0 failed) and `ai_code_gates.sh` exit 0; `commands.test` exit 0, `Overall Summary: 2377 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans`; `commands.smoke` exit 0, no `SCRIPT ERROR`.

Retained transcripts (paths shortened: `<TEMP>` is the system temp folder, `<ENGINE>` the engine folder, `<APPDATA>` the real user-data location).

`--self-check`, this lane, then the second worktree's user directory (same folder name, another parent):

```text
binary:    <ENGINE>/Godot_v4.7.2-stable_win64_console.exe (from GODOT_BIN)
version:   4.7.2.stable.official.ed1daf0bf
user dir:  <TEMP>/dungeon-run-ccg-userdata/s5-l2-bdcf6e58/Godot/app_userdata/Dungeon Run CCG
templates: NOT VISIBLE at <TEMP>/dungeon-run-ccg-userdata/s5-l2-bdcf6e58/Godot/export_templates/4.7.2.stable (only an export needs them)
           install: run the editor outside this wrapper, Editor > Manage Export Templates; they go to <APPDATA>/Godot/export_templates and the next run links them

user dir:  <TEMP>/dungeon-run-ccg-userdata/s5-l2-3e2c4a38/Godot/app_userdata/Dungeon Run CCG
```

AC-2, `print_user_dir.gd` through the wrapper in both worktrees, and a file written under one `user://`:

```text
lane:   <TEMP>/dungeon-run-ccg-userdata/s5-l2-bdcf6e58/Godot/app_userdata/Dungeon Run CCG
second: <TEMP>/dungeon-run-ccg-userdata/s5-l2-3e2c4a38/Godot/app_userdata/Dungeon Run CCG
differ: yes
lane outside repository: yes
second outside repository: yes
marker in lane: present
marker in second: absent
```

AC-3, the export half. No real templates exist here and none were downloaded, so a real export stays NOT ASSESSED. Placeholder files behind the link show Godot looks through the junction: with none it stops at the template check; with them it passes that check, reads the placeholder and fails only because it is not an executable.

```text
no templates:          exit 1  No export template found at the expected path: <TEMP>/dungeon-run-ccg-userdata/s5l2-noexport/Godot/export_templates/4.7.2.stable/windows_debug_x86_64.exe
placeholder via link:  exit 1  PCK Embedding: Executable file header corrupted.
--self-check:          templates: visible at <TEMP>/dungeon-run-ccg-userdata/s5l2-fakeexport/Godot/export_templates/4.7.2.stable
```

AC-4, `commands.test` verbatim in two worktrees at the same time. A first isolated run differed only in `test_wrapper_is_tracked_executable_and_lf`, because the wrapper was not yet tracked in the second worktree; it was staged there and the run repeated.

```text
Clash reproduced: both runs forced onto one user directory (GODOT_WORKTREE_KEY shared), 16:50:52-16:58:06 UTC
  lane:   exit 100  2346 test cases | 0 errors | 1 failures
  second: exit 100  2343 test cases | 2 errors | 2 failures
  second, boss_ai_profiles_data_test: [error] E_MISSING_FILE ai_profiles.json - cannot open user://boss_ai_profiles_data_test/ai_profiles.json
  (the other failures are godot_wrapper_test's own fixture, staged at one fixed user:// path in both runs)

Isolated: default keys, 17:08:03-17:15:01 UTC
  lane:   exit 0  2377 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans
  second: exit 0  2377 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans
```

**Reviewed by**: lean — `/code-review` runs independently at M0 (orchestrator)
