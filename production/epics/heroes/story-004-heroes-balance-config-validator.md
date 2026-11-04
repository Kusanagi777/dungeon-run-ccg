# Story 004: `Heroes.validate_config` — the `heroes_balance.json` stage-7a validator, registered at Boot

> **Epic**: Heroes
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-11-04
> **Last Updated**: [set by /dev-story when implementation begins]
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

- [ ] **AC-1** GIVEN the shipped `heroes_balance.json` body, WHEN `Heroes.validate_config(body, null)` is called, THEN it returns `[]`.
- [ ] **AC-2 (Tuning Knobs safe ranges)** GIVEN a fixture body with each knob set outside its Tuning Knobs safe range in turn — `avg_min`–`avg_max` outside 2.2–3.2 (or `avg_min > avg_max`), `max_cost` outside 4–6, `plan_min`–`plan_max` outside 3–8, `hp_value_min`–`hp_value_max` outside 1.0–3.0, `set_share_tol` outside 0.04–0.15, `synergy_min` outside 3–8 — THEN exactly one `E_RANGE` entry naming that key is returned; GIVEN a required key removed, THEN one `E_MISSING_FIELD`; GIVEN an extra key, THEN one `E_UNKNOWN_FIELD`.
- [ ] **AC-3 (registration)** GIVEN `Boot._collect_validators`, THEN `configs.heroes_balance` is `Heroes.validate_config` and `Boot.PENDING_CONFIG_OWNERS` no longer lists `heroes_balance` (the pinned lists in `tests/integration/boot/boot_validator_map_test.gd` are updated); a full load of the shipped data reports no `W_VALIDATOR_PENDING` for `heroes_balance.json`.

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

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/gameplay/heroes/heroes.gd` — `validate_config`
- `src/core/boot.gd` — register `heroes_balance`; drop it from `PENDING_CONFIG_OWNERS`
- `tests/unit/heroes/heroes_validate_config_test.gd`
- `tests/integration/boot/boot_validator_map_test.gd` — pinned pending list updated

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/heroes/heroes_validate_config_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/heroes/story-002-heroes-accessor.md` (the `Heroes` class). Cross-epic (Complete): `production/epics/boot-composition-root/story-004-boot-composition-root.md`, `production/epics/card-database/story-004-delegated-validators.md`
- Unlocks: the release guardrail (empty `PENDING_CONFIG_OWNERS`), together with the other owners' validators
