# Sprint 5 — 2026-11-25 to 2026-12-01

> **Type**: sized by lanes and links, like sprint 4. The retro's link rules apply (`production/retrospectives/retro-sprint-4-2026-11-04.md`, Estimation Accuracy): an opener or a re-open after a merge counts as 2 links, an L as about 1.5, and a story that first runs a new subsystem on the real engine (BAI-007, BAI-008, MR-019) as 2. The boss-ai critical lane carries planner → driver (BAI-007 → 008 → 013 → 015)
> **Stage**: Pre-Production · workflow standard (match-rules and card-effects at `full` via `workflow_overrides`) · review lean · automation guided · story_granularity balanced (6–10 per sprint, scaled by measured velocity: 22 stories in sprint 4) · qa.level standard
> **PR-SPRINT**: skipped — Lean mode
> **QA Plan**: none yet for sprint 5. Run `/qa-plan sprint` before implementation begins. That is the Phase 5 choice [A], the documented default, recorded under the owner's standing approval
> **Milestone**: there is no file in `production/milestones/`, so this plan works from the story backlog. **First Playable: sprint 6, ending 2026-12-08, fallback sprint 7.** The owner accepted it on 2026-11-04 (`production/gate-checks/gate-pre-production-2026-11-03.md`; retro-4 kept it "at lower confidence")
> **Risk register**: none in `production/risk-register/`. Risks below come from the sprint contents only
> **Generated**: 2026-11-04 by `/sprint-plan new`. A subagent followed the skill by hand: it cannot be model-invoked. Owner standing approval applied, so no AskUserQuestion; where the skill asks, the documented default is taken and recorded here
> **Lanes run as `general-purpose` agents.** Role agents stop at 20 turns (retro-4 action 5). A lane's role (ai-programmer, gameplay-programmer, …) goes in its brief, not in its agent type

## Sprint Goal

Land the match driver by merge point 2 on the boss-ai critical lane: lethal search, `plan_turn`, `MatchDriver` construction and `tick()` (BAI-007 → 008 → 013 → 015). That lets `MatchController` / `MatchQuery` (MUI-003) and boss-turn pacing (MUI-010) open in W3. Around it, close the rest of the First Playable branch:
- **boss-ai**: choice, forecast, defensive mode with A31, the purity gates and the phase schedule (BAI-009 … 012, 014);
- **heroes**: the War hero seated from its `HeroDef`, plus the `Heroes` accessor (heroes 001–004);
- **treasures**: installers and the boss passive (treasures 001), the stage-7b validator (003), the pool (009) and the fold treasures (005/006);
- **card-effects**: the hook chain that lets boss passives fire (CE-009, 014, 013, 015), plus the destroy-before-silence check (CE-017);
- **rules engine**: the performance pass in its own match-rules lane (MR-019, which closes MR-018);
- **content**: Gravekeeper back in the boss decks (content 010);
- **W1 fix buffer** for the sprint-4 review. Its top item is Mass Rites' `retrigger` op, which ships broken today.

Nothing new is playable this sprint (MUI-004 is stretch). First Playable stays at **sprint 6 (2026-12-08)**. The M3 check is below.

## First Playable check (accepted: sprint 6, 2026-12-08; fallback sprint 7)

**Retro decision point:** declare sprint 7 at the sprint-5 close if either of these fails:
1. BAI-015 has not merged by sprint-5 M3.
2. The heroes stories were not written in W1.

| Condition (retro-4 § First Playable outlook) | State at plan time | This plan |
|---|---|---|
| **BAI-015 merged by M3** (the M3 check) | Not started | **Planned for M2.** L1 W1 runs BAI-007 → 008, then W2 runs BAI-013 → 015. W3 is a review-fix and slip slot, so BAI-015 has one wave of slack before the check. **At M3 the orchestrator records** "BAI-015 merged at M2 / M3 / not merged". If not merged, the sprint-5 close declares sprint 7 |
| Heroes stories written in W1 | **Met before the sprint.** Heroes 001–004 were written 2026-11-04 (`ecf2da3`, merged `570c4d3`) | Heroes 001/002, which BAI-016 needs for the War starter deck, merge at M1 |
| Story 019 (perf pass) in its own match-rules lane, not the boss-ai lane | — | L6, [S], W2 |
| `docs/s4-ddx18` merged before BAI-008 readiness | **Met.** It merged on the trunk as `fca8476` | F7 `t_sim` is measured (DD-X18), and band 1 (≈ 144 ms) fits the 500 ms planner run. Band 2/3 counts wait for R5 after MR-019 |
| Sprint 5 takes the boss-ai review reading off sprint 6 | — | Every boss-ai story gets its `/code-review` in its own wave. Owner reading is budgeted in W1–W3 (Capacity) |

**Links on the First Playable path in this plan:**
- **Delivered if on plan**:
  - BAI-007, 008, 013, 015 (critical, M1–M2);
  - BAI-009, 010, 011, 012, 014 (BAI-016's inputs);
  - heroes 001, 002 (M1);
  - treasures 001 (M1; boss passives);
  - CE-014 → CE-015 (W2–W3; boss passives fire from the hero slot);
  - MUI-003 and MUI-010 (W3).
- **Left for sprint 6:**
  - **Match-ui chain**: MUI-004 → 005 → 008 → 011 → 012, about 6.5 link-equivalents. It drops to about 5 if stretch MUI-004 lands here.
  - **Boss-ai chain**: BAI-016 (L) → 017 → 018 (L, owner Windows run) → MUI-012. BAI-019 sits ahead of BAI-017; it is stretch here, otherwise sprint 6 W1.
  - **In parallel**: MUI-006, 007, 009, and content 006 (treasures data: needs treasures 003 and CE-015).
- **Sprint-6 shape:** two lanes of about 6.5 and 5 links. That fits the lanes, but the owner's 12 h there remains the constraint (Capacity).

## Goal Prerequisites

The goal has nothing new for a player to run. MUI-004, which is stretch, would give a debug-loaded match view only. The rows below are what the picked stories' criteria, notes and dependencies name.

| Needed to show the goal | Status |
|-------------------------|--------|
| Main scene (`run/main_scene`) for `commands.smoke` | exists (`res://src/scenes/main.tscn`) |
| `RulesEngine.clone()` / `legal_commands()` / `submit()` (BAI-007, 008, 013) | exists (MR-017) |
| Scorer, candidates, tie-break (BAI-007, 008, 009, 010) | exists (BAI-004 … 006) |
| `PlannerTask` seam (BAI-008, 013, 014) | exists (BAI-001) |
| `src/gameplay/run/match_driver.gd` (BAI-014, 015, MUI-003, MUI-010) | built by BAI-013 (L1 W2) |
| `tests/helpers/fake_planner_task.gd` (BAI-013/014, MUI-010's PlannerTask fake) | built by BAI-013 |
| `MatchQuery` (`src/gameplay/match/match_query.gd`; MUI-003; the BAI review S3 read API) | built by MUI-003 (L8 W3) |
| `hero_war` HeroDef and Whetstone hero power (heroes 001/002) | exists (content 001, CE-011) |
| `Treasures.passive_installer` / `HookInstaller` (CE-013, CE-014, CE-015, the treasures stories) | built by treasures 001 (L4 W1) |
| Hero-slot hosting of boss passives (`effect_resolver.gd:531–533`; every MVP boss passive) | built by CE-015 (L5 W3) |
| `retrigger` op for `boss_mass_rites` (content 004, Rot Warden ×3; review S5) | built by the **L7 W1 fix buffer**. Review work, not a story; the owner's brief schedules it. GDD card-effects C5 `retrigger` row is the spec |
| `ai_profiles.json` `op_values.add_counter` (content 010 AC-1) | built by content 010 |
| Card-effects counters (`add_counter` runtime, which content 010's Gravekeeper uses) | built by CE-009 (L5 W1). content 010 follows at W2 |
| G7 gate in `tools/lint/gates.sh` (X1; ADR-0007 Decision 9) | built by the L7 W1 fix buffer |
| `tools/ci/ai_code_gates.sh` (BAI-012) | built by BAI-012 |
| Golden logs `tests/fixtures/match_rules/golden_logs/` (MR-019 AC-2) | built by MR-019. They are recorded on the M1 trunk before any `src/` edit |
| Release export template for MR-019's re-measure (AC-3, AC-40) | exists (used by MR-018: 19.9 ms release) |
| `treasures_v1.json` fixture, 20 T8 records (treasures 001/005/006/009) | built by treasures 001 |
| CI Windows export (gate condition 8; BAI-018 and MUI-012 in sprint 6) | exists (BOOT-008) |
| **`planner_target_ms` (500) as a shipped knob the match UI can read** (MUI-010's DD-X23 criterion: "the beat ends at *t* + 500 (`planner_target_ms`)") | **missing.** The boss-ai GDD Tuning Knobs lists it, but no shipped config carries it: `ai_profiles.json` has no such key, nor does `match_ui.json`. No picked story adds it. BAI-016 (sprint 6) also reads it "from `ai_profiles.json` Tuning Knobs" |

**Fixes for the missing row.** These are open to the owner; this plan applies none of them and edits no story file:
- **(a)** Write a story first: `/create-stories boss-ai-match-driver` for a story that adds `planner_target_ms` to the `ai_profiles.json` runtime block, with its validator row. The story would land in W1 or W2, so MUI-010 (W3) reads it.
- **(b)** Use `/quick-design` on MUI-010. Its test would take the target from the PlannerTask fake's constructor, and the knob's home is left to BAI-016. That leaves the DD-X23 cap untested against data.
- **(c)** Reword MUI-010's DD-X23 criterion to name the boss-ai Tuning Knob value, with no shipped-data read until a story adds the key.

None of them needs a story this sprint holds. The fix it picks decides how far MUI-010 can close.

## Capacity

### Agent capacity (not the constraint)

- **Calendar**: Wed 2026-11-25 – Tue 2026-12-01 (5 working days).
- **Measured basis** (sprint 4): 22 stories done in 259 agent-min over 6 lanes; mean 11.3 min per story, median 8.0.
  - Openers and re-opens averaged 13.8 min, follow-ons 7.3 min.
  - Dependency eligibility and merge points limit the sprint, not agent time.
- **Sizing**:
  - 8 story lanes × 2–5 stories, plus at most one stretch per lane.
  - **Committed: 28 stories**: 13 Must Have, 12 Should Have and 3 carryover (CE-009, CE-014, MR-018). That is ≈ 27.5 story-days on the S 0.5 / M 1 / L 3 label, which is relative size only.
  - **Stretch: 3** (BAI-019, treasures 008, MUI-004). Every stretch story depends only on committed or done stories. **No committed story depends on a stretch story.**
  - Heaviest lane: L4 (treasures) at 7.5 links. Sprint 4's heaviest lanes carried 7, so L4 is at the measured ceiling.
- **Buffer (≈ 20%)**:
  - **L7 W1 is the fix buffer for the sprint-4 review** (`code-review-s4-unreviewed.md`, items below).
  - **L6 W1** fixes the perf harness.
  - **L1 W3** is the BAI-013/015 review-fix and slip slot.
  - **L7 W2 / W3** fix what the previous wave's reviews find.
  - L3 W3 is a free buffer.
- **Merge protocol** (sprints 3–4, unchanged):
  1. Lanes merge one at a time, with the full suite (`commands.test`) after each. Add `-c` when diagnosing.
  2. **[S]** stories edit `tests/helpers/**`, `TestConstants`, `MatchFactory` or `MatchState`. They merge first in their wave.
  3. **[C]** stories start enforcing a shared contract or change the shipped data. They merge last, after running the full suite against the merged state, and fix what they break.
  4. **`src/core/boot.gd` `_collect_validators()` stays orchestrator-owned.** Heroes 004 (`heroes_balance`, M1) and treasures 003 (the `treasure` stage-7b adapter, M2) each name a registration line. The orchestrator adds each line at merge, removes the matching `PENDING_*_OWNERS` entry, and updates the pinned list in `boot_validator_map_test.gd`. The lanes do not touch it.
  5. Lane scratch files are prefixed `<lane>-`. `/dev-story` logs start and end UTC per story.
- **Standing rules** (retro-4 action 5):
  - Commit each story the moment its suite is green, **and before any idle point**.
  - Log every pause, worktree loss and resume in `active.md` with UTC.
  - Keep the committer-identity hook on from the first lane. Check `git log --format=%cn <lane>` before a merge instead of rewriting history.
  - Lanes never hand-edit `sprint-status.yaml`. The orchestrator updates it at merge.
- **Reviews keep pace with the waves** (retro-4 action 1). Every Logic and Integration story gets an independent `/code-review` in its own wave, as listed in the review row of the Lanes table. Findings go to the next wave's L7 slot. W3 findings go to a sprint-6 W1 buffer.
- **Cut order if a wave runs short** (unfinished stories carry; no mid-sprint re-scope):
  - Stretch first: MUI-004, then treasures 008, then BAI-019.
  - Then Should Have: treasures 006 → 005 → 009 → heroes 003 → CE-017 → content 010 → CE-013 → MR-019 → treasures 003 → heroes 004 → MUI-010 → CE-015.
  - Carryover CE-014 is cut only with CE-015, its dependent.
  - Must Have is not cut.

### Owner capacity: 12 h per week (decided 2026-11-04)

Agent build time is not the constraint. **The owner's 12 hours for review and playtesting are the human bottleneck.** Sprint 5 has no UI story except stretch MUI-004, and nothing new to play.

| Wave | Owner work | Hours |
|---|---|---|
| before W1 | **NC-5 Windows checks, owner's plan: later today (2026-11-04), before the sprint.** BOOT-006 Windows row and two frames, CDB-007 known answer `4667ce6e5d01302f`, on `deckdelve-windows-debug-<sha>`. Carried twice. Not counted below; if it slips into W1, add 1.0 h | (1.0) |
| W1 | `/code-review` verdicts: BAI-007, BAI-008 (critical first), CE-009, heroes 001, treasures 001 | 1.25 |
| W1 | Read the fix-buffer outcome (S1, S4, S5, DD-X25, T1/T2, X1, S6/S7, DD-X19) | 0.75 |
| W1 | Design calls: (1) S3 aura keyword/cost projection, where match-rules C10 and match-ui disagree (game-designer proposes, owner approves as a DD row); (2) the fix for MUI-010's missing `planner_target_ms` knob (Goal Prerequisites); (3) confirm or strike content 010's Torchbearer line | 0.5 |
| W2 | `/code-review` verdicts: BAI-013, BAI-015 (critical first), BAI-011, BAI-009 (A31), MR-019, CE-014, CE-013, treasures 003; summaries for CE-017 and heroes 002–004 | 2.5 |
| W2 | Sign off content 010 data (the Gravekeeper deck diffs, validator record) | 0.25 |
| W3 | `/code-review` verdicts: BAI-014, BAI-012, CE-015, MUI-003, MUI-010; summaries for treasures 005/006/009 | 1.5 |
| W3 | MR-019 result. If its AC-3 still misses after R1–R4, decide R6 (re-budget) so MR-018 can close. Read the R5 band-count proposal | 0.5 |
| W3 | MUI-004 screenshot sign-off (**stretch: only if it lands**) | 0.5 |
| W3 | **First Playable prep**: ready the Windows machine and the latest debug artifact for BAI-018's A30 run and playtest #1 (a dry launch, not a playtest), and block the sprint-6 owner hours | 1.0 |
| W3 | Sprint close: smoke report, retro, **the M3 First Playable decision**, approve the sprint-6 plan | 1.0 |
| — | **Total** | **9.75 of 12** (10.75 if NC-5 slips into W1) |

- **Reserve ≈ 2.25 h.** It covers the review reading running over, or a second design call.
- **Sprint-6 owner load, recorded now:**
  - five UI screenshot sign-offs (MUI-004, 005, 008, 009, 011), ≈ 2.5 h; one fewer if MUI-004 lands here;
  - BAI-018's Windows A30 run, ≈ 1 h;
  - MUI-012 playtest #1, 1–2 h;
  - the code-review reading.
  This plan's W3 prep and the in-wave boss-ai reading are what keep that inside 12 h.

## Lanes

A **lane** is one `general-purpose` agent implementing its dependency chain back to back in one worktree, one commit per story, with the full suite green after each. **Waves are merge points.** A story that depends on another lane's story starts only after that story has merged at an earlier merge point.

| Lane | W1 (→ M1) | W2 (→ M2) | W3 (→ M3) | Stretch | Links |
|---|---|---|---|---|---|
| **1 Critical — boss-ai A** (planner → driver) | BAI-007 (M, opener; real engine, 2) → BAI-008 (L, 2; carries A3/A5 and the sim stream) | BAI-013 **[S]** (M, re-open; new `fake_planner_task.gd`) → BAI-015 (M) | BAI-013/015 review-fix and slip slot (buffer) | none | 7 |
| **2 boss-ai B** (choice, forecast, defence, schedule) | BAI-010 (S, opener) | BAI-011 (M, re-open; needs BAI-008 at M1) → BAI-009 (M; A31, DD-X22) | BAI-014 (M, re-open; needs BAI-013 at M2) | **BAI-019** (S), after BAI-014 (needs BAI-013/015 at M2) | 7 (+1) |
| **3 Critical — heroes + content** | heroes 001 (M, opener; `rules_engine.gd` C3.2; [S] if it takes the `card_factory` fixture option) → heroes 002 (S) → heroes 003 (S) → heroes 004 (S; orchestrator registers `heroes_balance` at M1) | content 010 **[C]** (S, re-open; needs CE-009 at M1) | buffer | none | 5.5 |
| **4 Critical — treasures** | treasures 001 (M, opener; [S] if it adds `boss_test_taxman` to `card_factory.gd`) → treasures 009 (S) | treasures 003 (M, re-open; orchestrator registers the `treasure` adapter at M2) | treasures 005 (M, re-open; needs CE-014 at M2) → treasures 006 (M) | **treasures 008** (S; needs CE-013 at M2) | 7.5 (+0.5) |
| **5 card-effects** (hook chain to boss passives) | CE-009 (M, opener; **carryover**; `rules_engine.gd` silence C13.2, DD-X21) | CE-014 (M, re-open; **carryover**; needs treasures 001 at M1) → CE-013 (M; needs treasures 001 at M1) | CE-015 (M, re-open) | none | 7 |
| **6 match-rules perf [S]** | perf-harness fix buffer: S6, S7, DD-X19 (`tests/performance/` only) | **MR-019 [S]** (L, re-open; 2.5). Golden logs are recorded on the M1 trunk before any `src/` edit; it is the **only** `rules_engine.gd` editor in W2 | MR-019 review-fix slot → MR-018 re-measure and close (**carryover**, AC-40) | none | ≈ 6 |
| **7 review fixes** | **fix buffer [C] for the sprint-4 review** (list below; S5 `retrigger` first) | CE-017 **[C]** (S, re-open) + the W1-review fix slot | BAI-012 (S, re-open; needs BAI-008 at M1, BAI-011 at M2) + the W2-review fix slot (+ S3 if decided in W1) | — | 4 + buffers |
| **8 match-ui** | no eligible story: MUI-003 needs BAI-013 (M2) | — | MUI-003 (M, opener; needs BAI-013 at M2) → MUI-010 (M; needs BAI-015 at M2) | **MUI-004** (L, UI), after MUI-003 | 3 (+1.5) |
| **review** | `/code-review` **BAI-007, BAI-008**, CE-009, heroes 001, treasures 001 (summary: heroes 002–004, treasures 009, the fix buffer). Verdicts before M2 merges BAI-013 and CE-014 on top | `/code-review` **BAI-013, BAI-015**, BAI-011, BAI-009, MR-019, CE-014, CE-013, treasures 003 (summary: CE-017, content 010). Verdicts before M3 | `/code-review` BAI-014, BAI-012, CE-015, MUI-003, MUI-010, treasures 005/006 before sprint close. Findings → sprint-6 W1 buffer | — | — |

**Merge order:**
- **M1**:
  1. L4 (treasures 001; [S] if it took `card_factory`).
  2. L3 (heroes 001's `rules_engine.gd` seating; then the orchestrator adds the `heroes_balance` line).
  3. L1 (BAI-008, `boss_ai.gd`).
  4. L2 (BAI-010; rebases on L1's `boss_ai.gd`).
  5. L5 (CE-009: `rules_engine.gd` silence, `effect_resolver.gd`, `ops.gd`, `values.gd`).
  6. L6 (perf tests only).
  7. L7 (fix buffer [C], last; it rebases onto CE-009 in `effect_resolver.gd`, `ops.gd` and `rules_engine.gd`).
- **M2**:
  1. L1 (BAI-013 [S], BAI-015). The critical path lands at M2 whatever MR-019 does.
  2. L6 (MR-019 [S]). Its byte-identical-log claim is then checked by the full suite with BAI-015's replay test on top.
  3. L2.
  4. L4 (treasures 003; then the orchestrator adds the `treasure` adapter).
  5. L5.
  6. L7 (CE-017 [C]).
  7. L3 (content 010 [C], last).
- **M3**:
  1. L6 (MR-019 fixes, MR-018; `rules_engine.gd`).
  2. L7 (BAI-012's CI step; S3 if decided, which also touches `rules_engine.gd`).
  3. L4 (treasures 005/006, test-only; any failing case is fixed in the file that owns it).
  4. L5 (CE-015).
  5. L2 (BAI-014, `match_driver.gd`).
  6. L8 (MUI-003, MUI-010).
  7. L1 (buffer).
- **The orchestrator records the M3 check** (BAI-015 merged at M2 or M3, or not) in `active.md` and the sprint-status header.

**Where the shared files fall:**
- **`rules_engine.gd`**:
  - W1: heroes 001 (C3.2 seating), CE-009 (silence C13.2) and the fix buffer (S1 `discover`, S5's queue call). These are three functions in three lanes, merged in the order above.
  - W2: **MR-019 only.** This keeps the heroes 001 / MR-019 conflict in different waves, as the owner's brief asks.
  - W3: MR-019's fix slot first, then S3 if decided, then any treasures 005/006 fix.
- **`boss_ai.gd`**:
  - W1: BAI-008 (L1), then BAI-010 (L2; rebases).
  - W2: BAI-011 → BAI-009 (L2 only).
  - W3: BAI-014 (L2 only).
- **`match_driver.gd`**: BAI-013 → 015 (L1 W2), then BAI-014 (L2 W3). Never two lanes in one wave.
- **`effect_resolver.gd` / `ops.gd`**:
  - W1: CE-009 (L5) and the fix buffer (L7, [C] last).
  - W2: CE-014 → CE-013 (L5 only).
  - W3: CE-015 (L5).
- **`effect_validator.gd`**: DD-X25 (L7 W1), then CE-017 (L7 W2). Same lane, in series.
- **`input_router.gd`**: MUI-010 creates `controls_locked`, then MUI-004 builds its skeleton around it. Same lane, in series.
- **`tests/performance/match_rules/match_rules_perf_test.gd`**: S6/S7 (L6 W1), then MR-019 AC-4 (L6 W2). Same lane.

**Why lane 8 is empty until W3.** MUI-003 needs BAI-013's `MatchDriver` construction, which merges at M2. Every other match-ui story needs MUI-003, MUI-004, BAI-015 or MUI-012. MUI-010 needs BAI-015 (M2). No plan task or yaml row is created for the idle W1–W2 slot.

### The L7 W1 fix buffer (sprint-4 review, `code-review-s4-unreviewed.md`)

Review work, not stories. Each fix lands with its regression test and a commit that cites the finding. Items are in priority order.

1. **S5: Mass Rites' `retrigger` op is unimplemented.** `boss_mass_rites` appears ×3 in the shipped Rot Warden deck. The validator accepts it, the resolver records it `skipped`, and the planner values it at 1.5.
   - Implement card-effects C5's row: queue the target's live `deathrattle` effects as if raised now, emitting `trigger_queued{reason: retrigger}`, with no-ops `no_target` / `no_such_trigger`.
   - Test it with Mass Rites over Rot Zombies on shipped data.
   - This is the item that **ships broken** today.
2. **S1: an `event_cap` during a Discover offer or resume** leaves a stale `pending_choice` on the Ended state, and the resolver dereferences a null `_engine`.
   - `discover` clears `pending_choice` / `suspended_action` on halt.
   - The resolver survives an unbind in its own frame.
   - Add a P1-style sweep over `k` as the regression test.
3. **S2 → DD-X25.** The effect validator rejects an aura granting `divine_shield` (`E_FX_OP`, via `AURA_UNGRANTABLE_KEYWORDS`), with a validator test. No shipped record has one.
4. **S4: the `hand` selector honours `n`.** It takes F5 picks when `n` is set. Test it with two seeds.
5. **X1: G7 in `tools/lint/gates.sh`.** Use the manifest pattern plus `log\.append\(` and `RandomNumberGenerator`, with a planted-hit test in `boot_lint_gates_test.gd`. Correct CE-007/008's "G7 0 hits" completion notes.
6. **T1 and T2: tests.**
   - T1: a production-resolver queued-pass Discover (P2 / P5 shapes) with `effect_resolved.depth == 1`.
   - T2: one weapon-hosted aura, and one test where the player-before-boss source order is observable.
7. **Records.**
   - Write each of the 13 verdicts into its story's "Reviewed by" (retro-4 action 1).
   - Tick the AC boxes the review lists (N5).
   - Close BOOT-007's Test Evidence (N9).
   - Carry CE-008's N7 C2 defaults into CE-009's readiness.
8. **Optional: BAI review S3**, where the scorer reads `RulesEngine.state()`. The docs half goes here: a TD register entry, plus an ADR-0007 erratum naming the read API Boss AI may use until `MatchQuery`. The code read-through follows in sprint 6, after MUI-003 creates `MatchQuery`.
9. **Not in L7.**
   - **2026-11-04 update:** S3 was decided (DD-X26, option C) and landed before W2 with DD-X27 and DD-X28, so MR-019's golden logs record the new payload. The W3 S3 slots below are retired.
   - **S3** (auras' keyword and cost changes never reach the log or the view) is a GDD conflict: match-rules C10 vs match-ui. A design call comes first (W1, owner). Implementation goes in L7 W3 if decided, otherwise it carries.
   - **S6/S7** (the perf gate's retired 50 ms target; one failing perf gate hides the others) and **DD-X19** (`APPEND_BUDGET_USEC` 50_000 → 80_000 in `tests/performance/rng_event_log/rng_event_log_perf_test.gd`) are L6 W1, because MR-019 edits the same perf file next.
   - The remaining nits (N1–N3, N6, N8, N10–N12) are at the lanes' discretion.

**Other epics checked:**
- **treasures 002, 004, 007, 010, 012**: each needs CE-014 and/or CE-015 merged at an earlier merge point (CE-015 lands at M3), or treasures 007 → sprint 6.
- **treasures 011**: needs Run Structure stories (none exist).
- **treasures 013**: **Blocked** (GDD gap).
- **CE-016**: needs CE-014 and CE-015 → sprint 6.
- **content 006**: needs treasures 003 and CE-015 → sprint 6 W1.
- **content 009**: needs BAI-016.
- **CDB-010**: needs content 009.
- **RNG-009**: needs meta-progression's `AtomicFileWriter` story.
- **RNG-011**: needs run-structure and reward-draft stories.
- **MUI-005 … 024**: need MUI-004 or MUI-012.
- **BAI-016**: needs BAI-014 (M3) → sprint 6 W1.

## Tasks

The Est. Days column uses the S 0.5 / M 1 / L 3 scale as a relative-size label only. Plan by the Links column above. Every lane runs on a `general-purpose` agent; the role in brackets is the brief.

### Must Have (Critical Path)
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| BAI-007 | [Lethal search](../epics/boss-ai-match-driver/story-007-lethal-search.md) (Logic, M), L1 W1, `/code-review` at M1 | general-purpose (ai-programmer), L1 | 1 | BAI-005 (done) | A6–A9: damage-subset DFS, F4 prune, node budget per band, shallow mode; `await checkpoint()` between nodes |
| BAI-008 | [`plan_turn`: the C2 action loop, TurnPlan, `plan_task` and the caps](../epics/boss-ai-match-driver/story-008-plan-turn-loop-and-turn-plan.md) (Logic, L), L1 W1, `/code-review` at M1 | general-purpose (ai-programmer), L1 | 3 | BAI-001, 005, 006 (done), BAI-007 (L1) | A1, A10, A24, A27; A3 / A5 (moved from story 006); C4 sandbox sim stream |
| BAI-013 | [MatchDriver construction, command gate and the concede slot](../epics/boss-ai-match-driver/story-013-match-driver-construction-and-command-gate.md) (Logic, M), L1 W2 **[S]**, `/code-review` at M2 | general-purpose (gameplay-programmer), L1 | 1 | BAI-001, 002 (done), BAI-008 (L1, M1); RulesEngine, EffectResolver (done) | per the story file: construction order, command gate, concede slot; creates `tests/helpers/fake_planner_task.gd` |
| BAI-015 | [MatchDriver `tick()`, bounded replay with checksum, `match_ended`, shutdown](../epics/boss-ai-match-driver/story-015-match-driver-tick-replay-and-shutdown.md) (Integration, M), L1 W2, `/code-review` at M2. **The M3 check** | general-purpose (gameplay-programmer), L1 | 1 | BAI-013 (L1) | per the story file: `tick()`, replay with checksum, `match_ended`, shutdown |
| BAI-010 | [Choice phase: `choose` for Discover and Choose One](../epics/boss-ai-match-driver/story-010-choice-phase.md) (Logic, S), L2 W1 | general-purpose (ai-programmer), L2 | 0.5 | BAI-005, 006 (done) | A16. Lands before a First Playable that includes Gatekeeper (review N10) |
| BAI-011 | [Forecast and telegraphing](../epics/boss-ai-match-driver/story-011-forecast-and-telegraphing.md) (Logic, M), L2 W2 | general-purpose (ai-programmer), L2 | 1 | BAI-008 (M1) | A19, A21: Intent, intent keys, kept, `effective_mode` |
| BAI-009 | [Defensive mode and sandbox fidelity](../epics/boss-ai-match-driver/story-009-defensive-mode-and-sandbox-fidelity.md) (Logic, S → M), L2 W2 | general-purpose (ai-programmer), L2 | 1 | BAI-008 (M1) | A15, A20; **A31 (DD-X22)**: non-lethal face attack gets `f_face = 0`, `f_self = −0.75` on the F1 vulnerability board |
| BAI-014 | [MatchDriver phase schedule](../epics/boss-ai-match-driver/story-014-match-driver-phase-schedule.md) (Logic, M), L2 W3 | general-purpose (gameplay-programmer), L2 | 1 | BAI-013 (M2), BAI-010, BAI-011 (L2) | per the story file: forecast, plan and choose tasks, stale premise, telegraph setting |
| BAI-012 | [Hidden-information purity and the `src/ai` CI gates](../epics/boss-ai-match-driver/story-012-hidden-information-and-purity-gates.md) (Logic, S), L7 W3 | general-purpose (ai-programmer), L7 | 0.5 | BAI-008 (M1), BAI-011 (M2) | A4 decoy hands; A29 literal and thread-symbol gates in `tools/ci/ai_code_gates.sh` plus one `tests.yml` step |
| heroes-001 | [War hero seated from its `HeroDef`](../epics/heroes/story-001-war-hero-seated-from-herodef.md) (Integration, M), L3 W1 | general-purpose (gameplay-programmer), L3 | 1 | MR-003, MR-010, CE-011, CDB-006, content 001 (done) | AC-1 (C3.2 reads the HeroDef), AC-7, AC-8, AC-19: Whetstone on shipped data |
| heroes-002 | [`Heroes` accessor](../epics/heroes/story-002-heroes-accessor.md) (Logic, S), L3 W1 | general-purpose (gameplay-programmer), L3 | 0.5 | CDB-006, content 001 (done) | AC-1 … AC-4: `hero`, `launch_heroes`, `plan_tags` over `CardDatabase` |
| treasures-001 | [`Treasures` installers](../epics/treasures/story-001-installers-passive-and-collect-state.md) (Logic, M), L4 W1, `/code-review` at M1 | general-purpose (gameplay-programmer), L4 | 1 | MR-002, CDB-006 (done) | AC-1, AC-4, AC-10, **AC-T3.1 boss passive**: `installers_for`, `passive_installer`, `collect_state`; `treasures_v1.json` fixture |
| MUI-003 | [MatchController and MatchQuery](../epics/match-ui/story-003-match-controller-and-match-query.md) (Integration, M), L8 W3, `/code-review` at M3 | general-purpose (ui-programmer), L8 | 1 | MUI-001, 002, MR-001, BAI-001 (done), **BAI-013 (M2)** | L2, L13: the three channels, flush-before-submit, engine parity; creates `MatchQuery` |

Must Have: 13 stories, ≈ 13.5 story-days.

### Should Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| MR-019 | [Rules engine performance pass](../epics/match-rules/story-019-rules-engine-performance-pass.md) (Logic, L), L6 W2 **[S]**, `/code-review` at M2 | general-purpose (gameplay-programmer / performance), L6 | 3 | MR-017 (done), MR-018 harness (in tree); L6 W1 perf fixes | AC-1 op/allocation budgets; **AC-2 behaviour byte-identical** (golden logs recorded first); AC-3 worst-case `submit` (AC-40); AC-4 `t_sim` on band 2 per planner run (DD-X18). Not on the band-1 path |
| heroes-003 | [F2 plan-card count and F5 signature synergy](../epics/heroes/story-003-plan-card-and-synergy-checks.md) (Logic, S), L3 W1 | general-purpose, L3 | 0.5 | heroes 002 (L3) | AC-3, AC-F2, AC-5 |
| heroes-004 | [`Heroes.validate_config`, registered at Boot](../epics/heroes/story-004-heroes-balance-config-validator.md) (Logic, S), L3 W1 | general-purpose, L3 | 0.5 | heroes 002 (L3), BOOT-004, CDB-004 (done) | AC-1, AC-2 safe ranges; AC-3 registration. **Orchestrator adds the `heroes_balance` line at M1** |
| treasures-009 | [`Treasures.pool` membership predicate](../epics/treasures/story-009-pool-membership-predicate.md) (Logic, S), L4 W1 | general-purpose, L4 | 0.5 | treasures 001 (L4) | AC-12, AC-11, AC-MVP (Meta absent) |
| treasures-003 | [`TreasureValidator` at stage 7b](../epics/treasures/story-003-treasure-validator-at-stage-7b.md) (Logic, M), L4 W2 | general-purpose, L4 | 1 | treasures 001 (L4), CDB-004, BOOT-004 (done) | AC-5, AC-T7a, AC-T7b, AC-REG. **Orchestrator adds the `treasure` adapter at M2**, emptying `PENDING_RECORD_OWNERS` |
| treasures-005 | [Cost-fold treasures](../epics/treasures/story-005-cost-fold-treasures.md) (Integration, M), L4 W3 | general-purpose, L4 | 1 | treasures 001 (L4), **CE-014 (M2)**, MR-010, MR-011 (done) | AC-16, AC-17, AC-8; test-only, a failing case is fixed where the behaviour lives |
| treasures-006 | [Hand-size and attack-count folds](../epics/treasures/story-006-hand-size-and-attack-fold-treasures.md) (Integration, M), L4 W3 | general-purpose, L4 | 1 | treasures 001 (L4), **CE-014 (M2)**, MR-003, 004, 012 (done) | AC-19, AC-13, AC-23; test-only |
| CE-013 | [Transform, copy-to-hand, bounce, keyword auras from a treasure host](../epics/card-effects/story-013-transform-copy-keyword-aura.md) (Logic, M), L5 W2, `/code-review` at M2 | general-purpose (gameplay-programmer), L5 | 1 | CE-009 (L5), CE-012 (done), **treasures 001 (M1)** | AC-30, AC-31, AC-32 |
| CE-015 | [Trigger hooks as steps and hero-slot observers (treasures, boss passives)](../epics/card-effects/story-015-hook-trigger-steps-hero-slot-observers.md) (Logic, M), L5 W3, `/code-review` at M3 | general-purpose (gameplay-programmer), L5 | 1 | CE-002, 008 (done), CE-009, CE-014 (L5), treasures 001 (M1) | AC-16, AC-36, AC-25, AC-45: boss passives fire from the hero slot (First Playable boss) |
| CE-017 | [Validator: silence before destroy](../epics/card-effects/story-017-validator-silence-before-destroy.md) (Logic, S), L7 W2 **[C]** | general-purpose, L7 | 0.5 | CE-003, CE-004 (done) | AC-47 destroy-before-silence `E_FX_OP` (reference vs search, `repeat` / `conditional` / `choose_one` structure); no new row on shipped data (DD-X21) |
| content-010 | [Gravekeeper returns to the boss decks](../epics/content/story-010-gravekeeper-returns-to-the-boss-decks.md) (Config/Data, S), L3 W2 **[C]** | general-purpose (game-designer, data), L3 | 0.5 | content 001, 003, 004, BAI-003 (done); runtime: CE-009 (M1) | AC-1 `op_values.add_counter 0.5` (DD-X20); AC-2 `neutral_gravekeeper` per CN-2; **AC-3 decks on their B2 recipes, The Torchbearer line kept** (Readiness notes); AC-4 validator clean, smoke record |
| MUI-010 | [Boss-turn pacing](../epics/match-ui/story-010-boss-turn-pacing.md) (Logic, M), L8 W3, `/code-review` at M3 | general-purpose (ui-programmer), L8 | 1 | MUI-002, BAI-003 (done), **BAI-015 (M2)** | L8, L16, the control lock; **DD-X23 commit beat `max(intent_banner_s, p)` up to `planner_target_ms`** (see the missing knob in Goal Prerequisites) |

Should Have: 12 stories, ≈ 11.5 story-days. **Committed total: 28 stories** (13 + 12 + 3 carryover), ≈ 27.5 story-days.

### Nice to Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| BAI-019 | [`CardDatabase.reload()` returns `E_BUSY` while a PlannerTask is live](../epics/boss-ai-match-driver/story-019-reload-busy-while-planning.md) (Integration, S), L2 W3 stretch | general-purpose, L2 | 0.5 | CDB-008, BAI-001 (done), BAI-013, 015 (M2), BAI-014 (L2) | per the story file. Must land before BAI-017 (sprint 6) |
| treasures-008 | [Aura treasures on the hero slot](../epics/treasures/story-008-aura-treasures.md) (Integration, S), L4 W3 stretch | general-purpose, L4 | 0.5 | treasures 001 (L4), **CE-013 (M2)**, CE-011, 012 (done) | AC-22, AC-24 |
| MUI-004 | [MatchView skeleton, Presenter base, `--fixture` loader, first capture, `/perf-profile`](../epics/match-ui/story-004-match-view-skeleton-and-fixture-loader.md) (UI, L), L8 W3 stretch | general-purpose (ui-programmer), L8 | 3 | MUI-002, BOOT-004, content 001 (done), MUI-003 (L8), BAI-015 (M2) | per the story file; **retained screenshot in `production/qa/evidence/` + owner sign-off** (UI gate BLOCKING). Landing it cuts sprint 6's match-ui chain by ≈ 1.5 links |

## Carryover from Previous Sprint
| Task | Reason | New Estimate |
|------|--------|-------------|
| [MR-018 Performance budgets](../epics/match-rules/story-018-performance-budgets.md) (should-have; **In Progress**) | AC-40 worst-case `submit` missed: 25.1 ms debug / 19.9 ms release against 5 ms. It stays open until MR-019 re-measures | 0.5: re-measure AC-40 after MR-019 (L6 W3). If MR-019's AC-3 still misses, the owner decides R6 and MR-018 closes on that decision |
| [CE-009 Deathrattle snapshot, `once_per_turn`, Silence-after-queue, counters](../epics/card-effects/story-009-deathrattle-snapshot-counters.md) (nice-to-have; not started) | Blocked by the destroy-then-silence conflict, cleared by **DD-X21**. Scope grew: the match-rules `silence` change (C13 step 2) and match-rules AC-46 | 1 (M), L5 W1. **Committed this sprint**: CE-013, CE-015 and content 010 build on it |
| [CE-014 Value-hook folds](../epics/card-effects/story-014-value-hook-folds.md) (nice-to-have; not started) | Blocked by the missing treasures `HookInstaller`. treasures 001 builds it at M1 | 1 (M), L5 W2. **Committed this sprint**: CE-015 and treasures 005/006 build on it |

The skill keeps each carryover's previous priority in the yaml (nice-to-have for CE-009 and CE-014). This plan **schedules them as committed lane work, not stretch**, because committed stories depend on them. The counts above include them.

**Carried items that are not stories:**
- **Sprint-4 review findings** (`code-review-s4-unreviewed.md`; 13 stories, no blocking item) → the L7 W1 fix buffer.
- **BAI review open items** (`code-review-s4-bai004-006.md`): S3 docs half (optional, L7 W1); N3 / N4 into BAI-008; N5 into BAI-011; N6 into BAI-012.
- **NC-5 owner Windows checks** (carried twice). The owner runs them later today, before the sprint. If they slip, budget 1 h in W1.
- **DD-X19 code change** (`APPEND_BUDGET_USEC` → 80_000) → L6 W1.
- **`sprint-status.yaml` BOOT-007 stale note** (retro-4 action 5). Fixed in this write, under `previous_sprints`.

## Readiness notes (run `/story-readiness` on each before `/dev-story`)

- **BAI-007 / BAI-008.**
  - The DD-X18 propagation is on the trunk (`fca8476`). F7 `t_sim` is measured. Band 1 (≈ 144 ms) fits the 500 ms per planner run.
  - Band 2/3 counts stand until MR-019 re-measures, followed by R5 (`/propagate-design-change` boss-ai F7). That is not a readiness block for band 1.
  - BAI-008 already carries A3, A5 and the C4 sim stream (`ae3b161`; review S5 closed).
  - Readiness adds two review nits: BAI review N3 (test `collect → score_all → pick` end to end) and N4 (C9's `chosen` vs `alternatives`).
- **BAI-009**: re-sized S → M for A31 (DD-X22). It edits `scorer.gd` and `boss_ai.gd` in L2 W2. No other lane edits them in W2.
- **BAI-011**: BAI review N5. A forecast clone taken in `PlayerTurn.Main` must score the boss side; consider an explicit `side` parameter.
- **BAI-012**: BAI review N6. A29's literal grep is this story's gate, so `candidates.gd`'s `OP_UNVALUED` / `BODY_DIVISOR` literals meet it here.
- **BAI-013**: [S]. It creates `src/gameplay/run/` (a new directory) and `tests/helpers/fake_planner_task.gd`. MUI-010's PlannerTask fake should reuse that helper.
- **MR-019**:
  - Record the golden logs on the M1 trunk, commit them, and only then edit `src/`.
  - It runs after L6 W1 has merged S6/S7, so AC-4 reads `ai_planner_target_ms` from the registry and the gates no longer hide each other.
  - It must not run in the boss-ai lane (retro-4 action 2).
- **heroes 001**: its `rules_engine.gd` C3.2 edit is the cross-epic edit its notes name. It merges at M1, before MR-019 records its goldens.
- **heroes 004 / treasures 003**: the `boot.gd` registration and the `boot_validator_map_test.gd` pinned list are orchestrator work at merge. Readiness should confirm each story's AC-3 / AC-REG is met by the orchestrator's line, as with `ai_profile` in sprint 4.
- **CE-009**:
  - DD-X21 cleared the blocker; AC-21 stands.
  - Its scope includes the match-rules `silence` primitive change and match-rules AC-46 in `match_rules_freeze_silence_test.gd`.
  - Carry the sprint-4 review's N7 C2 defaults (`by: owner`, `side: owner`, `attacker: self`) to game-designer at readiness.
- **CE-014**: the story header reads Ready. Its yaml blocker (no `HookInstaller`) clears when treasures 001 merges at M1.
- **CE-017**: independent of CE-009. It runs after the DD-X25 validator change in the same lane, because both edit `effect_validator.gd`.
- **content 010**:
  - **AC-3's Torchbearer line is kept.** The story offers the owner a strike. The default is to keep it, because it matches DD-X20's intent ("the boss decks that dropped it"). Recorded under the standing approval; the owner can still strike it in W1 (design calls).
  - It runs after CE-009 merges, so Gravekeeper's counter works at runtime when the data ships.
- **MUI-010**:
  - DD-X23 is in its criteria.
  - The `planner_target_ms` source is **missing** (Goal Prerequisites); readiness should record the fix the owner picks.
  - It creates `InputRouter.controls_locked()`, which MUI-004 (stretch) then builds its skeleton around.
- **MUI-003**: creates `MatchQuery` (the ADR-0008 erratum). The BAI review S3 code half reads through it in sprint 6.
- **treasures 005 / 006**: test-only. A failing case is fixed "where it lives": CE-014 (`effect_resolver.gd`) or match-rules (`rules_engine.gd`). They merge after L6 at M3.
- **Stale story text, not in this sprint**:
  - Several match-ui stories (MUI-006, 008, 009, 011, 013 …) still say "UX doc not authored". `design/ux/hand.md`, `targeting.md`, `mulligan.md` and `match-end.md` exist and are APPROVED (gate condition 11).
  - content 006 names "the Treasures epic's validator story (path not yet assigned)". That is now treasures 003.
  - Refresh both at their readiness checks.

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| **BAI-008 (L, 2 links) or BAI-007 overruns W1.** BAI-013/015 would then slip toward M3. If BAI-015 misses M3, First Playable falls to the sprint-7 fallback | Medium | High | Nothing else in L1. BAI-015 is planned at M2, with L1 W3 as the slip slot. The BAI-007/008 verdicts are read before M2 merges BAI-013 on top. Must Have is never cut |
| **Goal prerequisite missing: `planner_target_ms` as a shipped knob** (MUI-010 DD-X23; BAI-016 in sprint 6) | Certain unless fixed | Medium | Owner picks fix (a), (b) or (c) in W1 (design calls) |
| **`rules_engine.gd` edited by three lanes in W1** (heroes 001, CE-009, fix buffer S1/S5), then restructured by MR-019 in W2 | High | Medium | Merge order L3 → L5 → L7 at M1, full suite after each. MR-019 records goldens on the M1 trunk. No other `rules_engine.gd` editor in W2 |
| **MR-019 (L) overruns or misses AC-3** | Medium | Low for First Playable (band 1 fits); Medium for band 2 | Its own lane, W3 fix slot. MR-018 closes on R6 if AC-3 still misses. R5 band counts follow |
| **`retrigger` (S5) is built from a GDD row without a story** | Medium | Medium (Rot Warden plays wrong if mis-specified) | GDD card-effects C5 row as the spec, a shipped-data Mass Rites test, and a review in the W1 review row. The lane records it in content 004's notes |
| **S3 (aura keyword/cost projection) stays undecided.** Gatekeeper's Taunt aura and `war_warlord` +1 Attack would be invisible to the view in sprint 6 | Medium | Medium (sprint-6 UI) | Design call in W1; implementation in L7 W3 if decided; otherwise route to sprint 6 before MUI-007 |
| `boss_ai.gd` edited by L1 (BAI-008) and L2 (BAI-010) in W1 | Medium | Low | L1 merges first; L2 rebases. Later waves have one editor each |
| Two `boot.gd` registrations (M1 heroes 004, M2 treasures 003) against one pinned pending list | Medium | Low | Orchestrator-owned lines at merge; the pinned list is updated in the same merge |
| Shipped-data and contract merges ([C]: fix buffer, CE-017, content 010) break tests that pin warning counts or behaviour | Medium | Medium | [C] merges last per wave, after the full suite against the merged state |
| Lane L4 at 7.5 links (treasures 001 → 009 \| 003 \| 005 → 006) | Medium | Low | treasures 005/006 are test-only. Cut order drops 006 → 005 → 009 first |
| Review verdicts read NOT ASSESSED again: engine-specialist and qa-tester passes cannot be spawned from a reviewer context | High | Medium | Substitute probes and mutants, as in sprint 4. Record the NOT ASSESSED verdict honestly; never round it up |
| **Sprint-6 owner load** (5 UI sign-offs + BAI-018 Windows + playtest #1) exceeds 12 h | Medium | High (the date) | Boss-ai reading done in-wave this sprint; W3 First Playable prep. MUI-004 stretch would move one sign-off here |
| Container pauses, turn caps, worktree loss (sprint 4: a 9 h pause, an uncommitted story) | Medium | Low | General-purpose lanes; commit before any idle point; log every event in `active.md` with UTC |
| treasures 013 Blocked (GDD gap, T7 power band) | Certain | Low (no MVP dependent) | Treasures GDD revision (`/quick-design` or `/design-system treasures`) before it is scheduled |

## Dependencies on External Factors
- **Owner (Jacob)**, within 12 h:
  - NC-5, today and before the sprint;
  - the three W1 design calls (S3; the `planner_target_ms` fix; the Torchbearer line);
  - the review verdict reading in every wave;
  - the content 010 sign-off;
  - the MR-019 R6 decision if needed;
  - First Playable prep and the M3 decision at close.
- **game-designer** (via the orchestrator): propose the S3 DD row and confirm the CE-008 N7 C2 defaults.
- **lead-programmer**: `/code-review` per the review row (each wave).
- **technical-director / ai-programmer**: R5 boss-ai F7 band counts after MR-019 (`/propagate-design-change`).
- Godot 4.7.2 headless + gdUnit4 (`commands.test`). GitHub Actions: `tests.yml`, with BAI-012's added step, and `windows-export.yml`.

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed (BAI-007 … 015, heroes 001/002, treasures 001, MUI-003)
- [ ] **M3 check recorded**: BAI-015 merged at M2 / M3 / not merged, and the First Playable decision taken at close
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-005-[date].md`, from `/qa-plan sprint`), with named cases for `retrigger` (S5), the Discover `event_cap` (S1), MR-019 AC-2 byte-identical logs and match-rules AC-46
- [ ] All Logic/Integration stories have passing unit/integration tests
- [ ] Smoke check passed (`/smoke-check sprint`), including content 010's validator record and the new G7 gate
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations (the S3 DD row if decided; R5 if MR-019 lands)
- [ ] Code reviewed and merged: every Logic and Integration story has an independent `/code-review` verdict in its "Reviewed by", taken in its own wave
- [ ] The sprint-4 review fix buffer merged at M1, and its 13 verdicts are recorded in the stories
- [ ] Each wave merged one lane at a time: [S] first, [C] last, full suite green after every merge
- [ ] `boot.gd` `_collect_validators()` touched by the orchestrator only (heroes 004 at M1, treasures 003 at M2)
- [ ] Each story committed the moment its suite was green and before any idle point; pauses and worktree losses logged in `active.md`
- [ ] Owner hours stayed within 12 h, or the overrun is recorded in the retro

QA plan: run `/qa-plan sprint` before implementation begins.

> **Scope check:** run `/scope-check [epic]` if this sprint includes stories added beyond the original epic scope. Every picked story is an existing story under `production/epics/`. Heroes 001–004, treasures 001–013, content 010, card-effects 017 and match-rules 019 were all written 2026-11-04 from GDD rows or DD decisions. The fix buffer's `retrigger` is existing GDD scope (card-effects C5) without a story.
