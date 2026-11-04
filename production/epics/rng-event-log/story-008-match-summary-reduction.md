# Story 008: `reduce_to_summary()` — `match_summary` and `damage_by_card` (rule 19)

> **Epic**: RNG & Event Log
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-03

## Context

**GDD**: `design/gdd/rng-event-log.md`
**Requirement**: `TR-rng-event-log-006` (rule 18: the match log is reduced to a summary on `match_ended`; rule 19 defines the reduction — no registry row names rule 19 on its own)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Seeded RNG Service and Event Log
**ADR Decision Summary**: `reduce_to_summary()` implements rule 19 — `damage_by_card` from `damage_dealt.source` / `dealt` through the `instance_id → card_id` map built from `minion_summoned`, `weapon_equipped`, `card_played` and `hero_power_used`; the summary is one `match_summary` event per match on the run log.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (general) / LOW for this story
**Engine Notes**: Pure Dictionary reduction; typed Arrays; explicit `return` on typed overrides (4.7). No engine API.

The run log holds run-scope events plus one `match_summary` per match (rule 18); Run UI reads `damage_by_card` for the summary screen and `/balance-check` reads it from archived logs. The payload field names come from Match Rules' C15 table (authoritative for its events).

**Control Manifest Rules (this layer)**:
- Required: treat every returned Dictionary/Array as read-only — a system that mutates takes `duplicate(true)` first; emit exactly one event per mutation (the summary append is Run Structure's).
- Forbidden: never a log filter in `src/core/log/` (the reduction reads, it does not filter the live log); never `assert()` on data in release paths.
- Guardrail: none specific.

---

## Acceptance Criteria

*From GDD `design/gdd/rng-event-log.md` (rules 18–19, event catalogue `match_summary`), scoped to this story:*

- [ ] **GIVEN** a sealed match log with a `minion_summoned{instance_id: 7, card_id: "card_a"}`, three player `damage_dealt` events with `source: 7` and `dealt` 3, 4, 5 (one with `requested: 6, prevented: 1`), and one `damage_dealt` whose `source` is a boss instance, **WHEN** reduced to `match_summary`, **THEN** `damage_by_card == {"card_a": 12}` (rule 19 — `dealt`, not `requested`, is summed; boss sources are excluded).
- [ ] **Attribution map (rule 19):** a `source` that is a player weapon (`weapon_equipped`) or the hero power (`hero_power_used.power_id`) attributes to that `card_id` / `power_id`; a `card_played` instance attributes to its `card_id`; a `source` with no map entry (fatigue, unknown id) attributes to nothing and raises no error.
- [ ] **Summary shape (catalogue row):** the returned Dictionary has exactly `{floor, result, winner, reason, turns, event_count, cards_played, damage_by_card}` with `result`, `winner`, `reason` copied from the sealed log's `match_ended` payload (C14 `MatchResult`), `turns` from `match_ended.turns`, `event_count == size()`, `cards_played` = count of player `card_played` events; calling `reduce_to_summary()` on an unsealed log returns an empty Dictionary and pushes an error.

---

## Implementation Notes

*Derived from ADR-0003 Implementation Guidelines and Decision 9:*

- `reduce_to_summary() -> Dictionary`: one pass over `events`: build `instance_id → card_id` from `minion_summoned`, `weapon_equipped`, `card_played` (`instance_id, card_id`) and `hero_power_used` (`power_id` keyed by the hero's `instance_id` — Match Rules assigns both heroes an `instance_id`; until its C15 fixes the hero-power attribution key, map `power_id` under the player's hero instance); determine player-owned instances by `side == "player"` on the summoning/playing event; sum `dealt` per `card_id` for `damage_dealt` whose `source` is player-owned.
- Field names are Match Rules' C15 payload (`source, target, requested, prevented, armor_absorbed, dealt, health_after`); the GDD's catalogue table is the cross-system index — if C15 renames a field the GDD row changes first.
- The result is a plain Dictionary that Run Structure appends as `match_summary` to the run log (rule 18) — this method appends nothing.
- Must not mutate `events`; must never assert on payload data in release.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Run Structure epic: appending `match_summary` to the run log, `run_total_events`.
- Run UI epic: displaying `damage_by_card`.
- Story 009: archiving the raw log before reduction.

---

## Files

- `src/core/log/event_log.gd` — `reduce_to_summary()` (rules 18-19), `_as_int()`, `_SIDE_PLAYER`
- `tests/unit/rng_event_log/event_log_summary_test.gd` — 7 tests

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: standard` Logic tests are BLOCKING.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/rng_event_log/event_log_summary_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] Created — 7 tests, passing

---

## Dependencies

- Depends on: `production/epics/rng-event-log/story-005-event-log-core-append-subscribe-seal.md`
- Unlocks: None inside this epic (Run Structure and Run UI consume it)

---

## Completion Notes
**Completed**: 2026-11-03
**Started / ended (UTC)**: 2026-11-03T22:31:41Z – 2026-11-03T22:33:59Z
**Criteria**: 3/3 passing (all covered by unit tests; no deferred items)

| Criterion | Covered by | Status |
|-----------|------------|--------|
| AC-1: `minion_summoned{7, card_a}` + player `damage_dealt` 3/4/5 (one `requested 6, prevented 1`) + a boss-source hit → `{"card_a": 12}` | `event_log_summary_test.gd::test_dealt_from_a_player_minion_is_summed_and_boss_sources_are_excluded` | COVERED |
| AC-2: weapon → its `card_id`, hero power → `power_id`, `card_played` instance → its `card_id`; unmapped sources (fatigue, unknown id) → nothing, no error | `test_weapon_hero_power_and_played_card_attribute_to_their_ids`, `test_unmapped_sources_attribute_to_nothing_without_an_error` | COVERED |
| AC-3: exactly `{floor, result, winner, reason, turns, event_count, cards_played, damage_by_card}` from `match_ended`; `event_count == size()`; player `card_played` count; unsealed → `{}` + error | `test_summary_has_exactly_the_catalogue_fields_copied_from_match_ended`, `test_a_fault_result_copies_a_null_winner`, `test_an_unsealed_log_gives_an_empty_summary_and_an_error`, `test_reduction_leaves_the_log_unchanged_and_survives_a_json_round_trip` | COVERED |

**Deviations**:
- ADVISORY — the hero-power key: `hero_power_used{side, power_id, target_id}` names no instance, so `power_id` is mapped under the player's hero instance read from `match_started.hero_id`. The engine (`src/gameplay/match/rules_engine.gd`) emits the hero's `entity_id` there; the GDD catalogue's `hero_id` could also be read as a definition id. This follows the story's Implementation Notes ("until its C15 fixes the hero-power attribution key"). Consequence: if Match Rules makes the hero (not the weapon instance) the `source` of a weapon attack, that damage would be credited to the hero power once one has been used — Match Rules C15 should pin the `source` of hero attacks and hero-power damage.
- ADVISORY — `floor` comes from `match_ended.floor` (C14 carries it), falling back to the log header's `floor`. A sealed run log, or a match log sealed without a `match_ended` (Faulted then another type), also returns `{}` + the same error.
- ADVISORY — numeric payload values are read as whole numbers (`int` or integral float), so a log rebuilt by `from_json()` reduces identically (tested); a non-numeric `source` / `dealt` attributes nothing, silently (no assert on payload data).
**Test Evidence**: `tests/unit/rng_event_log/event_log_summary_test.gd` — 7 tests. Seen failing first: all 7 failed against the code without `reduce_to_summary()` (exit 100); after implementation two mutations (summing `requested`, no player-side filter) failed 2 tests, then passed restored. Full suite 719/719, exit 0; 36 SCRIPT ERROR lines, all from existing negative tests (unchanged). Smoke exit 0, no SCRIPT ERROR.
**Run result**: N/A — a pure reduction with no scene, node or screen; the summary is displayed by the Run UI epic.
**Engine check**: NOT ASSESSED — no specialist agent in this lane; no engine API beyond Dictionary/Array.
**Reviewed by**: self, no independent review (`review_mode: lean` — QL-TEST-COVERAGE and LP-CODE-REVIEW skipped; `/code-review` not run in this lane) · `/code-review 2026-11-04 (independent, sprint-4 carry): CHANGES REQUIRED (1 blocking)` — fixed in 211e18c (engine-log tests dcf1447; GDD catalogue now `entity_id`)
