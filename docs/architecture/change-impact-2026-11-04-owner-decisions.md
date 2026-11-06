# Change Impact Report: owner decisions DD-X19 … DD-X24

`/propagate-design-change`, run by hand 2026-11-04 once per changed GDD
(`workflow: standard`; match-rules and card-effects pinned `full`;
`review_mode: lean`; owner standing approval for DD-X19 … DD-X24, so Phase 7
resolutions were taken without questions and are recorded below).
TD-CHANGE-IMPACT skipped — Lean mode (every section).

This pass edits docs and stories only. Code, tests and JSON data that the
decisions change are listed under each section's **Sprint 5** line.

## DD-X19 — rng-event-log.md: event-log append budget 50 → 80 ms

### Change Summary
Changed sections:
- Acceptance Criteria (Performance): 10,000 appends + `events_since(0)` under **80 ms** headless (was 50 ms).

Unchanged: every rule, formula, edge case and the `restore()` 5 ms budget.

Key changes affecting architecture: the budget ADR-0003 quotes (Context, Validation Criteria, Performance Implications).

Downstream GDDs to re-check: none — the budget is not a registry entity (`design/registry/entities.yaml` has no entry with this value).

### ADRs in scope
Checked 7 ADRs (standard: Foundation ADR-0001, 0002, 0003, 0004, 0010, plus ADR-0006 and 0009, which name rng-event-log.md). 4 reference rng-event-log.md (ADR-0003, 0004, 0006, 0009); a search for the changed fact (50 ms append AC) hits ADR-0003 only.

#### ADR-0003: Seeded RNG Service and Event Log
Status: Needs Review → **Updated in place (erratum 2026-11-04, DD-X19)**
- Assumed: "10,000 appends + `events_since(0)` under 50 ms headless".
- Now: under 80 ms headless.
- Assessment: Decision 5 (per-append deep copy and freeze) holds; the owner chose to raise the budget rather than revisit the copy. Context, Validation Criteria and Performance Implications updated.

Still valid: ADR-0004, 0006, 0009 cite rng-event-log.md for other requirements (snapshot persistence, `ai_decision` events, `events_since` projection), not the budget. ADR-0001, 0002, 0010 do not cite the budget; they are out of scope for this fact, not verified unaffected.

### Other documents fixed
- `docs/architecture/control-manifest.md` Core Performance Guardrails `EventLog` row.
- `docs/architecture/requirements-traceability.md` Superseded Requirements row.
- Story `production/epics/rng-event-log/story-010-…` AC-2 and Completion Notes.
- Not edited: sprint plans and QA plans (dated records).

**Sprint 5:** `tests/performance/rng_event_log/rng_event_log_perf_test.gd` — `APPEND_BUDGET_USEC` 50_000 → 80_000, rename `test_ten_thousand_appends_and_events_since_zero_fit_in_50_ms`, header comment; re-run the perf job.

## DD-X20 — boss-ai.md and content.md: Boss AI values `add_counter`

### Change Summary for DD-X20
Changed sections:
- boss-ai C6: `add_counter` joins the op list with the row `add_counter 0.5` and its rationale (the floor of the table, with `armor`; the reading `damage` op already carries the payoff). `set_counter` stays unvalued.
- boss-ai F9: a note under the schema block. The decided row moves into the `op_values:` list together with `ai_profiles.json` (content story 010), because `boss_ai_profiles_data_test.gd` pins the shipped file to that list.
- content Edge Cases ("If a boss deck recipe cannot reach 30 ids"): the Gravekeeper use of the fallback is superseded.

Unchanged: every formula, weight, budget and every other op value. The CN-2 / CN-3 tables are unchanged, since they already list Gravekeeper.

Key changes affecting architecture: none structural. The op value table is data (`ai_profiles.json`), and its keys are already open to Card Effects C5 names.

Downstream GDDs to re-check: none in the registry (`op_values` has no entity). card-effects C11 row 45 is the reading op, unchanged.

### ADRs in scope for DD-X20
boss-ai.md (standard): 8 ADRs (Foundation 0001, 0002, 0003, 0004, 0010 plus 0005, 0006, 0007, 0008, which name boss-ai.md). content.md: ADR-0002 and 0003 name it. A search of `docs/architecture/` for `add_counter`, `op_values` values and `gravekeeper` finds `op_values` only as a constructor parameter name (ADR-0001, ADR-0008, architecture.md), with no row or value quoted.
- All in-scope ADRs: **Still Valid**. None quotes an op value or the Gravekeeper deferral, so no erratum is needed.

### Stories
- New: `production/epics/content/story-010-gravekeeper-returns-to-the-boss-decks.md` (Config/Data, S). It covers the row, the card, the Gatekeeper / Hollow King / Rot Warden swaps, and The Torchbearer's swap (story 001 dropped Gravekeeper for the same reason; flagged for the owner to strike if unwanted).
- Dated pointers added in content stories 001, 003 and 004. Story 009 now depends on 010. EPIC.md and `production/epics/index.md` show 10 stories.

**Sprint 5:** content story 010 (data: `ai_profiles.json`, `cards_neutral.json`, `bosses.json`; tests: `boss_ai_profiles_data_test.gd` 19 → 20, `content_mvp1_data_test.gd`, `content_batch0_data_test.gd`; boss-ai F9 list).

## DD-X21 — match-rules.md, card-effects.md, content.md: destroy then Silence

### Change Summary for DD-X21
Changed sections:
- match-rules C12 (Silence and Deathrattle rows): a minion already `pending_destroy` keeps its Deathrattles when Silenced, so destroy-then-silence **fires**. The old row read "not if Silenced before [it died]".
- match-rules C13 Silence step (2): the `pending_destroy` exception, with its reason (the mark is irrevocable; `health ≤ 0` is not protected, because a later op can heal it back). The snapshot is still the one taken at the death check.
- match-rules Edge Cases: two bullets (destroy-then-silence fires; lethal damage-then-silence does not). Acceptance Criteria: new AC-46.
- card-effects C5: `destroy` row note, plus the new content rule "Silence before destroy" (same target = same explicit reference).
- card-effects C10: `E_FX_OP` gains the destroy-before-silence order check. No new code: the C10 set is closed, as in DD-X16. Edge Cases: one bullet. AC-21: a dated note that it stands. New AC-47.
- content CN-6 step 6 (style guide): Silence is said and listed first.

Unchanged: C10 loop, DD-M11 order, raise-time snapshot (C6.5), the closed code set, both Tuning Knobs sections (parsed by the config-file tests).

Key changes affecting architecture: the `silence` primitive's behaviour on a `pending_destroy` minion. No API or event change: `silenced` and `trigger_queued` payloads are unchanged.

Downstream GDDs to re-check: none in the registry. boss-ai sandbox resolves through the same engine, so no text change is needed.

### ADRs in scope for DD-X21
match-rules and card-effects are pinned `full`, so all 11 ADRs are in scope. 7 name match-rules.md (0001, 0003, 0005, 0006, 0007, 0008, 0009); 3 name card-effects.md (0002, 0005, 0007); content.md is named by 0002 and 0003. A search of `docs/architecture/` for Silence / Deathrattle / `pending_destroy` rules finds only ADR-0007's responder rule ("source live, not silenced"). That rule still holds: a queued instance resolves, and the change is in what Silence removes. ADR-0007's closed `E_FX_*` list is unchanged.
- All 11: **Still Valid**. No erratum: no ADR quotes the old C12 sentence.

### Shipped data checked (read-only)
`assets/data/cards_*.json`, `bosses.json`, `treasures.json`, `hero_powers.json`: **no card destroys and silences one target**. The only `destroy` is `war_headsman` and the only `silence` is `neutral_hush_owl`. No planned card in content CN-2 / CN-3 does both.

### Stories for DD-X21
- `production/epics/card-effects/story-009-…`: AC-21 stands; match-rules AC-46 and the `silence` primitive change added to scope and Files. The sprint-4 blocker is cleared in `production/sprint-status.yaml`.
- New `production/epics/card-effects/story-017-validator-silence-before-destroy.md` (Logic, S): AC-47. Card-effects EPIC (17 stories, coverage line), match-rules EPIC coverage line, `production/epics/index.md`.

**Sprint 5:** `src/gameplay/match/rules_engine.gd` `silence` / death check plus a match-rules regression test (card-effects 009); `src/gameplay/effects/effect_validator.gd` order check plus validator tests (card-effects 017).

## DD-X22 — boss-ai.md: non-lethal face attacks

### Change Summary for DD-X22
Changed sections:
- C6: an **Attack valuation** paragraph records the pre-filter value as built by boss-ai story 005: one `damage` row, plus the `destroy` row on a kill, with lethal face attacks ranked first. A non-lethal face attack is one `damage` row whatever its Attack, and is valued after simulation by `f_face`.
- F1: a **Vulnerability exception** with `reach`, `unsafe` and `vulnerable(a)` defined, plus a worked example and a new variables row. When the exception holds, `f_face = 0` and `f_self = −min(1, reach / (boss_health + boss_armor))`.
- Edge Cases: the "player has lethal next turn" entry is reconciled (no trade helps → the boss races), and a new entry is added. Tuning Knobs: `defensive_margin` also sets `unsafe`. Acceptance Criteria: new A31.

"Vulnerable" chosen: the attack is non-lethal and on the player's hero; **after** it, the player's on-board reach is at least the boss's health plus armour minus `defensive_margin`; and the same attacker had a simulated attack on a player minion whose after-state is below that threshold. The player's reach is F6's board and weapon terms, without the hand estimate, minus the boss's Taunt health (F4).
- Board-only, because the hand is hidden.
- "Gives up a trade" is literal, so the boss still races when no trade helps (the existing edge case).
- The "only Taunt" option was rejected: an attack never removes the attacker's Taunt, and a defending hero never strikes back (match-rules C8), so it can never be what an attack gives up.
- No new knob, so no data change.

Unchanged: weights, F2–F9, DEFENSIVE mode (F6), lethal search, budgets.

Key changes affecting architecture: none. The rule is scorer arithmetic over states the one-ply sandbox already simulates, so it adds no simulation and no new seam.

### ADRs in scope for DD-X22
8 ADRs (as DD-X20). A search of `docs/architecture/` for `f_face`, `f_self`, `defensive_margin` and the attack valuation finds nothing. All in scope are **Still Valid**; no erratum.

### Stories for DD-X22
- `production/epics/boss-ai-match-driver/story-009-defensive-mode-and-sandbox-fidelity.md`: A31 AC, an Implementation Notes paragraph, Files (`src/ai/scorer.gd`, the new test and fixture), estimate S → M.
- `story-005-…`: its "Open (design)" item is marked resolved; no pre-filter code change.
- Boss-ai EPIC: story-table row, Definition of Done count 31.

**Sprint 5:** `src/ai/threat_estimate.gd` `reach` / `unsafe`; `src/ai/scorer.gd` exception; `tests/unit/boss_ai/boss_ai_face_attack_vulnerability_test.gd` and its fixture (boss-ai story 009).

## DD-X23 — match-ui.md and boss-ai.md: the commit beat stretches over planning

### Change Summary for DD-X23
Changed sections:
- match-ui U6 step 2: the beat starts at End Turn on the intent already shown and lasts `max(intent_banner_s, planner run)`, capped at `planner_target_ms` 500 ms. Past the cap, "boss thinking" shows until the plan arrives, then playback.
- match-ui F4 `intent_banner_s` row: the stretch is planning time, not playback, so `max_turn_playback_s` is unchanged.
- match-ui Input Responsiveness: the End Turn row (was "commit beat visible ≤ 300 ms"). Impact Moments: the commit-beat row.
- boss-ai Game Feel: Feel Reference; Input Responsiveness "planner complete" and "first boss action" rows; Impact Moments. Tuning Knobs: the `planner_target_ms` effect text.
- UX `design/ux/hud.md`: the End Turn button update behaviour and the intent-banner timing row.

Unchanged: `intent_banner_s` 0.3, `plan_changed_s`, F4 arithmetic, `planner_target_ms` 500 (DD-X18), skip behaviour, control locking.

Key changes affecting architecture: the latency row that ADR-0009 and ADR-0006 quote. TR-match-ui-005 changes.

Downstream GDDs to re-check: none in the registry.

### ADRs in scope for DD-X23
match-ui.md (standard): Foundation ADR-0001, 0002, 0003, 0004, 0010 plus the ADRs naming match-ui.md (0006, 0008, 0009, 0011), 9 in all. A search for the commit-beat latency and "300 ms banner beat" hits ADR-0006 and ADR-0009.
- **ADR-0009** (Match UI animation queue): Needs Review → **Updated in place (erratum 2026-11-04, DD-X23)**. The Related latency line is updated. Decisions 1–4 still hold, because boss-turn mode already starts on `turn_started{side: boss}` and the beat is view-state.
- **ADR-0006** (planner threading): Needs Review → **Updated in place (erratum 2026-11-04, DD-X23)**. The Validation Criteria flag from DD-X18 is resolved, and Performance Implications is reworded. The "boss thinking" branch of the tick diagram is unchanged.
- ADR-0001, 0002, 0003, 0004, 0008, 0010, 0011: **Still Valid**, since none quotes the beat.

### Other documents fixed for DD-X23
- `architecture.md`: the TR-match-ui-005 baseline row, §Performance budgets "Boss AI planner per run" and "UI input latency".
- `control-manifest.md`: the "Boss AI worker" guardrail.
- `tr-registry.yaml`: TR-match-ui-005, `revised: 2026-11-04` (same intent, ID kept).
- `requirements-traceability.md`: a row.

### Stories (dated AC notes)
- Affected: match-ui story 010 (new pacing AC with a planner fake), 015 (End Turn AC amended; "boss thinking" screenshot), 024 (latency-table row), and the match-ui EPIC scope line.
- MUI-003, MUI-004 and MUI-011 were checked and are **not affected**. They hold no commit-beat or latency criterion; 003/004 use `ImmediatePlannerTask`, so there is no planning delay.

**Sprint 5:** `src/ui/match/` boss-turn mode (beat start on End Turn, `max` / cap, "boss thinking" state) per match-ui 010 / 015; the latency test per 024. No data change (`intent_banner_s`, `planner_target_ms` unchanged).
