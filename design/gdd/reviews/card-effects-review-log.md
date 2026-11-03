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
