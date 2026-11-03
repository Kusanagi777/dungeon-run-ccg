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
