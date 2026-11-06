# Review log — design/gdd/content.md

## Review — 2026-11-03 — Verdict: NEEDS REVISION
Review mode: lean · Workflow: standard
Scope signal: XL
Specialists: none (lean mode — no specialist agents spawned; main-review AC check only)
Blocking items: 4 | Recommended: 7
Summary: Structurally complete (8/8 present, 6/6 required at `standard` incl. Formulas) and the card, boss and bundle tables are internally consistent (all counts, curves, shares, bundle tags/sets/bands and 52/56 hero-set coverage recomputed and confirmed; 10 card rows and all 4 MVP bosses verified against card-effects C2/C3/C5/C11 and no v2 pattern used). Blocking: CN-5 described a 5/5/5/5 treasure split and a "5 generic + 5 War" MVP that the Treasures GDD's authoritative T8 table contradicts (10/4/3/3; MVP = 7 universal + 2 War + 1 Knowledge); CN-6 MVP-0 shipped `heroes.json` with three heroes whose starter cards are Alpha records, so the batch's own "loads clean" gate fails on CR-5 `E_UNKNOWN_REF`; `power_mend` and `neutral_sheep` were batched before any record referenced them (orphans, data-files rule / AC-16); two arithmetic slips (F3 Kingsblade budget, F5 op count). All four resolved in session from the Treasures GDD, DD-H06 and Card Database CR-1/CR-5 without an owner decision; status is now In Review pending re-review.
Prior verdict resolved: First review
Findings:
- [BLOCKING] CN-5 Treasure plan: split and MVP set contradicted Treasures T8 (fixed — ids named per batch, 10/12/16/20 cumulative)
- [BLOCKING] CN-6 Production pipeline: MVP-0 `heroes.json` with 3 heroes cannot load clean (fixed — `hero_war` / `power_whetstone` only at MVP-0 per DD-H06; Decay/Knowledge HeroDefs with their set batches)
- [BLOCKING] CN-1 / CN-6: `power_mend` at MVP-0 and `neutral_sheep` at MVP referenced by nothing (fixed — VS / Alpha-B; token and hero-power rows rewritten; AC-20 rescoped)
- [BLOCKING] Formulas F3 / F5: Kingsblade weapon budget 13 → 14; "26 of 26" ops → 25 of 25 (fixed)
- [RECOMMENDED] CN-3 B2: Rot Warden MVP recipe was unparseable ("2× `boss_rot_zombie` ×3") — rewritten to an explicit 30
- [RECOMMENDED] CN-2 / CN-3: `tag` filter on board minions (card-effects C3 lists cards/pools only) used by `boss_rat_matriarch` (MVP), `decay_husk_herder`, `decay_plague_of_rot` — Open Question added with MVP fallback (card-effects R-3)
- [RECOMMENDED] CN-3: boss passives on `on_minion_died` / `on_play` / `on_attack` have no hook column; Rot Warden (MVP) depends on Treasures T2.5 observer reading — Open Question added with fallback (card-effects R-10)
- [RECOMMENDED] CN-2: `neutral_gravekeeper` reads a counter inside its own Deathrattle while C5 says counters die with the source — Open Question added
- [RECOMMENDED] Acceptance Criteria: AC-13 basis (player targets vs Boss AI's proposed script-relative targets) — Open Question added; unnumbered AC numbered AC-21 with a grep-testable form
- [RECOMMENDED] Pipeline vs `.claude/rules/data-files.md`: `content_budgets.json` has no documented schema (only a constants list across F1–F6) — add a key list / JSON Schema sketch before the MVP-1 validator story
- [RECOMMENDED] Formulas F4: `T` model 10/10/11 per band vs Run Structure F7 (floor 8 = 10, floor 3 = 9) — state it is a band mean
Reviewed-Content-Hash: design/gdd/content.md ba2af38bd3bd5862e2967bd03c55081202282be3
Reviewed-Content-Hash: design/registry/entities.yaml 3364fe83ab25b4e4e9cc1c97bce415b250230dba
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/card-effects.md c9482cdffa200bd8c594b2c9a5185eda26c8f271
Reviewed-Content-Hash: design/gdd/treasures.md fa73c76396acba6ea9f3a563094b89c4a81fde01
Reviewed-Content-Hash: design/gdd/heroes.md 9447c45a9301eeb101f3b70de2966cec4603471b
Reviewed-Content-Hash: design/gdd/card-database.md c5903c4c808a0d2b1cf124242ba10a0fb1ea0fef
Reviewed-Content-Hash: design/gdd/boss-ai.md 58e8011f3ad5605ab42d95e56229c291c3de9775
Reviewed-Content-Hash: design/gdd/run-structure.md 3b61401b846ee41676c50c59cdd3b3bd2a0bc7da
Reviewed-Content-Hash: design/gdd/match-rules.md 4c45bb5b36e1b50b3b286a2f10ea13cd0b703eae
Reviewed-Content-Hash: design/gdd/reward-draft.md 40e87d43e0dd3bb8e64a161bfb36ba3d17afe7d0
Reviewed-Content-Hash: design/gdd/game-concept.md 942314097524c7e2f25ad786643fba0a8aa4a701
Reviewed-Content-Hash: design/design-decisions.md 96d205e052b6b069575e43201d735fb254843a13

## Follow-up Review — 2026-11-03 — Verdict: NEEDS REVISION
Review mode: lean · Workflow: standard
Scope signal: XL
Specialists: none (lean mode — no specialist agents spawned; main-review AC check only)
Blocking items: 2 | Recommended: 4
Summary: Re-review after the first-review revisions and the cross-review fixes. Everything the prior pass and the cross-review touched verified clean: 6/6 required sections at `standard` (8/8 present); all 16 boss rows match the registry (band, health, passive, hero power); CN-5's 20 treasure ids, affinities, rarities, unlock flags and the 10 MVP ids match Treasures T8 and the registry; 36 bundles recomputed (tags, sets, batch ≤ card batch, band averages, 52/56 hero and 34/39 neutral coverage); C-03 B (`armour` tag kept, PLAN_MAX 7), C-23, C-24, D-04, D-06 (5 = 3/1/1 everywhere), D-07 and DD-H05 wording consistent; F3/F5/F6 arithmetic re-done; 12 card rows and the 5 MVP bosses plus their 10 boss cards checked against card-effects C2/C3/C5/C9/C11 (no v2 pattern). Two new blockers, both the same class the first review caught: five boss deck recipes named cards from a later batch than the boss (AC-10 / "loads clean" unsatisfiable), and F5/AC-7/CN-2 still gate coverage on "provisional" ops after card-effects de-provisionalised them (C-22). Both resolved in session without an owner decision; status is In Review pending re-review.
Prior verdict resolved: Yes
Findings:
- [BLOCKING] CN-3 B2 / Edge Cases: Hollow King (MVP-1) recipe named VS neutrals; Lich Archivist (VS) and Frost Hag (Alpha-A) named Knowledge cards (Alpha-B); Bog Witch and Shadow of the Delve (Alpha-A) named `neutral_ember_sprite` (Alpha-B); the hero-set ordering sentence had `pyre_sergeant` / `lich_archivist` reversed (fixed — explicit same-batch recipes totalling 30, swap-in batch named, Edge Cases lists every fallback case)
- [BLOCKING] Formulas F5 / AC-7 / CN-2 / CN-5 / Cross-References: coverage excluded "provisional" ops, but card-effects C5/C10 made `remove_keyword`, `shuffle_into_deck`, `discard`, `weapon_durability`, `hero_power_refresh` full v1 ops on 2026-11-03, so `op_coverage = 1.0` at Alpha was undecidable and the `war_quartermaster` rationale false (fixed — explicit `OPS_EXEMPT` / `coverage.ops_exempt`, `W_COVERAGE_UNUSED`, rationale restated)
- [RECOMMENDED] Open Questions: `war_pit_champion` hero-Windfury question was already answered by Match Rules C1/F3 (resolved in session)
- [RECOMMENDED] CN-6 step 2: `content_budgets.json` `curve.bucket` used `"6+"` as a key — not snake_case per `.claude/rules/data-files.md` (fixed — array like `pressure.band`)
- [RECOMMENDED] Cross-GDD (not edited): design-decisions.md DD-H06 still reads "4 bosses"; Run Structure F2 table and its open "spare band-1 boss" question still read 2/1/1 pools — both superseded by D-06; card-effects C5 `mana` row says `this_turn` is unused by v1 content, but `decay_soul_tithe` and `neutral_treasure_map` use it
- [RECOMMENDED] CN-4 / AC-15: `neutral_tunnel_rat` was omitted from the starters-in-neutral-bundles note; AC-15's parenthetical conflated theme counts with band counts (both fixed)
Reviewed-Content-Hash: design/gdd/content.md 0ebdda3190f417e6ae20c6444b24daed4e75bf2d
Reviewed-Content-Hash: design/registry/entities.yaml c0b7b1c0ad84e2c548b1bb890c79073e397c259c
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/card-effects.md 0a434c1bcf30900536181fc057877a04832c766e
Reviewed-Content-Hash: design/gdd/treasures.md 97a87411e8e8b1e2988f8eaf36cd4edbde227cee
Reviewed-Content-Hash: design/gdd/heroes.md 2c76cf8115794dbf939f51317884d278d4561656
Reviewed-Content-Hash: design/gdd/card-database.md bf374f0a4c79940fe414c216246ea3cca7f195db
Reviewed-Content-Hash: design/gdd/boss-ai.md 346787f0550706b31047cb67b5356266e488440a
Reviewed-Content-Hash: design/gdd/run-structure.md 1485f9df6fb25ee9514c6a88385e8f88704f7603
Reviewed-Content-Hash: design/gdd/match-rules.md 54e7dae9ecc522fc57787bf4c65313364d74be3f
Reviewed-Content-Hash: design/gdd/reward-draft.md fefe17c210dcc4fb1bd265441cf2355d0eb202e9
Reviewed-Content-Hash: design/gdd/game-concept.md c781025c5f2a71209b4de0976ab806d097b8f0b0
Reviewed-Content-Hash: design/design-decisions.md 6d7e7fac963fc62e7ff90a531df77e23e2eb0488
Reviewed-Content-Hash: .claude/rules/data-files.md d73a823d8bcb94cb974e0f6ada9b4fceda733724

## Review — 2026-11-03 — Verdict: APPROVED
Review mode: lean · Workflow: standard
Scope signal: XL
Specialists: none (lean mode — no specialist agents spawned; main-review AC check only)
Blocking items: 0 | Recommended: 3
Summary: Final pass after the second re-review's in-session fixes and the cross-GDD housekeeping commit. Both prior blockers hold: every B2 fallback recipe (Rat King, Gatekeeper, Torchbearer, Rot Warden, Hollow King at MVP-1; Lich Archivist at VS; Frost Hag at Alpha-A) totals 30 ids drawn only from the boss's batch or earlier, and F5 / AC-7 / CN-2 / CN-5 use the explicit `OPS_EXEMPT` set with no "provisional" language left. The cross-GDD items the last entry raised are now closed upstream and the GDD agrees with each: DD-H06 reads 5 MVP bosses (3 / 1 / 1), Run Structure F2 / Interactions / Dependencies read 3/1/1 and its spare-boss OQ is resolved, Match Rules C5 defines temporary mana for `decay_soul_tithe` / `neutral_treasure_map`, Heroes keeps `W_HERO_HEALTH` and CN-6 step 3 lists it. Registry recheck clean: all 16 boss rows (band, health, hero power) and all 20 treasure rows (affinity, rarity, unlock, the 10 MVP ids) match CN-3 / CN-5 and Treasures T8; `hero_set_size`, `boss_starting_health_by_band`, `starting_hand_boss`, `min_treasure_pool`, `data_load_budget_ms`, `target_win_rate_by_floor` as restated. Six of six required sections at `standard` (8/8 present); every AC is GIVEN/WHEN/THEN with a measurable THEN. Three housekeeping notes remain, none blocking.
Prior verdict resolved: Yes
Findings:
- [RECOMMENDED] CN-3 (MVP bosses paragraph, lines 384–385): "DD-H06 still reads '4 bosses' … should be amended" is stale — DD-H06 was amended to 5 (3 / 1 / 1) on 2026-11-03; delete the two sentences
- [RECOMMENDED] Open Questions: the `discover`-tag pity question (row "Knowledge's `discover` tag has one bundle") is marked Open but Reward Draft answered it on 2026-11-03 (no hard ≥ 2 requirement; pity never invents a bundle; `pity_forced` rate is the evidence) — mark resolved
- [RECOMMENDED] Cross-GDD (not edited): card-effects C5 `mana` row and its Open Question still say match-rules C5 "does not use / should state" the temporary case; Match Rules C5 now defines it — card-effects housekeeping, no Content change
Reviewed-Content-Hash: design/gdd/content.md dc95b8e96ca465d68b1835307341807ef8ffe3a8
Reviewed-Content-Hash: design/registry/entities.yaml 76f479bf5a4270db81c0d82a5eb86ee4c5c9e227
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/card-effects.md 0a434c1bcf30900536181fc057877a04832c766e
Reviewed-Content-Hash: design/gdd/treasures.md b50806cc8b2b5117b0064b934122be5ecaced4ad
Reviewed-Content-Hash: design/gdd/heroes.md 3e9c89b4cd87b8fde225762af7e169fcf2fed1dd
Reviewed-Content-Hash: design/gdd/card-database.md d04095c7f44e5d930ba3c23c4f88024736fdc6a8
Reviewed-Content-Hash: design/gdd/boss-ai.md 2c2bedbaa6ff558777d2af7d81b3b91c5783af82
Reviewed-Content-Hash: design/gdd/run-structure.md f89d6a98f6981671324f9a0c49708df0d1847787
Reviewed-Content-Hash: design/gdd/match-rules.md 7af4351b32a419195d38bf274c2a68b9c63aa804
Reviewed-Content-Hash: design/gdd/reward-draft.md a7efa9bae59c93827f73ff208438d3131a6de8bb
Reviewed-Content-Hash: design/gdd/game-concept.md e2b0c05d2b9729099fdcc47c9c96c7ef6724e61f
Reviewed-Content-Hash: design/design-decisions.md 914fb4ab3d19c6957bf65dcff93bb6804f664708
Reviewed-Content-Hash: .claude/rules/data-files.md d73a823d8bcb94cb974e0f6ada9b4fceda733724
