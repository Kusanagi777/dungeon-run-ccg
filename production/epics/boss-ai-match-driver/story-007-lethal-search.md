# Story 007: Lethal search — damage subset DFS, F4 prune, node budget, shallow mode

> **Epic**: Boss AI + Match Driver
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/boss-ai.md` (C3, F4, F7 `lethal_max_nodes`, F9 `lethal_search`, Edge Cases "Lethal and defence")
**Requirement**: `TR-boss-ai-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Boss AI Planner Threading (the search runs on the clone inside the task and `await`s `checkpoint()` between nodes)
**ADR Decision Summary**: Lethal search is a depth-first search over the damage subset of `legal_commands()`; each node clones and submits one command; a leaf with the player hero at ≤ 0 is lethal; F4 prunes; the node budget is a count per band; on exhaustion it returns null and the turn proceeds normally.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH / NOT SOURCEABLE
**Engine Notes**: Each node is a `RulesEngine.clone()` (hand-written deep copy, NOT SOURCEABLE — `match-rules` epic); memory is one clone per live search depth, released on backtrack. Recursion depth is bounded by `max_actions_per_turn` (30); prefer an explicit stack to keep the coroutine shape simple under the erratum (`await checkpoint()` inside a recursive coroutine works but every frame must `await`).

**Control Manifest Rules (this layer)**:
- Required: `BossAI` `await`s `planner.checkpoint()` between lethal-search nodes (C3). Budgets are counts from `ai_profiles.json`.
- Forbidden: Never run the search against the live engine; the worker is never handed the live engine or live log.
- Guardrail: `lethal_max_nodes` 50 / 500 / 4000 per band (F7); at band 3 it is the first knob lowered if A22 fails.

---

## Acceptance Criteria

*From GDD `design/gdd/boss-ai.md` A6, A7, A8, A9, scoped to this story:*

- [ ] **A6** GIVEN boss attackers summing to ≥ player health with no Taunt, WHEN the boss turn runs with any band overlay (every band has `lethal_search ≠ off`), THEN the player's hero is at ≤ 0 when the turn ends and the first `ai_decision.mode` is `LETHAL`.
- [ ] **A7** GIVEN lethal that requires killing a 2/3 Taunt with a 3/3 first then attacking face with two others, WHEN band 2 or 3 plays, THEN lethal is taken and the first `ai_decision.mode` is `LETHAL`; WHEN band 1 plays (`lethal_search = shallow`, depth 1), THEN no `ai_decision` on that turn has `mode = LETHAL` and the first one records `lethal_search: shallow_none`.
- [ ] **A8** GIVEN lethal only via weapon equip + hero attack + 3-damage spell within mana, WHEN band 3 plays, THEN lethal is taken in that or an equivalent order.
- [ ] **A9** GIVEN `potential − taunt_hp < player_health + player_armor` (F4), WHEN the turn runs, THEN the lethal search expands 0 nodes (the prune fires at the root); GIVEN the budget is exhausted without a leaf, THEN null is returned and `ai_decision.mode` records `lethal_search_exhausted`.

---

## Implementation Notes

*Derived from ADR-0006 Decision and GDD C3 / F4:*

- Files: `src/ai/lethal_search.gd` (`class_name LethalSearch extends RefCounted`): `search(sandbox, profile, budgets, planner) -> Array[Command]` (null when none within budget) — a coroutine because it awaits `planner.checkpoint()` between nodes.
- Damage subset: attacks; `play_card` for Charge minions (any target) or Rush (Taunt clearing); spells and hero power whose spec contains a `damage` op that can target the enemy hero; weapon plays followed by a hero attack. Reuse Story 005's annotations for the spec checks.
- F4 upper bound: `potential = Σ attack × attacks_remaining over attackers that can attack + greedy-by-damage/cost sum of hand face damage within mana (face_damage = op amount + boss Spell Damage, match-rules F7)`; `taunt_hp = Σ health of player Taunts`; prune iff `potential − taunt_hp < player_health + player_armor`.
- `lethal_search = shallow` (band 1): depth 1 — direct attacks and one burn; record `lethal_search: shallow_none` on the first decision when it finds nothing. `off`: skip entirely.
- Node = clone + one `submit`; count every expanded node against `lethal_max_nodes`; a sandbox `resolution_overflow` prunes that branch. Return the command list; execution step-by-step with divergence detection is Story 008 (`ai_plan_aborted`).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 008: executing the plan, the second-search-per-turn rule, `ai_plan_aborted` (A10).
- Story 009: DEFENSIVE trigger (lethal is checked first, C2).

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/ai/lethal_search.gd`
- `tests/unit/boss_ai/boss_ai_lethal_search_test.gd`
- `tests/fixtures/boss_ai/lethal_open_face.json`, `tests/fixtures/boss_ai/lethal_through_taunt.json`, `tests/fixtures/boss_ai/lethal_weapon_spell.json`, `tests/fixtures/boss_ai/lethal_pruned_root.json`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/boss_ai/boss_ai_lethal_search_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/boss-ai-match-driver/story-005-candidates-hero-power-rule-and-positions.md`
- Unlocks: `production/epics/boss-ai-match-driver/story-008-plan-turn-loop-and-turn-plan.md`
