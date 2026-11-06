# Sprint 1 — 2026-11-04 to 2026-11-10

> **Type**: one-week calibration sprint (gate `production/gate-checks/gate-pre-production-2026-11-03.md`, entry condition 4)
> **Stage**: Pre-Production · workflow standard · review lean · automation guided · story_granularity balanced (6–10 stories per sprint) · qa.level standard
> **PR-SPRINT**: skipped — Lean mode
> **QA Plan**: none yet — run `/qa-plan sprint` before implementation begins (Phase 5 choice [A], owner standing approval)
> **Milestone file**: none in `production/milestones/` (none is required; the milestone below is recorded in this plan only)
> **Risk register**: none in `production/risk-register/` — risks assessed from the sprint contents only
> **Generated**: 2026-11-03 by `/sprint-plan new` (subagent run; owner standing approval, no AskUserQuestion)

## Milestone: First Playable (sprints 1–2 target)

Gate entry condition 5: a **Windows export** of **one War match vs one band-1 boss** (`boss_torchbearer`, content story 001), **mouse-played**; the owner plays it = playtest #1. Target: end of sprint 2. Sprint 1 builds Foundation and Core seams toward it and runs the three sprint-1 spikes; it does not deliver anything playable.

What the milestone needs that this sprint does not build (reported, not solved — see Risks):
- **Match UI stories** — the `match-ui` epic has no stories yet (`/create-stories match-ui`). Nothing playable can be shown without them.
- **Windows export in CI as a download** (gate condition 8) — no story holds it (`tools/` / devops task; index.md places it as a sprint task under E10).
- **The story volume** — content story 001 alone needs card-database 001–006, match-rules 001, card-effects 002–003, boss-ai 003 and rng-event-log 007 first; the full first-playable chain across the seven storied epics plus Match UI is roughly 50+ stories. At the balanced range (≤10 per sprint) it does not fit sprints 1–2 unless sprint 1's measured velocity is far above the range. Sprint 2's plan must confirm or re-date this milestone from that velocity.

## Sprint Goal

Lay the foundation for the first playable — the `Boot` composition root, the RNG golden pin and draw primitives, the match-rules data model and hook registry, the card-database loader's first stage — and run the three spikes the gate requires in sprint 1 (DSL five hardest effects with a PROCEED/PIVOT outcome, the Boss AI `PlannerTask` seam, the RNG golden-pin test).

Owner's fuller brief, and what did not fit the 10-story cap: the card-database loader to `Ready` on content batch 0 (card-database 002–006 + content 001 and its cross-epic chain), RNG `RngService` / `EventLog` core (rng-event-log 002, 005), and match setup (match-rules 003). They are the first sprint-2 candidates below.

## Goal Prerequisites

| Needed to show the goal | Status |
|-------------------------|--------|
| None: the goal has nothing to run or show — every committed story is Logic or Integration, proven by headless gdUnit4 tests (`commands.test`); the spike outcome is a document | — |

The **milestone** (not this sprint's goal) has missing prerequisites; they are listed above and copied into Risks.

## Capacity

- Calendar: Wed 2026-11-04 – Tue 2026-11-10 (7 days, 5 working days)
- Total days: 5
- Buffer (20%): 1 day reserved for unplanned work
- Available: 4 days
- **Capacity is unmeasured** — the owner has not given weekly hours (gate condition 3, accepted risk). Development runs in a cloud container (headless; UI evidence via `tools/capture.sh` under xvfb), with the owner reviewing and playing Windows exports.
- **Sizing basis**: story count, not hours — 10 stories, the top of the balanced range (6–10), no stretch tier (Should Have and Nice to Have are empty on purpose).
- **Committed estimate**: 2 S + 7 M + 1 L ≈ **11 story-days** at the `/create-stories` scale (S ≈ a few hours → 0.5, M ≈ about a day → 1, L ≈ several days → 3). This exceeds the 4 available person-days at that scale; the scale was written for a human day, and the ratio of completed to committed story-days is exactly what this sprint measures.
- **Velocity record**: at sprint close, `/retrospective` records stories completed and story-days completed. **Sprint 2 is planned from sprint 1's measured velocity**, not from this sizing.
- **Cut order if the week runs short** (no re-scoping mid-sprint; unfinished stories become sprint-2 carryover): card-database 001 → match-rules 002 → match-rules 001. The three spikes and the boot chain are not cut.

## Tasks

### Must Have (Critical Path)

Execution order is the row order; parallel work is fine where the Dependencies column allows it.

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| RNG-001 | [RngStream — engine golden pin and F4 draw primitives](../epics/rng-event-log/story-001-rng-stream-engine-pin-and-draw-primitives.md) — **spike: gate condition 7** (Logic, M) | gameplay-programmer | 1 | None | `tests/unit/rng_event_log/rng_engine_pins_test.gd` 100-draw golden sequence for seed 42 passes; `weighted_pick`, `fork`, `shuffle` draw counts exact (F4); full ACs in story |
| CE-001 | [Spike — the five hardest DSL effect types](../epics/card-effects/story-001-dsl-spike-five-hardest.md) — **spike: gate condition 6** (Logic, L; throwaway allowed) | lead-programmer | 3 | None in epic; cross-epic stub engine allowed (match-rules not built yet); `tests/helpers/test_rng_stream.gd` exists | AC-S1 five C11 effects resolve headless with a fixed seed; AC-S2 `docs/architecture/spikes/2026-11-DD-dsl-effect-spike.md` records **PROCEED or PIVOT** (PIVOT re-blocks card-effects 006–016); AC-S3 spike code deleted or promoted, G7 clean |
| BAI-001 | [PlannerTask seam and its three implementations](../epics/boss-ai-match-driver/story-001-planner-task-seam.md) — **start of the planner spike, gate condition 6** (Logic, M) | ai-programmer | 1 | None in epic | Immediate / TimeSliced / WorkerPool tasks meet the `start`/`poll`/`result`/`is_live` contract; `PlannerTask` is `@abstract`; full ACs in story. The Windows half of the spike is BAI-018 (sprint 2+) |
| BOOT-001 | [SettingsBus](../epics/boot-composition-root/story-001-settings-bus.md) (Logic, S) | godot-gdscript-specialist | 0.5 | None | One signal `settings_changed(key, value)` + `get_setting`; parse check and gates G1–G3/G2b clean |
| BOOT-002 | [MetaApi abstract seam](../epics/boot-composition-root/story-002-meta-api-abstract-seam.md) (Logic, S) | godot-gdscript-specialist | 0.5 | BOOT-001 | `@abstract` M1.3 methods with typed returns; `MetaApi.new()` refused on 4.7.2, concrete test subclass instantiates |
| BOOT-003 | [MetaStub — the MVP MetaApi implementation](../epics/boot-composition-root/story-003-meta-stub.md) (Logic, M) | godot-gdscript-specialist | 1 | BOOT-001, BOOT-002; cross-epic `CardDatabase` injected as a test double (card-database 006 not in sprint) | In-memory active-run round-trip, settings from `profile_defaults` with M9 range check, `from_fixture`; full ACs in story |
| BOOT-004 | [Boot — the one autoload and lazy composition root](../epics/boot-composition-root/story-004-boot-composition-root.md) (Integration, M) | engine-programmer | 1 | BOOT-001, BOOT-003; cross-epic `CardDatabase` + `ValidationReport` via `boot({card_database: ...})` override | `Boot` is the only autoload, `_ready()` inert; `boot()` steps 2–4 in order; overrides honoured; `Failed` load returns `ok == false` with the report. Integration test under `tests/integration/boot/` |
| MR-001 | [Match data model, derived values and rules config](../epics/match-rules/story-001-data-model-and-rules-config.md) (Logic, M) | gameplay-programmer | 1 | None; `TestRngService` / `TestEventLog` doubles exist in `tests/helpers/` | AC-41 F9 constants only in config; C1 derived values; `MatchState` shape from `MatchFactory.make_match_config`; creates `assets/data/match_rules.json` |
| MR-002 | [HookRegistry: install order, fold, copy](../epics/match-rules/story-002-hook-registry.md) (Logic, M) | gameplay-programmer | 1 | MR-001 (registry class can be built in parallel) | Install order, duplicate-host refusal, unclamped fold, deep `copy()` with evaluators unset |
| CDB-001 | [File manifest, parse and envelope (CR-5 stages 1–3)](../epics/card-database/story-001-manifest-parse-envelope.md) (Logic, M) | gameplay-programmer | 1 | None | `FILE_MANIFEST` one row per DD-T01 file; `E_PARSE` / `E_SCHEMA_VERSION` with no fail-fast; single-parser grep test |

Total: 10 stories, ≈ 11 story-days.

### Should Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| — | None — calibration sprint is stretch-free by the owner's brief | | | | |

### Nice to Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| — | None | | | | |

## Carryover from Previous Sprint
| Task | Reason | New Estimate |
|------|--------|-------------|
| — | First sprint; no previous sprint | — |

## Next Sprint Anchors (sprint 2 or later — not in sprint 1)

| Story | Why not now | Depends on |
|-------|-------------|-----------|
| [boss-ai-match-driver 016 — headless AI-vs-AI harness](../epics/boss-ai-match-driver/story-016-sim-harness.md) (gate condition 6, L) | Needs most of the epic | 001–015 in epic order (via 013 → 014/015) |
| [boss-ai-match-driver 018 — Windows planner, A30 and determinism](../epics/boss-ai-match-driver/story-018-windows-planner-a30-and-determinism.md) (gate conditions 6 and 9, L; owner-run on Windows) | Needs the harness and a Windows export; cannot run in the Linux container | 016 → 017 → 018; Windows CI export (gate 8, no story) |

First sprint-2 candidates (the parts of the owner's goal that did not fit, in dependency order): match-rules 003 (setup); rng-event-log 002 (`RngService`) and 005 (`EventLog` core); card-database 002 → 006 (loader to the freeze); then the content story 001 chain — card-effects 002/003 (if the spike says PROCEED), boss-ai 002/003, rng-event-log 007, card-database 008 — and boot 005/006/007. Card-database 010 (`Ready` on shipped data in the export) also needs content MVP-1 and is later still.

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Capacity unmeasured; committed ≈ 11 story-days against 4 available person-days at the `/create-stories` scale | High | Medium | Calibration by design: fixed cut order above; record actual velocity at close; plan sprint 2 from it |
| CE-001 returns **PIVOT** | Medium | High | PIVOT re-blocks card-effects 006–016 and pushes the first playable; surface the outcome to Jacob the day it lands; card-effects 002/003 planning waits on it |
| RNG golden pin fails (engine RNG drift on 4.7.2) | Low | High | RNG-001 runs first; a failure stops ADR-0003 work and goes to technical-director |
| WorkerThreadPool behaviour on Windows unverified (BAI-001 tested on Linux only) | Medium | Medium | BAI-001 is the Linux seam; Windows half is BAI-018 (gate conditions 6/9), scheduled later |
| **Milestone prerequisite missing:** no Match UI stories | Certain | High | Fixes open to the owner: run `/create-stories match-ui` before sprint 2; or re-date / reword the first-playable milestone |
| **Milestone prerequisite missing:** no story for the Windows export in CI (gate condition 8) | Certain | High | Fixes open: write a story/task for it (`/create-stories` or a sprint-2 task, devops-engineer); or the owner exports by hand for playtest #1 |
| **Milestone at risk:** first-playable chain (~50+ stories) exceeds two balanced sprints | High | High | Sprint 2 planning re-dates or rescopes the milestone from measured velocity; options: raise per-sprint count if velocity supports it, or a narrower playable cut |
| Cross-epic seams built against test doubles (BOOT-003/004 vs `CardDatabase`, MR-001 vs RNG/EventLog) diverge from the real classes | Medium | Medium | Doubles follow ADR-0001/0002/0003 Key Interfaces; re-run those tests when card-database 006 and rng-event-log 002/005 land |
| Long-lived PR #1 and ephemeral container | Medium | Medium | Merge PR #1 before gameplay code lands (gate accepted risk) |

## Dependencies on External Factors
- Owner (Jacob): weekly hours still not given (gate condition 3) — needed for sprint 2 capacity in hours.
- Owner: reads CE-001's PROCEED/PIVOT record and accepts or overrides it.
- Godot 4.7.2 headless + gdUnit4 6.2.3 in the container (`commands.test`); CI `.github/workflows/tests.yml` green.
- No Windows run is required this sprint.

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-001-[date].md`, from `/qa-plan sprint`)
- [ ] All Logic/Integration stories have passing unit/integration tests
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged
- [ ] CE-001 outcome recorded (PROCEED / PIVOT) in `docs/architecture/spikes/`
- [ ] Velocity recorded at close (stories and story-days completed) for sprint 2 planning

QA plan: run `/qa-plan sprint` before implementation begins.
