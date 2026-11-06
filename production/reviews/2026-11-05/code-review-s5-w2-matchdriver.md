# Sprint 5 code review: MatchDriver stories 013 and 015

Reviewer: lead-programmer, independent. Commit `2117aa3` (trunk had not moved at the end of the review). Read-only.
Process: `.claude/skills/code-review/SKILL.md`, followed by hand. Phase 7 ran `godot-gdscript-specialist` and `qa-tester`. `godot-specialist` was not spawned: neither file touches scenes, nodes or lifecycle hooks.

| Story | Commit | Verdict |
|---|---|---|
| 013 construction, gate, concede slot | `d3c7115` | **CHANGES REQUIRED** (one defect, R-1) |
| 015 tick, replay, shutdown | `6151700` | **APPROVED WITH SUGGESTIONS** |

Separately, four design questions (Q-1 to Q-4) must be answered before BAI-014 starts. They do not block these two stories, because no production code starts a task yet: `src/` has no `MatchDriver.new`, no `driver_factory` and no caller of `_start_plan_task`.

**Not run:** Godot, gdUnit and `no_global_rng.sh`. The stories' pass counts are their own claims. The counts do match the files: 17 and 37 `func test_`, and 1746 + 37 = 1783. `tools/lint/gates.sh` was run at `2117aa3`.

---

## Direct answers to the review questions

| Question | Answer |
|---|---|
| `match_driver.gd` `await`-free, no gate weakened | **Yes.** No `await` in the file. `gates.sh`: G1 to G7 all 0 hits, exit 0. `git diff 6694a41 2117aa3 -- tools .github .claude/scripts .claude/hooks project.godot` is empty. G1, G2 and G2b scan `src/gameplay` recursively, so `src/gameplay/run/` is covered. |
| Nothing reaches the engine outside the gate | **Yes.** The only `_engine.submit` calls in the driver are lines 133 and 323, and nothing else outside the rules tier submits to the live engine. `src/ai/**` submits only to sandboxes, apart from the harness-only `play_turn`. A forged `end_turn(boss)` is re-stamped `player` and refused. |
| Concede slot | **Behaves.** A single Dictionary slot, cleared at `Ended` and at shutdown. Queued only while a task is live and not ended. On task return the result is discarded before the concede is submitted. |
| Can a checksum mismatch pass? | **Not for a plan with commands.** Three limits, two of them by design: the checksum is types-only, so payload drift passes (ADR-0006 specifies this); a replay that reaches `Ended` is never compared (the log is sealed by then); an empty plan is never compared (correct, since its `expected_checksum` is 0, but see Q-3). |
| Replay bounds | **Correct.** Minimum one command per tick, budget spent means stop, poll time counts against the budget, carry works across ticks. Budget is read once from data. |
| `tick()` order | **Correct** per ADR-0008 Decision 4. Poll at most once per tick, never after `true`. |
| `match_ended` | **Correct.** Emitted once, after the event reached subscribers. No engine signal connected. |
| Double shutdown | **Safe.** `_task` is null the second time and `end_match()` is idempotent. |
| Shutdown mid-plan | **Correct by reading, but untested** (S-3). |
| Leaks | **None found** for the three task types once a task has finished. Teardown was tested only with a fake task (S-5). |
| Running worker | **Handled.** At `Ended` the task stays held until `tick()` or `shutdown()` collects it. Only the clone is in the worker's hands, and the sandbox ends after `poll()` is true. |
| Injected clock | **No blocking test depends on real time.** `match_driver_gate_test.gd:79,104` and `match_driver_replay_test.gd:761` use the default clock, but none asserts on pacing or faults. The default is exercised but never asserted on. |
| `PlannerTask` one object per match | **Only a defect at BAI-014, not now** (Q-1). |
| `match_query.gd` hidden information | **Not fully respected** (R-1). Read-only rules hold: every answer is a value or a copy. |
| Would tests fail if behaviour were wrong? | **Mostly yes.** The exceptions are listed in S-3, S-4 and S-6. |

---

## Code Review: Story 013, MatchDriver construction, command gate, concede slot

### Engine Specialist Findings: ISSUES FOUND
Shared with story 015; see the disposition table at the end. The one that lands here is Q-1.

### Testability: GAPS
All four criteria map to tests that would fail. Gaps, all minor:
- AC-1 "one forecast after the mulligan" is unassessed, as the story records. BAI-014 AC-1 covers the same behaviour. The criterion is ticked `[x]` although half of it is NOT ASSESSED.
- `test_a_concede_during_a_boss_choice_with_no_task_drops_the_choice` (`match_driver_gate_test.gd:341`) never reads `pending_choice()`, so "the continuation is dropped" is asserted only through `discover_picked`.
- `test_a_second_concede_does_not_grow_the_slot` (`:272`) would still pass with a growing queue, because a refusal after `Ended` is unlogged. It adds little beyond the slot being a Dictionary.

### ADR Compliance: DRIFT
- **ADR-0001: COMPLIANT.** No Node, autoload, coroutine or UI import.
- **ADR-0008 Decisions 1 and 2: COMPLIANT.** Build order is spy-recorded. The third `EffectResolver` argument follows the 2026-11-04 erratum.
- **ADR DRIFT (WARNING):** ADR-0006:283 and ADR-0008:372 say `start` runs "exactly once per task object", while ADR-0008 Decision 3 runs every task through the one injected object. The ADRs contradict each other. See Q-1.
- **MINOR DEVIATION (INFO):** `BossAI.new` takes eight arguments; ADR-0008 and manifest line 192 show six. The queued-concede path returns without `_after_engine_step()`, although Decision 2 says "every accepted or rejected submit". It changes nothing, because the engine was not touched.

### Standards Compliance: 6/6 passing

### Architecture: CLEAN
Dependency direction is correct. `MatchQuery` sits in the rules tier as the erratum requires.

### SOLID: COMPLIANT
`PlannerTask` is the seam. The concrete `RulesEngine` dependency is what ADR-0008 specifies.

### Game-Specific Concerns
Hidden information: see R-1.

### Positive Observations
- `submit` stamps a deep copy, so the caller's command is untouched, and a test proves it.
- One overridable method per construction step gives real spy evidence with nothing production-only added.
- The concede slot's ordering against `Ended` is tested from both sides.

### Required Changes

**R-1. Defect (hidden information): `MatchQuery.pending_choice()` hands the UI a boss Choice's options, and the class example shows them.**
- `src/gameplay/match/match_query.gd:37-38` returns the full `ChoiceRequest` whatever its side.
- `match_query.gd:12-13` is the published usage: `if query.phase() == MatchState.PHASE_CHOICE: show_options(query.pending_choice().options)`. Following it during a boss Discover shows the player the boss's options.
- `design/gdd/match-ui.md:644-646`: "The player never sees the options (hidden information)." The same design redacts at the query level for `hand("boss")` (U2, line 111).
- Nothing consumes this today, so no leak exists yet. But MUI-003 inherits it, and its QA row covers only `hand("boss")`, so nothing later would catch it.
- Fix: for `side == boss` return no options, and put a `side` check in the example. Add one test. Adding it to MUI-003 as an explicit criterion also closes this, provided the example is corrected now.
- Confidence: VERIFIED.

### Suggestions
- **N-1. Nit:** `pending_choice` in U2 implies a caller checks `side`, so the owner may prefer to document that rather than redact. Redaction is the safer reading, and R-1 records it as such.
- **S-1. Defect, MUI-003 hand-off:** `match_query.gd:32` `phase()` returns a String, while U2 (`match-ui.md:108`) specifies `Phase` plus `active_side`. `PHASE_MAIN` is the same for both sides, so the query alone cannot enable End Turn. The `MAIN` assertion at `match_driver_gate_test.gd:205` runs on the boss's turn. Add it in MUI-003.
- **Q-5. Design question, MUI-003:** `legal_commands()` is a pass-through as specified, so on the boss's turn it lists boss commands, including `end_turn`, and shows which boss hand indices are affordable. `match_driver_gate_test.gd:206` pins this. `match-ui.md:870` drives End Turn from it. The owner should decide whether the UI-facing list keeps player commands only.
- **N-2. Nit:** `MatchQuery` "answers at all times" has one exception: after `shutdown()` of an unfinished match the resolver is unbound, and `legal_commands()` for a targeted card hits `assert(_engine != null)` in `effect_resolver.gd:307`. Nothing queries then. Soften the comment.
- **N-3. Nit:** `_settings = settings` keeps the caller's Dictionary. Decision 7 calls it a snapshot.
- **N-4. Nit:** `production/epics/match-ui/story-003` still carries a stale ownership flag placing the class under `src/ui/match/`, and the QA plan says MUI-003 "creates" the file.

### Verdict: CHANGES REQUIRED

---

## Code Review: Story 015, tick, bounded replay, match_ended, shutdown

### Story 015 — Engine Specialist Findings: ISSUES FOUND
See the disposition table at the end. Nothing in it blocks this story.

### Story 015 — Testability: GAPS
All four criteria and the QA rows map to tests. Mutation reasoning leaves the gaps in S-3 to S-6.

### Story 015 — ADR Compliance: DRIFT
- **ADR-0003: COMPLIANT** apart from D-1 (one narrow path appends to a sealed log).
- **ADR-0006 replay protocol and ADR-0008 Decisions 4, 5, 9: COMPLIANT.**
- **ADR DRIFT (WARNING):** the optional fifth argument `clock` is not in ADR-0008 Key Interfaces. The story records this; the ADR still needs the line.
- **MINOR DEVIATION (INFO):** the checksum is computed once at the end from the log rather than folded per command. Equivalent. `at_index = commands.size()` for a final mismatch is a reading the story asks to have confirmed; it is reasonable.

### Story 015 — Standards Compliance: 6/6 passing

### Story 015 — Architecture: CLEAN

### Story 015 — SOLID: COMPLIANT

### Story 015 — Game-Specific Concerns
- Frame budget: bounded replay is correct. `tick_over_budget` has a problem with the shipped data (Q-4).
- Determinism: pacing never changes what is replayed by design, but the test does not prove it (S-4).
- Resource cleanup: correct by reading (S-5 for the gap).

### Story 015 — Positive Observations
- `_ended` is checked at every append site, and the order of `_pending_plan` checks after each step holds up against overflow, concede and lethal.
- Engine and subscriber time is kept out of the driver's own work, with a test that charges ten budgets per event.
- `shutdown()` on an unfinished match calls `end_match()`, which the graph needs, and the live-match `weakref` test would catch its removal.
- `test_a_poll_that_spent_the_budget_still_replays_one_command` pins a boundary that is easy to get wrong.

### Story 015 — Required Changes
None.

### Story 015 — Suggestions
- **D-1. Defect, low: a rejected replay command at the log cap appends to a sealed log.** `match_driver.gd:263-265` runs `_diverge` before `_after_engine_step`. When the engine's own `command_rejected` append is the one that overflows, `_reject` calls `fault(event_cap)`, the log seals, and `_ended` is still false. `_diverge` then appends `ai_fault` to a sealed log, which is a caller bug (`event_log.gd:164-166`, debug assert). The end state is still correct, the trigger is one exact append, and release only warns, so this does not hold the story. Fix in BAI-014: step first, or check `_engine.phase()`. VERIFIED by reading.
- **S-2. Design question, low:** every real plan ends in `end_turn` (`boss_ai.gd:578-583`), so on a real final mismatch the driver's `end_turn` is always refused and logs `command_rejected {side: boss}`. `test_a_checksum_mismatch_faults_at_the_end_and_ends_the_turn` uses a plan with no `end_turn`, which the planner cannot produce in normal play. Consider guarding on `active_side()`. The AC says submit, so this is the owner's call.
- **S-3. Test gaps:** no test shuts down with a plan pending, so removing line 199 survives (a later `tick()` would replay into a torn-down engine). Line 176: no test runs a tick with outside time followed by an over-budget tick, so a stale `_outside_usec` survives. Line 296: no test has the divergence `end_turn` end the match.
- **S-4. Test overclaims:** `test_one_seed_gives_a_byte_identical_log_however_replay_is_sliced` (`match_driver_replay_test.gd:848`) compares bytes only between two unsliced runs. The sliced run gets a types-only checksum that skips diagnostics, and nothing proves it sliced. Compare canonical logs with `tick_over_budget` removed. The header at `:9-11` says the clock is a FakeClock; line 761 uses the real one.
- **S-5. Teardown coverage:** the `weakref` tests use `FakePlannerTask`, which drops the work Callable on purpose (`fake_planner_task.gd:9-10`). The real shape, where `plan_task` captures the task, is not covered. Repeat `_graph_after` with `ImmediatePlannerTask` and the real `plan_task`.
- **S-6.** `test_a_tick_that_ends_the_match_appends_nothing_after_the_end` (`:662`) cannot fail on its assertions: without the `_ended` guard at line 309, the sealed log refuses the append anyway. Only the debug assert could catch it, and whether gdUnit reports that is not assessed. Assert on a subscriber or a counted append instead.
- **N-5. Nit:** a live-match `shutdown()` leaves `_ended` false, so a later debug `tick()` could append to the dead log. `FixtureDatabase.heroes()` has one hero, which hides a wrong-hero lookup in `_hero_set`.

### Verdict: APPROVED WITH SUGGESTIONS

---

## Design questions for the owner, before BAI-014 starts

**Q-1. `PlannerTask` lifecycle: which contract holds? (Only a defect at BAI-014, not now.)**
- Today: `_start_plan_task` (`match_driver.gd:219-222`) has no production caller, so nothing is wrong at runtime.
- At BAI-014: the second task of a match is the first boss plan, on turn 1, after the forecast. `TimeSlicedPlannerTask.start` (`time_sliced_planner_task.gd:46-50`) never clears `_done`, so `poll()` (`:57`) answers `true` at once. If that work suspends, the driver takes the **previous** `_result`, and the coroutine is stranded. `--ai-sync` and `planner_mode: time_sliced` are shipped paths.
- `WorkerPoolPlannerTask` and `ImmediatePlannerTask` survive a restart when idle, but it is out of contract. A restart while live overwrites `_task_id`.
- `FakePlannerTask.start` (`fake_planner_task.gd:39-41`) resets itself, which hides all of this from the suites.
- Story 013 says "Open for story 014", but story 014's text does not mention it.
- Options: (a) inject a factory, one object per task, which changes the ADR's four-argument call; (b) relax the contract to "one at a time" and reset `_done` and `_result` in `start`. Either way, make the fake match the decision, and have `_start_plan_task` refuse a live task. VERIFIED by reading; `qa-tester` and the specialist reached it independently.

**Q-2. A Choice raised by a replayed command: who answers it?**
Plans already carry the boss's `choose` commands (`boss_ai.gd:632-650`). But ADR-0008:230 and BAI-014 AC-3 start a choose task for a boss Choice "raised by a replayed command" whenever no task is live. `_after_engine_step()` at `match_driver.gd:266` runs in exactly that state, with the plan's own `choose` next in line. Built as written, both answer: the task draws from `ai_<floor>` a second time and breaks the byte-identical logs story 017 requires. Recommendation: the row adds "and no plan pending", and the ADR text changes.

**Q-3. What does the boss do when a task gives it no way forward?**
- `match_driver.gd:236`: a `null` result (the seam's "the work errored") or any non-plan is ignored. Story 015 hands this to story 014, and story 014 does not pick it up.
- `match_driver.gd:256-258`: an empty plan at the boss's Main stops with no `_after_engine_step()`. `test_a_plan_with_no_commands_is_done_at_once` pins that. The same applies when `_finish_replay` (`:273-279`) ends a plan that had no `end_turn`, because the last step ran while `_pending_plan` was still set.
- `_diverge` during a boss Choice: `end_turn` is refused with `CHOICE_PENDING`. BAI-014's Choice row should pick this up.
- In all of these the boss turn hangs and only concede gets out. boss-ai States says `Faulted` is "Match over" (line 323), and no code does that. Recommendation: `ai_fault` plus `end_turn`, then the step.

**Q-4. `tick_over_budget` fires on every time-sliced slice with the shipped data.**
`slice_ms` and `replay_budget_ms` are both 2 (`ai_profiles.json:189-190`, boss-ai F9). `checkpoint()` suspends only once a slice has used at least 2 ms, so every suspended `poll()` exceeds the budget at `match_driver.gd:181`. Probe A measured 2.09 to 2.11 ms. The story says "near `slice_ms`"; with this data it is every slice. Effects, debug builds only, once BAI-014 lands:
- At ADR-0006's band-3 worst case of about 2,190 ms per run, that is roughly 1,100 faults per planner run. Against the 10,000-event cap, about nine such runs end the match with `event_cap`. This is arithmetic, not a measurement, and it is a worst case.
- Story 017 AC-1 requires zero `ai_fault` of any kind with `TimeSlicedPlannerTask`, and byte-identical logs. Its runs need a stopped driver clock, which the fifth argument allows, and the story should say so.
- Options: one fault per turn, a lower `slice_ms`, or leave poll time out of the comparison for that planner.

---

## Specialist findings: disposition

| Finding | Source | Confidence | Outcome |
|---|---|---|---|
| Second `start` on one task (`match_driver.gd:221-222`) | both | VERIFIED | Q-1 |
| `FakePlannerTask` masks restart | qa-tester | VERIFIED | Q-1 |
| Sealed-log append on rejected command at the cap | qa-tester | VERIFIED | D-1 |
| Divergence during a boss Choice stalls | qa-tester | VERIFIED | Q-3 |
| Null result has no fault | qa-tester | VERIFIED | Q-3 |
| Time-sliced poll spends the whole budget | qa-tester | VERIFIED | Q-4 |
| Lines 176, 199, 296 uncovered | qa-tester | VERIFIED | S-3 |
| Tests at `:848`, `:662`, `:272`, `:341` prove less than claimed | qa-tester | VERIFIED | S-4, S-6, story 013 Testability |
| `shutdown()` may spin forever if time-sliced work errors after suspending (`:195`) | specialist | UNVERIFIED, NOT SOURCEABLE | Could not assess, below |
| Worker returns a FunctionState if the work truly suspends | specialist | UNVERIFIED | Dropped: base `checkpoint()` is a no-op and ADR-0006's erratum records all three shapes verified. It would land in Q-3 anyway. |
| Subclass members null during base `_init` | specialist (about 65%) | UNVERIFIED | Dropped: test-only, and `match_driver_gate_test.gd:108` relies on the opposite and is recorded passing |
| A `match_ended` handler dropping the driver mid-`tick` | specialist | UNVERIFIED | Dropped: the controller still holds a reference (ADR-0008 Decision 9) |
| `record.set` on a Dictionary | specialist | Not a defect | The Discover test covers the lookup |

---

## Could not assess

- **Test results.** Godot and gdUnit were not run, by instruction. Whether the suites pass, and the stories' mutation results, are their claims. `no_global_rng.sh` and the parse check were not run.
- **Worker behaviour.** No page under `docs/engine-reference/godot/` covers threading, coroutine failure or `RefCounted` teardown. **NOT SOURCEABLE:** whether `shutdown()` terminates when time-sliced work errors after suspending, and whether the pool releases its Callable after `wait_for_task_completion`. A real worker through this path is story 017.
- **Frame timing (A30)** is story 018. The Q-4 counts are arithmetic only.
- **`Time.get_ticks_usec` as a default argument** is exercised by the gate suite but asserted by nothing. Same form as `TimeSlicedPlannerTask`.
- **Whether gdUnit reports the sealed-log debug assert** as a test failure, which decides whether line 309's guard has any test at all.
- **The forecast half of story 013 AC-1**, until story 014.
- **`RunMachine` and `Boot` wiring** do not exist yet, so `driver_factory` and `match_ended`-connected-first are unassessed. The `MatchConfig` fields the driver reads do match run-structure R3 and `MatchFactory`.
