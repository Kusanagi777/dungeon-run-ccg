# Story 010: `Treasures.validate_config` for `treasures_balance.json`, and magnitudes read from data

> **Epic**: Treasures
> **Status**: In Review
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-11-04
> **Last Updated**: [set by /dev-story when implementation begins]
> **First Playable path**: no — a debug build reports the pending validator as a warning. It is required before any **exported release** build, where a pending validator is an error

## Context

**GDD**: `design/gdd/treasures.md` (Tuning Knobs, T7 `MAX_EFFECTS_PER_TREASURE`, AC-30 first half) · `design/gdd/card-database.md` CR-1 / CR-5 stage 7a
**Requirement**: `TR-card-database-002` (carried: one validator per config file)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Data format, effect schema/DSL and `config()` loading (most direct); ADR-0005: Owner-scoped hook registry (`Treasures._init(db, balance_config)`)
**ADR Decision Summary**: Each externally owned config file has a static validator called at stage 7a as `(body, db) -> Array`, registered at `Boot` (`treasures_balance: Treasures.validate_config`). A missing knob is the owner validator's error, never a loader fallback. The owner reads its body once at construction.
**ADR Version**: 2026-11-03 (ADR-0002); 2026-11-03 (ADR-0005)

**Engine**: Godot 4.7.2 | **Risk**: HIGH (by version); LOW for the APIs
**Engine Notes**: ADR-0002 Engine Compatibility — no post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: every config owner exposes a `static` validator registered at `Boot` (`Treasures.validate_config` is on the manifest's list); body read once at construction
- Forbidden: never a numeric gameplay default in loader code; never make a missing validator pass silently; never hardcode a treasure magnitude (they are `treasures.json` `effects` data)
- Guardrail: the release guardrail is an empty `Boot.PENDING_CONFIG_OWNERS`

---

## Acceptance Criteria

*From GDD `design/gdd/treasures.md` (Tuning Knobs, AC-30) and `card-database.md` CR-5 stage 7a, scoped to this story:*

- [ ] **AC-1** GIVEN the shipped `treasures_balance.json` body, WHEN `Treasures.validate_config(body, null)`, THEN `[]`.
- [ ] **AC-2 (Tuning Knobs safe ranges)** GIVEN a fixture body with each knob outside its safe range in turn — `max_effects_per_treasure` outside 1–5; `common_band` / `rare_band` overlapping or narrower than 1.0; any `v_*` outside ±50 % of its Tuning Knobs value; any `eta_*` outside 0.4–1.0 — THEN exactly one `E_RANGE` naming that key; a removed key → `E_MISSING_FIELD`; an extra key → `E_UNKNOWN_FIELD`.
- [ ] **AC-3 (registration)** GIVEN `Boot._collect_validators`, THEN `configs.treasures_balance` is `Treasures.validate_config` and `Boot.PENDING_CONFIG_OWNERS` no longer lists `treasures_balance` (pinned lists in `tests/integration/boot/boot_validator_map_test.gd` updated); a shipped load reports no `W_VALIDATOR_PENDING` for `treasures_balance.json`.
- [ ] **AC-30 (first half)** No hardcoded values: GIVEN the fixture's Iron Constitution edited to `health: 5`, WHEN the match starts, THEN the hero reads 35/35 with no code change; every magnitude in T8 is read from `treasures.json`.

---

## Implementation Notes

*Derived from ADR-0002 Decision 4 and Implementation Guidelines:*

- `static func validate_config(body: Dictionary, _db: Variant) -> Array` on `Treasures`. It is pure, and it follows `ContentValidator.validate_config`'s key-spec precedent: the key list and safe ranges are format knowledge, and the values stay in the file. Use the code names that validator uses (`E_MISSING_FIELD`, `E_SCHEMA`, `E_RANGE`, `E_UNKNOWN_FIELD`).
- The keys are those in the shipped body: `max_effects_per_treasure`, `common_band`, `rare_band`, `v_card`, `v_dmg`, `v_hp`, `v_stat`, `v_token`, `v_rush`, `eta_mana`, `eta_crystal`, `eta_first`, `eta_overheal`. The ±50 % ranges for `v_*` come from the Tuning Knobs row and its stated values (1.5, 0.5, 0.35, 0.5, 1.0, 0.5). They are a safe range written in the GDD, not a default.
- **Known gap, not this story's to close.** F1 lists more data-file constants (`V_MANA`, `T_TURNS`, `N_*`, `AOE_FACTOR`, `LEGENDARY_SURPLUS`) that `treasures_balance.json` does not carry. They are only needed by `W_TR_POWER` (story 013, Blocked). This validator checks the shipped key set. When story 013 is unblocked and those keys land, it extends the spec in the same change.
- AC-30's second half ("every F1 constant from `treasures_balance.json`") belongs to story 013, the only reader of F1.
- Boot gets one line, and the name comes off `PENDING_CONFIG_OWNERS` (Boot epic's one-line-per-owner pattern; `src/core/boot.gd` belongs to that epic).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: the stage-7b record validator (`E_TR_EFFECT_COUNT` reads `max_effects_per_treasure` from this body)
- Story 013: `W_TR_POWER` and the F1 constants
- Heroes story 004: `heroes_balance.json` (same pattern, different owner)

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/gameplay/treasures/treasures.gd` — `validate_config`
- `src/core/boot.gd` — register `treasures_balance`; drop it from `PENDING_CONFIG_OWNERS`
- `tests/unit/treasures/treasures_validate_config_test.gd`
- `tests/integration/treasures/treasures_data_driven_test.gd` (AC-30)
- `tests/integration/boot/boot_validator_map_test.gd` — pinned pending list updated

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/treasures/treasures_validate_config_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/treasures/story-001-installers-passive-and-collect-state.md`, `production/epics/treasures/story-007-trigger-hook-treasures.md` (AC-30 runs Iron Constitution). Cross-epic (Complete): `production/epics/boot-composition-root/story-004-boot-composition-root.md`
- Unlocks: the release guardrail (empty `PENDING_CONFIG_OWNERS`), together with the other owners' validators
