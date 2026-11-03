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

## Review — 2026-11-03 — Verdict: APPROVED
Review mode: lean · Workflow: standard
Scope signal: L
Specialists: none (lean mode — no specialist agents; main review re-checked all 32 ACs, the registry search, run-structure T21/`suspend`, Meta M1.3/M3.6/M9, reward-draft D8/D9/D11 + DD-X05, match-ui "Match end", boss-ai C8.4, heroes H-2/DD-X02, accessibility-requirements "Reading time"/Visual/Motor, interaction-patterns Toast/Focus Management/Pick One of N/Progress Strip, art bible §2/§4, ui-code.md rules 1–8)
Blocking items: 0 | Recommended: 3
Summary: Re-review after the first-review revisions, the cross-review fixes and the accessibility alignment. Every prior blocker is resolved and verified against the siblings: `draft_offered{floor, kind, option_ids[], flags[]}` with 1–3 offers and `allow_skip` (DD-X05), the real Meta API and the DD-X07 settings record edited by Run UI and read by Match UI / Boss AI (C-01), `match_view_finished` + 4 s auto-advance, S11b on `match_faulted`, the seven commands including `suspend()` wired as S23 (C-12), F3 at 5000–8000 ms with hover/focus pause, the 2 px / 3 px-offset focus ring, `1`/`2`/`3` + Tab reachability and three discrete `text_scale` steps. F1–F4 recompute exactly; all ten dependency GDDs exist; every registry value in the document agrees except `toast_visible_ms`, where the GDD is the owning source and the registry row is the stale side. Three non-blocking token/pointer corrections remain (below).
Prior verdict resolved: Yes
Findings:
- [RECOMMENDED] Detailed Design U2 `pause` row / Cross-References: `E_PHASE` should read `E_BAD_PHASE` — run-structure.md line 80 states "the cross-review's `E_PHASE` is this GDD's `E_BAD_PHASE`" and uses `E_BAD_PHASE` everywhere else.
- [RECOMMENDED] Detailed Design U7: "(Meta M7.1 — there is no `last_hero_id`)" is wrong — meta-progression.md M1.3 defines `last_hero_id() -> hero_id | null` as argmax `last_played_at`; U7 should call it (null → War) instead of recomputing the argmax; the Open Questions row "only the three M9 keys above remain open" is stale (all resolved).
- [RECOMMENDED] Acceptance Criteria AC-26: "named in `project.yaml` platform notes" dangles — project.yaml has no such block; point at the target-hardware wording card-database's performance AC uses (mid-range desktop, SSD, release build; `.claude/docs/technical-preferences.md` Platform Notes) and record the actual machine in the evidence note until `project.yaml performance:` names one. The 100 ms / 50 ms / zero-allocation thresholds are already measurable.
- [REGISTRY] `toast_visible_ms` (entities.yaml ~line 1256): expression `clamp(2000 + 30*chars, 2000, 6000)` and `output_range [2000, 6000]` are stale against the owning GDD's F3 (`clamp(5000 + 30*chars, 5000, 8000)`, 5000–8000); set `revised: 2026-11-03`.
- [CROSS-DOC] accessibility-requirements.md rows 207 and 290 still describe the toast as 2–6 s and row 365 keeps the raise-to-5000 request open; row 99 lists the pre-DD-X07 `anim_speed` enum. meta-progression.md line 380 (Run UI row) still lists `unlock_hint`. match-ui.md line 438 says Run UI hands over "current settings values" — both read Meta's record per DD-X07. None is a Run UI defect.
Reviewed-Content-Hash: design/gdd/run-ui.md d9018ff2729512cf024dd40326853be715a806b4
Reviewed-Content-Hash: design/registry/entities.yaml 1ee18bfb98f9c2349140eda37142a0e93a335c11
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/reward-draft.md 46e985b9b2915a99fd6a9d039ba420634cb0489b
Reviewed-Content-Hash: design/gdd/meta-progression.md 43936af8124347bad40ad7d52e1eda53d7ec5fcf
Reviewed-Content-Hash: design/gdd/match-ui.md dbff3a5d072d175f5f8fe406ad9f2258df31077d
Reviewed-Content-Hash: design/gdd/run-structure.md 1485f9df6fb25ee9514c6a88385e8f88704f7603
Reviewed-Content-Hash: design/gdd/card-database.md 137ebdb8bac44a389c04a3ce06453157c07d0a14
Reviewed-Content-Hash: design/gdd/heroes.md 2c76cf8115794dbf939f51317884d278d4561656
Reviewed-Content-Hash: design/gdd/rng-event-log.md dc7474f4995cf1741e5617c0b5938f18eee5fcc4
Reviewed-Content-Hash: design/gdd/boss-ai.md 346787f0550706b31047cb67b5356266e488440a
Reviewed-Content-Hash: design/gdd/game-concept.md c781025c5f2a71209b4de0976ab806d097b8f0b0
Reviewed-Content-Hash: design/gdd/systems-index.md b6cea95eef89f3f0015d0cd1ff03c7189442aceb
Reviewed-Content-Hash: design/art/art-bible.md 1dd9cdde34eb11cc75938aaac8d5da5eca280f2b
Reviewed-Content-Hash: design/design-decisions.md 7a7fd2f58edfa5bdefa2d9e376b809a4a529615f
Reviewed-Content-Hash: .claude/rules/ui-code.md 37c1a82d0cffa30e10fb93ee97b97773c155368f
Reviewed-Content-Hash: design/accessibility-requirements.md 96c731ff0757d53872c56769c5893286d5c351dd
Reviewed-Content-Hash: design/ux/interaction-patterns.md 0a5713271e352b17d993667908c55de8d2b3670e
