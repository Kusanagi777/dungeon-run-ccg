# Story 024: Input latency table measured, and the Feel acceptance playtest

> **Epic**: Match UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/match-ui.md` Game Feel — Input Responsiveness (seven rows), Feel Acceptance Criteria
**Requirement**: `TR-match-ui-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009 (Validation Criteria: "match-ui Input Responsiveness table measured by the `scene_runner()` integration test: all seven rows within budget"); ADR-0010 (Windows confirmation advisory)
**ADR Decision Summary**: Pickup and drag are immediate; the first visual event is a step start within the frame after `submit`; skip-all is a one-frame flush.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Headless frames ran ≈ 6–7 ms in Probe A (not 60 Hz) — measure in wall-clock ms with `Time.get_ticks_usec()` under the windowed xvfb run, and state which.

**Control Manifest Rules (this layer)**:
- Required: timing on `_process` ticks.
- Forbidden: Never `await` chains for timing.
- Guardrail: skip-all ≤ 100 ms; `MatchQuery` ≤ 2 ms.

---

## Acceptance Criteria

*From match-ui Input Responsiveness and Feel Acceptance Criteria:*

- [ ] GIVEN `tests/integration/match_ui/input_latency_test.gd` (`scene_runner()`), WHEN each row is measured on `turn1_player` / `boss_turn_playback`, THEN press → lift ≤ 16 ms, drag → position ≤ 16 ms, release → first visual event ≤ 50 ms, rejection → shake + tooltip ≤ 50 ms, skip-all → display = view-state ≤ 100 ms, End Turn → intent commit beat ≤ 300 ms, hover → preview complete ≤ 100 ms.
- [ ] GIVEN the Windows export, WHEN the same seven rows are timed by hand or by a debug overlay, THEN the results are recorded beside the Linux numbers (advisory, ADR-0010).
- [ ] GIVEN playtest #2 (≥ 10 losses across testers), WHEN reported with `/playtest-report`, THEN no tester calls pickup / drag "laggy", "floaty" or "sticky", none asks "who attacked first?", none calls a boss turn "long" at defaults or "a blur" at `fast`, and testers state why they lost from the board and ticker alone in ≥ 8 of 10 losses.

---

## Implementation Notes

- One test, one row per case; fail messages print the measured ms.
- The playtest is a document, not an automated test (coding-standards: feel is not automated).

---

## Out of Scope

- Polish backlog arising from the playtest (new stories via `/quick-design`).

---

## Files

- `tests/integration/match_ui/input_latency_test.gd`
- `production/qa/playtests/playtest-002-match-feel.md`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/match_ui/input_latency_test.gd` passes, AND playtest doc `production/qa/playtests/playtest-002-match-feel.md`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/match-ui/story-012-first-playable-windows-match.md`, `production/epics/match-ui/story-022-debug-loader-poses-and-fixture-sweep.md`, `production/epics/match-ui/story-023-impact-moments-and-reduce-motion.md`
- Unlocks: None
