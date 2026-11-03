# Story 010: Playing minions, spells, weapons and the hero power

> **Epic**: Match Rules
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

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

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/gameplay/match/rules_engine.gd` (`play_card` minion/spell/weapon handlers, `use_hero_power`, `legal_commands` expansion, `effective_cost` base)
- `tests/helpers/test_effect_resolver.gd` (scripted `targeting_spec` / `legal_targets` per `def_id`)
- `tests/helpers/card_factory.gd` (fixture set additions if the 2/2 weapon with Deathrattle and the required-target Battlecry minion are missing)
- `tests/unit/match_rules/match_rules_play_card_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/match_rules/match_rules_play_card_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later). `qa.level: standard` — BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/match-rules/story-009-resolution-loop.md`
- Unlocks: `production/epics/match-rules/story-011-effective-cost-and-temporary-mana.md`, `production/epics/match-rules/story-012-attack-legality.md`, `production/epics/match-rules/story-016-choice-phase-and-discover.md`
