# Story 016: Rejection feedback — shake, reason tooltip, related-control flash

> **Epic**: Match UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: S
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/match-ui.md` U5 (Rejection handling), U3.4a (player `command_rejected` → `reject_shake` + feed line), Input Responsiveness (rejection 50 ms), O10 · UX: `design/ux/hud.md` §5 Rejection row, §12 Notifications; `design/ux/interaction-patterns.md` Rejection Feedback, Tooltip
**Requirement**: `TR-match-ui-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009 (step-driven presenter visuals; `reject_shake` 0.2 s); ADR-0001 (the display is not changed by a rejection — nothing happened)
**ADR Decision Summary**: A rejected `submit` produces only the shake / tooltip step and a feed line; no other presenter changes.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Tooltip text via `tr("reject.<code>")`. Under `reduce_motion` the shake becomes a 2-frame outline flash (Story 023 asserts it).

**Control Manifest Rules (this layer)**:
- Required: All text `tr()` keys; durations from `config("match_ui")` (`REJECTION_TOOLTIP_S` 1.5).
- Forbidden: A presenter never stores a value the view-state does not have.
- Guardrail: rejection → shake + tooltip ≤ 50 ms.

---

## Acceptance Criteria

*From match-ui U5, O10, hud.md §12 Notifications:*

- [ ] **O10** GIVEN `--pose=reject:MUST_ATTACK_TAUNT`, WHEN captured, THEN the tooltip text is the localised `reject.MUST_ATTACK_TAUNT` reason at the cursor and the Taunt minions are flashed.
- [ ] GIVEN `--pose=reject:NOT_ENOUGH_MANA`, WHEN captured, THEN the mana bar outline is flashed, the tooltip reads the `reject.NOT_ENOUGH_MANA` copy, the ticker holds a `feed.command_rejected` line, and every other presenter is unchanged (`sync_report()` empty against the pre-rejection view-state).
- [ ] GIVEN a submit that the engine rejects (a race the disable missed, forced in a `scene_runner()` test), WHEN timed, THEN the originating control's shake and the tooltip start within 50 ms and the tooltip clears after `REJECTION_TOOLTIP_S` (1.5 s).

---

## Implementation Notes

- Implement `--pose=reject:<code>` (shake + tooltip frozen). Tooltip is a shared `src/ui/common/tooltip.tscn` (Run UI reuses it).
- Flash targets per code from a small data table in `match_ui.json` (`MUST_ATTACK_TAUNT` → taunts, `NOT_ENOUGH_MANA` → mana bar).

---

## Out of Scope

- Story 023: the `reduce_motion` variant.

---

## Files

- `src/ui/common/tooltip.tscn`, `src/ui/common/tooltip.gd`
- `src/ui/match/hero_presenter.gd`, `board_presenter.gd`, `hand_presenter.gd` (flash / shake handlers)
- `src/ui/match/match_debug_loader.gd` (`reject:` pose)
- `tests/integration/match_ui/rejection_feedback_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- UI: retained screenshots `01-reject-must-attack-taunt.png`, `02-reject-not-enough-mana.png` in `production/qa/evidence/story-016-rejection-feedback/` via `tools/capture.sh`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/match-ui/story-008-drag-to-play-attack-and-targeting-arrow.md`, `production/epics/match-ui/story-014-event-feed.md`
- UX: `design/ux/targeting.md` (rejection tooltip owner per UI Requirements) not authored (gate condition 11 note as in Story 006)
- Unlocks: `production/epics/match-ui/story-023-impact-moments-and-reduce-motion.md`
