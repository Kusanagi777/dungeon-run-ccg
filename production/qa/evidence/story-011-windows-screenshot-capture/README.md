# Evidence: boot-composition-root story 011 (a Windows screenshot path)

**Date**: 2026-11-05 · **Story**: `production/epics/boot-composition-root/story-011-windows-screenshot-capture.md` (Integration)
**Captured by**: sprint 6 pre-wave lane `s6/boot-011`, on the owner's Windows 11 desktop. These are the first Windows captures this project has taken.

Two real captures ran, each opening a window for about 5 seconds. Both exited 0 at the first attempt. The first ran from the worktree root, the second from `production/` inside it.

Both runs, from Git Bash:

```bash
export PATH="$PWD/tools/bin:$PATH"
export GODOT_BIN=<engine folder>/Godot_v4.7.2-stable_win64_console.exe
```

## Frames

| Frame | Sidecar `renderer:` line | Command | Exit | Blank check | UTC |
|---|---|---|---|---|---|
| `01-boot.png` | `windows / default (Forward+) / NVIDIA - NVIDIA GeForce RTX 4080 Laptop GPU` | `bash tools/capture.sh res://src/scenes/boot.tscn production/qa/evidence/story-011-windows-screenshot-capture 60` | 0 | 1280x720, 475 distinct colours | 17:45:39 to 17:45:44 |
| `02-data_error-opengl3.png` | `windows / opengl3 (Compatibility) / NVIDIA - NVIDIA GeForce RTX 4080 Laptop GPU` | `CAPTURE_RENDERER=opengl3 CAPTURE_LABEL=02-data_error-opengl3 bash ../tools/capture.sh res://src/scenes/main.tscn qa/evidence/story-011-windows-screenshot-capture 60 -- --boot-fail-fixture=boot_data_error` | 0 | 1280x720, 463 distinct colours | 17:45:53 to 17:45:58 |

Each frame's `.renderer.txt` holds the OS, the exact Godot arguments and the engine's lines. On 2026-11-05 the independent review's D-011-2 had their machine paths replaced by hand with `<repo>` and `<tmp>`, the form `capture.sh` now writes; the frames were not re-captured, and they came from `dcc0f53`'s script. The blank check ran under `python3`, the first that started.

## Checked by eye

- `01-boot.png`: the dark boot screen, "Deckdelve — boot" centred, and "Dungeon Run CCG — Godot 4.7.2-stable (official)" at bottom left. No clipping.
- `02-data_error-opengl3.png`: "The game data failed to load", "8 problems — fix the data files and restart", then the `E_UNKNOWN_REF` row for `hero_war.starter_deck[14]` and seven warning rows. This screen appears only if `--boot-fail-fixture=boot_data_error` reached `OS.get_cmdline_user_args()`, so it also proves the arguments after `--` arrive on Windows.

## What the engine printed

- Forward+: `Vulkan 1.4.341 - Forward+ - Using Device #0: NVIDIA - NVIDIA GeForce RTX 4080 Laptop GPU`
- Compatibility: `OpenGL API 3.3.0 NVIDIA 610.47 - Compatibility - Using Device: NVIDIA - NVIDIA GeForce RTX 4080 Laptop GPU`
- Both: `recording movie in 1280×720 @ 60 FPS`.

**This run used Vulkan, not D3D12.** `project.godot` sets no `rendering_device/driver`, and `docs/engine-reference/godot/` says D3D12 is the Windows default since 4.6. The sidecar records what ran, so the frame stands, but the reference and this observation disagree. Why is NOT ASSESSED.

## Linux

**NOT ASSESSED.** No Linux host here, so AC-3 has no run. `tests/integration/boot/capture_script_test.gd` pins the Linux line and exit codes with stubs on this machine; that is a guard on the script, not evidence for AC-3.
