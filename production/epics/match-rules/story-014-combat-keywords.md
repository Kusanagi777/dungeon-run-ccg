# Story 014: Windfury, Stealth and Divine Shield in combat

> **Epic**: Match Rules
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-04

## Context

**GDD**: `design/gdd/match-rules.md` (C12 Keyword semantics — Windfury, Stealth, Divine Shield, Poisonous, Lifesteal rows; C8 Windfury paragraph and step 1; C9; Edge Cases "Combat" and "Keywords and status"; States — character status sub-states)
**Requirement**: `TR-match-rules-005` (keyword effects realised through `apply_damage` / `apply_heal` / `remove_keyword`), `TR-match-rules-006` (`modify_max_attacks` live derivation)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Effect Resolver / Validator Boundary (keyword *semantics* that are rules — not card text — live in the engine; the resolver never writes `keywords`)
**ADR Decision Summary**: The engine owns the primitives and the combat steps; keyword consequences that are match rules (a shield popping, Stealth lost at declaration, a second Windfury swing being a new command) are engine behaviour observable in the log, never DSL.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: HIGH by version; APIs used predate 4.3. No engine-specific verification.

Three keyword rules that are only visible in combat: Windfury is a derived `max_attacks` so the second attack is simply a new `attack` command that needs a new legal target; Stealth is lost at declaration and from then on the minion is targetable; Divine Shield eats the whole hit before Poisonous and Lifesteal can see any `dealt`. Together with story 013 these close the DD-M09 combat keyword set (Taunt, Charge and Rush were legality in story 012).

**Control Manifest Rules (this layer)**:
- Required: `RulesEngine` owns … the 24 primitives (ADR-0007); value folds — the engine clamps exactly once (ADR-0005)
- Forbidden: never write match state directly from `src/gameplay/effects/**` (gate G7) — `keywords` changes go through `add_keyword` / `remove_keyword` (ADR-0007); never add a hook point without a match-rules GDD change (ADR-0005)
- Guardrail: `submit()` ≤ 5 ms worst case (ADR-0007, ADR-0001)

---

## Acceptance Criteria

*From GDD `design/gdd/match-rules.md`, scoped to this story:*

- [ ] AC-18 **GIVEN** a Windfury 2/5 and two enemy 1/1s, **WHEN** it attacks the first (which dies; the attacker is at `damage_taken 1`) and then the second, **THEN** both attacks are accepted, the attacker ends at `damage_taken 2`, and a third `attack` returns `CANNOT_ATTACK` (`max_attacks = 2`, no "continue attacking the same target" state; the Taunt rule is re-evaluated for the second command); **GIVEN** a minion gains Windfury (via `add_keyword` or an enchantment) after attacking once this turn, **THEN** `attacks_remaining == 1` and it may attack again; losing Windfury after one attack leaves none.
- [ ] AC-22 **GIVEN** a Divine Shield minion, **WHEN** hit by a Poisonous Lifesteal attacker for 4, **THEN** `divine_shield_popped`, `dealt == 0`, the minion survives (no `pending_destroy`), no `healed` event, and the attacker still takes the defender's damage; **GIVEN** a Poisonous minion is killed by its defender in the simultaneous-damage step, **THEN** its poison still applies and both die together in the same death check.
- [ ] AC-26 **GIVEN** a Stealth minion, **WHEN** it attacks, **THEN** `stealth_lost` precedes `damage_dealt`, and it is targetable afterwards (an enemy `attack` naming it is accepted; a required-target enemy spell lists it in `legal_targets`); **GIVEN** a Stealth minion that is also Taunt, **THEN** it does not enforce its Taunt while stealthed (story 012) and does from the attack after it loses Stealth; random and area effects still hit a stealthed minion (`apply_damage` on it is not refused).

---

## Implementation Notes

*Derived from ADR-0007 Decision 1 and GDD C12 / C8 / C9:*

- Windfury: nothing to add in combat beyond stories 012–013 — `max_attacks` is derived live from `has_windfury` (keyword, hero enchantment or hero weapon) through the `modify_max_attacks` fold and clamp; verify `attacks_used` persists across the two commands and resets at the Start step. The second swing is a fresh `submit(attack)` and goes through `can_attack` again.
- Stealth: removed at C8 step 1 (`keywords.erase(Stealth)` on the attacker through the engine's own `remove_keyword`-equivalent path, emitting `stealth_lost` rather than `keyword_removed` — C15 names both; `stealth_lost` is the combat one). Stealth protects only against enemy *targeting* (`can_attack`, `legal_targets`); `apply_damage` never checks it. Silence also clears it (story 015).
- Divine Shield: entirely inside F2 (story 007) — `prevented = amount`, `dealt = 0`, no Poisonous mark, no Lifesteal heal, no `on_damage`; a 0-damage hit does not pop it. The defender's return damage in step 4 is unaffected by the attacker's shield state except through F2 on the attacker.
- Poisonous-vs-defender death: both `apply_damage` calls happen in step 4 before any death check (story 013), so `pending_destroy` is set on the defender even though the attacker is at ≤ 0 health; the death check removes both in the same step (DD-M11 order).
- Tests use the fixture card set (`tests/helpers/card_factory.gd`: one of each keyword) and read `damage_taken`, `keywords`, `attacks_used` straight from the state via `MatchFactory.find_entity`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 007: the F2 pipeline itself
- Story 012 / 013: legality and the resolution steps this story observes
- Story 015: Freeze, Silence (which also removes Divine Shield / Stealth / Taunt / Deathrattle)
- Card Effects epic: Spell Damage +N application, Discover, Battlecry / Deathrattle content, Aura emission

---

## Files

- `src/gameplay/match/rules_engine.gd` (`_declare_attack_step`: a Stealth attacker loses Stealth at declaration — keyword stripped from its definition set and enchantments, `stealth_lost {entity_id}`; `_do_attack` step-1 doc)
- `tests/unit/match_rules/match_rules_combat_keywords_test.gd` (new, 10 tests)

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/match_rules/match_rules_combat_keywords_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later). `qa.level: standard` — BLOCKING.

**Status**: [x] Created and passing (10 test functions)

---

## Dependencies

- Depends on: `production/epics/match-rules/story-013-attack-resolution.md`
- Unlocks: `production/epics/match-rules/story-017-clone-and-replay.md`

## Readiness
**2026-11-04 — READY** (`/story-readiness` read by hand, sprint 4 lane 1). Design: C12 rows, C8 step 1, C9 and the Edge Cases cited, criteria testable. Architecture: ADR-0007 Accepted; TR-match-rules-005 / 006 active; Manifest Version 2026-11-03 = current. Scope: M, Out of Scope stated, dependency story 013 Complete (e5e3cb7). No open markers; no asset references. DoD: 3 ACs, Type Logic, Test Evidence path, `submit()` ≤ 5 ms noted. QL-STORY-READY skipped — Lean mode.

## Completion Notes
**Completed**: 2026-11-04 (started 03:17:23 UTC, ended 03:20:20 UTC; closed after the mutant runs)
**Criteria**: 3/3 passing — AC-18 (`test_a_windfury_minion_attacks_twice_as_two_commands_and_not_a_third_time` — Taunt re-evaluated for the second command, `damage_taken 2`, third `CANNOT_ATTACK`; `test_attacks_used_resets_at_the_start_step`; `test_gaining_windfury_after_one_attack_grants_one_more` via `add_keyword` and via an enchantment; `test_losing_windfury_after_one_attack_leaves_no_attacks`), AC-22 (`test_divine_shield_eats_a_poisonous_lifesteal_hit_and_the_attacker_still_takes_damage`, `test_a_poisonous_attacker_killed_by_its_defender_still_poisons_it_and_both_die_together`), AC-26 (`test_a_stealth_minion_loses_stealth_when_it_attacks_before_any_damage`, `test_a_minion_that_lost_stealth_is_attackable_and_its_taunt_binds_again`, `test_a_stealth_taunt_that_has_not_attacked_does_not_bind_the_enemy`, `test_area_and_random_damage_still_hit_a_stealthed_minion`).
**Watched fail**: the two Stealth-loss tests failed against the story-013 engine. The other eight already passed (Windfury, Divine Shield and Poisonous were in place from stories 001 / 007 / 012 / 013), so each was watched failing against one mutant per run: Windfury ignored in `max_attacks` (3 tests), `_strip_keyword` leaving the definition keyword (losing Windfury, plus Divine Shield and both Stealth tests), Divine Shield disabled, Poisonous marking nothing, a Stealth Taunt counted as a taunter, `apply_damage` refusing a stealthed target.
**Keyword-read fixes surfaced by the tests**: none needed beyond Stealth loss; every keyword read already goes through `_has_keyword` (definition plus `keywords_added`).
**Deviations** (advisory):
- AC-26's "a required-target enemy spell lists it in `legal_targets`" is not asserted here: `legal_targets` is the resolver's (card-effects) filter, and the double answers from scripted lists. The engine's half — the `stealth` keyword is gone from the record the filter reads — is asserted; the listing belongs to a card-effects targeting test.
- The story says tests use the `card_factory.gd` keyword fixture set; they use `MatchFactory.summon` with keyword lists instead (same records, no database needed for combat).
**Test Evidence**: `tests/unit/match_rules/match_rules_combat_keywords_test.gd` (10 tests); full suite 1112 test cases, 0 failures, exit 0, 85 SCRIPT ERROR lines (unchanged intentional negatives); smoke exit 0, no SCRIPT ERROR; parse check exit 0.
**Run result**: N/A — headless rules code; no scene, node or screen renders an attack yet (Match UI is a later epic).
**Reviewed by**: self, no independent review (LP-CODE-REVIEW skipped — Lean mode; QL-TEST-COVERAGE skipped — Lean mode)
