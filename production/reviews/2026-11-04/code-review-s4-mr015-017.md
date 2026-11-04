# Code Review: match-rules 015 (freeze, thaw, Silence) and 017 (clone and replay)

**Date**: 2026-11-04. **Reviewer**: independent session. `/code-review` followed by hand from `.claude/skills/code-review/SKILL.md`, because the skill cannot be model-invoked.
**Commits**: `c382564` (story 015) and `b1caae8` (story 017), merged at `70947a5` on `bootstrap/ccgs-template`.
**HEAD during the review**: `29146bf`. It adds only `design/ux/*.md`, so every `file:line` below is the same at `70947a5` and at HEAD.
**Standing approval**: the owner gave it. No questions were asked. No source, test or story file was edited, and nothing was committed.

---

## Notes for Boss AI story 004 (read first)

1. **Isolation holds, and so does equivalence.** Probe P1 walks every container reachable from both states and found **no shared mutable container** between live and clone, or between clone and clone-of-clone. It covered `players`, `effects`, `suspended_*`, `pending_choice`, `result`, the hook `_entries`/`_hosts`, the log, `rng_match` with its generator and fork memo, the resolver and the engine transients. It ran on all 10 AC-39 fixtures, the boss-Discover fixture and the production-resolver paused Discover.
   - Probe P2 submitted the same 40 commands to the clone, to a clone-of-clone and then to the live engine, across 11 states. The `[type, payload]` streams, the entity snapshots and the `rng_match.draws` counts were identical every time.
   - A planner may therefore treat `clone()` as a value copy, clone a clone, and expect live replay to reproduce the sandbox.
2. **Budget: `t_sim` is about 100× what boss-ai F7 assumes.** F7 budgets `t_sim = clone + one submit ≈ 0.01 ms`. Measured on Godot 4.7.2 (editor binary, `-d`, headless):
   - `clone()` alone takes **93–190 µs**.
   - `clone + submit + end_match` takes **0.43–1.5 ms per candidate**. A single attack `submit` is about 0.7 ms, and `legal_commands()` is about 0.47 ms.
   - At that rate band 3's `(8·250 + 4000)` nodes cost seconds, not 60 ms. Even band 1 cannot meet 50 ms when it evaluates every candidate.
   - Plan the one-ply sandbox against measured numbers: pre-filter candidates and cap evaluations per action, and push story 018's timing ahead of BAI tuning. These are debug-build numbers, and a release template will be faster, but not by 100×.
   - The `rng_match` copy is O(draws): about 100 µs at 1,000 draws and about 1 ms at 10,000 (ADR-0003 F5 reseed-and-discard).
3. **Call `end_match()` on every clone, every time, including on early-return and abort paths.** P6 dropped 10 clones without `end_match()`, and all 10 stayed alive: the engine and resolver form a `RefCounted` cycle. With `end_match()`, 0 of 10 stayed alive. A trial whose `submit` ends the match unbinds itself, and `end_match()` on it is then a harmless no-op.
4. **Checksum source.** Compute `TurnPlan.expected_checksum` over the **root sandbox's** scratch log (`state().log.events_since(0)`), not over a trial's log. Each `clone()` gets a fresh scratch log with `seq` from 1, so the trials do not pollute the root sandbox's log.
   - Fold **types only** (ADR-0006). `seq` and `cause_seq` differ between scratch and live. After a resumed Choice, scratch `cause_seq` values still point at **live** seq numbers: P5 shows `choice_made` at scratch seq 1 with `cause_seq 32`.
5. **Do not fork `rng_match` on a clone.** The fork memo is not copied (the documented deviation). P3 confirms the result: if the live stream has already forked label `x`, the clone's `fork("x")` takes a parent draw that the live engine would not take, and every later draw diverges (`2164` live vs `27144` clone). Use the `ai_<floor>` stream and its `sim_<turn>` forks for planner randomness, as ADR-0003 intends.
6. **Only submit commands from `legal_commands()`.** `submit` silently accepts and ignores a stray `position` on a spell or weapon, and a `target_id` on a `none`-targeting card or power (see S6). Replay stays equivalent, but a planner that synthesises commands could deduplicate wrongly.
7. **`clone()` is between calls only.** It is guarded by a debug `assert` and is legal in `Choice`. `BossAI.choose(sandbox, pending)` on a boss Discover works: the production-resolver test plus P1 and P2 cover it.

---

## Inputs

| Input | Status |
|---|---|
| Story files 015, 017 (incl. Completion Notes, deviations) | FOUND |
| GDD `match-rules.md` by section: C2, C4 End step, C12 Freeze/Silence/Deathrattle rows, C13, F6, Edge Cases "Keywords and status", States (grep) | FOUND |
| ADR-0003 (fork points, F5, Decision/erratum, grep-bounded) | FOUND |
| ADR-0005 Decision 7, ADR-0006 Status/Decision/Guidelines/Performance, ADR-0007 Decision 3 + 2026-11-04 erratum, ADR-0008 Decision 4 + Risks | FOUND |
| Control manifest Core and Feature rows on `clone()`, guardrails | FOUND |
| `RulesEngine.clone()` doc comment (`rules_engine.gd:3390–3440`) | FOUND |
| card-effects GDD (C6.5 states rows) and card-effects story 009 AC-21 | FOUND (consulted for S3) |
| boss-ai GDD F7 and Tuning Knobs rows (for the budget note) | FOUND |
| Story `## QA Test Cases` | ABSENT: "N/A — no qa-lead specs at this tier" |
| Match-rules performance test (story 018) | ABSENT: the perf guardrail is NOT ASSESSED; probe numbers are observations |

## Baseline (main repo, no edits)

- `godot --headless --path . --import` exited 0.
- `commands.test` reported **1314 test cases, 0 errors, 0 failures, 0 orphans, exit 0**. There were 85 `SCRIPT ERROR` lines, all from the known intentional negatives: `card_database.gd` 44, `rng_stream.gd` 16, `card_database_freeze_test.gd` 7, `event_log.gd` 6, `rng_service.gd` 4 and `boss_ai_planner_task_test.gd` 3. None came from `src/gameplay/match`. The count is unchanged from the stories' completion notes.
- `commands.smoke` (`godot --headless --quit-after 5`) exited 0 with no `SCRIPT ERROR`.
- Logs: `scratchpad/rv4c_import.log`, `rv4c_suite.log`, `rv4c_smoke.log`.

## How behaviour was verified

All verification ran in a scratch snapshot, `scratchpad/rv4c_snap/` (`git archive HEAD`), whose import exited 0.

- **Probes**: `rv4c_snap/tests/rv4c_probe/rv4c_probe_test.gd`, probes P1–P11. It extends the story-017 suite, so all 12 inherited tests also ran and passed: 23/23. The output is in `scratchpad/rv4c_probe.log` and `rv4c_probe2.log`.
- **Mutants**: `scratchpad/rv4c_mut.py` applies one mutation per invocation, runs `tests/unit/match_rules` (294 tests), restores the file and asserts the restore. Restore sources are `rv4c_engine_orig.gd` and `rv4c_state_orig.gd`, and the final `cmp` was clean.

| Mutant | Result |
|---|---|
| M1 thaw `or` → `and` | killed |
| M2 no F6 clamp | killed |
| M3 thaw stage removed | killed |
| M4 Silence leaves `frozen` | killed |
| **M5** `suspended_queue` shared (not duplicated) | **SURVIVES** (live-visible: `_do_choose` clears it in place, `:2690`) |
| M6 `suspended_action` shared | survives (equivalent today: only ever reassigned, `:2688`, `:1357`) |
| M7 `pending_choice` shared | survives (equivalent today: reassigned) |
| **M8** scratch log cap = full cap, not remaining room | **SURVIVES** (doc claim untested) |
| **M9** `_torn_down` not copied | **SURVIVES** (doc claim untested) |
| M10 stream not restored to `draws` | killed |
| M11 `result` shared | survives (equivalent today) |
| **M12** Silence also strips *received* aura enchantments | **SURVIVES** (see S4) |

---

## Engine Specialist Findings: NOT ASSESSED

`godot-gdscript-specialist` and `godot-specialist` could not be spawned in this session. As a substitute, the reviewer checked the engine behaviour the change relies on with the probes above, on 4.7.2:

- `duplicate(true)` on a typed `Dictionary[String, Dictionary]`, on nested typed `Array[Dictionary]` records, and on read-only hook entries gives fully independent containers. P1 found no alias at any depth.
- `make_read_only()` is re-applied by `HookRegistry.copy()`.
- `weakref` frees the clone after `end_match()` (P6).
- `RandomNumberGenerator` reseed-and-discard reproduces the stream (P2 draw counts, plus the AC test).
- Every API used predates 4.3, so there is no post-cutoff exposure.

## Testability: GAPS (qa-tester NOT ASSESSED; review done by the reviewer)

There are no QA Test Cases. The gaps are M5, M8, M9 and M12, plus S3's untested queued-vs-silenced boundary (S4 and S5 below).

## ADR Compliance: COMPLIANT (minor deviations)

- **ADR-0007 Decision 3 and the 2026-11-04 erratum: COMPLIANT.** The clone gets a fresh `EffectResolver` with the live `effects_config()` and `player_hero_set()`, bound with no installers, and its memo starts empty. P1 confirmed clone memo 0 vs live 8, and `_tail` empty.
- **ADR-0005 rule 7: COMPLIANT.** `copy()` is by value and evaluators are rebound on the clone only.
- **ADR-0006 and ADR-0008: COMPLIANT.** The scratch log is detached, with no subscribers. The live engine holds no reference to the clone. P2 confirms that replay is equivalent.
- **ADR-0003 F5: COMPLIANT** (reseed-and-discard). The **MINOR DEVIATION** is S7: `_copy_stream` reads `RngStream._stream_seed` and `_make_child`, and the fork memo is not carried.
- **ADR-0007 Silence ("`silenced` is what the resolver reads"): COMPLIANT.** The double and the production resolver (`effect_resolver.gd:483`) both read it.

## Standards Compliance: 6/6 passing

`clone()`, `MatchState.clone`, `silence` and `_thaw` carry doc comments with examples. Every method is under 40 lines. Nothing is hardcoded, and dependencies are injected.

## Architecture: MINOR ISSUES

The clone design is sound and cheap to reason about, with three plain-data fields and two swapped references. The minor issues are the untracked `RngStream.copy()` seam (S7) and the downstream UI contract that Silence now breaks (S1).

## SOLID: COMPLIANT

`clone()` is split into `_fresh_resolver`, `_scratch_log` and `_copy_stream`. The pressure on `RulesEngine`'s size is the same as noted in earlier reviews.

## Game-Specific Concerns

- No frame-time code is involved.
- The P4 and P11 numbers are in the BAI notes.
- The `silenced` payload carries typed arrays (`Array[Dictionary]`, `Array[String]`), so `EventLog.append` takes the slower coercing copy (`event_log.gd:173–184`). The result is correct but slower; see nit N5.

---

## Findings — Story 015 (freeze, thaw and Silence)

**Blocking: none.** The thaw timing is correct. It runs at End step 4, after the `on_turn_end` hooks and before the `end_of_turn` expiry (`rules_engine.gd:2380`, `:2525–2535`), and M1/M3 are killed. Silence's steps 1–6, the F6 clamp and the exclusions match C13. A trigger already queued when its source is Silenced still resolves (P8: `trigger_queued ×2 → trigger_resolved → silenced → trigger_resolved → ran`), which agrees with card-effects C6.5 "queued = earned".

**S1 (should-fix, cross-epic → match-ui): after Silence the board shows stale stats and keywords.**
- Where: `src/ui/match/match_view_state.gd:458–466` (`"silenced"` only sets the flag and adds a badge step), against the new `silence` at `rules_engine.gd:1132–1156`.
- Why it breaks now: Silence removes enchantments and keywords and clamps damage **without** emitting `enchantment_removed`, by design (one `silenced` event). The view-state is a pure event projection (ADR-0001), and match-ui GDD line 191 says `silenced` updates "Stats, keywords, flags".
- Scenario: a 2/2 Taunt is buffed +2/+2 (the view shows 4/4) and then Silenced. The engine now has 2/2 and no keywords. The view still shows **4/4 with a Taunt badge**, so the player believes they must attack it.
- Fix: in `MatchViewState`, apply `payload.removed_enchantments` as removals (attack and max-health deltas), erase `payload.removed_keywords`, and clamp health to the new maximum. Alternatively, add the post-Silence `attack, health, max_health` to the `silenced` payload (as `minion_modified` does) and record that in C15.

**S2 (should-fix, GDD decision + one-line fix): the F6 Silence clamp creates damage when it removes a health *debuff*.**
- Where: `rules_engine.gd:1154`. It implements F6 literally: `damage_taken − (old_max − new_max)`.
- How it fails: when `old_max < new_max` (a negative `health_delta`, or `set_stats` "set health to 1"), the subtracted term is negative, so `damage_taken` grows.
- P7, case 1: a 3/5 with a −2 health debuff and no damage, Silenced, becomes **max 5, health 3, damage_taken 2**. An undamaged minion now carries 2 "damage" that a later heal would "restore".
- P7, case 2: a 4/4 with 2 damage takes `set_stats(health 1)` and is then Silenced. It ends at **max 4, health 1, damage 3**, whereas Hearthstone's Hunter's Mark plus Silence gives 4/4.
- Latency: no shipped card uses a negative health delta or `set_stats` today, but the primitive exists (C9).
- Fix: GDD F6 should read `damage_taken' = max(0, damage_taken − max(0, old_max − new_max))`, or explicitly confirm the current reading. Then change line 1154 to `maxi(0, old_max - max_health(minion))` and add a test.

**S3 (should-fix, cross-GDD conflict, resolve before card-effects story 009 starts): Deathrattle after `destroy` then `silence` in one effect.**
- What happens: `_death_check` snapshots the minion *after* the Silence (`rules_engine.gd:2865`). Both the double (`test_effect_resolver.gd:333`) and the production resolver (`effect_resolver.gd:483`) skip a snapshot with `silenced` set, so P9 shows `silenced, minion_died` and **no Deathrattle**.
- Which document agrees: match-rules C12 ("not if Silenced before [death]") agrees with this. card-effects story 009 **AC-21** demands the opposite for exactly this sequence ("Deathrattle still resolves (queued = earned)").
- Fix: decide in the GDDs. Either C12 wins (amend card-effects AC-21), or the engine must raise the Deathrattle at `destroy()` / mark it earned when `pending_destroy` is set. Then pin it with a match-rules test.

**S4 (should-fix, test gap): a damaged recipient of a received aura is not covered.**
- Where: `match_rules_freeze_silence_test.gd:355` uses undamaged minions, so M12 (Silence strips received auras too) survives.
- Why it matters: in that mutant, F6 clamps against the aura-inclusive maximum, and `recompute_auras()` then re-adds the aura. Silence **heals** the minion: a 2/2 with a +2 health aura and 3 damage goes from health 1 to health 3. The current code is correct; nothing pins it.
- Fix: add one test, "damaged minion with a received aura, Silenced: `health` unchanged, `damage_taken` unchanged, aura not in `removed_enchantments`".

**Nits**
- N1: The thaw rule reads `attacks_remaining` at the End step (`:2531`), per the GDD letter. P10 shows two consequences: a Windfury minion frozen after one of its two attacks stays frozen through its next turn, and a summoning-sick minion frozen on its own turn does too. Whether this matches Hearthstone is UNVERIFIED, so this is a design question, not a defect.
- N2: No match-rules test pins P8's behaviour (a queued trigger of a later-silenced source resolves). card-effects 009 AC-21 will cover the Deathrattle half; add the queued `turn_end` or `on_damage` case there or here.
- N3: The `silenced` payload's `removed_enchantments` are full value copies (`:1147`), so log size grows with enchantment count. This is fine at v1 scale.

## Findings — Story 017 (clone and replay)

**Blocking: none.** P1 found no shared mutable state. P2 found the clone, clone-of-clone and live engine identical over 40 commands × 11 states. Both the double and the production resolver were exercised, including a paused Discover resumed on the clone only.

**S5 (should-fix, test gap): isolation is never exercised with a non-empty `suspended_queue`.**
- Where: `_do_choose` clears the parked queue **in place** (`rules_engine.gd:2690`, and `_abandon_choice` at `:2725`).
- Scenario: if `MatchState.clone` (`match_state.gd:134`) ever regressed to sharing it (M5), a planner's `choose` on the clone would wipe the live engine's queued triggers. The live boss Discover would then resume with its Deathrattles or observers gone, and replay would diverge.
- Why the suite misses it: every paused fixture has Q empty, so M5 survives the 294-test suite. M6, M7 and M11 also survive, because the engine only reassigns those fields today.
- Fix: add a paused fixture with triggers waiting in Q (for example, a Discover raised by the first of two queued `on_minion_died` observers) to `test_twenty_commands_on_a_clone_…`, and add P1's no-alias walk as a permanent test. It kills M5–M7 and M11 structurally.

**S6 (should-fix, decision needed): AC-39 is not met as written. `submit` ignores stray arguments that `legal_commands()` never lists.**
- Where: `rules_engine.gd:1935–1940` checks `position` only for minions, and `:1963–1975` returns `""` for `none` targeting before looking at `target_id`, and for a `required` Battlecry with no legal target.
- Scenario: `play_card(spell, position: 3)` and `use_hero_power(target_id: 7)` on a `none` power are **accepted**, although they are absent from `legal_commands()`. AC-39 says such commands are rejected. The test canonicalises them away (`match_rules_clone_replay_test.gd:370–391`). The Mulligan has the same property: any valid mask is accepted, but only keep-all is listed.
- Impact: a UI or AI that sends a malformed command gets silent acceptance instead of a typed rejection.
- Fix: preferably reject (`INVALID_POSITION` for a non-null position on a non-minion, `ILLEGAL_TARGET` for a non-null target on `none` or a target-less Battlecry) and drop the canonicalisation from the test. Otherwise, amend C2 and AC-39 to state the don't-care arguments and the Mulligan exception. Either way, record the choice.

**S7 (should-fix, tracking + latent divergence): the `RngStream` copy depends on private members, and `RngStream.copy()` has no owning story.**
- Where: `_copy_stream` (`rules_engine.gd:3492–3501`) reads `source._stream_seed` and calls `_make_child`. Its `TODO(rng-event-log)` names an epic, but no rng-event-log story mentions `copy()` (grep of `production/epics/rng-event-log/`).
- The fork memo `_forks` is dropped. P3: after `live.rng_match().fork("x")`, the clone's `fork("x")` draws (42 → 43) while the live engine's does not, and every later draw differs. This is latent, because nothing forks `rng_match` (DD-T03).
- Fix: add an rng-event-log story for `RngStream.copy()` that reproduces the fork memo (the snapshot's `fork_points` semantics) and keeps O(draws). Point the TODO at it, and assert in `_copy_stream` that `_forks` is empty until then.

**S8 (should-fix, route to story 018, boss-ai F7 and ADR-0006): the clone and submit costs fall far outside the planner's assumed budget.** The numbers are in BAI note 2. `clone()` is about 15% of the per-candidate cost, and `submit` is the rest. This needs no code change in 017. Story 018 should measure both on a release template, boss-ai F7's `t_sim ≈ 0.01 ms` should be re-derived, and `lethal_max_nodes` / `max_evals_per_action` re-budgeted before BAI tuning. The O(draws) stream copy is the one cost `clone()` adds itself; it is small at realistic draw counts (≤ 300 draws ≈ 30–40 µs).

**Nits**
- N4: The scratch-log cap uses the live log's remaining room (`:3481`), and `_torn_down` is copied (`:3447`). Both are contract clauses in the doc comment that no test covers (M8 and M9 survive). Add two small tests. M9's failure mode is a clone of a torn-down live engine that accepts commands with an unbound resolver.
- N5: The scratch log's `seq` restarts at 1, but a resumed action stamps live `cause_seq` values (P5). Add one sentence to the `clone()` doc: "provenance in the scratch log is not navigable across the clone point".
- N6: `clone()` of an Ended or torn-down engine still constructs a resolver it never binds (`:3444–3448`). This wastes one allocation; build it only when `_bound`.
- N7: The `not _resolving` guard is a debug `assert` only (`:3443`). A release-build clone taken from inside a resolver callback would silently drop `_queue`/`_stages`. Consider returning null with `push_error` in release.

---

## Positive Observations

- The `clone()` doc comment is a real contract (When / State / Hooks / Resolver / Log / RNG / Ended / Lifetime) with a correct planner example. Boss AI can build on it as written.
- `MatchState.clone` is a short, explicit field list, and P1 shows it is complete.
- The story-016 decision to keep the paused action as plain data paid off: a clone resumes a Discover exactly.
- AC-38 records its 200 commands from a deterministic policy and asserts the AC's shape (all types, ends in `concede`), so the test cannot pass vacuously. The fixtures assert their `expect` block.
- The completion notes are honest about deviations (stray arguments, fork memo, private-member copy). They were the starting points for S6 and S7.
- Story 015's thaw rule is one comparison with no hidden counter, and the stage ordering is pinned by an order test (M3 killed).

## Required Changes

None blocking.

## Suggestions

S1–S8 are should-fix.
- **First**: S5, because it guards the exact sandbox BAI-004 starts on, and S8, because it decides whether BAI-004's budgets are reachable.
- **Before card-effects 009 starts**: S3.
- **Before Silence is playable in the match UI**: S1.
- **Needs a design decision**: S2 and S6.
- **Tracking**: S7.
- N1–N7 are nits.

## Verdict

| Story | Skill verdict | Substantive |
|---|---|---|
| **MR-015** freeze, thaw, Silence | **NOT ASSESSED**: the engine-specialist and qa-tester passes could not run | No blocking defects. 4 should-fix: S1 UI projection, S2 F6 debuff clamp, S3 Deathrattle GDD conflict, S4 test gap |
| **MR-017** clone and replay | **NOT ASSESSED**: same reasons; the perf guardrail has no data (story 018) | No blocking defects; isolation and equivalence verified. 4 should-fix: S5 test gap, S6 AC-39 strictness, S7 `RngStream.copy()` tracking, S8 budget routing |

Under the skill's rule, NOT ASSESSED outranks both approvals because the engine-specialist review did not run. If that pass ran and agreed, both stories would read **APPROVED WITH SUGGESTIONS**.

## Scratch artefacts

All of these are in `/tmp/claude-0/-home-user-dungeon-run-ccg/cb1e7c62-c2a7-52ec-b886-47b571cec227/scratchpad/`:
- `rv4c_snap/`: a `git archive` of HEAD `29146bf`.
- `rv4c_snap/tests/rv4c_probe/rv4c_probe_test.gd`: probes P1–P11.
- `rv4c_mut.py`, with `rv4c_engine_orig.gd` and `rv4c_state_orig.gd` as its restore sources.
- `rv4c_mut_a.log` and `rv4c_mut_b.log`: the mutant results.
- `rv4c_probe.log` and `rv4c_probe2.log`: the probe output.
- `rv4c_import.log`, `rv4c_suite.log` and `rv4c_smoke.log`: the baseline logs.
