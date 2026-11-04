# Architecture Traceability Index
Last Updated: 2026-11-03
Engine: Godot 4.7.2 (GDScript; pinned 4.7 — `docs/engine-reference/godot/VERSION.md`)
Source run: `/architecture-review` full, workflow `standard` — `docs/architecture/architecture-review-2026-11-03b.md` (second run of the day; supersedes the index written by `architecture-review-2026-11-03.md`)

## Coverage Summary
- Total requirements: 71 (70 baseline rows + `TR-accessibility-requirements-001`; registry v3, no new IDs this run, three entries `revised` 2026-11-03 for GDD wording)
- Covered: 71 (100%) — every covering ADR is `Accepted`
- Partial: 0 (was 7 — closed by citation rows added to ADR-0002/0003/0005/0006/0007/0008 on 2026-11-03)
- Gaps: 0 (was 1 — `TR-accessibility-requirements-001` closed by the ADR-0004 decision addendum of 2026-11-03)

Status key: ✅ Covered by an Accepted ADR that cites the requirement in its `## GDD Requirements Addressed` table · ⚠️ Partial · ❌ Gap · 🟡 Covered by a `Proposed` ADR · ❓ Not assessed. No ADR is `Proposed` and none is unreadable, so there are no 🟡 or ❓ rows. Stories: none exist yet (`production/epics/` absent), so no Story / Test columns — `rtm` mode adds them once `/create-stories` has run.

## Full Matrix

| Requirement ID | GDD | System | Requirement (short) | ADR Coverage | Status |
|---|---|---|---|---|---|
| TR-card-database-001 | card-database.md | Card Database | Only JSON parser; two envelopes; `config(name)` | ADR-0002 | ✅ |
| TR-card-database-002 | card-database.md | Card Database | Nine-stage pipeline, injected validators; `Failed` has no menu | ADR-0002, ADR-0007, ADR-0011 | ✅ |
| TR-card-database-003 | card-database.md | Card Database | Pure id-ascending queries on a frozen snapshot | ADR-0002 | ✅ |
| TR-card-database-004 | card-database.md | Card Database | `data_version` SHA-256 fingerprint | ADR-0002 | ✅ |
| TR-card-database-005 | card-database.md | Card Database | Load ≤ 200 ms, snapshot ≤ 4 MB, synchronous | ADR-0002 | ✅ |
| TR-rng-event-log-001 | rng-event-log.md | RNG & Event Log | `RngService`, memoised named streams, `fork`, draw API | ADR-0003 | ✅ |
| TR-rng-event-log-002 | rng-event-log.md | RNG & Event Log | No global RNG under the rules tree | ADR-0003 | ✅ |
| TR-rng-event-log-003 | rng-event-log.md | RNG & Event Log | Replay equivalence; `snapshot()` (`run_seed_hex`) / `restore()` | ADR-0003, ADR-0006 | ✅ |
| TR-rng-event-log-004 | rng-event-log.md | RNG & Event Log | Append-only envelope, one event per mutation, sealing, subscribe | ADR-0003, ADR-0009 | ✅ |
| TR-rng-event-log-005 | rng-event-log.md | RNG & Event Log | Diagnostics on the same log | ADR-0003, ADR-0006, ADR-0009 | ✅ |
| TR-rng-event-log-006 | rng-event-log.md | RNG & Event Log | `max_match_events` budget; `user://logs/` archive | ADR-0003, ADR-0004 | ✅ |
| TR-match-rules-001 | match-rules.md | Match Rules | `RulesEngine` owns one plain-data `MatchState` | ADR-0001 | ✅ |
| TR-match-rules-002 | match-rules.md | Match Rules | `submit`/`legal_commands`; illegal moves are data; `ENGINE_BUSY` | ADR-0001, ADR-0006, ADR-0008 | ✅ |
| TR-match-rules-003 | match-rules.md | Match Rules | `clone()` deep copy incl. hooks, scratch log, `rng_match` | ADR-0005, ADR-0006 | ✅ |
| TR-match-rules-004 | match-rules.md | Match Rules | `MatchConfig` is the only input | ADR-0003, ADR-0008 (built at `begin_match`), ADR-0005 (`hook_installers`) | ✅ |
| TR-match-rules-005 | match-rules.md | Match Rules | Primitive API is the only mutator; one event each | ADR-0001, ADR-0007 | ✅ |
| TR-match-rules-006 | match-rules.md | Match Rules | 15 trigger points, 12 hook points, C10 loop | ADR-0005, ADR-0007 | ✅ |
| TR-match-rules-007 | match-rules.md | Match Rules | `MatchResult` shape; C15 event vocabulary | ADR-0003, ADR-0008 | ✅ |
| TR-match-rules-008 | match-rules.md | Match Rules | `submit()` ≤ 5 ms, `legal_commands()` ≤ 2 ms | ADR-0007 (engine side: one pass = one step, `step_bound` ≤ 250, `targeting_spec` memo — cited 2026-11-03), ADR-0009 (caller side) | ✅ |
| TR-card-effects-001 | card-effects.md | Card Effects | Effects are plain JSON; `targeting_spec` derived | ADR-0002, ADR-0007 | ✅ |
| TR-card-effects-002 | card-effects.md | Card Effects | Resolver over primitives; one pass = one step; bind at `start` | ADR-0007 | ✅ |
| TR-card-effects-003 | card-effects.md | Card Effects | One `ChoiceRequest` with continuation | ADR-0007 | ✅ |
| TR-card-effects-004 | card-effects.md | Card Effects | Hook-bound and observer effects | ADR-0005, ADR-0007 | ✅ |
| TR-card-effects-005 | card-effects.md | Card Effects | `validate_effects` injected at stage 7 | ADR-0002, ADR-0007 | ✅ |
| TR-card-effects-006 | card-effects.md | Card Effects | Static step bound 250; 8 ops | ADR-0007 | ✅ |
| TR-boss-ai-001 | boss-ai.md | Boss AI | Pure `RefCounted` planner over `legal_commands`/`clone` | ADR-0001, ADR-0003, ADR-0006 | ✅ |
| TR-boss-ai-002 | boss-ai.md | Boss AI | `forecast`/`play_turn`/`choose` synchronous | ADR-0006, ADR-0008 | ✅ |
| TR-boss-ai-003 | boss-ai.md | Boss AI | ≤ 2 ms main thread; planner off-thread or sliced | ADR-0006, ADR-0008 | ✅ |
| TR-boss-ai-004 | boss-ai.md | Boss AI | Telegraph events; `effective_mode = min(...)` | ADR-0008 (Decision 3 `ai_intent_shown` append; Decision 7 `telegraph_mode` forwarding — cited 2026-11-03; the `min()` rule is BossAI logic, boss-ai C8.4), ADR-0006 | ✅ |
| TR-boss-ai-005 | boss-ai.md | Boss AI | `ai_profiles.json` resolution; stage-7 validator; `runtime` block | ADR-0002 (served via `config("ai_profiles")`, validator slot), ADR-0006 (`runtime{planner_mode, slice_ms, replay_budget_ms}` owned by boss-ai F9, consumed by `PlannerTask`), ADR-0008 (`ProfileResolver.resolve` call site) | ✅ |
| TR-boss-ai-006 | boss-ai.md | Boss AI | Headless sim harness | ADR-0006 (`ImmediatePlannerTask`) | ✅ |
| TR-heroes-001 | heroes.md | Heroes | Heroes are data; hero powers are DSL effects | ADR-0002, ADR-0007 | ✅ |
| TR-run-structure-001 | run-structure.md | Run Structure | `RunState` schema with `validate()`; seed persisted as hex | ADR-0004, ADR-0008 | ✅ |
| TR-run-structure-002 | run-structure.md | Run Structure | `new_run`, `begin_match`, `MatchResult` handling | ADR-0008 | ✅ |
| TR-run-structure-003 | run-structure.md | Run Structure | Transition table; seven commands | ADR-0008 (T5–T9), ADR-0011 | ✅ |
| TR-run-structure-004 | run-structure.md | Run Structure | Save points via Meta; resume semantics | ADR-0003, ADR-0004, ADR-0008, ADR-0011 | ✅ |
| TR-run-structure-005 | run-structure.md | Run Structure | Run Structure owns the match driver | ADR-0006, ADR-0008 | ✅ |
| TR-reward-draft-001 | reward-draft.md | Reward Draft | `init_run`/`offer`/`pick`; `offer` pure | ADR-0003 (stream side: `draft_<f>` injected, F6 purity, events on the run log), ADR-0005 (pool side: snapshot once at `init_run`, `offer` never re-reads `pool()`), ADR-0011 (UI side) | ✅ |
| TR-reward-draft-002 | reward-draft.md | Reward Draft | Exclusion/pity from `drafts[]`; pool snapshot at `init_run` | ADR-0003 (persistence side: `drafts[]` in the `RunRecord`, no separate pity state), ADR-0005 (pool side: recomputed per call from `DraftRecord` entries) | ✅ |
| TR-treasures-001 | treasures.md | Treasures | Per-match `HookRegistry`, installation order, owner scope | ADR-0005 | ✅ |
| TR-treasures-002 | treasures.md | Treasures | `installers_for` pure/idempotent; duplicate skipped | ADR-0005 | ✅ |
| TR-treasures-003 | treasures.md | Treasures | `collect_state`; `pool()` id-ascending | ADR-0005 | ✅ |
| TR-treasures-004 | treasures.md | Treasures | Fold < 0.05 ms, no allocation | ADR-0005 | ✅ |
| TR-meta-progression-001 | meta-progression.md | Meta Progression | One profile file; M1.3 API | ADR-0004, ADR-0011 | ✅ |
| TR-meta-progression-002 | meta-progression.md | Meta Progression | Atomic write; pure migrations | ADR-0004 | ✅ |
| TR-meta-progression-003 | meta-progression.md | Meta Progression | Load order; corrupt copies; `ReadOnly`; repairs | ADR-0004 | ✅ |
| TR-meta-progression-004 | meta-progression.md | Meta Progression | `profile.lock` heartbeat | ADR-0004 | ✅ |
| TR-meta-progression-005 | meta-progression.md | Meta Progression | Settings record incl. `bindings`; `settings_changed`; MVP stub | ADR-0004 (incl. the 2026-11-03 addendum), ADR-0009, ADR-0011 | ✅ |
| TR-meta-progression-006 | meta-progression.md | Meta Progression | ≤ 2 MB; save ≤ 50 ms | ADR-0004 | ✅ |
| TR-match-ui-001 | match-ui.md | Match UI | `MatchView` parts; three channels | ADR-0001, ADR-0008, ADR-0009 | ✅ |
| TR-match-ui-002 | match-ui.md | Match UI | Projection; `AnimStep` FIFO; skip-all; idle invariant | ADR-0003, ADR-0009 | ✅ |
| TR-match-ui-003 | match-ui.md | Match UI | Boss turn in the log; UI paces | ADR-0003, ADR-0006, ADR-0008, ADR-0009 | ✅ |
| TR-match-ui-004 | match-ui.md | Match UI | Debug entry points; fixtures run the real engine | ADR-0001, ADR-0008, ADR-0009, ADR-0010 | ✅ |
| TR-match-ui-005 | match-ui.md | Match UI | Latency table | ADR-0009 | ✅ |
| TR-match-ui-006 | match-ui.md | Match UI | Scene hand-off; `match_view_finished` | ADR-0008, ADR-0009, ADR-0011 | ✅ |
| TR-run-ui-001 | run-ui.md | Run UI | `RunShell`, `RunController` sole talker | ADR-0001, ADR-0011 | ✅ |
| TR-run-ui-002 | run-ui.md | Run UI | Screen inventory; intent map; `data_error` | ADR-0008, ADR-0011 | ✅ |
| TR-run-ui-003 | run-ui.md | Run UI | Mouse primary, keyboard complete, dual focus | ADR-0011 | ✅ |
| TR-run-ui-004 | run-ui.md | Run UI | Run UI fixtures into a Meta stub | ADR-0001, ADR-0010, ADR-0011 | ✅ |
| TR-run-ui-005 | run-ui.md | Run UI | Restart and transition budgets | ADR-0011 | ✅ |
| TR-content-001 | content.md | Content | Headless validate command; zero-error batches | ADR-0002 | ✅ |
| TR-content-002 | content.md | Content | Run logs and sim outputs feed `/balance-check` | ADR-0003 (archives `user://runs/`, `user://logs/`, sim JSON — one envelope; cited 2026-11-03), ADR-0006 (harness producer) | ✅ |
| TR-game-concept-001 | game-concept.md | Game Concept | Xvfb evidence; renderer for capture | ADR-0010 | ✅ |
| TR-design-decisions-001 | design-decisions.md | Design Decisions | DD-T02 rules are `RefCounted` | ADR-0001, ADR-0006 | ✅ |
| TR-design-decisions-002 | design-decisions.md | Design Decisions | DD-T01 JSON data; profile path | ADR-0002, ADR-0004 | ✅ |
| TR-design-decisions-003 | design-decisions.md | Design Decisions | DD-T05 1280x720, `canvas_items`, input | ADR-0009, ADR-0010, ADR-0011 | ✅ |
| TR-systems-index-001 | systems-index.md | Systems Index | Run ↔ Meta via `MetaApi` + stub | ADR-0001, ADR-0004, ADR-0011 | ✅ |
| TR-systems-index-002 | systems-index.md | Systems Index | Match UI ↔ Run UI one-way hand-off | ADR-0001, ADR-0008, ADR-0009, ADR-0011 | ✅ |
| TR-systems-index-003 | systems-index.md | Systems Index | Treasures ↔ Reward Draft: pool read, `treasure_granted` | ADR-0005 (pool edge QQ-08; `RunMachine` named as the `treasure_granted` emitter, R5.4 / T11 — cited 2026-11-03), ADR-0011 (routes the event) | ✅ |
| TR-tech-debt-001 | tech-debt-register.md | Tech Debt | Production tree retires TD-001..012 | ADR-0001, ADR-0002, ADR-0003, ADR-0004, ADR-0005, ADR-0007, ADR-0008, ADR-0009, ADR-0010, ADR-0011 | ✅ |
| TR-accessibility-requirements-001 | accessibility-requirements.md | Accessibility | Input remapping persists across restarts; storage | ADR-0004 (Decision addendum 2026-11-03: `settings.bindings` in the profile settings record, applied to `InputMap` at Boot, same atomic path, `cancel` fixed, additive key) | ✅ |

## Known Gaps

None. The one gap of the prior index (`TR-accessibility-requirements-001`) is closed by ADR-0004's decision addendum. Two follow-ups are recorded in the review report, neither a coverage gap: `design/accessibility-requirements.md` Open Questions row still reads "storage undecided" and should point at the addendum; the addendum's `InputMap` / `InputEvent`-as-Dictionary claims are not yet listed in ADR-0004's Engine Compatibility table (LOW risk, pre-4.3 APIs; `modules/input.md` covers only `DEVICE_ID_*`).

## Superseded Requirements

None superseded. Three registry entries were `revised` 2026-11-03 because their GDD wording changed after the ADR was written, with the same intent and no ADR change required: `TR-rng-event-log-003` (rule 10 snapshot carries `run_seed_hex`), `TR-run-structure-001` (R1 persists the seed as hex — the prior run's GDD revision flag, now applied), `TR-meta-progression-005` (M9 gains `bindings`). All three are consistent with ADR-0003 / ADR-0004 as accepted.

| Date | GDD | Requirement | Changed To | ADRs Affected | Resolution |
|------|-----|-------------|------------|---------------|------------|
| 2026-11-04 | boss-ai.md | TR-boss-ai-003 — "budgets are counts, 50 ms per turn is the p95 acceptance target" (A22: one forecast + one play_turn per round) | "budgets are counts, 500 ms per planner run (`play_turn` and `forecast` each) is the p95 acceptance target" (DD-X18; F7 `t_sim` measured ≈ 0.37 ms release) | ADR-0006, ADR-0007 | Updated (errata 2026-11-04; same intent, `revised` in the registry; decisions unchanged) — `docs/architecture/change-impact-2026-11-04-boss-ai.md` |
| 2026-11-04 | rng-event-log.md | Acceptance Criteria (Performance) — "10,000 appends + `events_since(0)` under 50 ms headless" | "… under 80 ms headless" (DD-X19) | ADR-0003 | Updated (erratum 2026-11-04; decision unchanged) — `docs/architecture/change-impact-2026-11-04-owner-decisions.md` |
| 2026-11-04 | match-rules.md | C12 Deathrattle — "fires … but not if Silenced before [it died]" (destroy then silence in one effect: no Deathrattle) | "a minion already `pending_destroy` keeps its Deathrattles when Silenced — destroy then silence fires" (C13 step 2; DD-X21); card-effects C10 `E_FX_OP` rejects the destroy-first order in content | none (ADR-0007 checked) | Valid — `docs/architecture/change-impact-2026-11-04-owner-decisions.md` |
