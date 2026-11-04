## Retrospective: Sprint 4 — Combat, choice and clone; card-effects observers to Discover; MVP-1 data
Period: planned 2026-11-18 -- 2026-11-24; executed 2026-11-04 02:34 -- 14:55 UTC (lanes 02:44 → 05:16 and 14:09 → 14:55; about 3 h 18 min active around an 8 h 53 min container pause)
Generated: 2026-11-04 by `/retrospective sprint-4` (followed by hand: the skill cannot be model-invoked. Subagent run under the owner's standing approval; no AskUserQuestion; automation guided)

**Inputs** (FOUND unless marked):
- `production/sprints/sprint-004.md` and `production/sprint-status.yaml` (reconciled at close, `0b19ad6`).
- The 25 sprint-4 story files, read for their Status, Completion Notes start/end UTC and "Reviewed by" lines; match-rules story 019 (the follow-up).
- `git log 301dc2f^..75252ba` (`--since=2026-11-04T02:30`): 123 commits (30 merges, 93 non-merge; 21 titled "merge: sprint 4 …"), HEAD `75252ba`.
- `production/retrospectives/retro-sprint-3-2026-11-04.md`.
- `production/qa/smoke-2026-11-04-sprint-004.md` (PASS, 1403/1403) and `production/qa/perf-match-rules-2026-11-04.md`.
- Review reports (session scratchpad `reports/`): `code-review-s3-unreviewed`, `code-review-s4-mr012-014`, `code-review-s4-mr011-016`, `code-review-s4-mr015-017`, `code-review-s4-bai004-006`, `ux-review-s4-round1`, `-round2`, `-round3-match-end`.
- Orchestrator observations (relayed in the brief): subagent turn caps, worktree deletions, the container pause, the committer-identity hook and the `filter-branch` rewrite, review coverage, owner and designer decisions, the perf finding and the First Playable question.
- `design/design-decisions.md` rows DD-X15 … DD-X18.

Not available:
- Milestone file: ABSENT (`production/milestones/` does not exist).
- Bug tracker: ABSENT. "Bugs" below means code-review findings.
- Owner time log: ABSENT. Owner hours against the 12 h budget are **NOT ASSESSED — NO DATA**.
- Session checkpoint for sprint 4: `production/session-state/active.md` was last written at 03:02 UTC. The pause, the worktree losses and the resumes are not in it; they come from story notes and the orchestrator's brief.
- Commit timestamps as a timing source: the `filter-branch` rewrite left lane commits clustered at 03:02, 03:17 and 03:20 author time. Durations below use the Completion Notes only.

### Metrics

| Metric | Planned | Actual | Delta |
|--------|---------|--------|-------|
| Tasks (stories) | 22 committed + 3 stretch (CE-009, BAI-006, CE-014) | **22 done**: 21 committed + 1 stretch (BAI-006). MR-018 In Progress (blocked); CE-009 and CE-014 not started (blocked) | −1 vs committed; −3 vs committed + stretch |
| Completion rate | -- | **95% committed (21/22)**; 88% including stretch (22/25) | first committed miss in four sprints |
| Story-days (relative label) | ≈ 24 committed (+2.5 stretch) | 23.5 done (+1 in progress) | −0.5 committed |
| Critical-lane links | 6 (MR-012, 013, 014, 017; BAI-004, 005) | **6**. MR-017 merged at M2 (`70947a5`, 04:13), as the sprint-6 date required | 0 |
| Bugs found (code review) | -- | **2 blocking** (RNG-008 from the sprint-3 review; BAI-004 B1) + **29 should-fix** (6 sprint-3 + 23 sprint-4) | -- |
| Bugs fixed | -- | Both blocking (`ed41bab`, `40877df`). Should-fix: all but 4, which are open or routed: MR-015 S3 (GDD conflict → CE-009 blocker), BAI S3 (`state()` drift until `MatchQuery`), MR-017 S8 and BAI S6 (cost vs F7 → story 019) | -- |
| UX specs | 4 (hand, targeting, mulligan, match-end), non-story, idle match-ui lane | 4 APPROVED after 3 review rounds (4 NEEDS REVISION → 3 APPROVED + 1 → APPROVED); gate condition 11 met (`84a8fb7`) | -- |
| Unplanned tasks added | -- | MR-013 staged-model refactor (`5c61083`, orchestrator request); match-rules story 019 (`fe3f335`); DD-X15/16/17 designer defaults and DD-X18 owner decision; GDD/ADR sync and errata (`1d032d2`, `00d48bf`, `b32bbb1`); control manifest 2026-11-04 and gate condition 12 closed (`8cc1762`, `ad54ecc`); `RngStream.copy()` and `clone(rng_override)` (`238df81`, `cf1234c`); settings allowlist (`91d9ca1`) | -- |
| Commits | -- | 123 (93 non-merge, 30 merges) | -- |
| Tests | 1078 at sprint-3 close | **1403** (90 blocking suites + 4 non-blocking perf suites), 0 failures, 0 orphans | +325 (+30%) |

### Measured durations (from Completion Notes start/end UTC)

| Lane | Story (est. d) | Start → end (UTC) | Minutes | Note |
|------|----------------|-------------------|---------|------|
| 1 match-rules A (critical) | MR-012 (1, opener) | 02:45:59 → 02:53:11 | 7.2 | |
| | MR-013 (1) | 03:02:16 → 03:06:26 | 4.2 | + unplanned staged-model refactor after M1, ended 03:24:16 (start not logged) |
| | MR-014 (1) | 03:17:23 → 03:20:20 | 3.0 | |
| | MR-018 (1, re-open) | 04:15:14 → 04:40 | 24.8 | In Progress: `/story-done` BLOCKED on AC-40 |
| 2 match-rules B (critical) | MR-011 (0.5, opener) | 02:44:02 → 02:52 | 8.0 | turn-cap stop and a worktree move, no work lost |
| | MR-016 (1) | 03:02:14 → 03:14 | 11.8 | |
| | MR-015 (1, re-open) | 03:52:01 → 03:55:49 | 3.8 | |
| | MR-017 (3) | 03:56:44 → 04:11:08 | 14.4 | trunk merged mid-story (`042d5d4`) |
| 3 card-effects A | CE-008 (1, opener) | 02:46:18 → 02:55 | 8.7 | first worktree vanished mid-run, re-attached |
| | CE-007 (1) | 03:02:17 → 03:10 | 7.7 | |
| | CE-011 (1, re-open) | 03:45:31 → 03:53 | 7.5 | |
| | CE-012 (1, re-open) | 04:19 → 04:34 | 15.0 | reading from ≈ 04:05 |
| 4 boss-ai | CDB-009 (0.5, opener) | 03:45:38 → 03:53:55 | 8.3 | W1 was the sprint-3 review-fix buffer (03:02 → 03:43) |
| | BOOT-007 (0.5) | 03:54:00 → 03:58:15 | 4.2 | |
| | BAI-004 (1, re-open) | 04:22 → 05:14 | 52.0 | |
| | BAI-005 (1) | 05:15 → ≈ 05:25 | ≈ 10 | **committed 14:09**, after the pause |
| | BAI-006 (0.5, stretch) | 14:09 → 14:15 | 6.0 | |
| 5 content data | content 002 (1, opener) | 02:44:25 → 02:53:54 | 9.5 | |
| | content 003 (1) | 03:02:22 → 03:07:47 | 5.4 | |
| | content 005 (0.5, re-open) | 03:45:46 → 03:51:18 | 5.5 | |
| | content 004 (1) | 03:51:30 → 03:56:42 | 5.2 | |
| 6 tools + card-effects B | content 008 (1, opener) | 02:44:30 → 03:01:11 | 16.7 | resumed twice at the turn cap; worktree removed and recreated between |
| | CE-010 (3, re-open) | 03:45 → 04:05 | 20.0 | |

- **Total: 258.8 agent-minutes for 23 stories** (22 done + MR-018). Mean 11.3 min, median 8.0 min, range 3.0–52.0 min. That is 10.6 min per story-day (sprint 3: 6.2).
- **Openers and re-opens vs. follow-ons.** The 14 openers and re-opens averaged 13.8 min; the 9 follow-ons 7.3 min (sprint 3: 11.2 and 8.0). The premium is back: 9 of the 14 re-opened a lane after a merge, and two of them (BAI-004, MR-018) were the sprint's two outliers.
- **Lane throughput:**

  | Lane | Stories | Agent-min | Min per story | Est. days |
  |---|---|---|---|---|
  | 1 match-rules A | 4 | 39.1 | 9.8 | 4 |
  | 2 match-rules B | 4 | 37.9 | 9.5 | 5.5 |
  | 3 card-effects A | 4 | 38.9 | 9.7 | 4 |
  | 4 boss-ai | 5 | 80.5 | 16.1 | 3.5 |
  | 5 content data | 4 | 25.6 | 6.4 | 3.5 |
  | 6 tools + card-effects B | 2 | 36.7 | 18.3 | 4 |

- **The critical path.** L2 carried MR-011 → 016 → 015 → 017 in 89 min of wall clock (02:44 → 04:13 merge), 38 of them agent time. BAI-004 opened 9 min after M2. The pause, not the lanes, held BAI-004/005 off the trunk until 14:14.
- **Wall clock.**
  - W1 02:44 → 03:43 (M1 merges 03:02 → 03:43), W2 03:45 → 04:13 (M2 03:54 → 04:13), W3 04:15 → 05:16 (M3 05:15 → 05:16, then 14:14 → 14:55).
  - **Pause 05:16 → 14:09 (8 h 53 min).** BAI-005 had finished at ≈ 05:25 and sat uncommitted through it.
  - After the pause, 14:09 → 14:55: BAI-006, the MR-015/017 review fixes (14:09 → 14:25) and the BAI-004–006 review fixes (14:29 → 14:55).
  - Net of the pause, the sprint fitted in about 3 h 18 min, against sprint 3's ≈ 2 h 20 min net.

### Velocity Trend

| Sprint | Planned | Completed | Rate | Agent-min | Wall clock |
|--------|---------|-----------|------|-----------|-----------|
| 2 | 15 + 2 stretch / ≈ 14 (+1) d | 16 / 14.5 d | 100% committed (94% incl. stretch) | 128 | ≈ 70 min |
| 3 | 17 + 3 stretch / ≈ 25 (+4.5) d | 20 / 29.5 d | 100% committed, 100% incl. stretch | 183 (+13 recovery) | ≈ 4 h (≈ 2 h 20 min net) |
| 4 (current) | 22 + 3 stretch / ≈ 24 (+2.5) d | **22 / 23.5 d** | **95% committed (21/22), 88% incl. stretch** | 259 | ≈ 12 h 11 min elapsed (≈ 3 h 18 min net of the pause) |

**Trend: Stable.** Delivered stories rose 20 → 22 (+10%) and the critical lane delivered all 6 planned links. Story-days fell (29.5 → 23.5) because sprint 4's stories carry smaller labels; agent time per story rose (9.1 → 11.3 min) with heavier `full`-tier work. The one committed miss (MR-018) is a measured performance criterion, not a throughput shortfall, and the two missed stretch stories were blocked before they could start.

### What Went Well
- **The critical path landed on plan.** MR-017 merged at M2 (04:13), BAI-004 and BAI-005 landed in W3, and stretch BAI-006 came with them. This was the plan's stated condition for the sprint-6 date.
- **The Discover pause held from three sides.**
  - NC-1 (`match_rules_choice_test.gd`) and NC-2 (`card_effects_choices_test.gd`, through the real `EffectResolver`) both pass.
  - MR-017 clones at the pause.
  - The MR-015/017 review's probes found no shared mutable state between live and clone over 40 commands × 11 states, with both the double and the production resolver.
- **Reviews caught real defects before dependents built on them.**
  - BAI-004 B1: A18 was ticked, but on the merged `TieBreak.pick` path removal won only 20 of 40 seeds. It was fixed (`40877df`) before BAI-008 starts calling `pick`.
  - The sprint-3 review's blocking item (RNG-008 attribution read `instance_id`, the engine emits `entity_id`) was fixed in the L4 W1 buffer (`ed41bab`, merged `5237557`) before any lane built on the match summary.
  - About 25 should-fix items were fixed inside the sprint, in the reserved slots. On the boss-ai stories the review's surviving mutants went from 15/19 to 4/19 (`3d80389`).
- **The perf harness replaced an assumption with a number.** Boss-ai F7 assumed `t_sim` ≈ 0.01 ms; MR-018 measured 0.37–0.45 ms (CI at close: 0.39 ms). The owner decided DD-X18 (500 ms per planner run) the same day, and match-rules story 019 was written for the engine work.
- **Two gate conditions closed in idle capacity.**
  - Condition 11: the match-ui lane had no eligible story, so it ran the four UX specs through three review rounds to APPROVED.
  - Condition 12: BOOT-007's list went into control manifest 2026-11-04.
- **MVP-1 data is in and clean.**
  - 30 → 69 records load `Ready` with 0 errors, and `W_POOL_SIZE` fell 3 → 1.
  - `ai_profile` left the pending list (orchestrator-registered, `5f78fa7`), so content 003/004 "zero `E_AI_*`" is checked through the load rather than marked NOT ASSESSED.
  - The cheap prerequisite fixes from the plan worked: BAI-010 (a), `bundle_pool_min` (a), and `ai_profile` as in fix (a).
- **Tests 1078 → 1403 (+30%)**, 0 orphans. TODO count fell 38 → 27.

### What Went Poorly
- **The first committed miss: MR-018 (AC-40).**
  - The worst-case `submit` is 25.1 ms debug / 19.9 ms release against 5 ms; at close it measured 27.3 ms locally and 17.6 ms on CI.
  - `clone()` + one `submit` is 39× F7's assumption. The engine is too slow for Boss AI F7 as written: at 0.39 ms per node, band 2 needs 569 ms and band 3 2.3 s per turn. Band 1 (144 ms) fits DD-X18's 500 ms.
  - Systemic cause: both budgets were set in the GDD and ADR-0007 before anything was measured. The first measurement of `clone()` came from a reviewer (MR-015/017 S8) in W2, not from a story, and the budget story ran last (W3).
- **Review coverage is not what the orchestrator's note says.**
  - The orchestrator reports that every story got an independent `/code-review`. The reports and the story files show **10 of the 23 sprint-4 stories** reviewed (MR-011 … 017, BAI-004 … 006), plus the 13 sprint-3 carryovers.
  - The other 13 read "self", "lean" or "not reviewed": CE-007, 008, 010, 011, 012 (all `full` tier; CE-010 is an L and holds NC-2), content 002–005 and 008, CDB-009, BOOT-007, MR-018.
  - This is sprint 3's "W3 unreviewed" gap again, now covering the whole card-effects lane.
  - Every reviewed story's formal verdict is also NOT ASSESSED: the engine-specialist and qa-tester passes cannot be spawned from a reviewer context.
- **Subagent turn caps cost resumes.**
  - Lane types with a 20-turn cap (gameplay-programmer, tools-programmer, qa-lead) needed many resumes. MR-011 records one turn-cap stop; content 008 records two.
  - General-purpose lanes ran through without a stop.
- **Worktrees were deleted mid-run several times.**
  - CE-008's first worktree vanished, content 008's was removed and recreated, and MR-011's moved.
  - The branches survived each time, so no work was lost. Each loss still cost a re-attach and a resume, and none was logged in `active.md`.
- **An 8 h 53 min container pause (05:16 → 14:09).**
  - BAI-005 had finished at ≈ 05:25 but was committed only at 14:09. That breaks the standing rule (retro-3 action 1) for the one story the pause hit.
  - BAI-004/005/006 then merged, and were reviewed and fixed, after the pause.
- **The committer-identity hook arrived mid-sprint.**
  - 12 commits carry Jacob as committer: 5 planning commits before the lanes, then 7 lane or orchestrator commits from 03:02 → 03:43.
  - Lane copies were rewritten with `filter-branch` before merge. One lane merged the pre-amend commit, which left a duplicate on the trunk: `bb2d9f7` and `8d8f001` have the same message, author date and one-line change to story 016.
  - The rewrite also collapsed author dates, so `git log` no longer times the sprint.
- **`sprint-status.yaml` defects recurred.** content-008 had two `completed:` keys, the last one empty, which is the same defect as sprint 3's CDB-006. It was fixed at close (`0b19ad6`). BOOT-007's note still says "`/create-control-manifest` update pending", though `8cc1762` / `ad54ecc` closed it.
- **Owner items carried again.**
  - NC-5 (BOOT-006 Windows row and frames, CDB-007 known answer) is "not yet run" for the second sprint.
  - The append-budget decision is open for the second sprint; it measured 72 ms locally at close, 34 ms on CI.
  - Game-designer data sign-off for content 002–005 reads NOT ASSESSED (no agent).

### Blockers Encountered

No story in `sprint-status.yaml` has `status: blocked`. Three carry a `blocker` field, listed first.

| Blocker | Duration | Resolution | Prevention |
|---------|----------|------------|------------|
| **MR-018**: AC-40 worst-case `submit` 20–25 ms vs 5 ms; `t_sim` 0.39 ms vs F7's 0.01 ms | From 04:40 to now (open) | Story 019 (R1–R4 engine pass) written, Ready for sprint 5; DD-X18 raised the planner target; MR-018 stays In Progress until 019 re-measures | Measure before budgeting: a perf spike or harness story precedes any story whose ADR sets a wall-clock budget (Action 2) |
| **CE-009** (stretch): destroy-then-silence conflict, match-rules C12 vs card-effects AC-21 (review MR-015/017 S3) | Not started | Open: a GDD decision | Route review GDD conflicts to the designer the day they are found, before the dependent story's wave (Action 4) |
| **CE-014** (stretch): treasures `HookInstaller` missing | Not started | Open: no treasures stories | `/create-stories treasures` (Action 3); the plan already flagged it "certain unless fixed" |
| Container pause (05:16 → 14:09) | 8 h 53 min | Lanes resumed; BAI-005's uncommitted work survived | Commit before any idle point, not only "when green" (Action 5) |
| Subagent 20-turn caps; worktree deletions | Several resumes; MR-011, CE-008 and content 008 hit | Resumed by id; branches intact | General-purpose lanes; log each loss with UTC in `active.md` (Action 5) |

### Estimation Accuracy

Each story is scaled by the sprint's own mean rate, 10.6 min per story-day.

| Task | Estimated | Actual | Variance | Likely cause |
|------|-----------|--------|----------|--------------|
| BAI-004 scorer (most underestimated) | 1 d (≈ 10.6 min) | 52.0 min | +392% | First boss-ai story on the engine: the F1–F5 worked examples, the sandbox design, a re-open after M2, and folding in the MR-015/017 review's cost measurements |
| MR-018 perf budgets | 1 d (≈ 10.6 min) | 24.8 min | +135% | Built the harness and 56-pass fixtures, indexed the resolver double, measured on two builds |
| MR-014 combat keywords (most overestimated) | 1 d (≈ 10.6 min) | 3.0 min | −72% | Follow-on in L1, on MR-013's handler and fixtures |
| MR-017 clone and replay (L) | 3 d (≈ 31.7 min) | 14.4 min | −55% | `MatchState` was already plain data (MR-016's suspended queue); the L label assumed a harder deep copy |

**Overall estimation accuracy**: 6 of 23 stories (26%) within ±20% of the scaled estimate (MR-016, CE-008, BAI-005, BAI-006, content 002, content 005). Sprint 3 managed 15%.

By label, S stories took 6.4 min, M 12.0 min and L 17.2 min: a ratio of 0.53 : 1 : 1.43 against the labels' 0.5 : 1 : 3. S now matches its label. L is again ≈ 1.4, as sprint 3 found, so keep counting an L as about 1.5 links. The outliers were both re-opens that also absorbed measurement work; for sprint 5, a story that first runs a new subsystem on the real engine (BAI-007, BAI-008, story 019) counts as 2 links.

### Carryover Analysis

| Task | Original sprint | Times carried | Reason | Action |
|------|----------------|---------------|--------|--------|
| MR-018 performance budgets (In Progress) | 4 | 0 (into sprint 5) | AC-40 `submit` budget missed | Keep open; story 019 re-measures. If AC-3 of 019 still misses after R1–R4, the owner decides R6 (re-budget) and MR-018 closes on that decision |
| CE-009 Deathrattle snapshot (stretch) | 4 | 0 | GDD conflict (C12 vs AC-21) | Designer decision, then sprint-5 stretch in the card-effects lane |
| CE-014 value-hook folds (stretch) | 4 | 0 | Treasures `HookInstaller` missing | `/create-stories treasures` first; then schedule |
| Independent review of 13 sprint-4 stories | 4 | 0 | Not reviewed in sprint | Review lane in sprint 5 W1 (Action 1) |
| NC-5 owner Windows checks (BOOT-006 row and frames, CDB-007 known answer) | 3 | 1 | Owner-only machine | Owner, before the sprint-5 plan |
| Event-log append budget decision | 3 | 1 | Owner decision | Owner, before the sprint-5 plan |
| Content 002–005 data sign-off | 4 | 0 | Game-designer pass NOT ASSESSED (no agent); owner sign-off not recorded | Owner reads the four smoke records (≈ 1.75 h budgeted in sprint 4) |

### Technical Debt Status
- TODO: 27 (23 in `src/`, 4 in `tests/` outside fixtures). Previous: 38 (34 / 4).
- FIXME: 0 (previous 0). HACK: 0 (previous 0).
- Trend: **shrinking** (−11, all in `src/`): the sprint replaced cross-epic seams with code (choice phase, observers, auras, `ai_profile`).
- Areas of concern:
  - **Engine performance debt.** The worst-case `submit` is 3.5–5.5× its budget, and `clone()` + `submit` is 39× F7's assumption. The cost sits in `_recompute_auras` (≈ 60% of a plain command), `_find_record` scans and per-trigger candidate arrays (perf record R1–R3).
  - **`src/ai/**` reads `RulesEngine.state()`** (ADR-0007 Decision 4 drift, BAI review S3) until `MatchQuery` lands.
  - **`PENDING_*_OWNERS`: 7 configs + 1 record kind** (was 7 + 2). Every release export still opens on `data_error` by design.
  - **G7** (field-list gate over `src/gameplay/effects/`) still has no CI gate. The hand check at close found 0 direct writes over 18 files.
  - **Exit-time leaks** in `validate.gd` (10 ObjectDB / 4 resources) and the suite (3323 / 29), exit codes still 0.

### Previous Action Items Follow-Up

| Action item (from Sprint 3) | Status | Notes |
|-------------------------------|--------|-------|
| 1. Commit each story the moment its suite is green; resume by id; log restarts in `active.md` | **Partly done** | Per-story commits held for 22 of 23 stories, and resumes by id worked. BAI-005 sat uncommitted through the 9 h pause. `active.md` has no sprint-4 incident entry (last written 03:02) |
| 2. Story for the ADR-0006 `reload()` `E_BUSY` gap | **Done** | boss-ai-match-driver story 019 (`ae5f87c`), placed after BAI-015 |
| 3. Review lane for the 13 unreviewed sprint-3 stories | **Done** | `code-review-s3-unreviewed`: 12 approved (with suggestions), 1 blocking (RNG-008), fixed in L4 W1 (`5237557`); verdicts recorded in the stories (`cbd12aa`) |
| 4. Owner decisions (First Playable, hours, Windows launch, append budget) | **Partly done** | First Playable sprint 6 / fallback 7 and 12 h/week accepted (`301dc2f`); DD-X18 decided. Windows launch (NC-5) and the append budget are still open |
| 5. Fix the duplicate `completed:` key on `card-database-006` | **Done, but recurred** | CDB-006 is clean; content-008 had the same defect this sprint, fixed at close (`0b19ad6`) |
| Process: no committed story depends on a stretch story | **Done** | No lane waited on a stretch story |
| Process: reviews keep pace with the waves | **Partly done** | Every planned review (MR-013, MR-016, MR-017, BAI-004) and its fix slot ran, plus 6 more stories. 13 stories had none |

### First Playable outlook (accepted: sprint 6, 2026-12-08; fallback sprint 7)

- **Delivered this sprint**: all 6 planned critical links. MR-017 merged at M2, which was the plan's condition for sprint 6.
- **Remaining path (9 links)**:
  - BAI-007 (M) → BAI-008 (L) → BAI-013 (M) → BAI-015 (M) in sprint 5.
  - MUI-004 (L) → 005 (L) → 008 (L) → 011 (M) → 012 (M) in sprint 6.
  - The other branch after BAI-015 is BAI-016 → 017 → 018 → MUI-012, with boss-ai story 019 (`E_BUSY`) ahead of BAI-017.
- **What changed since the plan:**
  - **Story 019 (rules engine perf pass, L) is not on the band-1 path.**
    - First Playable is one War match against one band-1 boss (gate check, condition 5).
    - Band 1's 370 F7 nodes at the measured 0.39 ms take ≈ 144 ms, inside DD-X18's 500 ms per planner run.
    - Story 019 is needed before band 2 (569 ms) and band 3. It edits `rules_engine.gd`, which BAI-008 and BAI-013 call, so it must run in its own match-rules lane as [S], under byte-identical event logs. It must not sit in the boss-ai lane.
    - The DD-X18 propagation (`095526e`, story 019 AC-4 → ≤ 340 µs, and boss-ai A22 notes) is on branch `docs/s4-ddx18`, not yet on the trunk. It must merge before BAI-007/008 readiness.
  - **BAI-008 grew.** It now carries A3 and A5 from BAI-006 and the sim-stream wiring from the BAI-004 review. Count it as 2 links, which makes sprint 5's boss-ai chain ≈ 5 link-equivalents, the measured per-sprint rate with no slack.
  - **Sprint 6 is heavier than planned.** On the 1.5-per-L rule the match-ui chain is ≈ 6.5 link-equivalents. It also needs five UI screenshot sign-offs, BAI-018's Windows run and playtest #1 inside the owner's 12 h.
  - **The heroes epic still has no stories** (`EPIC.md` only). BAI-016 needs the War starter deck from it, and BAI-016 is on the BAI-016 → 018 → MUI-012 branch.
  - **Helps:** gate condition 11 is met (the four UX specs are APPROVED), so MUI-005/008/009/011 can reach readiness in sprint 5.
- **Recommendation: keep sprint 6 as the target, with lower confidence than at plan time.** Sprint 7 is now the likely date if any one condition slips:
  1. Sprint 5 lands BAI-007 → 008 → 013 → 015 in the boss-ai lane, with story 019 in a separate match-rules lane.
  2. `/create-stories heroes` lands in sprint 5 W1.
  3. `docs/s4-ddx18` merges before BAI-008's readiness check.
  4. Sprint 5 takes the boss-ai review reading off sprint 6's owner hours.
- **Decision point**: if BAI-015 has not merged by sprint-5 M3, declare sprint 7 at the sprint-5 close rather than at sprint 6.

### Action Items for Next Iteration

| # | Action | Owner | Priority | Deadline |
|---|--------|-------|----------|----------|
| 1 | **Close the review gap.** Run independent `/code-review` on the 13 unreviewed sprint-4 stories, starting with CE-010 (L, `full`, NC-2), then CE-012, CE-007, CE-008, CE-011, then content 008 and CDB-009; the content 002–005 data and BOOT-007 doc get summary reviews. Put the fixes in a sprint-5 W1 buffer, and record each verdict in the story's "Reviewed by". From sprint 5 on, schedule a review for every Logic story in its own wave, not only the reserved ones | lead-programmer via `/code-review`; orchestrator schedules | High | Sprint 5 M1 |
| 2 | **Engine performance and the planner budget.** Merge `docs/s4-ddx18`. Plan match-rules story 019 in its own [S] match-rules lane in sprint 5, never in the boss-ai lane. Run `/propagate-design-change` on boss-ai F7 (R5: re-derive `t_sim` and the band counts against 500 ms) before BAI-007/008 readiness. Going forward, a budget set by an ADR or GDD gets a measurement story in the same sprint as the first code that can be measured | producer (plan); technical-director (F7 / ADR-0006, ADR-0007); ai-programmer (counts) | High | Sprint 5 plan; F7 before BAI-008 readiness |
| 3 | **Write the missing stories.** `/create-stories heroes` (BAI-016 needs the War starter deck: First Playable branch) and `/create-stories treasures` (`HookInstaller` for CE-014) | producer | High (heroes) / Medium (treasures) | Sprint 5 W1 |
| 4 | **Owner decisions.** (a) The destroy-then-silence conflict (match-rules C12 vs card-effects AC-21): game-designer proposes, owner approves, as a DD row. (b) The event-log append budget, carried twice (72 ms local, 34 ms CI, against 50 ms): raise it or optimise after a release-build measurement. (c) NC-5 on `deckdelve-windows-debug-d26260566ef9…`, carried twice. (d) Sign off the content 002–005 data | Jacob (with game-designer for a) | High | Before `/sprint-plan new` (sprint 5) |
| 5 | **Lane hygiene.** Run lanes as general-purpose subagents (or lift the 20-turn cap). Commit before any idle point, not only when green. Log every pause, worktree loss and resume in `active.md` with UTC. Keep the committer-identity hook on from sprint start, and before any merge check `git log --format=%cn <lane>` instead of rewriting merged history. Lanes never hand-edit `sprint-status.yaml`; the orchestrator updates it at merge, and fixes BOOT-007's stale note | orchestrator | Medium | Sprint 5, from the first lane |

### Process Improvements
- **Measure before you budget.** Sprint 4's only committed miss was a budget nobody had measured until W3. When a story can first exercise a budgeted path (here MR-017's `clone()`), put the measurement in that story or the next wave, not at the end of the chain.
- **Review every Logic story in its wave.** The reserved-review list protected the critical path but left the whole card-effects lane unreviewed. Size the review lane by story count (≈ 1 review per 3 stories per wave) and give it a fix slot in the following wave.
- **Make the run environment boring.** Turn caps, deleted worktrees, a mid-sprint hook change and a 9 h pause each cost little alone, but together they produced an uncommitted story, a duplicate commit and an unreliable `git log`. Fix them before sprint 5 starts (Action 5), not in flight.

### Summary
Sprint 4 delivered 22 of 25 stories: 21 of 22 committed and 1 of 3 stretch, with all 6 critical links on time and MR-017 at M2. Tests rose to 1403, the MVP-1 data loads clean, and two gate conditions (11 and 12) closed. The one committed miss is a finding rather than a slip: the rules engine is 3.5–5.5× over its `submit` budget and 39× over F7's planner assumption. Story 019 and DD-X18 answer that. Band 1 already fits, so it does not move First Playable, but band 2 needs the engine pass. The most important change is to close the review gap (13 unreviewed stories, the whole card-effects lane) and to review every Logic story in its wave. First Playable stays at sprint 6 with lower confidence. Sprint 7 becomes the date if BAI-015 has not merged by sprint-5 M3 or the heroes stories are not written in sprint 5 W1.
