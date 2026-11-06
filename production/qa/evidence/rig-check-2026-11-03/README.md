# Rig check — 2026-11-03

**This is the test-rig proof, not story evidence.** It proves that the
run-and-observe capture path (`tools/capture.sh`) produces a real, non-blank
frame of a launched scene on this Linux container. No story is closed by it.

## Command

```
bash tools/capture.sh res://src/scenes/boot.tscn production/qa/evidence/rig-check-2026-11-03
```

Run from the repository root with `~/.local/bin` on `PATH` (Godot 4.7.2
`4.7.2.stable.official.ed1daf0bf`, `xvfb-run` from xvfb 21.1.12). The script
ran exactly:

```
xvfb-run -a -s "-screen 0 1280x720x24" godot --path /home/user/dungeon-run-ccg --windowed --resolution 1280x720 --rendering-driver opengl3 --write-movie <out-dir>/.capture-XXXXXX/f.png --quit-after 60 res://src/scenes/boot.tscn
```

## Result

| Item | Value |
|---|---|
| Exit code | `0` |
| Kept frame | `01-boot.png` (the last of 60 frames; the other 59 and `f.wav` were deleted by the script) |
| Image | 1280x720, 8-bit RGB PNG, 18,844 bytes |
| Non-blank check | `capture.sh: … 01-boot.png 1280x720, 473 distinct colours` (the check exits 4 on a one-colour frame; verified against a synthetic solid PNG, which it rejected) |
| Renderer actually used | `OpenGL API 4.5 (Core Profile) Mesa 25.2.8 … Compatibility … llvmpipe` — the Compatibility renderer under software GL, not the project's Forward+ |
| Log noise | one `WARNING: Could not set V-Sync mode` line (expected under Xvfb; Probe C saw the same) |

What is in the frame, checked by eye (the agent read the PNG): `bg_edge`
`#141820` background filling the viewport, the title `Deckdelve — boot` centred
in `text_light`, and the build stamp `Dungeon Run CCG — Godot 4.7.2-stable
(official)` bottom-left in `text_muted`. Nothing clipped.

## Same-day context

- Smoke: `timeout 30 godot --headless --quit-after 5` exits `0` with no
  `SCRIPT ERROR` now that `run/main_scene` is `res://src/scenes/boot.tscn`.
- Tests: `commands.test` → `66 test cases | 0 errors | 0 failures | 0 orphans`,
  `Exit code: 0` (4 suites, including `tests/integration/boot/boot_scene_test.gd`).
- Capture command provenance: `docs/architecture/spikes/2026-11-03-engine-probes.md`
  Probe C; procedure: `.claude/docs/run-and-observe.md`.
