# Story 002: AnimStep and AnimationQueue — command groups, coalescing, F3 speed, skip-all and the idle invariant

> **Epic**: Match UI
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-03

## Context

**GDD**: `design/gdd/match-ui.md` U4 (rules 1–8), F3 (effective duration, `SPEED_DIV`)
**Requirement**: `TR-match-ui-002` (also `TR-match-ui-005`, skip row)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009: Match UI Animation Queue, Tween Approach and Scene Partition (Decision §1–2)
**ADR Decision Summary**: The `AnimationQueue` is a `RefCounted` scheduler that owns *timing* only: FIFO by command group, `parallel_ok` steps start with the previous step, > `COALESCE_THRESHOLD` pops coalesce, `d_eff = 0 if skipped or instant else d_base / SPEED_DIV[anim_speed]`, and every step ends when the queue's clock calls `apply_final`; `skip_all()` runs the rest in order within one frame.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (UI + Animation 4.5–4.7 by version; this story is Node-free — `RefCounted` and `signal` only)
**Engine Notes**: Never `await`, `Timer` nodes or `Engine.time_scale` (ADR-0009). The queue never creates a `Tween`; it emits `step_started(step, d_eff)`, `step_finished`, `drained`, `skipped`. A step whose presenter never responds still ends at `d_eff` (ADR-0009 verification item 2 — `tween_await` timeout semantics are NOT SOURCEABLE, so the clock is authoritative).

**Control Manifest Rules (this layer)**:
- Required: The queue schedules, presenters tween; every step ends when `advance(delta)` calls `step.apply_final` (idempotent). Groups FIFO; `parallel_ok` with the step before; > 8 pops on distinct targets from one source coalesce; impact extras are queue-local clock multipliers dropped at `fast` or `reduce_motion`.
- Forbidden: Never let the queue own the tweens or end a step on `Tween.finished`. Never hardcoded setting defaults.
- Guardrail: Skip-all → display = view-state ≤ 100 ms (300-step stream); `advance(delta)` O(active steps).

---

## Acceptance Criteria

*From GDD `design/gdd/match-ui.md` Acceptance Criteria (Logic):*

- [x] **L5** GIVEN four `minion_died` events sharing one `cause_seq`, WHEN projected and enqueued, THEN exactly one `death_group` step and one `gap_close` step are played, in that order, and no step of a later group starts before them.
- [x] **L6** GIVEN a queue holding the steps of a 30-event burst (and, for timing, a recorded 300-step stream), WHEN `skip_all()` is invoked after step *k* for every *k* in 0..30, THEN after the flush every presenter-facing value (a fake presenter's `sync_report()`) equals the view-state, every `apply_final` ran exactly once in `seq` order, `skipped` was emitted once, and the 300-step flush completes in ≤ 100 ms.
- [x] **L7** GIVEN `anim_speed = fast` (`SPEED_DIV` 2.0), WHEN `d_eff` is computed for every base duration in `match_ui.json`, THEN each equals `d_base / 2` and hit-stop / shake / slow-down extras are 0; GIVEN `normal`, THEN each equals `d_base`; GIVEN `instant`, THEN 0 with `apply_final` only; GIVEN `reduce_motion = true` at `normal`, THEN extras are 0 and base durations unchanged.
- [x] **L11** GIVEN a command group with 10 `damage_dealt` on distinct targets from one source, WHEN steps are enqueued, THEN they coalesce into one simultaneous pop step; GIVEN 7, THEN seven steps (`COALESCE_THRESHOLD` read from config, 8).

---

## Implementation Notes

*Derived from ADR-0009 Implementation Guidelines and Key Interfaces:*

- `src/ui/match/animation_queue.gd` — `class_name AnimationQueue extends RefCounted`: `_init(ui_config: Dictionary, settings: Dictionary)`, `enqueue`, `advance(delta)`, `skip_all`, `is_idle`, `set_speed`, `set_reduce_motion`; `enter_boss_turn` / `exit_boss_turn` are stubs here (Story 010 fills them). Signals as ADR-0009 Key Interfaces.
- `AnimStep` gains `parallel_ok` and `impact: Dictionary` (`{hit_stop_ms, shake_ms, slow_ms}`).
- Coalescing happens at enqueue time over the open group: pops with the same source and distinct targets beyond the threshold collapse into one step whose `apply_final` calls each original `apply_final` in `seq` order.
- `skip_all()`: emit `skipped` first (presenters kill tweens), then run remaining `apply_final`s in order in the same call, drop queued SFX ids, clear impact clocks; it must not recompute layout per step (ADR-0009 Risks — one layout pass at the end, done by presenters on `drained`).
- Tests use a fake clock (call `advance()` with fixed deltas) and a fake presenter recording `apply_final` order; no Node, no scene.
- Speed and `reduce_motion` come from the settings dictionary built from `SettingsBus` (Boot epic); session defaults from `config("profile_defaults")` — never literals.

---

## Out of Scope

- Story 010: boss-turn mode, F4 gap and `k`, auto-skip at `K_MIN`.
- Story 023: the visual side of hit-stop, shake and lethal slow-down (presenters).
- Story 003: `MatchController.submit` calling `skip_all()` first (U4.7).

---

## Files

- `src/ui/match/animation_queue.gd`
- `src/ui/match/anim_step.gd`
- `tests/unit/match_ui/animation_queue_test.gd`
- `tests/helpers/match_ui/fake_presenter.gd`
- `tests/performance/match_ui/animation_queue_perf_test.gd` (added: L6's 300-step ≤ 100 ms clause, non-blocking perf suite)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/match_ui/animation_queue_test.gd` — must exist and pass

**Status**: [x] Created — `tests/unit/match_ui/animation_queue_test.gd` (15 tests); timing half in `tests/performance/match_ui/animation_queue_perf_test.gd`

---

## Dependencies

- Depends on: `production/epics/match-ui/story-001-match-view-state-projection.md`; `production/epics/boot-composition-root/story-001-settings-bus.md`
- Unlocks: `production/epics/match-ui/story-004-match-view-skeleton-and-fixture-loader.md`, `production/epics/match-ui/story-010-boss-turn-pacing.md`

---

## Completion Notes
**Completed**: 2026-11-03 (started 23:33:36 UTC, ended 23:39:32 UTC)
**Criteria**: 4/4 passing — L5 (`test_four_deaths_sharing_a_cause_play_one_death_group_then_one_gap_close_before_the_next_group`: the full start/finish timeline, a later group's `draw` only after `gap_close` finished), L6 (`test_skip_all_after_every_step_k_syncs_the_presenter_and_runs_each_final_once_in_seq_order` over k = 0..30 on a 30-event burst of 24 steps, k > 24 being skip-on-empty; plus `test_the_burst_out_of_sync_before_playback_and_in_sync_once_drained`, `test_skip_all_emits_skipped_before_any_final_and_drained_after`, `test_skip_all_on_an_idle_queue_emits_skipped_once_and_no_drained`; the 300-step ≤ 100 ms clause is `tests/performance/match_ui/animation_queue_perf_test.gd` — measured 2,217 us), L7 (`test_effective_durations_follow_f3_for_every_base_duration_and_speed` over every `d_base` key × normal / fast / instant / reduce_motion, `test_fast_halves_playback_on_the_fake_clock`, `test_instant_runs_apply_final_only`, `test_set_speed_and_set_reduce_motion_apply_to_later_steps`), L11 (`test_ten_pops_on_distinct_targets_from_one_source_coalesce_into_one_step`, `test_pops_up_to_the_threshold_play_one_by_one` (7 and 8), `test_one_pop_beyond_the_threshold_coalesces_and_the_threshold_is_read_from_config` (threshold 4 → 4 and 1), `test_pops_from_different_sources_or_groups_never_coalesce`). Also `parallel_ok` and `run_final` idempotence. Watched fail: 14 of 15 against a stub queue (`run_final` idempotence passed because `AnimStep` was written first); 13 mutants all caught — no parallel start, skip runs pending before active, `>=` threshold, no coalescing, no `skipped`, skip drops finals, extras kept at fast, `reduce_motion` ignored, no divisor, `step_started` at instant, `drained` on an idle skip, out-of-order finishing, non-idempotent `run_final`.
**Deviations** (advisory):
- **Edge cases the QA plan said to flag**: the threshold is strict ("more than `COALESCE_THRESHOLD`", U4.3 / ADR-0009) — 8 pops are 8 steps, 9 coalesce; `skip_all()` on an idle queue emits `skipped` exactly once and no `drained` (the story was silent; L6's "skipped emitted once for every k" includes the k past the last step).
- **Ordering**: a `parallel_ok` step starts with the step before it but its `apply_final` waits for that step's, so every final runs in `seq` order (L6) even when the parallel step is shorter; its tween still lasts its own `d_eff`.
- **Instant**: no `step_started` is emitted at `instant` (AC "apply_final only"); `step_finished` still is.
- **Impact extras**: `AnimStep.impact` is set by Story 023 (the projection attaches none yet). The queue keeps them only at `normal` without `reduce_motion`, scaled by the `normal` divisor; hit-stop and slow-down lengthen the step's hold on the queue clock, shake does not. The config key `impact_ms {hit_stop, hit_stop_heavy, shake, slow}` is a fixture-body name pending content 001's `match_ui.json`.
- **API additions** beyond ADR-0009 Key Interfaces: `effective_duration(step)` and `effective_impact(step)` (F3, public for L7), `AnimStep.run_final()` / `final_ran()` (the idempotent guard the queue calls; `apply_final` is a zero-argument `Callable` with the step bound in) and `AnimStep.members` (coalesced originals).
- An unknown `anim_speed` label is reported (`push_error`) and plays as `instant` — the display stays correct; no default label is invented.
- No SFX exist yet, so "drop queued SFX ids" has nothing to drop; `enter_boss_turn` / `exit_boss_turn` are documented no-ops (Story 010).
- The perf suite file is new under `tests/performance/match_ui/` (QA plan Cross-cutting 2), outside the story's `## Files` list as written.
**Test Evidence**: `tests/unit/match_ui/animation_queue_test.gd` (15 tests) + `tests/helpers/match_ui/fake_presenter.gd`; full suite 846 test cases, 0 failures, exit 0, 45 SCRIPT ERROR lines (baseline intentional negatives, unchanged from story 001; none from match_ui); smoke exit 0, no SCRIPT ERROR; perf suite exit 0 (`PERF match_ui skip_all x300 steps: 2217 us (budget 100000 us)`); `tools/lint/gates.sh` PASS.
**Run result**: N/A — the story adds a Node-free `RefCounted` scheduler driven by a fake clock; nothing renders until Story 004's `MatchView` and presenters exist.
**Reviewed by**: self, no independent review (LP-CODE-REVIEW skipped — Lean mode; QL-TEST-COVERAGE skipped — Lean mode)
