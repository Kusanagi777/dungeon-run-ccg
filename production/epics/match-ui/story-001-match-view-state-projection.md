# Story 001: MatchViewState — pure projection, hidden information and the unknown / diagnostic filters

> **Epic**: Match UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/match-ui.md` U3 (projection rules 1–5, the event → projection → step table, silent set), U1 (`MatchViewState` row)
**Requirement**: `TR-match-ui-002` (also `TR-match-ui-001`)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009: Match UI Animation Queue, Tween Approach and Scene Partition (Decision §2, Key Interfaces); ADR-0003 (envelope `{seq, turn, type, payload, cause_seq}`, rule 12a diagnostics); ADR-0001 (presenters render numbers from events, not queries)
**ADR Decision Summary**: `MatchViewState.apply(event) -> Array[AnimStep]` is a pure `RefCounted` projection of the match event log; `group_id` is the `seq` of the event's command root (walk `cause_seq` to 0 through a per-turn `seq → cause_seq` map); diagnostic events are filtered before the unknown-type rule (U3.4a).
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (by version; this story uses only `RefCounted`, typed `Array` / `Dictionary` — 4.0-era, LOW)
**Engine Notes**: Every override returns explicitly (4.7 typed-return rule). Typed `Array[AnimStep]` in signatures; no untyped containers (deprecated-apis). Lambdas capture by value — the `seq → cause_seq` map is an instance field.

**Control Manifest Rules (this layer)**:
- Required: `AnimationQueue`, `MatchViewState` and `AnimStep` are `RefCounted` with no Node reference; unit tests run headless. `MatchViewState.apply(event) -> Array[AnimStep]` is pure; `group_id` = the `seq` of the command root.
- Forbidden: Never hold a `MatchState` or live rules object in `src/ui/**`. A presenter never stores a value the view-state does not have.
- Guardrail: `MatchViewState.apply` is O(1) per event.

---

## Acceptance Criteria

*From GDD `design/gdd/match-ui.md` Acceptance Criteria (Logic), scoped to the projection:*

- [ ] **L1** GIVEN a recorded event stream of a full match, WHEN projected twice from `seq` 1, THEN the two `MatchViewState`s are field-for-field equal and the two `AnimStep` lists are equal (kind, entity ids, base duration, group id) — projection is pure.
- [ ] **L3** GIVEN a boss `card_drawn` event, WHEN projected, THEN the boss hand count increments and no `card_id` is stored anywhere in the view-state; a boss-side `discover_offered` stores no options (U3.2).
- [ ] **L4** GIVEN an event of an unknown `type` (in neither the U3 table, the `silent_types[]` set nor the diagnostic class), WHEN projected, THEN the view-state is unchanged except one feed line keyed `feed.unknown` carrying the type name, no step is produced and no exception is raised.
- [ ] **L9** GIVEN a player-side `command_rejected` diagnostic, WHEN projected, THEN no view-state field other than `feed_lines` changes, exactly one `reject_shake` step carrying the code is produced and exactly one `feed.command_rejected` line is appended; GIVEN a boss-side `command_rejected`, THEN no step and no line.

---

## Implementation Notes

*Derived from ADR-0009 Implementation Guidelines and match-ui U3:*

- `src/ui/match/match_view_state.gd` — `class_name MatchViewState extends RefCounted`; fields per ADR-0009 Key Interfaces: per side `hero{health, armor, weapon, power_state}`, `mana{available, max, temporary}`, `deck_count`, `fatigue_next`, `hand[]` (boss = count), `board[]` (≤ `board_size` 7); plus `phase`, `active_side`, `turn`, `intent`, `pending_choice`, `pending_mulligan`, `counters`, `armed_sources`, `exhausted_sources`, `feed_lines`, `result`. `side(name)` returns value copies.
- Implement the whole U3 table in one dispatch (a `match` on `type`); every event applies immediately in `seq` order (rule 1). Steps carry `base_duration_s` looked up from the injected `config("match_ui")` dictionary — never a literal (L14 is asserted in Story 006 and Story 002; this story takes the config as a constructor argument).
- Rule 3 groupings that are *projection* concerns live here: `mana_*` / `auras_recomputed` → zero steps; `attack_declared … attack_resolved` → one lunge step; a run of `minion_died` sharing a `cause_seq` → one `death_group` step followed by one `gap_close` step (L5 is asserted in Story 002 against the queue; emit them here); `discover_offered` + `choice_requested` → one `overlay_open` step on the second of the pair, whichever order.
- Rule 4a precedes rule 4: `payload.diagnostic == true` → no state change, no step, no line (except the player's `command_rejected`, L9). `ai_decision` fills a debug buffer only when a `debug_overlay` flag is set (wired by Story 022's `--ai-debug`). Silent set from `config("match_ui").silent_types`.
- Feed line *content* (key + params) is recorded here as `{key, params, group_id}`; rendering and grouping are Story 014.
- The recorded streams are produced by the real engine (`tests/fixtures/match_ui/` JSON run through `MatchDriver` with `ImmediatePlannerTask`) and saved as test data under `tests/fixtures/match_ui/streams/`; until Story 004's loader exists, build them in the test with `MatchFactory` + `RulesEngine` from the match-rules epic.

---

## Out of Scope

- Story 002: queue scheduling, coalescing (> 8 pops), F3, skip-all, idle invariant.
- Story 003: L2 (parity with `MatchQuery` after every `seq`).
- Story 014: feed rendering, F5 collapse, L18 (`counter_changed`, silent set and diagnostics without `--ai-debug` — this story implements the filter; Story 014 owns the AC).

---

## Files

- `src/ui/match/match_view_state.gd`
- `src/ui/match/anim_step.gd` (data class only; queue behaviour is Story 002)
- `tests/unit/match_ui/match_view_state_projection_test.gd`
- `tests/fixtures/match_ui/streams/full_match_torchbearer.json`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/match_ui/match_view_state_projection_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/rng-event-log/story-005-event-log-core-append-subscribe-seal.md`, `production/epics/rng-event-log/story-006-event-log-serialization-and-diagnostics.md`; `production/epics/match-rules/story-004-command-channel-and-mulligan.md` (C15 event names, `command_rejected`); `production/epics/card-database/story-006-freeze-and-queries.md` (`config("match_ui")`)
- Unlocks: `production/epics/match-ui/story-002-animation-queue-core.md`, `production/epics/match-ui/story-003-match-controller-and-match-query.md`
