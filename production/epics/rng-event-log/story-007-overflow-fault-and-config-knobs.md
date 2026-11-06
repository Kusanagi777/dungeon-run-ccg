# Story 007: Overflow fault (`log_overflow` → Faulted → Sealed) and the `rng_event_log` config knobs

> **Epic**: RNG & Event Log
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-03

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

- `src/core/log/event_log.gd` — modified (`signal overflowed`, overflow → Faulted → Sealed in `append`, static `max_events_for`, static `validate_config` + `CONFIG_FILE` / `CONFIG_SAFE_RANGES` / `KEEP_MATCH_LOGS_KEYS` / `E_MISSING_FIELD` / `E_SCHEMA` / `E_RANGE`, Faulted restored by `from_json`)
- `assets/data/rng_event_log.json` — created (CR-1 envelope, DD-T01 defaults)
- `src/core/boot.gd` — one line: `configs.rng_event_log = EventLog.validate_config` in `_collect_validators()` (named by the lane brief)
- `tests/unit/rng_event_log/event_log_overflow_test.gd` — created (21 test functions)
- `tests/integration/rng_event_log/event_log_config_file_test.gd` — created (5 test functions: the shipped file through `DataLoader`, and the knob-literal scan of `src/core/log/`)
- `tests/helpers/test_event_log.gd` — header comment: cap wording settled

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: standard` Logic tests are BLOCKING. The data file is additionally covered by the smoke check once Card Database loads it.*

**Story Type**: Logic (mixed Logic + Config/Data; Logic carries the higher implementation risk)
**Required evidence**:
- Logic: `tests/unit/rng_event_log/event_log_overflow_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] Created — `tests/unit/rng_event_log/event_log_overflow_test.gd` (21 tests) + `tests/integration/rng_event_log/event_log_config_file_test.gd` (5 tests), passing

---

## Dependencies

- Depends on: `production/epics/rng-event-log/story-005-event-log-core-append-subscribe-seal.md`
- Unlocks: `production/epics/rng-event-log/story-009-match-log-archive-to-user-logs.md`

---

## Completion Notes
**Completed**: 2026-11-03
**Started / ended (UTC)**: 2026-11-03T21:16:34Z – 2026-11-03T21:21:30Z
**Criteria**: 3/3 passing (all covered by tests; no deferred items)

| Criterion | Covered by | Status |
|-----------|------------|--------|
| AC-1: at `max_events = 5` → `log_overflow{cap, seq}`, `overflowed` once, exactly one more append (caller's `match_ended(fault)`), sealed, later `-1`; log never appends `match_ended` | `event_log_overflow_test.gd::test_append_at_the_cap_appends_log_overflow_and_drops_the_attempted_event`, `test_overflowed_signal_fires_once_with_cap_and_seq`, `test_faulted_log_accepts_exactly_one_more_event_then_is_sealed`, `test_the_log_never_appends_match_ended_itself`, `test_the_one_further_event_may_be_any_type_and_still_seals`, `test_subscribers_receive_log_overflow_before_the_signal_fires`, `test_match_ended_appended_from_the_overflowed_handler_is_accepted_untagged`, `test_a_faulted_log_round_trips_as_faulted`, `test_the_cap_applies_to_run_scope_logs_too` | COVERED |
| AC-2: `assets/data/rng_event_log.json` with the DD-T01 body; `max_events_for` → 10,000 / 2,500; no knob literal in `src/core/log/` | `event_log_config_file_test.gd::test_shipped_file_loads_and_carries_the_story_defaults`, `test_max_events_for_the_shipped_file_is_ten_thousand`, `test_matcher_catches_each_knob_literal_and_skips_range_bounds`, `test_no_knob_literal_appears_in_src_core_log`; `event_log_overflow_test.gd::test_max_events_for_the_defaults_is_ten_thousand`, `test_max_events_for_the_minimum_budget_is_two_thousand_five_hundred`, `test_max_events_for_floors_the_quotient_and_accepts_json_floats`, `test_max_events_for_a_body_without_the_knobs_reports_and_returns_zero` | COVERED |
| AC-3: `validate_config(body, db)` static, `[]` for the shipped file, one entry by key for each out-of-range / non-bool / missing knob, never asserts | `event_log_config_file_test.gd::test_validate_config_returns_no_entry_for_the_shipped_file`; `event_log_overflow_test.gd::test_validate_config_accepts_the_shipped_body_and_the_range_bounds`, `test_validate_config_reports_each_out_of_range_knob_once_by_key`, `test_validate_config_reports_a_missing_key_once_by_key`, `test_validate_config_reports_a_non_bool_or_missing_keep_match_logs_entry`, `test_validate_config_reports_a_non_whole_number_knob`, `test_validate_config_entries_have_the_validation_report_shape`, `test_validate_config_never_asserts_on_bad_data`, `test_boot_registers_validate_config_as_the_rng_event_log_config_validator` | COVERED |

**Deviations**:
- ADVISORY / OUT OF SCOPE (sanctioned) — `src/core/boot.gd` `_collect_validators()` gains the `rng_event_log` entry. The story's Out of Scope gives this to Boot & Composition Root; the lane brief named it as this story's one-line change. The `FILE_MANIFEST` row already existed.
- ADVISORY — codes: the story says "`E_RANGE` for out-of-range, missing-key code per `DataLoader`"; `ValidationReport` defines neither yet (card-database lane adds the CR-5 set this sprint), so `EventLog` declares `E_MISSING_FIELD`, `E_SCHEMA` (wrong type) and `E_RANGE` with the ADR-0002 spellings. `E_RANGE` is not in ADR-0002's closed CR-5 list (the story names it); stage 7 merges owner codes under `E_DELEGATED`.
- ADVISORY — the shipped-file and no-literal checks read repository files, so they live in a new integration suite (the match-rules precedent), not in the unit file the story names.
- ADVISORY — the dropped append at the cap pushes a warning (a rules fault, not a caller bug: no assert); `max_events_for` on a body without the knobs pushes an error and returns 0 (a log built with 0 faults on its first append) rather than a fallback cap.
- ADVISORY — `TestEventLog` keeps its shortcut (it fabricates `match_ended` on overflow) for existing callers; only its header comment changed, pointing at the production rule. `tests/fixtures/data/*/rng_event_log.json` still carry `config: {}`: once card-database stage 7 runs config validators with Boot's map, a fixture root used with the real validators will report three `E_MISSING_FIELD` (same as `match_rules.json` there today) — card-database lane's call.
**Test Evidence**: unit `tests/unit/rng_event_log/event_log_overflow_test.gd` (21) + integration `tests/integration/rng_event_log/event_log_config_file_test.gd` (5); mutations (no seal after the Faulted event, F7 off by one, a closed range bound) each seen failing (exit 100) before restore. Full suite 399/399 passed, exit 0; 1 new SCRIPT ERROR is the intentional sealed-append assert (30 total). Smoke exit 0, no SCRIPT ERROR.
**Run result**: N/A — the overflow fault and the config knobs have no scene or screen; the data file is loaded only by Card Database (no player-visible surface until Run Structure returns a faulted floor to `pre_match`).
**Engine check**: NOT ASSESSED — no specialist agent in this lane; `signal` with typed args, `@warning_ignore("integer_division")` and typed `Dictionary[String, Array]` consts parse on 4.7.2.
**Reviewed by**: self, no independent review (`review_mode: lean` — QL-TEST-COVERAGE and LP-CODE-REVIEW skipped; `/code-review` not run in this lane)
