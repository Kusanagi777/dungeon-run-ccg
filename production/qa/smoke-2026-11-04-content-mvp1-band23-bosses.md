## Smoke Record — content story 004 (MVP-1 bosses The Rot Warden, The Hollow King, and the `decay_husk` token)
**Date**: 2026-11-04
**Story**: `production/epics/content/story-004-mvp-1-bosses-rot-warden-hollow-king.md` (Config/Data)
**Engine**: Godot 4.7.2 (`4.7.2.stable.official.ed1daf0bf`, editor binary = debug build)
**QA Plan**: `production/qa/qa-plan-sprint-004-2026-11-04.md`; this record works from the story's acceptance criteria.
**Run by**: sprint-4 lane 5 wave 2 `lane/s4-l5-w2` (owner's standing approval), on top of content story 005 (`28819aa`). This is the per-story Config/Data record, not the sprint's `/smoke-check` report.

### What changed

| File | Records added |
|---|---|
| `bosses.json` | **`boss_rot_warden`** (band 2, health 40). Passive `on_minion_died{who: friendly_minion}` → `enemy_hero` → `damage 1`. Tags `["deathrattle"]`.<br>**`boss_hollow_king`** (band 3, health 50). Passive `turn_start{side: owner}` → `all_friendly_minions` → `buff +1/+1`. Tags `["wall"]`.<br>Both: `hero_power` null, CN-3 B1 `passive_text`, `ai_profile` = boss id, placeholder `intro_text` naming the passive. |
| `cards_boss.json` | `boss_rot_zombie` (M 3, 2/3, Deathrattle: summon `decay_husk` ×1 at `source_slot`); `boss_mass_rites` (S 4, `all_friendly_minions` → `retrigger deathrattle`); `boss_hollow_knight` (M 4, 3/4, Divine Shield); `boss_crown_of_thorns` (S 3, `all_friendly_minions` → `buff +1/+1`, `give_keyword taunt`). All four are set `boss`, `common`. |
| `cards_decay.json` (new, optional `FILE_MANIFEST` row) | One record: `decay_husk` (Husk, minion 1, 1/1, tag `husk`, `token: true`). |

Every earlier boss, card and bundle is unchanged.

**Decks** (30 non-token ids each, all from MVP-1 or earlier):

**Rot Warden** follows the MVP recipe: `boss_rot_zombie` ×3, `boss_mass_rites` ×3, and 2× each of 12 neutrals.
- The recipe leads with `neutral_gravekeeper` and `neutral_shield_golem`.
- The other 10, named in the story's Implementation Notes: torch_imp, tunnel_rat, cellar_guard, lantern_bearer, bulwark_smith, dungeon_delver, hush_owl, spark_fiend, banner_captain, wolf_rider.
- **Deviation:** `neutral_gravekeeper` can't ship (story 001: Boss AI has no `op_values` row for `add_counter`). Its two slots go to `neutral_crypt_brute` ×2. This is the content Edge Cases same-batch fallback, "neutrals from that batch or earlier", used because both boss cards are already at the ×3 cap.
- Left out of the 15 MVP neutrals: `neutral_ogre_porter` and `neutral_smite_or_mend`.

**Hollow King** follows the MVP-1 recipe: `war_shield_maiden` ×2, `war_shieldwall_veteran` ×2, and the 10 shippable recipe neutrals ×2.
- **Deviation:** the two `neutral_gravekeeper` slots go to the boss cards at ×3 (`boss_hollow_knight` ×3, `boss_crown_of_thorns` ×3). This is the same fallback story 003 used for Gatekeeper.

### Content validate command on the shipped data

`godot --headless --path . -s res://tools/content/validate.gd` (editor binary, debug) → **exit 0**.

| | Before (after story 005, `28819aa`) | After |
|---|---|---|
| State | `Ready` | `Ready` |
| Errors | 0 | **0** |
| Warnings (all / content checks F1–F5) | 51 / 43 | **51 / 43** |
| Records | 62 | **69** (+2 BossDefs, +4 boss cards, +1 token) |
| `W_POOL_SIZE` | 1 (treasure 0 < 6) | **1**, unchanged. The `decay` set raises no `E_COUNT` / `W_POOL_SIZE`: stage 8 sizes pools only for hero sets in `heroes.json`. |
| Load ms (observation, never asserted; budget 200) | 19.43 | 20.68 |

Diff of the sorted warning lines. Two rows changed in value, none were added and none removed:

```
< [warning] W_SET_SHARE cards_boss.json.set_share.boss.minion — boss minion share 0.83 (5 / 6) outside 0.56 ± 0.08 (F1)
< [warning] W_SET_SHARE cards_boss.json.set_share.boss.spell — boss spell share 0.17 (1 / 6) outside 0.41 ± 0.08 (F1)
---
> [warning] W_SET_SHARE cards_boss.json.set_share.boss.minion — boss minion share 0.70 (7 / 10) outside 0.56 ± 0.08 (F1)
> [warning] W_SET_SHARE cards_boss.json.set_share.boss.spell — boss spell share 0.30 (3 / 10) outside 0.41 ± 0.08 (F1)
```

**Content story 008 checks (F1–F5) for this story:**
- **F1 `W_SET_SHARE` boss.** The boss set moves toward its target: 0.83 → 0.70 minion share, 0.17 → 0.30 spell share. It is still outside ± 0.08 because the MVP boss set is 10 cards, and only 3 of the 10 B3 rows shipped so far are spells. The full v1 B3 table is 32 cards, 17 M / 14 S / 1 W ≈ 0.53 / 0.44, inside the target. The row is expected to clear only near Alpha. It is triaged at the batch close (story 009), not fixed here.
- **F2 `W_CURVE` / F3 `W_BUDGET`.** No new row. Both checks read collectible cards only: non-token, not set `boss`. This story adds only boss cards and a token.
- **F5.** No change. Boss cards are not collectible, so `retrigger`, `give_keyword` and `summon` used here do not count toward `ops_covered`. `modify_value` is still unused by any passive: neither new passive uses it.
- **F4 (boss pressure)** is not a load-time check. It is deferred to the batch close (story 009) with the sim harness.
- No `W_BAND_HEALTH` (40 / 50 = `boss_starting_health_by_band`), no `W_DUP_NAME`, no `W_FX_*`, no `E_TEXT_LENGTH`.

### AC-1: `ai_profile` resolves with zero `E_AI_*`, through the load

Boot now registers `map["ai_profile"] = BossAI.validate_ai_profile` at stage 7b (sprint-4 L4). The shipped load therefore runs the validator over all 5 bosses, and the report holds **no `E_AI_*` and no `ai_profile` `W_VALIDATOR_PENDING` row**.

`test_rot_warden_and_hollow_king_profiles_resolve_through_their_overrides_with_zero_e_ai_rows` checks this two ways:
- It calls `validate_ai_profile` directly for both new bosses, and also scans the load report for `E_AI_*`.
- It resolves both profiles with `ProfileResolver.resolve`:
  - Rot Warden at band 2 extends `passive_driven`, with `w_self` 1.5 and `synergy_tags` `["deathrattle"]` (Boss AI F9).
  - Hollow King at band 3 extends `control`, with `w_board` 3.0.
  - Neither uses `intent_mode: hidden`.

**Seen failing.** With Rot Warden's `ai_profile` mutated to `boss_rot_wardenx`, the shipped load goes `Failed` with `E_DELEGATED … E_AI_PROFILE_UNKNOWN` (`record_id` `boss_rot_warden`), and the suite fails. The key was then restored.

### AC-2 / AC-3: decks, cards, token

These are pinned by `tests/integration/content/content_mvp1_data_test.gd`, which has 9 tests for this story. The tests load through the real loader and Boot's validator map, and check:
- Bands 2 and 3 hold exactly the new bosses, and both B1 rows match.
- Both decks have 30 resolving non-token ids with the counts above.
- The four B3 cards match their rows, including the `retrigger` and `buff` + `give_keyword` effect shapes.
- `decay_husk` is the only `decay` record. It is a 1/1 `husk` token, the `summon` target of `boss_rot_zombie`, and appears in no deck, pool or bundle. No `E_COUNT` / `W_POOL_SIZE` is raised for `decay`.
- `EffectValidator.validate_effects` returns **zero rows** over both passives and every boss and decay card. That includes `on_minion_died` on the passive host (card-effects C9) and `retrigger` on `all_friendly_minions`.
- The load is `Ready` with zero errors.

Two story-003 pins in the same file were raised to the new totals: 3 → 5 shipped bosses, and 7 → 11 boss-set cards.

### Not evaluated here

- **F4 boss pressure and the sim harness** (AC-12/13) belong to the batch close, story 009. Hollow King's `passive_points` by the F4 rate (+1/+1 to n = 2 minions → 4) is under PASSIVE_CAP[3] 6. Rot Warden's death ping is not in the F4 rate list; the sim decides it.
- **Runtime behaviour** of the death-ping observer, Mass Rites' `retrigger` and Crown of Thorns is Card Effects / Match Rules work, exercised once the match driver plays these bosses.

### Run result (same tree)

- `godot --headless --path . --import`: exit 0.
- `commands.test`: `1238 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans`, exit 0. 85 `SCRIPT ERROR` lines, the baseline count from the negative tests.
- `commands.smoke` (`timeout 60 godot --headless --quit-after 5`): exit 0, no `SCRIPT ERROR`.
- `bash tools/lint/gates.sh .`: all gates 0 hits, PASS.

**Sign-off**: game-designer (data author): NOT ASSESSED (lean, no agent). Rot Warden's 10 named neutrals, the two exclusions and both Gravekeeper fallbacks were chosen by the lane acting as game-designer. The owner may swap them.

**Result**: PASS (Config/Data, ADVISORY at story level). `Ready`, 0 errors, zero `E_FX_*`, zero `E_AI_*` through the load.
