# Story 003: MatchController and MatchQuery — the three channels, flush-before-submit and engine parity

> **Epic**: Match UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

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

- [ ] GIVEN a `MatchDriver` built by the driver factory with `ImmediatePlannerTask`, WHEN wrapped by `MatchController.new(driver)`, THEN every U2 call is a pass-through, the controller's only field is the driver reference (and the queue handle it is given for U4.7), and every `MatchQuery` method (`phase`, `pending_choice`, `entity`, `hand`, `card_text`, `legal_commands`, `hero_power_state`) returns a value copy — mutating a returned dictionary changes nothing a second call returns.
- [ ] GIVEN a queue holding pending steps, WHEN `MatchController.submit(cmd)` is called, THEN `skip_all()` runs (every pending `apply_final` executed) before the command reaches `driver.submit`, and the returned `CommandResult` is the driver's unchanged.
- [ ] **L2** GIVEN a recorded full-match stream, WHEN each event is applied to a `MatchViewState`, THEN hero health / armour, mana, deck counts, hand ids and board tokens equal the `MatchQuery` snapshot taken after the same `seq`.
- [ ] **L13** Performance: projecting 2,000 events completes in < 50 ms; a skip-all over 200 pending steps completes in < 100 ms; every `MatchQuery` call returns in ≤ 2 ms on a 7 v 7 board.

---

## Implementation Notes

*Derived from ADR-0008 and ADR-0009 Implementation Guidelines:*

- `src/ui/match/match_controller.gd`, `src/ui/match/match_query.gd` per ADR-0008 Key Interfaces. `MatchQuery` reads through `RulesEngine.state_snapshot(entity_id)` / `phase()` / `pending_choice()` (match-rules story 001's value copies) and `CardDatabase` for `card_text`.
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
- `src/ui/match/match_query.gd`
- `tests/integration/match_ui/match_controller_channels_test.gd`
- `tests/integration/match_ui/view_state_engine_parity_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/match_ui/match_controller_channels_test.gd` and `tests/integration/match_ui/view_state_engine_parity_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/match-ui/story-001-match-view-state-projection.md`, `production/epics/match-ui/story-002-animation-queue-core.md`; `production/epics/boss-ai-match-driver/story-013-match-driver-construction-and-command-gate.md`, `production/epics/boss-ai-match-driver/story-001-planner-task-seam.md`; `production/epics/match-rules/story-001-data-model-and-rules-config.md`
- Unlocks: `production/epics/match-ui/story-004-match-view-skeleton-and-fixture-loader.md`
