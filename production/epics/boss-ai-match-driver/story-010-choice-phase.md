# Story 010: Choice phase — `choose` for Discover and choose_one

> **Epic**: Boss AI + Match Driver
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-04
> **Readiness**: READY (2026-11-04, by hand: stories 005 and 006 Complete; ADR-0006 and ADR-0008 Accepted; manifest 2026-11-03 to 2026-11-04 adds no rule for this story; the boss-ai A24 / A16 `alternatives` gap is settled for `kind: choice` by A16 and the Edge Case)

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

- [x] **A16** GIVEN a Discover with options [2-cost, 2-cost identical, 7-cost] and `mana_max = 4`, WHEN the boss chooses, THEN index 0 is picked, no `ai_<floor>` draw is consumed, and the `ai_decision {kind: choice}` lists 2 alternatives (duplicates collapsed to the lowest index before tie-breaking).
- [x] GIVEN a `ChoiceRequest {kind: discover}`, WHEN scored, THEN each option scores `op_value(option) × cost_fit + preference` with a vanilla body valued as `buff` at `(attack + health) / 4`, `cost_fit = 1` if the option's cost ≤ next turn's `mana_max` else 0.5, and `preference` from the profile's `choice_preference` for the option's tags (aggro `charge`/`weapon`, control `taunt`/`heal`/`damage_all`, tempo lowest cost, passive_driven its `synergy_tags`).
- [x] GIVEN a `ChoiceRequest {kind: choose_one}` (options `{label_key, ops[]}`), WHEN scored, THEN each option scores `Σ op_value(op) × targets_now(op)` with `cost_fit = 1` and `preference` looked up by op names; identical `ops[]` collapse to the lowest index; and a Choice raised for the boss during the player's turn is answered by the same `choose` entry point and returns to `Idle`.

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

- `src/ai/chooser.gd` (new)
- `src/ai/boss_ai.gd` (`choose` entry point, `last_choice`, C1.1 `_init`)
- `src/ai/candidates.gd` (`card_value` extracted from `op_value`, `ops_value`)
- `src/ai/scorer.gd` (trials answer Choices with `Chooser`; `cost_fit` normalisers; optional `op_values` argument; `sim_choice_placeholder` removed)
- `src/ai/lethal_search.gd` (nodes answer Choices with `Chooser`)
- `tests/unit/boss_ai/boss_ai_plan_turn_test.gd` (NC-8 byte-identical plan), `tests/unit/boss_ai/boss_ai_scorer_test.gd` (dead placeholder check removed)
- `tests/unit/boss_ai/boss_ai_choose_test.gd` (new)
- `tests/fixtures/boss_ai/discover_duplicate_options.json`, `tests/fixtures/boss_ai/choose_one_options.json` (new)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/boss_ai/boss_ai_choose_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] Created — 30 tests, passing (see Completion Notes for the merged full suite, 2026-11-04)

---

## Dependencies

- Depends on: `production/epics/boss-ai-match-driver/story-005-candidates-hero-power-rule-and-positions.md`, `production/epics/boss-ai-match-driver/story-006-tie-break-and-stream-draws.md`
- Unlocks: `production/epics/boss-ai-match-driver/story-014-match-driver-phase-schedule.md`

---

## Completion Notes
**Completed**: 2026-11-04 (start 19:34 UTC, end 19:49 UTC; sprint 5 lane 2 wave 1, branch `s5/l2-w1`)
**Criteria**: 3/3 passing, with one open data question on the passive_driven clause (below). A16 `test_a16_duplicates_collapse_and_the_cheap_option_wins_with_no_draw`; Discover score, `cost_fit` and one preference case per profile; Choose One score, op-name preference, collapse, and `test_a_boss_choice_raised_on_the_players_turn_returns_to_the_players_main`.
**Failing first**: all 23 tests were seen failing against missing code (`Chooser` undeclared, `BossAI.new` and `Scorer.new` taking no such arguments). Nine deliberate mutants were then each killed: collapse off, `cost_fit` strict, no crystal bonus, no type tag, no `damage_all`, no `low_cost`, no side guard, pick not first, scorer left on the placeholder.
**Verification**: import exit 0; `gates.sh`, `no_global_rng.sh`, `parse-check.sh` pass; `commands.test` 1433 test cases, 0 errors, 0 failures, 0 orphans, exit 0; `commands.smoke` exit 0, no `SCRIPT ERROR`.
**Run result**: N/A: nothing reaches the screen until the match driver runs a boss turn.
**Deviations** (advisory):
- `BossAI.choose` returns the index alone (GDD C1.4, ADR-0008 `-> int`). The story's "returns it alongside the index" is met by `BossAI.last_choice`, which `plan_turn` and story 014's `choose_task` read. GDD over story.
- Lane 2's own `BossAI._init` was dropped at the BAI-008 join: Lane 1's `_init(boss_def, resolved_profile, band, ai_stream, op_values, log, db, keyword_values)` stands, and now also keeps `op_values`.
- `src/ai/candidates.gd` and `src/ai/scorer.gd` are outside the story's planned Files. The Implementation Notes ask for `CandidateSet`'s values and for scoring sandboxes to answer with `choose`, and `scorer.gd` assigned that to this story. `Scorer.NORMALISERS` gained `cost_fit_full` and `cost_fit_over` for A29.
- `alternatives` for a choice counts the pick (A16, Edge Case), through Lane 1's `Scorer.alternatives(scored, chosen)`: best first, the pick always listed. A24's empty list stays the `kind: action` rule.
- `sim_choice_placeholder` is gone with the option 0 answers, so `boss_ai_scorer_test.gd`'s `_assert_no_sandbox_choice` (5 calls), which only read that flag, was removed. A scorer built without `op_values` values every op at the C6 fallback row; `BossAI` always passes them.

**Readings of C7** (the GDD names these tags but does not define them; none adds a number):
- An option's tags are C6 `synergy_match`'s fields plus its `type` (`weapon`) and op names (`heal`). No shipped card carries these as `tags`.
- `damage_all` names no op in the C5 table: read as a `damage` op on C6's area selectors, for Discover and Choose One.
- `low_cost` goes to every option of the lowest cost among those offered, after the collapse. A Choose One option has no cost, so never.
- Several matching tags sum, each distinct tag once.

**Open**:
- **passive_driven has no preference amount.** C7 says its preference comes from its `synergy_tags`, but F9 gives `passive_driven` and `boss_rot_warden` no `choice_preference` row, and the amount is not defined anywhere. The code reads `choice_preference` for those tags, so shipped passive_driven bosses score a preference of 0 until a row is added; no number was invented. The owner decides whether to ship one.
- A Choose One op with no `targets` of its own counts one target, because the request does not carry the offering effect's `targets`. Shipped `neutral_smite_or_mend` uses `chosen`, so it is unaffected.

**BAI-008 join** (2026-11-04, start 21:55 UTC, end 22:14 UTC; full suite 1624 test cases, 0 errors, 0 failures, smoke exit 0; merged trunk `f96fc04`, not rebased): `plan_turn`, `LethalSearch` and `Scorer` all answer Choices with `Chooser`; no option 0 answer remains in `src/ai/`. The root sandbox draws a tie from the live `ai_<floor>` stream, counted in `TurnPlan.ai_draws`; a trial or search node draws from its own `rng_match()`, its copy of the `sim_<turn>` fork. QA's "`choose` inside a plan" case is closed by the plan and lethal tests in `boss_ai_choose_test.gd`; NC-8's byte-identical plan by `test_a_plan_is_byte_identical_at_either_end_of_the_planner_target_range`. New tests were seen failing against the option 0 answers, except two that cannot fail there: the NC-8 test failed on a mutant feeding the knob into the budgets, the node-stream test on a mutant drawing from the fork. Lane 3's new `heroes_fixture_hero/ai_profiles.json` gained the required `planner_target_ms` key.
**Test Evidence**: `tests/unit/boss_ai/boss_ai_choose_test.gd`
**Reviewed by**: independent review 2026-11-04 (`production/reviews/2026-11-04/code-review-s5-w1-bossai.md`): **APPROVED WITH SUGGESTIONS**, 0 required; the `planner_target_ms` knob (`631a7ae`), which landed with this story, **APPROVED WITH SUGGESTIONS**. D-4 must be fixed before story 016. DQ-4 is open.
