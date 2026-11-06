# Gate Check: Systems Design → Technical Setup — 2026-11-03

**Verdict: CONCERNS (accepted) — stage advanced to Technical Setup.**
Workflow standard · review lean · panel TD + PR · automation guided (owner's standing approval; entry conditions completed before the stage write).

## Artifact checklist (`gate-technical-setup.md`, standard reductions)
- [x] `design/gdd/systems-index.md` — 13 systems enumerated, MVP tier defined, dependency map bidirectional (Content row repaired; Reward Draft ↔ Content, Run Structure ↔ Meta Progression, Match UI ↔ Run UI recorded)
- [x] All MVP GDDs exist and individually pass `/design-review` — 13/13 latest log entries APPROVED (match-rules and card-effects at the `full` 8 sections per `system_overrides`; others at the standard 5 + Formulas)
- [x] Cross-GDD review report exists — `design/gdd/gdd-cross-review-2026-11-03.md` (FAIL, all 6 blocking items applied) and `design/gdd/gdd-cross-review-2026-11-03b.md` (since-last-review, both passes, **CONCERNS**, 0 blocking, 0 NOT ASSESSED)
- [x] Cross-GDD issues resolved or accepted — N-01..N-04 applied; D-01/D-05 accepted by design pending playtest measurement; D-03 owner decision carried forward
- [x] No stale GDD references — only `design/ux/draft-picker.md (planned)` remains and is a live, accurate marker (being written)

## Director panel
| Director | Gate | Verdict |
|---|---|---|
| technical-director | TD-PHASE-GATE | **CONCERNS** — enough to architect from; entry conditions were index/dependency hygiene (done) and ADR numbering (DD-X08); two engine facts NOT SOURCEABLE (AI threading model, atomic rename) must be backed by 4.7 docs or a headless probe before those ADRs are Accepted |
| producer | PR-PHASE-GATE | **CONCERNS** — design complete and stable; schedule risk unmeasured; defined Technical Setup exit criteria C4–C9 |

Escalation: two CONCERNS, no NOT READY, no NOT ASSESSED → CONCERNS; entry conditions C1–C3 (PR) and condition 1 (TD) completed 2026-11-03 before the stage write.

## Technical Setup exit criteria (before the Pre-Production gate)
1. **Critical ADRs** (~6–8), each citing the TD items it retires: ADR-0001 rules/presentation split (TD-001/003/005/006); ADR-0002 data format + effect schema/DSL + `config()` loading (TD-008); ADR-0003 seeded RNG service + event log (TD-007); ADR-0004 save format + atomic profile write; owner-scoped hook registry (supersedes modifier-hook-chain.md; TD-009); Boss AI planner threading/time-slicing (2 ms rule); effect resolver/validator boundary; match driver ownership; Match UI tween/scene partition; **renderer vs Xvfb capture** (carry-forward). Numbering per DD-X08.
2. `/create-control-manifest` and `/architecture-review` over the ADR set; TR registry traced to GDD requirements.
3. Test rig completion: export preset + `commands.build`, a main-scene stub so `commands.smoke` exits, one integration test in CI, a proven launch-and-screenshot run into `production/qa/evidence/`.
4. UX: finish and `/ux-review` the per-screen specs (hud, draft-picker, hero-select, run-summary); close hud.md §13 conflicts.
5. Close TD-001..TD-012 against the ADRs that rule out each root cause.
6. Performance budgets recorded in `docs/architecture/architecture.md` (frame, AI, UI latency, load, memory, draw calls).
7. Carry-forwards from the previous gate: weekly hours + `/estimate`; early playable build as first Pre-Production goal; Meta Progression MVP stub; DSL/Boss AI spikes + AI-vs-AI harness in sprint 1; Torchlit Ledger confirmation; decisions on N-05 (defender-hero weapon damage) and D-03 (any-hero treasure unlock).

## Next
`/create-architecture` → `/architecture-decision` ×N → `/create-control-manifest` → `/architecture-review` → `/ux-review` → `/gate-check pre-production`.
