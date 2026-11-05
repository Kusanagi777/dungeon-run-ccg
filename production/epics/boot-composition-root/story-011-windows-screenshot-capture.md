# Story 011: A Windows screenshot path — `tools/capture.sh` without Xvfb, with the renderer recorded

> **Epic**: Boot & Composition Root
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-11-04
> **Last Updated**: 2026-11-05
> **Readiness**: 2026-11-05 `/story-readiness` (by hand, sprint 6 pre-wave lane): **READY**. ADR-0010 is Accepted and carries the DD-X32 erratum; stories 006 and 010 are Complete; three testable criteria, no open question in them. No GDD, stated with a reason (tooling). No qa-lead specs (Lean mode), so the tests come from the criteria. The review's DQ-2 (planner on a capture run) is not a criterion here; see Completion Notes.

## Context

Sprint 6 Goal Prerequisites row 12 and retro-5 action 4. Coding standards require a retained screenshot for every UI story, at every `qa.level`. `tools/capture.sh` runs `xvfb-run … godot --rendering-driver opengl3 --write-movie …`, which exists only on Linux; all evidence so far came from the Linux container, while sprint 5 ran on a Windows machine and sprint 6's eight UI stories need eight or more retained frames. ADR-0010 Decision 3 already describes the Windows form ("the same `godot` line without `xvfb-run` and without `--rendering-driver opengl3` is the Forward+ capture used for playtest confirmation") but no script implements it, and Decision 5 calls the Windows capture rig an open point.

This story builds that rig and records which renderer produced every frame. Per DD-X32 (owner, 2026-11-05), Windows frames count as BLOCKING UI evidence and each records its renderer in a sidecar; a dated ADR-0010 erratum (2026-11-05) carries this.

Two facts found while verifying: `tools/capture.sh` already forwards arguments after `--` and takes `CAPTURE_LABEL` (boot-composition-root story 006), so MUI-004 AC-3's "extended to forward arguments" is a check, not an edit; and `.claude/docs/run-and-observe.md` documents a Windows Godot launch line that the script does not use.

**GDD**: no GDD (tooling). `design/gdd/match-ui.md` U11 (the screenshot contract) · `design/ux/hud.md` §12 (capture line) · `.claude/docs/run-and-observe.md` (Godot 4 capture) · `design/design-decisions.md` DD-X32
**Requirement**: `TR-game-concept-001` (headless test and screenshot evidence on Linux CI via Xvfb; Forward+ may need the Compatibility renderer for capture)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010: Renderer Choice vs Xvfb Screenshot Capture (Decision 2, 3, 5; Implementation Guidelines; Risks "Windows confirmation rows get skipped"; erratum 2026-11-05)
**ADR Decision Summary**: The shipped renderer stays Forward+. CI evidence is the Compatibility renderer on llvmpipe under Xvfb via `tools/capture.sh`, the last Movie Maker frame at the project viewport size. The Windows form is the same launch without `xvfb-run` and without `--rendering-driver`, giving the Forward+ look; each UI story records a Windows row confirming it. Erratum 2026-11-05 (DD-X32): a Windows frame with its renderer sidecar is BLOCKING UI evidence too.
**ADR Version**: 2026-11-03 (erratum 2026-11-05 is in the text read)

**Engine**: Godot 4.7.2 | **Risk**: HIGH (UI 4.5–4.7; the D3D12 default on Windows is sourced, a Windows capture has never been taken in this project: ADR-0010 Context)
**Engine Notes**: `--write-movie` crashes with `--headless` (exit 134): never add it. Frames are the project viewport size (1280x720), not `--resolution`. On Windows, Git Bash rewrites an argument that starts with `/` into a Windows path before a native exe sees it: use `MSYS_NO_PATHCONV=1` or `cygpath -m` for the paths passed to Godot (`run-and-observe.md`). Movie Maker names frames `f00000000.png` upward; the script already takes the last.

**Control Manifest Rules (Foundation layer, v2026-11-04)**:
- Required: "UI/Visual evidence on Linux is produced only by `tools/capture.sh`" (xvfb, `--rendering-driver opengl3` explicit, `--write-movie`, `--quit-after ≥ 60`, last frame kept at 1280x720). Every UI story records a Windows playtest row.
- Forbidden: `--headless` on a capture; relying on the silent Vulkan→GL fallback on Linux; changing `rendering/renderer/rendering_method`.
- Guardrail: evidence capture is offline tooling; a 60-frame full match scene expected in 5–30 s (ADR-0010).

---

## Acceptance Criteria

*From sprint 6 row 12, ADR-0010 Decision 3 and 5, DD-X32:*

- [x] GIVEN Git Bash on Windows with a desktop session and the story 010 wrapper first on `PATH`, WHEN `bash tools/capture.sh res://src/scenes/boot.tscn <out-dir> 60` (the script header's rig-check command) runs, THEN it does not call `xvfb-run` or add `--headless`, exits 0, and keeps a non-blank 1280x720 PNG named as on Linux; the blank check runs under whichever of `python3`, `python`, `py -3` starts first, and none starting is exit 2 with a message.
- [x] GIVEN the same run, THEN the default renderer on Windows is ADR-0010 Decision 3's Windows form (no `--rendering-driver`, the project's Forward+); `CAPTURE_RENDERER=opengl3` passes `--rendering-driver opengl3` without Xvfb (Compatibility on the real GPU); any other value is exit 2; and beside the kept PNG the script writes `<name>.renderer.txt` holding the OS, the exact Godot arguments and the engine's startup renderer line(s), so no frame is retained without its renderer, and a Windows frame with that sidecar is BLOCKING UI evidence (DD-X32).
- [ ] **NOT ASSESSED (2026-11-05: no Linux host here).** GIVEN a Linux host (cloud container or CI), WHEN the rig-check command and the 3- and 5-argument forms run, THEN output, exit codes (0, 2, 3, 4) and the kept file are as before plus the `.renderer.txt` sidecar, which reads `xvfb / opengl3 / llvmpipe`; where no Linux host is available this criterion reads NOT ASSESSED, and Windows evidence is never offered for it.

---

## Implementation Notes

*Derived from ADR-0010 Decision 2–4 and Implementation Guidelines:*

- Branch on `uname -s` (`MINGW*`/`MSYS*`/`CYGWIN*` = Windows), not on a path. Windows: `godot --path <repo> --windowed --resolution 1280x720 [--rendering-driver opengl3] --write-movie <tmp>/f.png --quit-after <frames> <scene> [-- user args]`; Linux: the existing `xvfb-run` line, unchanged. Keep the temp-dir cleanup trap and the `ls | sort | tail -n 1` last-frame pick.
- Run `godot` through the story 010 wrapper (so `user://` is per worktree); if no `godot` resolves, exit 2 with the wrapper's message.
- A Windows capture opens a window on the owner's or lane's desktop for the frame count; say so in the header comment. It needs a real desktop session, so a service or remote session with no display is exit 3 with the Godot error shown.
- The renderer line: capture Godot's stdout/stderr to a log under the temp dir and copy the first lines that name the rendering method or driver (the Vulkan/D3D12/OpenGL banner) into the sidecar. The exact banner text on D3D12 is not in the engine reference; the story's retained sidecar is the first observation of it. MUI-004 separately prints `RenderingServer.get_current_rendering_method()` from the game in debug builds; keep both.
- Update the header comment (usage, `CAPTURE_RENDERER`, exit codes) and `tests/README.md`'s capture paragraph. Do not touch the evidence stamping (`review-receipts.sh hash`): it stays the caller's step in `run-and-observe.md`.
- `tools/capture.sh` is edited in this story first, then in MUI-004 only if its own change needs it (the plan lists it as a W1 L1 shared file).

**Decided (DD-X32, owner, 2026-11-05):** a Windows frame is BLOCKING UI evidence, in either renderer (Forward+ by default, or `CAPTURE_RENDERER=opengl3`), and the Linux CI frame stays valid. Every retained Windows frame carries its sidecar and the reviewer says which renderer it is. A dated ADR-0010 erratum (2026-11-05) carries this; the control manifest gains the Windows form at the next `/create-control-manifest update`, a separate run. The per-UI-story Windows playtest row is unchanged. Plan row 12 fix (c) (Linux cloud lanes, or the owner retaining frames by hand) stays available as the fallback and is NOT ASSESSED for availability.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `godot` resolution and `user://` isolation (`production/epics/boot-composition-root/story-010-godot-wrapper-and-user-dir-isolation.md`).
- The first match-ui capture, `--fixture`, `CAPTURE_LABEL` use and `/perf-profile` (`production/epics/match-ui/story-004-match-view-skeleton-and-fixture-loader.md`).
- The Windows playtest rows and the owner's first-light folder (`production/epics/match-ui/story-012-first-playable-windows-match.md`).
- Control manifest edits (technical-director). The ADR-0010 erratum for DD-X32 is already written.

---

## Files

- `tools/capture.sh`
- `tests/README.md` (capture paragraph)
- `production/qa/evidence/story-011-windows-screenshot-capture/` (the two Windows frames, their sidecars, the README of commands and what was checked by eye)
- `tests/integration/boot/capture_script_test.gd` (added 2026-11-05, with its `.uid`: the lane brief asks for tests first)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above (QL-STORY-READY skipped — Lean mode).*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: documented verification record — the retained frames and sidecars above, with the exact command lines and exit codes, and the Linux re-run output or an explicit NOT ASSESSED. `bash -n tools/capture.sh` and the lint gates stay green.

**Status**: [x] Created; see Completion Notes

---

## Dependencies

- Depends on: `production/epics/boot-composition-root/story-010-godot-wrapper-and-user-dir-isolation.md` (the `godot` it launches); `production/epics/boot-composition-root/story-006-main-scene-composition-entry.md` (the rig-check scene and the `--` pass-through, done)
- Unlocks: `production/epics/match-ui/story-004-match-view-skeleton-and-fixture-loader.md` (AC-3 and its retained frame, if lanes run on Windows), and the retained screenshots of `story-005`, `006`, `007`, `008`, `009`, `011` and `025` in the same case
- **Sprint 6 placement**: before W1, behind story 010 in the same tools lane, merged before MUI-004 starts (MUI-004 W1 L1 takes the first frame). Fallback if it slips: lanes capture on a Linux host (plan row 12 fix (c)) or the owner retains frames by hand at 0.25 h more per UI story that the plan does not budget. Not a [S] or [C] story.

---

## Completion Notes
**Completed**: 2026-11-05
**Started / ended (UTC)**: 2026-11-05T17:34:46Z – 2026-11-05T18:03:30Z
**Criteria**: 2/3 passing. AC-3 is NOT ASSESSED: no Linux host here, as the AC allows, and no Windows evidence is offered for it.
**Real captures run**: 2, each opening a window for about 5 s, both exit 0 at the first attempt. Frames, sidecars, commands and the eye check are in `production/qa/evidence/story-011-windows-screenshot-capture/`.

**Deviations**:
- **`tests/integration/boot/capture_script_test.gd` is new and was not in the story's Files.** The lane brief asks for tests first.
- **The Windows branch calls `$repo_root/tools/bin/godot` by path, not `godot` on `PATH`.** That guarantees the wrapper, whatever else is on `PATH`; AC-1's GIVEN still holds.
- **Godot's output is now logged and repeated after it exits, on Linux too.** Same streams and same content, but nothing shows while it runs. Files, not `tee`: no race on the log, and no pipe that a stray child could hold open on a host this lane cannot test.
- **No renderer line in the log is exit 3 with no frame kept, on both branches.** AC-2's "no frame is retained without its renderer" wins over AC-3's "as before" for this one new path. On Windows it catches `GODOT_BIN` naming the GUI build. The Linux banner is the one retained in the story 006 evidence, so a Linux run should not reach it; that is unverified until a Linux run.
- **`CAPTURE_RENDERER` is checked on Linux too**: any value but `opengl3` is exit 2 there. It has no other effect on Linux.
- **The Python search is Windows only.** Linux stays on `python3`, so its exit codes do not move.
- **The second frame is `main.tscn`'s `data_error`, not the boot scene again**, so the same window also proves the arguments after `--` reach the scene on Windows, and a third run was not needed.
- **Finding: Forward+ ran on Vulkan 1.4.341, not D3D12.** `project.godot` sets no driver, and `docs/engine-reference/godot/` says D3D12 is the Windows default since 4.6. The frame stands, because the sidecar records what ran. Why they disagree is NOT ASSESSED; the reference is not edited here.
- `.claude/docs/run-and-observe.md` and the control manifest are unchanged: neither is in this story's Files.

**Test Evidence**: `tests/integration/boot/capture_script_test.gd`, 36 tests, no window: stubs stand for `uname`, `xvfb-run` and the engine, and the real wrapper and blank check run. 27 were seen failing against the unmodified script. The other 9 passed there, which for the Linux tests is the point: they pin "as before". Each of the 9 was then seen failing on a deliberate mutant, 8 mutants in all, restored after each run: `--headless` on the Windows line; the Godot exit check removed; a rendering driver always passed; the Linux line changed; user args dropped on Linux; Godot's stderr on stdout; the kept-path line broken; the Python search used on Linux.

**Gate** (2026-11-05, this tree): `--import` exit 0; `gates.sh`, `no_global_rng.sh`, `parse-check.sh` (52 checked, 0 failed), `ai_code_gates.sh` and `bash -n tools/capture.sh` pass; the suite ends `Overall Summary: 2441 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |`; `godot --headless --quit-after 5` exit 0 with no `SCRIPT ERROR`.

**The planner on a capture run (review DQ-2, `story-009:62`)**: `capture.sh` needs no planner change, so none was made. A shell cannot pass a `Callable`, but it does not have to:
- Arguments after `--` reach `OS.get_cmdline_user_args()` on both branches (`test_windows_user_args_...`, `test_linux_user_args_...`, and frame 02 on a real Windows run).
- `Boot.driver_factory()` reads those arguments by default, so `-- --fixture=<name> --ai-sync` selects `TimeSlicedPlannerTask` with no override.
- Observed in a scratch headless run, not committed and with no window: `--ai-sync` as a real process argument gave `TimeSlicedPlannerTask` on the real clock, three rounds, 149 events, 0 faults, and an event stream identical to `ImmediatePlannerTask`'s on the same fixture. With no flag it gave `WorkerPoolPlannerTask`, also identical. The scratch script exited 139 after printing, each time: TD-013, from its own unanchored inner class. It is not a repo command. The fixture is `MatchDriverFixture`, not a `match_view` run, because `match_view.tscn` does not exist yet.
- The other route in the review, a launcher scene under `tests/`, also passes `capture.sh`'s `res://*.tscn` check, so it needs no change here either.

**Open, for the owner, blocks MUI-004's readiness**: does the `match_view.tscn` capture get its planner from `-- --ai-sync`, with the loader passing no override, or from a launcher scene under `tests/` that passes `ImmediatePlannerTask`? Not decided here: DD-X33 names tests and the sim harness and is silent on a capture run, and ADR-0008 D11 and the manifest (lines 212, 331) still say `ImmediatePlannerTask`. `--ai-sync` is the smaller change; it means rewording MUI-004 AC-2 and adding the flag to AC-3's command. `story-009:62` stays wrong until then and is not edited here.
