# Sprint 4 — 2026-11-18 to 2026-11-24

> **Type**: sized by lanes and links (retro `production/retrospectives/retro-sprint-3-2026-11-04.md`, Process Improvements). Two match-rules lanes carry the critical path to `RulesEngine.clone()` (MR-017)
> **Stage**: Pre-Production · workflow standard (match-rules and card-effects at `full` via `workflow_overrides`) · review lean · automation guided · story_granularity balanced (6–10 per sprint, scaled by measured velocity) · qa.level standard
> **PR-SPRINT**: skipped — Lean mode
> **QA Plan**: none yet for sprint 4. Run `/qa-plan sprint` before implementation begins (Phase 5 choice [A], recorded under the owner's standing approval)
> **Milestone**: no file in `production/milestones/`; planning against the story backlog. **First Playable: sprint 6, ending 2026-12-08, fallback sprint 7 — accepted by the owner 2026-11-04** (`production/gate-checks/gate-pre-production-2026-11-03.md` § Owner decisions recorded after the gate; relayed to this run by the coordinator)
> **Risk register**: none in `production/risk-register/`; risks assessed from the sprint contents only
> **Generated**: 2026-11-04 by `/sprint-plan new` (subagent run under the owner's standing approval, no AskUserQuestion)

## Sprint Goal

Land `RulesEngine.clone()` with replay equivalence (MR-017) by merge point 2 on two match-rules lanes (MR-011 … 017; MR-018 budgets in W3), so the Boss AI scorer and candidate generator (BAI-004, BAI-005) open in W3. In parallel: event observers, values/selectors/Spell Damage, hero powers, auras and Discover in card effects (CE-007, 008, 010, 011, 012); the MVP-1 War set, bundles and four MVP-1 bosses (content 002–005) with the content budget checks (content 008); the load/memory budget (CDB-009) and the Boot responsibilities list (BOOT-007). Nothing new is playable this sprint. First Playable stays at **sprint 6 (2026-12-08)**, fallback sprint 7.

## First Playable outlook (accepted date: sprint 6, 2026-12-08; fallback sprint 7)

- **Path at sprint-3 close** (retro): 15 links: MR-012 → 013 → 014 → 017; BAI-004 / 005 / 007 / 008 / 013 / 015; MUI-004 → 005 → 008 → 011 → 012.
- **This plan delivers 6 of them**: MR-012, 013, 014, 017 (M1–M2) and BAI-004, 005 (W3).
- **After sprint 4, 9 links remain**: BAI-007 → 008 → 013 → 015, then MUI-004 → 005 → 008 → 011 → 012. MUI-003 (needs BAI-013) runs parallel to BAI-015. The other branch after BAI-015 is BAI-016 → 017 → 018 → MUI-012 (4 links), with the new story 019 (`reload()` `E_BUSY`) ahead of BAI-017.
- **At the measured 5 critical links per sprint**:
  - Sprint 5 carries the 4 boss-ai links, so MUI-004 can open in sprint 6 W1.
  - Sprint 6 then carries the 5 match-ui links, with no slack.
  - **Sprint 6 holds only if MR-017 merges at M2 and BAI-004/005 land this sprint.**
- **If MR-017 misses M2** it merges at M3, BAI-004/005 carry into sprint 5 W1, and sprint 5 needs 6 chained boss-ai links. That is over the measured rate, so the date falls to the **sprint 7 fallback**.
- **Conditions on the date** (none of them agent time):
  1. MR-017 by M2 (this plan).
  2. UX specs for hand, targeting, mulligan and match-end (gate condition 11) APPROVED before MUI-005/006/008/009/011 reach readiness in sprint 5–6. `design/ux/` holds none of the four today.
  3. `/create-stories heroes` before BAI-016 (its real-data runs need the War starter deck from the heroes epic).
  4. Owner hours in sprint 6: BAI-018's Windows run, the UI screenshot sign-offs of MUI-004/005/008/009/011 and playtest #1 all fall there. See Capacity.

## Goal Prerequisites

The goal has nothing new to run or show to a player (logic, tests and data). The rows below are what the picked stories' criteria and notes name.

| Needed to show the goal | Status |
|-------------------------|--------|
| Main scene for `commands.smoke` (`run/main_scene`) | exists (`res://src/scenes/main.tscn`) |
| `play_card` / hero power in `legal_commands()` (BAI-004 plays, MR-011, MR-012, MR-016) | exists (MR-010) |
| Attack legality and resolution (BAI-004 trades, CE-014 AC-35, MR-015) | built by MR-012, MR-013 (L1 W1) |
| F1 `effective_cost` with the `modify_cost` fold (CE-012 AC-29, CE-014 AC-33) | built by MR-011 (L2 W1) |
| `discover` / `Choice` phase / `choose` / `resolver.resume` (CE-010, MR-017 C2) | built by MR-016 (L2 W1) |
| Complete `silence` (CE-012 AC-27, CE-009 AC-21) | built by MR-015 (L2 W2) |
| **`RulesEngine.clone()`** (BAI-004 one-ply sandbox; MR-018; the `EffectRuntime` by-value clause moved from CE-002) | built by MR-017 (L2 W2) |
| `tests/fixtures/match_states/` (MR-017 AC-39, MR-018) | built by MR-017 |
| Boss AI `choose` scoring to auto-answer a sandbox Discover (BAI-004 Implementation Notes) | **missing**: BAI-010, not eligible (needs BAI-005 and BAI-006) |
| HeroPowerDef rows for CE-011 | exists as fixture rows 8/16/25 (CE-005); the heroes epic has no stories |
| Treasures `HookInstaller` / `passive_installer` (CE-014, stretch) | **missing**: the treasures epic has no stories |
| Stage-7b `ai_profile` validator registered (content 003 AC-1 "zero `E_AI_*`") | **missing**: `BossAI.validate_ai_profile` exists (`src/ai/boss_ai.gd:213`), but `"ai_profile"` is still in `PENDING_RECORD_OWNERS` (`src/core/boot.gd:49`, `TODO(boss-ai)` at :167). No story owns the registration |
| Reward Draft's registered `bundle_pool_min` (content 005 AC-3) | **missing**: `reward_draft` is still in `PENDING_CONFIG_OWNERS`; the reward-draft epic has no stories |
| `ContentValidator` registered (content 008) | exists (`configs.content_budgets`) |
| `Boot` from stories 004–006 (BOOT-007) | exists |
| Shipped MVP-0 data set (CDB-009) | exists (content 001) |

**Fixes for the missing rows.** These are open to the owner. This plan applies none of them and edits no story file.
- **BAI-010 `choose` for BAI-004.**
  - (a) BAI-004's `/story-readiness` confirms that its four fixtures (A11, A13, A14, A18) raise no Discover. The auto-answer stays out of scope until BAI-010 (the story lists BAI-010 under its notes, not its dependencies).
  - (b) `/quick-design` a placeholder rule (option 0) for the sandbox until BAI-010.
  - (c) Reword the goal to promise only BAI-004's scorer without the Discover path.
- **Treasures `HookInstaller` for CE-014 (stretch).**
  - (a) `/create-stories treasures` first.
  - (b) Readiness accepts a test-side installer. That needs a `/quick-design` note, because the story names the treasures epic.
  - (c) Leave CE-014 out. It is stretch, so the goal does not depend on it.
- **`ai_profile` stage-7b registration for content 003.**
  - (a) `/create-stories` (boss-ai) for the 7b adapter.
  - (b) `/quick-design`: content 003 AC-1 is met by a `ProfileResolver.resolve` test over the shipped rows, with `W_VALIDATOR_PENDING` still listed in the smoke record.
  - (c) Reword content 003's goal line to drop "zero `E_AI_*` through the load".
  - If (a) lands, the orchestrator adds the line at merge, not a lane: remove `"ai_profile"` from `PENDING_RECORD_OWNERS` and add `map["ai_profile"] = BossAI.validate_ai_profile` in `_collect_validators()`.
- **`bundle_pool_min` for content 005.**
  - (a) Check AC-3 against the GDD value (9) and say so in the smoke record.
  - (b) `/create-stories reward-draft` for the config owner.
  - (c) Drop AC-3's "registered" clause by `/quick-design`.

## Capacity

### Agent capacity (not the constraint)

- **Calendar**: Wed 2026-11-18 – Tue 2026-11-24 (5 working days).
- **Measured basis** (sprint 3): 20 stories in 183 agent-min over 6 lanes, slowest lane 56 min. Mean 9.1 min per story; openers 11.2 min, follow-ons 8.0 min. Dependency eligibility limits the sprint, not agent time.
- **Sizing**:
  - 6 story lanes × 2–4 stories, plus at most one stretch per lane. A 7th lane (match-ui) has no eligible story; see Lanes.
  - An opener, or a re-open after a merge, counts as 2 links. An L counts as about 1.5.
  - **Committed: 22 stories**, ≈ 24 story-days on the S 0.5 / M 1 / L 3 label. The labels are relative size only.
  - **Stretch: 3** (CE-009, BAI-006, CE-014). Every stretch story depends only on committed or done stories, and **no committed story depends on a stretch story**.
- **Buffer (≈ 20%)**:
  - L4 W1 is the **fix buffer for the separate sprint-3 review** (the 13 unreviewed stories). It is reserved before any of those findings exist.
  - L1 W2 is the MR-013 review-fix slot. L2 W3 is the MR-017 review-fix slot.
  - Each wave keeps one fix buffer for merge breaks.
- **Merge protocol** (sprint 3's, unchanged):
  1. Lanes merge one at a time, with the full suite (`commands.test`) after each; add `-c` when diagnosing.
  2. **[S]** (edits `tests/helpers/**`, `TestConstants`, `MatchFactory`, `MatchState`) merges first in its wave.
  3. **[C]** (starts enforcing a shared contract or changes the shipped data) merges last, after running the full suite against the merged state, and fixes what it breaks.
  4. **`src/core/boot.gd` `_collect_validators()` stays orchestrator-owned.** No picked story registers a validator. The one conditional line is content 003's `ai_profile` (above), added by the orchestrator at merge only if fix (a) lands.
  5. Lane scratch files are prefixed `<lane>-`. `/dev-story` logs start and end UTC per story.
- **Standing rule (retro action 1): commit each story the moment its suite is green.** Completion Notes may follow in a second commit. After a container restart, resume stopped agents by id, and log the restart in `active.md` with its UTC time and the stories it hit.
- **Cut order if a wave runs short** (unfinished stories carry; no mid-sprint re-scope):
  - Stretch first: CE-014, then BAI-006, then CE-009.
  - Then Should Have: content 008 → BOOT-007 → CDB-009 → content 004 → content 005 → MR-018 → CE-012 → CE-011.
  - Must Have is not cut.

### Owner capacity: 12 h per week (decided 2026-11-04)

Agent build time is not the constraint. **The owner's 12 hours for review and playtesting are the human bottleneck.** Sprint 4 has no UI story and nothing new to play, so the hours go to review reading, data sign-off and the carried Windows checks.

| Wave | Owner work | Hours |
|---|---|---|
| W1 | Read the separate review's verdicts on the 13 sprint-3 stories (≈ 10 min each; CDB-008 and CE-004 … 006 first) | 2.0 |
| W1 | `/code-review` verdicts: MR-013, MR-016 | 1.0 |
| W1 | Approve the MR-016 Discover/after-cast criterion (`/quick-design`, see Readiness notes) and the fixes for the missing prerequisites above | 0.5 |
| W1 | Carried Windows checks on the debug build `deckdelve-windows-debug-<sha>`: BOOT-006's Windows row and two frames, CDB-007's known answer. This is a launch, not a playtest | 1.0 |
| W1 | Decide the event-log append budget (raise it, or optimise after a release-build measurement) | 0.25 |
| W2 | `/code-review` verdict: MR-017 | 0.75 |
| W2 | Sign off content 002 (War set) and 003 (Rat King, Gatekeeper) data | 1.0 |
| W2 | Review `/ux-design` hand and targeting specs (needed for sprint-5/6 readiness) | 1.5 |
| W3 | `/code-review` verdict: BAI-004 | 0.5 |
| W3 | Sign off content 004 (Rot Warden, Hollow King) and 005 (bundles) data | 0.75 |
| W3 | Review `/ux-design` mulligan and match-end specs | 1.5 |
| W3 | Sprint close: read the smoke report and retro, approve the sprint-5 plan | 1.0 |
| — | **Total** | **11.75 of 12** |

- **Flag: the budget is near full, and W1 (4.75 h) is the heaviest wave.** If the 13-story review reading runs over:
  - Read summaries only for the low-tier verdicts (RNG-008/010, content 001/007, MUI-002).
  - Move the mulligan and match-end UX reviews to sprint 5.
- **No playtest slot this sprint**: nothing new is playable. Budget the 1–2 h Windows debug-build playtest in each sprint from the first playable build (MUI-012, sprint 6) on.
- **Flag for sprint 6, recorded now.** The 12 h there must cover:
  - five UI screenshot sign-offs (MUI-004, 005, 008, 009, 011), ≈ 2.5 h;
  - BAI-018's Windows A30 run (owner machine), ≈ 1 h;
  - MUI-012 playtest #1, 1–2 h;
  - the code-review reading.

  That fits only if sprint 5 takes the UX reviews and the boss-ai reading off sprint 6.

## Lanes

A **lane** is one agent implementing its dependency chain back to back in one worktree, one commit per story, with the full suite green after each. **Waves are merge points.** A story that depends on another lane's story starts only after that story has merged at an earlier merge point.

| Lane | W1 (→ M1) | W2 (→ M2) | W3 (→ M3) | Stretch | Links |
|---|---|---|---|---|---|
| **1 Critical — match-rules A** (attacks) | MR-012 (M, opener) → MR-013 **[S]** (M) → MR-014 (M) | MR-013 review-fix slot (buffer) | MR-018 **[S]** (M, re-open; needs MR-017 at M2) | none eligible (epic exhausted) | 6 |
| **2 Critical — match-rules B** (cost, choice, freeze, clone) | MR-011 **[S]** (S, opener) → MR-016 **[S]** (M) | MR-015 **[S]** (M, re-open; needs MR-013 at M1) → **MR-017 [S]** (L; needs MR-014 at M1) | MR-017 review-fix slot (buffer) | none eligible | 6.5 |
| **3 card-effects A** | CE-008 (M, opener) → CE-007 (M) | CE-011 (M, re-open) | CE-012 (M, re-open; needs MR-011 at M1, MR-015 at M2) | **CE-009** (M), W3 after CE-012; needs MR-015 at M2 | 7 (+1) |
| **4 boss-ai** | **fix buffer for the separate sprint-3 review** | CDB-009 **[S]** (S, opener) → BOOT-007 (S) | **BAI-004** (M, re-open; **after MR-017 merges at M2**) → BAI-005 (M) | **BAI-006** (S), W3 after BAI-004 | 5.5 (+0.5) |
| **5 content data** | content 002 **[C]** (M, opener) → content 003 **[C]** (M) | content 005 **[C]** (S, re-open) → content 004 **[C]** (M) | buffer | none eligible: content 006 needs a treasures validator story and CE-015; content 009 needs BAI-016 | 6 |
| **6 tools + card-effects B** | content 008 (M, opener) | CE-010 (L, re-open; needs CE-007 and MR-016 at M1) | buffer | **CE-014** (M), W3; needs CE-008, MR-011, MR-012 at M1 (and the treasures-installer fix above) | 3.5 (+2) |
| **7 match-ui** | no eligible story (below) | — | — | — | 0 |
| **review** | `/code-review` **MR-013, MR-016**. Verdicts land before M2 merges MR-015/017 and CE-010 on top. The separate sprint-3 review's findings → L4 W1 | `/code-review` **MR-017**. Verdict lands before M3 merges BAI-004 and MR-018 on top | `/code-review` **BAI-004**, before sprint close; at the latest before sprint-5 W1 merges BAI-007 on it | — | — |

**Merge order:**
- **M1**: L1 (MR-013 [S]) → L2 (MR-011/016 [S]; rebases onto L1, both edit `test_effect_resolver.gd`) → L3 → L6 → L5 (content [C], last).
- **M2**: L2 (MR-015/017 [S]) → L4 (CDB-009 [S]) → L3 → L6 → L5 ([C], last).
- **M3**: L1 (MR-018 [S]) → L3 → L4 → L6.

**Where BAI-004 lands.** BAI-004's one-ply simulation is `sandbox = engine.clone()` (Implementation Notes). Its story says the match-rules `clone()` / `legal_commands()` / `submit()` are a dependency. So BAI-004 needs MR-017, and it is **placed after MR-017's merge point (M2), in L4 W3**. Its trades need MR-012/013 (M1) and its plays need MR-010 (done). BAI-005 follows it in the lane, and BAI-006 is the lane's stretch. If MR-017 misses M2, BAI-004/005 carry to sprint 5 W1; see the outlook.

**Two match-rules lanes, split by the dependency graph.**
- MR-011, 012 and 016 need only MR-010, so all three open in W1.
- MR-013 → MR-014 follow MR-012 in L1.
- MR-015 needs MR-013 (and MR-009, done), so it opens in L2 W2 after M1.
- MR-017 needs MR-011, 014, 015 and 016, and follows MR-015 in L2 W2.
- MR-018 needs MR-017. It takes L1 W3 after M2.

**Why lane 7 (match-ui) has no story.** MUI-003 needs BAI-013 (driver construction), which chains through BAI-008 → 005/006/007 → BAI-004 → MR-017. Every later story in the first-playable slice needs MUI-003 or MUI-004 (and through them BAI-015) or MUI-012. So no match-ui story is eligible in sprint 4. The slot is free for non-story preparation: `/ux-design` hand, targeting, mulligan and match-end (gate condition 11; owner review in the capacity table). No plan task or yaml row is created for that work.

**Other epics checked:**
- **RNG**: RNG-009 needs the meta-progression `AtomicFileWriter` story, and RNG-011 needs run-structure / reward-draft stories. Neither dependency has a story, so no RNG story is unblocked.
- **CDB-010** needs the MVP-1 batch close (content 009 → BAI-016).

## Tasks

Est. Days use the S 0.5 / M 1 / L 3 scale as a relative-size label only. Plan by the Links column above.

### Must Have (Critical Path)
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| MR-012 | [Attack legality](../epics/match-rules/story-012-attack-legality.md) (Logic, M), L1 W1 | gameplay-programmer | 1 | MR-010 (done) | `can_attack`, `max_attacks` fold + clamp, `attack` validation, `legal_commands` attack expansion |
| MR-013 | [Attack resolution](../epics/match-rules/story-013-attack-resolution.md) (Logic, M), L1 W1 **[S]**, `/code-review` at M1 | gameplay-programmer | 1 | MR-012 (L1) | C8 steps 1–7; **DD-X11**: a defending hero never deals damage back (one `damage_dealt`, weapon durability unchanged); snapshotted attack at the damage step; `on_attack` fixtures |
| MR-014 | [Combat keywords](../epics/match-rules/story-014-combat-keywords.md) (Logic, M), L1 W1 | gameplay-programmer | 1 | MR-013 (L1) | Stealth lost at declaration; keyword reads fixed where the tests surface them |
| MR-011 | [Effective cost, mana payment and temporary crystals](../epics/match-rules/story-011-effective-cost-and-temporary-mana.md) (Logic, S), L2 W1 **[S]** | gameplay-programmer | 0.5 | MR-010, MR-002 (done) | F1 `modify_cost` fold, clamp at 0 once; `add_mana(temporary=true)`; End-step expiry. Edits `match_factory.gd`, `match_state.gd` |
| MR-016 | [Choice phase and Discover](../epics/match-rules/story-016-choice-phase-and-discover.md) (Logic, M), L2 W1 **[S]**, `/code-review` at M1 | gameplay-programmer | 1 | MR-010 (done) | AC-36 boss Discover → `choose(1)` resumes; `Choice` guards (`NOT_YOUR_TURN`, `INVALID_CHOICE`, concede); C2 suspended queue and step count in plain data. **Plus the after-cast check** (Readiness notes) |
| MR-015 | [Freeze, thaw and Silence](../epics/match-rules/story-015-freeze-thaw-silence.md) (Logic, M), L2 W2 **[S]** | gameplay-programmer | 1 | MR-013 (M1), MR-009 (done) | `freeze`, complete `silence`, thaw at End step 4; skipped triggers for `silenced` |
| MR-017 | [Clone and replay](../epics/match-rules/story-017-clone-and-replay.md) (Logic, L), L2 W2 **[S]**, `/code-review` at M2 | gameplay-programmer | 3 | MR-011, MR-016 (L2), MR-014 (M1), MR-015 (L2) | AC-38 200-command replay byte-identical; AC-39 10 fixture states, legal accepted and illegal rejected; C2 clone isolation incl. pending Discover; **the `EffectRuntime` by-value clause moved from CE-002 AC-1** (clone's `state().effects` equal by value, counter mutation isolated) |
| BAI-004 | [Scorer features and board value](../epics/boss-ai-match-driver/story-004-scorer-features-and-board-value.md) (Logic, M), L4 W3, `/code-review` at M3 | ai-programmer | 1 | BAI-002 (done), **MR-017 (M2)**, MR-012/013 (M1), MR-010 (done) | A11 F1 worked example (2.45 / 1.87, `end_turn` −1.0 / −0.33); A13 `aoe_seen` −1/7; A14 Fireball → 6/6; A18 board-full removal × 1.25 |
| BAI-005 | [Candidates, hero-power rule and positions](../epics/boss-ai-match-driver/story-005-candidates-hero-power-rule-and-positions.md) (Logic, M), L4 W3 | ai-programmer | 1 | BAI-004 (L4) | per the story file (hero power with spare mana, adjacent positions, wide-hand prefilter fixtures) |

Must Have: 9 stories, ≈ 10.5 story-days.

### Should Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| MR-018 | [Performance budgets](../epics/match-rules/story-018-performance-budgets.md) (Logic, M), L1 W3 **[S]** | gameplay-programmer | 1 | MR-017 (M2) | perf suite in `tests/performance/match_rules/` (non-blocking job); hook-fold budget unit test; `production/qa/perf-match-rules-<date>.md` |
| CE-008 | [Event observers and queueing](../epics/card-effects/story-008-event-observers-queueing.md) (Logic, M), L3 W1 | gameplay-programmer | 1 | CE-006 (done) | `resolve` for event points, `_responds`, `scope.gd` matcher |
| CE-007 | [Values, selectors and Spell Damage](../epics/card-effects/story-007-values-selectors-spell-damage.md) (Logic, M), L3 W1 | gameplay-programmer | 1 | CE-006 (done), CE-008 (L3; AC-23/24) | C3 selectors and predicates; `conditional`, `repeat`; F1 Spell Damage via match-rules F7; `per_turn` tallies |
| CE-011 | [Hero powers](../epics/card-effects/story-011-hero-powers.md) (Logic, M), L3 W2 | gameplay-programmer | 1 | CE-006 (done), CE-007 (L3); HeroPowerDef fixture rows 8/16/25 | `hero_power` host lookup; `equip`; `buff` on deck instances; `summon` fallback (MUI-005 Whetstone needs it) |
| CE-012 | [Auras and enchantments](../epics/card-effects/story-012-auras-enchantments.md) (Logic, M), L3 W3 | gameplay-programmer | 1 | CE-007 (L3), MR-011 (M1), MR-015 (M2) | AC-26…29: recompute order, Silence on source/recipient (AC-27), `zone: hand` cost aura clamped once (AC-29) |
| CE-010 | [Discover and Choose One](../epics/card-effects/story-010-discover-choose-one.md) (Logic, L), L6 W2 | gameplay-programmer | 3 | CE-006 (done), CE-007 (M1), MR-016 (M1) | `discover`, `choose_one`, `add_to_hand` from pool + filter; `resume` and pass suspension. Must agree with MR-016's after-cast rule |
| CDB-009 | [Load and memory budget](../epics/card-database/story-009-load-and-memory-budget.md) (Logic, S), L4 W2 **[S]** | gameplay-programmer | 0.5 | CDB-006, content 001 (done) | load ≤ `data_load_budget_ms`, memory budget; debug `n_records` / `n_refs` counters. Edits `test_constants.gd` |
| BOOT-007 | [Boot responsibilities in the control manifest](../epics/boot-composition-root/story-007-boot-responsibilities-manifest.md) (Config/Data, S), L4 W2 | technical-director (doc) | 0.5 | BOOT-004/005/006 (done) | `boot-responsibilities.md` matches `boot.gd` members; gate condition 12 handed over. Writes after the L4 W1 fix buffer, in case review fixes touch `boot.gd` |
| content-002 | [MVP-1 War set](../epics/content/story-002-mvp-1-war-set.md) (Config/Data, M), L5 W1 **[C]** | game-designer (data) | 1 | content 001, CE-004 (done) | `cards_war.json` per the story; zero `E_FX_*`; smoke record |
| content-003 | [MVP-1 band-1 bosses: Rat King, Gatekeeper](../epics/content/story-003-mvp-1-band-1-bosses-rat-king-gatekeeper.md) (Config/Data, M), L5 W1 **[C]** | game-designer (data) | 1 | content 001, BAI-002, BAI-003 (done) | AC-1 BossDefs per CN-3 B1; `ai_profile` resolves (see the missing `ai_profile` registration above) |
| content-005 | [MVP-1 bundles](../epics/content/story-005-mvp-1-bundles.md) (Config/Data, S), L5 W2 **[C]** | game-designer (data) | 0.5 | content 002 (L5) | AC-1 10 bundles; AC-2 coverage and band split; AC-3 pool threshold (see the missing `bundle_pool_min` above) |
| content-004 | [MVP-1 bosses: Rot Warden, Hollow King](../epics/content/story-004-mvp-1-bosses-rot-warden-hollow-king.md) (Config/Data, M), L5 W2 **[C]** | game-designer (data) | 1 | content 002 (L5), content 001, BAI-003 (done) | BossDefs and decks per the story; same `bosses.json` / `cards_boss.json` as content 003, so the same lane runs them in series |
| content-008 | [Content budget checks](../epics/content/story-008-content-budget-checks.md) (Logic, M), L6 W1 | tools-programmer | 1 | content 007 (done) | budget checks in `ContentValidator` with fixtures under `tests/fixtures/data/content_checks_*/` |

Should Have: 13 stories, ≈ 13.5 story-days. **Committed total: 22 stories, ≈ 24 story-days.**

### Nice to Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| CE-009 | [Deathrattle snapshot, `once_per_turn`, Silence-after-queue, counters](../epics/card-effects/story-009-deathrattle-snapshot-counters.md) (Logic, M), L3 W3 stretch | gameplay-programmer | 1 | CE-007, CE-008 (L3), CE-012 (L3; AC-20), MR-015 (M2) | AC-21 queued Deathrattle survives Silence; snapshot refs; counters |
| BAI-006 | [Tie-break and stream draws](../epics/boss-ai-match-driver/story-006-tie-break-and-stream-draws.md) (Logic, S), L4 W3 stretch | ai-programmer | 0.5 | BAI-004 (L4), RNG fork (done) | per the story file (tie set board fixture) |
| CE-014 | [Value-hook folds](../epics/card-effects/story-014-value-hook-folds.md) (Logic, M), L6 W3 stretch | gameplay-programmer | 1 | CE-002 (done), CE-008, MR-011, MR-012 (M1); treasures `HookInstaller` (**missing**, see above) | AC-33 `modify_cost` order and clamp; AC-34 `modify_damage` + `hook_delta`; AC-35 `modify_max_attacks` |

## Candidates for later sprints (not in this sprint)

| Story | Status | Placement |
|---|---|---|
| [boss-ai-match-driver story 019 — `CardDatabase.reload()` returns `E_BUSY` while a PlannerTask is live](../epics/boss-ai-match-driver/story-019-reload-busy-while-planning.md) (Integration, S; the ADR-0006 gap from retro action 2) | Ready (written 2026-11-04, `ae5f87c`) | It depends on CDB-008 and BAI-001 (done) and on BAI-013, 014, 015 (the match driver). So it goes **after BAI-015**: sprint 5 W3 at the earliest, otherwise sprint 6 W1. It unlocks BAI-017's `E_BUSY` assertion, so it must land before BAI-017 |
| BAI-007 → 008 → 013 → 015; BAI-009, 010, 011, 012, 014; MUI-003 (after BAI-013) | Ready | Sprint 5: the critical path for the sprint-6 date |
| MUI-004 → 005 → 008 → 011 → 012; MUI-006, 007, 009, 010 | Ready (UX docs pending for 005/006/008/009/011) | Sprint 6 |

## Readiness notes (run `/story-readiness` on each before `/dev-story`)

- **MR-016: the Discover pause and the after-cast steps (the review's risk).**
  - The risk: a spell that pauses for a Discover choice must **not** run its after-cast steps (the rest of its effect list, `on_spell_cast` / after-cast observers, leaving `resolving`, the `card_played` / spell-resolved bookkeeping, `win_loss_check`) until `choose` arrives.
  - After `choose`, those steps must run exactly once, in order, with the same `cause_seq` chain.
  - MR-016's three ACs cover the boss Battlecry case and the suspended queue, but no AC names a player **spell** with steps after the `discover`.
  - Add that criterion by `/quick-design` before MR-016's readiness check (owner approval budgeted in W1), or carry it as a named QA-plan case. This plan edits no story file.
  - CE-010's resolver pass suspension must honour the same rule, so CE-010 (W2) builds on MR-016's merged behaviour and its review verdict.
- **MR-017.** Its C2 clone-isolation criterion already carries the clause moved from CE-002 AC-1 (2026-11-03). Readiness confirms the clause and the fixture-loading choice (a) in its notes.
- **MR-013.** DD-X11 is recorded and its AC is written. `/story-readiness` lifts the epic's N-05 block.
- **BAI-004.**
  - It starts only after M2 and MR-017's merge. Its `/code-review` verdict on MR-017 should be read first.
  - `score_all` is a coroutine (`await planner.checkpoint()`, BAI-001 done).
  - For the sandbox Discover auto-answer, see Goal Prerequisites.
- **CE-007** runs after CE-008 in the same lane, because AC-23/24 queue turn triggers through CE-008.
- **CE-012** is in W3 because AC-27 needs MR-015's complete Silence (M2) and AC-29 needs MR-011's F1 (M1).
- **Content 002–005** change the shipped data ([C]). Each one runs `validate.gd`, keeps a smoke record, and expects `W_POOL_SIZE` counts to fall as the pools fill.
- **CDB-009** is [S] (it edits `test_constants.gd`) and merges first after L2 at M2.
- **BOOT-007** reads `boot.gd` after the W1 fix buffer has merged.
- **Gate condition 11.** No picked story is a UI story, so no sprint-4 readiness check needs a UX doc. The four missing specs gate sprint 5–6.

## Carryover from Previous Sprint
| Task | Reason | New Estimate |
|------|--------|-------------|
| — | None: sprint 3 closed 20/20 (`production/sprint-status.yaml`, previous_sprints) | — |

**Carried items that are not stories:**
- **The independent review of the 13 unreviewed sprint-3 stories** (retro action 3). A separate agent is running it now, with CDB-008 and CE-004 … 006 first. Its fixes go to L4 W1. Its verdicts go into each story's "Reviewed by" line, including the 7 already reviewed.
- **Owner Windows checks** (debug build): BOOT-006's Windows row and frames, and CDB-007's known answer. Budgeted in W1.
- **Event-log append budget decision** (51–60 ms local vs 50 ms; CI 33–47 ms). Budgeted in W1.

## Owner items

| Item | Status |
|---|---|
| First Playable date | **Resolved 2026-11-04: accepted, sprint 6 (ends 2026-12-08), fallback sprint 7.** Recorded as the milestone date |
| Weekly hours (gate condition 3) | **Resolved 2026-11-04: 12 h/week** for review and playtesting. Budgeted under Capacity |
| Windows playtest of the debug build | Open, not blocking. This sprint has a launch check only (W1); the 1–2 h playtest starts with the first playable build (sprint 6) |
| Event-log append budget | Open, not blocking (W1) |
| Fixes for the four missing prerequisites (Goal Prerequisites) | Open, not blocking (W1, 0.5 h) |

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| **MR-017 misses M2.** L2 W2 carries MR-015 (re-open) and MR-017 (L), about 3.5 links in one wave. BAI-004/005 then carry, and First Playable falls to the sprint-7 fallback | Medium | High | L2 W1 is light (MR-011 S + MR-016). The MR-013 verdict is read before M2, and its fixes go to L1 W2, not L2. MR stories are never cut |
| **Goal prerequisite missing: BAI-010 `choose` for BAI-004's sandbox Discover** | Medium | Medium | Fix (a): fixtures with no Discover; record it at readiness |
| **Goal prerequisite missing: stage-7b `ai_profile` registration for content 003 AC-1** | Certain unless fixed | Low | Fix (a), (b) or (c) above. The orchestrator owns the `boot.gd` line if (a) lands |
| **Goal prerequisite missing: Reward Draft `bundle_pool_min` for content 005 AC-3** | Certain unless fixed | Low | Fix (a): check against the GDD value 9 in the smoke record |
| **Goal prerequisite missing (stretch): treasures `HookInstaller` for CE-014** | Certain unless fixed | Low (stretch) | Leave CE-014 out, or `/create-stories treasures` |
| MR-016's Discover pause lets a spell's after-cast steps run before `choose` | Medium | High (corrupts `clone()` and replay in MR-017, and CE-010) | Add the after-cast criterion before readiness; `/code-review` MR-016 at M1, before CE-010 and MR-017 merge on it |
| Two [S] match-rules lanes both edit `test_effect_resolver.gd` / `MatchState` in W1 | High | Medium | L1 merges first, then L2 rebases; `-c` when diagnosing |
| Shipped-data merges (content 002–005 [C]) break tests that pin warning counts | Medium | Medium | [C] merges last per wave, after the full suite against merged state |
| The separate sprint-3 review returns more fixes than L4 W1 holds | Medium | Medium | Blocking findings first. Others go to the W2/W3 buffers in L5/L6. BOOT-007 and CDB-009 can slip to W3 before BAI-004 |
| **Owner hours: 11.75 of 12 h budgeted; W1 at 4.75 h** | Medium | Medium | Summary-only reading for low-tier verdicts. Move the mulligan and match-end UX reviews to sprint 5 |
| **Sprint-6 owner load** (5 UI sign-offs + BAI-018 Windows + playtest #1) exceeds 12 h | Medium | High (the date) | Do the UX reviews and the boss-ai reading in sprint 5; plan sprint 6 owner work first |
| Container restarts (3 in sprint 3) | High | Low | Standing rule: commit each story when green; log restarts in `active.md` |
| Match-ui lane idle; UX specs (gate condition 11) still missing | Certain | Medium (sprint 5–6) | `/ux-design` in the idle slot; owner review budgeted W2/W3 |
| Heroes epic has no stories; BAI-016 needs the War starter deck from it | Certain | Medium (sprint 6) | `/create-stories heroes` during sprint 4 or 5 |
| G7 field-list gate still unowned while `src/gameplay/effects/` grows (CE-007 … 012) | Medium | Medium | G7 by hand in the sprint smoke check |

## Dependencies on External Factors
- **Owner (Jacob)**, within 12 h:
  - the review verdict reading;
  - the MR-016 criterion and the missing-prerequisite fixes;
  - the Windows debug-build checks;
  - the append-budget decision;
  - the content data sign-offs;
  - the UX spec reviews.
- **The separate review agent**: sprint-3 review verdicts by M1.
- **lead-programmer**: `/code-review` of MR-013, MR-016 (M1), MR-017 (M2) and BAI-004 (M3).
- **ux-designer**: `/ux-design` hand, targeting, mulligan, match-end (non-story).
- **producer**: `/create-stories heroes` (for BAI-016), and optionally treasures / reward-draft / the boss-ai 7b adapter for the missing prerequisites.
- Godot 4.7.2 headless + gdUnit4 (`commands.test`); GitHub Actions (`tests.yml`, Windows Export with the debug artifact).

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed (MR-011 … 017, BAI-004, BAI-005)
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-004-[date].md`, from `/qa-plan sprint`), including the MR-016 after-cast case
- [ ] All Logic/Integration stories have passing unit/integration tests
- [ ] Smoke check passed (`/smoke-check sprint`), including the content 002–005 load records and G7 by hand
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged: `/code-review` verdicts for MR-013, MR-016, MR-017 and BAI-004, recorded in each story's "Reviewed by"
- [ ] Each wave merged one lane at a time: [S] first, [C] last, full suite green after every merge
- [ ] `boot.gd` `_collect_validators()` touched by the orchestrator only
- [ ] Each story committed the moment its suite was green; restarts logged in `active.md`
- [ ] Owner hours stayed within 12 h, or the overrun is recorded in the retro

QA plan: run `/qa-plan sprint` before implementation begins.

> **Scope check:** If this sprint includes stories added beyond the original epic scope, run `/scope-check [epic]` to detect scope creep before implementation begins. (None are: every story is an existing Ready story; story 019 is listed as a later candidate only.)
