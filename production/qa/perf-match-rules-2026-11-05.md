# Performance record: rules engine performance pass (2026-11-05)

**Story**: `production/epics/match-rules/story-019-rules-engine-performance-pass.md` (AC-3, AC-4; R1 to R4 of `production/qa/perf-match-rules-2026-11-04.md`)
**Suites**: `tests/performance/match_rules/`: one gate per suite (`match_rules_submit_perf_test.gd`, `match_rules_legal_commands_perf_test.gd`, `match_rules_fold_perf_test.gd`, `match_rules_perf_test.gd`)
**Code**: lane `s5/l6-w2`, from trunk `6694a41`. Steps: `4d2b046` goldens, `05aa6d2` counters, `7be107f` R1, `f7a4912` R2, `4596f34` R3
**Runner**: the owner's Windows 11 machine, Godot 4.7.2 **debug** editor binary, with six other lanes running their suites on it. It is shared and loaded, so every absolute figure below is **provisional**. The owner re-measures on a quiet machine after M2.

## Verdict

| Budget | Source | Debug binary, loaded: median | Release template | Target / gate | Result |
|---|---|---|---|---|---|
| `submit()` worst case, 56-pass chain (AC-3) | GDD 5 ms; ADR-0007 | **13.3 ms** (p95 14.0, max 14.4) | NOT ASSESSED | 5 ms / 10 ms | **MISSED on debug**: 2.7× the target, and over the 2× gate. Goes to the owner as R6 |
| `legal_commands()`, full board (AC-3) | GDD 2 ms | 0.52 ms (p95 0.62, max 0.94) | NOT ASSESSED | 2 ms / 4 ms | Within budget on debug, no regression |
| `hooks.fold`, 12 entries (AC-3) | ADR-0005 < 0.05 ms | 19 µs (p95 21, max 31) | NOT ASSESSED | 50 µs / 100 µs | Within budget on debug, no regression |
| `t_sim` = `clone()` + one `submit` (AC-4) | boss-ai F7, DD-X18 | **273 µs** | NOT ASSESSED | 340 µs / 680 µs | **Under target on debug.** AC-4 is judged on the release template, so its verdict is open |

**No release figure exists.** No export template is installed on this machine and none was downloaded. The 2026-11-04 record found debug 1.2× to 1.3× release, but that was another machine and code base, so no release number is inferred here.

The `performance` job will exit 100 on one suite, the submit gate. That is expected until R6.

## What each step bought

Each row is one interleaved A/B: the two builds run alternately, so both see the same load, and the figure is the median of the runs. Run them again and expect drift: a same-code A/A run on this load moved `t_sim` by 9 % at 3 rounds, and the chain, `clone` and `legal_commands` by 2 to 4 %. Small deltas below are not findings.

| Step | Runs | Chain `submit` before → after | `t_sim` before → after | Reading |
|---|---|---|---|---|
| R1, aura stat passes | 7 | 20.8 → 16.8 ms (0.81×) | 576 → 278 µs (0.48×) | The whole of the planner win |
| R2, location index | 7 | 16.4 → 14.7 ms (0.90×) | 267 → 273 µs (1.02×) | Chain only. `t_sim` is flat, inside the noise |
| R3, candidate buffers | 7 | 14.4 → 13.6 ms (0.94×) | 277 → 275 µs (0.99×) | Chain only. `t_sim` is flat, inside the noise |
| R4, cheaper `clone()` | n/a | not landed | not landed | See below |
| **All, against the counter build** | 9 | **20.1 → 13.8 ms (0.69×)** | **573 → 278 µs (0.49×)** | `clone` 102 → 99 µs, `legal_commands` 530 → 530 µs |

The story expected about 60 % off a plain command from R1, and it delivered 52 %. R6's forecast of 8 to 12 ms after R1 to R3 was for another machine; this one lands at 13.3 ms under load.

**Counts are not time, twice over.** Both first cuts met their AC-1 budget and bought nothing, which only the A/B showed:
- R2's first `_locate` cut visits from 13,944 to 917 and left the chain at 1.01×: a `{}` default, a nested call and a String-keyed zone read cost a hit as much as the scan (2.3 µs, against 0.8 µs flat). A hero lookup had got 3.5× slower.
- R3's first buffer cut allocations from 555 to 1 and came out at 1.04×: refilling on every raise cost more than the allocation it saved. Refilling only when a candidate moved gave 0.94×.

## The op counts (AC-1, deterministic, the 56-pass chain)

| Counter | Baseline | Final | Budget |
|---|---|---|---|
| `recompute_calls` / `drain_iterations` | 61 / 61 | 61 / 61 | equal |
| `stat_map_passes` | 122 | 0 | 0 |
| `record_lookups` / `record_visits` | 917 / 13,944 | 917 / 917 | visits at most lookups |
| `candidate_buffers` | 555 | 1 | at most `drain_iterations` + 1 |

`4596f34`'s commit message says "555 to 3". The measured figure is 1: three was a guess at the nesting depth, written before the count was read.

## `t_sim` per state (debug, loaded, x100; µs)

| State | Command | `clone` median | clone + submit median | p95 |
|---|---|---|---|---|
| mulligan | mulligan | 87 | 257 | 317 |
| early_main | play_card | 91 | 254 | 312 |
| full_boards | play_card | 116 | 371 | 400 |
| choice_pending | choose | 93 | 191 | 241 |
| taunt_stealth | play_card | 99 | 297 | 378 |
| empty_decks | end_turn | 59 | 218 | 284 |
| frozen_hero | play_card | 91 | 245 | 317 |
| weapon_equipped | play_card | 91 | 245 | 284 |
| boss_main | play_card | 95 | 273 | 297 |
| late_game | attack | 119 | 337 | 373 |
| budget full board | play_card | 121 | 386 | 478 |
| budget chain | play_card | 601 | 13,931 | 14,742 |
| **median of state medians** | | | **273** | |

`clone()` is now about a third of a plain node (99 of 278 µs), up from about a fifth (102 of 573 µs), because `submit` shrank around it.

**Planner bands at `t_sim` 273 µs** (F7 nodes, per planner run, target 500 ms):

| Band | Nodes | Before (unloaded, 432 µs) | Now (loaded, 273 µs) | Fits 500 ms |
|---|---|---|---|---|
| 1 | 370 | 159 ms | 101 ms | Yes |
| 2 | 1,460 | 630 ms | 398 ms | Yes, on debug |
| 3 | 6,000 | 2,592 ms | 1,638 ms | No: R5 lowers its counts, as the story expected |

The "before" column is the unloaded figure you gave, the "now" column was taken under load, so the true gain is the A/B's 0.49×, not this ratio.

## R4: not landed

The story allows sharing only data never mutated after creation. Checked against the writers:

| Candidate | Finding |
|---|---|
| `keywords` arrays | Not shareable. Silence clears them and `_strip_keyword` erases in place, and each record already holds its own copy |
| `enchantments`, `cost_modifiers` | Not shareable. Written in place |
| Deck cards | Not shareable. A draw writes `zone`, and `CARD_TARGET_ZONES` lets effects enchant them |
| Graveyard entries | The one candidate. No selector targets the graveyard, though `apply_enchantment` could reach one through `_find_record` |

Measured on the ten states, `players.duplicate(true)` takes 28 µs (median), and a copy sharing graveyard entries takes 32 µs, slower in all ten: a field-by-field copy in GDScript loses to one C++ deep copy, and the graveyards here hold at most 2 cards. A long match with a large graveyard could differ, but that was not measured. R4 is a stretch and AC-4 no longer needs it, so `MatchState.clone` is unchanged and AC-2's no-alias walk does not apply.

## Not yet recorded

- **Release template**: NOT ASSESSED (AC-3, AC-4, AC-40). The method is in the 2026-11-04 record.
- **Reference and quiet-machine figures**: the owner's re-measure after M2.
- **CI `performance` job**: not run, because the lane does not push.
- **Production `EffectResolver`**: not measured, as before; these numbers are the engine plus the scripted double. Its Deathrattles pass a dead source, and a dead id is a location miss, so each one still scans at today's cost. No regression, but R2 buys it nothing there.
- **Goldens across OS**: recorded on Windows only. QA plan MR-019 asks for one comparison on the other OS; the Linux CI run is the first.
- **Hot spot 3** (`_enqueue`'s snapshot): out of scope. Not re-ranked, because the remaining chain time was not re-profiled.
