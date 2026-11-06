# Review Log — RNG & Event Log

## Review — 2026-11-03 — Verdict: NEEDS REVISION
Review mode: lean · Workflow: standard
Scope signal: L
Specialists: none (lean mode — single-session review; no `systems-designer` / `qa-lead` pass)
Blocking items: 6 | Recommended: 5
Summary: The determinism design is sound and every worked example in F1/F2 verifies numerically, but the document had drifted from the nine sibling GDDs written after it: F4 bounded `randi_range` spans to 65,536 while `weighted_pick` was allowed totals to 2^31−1 through that same call; rule 19 computed `damage_by_card` from `damage_dealt.source_id`/`amount`, fields Match Rules does not emit; the v1 catalogue named Match Rules' events differently from match-rules C15, mis-assigned `treasure_granted`, and omitted Boss AI's diagnostic events while the diagnostic-channel question assigned to this GDD stayed unanswered; the retry edge case contradicted run-structure R8.3; Dependencies and Cross-References still said no sibling GDD existed. All blocking items were resolvable from the registry, DD rows and siblings, so option [A] Revise now was taken; the GDD was revised in place and should be marked In Review pending re-review.
Prior verdict resolved: First review
Findings:
- [BLOCKING] Formulas F4: `weighted_pick` total range 1–2^31−1 contradicts `randi_range` span bound ≤ 65,536 — fixed: total bounded to 65,536, Edge Cases assert added
- [BLOCKING] Detailed Design rule 19 / Acceptance Criteria: `damage_by_card` read `source_id`/`amount`; Match Rules C15 emits `source`/`dealt` — fixed: rule, catalogue row and AC rewritten to the owner's fields
- [BLOCKING] Detailed Design §D catalogue: event names and owners disagreed with match-rules C15, run-structure R5.4, reward-draft D11, treasures R-9, boss-ai C10 — fixed: realigned; owner tables declared authoritative
- [BLOCKING] Detailed Design rule 12: diagnostic events (`command_rejected`, `ai_decision`) had no defined channel (match-rules OQ assigned here) — fixed: rule 12a, same log, `diagnostic: true`
- [BLOCKING] Edge Cases: floor retry via `fork("retry_<n>")` contradicted run-structure R8.3 (same streams at `draws = 0`) — fixed: follows Run Structure, which owns the policy
- [BLOCKING] Dependencies / Cross-References: "none of these GDDs exists yet", "(not yet authored)", stale bidirectional claim about systems-index — fixed: current state recorded, index verified
- [RECOMMENDED] Detailed Design rule 18: archive key `<run_seed_hex>` would be overwritten by a replayed seed — adopted `run_id` per run-structure / meta-progression
- [RECOMMENDED] Interactions: Card Effects per-effect fork no longer matches card-effects C6.9 direct draws — row amended; Boss AI fork use documented
- [RECOMMENDED] Tuning Knobs: absent (advisory at standard) although three knobs exist — section added with safe ranges
- [RECOMMENDED] Formulas F5 vs Acceptance Criteria: "sub-millisecond" vs "< 5 ms" for 10,000-draw restore — aligned to 5 ms
- [RECOMMENDED] Acceptance Criteria: AC-1 named no API call, AC-3 was conditional on GDDs "once they exist" — rewritten as executable tests
- [CROSS-GDD] Match Rules Interactions names the stream API `shuffle/pick/range` and `MatchConfig.seed`; should adopt F4 names and stream handles (Open Question 8)
- [CROSS-GDD] DD-T03 lists streams `run, match, draft`; GDD uses `match_<floor>`, `draft_<floor>`, `ai_<floor>` — register row wording to update via owner
- [CROSS-GDD] run-ui cites the envelope as `{seq, type, payload}`; should be `{seq, turn, type, payload, cause_seq}`
- [CROSS-GDD] boss-ai draw accounting (A-tests) must include one parent draw per new fork label (rule 5)
Reviewed-Content-Hash: design/gdd/rng-event-log.md cb06cb1680292fc0af6b80262894d273f27d1fa8
Reviewed-Content-Hash: design/registry/entities.yaml 3364fe83ab25b4e4e9cc1c97bce415b250230dba
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md 942314097524c7e2f25ad786643fba0a8aa4a701
Reviewed-Content-Hash: design/design-decisions.md 96d205e052b6b069575e43201d735fb254843a13
Reviewed-Content-Hash: design/gdd/match-rules.md ea6637fc9cbd619475b9bd73704794286bd90c2e
Reviewed-Content-Hash: design/gdd/card-effects.md 06d1a1c86d2da73767a5865e64187943b8849dd6
Reviewed-Content-Hash: design/gdd/boss-ai.md 494058ed4e0f53de4a41b7e5613c86537dd01d71
Reviewed-Content-Hash: design/gdd/run-structure.md 3b469d46dc3f6ab03659641221f32bd6899abac5
Reviewed-Content-Hash: design/gdd/reward-draft.md 12367663fc15a5201ffa2d4c2f64234d11c9fe1b
Reviewed-Content-Hash: design/gdd/treasures.md c37de4e7647527f2086ddbdb5b1b21d514518f59
Reviewed-Content-Hash: design/gdd/match-ui.md 6645f862cbd413853a0afdec2f3ccf775e811547
Reviewed-Content-Hash: design/gdd/run-ui.md 8d242eaafec4a3b0db63f3db3c65cd4771d3d120
Reviewed-Content-Hash: design/gdd/meta-progression.md bdfd4ad9111612ebe5d33596746caadfa5dc873f
Reviewed-Content-Hash: design/gdd/systems-index.md 1a5454bb731d1a57ff78d52c6cb98ae3d49598fc

## Follow-up Review — 2026-11-03 — Verdict: NEEDS REVISION
Review mode: lean · Workflow: standard
Scope signal: L
Specialists: none (lean mode — single-session review; no `systems-designer` / `qa-lead` pass)
Blocking items: 3 | Recommended: 5
Summary: Re-review after the first revision and the cross-review fixes. All six prior blockers and cross-review C-09 / C-05 are verified applied, and the siblings now cite this GDD correctly (match-rules F4 names and rule 12a, run-ui envelope, boss-ai fork draws). Formulas, edge cases, dependency graph (10/10 on disk) and registry values are clean; every acceptance criterion is executable. What remained was catalogue drift against owner tables that moved after the last pass: `run_ended.abandon_reason` carried an invented `player/system` enum against run-structure R6's `player | data_version_mismatch | save_corrupt`; `match_ended` used `winner_side` and a truncated `reason` enum against match-rules C14; the `ai_intent_*` rows omitted `effective_mode`, which DD-X03 and boss-ai C8.4 require. All were resolvable from the owner GDDs and DD rows, so option [A] Revise now was taken; the GDD was revised in place and should be marked In Review pending re-review.
Prior verdict resolved: Yes
Findings:
- [BLOCKING] Detailed Design §D catalogue `run_ended`: `abandon_reason (player/system)` contradicts run-structure R6 / meta-progression M7 enum — fixed: owner enum, `floor_reached`, `ended_by` added
- [BLOCKING] Detailed Design §D catalogue `match_ended`: `winner_side` and partial `reason` enum vs match-rules C14 `MatchResult` (`winner`, `event_cap`, `turn_cap`) — fixed: row mirrors C14
- [BLOCKING] Detailed Design §D catalogue `ai_intent_shown` / `ai_intent_committed`: `effective_mode` missing (DD-X03, boss-ai C8.4) — fixed
- [RECOMMENDED] Detailed Design §D catalogue `discover_offered` / `discover_picked`: lagged card-effects' payload (`effect_id`, `kind`, label keys, `picked_index`) — fixed
- [RECOMMENDED] Detailed Design §D catalogue / Interactions: owner-added types `deck_grew`, `run_warning` (run-structure R10), `counter_changed` (card-effects), `hook_install_skipped` (treasures) absent from the cross-system index — rows added
- [RECOMMENDED] Detailed Design rule 13: how the log learns `turn` was unstated although match-rules C15 says the log stamps it — `set_turn(n)` added
- [RECOMMENDED] Edge Cases `max_match_events`: "force `match_ended`" left the emitter ambiguous; match-rules Edge Cases says the engine emits it — wording aligned
- [RECOMMENDED] Open Questions 7: siblings now cite rule 12a — closed
- [CROSS-GDD] card-effects Open Questions (fork("effect_<id>") row) still "Open — proposed here" although this GDD's Interactions row was amended on the first revision — card-effects to close
- [CROSS-GDD] run-structure R10 `run_warning` records no mutation; per rule 12a it should carry `diagnostic: true` — Run Structure to confirm or state an exception
- [CROSS-GDD] systems-index Recommended Design Order row 2 scores RNG & Event Log `S`; two reviews score it `L` (7 formulas, 10 dependents, one ADR) — index to update
- [CROSS-GDD] DD-T04 still reads `{seq, type, payload}`; this GDD extends it to `{seq, turn, type, payload, cause_seq}` and run-ui / match-ui / match-rules adopted the five-field form — register row wording to update via owner
Reviewed-Content-Hash: design/gdd/rng-event-log.md dc7474f4995cf1741e5617c0b5938f18eee5fcc4
Reviewed-Content-Hash: design/registry/entities.yaml 1ee18bfb98f9c2349140eda37142a0e93a335c11
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md c781025c5f2a71209b4de0976ab806d097b8f0b0
Reviewed-Content-Hash: design/design-decisions.md 7a7fd2f58edfa5bdefa2d9e376b809a4a529615f
Reviewed-Content-Hash: design/gdd/match-rules.md 54e7dae9ecc522fc57787bf4c65313364d74be3f
Reviewed-Content-Hash: design/gdd/card-effects.md 90b8b6e139e107e5a588cd760da49b3946a404bc
Reviewed-Content-Hash: design/gdd/boss-ai.md 346787f0550706b31047cb67b5356266e488440a
Reviewed-Content-Hash: design/gdd/run-structure.md 1485f9df6fb25ee9514c6a88385e8f88704f7603
Reviewed-Content-Hash: design/gdd/reward-draft.md 46e985b9b2915a99fd6a9d039ba420634cb0489b
Reviewed-Content-Hash: design/gdd/treasures.md 97a87411e8e8b1e2988f8eaf36cd4edbde227cee
Reviewed-Content-Hash: design/gdd/match-ui.md dbff3a5d072d175f5f8fe406ad9f2258df31077d
Reviewed-Content-Hash: design/gdd/run-ui.md d9018ff2729512cf024dd40326853be715a806b4
Reviewed-Content-Hash: design/gdd/meta-progression.md 43936af8124347bad40ad7d52e1eda53d7ec5fcf
Reviewed-Content-Hash: design/gdd/systems-index.md b6cea95eef89f3f0015d0cd1ff03c7189442aceb
Reviewed-Content-Hash: design/gdd/gdd-cross-review-2026-11-03.md c735c9738a373e58a095ba1c942ee89f0de6685a

## Review — 2026-11-03 — Verdict: APPROVED
Review mode: lean · Workflow: standard
Scope signal: L
Specialists: none (lean mode — single-session review; no `systems-designer` / `qa-lead` pass)
Blocking items: 0 | Recommended: 3
Summary: Third pass; the target document is byte-identical to the revised version of the second pass and four stamped cross-documents changed (registry, design-decisions, card-effects, reward-draft), so every catalogue row was re-verified against its owner. The three in-place fixes hold: `run_ended` carries Run Structure's R1/R6 `abandon_reason` enum with `floor_reached` and `ended_by`; `match_ended` is match-rules C14's `MatchResult` verbatim (`winner`, full `reason` enum incl. `event_cap`); `ai_intent_shown` / `ai_intent_committed` match boss-ai C8.1–C8.2 field for field and the `effective_mode` formula is DD-X03's. The added rows (`discover_*`, `counter_changed`, `hook_install_skipped`, `deck_grew`, `run_warning`) match card-effects, treasures T3 and run-structure R10; every F1/F2 worked example re-verifies numerically; the dependency graph is 10/10 on disk; the registry search (≈25 terms, 50 lines) found no conflict; DD-T03 / DD-T04 now read this GDD's stream names and five-field envelope. Nothing regressed. What remains is additive: the owned `match_summary` row leaves `result` undefined and lacks the `reason`/`winner` its two consumers read, and the `draft_offered` flag enum lags reward-draft D11.
Prior verdict resolved: Yes
Findings:
- [RECOMMENDED] Detailed Design §D `match_summary` (owned here): `result` values undefined; run-structure R10 reads `reason` from it and meta-progression M7.2 tests `result == player` — define `result` as C14's `win | loss | fault` and add `winner`, `reason` (copied from `match_ended`)
- [RECOMMENDED] Detailed Design §D `draft_offered`: `flags[]` enum reads `short | pity_forced | universal_forced | coverage`; reward-draft D11 is `pity_forced | coverage_forced | universal_forced | universal_missing | reoffer | short`
- [RECOMMENDED] Formulas F7: `run_total_events` "reported in `run_ended` diagnostics" — `run_ended` is Run Structure's payload and carries no such field; state it as Σ `match_summary.event_count` or drop the clause
- [NICE-TO-HAVE] §D `run_ended`: fields are listed flat; R6 emits `run_ended{result, floors_cleared, total_turns, run_seed_hex}` with `result` = the R1 record (`outcome`, `abandon_reason`, `ended_by`, `floor_reached`) — note the nesting
- [NICE-TO-HAVE] Cross-References DD-T04 row: "this GDD extends the envelope" is moot now that DD-T04 reads the five-field form
- [CROSS-GDD] card-effects Open Questions `fork("effect_<id>")` row still "Open — proposed here" though this GDD's Interactions row was amended two passes ago; card-effects Cross-References cite a `minion_modified` catalogue row that does not exist (`enchantment_applied`) and describe `effect_resolved`'s catalogue row by its pre-realignment fields
- [CROSS-GDD] meta-progression M7.2 / F2 pseudo-code test `match_summary.result == player` — should read the `winner` field once the row above defines it
- [CROSS-GDD] run-structure R4 lists `seed` in `MatchResult` (C14 says the record carries no seed) and R3.2 still flags the `MatchConfig.seed` name as open (resolved by cross-review C-05)
- [CROSS-GDD] systems-index Recommended Design Order row 2 still scores RNG & Event Log `S`; three reviews score it `L`
Reviewed-Content-Hash: design/gdd/rng-event-log.md dc7474f4995cf1741e5617c0b5938f18eee5fcc4
Reviewed-Content-Hash: design/registry/entities.yaml c0b7b1c0ad84e2c548b1bb890c79073e397c259c
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: design/gdd/game-concept.md c781025c5f2a71209b4de0976ab806d097b8f0b0
Reviewed-Content-Hash: design/design-decisions.md 6d7e7fac963fc62e7ff90a531df77e23e2eb0488
Reviewed-Content-Hash: design/gdd/match-rules.md 54e7dae9ecc522fc57787bf4c65313364d74be3f
Reviewed-Content-Hash: design/gdd/card-effects.md 0a434c1bcf30900536181fc057877a04832c766e
Reviewed-Content-Hash: design/gdd/boss-ai.md 346787f0550706b31047cb67b5356266e488440a
Reviewed-Content-Hash: design/gdd/run-structure.md 1485f9df6fb25ee9514c6a88385e8f88704f7603
Reviewed-Content-Hash: design/gdd/reward-draft.md fefe17c210dcc4fb1bd265441cf2355d0eb202e9
Reviewed-Content-Hash: design/gdd/treasures.md 97a87411e8e8b1e2988f8eaf36cd4edbde227cee
Reviewed-Content-Hash: design/gdd/match-ui.md cd8dc9c6ed098bb2b6036957a1690f4c6c4556ea
Reviewed-Content-Hash: design/gdd/run-ui.md d9018ff2729512cf024dd40326853be715a806b4
Reviewed-Content-Hash: design/gdd/meta-progression.md 43936af8124347bad40ad7d52e1eda53d7ec5fcf
Reviewed-Content-Hash: design/gdd/systems-index.md b6cea95eef89f3f0015d0cd1ff03c7189442aceb
