# Architecture Traceability Index
Last Updated: 2026-11-03
Engine: Godot 4.7.2 (GDScript; pinned 4.7 — `docs/engine-reference/godot/VERSION.md`)
Source run: `/architecture-review` full, workflow `standard` — `docs/architecture/architecture-review-2026-11-03.md`

## Coverage Summary
- Total requirements: 72 (71 from the architecture.md baseline, now registered; 1 new from `design/accessibility-requirements.md`)
- Covered: 64 (89%) — every covering ADR is `Accepted`
- Partial: 7
- Gaps: 1

Status key: ✅ Covered by an Accepted ADR that cites the requirement · ⚠️ Partial (implicit or half coverage; no ADR cites it) · ❌ Gap (no ADR). No ADR is `Proposed`, so no 🟡 rows; no ADR is unreadable, so no ❓ rows.

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
| TR-rng-event-log-003 | rng-event-log.md | RNG & Event Log | Replay equivalence; `snapshot()`/`restore()` | ADR-0003, ADR-0006 | ✅ |
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
| TR-match-rules-008 | match-rules.md | Match Rules | `submit()` ≤ 5 ms, `legal_commands()` ≤ 2 ms | ADR-0009 (cites; caller side), ADR-0007 (Performance Implications: `targeting_spec` memo) | ⚠️ Partial — a budget no ADR decides how to meet; proven by the Match Rules performance test, not by architecture |
| TR-card-effects-001 | card-effects.md | Card Effects | Effects are plain JSON; `targeting_spec` derived | ADR-0002, ADR-0007 | ✅ |
| TR-card-effects-002 | card-effects.md | Card Effects | Resolver over primitives; one pass = one step; bind at `start` | ADR-0007 | ✅ |
| TR-card-effects-003 | card-effects.md | Card Effects | One `ChoiceRequest` with continuation | ADR-0007 | ✅ |
| TR-card-effects-004 | card-effects.md | Card Effects | Hook-bound and observer effects | ADR-0005, ADR-0007 | ✅ |
| TR-card-effects-005 | card-effects.md | Card Effects | `validate_effects` injected at stage 7 | ADR-0002, ADR-0007 | ✅ |
| TR-card-effects-006 | card-effects.md | Card Effects | Static step bound 250; 8 ops | ADR-0007 | ✅ |
| TR-boss-ai-001 | boss-ai.md | Boss AI | Pure `RefCounted` planner over `legal_commands`/`clone` | ADR-0001, ADR-0003, ADR-0006 | ✅ |
| TR-boss-ai-002 | boss-ai.md | Boss AI | `forecast`/`play_turn`/`choose` synchronous | ADR-0006, ADR-0008 | ✅ |
| TR-boss-ai-003 | boss-ai.md | Boss AI | ≤ 2 ms main thread; planner off-thread or sliced | ADR-0006, ADR-0008 | ✅ |
| TR-boss-ai-004 | boss-ai.md | Boss AI | Telegraph events; `effective_mode = min(...)` | ADR-0008 (Decision 3: `ai_intent_shown` append; Decision 7: `telegraph_mode` forwarding), ADR-0006 (driver appends on main thread) — implicit, uncited | ⚠️ Partial — emission path and setting plumbing decided; no ADR table cites TR-boss-ai-004; the `min()` rule itself is BossAI logic and needs no ADR |
| TR-boss-ai-005 | boss-ai.md | Boss AI | `ai_profiles.json` resolution; stage-7 validator | ADR-0002 (config served, validator slot), ADR-0008 (`ProfileResolver.resolve` call site), ADR-0006 (`runtime` block proposed) — uncited | ⚠️ Partial — loading and validation covered; the `runtime{planner_mode, slice_ms, replay_budget_ms}` block still has no data owner (open since acceptance) |
| TR-boss-ai-006 | boss-ai.md | Boss AI | Headless sim harness | ADR-0006 (`ImmediatePlannerTask`) | ✅ |
| TR-heroes-001 | heroes.md | Heroes | Heroes are data; hero powers are DSL effects | ADR-0002, ADR-0007 | ✅ |
| TR-run-structure-001 | run-structure.md | Run Structure | `RunState` schema with `validate()` | ADR-0004, ADR-0008 | ✅ |
| TR-run-structure-002 | run-structure.md | Run Structure | `new_run`, `begin_match`, `MatchResult` handling | ADR-0008 | ✅ |
| TR-run-structure-003 | run-structure.md | Run Structure | Transition table; seven commands | ADR-0008 (T5–T9), ADR-0011 | ✅ |
| TR-run-structure-004 | run-structure.md | Run Structure | Save points via Meta; resume semantics | ADR-0003, ADR-0004, ADR-0008, ADR-0011 | ✅ |
| TR-run-structure-005 | run-structure.md | Run Structure | Run Structure owns the match driver | ADR-0006, ADR-0008 | ✅ |
| TR-reward-draft-001 | reward-draft.md | Reward Draft | `init_run`/`offer`/`pick`; `offer` pure | ADR-0011 (UI side: `Offer` read model, `pick` → `draft_pick`); purity follows ADR-0003 rule 7 lint; `architecture.md` §API Boundaries | ⚠️ Partial — no ADR decides the Reward Draft API or its stream injection; Feature layer, non-critical at `standard` |
| TR-reward-draft-002 | reward-draft.md | Reward Draft | Exclusion/pity from `drafts[]`; pool snapshot at `init_run` | ADR-0005 (pool half: `Treasures.pool()` called once from `init_run`) | ⚠️ Partial — pity/exclusion derivation from `run_state.drafts[]` (no separate pity state) is in no ADR |
| TR-treasures-001 | treasures.md | Treasures | Per-match `HookRegistry`, installation order, owner scope | ADR-0005 | ✅ |
| TR-treasures-002 | treasures.md | Treasures | `installers_for` pure/idempotent; duplicate skipped | ADR-0005 | ✅ |
| TR-treasures-003 | treasures.md | Treasures | `collect_state`; `pool()` id-ascending | ADR-0005 | ✅ |
| TR-treasures-004 | treasures.md | Treasures | Fold < 0.05 ms, no allocation | ADR-0005 | ✅ |
| TR-meta-progression-001 | meta-progression.md | Meta Progression | One profile file; M1.3 API | ADR-0004, ADR-0011 | ✅ |
| TR-meta-progression-002 | meta-progression.md | Meta Progression | Atomic write; pure migrations | ADR-0004 | ✅ |
| TR-meta-progression-003 | meta-progression.md | Meta Progression | Load order; corrupt copies; `ReadOnly`; repairs | ADR-0004 | ✅ |
| TR-meta-progression-004 | meta-progression.md | Meta Progression | `profile.lock` heartbeat | ADR-0004 | ✅ |
| TR-meta-progression-005 | meta-progression.md | Meta Progression | Settings record; `settings_changed`; MVP stub | ADR-0004, ADR-0009, ADR-0011 | ✅ |
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
| TR-content-002 | content.md | Content | Run logs and sim outputs feed `/balance-check` | ADR-0003 (archives exist), ADR-0006 (harness) — producers only, uncited | ⚠️ Partial — tooling input contract; no ADR names it and none is needed; close by citing in ADR-0003's table |
| TR-game-concept-001 | game-concept.md | Game Concept | Xvfb evidence; renderer for capture | ADR-0010 | ✅ |
| TR-design-decisions-001 | design-decisions.md | Design Decisions | DD-T02 rules are `RefCounted` | ADR-0001, ADR-0006 | ✅ |
| TR-design-decisions-002 | design-decisions.md | Design Decisions | DD-T01 JSON data; profile path | ADR-0002, ADR-0004 | ✅ |
| TR-design-decisions-003 | design-decisions.md | Design Decisions | DD-T05 1280x720, `canvas_items`, input | ADR-0009, ADR-0010, ADR-0011 | ✅ |
| TR-systems-index-001 | systems-index.md | Systems Index | Run ↔ Meta via `MetaApi` + stub | ADR-0001, ADR-0004, ADR-0011 | ✅ |
| TR-systems-index-002 | systems-index.md | Systems Index | Match UI ↔ Run UI one-way hand-off | ADR-0001, ADR-0008, ADR-0009, ADR-0011 | ✅ |
| TR-systems-index-003 | systems-index.md | Systems Index | Treasures ↔ Reward Draft: pool read, `treasure_granted` | ADR-0005 (QQ-08 `pool()` from `init_run`), ADR-0011 (routes `treasure_granted`) — uncited | ⚠️ Partial — the pool edge is decided; the emitter of `treasure_granted` (RunMachine per systems-index) is in no ADR table |
| TR-tech-debt-001 | tech-debt-register.md | Tech Debt | Production tree retires TD-001..012 | ADR-0001, ADR-0002, ADR-0003, ADR-0004, ADR-0005, ADR-0007, ADR-0008, ADR-0009, ADR-0010, ADR-0011 | ✅ |
| TR-accessibility-requirements-001 | accessibility-requirements.md | Accessibility | Input remapping persists; storage undecided | — | ❌ GAP |

## Known Gaps

- ❌ **TR-accessibility-requirements-001** — `design/accessibility-requirements.md` § Motor / Open Questions: full input remapping (Standard tier, due Alpha) needs a persisted bindings store; the doc leaves "bindings map in meta M9 vs `InputMap` serialised to `user://bindings.cfg` by Run UI" open. Suggested: `/architecture-decision input-remapping-storage` (Presentation / Persistence; engine risk LOW — `InputMap` is pre-4.3; the 4.5 SDL3 gamepad driver only matters post-v1). Not blocking: Alpha scope, Feature/Presentation layer.

Partial rows (no new ADR required; close each by adding the cited row to the named ADR's `## GDD Requirements Addressed` table on its next revision):
- TR-match-rules-008 → ADR-0007 (engine-side perf budget; the performance test is the proof)
- TR-boss-ai-004 → ADR-0008 (telegraph emission and `telegraph_mode` forwarding)
- TR-boss-ai-005 → ADR-0002 (validator slot) and ADR-0006 (`runtime` block — assign the data owner first)
- TR-reward-draft-001, TR-reward-draft-002 → either rows in ADR-0003/ADR-0005, or a small Feature-layer ADR "Reward Draft purity and draft-state ownership" if the team wants the offer/pick contract binding
- TR-content-002 → ADR-0003 (archive as `/balance-check` input)
- TR-systems-index-003 → ADR-0005 (name RunMachine as the `treasure_granted` emitter)

## Superseded Requirements

None — this is the first registration; no GDD changed after an ADR was written. The seven consistency edits made at acceptance (2026-11-03) changed ADR text, not GDDs.
