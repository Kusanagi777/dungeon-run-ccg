# Story 020: `minion_summoned` carries `keywords[]`, `match_started` carries the starting hero health, one reviewed golden regeneration

> **Epic**: Match Rules
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-04
> **Last Updated**: 2026-11-05

> **BLOCKED IN PART (2026-11-05)**: the `keywords` half is built and committed. The starting-health half (AC-2, AC-3's health clause, AC-4's health clause) waits on the design owner: open questions 1 and 2 below. Neither match-rules C15 nor rng-event-log §D settles them. Status stays Ready until they do. See Completion Notes.

## Context

Sprint 6 Goal Prerequisites rows 9 and 10, found by the match-ui reviews and recorded in MUI-001 / MUI-003 notes as "no tracked item". Two events leave the view without data it needs:

- `minion_summoned` is emitted at `rules_engine.gd` `summon_minion` (about line 1265) and `_accept_minion` (about line 2386) as `{side, entity_id, card_id, position, attack, health}`. rng-event-log §D lists `keywords[]`. `MatchViewState` already reads `keywords` from the payload (`match_view_state.gd`, `minion_summoned`), so today every token starts with an empty set: MUI-007's keyword badges (Taunt, Divine Shield, …) have no source until an aura pass happens to report one. `tests/integration/match_ui/view_state_engine_parity_test.gd` leaves `keywords` out of the comparison for exactly this (`NOT_PROJECTED`).
- `match_started` carries `{floor, hero_id, boss_id, player_deck_size, boss_deck_size}` and no health. No C15 event reports a hero's starting health, so `hero.health` is null in the view until the first `damage_dealt`, and MUI-005 AC-1 ("health … stamps on both portraits in the first capture") cannot be met from events.

**Which event carries the starting health** (decided from the docs): `match_started`. C3 step 4 lets `on_match_start` hooks (Treasures, the boss passive) alter starting health, armour, mana or hand size before step 8 emits `match_started`, so it is the one event emitted after the starting values are final; an event a hook emits earlier finds no hero in the view, because the view learns the hero entity ids only when `match_started` is projected. The values are absolute, like `auras_recomputed` entries.

Both changes touch the same two events in the same file and the same goldens, so they are one story and one regeneration (sprint plan: "can share one golden regeneration").

**GDD**: `design/gdd/match-rules.md` C3 steps 2, 4, 8 and C15 (event vocabulary) · `design/gdd/rng-event-log.md` §D rows `match_started`, `minion_summoned` · `design/gdd/match-ui.md` U3 table (`match_started`, `minion_summoned`) as the consumer. At `full`, the other match-rules sections were not needed: no formula, edge case or tuning knob changes.
**Requirement**: `TR-match-rules-007` (C15 is the authoritative event vocabulary, DD-X04), `TR-rng-event-log-004` (one event per mutation, JSON-only payloads)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Seeded RNG Service and Event Log (one event per mutation after the mutation; payloads JSON-only; the catalogue). Also ADR-0007 (the engine owns the primitives and the events they emit) and ADR-0001 (the UI renders from events only)
**ADR Decision Summary**: Every mutation emits exactly one event after the mutation, and the UI projects only events; the engine's C15 catalogue is authoritative (DD-X04) and the log mirrors it. A payload field the view needs must therefore be on the event, never read back from the engine.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: LOW for this change (`Array`, `Dictionary`, sorting: pre-4.3 APIs); the ADRs are HIGH by version.
**Engine Notes**: Payloads go through `EventLog.append`, which deep-copies them: pass a fresh `Array` for `keywords`, never the minion's own array.

**Control Manifest Rules (Core layer, v2026-11-04)**:
- Required: one event per state mutation, after it, with `cause_seq` set; payloads are plain JSON data; the engine never reads the view and the view never reads engine state, only events and `MatchQuery`.
- Forbidden: regenerating a golden to make `match_rules_golden_log_test.gd` pass; changing the order or number of events; changing any field already in a payload.
- Guardrail: `submit()` ≤ 5 ms, `legal_commands()` ≤ 2 ms; the op-count and allocation budgets in `match_rules_op_budget_test.gd` stay as they are (this story adds one array per summon and two integers per match start).

---

## Acceptance Criteria

*From match-rules C3 / C15 and rng-event-log §D, scoped to this story:*

- [x] GIVEN a minion with printed keywords played from hand and another summoned by `summon_minion`, WHEN `minion_summoned` is emitted, THEN at both sites the payload holds `keywords`, the minion's effective set (printed plus enchantment-granted at that instant, each once, sorted: the same `_effective_keywords` that fills `auras_recomputed`), an empty array when it has none; no other field of the payload changes, and the event count and order of every sequence are unchanged.
- [ ] GIVEN a match whose `on_match_start` hook changes a hero's starting health, WHEN `match_started` is emitted (C3 step 8), THEN its payload also holds `player_health` and `boss_health`, each the hero's `health()` at that instant (after the hook), and the existing five fields are unchanged; and WHEN a `MatchViewState` projects it, THEN both heroes' `hero.health` equal those values from the first projected step.
- [ ] GIVEN the shipped War decks against all four MATCHES of `view_state_engine_parity_test.gd`, WHEN the suite runs with `NOT_PROJECTED` deleted, THEN token `keywords` are compared at every `seq` and `hero_health` is compared from the first step (no null skipped), and the suite passes; and match-rules C3 step 8 / C15 and rng-event-log §D list the new payload fields as implemented, with the `keywords[]` meaning stated.
- [ ] GIVEN the goldens under `tests/fixtures/match_rules/golden_logs/`, WHEN they are regenerated with `tools/match_rules/record_golden_logs.gd` in this change's own commit, THEN removing the added fields (`keywords` from `minion_summoned`, `player_health` and `boss_health` from `match_started`) from the new files gives the old files byte for byte (the stripped-diff proof, recorded in the commit message), technical-director has read the diff before merge, and `match_rules_golden_log_test.gd` and `match_rules_op_budget_test.gd` pass with no budget raised.

---

## Implementation Notes

*Derived from ADR-0003 and the golden-log rule in `tests/README.md` (Golden logs) and `record_golden_logs.gd`:*

- `summon_minion` and `_accept_minion`: add `"keywords": _effective_keywords(minion)` to the payload. `_effective_keywords` is `static` and already used by the aura pass; it allocates one array, which the op-budget suite counts: keep that suite green, and if an allocation budget moves, report the number to the owner (R6) rather than raising it.
- `match_started` (C3 step 8, `rules_engine.gd` about line 2592): add `player_health` and `boss_health` after the existing `*_deck_size` pair, the naming that pattern suggests. **Field names are proposed, not in any document**; the GDD edit in AC-3 makes them official and needs the design owner's approval ("May I write this to …").
- **Cross-epic touch, approved with this story** (precedent: BAI-019 touching `boot.gd`): `src/ui/match/match_view_state.gd`, the `match_started` branch of `_project`, also sets each side's `hero.health` from the payload (`p.get(…)`, so an older stream without the fields still projects with health null). Without it row 10 is half done: the engine says the health and no story makes the view read it. Match UI's owner reviews that hunk. MUI-001's projection test gains a test beside the existing `match_started` row; `tests/fixtures/match_ui/streams/full_match_torchbearer.json` is hand-built and keeps working unchanged.
- **Golden regeneration**: run `godot --headless --path . -s res://tools/match_rules/record_golden_logs.gd` once, after the engine change, in the same commit. The proof is mechanical: delete the added keys from each changed line of the new files and compare with the previous commit's files. At the time of writing nine goldens hold `minion_summoned` and twelve hold `match_started` (`grep -c`); expect those files, and only those, in `git diff --stat`. A line that differs in any other way means the change is not what it claims: stop.
- **Merge position**: `rules_engine.gd` has no other planned editor in sprint 6. This story merges first in its wave, before any golden is compared.
- Do not mix other `rules_engine.gd` edits into the commit, or the golden diff stops being a reviewable statement about these two events.

**Open design questions — flagged, not decided (design owner / game-designer):**

1. **Names.** `player_health` / `boss_health` follow the existing `player_deck_size` / `boss_deck_size`; no document names them.
2. **Armour.** C3 step 4 also lets a hook alter starting armour. An `armor_gained` a hook emits before `match_started` cannot be projected (the hero entity is unknown to the view yet), so a start-of-match armour bonus would be lost to the view. No v1 content is known to do it. Add `player_armor` / `boss_armor` now, or record it as a known limit?
3. **`position` against `board_index`.** The engine emits `position` for `minion_summoned` (and `card_played`); rng-event-log §D lists `board_index`. `MatchViewState` accepts both. This story leaves it alone; one of the two documents or the engine should move.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Drawing the keyword badges and the health stamps: `production/epics/match-ui/story-007-board-rows-and-tokens.md`, `production/epics/match-ui/story-005-hero-panels-mana-and-end-turn.md`.
- Any engine optimisation: `production/epics/match-rules/story-019-rules-engine-performance-pass.md` (its close-out is bookkeeping on R6).
- Re-recording the hand-built stream fixture from a real match (MUI-004 / later).

---

## Files

- `src/gameplay/match/rules_engine.gd` (the two `minion_summoned` sites, the `match_started` emit)
- `src/ui/match/match_view_state.gd` (the `match_started` branch only; cross-epic, see Implementation Notes)
- `design/gdd/match-rules.md` (C3 step 8, C15), `design/gdd/rng-event-log.md` (§D)
- `tests/unit/match_rules/match_rules_event_payloads_test.gd` (new)
- `tests/unit/match_rules/match_rules_primitives_test.gd` (added 2026-11-05: its exact `minion_summoned` payload assertion gains `keywords`)
- `tests/unit/match_ui/match_view_state_projection_test.gd` (one added test)
- `tests/integration/match_ui/view_state_engine_parity_test.gd` (`NOT_PROJECTED` removed, header comment updated)
- `tests/fixtures/match_rules/golden_logs/*.jsonl` (regenerated)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above (QL-STORY-READY skipped — Lean mode).*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/match_rules/match_rules_event_payloads_test.gd` — must exist and pass. Watch the new tests fail on the unchanged engine first (test-standards: a test only ever seen passing is not known to test anything). A fixture needs a minion with at least two keywords and one with none, and an `on_match_start` hook that moves health.
- Also: the parity suite (`view_state_engine_parity_test.gd`) and the golden suite pass; the stripped-diff proof is in the commit message.

**Status**: [x] Created for the `keywords` half (7 tests); the `on_match_start` health fixture waits on the blocker

---

## Dependencies

- Depends on: `production/epics/match-rules/story-003-match-setup.md` (`match_started`), `production/epics/match-rules/story-010-play-card-and-hero-power.md` (the minion play), `production/epics/match-rules/story-019-rules-engine-performance-pass.md` (the goldens and the op budgets exist; MR-019 is in close-out), `production/epics/match-ui/story-001-match-view-state-projection.md` (the projection it extends). All done except MR-019's close-out
- Unlocks: `production/epics/match-ui/story-005-hero-panels-mana-and-end-turn.md` (AC-1 health stamps), `production/epics/match-ui/story-007-board-rows-and-tokens.md` (the keyword-badge clause of AC-1), `production/epics/match-ui/story-003-match-controller-and-match-query.md` L2 parity (keywords and health compared)
- **Sprint 6 placement**: before W1, lane 9 in the plan's Pre-W1 story lanes, merged first at M0 (it is the only `rules_engine.gd` editor), about 1.5 links. MUI-005 (L1 W1) wants the health on events before its first capture. Fallback: L6 W1 (L6 merges first at M1, and this story needs that slot); then MUI-005's AC-1 health stamps close at the W2 fix slot and MUI-007 (L3 W2) is unaffected. [C] type: it changes recorded goldens, so the full suite runs against the merged state after it. If MR-019 / MR-018 close out in the same lane, keep them in separate commits.

---

## Readiness (2026-11-05, `/story-readiness` read by hand)

**Verdict: BLOCKED in part.** Design, architecture, scope and dependencies pass, and MR-019's close-out does not gate this work. Open Questions blocks: questions 1 and 2 are written as undecided, and AC-2 depends on both.

- **Ready:** AC-1, and the `keywords` clauses of AC-3 and AC-4. §D lists `keywords[]`, and C15 defines the field for `auras_recomputed`.
- **Blocked:** AC-2, and the health clauses of AC-3 and AC-4. C15 gives `match_started` no payload, §D lists five fields with no health, and no DD-X row covers it. `player_health` / `boss_health` appear only in this story's proposal and as unrelated boss-ai formula variables. The engine's own precedent is split: `player_deck_size` is flat, while `match_ended` nests `final_health{player, boss}`. The sprint plan lists both questions as owner decisions for the Pre-W1 lane.
- **Advisory:** the plan's readiness note says to regenerate after retro action 1 (Linux CI read on `d181790`). That item still reads open. The orchestrator ordered this regeneration, on a lane branch that is not merged.

---

## Completion Notes

**Not closed: Status stays Ready** (lane brief stop rule, applied per field by the orchestrator, 2026-11-05).
**Start**: 2026-11-05 16:29:03 UTC. **End**: 2026-11-05 16:40:16 UTC.

**Built**: `keywords` on `minion_summoned` at both emit sites through `_effective_keywords`; `NOT_PROJECTED` deleted, so the parity suite compares token `keywords` at every `seq` that compares boards, on all four MATCHES; match-rules C15 and rng-event-log §D state the meaning; the goldens are re-recorded.

**Not built, waiting on the blocker**: `player_health` / `boss_health` on `match_started`; the `match_view_state.gd` hunk; the `match_view_state_projection_test.gd` test; the `on_match_start` fixture; removing the null `hero.health` skip in the parity suite. `match_view_state.gd` is untouched.

| Criterion | State |
|---|---|
| AC-1 keywords at both sites | Met, except as noted under Coverage |
| AC-2 starting health | Blocked |
| AC-3 parity and GDDs | Keywords clause met. `hero_health` from the first step blocked |
| AC-4 goldens | Keywords-only regeneration, proof below. technical-director's read is still to come. `match_rules_golden_log_test.gd` and `match_rules_op_budget_test.gd` pass, no budget raised |

**Golden proof** (standalone byte comparison against the parent commit, not engine code): `keywords` removed from each `minion_summoned` payload gives the old files byte for byte. 9 of 16 files changed, 185 of 4647 lines; the other 7 files and 4462 lines are identical. The nine are the nine files holding `minion_summoned`, as forecast. The proof was seen to fail on two deliberate tampers (a summon's `attack`, a `match_started` deck size).

**Tests first**: on the unchanged engine, all 7 new unit tests failed against missing code, and both parity tests failed once `NOT_PROJECTED` was gone (`view [] engine ["battlecry"]`). After the engine change and before re-recording, five golden tests failed, as they should. A `minion.keywords` mutant failed 5 of the 7; the two empty-array tests are the ones it cannot reach. No mutant left in the tree.

**Coverage**: a minion has no enchantment at either emit site, because it is created just before the emit. AC-1's "enchantment-granted" branch is therefore unreachable there and is not exercised by a test; it is the same `_effective_keywords` the aura pass tests cover.

**Deviations**:
- **Two regenerations, not one.** The health half needs a second one, touching the 12 files that hold `match_started`, with its own proof and read. The alternative was holding the `keywords` half back from M0.
- `match_rules_primitives_test.gd` was not in Files: its exact-payload assertion had to gain the field.
- A planned test, that changing the reported array leaves the minion alone, was removed before commit. It passed under a real aliasing mutant, because `EventLog.append` deep-copies, so it could not fail.

**Effect on the plan**: MUI-007's keyword badges are unblocked. MUI-005 AC-1's health stamps are not, until the owner answers.

**Result**: `Overall Summary: 2352 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans`; smoke exit 0, no SCRIPT ERROR; `gates.sh`, `no_global_rng.sh`, `parse-check.sh` and `ai_code_gates.sh` pass.
