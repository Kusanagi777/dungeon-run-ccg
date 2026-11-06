# Story 003: Id uniqueness and cross-references (CR-5 stages 5–6)

> **Epic**: Card Database
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-03

## Context

**GDD**: `design/gdd/card-database.md`
**Requirement**: `TR-card-database-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Data format, effect schema/DSL and `config()` loading
**ADR Decision Summary**: Stages 5–6 run in `DataLoader` over plain Dictionaries with the closed code set (`E_DUP_ID`, `E_UNKNOWN_REF`, `E_COUNT`, `E_TOKEN_IN_LIST`, `E_TAG_MISMATCH`); every stage collects every problem and continues, so one report lists everything and there is no "load what passed" path. The id-sorted staging built here is what stage 7 (Story 004) answers lookups from.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (ADR-0002 knowledge risk generally; APIs used — `Dictionary`, `Array.sort_custom` — are pre-4.4, LOW)
**Engine Notes**: No post-cutoff API. Sort records by id with a deterministic comparator (`String <`), never by file order.

**Control Manifest Rules (this layer)**:
- Required: Validate in the nine CR-5 stages with the closed code set. Queries are pure reads on the frozen snapshot, every record list sorted by id (prepare the staging here).
- Forbidden: Never author a content-version string; never depend on file order or authoring order. Never `assert()` on data in release paths.
- Guardrail: Data load ≤ `data_load_budget_ms` 200; `n_refs = n_heroes × 15 + n_bundles × 3 + Σ boss_deck_size + n_heroes + n_bosses` O(1) checks each via an id map, never a linear scan per reference.

---

## Acceptance Criteria

*From GDD `design/gdd/card-database.md` (CR-5 stages 5–6, Edge Cases "Identity and references" and "Pools and lists", Acceptance Criteria), scoped to this story:*

- [ ] **GIVEN** a fixture set with one card id duplicated into a second set file, **WHEN** loading, **THEN** the report contains one `E_DUP_ID` naming the id and both file paths (and record index), state is `Failed`, and neither copy is queryable after the load (no "last one wins").
- [ ] **GIVEN** a hero whose `starter_deck` has 14 ids, **WHEN** loading, **THEN** `E_COUNT` reports found 14, expected 15; **GIVEN** a bundle with 2 cards, **THEN** `E_COUNT` found 2, expected 3; **GIVEN** a starter deck with the same id twice (15 entries), **THEN** no error (duplicates inside a starter deck are allowed); **GIVEN** a starter deck, bundle `cards`, boss `deck` or `hero_power` referencing an id that does not exist, **THEN** `E_UNKNOWN_REF` names the referring record, the field, the index in the list and the missing id.
- [ ] **GIVEN** a bundle whose third card lacks the bundle's `theme` tag, **WHEN** loading, **THEN** `E_TAG_MISMATCH` names the bundle, the card and the tag; **GIVEN** a bundle whose card is from a different set than the bundle, or a hero whose starter card is from neither the hero's set nor `neutral`, **THEN** `E_SET_MISMATCH` names the referring record and the card.
- [ ] **GIVEN** a boss deck containing a card with `token: true`, **WHEN** loading, **THEN** `E_TOKEN_IN_LIST` names the boss, the index and the card id (the same for a token in a starter deck or bundle); **GIVEN** a boss deck containing a War-set weapon, **THEN** no error or warning is raised for that reference; **GIVEN** a hero whose `set` has no `cards_<set>.json` in the root, **THEN** `E_MISSING_FILE` names the hero and the file.

---

## Implementation Notes

*Derived from ADR-0002 Decision 3–4 and card-database CR-5 / Edge Cases:*

- Stage 5: build one global `index_of: Dictionary[String, int]`-style map across **all** record types while walking files in manifest order; a second definition of an id adds `E_DUP_ID` with every defining `{file, index}`; exclude every copy from later stages. A `boss`-set card id and a BossDef id share the namespace (`boss_<name>`) — a collision is `E_DUP_ID`, by design (CR-2).
- Stage 6, per CR-5: hero `starter_deck` (exactly 15 — `TestConstants.STARTER_DECK_SIZE` mirrors DD-R03 — no tokens, each card `set ∈ {hero.set, neutral}`), hero `hero_power` (a HeroPowerDef id), boss `deck` (≥ 1, no tokens, any set incl. hero sets and `boss`), boss `hero_power` (HeroPowerDef id or `null` per Story 002's rule), bundle `cards` (exactly 3 — `TestConstants.BUNDLE_CARD_COUNT` — no tokens, each `set == bundle.set`, each carries `bundle.theme` in `tags`). The hero `set` → `cards_<set>.json` presence check is `E_MISSING_FILE` naming the hero.
- Error entries name the referring record (`record_id`), the field (`field`) and, in the message, the list index and the offending id, so Content can find the row.
- After stage 6, stage the per-type record lists **sorted by id ascending** and the `index_of` map over them — Story 004's stage-7 lookups and Story 006's freeze both read this staging; build it once here.
- One report lists everything: verify with a fixture holding three distinct errors across stages 2, 4 and 6 (that cross-stage check is Story 008's AC; this story's tests assert per-stage collection).
- Fixtures derive from `tests/fixtures/data/minimal/` with `CardFactory.make_hero_def` / `make_bundle_def` / `make_boss_def` overrides.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: field shape / enum / range checks (stage 4).
- Story 004: delegated validators and the staged-lookup exception during stage 7.
- Story 005: pool-size thresholds (`W_POOL_SIZE`, bundle-pool hard floor `E_COUNT` 3), `W_EMPTY_SET`, `W_DUP_NAME`.
- Story 006: `make_read_only()` freeze and the public CR-6 queries.

---

## Files

- `src/core/data/data_loader.gd` (stage 5 `_check_unique`, stage 6 `_check_references`, `_build_staging`; `LoadResult.staging`; stage 4 now also collects every record's string id)
- `src/core/data/record_schemas.gd` (`count` 15 / 3 on the CR-3 `starter_deck` / `cards` specs)
- `src/core/data/validation_report.gd` (the five stage 5–6 codes)
- `tests/fixtures/data/dup_id/`, `refs_counts/`, `refs_unknown/`, `refs_sets_tags/`, `refs_tokens/`, `refs_missing_set_file/`
- `tests/unit/card_database/card_database_references_test.gd` (21 tests)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: `standard` — Logic tests are BLOCKING.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/card_database/card_database_references_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] Created — 21 tests, passing

---

## Dependencies

- Depends on: `production/epics/card-database/story-001-manifest-parse-envelope.md`, `production/epics/card-database/story-002-record-schema-validation.md`
- Unlocks: `production/epics/card-database/story-004-delegated-validators.md`, `production/epics/card-database/story-005-budget-warnings-and-pool-thresholds.md`

## Completion Notes

**Completed**: 2026-11-03 (started 2026-11-03T21:13:14Z, finished 2026-11-03T21:17:19Z UTC)
**Criteria**: 4/4 passing (all covered by unit tests in `card_database_references_test.gd`; none deferred)
**Run result**: N/A — stages 5–6 are headless loader validation with no scene, screen or log a player sees; the report reaches the player only through the `data_error` screen (Run UI epic)
**Deviations** (advisory):
- Stage 5 sees the id of **every** record with a string id, including one that failed stage 4 — otherwise the GDD's own AC ("one card id duplicated into a second set file → `E_DUP_ID`") could never fire, because a `war_` card in `cards_neutral.json` always fails its prefix at stage 4. Such a record gets both its stage-4 entry and the `E_DUP_ID`; stage 6 still reads only records that passed 4 and 5.
- `E_DUP_ID` is one entry per id whose `file` is the first defining file in manifest order; every `file records[i]` is in the message (the report entry has one `file` slot).
- A reference to a record that failed stage 4, 5 or 6 is `E_UNKNOWN_REF` ("unknown id, or its record failed validation"); a `hero_power` naming a non-HeroPowerDef record, or a list entry naming a non-card record, is `E_UNKNOWN_REF` with both types named.
- The hero set-file check (`E_MISSING_FILE`, `file` = the missing `cards_<set>.json`, `record_id` = the hero, `field` = `set`) asks `FileAccess.file_exists` on the root, so a set file that is present but failed to parse is not reported twice.
- The 15 / 3 list lengths are held as `count` on the CR-3 field specs in `RecordSchemas` (format knowledge, DD-R03 / DD-R04), not as numeric constants; `TestConstants.STARTER_DECK_SIZE` / `BUNDLE_CARD_COUNT` are pinned to them by a test.
- The staging (`LoadResult.staging`: `{records: {type: id-sorted Array}, index_of: {id: {type, position}}, files: {id: file}}`) is built whatever the outcome and is provisional until Story 006 freezes it; a record failing stage 6 is not staged.
- Fixture roots derive from `clean/` (story 002), not `minimal/`, via the same scratch generator.
**Test Evidence**: `tests/unit/card_database/card_database_references_test.gd` (21 tests; seen failing before stages 5–6 existed); full suite exit 0, 390 test cases; smoke exit 0, no SCRIPT ERROR; parse check ok
**Reviewed by**: self, no independent review (`/code-review` not run; LP-CODE-REVIEW and QL-TEST-COVERAGE skipped — Lean mode)
