# Story 009: Raise-time snapshot, `once_per_turn`, Silence-after-queue and counters

> **Epic**: Card Effects
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-04
> **Last Updated**: 2026-11-04 (implemented, sprint 5 L5 W1)

## Context

**GDD**: `design/gdd/card-effects.md`
**Requirement**: `TR-card-effects-002`, `TR-card-effects-001` (`once_per_turn` in the schema; runtime as plain data)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Effect Resolver / Validator Boundary
**ADR Decision Summary**: `EffectRuntime {once_marks, counters, per_turn, pending_choice}` is the resolver's only state, plain data in `MatchState.effects`; `counter_changed` is emitted for each counter change through `engine.emit`; `once_per_turn` marks and tallies are derivable from the log and emit nothing.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (by version; the APIs used predate 4.3 and are LOW)
**Engine Notes**: ADR-0007 Engine Compatibility — no post-cutoff APIs. The snapshot is a `Dictionary` produced with `duplicate(true)` of plain containers only.

**Control Manifest Rules (this layer)**:
- Required: `EffectRuntime` is plain data (Dictionaries, Arrays, ints, Strings); `counter_changed` is emitted for each counter change
- Forbidden: `EffectRuntime` never holds a Callable, a Node or an object reference; never write match state directly (gate G7)
- Guardrail: `clone()` copies `EffectRuntime` by value — keep snapshots small (the C6.5 field list, nothing more)

---

## Acceptance Criteria

*From GDD `design/gdd/card-effects.md` (C5 `add_counter` / `set_counter`, C6.5, C6.7, Edge Cases; AC-19, AC-20, AC-21, AC-46) and `design/gdd/match-rules.md` (C12 Deathrattle row, C13 step 2; AC-46 — added 2026-11-04, DD-X21), scoped to this story:*

- [x] **AC-19** GIVEN row 11 ("Whenever a friendly minion dies, gain +1/+1") and two friendly minions dying in one death check, WHEN the loop completes, THEN row 11 has +2/+2 (two queued triggers, two `effect_resolved`); GIVEN the same effect with `once_per_turn: true`, THEN +1/+1 and exactly one `trigger_queued` (the mark is set when queued, keyed `(effect_id, source entity_id, match.turn)`; the second raise is dropped silently).
- [x] **AC-20** GIVEN row 12 (Deathrattle: damage = `source.attack`) buffed to 5 Attack by an aura lord that dies in the same step, WHEN both die, THEN the enemy hero takes 5 (the raise-time snapshot), not the base Attack.
- [x] **AC-21** GIVEN a minion Silenced while its Deathrattle is already queued (`destroy` then `silence` on a `pending_destroy` target in one effect), WHEN the loop completes, THEN the Deathrattle still resolves (queued = earned); GIVEN Silence **before** death, THEN no `trigger_queued` for it. *(2026-11-04, DD-X21: AC-21 stands as written. The owner decided the Deathrattle fires; match-rules C12 / C13 changed to match it, so the sprint-4 conflict between match-rules C12 and this AC is resolved.)*
- [x] **Match-rules AC-46 (engine change in scope, 2026-11-04, DD-X21)** GIVEN a minion with a Deathrattle "deal 2 damage to the enemy hero", WHEN one effect runs `destroy` then `silence` on it through `chosen`, THEN the log reads `silenced`, `minion_died`, then `trigger_queued` and `damage_dealt {dealt: 2}`. WHEN the order is `silence` then `destroy`, THEN no `trigger_queued` follows for it. WHEN the effect is lethal `damage` then `silence`, THEN no `trigger_queued` follows. This needs the C13 step 2 change in match-rules' `silence` primitive: a `pending_destroy` minion keeps the Deathrattles it held when marked. The primitive is match-rules story 015's code (Complete); the change lands in its file, under this story, with a match-rules regression test.
- [x] **AC-46** GIVEN row 45 after three minions (either side) died while it was in play, WHEN it dies, THEN `damage_dealt{dealt: 3}` on the enemy hero read from `counter.seen` in the raise-time snapshot, with three prior `counter_changed{source_id, key: seen, value}` events; GIVEN the same minion bounced to hand and replayed, THEN its counter reads 0 (counters die with the `entity_id`). *(2026-11-04: `amount` corrected to `dealt`, the GDD row and match-rules C15 field; the engine emits no `amount`.)*

---

## Implementation Notes

*Derived from ADR-0007 Decisions 1, 5 and GDD C6.5, C6.7:*

- Snapshot at queue time: `{source_id, def_id, owner, attack, health, max_health, board_index, keywords, counters}` (C6.5), stored on the queued trigger record the engine holds (plain data). `source.*` and `counter.*` refs read live while the source is still the same `entity_id` in play, else the snapshot. `transform` mid-effect: later ops' `self` is the new entity; queued triggers of the old entity resolve from their snapshot (story 013 tests the transform half).
- `once_marks[effect_id + ":" + source_id + ":" + turn] = true` set when the effect is queued or run; no reset needed (the turn counter moves on). Keyed by treasure/passive id for hook hosts (story 015).
- `counters[source_id][key]` via `add_counter` / `set_counter`; `engine.emit(&"counter_changed", {source_id, key, value})` per change; a read of a never-set counter is 0. A `set_counter` with a `{count: selector}` value (row 46) evaluates the selector against the live board before the following `destroy`.
- Silence: the resolver checks `silenced` when deciding who responds (story 008); it never removes an already-queued trigger. Match-rules' Silence primitive owns the `silenced` flag; this story only reads it.
- **Engine change (2026-11-04, DD-X21).** Today `RulesEngine.silence()` clears every Deathrattle, so `destroy` then `silence` in one pass leaves nothing for the death check to queue, and AC-21 fails. Under match-rules C13 step 2 (revised), `silence` on a target with `pending_destroy` keeps its Deathrattle effects, printed or enchantment-granted, and the resolver must still answer `deathrattle` for that entity. Do one of these and record which: (a) the death check queues the Deathrattles held at the mark; or (b) `silenced` does not suppress the `deathrattle` trigger of a `pending_destroy` entity. Either way the snapshot is the usual raise-time one, taken at the death check. A minion at `health ≤ 0` without `pending_destroy` is unchanged: Silence still strips it. Watch the AC-21 test fail on the unchanged engine before the fix.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 008: responder selection and queueing itself
- Story 012: the aura lord dying (recompute) — AC-20 needs auras to exist; land 012 before closing AC-20 or stub the +5 with a `buff` and note it
- Story 013: `transform` and `return_to_hand` behaviour beyond the counter reset
- Story 016: AC-40 (clone with a queued trigger and a counter)

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/gameplay/effects/effect_resolver.gd` (snapshot on the queue entry, `_claim_once`, the kept-Deathrattle answer in `_candidate_host`)
- `src/gameplay/effects/effect_runtime.gd` (`once_marks`, `counters` helpers)
- `src/gameplay/effects/ops.gd` (`add_counter`, `set_counter`, `values.read_from`, `source_slot` from the snapshot)
- `src/gameplay/effects/values.gd` (`source_snapshot`, `reads_snapshot`, snapshot-aware `source.*` / `counter.*` refs)
- `tests/unit/card_effects/card_effects_deathrattle_snapshot_test.gd` and its `.uid`
- `src/gameplay/match/rules_engine.gd` (`silence` only: a `pending_destroy` minion keeps its Deathrattles — match-rules C13 step 2, 2026-11-04, DD-X21; the death check is unchanged)
- `tests/unit/match_rules/match_rules_freeze_silence_test.gd` (match-rules AC-46 regression, 2026-11-04, DD-X21)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/card_effects/card_effects_deathrattle_snapshot_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] Created: 25 tests, plus 7 match-rules AC-46 tests in `tests/unit/match_rules/match_rules_freeze_silence_test.gd`

---

## Dependencies

- Depends on: `production/epics/card-effects/story-008-event-observers-queueing.md`, `production/epics/card-effects/story-007-values-selectors-spell-damage.md`; AC-20 also `production/epics/card-effects/story-012-auras-enchantments.md`. Cross-epic: `production/epics/match-rules/` (death check, DD-M11 Deathrattle order, `silence` / `destroy` / `return_to_hand` primitives).
- Unlocks: `production/epics/card-effects/story-013-transform-copy-keyword-aura.md`, `story-015-hook-trigger-steps-hero-slot-observers.md`, `story-016-determinism-clone-bounds-perf.md`

---

## Readiness (2026-11-04, by hand, sprint 5 L5 W1)

**Verdict: READY**, after two gaps were resolved from the docs. Workflow `full` (card-effects override).

- Passing: requirement traced (C5, C6.5, C6.7, AC-19/20/21/46, match-rules AC-46); ADR-0007 Accepted; TR-card-effects-001 and 002 active; stories 007, 008 and 012 Complete; no open markers; 5 criteria; Logic evidence path named; no asset references.
- **Manifest Version (was NEEDS WORK at `full`)**: the story read 2026-11-03, the manifest 2026-11-04. Reviewed the rows added since. The ADR-0007 queue-entry shape applies (`snapshot?` is resolver-supplied, which this story uses); the rest do not touch this story. Set to 2026-11-04.
- **Performance noted (was missing)**: no new budget. `submit()` stays under the manifest's 5 ms; the C6.5 snapshot replaces the whole-record deep copy per queue entry, so a queued trigger holds less than before.
- **Untestable AC-46 (`damage_dealt.amount`)**: corrected to `dealt` (QA plan "GDD and story contradictions": tests follow the GDD).
- **Two AC-46 rows**: different GDDs' numbering, not a duplicate.
- **N7 C2 defaults carried**: `by: owner` on `on_play` / `after_cast`, `side: owner` on `on_weapon_equipped`, `attacker: self`. The C2 table already carries them dated as designer defaults and `scope.gd` matches them. **game-designer confirmation is still outstanding**: no agent could be consulted from this lane. This story does not depend on them, so it is not a block.
- QL-STORY-READY skipped — Lean mode.

---

## Completion Notes

**Completed**: 2026-11-04
**Started / ended (UTC)**: 19:34:39 / 19:57:24
**Criteria**: 5/5 passing, all by automated test (none deferred)
**Test Evidence**: `tests/unit/card_effects/card_effects_deathrattle_snapshot_test.gd` (25), `tests/unit/match_rules/match_rules_freeze_silence_test.gd` (+7)
**Reviewed by**: independent `/code-review`, 2026-11-04 (`production/reviews/2026-11-04/code-review-s5-w1-ce009-fixbuffer.md`, full scope): **APPROVED WITH SUGGESTIONS**, 0 required on this branch. The merge hazards are closed on the fix-buffer side: R1 in `c90fb4b`, H1 in `a82a16d`. Open: S1, S2, the two weak tests, N1 to N4
**Run result**: N/A — a Logic story changes nothing visible; the full suite and `godot --headless --quit-after 5` are the evidence.

**Traceability**

| Criterion | Covered by |
|-----------|------------|
| AC-19 | `test_row11_two_friendly_deaths_in_one_check_gain_two_buffs`, `test_once_per_turn_two_deaths_in_one_check_queue_one_trigger_and_one_buff`, `test_once_per_turn_mark_is_keyed_by_effect_source_and_turn`, `test_once_per_turn_a_new_turn_clears_the_mark_with_no_reset` |
| AC-20 | `test_row12_buffed_by_an_aura_lord_dying_in_the_same_step_deals_the_snapshot_attack` (the real aura: story 012 is Complete, so no `buff` stub) |
| AC-21 | `test_destroy_then_silence_in_one_effect_still_resolves_the_deathrattle`, `test_silence_before_death_queues_no_deathrattle`, `test_a_trigger_queued_before_silence_still_resolves_and_the_source_then_fires_nothing` |
| Match-rules AC-46 (NC-4) | `test_ac46_destroy_then_silence_through_chosen_logs_silenced_died_queued_then_two_damage`, `test_ac46_silence_then_destroy_logs_the_death_and_queues_nothing_for_it`, `test_ac46_lethal_damage_then_silence_queues_nothing_for_it`, plus the granted, keep-only, living-minion and second-Silence cases |
| AC-46 | `test_row45_after_three_deaths_deals_three_read_from_the_snapshot`, `test_row45_bounced_and_replayed_reads_a_counter_of_zero`, `test_row45_counter_raised_before_death_but_resolved_after_is_not_in_snapshot` |

**Seen failing first.** Run against the unchanged engine with only the `EffectRuntime` helpers added (the suite could not parse without them): 21 of the 32 new tests failed, including AC-21 and match-rules AC-46 case 1. The other 11 passed there because they guard behaviour that already held, so each was then seen failing against a deliberate mutant, one per run, restored after:

| Mutant | Killed by |
|--------|-----------|
| `once_per_turn` defaults to true | row 11 +2/+2, unmarked effect, row 45 three deaths, clone |
| `silence` drops the already-silenced guard | both second-Silence tests |
| `silence` keeps Deathrattles without `pending_destroy` | Silence before death, silence-then-destroy, lethal-then-silence, living minion, both second-Silence tests, and sprint-4's `test_silence_removes_divine_shield_taunt_and_deathrattle_and_it_never_fires` |
| a queued pass skips a silenced source | trigger queued before Silence |
| the snapshot stores base Attack | AC-20, the C6.5 field test, the weapon test |
| an unset counter reads 1 | the never-set counter test and four row 45 / clone tests |
| a kept minion keeps its enchantments | post-Silence snapshot |
| `counter.*` always reads the live bucket | the row 45 late-counter case |

**Verification**: `--import` exit 0; `gates.sh`, `no_global_rng.sh`, `parse-check.sh` clean; the manifest's G7 pattern run by hand over `src/gameplay/effects`, 0 hits (`gates.sh` gains G7 in the L7 fix buffer); full suite 1442 cases, 0 failures, 93 suites, exit 0; smoke exit 0, no SCRIPT ERROR; `validate.gd` 0 errors. The suite's SCRIPT ERROR lines are negative tests; none traces into `src/gameplay/effects/` or `rules_engine.gd`.

**Option taken (Implementation Notes)**: (b), narrowed. `silenced` does not suppress the `deathrattle` trigger of an entity that `silence` itself marked `deathrattles_kept`. Reading `pending_destroy` alone would fire on `silence` then `destroy`, so the marker is set only when Silence lands on a minion already `pending_destroy` and not already Silenced. The snapshot is the usual one, taken at the death check.

**Deviations**

- ADVISORY: story AC-46 said `damage_dealt{amount}`; the engine, match-rules C15 and the GDD row say `dealt`. Followed the engine; the story is corrected.
- ADVISORY: `deathrattles_kept` is a new minion field, set only on this path and absent otherwise, like `pending_destroy` it is not in the `MatchRecords` factory. Match-rules C1 does not list it, and no rule changed, so no GDD edit was made.
- ADVISORY: "granted" is kept at keyword level. v1 has no Deathrattle *effect* an enchantment can carry (`give_keyword` refuses `deathrattle`, C7 auras never grant it, and `_collect` walks definition effects), so a granted `deathrattle` keyword moves into `keywords` when its enchantment is removed.
- ADVISORY: the snapshot is exactly the C6.5 list, so a departed source no longer exposes the whole record. `source.damage_taken` is derived (`max_health − health`), since C4 allows that ref and C6.5 has no such field; a `test` filter on a departed `source` reads defaults for `silenced`, `frozen` and the like. No fixture or shipped record tests `source` that way.
- ADVISORY: `counter_changed` fires only on a real change (ADR-0007 "for each counter change"), so a `set_counter` of the same value emits nothing and still reports `applied`.
- OUT OF SCOPE of the ACs, in scope by the code: `summon` `source_slot` from the snapshot's `board_index`, and the C5 Deathrattle default. `TODO(story 009)` in `ops.gd` and story 008's notes gave it to this story. A Deathrattle summon now lands in the dead minion's slot and logs `values.position: source_slot`, not `end`; `boss_rot_zombie` is one such card.
- OUT OF SCOPE of the ACs: `values.read_from` on ops (card-effects Edge Cases row 45 names it), and a weapon's `source.attack` now includes its enchantments, so the snapshot's Attack is right for a buffed weapon.

**Left open**

- N7: game-designer confirmation of the three C2 defaults (Readiness above).
- `TestEffectResolver` does not honour `deathrattles_kept`: it is a shared helper, edits there stay additive, so the AC-46 cases use the real resolver.
- Not changed, outside this story: a `trigger_subject.*` ref on a departed subject reads 0, where C3 says it reads the raise-time snapshot; and `has_trigger` reads false on a kept-Deathrattle minion during its last pass, which `retrigger` (L7) should check.
