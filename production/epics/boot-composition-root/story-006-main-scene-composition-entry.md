# Story 006: main.tscn composition entry and the RunShell stub

> **Epic**: Boot & Composition Root
> **Status**: Ready
> **Layer**: Presentation (scene root of the Foundation epic — the one composition entry)
> **Type**: UI
> **Estimate**: S
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: — (no system GDD; `docs/architecture/architecture.md` §Data Flow 5 Initialisation order steps 1 and 5; §Dependency injection "`main.tscn` as the only root" rationale; `design/gdd/run-ui.md` U1 `RunShell` root and S1/S2 `main_menu` / `data_error` — the stub stands in until the Run UI epic)
**Requirement**: `TR-design-decisions-001` (also `TR-tech-debt-001` — TD-006: UI never mutates state)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Rules / Presentation Split (Decision 3 — presentation tier; Decision 4 — `main.tscn` calls `Boot.boot()`; Implementation Guidelines — scene roots pass services down by argument); ADR-0011: Run UI Shell Pattern and the Meta Stub Injection Seam (Decision 1 — `RunShell._ready()` calls `Boot.services()` once, opens `main_menu` or `data_error` on a `Failed` load); ADR-0010 (evidence capture via `tools/capture.sh`)
**ADR Decision Summary**: `src/scenes/main.tscn` is the one composition path: it calls `Boot.boot()` and hands the `Services` bag to the `RunShell` root by argument; `RunShell` is the root of everything outside a match and opens `main_menu`, or `data_error` when the data load `Failed`; no debug loader re-implements composition.
**ADR Version**: 2026-11-03 (ADR-0001, ADR-0011, ADR-0010 — all `Last Verified` 2026-11-03)

**Engine**: Godot 4.7.2 | **Risk**: HIGH (ADR-0011's rating — UI carries 4.5–4.7 changes; this stub uses only `Control`, `Label`, `ColorRect`, `tr()` and `%UniqueName`, the same set `boot_screen.gd` already uses)
**Engine Notes**: `display/window/stretch/mode = canvas_items` is the 4.7 default for new projects (ADR-0011, sourced; DD-T05 requires it) — check `project.godot` rather than assume. `tr()` with no catalogue returns the key (4.0 behaviour; ADR-0011 verification 4). Capture only through `tools/capture.sh` (xvfb, `--rendering-driver opengl3` explicit, never `--headless` with `--write-movie` — exit 134); CI frames are Compatibility/llvmpipe output, so the UI story records a Windows playtest row confirming the Forward+ look (ADR-0010, manifest).

**Control Manifest Rules (this layer)**:
- Required: Scene roots (`MatchView`, `RunShell`, `main.tscn`) and `*_debug_loader.gd` are the only non-test callers of `Boot.services()`; they pass services down by argument, never re-fetch deeper in the tree — ADR-0001
- Required: UI/Visual evidence on Linux is produced only by `tools/capture.sh <scene> <out-dir> [frames] [-- <args>]`; every captured state is reached through a fixture and the real engine / `MetaStub`; stamp with `review-receipts.sh hash` and retain under `production/qa/evidence/<story-slug>/`; every UI story records a Windows playtest row — ADR-0010
- Forbidden: Never a second composition path (`main.tscn` only; debug loaders re-implementing composition) — TD-006 — ADR-0001 (Alt 1); never build a view-state by hand for a screenshot — ADR-0010
- Forbidden: `queue_free` appears only under `src/ui/` — ADR-0001
- Guardrail: Data load inside `Boot.boot()` ≤ `data_load_budget_ms` 200, synchronous at boot (the stub shows nothing until it returns) — ADR-0002, ADR-0001

---

## Acceptance Criteria

*From `docs/architecture/architecture.md` §Data Flow 5 and ADR-0001 Decision 4 / ADR-0011 Decision 1, scoped to this story:*

- [ ] `src/scenes/main.tscn` is `application/run/main_scene`; its root script calls `Boot.boot()` exactly once in `_ready()`, then instantiates the `RunShell` stub (`src/ui/run/run_shell.tscn`, `class_name RunShell extends Control`) and hands it the `Services` bag by argument before adding it to the tree; `main.tscn`'s root and `run_shell.gd` are the only `Boot` references under `src/scenes/` and `src/ui/` (gate G3 scope note in ADR-0001 Decision 4); `src/scenes/boot.tscn` stays as the capture-rig scene and is no longer the main scene.
- [ ] With `BootResult.ok == true` the stub shows a placeholder `main_menu` state (title and a "Run UI pending" line, every string a `tr()` key, art-bible §4 tokens as theme overrides in the `.tscn` as `boot.tscn` does); with `ok == false` it shows a `data_error` state listing the `ValidationReport` rows (CR-8 shape; ADR-0011 Decision 1 S1/S2). Both states are captured with `tools/capture.sh` to `production/qa/evidence/story-006-main-scene-composition-entry/` — the `Failed` state reached through a `Boot` override selected by a debug command-line arg (`OS.get_cmdline_user_args()`, the seam `RunDebugLoader` will reuse), never a hand-built view-state — and the frames are stamped with `review-receipts.sh hash`.
- [ ] `tests/integration/boot/boot_scene_test.gd` `test_project_main_scene_is_boot_scene` is updated to assert the new main scene (and renamed to say so); `timeout 30 godot --headless --quit-after 5` (`commands.smoke`) exits 0 with no `SCRIPT ERROR`; the stub holds no game state, stores the `Services` reference only on the shell root, and calls no `Boot.services()` deeper in the tree.
- [ ] A Windows playtest row is recorded in the evidence folder's `README.md` ("matches CI evidence / differs" against the Forward+ build, ADR-0010) — advisory until the Windows export job exists (gate condition 8), but the row must be present and honest (`not yet run` is an acceptable value).

---

## Implementation Notes

*Derived from ADR-0001 Decision 3/4 and Implementation Guidelines, ADR-0011 Decision 1, ADR-0010:*

- Files: `src/scenes/main.tscn` + `src/scenes/main.gd` (root script; `class_name Main extends Control` or `Node` — a thin root whose only job is step 1 of Data Flow 5), `src/ui/run/run_shell.tscn` + `src/ui/run/run_shell.gd` (stub: `class_name RunShell extends Control`, a `set_services(services: Services)` or constructor-style `bind` called before `add_child`, two placeholder states).
- ADR-0011 Decision 1 says `RunShell._ready()` calls `Boot.services()` once; ADR-0001 says `main.tscn` calls `Boot.boot()`. Both hold: `main.gd` boots, `RunShell` receives the bag by argument (preferred — it keeps the shell testable with a `MetaStub` and no autoload) and may fall back to `Boot.services()` only when launched directly as a scene (the `--run-ui-screen` path, Run UI epic). Do not implement `ScreenStack`, `ToastLayer`, `TransitionLayer`, `RunController` or `Screen` here — the Run UI epic replaces the stub's body and keeps its file names.
- `data_error` read model is the `ValidationReport` rows (CR-8); render them as a plain `Label` list (`ItemList`/`RichTextLabel` are Run UI's call). `Failed` has no main menu (TD-008 rule).
- Debug arg for the failed-state capture: `--boot-fail-fixture` (or similar) read with `OS.get_cmdline_user_args()` in `main.gd`, debug builds only (`OS.is_debug_build()`), mapping to `Boot.boot({card_database: <db loaded from a broken fixture>})`. It is the same override seam story 004 provides and `RunDebugLoader` will use — one composition path.
- Capture: `bash tools/capture.sh res://src/scenes/main.tscn production/qa/evidence/story-006-main-scene-composition-entry` for the happy path and `… -- --boot-fail-fixture=<name>` for `data_error`; the kept frame is `01-main.png` — rename or sub-folder per state (`main-menu/`, `data-error/`) so both are retained. `Read` the PNGs and compare to the AC before closing (run-and-observe step 4).
- `tests/README.md` "Smoke" paragraph and the `boot_scene_test.gd` header comment name `boot.tscn` as the main scene; update both lines (docs change inside the story's scope).
- UI rules (`.claude/rules/ui-code.md`): display only; `tr()` on every string; the stub has no interactive element yet, so focus/gamepad rules are deferred to the Run UI epic.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 004: `Boot.boot()` itself and the `{card_database: …}` override.
- Run UI epic: the real `RunShell` (`ScreenStack`, `ToastLayer`, `TransitionLayer`, `CanvasModulate`, `RunController`, `Screen`, `RunDebugLoader`, `main_menu` and `data_error` screens as `src/ui/run/screens/<id>.tscn`).
- Match UI epic: `MatchView`, `--fixture`.
- Gate condition 8 (Windows export in CI) — the Windows row stays advisory until then.

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/scenes/main.tscn`
- `src/scenes/main.gd`
- `src/ui/run/run_shell.tscn`
- `src/ui/run/run_shell.gd`
- `project.godot` (`application/run/main_scene`)
- `tests/integration/boot/boot_scene_test.gd` (main-scene assertion updated)
- `tests/README.md` (smoke paragraph: main scene name)
- `production/qa/evidence/story-006-main-scene-composition-entry/` (frames + `README.md` with the Windows row)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level` (`standard`): the retained screenshot is required at every `qa.level`.*

**Story Type**: UI
**Required evidence**:
- UI: a retained screenshot of each screen touched (`main_menu` placeholder and `data_error` placeholder), in `production/qa/evidence/story-006-main-scene-composition-entry/`, produced by `tools/capture.sh`, stamped with `review-receipts.sh hash`; plus the Windows playtest row

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/boot-composition-root/story-004-boot-composition-root.md`
- Unlocks: `production/epics/boot-composition-root/story-007-boot-responsibilities-manifest.md`; the Run UI epic's `RunShell` stories (they replace the stub body)
