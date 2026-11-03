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
