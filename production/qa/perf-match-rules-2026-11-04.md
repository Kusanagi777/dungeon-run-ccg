# Performance record: Match Rules budgets (2026-11-04)

**Story**: `production/epics/match-rules/story-018-performance-budgets.md` (AC-40, AC-40 Input Responsiveness, ADR-0005 fold guardrail); QA plan `production/qa/qa-plan-sprint-004-2026-11-04.md` § MR-018 and named case **NC-4**; code review `S8` of MR-015/017 (route the `clone()` / `submit` costs to boss-ai F7 and ADR-0006)
**Suites**: `tests/performance/match_rules/match_rules_perf_test.gd` (non-blocking: outside `commands.test` by `-i res://tests/performance`, run by the `performance` job of `.github/workflows/tests.yml`; exit 100 there is a warning) and the blocking deterministic half `tests/unit/match_rules/match_rules_hook_fold_budget_test.gd`
**Fixtures**: `tests/helpers/match_budget_fixtures.gd`: the 56-pass Deathrattle chain, the 7 v 7 full board, the 12-entry fold, and the ten `tests/fixtures/match_states/` states of story 017 replayed from `start`
**Command (debug editor, as CI runs it)**: `godot --headless -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/performance --ignoreHeadlessMode -c`
**Code**: trunk `70947a5` ("merge: sprint 4 L2 W2", which contains MR-017 `clone()`) plus this story's branch `lane/s4-l1-w3` (tests and helpers only; no `src/` change)
**Runner**: local agent container. Linux x86_64, `Intel(R) Xeon(R) Processor @ 2.10GHz`, 4 vCPU, shared. It is **not** the reference machine: AC-40 names the owner's machine. Run-to-run noise here is about ±20 % on medians.

## Verdict

| Budget | Source | Debug editor (CI build) median | Release template median | Gate (2×) | Result |
|---|---|---|---|---|---|
| `submit()` worst case, 56-pass Deathrattle chain | GDD Input Responsiveness 5 ms; ADR-0007 | **25.1 ms** (p95 33.3, max 42.7) | **19.9 ms** (p95 26.6, max 35.5) | 10 ms | **MISSED**: 5.0× budget (debug) and 4.0× (release); the 2× gate fails on both builds |
| `legal_commands()`, full board (94 commands) | GDD 2 ms; ADR-0007 | 0.64 ms (p95 0.70, max 0.72) | 0.56 ms (p95 0.72, max 1.27) | 4 ms | within budget (≈ 30 %); identical list on all 100 calls |
| `hooks.fold`, 12 `modify_damage` entries | ADR-0005 Decision 4: < 0.05 ms | 22 µs (p95 31, max 62; block mean 23.0 µs) | 16 µs (p95 25, max 79) | 100 µs | within budget (≈ 45 %) |
| `clone()` + one `submit` per planner node (`t_sim`), median over 12 states | boss-ai F7 assumes 0.01 ms | **450 µs** | **365 µs** | 16.7 µs (band-3 share × 2) | **MISSED**: 36–45× F7's assumption; no band's F7 count fits `planner_target_ms` |

The Logic evidence passes. The blocking unit file has 8 tests, all deterministic, and each was seen failing under a mutation (list below). **AC-40's submit criterion fails**, so the story is not closed (story Completion Notes). The performance job reports this as a warning (exit 100), as designed.

## AC-40: worst-case `submit`

The fixture has 7 boss "chain" minions. Each one's Deathrattle summons a token carrying the same Deathrattle one generation lower, then deals 1 damage to every minion on both boards. They face 7 player walls (2/100). The player plays a 0-cost nova that deals 1 to each enemy minion. One `submit` then resolves **56 Deathrattle passes** (7 × (7 + 1)), well under `resolution_step_cap` 1000, with no fault, and the boards settle at 7 v 0 (asserted in the blocking suite). The action emits **669 events**: 448 `damage_dealt`, 56 `minion_died`, 56 `trigger_queued`, 56 `trigger_resolved`, 49 `minion_summoned`, and the play's own events. Each of the 100 samples times only `sandbox.submit(cmd)`, on a fresh `clone()` of the same live match.

```
PERF match_rules submit deathrattle_chain(56 passes) x100: median 25065 us, p95 33253 us, max 42737 us (budget 5000 us, gate 10000 us)
```

**What the number includes.** It includes the engine and the scripted resolver double (`TestEffectResolver`, `recording = false`). The double was given a per-source trigger index for this story; the answers and their order are unchanged. Before the index, the double's linear scan over candidates × triggers alone made this sample 75 ms. With the index, the double's remaining cost is mostly its `on_damage` resolve: about 6 ms of an instrumented 26 ms run. So the engine alone is still about 18–20 ms on the debug build, 3.5–4× the budget. **The production `EffectResolver` was not measured.** Its per-candidate effect lookup may cost more or less than the double's.

## AC-40 Input Responsiveness: `legal_commands()`

The fixture is 7 v 7 with every player minion ready and the leftmost one Windfury. The hand holds 10 cards: two `required`-target spells (16 targets each), four minions (absent from the list because the board is full), two untargeted spells, a weapon and the nova. The hero power is affordable and unused. That gives 94 commands: 56 attacks, 36 plays, 1 power and `end_turn`. The composition is asserted in the blocking suite. The resolver's targeting memo is warmed by one call before the samples.

```
PERF match_rules legal_commands full_board(94 commands) x100: median 638 us, p95 701 us, max 715 us (budget 2000 us, gate 4000 us)
```

## ADR-0005: 12-entry fold

There are three treasures and the boss passive, with three `modify_damage` `delta +1` entries each (`HookRegistry.DEBUG_MAX_ENTRIES`). The evaluator is the double's `apply_value_hook` with recording off, and the production evaluator was not measured. The first run of this test was vacuous: the registry's evaluator Callables do not keep the resolver alive, so a resolver freed before the loop made every fold a no-op, which printed as 0.19 µs. The test now holds the resolver and asserts that the fold returns 12.

```
PERF match_rules hooks.fold modify_damage(12 entries) x1000: median 22 us, p95 31 us, max 62 us (budget 50.0 us, gate 100.0 us)
PERF match_rules hooks.fold modify_damage(12 entries) block mean: 23.03 us over 1000 folds (budget 50.0 us)
```

Per-call samples sit near the timer's 1 µs resolution. The block mean is the steadier figure.

## `clone()` and the Boss AI planner budget (boss-ai F7, ADR-0006; review S8)

**F7's assumption**: `planner_time ≈ (actions · evals + lethal_nodes) · t_sim`, with `t_sim = clone + one submit ≈ 0.01 ms`. F7's worked example uses 8 actions. The band-3 worst case is `(8 · 250 + 4000) · 0.01 ms ≈ 60 ms` against `planner_target_ms` 50, which is per boss turn and p95 (ADR-0006 Performance; A22 measures one `forecast` plus one `play_turn` per round, about 2× a turn).

**Measured**: for each state, 100 × (`clone()` timed, then the state's first `legal_commands()` entry submitted on the clone and timed, then `end_match()`). Times are in µs.

| State | Command | Debug editor `clone` median / p95 | Debug editor clone+submit median / p95 | Release `clone` median / p95 | Release clone+submit median / p95 |
|---|---|---|---|---|---|
| 01 mulligan | mulligan | 145 / 243 | 410 / 471 | 78 / 105 | 292 / 330 |
| 02 early_main | play_card | 140 / 175 | 450 / 518 | 72 / 93 | 293 / 346 |
| 03 full_boards | play_card | 189 / 395 | 879 / 1583 | 104 / 130 | 539 / 651 |
| 04 choice_pending | choose | 112 / 240 | 261 / 360 | 75 / 99 | 202 / 245 |
| 05 taunt_stealth | play_card | 105 / 184 | 452 / 612 | 81 / 116 | 365 / 489 |
| 06 empty_decks | use_hero_power | 58 / 86 | 200 / 244 | 57 / 76 | 200 / 242 |
| 07 frozen_hero | play_card | 99 / 150 | 334 / 479 | 94 / 122 | 350 / 402 |
| 08 weapon_equipped | play_card | 232 / 332 | 329 / 378 | 92 / 121 | 343 / 391 |
| 09 boss_main | play_card | 252 / 324 | 385 / 453 | 97 / 123 | 403 / 526 |
| 10 late_game | attack | 169 / 323 | 561 / 652 | 132 / 207 | 592 / 855 |
| budget full board | play_card | 168 / 247 | 652 / 726 | 153 / 223 | 781 / 958 |
| budget chain (56 passes) | play_card | 920 / 1148 | 24149 / 27528 | 555 / 947 | 17700 / 29941 |
| **median of state medians (`t_sim`)** | | | **450** | | **365** |

The debug `clone` column comes from the first suite run of the day and the clone+submit column from the recorded run. The two runs agree within noise. A clone taken right after a heavy `submit` (the chain rows) costs 3–5× a clone taken in a quiet loop (180 µs there). Allocator state is the likely cause; it was not investigated.

**Where the clone time goes**: `MatchState.clone` (mostly `players.duplicate(true)`) is about 87 µs of a 130–180 µs debug clone. The rest is the resolver's `clone_unbound` (the double), the scratch `EventLog` and the O(draws) stream copy (review S7). `clone()` is 15–35 % of a node. Most of a node's cost is `submit`.

**Node budget implied by `planner_target_ms` 50** (the same for every band, because the target does not change with band):

| Band | F7 counts (`ai_profiles.json`) | F7 nodes per turn (8 · evals + lethal) | Turn time at release `t_sim` 365 µs | Over budget | Scale factor to fit |
|---|---|---|---|---|---|
| 1 | evals 40, lethal 50 | 370 | 135 ms | 2.7× | × 0.37 |
| 2 | evals 120, lethal 500 | 1,460 | 533 ms | 10.7× | × 0.094 |
| 3 | evals 250, lethal 4000 | 6,000 | 2,190 ms | 44× | × 0.023 |

At the measured cost, **about 137 nodes per turn fit** on the release template (111 on the debug editor). Per round, with one forecast and one turn, that is about 68 (55). Scaling each band's counts by its factor gives an illustration, not a proposal: band 1 evals ≈ 15 / lethal ≈ 18, band 2 ≈ 11 / 47, band 3 ≈ 6 / 91. Halve those per round. Lowering `lethal_max_nodes` alone (F7's "first knob") cannot fit band 3: its `8 · 250` evaluation term is 2,000 nodes, 730 ms, before any lethal search. **`clone()` does not fit F7's budget either**: on its own, at 72–153 µs (release), it is 9–18× the band-3 per-node share of 8.3 µs.

## Hot spots (instrumented, debug editor; subclass timers, so the absolute values are inflated)

1. **`_recompute_auras` once per C10 drain iteration**: two `_stat_map` passes (attack, health and max health of every character, with a fresh Array per character) plus an aura strip over every character, the weapon and the hand. One attack `submit` took 485–640 µs, and 290–405 µs of that, about 60–70 %, was this function's four calls. The chain makes 61 calls.
2. **The per-damage-event path in a chain** (448 events): the `on_damage` raise (candidate list plus resolver), `emit`, and linear `_find_record` / `_character` lookups across the zones. In the instrumented chain run, `_find_record` took ≈ 2.4 ms over 462 calls and `_candidates_in_order` ≈ 2.2 ms over 555 calls; the story's Implementation Notes expected the second.
3. The death check and `_enqueue` (a `duplicate(true)` snapshot per queued trigger).
4. `clone()`: `players.duplicate(true)`, then the stream replay.

## Recommendations (not implemented: the story touches tests and the record only; owners named)

- **R1 (`/perf-profile`, then a match-rules story; gameplay-programmer).** In `_recompute_auras`, skip both `_stat_map` passes when the strip removed nothing and the resolver applied no `is_aura` enchantment, using a counter in `apply_enchantment` while `_recomputing_auras` is set. This should be the largest single win for a plain command (about −60 % on an attack). It is semantics-preserving only if the resolver's aura pass applies nothing else. The test double's `aura_scripts` can call any primitive, so the change needs a test of its own.
- **R2.** Keep an `entity_id → location` index (zone and side; no derived values, so C1 holds) for `_find_record`, `_live_record` and `_character`, maintained by the zone moves.
- **R3.** Reuse one candidate buffer per drain iteration instead of a new `Array[int]` per trigger point.
- **R4 (cheaper clone).** Use `RngStream.copy()` (review S7) instead of the O(draws) replay, and avoid deep-copying data that never changes once created (keyword arrays from definitions, the graveyard). Even a 2× faster clone leaves `t_sim` dominated by `submit`.
- **R5 (design: game-designer and ai-programmer, then `/propagate-design-change` boss-ai F7 → ADR-0006).** Re-derive `t_sim` from these numbers, about 0.35–0.45 ms on this container, not 0.01 ms. Then do one or more of these: re-budget `max_evals_per_action` and `lethal_max_nodes` per band (table above), let the `op_value` prefilter decide more before anything is simulated, change the planner to do/undo moves on one sandbox instead of a clone per node, or raise `planner_target_ms`. Do this before BAI-004/005 tune weights against the current counts. BAI story 016's A22 will fail by 3–44× as specified.
- **R6 (owner decision).** Decide whether 5 ms is realistic in GDScript for a 56-pass, 669-event chain. Even if R1–R3 each roughly halved their share, the chain would likely sit at about 8–12 ms on this container. Measure on the reference machine first, since a fast desktop core may be 1.5–2× this container.

## NC-4: event-log append budget (sprint-3 observation, beside these numbers)

| Run | Build | `append ×10,000 + events_since(0)` | Budget |
|---|---|---|---|
| This container, today's `performance` run | debug editor | 39.4 ms | 50 ms |
| This container, three release-template runs | release | 43.1, 64.8, 60.5 ms | 50 ms |
| Sprint 3 (smoke report 2026-11-04) | CI, debug | 33–47 ms; local 51–60 ms | 50 ms |

**The release build does not make the append budget safe**: two of the three release runs missed. The owner's W1 decision (sprint-004 plan: raise the budget, or optimise after a release-build measurement) is **not recorded on this branch**. This row is the release-build measurement that decision was waiting for.

## How the release figures were taken

The release figures come from a throwaway copy of the project in the session scratchpad (`l1_release/`). It had an added Linux export preset, a `Node` bench that mirrors the perf suite (same fixtures, same windows, same sample counts) set as the main scene, and `--export-pack` from the editor. It ran on `linux_release.x86_64` 4.7.2 (`OS.is_debug_build() == false`); `linux_debug.x86_64` gave numbers within noise of release. Nothing of this is in the repository. The export template refuses `--main-pack` / `-s` path overrides, so a perf scene in an exported build is the way to repeat it.

## Not yet recorded

- **CI (`performance` job)**: not run, because the lane does not push. After the merge, read the `PERF match_rules …` lines in the job summary and add a row here. Expect exit 100 (two failures: the submit gate and the node-cost gate), reported as a warning.
- **Reference machine (owner's)**: not run. AC-40's verdict should be taken there before any budget changes.
- **Production `EffectResolver`**: not measured. These numbers are the engine plus the scripted double.

## Watched failing

- Blocking unit file (one mutation per run, each restored):
  - `DEBUG_MAX_ENTRIES` 12 → 13: the four ADR-0005 tests fail.
  - `HookRegistry.copy()` drops an entry: the clone test fails.
  - Chain generations 7 → 5 (42 passes): the ≥ 50-pass test fails.
  - `legal_commands()` omits `end_turn` on some calls: the identity test fails.
  - Hero power never listed: the composition test fails.
  - The fold skips its first entry: the evaluator-count test fails.
  - `MatchState.clone` shares `players`: the fresh-clone chain test fails.
- Perf suite: the submit and node-cost gates fail against the real code (this record). The `legal_commands` and fold gates have not been seen failing; the fold test's vacuous first run is now guarded by a value assertion.
