## Smoke Record — content story 010 (Gravekeeper returns to the boss decks)
**Date**: 2026-11-04
**Story**: `production/epics/content/story-010-gravekeeper-returns-to-the-boss-decks.md` (Config/Data)
**Engine**: Godot 4.7.2 (`4.7.2.stable.official.ed1daf0bf`, editor binary = debug build)
**QA Plan**: `production/qa/qa-plan-sprint-005-2026-11-04.md`, content-010 sections.
**Run by**: sprint-5 lane 3 wave 2, `s5/l3-w2`, cut from trunk `6694a41`. Per-story Config/Data record, not the sprint's `/smoke-check` report. It merges last at M2; the orchestrator's after-merge load (QA plan "content-010 Config/Data smoke record") is still to run.

**Owner sign-off (W2, 0.25 h)**: PENDING. Sections 1 and 2 are what you sign.

### 1. Deck diffs

Every deck is 30 non-token ids. Rat King is unchanged (DD-X24).

| Deck | Out | In | Distinct ids | Source |
|---|---|---|---|---|
| The Gatekeeper | `boss_iron_gate` ×3 → ×2, `boss_gate_warden` ×3 → ×2 | `neutral_gravekeeper` ×2 | 14 → 15 | DD-X20; undoes story 003's fallback |
| The Hollow King | `boss_hollow_knight` ×3 → ×2, `boss_crown_of_thorns` ×3 → ×2 | `neutral_gravekeeper` ×2 | 14 → 15 | DD-X20; undoes story 004's fallback |
| The Rot Warden | `neutral_crypt_brute` ×2 → ×0 | `neutral_gravekeeper` ×2 | 14 → 14 | DD-X20; undoes story 004's fallback. The other 10 named neutrals and both exclusions are unchanged |
| The Torchbearer | `neutral_ogre_porter` ×2 → ×0 | `neutral_gravekeeper` ×2 | 15 → 15 | AC-3, line kept (sprint-005 Readiness notes); undoes story 001's deviation. DD-X20's own list names only the other three decks |

Also shipped in this story:
- `ai_profiles.json`: `op_values.add_counter` 0.5 (DD-X20, boss-ai C6). The other 19 rows and every other key are unchanged.
- `cards_neutral.json`: `neutral_gravekeeper`, minion, cost 3, 2/3, rare, `deathrattle`, tag `pings`, CN-2 text (89 of 90 characters), `effects[]` = card-effects C11 row 45.
- `boss-ai.md` F9: `add_counter 0.5` in the list; the "does not yet carry" note is removed.

### 2. Validator record

`godot --headless --path . -s res://tools/content/validate.gd` (editor binary, debug) → **exit 0**.

| | Before (trunk `6694a41`) | After |
|---|---|---|
| State | `Ready` | `Ready` |
| Errors | 0 | **0** |
| Warnings (all / content checks) | 50 / 43 | **50 / 43** |
| Records | 69 | **70** (+1 card) |
| New warning codes | | **none** |

The QA plan's baseline of 51 predates heroes 004, which removed the `heroes_balance` pending row. The six `W_VALIDATOR_PENDING` rows match the QA plan's list: `match_ui`, `profile_defaults`, `reward_draft`, `run_structure`, `run_ui`, `treasures_balance` (no record owner). Load time is an observation, not asserted: 258.60 ms cold on a shared machine before, 36.16 ms after; budget 200.

Every row that changed, from a diff of the sorted warning lines:

```
+ W_BUDGET cards_neutral.json#neutral_gravekeeper.budget — not checked — op add_counter has no F3 rate, damage.amount is a value expression (partial value 5.0 vs budget 7.0)
- W_COVERAGE ...ops_covered.add_counter — op add_counter is used by no collectible card (F5, 39 cards)
~ W_COVERAGE ...kw_min.deathrattle — on 0 → 1 collectible cards, under kw_min 2 (F5)
~ W_COVERAGE ...ops_covered.* — the 11 other unused-op rows read 40 cards, was 39
~ W_CURVE cards_neutral.json.curve.avg — avg_cost 2.71 (14 cards) → 2.73 (15 cards), outside 2.9–3.4 (F2)
~ W_CURVE cards_neutral.json.curve.bucket[2] — cost bucket 3 share 0.36 (5 / 14) → 0.40 (6 / 15), misses 0.24 by more than 0.08 (F2)
~ W_CURVE cards_neutral.json.curve.bucket[5] — cost bucket 6+ share 0.00 (0 / 14) → 0.00 (0 / 15) (F2)
~ W_SET_SHARE cards_neutral.json.set_share.neutral.minion — 0.93 (13 / 14) → 0.93 (14 / 15), outside 0.82 ± 0.08 (F1)
```

All four codes are in the latest content smoke record, `smoke-2026-11-04-content-mvp1-bundles.md`. The neutral curve and set-share rows were already failing; a 15th neutral at cost 3 moves bucket 3 further from target. Story 009 triages them at the batch close.

**F3 (content AC-6).** The new `W_BUDGET` row is "not checked", the same kind as the `neutral_banner_captain` and `neutral_spark_fiend` rows. F3 has no rate for `add_counter`, or for a damage amount read from a counter. The partial value 5.0 is the 2/3 body, against budget 7.0 and rare tolerance 2.0, so it is at the edge of the band with no effect points, and inside it for up to 4.0 effect points. No accepted-deviation note is needed: the card is not shown outside `BUDGET_TOL`. Whether F3 should gain a rate is left open; none is invented here.

**F4 (`boss_pressure`).** Formal F4 stays with story 009 (story Out of Scope); the QA plan asks for the recompute to be recorded, so this is an observation only. The table gives the deck term `avg_points × (4 + T) / T` with T = 10 / 10 / 11. `passive_points` is left out because this story does not change it. Values come from `ContentValidator.card_value`, so each is a **partial value**: cards with an unvalued op count less than their real worth, and Gravekeeper counts as 5.0.

| Deck | Band | `avg_points` | Deck term | Change |
|---|---|---|---|---|
| The Gatekeeper | 1 | 6.533 → 6.267 | 9.147 → 8.773 | −0.373 |
| The Torchbearer | 1 | 5.767 → 5.367 | 8.073 → 7.513 | −0.560 |
| The Rot Warden | 2 | 5.193 → 4.927 | 7.271 → 6.897 | −0.373 |
| The Hollow King | 3 | 6.467 → 6.500 | 8.818 → 8.864 | +0.045 |

The falls are partly the model: Gravekeeper's payoff scores 0 while it replaces a 9-point (Crypt Brute) or 11-point (Ogre Porter) vanilla body. The sim check (AC-12) waits for BAI-016.

### 3. AC-1 to AC-3 evidence

Pinned on shipped data through the real loader and Boot's validator map:
- **AC-1**: `boss_ai_profiles_data_test.gd::test_op_values_are_f9s_twenty_card_effects_ops_with_its_values` (renamed from `…_nineteen_…`). It reads the list from F9, checks 20 rows, `add_counter` 0.5, the shipped file equal to the list, and the note gone. `validate_profiles_config` returns zero rows on the shipped file, `planner_target_ms` included (`test_gravekeeper_validates_with_zero_fx_rows_and_zero_e_ai_op_unvalued`).
- **AC-2**: `content_mvp1_data_test.gd::test_gravekeeper_is_the_cn2_row_with_c11_row_45_verbatim` parses row 45 out of `card-effects.md`, so the effects are compared to the GDD, not to a copy. The neutral set is 15.
- **AC-3**: the four deck tests in `content_mvp1_data_test.gd` and `content_batch0_data_test.gd`. Rat King's test is unchanged and still passes.
- **Runtime (QA plan, optional)**: `test_shipped_gravekeeper_deals_the_minions_that_died_in_play_to_the_enemy_hero`. The shipped record, on the real engine and resolver, deals 3 to the enemy hero after three minions from either side die while it is in play.

### Seen failing

On the old data, before any data edit, all 10 target tests failed: the 7 in `content_mvp1_data_test.gd`, the 2 in `content_batch0_data_test.gd`, and the `op_values` test. They pass after the data change. Run: 68 cases in the three suites, 0 failures.

### 4. Run result (same tree)

- `godot --headless --path . --import`: exit 0, no errors in its log.
- `bash tools/lint/gates.sh`, `no_global_rng.sh`, `parse-check.sh`: all exit 0, 0 hits, 41 checked, 0 failed.
- `commands.test`: `1732 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans`, exit 0, 105 of 105 suites. 88 `SCRIPT ERROR` lines, all from intentional negative tests; none names Gravekeeper or a counter.
- `commands.smoke` (`godot --headless --quit-after 5`): exit 0, engine banner only, no `SCRIPT ERROR`.

**Checked and unchanged**: `tests/fixtures/match_ui/streams/full_match_torchbearer.json` shows a boss `neutral_ogre_porter`, but its own note says it is hand-built and it reads no shipped deck, so this story does not break it.

### 5. Full validate output (after)

```
[warning] W_SET_SHARE cards_boss.json.set_share.boss.minion — boss minion share 0.70 (7 / 10) outside 0.56 ± 0.08 (F1)
[warning] W_SET_SHARE cards_boss.json.set_share.boss.spell — boss spell share 0.30 (3 / 10) outside 0.41 ± 0.08 (F1)
[warning] W_SET_SHARE cards_neutral.json.set_share.neutral.minion — neutral minion share 0.93 (14 / 15) outside 0.82 ± 0.08 (F1)
[warning] W_CURVE cards_neutral.json.curve.avg — avg_cost 2.73 (15 cards) outside 2.9–3.4 (F2)
[warning] W_CURVE cards_neutral.json.curve.bucket[2] — cost bucket 3 share 0.40 (6 / 15) misses 0.24 by more than 0.08 (F2)
[warning] W_CURVE cards_neutral.json.curve.bucket[5] — cost bucket 6+ share 0.00 (0 / 15) misses 0.1 by more than 0.08 (F2)
[warning] W_BUDGET cards_neutral.json#neutral_banner_captain.budget — not checked — op aura has no F3 rate (partial value 4.0 vs budget 7.0)
[warning] W_BUDGET cards_neutral.json#neutral_gravekeeper.budget — not checked — op add_counter has no F3 rate, damage.amount is a value expression (partial value 5.0 vs budget 7.0)
[warning] W_BUDGET cards_neutral.json#neutral_spark_fiend.budget — not checked — damage on selector "" (partial value 5.0 vs budget 7.0)
[warning] W_BUDGET cards_war.json#war_armorer.budget — not checked — armor.amount is a value expression (partial value 5.0 vs budget 5.0)
[warning] W_BUDGET cards_war.json#war_blade_apprentice.budget — not checked — op equip has no F3 rate (partial value 4.0 vs budget 5.0)
[warning] W_BUDGET cards_war.json#war_blade_strike.budget — not checked — damage.amount is a value expression (partial value 0.0 vs budget 2.0)
[warning] W_BUDGET cards_war.json#war_cleave_through.budget — value 9.0 vs budget 6.0 (Δ +3.0, rare tol 2.0; F3)
[warning] W_BUDGET cards_war.json#war_rally.budget — not checked — buff on selector "all_friendly_minions" (partial value 0.0 vs budget 6.0)
[warning] W_BUDGET cards_war.json#war_warcry.budget — not checked — buff on selector "all_friendly_minions" (partial value 0.0 vs budget 4.0)
[warning] W_BUDGET cards_war.json#war_warlord.budget — not checked — op aura has no F3 rate (partial value 10.0 vs budget 13.0)
[warning] W_COVERAGE content_budgets.json.coverage.ops_covered.set_stats — op set_stats is used by no collectible card (F5, 40 cards)
[warning] W_COVERAGE content_budgets.json.coverage.ops_covered.freeze — op freeze is used by no collectible card (F5, 40 cards)
[warning] W_COVERAGE content_budgets.json.coverage.ops_covered.summon — op summon is used by no collectible card (F5, 40 cards)
[warning] W_COVERAGE content_budgets.json.coverage.ops_covered.transform — op transform is used by no collectible card (F5, 40 cards)
[warning] W_COVERAGE content_budgets.json.coverage.ops_covered.discover — op discover is used by no collectible card (F5, 40 cards)
[warning] W_COVERAGE content_budgets.json.coverage.ops_covered.add_to_hand — op add_to_hand is used by no collectible card (F5, 40 cards)
[warning] W_COVERAGE content_budgets.json.coverage.ops_covered.copy_to_hand — op copy_to_hand is used by no collectible card (F5, 40 cards)
[warning] W_COVERAGE content_budgets.json.coverage.ops_covered.return_to_hand — op return_to_hand is used by no collectible card (F5, 40 cards)
[warning] W_COVERAGE content_budgets.json.coverage.ops_covered.mana — op mana is used by no collectible card (F5, 40 cards)
[warning] W_COVERAGE content_budgets.json.coverage.ops_covered.retrigger — op retrigger is used by no collectible card (F5, 40 cards)
[warning] W_COVERAGE content_budgets.json.coverage.ops_covered.set_counter — op set_counter is used by no collectible card (F5, 40 cards)
[warning] W_COVERAGE content_budgets.json.coverage.modify_value — op modify_value is used by no boss passive or treasure (F5)
[warning] W_COVERAGE_UNUSED content_budgets.json.coverage.ops_exempt.remove_keyword — exempt op remove_keyword is used by no collectible card (F5)
[warning] W_COVERAGE_UNUSED content_budgets.json.coverage.ops_exempt.shuffle_into_deck — exempt op shuffle_into_deck is used by no collectible card (F5)
[warning] W_COVERAGE_UNUSED content_budgets.json.coverage.ops_exempt.discard — exempt op discard is used by no collectible card (F5)
[warning] W_COVERAGE_UNUSED content_budgets.json.coverage.ops_exempt.weapon_durability — exempt op weapon_durability is used by no collectible card (F5)
[warning] W_COVERAGE_UNUSED content_budgets.json.coverage.ops_exempt.hero_power_refresh — exempt op hero_power_refresh is used by no collectible card (F5)
[warning] W_COVERAGE content_budgets.json.coverage.kw_min.rush — keyword rush is on 1 collectible cards, under kw_min 2 (F5)
[warning] W_COVERAGE content_budgets.json.coverage.kw_min.windfury — keyword windfury is on 1 collectible cards, under kw_min 2 (F5)
[warning] W_COVERAGE content_budgets.json.coverage.kw_min.stealth — keyword stealth is on 0 collectible cards, under kw_min 2 (F5)
[warning] W_COVERAGE content_budgets.json.coverage.kw_min.lifesteal — keyword lifesteal is on 0 collectible cards, under kw_min 2 (F5)
[warning] W_COVERAGE content_budgets.json.coverage.kw_min.poisonous — keyword poisonous is on 0 collectible cards, under kw_min 2 (F5)
[warning] W_COVERAGE content_budgets.json.coverage.kw_min.freeze — keyword freeze is on 0 collectible cards, under kw_min 2 (F5)
[warning] W_COVERAGE content_budgets.json.coverage.kw_min.silence — keyword silence is on 1 collectible cards, under kw_min 2 (F5)
[warning] W_COVERAGE content_budgets.json.coverage.kw_min.deathrattle — keyword deathrattle is on 1 collectible cards, under kw_min 2 (F5)
[warning] W_COVERAGE content_budgets.json.coverage.kw_min.spell_damage — keyword spell_damage is on 0 collectible cards, under kw_min 2 (F5)
[warning] W_COVERAGE content_budgets.json.coverage.kw_min.discover — keyword discover is on 0 collectible cards, under kw_min 2 (F5)
[warning] E_DELEGATED match_ui.json — W_VALIDATOR_PENDING: configs.match_ui is not checked: its owner Match UI has not shipped validate_config
[warning] E_DELEGATED profile_defaults.json — W_VALIDATOR_PENDING: configs.profile_defaults is not checked: its owner Meta Progression has not shipped validate_config
[warning] E_DELEGATED reward_draft.json — W_VALIDATOR_PENDING: configs.reward_draft is not checked: its owner Reward Draft has not shipped validate_config
[warning] E_DELEGATED run_structure.json — W_VALIDATOR_PENDING: configs.run_structure is not checked: its owner Run Structure has not shipped validate_config
[warning] E_DELEGATED run_ui.json — W_VALIDATOR_PENDING: configs.run_ui is not checked: its owner Run UI has not shipped validate_config
[warning] W_POOL_SIZE treasures.json — 0 < 6: treasures unlocked by default vs min_treasure_pool (2 treasure drafts × 3 offers, no repeats in a run)
[warning] E_DELEGATED treasures_balance.json — W_VALIDATOR_PENDING: configs.treasures_balance is not checked: its owner Treasures has not shipped validate_config
validate: Ready — 0 errors, 50 warnings (content checks 0 errors, 43 warnings), 70 records; load ms 36.16 (data_load_budget_ms 200) — root res://assets/data/
```

**Sign-off**: game-designer (data author): lane 3, acting as game-designer. Owner: PENDING (W2).

**Result**: PASS (Config/Data, ADVISORY at story level). State `Ready`, 0 errors, no new warning code. The orchestrator's after-merge load at M2 is still to run.
