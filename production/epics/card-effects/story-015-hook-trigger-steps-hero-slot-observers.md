# Story 015: Trigger hooks as synchronous steps and hero-slot observers (treasures, boss passives)

> **Epic**: Card Effects
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/card-effects.md`
**Requirement**: `TR-card-effects-004` (C9: trigger hooks as synchronous steps; hook-less event triggers as hero-slot observers)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Owner-scoped hook registry (most direct); ADR-0007: Effect Resolver / Validator Boundary (`run_hook_effect` is the resolver's bound method)
**ADR Decision Summary**: Trigger entries run synchronously as their own step at the hook point, each followed by the full C10 loop, in installation order (treasures in pick order, then the boss passive); hook-less treasure/passive event triggers (`on_play`, `after_cast`, `on_attack`, `on_damage_dealt`, `on_heal`, `on_minion_died`, `on_hero_power`, `on_weapon_equipped`, non-hero `on_damage_taken`) are hero-slot observers queued by the resolver in candidate order and never enter the registry; `source_id` in every event they emit is the treasure or passive id.
**ADR Version**: 2026-11-03 (ADR-0005); 2026-11-03 (ADR-0007)

**Engine**: Godot 4.7.2 | **Risk**: HIGH (language, by version); LOW for the APIs
**Engine Notes**: ADR-0005 Engine Compatibility — evaluators receive the entry and context as arguments (lambdas capture by value, sourced); no `NOT SOURCEABLE` item.

**Control Manifest Rules (this layer)**:
- Required: ordering is installation order — `player.hook_installers` (pick order), each `effects[]` in array order, then `boss.hook_installers`; hook-less treasure event triggers are hero-slot observers queued by the resolver; match-tier hook state (`once_per_turn` marks, counters) lives in `EffectRuntime` keyed by treasure id; `side` is passed on every invocation
- Forbidden: never add hook-less treasure triggers to the registry "because they are treasure effects"; never let the registry evaluate the DSL; never add a hook point without a match-rules GDD change and a C2 row; `HookRegistry` never appends to a log
- Guardrail: ≤ 12 entries per match (`entry_count()` asserted in debug); three treasures add < 2 ms per match

---

## Acceptance Criteria

*From GDD `design/gdd/card-effects.md` (C2 hook column, C6.3 order table, C9, Edge Cases "Hooks and passives"; AC-16, AC-25, AC-36, AC-45), scoped to this story:*

- [ ] **AC-16** GIVEN a treasure "at the start of your turn gain 1 Armor" (hook `on_turn_start`) and row 34 on the player's board, WHEN the player's Start step runs, THEN `armor_gained` precedes both `damage_dealt` events; exactly one `trigger_resolved{trigger: turn_start}` sits between `armor_gained` and the first `damage_dealt` (the hook step, then row 34's queued pass), and **no** `trigger_resolved` sits between the two `damage_dealt` (both pings are one pass, C6.0); the step counter rose by 2. At the End step the order is reversed: card `turn_end` observers first, then `on_turn_end` hooks (C6.3 — the one exception).
- [ ] **AC-36** GIVEN row 38 (treasure "At the start of the match, gain 10 Armor", `on_match_start`) installed, WHEN `start` runs, THEN `armor_gained{10}` appears before the first `card_drawn`, with `source_id` equal to the treasure id; two treasures run in pick order and the boss passive after all treasures; a duplicate `host_id` installs nothing and the engine logs `hook_install_skipped{host_id, reason: duplicate}`.
- [ ] **AC-25** GIVEN row 37 (boss passive "whenever the player heals, deal 1 to their hero", `on_heal` — no hook column) and a player minion "whenever you heal, gain +1/+1", WHEN the player heals, THEN the log reads `healed`, then the minion's `enchantment_applied`, then the passive's `damage_dealt{amount: 1}` with `source_id` equal to the passive id — two `trigger_resolved{trigger: on_heal}` in that order (player-side observers before the boss hero-slot observer).
- [ ] **AC-45** GIVEN a treasure "whenever a friendly minion dies, summon a 1/1 Husk — once per turn" (`on_minion_died`, hero-slot observer, `once_per_turn`) and row 11 on board, WHEN two friendly minions die in one death check, THEN exactly one `minion_summoned{decay_husk}` with `source_id` equal to the treasure id, its `trigger_resolved` **after** row 11's two, and no `E_FX_TRIGGER` at load (the `once_per_turn` mark is keyed on the treasure id).

---

## Implementation Notes

*Derived from ADR-0005 Decisions 1–4, 8–9, 11 and ADR-0007 Key Interfaces:*

- `func run_hook_effect(entry: HookEntry, side: StringName, ctx: Dictionary) -> void`: evaluate `scope` relative to `entry.side`; if it matches, run **one pass now** (story 006's `_run_pass`) with host context `{host_kind: entry.host_kind, host_id: entry.host_id, source_id: entry.host_id, owner: entry.side}`; the engine treats the call as one step and runs the C10 loop after it (`HookRegistry.run_triggers` loops entries; the engine owns the loop).
- `bind` (story 002) classifies each installer effect by C2: value trigger → `install` as a value entry; event trigger with a hook column → `install` as a trigger entry; `aura` → the resolver's aura source list (story 013); event trigger with hook column `—` → the resolver's **hero-slot observer list** for `entry.side`, never `install`. The registry's `entry_count()` therefore counts only the first two kinds.
- Hero-slot observers are candidates at the "hero power / hero enchantments" position of their side in the engine's candidate order (C6.3): the engine passes `ctx.candidates` as entity ids; agree with match-rules how the hero slot is represented in `candidates` (a sentinel id per side, or the resolver appending its observers at that position when it sees the hero id) and record it on `/dev-story`. Both sides' hero slots appear in every candidate list — a boss passive observing the player's heal is simply a boss-side candidate.
- A treasure/passive is always a live source: never Silenced, never leaves play; its `entity_id` for `once_marks` and `counters` is the treasure/passive id (story 009's keys accept a String id).
- `HookRegistry`, `HookEntry`, `HookInstaller` live in `src/gameplay/match/` (match-rules) and `Treasures.installers_for` / `passive_installer` in `src/gameplay/treasures/`; this story writes none of them.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 014: value folds
- Story 013: treasure auras
- match-rules: `HookRegistry`, the 12 engine hook call sites, `hook_install_skipped`; `production/epics/treasures/`: Grave Tithe's real record, `collect_state`, the pool

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/gameplay/effects/effect_resolver.gd` (`run_hook_effect`, installer classification in `bind`, hero-slot observer list)
- `src/gameplay/effects/scope.gd`
- `tests/unit/card_effects/card_effects_hook_triggers_observers_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/card_effects/card_effects_hook_triggers_observers_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/card-effects/story-002-runtime-binding-config.md`, `production/epics/card-effects/story-008-event-observers-queueing.md`, `production/epics/card-effects/story-009-deathrattle-snapshot-counters.md` (`once_per_turn` keyed by treasure id), `production/epics/card-effects/story-014-value-hook-folds.md` (shared `scope.gd`, installer classification). Cross-epic: `production/epics/match-rules/` (`HookRegistry.run_triggers`, hook call sites, candidate order), `production/epics/treasures/` (`HookInstaller`, `passive_installer`).
- Unlocks: `production/epics/treasures/` trigger-hook and observer treasures; `production/epics/content/` boss passives; `production/epics/card-effects/story-016-determinism-clone-bounds-perf.md`
