# Review Log — RNG & Event Log

## Review — 2026-11-03 — Verdict: NEEDS REVISION
Review mode: lean · Workflow: standard
Scope signal: L
Specialists: none (lean mode — single-session review; no `systems-designer` / `qa-lead` pass)
Blocking items: 6 | Recommended: 5
Summary: The determinism design is sound and every worked example in F1/F2 verifies numerically, but the document had drifted from the nine sibling GDDs written after it: F4 bounded `randi_range` spans to 65,536 while `weighted_pick` was allowed totals to 2^31−1 through that same call; rule 19 computed `damage_by_card` from `damage_dealt.source_id`/`amount`, fields Match Rules does not emit; the v1 catalogue named Match Rules' events differently from match-rules C15, mis-assigned `treasure_granted`, and omitted Boss AI's diagnostic events while the diagnostic-channel question assigned to this GDD stayed unanswered; the retry edge case contradicted run-structure R8.3; Dependencies and Cross-References still said no sibling GDD existed. All blocking items were resolvable from the registry, DD rows and siblings, so option [A] Revise now was taken; the GDD was revised in place and should be marked In Review pending re-review.
Prior verdict resolved: First review
Findings:
- [BLOCKING] Formulas F4: `weighted_pick` total range 1–2^31−1 contradicts `randi_range` span bound ≤ 65,536 — fixed: total bounded to 65,536, Edge Cases assert added
- [BLOCKING] Detailed Design rule 19 / Acceptance Criteria: `damage_by_card` read `source_id`/`amount`; Match Rules C15 emits `source`/`dealt` — fixed: rule, catalogue row and AC rewritten to the owner's fields
- [BLOCKING] Detailed Design §D catalogue: event names and owners disagreed with match-rules C15, run-structure R5.4, reward-draft D11, treasures R-9, boss-ai C10 — fixed: realigned; owner tables declared authoritative
- [BLOCKING] Detailed Design rule 12: diagnostic events (`command_rejected`, `ai_decision`) had no defined channel (match-rules OQ assigned here) — fixed: rule 12a, same log, `diagnostic: true`
- [BLOCKING] Edge Cases: floor retry via `fork("retry_<n>")` contradicted run-structure R8.3 (same streams at `draws = 0`) — fixed: follows Run Structure, which owns the policy
- [BLOCKING] Dependencies / Cross-References: "none of these GDDs exists yet", "(not yet authored)", stale bidirectional claim about systems-index — fixed: current state recorded, index verified
- [RECOMMENDED] Detailed Design rule 18: archive key `<run_seed_hex>` would be overwritten by a replayed seed — adopted `run_id` per run-structure / meta-progression
- [RECOMMENDED] Interactions: Card Effects per-effect fork no longer matches card-effects C6.9 direct draws — row amended; Boss AI fork use documented
- [RECOMMENDED] Tuning Knobs: absent (advisory at standard) although three knobs exist — section added with safe ranges
- [RECOMMENDED] Formulas F5 vs Acceptance Criteria: "sub-millisecond" vs "< 5 ms" for 10,000-draw restore — aligned to 5 ms
- [RECOMMENDED] Acceptance Criteria: AC-1 named no API call, AC-3 was conditional on GDDs "once they exist" — rewritten as executable tests
- [CROSS-GDD] Match Rules Interactions names the stream API `shuffle/pick/range` and `MatchConfig.seed`; should adopt F4 names and stream handles (Open Question 8)
- [CROSS-GDD] DD-T03 lists streams `run, match, draft`; GDD uses `match_<floor>`, `draft_<floor>`, `ai_<floor>` — register row wording to update via owner
- [CROSS-GDD] run-ui cites the envelope as `{seq, type, payload}`; should be `{seq, turn, type, payload, cause_seq}`
- [CROSS-GDD] boss-ai draw accounting (A-tests) must include one parent draw per new fork label (rule 5)
Reviewed-Content-Hash: design/gdd/rng-event-log.md cb06cb1680292fc0af6b80262894d273f27d1fa8
Reviewed-Content-Hash: design/registry/entities.yaml 3364fe83ab25b4e4e9cc1c97bce415b250230dba
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md 942314097524c7e2f25ad786643fba0a8aa4a701
Reviewed-Content-Hash: design/design-decisions.md 96d205e052b6b069575e43201d735fb254843a13
Reviewed-Content-Hash: design/gdd/match-rules.md ea6637fc9cbd619475b9bd73704794286bd90c2e
Reviewed-Content-Hash: design/gdd/card-effects.md 06d1a1c86d2da73767a5865e64187943b8849dd6
Reviewed-Content-Hash: design/gdd/boss-ai.md 494058ed4e0f53de4a41b7e5613c86537dd01d71
Reviewed-Content-Hash: design/gdd/run-structure.md 3b469d46dc3f6ab03659641221f32bd6899abac5
Reviewed-Content-Hash: design/gdd/reward-draft.md 12367663fc15a5201ffa2d4c2f64234d11c9fe1b
Reviewed-Content-Hash: design/gdd/treasures.md c37de4e7647527f2086ddbdb5b1b21d514518f59
Reviewed-Content-Hash: design/gdd/match-ui.md 6645f862cbd413853a0afdec2f3ccf775e811547
Reviewed-Content-Hash: design/gdd/run-ui.md 8d242eaafec4a3b0db63f3db3c65cd4771d3d120
Reviewed-Content-Hash: design/gdd/meta-progression.md bdfd4ad9111612ebe5d33596746caadfa5dc873f
Reviewed-Content-Hash: design/gdd/systems-index.md 1a5454bb731d1a57ff78d52c6cb98ae3d49598fc
