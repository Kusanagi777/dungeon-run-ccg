# Story 007: Board rows — minion tokens, summon, death group, gap-close and the offset_transform lunge

> **Epic**: Match UI
> **Status**: In Review
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/match-ui.md` U3 (`minion_summoned`, `summon_failed`, `minion_died` group, stat recolour / badge rows, lunge), F6 rows, O3 · UX: `design/ux/hud.md` §3.2 rows, §12 Layout & Visibility; `design/ux/interaction-patterns.md` Board Token, Floating Number
**Requirement**: `TR-match-ui-001`, `TR-match-ui-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009 (`board_row.tscn` ×2 — `BoardPresenter`: an `HBoxContainer` of `MinionToken` controls; lunge / lift use `offset_transform_*` so the container never resets them mid-tween)
**ADR Decision Summary**: Tokens live in a container; motion inside it uses the 4.7 `Control.offset_transform_*` properties; death groups are one step, then one gap-close; tokens are freed only after `apply_final`.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: `Control.offset_transform_enabled / _position / _scale / _rotation` (4.7, sourced: `modules/ui.md`) — **not observed on this machine**; ADR-0009 Verification item 1 requires the mid-lunge test below. Fallback (ADR-0009 Risks): a non-container row laid out by `BoardPresenter`.

**Control Manifest Rules (this layer)**:
- Required: Lifts and presses on children of a `Container` use `Control.offset_transform_*`. `queue_free` only for presenter children after `apply_final`.
- Forbidden: Never `position` / `scale` for lifts inside a `Container`.
- Guardrail: tween count ≤ steps in flight.

---

## Acceptance Criteria

*From match-ui O3, U3 and ADR-0009 Verification:*

- [ ] **O3** GIVEN `--fixture=midgame_full_board` (7 v 7), WHEN captured, THEN 7 tokens per side sit in the F6 rows (boss 301,176; player 301,334) at x = 301 + 98·i with 8-px gaps, each showing attack and health numerals ≥ 14 px and its keyword badges (Taunt, Divine Shield, Frozen, Stealth, Windfury, Silenced, summoning-sick, glyphs) with their non-colour backups.
- [ ] GIVEN a `scene_runner()` test feeding `minion_summoned` at `board_index` 2 and then four `minion_died` of one cause, WHEN played at `normal`, THEN the token grows in (0.2 s) and the row re-spaces, the four tokens leave in one `death_group` step followed by one `gap_close`, and after each `apply_final` `sync_report()` is empty and no freed token remains.
- [ ] GIVEN an attacking token mid-lunge while the row re-sorts (a summon on the same row in the same frame), WHEN sampled mid-step, THEN its `offset_transform_position` is non-zero and survives the re-layout (`tests/integration/match_ui/test_board_row_lunge.gd`), and a mid-lunge evidence frame is retained (or, if the property misbehaves, the fallback layout is taken and recorded in this story).

---

## Implementation Notes

- `src/ui/match/board_presenter.gd` on `board_row.tscn` (`side` export); `src/ui/match/minion_token.tscn` (90x126, art bible §4 token).
- Damage / heal pops on tokens reuse `number_pop.tscn` (Story 005). `divine_shield_popped` burst and its no-number rule are drawn here; the O12 capture is Story 022.
- Can-attack outline from the view-state's per-token `can_attack` (derived from the last `legal_commands()` only on hover / drag — never rendered numbers).
- Mid-lunge frame: until `--pause-at` lands (Story 015), retain the frame from the integration test via `get_viewport().get_texture().get_image()` saved into the evidence folder — the story's evidence README names how it was taken.

---

## Out of Scope

- Story 008: attack drag input and Taunt / Stealth highlighting. Story 023: hit-stop / shake on contact.

---

## Files

- `src/ui/match/board_row.tscn`, `src/ui/match/board_presenter.gd`, `src/ui/match/minion_token.tscn`, `src/ui/match/minion_token.gd`
- `tests/fixtures/match_ui/midgame_full_board.json`, `tests/fixtures/match_ui/simultaneous_deaths.json`
- `tests/integration/match_ui/board_presenter_test.gd`, `tests/integration/match_ui/test_board_row_lunge.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- UI: retained screenshots `01-midgame_full_board.png` and `02-mid-lunge.png` in `production/qa/evidence/story-007-board-rows-and-tokens/` (the first via `tools/capture.sh`)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/match-ui/story-004-match-view-skeleton-and-fixture-loader.md`; `production/epics/match-rules/story-013-attack-resolution.md`, `production/epics/match-rules/story-014-combat-keywords.md`
- Unlocks: `production/epics/match-ui/story-008-drag-to-play-attack-and-targeting-arrow.md`
