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
