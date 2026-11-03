# Story 014: Event feed — ticker, drawer, command-root grouping and collapse

> **Epic**: Match UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/match-ui.md` U10, F5, U3.4a / silent set, L18, O11, O14 · UX: `design/ux/hud.md` §5 Feed drawer row, §12 (`feed:open`, `fatigue_and_burn`); `design/ux/interaction-patterns.md` Event Feed. UI Requirements names `design/ux/event-feed.md`, not yet authored.
**Requirement**: `TR-match-ui-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009 (`event_feed.tscn` — `FeedPresenter`, `RichTextLabel`, 3-line ticker and full panel); ADR-0001 (all text `tr()` keys); ADR-0003 (diagnostic class, rule 12a)
**ADR Decision Summary**: Feed lines are view-state (`feed_lines[]` recorded by the projection); `FeedPresenter` renders them grouped under their command root, collapses long groups, and keeps the newest `FEED_MAX_LINES`.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: If images are ever inlined, `RichTextLabel.add_image()` / `update_image()` take `width_unit` / `height_unit` (4.7 rename, sourced) — not `*_in_percent`.

**Control Manifest Rules (this layer)**:
- Required: `FeedPresenter` uses `RichTextLabel`. All user-facing text is a `tr()` key; entity names through `card_text(card_id).name_key`.
- Forbidden: Boss hand contents never appear until played.
- Guardrail: feed buffer `FEED_MAX_LINES` 200.

---

## Acceptance Criteria

*From match-ui L18, F5, O11, O14:*

- [ ] **L18** GIVEN `ai_decision`, `ai_plan_aborted`, `ai_fault` (`diagnostic: true`) and the silent-set events `turn_reset`, `card_to_graveyard`, WHEN projected without `--ai-debug`, THEN no step, no feed line and no view-state change (debug buffer excepted); GIVEN `counter_changed{source_id, key, value}`, THEN `counters[source_id][key] == value`, exactly one `feed.counter_changed` line and no step.
- [ ] GIVEN a command group with 20 child lines, WHEN F5 runs, THEN it renders 7 lines (6 + "+N more", expandable); the panel retains only the newest `FEED_MAX_LINES` (200) and the ticker shows the newest `FEED_TICKER_LINES` (3), all read from config.
- [ ] **O14** GIVEN `simultaneous_deaths --pose=feed:open`, WHEN captured, THEN the drawer occupies 0,40,300,290, the player portrait at 24,334 is fully visible, the deaths are indented under their command root and a chain longer than 6 shows "+N more".
- [ ] **O11** GIVEN `fatigue_and_burn`, WHEN captured, THEN the player deck pile reads "Fatigue: next N" and the feed ticker names the burned card (name resolved through `card_text`, never a payload string).

---

## Implementation Notes

- `src/ui/match/feed_presenter.gd` on `event_feed.tscn`; `L` key and the top-bar button toggle the drawer; `Esc` / RMB close it first (chain step 2 — Story 019 owns the whole chain).
- Implement `--pose=feed:open`. Fixture `fatigue_and_burn.json` scripts a deck run-out and a full-hand burn.
- Unit-test F5 as a pure function in `tests/unit/match_ui/feed_lines_test.gd` (with L18).

---

## Out of Scope

- Story 022: `--ai-debug` rendering of `feed.diag.<type>` lines and the AI debug overlay.

---

## Files

- `src/ui/match/event_feed.tscn`, `src/ui/match/feed_presenter.gd`, `src/ui/match/feed_lines.gd`
- `tests/fixtures/match_ui/fatigue_and_burn.json`
- `tests/unit/match_ui/feed_lines_test.gd`
- `assets/data/` localisation table rows for `feed.*` keys (en)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- UI: retained screenshots `01-simultaneous_deaths-feed-open.png`, `02-fatigue_and_burn.png` in `production/qa/evidence/story-014-event-feed/` via `tools/capture.sh`
- Also: `tests/unit/match_ui/feed_lines_test.gd` passes (L18, F5)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/match-ui/story-012-first-playable-windows-match.md`; `production/epics/match-rules/story-006-primitives-draw-burn-fatigue.md`; `production/epics/card-effects/story-009-deathrattle-snapshot-counters.md` (`counter_changed`)
- UX: `design/ux/event-feed.md` not authored (gate condition 11 note as in Story 006)
- Unlocks: `production/epics/match-ui/story-016-rejection-feedback.md`, `production/epics/match-ui/story-022-debug-loader-poses-and-fixture-sweep.md`
