# Story 017: InputRouter — click-to-select, keyboard targeting, shortcuts and the End Turn arm guard

> **Epic**: Match UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/match-ui.md` U5 (Click to select, Keyboard, End Turn arm guard), States (`KeyTargeting`, transitions), L15, L17, O17 (headless half) · UX: `design/ux/interaction-patterns.md` Click-to-Select / Keyboard Targeting, End Turn Button, Standard Shortcuts, Escape / Cancel; `design/accessibility-requirements.md` Motor ("Accidental-activation guard", click-to-select), Test Plan "Mouse-only completion" and "Keyboard-only completion"
**Requirement**: `TR-match-ui-005`, `TR-design-decisions-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009 (`InputRouter extends Node` — mouse / keyboard → intent → command; `Esc` chain; skip-all; focus cycling)
**ADR Decision Summary**: `InputRouter` is the only producer of `command_requested`; any (state, input) pair not listed is ignored; mouse and keyboard are identified by event type.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: `InputEventMouseButton` / `InputEventKey` by type, or `InputEvent.DEVICE_ID_MOUSE` / `DEVICE_ID_KEYBOARD` (4.7), never `event.device == 0`. Test the router headless by calling `intent(name, args)` and feeding synthetic `InputEvent`s with a fake clock for `end_turn_arm_ms`. Gamepad is post-v1 — nothing here may prevent mapping keyboard targeting onto it.

**Control Manifest Rules (this layer)**:
- Required: Mouse / keyboard events identified by type. Every threshold from `config("match_ui")` (`CLICK_DRAG_PX` 8, `end_turn_arm_ms` 300).
- Forbidden: Never `event.device == 0`. Never forward an unlisted (state, input) pair to `submit`.
- Guardrail: n/a.

---

## Acceptance Criteria

*From match-ui L15, L17, O17 and U5 Keyboard:*

- [ ] **L17** GIVEN a playable card, WHEN a press-and-release moving < 8 px lands on it, THEN the view enters `KeyTargeting` with `entered_by = pointer` and nothing is submitted; WHEN a second click lands on a lit slot, THEN exactly one `play_card` is submitted; WHEN `Esc`, RMB or a click on empty table follows instead, THEN nothing is submitted; a click on a different legal source re-selects it.
- [ ] **L15** GIVEN the queue drains at *t* in `PlayerTurn.Main` with no playable card lit (focus on End Turn), WHEN `Space` is pressed at *t* + 100 ms, THEN nothing is forwarded to `submit`; at *t* + 300 ms exactly one `end_turn`; a simulated click on the button at *t* + 0 ms submits `end_turn`; GIVEN instead a playable card is lit (focus on it), WHEN `Space` at *t* + 300 ms, THEN nothing is submitted and `Enter` enters `KeyTargeting` for that card.
- [ ] GIVEN `Idle`, WHEN keys `1`–`9`,`0`, `Tab` / `Shift+Tab`, `Enter`, `A` + number, `H` and `L` are used, THEN each produces the U5 behaviour (pick hand card into keyboard targeting, cycle legal targets with the arrow following, confirm, pick attacker by board index, hero power, toggle feed), and `Space` / `Enter` / left-click outside a control while the queue is busy run skip-all.
- [ ] **O17 (headless)** GIVEN the fixtures `turn1_player`, `targeting_taunt` and `mulligan`, WHEN every interactive action is reached by keyboard only and, separately, by mouse only, THEN for each state the resulting `MatchViewState` and `InputRouter` state are equal across the two paths.

---

## Implementation Notes

- Extend `src/ui/match/input_router.gd` with `KeyTargeting{entered_by: pointer | key}`; share visuals with `Dragging` (Story 008).
- `Esc` priority chain steps 1–2 here (cancel targeting, close feed); steps 3–4 and the Mulligan / Choice / `Ended` rules are Story 019.
- Implement `--pose=select:<instance_id>`; its retained capture pairs with `drag:` in Story 018 (O17 capture half).

---

## Out of Scope

- Story 018: focus ring and `Tab` focus cycling in `Idle` (outside targeting). Story 019: pause menu / Esc steps 3–4.

---

## Files

- `src/ui/match/input_router.gd`
- `src/ui/match/match_debug_loader.gd` (`select:` pose)
- `tests/unit/match_ui/input_router_test.gd`
- `tests/integration/match_ui/keyboard_mouse_parity_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/match_ui/input_router_test.gd` — must exist and pass (L15, L17, shortcut map)
- Also: `tests/integration/match_ui/keyboard_mouse_parity_test.gd` (O17 headless half)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/match-ui/story-008-drag-to-play-attack-and-targeting-arrow.md`, `production/epics/match-ui/story-012-first-playable-windows-match.md`
- Unlocks: `production/epics/match-ui/story-018-focus-cycling-and-inspect-on-focus.md`, `production/epics/match-ui/story-019-pause-menu-concede-and-esc-chain.md`
