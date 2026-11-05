# Story 008: Drag to play, drag to attack and the targeting arrow

> **Epic**: Match UI
> **Status**: In Review
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: L
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/match-ui.md` U5 (Drag to play, Attack, Hero power targeted), U7 (targeting arrow), States (`Dragging`), Input Responsiveness (pickup, drag, release rows), O4, O5 · UX: `design/ux/hud.md` §5 `Dragging / KeyTargeting` row; `design/ux/interaction-patterns.md` Card Drag-to-Play, Targeting Arrow. UI Requirements names `design/ux/targeting.md`, not yet authored.
**Requirement**: `TR-match-ui-005`, `TR-match-ui-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009 (`targeting_arrow.tscn` — `TargetingArrow extends Presenter`, `_draw` each frame while active, line width from data; `InputRouter` mouse → intent → `command_requested`); ADR-0001 (only `submit`)
**ADR Decision Summary**: `InputRouter` turns mouse input into intents and commands; legality is read from `legal_commands()` on pickup only; the arrow is a quadratic Bezier redrawn per frame; the engine is never called on cancel.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Identify input by type (`InputEventMouseButton`, `InputEventMouseMotion`), never `event.device == 0` (4.7). `CanvasItem` lines have no antialiasing feather in 4.7 — arrow width comes from config, not tuned by eye. Salvage `prototypes/hearthstone-clone-2026-01/scripts/targeting_arrow.gd` (single quadratic curve, 20 segments, head polygon; keep the math) — drop its `Node2D` base and exported colour; it becomes a `Presenter` with `state_target` and `ARROW_LIFT_PX` from data. `card_ui.gd` drag offset logic may be reused; its direct state reads may not.

**Control Manifest Rules (this layer)**:
- Required: `InputRouter extends Node` maps mouse / keyboard → intent → `command_requested`; `MatchView` forwards to `MatchController.submit`.
- Forbidden: Never call `.submit(` outside the controller / driver / view input path. Never let presenters poll `MatchQuery` to render numbers.
- Guardrail: `MatchQuery` / `legal_commands()` ≤ 2 ms, on pickup / hover only.

---

## Acceptance Criteria

*From match-ui U5, U7, Input Responsiveness, O4, O5:*

- [ ] GIVEN `Idle` and a hand card with `playable = true`, WHEN pressed and moved > `CLICK_DRAG_PX` (8), THEN it lifts within one frame (16 ms, no tween-in). A minion or an untargeted spell / weapon then follows the cursor exactly each frame, with the legal summon gaps (minion) or the dashed cast zone 301, 176, 678, 284 (untargeted spell / weapon) shown from `legal_commands()`. A **targeted** spell / weapon instead **parks** at 1.0x upright, centred on its F1 x with its top at y 438, and the arrow runs from it to the cursor with every legal target outlined `state_target` (match-ui U5 "the arrow appears from the card"; `design/ux/targeting.md` §5.2 Parked source, §6 Phase T). Release on a legal slot / inside the cast zone / on a legal target submits exactly one `play_card`, and the first visual step starts ≤ 50 ms after release; a release over another legal source never re-selects (`targeting.md` §7.4 drag-release table). Release elsewhere, RMB or `Esc` tweens the card back (0.15 s) with no command and no event. *(amended 2026-11-04 to match design/ux/targeting.md, ux-review round 1. **Not amended**: a minion with a targeted Battlecry, which `targeting.md` plays as position then target (Phase P → T, through `KeyTargeting`). That sequence is not yet in match-ui U5 / States — review R1 / A2, routed to the Match UI GDD owner and the producer. Until it is recorded, this AC does not cover that case.)*
- [ ] GIVEN a friendly token (or the player hero with a weapon) that `legal_commands()` lets attack, WHEN dragged, THEN the arrow starts from it, only legal defenders outline (only Taunts when a Taunt exists; Stealth enemies never outlined nor droppable), and release on a legal defender submits exactly one `attack`; a targeted hero power starts the same arrow and submits `use_hero_power` with the target.
- [ ] **O4** GIVEN `targeting_taunt --pose=drag:<attacker>`, WHEN captured, THEN the Bezier arrow (quadratic, control point `ARROW_LIFT_PX` above the midpoint, triangular head) runs from the attacker to screen centre, only Taunt minions carry the `state_target` outline, and the boss hero is not outlined.
- [ ] **O5** GIVEN `targeting_stealth --pose=drag:<attacker>`, WHEN captured, THEN the Stealth minion shows its badge and no outline.

---

## Implementation Notes

- `src/ui/match/input_router.gd`: states `Idle`, `Dragging`; intents `drag_start`, `drag_move`, `drag_release`, `cancel`. Any (state, input) pair not listed in match-ui States is ignored, never forwarded.
- `src/ui/match/targeting_arrow.gd` — `start_from`, `update_end`, `_draw`; hovered legal target gains a 3 px ring (shape is the primary cue, art bible colourblind rule).
- Implement `--pose=drag:<instance_id>` in `MatchDebugLoader.apply_pose` (card lifted / attacker armed, arrow to screen centre, legal targets lit).
- Fixtures `targeting_taunt.json`, `targeting_stealth.json` run the real engine to the board state; no hand-built view-state.
- Click-to-select and keyboard targeting share the same visuals — Story 017 adds those entry paths.

---

## Out of Scope

- Story 016: rejection shake / tooltip. Story 017: click-to-select, keyboard targeting. Story 024: the measured latency table.

---

## Files

- `src/ui/match/input_router.gd`
- `src/ui/match/targeting_arrow.tscn`, `src/ui/match/targeting_arrow.gd`
- `src/ui/match/hand_presenter.gd`, `src/ui/match/board_presenter.gd` (drop-zone / outline display)
- `src/ui/match/match_debug_loader.gd` (`drag:` pose)
- `tests/fixtures/match_ui/targeting_taunt.json`, `tests/fixtures/match_ui/targeting_stealth.json`
- `tests/integration/match_ui/drag_to_play_and_attack_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- UI: retained screenshots `01-targeting_taunt-drag.png`, `02-targeting_stealth-drag.png` in `production/qa/evidence/story-008-drag-to-play-attack-and-targeting-arrow/` via `tools/capture.sh`
- Also: `tests/integration/match_ui/drag_to_play_and_attack_test.gd` passes

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/match-ui/story-005-hero-panels-mana-and-end-turn.md`, `production/epics/match-ui/story-006-hand-fan-and-hover-preview.md`, `production/epics/match-ui/story-007-board-rows-and-tokens.md`; `production/epics/match-rules/story-012-attack-legality.md`; `production/epics/card-effects/story-004-validator-step-bound-targeting.md`
- UX: `design/ux/targeting.md` not authored (gate condition 11 note as in Story 006)
- Unlocks: `production/epics/match-ui/story-012-first-playable-windows-match.md`, `production/epics/match-ui/story-016-rejection-feedback.md`, `production/epics/match-ui/story-017-click-to-select-and-keyboard-targeting.md`
