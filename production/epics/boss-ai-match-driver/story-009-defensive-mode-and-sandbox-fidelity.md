# Story 009: DEFENSIVE mode (F6 threat estimate) and sandbox hook fidelity

> **Epic**: Boss AI + Match Driver
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S → M (2026-11-04, DD-X22: A31 added)
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-04 (DD-X22 amendment; implementation not started)

## Context

**GDD**: `design/gdd/boss-ai.md` (C2 defensive branch, F6, States "Modes", Interactions Match Rules provisional requirement, Edge Cases "If the boss passive changes the rules mid-match")
**Requirement**: `TR-boss-ai-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Boss AI Planner Threading (replay correctness depends on `clone()` fidelity — hooks, continuation, `rng_match`; A20 covers hooks)
**ADR Decision Summary**: The clone carries the same hooks and `rng_match` position as the live engine, so the sandbox scores effects as the live match resolves them; a fidelity bug surfaces as `ai_fault {replay_divergence}`. Mode is re-evaluated at every `Planning` entry; DEFENSIVE multiplies the profile weights by `rules.defensive_multipliers`.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH / NOT SOURCEABLE
**Engine Notes**: `clone()` carrying `HookRegistry.copy()` with evaluators unset and the clone's resolver rebinding is match-rules / ADR-0005 code (NOT SOURCEABLE deep copy). This story only asserts the observable outcome through scoring.

**Control Manifest Rules (this layer)**:
- Required: `RulesEngine.clone()` deep-copies `MatchState` including `state.hooks.copy()` and binds a fresh `EffectResolver` with no installers; `copy()` is a by-value copy with evaluators unset and the clone's resolver rebinds.
- Forbidden: Never share the live resolver with a clone. Never special-case "player only" in engine code.
- Guardrail: `copy()` ≤ 12 small `duplicate(true)` calls per Boss AI clone.

---

## Acceptance Criteria

*From GDD `design/gdd/boss-ai.md` A15, A20, A31 (A31 added 2026-11-04, DD-X22), scoped to this story:*

- [ ] **A15** GIVEN F6's example board (player 4/4 + 3/2 Windfury, 6 mana next turn → incoming 16; boss at 18, band 3 `defensive = true`, `defensive_margin` 3), WHEN the turn plans, THEN `mode = DEFENSIVE` is logged in `ai_decision` and `mode_trace`, and a Taunt in hand is played before a non-Taunt of equal stats (Taunt +0.5 BV in F2, `w_face ×0.25, w_self ×2, w_heal ×2, w_threat ×1.5`); GIVEN the same board with band 2 (`defensive = false`), THEN `mode = NORMAL`.
- [ ] **A20** GIVEN a boss passive that doubles the boss's healing (hook installed via `boss.hook_installers`), WHEN a heal is scored in the sandbox, THEN `f_heal` reflects the doubled amount (the clone carries hooks); and GIVEN both lethal and the defensive condition hold, THEN lethal wins (checked first, C2).
- [ ] **A31 (2026-11-04, DD-X22 — non-lethal face attacks)** GIVEN boss-ai F1's vulnerability example (default profile; boss 12 health, `defensive_margin` 3, no boss Taunt, mana 0; player 5/5 + 4/2 at 20 health; boss 4/4 able to attack), WHEN the candidates are scored, THEN the face attack has `f_face = 0` and `f_self = −0.75` (`reach 9 / 12`), and the chosen action is not the face attack. GIVEN the 4/2 replaced by a 4/6, THEN the face attack has `f_face = 0.2` and `f_self = 0` (no trade by the 4/4 makes the boss safe) and is chosen. GIVEN a boss 2/4 Taunt added (`reach` 5, safe), THEN `f_face = 0.2`. GIVEN the player at 4 health, THEN the face attack is lethal and never zeroed. Applies in every band (no `rules.defensive` gate).

---

## Implementation Notes

*Derived from ADR-0006 Consequences and GDD F6 / States:*

- Files: `src/ai/threat_estimate.gd` (`class_name ThreatEstimate extends RefCounted`, `static func incoming(sandbox, rules) -> int`): `Σ attack × max_attacks over player minions (frozen-that-thaw and summoning-sick count) + hero weapon attack + burn_per_mana × mana_max_player_next_turn`; defensive iff `incoming ≥ boss_health + boss_armor − defensive_margin`. Wire into `BossAI.plan_turn` after the lethal branch.
- Mode application: build the effective weight vector once per `Planning` entry (`weights × defensive_multipliers` when DEFENSIVE) and pass it to Story 004's scorer; the scorer applies the Taunt +0.5 BV bonus when told the mode. A successful clear drops back to NORMAL within the same turn.
- If the player has lethal next turn and nothing changes the estimate, the AI still plays the best DEFENSIVE action (racing allowed — `f_face` reduced, not zeroed); it never resigns or stalls.
- **A31 (2026-11-04, DD-X22).** `ThreatEstimate.reach(state, rules)` is the board-only part of `incoming` (no `burn_per_mana` term) minus the health of the boss's Taunts. `unsafe(state)` is `reach ≥ boss_health + boss_armor − defensive_margin`. In Story 004's scorer, after the one-ply sims of one `score_all`, a non-lethal face attack by attacker A gets `f_face = 0` and `f_self = −min(1, reach(after) / (boss_health + boss_armor))` when its after-state is unsafe and some simulated attack by A on a player minion has a safe after-state. It reads only sandbox states already simulated, so it costs no extra sim. The change lands in `src/ai/scorer.gd` (story 004's file, Complete). `ai_decision.top3` shows the adjusted features.
- A20's fixture needs a real boss passive hook through `MatchConfig.boss.hook_installers` (match-rules / card-effects code). If those epics have not landed, the test is written against the factories in `tests/helpers/` and marked pending with the blocking story path — do not stub the hook inside `src/ai/**`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 004: feature arithmetic and base weights.
- Story 007: the lethal branch that precedes the defensive check.
- `match-rules` / `card-effects` epics: `clone()` carrying hooks.

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/ai/threat_estimate.gd`
- `src/ai/boss_ai.gd` (mode selection)
- `src/ai/scorer.gd` (A31 vulnerability exception — 2026-11-04, DD-X22)
- `tests/unit/boss_ai/boss_ai_face_attack_vulnerability_test.gd`, `tests/fixtures/boss_ai/f1_vulnerability_board.json` (A31)
- `tests/unit/boss_ai/boss_ai_defensive_mode_test.gd`
- `tests/fixtures/boss_ai/f6_defensive_board.json`, `tests/fixtures/boss_ai/heal_doubling_passive.json`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/boss_ai/boss_ai_defensive_mode_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/boss-ai-match-driver/story-008-plan-turn-loop-and-turn-plan.md`
- Unlocks: `production/epics/boss-ai-match-driver/story-016-sim-harness.md`
