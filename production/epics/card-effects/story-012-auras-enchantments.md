# Story 012: Auras (`recompute_auras`), hand-cost auras and the enchantment lifecycle (F2, F3)

> **Epic**: Card Effects
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-04

## Context

**GDD**: `design/gdd/card-effects.md`
**Requirement**: `TR-card-effects-002` (C7 auras are composed from the `apply_enchantment(…, is_aura: true)` primitive inside the engine's `recompute_auras()` callback; the epic's module list names `recompute_auras()` under this requirement)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Effect Resolver / Validator Boundary
**ADR Decision Summary**: The engine's C10 loop calls `resolver.recompute_auras()` after every step; the resolver re-applies every live aura through the enchantment primitive in canonical source order and never calls `recompute_auras()` itself between ops.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (by version; the APIs used predate 4.3 and are LOW)
**Engine Notes**: ADR-0007 Engine Compatibility — no post-cutoff APIs.

**Control Manifest Rules (this layer)**:
- Required: `RulesEngine` owns the C10 loop (death check → `recompute_auras()` → queue pop); the resolver mutates only through primitives
- Forbidden: never call the death check or `recompute_auras()` between ops; never write `enchantments[]` directly (gate G7)
- Guardrail: `recompute_cost ≤ 16 × 16` selector evaluations per recompute (F2); `submit()` ≤ 5 ms

---

## Acceptance Criteria

*From GDD `design/gdd/card-effects.md` (C7, F1 `hand_aura_delta`, F2, F3, Edge Cases "Buffs, auras and Silence"; AC-26, AC-27, AC-28, AC-29), scoped to this story:*

- [x] **AC-26** GIVEN the friendly board `[row 26, row 26, vanilla 1/1, row 27]` left to right, WHEN auras are recomputed, THEN the 1/1 reads 5/3 (`+1 +1` attack from the two lords `+2` from adjacency = `+4`; health `+2`), each lord reads +1/+1 from the other only (row 27 is adjacent to neither), and row 27 reads +2/+2; one source never applies the same aura twice to one target.
- [x] **AC-27** GIVEN row 26 buffing a damaged 2/2 (now 3/1 after 2 damage), WHEN row 26 is Silenced, THEN at the next recompute the 2/2 has `health ≤ 0` and dies in the following loop pass, with `silenced` → `auras_recomputed` → `minion_died` in the log (Silence on a recipient strips and re-applies — net no change).
- [x] **AC-28** GIVEN a "+4/+4 until end of turn" on a 1/1 that then takes 4 damage, WHEN the owner's End step runs, THEN `enchantment_removed` then `minion_died` (F3: `damage_taken` unchanged, health `1 + 0 − 4`); a negative `buff` (`health: −2`) on a 3/3 with 2 damage kills the same way.
- [x] **AC-29** GIVEN row 24 ("Your spells cost (1) less", `aura` with `zone: hand`) on board and a 3-cost spell in hand, WHEN `effective_cost` is read, THEN 2; with two copies of row 24 → 1; with a 1-cost spell and two copies → 0, never negative (F1 clamps once).

---

## Implementation Notes

*Derived from ADR-0007 Decision 1 and GDD C7, F2, F3:*

- `recompute_auras()`: the engine strips every `is_aura` enchantment (its side of the contract), then calls the resolver, which walks live aura sources in canonical source order — player board L→R, boss board, then treasure/passive auras hosted on the hero slot (story 013 adds the treasure host) — skips silenced sources, evaluates each aura's `targets` selector afresh (`not_self`, `adjacent`, `all_friendly_minions`, `hand` + filter), and calls `apply_enchantment(target, {attack_delta, health_delta, cost_delta, keywords_added, is_aura: true})` once per (source, target). Agree with match-rules whether the strip lives in the engine or the resolver asks for it through a primitive; record the choice on `/dev-story`.
- Stacking is additive across sources (F2); `max_health` then follows match-rules F6; the engine floors derived `attack` at 0.
- `zone: hand` auras and `passive_hand` are the `hand_aura_delta` term of F1 and are evaluated at every F1 read (match-rules asks `effective_cost`); the treasure "spells cost 1 less" is **not** an aura (story 014, a `modify_cost` fold).
- `buff` with `duration: until_end_of_turn` → `expires: end_of_turn`; removal is match-rules C4 End step 5 of the **recipient's controller** (an enemy recipient keeps it one turn longer — intended, cross-review C-16b). The resolver only sets `expires`.
- Auras never grant `battlecry` / `deathrattle`; only stats, `cost` and the `give_keyword` keyword set.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 013: `aura` with `keywords` from a treasure host (AC-32), transforms dropping enchantments
- Story 014: `modify_cost` folds (the third F1 term)
- match-rules: `recompute_auras()` call placement, F6 health arithmetic, End step 5 expiry, Silence's `damage_taken` rule

---

## Files

- `src/gameplay/effects/effect_resolver.gd` (`recompute_auras`, `_aura_sources`, `_aura_run`; `TRIGGER_AURA` / `TRIGGER_PASSIVE_HAND`)
- `src/gameplay/effects/ops.gd` (`apply_aura`; `OP_AURA`, `AURA_KINDS`, `ZONE_HAND`; `buff` durations unchanged — shipped by story 006)
- `src/gameplay/effects/selectors.gd` (`RUN_AURA_RECOMPUTE`, `_left_out`: a pool during a recompute leaves out only `pending_destroy`)
- `src/gameplay/match/rules_engine.gd` (`_drain` + `_any_minion_dying`: one more death check after a recompute whose aura loss left a minion at `health ≤ 0`)
- `tests/unit/card_effects/card_effects_auras_enchantments_test.gd` (14 tests)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/card_effects/card_effects_auras_enchantments_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] Created — 14 tests, passing in the full suite

---

## Dependencies

- Depends on: `production/epics/card-effects/story-007-values-selectors-spell-damage.md` (selectors). Cross-epic: `production/epics/match-rules/` (C10 loop calling `recompute_auras()`, `apply_enchantment` with `is_aura`, F6, `effective_cost` F1, End step 5).
- Unlocks: `production/epics/card-effects/story-009-deathrattle-snapshot-counters.md` (AC-20), `story-013-transform-copy-keyword-aura.md`

## Readiness

`/story-readiness` (by hand, 2026-11-04, Tier: workflow full, review lean): **READY**.
Design Completeness: GDD C7, F1 `hand_aura_delta`, F2, F3, Edge Cases and AC-26…29 traced; fixture
rows 24/26/27 exist in `tests/fixtures/cards_effects_test.json`; ACs testable. Architecture
Completeness: ADR-0007 Accepted (version 2026-11-03 = story); TR-card-effects-002 active; Manifest
Version 2026-11-03 current. Scope Clarity: estimate M, Out of Scope and dependencies stated; story 007
Complete; match-rules 011 (F1 clamp) and 015 (complete Silence) merged at M1/M2 (70947a5). Open
Questions: the strip-site choice ("agree with match-rules") is resolved by the merged engine —
`RulesEngine._recompute_auras()` strips every `is_aura` enchantment and hand `cost_modifiers`, then
calls the resolver. DD-X16 (no aura-granted Stealth) is enforced by the validator. Asset References:
none. Definition of Done: 4 ACs, Logic type, test evidence path, guardrails stated.
QL-STORY-READY skipped — Lean mode.

## Completion Notes
**Completed**: 2026-11-04 (started 04:19 UTC, ended 04:34 UTC; readiness and reading from ~04:05)
**Criteria**: 4/4 passing (AC-26, AC-27, AC-28, AC-29), no deferred items
- AC-26 — `test_two_lords_and_a_flank_banner_make_the_vanilla_5_3` (5/3; lords 3/3 from each other only; row 27 4/4; aura sources per target in canonical order, one per source), `test_recomputing_again_never_applies_an_aura_twice`, `test_an_adjacent_aura_follows_the_board_and_the_boss_side_is_not_friendly` (selector re-evaluated after a death; the boss lord buffs only the boss side).
- AC-27 — `test_silencing_the_lord_kills_the_damaged_minion_it_buffed` (`silenced` → `auras_recomputed` → `minion_died`), `test_a_silenced_recipient_keeps_the_aura_net_no_change` (no `auras_recomputed`, no death), `test_two_damaged_lords_keep_each_other_alive_through_every_recompute`; from the match-rules 015 review: `test_a_damaged_minion_that_gains_an_aura_then_is_silenced_keeps_its_stats_and_damage` (damage, then the aura, then Silence: 3/2 kept, `damage_taken` 1, no `auras_recomputed`). The Silence health-debuff defect that review found (`rules_engine.gd` `silence` F6 step adds damage when a negative `health_delta` is removed) is left to the match-rules fix lane, as instructed; no test here pins it.
- AC-28 — `test_a_temporary_buff_expires_at_the_end_step_and_the_damaged_minion_dies` (`enchantment_removed` then `minion_died`), `test_a_negative_health_buff_on_a_damaged_3_3_kills_it`.
- AC-29 — `test_one_archivist_makes_a_3_cost_spell_cost_2` (a 3-cost minion stays 3), `test_two_archivists_stack_and_a_1_cost_spell_floors_at_0` (two `cost_modifiers`, one clamp), `test_an_archivist_discounts_only_its_owners_hand_and_stops_when_silenced`. Beyond the AC: `test_a_passive_hand_cost_reads_its_value_at_each_recompute` (C7 `passive_hand`, value expression read at recompute).
- Clone isolation: `test_a_clone_recomputes_its_own_auras_and_leaves_the_live_board_alone` (the sandbox silences the lord; the live aura, `silenced` flag and `EffectRuntime` are untouched). The story adds no runtime state: auras are re-derived from the board on every recompute.
- Watched fail: 11 of 13 failed before the code (the 14th, added after the review note, passes by construction). The 2 AC-28 tests pass by construction (story 006 shipped `buff` durations); each was mutated, one mutation per run, then restored: `expires` always null (temp-buff test failed), negative `health` clamped to 0 (negative-buff test failed). The recompute dying rule was mutated too (stripped health treated as dying): the three AC-27 tests failed. The recompute was mutated to skip Silenced recipients: the two recipient-Silence tests failed.
**Verification**: `godot --headless --path . --import` exit 0; full suite (`commands.test`) 1328/1328, exit 0, 85 SCRIPT ERROR lines (the existing baseline from other systems' negative tests; the new suite adds none); smoke exit 0, no SCRIPT ERROR; `tools/lint/gates.sh` PASS; parse check of the 5 changed scripts ok.
**Run result**: N/A — nothing renders: the real resolver is not yet composed into a playable match (no `MatchDriver`); auras are logic only.
**Deviations** (all ADVISORY):
- **Engine fix outside card-effects (`rules_engine.gd` `_drain`).** The C10 loop broke when the death check *before* the recompute found nobody and Q was empty, so a minion whose aura the recompute removed stayed on the board at health 0 (AC-27 failed: no `minion_died`). The loop now runs one more death check when a board minion is at `health ≤ 0` or `pending_destroy` after the recompute (`_any_minion_dying`, read-only, additive). match-rules owns the loop; no match-rules test changed.
- **Recompute dying rule.** C3 says pools never yield a dying character, but during a recompute the engine has already stripped every aura, so a minion alive only through an aura reads `health ≤ 0`. Under `RUN_AURA_RECOMPUTE` a pool leaves out only `pending_destroy` (the death check has already run). Without it a damaged aura recipient died on the next step.
- **Strip site:** the engine's (`RulesEngine._recompute_auras` strips characters, weapons and hand `cost_modifiers`); the resolver only re-applies.
- **Weapons as aura sources** come after both boards (C7 names boards then treasures; C2 lets weapons host `aura`; C3 orders weapons after the boards). No fixture weapon has an aura yet.
- **`zone: hand`** defaults the effect's targets to `hand` when it names none; row 24 names `hand` itself.
**Test Evidence**: `tests/unit/card_effects/card_effects_auras_enchantments_test.gd`
**Reviewed by**: independent `/code-review` 2026-11-04 (by hand, `production/reviews/2026-11-04/code-review-s4-unreviewed.md`): **NOT ASSESSED** [otherwise APPROVED WITH SUGGESTIONS; the engine-specialist and qa-tester passes could not be spawned]. 0 blocking. Should-fix S2 (DD-X25) and T2: fixed in the L7 W1 fix buffer. S3 awaits the owner's design call. Nit N5: boxes ticked. Lane record before that review: not reviewed — `/code-review` NOT ASSESSED (agent-requiring gate, lean lane run)
