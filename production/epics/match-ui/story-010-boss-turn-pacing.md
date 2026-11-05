# Story 010: Boss-turn pacing — F4 gap and compression, boss-turn mode and control lock

> **Epic**: Match UI
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-04

## Context

**GDD**: `design/gdd/match-ui.md` U6 (rules 1–6), F4 (gap and compression), States (`BossTurn`)
**Requirement**: `TR-match-ui-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009 (Decision §2, boss-turn mode); ADR-0008 (`tick()` replay drives the burst into the log); ADR-0003 (events delivered synchronously, in order)
**ADR Decision Summary**: Boss-turn mode is entered on `turn_started{side: boss}` and exited when `turn_started{side: player}` has drained; the commit beat plays first; F4's `gap` and `k` are computed when the first action group would start over the groups then queued; later groups reuse that `gap`; the remainder auto-skips if the total would exceed `max_turn_playback_s`.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (by version; Node-free logic)
**Engine Notes**: ADR-0006 may replay a plan across a few ticks; the "computed at first group" rule makes a partial burst less compressed, never wrong. No `Engine.time_scale`, no `await`.

**Control Manifest Rules (this layer)**:
- Required: Boss-turn mode as above; `anim_speed`, `action_delay_ms` from `SettingsBus`; pacing knobs from Boss AI data (`presentation.action_delay_s`, `max_turn_playback_s`, `intent_banner_s`) and `config("match_ui")` (`MIN_ACTION_GAP_S`, `K_MIN`).
- Forbidden: Never hardcoded setting defaults.
- Guardrail: the queue holds at most one boss turn of steps (≤ 30 groups).

---

## Acceptance Criteria

*From match-ui Acceptance Criteria L8, L16 and U6:*

- [x] **L8** GIVEN a boss turn with A = 12 groups and D = 7.0 s at defaults, WHEN F4 runs, THEN gap = 0.245 s (±0.001) and T = 10.0 s; GIVEN A = 30, D = 15 s, THEN gap = 0.15, k = 0.509 (±0.001) and the turn plays in 10.0 s; GIVEN A = 5, D = 2.5 s, THEN gap 0.6 and T = 5.2 s.
- [x] **L16** GIVEN `settings.action_delay_ms = 1200` and a boss turn with A = 5, D = 2.5 s, WHEN F4 runs, THEN gap = 1.2 s and T = 7.6 s; GIVEN the setting absent, THEN gap = 0.6 s (Boss AI's `presentation.action_delay_s`).
- [x] GIVEN `turn_started{side: boss}` then a burst whose groups arrive over two ticks, WHEN the queue plays it with a fake clock, THEN the commit beat (`intent_banner_s`) plays before the first action group, the second tick's groups use the gap computed at the first group, the remainder auto-skips once `k = K_MIN` and the clock reaches `max_turn_playback_s`, player controls report locked (only skip, pause menu and feed allowed) until `turn_started{side: player}` has drained, and a boss-side Choice produces one 0.4 s "boss discovers…" step with no options.
- [x] **(2026-11-04, DD-X23 — commit beat over planning)** GIVEN End Turn at *t* and a `PlannerTask` fake that completes after *p* ms, WHEN the queue plays the boss turn with a fake clock, THEN the commit beat starts at *t* and the first action group starts at *t* + `max(intent_banner_s, p)` for *p* ∈ {100, 400} (300 ms and 400 ms). For *p* = 800 the beat ends at *t* + 500 (`planner_target_ms`), the "boss thinking" state shows from *t* + 500 until the plan arrives at *t* + 800, and the first group starts then. In every case F4's `gap` / `k` are computed with `intent_banner_s`; the stretch is planning time and does not count against `max_turn_playback_s` (match-ui U6.2, F4).

---

## Readiness (`/story-readiness`, by hand, 2026-11-04)

**READY, with four readings recorded here** (sprint 5 lane 8 wave 3). Tier: workflow standard. ADR-0003, ADR-0008 and ADR-0009 Accepted; stories 002, BAI-003 and BAI-015 Complete; `planner_target_ms` shipped in `ai_profiles.json` `runtime`. Advisory: the story embeds Manifest Version 2026-11-03, the manifest is 2026-11-04.

- **`MIN_ACTION_GAP_S` and `K_MIN`** are not in `match_ui.json`, but the GDD gives both (F4, Tuning Knobs: 0.15 and 0.25), so the keys ship here as `min_action_gap_s` and `k_min` (snake_case, DD-T01). The file joins this story's Files.
- **The lock wording:** the story's "skip, pause menu and feed" and U6.1's "skip, concede, settings, feed" agree, because the pause menu holds concede and settings.
- **"Boss discovers…"** needs a step kind and a `d_base` key the story does not list; the GDD gives 0.4 s (U6.6, Edge Cases).
- **"The plan has arrived"** is read from the log: the `ai_intent_committed` step, always the plan's first diagnostic (`BossAI._commit_intent`), so the queue stays free of the planner.

---

## Implementation Notes

- Fill `AnimationQueue.enter_boss_turn(pacing)` / `exit_boss_turn()` (Story 002 stubs); `MatchView` calls them from the projected `turn_started` steps.
- `ai_action_delay_s = settings.action_delay_ms / 1000` when present, else Boss AI's value read from `config("ai_profiles").presentation` (via the injected config, never parsed by the UI).
- Expose `InputRouter.controls_locked()` derived from view state + queue; Story 015 renders the lock (End Turn disabled, hand dim, skip hint).

---

## Out of Scope

- Story 015: intent banner rendering (including the "boss thinking" state), skip hint, hand dim, End Turn → commit beat measurement (`max(300 ms, planner run)` ≤ 500 ms — 2026-11-04, DD-X23; was ≤ 300 ms).

---

## Files

- `src/ui/match/animation_queue.gd`
- `src/ui/match/input_router.gd` (`controls_locked`)
- `src/ui/match/anim_step.gd`, `src/ui/match/match_view_state.gd` (the `boss_discovers` step)
- `assets/data/match_ui.json` (`min_action_gap_s`, `k_min`, `d_base.boss_discovers`)
- `tests/unit/match_ui/boss_turn_pacing_test.gd`
- `tests/unit/match_ui/match_view_state_projection_test.gd`, `tests/integration/match_ui/match_ui_shipped_config_test.gd`, `tests/helpers/match_ui/match_ui_test_config.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/match_ui/boss_turn_pacing_test.gd` — must exist and pass

**Status**: [x] Created and passing

---

## Dependencies

- Depends on: `production/epics/match-ui/story-002-animation-queue-core.md`; `production/epics/boss-ai-match-driver/story-003-ai-profiles-mvp-data.md` (`presentation.*` knobs), `production/epics/boss-ai-match-driver/story-015-match-driver-tick-replay-and-shutdown.md`
- Unlocks: `production/epics/match-ui/story-012-first-playable-windows-match.md`, `production/epics/match-ui/story-015-boss-intent-banner-and-boss-turn-view.md`

---

## Completion Notes
**Completed**: 2026-11-04 (start 04:25:33 UTC, end 05:29:42 UTC; sprint 5 lane 8 wave 3, branch `s5/l8-w3`)
**Criteria**: 4/4 in `boss_turn_pacing_test.gd` (41 cases, fake clock; `PlannerTask` fake from `tests/helpers/fake_planner_task.gd`; cap read from the shipped `planner_target_ms`). F4's numbers are asserted as formula and as played time. QA plan NC-7 cases covered, boundaries p = 300 and p = 500 included.
**Tests seen failing**: the suite failed to parse against the missing `InputRouter` and `boss_pacing` (exit 105), then seven deliberate mutants each failed: the stretch counted against the budget (4), the mode ending at the exit call (5), no hold in the beat (15), F4 recomputed per group (14), the commit step taking its own time (26), no cap (6 plus 1 error), `k` not applied to gaps (1). Restored, checked with `cmp`.
**Verification**: import exit 0; `gates.sh` G1 to G7 0 hits, `no_global_rng.sh` 0 hits, `parse-check.sh` 45 checked, 0 failed; `validate.gd` Ready, 0 errors; `commands.test` 2144 test cases, 0 errors, 0 failures, 0 orphans, exit 0, 88 `SCRIPT ERROR` lines, unchanged; smoke exit 0, 0 `SCRIPT ERROR`.
**Run result**: N/A: nothing player-visible. The story adds Node-free timing and a lock nothing renders; no scene exists until story 004, and story 015 draws the banner and the lock. No capture was taken.
**Open, for the owner**:
- **The first group can miss DD-X23 on a real turn.** Start-step steps precede any plan: at defaults the turn banner (0.4 s) and the boss's draw (0.2 s) run 0.6 s in FIFO order (U4.2), past both the 0.3 s beat and the 0.5 s cap. The ACs hold for the beat and pass as written; on a real boss turn the first group starts at about *t* + 600 ms. No document says whether those steps may overlap or be cut short, so none is invented: `test_start_step_steps_play_inside_the_beat_and_fifo_holds_a_longer_one` pins today's behaviour.
- **`A` counts `group_id`s, and a command is often several.** The engine logs `card_played` and `minion_summoned` at `cause_seq = 0`, so one play is two command groups under U4.2's definition, while F4's table says "boss commands". Gaps therefore also fall inside a play. Followed U4.2 and F4's first line.
**Deviations** (advisory):
- **Auto-skip fires whenever the clock reaches `max_turn_playback_s`,** not only at `k = K_MIN` (F4's last sentence). ADR-0009 Decision 2 extends it to a late tick, and L8 needs it: `k` is computed after the beat, so 30 groups at `k = 0.509` run 0.3 + 19.35k = 10.15 s, and the last 0.15 s is skipped to play in 10.0 s.
- **Auto-skip leaves the player's steps playing.** U4.5 flushes everything; the remainder of the boss turn is what F4 names.
- **F4's `A` and `D` exclude the commit step, which takes no time of its own,** or it would count twice with `intent_banner_s`. `D` otherwise sums every step, parallel ones too (F4's literal sum), and excludes impact extras, as F3 does. `k` scales those extras' hold.
- **`instant`** follows Edge Cases `T = 0`: no beat holds the plan, resolving the QA plan's open question. "Boss thinking" still fires at the cap there, since the boss really is thinking.
- **`skip_all` during the beat** ends the beat if the plan is here, and leaves the wait alone if it is not.
- **`exit_boss_turn()` is a request:** the mode ends when the queue drains. `MatchView` must call it before enqueuing `turn_started{player}`'s steps, so `seq` marks where the boss turn ends.
- **Additions to ADR-0009 Key Interfaces:** `boss_pacing()`, `boss_turn_timing()`, `boss_turn_active()`, `commit_beat_active()`, `boss_thinking()`, signal `boss_thinking_changed`, pacing key `planner_target_s` (DD-X23 postdates the ADR). `InputRouter.bind()` and `allows()` are also new; story 004 builds the rest of the router.
- **A story 001 assertion changed.** `test_boss_discover_offered_and_choice_requested_store_no_options` ended in `assert_array(steps).is_empty()`, against U6.6 and this story's AC. It now asserts the one step and that it carries no options; the hidden-information checks are untouched.
- **`match_ui.json`:** three keys added. The `match_ui` validator is still pending at Boot, so a wrong value would pass; the shipped-config suite pins their safe ranges meanwhile.
**Reviewed by**: pending, independent `/code-review` at the end of the wave.
