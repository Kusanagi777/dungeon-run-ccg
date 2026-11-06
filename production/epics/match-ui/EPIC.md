# Epic: Match UI

> **Layer**: Presentation
> **GDD**: design/gdd/match-ui.md (Overview, Detailed Rules U1–U7, U9, U11, U12, Formulas F3–F4, Input Responsiveness, Interactions "Run Structure" / "Run UI", Acceptance Criteria) · design/ux/hud.md (APPROVED round 3) · design/ux/interaction-patterns.md
> **Architecture Module**: `MatchView` + presenters + `TargetingArrow` + `InputRouter` + `MatchController` + `MatchQuery` + `MatchViewState` + `AnimationQueue` + `MatchDebugLoader` (`src/ui/match/`, shared `src/ui/common/card_frame.tscn`)
> **Control Manifest**: Presentation Layer Rules (Manifest Version 2026-11-03)
> **Build Order**: 7 of 14 — plan E5, ADR-0009 / ADR-0008 / ADR-0001 / ADR-0010
> **Status**: Ready
> **Stories**: 24 (see the table below) — created 2026-11-03 by `/create-stories match-ui`

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | MatchViewState — pure projection, hidden information and the unknown / diagnostic filters | Logic | Ready | ADR-0009, ADR-0003, ADR-0001 |
| 002 | AnimStep and AnimationQueue — command groups, coalescing, F3 speed, skip-all and the idle invariant | Logic | Ready | ADR-0009 |
| 003 | MatchController and MatchQuery — the three channels, flush-before-submit and engine parity | Integration | Ready | ADR-0008, ADR-0001, ADR-0009 |
| 004 | MatchView skeleton, Presenter base, the --fixture loader, first capture and /perf-profile | UI | Ready | ADR-0009, ADR-0010, ADR-0008 |
| 005 | Hero panels, mana bar, deck piles, top bar, hero power and End Turn | UI | Ready | ADR-0009, ADR-0001 |
| 006 | Hand fan and hover preview — F1, F2 and the shared CardFrame | UI | Ready | ADR-0009 |
| 007 | Board rows — minion tokens, summon, death group, gap-close and the offset_transform lunge | UI | Ready | ADR-0009 |
| 008 | Drag to play, drag to attack and the targeting arrow | UI | Ready | ADR-0009, ADR-0001 |
| 009 | Mulligan screen — keep / replace any subset, Confirm | UI | Ready | ADR-0009, ADR-0001 |
| 010 | Boss-turn pacing — F4 gap and compression, boss-turn mode and control lock | Logic | Ready | ADR-0009, ADR-0008, ADR-0003 |
| 011 | Match-end banner and the match_view_finished hand-off | UI | Ready | ADR-0008, ADR-0009, ADR-0011 |
| 012 | First playable — one War match vs The Torchbearer, mouse-played, on the Windows export | Integration | Ready | ADR-0010, ADR-0009, ADR-0008 |
| 013 | Choice overlay — Discover and Choose One | UI | Ready | ADR-0009 |
| 014 | Event feed — ticker, drawer, command-root grouping and collapse | UI | Ready | ADR-0009, ADR-0001, ADR-0003 |
| 015 | Boss intent banner and the boss-turn view — commit beat, skip hint, hand dim, --pause-at | UI | Ready | ADR-0009, ADR-0008 |
| 016 | Rejection feedback — shake, reason tooltip, related-control flash | UI | Ready | ADR-0009, ADR-0001 |
| 017 | InputRouter — click-to-select, keyboard targeting, shortcuts and the End Turn arm guard | Logic | Ready | ADR-0009 |
| 018 | Keyboard focus cycling, the focus ring and inspect-on-focus | UI | Ready | ADR-0009 |
| 019 | Pause menu, concede and the Esc chain | UI | Ready | ADR-0009, ADR-0011, ADR-0008 |
| 020 | Live settings — text_scale variants, high-contrast states, gamma and letterboxing | UI | Ready | ADR-0009, ADR-0011, ADR-0010 |
| 021 | Treasure tray — chips, 44x44 hit rects, tooltip on hover or focus, hook flare | UI | Ready | ADR-0009, ADR-0001 |
| 022 | Debug loader completion — argument parsing, --anim-speed, --ai-debug overlay and the full fixture sweep | Integration | Ready | ADR-0009, ADR-0010 |
| 023 | Impact moments and reduce motion — hit-stop, shake, lethal slow-down, feel timings | Visual/Feel | Ready | ADR-0009 |
| 024 | Input latency table measured, and the Feel acceptance playtest | Integration | Ready | ADR-0009, ADR-0010 |
| 025 | Hero power by drag — an untargeted Ready hero power is dragged to the cast zone (Phase C) | UI | Ready | ADR-0009, ADR-0001 |

First-playable slice: 001–012 (gate condition 5). Dependency order: 001 → 002 → 003 → 004 (carries `/perf-profile`, gate condition 10) → 005, 006, 007, 009, 010 → 008 (needs 005–007) → 011 → 012 · after the slice: 013, 014, 017 → 015 (needs 010), 016 (needs 008, 014), 018 (needs 006, 017) → 019 (needs 013, 017, 018) → 021 (needs 014, 018) → 020 (needs 015, 019, 021) → 022 (needs 014, 015) → 023 (needs 015, 016) → 024. Logic tests live under `tests/unit/match_ui/`, Integration under `tests/integration/match_ui/`; UI evidence under `production/qa/evidence/<story-slug>/` via `tools/capture.sh`. QL-STORY-READY skipped — Lean mode.

## Overview

Turn a match into something the owner can play with a mouse: hand fan, two board rows, hero panels with health, armour, weapon and hero power, mana bar, targeting arrow, intent banner, mulligan screen, Choice overlay, event feed and the end banner. The layer is deliberately thin and one-directional: `MatchController.submit` is the only way in, `subscribe` / `events_since` the only way out, `MatchQuery` value copies the only read. `MatchViewState.apply(event)` is a pure projection into `AnimStep`s; the `AnimationQueue` schedules them FIFO by command root with coalescing, the speed divisor, boss-turn pacing compressed to `max_turn_playback_s`, and `skip_all()` within 100 ms before every submit; presenters tween on `step_started` and are authoritative only at `apply_final`. Each screen is reachable unattended through `--fixture` for retained screenshots. This is the first playable's surface, so `/perf-profile` runs at its first story and the Windows export is confirmed here.

## Scope (MVP)

- Scene partition per ADR-0009 (`match_view.tscn` root + one scene per presenter + shared card frame); `@abstract Presenter` with `bind`, `owns`, `on_step_started`, `apply_final`, `sync_report`
- `MatchViewState`, `AnimationQueue`, `AnimStep` as headless-testable `RefCounted` with a fake clock; `COALESCE_THRESHOLD` 8, `SPEED_DIV`, `reduce_motion`, `anim_speed` from `SettingsBus`
- Mouse-first input: drag-to-play, drag-to-attack, hero power, End Turn, hover text ≤ 100 ms; latency table (pickup / drag 16 ms, release → first event 50 ms, rejection 50 ms, skip 100 ms, End Turn → commit beat `max(300 ms, planner run)` ≤ 500 ms then "boss thinking" — 2026-11-04, DD-X23; was End Turn → intent 300 ms)
- Mulligan screen (Hearthstone rules), Choice overlay for Discover / Choose One, intent banner, event feed, end banner, pause menu
- `MatchDebugLoader` (`--fixture`, `--pose`, `--pause-at`, `--anim-speed`, `--ai-debug`), fixtures under `tests/fixtures/match_ui/`, absent from release exports (CI greps the `.pck`)
- `match_view_finished(result)` hand-off signal

Out of scope: gamepad and input remapping (Alpha, deferred list); audio beyond minimal SFX stubs; custom art (Full Vision).

## Salvage from the archived prototype (`prototypes/hearthstone-clone-2026-01/`, never imported)

- `scripts/card_ui.gd` + `scenes/card_ui.tscn` — hover lift and drag feel; re-express as `Control.offset_transform_*` inside containers (ADR-0009)
- `scripts/targeting_arrow.gd` + `scenes/targeting_arrow.tscn` — bezier arrow; keep the curve math, drop the Node-side state reads
- `scripts/mulligan_screen.gd` — layout only; rules fixed to Hearthstone mulligan as match-rules specifies
- `scripts/discover_selection.gd` — pick-1-of-N layout informs the Choice overlay (shared pattern with Run UI's draft picker)

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0009: Match UI Animation Queue, Tween Approach and Scene Partition | `Tween` (+ `tween_await` 4.7) over `AnimationPlayer`; `Control.offset_transform_*` lifts; queue schedules, presenters tween; one scene per presenter; process-tick timing; dual-focus (4.6) | **HIGH** (UI + Animation 4.5–4.7; specific APIs sourced) |
| ADR-0008: Match Driver Ownership and the Run ↔ Match ↔ UI Hand-off | `MatchController` wraps the driver it does not own; `MatchConfig` + driver in, `match_view_finished(result)` back after Run Structure processes `match_ended` | HIGH by version |
| ADR-0001: Rules / Presentation Split | Three channels only; presenters render numbers from events, not queries; `queue_free` only under `src/ui/` | HIGH |
| ADR-0010: Renderer Choice vs Xvfb Screenshot Capture | Shipped Forward+, CI capture via Compatibility/llvmpipe; per-UI-story Windows confirmation row is advisory | HIGH (rendering 4.5–4.7; capture observed in Probe C) |
| ADR-0003: Seeded RNG Service and Event Log | Subscribers synchronous, main-thread, by value; `events_since(seq)` replay | HIGH / NOT SOURCEABLE |
| ADR-0011: Run UI Shell Pattern | `RunShell` hosts `MatchView` and consumes `match_view_finished` | HIGH |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-match-ui-001 | U1, U2: MatchView scene + MatchController (injected) + MatchQuery + MatchViewState + AnimationQueue + presenters + InputRouter; three channels only: commands in, events out, queries out | ADR-0009 ✅ (also ADR-0001, 0008) |
| TR-match-ui-002 | U3, U4: the presentation model is a projection of events; AnimStep FIFO grouped by command root (cause_seq = 0), coalescing, speed divisor, skip-all within 100 ms, idle invariant (presenters == view-state) | ADR-0009 ✅ (also ADR-0003) |
| TR-match-ui-003 | U6: the boss turn is already in the log when the UI sees it; the UI paces the burst, compressing to max_turn_playback_s | ADR-0009 ✅ (also ADR-0003, 0006, 0008) |
| TR-match-ui-004 | U11: debug entry points --fixture=<name>, --pose, --pause-at, --anim-speed, --ai-debug via OS.get_cmdline_user_args(); fixtures tests/fixtures/match_ui/<name>.json run the real engine; MatchDebugLoader absent from release exports | ADR-0009 ✅ (also ADR-0001, 0008, 0010) |
| TR-match-ui-005 | Input Responsiveness latency table: pickup 16 ms, drag 16 ms, release to first event 50 ms, rejection 50 ms, skip 100 ms, End Turn to intent 300 ms, hover 100 ms | ADR-0009 ✅ |
| TR-match-ui-006 | Interactions (Run UI): hand-off - Run UI swaps MatchView in at begin_match with MatchConfig + MatchController; Match UI emits match_view_finished(result) after the end banner | ADR-0008 ✅ (also ADR-0009, 0011) |
| TR-design-decisions-003 (carried, shared with Run UI) | DD-T05: 1280x720 logical, canvas_items stretch, mouse primary, keyboard shortcuts | ADR-0009 ✅ (also ADR-0010, 0011) |
| TR-systems-index-002 (carried, shared with Run UI) | Circular Dependencies: Match UI <-> Run UI - one-way scene hand-off; the reverse edge is a signal only | ADR-0008 ✅ (also ADR-0009, 0011) |
| TR-game-concept-001 (carried) | Technical Considerations: headless test and screenshot evidence on Linux CI (Xvfb); Forward+ may need the Compatibility renderer for capture | ADR-0010 ✅ |

Requirements covered by Accepted ADRs: 9 / 9. Untraced Requirements: None.

## Gate Entry Conditions Carried

- **Condition 5**: first playable — Windows export, one War match vs one band-1 boss, mouse-played, within sprints 1–2; the owner plays it as playtest #1 (launched through a `--fixture` until Run UI lands).
- **Condition 8**: CI builds the Windows export and publishes it; the owner retains `production/qa/evidence/windows-first-light-<date>/`.
- **Condition 10**: draw calls / memory ceiling confirmed by `/perf-profile` at the **first** Match UI story; `architecture.md` §Performance budgets updated.
- **Condition 11**: `design/ux/hud.md` is APPROVED (round 3); each story cites it before `/story-readiness`.

## Definition of Done

- Every story implemented, reviewed and closed with `/story-done`
- Every acceptance criterion of design/gdd/match-ui.md verified (37 criteria lines)
- Every fixture screen has a retained screenshot in `production/qa/evidence/`; `MatchView._assert_in_sync()` passes after every drain in debug
- Logic and Integration stories have passing tests in the test root
- Visual/Feel and UI stories have retained screenshots in `production/qa/evidence/` (a lead sign-off too for Visual/Feel)
