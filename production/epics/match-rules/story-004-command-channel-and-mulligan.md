# Story 004: Command channel, rejection codes and mulligan

> **Epic**: Match Rules
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/match-rules.md` (C2 Commands, results and rejections; C3 step 7; States and Transitions — `Resolving`, `Ended`, the `WRONG_PHASE` / `NOT_YOUR_TURN` fallback; C15 diagnostics; Edge Cases "Win/loss" re-entrancy rows)
**Requirement**: `TR-match-rules-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Rules / Presentation Split (the single command channel); also ADR-0006 / ADR-0008 (`ENGINE_BUSY` is the only re-entrancy answer; `MatchDriver` is the one outside caller of `submit`), ADR-0003 (rule 12a — diagnostics on the same log)
**ADR Decision Summary**: The presentation tier talks to the rules through exactly three channels — commands in (`submit(Command) -> CommandResult`), events out, value-copy queries out. Illegal moves are data from a closed rejection set; `submit` is synchronous and a nested `submit` returns `ENGINE_BUSY` rather than corrupting state; `command_rejected` is an ordinary append with `payload.diagnostic = true`.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: HIGH by version; no post-cutoff API used. Lambdas capture locals by value — the `Resolving` guard is an instance field on the engine, never a captured local. A `RefCounted` may declare `signal match_ended` as a unit-test convenience (ADR-0008: never connected in production).

`submit` is the engine's one door. This story builds the dispatcher, the phase guard, the closed rejection set in the order C2 lists it, the `Resolving` state that turns a re-entrant call into `ENGINE_BUSY`, and the first real command, `mulligan`. The command handlers for `play_card`, `attack`, `use_hero_power`, `choose`, `end_turn` are added by their own stories; here they exist only as the phase-table rows that reject them with `WRONG_PHASE` outside Main.

**Control Manifest Rules (this layer)**:
- Required: `MatchDriver` … is the only caller of `RulesEngine.submit` from outside the rules tier, and stamps `issuer = "player"` on UI commands and `issuer = "boss"` on replayed plan commands (ADR-0008); a `concede` that arrives while a task is live is queued in a single slot by the driver and returns `{accepted: false, rejection: {code: ENGINE_BUSY, detail: "concede_queued"}}` — the engine itself knows nothing of tasks (ADR-0006, ADR-0008)
- Forbidden: never `RulesEngine` drives the boss itself (ADR-0008 Alt 2); never invoke a Boss AI entry point inline from `submit` (ADR-0008); never connect `RulesEngine.match_ended` in production (ADR-0008)
- Guardrail: `submit()` ≤ 5 ms worst case; `legal_commands()` ≤ 2 ms (ADR-0007, ADR-0001) — validate before mutating, reject early

---

## Acceptance Criteria

*From GDD `design/gdd/match-rules.md`, scoped to this story:*

- [ ] AC-03 **GIVEN** the Mulligan phase, **WHEN** `mulligan([true, false, false])` is accepted, **THEN** the deck size is unchanged, the hand has 3 cards, card 0 is the same instance, and the returned instances are somewhere in the deck (DD-M05: return before redraw, one fresh shuffle of the whole deck — the test must **not** assert "never redraws the same card"); `mulligan_resolved` is emitted; a mask of all `true` is a legal "keep all"; `MULLIGAN_ROUNDS = 1` — a second `mulligan` is `WRONG_PHASE`.
- [ ] AC-04 **GIVEN** the Mulligan phase, **WHEN** `mulligan` is sent with a 2-element mask, **THEN** the result is `accepted = false, code = INVALID_MASK` and no event other than `command_rejected` is appended; the `command_rejected` payload carries `diagnostic: true`, the code and the command, and takes the next `seq` on the **same** log (C15, rng-event-log rule 12a).
- [ ] AC-37 **GIVEN** an event handler that calls `submit` during playback of a command (a log subscriber), **WHEN** the nested call happens, **THEN** `ENGINE_BUSY`, no state change, `command_rejected` logged as diagnostic, and the outer command's result is unaffected (`accepted = true`, its `events: [seq_first, seq_last]` range correct).
- [ ] C2 / States **GIVEN** any phase, **WHEN** a command outside that phase's accepted set is sent (e.g. `play_card` in Mulligan; `mulligan` from the boss), **THEN** the rejection is `WRONG_PHASE`, or `NOT_YOUR_TURN` when the phase is right but the issuer is not the active side; the rejection code set the engine can produce equals `MatchFactory.REJECTION_CODES` exactly (21 codes, closed); and `CommandResult` has the shape `{accepted, rejection: {code, detail} | null, events: [seq_first, seq_last]}` (after `Ended`, every command → `MATCH_ENDED` — asserted in story 008 once a match can end).

---

## Implementation Notes

*Derived from ADR-0001 Implementation Guidelines, ADR-0003 Decision 6–7 and GDD C2 / States:*

- `submit(command: Dictionary) -> Dictionary` (the `Command` record: `{type, issuer, ...args}`; `CommandResult` per `MatchFactory.make_command_result`). Order inside `submit`: (1) if `_resolving` → `ENGINE_BUSY`; (2) if `phase == Ended` → `MATCH_ENDED`; (3) phase/issuer guard from the States transition table → `WRONG_PHASE` / `NOT_YOUR_TURN` / `CHOICE_PENDING`; (4) the command's own validation in the order its C2 row lists (the first failing reason is deterministic — tests assert the code); (5) set `_resolving = true`, record `seq_first`, run the handler to completion, run the C10 loop (story 009) and `win_loss_check` (story 008), clear `_resolving`, return `{accepted: true, events: [seq_first, seq_last]}`. A rejection never mutates state and always appends exactly one `command_rejected{code, detail, command, diagnostic: true}` through `emit` — the log stamps `seq`; there is no second channel.
- `_resolving` is a plain instance field. `Resolving` is a real state the engine is in for the whole call but is never observable between calls; `phase()` returns the originating phase.
- The rejection codes are a `const` closed set in the engine, spelled exactly as C2 and `MatchFactory.REJECTION_CODES`; adding one is a GDD change.
- `mulligan(keep_mask)`: phase = Mulligan, issuer = PLAYER; `keep_mask.size() != hand.size()` → `INVALID_MASK`. Accepted: cards whose bit is `false` return to the deck (zone `deck`), `rng_match.shuffle(deck)`, `draw(PLAYER, returned_count)` — the return happens **before** the redraw; emit `mulligan_resolved`; then step 8 (`match_started`, first Start step) which story 005 adds — until then leave `phase = Mulligan` resolved into a `PlayerTurn.Start` placeholder guarded by a `TODO(story 005)` comment, or land 004 and 005 in one `/dev-story` session.
- `legal_commands()` in this story returns `[mulligan(all true)]` in Mulligan (plus `concede` once story 008 adds it) and `[]` otherwise; stories 010–016 expand it. Keep the signature `legal_commands() -> Array` and never allocate per hover beyond the result array.
- Subscriber re-entrancy for AC-37: use `TestEventLog.subscribe` with a callback that calls `engine.submit(...)`; the log itself accepts the nested append in release and the engine's `_resolving` guard produces `ENGINE_BUSY`.
- `phase()`, `pending_choice()`, `result()` are value getters (architecture.md §Core — Match Rules).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 005: `match_started`, Start step, `end_turn`, `TURN_CAP`
- Story 008: `concede`, `MATCH_ENDED` after a real end, `resolver.unbind()`
- Story 010 / 012 / 016: the `play_card`, `use_hero_power`, `attack`, `choose` handlers and their codes
- boss-ai-match-driver epic: `MatchDriver`'s `concede_queued` slot and `issuer` stamping

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/gameplay/match/rules_engine.gd` (`submit`, `legal_commands`, `phase`, `pending_choice`, `result`, phase guard table, rejection constants, `mulligan` handler)
- `src/gameplay/match/match_records.gd` (`CommandResult`, `Command` builders)
- `tests/unit/match_rules/match_rules_command_channel_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/match_rules/match_rules_command_channel_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later). `qa.level: standard` — BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/match-rules/story-003-match-setup.md`
- Unlocks: `production/epics/match-rules/story-005-turn-structure-and-mana.md`
