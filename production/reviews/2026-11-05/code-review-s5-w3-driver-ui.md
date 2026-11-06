# Sprint 5 wave 3 code review: match driver schedule, C1.3, F2, MUI-003, MUI-010

Reviewer: lead-programmer, independent, read-only. Date: 2026-11-05.
Trunk read at `fd3174f`. `s5/l8-w3` read at `62004ed`, plus lane 8's uncommitted merge state in `.claude/worktrees/s5-l8` (staged and working diff of `match_controller.gd` and `match_controller_channels_test.gd`).

| Item | Verdict |
|---|---|
| BAI-014 phase schedule (`b7da921`) | **CHANGES REQUIRED** (one ADR item only; no hang found) |
| C1.3 search fix (`3ed119f`) | **APPROVED WITH SUGGESTIONS** |
| F2 data move (`f581681`) | **APPROVED WITH SUGGESTIONS** |
| MUI-003 (`2cb5b1c`) | **CHANGES REQUIRED** |
| MUI-010 (`62004ed`) | **CHANGES REQUIRED** |

Every finding below is `VERIFIED` by reading the code unless it says otherwise. Nothing was run: see "Could not assess".

## Blocking findings

**B1. Defect (ADR violation): `RulesEngine.state()` outside its allowed callers. Behaviour is safe.**
- `src/gameplay/match/match_query.gd:216` on `s5/l8-w3`, and `src/gameplay/run/match_driver.gd:300,301,324` on trunk (`:213`, `hooks()`, is older).
- ADR-0007 Decision 4: "`state()` may be called only from `src/gameplay/effects/**`; `MatchQuery` and Boss AI keep using `snapshot_entity` / `clone()`." Control manifest line 175 repeats it. The 2026-11-04 erratum widens it for `src/ai/**` on a sandbox clone only and says "`state()` on the live engine stays forbidden there."
- The skill rates an explicitly rejected pattern as ARCHITECTURAL VIOLATION, so this is blocking by rule. It is disclosed for MatchQuery, not for the driver.
- Safety, checked per method: main thread only, the live `PlayerState` never leaves the class, and every answer is built fresh or duplicated. `effective_cost` is a pure fold and survives teardown (`HookRegistry.fold` returns the value with no evaluator).
- Fix, either: add narrow reads to `RulesEngine` (`turn()`, and a per-side value read), or an owner erratum to ADR-0007 naming `MatchQuery` and the driver. `turn()` alone closes the driver's three new sites.

**B2. Defect: the `attacker` key change activated a double count (MUI-003).**
- `src/ui/match/match_view_state.gd:424` on `s5/l8-w3`: `attack_cancelled` calls `_count_attack`, and so does `attack_resolved` (`:422`).
- The engine emits both on a cancelled attack (`match_rules_attack_resolution_test.gd:299`, order `attack_cancelled`, `attack_resolved`) and adds one to `attacks_used` (`rules_engine.gd:2009`). So the view reads engine + 1.
- It was dormant while the key was wrong: `p.get("attacker_id", 0)` gave 0, a no-op. match-ui U3 says `attack_cancelled` changes "none", so the line is wrong by the GDD.
- L2 cannot see it: `attack_cancelled` is not in `MUST_SEE`. A Windfury attacker shows as spent after one swing.
- Reach: the one shipped `on_attack` is `war_duelists_edge`, which gives armour, so no shipped card cancels an attack today.
- Fix: drop `_count_attack` from `attack_cancelled`, and add a projection test with both events.

**B3. Defect: a player's Choice on the boss's turn is locked out (MUI-010).**
- `src/ui/match/input_router.gd:34`, `:20`. `controls_locked()` is `active_side == boss or boss_turn_active()`, and `LOCKED_INTENTS` is skip, menu, feed. `allows()` therefore refuses any pick.
- The state is real. BAI-014's `test_a_players_choice_on_the_boss_turn_waits_for_the_player_then_the_boss_plans_on` drives it, and the driver then waits on the player. match-ui States: "any state except `Ended` → `ChoiceOpen` on a player `choice_requested`".
- Result, once a router honours `allows()`: the match stalls, with concede the only way out. The story AC's wording produces this, so amend the AC too.
- Same trigger, second fault: `animation_queue.gd:567` runs `_turn_clock_s` in `PLAYBACK` while the queue is empty. The time the player spends choosing, and the re-plan after it, count against `max_turn_playback_s`, so `_auto_skip_if_due` (`:529`) can skip the boss's whole second half. F4's table says planning time does not count.
- Reach: no shipped card raises a player Choice on the boss's turn (the only `choose_one` is `neutral_smite_or_mend`, a spell; no `discover` op ships). Latent, but it must land before MUI-004 wires the router.
- Fix: lock false when `pending_choice.side == player`, a `choose` intent, and stop the turn clock while no plan step is queued or playing. No test covers either.

## BAI-014

```
## Code Review: MatchDriver phase schedule

### Engine Specialist Findings: ISSUES FOUND (not sourceable; see Could not assess)
### Testability: TESTABLE (qa-tester not spawned; reviewed by hand)
### ADR Compliance: VIOLATION (B1). ADR-0006, ADR-0008 and DD-X31 otherwise COMPLIANT
### Standards Compliance: 6/6
### Architecture: MINOR ISSUES (B1)
### SOLID: COMPLIANT
### Verdict: CHANGES REQUIRED
```

**Hang and stall trace: no hang found.** Every path that does not reach `end_turn`:

| Path | Outcome |
|---|---|
| Plan stops at the boss's Main with commands replayed | `_finish_replay` → `_schedule` → the row plans again; a sandbox `end_turn` refusal gives an empty plan → `_give_up` |
| Plan ends on an open boss Choice (`choice_unanswered`) | The row plans; empty plan; `_close_boss_choices` takes option 0, then `end_turn` |
| Null or empty plan, boss Choice open | Closed first, `end_turn` after; a closed Choice that opens a player's Choice leaves `phase != Main`, so it waits for the player, then the row plans |
| Option 0 refused | `_close_boss_choices` stops; the row replans each tick and logs, so `event_cap` ends it. Loops, cannot hang |
| Player's Choice on the boss's turn | Waits; `submit` runs the schedule afterwards. Driver side correct; UI side is B3 |
| Stale plan premise | Only concede could move it, and it is queued. A discard re-enters the schedule |
| Divergence with the match ended by the close | `_ended` is still false, so `end_turn` is refused unlogged (`MATCH_ENDED`), and the step handles `Ended` |
| Lethal during a live forecast | `Ended` runs with the task live; `tick` or `shutdown` releases it; `_on_task_done` returns on `_ended` |
| Event cap inside replay, diagnostics or a fault | Guarded at each point by `_ended` and `_pending_plan` |

One gap I could not close: time-sliced work that errors after its first suspension. See Could not assess.

**A boss Choice with no plan starts a plan task: right, and I recommend the owner confirm it.** With the row gone, `CHOICE_PENDING` hangs a boss Deathrattle or Start-step Choice. On the player's turn `plan_turn` gives the `choose` alone: `_is_own_main` is false, so there is no `sim` fork, no commit, and `last_forecast` is unspent. An End- or Start-step Choice that leads into the boss's Main plans the whole turn, as it should. On a give-up the player's turn stands.

**Fresh tasks: nothing leaked.** `_start_task` runs only with `_task == null`, so a re-plan never replaces a live task. Every end path goes through `_release_task`, which ends the sandbox after the work finished. `shutdown` drains a live task. It relies on MUI-004 calling it from `_exit_tree`.

**Determinism: holds.** One task at a time fixes the stream order, forecast fork then plan. A forecast always runs, stale or not, so draws do not depend on timing. `RngStream.fork` caches a label, so a re-plan's `sim_<turn>` costs no draw. `_read_public_log` runs at deterministic points. A second `ai_intent_committed` is skipped by `TurnPlan.checksum` (`INTENT_EVENTS`), and `_replay_start_seq` resets per plan, so replay is unaffected. `command_rejected` from a player click mid-replay is diagnostic, so it causes no false divergence. Timing does change two things: whether `ai_intent_shown` appears, and `kept`. Neither is in the checksum, but a whole-log compare of two worker runs would differ.

**`slice_ms`: it hides real overruns on the time-sliced path only.** On the worker path the only exclusions are `clone()` and `start()`. On the time-sliced path no slice length is checked at all, so `tick_over_budget` cannot fire however long a slice runs. The story understates the cost: a tick can run a poll slice and then `start()`'s first slice (stale forecast → plan row), about 4.2 ms plus the clone, not 2.1 ms. The default is `worker` and ADR-0006's erratum sanctions this, so it is not blocking. A30 is now the only guard, and it is a manual windowed run. Suggestion: in debug, compare a slicing poll with `slice_ms` plus a tolerance under its own fault reason.

**`null_forecast_gives_up`: I agree it is equivalent.** `_take_forecast` runs only with the premise held, which for a forecast is always the player's Main (`_schedule`). So `_boss_owes_choice` is false, `_give_up` returns on the side check, and the event-cap path matches `_append_fault`.

**AC check.** AC-1 to AC-5 each map to tests that exercise them. The story's deviations and the ADR errata agree with the code.

**Design questions for the owner**
- **Second commit.** boss-ai C2 and C8.2 describe one commit, when Main begins. A re-plan commits again with `kept = false`, so "plan changed" fires mid-turn even if the first commit was kept. In the queue the second commit is not `_is_commit` (`animation_queue.gd:455`), so it plays as a plan group of 0.3 s × k. Recommend one commit per boss turn.
- **`kept` with no forecast.** Ending the turn before the forecast returns gives "plan changed" with no banner ever shown. At band 3 a forecast may run about 2 s (ADR-0006), so this will be common for fast players. The same discard, with no second forecast, removes the telegraph when the player's own Choice is open as the forecast returns.
- **Slice retune**, already open: `slice_ms` 2 against A30.

**Nits**
- `telegraph_mode` moved to `brief` during a forecast still appends the `full` payload once (`_take_forecast`). Only `off` is handled and tested.
- `BossAI.choose` has no production caller now.
- `docs/architecture/control-manifest.md:200` is already updated on trunk; the story's "needs regenerating" note and its quoted rule lag. `run-structure.md` rows remain as the story says.

## C1.3 search fix

```
### Engine Specialist Findings: CLEAN
### Testability: TESTABLE
### ADR Compliance: DRIFT (minor)
### Standards Compliance: 6/6
### Architecture: CLEAN    ### SOLID: COMPLIANT
### Verdict: APPROVED WITH SUGGESTIONS
```

The fix is correct at node boundaries: the search gets the deck as it stands, `turn.unseen` stays empty on a real plan so a true draw stays, and `_settle` is unchanged. The forecast path only improves (a card shuffled into the deck mid-forecast is now covered). Scorer's `hand_defs` reads the before-state only, so a trial's draw does not reach it.

Suggestions:
- The title overclaims. `lethal_search.gd:140-143` drops after `submit`, so an `on_draw` hook still reads the card inside a search node, exactly as in the trial the commit excludes. No shipped card has `on_draw`. Say so in the search doc and in the owner's item.
- ADR-0006's 2026-11-05 erratum still says "a real plan never does it" about `drop_unseen`. Node clones of a real plan now do. Amend it.
- `tests/fixtures/boss_ai/real_plan_undrawn_card.json` is unused until the trial decision. Keep it only with that item open.

## F2 data move

```
### Engine Specialist Findings: CLEAN
### Testability: TESTABLE
### ADR Compliance: COMPLIANT
### Standards Compliance: 6/6
### Architecture: CLEAN    ### SOLID: COMPLIANT
### Verdict: APPROVED WITH SUGGESTIONS
```

Behaviour is identical by reading: the same four values, the same arithmetic, `profile.rules` passed on both `_measure` calls, DEFENSIVE's copied profile keeps `rules`, and no other caller of `board_value` or `threat` exists. The keys are validated: `RULE_KEYS` makes them required on `default`, `RANGES` holds 0 to 3 as F2 says, and the gate pins the rows. As `rules` they are sensible: F2 calls them data, and bands and overrides can tune them with the resolver's shallow merge. The 20-odd 42-byte fixtures that lack the keys are stubs, not profiles.

Suggestions (nits): `F2_RULE_KEYS` has no production reader. `threat_deathrattle` and `defensive_taunt_bv` stay literals beside their new data siblings; that is correct by F2, and worth a line in the table doc.

## MUI-003

```
### Engine Specialist Findings: ISSUES FOUND (nit: InputRouter, see MUI-010)
### Testability: GAPS (attack_cancelled; keywords)
### ADR Compliance: VIOLATION (B1)
### Standards Compliance: 6/6
### Architecture: VIOLATIONS FOUND (B1)
### SOLID: COMPLIANT
### Verdict: CHANGES REQUIRED (B1, B2)
```

**The UI cannot mutate state.** The controller forwards; `submit` goes through the driver, which stamps `issuer = player`; `hooks()` is not forwarded. All nine `MatchQuery` reads return fresh values or deep copies. Privacy of `_engine` is by convention only, as everywhere in GDScript. G5 was not run.

**Hidden information.** `hand("boss")` is a count, `entity()` answers `{}` for a deck or boss-hand card, and `snapshot` carries no deck order or boss hand ids. `pending_choice` empties boss `options`; `source_id` and `effect_id` remain, which are public. `resolving` and `graveyard` are public by C1.3.

Design question for the owner, widening Q-5: `MatchQuery.legal_commands()` is not limited to a boss Choice. At the boss's Main it lists the boss's own `play_card` commands, which shows how many boss cards are affordable and which take targets. So the doc at `match_query.gd:12` ("the one exception today") is false. U2 calls it a pass-through, and nothing renders it yet. Filter to `issuer == player` or correct the doc.

**The `attacker`/`defender` change.** Reading the engine's spelling is right: the engine sends `attacker`, and §D says `attacker_id`. Two things follow. The fix activated B2. And the fallback keeps the disagreement alive: fix the §D row, then read one key.

**Open item that needs a home.** L2's `keywords` clause is NOT ASSESSED and the box is ticked. The cause is real: `minion_summoned` carries no `keywords[]`, so no Taunt or Divine Shield badge can come from events. I found no tracked item outside this story's notes.

**Nits:** `snapshot()` is a test-facing method on a production class. L2's `MID_BATCH` and `SETTLED_ONLY` exclusions are recorded and reasoned; I accept them.

## MUI-010

```
### Engine Specialist Findings: ISSUES FOUND (nit: InputRouter)
### Testability: GAPS (B3)
### ADR Compliance: COMPLIANT (additions to ADR-0009 Key Interfaces recorded)
### Standards Compliance: 6/6
### Architecture: CLEAN    ### SOLID: COMPLIANT
### Verdict: CHANGES REQUIRED (B3)
```

**`controls_locked()` across phases.**

| State | Locked | Correct? |
|---|---|---|
| Mulligan, player's Main, forecast live | No | Yes; does not read `is_planning` (lane 8's new test pins it) |
| Boss's turn, beat, thinking, playback | Yes | Yes |
| Until `turn_started{player}` has drained | Yes | Yes |
| Player's own Choice on the player's turn | No | Yes |
| **Player's Choice on the boss's turn** | Yes | **No: B3** |
| Boss Choice on the player's turn | No | Nit: GDD line 270 wants the control disabled; the click only earns `CHOICE_PENDING` |

**Stuck lock: none beyond B3.** A turn with no plan leaves on `exit_boss_turn` (`_leave_wait`). A fault path reaches `turn_started{player}`. Drain ends the mode through `advance` and skip alike. `advance` cannot spin with `wait = INF`.

**Wall-clock.** Clean. `commands.test` excludes `res://tests/performance` with `-i`. `boss_turn_pacing_test.gd`, the channels suite and the parity suite read no clock. L13 sits in `tests/performance/`.

**The changed MUI-001 assertion is right.** U6.6 and Edge Cases require the 0.4 s step. The hidden-information checks stay, and the test adds that the step's data is empty.

**ACs.** L8, L16, the pacing AC and DD-X23 hold in code and tests, apart from the lock wording in B3. Auto-skip past `k = K_MIN` is the reasonable reading, and L8 needs it.

**Owner items raised by the authors, confirmed:** on a real turn the first group starts near *t* + 600 ms, because the Start-step steps precede it. `A` counts groups, while F4's table says commands.

**Nits**
- A match that ends before any plan (boss dies in its Start step) leaves `THINKING` on, since no exit comes.
- `InputRouter extends Node` with no scene use needs an owner to free it; story 004 should own that or make it `RefCounted`.
- `boss_turn_pacing_test.gd` is a unit suite that loads shipped JSON.
- The `match_ui` validator is still pending, so the three new keys are pinned only by a test.

## Could not assess

- **Nothing was run** (no Godot, by instruction). Every pass count, mutant result, the "12 logs byte-identical" claim and every perf figure is the authors' record, unverified. `gates.sh`, G5 and `ai_code_gates.sh` on the merged tree: not run.
- **The real worker pool.** No test runs `WorkerThreadPool`: only `boss_ai_planner_task_test.gd` names `WorkerPoolPlannerTask`, on a fake pool. The doc at `worker_pool_planner_task.gd:17-18` says integration tests exercise it; none does. `planner_mode` ships as `worker`, and `driver_factory` does not exist, so the default path has never run through the driver. Add one integration test.
- **NOT SOURCEABLE** (`docs/engine-reference/godot/` has no page; specialist agrees): whether a runtime error inside time-sliced work after it suspended ever completes `_run`. If it does not, `poll()` stays false and the boss stalls, with no timeout; AC-4's "never hangs" is then unproven for errored work. Also whether `_result = work.call()` on a non-suspending coroutine is always the value, thread safety of concurrent `CardDatabase` reads (story 017), and of the static `RegEx` in `RngStream.fork`.
- **A30**: manual, windowed, not run.
- **AC-1 "built by the driver factory"** and everything MUI-004 wires (`exit_boss_turn` order, `shutdown` from `_exit_tree`).
- **Lane 8's merge** was in progress as I read; its uncommitted edits may change.
- **Specialists.** `godot-gdscript-specialist` ran once, on the questions above, and its points were checked against the code. `qa-tester` and a UI specialist were not spawned; I did testability by hand.
