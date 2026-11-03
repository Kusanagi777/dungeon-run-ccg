# Story 005: EventLog core — envelope, append, subscribe, events_since, turn, sealing

> **Epic**: RNG & Event Log
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/rng-event-log.md`
**Requirement**: `TR-rng-event-log-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Seeded RNG Service and Event Log (also ADR-0009: Match UI Animation Queue — the consumer of `subscribe` / `events_since`)
**ADR Decision Summary**: `EventLog.append(type, payload, cause_seq = 0) -> int` is the only writer: it stamps `seq` (1-based) and `turn` (from `set_turn`, 0 before the first call), stores `type` as `String`, deep-copies `payload`, appends, then notifies subscribers synchronously in registration order on the calling thread; it returns `-1` when sealed. Subscribers are synchronous, main-thread, by-value lambdas; a re-entrant append is asserted in debug and tagged `payload._reentrant = true` in release. No Godot signals for event delivery.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: GDScript lambdas capture locals by value (sourced, `current-best-practices.md`) — subscriber code that accumulates state closes over a Dictionary or object; typed `Array[Dictionary]` / `Array[Callable]`; explicit `return` on typed overrides (4.7). No post-cutoff API needed.

This is the single event channel every rules module writes and the UI reads (DD-T04, Pillar 4). `tests/helpers/test_event_log.gd` is the behavioural reference and stays as the tiny-`max_events` double after its `TODO(E1 story)` swap. Overflow, serialisation and the summary are later stories; this one lands the writer, the readers and sealing.

**Control Manifest Rules (this layer)**:
- Required: `EventLog` (`src/core/log/`) is a concrete `RefCounted` constructed by `RunMachine` / `MatchDriver` and by tests directly; `append` is the only writer, stamps `seq` and `turn`, stores `type` as `String`, deep-copies `payload`, notifies subscribers synchronously in registration order, returns `-1` when sealed; subscribers are synchronous, main-thread, by-value lambdas; diagnostics share the log with `payload.diagnostic = true`.
- Forbidden: never Godot signals for event delivery (`overflowed` is the one exception); never a second event channel or a log filter in `src/core/log/`; never append to or subscribe to the live log from a worker thread; never reference `Boot` from `src/core/**`.
- Guardrail: `EventLog` 10,000 appends within the 50 ms AC (measured in Story 010).

---

## Acceptance Criteria

*From GDD `design/gdd/rng-event-log.md` (rules 11–15; Edge Cases "Events"), scoped to this story:*

- [ ] **GIVEN** an open match log, **WHEN** 5 events are appended, **THEN** `seq` is 1..5, `events_since(3)` returns exactly seq 4 and 5, and each subscriber received each event once in order (rule 13, F7); every event is `{seq, turn, type, payload, cause_seq}` with `type` a `String` (`EventLogAssertions.assert_envelopes_valid` holds) and `payload` a deep copy (mutating the caller's Dictionary after `append` leaves the stored event unchanged).
- [ ] **GIVEN** an event appended with `cause_seq = 40` while event 40 resolves, **WHEN** inspected, **THEN** its `seq > 40` and `cause_seq == 40`; `events_since(seq)` with `seq` ≥ the last `seq` returns an empty array and with `seq < 0` returns every event (neither is an error).
- [ ] **Turn stamp and sealing (rules 11, 13, 15):** `turn` is 0 before the first `set_turn(n)` and equals the last `set_turn` value afterwards; appending `match_ended` (scope `match`) or `run_ended` (scope `run`) seals the log (`is_sealed() == true`); a later `append` returns `-1`, stores nothing, notifies no subscriber and pushes a warning in release (assert in debug); `size()` and `snapshot()` (metadata block plus the full event array) report the sealed contents.
- [ ] **Re-entrancy (Edge Cases):** a subscriber callback that calls `append` is asserted in debug; in release the nested append is accepted, takes the next `seq`, and its payload carries `_reentrant: true`.

---

## Implementation Notes

*Derived from ADR-0003 Implementation Guidelines and Decision 5–7:*

- `src/core/log/event_log.gd`: `class_name EventLog extends RefCounted`; `_init(max_events: int, scope: String, meta: Dictionary = {})` — `max_events` arrives from the composition root (never read `config()` here; Story 007 wires the derivation), `meta = {engine_version, data_version, run_seed_hex, floor}`.
- `append(type: StringName, payload: Dictionary, cause_seq: int = 0) -> int`: if sealed → `-1` (+ `push_warning` release / `assert` debug); stamp `seq = size() + 1`, `turn = current_turn`, `type = String(type)`, `payload = payload.duplicate(true)`; append; then call each subscriber in registration order with the event. The nested-append guard is a `_notifying` flag: when set, tag `payload._reentrant = true` (release) / `assert` (debug).
- `set_turn(turn: int)`: Match Rules calls it immediately before appending `turn_started` (match-rules C15); run-scope logs leave it 0.
- `subscribe(callback: Callable)`: register only; delivery is in `append`. `events_since(seq: int) -> Array[Dictionary]`: slice by `seq`, typed.
- Sealing: `match_ended` seals a `match`-scope log, `run_ended` a `run`-scope log; `is_sealed() -> bool`. The Faulted path (overflow) is Story 007.
- Must emit exactly one event per state mutation, after the mutation, with `cause_seq` = the outer event's `seq` during nested resolution — this story provides the mechanism; the owner systems obey the rule.
- Payload JSON validation / coercion at append time is Story 006; this story may assert `GameAssertions.is_json_representable` in debug only.
- Swap `TestEventLog`'s `TODO(E1 story)`: tests that need the real log construct `EventLog.new(max_events, "match")` directly; keep `TestEventLog` for tiny-cap and scripted cases.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 006: `to_json()` / `from_json()`, canonical form, payload coercion (`_coerced[]`), diagnostic round-trip.
- Story 007: `log_overflow`, `overflowed` signal, the Faulted state, `max_events` derivation and `validate_config`.
- Story 008: `reduce_to_summary()`.
- Match UI epic: filtering `diagnostic` events from the feed (`MatchViewState`).

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/core/log/event_log.gd`
- `tests/unit/rng_event_log/event_log_test.gd`
- `tests/helpers/test_event_log.gd` (TODO(E1) note updated)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: standard` Logic tests are BLOCKING.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/rng_event_log/event_log_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None
- Unlocks: `production/epics/rng-event-log/story-006-event-log-serialization-and-diagnostics.md`, `production/epics/rng-event-log/story-007-overflow-fault-and-config-knobs.md`, `production/epics/rng-event-log/story-008-match-summary-reduction.md`
