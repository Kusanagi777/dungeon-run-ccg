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

## Review — 2026-11-03 — Verdict: APPROVED
Review mode: lean · Workflow: standard
Scope signal: L
Specialists: none (lean — single-session analysis; fresh independent reviewer, not the author; re-review after first-review revisions and cross-review fixes C-02, C-06, C-19, C-26, C-30)
Blocking items: 0 | Recommended: 3
Summary: Every blocker from the first review and every cross-review item assigned to this GDD is now carried by the document and confirmed on the partner side: Hollow Crown rides match-rules `crystal_bonus` (C1 PlayerState, C4 Start step 2, C5, F4, AC-06) and card-effects' `mana` op row; T1 `unlock` is the DD-X01 `{key, condition}` object; the four unlock keys are defined in meta M10 and registry `unlock_keys_v1`; the hook-table clamps (`modify_heal` floor, `[0, HAND_SIZE]`, `[0, MAX_ATTACKS_CAP = 4]`), C1 per-fold-call conditions, C3 `tag` on board minions, C9 hero-slot observers, C2 `kind` semantics and `aura` on `owner_weapon` all exist where the Open Questions say they do. The whole-document registry search (103 lines) found no value conflict: all 20 treasure rarities, tags, power estimates and MVP flags match the registry, as do 70/30, `[1, 3, 5]`, `min_treasure_pool` 9, `[6, 9]` offers, bands, `MAX_EFFECTS_PER_TREASURE` 3, `decay_husk` 1/1 and `war_whetstone_blade` 1/2. D-01 and D-03 assign no change here (D-03 is an open Content/Meta owner choice). Three small wording items remain, none blocking.
Prior verdict resolved: Yes — NEEDS REVISION (2026-11-03, first review): all six blockers resolved (four in session, two via cross-GDD changes in meta-progression M10 / registry `unlock_keys_v1` and reward-draft F2)
Findings:
- [RECOMMENDED] Detailed Design T6: signature written `Treasures.pool(is_unlocked, exclude_ids)` while Interactions, Dependencies, AC-11/AC-12 and meta M1.3 write `pool(unlocked_keys, exclude_ids)` — one parameter name (the set)
- [RECOMMENDED] Dependencies: sentence "Match UI, Run UI and Card Effects still mark their rows 'undesigned / provisional'" is stale — match-ui Cross-References were corrected by cross-review C-30 and card-effects/run-ui carry no such marker; drop it on the next edit
- [RECOMMENDED] Acceptance Criteria AC-14: the no-allocation check names Godot `Performance.OBJECT_COUNT` / `MEMORY_STATIC` — NOT SOURCEABLE in `docs/engine-reference/godot/` (no monitor list is pinned); the test author verifies the monitor names against the installed 4.7.2 editor before writing the test (test detail, not a design rule)
- [NICE-TO-HAVE] Open Questions: last row (rarity-weight ownership) is the only row still Open — owner decision, no effect on implementability; cross-review D-01 (Crown/Banner pick-rate watch via `/balance-check`) and D-03 (a fifth any-hero unlock) stay with the owner
Reviewed-Content-Hash: design/gdd/treasures.md 97a87411e8e8b1e2988f8eaf36cd4edbde227cee
Reviewed-Content-Hash: design/registry/entities.yaml 1ee18bfb98f9c2349140eda37142a0e93a335c11
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/match-rules.md 54e7dae9ecc522fc57787bf4c65313364d74be3f
Reviewed-Content-Hash: design/gdd/card-effects.md 90b8b6e139e107e5a588cd760da49b3946a404bc
Reviewed-Content-Hash: design/gdd/run-structure.md 1485f9df6fb25ee9514c6a88385e8f88704f7603
Reviewed-Content-Hash: design/gdd/card-database.md cd631beb882ec0fa4adb3b048671d05628993c49
Reviewed-Content-Hash: design/gdd/reward-draft.md 46e985b9b2915a99fd6a9d039ba420634cb0489b
Reviewed-Content-Hash: design/gdd/meta-progression.md 43936af8124347bad40ad7d52e1eda53d7ec5fcf
Reviewed-Content-Hash: design/gdd/heroes.md dea1ee1e0afbc53aeace944eac7960f020fc5bbd
Reviewed-Content-Hash: design/gdd/rng-event-log.md 43f509f1edb37d0cc3087908330f94dcc24185cb
Reviewed-Content-Hash: design/gdd/boss-ai.md 346787f0550706b31047cb67b5356266e488440a
Reviewed-Content-Hash: design/gdd/match-ui.md dbff3a5d072d175f5f8fe406ad9f2258df31077d
Reviewed-Content-Hash: design/gdd/run-ui.md d9018ff2729512cf024dd40326853be715a806b4
Reviewed-Content-Hash: design/gdd/content.md 9a4fabbfd9e515a5dd437ed7babbe949119da8ee
Reviewed-Content-Hash: design/gdd/game-concept.md c781025c5f2a71209b4de0976ab806d097b8f0b0
Reviewed-Content-Hash: design/gdd/systems-index.md b6cea95eef89f3f0015d0cd1ff03c7189442aceb
Reviewed-Content-Hash: design/design-decisions.md 7a7fd2f58edfa5bdefa2d9e376b809a4a529615f
Reviewed-Content-Hash: design/gdd/gdd-cross-review-2026-11-03.md c735c9738a373e58a095ba1c942ee89f0de6685a
