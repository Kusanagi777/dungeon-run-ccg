# Sprint 2 — 2026-11-04 to 2026-11-10

> **Type**: first sprint planned from measured velocity (gate `production/gate-checks/gate-pre-production-2026-11-03.md`, entry condition 4; retro `production/retrospectives/retro-sprint-1-2026-11-03.md`)
> **Stage**: Pre-Production · workflow standard · review lean · automation guided · story_granularity balanced (6–10 per sprint, scaled by velocity) · qa.level standard
> **PR-SPRINT**: skipped — Lean mode
> **QA Plan**: none yet for sprint 2. Run `/qa-plan sprint` before implementation begins (Phase 5 choice [A], recorded under the owner's standing approval)
> **Milestone file**: none in `production/milestones/`; planning against the story backlog. The First Playable milestone is recorded in sprint plans only (see below)
> **Risk register**: none in `production/risk-register/`; risks assessed from the sprint contents only
> **Dates**: sprint 1 ran on 2026-11-03, before its planned window. Sprint 2 takes the same 2026-11-04 → 2026-11-10 window
> **Generated**: 2026-11-03 by `/sprint-plan new` (subagent run under the owner's standing approval, no AskUserQuestion)

## Milestone: First Playable — re-dated

Gate entry condition 5: a **Windows export** of **one War match vs one band-1 boss** (`boss_torchbearer`, content story 001), **mouse-played**. The owner plays it, and that is playtest #1. The original target was the end of sprint 2. **Sprint 2 cannot reach it.**

**What the dependency graph says.** This was computed from every story's `## Dependencies` line, plus the cross-epic needs that the story text names without a path:
- CE-002 needs MR-003 `start`, MR-008 `end_match`, MR-017 `clone` (AC-1) and CDB-006 `config()`.
- BAI-004 needs MR-004 `submit` and MR-017 `clone`.
- BAI-013 needs MR-010 and CE-002.
- BAI-018 needs MUI-004.

Under the brief's rule (a story enters a wave only when its dependencies are done or in an earlier wave):
- **60 stories** (≈ 82 story-days) remain between today and `match-ui/story-012` (first playable).
- The **critical path is 22 waves long**: MR-003 → … → MR-010 → MR-012 → MR-013 → MR-014 → MR-017 → BAI-004 → BAI-005 → BAI-007 → BAI-008 → BAI-013 → BAI-015 → BAI-016 → BAI-017 → BAI-018 → MUI-012.
- Sprint 2 covers waves 1–3.

**Re-dated target: sprint 9 (2026-12-23 → 2026-12-29)**, assuming 3 waves per sprint on weekly sprints. The limit is the critical path, not capacity. 60 stories over 8 sprints is about 7.5 per sprint, well under the 15–18 the retro measured.

The owner can pull the date in. None of these is applied in this plan:
1. **Allow serial links inside one wave or session.** Sprint 1 chained BOOT-001 → 004 in one session. At 2–3 links per session, the capacity bound (≈ 60 stories at 15–18 per sprint) gives about **sprint 5 (2026-11-25 → 12-01)**.
2. **Split CE-002 AC-1's `clone()` half into MR-017's scope** (`/quick-design`). Then CE-002, and content 001 behind it, wait only on MR-008 and CDB-006, about wave 7 instead of 14. This does not shorten the MR → BAI critical path.
3. **Rescope the playable.** Example: a scripted or greedy boss for playtest #1, with the full planner (BAI-004 … 018) after it. This is a design change (`/quick-design` + story edits), and gate condition 5 then changes wording.

Gate entry condition 5 ("within sprints 1–2") **will not be met as written**. Its owners (producer / Jacob) need to accept the re-date or pick one of the options above.

**Still missing for the milestone at sprint-2 end:**
- **Loader**: CDB-006 (freeze and queries).
- **Rules**: MR-006 … MR-018.
- **Effects**: CE-002 and CE-004 … CE-011.
- **Content**: content 001 (Torchbearer, War starter).
- **Boss AI**: BAI-004 … BAI-018 (BAI-018 also needs a Windows machine).
- **Match UI**: every story. MUI-001 is wave 5 at the earliest, because it needs CDB-006, MR-004 and RNG-006.
- **Windows export in CI**: the task below, which still needs its story.
- **UX specs** for hand, targeting, mulligan and match-end (gate condition 11). They are not authored, and MUI-006/008/009/011 need them before `/story-readiness`.
- **Heroes epic stories**: none exist. BAI-016's real-data runs and CE-011 name it.

## Sprint Goal

Advance the first-playable chain by three dependency waves:
- **Rules**: match setup → command channel/mulligan → turns and mana (match-rules 003–005).
- **Event log**: core, serialisation and config knobs (rng-event-log 005–007, plus `RngService` 002).
- **Loader**: stages 4–8 (card-database 002–005).
- **Boss AI and effects**: AI profiles with the Torchbearer override (boss-ai 002–003) and the effect validator (card-effects 003).
- **CI**: the G1–G6 lint gates (boot 005), and the Windows-export CI job once its story exists.

Sprint 2 makes nothing new playable.

## Goal Prerequisites

| Needed to show the goal | Status |
|-------------------------|--------|
| Stories are Logic / Integration / Config-Data, proven headless by `commands.test` and the smoke check; nothing new to run or show | — (main scene `res://src/scenes/boot.tscn` exists) |
| `tests.yml` CI workflow (BOOT-005 adds a blocking gate step) | exists (`.github/workflows/tests.yml`) |
| `Windows Desktop` export preset + 4.7.2 export templates (Windows-export task) | exists (`export_presets.cfg`; templates via `EXPORT_TEMPLATES=1 bash tools/setup.sh`) |
| **A story for the Windows-export CI job** (gate condition 8) | **missing**: no story in any epic |
| Story amendment for G3 exclusions in BOOT-005 (see Readiness notes) | **missing**: BOOT-005's AC transcribes ADR-0001's G3 pattern, which fails on today's tree |

There are three ways to fix the missing rows. All three are open to the owner, and this plan does none of them:
- **(a)** Write the Windows-export story with `/create-stories` (it is not part of any epic, so `/quick-design` producing an embedded spec is the lighter path). Then run the task in W1 as planned. No Ready story builds it, so nothing can be pulled in.
- **(b)** Amend BOOT-005 through `/quick-design`, or an ADR-0001 erratum, so that G3 excludes `##` doc-comment lines and the `class_name Services` declaration.
- **(c)** Reword the goal to drop the Windows-export job and promise only the stories.

## Capacity

- **Calendar**: Wed 2026-11-04 – Tue 2026-11-10 (5 working days).
- **Owner hours**: still not given (gate condition 3, an accepted risk). Capacity is planned in **sessions and waves**, not hours. Owner review time is the binding constraint (retro).
- **Measured velocity** (sprint 1): 10 stories (11 story-days: 2 S, 7 M, 1 L) in one session, from one wide parallel wave.
- **Sizing**: retro recommendation, **3 waves of ≤ 6 parallel stories**, about one session per wave.
  - **Commitment**: 15 stories = 11 Must Have + 4 Should Have, ≈ 14 story-days (S 0.5 / M 1 / L 3).
  - **Stretch**: 2 Nice to Have, +1 story-day. With stretch, 17 stories.
  - This is above balanced's nominal 6–10 range, which scales by velocity.
- **Buffer (≈ 20%)**: one **fix buffer of ≈ 1 story-day per wave**, for blocking review findings (3 total). Plus one **review lane per wave** (below). A review lane is not a story.
- **Merge protocol** (unchanged from sprint 1, now required):
  - Merge one story at a time.
  - Run the full suite (`commands.test`) after each merge.
  - In each wave, merge the **serialised** stories first, one at a time, in the order listed. Every other branch in that wave rebases onto them before it merges.
- **Cut order if a wave runs short** (unfinished stories carry to sprint 3, with no mid-sprint re-scope): Nice to Have (RNG-004, BOOT-006) → RNG-002 → CE-003 → BAI-003 → BAI-002. Must Have stories are not cut. A late MR link shifts the whole critical path one wave.
- **Per-story timing**: `/dev-story` should log a start and end time per story (retro action 5), so sprint 3 gets per-story effort.
- **Execution rule — lanes (orchestrator, 2026-11-03).** Waves are the merge cadence, not a ban on dependent work: a **lane** is one agent that implements a dependency chain back to back in one worktree (as sprint 1 did for boot 001–003 and match-rules 001–002), committing one story at a time with the full suite green after each. A wave runs up to 6 lanes; a lane may carry its chain past the wave boundary when every story in it passes. Serialised stories (shared test helpers) still merge first. This is the plan's option 1 for pulling First Playable in (≈ sprint 5 instead of 9); the milestone is re-dated from sprint 2's measured lane throughput at sprint close rather than now.

## Waves

**[S] = serialised**: the story touches shared test helpers (`tests/helpers/**`, `TestConstants`, `MatchFactory`) or `MatchState`. It runs and merges alone, before the wave's other stories merge.

### Wave 1: ≈ 6 story-days, 6 stories
| Lane | Story | Est. | Note |
|---|---|---|---|
| 1 | MR-003 Match setup **[S]** | M (1) | new `tests/helpers/test_effect_resolver.gd`, edits `match_factory.gd` and `match_state.gd`. **Merges first** |
| 2 | RNG-005 EventLog core **[S]** | M (1) | edits `tests/helpers/test_event_log.gd`. Merges second |
| 3 | CDB-002 Record schema validation | M (1) | |
| 4 | BOOT-005 Grep gates G1–G6 + parse check in CI | M (1) | readiness note: G3 exclusions, G6 pattern |
| 5 | BAI-002 ProfileResolver + ai_profiles validator | M (1) | |
| 6 | CE-003 EffectValidator schema/trigger/selector/op/ref | M (1) | `CardFactory` fixture db double allowed |
| review | `/code-review` on sprint-1 stories still under review (MR-001, CDB-001) | — | BOOT-004 and RNG-001 are already reviewed: NOT ASSESSED, **no blocking defect**. MR-001's verdict lands before MR-003 merges, CDB-001's before CDB-002 merges |
| task | TASK-WINEXP Windows export in CI | — | starts only once its story exists (see below) |

### Wave 2: ≈ 5.5 story-days, 6 stories
| Lane | Story | Est. | Note |
|---|---|---|---|
| 1 | RNG-002 RngService seed derivation + streams **[S]** | M (1) | swaps `tests/helpers/test_rng_service.gd` and `test_rng_stream.gd`, edits `tests/unit/framework/test_helpers_test.gd`. **Merges first** |
| 2 | RNG-007 Overflow fault + `rng_event_log.json` **[S]** | M (1) | edits `tests/helpers/test_event_log.gd`. Merges second. Same source file as RNG-006: rebase onto it |
| 3 | MR-004 Command channel, rejection codes, mulligan | M (1) | reads `MatchFactory.REJECTION_CODES` (no helper edit planned; mark [S] at `/dev-story` if it adds to the factory) |
| 4 | RNG-006 EventLog serialisation + diagnostics | M (1) | merges before RNG-007 (shared `event_log.gd`) |
| 5 | CDB-003 Id uniqueness + cross-references | M (1) | reads `TestConstants` only |
| 6 | BAI-003 `ai_profiles.json` MVP data (Torchbearer override) | S (0.5) | Config/Data: smoke-check evidence |
| review | `/code-review` of W1's riskiest: **MR-003** (resolver double, `MatchFactory`, `MatchState`, ADR-0007 bind). Queue BOOT-005 (CI gate) if time allows | — | retro floor: shared helper / state type |

### Wave 3: ≈ 2.5 story-days committed + 1 stretch, 3 + 2 stories
| Lane | Story | Est. | Note |
|---|---|---|---|
| 1 | CDB-004 Delegated validators, stage 7 **[S]** | M (1) | new `tests/helpers/validator_stubs.gd`. **Merges first**. CDB-005 rebases onto it (shared `data_loader.gd`) |
| 2 | MR-005 Turn structure, mana, turn cap **[S]** | M (1) | edits `tests/helpers/test_effect_resolver.gd`. Merges second |
| 3 | CDB-005 Budget warnings + pool thresholds | S (0.5) | |
| 4 | *stretch* RNG-004 No-global-RNG lint in CI | S (0.5) | edits `tests.yml` after BOOT-005. Fold in the RNG-001 review's G6 note: bare `randi_range(` / `randf_range(` / `seed(` |
| 5 | *stretch* BOOT-006 `main.tscn` composition entry + RunShell stub | S (0.5) | UI: retained screenshot in `production/qa/evidence/` |
| review | `/code-review` of W2's riskiest: **RNG-002** (helper swap, determinism root). Queue MR-004 (the `submit` contract every consumer builds on). W3's own reviews fall to sprint 3 W1 | — | |

W3 is light by construction. CDB-006, MR-006, RNG-003, RNG-008 and BOOT-007 become wave-eligible only after W3 or after the stretch stories, so W3 cannot hold more preferred chain stories. The spare capacity goes to the fix buffer and the review backlog.

## Tasks

### Must Have (Critical Path)
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| MR-003 | [Match setup: bind, heroes, shuffle, starting hands](../epics/match-rules/story-003-match-setup.md) (Logic, M), W1 **[S]** | gameplay-programmer | 1 | MR-001, MR-002 (done) | AC-01 same seed → identical setup logs; AC-02 3/4 hands, mana 0/0, `mulligan_offered`; AC-43 boss health from config; `resolver.bind` before `on_match_start`; adds `TestEffectResolver` |
| RNG-005 | [EventLog core: append, subscribe, events_since, turn, sealing](../epics/rng-event-log/story-005-event-log-core-append-subscribe-seal.md) (Logic, M), W1 **[S]** | gameplay-programmer | 1 | None | seq 1..n, `events_since`, `cause_seq`, turn stamp, seal on `match_ended`, re-entrancy rule; full ACs in story |
| CDB-002 | [Record schema validation (CR-3, stage 4)](../epics/card-database/story-002-record-schema-validation.md) (Logic, M), W1 | gameplay-programmer | 1 | CDB-001 (done) | `E_UNKNOWN_FIELD` / `E_SCHEMA` / unlock shapes / tags+passive accepted; no fail-fast |
| BOOT-005 | [Grep gates G1–G6 and per-file parse check in CI](../epics/boot-composition-root/story-005-lint-gates-ci.md) (Integration, M), W1 | devops-engineer (engine-programmer pairs) | 1 | BOOT-004 (done) | `tools/lint/gates.sh` + `parse-check.sh`; each gate watched failing on a fixture; one blocking step in `tests.yml`; real tree exits 0 (**needs the G3 amendment, see Readiness notes**) |
| MR-004 | [Command channel, rejection codes and mulligan](../epics/match-rules/story-004-command-channel-and-mulligan.md) (Logic, M), W2 | gameplay-programmer | 1 | MR-003 (W1) | AC-03/04 mulligan + `INVALID_MASK`; AC-37 `ENGINE_BUSY`; phase/issuer guard; closed 21-code set = `MatchFactory.REJECTION_CODES` |
| RNG-006 | [EventLog serialisation and diagnostics](../epics/rng-event-log/story-006-event-log-serialization-and-diagnostics.md) (Logic, M), W2 | gameplay-programmer | 1 | RNG-005 (W1) | `to_json`/`from_json` `replay_equal`; unserialisable payload coercion; diagnostic events; canonical byte-equality (F6) |
| RNG-007 | [Overflow fault and `rng_event_log` config knobs](../epics/rng-event-log/story-007-overflow-fault-and-config-knobs.md) (Logic, M), W2 **[S]** | gameplay-programmer | 1 | RNG-005 (W1) | `log_overflow` → Faulted → Sealed; `assets/data/rng_event_log.json`; `EventLog.validate_config` (stage 7a) |
| CDB-003 | [Id uniqueness and cross-references (stages 5–6)](../epics/card-database/story-003-uniqueness-and-cross-references.md) (Logic, M), W2 | gameplay-programmer | 1 | CDB-001 (done), CDB-002 (W1) | `E_DUP_ID`, `E_COUNT`, `E_TAG_MISMATCH`, `E_TOKEN_IN_LIST`, missing-file checks |
| MR-005 | [Turn structure, mana curve and turn cap](../epics/match-rules/story-005-turn-structure-and-mana.md) (Logic, M), W3 **[S]** | gameplay-programmer | 1 | MR-004 (W2) | AC-05 first Start step; AC-06 mana curve to 10; AC-09 `NOT_YOUR_TURN`/`WRONG_PHASE`; AC-10 `TURN_CAP` → boss win |
| CDB-004 | [Delegated validators and the stage-7 lookup exception](../epics/card-database/story-004-delegated-validators.md) (Logic, M), W3 **[S]** | gameplay-programmer | 1 | CDB-003 (W2) | `E_DELEGATED` for rejecting / missing validators; stage-7 lookups open; adds `ValidatorStubs` |
| CDB-005 | [Budget warnings and pool thresholds (stage 8)](../epics/card-database/story-005-budget-warnings-and-pool-thresholds.md) (Logic, S), W3 | gameplay-programmer | 0.5 | CDB-002 (W1), CDB-003 (W2) | `W_POOL_SIZE`, bundle-pool `E_COUNT`, `W_EMPTY_SET`; knobs read from `card_database.json` |

Must Have: 11 stories, 10.5 story-days.

### Should Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| BAI-002 | [ProfileResolver and the ai_profiles validator](../epics/boss-ai-match-driver/story-002-profile-resolver-and-validator.md) (Logic, M), W1 | ai-programmer | 1 | None in epic (stub config) | resolve chain default → archetype → band → override; A25 `E_AI_PROFILE_UNKNOWN`; A26 weight clamp; unknown-field / op_values checks |
| CE-003 | [EffectValidator: schema, trigger, selector, op and reference checks](../epics/card-effects/story-003-validator-schema-codes.md) (Logic, M), W1 | gameplay-programmer | 1 | Cross-epic `CardDatabase.has/card` (fixture double allowed) | AC-02 `E_FX_CHOSEN`; AC-03 `E_FX_TRIGGER`; AC-04 `E_FX_REF`; AC-06 v2-op rejection |
| RNG-002 | [RngService: seed derivation and memoised streams](../epics/rng-event-log/story-002-rng-service-seed-derivation-and-streams.md) (Logic, M), W2 **[S]** | gameplay-programmer | 1 | RNG-001 (done) | same-seed sequences; F2 stream seeds exact; F1 seed parsing; memoisation + name check; swaps the test doubles |
| BAI-003 | [ai_profiles.json: archetypes, bands, runtime block, five MVP overrides](../epics/boss-ai-match-driver/story-003-ai-profiles-mvp-data.md) (Config/Data, S), W2 | ai-programmer | 0.5 | BAI-002 (W1) | F9 tables; band overlays; `boss_torchbearer` override; zero `E_AI_*`; smoke check passes |

Should Have: 4 stories, 3.5 story-days. **Committed total: 15 stories, ≈ 14 story-days.**

### Nice to Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| RNG-004 | [No-global-RNG lint in CI](../epics/rng-event-log/story-004-no-global-rng-lint.md) (Logic, S), W3 | devops-engineer | 0.5 | RNG-001 (done); after BOOT-005 merges (`tests.yml`) | lint script greps rules tree; watched failing on a fixture; blocking CI step |
| BOOT-006 | [main.tscn composition entry and the RunShell stub](../epics/boot-composition-root/story-006-main-scene-composition-entry.md) (UI, S), W3 | godot-specialist | 0.5 | BOOT-004 (done) | `main.tscn` is main scene, `Boot.boot()` once; stub `main_menu`; scene test updated; retained screenshot + Windows row |

### Non-story task: Windows export in CI (gate entry condition 8)
| ID | Task | Agent/Owner | Est. | Dependencies | Acceptance Criteria |
|----|------|-------------|------|-------------|-------------------|
| TASK-WINEXP | Windows export job in CI | devops-engineer (Jacob for the first-light launch) | ≈ S–M (unsized: no story) | `export_presets.cfg` `Windows Desktop` (exists), `tools/setup.sh` with `EXPORT_TEMPLATES=1` (exists), `commands.build` | A CI job installs the Godot 4.7.2 export templates, builds the `Windows Desktop` preset (`commands.build`, `build/windows/deckdelve.exe`) and uploads the `.exe` as a workflow artifact. Gate condition 8 then needs the owner to launch it once and retain `production/qa/evidence/windows-first-light-<date>/` |

> ⚠️ **TASK-WINEXP has no story.** Write one before it starts, with `/create-stories` or `/quick-design`. The epics index puts it outside every epic (E10 Polish & release prep). Until that story exists the task is planned, not startable. It is not counted in the 15 stories. It is scheduled in W1 so it can land before BOOT-005 and RNG-004 also edit `tests.yml`. If it starts later, rebase onto them.

## Readiness notes (from the inputs; run `/story-readiness` on each before `/dev-story`)

- **BOOT-005, G3.** AC-1 transcribes ADR-0001's G3 pattern `\bBoot\b|\bServices\b` over `src/core/**` minus `boot.gd`. On today's tree that gives 7 hits: 6 `##` doc comments in `services.gd`, `card_database.gd` and `boot_result.gd`, plus the `class_name Services` declaration (smoke report item 6; BOOT-004 review). The gate would fail on day one. The story must first exclude comment lines and the `services.gd` declaration, either through `/quick-design` or an ADR-0001 erratum. This plan does not edit the story.
- **BOOT-005, G6.** The RNG-001 review found that G6 flags `stream.randf()` (a legitimate stream call) and misses bare `randi_range(` / `randf_range(` / `seed(`. Settle the pattern with RNG-004's, so the two scripts agree.
- **G7 field-list gap (DSL spike finding 9, ADR-0007 erratum).** G7 does not see subscript writes, and its field list misses `pending_destroy` and whole-array reassignments. **G7 is not in BOOT-005's scope** (G1–G6 only; ADR-0001 states no G7 pattern). It needs an owner: either a BOOT-005 amendment, card-effects 016, or a separate gate story. `src/gameplay/effects/` stays empty until CE-003 lands in W1, and CE-003 creates `effect_validator.gd` / `effect_schema.gd` there. G7 then has real files to scan, with no CI gate yet. Raised for technical-director; no story is changed here.
- **MR-004.** If it adds to `MatchFactory` (the story only reads `REJECTION_CODES` / `make_command_result`), it becomes [S] in W2 and merges after RNG-002.
- **Sprint-1 code-review follow-ups** (retro action 1):
  - BOOT-004 and RNG-001 have been reviewed: NOT ASSESSED (no engine specialist), no blocking defect, should-fix items logged in `active.md`.
  - MR-001 and CDB-001 are still under review. W1's review lane takes them, and W1's fix buffer absorbs any blocking finding before MR-003 / CDB-002 merge.

## Carryover from Previous Sprint
| Task | Reason | New Estimate |
|------|--------|-------------|
| — | None: sprint 1 closed 10/10 `done` (`production/sprint-status.yaml`) | — |

Sprint-1 DoD items still open: QA sign-off (`/team-qa sprint` for sprint 1) and code review (above). Neither is a story, and both are tracked here.

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| **First Playable misses gate condition 5's "sprints 1–2"**: the strict critical path is 22 waves | Certain | High | Re-dated to sprint 9 above. Owner picks: accept, serial-in-wave chaining (≈ sprint 5), CE-002 split, or rescope |
| **Goal prerequisite missing:** no story for the Windows-export CI job (gate condition 8) | Certain | High | Write it via `/create-stories` / `/quick-design` before W1, or reword the goal. Fallback for playtest #1: owner exports by hand with `commands.build` |
| **Goal prerequisite missing:** BOOT-005's G3 pattern fails on the current tree | Certain | Medium | Amend the story / ADR-0001 erratum before BOOT-005 starts; otherwise BOOT-005 moves to W2 |
| Merge breaks on shared helpers (sprint 1's `0448510`) | Medium | Medium | [S] marking; serialised stories merge first in listed order; full suite after every merge |
| Same-file collisions not covered by the helper rule: RNG-006/007 (`event_log.gd`), CDB-004/005 (`data_loader.gd`), BOOT-005 / RNG-004 / TASK-WINEXP (`tests.yml`), the MR chain (`rules_engine.gd`) | High | Low | Merge order fixed per wave above; MR stories are one per wave by dependency |
| A blocking finding in the MR-001 / CDB-001 review lands after dependents start | Medium | Medium | Dependents do not merge before the verdict; 1 story-day fix buffer per wave |
| Late MR link slips the entire critical path | Medium | High | MR stories are Must Have and never cut; each MR merges first or second in its wave |
| CE-002 AC-1 needs `clone()` (MR-017): CE-002 and content 001 sit at waves 13–14 | Certain | High | Option 2 above (`/quick-design` split), owner decision |
| Owner review time and weekly hours unknown (gate condition 3) | High | Medium | Plan in sessions; one review lane per wave; cut order fixed |
| UX specs for hand / targeting / mulligan / match-end not authored (gate condition 11) | Certain | Medium (not this sprint) | `/ux-design` them before MUI-006/008/009/011 reach `/story-readiness` (sprint 3+) |
| Heroes epic has no stories; BAI-016 and CE-011 name it | High | Medium | `/create-stories heroes` before sprint 4 |
| Cross-epic doubles diverge from real classes once RNG-002 / RNG-005 land (`TestRngService`, `TestEventLog`) | Medium | Medium | RNG-002 and RNG-005 swap the doubles and are [S]; re-run MR suites after each |

## Dependencies on External Factors
- **Owner (Jacob)** decides three things:
  - First Playable re-date or rescope (gate condition 5).
  - Who writes the TASK-WINEXP story.
  - The BOOT-005 G3 amendment.
- **Owner (Jacob)**: weekly hours (gate condition 3), and the first-light launch of the Windows `.exe` (gate condition 8).
- **lead-programmer**: MR-001 / CDB-001 `/code-review` verdicts.
- **GitHub Actions runner**: Windows export templates download in CI (TASK-WINEXP); ripgrep ≥ 14 on `ubuntu-latest` (BOOT-005).
- Godot 4.7.2 headless + gdUnit4 in the container (`commands.test`).

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-002-[date].md`, from `/qa-plan sprint`)
- [ ] All Logic/Integration stories have passing unit/integration tests
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged: one `/code-review` per wave as above, recorded in each story's Completion Notes "Reviewed by"
- [ ] Each wave merged one story at a time, serialised stories first, full suite green after every merge
- [ ] TASK-WINEXP either has a story and a green CI artifact, or is recorded as carried with its story written
- [ ] Owner decision on the First Playable re-date recorded here
- [ ] Per-story start/end time logged by `/dev-story` (velocity for sprint 3)

QA plan: run `/qa-plan sprint` before implementation begins.
