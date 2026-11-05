# Story 022: Debug loader completion — argument parsing, --anim-speed, --ai-debug overlay and the full fixture sweep

> **Epic**: Match UI
> **Status**: In Review
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/match-ui.md` U11 (argument table, required fixtures, settings variants), U3.4a (`--ai-debug`), UI Requirements (AI debug overlay), O12 · UX: `design/ux/hud.md` §5 `--ai-debug` row
**Requirement**: `TR-match-ui-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009 (Decision §4 — the same fixture JSON drives evidence and `tests/integration/match_ui/`); ADR-0010 (capture launch line)
**ADR Decision Summary**: Every screen is reachable unattended from a launch argument; fixtures run the real engine; the loader exists only in debug builds.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: `OS.get_cmdline_user_args()` returns only the args after `--` (4.x, LOW). Captures never `--headless`.

**Control Manifest Rules (this layer)**:
- Required: `MatchDebugLoader` (debug builds only) reads `--fixture`, `--pose`, `--pause-at`, `--anim-speed`, `--ai-debug`.
- Forbidden: Fixtures never contain hand-built view-states.
- Guardrail: n/a.

---

## Acceptance Criteria

*From match-ui U11, O12 and ADR-0009 Verification ("Fixtures run the real engine"):*

- [ ] GIVEN `MatchDebugLoader.from_args`, WHEN given every U11 argument form (and an unknown one), THEN it returns `{fixture, pose, pause_at, anim_speed, ai_debug}` exactly, rejects an unknown pose with a logged warning and no crash, and `--anim-speed=instant|fast|normal` overrides the setting for that launch only.
- [ ] GIVEN `tests/integration/match_ui/test_fixtures_load.gd`, WHEN it loads every required U11 fixture and every `_ts150` variant, THEN each runs through the real `MatchDriver` with zero rejected commands, ends in the state its name claims, and a static check finds no view-state fields in any fixture JSON.
- [ ] GIVEN `boss_turn_playback --ai-debug` in a debug build, WHEN captured, THEN the AI debug overlay occupies 0,40,300,290 and `diagnostic: true` events render as `feed.diag.<type>` lines in `text_muted`; without the flag none reach the feed.
- [ ] **O12** GIVEN `divine_shield_hit --pause-at=<seq>` on the shield-pop step, WHEN captured, THEN a ring burst is visible and no damage number is shown on that target; and every required fixture has one retained sweep screenshot.

---

## Implementation Notes

- Add `tools/capture_match_fixtures.sh` (or a loop documented in the evidence README) calling `tools/capture.sh` once per fixture with `CAPTURE_LABEL=<nn>-<fixture>`.
- Remaining poses not added by earlier stories (`end:<reason>` if any fixture cannot reach one) land here.
- Fixtures `divine_shield_hit.json` and any required fixture still missing.

---

## Out of Scope

- Story 012: release-export exclusion.

---

## Files

- `src/ui/match/match_debug_loader.gd`, `src/ui/match/ai_debug_overlay.tscn`
- `tests/fixtures/match_ui/divine_shield_hit.json` (+ any missing required fixture)
- `tests/unit/match_ui/match_debug_loader_args_test.gd`
- `tests/integration/match_ui/test_fixtures_load.gd`
- `tools/capture_match_fixtures.sh`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/match_ui/test_fixtures_load.gd` passes
- Screenshot sweep (one per fixture) and the O12 / `--ai-debug` captures retained in `production/qa/evidence/story-022-debug-loader-poses-and-fixture-sweep/`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/match-ui/story-014-event-feed.md`, `production/epics/match-ui/story-015-boss-intent-banner-and-boss-turn-view.md`; `production/epics/match-ui/story-004-match-view-skeleton-and-fixture-loader.md`
- Unlocks: `production/epics/match-ui/story-024-input-latency-and-feel-validation.md`
