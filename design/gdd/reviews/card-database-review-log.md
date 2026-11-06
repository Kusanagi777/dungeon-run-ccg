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

## Review — 2026-11-03 — Verdict: NEEDS REVISION
Review mode: lean · Workflow: standard
Scope signal: L
Specialists: none (lean mode — main review only; qa-lead AC check performed inline)
Blocking items: 2 | Recommended: 4
Summary: Re-review after the first revision and the cross-GDD pass. All four prior blockers and the cross-review Part B items for this file (C-06 `unlock` object, C-21 `profile_defaults.json`, C-04 `targeting`, C-30 housekeeping) are verified applied, and no value in the document contradicts the registry. Two new blockers surfaced: the loader's own five tuning knobs were sourced to "data file" while no CR-1 / DD-T01 file held them and the single-parser rule left a programmer nowhere to put them (and the "no hardcoded values" AC demanded `schema_version_current` be read from a file whose envelope it validates); and the shipped-data AC restated Content CN-1's MVP counts wrongly (4 tokens / 8 boss-only / 4 bosses vs CN-1's 3 / 10 / 5). Both were resolved in place (option [A]); one register edit (a DD-T01 row for `card_database.json`) remains for the owner. Status after revision: In Review.
Prior verdict resolved: Yes
Findings:
- [BLOCKING] Formulas / CR-1 / Acceptance Criteria: `min_collectible_pool`, `min_bundle_pool`, `max_records`, `data_load_budget_ms`, `data_memory_budget_mb` sourced to "data file" with no CR-1 or DD-T01 file to hold them; AC required `schema_version_current` from config (circular) — FIXED: `card_database.json` config row (self-validated at stage 4, `config("card_database")`), `schema_version_current` declared the one code constant (CR-5 stage 3), AC rewritten with a fixture test, new AC for the knob file's range/missing cases; DD-T01 row left as an Open Question for the owner.
- [BLOCKING] Acceptance Criteria (shipped data set): MVP counts "4 tokens, 8 boss-only, 4 bosses" contradict content.md CN-1 (3 tokens, 10 boss-only, 5 bosses incl. the D-06 spare) — FIXED: aligned to CN-1 with the war 25 + neutral 15 split; CN-1 named as source of truth; Cross-References row added.
- [RECOMMENDED] Formulas: DD-H05 neutral bundles stated as ~6 (now 12), v1 bundle pool 14 (now 20), MVP collectible split 18 + 22 (CN-1: 25 + 15), validation-cost example built on 212 records / 30 bundles — FIXED in the same pass; `min_bundle_pool` now points at Reward Draft's `bundle_pool_min` (prior review's open recommendation).
- [RECOMMENDED] Dependencies: intro said "three injected validators" while CR-5 lists four record validators plus config validators — FIXED.
- [RECOMMENDED] Cross-GDD wording (not edited here): boss-ai.md Edge Cases L602 says an absent `ai_profiles.json` falls back to a built-in `default` profile "so headless tests still run"; under CR-1 a missing required config file is `E_MISSING_FILE` and the load fails, so that fallback can only exist behind an injected stub — Boss AI should say so.
- [RECOMMENDED] Registry hygiene (not edited here): `referenced_by` lists card-database.md on `discover_pool`, `boss_sequence` and `unlock_keys_v1`, none of which this document names; `bundle_pool_min` is now named (this revision). Remove the three or leave as-is if the registry treats indirect use as a reference.
- [NICE-TO-HAVE] Tuning Knobs section is absent (advisory at `standard`): the five knobs now live in the `card_database.json` row and the Formulas tables; a short Tuning Knobs table would give Content one place to read them.
Reviewed-Content-Hash: design/gdd/card-database.md bf374f0a4c79940fe414c216246ea3cca7f195db
Reviewed-Content-Hash: design/registry/entities.yaml c0b7b1c0ad84e2c548b1bb890c79073e397c259c
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md c781025c5f2a71209b4de0976ab806d097b8f0b0
Reviewed-Content-Hash: design/design-decisions.md 6d7e7fac963fc62e7ff90a531df77e23e2eb0488
Reviewed-Content-Hash: design/gdd/systems-index.md b6cea95eef89f3f0015d0cd1ff03c7189442aceb
Reviewed-Content-Hash: design/gdd/gdd-cross-review-2026-11-03.md c735c9738a373e58a095ba1c942ee89f0de6685a
Reviewed-Content-Hash: design/gdd/treasures.md 97a87411e8e8b1e2988f8eaf36cd4edbde227cee
Reviewed-Content-Hash: design/gdd/reward-draft.md f3443f5279f5593cddfc2fae713d0084f1106aa0
Reviewed-Content-Hash: design/gdd/card-effects.md 0a434c1bcf30900536181fc057877a04832c766e
Reviewed-Content-Hash: design/gdd/match-rules.md 54e7dae9ecc522fc57787bf4c65313364d74be3f
Reviewed-Content-Hash: design/gdd/content.md 9a4fabbfd9e515a5dd437ed7babbe949119da8ee
Reviewed-Content-Hash: design/gdd/heroes.md 2c76cf8115794dbf939f51317884d278d4561656
Reviewed-Content-Hash: design/gdd/boss-ai.md 346787f0550706b31047cb67b5356266e488440a
Reviewed-Content-Hash: design/gdd/run-structure.md 1485f9df6fb25ee9514c6a88385e8f88704f7603
Reviewed-Content-Hash: design/gdd/run-ui.md d9018ff2729512cf024dd40326853be715a806b4
Reviewed-Content-Hash: design/gdd/meta-progression.md 43936af8124347bad40ad7d52e1eda53d7ec5fcf
Reviewed-Content-Hash: design/gdd/match-ui.md dbff3a5d072d175f5f8fe406ad9f2258df31077d
Reviewed-Content-Hash: design/gdd/rng-event-log.md dc7474f4995cf1741e5617c0b5938f18eee5fcc4

## Review — 2026-11-03 — Verdict: APPROVED
Review mode: lean · Workflow: standard
Scope signal: L
Specialists: none (lean mode — main review only; qa-lead AC check performed inline)
Blocking items: 0 | Recommended: 0
Summary: Final pass after the second in-place revision. The document itself was byte-identical to the one the previous re-review revised; the registry, the register and thirteen sibling GDDs had changed since, so every cross-document fact was re-verified. Both prior blockers are confirmed applied and consistent across CR-1, CR-5 stage 7, Formulas and the ACs (`card_database.json` self-validated at stage 4, `schema_version_current` the one declared code constant; shipped-data AC counts equal Content CN-1's MVP row); DD-T01 now lists `card_database.json`, Boss AI reworded its `ai_profiles.json` fallback, and the registry's three stale `referenced_by` lines were removed — every open item from the previous entry is closed except `discover` (Card Effects' choice, both paths supported). No value in the document contradicts the registry or a DD row; the only edit this pass was housekeeping (three "DD-T01 row pending" markers closed, no rule or contract changed). Status: Approved.
Prior verdict resolved: Yes
Findings:
- none
- [NICE-TO-HAVE] CR-2 id table: `treasure_second_wind` is an illustrative id, not a registered treasure — `treasure_hollow_crown` would let a reader cross-check the registry.
- [NICE-TO-HAVE] CR-5 stage 4: the sentence "Config bodies are not schema-checked here" could name the `card_database.json` exception that CR-1 and stage 7 already state; and stage 8 should say budget warnings are skipped when that file failed stage 4 (the load is `Failed` anyway).
- [NICE-TO-HAVE] Tuning Knobs section still absent (advisory at `standard`); the five knobs live in the CR-1 row and the Formulas tables.
- [NICE-TO-HAVE] systems-index Recommended Design Order lists Card Database at effort `S`; three reviews have signalled `L` (five formulas, twelve dependents, an ADR for file I/O and class layout) — index-side note, not a GDD defect.
Reviewed-Content-Hash: design/gdd/card-database.md d04095c7f44e5d930ba3c23c4f88024736fdc6a8
Reviewed-Content-Hash: design/registry/entities.yaml 76f479bf5a4270db81c0d82a5eb86ee4c5c9e227
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md e2b0c05d2b9729099fdcc47c9c96c7ef6724e61f
Reviewed-Content-Hash: design/design-decisions.md 914fb4ab3d19c6957bf65dcff93bb6804f664708
Reviewed-Content-Hash: design/gdd/systems-index.md a20a2191f2853e48591ac1eec0417f089077f7c6
Reviewed-Content-Hash: design/gdd/gdd-cross-review-2026-11-03.md c735c9738a373e58a095ba1c942ee89f0de6685a
Reviewed-Content-Hash: design/gdd/treasures.md b50806cc8b2b5117b0064b934122be5ecaced4ad
Reviewed-Content-Hash: design/gdd/reward-draft.md a7efa9bae59c93827f73ff208438d3131a6de8bb
Reviewed-Content-Hash: design/gdd/card-effects.md 517bbd86e95d53c7e14a33c53347991ccb88266c
Reviewed-Content-Hash: design/gdd/match-rules.md 7af4351b32a419195d38bf274c2a68b9c63aa804
Reviewed-Content-Hash: design/gdd/content.md dc95b8e96ca465d68b1835307341807ef8ffe3a8
Reviewed-Content-Hash: design/gdd/heroes.md 3e9c89b4cd87b8fde225762af7e169fcf2fed1dd
Reviewed-Content-Hash: design/gdd/boss-ai.md 2c2bedbaa6ff558777d2af7d81b3b91c5783af82
Reviewed-Content-Hash: design/gdd/run-structure.md f89d6a98f6981671324f9a0c49708df0d1847787
Reviewed-Content-Hash: design/gdd/run-ui.md b97595084d05aabfe872316243343bf85c3f45d0
Reviewed-Content-Hash: design/gdd/meta-progression.md 878962538feb2a76598643d4ce90adc4f436ba55
Reviewed-Content-Hash: design/gdd/match-ui.md e2bcccad61083401a8c8dbdbd0a4068afc64e3d7
Reviewed-Content-Hash: design/gdd/rng-event-log.md 6981bf37934cae2e74ed37a23eb349fb62dcbf5b
