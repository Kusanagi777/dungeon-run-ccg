# Story 018: Performance budgets: submit and legal_commands

> **Epic**: Match Rules
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/match-rules.md` (Game Feel — Input Responsiveness table; Acceptance Criteria AC-40)
**Requirement**: `TR-match-rules-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Effect Resolver / Validator Boundary (Performance: `submit()` ≤ 5 ms worst case incl. resolver passes; `legal_commands()` ≤ 2 ms with `targeting_spec` memoised per `def_id`; `clone()` measured by the sim harness); also ADR-0001 (the budgets are the rules tier's), ADR-0005 (hook fold < 0.05 ms, ≤ 12 entries), ADR-0009 (the UI's 50 ms command-to-first-visual budget rides on this)
**ADR Decision Summary**: The engine is pure logic measured headless: a worst-case `submit` (50-step Deathrattle chain) completes in 5 ms, `legal_commands()` in 2 ms, a 12-entry hook fold in 0.05 ms. Timing is not deterministic, so these are a performance job with a 2× regression gate, not blocking unit assertions.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: HIGH by version. `Time.get_ticks_usec()` is the timer (pre-4.3, unchanged). Headless CI runs on a shared runner — the GDD names "the reference machine named in the Game Feel budget"; numbers from CI are indicative and the 2× gate is what fails the job. `NOT SOURCEABLE — frame pacing under a live task` belongs to ADR-0008; this story measures the engine alone.

Match Rules is the project's first bottleneck: seven systems call `submit` and the Boss AI calls `legal_commands()` per look-ahead node. The budgets exist so the UI never shows a "thinking" delay for the player and so the planner's 50 ms p95 (A22) is reachable. This story builds the worst-case fixture and the timing harness; it is the last story because it measures everything before it.

**Control Manifest Rules (this layer)**:
- Required: `RulesEngine` owns … the C10 loop … `RESOLUTION_STEP_CAP` (ADR-0007); `targeting_spec` memoised per `def_id` (ADR-0007)
- Forbidden: never allocate in the fold — no `duplicate()` of entries, no arrays built per invocation (ADR-0005); `tests/unit/**` and the sim harness never start a worker (ADR-0006)
- Guardrail: `RulesEngine.submit()` ≤ 5 ms worst case (50-step Deathrattle chain, includes resolver passes); `legal_commands()` ≤ 2 ms; hook fold — 12-entry fold < 0.05 ms, three treasures add < 2 ms per match, ≤ 12 entries per match (`entry_count()` asserted in debug); `clone()` + empty resolver memo per look-ahead node against `planner_target_ms` 50 p95 (ADR-0007, ADR-0001, ADR-0005)

---

## Acceptance Criteria

*From GDD `design/gdd/match-rules.md`, scoped to this story:*

- [ ] AC-40 (*performance test*, `tests/performance/match_rules/`, not part of the blocking unit suite — timing is not deterministic) **GIVEN** a match with a 7-minion Deathrattle chain (each Deathrattle summons a Deathrattle minion and damages the board — a ≥ 50-step chain under the cap), **WHEN** `submit` is timed over 100 iterations (fresh `clone()` per iteration so each run is the worst case), **THEN** the median is under 5 ms on the reference machine; a regression above 2× the budget (10 ms median) fails the performance job; the measured median, p95 and max are printed in the test output and recorded in `production/qa/perf-match-rules-<date>.md`.
- [ ] AC-40 / Input Responsiveness **GIVEN** a full board (7 v 7, 10-card hand with two required-target spells, hero power usable, Windfury attacker), **WHEN** `legal_commands()` is timed over 100 iterations, **THEN** the median is under 2 ms and the returned list is identical on every iteration (no allocation-dependent order); a regression above 2× (4 ms) fails the job.
- [ ] ADR-0005 guardrail **GIVEN** 12 installed value entries on `modify_damage`, **WHEN** `hooks.fold` is timed over 1,000 iterations, **THEN** the median is under 0.05 ms; `entry_count()` is 12 and installing a 13th host trips the debug assertion; a `clone()` of that match copies ≤ 12 entries (`copy()` call count or `entry_count()` equality) — the `entry_count` / assertion half is deterministic and lives in the blocking unit suite (`tests/unit/match_rules/match_rules_hook_fold_budget_test.gd`).

---

## Implementation Notes

*Derived from ADR-0007 Performance, ADR-0005 Decision 4 / Implementation Guidelines and GDD AC-40:*

- Harness: `tests/performance/match_rules/match_rules_perf_test.gd`, a gdUnit4 suite that builds the worst-case fixture through the scripted resolver double (the Deathrattle chain is scripted, so no Card Effects code is needed), times with `Time.get_ticks_usec()` around `engine.submit(cmd)` / `engine.legal_commands()`, collects 100 samples, and asserts `median < 2 × budget` (the gate) while **printing** median / p95 / max against the budget (the target). Budgets come from `project.yaml` performance budgets / `rules_config`, never literals.
- Suite placement: the GDD and `.claude/rules/test-standards.md` ("performance tests must specify acceptable thresholds and fail if exceeded") put this under `tests/performance/`. **`commands.test` runs `-a res://tests`, which would include it in the blocking run** — either add `tests/performance/` to a gdUnit4 ignore for `commands.test` and give CI a separate `performance` job, or keep the 2× gate loose enough to hold on CI runners. Decide at `/dev-story` with `tests/README.md` updated; the GDD's intent is "a regression above 2× fails the performance job", not the unit job.
- Deathrattle chain fixture: 7 minions whose scripted Deathrattle each (a) `summon_minion` a token with the same Deathrattle, (b) `apply_damage(each enemy minion, 1)`; with `RESOLUTION_STEP_CAP` at its default (1000) the chain runs ≥ 50 steps and stops when boards stabilise. Use one `clone()` per iteration so the measured `submit` is always the first swing.
- `legal_commands()` fixture: the resolver double's `targeting_spec` memo is warm (call once before timing — ADR-0007 memoises per `def_id` in the resolver; a cold first call is allowed to exceed).
- Record results in `production/qa/perf-match-rules-<date>.md` (machine, Godot build, medians) — `/perf-profile` reads it later.
- Optimisation guidance if the budget is missed: the queue `pop_front`, `_candidates_in_order()` allocation per trigger point, and `effective_cost` per hand card are the expected hot spots; never fix by caching derived values on the records (C1).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- boss-ai-match-driver epic: main-thread ≤ 2 ms per frame, planner 50 ms p95, `clone()` per look-ahead node in the sim harness
- match-ui epic: the 50 ms command-to-first-visual budget
- `/perf-profile`: ranked optimisation recommendations if the job fails

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `tests/performance/match_rules/match_rules_perf_test.gd`
- `tests/unit/match_rules/match_rules_hook_fold_budget_test.gd`
- `tests/helpers/test_effect_resolver.gd` (Deathrattle chain fixture)
- `tests/README.md` (performance suite section)
- `production/qa/perf-match-rules-<date>.md`
- `src/gameplay/match/rules_engine.gd` (only if a budget is missed)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/match_rules/match_rules_hook_fold_budget_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later). `qa.level: standard` — BLOCKING. The timing suite `tests/performance/match_rules/match_rules_perf_test.gd` must exist and its recorded medians in `production/qa/perf-match-rules-<date>.md` must be within 2× budget.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/match-rules/story-017-clone-and-replay.md`
- Unlocks: None (last story of the epic; `boss-ai-match-driver` and `match-ui` epics consume the budgets)
