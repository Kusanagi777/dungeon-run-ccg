# Story 017: EffectValidator — Silence before destroy on one target (`E_FX_OP`, DD-X21)

> **Epic**: Card Effects
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-11-04
> **Last Updated**: 2026-11-04 (implemented, sprint 5 L7 W2)

## Context

**GDD**: `design/gdd/card-effects.md` (C5 "Silence before destroy", C10 `E_FX_OP` row, Edge Cases, AC-47) · `design/gdd/match-rules.md` (C12 Deathrattle row, C13 step 2 — why the order matters) · `design/gdd/content.md` (CN-6 step 6 style guide)
**Requirement**: `TR-card-effects-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Effect Resolver / Validator Boundary
**ADR Decision Summary**: `EffectValidator.validate_effects(host_kind, host_id, effects, db, caps) -> Array` is `static` and pure, and returns `[{code, host_id, effect_id, path, message}]` from the closed `E_FX_*` / `W_FX_*` set. The new check adds no code: it reports under the existing `E_FX_OP`, as DD-X16's aura-Stealth rule did.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (by version; no post-cutoff API — static GDScript over Dictionaries)
**Engine Notes**: none beyond story 003.

**Control Manifest Rules (this layer)**:
- Required: codes are the closed `E_FX_*` / `W_FX_*` set; the validator reads nothing but its arguments.
- Forbidden: never add an `E_FX_*` / `W_FX_*` code without a card-effects GDD change. This story adds none.
- Guardrail: `validate_effects` over the full v1 fixture under 50 ms (story 016).

**Why (owner decision DD-X21, 2026-11-04).** When one effect destroys a minion and then Silences it, the Deathrattle fires (match-rules C13 step 2; runtime in story 009). A card that means "and its Deathrattle does not fire" must list `silence` first. The content validator rejects the destroy-first order so that no card ships it by accident.

---

## Acceptance Criteria

*From GDD `design/gdd/card-effects.md` (C5, C10, AC-47), scoped to this story:*

- [x] **AC-47 (destroy before silence)** GIVEN an effect with `targets: chosen` and ops `[destroy, silence]`, WHEN validated, THEN exactly one `E_FX_OP` whose message names both op paths (`ops[0]`, `ops[1]`). GIVEN `[silence, destroy]`, THEN no row.
- [x] **AC-47 (reference, not search)** GIVEN `destroy` on `chosen` and `silence` with its own `targets: all_enemy_minions`, THEN no row (a search selector never yields a dying minion, C3). GIVEN both ops reaching `self`, `target`, `trigger_subject` or `trigger_source` (own `targets` or inherited), THEN `E_FX_OP` for each reference kind (one case per reference).
- [x] **AC-47 (structure)** GIVEN a `repeat` holding `[silence, destroy]` on `chosen`, THEN `E_FX_OP` (iteration 2's silence follows iteration 1's destroy). GIVEN `destroy` in a `conditional`'s `then` and `silence` in its `else`, or in two `choose_one` options, THEN no row. GIVEN `destroy` inside a `conditional` `then` followed by a top-level `silence` on the same reference, THEN `E_FX_OP`.
- [x] **Shipped data** GIVEN `assets/data/cards_*.json`, `bosses.json`, `treasures.json` and `hero_powers.json` as of 2026-11-04, WHEN loaded, THEN no new `E_FX_OP` row. No shipped record has both ops; the only `destroy` is `war_headsman` and the only `silence` is `neutral_hush_owl`.

---

## Implementation Notes

- Walk each effect's ops in execution order, carrying the effective target of each op: its own `targets`, else the effect's. Only explicit references (`chosen`, `self`, `target`, `trigger_subject`, `trigger_source`) are tracked; any other selector is ignored for this check.
- Branches: `conditional` `then` and `else` are walked as alternatives. Each sees the ops before the `conditional`, and the ops after it see the union. `choose_one` options are walked the same way. A `repeat` body is walked twice, which models iteration 2 following iteration 1.
- The rule is per effect. Two effects on one host are two passes with a death check between them (card-effects C6.0), so a later effect's `silence` cannot reach a minion the earlier one destroyed.
- The message text follows the DD-X16 row's style: "destroy before silence on one target (DD-X21): ops[i] destroy, ops[j] silence — list silence first".

---

## Out of Scope

- Story 009: the runtime (the Deathrattle fires on destroy-then-silence; match-rules AC-46).
- Damage-then-silence ordering: it is not statically checkable (the damage may not kill), and match-rules C13 leaves it unprotected by design.

---

## Files

- `src/gameplay/effects/effect_validator.gd` (the order check under `E_FX_OP`)
- `tests/unit/card_effects/card_effects_validator_schema_test.gd` (AC-47 cases; watch each fail before the check lands)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/card_effects/card_effects_validator_schema_test.gd` — the AC-47 cases exist and pass

**Status**: [x] Created: 21 tests in `tests/unit/card_effects/card_effects_validator_schema_test.gd`

---

## Dependencies

- Depends on: `production/epics/card-effects/story-003-validator-schema-codes.md`, `production/epics/card-effects/story-004-validator-step-bound-targeting.md` (both Complete)
- Independent of story 009 (it can land first)
- Unlocks: nothing blocking; content batches gain the check at their next validate run

---

## Readiness (2026-11-04, by hand, sprint 5 L7 W2)

**Verdict: READY.** Workflow `full` (card-effects override).

- Passing: requirement traced (C5, C10, AC-47; `TR-card-effects-005`); ADR-0007 Accepted; Manifest Version 2026-11-04 equals the manifest; stories 003 and 004 Complete; DD-X25 on trunk, so `effect_validator.gd` is free; no open markers; 4 criteria; Logic evidence path named.
- **QA plan adds one case the story omits:** `[destroy, silence]` inside a `repeat` also reports (C10 "in either order"). Tested.
- **`target` is not a C3 selector.** AC-47 and C5 name it as a reference, and C3 says `chosen` is "the same entity as `target`", but `targets: "target"` is `E_FX_SELECTOR` (`EffectSchema.SELECTORS`). Resolved from the docs: the walk reads `target` as `chosen`, so the AC's row is reported, next to the `E_FX_SELECTOR`. No rule invented.
- QL-STORY-READY skipped: Lean mode.

## Completion Notes

**Completed**: 2026-11-04
**Started / ended (UTC)**: 00:41:20 / 00:51:41
**Criteria**: 4/4 passing, all by automated test (none deferred)
**Test Evidence**: `tests/unit/card_effects/card_effects_validator_schema_test.gd` (+21)
**Reviewed by**: self, no independent review (the orchestrator runs `/code-review` at the end of the wave; a lane does not review its own work)
**Run result**: N/A: a Logic story changes nothing visible; the full suite and `godot --headless --quit-after 5` are the evidence.

**Traceability**

| Criterion | Covered by |
|-----------|------------|
| AC-47 destroy before silence | `test_ac47_destroy_before_silence_on_chosen_is_one_e_fx_op_naming_both_paths`, `test_ac47_silence_before_destroy_on_chosen_is_clean`, `test_ac47_a_gap_between_the_two_ops_changes_nothing`, `test_ac47_every_silence_after_the_destroy_is_named_once` |
| AC-47 reference, not search | `test_ac47_a_search_selector_never_counts_as_the_destroyed_minion`, one test each for `chosen`, `self`, `target`, `trigger_subject`, `trigger_source` (own and inherited), `test_ac47_two_different_references_are_two_minions` |
| AC-47 structure | `test_ac47_a_repeat_holding_both_ops_counts_in_either_order`, `test_ac47_a_repeat_holding_one_of_the_ops_orders_like_a_plain_op`, `test_ac47_a_then_and_its_else_never_order_against_each_other`, `test_ac47_two_choose_one_options_never_order_against_each_other`, `test_ac47_ops_after_a_branch_see_a_destroy_from_either_arm`, `test_ac47_each_arm_sees_a_destroy_before_the_branch`, `test_ac47_silence_first_stays_clean_around_a_branch`, `test_ac47_one_arm_does_not_leak_its_destroy_into_the_next_arm`, `test_ac47_the_rule_is_per_effect`, `test_ac47_a_malformed_tree_is_reported_by_the_schema_checks_and_not_walked` |
| Shipped data | `validate.gd` Ready, 0 errors; the zero-row shipped tests in `content_mvp1_data_test.gd` and the Boot load stay green. `destroy` appears only on `war_headsman`, `silence` only on `neutral_hush_owl` (searched `assets/data`) |

**Seen failing first.** Against the unchanged validator 13 of the 21 failed. The other 8 pin what must stay clean, so each was seen failing against a deliberate mutant, one per run, restored after:

| Mutant | Killed by |
|--------|-----------|
| `repeat` body walked once | repeat in either order |
| arms share the state | then/else, two options, arm leak |
| no union after a branch | ops after a branch |
| a search counts as a reference | search selector |
| every reference is one reference | two different references |
| `target` not read as `chosen` | `target` case |
| no row dedupe | both repeat tests |
| ops walked twice at top level | silence-first cases, nine tests |
| state carried across effects | per effect |
| inherited `targets` ignored | thirteen tests |

Removing the "both ops present" early return alone survives, as it should: it only saves the walk.

**Verification**: `--import` exit 0; `gates.sh` G1 to G7 0 hits; `no_global_rng.sh`, `parse-check.sh` clean; full suite 1750 cases, 0 failures, exit 0; smoke exit 0, no SCRIPT ERROR; `validate.gd` 0 errors. The suite's 88 SCRIPT ERROR lines equal the trunk baseline.

**Deviations**

- ADVISORY: QA plan's extra `repeat` case tested, as Readiness says.
- ADVISORY: a `repeat` with a literal `times: 1` holding `[silence, destroy]` also reports. C10 and the story give no exception for it ("counts in either order", "walked twice"), so none was added, though no iteration 2 exists. No shipped record has the shape.
- ADVISORY: one row per offending `silence` and reference, so `[destroy, silence, silence]` gives two rows. The AC's "exactly one" is the two-op case.
- ADVISORY: `ORDER_REFERENCES` sits in `effect_validator.gd`, the story's named file, not `effect_schema.gd`.

**Left open**

- `target` is listed as a reference by C3 and C5 but is not a selector name. A wording fix for the GDD owner; no behaviour depends on it, since such data already fails `E_FX_SELECTOR`.
