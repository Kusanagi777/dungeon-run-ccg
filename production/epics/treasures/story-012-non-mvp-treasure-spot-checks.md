# Story 012: Non-MVP treasure spot checks — Grave Tithe, Living Armory, Focusing Prism, Mending Charm

> **Epic**: Treasures
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-11-04
> **Last Updated**: [set by /dev-story when implementation begins]
> **First Playable path**: no — Alpha scope (the records ship with Content's Alpha treasure batches; tested here from the fixture)

## Context

**GDD**: `design/gdd/treasures.md` (T2.5, T8 rows 10, 13, 16, 18; T9; Edge Cases "Content specifics"; AC-25, AC-26, AC-27, AC-28) · `design/design-decisions.md` DD-X12
**Requirement**: `TR-treasures-001` (owner-scoped hosts, hero-slot observers)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Owner-scoped hook registry (most direct: hook-less treasure event triggers are hero-slot observers, never registry entries; `once_per_turn` keyed on the treasure id); ADR-0007: Effect Resolver / Validator Boundary (observer queueing; `pool: collectible` needs `player_hero_set`)
**ADR Decision Summary**: `on_minion_died` on a treasure host has no hook column, so the resolver queues it as a hero-slot observer in candidate order. `modify_damage` folds +1 per `apply_damage`, and `turn_end` runs as an `on_turn_end` hook step. `add_to_hand from {pool: collectible}` draws from `rng_match`, and it offers nothing without the run hero's set. ADR-0007 erratum 2026-11-04: `EffectResolver._init(db, effects_config, player_hero_set)`.
**ADR Version**: 2026-11-03 (ADR-0005); 2026-11-03 (ADR-0007)

**Engine**: Godot 4.7.2 | **Risk**: HIGH (language, by version); LOW for the APIs
**Engine Notes**: ADR-0005 / ADR-0007 Engine Compatibility — no post-cutoff API. Living Armory runs at `on_match_start` and adds a card: it is not a Discover, so ADR-0005's 2026-11-04 erratum (Discover refused at `on_match_start`) does not apply.

**Control Manifest Rules (this layer)**:
- Required: hook-less treasure event triggers are hero-slot observers queued by the resolver; `EffectRuntime` keys match-tier marks by treasure id; `EffectResolver._init(db, effects_config, player_hero_set)` gets the run hero's set (composition)
- Forbidden: never add hook-less treasure triggers to the registry; `EffectResolver` never touches a `RandomNumberGenerator` (draws only through `engine.rng_match()`)
- Guardrail: `RulesEngine.submit()` ≤ 5 ms

---

## Acceptance Criteria

*From GDD `design/gdd/treasures.md` (AC-25 to AC-28), scoped to this story:*

- [ ] **AC-25** Grave Tithe: WHEN two friendly minions die in one action, THEN one `decay_husk` is summoned at the board's right end; WHEN the board is full, THEN `summon_failed{board_full}` and no second Husk that turn even if another minion dies.
- [ ] **AC-26** Living Armory: GIVEN a collectible pool with no Legendary minion, THEN `effect_resolved.ops[0].outcome = empty_pool` and the hand is 3 after starting draws; GIVEN the full v1 pool and seed `00000000000000A7` twice, THEN the same Legendary is added both times.
- [ ] **AC-27** Focusing Prism: WHEN "deal 1 damage to all enemy minions" is cast at three enemy minions, THEN each takes 2 and `effect_resolved.values` show `hook_delta: +1` per target.
- [ ] **AC-28** Mending Charm: WHEN the owner's turn ends at full health, THEN `healed{amount: 0, source_id: treasure_mending_charm}` is emitted and the feed shows "(no effect)".

---

## Implementation Notes

*Derived from ADR-0005 Decision rule 9, ADR-0007 Decision 1 and its 2026-11-04 erratum:*

- All four records come from the 20-record fixture (story 001). None is in the MVP `treasures.json` (CN-5). Living Armory's `unlock` is `first_victory` (DD-X12). That does not matter here: `installers_for` never checks unlocks (story 009).
- AC-25's `once_per_turn` mark is set when the observer is **queued** (C6.7), so a full-board `summon_failed` still consumes it. "Once per turn" counts the global `match.turn`, so the boss's turn allows another Husk (Edge Cases). Card-effects 015 AC-45 proves the observer mechanics on a fixture row. This story proves the T8 record.
- AC-26 needs the resolver built with `player_hero_set` (the run hero's set, `war` for `hero_war`). Without it `pool: collectible` logs an error and offers nothing, so a missing argument would read as `empty_pool` and the second half of AC-26 could pass for the wrong reason. Assert that the first case's pool really is empty of Legendary minions, and that the second case adds a non-null card. The random pick draws from `match_<floor>` after the deck shuffles (C3 step 3 → 4).
- AC-28's "(no effect)" is a Match UI feed line, not the rules tier (treasures UI Requirements row 3). Assert `healed{amount: 0}` here, and assert the feed text either in a Match UI feed-formatter unit test if one exists or by recording it as Match UI's in Completion Notes. Do not build UI in this epic.
- AC-27's `hook_delta` is the field card-effects 014 emits on `effect_resolved.values`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Card-effects 015: the observer queue (AC-25, AC-45 there); card-effects 014: `modify_damage` evaluator
- Match UI epic: the feed's "(no effect)" rendering
- The other non-MVP treasures (Ledger, Boots, Rotting Bargain, Plague Bell, Grimoire, Captured Standard): Content's Alpha batches, validated by story 003 at load

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `tests/integration/treasures/treasures_non_mvp_spot_checks_test.gd`
- No production file planned

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/treasures/treasures_non_mvp_spot_checks_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/treasures/story-001-installers-passive-and-collect-state.md`. Cross-epic: `production/epics/card-effects/story-014-value-hook-folds.md` (Prism), `production/epics/card-effects/story-015-hook-trigger-steps-hero-slot-observers.md` (Tithe, Charm, Armory); Complete: `production/epics/card-effects/story-010-discover-choose-one.md` (`pool: collectible` with `player_hero_set`)
- Unlocks: Content's Alpha treasure batches (rows 10, 13, 16, 18)
