# Story 008: Win, loss, concede and MatchResult

> **Epic**: Match Rules
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

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

- [ ] AC-34 **GIVEN** both heroes at 1 health, **WHEN** an effect deals 1 to both heroes (a scripted trigger calling `apply_damage` twice), **THEN** `result.winner == BOSS`, `reason == both_dead`, and both `damage_dealt` events precede `match_ended` (DD-M12); **GIVEN** only the player's hero ≤ 0 **THEN** boss wins `hero_dead`; only the boss's hero ≤ 0 **THEN** player wins `hero_dead`; **GIVEN** the player's hero drops to ≤ 0 mid-loop and a later step in the same loop heals it above 0, **THEN** the match continues (the check runs only at the end of the loop).
- [ ] AC-35 **GIVEN** the boss's Main phase, **WHEN** the player sends `concede`, **THEN** `phase == Ended`, `winner == BOSS`, `reason == concede`; a following boss `end_turn` is rejected `MATCH_ENDED`; `concede` is also accepted in Mulligan and Choice, and from the boss issuer it is `NOT_YOUR_TURN`-class illegal (C2: issuer = PLAYER) — assert the code the ordered checks produce.
- [ ] AC-42 **GIVEN** a `MatchResult`, **WHEN** inspected after `match_ended`, **THEN** it carries `result (win | loss | fault, from the player's side), winner, reason, floor, turns, turns_per_side, stats.damage_dealt_by_card` (plus `damage_taken`, `cards_played`, `minions_summoned`) for both sides and final hero health both sides (`MatchFactory.make_match_result` keys); **GIVEN** a `resolution_overflow` (step cap forced via test config; the loop itself is story 009 — here `fault(reason)` is the engine entry point), **THEN** `result == fault` and `winner == null`; `match_ended` is the last event, the log is sealed, `resolver.unbind()` was called, and the engine is collectable (`weakref` test); **GIVEN** the log reports `log_overflow` on an append, **THEN** the engine stops and emits exactly one `match_ended{result: fault, reason: event_cap, winner: null}`.

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

- `src/gameplay/match/rules_engine.gd` (`win_loss_check`, `_end_match`, `end_match`, `fault`, `concede` handler, `result`)
- `src/gameplay/match/match_records.gd` (`MatchResult` builder)
- `tests/unit/match_rules/match_rules_win_loss_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/match_rules/match_rules_win_loss_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later). `qa.level: standard` — BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/match-rules/story-007-damage-heal-armor.md`
- Unlocks: `production/epics/match-rules/story-009-resolution-loop.md`
