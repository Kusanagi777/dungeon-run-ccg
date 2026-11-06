## Smoke Record — content story 001 (batch-0 data set)
**Date**: 2026-11-04
**Story**: `production/epics/content/story-001-batch-0-first-playable-data-set.md` (Config/Data)
**Engine**: Godot 4.7.2 (`4.7.2.stable.official.ed1daf0bf`, editor binary = debug build)
**QA Plan**: `production/qa/qa-plan-sprint-003-2026-11-03.md` — Manual QA "content 001 Batch-0 data set — Config/Data smoke record"; Smoke item 7
**Run by**: sprint-3 lane `lane/s3-content-001-007` (owner's standing approval). This is the story's per-story Config/Data record, not the sprint's `/smoke-check` report.

### Headless load (AC-1)

**Method**: a headless SceneTree script loads `res://assets/data/` through `DataLoader` + `CardDatabase.load()` with the validator map `Boot` composes — a fresh `boot.gd` instance's `_collect_validators(null)` (debug severity), never the autoload and never `boot()`. The same load is pinned by `tests/integration/content/content_batch0_data_test.gd` (15 tests, real validators, no `accept_all()`).

| Field | Value |
|---|---|
| State | `READY` |
| Error entries | **0** |
| Warning entries | 13 (listed below) |
| `Unloaded → Ready` | 12.44 ms on the Linux dev container — an **observation**, compared with `data_load_budget_ms` 200 (`card_database.json`); never asserted (QA plan Cross-cutting 2) |
| `data_version()` | `cfd890056334fee8` |
| Records | 24 CardDefs (21 collectible + 1 token in war/neutral, 2 boss), 1 HeroDef, 1 HeroPowerDef, 1 BossDef, 3 BundleDefs, 0 TreasureDefs |

Load report (`ValidationReport.to_text()`, verbatim):

```
[warning] W_BAND_HEALTH bosses.json — band health not checked: match_rules.boss_starting_health_by_band absent, not whole numbers, or missing a band
[warning] E_DELEGATED bosses.json#boss_torchbearer.ai_profile — W_VALIDATOR_PENDING: `ai_profile` (host kind boss) is not checked: its owner Boss AI has not shipped the validator (BossDef `ai_profile`)
[warning] W_POOL_SIZE bundles.json.min_bundle_pool — bundle pool for war: 3 < 10 (n_bundles(war) + n_bundles(neutral) vs min_bundle_pool)
[warning] W_POOL_SIZE cards_war.json.min_collectible_pool — collectible pool for war: 21 < 30 (n_nontoken(war) + n_nontoken(neutral) vs min_collectible_pool)
[warning] E_DELEGATED content_budgets.json — W_VALIDATOR_PENDING: configs.content_budgets is not checked: its owner Content has not shipped validate_config
[warning] E_DELEGATED heroes_balance.json — W_VALIDATOR_PENDING: configs.heroes_balance is not checked: its owner Heroes has not shipped validate_config
[warning] E_DELEGATED match_ui.json — W_VALIDATOR_PENDING: configs.match_ui is not checked: its owner Match UI has not shipped validate_config
[warning] E_DELEGATED profile_defaults.json — W_VALIDATOR_PENDING: configs.profile_defaults is not checked: its owner Meta Progression has not shipped validate_config
[warning] E_DELEGATED reward_draft.json — W_VALIDATOR_PENDING: configs.reward_draft is not checked: its owner Reward Draft has not shipped validate_config
[warning] E_DELEGATED run_structure.json — W_VALIDATOR_PENDING: configs.run_structure is not checked: its owner Run Structure has not shipped validate_config
[warning] E_DELEGATED run_ui.json — W_VALIDATOR_PENDING: configs.run_ui is not checked: its owner Run UI has not shipped validate_config
[warning] W_POOL_SIZE treasures.json — 0 < 6: treasures unlocked by default vs min_treasure_pool (2 treasure drafts × 3 offers, no repeats in a run)
[warning] E_DELEGATED treasures_balance.json — W_VALIDATOR_PENDING: configs.treasures_balance is not checked: its owner Treasures has not shipped validate_config
```

### Validators used (the AC-1 "stub validators named in the smoke record")

Real validators that ran over this data: `effects` → `EffectValidator.validate_effects` through Boot's `_effects_adapter` (caps = the shipped `card_effects.json`); `unlock` → Boot's MVP `_validate_unlock_defs_mvp`; `configs.card_effects` → `EffectValidator.validate_config`; `configs.match_rules` → `RulesEngine.validate_rules_config`; `configs.ai_profiles` → `BossAI.validate_profiles_config` (op coverage over this batch's cards included); `configs.rng_event_log` → `EventLog.validate_config`; `card_database.json` → the loader's own stage-4 knob check.

Pending (Boot's `PENDING_CONFIG_OWNERS` / `PENDING_RECORD_OWNERS`; each emits one `W_VALIDATOR_PENDING`, a warning in this debug load and an **error in an exported release build**):

| Pending | Owner | Row in the report |
|---|---|---|
| `configs.run_structure` | Run Structure | yes |
| `configs.reward_draft` | Reward Draft | yes |
| `configs.treasures_balance` | Treasures | yes |
| `configs.heroes_balance` | Heroes | yes |
| `configs.match_ui` | Match UI | yes |
| `configs.run_ui` | Run UI | yes |
| `configs.profile_defaults` | Meta Progression | yes |
| `configs.content_budgets` | Content (story 007 ships `ContentValidator.validate_config`; the orchestrator registers it at merge) | yes, until then |
| record `ai_profile` | Boss AI | yes (one row, host kind boss) |
| record `treasure` | Treasures | no row: `treasures.json` holds no records, so the validator is never called |

### Warnings triage (CN-6 step 3)

- `W_POOL_SIZE` ×3 (collectible 21 < 30, bundle 3 < 10, treasure 0 < 6): accepted at MVP-0 only (CN-6.3). The bundle pool sits exactly on the DD-R04 hard floor of 3, so stage 8 does not raise `E_COUNT`.
- `W_BAND_HEALTH` "not checked": `match_rules.json` (Match Rules' file) has no `boss_starting_health_by_band`, so stage 8 cannot compare. `boss_torchbearer.health` is 30 = the band-1 value (registry `boss_starting_health_by_band` 30/40/50). Not a content fault; for Match Rules.
- `W_VALIDATOR_PENDING` ×9: the pending owners above.
- `W_DUP_NAME`, `W_FX_KEYWORD_MISMATCH`: none (both must be fixed before a batch closes).

### Spot-check against the GDDs (Manual QA checklist)

- [x] Every required `FILE_MANIFEST` row is present with a CR-1 envelope; state `Ready`, **0** errors.
- [x] Warning list = `W_POOL_SIZE` (collectible, bundle, treasure) + one `W_VALIDATOR_PENDING` per pending owner — **plus** the `W_BAND_HEALTH` "not checked" row the QA plan did not list (above).
- [x] Load time printed and compared with 200 ms as an observation.
- [x] `hero_war` (Halvard, the Whetted; war; 30; `power_whetstone`; `unlock` null; H-2 identity line), `power_whetstone` (cost 2, H-3 / C11 row 8 effect), the 15-card H-4 starter (war/neutral, no token; F1: counts 4/4/4/2/1, sum 37, avg 2.47, max 5); `war_whetstone_blade` is a 1/2 token weapon referenced by Whetstone's `equip`.
- [x] `boss_torchbearer` per CN-3 B1 (band 1, 30, no power, `turn_end{side: owner}` → `enemy_hero` → `damage 1`, `passive_text`, tags `["burn"]`, `ai_profile` resolving through `{extends: aggro}` with zero `E_AI_*` rows from `BossAI.validate_profiles_config` and `validate_ai_profile`). Deck: 30 ids per B2 **with one deviation** — `neutral_gravekeeper` ×2 replaced by `neutral_ogre_porter` ×2 (story Completion Notes).
- [x] Zero `E_FX_*` / `W_FX_*` over every card `effects[]`, the power and the passive; every `text.en` ≤ 90 characters; 3 bundles per CN-4; no token in any list.

**Sign-off**: game-designer (data author) — NOT ASSESSED (lean, no agent; the lane authored from the GDD tables). The owner reads the `boss_torchbearer` and War starter rows (QA plan).

**Result**: PASS (Config/Data, ADVISORY at story level) — `Ready`, 0 errors.

### Content validate command on the shipped data (content story 007; QA plan Smoke item 7)

`godot --headless --path . -s res://tools/content/validate.gd` (editor binary, debug) → **exit 0**. It printed the same 13 report lines as above, then:

```
validate: Ready — 0 errors, 13 warnings, 30 records; load ms 11.84 (data_load_budget_ms 200) — root res://assets/data/
```

Release behaviour (not run as a binary; pinned in process by `test_release_map_makes_pending_validators_errors_and_exits_1`): with Boot's release-severity map every pending owner's row is an error, so the same data exits **1**. With the orchestrator's `configs["content_budgets"] = ContentValidator.validate_config` line applied (trialled on the lane and reverted, since `boot.gd` is orchestrator-owned) the shipped `content_budgets.json` passes and the debug report drops to 12 warnings.

### Run result (same tree)

- `godot --headless --path . --import`: exit 0.
- `commands.test`: `960 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans`, exit 0; 85 `SCRIPT ERROR` lines, the same count as the pre-story baseline (all from negative tests).
- `commands.smoke` (`timeout 60 godot --headless --quit-after 5`): exit 0, no `SCRIPT ERROR`. Main scene is still `boot.tscn`, which does not call `Boot.boot()`.
- `bash tools/lint/gates.sh .`: all gates 0 hits — PASS.
