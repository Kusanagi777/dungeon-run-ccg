# Story 012: Attack legality predicate

> **Epic**: Match Rules
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-04

## Context

**GDD**: `design/gdd/match-rules.md` (C8 Attacking — legality bullets; F3 Attack legality predicate; C12 Taunt, Charge, Rush, Stealth, Windfury rows; C2 `attack` row; Edge Cases "Combat" legality rows; DD-M10)
**Requirement**: `TR-match-rules-002` (closed rejection codes in F3 order; `legal_commands()` attacker × defender expansion), `TR-match-rules-006` (`modify_max_attacks` fold-then-clamp)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Effect Resolver / Validator Boundary (the engine owns the phase machine and command validation); also ADR-0005 (`atks = clampi(hooks.fold(&"modify_max_attacks", character.controller, 2 if windfury else 1, {who}), 0, cfg.MAX_ATTACKS_CAP)`), ADR-0001 (illegal moves are data)
**ADR Decision Summary**: Command legality is the engine's; `max_attacks` is a derived value whose hook fold the engine clamps once to `[0, MAX_ATTACKS_CAP]`; rejections are data from the closed set, in a deterministic order.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: HIGH by version; APIs used predate 4.3. `can_attack` runs for every attacker × defender pair in `legal_commands()` (≤ 2 ms): compute `taunters(side)` once per call, not per pair.

F3 is a conjunction evaluated left to right and the first false term names the rejection code — `CANNOT_ATTACK`, `ATTACKER_FROZEN`, `SUMMONING_SICK` / `RUSH_CANNOT_HIT_HERO`, `ILLEGAL_TARGET`, `TARGET_STEALTHED`, `MUST_ATTACK_TAUNT`. A Stealth Taunt is excluded from `taunters` and still cannot be hit; a hero with no weapon and no attack buff has attack 0 and cannot attack.

**Control Manifest Rules (this layer)**:
- Required: value folds — the engine clamps exactly once after the whole fold with bounds from `config("match_rules")` (`MAX_ATTACKS_CAP`) (ADR-0005); hook catalogue value points include `modify_max_attacks` (ADR-0005)
- Forbidden: never clamp inside the fold; never special-case "player only" in engine code (ADR-0005)
- Guardrail: `legal_commands()` ≤ 2 ms (ADR-0007, ADR-0001)

---

## Acceptance Criteria

*From GDD `design/gdd/match-rules.md`, scoped to this story:*

- [ ] AC-12 **GIVEN** a minion played this turn without Charge or Rush, **WHEN** it attacks, **THEN** `SUMMONING_SICK`; **GIVEN** it has Rush, **WHEN** it attacks the hero, **THEN** `RUSH_CANNOT_HIT_HERO`, and **WHEN** it attacks a minion, **THEN** accepted; **GIVEN** Charge, **THEN** any target is accepted (Charge supersedes Rush); next turn the summoning sickness is gone and it attacks anything.
- [ ] AC-17 **GIVEN** an enemy Taunt minion and an enemy non-Taunt minion, **WHEN** attacking the non-Taunt, **THEN** `MUST_ATTACK_TAUNT`; **GIVEN** the Taunt minion also has Stealth, **THEN** attacking the non-Taunt is accepted and attacking the Stealth Taunt returns `TARGET_STEALTHED` (`taunters(side) = {m : m.taunt ∧ ¬m.stealth}`); attacking a friendly or not-in-play target → `ILLEGAL_TARGET`; an attacker with `attack == 0` (a hero with no weapon, or a debuffed minion) → `CANNOT_ATTACK`; a `modify_max_attacks` hook `set 2` lets a non-Windfury minion attack twice and the clamp holds the fold to `[0, MAX_ATTACKS_CAP]` (a `set 9` yields 4 attacks, not 9).
- [ ] AC-20 **GIVEN** the hero is Frozen and holds a weapon, **WHEN** `attack` is sent, **THEN** `ATTACKER_FROZEN` and durability is unchanged (the hero power is still usable — Freeze affects attacks only); **AND** `legal_commands()` lists exactly the attacker × defender pairs for which `can_attack` is true for the active side and none for the inactive side (`NOT_YOUR_TURN` when the boss attacks in player Main).

---

## Implementation Notes

*Derived from ADR-0005 Key Interfaces, ADR-0001 Decision 3 and GDD F3 / C8:*

- `can_attack(A, D) -> {ok, code}` evaluated left to right, first false term wins: `phase == Main(A.controller)` [`NOT_YOUR_TURN` / `WRONG_PHASE` — the generic guard in `submit` already covers this] ∧ `attack(A) > 0 ∧ attacks_remaining(A) > 0` [`CANNOT_ATTACK`] ∧ `¬A.frozen` [`ATTACKER_FROZEN`] ∧ `(A is hero ∨ ¬A.summoning_sick ∨ charge(A) ∨ (rush(A) ∧ D is minion))` [`SUMMONING_SICK` when neither keyword; `RUSH_CANNOT_HIT_HERO` when Rush and D is a hero] ∧ `D.controller ≠ A.controller ∧ D in play` [`ILLEGAL_TARGET`] ∧ `¬(D is minion ∧ stealth(D))` [`TARGET_STEALTHED`] ∧ `(taunters(D.controller) = ∅ ∨ D ∈ taunters)` [`MUST_ATTACK_TAUNT`].
- `attacks_remaining(A) = max_attacks(A) − A.attacks_used`; `max_attacks(A) = clampi(hooks.fold(&"modify_max_attacks", A.controller, 2 if has_windfury(A) else 1, {who: A}), 0, MAX_ATTACKS_CAP)` — the one clamp, in the engine; `has_windfury` = keyword on A, a hero enchantment, **or** the hero's weapon keyword (C1). Derived live: gaining Windfury mid-turn after one attack grants one more; losing it leaves none.
- Hero attack = `weapon.attack + hero attack enchantments` (C1 `attack_of`); a hero with neither has attack 0 → `CANNOT_ATTACK`.
- `attack{attacker_id, target_id}` handler: after the generic guards, run `can_attack`; on `ok` hand over to the resolution of story 013 (land a stub that records acceptance until 013; or implement both in one `/dev-story` session).
- `legal_commands()` adds, for every character of the active side with `attacks_remaining > 0`, every enemy character for which `can_attack` is true. Compute `taunters` once per call.
- Keyword reads honour `keywords_added` from enchantments and `remove_keyword` (takes effect at the next legality evaluation).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 013: resolution of an accepted attack (declaration, `on_attack`, re-check, simultaneous damage, durability)
- Story 014: Windfury's second attack after the first target dies; Stealth loss at declaration; shields
- Story 015: how a character becomes Frozen and thaws

---

## Files

- `src/gameplay/match/rules_engine.gd` (`can_attack` F3 + `_attack_rejection` / `_taunters`, `max_attacks` `modify_max_attacks` fold then one clamp, `attack` validation `_validate_attack`, `_append_attack_commands` in `legal_commands()`, an acceptance-only `_do_attack` step for story 013 to replace; the six F3 `R_*` codes)
- `src/gameplay/match/match_records.gd` (`MatchRecords.attack` command builder; `KEYWORD_TAUNT` / `STEALTH` / `CHARGE` / `RUSH`)
- `tests/unit/match_rules/match_rules_attack_legality_test.gd` (new, 16 tests)

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/match_rules/match_rules_attack_legality_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later). `qa.level: standard` — BLOCKING.

**Status**: [x] Created and passing (16 test functions)

---

## Dependencies

- Depends on: `production/epics/match-rules/story-010-play-card-and-hero-power.md`
- Unlocks: `production/epics/match-rules/story-013-attack-resolution.md`

## Readiness
**2026-11-04 — READY** (`/story-readiness` read by hand, sprint 4 lane 1). Design: C8 / F3 / C12 rows cited, criteria self-contained and testable. Architecture: ADR-0007, 0005, 0001 Accepted; TR-match-rules-002 / 006 active; Manifest Version 2026-11-03 = current. Scope: estimate M, Out of Scope stated, dependency story 010 Complete. No open markers; no asset references. DoD: 3 ACs (balanced minimum 2), Type Logic, Test Evidence path given, perf budget (`legal_commands()` ≤ 2 ms) noted. QL-STORY-READY skipped — Lean mode.

## Completion Notes
**Completed**: 2026-11-04 (started 02:45:59 UTC, ended 02:53:11 UTC)
**Criteria**: 3/3 passing — AC-12 (`test_minion_played_this_turn_without_charge_or_rush_is_summoning_sick`, `test_rush_minion_cannot_hit_the_hero_but_may_hit_a_minion`, `test_charge_minion_may_hit_any_target_and_supersedes_rush`, `test_summoning_sickness_is_gone_on_the_next_own_turn`), AC-17 (`test_a_taunt_minion_must_be_attacked_before_anything_else`, `test_a_stealth_taunt_is_not_a_taunter_and_cannot_be_attacked`, `test_a_friendly_or_not_in_play_target_is_an_illegal_target`, `test_an_attacker_with_attack_zero_or_no_attacks_left_cannot_attack`, `test_a_max_attacks_hook_set_two_lets_a_non_windfury_minion_attack_twice`, `test_the_max_attacks_fold_is_clamped_once_to_zero_and_the_cap` — includes a `delta −2, +2` chain that is 1 only without a clamp between entries), AC-20 (`test_a_frozen_hero_with_a_weapon_is_attacker_frozen_and_keeps_its_durability`, `test_legal_commands_lists_exactly_the_pairs_can_attack_accepts_for_the_active_side`, `test_legal_commands_under_a_taunt_lists_only_the_taunt_as_defender`), plus `test_attack_rejections_follow_the_f3_term_order`, `test_keywords_from_enchantments_and_remove_keyword_are_read_at_the_next_evaluation`, `test_windfury_from_a_keyword_an_enchantment_or_the_hero_weapon_gives_two_attacks`. Watched fail: 15 of 16 against a `can_attack` stub that rejected everything (the Windfury `max_attacks` test passed, because `has_windfury` was already in place from story 001, so it guards existing behaviour).
**Decisions recorded**:
- `can_attack(attacker_id, target_id) -> {ok, code}` is public (Boss AI and the UI can ask about one pair); `legal_commands()` calls the record-level `_attack_rejection` with `taunters` computed once per call.
- `modify_max_attacks` fold ctx is `{who: <entity id>}`, one reused Dictionary (ADR-0005 shows `{who: character}`; ids match the `modify_damage` ctx and card-effects C2 `who` scopes).
- Attack expansion order in `legal_commands()`: plays, then attacks (attacker hero → board left to right × defender hero → board), then the hero power, then `end_turn` (C2 row order).
**Deviations** (advisory):
- F3 has no term for an `attacker_id` that names no character in play; the engine answers `CANNOT_ATTACK`. An enemy character named as attacker fails F3's first term (`NOT_YOUR_TURN`).
- Rush with a target that is neither a minion nor a hero (unknown id) is `SUMMONING_SICK` (the literal false term; `RUSH_CANNOT_HIT_HERO` only when the target is a hero).
- `match_records.gd` was changed although the story's Files list named only `rules_engine.gd`: the `attack` command builder and the four combat keyword constants (story 010 set the precedent for builders there).
- Until story 013, an accepted attack is one step: `attack_declared`, `attacks_used += 1`, `attack_resolved` (the story's allowed stub).
- The `_validate` comment `TODO(stories 012, 016)` was left untouched on purpose, to keep lane 2's MR-016 merge small; it is stale for 012.
**Test Evidence**: `tests/unit/match_rules/match_rules_attack_legality_test.gd` (16 tests); full suite 1094 test cases, 0 failures, exit 0, 85 SCRIPT ERROR lines (unchanged intentional negatives); smoke exit 0, no SCRIPT ERROR; parse check exit 0.
**Run result**: N/A — headless rules code; no scene, node or screen renders an attack yet (Match UI is a later epic).
**Reviewed by**: independent `/code-review` 2026-11-04 (by hand, `code-review-s4-mr012-014`): **APPROVED WITH SUGGESTIONS** (overall NOT ASSESSED — specialist and qa-tester not spawnable). Fixes (sprint 4, lane 1 review-fix slot): S1 a weapon's enchantment-granted Windfury counts — `8c6e7b1` (`test_windfury_granted_to_the_hero_weapon_by_an_enchantment_gives_two_attacks`); N5 stale TODO removed and N1 the two deviations above marked in `_attack_rejection` — `dc64b21` (comments; their GDD F3 line is for the GDD owner). Open nits: N2 (`_max_attacks_ctx` not re-entrant), N4 (`_attack_rejection` complexity). QL-TEST-COVERAGE skipped — Lean mode
