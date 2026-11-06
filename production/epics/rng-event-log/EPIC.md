# Epic: RNG & Event Log

> **Layer**: Foundation
> **GDD**: design/gdd/rng-event-log.md (Overview, Detailed Rules 1–19, Formulas F1–F7, Acceptance Criteria)
> **Architecture Module**: `RngService` / `RngStream` (`src/core/rng/`) and `EventLog` (`src/core/log/`)
> **Control Manifest**: Foundation Layer Rules (Manifest Version 2026-11-03)
> **Build Order**: 2 of 14 — plan E1 (Foundation), ADR-0003
> **Status**: Ready
> **Stories**: 11 (see table below) — created 2026-11-03 by `/create-stories rng-event-log`

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | RngStream — engine golden pin and F4 draw primitives (gate condition 7) | Logic | Ready | ADR-0003 |
| 002 | RngService — seed derivation (F1–F3) and memoised named streams | Logic | Ready | ADR-0003 |
| 003 | Snapshot and restore by reseed-and-discard, command guard, hex snapshot form | Logic | Ready | ADR-0003 |
| 004 | No-global-RNG lint (`tools/lint/no_global_rng.sh`) in CI | Logic | Ready | ADR-0003 |
| 005 | EventLog core — envelope, append, subscribe, events_since, turn, sealing | Logic | Ready | ADR-0003 |
| 006 | EventLog serialisation — to_json / from_json, payload coercion, diagnostic round-trip | Logic | Ready | ADR-0003 |
| 007 | Overflow fault and the `rng_event_log` config knobs | Logic | Ready | ADR-0003 |
| 008 | `reduce_to_summary()` — match_summary and damage_by_card (rule 19) | Logic | Ready | ADR-0003 |
| 009 | Match log archive to `user://logs/` (needs ADR-0004 `AtomicFileWriter`) | Integration | Ready | ADR-0003 |
| 010 | Determinism contract (F6 self-test) and performance budgets | Logic | Ready | ADR-0003 |
| 011 | Replay equivalence across systems (needs Run Structure, Reward Draft, Match Rules) | Integration | Ready | ADR-0003 |

## Overview

Build the determinism layer every rule sits on. `RngService(run_seed, data_version)` hands out memoised named streams (`run`, `match_<f>`, `draft_<f>`, `ai_<f>`) seeded by FNV-1a 64 + SplitMix64 (F1–F3), with `fork(label)`, the draw API (`randi_range`, `randf`, `shuffle`, `weighted_pick`) and `snapshot()` / `restore()` by reseed-and-discard, 64-bit values crossing JSON as 16-hex strings. `EventLog.append(type, payload, cause_seq)` is the only writer of the append-only `{seq, turn, type, payload, cause_seq}` log: one event per mutation, diagnostics on the same channel with `payload.diagnostic = true`, synchronous main-thread by-value subscribers, sealing on `match_ended` / `run_ended`, the 2 MB overflow fault and the `user://logs/` archive. Pillar 4 (replay from seed), headless AI-vs-AI simulation and every unit test's determinism rule depend on it, and `RandomNumberGenerator` is NOT SOURCEABLE in the engine reference, so the first story pins the engine's output sequence.

## Scope (MVP)

- `RngService`, `RngStream` (one `RandomNumberGenerator` per stream, `seed` set once, `randi32()` the only generator call), `run_seed_from_input(input, entropy)` with the single allow-listed entropy call
- `EventLog` with `set_turn`, `subscribe`, `events_since`, `snapshot`, `to_json` / `from_json`, `reduce_to_summary`, `max_events` from `config("rng_event_log")`
- `tools/lint/no_global_rng.sh` (rule 7: nothing under the rules tree calls global RNG)
- `tests/unit/rng_event_log/rng_engine_pins_test.gd` — the 100-draw golden-sequence pin (seed 42 → 492690617, 1919685028, 3561993920 observed 2026-11-03) in the **first** story

Out of scope: `keep_match_logs` default per build type and the replay viewer (Vertical Slice, architecture.md "Can defer").

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0003: Seeded RNG Service and Event Log | One injected `RefCounted` service, named memoised streams, FNV-1a 64 + SplitMix64, snapshot/restore by draw counts, append-only log with `cause_seq`, synchronous subscribers, 2 MB budget | HIGH / NOT SOURCEABLE (`RandomNumberGenerator`, int overflow — closed by headless probe) |
| ADR-0001: Rules / Presentation Split | Only `src/core/**` touches `RandomNumberGenerator` and `user://`; tests construct `TestRngService` / `TestEventLog` directly | HIGH |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-rng-event-log-001 | Rules 1-6: one RngService(run_seed, data_version); memoised named streams run, match_<f>, draft_<f>, ai_<f>; fork(label); draw API randi_range, randf, shuffle, weighted_pick | ADR-0003 ✅ |
| TR-rng-event-log-002 | Rule 7: no code under the rules tree calls global RNG; randomness is an injected parameter | ADR-0003 ✅ |
| TR-rng-event-log-003 | Rules 9-10: replay equivalence per command sequence; snapshot() returns {run_seed_hex, data_version, streams{name: draws}} (64-bit values are hex strings in every persisted form) and restore() rebuilds streams from draws counts | ADR-0003 ✅ (also ADR-0006) |
| TR-rng-event-log-004 | Rules 11-15: append-only log {seq, turn, type, payload, cause_seq}, one event per mutation, JSON-only payloads, sealed on match_ended / run_ended, subscribe / events_since | ADR-0003 ✅ (also ADR-0009) |
| TR-rng-event-log-005 | Rule 12a: diagnostic events (command_rejected, ai_decision, ...) go on the same log with payload.diagnostic = true | ADR-0003 ✅ (also ADR-0006, 0009) |
| TR-rng-event-log-006 | F7, rule 18: max_match_events = log_memory_budget_bytes / avg_event_bytes (10,000 at 2 MB); overflow is a fault; raw match logs to user://logs/<run_id>/floor_<n>_attempt_<k>.json when keep_match_logs | ADR-0003 ✅ (also ADR-0004) |

Requirements covered by Accepted ADRs: 6 / 6. Untraced Requirements: None.

## Gate Entry Conditions Carried

- **Condition 7**: the first RNG story adds the 100-draw golden-sequence pin test `tests/unit/rng_event_log/rng_engine_pins_test.gd` (ADR-0003) — gameplay-programmer.
- **Condition 6** (sprint-1 spike, shared): the headless AI-vs-AI harness must be deterministic per seed; that property is proven here (`snapshot` / `restore`, byte-identical logs) before the Boss AI epic consumes it.

## Definition of Done

- Every story implemented, reviewed and closed with `/story-done`
- Every acceptance criterion of design/gdd/rng-event-log.md verified
- The golden-pin test exists and passes on the installed 4.7.2; `no_global_rng.sh` is green in CI
- Logic and Integration stories have passing tests in the test root
- Visual/Feel and UI stories have retained screenshots in `production/qa/evidence/` (a lead sign-off too for Visual/Feel)
