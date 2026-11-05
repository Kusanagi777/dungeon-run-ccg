# Sprint 5 code review: Boss AI lethal search, plan_turn, choice phase, planner_target_ms

Reviewer: lead-programmer, independent. Commit `3531e19` on `bootstrap/ccgs-template`. `src/ai/` is byte-identical from `f75dab6` to `3531e19` (`git diff --quiet`). Read-only: nothing edited, committed or merged, and Godot not run.

| Item | Verdict |
|---|---|
| Story 007 lethal search (`a50eacb`) | **APPROVED WITH SUGGESTIONS**, one design question open |
| Story 008 `plan_turn` (`347b9e3`) | **CHANGES REQUIRED**, one defect |
| Story 010 choice phase (`f17e47e`, `f75dab6`) | **APPROVED WITH SUGGESTIONS** |
| `planner_target_ms` knob (`631a7ae`) | **APPROVED WITH SUGGESTIONS** |

## What was and was not assessed

**Ran:** `tools/lint/gates.sh` (G1 to G7, all 0 hits, PASS) and `tools/lint/no_global_rng.sh` (0 hits). Both are read-only grep gates.

**Not assessed, and why:**
- **The test suite was not run** (no Godot, by instruction). Every statement about what a test does comes from reading it. The stories' pass counts and mutant kills are the authors' claims, not observed here.
- **`match_driver.gd` being `await`-free: NOT ASSESSED — the file does not exist at this commit** (stories 013 to 015 unbuilt). G2b's bare-`await` scope covers `src/gameplay`, so the gate will apply when it lands. A 0-hit G2b today says nothing about it.
- **A22 and A30: NOT ASSESSED — no measurement exists.** No planner timing and no main-thread frame data at any band.
- **`plan_turn` on a real `WorkerThreadPool` thread: NOT ASSESSED.** No test runs it (`tests/unit/**` never starts a worker, and `tests/integration/boss_ai/` holds only the data test). Concurrent read-only Dictionary access is NOT SOURCEABLE (ADR-0006).
- **A4 (decoy hand and second-fixture byte identity):** no such test yet; story 012 owns it. Hidden information below is judged from code only.
- **A31 / DD-X22 vulnerability exception:** not implemented at this commit (`scorer.gd` has no `vulnerable`). That is story 009, out of scope, not a finding here. The C6 attack valuation half of DD-X22 is in `candidates.gd` `attack_value` and matches the GDD.
- **DD-X20:** shipped `op_values` still has 19 rows, no `add_counter`. F9 says this is expected until content-010 (merges last at M2). No shipped card uses the op.
- **Forecast, `intent_from_plan`, DEFENSIVE:** stories 011 and 009, not built.

---

## Story 007: Lethal search

### Engine Specialist Findings: ISSUES FOUND (none blocking)
`godot-gdscript-specialist` ran over the planner files, read-only, with a brief that carried no findings of mine. It reported `await` on non-suspending coroutines, the `Variant` return across `await`, lambda captures and the null guards as clean, consistent with engine-validation claims 10 to 12. Its findings, each checked:

| Claim | Where | Result |
|---|---|---|
| A suspended, never-completed pass leaks the task and the clones on `stack` | `lethal_search.gd:126-154`, `time_sliced_planner_task.gd:68` | VERIFIED as a dependency, not a defect: clones end only on normal exits. ADR-0006 `shutdown()` blocks until the task ends, so story 015 must poll to the end and never drop a live task |
| A script error in `_run` leaves `_done` false forever | `time_sliced_planner_task.gd:73-77` | UNVERIFIED — specialist claim. `test_time_sliced_errored_work_gives_null_result_and_finishes` covers an error before any suspension; an error after one is untested. Story 001 code, outside this scope |
| Shared fields written on the worker race the main thread | `boss_ai.gd:635-641` | Dropped: ADR-0006 forbids main-thread reads of `BossAI` while a task is live, and one task runs at a time |
| `legal_commands().has(step)` fails if `positions()` adds keys | `boss_ai.gd:595` | Dropped: `positions()` returns `legal_commands()` entries unchanged |
| `chooser.gd:123` cast, clock typing, `_NoYield` base | | Dropped: request kinds are a closed pair, the clock is injected, `_NoYield` extends `PlannerTask` (`boss_ai.gd:195`) |

### Testability: GAPS
QA plan rows are covered: A6 to A9, F4 worked example, equality, budget exact and one short, budgets from data, isolation, checkpoint count, shallow, overflow. Gaps:
- No test suspends inside `search`. `test_checkpoint_runs_once_per_expanded_node` counts checkpoints with a planner that never yields, and the one yielding test (`boss_ai_plan_task_shape_test.gd:63`) uses the F1 board, so the explicit stack is never run across a real suspension.
- `test_every_clone_of_the_sandbox_is_ended_on_each_exit_path` tracks only the root's direct clones. `TrackingEngine.clone` is not inherited by the plain clones it returns, so depth 2 and deeper are unchecked. A leak in `_leave` at depth would pass.
- `test_f4_counts_hand_damage_greedily...` uses a hand where greedy happens to be optimal, so it cannot show the problem in DQ-1.

### ADR Compliance: COMPLIANT
- ADR-0006: search runs on clones, `await planner.checkpoint()` once per node (`lethal_search.gd:140`), counts not clocks, null on exhaustion.
- ADR-0007: `state()` on a sandbox clone is the read API its 2026-11-04 erratum allows until `MatchQuery` exists.

### Standards Compliance: 5/6
- `search` is 48 lines (`lethal_search.gd:108-155`), over the 40-line limit. The explicit stack explains it; a nit.

### Architecture: CLEAN
### SOLID: COMPLIANT
`LethalSearch`, `Scorer` and `Chooser` reach into `BossAI` for `STRUCTURAL_OPS` and `is_number` (a pre-existing pattern). Schema constants on a smaller shared class would remove the cycle. Nit.

### Game-Specific Concerns
**Determinism: clean.** Depth-1 clones take `sim_stream.copy()`, deeper clones copy their parent's stream, the fork is never advanced, and node Choices draw from `node.rng_match()`. `test_search_randomness_comes_from_the_sim_fork_not_the_live_stream` sweeps 12 live positions and would catch a dropped fork.

**Sandbox isolation: clean.** The caller's sandbox is only read and cloned; every clone ends on the found, exhausted and normal paths.

**Hidden information: one latent defect (D-2).** `potential`, `_rank` and `_played` read only the side to move's hand. The player's hand is never read.

**No residue:** F4 `<`, the budget compare, `_denser` and the ranks all match the spec.

### Positive Observations
- The explicit stack keeps one coroutine frame and makes clone lifetime easy to follow.
- `outcome` separates exhausted from none, which a bare null cannot.
- The rewrite of the sim-fork test after a surviving mutant is the right response, and the story is candid that tests came after the code.

### Required Changes
None in code. DQ-1 needs an owner answer.

### Suggestions
- **D-2 (defect, latent, not blocking; close with story 012).** A search node reads the boss's real deck order, which C1.3 forbids ("either `deck` order"). A clone keeps the true deck, so a subset move that draws puts the real top card in the child's hand and `_frame` enumerates it (`lethal_search.gd:149`, through `candidates.gd:131`). The sim fork does not help: the draw is not random at draw time. **Today's reach:** `boss_ember_bolt` (damage + draw) is the only subset move that draws, it is only in band 1 `boss_torchbearer`, and shallow's one-burn rule (`lethal_search.gd:284`) stops anything drawn from being played, so no shipped line exploits it. Any draw on a Charge, weapon or burn card in a band 2 or 3 deck would. Fix: do not enumerate hand cards absent from the root's hand, and add a fixture with a planted top card to story 012.
- **D-3 (defect, latent).** `_hand_damage` counts a Charge minion once (`lethal_search.gd:325`), though the weapon branch two lines down handles Windfury. A Charge + Windfury minion undercounts F4 and can prune a real lethal. No shipped card has both.
- Add a time-sliced lethal test and track clones at depth.

### Design question for the owner
- **DQ-1: F4 is not an upper bound, in two ways.** The code follows the GDD, and A9's worked example still holds under either fix below. C3 and the heading call it an upper bound, and that is what makes pruning safe.
  - *Burn is charged for the Taunt* (`lethal_search.gd:166`). Taunt restricts attacks only (`rules_engine.gd:1703`). Player at 3 with a 2/5 Taunt, boss holds a 3-damage bolt and no attackers: `3 − 5 < 3`, pruned at 0 nodes, though the bolt to the face is lethal.
  - *Greedy mana can miss the best line* (`lethal_search.gd:200-208`). 5 mana, 3-cost 4-damage and 5-cost 6-damage, player at 6: greedy takes the first, `potential` is 4, pruned, though the second is lethal.
  - Scoring may still take these lines (C3 "stumble"), but no `LETHAL` is recorded and a band 3 boss misses a proven kill. Candidate rule: `max(0, attack_part − taunt_hp) + burn_part`, with a fractional-knapsack burn bound. Owner decides; F4 and A9 would change together.

### Verdict: APPROVED WITH SUGGESTIONS

---

## Story 008: plan_turn, TurnPlan, plan_task

### Engine Specialist Findings: CLEAN for this story's coroutine chain (see Story 007 table)

### Testability: GAPS
All seven ACs and N3, N4 map to tests. Strong ones: A10's three tests, `test_a_plan_that_runs_out_with_the_player_alive_is_aborted_too` (a sweep that asserts it reached the case), the checksum against a live replay, and the time-sliced `to_dict` equality. Gaps:
- **A3's "replay" is a re-run.** `test_ai_draws_per_turn_equal_tie_draws_plus_the_one_new_fork_and_replay_equally` calls `_ten_turns` twice (`boss_ai_plan_turn_test.gd:202-203`). That proves determinism and the draw formula, not "replayed from its `stream_seed` and command list". The AC is marked done on a weaker proof. The tie-draw count also ignores choice ties, which is safe only because the fixture has none.
- The root-sandbox fault branch (`boss_ai.gd:463-465`) has no test.
- Nothing asserts time-sliced mode through the call shape story 014 will use (see D-1).

### ADR Compliance: DRIFT
- **ADR-0006 `BossAI` must yield when time-sliced: met only for callers that pass the task (D-1).**
- Every `await` in `boss_ai.gd` (lines 439, 462, 480, 524, 532) is on the planner's own coroutines, as the manifest allows; G2b 0 hits. `plan_task` builds the erratum's lambda; `_read_public_log` stays on the main thread.
- **ADR DRIFT (warning):** `play_turn` writes the live log through `engine.emit` (`boss_ai.gd:485`). That is `log.append` on a live log by another name, which the manifest forbids in `src/ai/**`; the story states it, no gate sees it. The manifest also routes the harness through the driver, so `play_turn` may have no production caller. Keep it test-side or amend the rule.
- **MINOR:** `_init` takes 8 arguments; the manifest and C1.1 list 6.

### Standards Compliance: 6/6 for the planner block

### Architecture: MINOR ISSUES
Stale docs: `boss_ai.gd:8` says `choose` arrives later; `planner_task.gd:10,26` show the no-planner calls (D-1); `scorer.gd:47-51` says "until a caller passes it".

### SOLID: COMPLIANT

### Game-Specific Concerns
**Determinism: clean.** One `sim_<turn>` fork per turn, memoised, counted through the `draws` delta (`boss_ai.gd:458-460`); every `score_all` gets it; ties and root Choices are the only live `ai_<floor>` draws and all reach `ai_draws`; the root's `rng_match` moves only by accepted commands. No draw reaches a global RNG (G6 and `no_global_rng.sh` 0 hits).

**Isolation: clean.** Scratch log, copied stream, `test_planning_writes_nothing_to_the_live_log`. `RngStream`'s header says a worker never uses a live stream, but ADR-0006 hands it `ai_<floor>` on purpose: fix the comment, not the code.

**Hidden information: clean in this file.** `_measure` reads hand definitions for the active side only and counts otherwise. `_read_public_log` uses `card_played` alone. Pending player Choices are read for `side` only.

**Termination: clean.** Every pass consumes a search, an action or sets `finished`.

**Time-slicing even when wired:** `_execute_lethal` and `_answer_choices` run up to the action cap of submits with no checkpoint (`boss_ai.gd:590-611`). ADR-0006 asks only for checkpoints in scoring and search, but A30's 2 ms could be overrun on a long lethal. Unmeasured.

**Debug residue: none.** `src/ai/` holds no `print`, `breakpoint`, TODO or mutant marker. All five awaits are present, including the `_plan_pass` one the story's incident lost. `MAX_REJECTIONS`, `ALTERNATIVES_MAX`, the normalisers, `trade_quality`, the tie band, the pre-filter and `next_mana_max` were compared against the GDD by hand and match. No stray `.bak`, `.orig` or mutation file is tracked.

### Positive Observations
- `TurnPlan` is genuinely plain data with one shared checksum for both sides of a replay.
- Routing by `command_index` solves a real gap in the story's payload shape.
- The deviations list is thorough and honest, D-1 included.

### Required Changes
- **D-1 (defect, blocking).** `boss_ai.gd:437`: `func plan_task(sandbox: RulesEngine, planner: PlannerTask = null) -> Callable:`. With no planner, `plan_turn` substitutes `_NoYield` (`boss_ai.gd:452`), so a `TimeSlicedPlannerTask` runs the whole plan inside `start()` on the main thread and reports success. F7 puts band 3 at about 2,190 ms. Nothing fails: only A30's windowed profile would show it.
  - This is the shape everyone is told to write. Story 014's AC (`story-014...md:36`), the ADR-0006 diagram (line 248), the manifest and `planner_task.gd:10,26` all say `plan_task(sandbox)`. Story 008 notes the trap, but a note does not reach a driver built to its AC against a fake task.
  - Shipped `planner_mode` is `worker`, so the default path is unaffected; the fallback and `--ai-sync` are.
  - **Fix:** make `planner` required on `plan_task`, keeping the default on `plan_turn`. Update the immediate-task test callers, `planner_task.gd`, story 014's AC, and through their owner ADR-0006, ADR-0008 and the manifest. Answer to the review's question: time-sliced runs can yield, and the test proves it, but only when the caller passes the task.

### Suggestions
- Make A3's test a real replay, or restate the AC.
- Add a root-fault test and a checkpoint in `_execute_lethal`.
- Correct the manifest's "≤ 30 commands + ≤ 30 diagnostics": 31 is right by C2, and `choose` commands are not counted either, so a plan can exceed 31. Same for the QA plan's edge case.

### Design questions for the owner
- **DQ-2: one search per turn.** C2's pseudocode searches every pass; the code searches once plus once after an abort (`boss_ai.gd:520`). The story's argument holds for band 1 (A7), but bands 2 and 3 then never see a lethal that opens mid-turn, such as after a trade or a draw. Confirm, and fix C2's text either way.
- **DQ-3: F7 budget.** An abort allows a second full search, so F7's `8·evals + lethal` is really `+ 2·lethal` worst case: about 1,460 ms more at band 3. Include it when counts are retuned after MR-019.
- **Divergence by legality (noted in the story).** A plan whose state changed but stays legal runs to its end in `LETHAL` before `not_lethal` fires. C3 says the plan is discarded when the state diverges. Accept or tighten.

### Verdict: CHANGES REQUIRED

---

## Story 010: Choice phase

### Engine Specialist Findings: CLEAN (see Story 007 table)

### Testability: GAPS
A16, the Discover score, `cost_fit` at and over the limit, one preference case per profile, Choose One, collapse, ties and the QA "`choose` inside a plan" case are covered, with real engine Choices. `test_a_scorer_without_op_values_answers_at_the_c6_fallback_row` is close to vacuous: it asserts only that a removed key is absent, not what its name says.

### ADR Compliance: COMPLIANT
- ADR-0006: pure over the clone, returns an index.
- ADR-0008: `-> int`, with `last_choice` for the task. Sound.

### Standards Compliance: 6/6

### Architecture: CLEAN

### SOLID: ISSUES FOUND
`Chooser` hard-codes the boss side (D-4).

### Game-Specific Concerns
**Determinism: clean.** Root ties draw from `ai_<floor>` and count in `ai_draws` (`boss_ai.gd:642`); trial and node ties draw from their own copy; collapse precedes the tie-break, so duplicates cost nothing. `next_mana_max` matches the engine's Start step (`rules_engine.gd:2388`) on either side's turn.

**Hidden information: clean.** A player's request returns `NO_OPTION` before its options are read.

**Performance:** `Chooser.choose` builds a `CandidateSet` per Choice, so the annotation memo is lost. Minor.

### Positive Observations
- The C7 readings of `damage_all`, `low_cost` and tags are written down rather than silently chosen.
- The passive_driven gap was raised, not filled with an invented number.

### Required Changes
None for this story's ACs.

### Suggestions
- **D-4 (defect, not blocking now; must be fixed before story 016).** `chooser.gd:70` returns `NO_OPTION` for any side but `boss`, while `plan_turn` and `LethalSearch` are side-neutral. C11 and story 016 pilot the hero seat with a second `BossAI`. There, `neutral_smite_or_mend` leaves the root sandbox stuck in `Choice`: `_answer_choices` returns (`boss_ai.gd:636`), `_is_own_main` is false, and the plan ends with no `end_turn` and no diagnostic. Trials score it as if nothing resolved. Fix: pass the planner's own side. `test_a_players_pending_choice_is_never_scored` would then pass that side too.
- Also record a fault when `_answer_choices` gives up (`boss_ai.gd:636-637`) rather than ending the plan silently.
- Give the vacuous test a real assertion.

### Design question for the owner
- **DQ-4 (already open in the story).** `passive_driven` has no `choice_preference` rows, so shipped `boss_rot_warden` scores a preference of 0 and C7's clause does nothing. Confirmed in `ai_profiles.json`.

### Verdict: APPROVED WITH SUGGESTIONS

---

## planner_target_ms knob

### Engine Specialist Findings: N/A — validator and data only; no coroutine or engine code touched

### Testability: TESTABLE
Every QA NC-8 row is met: shipped 500 against the registry; 50 and 1000 accepted; 49, 1001, 49.9, 1000.1, 0, negative, string, null, bool, NaN and infinities rejected with `E_AI_WEIGHT_RANGE` on the right field; key required; nested `runtime` proven read-only through `CardDatabase`; bounds in `RANGES`; byte-identical plan at 50 and 1,000; unknown keys still rejected. Every fixture with a `runtime` block carries the key.

### ADR Compliance: COMPLIANT
Matches handoff section 4 and DD-X18: value 500, range 50 to 1,000, `runtime` block, counts untouched. Only the validator in `src/` names it; `BossAI` is never handed `runtime`.

### Standards Compliance: 6/6
### Architecture: CLEAN
### SOLID: COMPLIANT

### Game-Specific Concerns
None. It is not a clock: nothing in `src/ai` or `src/gameplay` reads it.

### Positive Observations
Same-commit validator and data, with the F9 line updated as the data test requires.

### Required Changes
None.

### Suggestions (nits)
- `test_planner_target_is_never_a_runtime_clock` exempts all of `boss_ai.gd`, the file that holds the planner. Exempt the validator lines, not the file.
- `integral: false` accepts `500.5`. Harmless; set it `true` if whole milliseconds are meant.
- `sprint-005.md` still lists the knob as missing (the QA plan noted this).

### Verdict: APPROVED WITH SUGGESTIONS
