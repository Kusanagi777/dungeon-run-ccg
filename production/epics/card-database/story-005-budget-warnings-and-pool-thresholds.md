# Story 005: Budget warnings and pool thresholds (CR-5 stage 8, Formulas)

> **Epic**: Card Database
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-03

## Context

**GDD**: `design/gdd/card-database.md`
**Requirement**: `TR-card-database-002` (stage 8), `TR-card-database-005` (Formulas: pool sizes and knobs)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Data format, effect schema/DSL and `config()` loading
**ADR Decision Summary**: Stage 8 raises budget warnings that never block; every threshold the loader applies (`min_collectible_pool`, `min_bundle_pool`, `max_records`) comes from the parsed `card_database.json` body, never from a literal — a missing knob is a data error, not a fallback.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (ADR-0002 knowledge risk generally; APIs used are pre-4.4, LOW)
**Engine Notes**: No post-cutoff API. Coerce knob values with `int()` (JSON numbers parse as `float`).

**Control Manifest Rules (this layer)**:
- Required: Validate in the nine CR-5 stages with the closed code set (`W_POOL_SIZE`, `W_BAND_HEALTH`, `W_EMPTY_SET`, `W_DUP_NAME`, `W_UNKNOWN_FILE`).
- Forbidden: Never a numeric gameplay default in loader code — `SCHEMA_VERSION_CURRENT` and `FILE_MANIFEST` are the only data-shaped literals in `src/core/data/`.
- Guardrail: Data load ≤ `data_load_budget_ms` 200 — pool counts are one pass over the staged lists.

---

## Acceptance Criteria

*From GDD `design/gdd/card-database.md` (CR-5 stage 8, Formulas "Collectible pool size", "Bundle pool size", "Minimum treasure pool", Edge Cases, Acceptance Criteria "Pools and determinism", "Performance and standards"), scoped to this story:*

- [ ] **GIVEN** a fixture with 8 treasures all `unlock: null`, **WHEN** loading, **THEN** `W_POOL_SIZE` reports 8 < 9 (`treasure_drafts_per_run` 3 × `treasure_offers_per_draft` 3) and state is `Ready`; **GIVEN** a fixture whose `collectible_pool_size(hero_set) = n_nontoken(hero_set) + n_nontoken(neutral)` is below `min_collectible_pool`, **THEN** `W_POOL_SIZE` names the hero set, found and threshold, and state is `Ready`.
- [ ] **GIVEN** a fixture with 2 bundles for a hero set and 0 neutral bundles, **WHEN** loading, **THEN** `E_COUNT` reports a bundle pool of 2 below the hard floor 3 and state is `Failed`; **GIVEN** a bundle pool of 5 with `min_bundle_pool: 10`, **THEN** `W_POOL_SIZE` (5 < 10) and state is `Ready`.
- [ ] **GIVEN** `cards_decay.json` with `records: []`, **WHEN** loading, **THEN** `W_EMPTY_SET` is reported, state is `Ready`, and `cards_by_set("decay")` returns an empty list; **GIVEN** a boss whose `health` differs from its band default (30/40/50, DD-M02), **THEN** `W_BAND_HEALTH` names the boss, found and default and state is `Ready`; **GIVEN** two different cards sharing a `name`, **THEN** `W_DUP_NAME` names both ids and state is `Ready`.
- [ ] No hardcoded values: `min_collectible_pool`, `min_bundle_pool`, `max_records`, `data_load_budget_ms` and `data_memory_budget_mb` are read from the `card_database.json` body, not literals in the loader — **GIVEN** a fixture `card_database.json` with `min_collectible_pool: 99` over a 40-card War+neutral pool, **WHEN** loading, **THEN** `W_POOL_SIZE` fires; **GIVEN** `n_records > max_records`, **THEN** `E_COUNT` names `max_records`, found and limit.

---

## Implementation Notes

*Derived from ADR-0002 Decision 3 and Implementation Guidelines; card-database Formulas:*

- Stage 8 reads the five knobs from the parsed `card_database.json` body (schema-checked in Story 002, so they are present and in range by now). Per hero set present in `heroes.json`: `collectible_pool_size = n_nontoken(set) + n_nontoken(neutral)`, warn below `min_collectible_pool`; `bundle_pool_size = n_bundles(set) + n_bundles(neutral)`, **error** `E_COUNT` below the hard floor 3 (DD-R04: one draft needs three offers) and warn below `min_bundle_pool`. The hard floor 3 is a rule constant, not a tuning knob — cite DD-R04 in a comment; it is the one number stage 8 may hold.
- Treasure pool: `n_unlocked_default` = treasures with `unlock == null`; warn below `min_treasure_pool = treasure_drafts_per_run × treasure_offers_per_draft`. Both factors are DD-R05 constants (3 × 3 = 9); the GDD declares them constants, not knobs — read them from `config("run_structure")`'s body if Run Structure exposes them there, else hold them as a named rule constant with the DD-R05 citation and flag in the story's close-out that Run Structure should own them (`/story-done` note).
- `W_BAND_HEALTH`: band defaults 30/40/50 are DD-M02 values; `TestConstants.BOSS_STARTING_HEALTH_BY_BAND` mirrors them for tests. Source them from `config("match_rules")`'s body when Match Rules exposes a per-band starting health; otherwise the same rule-constant treatment and flag.
- `W_EMPTY_SET`: a set file that parsed with `records: []`; load succeeds unless a hero, bundle or boss references that set (then Story 003's `E_UNKNOWN_REF` / `E_COUNT` already fired).
- `W_DUP_NAME`: two different card ids with the same `name` (names are display text; ids are identity).
- `max_records`: total records across all files; above it `E_COUNT`.
- Warnings are entries with `severity = warning`; `report().warnings()` holds them after a `Ready` load; `has_errors()` ignores them.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: the knob ranges (`E_SCHEMA` when a knob is out of range or missing).
- Story 003: `E_COUNT` for starter-deck (15) and bundle-card (3) sizes.
- Story 009: measuring `data_load_budget_ms` / `data_memory_budget_mb` (the knobs are read here; the budget test lives there).
- Reward Draft epic: the pity-dependent `bundle_pool_min` (9 at MVP, 13 at v1) — Content sets `min_bundle_pool` to at least that value per batch.

---

## Files

- `src/core/data/data_loader.gd` (stage 8: `_check_budgets` and its four helpers)
- `src/core/data/validation_report.gd` (`W_POOL_SIZE`, `W_BAND_HEALTH`, `W_EMPTY_SET`, `W_DUP_NAME`)
- `tests/fixtures/data/pool_treasures/`, `pool_collectible/`, `pool_at_threshold/`, `pool_bundles_floor/`, `pool_bundles_warn/`, `pool_mvp_40/`, `empty_set/`, `band_health/`, `dup_name/`, `knobs_99/`, `max_records/`, `stage8_inputs_missing/`
- `tests/fixtures/data/*/{run_structure,reward_draft,match_rules}.json` in `clean/` and every root derived from it (the stage-8 inputs other owners hold); `schema_knob_edges_low/card_database.json` (`max_records` 5000)
- `tests/unit/card_database/card_database_budget_warnings_test.gd` (15 tests)
- `tests/unit/card_database/card_database_{pipeline,bad_values,parse_error,strict_json,schema}_test.gd` (expectations that assumed a warning-free empty root)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: `standard` — Logic tests are BLOCKING.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/card_database/card_database_budget_warnings_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] Created — 15 tests, passing

---

## Dependencies

- Depends on: `production/epics/card-database/story-002-record-schema-validation.md`, `production/epics/card-database/story-003-uniqueness-and-cross-references.md`
- Unlocks: `production/epics/card-database/story-006-freeze-and-queries.md`

## Completion Notes

**Completed**: 2026-11-03 (started 2026-11-03T21:28:15Z, finished 2026-11-03T21:33:35Z UTC)
**Criteria**: 4/4 passing (all covered by unit tests in `card_database_budget_warnings_test.gd`; none deferred)
**Run result**: N/A — stage 8 is headless loader validation with no scene, screen or log a player sees; its warnings reach the player only through the report (validate command / `data_error` screen)
**Deviations** (advisory):
- **DD-R05 / DD-M02 owners (the sprint plan's open point), read from data, no literal:** `treasure_drafts_per_run = |treasure_floors ∩ [1, floors_per_run − 1]|` from `run_structure.json` (Run Structure owns `floors_per_run` and `treasure_floors` — run-structure Tuning Knobs; the count formula is reward-draft's `K`); `treasure_offers_per_draft` from `reward_draft.json` (reward-draft Tuning Knobs lists it, "constant in v1"); `boss_starting_health_by_band` from `match_rules.json` (registry entry's source is match-rules; match-rules Tuning Knobs "Boss band health"). **Flag for those owners:** none of the three keys is in their shipped bodies or validators yet (`assets/data/match_rules.json` / `RulesEngine.CONFIG_KEYS` lack `boss_starting_health_by_band`; no `run_structure.json` / `reward_draft.json` ship). Until they do, stage 8 does not fall back: it emits one `W_POOL_SIZE` / `W_BAND_HEALTH` whose message says "not checked" and names the absent keys (skill-authoring obligation 3), and the load is not failed by it.
- The bundle-pool hard floor (3, DD-R04) is read as `RecordSchemas.KNOB_RANGES.min_bundle_pool[0]` — the Formulas row defines the knob's range floor as that hard floor — so `src/core/data/` still holds no numeric constant besides `SCHEMA_VERSION_CURRENT`.
- Entry placement: collectible-pool `W_POOL_SIZE` on `cards_<set>.json` (`field` `min_collectible_pool`); bundle-pool `E_COUNT` / `W_POOL_SIZE` on `bundles.json` (`field` `min_bundle_pool`); treasure-pool `W_POOL_SIZE` on `treasures.json`; `max_records` `E_COUNT` on `card_database.json` (counts every record in every definition file, failed ones included — "all records across all files"); `W_DUP_NAME` is one entry per shared name on the first id's file, listing every id. Pools count staged records only (passed stages 4–7).
- Story-001/002 tests adjusted: `minimal/`-derived roots now carry stage-8 warnings (three empty required set files, treasure pool unchecked), so the "empty report" assertions on `minimal/`, `bad_values/`, `parse_error/` and `strict_json/` now assert no errors / no other warnings; `clean/` is the root that loads with an empty report. `schema_knob_edges_low/` uses `max_records` 5000 (it has no stated range; 1 would trip stage 8).
**Test Evidence**: `tests/unit/card_database/card_database_budget_warnings_test.gd` (15 tests; seen failing before stage 8 existed); full suite exit 0, 481 test cases (two intentional guard `Assertion failed` SCRIPT ERRORs); `tools/lint/gates.sh` exit 0; parse check 21/0; smoke exit 0, no SCRIPT ERROR
**Reviewed by**: self, no independent review (`/code-review` not run; LP-CODE-REVIEW and QL-TEST-COVERAGE skipped — Lean mode)
