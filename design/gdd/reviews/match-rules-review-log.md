# Review Log — Match Rules (`design/gdd/match-rules.md`)

## Review — 2026-11-03 — Verdict: NEEDS REVISION
Review mode: lean · Workflow: full
Scope signal: XL
Specialists: none (lean mode — no specialist agents; single-session adversarial review)
Blocking items: 7 | Recommended: 8
Summary: Structurally complete at the `full` tier (8/8 sections) and the strongest rules spec in the set, but it had drifted from three sibling GDDs that already agree with each other: `MatchConfig` carried a `seed` the engine "seeds the match stream" from (Run Structure R3 passes memoised streams and `boss.health`; RNG & Event Log forbids engine seeding; the GDD's own Interactions row said "never seeds"), and `resolution_overflow` was a boss win where Run Structure T9 and the log's `event_cap` make it a non-losing fault. Three acceptance criteria were unsatisfiable as written (AC-18 1/1 Windfury dies on swing one, AC-19 needs a second attack in one turn, AC-30's self-copy Deathrattle terminates at board full) and F8's k = 0.8 case contradicted itself. All blocking items were resolvable from the sibling GDDs, the registry and the DD rows, so option [A] Revise now was applied in-session; status should be In Review pending re-review.
Prior verdict resolved: First review
Findings:
- [BLOCKING] Detailed Design C3 / Interactions: `MatchConfig.seed` and "engine seeds the match stream" contradict Run Structure R3 (`rng_match`, `rng_ai`, `log`, `boss.health`), RNG & Event Log rule 3 and this GDD's own RNG row — fixed: config shape aligned, engine never seeds, boss health read from config
- [BLOCKING] Detailed Design C10/C14, States, Edge Cases: `resolution_overflow` = boss win contradicts Run Structure T9 (`result = fault`, floor not lost) and RNG & Event Log's forced `match_ended(result: fault)` — fixed: `result: win | loss | fault`, `winner: null` on fault, `event_cap` added
- [BLOCKING] Acceptance Criteria AC-18, AC-19, AC-30: unsatisfiable as written — fixed (2/5 Windfury attacker; second swing on the next turn; heal ping-pong fixture for overflow)
- [BLOCKING] Formulas F8: "k = 0.8 → n = 8 ... → 9" self-contradiction — fixed to n = 9 with the cumulative values shown
- [BLOCKING] Interactions primitive API: five primitives Card Effects and Heroes depend on (`remove_keyword`, `add_card_to_deck`, `modify_durability`, `refresh_hero_power`, `discard`) were absent while this GDD's own rule says they must exist here first — fixed: added with events
- [BLOCKING] Interactions hook table: `modify_heal` unclamped (a hook could turn a heal into damage), `modify_starting_hand_size` and `modify_max_attacks` unclamped (Treasures R-4/R-5) — fixed: clamps and `MAX_ATTACKS_CAP = 4` added, fold semantics stated
- [BLOCKING] Detailed Design C1/C9, Formulas F2: hero health written as a separate `health` field in C9/F2 but derived from `damage_taken` in C1 — fixed: unified on `damage_taken`
- [RECOMMENDED] Detailed Design C15: envelope lacked `turn` and `cause_seq` (RNG & Event Log rule 11) — fixed; event-name mismatches with the log catalogue and Card Effects (`mulligan_completed`, `mana_changed`, `weapon_broken`, `healing_applied`, `discover_offered`) need an owner decision — logged in Open Questions
- [RECOMMENDED] Detailed Design C1/F3: hero Windfury via enchantment (Content open question) and `modify_max_attacks` not reflected in C1 — fixed
- [RECOMMENDED] Detailed Design C2: `clone()` must carry the `HookRegistry` (Boss AI A20) and must not touch the live log/stream — fixed
- [RECOMMENDED] Formulas F2: `dealt ∈ [0, requested]` wrong when `modify_damage` raises the amount — fixed to `[0, amount]`
- [RECOMMENDED] Acceptance Criteria AC-39 "(sampled)" undefined; AC-40 wall-clock timing in the blocking unit suite violates the determinism rule — fixed (seeded 200-command sample; AC-40 moved to `tests/performance/`)
- [RECOMMENDED] Dependencies: claim that the systems index lists every downstream row was false for Heroes, Treasures, Content — sentence corrected; index rows 6, 9, 13 need "Match Rules" added (orchestrator)
- [RECOMMENDED] Open Questions: boss-mulligan row closed by Boss AI C11 and `match_rules.json` row resolved by DD-T01 — updated; DD-M11 wording ("after the action completes" vs per-step death checks) raised for the owner
- [RECOMMENDED] Cross-GDD, not fixed here: Heroes line 213 uses rejection code `INSUFFICIENT_MANA` — this GDD's closed set says `NOT_ENOUGH_MANA`
Reviewed-Content-Hash: design/gdd/match-rules.md 4c45bb5b36e1b50b3b286a2f10ea13cd0b703eae
Reviewed-Content-Hash: design/registry/entities.yaml 3364fe83ab25b4e4e9cc1c97bce415b250230dba
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md 942314097524c7e2f25ad786643fba0a8aa4a701
Reviewed-Content-Hash: design/design-decisions.md 96d205e052b6b069575e43201d735fb254843a13
Reviewed-Content-Hash: design/gdd/run-structure.md 3b61401b846ee41676c50c59cdd3b3bd2a0bc7da
Reviewed-Content-Hash: design/gdd/rng-event-log.md cb06cb1680292fc0af6b80262894d273f27d1fa8
Reviewed-Content-Hash: design/gdd/card-effects.md 06d1a1c86d2da73767a5865e64187943b8849dd6
Reviewed-Content-Hash: design/gdd/boss-ai.md 494058ed4e0f53de4a41b7e5613c86537dd01d71
Reviewed-Content-Hash: design/gdd/treasures.md fa73c76396acba6ea9f3a563094b89c4a81fde01
Reviewed-Content-Hash: design/gdd/heroes.md 50129f93679a9dfa2153049499b8c646a476d1f9
Reviewed-Content-Hash: design/gdd/content.md 3e5e568fada0126b6e7f2685c4afe86211dca3e6
Reviewed-Content-Hash: design/gdd/match-ui.md 6645f862cbd413853a0afdec2f3ccf775e811547
Reviewed-Content-Hash: design/gdd/systems-index.md 1a5454bb731d1a57ff78d52c6cb98ae3d49598fc
