# Story 009: `Treasures.pool(unlocked_keys, exclude_ids)` — the one membership predicate

> **Epic**: Treasures
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-11-04
> **Last Updated**: 2026-11-04
> **Readiness**: READY (2026-11-04, by hand: ADR-0005 Accepted, manifest 2026-11-04 current, TR-IDs active, story 001 Complete, 0 lint rows; QL-STORY-READY skipped, Lean mode)
> **First Playable path**: no — the First Playable is one match with no draft. `RewardDraft.init_run` is its consumer

## Context

**GDD**: `design/gdd/treasures.md` (T5.1, T6, Edge Cases "State and persistence", AC-11, AC-12) · `design/design-decisions.md` DD-X12
**Requirement**: `TR-treasures-003` (the `pool` half); `TR-systems-index-003` (carried: Treasures owns the definitions, Reward Draft reads the pool)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Owner-scoped hook registry (Decision rule 10)
**ADR Decision Summary**: `Treasures.pool(unlocked_keys, exclude_ids)` implements membership (`unlock == null` or `unlock.key ∈ unlocked_keys`; not in `exclude_ids`) over `CardDatabase.treasure_pool()` and returns it id-ascending. It is pure. `RewardDraft.init_run` calls it and never re-derives the predicate.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (language, by version); LOW for the APIs
**Engine Notes**: ADR-0005 Engine Compatibility — no post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: `Treasures.pool(unlocked_keys, exclude_ids)` is the single membership predicate over `CardDatabase.treasure_pool()`, id-ascending; `RewardDraft.init_run` calls it
- Forbidden: never re-implement the predicate outside `Treasures.pool()`; never mutate `RunState`; never draw RNG here (the seeded draw is Reward Draft's)
- Guardrail: none specific (≤ 20 records)

---

## Acceptance Criteria

*From GDD `design/gdd/treasures.md` (T6, AC-11, AC-12, Edge Cases), scoped to this story:*

- [x] **AC-12** GIVEN the 20-record fixture, WHEN `pool(∅, ∅)`, THEN 16 ids in ascending order; `pool({hero_decay_first_win, hero_decay_floor_5, hero_knowledge_first_win, first_victory}, ∅)` → 20; `pool(∅, [treasure_worn_signet])` → 15, without it.
- [x] **AC-11** GIVEN a run holding `treasure_grave_tithe` and an `unlocked_keys` set that no longer contains `hero_decay_first_win`, WHEN the run's installers are built (`installers_for`, which `begin_match` calls — T3.1), THEN Grave Tithe is installed; WHEN `pool(unlocked_keys, [])` is queried, THEN it is absent.
- [x] **AC-MVP (Meta absent)** GIVEN the MVP's `MetaStub` (`unlocked_keys()` = ∅) and the 10 MVP records (all `unlock: null`, DD-H06), WHEN `pool(∅, ∅)`, THEN all 10 ids are returned id-ascending — ≥ `min_treasure_pool` 9 — and two calls with the same arguments return equal lists.

---

## Implementation Notes

*Derived from ADR-0005 Decision rule 10 and treasures T6:*

- **DD-X12 changed one key.** Living Armory's unlock is `first_victory` (`runs_won ≥ 1`, any hero). It was `bosses_defeated_16`, which stays defined and reserved. The four keys in AC-12 are T8's current column (meta M10 and `design/registry/entities.yaml` agree). Treasures Open Questions row R-14 still names `bosses_defeated_16` in its resolution text. That row is stale wording, not a rule, and this story follows T8.
- **Argument type.** ADR-0005 Key Interfaces types `unlocked_keys` as `Dictionary` (a set), but `MetaApi.unlocked_keys()` returns `Array`. Implement the ADR's signature and treat it as set membership. The caller (Reward Draft) converts once at `init_run`. Record in Completion Notes if the ADR's type is changed instead; that is an ADR erratum, not a silent change.
- `exclude_ids` is held ∪ previously offered, which Reward Draft derives from `drafts[]` (reward-draft D7). `pool` only takes the set. It never reads `RunState` or `draft_state`.
- AC-11's installation half is asserted at `installers_for`: it never consults unlock state (T6, Edge Cases "unlock revoked mid-run"). The `begin_match` call itself is in the Run Structure epic.
- Order: `CardDatabase.treasure_pool()` is already id-ascending (CR-6). Filter it and keep the order; never re-sort with a comparator.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Reward Draft epic: the pool snapshot at `init_run`, weights (`RARITY_W` 70/30, affinity), the universal slot, pity
- Meta Progression epic: `unlocked_keys()` and the unlock-key validator (M2.4)

---

## Files

- `src/gameplay/treasures/treasures.gd` — `pool`
- `tests/unit/treasures/treasures_pool_test.gd` — created, 14 tests

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/treasures/treasures_pool_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] Created, 14 tests passing

---

## Dependencies

- Depends on: `production/epics/treasures/story-001-installers-passive-and-collect-state.md` (class, fixture, `installers_for`)
- Unlocks: the Reward Draft epic's `init_run` pool snapshot (no stories yet — `/create-stories reward-draft`)

---

## Completion Notes

**Completed**: 2026-11-04
**Start / end (UTC)**: 2026-11-04T19:50:07Z to 2026-11-04T19:56:23Z
**Criteria**: 3/3 passing on the fixture. AC-MVP on shipped data: NOT ASSESSED — shipped `treasures.json` has 0 records until content 006 (sprint 6), so AC-MVP ran on the 10 MVP records of `treasures_v1.json`.
**Test Evidence**: `tests/unit/treasures/treasures_pool_test.gd`, 14 tests
**Run result**: N/A — `pool` has no scene or screen; nothing calls it until `RewardDraft.init_run` exists
**Reviewed by**: independent `/code-review`, 2026-11-04 (`production/reviews/2026-11-04/code-review-s5-w1-heroes-treasures.md`, summary scope: correctness and contract risk only): **APPROVED WITH SUGGESTIONS**. The shipped-data half of AC-MVP is NOT ASSESSED (no shipped treasures yet). Open: the first caller must turn `unlocked_keys()` into a Dictionary set

**Seen failing.** All 14. First against no `pool` method (13 errored and 1 failed), then against a stub returning `[]`: 10 failed on their assertions. The other 4 failed against deliberate mutants, and the predicate's own logic was mutated too (ids instead of records, unlocks ignored, any key unlocking all, exclusions ignored, a re-sort, a written argument, the frozen pool handed out, `installers_for` checking unlocks, a non-MVP id in `MVP_IDS`). The stub also showed `test_pool_returns_the_treasure_def_records` passing on an empty list, so it now asserts the count.

**Deviations (ADVISORY).**
- `pool` returns TreasureDef records, not ids. The ACs say "ids", but T6 and ADR-0005 say `TreasureDef[]`, and the GDD outranks the story. The tests read the ids from the records. Reward Draft's `draft_state.treasure_pool` stores ids (D3), so `init_run` maps them.
- `unlocked_keys` is a `Dictionary` set, as ADR-0005 types it. `MetaApi.unlocked_keys()` is an Array, so the caller converts once; the ADR's type is unchanged.

**AC-MVP needs the subset.** `MetaStub.unlocked_keys()` is derived from the `unlock` fields in the data, so it is empty over the 10 MVP records and holds all four keys over the 20. The test asserts the empty result rather than assuming it. T8's MVP column is not a record field (CR-3), so the 10 ids live in `TreasureFixtures.MVP_IDS`.

**No RNG (Forbidden).** The QA plan asks to watch the stream counters, but `Treasures` is given no stream, so a counter could not move. The guard is `test_nothing_under_treasures_names_run_state_a_log_or_rng` from story 001, which scans every script in the folder, so it covers `pool`.
