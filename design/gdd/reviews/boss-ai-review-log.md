# Review Log — design/gdd/boss-ai.md

## Review — 2026-11-03 — Verdict: NEEDS REVISION
Review mode: lean · Workflow: standard
Scope signal: L
Specialists: none (lean — single-session; independent reviewer, not the author)
Blocking items: 7 | Recommended: 6
Summary: A strong, implementable utility planner with the right determinism and telegraphing story, undermined by arithmetic in its own worked example (A11 would have failed against a correct implementation), a hidden-information hole (the AI was allowed to read the event log, which carries the player's `card_drawn.card_id`), a waiver of the repo's 2 ms/frame AI rule, and an op vocabulary that did not match the Card Effects GDD it claimed was still "planned". All seven blocking items were resolvable from the GDD, the registry, design-decisions.md and sibling GDDs, so they were fixed in place (REVISED note in the header); status should be In Review pending a clean re-review. No registry value conflicts found.
Prior verdict resolved: First review
Findings:
- [BLOCKING] Formulas F1 / Acceptance Criteria A11: worked example used w_mana 1.5 (tempo) for an aggro boss, ignored the attacker's own damage, the Taunt multiplier and f_card; A11 asserted the wrong scores — recomputed (2.45 / 1.87) and A11 updated. FIXED
- [BLOCKING] Detailed Design C1.3 / A4: "may read the event log so far" leaked `card_drawn.card_id` (rng-event-log catalogue) — restricted to public events, `aoe_seen` sourced from `card_played`, A4 now draws the decoy through the engine and adds a hand-swap determinism check. FIXED
- [BLOCKING] Detailed Design C1.5 / Game Feel: GDD waived `.claude/rules/ai-code.md` 2 ms/frame for the planner (50 ms synchronous on the main thread) — now off-main-thread or time-sliced (mechanism by ADR, NOT SOURCEABLE in engine reference), new A30. FIXED
- [BLOCKING] Detailed Design C6 / F9 / Dependencies: `op_values` keys `damage_all`, `add_mana`, `equip_weapon` and the `targeting.mode`, `position_sensitive`, `aoe`, `synergy_tags` annotations do not exist in card-effects.md (which exists, contrary to "planned") — keys realigned to Card Effects C5 names, annotations derived from C3 selectors / C2 triggers, C7 handles `kind: choose_one`. FIXED
- [BLOCKING] Formulas F9 vs Game Feel / Visual / Match UI: `intent_banner_s` was 1.2 s in F9 and 0.3 s everywhere else — set to 0.3 with a separate `plan_changed_s` 1.2; Tuning Knobs row added. FIXED
- [BLOCKING] Acceptance Criteria A6 / A7: "any band's profile" undefined for `lethal_search = off`; "not guaranteed" untestable — rewritten as mode assertions. FIXED
- [BLOCKING] Detailed Design C2 vs Edge Cases / A24: pseudocode submitted `end_turn` on the shortcut path without the `ai_decision` A24 requires; plan steps not counted; defensive guard lacked F6's armour term. FIXED
- [RECOMMENDED] Formulas F7: "3,000 AI commands" assumed 100 boss turns; TURN_CAP is 100 global turns → 1,500; forecast cost was unbudgeted → folded into A22. FIXED
- [RECOMMENDED] States: no transition out of `Choosing` when the Choice was raised during the player's turn — row added. FIXED
- [RECOMMENDED] Open Questions / Interactions: stale notes — DD-T01 already lists `ai_profiles.json`; `clone()` carries `hooks` (match-rules C1/C2, treasures rule 6); rng-event-log 12a already catalogues the three diagnostic events — resolved or narrowed. FIXED
- [RECOMMENDED] Detailed Design C9: ai-code.md compliance now stated rule by rule, with group-AI and network rows marked not applicable. FIXED
- [RECOMMENDED] Cross-GDD: meta-progression.md and run-ui.md attribute a `telegraph_mode` player setting to Boss AI that this GDD never defined (meta-progression's own Interactions row withdraws it) — recorded as an owner question. OPEN (owner)
- [RECOMMENDED] Cross-GDD: rng-event-log catalogue lacks `ai_intent_committed` and `amount` on `ai_intent_shown`; systems-index describes Boss AI as "priority-scripted" (it is utility-scored); card-database.md cross-ref still says boss-ai.md "(planned)". OPEN (other GDDs / index)
- [ADVISORY] Player Fantasy section absent — advisory at `standard`; the Overview's second paragraph carries the intent.
Reviewed-Content-Hash: design/gdd/boss-ai.md d8bfbd6c083e9af0419efd46f2aeb86c98a6dfb6
Reviewed-Content-Hash: design/registry/entities.yaml 3364fe83ab25b4e4e9cc1c97bce415b250230dba
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/match-rules.md 4c45bb5b36e1b50b3b286a2f10ea13cd0b703eae
Reviewed-Content-Hash: design/gdd/card-effects.md 48ada791a708311cf24ecad74e50f27088e3cdab
Reviewed-Content-Hash: design/gdd/card-database.md c5903c4c808a0d2b1cf124242ba10a0fb1ea0fef
Reviewed-Content-Hash: design/gdd/rng-event-log.md cb06cb1680292fc0af6b80262894d273f27d1fa8
Reviewed-Content-Hash: design/gdd/match-ui.md b02c324e86580680866349677604432e43af4eef
Reviewed-Content-Hash: design/gdd/content.md ba2af38bd3bd5862e2967bd03c55081202282be3
Reviewed-Content-Hash: design/gdd/run-structure.md 3b61401b846ee41676c50c59cdd3b3bd2a0bc7da
Reviewed-Content-Hash: design/gdd/treasures.md fa73c76396acba6ea9f3a563094b89c4a81fde01
Reviewed-Content-Hash: design/gdd/meta-progression.md e1b2d83f2eee16edc639e9093cc89474ca40df94
Reviewed-Content-Hash: design/gdd/run-ui.md 40f3ae586d40370209dff143eadf78ad9a6a2f2b
Reviewed-Content-Hash: design/gdd/game-concept.md 942314097524c7e2f25ad786643fba0a8aa4a701
Reviewed-Content-Hash: design/design-decisions.md 96d205e052b6b069575e43201d735fb254843a13
Reviewed-Content-Hash: .claude/rules/ai-code.md 2c50b3bc673906ae6914b35ef0ad4d4a91f38d24

## Review — 2026-11-03 — Verdict: APPROVED
Review mode: lean · Workflow: standard
Scope signal: L
Specialists: none (lean — single-session; independent re-reviewer, not the author)
Blocking items: 0 | Recommended: 6
Summary: Re-review after the first-review revisions and the cross-review fixes. All seven prior blocking items hold (F1 arithmetic re-derived to 2.45 / 1.87; hidden-information rule and A4; 2 ms/frame rule honoured via off-main-thread planner and A30; op vocabulary matches Card Effects C5; `intent_banner_s` 0.3 / `plan_changed_s` 1.2; A6/A7 testable; C2 emits `ai_decision` on every path). C-01, C-14, C-15, C-30, D-04 and D-07 are each applied as the cross-review specified and agree with DD-X03/DD-X07, rng-event-log rule 5 / 12a / §D, card-database CR-1 `config("ai_profiles")`, content B2 and AC-13. `.claude/rules/ai-code.md` is addressed rule by rule in C9 with the two inapplicable rules named. No registry value conflicts; all nine dependency GDDs exist and list Boss AI back. Remaining findings are precision nits that an implementer resolves from the cited owner GDD; none needs a design decision.
Prior verdict resolved: Yes
Findings:
- [RECOMMENDED] Detailed Design C8.1: forecast mana written as `mana_max + 1` — at `MAX_MANA` that is 11; write `mana_max_by_turn(t_side + 1)` (match-rules F4, which also now carries `crystal_bonus`).
- [RECOMMENDED] Detailed Design C3: the lethal-search sandbox names no stream; state that its nodes draw from the same `fork("sim_<turn>")` as C4 (A5's draw count already implies it).
- [RECOMMENDED] Edge Cases "ai_profiles.json is absent": says an embedded `default` copy is used at runtime; card-database L424–427 says load fails (`E_MISSING_FILE`) and the embedded copy is a test fixture only. Align to Card Database, the load-pipeline owner.
- [RECOMMENDED] Detailed Design C1.1 vs run-structure L428: constructor `(boss_def, resolved_profile, band, ai_stream, op_values)` here, `BossAI(ai_id, rng_ai, config("ai_profiles"))` there — say the ADR pins the signature and that Boss AI resolves the profile (C10) whichever form is chosen.
- [RECOMMENDED] Acceptance Criteria A8 / A16 / A7: "that or an equivalent order" → assert `player.hero.health ≤ 0` at turn end and first `ai_decision.mode = LETHAL`; state that `alternatives[]` includes the chosen candidate (A16's "2 alternatives" and the identical-options edge case both assume it); define `lethal_search: shallow_none` beside `lethal_search_exhausted` in C9's payload.
- [RECOMMENDED] Cross-GDD (rng-event-log §D L166): `ai_intent_shown` / `ai_intent_committed` payload rows lack `effective_mode`, which C8 and match-ui L182 both carry — catalogue addition, not a Boss AI change. Card-effects Dependencies row for Boss AI (L1053) still omits op names/selectors as consumed (low).
- [ADVISORY] Player Fantasy section absent — advisory at `standard`; the Overview's second paragraph carries the intent.
Reviewed-Content-Hash: design/gdd/boss-ai.md 346787f0550706b31047cb67b5356266e488440a
Reviewed-Content-Hash: design/registry/entities.yaml 1ee18bfb98f9c2349140eda37142a0e93a335c11
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/match-rules.md 54e7dae9ecc522fc57787bf4c65313364d74be3f
Reviewed-Content-Hash: design/gdd/card-effects.md 90b8b6e139e107e5a588cd760da49b3946a404bc
Reviewed-Content-Hash: design/gdd/card-database.md cd631beb882ec0fa4adb3b048671d05628993c49
Reviewed-Content-Hash: design/gdd/rng-event-log.md 43f509f1edb37d0cc3087908330f94dcc24185cb
Reviewed-Content-Hash: design/gdd/match-ui.md dbff3a5d072d175f5f8fe406ad9f2258df31077d
Reviewed-Content-Hash: design/gdd/content.md 9a4fabbfd9e515a5dd437ed7babbe949119da8ee
Reviewed-Content-Hash: design/gdd/run-structure.md 1485f9df6fb25ee9514c6a88385e8f88704f7603
Reviewed-Content-Hash: design/gdd/meta-progression.md 43936af8124347bad40ad7d52e1eda53d7ec5fcf
Reviewed-Content-Hash: design/gdd/game-concept.md c781025c5f2a71209b4de0976ab806d097b8f0b0
Reviewed-Content-Hash: design/gdd/systems-index.md b6cea95eef89f3f0015d0cd1ff03c7189442aceb
Reviewed-Content-Hash: design/gdd/gdd-cross-review-2026-11-03.md c735c9738a373e58a095ba1c942ee89f0de6685a
Reviewed-Content-Hash: design/design-decisions.md 7a7fd2f58edfa5bdefa2d9e376b809a4a529615f
Reviewed-Content-Hash: .claude/rules/ai-code.md 2c50b3bc673906ae6914b35ef0ad4d4a91f38d24
