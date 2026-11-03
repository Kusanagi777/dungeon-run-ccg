# Review log — design/gdd/content.md

## Review — 2026-11-03 — Verdict: NEEDS REVISION
Review mode: lean · Workflow: standard
Scope signal: XL
Specialists: none (lean mode — no specialist agents spawned; main-review AC check only)
Blocking items: 4 | Recommended: 7
Summary: Structurally complete (8/8 present, 6/6 required at `standard` incl. Formulas) and the card, boss and bundle tables are internally consistent (all counts, curves, shares, bundle tags/sets/bands and 52/56 hero-set coverage recomputed and confirmed; 10 card rows and all 4 MVP bosses verified against card-effects C2/C3/C5/C11 and no v2 pattern used). Blocking: CN-5 described a 5/5/5/5 treasure split and a "5 generic + 5 War" MVP that the Treasures GDD's authoritative T8 table contradicts (10/4/3/3; MVP = 7 universal + 2 War + 1 Knowledge); CN-6 MVP-0 shipped `heroes.json` with three heroes whose starter cards are Alpha records, so the batch's own "loads clean" gate fails on CR-5 `E_UNKNOWN_REF`; `power_mend` and `neutral_sheep` were batched before any record referenced them (orphans, data-files rule / AC-16); two arithmetic slips (F3 Kingsblade budget, F5 op count). All four resolved in session from the Treasures GDD, DD-H06 and Card Database CR-1/CR-5 without an owner decision; status is now In Review pending re-review.
Prior verdict resolved: First review
Findings:
- [BLOCKING] CN-5 Treasure plan: split and MVP set contradicted Treasures T8 (fixed — ids named per batch, 10/12/16/20 cumulative)
- [BLOCKING] CN-6 Production pipeline: MVP-0 `heroes.json` with 3 heroes cannot load clean (fixed — `hero_war` / `power_whetstone` only at MVP-0 per DD-H06; Decay/Knowledge HeroDefs with their set batches)
- [BLOCKING] CN-1 / CN-6: `power_mend` at MVP-0 and `neutral_sheep` at MVP referenced by nothing (fixed — VS / Alpha-B; token and hero-power rows rewritten; AC-20 rescoped)
- [BLOCKING] Formulas F3 / F5: Kingsblade weapon budget 13 → 14; "26 of 26" ops → 25 of 25 (fixed)
- [RECOMMENDED] CN-3 B2: Rot Warden MVP recipe was unparseable ("2× `boss_rot_zombie` ×3") — rewritten to an explicit 30
- [RECOMMENDED] CN-2 / CN-3: `tag` filter on board minions (card-effects C3 lists cards/pools only) used by `boss_rat_matriarch` (MVP), `decay_husk_herder`, `decay_plague_of_rot` — Open Question added with MVP fallback (card-effects R-3)
- [RECOMMENDED] CN-3: boss passives on `on_minion_died` / `on_play` / `on_attack` have no hook column; Rot Warden (MVP) depends on Treasures T2.5 observer reading — Open Question added with fallback (card-effects R-10)
- [RECOMMENDED] CN-2: `neutral_gravekeeper` reads a counter inside its own Deathrattle while C5 says counters die with the source — Open Question added
- [RECOMMENDED] Acceptance Criteria: AC-13 basis (player targets vs Boss AI's proposed script-relative targets) — Open Question added; unnumbered AC numbered AC-21 with a grep-testable form
- [RECOMMENDED] Pipeline vs `.claude/rules/data-files.md`: `content_budgets.json` has no documented schema (only a constants list across F1–F6) — add a key list / JSON Schema sketch before the MVP-1 validator story
- [RECOMMENDED] Formulas F4: `T` model 10/10/11 per band vs Run Structure F7 (floor 8 = 10, floor 3 = 9) — state it is a band mean
Reviewed-Content-Hash: design/gdd/content.md ba2af38bd3bd5862e2967bd03c55081202282be3
Reviewed-Content-Hash: design/registry/entities.yaml 3364fe83ab25b4e4e9cc1c97bce415b250230dba
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/card-effects.md c9482cdffa200bd8c594b2c9a5185eda26c8f271
Reviewed-Content-Hash: design/gdd/treasures.md fa73c76396acba6ea9f3a563094b89c4a81fde01
Reviewed-Content-Hash: design/gdd/heroes.md 9447c45a9301eeb101f3b70de2966cec4603471b
Reviewed-Content-Hash: design/gdd/card-database.md c5903c4c808a0d2b1cf124242ba10a0fb1ea0fef
Reviewed-Content-Hash: design/gdd/boss-ai.md 58e8011f3ad5605ab42d95e56229c291c3de9775
Reviewed-Content-Hash: design/gdd/run-structure.md 3b61401b846ee41676c50c59cdd3b3bd2a0bc7da
Reviewed-Content-Hash: design/gdd/match-rules.md 4c45bb5b36e1b50b3b286a2f10ea13cd0b703eae
Reviewed-Content-Hash: design/gdd/reward-draft.md 40e87d43e0dd3bb8e64a161bfb36ba3d17afe7d0
Reviewed-Content-Hash: design/gdd/game-concept.md 942314097524c7e2f25ad786643fba0a8aa4a701
Reviewed-Content-Hash: design/design-decisions.md 96d205e052b6b069575e43201d735fb254843a13
