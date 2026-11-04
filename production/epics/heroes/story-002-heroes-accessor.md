# Story 002: `Heroes` accessor — `hero`, `launch_heroes`, `plan_tags` over `CardDatabase`

> **Epic**: Heroes
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-11-04
> **Last Updated**: [set by /dev-story when implementation begins]
> **First Playable path**: yes — boss-ai story 016 builds the War `MatchConfig.player.deck` from `hero("hero_war").starter_deck`

## Context

**GDD**: `design/gdd/heroes.md` (H-1, H-2, H-5, H-7, Interactions "Reward Draft", AC-1, AC-6, AC-16 data half)
**Requirement**: `TR-heroes-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Data format, effect schema/DSL and `config()` loading
**ADR Decision Summary**: `HeroDef` / `HeroPowerDef` records are loaded, validated and frozen by `CardDatabase`, and config bodies reach their owner once, at construction. `Heroes` is thin data access over that snapshot (architecture.md: `hero(id)`, `launch_heroes()`, `plan_tags(hero_id)`, depends on `CardDatabase` only) with nothing hero-specific in code.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (by version; APIs LOW)
**Engine Notes**: ADR-0002 Engine Compatibility — no post-cutoff API; typed-method overrides in test doubles return explicitly (4.7).

**Control Manifest Rules (this layer)**:
- Required: every config owner reads its body once at construction; `src/gameplay/heroes/**` is `RefCounted` and constructor-injected (no Node, no autoload)
- Forbidden: never re-parse `assets/data/*.json` outside `CardDatabase`; never a numeric gameplay literal in run code; never downcast `MetaApi` or reference `MetaStub` outside `Boot`, debug loaders and tests
- Guardrail: Run UI `select_ready` ≤ 300 ms (the accessor answers in O(heroes))

The run and the UI read heroes through this accessor: Run Structure (R2) copies the starter deck, Reward Draft weights bundles by `plan_tags`, and Run UI lists the launch heroes. Unlock state is not part of it: `MetaApi.is_hero_unlocked` (the `MetaStub` answers true) is consulted by Run Structure and Run UI, not here.

---

## Acceptance Criteria

*From GDD `design/gdd/heroes.md` (H-2, H-5, H-7, AC-1, AC-6, AC-16), scoped to this story:*

- [ ] **AC-1 (H-2, H-7; AC-16 data half)** GIVEN a `CardDatabase` built from `tests/helpers/` factory records with two `HeroDef`s whose `unlock` is null and one fixture hero with a non-null `unlock {key, condition}`, WHEN `launch_heroes()` is called, THEN it returns the two unlock-null heroes in id-ascending order and not the fixture hero; `hero(id)` returns the same frozen record as `db.hero(id)`, and an unknown id returns `null` as `db.hero` does.
- [ ] **AC-2 (H-5; reward-draft F3)** GIVEN the shipped `heroes_balance.json`, WHEN `plan_tags("hero_war")` is called, THEN it returns `["weapons", "aggro", "armour"]`, read from `config("heroes_balance").plan_tags[hero.set]`; GIVEN a fixture body with a different `plan_tags.war` list, THEN that list is returned with no code change.
- [ ] **AC-3 (GDD AC-1, MVP-0 batch)** GIVEN the shipped `assets/data/` (Content CN-6: MVP-0 ships `hero_war` only, DD-H06), WHEN the Card Database loads and the accessor is built over it, THEN `launch_heroes()` returns exactly `[hero_war]` with `health = 30`, a `hero_power` id that `db.hero_power()` resolves, and a `starter_deck` of exactly 15 ids, all `token == false` and each with `set ∈ {war, neutral}`; `report()` holds zero `E_*` entries.
- [ ] **AC-4 (GDD AC-6)** GIVEN the tokens `decay_husk` and `war_whetstone_blade`, WHEN `collectible_pool(set)` and `bundle_pool(set)` are queried for every set present (`war`, `neutral`, `decay`, `boss`), THEN neither token appears.

---

## Implementation Notes

*Derived from ADR-0002 Decision 6 and Implementation Guidelines; architecture.md §API Boundaries (Heroes row):*

- `class_name Heroes extends RefCounted`; `_init(db: CardDatabase)` keeps `db` and reads `db.config("heroes_balance")` once. Public API exactly `hero(id) -> Variant`, `launch_heroes() -> Array`, `plan_tags(hero_id) -> Array`, each with a doc comment (coding standards). Story 003 adds the F2/F5 functions.
- `launch_heroes()` filters `db.heroes()`, which is already id-ascending (CR-6), on `unlock == null` (H-2: launch heroes are `unlock: null`; H-7 heroes carry the `{key, condition}` object, DD-X01). It does not ask `MetaApi`: whether a locked hero is selectable is Run UI's state, and `new_run` rejecting it with `E_HERO_LOCKED` is Run Structure's (run-structure AC-23).
- `plan_tags(hero_id)` returns a copy of `plan_tags[db.hero(hero_id).set]`. The tag list is data (`heroes_balance.json`), never a code constant. For an unknown hero, follow `CardDatabase`'s convention (`push_error`, empty result) and do not assert.
- AC-3 and AC-4 run over the real shipped data (integration-style fixture-free tests). The structural checks they observe (15 ids, set, no tokens, `E_UNKNOWN_REF`, `E_TOKEN_IN_LIST`) already live in `DataLoader` stage 6. This story asserts them through the accessor and adds no second validator.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: the engine seating the hero from its `HeroDef`
- Story 003: F2 plan-card count and F5 synergy
- Story 004: `Heroes.validate_config` for `heroes_balance.json`
- Run UI epic: the Locked display and pre-selecting War (AC-16 screen half, run-ui U7); Run Structure epic: `E_HERO_LOCKED`

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/gameplay/heroes/heroes.gd` — created (`Heroes`)
- `tests/unit/heroes/heroes_accessor_test.gd`
- `tests/integration/heroes/heroes_shipped_data_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/heroes/heroes_accessor_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later); AC-3 / AC-4 in `tests/integration/heroes/heroes_shipped_data_test.gd`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None in this epic. Cross-epic (Complete): `production/epics/card-database/story-006-freeze-and-queries.md`, `production/epics/content/story-001-batch-0-first-playable-data-set.md`
- Unlocks: `production/epics/heroes/story-003-plan-card-and-synergy-checks.md`; `production/epics/boss-ai-match-driver/story-016-sim-harness.md` (War starter deck, with story 001); the Run Structure, Reward Draft and Run UI epics' hero reads
