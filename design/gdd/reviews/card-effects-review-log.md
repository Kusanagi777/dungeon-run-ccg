# Review Log — Card Effects (`design/gdd/card-effects.md`)

## Review — 2026-11-03 — Verdict: NEEDS REVISION
Review mode: lean · Workflow: full
Scope signal: XL
Specialists: none (lean mode — single-session review; specialist delegation skipped by configuration, not by omission)
Blocking items: 7 | Recommended: 6
Summary: Structurally complete (8/8 at `full`) and unusually thorough, but the resolver's step unit was ambiguous (one pass vs one step per primitive), which contradicted its own Edge Cases (dying `pending_destroy` minions "still in play" vs a `repeat` that finds `no_target` after a kill) and broke Heroes' Rot encoding; C11 rows 8/16/25 described hero powers that contradict the Heroes GDD and the registry (`hero_*.hero_power`, `decay_husk` 1/1, `war_whetstone_blade`); and event triggers on treasure/passive hosts without a hook binding (Grave Tithe, four Content boss passives) had no defined execution. All blocking items were resolvable from the sibling GDDs, DD rows and registry, so option [A] "Revise now" was taken: the GDD now carries a `REVISED 2026-11-03` note, C6.0 (step unit), `is_dying`, `adjacent of:`, `tag` on board minions, `owner.turns_taken`, `target` ref, counters in snapshots, hero-slot observers (C9), rewritten rows 8/16/25, new rows 44–46 and AC-43–46. Status after revision: In Review — a re-review decides Approved.
Prior verdict resolved: First review
Findings:
- [BLOCKING] Detailed Design C6 / Edge Cases: step unit undefined — "one effect, one pass" (C6.4) vs "each primitive is one step" (States, F6, C6.10); Edge Cases line 796 (pending_destroy targets read as alive) contradicted line 864 and AC-24 (killed minion gives `no_target`). FIXED: C6.0 — a pass is one C10 step, primitives are mutations, dying entities excluded from selectors, F6/C6.10/Edge Cases restated in those units.
- [BLOCKING] C11 rows 8, 16, 25 / Dependencies: hero powers "Sharpen / Sacrifice (2/2 Ghoul) / Insight: Deal 1 damage" contradict Heroes H-3 and registry (`hero_decay.hero_power: power_rot`, `decay_husk` 1/1, `war_whetstone_blade` 1/2; lines 480, 488, 497 pre-revision) while Dependencies claimed rows 1–25 carry the hero identities. FIXED: rows rewritten as Whetstone / Rot / Insight with registry token ids; Heroes' `branch`/`has_weapon`/`left_play`/`bind`/`enchant_card` mapped to v1 ops (`conditional`/`exists`/`is_dying`/`deck_top` + `buff cost`).
- [BLOCKING] C2 / C9: event triggers legal on treasure/passive hosts with no hook column (`on_minion_died`, `on_attack`, `on_play`, …) had no execution rule, though C9 only defined hook-step execution; Grave Tithe and Content bosses Bog Witch, Pyre Sergeant, Mirror Sage, Thornhide-style scopes depend on it. FIXED: hero-slot observer rule in C2/C9 (Treasures R-10 confirmed); treasure/passive sources always live; `once_per_turn`/counters keyed on treasure id.
- [BLOCKING] C3 / Edge Cases: `adjacent` defined as source-relative only, yet Edge Cases used it for "a minion and its neighbours" (which would be `E_FX_SELECTOR` on a spell). FIXED: `of: self|target|trigger_subject`.
- [BLOCKING] C3: `tag` predicate limited to cards/pools, but Content's `decay_husk_herder`, `decay_plague_of_rot` and Treasures' Plague Bell filter board minions by tag (R-3). FIXED: `tag`/`set` apply to board minions via the definition.
- [BLOCKING] C5 / C6.5: counters "die with the source" and were absent from the raise-time snapshot, so Content's Gravekeeper (`counter` read in its own Deathrattle) was unreadable. FIXED: counters in the snapshot; row 45 + AC-46.
- [BLOCKING] C4: `target` ref undefined when an op overrides `targets` (Content's Soul Tithe reads `target.cost` from a `mana` op). FIXED: `target` = the `chosen` entity, never rebound; per-target refs listed in the v2 table.
- [RECOMMENDED] C1 / C2 / C5: Treasures R-2 (condition on value triggers), R-6 (`owner.turns_taken`), R-13 (`scope.card` kind rule), `aura` on `owner_weapon` — applied in this revision; Treasures to close them.
- [RECOMMENDED] F6 / max_match_events: the claim "log cap cannot precede the step cap" was unit-confused; restated honestly (either cap ends the match with its reason).
- [RECOMMENDED] Cross-References: Heroes/Treasures/Boss AI/Match UI marked "(undesigned)" though all are Designed; Content row missing — fixed.
- [RECOMMENDED] C6.7 / Pillar 4: a second `once_per_turn` raise in one step is dropped with no event; consider a non-mutating `trigger_skipped{reason: once_per_turn}` diagnostic so the feed can explain the absence (left open — DD-T04 interpretation).
- [RECOMMENDED] Acceptance Criteria AC-37: "any 100-command scripted match" should name its fixture script (e.g. `tests/fixtures/replay_card_effects_100.json`) to be reproducible; AC-42 should name the reference machine or a relative budget.
- [RECOMMENDED] Game Feel ACs: "No playtester describes a Deathrattle cascade as 'a blur'" → "≤ 1 of 10 playtesters"; advisory section, not the AC section.
Needs owner / cross-GDD change (not edited here):
- Heroes: correct H-3 sketches (`targeting` field; the assumed death check between Rot's ops) and close its DSL open question — `/propagate-design-change`.
- Treasures: close R-2, R-3, R-6, R-10, R-13 and the `aura`-on-weapon question; R-1 (permanent `add_mana`) stays with Match Rules.
- Match Rules: confirm C4 End step 5 expiry covers `until_end_of_turn` enchantments on card instances (rows 25, 41); existing open asks on `targeting_spec` wording, enemy-side expiry and observer candidate order stand.
- RNG & Event Log: event-name drift (`healed`/`healing_applied`, etc.) — one catalogue must win.
- Registry: no value corrections needed; `decay_husk` and `war_whetstone_blade` `referenced_by: card-effects.md` are now accurate (the pre-revision GDD never named them).
- Systems index: set Card Effects to **In Review**; reconcile "six dependents" (five rows list it).
Reviewed-Content-Hash: design/gdd/card-effects.md 0400f04821c0448a478b87fb82ae42fc7eebc11d
Reviewed-Content-Hash: design/registry/entities.yaml 3364fe83ab25b4e4e9cc1c97bce415b250230dba
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/match-rules.md 4c45bb5b36e1b50b3b286a2f10ea13cd0b703eae
Reviewed-Content-Hash: design/gdd/heroes.md c08cca2638198b107222b0c7b5058c3ca86a17de
Reviewed-Content-Hash: design/gdd/treasures.md fa73c76396acba6ea9f3a563094b89c4a81fde01
Reviewed-Content-Hash: design/gdd/content.md ba2af38bd3bd5862e2967bd03c55081202282be3
Reviewed-Content-Hash: design/gdd/game-concept.md 942314097524c7e2f25ad786643fba0a8aa4a701
Reviewed-Content-Hash: design/gdd/systems-index.md 1a5454bb731d1a57ff78d52c6cb98ae3d49598fc
Reviewed-Content-Hash: design/design-decisions.md 96d205e052b6b069575e43201d735fb254843a13

## Review — 2026-11-03 — Verdict: NEEDS REVISION
Review mode: lean · Workflow: full
Scope signal: XL
Specialists: none (lean mode — single-session review; specialist delegation skipped by configuration, not by omission)
Blocking items: 4 | Recommended: 7
Summary: Re-review after the first-review revisions and the cross-review fixes. Structurally complete (8/8 at `full`); all seven prior blockers and every cross-review item naming card-effects (C-02, C-04, C-07/DD-X04 pairing, C-16a/b/c, C-22, C-25, V-35) are verifiably applied against the current match-rules, heroes, treasures, content, rng-event-log and match-ui texts; no registry value conflicts (77 matching lines checked). What remained were residues of the first blocker — three places still said "each primitive / each summon is one step" and AC-16 asserted a `trigger_resolved` between two pings of one `repeat` pass — plus a closed `outcome` enum that omitted three outcomes the GDD itself uses, a "hooks before card triggers throughout" claim contradicted by match-rules' End step (card `turn_end` triggers, then `on_turn_end` hooks), and a minion-played order row with no slot for `on_card_played` observers. All four were resolvable from the GDD and match-rules, so option [A] "Revise now" was taken; the document carries a `REVISED 2026-11-03 (re-review)` header note. Status after revision: In Review — no owner decision is outstanding; the next re-review should expect APPROVED unless the sibling GDDs change.
Prior verdict resolved: Yes
Findings:
- [BLOCKING] States and Transitions / Edge Cases / Acceptance Criteria: step-unit residues — `Resolving` row "each primitive is one step", recursion entry "each summon is one step", AC-16 "`trigger_resolved` between them" (two pings of one `repeat` pass), AC-09 loose order — all contradicted C6.0. FIXED: mutation vs pass wording; AC-09 explicit log order (`card_played`, `minion_summoned`, 2× `card_drawn`, `effect_resolved`, `minion_died`); AC-16 asserts exactly one `trigger_resolved` between the hook step and row 34's pass and none between its pings.
- [BLOCKING] Interactions (`effect_resolved` payload): closed `outcome` set lacked `partial` (C5 `summon`, Edge Cases), `fatigue` (Edge Cases draw entry) and `no_such_trigger` (C5 `retrigger`). FIXED: enum extended; comment marks it the closed set.
- [BLOCKING] C6.3 / C9 / Tuning Knobs `HOOKS_BEFORE_TRIGGERS`: "hooks before card triggers at the same point is the rule throughout" vs the table's own End-step row and match-rules C4 End steps 2–3 (card `turn_end` triggers first, then `on_turn_end` hooks). FIXED: End step named as the one exception in all three places; the table is authoritative over the shorthand.
- [BLOCKING] C6.3 minion/weapon-played row: card-hosted `on_card_played` observers (C2, fired for every card per match-rules trigger points) had no position, while the spell row placed them. FIXED: inserted after the `on_card_played` hooks, mirroring the spell row.
- [RECOMMENDED] C5 `mana` op: "`this_turn` is not used by v1 content" is false — Content's `decay_soul_tithe` (Alpha) uses it and C4 cites that card. Wording corrected here; Match Rules C5 still says the same and defines no temporary semantics — Open Question added (cross-GDD).
- [RECOMMENDED] C5 `discover` `then: cast`: a spell with `required` targeting has no target at resume time. Logged in Open Questions with a proposed validator rule (`E_FX_OP_TARGET` unless mode `none`); no v1 content uses it.
- [RECOMMENDED] C8.1: "Match UI opens the panel on `discover_offered`" overstated match-ui U3 (overlay opens when the second of the `choice_requested`/`discover_offered` pair is projected). Wording aligned; DD-X04 pairing itself is correctly stated in C6.6, C8.1 and Interactions.
- [RECOMMENDED] AC-37: named its replay fixture (`tests/fixtures/replay_card_effects_100.json`) so "any 100-command match" is reproducible. Applied.
- [RECOMMENDED] AC-42: "under 2 ms on the CI runner" still names no reference machine or relative budget — left open (needs a project-level performance baseline, not a GDD decision).
- [RECOMMENDED] AC-17: "row 9's Scarabs" → Husks (row 9 summons `decay_husk`). Applied.
- [RECOMMENDED] Registry hygiene (not value conflicts): `hook_fold` and `max_effects_per_treasure` list `design/gdd/card-effects.md` under `referenced_by` but the GDD never names either; `effect_static_step_limit` unit reads `steps` while the GDD now bounds mutations per pass. Report to the orchestrator; registry not edited.
Needs owner / cross-GDD change (not edited here):
- Match Rules: define `add_mana(…, temporary=true)` semantics and drop "not used by v1 content" (Soul Tithe), or Content retexts the card.
- Registry: `referenced_by` corrections above; optional `effect_static_step_limit` unit → `mutations per pass`.
- Systems index: keep Card Effects at **In Review** until the next re-review; the five-dependents count is now consistent.
Reviewed-Content-Hash: design/gdd/card-effects.md 0a434c1bcf30900536181fc057877a04832c766e
Reviewed-Content-Hash: design/registry/entities.yaml 1ee18bfb98f9c2349140eda37142a0e93a335c11
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/match-rules.md 54e7dae9ecc522fc57787bf4c65313364d74be3f
Reviewed-Content-Hash: design/gdd/heroes.md 2c76cf8115794dbf939f51317884d278d4561656
Reviewed-Content-Hash: design/gdd/treasures.md 97a87411e8e8b1e2988f8eaf36cd4edbde227cee
Reviewed-Content-Hash: design/gdd/content.md 9a4fabbfd9e515a5dd437ed7babbe949119da8ee
Reviewed-Content-Hash: design/gdd/rng-event-log.md dc7474f4995cf1741e5617c0b5938f18eee5fcc4
Reviewed-Content-Hash: design/gdd/card-database.md cb07e8c1f7ef7f6b7336e56e53bf6f1b6e11f06d
Reviewed-Content-Hash: design/gdd/boss-ai.md 346787f0550706b31047cb67b5356266e488440a
Reviewed-Content-Hash: design/gdd/match-ui.md dbff3a5d072d175f5f8fe406ad9f2258df31077d
Reviewed-Content-Hash: design/gdd/game-concept.md c781025c5f2a71209b4de0976ab806d097b8f0b0
Reviewed-Content-Hash: design/gdd/systems-index.md b6cea95eef89f3f0015d0cd1ff03c7189442aceb
Reviewed-Content-Hash: design/design-decisions.md 7a7fd2f58edfa5bdefa2d9e376b809a4a529615f
Reviewed-Content-Hash: design/gdd/gdd-cross-review-2026-11-03.md c735c9738a373e58a095ba1c942ee89f0de6685a

## Review — 2026-11-03 — Verdict: NEEDS REVISION
Review mode: lean · Workflow: full
Scope signal: XL
Specialists: none (lean mode — single-session review; specialist delegation skipped by configuration, not by omission)
Blocking items: 2 | Recommended: 6
Summary: Final re-review. The target was byte-identical to the previous (post-revision) receipt; the registry and ten sibling files had changed, so cross-document facts were re-verified and the whole document re-read (8/8 at `full`; 88 registry-term lines checked, no value conflicts). Match Rules C5 now defines `add_mana(side, n, temporary=true)` (temporary crystals, expiring at End step 5), Heroes H-3 carries rows 8/16/25 verbatim, and RNG & Event Log adopted direct draws — three Open Questions closed accordingly. Two residues of the first review's hero-slot-observer fix remained: the Edge Case "boss passive on the player's action" and AC-25 still asserted a hook-step order for row 37's `on_heal` passive, which C2/C9 make a boss-side observer resolving after the player's `on_heal` observers (a test written to AC-25 would fail an implementation written to C9); and F6's static bound had no rule for a non-literal `count`/`times` or for side-scoped/`adjacent` selectors, though Content's Raise Dead uses `count: {ref}`. Both were resolvable from the GDD and its Tuning Knobs, so option [A] "Revise now" was taken; the document carries a `REVISED 2026-11-03 (final re-review)` header note. Status after revision: In Review — nothing is outstanding with an owner or a sibling GDD; the next pass is a receipt check plus a read of the edited lines.
Prior verdict resolved: Yes
Findings:
- [BLOCKING] Edge Cases (Hooks and passives) / Acceptance Criteria AC-25: "whenever the player heals" boss passive described as a hook step resolving before player `on_heal` observers, contradicting C2 (no `on_heal` hook) and C9 (hero-slot observer, candidate order player side first). FIXED: both restated as the observer order (`healed` → minion `enchantment_applied` → passive `damage_dealt`, two `trigger_resolved{on_heal}`), with "hooks first" scoped to triggers that have a hook column.
- [BLOCKING] Formulas F6: `steps(op)` multiplied only `summon` by `count`, defined no `max_targets` for `adjacent` or side-scoped ops, and gave no value for a non-literal `count`/`n`/`times` (Content's `decay_raise_dead`). FIXED: `count(op)` for every leaf op, `max_targets(adjacent) = 2`, `max_targets(side-scoped) = 1`, ceilings `MAX_SUMMON_COUNT` / `MAX_REPEAT` / `HAND_SIZE` for value expressions.
- [RECOMMENDED] C5 `mana` row: still claimed match-rules C5 "says v1 content does not use" temporary mana — now false. Applied: row restates match-rules' temporary-crystal rule and names `decay_soul_tithe` and `neutral_treasure_map`; Open Question marked resolved (Match Rules chose crystals over the "`mana_current` only" proposal).
- [RECOMMENDED] C5 `summon`: default `position` undefined for a non-minion source (spell, hero power, treasure). Applied: `source_slot`/`right_of_source` resolve to `end`.
- [RECOMMENDED] AC-26: board layout unspecified, so row 27's adjacency to a lord was tester-dependent. Applied: `[row 26, row 26, vanilla 1/1, row 27]`, expected stats per minion.
- [RECOMMENDED] C10 / Open Questions: `then: cast` targeting gap (owned here) adopted as an `E_FX_OP_TARGET` case; question closed.
- [RECOMMENDED] C6.9 / Open Questions / Dependencies: RNG fork proposal and Heroes H-3 rows closed against the current sibling texts; Treasures dependency row names hero-slot observers alongside hook-bound triggers.
- [RECOMMENDED] AC-42: "under 2 ms on the CI runner" still names no reference machine or relative budget — left open (project-level performance baseline, not a GDD decision).
Needs owner / cross-GDD change (not edited here):
- Registry (hygiene, not value conflicts): `hook_fold` and `max_effects_per_treasure` list `design/gdd/card-effects.md` under `referenced_by` though the GDD never names them; `effect_static_step_limit` unit `steps` → `mutations per pass` (F6 bounds mutations).
- Systems index: Card Effects stays **In Review** until a re-review reads the edited lines; dependents count (five) is consistent.
- No sibling GDD needs a change for this GDD to be approved.
Reviewed-Content-Hash: design/gdd/card-effects.md 3ad4c403613cbe3ea2799f6e4df4ca8861ceaae1
Reviewed-Content-Hash: design/registry/entities.yaml 15a5aaa3931e9b5af78e87f742bfa2de9e0fa8d0
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/match-rules.md 7af4351b32a419195d38bf274c2a68b9c63aa804
Reviewed-Content-Hash: design/gdd/heroes.md 3e9c89b4cd87b8fde225762af7e169fcf2fed1dd
Reviewed-Content-Hash: design/gdd/treasures.md b50806cc8b2b5117b0064b934122be5ecaced4ad
Reviewed-Content-Hash: design/gdd/content.md dc95b8e96ca465d68b1835307341807ef8ffe3a8
Reviewed-Content-Hash: design/gdd/rng-event-log.md 6981bf37934cae2e74ed37a23eb349fb62dcbf5b
Reviewed-Content-Hash: design/gdd/card-database.md d04095c7f44e5d930ba3c23c4f88024736fdc6a8
Reviewed-Content-Hash: design/gdd/boss-ai.md 2c2bedbaa6ff558777d2af7d81b3b91c5783af82
Reviewed-Content-Hash: design/gdd/match-ui.md e2bcccad61083401a8c8dbdbd0a4068afc64e3d7
Reviewed-Content-Hash: design/gdd/game-concept.md e2b0c05d2b9729099fdcc47c9c96c7ef6724e61f
Reviewed-Content-Hash: design/gdd/systems-index.md a20a2191f2853e48591ac1eec0417f089077f7c6
Reviewed-Content-Hash: design/design-decisions.md 914fb4ab3d19c6957bf65dcff93bb6804f664708
Reviewed-Content-Hash: design/gdd/gdd-cross-review-2026-11-03.md c735c9738a373e58a095ba1c942ee89f0de6685a
