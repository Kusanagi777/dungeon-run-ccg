# Story 009: Load and memory budget test (Formulas "Validation cost and load budget")

> **Epic**: Card Database
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-04
> **Readiness**: 2026-11-04 `/story-readiness` (by hand, lane 4 W2): **NEEDS WORK → READY**. Gaps found: *Testable* — AC-3's last clause names a tolerance and then asserts nothing (no run can fail it); AC-1 / AC-2 are wall-clock and memory thresholds that would fail the blocking suite, which the coding standards' Determinism rule forbids, and load the shipped `assets/data/` from a unit test (file I/O outside the fixture-root exception). Both resolved from the docs by the quick-design amendment below (the sprint-4 QA plan's CDB-009 rewrite). Every other item passes: ADR-0002 Accepted (version 2026-11-03 = story stamp); TR-card-database-005 active; Manifest Version 2026-11-03 = manifest; dependencies story-006 Complete and content story-001 (the MVP-0 batch) Complete; 4 ACs ≥ 2 (balanced); Test Evidence names the blocking path. QL-STORY-READY skipped — Lean mode.

## Context

**GDD**: `design/gdd/card-database.md`
**Requirement**: `TR-card-database-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Data format, effect schema/DSL and `config()` loading (Performance Implications; Validation Criteria `card_database_load_budget_test.gd`)
**ADR Decision Summary**: One synchronous parse plus ~900 O(1) checks at v1; budget `data_load_budget_ms` 200, expected < 50 ms; frozen snapshot ≤ `data_memory_budget_mb` 4; the data load runs at boot ahead of the profile load and is the one place a boot stall can originate. `Unloaded → Ready` ≤ 200 ms on the reference machine is `NOT SOURCEABLE` and proven by this test.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (ADR-0002 knowledge risk generally; `Time.get_ticks_usec()`, `OS.get_static_memory_usage()` / `Performance.get_monitor(Performance.MEMORY_STATIC)` are pre-4.4, LOW)
**Engine Notes**: ADR-0002 Verification Required item 5 — the budget on the reference machine. Static-memory deltas on Godot are coarse (allocator pools); measure the delta across `load()` after a `GC`-free warm-up and treat a result within the budget as the pass condition, logging both numbers as the GDD requires. CI (llvmpipe, shared runner) is slower than the target hardware; the threshold is the knob's value, the expected figure is < 50 ms.

**Control Manifest Rules (this layer)**:
- Required: Tests under `tests/unit/**` construct rules objects directly, never through `Boot`.
- Forbidden: Never hardcode `data_load_budget_ms` or `data_memory_budget_mb` in the test — read them from `config("card_database")` after the load (or `TestConstants.DATA_LOAD_BUDGET_MS` / `DATA_MEMORY_BUDGET_MB`, which must mirror the shipped `card_database.json`).
- Guardrail: Data load (`Boot.boot()` → `CardDatabase` `Unloaded → Ready`) ≤ `data_load_budget_ms` 200 (expected < 50 ms), synchronous at boot; frozen snapshot ≤ `data_memory_budget_mb` 4.

---

## Acceptance Criteria

*From GDD `design/gdd/card-database.md` (Formulas "Validation cost and load budget", States `Loading`, Acceptance Criteria "Performance and standards"), scoped to this story:*

**(amended 2026-11-04 per QA plan)** — quick-design amendment (Tweak; test placement only, no rule or value changes), from `production/qa/qa-plan-sprint-004-2026-11-04.md` § CDB-009 and § "Acceptance criteria found untestable as written". The criteria in force are AC-1 … AC-4 directly below; the original three follow, struck through in meaning, for the record.

*Design delta.* The GDD rule is unchanged (`Unloaded → Ready` ≤ `data_load_budget_ms`, snapshot ≤ `data_memory_budget_mb`, `load()` synchronous, `validation_checks = n_records + n_refs`). What changes is **where each half is checked**: wall-clock time and memory are not deterministic on a shared runner, so their thresholds move to the non-blocking performance suite (`tests/performance/card_database/`, run by the `performance` job of `.github/workflows/tests.yml`, `continue-on-error`, outside `commands.test` by its `-i res://tests/performance`); the blocking suite keeps only what is deterministic — the synchronous return, the debug counters and the budget knobs' presence. Measurements are recorded in `production/qa/perf-card-database-2026-11-04.md`. The formula's `n_bosses` term is read as *bosses whose `hero_power` is not `null`* — the CR-5 step 6 reference that exists (`BossDef.hero_power` is nullable, CR-3); with every boss holding one, as the v1 estimate assumes, the two are the same.

- [ ] **AC-1 (performance, non-blocking job)**: **GIVEN** the shipped data under `assets/data/`, **WHEN** `load()` runs on a `CardDatabase` with `Boot`'s validator map (built from a fresh `boot.gd` instance, never the autoload) after one warm-up load of the same root, **THEN** the median of 5 measured loads (each a fresh database; `Time.get_ticks_usec()` around `load()`) is ≤ `data_load_budget_ms` read from `config("card_database")`, the suite fails above it, and a `PERF` line logs the measured ms and the budget. Lives in `tests/performance/card_database/card_database_load_budget_perf_test.gd`.
- [ ] **AC-2 (performance, non-blocking job)**: **GIVEN** the same load, **THEN** the frozen snapshot's size — the `Performance.MEMORY_STATIC` delta across `load()` when it is measurable headlessly, else the documented proxy, the byte length of `DataLoader.canonical_json(snapshot)` — is ≤ `data_memory_budget_mb` (from `config("card_database")`), the suite fails above it, and a `PERF` line logs **both** numbers and which one was compared. Same file.
- [ ] **AC-3 (blocking)**: **GIVEN** `load()` is called from the test's main thread on a fixture root, **THEN** it returns with `state()` already `Ready` (clean fixture) or `Failed` (parse-error fixture) — no `await`, no thread, no signal — **and** the loader's debug counters satisfy `validation_checks == n_records + n_refs`, where on the `clean/` fixture `n_records` is every record across every definition file and `n_refs` equals `n_heroes × STARTER_DECK_SIZE + n_bundles × BUNDLE_CARD_COUNT + Σ boss_deck_size + n_heroes + n_bosses_with_hero_power` computed from the loaded set (asserted, exact), with the fixture's known answer pinned as well; the counters are per run (a second run of the same loader reports the same numbers, not their sum). The shipped-data figure is **logged** beside the GDD v1 estimate (893) by the perf suite, not asserted. Lives in `tests/unit/card_database/card_database_load_budget_test.gd`.
- [ ] **AC-4 (blocking)**: `data_load_budget_ms` and `data_memory_budget_mb` are present in `config("card_database")` as whole numbers — on a fixture root in the unit suite, and on the shipped `assets/data/card_database.json` in `tests/integration/card_database/card_database_shipped_budget_test.gd`, where they equal `TestConstants.DATA_LOAD_BUDGET_MS` / `DATA_MEMORY_BUDGET_MB` (the mirror) — and the shipped load's counters satisfy the AC-3 formula over the shipped loaded set. No test hardcodes either budget value.

*Original criteria (superseded by AC-1 … AC-4 above, kept for the record):*

- *(orig. 1, now AC-1 + AC-2 in the perf suite)* Performance: **GIVEN** the shipped MVP data set under `assets/data/` (release build, SSD, target hardware — CI is the floor, the owner's machine the reference), **WHEN** `load()` runs with the full validator map, **THEN** `Unloaded → Ready` completes in ≤ `data_load_budget_ms` (200 ms) measured with `Time.get_ticks_usec()` around `load()`, and the test fails above the threshold and logs the measured milliseconds.
- *(orig. 2, now AC-2)* **GIVEN** the same load, **THEN** the frozen snapshot's resident size (static-memory delta across `load()`, or a canonical-JSON byte count of the snapshot as the documented proxy if the delta is not measurable headlessly) is ≤ `data_memory_budget_mb` (4 MB), the test fails above it and logs the measured number.
- *(orig. 3, now AC-3; its "within the test's tolerance (logged, not asserted)" clause could not fail)* **GIVEN** `load()` is called from the test's main thread, **THEN** it returns only after `state()` is `Ready` or `Failed` (synchronous — no `await`, no thread, no signal), and the measured `validation_checks = n_records + n_refs` count the loader reports in debug matches the Formulas estimate for the data set within the test's tolerance (logged, not asserted as an exact number).

---

## Implementation Notes

*Derived from ADR-0002 Performance Implications and Validation Criteria:*

- `tests/unit/card_database/card_database_load_budget_test.gd`: construct `DataLoader.new("res://assets/data/")` and `CardDatabase.new(loader)` directly; inject `ValidatorStubs.accept_all()` **plus** the real validators that exist at the time (start with stubs; `/dev-story` notes which real validators were in the map — the budget must hold with the real ones too, so re-run when Card Effects lands its validator). Warm up once with a throwaway load against the same root (file cache), then time the measured load.
- Read the thresholds from `db.config("card_database")` after the load; add `TestConstants.DATA_LOAD_BUDGET_MS` / `DATA_MEMORY_BUDGET_MB` mirroring the shipped file (each constant names its source, per the helper's convention).
- Memory: `Performance.get_monitor(Performance.MEMORY_STATIC)` before and after; if the delta is unusable headlessly, document the proxy (`DataLoader.canonical_json(snapshot).length()`) in the test's doc comment and the story close-out. Either way, log both numbers with `print_rich`/gdUnit4 reporting so the figure is in the CI artifact.
- Synchronous: no `await` in `load()`; assert `state()` immediately after the call.
- Debug counters: have `DataLoader` count records and references checked (`n_records`, `n_refs`) into the `LoadResult` for the test to log; cheap integers, no behaviour change.
- This test runs against the **shipped** data, so it is skipped (gdUnit4 `@warning_ignore`/skip with reason) until `assets/data/` holds the content MVP-0 batch — keep the skip reason explicit so `/smoke-check` sees why.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Content epic: authoring `assets/data/*.json` (MVP-0 / MVP-1 batches).
- Story 010: `Boot`-driven load on the shipped set and the exported-build smoke check.
- Boot epic: where in the boot sequence the load runs (ahead of the profile load).

---

## Files

- `src/core/data/data_loader.gd` (`LoadResult.n_records` / `n_refs` debug counters and `validation_checks()`; `_count_records`; `_ref` counts each checked reference; counters reset per `run()`)
- `tests/helpers/test_constants.gd` (additive: `DATA_MEMORY_BUDGET_MB`, `VALIDATION_CHECKS_V1_ESTIMATE`; `DATA_LOAD_BUDGET_MS` already existed)
- `tests/unit/card_database/card_database_load_budget_test.gd` (new, blocking, 7 tests) + `.uid`
- `tests/integration/card_database/card_database_shipped_budget_test.gd` (new, blocking, 2 tests) + `.uid`
- `tests/performance/card_database/card_database_load_budget_perf_test.gd` (new, non-blocking job, 3 tests) + `.uid`
- `production/qa/perf-card-database-2026-11-04.md` (new: the measurements)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: `standard` — Logic tests are BLOCKING. Performance tests must specify acceptable thresholds and fail if exceeded (`.claude/rules/test-standards.md`).*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/card_database/card_database_load_budget_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later); the logged numbers from the owner's reference machine go in the close-out note.

**Status**: [x] Created and passing (2026-11-04): unit 7 + integration 2 in the blocking suite (full `commands.test` 1234/1234, exit 0); perf 3 in the non-blocking suite (local exit 0; numbers in `production/qa/perf-card-database-2026-11-04.md`)

---

## Dependencies

- Depends on: `production/epics/card-database/story-006-freeze-and-queries.md`; content epic MVP-0 batch story (the shipped `assets/data/` set — path assigned by `/create-stories content`)
- Unlocks: `production/epics/card-database/story-010-shipped-data-and-export-inclusion.md`

---

## Completion Notes
**Completed**: 2026-11-04 (started 03:45:38 UTC, ended 03:53:55 UTC; lane 4 W2, branch `lane/s4-l4-w2`)
**Criteria**: 4/4 passing (amended set). AC-1 and AC-2 pass on a local debug run only — CI `performance` job and the owner's reference machine are not yet recorded (see the perf record).

| Criterion | Covered by | Status |
|---|---|---|
| AC-1 load ≤ `data_load_budget_ms` (perf) | `tests/performance/card_database/card_database_load_budget_perf_test.gd::test_shipped_load_median_is_within_data_load_budget_ms` — local median 17.8 ms vs 200 | COVERED (non-blocking) |
| AC-2 snapshot ≤ `data_memory_budget_mb` (perf) | `…_perf_test.gd::test_shipped_snapshot_is_within_data_memory_budget_mb` — `MEMORY_STATIC` delta measurable headlessly: 0.47 MB vs 4; proxy 84,559 bytes logged | COVERED (non-blocking) |
| AC-3 synchronous return + counters | `tests/unit/card_database/card_database_load_budget_test.gd` (2 state tests, formula over loaded set, known answer 31 + 30, zero on `minimal/`, per-run); shipped 170 = 55 + 115 logged beside 893 by `…_perf_test.gd::test_shipped_validation_checks_logged_beside_the_v1_estimate` | COVERED |
| AC-4 budget knobs present, mirror equal, shipped formula | unit `test_budget_knobs_are_whole_numbers_in_config_card_database`; `tests/integration/card_database/card_database_shipped_budget_test.gd` (2 tests) | COVERED |

Every new test was seen failing first: the counter tests against zero-valued stub counters; the per-run test with the `_n_refs` reset removed; the knob tests with `DATA_MEMORY_BUDGET_MB` mutated to 5; the state tests with `load()` leaving `LOADING`; the perf thresholds with ms read as µs and MB as KB. Each mutation was restored before the next run.
**Real validators in the timed map**: `Boot._collect_validators(null, true)` — `effects` (EffectValidator via the stage-7b adapter), `unlock` (MVP), `ai_profile` (BossAI), configs `card_effects`, `match_rules`, `ai_profiles`, `rng_event_log`, `content_budgets`; pending: `treasure` and 7 config owners. Re-run the perf suite as those land.
**Deviations**:
- ADVISORY — the ACs were amended (quick-design, in-story, 2026-11-04 per QA plan); no `design/quick-specs/` file, following the MR-016 precedent.
- ADVISORY — the counters are counted in every build, not only debug (two integer increments; no branch reads them), so a release-build tool sees the same figure.
- ADVISORY — formula reading: the GDD's `+ n_bosses` term is the bosses whose `hero_power` is not null (the reference stage 6 checks). `clean/` has one null-power boss, so the counter is 30 where the literal formula gives 31. Suggest a one-word GDD clarification ("n_bosses with a hero power") at the next card-database revision.
- Scope — `tests/integration/card_database/` and `tests/performance/card_database/` are new folders, beyond the original Files list (now listed); the shipped-file mirror check needs `assets/data/`, which a unit test may not read.
- The Implementation Note "skip until MVP-0 data exists" is moot: content 001 is Complete, nothing is skipped.
**Test Evidence**: `tests/unit/card_database/card_database_load_budget_test.gd` (+ the integration and perf files above); `production/qa/perf-card-database-2026-11-04.md`
**Run result**: N/A — the story adds counters and tests; nothing on screen changes (no scene, UI or presentation file touched).
**Reviewed by**: self, no independent review (lean; `/code-review` not run on this story)
