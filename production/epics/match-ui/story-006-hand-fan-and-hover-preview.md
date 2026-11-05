# Story 006: Hand fan and hover preview — F1, F2 and the shared CardFrame

> **Epic**: Match UI
> **Status**: In Review
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/match-ui.md` F1 (hand fan layout), F2 (hover preview), U3 (`card_drawn`, `card_played`), Input Responsiveness (hover row) · UX: `design/ux/hud.md` §3.2 hand zone, §12 (hand_10 rows); `design/ux/interaction-patterns.md` Card (Hand), Card Inspect. UI Requirements names `design/ux/hand.md`, which does not exist yet (see Dependencies).
**Requirement**: `TR-match-ui-005`, `TR-design-decisions-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009 (`hand_fan.tscn` — `HandPresenter`, custom layout, not a Container, because F1 rotates and overlaps; shared `src/ui/common/card_frame.tscn`)
**ADR Decision Summary**: `HandPresenter` lays out the fan itself from F1 and owns pickup / hover visuals; hover lift is a tween of `HOVER_IN_S`, pickup is immediate; `CardFrame` is shared with Run UI (ADR-0011).
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: The hand is a custom layout, so `position` / `rotation` / `scale` on its cards are safe (the `offset_transform_*` rule applies to Container children only). Hover never moves keyboard focus (4.6 dual focus). Salvage `prototypes/hearthstone-clone-2026-01/scripts/card_ui.gd` hover-in-place (neighbours do not move) — copy and rework; drop its `_on_mana_changed` Node-side state read and `top_level` juggling; affordability comes from the view-state's `hand[].playable`.

**Control Manifest Rules (this layer)**:
- Required: Every geometry value from `config("match_ui")` (read once in `MatchView._ready`). Focus ring from keyboard focus only; hover is a lift and never moves focus.
- Forbidden: Never hardcoded values; the UI never parses JSON itself.
- Guardrail: hover → 1.5x preview complete ≤ 100 ms.

---

## Acceptance Criteria

*From match-ui Acceptance Criteria L10, L14, O1, O2:*

- [ ] **L10 / L14** GIVEN n = 10 and n = 3, WHEN the pure F1 function runs with the shipped config, THEN spacings are 72.2 px and 158 px, end-card rotations ±15° and ±4°, centre card y 672.3 (n = 10) and 672 (n = 3), and no card centre lies outside x 315–965; GIVEN an injected config with `HAND_W = 700`, THEN the output changes accordingly (no constant is hardcoded).
- [ ] **O1** GIVEN `--fixture=hand_10`, WHEN captured, THEN ten cards are visible with every cost stamp and attack stamp unobscured, the centre card highest, no card pixel left of x 188 or right of x 1092, and none over the mana bar zone (x ≥ 1060, y ≥ 652) or the treasure-chip zone (x ≤ 162).
- [ ] **O2** GIVEN `hand_10 --pose=hover:<id>` (card 9), WHEN captured, THEN the hovered card is 225x315, upright, bottom on the baseline y 696, clamped inside the viewport, on top of its neighbours, the neighbours have not moved, and the mana bar is fully visible.
- [ ] GIVEN a mouse-over on a hand card, WHEN timed by a `scene_runner()` test, THEN the 1.5x preview is complete within 100 ms (`HOVER_IN_S` 0.1 from config) and mouse-out restores it with no neighbour movement.

---

## Implementation Notes

- `src/ui/match/hand_layout.gd` — static pure F1 / F2 functions (unit-testable without a scene); `src/ui/match/hand_presenter.gd` on `hand_fan.tscn` calls them.
- `src/ui/common/card_frame.gd` / `.tscn` — 150x210 slot layout per art bible §4 "Card frame slot layout" (cost stamp x 3–37, attack / health corner stamps, name, text keys, keyword badges); placeholder art per art bible §7. The cost stamp's number comes from the projection: the `MatchViewState` hand card's `effective_cost`, which `auras_recomputed` replaces, and the printed cost until an entry has set it (2026-11-04, DD-X26). Text through `tr()` and `card_text(card_id)` name / text keys.
- Implement the `hover:<id>` pose in `MatchDebugLoader.apply_pose` (first pose; others arrive with their stories).
- Draw / play travel steps (`draw` 0.2, `play_card` 0.25) are tweens toward the F1 slot / board slot; `apply_final` snaps.
- Hand dims to 60 % during `BossTurn` — Story 015.

---

## Out of Scope

- Story 008: pickup and drag. Story 018: focus-opened preview. Story 020: `text_scale` reading panel.

---

## Files

- `src/ui/match/hand_layout.gd`, `src/ui/match/hand_presenter.gd`, `src/ui/match/hand_fan.tscn`
- `src/ui/common/card_frame.gd`, `src/ui/common/card_frame.tscn`
- `src/ui/match/match_debug_loader.gd` (`hover:` pose)
- `tests/fixtures/match_ui/hand_10.json`
- `tests/unit/match_ui/hand_fan_layout_test.gd`
- `tests/integration/match_ui/hand_hover_latency_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- UI: retained screenshots `01-hand_10.png`, `02-hand_10-hover.png` in `production/qa/evidence/story-006-hand-fan-and-hover-preview/` via `tools/capture.sh`
- Also: `tests/unit/match_ui/hand_fan_layout_test.gd` passes (L10 / L14)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/match-ui/story-004-match-view-skeleton-and-fixture-loader.md`
- UX: `design/ux/hand.md` is named by match-ui UI Requirements but not authored; gate condition 11 requires each story's UX doc APPROVED before `/story-readiness` — this story cites `hud.md` (APPROVED round 3) and the interaction-patterns Card (Hand) / Card Inspect patterns; run `/ux-design hand` if the readiness check demands the per-screen spec.
- Unlocks: `production/epics/match-ui/story-008-drag-to-play-attack-and-targeting-arrow.md`, `production/epics/match-ui/story-018-focus-cycling-and-inspect-on-focus.md`
