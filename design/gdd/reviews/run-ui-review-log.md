# Review log — design/gdd/run-ui.md

## Review — 2026-11-03 — Verdict: NEEDS REVISION
Review mode: lean · Workflow: standard
Scope signal: L
Specialists: none (lean mode — no specialist agents; main review checked ACs, registry, art bible §2/§4, ui-code.md)
Blocking items: 6 | Recommended: 7
Summary: The screen inventory, shell state machine, timing budgets (F1–F4 recompute correctly) and the art-bible mood per state are sound and the registry values all agree. The document failed on its contracts: it was written while reward-draft.md, meta-progression.md and match-ui.md were still "concurrent/planned", and all three now disagree with it (event payload `option_ids`/`flags` and 1–3 offers, Meta's real API names, typed-confirm reset, `ack_notification`, settings keys, `match_view_finished` with a 4 s auto-advance), plus a missing `match → boss_intro` transition on `match_faulted` and two ui-code.md gaps (text scale, min/max resolution). All six blockers were resolved in-session (option A); three cross-GDD items remain open in the GDD's Open Questions (Meta M9 keys, Run Structure `suspend()`, Meta toast-ack wording).
Prior verdict resolved: First review
Findings:
- [BLOCKING] Detailed Design U8 / Interactions / S12–S15 / AC-9, AC-21: Reward Draft contract mismatch — `offered_ids`+`theme_labels` vs `option_ids`+`flags`; "exactly 3" vs `short` (1–2) and `[]` skipped in the run; `synergy_tags` vs `TreasureDef.tags` and Reward Draft's own `n_tag`/`affine` numbers; no `allow_skip` control. FIXED.
- [BLOCKING] Detailed Design U2/U5/U7 / Interactions / Edge Cases: Meta Progression contract mismatch — invented API (`unlock_hint`, `profile_stats`, `list_runs`, `get_run`, `last_hero_id`, `get_setting`) vs M1.3 (`unlock_progress(key)`, `stats_for_hero`, `run_log(offset, limit)`, `get_settings`, `pending_notifications`/`ack_notification`); `unlock_granted` payload; "typed RESET not required" contradicts M1.1 typed confirmation; no load-status line / ReadOnly banner; settings screen lacked `action_delay_ms`, `keep_run_records`, Clear run records; `max_archived_runs` → `run_log_cap`. FIXED.
- [BLOCKING] Detailed Design U2 `match` / S11 / Interactions / Dependencies / Cross-References: Match UI handoff named `match_ended(MatchResult)` + "Continue"; match-ui.md emits `match_view_finished(result)` after click or `MATCH_END_AUTO_S` = 4 s. FIXED.
- [BLOCKING] States and Transitions: no row for `match → boss_intro` on `match_faulted` (AC-11 would reject the fault path as `bad_state`); events arriving during the end banner unbuffered. FIXED (S11b, buffer rule, AC-29).
- [BLOCKING] Tuning Knobs / UI Requirements / Acceptance Criteria: ui-code rule 7 (scalable text mandatory) — no text-scale setting; rule 8 — no min/max resolution test. FIXED (`text_scale` knob, AC-31); the Meta key is cross-GDD.
- [BLOCKING] Visual/Audio: art bible §4 — identification colour used as toast text colour (no third text colour; fails contrast on `table_dark`); `state_buff` "for one beat" on the deck count violates rule (c) (readout, not animation). FIXED.
- [RECOMMENDED] Open Questions: Meta M9 must add `anim_speed`, `text_scale`, `high_contrast_states` (match-ui.md assumes them too) — cross-GDD, left open.
- [RECOMMENDED] Open Questions: pause "Quit to menu" between matches has no Run Structure command (`return_to_menu` is terminal-only) — proposed `suspend()`, cross-GDD, left open.
- [RECOMMENDED] Open Questions: Meta UI Requirements "acked after 4 s" vs Run UI F3 — Meta wording, left open.
- [RECOMMENDED] Formulas F4 / Open Questions: bundle hover preview "anchored to the panel's outer edge" leaves the viewport for the right panel — anchoring rule proposed for `/ux-design draft-picker`.
- [RECOMMENDED] Acceptance Criteria AC-26: "reference machine" undefined — rewritten to the minimum-spec machine with a measurable idle-allocation check.
- [RECOMMENDED] Visual/Audio: UI sounds not stated to go through the audio event bus (ui-code rule 5) — sentence added.
- [RECOMMENDED] Detailed Design U7 / Open Questions: "first run forces War" (heroes.md H-2) vs pre-select here — owner decision, left open.
Reviewed-Content-Hash: design/gdd/run-ui.md 40f3ae586d40370209dff143eadf78ad9a6a2f2b
Reviewed-Content-Hash: design/registry/entities.yaml 3364fe83ab25b4e4e9cc1c97bce415b250230dba
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/reward-draft.md 8b94d9030c171b13258dc882b6c847d71e12305d
Reviewed-Content-Hash: design/gdd/meta-progression.md e1b2d83f2eee16edc639e9093cc89474ca40df94
Reviewed-Content-Hash: design/gdd/match-ui.md a267c1524337e040e9ba5eb85f4b56c514244e0a
Reviewed-Content-Hash: design/gdd/run-structure.md 3b61401b846ee41676c50c59cdd3b3bd2a0bc7da
Reviewed-Content-Hash: design/gdd/card-database.md c5903c4c808a0d2b1cf124242ba10a0fb1ea0fef
Reviewed-Content-Hash: design/gdd/heroes.md 99f04753bbdabf6c30014f9d1c9842d6485d07b6
Reviewed-Content-Hash: design/gdd/rng-event-log.md cb06cb1680292fc0af6b80262894d273f27d1fa8
Reviewed-Content-Hash: design/gdd/game-concept.md 942314097524c7e2f25ad786643fba0a8aa4a701
Reviewed-Content-Hash: design/art/art-bible.md 1dd9cdde34eb11cc75938aaac8d5da5eca280f2b
Reviewed-Content-Hash: design/design-decisions.md 96d205e052b6b069575e43201d735fb254843a13
Reviewed-Content-Hash: .claude/rules/ui-code.md 37c1a82d0cffa30e10fb93ee97b97773c155368f
