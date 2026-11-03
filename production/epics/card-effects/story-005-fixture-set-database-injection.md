# Story 005: C11 fixture set and validator injection into Card Database stage 7

> **Epic**: Card Effects
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/card-effects.md`
**Requirement**: `TR-card-effects-005` (injected into Card Database stage 7)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Data format, effect schema/DSL and `config()` loading (stage 7b calling convention); ADR-0007: Effect Resolver / Validator Boundary (the five-parameter stub)
**ADR Decision Summary**: Card Database stage 7b invokes the registered Callable as `call(host_kind, host_id, value, db, configs)`; `Boot` registers `effects` as the one-line adapter `func(k, id, fx, db, configs): return EffectValidator.validate_effects(k, id, fx, db, configs["card_effects"])`; results merge with severity `E_DELEGATED` plus the owner's code; a missing validator is itself `E_DELEGATED` in every build type; tests inject the five-parameter accept-all stub.
**ADR Version**: 2026-11-03 (ADR-0002); 2026-11-03 (ADR-0007)

**Engine**: Godot 4.7.2 | **Risk**: HIGH (by version; the APIs used predate 4.3 and are LOW)
**Engine Notes**: ADR-0002 Engine Compatibility — no post-cutoff APIs required; the fixture is read through `DataLoader` pointed at `tests/fixtures/data/<case>/`, never `FileAccess` in a test. Lambdas capture locals by value (sourced) — the adapter closes over nothing.

**Control Manifest Rules (this layer)**:
- Required: tests inject the five-parameter accept-all stub `func(_k, _id, _fx, _db, _configs): return []` into `CardDatabase.load`; `caps` is the `card_effects` config body passed as a parameter
- Forbidden: never make the validator a `RefCounted` instance with cached database access; never read `targeting` from a stored field
- Guardrail: `validate_effects` over the full v1 fixture under 50 ms (measured in story 016; this story builds the fixture it runs over)

---

## Acceptance Criteria

*From GDD `design/gdd/card-effects.md` (C10, C11, Acceptance Criteria preamble; AC-01) and ADR-0002 D4, scoped to this story:*

- [ ] **AC-01** GIVEN the full v1 fixture set `tests/fixtures/cards_effects_test.json` (one card, hero power, boss passive or treasure per C11 row 1–46, plus the vanilla minions from `CardFactory.make_fixture_card_set()`), WHEN `validate_effects` runs on every host, THEN it returns zero errors, and each C11 row 1–46 is present in the fixture (a test enumerates the row ids) and validates; warnings are allowed only where C11 says so.
- [ ] **AC-2 (ADR-0002 D4, C10)** GIVEN `CardDatabase.load({effects: <adapter>, …})` over a fixture folder whose one card carries `summon` with `card_id: "nope"`, WHEN the load runs, THEN the `ValidationReport` holds an `E_DELEGATED` entry carrying code `E_FX_REF`, `host_id`, `effect_id` and `path`, `state()` is `Failed`, and the adapter was called with exactly five arguments (`host_kind, host_id, value, db, configs`) during stage 7 with `db` in `Loading` answering `has()`.
- [ ] **AC-3 (manifest, ADR-0007 D8)** GIVEN the same fixture loaded with the accept-all stub `func(_k, _id, _fx, _db, _configs): return []`, THEN the load reaches `Ready` with no `E_FX_*` entries; and GIVEN `load({})` with no `effects` validator, THEN `E_DELEGATED` is reported regardless of `OS.is_debug_build()`.

---

## Implementation Notes

*Derived from ADR-0002 Decision 4 and ADR-0007 Decision 8:*

- The fixture ids follow CR-2 and name their row: `fx_row_01_war_weapon_buff`, …, `fx_row_46_decay_husk_purge`; set the `set` field per C11's "Set / kind" column; hero powers go in the `hero_powers` definition file, passives on boss records, treasures in `treasures`. Tokens the rows summon (`decay_husk`, `war_token_axe`, `war_whetstone_blade`, `neutral_sheep`) are in the fixture as `token: true` so `E_FX_REF` does not fire.
- Keep the fixture in `tests/fixtures/data/card_effects_v1/` as a full DD-T01 folder so `DataLoader.new("res://tests/fixtures/data/card_effects_v1/")` loads it end to end; `cards_effects_test.json` is the flat array other unit tests read via `CardFactory`-shaped records. Both are generated from the same source list (a small GDScript or JSON) to prevent drift.
- The adapter lives in `Boot` (boot-composition-root epic); this story adds the integration test that composes `DataLoader` + the real `EffectValidator` without `Boot`, the way `tools/content/validate.gd` does.
- AC-01's "zero errors" is the gate that makes every MVP card authorable: when a row fails, fix the validator or raise a GDD question — never loosen a code.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003–004: validator logic
- Story 016: timing `validate_effects` over this fixture (AC-42) and the 100-command replay fixture (AC-37)
- `production/epics/boot-composition-root/`: registering the adapter in `Boot.boot()`
- `production/epics/content/`: the real `assets/data/cards_*.json`

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `tests/fixtures/cards_effects_test.json`
- `tests/fixtures/data/card_effects_v1/` (DD-T01 folder for the loader path)
- `tests/fixtures/data/card_effects_bad_ref/` (AC-2 case)
- `tests/integration/card_effects/card_effects_fixture_load_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/card_effects/card_effects_fixture_load_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/card-effects/story-003-validator-schema-codes.md`, `production/epics/card-effects/story-004-validator-step-bound-targeting.md`. Cross-epic: `production/epics/card-database/` (`DataLoader`, `CardDatabase.load` stages 7a/7b, `ValidationReport`); story paths are assigned by that epic's concurrent `/create-stories` run.
- Unlocks: `production/epics/card-effects/story-016-determinism-clone-bounds-perf.md`; every resolution story 006–015 reads this fixture

> **Blocker (2026-11-03, sprint-3 lane `lane/s3-card-effects-002-005`):** not started.
> It depends on story 004 (`E_FX_BUDGET`, `E_FX_OP_TARGET`, `step_bound` — AC-01's "every
> C11 row validates" runs the full validator), which is blocked on match-rules story 010
> (see story 004's blocker note). Stays Ready; carries with story 004.
