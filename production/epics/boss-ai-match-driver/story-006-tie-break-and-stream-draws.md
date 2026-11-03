# Story 006: Tie-break set, fork labels and ai_<floor> draw accounting

> **Epic**: Boss AI + Match Driver
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/boss-ai.md` (C9 tie-breaks and draws, F8, C4 sandbox forks, C8.1 forecast fork)
**Requirement**: `TR-boss-ai-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Seeded RNG Service and Event Log (named streams, `fork(label)` costs one parent draw per new label — rule 5; replay by draw count); ADR-0006 (the worker is handed the `ai_<floor>` stream, which nothing else reads; `TurnPlan.ai_draws`)
**ADR Decision Summary**: The AI's only live `ai_<floor>` draws are one `randi_range` per tie set of size > 1 plus one parent draw per new fork label (`sim_<turn>`, `forecast_<turn>`); sandboxes draw from their forks. Draw count per turn is therefore deterministic given the state, which `restore()` relies on. The `match_<floor>` stream is never touched by the planner.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH / NOT SOURCEABLE
**Engine Notes**: ADR-0003 — one `RandomNumberGenerator` per stream, same seed ⇒ same sequence observed on 4.7.2 (Probe D); `randi_range` over `randi32()` per F4. Tests use `TestRngStream` (`tests/helpers/test_rng_stream.gd`) with exact `draws` counting and `fork`.

**Control Manifest Rules (this layer)**:
- Required: Tie-breaks from `ai_<floor>` and its forks; `ai_decision` diagnostics on the log (ADR-0003). The worker receives the clone, the `ai_<floor>` stream and the frozen `CardDatabase`.
- Forbidden: Nothing in `src/ai/**` touches a `RandomNumberGenerator` directly or the `match_<floor>` stream; never `log.append` on a live log from the planner.
- Guardrail: none beyond the draw accounting itself.

---

## Acceptance Criteria

*From GDD `design/gdd/boss-ai.md` A2, A3, A5, scoped to this story:*

- [ ] **A2** GIVEN two matches identical except `run_seed`, WHEN a turn produces a tie set of size > 1, THEN the chosen commands may differ, and every other decision with a tie set of size 1 is identical (a tie set of size 1 consumes no draw).
- [ ] **A3** GIVEN a logged match, WHEN replayed from its `stream_seed` and command list, THEN the AI's `ai_<floor>` draw count per turn equals the original and equals (tie-set draws + number of new fork labels created that turn), and `TurnPlan.ai_draws` reports the same number.
- [ ] **A5** GIVEN any state, WHEN `play_turn` runs, THEN the live `match_<floor>` stream's `draws` counter is unchanged by the planner, and the `ai_<floor>` counter rises by exactly (tie-set draws + new fork labels this turn); `sim_<turn>` and `forecast_<turn>` labels are created at most once per turn each.

---

## Implementation Notes

*Derived from ADR-0003 and GDD C9 / F8:*

- Files: `src/ai/tie_break.gd` (`class_name TieBreak extends RefCounted`): `pick(scored: Array, tie_epsilon: float, ai_stream) -> {chosen, ties}`; `ties = sort_canonical({a : score(best) − score(a) ≤ tie_epsilon})`; canonical order is command type, then `hand_index`, `attacker_id`, `target_id`, `position`; `pick = ties[ai_stream.randi_range(0, |ties| − 1)]` only when `|ties| > 1`.
- Fork handling lives in `BossAI` (Story 008): `ai_stream.fork("sim_<turn>")` once per turn, shared by every sandbox that turn; `fork("forecast_<turn>")` once per forecast. Count both in `TurnPlan.ai_draws` (ADR-0006 `TurnPlan` field).
- `tie_epsilon` from `rules` (default 0.05) — data, never a literal.
- The test drives the planner with `TestRngStream.seeded` and asserts `draws` exactly; the `match_<floor>` double asserts `draws_outside([...])` is empty for the planner.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 008: `plan_turn`, which creates the forks and fills `TurnPlan.ai_draws`; A1 (10-turn byte-identical sequences).
- Story 017: the cross-implementation determinism run.

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/ai/tie_break.gd`
- `tests/unit/boss_ai/boss_ai_tie_break_test.gd`
- `tests/fixtures/boss_ai/tie_set_board.json`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/boss_ai/boss_ai_tie_break_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/boss-ai-match-driver/story-004-scorer-features-and-board-value.md`; `rng-event-log` epic's `RngStream.fork` / draw counters (cross-epic)
- Unlocks: `production/epics/boss-ai-match-driver/story-008-plan-turn-loop-and-turn-plan.md`
