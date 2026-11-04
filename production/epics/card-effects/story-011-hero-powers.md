# Story 011: Hero powers — Whetstone, Rot and Insight through the `hero_power` trigger

> **Epic**: Card Effects
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-04

## Context

**GDD**: `design/gdd/card-effects.md`
**Requirement**: `TR-card-effects-002` (`hero_power` is a play trigger; DD-M13)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Effect Resolver / Validator Boundary
**ADR Decision Summary**: A hero power is a `hero_power`-triggered effect on a `HeroPowerDef` host, resolved as the first step of the `hero_power` command through primitives only; a hero power is "a spell-like effect that is not a spell" (no Spell Damage by default, F1); `conditional` reads live state inside the atomic pass (C6.0).
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (by version; the APIs used predate 4.3 and are LOW)
**Engine Notes**: ADR-0007 Engine Compatibility — no post-cutoff APIs.

**Control Manifest Rules (this layer)**:
- Required: mutate only through primitives (`equip_weapon`, `apply_enchantment`, `apply_damage`, `summon_minion`, `draw`); one effect pass = one C10 step
- Forbidden: never call the death check between ops (Rot's `is_dying` depends on it); never write match state directly (gate G7)
- Guardrail: `RulesEngine.submit()` ≤ 5 ms

---

## Acceptance Criteria

*From GDD `design/gdd/card-effects.md` (C11 rows 8, 16, 25; C3 `is_dying`, `deck_top`; C5 `buff` on deck cards, `summon position`; Edge Cases; AC-15, AC-43, AC-44), scoped to this story:*

- [x] **AC-15** GIVEN row 8 (War hero power Whetstone) with no weapon, WHEN used, THEN `weapon_equipped` (1/2 `war_whetstone_blade`) and `effect_resolved.ops[0].values.branch == "else"`; WHEN used next turn with the Blade held, THEN `enchantment_applied{attack_delta: 1, expires: end_of_turn}` on the weapon and no equip (`branch == "then"`); at that End step the enchantment is removed (`enchantment_removed`).
- [x] **AC-43** GIVEN row 16 (Rot) used on an enemy 2/1, WHEN resolved, THEN the log reads `damage_dealt{amount: 1}`, `minion_summoned{decay_husk}` at the rightmost friendly slot (`position: end`), `effect_resolved` (`ops[1].outcome == applied`), then `minion_died` for the target — the Husk arrives before the target's Deathrattle resolves; GIVEN an enemy 2/3 instead, THEN damage only, no `minion_summoned`, `ops[1].outcome == skipped`; GIVEN a 1/1 with Divine Shield, THEN `divine_shield_popped`, no summon (`is_dying` stays false).
- [x] **AC-44** GIVEN row 25 (Insight) with a 3-cost spell on top of the deck, WHEN used, THEN `enchantment_applied{cost_delta: 1, expires: end_of_turn}` precedes `card_drawn`, that card's `effective_cost` reads 4 until the owner's End step and 3 after it; GIVEN an empty deck, THEN `ops[0].outcome == no_target` and one fatigue damage event, no enchantment.

---

## Implementation Notes

*Derived from ADR-0007 Decision 1 and GDD C11 rows 8 / 16 / 25:*

- Heroes H-3's sketch vocabulary maps 1:1 and adds nothing: `branch` → `conditional`, `has_weapon` → `{exists: owner_weapon}`, `enchant` → `buff`, `equip_weapon` → `equip`, `left_play` → `is_dying`, `bind/$drawn` → `buff` on `deck_top` then `draw`. No `targeting` field (C1 rule 1); the `hero_power` command supplies `target_id` for Rot and Brand.
- `conditional` logs the evaluated condition and the branch taken in `values` (`branch: then | else`); the branch not taken is one `skipped` entry.
- `summon` from a non-minion source (hero power) resolves `source_slot` / `right_of_source` to `end` (C5).
- `buff` with `cost` on a `deck_top` instance: the enchantment travels with the instance into hand (C5); expiry is match-rules C4 End step 5 (card instances in S's hand and deck are included — cross-review C-16a).
- The Spell Damage rule for hero powers is F1 (`auto` → host is not a spell → no scaling) and is already covered by story 007's AC-13; Brand (row 44) needs nothing new here.
- The hero-power host is `db.hero_power(id)`; `host_kind: hero_power` in `effect_resolved`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 006: play-trigger plumbing; Story 007: `conditional`, value refs
- Story 012: enchantment expiry (`until_end_of_turn`) in general — this story asserts it through the weapon and the drawn card only
- `production/epics/heroes/`: `hero_powers.json` content and hero identities; `production/epics/match-rules/`: the `hero_power` command, `HERO_POWER_USED`, Freeze not blocking powers

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/gameplay/effects/ops.gd` — modified (`buff` takes a card instance in hand or deck when it has `cost`: `CARD_INSTANCE_PARAMS`, `_target_kind`; `conditional` entries carry `values.branch`; `summon` logs `values.position`, `end` for a non-minion source: `_source_index`)
- `src/gameplay/effects/selectors.gd` — modified (`KIND_CARD`, `CARD_TARGET_ZONES`, `is_card_instance`; `deck_top` and `is_dying` already existed from story 007)
- `src/gameplay/effects/values.gd` — modified (`exists` over a reference selector such as `owner_weapon` reads the reference instead of an empty pool)
- `src/gameplay/match/rules_engine.gd` — modified (`attack()`: a hero's weapon attack includes the weapon's own enchantments; 2 added lines)
- `tests/unit/card_effects/card_effects_hero_powers_test.gd` — created (12 tests)
- `src/gameplay/effects/effect_resolver.gd` — unchanged: the `hero_power` host lookup (`db.hero_power(id)` for a `power_` id, `host_kind: hero_power`) shipped with story 006

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/card_effects/card_effects_hero_powers_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] Created — 12 tests, passing in the full suite

---

## Dependencies

- Depends on: `production/epics/card-effects/story-006-play-triggers-one-pass.md`, `production/epics/card-effects/story-007-values-selectors-spell-damage.md`. Cross-epic: `production/epics/match-rules/` (`hero_power` command, `equip_weapon`, `apply_enchantment` on card instances, End step 5 expiry, fatigue), `production/epics/heroes/` (the three `HeroPowerDef` records — the fixture from story 005 carries rows 8/16/25 until then).
- Unlocks: gate entry condition 5 (War starter deck resolves) together with story 006; `production/epics/heroes/` stories

## Readiness

`/story-readiness` (by hand, 2026-11-04, Tier: workflow full, review lean): **READY**.
Design Completeness: GDD C11 rows 8/16/25, C3, C5 and AC-15/43/44 traced; ACs testable.
Architecture Completeness: ADR-0007 Accepted (version 2026-11-03 = story); TR-card-effects-002
active; Manifest Version 2026-11-03 current. Scope Clarity: estimate M, Out of Scope and
dependencies stated. Open Questions: no markers; stories 006 and 007 Complete. Asset
References: none. Definition of Done: 3 ACs, Logic type, test evidence path, `submit()` ≤ 5 ms
guardrail stated (perf is story 016's). QL-STORY-READY skipped — Lean mode.

## Completion Notes
**Completed**: 2026-11-04 (started 03:45:31 UTC, ended 03:53 UTC)
**Criteria**: 3/3 passing (AC-15, AC-43, AC-44), no deferred items
- AC-15 — `test_whetstone_with_no_weapon_equips_the_blade_on_the_else_branch` (1/2 Blade, `ops[0].values.branch == "else"`, `host_kind: hero_power`), `test_whetstone_with_the_blade_held_buffs_it_this_turn_on_the_then_branch` (`enchantment_applied {attack_delta: 1, expires: end_of_turn}` on the Blade, no `weapon_equipped`, `branch: then`), `test_whetstones_blade_buff_is_removed_at_the_owners_end_step`; beyond the AC, `test_a_whetted_blade_swing_deals_the_blade_attack_plus_1`.
- AC-43 — `test_rot_on_an_enemy_2_1_summons_a_husk_at_the_right_before_the_target_dies` (order `damage_dealt`, `minion_summoned` at index 1 of a one-minion board, `effect_resolved`, `minion_died`; `ops[1]` applied, `values.position: end`), `test_rot_on_an_enemy_2_3_deals_damage_only_and_skips_the_summon`, `test_rot_on_a_divine_shield_1_1_pops_the_shield_and_summons_nothing`; C5 fallback: `test_a_hero_power_summon_with_no_position_fills_from_the_right`.
- AC-44 — `test_insight_costs_the_drawn_card_1_more_before_drawing_it` (`enchantment_applied {cost_delta: 1}` before `card_drawn` of the same instance; `effective_cost` 4), `test_insights_cost_increase_expires_at_the_owners_end_step` (3 after), `test_insight_on_an_empty_deck_is_no_target_then_one_fatigue_hit`; C5 "`cost` only": `test_a_buff_without_cost_on_a_deck_card_is_skipped`.
- Watched fail: 9 of 12 failed before the code. The 3 that passed by construction were mutated, one mutation per run, each restored: `is_dying` always true (all three Rot tests failed), an empty target set folded to `applied` (empty-deck and cost-only tests failed), a card instance legal without `cost` (cost-only test failed). The summon fallback was also mutated (non-minion source → slot 0): its test failed.
**Verification**: `godot --headless --path . --import` exit 0; full suite (`commands.test`) 1237/1237, exit 0, 85 SCRIPT ERROR lines (the story-007 baseline, all from other systems' negative tests); smoke exit 0, no SCRIPT ERROR; `tools/lint/gates.sh` PASS; parse check of the 5 changed scripts ok.
**Run result**: N/A — nothing renders: the real resolver is not yet composed into a playable match (no `MatchDriver`); match-ui story 005 shows Whetstone.
**Deviations** (all ADVISORY):
- **Two defects fixed outside the story's planned files.** (1) `values.gd`: `{exists: owner_weapon}` was always false, because `exists` read `EffectSelectors.pool`, which is empty for a reference selector, so Whetstone re-equipped every time. `exists` over a reference now reads `EffectSelectors.entities` (no draw). (2) `rules_engine.gd` `attack()` added `weapon.attack` but not the weapon's own enchantments, so Whetstone's +1 never reached combat (card-effects' `weapon_attack` ref already folded them). The fix is 2 added lines in `attack()` only; the file is also being edited by the match-rules review-fix lane.
- **DD-X15 not asserted.** `_attack_damage_step` still passes the weapon as the swing's `damage_dealt.source`; DD-X15 makes it the hero. That is match-rules C8, owned by the review-fix lane, so the swing test asserts the damage and target only.
- **The `hero_power` host lookup, `equip` and `deck_top` needed no change**: stories 006/007 shipped them. The C5 summon fallback already placed the copy at `end`; this story logs it as `values.position` and tests it.
- **`values.branch` is on every entry of a `conditional`**, the skipped ones included, beside story 007's `values.condition`. So `ops[0].values.branch` reads the branch taken, whichever branch `ops[0]` belongs to (`then` is listed first).
**Test Evidence**: `tests/unit/card_effects/card_effects_hero_powers_test.gd`
**Reviewed by**: not reviewed — `/code-review` NOT ASSESSED (agent-requiring gate, lean lane run)
