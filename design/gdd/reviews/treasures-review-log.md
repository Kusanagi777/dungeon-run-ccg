# Review Log — Treasures (`design/gdd/treasures.md`)

## Review — 2026-11-03 — Verdict: NEEDS REVISION
Review mode: lean · Workflow: standard
Scope signal: L
Specialists: none (lean — single-session analysis; fresh independent reviewer, not the author)
Blocking items: 6 | Recommended: 9
Summary: Structurally complete (8/8 present, 6/6 required at standard) and unusually implementable — the hook chain, fold/clamp semantics and 20-record pool are precise and every cross-system primitive it needs is logged as a request (R-1..R-13 verified as requests, none assumed). The blockers were contract drift against sibling GDDs that were "planned" when this was written and are now designed: T6 described a Reward Draft pool query that reward-draft.md does not make (`draft_state.offered_treasure_ids` is superseded, the pool is snapshotted at `init_run`, weights are per-item), the Dependencies section said five partners had no GDD, an affinity tally was wrong, and R-8 was already resolved in DD-T01. Those were fixed in session. The unlock-key mismatch with meta-progression (six placeholder ids vs this pool's four) is a meta-progression/registry change, not a Treasures change — its own M2.1 already accepts this GDD's four keys; owner still picks 4-vs-6 and the milestone mapping.
Prior verdict resolved: First review
Findings:
- [BLOCKING] Detailed Design T6: pool contract stale vs reward-draft D3/D7/F2 (`offered_treasure_ids` superseded; snapshot timing; per-slot vs per-item weights) — FIXED (T6 rewritten, Edge Cases and Cross-References aligned)
- [BLOCKING] Detailed Design T8: affinity tally "11 universal / 2 knowledge" was 10 / 3 — FIXED
- [BLOCKING] Dependencies: "Reward Draft, Meta Progression, Match UI, Run UI and Content have no GDD yet" — all exist; bidirectionality re-verified — FIXED
- [BLOCKING] Open Questions R-8 / Formulas intro: `treasures_balance.json` already in DD-T01 — FIXED (closed)
- [BLOCKING] Detailed Design T8 / Open Questions R-14: unlock keys vs meta-progression M10 and registry `unlock_keys_v1` (six placeholder ids, `lich_grimoire` keyed off nonexistent `treasure_second_wind`) — CROSS-GDD: meta-progression M10 + registry change; owner decides 4 vs 6 and milestone mapping; R-14 updated to say so
- [BLOCKING] Open Questions R-16 (new): reward-draft tests `tags == []` for universal; this GDD never emits `[]` (explicit `universal` tag, `E_TR_TAGS`) — universal slot would fail every draft — CROSS-GDD: Reward Draft to test `"universal" ∈ tags`
- [RECOMMENDED] Acceptance Criteria AC-13: accepted either of two outcomes — FIXED (one assertion per match-rules version)
- [RECOMMENDED] Acceptance Criteria AC-14: "reference machine" undefined — FIXED (ratio ≤ 1.05×, median of 5, no-allocation check)
- [RECOMMENDED] Acceptance Criteria AC-17: asserts R-13's answer before Card Effects gives it — FIXED (dependency stated)
- [RECOMMENDED] Open Questions R-10: `once_per_turn` keyed on `source entity_id` (card-effects C6.7) but treasures have none — FIXED (key `host_id` requested)
- [RECOMMENDED] Open Questions R-17 (new): `unlock` field `string` (T1, CR-3) vs `{key, condition}` (meta-progression CR-3 amendment) — cross-GDD / owner
- [RECOMMENDED] Open Questions R-18 (new): three names for the unlock-state interface (`unlocked_keys` / `is_treasure_unlocked(id)` / `unlocked_ids("treasure")`) — cross-GDD
- [RECOMMENDED] Open Questions R-19 (new): Run UI `synergy_tags[]` vs `tags` — Run UI to rename
- [RECOMMENDED] Open Questions R-20 (new): Content CN-5 expects 5/5/5/5 split and "5 generic + 5 War" MVP; T8 is 10/4/3/3 — Content to update unless owner wants more hero-affine treasures
- [RECOMMENDED] Open Questions R-1: Hollow Crown is MVP yet waits on an open Match Rules primitive (`add_mana` permanent; match-rules C5 says "no crystal gain in v1") — resolve before the MVP treasure stories, fallback text already recorded
- [NICE-TO-HAVE] Registry: `treasure_offers_per_run.output_range` is `[9, 9]`; GDD gives 6 at MVP — widen to `[6, 9]`
- [NICE-TO-HAVE] systems-index.md: Content row says "8 treasures" at MVP (line 85) vs DD-H06's 10; Treasures "Depends On" should add Match Rules and Heroes
Reviewed-Content-Hash: design/gdd/treasures.md fa73c76396acba6ea9f3a563094b89c4a81fde01
Reviewed-Content-Hash: design/registry/entities.yaml 3364fe83ab25b4e4e9cc1c97bce415b250230dba
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/match-rules.md bb4bfe29a4dffb9a7638e040f60249b3baa6919d
Reviewed-Content-Hash: design/gdd/card-effects.md 06d1a1c86d2da73767a5865e64187943b8849dd6
Reviewed-Content-Hash: design/gdd/run-structure.md 3b61401b846ee41676c50c59cdd3b3bd2a0bc7da
Reviewed-Content-Hash: design/gdd/card-database.md c5903c4c808a0d2b1cf124242ba10a0fb1ea0fef
Reviewed-Content-Hash: design/gdd/reward-draft.md 40e87d43e0dd3bb8e64a161bfb36ba3d17afe7d0
Reviewed-Content-Hash: design/gdd/meta-progression.md e1b2d83f2eee16edc639e9093cc89474ca40df94
Reviewed-Content-Hash: design/gdd/heroes.md 50129f93679a9dfa2153049499b8c646a476d1f9
Reviewed-Content-Hash: design/gdd/rng-event-log.md cb06cb1680292fc0af6b80262894d273f27d1fa8
Reviewed-Content-Hash: design/gdd/boss-ai.md 494058ed4e0f53de4a41b7e5613c86537dd01d71
Reviewed-Content-Hash: design/gdd/match-ui.md 6645f862cbd413853a0afdec2f3ccf775e811547
Reviewed-Content-Hash: design/gdd/run-ui.md 264fec3bca820fde7c3469324043570d25267e5c
Reviewed-Content-Hash: design/gdd/content.md 3e5e568fada0126b6e7f2685c4afe86211dca3e6
Reviewed-Content-Hash: design/gdd/game-concept.md 942314097524c7e2f25ad786643fba0a8aa4a701
Reviewed-Content-Hash: design/gdd/systems-index.md 1a5454bb731d1a57ff78d52c6cb98ae3d49598fc
Reviewed-Content-Hash: design/design-decisions.md 96d205e052b6b069575e43201d735fb254843a13
