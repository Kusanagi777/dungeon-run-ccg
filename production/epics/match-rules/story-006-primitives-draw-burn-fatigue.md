# Story 006: Primitive API, draw, burn and fatigue

> **Epic**: Match Rules
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-03

## Context

**GDD**: `design/gdd/match-rules.md` (Interactions — Engine primitive API, 24 calls; C11 Hand, draw, burn and fatigue; F5 Fatigue damage; C15 Event vocabulary and `cause_seq`; Edge Cases "Hand, draw and fatigue")
**Requirement**: `TR-match-rules-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Effect Resolver / Validator Boundary (Decision 1, 5, 6 — primitives are the only writes; `emit` carries `cause_seq`); also ADR-0003 (one event per mutation after the mutation; `cause_seq`; payload values JSON-representable)
**ADR Decision Summary**: `RulesEngine` owns the primitive API (`draw` … `discard`, 24 calls) and the one event each emits; the resolver mutates match state **only** by calling them. Primitives emit with the `cause_seq` the engine holds for the current step; `engine.emit(type, payload)` is the thin wrapper that keeps every `log.append` call site inside the engine.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: HIGH by version; APIs used predate 4.3. `JSON.parse_string` returns `float` for every number (probe E) — payload ints are coerced back with `int()` on load, so keep payload values to ints, Strings, bools, null and plain containers (`GameAssertions.assert_json_representable`). `RandomNumberGenerator` is never named under `src/gameplay/` (`random` positions draw from `rng_match`).

Everything that changes a match goes through one of these calls, and every call leaves exactly one event. That is what makes the log a complete explanation (Pillar 4) and what lets the Card Effects resolver compose card text without ever writing a field. This story lands the full set so later stories (combat, play, keywords) call primitives instead of fields, and it completes `draw` with the burn and fatigue branches.

**Control Manifest Rules (this layer)**:
- Required: `RulesEngine` owns … the 24 primitives (ADR-0007); `EffectResolver` mutates match state only through engine primitives, emits only through `engine.emit(type, payload)`, draws only through `engine.rng_match()`; `RulesEngine.state()` is called only from `src/gameplay/effects/**` (ADR-0007); `subscribe(cb)` registers directly on the match `EventLog` — no event buffer (ADR-0008, ADR-0003)
- Forbidden: never write match state directly from `src/gameplay/effects/**` — gate G7 (ADR-0007); `EffectResolver` never calls `EventLog.append` (ADR-0007); never compile effects to GDScript Callables at load (ADR-0007 Alt 2)
- Guardrail: `submit()` ≤ 5 ms worst case (50-step Deathrattle chain, includes resolver passes) — each primitive is O(board) at most; no `duplicate()` of state inside a primitive (ADR-0007, ADR-0001)

---

## Acceptance Criteria

*From GDD `design/gdd/match-rules.md`, scoped to this story:*

- [x] AC-31 **GIVEN** a hand of 10, **WHEN** a draw happens, **THEN** `card_burned` is emitted (with the definition id), the hand stays at 10, the deck shrank by 1, the card is in the graveyard, no `on_draw` trigger event and no `on_draw` hook invocation.
- [x] AC-32 **GIVEN** an empty deck and hero health 30, **WHEN** four draws occur, **THEN** `fatigue_damage` amounts are 1, 2, 3, 4 and health is 20 (F5: `FATIGUE_BASE + (k − 1) × FATIGUE_STEP`, counter per side, never reset); armour of 2 before the first draw absorbs it fully (health 29 after 1 + 2 instead of 27 — fatigue goes through F2, story 007 completes armour; this story routes fatigue through `apply_damage(hero, k, source = FATIGUE)`).
- [x] AC-33 **GIVEN** one card left in the deck, **WHEN** a "draw 2" effect resolves (`draw(side, 2)`), **THEN** one `card_drawn` then one `fatigue_damage {amount: 1}` — effects that draw N call the per-card draw N times.
- [x] Interactions / C15 **GIVEN** each of the 24 primitives (`draw`, `apply_damage`, `apply_heal`, `apply_armor`, `apply_enchantment`, `remove_enchantment`, `summon_minion`, `destroy`, `silence`, `freeze`, `add_keyword`, `return_to_hand`, `transform`, `add_mana`, `equip_weapon`, `discover`, `add_card_to_hand`, `set_stats`, `remove_keyword`, `add_card_to_deck`, `modify_durability`, `refresh_hero_power`, `discard`, `recompute_auras` via the loop) called once on a started match, **THEN** each appends exactly one event of its C15 type (`card_drawn`/`card_burned`/`fatigue_damage`, `damage_dealt`, `healed`, `armor_gained`, `enchantment_applied`, `enchantment_removed`, `minion_summoned`/`summon_failed`, `minion_died` (via the death check), `silenced`, `frozen`, `keyword_removed` for `remove_keyword`, `mana_added`, `weapon_equipped`, `choice_requested`, `card_added_to_deck`, `weapon_durability_changed`, `hero_power_refreshed`, `card_discarded`, …) with the acting `entity_id`s and resulting numbers in the payload, the payload passes `assert_json_representable`, and `cause_seq` equals the `seq` the engine holds for the current step (0 for the direct consequence of a command); `add_card_to_deck(side, def_id, random)` and `discard(side, random)` draw exactly one index from `rng_match` and nothing from any other stream.

---

## Implementation Notes

*Derived from ADR-0007 Decision 1, 5, 6, 7 / Implementation Guidelines and GDD Interactions / C11:*

- The 24 primitives are public methods on `RulesEngine` (ADR-0007 Decision 1: "called only by `EffectResolver` and by the engine's own command handlers"). Each: validate its arguments (a primitive on a missing entity is a no-op with no event — a content bug, not a crash), mutate the plain-data state, `emit` its one event, then **return** — it never runs the death check or `recompute_auras()` itself (one effect pass = one C10 step; the loop runs between steps, story 009).
- `emit(type: StringName, payload: Dictionary) -> int` appends through `log.append(type, payload, _current_cause_seq)`; the engine sets `_current_cause_seq` to the `seq` of the event whose resolution produced the current step (a Deathrattle's summon is attributable to the death that queued it).
- `draw(side, n)`: per card — deck empty → `fatigue_counter += 1`, `apply_damage(hero, FATIGUE_BASE + (k−1)×FATIGUE_STEP, source = FATIGUE)`, emit `fatigue_damage`, continue; else `card = deck.pop_front()`; `hand.size() >= HAND_SIZE` → graveyard, `card_burned{def_id, instance_id, side}`, no `on_draw`; else append to hand, `card_drawn`, `hooks.run_triggers(&"on_draw", side, {card})` then `resolver.resolve(&"on_draw", …)`. A 0-card deck at match start applies fatigue 1, 2, 3 before the mulligan — not special-cased.
- `summon_minion(side, def_id, position)`: board full → `summon_failed{reason: board_full}` no-op; else insert at `position` (`clamp` to the rightmost slot when the former index is beyond the end), `summoning_sick = true`, `summoned_on_turn = turn`, `minion_summoned`; then `hooks.run_triggers(&"on_minion_summoned", …)`. `destroy(target)` sets `pending_destroy = true` (dies in the next death check). `transform(target, def_id)` recreates the character with a **new** `entity_id`. `set_stats` and `apply_enchantment` never write `base_*` after creation except through Silence (story 015) or `transform`. `add_card_to_deck(…, position: top | bottom | random)` — `random` = one `rng_match.randi_range` index; `discard(side, hand_index | random)` likewise, card to graveyard, no burn semantics. `modify_durability(weapon, delta)` emits `weapon_durability_changed`; ≤ 0 breaks in the next death check. `refresh_hero_power(side)` sets `used_this_turn = false`, no mana refund. `remove_keyword` emits `keyword_removed`; it takes effect at the next legality or damage evaluation. `discover(side, options) -> ChoiceRequest` enters `Choice` (story 016 — here it creates the request and emits `choice_requested`).
- `apply_damage` / `apply_heal` / `apply_armor` are landed here as the F2/C9 skeleton (`damage_taken += amount`, `restored = min(amount, damage_taken)`, `armor += amount`) with their events; story 007 completes hooks, Divine Shield, armour absorption, Poisonous and Lifesteal. `apply_damage` records `stats.damage_dealt_by_card` / `stats.damage_taken` per C1.
- `state() -> MatchState` is a live reference for the resolver only (control manifest); the test resolver double is the one test caller.
- A grep guard for later: nothing under `src/gameplay/effects/**` may match gate G7 (`\.(board|hand|deck|…)\s*\.(append|erase|…)\(` …) — the engine's own files are where those writes live.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 007: the full F2 pipeline (hooks → Divine Shield → armour → `damage_taken`, Poisonous, Lifesteal), `modify_heal` fold
- Story 009: death check, trigger queue, `recompute_auras()` call, `RESOLUTION_STEP_CAP`
- Story 015: `silence` semantics beyond the event (enchantment strip, F6 clamp), thaw
- Story 016: the `Choice` phase and `resume` on `choose`
- Card Effects epic: the resolver that calls these primitives from DSL ops

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/gameplay/match/rules_engine.gd` — `PRIMITIVES` (23 engine calls + the resolver's `recompute_auras`), `SOURCE_FATIGUE` and reason constants, the full `draw` (burn, fatigue F5 through `apply_damage`, `on_draw` hooks then trigger point), `apply_damage` / `apply_heal` / `apply_armor` skeletons (armour absorption included), `apply_enchantment`, `remove_enchantment`, `summon_minion`, `destroy`, `silence`, `freeze`, `add_keyword`, `return_to_hand`, `transform`, `equip_weapon`, `discover`, `add_card_to_hand`, `set_stats`, `remove_keyword`, `add_card_to_deck`, `modify_durability`, `refresh_hero_power`, `discard`; lookup helpers (`_character`, `_minion`, `_weapon`, `_owner_of`, `_card_def`), `_raise` (resolve → queue, no loop)
- `src/gameplay/match/match_records.gd` — `choice_request` (`ChoiceRequest {side, kind, options, source_id, effect_id}`), keyword, deck-position, `PICK_RANDOM` and choice-kind constants
- `tests/helpers/match_factory.gd` — `make_started_engine` takes an optional trailing `db` (the engine's `card(def_id)` lookup); every existing caller unchanged
- `tests/unit/match_rules/match_rules_primitives_test.gd` — 30 test functions

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/match_rules/match_rules_primitives_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later). `qa.level: standard` — BLOCKING.

**Status**: [x] Created and passing (30 test functions)

---

## Dependencies

- Depends on: `production/epics/match-rules/story-005-turn-structure-and-mana.md`
- Unlocks: `production/epics/match-rules/story-007-damage-heal-armor.md`

## Completion Notes
**Completed**: 2026-11-03 (started 22:21:36 UTC, ended 22:34:39 UTC)
**Criteria**: 4/4 passing — AC-31 (`test_draw_into_a_full_hand_burns_the_card_without_on_draw`, `test_successful_draw_runs_on_draw_hooks_then_the_on_draw_trigger_point`), AC-32 (`test_four_empty_deck_draws_deal_fatigue_1_2_3_4`, `test_fatigue_counter_is_per_side_and_never_resets_across_turns`, `test_fatigue_amount_reads_the_fatigue_knobs`, `test_armour_absorbs_fatigue_before_health`, `test_empty_deck_at_match_start_applies_fatigue_1_2_3_before_the_mulligan`), AC-33 (`test_draw_two_with_one_card_left_draws_one_then_takes_fatigue_1`), Interactions / C15 (22 tests, one per primitive group, plus `test_primitive_on_a_missing_entity_is_a_no_op_without_an_event` and `test_primitives_stamp_the_cause_seq_the_engine_holds_for_the_step`). Watched fail: the suite against the story-005 engine (parse error on the missing API, then 14 failures with the API in place and `draw` not yet completed); mutant firing `on_draw` hooks on a burn (the AC-31 test fails).
**Deviations** (advisory):
- `apply_damage` already absorbs armour (needed by AC-32's armour clause, verified here rather than deferred); `armor_lost`, the `modify_damage` fold, Divine Shield, Poisonous, Lifesteal and `on_hero_damaged` remain story 007.
- `destroy` emits no event: C15 has none for the `pending_destroy` mark; the death check's `minion_died` / `weapon_destroyed` (story 009) is its event. AC-40's "minion_died (via the death check)" is verified there.
- `transform` emits `minion_transformed {side, old_entity_id, entity_id, card_id, position}` — not in the C15 vocabulary (no transform event exists there); needs a match-rules C15 row (as `card_added_to_hand` got on 2026-11-03).
- `return_to_hand` emits `card_added_to_hand` / `card_burned` with an extra `returned_entity_id` key (C15 has no bounce event).
- `add_keyword` is an enchantment with `keywords_added = [kw]` (one `enchantment_applied`, so Silence strips it); `set_stats` is an enchantment too (`enchantment_applied` with `reason: set_stats`; setting health clears `damage_taken`).
- `remove_enchantment(target, index)`: enchantments carry no id, so the GDD's `id` is the list index.
- `discover` sets `pending_choice` and emits `choice_requested` but does not enter `Choice` (story 016).
- `summon_minion` / `transform` / `equip_weapon` read definitions through `db.card(def_id)`; with no database (every pre-006 test) they are no-ops with a warning. `MatchFactory.make_started_engine` gained an optional trailing `db` parameter; the suite uses a test-local `FixtureDb`.
- `on_draw` fires for every successful draw, setup and mulligan redraws included (C11 has no exception) — design question for Treasures: should starting-hand draws trigger "whenever you draw" hooks?
- Damage attribution: `damage_dealt_by_card` is keyed by the source record's `def_id`; a hero source (no `def_id`) and `SOURCE_FATIGUE` attribute nothing.
- `recompute_auras` is the resolver's (24th call); the C10 loop that calls it is story 009.
**Test Evidence**: `tests/unit/match_rules/match_rules_primitives_test.gd` (30 tests); full suite 723 test cases, 0 failures, exit 0, 36 SCRIPT ERROR lines (the same intentional negative-test count as the baseline); smoke exit 0, no SCRIPT ERROR; parse check exit 0.
**Run result**: N/A — the story changes headless engine primitives and the event log only; no scene, node or screen renders them (Match UI is a later epic).
**Reviewed by**: self, no independent review (LP-CODE-REVIEW skipped — Lean mode; QL-TEST-COVERAGE skipped — Lean mode)
