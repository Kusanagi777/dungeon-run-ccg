# Story 001: War hero seated from its `HeroDef` — Whetstone on shipped data

> **Epic**: Heroes
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-11-04
> **Last Updated**: 2026-11-04
> **First Playable path**: yes — the War match needs the hero's health and Whetstone from data, not from a test setting

## Context

**GDD**: `design/gdd/heroes.md` (H-1, H-3, Edge Cases "Whetstone", AC-7, AC-8, AC-19) · `design/gdd/match-rules.md` C3 step 2
**Requirement**: `TR-heroes-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Data format, effect schema/DSL and `config()` loading (most direct); ADR-0007: Effect Resolver / Validator Boundary
**ADR Decision Summary**: A hero is a `HeroDef` record read through `CardDatabase`; nothing hero-specific lives in code (ADR-0002). The hero power is a `hero_power`-trigger effect on its `HeroPowerDef`, resolved by `EffectResolver` through engine primitives only (ADR-0007).
**ADR Version**: 2026-11-03 (ADR-0002); 2026-11-03 (ADR-0007)

**Engine**: Godot 4.7.2 | **Risk**: HIGH (by version; the APIs used — `RefCounted`, `Dictionary`, `Array` — predate 4.3 and are LOW)
**Engine Notes**: ADR-0002 / ADR-0007 Engine Compatibility — no post-cutoff API. An override of a typed method returns explicitly (4.7) if a test double is written.

**Control Manifest Rules (this layer)**:
- Required: `MatchConfig` is the engine's only input (`player {hero_def_id, deck, hook_installers}`); config bodies are read once at construction; every gameplay value comes from data
- Forbidden: never a numeric gameplay literal in run code; never write match state from `src/gameplay/effects/**` (gate G7)
- Guardrail: `RulesEngine.submit()` ≤ 5 ms; `legal_commands()` ≤ 2 ms

The engine still seats the player hero from the knob `starting_health_player` and leaves `PlayerState.hero_power.def_id` empty (`TODO(card-database story 006)` in `RulesEngine.start`, noted open by match-rules stories 003 and 010; every hero-power test so far sets `def_id` itself). Match-rules C3 step 2 says player health is the hero record's `health`. No story owns that line, and the First Playable War match cannot use Whetstone until it is closed, so this epic takes it.

---

## Acceptance Criteria

*From GDD `design/gdd/heroes.md` (H-1, H-3, AC-7, AC-8, AC-19) and `design/gdd/match-rules.md` C3 step 2, scoped to this story:*

- [x] **AC-1 (H-1, match-rules C3.2)** GIVEN the shipped `assets/data/` and a `MatchConfig` with `player.hero_def_id = "hero_war"`, WHEN `RulesEngine.start` runs, THEN the player hero's `base_health` equals `db.hero("hero_war").health` (30) and `PlayerState.hero_power.def_id == "power_whetstone"`, read from the record and not set by the test; GIVEN a fixture `HeroDef` with `health: 27`, THEN the hero seats at 27/27 with no code change.
- [x] **AC-7** GIVEN War on shipped data with no weapon and 2 mana, WHEN `use_hero_power`, THEN the events are `hero_power_used`, `weapon_equipped(war_whetstone_blade)`; hero attack = 1, durability 2, mana 0.
- [x] **AC-8** GIVEN War on shipped data holding a 2/2 weapon (`war_rusted_axe`), WHEN `use_hero_power`, THEN no `weapon_destroyed`; weapon attack = 3 until the End step, 2 afterwards (`enchantment_removed`).
- [x] **AC-19** No hero value (health, power cost, blade stats, Husk stats, tax, curve bounds) is a literal in `src/`; all come from `heroes.json`, `hero_powers.json`, `cards_*.json` or `heroes_balance.json`. Adding a fourth hero is data only: a fixture hero whose `hero_power` is an existing power (`power_whetstone`) loads and plays a scripted turn (mulligan, use the power, end turn) with no code change.

---

## Implementation Notes

*Derived from ADR-0002 Decision 6 / Implementation Guidelines, ADR-0007 Decision 1, match-rules C3:*

- C3 step 2 reads `db.hero(config.player.hero_def_id)`: `base_health = record.health`, and `players.player.hero_power = {def_id: record.hero_power, used_this_turn: false}`. CR-3 makes `health` required, so the `starting_health_player` fallback C3 names is reached only by a config whose `hero_def_id` has no record. Keep that branch and log it (`push_error`); do not invent another default.
- The engine already holds `db` (`RulesEngine._init(db, rules_config, resolver)`). Read the record once in `start`, never per command. Treat the record as read-only (ADR-0002: take `duplicate(true)` before any mutation).
- Whetstone's resolution (`conditional` / `exists: owner_weapon`, `equip`, `buff` until end of turn) is done (card-effects 011, match-rules 010). This story proves it on the **shipped** records instead of fixture rows 8/16/25, so AC-7 and AC-8 are integration tests over `assets/data/` through a real `EffectResolver`.
- The power cost stays `rule("hero_power_cost")` through the `modify_cost` fold (match-rules C7 / F1): `HeroPowerDef.cost` is not read by the engine. This matches the shipped data, where both are 2.
- AC-19's literal check is a review item plus the fixture-hero test. The fixture hero lives in a fixture root or a `tests/helpers/card_factory.gd` record set, never in `assets/data/`.
- **Cross-epic edit.** `src/gameplay/match/rules_engine.gd` belongs to the match-rules epic. The producer assigns this one C3 step 2 change here, because no match-rules story is left to own it. Match-rules story 019 (performance pass, its own [S] lane, byte-identical event logs) edits the same file, so do not schedule the two in one wave, or rebase this change onto 019's.
- The boss's hero power is out of scope: no MVP boss has one (`bosses.json`: `hero_power` null on all five).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: the `Heroes` accessor (`hero`, `launch_heroes`, `plan_tags`) and the shipped-data checks AC-1 / AC-6
- Run Structure epic: copying the starter deck into the run deck and building `MatchConfig` at `begin_match` (R2, R3)
- Card-effects 011 / match-rules 010: the power's resolution and the `use_hero_power` command (both Complete)
- Decay (Rot) and Knowledge (Insight) on shipped data: AC-9 to AC-14 are deferred to Alpha with their heroes (DD-H06)

---

## Files

- `src/gameplay/match/rules_engine.gd`: C3 step 2 reads the `HeroDef`, inside `start` and its doc comment only (cross-epic edit, see Implementation Notes)
- `tests/integration/heroes/heroes_war_match_seating_test.gd`
- `tests/fixtures/data/heroes_fixture_hero/`: the 27-health and fourth-hero fixture root (the fixture-root option, so no shared helper changed and this story is not [S])

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/heroes/heroes_war_match_seating_test.gd` — must exist and pass

**Status**: [x] Created, 14 tests, passing

---

## Dependencies

- Depends on: None in this epic. Cross-epic (all Complete): `production/epics/match-rules/story-003-match-setup.md`, `production/epics/match-rules/story-010-play-card-and-hero-power.md`, `production/epics/card-effects/story-011-hero-powers.md`, `production/epics/card-database/story-006-freeze-and-queries.md`, `production/epics/content/story-001-batch-0-first-playable-data-set.md`
- Unlocks: `production/epics/boss-ai-match-driver/story-016-sim-harness.md` (real-data War runs, together with story 002); the First Playable War match (gate entry condition 5)

---

## Completion Notes
**Completed**: 2026-11-04
**Start / end (UTC)**: 2026-11-04T19:37:47Z to 2026-11-04T19:44:24Z
**Readiness**: READY (2026-11-04). ADR-0002 and ADR-0007 Accepted at the story's versions, manifest 2026-11-04 matches, every dependency Complete. Advisory: the QA plan's AC-1 gap, below.
**Criteria**: 4/4 passing
**Test Evidence**: `tests/integration/heroes/heroes_war_match_seating_test.gd`, 14 tests. Full suite 1424 cases, 0 failures (baseline 1410).
**Seen failing**: 11 tests against the missing code. The 3 that pin behaviour already true each failed against a deliberate mutant: boss health from the knob (`test_the_boss_hero_still_seats_from_the_config_health`), power cost from the `HeroPowerDef` (`test_the_power_cost_is_the_rule_and_not_the_hero_power_record`), `start` without the null-`db` guard (`test_an_engine_with_no_database_seats_the_knob`).
**Run result**: N/A: no screen exists for this path yet; the match runs headless in the tests, and Match UI is sprint 5 W3 onward.
**Deviations**:
- ADVISORY: AC-7, AC-19's "scripted turn" runs on the player's second turn. Turn 1 has 1 mana and the power costs 2, so the script is mulligan, both `end_turn`s, power, `end_turn`.
- ADVISORY: AC-8 and the Windfury and Frozen cases hold their weapon through the `equip_weapon` primitive, not a played card. The weapon-over-Blade case plays a real card.
- Added from the QA plan: Frozen hero (equip and sharpen), Windfury both swings, weapon over the Blade, the no-record default.
**Open design gap (heroes.md, match-rules C3 step 2)**: an unknown `hero_def_id`. C3 and the story settle the health: the `starting_health_player` default and a `push_error`. Both GDDs are silent on the hero power and on whether the match should fail instead. No rule was invented: `hero_power.def_id` keeps `make_player_state`'s empty value, the same as before this story, and a test pins it. A later `use_hero_power` on that match is unspecified. Needs a C3 line.
**Log volume**: every engine started with no hero record logs the error, and in the test suite that is each null-`db` and stub-`db` engine: 460 `no HeroDef` errors a run, roughly doubling the run's output. `SCRIPT ERROR` lines are unchanged at 86. Production reaches this only on a bad config.
**Reviewed by**: independent `/code-review`, 2026-11-04 (`production/reviews/2026-11-04/code-review-s5-w1-heroes-treasures.md`, full scope): **CHANGES REQUIRED**, one required change (T1), closed by `71bdcd5` (Review fixes below). No separate re-review report exists.
**Review fixes (2026-11-04)**:
- T1, required: every hero under test used `power_whetstone`, so a literal at the seating line passed all 14 tests and AC-1's power half was unproven, and the "Seen failing" list above did not cover it. `hero_fixture_scholar` now holds a second power, `power_fixture_study`, and `test_a_hero_seats_the_power_its_record_names_and_uses_it` asserts it is seated and resolves. It failed against a mutant hardcoding `"power_whetstone"`.
- S1: `has` answers for any record type, so a card id as `hero_def_id` reached `hero` and asserted in debug. `start` now takes the record from `heroes`, keeping `has` as the first filter. `test_a_hero_def_id_naming_another_record_type_seats_the_knob_and_logs_the_error` failed against the old guard. The same fix in `Heroes.plan_tags` (story 002) has `test_plan_tags_of_an_id_of_another_record_type_logs_and_returns_empty`, which also failed first.
- Not taken here: T2 and the `start` extraction, both suggestions outside the coordinator's list.
**Test count**: this file is now 16 tests.
