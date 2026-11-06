# Story 018: Keyboard focus cycling, the focus ring and inspect-on-focus

> **Epic**: Match UI
> **Status**: In Review
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/match-ui.md` U5 (Keyboard inspect — focus cycling in `Idle`), U11 (`--pose=focus:<element>`), O17 (capture half), O18 · UX: `design/ux/hud.md` §10 Focus Order, §12 Focus & Input; `design/ux/interaction-patterns.md` Focus Management, Card Inspect, Hero Power Button; `design/accessibility-requirements.md` Test Plan "Focus visibility and order"
**Requirement**: `TR-design-decisions-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009 (`InputRouter` focus cycling; the focus ring is keyboard focus only, 4.6 dual focus)
**ADR Decision Summary**: The ring is drawn from `focus_entered` / `focus_exited`; hover is a lift and never moves focus; `grab_focus()` moves keyboard focus only; focus opens the same information hover does.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Godot 4.6 split mouse hover from keyboard focus (sourced: `modules/ui.md` § Focus Management) — verify on 4.7.2 with a capture where the ring sits on one card while the cursor hovers another (ADR-0009 Verification table). Ring line width explicit (4.7, no feather).

**Control Manifest Rules (this layer)**:
- Required: Focus ring drawn from keyboard focus; `grab_focus()` on the screen's default focus after every transition.
- Forbidden: Never draw the focus ring from hover.
- Guardrail: n/a.

---

## Acceptance Criteria

*From match-ui U5, O17, O18 and hud.md §12 Focus & Input:*

- [ ] GIVEN `Idle`, WHEN `Tab` is pressed repeatedly from the default stop, THEN focus visits hand → player row → hero power → player portrait → treasure chips → End Turn → feed toggle → menu → intent banner → boss row → boss portrait → wrap, never lands on a pile, the mana bar or top-bar text; on entering `Idle` focus goes to End Turn when nothing is lit, else the left-most playable card; a focused card leaving the hand moves focus to the card now at that index, else End Turn.
- [ ] **O18** GIVEN `turn1_player --pose=focus:hero_power` with the power `Blocked`, WHEN captured, THEN a 2 px `state_actionable` ring sits 3 px outside the button and the tooltip names the `Blocked` reason with no pointer hover; GIVEN `--pose=focus:0`, THEN the ring and the 1.5x preview are both visible — also at `--anim-speed=instant`.
- [ ] GIVEN `midgame_full_board --pose=focus:<token id>` with the cursor parked over a different card, WHEN captured, THEN the ring is on the focused token only and the hovered card shows its lift without a ring (4.6 dual focus observed on 4.7.2).
- [ ] **O17 (captures)** GIVEN the `focus:*` / `select:*` captures and their `hover:` / `drag:` pairs on the same fixture, WHEN diffed, THEN the focus ring is the only differing pixel region; all pairs are retained.

---

## Implementation Notes

- Implement `--pose=focus:<element>` (`<hand index>`, token instance id, `hero_power`, `end_turn`, `treasure:<n>`).
- Ring: one `FocusRing` control drawn above the focused element's bounds + 3 px, 2 px `state_actionable`; independent of `anim_speed`.
- Focus neighbours declared per presenter (`focus_neighbor_*`) so the gamepad mapping later stays possible.
- `focus:treasure:<n>` capture is Story 021 (tray).

---

## Out of Scope

- Story 021: treasure-chip focus and its 44x44 hit rect. Story 019: pause-menu focus and return.

---

## Files

- `src/ui/match/focus_ring.gd`, `src/ui/match/input_router.gd` (focus order)
- `src/ui/match/hand_presenter.gd`, `board_presenter.gd`, `hero_presenter.gd` (focus-opened preview / tooltip)
- `src/ui/match/match_debug_loader.gd` (`focus:` pose)
- `tests/integration/match_ui/focus_order_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- UI: retained screenshots (focus hero power blocked, focus hand 0, focus token with hover elsewhere, each `focus:` / `select:` capture beside its `hover:` / `drag:` pair) in `production/qa/evidence/story-018-focus-cycling-and-inspect-on-focus/` via `tools/capture.sh`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/match-ui/story-006-hand-fan-and-hover-preview.md`, `production/epics/match-ui/story-017-click-to-select-and-keyboard-targeting.md`
- Unlocks: `production/epics/match-ui/story-019-pause-menu-concede-and-esc-chain.md`, `production/epics/match-ui/story-021-treasure-tray.md`
