# Story 020: Live settings — text_scale variants, high-contrast states, gamma and letterboxing

> **Epic**: Match UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: L
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/match-ui.md` Interactions (Meta Progression row: `anim_speed`, `high_contrast_states`, `reduce_motion`, `action_delay_ms`, `text_scale`, `gamma`), U11 (`*_ts150` settings variants), O16 · UX: `design/ux/hud.md` §10.1 Colorblind Modes, §10.2 Text Scaling, §10.5, §12 Accessibility rows; `design/accessibility-requirements.md` (Standard tier: text scale 100/125/150 %, selectable high-contrast state set, gamma DD-X10), Test Plan rows "Text contrast ratios", "Colour-as-only-indicator", "Text scale"; `design/art/art-bible.md` §4 (tokens, high-contrast swaps `state_danger` → `#FF8C42`, `state_buff` → `#4FA3FF`)
**Requirement**: `TR-design-decisions-003` (also `TR-game-concept-001`)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009 (`gamma` is one `CanvasModulate` under `match_view.tscn`; `text_scale` is one of three discrete theme-override sets with fixture-tested layouts); ADR-0011 (settings via `SettingsBus` / `MetaApi`); ADR-0010 (renderer-neutral theme resources and fonts; no post-processing)
**ADR Decision Summary**: Every read setting is applied live from `settings_changed`; gamma never touches colour tokens; text scale is discrete (1.0 / 1.25 / 1.5), never continuous.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: `CanvasModulate` (4.0, LOW). Theme overrides via `theme_type_variation` / font-size overrides. `canvas_items` stretch with `keep` aspect (DD-T05; 4.7 changed project stretch defaults — sourced in `breaking-changes.md`, verify the project setting is explicit).

**Control Manifest Rules (this layer)**:
- Required: `gamma` is one `CanvasModulate`; `text_scale` one of three theme-override sets each with a retained `_ts150` fixture screenshot; settings read from `SettingsBus` and applied live.
- Forbidden: Never a continuous `text_scale`; gamma is never a colour-token change; no `WorldEnvironment` / HDR / tonemapping.
- Guardrail: n/a.

---

## Acceptance Criteria

*From match-ui O16, U11 settings variants and hud.md §12 Accessibility:*

- [ ] GIVEN the seven `_ts150` fixtures (`turn1_player`, `midgame_full_board`, `hand_10`, `boss_intent_full`, `boss_turn_playback`, `treasure_tray`, `fatigue_and_burn` with profile `text_scale = 1.5`), WHEN captured, THEN no text clips, no element overlaps another, the intent banner has grown left, the boss strip holds only the hand count and the boss mana pill sits at 1196,152,56,24 inside the portrait panel.
- [ ] GIVEN `high_contrast_states` on and off, WHEN `midgame_full_board`, `divine_shield_hit` and `boss_intent_full` are captured and run through Coblis (protanopia, deuteranopia, tritanopia), THEN every state in hud.md §10.1 stays identifiable by its glyph / word / shape, and an automated check of the theme's text / background token pairs reports ≥ 4.5:1 (≥ 3:1 for ≥ 18 px bold).
- [ ] GIVEN `gamma` 0.8 and 1.4, WHEN `settings_changed` fires, THEN only the one `CanvasModulate` changes (colour tokens untouched) on the next frame; GIVEN any other read setting changed in the pause menu, THEN the HUD reflects it on the next frame.
- [ ] **O16** GIVEN any fixture with the window at 1920x1080 and at 1024x768, WHEN captured, THEN the frame is uniformly scaled / letterboxed with the F6 grid intact and no element clipped.

---

## Implementation Notes

- `src/ui/match/match_view.gd` subscribes to `SettingsBus.settings_changed`; theme sets in `src/ui/common/theme/` (`base.tres`, `ts125`, `ts150`, high-contrast state overrides).
- `_ts150` fixtures reuse the base command list with a `profile.settings` block (no new launch argument).
- O16 captures: `capture.sh` records the project viewport size; capture the letterbox with the window size set through `--resolution` and note in the evidence README how the window size was applied (Movie Maker frames are viewport-sized — if letterboxing is invisible in the frame, take an OS-level capture under xvfb per `run-and-observe.md` "Any engine — OS capture fallback").
- Coblis runs are manual; record them in `production/qa/evidence/story-020-live-settings-text-scale-contrast-gamma/coblis.md`.

---

## Out of Scope

- Story 023: `reduce_motion` behaviour. Alpha deferred list: input remapping (TR-accessibility-requirements-001).

---

## Files

- `src/ui/match/match_view.gd`
- `src/ui/common/theme/*.tres`
- `tests/fixtures/match_ui/*_ts150.json` (7)
- `tests/integration/match_ui/live_settings_test.gd`, `tests/integration/match_ui/theme_contrast_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- UI: retained screenshots of each `_ts150` fixture, the high-contrast pairs, and the two letterbox resolutions in `production/qa/evidence/story-020-live-settings-text-scale-contrast-gamma/` via `tools/capture.sh`, plus `coblis.md`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/match-ui/story-019-pause-menu-concede-and-esc-chain.md`, `production/epics/match-ui/story-015-boss-intent-banner-and-boss-turn-view.md`, `production/epics/match-ui/story-021-treasure-tray.md` (for `treasure_tray_ts150`); `production/epics/boot-composition-root/story-001-settings-bus.md`
- Unlocks: None
