# Story 004: F6 static step bound, `E_FX_BUDGET` and derived `targeting_spec`

> **Epic**: Card Effects
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-04

## Context

**GDD**: `design/gdd/card-effects.md`
**Requirement**: `TR-card-effects-006` (F6 bound), `TR-card-effects-001` (targeting_spec derived, never stored), `TR-card-effects-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Effect Resolver / Validator Boundary (also ADR-0002: Card Database rejects a stored `targeting` field, CR-3)
**ADR Decision Summary**: `validate_effects` computes `effect_step_bound` per F6 and raises `E_FX_BUDGET` above `caps.EFFECT_STATIC_STEP_LIMIT`; the same function yields `targeting_spec` for the host — one derivation (`derive_targeting_spec`), two callers: the validator checks it, the resolver memoises it per `def_id`; `step_bound` is exposed for tests and `/balance-check`.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (by version; the APIs used predate 4.3 and are LOW)
**Engine Notes**: ADR-0007 Engine Compatibility — no post-cutoff APIs. Pure integer arithmetic on Dictionaries.

**Control Manifest Rules (this layer)**:
- Required: `targeting_spec` is derived via `derive_targeting_spec`, memoised per `def_id`; `legal_commands()` ≤ 2 ms relies on that memo
- Forbidden: never read `targeting` from a stored field (Card Database rejects it, CR-3)
- Guardrail: `legal_commands()` ≤ 2 ms (`targeting_spec` memoised per `def_id`)

---

## Acceptance Criteria

*From GDD `design/gdd/card-effects.md` (C1 rule 1, C3 `chosen`, C10, F6; AC-05, AC-07), scoped to this story:*

- [ ] **AC-05** GIVEN "deal 1 damage to all minions, 20 times" (`repeat` `times: 20` over `all_minions`), WHEN validated with `caps.EFFECT_STATIC_STEP_LIMIT = 250`, THEN `E_FX_BUDGET` with `bound = 321` in the message/values; with `times: 10` it passes (`161`). `EffectValidator.step_bound(effect, caps)` returns the F6 value for the C11 examples: row 34 → 3; a non-literal `count` on `summon` is taken at `caps.MAX_SUMMON_COUNT`, a non-literal `times` at `caps.MAX_REPEAT`, any other non-literal at `HAND_SIZE` (10); `steps(conditional) = max(Σ then, Σ else)`, `steps(choose_one) = max over options`.
- [ ] **AC-07** GIVEN row 18 (`chosen`, `kind: any`) and row 10 (`chosen` friendly minion, Battlecry), WHEN `targeting_spec` is queried, THEN row 18 → `{mode: required, filter: {kind: any}}`, a `chosen` with `optional: true` → `mode: optional`, a host with no `chosen` → `mode: none`; and `EffectResolver.legal_targets(def_id, source)` for row 18 lists every non-Stealth enemy character plus all friendly characters; row 10 on an empty friendly board → empty list, and match-rules' `legal_commands()` still lists the minion (a Battlecry with no legal target is still playable; the effect does not resolve — Edge Cases).
- [ ] **AC-3 (C10 `E_FX_OP_TARGET`)** GIVEN `discover` with `then: cast` whose `list` (or load-time pool after `filter`) contains a spell whose derived `targeting_spec.mode` is not `none`, WHEN validated, THEN `E_FX_OP_TARGET`; GIVEN `freeze` with `targets: hand`, THEN `E_FX_OP_TARGET` (a selector that can never yield a legal kind).

---

## Implementation Notes

*Derived from ADR-0007 Decision 8 and GDD F6 / C1 rule 1:*

- `static func step_bound(effect: Dictionary, caps: Dictionary) -> int` = `1 + Σ steps(op)`; `steps(leaf) = max_targets(op.targets or effect.targets) × count(op)`; `max_targets`: `all_*` 16, single 1, `adjacent` 2, `hand` 10, `random_* n` n, side-scoped 1. `steps(repeat) = times × Σ steps(inner)`.
- `static func derive_targeting_spec(effects: Array) -> Dictionary` scans play triggers (`battlecry`, `cast`, `hero_power`) for an effect-level `chosen` and returns `{mode, filter}`; `validate_effects` calls it (C1 rule 1 is where `E_FX_CHOSEN`'s "more than one" is detected — story 003 — and `targeting_spec` is the one derivation).
- `EffectResolver.targeting_spec(def_id)` memoises the derivation per `def_id` in the resolver-local Dictionary (story 002's memo); `legal_targets(def_id, source)` applies the filter over canonical order and excludes enemy Stealth minions for `chosen` (match-rules C12) — Stealth exclusion is the only runtime rule beyond the filter.
- The 10 for `HAND_SIZE` is match-rules' knob; the validator receives it through `caps` or the `configs` map (ADR-0002 D4 passes all parsed bodies; the 7b adapter may fold `configs["match_rules"].HAND_SIZE` into `caps`) — never a literal in the validator.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: every other `E_FX_*` code
- Story 006: the `chosen` target reaching the ops at runtime (`target` ref, `NO_LEGAL_TARGET` rejection path belongs to match-rules C6)
- Story 016: `RESOLUTION_STEP_CAP` at runtime (AC-38)

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/gameplay/effects/effect_validator.gd` — modified (`step_bound`, `derive_targeting_spec`, `stage7_caps`, `CAP_EFFECT_STATIC_STEP_LIMIT` / `CAP_HAND_SIZE` / `BOUND_UNKNOWN`; `E_FX_BUDGET` per effect; `E_FX_OP_TARGET` for a targeted op whose selector can never yield a legal kind, or has none, and for `discover` `then: cast` over a targeted spell)
- `src/gameplay/effects/effect_schema.gd` — modified (`TARGETING_*` modes; C5 "Legal targets" as `OP_TARGET_KINDS`, `SELECTOR_KINDS`, `SELF_KINDS`, `FILTER_KIND_NARROWS`; F6 `max_targets` constants, `N_SELECTORS`, `CONTROL_OPS`)
- `src/gameplay/effects/effect_resolver.gd` — modified (`targeting_spec` and `definition` memoised in the story-002 entry; `legal_targets`; the memo asks `has()` first and routes `power_` ids to `hero_power()`)
- `src/gameplay/effects/selectors.gd` — created (`EffectSelectors`: canonical `characters`, `is_dying`, `has_keyword`, `chosen_candidates`, the C3 character filter `matches`; grown by stories 006–007)
- `tests/unit/card_effects/card_effects_validator_bound_targeting_test.gd` — created (31 tests)
- `tests/unit/card_effects/card_effects_validator_schema_test.gd` — modified (`_caps()` carries `hand_size`, as `stage7_caps` folds it)
- `tests/unit/card_effects/card_effects_runtime_binding_test.gd` — modified (`FakeCardDatabase.has()`, which the memo now asks first)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/card_effects/card_effects_validator_bound_targeting_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] Created — 31 tests, passing in the full suite

---

## Dependencies

- Depends on: `production/epics/card-effects/story-003-validator-schema-codes.md`, `production/epics/card-effects/story-002-runtime-binding-config.md` (resolver memo). Cross-epic: `production/epics/match-rules/` (`legal_commands()` calling `targeting_spec(def_id)`; `HAND_SIZE` in `match_rules.json`).
- Unlocks: `production/epics/card-effects/story-005-fixture-set-database-injection.md`, `production/epics/card-effects/story-006-play-triggers-one-pass.md`

> **Blocker (2026-11-03, sprint-3 lane `lane/s3-card-effects-002-005`, checked 23:15 UTC):**
> not started. In-epic dependencies are met (story 003 Complete; story 002 Complete in
> commit `e1c58eb` on that lane). The cross-epic one is not: AC-07's last clause
> ("match-rules' `legal_commands()` still lists the minion") needs match-rules story 010
> (`play_card` in `legal_commands()`, which then calls `targeting_spec(def_id)`), and on
> this branch `RulesEngine.legal_commands()` still lists only the mulligan and `end_turn`
> (`_validate` carries `TODO(stories 010, 012, 016): play_card`). The story allows no
> stub for it, so it stays Ready and waits for MR-010 to merge (sprint-3 plan: M2; if
> MR-010 misses M2, CE-004/005 carry). Story 002 left the memo entry
> (`EffectResolver._memo_entry`, `{effects}`) ready for `targeting_spec`, and
> `EffectValidator` reads caps snake_case (`caps.effect_static_step_limit`,
> `caps.max_summon_count`, `caps.max_repeat`).
>
> **Blocker cleared (2026-11-04 00:00 UTC, sprint-3 lane `lane/s3-card-effects-004-006`):**
> match-rules story 010 is merged on trunk (`66640a4`): `RulesEngine.legal_commands()` lists
> `play_card` per legal target and calls `resolver.targeting_spec(def_id)` /
> `legal_targets(def_id, source)`. Started.

---

## Completion Notes
**Completed**: 2026-11-04 (started 00:00:04 UTC, ended 00:09:39 UTC)
**Criteria**: 3/3 passing (AC-05, AC-07, AC-3), no deferred items
- AC-05 — `card_effects_validator_bound_targeting_test.gd`: `test_repeat_20_over_all_minions_is_e_fx_budget_with_bound_321` (message carries 321 and 250; `max_repeat` raised to its safe-range ceiling 20 so `E_FX_BUDGET` is the only entry — at the default 10, `times: 20` is also `E_FX_OP`), `test_repeat_10_over_all_minions_passes_with_bound_161`, `test_a_bound_exactly_at_the_limit_passes_and_one_over_fails`, `test_step_bound_of_row_34_is_3`, `test_a_non_literal_summon_count_is_taken_at_max_summon_count`, `test_a_non_literal_times_is_taken_at_max_repeat`, `test_any_other_non_literal_is_taken_at_hand_size`, `test_conditional_takes_the_larger_branch`, `test_choose_one_takes_the_largest_option`, `test_max_targets_follow_the_f6_table`, `test_a_bound_needing_hand_size_without_it_in_caps_fails_closed`, `test_stage7_caps_fold_match_rules_hand_size_into_the_card_effects_body`.
- AC-07 — `test_row_18_targeting_spec_is_required_with_kind_any`, `test_an_optional_chosen_is_mode_optional`, `test_a_host_without_a_play_chosen_is_mode_none`, `test_targeting_modes_are_the_engine_spellings`, `test_resolver_targeting_spec_is_the_derivation_memoised_per_def_id`, `test_a_def_id_the_database_lacks_has_no_targeting_and_is_not_looked_up`, `test_row_18_legal_targets_are_non_stealth_enemies_and_all_friendlies_in_canonical_order` (real `RulesEngine` + real `EffectResolver`), `test_stealth_granted_by_an_enchantment_also_protects_an_enemy`, `test_row_10_on_an_empty_friendly_board_has_no_legal_target_and_is_still_playable` (`legal_commands()` lists `play_card(0, 0, null)`), `test_row_10_with_a_friendly_minion_lists_it_as_the_only_target`, `test_a_dying_minion_is_never_a_legal_target`, `test_legal_targets_of_a_def_without_chosen_is_empty`.
- AC-3 — `test_freeze_on_hand_is_e_fx_op_target`, `test_an_op_inheriting_an_illegal_effect_level_selector_is_e_fx_op_target`, `test_a_chosen_filter_narrowing_to_heroes_rules_out_a_minion_op`, `test_a_targeted_op_with_no_selector_at_all_is_e_fx_op_target`, `test_legal_selector_and_op_pairs_are_clean`, `test_discover_then_cast_over_a_list_with_a_targeted_spell_is_e_fx_op_target`, `test_discover_then_cast_over_the_filtered_load_time_pool_is_checked`.
- Watched fail: the suite failed to parse before the code existed (missing `step_bound`, `derive_targeting_spec`, `stage7_caps`, `EffectSchema.TARGETING_*`); then one mutation per run, each restored: `F6_MAX_TARGETS_ALL` 16 → 15 (6 bound tests failed), the enemy-Stealth exclusion removed (both Stealth tests failed), `_check_op_target` disabled (4 op-target tests failed), `targeting_spec` re-derived per call (the memo test failed), the pool filter ignored in the `then: cast` check (the pool test failed).
**Verification**: `godot --headless --path . --import` exit 0; full suite (`commands.test`) 976 test cases, 0 failures, exit 0; smoke `godot --headless --quit-after 5` exit 0, no SCRIPT ERROR; parse check of every changed `.gd` ok; `tools/lint/gates.sh` PASS (a G3 hit on a message naming the composition root was reworded), `tools/lint/no_global_rng.sh` 0 hits; the ADR-0007 G7 regex over `src/gameplay/effects/` 0 hits. The suite's 85 SCRIPT ERROR lines all come from card-database, rng, event-log, boss-ai and boot negative tests; card_effects suites emit none.
**Run result**: N/A — the validator runs at Card Database load and `targeting_spec` / `legal_targets` inside `RulesEngine` validation, with nothing on screen; no match UI exists yet to show a highlight.
**Deviations** (all ADVISORY):
- **`HAND_SIZE` reaches the validator through `caps["hand_size"]`**, folded from the `match_rules` body by the new `EffectValidator.stage7_caps(bodies)` (the Implementation Notes' "the 7b adapter may fold `configs["match_rules"].HAND_SIZE` into `caps`"). A bound that needs it while it is absent is `E_FX_BUDGET` ("cannot be computed: caps lack hand_size") and `step_bound` returns `BOUND_UNKNOWN` (-1) — fail closed, never a pass. **Boot registration change for the orchestrator** (boot.gd not edited): in `Boot._effects_adapter`, pass `EffectValidator.stage7_caps(bodies)` instead of `bodies["card_effects"]` as the fifth argument of `validate_effects`. Until then any shipped effect using `hand`, or a non-literal `count` / `n`, fails stage 7b (no shipped card data exists yet).
- **`E_FX_OP_TARGET` beyond the two named cases:** a targeted op (C5 "Legal targets" column, now `EffectSchema.OP_TARGET_KINDS`) with no selector at op or effect level is also `E_FX_OP_TARGET` (it can never reach a target). Side-scoped ops ignore an inherited effect-level selector (row 10's `draw` beside its `chosen`) — in the bound too (`max_targets` 1).
- **`then: cast` load-time pool:** `collectible` reads `db.cards_by_type("spell")` minus tokens and the `boss` set (F4); `deck` / `hand` pools check every spell, since any spell may be held. Character-only predicates and non-literal values in a pool filter do not narrow, so the checked set is never smaller than the runtime one.
- **F6 `hand` with `n`:** `max_targets(hand)` is `n` when the selector gives one, else `HAND_SIZE`; `deck_top`, `deck_random`, `enemy_hand_random` take `n` (default 1) like `random_*`.
- **The memo asks `has()` before the typed lookup** and routes a `power_` id (CR-2) to `hero_power()` — the engine asks `targeting_spec` for the hero power too, and `card()` on a HeroPowerDef logs and asserts. Story 002's test double gained `has()`.
- **`EffectSchema` and two story-002/003 test files changed** (not in the planned Files list): the C5 legal-target and F6 tables live with the rest of the DSL vocabulary; `card_effects_validator_schema_test.gd` `_caps()` gained `hand_size` (its C11-rows test hit the fail-closed bound on row 24's `hand`).
- `legal_targets` also excludes dying characters (C3: selectors never yield one); at command time none exists.
- Filter value expressions (`attack_le: {ref: …}`) in a `chosen` filter never match until story 007 (TODO in `selectors.gd`); no C11 row uses one.
**Test Evidence**: `tests/unit/card_effects/card_effects_validator_bound_targeting_test.gd`
**Reviewed by**: self, no independent review (lean: LP-CODE-REVIEW and QL-TEST-COVERAGE skipped — Lean mode; `/code-review` not run)
