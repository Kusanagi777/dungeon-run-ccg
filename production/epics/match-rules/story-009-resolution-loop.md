# Story 009: Resolution loop: death check, trigger queue, auras, step cap

> **Epic**: Match Rules
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-04

## Context

**GDD**: `design/gdd/match-rules.md` (C10 Death resolution and trigger ordering; C12 Deathrattle, Aura rows; F6 aura loss; Interactions trigger points `on_damage`, `on_minion_died`, `deathrattle`; Edge Cases "Board and summoning", "Win/loss" overflow rows; DD-M11)
**Requirement**: `TR-match-rules-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Effect Resolver / Validator Boundary (Decision 1 — the engine owns the C10 loop, `RESOLUTION_STEP_CAP`, candidate order; one effect pass = one step; `recompute_auras()` is the resolver's method the engine's loop calls); also ADR-0005 (trigger hook entries are each one step followed by the full loop)
**ADR Decision Summary**: The engine owns time and order — the C10 loop (death check → `recompute_auras()` → queue pop), `RESOLUTION_STEP_CAP`, and the moment and candidate order of every trigger point; the resolver decides who responds and orders effects only within one entity, never calling the death check or `recompute_auras()` between ops. Triggers queue, never nest.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: HIGH by version; APIs used predate 4.3. The queue is a plain `Array` of step Dictionaries (`pop_front` is O(n) on `Array`; with the cap at 1000 and typical queues under 20 that is within budget — measure in story 018 before reaching for a ring buffer). No recursion: a trigger raised during `execute(t)` is appended, not run.

This is the rule that makes Pillar 4 true: every action runs the same loop, every death is checked after every step, every queued trigger resolves even if its source has left play, and the log can answer "did it fire or not" without Hearthstone trivia. It is also the one place a content bug is allowed to end a match — loudly, as a fault, after `RESOLUTION_STEP_CAP` steps.

**Control Manifest Rules (this layer)**:
- Required: `RulesEngine` owns … the C10 loop (death check → `recompute_auras()` → queue pop), `RESOLUTION_STEP_CAP` (ADR-0007); one effect pass = one C10 step; the resolver orders effects only *within* one entity (ADR-0007); trigger hook entries run synchronously as their own step and may call primitives, each followed by the full C10 loop (ADR-0005)
- Forbidden: never let the resolver own the C10 loop or the trigger queue — Match Rules must be testable without Card Effects (ADR-0007 Alt 1); never re-sort candidates across entities in the resolver; never call the death check or `recompute_auras()` between ops (ADR-0007)
- Guardrail: `submit()` ≤ 5 ms worst case (50-step Deathrattle chain, includes resolver passes) (ADR-0007, ADR-0001)

---

## Acceptance Criteria

*From GDD `design/gdd/match-rules.md`, scoped to this story:*

- [ ] AC-27 **GIVEN** player board [A(dr), B(dr)] and boss board [C(dr)] all at 1 health, **WHEN** a 1-damage-to-all effect resolves, **THEN** the log order is `minion_died A, B, C` then `trigger_resolved A, B, C` (DD-M11: player board left to right, boss board left to right, then weapons; Deathrattles appended to Q in that order), and `on_minion_died` observers among A, B, C do not fire (a minion that died in the same check observes nothing); each `trigger_resolved` carries `cause_seq` = the `seq` of the `minion_died` that queued it.
- [ ] AC-28 **GIVEN** a minion with an `on_damage: draw` trigger at 1 health, **WHEN** it is hit for 1, **THEN** `card_drawn` is emitted after `damage_dealt` and before its own `trigger_resolved(deathrattle)` (combat/damage `on_damage` triggers are queued before the death check runs, so they resolve before the Deathrattles of minions that died from the same hit); a queued trigger resolves even though its source left play, reading the snapshot of the source's stats taken at raise time.
- [ ] AC-29 **GIVEN** 7 friendly minions where `board[3]` has "Deathrattle: summon a 2/2", **WHEN** it dies, **THEN** the token appears at index 3 (dead minions leave play **before** their Deathrattles run, so 6 + 1 fits); **GIVEN** 6 others plus a second simultaneous summon, **THEN** the second summon emits `summon_failed {reason: board_full}`; **GIVEN** the dead minion's former index is beyond the board end, **THEN** the token goes to the rightmost slot; **GIVEN** an aura source dies in the same step as the minions it buffs are damaged, **THEN** `recompute_auras` drops the buff, the re-run death check kills the buffed minions in the **next** pass and their Deathrattles queue after the source's (two `minion_died` groups; one `auras_recomputed` per pass with net stat changes).
- [ ] AC-30 **GIVEN** two friendly test minions each with the fixture trigger "whenever a friendly minion is healed, heal the other friendly minion for 1" (a full-health heal restores 0 and still emits `healed`, so the pair ping-pongs forever), **WHEN** either is healed with `RESOLUTION_STEP_CAP = 50`, **THEN** the match ends with `result == fault`, `winner == null`, `reason == resolution_overflow` after exactly 50 steps, `resolution_overflow{steps: 50}` precedes `match_ended`, and `match_ended` is the last event.

---

## Implementation Notes

*Derived from ADR-0007 Decision 1 / Implementation Guidelines and GDD C10:*

- `run_action(initial_step)`: `execute(initial_step)`; then loop: `dead = death_check()`; `recompute_auras()`; if `dead` empty and `Q` empty → break; if `Q` empty → continue (aura loss may have killed something); `t = Q.pop_front()`; `execute(t)`; count a step on each `execute`; when `steps > RESOLUTION_STEP_CAP` → `fault("resolution_overflow")` and return. After the loop: `win_loss_check()` (story 008). Every command handler and every engine-initiated step (Start/End sub-steps, hook trigger entries) goes through `run_action`.
- `execute(step)`: sets `_current_cause_seq` to the step's `cause_seq`, runs it (a primitive call, a `resolver.resolve(point, ctx)` pass, or a `hooks.run_triggers` entry); anything *raised* during it is **appended** to `Q` — never run inline — as a step Dictionary `{point, ctx (with a snapshot of the source's stats), cause_seq}`. `trigger_queued` is emitted when a trigger is appended and `trigger_resolved` when it runs (both C15 status events). Nothing is queued for a source that was not in play at raise time.
- `death_check()`: mark every minion with `health ≤ 0` or `pending_destroy`, every weapon with `durability ≤ 0`; all marked leave play in the **same** step; emit `minion_died` / `weapon_destroyed` in order player board L→R, boss board L→R, player weapon, boss weapon; append each one's Deathrattle steps to `Q` in exactly that order (several Deathrattles on one character: enchantment order, base first — the resolver orders within the entity); then raise `on_minion_died` for every observer **still in play**. Return the dead list.
- `recompute_auras()`: the engine strips every `is_aura` enchantment, then calls `resolver.recompute_auras()` (ADR-0007 Key Interfaces: the resolver re-applies auras from every living aura source in board order, player then boss, through `apply_enchantment(…, is_aura = true)`); the engine emits one `auras_recomputed` listing net stat changes per pass (none when nothing changed). Aura loss leaves `damage_taken` untouched (F6), so the next pass's death check finishes the job.
- Summons during the loop use `summon_minion(side, def_id, position)` with the dead minion's former index, clamped to the rightmost slot; a full board → `summon_failed`.
- Candidate order for every trigger point is `_candidates_in_order()` (story 005) filtered to the point's subject; the engine passes `ctx.candidates: Array[int]` and the resolver double records it.
- `RESOLUTION_STEP_CAP` comes from `rules_config` (tests set 50). The step counter resets per `run_action`.
- AC-30's fixture trigger lives in the scripted resolver double (`on_heal` → `apply_heal(other, 1)`); a self-copying Deathrattle is **not** a valid fixture (it stops when the board fills).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 010: the play-order steps (Battlecry → `on_card_played` → `on_play` → `on_summon`) that feed this loop
- Story 013: combat's `on_attack` / simultaneous damage steps
- Story 015: Silence removing Deathrattles before death
- Card Effects epic: the DSL that decides who responds and what a Deathrattle does

---

## Files

- `src/gameplay/match/rules_engine.gd` (`run_action`, `_run_step` / `_drain` / `_execute_queued`, `_enqueue` with the raise-time snapshot and the in-play guard, `_death_check` in DD-M11 order with Deathrattle and `on_minion_died` raises, `_recompute_auras` with one net-change `auras_recomputed`, the `resolution_step_cap` fault; every command handler, C4 sub-step and step-boundary hook entry runs as its own step; `equip_weapon` queues the replaced weapon's Deathrattle; constants `CTX_QUEUED`, `WEAPON_BROKEN`)
- `src/gameplay/match/hook_registry.gd` (`run_trigger_entry(point, index, side, ctx)` — one entry as one step)
- `tests/helpers/test_effect_resolver.gd` (event-trigger responders `add_trigger` / `passes` / `pass_ids`, `subject_is`; fixtures `add_deathrattle_summon`, `add_heal_ping_pong`, `auras`; `candidates_for` skips executed queued passes)
- `tests/unit/match_rules/match_rules_resolution_loop_test.gd` (new, 12 tests)
- `tests/unit/match_rules/match_rules_turn_structure_test.gd` (End-step aura assertion re-expressed for a per-step recompute)

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/match_rules/match_rules_resolution_loop_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later). `qa.level: standard` — BLOCKING.

**Status**: [x] Created and passing (12 test functions)

---

## Dependencies

- Depends on: `production/epics/match-rules/story-008-win-loss-concede-result.md`
- Unlocks: `production/epics/match-rules/story-010-play-card-and-hero-power.md`

## Completion Notes
**Completed**: 2026-11-03 (started 22:58:58 UTC, ended 23:21:20 UTC; the code-review fix commit for stories 006–008 ran 23:06–23:14 inside that window)
**Criteria**: 4/4 passing — AC-27 (`test_simultaneous_deaths_leave_in_dd_m11_order_and_queue_deathrattles_in_that_order`, `test_a_broken_weapon_leaves_after_the_minions_and_its_deathrattle_queues_after_theirs`), AC-28 (`test_on_damage_trigger_resolves_before_its_own_deathrattle_from_the_raise_time_snapshot`, `test_nothing_is_queued_for_a_source_not_in_play_at_raise_time`), AC-29 (`test_deathrattle_summon_on_a_full_board_takes_the_dead_minions_index`, `test_a_second_simultaneous_summon_on_the_refilled_board_fails`, `test_deathrattle_summon_past_the_board_end_goes_rightmost`, `test_aura_loss_kills_the_buffed_minion_in_the_next_pass_after_the_sources_deathrattle`), AC-30 (`test_heal_ping_pong_faults_resolution_overflow_after_exactly_the_step_cap`, `test_the_step_counter_resets_per_action`); plus `test_replacing_a_weapon_queues_the_old_weapons_deathrattle` (story-006 TODO) and `test_each_hook_trigger_entry_is_followed_by_the_full_loop` (story 008's open item: hook entries now run the loop after **each** entry). Watched fail: 11 of 12 against a `run_action` stub with no loop; the 12th (in-play guard) fails with the guard disabled.
**Deviations** (advisory):
- **Queued-trigger execution interface (not fixed by ADR-0007 Key Interfaces):** the engine executes a popped trigger by calling `resolver.resolve(point, ctx)` with `ctx[RulesEngine.CTX_QUEUED] = true` (`ctx` = the resolver's own entry plus `snapshot`); the resolver runs that one pass. No new resolver method. A queue entry the resolver returns must carry `source_id: int` and `effect_id` (optional `point`, `snapshot`). Card-effects story 008 implements against this; record it as an ADR-0007 Key Interfaces note.
- The engine attaches `ctx.snapshot` (a value copy of the source at raise time, or the dead snapshot with `position` for a Deathrattle) when the resolver's entry has none, and drops an entry whose source is not on the board, a hero, a weapon or in hand at raise time — the resolver remains the owner of "who responds" (C6.5 snapshot fields are the resolver's).
- Hook trigger points reached **inside** a primitive (`on_draw`, `on_hero_damaged`, `on_minion_summoned`) still run synchronously within the current step: a C10 loop there would run a death check between the ops of one effect pass (ADR-0007, card-effects C6.0 / C6.3 "inside F2 … synchronous"). Step-boundary hook points (`on_match_start`, `on_turn_start`, `on_turn_end`; story 010's `on_card_played`) run one entry per step through the new `HookRegistry.run_trigger_entry` (file outside the story's list).
- `run_action(step: Callable)` is public (the C10 entry for engine-driven fixture steps); `win_loss_check` runs after it and at the C4 points, not after each C4 sub-step (DD-M12 "when the current action finishes").
- Deathrattles are raised with one `resolve(&"deathrattle", {candidates: [id], subject, snapshot})` per dead entity, and `on_minion_died` once per dead minion with the survivors as candidates.
- `trigger_queued` / `trigger_resolved` payload `{point, source_id, effect_id}`; `minion_died {side, entity_id, card_id, position}`; `weapon_destroyed.reason: broken` from the death check; `auras_recomputed {changes: [{entity_id, attack, health, max_health}]}`. Aura enchantments re-applied during the recompute emit no `enchantment_applied`.
- `match_rules_turn_structure_test.gd`: "`aura_recomputes == before + 1` over a whole `end_turn`" pinned the story-005 placeholder; it now asserts a recompute between the End-step expiry and `turn_ended`.
- A dead minion's card is not moved to the graveyard (not in C10; story 015 / Content can add it).
**Test Evidence**: `tests/unit/match_rules/match_rules_resolution_loop_test.gd` (12 tests); full suite 833 test cases, 0 failures, exit 0, 45 SCRIPT ERROR lines (the same intentional negatives as before the story); smoke exit 0, no SCRIPT ERROR; parse check exit 0.
**Run result**: N/A — the loop is headless rules code; no scene, node or screen renders it yet (Match UI is a later epic).
**Reviewed by**: self, no independent review (LP-CODE-REVIEW skipped — Lean mode; QL-TEST-COVERAGE skipped — Lean mode)

### Code-review fix pass (2026-11-04, started 02:02:58 UTC, ended 02:08:14 UTC; branch `fix/review-s3w2`)
Findings from `/code-review` sprint 3 wave 2 (2026-11-03) on this story, all fixed:
- **In-primitive hook re-entry** (should-fix): `on_draw`, `on_hero_damaged` and `on_minion_summoned` entries ran nested inside the primitive with no guard, so a self-feeding hook overflowed the GDScript call stack. The engine now marks a hook point running while its entries run (`_run_inline_hooks` for the three in-primitive points, `_run_hook_entry` for each step-boundary entry — the mark covers the entry, not the C10 loop after it); a primitive that reaches the same point again faults `resolution_overflow {steps}` (ADR-0005 rule-4 exception, erratum 2026-11-03). Unblocks card-effects 015 filling `run_hook_effect`.
- **Step-cap reset** (should-fix): `_steps = 0` ran in `_run_step`, i.e. per sub-step, so one command got `cap × sub-steps`. It now resets once per `submit`, `run_action` and `start`.
- **Malformed queue entry** (nit): an entry without a whole-number `source_id` is `push_error`ed and skipped; the entries after it still queue.
Tests added (6, in `match_rules_resolution_loop_test.gd`, now 18): `test_self_feeding_on_hero_damaged_hook_faults_resolution_overflow_not_the_call_stack`, `test_self_feeding_on_draw_hook_faults_resolution_overflow`, `test_self_feeding_on_minion_summoned_hook_faults_resolution_overflow`, `test_an_in_primitive_hook_that_does_not_re_enter_runs_on_every_hit` (control: the guard clears after each entry), `test_the_step_cap_counts_every_step_of_one_command`, `test_a_malformed_queue_entry_is_logged_and_skipped`. Watched fail on the unfixed engine: 5 of 6 (stack overflow ×1, no fault ×3 — the on_draw / on_minion_summoned loops end on fatigue / a full board —, crash on `entry.source_id`); the control passes before and after by design. Full suite 1064 test cases, 0 failures, exit 0, 85 SCRIPT ERROR lines (unchanged intentional negatives); smoke exit 0, no SCRIPT ERROR.
Deviation (advisory): the guard is per hook **point**, as the erratum words it — a re-entry of the point by any side inside an entry faults, even if no entry would be in scope for the nested call.
