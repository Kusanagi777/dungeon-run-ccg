# Story 004: MatchView skeleton, Presenter base, the --fixture loader, first capture and /perf-profile

> **Epic**: Match UI
> **Status**: In Review
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: L
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/match-ui.md` U1, U11 (`--fixture`, the screenshot contract), States (`Loading`), F6 (1280x720 grid) · UX: `design/ux/hud.md` §3 Layout Zones, §5 `Loading` row, §12 (capture line)
**Requirement**: `TR-match-ui-001`, `TR-match-ui-004`, `TR-design-decisions-003`, `TR-game-concept-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009 (Decision §3 scene partition, §4 debug loader seam); ADR-0010: Renderer Choice vs Xvfb Screenshot Capture; ADR-0008 (`MatchView` lifecycle, `ImmediatePlannerTask` through the same `driver_factory`)
**ADR Decision Summary**: `match_view.tscn` (root `MatchView extends Control`) plus one scene per presenter and a shared `card_frame.tscn`; `@abstract Presenter` declares `bind`, `owns`, `on_step_started`, `apply_final`, `sync_report`. `MatchDebugLoader` (debug builds only) reads `--fixture`, calls `Boot.boot()`, builds a real driver with `ImmediatePlannerTask`, runs the scripted commands, then `MatchView` projects `events_since(0)` at `instant`. Shipped renderer Forward+; CI evidence is Compatibility/llvmpipe under xvfb via `tools/capture.sh`.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: `@abstract` (4.5, sourced) for `Presenter`; every override returns explicitly (4.7 typed-return rule). `OS.get_cmdline_user_args()` / `OS.is_debug_build()` are 4.x training-data APIs (LOW). `--headless --write-movie` crashes (exit 134) — never add `--headless` to captures (ADR-0010, `tools/capture.sh`). Movie Maker frames are the project viewport size. Print `RenderingServer.get_current_rendering_method()` / driver / adapter once in debug builds.

**Control Manifest Rules (this layer)**:
- Required: Scene partition is one scene per presenter plus shared `src/ui/common/card_frame.tscn`. `MatchView`: `set_controller`; `_process` → `controller.tick()` + `queue.advance(delta)`; projects `events_since(0)` then subscribes; `_exit_tree` → `controller.shutdown()`. `_assert_in_sync()` after every drain in debug builds. Every value from `config("match_ui")`, read once in `_ready`.
- Forbidden: Never a single monolithic `match_view.tscn`. Fixtures never contain hand-built view-states. Never a Forward+-only project setting, glow, HDR or post-processing.
- Guardrail: 11 scenes preloaded by `match_view.tscn`; performance budgets per `project.yaml` `performance.*` (`draw_call_limit` 500, `memory_ceiling_mb` 1024, 60 fps / 16.6 ms).

---

## Acceptance Criteria

*From match-ui U1/U11, ADR-0009 Migration Plan step 2, gate `gate-pre-production-2026-11-03.md` entry condition 10:*

- [ ] GIVEN `res://src/ui/match/match_view.tscn`, WHEN it is instanced with a `MatchController`, THEN it holds the ADR-0009 partition (`hand_fan`, `board_row` ×2, `hero_panel` ×2, `targeting_arrow`, `choice_overlay`, `event_feed`, `banner`, `mulligan_screen`, `pause_menu` — stubs extending `Presenter` where later stories fill them), owns one `MatchViewState`, one `AnimationQueue` and one `InputRouter`, projects `events_since(0)` before calling `subscribe`, drives `controller.tick()` and `queue.advance(delta)` from `_process`, calls `controller.shutdown()` in `_exit_tree`, and in a debug build calls `_assert_in_sync()` after every `drained` (an integration test with `scene_runner()` asserts all of this).
- [ ] GIVEN `-- --fixture=turn1_player`, WHEN `match_view.tscn` launches in a debug build, THEN `MatchDebugLoader` loads `tests/fixtures/match_ui/turn1_player.json` (a `MatchConfig` for `hero_war` vs `boss_torchbearer` + a scripted command list), builds the driver through the same `driver_factory` with `ImmediatePlannerTask`, runs every command with zero rejections, and the view reaches `Idle` at `anim_speed = instant` with an empty queue.
- [ ] GIVEN `tools/capture.sh` extended to forward arguments after a literal `--` to Godot (and to name the kept frame from an optional label), WHEN `bash tools/capture.sh res://src/ui/match/match_view.tscn production/qa/evidence/story-004-match-view-skeleton-and-fixture-loader 60 -- --fixture=turn1_player --anim-speed=instant` runs under xvfb, THEN exit code is 0 and a non-blank 1280x720 PNG is retained in that folder, with a `README.md` recording the command, the renderer line the log printed, and the frame contents checked by eye; the existing 2- and 3-argument forms behave exactly as before (rig-check command re-run).
- [ ] GIVEN the `turn1_player` fixture running windowed for ≥ 10 s, WHEN `/perf-profile` measures it, THEN draw calls ≤ 500 (`performance.draw_call_limit`) and process memory ≤ 1024 MB (`performance.memory_ceiling_mb`) at 60 fps target, the report is retained under `production/qa/evidence/story-004-match-view-skeleton-and-fixture-loader/perf-profile.md`, and `docs/architecture/architecture.md` §Performance budgets replaces its provisional values with the measured ones (gate entry condition 10 — performance-analyst).

---

## Implementation Notes

*Derived from ADR-0009 §3–4 and ADR-0010 Implementation Guidelines:*

- `src/ui/match/presenter.gd` — `@abstract class_name Presenter extends Control` exactly as ADR-0009 Key Interfaces. Stub presenters return `true`/`[]` explicitly until their story fills them.
- `src/ui/match/match_debug_loader.gd` — `from_args`, `load_fixture`; `apply_pose` stays empty (poses arrive with the stories that need them, Story 022 completes them). Attach only when `OS.is_debug_build()`.
- Fixture JSON format (shared with `tests/integration/match_ui/`): `{"config": {hero, boss, seed, floor, band, treasures: []}, "profile": {settings…}, "commands": [...]}`. Document it in `tests/fixtures/match_ui/README.md`.
- `capture.sh` change is backward compatible: `$4 == "--"` → remaining args after the scene. The kept frame name defaults to `01-<scene>.png`; add an optional `CAPTURE_LABEL` env var (`<nn>-<what>`) so later stories can retain several frames from `match_view.tscn` in one folder. Keep the blank-frame check.
- Project setting: 1280x720 logical, `canvas_items` stretch, `keep` aspect (DD-T05) — verify, do not change, if already set by the Boot epic.
- `/perf-profile` reads `project.yaml` `performance.*`; note in the report that the CI capture path is Compatibility/llvmpipe and that the Forward+ / Windows numbers come from Story 012's run (ADR-0010 advisory row).

---

## Out of Scope

- Stories 005–009, 011: filling each presenter.
- Story 012: release-export exclusion of the loader (`.pck` grep) and the Windows run.
- Story 022: `--pose`, `--pause-at`, `--ai-debug` and the full fixture sweep.

---

## Files

- `src/ui/match/match_view.tscn`, `src/ui/match/match_view.gd`
- `src/ui/match/presenter.gd`, `src/ui/match/input_router.gd` (skeleton)
- `src/ui/match/hand_fan.tscn`, `board_row.tscn`, `hero_panel.tscn`, `targeting_arrow.tscn`, `choice_overlay.tscn`, `event_feed.tscn`, `banner.tscn`, `mulligan_screen.tscn`, `pause_menu.tscn` (stubs)
- `src/ui/common/card_frame.tscn` (stub)
- `src/ui/match/match_debug_loader.gd`
- `tests/fixtures/match_ui/turn1_player.json`, `tests/fixtures/match_ui/README.md`
- `tools/capture.sh`
- `tests/integration/match_ui/match_view_lifecycle_test.gd`
- `docs/architecture/architecture.md` (§Performance budgets values only)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- UI: retained screenshot `production/qa/evidence/story-004-match-view-skeleton-and-fixture-loader/01-turn1_player.png` (via `tools/capture.sh`), its `README.md`, and `perf-profile.md` in the same folder
- Also: `tests/integration/match_ui/match_view_lifecycle_test.gd` passes
- Windows confirmation row: advisory (ADR-0010)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/match-ui/story-002-animation-queue-core.md`, `production/epics/match-ui/story-003-match-controller-and-match-query.md`; `production/epics/boot-composition-root/story-004-boot-composition-root.md`; `production/epics/content/story-001-batch-0-first-playable-data-set.md` (`match_ui.json`, `hero_war`, `boss_torchbearer`); `production/epics/boss-ai-match-driver/story-015-match-driver-tick-replay-and-shutdown.md`
- Unlocks: `production/epics/match-ui/story-005-hero-panels-mana-and-end-turn.md`, `production/epics/match-ui/story-006-hand-fan-and-hover-preview.md`, `production/epics/match-ui/story-007-board-rows-and-tokens.md`, `production/epics/match-ui/story-009-mulligan-screen.md`, `production/epics/match-ui/story-022-debug-loader-poses-and-fixture-sweep.md`
