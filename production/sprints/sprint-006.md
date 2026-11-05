# Sprint 6 — 2026-12-02 to 2026-12-08

> **Type**: the First Playable sprint, sized by lanes and links like sprints 4 and 5. The retro link rules apply (`production/retrospectives/retro-sprint-4-2026-11-04.md`, Estimation Accuracy): an opener or a re-open after a merge counts as 2 links, an L as about 1.5, and a story that first runs a new subsystem on the real engine as 2. Measured: sprint 5 delivered 26 of 28 committed, and every wave needed a review-fix return trip, so **a wave's real end is one review cycle after its last merge**. This sprint is bound by the depth of one serial chain and by the owner's 12 h, not by agent time
> **Stage**: Pre-Production · workflow standard (match-rules and card-effects at `full` via `workflow_overrides`) · review lean · automation guided · story_granularity balanced (6–10 per sprint, scaled by measured velocity: 26 delivered in sprint 5) · qa.level standard
> **PR-SPRINT**: skipped — Lean mode
> **QA Plan**: none. The owner chose to skip it for now (2026-11-05, Phase 5 choice [B])
> **Milestone**: there is no file in `production/milestones/`, so this plan works from the story backlog. **First Playable: sprint 6, ending 2026-12-08, fallback sprint 7.** The owner accepted it on 2026-11-04 (`production/gate-checks/gate-pre-production-2026-11-03.md`, entry condition 5)
> **Risk register**: none in `production/risk-register/`. Risks below come from the sprint contents only
> **Generated**: 2026-11-05 by `/sprint-plan new`, phases 1–3, followed by hand by a producer subagent (the skill cannot be model-invoked). The owner answered the QA question and approved the write
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
| The two missing First Playable pieces named in retro action 3 (`driver_factory`, `keywords[]`) | **Not met.** No story owns either (verified; Goal Prerequisites rows 8 and 9) | Reported, not planned. **The date depends on the owner's choice here** |

**Remaining path, verified against each story's Dependencies** (the retro list is corrected where it differs):

| Chain | Verified dependency |
|---|---|
| MUI-004 → **005, 006, 007** | each needs only MUI-004 (MUI-003, BOOT-004, content 001, BAI-015 are done) |
| **MUI-008** | needs **005, 006 and 007 all merged**, plus MR-012 and CE-004 (done). MUI-006 and 007 are on the path, not "in parallel" |
| MUI-009 | needs 004 and **006** (`CardFrame`) |
| MUI-011 | needs 005 (and MR-008, RNG-007, BAI-015, done) |
| **MUI-012** | needs 008, 009, 010 (done), 011, **BAI-018**, content 001 (done), BOOT-008 (CI Windows export, exists) |
| BAI-016 → 017 → 018 | 016 needs BAI-003, 009, 014, 015 (done) and the heroes War deck (done); 017 needs 016 and, for its `E_BUSY` assertion, **BAI-019**; 018 needs 016, 017 and the real `MatchView` |
| BAI-019 | needs CDB-008, BAI-001, 013, 014, 015 (done). Story 017 allows its `E_BUSY` assertion to be marked pending; the plan lands BAI-019 first |
| content 006 | not on the path (the playable match carries no treasures). Dependencies are met: treasures 003 and CE-015 are done. Its "validator story path not yet assigned" text is treasures 003 |

**Chain depth sets the date.** MUI-004 → {005, 006, 007} → 008 → 012 cannot be shorter than three merge points (M1, M2, M3), and the M3 stories need a review-fix trip before the owner plays. That leaves one slot, the **close slot**, between M3 and 2026-12-08. **Decision points:** at M2, if MUI-006 or 007 has not merged, MUI-008 cannot start and sprint 7 is declared early. At M3, if MUI-008 or MUI-012 has not merged, the sprint-6 close declares sprint 7.

## Goal Prerequisites

Checked against the repo at `82427f5`. `engine.name` is Godot, so scenes were searched as `*.tscn` (`src/` holds `boot.tscn`, `main.tscn`, `run_shell.tscn` only).

| # | Needed to show the goal | Status |
|---|-------------------------|--------|
| 1 | Playable scene `res://src/ui/match/match_view.tscn`, its presenter scenes and `card_frame.tscn` | built by MUI-004 (skeleton and stubs), then MUI-005, 006, 007, 008, 009, 011 fill them. None exists today |
| 2 | `run/main_scene` | exists (`res://src/scenes/main.tscn`, the `RunShell` stub). The playtest does not use it: it launches through `--fixture` (MUI-012 context, Run UI is not storied). **How the exported debug exe reaches `match_view.tscn` from `-- --fixture=…` is NOT ASSESSED**: `main.gd` reads only `--boot-fail-fixture`, and MUI-012 says "launchable as the scene argument" without a test |
| 3 | `MatchDebugLoader` (debug builds only) | built by MUI-004. Its exclusion from the release `.pck`, the `.pck` grep and the debug/release preset split are built by MUI-012 (`export_presets.cfg` holds one preset today) |
| 4 | Fixtures `turn1_player`, `hand_10`, `midgame_full_board`, `mulligan`, `targeting_taunt`, `targeting_stealth`, `match_end_*` (5), `first_playable` | built by MUI-004, 006, 007, 009, 008, 011, 012. `tests/fixtures/match_ui/` holds only `streams/` today |
| 5 | `MatchDriver`, `MatchController`, `MatchQuery`, `RulesEngine.clone()` | exists (BAI-013/014/015, MUI-003, MR-017) |
| 6 | `planner_target_ms` (500) and `planner_mode` (`worker`) as shipped knobs | exists (`assets/data/ai_profiles.json:193–196`; the sprint-5 gap is closed) |
| 7 | `hero_war`, the 15-card starter deck, Whetstone, `boss_torchbearer` | exists (content 001, heroes 001/002, CE-011). The deck has no Choice, no Discover and no targeted Battlecry, so MUI-013 is not needed |
| 8 | **`driver_factory`** (`RunMachine` calls it; `Boot` supplies it, ADR-0008 Decision 1) | **missing.** `src/` has one mention, a doc comment in `match_driver.gd`. `RunMachine` is not built (run-structure has no stories). MUI-003's notes say "no story builds `driver_factory`". MUI-004 AC-2, BAI-016 AC-4, BAI-019 AC-3, BAI-018 and MUI-012 all name it. BAI-019 lists `src/core/boot.gd` "the `driver_factory` wiring", which cannot be wiring when the factory does not exist. BAI-018 also needs the factory to choose `WorkerPoolPlannerTask`, while MUI-004's loader specifies `ImmediatePlannerTask` |
| 9 | **`keywords[]` on `minion_summoned`** | **missing.** `rules_engine.gd:1265` and `:2386` emit `{side, entity_id, card_id, position, attack, health}`; rng-event-log §D lists `keywords[]`. No printed keyword reaches the view, so MUI-007's badges (Taunt, Divine Shield, …) have no event source. Recorded in MUI-003 L2 and the wave-3 review as "no tracked item". Fix is two payload lines plus a reviewed golden regeneration (retro action 3) |
| 10 | **Starting hero health on an event** | **missing.** `match_started` carries `floor, hero_id, boss_id, player_deck_size` only. `hero.health` is null in the view until the first `damage_dealt` (MUI-001, MUI-003 notes), so MUI-005 AC-1 (health stamps on both portraits in the first capture) cannot be met from events. No story holds it |
| 11 | **Hero-power confirm for untargeted Whetstone** | **missing.** MUI-005 AC-4 says a single click never plays and "that confirm path is Story 017's `KeyTargeting` session". MUI-017 is Ready but depends on MUI-008 **and MUI-012**, and MUI-012 AC-1 plays "hero power" through mouse intents. Found while verifying, not in the retro |
| 12 | **A Windows screenshot path** for retained UI captures | **missing.** `tools/capture.sh` is bash plus `xvfb-run` and the Compatibility renderer. All evidence so far came from the Linux container. Sprint 5 ran on local Windows. UI stories require retained screenshots at every `qa.level` (coding standards). Retro action 4; no story. Frames from a Windows GPU would be Forward+, not ADR-0010's CI renderer, so whether they count is an ADR-0010 question this plan does not settle |
| 13 | **`godot` on PATH and a per-worktree `user://`** | **missing from the repo.** `which godot` finds nothing; the wrapper (`scratchpad/bin/godot` setting `APPDATA` per worktree) and `scratchpad/appdata/s5-l*` live only in the session scratchpad. `git ls-files` lists no wrapper. Retro action 4; no story |
| 14 | **Export templates, and a Windows debug export** | **missing locally.** No template is installed (smoke report); `tools/setup.sh` installs the Linux binary. CI (`windows-export.yml`) exports **release** only. The playtest, BAI-018's A30 profiler half and NC-5 need a debug export; R6 and A22 need a release template. No story builds a debug-export job. Retro action 2 is the owner's template install |
| 15 | **A release export that opens past `data_error`** | **missing for 5 of 6.** `PENDING_CONFIG_OWNERS` still holds `run_structure`, `reward_draft`, `treasures_balance`, `match_ui`, `run_ui`, `profile_defaults`; in a release build each is an `error`, so the load is `Failed` by design. Only `treasures_balance` has a story (treasures 010). The goal itself (a debug playtest) does not need this; MUI-012 AC-3 ("release build boots to its main scene without error") and BAI-018 AC-1 (the `commands.build` release export plays a match) name it |
| 16 | UX specs for hand, targeting, mulligan, match end | exists and APPROVED (`design/ux/hand.md`, `targeting.md`, `mulligan.md`, `match-end.md`). Stories 006, 008, 009, 011 still say "not authored": refresh at readiness |

**Report only.** This plan applies none of the fixes below, adds no task for a missing row, puts none of its work into a picked story, and edits no story file. The three fixes open to the owner for each missing row, as part of the plan and not as a question:

| Row | (a) Pull in a Ready story | (b) Write a story first | (c) Reword the goal to what the sprint can show |
|---|---|---|---|
| 8 `driver_factory` | **None exists.** | `/create-stories boot-composition-root` (Boot supplies it; DD-X31 and the BAI-014 notes give the shape). `RunMachine` itself stays out: the fixture launch does not need it | MUI-004, BAI-016, BAI-018 and MUI-012 build `MatchDriver` directly in the loader and harness. Four ACs lose the words "the same `driver_factory`" |
| 9 `keywords[]` | **None exists.** | `/create-stories match-rules`: the payload lines, the rng-event-log §D reconciliation, a reviewed golden regeneration. It can share a story and one regeneration with row 10 | First Playable tokens show no printed-keyword badges; MUI-007 AC-1 (O3) loses that clause |
| 10 starting health | **None exists.** | `/create-stories match-rules` (match-rules C15 and rng-event-log §D row for the event) | Portraits show no health until the first hit; MUI-005 AC-1 loses the health stamps |
| 11 hero-power confirm | **MUI-017** (Ready, L, Logic). It depends on MUI-008 and MUI-012 as written, so it cannot precede 012 without editing that dependency; pulling it makes 16 committed and adds an L after 008 | `/create-stories match-ui` for a hero-power confirm slice | First Playable is played without the hero power; MUI-012 AC-1 drops it |
| 12 Windows screenshots | **None exists.** | `/create-stories boot-composition-root` (tools), with an ADR-0010 note on Forward+ frames | UI captures come from Linux cloud lanes as in sprints 1–4, or the owner takes and retains them by hand. **NOT ASSESSED** whether a Linux lane is available |
| 13 `godot` PATH, `user://` | **None exists.** | `/create-stories boot-composition-root` (tools), retro action 4 | Lanes keep using the scratchpad shim, as in sprint 5; the risk is accepted and written down |
| 14 templates, debug export | **None exists.** | `/create-stories boot-composition-root` for a CI debug-export artifact (a BOOT-008 sibling) | The owner installs the templates (retro action 2) and exports the playtest build by hand |
| 15 release past `data_error` | **treasures 010** (Ready, S; depends on treasures 007) clears one of six | `/create-stories` for the `match_ui` validator, run-structure, reward-draft, run-ui and meta owners | MUI-012 AC-3 and BAI-018 AC-1 name the debug export; a release export is expected to open on `data_error` |

None of these takes the committed count past the range except pulling MUI-017 (see Capacity). **Which fix the owner picks decides how far MUI-004, 005, 007, 012 and BAI-016, 018, 019 can close** (Readiness notes).

## Capacity

### Agent capacity (not the constraint)

- **Calendar**: Wed 2026-12-02 – Tue 2026-12-08 (5 working days).
- **Measured basis**: sprint 5 delivered 26 of 28 committed (93%), 0 of 3 stretch; 2345 tests. Agent minutes are NOT ASSESSED — NO DATA (restarts distort them); sprint 4's basis was 259 agent-min for 22 stories, mean 11.3 min.
- **Sizing**:
  - 6 lanes (4 carry stories, 2 are fix and close lanes), at most 7 links each. The measured ceiling is 7; **L1 is at 6.5**.
  - **Committed: 15 stories**: 10 Must Have, 1 Should Have, and 4 carryover scheduled as committed (MUI-004, BAI-019, MR-019, MR-018) — about 23 story-days on the S 0.5 / M 1 / L 3 label, relative size only.
  - **Stretch: 3** (treasures 008, 002, 007). **No committed story depends on a stretch story.**
  - 15 is below sprint 5's 28 on purpose. The path is serial and UI-heavy, each UI story costs an owner sign-off, and the Ready backlog beyond the path (treasures 002/004/007/010/012, CE-016) adds owner reading hours without moving the goal. A Ready backlog smaller than the range is never padded.
- **Buffer (≈ 20%)**:
  - L1 W2 is the W1-review fix slot (no story).
  - L2 and L3 W3 are the W2-review fix slots.
  - The **close slot** (Mon–Tue) is the W3 review-fix, the debug export and the playtest. It is not optional.
- **Merge protocol** (unchanged from sprints 3–5):
  1. Lanes merge one at a time, with the full suite (`commands.test`) after each.
  2. **[S]** stories edit shared test helpers or fixtures; they merge first in their wave. None is planned.
  3. **[C]** stories start enforcing a shared contract or change shipped data; they merge last, after the full suite against the merged state. This sprint: content 006 and BAI-019 at M1, any `ai_profiles.json` retune at M3.
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
- **Cut order if a wave runs short** (unfinished stories carry; no mid-sprint re-scope): stretch first (treasures 007, 002, 008), then content 006, then the MR-019/MR-018 close-out. **The 10 Must Have stories and MUI-004 and BAI-019 are not cut.** If the path cannot finish, the goal moves to sprint 7 at the decision points above.

### Owner capacity: 12 h per week

The owner's hours for review and playtesting are the human bottleneck. This sprint has **seven UI stories**, each with a retained screenshot and an owner sign-off (the UI gate is BLOCKING), a Windows run (BAI-018) and playtest #1. Sprint 5's five-sign-off estimate was ≈ 2.5 h; this plan budgets 0.5 h each.

| When | Owner work | Hours |
|---|---|---|
| before W1 (not counted) | Retro 1: read Linux CI on `d181790`, run `gh auth login`, re-run `/smoke-check`. The pre-W1 decision lane (below). Read any `/create-stories` output if the owner picks fix (b). Commit or revert the uncommitted `project.godot` change on the trunk. If any of this slips into W1, add it | (1.25) |
| W1 | **R6** (retro 2): install export templates, measure a release build, decide keep or re-budget the 10 ms gate, close MR-018 | 1.0 |
| W1 | **NC-5** (retro 5, third carry): run the exported debug build, repeated quits for TD-013 | 0.5 |
| W1 | Late pre-W1 decisions: Q-5, `passive_driven` | 0.25 |
| W1 | UI sign-offs: MUI-004 (frame and `perf-profile.md`), MUI-005 | 1.0 |
| W1 | `/code-review` verdicts: BAI-016, BAI-019, MUI-004, MUI-005; summary: content 006 | 0.75 |
| W2 | UI sign-offs: MUI-006 (2 frames), 007 (2), 009 (3), 011 (6) | 2.0 |
| W2 | Verdicts: BAI-017, MUI-006, 007, 009, 011; the W1 fix-slot outcome | 0.75 |
| W2 | Pre-W3 decision: one search per turn and the second-search budget; R5 band counts (retro 2) | 0.25 |
| W3 | UI sign-off: MUI-008 (drag, arrow, Taunt and Stealth frames) | 0.5 |
| W3 | **BAI-018 Windows run**: A30, determinism, A22 on band 3 | 1.0 |
| W3 | **MUI-012 playtest #1** and report | 1.5 |
| W3 | Verdicts: MUI-008, MUI-012, BAI-018 | 0.75 |
| close | Smoke report, retro, the First Playable decision, approve the sprint-7 plan | 1.0 |
| — | **Total** | **11.25 of 12** |

- **Reserve ≈ 0.75 h.** It must cover a W3 review-fix that sends MUI-008 back for a second sign-off and a second playtest. It cannot also cover pulled-in prerequisite stories: each adds its own reading.
- Stretch stories that land add ≈ 0.25 h of reading each; read them in sprint 7 if the hours are gone.
- The owner's real exposure is the W3 stack: sign-off, Windows run, playtest and verdicts in one wave, 3.75 h.

## Lanes

A **lane** is one `general-purpose` agent implementing its dependency chain back to back in one worktree, one commit per story, the full suite green after each. **Waves are merge points.** A story that depends on another lane's story starts only after that story has merged at an earlier merge point.

| Lane | W1 (→ M1) | W2 (→ M2) | W3 (→ M3) | Stretch | Links |
|---|---|---|---|---|---|
| **1 Critical — match-ui A** (the chain) | **MUI-004** (L, opener, new subsystem: first scenes, `Presenter`, loader, capture and `/perf-profile`, 2) → **MUI-005** (L, 1.5) | W1-review fix slot (buffer) | **MUI-008** (L, re-open, 2) → **MUI-012** (M, 1) | none | 6.5 |
| **2 match-ui B** | — | **MUI-006** (M, opener, 2) → **MUI-009** (M, 1; needs 006 in-lane) | W2-review fix slot | none | 3 |
| **3 match-ui C** | — | **MUI-007** (M, opener, 2) → **MUI-011** (M, 1; needs 005 at M1) | W2-review fix slot | none | 3 |
| **4 Critical — boss-ai** | **BAI-016** (L, opener, new subsystem: the harness on the real engine, 2) → **BAI-019** (S, 0.5) | **BAI-017** (M, re-open, 2) | **BAI-018** (L, re-open, 2; the owner's Windows run) | none | 6.5 |
| **5 content + treasures** | **content 006** (S, opener, 2) | — | — | **treasures 008** (S, W2, 2) → **treasures 002** (M, W2, 1) → **treasures 007** (M, W3, 2) | 2 (+5) |
| **6 match-rules perf close** | **MR-019 / MR-018 close-out** (opener, 2): runs only after the owner's R6 decision; closes the stories, plans **no** new engine work | — | — | none | 2 |
| **review** | `/code-review` **BAI-016, BAI-019**, MUI-004, MUI-005 (summary: content 006). Verdicts before M2 | `/code-review` **BAI-017**, MUI-006, 007, 009, 011 (summary: treasures stretch). Verdicts before M3 | `/code-review` **MUI-008, MUI-012**, BAI-018 (evidence read), MR-019 close-out (summary) before the close slot | — | — |

**Why this shape.**
- MUI-004 and MUI-005 share lane 1 in W1 because 005 needs only 004, and a second wave would add a merge point to the chain. It carries the risk that 005 builds on a skeleton the owner has not yet signed off (4 and 5 are signed off together at M1).
- 006, 007, 009 and 011 split across two lanes in W2 so that 006 and 007 both merge at M2, which 008 needs.
- MUI-008 → 012 runs in one lane in W3 because 012's other dependencies (009, 011, BAI-018) are merged by then.
- BAI-018 is the pipeline rehearsal: its debug export on the M2 trunk is the first test of the export route before the playtest.
- Lane 5 and lane 6 carry no goal work. They are the lanes that can idle.

**Merge order:**
- **M1**: 1. L6. 2. L1 (MUI-004, 005). 3. L5 (content 006 **[C]**, shipped data). 4. L4 (BAI-016, then BAI-019 **[C]**, `E_BUSY` enforcement, last).
- **M2**: 1. L1 (W1-review fixes). 2. L2. 3. L3. 4. L4 (BAI-017, tests only). 5. L5 (stretch).
- **M3**: 1. L1 (MUI-008, 012). 2. L2 and L3 fix slots. 3. L5 (stretch). 4. L4 (BAI-018 evidence; any `ai_profiles.json` retune **[C]** last).
- **The orchestrator records the M2 and M3 checks** in `active.md` and the sprint-status header.

**Where the shared files fall:**
- **`src/ui/match/match_view.gd` / `.tscn`**: W1 L1 (004); W2 L3 (011: `Ended`, `match_view_finished`). One editor per wave.
- **`src/ui/match/input_router.gd`**: W1 L1 (005, End Turn and hero-power intents); W3 L1 (008, `Dragging`). Same lane, in series.
- **`src/ui/match/match_debug_loader.gd`**: W1 L1 (004 creates), W2 L2 (006, `hover:` pose), W3 L1 (008, `drag:` pose). One editor per wave.
- **`hand_presenter.gd`, `card_frame.*`**: W2 L2 (006); W3 L1 (008 edits `hand_presenter.gd`). **`board_presenter.gd`**: W2 L3 (007); W3 L1 (008). Never two lanes in one wave.
- **`tools/capture.sh`**: W1 L1 (004). **`export_presets.cfg`, `.github/workflows/`**: W3 L1 (012). **`docs/architecture/architecture.md`** (performance values only): W1 L1 (004).
- **`src/core/boot.gd`, `src/core/data/card_database.gd`, `validation_report.gd`**: W1 L4 (BAI-019), which names a `driver_factory` wiring that does not exist (row 8). Orchestrator-owned lines are untouched.
- **`rules_engine.gd`**: no planned editor. **If the owner chooses to fix rows 9 and 10 by story, that story edits it; it merges first in its wave**, before any golden is compared.
- **`assets/data/ai_profiles.json`**: nobody in W1 unless the owner decides `passive_driven`; W3 L4 only if A22 misses (BAI-018 AC-4). **`assets/data/treasures.json`**: W1 L5 only.
- **`tests/performance/match_rules/**`**: W1 L6 only.

## Pre-wave owner-decision lanes (retro 5 process improvement)

A short lane before each wave: the decisions that wave's stories would otherwise build against. None is a story.

| Lane | Decisions | Lands before |
|---|---|---|
| **Pre-W1** (before 2026-12-02) | The eight Goal Prerequisite fixes (a/b/c per row); Q-5 `legal_commands()` filter; `passive_driven` preference rows; the Torchbearer deck line (content 010 sign-off, still open: the swap goes beyond DD-X20's three decks and the Torchbearer is the playtest opponent); commit or revert `project.godot` | MUI-004, 005, 007, BAI-016, 019 |
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
| MUI-005 | [Hero panels, mana bar, deck piles, top bar, hero power and End Turn](../epics/match-ui/story-005-hero-panels-mana-and-end-turn.md) (UI, L), L1 W1 | general-purpose (ui-programmer), L1 | 3 | MUI-004 (L1), CE-011, MR-010 (done) | F6 rects ±2 px; number pops; End Turn rule; hero-power single click submits nothing (**row 11**). **Retained screenshots + owner sign-off.** AC-1 health stamps need **row 10** |
| MUI-006 | [Hand fan and hover preview](../epics/match-ui/story-006-hand-fan-and-hover-preview.md) (UI, M), L2 W2 | general-purpose (ui-programmer), L2 | 1 | MUI-004 (M1) | L10/L14 layout, O1, O2, hover ≤ 100 ms; `CardFrame`. **Screenshots + sign-off** |
| MUI-007 | [Board rows and tokens](../epics/match-ui/story-007-board-rows-and-tokens.md) (UI, M), L3 W2 | general-purpose (ui-programmer), L3 | 1 | MUI-004 (M1), MR-013, MR-014 (done) | O3 full board, summon and death steps, mid-lunge offset. **Screenshots + sign-off.** The keyword-badge clause needs **row 9** |
| MUI-008 | [Drag to play, drag to attack and the targeting arrow](../epics/match-ui/story-008-drag-to-play-attack-and-targeting-arrow.md) (UI, L), L1 W3 | general-purpose (ui-programmer), L1 | 3 | MUI-005 (M1), **MUI-006, MUI-007 (M2)**, MR-012, CE-004 (done) | drag play and attack, arrow, O4 Taunt, O5 Stealth. **Screenshots + sign-off.** Reads `legal_commands()` on pickup (**Q-5**) |
| MUI-009 | [Mulligan screen](../epics/match-ui/story-009-mulligan-screen.md) (UI, M), L2 W2 | general-purpose (ui-programmer), L2 | 1 | MUI-004 (M1), MUI-006 (L2), MR-004 (done) | O6, 8 subsets, n = 5 mask, effective-cost stamp. **Three screenshots + sign-off** |
| MUI-011 | [Match-end banner and the `match_view_finished` hand-off](../epics/match-ui/story-011-match-end-banner-and-handoff.md) (UI, M), L3 W2 | general-purpose (ui-programmer), L3 | 1 | MUI-005 (M1), MR-008, RNG-007, BAI-015 (done) | O13 (5 banners), `Ended`, O19, `RunShell` double. **Six screenshots + sign-off** |
| MUI-012 | [First playable: one War match vs The Torchbearer, mouse-played, on the Windows export](../epics/match-ui/story-012-first-playable-windows-match.md) (Integration, M), L1 W3. **The goal** | general-purpose (ui-programmer), L1; owner plays | 1 | MUI-008 (L1), MUI-009, MUI-011 (M2), MUI-010 (done), **BAI-018 (M3 evidence)**, content 001, BOOT-008 (done) | scripted full match through `InputRouter`; owner plays on the Windows **debug** export; playtest report; `.pck` has no loader. AC-1 hero power (**row 11**), AC-3 release boot (**row 15**) |
| BAI-016 | [Headless AI-vs-AI simulation harness](../epics/boss-ai-match-driver/story-016-sim-harness.md) (Integration, L), L4 W1, `/code-review` at M1 | general-purpose (ai-programmer), L4 | 3 | BAI-003, 009, 014, 015 (done); content batch 0; heroes 001/002 (done) | A28 identical-file rerun, A23, A22 advisory, five retained `production/qa/sim/*.json`. AC-4 names `driver_factory` (**row 8**) |
| BAI-017 | [Planner determinism across implementations](../epics/boss-ai-match-driver/story-017-planner-determinism-across-implementations.md) (Integration, M), L4 W2, `/code-review` at M2 | general-purpose (ai-programmer), L4 | 1 | BAI-001, 015 (done), BAI-016 (M1), **BAI-019 (M1)** | byte-identical across worker, time-sliced and immediate; the one place a real worker runs under `tests/`; `E_BUSY` assertion |
| BAI-018 | [Windows planner A30 and determinism](../epics/boss-ai-match-driver/story-018-windows-planner-a30-and-determinism.md) (Integration, L), L4 W3, the owner's Windows run | general-purpose (evidence), L4; **owner runs** | 3 | BAI-003 (done), BAI-016 (M1), BAI-017 (M2); `MatchView` (MUI-004, M1); the Boot factory (**row 8**) | boss turn on the Windows export with the worker, A30, 1,000-turn determinism, A22 on band 3. Needs rows 8, 14. AC-1's release export is **row 15** |

Must Have: 10 stories, ≈ 18 story-days.

### Should Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| content-006 | [MVP-1 treasures data](../epics/content/story-006-mvp-1-treasures.md) (Config/Data, S), L5 W1 **[C]**, not on the goal path | general-purpose (game-designer, data), L5 | 0.5 | content 001, treasures 003, CE-015 (done) | the 10 CN-5 records, zero `E_TR_*` / `E_FX_*`, pool 10 ≥ 9, 7 universal. "Validator story path not yet assigned" is treasures 003 |

Should Have: 1 story, 0.5 story-day. **Committed total: 15 stories** (10 + 1 + 4 carryover), ≈ 23 story-days.

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
| [MUI-004 MatchView skeleton, Presenter base, `--fixture` loader, first capture, `/perf-profile`](../epics/match-ui/story-004-match-view-skeleton-and-fixture-loader.md) (nice-to-have, `backlog`; sprint 5 stretch, not started: L, needs owner screenshots) | The head of the match-ui chain; MUI-005 … 012 all wait on it. Needs rows 8 and 12 settled before it can close its AC-2 and AC-3 | 3 (L, 2 links): L1 W1, first in the chain |
| [BAI-019 `CardDatabase.reload()` returns `E_BUSY` while a PlannerTask is live](../epics/boss-ai-match-driver/story-019-reload-busy-while-planning.md) (nice-to-have, `backlog`; sprint 5 stretch, not started: edits `boot.gd`) | Ahead of BAI-017. AC-3 builds a driver "through the composition root's `driver_factory`", which does not exist (row 8) | 0.5 (S): L4 W1, after BAI-016 |
| [MR-019 Rules engine performance pass](../epics/match-rules/story-019-rules-engine-performance-pass.md) (should-have, `in-progress`) | AC-3 missed: the chain about 14 to 18 ms debug against the 10 ms gate; release not measured (no template). Waits on the owner's R6 | 0.5: close-out on R6 (L6 W1). **No new engine work is planned.** If the owner chooses to optimise further, that is a new story, not this one |
| [MR-018 Performance budgets](../epics/match-rules/story-018-performance-budgets.md) (should-have, `in-progress`) | AC-40 open since sprint 4; carried twice. Closes on MR-019's re-measure or R6 | 0.5: re-measure AC-40 on a release template, close on R6 (L6 W1) |
| [treasures 008 Aura treasures on the hero slot](../epics/treasures/story-008-aura-treasures.md) (nice-to-have, `backlog`; sprint 5 stretch, not started) | Not on the goal path. Needs CE-013 (done). Retro said sprint 6 | 0.5 (S): L5 W2, stretch |

**Carried items that are not stories** (retro-5 action items 1–5; named, no story invented):

| # | Item | Owner | When |
|---|------|-------|------|
| 1 | Read Linux CI on `d181790`, fix anything red, `gh auth login`, re-run `/smoke-check` | Jacob, then orchestrator | before W1 |
| 2 | **R6:** install export templates, measure a release build, decide keep or re-budget the 10 ms gate, close MR-018, then **R5** on boss-ai F7 | Jacob; technical-director for R5 | W1 (R6); pre-W3 (R5) |
| 3 | Write the two missing First Playable pieces (`driver_factory`, `keywords[]`) | producer | this plan **reports** them (rows 8, 9) and adds row 10 as found; the stories are `/create-stories`' job |
| 4 | Make the local environment boring: `godot` on PATH, a committed per-worktree `user://` wrapper, a Windows screenshot path | tools-programmer | W1 (rows 12, 13) |
| 5 | **NC-5:** run the exported debug build, repeated quits for TD-013 | Jacob | W1 (0.5 h in the budget) |

Also open, not stories: TD-014 (`src/ai/**` reads `RulesEngine.state()`; the register assigns it "Sprint 6", Open) — no picked story covers it; the Linux-CI-unread `d181790` goldens; the `--import` exit 139 about 1 in 20 (TD-013 follow-up).

## Readiness notes (run `/story-readiness` on each before `/dev-story`)

- **MUI-004**:
  - Blocked in practice by **row 8** (AC-2 builds the driver "through the same `driver_factory`") and **row 12** (AC-3 and its evidence need `tools/capture.sh` under Xvfb). The story file is `Ready`; readiness will find these.
  - Verify, do not change, the project settings (1280x720, `canvas_items`, `keep`). The trunk has an **uncommitted `project.godot` change** (drops `window/stretch/aspect="keep"` and `renderer/rendering_method`, moves `[editor_plugins]`). Both dropped values equal Godot's defaults, so it looks like an editor re-save, but decide it before MUI-004 starts.
  - It edits `docs/architecture/architecture.md` performance values: the measured numbers come from the CI path (Compatibility/llvmpipe) unless row 12 changes that.
  - Stale text: "UX doc not authored"; `design/ux/` has the four approved specs.
- **MUI-005**: AC-1 health stamps need **row 10**; the `state_actionable` End Turn outline reads `legal_commands()` (**Q-5**); AC-4's confirm path is **row 11**.
- **MUI-006 / 008 / 009 / 011**: refresh the stale "UX doc not authored" lines to `hand.md`, `targeting.md`, `mulligan.md`, `match-end.md`. MUI-008 AC-1 records that a minion with a targeted Battlecry (Phase P → T) is **not covered**; the War starter deck has none (checked: `war_shield_squire` is `targets: owner`).
- **MUI-007**: the keyword-badge clause of AC-1 needs **row 9**. Mid-lunge evidence is taken from the integration test until `--pause-at` exists (MUI-015 is not in this sprint).
- **MUI-010 is done**; its open items (the 0.6 s start steps, F4 `A`) are decisions, not work.
- **MUI-012**: AC-1 includes the hero power (**row 11**); AC-2 needs the Windows debug export (**row 14**) and the launch route (row 2, NOT ASSESSED); AC-3 names the release boot (**row 15**). Its note says the release build keeps `boot.tscn` as `run/main_scene`; since BOOT-006 it is `main.tscn`. Correct at readiness. MUI-017 depends on 012; keep it out.
- **BAI-016**: AC-4 and the notes build the harness through `driver_factory` (**row 8**) and need `Heroes` for the hero script (done). It writes five `production/qa/sim/*.json`; a late `passive_driven` row (Q above) means re-running `boss_rot_warden`. `production/qa/sim/` must be covered by `production/.gdignore`.
- **BAI-019**: AC-3 needs a `MatchDriver` from the composition root's factory; the story's note says to add the wiring "where the factory is built". The factory is not built (**row 8**). This is the most direct case of a picked story assuming a missing prerequisite; the plan does not widen BAI-019.
- **BAI-017**: AC-1's byte-identical runs need a stopped driver clock and zero `ai_fault` on the time-sliced path; the wave-2 review Q-4 says `tick_over_budget` fires on every slice with `slice_ms` = `replay_budget_ms` = 2. Readiness should say how the test stops the clock.
- **BAI-018**:
  - Needs the worker task in a **windowed** match (A30), but MUI-004's loader specifies `ImmediatePlannerTask`. **NOT ASSESSED** how the Windows run selects `planner_mode: worker`; row 8.
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
| **Goal prerequisite missing: `driver_factory`** (row 8). MUI-004, BAI-016, BAI-019, BAI-018 and MUI-012 assume it | Certain unless fixed | High: the chain starts at MUI-004 | Owner picks fix (a), (b) or (c) pre-W1. A story written in pre-W1 must be Ready and merged at M1 for MUI-004 to close |
| **Goal prerequisite missing: `keywords[]` on `minion_summoned`** (row 9) | Certain unless fixed | Medium: no keyword badges in the playtest | As above; shares a golden regeneration with row 10 |
| **Goal prerequisite missing: starting hero health on an event** (row 10) | Certain unless fixed | Medium: MUI-005 AC-1 unmet | As above |
| **Goal prerequisite missing: the untargeted hero-power confirm** (row 11) | Certain unless fixed | Medium: MUI-012 AC-1 and the playtest cannot use Whetstone | Owner picks (a) with an edited MUI-017, (b) or (c) |
| **Goal prerequisite missing: a Windows screenshot path** (row 12) | Certain unless fixed | High: seven UI stories need retained frames | Retro action 4; fix (c) has the owner retain frames by hand, at 0.25 h more per story that this plan does not budget |
| **Goal prerequisite missing: `godot` PATH and `user://` isolation committed** (row 13) | Certain | Medium: every lane runs through a session shim | Accept the shim for sprint 6, as in sprint 5; log it |
| **Goal prerequisite missing: export templates and a Windows debug export** (row 14) | Certain | High: R6, NC-5, BAI-018 and the playtest all need one | Retro action 2, W1. If templates are late, BAI-018 and MUI-012 slip and the date goes to sprint 7 |
| **Goal prerequisite missing: a release export past `data_error`** (row 15) | Certain | Low for the goal, Medium for two ACs | Fix (c): name the debug export in MUI-012 AC-3 and BAI-018 AC-1 |
| **Chain depth: three merge points plus a review-fix trip** leaves one slot before 2026-12-08. A W3 return trip sends MUI-008 back for a second sign-off and playtest | High | High: sprint 7 | Decision points at M2 and M3. 0.75 h reserve. BAI-018 rehearses the export route early in W3. L1's W2 slot is empty on purpose |
| **L1 at 6.5 links** with two L UI stories in W1 and the first scene build, tooling and `/perf-profile` in MUI-004; 005 builds on a skeleton not yet signed off | Medium | High | Nothing else in L1 W1. If 005 slips, 011 (L3 W2) waits on M2 instead of M1 |
| **Owner hours 11.25 of 12.** Seven sign-offs, R6, NC-5, the Windows run, a playtest, verdicts | High | High | Cut order protects the path; stretch is read in sprint 7. NC-5 and the BAI-018 run share the owner's Windows setup |
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
- **tools-programmer**: rows 12 and 13 (retro action 4).
- **technical-director**: R5 boss-ai F7 band counts (`/propagate-design-change`) after R6.
- **lead-programmer**: `/code-review` per the review row, each wave.
- **The owner's Windows machine**: Godot 4.7.2 export templates (about 2 GB unpacked), a debug and a release export, a profiler for A30.
- GitHub Actions: `tests.yml` and `windows-export.yml` (release only), and `gh` logged in so CI can be read here.

## Definition of Done for this Sprint

- [ ] All Must Have tasks completed (MUI-005 … 012, BAI-016 … 018) and the committed carryover (MUI-004, BAI-019, MR-019, MR-018)
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

> **Scope check:** run `/scope-check [epic]` if this sprint includes stories added beyond the original epic scope. Every picked story is an existing story under `production/epics/`; none was added or widened. The eight missing prerequisites are reported, not planned.
