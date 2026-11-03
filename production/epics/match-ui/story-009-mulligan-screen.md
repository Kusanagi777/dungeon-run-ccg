# Story 009: Mulligan screen — keep / replace any subset, Confirm

> **Epic**: Match UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/match-ui.md` U8, U3 (`mulligan_offered`, `mulligan_resolved`), States (`Mulligan`), F6 (Choice / Mulligan row 278,202,723,315), O6 · UX: `design/ux/hud.md` §5 `Mulligan` row; `design/ux/interaction-patterns.md` Pick One of N (Option Row), Button (Primary). UI Requirements names `design/ux/mulligan.md`, not yet authored.
**Requirement**: `TR-match-ui-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009 (`mulligan_screen.tscn` — `MulliganPresenter`, opened by the `mulligan_offered` step); ADR-0001
**ADR Decision Summary**: The mulligan is a presenter opened by a projected step; Confirm sends `mulligan(keep_mask)` through `InputRouter` → `MatchController.submit`.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Cards are `CardFrame` instances at 1.5x (225x315). Salvage `prototypes/hearthstone-clone-2026-01/scripts/mulligan_screen.gd` layout and toggle-and-confirm flow only; its "keep exactly N" rule is **not** kept — DD-M05 / match-rules allow any subset, including replacing none or all (Hearthstone rules).

**Control Manifest Rules (this layer)**:
- Required: Keyboard `1` / `2` / `3` move focus to option *n* on three-option screens. All text is a `tr()` key.
- Forbidden: Never hardcoded values.
- Guardrail: n/a.

---

## Acceptance Criteria

*From match-ui U8, O6 and States:*

- [ ] **O6** GIVEN `--fixture=mulligan`, WHEN captured, THEN three 225x315 cards are centred in 278,202,723,315 over a table dimmed to `table_dark`, each with a keep / replace toggle, and the Confirm button is enabled.
- [ ] GIVEN the mulligan screen, WHEN each of the 8 keep / replace subsets is chosen by click or `1`–`3` and Confirm is pressed, THEN exactly one `mulligan(keep_mask)` with that mask is submitted and accepted (replacing none and replacing all included); the boss is never offered a mulligan.
- [ ] GIVEN `mulligan_resolved`, WHEN projected, THEN the replaced cards flip (0.3 s) into the hand, the view moves `Mulligan → Playback → Idle`, and the screen has no cancel (`Esc` handling is Story 019).

---

## Implementation Notes

- `src/ui/match/mulligan_presenter.gd` on `mulligan_screen.tscn`; the 3 starting cards come from `MatchViewState.pending_mulligan` (`starting_hand_player` from config).
- Fixture `mulligan.json`: `MatchConfig` only, empty command list (the match rests at `mulligan_offered`).
- Focus ring visuals are Story 018; this story wires `1`–`3` toggles and Enter/Confirm.

---

## Out of Scope

- Story 019: `Esc` over the mulligan opens the pause menu (O19).

---

## Files

- `src/ui/match/mulligan_screen.tscn`, `src/ui/match/mulligan_presenter.gd`
- `tests/fixtures/match_ui/mulligan.json`
- `tests/integration/match_ui/mulligan_screen_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- UI: retained screenshot `01-mulligan.png` in `production/qa/evidence/story-009-mulligan-screen/` via `tools/capture.sh`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/match-ui/story-004-match-view-skeleton-and-fixture-loader.md`, `production/epics/match-ui/story-006-hand-fan-and-hover-preview.md` (`CardFrame`); `production/epics/match-rules/story-004-command-channel-and-mulligan.md`
- UX: `design/ux/mulligan.md` not authored (gate condition 11 note as in Story 006)
- Unlocks: `production/epics/match-ui/story-012-first-playable-windows-match.md`
