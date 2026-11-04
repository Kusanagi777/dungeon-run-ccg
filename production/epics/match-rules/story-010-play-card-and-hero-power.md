# Story 010: Playing minions, spells, weapons and the hero power

> **Epic**: Match Rules
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-04

## Context

**GDD**: `design/gdd/match-rules.md` (C6 Playing cards — minions, spells, weapons; C7 Hero power; C2 `play_card` / `use_hero_power` rows and `legal_commands()`; C12 Battlecry row; Edge Cases "Targeting and playing"; DD-M13)
**Requirement**: `TR-match-rules-005` (`summon_minion`, `equip_weapon` paths), `TR-match-rules-006` (trigger points `battlecry`, `on_play`, `on_summon`, `on_cast` / `after_cast`, `hero_power`, `on_weapon_equipped`; hook `on_card_played`), `TR-match-rules-002` (`legal_commands` expansion, the C6 rejection order)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Effect Resolver / Validator Boundary (Decision 1 — `targeting_spec(def_id)` / `legal_targets(def_id, source)` are the resolver's, called by the engine during C6 validation; trigger order is the engine's)
**ADR Decision Summary**: The engine owns *when* a trigger point fires and in what candidate order; the resolver owns *who responds* and derives `targeting_spec` from the `chosen` selector (memoised per `def_id`, never a stored field). C6's fixed play order — Battlecry, `on_card_played` hooks, `on_play`, `on_summon` — is four engine steps, each followed by the C10 loop.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: HIGH by version; APIs used predate 4.3. `legal_commands()` is called on every hover and per Boss AI node — ≤ 2 ms; the `targeting_spec` memo per `def_id` is the resolver's (ADR-0007), so the engine asks once per hand card per call and allocates only the result array.

Playing a card is the longest validation chain in the engine and the order of its checks is part of the contract: tests assert the code, so the first failing reason must be deterministic. Mana is paid at acceptance and never refunded; a Battlecry with no legal target still leaves a body on the board (Hearthstone rule), while a required-target spell with no target is simply not playable.

**Control Manifest Rules (this layer)**:
- Required: the engine fires trigger points with `ctx.candidates` already in engine order (ADR-0007); `targeting_spec` is derived via `derive_targeting_spec`, memoised per `def_id` (ADR-0007); hook catalogue trigger points include `on_card_played`, `on_minion_summoned` (ADR-0005)
- Forbidden: never read `targeting` from a stored field (Card Database rejects it, CR-3) (ADR-0007); never compile treasure effects into card instances at `begin_match` (ADR-0005 Alt 3); never let the resolver own the trigger queue (ADR-0007 Alt 1)
- Guardrail: `legal_commands()` ≤ 2 ms (`targeting_spec` memoised per `def_id`); `submit()` ≤ 5 ms (ADR-0007, ADR-0001)

---

## Acceptance Criteria

*From GDD `design/gdd/match-rules.md`, scoped to this story:*

- [ ] AC-11 **GIVEN** 7 friendly minions, **WHEN** a minion is played, **THEN** rejection `BOARD_FULL`; **WHEN** played with `position = 8` on a 2-minion board, **THEN** `INVALID_POSITION` (negative likewise; `position == board.size` is the rightmost slot and legal); **WHEN** `position = 2`, **THEN** it becomes `board[2]` with `summoning_sick = true`, `attacks_used = 0`, `summoned_on_turn = turn`, and the events are `mana_spent`, `card_played`, `minion_summoned`, then the Battlecry step, `on_card_played` hook, `on_play`, `on_summon` steps in that order (resolver double records the `resolve` call order); the C6 validation order `phase/turn → hand_index (INVALID_INDEX) → type → cost (NOT_ENOUGH_MANA) → BOARD_FULL → INVALID_POSITION → targeting` is asserted by failing two checks at once and reading the first.
- [ ] AC-13 **GIVEN** a required-target spell and no enemy minions (only a Stealth one), **WHEN** `legal_commands()` is queried, **THEN** the spell is absent and `play_card` on it returns `NO_LEGAL_TARGET` (enemy Stealth characters are not legal targets; friendly ones count); **GIVEN** a required-target Battlecry minion in the same state, **THEN** it is playable and no `battlecry` trigger event is emitted (the body is still a body); `targeting = optional` accepts `target_id = null`; `targeting = none` ignores `target_id`; a `required` target that is not legal → `ILLEGAL_TARGET`; missing → `TARGET_REQUIRED`; an accepted spell moves to zone `resolving`, emits `spell_cast` with the caster's Spell Damage total (F7), resolves, fires `after_cast`, then `card_to_graveyard`.
- [ ] AC-14 **GIVEN** a hero holding weapon W1 (durability 1) with a Deathrattle, **WHEN** weapon W2 is played, **THEN** events are `weapon_destroyed(W1)`, W1's `trigger_resolved`, then `weapon_equipped(W2)`, then W2's Battlecry and `on_card_played`; equipping never resets `attacks_used` (equipping a Windfury weapon after one attack leaves one more attack available — derived).
- [ ] AC-15 **GIVEN** the hero power unused and mana 2, **WHEN** `use_hero_power` is accepted, **THEN** mana is 0, `hero_power_used` is emitted, `used_this_turn == true`, the `hero_power` trigger point fires, and a second `use_hero_power` the same turn returns `HERO_POWER_USED` (checked before cost — a power reduced to 0 cost is still once per turn); after the next own Start step it is usable again; a `required`-target power with no legal target is not usable (spell rule) and is absent from `legal_commands()`.

---

## Implementation Notes

*Derived from ADR-0007 Decision 1 / Implementation Guidelines and GDD C6 / C7:*

- `play_card{hand_index, position, target_id}` — common prefix: phase = Main of issuer → `hand_index` in `0..hand.size()−1` else `INVALID_INDEX` → card type from `db.card(def_id)` → `effective_cost(card) <= mana_current` else `NOT_ENOUGH_MANA` (F1 is story 011; use base cost + `cost_modifiers` here with the hook fold added there). Then by type:
  - **Minion**: `board.size() < BOARD_SIZE` else `BOARD_FULL` → `0 <= position <= board.size()` else `INVALID_POSITION` → targeting via `resolver.targeting_spec(def_id)` + `resolver.legal_targets(def_id, source)`: `required` with ≥ 1 legal target → `target_id` must be legal (`TARGET_REQUIRED` / `ILLEGAL_TARGET`); `required` with none → playable, Battlecry will not resolve; `optional` → null ok; `none` → ignored. Accept: pay mana (`mana_spent`), move the card to `board[position]` as a new `Character` (`entity_id` from `next_entity_id`), emit `card_played` then `minion_summoned`; `stats.cards_played += 1`, `stats.minions_summoned += 1`; then four steps through `run_action`: (a) `resolver.resolve(&"battlecry", {source, target})` when the Battlecry has a target or needs none, (b) `hooks.run_triggers(&"on_card_played", side, {card})`, (c) `resolver.resolve(&"on_play", …)`, (d) `resolver.resolve(&"on_summon", …)`; `hooks.run_triggers(&"on_minion_summoned", …)` after the summon.
  - **Spell**: targeting first (`required` with no legal target → `NO_LEGAL_TARGET`, not playable — absent from `legal_commands()`), then pay mana, card → zone `resolving`, `spell_cast{spell_damage: F7 total}`, `resolver.resolve(&"on_cast", …)` (the spell's effect, one or more steps), `resolver.resolve(&"after_cast", …)`, card → graveyard (`card_to_graveyard`).
  - **Weapon**: targeting as for minions; pay mana; if a weapon is held → `weapon_destroyed` and queue its Deathrattle (death-check order, story 009) **before** `equip_weapon(side, def_id)` emits `weapon_equipped`; then the weapon's Battlecry, `on_card_played` hooks, `resolver.resolve(&"on_weapon_equipped", …)`.
- `use_hero_power{target_id}`: phase/turn → `used_this_turn` false else `HERO_POWER_USED` → `effective_cost(HERO_POWER_COST)` ≤ mana → targeting identical to spells. Accept: pay, `used_this_turn = true`, `hero_power_used`, `resolver.resolve(&"hero_power", {source: hero, target})`. Its content lives in Heroes / Card Effects.
- Mana is paid at command acceptance, before any effect resolves, and is never refunded — a fizzled Battlecry still cost its mana (C5).
- `legal_commands()` expands for the active side: each playable hand card × each valid position (minions) × each legal target, hero power × each legal target, plus `end_turn` (and `concede` for the player); attacks are added in story 012. Reuse the memoised `targeting_spec`; never recompute legality by trial-submitting.
- Spell Damage total F7: `Σ board spell_damage_bonus` (+ hero enchantments); Card Effects adds it to spell damage ops — the engine only reports it in `spell_cast`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 011: F1 `effective_cost` with hand auras and `modify_cost` hooks, temporary mana
- Story 012 / 013: attacks
- Story 016: a Battlecry / spell that raises a `ChoiceRequest` (Discover)
- Card Effects epic: `targeting_spec` derivation, `legal_targets` filters, what the Battlecry / spell / power does

---

## Files

- `src/gameplay/match/rules_engine.gd` (`play_card` minion / spell / weapon handlers and `use_hero_power` in C6 / C7 check order, `legal_commands()` expansion, `effective_cost` F1 base, `spell_damage` F7; the spell's `resolving` zone in record lookups; `_run_step(step, cause)` so play steps run under `card_played` / `spell_cast` / `hero_power_used`; constants `TARGETING_*`, `CARD_*`, the new `R_*` codes)
- `src/gameplay/match/match_state.gd` (PlayerState `resolving` — the spell being cast)
- `src/gameplay/match/match_records.gd` (`play_card` / `use_hero_power` command builders)
- `tests/unit/match_rules/match_rules_play_card_test.gd` (new, 15 tests)
- `tests/unit/match_rules/match_rules_data_model_test.gd` (PlayerState field list gains `resolving`)

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/match_rules/match_rules_play_card_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later). `qa.level: standard` — BLOCKING.

**Status**: [x] Created and passing (15 test functions)

---

## Dependencies

- Depends on: `production/epics/match-rules/story-009-resolution-loop.md`
- Unlocks: `production/epics/match-rules/story-011-effective-cost-and-temporary-mana.md`, `production/epics/match-rules/story-012-attack-legality.md`, `production/epics/match-rules/story-016-choice-phase-and-discover.md`

## Completion Notes
**Completed**: 2026-11-03 (started 23:33:29 UTC, ended 23:42:03 UTC)
**Criteria**: 4/4 passing — AC-11 (`test_minion_on_a_full_board_is_board_full`, `test_minion_position_outside_zero_to_board_size_is_invalid_position`, `test_played_minion_enters_the_slot_sick_and_runs_the_play_steps_in_order`, `test_play_card_checks_run_in_the_c6_order`), AC-13 (`test_required_target_spell_with_no_legal_target_is_not_playable`, `test_required_target_battlecry_with_no_legal_target_still_plays_its_body`, `test_required_target_rules_target_required_and_illegal_target`, `test_optional_target_accepts_null_and_none_ignores_target_id`, `test_accepted_spell_resolves_from_the_resolving_zone_then_goes_to_the_graveyard`, `test_a_resolving_spell_is_the_damage_source_for_lifesteal_and_stats`), AC-14 (`test_playing_a_weapon_destroys_the_old_one_and_resolves_its_deathrattle_first`), AC-15 (`test_hero_power_pays_marks_used_fires_and_is_once_per_turn`, `test_hero_power_is_usable_again_after_the_next_own_start_step`, `test_required_target_hero_power_with_no_legal_target_is_not_usable`), plus `test_legal_commands_expand_cards_positions_targets_and_the_hero_power` (C2). Watched fail: 15 of 15 against the story-009 engine (play_card / use_hero_power were `WRONG_PHASE`); mutant — the `resolving` zone dropped from the record lookups — fails the Lifesteal/stats test.
**Decisions recorded** (open item from story 008):
- **Where a cast spell lives:** a new PlayerState field `resolving` (Array of CardInstance, zone `resolving`) holds the spell from `spell_cast` until `card_to_graveyard`. `_find_record` / `_owner_of` / the in-play test search it, so a spell's `instance_id` is a damage source: its definition's Lifesteal / Poisonous apply and `damage_dealt_by_card` attributes to its `def_id`. C1's PlayerState list in the GDD should gain `resolving` (owner: match-rules GDD; `MatchState` is [S] for this story, the data-model test updated).
- **Battlecry with no legal target** (contract for card-effects story 006): the engine does **not** call `resolve(&"battlecry", …)` at all.
- **Play ctx** for `battlecry` / `on_cast` / `hero_power`: `{side, candidates: [host], source, target_id, card_id}` (spell: `source` = its instance id; minion / weapon: the new entity; power: the hero). Observer points carry `{side, candidates, subject, card_id}`. `legal_targets(def_id, source)` gets `{side, source_id, card_id}` (the hand card's instance id, or the hero for the power).
- Play steps run under `cause_seq` = `card_played` (minion, weapon), `spell_cast` (spell), `hero_power_used` (power) — card-effects C6.6.
**Deviations** (advisory):
- The play order follows card-effects C6.3 (the table testers assert), which adds two steps the story's notes do not list: `on_card_played` **observers** after the hooks, and the `on_minion_summoned` **hooks** between `on_play` and `on_summon` (the played minion is placed by the handler, not `summon_minion`, so its hooks run as their own steps there). Spells also run `on_card_played` hooks + observers between `on_cast` and `after_cast`; weapons skip `on_play`.
- Spells and weapons emit `card_played` too (C6 lists it for minions; C15 has one event for every play and `stats.cards_played` counts all).
- `legal_commands()` lists no `concede` (GDD C2 lists only the active side's expansions plus `end_turn`; story 008 decided the same) — the story's note said "and concede for the player".
- The C6 "type" check returns `INVALID_INDEX` for a hand card with no minion / spell / weapon definition (C2 has no type code); it is not double-failed in the order test.
- `TARGET_STEALTHED` is not produced: an enemy Stealth character is simply not in `legal_targets` (the resolver's filter), so it is `ILLEGAL_TARGET` / `NO_LEGAL_TARGET`.
- The hero power's cost is `rule("hero_power_cost")`; its `def_id` is not yet read from the hero record at `start` (still the C3 step 2 TODO) — tests set `hero_power.def_id`.
- No `card_factory.gd` additions: the fixtures are test-local `CardFactory` records; Deathrattle / Battlecry behaviour is scripted on the resolver double.
**Test Evidence**: `tests/unit/match_rules/match_rules_play_card_test.gd` (15 tests); full suite 848 test cases, 0 failures, exit 0, 45 SCRIPT ERROR lines (unchanged intentional negatives); smoke exit 0, no SCRIPT ERROR; parse check exit 0.
**Run result**: N/A — headless rules code; no scene, node or screen renders a play yet (Match UI is a later epic).
**Reviewed by**: self, no independent review (LP-CODE-REVIEW skipped — Lean mode; QL-TEST-COVERAGE skipped — Lean mode)

### Code-review fix pass (2026-11-04, started 02:08:14 UTC, ended 02:11:22 UTC; branch `fix/review-s3w2`)
Findings from `/code-review` sprint 3 wave 2 (2026-11-03) on this story, all fixed:
- **`resolving` on halt** (should-fix): a fault or `event_cap` mid-spell returned before the card left `resolving`. `_cast_spell` now always moves it to the graveyard; `card_to_graveyard` is emitted only while the match runs (the log is sealed after a halt). `_accept_spell` puts the card in `resolving` before its own halt check, so a refused `card_played` cannot strand it out of every zone.
- **`on_hero_power` observers** (should-fix, card-effects C6.3 "Hero power used" step 2): fired as their own step after the host `hero_power` step, `subject` the hero, `card_id` the power, under `hero_power_used`.
- **`on_summon` for effect summons** (should-fix, card-effects C6.3 "Minion summoned by an effect", needed by card-effects 008 AC-17): `summon_minion` raises `on_summon {subject, card_id}` after its `on_minion_summoned` hooks; its observers queue under `minion_summoned`. The played minion still gets exactly one `on_summon` (the handler places it without `summon_minion`).
- **`on_card_played` ctx** (nit, card-effects C2 `trigger_subject` = the card instance): the observers' ctx carries `instance_id` for minions, spells and weapons; `subject` is unchanged.
Tests added (6, in `match_rules_play_card_test.gd`, now 21): `test_a_spell_faulted_mid_resolution_leaves_the_resolving_zone`, `test_a_spell_stopped_by_the_event_cap_leaves_the_resolving_zone`, `test_hero_power_fires_on_hero_power_observers_after_the_host_step`, `test_an_effect_summoned_minion_raises_on_summon_after_its_hooks_and_no_play_points`, `test_on_summon_fires_once_for_a_played_minion_and_once_per_effect_summon` (AC-17's +2/+2 vs +1/+1 at engine level), `test_on_card_played_observers_get_the_card_instance_id`. Watched fail: 6 of 6 on the unfixed engine. Full suite 1070 test cases, 0 failures, exit 0, 85 SCRIPT ERROR lines (unchanged intentional negatives); smoke exit 0, no SCRIPT ERROR.
Not in scope (left for story 016): a spell that pauses for a Discover choice still continues to `after_cast` and the graveyard.
