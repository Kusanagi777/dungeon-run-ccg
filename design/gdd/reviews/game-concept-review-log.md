# Review Log — design/gdd/game-concept.md

## Review — 2026-11-03 — Verdict: NEEDS REVISION
Review mode: lean · Workflow: standard
Scope signal: XL
Specialists: none (lean — single-session; independent reviewer, not the author)
Blocking items: 6 | Recommended: 5
Summary: Target is the game-concept document, so the 8-section GDD checklist does not apply (`gdd-structure-check.sh` reports all 8 ABSENT by design); validated instead against the concept template's 16 sections — all present with content — and the Systems Design gate's quality checks (core loop described at four time scales; target audience and player profile identified; Visual Identity Anchor has a one-line rule and 3 supporting principles with design tests; 4 pillars with design tests plus 4 anti-pillars): all pass. The concept was written before the 13 system GDDs and had drifted from the decisions register and the GDDs on six cross-document facts: treasure drafts framed as either/or with bundles (DD-R04/R05 make them additive on floors 1, 3, 5; "up to seven drafts" is 7 + 3), MVP boss pool 4 across two bands (DD-H06 / D-06: 5 across three, 3/1/1, for a 4-floor run), MVP card and bundle counts missing the 10 boss-only cards and 10 bundles, "~30 bundles" (DD-H05: 36), Scope Tier rows not matching content.md CN-1, and floor-1 bosses described as vanilla decks (Pillar 2 and content.md CN-3 give every band-1 boss a passive). All six were resolvable from design-decisions.md, the registry and the GDDs and were fixed in place; Status set to Under Review pending a clean re-review. No registry value conflicts remain: hero health 30, 15-card starters, 7-minion board, 10-card hand, 10 mana, 16 bosses 6/6/4, 20 treasures, 36 bundles, unlock heroes Fortune/Order/Shadow and the DD-X02 pre-select all agree.
Prior verdict resolved: First review
Findings:
- [BLOCKING] Elevator Pitch / Core Mechanics 4 / Core Loop (short-term, session): bundle *or* treasure after a win, "up to seven drafts" — DD-R04/R05 and reward-draft.md: a bundle after every win on floors 1–7 and a treasure as well on floors 1, 3, 5 (treasure first); 7 bundle + 3 treasure drafts. FIXED
- [BLOCKING] MVP Definition item 3: "4 bosses across two bands" — DD-H06 / cross-review D-06 / content.md CN-1: 5 bosses 3/1/1 (one spare band-1 boss) for a 4-floor gauntlet (`floors_per_run` 4, `band_split` 2/1/1). FIXED
- [BLOCKING] MVP Definition items 2 and 5: ~40 cards and treasures only — DD-H06 also ships 10 boss-only cards and 10 bundles (8 War + 2 neutral). FIXED
- [BLOCKING] Technical Considerations / Content Volume: "~30 bundles" — DD-H05: 36 (8 per hero + 12 neutral); 32 boss-only cards were unlisted. FIXED
- [BLOCKING] Scope Tiers: MVP row 4 bosses; VS row lacked its 9-boss pool (4/3/2), 18 boss-only cards and 16 bundles; Alpha row lacked 36 bundles — aligned to content.md CN-1. FIXED
- [BLOCKING] Flow State Design / Onboarding: "floor 1 bosses are vanilla minion decks" contradicted Pillar 2 and content.md CN-3 (every band-1 boss is a teaching boss with one simple telegraphed passive over a mostly-vanilla deck). FIXED
- [RECOMMENDED] Risks / Open Questions: the three listed questions were all resolved (DD-R05, DD-R02, DD-M05) — moved to a Resolved list with DD-H06 and DD-X02; the genuinely open items now listed: the "~8 hours to see most content" claim vs run-structure F6 `p_victory ≈ 3.3 %` (measure at first playtest, cross-review 2026-11-03), owner confirmation of the "Torchlit Ledger" direction (AD-CONCEPT-VISUAL and AD-ART-BIBLE both skipped), and hero display names as placeholders (heroes.md). FIXED (owner items remain OPEN)
- [RECOMMENDED] MDA / Fantasy row: hero display names Halvard, Mother Wythe, Archivist Ilse (registry `hero_war/decay/knowledge`, heroes.md H-3) were absent from the concept — added once, marked placeholder. FIXED
- [RECOMMENDED] Core Identity / Session Length: 30–45 min annotated with run-structure F5's model (victory ≈ 40 min, median run ≈ 22 min) so the two documents visibly agree. FIXED
- [RECOMMENDED] Next Steps: `/art-bible` (sections 1–4 exist, Draft), `/map-systems` (13 systems) and `/design-system` (13 GDDs) were unticked though done — ticked. FIXED
- [RECOMMENDED] Cross-GDD (not edited): systems-index.md L85 and L109 still say "4 bosses" at MVP and L188 "priority scripts" for Boss AI (utility-scored); content.md L384 says DD-H06 "still reads 4 bosses" though DD-H06 now reads 5. OPEN (other files)
- [ADVISORY] Status reads Under Review, not Approved: the revisions were applied by the reviewer in session; a clean re-review (or the owner) decides Approved. Owner decisions outstanding: Torchlit Ledger confirmation, hero names, the 8-hour content claim.
Reviewed-Content-Hash: design/gdd/game-concept.md e2b0c05d2b9729099fdcc47c9c96c7ef6724e61f
Reviewed-Content-Hash: design/registry/entities.yaml 76f479bf5a4270db81c0d82a5eb86ee4c5c9e227
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/design-decisions.md 914fb4ab3d19c6957bf65dcff93bb6804f664708
Reviewed-Content-Hash: design/gdd/systems-index.md a20a2191f2853e48591ac1eec0417f089077f7c6
Reviewed-Content-Hash: design/gdd/content.md dc95b8e96ca465d68b1835307341807ef8ffe3a8
Reviewed-Content-Hash: design/gdd/run-structure.md f89d6a98f6981671324f9a0c49708df0d1847787
Reviewed-Content-Hash: design/gdd/reward-draft.md a7efa9bae59c93827f73ff208438d3131a6de8bb
Reviewed-Content-Hash: design/gdd/heroes.md 3e9c89b4cd87b8fde225762af7e169fcf2fed1dd
Reviewed-Content-Hash: design/gdd/treasures.md b50806cc8b2b5117b0064b934122be5ecaced4ad
Reviewed-Content-Hash: design/gdd/meta-progression.md 878962538feb2a76598643d4ce90adc4f436ba55
Reviewed-Content-Hash: design/gdd/boss-ai.md 2c2bedbaa6ff558777d2af7d81b3b91c5783af82
Reviewed-Content-Hash: design/gdd/match-ui.md e2bcccad61083401a8c8dbdbd0a4068afc64e3d7
Reviewed-Content-Hash: design/art/art-bible.md 1dd9cdde34eb11cc75938aaac8d5da5eca280f2b
Reviewed-Content-Hash: design/gdd/gdd-cross-review-2026-11-03.md c735c9738a373e58a095ba1c942ee89f0de6685a
Reviewed-Content-Hash: .claude/docs/templates/game-concept.md 3a778a5419100a80903af31d0de043fc0acf184d
Reviewed-Content-Hash: .claude/skills/gate-check/references/gate-systems-design.md c1dcdfbaab49b94176f8804304bfecbd98936e7e
