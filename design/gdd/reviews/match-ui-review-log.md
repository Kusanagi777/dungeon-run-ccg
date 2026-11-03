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

## Review — 2026-11-03 — Verdict: NEEDS REVISION
Review mode: lean · Workflow: standard
Scope signal: L
Specialists: none (lean — main review only; no Agent calls)
Blocking items: 3 | Recommended: 6
Summary: Re-review after the first-review revisions, cross-review C-01 / C-07 / S-04 and the accessibility and pattern-library alignments. Every prior blocking item is resolved and the alignments landed as specified (click-to-select with the 8 px threshold, `end_turn_arm_ms` 300 ms with the click never gated, `Esc` falling through to the pause menu on Mulligan / Choice / end banner, `Tab` idle focus cycle with the 2 px ring, 44x44 chip hit rects, `Blocked` reason on focus); ui-code.md rules 1, 2, 4–6 and 8 and art bible §4 geometry and tokens hold, and every registry value the GDD restates matches. Three new defects a programmer would have implemented as written were found and fixed in place (option A, no owner decision): the F6 mana bar sat inside the hand zone (covered for every n ≥ 6, and the rotated fan envelope reaches x 188 / 1092, so O1, O3 and F1's "no overlap" claims were false); rng-event-log rule 12a's `diagnostic: true` events and card-effects' `counter_changed` were in neither the U3 table nor the silent set, so rule 4 would have printed `feed.unknown` lines every boss turn in release; L15 assumed `Space` ends the turn while U5 gives idle focus to the left-most playable card. Status is In Review pending a byte-identical re-review.
Prior verdict resolved: Yes
Findings:
- [BLOCKING] Formulas F6 / F1 / AC O1, O3: mana bar `1000, 676, 256, 32` overlapped the hand zone (right card x 890–1040, rotated edge x 1048 at y 676; outer top corners x 188 / 1092) — fixed: mana bar `1060, 652, 196, 56` (two rows), deck pile `1180, 540, 76, 106`, tray three v1 slots (`MAX_TREASURES_HELD`), `HAND_W` safe range 700–800, F1 envelope stated, O1 rewritten
- [BLOCKING] Detailed Design U3 / Interactions: `ai_decision`, `ai_plan_aborted`, `ai_fault` (rng rule 12a) and `counter_changed` (card-effects C5) fell to rule 4 (`feed.unknown`) — fixed: rule 4a filters diagnostics (player `command_rejected` keeps the tooltip and gains `feed.command_rejected`, accessibility-requirements "Reading time"), `counter_changed` → `counters{}` + feed line, no badge; L9 / L18; `--ai-debug` in U11
- [BLOCKING] Acceptance Criteria L15: unsatisfiable when a playable card is lit (U5: `Space` is End Turn only with no card focused) — fixed: precondition "no playable card lit" plus the lit-card branch
- [RECOMMENDED] Detailed Design U5 (fixed): idle focus order differed from interaction-patterns Focus Management, the owner the GDD names — aligned to hero power → portrait → chips → End Turn
- [RECOMMENDED] UI Requirements / AC O15 (fixed): pause-menu row omitted `reduce_motion` that U9 lists; O17 defined as view-state equality plus a retained pose pair
- [RECOMMENDED] Detailed Design U5 (`/ux-design hud`): `Space` with a playable card focused does nothing in `Idle` and gives no feedback — specify a response (focus jumps to End Turn, or a flash)
- [RECOMMENDED] Acceptance Criteria L13: millisecond budgets still name no reference machine
- [RECOMMENDED] Cross-GDD housekeeping: rng-event-log rule 12a line 117 ("hides diagnostic events … unless a debug flag") now has the player `command_rejected` exception; treasures.md Tuning Knobs line 669 says the tray width "assumes ≤ 4" — it is three slots
- [RECOMMENDED] Registry: `boss_turn_gap.output_range` [0.15, 0.6] is stale — `action_delay_ms` (0–2000) raises the clamp cap to 2.0 (L16 yields 1.2); `hero_war` / `hero_decay` / `hero_knowledge` list match-ui.md in `referenced_by` though the GDD never names those entries (harmless)
Reviewed-Content-Hash: design/gdd/match-ui.md 2d49b0054a541eaef149cf7b26ce21617b2099e4
Reviewed-Content-Hash: design/registry/entities.yaml c0b7b1c0ad84e2c548b1bb890c79073e397c259c
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/match-rules.md 54e7dae9ecc522fc57787bf4c65313364d74be3f
Reviewed-Content-Hash: design/gdd/rng-event-log.md dc7474f4995cf1741e5617c0b5938f18eee5fcc4
Reviewed-Content-Hash: design/gdd/card-effects.md 0a434c1bcf30900536181fc057877a04832c766e
Reviewed-Content-Hash: design/gdd/boss-ai.md 346787f0550706b31047cb67b5356266e488440a
Reviewed-Content-Hash: design/gdd/card-database.md bf374f0a4c79940fe414c216246ea3cca7f195db
Reviewed-Content-Hash: design/gdd/heroes.md 2c76cf8115794dbf939f51317884d278d4561656
Reviewed-Content-Hash: design/gdd/treasures.md 97a87411e8e8b1e2988f8eaf36cd4edbde227cee
Reviewed-Content-Hash: design/gdd/run-structure.md 1485f9df6fb25ee9514c6a88385e8f88704f7603
Reviewed-Content-Hash: design/gdd/run-ui.md d9018ff2729512cf024dd40326853be715a806b4
Reviewed-Content-Hash: design/gdd/meta-progression.md 43936af8124347bad40ad7d52e1eda53d7ec5fcf
Reviewed-Content-Hash: design/gdd/game-concept.md c781025c5f2a71209b4de0976ab806d097b8f0b0
Reviewed-Content-Hash: design/gdd/systems-index.md b6cea95eef89f3f0015d0cd1ff03c7189442aceb
Reviewed-Content-Hash: design/art/art-bible.md 1dd9cdde34eb11cc75938aaac8d5da5eca280f2b
Reviewed-Content-Hash: design/design-decisions.md 6d7e7fac963fc62e7ff90a531df77e23e2eb0488
Reviewed-Content-Hash: .claude/rules/ui-code.md 37c1a82d0cffa30e10fb93ee97b97773c155368f
Reviewed-Content-Hash: design/accessibility-requirements.md 96c731ff0757d53872c56769c5893286d5c351dd
Reviewed-Content-Hash: design/ux/interaction-patterns.md 0a5713271e352b17d993667908c55de8d2b3670e

## Review — 2026-11-03 — Verdict: APPROVED
Review mode: lean · Workflow: standard
Scope signal: L
Specialists: none (lean — main review only; no Agent calls)
Blocking items: 0 | Recommended: 6
Summary: Final pass after the re-review's three in-place fixes and the cross-GDD housekeeping. All three fixes hold by the document's own numbers: the F6 mana bar `1060, 652, 196, 56` clears card 9's rotated right edge (x 1054 at y 652) and the deck pile `1180, 540, 76, 106` clears both; U3.4a filters rng-event-log rule 12a's `diagnostic: true` class (rng-event-log now marks the player's `command_rejected` diagnostic) and `counter_changed` projects to `counters{}`; L15 carries the "no playable card lit" precondition. The Run UI row reads settings from Meta Progression (DD-X07), treasures.md says three tray chips, and every registry value the GDD restates (`hand_fan_width_px` 800, `hover_scale` 1.5, the three `anim_*_s`, `min_action_gap_s`, `rejection_tooltip_s`, `feed_max_lines`, `match_end_auto_s`, `board_size` 7, `hand_size` 10, `starting_hand_player` 3, `max_mana_crystals` 10, `ai_action_delay_s` 0.6, `discover_count` 3, `hero_power_cost` 2) matches; F1, F2, F4 and F5 worked examples recompute; ui-code.md rules 1, 2, 4–6 and 8 and art bible §4 tokens, sizes and slot geometry hold. Remaining items are stale cross-reference wording and one undeclared Boss AI knob — none changes what a programmer builds.
Prior verdict resolved: Yes
Findings:
- [RECOMMENDED] Dependencies intro: still says the index lacks Run UI and Meta Progression ("rows this table adds … flagged for `/map-systems`") — systems-index row 11 now lists all ten; drop the sentence
- [RECOMMENDED] Interactions Run Structure row / Dependencies: "it never references this system" is stale — run-structure.md's Boss AI row (cross-review C-17) names Match UI's `MatchController` as the driver's wrapper; the direction (nothing flows back, hand-off via Run UI) is unchanged
- [RECOMMENDED] Detailed Design U6.2 / Tuning Knobs "owned elsewhere": the "plan changed" label has no duration here — boss-ai Tuning Knobs owns `plan_changed_s` 1.2 s; name it and say whether it replaces `intent_banner_s` as F4's pre-action beat when `kept = false`
- [RECOMMENDED] Tuning Knobs `reduce_motion` / Impact Moments: accessibility-requirements Visual table (Comprehensive, Pre-Production) also makes `reject_shake` a 2-frame outline flash and the skip-hint / `lethal` pulses static under `reduce_motion`; cite that table as the owner or extend the row
- [RECOMMENDED] Detailed Design U9 / States `ChoiceOpen`: "opens on `choice_requested`" — U3's pair rule (overlay on the second of `choice_requested` / `discover_offered`, whichever order) is the one to cite
- [RECOMMENDED] Acceptance Criteria L13: millisecond budgets still name no reference machine (carried from both prior reviews)
- [RECOMMENDED] Cross-GDD housekeeping (not this GDD): rng-event-log rule 12a's parenthetical says U3.4a "filters them from the feed" — match-ui gives the player's own `command_rejected` a `feed.command_rejected` line (accessibility "Reading time"); accessibility-requirements Motor rows "Hold-to-press alternatives" and "Accidental-activation guard" still read "Not in match-ui U5 today" / "Recorded as a conflict" — both resolved into U5
- [RECOMMENDED] Registry: `boss_turn_gap.output_range` [0.15, 0.6] still stale — `action_delay_ms` 0–2000 raises the clamp cap to 2.0 (L16 yields 1.2); `hero_war` / `hero_decay` / `hero_knowledge` `referenced_by` match-ui.md though the GDD never names those entries (harmless)
Reviewed-Content-Hash: design/gdd/match-ui.md e2bcccad61083401a8c8dbdbd0a4068afc64e3d7
Reviewed-Content-Hash: design/registry/entities.yaml 76f479bf5a4270db81c0d82a5eb86ee4c5c9e227
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/match-rules.md 7af4351b32a419195d38bf274c2a68b9c63aa804
Reviewed-Content-Hash: design/gdd/rng-event-log.md 6981bf37934cae2e74ed37a23eb349fb62dcbf5b
Reviewed-Content-Hash: design/gdd/card-effects.md 0a434c1bcf30900536181fc057877a04832c766e
Reviewed-Content-Hash: design/gdd/boss-ai.md 2c2bedbaa6ff558777d2af7d81b3b91c5783af82
Reviewed-Content-Hash: design/gdd/card-database.md d04095c7f44e5d930ba3c23c4f88024736fdc6a8
Reviewed-Content-Hash: design/gdd/heroes.md 3e9c89b4cd87b8fde225762af7e169fcf2fed1dd
Reviewed-Content-Hash: design/gdd/treasures.md b50806cc8b2b5117b0064b934122be5ecaced4ad
Reviewed-Content-Hash: design/gdd/run-structure.md f89d6a98f6981671324f9a0c49708df0d1847787
Reviewed-Content-Hash: design/gdd/run-ui.md b97595084d05aabfe872316243343bf85c3f45d0
Reviewed-Content-Hash: design/gdd/meta-progression.md 878962538feb2a76598643d4ce90adc4f436ba55
Reviewed-Content-Hash: design/gdd/game-concept.md 0c2c930dd6bdaa11592472e2051d801911f4ded1
Reviewed-Content-Hash: design/gdd/systems-index.md a20a2191f2853e48591ac1eec0417f089077f7c6
Reviewed-Content-Hash: design/art/art-bible.md 1dd9cdde34eb11cc75938aaac8d5da5eca280f2b
Reviewed-Content-Hash: design/design-decisions.md 914fb4ab3d19c6957bf65dcff93bb6804f664708
Reviewed-Content-Hash: .claude/rules/ui-code.md 37c1a82d0cffa30e10fb93ee97b97773c155368f
Reviewed-Content-Hash: design/accessibility-requirements.md 52e2cd2ed4cc0ad43c175655eb00d08c2519b3f7
Reviewed-Content-Hash: design/ux/interaction-patterns.md 0a5713271e352b17d993667908c55de8d2b3670e
