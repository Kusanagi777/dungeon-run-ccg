# Code Review: match-rules 011 (effective cost, temporary crystals) and 016 (Choice phase, Discover)

**Date**: 2026-11-04. **Reviewer**: independent session. `/code-review` followed by hand from `.claude/skills/code-review/SKILL.md`; the skill cannot be model-invoked.
**Commits**: `47ccfec` (story 011) and `023647c` (story 016), plus the story-016 AC-order commit `52c6012`.
**Code reviewed**: `src/gameplay/match/rules_engine.gd`, `match_state.gd` and `match_records.gd` at `52c6012`, where `rules_engine.gd` is identical to `023647c`. Every `file:line` below refers to that revision.
**Branch moved during the review.** HEAD is now `aa7f110`, which merges match-rules 012–014 (the attack handler on the staged model). That merge does not touch any function cited here (`_do_choose`, `_abandon_*`, `start`, `_run_inline_hooks`, `add_mana`, `_expire_end_of_turn`, `_fold_cost`, `_cast_spell`, `_park`). Every finding therefore still applies at HEAD, but line numbers there are shifted by about +230 below line 1500.
**Standing approval**: the owner gave it. No questions were asked, and no source, test or story was edited.

---

## Inputs

| Input | Status |
|---|---|
| Story files 011, 016 (incl. quick-design 2026-11-04 AC and its order correction) | FOUND |
| GDD `match-rules.md` §C1, C2, C4, C5, C6, C10, States/Transitions, F1 (read by section) | FOUND |
| ADR-0007 Status/errata + Decision + Key Interfaces + Implementation Guidelines | FOUND |
| ADR-0008 Status/errata + the Choice-related Decision rows (grep) | FOUND |
| ADR-0005 (story 011's governing ADR) — via control manifest Core rules only | FOUND (manifest); ADR body not re-read |
| Control manifest §Core Layer Rules (Required / Forbidden / Guardrails) | FOUND |
| Diffs `git show 47ccfec 023647c` | FOUND |
| Story `## QA Test Cases` | ABSENT — "N/A — no qa-lead specs at this tier" |
| Match-rules performance test (submit ≤ 5 ms, legal_commands ≤ 2 ms) | ABSENT — `tests/performance/` holds only match_ui and rng_event_log |

## Baseline (main repo, before any probe)

- `godot --headless --path . --import` → exit 0.
- `commands.test` → **1163 test cases, 0 errors, 0 failures, exit 0**. There are 85 `SCRIPT ERROR` lines, all from `card_database.gd`, `rng_stream.gd`, `event_log.gd`, `rng_service.gd`, `card_database_freeze_test.gd` and `boss_ai_planner_task_test.gd`, which are existing intentional negatives. None comes from `src/gameplay/match`.
- `commands.smoke` (`godot --headless --quit-after 5`) → exit 0, no `SCRIPT ERROR`.
- Non-blocking performance suite: 3 cases pass. None of them covers match rules.

## How the review verified behaviour

The review did not edit the main repo. All work ran in a scratch snapshot exported with `git archive 52c6012`:
- `scratchpad/rv4_snap/`: import exit 0, full suite 1163/1163 plus the probes.
- Probe suite `rv4_snap/tests/rv4_probe/rv4_probe_test.gd`, probes P2a–P11. Each probe pins the observed behaviour.
- Mutant runner `scratchpad/rv4_mutant.py`. It applies one textual mutation to the snapshot's `rules_engine.gd`, runs the full blocking suite, and restores the file from `scratchpad/rv4_engine_orig.gd`. Each run checks that the restore happened.

| Mutant | Full-suite result |
|---|---|
| M1 `card_to_graveyard` stage moved before the `after_cast` observers | **SURVIVES** (1163 pass) |
| M2 no `_drain()` after `resume` | killed (step-cap test) |
| M3 drain the paused step | equivalent: `_drain` itself returns while suspended (`:2414`) |
| M4 resume under `cause_seq = 0` | killed |
| M5 expiry leaves `mana_current` | killed |
| M6 temporary `mana_current` not clamped | killed |
| M7 no upper bound on `option_index` | killed |
| M8 side-less `effective_cost` assumes `"player"` | **SURVIVES** |

---

## Engine Specialist Findings: NOT ASSESSED

`godot-gdscript-specialist` (`specialists.code`) and `godot-specialist` (primary) could not be spawned in this session. As a substitute, the reviewer checked the engine behaviour the change relies on with the headless scripts above, on Godot 4.7.2:

- `Array[Dictionary].assign(untyped Array)` behaves correctly round-trip through park and choose.
- `duplicate(true)` gives deep copies of stages and frame.
- `pop_front()` into a typed parameter works.
- `Callable.bind` is used only for locals and is never stored in state.
- `assert_json_representable` passes over every plain `MatchState` field while paused.

No post-cutoff API is used. Confidence: VERIFIED for these points only. This is not a substitute for the specialist pass.

## Testability: GAPS (qa-tester NOT ASSESSED; review done by the reviewer)

The `qa-tester` agent could not be spawned, and the story has no QA Test Cases. The reviewer mapped each AC to its tests and ran the mutants.

- Story 011 has 13 tests. They cover F1, the fold order, the hero power and AC-45. M8 shows the side-less `effective_cost(card)` path is untested (nit N6).
- Story 016 has 11 tests and covers the guards, the parking, the cause chain and the step cap. **The quick-design AC's `after_cast` → `card_to_graveyard` order is not asserted anywhere in the suite** (S1). There are also no regression tests for the new pause sites the refactor created: End-step pause, step-boundary hook-entry pause, and a second Discover raised inside `resume`. The reviewer verified all three by probe and found them correct (N7).

## ADR Compliance: COMPLIANT (minor deviations)

- **ADR-0007 Decision 1 / Guidelines**: COMPLIANT.
  - The continuation is plain data on `MatchState` (`suspended_queue`, `suspended_steps`, `suspended_action{origin_phase, cause_seq, frame, stages}`).
  - The engine owns `Choice` and `pending_choice.side`, and `resume(choice, index)` runs on `choose`.
  - No Callable, Node or object is stored. `_stages` and `_frame` hold ids, never records (`_accept_stage`, `:2291`).
  - One effect pass is one step, and no death check runs inside the paused pass (`:2400`, `:2414`).
- **ADR-0008**: COMPLIANT. The engine does nothing special for a boss-side choice, and nothing calls the AI from `submit`.
- **ADR-0005 (011)**: COMPLIANT.
  - There is one clamp, after the whole fold (`_fold_cost`, `:661–668`).
  - The fold context is a reused Dictionary, with no allocation per call.
  - `side` is passed on every call, and nothing is special-cased for the player.
  - MINOR DEVIATION (INFO): the shared `_cost_ctx` is not re-entrant (N4).

## Standards Compliance: 5/6 passing

- Doc comments: present on every public method (`effective_cost`, `hero_power_cost`, `add_mana`, `discover`, `choose`).
- **Complexity / length: FAIL (nit N5).** `_run_stage` (`:2245–2288`) is a 15-arm `match`, about 44 lines, with cyclomatic complexity above 10.
- Dependency injection, data-driven values (`max_mana`, `hero_power_cost`, `resolution_step_cap` from `rules_config`) and interface use all pass.

## Architecture: MINOR ISSUES

The staged-command model is a sound way to make every handler pausable without coroutines or Callables in state. It gives Story 017's `clone()` a `duplicate(true)` of three fields. The minor issues are pause sites the model does not cover: in-primitive hooks (S2) and `start()` (S3).

## SOLID: COMPLIANT (with an existing concern)

`RulesEngine` is now about 3000 lines and owns commands, stages, primitives and the loop. That Single Responsibility pressure is not new to these stories. Splitting out the stage and choice machinery into a `CommandStages` helper is a later refactor, not a defect.

## Game-Specific Concerns

- No frame-time code is involved.
- Allocation: `submit` allocates its stage Dictionaries once per command, which is acceptable.
- Performance guardrails (submit ≤ 5 ms, legal_commands ≤ 2 ms): **NOT ASSESSED — NO DATA**, because no match-rules performance test exists. One observation, not a verdict: P11 measured `legal_commands()` with 10 hand cards and a 12-entry `modify_cost` fold at a mean of 783 µs. That was a debug build with the recording `TestEffectResolver`.

---

## Findings

### Story 016 — Choice phase and Discover

**S1 — should-fix. The AC's `after_cast` before `card_to_graveyard` order is untested, and the completion note claims it is tested.**
- **Where**: `tests/unit/match_rules/match_rules_choice_test.gd:193–195` (only `added < dealt`, `dealt < observed` and `dealt < to_graveyard` are asserted). Also `match_rules_play_card_test.gd:340–348`: for a spell that is not paused, it checks event types and resolve calls separately and never compares the two.
- **Claim**: completion note line 117 says "the test asserts … that `after_cast` precedes `card_to_graveyard`".
- **Failure scenario**: mutant M1 swaps the last two stages of `_cast_spell` (`rules_engine.gd:1817–1818`). That reverses the GDD C6 order, which is the exact order the 2026-11-04 correction fixed, and **all 1163 tests still pass**.
- **Current behaviour**: correct. P9 observed `choice_made, phase_changed, card_added_to_hand, damage_dealt, after_cast-pass, card_to_graveyard`.
- **Fix**:
  - Add `assert_int(int(observed[0].seq)).is_less(int(to_graveyard[0].seq))` after `:195`.
  - Add the same comparison of the `after_cast` trigger and `card_to_graveyard` seqs in the story-010 spell test.
  - Watch both fail under M1, then correct the completion note.

**S2 — should-fix (latent in v1 content). In-primitive hook points keep running after a pause.**
- **Where**: `rules_engine.gd:2131–2135` (`_run_inline_hooks` → `HookRegistry.run_triggers`, `hook_registry.gd:152–156`, which loops over every entry), and `_draw` `:780–807` (the per-card loop checks only `_halted()`).
- **Failure scenario 1 (P2a, verified)**: a treasure installs two `on_draw` entries, `[discover, gain 1 armour]`. The player's Start-step draw fires the hooks. Entry 0 raises the request and the phase becomes `choice`, but entry 1 still runs, so `armor_gained` is in the log while the choice is pending and before any `choose`.
- **Failure scenario 2 (P2b)**: in a multi-card `draw(side, 2)`, the second card is drawn (`card_drawn` ×2 after `choice_requested`). If the second card's hook Discovers too, that request is refused with `push_error` and dropped.
- This breaks the contract in the `discover` doc: "nothing else may happen until it does".
- **Reachability**: no v1 treasure Discovers on `on_draw`, `on_hero_damaged` or `on_minion_summoned`, and the real `run_hook_effect` is a stub until card-effects 015.
- **Fix, either of**:
  - (a) Make Discover illegal at in-primitive hook points: `EffectValidator` `E_FX_OP_UNAVAILABLE` for `discover` / `choose_one` under those triggers, plus `discover()` refusing while an inline point is marked in `_hook_points_running`. Record this in the card-effects GDD.
  - (b) Park the inline continuation as plain data `{point, next_index, side, ctx}` and stop `_draw` at `_suspended()`.
  - (a) is the cheaper option and matches C6.0 ("no C10 loop inside a primitive").

**S3 — should-fix (latent). A Discover raised during `start()` corrupts the match.**
- **Where**: `rules_engine.gd:468–476`. `on_match_start` runs through `_run_hook_steps`, then `_draw` and `_state.phase = PHASE_MULLIGAN` run unconditionally.
- **Failure scenario (P3, verified)**: an `on_match_start` treasure Discovers. After `start()`:
  - `phase == "mulligan"`, `pending_choice` is still set, and `suspended_action.origin_phase == "setup"`.
  - `choose(player, 0)` is rejected `WRONG_PHASE`.
  - Because `discover()` refuses while `pending_choice != null` (`:1276`), **every later Discover in the match (Battlecries, spells) is silently refused**.
- The story's Deviations section says `start()` is not staged but does not mention this outcome.
- **Fix**: in `discover()`, refuse a request raised outside a staged command or step (`phase == setup`, or no `_resolving` command): `push_error`, return `{}`, and leave the state untouched. Alternatively, build C3 steps 4–6 as stages. Add a test.

**S4 — should-fix (edge). An event cap on `choice_made` leaves the paused spell in `resolving`.**
- **Where**: `rules_engine.gd:2333–2335`. `_do_choose` emits `choice_made` and returns on `_halted()` before restoring `_stages` (`:2343`), so `submit`'s `_abandon_stages()` finds nothing to clean up.
- **Failure scenario (P10, verified)**: a spell is paused, and the log is exactly at `max_match_events`. `choose(0)` returns accepted with phase `ended`, reason `event_cap`, and `players.player.resolving.size() == 1`; the stages are still parked in `suspended_action`.
- This reverses the 2026-11-03 code-review fix: "a fault still moves the card out of `resolving`".
- **Fix**: take the stages and frame out of `suspended_action` before the emit, or call `_abandon_choice()` on that early return so `_abandon_stages()` sees `STAGE_SPELL_DONE`. Add a test with `TestEventLog.max_events`.

**N1 — nit. The hook re-entry guard is not held across the resumed half of a hook entry.**
- **Where**: `:2118–2122`. `_hook_points_running[point]` is cleared when the paused entry returns, and `resume` runs the entry's later ops without the mark.
- **Scenario (P7)**: an `on_draw` hook "Discover, then draw a card" never faults `resolution_overflow`. It re-prompts once per card until the deck is empty.
- This is not a stack hazard, because each round needs a `choose`, but it contradicts the ADR-0005 erratum's "a self-feeding hook ends the match as a fault".
- **Fix**: record the running points in `suspended_action` and restore them around `resume`, or note the exception in the erratum.

**N2 — nit.** `concede` in `Choice` (`_abandon_choice`, `:2358–2366`) leaves `state.effects.pending_choice`, the resolver's own continuation, set on the Ended state. This is harmless, but card-effects 010 should clear it on `unbind`, or the engine should null it, so that "concede abandons it" holds for all the data.

**N3 — nit.** The `"choice"` arm of the phase guard (`:1570–1573`) returns `NOT_YOUR_TURN` for an issuer that is not a side at all, whereas the `"active"` arm returns `WRONG_PHASE`. Make the two consistent.

**N4 — nit (011/016 hand-off).** The production `EffectResolver` has no `resume()` yet, and `_resolver` is `Variant`. A choice raised before card-effects 010 lands would end in a "Nonexistent function" runtime error at `:2348`. This is unreachable today, because the production resolver never calls `discover`. Add it as a 010 entry criterion.

**N5 — nit.** `_run_stage` (`:2245–2288`) is over the 40-line and complexity-10 standards. Split it into a turn-stage dispatcher and a play-stage dispatcher.

**N7 — nit (test coverage).** No test covers these paths, though the probes verified each one correct:
- A Discover in the End step (P6: resumes expiry, `turn_ended` and the boss Start step).
- A second Discover raised inside `resume` (P5: parks again, `after_cast` and the graveyard move run once).
- A pause inside a step-boundary hook entry.

These are the refactor's new seams. The P5 and P6 shapes can be copied into tests.

### Story 011 — effective cost and temporary crystals

**S5 — should-fix (latent). Temporary crystals granted on the opponent's turn outlive the refill and then cut `mana_max` below F4.**
- **Where**: `add_mana` `:830–837` records `temporary_crystals` on the receiving side. Only that side's End step clears it (`_expire_end_of_turn`, `:2184–2188`). The Start-step refill (`:2031`) overwrites `mana_max` but keeps `temporary_crystals`.
- **Failure scenario (P4, verified)**: during boss turn 2, the player gains 2 temporary crystals and reads 3/3 with temp 2. At the player's Start step the reading is 2/2 with temp still 2. At the player's End step `mana_max` becomes 2 − 2 = **0** and the reading is **0/0**, below F4's 2. The next Start then emits `crystal_gained {gained: 3}` instead of 1.
- **Reachability**: v1's two sources, `decay_soul_tithe` and `neutral_treasure_map`, are own-turn spells. Any reactive or off-turn `mana` op would hit this.
- **Fix**: zero `temporary_crystals` at the Start-step refill, which already discards them by F4. Ask the GDD owner whether "until the end of the current turn" should mean the active side's End step for off-turn grants, and record the answer in C5. Add a test.

**N6 — nit.** The side-less `effective_cost(card)` path (`:644`, `_owner_of`) is untested: mutant M8, which hard-codes `"player"`, survives. Add a test with a boss hand card and a side-scoped `modify_cost` hook, called without a side.

**N8 — nit.** `_cost_ctx` (`:299`, `:661–668`) is one shared mutable Dictionary. A fold evaluator that calls `effective_cost` or `hero_power_cost` (for example, a condition reading another card's cost) would overwrite `ctx.card` and `kind` for the outer fold's later entries, then null them. This is latent because the real `apply_value_hook` is a stub until card-effects 014. **Fix**: save the previous `card` and `kind` into locals and restore them after the fold. That adds no allocation.

**N9 — nit.** When the clamp applies, `mana_current` rises by `n` while expiry removes only the recorded `gained`.
- 5/9 + 3 gives 8/10, and expiry leaves 7/9 rather than 5/9.
- 9/10 + 2 gives 10/10, and nothing expires.
- This matters only if something reads `mana_current` off-turn before the next refill. Either document it in the `add_mana` doc or clarify the C5 wording "reduced by the same amount".

---

## Positive Observations

- The plain-data stage model is well executed:
  - Stages carry ids, not records, and the frame is the only cross-stage memory.
  - Park and choose restore Q, `_steps`, the frame and the stages symmetrically.
  - `cause_seq` continuity holds; this was verified by M4 and by the existing test.
- The step cap counts across the pause, which M2 and the existing test prove.
- A second Discover inside `resume` re-parks cleanly (P5).
- The double guard in `_run_step` (`:2400`) and `_drain` (`:2414`) makes the "no death check after an unfinished pass" rule robust (M3 is equivalent).
- `pending_choice()` and the `choice_requested` payload are value copies, and the request's options are deep-duplicated.
- F1 is clean: one clamp, no allocation in the fold, hero power through the same pipeline, and display and payment sharing one function. The 011 test set kills four of the five mutants aimed at it.
- Both completion notes record their mutant runs and deviations honestly. The one exception is the S1 claim.
- The later 012–014 merge took up the 016 hand-off: the attack handler is now staged.

## Required Changes

None blocking.

## Suggestions

S1–S5 are should-fix. S1 is the most direct: a one-line test that pins the order the AC was corrected for. Fix S2 and S3 before card-effects 010 and 015 give the real resolver Discover and hook effects. Fix S5 before any off-turn `mana` content exists. N1–N9 are nits.

## Verdict

| Story | Skill verdict | Substantive |
|---|---|---|
| **MR-016** Choice / Discover | **NOT ASSESSED**: specialist and qa-tester passes could not run, and the perf guardrail had no data | No blocking defects. 4 should-fix: S1 test gap, plus latent pause holes S2, S3, S4. Reached by v1 content (Battlecry, spell, repeat), the behaviour is correct |
| **MR-011** effective cost / temporary crystals | **NOT ASSESSED**: same reasons | No blocking defects. 1 should-fix (S5, latent off-turn temporary crystals) and nits |

Under the skill's rule, NOT ASSESSED outranks the approvals because the engine-specialist review did not run. Once that pass runs and agrees, both stories would read **APPROVED WITH SUGGESTIONS**.

## Scratch artefacts

All of these are in `/tmp/claude-0/-home-user-dungeon-run-ccg/cb1e7c62-c2a7-52ec-b886-47b571cec227/scratchpad/`:
- `rv4_snap/`: the snapshot of `52c6012`.
- `rv4_snap/tests/rv4_probe/rv4_probe_test.gd`: the probes.
- `rv4_mutant.py`, with `rv4_engine_orig.gd` as its restore source.
- `rv4_test.log`, `rv4_import.log`, `rv4_smoke.log`: the baseline logs.
- `rv4_mut/`: a stale working-tree copy taken while the branch moved. **Ignore its results.**
