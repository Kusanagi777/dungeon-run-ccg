# Review Log — Reward Draft (`design/gdd/reward-draft.md`)

## Review — 2026-11-03 — Verdict: NEEDS REVISION
Review mode: lean · Workflow: standard
Scope signal: L
Specialists: none (lean mode — economy-designer, systems-designer, game-designer, qa-lead, creative-director not spawned)
Blocking items: 2 | Recommended: 7
Summary: Structurally complete (6/6 required at `standard`; Formulas required and present, all eight formulas re-derived by hand against their worked examples) and the pity/coverage/cooling design is implementable, but two contracts with sibling GDDs were broken: treasure *universal* was defined as `tags == []` while Treasures T1/T8 and the registry's 20 treasure items give every treasure exactly one affinity tag (so no treasure would ever be universal and AC-23 fails on the real pool), and the Meta Progression call `is_treasure_unlocked(id)` does not exist (Meta offers `unlocked_ids("treasure")`). Both were resolved in place from the sibling GDDs under guided-mode option [A]. The offer-list name (`option_ids` on `Offer`/`draft_offered` vs `offered_ids` on `DraftRecord`) was first renamed, then restored after a concurrent Run UI revision confirmed `option_ids`; D11 now states the two-name rule and Run Structure R5.3 is flagged. Cross-GDD follow-ups (Treasures F4 odds re-fit under per-item weights, Meta read timing, Run UI stale "exactly 3" row, RNG catalogue payload fields, DD-H05 neutral-bundle count) are recorded in Open Questions. Status after revision: In Review, pending re-review.
Prior verdict resolved: First review
Findings:
- [BLOCKING] Formulas F2 / Detailed Design D7 / Interactions / F6: `universal(t) ⇔ tags(t) == []` contradicts Treasures T1 (exactly one affinity tag) and the registry's treasure items (all carry `universal|war|decay|knowledge`); `universal_forced` could never fire, AC-23 fails on the real pool — FIXED: universal ⇔ `"universal" ∈ tags`, `tags` 1–4, `affine` on plan tags only (as Treasures T6), T8 counts (10 universal / 7 MVP) cited
- [BLOCKING] Interactions / Dependencies / Cross-References / D3: `is_treasure_unlocked(id)` is not an API meta-progression.md defines — FIXED: `unlocked_ids("treasure")` read once at `init_run`; Meta's "at `offer()` time" wording flagged as an amendment
- [RECOMMENDED] Detailed Design D1/D11 vs Run Structure R5.3: `Offer.option_ids` vs `offer(...) → offered_ids[]` — D11 now states the naming rule (`option_ids` on the offer and events, `offered_ids` only as the persisted `DraftRecord` field); Run Structure R5.3 to read `Offer{option_ids[], flags[]}` (cross-GDD)
- [RECOMMENDED] Interactions (Treasures contract): per-item rarity weights give ≈ 26 % rare slots at 11 C / 9 R, not the 30 % of a per-slot roll — Treasures T6 (restated same day) agrees on per-item; its F4 `p_seen` / F1 budgets to be re-fitted at the first balance pass (cross-GDD)
- [RECOMMENDED] Detailed Design D11: Run UI U8 now builds 1–3 options with placeholders and reads no `theme_labels`/`synergy_tags`; its Dependencies row and an Open Questions row still say "exactly 3 ids and optional theme labels"; RNG catalogue `draft_offered`/`draft_picked` rows lack `flags[]` and `option_index` (cross-GDD)
- [RECOMMENDED] Detailed Design D8 / Tuning Knobs: `treasure_short_policy = reoffer` re-offers a declined treasure, contradicting DD-R05 and this GDD's own Treasures-contract rule; default `fewer` honours it — label the knob debug-only or remove (owner)
- [RECOMMENDED] Formulas F2 / Acceptance Criteria: the T10 fixture (6 C / 4 R, 7 plain universals) is not the T8 MVP pool (5 C / 5 R, 7 universals of which 4 rare and 3 War-affine) — relabelled as synthetic; consider a second AC on the real T8 pool
- [RECOMMENDED] Formulas F5/F7, Open Questions: Content CN-4 recommends 12 neutral bundles (B = 20); F7's "uniform picker ≈ 0.50" becomes 0.40 and AC-29's uniform threshold would rest on affinity — recorded; DD-H05 owner decision pending; Content says pity wants ≥ 2 bundles per plan tag where this GDD assumes ~3
- [RECOMMENDED] Acceptance Criteria AC-9: "with any pick policy" was not a test — rewritten to three named policies
- [NICE-TO-HAVE] Edge Cases: "possible from floor 6: 5 taken, 2 cooling" arithmetic — fixed to floor 5 (4 taken + up to 4 cooling)
- [NICE-TO-HAVE] Dependencies / Cross-References: systems-index note and *(planned)* markers were stale — fixed
- [NICE-TO-HAVE] Registry: `bundle_pool_min.output_range [5, 21]` does not span the GDD's own variable ranges (F 3–12, W 0–7 ⇒ 4–27); `collectible_pool_size` and `hero_set_size` list reward-draft.md in `referenced_by` but the GDD does not cite them
Reviewed-Content-Hash: design/gdd/reward-draft.md 0e5e1e7eb5b5938fccfed201ee0752e90d01a7a0
Reviewed-Content-Hash: design/registry/entities.yaml 3364fe83ab25b4e4e9cc1c97bce415b250230dba
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/treasures.md fa73c76396acba6ea9f3a563094b89c4a81fde01
Reviewed-Content-Hash: design/gdd/content.md ba2af38bd3bd5862e2967bd03c55081202282be3
Reviewed-Content-Hash: design/gdd/run-ui.md 40f3ae586d40370209dff143eadf78ad9a6a2f2b
Reviewed-Content-Hash: design/gdd/run-structure.md 3b61401b846ee41676c50c59cdd3b3bd2a0bc7da
Reviewed-Content-Hash: design/gdd/meta-progression.md e1b2d83f2eee16edc639e9093cc89474ca40df94
Reviewed-Content-Hash: design/gdd/heroes.md 05f08a354ba61f99cd5065bb307477be65a81e45
Reviewed-Content-Hash: design/gdd/card-database.md c5903c4c808a0d2b1cf124242ba10a0fb1ea0fef
Reviewed-Content-Hash: design/gdd/rng-event-log.md cb06cb1680292fc0af6b80262894d273f27d1fa8
Reviewed-Content-Hash: design/gdd/game-concept.md 942314097524c7e2f25ad786643fba0a8aa4a701
Reviewed-Content-Hash: design/gdd/systems-index.md 1a5454bb731d1a57ff78d52c6cb98ae3d49598fc
Reviewed-Content-Hash: design/design-decisions.md 96d205e052b6b069575e43201d735fb254843a13

## Follow-up Review — 2026-11-03 — Verdict: NEEDS REVISION
Review mode: lean · Workflow: standard
Scope signal: L
Specialists: none (lean mode — economy-designer, systems-designer, game-designer, qa-lead, creative-director not spawned)
Blocking items: 1 | Recommended: 4
Summary: Re-review after the first-review revisions and the cross-review fixes. C-10 (`unlocked_keys()` at `init_run`, meta M1.3 and Meta's rows agree), C-13 / DD-X06 (`reoffer` debug-only, `E_CONFIG`, AC-11), DD-H05 (B = 20 per hero in D4/F5/F7/Edge Cases/AC-11b/AC-29, `bundle_pool_min` 4–27 matches the registry) and D-02 (`AFFINITY_CAP` 6, F1 range 1–325, AC-20 data-driven proof, rails metric kept) all verify against the cross-review and the sibling GDDs; every formula (F1–F8) was re-derived by hand. One new contradiction with an owning GDD: Heroes H-4 / F2 (cross-review C-03, option B) count the War starter at 7 plan cards because `war_iron_vanguard` carries Content's `armour` tag, while this GDD's F1 worked example, AC-20, F3 example, F7, F8 and Cross-References still used `armour` × 1 and 6/15 — AC-20 would fail against the real starter. Fixed in place under guided-mode option [A] (armour bundle 150, total 675, `plan_share(8) = (7 + 3k)/36`, uniform baseline 0.43). Status after revision: In Review, pending re-review; registry `bundle_weight.output_range` needs 390 → 325.
Prior verdict resolved: Yes
Findings:
- [BLOCKING] Formulas F1 / Acceptance Criteria AC-20 / F3 / F7 / F8 / Cross-References: War starter counted `armour` × 1 and 6/15 plan cards; Heroes H-4 / F2 now count 7 (`war_iron_vanguard` tagged `armour`) — FIXED: `bundle_war_armour` 150, total 675, odds 26.7 / 25.9 / 22.2 / 14.8 / 10.4 %, AC-20 180/175/150/100/70, F3 `3 vs 2 vs 2`, F7 `(7 + 3k)/36` with uniform baseline 0.43 (AC-29, Tuning Knobs `AFFINITY_STEP`), F8 4.7 plan cards at floor 1
- [RECOMMENDED] Registry: `bundle_weight.output_range [1, 390]` predates D-02 — GDD F1 now tops out at 325 (`100 × 2.5 × 1.30`); registry correction for the orchestrator
- [RECOMMENDED] Open Questions (D-02): the cross-review said "no GDD change now — measure first"; the GDD lowered `AFFINITY_CAP` 8 → 6 and kept the ~70 % metric, noting the owner may restore 8 — owner to confirm the pre-emptive lowering
- [RECOMMENDED] Cross-GDD (not this GDD): rng-event-log catalogue L173 flag vocabulary `coverage` vs this GDD's `coverage_forced`, and it omits `universal_missing` / `reoffer`; rng-event-log L63/L228/L462 still say "pity rolls" (pity is draw-free, F3); card-database `bundle_pool_size` "14 at v1" predates DD-H05 (20); content L456 "`n_universal` 7 ≥ Reward Draft's 5" predates the F6 one-rule (hard 3 / recommended 7)
- [RECOMMENDED] Open Questions: Content's Alpha-B question (does pity need ≥ 2 bundles per plan tag?) was assigned to Reward Draft and unanswered — answered in place (no hard requirement; pity never invents a bundle; ≥ 2 keeps the rule live after the first pick)
- [NICE-TO-HAVE] Dependencies: the "design-order list names only four of six" note was stale (systems-index item 4 lists all six) — fixed
- [NICE-TO-HAVE] Open Questions: "concept says first treasure on floor 2" — concept now cites DD-R05 (floor 1) — marked Resolved
Reviewed-Content-Hash: design/gdd/reward-draft.md fefe17c210dcc4fb1bd265441cf2355d0eb202e9
Reviewed-Content-Hash: design/registry/entities.yaml c0b7b1c0ad84e2c548b1bb890c79073e397c259c
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/treasures.md 97a87411e8e8b1e2988f8eaf36cd4edbde227cee
Reviewed-Content-Hash: design/gdd/content.md 9a4fabbfd9e515a5dd437ed7babbe949119da8ee
Reviewed-Content-Hash: design/gdd/run-ui.md d9018ff2729512cf024dd40326853be715a806b4
Reviewed-Content-Hash: design/gdd/run-structure.md 1485f9df6fb25ee9514c6a88385e8f88704f7603
Reviewed-Content-Hash: design/gdd/meta-progression.md 43936af8124347bad40ad7d52e1eda53d7ec5fcf
Reviewed-Content-Hash: design/gdd/heroes.md 2c76cf8115794dbf939f51317884d278d4561656
Reviewed-Content-Hash: design/gdd/card-database.md bf374f0a4c79940fe414c216246ea3cca7f195db
Reviewed-Content-Hash: design/gdd/rng-event-log.md dc7474f4995cf1741e5617c0b5938f18eee5fcc4
Reviewed-Content-Hash: design/gdd/game-concept.md c781025c5f2a71209b4de0976ab806d097b8f0b0
Reviewed-Content-Hash: design/gdd/systems-index.md b6cea95eef89f3f0015d0cd1ff03c7189442aceb
Reviewed-Content-Hash: design/design-decisions.md 6d7e7fac963fc62e7ff90a531df77e23e2eb0488
Reviewed-Content-Hash: design/gdd/gdd-cross-review-2026-11-03.md c735c9738a373e58a095ba1c942ee89f0de6685a

## Review — 2026-11-03 — Verdict: APPROVED
Review mode: lean · Workflow: standard
Scope signal: L
Specialists: none (lean mode — economy-designer, systems-designer, game-designer, qa-lead, creative-director not spawned)
Blocking items: 0 | Recommended: 3
Summary: Final re-review after the in-place PLAN_MAX-7 fix. The receipt check showed the GDD byte-identical to the last stamp with the registry and nine sibling files changed, so a full pass was run rather than a delta: structure 6/6 required at `standard` (Formulas required and present), all eight formulas and their worked examples re-derived by hand (F1 cap 325 = 100 × 2.5 × 1.30, floor-1 weights 180/175/150/100/70 → 675, floor-7 250/130 and 300 at cap 8; F2 370 → 24 %, 555 → 46 %; F5 B_min 4–27 and the 20/17/14/13/12/11/10 series; F6 10/7/4; F7 (7 + 3k)/36 → 0.43 uniform baseline; F8 1330/7140) and every registry value this GDD restates matches the registry (`bundle_weight` [1, 325], `bundle_pool_min` [4, 27], `treasure_weight` [30, 105], `floors_per_run` 8, `treasure_floors` 1/3/5, `starter_deck_size` 15, `bundle_card_count` 3, `min_treasure_pool` 9, `pity_window` 2, `reoffer_after_floors` 2, `treasure_rarity_weights` 70/30, `offers_per_draft` 3). Contracts verified both ways: Treasures T6/T8 (per-item weights, `unlocked_keys` predicate, 11 C / 9 R, 10 universal, MVP 5 C / 5 R with 7 universal of which 4 rare and 3 War-affine), Heroes H-4/F2 (War 7 plan cards), Run Structure R1/R2.5/R5.3/R5.7, Run UI U8, Meta M1.3, RNG catalogue (flags[] and option_index now present), Card Database CR-6 / `bundle_pool_size` 20 at v1. One housekeeping edit under the revise-now rule: the T6 call is now `pool(unlocked_keys, exclude_ids)` in all three places (treasures.md unified the signature the same day). `AFFINITY_CAP = 6` stands as a designer default. All eight declared dependencies exist on disk. Recommend systems-index status Approved.
Prior verdict resolved: Yes
Findings:
- [RECOMMENDED] Interactions / Dependencies / Open Questions: `Treasures.pool(is_unlocked, exclude_ids)` in three places while treasures.md T6, meta-progression M1.3 and Treasures AC-11/12 write `pool(unlocked_keys, exclude_ids)` — FIXED in place (housekeeping; the Dependencies row's "we never call it" now reads "beyond that pool predicate we never call it")
- [RECOMMENDED] Cross-GDD (not this GDD): rng-event-log L65 / L238 / L474 still say "pity rolls" (pity is draw-free, F3); content.md Open Questions L910 still marks the Alpha-B "≥ 2 bundles per plan tag" question Open though this GDD answered it on 2026-11-03
- [RECOMMENDED] Tuning Knobs: the row names two knobs `bundle_offers_per_draft` / `treasure_offers_per_draft` (3 / 3) where the registry carries one entry `offers_per_draft` = 3 covering both — values agree; align the knob name with the registry entry when `reward_draft.json` is authored, or register the second name
- [NICE-TO-HAVE] Status header: the first REVISED note's "Treasures' `pool()` declared unused" is history superseded by the cross-review note; harmless, left as a record
Reviewed-Content-Hash: design/gdd/reward-draft.md a7efa9bae59c93827f73ff208438d3131a6de8bb
Reviewed-Content-Hash: design/registry/entities.yaml 76f479bf5a4270db81c0d82a5eb86ee4c5c9e227
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/treasures.md b50806cc8b2b5117b0064b934122be5ecaced4ad
Reviewed-Content-Hash: design/gdd/content.md dc95b8e96ca465d68b1835307341807ef8ffe3a8
Reviewed-Content-Hash: design/gdd/run-ui.md b97595084d05aabfe872316243343bf85c3f45d0
Reviewed-Content-Hash: design/gdd/run-structure.md f89d6a98f6981671324f9a0c49708df0d1847787
Reviewed-Content-Hash: design/gdd/meta-progression.md 878962538feb2a76598643d4ce90adc4f436ba55
Reviewed-Content-Hash: design/gdd/heroes.md 3e9c89b4cd87b8fde225762af7e169fcf2fed1dd
Reviewed-Content-Hash: design/gdd/card-database.md d04095c7f44e5d930ba3c23c4f88024736fdc6a8
Reviewed-Content-Hash: design/gdd/rng-event-log.md 6981bf37934cae2e74ed37a23eb349fb62dcbf5b
Reviewed-Content-Hash: design/gdd/game-concept.md 0c2c930dd6bdaa11592472e2051d801911f4ded1
Reviewed-Content-Hash: design/gdd/systems-index.md a20a2191f2853e48591ac1eec0417f089077f7c6
Reviewed-Content-Hash: design/design-decisions.md 914fb4ab3d19c6957bf65dcff93bb6804f664708
Reviewed-Content-Hash: design/gdd/gdd-cross-review-2026-11-03.md c735c9738a373e58a095ba1c942ee89f0de6685a
