# Story 012: Attack legality predicate

> **Epic**: Match Rules
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

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

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/gameplay/match/rules_engine.gd` (`can_attack`, `max_attacks` fold + clamp, `attack` handler validation, `legal_commands` attack expansion)
- `tests/unit/match_rules/match_rules_attack_legality_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/match_rules/match_rules_attack_legality_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later). `qa.level: standard` — BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/match-rules/story-010-play-card-and-hero-power.md`
- Unlocks: `production/epics/match-rules/story-013-attack-resolution.md`
