# Story 018: Windows export — planner running, A30 frame budget and determinism on Windows (gate conditions 6 and 9)

> **Epic**: Boss AI + Match Driver
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: L
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/boss-ai.md` C1.5, C9 ("2 ms/frame → C1.5 and A30"), A30, A22 ("target machine, release template")
**Requirement**: `TR-boss-ai-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Boss AI Planner Threading (Engine Compatibility "Verification Required" items 1–3: A30 on the target machine; the determinism test; both on **Windows** — Probe A ran on Linux only; Validation Criteria "A30 passes on Linux and Windows debug builds"); ADR-0008 (Engine Compatibility item 2: frame pacing of `tick()` under a live task is NOT SOURCEABLE; A30 measures it with the real `MatchView._process`)
**ADR Decision Summary**: Windows `WorkerThreadPool` behaviour is NOT SOURCEABLE until the determinism test and A30 run on the `commands.build` Windows export; the ADR gates the epic's close on that run (gate condition 9, technical-director) and the sprint-1 spike requires "Boss AI planner running on the Windows export" (gate condition 6, lead-programmer). If the pool misbehaves on Windows, `ThreadPlannerTask` (ADR-0006 Alt 2) is the drop-in behind the seam.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH / NOT SOURCEABLE
**Engine Notes**: `commands.build` = `godot --headless --path . --export-release 'Windows Desktop' build/windows/deckdelve.exe` (verified locally 2026-11-03; needs `EXPORT_TEMPLATES=1 bash tools/setup.sh`; not in CI; first export after a fresh import may exit 134 — run `--import` first and retry once). A debug export (`--export-debug`) is needed for the profiler half of A30; `assets/data/*.json` in the exported PCK is NOT SOURCEABLE (ADR-0002 item 4) and is confirmed by the planner loading `ai_profiles.json` from the export. Windows D3D12 is the 4.6+ default renderer — irrelevant to the planner but part of the first-light evidence (gate condition 8, `match-ui` epic). This story cannot run in the Linux CI container; it is executed on the owner's Windows machine and its evidence retained.

**Control Manifest Rules (this layer)**:
- Required: Default `WorkerPoolPlannerTask` protocol; `Boot` constructs `WorkerPoolPlannerTask` by default and `TimeSlicedPlannerTask` when `runtime.planner_mode == "time_sliced"` or `--ai-sync`.
- Forbidden: Never a dedicated `Thread` per boss turn as the default (kept as a drop-in `ThreadPlannerTask` behind the seam if the pool misbehaves on Windows). Never main-thread time-slicing as the sole implementation.
- Guardrail: Boss AI main thread ≤ 2 ms per frame — one `is_task_completed` per frame plus replay bounded by `replay_budget_ms`; worker 50 ms p95 per turn (A22).

---

## Acceptance Criteria

*From GDD `design/gdd/boss-ai.md` A30, A22 and ADR-0006 Engine Compatibility "Verification Required" / gate conditions 6 and 9, scoped to this story:*

- [ ] GIVEN the Windows export built by `commands.build` from the current `main`, WHEN it is launched on the owner's Windows machine and a band-1 match (Rat King, Gatekeeper or Torchbearer) is played through the real `MatchDriver` with `WorkerPoolPlannerTask` (`runtime.planner_mode = worker`), THEN at least one full boss turn completes with `ai_intent_shown`, `ai_intent_committed` and `ai_decision` events in the log, no `ai_fault`, and the retained log is saved under `production/qa/evidence/boss-ai-windows-<date>/` (gate condition 6: "Boss AI planner running on the Windows export").
- [ ] **A30** GIVEN a Windows debug export with the profiler attached, WHEN 20 band-3 boss rounds (Hollow King) run through the real match driver (windowed, not headless), THEN no frame attributes more than 2 ms of main-thread time to `src/ai/**` (and `MatchDriver.tick()` logs no `ai_fault {tick_over_budget}`), and the `ai_decision` sequence equals the headless Linux run of the same seed (A1); the profiler capture and the two canonical-JSON logs are retained in the evidence folder.
- [ ] GIVEN the Windows export, WHEN Story 017's determinism suite (worker vs time-sliced vs immediate, the full 1,000-turn set) is run via `tools/sim.sh` / the gdUnit4 command on Windows, THEN the logs are byte-identical across the three implementations with zero `ai_fault`, the result file is retained, and gate condition 9's Boss AI half is recorded as met in `production/gate-checks/gate-pre-production-2026-11-03.md`'s follow-up (technical-director sign-off noted in the evidence README).
- [ ] **A22 on the target machine** GIVEN Story 016's harness run on the owner's Windows machine (headless, release template, band 3, 200 seeds), THEN `p95_planner_ms ≤ 50` and `ai_decision` events ≤ 400 per match, or the F7 knob (`lethal_max_nodes` band 3) is lowered in `ai_profiles.json` and the run repeated until it passes — the data change recorded as a `/quick-design` note.

---

## Implementation Notes

*Derived from ADR-0006 Engine Compatibility / Verification and `tests/README.md` "Export is not run in CI (yet)":*

- Deliverables are evidence, not code: `production/qa/evidence/boss-ai-windows-<date>/README.md` (machine spec, Godot build, export commit, exact commands, pass/fail per AC), the match log JSON(s), the profiler screenshot(s) (A30 is a measurement; the retained PNG is read and compared per run-and-observe step 4), the determinism result file and the A22 harness JSON.
- Commands: `godot --headless --path . --import` → `commands.build` (release) and `godot --headless --path . --export-debug 'Windows Desktop' build/windows/deckdelve-debug.exe`; on Windows, the gdUnit4 command from `tests/README.md` for Story 017's suites with `SIM_FULL=1`; `tools/sim.sh --boss boss_hollow_king --seeds 200` for A22.
- If `WorkerThreadPool` misbehaves on Windows (non-identical logs, stderr errors, hangs in `shutdown()`), do not patch around it: write `src/ai/thread_planner_task.gd` (`ThreadPlannerTask`, ADR-0006 Alt 2 — `Thread.start / is_alive / wait_to_finish`, observed in Probe A) as the drop-in and record the finding for an ADR-0006 revision (`/architecture-decision`), then re-run.
- Debug-only self-timing in `tick()` (Story 015) is the automated witness beside the profiler; the profiler's per-script attribution is the GDD's named measurement.
- Owner involvement: the owner (or anyone with a Windows machine and export templates) runs this; the cloud session cannot. Schedule it in the sprint that closes the epic (gate condition 9 deadline).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 016 / 017: the harness and suites themselves.
- `match-ui` epic: Windows first-light screenshots (gate condition 8) and `/perf-profile` (condition 10).
- `meta-progression` epic: `atomic_write_platform_test.gd` (the other half of gate condition 9).
- CI Windows export job (plan E10 / release prep).

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `production/qa/evidence/boss-ai-windows-<date>/README.md`
- `production/qa/evidence/boss-ai-windows-<date>/*.png`, `*.json` (retained logs, profiler capture, determinism and A22 results)
- `src/ai/thread_planner_task.gd` (only if the pool fails on Windows)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Integration
**Required evidence**:
- Integration: documented playtest / verification record — `production/qa/evidence/boss-ai-windows-<date>/README.md` with the retained logs, profiler capture and result files (Story 017's suites re-run on Windows are the automated half)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/boss-ai-match-driver/story-003-ai-profiles-mvp-data.md`, `production/epics/boss-ai-match-driver/story-016-sim-harness.md`, `production/epics/boss-ai-match-driver/story-017-planner-determinism-across-implementations.md`; `match-ui` epic's `MatchView` (the real `_process` → `tick()` call site for A30) and `boot-composition-root`'s `Boot` factory (cross-epic)
- Unlocks: None — closes gate conditions 6 (Boss AI half) and 9 (Boss AI half) for this epic
