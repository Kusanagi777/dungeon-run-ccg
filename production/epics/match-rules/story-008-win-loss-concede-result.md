# Story 008: Win, loss, concede and MatchResult

> **Epic**: Match Rules
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-03

## Context

**GDD**: `design/gdd/match-rules.md` (C14 Win, loss and concede; C15 `match_ended`; States `Ended` and the `log_overflow` row; Edge Cases "Win/loss")
**Requirement**: `TR-match-rules-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Effect Resolver / Validator Boundary (`win_loss_check` is the engine's; `resolver.unbind()` when `phase` becomes `Ended`); also ADR-0003 (the log seals on `match_ended`; `log_overflow` then exactly one more event), ADR-0008 (`engine.end_match()`; driver emits its own `match_ended` only after the event reached subscribers)
**ADR Decision Summary**: The engine owns `win_loss_check` and the `Ended` transition; on `match_ended` it calls `resolver.unbind()`, which clears the engine reference and the registry's evaluators and breaks the `RefCounted` cycle. A fault is a third outcome with `winner = null`; the log's overflow fault is answered by exactly one `match_ended{result: fault, reason: event_cap}`.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: `NOT SOURCEABLE — RefCounted cycle collection` (ADR-0007): the teardown test holds `weakref(engine)`, calls `end_match()` (→ `unbind()`), drops strong refs and asserts `get_ref() == null`. The engine may declare `signal match_ended(result)` as a unit-test convenience only (ADR-0008: never connected in production).

The match ends in exactly one place, `win_loss_check()`, which runs at the end of every action's resolution loop and at the C4 points — never mid-loop — so a Deathrattle heal can still save a hero at 0 and "both dead" is decided by rule, legibly, in the log. `concede` is the one command accepted in any non-Ended phase. The `MatchResult` carries no seed: run seed + floor identify the match (DD-R09).

**Control Manifest Rules (this layer)**:
- Required: `RulesEngine` owns … `win_loss_check` (ADR-0007); `resolver.unbind()` when `phase` becomes `Ended` (breaks the `RefCounted` cycle) (ADR-0007, ADR-0005); `_after_engine_step()` … on `Ended` drops any pending plan, calls `engine.end_match()` and emits its own `match_ended(result)` only after the `match_ended` event has reached subscribers (ADR-0008)
- Forbidden: never connect `RulesEngine.match_ended` in production (ADR-0008); never suspend mid-match by serialising the event log (ADR-0008 Alt 4); never append to a log from the registry (ADR-0005)
- Guardrail: memory — one driver graph per attempt, no event buffer; the engine↔resolver cycle must not survive the match (ADR-0007, ADR-0008)

---

## Acceptance Criteria

*From GDD `design/gdd/match-rules.md`, scoped to this story:*

- [x] AC-34 **GIVEN** both heroes at 1 health, **WHEN** an effect deals 1 to both heroes (a scripted trigger calling `apply_damage` twice), **THEN** `result.winner == BOSS`, `reason == both_dead`, and both `damage_dealt` events precede `match_ended` (DD-M12); **GIVEN** only the player's hero ≤ 0 **THEN** boss wins `hero_dead`; only the boss's hero ≤ 0 **THEN** player wins `hero_dead`; **GIVEN** the player's hero drops to ≤ 0 mid-loop and a later step in the same loop heals it above 0, **THEN** the match continues (the check runs only at the end of the loop).
- [x] AC-35 **GIVEN** the boss's Main phase, **WHEN** the player sends `concede`, **THEN** `phase == Ended`, `winner == BOSS`, `reason == concede`; a following boss `end_turn` is rejected `MATCH_ENDED`; `concede` is also accepted in Mulligan and Choice, and from the boss issuer it is `NOT_YOUR_TURN`-class illegal (C2: issuer = PLAYER) — assert the code the ordered checks produce.
- [x] AC-42 **GIVEN** a `MatchResult`, **WHEN** inspected after `match_ended`, **THEN** it carries `result (win | loss | fault, from the player's side), winner, reason, floor, turns, turns_per_side, stats.damage_dealt_by_card` (plus `damage_taken`, `cards_played`, `minions_summoned`) for both sides and final hero health both sides (`MatchFactory.make_match_result` keys); **GIVEN** a `resolution_overflow` (step cap forced via test config; the loop itself is story 009 — here `fault(reason)` is the engine entry point), **THEN** `result == fault` and `winner == null`; `match_ended` is the last event, the log is sealed, `resolver.unbind()` was called, and the engine is collectable (`weakref` test); **GIVEN** the log reports `log_overflow` on an append, **THEN** the engine stops and emits exactly one `match_ended{result: fault, reason: event_cap, winner: null}`.

---

## Implementation Notes

*Derived from ADR-0007 Decision 2 / Implementation Guidelines, ADR-0003 Decision 8, ADR-0008 Decision and GDD C14:*

- `win_loss_check()`: both heroes ≤ 0 → BOSS, `both_dead`; player ≤ 0 → BOSS, `hero_dead`; boss ≤ 0 → PLAYER, `hero_dead`; else nothing. Called at the end of every action's C10 loop and at C4 Start step 7 / End step 6, never mid-loop.
- `_end_match(result, winner, reason)`: build the `MatchResult` `{result, winner, reason, floor, turns, turns_per_side: {player, boss}, stats: {player, boss}, final_health: {player, boss}}` (`result` is from the player's side: `win` when winner PLAYER, `loss` when BOSS, `fault` with `winner = null`), set `state.result`, `phase = Ended`, emit `match_ended(result)` (the log seals on it), then `resolver.unbind()` (clears the engine reference and `hooks.set_evaluators` → unset), emit the test-only signal. `end_match()` is the public entry the driver calls (idempotent once Ended). `result()` returns the record.
- `concede`: legal in any phase except Ended, issuer PLAYER (the ordered checks: `MATCH_ENDED` first, then issuer). Because the engine is synchronous, a concede during the boss's turn lands after the boss's in-flight command returned; the boss's remaining plan never runs (the driver's `_after_engine_step` sees `Ended`).
- `TURN_CAP` (story 005) ends through the same `_end_match(…, BOSS, turn_cap)`.
- Faults: `fault(reason)` with `reason ∈ {resolution_overflow, event_cap}` → `_end_match("fault", null, reason)`. For `resolution_overflow` the engine first emits `resolution_overflow{steps}` then `match_ended`. For `event_cap`: the log appends its own `log_overflow` and accepts **exactly one** more event — `emit` returns the sentinel the log gives on overflow (ADR-0003: `overflowed` / `append` result), the engine aborts the current loop without further mutation and the one allowed append is `match_ended`. Run Structure treats a fault as "floor not lost" (its T9); nothing here decides that.
- After `Ended`, `submit` returns `MATCH_ENDED` for every command (story 004's guard, now reachable) and `legal_commands()` returns `[]`.
- Tests: a scripted resolver trigger that damages both heroes; `TestEventLog` with `max_events` set low for the `event_cap` path; `EventLogAssertions.assert_last_type(log, "match_ended")`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 009: the `RESOLUTION_STEP_CAP` loop that calls `fault("resolution_overflow")` (AC-30)
- run-structure epic: what a fault means for the run (T9, `pre_match`)
- boss-ai-match-driver epic: `MatchDriver._after_engine_step` and its own `match_ended(result)`

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/gameplay/match/rules_engine.gd` — `_win_loss_check` (both_dead / hero_dead, at the end of every action and C4 Start 7 / End 6), `concede` handler and `_validate` row, `fault(reason, steps)`, `end_match()` (idempotent teardown), `_end_match(winner, reason)` (full `MatchResult`, `match_ended`, `resolver.unbind()` once, test-only `signal match_ended`), `_halted()` guards in every primitive and step, `emit` / `_reject` answer a refused append with `fault(event_cap)` and append nothing once Ended
- `src/gameplay/match/match_records.gd` — `final_result(state, winner, reason, final_health)` (the C14 builder), `RESULT_*`, `REASON_*`, `FAULT_REASONS`, `concede()` command builder
- `tests/unit/match_rules/match_rules_win_loss_test.gd` — 15 test functions

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/match_rules/match_rules_win_loss_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later). `qa.level: standard` — BLOCKING.

**Status**: [x] Created and passing (15 test functions)

---

## Dependencies

- Depends on: `production/epics/match-rules/story-007-damage-heal-armor.md`
- Unlocks: `production/epics/match-rules/story-009-resolution-loop.md`

## Completion Notes
**Completed**: 2026-11-03 (started 22:45:03 UTC, ended 22:52:46 UTC)
**Criteria**: 3/3 passing — AC-34 (`test_both_heroes_at_zero_after_one_action_is_a_boss_win_both_dead`, `test_only_the_player_hero_dead_is_a_boss_win_hero_dead`, `test_only_the_boss_hero_dead_is_a_player_win_hero_dead`, `test_a_hero_at_zero_mid_action_healed_later_in_the_same_action_survives`, `test_win_loss_check_on_a_living_match_changes_nothing`), AC-35 (`test_player_concede_during_the_boss_main_ends_the_match_for_the_boss`, `test_concede_is_accepted_in_mulligan_and_choice`, `test_concede_from_the_boss_issuer_is_rejected_in_every_phase`, `test_concede_after_ended_is_match_ended`), AC-42 (`test_match_result_carries_the_c14_fields_and_both_sides_stats`, `test_resolution_overflow_fault_has_no_winner_and_seals_the_log`, `test_log_overflow_ends_the_match_with_exactly_one_event_cap_match_ended`, `test_ended_engine_is_collected_after_unbind`, `test_end_match_on_a_live_engine_unbinds_once`, `test_match_ended_signal_fires_once_with_the_result`). Watched fail: 12 of 15 against the story-007 engine (the three that passed pin pre-existing behaviour: the boss issuer's `WRONG_PHASE`, a hero healed back above 0, a no-op check); mutants — no `unbind()` at Ended (4 tests fail), `_unbind` that never reaches the resolver (both weakref assertions fail: the cycle keeps the engine alive), `both_dead` branch disabled (the AC-34 test fails).
**Deviations** (advisory):
- A boss-issued `concede` is `WRONG_PHASE` in every phase: the story-004 phase guard answers a disallowed issuer of a PLAYER-only row with `WRONG_PHASE` (AC-35 asks for "the code the ordered checks produce"; it reads "NOT_YOUR_TURN-class").
- `win_loss_check` stays engine-internal (`_win_loss_check`, ADR-0007 ownership table "internal"); the test calls it directly once.
- `end_match()` on a live match unbinds without ending it (card-effects story 002's teardown test calls it before any end); on an ended match it is a no-op, since the engine unbinds at `Ended` itself.
- Once `Ended`, `emit` appends nothing and a rejection is not logged (`command_rejected` would be an append to a sealed log — a production `EventLog` caller bug); a post-Ended rejection's range is `[0, 0]`.
- The event-cap answer reads the append result (`-1` on a live match), not `EventLog.overflowed`: connecting the signal would give the log a reference back into the engine. Every primitive and step is a no-op after the fault (`_halted()`), so the action stops without further mutation; the mutation that preceded the refused event stays (its event is the one the log dropped).
- `fault(reason, steps)`: `steps` is the `resolution_overflow {steps}` payload story 009's loop supplies.
- Concede is not listed in `legal_commands()` (C2 lists the active side's expansions plus `end_turn`; the boss may never concede).
**Test Evidence**: `tests/unit/match_rules/match_rules_win_loss_test.gd` (15 tests); full suite 751 test cases, 0 failures, exit 0, 36 SCRIPT ERROR lines (baseline intentional negatives); smoke exit 0, no SCRIPT ERROR; parse check exit 0.
**Run result**: N/A — the story changes the headless end-of-match rules and the event log only; no scene, node or screen renders them (Match UI's result screen is a later epic).
**Reviewed by**: self, no independent review (LP-CODE-REVIEW skipped — Lean mode; QL-TEST-COVERAGE skipped — Lean mode)
