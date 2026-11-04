# Story 007: Lethal search — damage subset DFS, F4 prune, node budget, shallow mode

> **Epic**: Boss AI + Match Driver
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-04

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
- Guardrail: `lethal_max_nodes` 50 / 500 / 4000 per band (F7); band 3's counts (this and `max_evals_per_action`) are lowered if A22 (p95 ≤ 500 ms per planner run) fails after match-rules story 019 re-measures (2026-11-04, DD-X18).

---

## Readiness (`/story-readiness`, by hand, 2026-11-04)

**READY.** Tier: workflow standard. ADR-0006 Accepted; TR-boss-ai-001 active; story 005 Complete; four testable criteria, no open question; `story-facts.sh --lint` clean. Advisory: the story embeds Manifest Version 2026-11-03, the manifest is 2026-11-04 (DD-X15..X25, none touching the search). A6, A7 and A9 end in `ai_decision` clauses that need `plan_turn`, which story 008 builds: this story proves the search, and those clauses close with story 008's suite. Sprint readiness note: band 2 and 3 counts stand until MR-019, not a block for band 1.

---

## Acceptance Criteria

*From GDD `design/gdd/boss-ai.md` A6, A7, A8, A9, scoped to this story:*

- [x] **A6** GIVEN boss attackers summing to ≥ player health with no Taunt, WHEN the boss turn runs with any band overlay (every band has `lethal_search ≠ off`), THEN the player's hero is at ≤ 0 when the turn ends and the first `ai_decision.mode` is `LETHAL`.
- [x] **A7** GIVEN lethal that requires killing a 2/3 Taunt with a 3/3 first then attacking face with two others, WHEN band 2 or 3 plays, THEN lethal is taken and the first `ai_decision.mode` is `LETHAL`; WHEN band 1 plays (`lethal_search = shallow`, depth 1), THEN no `ai_decision` on that turn has `mode = LETHAL` and the first one records `lethal_search: shallow_none`.
- [x] **A8** GIVEN lethal only via weapon equip + hero attack + 3-damage spell within mana, WHEN band 3 plays, THEN lethal is taken in that or an equivalent order.
- [x] **A9** GIVEN `potential − taunt_hp < player_health + player_armor` (F4), WHEN the turn runs, THEN the lethal search expands 0 nodes (the prune fires at the root); GIVEN the budget is exhausted without a leaf, THEN null is returned and `ai_decision.mode` records `lethal_search_exhausted`.

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

- `src/ai/lethal_search.gd` (new)
- `src/ai/candidates.gd` (`positions()` extracted from `collect`, no behaviour change)
- `tests/unit/boss_ai/boss_ai_lethal_search_test.gd` (new, 28 tests)
- `tests/helpers/boss_ai_board.gd` (additive: `adopt`)
- `tests/fixtures/boss_ai/lethal_open_face.json`, `tests/fixtures/boss_ai/lethal_through_taunt.json`, `tests/fixtures/boss_ai/lethal_weapon_spell.json`, `tests/fixtures/boss_ai/lethal_pruned_root.json`, `tests/fixtures/boss_ai/lethal_shield_wall.json` (new)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/boss_ai/boss_ai_lethal_search_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] Created: 28 tests, passing

---

## Dependencies

- Depends on: `production/epics/boss-ai-match-driver/story-005-candidates-hero-power-rule-and-positions.md`
- Unlocks: `production/epics/boss-ai-match-driver/story-008-plan-turn-loop-and-turn-plan.md`

---

## Completion Notes
**Completed**: 2026-11-04 (start 19:43 UTC, end 19:56 UTC; sprint 5 lane 1 wave 1, branch `s5/l1-w1`)
**Criteria**: 4/4 at search level. A6 `test_attackers_summing_to_the_players_health_are_lethal_in_every_band`; A7 `test_a_taunt_line_is_found_in_bands_two_and_three`, `test_a_taunt_line_is_beyond_the_shallow_search_of_band_one`; A8 `test_a_weapon_swing_and_a_spell_are_lethal_in_band_three`; A9 `test_f4_worked_example_prunes_at_the_root_expanding_no_node`, `test_f4_equality_does_not_prune_and_one_short_does`, `test_a_budget_of_exactly_the_nodes_needed_finds_the_leaf_and_one_fewer_returns_null`. The turn-level clauses (`ai_decision.mode` `LETHAL` / `lethal_search_exhausted`, `lethal_search: shallow_none`, the hero at ≤ 0 when the turn ends) need `plan_turn` and are asserted in story 008's `boss_ai_plan_turn_test.gd`.
**Tests seen failing**: the whole suite against missing code (`LethalSearch` absent, parse errors, exit 105), then 12 deliberate mutants of `lethal_search.gd`, all killed: F4 `<` to `<=`, armor dropped, greedy order dropped, Spell Damage dropped, root prune dropped, budget off by one, `checkpoint` dropped, `_release` dropped, two burns in shallow, `positions` skipped, sim fork dropped, fault check dropped. The last two survived the first test draft, so `test_search_randomness_comes_from_the_sim_fork_not_the_live_stream` was rewritten to sweep live offsets and `test_a_lethal_blow_that_overflows_is_no_leaf` was added.
**Verification**: import exit 0; `gates.sh`, `no_global_rng.sh`, `parse-check.sh` exit 0; `commands.test` 1438 test cases, 0 errors, 0 failures, 0 orphans, exit 0, 86 `SCRIPT ERROR` lines (intentional negatives; none from `src/ai/` or the new suite); `commands.smoke` exit 0, no `SCRIPT ERROR`.
**Run result**: N/A: nothing reaches the screen until the match driver runs a boss turn (story 013).
**Deviations** (advisory):
- `search` is an instance method of `LethalSearch.new(db, picker)` and takes a fifth argument, `sim_stream` (story 008's "the lethal search's sandboxes take the same fork"). It returns the command list or null; `nodes` and `outcome` carry the counter and the reason, since a null alone cannot tell exhausted from none.
- F4's "hand damage cards" is read as the C3 subset: Charge minions, Rush minions against a Taunt, weapons and a damage hero power count alongside burn. F4's text names only `op amount + Spell Damage`, but A8's weapon line would be pruned at the root otherwise, and an upper bound that excludes a searched line is not one.
- A card whose `amount` or `repeat.times` is an expression (shipped `owner.weapon_attack`) cannot be priced without running it: within mana it makes `potential` unbounded, so it never prunes. F4 is silent on this.
- Shallow reads "depth 1" as no setup ply: attacks on the hero plus at most one burn at the hero, in any number of commands (A6 needs several attacks in band 1). A hero power with a face-reaching `damage` op counts as the burn.
- `src/ai/lethal_search.gd` answers a boss-side Choice with option 0 until story 010, as the scorer does.
**Test Evidence**: `tests/unit/boss_ai/boss_ai_lethal_search_test.gd`
**Reviewed by**: not reviewed in lane (the orchestrator runs `/code-review` at M1).
