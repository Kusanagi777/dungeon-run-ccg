# Story 002: Treasures in a live match — installation order, duplicate skip, no back-reference, clone

> **Epic**: Treasures
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-11-04
> **Last Updated**: [set by /dev-story when implementation begins]
> **First Playable path**: no (it proves the boss passive's order against treasures; the First Playable runs no treasure)

## Context

**GDD**: `design/gdd/treasures.md` (T2.1–T2.4, T3.3–T3.6, Edge Cases "Installation and ordering", AC-2, AC-3, AC-6, AC-7)
**Requirement**: `TR-treasures-001`, `TR-treasures-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Owner-scoped hook registry (most direct); ADR-0007: Effect Resolver / Validator Boundary (`bind` installs, the evaluators run entries, the clone binds a fresh resolver)
**ADR Decision Summary**: `RulesEngine.start` builds `state.hooks = HookRegistry.new()` and calls `resolver.bind(engine, player.hook_installers + boss.hook_installers)` as C3 step 1, so the order is treasures in pick order, each `effects[]` in array order, then the passive. A duplicate `host_id` installs nothing and the engine logs `hook_install_skipped`. Entries are plain data with no back-reference, and `copy()` is by value with evaluators unset.
**ADR Version**: 2026-11-03 (ADR-0005); 2026-11-03 (ADR-0007)

**Engine**: Godot 4.7.2 | **Risk**: HIGH (language, by version); LOW for the APIs
**Engine Notes**: ADR-0005 Engine Compatibility — lambdas capture by value: evaluators take the entry and context as arguments; ADR-0007 `NOT SOURCEABLE — RefCounted cycle collection` (the clone is ended with `end_match()` on every path).

**Control Manifest Rules (this layer)**:
- Required: ordering is installation order (`MatchConfig.player.hook_installers`, each `effects[]` in array order, then `boss.hook_installers`); `install()` returns `false` on a duplicate `host_id` and the engine appends `hook_install_skipped`; `copy()` by value with evaluators unset; every clone ended with `end_match()` then dropped (Core)
- Forbidden: never sort entries or add a `priority`; `HookRegistry` / `HookEntry` / `HookInstaller` never reference `RulesEngine`, `EventLog`, `MatchState`, a Node, an autoload or the registry itself; never append to a log from the registry
- Guardrail: ≤ 12 entries per match (`entry_count()` asserted in debug); `copy()` ≤ 12 small `duplicate(true)` calls per clone

The registry and the binding are done (match-rules 002 and 003). This story runs them with **real** treasure installers from story 001 and the real resolver, and proves the T2/T3 guarantees that retire TD-009's modifier half.

---

## Acceptance Criteria

*From GDD `design/gdd/treasures.md` (AC-2, AC-3, AC-6, AC-7), scoped to this story:*

- [ ] **AC-2** GIVEN installers for `[treasure_worn_signet, treasure_hollow_crown]` plus `boss_test_taxman`'s passive, WHEN the match starts, THEN `MatchState.hooks.entries(&"modify_cost")` holds entries in the order `[signet, taxman]` and `entries(&"on_match_start")` holds `[crown]`; the hero power's displayed cost is `fold(2) = set 1 → +1 = 2`.
- [ ] **AC-3** GIVEN installers `[signet, signet]` (a duplicate that reached the registry), WHEN bound, THEN exactly one `modify_cost` entry exists and exactly one `hook_install_skipped{host_id: treasure_worn_signet, reason: duplicate}` is logged.
- [ ] **AC-6** GIVEN a headless unit test with no `SceneTree` and no autoload, WHEN a `HookRegistry` is built from `installers_for` and `on_turn_start` is invoked, THEN the entries run and no object in the chain holds a `Node` or a reference back to the registry (reflection check over `HookEntry` values and `HookInstaller` properties).
- [ ] **AC-7** GIVEN a match with `[treasure_hollow_crown, treasure_thornhide_cloak]` installed, WHEN `RulesEngine.clone()` is advanced one boss action, THEN the clone's hook results equal a real advance's results and the real log gained no event.

---

## Implementation Notes

*Derived from ADR-0005 Decision (rules 2, 5, 6, 7, 11) and ADR-0007 Decision 3:*

- Build `MatchConfig` the way `RunMachine.begin_match` will (R3): `player.hook_installers = treasures.installers_for(ids, {schema_version: 1, by_treasure: {}})` and `boss.hook_installers = Treasures.passive_installer(boss_def)`. Use `tests/helpers/match_factory.gd` for the rest of the config.
- AC-2's displayed cost is `RulesEngine.hero_power_cost(side)`, which goes through `HookRegistry.fold(&"modify_cost", …)` and the resolver's `apply_value_hook` (card-effects 014). The clamp is applied once after the fold, by the engine.
- AC-3 bypasses `installers_for`'s own de-duplication on purpose: it hands the engine two equal installers to prove the second guard (T3.4). The skip is already logged by `RulesEngine._log_skipped_installers` (match-rules 003). This story asserts it with real treasure data and changes no engine code unless a test fails.
- AC-6's "entries run" needs real evaluators, so bind through a real `EffectResolver` (`run_hook_effect`, card-effects 015) with an `on_turn_start` treasure from the fixture (Scholar's Candle) or a one-op fixture treasure. The reflection check walks `HookEntry` dictionary values recursively and asserts no `Object` other than plain containers.
- AC-7: crown's effect is an `on_match_start` trigger. Cloak's is an **in-primitive** `on_hero_damaged` hook, synchronous inside `apply_damage` with no C10 loop between entries (ADR-0005 erratum 2026-11-03). Pick a boss action that damages the player hero, so the cloak fires on both the clone and the live engine. Clone contract: `RulesEngine.clone()` → act → compare → `end_match()` on the clone on every path.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: building the installers; Story 004: the F5 fold budget
- Stories 005–008: each MVP treasure's behaviour
- Card-effects 014 / 015: `apply_value_hook`, `run_hook_effect` (the evaluators this story drives)

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `tests/integration/treasures/treasures_installation_test.gd`
- `tests/unit/treasures/treasures_chain_purity_test.gd` (AC-6, headless)
- No production file planned. A failing assertion becomes a fix in the file that owns the behaviour, recorded on `/dev-story`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/treasures/treasures_installation_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/treasures/story-001-installers-passive-and-collect-state.md`. Cross-epic: `production/epics/card-effects/story-014-value-hook-folds.md` (AC-2's fold), `production/epics/card-effects/story-015-hook-trigger-steps-hero-slot-observers.md` (AC-6 / AC-7 trigger entries); Complete: `production/epics/match-rules/story-003-match-setup.md`, `production/epics/match-rules/story-017-clone-and-replay.md`
- Unlocks: `production/epics/treasures/story-004-hook-chain-cost-bound-and-purity.md`
