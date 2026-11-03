# Sprint 3 — 2026-11-11 to 2026-11-17

> **Type**: first sprint sized by lanes and links (retro `production/retrospectives/retro-sprint-2-2026-11-03.md`, Process Improvements)
> **Stage**: Pre-Production · workflow standard (match-rules and card-effects at `full` via `workflow_overrides`) · review lean · automation guided · story_granularity balanced (6–10 per sprint, scaled by velocity) · qa.level standard
> **PR-SPRINT**: skipped — Lean mode
> **QA Plan**: none yet for sprint 3. Run `/qa-plan sprint` before implementation begins (Phase 5 choice [A], recorded under the owner's standing approval)
> **Milestone file**: none in `production/milestones/`; planning against the story backlog. First Playable is recorded in sprint plans and retros only
> **Risk register**: none in `production/risk-register/`; risks assessed from the sprint contents only
> **Generated**: 2026-11-03 by `/sprint-plan new` (subagent run under the owner's standing approval, no AskUserQuestion)

## Sprint Goal

Carry the match-rules critical lane through primitives, damage, win/loss and the resolution loop (MR-006 → MR-009). In parallel: freeze the card database and its queries (CDB-006 → 008); bind the effect runtime and the validator's step-bound and fixture checks (CE-002 → 005); finish RNG snapshot/restore, match summary and the determinism self-test (RNG-003, 008, 010); start the match view's state projection and animation queue (MUI-001, 002); and ship the batch-0 first-playable data set with its validate command (content 001, 007). Sprint 3 makes nothing new playable. First Playable stays at **sprint 7** (owner acceptance pending).

## First Playable outlook

- **The retro's count.** The remaining critical path was 19 links: MR-006 … 010, MR-012/013/014/017, BAI-004/005/007/008/013/015/016/017/018, then MUI-012.
- **Re-derived from the story files, the path is one link longer.** MUI-004 needs BAI-015. Once BAI-015 is done, the match-ui branch has 5 links left (MUI-004 → 005 → 008 → 011 → 012). The boss-ai branch has only 4 (BAI-016 → 017 → 018 → MUI-012). So the path from today is about **20 links**.
- **After this sprint.**
  - If MR-006 … 009 land, about 16 links remain. If the MR-010 stretch also lands, 15 remain.
  - At 4 critical links per sprint, that is 4 more sprints: **sprint 7 holds, with no slack**.
  - **Sprint 6** needs MR-010 this sprint and 5 links per sprint from sprint 4 on.
- **The boss-ai lane cannot open before sprint 5.** BAI-004 scores a `RulesEngine.clone()` sandbox (MR-017). MR-017 needs MR-011, MR-014, MR-015 and MR-016. Sprint 4 therefore needs **two match-rules lanes**: MR-012 → 013 → 014 on one, and MR-011 / MR-016 / MR-015 on the other. Otherwise MR-017 slips a sprint, and the date slips with it.
- **Conditions on the date** (unchanged from the retro):
  - UX specs for hand, targeting, mulligan and match-end (gate condition 11), before MUI-005/006/008/009/011 reach readiness.
  - `/create-stories heroes`, before BAI-016 and CE-011.
  - The owner's acceptance of the re-date.

## Goal Prerequisites

| Needed to show the goal | Status |
|-------------------------|--------|
| Main scene for `commands.smoke` (`run/main_scene`) | exists (`res://src/scenes/boot.tscn`); BOOT-006 (stretch) moves it to `main.tscn` |
| `RulesEngine.end_match()` (CE-002 AC-2 teardown) | built by MR-008 (W1) |
| `CardDatabase.config()` frozen (CE-002, MUI-001, content 001) | built by CDB-006 (W1). An unfrozen `config()` already exists on trunk (added by CDB-004, `108abcd`) |
| **`RulesEngine.clone()`** (CE-002 AC-1, second clause) | **missing**: MR-017, not in this sprint. See "CE-002 split" below |
| `assets/data/card_effects.json` (content 001 AC-1) | built by CE-002 (W2) |
| `match_rules.json`, `ai_profiles.json`, `rng_event_log.json` | exist |
| Nine seeded configs + definition files (`run_structure` … `content_budgets`, `cards_*`, `heroes`, `bosses`, `bundles`, `treasures`) | built by content 001 (W3) |
| `play_card` in `legal_commands()` (CE-004 AC-07's last clause; CE-006) | built by MR-010, **stretch only** (W2). See Risks |
| `match_ui.json` body (MUI-001 config read, MUI-002 L7 durations) | built by content 001, but in W3, after MUI-001 (W2). MUI-001/002 use a fixture body until it merges |
| `tools/capture.sh` `[-- <args>]` pass-through (BOOT-006 `data_error` capture) | built by BOOT-006 (stretch; its blocker note puts it in that story's scope) |
| Real-data `Boot.boot()` → `ok == true` (BOOT-006 AC-2 `main_menu` capture) | **missing, conditional**: needs content 001 (W3). If the code-review fix pass makes pending validators *fail*, it also needs owners for `run_structure`, `reward_draft`, `treasures_balance`, `heroes_balance`, `match_ui`, `run_ui` and `profile_defaults`, and no picked story builds those |
| `AtomicFileWriter` (RNG-009) / run-structure + reward-draft stories (RNG-011) | not needed: those stories are not picked (no story exists for either dependency) |

**Fixes for the missing rows.** They are open to the owner, and this plan applies none of them:
- **`clone()` for CE-002.**
  - (a) Apply the CE-002 split below with `/quick-design`: an edit to CE-002 AC-1 plus MR-017.
  - (b) Leave CE-002 as written. CE-002 and content 001 then carry to sprint 5 or later. Lane 3 has no eligible work, and lane 6 has only content 007, which cannot pass without content 001.
  - (c) Reword the goal to drop CE-002 and content 001.
- **Real-data `Boot.boot()` Ready for BOOT-006.**
  - (a) `/create-stories` for the seven config owners.
  - (b) A `/quick-design` decision that a seeded config with no owner is an explicit `W_` warning, not an error.
  - (c) Drop BOOT-006's `main_menu` capture from this sprint. BOOT-006 is stretch, so the goal does not depend on it.

## CE-002 split — recommendation: **split**

**Recommendation.** Move the second clause of CE-002 AC-1 into MR-017's acceptance criteria with `/quick-design`. That clause reads: "WHEN `engine.clone()` runs, THEN the clone's `state().effects` is equal by value and mutating a counter on the clone leaves the original unchanged."

**Why split:**
1. **It is MR-017's behaviour.** ADR-0007 D3 and the control manifest assign by-value copying of `EffectRuntime` to `clone()`. That is MR-017's code, so the test belongs where the code lives. CE-002 keeps the plain-data half of AC-1, which is what it owns.
2. **The wait is long.** `clone()` sits behind MR-010 → MR-011, MR-012 → 013 → 014/015, and MR-016 → MR-017. That is sprint 4 at the earliest, more likely sprint 5.
3. **Unsplit, CE-002 cannot close until then.** Everything behind it waits too: CE-004, CE-005, CE-006 …, content 001 (which needs `card_effects.json`), BOOT-006's `main_menu`, CDB-009/010, and MUI-004's data.
4. **Split, CE-002 needs only MR-008 and CDB-006.** Both land at merge point 1, so CE-002 runs in W2, content 001 in W3, and the effects chain starts this sprint.

**What it does not change.** It does not shorten the MR → BAI → MUI critical path. The gain is in the branches that join that path later, which would otherwise become the long pole in sprints 5–6.

**When.** Apply the split before CE-002's `/story-readiness`, which is the start of W2. This plan edits no story file. If the split has not been applied by W2, take path (b) above.

## Capacity

- **Calendar**: Wed 2026-11-11 – Tue 2026-11-17 (5 working days).
- **Owner hours**: still not given (gate condition 3, carried for the third sprint). Capacity is planned in **sessions, lanes and links**, not hours. The binding cost is merge-fix time and owner review time, not agent time.
- **Measured basis** (sprint 2):
  - 16 stories took 34 min of lane time over 6 lanes.
  - Lane openers took 11.6 min on average, and follow-on stories 5.8 min. Up to 4 chained links ran per lane-session.
  - Estimated size barely predicted duration. Position in the lane did.
- **Sizing**: 6 lanes × about 3 stories, plus one stretch per lane where one is eligible. **An opener counts as 2 links.**
  - **Committed**: 17 stories, about 23 link-equivalents. On the sprint-2 scale (S 0.5 / M 1 / L 3) that is about 25 story-days, kept only as a relative-size label.
  - **Stretch**: MR-010, CE-006, plus BOOT-006 (carryover). With stretch, 20 stories.
  - This is above balanced's nominal 6–10 range, scaled by the measured velocity.
- **Buffer (≈ 20%)**:
  - One **fix buffer per wave**, for blocking review findings and merge breaks.
  - One **review lane per wave** (below). A review lane is not a story.
  - Lanes 2 and 4 finish in W2. Their W3 slot is buffer.
- **Merge protocol** (sprint 2's, plus the retro's two new rules):
  1. Lanes merge one at a time, with the full suite (`commands.test`) after each. To diagnose a merge break, add `-c` so every failure shows at once. CI stays as is.
  2. **[S] = serialised**: the story edits shared test helpers (`tests/helpers/**`, `TestConstants`, `MatchFactory`, `CardFactory`) or `MatchState`. It merges **first** in its wave.
  3. **[C] = contract-tightening**: the story starts enforcing a shared contract. It merges **last** in its wave. Before its merge it runs the full suite against the other lanes' merged state, and it fixes every fixture it breaks.
  4. **`src/core/boot.gd` `_collect_validators()` has one owner: the orchestrator.** No lane edits it. A story that needs a validator registered names it in its Completion Notes. The orchestrator adds the line at merge, in one commit per lane.
     - CE-002 → `configs.card_effects = EffectValidator.validate_config`. This replaces its `PENDING_CONFIG_OWNERS` entry. Once it lands, the `effects` adapter's `bodies["card_effects"]` caps are real.
     - content 007 → `configs.content_budgets = ContentValidator.validate_config`.
     - No other picked story registers one.
  5. Lane scratch files are prefixed `<lane>-` or kept in a per-lane subdirectory (retro action 5).
  6. `/dev-story` logs the start and end time (UTC) for each story, as in sprint 2.
- **Cut order if a wave runs short** (unfinished stories carry to sprint 4; no mid-sprint re-scope):
  - Nice to Have first: BOOT-006, then CE-006, then MR-010.
  - Then content 007 → MUI-002 → RNG-010 → CDB-007.
  - Must Have stories are not cut. A late MR link shifts the whole critical path.

## Lanes

A **lane** is one agent implementing its dependency chain back to back in one worktree, one commit per story, with the full suite green after each. **Waves are merge points.** At the end of each wave, every lane merges what it has committed, in the order given. A story that depends on another lane's story starts only after that story has merged at an earlier merge point.

| Lane | W1 (→ merge point 1) | W2 (→ merge point 2) | W3 (→ merge point 3) | Stretch | Links (opener = 2) |
|---|---|---|---|---|---|
| **1 Critical — match-rules** | MR-006 **[S]** (L, opener) → MR-007 **[S]** (M) → MR-008 (M) | MR-009 **[S]** (L) | review fixes / fix buffer | **MR-010 [S]** (L), W2 after MR-009 | 5 (+1) |
| **2 card-database** | CDB-006 **[C]** (M, opener) | CDB-007 (S) → CDB-008 **[C]** (M) | buffer | none eligible: CDB-009 needs content 001's shipped data (W3, same merge point); CDB-010 needs CDB-009 and MVP-1 | 4 |
| **3 card-effects** | — (nothing in the epic is eligible before MR-008 + CDB-006 merge) | CE-002 **[C]** (M, opener; split applied) | CE-004 (S) → CE-005 (M) | **CE-006** (M), W3; needs MR-010 merged at M2 | 4 (+1) |
| **4 rng-event-log** | RNG-003 (M, opener) → RNG-008 (S) | RNG-010 (S) | buffer | none eligible: RNG-009 needs the meta-progression `AtomicFileWriter` story (no story exists); RNG-011 needs run-structure / reward-draft stories (none exist) | 4 |
| **5 match-ui** (the boss-ai slot; see below) | — (MUI-001 needs CDB-006) | MUI-001 (L, opener) | MUI-002 (L) | none eligible: MUI-003 needs BAI-013 | 3 |
| **6 content** | — (needs CDB-006 and CE-002) | — | content 001 **[C]** (L, opener) → content 007 (M) | **BOOT-006** (S, carryover), W3 after content 001 | 3 (+1) |
| review | `/code-review` MR-006, MR-007, MR-008 and **CDB-006**. Verdicts are recorded before M2 merges CE-002 / MUI-001 on top of them | `/code-review` MR-009 (+ MR-010). Verdicts are recorded before M3 merges CE-004 … 006 | W3's own reviews fall to sprint 4 W1 | — | — |

**Merge order at each point:**
- **M1**: L1 (MR, [S]) → L4 (RNG) → L2 (CDB-006, [C], last).
- **M2**: L1 (MR-009 / 010, [S]) → L4 → L5 → L3 (CE-002, [C]: the orchestrator adds the `card_effects` validator line) → L2 (CDB-008, [C], last).
- **M3**: L5 → L3 → L6.
  - content 001 is [C]: the shipped data set changes what `Boot.boot()` and `commands.smoke` load.
  - The orchestrator adds content 007's `content_budgets` line.
  - BOOT-006, if it is reached, merges after content 001 and last overall, because it changes `run/main_scene`.

**Why the boss-ai lane runs match-ui instead.** BAI-004's AC A11 scores trades and plays by one-ply simulation on a `RulesEngine.clone()` sandbox:
- `clone()` is MR-017, sprint 4–5.
- The trades need attack resolution, MR-012/013.
- The plays need `play_card`, MR-010.

BAI-005 and BAI-006 both depend on BAI-004. So no boss-ai story is eligible this sprint. MUI-001 → 002 is the eligible chain closest to First Playable: MUI-001 needs CDB-006, RNG-005/006 and MR-004, and the last two are done. Taking them now removes two L links from the match-ui branch, which is the longest branch (see the outlook).

**Late-start lanes.** Lanes 3, 5 and 6 cannot start in W1, because their first story needs CDB-006 and/or MR-008 merged. That is the dependency graph, not idle capacity: the slots exist because sprint 2's measured agent time is not the constraint. Do not start their stories early against unmerged branches.

## Tasks

Est. Days use the sprint-2 scale (S 0.5 / M 1 / L 3) as a relative-size label only. Plan by the Links column above.

### Must Have (Critical Path)
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| MR-006 | [Primitive API, draw, burn and fatigue](../epics/match-rules/story-006-primitives-draw-burn-fatigue.md) (Logic, L), L1 W1 **[S]** | gameplay-programmer | 3 | MR-005 (done) | AC-31 burn at hand 10; AC-32 fatigue 1-2-3-4; AC-33 draw-2 with one card; the 24 primitives emit their C15 events |
| MR-007 | [Damage, healing and armour pipeline](../epics/match-rules/story-007-damage-heal-armor.md) (Logic, M), L1 W1 **[S]** | gameplay-programmer | 1 | MR-006 (L1), MR-002 (done) | AC-23 armour + Lifesteal; AC-44 heal floored at 0; Divine Shield; Poisonous → `pending_destroy`. Edits `test_effect_resolver.gd` |
| MR-008 | [Win, loss, concede and MatchResult](../epics/match-rules/story-008-win-loss-concede-result.md) (Logic, M), L1 W1 | gameplay-programmer | 1 | MR-007 (L1) | AC-34 simultaneous lethal → boss wins; AC-35 concede in the boss's Main; AC-42 `MatchResult` shape; `end_match()` (CE-002 needs it) |
| MR-009 | [Resolution loop: death check, trigger queue, auras, step cap](../epics/match-rules/story-009-resolution-loop.md) (Logic, L), L1 W2 **[S]** | gameplay-programmer | 3 | MR-008 (M1) | AC-27 death order; AC-28 `on_damage` trigger order; AC-29 Deathrattle token at the dead minion's index; AC-30 heal ping-pong step cap. Edits `test_effect_resolver.gd` |
| CDB-006 | [Freeze and CR-6 queries (stage 9)](../epics/card-database/story-006-freeze-and-queries.md) (Logic, M), L2 W1 **[C]** | gameplay-programmer | 1 | CDB-004, CDB-005 (done) | id-ascending pools; `card()` O(1), same instance; all 13 `config(name)` non-null and frozen; nested writes refused. **[C]**: every test that mutates a returned record breaks, and this lane fixes them |
| CE-002 | [EffectRuntime, resolver binding lifecycle and `card_effects.json`](../epics/card-effects/story-002-runtime-binding-config.md) (Logic, M), L3 W2 **[C]** | gameplay-programmer | 1 | MR-003 (done), MR-008 (M1), CDB-006 (M1); **the split** (else MR-017) | AC-1 plain-data `EffectRuntime` (clone half → MR-017 if split); AC-2 `bind` before `on_match_start` + the weakref teardown after `end_match()`; AC-41 knobs from `card_effects.json`, `validate_config`. Validator line: `configs.card_effects` (orchestrator) |
| content-001 | [Batch-0 first-playable data set](../epics/content/story-001-batch-0-first-playable-data-set.md) (Config/Data, L), L6 W3 **[C]** | game-designer (data), gameplay-programmer pairs for the load run | 3 | CDB-001…006 (CDB-006 at M1), MR-001, CE-002 (M2), CE-003, BAI-003, RNG-007 (done) | AC-1 loads `Ready`: zero errors, only `W_POOL_SIZE`, ≤ 200 ms, stub validators named in the smoke record; AC-2 `hero_war`, Whetstone, 15-card starter; AC-3 `boss_torchbearer` + a 30-card deck; AC-4 zero `E_FX_*`, text ≤ 90 chars, 3 bundles. Smoke record in `production/qa/smoke-[date].md` |

Must Have: 7 stories, ≈ 13 story-days.

### Should Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| CDB-007 | [`data_version` fingerprint (CR-9)](../epics/card-database/story-007-data-version-fingerprint.md) (Logic, S), L2 W2 | gameplay-programmer | 0.5 | CDB-006 (L2) | order-, key- and whitespace-independent; known-answer fixture; `""` + one error when not `Ready` |
| CDB-008 | [State machine, visible failure and debug `reload()`](../epics/card-database/story-008-state-machine-and-debug-reload.md) (Logic, M), L2 W2 **[C]** | gameplay-programmer | 1 | CDB-006 (L2) | all errors in one report; `E_NOT_LOADED` for queries in `Unloaded`/`Failed`; reload keeps the old snapshot on error. **[C]**: queries before `Ready` start failing |
| CE-004 | [Validator step bound and targeting spec](../epics/card-effects/story-004-validator-step-bound-targeting.md) (Logic, S), L3 W3 | gameplay-programmer | 0.5 | CE-003 (done), CE-002 (L3); AC-07's last clause needs MR-010 merged at M2 | AC-05 `E_FX_BUDGET` 321 / 161; `step_bound` F6 values; AC-07 `targeting_spec` modes + `legal_targets`; AC-3 `E_FX_OP_TARGET` |
| CE-005 | [Fixture set and database injection](../epics/card-effects/story-005-fixture-set-database-injection.md) (Integration, M), L3 W3 | gameplay-programmer | 1 | CE-003 (done), CE-004 (L3), CDB `DataLoader` (done) | AC-01 C11 rows 1–46 fixture validates; AC-2 `E_DELEGATED` carrying `E_FX_REF`, five-argument adapter; AC-3 accept-all → `Ready`, `load({})` → `E_DELEGATED` |
| RNG-003 | [Snapshot, restore and the command guard](../epics/rng-event-log/story-003-snapshot-restore-and-command-guard.md) (Logic, M), L4 W1 | gameplay-programmer | 1 | RNG-002 (done; **plus the review fix pass**) | shuffle-restore-shuffle identical; draws 37 → next 20 match, forks restored under their full name; `data_version` mismatch → `ERR_INVALID_DATA`; mid-command `snapshot()` refused; hex round trip above 2^53 |
| RNG-008 | [`reduce_to_summary()` and `damage_by_card`](../epics/rng-event-log/story-008-match-summary-reduction.md) (Logic, S), L4 W1 | gameplay-programmer | 0.5 | RNG-005 (done) | `damage_by_card` sums `dealt`, boss sources excluded; attribution map; summary shape; unsealed log → `{}` + error |
| RNG-010 | [Determinism contract (F6) and performance budgets](../epics/rng-event-log/story-010-determinism-contract-and-performance-budgets.md) (Logic, S), L4 W2 | gameplay-programmer | 0.5 | RNG-003 (L4), RNG-006 (done) | F6 self-test `replay_equal` + byte-identical JSON; 10k appends < 50 ms; 10k-draw restore < 5 ms (perf asserts go to the non-blocking CI job, per the sprint-2 QA plan) |
| MUI-001 | [MatchViewState: pure projection and the hidden-info / unknown / diagnostic filters](../epics/match-ui/story-001-match-view-state-projection.md) (Logic, L), L5 W2 | ui-programmer (godot-specialist) | 3 | RNG-005, RNG-006, MR-004 (done), CDB-006 (M1) | L1 replay-equal projection; L3 no boss `card_id` stored; L4 unknown types ignored; L9 rejection → `feed_lines` + one `reject_shake` |
| MUI-002 | [AnimStep and AnimationQueue](../epics/match-ui/story-002-animation-queue-core.md) (Logic, L), L5 W3 | ui-programmer (godot-specialist) | 3 | MUI-001 (L5), BOOT-001 (done) | L5 death-group coalescing; L6 `skip_all()` at every k; L7 F3 speed divisor over `match_ui.json` durations; L11 simultaneous pops |
| content-007 | [`validate.gd` command and the `content_budgets` validator](../epics/content/story-007-validate-command-and-budgets-config.md) (Logic, M), L6 W3 | tools-programmer | 1 | CDB-008 (M2), CDB-004 (done), content 001 (L6) | AC-1 exit 0 / 1 contract, no `Boot`; AC-2 `ContentValidator.validate_config`; AC-3 schemas match the CR-3 field lists. Validator line: `configs.content_budgets` (orchestrator) |

Should Have: 10 stories, ≈ 12 story-days. **Committed total: 17 stories, ≈ 25 story-days (≈ 23 link-equivalents).**

### Nice to Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| MR-010 | [Playing minions, spells, weapons and the hero power](../epics/match-rules/story-010-play-card-and-hero-power.md) (Logic, L), L1 W2 stretch **[S]** | gameplay-programmer | 3 | MR-009 (L1) | AC-11 `BOARD_FULL` + position clamp; AC-13 required-target spell absent from `legal_commands()`; AC-14 weapon replacement order; AC-15 hero power mana and `used_this_turn`. Edits `test_effect_resolver.gd` and `card_factory.gd` |
| CE-006 | [Play triggers, `chosen` targeting and the one-pass contract](../epics/card-effects/story-006-play-triggers-one-pass.md) (Logic, M), L3 W3 stretch | gameplay-programmer | 1 | CE-001 (PROCEED), CE-002, CE-004, CE-005 (L3); MR-006, MR-009, MR-010 (M1/M2) | AC-08 Battlecry with no target; AC-09 log order; AC-39 `effect_resolved` fields |

BOOT-006 is also a stretch item (L6 W3), but it is sprint-2 carryover and is listed only in the Carryover table.

## Readiness notes (from the inputs; run `/story-readiness` on each before `/dev-story`)

- **RNG-003 and the settled `stream()` rule.** The sprint-2 code review settled two rules:
  - `RngService.stream()` takes **root names only**.
  - A fork is keyed by **parent + label**.

  RNG-003's AC-2 wants a fork in `snapshot().streams` "under its full name" (`"<parent>/<label>"`). Keep that as the *snapshot key* only. `restore()` must rebuild a fork through the parent's fork path, `stream(parent).fork(label)` at the recorded position, and never through `stream("<parent>/<label>")`. The fix pass changes RNG-002's restore and fork code, so RNG-003 starts from the trunk after that merge.
- **CE-002.** Run `/story-readiness` only after the split decision (above). Without the split, AC-1 is unreachable this sprint.
- **CE-004 AC-07.** The last clause ("match-rules' `legal_commands()` still lists the minion") needs MR-010's `play_card` legal commands. If MR-010 does not merge at M2, CE-004 cannot close all its ACs. CE-005 and CE-006 behind it carry with it.
- **MUI-001 / MUI-002 and `match_ui.json`.** The body ships with content 001 (W3). MUI-001 (W2) and MUI-002 (W3, parallel to content 001) read a fixture body built from `match-ui.md` Tuning Knobs, through `CardFactory.make_config_file`. Rebase MUI-002 onto content 001 if it merges first. `/perf-profile` (gate condition 10) is MUI-004's, not MUI-001's.
- **content 001 and pending validators.** AC-1 allows an accepting stub where an owner's validator has not landed, as long as the smoke record names it. The code-review fix pass (CDB-004: "pending validators must not pass silently") changes what `Boot`'s own map does with the seven configs that still have no owner. Re-read `boot.gd` after that merge, before content 001 starts.
- **BOOT-006** (carryover).
  - Its blocker note names three gaps: CDB-006, a full shipped data set, and `capture.sh` `--`.
  - Two are closed by earlier slots this sprint: CDB-006 at M1 and content 001 in the same lane. The third, `capture.sh`, is in its own scope.
  - Part (2) of its blocker (`config()` missing) was already resolved on trunk by CDB-004.
  - The `main_menu` capture still needs real-data `Boot.boot()` → `ok == true`. See Goal Prerequisites.
  - Leave the yaml at `blocked` until content 001 merges.
- **content 007** reads `CardDatabase.to_text()` / `state()` from CDB-008, which merges at M2. It is in the same lane as content 001, after it.

## Carryover from Previous Sprint
| Task | Reason | New Estimate |
|------|--------|-------------|
| BOOT-006 [`main.tscn` composition entry and the RunShell stub](../epics/boot-composition-root/story-006-main-scene-composition-entry.md) (UI, nice-to-have) | Not started in sprint 2. Blocked on CDB-006 queries, a full shipped data set, and `tools/capture.sh` `--` pass-through. Sprint 3: L6 W3 stretch after content 001 (CDB-006 lands at M1, an earlier slot, per the brief's condition). `main_menu` also needs real-data `Boot.boot()` Ready | S (0.5), unchanged. Yaml `status: blocked` until content 001 merges (retro action 4) |

**Carryover in progress (not sprint-3 scope).** The code-review fix pass on sprint-2 stories is running now and merges before sprint 3 starts:
- **CDB-004 (blocking)**: pending validators must not pass silently. This is ADR-0002 D4 and the manifest rule.
- **MR-003**: `start()` passes `Array[HookInstaller]` to `resolver.bind`.
- **RNG-002**: restore and fork fixed, and `stream()` takes root names only.

Lane 4 (RNG-003) and lane 6 (content 001) start from the trunk after that merge.

**Owner items still open.** These are recorded here and do not block the sprint:
1. **Weekly hours** (gate condition 3, carried twice). Capacity stays in sessions.
2. **Windows first-light screenshot.** Launch the BOOT-008 artifact (run 41723632236). Evidence goes to `production/qa/evidence/windows-first-light-<date>/`.
3. **Acceptance of the First Playable re-date to sprint 7** (stretch sprint 6), or a rescope.
4. **The CE-002 split** (recommended above).

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| **Goal prerequisite missing: `clone()` for CE-002 AC-1.** Without the split, CE-002, content 001 and lane 3 stall | Certain unless split | High | Apply the split with `/quick-design` before W2. Otherwise take path (b): carry CE-002 and content 001, and reassign lanes 3 and 6 to buffer and review |
| **Goal prerequisite missing (conditional): real-data `Boot.boot()` Ready** for BOOT-006's `main_menu` | Medium | Low (stretch) | Decide pending-config policy after the fix pass merges; `/create-stories` for the seven config owners or a `/quick-design` warning rule |
| **MR-010 is stretch but CE-004 AC-07 / CE-005 / CE-006 need it** | Medium | Medium | Schedule MR-010 directly after MR-009 in W2; if it misses M2, CE-004/005 carry (CE-002 still lands) |
| Critical lane carries 3 links in W1 (MR-006 L + 007 + 008) so CE-002 can start in W2 | Medium | High | Sprint 2 measured 4 links per lane-session; if MR-008 misses M1, CE-002 → W3 and CE-004/005 → carry; MR stories are never cut |
| Contract-tightening merges break other lanes (sprint 2's CDB-004 pattern): CDB-006 freeze, CDB-008 `E_NOT_LOADED`, CE-002 real `card_effects` validator, content 001 real data set | High | Medium | [C] marking: merge last in wave, run the full suite against merged state first, own the fixture fixes; `-c` when diagnosing |
| `boot.gd` `_collect_validators()` conflicts (sprint 2's three-lane hand-merge) | Low (rule in place) | Medium | Single owner: the orchestrator adds CE-002's and content 007's lines at merge |
| The fix pass slips into sprint 3 | Low | Medium | RNG-003 and content 001 wait for it; lanes 1, 2 and 5 do not touch the files it changes |
| `MatchState` / `test_effect_resolver.gd` edits by every MR story collide with the CE lane's resolver work | Medium | Medium | MR lane merges first at every point ([S]); CE lane rebases onto it |
| Independent review skipped again (0/16 in sprint 2) | Medium | High | Review lane per wave, with named stories; dependents do not merge before the verdict (retro action 2) |
| 45 `ValidatorStubs.accept_all()` call sites hide a validator regression once CE-002 / content 007 make validators real | Medium | Medium | CE-002 and content 007 tests exercise the real validators, never `accept_all()` |
| Sprint 4 has one MR lane only, so MR-017 (and BAI-004) slips | Medium | High | Plan two MR lanes in sprint 4 (MR-012→014 / MR-011, MR-016, MR-015) |
| UX specs (gate condition 11) and heroes stories still missing | Certain | Medium (sprint 4+) | `/ux-design` hand, targeting, mulligan and match-end by sprint 4; `/create-stories heroes` before sprint 5 |
| G7 field-list gap still has no owning story; `src/gameplay/effects/` grows with CE-002/004/005 | Medium | Medium | G7 by hand in each smoke check (as in sprint 2) until a story or ADR-0001 erratum owns it |

## Dependencies on External Factors
- **Owner (Jacob)**:
  - The CE-002 split, before W2.
  - First Playable re-date acceptance.
  - Weekly hours.
  - Windows first-light launch.
  - The pending-config policy, only if BOOT-006 is reached.
- **lead-programmer**: `/code-review` verdicts in the review lanes (MR-006 … 010, CDB-006).
- **The code-review fix pass** merging before 2026-11-11.
- Godot 4.7.2 headless + gdUnit4 in the container (`commands.test`); GitHub Actions (`tests.yml`, Windows Export).

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-003-[date].md`, from `/qa-plan sprint`)
- [ ] All Logic/Integration stories have passing unit/integration tests
- [ ] Smoke check passed (`/smoke-check sprint`), including content 001's load record and G7 by hand
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations (incl. the CE-002 / MR-017 split if applied)
- [ ] Code reviewed and merged. The review lane per wave covers MR-006 … 009 (+ 010) and CDB-006, recorded in each story's Completion Notes under "Reviewed by"
- [ ] Each wave merged one lane at a time: [S] first, [C] last, full suite green after every merge
- [ ] `boot.gd` validator lines added by the orchestrator only, one commit per lane
- [ ] Per-story start/end time (UTC) logged by `/dev-story`
- [ ] Owner decisions recorded here: CE-002 split, First Playable re-date

QA plan: run `/qa-plan sprint` before implementation begins.

> **Scope check:** If this sprint includes stories added beyond the original epic scope, run `/scope-check [epic]` to detect scope creep before implementation begins. (None are: every story is an existing Ready story.)
