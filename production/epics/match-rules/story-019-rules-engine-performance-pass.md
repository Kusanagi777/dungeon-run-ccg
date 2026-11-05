# Story 019: Rules engine performance pass

> **Epic**: Match Rules
> **Status**: In Progress
> **Layer**: Core
> **Type**: Logic
> **Estimate**: L (several days: four engine changes, two new blocking suites and golden logs, a release-template re-measure)
> **Manifest Version**: 2026-11-04
> **Last Updated**: 2026-11-04
> **Sprint**: candidate for sprint 5. Not in sprint 4.

## Context

**GDD**: `design/gdd/match-rules.md` (Game Feel: Input Responsiveness table; C10 loop; Acceptance Criteria AC-38 and AC-40); `design/gdd/boss-ai.md` F7 (read-only here: it is the source of the node-cost target)
**Requirement**: `TR-match-rules-008`, also `TR-match-rules-003` (`clone()`) and `TR-match-rules-006` (the C10 loop, unchanged in behaviour)
*(Requirement text lives in `docs/architecture/tr-registry.yaml`. Read it fresh at review time.)*

**ADR Governing Implementation**: ADR-0007: Effect Resolver / Validator Boundary (Performance Implications: `submit()` ≤ 5 ms worst case including resolver passes; `clone()` + empty memo per look-ahead node against `planner_target_ms` 500 p95 per planner run — was 50, 2026-11-04, DD-X18). Also ADR-0006: Boss AI Planner Threading (Constraints and Performance: a 500 ms p95 target per planner run, `play_turn` and `forecast` each, a count-tuning target and not a runtime switch — was 50 ms per turn, 2026-11-04, DD-X18); ADR-0003: Seeded RNG Service and Event Log (Decision 3 and Alternative 3: a stream is copied by reseed-and-discard); ADR-0005: Owner-scoped hook registry (no allocation in the fold; `copy()` by value).
**ADR Decision Summary**: `RulesEngine` owns `MatchState`, the primitives, candidate order and the C10 loop (death check, then `recompute_auras()`, then queue pop). The resolver writes only through primitives, and one effect pass is one C10 step. The engine budget is ≤ 5 ms for a worst-case `submit` and ≤ 2 ms for `legal_commands()`. `clone()` deep-copies state, hooks and a scratch log and binds a fresh resolver. Its per-node cost is measured against the planner's 500 ms p95 per planner run (was 50 ms — 2026-11-04, DD-X18).
**ADR Version**: 2026-11-03 (ADR-0007; ADR-0006, ADR-0003 and ADR-0005 are also 2026-11-03)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: HIGH by version (ADR-0007 Engine Compatibility), but the APIs used here (`RefCounted`, `Dictionary`, `Array`, `duplicate`, `is_same`, `Time.get_ticks_usec`) predate 4.3 and no post-cutoff change is listed for them. `NOT SOURCEABLE`: `docs/engine-reference/godot/` documents no allocation monitor for `Array` or `Dictionary`. Allocation budgets are therefore counted at their allocation sites in the engine, not read from `Performance`. Wall-clock numbers from the shared CI runner are indicative only; the targets are judged on the release template and on the reference machine.

Story 018 built the timing harness and found two budgets missed: the worst-case `submit` is 25.1 ms debug / 19.9 ms release (AC-40 asks for 5 ms), and `clone()` + one `submit` is 365–450 µs against boss-ai F7's assumed 10 µs (`production/qa/perf-match-rules-2026-11-04.md`; code reviews MR-015/017 S8 and BAI-004/006 S6, which measured 0.4–1.3 ms per Boss AI candidate). This story makes the engine changes ranked R1–R4 in that record. Rules behaviour must not change, so the event logs stay byte-identical. It does not change any budget or any boss-ai count.

**Control Manifest Rules (Core layer, v2026-11-04)**:
- Required: `RulesEngine` owns the C10 loop (death check → `recompute_auras()` → queue pop) and `RESOLUTION_STEP_CAP`, and fires trigger points with `ctx.candidates` already in engine order (ADR-0007).
- Required: the `clone()` contract. It deep-copies `MatchState`, including `state.effects`, `suspended_queue` and `state.hooks.copy()`. It binds a fresh resolver with no installers, sets `rng_match = RngStream.copy()` of the live stream and gives the clone a detached scratch log. Every clone is ended with `end_match()` on every path (ADR-0007 Decision 3, ADR-0006).
- Forbidden: never call the death check or `recompute_auras()` between ops; never let the resolver own the loop or the queue (ADR-0007).
- Forbidden: never allocate in the fold; never fork `rng_match` on a clone; never drop a clone without `end_match()`; `tests/unit/**` never starts a worker (ADR-0005, ADR-0003, ADR-0006).
- Guardrail: `submit()` ≤ 5 ms worst case (Deathrattle chain, resolver passes included); `legal_commands()` ≤ 2 ms; a 12-entry fold < 0.05 ms, with `copy()` ≤ 12 small `duplicate(true)` calls per clone; `clone()` + empty resolver memo per look-ahead node against `planner_target_ms` 500 p95 per planner run (was 50 — 2026-11-04, DD-X18) (ADR-0007, ADR-0005).
- GDD C1 (story 018 Implementation Notes): never fix a cost by caching derived values on the records.

---

## Scope: R1–R6 in priority order

| # | Recommendation (perf record) | In this story |
|---|---|---|
| **R1** | `_recompute_auras`: skip both `_stat_map` passes when the strip removed no `is_aura` enchantment **and** no primitive ran during `resolver.recompute_auras()`. This is about 60 % of a plain command. | **Core** |
| **R2** | An `entity_id → {side, zone}` location index for `_find_record`, `_live_record` and `_character`, kept up to date by the zone moves. It holds no derived values, so C1 holds. | **Core** |
| **R3** | One reused candidate buffer per drain iteration instead of a new `Array[int]` per trigger point. | **Core** (small) |
| **R4** | A cheaper `clone()`: do not deep-copy data that is never mutated once created. The `RngStream` copy is unchanged (see Out of Scope). | **Stretch**. Headroom for AC-4, no longer a precondition (2026-11-04, DD-X18): AC-4's target is now 340 µs, a ≈ 7 % cut from today's 365 µs, and `clone()` alone (72–153 µs on release) is under half of it. R1 (≈ 60 % of a plain command's `submit`) is expected to carry AC-4; R4 matters if R1–R3 land short. |
| **R5** | Re-derive boss-ai F7 `t_sim` and re-budget the band counts. | **Not this story.** It is the follow-up below. |
| **R6** | Decide whether 5 ms is realistic in GDScript for the 56-pass chain. | **Not this story.** The owner decides it only if AC-3 still misses after R1–R4 (see Close rule). |

---

## Acceptance Criteria

*From GDD `design/gdd/match-rules.md` (AC-38, AC-40, Input Responsiveness) and boss-ai F7 / A22, scoped to this story. AC-1 and AC-2 are deterministic and run in the blocking suite. AC-3 and AC-4 are wall-clock targets that run only in `tests/performance/match_rules/`, the non-blocking `performance` job.*

- [ ] **AC-1: Op-count and allocation-count budgets (blocking, `tests/unit/match_rules/match_rules_op_budget_test.gd`).**
  - **GIVEN** the story-018 fixtures (`tests/helpers/match_budget_fixtures.gd`), with the engine's diagnostic counters reset before the measured `submit`.
  - **WHEN** the 56-pass Deathrattle chain `submit` runs once.
  - **THEN** `recompute_calls == drain_iterations` (the C10 loop shape is unchanged; 61 today).
  - **THEN, R1:** `stat_map_passes == 0`. The fixture has no aura source; today the count is 122, two per recompute.
  - **THEN, R2:** `record_visits ≤ record_lookups`. Each lookup touches one record; today `_find_record` alone makes 462 calls, each a linear scan across the zones.
  - **THEN, R3:** `candidate_buffers ≤ drain_iterations + 1`. Today `_candidates_in_order` makes 555 calls, each allocating.
  - **AND GIVEN** a new aura fixture (one aura source on the board), **THEN** each recompute that strips an aura or runs a primitive makes ≤ 2 `stat_map_passes`, and every other recompute makes 0.
  - Each budget is a named test constant that cites its source. Each assertion has been seen failing with its optimisation reverted.
- [ ] **AC-2: Behaviour identical (blocking).**
  - **GIVEN** golden event logs recorded on the **unchanged** engine, before any `src/` edit and in a commit of their own. They cover: the chain `submit`; the full-board `legal_commands()` list; every legal command of the 10 `tests/fixtures/match_states/` states, each submitted on a fresh clone; and the 200-command scripted match of AC-38.
  - **WHEN** the same inputs run on the changed engine.
  - **THEN** each event log, `legal_commands()` list, `state_snapshot()` and `MatchResult` is byte-identical to its golden file.
  - **AND** the full suite is green, including AC-38 (`test_a_200_command_match_replays_byte_identical_with_an_equal_result`) and every story-017 isolation test in `match_rules_clone_replay_test.gd`.
  - **AND** R1 has a test of its own: an `aura_scripts` entry in the test double that calls a non-enchantment primitive during the aura pass still produces the same `auras_recomputed` payload as the golden log.
  - **AND** if R4 lands: a no-alias walk shows that every container the engine mutates is not `is_same` between the clone and the live state. The containers shared by reference are exactly the immutable set listed in `MatchState.clone`'s doc comment.
- [ ] **AC-3: Worst-case `submit` (performance job; AC-40).**
  - **GIVEN** the 56-pass chain, with a fresh `clone()` per sample.
  - **WHEN** `submit` is timed over 100 samples.
  - **THEN** the median is ≤ 5 ms (the target, `SUBMIT_BUDGET_USEC`). Above 10 ms (2×) the job fails.
  - **AND** `legal_commands()` (full board) stays ≤ 2 ms and the 12-entry fold stays < 0.05 ms, so neither regresses.
  - Median, p95 and max are printed. They are recorded in `production/qa/perf-match-rules-<date>.md` for the debug editor and the release template, and on the reference machine when it is available.
- [ ] **AC-4: Planner node cost `t_sim` = `clone()` + one `submit` (performance job; boss-ai F7, A22).**
  - **GIVEN** the 12 fixture states of `test_clone_and_one_command_node_cost_per_fixture_state_against_the_f7_planner_budget`.
  - **WHEN** `clone()` plus one `submit` is timed over 100 samples per state.
  - **THEN** the median of the state medians is ≤ **340 µs** on the release template. Above 680 µs (2×) the job fails.
  - **The arithmetic (retargeted 2026-11-04, DD-X18; was ≤ 67 µs = 50 ms / 740 nodes per round):**
    - DD-X18 sets `planner_target_ms` to 500 ms **per planner run**; A22 measures `play_turn` and `forecast` separately, so there is no per-round 2× factor.
    - Band-2 F7 nodes per run = 8 actions × `max_evals_per_action` 120 + `lethal_max_nodes` 500 = 1,460.
    - 500 ms / 1,460 = 342.5 µs per node. The target is 340 µs (1,460 × 340 µs = 496 ms).
    - Band 1 (370 nodes) already fits: 370 × 365 µs ≈ 135 ms.
    - Today's release figure is 365 µs, so this needs a ≈ 7 % cut (1.07×).
    - Band 3 (6,000 nodes, ≈ 2,190 ms at 365 µs; it would need ≈ 83 µs) is **not** targeted here: boss-ai F7 lowers band 3's counts after the follow-up re-measure, until A22 passes.
  - The perf test's gate band changes from 3 to 2, per planner run (no per-round factor), and the test prints all three bands as it does now.

**Close rule.** AC-1 and AC-2 close the implementation. If AC-3 or AC-4 still misses after R1–R4, `/story-done` records the measured figures and returns BLOCKED, as story 018 did. The fix is not widened inside this story. Instead, R6 (the owner re-budgets the 5 ms) and the follow-up below decide. R6 already expects the chain at about 8–12 ms after R1–R3. Against the DD-X18 target of 340 µs (2026-11-04), AC-4 is expected to pass after R1 alone: it asks for a ≈ 7 % cut and R1 removes about 60 % of a plain command; the perf record's warning that `submit` dominates a node now bears on band 3, which is re-budgeted by counts, not by this story.

---

## Implementation Notes

*Derived from ADR-0007 Implementation Guidelines and Performance Implications, ADR-0003 Decision 3, ADR-0005 and the perf record:*

- **Order of work.**
  1. Record the golden logs and the baseline counter values on the unchanged engine, in their own commit, and write the baselines into this story.
  2. Make R1, re-measure and commit.
  3. Then R2, then R3, then R4 (stretch), each measured on its own. Each step keeps AC-2 green.
- **Counters.** Plain ints owned by `RulesEngine`, exposed as `op_counts() -> Dictionary` (a copy) and `reset_op_counts()`. They are diagnostics. Rules logic never reads them, they are not in `MatchState`, and `state_snapshot()` and the log are unchanged. A clone starts at zero.
- **R1.** Stats can change only if the strip removed something or the resolver ran **any** primitive while `_recomputing_auras` was set. The test double's `aura_scripts` can call any primitive, so counting only `is_aura` applications is not enough. `before` must be the stats before the strip. Either take it lazily before the first mutation, or check for `is_aura` before stripping. Hand `cost_modifiers` are still stripped and re-applied as they are now. The event rule is unchanged: no `auras_recomputed` event when the net changes are empty.
- **R2.** The index is engine-side transient data, rebuilt in `clone()` (O(entities)) and updated by every zone move: summon, death, draw, play, bounce, discard, equip and destroy. It is not in `MatchState`, so C1, the snapshot and the clone contract are untouched. A debug assertion checks a lookup against the linear scan.
- **R3.** Reuse the allocation and refill it when the zones changed. The resolver reads `ctx.candidates` and never re-sorts it (ADR-0007). If any resolver path retains the array, the buffer must be copied for that path. AC-2's golden logs catch an aliasing divergence.
- **R4.** Only data that is never mutated after creation may be shared: graveyard entries (append-only; the array itself is still copied) and definition-derived arrays that no primitive writes. Check each against Silence and keyword grants before sharing it. `HookRegistry.copy()` stays by value (ADR-0005). Every shared field is listed in `MatchState.clone`'s doc comment.
- **Measuring.** The double stays `recording = false` in timed calls. Release-template figures use the scratch-export method in the perf record ("How the release figures were taken"). Nothing of it goes into the repository.

---

## Out of Scope

*Handled elsewhere. Do not implement here:*

- **R5, the follow-up below**: boss-ai F7 counts. (F7's `t_sim`, `planner_target_ms` and ADR-0006's budget text were already updated by DD-X18 on 2026-11-04.)
- **R6**: the owner's decision on the 5 ms budget.
- **An O(1) `RngStream.copy()`**: rng-event-log owns `src/core/rng/rng_stream.gd`. ADR-0003 Alternative 3 allows an in-memory state copy only with a test proving identical next outputs. Raise it as an rng-event-log story if R4 measurements show the stream copy matters. It is ≈ 30–40 µs at ≤ 300 draws (review S8).
- **Hot spot 3** (`_enqueue`'s `duplicate(true)` snapshot per queued trigger): not ranked in R1–R6. Re-rank it after this story's re-measure.
- **The boss-ai scorer's own costs** (BAI review S6: hoist `_measure`, reuse the candidate list): boss-ai-match-driver.
- **Measuring the production `EffectResolver`**: card-effects. The harness measures the engine plus the scripted double, as in story 018.
- **NC-4, the event-log append budget**: the rng-event-log owner's W1 decision.

---

## Follow-up (a separate step after this story, not part of it)

1. Re-measure: run the CI `performance` job and the release template (and the reference machine when available), and write a new `production/qa/perf-match-rules-<date>.md`. Story 018's AC-40 row is re-taken from it.
2. (Revised 2026-11-04, DD-X18.) F7 already carries the measured `t_sim` (~0.37 ms release / ~0.45 ms debug) and the 500 ms per-run target. After re-measuring, update F7's `t_sim` to the new figure and re-budget the counts against 500 ms per run: band 3's `max_evals_per_action` and `lethal_max_nodes` are lowered until A22 passes (≈ 2,190 ms today), and band 2's too if AC-4 missed 340 µs. Consider the `op_value` prefilter or do/undo on one sandbox, as the design owners choose. Then run `/propagate-design-change design/gdd/boss-ai.md` on the F7 counts and resolve the ADR rows it flags. This must happen before BAI-004/005 tune weights against the current counts.

---

## Files

*The code and test files this story is planned to create or change. `/dev-story` replaces the list with the files it changed, and `/story-done` checks scope against it.*

- `src/gameplay/match/rules_engine.gd` (R1–R3, the location index, the diagnostic counters)
- `src/gameplay/match/match_state.gd` (R4, stretch: `clone()` and its doc comment)
- `tests/unit/match_rules/match_rules_op_budget_test.gd` (new: AC-1, the R1 aura-primitive test, the R4 no-alias walk)
- `tests/unit/match_rules/match_rules_golden_log_test.gd` (new: AC-2 golden comparisons)
- `tests/fixtures/match_rules/golden_logs/` (new: recorded on the unchanged engine, committed before any `src/` edit)
- `tests/helpers/match_budget_fixtures.gd` (additive: the aura fixture)
- `tests/performance/match_rules/match_rules_perf_test.gd` (AC-4 gate on band 2 per planner run — was band 1 per round, 2026-11-04, DD-X18; target and gate printed)
- `tests/README.md` (new suites, golden-log rule)
- `production/qa/perf-match-rules-<date>.md` (new record)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`. At `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/match_rules/match_rules_op_budget_test.gd` and `tests/unit/match_rules/match_rules_golden_log_test.gd` must exist and pass. `/story-done` checks that they exist; pass or fail is established by `/gate-check` and `/smoke-check`, both later. At `qa.level: standard` this is BLOCKING.
- AC-3 and AC-4: recorded medians in `production/qa/perf-match-rules-<date>.md`, judged against the targets (not the 2× gate) on the release template.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/match-rules/story-017-clone-and-replay.md` (Complete); `production/epics/match-rules/story-018-performance-budgets.md` (its harness and fixtures are in the tree; the story stays In Progress until its AC-40 is re-taken)
- Unlocks: `production/epics/match-rules/story-018-performance-budgets.md` (AC-40 re-measure); the boss-ai F7 `/propagate-design-change` follow-up (before weight tuning in `production/epics/boss-ai-match-driver/story-004-scorer-features-and-board-value.md` and `production/epics/boss-ai-match-driver/story-005-candidates-hero-power-rule-and-positions.md`)

---

## Readiness (2026-11-04, `/story-readiness` read by hand)

**Verdict: READY** (tier `workflow: full`). ADR-0003/0005/0006/0007 Accepted; Manifest Version 2026-11-04 matches the manifest; TR-match-rules-003, -006 and -008 active; dependencies 017 Complete and 018's harness and fixtures in the tree; 4 criteria, each observable; Out of Scope stated; no open markers. QL-STORY-READY skipped: Lean mode.

Three things this story text predates, settled here (a `DD-X` row wins, then the GDD, then the story):
- **Perf files.** Wave 1 split the gates: submit, legal and fold moved to `match_rules_{submit,legal_commands,fold}_perf_test.gd`, and `match_rules_perf_test.gd` keeps the planner gate. AC-3 and AC-4 follow the code.
- **AC-4's data source.** `runtime.planner_target_ms` in `assets/data/ai_profiles.json`, not the design registry a Godot test cannot read (QA plan MR-019 Gap, NC-8).
- **Release figures.** No export template is installed on this machine and none is to be downloaded, so AC-3 and AC-4 are measured on the debug binary and every release figure is NOT ASSESSED until the owner re-measures after M2.

## Baseline counters (2026-11-04, the 56-pass chain `submit`, counters reset before it)

Read on the unchanged engine plus the diagnostic counters alone (`4d2b046`, then the counter commit), whose goldens all stayed byte-identical:

| Counter | Baseline | Budget (AC-1) |
|---|---|---|
| `drain_iterations` | 61 | n/a |
| `recompute_calls` | 61 | equal to `drain_iterations` |
| `stat_map_passes` | 122 | 0 |
| `record_lookups` | 917 | n/a |
| `record_visits` | 13,944 | at most `record_lookups` |
| `candidate_buffers` | 555 | at most `drain_iterations` + 1 |
