# Story 016: Headless AI-vs-AI simulation harness (gate condition 6)

> **Epic**: Boss AI + Match Driver
> **Status**: In Review
> **Layer**: Core
> **Type**: Integration
> **Estimate**: L
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/boss-ai.md` (C11, A22, A23, A28, F7, Edge Cases "If two seeded runs diverge") · `design/gdd/content.md` AC-13 (per-floor boss win rate basis, D-07)
**Requirement**: `TR-boss-ai-006`, `TR-boss-ai-003` (A22 measurement)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Boss AI Planner Threading (harness uses `ImmediatePlannerTask`, never a worker; A22 measured inside the task); ADR-0008 (Decision 11: the harness builds its drivers through the same `driver_factory` and submits through `driver.submit`, ticking until `is_planning()` is false)
**ADR Decision Summary**: The harness runs N seeded matches of a boss against a hero-script (a second `BossAI` piloting a hero deck with the `default` profile) or boss vs boss, through two `MatchDriver`s built by the real factory with `ImmediatePlannerTask`, and writes `production/qa/sim/<boss_id>_<date>.json` with win rate, mean turns, mean final health, decision count, planner time p50/p95 and rejected-command count (must be 0). It is deterministic per seed. Gate condition 6 ("headless AI-vs-AI harness deterministic per seed") closes here.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH / NOT SOURCEABLE
**Engine Notes**: Runs under `godot --headless -s` (gdUnit4 suite) or as a standalone `--script` with `--boss`/`--seeds` args (`OS.get_cmdline_user_args()` — pre-4.4 API, LOW). Headless frame pacing is irrelevant: `ImmediatePlannerTask` completes inside `start()`. A22 timing with `Time.get_ticks_usec()` inside the task (NOT SOURCEABLE, LOW). `FileAccess.store_string` returns `bool` on 4.4+ (sourced) — check it when writing the JSON. JSON floats: write planner ms as numbers, seeds as decimal strings if > 2^53 (ADR-0003 hex rule for 64-bit values).

**Control Manifest Rules (this layer)**:
- Required: `MatchDebugLoader` and the boss-ai sim harness build their driver through the same `driver_factory` with `ImmediatePlannerTask`, submit through `driver.submit`, and `tick()` until `is_planning()` is false. `tests/unit/**` and the sim harness never start a worker.
- Forbidden: Never a second driver shape or hand-built state; never run `play_turn` against the live engine on a worker.
- Guardrail: Boss AI worker 500 ms p95 target per planner run (A22; `play_turn` and `forecast` each); `clone()` + empty resolver memo per look-ahead node measured by the sim harness against `planner_target_ms` 500 p95 (2026-11-04, DD-X18); was 50 ms p95 per turn.

---

## Acceptance Criteria

*From GDD `design/gdd/boss-ai.md` A22, A23, A28 and ADR-0008 Decision 11, scoped to this story:*

- [ ] **A28** GIVEN the harness, WHEN run with `--boss boss_x --seeds 100`, THEN it writes `production/qa/sim/boss_x_<date>.json` with `win_rate`, `mean_turns`, `mean_final_health`, `decision_count`, `p50_planner_ms`, `p95_planner_ms`, `rejections = 0` and the per-floor boss win rate (C11 / content AC-13 basis), and a second run with the same seeds produces an identical file (timestamp field excluded from the comparison or fixed by seed); on divergence it prints the first differing `ai_decision` payload (Edge Cases).
- [ ] **A23** GIVEN 1,000 seeded matches (mixed bands, boss vs hero-script), WHEN complete, THEN zero `command_rejected` events have `side = boss`, zero `ai_fault`, zero `resolution_overflow`, and every match ends by `hero_dead` or `turn_cap`.
- [ ] **A22** GIVEN the harness at band 3 budgets on the target machine (headless, release template), WHEN 200 seeded matches run, THEN planner time per planner run (measured inside the task, reported separately for `play_turn` and for `forecast`) is p95 ≤ 500 ms for each, and the match's total `ai_decision` events are ≤ 400; a miss is reported with the F7 note that band 3's counts are lowered until A22 passes (2026-11-04, DD-X18); was p95 ≤ 50 ms per round of one `forecast` plus one `play_turn`.
- [ ] GIVEN the harness, WHEN it builds a match, THEN both sides' drivers come from the injected `driver_factory` with `ImmediatePlannerTask`, every command goes through `driver.submit`, `tick()` is called until `is_planning()` is false and no plan is pending, no `WorkerThreadPool` task is ever started, and the retained outputs for the five MVP bosses exist under `production/qa/sim/` (Definition of Done).

---

## Implementation Notes

*Derived from ADR-0006 / ADR-0008 Implementation Guidelines and GDD C11:*

- Files: `tests/integration/boss_ai/sim_harness.gd` (`class_name BossAiSimHarness extends RefCounted`: `run(boss_id, seeds: Array[int], opponent: {hero_id | boss_id}, out_dir) -> Dictionary`), `tests/integration/boss_ai/boss_ai_sim_harness_test.gd` (the gdUnit4 suite: A28 identical-file with a small seed list, A23 on a CI-sized sample with the full 1,000 behind an env flag, A22 recorded as ADVISORY in CI — the "target machine, release template" measurement is Story 018's Windows run and the owner's machine), `tools/sim.sh` (wraps `godot --headless -s tests/integration/boss_ai/sim_harness.gd -- --boss X --seeds N`).
- Hero-script: a second `BossAI` with the `default` profile piloting the hero deck; the player side is still "player" to the engine — the harness stamps `issuer` by calling each driver's `submit` for the human seat and letting the boss seat plan through the driver. Boss vs boss runs two drivers in lock-step: forecast / plan tasks on each, replayed through `tick()`.
- `production/qa/sim/` is versioned; add it to `production/.gdignore` scope if not already covered so Godot never imports the JSON.
- Determinism: everything flows from `run_seed` through `RngService`; the file's `generated_at` is the only non-deterministic field — write it but exclude it from the A28 comparison, or omit it.
- Planner time p50/p95 are measured inside `ImmediatePlannerTask.start()` around `work.call()`; report `planner_target_ms` from `ai_profiles.json` Tuning Knobs beside them.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 017: the three-implementation determinism comparison (worker vs time-sliced vs immediate).
- Story 018: A22 / A30 on the Windows export and the owner's machine.
- `content` epic: AC-13 tuning passes using this harness.
- `/balance-check`: reading the output.

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `tests/integration/boss_ai/sim_harness.gd`
- `tests/integration/boss_ai/boss_ai_sim_harness_test.gd`
- `tools/sim.sh`
- `production/qa/sim/boss_rat_king_<date>.json`, `boss_gatekeeper_<date>.json`, `boss_torchbearer_<date>.json`, `boss_rot_warden_<date>.json`, `boss_hollow_king_<date>.json` (retained outputs)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/boss_ai/boss_ai_sim_harness_test.gd` — required; plus the retained `production/qa/sim/*.json` for the five MVP bosses (Definition of Done)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/boss-ai-match-driver/story-003-ai-profiles-mvp-data.md`, `production/epics/boss-ai-match-driver/story-009-defensive-mode-and-sandbox-fidelity.md`, `production/epics/boss-ai-match-driver/story-014-match-driver-phase-schedule.md`, `production/epics/boss-ai-match-driver/story-015-match-driver-tick-replay-and-shutdown.md`; `content` epic batch 0 (five MVP boss decks) and `heroes` epic (War starter deck) for the real-data runs (cross-epic)
- Unlocks: `production/epics/boss-ai-match-driver/story-017-planner-determinism-across-implementations.md`, `production/epics/boss-ai-match-driver/story-018-windows-planner-a30-and-determinism.md`
