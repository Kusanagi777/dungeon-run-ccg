## Smoke Record — content story 005 (MVP-1: the 10 MVP bundles)
**Date**: 2026-11-04
**Story**: `production/epics/content/story-005-mvp-1-bundles.md` (Config/Data)
**Engine**: Godot 4.7.2 (`4.7.2.stable.official.ed1daf0bf`, editor binary = debug build)
**QA Plan**: `production/qa/qa-plan-sprint-004-2026-11-04.md`; this record works from the story's acceptance criteria.
**Run by**: sprint-4 lane 5 wave 2 `lane/s4-l5-w2` (owner's standing approval), on trunk `c9cd55b` (merge: sprint 4 L5). Per-story Config/Data record, not the sprint's `/smoke-check` report.

### What changed

| File | Change |
|---|---|
| `bundles.json` | +7 BundleDefs, verbatim from CN-4: `bundle_war_weapons_1` Whetted Steel, `bundle_war_weapons_2` Armoury, `bundle_war_weapons_3` Kingsguard, `bundle_war_aggro_1` First Blood, `bundle_war_aggro_2` The Pit, `bundle_war_aggro_3` Warband, `bundle_war_armour_2` Bulwark. Each: `unlock` null, `text` `{key: bundle.<id>.text, en: <one-line pitch>}`. The three batch-0 bundles are unchanged. |
| `card_database.json` | **unchanged**: `min_bundle_pool` is already 10, which is ≥ 9 (see AC-3). |

### Content validate command on the shipped data

`godot --headless --path . -s res://tools/content/validate.gd` (editor binary, debug) → **exit 0**.

| | Before (trunk `c9cd55b`) | After |
|---|---|---|
| State | `Ready` | `Ready` |
| Errors | 0 | **0** |
| Warnings (all / content checks F1–F5) | 53 / 44 | **51 / 43** |
| Records | 55 | **62** (+7 BundleDefs) |
| `W_POOL_SIZE` | 2 (bundle pool for war 3 < 10; treasure 0 < 6) | **1**: only the treasure row is left (story 006) |
| Load ms (observation, never asserted; budget 200) | 14.99 | 19.43 |

The two rows that went away (diff of the sorted warning lines):

```
< [warning] W_COVERAGE bundles.json.coverage.bundle_coverage_min.war — war bundle_coverage 0.06 (1 / 18 non-starter cards in a bundle) under 0.9 (F5)
< [warning] W_POOL_SIZE bundles.json.min_bundle_pool — bundle pool for war: 3 < 10 (n_bundles(war) + n_bundles(neutral) vs min_bundle_pool)
```

No row was added. **Content story 008 checks (F1–F5) for this story:** F5 War bundle coverage is now 17 / 18 = 0.94, above `bundle_coverage_min` 0.90, so its `W_COVERAGE` row clears. The one unbundled non-starter War card is `war_throwing_axe`, which content Edge Cases names as Discover-only. F1, F2 and F3 do not read bundles, so this story adds **no `W_BUDGET` or `W_CURVE` row**. The rows still listed (the War `W_BUDGET` "not checked" rows and `war_cleave_through` +3.0, the neutral `W_CURVE` / `W_SET_SHARE`, the boss `W_SET_SHARE`, and the MVP `W_COVERAGE` op and keyword rows) come from stories 001–003 and are unchanged. Story 009 triages them at the batch close.

### AC-1 / AC-2: records, coverage and bands

These are pinned by `tests/integration/content/content_mvp1_data_test.gd`, which loads through the real loader and Boot's validator map:
- `test_bundles_json_is_the_ten_cn4_mvp_bundles_with_set_theme_and_pitch`: `bundle_pool("war")` holds exactly the 10 CN-4 ids (8 `war`, 2 `neutral`). Each has its CN-4 name, theme and cards, `unlock` null, a keyed one-line pitch, and cards from its own set that carry its theme tag and are not tokens. The load report has no `E_COUNT`, `E_TOKEN_IN_LIST` or `E_TAG_MISMATCH`.
- `test_mvp_bundles_cover_every_war_signature_and_plan_tag_with_a_3_3_2_band_split`: `war_duelists_edge` (Kingsguard), `war_pit_champion` (The Pit) and `war_cleave_through` (Warband) are each in a bundle. `weapons`, `aggro` and `armour` have 3 / 3 / 2 bundles. The F2 bands, with cut-offs `curve.early_max` 2.5 and `mid_max` 4.0 read from `content_budgets.json`, split 3 early (1.67, 2.33, 2.00) / 3 mid (2.67, 3.67, 3.33) / 2 late (5.00, 5.33).
- `test_mvp_bundles_clear_the_f5_war_bundle_coverage_floor`: `ContentValidator.run_checks` returns no `coverage.bundle_coverage_min.war` row.

### AC-3: pool threshold, checked against the GDD value

**Reward Draft's `bundle_pool_min` is not registered.** `reward_draft` is still in Boot's `PENDING_CONFIG_OWNERS`, and the reward-draft epic has no stories. Per sprint-004 Goal Prerequisites option (a), AC-3 is checked against the **GDD value 9** (`reward-draft.md` F5: "MVP (`F = 4`): `B_min = 9` for any `W ≥ 2`"):
- `test_min_bundle_pool_meets_the_mvp_bundle_pool_min_and_the_war_pool_raises_no_pool_size` evaluates F5, `B_min = 3 + (F − 2) + 2 × min(F − 2, W)`, over the shipped knobs (`run_structure.floors_per_run` 4, `reward_draft.reoffer_after_floors` 2). The result is 9, which equals the GDD value. The test then checks `card_database.min_bundle_pool` (10) ≥ 9, `bundle_pool("war").size()` = 10 ≥ `min_bundle_pool`, and no `W_POOL_SIZE` on `bundles.json`.
- Once Reward Draft ships its config validator and registers `bundle_pool_min`, the test's GDD constant should be replaced by the registered value.

### Seen failing

All four new tests were run against the batch-0 `bundles.json`, before the seven rows were added, and all four failed: 3 ids not 10; signatures and plan tags missing; coverage row `0.06 (1 / 18)`; pool 3 < 10 with the `W_POOL_SIZE` row. They pass after the rows are added.

### Run result (same tree)

- `godot --headless --path . --import`: exit 0.
- `commands.test`: `1229 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans`, exit 0. There are 85 `SCRIPT ERROR` lines, the same as the baseline count from the negative tests.
- `commands.smoke` (`timeout 60 godot --headless --quit-after 5`): exit 0, no `SCRIPT ERROR`.
- `bash tools/lint/gates.sh .`: all gates 0 hits, PASS.
- `content_batch0_data_test.gd` had two exact pins that the new rows break. Both were relaxed: the three batch-0 bundles are still checked as present, and the expected `W_POOL_SIZE` files are now only `treasures.json`.

**Sign-off**: game-designer (data author): NOT ASSESSED (lean, no agent). The seven pitch lines were written by the lane acting as game-designer, and the owner may reword them.

**Result**: PASS (Config/Data, ADVISORY at story level). State `Ready`, 0 errors, no `W_POOL_SIZE` on bundles. AC-3 was checked against the GDD value, not a registered key.
