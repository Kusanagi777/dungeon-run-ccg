# Story 009: Match log archive to `user://logs/` (keep_match_logs and the faults folder)

> **Epic**: RNG & Event Log
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/rng-event-log.md`
**Requirement**: `TR-rng-event-log-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Seeded RNG Service and Event Log (also ADR-0004: Save Format and Atomic Profile Write — `AtomicFileWriter`)
**ADR Decision Summary**: Raw match logs go to `user://logs/<run_id>/floor_<n>_attempt_<k>.json` when `keep_match_logs`, and to `user://logs/faults/<run_id>_floor_<n>_attempt_<k>.json` always on a `log_overflow`; the write goes through ADR-0004's `AtomicFileWriter` with `DirAccess.make_dir_recursive_absolute` first, so `src/core/log/` and `src/core/save/` remain the only openers of `user://`.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH / NOT SOURCEABLE
**Engine Notes**: `FileAccess.open` does not create parent directories (probe B, observed) — `make_dir_recursive_absolute` first; rename-over-existing semantics on Windows are NOT SOURCEABLE (ADR-0004), which is why every `user://` write goes through `AtomicFileWriter` (tmp → bak rotation → rename onto an absent path). `flush()` / `close()` issue no `fsync` — never claim power-loss durability.

The archive is what `/balance-check` and bug reports read. The faults folder exists so a `log_overflow` is always diagnosable regardless of the `keep_match_logs` setting. This story depends on `AtomicFileWriter`, which the Meta Progression epic builds; if that epic is scheduled later, the writer can be pulled forward as its first story rather than re-implemented here.

**Control Manifest Rules (this layer)**:
- Required: only `src/core/**` touches `FileAccess`, `DirAccess` and `user://`; `src/core/log/` and `src/core/save/` are the only openers of `user://`; logs go to `user://logs/<run_id>/floor_<n>_attempt_<k>.json` when `keep_match_logs` and to `user://logs/faults/…` always on `log_overflow`, through `AtomicFileWriter` with `make_dir_recursive_absolute` first; every file under `user://` is written through `AtomicFileWriter.write()` in the W1–W9 order.
- Forbidden: never write in place (`FileAccess.open(final, WRITE)`); never a background-thread save; never ignore a `false` from `store_string()`; never claim power-loss durability in UI copy, docs or stories; never hardcode `keep_match_logs`.
- Guardrail: a match log is typically 60–400 KB; `AtomicFileWriter` is synchronous on the main thread.

---

## Acceptance Criteria

*From GDD `design/gdd/rng-event-log.md` (rule 18; Edge Cases "max_match_events"; Tuning Knobs `keep_match_logs`), scoped to this story:*

- [ ] **GIVEN** a sealed match log and `keep_match_logs = true`, **WHEN** archived with `run_id = "<run_seed_hex>-<started_at>"`, `floor = n`, `attempt = k`, **THEN** `user://logs/<run_id>/floor_<n>_attempt_<k>.json` exists, its content equals `to_json()`, it was written through `AtomicFileWriter` (no `.tmp` left behind, directory created first), and reading it back with `EventLog.from_json` is `replay_equal` to the original; **GIVEN** `keep_match_logs = false`, **THEN** no file is written and no directory is created.
- [ ] **GIVEN** a log that reached `log_overflow` (Faulted → Sealed), **WHEN** archived with `keep_match_logs = false`, **THEN** `user://logs/faults/<run_id>_floor_<n>_attempt_<k>.json` exists with the full log; with `keep_match_logs = true` both the regular archive and the faults copy exist.
- [ ] **Write failure is visible, not fatal:** when `AtomicFileWriter.write()` returns an error (simulate with an unwritable path), the archive call returns that `Error`, the in-memory log is untouched, and no partial file sits at the final path.

---

## Implementation Notes

*Derived from ADR-0003 Implementation Guidelines and Decision 9, ADR-0004 Decision (AtomicFileWriter W1–W9):*

- Put the archive in `src/core/log/event_log_archive.gd` (`class_name EventLogArchive extends RefCounted`, `_init(writer: AtomicFileWriter, keep_match_logs: bool)`, `archive_match(log: EventLog, run_id: String, floor: int, attempt: int) -> Error`) so `EventLog` stays a pure data structure and the writer is injected — tests inject a real `AtomicFileWriter` pointed at a temp `user://` subfolder, or a stub.
- Paths: `user://logs/<run_id>/floor_<n>_attempt_<k>.json` (`k = match_attempts[floor]`, Run Structure's value) and `user://logs/faults/<run_id>_floor_<n>_attempt_<k>.json`; `run_id` is Run Structure's `<run_seed_hex>-<started_at>` so a replayed seed never overwrites an archive.
- `DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))` before every write; then `writer.write(path, log.to_json())` — W1–W9 live in the writer, not here.
- `keep_match_logs` arrives as a constructor argument chosen at the composition root from `config("rng_event_log").keep_match_logs[debug|release]` (Story 007's data file); never read `config()` here and never branch on `OS.is_debug_build()` in this class.
- Must never write on a worker thread; `archive_match` is called from `MatchDriver` / `RunMachine` on the main thread after `match_ended`, before `reduce_to_summary()`.
- Do not write "durable across power loss" anywhere — ADR-0004.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Meta Progression epic: `AtomicFileWriter` itself (W1–W9), `profile.json`, the run archive `user://runs/<run_id>.json`.
- Run Structure epic: computing `run_id`, `match_attempts[floor]`, calling the archive at `match_ended`.
- Deferred (Vertical Slice): the replay viewer that reads archived logs; `keep_match_logs` release default (Open Question 5).

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/core/log/event_log_archive.gd`
- `tests/integration/rng_event_log/log_archive_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: standard` Integration tests are BLOCKING.*

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/rng_event_log/log_archive_test.gd` — must exist and pass (file I/O is permitted in an integration suite; clean up the temp `user://logs/` subfolder in `after_test`)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/rng-event-log/story-006-event-log-serialization-and-diagnostics.md`, `production/epics/rng-event-log/story-007-overflow-fault-and-config-knobs.md`, and the `AtomicFileWriter` story of `production/epics/meta-progression/EPIC.md` (not yet created — cross-epic; pull it forward or schedule this story after it)
- Unlocks: None inside this epic (Run Structure calls it; `/balance-check` reads the output)
