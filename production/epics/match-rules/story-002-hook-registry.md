# Story 002: HookRegistry: install order, fold, copy

> **Epic**: Match Rules
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/match-rules.md` (Interactions — hook points table and the fold rule; C1 `hooks`)
**Requirement**: `TR-match-rules-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Owner-scoped hook registry (also ADR-0007 for `set_evaluators`)
**ADR Decision Summary**: `HookRegistry` is a plain `RefCounted` on `MatchState.hooks`, created by `RulesEngine.start`, storing per hook point an `Array` of `HookEntry` dictionaries `{host_kind, host_id, side, effect_id, effect, state}` in installation order only; value hooks fold entry-to-entry and the engine clamps exactly once after the fold; `copy()` is by value with evaluators unset; the registry evaluates nothing itself.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: LOW for the APIs used (`RefCounted`, `Dictionary`, `Array`, `StringName`, `Callable` — unchanged through 4.7); HIGH for GDScript generally. Two sourced rules apply: lambdas capture locals by value, so the evaluators receive the entry and context as arguments and never close over mutable locals; an override of a typed method returns explicitly (4.7) — relevant to any test double of `HookRegistry`. No engine-level verification required (no sort, so no `sort_custom` stability question).

The registry is the seam Treasures and the boss passive use to alter match rules without touching Match Rules code. It is deliberately dumb: it stores entries, iterates them in the order they were installed and calls back through two Callables the resolver registers at `bind`. This story replaces the prototype's `ModifierManager` and retires the modifier half of TD-009. Tests use a scripted pair of evaluator Callables (no resolver needed).

**Control Manifest Rules (this layer)**:
- Required: `HookRegistry` is a plain `RefCounted` owned by `MatchState` … in installation order; it evaluates nothing itself — the resolver registers `set_evaluators(apply_value_hook, run_hook_effect)` at `bind`; hook catalogue = match-rules' table (7 trigger points, 5 value points, no gate points); ordering is installation order; value folds — entry *n*'s output is entry *n+1*'s input (`delta` adds, `set` replaces, `mul` multiplies), the fold mutates and allocates nothing, the engine clamps exactly once after the whole fold; `install(installer)` returns `false` on a duplicate `host_id`; `side` is passed on every invocation; `copy()` is a by-value copy with evaluators unset (ADR-0005)
- Forbidden: never a global priority-ordered modifier manager; never signals / an event bus for hooks; never let the registry evaluate the DSL itself; `HookRegistry`, `HookEntry` and `HookInstaller` never reference `RulesEngine`, `EventLog`, `MatchState`, a Node, an autoload or the registry itself; never sort entries or add a `priority`, `weight` or `order` field; never clamp inside the fold; never allocate in the fold; never append to a log from the registry; never give an entry `is_enabled`, `duration_turns`, `stacks` or removal in v1 (ADR-0005)
- Guardrail: hook fold — 12-entry fold < 0.05 ms; ≤ 12 entries per match (`entry_count()` asserted in debug); `copy()` ≤ 12 small `duplicate(true)` calls per Boss AI clone (ADR-0005)

---

## Acceptance Criteria

*From GDD `design/gdd/match-rules.md` Interactions (hook table, fold rule) and ADR-0005 Decision rules 1–7, scoped to this story:*

- [ ] Installation order **GIVEN** two player installers (`host_id` `t_a`, `t_b`, each with two `effects[]` on `modify_cost`) and one boss installer (`host_id` `boss_p`, one `on_turn_start` effect and one `modify_cost` effect), **WHEN** installed in `MatchConfig.player.hook_installers` then `boss.hook_installers` order, **THEN** `entries(&"modify_cost")` holds five `HookEntry` dictionaries in the order `t_a[0], t_a[1], t_b[0], t_b[1], boss_p[…]`, each with exactly the keys `{host_kind, host_id, side, effect_id, effect, state}` and `side` `"player"` / `"boss"` (the `MatchFactory.SIDE_*` strings); `entry_count() == 6`; `hosts()` lists the three hosts with their `state` blobs; and no entry carries `priority`, `weight`, `order`, `is_enabled`, `duration_turns` or `stacks`.
- [ ] Duplicate host **GIVEN** `t_a` already installed, **WHEN** `install(t_a_again)` is called, **THEN** it returns `false`, `entry_count()` is unchanged and `entries(point)` is unchanged for every point; a fresh registry given the same installer list yields an equal registry (idempotent).
- [ ] Fold semantics **GIVEN** evaluators set to a scripted `fold_entry` that applies `delta −1`, `delta −1`, `delta −1` in turn, **WHEN** `fold(&"modify_cost", "player", 1, ctx)` runs, **THEN** the result is `−2` (no clamp inside the fold — the caller clamps once; `1 − 1 − 1 − 1 → −2`, not `0`), the evaluator received entry *n*'s output as entry *n+1*'s input and the same `side` and the same `ctx` object on every call, and `fold` returned the input unchanged when `entries(point)` is empty; a `set 2` entry followed by `mul 3` yields `6`.
- [ ] Copy by value **GIVEN** a registry with evaluators set and three entries, **WHEN** `copy()` is called and an entry's `effect` Dictionary in the copy is mutated, **THEN** the original is unchanged (`duplicate(true)`), the copy's evaluators are unset (a `fold` on the copy before `set_evaluators` returns the input unchanged / `run_triggers` runs nothing), `entry_count()` matches, and `gate(point, side, ctx)` returns `true` for every point (no gate points in v1; `GATE_POINTS` is empty).

---

## Implementation Notes

*Derived from ADR-0005 Implementation Guidelines and Key Interfaces:*

- File `src/gameplay/match/hook_registry.gd`, `class_name HookRegistry extends RefCounted`, with the constants `TRIGGER_POINTS = [on_match_start, on_turn_start, on_turn_end, on_card_played, on_minion_summoned, on_hero_damaged, on_draw]`, `VALUE_POINTS = [modify_cost, modify_damage, modify_heal, modify_starting_hand_size, modify_max_attacks]`, `GATE_POINTS = []`, and the methods `install(installer) -> bool`, `set_evaluators(fold_entry: Callable, run_entry: Callable)`, `entries(point) -> Array` (read-only view, installation order), `fold(point, side, value, ctx) -> int`, `run_triggers(point, side, ctx) -> void`, `gate(point, side, ctx) -> bool` (reserved: AND, short-circuit, `true` when empty), `hosts() -> Array[Dictionary]`, `copy() -> HookRegistry`, `entry_count() -> int`.
- `HookEntry` is a Dictionary shape, never a class with behaviour. `HookInstaller extends RefCounted` with `host_kind`, `host_id`, `side`, `effects: Array`, `state: Dictionary`, `to_dict()` / `static from_dict()` — `src/gameplay/match/hook_installer.gd` (Treasures T3.2 builds them; this story defines the type).
- `install` iterates `installer.effects` in array order and appends one entry per effect to `entries[effect.hook_point]`; a `host_id` already in `hosts` → return `false`, install nothing. The **engine** logs `hook_install_skipped{host_id, reason: duplicate}` (story 003) — the registry has no log.
- `fold`: `for e in entries[point]: value = fold_entry.call(e, side, value, ctx)`; return `value`. No `duplicate()`, no array built per invocation, no clamp. `run_triggers`: `for e in entries[point]: run_entry.call(e, side, ctx)` — each call is one step and the **engine** runs the C10 loop after it (story 009).
- `copy()`: new registry, each entry `duplicate(true)`, `hosts` copied, evaluators left unset. `MatchState.clone()` (story 017) calls it and the clone's resolver rebinds.
- Scope evaluation (`entry.side` vs the `side` argument; card-effects C2 scope keys) is the **resolver's** job inside `apply_value_hook` / `run_hook_effect` — the registry only passes `side` through. Never special-case "player only" here.
- Match-tier hook state (`once_per_turn`, counters) lives in `EffectRuntime` (ADR-0007), not here; `entry.state` is the read-only run-tier blob.
- Assert `entry_count() <= 12` in debug (`assert(...)` is stripped in release, which is the intent).
- After this story `MatchFactory.make_match_state` sets `hooks` to `HookRegistry.new()` where it used `[]` (the epic's `TODO(E1/E2)` swap).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: creating the registry in `start()`, calling `resolver.bind`, logging `hook_install_skipped`
- Story 007 / 011 / 012: the engine's single clamp after each fold (`modify_damage`/`modify_heal`, `modify_cost`, `modify_max_attacks`)
- Card Effects epic: `EffectResolver.apply_value_hook` / `run_hook_effect` (the real evaluators) and scope evaluation
- Treasures epic: `Treasures.installers_for`, `passive_installer`, `collect_state`

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/gameplay/match/hook_registry.gd`
- `src/gameplay/match/hook_installer.gd`
- `tests/helpers/match_factory.gd` (`hooks: []` → `HookRegistry.new()`; `make_hook_installer` helper)
- `tests/unit/match_rules/match_rules_hook_registry_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/match_rules/match_rules_hook_registry_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later). `qa.level: standard` — BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/match-rules/story-001-data-model-and-rules-config.md` (for the `MatchState.hooks` slot and the factory swap; the registry class itself has no dependency and may be built in parallel)
- Unlocks: `production/epics/match-rules/story-003-match-setup.md`, `production/epics/match-rules/story-007-damage-heal-armor.md`, `production/epics/match-rules/story-011-effective-cost-and-temporary-mana.md`, `production/epics/match-rules/story-017-clone-and-replay.md`
