# Story 013: Choice overlay — Discover and Choose One

> **Epic**: Match UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/match-ui.md` U9 (Choice overlay), U3 (`discover_offered` + `choice_requested` pairing, `choice_made` / `discover_picked`), U6.6 (boss Choice), States (`ChoiceOpen`), L12, O7 · UX: `design/ux/hud.md` §5 `ChoiceOpen` row; `design/ux/interaction-patterns.md` Pick One of N (Option Row). UI Requirements names `design/ux/choice-overlay.md`, not yet authored.
**Requirement**: `TR-match-ui-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009 (`choice_overlay.tscn` — `OverlayPresenter`: Choice overlay, table dim, "boss discovers…" label; 3 `CardFrame`s or 3 plates; no cancel)
**ADR Decision Summary**: The overlay opens on the projected step for the second of the `discover_offered` / `choice_requested` pair and sends `choose(i)` through the one command path.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Salvage `prototypes/hearthstone-clone-2026-01/scripts/discover_selection.gd` select-then-confirm layout only (shared pattern with Run UI's draft picker — reuse via `CardFrame`, never import). Batch-0 content has no Discover or Choose One card, so this is outside the first-playable slice; it becomes required once Card Effects / content add one (Gatekeeper's `neutral_smite_or_mend`).

**Control Manifest Rules (this layer)**:
- Required: `1` / `2` / `3` move focus to option *n*; all text `tr()` keys.
- Forbidden: A presenter never stores a value the view-state does not have.
- Guardrail: n/a.

---

## Acceptance Criteria

*From match-ui L12, O7, U9:*

- [ ] **L12** GIVEN `events_since(0)` of a match that ended in `Choice` for the player, WHEN projected with `anim_speed = instant`, THEN the view state is `ChoiceOpen` with 3 options and the queue is empty (unit test on view-state + queue).
- [ ] **O7** GIVEN `choice_discover` and `choice_choose_one`, WHEN captured, THEN three options (three 225x315 cards, or three labelled plates) and a Confirm sit in 278,202,723,315 over a dimmed table, and the End Turn button is disabled.
- [ ] GIVEN the overlay, WHEN an option is chosen by click or `1`–`3` and Confirm / `Enter` pressed, THEN exactly one `choose(i)` is submitted and `choice_made` closes the overlay (0.15 s); GIVEN a boss-side Choice, THEN the boss portrait shows the 0.4 s "boss discovers…" label and no options are drawn.

---

## Implementation Notes

- `src/ui/match/overlay_presenter.gd` on `choice_overlay.tscn`; options from `MatchViewState.pending_choice` (player side only — boss side holds none, U3.2).
- Implement `--pose=choice:open` (requires a fixture ending in `Choice`).
- Fixtures `choice_discover.json`, `choice_choose_one.json` need a card with each effect in the loaded data; if none is shipped yet, use a test-only card set loaded through the card-database fixture root (card-effects story 005), never a hand-built view-state.

---

## Out of Scope

- Story 019: `Esc` over the overlay opens the pause menu (O19).

---

## Files

- `src/ui/match/choice_overlay.tscn`, `src/ui/match/overlay_presenter.gd`
- `tests/fixtures/match_ui/choice_discover.json`, `tests/fixtures/match_ui/choice_choose_one.json`
- `tests/unit/match_ui/choice_projection_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- UI: retained screenshots `01-choice_discover.png`, `02-choice_choose_one.png` in `production/qa/evidence/story-013-choice-overlay/` via `tools/capture.sh`
- Also: `tests/unit/match_ui/choice_projection_test.gd` passes (L12)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/match-ui/story-012-first-playable-windows-match.md`; `production/epics/card-effects/story-010-discover-choose-one.md`, `production/epics/match-rules/story-016-choice-phase-and-discover.md`; `production/epics/boss-ai-match-driver/story-010-choice-phase.md`
- UX: `design/ux/choice-overlay.md` not authored (gate condition 11 note as in Story 006)
- Unlocks: `production/epics/match-ui/story-019-pause-menu-concede-and-esc-chain.md`
