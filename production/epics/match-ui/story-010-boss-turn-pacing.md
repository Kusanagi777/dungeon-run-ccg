# Story 010: Boss-turn pacing — F4 gap and compression, boss-turn mode and control lock

> **Epic**: Match UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/match-ui.md` U6 (rules 1–6), F4 (gap and compression), States (`BossTurn`)
**Requirement**: `TR-match-ui-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009 (Decision §2, boss-turn mode); ADR-0008 (`tick()` replay drives the burst into the log); ADR-0003 (events delivered synchronously, in order)
**ADR Decision Summary**: Boss-turn mode is entered on `turn_started{side: boss}` and exited when `turn_started{side: player}` has drained; the commit beat plays first; F4's `gap` and `k` are computed when the first action group would start over the groups then queued; later groups reuse that `gap`; the remainder auto-skips if the total would exceed `max_turn_playback_s`.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (by version; Node-free logic)
**Engine Notes**: ADR-0006 may replay a plan across a few ticks; the "computed at first group" rule makes a partial burst less compressed, never wrong. No `Engine.time_scale`, no `await`.

**Control Manifest Rules (this layer)**:
- Required: Boss-turn mode as above; `anim_speed`, `action_delay_ms` from `SettingsBus`; pacing knobs from Boss AI data (`presentation.action_delay_s`, `max_turn_playback_s`, `intent_banner_s`) and `config("match_ui")` (`MIN_ACTION_GAP_S`, `K_MIN`).
- Forbidden: Never hardcoded setting defaults.
- Guardrail: the queue holds at most one boss turn of steps (≤ 30 groups).

---

## Acceptance Criteria

*From match-ui Acceptance Criteria L8, L16 and U6:*

- [ ] **L8** GIVEN a boss turn with A = 12 groups and D = 7.0 s at defaults, WHEN F4 runs, THEN gap = 0.245 s (±0.001) and T = 10.0 s; GIVEN A = 30, D = 15 s, THEN gap = 0.15, k = 0.509 (±0.001) and the turn plays in 10.0 s; GIVEN A = 5, D = 2.5 s, THEN gap 0.6 and T = 5.2 s.
- [ ] **L16** GIVEN `settings.action_delay_ms = 1200` and a boss turn with A = 5, D = 2.5 s, WHEN F4 runs, THEN gap = 1.2 s and T = 7.6 s; GIVEN the setting absent, THEN gap = 0.6 s (Boss AI's `presentation.action_delay_s`).
- [ ] GIVEN `turn_started{side: boss}` then a burst whose groups arrive over two ticks, WHEN the queue plays it with a fake clock, THEN the commit beat (`intent_banner_s`) plays before the first action group, the second tick's groups use the gap computed at the first group, the remainder auto-skips once `k = K_MIN` and the clock reaches `max_turn_playback_s`, player controls report locked (only skip, pause menu and feed allowed) until `turn_started{side: player}` has drained, and a boss-side Choice produces one 0.4 s "boss discovers…" step with no options.

---

## Implementation Notes

- Fill `AnimationQueue.enter_boss_turn(pacing)` / `exit_boss_turn()` (Story 002 stubs); `MatchView` calls them from the projected `turn_started` steps.
- `ai_action_delay_s = settings.action_delay_ms / 1000` when present, else Boss AI's value read from `config("ai_profiles").presentation` (via the injected config, never parsed by the UI).
- Expose `InputRouter.controls_locked()` derived from view state + queue; Story 015 renders the lock (End Turn disabled, hand dim, skip hint).

---

## Out of Scope

- Story 015: intent banner rendering, skip hint, hand dim, End Turn → commit beat ≤ 300 ms measurement.

---

## Files

- `src/ui/match/animation_queue.gd`
- `src/ui/match/input_router.gd` (`controls_locked`)
- `tests/unit/match_ui/boss_turn_pacing_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/match_ui/boss_turn_pacing_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/match-ui/story-002-animation-queue-core.md`; `production/epics/boss-ai-match-driver/story-003-ai-profiles-mvp-data.md` (`presentation.*` knobs), `production/epics/boss-ai-match-driver/story-015-match-driver-tick-replay-and-shutdown.md`
- Unlocks: `production/epics/match-ui/story-012-first-playable-windows-match.md`, `production/epics/match-ui/story-015-boss-intent-banner-and-boss-turn-view.md`
