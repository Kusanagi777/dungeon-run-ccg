# Review log — design/gdd/match-ui.md

## Review — 2026-11-03 — Verdict: NEEDS REVISION
Review mode: lean · Workflow: standard
Scope signal: L
Specialists: none (lean — main review only; no Agent calls)
Blocking items: 6 | Recommended: 6
Summary: The architecture (display-only projection of the event log, skippable queue, fixture-driven screenshots) is sound and honours ui-code.md rules 1, 2, 4–6 and art bible §4 geometry and tokens. The hand-fan formula contradicted its own acceptance criterion (outer cards' attack stamps off the 720-px viewport), the match-end hand-off named a partner (Run Structure) that never names this system, the Designed Treasures GDD's match-screen tray was missing from the grid and fixtures, and two C15 events would have rendered as "unknown event" feed lines. All six blocking items were resolved in place without a new owner decision (option A); the document is now In Review pending re-review. Cross-GDD items (`intent_banner_s` 1.2 vs 0.3 in boss-ai, run-ui's `anim_speed` labels and action-delay slider, `telegraph_mode` ownership, ui-code.md gamepad / text-scale mandates vs the v1 deferral) are recorded in Open Questions and need Boss AI, Run UI or the owner.
Prior verdict resolved: First review
Findings:
- [BLOCKING] Formulas F1 / F6 / AC O1: bottom-centre pivot at `HAND_BASE_Y` 716 plus a 24-px downward arc put outer cards at y 740 with their attack stamps off-screen; O1 unsatisfiable — fixed: arc lifts the centre, `HAND_BASE_Y` 696, hand zone 240, 462, 800, 258, F2 preview top y 381
- [BLOCKING] Detailed Design U9 / Interactions / Dependencies: hand-off declared "mutual, Hard" with Run Structure, whose GDD never names Match UI; run-ui.md owns the scene swap and the `match_view_finished` contract — fixed: Run UI is the sibling partner, Run Structure indirect via `MatchConfig`
- [BLOCKING] Formulas F6 / UI Requirements / U11: treasures.md (Designed, MVP) places a tray on the match screen; no zone, inventory row or fixture existed and the GDD called Treasures "undesigned" — fixed: tray zone 24, 502, 200, 40, inventory row, `treasure_tray` fixture, `healed{amount: 0}` suppressed
- [BLOCKING] Detailed Design U3: C15's `turn_reset` and `card_to_graveyard` were in neither the table nor an exemption, so rule 4 would emit `feed.unknown` lines for them — fixed: declared silent set (`silent_types[]`)
- [BLOCKING] Game Feel / Tuning Knobs: screen shake "respects a motion-reduction setting" that no section defined (ui-code.md rule 4) — fixed: `reduce_motion` setting drops shake, hit-stop and lethal slow-down; exposed in the pause menu and persisted via Meta
- [BLOCKING] Formulas intro / Tuning Knobs / Open Questions / AC L14: `match_ui.json` said to need a DD-T01 row and a loader; DD-T01 already lists it and card-database CR-1 serves it via `config("match_ui")` — fixed; U12 cross-reference F7 → F6 corrected
- [RECOMMENDED] Open Questions (cross-GDD, Boss AI): boss-ai.md gives `intent_banner_s` 1.2 s in its data sketch and 300 ms in Impact Moments; F4/U6/L8 assume 0.3 s
- [RECOMMENDED] Open Questions (cross-GDD, Run UI): run-ui.md labels `anim_speed` `instant|fast|normal` and adds an "action delay" slider this GDD does not own; Meta M9 stores this GDD's enum
- [RECOMMENDED] Open Questions (owner): `telegraph_mode` settings key has no semantic owner; ui-code.md rules 3 and 7 (gamepad, scalable text, colourblind modes) vs the v1 deferral need an explicit decision
- [RECOMMENDED] Detailed Design U5: `Space`/`Enter` means End Turn when enabled and skip-all otherwise — a skip pressed as the boss turn drains becomes an accidental End Turn; add an `END_TURN_KEY_GUARD_MS` (~300 ms) after the queue drains
- [RECOMMENDED] Acceptance Criteria L13 / O17: L13 names no reference machine for its millisecond budgets; O17's "matches its mouse-reached screenshot" should be defined as view-state equality plus a screenshot pair
- [RECOMMENDED] Registry: `referenced_by` lists match-ui.md on `transition_duration`, `action_score`, `spell_damage_requested`, `discover_pool`, `player_starting_health` and `ai_planner_target_ms`, none of which this GDD cites; systems-index Depends On lacks Run UI (mutual) and Meta Progression (soft)
Reviewed-Content-Hash: design/gdd/match-ui.md 1ff29fdb08f7432bf5e6f34ac2c207a8e8d8e654
Reviewed-Content-Hash: design/registry/entities.yaml 3364fe83ab25b4e4e9cc1c97bce415b250230dba
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/match-rules.md 4c45bb5b36e1b50b3b286a2f10ea13cd0b703eae
Reviewed-Content-Hash: design/gdd/rng-event-log.md cb06cb1680292fc0af6b80262894d273f27d1fa8
Reviewed-Content-Hash: design/gdd/card-effects.md 0400f04821c0448a478b87fb82ae42fc7eebc11d
Reviewed-Content-Hash: design/gdd/boss-ai.md d8bfbd6c083e9af0419efd46f2aeb86c98a6dfb6
Reviewed-Content-Hash: design/gdd/card-database.md c5903c4c808a0d2b1cf124242ba10a0fb1ea0fef
Reviewed-Content-Hash: design/gdd/heroes.md e95b75fe14e4afa5b7b181c2c6e4ac15c0e10d37
Reviewed-Content-Hash: design/gdd/treasures.md fa73c76396acba6ea9f3a563094b89c4a81fde01
Reviewed-Content-Hash: design/gdd/run-structure.md 3b61401b846ee41676c50c59cdd3b3bd2a0bc7da
Reviewed-Content-Hash: design/gdd/run-ui.md 40f3ae586d40370209dff143eadf78ad9a6a2f2b
Reviewed-Content-Hash: design/gdd/meta-progression.md e1b2d83f2eee16edc639e9093cc89474ca40df94
Reviewed-Content-Hash: design/gdd/game-concept.md 942314097524c7e2f25ad786643fba0a8aa4a701
Reviewed-Content-Hash: design/gdd/systems-index.md 1a5454bb731d1a57ff78d52c6cb98ae3d49598fc
Reviewed-Content-Hash: design/art/art-bible.md 1dd9cdde34eb11cc75938aaac8d5da5eca280f2b
Reviewed-Content-Hash: design/design-decisions.md 96d205e052b6b069575e43201d735fb254843a13
Reviewed-Content-Hash: .claude/rules/ui-code.md 37c1a82d0cffa30e10fb93ee97b97773c155368f
