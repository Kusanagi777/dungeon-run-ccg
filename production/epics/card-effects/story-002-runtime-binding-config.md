# Story 002: EffectRuntime, resolver binding lifecycle and `card_effects.json`

> **Epic**: Card Effects
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/card-effects.md`
**Requirement**: `TR-card-effects-002` (binding at `RulesEngine.start`), `TR-card-effects-001` (plain-data runtime)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Effect Resolver / Validator Boundary (also ADR-0002: `config()` read once at construction; ADR-0005: `set_evaluators` at `bind`)
**ADR Decision Summary**: `RulesEngine._init(db, rules_config, resolver)` stores the resolver; `start(config)` calls `resolver.bind(self, installers)` before `on_match_start`; `unbind()` at `Ended` breaks the `RefCounted` cycle; `EffectRuntime {once_marks, counters, per_turn, pending_choice}` is plain data in `MatchState.effects`, copied by value in `clone()`; `clone()` binds a fresh resolver with no installers.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (by version; the APIs used predate 4.3 and are LOW)
**Engine Notes**: ADR-0007 Verification Required — `NOT SOURCEABLE — RefCounted cycle collection`: the engine holds the resolver and `bind()` gives the resolver the engine. This story's teardown test holds `weakref(engine)`, calls `RulesEngine.end_match()` (which calls `resolver.unbind()`), drops strong refs and asserts `weakref.get_ref() == null`. The ADR names this test at `tests/unit/effects/`; this epic's test root is `tests/unit/card_effects/` (tests/README.md), which is where it goes.

**Control Manifest Rules (this layer)**:
- Required: `RulesEngine.start(config)` constructs `state.hooks = HookRegistry.new()` then calls `resolver.bind(self, player.hook_installers + boss.hook_installers)` as C3 step 1; `resolver.unbind()` when `phase` becomes `Ended`; `EffectRuntime` is plain data in `MatchState.effects`, copied by value by `clone()`; `clone()` binds a fresh `EffectResolver.new(db, effects_config)` with no installers
- Forbidden: `EffectRuntime` never holds a Callable, a Node or an object reference; never share the live resolver with a clone; `EffectResolver` never holds an `EventLog` or touches a `RandomNumberGenerator`
- Guardrail: `clone()` + empty resolver memo per look-ahead node measured by the sim harness against `planner_target_ms` 50 p95

---

## Acceptance Criteria

*From GDD `design/gdd/card-effects.md` (C6.1, C6.8, Tuning Knobs; AC-41) and ADR-0007 Decisions 2–3 and Verification, scoped to this story:*

- [ ] **AC-1 (C6.8, ADR-0007 D3)** GIVEN a started match, WHEN `engine.state().effects` is inspected, THEN it is an `EffectRuntime` holding only `once_marks: Dictionary`, `counters: Dictionary`, `per_turn: Dictionary`, `pending_choice: Variant` (Dictionaries, Arrays, ints, Strings — `GameAssertions.assert_json_representable` passes). *(Split 2026-11-03, orchestrator: the `engine.clone()` by-value clause moved to match-rules story 017's C2 clone-isolation AC — ADR-0007 assigns `clone()` to match-rules — so this story no longer depends on story 017.)*
- [ ] **AC-2 (C6.1, ADR-0007 D2 + Verification)** GIVEN `RulesEngine.new(db, rules_config, resolver)` and `start(config)`, THEN `bind` ran before `on_match_start` (the resolver observes the `on_match_start` hook point) and `state.hooks` has the resolver's evaluators set; and GIVEN `end_match()` → `unbind()`, WHEN the test drops its strong references, THEN `weakref(engine).get_ref() == null` and the registry's evaluators are unset.
- [ ] **AC-41** GIVEN `src/gameplay/effects/**`, WHEN grepped for the Tuning Knobs constants (`DISCOVER_COUNT`, `DISCOVER_EXCLUDE_HAND`, `MAX_OPS_PER_EFFECT`, `MAX_REPEAT`, `MAX_SUMMON_COUNT`, `EFFECT_STATIC_STEP_LIMIT`, `SPELL_DAMAGE_DEFAULT`, `HOOKS_BEFORE_TRIGGERS`) and for global RNG calls (`randi`, `randf`, `shuffle(`, `pick_random`, `RandomNumberGenerator`), THEN every constant comes from `assets/data/card_effects.json` (read once via `config("card_effects")` in `EffectResolver._init`) and no global RNG call exists under the rules tree; `EffectValidator.validate_config(body, db)` returns `[]` for the shipped file and an error entry for a knob outside its Tuning Knobs safe range or a missing knob.

---

## Implementation Notes

*Derived from ADR-0007 Decisions 2–4, 8 and ADR-0002/ADR-0005 guidelines:*

- `class_name EffectResolver extends RefCounted`; `_init(db: CardDatabase, effects_config: Dictionary)` keeps both references; `bind(engine, installers)` stores the engine, installs each installer through `engine.state().hooks.install(installer)` in order (treasures in pick order, then the boss passive — a `false` return means the **engine** logs `hook_install_skipped`), then `hooks.set_evaluators(apply_value_hook, run_hook_effect)` with **bound methods**; `unbind()` clears the engine reference and the evaluators.
- The resolver keeps **no per-instance index**: effects are read from `db.card(def_id).effects` and memoised per `def_id` in a resolver-local Dictionary that is derived data (rebuildable). The memo starts empty in a clone.
- `EffectRuntime` is its own small script (`effect_runtime.gd`) or a Dictionary factory — either way it is plain data; `MatchState.clone()` copies it with `duplicate(true)`. Prefer typed containers (`deprecated-apis.md` pattern).
- `state()` and `emit(type, payload)` are engine additions owned by match-rules; this story consumes them and asserts `state()` is called only from `src/gameplay/effects/**`.
- `card_effects.json` is a DD-T01 config file (`{schema_version, config}` envelope, `CardFactory.make_config_file`). `validate_config` is the 7a config validator ADR-0002 registers under `configs.card_effects`; it is `static`, checks presence and the safe ranges of the Tuning Knobs table, and is composed by `tools/content/validate.gd` without `Boot`.
- Tests: `MatchFactory.make_match_config(floor, rng, log)` with a `TestRngStream` and `TestEventLog`; `ImmediatePlannerTask` is not involved (no AI here).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003–004: `validate_effects` and `derive_targeting_spec` (this story ships only `validate_config`)
- Story 006: the first `resolve(point, ctx)` pass and `effect_resolved`
- Story 014–015: what `apply_value_hook` / `run_hook_effect` do (this story registers them; they may be no-op bodies that return `value` unchanged)
- Story 016: AC-40 (clone determinism with queued triggers)

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/gameplay/effects/effect_resolver.gd` (`_init`, `bind`, `unbind`, memo)
- `src/gameplay/effects/effect_runtime.gd`
- `src/gameplay/effects/choice_request.gd` (shape only: `{side, kind, options, source_id, effect_id}`)
- `src/gameplay/effects/effect_validator.gd` (`validate_config` only)
- `assets/data/card_effects.json`
- `tests/unit/card_effects/card_effects_runtime_binding_test.gd`
- `tests/unit/card_effects/card_effects_resolver_teardown_test.gd` (the weakref test ADR-0007 names)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/card_effects/card_effects_runtime_binding_test.gd` and `card_effects_resolver_teardown_test.gd` — must exist and pass (`/story-done` checks that they EXIST; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Cross-epic — `production/epics/match-rules/` (`RulesEngine._init(db, rules_config, resolver)`, `start`, `end_match`, `state()`, `emit()`, `HookRegistry` — match-rules 003 and 008; `clone` no longer, per the 2026-11-03 split), `production/epics/card-database/` (`CardDatabase.config()`, config-file envelope); story paths are assigned by those epics' concurrent `/create-stories` runs. In-epic: none (story 001 is a spike whose code this story may promote, AC-S3).
- Unlocks: `production/epics/card-effects/story-006-play-triggers-one-pass.md`, `story-014-value-hook-folds.md`, `story-015-hook-trigger-steps-hero-slot-observers.md`
