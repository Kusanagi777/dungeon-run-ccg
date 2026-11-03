# Story 003: EffectValidator — schema, trigger, selector, op and reference checks

> **Epic**: Card Effects
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/card-effects.md`
**Requirement**: `TR-card-effects-005` (also `TR-card-effects-001`: effect shape)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Effect Resolver / Validator Boundary (also ADR-0002: validator injected under key `effects`, stage 7b calling convention)
**ADR Decision Summary**: `EffectValidator.validate_effects(host_kind, host_id, effects, db, caps) -> Array` is `static`, pure, allocates its own report and reads nothing but its arguments; it returns `[{code, host_id, effect_id, path, message}]` from the closed `E_FX_*` / `W_FX_*` set; `caps` is the `card_effects` config body passed as a parameter.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (by version; the APIs used predate 4.3 and are LOW)
**Engine Notes**: ADR-0007 Engine Compatibility — no post-cutoff APIs; `static func` on a `RefCounted` script is pre-4.3. ADR-0002 rule: an override of a typed method returns explicitly (relevant only to test doubles).

**Control Manifest Rules (this layer)**:
- Required: `EffectValidator.validate_effects(host_kind, host_id, effects, db, caps) -> Array` is `static`, pure, allocates its own report; codes are the closed `E_FX_*` / `W_FX_*` set
- Forbidden: never make the validator a `RefCounted` instance with cached database access; never add an `E_FX_*` / `W_FX_*` code without a card-effects GDD change
- Guardrail: `validate_effects` over the full v1 fixture under 50 ms (asserted in story 016)

---

## Acceptance Criteria

*From GDD `design/gdd/card-effects.md` (C1, C2 Hosts column, C3, C4 ref paths, C5, C10; AC-02, AC-03, AC-04, AC-06), scoped to this story:*

- [ ] **AC-02** GIVEN a card with two play effects each using `chosen`, WHEN validated, THEN `E_FX_CHOSEN` names the host and the second effect's id (default id `<host_id>.1`); and a `chosen` on a non-play trigger or inside a `choose_one` option is also `E_FX_CHOSEN`.
- [ ] **AC-03** GIVEN a boss `passive` with trigger `battlecry`, WHEN validated with `host_kind: passive`, THEN `E_FX_TRIGGER`; GIVEN a treasure effect with `targets: self`, THEN `E_FX_SELECTOR`; an unknown filter predicate is `E_FX_FILTER`; `aura` outside a static trigger and a non-`modify_value` op under a value trigger are `E_FX_OP`; `ops` empty or more than `caps.MAX_OPS_PER_EFFECT` (8) or a duplicate `id` within the host is `E_FX_SCHEMA`.
- [ ] **AC-04** GIVEN `summon` with `card_id: "nope"`, WHEN validated against a `db` whose `has("nope")` is false, THEN `E_FX_REF`; `summon` of a spell id or `equip` of a non-weapon is `E_FX_REF`; GIVEN `{"ref": "owner.bananas"}`, THEN `E_FX_REF_PATH`; a `target.*` ref under a trigger without `chosen` is `E_FX_REF_PATH`.
- [ ] **AC-06** GIVEN an effect using `shuffle_into_deck`, `discard`, `weapon_durability`, `hero_power_refresh` or `remove_keyword`, WHEN validated against the v1 primitive table, THEN no `E_FX_OP_UNAVAILABLE`; GIVEN a test primitive table lacking `add_card_to_deck`, WHEN `shuffle_into_deck` is validated against it, THEN `E_FX_OP_UNAVAILABLE` names the op and the missing primitive. Warnings: `deathrattle` in `keywords[]` with no `deathrattle` effect (or vice versa) is `W_FX_KEYWORD_MISMATCH`; a constant-false `condition` or `repeat` with `times: 0` is `W_FX_UNREACHABLE`; neither fails the host.

---

## Implementation Notes

*Derived from ADR-0007 Decision 8 and C10:*

- `class_name EffectValidator extends RefCounted` with `static func validate_effects(host_kind: StringName, host_id: String, effects: Array, db: CardDatabase, caps: Dictionary) -> Array`. The report is a new `Array` per call; each entry is `{code: StringName, host_id, effect_id, path, message}` where `path` is a JSON-pointer-like string (`effects/1/ops/0/card_id`) so Card Database's data-error screen can show it.
- The op→primitive table (C5 "Primitive(s)" column) is a `const` Dictionary in the validator; `E_FX_OP_UNAVAILABLE` is raised when an op's primitive is absent from the primitive-name list the validator is given. Expose that list as a parameter with a default of the v1 table (or a `caps` key the test can override) so AC-06's second half is testable without a real engine.
- `db` is used only for lookups (`has`, `card`) — during stage 7 the database is `Loading` and answers lookups only (ADR-0002 D4). Never call `config()` on it; `caps` is the parameter.
- Host-kind legality is C2's Hosts column (`card` splits into minion/spell/weapon by the record's `type`; `hero_power`, `treasure`, `passive`). Build the legality table from C2 as data, one row per trigger.
- The closed code set is a `const Array[StringName]`; a test asserts every emitted code is in it (and the set is exactly the 13 C10 names).
- Validation is pure: no `push_error`, no file access, no RNG, no static mutable state (a `static var` cache is forbidden — it is the "cached database access" of Alt 3).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 004: `E_FX_BUDGET` (F6 `step_bound`), `derive_targeting_spec`, `E_FX_OP_TARGET` for `then: cast`
- Story 005: the fixture set (AC-01) and injection into `CardDatabase.load` stage 7b
- Story 002: `validate_config` (the 7a config validator)

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/gameplay/effects/effect_validator.gd`
- `src/gameplay/effects/effect_schema.gd` (C2 trigger table, C3 selector/predicate table, C5 op table as `const` data — shared with the resolver)
- `tests/unit/card_effects/card_effects_validator_schema_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/card_effects/card_effects_validator_schema_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Cross-epic — `production/epics/card-database/` (`CardDatabase.has` / `card` lookups; a `CardFactory` fixture database double is acceptable for this unit test); story paths are assigned by that epic's concurrent `/create-stories` run. In-epic: none.
- Unlocks: `production/epics/card-effects/story-004-validator-step-bound-targeting.md`, `production/epics/card-effects/story-005-fixture-set-database-injection.md`
