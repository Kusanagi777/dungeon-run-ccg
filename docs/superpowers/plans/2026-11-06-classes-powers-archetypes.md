# Classes, Powers and Archetypes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Grow Deckdelve from 3 to 6 classes with 3 earned hero powers each and 14 new archetypes, with no content ceilings and balance judged only between peers.

**Architecture:** Phase 1 makes sets data-driven and adds a relative balance report. Phase 2 adds per-run powers and rebuilds hero select. Phases 3 to 6 are mostly data. Phase 7 tunes and updates the docs.

**Tech Stack:** Godot 4.7.2, GDScript, gdUnit4, JSON data in `assets/data/`.

**Spec:** `docs/superpowers/specs/2026-11-06-classes-powers-archetypes-design.md`

## Global Constraints

- No upper limit on classes, cards, bundles, bosses or archetypes. Minimums may stay.
- Balance rules are relative only. The balance tool reports and never blocks a build.
- Adding a class after this plan needs data files only.
- Class order, ids and names: `hero_fortune` Lady Tallow, `hero_order` Warden Cassia, `hero_shadow` The Lamplighter.
- Each class has 3 powers: second at `floor_reached` n 5 with that class, third at `runs_won` n 1 with that class.
- Class unlocks: `hero_fortune` `runs_won` n 1; `hero_order` `floor_reached` n 5; `hero_shadow` `boss_defeated` n 8 with no `boss_id`.
- Boss powers (Mend, Drain, Reinforce, Brand) stay boss-only.
- Tolerances: class 5 points, power 5, archetype 7, boss 7 (`heroes_balance.json`).
- UI text goes through `tr`. Keyboard and gamepad must reach everything. Test at 100 % and 150 % text.
- UI displays state only and sends intents. All public methods get doc comments. Gameplay values live in data.
- After adding a `class_name`, run `godot --headless --path . --import` and keep the `.uid` and class cache changes.
- Commit only when the owner has authorised it. Messages use Conventional Commits and name this plan.

**Running tests (Git Bash):**

```bash
export GODOT_BIN="/c/Users/user/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe" PATH="$PWD/tools/bin:$PATH"
godot --headless -s -d --path . res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a <test file or folder> --ignoreHeadlessMode -c
```

`T <path>` below means this command. Read `Overall Summary`, not the exit code alone. The full suite outlasts one command, so run `tests/unit` and `tests/integration` separately. Tests and screenshots share `user://`, so never run them at the same time.

## Review Focus

- A saved run names a power that later data removed: the run resumes with the hero's starting power and warns, and does not crash.
- A class's power is locked when a run starts through a stale screen: the run is rejected, with a toast, and hero select stays usable.
- A new set's data is malformed or its art is missing: validation names the file, and the class still shows with its initial letter.
- Hero select has more classes than fit on screen: the roster scrolls and focus stays visible by keyboard and gamepad.
- The boss AI meets a power with `flip`: forecasting stays deterministic and never consumes the live match stream.

---

## Phase 1: Open growth

### Task 1: Clean baseline

**Files:** none new.

- [ ] **Step 1: Ask the owner to commit the current work.** The visual polish, drawer fix, Unlocks screen and specs are uncommitted, and `project.godot` holds an unrelated owner change that must be left out unless they say otherwise.
- [ ] **Step 2: Run `T tests/integration/run_ui`.** Expected: no failures. Fix any failure before Task 2, since this work has not passed a full run.

### Task 2: Sets come from data

**Files:**
- Modify: `src/core/data/record_schemas.gd:41-59,81,105,148`, `src/core/data/data_loader.gd:55-70,945`, `src/gameplay/heroes/heroes.gd:321`, `src/tools/content/content_validator.gd:300`, `tools/content/schemas/heroes.schema.json`, `tools/content/schemas/bundles.schema.json`, `tests/helpers/card_factory.gd:17`
- Test: `tests/integration/card_database/card_database_open_sets_test.gd`
- Create fixture: `tests/fixtures/data/open_set/` (a copy of `minimal` plus `cards_ember.json` and one `hero_ember`)

**Interfaces:**
- Produces: `DataLoader.discover_sets(root: String) -> PackedStringArray`, the sorted `<id>` of every `cards_<id>.json`; `RecordSchemas.SET_ID_PATTERN := "^[a-z][a-z0-9_]*$"`; `CardDatabase.sets() -> PackedStringArray`; `CardDatabase.hero_sets() -> PackedStringArray`.

- [ ] **Step 1: Write the failing tests** in `card_database_open_sets_test.gd`:

```gdscript
func test_a_set_made_only_of_data_files_loads_ready() -> void:
    var db := _load("res://tests/fixtures/data/open_set/")
    assert_int(db.state()).is_equal(CardDatabase.State.READY)
    assert_array(Array(db.hero_sets())).contains(["ember"])
    assert_bool(db.has("hero_ember")).is_true()

func test_a_hero_naming_a_set_with_no_file_is_e_missing_file() -> void:
    # hero set "ghost", no cards_ghost.json: the existing check still names the file
```

- [ ] **Step 2:** `T` that file. Expected: FAIL, `ember` rejected by the `enum`.
- [ ] **Step 3: Implement.** Replace the three `enum` set fields with a `set_id` kind that checks `SET_ID_PATTERN`. Delete `SETS`, `HERO_SETS` and `BUNDLE_SETS`. The loader's file table adds one row per discovered set and builds pools from `discover_sets`. `heroes.gd` and `content_validator.gd` read hero sets from the pool's heroes. JSON schemas use `"pattern"` in place of `enum`. `boss` and `neutral` stay non-hero sets by having no `HeroDef`.
- [ ] **Step 4:** `T tests/integration/card_database` and `T tests/unit/card_database`. Expected: PASS. Update tests that read the deleted constants to `db.sets()`.
- [ ] **Step 5: Commit.** `refactor(data): derive card sets from data files`

### Task 3: Remove ceilings

**Files:**
- Modify: `src/core/data/data_loader.gd:763-765`, `src/core/data/record_schemas.gd:62-68`, `assets/data/card_database.json`, `src/gameplay/heroes/heroes.gd:53-54`, `assets/data/heroes_balance.json`, `src/tools/content/content_validator.gd:96,159`, `assets/data/content_budgets.json`, `tools/content/schemas/content_budgets.schema.json`, `src/ui/match/match_ui_context.gd:14-15`, `src/ui/run/screens/run_log.gd:48-51,76`
- Test: existing suites; `tests/unit/content/content_starter_curve_warning_test.gd`, `tests/unit/ui/match_ui_set_colours_test.gd`

**Interfaces:**
- Produces: `ContentValidator.W_STARTER_CURVE`; palette convention `<set>` and `<set>2`, with `neutral` when absent.

- [ ] **Step 1: Write the failing tests:** a starter outside the curve returns a `W_STARTER_CURVE` row with warning severity; `MatchUiContext.card_face` for a card in set `ember` with palette tokens `ember` and `ember2` returns those colours, and with no tokens returns `neutral` without a `push_error`; `boss` still maps to `boss_band_1`.
- [ ] **Step 2:** `T` both. Expected: FAIL.
- [ ] **Step 3: Implement.** Delete `max_records`, `hero_set_size`, `hero_set_size_tol` and `neutral_set_size` from code, data, schemas and the test fixtures that declare them. Rename the starter code. Replace `SET_PRIMARY` and `SET_SECONDARY` with the palette convention. In `run_log.gd` replace the filter buttons with one `OptionButton` holding "All heroes" and each hero, sending the same local filter.
- [ ] **Step 4:** `T tests/unit/content`, `T tests/integration/content`, `T tests/integration/run_ui/run_ui_fixture_screens_test.gd`. Expected: PASS. Tests pinning a removed ceiling are deleted, with the spec's section 5 as the reason.
- [ ] **Step 5: Commit.** `feat(data): remove content ceilings`

### Task 4: Balance report

**Files:**
- Create: `src/tools/balance/balance_report.gd`, `tools/balance.sh`, `tests/integration/boss_ai/balance_main.gd`
- Modify: `src/gameplay/match/rules_engine.gd:597`, `tests/integration/boss_ai/sim_harness.gd:223-262`, `assets/data/heroes_balance.json`, `src/gameplay/heroes/heroes.gd`
- Test: `tests/unit/balance/balance_report_test.gd`

**Interfaces:**
- Produces: `RulesEngine.start` reads `config.player.get("hero_power", hero_def.hero_power)`; `BossAiSimHarness.run` accepts `opponent.hero_power: String`; `BalanceReport.compare(rates: Dictionary, tolerance: float) -> Array[Dictionary]`, rows `{id, rate, median, gap, out_of_tolerance}` sorted by id; `BalanceReport.render(groups: Dictionary) -> String`; `heroes_balance.balance` = `{class_tol: 5, power_tol: 5, archetype_tol: 7, boss_tol: 7, seeds: 40}`.

- [ ] **Step 1: Write the failing tests:**

```gdscript
func test_a_rate_past_tolerance_from_the_median_is_flagged() -> void:
    var rows := BalanceReport.compare({"a": 50.0, "b": 52.0, "c": 60.0}, 5.0)
    assert_float(rows[2].median).is_equal(52.0)
    assert_bool(rows[2].out_of_tolerance).is_true()
    assert_bool(rows[1].out_of_tolerance).is_false()

func test_exactly_tolerance_is_in_tolerance() -> void:
    assert_bool(BalanceReport.compare({"a": 50.0, "b": 55.0, "c": 55.0}, 5.0)[0].out_of_tolerance).is_false()

func test_the_engine_seats_the_configured_player_power() -> void:
    # a MatchConfig with player.hero_power "power_mend" seats that def_id, and omitting it seats the hero's own
```

- [ ] **Step 2:** `T tests/unit/balance`. Expected: FAIL.
- [ ] **Step 3: Implement.** `balance_main.gd` is a `SceneTree` like `sim_main.gd`, with arguments `--class`, `--boss`, `--archetype`, `--seeds`, `--out`. For each hero and power it plays sampled bosses from seeds derived with a fixed base. An archetype run uses the starter plus that archetype's bundles, removing the lowest-synergy cards to keep the deck legal. It prints the four peer tables and overall win rate, and writes `production/qa/balance/<date>.md`. It exits 0 unless it could not run. `Heroes.validate_config` checks the new block.
- [ ] **Step 4:** `T tests/unit/balance`. Expected: PASS. Then run `bash tools/balance.sh --seeds 10` twice and diff the tables. Expected: identical.
- [ ] **Step 5: Keep the baseline report and commit.** `feat(tools): add relative balance report`

## Phase 2: Power system

### Task 5: Extra power data and unlocks

**Files:**
- Modify: `src/core/data/record_schemas.gd:105-110`, `src/core/data/data_loader.gd:458`, `src/gameplay/meta/unlock_evaluator.gd:44-52`, `tools/content/schemas/heroes.schema.json`, `assets/data/heroes.json`, `assets/data/hero_powers.json`, `assets/art/art_map.json`, `assets/data/match_ui.json`, `assets/data/run_ui.json`, `src/tools/content/content_validator.gd`, `tests/unit/ui/art_library_test.gd`
- Test: `tests/unit/heroes/heroes_extra_powers_test.gd`

**Interfaces:**
- Produces: `HeroDef.extra_powers: Array[{power: String, unlock: {key, condition}}]`, required, exactly 2; `UnlockEvaluator` record kind `&"power"` keyed by power id; `Heroes.powers_of(hero_id: String) -> PackedStringArray`, starting power first.

- [ ] **Step 1: Write the failing tests:** `powers_of("hero_decay")` is `["power_rot", "power_harvest", "power_raise"]`; a hero with one `extra_powers` row fails with `E_COUNT`; a row naming an unknown power fails with the ref error; a power owned by two heroes or by a boss fails validation; `unlock_hint("power_harvest")` has `target` 5 on a real `MetaFacade`.
- [ ] **Step 2:** `T` it. Expected: FAIL.
- [ ] **Step 3: Implement** the schema, reference checks and evaluator rows. Add `power_battle_cry`, `power_brace`, `power_harvest`, `power_raise`, `power_frostbind`, `power_study` with the spec's text. Add their `art_map.json` `powers` stamps (`banner`, `shield`, `grave`, `skull_warm`, `frost`, `scroll`) and strings. War: Battle Cry, Brace. Decay: Harvest, Raise. Knowledge: Frostbind, Study.
- [ ] **Step 4:** `T tests/unit/heroes`, `T tests/unit/ui/art_library_test.gd`, `T tests/integration/content`. Expected: PASS.
- [ ] **Step 5: Commit.** `feat(heroes): add extra powers with unlocks`

### Task 6: A run carries its power

**Files:**
- Modify: `src/gameplay/run/run_machine.gd:145,571,735`, `src/gameplay/run/run_state.gd:50,238`, `src/gameplay/run/run_record.gd:39,75,114`, `src/gameplay/run/run_codes.gd:19,103`, `src/gameplay/meta/meta_api.gd`, `src/gameplay/meta/meta_facade.gd`, `src/gameplay/meta/meta_stub.gd`, `src/ui/run/run_controller.gd:265,343,354`, `assets/data/run_ui.json`
- Test: `tests/integration/run/run_hero_power_test.gd`

**Interfaces:**
- Consumes: `Heroes.powers_of`, `MatchConfig.player.hero_power`.
- Produces: `RunMachine.new_run(hero_id: String, seed_input: String, power_id: String = "") -> Error`, empty meaning the starting power; `RunCodes.E_POWER_LOCKED`; `RunState.hero_power_id: String`; `MetaApi.is_power_unlocked(power_id: String) -> bool`; intent `start_run` takes `power_id`; event `run_started` gains `hero_power_id`; string `rejected.E_POWER_LOCKED`.

- [ ] **Step 1: Write the failing tests:** an unlocked extra power reaches `player.hero_power` in the next `MatchConfig`; a locked one returns `E_POWER_LOCKED` with no save and no event; a power from another hero returns `E_UNKNOWN_ID`; empty means the starting power; the field round-trips through `RunRecord`; a record without it reads as the starting power; **a record naming a removed power resumes on the starting power and logs a warning** (Review Focus).
- [ ] **Step 2:** `T` it. Expected: FAIL.
- [ ] **Step 3: Implement.** Run records stay at schema version 1. Add `W_POWER_REMOVED` beside the other run warnings. `RunMachine` checks ownership through `Heroes.powers_of`, at `new_run` and again on resume. Confirm what happens to a save from another `data_version` and record it for the patch notes.
- [ ] **Step 4:** `T tests/integration/run`, `T tests/integration/run_ui/run_ui_controller_test.gd`. Expected: PASS.
- [ ] **Step 5: Commit.** `feat(run): carry the chosen hero power through a run`

### Task 7: Hero select roster

**Files:**
- Rewrite: `src/ui/run/screens/hero_select.gd`
- Modify: `src/ui/run/run_read_models.gd:64-72,456-492`, `design/ux/hero-select.md`, `assets/data/run_ui.json`, `tests/integration/run_ui/run_ui_fixture_screens_test.gd`, `tests/integration/run_ui/run_ui_keyboard_test.gd`
- Test: `tests/integration/run_ui/run_ui_hero_roster_test.gd`

**Interfaces:**
- Consumes: `start_run {hero_id, seed_input, power_id}`.
- Produces: read model `hero_select.heroes[]` includes locked classes with `{id, name, unlocked, hint, powers: [{id, name, cost, text, unlocked, condition}], selected_power}`. `selected_power` is the last power played with that class from the run log, else the starting power.

- [ ] **Step 1: Write the failing tests:** every class has a tab; a locked class focuses, shows its hint and disables Start; a locked power cannot be selected and shows its condition; the chosen `power_id` reaches `start_run`; one `DeckDrawer` exists and follows the focused class; with 12 fixture classes the roster scrolls and the focused tab stays in view (Review Focus); `ui_up` and `ui_down` move between tabs; a class with no art shows its initial (Review Focus).
- [ ] **Step 2:** `T` it. Expected: FAIL.
- [ ] **Step 3: Implement** to section 2 of the spec. Tab column at x 40, width 96, in a `UiKit.scroll()`. Detail panel at x 152 to 1240, y 72 to 520. Keep `SEED_RECT`, `BACK_POS`, `START_POS` and `DECK_POS`. Reuse `CurveBars` and `UiKit.stamp`. A rejected Start shows the toast and stays on the screen. Rewrite `hero-select.md` to match.
- [ ] **Step 4:** `T tests/integration/run_ui`. Expected: PASS. Tests tied to panel slots change with the new UX doc.
- [ ] **Step 5: Capture and look.** `bash tools/capture.sh res://src/scenes/main.tscn production/qa/evidence/hero-roster 30 -- --run-ui-screen=hero_select --run-ui-fixture=<fresh_profile, locked_heroes, locked_heroes_ts150>`. Expected: nothing clipped.
- [ ] **Step 6: Commit.** `feat(ui): rebuild hero select as a roster with power choice`

### Task 8: Powers on the Unlocks screen

**Files:**
- Modify: `src/ui/run/run_read_models.gd` (`unlocks`, `_unlock_row`, `_condition_text`), `src/ui/run/screens/unlocks.gd`, `src/gameplay/meta/unlock_evaluator.gd:153`, `assets/data/run_ui.json`
- Test: `tests/integration/run_ui/run_ui_unlocks_model_test.gd`

- [ ] **Step 1: Write the failing tests:** a fresh profile lists 6 power rows under a Powers section with the condition "Reach floor 5 as Mother Wythe"; a `boss_defeated` condition with no `boss_id` reads "Defeat 8 bosses"; `SHIPPED_GATED_TREASURES` rows still appear.
- [ ] **Step 2:** `T` it. Expected: FAIL.
- [ ] **Step 3: Implement.** Add `unlocks.kind.power` "Powers", `unlock.condition.boss_defeated_any` "Defeat {n} bosses", and choose that key when `boss_id` is absent. Power rows use `ArtLibrary.power_stamp`, tinted ink.
- [ ] **Step 4:** `T` it. Expected: PASS.
- [ ] **Step 5: Commit.** `feat(ui): list hero powers on the Unlocks screen`

## Phase 3: Fortune

### Task 9: The `flip` condition

**Files:**
- Modify: `src/gameplay/effects/effect_schema.gd:197`, `src/gameplay/effects/effect_validator.gd:615`, `src/gameplay/effects/values.gd:241`, `src/gameplay/effects/selectors.gd:145`, `src/ui/match/feed_lines.gd`, `assets/data/match_ui.json`
- Test: `tests/unit/card_effects/effect_flip_test.gd`

**Interfaces:**
- Produces: condition `{"flip": <1-99>}`, true at that percentage; event `coin_flipped {won: bool}`.

- [ ] **Step 1: Write the failing tests:** one seed gives the same results twice; 1000 flips at 50 fall within 450 to 550; each flip draws exactly once from `rng_match`; `{"flip": 0}`, `100` and `"x"` fail with `E_FX_SCHEMA`; a flip in a forecast sandbox leaves the live stream untouched (Review Focus); the feed shows heads or tails.
- [ ] **Step 2:** `T` it. Expected: FAIL.
- [ ] **Step 3: Implement** in `EffectValues.holds` using `resolver.bound_engine().rng_match()`. The static validator treats `flip` as unknown at validation time, like other runtime conditions.
- [ ] **Step 4:** `T tests/unit/card_effects`, `T tests/integration/boss_ai`. Expected: PASS. If the planner cannot score it, score a flip as its average outcome, as the spec allows.
- [ ] **Step 5: Commit.** `feat(effects): add the flip condition`

### Task 10: A new class, Fortune

Tasks 11 and 12 repeat this task with their own values.

**Files:**
- Create: `assets/data/cards_fortune.json`
- Modify: `assets/data/heroes.json`, `assets/data/hero_powers.json`, `assets/data/bundles.json`, `assets/data/heroes_balance.json`, `assets/data/run_ui.json`, `assets/data/match_ui.json`, `assets/art/art_map.json`, `THIRD_PARTY_ART.md`, `tests/integration/card_database/card_database_shipped_data_test.gd`
- Test: `tests/integration/content/content_class_fortune_test.gd`

Values: 25 cards, about 8 per archetype: Gamble, Hoard, Jackpot, tags `gamble`, `hoard`, `jackpot`. Token `fortune_coin`, cost 0, "Gain 1 mana this turn." Powers `power_toss` (uses `flip`), `power_loaded_die`, `power_stake`. Palette `fortune` and `fortune2`: coin gold and soot, each at 4.5:1 against `text_light`. Portrait `coins`. Bundles: 8, at least 2 per archetype, 3 cards each.

- [ ] **Step 1: Write the failing test:** the hero exists with `unlock.key` `hero_fortune` and its condition; `Heroes.powers_of` returns the three powers; each archetype tag has at least 5 cards and 2 bundles; every card and power resolves a stamp; `ContentValidator.run_checks` returns no `E_` rows; a fresh profile's hero select shows the class locked.
- [ ] **Step 2:** `T` it. Expected: FAIL.
- [ ] **Step 3: Design the cards in data.** Cards use existing ops. For Hoard, first test whether a card can read a counter held on another entity; if not, count Coins with `{"holding": {...}}` as the spec allows. Starter deck: 15 cards inside `starter_curve`, holding a playable plan. Write `hero.blurb.fortune`, `theme.*`, and `hero_fortune` identity text with the `writer` agent's voice rules. Keep text under `text_max_chars`.
- [ ] **Step 4:** `T` it, then `T tests/integration/content`, and run `godot --headless --path . -s res://tools/content/validate.gd`. Expected: PASS, exit 0.
- [ ] **Step 5: Run `bash tools/balance.sh --class hero_fortune`.** Adjust numbers until its class and powers are in tolerance, or record why not.
- [ ] **Step 6: Capture** a match using a new `fortune_midgame` fixture, and look at it.
- [ ] **Step 7: Commit.** `feat(content): add the Fortune class`

## Phase 4: Order

### Task 11: A new class, Order

Same files and steps as Task 10, with `order` in place of `fortune`.

Values: archetypes Formation, Aegis, Oath; tags `formation`, `aegis`, `oath`. Powers `power_ward`, `power_stand_fast`, `power_muster`, with token `order_recruit` (1/2, Taunt). Palette: ivory, steel. Portrait `helmet`. Formation reads `owner.board_size` and uses `adjacent`. Its auras must not grant `stealth` or `divine_shield` (`AURA_UNGRANTABLE_KEYWORDS`).

- [ ] **Step 1 to 7:** as Task 10. Commit: `feat(content): add the Order class`

## Phase 5: Shadow

### Task 12: A new class, Shadow

Same files and steps as Task 10, with `shadow` in place of `fortune`.

Values: archetypes Stealth, Venom, Ambush; tags `stealth`, `venom`, `ambush`. Powers `power_garrote`, `power_vanish`, `power_envenom`. Palette: charcoal, violet. Portrait `hood`. Ambush reads `owner.cards_played_this_turn`. Unlock `hero_shadow`, `boss_defeated` n 8.

- [ ] **Step 1 to 7:** as Task 10. Commit: `feat(content): add the Shadow class`

## Phase 6: Archetypes

### Task 13: Berserk, Plague, Frost

**Files:**
- Modify: `assets/data/cards_war.json`, `cards_decay.json`, `cards_knowledge.json`, `bundles.json`, `heroes_balance.json`, `run_ui.json`, `assets/art/art_map.json`
- Test: `tests/integration/content/content_archetypes_test.gd`

Values: 6 cards and 2 bundles each. Tags `berserk`, `plague`, `frost`. Berserk checks for a damaged-minion filter first, falling back to `on_damage_taken`.

- [ ] **Step 1: Write the failing test:** each tag has 6 cards and 2 bundles, every card resolves a stamp, and no existing card id changed.
- [ ] **Step 2:** `T` it. Expected: FAIL.
- [ ] **Step 3: Design the cards and bundles in data.**
- [ ] **Step 4:** `T` it, `T tests/integration/content`, and run validation. Expected: PASS.
- [ ] **Step 5: Commit.** `feat(content): add Berserk, Plague and Frost`

### Task 14: Pack and Salvage

Same shape as Task 13, in `cards_neutral.json`. Values: 6 cards and 2 bundles each. Tags `pack`, `salvage`. Neutral cards must draft for every class, so check them with each `plan_tags` entry.

- [ ] **Step 1 to 5:** as Task 13. Commit: `feat(content): add Pack and Salvage`

## Phase 7: Balance and docs

### Task 15: Final balance

**Files:** `assets/data/*` numbers only; `production/qa/balance/`.

- [ ] **Step 1:** Run `bash tools/balance.sh` with the configured seeds.
- [ ] **Step 2:** Tune anything out of tolerance, in this order: powers, archetypes, classes, bosses. Change numbers, not card identities.
- [ ] **Step 3:** Rerun. Expected: all groups in tolerance, or each exception listed for the owner with its gap.
- [ ] **Step 4:** Compare overall win rate with the Task 4 baseline and report any drift to the owner.
- [ ] **Step 5: Commit.** `balance: tune classes, powers, archetypes and bosses against each other`

### Task 16: Docs and full verification

**Files:** `design/gdd/game-concept.md`, `design/gdd/heroes.md`, `design/gdd/content.md`, `design/gdd/meta-progression.md`, `design/art/art-bible.md`, `CHANGELOG.md`

- [ ] **Step 1:** Replace the "Small" content target with the open-growth rule and relative balance. Move H-7 into shipped heroes with the real unlocks.
- [ ] **Step 2:** Run `T tests/unit`, then `T tests/integration`. Compare the `Overall Summary` count with the `func test_` count. Expected: no failures.
- [ ] **Step 3:** Capture hero select at 100 % and 150 %, Unlocks, and a match per new class into `production/qa/evidence/six-classes/`, then look at each.
- [ ] **Step 4:** Time `CardDatabase.load` once on the shipped data and record it in `production/qa/balance/`, so data growth has a baseline.
- [ ] **Step 5:** Note in `CHANGELOG.md` that runs in progress may not resume, using what Task 6 found.
- [ ] **Step 6: Commit.** `docs: record six classes and open growth`
