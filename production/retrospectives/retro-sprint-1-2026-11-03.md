## Retrospective: Sprint 1 — Foundation and spikes
Period: planned 2026-11-04 -- 2026-11-10; executed 2026-11-03 (one working session, before the planned start)
Generated: 2026-11-03 (`/retrospective sprint 1`, subagent run under the owner's standing approval; automation guided, review lean)

**Inputs** — FOUND: `production/sprints/sprint-001.md`, `production/sprint-status.yaml` (10/10 `done`, no yaml/plan discrepancy), the 10 story files' Completion Notes (all `> **Status**: Complete`), `git log fbe9592..HEAD`, `production/qa/qa-plan-sprint-001-2026-11-03.md`, `production/qa/smoke-2026-11-03.md` (PASS), `docs/tech-debt-register.md`, `docs/architecture/spikes/2026-11-03-dsl-effect-spike.md`. ABSENT: earlier retrospectives (first sprint), a bug tracker (`production/bugs/` does not exist), per-story effort time (agents logged no hours).

### Metrics

| Metric | Planned | Actual | Delta |
|--------|---------|--------|-------|
| Tasks (stories) | 10 | 10 done | 0 |
| Completion Rate | -- | 100% | -- |
| Story-days (`/create-stories` scale: S 0.5, M 1, L 3) | ≈11 committed vs 4 available | 11 completed | +7 over available |
| Calendar | 5 working days | 1 session (implementation commits 19:03–19:52 UTC; sprint plan committed 18:39) | -5 days |
| Tests (gdUnit4 cases) | -- | 66 → 301 (+235: 31 RNG, 17 CE, 30 BAI, 10+11+50+12 BOOT, 17+18 MR, 39 CDB) | +235 |
| Bugs Found | -- | 1 (merge break, shared test helper) | -- |
| Bugs Fixed | -- | 1 (`0448510`, same session) | -- |
| Unplanned Tasks Added | -- | 0 stories; 4 doc/fix commits (`b30c1c8`, `754fab9`, `53a1697`, `0448510`) | -- |
| Commits | -- | 24 since the QA-plan/story prep (10 feat, 7 merge, 3 docs, 2 chore, 1 test, 1 fix) | -- |

### Velocity Trend

| Sprint | Planned | Completed | Rate |
|--------|---------|-----------|------|
| 1 (current) | 10 stories / ≈11 story-days | 10 stories / 11 story-days in 1 session | 100% |

**Trend**: NOT ASSESSED — NO DATA (first sprint; nothing to compare against).
**Measured velocity: 10 stories (11 story-days: 2 S, 7 M, 1 L) per working session**, with parallel agents in git worktrees and serial merges. The story-day scale was written for a human day and overstates elapsed time for agent work by an amount we can't yet measure. The constraint that holds is the owner's review time, not the sprint calendar.

### What Went Well
- **All 10 stories closed, with every acceptance criterion passing and none deferred.** The suite went from 66 to 301 cases with 0 failures and 0 orphans. CI `Automated Tests` is green on HEAD `0448510`. `/smoke-check sprint` came back PASS.
- **All three gate spikes resolved in sprint 1.** DSL spike (CE-001) came back **PROCEED** with no DSL change, so card-effects 006–016 stay unblocked. The RNG golden pin (seed 42, 100 values) is recorded on 4.7.2. The PlannerTask seam is in with an injected clock and no wall-clock assertion. Each spike carried mutation checks: tests were watched failing (exit 100) and then restored.
- **Merging one branch at a time with the full suite after each merge caught the one cross-branch break before it reached CI.** The break was fixed in one commit (`0448510`).
- **Engine findings went into the record, not into folklore.** Two ADR errata (ADR-0001: no `class_name Boot`; ADR-0007: G7 subscript forms) and engine-reference notes:
  - a bare call to a global-named method (`randi_range`) inside a class that defines it resolves to `@GlobalScope`
  - an autoload script cannot declare a `class_name` equal to its autoload name ("hides an autoload singleton")
  - `JSON.get_error_line()` is 0-based on 4.7.2
  - gdUnit4 under `godot -s` instantiates autoloads (QQ-04 answered)

  Two of these were previously NOT SOURCEABLE in the ADRs.
- **Deviations were logged per story, all ADVISORY,** with owners or a follow-up story named (e.g. the `modify_max_attacks` fold goes to match-rules 012, and the ADR-0011 "clamps" wording is an open item).

### What Went Poorly
- **No story had an independent review.** Every Completion Note reads "self, no independent review". Lean mode skipped LP-CODE-REVIEW and QL-TEST-COVERAGE, `/code-review` was never run, and the engine-specialist check is NOT ASSESSED. This leaves two Done items unmet: the QA plan's "Code reviewed (via `/code-review` or documented peer review)" and the sprint DoD's "Code reviewed and merged". Sprint-2 work will build directly on this unreviewed code (Boot, MatchState, RngStream, the data loader).
- **One merge break from parallel branches on a shared test helper.** MR-001 retyped `tests/helpers/match_factory.gd` to the production `MatchState`, a 224-line diff in a planned helper swap. CE-001's spike test, on a parallel branch, still built Dictionary state through the old factory, so the suite failed after the match-rules merge. Cost: one fix commit, `0448510`. Cause: two concurrent stories touched `tests/helpers/**` and nothing in the plan serialised them.
- **The day-based calibration is moot.** The sprint closed in one session before its planned start, so "11 story-days against 4 available" tells us little about weeks. The real capacity (the owner's weekly hours, gate condition 3) is still not given.
- **Sprint DoD items still open:** QA sign-off (`/team-qa sprint`) has not been run, and code review is unmet (above).
- **Cross-epic seams rest on test doubles:** `FakeCardDatabase` / `ConfigCardDatabase` (BOOT-003/004), `TestRngService` / `TestEventLog` (MR-001), and the CE-001 stub engine. With no override, `boot()` currently ends `Failed` because `assets/data/` does not exist yet. This was planned, but the risk carries into sprint 2.

### Blockers Encountered

| Blocker | Duration | Resolution | Prevention |
|---------|----------|------------|------------|
| No story had `status: blocked` | — | — | — |
| Post-merge suite failure: CE-001 spike test vs MR-001's typed `MatchFactory` | Minutes (fixed in the same session) | `0448510`: the spike test builds its own Dictionary state | Serialise stories that touch `tests/helpers/**`; merge the helper-changing story first and rebase the rest |

### Estimation Accuracy

| Task | Estimated | Actual | Variance | Likely Cause |
|------|-----------|--------|----------|--------------|
| Whole sprint | ≈11 story-days | 1 session | NOT ASSESSED — no per-story time logged | Agent work in parallel worktrees; the day scale assumes a human day |
| CE-001 (L, 3 days) vs BOOT-001/002 (S, 0.5) | 6× apart | Commit spacing gives no evidence of a 6× effort gap (`0e672cc` at 19:20, `1b0926d` at 19:03), but parallel starts make this unreliable | NOT ASSESSED | — |

**Overall estimation accuracy**: NOT ASSESSED — NO DATA. Actual effort per story was not recorded. The useful finding is relative: the S/M/L sizes predicted *scope* well (no story was split, carried or descoped), but they do not convert to calendar days for agent work. **Adjustment:** keep S/M/L for scope, plan capacity in sessions plus owner-review time, and have `/dev-story` log start and end times per story so sprint 2 can measure them.

### Carryover Analysis

| Task | Original Sprint | Times Carried | Reason | Action |
|------|----------------|---------------|--------|--------|
| None | — | — | All 10 done; the cut order (CDB-001 → MR-002 → MR-001) was never used | — |

### Technical Debt Status
- Current TODO count: 23 (16 in `src/`, 7 in `tests/`) — previous (at `fbe9592`): 6 (0 in `src/`, 6 in `tests/`)
- Current FIXME count: 0 (previous: 0)
- Current HACK count: 0 (previous: 0)
- Trend: Growing (+17 TODOs). Nearly all are deliberate cross-epic `TODO(<epic>)` markers left by stories built against doubles (e.g. `rules_engine.gd` `db` / `resolver` as `Variant`, `MetaStub.SETTINGS_SCHEMA` → `profile_defaults`, `save_errors.gd`). They are seams waiting for their stories, not shortcuts. Watch that each marker closes when its story lands.
- `docs/tech-debt-register.md` (TD-001..012) covers the archived prototype only; this sprint added no entries.
- Areas of concern:
  - The spike code was moved to `tests/unit/card_effects/spike/` rather than deleted (CE-001 deviation, ADVISORY).
  - As written, gate G3 reports 7 hits under `src/core/` (6 doc comments plus the `class_name Services` declaration) and needs exclusions before boot story 005 wires it into CI (smoke report, item 6).

### Previous Action Items Follow-Up
First sprint — no previous action items.

### Action Items for Next Iteration

| # | Action | Owner | Priority | Deadline |
|---|--------|-------|----------|----------|
| 1 | Run `/code-review` on the riskiest merged sprint-1 stories before sprint-2 stories build on them: BOOT-004 (only autoload; ADR-0001 deviation), MR-001 (factory swap, API additions beyond `architecture.md`, `MatchState` shape), RNG-001 (determinism root; `@GlobalScope` call-resolution trap), CDB-001 (single-parser data path). Record each verdict in the story's Completion Notes "Reviewed by" | lead-programmer via `/code-review`; owner (Jacob) reads the verdicts | High | Before the first sprint-2 story that depends on them starts |
| 2 | Serialise stories that touch shared test helpers (`tests/helpers/**`, `TestConstants`, `MatchFactory`) or shared state types (`MatchState`). The sprint plan marks them, one runs at a time, it merges first, and the others rebase onto it | producer (`/sprint-plan`) | High | Sprint 2 plan |
| 3 | Size sprint 2 from measured velocity: plan in sessions, with owner-review hours as the binding constraint. The owner gives weekly hours (gate condition 3) | Jacob | High | Before `/sprint-plan new` |
| 4 | Close sprint 1's open DoD items: run `/team-qa sprint` for the QA sign-off, and put boot story 005 (grep gates G3/G4 in CI, with comment and `services.gd` exclusions for G3) in sprint 2 | qa-lead / producer | Medium | Sprint 2, first wave |
| 5 | Have `/dev-story` log start and end time per story, so sprint 2 yields per-story effort for estimation accuracy | producer | Low | Sprint 2 |

### Process Improvements
- **Sprint-2 sizing.** Sprint 1's 10 stories were mostly independent: six systems and one wide parallel wave. The sprint-2 candidates are chains: card-database 002 → 006 is serial, then content 001 and its cross-epic chain. Parallelism will be lower, so don't extrapolate "10 per session" straight across. Size by dependency waves instead.
  - Commit **≈15–18 stories in 3 waves of ≤6 parallel stories**. Merge each wave serially with the full suite after each merge, as in sprint 1.
  - Reserve one slot per wave for `/code-review` on that wave's riskiest story.
  - Put the milestone prerequisites in wave 1: the match-ui slice (stories exist since `888d8ef`) and a Windows-export-in-CI task (gate condition 8).
  - Re-date or rescope First Playable from the result. The ~50-story chain is still more than two sprints at this sizing.
- **Lean review needs a floor.** Keep the lean director gates, but make independent `/code-review` mandatory for (a) any story that changes an autoload, a shared helper or a shared state type, and (b) any story recording an ADR deviation. Sprint 1 had 4 such stories (BOOT-004, MR-001, MR-002, CE-001).
- **Keep what worked.** Worktree-parallel implementation, serial merges with the full suite after each, mutation checks on each story's key assertion, and engine findings written into ADR errata the same day.

### Summary
A strong calibration sprint. All 10 stories (11 story-days) closed in one session, the suite went from 66 to 301 tests with CI and smoke green, and all three gate spikes resolved (DSL **PROCEED**). The cost was one merge break on a shared test helper and zero independent review. The single most important change: run `/code-review` on the riskiest merged stories (BOOT-004, MR-001, RNG-001, CDB-001) before sprint 2 builds on them, and serialise stories that touch shared test helpers.
