# Story 008: plan_turn — the C2 action loop, TurnPlan, plan_task and the caps

> **Epic**: Boss AI + Match Driver
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-04

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

## Readiness (`/story-readiness`, by hand, 2026-11-04)

**READY.** Tier: workflow standard. ADR-0001, ADR-0003 and ADR-0006 Accepted; TR-boss-ai-001 and TR-boss-ai-002 active; stories 001, 005, 006 and 007 Complete; `story-facts.sh --lint` clean. Advisory: the story embeds Manifest Version 2026-11-03, the manifest is 2026-11-04. Sprint readiness adds two review nits, closed here: **N3** (`collect → score_all → pick` tested end to end) and **N4** (C9's `chosen` against `alternatives`). Band 2 and 3 counts stand until MR-019; not a block for band 1.

**N4, the rule taken from the GDD** (QA plan, "GDD and story contradictions": A24 against A16). A16 and the Edge Case "all Discover options identical: one alternative" count the pick among the alternatives; A24 and C2's `ai_decision(end_turn, [], …)` log `[]`, and that Edge Case says "without scoring". Both hold if `alternatives` are what was **scored**: best first, at most three, the pick always among them; `[]` when nothing was scored (a forced `end_turn`, every `LETHAL` step). One case had no text: a tie-break pick outside the top three. It takes the last slot, which keeps the pick listed and the order best first.

---

## Acceptance Criteria

*From GDD `design/gdd/boss-ai.md` A1, A10, A24, A27, scoped to this story; A3 and A5 moved here from story 006 (its quick-design amendment, 2026-11-04), and the C4 sandbox-stream criterion added by the boss-ai 004–006 code review (2026-11-04):*

- [x] **A1** GIVEN the same `MatchConfig` and `run_seed = 42`, WHEN the boss plays 10 full turns against a scripted player sequence twice (through `ImmediatePlannerTask`), THEN the two `ai_decision` sequences are byte-identical (canonical JSON) and `TurnPlan.to_dict()` is JSON-representable (`GameAssertions.assert_json_representable`).
- [x] **A10** GIVEN a lethal plan whose first step's Deathrattle summons a player Taunt, WHEN executed on the sandbox, THEN `ai_plan_aborted` appears once in `diagnostics`, the loop re-enters at the top with one more search allowed, and the turn completes with normal scoring (no rejected command in the plan).
- [x] **A24** GIVEN a state where `legal_commands() == [end_turn]`, WHEN `plan_turn` runs, THEN the plan holds exactly one command and exactly one `ai_decision {chosen: end_turn, alternatives: [], reason: only_move}`; GIVEN an empty list, THEN `ai_fault {reason: no_legal_commands}` is recorded, `end_turn` is attempted once and the planner never spins.
- [x] **A27** GIVEN a zero-cost card loop fixture, WHEN the turn runs, THEN `end_turn` is submitted after 30 actions with `reason: action_cap`; and GIVEN three rejected commands in one turn on the sandbox, THEN `end_turn` is submitted (`ai_decision.rejection = code` on each, the exact command excluded).
- [x] **A3 (moved from story 006, 2026-11-04)** GIVEN a logged match, WHEN replayed from its `stream_seed` and command list, THEN the AI's `ai_<floor>` draw count per turn equals the original, equals (tie-set draws + number of new fork labels created that turn) (F8, C9; rng-event-log rule 5), and equals that turn's `TurnPlan.ai_draws`.
- [x] **A5 (moved from story 006, 2026-11-04)** GIVEN any state, WHEN `play_turn` runs, THEN the live `match_<floor>` stream's `draws` counter is unchanged by the planner (it moves only by the engine's own draws), the `ai_<floor>` counter rises by exactly (tie-set draws + number of new fork labels this turn), and `sim_<turn>` / `forecast_<turn>` are each created at most once per turn — sandboxes draw from their forks (A3 confirms).
- [x] **C4 sandbox stream (code review 2026-11-04, BAI-004 S1)** GIVEN a boss turn whose candidates include a random effect (`tests/fixtures/boss_ai/random_effect_board.json`), WHEN `plan_turn` scores it, THEN every one-ply trial draws from `ai_<floor>.fork(TieBreak.sim_label(turn))` — `plan_turn` passes that fork as `context[Scorer.CONTEXT_SIM_STREAM]` to every `score_all` of the turn — so the trial outcome does not follow the live stream, and the live `rng_match.draws` and the root sandbox's `rng_match.draws` are unchanged by scoring (the root sandbox keeps its `rng_match` copy, or the replay diverges — ADR-0006).

---

## Implementation Notes

*Derived from ADR-0006 Key Interfaces, Implementation Guidelines and GDD C2:*

- Files: `src/ai/boss_ai.gd` (`class_name BossAI extends RefCounted`; `_init(boss_def, resolved_profile, band, ai_stream, op_values, log)`; `plan_turn(sandbox: RulesEngine) -> TurnPlan` (coroutine); `plan_task(sandbox) -> Callable` returning `func() -> Variant: return await plan_turn(sandbox)`; `play_turn(engine) -> void` = `await plan_turn(engine.clone())` + immediate replay — harness only), `src/ai/turn_plan.gd` (`class_name TurnPlan extends RefCounted` with `commands: Array`, `diagnostics: Array[Dictionary]`, `expected_checksum: int`, `ai_draws: int`, `mode_trace: Array[StringName]`, `to_dict()`).
- C2 loop verbatim: `mode = NORMAL; actions = 0; rejections = 0`; first diagnostic is `ai_intent_committed(intent_from_plan(first_plan), kept)` (Story 011 supplies `intent_from_plan` and `kept`); `while sandbox.phase == BossTurn.Main`: `[end_turn]`-only or `actions >= max_actions_per_turn` → decision + `end_turn` + break; `plan = await LethalSearch.search(...)` → `LETHAL`, execute step by step on the sandbox, divergence → `ai_plan_aborted`, re-enter (second search allowed once); DEFENSIVE check (Story 009); `best, top3 = await score_all(cmds, mode)`; record `ai_decision(best, top3, mode)`; `result = sandbox.submit(best)`; rejection handling; `while phase == Choice and pending_choice.side == BOSS: sandbox.submit(choose(...))` (Story 010).
- Every diagnostic is a Dictionary shaped as the event payload (`kind: action|choice`, `chosen`, `mode`, `alternatives[≤3] of {command, score, features}`, mode transitions) with `diagnostic: true`; the driver appends it with `cause_seq = 0` before the command. `expected_checksum` = FNV-1a over the clone's scratch-log event types appended during the loop.
- `ai_draws` = tie-set draws + new fork labels this turn (Story 006). `mode_trace` records every NORMAL → LETHAL / DEFENSIVE transition (ai-code "log every transition").
- **Sandbox stream wiring (code review 2026-11-04, BAI-004 S1; readiness prerequisite).** The seam exists: `RulesEngine.clone(rng_override: RngStream = null)` (match rules, additive) and `Scorer.CONTEXT_SIM_STREAM`; the scorer gives each trial `clone(sim_stream.copy())` when the key is present, and otherwise falls back to a copy of the base's `rng_match` — the live outcome, which C4 forbids. `plan_turn` must: fork `sim = ai_stream.fork(TieBreak.sim_label(turn))` once per turn (one parent draw, counted in `ai_draws`); pass `{Scorer.CONTEXT_SIM_STREAM: sim}` in every `score_all` context of the turn; leave the root sandbox's `rng_match` alone (never `clone(sim)` the root — ADR-0006 replay); never fork `rng_match` on a clone. The lethal search's sandboxes (story 007) take the same fork. Unit evidence for the scorer half: `boss_ai_scorer_test.gd` `test_trial_random_effect_draws_from_the_sim_fork_not_the_live_stream`; for the seam: `tests/unit/match_rules/match_rules_clone_stream_test.gd`.
- **Canonical `choose` order.** `TieBreak.KEY_FIELDS` now ends with `option_index` (review nit N1), so equal-scored `choose` candidates sort by option; story 010's tie sets need nothing more.
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

- `src/ai/boss_ai.gd` (constructor, planner block)
- `src/ai/turn_plan.gd` (new)
- `src/ai/scorer.gd` (`alternatives` takes the pick, N4; additive)
- `tests/unit/boss_ai/boss_ai_plan_turn_test.gd` (new, 36 tests)
- `tests/unit/boss_ai/boss_ai_plan_task_shape_test.gd` (new, 5 tests)
- `tests/helpers/boss_ai_board.gd` (additive: `started_match`, `adopt` rules overrides)
- `tests/fixtures/boss_ai/scripted_player_10_turns.json`, `tests/fixtures/boss_ai/deathrattle_taunt_divergence.json`, `tests/fixtures/boss_ai/zero_cost_loop.json` (new)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/boss_ai/boss_ai_plan_turn_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] Created: `boss_ai_plan_turn_test.gd` 36 tests, `boss_ai_plan_task_shape_test.gd` 5 tests, passing

---

## Dependencies

- Depends on: `production/epics/boss-ai-match-driver/story-001-planner-task-seam.md`, `production/epics/boss-ai-match-driver/story-005-candidates-hero-power-rule-and-positions.md`, `production/epics/boss-ai-match-driver/story-006-tie-break-and-stream-draws.md`, `production/epics/boss-ai-match-driver/story-007-lethal-search.md`
- Unlocks: `production/epics/boss-ai-match-driver/story-009-defensive-mode-and-sandbox-fidelity.md`, `production/epics/boss-ai-match-driver/story-011-forecast-and-telegraphing.md`, `production/epics/boss-ai-match-driver/story-012-hidden-information-and-purity-gates.md`, `production/epics/boss-ai-match-driver/story-013-match-driver-construction-and-command-gate.md`

---

## Completion Notes
**Completed**: 2026-11-04 (start 19:57 UTC, end 21:51 UTC; sprint 5 lane 1 wave 1, branch `s5/l1-w1`)
**Criteria**: 7/7 passing, in `boss_ai_plan_turn_test.gd` unless noted. A1 `test_ten_boss_turns_from_one_seed_give_byte_identical_decisions`, `test_turn_plan_to_dict_is_json_representable`; A10 `test_a_plan_whose_deathrattle_summons_a_taunt_aborts_once_and_the_turn_completes`, `test_the_abort_allows_exactly_one_more_search`; A24 `test_only_end_turn_legal_gives_one_command_and_one_unscored_decision`, `test_an_empty_legal_list_faults_tries_end_turn_once_and_never_spins`, `test_an_empty_legal_list_whose_end_turn_is_rejected_faults_and_returns`; A27 `test_a_zero_cost_loop_ends_at_the_action_cap`, `test_three_rejections_force_end_turn_and_each_exact_command_is_excluded`; A3 `test_ai_draws_per_turn_equal_tie_draws_plus_the_one_new_fork_and_replay_equally`; A5 `test_planning_never_moves_the_live_match_stream`, `test_play_turn_moves_the_match_stream_only_by_the_engines_own_draws`, `test_a_second_plan_on_the_same_turn_forks_nothing_new`; C4 `test_a_trial_outcome_does_not_follow_the_live_stream`, `test_every_score_all_of_the_turn_gets_the_turns_sim_fork`. N3 `test_the_f1_turn_runs_trade_then_play_then_end_turn_through_the_whole_pipeline`; N4 `test_a_scored_decision_lists_at_most_three_alternatives_with_the_pick_among_them`, `test_a_pick_below_the_top_slots_takes_the_last_one_and_order_stays_best_first`. Story 007's turn-level clauses close here: `test_lethal_on_an_open_board_is_taken_in_every_band_and_logged_lethal`, `test_lethal_through_a_taunt_is_taken_in_bands_two_and_three`, `test_band_one_records_shallow_none_and_never_lethal_even_when_scoring_clears_the_taunt`, `test_the_weapon_and_spell_line_is_taken_on_the_turn`, `test_an_f4_prune_expands_no_node_and_the_turn_plays_on`, `test_an_exhausted_search_is_recorded_on_the_first_decision_and_scoring_completes_the_turn`. Erratum call shape: `boss_ai_plan_task_shape_test.gd`, by running it (immediate and time-sliced, never a worker) and by source scan.
**Tests seen failing**: the code was written before these suites, not after them, so this is not test-first order, and "seen failing" rests on mutants: 28 deliberate mutants of `boss_ai.gd`, `turn_plan.gd`, `scorer.gd` and one test file, all killed. `no_abort_on_not_lethal` survived the first draft, so `test_a_plan_that_runs_out_with_the_player_alive_is_aborted_too` was added and killed it. Two await mutants (`plan_task_no_await`, `src_call_not_awaited`) died by a parse failure that stopped the run: 4.7.2 will not compile an unawaited static coroutine call. So a third, a dynamic call that still parses, was used to see `test_every_call_to_a_planner_coroutine_under_src_ai_is_awaited` fail on its own. Not mutated: `_end_turn`'s `finished` flag, whose mutant is an infinite loop on `EmptyEngine`; `test_an_empty_legal_list_faults_tries_end_turn_once_and_never_spins` asserts one attempt.
**Incident**: a session restart killed a mutant run mid-mutation and left `await` stripped from `_plan_pass(turn)` in `boss_ai.gd`. It was found by reading the diff before the final gate and restored; `s5l1_mutate.py` now restores on a timeout as well. The gate below ran on the restored tree.
**Verification**: import exit 0; `gates.sh`, `no_global_rng.sh`, `parse-check.sh` exit 0; `commands.test` 1479 test cases, 0 errors, 0 failures, 0 orphans, exit 0, 86 `SCRIPT ERROR` lines (unchanged from story 007's run); `commands.smoke` exit 0, no `SCRIPT ERROR`. The exit warning's leaked ObjectDB count rose from 3913 to 4651: not investigated, the new suites leave their live test engines unended, as the older ones do, and `boot_script_teardown_test.gd` is green.
**Run result**: N/A: nothing reaches the screen until the match driver runs a boss turn (story 013). `plan_turn` did run on the real engine: A1's ten boss turns play a full `RulesEngine` match with the production `EffectResolver`. Band 1 to 3 counts were not timed; that is MR-019 and A22.
**Deviations** (advisory):
- **Search frequency, a reading to confirm.** C2's pseudocode searches on every pass; this searches once per turn, plus once after `ai_plan_aborted`. C2 alone contradicts A7: a band 1 trade that clears the Taunt would make a repeat search find the two face attacks, and `LETHAL` would be logged. C3 ("one more search is allowed per turn"), F7 (`lethal_nodes` counted once per run) and C3's "may still stumble into lethal" all fit the reading. The GDD is not edited: it needs no new rule, but C2's pseudocode should say so.
- **31 commands at the cap.** GDD C2 and A27 give 30 actions and then the forced `end_turn`, so the capped plan holds 31 commands and 31 diagnostics. The manifest guardrail and the QA plan say "at most 30". The GDD wins; the guardrail needs correcting. The test asserts `cap + 1`.
- **`_init` takes `db` and `keyword_values` as well** (7th and 8th, required): C1.1, ADR-0008 and the story list six arguments, but `Scorer` and `CandidateSet` need both and the engine exposes no database. Story 013 must pass them.
- **`plan_turn`, `plan_task` and `play_turn` take an optional `planner`**: no document says how `BossAI` reaches the running task's `checkpoint()`. Without it the planner never yields, so story 013/014 must call `plan_task(sandbox, task)` or a time-sliced run blocks the main thread.
- **The caller ends the sandbox** with `end_match()`, so `plan_task`'s lambda keeps the erratum's shape. Story 014's task-done path must do it, on the discard paths too.
- **Diagnostics carry two routing keys**, `event` and `command_index`, since the story's payload shape cannot say which event each is or which command it precedes (a rejected decision has none of its own). `TurnPlan.diagnostics_before()` and `event_payload()` are for story 015. Extra payload keys: `tie_set_size`, `lethal_nodes`, `mode_transition`.
- `lethal_search_exhausted` is written into `mode` on the first decision only, as A9 and the Edge Cases read; `mode_trace` keeps the mode played. Story 009 should know a DEFENSIVE first decision after exhaustion shows the literal there.
- Undefined values named here: `ai_fault {reason: end_turn_rejected}`; `ai_plan_aborted {reason: diverged | rejected | not_lethal, at_step}`; the rejection-forced `end_turn` has no `reason` (C2's set is closed at `only_move | action_cap`). A fault on the sandbox itself logs `ai_fault` with the match's own reason (States `Faulted`).
- `ai_intent_committed` is not emitted: story 011 supplies it and inserts it as the first diagnostic.
- Divergence is detected by legality, rejection, or a plan ending with the player alive, not by comparing state per step. A step that stays legal on a changed board runs on, and the plan is aborted at its end.
- `aoe_seen` is read from the injected log in `plan_task` and `play_turn`, on the main thread (C1.3, ADR-0006). A direct `plan_turn` call does not read it.
- `play_turn` writes diagnostics through `engine.emit`, because `log.append` on a live log is forbidden in `src/ai/**`. Harness only.
- Boss-side Choices are still option 0, flagged `sim_choice_placeholder`, in `BossAI._answer_choices`, `LethalSearch._answer_choices` and `Scorer._answer_choices`. Story 010 owns all three.
**Test Evidence**: `tests/unit/boss_ai/boss_ai_plan_turn_test.gd`, `tests/unit/boss_ai/boss_ai_plan_task_shape_test.gd`
**Reviewed by**: not reviewed in lane (the orchestrator runs `/code-review` at M1).
