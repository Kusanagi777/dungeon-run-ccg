# Sprint 6 — 2026-12-02 to 2026-12-08

> **Type**: the First Playable sprint, sized by lanes and links like sprints 4 and 5. The retro link rules apply (`production/retrospectives/retro-sprint-4-2026-11-04.md`, Estimation Accuracy): an opener or a re-open after a merge counts as 2 links, an L as about 1.5, and a story that first runs a new subsystem on the real engine as 2. Measured: sprint 5 delivered 26 of 28 committed, and every wave needed a review-fix return trip, so **a wave's real end is one review cycle after its last merge**. This sprint is bound by the depth of one serial chain and by the owner's 12 h, not by agent time
> **Stage**: Pre-Production · workflow standard (match-rules and card-effects at `full` via `workflow_overrides`) · review lean · automation guided · story_granularity balanced (6–10 per sprint, scaled by measured velocity: 26 delivered in sprint 5) · qa.level standard
> **PR-SPRINT**: skipped — Lean mode
> **QA Plan**: none. The owner chose to skip it for now (2026-11-05, Phase 5 choice [B])
> **Milestone**: there is no file in `production/milestones/`, so this plan works from the story backlog. **First Playable: sprint 6, ending 2026-12-08, fallback sprint 7.** The owner accepted it on 2026-11-04 (`production/gate-checks/gate-pre-production-2026-11-03.md`, entry condition 5)
> **Risk register**: none in `production/risk-register/`. Risks below come from the sprint contents only
> **Generated**: 2026-11-05 by `/sprint-plan new`, phases 1–3, followed by hand by a producer subagent (the skill cannot be model-invoked). The owner answered the QA question and approved the write
> **Updated**: 2026-11-05 by `/create-stories` (producer), on the owner's approval: five stories added (BOOT-009, 010, 011, MR-020, MUI-025), decisions DD-X32 to DD-X34 recorded, Goal Prerequisites rows 8 to 14 updated, committed 15 → 20
> **Dates**: 2026-12-02 (Wed) to 2026-12-08 (Tue), 5 working days. No document moves them. Sprint 5 was planned for 7 days and run in about 14 h of elapsed time, so waves below are merge points, not days; the calendar is set by when the owner can read
> **Lanes run as `general-purpose` agents on Windows**, one worktree per lane, a per-worktree `user://` (see Goal Prerequisites, row 13). A lane's role goes in its brief. **Reviewers read commits with `git show` and never move HEAD**: no `git checkout`, `git switch`, or anything that moves HEAD in the main checkout appears in a review brief
> ⚠️ **No QA Plan**: This sprint was started without a QA plan. Run `/qa-plan sprint`
> before the last story is implemented. The Production → Polish gate requires a QA
> sign-off report, which requires a QA plan.

## Sprint Goal

Deliver **First Playable**: the owner plays one War match against The Torchbearer, mouse-played, on a Windows debug export launched with `-- --fixture=first_playable` (playtest #1), by 2026-12-08. The sprint builds the match view (MUI-004 … 012), runs the boss planner on the Windows export (BAI-016 … 019, A30), and closes the sprint-5 performance carryover on the owner's R6 decision.

The gate's wording, for reference: "Windows export, one War match vs one band-1 boss, mouse-played, … the owner plays it = playtest #1" (entry condition 5).

## First Playable check (accepted: sprint 6, 2026-12-08; fallback sprint 7)

| Condition (retro-5 / retro-4 outlook) | State at plan time | This plan |
|---|---|---|
| **M3 check: BAI-015 merged at M2** | **Met.** `boss-ai-match-driver-015` is `done` (2026-11-05) | Recorded in `sprint-status.yaml` history |
| Heroes stories written; War starter deck for BAI-016 | **Met.** heroes 001–004 are `done` | — |
| Linux CI read on `d181790` | **Not met.** `gh` is not logged in; smoke verdict is NOT ASSESSED on this one item (`production/qa/smoke-2026-11-05-sprint-005.md`) | Retro action 1, before W1 (owner) |
| The two missing First Playable pieces named in retro action 3 (`driver_factory`, `keywords[]`) | **Storied, not built.** BOOT-009 and MR-020 own them (2026-11-05; Goal Prerequisites rows 8 and 9) | Pre-W1 lanes, merged at M0. **The date depends on M0 landing before W1**; each story's fallback is L6 W1 |

**Remaining path, verified against each story's Dependencies** (the retro list is corrected where it differs):

| Chain | Verified dependency |
|---|---|
| MUI-004 → **005, 006, 007** | each needs only MUI-004 (MUI-003, BOOT-004, content 001, BAI-015 are done) |
| **MUI-008** | needs **005, 006 and 007 all merged**, plus MR-012 and CE-004 (done). MUI-006 and 007 are on the path, not "in parallel" |
| MUI-009 | needs 004 and **006** (`CardFrame`) |
| MUI-011 | needs 005 (and MR-008, RNG-007, BAI-015, done) |
| Pre-W1: **BOOT-009**, **BOOT-010** → **BOOT-011**, **MR-020** | BOOT-009 needs BOOT-004 and BAI-001, 013, 014, 015 (done); BOOT-010 needs nothing; BOOT-011 needs BOOT-010 and BOOT-006 (done); MR-020 needs MR-003, 010, 019 (close-out only) and MUI-001 (done) |
| **MUI-025** | needs 005 and **008** (`Dragging`, the cast zone), plus CE-011 and heroes 001 (done) |
| **MUI-012** | needs 008, **025**, 009, 010 (done), 011, **BAI-018**, content 001 (done), BOOT-008 (CI Windows export, exists) |
| BAI-016 → 017 → 018 | 016 needs BAI-003, 009, 014, 015 (done) and the heroes War deck (done); 017 needs 016 and, for its `E_BUSY` assertion, **BAI-019**; 018 needs 016, 017 and the real `MatchView` |
| BAI-019 | needs CDB-008, BAI-001, 013, 014, 015 (done). Story 017 allows its `E_BUSY` assertion to be marked pending; the plan lands BAI-019 first |
| content 006 | not on the path (the playable match carries no treasures). Dependencies are met: treasures 003 and CE-015 are done. Its "validator story path not yet assigned" text is treasures 003 |

**Chain depth sets the date.** MUI-004 → {005, 006, 007} → 008 → 025 → 012 cannot be shorter than three merge points (M1, M2, M3), and the M3 stories need a review-fix trip before the owner plays. M0 sits before the sprint and adds no merge point to that chain. That leaves one slot, the **close slot**, between M3 and 2026-12-08. **Decision points:** at M2, if MUI-006 or 007 has not merged, MUI-008 cannot start and sprint 7 is declared early. At M3, if MUI-008, MUI-025 or MUI-012 has not merged, the sprint-6 close declares sprint 7.

## Goal Prerequisites

Checked against the repo at `82427f5`; rows 8 to 14 updated on 2026-11-05 at `4d79136`. `engine.name` is Godot, so scenes were searched as `*.tscn` (`src/` holds `boot.tscn`, `main.tscn`, `run_shell.tscn` only).

| # | Needed to show the goal | Status |
|---|-------------------------|--------|
| 1 | Playable scene `res://src/ui/match/match_view.tscn`, its presenter scenes and `card_frame.tscn` | built by MUI-004 (skeleton and stubs), then MUI-005, 006, 007, 008, 009, 011 fill them. None exists today |
| 2 | `run/main_scene` | exists (`res://src/scenes/main.tscn`, the `RunShell` stub). The playtest does not use it: it launches through `--fixture` (MUI-012 context, Run UI is not storied). **How the exported debug exe reaches `match_view.tscn` from `-- --fixture=…` is NOT ASSESSED**: `main.gd` reads only `--boot-fail-fixture`, and MUI-012 says "launchable as the scene argument" without a test |
| 3 | `MatchDebugLoader` (debug builds only) | built by MUI-004. Its exclusion from the release `.pck`, the `.pck` grep and the debug/release preset split are built by MUI-012 (`export_presets.cfg` holds one preset today) |
| 4 | Fixtures `turn1_player`, `hand_10`, `midgame_full_board`, `mulligan`, `targeting_taunt`, `targeting_stealth`, `match_end_*` (5), `first_playable` | built by MUI-004, 006, 007, 009, 008, 011, 012. `tests/fixtures/match_ui/` holds only `streams/` today |
| 5 | `MatchDriver`, `MatchController`, `MatchQuery`, `RulesEngine.clone()` | exists (BAI-013/014/015, MUI-003, MR-017) |
| 6 | `planner_target_ms` (500) and `planner_mode` (`worker`) as shipped knobs | exists (`assets/data/ai_profiles.json:193–196`; the sprint-5 gap is closed) |
| 7 | `hero_war`, the 15-card starter deck, Whetstone, `boss_torchbearer` | exists (content 001, heroes 001/002, CE-011). The deck has no Choice, no Discover and no targeted Battlecry, so MUI-013 is not needed |
| 8 | **`driver_factory`** (`RunMachine` calls it; `Boot` supplies it, ADR-0008 Decision 1) | built by BOOT-009 (pre-W1, M0): `Boot.driver_factory()` hands each driver a new `PlannerTask` per plan, `worker` by default and `time_sliced` as the fallback. Tests and the harness pass their planner through its override, and `planner_mode: "immediate"` becomes a data error (DD-X33). `RunMachine` stays unbuilt (run-structure has no stories). MUI-004 AC-2, BAI-016 AC-4, BAI-019 AC-3, BAI-018 and MUI-012 consume it |
| 9 | **`keywords[]` on `minion_summoned`** | built by MR-020 (pre-W1, M0): both emit sites gain `keywords` (`rules_engine.gd:1265` and `:2386`), reconciled with rng-event-log §D, in one reviewed golden regeneration shared with row 10. It gives MUI-007's badges (Taunt, Divine Shield, …) their event source |
| 10 | **Starting hero health on an event** | built by MR-020 (pre-W1, M0): `match_started` gains both heroes' starting health and `MatchViewState` reads it, so MUI-005 AC-1 (health stamps on both portraits in the first capture) is met from events. The field names and starting armour stay open (MR-020 open questions) |
| 11 | **Hero-power confirm for untargeted Whetstone** | built by MUI-025 (L1 W3, between MUI-008 and MUI-012): the untargeted `Ready` hero power is dragged to the cast zone. Drag-only is accepted for playtest #1; a single click does nothing until MUI-017, which follows after First Playable (DD-X34) |
| 12 | **A Windows screenshot path** for retained UI captures | built by BOOT-011 (pre-W1, M0, behind BOOT-010): `tools/capture.sh` runs on Windows without Xvfb. Windows frames count as BLOCKING UI evidence and each records its renderer in a `.renderer.txt` sidecar (DD-X32, ADR-0010 erratum 2026-11-05). Retro action 4 |
| 13 | **`godot` on PATH and a per-worktree `user://`** | built by BOOT-010 (pre-W1, M0): the committed `tools/bin/godot` resolves the engine and gives each worktree its own `user://`, replacing the sprint-5 scratchpad shim. Retro action 4 |
| 14 | **Export templates, and a Windows debug export** | **Debug export exists in CI; templates missing locally.** `windows-export.yml` already builds and uploads `deckdelve-windows-debug-<sha>` beside the release artifact (`bec8ede`, 2026-11-04), so the playtest, BAI-018's A30 profiler half and NC-5 have a debug export without a local template. It is built from the one preset, whose `exclude_filter` drops `tests/*`, so `--fixture` waits on MUI-012's preset split (row 3). The artifact lasts 14 days; **NOT ASSESSED** whether a current one exists (`gh` is not logged in). No template is installed locally (smoke report), and the owner's local export templates are still needed for R6 and any local release measure, A22 among them (retro action 2) |
| 15 | **A release export that opens past `data_error`** | **missing for 5 of 6.** `PENDING_CONFIG_OWNERS` still holds `run_structure`, `reward_draft`, `treasures_balance`, `match_ui`, `run_ui`, `profile_defaults`; in a release build each is an `error`, so the load is `Failed` by design. Only `treasures_balance` has a story (treasures 010). The goal itself (a debug playtest) does not need this; MUI-012 AC-3 ("release build boots to its main scene without error") and BAI-018 AC-1 (the `commands.build` release export plays a match) name it |
| 16 | UX specs for hand, targeting, mulligan, match end | exists and APPROVED (`design/ux/hand.md`, `targeting.md`, `mulligan.md`, `match-end.md`). Stories 006, 008, 009, 011 still say "not authored": refresh at readiness |

**The owner's choices (2026-11-05).** Fix (b) is taken for rows 8 to 13: the stories are in Tasks, Lanes and the Readiness notes. Row 14 is corrected: the debug export exists in CI, and the owner's local templates are what remains. Row 15 stays report only: no fix is picked. The table keeps the fixes each row was offered, and a row's (c) stays the fallback if its story slips:

| Row | (a) Pull in a Ready story | (b) Write a story first | (c) Reword the goal to what the sprint can show |
|---|---|---|---|
| 8 `driver_factory` | **None exists.** | **Taken (owner, 2026-11-05): BOOT-009.** Boot supplies it; DD-X31 and the BAI-014 notes give the shape, and DD-X33 makes `planner_mode: "immediate"` a data error. `RunMachine` itself stays out: the fixture launch does not need it | MUI-004, BAI-016, BAI-018 and MUI-012 build `MatchDriver` directly in the loader and harness. Four ACs lose the words "the same `driver_factory`" |
| 9 `keywords[]` | **None exists.** | **Taken (owner, 2026-11-05): MR-020.** The payload lines, the rng-event-log §D reconciliation, a reviewed golden regeneration, in one story and one regeneration with row 10 | First Playable tokens show no printed-keyword badges; MUI-007 AC-1 (O3) loses that clause |
| 10 starting health | **None exists.** | **Taken (owner, 2026-11-05): MR-020** (match-rules C15 and rng-event-log §D row for the event) | Portraits show no health until the first hit; MUI-005 AC-1 loses the health stamps |
| 11 hero-power confirm | **MUI-017** (Ready, L, Logic). Not taken: it depends on MUI-008 and MUI-012 as written, so it cannot precede 012 without editing that dependency, and it stays out until after First Playable (DD-X34) | **Taken (owner, 2026-11-05): MUI-025**, the hero-power drag slice. Drag-only for playtest #1 (DD-X34) | First Playable is played without the hero power; MUI-012 AC-1 drops it |
| 12 Windows screenshots | **None exists.** | **Taken (owner, 2026-11-05): BOOT-011** (tools). Windows frames are BLOCKING evidence with a renderer sidecar (DD-X32, ADR-0010 erratum 2026-11-05) | UI captures come from Linux cloud lanes as in sprints 1–4, or the owner takes and retains them by hand. **NOT ASSESSED** whether a Linux lane is available |
| 13 `godot` PATH, `user://` | **None exists.** | **Taken (owner, 2026-11-05): BOOT-010** (tools), retro action 4 | Lanes keep using the scratchpad shim, as in sprint 5; the risk is accepted and written down |
| 14 templates, debug export | **None needed for CI.** | **Not needed:** `windows-export.yml` already builds and uploads `deckdelve-windows-debug-<sha>`, so no BOOT-008 sibling is written | The owner installs the local templates (retro action 2) for R6 and any local release measure. The debug build comes from the CI artifact; a hand export is the fallback once templates are in |
| 15 release past `data_error` | **treasures 010** (Ready, S; depends on treasures 007) clears one of six | `/create-stories` for the `match_ui` validator, run-structure, reward-draft, run-ui and meta owners | MUI-012 AC-3 and BAI-018 AC-1 name the debug export; a release export is expected to open on `data_error` |

**Row 15 is the one pick left: it decides how far MUI-012 AC-3 and BAI-018 AC-1 can close** (Readiness notes).

## Capacity

### Agent capacity (not the constraint)

- **Calendar**: Wed 2026-12-02 – Tue 2026-12-08 (5 working days).
- **Measured basis**: sprint 5 delivered 26 of 28 committed (93%), 0 of 3 stretch; 2345 tests. Agent minutes are NOT ASSESSED — NO DATA (restarts distort them); sprint 4's basis was 259 agent-min for 22 stories, mean 11.3 min.
- **Sizing**:
  - 6 lanes (4 carry stories, 2 are fix and close lanes), plus 3 short pre-W1 lanes (L7 to L9), at most 7 links each. The measured ceiling is 7; **L1 is at 7.0** with MUI-025, so it has no link left.
  - **Committed: 20 stories**: 15 Must Have, 1 Should Have, and 4 carryover scheduled as committed (MUI-004, BAI-019, MR-019, MR-018) — about 27.5 story-days on the S 0.5 / M 1 / L 3 label, relative size only.
  - **Stretch: 3** (treasures 008, 002, 007). **No committed story depends on a stretch story.**
  - 20 is below sprint 5's 28 on purpose; the five added on 2026-11-05 close rows 8 to 13, and four of them land before W1. The path is serial and UI-heavy, each UI story costs an owner sign-off, and the Ready backlog beyond the path (treasures 002/004/007/010/012, CE-016) adds owner reading hours without moving the goal. A Ready backlog smaller than the range is never padded.
- **Buffer (≈ 20%)**:
  - L1 W2 is the W1-review fix slot (no story).
  - L2 and L3 W3 are the W2-review fix slots.
  - The **close slot** (Mon–Tue) is the W3 review-fix, the debug export and the playtest. It is not optional.
- **Merge protocol** (unchanged from sprints 3–5):
  1. Lanes merge one at a time, with the full suite (`commands.test`) after each.
  2. **[S]** stories edit shared test helpers or fixtures; they merge first in their wave. This sprint: BOOT-009 at M0 (`tests/fixtures/boss_ai/profiles_stub.json`).
  3. **[C]** stories start enforcing a shared contract or change shipped data; they merge last, after the full suite against the merged state. This sprint: content 006 and BAI-019 at M1, any `ai_profiles.json` retune at M3. MR-020 at M0 is [C] but merges first, by its own Merge position rule: see Merge order.
  4. **`src/core/boot.gd` `_collect_validators()` stays orchestrator-owned.** No picked story registers a validator.
  5. Lane scratch files are prefixed `<lane>-`. `/dev-story` logs start and end UTC per story.
- **Standing rules** (retro-4 action 5, kept):
  - Commit each story the moment its suite is green, and before any idle point.
  - Log every pause, worktree loss and resume in `active.md` with UTC (retro 5: not done in sprint 5).
  - Keep the committer-identity hook on; check `git log --format=%cn <lane>` before a merge.
  - Lanes never hand-edit `sprint-status.yaml`; the orchestrator updates it at merge.
  - The merge tooling checks the current branch before it acts (retro 5 process improvement).
- **Reviews keep pace with the waves.** Every Logic and Integration story gets an independent `/code-review` in its own wave, as in the review row below. Findings go to the next wave's fix slot; W3 findings go to the close slot.
- **Compare performance only with interleaved runs; never quote one** (retro 5).
- **Cut order if a wave runs short** (unfinished stories carry; no mid-sprint re-scope): stretch first (treasures 007, 002, 008), then content 006, then the MR-019/MR-018 close-out. **The 15 Must Have stories and MUI-004 and BAI-019 are not cut.** If the path cannot finish, the goal moves to sprint 7 at the decision points above.

### Owner capacity: 12 h per week

The owner's hours for review and playtesting are the human bottleneck. This sprint has **eight UI stories**, each with a retained screenshot and an owner sign-off (the UI gate is BLOCKING), a Windows run (BAI-018) and playtest #1. Sprint 5's five-sign-off estimate was ≈ 2.5 h; this plan budgets 0.5 h each.

| When | Owner work | Hours |
|---|---|---|
| before W1 (not counted) | Retro 1: read Linux CI on `d181790`, run `gh auth login`, re-run `/smoke-check`. The pre-W1 decision lane (below). Read the `/create-stories` output (done 2026-11-05). Commit or revert the uncommitted `project.godot` change on the trunk. New: `/code-review` verdicts on BOOT-009, 010, 011 and MR-020 (0.75), and the stories' open questions (0.25). If any of this slips into W1, add it | (2.25) |
| W1 | **R6** (retro 2): install export templates, measure a release build, decide keep or re-budget the 10 ms gate, close MR-018 | 1.0 |
| W1 | **NC-5** (retro 5, third carry): run the exported debug build, repeated quits for TD-013 | 0.5 |
| W1 | Late pre-W1 decisions: Q-5, `passive_driven` | 0.25 |
| W1 | UI sign-offs: MUI-004 (frame and `perf-profile.md`), MUI-005 | 1.0 |
| W1 | `/code-review` verdicts: BAI-016, BAI-019, MUI-004, MUI-005; summary: content 006 | 0.75 |
| W2 | UI sign-offs: MUI-006 (2 frames), 007 (2), 009 (3), 011 (6) | 2.0 |
| W2 | Verdicts: BAI-017, MUI-006, 007, 009, 011; the W1 fix-slot outcome | 0.75 |
| W2 | Pre-W3 decision: one search per turn and the second-search budget; R5 band counts (retro 2) | 0.25 |
| W3 | UI sign-off: MUI-008 (drag, arrow, Taunt and Stealth frames) | 0.5 |
| W3 | UI sign-off: MUI-025 (the hero-power drag frame) | 0.5 |
| W3 | **BAI-018 Windows run**: A30, determinism, A22 on band 3 | 1.0 |
| W3 | **MUI-012 playtest #1** and report | 1.5 |
| W3 | Verdicts: MUI-008, MUI-025, MUI-012, BAI-018 | 1.0 |
| close | Smoke report, retro, the First Playable decision, approve the sprint-7 plan | 1.0 |
| — | **Total** | **12.0 of 12** |

- **The table holds at exactly 12.0 h, with no reserve.** The five added stories cost 0.75 h inside the sprint (MUI-025's sign-off and verdict), which is all of the old 0.75 h reserve. MUI-025 is budgeted at the plan's 0.5 h per sign-off; the story's low estimate of 0.25 h would leave 0.25 h.
- **It exceeds 12 h if anything below happens**, and the overrun goes in the retro:
  - A W3 review-fix sends MUI-008 back for a second sign-off and a second playtest: at least + 0.5 h, about + 2 h with the playtest repeated.
  - Any of the pre-W1 row's 1.0 h of new work slips into W1: up to 13.0 h.
- Stretch stories that land add ≈ 0.25 h of reading each; read them in sprint 7, because the hours are gone.
- The owner's real exposure is the W3 stack: two sign-offs, Windows run, playtest and verdicts in one wave, 4.5 h.

## Lanes

A **lane** is one `general-purpose` agent implementing its dependency chain back to back in one worktree, one commit per story, the full suite green after each. **Waves are merge points.** A story that depends on another lane's story starts only after that story has merged at an earlier merge point.

| Lane | W1 (→ M1) | W2 (→ M2) | W3 (→ M3) | Stretch | Links |
|---|---|---|---|---|---|
| **1 Critical — match-ui A** (the chain) | **MUI-004** (L, opener, new subsystem: first scenes, `Presenter`, loader, capture and `/perf-profile`, 2) → **MUI-005** (L, 1.5) | W1-review fix slot (buffer) | **MUI-008** (L, re-open, 2) → **MUI-025** (S, 0.5) → **MUI-012** (M, 1) | none | 7.0 |
| **2 match-ui B** | — | **MUI-006** (M, opener, 2) → **MUI-009** (M, 1; needs 006 in-lane) | W2-review fix slot | none | 3 |
| **3 match-ui C** | — | **MUI-007** (M, opener, 2) → **MUI-011** (M, 1; needs 005 at M1) | W2-review fix slot | none | 3 |
| **4 Critical — boss-ai** | **BAI-016** (L, opener, new subsystem: the harness on the real engine, 2) → **BAI-019** (S, 0.5) | **BAI-017** (M, re-open, 2) | **BAI-018** (L, re-open, 2; the owner's Windows run) | none | 6.5 |
| **5 content + treasures** | **content 006** (S, opener, 2) | — | — | **treasures 008** (S, W2, 2) → **treasures 002** (M, W2, 1) → **treasures 007** (M, W3, 2) | 2 (+5) |
| **6 match-rules perf close** | **MR-019 / MR-018 close-out** (opener, 2): runs only after the owner's R6 decision; closes the stories, plans **no** new engine work | — | — | none | 2 |
| **review** | `/code-review` **BAI-016, BAI-019**, MUI-004, MUI-005 (summary: content 006). Verdicts before M2 | `/code-review` **BAI-017**, MUI-006, 007, 009, 011 (summary: treasures stretch). Verdicts before M3 | `/code-review` **MUI-008, MUI-025, MUI-012**, BAI-018 (evidence read), MR-019 close-out (summary) before the close slot | — | — |

### Pre-W1 story lanes (→ M0, before 2026-12-02)

Fix (b) for rows 8, 9, 10, 12 and 13 (owner, 2026-11-05). These four stories land before W1, so every W1 lane worktree is cut from a trunk that has them. M0 is a merge point before the sprint, and these lanes close at M0. The stories' own estimates are about 1.5, 1.5 and 2 links; the figures below use the retro's opener rule.

| Lane | Pre-W1 (→ M0) | Why before W1 | Fallback if it slips | Links |
|---|---|---|---|---|
| **7 tools** | **BOOT-010** (M, opener, 2) → **BOOT-011** (M, 1; needs 010 in-lane) | Every lane runs `godot` through the wrapper; MUI-004 takes the first frame in W1 | BOOT-010: lanes keep the scratchpad shim (row 13 fix (c)), it lands in L5 or L6 W1 and lanes adopt it at M1. BOOT-011: row 12 fix (c) | 3 |
| **8 boot** | **BOOT-009** (M, opener, 2) | MUI-004, BAI-016 and BAI-019 consume it in W1 | L6 W1, merged first at M1; MUI-004 AC-2, BAI-016 AC-4 and BAI-019 AC-3 then close in the W2 fix slots | 2 |
| **9 match-rules events** | **MR-020** (M, opener, 2) **[C]** | MUI-005 needs the health on events before its first capture in W1 | L6 W1; MUI-005's AC-1 health stamps then close at the W2 fix slot, and MUI-007 is unaffected | 2 |
| **review** | `/code-review` **BOOT-009, BOOT-010, BOOT-011, MR-020**. Verdicts before M0. technical-director reads MR-020's golden diff before merge | — | — | — |

**Why this shape.**
- MUI-004 and MUI-005 share lane 1 in W1 because 005 needs only 004, and a second wave would add a merge point to the chain. It carries the risk that 005 builds on a skeleton the owner has not yet signed off (4 and 5 are signed off together at M1).
- 006, 007, 009 and 011 split across two lanes in W2 so that 006 and 007 both merge at M2, which 008 needs.
- MUI-008 → 025 → 012 runs in one lane in W3 because 025 needs 008's `Dragging` and 012's other dependencies (009, 011, BAI-018) are merged by then.
- BAI-018 is the pipeline rehearsal: its debug export on the M2 trunk is the first test of the export route before the playtest.
- Lane 5 and lane 6 carry no goal work. They are the lanes that can idle.

**Merge order:**
- **M0** (before W1; W1 lane worktrees are cut after it): 1. L9 (MR-020 **[C]**, first because it is the only `rules_engine.gd` editor and the goldens settle before anything compares them). 2. L8 (BOOT-009 **[S]**, shared fixture, files disjoint from MR-020). 3. L7 (BOOT-010, then BOOT-011). The full suite after the last merge is the run against the merged state that MR-020's [C] needs.
- **M1**: 1. L6. 2. L1 (MUI-004, 005). 3. L5 (content 006 **[C]**, shipped data). 4. L4 (BAI-016, then BAI-019 **[C]**, `E_BUSY` enforcement, last).
- **M2**: 1. L1 (W1-review fixes). 2. L2. 3. L3. 4. L4 (BAI-017, tests only). 5. L5 (stretch).
- **M3**: 1. L1 (MUI-008, 025, 012). 2. L2 and L3 fix slots. 3. L5 (stretch). 4. L4 (BAI-018 evidence; any `ai_profiles.json` retune **[C]** last).
- **The orchestrator records the M2 and M3 checks** in `active.md` and the sprint-status header.

**Where the shared files fall:**
- **`src/ui/match/match_view.gd` / `.tscn`**: W1 L1 (004); W2 L3 (011: `Ended`, `match_view_finished`). One editor per wave.
- **`src/ui/match/match_view_state.gd`**: M0 L9 (MR-020, the `match_started` branch only).
- **`src/ui/match/input_router.gd`**: W1 L1 (005, End Turn and hero-power intents); W3 L1 (008, `Dragging`; then 025, the `hero_power` drag source). Same lane, in series.
- **`src/ui/match/hero_presenter.gd`**: W1 L1 (005); W3 L1 (025, the dragged look). Same lane.
- **`src/ui/match/match_debug_loader.gd`**: W1 L1 (004 creates), W2 L2 (006, `hover:` pose), W3 L1 (008, `drag:` pose; 025 if it adds a pose, in series). One lane per wave.
- **`hand_presenter.gd`, `card_frame.*`**: W2 L2 (006); W3 L1 (008 edits `hand_presenter.gd`). **`board_presenter.gd`**: W2 L3 (007); W3 L1 (008). Never two lanes in one wave.
- **`tools/capture.sh`**: M0 L7 (BOOT-011); W1 L1 (004, only if its own change needs it). **`tests/README.md`**: M0 L7 (BOOT-010, 011, in series). **`export_presets.cfg`, `.github/workflows/`**: W3 L1 (012). **`docs/architecture/architecture.md`** (performance values only): W1 L1 (004).
- **`src/core/boot.gd`**: M0 L8 (BOOT-009, one new method, merged by the orchestrator); W1 L4 (BAI-019, the `driver_factory` wiring, on the factory BOOT-009 built). **`src/core/data/card_database.gd`, `validation_report.gd`**: W1 L4 (BAI-019). Orchestrator-owned lines are untouched.
- **`src/ai/boss_ai.gd`** (`PLANNER_MODES`), **`tests/fixtures/boss_ai/profiles_stub.json`**, **`tests/unit/boss_ai/boss_ai_profile_resolver_test.gd`**, **`design/gdd/boss-ai.md`** (F9 `runtime` line): M0 L8 (BOOT-009) only.
- **`rules_engine.gd`**, **`tests/fixtures/match_rules/golden_logs/`**, **`design/gdd/match-rules.md`**, **`design/gdd/rng-event-log.md`**: M0 L9 (MR-020) is the only planned editor. **It merges first in its wave**, before any golden is compared.
- **`assets/data/ai_profiles.json`**: nobody in W1 unless the owner decides `passive_driven`; W3 L4 only if A22 misses (BAI-018 AC-4). **`assets/data/treasures.json`**: W1 L5 only.
- **`tests/performance/match_rules/**`**: W1 L6 only.

## Pre-wave owner-decision lanes (retro 5 process improvement)

A short lane before each wave: the decisions that wave's stories would otherwise build against. None is a story; the pre-W1 stories are under Lanes.

| Lane | Decisions | Lands before |
|---|---|---|
| **Pre-W1** (before 2026-12-02) | Row 15's fix (a/b/c), the one Goal Prerequisite pick left; the new stories' open questions (BAI-019's `is_live` under the factory, MR-020's field names and armour, MUI-025's dragged-button look); Q-5 `legal_commands()` filter; `passive_driven` preference rows; the Torchbearer deck line (content 010 sign-off, still open: the swap goes beyond DD-X20's three decks and the Torchbearer is the playtest opponent); commit or revert `project.godot` | MUI-004, 005, 007, BAI-016, 019 |
| **Pre-W2** (after M1 reviews) | W1 review outcomes; R6 result and what it means for the 10 ms gate | MUI-006, 007, 009, 011, BAI-017 |
| **Pre-W3** (after M2) | One search per turn and the second-search budget (DQ-2, DQ-3), R5 band counts (`/propagate-design-change` boss-ai F7); the owner's Windows machine and a debug export ready | BAI-018 AC-4, MUI-008, 012 |

### Open owner design questions and what each gates

Verified against the sprint-5 reviews and the story notes. "Gates none" means no picked story's acceptance criteria depend on it; the effect is on what the owner sees.

| Question | Source | Gates |
|---|---|---|
| **Q-5 `legal_commands()` during boss turns** lists boss commands and affordable boss hand indices | wave-2 and wave-3 reviews, `match_driver_gate_test.gd:206` | **MUI-005** (the `state_actionable` outline on End Turn reads it) and **MUI-008** (pickup legality). Decide pre-W1: filter to `issuer == player` or correct the doc |
| **`passive_driven` has no `choice_preference` rows**, so `boss_rot_warden` scores 0 | BAI-010 notes, wave-1 review DQ-4 | **BAI-016** retains a `boss_rot_warden` sim file. A data row decided later means re-running it. Gates none otherwise |
| **C1.3 trial `on_draw`**: search nodes read the real deck order | wave-3 review, Q-7 | Gates none: no shipped card has `on_draw`. `real_plan_undrawn_card.json` stays unused until decided |
| **A4 against C8.1**, and **`kept` with no forecast** | wave-2 review | Gates none: the telegraph is MUI-015, not in this sprint. It would color the banner in a later playtest |
| **One search per turn; the second-search budget (F7 `+ 2·lethal`)** | wave-1 review DQ-2, DQ-3; BAI-009 notes | **BAI-018 AC-4** (band 3 counts and the A22 run) and BAI-016's advisory A22. Decide pre-W3 |
| **False "plan changed" on a re-plan** (a second commit) | wave-3 review | Gates none now. "One commit per boss turn" would re-open BAI-014, which needs a story |
| **`retrigger`: mixed board `partial`; `once_per_turn`** | wave-1 review D2, D3 | Gates none. The Rot Warden deck plays Mass Rites ×3, so a ruling could change BAI-016's `boss_rot_warden` output |
| **Unknown `hero_def_id`** (fall back or fail) | heroes 001, wave-1 review X4 | Gates none: MUI-004 and 012 load `hero_war`. A match-rules C3 line |
| **DD-X23 cap against the 0.6 s turn banner and draw** | MUI-010 completion notes | Gates none by criteria. It decides how the first boss group feels in playtest #1 (≈ *t* + 600 ms). Wait for the playtest |
| **F4 `A` counts `group_id`s, a command is often several** | MUI-010 completion notes | Gates none. Same: feel, MUI-015 and MUI-024 |
| **Absent `side` in a value filter** | wave-2 review Q1 | Gates none picked; treasures 002 and 007 (stretch) author against it |
| **R6**: keep or re-budget the 10 ms `submit` gate | MR-019 AC-3 | **MR-019, MR-018** close-out; it decides whether further engine work needs a story |

## Tasks

The Est. Days column uses the S 0.5 / M 1 / L 3 scale as a relative-size label only. Plan by the Links column above. Every lane runs on a `general-purpose` agent; the role in brackets is the brief. Carryover stories appear in the Carryover table only.

### Must Have (Critical Path)
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| MR-020 | [`minion_summoned` carries `keywords[]`, `match_started` carries the starting hero health, one reviewed golden regeneration](../epics/match-rules/story-020-keywords-and-starting-health-on-events.md) (Logic, M), L9 pre-W1 **[C]**, `/code-review` at M0 | general-purpose (gameplay-programmer), L9 | 1 | MR-003, MR-010, MR-019 (close-out only), MUI-001 (done) | `keywords` at both emit sites; starting health on `match_started`; view parity with `NOT_PROJECTED` deleted; stripped-diff golden proof, read by technical-director. Rows 9, 10 |
| BOOT-009 | [Boot supplies `driver_factory`](../epics/boot-composition-root/story-009-driver-factory.md) (Integration, M), L8 pre-W1 **[S]**, `/code-review` at M0 | general-purpose (gameplay-programmer), L8 | 1 | BOOT-004, BAI-001, 013, 014, 015 (done) | a new driver and a new planner per call, by `planner_mode` and `--ai-sync`; planner override; `planner_mode: "immediate"` is a data error (DD-X33). Row 8 |
| BOOT-010 | [A committed Godot wrapper, a per-worktree `user://`](../epics/boot-composition-root/story-010-godot-wrapper-and-user-dir-isolation.md) (Integration, M), L7 pre-W1, `/code-review` at M0 | general-purpose (tools-programmer), L7 | 1 | None | `godot` resolution, per-worktree user data, templates visible, `commands.test` verbatim in two worktrees. Row 13 |
| BOOT-011 | [A Windows screenshot path](../epics/boot-composition-root/story-011-windows-screenshot-capture.md) (Integration, M), L7 pre-W1, `/code-review` at M0 | general-purpose (tools-programmer), L7 | 1 | BOOT-010 (L7), BOOT-006 (done) | `tools/capture.sh` on Windows without Xvfb; `.renderer.txt` sidecar beside every frame; Windows frames are BLOCKING evidence (DD-X32). Row 12 |
| MUI-005 | [Hero panels, mana bar, deck piles, top bar, hero power and End Turn](../epics/match-ui/story-005-hero-panels-mana-and-end-turn.md) (UI, L), L1 W1 | general-purpose (ui-programmer), L1 | 3 | MUI-004 (L1), MR-020 (M0), CE-011, MR-010 (done) | F6 rects ±2 px; number pops; End Turn rule; hero-power single click submits nothing (DD-X34). **Retained screenshots + owner sign-off.** AC-1 health stamps need MR-020 |
| MUI-006 | [Hand fan and hover preview](../epics/match-ui/story-006-hand-fan-and-hover-preview.md) (UI, M), L2 W2 | general-purpose (ui-programmer), L2 | 1 | MUI-004 (M1) | L10/L14 layout, O1, O2, hover ≤ 100 ms; `CardFrame`. **Screenshots + sign-off** |
| MUI-007 | [Board rows and tokens](../epics/match-ui/story-007-board-rows-and-tokens.md) (UI, M), L3 W2 | general-purpose (ui-programmer), L3 | 1 | MUI-004 (M1), MR-020 (M0), MR-013, MR-014 (done) | O3 full board, summon and death steps, mid-lunge offset. **Screenshots + sign-off.** The keyword-badge clause needs MR-020 |
| MUI-008 | [Drag to play, drag to attack and the targeting arrow](../epics/match-ui/story-008-drag-to-play-attack-and-targeting-arrow.md) (UI, L), L1 W3 | general-purpose (ui-programmer), L1 | 3 | MUI-005 (M1), **MUI-006, MUI-007 (M2)**, MR-012, CE-004 (done) | drag play and attack, arrow, O4 Taunt, O5 Stealth. **Screenshots + sign-off.** Reads `legal_commands()` on pickup (**Q-5**) |
| MUI-009 | [Mulligan screen](../epics/match-ui/story-009-mulligan-screen.md) (UI, M), L2 W2 | general-purpose (ui-programmer), L2 | 1 | MUI-004 (M1), MUI-006 (L2), MR-004 (done) | O6, 8 subsets, n = 5 mask, effective-cost stamp. **Three screenshots + sign-off** |
| MUI-011 | [Match-end banner and the `match_view_finished` hand-off](../epics/match-ui/story-011-match-end-banner-and-handoff.md) (UI, M), L3 W2 | general-purpose (ui-programmer), L3 | 1 | MUI-005 (M1), MR-008, RNG-007, BAI-015 (done) | O13 (5 banners), `Ended`, O19, `RunShell` double. **Six screenshots + sign-off** |
| MUI-025 | [Hero power by drag: an untargeted `Ready` hero power is dragged to the cast zone](../epics/match-ui/story-025-hero-power-drag-to-cast-zone.md) (UI, S), L1 W3, between MUI-008 and MUI-012 | general-purpose (ui-programmer), L1 | 0.5 | MUI-005 (M1), MUI-008 (L1), CE-011, heroes 001 (done) | drag to the cast zone submits one `use_hero_power`; anywhere else cancels; a single click does nothing until MUI-017 (DD-X34). **Screenshot + sign-off.** Row 11 |
| MUI-012 | [First playable: one War match vs The Torchbearer, mouse-played, on the Windows export](../epics/match-ui/story-012-first-playable-windows-match.md) (Integration, M), L1 W3. **The goal** | general-purpose (ui-programmer), L1; owner plays | 1 | MUI-008, MUI-025 (L1), MUI-009, MUI-011 (M2), MUI-010 (done), **BAI-018 (M3 evidence)**, content 001, BOOT-008 (done) | scripted full match through `InputRouter`; owner plays on the Windows **debug** export; playtest report; `.pck` has no loader. AC-1 hero power (MUI-025), AC-3 release boot (**row 15**) |
| BAI-016 | [Headless AI-vs-AI simulation harness](../epics/boss-ai-match-driver/story-016-sim-harness.md) (Integration, L), L4 W1, `/code-review` at M1 | general-purpose (ai-programmer), L4 | 3 | BOOT-009 (M0), BAI-003, 009, 014, 015 (done); content batch 0; heroes 001/002 (done) | A28 identical-file rerun, A23, A22 advisory, five retained `production/qa/sim/*.json`. AC-4 names `driver_factory` (BOOT-009) |
| BAI-017 | [Planner determinism across implementations](../epics/boss-ai-match-driver/story-017-planner-determinism-across-implementations.md) (Integration, M), L4 W2, `/code-review` at M2 | general-purpose (ai-programmer), L4 | 1 | BAI-001, 015 (done), BAI-016 (M1), **BAI-019 (M1)** | byte-identical across worker, time-sliced and immediate; the one place a real worker runs under `tests/`; `E_BUSY` assertion |
| BAI-018 | [Windows planner A30 and determinism](../epics/boss-ai-match-driver/story-018-windows-planner-a30-and-determinism.md) (Integration, L), L4 W3, the owner's Windows run | general-purpose (evidence), L4; **owner runs** | 3 | BAI-003 (done), BAI-016 (M1), BAI-017 (M2); `MatchView` (MUI-004, M1); the Boot factory (BOOT-009, M0) | boss turn on the Windows export with the worker, A30, 1,000-turn determinism, A22 on band 3. Needs BOOT-009 and row 14. AC-1's release export is **row 15** |

Must Have: 15 stories, ≈ 22.5 story-days.

### Should Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| content-006 | [MVP-1 treasures data](../epics/content/story-006-mvp-1-treasures.md) (Config/Data, S), L5 W1 **[C]**, not on the goal path | general-purpose (game-designer, data), L5 | 0.5 | content 001, treasures 003, CE-015 (done) | the 10 CN-5 records, zero `E_TR_*` / `E_FX_*`, pool 10 ≥ 9, 7 universal. "Validator story path not yet assigned" is treasures 003 |

Should Have: 1 story, 0.5 story-day. **Committed total: 20 stories** (15 + 1 + 4 carryover), ≈ 27.5 story-days.

### Nice to Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| treasures-002 | [Installation order, duplicates and clone](../epics/treasures/story-002-installation-order-duplicates-and-clone.md) (Integration, M), L5 W2 stretch | general-purpose, L5 | 1 | treasures 001, CE-014, CE-015, MR-003, MR-017 (done) | per the story file. Authors against the open absent-`side` default |
| treasures-007 | [Trigger-hook treasures](../epics/treasures/story-007-trigger-hook-treasures.md) (Integration, M), L5 W3 stretch | general-purpose, L5 | 1 | treasures 001, CE-015, MR-005, MR-007 (done) | per the story file |

Stretch also includes carryover **treasures 008** (below). Stretch total: **3 stories**, ≈ 2.5 story-days.

## Carryover from Previous Sprint

By `production/sprint-status.yaml` at the sprint-5 close. Each appears here only. The skill keeps the previous priority in the yaml; this plan **schedules the first four as committed lane work, not stretch**, because committed stories depend on them or an owner decision waits on them.

| Task | Reason | New Estimate |
|------|--------|-------------|
| [MUI-004 MatchView skeleton, Presenter base, `--fixture` loader, first capture, `/perf-profile`](../epics/match-ui/story-004-match-view-skeleton-and-fixture-loader.md) (nice-to-have, `backlog`; sprint 5 stretch, not started: L, needs owner screenshots) | The head of the match-ui chain; MUI-005 … 012 all wait on it. Needs BOOT-009 and BOOT-011 merged at M0 before it can close its AC-2 and AC-3 | 3 (L, 2 links): L1 W1, first in the chain |
| [BAI-019 `CardDatabase.reload()` returns `E_BUSY` while a PlannerTask is live](../epics/boss-ai-match-driver/story-019-reload-busy-while-planning.md) (nice-to-have, `backlog`; sprint 5 stretch, not started: edits `boot.gd`) | Ahead of BAI-017. AC-3 builds a driver "through the composition root's `driver_factory`", which BOOT-009 builds at M0 | 0.5 (S): L4 W1, after BAI-016 |
| [MR-019 Rules engine performance pass](../epics/match-rules/story-019-rules-engine-performance-pass.md) (should-have, `in-progress`) | AC-3 missed: the chain about 14 to 18 ms debug against the 10 ms gate; release not measured (no template). Waits on the owner's R6 | 0.5: close-out on R6 (L6 W1). **No new engine work is planned.** If the owner chooses to optimise further, that is a new story, not this one |
| [MR-018 Performance budgets](../epics/match-rules/story-018-performance-budgets.md) (should-have, `in-progress`) | AC-40 open since sprint 4; carried twice. Closes on MR-019's re-measure or R6 | 0.5: re-measure AC-40 on a release template, close on R6 (L6 W1) |
| [treasures 008 Aura treasures on the hero slot](../epics/treasures/story-008-aura-treasures.md) (nice-to-have, `backlog`; sprint 5 stretch, not started) | Not on the goal path. Needs CE-013 (done). Retro said sprint 6 | 0.5 (S): L5 W2, stretch |

**Carried items that are not stories** (retro-5 action items 1–5; named, no story invented):

| # | Item | Owner | When |
|---|------|-------|------|
| 1 | Read Linux CI on `d181790`, fix anything red, `gh auth login`, re-run `/smoke-check` | Jacob, then orchestrator | before W1 |
| 2 | **R6:** install export templates, measure a release build, decide keep or re-budget the 10 ms gate, close MR-018, then **R5** on boss-ai F7 | Jacob; technical-director for R5 | W1 (R6); pre-W3 (R5) |
| 3 | Write the two missing First Playable pieces (`driver_factory`, `keywords[]`) | producer | **done 2026-11-05**: BOOT-009 and MR-020 (rows 8, 9, and row 10 as found) |
| 4 | Make the local environment boring: `godot` on PATH, a committed per-worktree `user://` wrapper, a Windows screenshot path | tools-programmer | pre-W1, M0: BOOT-010, BOOT-011 (rows 13, 12) |
| 5 | **NC-5:** run the exported debug build, repeated quits for TD-013 | Jacob | W1 (0.5 h in the budget) |

Also open, not stories: TD-014 (`src/ai/**` reads `RulesEngine.state()`; the register assigns it "Sprint 6", Open) — no picked story covers it; the Linux-CI-unread `d181790` goldens; the `--import` exit 139 about 1 in 20 (TD-013 follow-up).

## Readiness notes (run `/story-readiness` on each before `/dev-story`)

- **BOOT-009**:
  - `planner_mode: "immediate"` becomes a data error (DD-X33), and `tests/fixtures/boss_ai/profiles_stub.json` is the one fixture that holds it: it moves to `worker` in the same commit.
  - Open: `--ai-sync` in a release build, and the failed-load behaviour of `driver_factory()`.
- **BOOT-010**: bash only; PowerShell and cmd are not covered. AC-3's export half reads NOT ASSESSED until templates are installed.
- **BOOT-011**: the first Windows capture this project has taken. DD-X32 settles what counts; the control manifest still says Linux only until the next `/create-control-manifest update`. AC-3 reads NOT ASSESSED where no Linux host is available.
- **MR-020**:
  - **Golden regeneration.** The recorder's rule (`tools/match_rules/record_golden_logs.gd`): a golden is regenerated only with a reviewed rules change, in that change's own commit, its diff read by technical-director. Never regenerate one to make `match_rules_golden_log_test.gd` pass.
  - The proof is the stripped diff: removing `keywords`, `player_health` and `boss_health` from the new files gives the old files byte for byte, recorded in the commit message. Expect nine files with `minion_summoned` and twelve with `match_started` of the 16 goldens (checked at `4d79136`), and no others.
  - Run it after retro action 1, so the regeneration does not sit on goldens no one has read on Linux.
  - Open: the names `player_health` / `boss_health` and starting armour. The GDD edit needs the design owner's approval.
- **MUI-025**: AC-1 and AC-4 wait on the dragged button's look (open). The pose name and fixture are picked at readiness. MUI-008 "Unlocks" gains this story then (a note only), and the MUI-005 lift is that story's readiness question.
- **MUI-004**:
  - Needs **BOOT-009** (AC-2 builds the driver "through the same `driver_factory`") and **BOOT-011** (AC-3 and its evidence on Windows, DD-X32) at M0. AC-2's "with `ImmediatePlannerTask`" needs rewording at readiness: an exported loader cannot name a `tests/helpers/` class, so it receives the planner from its caller (BOOT-009 notes).
  - Verify, do not change, the project settings (1280x720, `canvas_items`, `keep`). The trunk has an **uncommitted `project.godot` change** (drops `window/stretch/aspect="keep"` and `renderer/rendering_method`, moves `[editor_plugins]`). Both dropped values equal Godot's defaults, so it looks like an editor re-save, but decide it before MUI-004 starts.
  - It edits `docs/architecture/architecture.md` performance values: the measured numbers come from the CI path (Compatibility/llvmpipe) unless they name a Windows run. DD-X32 covers evidence frames, not these numbers.
  - Stale text: "UX doc not authored"; `design/ux/` has the four approved specs.
- **MUI-005**: AC-1 health stamps need MR-020 (M0); the `state_actionable` End Turn outline reads `legal_commands()` (**Q-5**); AC-4's confirm path stays MUI-017's, and the first playable casts by MUI-025's drag (DD-X34).
- **MUI-006 / 008 / 009 / 011**: refresh the stale "UX doc not authored" lines to `hand.md`, `targeting.md`, `mulligan.md`, `match-end.md`. MUI-008 AC-1 records that a minion with a targeted Battlecry (Phase P → T) is **not covered**; the War starter deck has none (checked: `war_shield_squire` is `targets: owner`).
- **MUI-007**: the keyword-badge clause of AC-1 needs MR-020 (M0). Mid-lunge evidence is taken from the integration test until `--pause-at` exists (MUI-015 is not in this sprint).
- **MUI-010 is done**; its open items (the 0.6 s start steps, F4 `A`) are decisions, not work.
- **MUI-012**: AC-1 includes the hero power (MUI-025, now in its Depends on); AC-2 needs the Windows debug export (**row 14**: the CI artifact, plus this story's preset split so `--fixture` has its fixtures) and the launch route (row 2, NOT ASSESSED); AC-3 names the release boot (**row 15**). Its note says the release build keeps `boot.tscn` as `run/main_scene`; since BOOT-006 it is `main.tscn`. Correct at readiness. MUI-017 depends on 012; keep it out.
- **BAI-016**: AC-4 and the notes build the harness through `driver_factory` (BOOT-009, with `ImmediatePlannerTask` as the override) and need `Heroes` for the hero script (done). It writes five `production/qa/sim/*.json`; a late `passive_driven` row (Q above) means re-running `boss_rot_warden`. `production/qa/sim/` must be covered by `production/.gdignore`.
- **BAI-019**: AC-3 needs a `MatchDriver` from the composition root's factory; the story's note says to add the wiring "where the factory is built", which is BOOT-009 at M0. **Open:** its busy predicate binds `task.is_live` to one task, which goes stale under DD-X31's task per plan. AC-3 and its notes need rewording at readiness to "any task this driver's factory made is live" (recommended in BOOT-009, not decided). The plan does not widen BAI-019.
- **BAI-017**: AC-1's byte-identical runs need a stopped driver clock and zero `ai_fault` on the time-sliced path; the wave-2 review Q-4 says `tick_over_budget` fires on every slice with `slice_ms` = `replay_budget_ms` = 2. Readiness should say how the test stops the clock.
- **BAI-018**:
  - Needs the worker task in a **windowed** match (A30). BOOT-009 settles it: the export passes no override, so `planner_mode: worker` selects `WorkerPoolPlannerTask`, once MUI-004's loader stops naming `ImmediatePlannerTask`.
  - AC-1 names the release export from `commands.build`, which opens on `data_error` (row 15).
  - AC-4: if band 3 misses A22, counts are lowered in `ai_profiles.json` and the run repeated, with a `/quick-design` note. That is the pre-W3 decision and a possible [C] merge.
  - Windows `WorkerThreadPool` behaviour is NOT SOURCEABLE until this run. If it misbehaves, `ThreadPlannerTask` is the drop-in (ADR-0006 Alt 2) and needs its own story.
- **content 006**: Config/Data, advisory evidence (a smoke record). `treasures_balance` stays pending.
- **MR-019 / MR-018**: close on the owner's R6 with a release figure; until a template exists the release row stays NOT ASSESSED. Reviewers' AC-3/AC-4 notes stand.
- **Stretch**: treasures 002 and 007 author against the absent-`side` default; treasures 008 follows CE-013 (done).
- **Hygiene**: sprint 5's lane worktrees (`s5-l1` … `s5-l8`) are still registered under `.claude/worktrees/`. Reuse or prune them at the orchestrator's discretion; none is edited here.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| **BOOT-009 misses M0** (row 8). MUI-004, BAI-016, BAI-019, BAI-018 and MUI-012 build on it | Medium | High: the chain starts at MUI-004 | Fallback L6 W1, merged first at M1; MUI-004 AC-2, BAI-016 AC-4 and BAI-019 AC-3 then close in the W2 fix slots |
| **MR-020 misses M0** (rows 9, 10) | Medium | Medium: MUI-005 AC-1 unmet at M1; no keyword badges in the playtest if it misses altogether | Fallback L6 W1; MUI-005's health stamps close at the W2 fix slot, and MUI-007 (W2) is unaffected |
| **Drag-only hero power in playtest #1** (row 11): a player tries to click Whetstone and nothing happens | High | Low: accepted (DD-X34) | The playtest report records it; MUI-017 follows after First Playable. MUI-025 itself rides L1 W3 with no spare link |
| **BOOT-011 misses M0, or the first Windows capture fails** (row 12) | Medium | High: eight UI stories need retained frames | Row 12 fix (c): a Linux lane (NOT ASSESSED), or the owner retains frames by hand, at 0.25 h more per story that this plan does not budget |
| **BOOT-010 misses M0** (row 13) | Low | Medium: every lane runs through a session shim | Keep the shim, as in sprint 5, and log it; it lands in L5 or L6 W1 and lanes adopt it at M1 |
| **Export templates missing locally** (row 14) | Certain until installed | High for R6, MR-018 and MR-019; the debug export comes from CI | Retro action 2, W1. If templates are late, R6 and the close-out slip. BAI-018 and the playtest use the CI debug artifact, which is NOT ASSESSED until one is downloaded and run |
| **Goal prerequisite missing: a release export past `data_error`** (row 15) | Certain | Low for the goal, Medium for two ACs | Fix (c): name the debug export in MUI-012 AC-3 and BAI-018 AC-1 |
| **Chain depth: three merge points plus a review-fix trip** leaves one slot before 2026-12-08. A W3 return trip sends MUI-008 back for a second sign-off and playtest | High | High: sprint 7 | Decision points at M2 and M3. No owner reserve left, so a return trip overruns 12 h. BAI-018 rehearses the export route early in W3. L1's W2 slot is empty on purpose |
| **L1 at 7.0 links, the measured ceiling,** with two L UI stories in W1 and the first scene build, tooling and `/perf-profile` in MUI-004; 005 builds on a skeleton not yet signed off; MUI-025 adds 0.5 in W3 | Medium | High | Nothing else in L1 W1. If 005 slips, 011 (L3 W2) waits on M2 instead of M1 |
| **Owner hours 12.0 of 12, no reserve.** Eight sign-offs, R6, NC-5, the Windows run, a playtest, verdicts | High | High | Cut order protects the path; stretch is read in sprint 7. NC-5 and the BAI-018 run share the owner's Windows setup. Any overrun goes in the retro |
| **A30 / A22 miss on Windows or band 3** (BAI-018 AC-4); `WorkerThreadPool` unverified on Windows | Medium | Medium: a retune re-runs the evidence | Pre-W3 decision (DQ-2, DQ-3, R5). `ThreadPlannerTask` is the documented drop-in but needs its own story |
| **MR-019 AC-3 stays red** after R6 (the owner keeps 10 ms) | Medium | Low for the goal (band 1 fits at ≈ 144 ms), Medium for band 2 (≈ 500 ms, borderline) | The close-out is bookkeeping. Further engine work needs a story |
| **Linux CI unread**: the sprint-5 goldens and platform fixes have only run on Windows | Medium | Medium | Retro action 1 before W1; a red result becomes a fix lane before M1 |
| **UI review rounds** find defects the tests passed (sprint 5: 14 blocking findings in 6 reviews) | High | Medium | In-wave independent reviews; fix slots in L1 W2 and L2/L3 W3. The first match-ui reviews are the first reviews of the presentation layer |
| **TD-013:** `--import` exits 139 about 1 in 20; the export and capture steps add more engine launches | Low | Low | Re-run once; log it |
| **Review verdicts read NOT ASSESSED**: engine-specialist and qa-tester passes cannot be spawned from a reviewer context | High | Medium | Substitute probes and mutants. Record NOT ASSESSED honestly |
| **Playtest feel**: the first boss group lands about 600 ms after End Turn (MUI-010 notes), and no telegraph banner exists (MUI-015 is not in scope) | High | Low | The playtest report records it; MUI-024 and the open questions pick it up |
| Container pauses, turn caps, worktree loss | Medium | Low | General-purpose lanes; commit before any idle point; log events in `active.md` with UTC |

## Dependencies on External Factors

- **Owner (Jacob)**, within 12 h: the pre-wave decisions; R6 and NC-5 in W1; the UI sign-offs; the Windows run; playtest #1; the close.
- **game-designer** (via the orchestrator): proposes the DD rows for Q-5, `passive_driven` and the Torchbearer line if the owner wants them recorded.
- **tools-programmer**: BOOT-010, BOOT-011 (rows 13 and 12, retro action 4), pre-W1.
- **technical-director**: R5 boss-ai F7 band counts (`/propagate-design-change`) after R6.
- **lead-programmer**: `/code-review` per the review row, each wave.
- **The owner's Windows machine**: Godot 4.7.2 export templates (about 2 GB unpacked) for R6 and any local release measure, the debug export (the CI artifact), a profiler for A30.
- GitHub Actions: `tests.yml` and `windows-export.yml` (release and debug artifacts), and `gh` logged in so CI can be read here.

## Definition of Done for this Sprint

- [ ] All Must Have tasks completed (BOOT-009 … 011, MR-020, MUI-005 … 012, MUI-025, BAI-016 … 018) and the committed carryover (MUI-004, BAI-019, MR-019, MR-018)
- [ ] **First Playable decision recorded** at the M2 and M3 checks and the sprint close: the owner played one War match vs The Torchbearer on a Windows debug export, with a playtest report (`production/qa/playtests/playtest-001-first-playable.md`) and an owner-retained screenshot in `production/qa/evidence/windows-first-light-<date>/`, or sprint 7 declared
- [ ] All tasks pass acceptance criteria, or each unmet clause is recorded against the missing prerequisite row it depends on
- [ ] QA plan exists (`production/qa/qa-plan-sprint-006-[date].md`, from `/qa-plan sprint`), with named cases for MUI-012 AC-1, the Q-5 filter and BAI-018 AC-1 to AC-4
- [ ] All Logic/Integration stories have passing unit/integration tests; every UI story has a retained screenshot in `production/qa/evidence/` and the owner's sign-off
- [ ] Smoke check passed (`/smoke-check sprint`), including the Linux CI read (retro action 1) that sprint 5 lacked
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations (the DD rows for decided owner questions; R5 if F7 is retuned)
- [ ] Code reviewed and merged: every Logic and Integration story has an independent `/code-review` verdict in its "Reviewed by", taken in its own wave; no reviewer moved HEAD
- [ ] Each wave merged one lane at a time: [S] first, [C] last, full suite green after every merge
- [ ] `boot.gd` `_collect_validators()` touched by the orchestrator only
- [ ] Each story committed the moment its suite was green; pauses and worktree losses logged in `active.md` with UTC
- [ ] Owner hours stayed within 12 h, or the overrun is recorded in the retro

QA plan: skipped for now by the owner; run `/qa-plan sprint` before the last story is implemented.

> **Scope check:** run `/scope-check [epic]` if this sprint includes stories added beyond the original epic scope. Five stories were added on 2026-11-05 on the owner's approval (BOOT-009, 010, 011, MR-020, MUI-025), to close Goal Prerequisites rows 8 to 13; no other story was widened, and MUI-012 only gained a dependency on MUI-025. Row 15 stays reported, not planned, and row 14 is left to the owner's template install.
