# Story 007: Trigger-hook treasures — Hollow Crown, Scholar's Candle, Iron Constitution, Thornhide Cloak

> **Epic**: Treasures
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-11-04
> **Last Updated**: [set by /dev-story when implementation begins]
> **First Playable path**: no

## Context

**GDD**: `design/gdd/treasures.md` (T2.2, T8 rows 1, 6, 8, 9; T9; Edge Cases "Content specifics"; AC-15, AC-18, AC-20, AC-21)
**Requirement**: `TR-treasures-001` (T2.2 trigger hooks run as their own step)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Owner-scoped hook registry (most direct); ADR-0007: Effect Resolver / Validator Boundary (`run_hook_effect`; ops through primitives only)
**ADR Decision Summary**: Trigger entries run synchronously as their own step at the hook point, each followed by the full C10 loop. The in-primitive hooks (`on_draw`, `on_hero_damaged`, `on_minion_summoned`) run inside the primitive, with no C10 loop between entries; a re-entry of the same point faults `resolution_overflow`. Every event a treasure causes carries `source_id` = the treasure id.
**ADR Version**: 2026-11-03 (ADR-0005); 2026-11-03 (ADR-0007)

**Engine**: Godot 4.7.2 | **Risk**: HIGH (language, by version); LOW for the APIs
**Engine Notes**: ADR-0005 Engine Compatibility — no post-cutoff API. ADR-0005 errata 2026-11-03 / 2026-11-04 (in-primitive hooks synchronous; a Discover from one, or from `on_match_start`, is refused) apply: none of these four raises a Discover.

**Control Manifest Rules (this layer)**:
- Required: in-primitive hooks run synchronously inside the primitive; `EffectResolver` mutates only through primitives and emits only through `engine.emit`; magnitudes from `treasures.json`
- Forbidden: never raise a Discover from an in-primitive hook or `on_match_start`; never write match state from `src/gameplay/effects/**` (gate G7)
- Guardrail: `RulesEngine.submit()` ≤ 5 ms

---

## Acceptance Criteria

*From GDD `design/gdd/treasures.md` (AC-15, AC-18, AC-20, AC-21), scoped to this story:*

- [ ] **AC-15** Hollow Crown: WHEN `match_started`, THEN the `on_match_start` hook calls `add_mana(PLAYER, 1, temporary=false)`, and `mana_added{side: player, n: 1, temporary: false}` (its `cause_seq` → `effect_resolved{source_id: treasure_hollow_crown}`) precedes the first `card_drawn`; `PlayerState.crystal_bonus` is 1 and every Start step reads `mana_max = min(turns_taken + crystal_bonus, 10)`, so player turn 1 reads 2/2 (with `crystal_gained`), turn 8 reads 9/9, turns 9 and 10 read 10/10; the boss's `crystal_bonus` stays 0 and its turn 1 reads 1/1.
- [ ] **AC-18** Scholar's Candle: THEN exactly one extra `card_drawn` with `cause_seq` → `effect_resolved{source_id: treasure_scholars_candle}` occurs at the Start of player turns 2 and 4 (`match.turn` 3 and 7), before that turn's natural draw, and none on turns 1, 3, 5.
- [ ] **AC-20** Iron Constitution: THEN `match_started` shows the player hero at 40/40 with one `enchantment_added{source_id: treasure_iron_constitution, health_delta: 10}`; after 15 damage the hero reads 25/40.
- [ ] **AC-21** Thornhide Cloak: GIVEN hero 30 health / 0 Armour, WHEN a boss minion deals 3, THEN `armor_gained 1` follows `damage_dealt` in the same action (27 health, 1 Armour); WHEN a fatigue tick of 1 hits, THEN Armour absorbs it and a new `armor_gained 1` follows.

---

## Implementation Notes

*Derived from ADR-0005 Decision rule 4 (+ errata) and ADR-0007 Decision 1:*

- Installers come from `installers_for` (story 001) over the 20-record fixture; seed `00000000000000A7`, hero `hero_war`.
- Event names: the GDD's ACs use `enchantment_added`. The match-rules C15 spelling is authoritative (DD-X04), and the engine emits `enchantment_applied` (card-effects 011). Assert the C15 name and note the GDD spelling in Completion Notes. The same applies to any other C15 rename found.
- Crown's crystal is match-rules' `crystal_bonus` (R-1, C-02). The Start-step formula is the engine's (match-rules 005, Complete). This story asserts that a treasure reaches it through the hook.
- Candle's condition `match.turn ∈ {3, 7}` is in the record (DD-M03: player turn n = `match.turn` 2n − 1). The ordering "before that turn's natural draw" is C4 Start step 4 (hooks) before the draw step.
- Cloak is an in-primitive `on_hero_damaged` hook with `min_amount: 1`. Fatigue damage and fully-absorbed damage both report `amount_dealt ≥ 1` (F2: `dealt` includes `armor_absorbed`), so it fires in both cases. That is intended and legible (Edge Cases).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 008: auras; Story 012: Mending Charm (`on_turn_end`), Grave Tithe (observer), Living Armory
- Card-effects 015: `run_hook_effect` and hook step ordering (AC-16, AC-36 there)

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `tests/integration/treasures/treasures_trigger_hooks_test.gd`
- No production file planned

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/treasures/treasures_trigger_hooks_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/treasures/story-001-installers-passive-and-collect-state.md`. Cross-epic: `production/epics/card-effects/story-015-hook-trigger-steps-hero-slot-observers.md`; Complete: `production/epics/match-rules/story-005-turn-structure-and-mana.md`, `production/epics/match-rules/story-007-damage-heal-armor.md`
- Unlocks: `production/epics/treasures/story-010-treasures-balance-validator-and-data-driven-magnitudes.md`, `production/epics/treasures/story-011-restart-and-resume-reinstall.md`; content story 006 behaviour sign-off for rows 1, 6, 8, 9
