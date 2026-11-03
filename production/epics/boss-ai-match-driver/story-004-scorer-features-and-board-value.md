# Story 004: Scorer — F1 action score, F2 board value, F3 trade quality, F5 over-extension

> **Epic**: Boss AI + Match Driver
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

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
- Guardrail: `clone()` + empty resolver memo per look-ahead node measured by the sim harness against `planner_target_ms` 50 p95; `submit()` ≤ 5 ms worst case.

---

## Acceptance Criteria

*From GDD `design/gdd/boss-ai.md` A11, A13, A14, A18, scoped to this story:*

- [ ] **A11** GIVEN the F1 worked example (aggro, 6 mana, player hero at 20 with a 2/3 Taunt, boss 3/3 on board, 4/4 in hand), WHEN scored, THEN the action order is trade, play 4/4, `end_turn`, and the logged scores equal 2.45 and 1.87 (±0.01), with `end_turn` at −1.0 then −0.33.
- [ ] **A13** GIVEN the player cast an `aoe`-tagged spell earlier this match (derived from `card_played`, C6) and the boss has 4 minions, WHEN a 5th minion play is scored with `w_over = 1`, THEN its score is lower by exactly `1/7` than the same play with `aoe_seen = false`.
- [ ] **A14** GIVEN the control profile and a Fireball-class spell with legal targets 6/6, 1/1 and the player's hero at 30, WHEN scored, THEN the 6/6 is targeted (target choice emerges from `f_threat`, C6).
- [ ] **A18** GIVEN the player's board is full (7), WHEN removal and a face attack of equal base score are available, THEN the removal is chosen (`w_threat × 1.25` while `player.board.size == BOARD_SIZE`).

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

- `src/ai/scorer.gd`
- `tests/unit/boss_ai/boss_ai_scorer_test.gd`
- `tests/fixtures/boss_ai/f1_worked_example.json`, `tests/fixtures/boss_ai/aoe_seen_board.json`, `tests/fixtures/boss_ai/fireball_targets.json`, `tests/fixtures/boss_ai/player_board_full.json`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/boss_ai/boss_ai_scorer_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/boss-ai-match-driver/story-002-profile-resolver-and-validator.md`; `match-rules` epic's `RulesEngine.clone()` / `legal_commands()` / `submit()` (cross-epic; stories not yet created)
- Unlocks: `production/epics/boss-ai-match-driver/story-005-candidates-hero-power-rule-and-positions.md`, `production/epics/boss-ai-match-driver/story-006-tie-break-and-stream-draws.md`, `production/epics/boss-ai-match-driver/story-010-choice-phase.md`
