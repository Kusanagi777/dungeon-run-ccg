# Story 005: C11 fixture set and validator injection into Card Database stage 7

> **Epic**: Card Effects
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-04

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

- `tests/fixtures/cards_effects_test.json` — created (the flat list: 46 row hosts + 4 tokens)
- `tests/fixtures/data/card_effects_v1/` — created (DD-T01 folder: the flat records, `CardFactory.make_fixture_card_set()`, hero, boss card, 3 bundles; shipped `card_effects.json` / `match_rules.json`)
- `tests/fixtures/data/card_effects_bad_ref/` — created (AC-2 case: `neutral_fx_bad_ref` summons `nope`)
- `tests/fixtures/gen_cards_effects_fixture.py` — created (the one source list both are written from)
- `tests/integration/card_effects/card_effects_fixture_load_test.gd` — created (7 tests)
- `src/gameplay/effects/effect_validator.gd` — modified (an entry's message names its effect id, which the stage-7b merge has no field for)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/card_effects/card_effects_fixture_load_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] Created — 7 tests, passing in the full suite

---

## Dependencies

- Depends on: `production/epics/card-effects/story-003-validator-schema-codes.md`, `production/epics/card-effects/story-004-validator-step-bound-targeting.md`. Cross-epic: `production/epics/card-database/` (`DataLoader`, `CardDatabase.load` stages 7a/7b, `ValidationReport`); story paths are assigned by that epic's concurrent `/create-stories` run.
- Unlocks: `production/epics/card-effects/story-016-determinism-clone-bounds-perf.md`; every resolution story 006–015 reads this fixture

> **Blocker (2026-11-03, sprint-3 lane `lane/s3-card-effects-002-005`):** not started.
> It depends on story 004 (`E_FX_BUDGET`, `E_FX_OP_TARGET`, `step_bound` — AC-01's "every
> C11 row validates" runs the full validator), which is blocked on match-rules story 010
> (see story 004's blocker note). Stays Ready; carries with story 004.
>
> **Blocker cleared (2026-11-04 00:18 UTC, sprint-3 lane `lane/s3-card-effects-004-006`):**
> match-rules story 010 is merged on trunk (`66640a4`) and story 004 is Complete on this
> lane (`afe128a`: `E_FX_BUDGET`, `E_FX_OP_TARGET`, `step_bound`). Started.

---

## Completion Notes
**Completed**: 2026-11-04 (started 00:18:18 UTC, ended 00:25:27 UTC)
**Criteria**: 3/3 passing (AC-01, AC-2, AC-3), no deferred items
- AC-01 — `tests/integration/card_effects/card_effects_fixture_load_test.gd`: `test_every_c11_row_1_to_46_is_in_the_fixture_exactly_once` (row ids enumerated from the flat list), `test_the_full_fixture_loads_ready_with_every_host_validated_clean` (the v1 folder through `CardDatabase.load` with the real validator in stage 7b and the real `card_effects` / `match_rules` stage-7a validators: `Ready`, zero errors, zero `E_FX_*` / `W_FX_*` entries, and every row host plus every `make_fixture_card_set()` card recorded with an empty report), `test_the_loader_folder_holds_the_flat_records_and_the_factory_set_unchanged` (drift guard), `test_the_fixture_tokens_exist_so_no_reference_fails`. No validator change was needed for any row (no false positive).
- AC-2 — `test_a_summon_of_an_unknown_card_is_e_delegated_e_fx_ref_and_fails_the_load`: one `E_DELEGATED` error, `record_id` `neutral_fx_bad_ref`, field `effects`, message `E_FX_REF: card `nope` not found … (effect `neutral_fx_bad_ref.0`) (at effects/0/ops/0/card_id)`, state `Failed`; a rest-parameter adapter saw exactly 5 arguments on every call, the database `Loading` and answering `has()`.
- AC-3 — `test_the_same_folder_with_the_accept_all_stub_reaches_ready_with_no_e_fx_entry` (the manifest's five-parameter stub, verbatim), `test_load_with_no_effects_validator_is_e_delegated_in_both_build_types` (`load({})` with `debug_build` true and false).
- Watched fail: the AC-2 test failed on the effect id before the message carried it; then one mutation per run, each restored: a duplicated row id in the flat list (row-count, load and drift tests failed), one value changed in the v1 folder only (the drift test failed), `F6_MAX_TARGETS_ALL` 16 → 300 (the clean-load, token and drift tests failed — the load went `Failed` on `E_FX_BUDGET`). The `load({})` test asserts card-database story 004 behaviour and was not mutated here (the loader is not this story's file).
**Resumed**: a container restart interrupted the lane before the commit; the uncommitted work was reviewed and re-verified 2026-11-04 01:33–01:40 UTC (generator re-run reproduces every committed fixture byte for byte; suite re-run with `-c`, same result).
**Verification**: `godot --headless --path . --import` exit 0; full suite (`commands.test`) 983 test cases, 0 failures, exit 0; smoke exit 0, no SCRIPT ERROR; `tools/lint/gates.sh` PASS, `no_global_rng.sh` 0 hits. The suite's 85 SCRIPT ERROR lines are unchanged and all from other systems' negative tests.
**Run result**: N/A — a data fixture and a load-time validator; nothing renders, and the data-error screen that would show a `Failed` load is not built yet.
**Deviations** (all ADVISORY):
- **Fixture ids carry their set prefix:** `war_fx_row_01_weapon_buff`, `power_fx_row_08_whetstone`, `boss_fx_row_35_mending_warden`, `treasure_fx_row_38_iron_hide`, … — the story's `fx_row_NN_…` spelling fails CR-2 (a CardDef id starts with its file's set, `E_SET_MISMATCH`; other types have fixed prefixes). Each still names its row (`fx_row_NN_`), which the row test enumerates.
- **Effect id in the merged report:** Card Database's `_merge_delegated` keeps `code`, `host_id`, `path` and `message` but has no `effect_id` field, so `EffectValidator` now appends `` (effect `<id>`)`` to every entry's message (the entry's own `effect_id` field is unchanged). An alternative is an `effect_id` field in the loader merge (card-database's file, not edited).
- **One source list:** `tests/fixtures/gen_cards_effects_fixture.py` (Python, test tooling) writes the flat file and both folders; the drift test pins the folder to the flat file and to `CardFactory.make_fixture_card_set()`. The flat file holds the row hosts and tokens; the vanilla set stays in `CardFactory` (the folder carries it), so other unit tests keep one copy of it.
- **Folder infrastructure beyond the rows:** one hero (`hero_war`, starter deck = the 15 factory cards, hero power row 8), one boss card for boss decks, three `fixture`-tagged neutral cards behind three bundles (DD-R04 `min_bundle_pool` 3 is an error below the floor); the boss rows use row 44 as their hero power. Config bodies other than `card_effects` / `match_rules` are `clean/`'s (stubbed at 7a in the test).
- The test composes the stage-7b adapter itself with `EffectValidator.stage7_caps(configs)` (story 004) — Boot's adapter still passes `configs["card_effects"]` until the orchestrator applies story 004's registration line; with that adapter row 24 (`hand`) would fail closed on `E_FX_BUDGET`.
**Test Evidence**: `tests/integration/card_effects/card_effects_fixture_load_test.gd`
**Reviewed by**: self, no independent review (lean: LP-CODE-REVIEW and QL-TEST-COVERAGE skipped — Lean mode; `/code-review` not run)
