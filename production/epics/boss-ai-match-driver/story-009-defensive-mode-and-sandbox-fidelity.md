# Story 009: DEFENSIVE mode (F6 threat estimate) and sandbox hook fidelity

> **Epic**: Boss AI + Match Driver
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S → M (2026-11-04, DD-X22: A31 added)
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-05
> **Readiness**: READY (2026-11-05, by hand: story 008 merged at M1, story 004 Complete; ADR-0006 Accepted; DD-X22 and GDD F1 agree with the story; the QA plan's evidence gap closed by adding the A31 file; A20 uses the story's own allowance, see below)

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

- `src/ai/threat_estimate.gd` (new)
- `src/ai/boss_ai.gd` (mode selection, `_scoring_mode`, `_scoring_profile`)
- `src/ai/scorer.gd` (A31 vulnerability exception — 2026-11-04, DD-X22)
- `src/ai/lethal_search.gd` (`is_taunter` made public for [ThreatEstimate])
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
- Logic: `tests/unit/boss_ai/boss_ai_defensive_mode_test.gd` and `tests/unit/boss_ai/boss_ai_face_attack_vulnerability_test.gd` (A31; added 2026-11-05, wave 1 readiness) — must exist and pass (`/story-done` checks that they EXIST; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] Created: `boss_ai_defensive_mode_test.gd` 17 tests, `boss_ai_face_attack_vulnerability_test.gd` 15 tests, passing

---

## Dependencies

- Depends on: `production/epics/boss-ai-match-driver/story-008-plan-turn-loop-and-turn-plan.md`
- Unlocks: `production/epics/boss-ai-match-driver/story-016-sim-harness.md`

---

## Completion Notes
**Completed**: 2026-11-05 (start 01:10 UTC, end 01:23 UTC; sprint 5 lane 2 wave 2, branch `s5/l2-w2`)
**Criteria**: 3/3 passing, A20 on the production resolver since review fix D2 (below). A15 `test_a15_*`, `test_f6_*`, `test_the_choice_follows_the_defensive_multipliers`, `test_a_successful_clear_drops_back_to_normal_within_the_turn`; A20 `test_a20_*`; A31 `test_a31_*` with the GDD's pinned scores (−0.75, −0.73, 0, 0.3), and the edges `test_only_the_same_attackers_trade_counts`, `test_a_frozen_or_sleeping_player_minion_counts_in_reach`, `test_the_exception_costs_no_extra_simulation`.
**Tests seen failing**: both suites failed first against missing code (`ThreatEstimate` undeclared). With `ThreatEstimate` in and the `scorer.gd` exception not yet written, the A31 tests failed with the face attack at its plain 0.3 (`f_face` 0.2), as the QA plan asks, and the mode tests failed on `NORMAL`. The A20 tests and the rest passed there, so 25 deliberate mutants were run, all killed: among them `clone_loses_hooks` (a temporary `HookRegistry.copy` edit, restored), `defensive_before_lethal`, `no_band_gate`, `mode_never_drops`, `no_taunt_bonus`, `burn_truncated`, `reach_has_burn`, `any_attackers_trade`, `lethal_zeroed`, `score_not_recomputed`.
**Verification**: import exit 0; `gates.sh`, `no_global_rng.sh`, `parse-check.sh` exit 0; `commands.test` Overall Summary 1808 test cases, 0 errors, 0 failures, 0 orphans, exit 0; `commands.smoke` exit 0, no `SCRIPT ERROR`.
**Run result**: N/A: nothing reaches the screen until the match driver runs a boss turn.
**A20 and CE-014**: the production `EffectResolver.apply_value_hook` passes every value through until card-effects story 014, and `clone()` rebuilds a production resolver, so a real `modify_heal` cannot fold on the production path yet. Under the story's allowance the test runs a real `boss.hook_installers` entry on `TestEffectResolver`, through `HookRegistry.copy()`, the clone's rebinding and the engine's `apply_heal` (a Lifesteal hit). Nothing is stubbed in `src/ai/**`. That NOT ASSESSED item closed with review fix D2 below.
**Deviations** (advisory):
- `ThreatEstimate.incoming` returns `float`, not the story's `int`: `burn_per_mana` is a float (GDD F6, range 0–2) and truncating moves the trigger. GDD over story.
- `reach(sandbox, own)` and `unsafe(sandbox, rules, own)` take the sandbox, whose derived values they need, and the side; the story wrote `reach(state, rules)` and `unsafe(state)`.
- `f_self` floors a negative `reach` at 0, or a heavily Taunted board would pay the attack a bonus. F1 does not reach this case: it needs a boss at or under its margin.
- The exception lives in `score_all`, so a lone `score()` stays the plain F1: only `score_all` has the trades to compare.
- A forced `end_turn` (only move, action cap) returns before the mode is re-evaluated, as it returns before the search (C2 order), so it logs the mode of the pass before.
- `src/ai/lethal_search.gd` is outside the planned Files: `_is_taunter` became public so F4's Taunt term has one definition.
- DD-X22's "gives up a blocker" follows GDD F1, which has no such clause (QA plan, informational).

**Unchanged, as told**: one search per turn and the second-search budget. The owner's questions on them stay open.
**Test Evidence**: `tests/unit/boss_ai/boss_ai_defensive_mode_test.gd`, `tests/unit/boss_ai/boss_ai_face_attack_vulnerability_test.gd`
**Reviewed by**: independent `/code-review`, 2026-11-05 (`production/reviews/2026-11-05/code-review-s5-w2-bossai-mr019.md`, full scope, at `f4aff0e`): **CHANGES REQUIRED**, one defect in the test evidence (D2), closed by `811d440` (Review fix D2 below). No separate re-review report exists. Open: the doomed-boss `chosen` assertion, the `f_self` floor and cap fixtures, and F6's frozen-minion question for the owner.

**Review fix D2** (2026-11-05; on trunk `f4aff0e`, CE-014 merged): A20 now runs on the production `EffectResolver`: a real `boss.hook_installers` `modify_heal` entry (`mul` 2, scope `source: friendly`) folded by `apply_value_hook` in a clone, through `HookRegistry.copy()`, the clone's own resolver and `apply_heal`. It passed with no `src/` change. `test_a20_a_boss_passive_that_doubles_healing_reaches_the_sandbox` was seen failing against two mutants, `a20_clone_loses_hooks` and `a20_production_fold_off`, both killed and restored. `TestEffectResolver` is gone from the suite. Verification: import, gates, no_global_rng, parse-check exit 0; commands.test Overall Summary 2045 test cases, 0 errors, 0 failures, 0 orphans, exit 0; commands.smoke exit 0, no SCRIPT ERROR (end 03:01 UTC).
