# Story 011: Match-end banner and the match_view_finished hand-off

> **Epic**: Match UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/match-ui.md` U9 (Match end, `fault` variant), U3 (`match_ended`, `log_overflow`, `resolution_overflow`), States (`Ended`), Interactions (Run UI row), O13, O19 (`Ended` half) · UX: `design/ux/hud.md` §5 `Ended` row, §12 Per-Context rows. UI Requirements names `design/ux/match-end.md`, not yet authored.
**Requirement**: `TR-match-ui-006`, `TR-systems-index-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008 (Decision 8 hand-off: `match_view_finished(result)` after the end banner; `RunMachine` has already processed `match_ended`); ADR-0009 (`banner.tscn` — `BannerPresenter`, the one place `AnimationPlayer` clips are allowed); ADR-0011 (`RunShell` consumes `match_view_finished`)
**ADR Decision Summary**: `MatchView` emits `match_view_finished(result)` once, after the end banner (click or `MATCH_END_AUTO_S`); it never navigates, never reads `RunState`, never knows about floors; the reverse edge to Run UI is this signal only.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: An `AnimationPlayer` flourish on the banner is allowed only as a target-free, fire-and-forget clip under the queue's clock. `_exit_tree` → `controller.shutdown()` (Story 004) must still run after the hand-off.

**Control Manifest Rules (this layer)**:
- Required: `MatchView` emits `match_view_finished(result)` after the end banner.
- Forbidden: `MatchView` never reads `RunState`, navigates, or knows about floors. The shell never changes screen while `MatchView` is up.
- Guardrail: n/a.

---

## Acceptance Criteria

*From match-ui O13, O19, U9 and ADR-0008 Verification:*

- [ ] **O13** GIVEN `match_end_victory`, `match_end_defeat`, `match_end_both_dead` and `match_end_concede`, WHEN captured, THEN each banner (340,260,600,200) carries its own `end.<reason>` copy and the winning hero portrait (if any) is saturated to its primary; GIVEN `match_end_fault` (a scripted `resolution_overflow`), THEN the banner reads the `end.fault` "Rules fault — this floor is replayed, not lost" copy on a neutral frame, neither portrait is saturated, and the audio log shows no `sfx.ui.defeat`.
- [ ] GIVEN `match_ended` projected, WHEN the queue drains, THEN the view enters `Ended`, the 0.6 s end banner plays, no command can be submitted, and `match_view_finished(result)` is emitted exactly once — on a click / `Enter`, or after `MATCH_END_AUTO_S` (4 s, from config) with no input.
- [ ] **O19 (Ended)** GIVEN `match_end_victory`, WHEN `Esc` is pressed (and the top-bar menu button clicked), THEN the view is still `Ended`, no pause menu opens, and the capture is pixel-identical to the un-pressed one (DD-X09).
- [ ] GIVEN a `RunShell` test double that swapped `MatchView` in with `MatchController.new(driver)`, WHEN the match ends, THEN the double receives `match_view_finished(result)` after `driver.match_ended` reached its `RunMachine` listener, `MatchView` made no scene change itself, and the driver graph is freed after the view leaves the tree (`weakref` check).

---

## Implementation Notes

- `src/ui/match/banner_presenter.gd` on `banner.tscn` — end-banner variant here; turn banner and intent banner are Story 015.
- Fixtures `match_end_*.json` (five) run the real engine to the ending; `match_end_concede` scripts a `concede` command; `match_end_fault` scripts a `resolution_overflow` (rng-event-log story 007's fault path).
- Implement `--pose=end:<reason>` only if a fixture cannot reach a reason; prefer the fixtures.
- Audio log: the SFX stub layer records cue ids per frame in debug builds; the fault test asserts `sfx.ui.defeat` absent. If no SFX stub exists yet, add the minimal cue logger here (epic scope: "minimal SFX stubs").

---

## Out of Scope

- `run-ui` epic: the real `RunShell` and `match_faulted → pre_match` replay. Story 019: pause menu in non-`Ended` states.

---

## Files

- `src/ui/match/banner.tscn`, `src/ui/match/banner_presenter.gd`
- `src/ui/match/match_view.gd` (`Ended` state, `match_view_finished`)
- `src/ui/match/sfx_stub.gd`
- `tests/fixtures/match_ui/match_end_victory.json`, `match_end_defeat.json`, `match_end_both_dead.json`, `match_end_concede.json`, `match_end_fault.json`
- `tests/integration/match_ui/match_end_handoff_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- UI: retained screenshots `01`–`05` (one per `match_end_*` fixture) and `06-victory-after-esc.png` in `production/qa/evidence/story-011-match-end-banner-and-handoff/` via `tools/capture.sh`
- Also: `tests/integration/match_ui/match_end_handoff_test.gd` passes

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/match-ui/story-005-hero-panels-mana-and-end-turn.md`; `production/epics/match-rules/story-008-win-loss-concede-result.md`; `production/epics/rng-event-log/story-007-overflow-fault-and-config-knobs.md`; `production/epics/boss-ai-match-driver/story-015-match-driver-tick-replay-and-shutdown.md`
- UX: `design/ux/match-end.md` not authored (gate condition 11 note as in Story 006)
- Unlocks: `production/epics/match-ui/story-012-first-playable-windows-match.md`; `run-ui` epic (RunShell hand-off, not yet storied)
