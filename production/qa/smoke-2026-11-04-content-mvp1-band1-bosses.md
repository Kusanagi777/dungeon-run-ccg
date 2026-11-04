## Smoke Record — content story 003 (MVP-1 band-1 bosses: The Rat King, The Gatekeeper)
**Date**: 2026-11-04
**Story**: `production/epics/content/story-003-mvp-1-band-1-bosses-rat-king-gatekeeper.md` (Config/Data)
**Engine**: Godot 4.7.2 (`4.7.2.stable.official.ed1daf0bf`, editor binary = debug build)
**QA Plan**: `production/qa/qa-plan-sprint-004-2026-11-04.md` is not on this branch (written in parallel); this record works from the story's acceptance criteria.
**Run by**: sprint-4 lane 5 `lane/s4-l5-content` (owner's standing approval), on top of content story 002 (`5a73649`). Per-story Config/Data record, not the sprint's `/smoke-check` report.

### What changed

| File | Records added |
|---|---|
| `bosses.json` | `boss_rat_king`, `boss_gatekeeper` (band 1, health 30, `hero_power` null, B1 passive + `passive_text`, tags `["swarm"]` / `["wall"]`, `ai_profile` = boss id, placeholder `intro_text` naming the passive) |
| `cards_boss.json` | `boss_rat_pack`, `boss_rat_matriarch`, `boss_iron_gate`, `boss_gate_warden` (CN-3 B3, set `boss`, `common`) and the token `boss_rat` (minion 1/1, tag `rat`, `token: true`) |
| `cards_neutral.json` | `neutral_smite_or_mend` (CN-2, C11 row 33 Choose One) |

Torchbearer, its cards and every batch-0 / story-002 record are unchanged.

**Decks.** Rat King: `boss_rat_pack` ×2, `boss_rat_matriarch` ×2 + 2× each of 13 MVP neutrals ≤ 5 cost — all 15 MVP neutrals except `neutral_gravekeeper` (deferred, story 001) and `neutral_smite_or_mend` (named in the story's Implementation Notes). Gatekeeper: the B2 recipe with **one deviation** — `neutral_gravekeeper` is not shippable (story 001: `E_AI_OP_UNVALUED` for `add_counter`), so its two slots go to the boss cards at ×3 (`boss_iron_gate` ×3, `boss_gate_warden` ×3), the content Edge Cases same-batch fallback; the other 12 recipe neutrals ×2.

### Content validate command (content story 007) on the shipped data

`godot --headless --path . -s res://tools/content/validate.gd` (editor binary, debug) → **exit 0**.

| | Before (after story 002, `5a73649`) | After |
|---|---|---|
| State | `Ready` | `Ready` |
| Errors | 0 | **0** |
| Warnings | 10 | **10** |
| Records | 47 | **55** (+2 BossDefs, +5 boss cards incl. the token, +1 neutral) |
| `W_POOL_SIZE` | 2 (bundle 3 < 10, treasure 0 < 6) | **2** — unchanged: this story adds no bundle or treasure, and the collectible pool (now 39) already cleared 30 in story 002 |
| Load ms (observation, never asserted; budget 200) | 12.45 | 14.29 |
| `data_version()` | `e2d8c276decc9b35` | `688ed8a7c5e414de` |

Load report after (verbatim):

```
[warning] E_DELEGATED bosses.json#boss_gatekeeper.ai_profile — W_VALIDATOR_PENDING: `ai_profile` (host kind boss) is not checked: its owner Boss AI has not shipped the validator (BossDef `ai_profile`)
[warning] W_POOL_SIZE bundles.json.min_bundle_pool — bundle pool for war: 3 < 10 (n_bundles(war) + n_bundles(neutral) vs min_bundle_pool)
[warning] E_DELEGATED heroes_balance.json — W_VALIDATOR_PENDING: configs.heroes_balance is not checked: its owner Heroes has not shipped validate_config
[warning] E_DELEGATED match_ui.json — W_VALIDATOR_PENDING: configs.match_ui is not checked: its owner Match UI has not shipped validate_config
[warning] E_DELEGATED profile_defaults.json — W_VALIDATOR_PENDING: configs.profile_defaults is not checked: its owner Meta Progression has not shipped validate_config
[warning] E_DELEGATED reward_draft.json — W_VALIDATOR_PENDING: configs.reward_draft is not checked: its owner Reward Draft has not shipped validate_config
[warning] E_DELEGATED run_structure.json — W_VALIDATOR_PENDING: configs.run_structure is not checked: its owner Run Structure has not shipped validate_config
[warning] E_DELEGATED run_ui.json — W_VALIDATOR_PENDING: configs.run_ui is not checked: its owner Run UI has not shipped validate_config
[warning] W_POOL_SIZE treasures.json — 0 < 6: treasures unlocked by default vs min_treasure_pool (2 treasure drafts × 3 offers, no repeats in a run)
[warning] E_DELEGATED treasures_balance.json — W_VALIDATOR_PENDING: configs.treasures_balance is not checked: its owner Treasures has not shipped validate_config
validate: Ready — 0 errors, 10 warnings, 55 records; load ms 14.29 (data_load_budget_ms 200) — root res://assets/data/
```

Triage: `W_POOL_SIZE` ×2 (stories 005, 006); `W_VALIDATOR_PENDING` ×8, among them the one `ai_profile` row (the loader files one pending row per record kind, on the first boss id in load order). No `W_DUP_NAME`, no `W_FX_*`, no `E_FX_*`, no `W_BAND_HEALTH` (both new bosses are 30 = band 1 in `match_rules.json`).

### AC-1 — `ai_profile` resolves with zero `E_AI_*`

**Boot's stage-7b `ai_profile` registration is not on this branch**: lane 4 registers `map["ai_profile"] = BossAI.validate_ai_profile` in `src/core/boot.gd` in parallel, and it lands at merge. Until then the shipped load shows the pending row above, so AC-1's "zero `E_AI_*`" is proven two ways:

1. **Direct run of the validators** — `test_every_shipped_boss_ai_profile_resolves_with_zero_e_ai_rows` (`tests/integration/content/content_mvp1_data_test.gd`): `BossAI.validate_profiles_config(ai_profiles, db)` (7a, op coverage over every loaded card, the new `summon` / `aura` / `buff` / `choose_one` inner ops included) plus `BossAI.validate_ai_profile(&"boss", id, ai_profile, db, {ai_profiles})` over **every shipped BossDef** (3) → **zero rows**. `ProfileResolver.resolve` at band 1 gives Rat King the `aggro` and Gatekeeper the `control` `w_face`, `intent_mode` `full`; the overrides read `{extends: aggro}` / `{extends: control}`. **Seen failing**: with Rat King's `ai_profile` mutated to `boss_rat_kingx` the test reports `E_AI_PROFILE_UNKNOWN` (`record_id` `boss_rat_king`) and fails; restored.
2. **Trial of the merge line** (not committed; `boot.gd` reverted with `git checkout`): with `map["ai_profile"] = BossAI.validate_ai_profile` added to `_collect_validators()`, the validate command prints `Ready — 0 errors, 9 warnings, 55 records` — the pending `ai_profile` row disappears and no `E_AI_*` row appears.

### AC-2 / AC-3 — decks, cards, token

Pinned by `content_mvp1_data_test.gd` (10 tests for this story; real validators): both B1 rows; band 1 = Gatekeeper, Rat King, Torchbearer; both decks 30 non-token ids that all resolve (batch MVP-1 or earlier), with the counts above; the four B3 cards (type, cost, stats, keywords, text, `boss` / `common`), the matriarch's `all_friendly_minions {tag: rat}` aura; `boss_rat` 1/1 `rat` token, the `summon` target of the Rat King passive (×1, `end`) and of `boss_rat_pack` (×2), in no deck, pool or bundle, and no BossDef shares its id; `neutral_smite_or_mend` per CN-2 / row 33; `EffectValidator.validate_effects` → **zero rows** over both passives and every boss and neutral card.

**Neutral set is 14, not 15** (AC-3 "bringing the neutral set to 15"): `neutral_gravekeeper` stays deferred (story 001 deviation; the fix is a Boss AI `op_values` row for `add_counter`, which this story may not edit).

### Not evaluated here

- F4 boss pressure and the sim harness (AC-12/13) are the batch close, story 009. The GDD's own F4 example already puts Rat King above band 1 (9.56 vs 7 ± 1) and defers to the sim.
- Runtime of the Rat King summon, the Taunt aura and the matriarch aura is Card Effects work; Gatekeeper's two `neutral_smite_or_mend` need Boss AI `choose` scoring (BAI-010) before the boss can play them sensibly.

### Run result (same tree)

- `godot --headless --path . --import`: exit 0.
- `commands.test`: `1096 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans`, exit 0; 85 `SCRIPT ERROR` lines, the baseline count (negative tests).
- `commands.smoke` (`timeout 60 godot --headless --quit-after 5`): exit 0, no `SCRIPT ERROR`.
- `bash tools/lint/gates.sh .`: all gates 0 hits — PASS.
- `data_version` known-answer tests: none pins the shipped data. `content_batch0_data_test.gd` pinned the neutral set, band 1 and the boss set to their batch-0 rows exactly; those three now check the batch-0 rows are still present.

**Sign-off**: game-designer (data author) — NOT ASSESSED (lean, no agent). The two Rat King exclusions and the Gatekeeper fallback were chosen by the lane acting as game-designer; the owner may swap them.

**Result**: PASS (Config/Data, ADVISORY at story level) — `Ready`, 0 errors, zero `E_FX_*`, zero `E_AI_*` by direct run.
