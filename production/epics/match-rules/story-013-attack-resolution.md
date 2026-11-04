# Story 013: Attack resolution and simultaneous damage

> **Epic**: Match Rules
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-04

## Context

**GDD**: `design/gdd/match-rules.md` (C8 Attacking — resolution steps 1–7 as decided 2026-11-03: a defending hero never deals damage back, DD-X11 / N-05; Interactions `on_attack` trigger point; Edge Cases "Combat"; DD-M11 simultaneous damage)
**Requirement**: `TR-match-rules-005` (`apply_damage`, `modify_durability` paths), `TR-match-rules-006` (`on_attack` / `on_damage` triggers, C10 loop after the swing)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Effect Resolver / Validator Boundary (the engine owns *when* `on_attack` fires and the step boundaries; one step = one C10 loop pass); also ADR-0003 (two `damage_dealt` events, consecutive `seq`)
**ADR Decision Summary**: Combat is engine-owned steps — declaration, the `on_attack` trigger pass, the re-check, one simultaneous-damage step, then the C10 loop — and every number it produces is in the log. The resolver only answers `on_attack` / `on_damage` candidates.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: HIGH by version; APIs used predate 4.3. No engine-specific verification; the step-4 attack value is read once into a local (snapshot) before either `apply_damage` call.

**Gate entry condition 3 (N-05)** is satisfied: `design/design-decisions.md` DD-X11 (owner, 2026-11-03) rules that a defending hero never deals damage back, weapon or not; C8 step 4 is reworded accordingly and F3 / AC-19 are unaffected (AC-19's return damage comes from the defending *minion*). `/story-readiness` should find the row and lift the block the epic carried.

Legality is evaluated once, at declaration. After `on_attack` triggers the engine re-checks only that both characters are still in play — a Taunt that appeared or a Taunt that was lost does not redirect — and then both damages land in one step with no death check between them, so a Poisonous minion killed by its defender still poisons it.

**Control Manifest Rules (this layer)**:
- Required: `RulesEngine` owns … the C10 loop … and fires trigger points with `ctx.candidates` already in engine order (ADR-0007); one effect pass = one C10 step (ADR-0007)
- Forbidden: never call the death check or `recompute_auras()` between ops (ADR-0007) — step 4's two damages are one step; never let the resolver own the trigger queue (ADR-0007 Alt 1)
- Guardrail: `submit()` ≤ 5 ms worst case (50-step Deathrattle chain) (ADR-0007, ADR-0001)

---

## Acceptance Criteria

*From GDD `design/gdd/match-rules.md`, scoped to this story:*

- [ ] AC-16 **GIVEN** a 3/4 attacker and a 2/5 defender, **WHEN** `attack` resolves, **THEN** defender `damage_taken == 3`, attacker `damage_taken == 2`, the two `damage_dealt` events have consecutive `seq` with no `minion_died` between them (`EventLogAssertions.assert_consecutive`), and `attacks_used == 1`; the full event order is `attack_declared`, [`on_attack` trigger events], `damage_dealt(A→D)`, `damage_dealt(D→A)`, [loop events], `attack_resolved`.
- [ ] AC-19 **GIVEN** a hero with a 2/2 weapon, **WHEN** the hero attacks an enemy 1/3 minion, **THEN** the minion has `damage_taken 2`, the hero took 1 (the defending **minion** strikes back), weapon durability is 1 (`weapon_durability_changed` in the same step), and a second `attack` the same turn returns `CANNOT_ATTACK`; **WHEN** the hero attacks again on its next own turn, **THEN** the minion dies and the weapon is destroyed in the same death check (`weapon_destroyed` after that attack's two `damage_dealt` events).
- [ ] AC-21 **GIVEN** an attacker whose `on_attack` trigger destroys the defender, **WHEN** the attack resolves, **THEN** `attack_cancelled` is emitted, no `damage_dealt` follows, `attacks_used == 1` (the swing was committed), and `attack_resolved` still closes the command; **GIVEN** a Taunt minion is summoned during `on_attack`, **THEN** the declared attack proceeds against its original target.
- [ ] C8 step 4 / DD-X11 **GIVEN** a minion attacking the enemy hero while that hero holds a 3/2 weapon and has attack 3, **WHEN** the attack resolves, **THEN** exactly one `damage_dealt` (minion → hero) is emitted, the attacking minion's `damage_taken` is unchanged and the hero's weapon durability is unchanged — a defending hero never deals damage back, weapon or not; **AND GIVEN** a defending minion whose attack drops to 0 during combat, **THEN** it still deals the attack value snapshotted at the damage step.

---

## Implementation Notes

*Derived from ADR-0007 Decision 1 / Implementation Guidelines and GDD C8 steps 1–7:*

- `attack{attacker_id, target_id}` accepted (story 012's `can_attack`) → inside `run_action`: (1) emit `attack_declared{attacker, defender}`; if A has Stealth, remove it now and emit `stealth_lost`. (2) `resolver.resolve(&"on_attack", {attacker, defender, candidates})` — each response is a step with the full loop. (3) **Re-check**: if A or D is no longer in play (died, bounced, transformed) → emit `attack_cancelled`, `A.attacks_used += 1`, skip to step 7. Legality is **not** re-evaluated (Taunt gained/lost in step 2 does not matter). (4) **Simultaneous damage, one step**: `a_atk = attack(A)`, `d_atk = attack(D)` read once; `apply_damage(D, a_atk, source = A)`; then `if d_atk > 0 and D is minion: apply_damage(A, d_atk, source = D)` — **never when D is a hero** (DD-X11); both `damage_dealt` in that order, no death check between; Divine Shield / Poisonous / Lifesteal are inside F2 (story 007); if A is a hero with a weapon: `modify_durability(weapon, −1)` in the same step. (5) `A.attacks_used += 1`. (6) The C10 loop (`on_damage` triggers queued in step 4 resolve, deaths, deathrattles, auras; a weapon at durability ≤ 0 breaks in the death check). (7) emit `attack_resolved`; `win_loss_check()`.
- `source` for a hero's weapon attack carries the weapon's keywords (Lifesteal / Poisonous on a weapon apply to hero attacks with it) and the hero as the damage dealer for stats.
- A defending minion's return damage uses `attack(D)` snapshotted at step 4, so a debuff applied by the first `apply_damage`'s triggers (queued, not nested) cannot change it — the loop runs after the step.
- The frozen-hero case (`ATTACKER_FROZEN`, no durability loss) is already rejected at legality (story 012); nothing here runs for it.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 012: `can_attack` and the rejection codes
- Story 014: the second Windfury attack as a new command, Stealth loss observable by targeting, Divine Shield vs Poisonous/Lifesteal in combat (AC-18, AC-22, AC-26)
- Story 015: Freeze / thaw interactions

---

## Files

- `src/gameplay/match/rules_engine.gd` (`_do_attack` C8 steps 1–7 replacing story 012's acceptance stub: `_declare_attack_step`, the `on_attack` trigger step under `attack_declared`, the re-check with `_cancel_attack_step`, `_attack_damage_step` — snapshot, DD-X11, weapon as source, durability, `attacks_used`)
- `tests/helpers/test_effect_resolver.gd` (additive: `attacker_is` guard, `add_on_attack_destroy`, `add_on_attack_summon` and their passes)
- `tests/unit/match_rules/match_rules_attack_resolution_test.gd` (new, 8 tests; 9 after the staged-model follow-up below)

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/match_rules/match_rules_attack_resolution_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later). `qa.level: standard` — BLOCKING.

**Status**: [x] Created and passing (8 test functions)

---

## Dependencies

- Depends on: `production/epics/match-rules/story-012-attack-legality.md`
- Unlocks: `production/epics/match-rules/story-014-combat-keywords.md`, `production/epics/match-rules/story-015-freeze-thaw-silence.md`

## Readiness
**2026-11-04 — READY** (`/story-readiness` read by hand, sprint 4 lane 1). **Gate entry condition 3 (N-05) lifted:** `design/design-decisions.md` DD-X11 (owner, 2026-11-03) carries the decision (a defending hero never deals damage back) and C8 step 4 is worded to match. Design: C8 steps 1–7 / Edge Cases "Combat" cited, criteria testable. Architecture: ADR-0007, 0003 Accepted; TR-match-rules-005 / 006 active; Manifest Version 2026-11-03 = current. Scope: M, Out of Scope stated, dependency story 012 Complete (2f15237). No open markers; no asset references. DoD: 4 ACs, Type Logic, Test Evidence path, `submit()` ≤ 5 ms noted. QL-STORY-READY skipped — Lean mode.

## Completion Notes
**Completed**: 2026-11-04 (started 03:02:16 UTC, ended 03:06:26 UTC)
**Criteria**: 4/4 passing — AC-16 (`test_simultaneous_damage_lands_both_hits_in_one_step_in_the_c8_order`: 3 / 2 `damage_taken`, consecutive `damage_dealt` A→D then D→A, `attacks_used 1`, order `attack_declared`, `trigger_resolved`, on_attack event, the hits, `attack_resolved` last), AC-19 (`test_a_hero_weapon_attack_takes_the_minions_strike_back_and_spends_durability`, `test_a_hero_weapon_attack_on_the_next_turn_kills_and_breaks_in_one_death_check` — `damage_dealt`, `damage_dealt`, `weapon_durability_changed`, `minion_died`, `weapon_destroyed` consecutive), AC-21 (`test_an_on_attack_trigger_that_destroys_the_defender_cancels_the_attack`, `test_an_on_attack_trigger_that_removes_the_attacker_cancels_the_attack`, `test_a_taunt_summoned_during_on_attack_does_not_redirect_the_declared_attack`), C8 step 4 / DD-X11 (`test_a_defending_hero_never_deals_damage_back_even_with_a_weapon`, `test_the_defender_strikes_back_with_its_attack_snapshotted_at_the_damage_step`). Watched fail: 8 of 8 against story 012's acceptance-only step. Mutants: re-reading `attack(D)` for the strike-back fails the snapshot test; dropping the "D is a minion" condition fails the DD-X11 test.
**Decisions recorded**:
- `on_attack` ctx: `{side: A.controller, candidates, attacker, defender, source: attacker, subject: defender}` (card-effects C2: `trigger_source` = attacker, `trigger_subject` = defender); the step runs under `attack_declared`'s `seq`. The damage step and `attack_cancelled` / `attack_resolved` are direct consequences of the command (`cause_seq` 0).
- A hero with a weapon hits with the **weapon id** as `source`: F2 reads the weapon's Lifesteal / Poisonous, and `damage_dealt_by_card` is credited to the weapon's `def_id`. The story's "the hero as the damage dealer for stats" has no separate field to land in (`apply_damage` takes one source); flagged for review.
- `attack_cancelled` with the attacker gone (destroyed by its own `on_attack`) increments nothing (there is no record left to count on).
- The snapshot test drops the defender's attack from a *collecting* `on_damage` script on the resolver double, the only hook inside the step between the two hits; a real resolver only queues there, so in production the snapshot protects against the same mutation reached through any future in-step path.
**Deviations** (advisory): Stealth removal at declaration (C8 step 1, listed in this story's notes) is left to story 014, whose Files and AC-26 own it.
**Test Evidence**: `tests/unit/match_rules/match_rules_attack_resolution_test.gd` (8 tests); full suite 1102 test cases, 0 failures, exit 0, 85 SCRIPT ERROR lines (unchanged intentional negatives); smoke exit 0, no SCRIPT ERROR; parse check exit 0.
**Run result**: N/A — headless rules code; no scene, node or screen renders an attack yet (Match UI is a later epic).
**Reviewed by**: self, no independent review (LP-CODE-REVIEW skipped — Lean mode; QL-TEST-COVERAGE skipped — Lean mode); `/code-review` reserved for this story at M1 (sprint 4 plan)

### Staged-model follow-up (2026-11-04, ended 03:24:16 UTC; lane 1 after merging lane 2's story 016)
At the orchestrator's request the attack handler moved onto story 016's plain-data stages: `_do_attack` builds four stages (`attack_declare`, `attack_point`, `attack_damage` — re-check, then cancel or the damage step — and `attack_resolved`) over the frame `{side, attacker, defender, cause}`, run by `_attack_stage` from one new arm in `_run_stage`. A Discover raised by an `on_attack` trigger now parks steps 3–7 and `choose` runs them once. Test added: `test_a_discover_raised_by_an_on_attack_trigger_pauses_the_rest_of_the_attack_until_choose`, watched failing against the direct-step handler (it emitted `attack_resolved` during the pause and ran nothing after `choose`). Full suite 1198 test cases, 0 failures, exit 0, 85 SCRIPT ERROR lines (unchanged); smoke exit 0, no SCRIPT ERROR.
