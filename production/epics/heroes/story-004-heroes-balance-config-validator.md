# Story 004: `Heroes.validate_config` — the `heroes_balance.json` stage-7a validator, registered at Boot

> **Epic**: Heroes
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-11-04
> **Last Updated**: 2026-11-04
> **First Playable path**: no — a debug build reports the pending validator as a warning. It is required before any **exported release** build, where a pending validator is an error and the load fails

## Context

**GDD**: `design/gdd/heroes.md` (Formulas F1–F5 variable tables, Tuning Knobs) · `design/gdd/card-database.md` CR-1 / CR-5 stage 7
**Requirement**: `TR-card-database-002` (carried: one delegated validator per config file)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Data format, effect schema/DSL and `config()` loading
**ADR Decision Summary**: Every externally owned config file has a static owner validator injected at stage 7a as `callable.call(body, db) -> Array` of `{code, host_id|null, field, message}`. A missing validator is `E_DELEGATED` in release builds, and `heroes_balance: Heroes.validate_config` is in the composition map.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (by version; APIs LOW)
**Engine Notes**: ADR-0002 Engine Compatibility — no post-cutoff API; lambdas capture by value (validator Callables take everything as arguments).

**Control Manifest Rules (this layer)**:
- Required: every config owner exposes a `static` validator registered at `Boot` (`Heroes.validate_config` is on the manifest's list); the owner reads its body once at construction
- Forbidden: never a numeric gameplay default in loader code (a missing knob is the owner validator's error, not a fallback); never make a missing validator pass silently
- Guardrail: data load ≤ `data_load_budget_ms` 200 (Foundation); the release guardrail is that `Boot.PENDING_CONFIG_OWNERS` is empty

Boot still registers `heroes_balance` as a pending config validator (`Boot.PENDING_CONFIG_OWNERS`). That gives one `W_VALIDATOR_PENDING` per load in a debug build and an error in an exported one. This story ships the real validator and takes `heroes_balance` off the pending list. The body's keys are those in `assets/data/heroes_balance.json`, the formulas' data-file variables.

---

## Acceptance Criteria

*From GDD `design/gdd/heroes.md` (Formulas variable tables, Tuning Knobs safe ranges) and `card-database.md` CR-5 stage 7, scoped to this story:*

- [x] **AC-1** GIVEN the shipped `heroes_balance.json` body, WHEN `Heroes.validate_config(body, null)` is called, THEN it returns `[]`.
- [x] **AC-2 (Tuning Knobs safe ranges)** GIVEN a fixture body with each knob set outside its Tuning Knobs safe range in turn — `avg_min`–`avg_max` outside 2.2–3.2 (or `avg_min > avg_max`), `max_cost` outside 4–6, `plan_min`–`plan_max` outside 3–8, `hp_value_min`–`hp_value_max` outside 1.0–3.0, `set_share_tol` outside 0.04–0.15, `synergy_min` outside 3–8 — THEN exactly one `E_RANGE` entry naming that key is returned; GIVEN a required key removed, THEN one `E_MISSING_FIELD`; GIVEN an extra key, THEN one `E_UNKNOWN_FIELD`.
- [x] **AC-3 (registration)** GIVEN `Boot._collect_validators`, THEN `configs.heroes_balance` is `Heroes.validate_config` and `Boot.PENDING_CONFIG_OWNERS` no longer lists `heroes_balance` (the pinned lists in `tests/integration/boot/boot_validator_map_test.gd` are updated); a full load of the shipped data reports no `W_VALIDATOR_PENDING` for `heroes_balance.json`.

---

## Implementation Notes

*Derived from ADR-0002 Decision 4 and Implementation Guidelines:*

- `static func validate_config(body: Dictionary, _db: Variant) -> Array` on `Heroes`. Pure: no state, no file I/O, so `tools/content/validate.gd` can compose it without `Boot`.
- Follow `ContentValidator.validate_config`'s precedent (content story 007): a key-spec table of **format knowledge**, meaning the key list and each key's Tuning Knobs safe range. No knob value lives in code; the values are the file's. Use the same code names (`E_MISSING_FIELD`, `E_SCHEMA`, `E_RANGE`, `E_UNKNOWN_FIELD`) so the report reads the same across owners.
- Keys with no Tuning Knobs safe range are checked for type and the bound their meaning implies, and the spec row says so. These are the `starter_curve.bucket` table (int pairs, low ≤ high, 0–15), `plan_tags` (per-set non-empty string lists), `hero_set_size` / `hero_set_size_tol` (int > 0), `set_share` (shares in 0–1 per set and type), `vanilla_2drop` (> 0) and `p_kill` (the F3 variable range 0.3–0.6).
- Boot gets one line, `configs["heroes_balance"] = Heroes.validate_config`, and the name comes off `PENDING_CONFIG_OWNERS` (boot-composition-root story 004: "each later epic adds its own line there"). `src/core/boot.gd` belongs to the Boot epic; this is the pattern that epic set for owners.
- `ContentValidator` keeps reading `heroes_balance` for F1 / F4 (content story 008). Its "not checked" path for an absent knob stays; this validator makes the absence a load error instead.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: evaluating F2 / F5 against the data (this story checks only the knobs' shape and ranges)
- The other pending config owners (`run_structure`, `reward_draft`, `treasures_balance`, `match_ui`, `run_ui`, `profile_defaults`): their own epics; `treasures_balance` is treasures story 010

---

## Files

- `src/gameplay/heroes/heroes.gd`: `validate_config`, `CONFIG_SPEC`, `ORDERED_PAIRS`
- `tests/unit/heroes/heroes_validate_config_test.gd`
- `tests/fixtures/data/minimal/heroes_balance.json`, `tests/fixtures/data/heroes_fixture_hero/heroes_balance.json`: the shipped body, which a real validator needs (see Completion Notes)
- Orchestrator, at merge, not on the lane branch: `src/core/boot.gd`, `tests/integration/boot/boot_validator_map_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/heroes/heroes_validate_config_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] Created, 13 tests, passing

---

## Dependencies

- Depends on: `production/epics/heroes/story-002-heroes-accessor.md` (the `Heroes` class). Cross-epic (Complete): `production/epics/boot-composition-root/story-004-boot-composition-root.md`, `production/epics/card-database/story-004-delegated-validators.md`
- Unlocks: the release guardrail (empty `PENDING_CONFIG_OWNERS`), together with the other owners' validators

---

## Completion Notes
**Implemented**: 2026-11-04. AC-3 closed at the M1 merge: the orchestrator added the Boot line, removed the pending owner and extended `boot_validator_map_test.gd`.
**Start / end (UTC)**: 2026-11-04T19:57:11Z to 2026-11-04T20:08:52Z
**Readiness**: READY (2026-11-04). ADR-0002 Accepted at the story's version, manifest 2026-11-04 matches, dependencies Complete. The sprint plan's readiness note applies: AC-3 is met by the orchestrator's line.
**Criteria**: 3/3 passing.
**AC-3 lines for the orchestrator, one commit**:
- `src/core/boot.gd` `_collect_validators()`: `configs["heroes_balance"] = Heroes.validate_config`
- `src/core/boot.gd` `PENDING_CONFIG_OWNERS`: remove `"heroes_balance"`
- `tests/integration/boot/boot_validator_map_test.gd`, after the `configs.card_effects` assert: `assert_array((configs.heroes_balance as Callable).call({}, null)).is_equal(Heroes.validate_config({}, null))`
**AC-3 dry run (2026-11-04, applied locally, restored, not committed)**: full suite 1471 cases, 0 failures; `validate.gd` exit 0; `W_VALIDATOR_PENDING` rows 7 to 6, the only changed row being `heroes_balance.json`.
**Test Evidence**: `tests/unit/heroes/heroes_validate_config_test.gd`, 13 tests. Full suite 1471 cases, 0 failures.
**Seen failing**: 8 tests against a stub returning `[]`. The 5 accept-cases against deliberate mutants: a tightened `avg_min` range (edges), `synergy_min` range excluding the shipped value (AC-1 and the rest built on the shipped body), set keys limited to the launch sets (the fourth-hero row). A further mutant removed the pair-check skip, which double-reported an out-of-range key. The tests also caught a real crash in the first version: the pair check walked into a missing or non-object `starter_curve`.
**Run result**: N/A: a load-time validator with no screen.
**Deviations**:
- ADVISORY, fixtures outside the story's Files: the real validator fails any load whose `heroes_balance.json` is the empty `config: {}`. An earlier dry run gave 7 failing tests, all on `minimal` and `heroes_fixture_hero`, so both now hold the shipped body. The other empty roots stay as they are, and the second dry run is green with them. `fingerprint/` and its pinned hash are unchanged.
- ADVISORY, "pinned list": `boot_validator_map_test.gd` has no hard-coded config list; it derives `pending` from `PENDING_CONFIG_OWNERS`. The line above is the matching `card_effects` assert.
- ADVISORY, beyond the AC's `avg_min > avg_max`: `plan_min > plan_max` and `hp_value_min > hp_value_max` are also `E_RANGE`, following `ContentValidator`'s ordered pairs.
- ADVISORY, a difference from that precedent: a pair is not compared when either end already has an entry, because AC-2 asks for exactly one.
- ADVISORY, key choices the story leaves open: `starter_curve.bucket` is the fixed key list of the file and F1 (`0`-`5`, `6_plus`). `plan_tags` and `set_share` take any `RecordSchemas.HERO_SETS` key, so a later hero's rows stay data only (AC-19), and any other key is `E_UNKNOWN_FIELD`.
**Reviewed by**: independent `/code-review`, 2026-11-04 (`production/reviews/2026-11-04/code-review-s5-w1-heroes-treasures.md`, summary scope: correctness and contract risk only): **APPROVED WITH SUGGESTIONS**. Open: the low design question on a `plan_tags` body with no row for an existing hero
