# Story 023: Impact moments and reduce motion — hit-stop, shake, lethal slow-down, feel timings

> **Epic**: Match UI
> **Status**: In Review
> **Layer**: Presentation
> **Type**: Visual/Feel
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/match-ui.md` Game Feel (Animation Feel Targets, Impact Moments, Weight and Responsiveness Profile), F3 (impact extras dropped at `fast` / `reduce_motion`) · `design/gdd/match-rules.md` Game Feel · UX: `design/ux/hud.md` §5 `reduce_motion` row, §10.3 Motion Sensitivity, §12 Accessibility (`reduce_motion` row); `design/ux/interaction-patterns.md` Animation Standards; `design/accessibility-requirements.md` Reduce-motion (elevated Comprehensive), Test Plan "Reduce motion"
**Requirement**: `TR-match-ui-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009 (impact extras are queue-local clock multipliers; never `Engine.time_scale`)
**ADR Decision Summary**: Hit-stop, shake and slow-down live in the queue's clock and the presenters' tweens; dropped at `fast` or under `reduce_motion`; skip-all cancels them.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Shake moves the table root via `offset_transform_*` if it sits in a container (4.7), else `position`; never the camera (no 3D, no `Camera2D` requirement). Ease-out only — no ease-in anywhere.

**Control Manifest Rules (this layer)**:
- Required: impact extras are queue-local clock multipliers dropped at `fast` or `reduce_motion`.
- Forbidden: Never `Engine.time_scale` for hit-stop; never `await` / `Timer` per step.
- Guardrail: n/a.

---

## Acceptance Criteria

*From match-ui Game Feel and hud.md §12 Accessibility:*

- [ ] GIVEN an attack at `normal`, WHEN played, THEN attacker and defender freeze 60 ms on contact (90 ms for hero damage ≥ 5), hero damage ≥ 5 or lethal shakes 3 px decaying over 120 ms, and the lethal `damage_dealt` step plays at time-scale 0.5 for 400 ms — all driven by the queue clock (unit-asserted durations; mid-step frames retained).
- [ ] GIVEN `reduce_motion = true` in the fixture profile, WHEN `divine_shield_hit` and `simultaneous_deaths` play at `normal`, THEN no hit-stop, shake or slow-down occurs, pops fade in place, `reject_shake` becomes a 2-frame outline flash, the `lethal` banner pulse is static, and positional travel (card-to-slot, lunge, draw, death) still plays with `d_base` unchanged.
- [ ] GIVEN the Animation Feel Targets table (card play 4/8/4 frames, lunge 6/3/9, death group 6/6/6, hover 0/6/0, drag return 0/9/0 ease-out no bounce), WHEN mid-step frames are captured with `--pause-at`, THEN they match the table, and the lead (Jacob) signs off the feel in the evidence file.

---

## Implementation Notes

- Extend `AnimStep.impact` handling in `animation_queue.gd`; presenters read `impact` in `on_step_started` for the visual (freeze = tween pause on both participants; shake = decaying offset tween on the table root).
- Unit additions in `tests/unit/match_ui/animation_queue_test.gd` for impact durations at `normal`, `fast`, `reduce_motion`.

---

## Out of Scope

- Story 024: playtest-level Feel Acceptance Criteria.

---

## Files

- `src/ui/match/animation_queue.gd`, `src/ui/match/board_presenter.gd`, `src/ui/match/hero_presenter.gd`, `src/ui/match/match_view.gd`
- `tests/unit/match_ui/animation_queue_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- Visual/Feel: retained mid-step screenshots in `production/qa/evidence/story-023-impact-moments-and-reduce-motion/` (via `tools/capture.sh` with `--pause-at`) + sign-off in `production/qa/evidence/story-023-impact-moments-and-reduce-motion-evidence.md`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/match-ui/story-015-boss-intent-banner-and-boss-turn-view.md`, `production/epics/match-ui/story-016-rejection-feedback.md`
- Unlocks: `production/epics/match-ui/story-024-input-latency-and-feel-validation.md`
