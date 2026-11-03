## Retrospective: Sprint 2 — First-playable chain, waves 1–3
Period: planned 2026-11-04 -- 2026-11-10; executed 2026-11-03 20:16 -- 21:38 UTC (one session)
Generated: 2026-11-03 by `/retrospective sprint-002` (subagent run under the owner's standing approval; no AskUserQuestion; automation guided)

**Inputs** (FOUND unless marked): `production/sprints/sprint-002.md`; `production/sprint-status.yaml`; the 16 done story files plus BOOT-006 and BOOT-008, read for Completion Notes start/end UTC; `git log 235c7fd..HEAD` (46 commits, HEAD `b06718d`); `production/retrospectives/retro-sprint-1-2026-11-03.md`; `production/qa/smoke-2026-11-03-sprint-002.md` (PASS, 668/668); `production/session-state/active.md` (orchestrator checkpoint). Milestone file: ABSENT (`production/milestones/` does not exist). First Playable is recorded in sprint plans only. Bug tracker: ABSENT. "Bugs" below means merge-time breaks found in this session.

### Metrics

| Metric | Planned | Actual | Delta |
|--------|---------|--------|-------|
| Tasks (stories) | 15 committed + 2 stretch | 16 done (15 committed + RNG-004 stretch); BOOT-006 not started | +1 over committed; −1 vs. committed+stretch |
| Completion Rate | -- | 100% committed; 94% incl. stretch (16/17) | -- |
| Effort Days (story-days) | ≈14 committed (+1 stretch) | 14.5 delivered | +0.5 |
| Bugs Found (merge-time breaks) | -- | 4 | -- |
| Bugs Fixed | -- | 4 (all by the orchestrator, before the next merge) | -- |
| Unplanned Tasks Added | -- | 1 story (BOOT-008 Windows export CI, from TASK-WINEXP) + 4 code-review fix passes on sprint-1 stories | -- |
| Commits | -- | 46 since `235c7fd` (10 merge commits, 9 of them lane/fix-pass merges to the trunk) | -- |
| Tests | 301 at sprint-1 close | 668 (38 suites), 0 failures, 0 orphans | +367 |

### Measured durations (from Completion Notes start/end UTC)

| Lane | Story (est.) | Start → end (UTC) | Minutes |
|------|--------------|-------------------|---------|
| match-rules | MR-003 (1) | 21:00:30 → 21:13 | 12.5 |
| | MR-004 (1) | 21:12:41 → 21:18 | 5.3 |
| | MR-005 (1) | 21:17:50 → 21:28 | 10.2 |
| rng-event-log | RNG-005 (1) | 21:04:33 → 21:10:30 | 6.0 |
| | RNG-006 (1) | 21:12:32 → 21:16:30 | 4.0 |
| | RNG-007 (1) | 21:16:34 → 21:21:30 | 4.9 |
| | RNG-002 (1) | 21:21:38 → 21:29:00 | 7.4 |
| card-database | CDB-002 (1) | 21:04:59 → 21:11:39 | 6.7 |
| | CDB-003 (1) | 21:13:14 → 21:17:19 | 4.1 |
| | CDB-004 (1) | 21:18:46 → 21:27:24 | 8.6 |
| | CDB-005 (0.5) | 21:28:15 → 21:33:35 | 5.3 |
| boot | BOOT-005 (1) | 21:00 → 21:11 | 11.0 |
| | RNG-004 (0.5, stretch) | 21:11 → 21:15 | 4.0 |
| boss-ai | BAI-002 (1) | 21:00:39 → 21:14:43 | 14.1 |
| | BAI-003 (0.5) | 21:16:30 → 21:20:45 | 4.3 |
| card-effects | CE-003 (1) | 21:00:42 → 21:20:08 | 19.4 |

- **Sum 128 agent-minutes for 16 stories.** Mean 8.0 min, median 6.4 min, range 4.0–19.4 min. That is ≈ 8.8 agent-minutes per estimated story-day.
- **The first story in a lane costs about twice a follow-on.** The six lane openers averaged 11.6 min; the ten follow-on stories averaged 5.8 min. The difference is context loading: the opener reads the GDD, ADRs and helpers that the rest of the chain reuses.
- **Wall clock.** Lane implementation ran 21:00 → 21:33:35 (34 min); serial merges ran 21:17:49 → 21:38:13. The last story finished 4.6 min before the last merge. The whole sprint, from the plan commit `388adce` (20:29) to the final merge (21:38), took ~70 min. That includes the QA plan, BOOT-008 and the four sprint-1 review fix passes, which ran 20:28–20:59 before the lanes started.
- Durations exclude orchestrator merge-fix time, which no story records.

### Velocity Trend

| Sprint | Planned | Completed | Rate |
|--------|---------|-----------|------|
| 1 | 10 stories / ≈11 story-days | 10 stories / 11 story-days, 1 session | 100% |
| 2 (current) | 15 committed + 2 stretch / ≈14 (+1) story-days | 16 stories / 14.5 story-days, 1 session (6 lanes) | 100% committed (94% incl. stretch) |

**Trend**: Increasing — +60% stories per session (10 → 16) and +32% story-days (11 → 14.5), even though sprint 2 was dependency chains rather than independent stories.
The lane rule (one agent carries a chain back to back) is what made the difference. Each lane carried 1–4 links, and no lane ran out of work before its chain ended in sprint scope. **Measured capacity is therefore a lower bound: sprint scope stopped the lanes, agent time did not.**

### What Went Well
- **The lane execution rule worked.** Six lanes in worktrees delivered 16 stories in 34 min of implementation, one commit per story. The rng-event-log and card-database lanes each carried 4 chained stories, across wave boundaries, with the full suite green after each commit.
- **Serial merges with the full suite after each caught every break before it reached the trunk.** There were four merge-time breaks (below). Each was fixed before the next lane merged, and every CI run on the branch is green: `Automated Tests` and `Windows Export` both `success` on `2c1710b`, `a34e02f` and `b06718d`.
- **The sprint-1 retro's top items landed.**
  - Four code-review fix passes on the risky sprint-1 stories (BOOT-004, RNG-001, MR-001/002, CDB-001) merged before dependents started (`e47ab93`, `15abd01`, `1760e17`, `ce5cd52`).
  - G3/G6 were corrected as an ADR-0001 erratum and propagated (`83b61c9`, `400705b`).
  - Per-story start/end times are now logged, which is what made this retro's durations possible.
- **Gate condition 8 is half met, and unplanned.** BOOT-008 put the Windows export in CI. The artifact was verified (`deckdelve-windows-…`, 39 MB) and the template cache hit was confirmed on the second run (`b322f2b`). Only the owner's first-light screenshot is still owed.
- **Lint gates are now blocking in CI.** The CI lint step runs G1–G6 + G2b, the no-global-RNG lint and the per-file parse check. ripgrep ≥ 14 is installed explicitly, and the step runs before gdUnit4.
- **Tests 301 → 668 (+122%)** with 0 orphans and no flaky tests. The suite runs in 6.3 s.

### What Went Poorly
- **Four merge-time breaks, all from cross-lane contract changes that no single lane could see:**
  1. Lint G2b tripped on a doc comment (`no await` in `rules_engine.gd`). The gate pattern was fixed to ignore comment lines (`2c1710b`, ADR-0001 erratum).
  2. The RNG lint flagged a legitimate raw-generator test, `rng_service_test.gd`. It was allow-listed in `tools/lint/no_global_rng.sh`.
  3. **`src/core/boot.gd` `_collect_validators()` conflicted across three lanes** (card-database, boss-ai, rng-event-log). Each registered its own validator. The orchestrator assembled the result by hand: the CDB lane's full map plus the real `ai_profiles` and `rng_event_log` validators. Nine placeholders remain in `PENDING_CONFIG_OWNERS`.
  4. **Integration tests broke when card-database stage 7 began enforcing every validator** (CDB-004). The staged-config tests were switched to `ValidatorStubs.accept_all()` (45 call sites now), and the minimal fixture got valid `rng_event_log` and `ai_profiles` bodies.
- **Diagnosing merges was slower than it needed to be.** gdUnit4's `commands.test` stops a suite at its first failure, so each merge break showed one failure per suite per run. Running with `-c` (continue) shows the whole set.
- **Lanes collided in the shared scratchpad.** Lanes wrote scratch files under the same names in one directory (orchestrator checkpoint). Nothing shipped wrong, but output had to be re-checked.
- **The sprint-1 review floor was not applied.** Sprint-1 Process Improvements made independent `/code-review` mandatory for stories that change a shared helper or shared state type. 0 of 16 sprint-2 stories record an independent review ("self, no independent review", Lean). That includes MR-003 (`MatchState`, `MatchFactory`), RNG-005/RNG-002 (helper swaps) and CDB-004 (`ValidatorStubs`, loader contract).
- **BOOT-006's status is inconsistent across files.** `sprint-status.yaml` reads `status: backlog` with a `blocker` text, and the story file reads `Status: Ready`. Neither says `blocked`, so `/sprint-status` will show it as startable.

### Blockers Encountered

| Blocker | Duration | Resolution | Prevention |
|---------|----------|------------|------------|
| **BOOT-006** `main.tscn` composition entry. `blocker`: "main_menu (BootResult.ok) path needs CardDatabase.config()/heroes()/treasure_pool() — card-database story 006; real data load is Failed (only match_rules.json ships); tools/capture.sh lacks the documented [-- <args>] pass-through" | Whole sprint (not started) | Carried to sprint 3, after CDB-006 plus a full data set; `tools/capture.sh` gains `--` arg pass-through | Readiness should check runtime prerequisites (a passing real-data load), not only story dependencies. The QA plan's Risks flagged this ("needs a passing load") and the stretch was kept anyway |
| `boot.gd` validator-assembly conflict across 3 lanes | Merge phase (minutes) | Hand-merged by the orchestrator | Single owner for `_collect_validators()` (Action 1) |
| CDB-004 stage-7 enforcement broke other lanes' integration tests | Merge phase (minutes) | `ValidatorStubs.accept_all()` + fixture bodies | A story that tightens a shared contract merges last and owns the fixture updates (Process Improvements) |

### Estimation Accuracy

The estimates are in human story-days. This compares each story against the sprint's own mean rate (8.8 min per story-day) to see relative calibration.

| Task | Estimated | Actual | Variance | Likely Cause |
|------|-----------|--------|----------|--------------|
| CE-003 EffectValidator (most underestimated) | 1 d (≈ 8.8 min) | 19.4 min | +120% | Lane opener in a `full`-tier system; widest code surface (schema, trigger, selector, op, ref; 36 tests) |
| BAI-002 ProfileResolver | 1 d (≈ 8.8 min) | 14.1 min | +60% | Lane opener; 46 tests |
| RNG-006 EventLog serialisation (most overestimated) | 1 d (≈ 8.8 min) | 4.0 min | −55% | Third in its chain; reused the RNG-005 envelope and helpers |
| CDB-003 Uniqueness/cross-refs | 1 d (≈ 8.8 min) | 4.1 min | −53% | Second in its chain; stage pattern set by CDB-002 |

**Overall estimation accuracy**: 5 of 16 stories (31%) within ±20% of the scaled estimate (BAI-003, RNG-004, MR-005, RNG-002, CDB-004).

Position in the lane predicts duration better than the estimate does. Openers average 11.6 min and follow-ons 5.8 min, while estimated size barely separates them. The S stories (0.5 d) took 4.0–5.3 min, about the same as M follow-ons. Adjustment for sprint 3: estimate in **links per lane** and treat the opener as ~2 links. Keep story-days only as a relative-size label. The binding cost is merge-fix and owner-review time, which no story-day estimate covers.

### Carryover Analysis

| Task | Original Sprint | Times Carried | Reason | Action |
|------|----------------|---------------|--------|--------|
| BOOT-006 `main.tscn` composition entry (UI, stretch) | 2 | 1 | Needs CDB-006 queries, a full real data set, and `capture.sh` `--` pass-through | Complete in sprint 3 after CDB-006; set yaml `status: blocked` until then |
| BOOT-008 owner first-light screenshot (gate condition 8, second half) | 2 | 1 | Only the owner has the Windows machine | Owner launches artifact `deckdelve-windows-…` from run 41723632236; screenshot to `production/qa/evidence/windows-first-light-<date>/` |
| First Playable re-date decision (sprint-2 DoD line) | 2 | 1 | Deferred by the plan to sprint close, pending measured throughput | Re-dated below; owner to accept |

### Technical Debt Status
- Current TODO count: 36 (29 in `src/`, 7 in `tests/` outside fixtures). Previous: 23 (16 in `src/`, 7 in `tests/`).
- Current FIXME count: 0 (previous: 0)
- Current HACK count: 0 (previous: 0)
- Trend: Growing (+13, all in `src/`). Every `src/` marker is a cross-epic `TODO(<epic>)` seam: meta-progression 8, card-database 2, boss-ai 1, match-rules 1, rng-event-log 1, treasures 1, plus untagged ones. They are not shortcuts, but meta-progression has no sprint scheduled.
- Areas of concern:
  - Nine `PENDING_CONFIG_OWNERS` placeholders in `boot.gd`: config files with no owning validator yet. A real-data `Boot.boot()` stays `Failed` until CDB-006 and these owners land.
  - 45 `ValidatorStubs.accept_all()` call sites. They are correct for staged-config tests, but they can hide a real validator regression if they spread into tests meant to exercise validators.

### Previous Action Items Follow-Up

| Action Item (from Sprint 1) | Status | Notes |
|-------------------------------|--------|-------|
| 1. `/code-review` BOOT-004, MR-001, RNG-001, CDB-001 before dependents start | Done | Four fix passes merged 20:28–20:59 (`e47ab93`, `15abd01`, `1760e17`, `ce5cd52`), before the lanes started at 21:00 |
| 2. Serialise stories that touch shared helpers / `MatchState` | Done, adapted | Plan marked [S]. Under lanes it became merge order: MR lane and RNG lane merged early. No helper-swap break occurred; the breaks came from `boot.gd` and the loader contract, which the [S] rule does not cover |
| 3. Owner gives weekly hours (gate condition 3) | Not Started | Still not given (sprint-2 plan, Capacity). Second sprint carried |
| 4. Close sprint-1 DoD: `/team-qa sprint`; BOOT-005 in sprint 2 | Partly done | BOOT-005 done (lint gates blocking in CI). `/team-qa` not run (needs the Agent tool) |
| 5. `/dev-story` logs start/end per story | Done | All 16 stories record UTC start/end |
| Process: mandatory `/code-review` for shared-helper/shared-state/ADR-deviation stories | Not done | 0/16 independently reviewed; see What Went Poorly |

### First Playable re-date (deferred to this retro by the sprint-2 plan)

- **Remaining critical path: 19 links.** The plan's 22-link path (MR-003 → … → MUI-012) lost MR-003/004/005 this sprint. MR-006 … MR-010, MR-012/013/014/017 and BAI-004/005/007/008/013/015/016/017/018 → MUI-012 remain.
- **Remaining stories: ≈ 44** (the plan's 60, minus this sprint's 16).
- **Measured throughput.** Up to 4 chained links per lane-session (rng-event-log, card-database). MR links averaged 9.3 min. Agent time for all 19 links is about 3 h serial, so it is not the constraint. Capacity: 44 stories at 16 per session is under 3 sessions.
- **Re-dated target: sprint 7 (2026-12-09 → 2026-12-15).** Of the bounds below, the critical path is the one that binds.
  - The critical path at the measured 4 links per session gives 19 / 4 → 5 sprints (3–7).
  - Stretch: **sprint 6 (2026-12-02 → 12-08)** if the critical lane carries 5 links per session from sprint 3.
  - This supersedes the plan's sprint-9 estimate. The plan's sprint-5 option-1 estimate assumed capacity, not path length, was the limit.
- **Conditions that the date depends on, none of them agent time:**
  - UX specs for hand, targeting, mulligan and match-end (gate condition 11) authored before MUI-006/008/009/011 reach readiness, by sprint 4.
  - `/create-stories heroes` before BAI-016 (sprint 4).
  - The owner's decision on the CE-002 `clone()` split, before sprint 4.
  - Owner review time (gate condition 3, still unknown).
- **Gate condition 5 ("within sprints 1–2") is not met.** The owner (Jacob) accepts this re-date or rescopes (sprint-2 plan, option 3).

### Action Items for Next Iteration

| # | Action | Owner | Priority | Deadline |
|---|--------|-------|----------|----------|
| 1 | **Single owner for `src/core/boot.gd` `_collect_validators()`.** Lanes do not edit it. Each lane's Completion Notes name the validator to register, and the orchestrator adds it at merge, in one commit per lane. Longer term, move registration to a per-system table, so adding a system is a new row, not an edit to shared code | orchestrator / lead-programmer | High | Sprint 3 plan (before lanes start) |
| 2 | **Run independent `/code-review` on MR-003, RNG-002 and CDB-004** (shared state, helper swap, loader contract). Record the verdicts in "Reviewed by" before the sprint-3 stories that build on them merge. Reserve one review slot per lane in the sprint-3 plan | lead-programmer via `/code-review`; Jacob reads the verdicts | High | Before sprint-3 merges of MR-006, RNG-003/008, CDB-006 |
| 3 | **Owner decisions owed:** accept the First Playable re-date to sprint 7 (or rescope), give weekly hours (gate condition 3, carried twice), decide the CE-002 `clone()` split, and launch the BOOT-008 artifact for first light | Jacob | High | Before `/sprint-plan new` for sprint 3 |
| 4 | **Set BOOT-006 to `blocked`** in `sprint-status.yaml` and in the story file. Fix `tools/capture.sh` `--` arg pass-through. Schedule BOOT-006 right after CDB-006 in the same lane | producer (`/sprint-plan`); devops-engineer for `capture.sh` | Medium | Sprint 3 plan |
| 5 | **Merge-diagnosis hygiene.** Use `commands.test` plus `-c` when diagnosing a merge, so every failure shows at once (keep CI as is). Prefix lane scratch files `<lane>-`, or give each lane its own scratch subdirectory | orchestrator | Medium | Sprint 3, first merge |

### Process Improvements
- **Size sprint 3 by lanes and links, not story-days.**
  - Commit **6 lanes × 3 links (≈ 18 stories)**, plus one stretch link per lane.
  - Make the critical lane MR-006 → MR-009 committed, with MR-010 as stretch, so it carries 5 links if it can.
  - Count each opener as 2 links when balancing lanes.
  - Candidate chains: CDB-006 → BOOT-006; RNG-003/008; CE-002 (if split); content 001; UX specs for gate condition 11.
  - Measured basis: 16 stories / 34 min of lane time, with openers at 2× follow-ons.
- **A contract-tightening story merges last and owns the fixture fallout.** Examples are a loader stage that starts enforcing validators, or a lint gate that starts blocking. Mark such stories [C] in the plan, next to [S]. The lane that tightens the contract runs the full suite against the other lanes' merged state before its own merge. CDB-004 and BOOT-005/RNG-004 would both have been [C] this sprint.
- **Keep what worked:** lanes carrying chains across wave boundaries, one commit per story, serial merges with the full suite after each, per-story UTC timing, and ADR errata the same day as the finding (G2b, G3/G6).

### Summary
A strong sprint: all 15 committed stories plus a stretch, 14.5 story-days delivered by six lanes in 34 minutes of implementation. Tests went 301 → 668, CI is green on both workflows, and the Windows export now builds in CI. Throughput is no longer the constraint. Cross-lane contracts (`boot.gd` validator assembly, loader enforcement) and the skipped independent review are. The most important change is a single owner for `boot.gd` `_collect_validators()`, together with merge-last ordering for contract-tightening stories. First Playable re-dates to sprint 7 (2026-12-15), stretch sprint 6, pending the owner's acceptance.
