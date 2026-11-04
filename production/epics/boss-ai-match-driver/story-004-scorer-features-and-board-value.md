# Story 004: Scorer — F1 action score, F2 board value, F3 trade quality, F5 over-extension

> **Epic**: Boss AI + Match Driver
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-04

## Context

**GDD**: `design/gdd/boss-ai.md` (C4, C5, C6, F1, F2, F3, F5, Edge Cases "board full")
**Requirement**: `TR-boss-ai-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Boss AI Planner Threading (the sandbox is a `RulesEngine.clone()`; scoring runs inside the task); ADR-0001: Rules / Presentation Split (`src/ai/**` is `RefCounted`, no Node); ADR-0003 (sandbox randomness from `ai_stream.fork("sim_<turn>")`)
**ADR Decision Summary**: Each candidate is scored by one-ply simulation on a `RulesEngine.clone()` sandbox that shares nothing with the live match; features are deltas before → after and the score is `Σ w_i · f_i` with data-driven weights. The clone carries hooks and the `rng_match` position; the sandbox draws only from its fork.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH / NOT SOURCEABLE
**Engine Notes**: `RulesEngine.clone()` as a deep copy is NOT SOURCEABLE (`duplicate_deep()` applies to `Resource`, not `RefCounted`; the clone is hand-written by the `match-rules` epic). This story must treat the clone as opaque and never reach into `MatchState` fields the match-rules API does not expose. Float arithmetic in GDScript is 64-bit; the ±0.01 tolerance in A11 is the test's, not an excuse for literal fudge.

**Control Manifest Rules (this layer)**:
- Required: `RulesEngine.clone()` deep-copies `MatchState` (including hooks) and binds a fresh `EffectResolver` with no installers — the sandbox. The Boss AI plans on the clone inside a `PlannerTask`. `BossAI` `await`s `planner.checkpoint()` between candidate evaluations (C4–C6 `score_all`).
- Forbidden: Nothing in `src/ai/**` ever calls `signal.emit`, `log.append` on a live log, `get_tree()` or any `Node` method. Never hand the worker the live engine. `RulesEngine.state()` is called only from `src/gameplay/effects/**` — the scorer reads through `legal_commands()`, `clone()`, `submit()` results and the public query surface.
- Guardrail: `clone()` + empty resolver memo per look-ahead node measured by the sim harness against `planner_target_ms` 50 p95; `submit()` ≤ 5 ms worst case. **Note 2026-11-04, DD-X18:** `planner_target_ms` is now 500 p95 per planner run (`play_turn` and `forecast` each).

---

## Readiness (`/story-readiness`, by hand, 2026-11-04)

**Verdict: READY.** Tier: workflow standard (boss-ai has no `system_overrides` row). ADR-0001, ADR-0003, ADR-0006 Accepted; TR-boss-ai-001 active; Manifest Version 2026-11-03 equals the manifest's; story 002 Complete; the cross-epic `clone()` / `legal_commands()` / `submit()` landed with match-rules 010–017 (MR-017 merged at M2, `70947a5`); no open markers; 4 criteria (≥ 2 at `balanced`). QL-STORY-READY skipped — Lean mode.

- **Sandbox Discover (sprint-004.md Goal Prerequisites, option (a)).** BAI-010's `choose` scorer does not exist. Confirmed at readiness: the four fixtures (A11 vanilla minions and a Taunt; A13 a vanilla minion and a player `damage all_enemy_minions` spell; A14 a single-target `damage` spell; A18 a single-target `destroy` spell) contain no `discover` or `choose_one` op, so no sandbox play raises a Choice. Each fixture test also asserts that no scored candidate needed a sandbox Choice answer. Should a future sandbox play raise a boss-side Choice before BAI-010, the scorer answers option 0 and flags the entry `sim_choice_placeholder: true` (the lead's instruction for this lane, 2026-11-04) — a placeholder, not C7 scoring.
- **Reading the sandbox.** No `MatchQuery` exists yet (match-ui epic), and the public engine surface has no board or hand enumeration. The scorer reads `state()` of **sandbox clones only** (read-only), never of the live engine; `score_all` takes a clone as its base. Recorded as an advisory deviation from the manifest's "`state()` only from `src/gameplay/effects/**`".

---

## Acceptance Criteria

*From GDD `design/gdd/boss-ai.md` A11, A13, A14, A18, scoped to this story:*

- [x] **A11** GIVEN the F1 worked example (aggro, 6 mana, player hero at 20 with a 2/3 Taunt, boss 3/3 on board, 4/4 in hand), WHEN scored, THEN the action order is trade, play 4/4, `end_turn`, and the logged scores equal 2.45 and 1.87 (±0.01), with `end_turn` at −1.0 then −0.33.
- [x] **A13** GIVEN the player cast an `aoe`-tagged spell earlier this match (derived from `card_played`, C6) and the boss has 4 minions, WHEN a 5th minion play is scored with `w_over = 1`, THEN its score is lower by exactly `1/7` than the same play with `aoe_seen = false`.
- [x] **A14** GIVEN the control profile and a Fireball-class spell with legal targets 6/6, 1/1 and the player's hero at 30, WHEN scored, THEN the 6/6 is targeted (target choice emerges from `f_threat`, C6).
- [x] **A18** GIVEN the player's board is full (7), WHEN removal and a face attack of equal base score are available, THEN the removal is chosen (`w_threat × 1.25` while `player.board.size == BOARD_SIZE`).

---

## Implementation Notes

*Derived from ADR-0006 Decision and GDD C4–C6 / F1–F3, F5:*

- Files: `src/ai/scorer.gd` (`class_name Scorer extends RefCounted`): `score(candidate, sandbox_before, profile, mode, context) -> {score, features}`; `features` is the eleven-key Dictionary F1 names so `ai_decision.features` can carry it verbatim. `BV(m)`, `threat(m)`, `BV(weapon)` and `trade_quality` are static helpers; `BV_NORM`, `THREAT_NORM`, `keyword_values`, `trade_ratio`, `overextend_cap_aoe` come from the resolved profile / config, never literals (A29).
- One-ply simulation: `sandbox = engine.clone()`; hand it `ai_stream.fork("sim_<turn>")` for any random effect; `submit(candidate)`; auto-answer any Discover the sandbox raises with Story 010's `choose`; read deltas from the clone's public state. A sandbox `resolution_overflow` scores `−∞` and marks `sim_overflow` (Edge Cases); the live engine is untouched.
- `f_over`: `overextend_cap = aoe_seen ? overextend_cap_aoe : BOARD_SIZE`; `aoe_seen` is the only cross-turn memory (C1.3) and is set from public `card_played` events whose spec is `aoe` by the C6 derivation, or by `rules.assume_aoe`.
- Board-full rule: multiply `w_threat` by 1.25 while the player's board has 7 minions; the factor is data (`rules`) if F9 gains a key, else named once in the normaliser table with a C6/Edge-Cases citation.
- DEFENSIVE multipliers (Story 009) are applied to the weight vector before scoring, so the scorer takes the already-multiplied weights and never branches on mode except the Taunt `+0.5` BV bonus.
- Call `await planner.checkpoint()` between candidate evaluations inside `score_all` (makes `score_all` a coroutine — erratum; every caller awaits it).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 005: candidate enumeration, `op_value` pre-filter, position handling, `hero_power` rule (A12, A17).
- Story 006: tie-break set and `ai_<floor>` draws.
- Story 009: DEFENSIVE weight multipliers and A20 (hooks in the sandbox).
- Story 010: `choose` scoring used to auto-answer sandbox Discovers.

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/ai/scorer.gd` (new)
- `tests/unit/boss_ai/boss_ai_scorer_test.gd` (new, 18 tests)
- `tests/helpers/boss_ai_board.gd` (new shared board-fixture helper for the boss-ai scorer / candidate suites; additive)
- `tests/fixtures/boss_ai/f1_worked_example.json`, `tests/fixtures/boss_ai/aoe_seen_board.json`, `tests/fixtures/boss_ai/fireball_targets.json`, `tests/fixtures/boss_ai/player_board_full.json`, `tests/fixtures/boss_ai/battlecry_no_target.json` (new)
- `tests/fixtures/boss_ai/profiles_stub.json` (additive: the F9 `control` archetype, for A14)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/boss_ai/boss_ai_scorer_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] Created — 18 tests, passing (full suite 1332 / 0 failures, 2026-11-04)

---

## Dependencies

- Depends on: `production/epics/boss-ai-match-driver/story-002-profile-resolver-and-validator.md`; `match-rules` epic's `RulesEngine.clone()` / `legal_commands()` / `submit()` (cross-epic; stories not yet created)
- Unlocks: `production/epics/boss-ai-match-driver/story-005-candidates-hero-power-rule-and-positions.md`, `production/epics/boss-ai-match-driver/story-006-tie-break-and-stream-draws.md`, `production/epics/boss-ai-match-driver/story-010-choice-phase.md`

---

## Completion Notes
**Completed**: 2026-11-04 (start 04:22 UTC, end 05:14 UTC; lane 4 wave 3, branch `lane/s4-l4-w3`)
**Criteria**: 4/4 passing — A11 `test_f1_worked_example_plays_trade_then_four_four_then_end_turn_at_the_gdd_scores` (+ `test_f1_trade_features_are_the_worked_example_terms`); A13 `test_aoe_seen_lowers_a_fifth_minion_play_by_exactly_one_seventh` (+ the single-target and `assume_aoe` cases, `test_is_aoe_derives_the_c6_annotation_from_the_effect_spec`); A14 `test_control_fireball_targets_the_six_six`; A18 `test_full_player_board_makes_removal_beat_an_equal_face_attack` and its boundary `test_player_board_of_six_leaves_removal_and_face_attack_equal`. QA-plan extras: isolation (live log, `rng_match.draws`, players unchanged), one checkpoint per candidate, `resolution_overflow` → −∞ / `sim_overflow`, Battlecry with no target scored as a body, DEFENSIVE Taunt +0.5 BV, F2 / F3 examples, and (per the 2026-11-04 match-rules 015/017 review) no trial clone left alive, on the normal and the rejected early-return path. Each new test was seen failing against a mutated scorer (board-full factor, cap, removed threat, checkpoint, end_turn simulation, overflow check, `end_match` on each path), then restored.
**Verification**: `godot --headless --path . --import` exit 0; `commands.test` 1332 test cases, 0 errors, 0 failures, 0 orphans, exit 0, 85 `SCRIPT ERROR` lines (the known intentional negatives, unchanged); `commands.smoke` exit 0, no `SCRIPT ERROR`; `tools/lint/gates.sh` all gates 0 hits.
**Run result**: N/A — the scorer is a headless rules-tier function with no scene; nothing reaches the screen until the match driver (story 013) and Match UI play a boss turn.
**Deviations** (advisory):
- The scorer reads `state()` of **sandbox clones** (boards, hand counts, mana, weapons, own-hand definitions), read-only, because no `MatchQuery` exists yet and the public engine surface cannot enumerate a board. Never the live engine. The manifest says `state()` is called only from `src/gameplay/effects/**`; revisit when `MatchQuery` lands.
- `end_turn` is scored, never simulated: its features are F1/C2's "do nothing" deltas (`after = before`) plus `f_mana = −mana_left / mana_max`. Submitting it would run the player's Start step (their draw) and score the player's turn. C4's "`end_turn` is always simulated" is read as "always evaluated, never pre-filtered".
- Every feature is clamped to [−1, 1] (C5), not only `f_board`, `f_card` and `f_heal` as F1 writes them (overkill face damage or a board wipe otherwise exceeds 1).
- F2's `taunt_bonus`, `flat_bonus` and the F2/F3 constants, F1's `f_card` divisor, the board-full `× 1.25` and the DEFENSIVE Taunt `+0.5` have no F9 key, so they sit once in `Scorer.NORMALISERS` with their GDD citations (the Implementation Notes' fallback).
- The `sim_<turn>` fork is not installed here: no public seam replaces a clone's `rng_match`, and `plan_turn` (story 008) owns the forks (story 006 note). Every trial copies the base sandbox's `rng_match`, so one turn's trials start from one stream position and never advance the live stream; until story 008 installs the fork, a sandbox random effect reads the live stream's future (C4 wants an estimate). Per the review, the fork must come from the `ai_<floor>` stream, never `rng_match.fork()` on a clone.
- Sandbox Discover: readiness option (a); a boss-side Choice raised in a trial is answered with option 0 and flagged `sim_choice_placeholder` until story 010.
- `f_hp` is 0 here; story 005 adds the `hero_power` rule.
- **Budget (F7 needs revision).** The match-rules 015/017 review measured, Godot 4.7.2 debug editor binary, headless: `clone()` 93–190 µs; `clone + submit + end_match` 0.43–1.5 ms per candidate; `legal_commands()` ≈ 0.47 ms. This scorer does exactly one `clone + submit + end_match` per non-`end_turn` candidate plus one base clone per action, so its per-candidate cost is that 0.43–1.5 ms (the A11 test, ~4 candidates × 3 actions, ran in ≈ 11 ms, consistent; an observation, not asserted). F7 assumes `t_sim ≈ 0.01 ms`, about 100× lower: band 3's `(8·250 + 4000)` nodes would take seconds. F7 and the `max_evals_per_action` / `lethal_max_nodes` budgets need revising against MR-018's measurements; not redesigned here.
- For BAI-008 (from the review): compute `TurnPlan.expected_checksum` over the root sandbox's scratch log, event types only.
**Test Evidence**: `tests/unit/boss_ai/boss_ai_scorer_test.gd`
**Reviewed by**: self, no independent review (`/code-review` of BAI-004 is reserved for M3, sprint-004.md)
