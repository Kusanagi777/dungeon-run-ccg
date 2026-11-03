# Story 003: EffectValidator — schema, trigger, selector, op and reference checks

> **Epic**: Card Effects
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-03

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

- [x] **AC-02** GIVEN a card with two play effects each using `chosen`, WHEN validated, THEN `E_FX_CHOSEN` names the host and the second effect's id (default id `<host_id>.1`); and a `chosen` on a non-play trigger or inside a `choose_one` option is also `E_FX_CHOSEN`.
- [x] **AC-03** GIVEN a boss `passive` with trigger `battlecry`, WHEN validated with `host_kind: passive`, THEN `E_FX_TRIGGER`; GIVEN a treasure effect with `targets: self`, THEN `E_FX_SELECTOR`; an unknown filter predicate is `E_FX_FILTER`; `aura` outside a static trigger and a non-`modify_value` op under a value trigger are `E_FX_OP`; `ops` empty or more than `caps.MAX_OPS_PER_EFFECT` (8) or a duplicate `id` within the host is `E_FX_SCHEMA`.
- [x] **AC-04** GIVEN `summon` with `card_id: "nope"`, WHEN validated against a `db` whose `has("nope")` is false, THEN `E_FX_REF`; `summon` of a spell id or `equip` of a non-weapon is `E_FX_REF`; GIVEN `{"ref": "owner.bananas"}`, THEN `E_FX_REF_PATH`; a `target.*` ref under a trigger without `chosen` is `E_FX_REF_PATH`.
- [x] **AC-06** GIVEN an effect using `shuffle_into_deck`, `discard`, `weapon_durability`, `hero_power_refresh` or `remove_keyword`, WHEN validated against the v1 primitive table, THEN no `E_FX_OP_UNAVAILABLE`; GIVEN a test primitive table lacking `add_card_to_deck`, WHEN `shuffle_into_deck` is validated against it, THEN `E_FX_OP_UNAVAILABLE` names the op and the missing primitive. Warnings: `deathrattle` in `keywords[]` with no `deathrattle` effect (or vice versa) is `W_FX_KEYWORD_MISMATCH`; a constant-false `condition` or `repeat` with `times: 0` is `W_FX_UNREACHABLE`; neither fails the host.

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

- `src/gameplay/effects/effect_validator.gd` — created (`EffectValidator.validate_effects`, closed `CODES`)
- `src/gameplay/effects/effect_schema.gd` — created (C1–C5 tables as `const` data, `V1_PRIMITIVES`)
- `tests/unit/card_effects/card_effects_validator_schema_test.gd` — created (36 test functions)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/card_effects/card_effects_validator_schema_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] Created — 36 test functions, all passing (2026-11-03)

---

## Dependencies

- Depends on: Cross-epic — `production/epics/card-database/` (`CardDatabase.has` / `card` lookups; a `CardFactory` fixture database double is acceptable for this unit test); story paths are assigned by that epic's concurrent `/create-stories` run. In-epic: none.
- Unlocks: `production/epics/card-effects/story-004-validator-step-bound-targeting.md`, `production/epics/card-effects/story-005-fixture-set-database-injection.md`

---

## Completion Notes
**Completed**: 2026-11-03 (started 21:00:42 UTC, ended 21:20:08 UTC)
**Criteria**: 4/4 passing (AC-02, AC-03, AC-04, AC-06), no deferred items
- AC-02 — `test_two_chosen_play_effects_report_e_fx_chosen_naming_host_and_second_default_id`, `test_chosen_on_a_non_play_trigger_is_e_fx_chosen`, `test_chosen_inside_a_choose_one_option_is_e_fx_chosen`
- AC-03 — `test_boss_passive_with_battlecry_is_e_fx_trigger`, `test_treasure_effect_targeting_self_is_e_fx_selector`, `test_unknown_filter_predicate_is_e_fx_filter`, `test_aura_op_outside_a_static_trigger_is_e_fx_op`, `test_non_modify_value_op_under_a_value_trigger_is_e_fx_op`, `test_empty_ops_is_e_fx_schema`, `test_ops_over_max_ops_per_effect_is_e_fx_schema_and_exactly_max_is_clean`, `test_duplicate_effect_id_within_the_host_is_e_fx_schema` (+ trigger/selector/op/schema siblings)
- AC-04 — `test_summon_of_an_unknown_card_id_is_e_fx_ref`, `test_summon_of_a_spell_transform_into_a_spell_and_equip_of_a_non_weapon_are_e_fx_ref`, `test_unknown_ref_path_is_e_fx_ref_path`, `test_target_ref_under_an_effect_without_chosen_is_e_fx_ref_path`
- AC-06 — `test_the_five_newer_ops_raise_no_op_unavailable_against_the_v1_primitive_table`, `test_a_primitive_table_lacking_add_card_to_deck_makes_shuffle_into_deck_op_unavailable`, `test_display_keyword_and_effects_disagreeing_either_way_warns_keyword_mismatch`, `test_constant_false_condition_warns_unreachable`, `test_repeat_with_times_zero_warns_unreachable`, `test_warnings_alone_carry_no_error_code_so_the_host_does_not_fail`
- Implementation Notes: `test_the_closed_code_set_is_exactly_the_thirteen_c10_names`, `test_every_emitted_code_is_in_the_closed_set`, `test_validation_is_pure_input_untouched_and_a_new_report_each_call`; no false positives on 43 C11 rows (`test_c11_coverage_rows_validate_with_no_entries`)
- Watched fail: all 31 negative tests failed against a stub returning `[]`; nine one-at-a-time source mutations (option `chosen`, `adjacent` anchor, nested keyword walk, host legality, `target` gating, condition fold, primitive check, context gating, float literals) each failed at least one test, then were restored.
**Verification**: `godot --headless --path . --import` exit 0; full suite (`commands.test`) 373 test cases, 0 failures, exit 0; smoke `godot --headless --quit-after 5` exit 0, no SCRIPT ERROR. The suite's 24 SCRIPT ERROR lines are other suites' intentional negative tests (RngStream / MetaApi / PlannerTask); this suite emits none.
**Run result**: N/A — the validator runs at data load with no screen of its own; its entries reach a player only through Card Database's `data_error` screen, which card-effects story 005 / card-database story 004 wire.
**Deviations** (all ADVISORY):
- `db` is typed `Variant`, not `CardDatabase`: `CardDatabase` has no `has` / `card` until card-database story 004 (parallel lane). Same precedent as `RulesEngine._init(db: Variant, …)`; TODO in the doc comment. Signature otherwise as ADR-0007: `static func validate_effects(host_kind: StringName, host_id: String, effects: Array, db: Variant, caps: Dictionary, primitives: PackedStringArray = EffectSchema.V1_PRIMITIVES) -> Array` — the optional sixth parameter is the story's AC-06 allowance; stage 7b's five-argument call gets the v1 table.
- Host kinds: `card` (type from `db.card(host_id).type`), `hero_power`, `treasure`, and both `passive` (AC-03) and `boss` (what card-database story 004 passes for BossDef). Paths are rooted at `passive/…` for those.
- `caps` keys read as ADR-0007 spells them (`MAX_OPS_PER_EFFECT`, `MAX_REPEAT`, `MAX_SUMMON_COUNT`) or snake_case (story 002 owns the JSON key naming; match-rules uses snake_case). A missing cap skips its bound — 7a `validate_config` reports missing knobs.
- DD-M09 keywords and the CR-3/CR-4 `set` / `type` / `rarity` enums are mirrored in `EffectSchema` with TODOs (no owning constant exists in `src/` yet).
- Interpretations beyond the C10 wording: `shuffle_into_deck.card_id` is existence-checked (`E_FX_REF`); a `chosen` below effect level must reuse an effect-level `chosen` (`E_FX_CHOSEN`); `trigger_subject` / `trigger_source` selectors and `of: trigger_subject` under a trigger that does not supply them are `E_FX_SELECTOR`; a filter predicate value outside its enum is `E_FX_FILTER`; scope values (other than filter-valued keys) are not checked.
- `E_FX_BUDGET` and `E_FX_OP_TARGET` are in `CODES` but never emitted (story 004).
**Open for other stories**: card-database story 004's merge maps every entry to severity `error`; `W_FX_*` entries must map to `warning` (C10: warnings never fail the host). BossDef `passive: null` must not be passed to the typed `effects: Array` parameter (skip, or pass `[]`).
**Test Evidence**: `tests/unit/card_effects/card_effects_validator_schema_test.gd`
**Reviewed by**: self, no independent review (review lean; `/code-review` not run — QL-TEST-COVERAGE and LP-CODE-REVIEW skipped, Lean mode)
