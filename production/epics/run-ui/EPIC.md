# Epic: Run UI

> **Layer**: Presentation
> **GDD**: design/gdd/run-ui.md (Overview, Detailed Rules U1–U10, Formulas F1–F4, Acceptance Criteria) · design/ux/hero-select.md, design/ux/run-summary.md, design/ux/draft-picker.md, design/ux/interaction-patterns.md, design/accessibility-requirements.md (all APPROVED)
> **Architecture Module**: `RunShell` + `RunController` + `ShellState` + `Screen` (base) + one script per U2 screen + `ToastLayer` + `RunDebugLoader` (`src/ui/run/`, `src/ui/shared/`)
> **Control Manifest**: Presentation Layer Rules (Manifest Version 2026-11-03)
> **Build Order**: 12 of 14 — plan E7, ADR-0011 / ADR-0008 / ADR-0001
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories run-ui`

## Overview

Build every screen outside a match as one `RunShell` whose screen stack mirrors Run Structure's phases: main menu, hero select, boss intro, the treasure-then-bundle drafts, the per-floor progress strip, victory and defeat summaries with a copyable seed, the resume prompt, the settings screen, the unlock toast queue and the `data_error` screen over a Failed load. Screens are display-only: they receive read models and send intents (`start_run`, `begin_match`, `pick(index)`, `continue`, `abandon`, `return_to_menu`) to `RunController`, the only object that talks to Run Structure, Reward Draft and `MetaApi`; every visible mutation renders from an event, transitions lock input under the `committed` sub-state, and `RunShell` hosts `MatchView` for the one-way hand-off. Pillar 3 is a UI promise here — a legible loss and a restart in under five seconds — and every screen is reachable from `--run-ui-screen` / `--run-ui-fixture` into the `MetaStub` for unattended screenshots.

## Scope (MVP)

- `RunShell`, `ShellState`, `@abstract Screen`, `RunController` intent → command map (U2), transition input lock (U4), toast queue + `ack_notification` (U5)
- Screens: main menu (Continue card from the stub), hero select (War only; locked panels for the rest per hero-select.md), boss intro with passive text, draft picker (treasure and bundle modes), progress strip, run summary (defeat / victory), resume prompt, settings (anim_speed, reduce_motion, telegraph_mode per DD-X07), data_error; **run log screen as the MVP stub only**
- Mouse primary, keyboard complete, 4.6 dual-focus ring; 44x44 hit rects for strip cells (a11y Motor row); `DisplayServer.clipboard_set` for Copy seed
- `RunDebugLoader` + `tests/fixtures/run_ui/*.json`; absent from release exports
- F1 budgets: restart ≤ 5000 ms (1.35 s same-hero path), `new_run` ≤ 200 ms, `intro_ready` / `select_ready` ≤ 300 ms

Out of scope (deferred list): gamepad mapping to the focus graph beyond what falls out of keyboard support; input remapping / controls screen (Alpha, ADR-0011 U2 row to add); the full run log screen (needs `MetaFacade` run-log pages); music / pause slider (a11y remainder).

## Salvage from the archived prototype (`prototypes/hearthstone-clone-2026-01/`, never imported)

- `scripts/discover_selection.gd` and `scripts/victory_selection.gd` (+ `.tscn`) — pick-1-of-N layouts for the draft picker's treasure and bundle modes; re-expressed under `interaction-patterns.md` Pick One of N and `draft-picker.md`

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0011: Run UI Shell Pattern and the Meta Stub Injection Seam | One `RunShell`, screen stack, `ShellState`, `RunController` sole talker; read models in, intents out; transition lock; toast queue; `--run-ui-fixture` into `MetaStub` through `Boot.boot(overrides)` | **HIGH** (UI 4.5–4.7; recursive Control disable property NOT SOURCEABLE — verify by `scene_runner()` before the story closes) |
| ADR-0008: Match Driver Ownership and the Run ↔ Match ↔ UI Hand-off | `RunShell` swaps `MatchView` in at `begin_match` and consumes `match_view_finished` after Run Structure processed `match_ended` | HIGH by version |
| ADR-0001: Rules / Presentation Split | Presentation tier definition; `Boot.services()` only at scene roots and debug loaders | HIGH |
| ADR-0010: Renderer Choice vs Xvfb Screenshot Capture | Fixture screenshots captured on CI with the Compatibility renderer; Windows confirmation advisory | HIGH |
| ADR-0009: Match UI Animation Queue and Scene Partition | Shared `card_frame.tscn`; `Control.offset_transform_*` for lifts; dual-focus rules | HIGH |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-run-ui-001 | U1: RunShell root scene with screen stack and ShellState; RunController is the only object talking to Run Structure, Reward Draft and Meta; screens get read models and send intent(name, args); every visible mutation renders from an event | ADR-0011 ✅ (also ADR-0001) |
| TR-run-ui-002 | U2: screen inventory with the complete intent -> command map; data_error screen over a Failed load | ADR-0011 ✅ (also ADR-0008) |
| TR-run-ui-003 | U3: mouse primary, keyboard complete; focus ring separate from hover (4.6 dual focus); gamepad maps to the focus graph | ADR-0011 ✅ (gamepad verification deferred to Alpha) |
| TR-run-ui-004 | U10: --run-ui-screen=<id> --run-ui-fixture=<name> loads tests/fixtures/run_ui/<name>.json into an in-memory Meta stub | ADR-0011 ✅ (also ADR-0001, 0010) |
| TR-run-ui-005 | F1: restart within restart_budget_ms (5000); new_run within 200 ms, intro_ready within 300 ms, select_ready within 300 ms | ADR-0011 ✅ |
| TR-design-decisions-003 (carried, shared with Match UI) | DD-T05: 1280x720 logical, canvas_items stretch, mouse primary, keyboard shortcuts | ADR-0011 ✅ (also ADR-0009, 0010) |
| TR-systems-index-002 (carried, shared with Match UI) | Circular Dependencies: Match UI <-> Run UI - one-way scene hand-off; the reverse edge is a signal only | ADR-0011 ✅ (also ADR-0008, 0009) |

Requirements covered by Accepted ADRs: 7 / 7. Untraced Requirements: None.

## Gate Entry Conditions Carried

- **Condition 11**: every UX doc APPROVED before its stories pass `/story-readiness` — hero-select (round 4), run-summary (round 4), draft-picker (round 3), interaction-patterns (round 4), accessibility-requirements (round 5) all APPROVED; advisories from those rounds are carried into the first UI stories.
- **Condition 5** (indirect): once this epic's hero select and boss intro exist, the first playable is launched from the menu instead of a fixture.

## Definition of Done

- Every story implemented, reviewed and closed with `/story-done`
- Every acceptance criterion of design/gdd/run-ui.md verified (32 criteria lines)
- Every U2 screen has a retained fixture screenshot in `production/qa/evidence/` at 100 % and the 150 % scale rows the UX specs define
- Logic and Integration stories have passing tests in the test root
- Visual/Feel and UI stories have retained screenshots in `production/qa/evidence/` (a lead sign-off too for Visual/Feel)
