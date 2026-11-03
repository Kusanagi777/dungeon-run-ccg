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

## Review — 2026-11-03 — Verdict: NEEDS REVISION
Review mode: lean · Workflow: standard
Scope signal: L
Specialists: none (lean mode — single-session analysis; `qa-lead`, `systems-designer`, `creative-director` not spawned)
Blocking items: 2 | Recommended: 1
Summary: Re-review after the first-review revisions and the cross-review fixes. C-03 (`PLAN_MAX` 7 in F2, Tuning Knobs, AC-3, H-4, OQ; Content keeps the `armour` tag), C-11 / DD-X02 (H-2, Interactions, Dependencies, OQ; run-structure, run-ui and game-concept agree) and C-30 (OQ rows on `refresh_hero_power` and `HeroDef.unlock` closed; both exist in match-rules / card-database) are all applied and verified against the sibling GDDs. All 8 sections present (6/6 required at `standard`); the whole-document registry search (74 lines) found no conflict; all ten dependency GDDs exist and the four previously one-sided dependents (Reward Draft, Run UI, Match UI, Treasures) now list Heroes. Two Acceptance Criteria asserted wrong or unsatisfiable results — AC-10 (Husk index after the dead minion's slot closes) and AC-16 (three heroes selectable on a fresh profile, contradicting AC-1's MVP-0 War-only batch) — both fixed in place from match-rules C10 and AC-1; no rule, formula or value changed. Document is In Review; a re-review decides Approved.
Prior verdict resolved: Yes — all 8 prior blockers closed (the open cross-GDD one, War 7 > `PLAN_MAX` 6, via cross-review C-03 option B)
Findings:
- [BLOCKING] Acceptance Criteria AC-10: asserted the Husk "at board index 1 (the dead minion's slot has closed up)" — with a single friendly 1/1 the Husk is summoned at index 1 during the pass and sits at index 0 after `minion_died` (match-rules C10 dense board) — FIXED
- [BLOCKING] Acceptance Criteria AC-16: "exactly the three launch heroes are selectable" fails at MVP-0 and Alpha-A under AC-1's batch scoping (DD-H06, Content CN-6) — FIXED (heroes present in the batch's `heroes.json`; locked state via a fixture hero)
- [RECOMMENDED] Edge Cases: `W_HERO_HEALTH` is named as a Content validator warning but appears in neither content.md's validator code list nor card-database.md — cross-GDD (Content adds the code, or Heroes drops the warning)
- [NICE-TO-HAVE] Player Fantasy: "a Spell Damage minion turns a 2-damage bolt into a 4" — one +1 minion makes it 3; "about a third of each starter is plan-shaped" is now 4–7 of 15 (27–47 %) after C-03
- [NICE-TO-HAVE] Detailed Design H-4: "Gain 2 Armour" vs Content's "Gain 2 Armor" — spelling only, Content's text is the shipped string
Reviewed-Content-Hash: design/gdd/heroes.md 2c76cf8115794dbf939f51317884d278d4561656
Reviewed-Content-Hash: design/registry/entities.yaml 1ee18bfb98f9c2349140eda37142a0e93a335c11
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/card-effects.md 90b8b6e139e107e5a588cd760da49b3946a404bc
Reviewed-Content-Hash: design/gdd/content.md 9a4fabbfd9e515a5dd437ed7babbe949119da8ee
Reviewed-Content-Hash: design/gdd/treasures.md 97a87411e8e8b1e2988f8eaf36cd4edbde227cee
Reviewed-Content-Hash: design/gdd/card-database.md cd631beb882ec0fa4adb3b048671d05628993c49
Reviewed-Content-Hash: design/gdd/match-rules.md 54e7dae9ecc522fc57787bf4c65313364d74be3f
Reviewed-Content-Hash: design/gdd/meta-progression.md 43936af8124347bad40ad7d52e1eda53d7ec5fcf
Reviewed-Content-Hash: design/gdd/run-structure.md 1485f9df6fb25ee9514c6a88385e8f88704f7603
Reviewed-Content-Hash: design/gdd/reward-draft.md 46e985b9b2915a99fd6a9d039ba420634cb0489b
Reviewed-Content-Hash: design/gdd/run-ui.md d9018ff2729512cf024dd40326853be715a806b4
Reviewed-Content-Hash: design/gdd/match-ui.md dbff3a5d072d175f5f8fe406ad9f2258df31077d
Reviewed-Content-Hash: design/gdd/boss-ai.md 346787f0550706b31047cb67b5356266e488440a
Reviewed-Content-Hash: design/gdd/game-concept.md c781025c5f2a71209b4de0976ab806d097b8f0b0
Reviewed-Content-Hash: design/gdd/systems-index.md b6cea95eef89f3f0015d0cd1ff03c7189442aceb
Reviewed-Content-Hash: design/gdd/gdd-cross-review-2026-11-03.md c735c9738a373e58a095ba1c942ee89f0de6685a
Reviewed-Content-Hash: design/design-decisions.md 7a7fd2f58edfa5bdefa2d9e376b809a4a529615f
Reviewed-Content-Hash: design/art/art-bible.md 1dd9cdde34eb11cc75938aaac8d5da5eca280f2b

## Review — 2026-11-03 — Verdict: APPROVED
Review mode: lean · Workflow: standard
Scope signal: L
Specialists: none (lean mode — single-session analysis; `qa-lead`, `systems-designer`, `creative-director` not spawned)
Blocking items: 0 | Recommended: 3
Summary: Third pass, independent reviewer. The document is byte-identical to the previous re-review's revised version; the registry and five sibling GDDs changed since, so every cross-document fact was re-verified rather than skipped. Both prior fixes hold: AC-10's index arithmetic follows match-rules C10 (summon at `board.size` during the pass, dense board after `minion_died`, Deathrattle after the death check — card-effects AC-43 asserts the same order), and AC-16's batch scoping matches Content CN-6 (MVP-0 `heroes.json` = `hero_war` only; Decay Alpha-A, Knowledge Alpha-B), run-ui U7 (panels built from the `HeroDef`s present, no locked row without locked data) and run-structure AC-23. All 8 sections present (6/6 required at `standard`, Formulas required and present); the whole-document registry search (63 lines) found no conflict; all eleven dependency GDDs exist and every dependent names Heroes; the sibling changes since the last pass (card-effects `effect_resolved.outcome` closed set, card-database `card_database.json`, reward-draft re-derived to War 7, DD-T04 wording, Content boss recipes / F5 exemptions, match-ui HUD geometry) touch no hero value or rule. Three recommended items remain, none blocking: AC-9 asserts `ops[1].values.branch`, a payload key card-effects never defines (its AC-43 asserts `ops[1].outcome == applied` instead); `W_HERO_HEALTH` is still in no validator code list; H-4's rationale calls `weapon_durability` a v2 op although card-effects moved it to v1 on 2026-11-03 (the conditional-draw text stands — Content agrees).
Prior verdict resolved: Yes — AC-10 and AC-16 verified against match-rules C10, Content CN-6, run-ui U7 and run-structure AC-23; no regression found
Findings:
- [RECOMMENDED] Acceptance Criteria AC-9: `effect_resolved.ops[1].values.branch == "then"` names a payload key card-effects' `effect_resolved` schema does not carry; rewrite to `ops[1].outcome == applied` (card-effects AC-43) or have Card Effects add `branch` to the `conditional` op's `values`
- [RECOMMENDED] Edge Cases: `W_HERO_HEALTH` is still absent from content.md's validator code list (CN-6 step 3) and from card-database.md — cross-GDD (Content adds the code, or Heroes drops the warning); carried from the previous pass
- [RECOMMENDED] Detailed Design H-4: "`weapon_durability` is a v2 op (card-effects C11)" is stale — card-effects moved it to v1 on 2026-11-03 (cross-review C-22); the redesign rationale should read "was provisional when redesigned; Content keeps the conditional draw"; no text or value changes
- [NICE-TO-HAVE] Acceptance Criteria AC-10: say "a single friendly 1/1 (board otherwise empty)" — the index-0 / index-1 assertion holds only for that fixture
- [NICE-TO-HAVE] Acceptance Criteria AC-18: cites `design/ux/hud.md`, which does not exist yet (the GDD's own UX flag schedules `/ux-design hud`); the three states are spelled out inline, so the AC is testable now
- [NICE-TO-HAVE] Player Fantasy: "a 2-damage bolt into a 4" (one +1 minion makes it 3) and "about a third of each starter" (4–7 of 15) — carried from the previous pass
Reviewed-Content-Hash: design/gdd/heroes.md 2c76cf8115794dbf939f51317884d278d4561656
Reviewed-Content-Hash: design/registry/entities.yaml c0b7b1c0ad84e2c548b1bb890c79073e397c259c
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/card-effects.md 0a434c1bcf30900536181fc057877a04832c766e
Reviewed-Content-Hash: design/gdd/content.md 0ebdda3190f417e6ae20c6444b24daed4e75bf2d
Reviewed-Content-Hash: design/gdd/treasures.md 97a87411e8e8b1e2988f8eaf36cd4edbde227cee
Reviewed-Content-Hash: design/gdd/card-database.md bf374f0a4c79940fe414c216246ea3cca7f195db
Reviewed-Content-Hash: design/gdd/match-rules.md 54e7dae9ecc522fc57787bf4c65313364d74be3f
Reviewed-Content-Hash: design/gdd/meta-progression.md 43936af8124347bad40ad7d52e1eda53d7ec5fcf
Reviewed-Content-Hash: design/gdd/run-structure.md 1485f9df6fb25ee9514c6a88385e8f88704f7603
Reviewed-Content-Hash: design/gdd/reward-draft.md fefe17c210dcc4fb1bd265441cf2355d0eb202e9
Reviewed-Content-Hash: design/gdd/run-ui.md d9018ff2729512cf024dd40326853be715a806b4
Reviewed-Content-Hash: design/gdd/match-ui.md 7ba3adcca78e4eb524e9927c901eee4d4bdeabdd
Reviewed-Content-Hash: design/gdd/boss-ai.md 346787f0550706b31047cb67b5356266e488440a
Reviewed-Content-Hash: design/gdd/game-concept.md c781025c5f2a71209b4de0976ab806d097b8f0b0
Reviewed-Content-Hash: design/gdd/systems-index.md b6cea95eef89f3f0015d0cd1ff03c7189442aceb
Reviewed-Content-Hash: design/design-decisions.md 6d7e7fac963fc62e7ff90a531df77e23e2eb0488
Reviewed-Content-Hash: design/art/art-bible.md 1dd9cdde34eb11cc75938aaac8d5da5eca280f2b
