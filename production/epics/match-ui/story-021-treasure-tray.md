# Story 021: Treasure tray — chips, 44x44 hit rects, tooltip on hover or focus, hook flare

> **Epic**: Match UI
> **Status**: In Review
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: S
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/match-ui.md` F6 (treasure tray 24,502,136,40; hit zone 22,500,140,44), Interactions (Treasures row: held ids in pick order from `MatchConfig`, `effect_resolved{host_kind: treasure}` flare, `healed{amount: 0}` suppressed), UI Requirements (Treasure tray), O18 (treasure clause) · UX: `design/ux/hud.md` §12 Layout (`treasure_tray`); `design/ux/interaction-patterns.md` Treasure Chip; `design/accessibility-requirements.md` Motor "Minimum target size"
**Requirement**: `TR-match-ui-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009 (presenter draws from view-state; a step per hook flare); ADR-0001
**ADR Decision Summary**: The tray is drawn from `MatchConfig`'s held treasures and flares on the projected hook-hosted `effect_resolved` step.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Hit rect larger than the visual: a 44x44 `Control` wrapping a 40x40 drawn chip (`mouse_filter` on the wrapper).

**Control Manifest Rules (this layer)**:
- Required: geometry from `config("match_ui")`; tooltip on hover **or** focus.
- Forbidden: no hover-only information.
- Guardrail: n/a.

---

## Acceptance Criteria

*From match-ui O18 (tray clause), F6 and hud.md §12:*

- [ ] GIVEN `--fixture=treasure_tray` (two held treasures, one hook firing), WHEN captured, THEN two 40x40 chips sit at x 24 and 72, y 502, with no fourth slot, and one chip carries the flare frame; GIVEN `turn1_player` (no treasure), THEN the tray is absent (no empty box).
- [ ] GIVEN `treasure_tray --pose=focus:treasure:1`, WHEN captured, THEN the chip's tooltip with the treasure `text` is shown without pointer hover and its hit rect (debug outline) measures 44x44 around the 40 px chip; the three chip hit rects never overlap.
- [ ] GIVEN a treasure hook resolving `healed{amount: 0}` on a full-health hero, WHEN projected and played, THEN no number pops and one feed line attributes the treasure.

---

## Implementation Notes

- Tray lives on the player `HeroPresenter` (or a small `TreasureTray` child presenter registered in the partition); keep `MAX_TREASURES_HELD` from treasures config.
- Fixture needs a shipped treasure with a hook (content story 006 / treasures epic); until then, a test-only treasure via the card-database fixture root.

---

## Out of Scope

- `treasures` epic: hook behaviour itself.

---

## Files

- `src/ui/match/treasure_tray.gd`, `src/ui/match/treasure_chip.tscn`
- `tests/fixtures/match_ui/treasure_tray.json`
- `tests/integration/match_ui/treasure_tray_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- UI: retained screenshots `01-treasure_tray.png`, `02-treasure-focus.png` in `production/qa/evidence/story-021-treasure-tray/` via `tools/capture.sh`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/match-ui/story-018-focus-cycling-and-inspect-on-focus.md`, `production/epics/match-ui/story-014-event-feed.md`; `treasures` epic (no stories yet) and `production/epics/content/story-006-mvp-1-treasures.md`
- Unlocks: `production/epics/match-ui/story-020-live-settings-text-scale-contrast-gamma.md`
