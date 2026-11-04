# Performance record: Card Database load and memory budget (2026-11-04)

**Story**: `production/epics/card-database/story-009-load-and-memory-budget.md` (AC-1, AC-2, AC-3 log line; amended 2026-11-04 per `production/qa/qa-plan-sprint-004-2026-11-04.md` § CDB-009)
**Suite**: `tests/performance/card_database/card_database_load_budget_perf_test.gd` (non-blocking: outside `commands.test` by `-i res://tests/performance`; run by the `performance` job of `.github/workflows/tests.yml`)
**Command**: `godot --headless -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/performance --ignoreHeadlessMode -c`
**Data**: the shipped `assets/data/` at trunk `c9cd55b` (after "merge: sprint 4 L5": MVP-0 batch + content 002 War set + content 003 band-1 bosses), branch `lane/s4-l4-w2`
**Validators**: the map a fresh `boot.gd` instance builds for a debug build (`_collect_validators(null, true)`): real `effects`, `unlock` (MVP), `ai_profile`, `configs.card_effects`, `match_rules`, `ai_profiles`, `rng_event_log`, `content_budgets`; pending `treasure` and 7 config owners (warnings in debug)

## Measurements

| Measure | Runner | Build | Value | Budget | Result |
|---|---|---|---|---|---|
| `load()` wall clock, 5 loads after 1 warm-up (min / **median** / max) | local agent container (Linux x86_64, shared) | headless editor, debug | 16.9 / **17.8** / 18.0 ms | `data_load_budget_ms` 200 (GDD expects < 50) | within budget (≈ 9 % of it) |
| `Performance.MEMORY_STATIC` delta across one `load()` | same | same | 493,772 bytes (0.47 MB) — measurable headlessly, so this is the compared figure | `data_memory_budget_mb` 4 (4,194,304 bytes) | within budget (≈ 12 %) |
| Canonical-JSON proxy, `DataLoader.canonical_json(snapshot)` UTF-8 bytes | same | same | 84,559 bytes | 4 MB | within budget (logged; the pools repeat records, so it overstates the JSON, yet stays far below the static delta, which also counts Dictionary/Variant overhead) |
| `validation_checks = n_records + n_refs` (shipped) | same | same | 170 = 55 + 115 | — (logged, not asserted) | GDD v1 estimate 893: the shipped set is MVP-0 + part of MVP-1, about a quarter of v1 |

The local run printed:

```
PERF card_database load (shipped, Boot debug map) x5: min 16921 us, median 17841 us, max 17997 us (budget 200 ms)
PERF card_database snapshot (shipped): MEMORY_STATIC delta 493772 bytes, canonical-JSON proxy 84559 bytes; compared: delta (budget 4 MB = 4194304 bytes)
PERF card_database validation_checks (shipped): 170 = n_records 55 + n_refs 115 (GDD v1 estimate 893; logged, not asserted)
```

## Not yet recorded

- **CI (`performance` job)**: not run — the lane does not push. Read the `PERF` lines in the job summary after the merge and add a row here.
- **Reference machine (owner's, release build, SSD)**: not run. AC-1's "target hardware" figure is the owner's; until then this record holds a debug-build figure from a shared container, which is the floor, not the reference.
- Watched failing: with the budget multipliers broken (ms read as µs, MB as KB) both threshold tests fail (exit 100), so the thresholds can fail; restored before this record.
