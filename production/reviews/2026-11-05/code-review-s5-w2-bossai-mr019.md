# Sprint 5 wave 2 code review: BAI-011, BAI-009, MR-019

**Reviewer**: lead-programmer, independent. **Tree**: `bootstrap/ccgs-template` at `f4aff0e`, main checkout. All named commits are ancestors of it.
**Method**: `.claude/skills/code-review/SKILL.md` followed by hand. Static review only: no edit, no commit, no merge, no Godot run.

| Story | Verdict | Blocking findings |
|---|---|---|
| BAI-011 forecast and telegraphing | **CHANGES REQUIRED** | 1 defect (D1) |
| BAI-009 defensive mode, A31 | **CHANGES REQUIRED** | 1 defect, test evidence only (D2) |
| MR-019 performance pass | **APPROVED WITH SUGGESTIONS** | None. The story stays BLOCKED on AC-3 and AC-4 under its own close rule |

## What this review could not assess

- **Nothing was executed.** Every "passes" or "green" below is the story's claim, or my reading of the code. The stories' mutant lists are unverified.
- **D1's scores are worked by hand** from shipped weights and cards. The code path is traced; the numbers are not measured.
- **Release-template figures** (AC-3, AC-4, AC-40): none exist. Debug figures were taken on a loaded machine.
- **Goldens across OS**: the QA plan asks for this before M2. It has not been done (Windows only).
- **A22 forecast p95**: BAI-016's, not measured.
- **The forecast in the driver**: no driver row runs a forecast yet (story 014), so `ai_intent_shown` is appended nowhere in `src/`. Stale discard, deferred telegraph changes and "one task at a time" are read from ADR-0008 and the manifest, not from code.
- **`Dictionary[int, int].duplicate()` keeping its type on 4.7**: NOT SOURCEABLE from `docs/engine-reference/godot/`. `clone()` runs it on every node, so a failure would be loud, but I did not see that run.
- **Specialist coverage**: the `godot-gdscript-specialist` hit its turn limit once and was told to report what it had. It did not reach `lethal_search.gd`, `chooser.gd`, `candidates.gd`, `turn_plan.gd` or the tests. I read the parts of those that bear on these stories, not all of them.

---

## Code Review: BAI-011 forecast and telegraphing (`2a6900a`)

### Engine Specialist Findings: CLEAN
No confirmed defect from `godot-gdscript-specialist`. Its observations, checked:
- `last_choice` overwritten by an overlapping task: dropped. Manifest line 193 runs a boss Choice only with no task live.
- `effective_mode()` read after the awaits: dropped. ADR-0008 Decision 7 sets the mode only with no task live.
- Unknown `defensive_multipliers` key: dropped. `boss_ai.gd:1119` rejects it at load.

### Testability: GAPS
Traced by qa-tester, each checked by me against the test and the code. Non-blocking except where D1 cites one.
- **`boss_ai.gd:553`, "draws only from the fork" (AC 3).** `test_the_forecast_takes_one_parent_draw_and_never_moves_the_live_game` (`boss_ai_forecast_test.gd:411`) checks only that the live stream did not move. A clone without the override passes that too, and then a random effect on the dry run draws the live stream's next values. No fixture has an engine-random effect, and shipped `neutral_spark_fiend` is one. The two fork tests cover ties and `score_all`, not `rng_match` on the dry run.
- **A19 `target_id` null.** Every `class_only` and `hidden` case at `:125`, `:139`, `:158` is `attack_face`, whose target is null anyway. Moving `intent.gd:63` out of its `if` would pass.
- **C8.2 `kept` by class** (`:255`): no case has one key with a different amount or target.
- **`amount` hides a buff** (`:530`): no fixture has a buff, so reading attack at play time at `boss_ai.gd:728` would pass.
- **First lethal step** (`:484`): no plan mixes lethal and other rows.
- **A19 "no `ai_intent_shown` is emitted"**: only `is_shown()` is checked. The story says so, and story 014 owns the append.

### ADR Compliance: DRIFT
- ADR-0006, ADR-0008: the clone, seam and required task are followed. `forecast_task` reads the log on the main thread and the fork is taken in the task body, which the manifest allows (line 240).
- Control manifest "the intent is never fabricated" and "Hidden: which card will be played": **drift**, see D1.

### Standards Compliance: 6/6
Doc comments present. `big_minion_cost` is C8.3's number in `Scorer.NORMALISERS`.

### Architecture: CLEAN
### SOLID: COMPLIANT

### Game-Specific Concerns: hidden information
**The player's hidden state: no exposure traced with shipped content.**
- `Scorer._measure` fills `hand_defs` only for `own` (`scorer.gd:518`); the opponent contributes a hand count, which C1.3 allows.
- `LethalSearch` reads the hand of `own`.
- `score()` does not simulate `end_turn`, so no trial draws the player's deck.
- The player's End step on the clone runs expiry and thaw. No shipped effect fires there: both `turn_end` effects are boss-owned, and `treasures.json` has no records.

**This protection is by absence, not by design.** `boss_ai.gd:670` runs the player's End step on the real hand and deck. The first player-side End-step effect that draws or reads the hand makes the plan depend on hidden cards, and nothing guards that. Put BAI-012's A4 "identical except the player's hand and deck" fixture on `forecast` as well as on the plan.

**The clone reaching the boss's Main: sound for the Start step, not for the plan.** Mana, thaw and reset attacks come from the engine. `discard` fires no trigger (`rules_engine.gd:1676`), so dropping the Start draw has no side effect beyond one extra graveyard card, and no effect reads the graveyard. `dry_run` is ended on every path: `shutdown()` polls a live task to its end, so an abandoned time-sliced forecast does not leak. The plan half is D1.

### Positive Observations
- `Intent` is plain data with no engine reference, so nothing live crosses back from a worker.
- `amount` uses the attack from when the plan began, so a buff in hand reveals nothing. After Start, so Hollow King's public +1/+1 is counted correctly.
- Letting the engine's own End and Start steps run avoids a second copy of F4, C13 and attack reset.
- `TurnPlan.checksum` skips the intent events by type, and the merged BAI-015 driver uses that one function on both sides.
- The author recorded the A4 conflict instead of bending a test around it.

### Required Changes

**D1. Defect: the forecast's plan reads the real deck after a mid-plan draw.** `src/ai/boss_ai.gd:557` and `:672` (drop runs once), `:795-803` (no drop after an accepted action). Confidence: **VERIFIED by trace; scores worked by hand, not run.**

`_drop_new_cards` runs once, in `_begin_own_turn`, before the plan. If the dry run then plays a card that draws, `_draw` pops the real deck (`rules_engine.gd:922`, no RNG involved) and the next `_plan_pass` sees that card in `legal_commands()`. This breaks AC 3 ("its current hand"), C1.3 ("never reads ... either `deck` order") and C8.4.

Reachable on floor 1: `boss_ember_bolt` (`assets/data/cards_boss.json:22`, cost 1, deal 1, draw 1) is in `boss_torchbearer`'s deck.

Scenario, default weights (`w_face` 1.5, `w_board` 2.0, `w_mana` 1.0):
1. Forecast mana 4; boss has an able 3/1 and holds Ember Bolt; player at 6 health with an empty board.
2. Dry run: attack face (0.75), then Ember Bolt (0.75, the earlier row wins the tie). 3 mana left.
3. If the second deck card is `neutral_dungeon_delver` (cost 3, 3/4), it is played at about 2.15 and the Intent is `develop_board`, `amount` null.
4. If it is `neutral_crypt_brute` (cost 4), it cannot be played and the Intent is `attack_face`, `amount` 3.

Same public state, two banners, decided by an undrawn card: the player can read the boss's deck from the Intent.

`test_the_forecast_plans_the_current_hand_and_never_the_deck_top` (`boss_ai_forecast_test.gd:378`) cannot catch this. It covers the Start draw only, and its fixture has no draw spell.

Fix: keep `held` on `_Turn` and drop new cards after every accepted action of a forecast, not of a real plan, where the draw is real. Test: a draw spell in hand and two fixtures differing only in deck order, asserting equal `to_dict()`.

### Suggestions
- **Low defect, `boss_ai.gd:846-847` and `:869-870`:** if the match ends before the last lethal step, the loop returns before the rows are marked, so the Intent is `attack_face` (or another class), not `lethal`. It needs the sandbox's randomness to finish the hero sooner than the search's did. I found no shipped card that does so.
- **Latent, `boss_ai.gd:893`:** a Choice owed by the player on the way to the boss's Main leaves the clone in `Choice`, the loop never runs and the forecast says `pass`, which is fabricated. No shipped End-step effect opens a Choice.
- **Nit:** both boss-ai stories say `Manifest Version 2026-11-03` (manifest is 2026-11-04) and are Complete with unticked criteria.

### Design questions for the owner
- **A4 against C8.1** (already open in the story). C8.5 and A4 say an unchanged board gives `kept = true`; C8.1 forecasts the current hand. The boss draws every turn, so "plan changed", which C8.2 says means the player's turn broke the plan, will often show when the player did nothing. BAI-012 cannot fixture A4 honestly until this is settled.
- **`kept` with no forecast** (already open): a stale forecast gives "plan changed" with no banner shown.

### Verdict: CHANGES REQUIRED

---

## Code Review: BAI-009 defensive mode and sandbox fidelity (`bd61da1`; A31, DD-X22)

### Engine Specialist Findings: CLEAN
Observation checked: `int(enchantment.attack_delta)` in `_board_damage` reads the key directly. Dropped: `MatchRecords.enchantment` and `apply_aura` always set it.

### Testability: GAPS
- **A20**: see D2.
- **`boss_ai_defensive_mode_test.gd:328-332`**, doomed boss: `chosen` is never asserted, and the last command being `end_turn` is true of every turn. A boss that scores and passes satisfies it. The Edge Case says it "still plays the best-scoring DEFENSIVE action".
- **`scorer.gd:422` and `:439`**: no fixture reaches the `f_self` floor or cap, so removing either passes.
- All other QA plan rows have a real test: A31 in three bands, the F6 boundary, the multiplier mutation, `top3`, same-attacker-only, armor and weapon.

### ADR Compliance: COMPLIANT
ADR-0006 checked. No hook is stubbed in `src/ai/**`.

### Standards Compliance: 6/6
### Architecture: CLEAN
`ThreatEstimate` reads no hand. `LethalSearch.is_taunter` going public keeps one Taunt definition.
### SOLID: COMPLIANT

### Game-Specific Concerns
A31 matches F1 line by line: `unsafe` on the after-state, the same attacker's trade, lethal excluded, board-only `reach`, no extra simulation, and the score recomputed through the same `_weighted`. It reads the profile already multiplied for DEFENSIVE. The story's deviations (float `incoming`, sandbox arguments, the exception living in `score_all`) are sound.

### Positive Observations
- The exception is a second pass over results already computed, so a lone `score()` stays plain F1 and the cost claim is testable (`test_the_exception_costs_no_extra_simulation`).
- GDD-pinned scores are asserted, not just signs.

### Required Changes

**D2. Defect, test evidence only: A20 has not run on the production resolver, and the reason it could not has gone.** `tests/unit/boss_ai/boss_ai_defensive_mode_test.gd:5-11` and `:88`. Confidence: **VERIFIED.**

The story allows the test double only "if those epics have not landed", and says A20 "stays NOT ASSESSED until CE-014 merges". CE-014 is merged in `f4aff0e` with `apply_value_hook` live. The header still says no real `modify_heal` can fold, which is now false, and tells the next author to re-point it. A failure on the production fold in a sandbox would not fail this test.

I expect the re-pointed test to pass, and I do not suspect `src/`. `card_effects_value_hooks_test.gd` covers `modify_heal` on a live engine (`:530`) and a clone folding `modify_cost` (`test_a_clone_folds_through_its_own_resolver_to_the_same_cost`), but no test combines them, and that combination is what A20 asserts. Note the fixture's `mul` must be an op the production `modify_value` accepts.

### Suggestions
- Assert `chosen` in the doomed-boss test.
- Add fixtures that reach the `f_self` floor and cap.
- **Nit:** `_board_damage` sums weapon attack without the `maxi(0, ...)` of `_weapon_attack`; a negative enchantment would lower `reach`. Rare.

### Design question for the owner
**F6 "frozen minions that will thaw" against C13.** `threat_estimate.gd:64-65` counts every frozen minion, and F1 and the QA plan say to. But under C13, a player minion frozen at the boss's Main does not attack on the player's next turn: a minion frozen on the boss's turn thaws at the End of that player turn, having missed it, and one frozen before attacking on its own turn stays frozen through its next turn. So F6's qualifier selects nothing at the boss's Main, and a boss that freezes its biggest threat gets no credit in `reach` or DEFENSIVE. No shipped card has a `freeze` op, so nothing is affected today. It belongs with the QA plan's open C13 wording gap.

### Verdict: CHANGES REQUIRED

---

## Code Review: MR-019 rules engine performance pass (`4d2b046`..`17efca2`)

### Engine Specialist Findings: CLEAN
Confirmed by my own trace, below.

### Testability: GAPS (none blocking)
- **`match_rules_op_budget_test.gd:285` is vacuous:** `is_same(x, {})` is always false. `:286` carries the check, so no coverage is lost.
- **`match_rules_golden_log_test.gd:75`:** named for 56 passes, floor is `CHAIN_MIN_STEPS` 50.
- **`match_rules_op_budget_test.gd`:** no floor on `drain_iterations` in the budget asserts. An empty chain passes there; the goldens catch it.
- **`match_golden_logs.gd:144`, `:212`, `:243`:** `_capture_full_board`, `_capture_aura_source_life` and `_capture_aura_holders` never turn the audit on, though the story says "the golden suite runs with it on". Five other captures do.
- **`match_rules_golden_log_test.gd:118`:** the name claims the AC-38 match; the body checks count, types and concede, with constants copied by hand.

### ADR Compliance: COMPLIANT
- ADR-0007: C10 order unchanged; `recompute_calls == drain_iterations` holds by construction.
- ADR-0005: no allocation added in the fold.
- GDD C1 / story 018: the index sits on the engine, not on records, and is not in `MatchState` or the snapshot.
- The story's own deviations (position in the hint, clone copies the index, opt-in audit) are sound and recorded.

### Standards Compliance: 6/6
### Architecture: CLEAN
### SOLID: COMPLIANT

### Game-Specific Concerns: can cached state go stale or leak?
**No defect found.** The golden logs use `TestEffectResolver` only, so I traced each item against the production `EffectResolver` too.

**R2 hints, and `clone()` copying them: safe.**
- A hint holds ints only: side, zone, position. It references no record, so nothing can alias between a clone and its source.
- `_where.duplicate()` is a value copy. Each engine reads hints against its own state.
- `_locate` returns only after an id check on the record at that slot, so a stale hint costs a scan and cannot give a wrong answer. That holds for a clone that diverged, for direct fixture writes and for writes from any other module.
- The one assumption is that ids are unique across zones. `next_entity_id` is shared and every zone move keeps or remints the id.
- `LOC_KEYS` order, the masks and the bit packing match the removed finders. `_character` once checked heroes before boards; with unique ids that order cannot matter.

**R1 aura pass: safe.**
- All 23 `PRIMITIVES` call `_before_aura_write` ahead of their first write, counted against the list.
- The strip's scan walks the same lists as the strip.
- Production `recompute_auras` writes only through `apply_enchantment`.
- `_aura_values` is pure: `apply_value_hook` mutates no match state and claims no `once_per_turn` mark, so folding fewer times changes nothing. It can now run inside `apply_aura`, but all of that loop's reads finish first and `_fold_run` is used by nothing else there.
- `_recompute_auras` cannot nest: primitives raise and queue, only `_run_step`, `submit` and resume drain.
- `_recomputing_auras` is read only by `apply_enchantment`'s silent branch and the guard, so taking `before` inside the pass reads the same values.

**R3 shared buffers: safe today, and the one cache that does not check itself.**
- A clone gets fresh empty buffers and a serial of 0, so nothing is shared.
- Every `resolve` that carries a buffer runs through `_resolve_candidates` at depth + 1. The direct calls at `:3049` and `:3206` carry a queue entry and a local array.
- Every buffer ctx reaches `resolve` immediately: `_run_step` calls its Callable at once, or not at all.
- Production `_collect` is the only reader of `ctx.candidates`, and only `_queue_entry` follows it, which does not copy the list. `_enqueue` copies entries, not ctx.
- Every board and weapon write bumps the serial, and all three action entries bump it. A resumed Choice arrives through `submit`.
- No file outside `rules_engine.gd` writes a zone (`match_view_state.gd` is a separate view model).

**Regenerated goldens: verified.** Merge `1e23a4c` rewrote 15 of the 16 after MR-019. With the empty `"aura_hosts":[],` key removed, all 15 hash byte-equal to `17efca2`, so the regeneration changed nothing else. That key comes from card-effects 013's `effect_runtime` field.

### Positive Observations
- Id-checked hints are the right design: correctness does not depend on every writer remembering the index.
- The A/B caught two cuts that met their count budgets and bought nothing, and the record says so plainly.
- `trigger_order` and `aura_holders` exist because mutants survived without them.
- R4 was declined on measurement and the record shows the check of each candidate. No budget was moved.
- Provisional figures are labelled as such, and release is NOT ASSESSED rather than inferred.

### Required Changes
None for the code. **The story is not closed by this review:** AC-3 (13.3 ms against 5 ms) goes to the owner as R6, and AC-3 and AC-4 need release figures.

### Suggestions
- **Close R3's one gap.** "Within an action only primitives write the zones" is enforced by nothing. Scenario: a later op reorders `board` in place with no serial bump, and the next raise in that action gets the old order with no failure. R2's self-check has no equivalent here. Extend `set_lookup_audit` to compare the reused buffer with a fresh walk.
- **Nit, `rules_engine.gd:3930`:** no entry of `_where` is ever erased, so dead ids are copied on every clone, a cost that grows with match length. Small at current sizes; worth a line in the R5 re-measure.
- Fix the Testability items, and turn the audit on in the three captures or correct the story's sentence.
- Run the cross-OS golden comparison the QA plan placed before M2. It is still open.
- `clone()`'s doc comment lists what is copied; add the index.

### Verdict: APPROVED WITH SUGGESTIONS
