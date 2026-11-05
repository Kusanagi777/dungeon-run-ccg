# Story 012: First playable — one War match vs The Torchbearer, mouse-played, on the Windows export

> **Epic**: Match UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

This story closes the first-playable slice (Stories 001–011). Gate `production/gate-checks/gate-pre-production-2026-11-03.md` entry condition 5 asks for a Windows export of one War match vs one band-1 boss, mouse-played, within sprints 1–2, which the owner plays as playtest #1 — launched through a `--fixture` until Run UI lands. Content story 001 names The Torchbearer as the batch-0 boss (the owner may swap Rat King there).

**GDD**: `design/gdd/match-ui.md` U11 (fixtures run the real engine; loader absent from release), U9 (hand-off) · `design/gdd/game-concept.md` Technical Considerations
**Requirement**: `TR-match-ui-004`, `TR-match-ui-006`, `TR-game-concept-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010: Renderer Choice vs Xvfb Screenshot Capture (shipped Forward+; per-UI-story Windows confirmation row advisory); ADR-0009 (Decision §4 — loader absent from release exports, CI greps the `.pck`); ADR-0008 (driver built through the same `driver_factory`)
**ADR Decision Summary**: The shipped build renders Forward+ (D3D12 default on Windows in 4.6+); CI evidence is Compatibility/llvmpipe, so the Windows run is the only Forward+ observation. `MatchDebugLoader` exists only in debug builds; the release `.pck` must not list it (export-filter syntax NOT SOURCEABLE — the grep is the test).
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Windows facts are unverified (gate Accepted Risks): Forward+/D3D12 parity, `WorkerThreadPool` (boss planner — boss-ai story 018). The playtest build must be a **debug** export (the `--fixture` path needs the loader and `tests/fixtures/match_ui/`), while the release preset must exclude both — two presets.

**Control Manifest Rules (this layer)**:
- Required: `MatchDebugLoader` (debug builds only) builds a real `MatchDriver` through `driver_factory`. Renderer-neutral 2D UI.
- Forbidden: `MatchDebugLoader` / `RunDebugLoader` never in release exports (CI greps the exported `.pck`).
- Guardrail: performance budgets per `project.yaml` (60 fps, 500 draw calls, 1024 MB).

---

## Acceptance Criteria

*From gate entry condition 5, match-ui U11 and ADR-0009 / ADR-0010 Validation:*

- [ ] GIVEN fixture `first_playable` (`hero_war` vs `boss_torchbearer`, fixed seed, empty command list), WHEN `tests/integration/match_ui/first_playable_match_test.gd` drives a full match through `InputRouter` mouse intents only (mulligan, plays, attacks, hero power, End Turn) at `anim_speed = instant`, THEN the match reaches `match_ended` and `match_view_finished(result)` with zero `_assert_in_sync` failures and zero commands built against a stale display.
- [ ] GIVEN the Windows **debug** export launched with `-- --fixture=first_playable`, WHEN the owner plays one match to the end banner with the mouse, THEN a playtest report exists (`/playtest-report` → `production/qa/playtests/playtest-001-first-playable.md`) and an owner-retained screenshot of the Windows run sits in `production/qa/evidence/windows-first-light-<date>/` with the renderer line from the log (ADR-0010 Windows confirmation — the one Forward+ observation).
- [ ] GIVEN the Windows **release** export preset, WHEN CI lists the exported `.pck`, THEN neither `match_debug_loader` nor `tests/fixtures/` appears, and the release build boots to its main scene without error.

---

## Implementation Notes

- `tests/fixtures/match_ui/first_playable.json` — a live start (rests at `mulligan_offered`); the scripted player in the integration test picks the first legal command each step (deterministic per seed, no randomness).
- Export presets: `export_presets.cfg` gains a debug Windows preset including `tests/fixtures/match_ui/*.json` and a release preset excluding `src/ui/match/match_debug_loader.gd` and `tests/**`. The CI build/publish of the Windows export is gate entry condition 8 (devops) — not an epic story; this story depends on it existing or adds the `.pck` grep step to the CI workflow itself.
- `match_view.tscn` must be launchable as the scene argument; the release build keeps `res://src/scenes/boot.tscn` as `run/main_scene`.
- Re-run `/perf-profile` on the Windows run if the owner is willing (advisory; Story 004 carries the gate).

---

## Out of Scope

- `run-ui` epic: launching a match from a real run. Story 024: measured latency table and Feel ACs.

---

## Files

- `tests/fixtures/match_ui/first_playable.json`
- `tests/integration/match_ui/first_playable_match_test.gd`
- `export_presets.cfg`
- `.github/workflows/` (the `.pck` grep step, if condition 8's workflow exists)
- `production/qa/playtests/playtest-001-first-playable.md`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/match_ui/first_playable_match_test.gd` passes, AND playtest doc `production/qa/playtests/playtest-001-first-playable.md`
- Owner evidence: `production/qa/evidence/windows-first-light-<date>/` (gate condition 8)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/match-ui/story-008-drag-to-play-attack-and-targeting-arrow.md`, `production/epics/match-ui/story-025-hero-power-drag-to-cast-zone.md` (added 2026-11-05: AC-1's hero power has no mouse path without it, DD-X34), `production/epics/match-ui/story-009-mulligan-screen.md`, `production/epics/match-ui/story-010-boss-turn-pacing.md`, `production/epics/match-ui/story-011-match-end-banner-and-handoff.md`; `production/epics/content/story-001-batch-0-first-playable-data-set.md`; `production/epics/boss-ai-match-driver/story-018-windows-planner-a30-and-determinism.md`; gate entry condition 8 (CI Windows export — sprint task, no story)
- Unlocks: `production/epics/match-ui/story-024-input-latency-and-feel-validation.md`; playtest #1
