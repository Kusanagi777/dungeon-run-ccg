# Story 013: Attack resolution and simultaneous damage

> **Epic**: Match Rules
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

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

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/gameplay/match/rules_engine.gd` (`attack` resolution steps 1–7)
- `tests/helpers/test_effect_resolver.gd` (scripted `on_attack` destroy / summon-Taunt fixtures)
- `tests/unit/match_rules/match_rules_attack_resolution_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/match_rules/match_rules_attack_resolution_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later). `qa.level: standard` — BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/match-rules/story-012-attack-legality.md`
- Unlocks: `production/epics/match-rules/story-014-combat-keywords.md`, `production/epics/match-rules/story-015-freeze-thaw-silence.md`
