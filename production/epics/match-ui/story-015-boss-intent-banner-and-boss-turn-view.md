# Story 015: Boss intent banner and the boss-turn view — commit beat, skip hint, hand dim, --pause-at

> **Epic**: Match UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: L
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/match-ui.md` U3 (`ai_intent_shown`, `ai_intent_committed`, `effective_mode`), U6, States (`BossTurn` hand dim), U11 (`--pause-at`), Input Responsiveness (End Turn → commit beat 300 ms, skip 100 ms), O8, O9 · UX: `design/ux/hud.md` §4.2 intent banner / skip hint, §5 `BossTurn` and `effective_mode = hidden` rows, §12 Per-Context rows; `design/ux/interaction-patterns.md` Boss Intent Banner, Skip & Playback
**Requirement**: `TR-match-ui-003`, `TR-match-ui-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009 (`BannerPresenter` — turn banner, intent banner `full` / `brief` / `hidden` renderings; boss-turn mode); ADR-0008 (`ai_intent_shown` appended on the main thread by the driver; `is_planning()` UI hint)
**ADR Decision Summary**: The banner renders exactly the `effective_mode` Boss AI emits (never re-applying `telegraph_mode`); the "plan changed" crossfade may be an authored `AnimationPlayer` clip under the queue's clock; skip-all at any time leaves the banner at its view-state final.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: `AnimationPlayer` only for the target-free crossfade on `BannerPresenter`, fire-and-forget. Captures of mid-turn frames need `--pause-at=<seq>`, introduced here.

**Control Manifest Rules (this layer)**:
- Required: Boss-turn mode (Story 010); `AnimationPlayer` only for authored target-free clips.
- Forbidden: Never `AnimationPlayer` per presenter for data-driven steps.
- Guardrail: Skip-all → display = view-state ≤ 100 ms.

---

## Acceptance Criteria

*From match-ui O8, O9, Input Responsiveness and hud.md §12:*

- [ ] **O8** GIVEN `boss_intent_full`, WHEN captured, THEN the banner at 980,52,276,36 shows an intent icon, label, amount and a reticle on the named target; GIVEN `boss_intent_plan_changed`, THEN the "plan changed" label is visible; GIVEN `boss_intent_hidden` (band-3 boss, `effective_mode = hidden`), THEN a "?" plate fills the banner rect with no icon, amount or reticle.
- [ ] **O9** GIVEN `boss_turn_playback --pause-at=<seq>` inside the boss turn, WHEN captured, THEN End Turn is disabled, no hand card or token carries the actionable outline, the hand zone is dimmed to `table_dark` (60 %), and the skip hint occupies 980,90,152,20 once 1 s has elapsed.
- [ ] GIVEN `Idle` with a forecast shown, WHEN End Turn is clicked, THEN the boss intent commit beat is visible within 300 ms (`scene_runner()` timing, Linux CI).
- [ ] GIVEN skip-all (click, `Space` or `Enter`) during `boss_turn_playback`, WHEN the frame after the input is captured, THEN every presenter equals `MatchViewState` (U4.6), the intent banner shows its final state and the turn banner text is present.

---

## Implementation Notes

- Banner rect, skip-hint delay and rect from `config("match_ui")`; the 1 s skip-hint delay is prose in the GDD with no data key (hud.md OQ `SKIP_HINT_DELAY_S` — Open). Add the key to `match_ui.json` as part of this story and note it for the GDD owner, or keep a named config default; never a literal in code.
- `--pause-at=<seq>`: stop `advance()` with the queue holding every step after `seq` (MatchDebugLoader, MatchView).
- Fixtures: `boss_intent_full`, `boss_intent_plan_changed`, `boss_intent_hidden`, `boss_turn_playback` (12-action turn). `boss_intent_hidden` needs a band-3 boss with `intent_mode: hidden` — none ships at batch 0; use a test-only boss def via the card-database fixture root.
- Hand dim: `HandPresenter` modulates the zone fill only (card contrast unchanged), one step, on `BossTurn` enter / exit.

---

## Out of Scope

- Story 010: F4 arithmetic. Story 022: `--ai-debug` overlay.

---

## Files

- `src/ui/match/banner_presenter.gd`, `src/ui/match/banner.tscn`
- `src/ui/match/hand_presenter.gd` (dim), `src/ui/match/match_debug_loader.gd` (`--pause-at`)
- `assets/data/match_ui.json` (skip-hint key, if added)
- `tests/fixtures/match_ui/boss_intent_full.json`, `boss_intent_plan_changed.json`, `boss_intent_hidden.json`, `boss_turn_playback.json`
- `tests/integration/match_ui/boss_turn_view_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- UI: retained screenshots `01-boss_intent_full.png`, `02-boss_intent_plan_changed.png`, `03-boss_intent_hidden.png`, `04-boss_turn_playback-paused.png`, `05-after-skip.png` in `production/qa/evidence/story-015-boss-intent-banner-and-boss-turn-view/` via `tools/capture.sh`
- Also: `tests/integration/match_ui/boss_turn_view_test.gd` passes

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/match-ui/story-010-boss-turn-pacing.md`, `production/epics/match-ui/story-012-first-playable-windows-match.md`; `production/epics/boss-ai-match-driver/story-011-forecast-and-telegraphing.md`
- Unlocks: `production/epics/match-ui/story-022-debug-loader-poses-and-fixture-sweep.md`, `production/epics/match-ui/story-023-impact-moments-and-reduce-motion.md`
