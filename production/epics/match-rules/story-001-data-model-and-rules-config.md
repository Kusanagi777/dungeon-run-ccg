# Story 001: Match data model, derived values and rules config

> **Epic**: Match Rules
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-03

## Context

**GDD**: `design/gdd/match-rules.md` (C1 Data model, C3 step 1, F9 Limits, Tuning Knobs)
**Requirement**: `TR-match-rules-001`, `TR-match-rules-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Rules / Presentation Split (also ADR-0003: Seeded RNG Service and Event Log for the `rng_match` / `log` handles; ADR-0002 for `config("match_rules")`)
**ADR Decision Summary**: Everything under `src/gameplay/**` is `RefCounted`, takes its collaborators in `_init`, references no Node, autoload or scene, and runs headless; rules state is plain data and derived values are functions, never fields. `RulesEngine._init(db, rules_config, resolver)` is the normative constructor.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: HIGH by version (4.7 post-cutoff, `VERSION.md`); the APIs used (`RefCounted`, `Dictionary`, `Array`, `StringName`) predate 4.3 with no post-cutoff change. Typed `Array[Dictionary]` / `Array[int]` per `deprecated-apis.md`; an override of a typed method needs an explicit `return` (4.7). Every rules file must pass `.claude/scripts/godot-parse-check.gd` on its own.

This is the first story of the engine: the record shapes every later story mutates. `tests/helpers/match_factory.gd` already fixes the field names (C1 spelling: `damage_taken`, `base_attack`, `attacks_used`, `frozen_on_turn`, `cost_modifiers`, …) and carries the `TODO(E1 story)` swap marker; this story is that swap. The F9 constants and the other Tuning Knobs live in `assets/data/match_rules.json` (DD-T01) and reach the engine as the frozen `rules_config` Dictionary — never as literals in `src/`.

**Control Manifest Rules (this layer)**:
- Required: `RulesEngine` owns `MatchState`, `next_entity_id`, the phase machine … and the 24 primitives (ADR-0007); `RulesEngine._init(db, rules_config, resolver)` (ADR-0007, ADR-0005); `EffectRuntime {once_marks, counters, per_turn, pending_choice}` is plain data in `MatchState.effects` (ADR-0007)
- Forbidden: `EffectRuntime` never holds a Callable, a Node or an object reference (ADR-0007); never compile effects to GDScript Callables at load — Callables cannot live in `MatchState` (ADR-0007 Alt 2); rules code never names `Boot`, `get_tree()`, `$`, `await`, a `.tscn` or a global RNG call (ADR-0001 gates G1–G3, G6)
- Guardrail: `clone()` is measured per look-ahead node against `planner_target_ms` 50 p95 — keep the records flat (Dictionaries / Arrays of ints and Strings) so `duplicate(true)` stays cheap (ADR-0007)

---

## Acceptance Criteria

*From GDD `design/gdd/match-rules.md`, scoped to this story:*

- [ ] AC-41 **GIVEN** the engine source, **WHEN** grepped for the F9 constants (`BOARD_SIZE`, `HAND_SIZE`, `STARTING_HAND_PLAYER`, `STARTING_HAND_BOSS`, `MAX_MANA`, `HERO_POWER_COST`, `MULLIGAN_ROUNDS`, `TURN_CAP`, `RESOLUTION_STEP_CAP`, `MAX_ATTACKS_CAP`) and the Tuning Knobs (`STARTING_HEALTH_PLAYER`, `FATIGUE_BASE`, `FATIGUE_STEP`), **THEN** every value comes from `match_rules.json` (the `rules_config` passed to `_init`) and none is a literal in `src/` (no hardcoded values).
- [ ] C1 derived values **GIVEN** a `Character` with `base_health 2`, one enchantment `health_delta +2`, `damage_taken 3`, and a hero with a 2-attack Windfury weapon, **WHEN** the derived accessors are read, **THEN** `max_health == 4`, `health == 1`, hero `attack == 2`, `has_windfury == true`, `max_attacks == 2`, `attacks_remaining == 2 − attacks_used`; **AND** no field named `health`, `max_health`, `attack`, `max_attacks` or `attacks_remaining` is stored on any record (derived values are never stored).
- [ ] C1 / C3 step 1 **GIVEN** `RulesEngine._init(db, rules_config, resolver)` and `MatchFactory.make_match_config(...)`, **WHEN** the production `MatchState` is built from that config, **THEN** `MatchState` holds exactly `turn, active_side, phase, players{player, boss}, pending_choice, result, next_entity_id, hooks, effects, floor` plus references to `log` and `rng_match` taken from `MatchConfig`; `PlayerState`, `Character`, `Enchantment`, `Weapon`, `CardInstance`, `CommandResult` and `MatchResult` carry the field names `tests/helpers/match_factory.gd` produces; `GameAssertions.assert_json_representable` passes on `state_snapshot(entity_id)` output; and no record references a `Node` (DD-T02).

---

## Implementation Notes

*Derived from ADR-0001 Implementation Guidelines (and ADR-0007 Decision 1, ADR-0002):*

- Code under `src/gameplay/match/` **must** `extends RefCounted` (or be a plain Dictionary record with `to_dict()` / `from_dict()` wrappers) and **must** receive every collaborator through `_init(...)` or an explicit `bind(...)`. The constructor is `RulesEngine._init(db: CardDatabase, rules_config: Dictionary, resolver: EffectResolver)`; this story may stub the resolver parameter type until story 003 binds it.
- Records are plain data: `MatchState`, `PlayerState`, `Character` (heroes and minions share one representation — a hero adds `armor`, `base_attack = 0`; a minion adds `def_id`, `summoning_sick`, `summoned_on_turn`), `Enchantment {source_entity_id | null, attack_delta, health_delta, keywords_added[], is_aura, expires}`, `Weapon`, `CardInstance {instance_id, def_id, zone, cost_modifiers[]}`. `MatchState.effects` is the `EffectRuntime` plain-data bag `{once_marks: {}, counters: {}, per_turn: {}, pending_choice: null}` owned by Card Effects' resolver (ADR-0007) — create it empty here.
- Derived values are functions on the engine (or a static helper the engine owns): `max_health`, `health`, `attack` (hero = base + enchantments + `weapon.attack`), `has_windfury` (keyword, hero enchantment **or** the hero's weapon), `max_attacks = clamp(hooks.fold(modify_max_attacks, …), 0, MAX_ATTACKS_CAP)`, `attacks_remaining`. Until story 002 lands, `max_attacks` reads `2 if has_windfury else 1` clamped; story 002 adds the fold.
- `rules_config` is read **once** at construction and kept as a reference (architecture.md: owners never re-query per frame). Create `assets/data/match_rules.json` with `schema_version`, the F9 constants and the Tuning Knobs (`STARTING_HEALTH_PLAYER 30`, `FATIGUE_BASE 1`, `FATIGUE_STEP 1`, DD-M02/M04/M06/M07 defaults) — the Card Database loader (ADR-0002, DD-T01) validates it; tests pass the same body straight to `_init` via a `TestConstants`-aligned fixture, never through `Boot`.
- `state_snapshot(entity_id)` returns a value copy (`duplicate(true)`) for `MatchQuery`; `MatchState.clone()` itself is story 017.
- The `tests/helpers/match_factory.gd` swap is a **type change, not a rename** (ADR-0001): the factory keeps producing the same field names; where it used `[]` for `hooks` it will take a real `HookRegistry` in story 002.
- `TestConstants` is the one source of gameplay numbers in tests; never write `7`, `10`, `30` as literals in the new suite.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: `HookRegistry` / `HookEntry` / `HookInstaller` and the `modify_max_attacks` fold
- Story 003: `start(config)` — heroes, shuffle, starting hands, resolver bind
- Story 004: `submit`, `legal_commands`, rejection codes
- Story 017: `clone()`

---

## Files

*The code and test files this story creates or changes (replaced by /dev-story with the files it changed).*

- `src/gameplay/match/rules_engine.gd` — created (constructor, `rules_config` reference, `rule(key)`, `load_state` / `state`, derived-value accessors, `state_snapshot`)
- `src/gameplay/match/match_state.gd` — created (MatchState fields, `from_config`, `make_player_state`, `make_effect_runtime`)
- `src/gameplay/match/match_records.gd` — created (Character / hero / minion / Enchantment / Weapon / CardInstance / CommandResult / MatchResult builders)
- `assets/data/match_rules.json` — created (`schema_version` 1, `config` with the 14 F9 / Tuning Knob values)
- `tests/helpers/match_factory.gd` — modified (swap to production records and `MatchState`; `make_rules_config` fixture)
- `tests/helpers/test_constants.gd` — modified (`MAX_ATTACKS_WINDFURY` mirror; not in the planned list)
- `tests/unit/framework/test_helpers_test.gd` — modified (fixture states typed `MatchState` after the swap; not in the planned list)
- `tests/unit/match_rules/match_rules_data_model_test.gd` — created (17 test functions)
- `.godot/global_script_class_cache.cfg` — regenerated (MatchRecords, MatchState, RulesEngine)

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/match_rules/match_rules_data_model_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later). `qa.level: standard` — BLOCKING.

**Status**: [x] Created — 17 test functions, passing (full suite exit 0, 2026-11-03)

---

## Dependencies

- Depends on: None (first story of the epic; the Foundation epics `card-database` and `rng-event-log` supply `CardDatabase`, `RngStream` and `EventLog` — tests use `TestRngService` / `TestEventLog` doubles until they land)
- Unlocks: `production/epics/match-rules/story-002-hook-registry.md`, `production/epics/match-rules/story-003-match-setup.md`

## Completion Notes
**Completed**: 2026-11-03
**Criteria**: 3/3 passing — AC-41 `match_rules_data_model_test.gd::test_rules_json_has_config_envelope_with_tuning_knob_defaults`, `::test_engine_reads_every_knob_from_the_injected_rules_config`, `::test_engine_source_binds_no_knob_to_a_literal` (scanner first shown catching three deliberately broken lines); C1 derived values `::test_buffed_damaged_minion_derives_max_health_and_health`, `::test_hero_with_windfury_weapon_derives_attack_and_two_attacks`, `::test_no_record_stores_a_derived_value` (+ edge cases: `::test_hero_enchantment_grants_windfury_without_a_weapon`, `::test_weapon_without_windfury_leaves_one_attack`, `::test_removing_windfury_weapon_returns_max_attacks_to_one`, `::test_max_attacks_is_clamped_to_max_attacks_cap_from_config`, `::test_health_goes_non_positive_when_damage_reaches_max_health`, `::test_enchantment_removal_lowers_health_with_damage_unchanged`, `::test_attack_never_goes_below_zero`); C1 / C3 step 1 `::test_match_state_from_config_holds_exactly_c1_fields`, `::test_records_carry_the_c1_field_names`, `::test_state_snapshot_is_a_json_representable_value_copy`, `::test_no_record_references_a_node`
**Deviations** (all ADVISORY):
- `match_rules.json` keys are the GDD knob names in lowercase snake_case (`MAX_ATTACKS_CAP` → `max_attacks_cap`) per DD-T01 / `data-files.md` and `card_database.json`'s precedent; ADR-0005's `cfg.HAND_SIZE` pseudo-code and the GDD's UPPER_CASE names read as the same knobs. `MAX_ATTACKS_WINDFURY` (a Tuning Knobs row, not in AC-41's list) is in the file too, mirrored by a new `TestConstants.MAX_ATTACKS_WINDFURY`. The one rule literal is `RulesEngine.ATTACKS_PER_TURN = 1` (DD-M08/M10; no knob row exists).
- `max_attacks` has no `modify_max_attacks` fold yet. This story says story 002 adds it; story 002's Out of Scope and Files give the engine's call sites to stories 007/011/012, so the fold is left for story 012 (the clamp is already single and after `n`).
- API additions not in `architecture.md` §API Boundaries: `load_state(state)` (the seam until `start` in story 003, and for `clone` in 017), `rule(key)` and `rules_config()`. `state()` is ADR-0007's addition.
- `MatchState` has no `band` field (story AC and GDD C1 list none; `architecture.md` lists one). `MatchResult` gains `final_health{player, boss}` (GDD C14; `architecture.md` lists it, the old factory did not).
- `db` and `resolver` are `Variant` until `CardDatabase` / `EffectResolver` exist (the story allows the stub; `TODO` markers in `rules_engine.gd`); `MatchState.log` / `rng_match` are `RefCounted` so `TestEventLog` / `TestRngStream` fit.
- Two files outside the planned list: `tests/helpers/test_constants.gd` (one constant) and `tests/unit/framework/test_helpers_test.gd` (five fixture variables retyped `MatchState`, one JSON check narrowed to `state.players`) — both forced by the factory swap.
- Two unit tests read versioned repo files (`assets/data/match_rules.json`, the `src/` tree) as static checks, the QA plan's AC-41 approach.
**Test Evidence**: `tests/unit/match_rules/match_rules_data_model_test.gd` (17 tests); full suite `commands.test` exit 0, 185 test cases, 0 failures; mutation check (weapon branch of `has_windfury` → `return false`) observed failing, exit 100, then restored; ADR-0001 gates G1, G2, G2b, G3, G6 and the data-read gate: 0 hits under `src/gameplay/` (patterns first shown matching a broken sample)
**Run result**: N/A — headless `RefCounted` rules data with no scene, Node or rendered output; nothing reaches the screen until Match UI exists
**Reviewed by**: self, no independent review (QL-TEST-COVERAGE skipped — Lean mode; LP-CODE-REVIEW skipped — Lean mode; `/code-review` not run; engine-specialist check NOT ASSESSED — no agent spawned)
**Review fixes** (2026-11-03, `/code-review` of match-rules 001+002 / card-database 001, branch `fix/review-rules-data`): the two repo-file checks left the unit suite — `test_rules_json_has_config_envelope_with_tuning_knob_defaults` is now `tests/integration/match_rules/match_rules_config_file_test.gd::test_shipped_match_rules_loads_through_data_loader_with_the_tuning_knob_defaults` (loads through `DataLoader`, no `JSON.parse_string`) and `::test_engine_source_binds_no_knob_to_a_literal` moved there with its scanner, which now also flags numeric literals other than 0/1 passed to a bounding call (`clampi(n, 0, 4)`; seen failing on an injected line). `SAFE_RANGES` moved from the test into `RulesEngine.CONFIG_SAFE_RANGES`, pinned to the GDD table by `::test_config_safe_ranges_equal_the_gdd_tuning_knobs_safe_range_column`; the promised `match_rules` config validator is `RulesEngine.validate_rules_config(body, db)`, registered in `Boot._collect_validators` (`tests/unit/match_rules/match_rules_config_validator_test.gd`). `MatchFactory.find_entity` no longer crashes on a null hero.
