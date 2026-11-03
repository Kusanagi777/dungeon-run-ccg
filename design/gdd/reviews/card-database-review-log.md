# Review Log — Card Database (`design/gdd/card-database.md`)

## Review — 2026-11-03 — Verdict: NEEDS REVISION
Review mode: lean · Workflow: standard
Scope signal: L
Specialists: none (lean mode — main review only; qa-lead AC check performed inline)
Blocking items: 4 | Recommended: 5
Summary: The document is precise and implementable on its own terms, but it had drifted from the register and from the twelve dependent GDDs written after it: DD-T01 now lists nine per-system config files under `assets/data/` that CR-1 would have rejected as `W_UNKNOWN_FILE` while the index forbids any other JSON parser; four dependents read a `data_version` the GDD never defined; `TreasureDef.tags` (carried by every registry treasure) and three other requested fields were absent under a schema that rejects unknown fields; and DD-T01/DD-H06 "proposals" were already accepted. All four blockers were resolved in place from design-decisions.md, the registry and the sibling GDDs (option [A], REVISED note in the header); one owner decision (`unlock` shape) and three sibling-GDD wording changes remain open. Status after revision: In Review.
Prior verdict resolved: First review
Findings:
- [BLOCKING] Detailed Design CR-1 / CR-7 / Edge Cases: DD-T01 lists `match_rules.json`, `card_effects.json`, `ai_profiles.json`, `run_structure.json`, `reward_draft.json`, `treasures_balance.json`, `heroes_balance.json`, `match_ui.json`, `run_ui.json`; CR-1 would warn on each and load none, and no path existed for owners to reach their knobs without parsing JSON themselves — FIXED: config file class, `config` envelope, `config(name)` query, per-file owner validators, edge cases and ACs.
- [BLOCKING] Detailed Design CR-3 TreasureDef: `tags` absent while registry treasures carry `tags` and Treasures T1 / Reward Draft F2 require it; `E_UNKNOWN_FIELD` would fail the shipped `treasures.json` — FIXED: `tags` added (shape here, semantics in Treasures' `E_TR_TAGS`); also `HeroDef.unlock` (Heroes H-7), `BossDef.tags` (Run Structure, Content), `BossDef.passive_text` (Content, Run UI).
- [BLOCKING] Detailed Design CR-6: `data_version` read by Run Structure R8, Treasures, Meta Progression M3.5 and Run UI but defined nowhere — FIXED: CR-9 deterministic content fingerprint, `data_version()` query, AC.
- [BLOCKING] Detailed Design CR-1 / Formulas / Open Questions: stale against the register — DD-T01 already includes `hero_powers.json` and `cards_boss.json`; DD-H06 is 10 MVP treasures, not 8, so the "warning fires at MVP" claim and two Open Questions were wrong — FIXED.
- [RECOMMENDED] Dependencies / Cross-References: "none of the dependent GDDs exist yet", "(planned)" markers and the index-row complaint were stale — FIXED in the same pass.
- [RECOMMENDED] Acceptance Criteria: "every record count matches the Content manifest" named an artifact that does not exist — rewritten against content.md's content-volume table with the MVP numbers.
- [RECOMMENDED] Open Questions: `unlock` shape (string vs `{key, condition}` object; `BundleDef.unlock`) is an owner decision (Meta Progression M2.1 names Jacob) — left open, string form kept.
- [RECOMMENDED] Cross-GDD wording: Run UI says `synergy_tags[]` (canonical is `tags`); Match Rules Dependencies says it reads a stored `targeting` field (Card Effects derives it; no field here); Match UI and Boss AI should reword their loader alternatives to `config(name)` — not edited here.
- [RECOMMENDED] Formulas: `min_bundle_pool` warning default 10 is this GDD's own number; Reward Draft's registered `bundle_pool_min` (5–21, pity-dependent) is the real requirement — consider pointing the warning threshold at it.
- [NICE-TO-HAVE] CR-2: bosses and boss-set cards share the `boss_` prefix in one namespace; collisions are caught (`E_DUP_ID`) but a distinct prefix for boss cards would remove the footgun.
Reviewed-Content-Hash: design/gdd/card-database.md c5903c4c808a0d2b1cf124242ba10a0fb1ea0fef
Reviewed-Content-Hash: design/registry/entities.yaml 3364fe83ab25b4e4e9cc1c97bce415b250230dba
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md 942314097524c7e2f25ad786643fba0a8aa4a701
Reviewed-Content-Hash: design/design-decisions.md 96d205e052b6b069575e43201d735fb254843a13
Reviewed-Content-Hash: design/gdd/systems-index.md 1a5454bb731d1a57ff78d52c6cb98ae3d49598fc
Reviewed-Content-Hash: design/gdd/treasures.md d4fdb4ad7d2f8d634fe1fe768ed1accd5ffa353a
Reviewed-Content-Hash: design/gdd/reward-draft.md 22cb0fa8fa8c6ffab127655ecccb7f50fce77ea7
Reviewed-Content-Hash: design/gdd/card-effects.md 06d1a1c86d2da73767a5865e64187943b8849dd6
Reviewed-Content-Hash: design/gdd/match-rules.md 10ab29c12900d1a178bfdda2ac4852808fc32b72
Reviewed-Content-Hash: design/gdd/content.md 3e5e568fada0126b6e7f2685c4afe86211dca3e6
Reviewed-Content-Hash: design/gdd/heroes.md 6539c88e77e08175ac5bce36345d1ab79be429e4
Reviewed-Content-Hash: design/gdd/boss-ai.md 494058ed4e0f53de4a41b7e5613c86537dd01d71
Reviewed-Content-Hash: design/gdd/run-structure.md e4b95d90738cc6c5d47750708c729a1a815d3e9d
Reviewed-Content-Hash: design/gdd/run-ui.md 92ba5e70b8b6324bae72d3b5238e86b088f3c99f
Reviewed-Content-Hash: design/gdd/meta-progression.md e1b2d83f2eee16edc639e9093cc89474ca40df94
Reviewed-Content-Hash: design/gdd/match-ui.md 6645f862cbd413853a0afdec2f3ccf775e811547
Reviewed-Content-Hash: design/gdd/rng-event-log.md cb06cb1680292fc0af6b80262894d273f27d1fa8
