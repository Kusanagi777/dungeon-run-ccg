## Smoke Record — content story 002 (MVP-1 War set)
**Date**: 2026-11-04
**Story**: `production/epics/content/story-002-mvp-1-war-set.md` (Config/Data)
**Engine**: Godot 4.7.2 (`4.7.2.stable.official.ed1daf0bf`, editor binary = debug build)
**QA Plan**: `production/qa/qa-plan-sprint-004-2026-11-04.md` is not on this branch (written in parallel); this record works from the story's acceptance criteria.
**Run by**: sprint-4 lane 5 `lane/s4-l5-content` (owner's standing approval). This is the story's per-story Config/Data record, not the sprint's `/smoke-check` report.

### What changed

`assets/data/cards_war.json`: the 17 MVP-1 War cards of the CN-2 War table appended (`war_blade_strike`, `war_throwing_axe`, `war_blade_apprentice`, `war_armorer`, `war_cellar_raider`, `war_berserker`, `war_heavy_maul`, `war_cleave_through` ◆, `war_rally`, `war_shieldwall_veteran`, `war_shield_maiden`, `war_duelists_edge` ◆, `war_pit_champion` ◆, `war_twin_hatchets`, `war_warlord`, `war_kingsblade`, `war_headsman`). The 8 batch-0 records and the `war_whetstone_blade` token are byte-identical to before.

### Content validate command (content story 007) on the shipped data

`godot --headless --path . -s res://tools/content/validate.gd` (editor binary, debug) → **exit 0**.

| | Before (HEAD `1d03416`) | After |
|---|---|---|
| State | `Ready` | `Ready` |
| Errors | 0 | **0** |
| Warnings | 11 | **10** |
| Records | 30 | **47** (+17 War cards) |
| `W_POOL_SIZE` | 3 (bundle 3 < 10, **collectible war 21 < 30**, treasure 0 < 6) | **2** (bundle 3 < 10, treasure 0 < 6) |
| Load ms (observation, never asserted; budget `data_load_budget_ms` 200) | 14.57 | 12.45 |
| `data_version()` | — | `e2d8c276decc9b35` |

The collectible War pool is now 25 War + 13 neutral = 38 ≥ `min_collectible_pool` 30, so its `W_POOL_SIZE` row is gone. Load report after (verbatim):

```
[warning] E_DELEGATED bosses.json#boss_torchbearer.ai_profile — W_VALIDATOR_PENDING: `ai_profile` (host kind boss) is not checked: its owner Boss AI has not shipped the validator (BossDef `ai_profile`)
[warning] W_POOL_SIZE bundles.json.min_bundle_pool — bundle pool for war: 3 < 10 (n_bundles(war) + n_bundles(neutral) vs min_bundle_pool)
[warning] E_DELEGATED heroes_balance.json — W_VALIDATOR_PENDING: configs.heroes_balance is not checked: its owner Heroes has not shipped validate_config
[warning] E_DELEGATED match_ui.json — W_VALIDATOR_PENDING: configs.match_ui is not checked: its owner Match UI has not shipped validate_config
[warning] E_DELEGATED profile_defaults.json — W_VALIDATOR_PENDING: configs.profile_defaults is not checked: its owner Meta Progression has not shipped validate_config
[warning] E_DELEGATED reward_draft.json — W_VALIDATOR_PENDING: configs.reward_draft is not checked: its owner Reward Draft has not shipped validate_config
[warning] E_DELEGATED run_structure.json — W_VALIDATOR_PENDING: configs.run_structure is not checked: its owner Run Structure has not shipped validate_config
[warning] E_DELEGATED run_ui.json — W_VALIDATOR_PENDING: configs.run_ui is not checked: its owner Run UI has not shipped validate_config
[warning] W_POOL_SIZE treasures.json — 0 < 6: treasures unlocked by default vs min_treasure_pool (2 treasure drafts × 3 offers, no repeats in a run)
[warning] E_DELEGATED treasures_balance.json — W_VALIDATOR_PENDING: configs.treasures_balance is not checked: its owner Treasures has not shipped validate_config
validate: Ready — 0 errors, 10 warnings, 47 records; load ms 12.45 (data_load_budget_ms 200) — root res://assets/data/
```

Warnings triage (CN-6 step 3): `W_POOL_SIZE` ×2 (bundles — story 005; treasures — story 006); `W_VALIDATOR_PENDING` ×8 (pending owners; an error in an exported build). **No `W_DUP_NAME`, no `W_FX_KEYWORD_MISMATCH`, no `W_FX_*`, no `E_FX_*`.**

### AC-1 / AC-2 (records, effects, text)

Pinned by `tests/integration/content/content_mvp1_data_test.gd` (8 tests, real validators, no `accept_all()`): 25 non-token War cards + the token; every card's id, name, type, cost, stats, keywords, `text.en`, rarity and tags equal its CN-2 row; the three signature cards and `war_shield_maiden` / `war_shieldwall_veteran` are collectible; `EffectValidator.validate_effects` returns **zero rows** over all 26 War hosts; no `W_DUP_NAME` / `W_FX_KEYWORD_MISMATCH` in the load report; every `text.en` ≤ `text_max_chars` 90 (longest: `war_cleave_through`, 73).

Effect shapes used (C11 rows): `war_blade_strike` row 6 verbatim (`ref owner.weapon_attack`, `spell_damage: false`); `war_blade_apprentice` row 2 + 4 (effect `condition {not: {exists: owner_weapon}}` → `equip war_whetstone_blade`); `war_armorer` row 5 + 6 (`armor` with `ref owner.weapon_attack`); `war_berserker` row 11 (`on_damage_taken {who: self}` → `buff self +2 attack`); `war_cleave_through` row 3 + 4 (`all_enemy_minions`, `conditional exists owner_weapon` → 3 else 2); `war_duelists_edge` row 5 on a weapon host; `war_pit_champion` row 15 (`buff keywords [windfury] until_end_of_turn` on `owner_hero`); `war_warlord` row 26 (`not_self`, `aura attack 1`); `war_kingsblade` row 3; `war_headsman` `destroy` on `chosen {kind: minion, is_damaged: true}`; the rest `armor`, `buff`, `damage` or keywords only.

### AC-3 (set balance) — evaluated by hand (story 008's checks are not on this branch)

**F1 / Heroes F4** (`heroes_balance.json` `set_share.war` 0.52 / 0.24 / 0.24, `set_share_tol` 0.08): 13 M / 6 S / 6 W of 25 → 0.52 / 0.24 / 0.24 — all on target. Also pinned by `test_war_type_shares_are_within_set_share_tolerance`.

**F2** (`content_budgets.json` `curve`): Σ cost 79 / 25 = **3.16** ∈ [2.9, 3.4]; buckets 1:4 2:6 3:6 4:4 5:2 6:2 7:1 = the CN-2 summary. Bucket shares vs target ± 0.08: ≤1 0.16 / 0.16 · 2 0.24 / 0.22 · 3 0.24 / 0.24 · 4 0.16 / 0.18 · 5 0.08 / 0.10 · ≥6 0.12 / 0.10 — all within. Pinned by `test_war_curve_matches_the_cn2_summary_and_f2_targets`.

**F3** (`budget.tol` C 1.5 / R 2.0 / L 3.0; points from `budget.keyword_tax` / `effect_points`). Modelling assumptions where the GDD leaves one open: expected weapon Attack 2 (Whetstone Blade / Rusted Axe) for `ref owner.weapon_attack` and a hero Windfury swing; "expected 3 bodies" for friendly-board buffs as for enemy AoE; a conditional takes its expected branch (War expects a weapon); a weapon's on-attack trigger fires once per durability.

| Card | R | Cost | Value | Budget | Δ | In tol |
|---|---|---|---|---|---|---|
| war_shield_squire | C | 1 | 3 + armor 1.0 = 4.0 | 3 | +1.0 | ✓ |
| war_sharpen | C | 1 | buff 2 = 2.0 | 2 | 0 | ✓ |
| war_blade_strike | C | 1 | 2 × 1.5 = 3.0 | 2 | +1.0 | ✓ |
| war_throwing_axe | C | 1 | 1 + 1.5 = 2.5 | 2 | +0.5 | ✓ |
| war_rusted_axe | C | 2 | 4 | 4 | 0 | ✓ |
| war_warcry | C | 2 | +1 × 3 = 3.0 | 4 | −1.0 | ✓ |
| war_blade_apprentice | C | 2 | 4 + equip 1/2 (2) = 6.0 | 5 | +1.0 | ✓ |
| war_armorer | R | 2 | 5 + armor 2 × 0.5 = 6.0 | 5 | +1.0 | ✓ |
| war_cellar_raider | C | 2 | 4 + rush 1 = 5.0 | 5 | 0 | ✓ |
| war_iron_resolve | C | 2 | 2.0 + 2.5 = 4.5 | 4 | +0.5 | ✓ |
| war_iron_vanguard | C | 3 | 6 + taunt 1 = 7.0 | 7 | 0 | ✓ |
| war_quartermaster | C | 3 | 5 + draw 2.5 = 7.5 | 7 | +0.5 | ✓ |
| war_berserker | R | 3 | 5 + buff 2 = 7.0 | 7 | 0 | ✓ |
| war_heavy_maul | W/C | 3 | 6 + armor 1.0 = 7.0 | 7 | 0 | ✓ |
| **war_cleave_through** | R | 3 | AoE 3 × 3.0 = 9.0 (weapon branch; 6.0 without) | 6 | **+3.0** | **✗** |
| war_rally | C | 3 | +2 × 3 = 6.0 | 6 | 0 | ✓ |
| war_pit_brawler | C | 4 | 7 + charge 2 = 9.0 | 9 | 0 | ✓ |
| war_shieldwall_veteran | C | 4 | 7 + 1 + 1.5 = 9.5 | 9 | +0.5 | ✓ (GDD F3 example) |
| war_shield_maiden | R | 4 | 6 + 1 + 2 = 9.0 | 9 | 0 | ✓ |
| **war_duelists_edge** | R | 4 | 9 + armor 2 × 3 swings × 0.5 = 12.0 | 9 | **+3.0** | **✗** |
| war_pit_champion | L | 5 | 10 + one extra swing 2 = 12.0 | 11 | +1.0 | ✓ |
| war_twin_hatchets | R | 5 | 8 + windfury 2 = 10.0 | 11 | −1.0 | ✓ |
| war_warlord | R | 6 | 10 + aura +1 × 3 = 13.0 | 13 | 0 | ✓ |
| war_kingsblade | L | 6 | 8 + 6 = 14.0 | 14 | 0 | ✓ (GDD F3 example) |
| war_headsman | L | 7 | 10 + destroy (restricted) 3.0 = 13.0 | 15 | −2.0 | ✓ |

Two cards are outside `BUDGET_TOL` (would be `W_BUDGET`), both War signature rares; accepted deviations with reasons in the story's Implementation Notes: `war_cleave_through` (+3.0 on the weapon branch, 0 without — the sweeper CN-3 B2 names as War's answer to Gatekeeper and Hollow King) and `war_duelists_edge` (+3.0 — the armour plan's payoff, valued only if the hero swings three times). `/balance-check` revisits both at the MVP-1 batch close (story 009).

### Run result (same tree)

- `godot --headless --path . --import`: exit 0.
- `commands.test`: `1086 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans`, exit 0; 85 `SCRIPT ERROR` lines, the batch-0 baseline count (all from negative tests).
- `commands.smoke` (`timeout 60 godot --headless --quit-after 5`): exit 0, no `SCRIPT ERROR`.
- `bash tools/lint/gates.sh .`: all gates 0 hits — PASS.
- `data_version` known-answer tests: none pins the shipped data (the fingerprint tests use fixtures), so none changed. `content_batch0_data_test.gd` pinned the batch-0 War set and `W_POOL_SIZE` files exactly; it now checks the batch-0 rows are still present and lists `W_POOL_SIZE` for `bundles.json` and `treasures.json` only.

**Sign-off**: game-designer (data author) — NOT ASSESSED (lean, no agent; the lane authored from the CN-2 table).

**Result**: PASS (Config/Data, ADVISORY at story level) — `Ready`, 0 errors, zero `E_FX_*`.
