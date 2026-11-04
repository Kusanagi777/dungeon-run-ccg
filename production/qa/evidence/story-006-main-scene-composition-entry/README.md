# Evidence — boot-composition-root story 006 (main.tscn composition entry, RunShell stub)

**Date**: 2026-11-04 · **Story**: `production/epics/boot-composition-root/story-006-main-scene-composition-entry.md` (UI)
**Captured by**: sprint-3 lane `lane/s3-content-001-007` (developer capture). **Owner review of the frames**: pending (UI, lean).

Both states are reached through the real composition: `main.tscn`'s root calls
`Boot.boot()` once and hands `Boot.services()` to the `RunShell` stub. No
view-state is built by hand.

## Frames

| Frame | State | Command (repo root, `~/.local/bin` on `PATH`) | Capture line |
|---|---|---|---|
| `01-main_menu.png` | `main_menu` — `Boot.boot()` over the shipped `assets/data/` (content story 001), `ok == true` in this debug run (pending validators are `W_VALIDATOR_PENDING` warnings) | `CAPTURE_LABEL=01-main_menu bash tools/capture.sh res://src/scenes/main.tscn production/qa/evidence/story-006-main-scene-composition-entry` | exit 0 · 1280x720, 413 distinct colours |
| `02-data_error.png` | `data_error` — `Boot.boot({card_database: <unloaded db over tests/fixtures/data/boot_data_error/>})` via the debug argument; Boot loads it with its own validator map | `CAPTURE_LABEL=02-data_error bash tools/capture.sh res://src/scenes/main.tscn production/qa/evidence/story-006-main-scene-composition-entry 60 -- --boot-fail-fixture=boot_data_error` | exit 0 · 1280x720, 474 distinct colours |

`boot_data_error/` is a copy of the batch-0 data set with one fault
(`hero_war.starter_deck[14]` = `neutral_ghost`), so the report has exactly one
error plus the debug-build warnings.

Renderer line both runs printed: `OpenGL API 4.5 (Core Profile) Mesa
25.2.8-0ubuntu0.24.04.4 - Compatibility - Using Device: Mesa - llvmpipe (LLVM
20.1.2, 256 bits)` — Compatibility/llvmpipe under Xvfb, not the project's
Forward+ (ADR-0010). No `SCRIPT ERROR` in either log.

## Checked by eye (the agent read both PNGs)

- `01-main_menu.png`: `bg_edge` `#141820` fills the viewport; "Deckdelve" centred
  at 48 px in `text_light`; "Run UI pending" under it at 20 px in `text_muted`.
  Nothing else on screen, nothing clipped. Matches AC-2's `main_menu` placeholder.
- `02-data_error.png`: same background; heading "The game data failed to load"
  (32 px, `text_light`); "12 problems — fix the data files and restart" (16 px,
  `text_muted`); then one row per `ValidationReport.to_text()` line in the CR-8
  shape `[severity] CODE file#record.field — message`: the `[error]
  E_UNKNOWN_REF heroes.json#hero_war.starter_deck — starter_deck[14]: no CardDef
  "neutral_ghost" …` row first, then the 11 warnings (`W_BAND_HEALTH`, the
  `W_VALIDATOR_PENDING` rows, `W_POOL_SIZE`). The one long row wraps; nothing is
  cut off. No main menu is shown (`Failed` has no main menu).

## Content stamps

```
Reviewed-Content-Hash: production/qa/evidence/story-006-main-scene-composition-entry/01-main_menu.png f60fb15214d69e0332114c78a7a40d8a7d47f909
Reviewed-Content-Hash: production/qa/evidence/story-006-main-scene-composition-entry/02-data_error.png cff94cb2a300033a052668d88d9d6f76cb91f887
```

## `capture.sh` rig-check re-run (2- and 3-argument forms unchanged)

Re-run on 2026-11-04 after adding the `--` pass-through and `CAPTURE_LABEL`, into a
scratch folder (the 2026-11-03 rig-check evidence is left as it was):

| Form | Exit | Result |
|---|---|---|
| `bash tools/capture.sh res://src/scenes/boot.tscn <dir>` | 0 | `01-boot.png`, 1280x720, 473 distinct colours — the same count the 2026-11-03 rig check recorded |
| `bash tools/capture.sh res://src/scenes/boot.tscn <dir> 30` | 0 | `01-boot.png` kept |
| `… <dir> 30 extra` (4th argument not `--`) | 2 | usage |
| `… <dir> 30 -- a b c d` | 0 | arguments forwarded; `boot.tscn` ignores them |
| `CAPTURE_LABEL=bad …` / `CAPTURE_LABEL=05-x/y …` | 2 | label refused |
| one argument | 2 | usage |

The blank-frame check is unchanged.

## Windows playtest row (ADR-0010)

| Build | Date | Result |
|---|---|---|
| Windows Forward+ build | — | **not yet run** — advisory until the Windows export job exists (gate condition 8). Note for whoever runs it: `windows-export.yml` builds `--export-release`, and a release build turns every pending validator (`PENDING_CONFIG_OWNERS`, `PENDING_RECORD_OWNERS`) into an error, so a release export opens on `data_error` **by design** until those lists are empty; a **debug** export shows `main_menu`. Record which build was launched. |
