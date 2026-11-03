# Review Log — Heroes (`design/gdd/heroes.md`)

## Review — 2026-11-03 — Verdict: NEEDS REVISION
Review mode: lean · Workflow: standard
Scope signal: L
Specialists: none (lean mode — single-session analysis; `qa-lead`, `systems-designer`, `creative-director` not spawned)
Blocking items: 8 | Recommended: 6
Summary: Structurally complete (8/8 present, 6/6 required at `standard` incl. Formulas) and registry-consistent, but the H-3 DSL sketches used a vocabulary card-effects v1 does not have, Rot's resolution order (death check between ops) contradicted card-effects C6.0/C6.4 and match-rules C10, and two starter/signature card texts were stale against Content's v1 redesigns. Seven of the eight blockers were resolved in place from the sibling GDDs the same day (card-effects' concurrent revision rewrote C11 rows 8/16/25 to these powers, which also settled Insight); the document is now In Review. One blocker is cross-GDD: Content's `armour` tag on `war_iron_vanguard` makes War's starter score 7 > `PLAN_MAX` 6 in F2.
Prior verdict resolved: First review
Findings:
- [BLOCKING] Detailed Design H-3: DSL sketches used `branch`/`has_weapon`/`enchant`/`equip_weapon`/`left_play`/`bind`/`enchant_card` — none exist in card-effects C3–C5 — FIXED (now C11 rows 8/16/25 verbatim: `conditional`+`exists owner_weapon`, `buff`, `equip`, `test [target, is_dying]`, `summon`, `buff cost` on `deck_top` then `draw`)
- [BLOCKING] Detailed Design H-3 / Edge Cases / AC-9–11: Rot assumed a death check between its two ops; card-effects C6.0 resolves one effect as one step with the C10 death check after it — FIXED (Husk precedes `minion_died` and the Deathrattle; full-board self-Rot yields `summon_failed`)
- [BLOCKING] Detailed Design H-3: Insight tax had no draw-binding in card-effects v1 and C11 row 25 said "Deal 1 damage" — FIXED by card-effects' same-day revision (`buff cost` on `deck_top` before `draw`); Heroes sketch, AC-13 and the empty-deck edge case aligned; fallback text withdrawn
- [BLOCKING] Detailed Design H-4: `war_quartermaster` "+1 Durability" stale vs Content redesign (`weapon_durability` is v2 per card-effects/treasures) — FIXED
- [BLOCKING] Detailed Design H-5: `war_cleave_through` adjacency text stale vs Content redesign — FIXED
- [BLOCKING] Formulas F2 / H-4: example counted tags not cards; Decay scores 5, not 6 — FIXED; Content's `armour` tag on `war_iron_vanguard` makes War 7 > `PLAN_MAX` 6 — OPEN, cross-GDD (Content drops the tag, or owner raises the knob)
- [BLOCKING] Acceptance Criteria AC-4: contradicted F4/Edge Cases (1 weapon = 0.04 is inside ±0.08) — FIXED (3-weapon fixture)
- [BLOCKING] States / Edge Cases / AC-16: `INSUFFICIENT_MANA` and `HERO_LOCKED` are not their owners' codes (`NOT_ENOUGH_MANA`, `E_HERO_LOCKED`) — FIXED
- [BLOCKING] Acceptance Criteria AC-1: required all three heroes in shipped data; DD-H06 / Content CN-6 ship War only at MVP — FIXED (scoped by batch)
- [RECOMMENDED] Detailed Design H-2: "first run forces War" was handed to Run Structure, which does not carry it (R2 checks only `is_hero_unlocked`) — moved to Open Questions; owner to place it in Run Structure or Meta Progression
- [RECOMMENDED] Detailed Design H-4: budget line "7 neutrals + 8 War cards" was wrong (7 War + 5 distinct neutrals); `neutral_lantern_bearer` is in no starter though Content stars it — FIXED in Heroes; Content ★ to review
- [RECOMMENDED] Acceptance Criteria AC-18: "renders the three states distinguishably" untestable — FIXED (retained screenshots + literal rejection code)
- [RECOMMENDED] Open Questions: OQ1/3/4/7 answered by card-effects, meta-progression (M2.1 `HeroDef.unlock`), reward-draft (`plan_tags`) and DD-T01 — FIXED; card-database CR-3 still lacks `unlock` on `HeroDef` (cross-GDD, card-database)
- [RECOMMENDED] Cross-References: "(undesigned)" / "(concurrent)" labels stale — FIXED
- [RECOMMENDED] Registry: `hero_war/decay/knowledge` `referenced_by` omit reward-draft.md, match-ui.md, run-ui.md and treasures.md, which all read heroes.md — registry correction for the orchestrator, not edited here
Reviewed-Content-Hash: design/gdd/heroes.md 05f08a354ba61f99cd5065bb307477be65a81e45
Reviewed-Content-Hash: design/registry/entities.yaml 3364fe83ab25b4e4e9cc1c97bce415b250230dba
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/card-effects.md 0400f04821c0448a478b87fb82ae42fc7eebc11d
Reviewed-Content-Hash: design/gdd/content.md ba2af38bd3bd5862e2967bd03c55081202282be3
Reviewed-Content-Hash: design/gdd/treasures.md fa73c76396acba6ea9f3a563094b89c4a81fde01
Reviewed-Content-Hash: design/gdd/card-database.md c5903c4c808a0d2b1cf124242ba10a0fb1ea0fef
Reviewed-Content-Hash: design/gdd/match-rules.md 4c45bb5b36e1b50b3b286a2f10ea13cd0b703eae
Reviewed-Content-Hash: design/gdd/meta-progression.md e1b2d83f2eee16edc639e9093cc89474ca40df94
Reviewed-Content-Hash: design/gdd/run-structure.md 3b61401b846ee41676c50c59cdd3b3bd2a0bc7da
Reviewed-Content-Hash: design/gdd/reward-draft.md 0e5e1e7eb5b5938fccfed201ee0752e90d01a7a0
Reviewed-Content-Hash: design/gdd/boss-ai.md d8bfbd6c083e9af0419efd46f2aeb86c98a6dfb6
Reviewed-Content-Hash: design/gdd/game-concept.md 942314097524c7e2f25ad786643fba0a8aa4a701
Reviewed-Content-Hash: design/gdd/systems-index.md 1a5454bb731d1a57ff78d52c6cb98ae3d49598fc
Reviewed-Content-Hash: design/design-decisions.md 96d205e052b6b069575e43201d735fb254843a13
Reviewed-Content-Hash: design/art/art-bible.md 1dd9cdde34eb11cc75938aaac8d5da5eca280f2b
