# Review Log — Meta Progression (`design/gdd/meta-progression.md`)

## Review — 2026-11-03 — Verdict: NEEDS REVISION
Review mode: lean · Workflow: standard
Scope signal: L
Specialists: none (lean mode — main review only; `game-designer`, `systems-designer`, `economy-designer`, `qa-lead`, `creative-director` not consulted)
Blocking items: 4 | Recommended: 6
Summary: The persistence core (atomic write, backup, migration, corruption, lock, fold, archive) is precise and implementable, and the acceptance criteria are concrete. The document failed on its contracts with its siblings: the M10 locked-treasure table named six ids that do not exist in treasures.md (which locks `treasure_grave_tithe`, `treasure_plague_bell`, `treasure_dogeared_grimoire`, `treasure_living_armory` under milestone-style keys the M2.1 key rule forbade), the unlock-state API matched neither Treasures' `pool(unlocked_keys, …)` nor Reward Draft's `is_treasure_unlocked(id)` at `init_run`, the settings record carried an invented `action_delay_ms` and a Boss AI `telegraph_mode` that boss-ai.md does not define while omitting Match UI's `anim_speed`/`high_contrast_states`, and the profile Loading order ran migration and retro-grant writes before the two-instance lock check. All four were resolved from the sibling GDDs under revise-now (REVISED 2026-11-03 note in the header); the document now awaits re-review as In Review.
Prior verdict resolved: First review
Findings:
- [BLOCKING] Detailed Design M10 / F1 / F5 / F6 / AC-19–21 / AC-24: six locked-treasure ids (`trophy_rack`, `tally_stick`, `deep_lamp`, `banner_of_halvard`, `lich_grimoire`, `gauntlet_crown`, plus `treasure_second_wind`) absent from treasures.md T8 and the registry; "6 locked / 14 unlocked" vs T8's 4 / 16 — FIXED: table rebuilt on T8's four ids and keys with conditions in the M2.2 grammar; examples and ACs rewritten
- [BLOCKING] Detailed Design M2.1: key rule `unlock.treasure_<id>` rejected the keys treasures.md T8/R-14 already names (`hero_decay_first_win` …) — FIXED: keys are unique strings, both styles valid, `unlock.<kind>_<id>` the default for new content
- [BLOCKING] Detailed Design M1.3 / M3.7 / Interactions / Dependencies: unlock-state API (`unlocked_ids("treasure")` at `offer()`) matched neither treasures.md T6 `pool(unlocked_keys, exclude_ids)` nor reward-draft.md `is_treasure_unlocked(id)` at `init_run`; Treasures and Reward Draft described as "no GDD yet / planned" though both are Designed — FIXED: `unlocked_keys()`, `is_treasure_unlocked(id)`, `unlock_hint()`, `last_hero_id()`, `run_log_entry()` added; read point stated as `init_run`; rows confirmed against the files
- [BLOCKING] Detailed Design M9 / Interactions / Dependencies / UI Requirements: settings record carried `action_delay_ms` (no consumer) and attributed `telegraph_mode` to Boss AI (boss-ai.md defines none; `intent_mode` is per-boss data) while omitting match-ui.md's persisted `anim_speed` and high-contrast state — FIXED: `anim_speed` (Match UI enum) and `high_contrast_states` stored; Boss AI row withdrawn; `telegraph_mode` kept for Run UI with owner marked open
- [BLOCKING] States and Transitions "Profile: Loading": order M5 → M4.4 → M3.1(b) → M6 wrote migrations and retro-grants before the lock check, so a second instance could rewrite a file the first owns — FIXED: M6 first; under ReadOnly, migrate and grant in memory only
- [RECOMMENDED] Open Questions: `bosses_defeated_16` read as 16 cumulative kills (16-distinct is inexpressible at `all_of` fan-out 8) — Treasures to confirm
- [RECOMMENDED] Tuning Knobs / Open Questions: no treasure rewards an any-hero milestone; a War-only player sees no treasure unlock before 16 kills — Treasures/Content may lock one universal treasure on `runs_won ≥ 1` (Curiosity hook)
- [RECOMMENDED] Open Questions (cross-GDD): treasures.md States names the grant event `unlock_earned`; this GDD and run-ui.md use `unlock_granted` — rename in treasures.md
- [RECOMMENDED] Open Questions (cross-GDD): run-ui.md `anim_speed` labels `instant|fast|normal` vs match-ui.md owner enum `1.0|1.5|2.0|instant` — Run UI maps labels
- [RECOMMENDED] M9 / design-decisions.md DD-T01: `assets/data/profile.json` shares a basename with `user://profile.json` and is missing from DD-T01's file list — rename `profile_defaults.json`, add the row
- [RECOMMENDED] Open Questions (owner): CR-3 amendment `unlock: {key, condition}` vs card-database/treasures `unlock: string` — Jacob + Card Database owner to decide before `/create-architecture`; a separate `unlocks.json` keyed by the string is the alternative
- [NICE-TO-HAVE] AC-27 "minimum spec" is defined nowhere in design/ — name the target machine in game-concept.md Technical Considerations or the test is not reproducible
- [NICE-TO-HAVE] Registry `unlock_keys_v1` still lists the six stale keys — replace with `hero_decay_first_win, hero_decay_floor_5, hero_knowledge_first_win, bosses_defeated_16, unlock.hero_fortune, unlock.hero_order, unlock.hero_shadow` and drop its reconcile note
Reviewed-Content-Hash: design/gdd/meta-progression.md e1b2d83f2eee16edc639e9093cc89474ca40df94
Reviewed-Content-Hash: design/registry/entities.yaml 3364fe83ab25b4e4e9cc1c97bce415b250230dba
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/treasures.md ad8a1b1d5315568822756ff643ffa53db41e6509
Reviewed-Content-Hash: design/gdd/reward-draft.md 22cb0fa8fa8c6ffab127655ecccb7f50fce77ea7
Reviewed-Content-Hash: design/gdd/run-structure.md e4b95d90738cc6c5d47750708c729a1a815d3e9d
Reviewed-Content-Hash: design/gdd/heroes.md 6539c88e77e08175ac5bce36345d1ab79be429e4
Reviewed-Content-Hash: design/gdd/card-database.md c5903c4c808a0d2b1cf124242ba10a0fb1ea0fef
Reviewed-Content-Hash: design/gdd/rng-event-log.md cb06cb1680292fc0af6b80262894d273f27d1fa8
Reviewed-Content-Hash: design/gdd/run-ui.md 92ba5e70b8b6324bae72d3b5238e86b088f3c99f
Reviewed-Content-Hash: design/gdd/match-ui.md 6645f862cbd413853a0afdec2f3ccf775e811547
Reviewed-Content-Hash: design/gdd/boss-ai.md 494058ed4e0f53de4a41b7e5613c86537dd01d71
Reviewed-Content-Hash: design/gdd/content.md 3e5e568fada0126b6e7f2685c4afe86211dca3e6
Reviewed-Content-Hash: design/gdd/game-concept.md 942314097524c7e2f25ad786643fba0a8aa4a701
Reviewed-Content-Hash: design/design-decisions.md 96d205e052b6b069575e43201d735fb254843a13
Reviewed-Content-Hash: design/gdd/systems-index.md 1a5454bb731d1a57ff78d52c6cb98ae3d49598fc

## Review — 2026-11-03 — Verdict: APPROVED
Review mode: lean · Workflow: standard
Scope signal: L
Specialists: none (lean mode — main review only; `game-designer`, `systems-designer`, `economy-designer`, `qa-lead`, `creative-director` not consulted)
Blocking items: 0 | Recommended: 4
Summary: Re-review after the first-review revisions and the cross-review fixes. All four prior blockers are closed and verified against the siblings and the registry: M10 carries exactly treasures.md T8's four locked ids and keys (rarities and registry `unlock` attributes match), M2.1 accepts both key styles, M1.3 exposes `unlocked_keys()` / `is_treasure_unlocked(id)` read at `init_run` (reward-draft D3/Interactions and treasures T6 now cite them), M9 is the DD-X07 key set with the `instant|fast|normal` labels, `action_delay_ms` → Match UI F4 and `telegraph_mode` → Boss AI C8.4 `effective_mode` (DD-X03), and the Loading row runs the M6 lock before migration and retro-grant writes. Cross-review items C-01, C-10, C-19, C-20, C-21 and C-30 are applied in this GDD and landed in the partner files (design-decisions DD-T01 and card-database CR-1 list `profile_defaults.json`; treasures States says `unlock_granted`; boss-ai, match-ui, run-ui and systems-index carry the DD-X03/DD-X07 consumers). Formulas F1–F7 check out at boundary values; AC-1–30 are concrete. What remains is wording that lags the resolutions the document's own Open Questions table records.
Prior verdict resolved: Yes
Findings:
- [RECOMMENDED] Detailed Design M7.3 / Dependencies (Run Structure row) / Cross-References: still say run-structure R6 "leaves `floor_reached` unset on victory — amendment proposed"; R6 now sets it (run-structure L259) and the Open Questions row says so — reword to "R6 sets it; F3 is the fallback for older records"
- [RECOMMENDED] Detailed Design M2.1 / Interactions (RNG row) / Cross-References: "amends card-database CR-3" and "rule 18 amendment (proposed)" markers are stale — CR-3 carries the `{key, condition}` object (DD-X01) and rng rule 18 keys by `run_id`; mark both adopted
- [RECOMMENDED] UI Requirements (toast row): restates Run UI's toast duration as "run-ui F3 2–6 s"; run-ui F3 is now `clamp(5000 + 30·chars, 5000, 8000)` ms (accessibility floor) and the registry `toast_visible_ms` row [2000, 6000] awaits the registry owner — drop the number and cite F3 only
- [RECOMMENDED] Detailed Design M3.1(b): when a new `data_version` is seen at load but no key is granted, say whether the `data_versions_seen[]` append persists at load or on the next mutator's write (AC-1 forbids a load-time write for `FRESH`; AC-22 covers only the granted case)
- [NICE-TO-HAVE] AC-27 "minimum spec" is still defined nowhere in design/ (game-concept Technical Considerations names none) — owner to name the target machine or the budget test is not reproducible
- [NICE-TO-HAVE] Dependencies intro says Reward Draft / Boss AI / Match UI are "flagged for /map-systems"; systems-index rows 5, 8, 11 already list Meta Progression
- [NICE-TO-HAVE] cross-GDD: run-ui.md L105/L187 still say "there is no `get_run` / `last_hero_id`" while M1.3 offers `run_log_entry(run_id)` and `last_hero_id()`; registry `unlock_keys_v1` note says hero keys are owned by heroes.md while heroes H-7 defers key and condition to Meta M2.1
Reviewed-Content-Hash: design/gdd/meta-progression.md 43936af8124347bad40ad7d52e1eda53d7ec5fcf
Reviewed-Content-Hash: design/registry/entities.yaml 1ee18bfb98f9c2349140eda37142a0e93a335c11
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/treasures.md 97a87411e8e8b1e2988f8eaf36cd4edbde227cee
Reviewed-Content-Hash: design/gdd/reward-draft.md 46e985b9b2915a99fd6a9d039ba420634cb0489b
Reviewed-Content-Hash: design/gdd/run-structure.md 1485f9df6fb25ee9514c6a88385e8f88704f7603
Reviewed-Content-Hash: design/gdd/heroes.md 2c76cf8115794dbf939f51317884d278d4561656
Reviewed-Content-Hash: design/gdd/card-database.md cd631beb882ec0fa4adb3b048671d05628993c49
Reviewed-Content-Hash: design/gdd/rng-event-log.md dc7474f4995cf1741e5617c0b5938f18eee5fcc4
Reviewed-Content-Hash: design/gdd/run-ui.md d9018ff2729512cf024dd40326853be715a806b4
Reviewed-Content-Hash: design/gdd/match-ui.md dbff3a5d072d175f5f8fe406ad9f2258df31077d
Reviewed-Content-Hash: design/gdd/boss-ai.md 346787f0550706b31047cb67b5356266e488440a
Reviewed-Content-Hash: design/gdd/content.md 9a4fabbfd9e515a5dd437ed7babbe949119da8ee
Reviewed-Content-Hash: design/gdd/game-concept.md c781025c5f2a71209b4de0976ab806d097b8f0b0
Reviewed-Content-Hash: design/design-decisions.md 7a7fd2f58edfa5bdefa2d9e376b809a4a529615f
Reviewed-Content-Hash: design/gdd/systems-index.md b6cea95eef89f3f0015d0cd1ff03c7189442aceb
Reviewed-Content-Hash: design/gdd/gdd-cross-review-2026-11-03.md c735c9738a373e58a095ba1c942ee89f0de6685a
