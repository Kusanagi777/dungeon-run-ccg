# Sprint 6 pre-W1 independent code review

Reviewer role: technical-director and lead-programmer. Date 2026-11-05. HEAD at review: `3141da2`, unmoved.
Method: `.claude/skills/code-review/SKILL.md` by hand. Read-only: no edit, commit, merge or Godot run.

| Story | Verdict |
|---|---|
| match-rules 020, branch `s6/mr-020` (`6338d2c`, `d6085bc`) | **APPROVED WITH SUGGESTIONS** |
| boot-composition-root 009, trunk `3141da2` (`dd96379`) | **APPROVED WITH SUGGESTIONS** |

No blocking defect in either. One design question blocks MUI-004's readiness, not these stories (DQ-2).

**Neither verdict rests on a test run.** I did not run the suites. Everything below is from reading code and mechanical checks on the committed files, except gates on trunk, which I ran.

## Not assessed

- **Test suites, smoke, parse check:** not run (Godot forbidden). Pass counts in both stories are the authors' claims.
- **`gates.sh` / `ai_code_gates.sh` on `s6/mr-020`:** not run. The scratchpad export of the branch was refused by the permission system and I did not work around it. The two `src/` files were read by hand instead; the hunks contain no gate token. On trunk `3141da2` both ran: G1-G7 0 hits, AI rules 0 hits. `no_global_rng.sh` was not run.
- **Real worker run:** NOT ASSESSED. See 009, "Can a real driver run a boss turn".
- **Thread safety on 4.7.2:** NOT SOURCEABLE, threading has no page under `docs/engine-reference/godot/`.
- **A real export:** none built. The "no tests/ dependency" result is a source scan.
- **Linux CI on `d181790`:** still open (`production/sprints/sprint-006.md:29`). The goldens were not compared on Linux. The new fields are ints and sorted strings, so the added risk looks small, but that is reasoning, not a read.
- **"88 `SCRIPT ERROR` lines"** in 009's Verification: no baseline found to judge it.
- **`godot-specialist`** (primary and `specialists.ui`) not spawned: `driver_factory` touches no scene, node or lifecycle hook, and `MatchViewState` is a `RefCounted` projection, not a widget.

---

## Golden diff read (story 020 AC-4)

`git diff aa112dc s6/mr-020 -- tests/fixtures/match_rules/golden_logs/`, compared line by line by script over both blobs of all 16 files.

**Result: every changed line is only the intended addition, and every value checked is correct.** This is my own check, not the commit message's. AC-4's technical-director read is done, so its box can be ticked.

| Check | Result |
|---|---|
| Files changed | 14 of 16 (`aura_holders`, `full_board_legal` unchanged) |
| Lines | 197 of 4647 changed; line counts equal; no CR |
| What changed | 185 `minion_summoned` + 12 `match_started`, nothing else |
| Row kinds | 134 `event`, 49 `clone_event`, 14 `command_event` |
| Added keys | exactly `keywords` / `starting_health`, none removed |
| Stripped proof | each new line with the key removed, re-serialised canonically, equals the old line byte for byte: 197 of 197 |
| Envelope and event count | `seq`, `turn`, `cause_seq`, `type` and count per line unchanged |
| Coverage | every `minion_summoned` and `match_started` in the new files has the field; 0 missed |
| Per commit | `6338d2c`: 9 files, 185 lines. `d6085bc`: 12 files, 12 lines. Matches both commit messages |
| Budgets | `match_rules_op_budget_test.gd` and `match_budget_fixtures.gd` unchanged |

**Keywords against the card.** All 185 rows span 8 card ids, each equal to its spec in `tests/helpers/match_budget_fixtures.gd:50-55,80`, sorted and unique:

| Card | Keywords | Rows |
|---|---|---|
| `fx_grunt` | none | 42 |
| `fx_brute` | none | 12 |
| `pb_grunt` | none | 3 |
| `fx_runner` | `charge` | 13 |
| `fx_wall` | `taunt` | 11 |
| `fx_seer` | `battlecry`, `discover` | 5 |
| `fx_shade` | `stealth` | 1 |
| `pb_chain` | `deathrattle` | 98 |

Second check: for the 55 rows whose entity appears in a later dump, the dumped record's keywords match, 0 mismatches. The other 130 entities are gone before any dump, so only the card spec backs them.

**Starting health against the hero.**

| Golden | Value | Backed by |
|---|---|---|
| 8 files | 30 / 30 | later dump `base_health` 30 |
| `state_mulligan` | 30 / 30 | no dump follows the event; fixture sets no override, so default only |
| `scripted_match` | player 40, boss 300 | `REPLAY_PLAYER_HEALTH`, `REPLAY_BOSS_HEALTH`; dump `base_health` agrees |
| `state_late_game` | boss 120 | fixture `boss_health` |
| `state_empty_decks` | 24 / 20 | not a bug, see below |

`state_empty_decks` is the one that looks wrong. Decks are empty, so the setup deal is fatigue: player 1+2+3, boss 1+2+3+4. The last `damage_dealt` before `match_started` has `health_after: 20`. It is `health()` at that instant, as AC-2 and DD-X35 say, and it is why the value must be current health, not max: the view drops those earlier `damage_dealt` rows, having no hero id yet.

---

## Code Review: match-rules 020

### Engine Specialist Findings: CLEAN
`godot-gdscript-specialist`: nothing found in the `rules_engine.gd` and `match_view_state.gd` hunks. I re-checked it against the diff.

### Testability: GAPS
From `qa-tester`, each verified by me. None blocks. See Suggestions.
- `view_state_engine_parity_test.gd:203-204` guards `_compared` and `_health_compared` but has no guard that a non-empty keyword set was compared. Keyword-free decks would pass the clause. Only the authors' note shows it failed for real.
- AC-1's "enchantment-granted" clause has no reachable test: both sites build a fresh record, so a printed-only mutant survives. The story discloses this.

### ADR Compliance: COMPLIANT
- ADR-0003: no new event, no reorder, payloads JSON-only, one event per mutation.
- ADR-0007, ADR-0001: engine owns the emit; the view reads events only.
- DD-X04: match-rules C15 and rng-event-log §D updated together.

### DD-X35: followed
- Nested `starting_health {player, boss}`, built over `MatchRecords.SIDES` (`rules_engine.gd:2592-2594`, `:2601`).
- No armour field. `test_match_started_adds_only_starting_health_even_when_a_hook_gives_armour` pins the key set exactly.
- GDD C3, C15, §D and the DD row agree with the code.

### MatchViewState projection: correct
`match_view_state.gd:305-308`: `p.get("starting_health", {})`, then `has()` per side, so an older stream leaves health null, as the notes require. Keys are Strings on both sides. It runs after the hero ids are set, makes no step (U3 says none), and leaves armour alone. `minion_summoned` (`:393`) copies the array.

### Hidden information: no leak
`keywords` on a boss `minion_summoned` exposes nothing new.
- There are only two emit sites, both for a minion entering the board, which is public.
- The same payload already carries `card_id`, `attack` and `health`, so printed keywords are derivable from it.
- At both sites the set is the printed set, so it says nothing beyond the card.
- `auras_recomputed` already reports keywords for entities in play.
- match-ui U3.2 hides boss draws and boss Discover options only, and those paths are untouched.
- Stealth is a visible badge (`match-ui.md:874`).
- Shipped boss-card keywords are `aura`, `battlecry`, `deathrattle`, `divine_shield`, `taunt`: all printed traits, none concealed.

### Standards Compliance: 6/6
`_mulligan_step` is 39 lines, up from 35, inside the limit. `_project` is long, but that predates this change.

### Architecture: CLEAN
### SOLID: COMPLIANT

### Game-Specific Concerns
One array per summon and two ints per match start, off any frame loop. `_effective_keywords` returns a fresh array, as the Engine Notes require.

### Positive Observations
- The story found the `match_started` timing argument itself and split the work so each regeneration is its own reviewable statement.
- Hook fixtures use different amounts per side, so a wrong-side or pre-hook read shows.
- The author removed a test that could not fail, rather than keeping a green one.

### Required Changes
None.

### Suggestions
1. Add a non-empty keyword counter to the parity guard (`view_state_engine_parity_test.gd:203`). *Nit.*
2. `rules_engine.gd:1236-1237` (branch) still documents `minion_summoned` without `keywords`. *Nit.*
3. `design/gdd/match-ui.md:173` U3 row still reads "Deck counts, hero ids". The story left this alone; match-ui's owner should add health. *Nit.*
4. AC-3 says compared "from the first step", while `view_state_engine_parity_test.gd:112` starts at `match_started`. Reword the AC to match. *Nit.*
5. Story Status reads Complete with AC-4 open. Tick it after this read. *Nit.*
6. `minion_transformed` has no case in `MatchViewState`, so a transformed token keeps stale keywords. It predates this story and no shipped card uses `transform`, but keyword parity will not catch it. Record it before transform content ships. *Nit.*

### Design question for the owner
**DQ-1. Hero health is null on the Mulligan screen.** Not a merge blocker.
`match_started` is emitted inside `_mulligan_step` (branch `rules_engine.gd:2591-2602`), after the player confirms. `mulligan_offered` comes earlier, at `start()`. `state_mulligan.jsonl` confirms it: `match_started` appears only among the command rows. But `design/ux/mulligan.md:176` keeps both portraits at full contrast under the overlay. So on a live start (`first_playable` rests at `mulligan_offered`) the health stamps have no value until the mulligan is confirmed. MUI-005 AC-1 is unaffected because `turn1_player` is past it. DD-X35's reasoning does not mention this. Decide what those stamps show before MUI-005's presenter is built.

### Verdict: APPROVED WITH SUGGESTIONS

Merge: no conflict with trunk (`git merge-tree` clean, no shared files). The story asks for the full suite on the merged state afterwards; that is still to do.

---

## Code Review: boot-composition-root 009

### Engine Specialist Findings: CLEAN (two NOT SOURCEABLE points)
`godot-gdscript-specialist` found the lambda captures sound and no thread-unsafe state it could verify. Its two unsourced points are under "Can a real driver run a boss turn".

### Boot Composition Root 009 — Testability: GAPS
From `qa-tester`, verified by me unless marked. See Suggestions.
- `OS.is_debug_build()` at `boot.gd:179` has no seam: removing it survives.
- `test_shipped_data_boots_to_a_factory` (`boot_driver_factory_test.gd:381-387`) asserts only `is_valid()`, so no test builds a driver from shipped data through the factory or asserts the shipped `worker` class.
- The scan's exemption at `:153` strips every `res://tests/fixtures/`, so `preload("res://tests/fixtures/x.gd")` would pass, and `tests/fixtures/lint/` does hold `.gd` files.
- An invalid non-null override silently becomes a worker (`boot.gd:177`).
- Dropped, unverified or too minor: `slice_ms` below 0.001, `_result.ok` after a reload.

### Boot Composition Root 009 — ADR Compliance: COMPLIANT
- **ADR-0008 D1:** the shape matches. New driver per call; `meta.get_settings()` taken inside the lambda, so per call.
- **ADR-0006 Guidelines:** default worker, `time_sliced` or `--ai-sync` fallback, new object per call.
- **ADR-0001 D4, ADR-0011 D4:** `boot.gd` is the one `src/core` file that may name these classes.
- **DD-X31, DD-X33:** followed in code, data, fixture and GDD F9.
- **ADR DRIFT (documents, WARNING):** ADR-0008 D11 (`:336-338`), manifest lines 212 and 331 and story MUI-004 still say the loader builds with `ImmediatePlannerTask`, which AC-3 now forbids `src/` to name. DD-X33 cites ADR-0006 and ADR-0008, but no ADR text carries it, and ADR-0006's `:481` row still quotes the old F9 list. These are technical-director's to refresh.

### AC check against the code
| AC | Finding |
|---|---|
| 1 | Met. Tests prove new driver, per-call snapshot, and empty `Callable` on no boot and on `Failed`, including the `meta`-override trap |
| 2 | Met. `.new` sits inside both lambdas |
| 3 | Met. Override wins before any config read. Grep: only `main.gd:34` outside `##`, exempted by the reword |
| 4 | Met. `_check_runtime` reads `PLANNER_MODES`; shipped and `minimal` data read `worker` |
| 5 | Met for the diff: 45 insertions, 0 deletions; no new script var; `_collect_validators` and `PENDING_*` untouched; G1-G7 pass. Existing suites not run by me |

### The five questions
**Fresh task per call: yes.** `boot.gd:181,183` call `.new` inside the lambda. `slice_usec` is an int captured by value. An override is used as given, by design. The planner `Callable` is shared by all drivers of one factory, harmless while stateless, and the author's BAI-019 note on that is correct.

**Export independent of `tests/`: yes, by source scan.** I went wider than the AC's one class name. Of the 23 classes declared only under `tests/`, none is named on a code line in `src/`: the hits are all `##` doc comments. 165 `tests/` `.uid` values appear nowhere in `src/`, and `project.godot` has no `tests/` path. No real export was built.

**`boot.gd` within the rules: yes.** One method, stateless, no stored factory, `BOOT_FIELDS` intact. `Services` untouched. `boot-responsibilities.md` updated, and the two rows are justified. Gates pass on trunk. `driver_factory` is not a per-service getter: it returns a derived factory, not a service.

**`--ai-sync` in release: ignored, by inspection.** `(OS.is_debug_build() and cmdline_args.has("--ai-sync")) or runtime.planner_mode == "time_sliced"` short-circuits, so a release build ignores the flag and still honours `time_sliced` from data. That matches `Main.boot_overrides`, where a release build ignores debug arguments. It remains untested. The fix is cheap, and the file has the precedent: `_collect_validators(meta, debug_build: bool = OS.is_debug_build())` at `boot.gd:219`. Owner to confirm the behaviour (DQ-3).

**Can a real driver run a boss turn with `WorkerPoolPlannerTask`: no blocker found by reading; NOT ASSESSED at run time.**
- The clone and the closure are built on the main thread in `_start_task` (`match_driver.gd:311-318`).
- The worker reaches the sandbox, `_ai_stream` and the frozen `db`. `_read_public_log`, the only `_log` read in `BossAI`, runs on the main thread before the task starts.
- `clone()` makes a fresh resolver and scratch log. `_where` holds int hints, so its flat copy is safe. `_telegraph_pending` defers setting changes while a task is live. `config()` returns the frozen body. `shutdown()` blocks on a live task.
- `poll` checks completion before waiting, once, and never touches the pool afterwards.
- **But no test or run in this repo has ever driven `MatchDriver` through the real pool.** `boss_ai_planner_task_test.gd` names no `WorkerThreadPool` and drives injected fakes; the factory tests never call `start()`. That is by design here (TD-012), and BAI-017 owns it, still Ready, not built. W1 work should not treat the default path as proven.
- UNVERIFIED, specialist claims, NOT SOURCEABLE: (a) `static var _label_regex` (`rng_stream.gd:46`) is shared and `fork()` searches it on the worker; whether concurrent `RegEx.search` is safe is unsourced. (b) `_result = work.call()` (`worker_pool_planner_task.gd:73`) needs the coroutine never to suspend. On (b), `ImmediatePlannerTask` uses the same idiom and `match_driver_replay_test.gd` exercises it, though on the main thread. Both belong in BAI-017's checks.

### Boot Composition Root 009 — Standards Compliance: 6/6
### Boot Composition Root 009 — Architecture: CLEAN
### Boot Composition Root 009 — SOLID: COMPLIANT

### Boot Composition Root 009 — Game-Specific Concerns
Nothing on a frame path. `_check_runtime` requires `planner_mode` and `slice_ms`, and a missing `runtime` is a row, so `db.config(...).runtime.planner_mode` is safe after `Ready`.

### Boot Composition Root 009 — Positive Observations
- The method is 15 lines of derived, stateless composition.
- The failed-load test uses a `meta` override deliberately, so a check on `meta` alone would fail it.
- `test_the_source_scan_finds_a_planted_reference` proves the scan can fail.
- The deviations section is honest, including the AC-3 grep being false as written.

### Boot Composition Root 009 — Required Changes
None.

### Boot Composition Root 009 — Suggestions
1. Add `debug_build: bool = OS.is_debug_build()` to `driver_factory`, plus a release-build test (`boot.gd:170,179`). This closes the only unseen half of AC-2.
2. Treat a non-null invalid override as an error, not a silent worker (`boot.gd:177`). A stale `Callable` in a test would otherwise start a real pool task, which ADR-0006 forbids under gdUnit.
3. Derive the scan's class list from `tests/` and tighten the fixture exemption to refuse `.gd` paths (`boot_driver_factory_test.gd:33,153`).
4. Assert `WorkerPoolPlannerTask` from the shipped data and build one driver in `test_shipped_data_boots_to_a_factory` (`:381`).
5. Name the literals `"--ai-sync"` and `"time_sliced"` (`boot.gd:179`), as `main.gd` does with `FAIL_FIXTURE_ARG`. *Nit.*
6. Refresh ADR-0006, ADR-0008 D11 and the manifest for DD-X33 at the next `/create-control-manifest update`.

### Design questions for the owner
**DQ-2. How does a `capture.sh` run get its planner? BLOCKS MUI-004 readiness (W1).**
`story-009-driver-factory.md:62` says `capture.sh` runs pass `ImmediatePlannerTask` as `planner_override`, and `:66` says the loader takes the planner from its caller. But MUI-004 AC-3 (`story-004:37`) launches `res://src/ui/match/match_view.tscn` as a process. A shell cannot pass a `Callable`, and the loader under `src/` cannot name the class. As written, no code path satisfies that row and MUI-004 AC-2 together. Story 009's note covers the rewording but not this. Options:
- Capture runs use `--ai-sync`, or the worker, with the loader ticking until `is_planning()` is false.
- A launcher scene under `tests/` that passes the override.

The factory seam itself is right, so this is not a 009 defect. Needs a decision before MUI-004 starts.

**DQ-3. `--ai-sync` in release.** Confirm "ignored", then one line in ADR-0006 (`:393-394`, and manifest line 195, which has no "debug" qualifier).

### Boot Composition Root 009 — Verdict: APPROVED WITH SUGGESTIONS

This approval covers the factory and its selection logic. It does not cover a real worker run, which is BAI-017's.
