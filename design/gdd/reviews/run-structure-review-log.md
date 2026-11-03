# Review Log — Run Structure (`design/gdd/run-structure.md`)

## Review — 2026-11-03 — Verdict: NEEDS REVISION
Review mode: lean · Workflow: standard
Scope signal: L
Specialists: none (lean mode — no specialist agents; main review performed all checks)
Blocking items: 3 | Recommended: 7
Summary: A thorough, implementable state machine whose formulas (F1–F7) and 31 acceptance criteria all check out numerically (F5 turn model, F6 p_reach/p_victory, AC-24's FNV-1a hash verified). It failed on three counts: the Reward Draft and Treasures contracts it proposed had been amended by those GDDs (`init_run`, `pick` signature, `draft_state` schema, empty-offer skip, `collect_state`) and the document still carried the superseded versions; and R6's abandon rule computed `floors_cleared = floor − 1` in every phase, which discards the won match when a player quits from a draft, and never set `floor_reached`, which Meta Progression F3 reads. All three were resolved in place from the sibling GDDs (revised 2026-11-03, status In Review); the remaining findings need another GDD or an owner decision and are listed below.
Prior verdict resolved: First review
Findings:
- [BLOCKING] Detailed Design R1/R2/R5/R8, Interactions: Reward Draft contract out of date — `draft_state` described as "pity counters + offered_treasure_ids[]" (reward-draft.md D3 schema is `{schema_version, treasure_pool[]}`); no `init_run` at run start or on a schema-less resume; `offer` return shape and `pick(kind, id, offer, run_state)` call missing; empty offer ⇒ step skipped not handled (T11/T12 guards would deadlock). FIXED: R1 rows, invariants, R2 step 5, R5.3–5.7, R8.2, T19/T20, Interactions/Dependencies rows, AC-32/AC-33.
- [BLOCKING] Detailed Design R1/R4: Treasures contract — `treasure_state` schema `{schema_version, by_treasure{}}` and the `collect_state(hooks, match_result)` call after `match_ended`, before S2 (treasures.md T4, R-11) absent. FIXED: R1 row, R2 step 5 init, R4 call order, AC-35.
- [BLOCKING] Detailed Design R6: abandon accounting — `floors_cleared = floor − 1` from `post_match_reward` undercounts the floor just won; `floor_reached` unset for abandon although Meta F3 reads it. FIXED: phase-dependent `floors_cleared`, `floor_reached = floors_cleared + 1`, victory sets `floor_reached = F`; Edge Cases bullet; AC-34.
- [RECOMMENDED] Detailed Design R3 / Open Questions: `MatchConfig.seed` (match-rules.md C3 "the engine seeds the match stream from seed") vs the memoised `match_<f>` / `ai_<f>` streams this GDD passes; match-rules.md's own Interactions row says it "never seeds or reseeds" — Match Rules must pick one. CROSS-GDD (match-rules.md).
- [RECOMMENDED] Detailed Design R10 / Interactions: RNG & Event Log catalogue still lists `treasure_granted` under Reward Draft and writes `run_ended.result` as `victory/death/abandoned`; this GDD, reward-draft.md D11 and treasures.md T5 all say Run Structure / `defeat`. CROSS-GDD (rng-event-log.md catalogue rows). Also rule 18 keys archived match logs by `run_seed_hex` alone (replayed seed overwrites) — proposed `run_id`.
- [RECOMMENDED] Interactions / Open Questions: `new_run` / `E_HERO_LOCKED` here vs `start_run` / `HERO_LOCKED` in heroes.md and run-ui.md. CROSS-GDD naming; this GDD owns the command set.
- [RECOMMENDED] Open Questions: heroes.md H-2 says Run Structure owns "first run forces War"; run-ui.md pre-selects and never forces; this GDD states no rule. OWNER DECISION (force vs pre-select); inert at MVP (War only).
- [RECOMMENDED] Detailed Design R1/R6: `play_seconds`, `started_at`, `run_id` need a clock inside a `RefCounted` rules object — inject a clock (DI over singletons, coding standards) so AC-28's byte-identical round-trip and AC-19 stay deterministic. Not fixed (implementation guidance; no rule change).
- [RECOMMENDED] Detailed Design R2 step 1: "old run ends as abandoned/player" when a *saved* (not in-memory) run exists — state that `new_run` loads and validates the slot first; a record that fails validation ends as a system abandon (R8.1), not a loss. Not fixed (minor; R8.1 already implies it).
- [RECOMMENDED] Dependencies / registry: treasures.md T6 still cites `draft_state.offered_treasure_ids[]` (superseded by reward-draft.md D3). CROSS-GDD (treasures.md).
- [NICE-TO-HAVE] Formulas F7: "valleys are the treasure floors (1, 3, 5)" while the floor-6 row calls itself the valley — pick one reading.
- [NICE-TO-HAVE] Acceptance Criteria AC-2: rewritten from "the `run` stream reports exactly 3 shuffle calls" (the snapshot exposes draw counts, not calls) to a recording test double asserting three `shuffle` calls of lengths 6/6/4 and no other draw. FIXED.
- [REGISTRY] No value conflicts. 89 lines matched the 128 entity names; every stated value agrees (hero_war 30 hp / 15 starter; boss_starting_health_by_band 30/40/50; starter_deck_size 15; bundle_card_count 3; min_treasure_pool 9; floors_per_run 8/4; band_split 3/3/2; treasure_floors 1,3,5; target_win_rate_by_floor; deck_size_by_floor; turns_to_lethal; run_record_schema_version 1). Corrections for the registry owner: `boss_sequence.output_range [4, 12]` vs the GDD's `floors_per_run` safe range 3–12 (line "Tuning Knobs"); `referenced_by: design/gdd/run-structure.md` is over-claimed on the 16 `boss_*` entries, `hero_decay`, `hero_knowledge` and `stream_seed` — the document never names them. Systems index: Run Structure's dependency column omits Meta Progression (mutual, R7).
- [REGISTRY] Open Questions rows for DD-T01 (`run_structure.json` now listed) and the concept's "first treasure on floor 2" (concept now reads floor 1 per DD-R05) were stale — marked resolved.
Reviewed-Content-Hash: design/gdd/run-structure.md 3b61401b846ee41676c50c59cdd3b3bd2a0bc7da
Reviewed-Content-Hash: design/registry/entities.yaml 3364fe83ab25b4e4e9cc1c97bce415b250230dba
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/reward-draft.md 40e87d43e0dd3bb8e64a161bfb36ba3d17afe7d0
Reviewed-Content-Hash: design/gdd/treasures.md c81e941b3e2ce459c0fa47c1377f1619ea48ed07
Reviewed-Content-Hash: design/gdd/meta-progression.md e1b2d83f2eee16edc639e9093cc89474ca40df94
Reviewed-Content-Hash: design/gdd/heroes.md 963a79afe86142ab4a17911e6b37ef37fb53195e
Reviewed-Content-Hash: design/gdd/match-rules.md bb4bfe29a4dffb9a7638e040f60249b3baa6919d
Reviewed-Content-Hash: design/gdd/rng-event-log.md cb06cb1680292fc0af6b80262894d273f27d1fa8
Reviewed-Content-Hash: design/gdd/run-ui.md 264fec3bca820fde7c3469324043570d25267e5c
Reviewed-Content-Hash: design/gdd/card-database.md c5903c4c808a0d2b1cf124242ba10a0fb1ea0fef
Reviewed-Content-Hash: design/gdd/game-concept.md 942314097524c7e2f25ad786643fba0a8aa4a701
Reviewed-Content-Hash: design/design-decisions.md 96d205e052b6b069575e43201d735fb254843a13
Reviewed-Content-Hash: design/gdd/systems-index.md 1a5454bb731d1a57ff78d52c6cb98ae3d49598fc

## Review — 2026-11-03 — Verdict: APPROVED
Review mode: lean · Workflow: standard
Scope signal: L
Specialists: none (lean mode — no specialist agents; main review performed all checks)
Blocking items: 0 | Recommended: 7
Summary: Re-review after the first-review revisions and the cross-review fixes. All three prior blockers hold (Reward Draft `init_run` / `Offer{option_ids[], flags[]}` / `pick` / `draft_state` schema / empty-offer skip; Treasures `collect_state` before S2; phase-dependent abandon accounting with `floor_reached` on every result). C-11 (no first-run hero, DD-X02; Heroes row and both Open Questions closed), C-12 (`suspend` in Core Rules, T21, R8.7, Interactions seven commands, Dependencies, Edge Cases, AC-36 — matches run-ui S23/L107 and the cross-review decision 6), C-17 (Boss AI rows: Run Structure owns the match driver — matches boss-ai L342/L634 and match-ui L93), C-30 (Open Questions on `MatchConfig.seed`, catalogue owner / `defeat`, `BossDef.tags`, rule 18, treasures T6 marked resolved) and DD-X05 (`offered_ids` only in the persisted DraftRecord, lines 106/214/226/940) are all verified in place and against the partner GDDs. Formulas re-checked (F6 `p_reach(8)` = 0.0835, `expected_floors_cleared` = 3.268; AC-11/33/34 arithmetic). What remains is housekeeping text that the document's own Open Questions table already supersedes, plus two small implementability clarifications — none blocks a programmer.
Prior verdict resolved: Yes
Findings:
- [RECOMMENDED] Detailed Design R3: "Match Rules C3 names a `seed` field … Match Rules settles it" is stale — match-rules C3/Dependencies now take the memoised `rng_match` / `rng_ai` handles and never seed (its REVISED note, L169–170); the Open Questions row already says so. Delete the paragraph.
- [RECOMMENDED] Detailed Design R5.2 / Formulas F2 / Edge Cases / Tuning Knobs: stale markers — "(contract — to be confirmed in reward-draft.md)" (confirmed, D2/F4), "`BossDef.tags[]` not in Card Database CR-3 today" (CR-3 L145 has it; knob inert until Content tags bosses), "rule 18 keys match-log folders by `run_seed_hex` alone — flagged" (rng rule 18 now keys by `run_id`), Dependencies "the index omits Meta Progression" (systems-index row 7 lists it). Each contradicts this GDD's own Open Questions resolution.
- [RECOMMENDED] Detailed Design R8.7: "Nothing is lost because every state `suspend` is legal in was saved on entry" is over-strong after an `E_IO` save failure (Edge Cases: run continues in memory) — state that `suspend` after `save_failed` replays the floors since the last good save, or retries the save once before dropping the run.
- [RECOMMENDED] Detailed Design R2.1 / T2: with `suspend` the common New-Run path is "saved run, no in-memory run"; say that `new_run` loads and validates the slot first, applies R6's phase-dependent `floors_cleared` to the loaded status, and that a record failing validation ends as a system abandon (R8.1), not a loss.
- [RECOMMENDED] Acceptance Criteria AC-30: 5 ms / 20 ms wall-clock thresholds are machine-dependent — mark ADVISORY or name the reference machine / CI runner.
- [RECOMMENDED] Interactions Boss AI: this GDD writes `BossAI(ai_id, rng_ai, config("ai_profiles"))`; boss-ai C1.1 writes `(boss_def, resolved_profile, band, ai_stream, op_values)`. Same owner (C-17), different constructor sketch — architecture/ADR settles it. CROSS-GDD (informational).
- [RECOMMENDED] Rejection codes: run-ui.md L107/L679 cites `E_PHASE` as a Run Structure code; this GDD's code is `E_BAD_PHASE` (noted at L80). CROSS-GDD (run-ui.md).
- [REGISTRY] No value conflicts: 114 lines matched the registry names; every stated value agrees (hero_war 30 / 15; boss_starting_health_by_band 30/40/50; starter_deck_size 15; bundle_card_count 3; min_treasure_pool 9; floors_per_run 8/4; band_split 3/3/2; treasure_floors 1,3,5; target_win_rate_by_floor; deck_size_by_floor [15,36]; turns_to_lethal [6,12]; run_record_schema_version 1; restart_budget_ms 5000; boss_sequence.output_range now [3,12] — prior correction applied). Still open for the registry owner (C-29): `referenced_by: design/gdd/run-structure.md` remains on the 16 `boss_*` entries, `hero_decay`, `hero_knowledge`, `stream_seed`, `max_match_events`, `profile_schema_version`, `progress_strip_geometry`, `stats_fold`, `offers_per_draft`, `boss_pressure` — the document names none of them. `boss_health.output_range [30, 60]` is narrower than the GDD's variable ranges imply (BossDef.health 20–60 + bonus 0–5 → 20–70); widen or note "defaults".
Reviewed-Content-Hash: design/gdd/run-structure.md 1485f9df6fb25ee9514c6a88385e8f88704f7603
Reviewed-Content-Hash: design/registry/entities.yaml 1ee18bfb98f9c2349140eda37142a0e93a335c11
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/reward-draft.md 46e985b9b2915a99fd6a9d039ba420634cb0489b
Reviewed-Content-Hash: design/gdd/treasures.md 97a87411e8e8b1e2988f8eaf36cd4edbde227cee
Reviewed-Content-Hash: design/gdd/meta-progression.md 43936af8124347bad40ad7d52e1eda53d7ec5fcf
Reviewed-Content-Hash: design/gdd/heroes.md dea1ee1e0afbc53aeace944eac7960f020fc5bbd
Reviewed-Content-Hash: design/gdd/match-rules.md 54e7dae9ecc522fc57787bf4c65313364d74be3f
Reviewed-Content-Hash: design/gdd/rng-event-log.md 43f509f1edb37d0cc3087908330f94dcc24185cb
Reviewed-Content-Hash: design/gdd/run-ui.md d9018ff2729512cf024dd40326853be715a806b4
Reviewed-Content-Hash: design/gdd/card-database.md cd631beb882ec0fa4adb3b048671d05628993c49
Reviewed-Content-Hash: design/gdd/boss-ai.md 346787f0550706b31047cb67b5356266e488440a
Reviewed-Content-Hash: design/gdd/game-concept.md c781025c5f2a71209b4de0976ab806d097b8f0b0
Reviewed-Content-Hash: design/design-decisions.md 7a7fd2f58edfa5bdefa2d9e376b809a4a529615f
Reviewed-Content-Hash: design/gdd/systems-index.md b6cea95eef89f3f0015d0cd1ff03c7189442aceb
Reviewed-Content-Hash: design/gdd/gdd-cross-review-2026-11-03.md c735c9738a373e58a095ba1c942ee89f0de6685a
