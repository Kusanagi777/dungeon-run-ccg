# Story 019: Pause menu, concede and the Esc chain

> **Epic**: Match UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/match-ui.md` U9 (Concede, Settings quick-access), U5 (`Esc` priority chain steps 3–4; no cancel on Mulligan / Choice / end banner), States (`Menu`), O15, O19 · UX: `design/ux/hud.md` §5 `Menu` row, §12 (`menu:concede`); `design/ux/interaction-patterns.md` Modal Dialog, Confirmation Dialog, Button (Destructive), Escape / Cancel, Overlay Open / Close. UI Requirements names `design/ux/pause-menu.md`, not yet authored.
**Requirement**: `TR-match-ui-001`, `TR-systems-index-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009 (`pause_menu.tscn` — `PauseMenu extends Control`, shared with Run UI as the settings panel); ADR-0011 (settings written only through `MetaApi.set_setting`, read through `SettingsBus`; Run UI reuses, never imports match presenters); ADR-0008 (concede while a planner task is live → `ENGINE_BUSY / concede_queued`)
**ADR Decision Summary**: The pause menu is a shared scene; concede goes through `submit`; settings changes go to `MetaApi.set_setting` and come back as `settings_changed`; underlying playback keeps running while the menu is open.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Base input is cut while the menu is up via the recursive Control disable (4.5, ADR-0011). Focus → Resume on open; returns to the trigger on close.

**Control Manifest Rules (this layer)**:
- Required: Settings written only through `MetaApi.set_setting`; `Esc` → back / close / cancel.
- Forbidden: Run UI never passes settings to Match UI. The pause menu is unreachable in `Ended`.
- Guardrail: n/a.

---

## Acceptance Criteria

*From match-ui O15, O19, U9 and hud.md §12:*

- [ ] **O15** GIVEN `--pose=menu:settings`, WHEN captured, THEN master / SFX volume sliders, the `anim_speed` selector (Normal / Fast / Instant) and the `reduce_motion` toggle are visible in 440,160,400,400 and the match behind is still rendered (dimmed to `table_dark`, ticker lit).
- [ ] GIVEN `--pose=menu:concede`, WHEN captured, THEN the confirm dialog is shown with Cancel holding the focus ring; WHEN confirmed in the player's turn, THEN `concede` is submitted and the match ends `concede`; WHEN confirmed during the boss turn with a planner task live, THEN the result is `ENGINE_BUSY / concede_queued` and the match still ends `concede` after the task (no boss command in the log).
- [ ] **O19** GIVEN `choice_discover` (and `mulligan`), WHEN `Esc` is pressed, THEN the overlay is still open with its options unchanged and the pause menu is open above it; `Esc` again closes the pause menu and returns focus.
- [ ] GIVEN the menu open during `Playback`, WHEN time passes, THEN playback keeps running underneath; GIVEN a settings change, THEN it is written via `MetaApi.set_setting` (MetaStub, session-local) and applied from `settings_changed` on the next frame.

---

## Implementation Notes

- `src/ui/match/pause_menu.tscn` / `.gd` — shared; place reusable parts so Run UI instances the scene (ADR-0011) without referencing `src/ui/match/` presenters.
- Esc chain: (1) cancel targeting (Story 017), (2) close feed (Story 017/014), (3) close the top-most overlay with a cancel, (4) open the pause menu; Mulligan / Choice have no cancel; `Ended` does nothing (Story 011).
- Implement `--pose=menu:concede`, `--pose=menu:settings`.

---

## Out of Scope

- Story 020: applying `text_scale`, `high_contrast_states`, `gamma` and the other read settings.

---

## Files

- `src/ui/match/pause_menu.tscn`, `src/ui/match/pause_menu.gd`
- `src/ui/common/confirm_dialog.tscn`
- `src/ui/match/input_router.gd` (Esc steps 3–4)
- `src/ui/match/match_debug_loader.gd` (`menu:` poses)
- `tests/integration/match_ui/pause_menu_concede_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- UI: retained screenshots `01-menu-settings.png`, `02-menu-concede.png`, `03-choice-esc.png`, `04-mulligan-esc.png` in `production/qa/evidence/story-019-pause-menu-concede-and-esc-chain/` via `tools/capture.sh`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/match-ui/story-013-choice-overlay.md`, `production/epics/match-ui/story-017-click-to-select-and-keyboard-targeting.md`, `production/epics/match-ui/story-018-focus-cycling-and-inspect-on-focus.md`; `production/epics/boot-composition-root/story-003-meta-stub.md`; `production/epics/boss-ai-match-driver/story-013-match-driver-construction-and-command-gate.md` (concede slot)
- UX: `design/ux/pause-menu.md` not authored (gate condition 11 note as in Story 006)
- Unlocks: `production/epics/match-ui/story-020-live-settings-text-scale-contrast-gamma.md`; `run-ui` epic (shared settings panel)
