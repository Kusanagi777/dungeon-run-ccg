# Story 008: plan_turn — the C2 action loop, TurnPlan, plan_task and the caps

> **Epic**: Boss AI + Match Driver
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/boss-ai.md` (C1, C2, C3 execution, C9 logging, States and Transitions, Edge Cases "Legality and the command loop")
**Requirement**: `TR-boss-ai-001`, `TR-boss-ai-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Boss AI Planner Threading (`plan_turn(sandbox) -> TurnPlan`, `plan_task(sandbox) -> Callable` per the 2026-11-03 erratum, `play_turn` kept for the harness); ADR-0001 (`RefCounted`, mutates only through `submit`); ADR-0003 (`ai_decision` / `ai_plan_aborted` / `ai_fault` payloads, rule 12a)
**ADR Decision Summary**: `BossAI.plan_turn` runs the C2 loop against the clone — `legal_commands()`, sandboxes, `submit()` on the clone, boss `choose` inside — and returns a `TurnPlan {commands[], diagnostics[], expected_checksum, ai_draws, mode_trace}` (plain data, JSON-representable). The planner never writes a live log; the driver replays the commands and appends the diagnostics on the main thread. `play_turn(engine)` keeps its C1.4 contract as `plan_turn(engine.clone())` + immediate replay for the harness.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH / NOT SOURCEABLE
**Engine Notes**: Erratum 2026-11-03 (engine validation claim 12): any function containing `await` is a coroutine and every statically resolved call to it must be `await`ed — `score_all` and the lethal search await `checkpoint()`, so `plan_turn` awaits them and is itself a coroutine; the task Callable must be `func() -> Variant: return await boss_ai.plan_turn(sandbox)`, built by `BossAI.plan_task(sandbox) -> Callable` inside `src/ai/` so `match_driver.gd` stays `await`-free; `play_turn`, the harness and unit tests that call `plan_turn` must `await` it. Verified in all three task shapes. A parse-check test for the call shape is required. FNV-1a checksum in signed int64 — wraparound observed safe (Probe D7).

**Control Manifest Rules (this layer)**:
- Required: The Boss AI plans on `RulesEngine.clone()` inside a `PlannerTask` and returns a `TurnPlan` (plain data). `BossAI` awaits `planner.checkpoint()` between candidate evaluations and lethal-search nodes — the one `await` allowed under `src/ai/**` (G2b).
- Forbidden: Never run `play_turn` against the live engine on the worker. Nothing in `src/ai/**` ever calls `signal.emit`, `log.append` on a live log, `get_tree()`, `Engine.get_main_loop()` or any `Node` method — the only log the planner writes is the clone's scratch log. Never compute one command per task and re-plan per command.
- Guardrail: `max_actions_per_turn` 30 bounds commands per plan; one `TurnPlan` (≤ 30 commands + ≤ 30 diagnostics) per turn.

---

## Acceptance Criteria

*From GDD `design/gdd/boss-ai.md` A1, A10, A24, A27, scoped to this story:*

- [ ] **A1** GIVEN the same `MatchConfig` and `run_seed = 42`, WHEN the boss plays 10 full turns against a scripted player sequence twice (through `ImmediatePlannerTask`), THEN the two `ai_decision` sequences are byte-identical (canonical JSON) and `TurnPlan.to_dict()` is JSON-representable (`GameAssertions.assert_json_representable`).
- [ ] **A10** GIVEN a lethal plan whose first step's Deathrattle summons a player Taunt, WHEN executed on the sandbox, THEN `ai_plan_aborted` appears once in `diagnostics`, the loop re-enters at the top with one more search allowed, and the turn completes with normal scoring (no rejected command in the plan).
- [ ] **A24** GIVEN a state where `legal_commands() == [end_turn]`, WHEN `plan_turn` runs, THEN the plan holds exactly one command and exactly one `ai_decision {chosen: end_turn, alternatives: [], reason: only_move}`; GIVEN an empty list, THEN `ai_fault {reason: no_legal_commands}` is recorded, `end_turn` is attempted once and the planner never spins.
- [ ] **A27** GIVEN a zero-cost card loop fixture, WHEN the turn runs, THEN `end_turn` is submitted after 30 actions with `reason: action_cap`; and GIVEN three rejected commands in one turn on the sandbox, THEN `end_turn` is submitted (`ai_decision.rejection = code` on each, the exact command excluded).

---

## Implementation Notes

*Derived from ADR-0006 Key Interfaces, Implementation Guidelines and GDD C2:*

- Files: `src/ai/boss_ai.gd` (`class_name BossAI extends RefCounted`; `_init(boss_def, resolved_profile, band, ai_stream, op_values, log)`; `plan_turn(sandbox: RulesEngine) -> TurnPlan` (coroutine); `plan_task(sandbox) -> Callable` returning `func() -> Variant: return await plan_turn(sandbox)`; `play_turn(engine) -> void` = `await plan_turn(engine.clone())` + immediate replay — harness only), `src/ai/turn_plan.gd` (`class_name TurnPlan extends RefCounted` with `commands: Array`, `diagnostics: Array[Dictionary]`, `expected_checksum: int`, `ai_draws: int`, `mode_trace: Array[StringName]`, `to_dict()`).
- C2 loop verbatim: `mode = NORMAL; actions = 0; rejections = 0`; first diagnostic is `ai_intent_committed(intent_from_plan(first_plan), kept)` (Story 011 supplies `intent_from_plan` and `kept`); `while sandbox.phase == BossTurn.Main`: `[end_turn]`-only or `actions >= max_actions_per_turn` → decision + `end_turn` + break; `plan = await LethalSearch.search(...)` → `LETHAL`, execute step by step on the sandbox, divergence → `ai_plan_aborted`, re-enter (second search allowed once); DEFENSIVE check (Story 009); `best, top3 = await score_all(cmds, mode)`; record `ai_decision(best, top3, mode)`; `result = sandbox.submit(best)`; rejection handling; `while phase == Choice and pending_choice.side == BOSS: sandbox.submit(choose(...))` (Story 010).
- Every diagnostic is a Dictionary shaped as the event payload (`kind: action|choice`, `chosen`, `mode`, `alternatives[≤3] of {command, score, features}`, mode transitions) with `diagnostic: true`; the driver appends it with `cause_seq = 0` before the command. `expected_checksum` = FNV-1a over the clone's scratch-log event types appended during the loop.
- `ai_draws` = tie-set draws + new fork labels this turn (Story 006). `mode_trace` records every NORMAL → LETHAL / DEFENSIVE transition (ai-code "log every transition").
- Parse-check test: `tests/unit/boss_ai/boss_ai_plan_task_shape_test.gd` loads `boss_ai.gd` and asserts `plan_task(sandbox).call()` returns a `TurnPlan` through `ImmediatePlannerTask` (the dynamic `work.call()` path), proving the erratum shape.
- Each state/transition in the GDD table must be reachable from the payloads alone (`Idle`, `Planning`, `Executing`, `Choosing`, `Ending`, `Faulted`); none is stored in `MatchState`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 009: DEFENSIVE trigger and multipliers (A15), A20.
- Story 010: `choose` (A16).
- Story 011: `forecast`, intent keys, `kept`, `effective_mode` (A19, A21).
- Story 015: replay into the live engine, checksum comparison, `ai_fault {replay_divergence}`.

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/ai/boss_ai.gd`
- `src/ai/turn_plan.gd`
- `tests/unit/boss_ai/boss_ai_plan_turn_test.gd`
- `tests/unit/boss_ai/boss_ai_plan_task_shape_test.gd`
- `tests/fixtures/boss_ai/scripted_player_10_turns.json`, `tests/fixtures/boss_ai/deathrattle_taunt_divergence.json`, `tests/fixtures/boss_ai/zero_cost_loop.json`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/boss_ai/boss_ai_plan_turn_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/boss-ai-match-driver/story-001-planner-task-seam.md`, `production/epics/boss-ai-match-driver/story-005-candidates-hero-power-rule-and-positions.md`, `production/epics/boss-ai-match-driver/story-006-tie-break-and-stream-draws.md`, `production/epics/boss-ai-match-driver/story-007-lethal-search.md`
- Unlocks: `production/epics/boss-ai-match-driver/story-009-defensive-mode-and-sandbox-fidelity.md`, `production/epics/boss-ai-match-driver/story-011-forecast-and-telegraphing.md`, `production/epics/boss-ai-match-driver/story-012-hidden-information-and-purity-gates.md`, `production/epics/boss-ai-match-driver/story-013-match-driver-construction-and-command-gate.md`
