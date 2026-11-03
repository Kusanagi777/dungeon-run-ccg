# Story 010: Choice phase — `choose` for Discover and choose_one

> **Epic**: Boss AI + Match Driver
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/boss-ai.md` (C7, C1.4 `choose`, States `Choosing`, Edge Cases "If a Discover is raised during the boss's turn", "If all Discover options are identical")
**Requirement**: `TR-boss-ai-001`, `TR-boss-ai-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Boss AI Planner Threading (`choose(sandbox, request) -> int` is a task body like the others; inside `plan_turn` the sandbox's own Discovers are answered inline); ADR-0008 (the driver schedules a `choose` task for a boss Choice raised outside a plan)
**ADR Decision Summary**: `choose` scores each option by `op_value × cost_fit + preference` (Discover) or `Σ op_value(op) × targets_now(op)` (choose_one), collapses identical options to the lowest index before tie-breaking so duplicates consume no RNG, and logs an `ai_decision {kind: choice}`. It is pure over the clone and returns an index; the driver submits `choose{issuer: boss, option_index}` on the main thread.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH / NOT SOURCEABLE
**Engine Notes**: No engine API beyond `Dictionary` / `Array`; `ChoiceRequest` shape is match-rules' (`kind: discover | choose_one`, options). `mana_max_by_turn(t + 1)` is match-rules F4.

**Control Manifest Rules (this layer)**:
- Required: Boss `Choice` with no task live → task `boss_ai.choose(sandbox, pending) -> int`, then `engine.submit(choose{issuer: boss, option_index})` on the main thread (driver, Story 014).
- Forbidden: Never invoke a Boss AI entry point inline from `submit` or `tick`. The planner never reads the player's pending Discover options (C1.3).
- Guardrail: none specific.

---

## Acceptance Criteria

*From GDD `design/gdd/boss-ai.md` A16 and C7, scoped to this story:*

- [ ] **A16** GIVEN a Discover with options [2-cost, 2-cost identical, 7-cost] and `mana_max = 4`, WHEN the boss chooses, THEN index 0 is picked, no `ai_<floor>` draw is consumed, and the `ai_decision {kind: choice}` lists 2 alternatives (duplicates collapsed to the lowest index before tie-breaking).
- [ ] GIVEN a `ChoiceRequest {kind: discover}`, WHEN scored, THEN each option scores `op_value(option) × cost_fit + preference` with a vanilla body valued as `buff` at `(attack + health) / 4`, `cost_fit = 1` if the option's cost ≤ next turn's `mana_max` else 0.5, and `preference` from the profile's `choice_preference` for the option's tags (aggro `charge`/`weapon`, control `taunt`/`heal`/`damage_all`, tempo lowest cost, passive_driven its `synergy_tags`).
- [ ] GIVEN a `ChoiceRequest {kind: choose_one}` (options `{label_key, ops[]}`), WHEN scored, THEN each option scores `Σ op_value(op) × targets_now(op)` with `cost_fit = 1` and `preference` looked up by op names; identical `ops[]` collapse to the lowest index; and a Choice raised for the boss during the player's turn is answered by the same `choose` entry point and returns to `Idle`.

---

## Implementation Notes

*Derived from ADR-0006 / ADR-0008 Decisions and GDD C7:*

- Files: `src/ai/chooser.gd` (`class_name Chooser extends RefCounted`, `static func choose(sandbox, request, profile, op_values, ai_stream, db) -> {index, diagnostic}`); `BossAI.choose(engine, request) -> int` wraps it and records the `ai_decision {kind: choice, chosen, alternatives[≤3]}` into the current plan's diagnostics (inside `plan_turn`) or returns it alongside the index for the driver's choose task (ADR-0008 Decision 3).
- Collapse identical options (same `def_id`, or identical `ops[]`) **before** Story 006's tie-break so no draw is consumed; a single remaining option returns immediately with one alternative.
- Inside `plan_turn`: after each `submit`, `while sandbox.phase == Choice and pending_choice.side == BOSS: sandbox.submit(choose(...))` before planning the next action; the sandboxes used for scoring auto-answer their own Discovers the same way (C4).
- `op_value` and `targets_now` come from Story 005's `CandidateSet`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 014: the driver's `choose` task scheduling and main-thread submit.
- Story 005: the `op_value` table and target counting.

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/ai/chooser.gd`
- `src/ai/boss_ai.gd` (`choose` entry point)
- `tests/unit/boss_ai/boss_ai_choose_test.gd`
- `tests/fixtures/boss_ai/discover_duplicate_options.json`, `tests/fixtures/boss_ai/choose_one_options.json`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/boss_ai/boss_ai_choose_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/boss-ai-match-driver/story-005-candidates-hero-power-rule-and-positions.md`, `production/epics/boss-ai-match-driver/story-006-tie-break-and-stream-draws.md`
- Unlocks: `production/epics/boss-ai-match-driver/story-014-match-driver-phase-schedule.md`
