# Change Impact Report: owner decisions DD-X19 … DD-X24

`/propagate-design-change`, run by hand 2026-11-04 once per changed GDD
(`workflow: standard`; match-rules and card-effects pinned `full`;
`review_mode: lean`; owner standing approval for DD-X19 … DD-X24, so Phase 7
resolutions were taken without questions and are recorded below).
TD-CHANGE-IMPACT skipped — Lean mode (every section).

This pass edits docs and stories only. Code, tests and JSON data that the
decisions change are listed under each section's **Sprint 5** line.

## DD-X19 — rng-event-log.md: event-log append budget 50 → 80 ms

### Change Summary
Changed sections:
- Acceptance Criteria (Performance): 10,000 appends + `events_since(0)` under **80 ms** headless (was 50 ms).

Unchanged: every rule, formula, edge case and the `restore()` 5 ms budget.

Key changes affecting architecture: the budget ADR-0003 quotes (Context, Validation Criteria, Performance Implications).

Downstream GDDs to re-check: none — the budget is not a registry entity (`design/registry/entities.yaml` has no entry with this value).

### ADRs in scope
Checked 7 ADRs (standard: Foundation ADR-0001, 0002, 0003, 0004, 0010, plus ADR-0006 and 0009, which name rng-event-log.md). 4 reference rng-event-log.md (ADR-0003, 0004, 0006, 0009); a search for the changed fact (50 ms append AC) hits ADR-0003 only.

#### ADR-0003: Seeded RNG Service and Event Log
Status: Needs Review → **Updated in place (erratum 2026-11-04, DD-X19)**
- Assumed: "10,000 appends + `events_since(0)` under 50 ms headless".
- Now: under 80 ms headless.
- Assessment: Decision 5 (per-append deep copy and freeze) holds; the owner chose to raise the budget rather than revisit the copy. Context, Validation Criteria and Performance Implications updated.

Still valid: ADR-0004, 0006, 0009 cite rng-event-log.md for other requirements (snapshot persistence, `ai_decision` events, `events_since` projection), not the budget. ADR-0001, 0002, 0010 do not cite the budget; they are out of scope for this fact, not verified unaffected.

### Other documents fixed
- `docs/architecture/control-manifest.md` Core Performance Guardrails `EventLog` row.
- `docs/architecture/requirements-traceability.md` Superseded Requirements row.
- Story `production/epics/rng-event-log/story-010-…` AC-2 and Completion Notes.
- Not edited: sprint plans and QA plans (dated records).

**Sprint 5:** `tests/performance/rng_event_log/rng_event_log_perf_test.gd` — `APPEND_BUDGET_USEC` 50_000 → 80_000, rename `test_ten_thousand_appends_and_events_since_zero_fit_in_50_ms`, header comment; re-run the perf job.

## DD-X20 — boss-ai.md and content.md: Boss AI values `add_counter`

### Change Summary
Changed sections:
- boss-ai C6: `add_counter` joins the op list with the row `add_counter 0.5` and its rationale (the floor of the table, with `armor`; the reading `damage` op already carries the payoff). `set_counter` stays unvalued.
- boss-ai F9: a note under the schema block. The decided row moves into the `op_values:` list together with `ai_profiles.json` (content story 010), because `boss_ai_profiles_data_test.gd` pins the shipped file to that list.
- content Edge Cases ("If a boss deck recipe cannot reach 30 ids"): the Gravekeeper use of the fallback is superseded.

Unchanged: every formula, weight, budget and every other op value. The CN-2 / CN-3 tables are unchanged, since they already list Gravekeeper.

Key changes affecting architecture: none structural. The op value table is data (`ai_profiles.json`), and its keys are already open to Card Effects C5 names.

Downstream GDDs to re-check: none in the registry (`op_values` has no entity). card-effects C11 row 45 is the reading op, unchanged.

### ADRs in scope
boss-ai.md (standard): 8 ADRs (Foundation 0001, 0002, 0003, 0004, 0010 plus 0005, 0006, 0007, 0008, which name boss-ai.md). content.md: ADR-0002 and 0003 name it. A search of `docs/architecture/` for `add_counter`, `op_values` values and `gravekeeper` finds `op_values` only as a constructor parameter name (ADR-0001, ADR-0008, architecture.md), with no row or value quoted.
- All in-scope ADRs: **Still Valid**. None quotes an op value or the Gravekeeper deferral, so no erratum is needed.

### Stories
- New: `production/epics/content/story-010-gravekeeper-returns-to-the-boss-decks.md` (Config/Data, S). It covers the row, the card, the Gatekeeper / Hollow King / Rot Warden swaps, and The Torchbearer's swap (story 001 dropped Gravekeeper for the same reason; flagged for the owner to strike if unwanted).
- Dated pointers added in content stories 001, 003 and 004. Story 009 now depends on 010. EPIC.md and `production/epics/index.md` show 10 stories.

**Sprint 5:** content story 010 (data: `ai_profiles.json`, `cards_neutral.json`, `bosses.json`; tests: `boss_ai_profiles_data_test.gd` 19 → 20, `content_mvp1_data_test.gd`, `content_batch0_data_test.gd`; boss-ai F9 list).
