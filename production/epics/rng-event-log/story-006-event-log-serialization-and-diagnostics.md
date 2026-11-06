# Story 006: EventLog serialisation — to_json / from_json, payload coercion, diagnostic round-trip

> **Epic**: RNG & Event Log
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-03

## Context

**GDD**: `design/gdd/rng-event-log.md`
**Requirement**: `TR-rng-event-log-005` (also `TR-rng-event-log-004`)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Seeded RNG Service and Event Log (also ADR-0006: Boss AI Planner Threading and ADR-0009 — consumers of diagnostic events)
**ADR Decision Summary**: `to_json()` produces `{log_schema_version, engine_version, data_version, run_seed_hex, scope, floor, events[]}` with `JSON.stringify(dict, "\t")`; canonical form for F6 is sorted keys, floats to 6 decimals, `StringName` as `String` (`EventLogAssertions.canonical_json` is the reference); payload values are validated at append in debug and coerced in release (`"<unserializable:ClassName>"` + `payload._coerced[]`); diagnostics (`command_rejected`, `ai_decision`, `ai_plan_aborted`, `ai_fault`, `run_warning`) are ordinary appends with `payload.diagnostic = true` — no second channel, no filter.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH / NOT SOURCEABLE
**Engine Notes**: `JSON.parse_string` returns `float` for every number and loses precision above 2^53 (probe E, observed) — `run_seed_hex` is a string and integral floats are coerced back to `int` on load. `JSON.stringify` on 4.7.2 already emits sorted keys (probe E4) but the canonicaliser must not rely on it. Use the instance form `JSON.new()` + `parse(text)` for error lines.

The serialised log is the bug-report attachment and the replay input (rule 17, Pillar 4). Rule 12a puts diagnostics on the same log so one file is the bug report; filtering is Match UI's job.

**Control Manifest Rules (this layer)**:
- Required: `to_json()` = `JSON.stringify(dict, "\t")` with the seven-field header; 64-bit values cross JSON as 16-hex strings, small integers coerced back with `int()` on load; diagnostics share the log with `payload.diagnostic = true`; parse with `JSON.new()` + `parse(text)`.
- Forbidden: never a second event channel or a log filter in `src/core/log/`; never trust `JSON.parse_string` to return an `int`; never `assert()` on data in release paths.
- Guardrail: open match log ≤ `log_memory_budget_bytes` 2 MB; typical 60–400 KB.

---

## Acceptance Criteria

*From GDD `design/gdd/rng-event-log.md` (rules 12a, 14, 17; F6; Edge Cases "Events"), scoped to this story:*

- [ ] **GIVEN** a match log, **WHEN** `to_json()` then `from_json()`, **THEN** `replay_equal` holds between the original and the round-tripped log (F6); the JSON header carries `{log_schema_version, engine_version, data_version, run_seed_hex, scope, floor, events[]}`; a `run_seed` above 2^53 survives as `run_seed_hex` bit-exactly; `StringName` values come back as `String`; `seq`, `turn`, `cause_seq` and integral payload numbers come back as `int`; a float payload value is printed with 6 decimals in canonical form.
- [ ] **GIVEN** a payload containing a `Vector2`, **WHEN** appended in a release build and serialised, **THEN** `to_json()` succeeds, the value reads `"<unserializable:Vector2>"` and `_coerced` lists the key (in debug the append asserts).
- [ ] **GIVEN** an open match log, **WHEN** `append("command_rejected", {diagnostic: true, …}, 0)` is called, **THEN** it receives the next `seq`, `events_since` returns it, and `to_json()` round-trips it with `replay_equal` holding (rule 12a); it is counted by `size()` like any event and may be named as another event's `cause_seq`.
- [ ] **Canonical equality (F6):** two logs built by the same scripted sequence of appends compare byte-equal under `EventLogAssertions.canonical_json` and `to_json()`, and a log differing in one payload value does not.

---

## Implementation Notes

*Derived from ADR-0003 Implementation Guidelines and Decision 4–6, 9:*

- `to_json() -> String`: build `{log_schema_version: 1, engine_version, data_version, run_seed_hex, scope, floor, events}` from `meta` and the event array; `JSON.stringify(dict, "\t")`. `static from_json(text: String) -> EventLog`: `JSON.new().parse(text)` (report `get_error_line()` / `get_error_message()` on failure, return `null`), rebuild an `EventLog` with the header's `meta`, coerce integral floats to `int` recursively (as `TestEventLog._coerce_integral_floats`), restore `sealed` by inspecting the last event type.
- Payload coercion at append time (`Story 005`'s `append` grows this): walk the payload; `int`, `float`, `bool`, `String`, `StringName` (→ `String`), `null`, `Array`/`Dictionary` of those pass; anything else becomes `"<unserializable:" + class_name + ">"` and the key path is pushed onto `payload._coerced` (release); `assert` in debug. Must never `assert()` on data in release paths.
- Diagnostics need no code path of their own — the AC proves the absence of a filter. Must never add a second channel or a filter here; `MatchViewState` filters (match-ui U3 rule 4a).
- Canonical form for tests: `EventLogAssertions.canonical_json` (sorted keys, floats 6 decimals, `StringName` as `String`) is the reference; production `to_json()` output must round-trip to the same canonical string, not necessarily be byte-identical to it.
- Must never trust `JSON.parse_string` to return an `int`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 005: the writer, readers and sealing.
- Story 007: overflow and config knobs.
- Story 009: writing the JSON to `user://logs/`.
- Meta Progression epic: `log_schema_version` migration of older run logs; newer-schema logs kept opaque.
- Deferred (Vertical Slice): the replay viewer that consumes `from_json()`.

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/core/log/event_log.gd` — modified (`to_json`, static `from_json`, `LOG_SCHEMA_VERSION`, `ENVELOPE_KEYS`, append-time rule 14 coercion with `_coerced[]`)
- `src/core/data/json_text.gd` — created (`JsonText.parse`: the in-memory JSON parser seam; OUT OF the planned list — see Completion Notes)
- `tests/unit/rng_event_log/event_log_serialization_test.gd` — created (17 test functions)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: standard` Logic tests are BLOCKING.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/rng_event_log/event_log_serialization_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] Created — `tests/unit/rng_event_log/event_log_serialization_test.gd` (17 tests, passing)

---

## Dependencies

- Depends on: `production/epics/rng-event-log/story-005-event-log-core-append-subscribe-seal.md`
- Unlocks: `production/epics/rng-event-log/story-009-match-log-archive-to-user-logs.md`, `production/epics/rng-event-log/story-010-determinism-contract-and-performance-budgets.md`, `production/epics/rng-event-log/story-011-replay-equivalence-integration.md`

---

## Completion Notes
**Completed**: 2026-11-03
**Started / ended (UTC)**: 2026-11-03T21:12:32Z – 2026-11-03T21:16:30Z
**Criteria**: 4/4 passing (all covered by unit tests; no deferred items)

| Criterion | Covered by | Status |
|-----------|------------|--------|
| AC-1: round trip `replay_equal`, seven-field header, `run_seed` > 2^53 as hex, `StringName` → `String`, ints back as `int`, float 6 decimals | `event_log_serialization_test.gd::test_to_json_then_from_json_is_replay_equal`, `test_json_header_carries_the_seven_fields_from_meta`, `test_to_json_is_tab_indented`, `test_run_seed_above_two_pow_53_survives_as_run_seed_hex_bit_exactly`, `test_string_name_values_and_keys_are_stored_and_round_tripped_as_string`, `test_seq_turn_cause_seq_and_integral_payload_numbers_come_back_as_int`, `test_float_payload_value_stays_float_and_prints_with_six_decimals`, `test_from_json_restores_scope_turn_and_sealed_state`, `test_from_json_rejects_malformed_text_with_the_error_line`, `test_from_json_rejects_a_non_log_document` | COVERED |
| AC-2: `Vector2` payload → `"<unserializable:Vector2>"`, `_coerced` lists the key, `to_json()` succeeds; debug asserts | `test_vector2_payload_is_reported_coerced_listed_and_serialised`, `test_nested_and_object_values_are_coerced_with_their_key_paths`, `test_json_only_payload_is_not_reported_and_carries_no_coerced_list` | COVERED |
| AC-3: `command_rejected{diagnostic: true}` takes the next `seq`, `events_since`, `size()`, `cause_seq` target, round trip | `test_command_rejected_diagnostic_is_an_ordinary_event` | COVERED |
| AC-4: same script → byte-equal canonical form and `to_json()`; one differing payload value → not equal | `test_two_logs_from_the_same_script_are_byte_equal_in_canonical_form_and_to_json`, `test_a_log_differing_in_one_payload_value_is_not_equal`, `test_round_tripped_to_json_reproduces_the_same_canonical_form` | COVERED |

**Deviations**:
- ADVISORY / OUT OF SCOPE — **parser seam `src/core/data/json_text.gd` (new file, not in the planned list).** ADR-0003 Decision 9 / the manifest's Foundation Required row say `from_json` parses with the `JSON` instance form, but ADR-0002's Forbidden row and the single-parser gate (`card_database_single_parser_test.gd`, tightened 2026-11-03 in 9cd3156) forbid any `JSON` instance outside `src/core/data/`. `EventLog.from_json` therefore calls `JsonText.parse(text)` — the instance form (1-based line + message), living in `src/core/data/` so the gate holds unchanged. Not done: moving `DataLoader`'s own stage-2 parse onto it (card-database lane edits `data_loader.gd` this sprint). ADR-0004's profile load will meet the same conflict; the ADR-0002 rule should say "a `JSON` instance outside `src/core/data/` — non-data readers call `JsonText.parse`" (a doc follow-up for technical-director, not made here).
- ADVISORY — `from_json(text, max_events = 0)`: the ADR signature has no cap argument; an optional one is added because the header carries no cap. 0 takes the number of events read (an unsealed rebuilt log then faults on its next append once Story 007's overflow is in); a sealed log ignores it.
- ADVISORY — coercion runs in every build after the debug assert is reported (the assert aborts only the reporting helper), so a debug log also always serialises; a non-String Dictionary key is replaced by its `str()` form and listed as `"<path>[key K]"`; `StringName` values and keys become `String` silently (rule 14 allows them).
- ADVISORY — known limit, documented in the class: a whole-number float payload value (`2.0`) comes back as `int` (JSON numbers are doubles; Edge Cases: gameplay quantities are ints). Payload ints above 2^53 are not hex-coerced at append (rule: 64-bit values go in payloads as hex strings — the owner's job).
**Test Evidence**: `tests/unit/rng_event_log/event_log_serialization_test.gd` — 17 tests; a mutation (no int coercion on load, no `StringName` conversion, no key report) was seen failing (exit 100) before restore. Full suite 373/373 passed, exit 0; 2 new SCRIPT ERRORs are the intentional coercion asserts (29 total). Smoke exit 0, no SCRIPT ERROR.
**Run result**: N/A — serialisation has no scene, node or screen; nothing is drawn or launched (the replay viewer that would show it is deferred to Vertical Slice).
**Engine check**: NOT ASSESSED — no specialist agent in this lane; `JSON.stringify(dict, "\t")` tab layout, `get_error_line()` 0-based and float-only numbers observed on 4.7.2 by the tests themselves.
**Reviewed by**: self, no independent review (`review_mode: lean` — QL-TEST-COVERAGE and LP-CODE-REVIEW skipped; `/code-review` not run in this lane)
