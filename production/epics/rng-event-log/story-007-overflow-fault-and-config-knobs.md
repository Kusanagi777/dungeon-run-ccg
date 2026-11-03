# Story 007: Overflow fault (`log_overflow` → Faulted → Sealed) and the `rng_event_log` config knobs

> **Epic**: RNG & Event Log
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/rng-event-log.md`
**Requirement**: `TR-rng-event-log-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Seeded RNG Service and Event Log (also ADR-0002: Data Format, Effect Schema and Config Loading — the `rng_event_log.json` config row and `EventLog.validate_config`)
**ADR Decision Summary**: At `max_match_events = floor(log_memory_budget_bytes / avg_event_bytes)` (10,000 at defaults) the log appends `log_overflow{cap, seq}`, emits `overflowed(cap, seq)`, accepts exactly one more event (Match Rules' `match_ended{result: fault, reason: event_cap}`), then is sealed; the log never fabricates a Match Rules event. `max_events`, `keep_match_logs` and `avg_event_bytes` come from `config("rng_event_log")` at the composition root and are never hardcoded; ADR-0002 lists `rng_event_log.json` in DD-T01 / `FILE_MANIFEST` with validator `EventLog.validate_config`.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: `signal overflowed(cap: int, seq: int)` is the one sanctioned signal on the log (the Faulted transition); typed Arrays; explicit `return` on typed overrides (4.7). No post-cutoff API.

`log_overflow` is the second line of defence behind Match Rules' `RESOLUTION_STEP_CAP` and Card Effects' `EFFECT_STATIC_STEP_LIMIT`; hitting it means a knob was lowered or a primitive emits too many events — a rules bug the player does not pay for (Pillar 3; Run Structure returns to `pre_match`). The knobs are engineering budgets, not balance values, but DD-T01 still forbids hardcoding them.

**Control Manifest Rules (this layer)**:
- Required: overflow = append `log_overflow{cap, seq}`, emit `overflowed`, accept exactly one more event, then sealed; `max_events`, `keep_match_logs`, `avg_event_bytes` come from `config("rng_event_log")` at the composition root; all game data is JSON under `assets/data/` in the code-owned `FILE_MANIFEST`; register a validator for every externally owned config file (`static func`, called as `call(body, db)`); read `config(<name>)` once in the owner's `_init` / `bind` and keep the reference.
- Forbidden: never hardcode `max_events`, `keep_match_logs` or `avg_event_bytes`; never a numeric gameplay default in loader code; never a per-system loader or any JSON parse outside `CardDatabase` in `src/`; never `assert()` on data in release paths.
- Guardrail: open match log ≤ `log_memory_budget_bytes` 2 MB (`max_match_events` 10,000 at defaults).

---

## Acceptance Criteria

*From GDD `design/gdd/rng-event-log.md` (rule 16, F7, Tuning Knobs, Edge Cases "max_match_events", Acceptance Criteria "No hardcoded values"), scoped to this story:*

- [ ] **GIVEN** a log at `max_match_events` (test with `max_events = 5`), **WHEN** another append is attempted, **THEN** the log holds `log_overflow{cap, seq}`, the `overflowed(cap, seq)` signal fired once, exactly one further append is accepted (`match_ended{result: fault, winner: null, reason: event_cap}` appended by the caller — the test plays Match Rules), the log is sealed, and further appends are dropped (`-1`); the log never appends a `match_ended` itself (State table: `Open → Faulted → Sealed`).
- [ ] **No hardcoded values (DD-T01):** `assets/data/rng_event_log.json` exists with `schema_version` and a body of `{log_memory_budget_bytes: 2000000, avg_event_bytes: 200, keep_match_logs: {debug: true, release: false}}`; `max_match_events = floor(log_memory_budget_bytes / avg_event_bytes)` is computed by a static `EventLog.max_events_for(config: Dictionary) -> int` that returns 10,000 at those defaults and 2,500 at the minimum budget; no literal `2000000`, `200` or `10000` for these knobs appears in `src/core/log/`.
- [ ] **`EventLog.validate_config(body, db) -> Array` (ADR-0002 stage 7a):** returns `[]` for the shipped file; returns one entry naming the key for `log_memory_budget_bytes` outside 500,000 – 20,000,000, `avg_event_bytes` outside 100 – 400, a non-bool `keep_match_logs` entry, or a missing key; it is a `static func` and never asserts.

---

## Implementation Notes

*Derived from ADR-0003 Implementation Guidelines and Decision 8, ADR-0002 Decision 1 and 4:*

- Overflow in `append`: when `size() == max_events` and the log is Open, append `log_overflow{cap: max_events, seq: <its own seq>}`, enter Faulted, `overflowed.emit(cap, seq)`; in Faulted accept exactly one more append (any type — the contract says Match Rules sends `match_ended{result: fault, reason: event_cap}`) and then seal. This settles the wording difference `TestEventLog`'s header notes against match-rules Edge Cases: "overflow event, then one more append, then sealed" is the production rule; update the helper's comment to point here.
- `max_events` reaches `EventLog._init(max_events, scope, meta)` from the composition root (`RunMachine` builds `MatchConfig` per attempt); this story adds `static func max_events_for(config: Dictionary) -> int` so the root computes F7 in one place and `keep_match_logs` selection by build type (`OS.is_debug_build()`) at the root is a one-liner — the root wiring itself belongs to the Run Structure epic.
- `assets/data/rng_event_log.json`: CR-1 envelope (`CardFactory.make_config_file` shape: `schema_version` + body). The `FILE_MANIFEST` row (`{name: "rng_event_log", class: config, required: true, owner: "RNG & Event Log"}`) and the `configs: {rng_event_log: EventLog.validate_config}` binding at `Boot.boot()` are Card Database and Boot & Composition Root work respectively — name them in the PR, do not add a parser here.
- `validate_config` is a `static func` returning validation entries in ADR-0002's closed code set (`E_RANGE` for out-of-range, missing-key code per `DataLoader`); it must never pass silently and must never assert on data in any build.
- Must never read `config()` per frame, per command or per append.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 009: writing the faulted log to `user://logs/faults/`.
- Card Database epic: the `FILE_MANIFEST` row and `config("rng_event_log")` loading.
- Boot & Composition Root epic: binding `EventLog.validate_config` into the validator map.
- Run Structure / Match Rules epics: emitting `match_ended{result: fault}` and `match_faulted`, returning to `pre_match`.
- Deferred: `keep_match_logs` default per build type in release (Open Question 5).

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/core/log/event_log.gd`
- `assets/data/rng_event_log.json`
- `tests/unit/rng_event_log/event_log_overflow_test.gd`
- `tests/helpers/test_event_log.gd` (header comment: cap wording settled)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: standard` Logic tests are BLOCKING. The data file is additionally covered by the smoke check once Card Database loads it.*

**Story Type**: Logic (mixed Logic + Config/Data; Logic carries the higher implementation risk)
**Required evidence**:
- Logic: `tests/unit/rng_event_log/event_log_overflow_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/rng-event-log/story-005-event-log-core-append-subscribe-seal.md`
- Unlocks: `production/epics/rng-event-log/story-009-match-log-archive-to-user-logs.md`
