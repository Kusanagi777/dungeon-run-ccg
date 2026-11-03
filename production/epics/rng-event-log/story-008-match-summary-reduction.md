# Story 008: `reduce_to_summary()` — `match_summary` and `damage_by_card` (rule 19)

> **Epic**: RNG & Event Log
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

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

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/core/log/event_log.gd`
- `tests/unit/rng_event_log/event_log_summary_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: standard` Logic tests are BLOCKING.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/rng_event_log/event_log_summary_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/rng-event-log/story-005-event-log-core-append-subscribe-seal.md`
- Unlocks: None inside this epic (Run Structure and Run UI consume it)
