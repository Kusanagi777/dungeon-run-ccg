## Retrospective: Sprint 5 — Match driver, planner, heroes, treasures and the hook chain
Period: planned 2026-11-25 to 2026-12-01; run 2026-11-04 to 2026-11-05 (local Windows session, about 14 h from the first lane to the last commit)
Generated: 2026-11-05

### Metrics

| Metric | Planned | Actual | Delta |
|--------|---------|--------|-------|
| Tasks (stories) | 28 committed + 3 stretch | **26 done**, all committed; 0 stretch | −2 committed |
| Completion rate | -- | **93% committed (26/28)**; 84% including stretch (26/31) | second sprint in a row below 100% |
| Story-days (relative label) | ≈ 27.5 committed | ≈ 24 done | −3.5 (MR-019 L, MR-018) |
| Critical-lane links | BAI-007 → 008 → 013 → 015 | **All 4**; BAI-015 merged at M2, as planned | 0 |
| Bugs found (independent review) | -- | **14 blocking** across 6 reviews, 2 of them pre-existing | -- |
| Bugs fixed | -- | **All 14**, before the wave that needed them | -- |
| Unplanned tasks added | -- | Windows baseline, TD-013, pre-W2 and pre-W3 owner-decision lanes | 4 |
| Commits | -- | 116 (93 non-merge), 19 of them `fix` | -- |
| Tests | 1403 at sprint-4 close | **2345** in 127 blocking suites, 0 failures, 0 orphans | +942 |
| Code | -- | `src/` +6076 / −390; `tests/` +29777 / −341 | -- |

Smoke: `production/qa/smoke-2026-11-05-sprint-005.md`, **NOT ASSESSED** on one item only: CI on the sprint HEAD was not read. Everything observed passed.

### Velocity Trend

| Sprint | Planned | Completed | Rate |
|--------|---------|-----------|------|
| 3 | 17 + 3 stretch | 20 | 100% committed, 100% incl. stretch |
| 4 | 22 + 3 stretch | 22 | 95% committed, 88% incl. stretch |
| 5 (current) | 28 + 3 stretch | 26 | 93% committed, 84% incl. stretch |

**Trend: Increasing throughput, stable rate.** Delivered stories rose 22 → 26 (+18%). Both misses are one open question, the rules engine budget, so the rate understates the sprint.

Agent-minutes are **NOT ASSESSED — NO DATA**: restarts and a stall distort several stories' start and end times, so a total would mislead. BAI-008's 19:57 to 21:51 window, for one, includes a session restart.

### What Went Well

- **The sprint goal landed on plan.** BAI-015 merged at M2, and a test now runs four boss turns on shipped data through planner, controller, view, queue and router with no fault.
- **Independent review in the wave paid for itself.** It found 14 blocking problems the tests had passed, among them two hidden-information leaks (the forecast and `MatchQuery`), a silent main-thread planner, a gate that passed on an empty folder, and 2 pre-existing defects that would have stopped 3 of 5 boss passives firing. This was retro-4's top action, and it worked.
- **Golden logs did their job.** They failed at the L5 merge. Stripping one token proved all 218 changed lines were a single intended state field, with every event unchanged, before any regeneration.
- **Mutation testing found real weak tests.** BAI-014's run exposed two tests that could not fail. Lane 2 fixed both.
- **MR-019 halved `t_sim`** (573 → about 300 us) and kept all 16 goldens byte-identical.
- **The stop rule worked.** Lanes stopped on real design gaps rather than inventing rules, which gave the owner seven clean decisions (DD-X26 to DD-X31 and content 010).
- **Landing owner decisions before a wave** (pre-W2, pre-W3) kept MR-019's goldens valid and let treasures 005 start on a real event.

### What Went Poorly

- **Local Windows setup cost about a quarter of the sprint's start.** The suite failed 16 tests on CRLF, path and encoding differences, and a shutdown crash (TD-013) made exit codes random. All were fixed, but the cloud had never exercised this platform.
- **Reviewer scope broke once.** A read-only reviewer ran a checkout and detached the main checkout, so one fast-forward moved HEAD and not the branch. It was found at the next merge and nothing was lost, but only because `git status` was read. A branch guard now exists.
- **A session restart mid-wave** killed background agents and left a mutant in `boss_ai.gd`. Lane 1 caught it in the diff before its gate. A stall and a network drop later cost time too.
- **Orchestrator brief errors.** Three briefs were wrong: Mass Rites "must no longer interleave" (the chosen rule still alternates), "add the failing test" (which would have turned the suite red), and a claim that band 2 "fits" from one good run. Each was caught, but each cost a correction.
- **Single performance runs misled twice.** 491 us and 23.8 ms looked like a regression and were machine load. Only interleaved runs across stages settled it.
- **Linux CI was never read.** `gh` is not logged in, so the first cross-OS check of the goldens and of this sprint's platform fixes is still unseen.

### Blockers Encountered

No story has `status: blocked`. Two are open:

| Blocker | Duration | Resolution | Prevention |
|---------|----------|------------|------------|
| MR-019 AC-3: chain about 14 to 18 ms debug against the 10 ms gate (blocks MR-018) | Open at close | Owner's R6 decision, after a release measure | Measure on a release template, which needs installing locally |
| No export template on the local machine | Whole sprint | Open | Add to local setup |
| Windows baseline red, TD-013 crash | About a quarter of a day | Fixed, `027416d` and `f8b666f` | Run the suite on Windows in CI, or at least before each sprint |

### Estimation Accuracy

Actual effort per story is **NOT ASSESSED — NO DATA** at story level, for the reason under Velocity Trend. By link count, the plan held: every lane finished its committed links except L6, whose miss is a budget and not a schedule problem. Sizing by lanes and links (retro-4) continues to be a better fit than story-days.

The plan did not size review-fix work inside the waves. Every wave needed a return trip to a lane after review, so a wave's real end is one review cycle after its last merge.

### Carryover Analysis

| Task | Original Sprint | Times Carried | Reason | Action |
|------|----------------|---------------|--------|--------|
| MR-018 performance budgets | 4 | 2 | Waits for MR-019 and R6 | Close on R6 |
| MR-019 engine performance pass | 5 | 1 | AC-3 missed; R1 to R3 landed, R4 measured slower | Owner R6; R5 boss-ai F7 counts after |
| BAI-019 (stretch) | 5 | 1 | Not started; edits `boot.gd` | Sprint 6 |
| Treasures 008 (stretch) | 5 | 1 | Not started | Sprint 6 |
| MUI-004 (stretch) | 5 | 1 | Not started; L, needs owner screenshots | Sprint 6, first in the match-ui chain |

### Technical Debt Status

- TODO: 18 in `src/` (previous 23). FIXME: 0 (0). HACK: 0 (0).
- Trend: **Shrinking**, while `src/` grew by about 5700 lines.
- Areas of concern:
  - **Rules engine budget:** see R6. Band 2 sits at about 500 ms, on the target line; band 3 is about 1700 ms, over it. R5 is still to do.
  - **TD-013 anchors** in `MetaApi` and `PlannerTask` stay until Godot 4.8. `--import` still exits 139 about 1 run in 20, cause unconfirmed.
  - **`PENDING_CONFIG_OWNERS`: 6, records 0** (was 7 and 1). Release exports still open on `data_error` by design.
  - **`driver_factory` has no owning story,** and First Playable needs it.
  - **`minion_summoned` omits `keywords[]`,** so printed keywords never reach the view.
  - **Windows-only verification** of everything since `811d440` until CI is read.

### Previous Action Items Follow-Up

| Action Item (from Sprint 4) | Status | Notes |
|-------------------------------|--------|-------|
| 1. Close the review gap; review every Logic story in its wave | **Done** | All 13 verdicts recorded, and every wave reviewed in-wave. The biggest return of the sprint |
| 2. Engine performance and planner budget | **Partly** | MR-019 ran in its own lane; `t_sim` halved. R5 and R6 still open |
| 3. Write the missing stories | **Done** | Before the sprint |
| 4. Owner decisions | **Partly** | (a), (b), (d) done. **(c) NC-5 not done: carried a third time** |
| 5. Lane hygiene | **Mostly** | General-purpose lanes, commit before idle, no hand edits to status. Pauses were not logged with UTC in `active.md` |

### Action Items for Next Iteration

| # | Action | Owner | Priority | Deadline |
|---|--------|-------|----------|----------|
| 1 | **Read Linux CI on `d181790`** and fix anything red; run `gh auth login` so CI can be read here. Re-run `/smoke-check` to move the verdict off NOT ASSESSED | Jacob, then orchestrator | High | Before sprint 6 W1 |
| 2 | **R6:** install export templates, measure a release build, decide keep or re-budget the 10 ms gate, then close MR-018 and run R5 on boss-ai F7 | Jacob; technical-director for R5 | High | Sprint 6 W1 |
| 3 | **Write the two missing pieces of First Playable:** a story that owns `driver_factory`, and one adding `keywords[]` to `minion_summoned`, with a reviewed golden change | producer | High | Sprint 6 plan |
| 4 | **Make the local environment boring:** `godot` on PATH, a committed per-worktree `user://` wrapper, a Windows screenshot path for MUI-004. All of it is scratchpad-only today | tools-programmer | High | Sprint 6 W1 |
| 5 | **NC-5**, third carry: run the exported debug build, including repeated quits for TD-013 | Jacob | Medium | Before playtest #1 |

### Process Improvements

- **Land owner decisions before the wave they constrain,** in a short pre-wave lane. Plan one per wave.
- **Compare performance only with interleaved runs,** and never quote one.
- **Every review brief forbids moving HEAD,** and the merge tooling checks the branch before it acts.

### Summary

A strong sprint: the boss plays real turns on shipped data, First Playable's M3 check is met, and 942 tests were added with every blocking review finding fixed in its wave. Sprint 6 stays the First Playable target, but two things could still move it: the unread Linux CI, and `driver_factory`, which nothing owns yet. The single most important change is to make the local environment reproducible, because everything this sprint relied on for Windows lives in a scratchpad.
