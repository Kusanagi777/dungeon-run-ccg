## Retrospective: Sprint 3 — Primitives to resolution loop, database freeze, effect runtime, match-view core
Period: planned 2026-11-11 -- 2026-11-17; executed 2026-11-03 22:20 -- 2026-11-04 02:19 UTC (one session, about 4 h wall clock)
Generated: 2026-11-04 by `/retrospective sprint-003` (subagent run under the owner's standing approval; no AskUserQuestion; automation guided)

**Inputs** (FOUND unless marked):
- `production/sprints/sprint-003.md` and `production/sprint-status.yaml`.
- The 20 sprint-3 story files, read for their Completion Notes start/end UTC.
- `git log 30b6509..HEAD`: 57 commits (15 merges, 42 non-merge), HEAD `91cb070`.
- `production/retrospectives/retro-sprint-2-2026-11-03.md`.
- `production/qa/smoke-2026-11-04-sprint-003.md` (PASS, 1078/1078).
- `production/session-state/active.md`: the code-review checkpoints and the orchestrator checkpoint at about 02:25Z.

Not available:
- Milestone file: ABSENT (`production/milestones/` does not exist).
- Bug tracker: ABSENT. "Bugs" below means code-review findings.
- Merge-conflict record: ABSENT. Git keeps no record of conflicts that were resolved, so "no hard conflicts" rests on the merge messages (none mentions a conflict) and on the `boot.gd` history (below).

### Metrics

| Metric | Planned | Actual | Delta |
|--------|---------|--------|-------|
| Tasks (stories) | 17 committed + 3 stretch (MR-010, CE-006, BOOT-006 carryover) | **20 done**: 17 committed + all 3 stretch | +3 over committed; 0 vs. committed + stretch |
| Completion rate | -- | 100% committed; 100% including stretch (20/20) | -- |
| Story-days (relative label) | ≈ 25 committed (+4.5 stretch) | 29.5 delivered | +4.5 |
| Critical-lane links | 4 committed (MR-006 … 009) + 1 stretch | **5** (MR-006 … MR-010) | +1 |
| Bugs found (code review) | -- | 1 blocking + about 13 should-fix / data items over 7 reviewed stories | -- |
| Bugs fixed | -- | All of them: `413c165` (MR-006 … 008), `fix/review-s3w2` → `91cb070` (MR-009/010, CE-002, MUI-001, `match_rules.json` band health) | -- |
| Unplanned tasks added | -- | Debug playtest build in CI (`bec8ede`); perf-miss-as-warning CI change (`f3995e8`); two designer defaults DD-X13/X14 and the C15 rows (`c2e23b6`); ADR errata 0002/0003/0005/0007 + match-rules C1 `resolving` (`b7fbf24`, `bf69d0d`, `0be3787`) | -- |
| Commits | -- | 57 since `30b6509` | -- |
| Tests | 668 at sprint-2 close | **1078** (65 blocking suites + 2 non-blocking perf suites), 0 failures, 0 orphans | +410 (+61%) |

### Measured durations (from Completion Notes start/end UTC)

| Lane | Story (est. d) | Start → end (UTC) | Minutes | Note |
|------|----------------|-------------------|---------|------|
| 1 match-rules (critical) | MR-006 (3, opener) | 22:21:36 → 22:34:39 | 13.1 | |
| | MR-007 (1) | 22:40:09 → 22:44:17 | 4.1 | |
| | MR-008 (1) | 22:45:03 → 22:52:46 | 7.7 | |
| | MR-009 (3) | 22:58:58 → 23:21:20 | 22.4 | includes the MR-006 … 008 review-fix commit (23:06–23:14), so about 14 min for the story itself |
| | MR-010 (3, stretch) | 23:33:29 → 23:42:03 | 8.6 | |
| 2 card-database | CDB-006 (1, opener) | 22:21:46 → 22:35:01 | 13.2 | |
| | CDB-007 (0.5) | 23:01:05 → 23:07:32 | 6.5 | |
| | CDB-008 (1) | 23:09:15 → 23:16:18 | 7.0 | |
| 3 card-effects | CE-002 (1, opener) | 23:02:49 → 23:14:04 | 11.2 | |
| | CE-004 (0.5, re-opener) | 00:00:04 → 00:09:39 | 9.6 | waited 23:15 → 00:00 for MR-010 to merge |
| | CE-005 (1) | 00:18:18 → 00:25:27 | 7.2 | + 7.0 re-verification after a restart (01:33–01:40) |
| | CE-006 (1, stretch) | 01:40:49 → 01:50:46 | 9.9 | "a container restart cost no work on this story" |
| 4 rng-event-log | RNG-003 (1, opener) | 22:21:58 → 22:30:44 | 8.8 | |
| | RNG-008 (0.5) | 22:31:41 → 22:33:59 | 2.3 | |
| | RNG-010 (0.5) | 22:34:40 → 22:42:46 | 8.1 | |
| 5 match-ui | MUI-001 (3, opener) | 22:59:16 → 23:16:21 | 17.1 | |
| | MUI-002 (3) | 23:33:36 → 23:39:32 | 5.9 | |
| 6 content | content 001 (3, opener) | 00:01:35 → 00:06:59 | 5.4 | GDD and code reading from 23:55, so about 12 min in all |
| | content 007 (1) | 00:08:06 → 00:16:30 | 8.4 | |
| | BOOT-006 (0.5, stretch) | 00:18:19 → 00:24:36 | 6.3 | interrupted by a restart before commit; resumed 01:33:58–01:37:40 and re-captured 01:40:33–01:43:00 (+ 6.2) |

- **Total: 182.8 agent-minutes for 20 stories, plus 13.2 min of restart recovery (196 in all).** Mean 9.1 min, median 8.2 min, range 2.3–22.4 min. That works out to 6.2 min per story-day.
- **Openers vs. follow-ons.** The 7 openers (counting CE-004's re-open on a new branch) averaged 11.2 min. The 13 follow-ons averaged 8.0 min. Sprint 2 measured 11.6 and 5.8. The opener premium shrank because the follow-ons got heavier: 9 of the 20 stories are `full`-tier match-rules and card-effects work.
- **Lane throughput:**

  | Lane | Stories | Agent-min | Min per story | Est. days |
  |---|---|---|---|---|
  | 1 match-rules | 5 | 55.8 | 11.2 | 11 |
  | 2 card-database | 3 | 26.8 | 8.9 | 2.5 |
  | 3 card-effects | 4 | 37.9 (+7.0) | 9.5 | 3.5 |
  | 4 rng-event-log | 3 | 19.2 | 6.4 | 2 |
  | 5 match-ui | 2 | 23.0 | 11.5 | 6 |
  | 6 content + boot | 3 | 20.1 (+6.2) | 6.7 | 4.5 |

- **The critical lane** carried 5 links in 80 min of wall clock (22:21 → 23:42), 55.8 of them agent time. Between links it waited for the M1 merge and the review.
- **Wall clock.**
  - Lanes ran 22:21 → 01:50, 3 h 29 min. Without the restart gap the work fitted in about 2 h 20 min.
  - Two gaps account for the rest:
    - Lane 3 waited 45 min (23:15 → 00:00) for MR-010 to merge at M2.
    - About 68 min (00:25 → 01:33) were lost to the container restart that interrupted CE-005 and BOOT-006.
  - The review-fix pass and the final merge ran 02:02 → 02:19.

### Velocity Trend

| Sprint | Planned | Completed | Rate | Agent-min | Wall clock |
|--------|---------|-----------|------|-----------|-----------|
| 1 | 10 stories / ≈ 11 d | 10 / 11 d | 100% | not logged | 1 session |
| 2 | 15 + 2 stretch / ≈ 14 (+1) d | 16 / 14.5 d | 100% committed (94% incl. stretch) | 128 | ≈ 70 min |
| 3 (current) | 17 + 3 stretch / ≈ 25 (+4.5) d | **20 / 29.5 d** | **100% committed, 100% incl. stretch** | 183 (+13 recovery) | ≈ 4 h (≈ 2 h 20 min net of the restart gap) |

**Trend: Increasing.** Stories rose 16 → 20 (+25%) and story-days 14.5 → 29.5 (+103%), and the critical lane went from 3 links to 5. For the second sprint running, scope stopped the lanes before agent time did. Wall clock rose because of the three review rounds, the M2 dependency wait and the restarts, not because the stories were slow.

### What Went Well
- **Every story landed, stretch included.** All 20 stories are done, and the critical lane carried 5 links (MR-006 → MR-010), one more than committed. With MR-010 in, CE-004, CE-005 and CE-006 could all close in W3.
- **The CE-002 split paid off as predicted.** CE-002's `clone()` check moved to MR-017. CE-002 then needed only MR-008 and CDB-006, ran in W2, and unblocked `card_effects.json`. From there: content 001 in W3, real-data `Boot.boot()` Ready, and BOOT-006's `main_menu` frame.
- **Single owner for `boot.gd` held.** No lane commit touches `src/core/boot.gd`. The validator lines arrived only in orchestrator merges:
  - `fdb4dd0`: content 007's `content_budgets` registration.
  - `3e1fac5`: the effects adapter now passes `EffectValidator.stage7_caps(bodies)`.

  No merge message records a conflict, against sprint 2's three-lane hand-merge.
- **Independent review found real defects before dependents built on them.**
  - Seven stories were reviewed (MR-006 … 010, CDB-006, CE-002). Sprint 2 reviewed none of its 16.
  - The review found one **blocking** defect: `match_ended` was lost when the event log hit its cap, leaving a Faulted log that was never sealed.
  - It also found about 13 should-fix items: the hook re-entry guard, a per-command step cap, the `resolving` zone left set on a halt, the missing `on_hero_power` and effect-summon `on_summon`, `EffectRuntime` accepting StringName, the projection of a non-null `fizzled`, and others. All were fixed and merged (`413c165`, `91cb070`).
  - Two designer defaults came out of the review: DD-X13 (setup draws skip `on_draw`) and DD-X14 (fatigue has no source). So did four ADR errata, recorded the same day.
- **CI now ships a playtest build.** `windows-export.yml` uploads a debug artifact next to the release one (`bec8ede`). A release build opens on `data_error` by design while validators are pending, so without the debug build the owner would have nothing playable to launch. The last run carried both artifacts.
- **Tests 668 → 1078 (+61%)**, 0 orphans, and the perf budgets moved out of the blocking run (`-i res://tests/performance`) as the QA plan required.

### What Went Poorly
- **The container restarted three times mid-sprint** (orchestrator checkpoint).
  - What the story notes show: two stories lost uncommitted work in one window, CE-005 and BOOT-006 (00:25 → 01:33, about 68 min of wall clock and 13 min of re-verification). CE-006 records a restart that "cost no work".
  - The brief said each restart cost an interrupted story. The notes support two interrupted stories, not three. The third restart is not recorded in any story file.
  - Recovery worked because finished stories were already committed, and stopped agents could be resumed. The lesson is to commit each story as soon as its suite is green, before verification write-ups.
- **The W3 stories went unreviewed.** 13 of 20 stories have no independent review, among them CE-004/005/006, CDB-007/008, content 001/007, BOOT-006, MUI-002 and RNG-003/008/010. The plan deferred W3 reviews to sprint 4 W1, but CDB-008 [C] and CE-004 … 006 (`full` tier) are shared-contract or high-tier work.
- **The story files under-report review.** The seven reviewed stories still read "Reviewed by: self, no independent review". The verdicts live only in `active.md` and the fix commits.
- **A lane idled on a stretch dependency for 45 min.** CE-004 AC-07 and CE-005/006 needed stretch MR-010. MR-010 landed, but lane 3 waited 23:15 → 00:00 for the M2 merge.
- **The event-log append budget is marginal, not settled.**
  - RNG-010's notes record 50.8–60.2 ms against the 50 ms budget.
  - This close-out measured 32.8, 47.0 and 44.9 ms on the last three CI runs, all passing.
  - Locally it measured 57.4, 46.5 and 47.0 ms: 1 miss in 3.
  - So it hovers at the budget rather than missing it every time. It is non-blocking by design, and the owner's decision is still open.
- **A defect in `sprint-status.yaml`.** The `card-database-006` entry has two `completed:` keys (`"2026-11-03"` and `""`). A YAML loader keeps the last one, so the story reads as having no completion date.

### Blockers Encountered

No story in `sprint-status.yaml` has `status: blocked`.

| Blocker | Duration | Resolution | Prevention |
|---------|----------|------------|------------|
| CE-004/005 blocked on stretch MR-010 (`655483e`) | 45 min (23:15 → 00:00) | MR-010 merged at M2 (`66640a4`) | Do not make a committed story depend on a stretch story. Either commit the dependency or move the dependent to stretch |
| Container restarts (×3) | ≈ 68 min wall clock in the worst window; 13 min of re-verification | Per-story commits kept finished work. CE-005's and BOOT-006's uncommitted work was re-verified (fixture generator byte-identical) and committed | Commit each story as soon as its suite is green (standing rule, Action 1). Record each restart in `active.md` with a timestamp |
| MR-008 blocking review finding (`match_ended` lost at the log cap) | Fixed inside MR-009's window (23:06–23:14) | `413c165` | Keep the review lane per wave. The finding landed before M2 merged CE-002 on top of it |

### Estimation Accuracy

Each story is scaled by the sprint's own mean rate, 6.2 min per story-day.

| Task | Estimated | Actual | Variance | Likely cause |
|------|-----------|--------|----------|--------------|
| CE-004 validator step bound (most underestimated) | 0.5 d (≈ 3.1 min) | 9.6 min | +210% | Re-opened the lane on a new branch after a trunk merge, which meant reloading context |
| RNG-010 determinism + perf | 0.5 d (≈ 3.1 min) | 8.1 min | +161% | Also built the CI perf job and the `-i` exclusion |
| content 001 batch-0 data (most overestimated) | 3 d (≈ 18.6 min) | 5.4 min (≈ 12 with reading) | −71% | Data authoring against settled schemas; the validators did the checking |
| MUI-002 AnimationQueue | 3 d (≈ 18.6 min) | 5.9 min | −68% | Follow-on to MUI-001, reusing its fixture and types |

**Overall estimation accuracy**: 3 of 20 stories (15%) within ±20% of the scaled estimate (CDB-008, CE-005, MUI-001). Sprint 2 managed 31%.

By label, S stories took 6.6 min on average, M 8.6 min and L 12.1 min. That is a ratio of 0.8 : 1 : 1.4 against the labels' 0.5 : 1 : 3. Size labels order the work loosely, and position in the lane still matters more. For sprint 4, count work in links per lane, an opener or a re-open after a merge as 2 links, and an L as about 1.5 links, not 3.

### Carryover Analysis

No story carries over. Open items that carry:

| Item | Original sprint | Times carried | Reason | Action |
|------|----------------|---------------|--------|--------|
| Independent `/code-review` of the W3 stories (CE-004/005/006, CDB-007/008, content 001/007, BOOT-006, MUI-002, RNG-003/008/010) | 3 | 0 (planned for sprint 4 W1) | The plan put W3 reviews in the next sprint | Review lane in sprint 4 W1, CDB-008 and CE-004 … 006 first |
| Owner review of BOOT-006's frames + Windows row of the debug build | 3 | 0 | Owner-only | Launch `deckdelve-windows-debug-<sha>` |
| CDB-007 Windows known-answer check | 3 | 0 | Owner-only machine | Owner, with the BOOT-006 launch |
| First Playable re-date acceptance | 2 | 2 | Owner decision | See below |
| Owner weekly hours (gate condition 3) | 1 | 3 | Owner decision | Still open |

### Technical Debt Status
- TODO: 38 (34 in `src/`, 4 in `tests/` outside fixtures). Previous: 36 (29 / 7).
- FIXME: 0 (previous 0). HACK: 0 (previous 0).
- Trend: **growing slowly** (+2 overall, +5 in `src/`). These are still cross-epic `TODO(<epic>)` seams.
- Areas of concern:
  - **`PENDING_CONFIG_OWNERS`: 7 configs + 2 record kinds.** It was 9 placeholders at sprint-2 close. Every release export fails its load until this list is empty.
  - **ADR-0006 gap.** `CardDatabase.reload()` should return `E_BUSY` while a planner task is live. CDB-008 shipped `reload()` without that check, and no story owns it (CDB-008 note).
  - **G7** (field-list gate over `src/gameplay/effects/`) still has no CI gate or owning story, and CE-002/004/005/006 grew that directory.
  - **`validate.gd` leaks at exit**: 10 ObjectDB instances and 4 resources, exit code still 0 (smoke observation).

### Previous Action Items Follow-Up

| Action item (from sprint 2) | Status | Notes |
|-------------------------------|--------|-------|
| 1. Single owner for `boot.gd` `_collect_validators()` | **Done** | No lane commit touches `boot.gd`; the orchestrator added the lines in `fdb4dd0` / `3e1fac5`. The per-system registration table is not built |
| 2. Independent `/code-review` of MR-003, RNG-002, CDB-004 before dependents merge | **Done** | Fix pass `53ae9d4` / `34c3a49` / `d041c96` merged `2c8295a` at 22:20, before any lane started |
| 3. Owner decisions (re-date, hours, CE-002 split, first light) | **Partly done** | CE-002 split applied. Windows first light done on 2026-11-03 (`production/qa/evidence/windows-first-light-2026-11-03/`). Re-date acceptance and weekly hours are still open |
| 4. BOOT-006 → blocked; `capture.sh` `--` pass-through | **Done** | Blocked until content 001 merged. BOOT-006 added `--` and `CAPTURE_LABEL` |
| 5. `-c` when diagnosing merges; lane-prefixed scratch | **Done** | The reviews ran `commands.test -c`. No scratch collision was recorded |
| Process: [C] contract-tightening merges last | **Done** | CDB-006/008, CE-002 and content 001 merged last in their waves; no fixture fallout reached the trunk |

### First Playable re-date (from the measured critical path)

- **Delivered**: MR-006 … MR-010, all 5 critical links. That is the stretch rate (5 per sprint) the sprint-3 plan named as the condition for sprint 6.
- **Remaining path: 15 links.**
  - MR-012 → 013 → 014 → MR-017. MR-017 also needs MR-011, 015 and 016 on a parallel lane.
  - BAI-004 / 005 / 007 / 008 / 013 / 015.
  - MUI-004 → 005 → 008 → 011 → 012, the longer of the two branches after BAI-015.
- **Measured rate.** The critical lane did 5 links in 56 agent-min and 80 min of wall clock. Agent time is not the limit. The limit is waves and review: a dependent link waits for its predecessor's merge, and for that merge's review.
- **Outlook:**
  - **Sprint 6 (2026-12-02 → 12-08)** at the measured 5 links per sprint: 15 / 5 = 3 sprints (4, 5, 6).
  - **Sprint 7 (2026-12-09 → 12-15)** stays the fallback.
  - Sprint 5 would need about 8 links per sprint on the critical lane. That needs at least 4 waves per sprint or reviews that do not hold the next link, and nothing measured shows it.
- **Conditions, none of them agent time:**
  1. Sprint 4 runs **two match-rules lanes** (MR-012 → 013 → 014, and MR-011 / 016 / 015), so that MR-017 lands by sprint-4 M3 and BAI-004 can open in sprint 5 W1.
  2. UX specs for hand, targeting, mulligan and match-end (gate condition 11) before MUI-005/008/011 reach readiness.
  3. `/create-stories heroes` before BAI-016 / CE-011.
  4. The owner accepts the re-date.
- **Recommendation**: re-date First Playable to **sprint 6**, with sprint 7 as the fallback if MR-017 misses sprint 4.

### Action Items for Next Iteration

| # | Action | Owner | Priority | Deadline |
|---|--------|-------|----------|----------|
| 1 | **Standing rule: commit each story the moment its suite is green.** Write the Completion Notes in a follow-up commit if needed. After any restart, resume stopped agents by id. Log each restart in `active.md` with UTC time and the stories it hit | orchestrator; add to `/dev-story` lane protocol | High | Sprint 4, from the first story |
| 2 | **Write a story for the ADR-0006 gap.** `CardDatabase.reload()` returns `E_BUSY` while a planner task is live; a test drives a live `PlannerTask`. It belongs in card-database, with a boss-ai test dependency | producer via `/create-stories` (card-database) | High | Sprint 4 plan |
| 3 | **Review lane in sprint 4 W1 for the 13 unreviewed sprint-3 stories**, CDB-008 and CE-004 … 006 first. Update each story's "Reviewed by" line with the verdict, including the 7 already reviewed | lead-programmer via `/code-review` | High | Sprint 4 M1 |
| 4 | **Owner decisions:** accept First Playable at sprint 6 (fallback 7); give weekly hours (carried 3×); launch the debug Windows artifact for BOOT-006's Windows row and the CDB-007 known answer; decide the event-log append budget (raise it, or optimise after a release-build measurement) | Jacob | High | Before `/sprint-plan new` (sprint 4) |
| 5 | **Fix the duplicate `completed:` key on `card-database-006`** in `sprint-status.yaml` | producer (`/sprint-plan` or `/story-done`) | Low | Sprint 4 plan |

### Process Improvements
- **Sprint 4 sizing: 6–7 lanes × 3–4 links, about 20–22 stories**, as far as eligible stories exist.
  - Two match-rules lanes carry the critical path to MR-017 by M3.
  - Count an opener, or a re-open after a merge, as 2 links, and an L as about 1.5.
  - Keep 3 waves, with one fix buffer per wave.
  - The measured basis is 20 stories in 183 agent-min over 6 lanes, with the slowest lane at 56 min. Capacity is not the limit; dependency eligibility is.
- **No committed story depends on a stretch story.** Lane 3's 45-minute wait came from committed CE-004/005 needing stretch MR-010. A story that needs a stretch dependency becomes stretch itself, or the dependency becomes committed.
- **Reviews keep pace with the waves.** Review W1 and W2 inside the sprint as now, and add a W3 review slot before close (or W1 of the next sprint). Record the verdict in the story file's "Reviewed by", not only in `active.md`.

### Summary
Sprint 3 delivered all 20 stories, all 3 stretch stories included: 29.5 story-days in 183 agent-minutes. The critical lane carried 5 links. Tests went from 668 to 1078, both CI workflows are green with a debug playtest build, and the shipped data loads `Ready` with 0 errors. Throughput is not the constraint. Uncommitted work lost to container restarts was, along with a dependency wait on a stretch story and review coverage that stopped at W2. The most important change is committing each story the moment it is green. On the measured 5 links per sprint, First Playable moves to sprint 6 (2026-12-08), provided sprint 4 runs two match-rules lanes to MR-017 and the owner accepts the date.
