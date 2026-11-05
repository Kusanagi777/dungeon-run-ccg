# Story 003: MatchController and MatchQuery — the three channels, flush-before-submit and engine parity

> **Epic**: Match UI
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-04

## Context

**GDD**: `design/gdd/match-ui.md` U1 (`MatchController`, `MatchQuery` rows), U2 (the boundary API and query table), U4.7 (command while busy)
**Requirement**: `TR-match-ui-001` (also `TR-match-ui-002`)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008: Match Driver Ownership and the Run ↔ Match ↔ UI Hand-off (Key Interfaces, `MatchController`); ADR-0001 (three channels only); ADR-0009 (U4.7 flush in `submit`)
**ADR Decision Summary**: `MatchController` wraps the `MatchDriver` it does not own and holds nothing but the driver reference; it passes through `submit`, `legal_commands`, `query`, `subscribe`, `events_since`, `tick`, `on_setting_changed`, `shutdown`, `is_planning`. `MatchQuery` returns value copies only. `submit` calls `queue.skip_all()` before `driver.submit`.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH by version (APIs used — `RefCounted`, `Callable`, `Dictionary.duplicate(true)` — have no post-cutoff change)
**Engine Notes**: The controller is `await`-free. Lambdas capture by value: no captured locals hold engine references.

**Control Manifest Rules (this layer)**:
- Required: UI talks to the rules through exactly three channels; `MatchController.submit` calls `queue.skip_all()` before `driver.submit`.
- Forbidden: Never call `.submit(` outside `*_controller.gd`, `*_driver.gd` and the `*_view.gd` input path (gate G5). `MatchController` holds nothing but the driver reference. Never let presenters poll `MatchQuery` to render numbers.
- Guardrail: `MatchQuery.*` ≤ 2 ms each, called only on hover / drag.

---

## Acceptance Criteria

*From GDD `design/gdd/match-ui.md` U1, U2, U4.7 and Acceptance Criteria L2, L13:*

- [x] GIVEN a `MatchDriver` built by the driver factory with `ImmediatePlannerTask`, WHEN wrapped by `MatchController.new(driver)`, THEN every U2 call is a pass-through, the controller's only field is the driver reference (and the queue handle it is given for U4.7), and every `MatchQuery` method (`phase`, `pending_choice`, `entity`, `hand`, `card_text`, `legal_commands`, `hero_power_state`) returns a value copy — mutating a returned dictionary changes nothing a second call returns.
- [x] GIVEN a queue holding pending steps, WHEN `MatchController.submit(cmd)` is called, THEN `skip_all()` runs (every pending `apply_final` executed) before the command reaches `driver.submit`, and the returned `CommandResult` is the driver's unchanged.
- [x] **L2** (token `keywords` NOT ASSESSED, see Completion Notes) GIVEN a recorded full-match stream, WHEN each event is applied to a `MatchViewState`, THEN hero health / armour, mana, deck counts, hand ids and board tokens equal the `MatchQuery` snapshot taken after the same `seq`.
- [x] **L13** (in `tests/performance/`, non-blocking) Performance: projecting 2,000 events completes in < 50 ms; a skip-all over 200 pending steps completes in < 100 ms; every `MatchQuery` call returns in ≤ 2 ms on a 7 v 7 board.

---

## Readiness (`/story-readiness`, by hand, 2026-11-04)

**READY, with three readings recorded here** (sprint 5 lane 8 wave 3). Tier: workflow standard. ADR-0001, ADR-0008 and ADR-0009 Accepted; stories 001, 002, BAI-001 and BAI-013 Complete. Advisory: the story embeds Manifest Version 2026-11-03, the manifest is 2026-11-04.

- **The ownership flag** in Implementation Notes is closed by the ADR-0008 erratum of 2026-11-03: `MatchQuery` is rules-tier, built by the driver, forwarded by the controller.
- **"Built by the driver factory":** no story builds `driver_factory`, so the tests call `MatchDriver.new` directly (QA plan, MUI-003 Gaps). NOT ASSESSED until that factory exists.
- **L13** goes to `tests/performance/match_ui/`: its thresholds are wall-clock (QA plan Cross-cutting 2).

---

## Implementation Notes

*Derived from ADR-0008 and ADR-0009 Implementation Guidelines:*

- `src/ui/match/match_controller.gd` (UI) and `src/gameplay/match/match_query.gd` (rules-tier read model, per the ADR-0008 erratum 2026-11-03 — keeps ADR-0001 one-way; the driver builds it, the controller forwards it). `MatchQuery` reads through `RulesEngine.state_snapshot(entity_id)` / `phase()` / `pending_choice()` (match-rules story 001's value copies) and `CardDatabase` for `card_text`.
- **Ownership flag**: boss-ai-match-driver story 013 states that `MatchDriver.query()` builds the `MatchQuery` once over the live engine, while ADR-0008 places `match_query.gd` under `src/ui/match/`. A rules-tier class constructing a UI-tier class conflicts with ADR-0001's tier direction. Resolve before `/dev-story`: either the driver returns a rules-side facade that `MatchController.query()` wraps into `MatchQuery`, or the class moves to `src/gameplay/run/`. Record the choice in this story; do not edit ADR-0008 without the owner.
- L2 parity test runs the real engine: `tests/integration/match_ui/view_state_engine_parity_test.gd` subscribes a `MatchViewState` and snapshots `MatchQuery` after every `seq`.
- L13 timing uses `Time.get_ticks_usec()` around the measured call; record the machine in the test output (min-spec TBD per `architecture.md` §Performance budgets).

---

## Out of Scope

- Story 004: `MatchView` lifecycle (`events_since(0)` then `subscribe`, `_process` → `tick()`, `_exit_tree` → `shutdown()`).
- `boss-ai-match-driver` epic: `MatchDriver` itself.

---

## Files

- `src/ui/match/match_controller.gd`
- `src/gameplay/match/match_query.gd` (ADR-0008 erratum 2026-11-03)
- `src/ui/match/match_view_state.gd` (L2: the engine's `attacker` / `defender` spelling)
- `tests/integration/match_ui/match_controller_channels_test.gd`
- `tests/integration/match_ui/view_state_engine_parity_test.gd`
- `tests/performance/match_ui/match_query_perf_test.gd` (L13)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/match_ui/match_controller_channels_test.gd` and `tests/integration/match_ui/view_state_engine_parity_test.gd` — must exist and pass

**Status**: [x] Created and passing

---

## Dependencies

- Depends on: `production/epics/match-ui/story-001-match-view-state-projection.md`, `production/epics/match-ui/story-002-animation-queue-core.md`; `production/epics/boss-ai-match-driver/story-013-match-driver-construction-and-command-gate.md`, `production/epics/boss-ai-match-driver/story-001-planner-task-seam.md`; `production/epics/match-rules/story-001-data-model-and-rules-config.md`
- Unlocks: `production/epics/match-ui/story-004-match-view-skeleton-and-fixture-loader.md`

---

## Completion Notes
**Completed**: 2026-11-04 (start 04:09:47 UTC, end 04:25:32 UTC; sprint 5 lane 8 wave 3, branch `s5/l8-w3`)
**Criteria**: AC-1 and AC-2 in `match_controller_channels_test.gd` (one or more cases per `MatchQuery` method). L2 in `view_state_engine_parity_test.gd` over four full shipped matches, with one clause NOT ASSESSED (below). L13 in `match_query_perf_test.gd` on an i9-13900HX with other lanes running: worst p95 1.5 ms (`hero_power_state`), 2,000 events 34 ms; skip-all is the existing 300-step case, 1.9 ms.
**NOT ASSESSED**:
- **L2, token `keywords`.** The engine's `minion_summoned` omits the `keywords[]` that rng-event-log §D lists, so no printed keyword reaches the view: Taunt, Divine Shield and the rest have no event-sourced badge. The fix is two payload lines in `rules_engine.gd` plus a reviewed golden regeneration, outside this story. `NOT_PROJECTED` in the parity suite excludes the field until then.
- **AC-1 "built by the driver factory".** No story builds it; the suites call `MatchDriver.new`.
**Tests seen failing**: both suites first failed to parse against the missing `MatchController` (exit 105). L2 then failed on real defects (`attacks_used`, keywords). Mutants on top: `skip_all` after `driver.submit`, and `MatchQuery` with the hidden-zone and boss-count checks removed, failed 5 cases plus 1 error; restored and checked.
**Verification**: import exit 0; `gates.sh` G1 to G7 0 hits, `no_global_rng.sh` 0 hits, `parse-check.sh` 45 checked, 0 failed; `commands.test` 2101 test cases, 0 errors, 0 failures, 0 orphans, exit 0, 88 `SCRIPT ERROR` lines; smoke exit 0, 0 `SCRIPT ERROR`.
**Run result**: N/A: nothing player-visible. No scene exists until story 004, so no capture was taken.
**Deviations** (advisory):
- **`phase()` stays a String, and `active_side()` is added.** U2's row returns the pair; the existing driver suites read `phase()` as a String.
- **`MatchQuery.snapshot(side)` is new.** L2 names "the `MatchQuery` snapshot", but U2's table has no read for mana, deck counts or armour. It is for parity, never for rendering.
- **`MatchQuery` calls `engine.state()`**, against ADR-0007 Decision 4, which names `state_snapshot()` and `clone()`. The engine has no per-side read, and `rules_engine.gd` is outside this story. Nothing live leaves the class. A `RulesEngine` per-side value read would close this.
- **`entity()` answers `{}` for a card in a deck or the boss's hand.** The GDD is silent; hidden information (U3 rule 2) requires it for the boss, and deck order for the player.
- **`hero_power_state()` is `{state, reason_code}`,** and a side with no power reads `HERO_POWER_USED`, as `_validate_hero_power` does.
- **`bind_queue(queue)`** carries the queue handle: `MatchView` builds the queue after the controller is injected. With none bound, `submit` flushes nothing.
- **`on_setting_changed`** was a dynamic call until BAI-014 reached this branch at the M3 merge; it is now direct. Tests build the driver with `planner_factory` (DD-X31).
- **Real planning, verified after the merge:** `test_real_boss_turns_plan_replay_and_pace_through_the_controller` plays four boss turns on the shipped data through `ImmediatePlannerTask`, the controller, the view, the queue and the router.
- **`match_view_state.gd` changed** (not in the planned Files): it read the catalogue's `attacker_id`, and the engine sends `attacker`, so `attacks_used` never moved and `attack_lunge` carried no ids on a real match. It now reads both.
- **L2 is per `seq` for hero armour and health, mana, deck counts and hands, and for boards at every `seq` outside `MID_BATCH`.** The engine applies a batch and then reports it: every death of a pass, and the Start step's reset. `attacks_used` compares after each command, because it moves before `attack_resolved`. Every command boundary compares everything.
- **`hero.health` is null in the view until an event reports it** (story 001): no event carries starting health, so a presenter has nothing to draw before the first damage. Parity counts those and compares the rest.
- **The boss Choice option count** still shows through `legal_commands()`: review question Q-5, open for the owner.
**Reviewed by**: pending, independent `/code-review` at the end of the wave.
