# Story 001: MatchViewState — pure projection, hidden information and the unknown / diagnostic filters

> **Epic**: Match UI
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-04

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

- [x] **L1** GIVEN a recorded event stream of a full match, WHEN projected twice from `seq` 1, THEN the two `MatchViewState`s are field-for-field equal and the two `AnimStep` lists are equal (kind, entity ids, base duration, group id) — projection is pure.
- [x] **L3** GIVEN a boss `card_drawn` event, WHEN projected, THEN the boss hand count increments and no `card_id` is stored anywhere in the view-state; a boss-side `discover_offered` stores no options (U3.2).
- [x] **L4** GIVEN an event of an unknown `type` (in neither the U3 table, the `silent_types[]` set nor the diagnostic class), WHEN projected, THEN the view-state is unchanged except one feed line keyed `feed.unknown` carrying the type name, no step is produced and no exception is raised.
- [x] **L9** GIVEN a player-side `command_rejected` diagnostic, WHEN projected, THEN no view-state field other than `feed_lines` changes, exactly one `reject_shake` step carrying the code is produced and exactly one `feed.command_rejected` line is appended; GIVEN a boss-side `command_rejected`, THEN no step and no line.

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
- `tests/helpers/match_ui/match_ui_test_config.gd` (added: the `match_ui` fixture body until content 001 ships `match_ui.json`, the DD-X07 settings defaults, the fixture-stream loader)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/match_ui/match_view_state_projection_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`)

**Status**: [x] Created — `tests/unit/match_ui/match_view_state_projection_test.gd` (17 tests)

---

## Dependencies

- Depends on: `production/epics/rng-event-log/story-005-event-log-core-append-subscribe-seal.md`, `production/epics/rng-event-log/story-006-event-log-serialization-and-diagnostics.md`; `production/epics/match-rules/story-004-command-channel-and-mulligan.md` (C15 event names, `command_rejected`); `production/epics/card-database/story-006-freeze-and-queries.md` (`config("match_ui")`)
- Unlocks: `production/epics/match-ui/story-002-animation-queue-core.md`, `production/epics/match-ui/story-003-match-controller-and-match-query.md`

---

## Completion Notes
**Completed**: 2026-11-03 (started 22:59:16 UTC, ended 23:16:21 UTC)
**Criteria**: 4/4 passing — L1 (`test_full_match_projected_twice_gives_equal_states_and_step_lists`, plus `test_full_match_projection_reaches_the_final_match_state` so equality is not over two empty projections), L3 (`test_boss_card_drawn_increments_the_hand_count_and_stores_no_card_id` — recursive walk of the snapshot and the step signatures; `test_boss_discover_offered_and_choice_requested_store_no_options`), L4 (`test_unknown_event_type_adds_only_one_feed_unknown_line_and_no_step`, incl. the deleted legacy aliases `mana_changed` / `weapon_broken`), L9 (`test_player_command_rejected_changes_only_feed_lines_and_yields_one_reject_shake`, `test_boss_command_rejected_yields_no_step_and_no_line`). Also: silent set (from config), the other diagnostics not "unknown", the `--ai-debug` buffer, `group_id` = command root, death run → one `death_group` + one `gap_close`, Discover pair → one `overlay_open` either order, mana / auras → zero steps, durations from config, `side()` value copies. Watched fail: 14 of 17 against a stub (`apply` → `[]`); the 3 "nothing changes" tests passed vacuously there, so each was then run against a mutant — boss-side reject guard removed, silent filter removed, diagnostic filter removed, boss `card_id` stored, boss options stored, `group_id` = `cause_seq` instead of the root, every death its own step — all 7 mutants caught.
**Deviations** (advisory):
- **Fixture**: `full_match_torchbearer.json` (170 events, `EventLog.to_json` format, loaded through `EventLog.from_json`) is hand-built per the orchestrator / QA plan (no full match is playable before MR-010+); shapes are the merged engine's where it emits the event (`minion_summoned{entity_id, position}`, `damage_dealt`, `healed{amount}` …) and the rng-event-log catalogue's otherwise (`card_played`, `mana_spent{amount, mana_available}`, `attack_*`, `minion_died{instance_id}`, `trigger_*`). The boss starts at 4 health so the match fits nine turns. Re-record once MUI-004 / MR-012+ land.
- **Config body**: `match_ui.json` does not exist yet; tests read `MatchUiTestConfig.body()` (keys `d_base`, `SPEED_DIV`, `COALESCE_THRESHOLD`, `silent_types`, `FEED_MAX_LINES`, `impact_ms`) — content 001 must ship the same key names or this helper and the reads change. `d_base` carries the F3 17 kinds plus 15 kinds the U3 table times but F3 does not name (`summon`, `weapon_update`, `power_press`, …; `intent_commit` = Boss AI `intent_banner_s`). No `match_ui` config validator ships here (`W_VALIDATOR_PENDING` stays).
- **GDD gaps found** (for the match-ui GDD owner): no C15 event carries a hero's starting health, so `hero.health` is null until the first `damage_dealt.health_after` (Story 003's L2 parity will need it, e.g. on `match_started`); `card_added_to_hand` (C15) is not in the U3 table — projected like `card_drawn` (incl. `returned_entity_id` → token leaves the board); `minion_transformed` (engine `transform`) is in neither C15 nor U3 and its payload has no stats — left to rule 4 (`feed.unknown`); `armor_lost` gets no pop (the following `damage_dealt` pops `dealt`, which includes `armor_absorbed`; the U3 row would double-count it); `log_overflow` / `resolution_overflow` set a fault `result` with no step (the fault's `match_ended` carries the end banner, else two banners).
- **Projection choices**: `turn_started` also does the Start step's bulk reset (power ready, `attacks_used` 0) because its `turn_reset` event is in the silent set; `turn_started` / `turn_ending` set phase `start` / `end` (the engine enters them without `phase_changed`); a spell logging both `card_played` and `spell_cast` gets one `play_card` step (on the event that removes it from hand); `fatigue_next` is the next fatigue counter `k`, not its damage (F5 base / step are match-rules data the UI does not read); boss hand and decks are tracked as instance-id sets (ids are public, `card_id`s are not) so a burn from `add_card_to_hand` does not tick the deck; every table event appends one `feed.<type>` line with the payload as params (hidden fields dropped), capped at `FEED_MAX_LINES`.
- **`AnimStep`** adds `seq` and `data` (payload numbers: `amount`, `code`, `source`) beside the ADR-0009 Key Interfaces fields; `impact` lands with Story 002. Hand entries carry no cost (no event carries it; Story 006 reads `MatchQuery.hand()`).
- The boss Choice's 0.4 s "boss discovers…" label (Edge Cases) has no step yet (Story 013 / 015).
**Test Evidence**: `tests/unit/match_ui/match_view_state_projection_test.gd` (17 tests); full suite 831 test cases, 0 failures, exit 0, 45 SCRIPT ERROR lines (all baseline intentional negatives in card_database / event_log / rng / boss_ai suites; none from match_ui); smoke exit 0, no SCRIPT ERROR; parse check exit 0; `tools/lint/gates.sh` PASS (G5: no rules-state names under `src/ui`).
**Run result**: N/A — the story adds a headless `RefCounted` projection and a data class; no scene, node or screen renders them until Story 004's `MatchView`.
**Reviewed by**: self, no independent review (LP-CODE-REVIEW skipped — Lean mode; QL-TEST-COVERAGE skipped — Lean mode)

### Fizzle fix (2026-11-04, started 02:17:30 UTC, ended 02:19:09 UTC; branch `fix/review-s3w2`)
Orchestrator item (sprint 3 wave 2 code review, extra): `effect_resolved` was projected as a fizzle only when `fizzled == true`, but `EffectResolver` emits `fizzled: null` or the reason String (`condition_false`), so the wisp never played. `MatchViewState` now treats any `fizzled` other than `null` as a fizzle and keeps the reason on the step (`AnimStep.data = {reason}`). Tests added (2, in `match_view_state_projection_test.gd`, payload in the resolver's shape): `test_effect_resolved_with_a_fizzle_reason_yields_one_fizzle_step_keeping_the_reason` (watched fail: no step) and `test_effect_resolved_with_null_fizzled_yields_no_step`. Full suite 1078 test cases, 0 failures, exit 0, 85 SCRIPT ERROR lines (unchanged); smoke exit 0. Run result: N/A, as above — the projection still renders nothing (Story 004).
Deviation (advisory): a literal `false` is also read as "not fizzled": the committed stream `tests/fixtures/match_ui/streams/full_match_torchbearer.json` and `animation_queue_test.gd` carry `fizzled: false` (pre-dating the engine's shape) and are unchanged.
