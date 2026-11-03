# Story 002: AnimStep and AnimationQueue — command groups, coalescing, F3 speed, skip-all and the idle invariant

> **Epic**: Match UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

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

- [ ] **L5** GIVEN four `minion_died` events sharing one `cause_seq`, WHEN projected and enqueued, THEN exactly one `death_group` step and one `gap_close` step are played, in that order, and no step of a later group starts before them.
- [ ] **L6** GIVEN a queue holding the steps of a 30-event burst (and, for timing, a recorded 300-step stream), WHEN `skip_all()` is invoked after step *k* for every *k* in 0..30, THEN after the flush every presenter-facing value (a fake presenter's `sync_report()`) equals the view-state, every `apply_final` ran exactly once in `seq` order, `skipped` was emitted once, and the 300-step flush completes in ≤ 100 ms.
- [ ] **L7** GIVEN `anim_speed = fast` (`SPEED_DIV` 2.0), WHEN `d_eff` is computed for every base duration in `match_ui.json`, THEN each equals `d_base / 2` and hit-stop / shake / slow-down extras are 0; GIVEN `normal`, THEN each equals `d_base`; GIVEN `instant`, THEN 0 with `apply_final` only; GIVEN `reduce_motion = true` at `normal`, THEN extras are 0 and base durations unchanged.
- [ ] **L11** GIVEN a command group with 10 `damage_dealt` on distinct targets from one source, WHEN steps are enqueued, THEN they coalesce into one simultaneous pop step; GIVEN 7, THEN seven steps (`COALESCE_THRESHOLD` read from config, 8).

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

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/match_ui/animation_queue_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/match-ui/story-001-match-view-state-projection.md`; `production/epics/boot-composition-root/story-001-settings-bus.md`
- Unlocks: `production/epics/match-ui/story-004-match-view-skeleton-and-fixture-loader.md`, `production/epics/match-ui/story-010-boss-turn-pacing.md`
