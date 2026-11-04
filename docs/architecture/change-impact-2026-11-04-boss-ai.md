# Change Impact Report: boss-ai.md (DD-X18)

`/propagate-design-change design/gdd/boss-ai.md`, run by hand 2026-11-04
(`workflow: standard`, `review_mode: lean`, owner standing approval for DD-X18).

## Change Summary: boss-ai.md
Date of revision: 2026-11-04 (commit `docs(design): boss-ai planner target 500 ms per planner run (DD-X18)`)

Changed sections:
- C9 Budgets, determinism and logging: target sentence now "500 ms per planner run (`play_turn` and `forecast` each)".
- F7 Budgets and expected planner time: `t_sim` is measured (~0.37 ms release / ~0.45 ms debug, `production/qa/perf-match-rules-2026-11-04.md`), not 0.01 ms; per-band arithmetic against 500 ms per run (band 1 370 nodes ≈ 135 ms, band 2 1,460 ≈ 533 ms, band 3 6,000 ≈ 2,190 ms); per-round 2× remark removed; band 3's counts will be lowered by A22 if needed after match-rules story 019 re-measures.
- Tuning Knobs: `planner_target_ms` 50 → 500, safe range 20–200 → 50–1,000.
- Game Feel: Feel Reference (a short "boss thinking" beat only beyond 300 ms); Input Responsiveness "Player `end_turn` → boss planner complete" 50 → 500 ms (30 frames).
- Acceptance Criteria A22: p95 ≤ 500 ms per planner run, `play_turn` and `forecast` each.

Unchanged sections: Overview, Player Fantasy, C1–C8, C10–C11, F1–F6, F8–F9, Edge Cases, Dependencies, Visual/Audio, all other acceptance criteria. Node counts (`lethal_max_nodes`, `max_evals_per_action`), the 2 ms main-thread budget (A30), `slice_ms` and `replay_budget_ms` are unchanged.

Key changes affecting architecture: the planner-time target and its unit (per round → per run); F7's `t_sim`.

Downstream GDDs to re-check (`design/registry/entities.yaml`):
- `ai_planner_target_ms` — referenced only by boss-ai.md; registry value updated 50 → 500 (`revised: 2026-11-04`).
- **match-ui.md Input Responsiveness** "End Turn → boss intent commit beat visible | 300 | boss-ai target": not a registry reference, found by search. With a `play_turn` run of up to 500 ms, the commit beat cannot always be visible within 300 ms of End Turn; the "boss thinking" state covers the gap. **Not edited** (outside this propagation's scope) — needs a match-ui note.

## ADRs in scope

Checked 10 ADRs (standard: the 5 Foundation ADRs plus any ADR naming boss-ai.md; ADR-0009 is out of scope). 8 reference boss-ai.md (ADR-0001, 0002, 0003, 0005, 0006, 0007, 0008, 0011); a search for the changed facts (50 ms target, A22, F7 `t_sim`, `planner_target_ms`) hits 2 of them.

### ADR-0006: Boss AI Planner Threading
Status: Needs Review → **Updated in place (erratum 2026-11-04)**
- Assumed: "50 ms p95 planner per turn (A22)"; F7 band-3 ≈ 60–80 ms; "forecast doubles the per-round worker cost".
- Now: 500 ms p95 per planner run, `play_turn` and `forecast` each; measured `t_sim` ≈ 0.37 ms.
- Assessment: the Decision (worker pool default, time-sliced fallback, clone-and-replay) still holds and is strengthened. Text fixed in Status (erratum), Summary, Problem Statement, Constraints, Negative (cancel-block bound), GDD Requirements Addressed, Performance Implications, Validation Criteria (A22 and the 300 ms commit-beat criterion).

### ADR-0007: Effect Resolver / Validator Boundary
Status: Needs Review → **Updated in place (erratum 2026-11-04)**
- Assumed: `clone()` + memo measured against `planner_target_ms` 50 p95; F7 ≈ 60 ms band-3.
- Assessment: decision unaffected; Performance Implications and the Engine Compatibility claim row updated.

### Still valid
ADR-0001, 0002, 0003, 0005, 0008, 0011 cite boss-ai.md for other requirements (C1, C9 counts-not-clock, C10/F9 config, hooks, driver ownership); none cites the target or `t_sim`. ADR-0008's "forecast returned after End Turn → discard" path is more likely at 500 ms but already tolerated (boss-ai C8). ADR-0004 and ADR-0010 (Foundation) do not reference boss-ai.md. ADR-0009 (Presentation) is out of scope at `standard` and is not verified unaffected; it quotes match-ui's 300 ms End Turn → commit beat, see Downstream GDDs.

TD-CHANGE-IMPACT skipped — Lean mode.

## Other architecture documents fixed
- `docs/architecture/architecture.md`: TR-boss-ai-003 baseline row, §Performance budgets "Boss AI planner per run", §Required ADRs ADR-0006 context, Last Updated.
- `docs/architecture/control-manifest.md`: Core Performance Guardrails "Boss AI worker" and "`clone()` + empty resolver memo" (Manifest Version already 2026-11-04).
- `docs/architecture/tr-registry.yaml`: TR-boss-ai-003 text, `revised: 2026-11-04` (same intent, ID kept).
- `docs/architecture/requirements-traceability.md`: Superseded Requirements row.
- Not edited: `architecture-review-2026-11-03*.md` (dated review records).

## Follow-up
- Match-rules story 019 re-measures `t_sim`; then `/propagate-design-change` on boss-ai F7 counts (band 3 lowered until A22 passes).
- match-ui.md End Turn → commit beat row: add the "boss thinking" note.

Verdict: COMPLETE — change impact report saved
