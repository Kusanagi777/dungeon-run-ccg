# Story 002: EffectRuntime, resolver binding lifecycle and `card_effects.json`

> **Epic**: Card Effects
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-03

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

- `src/gameplay/effects/effect_resolver.gd` — created (`_init`, `bind`, `unbind`, `bound_engine`, `effects_config` / `knob` / `knob_int`, the `effects_of` memo; identity `apply_value_hook`, no-op `run_hook_effect`, `resolve` → `[]` and no-op `recompute_auras` until stories 006 / 012 / 014 / 015)
- `src/gameplay/effects/effect_runtime.gd` — created (`FIELDS`, `make()`, `is_runtime()`)
- `src/gameplay/effects/choice_request.gd` — created (shape only: `FIELDS`, `KINDS`, `make()` over `MatchRecords.choice_request`)
- `src/gameplay/effects/effect_validator.gd` — modified (`validate_config` final: snake_case `CONFIG_KEYS`, unknown-key check; `validate_effects` caps read snake_case only)
- `assets/data/card_effects.json` — created (DD-T01 envelope, GDD Tuning Knobs current values)
- `tests/unit/card_effects/card_effects_runtime_binding_test.gd` — created (12 tests)
- `tests/unit/card_effects/card_effects_resolver_teardown_test.gd` — created (3 tests; the weakref test ADR-0007 names)
- `tests/integration/card_effects/card_effects_config_file_test.gd` — created (7 tests: shipped file, GDD pin, AC-41 scans — file reads, so integration)
- `tests/unit/card_effects/card_effects_config_validator_test.gd` — modified (interim tests moved to the final snake_case spelling; +1 test)
- `tests/unit/card_effects/card_effects_validator_schema_test.gd` — modified (`_caps()` keys snake_case)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/card_effects/card_effects_runtime_binding_test.gd` and `card_effects_resolver_teardown_test.gd` — must exist and pass (`/story-done` checks that they EXIST; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] Created — both unit files plus `tests/integration/card_effects/card_effects_config_file_test.gd`

---

## Dependencies

- Depends on: Cross-epic — `production/epics/match-rules/` (`RulesEngine._init(db, rules_config, resolver)`, `start`, `end_match`, `state()`, `emit()`, `HookRegistry` — match-rules 003 and 008; `clone` no longer, per the 2026-11-03 split), `production/epics/card-database/` (`CardDatabase.config()`, config-file envelope); story paths are assigned by those epics' concurrent `/create-stories` runs. In-epic: none (story 001 is a spike whose code this story may promote, AC-S3).
- Unlocks: `production/epics/card-effects/story-006-play-triggers-one-pass.md`, `story-014-value-hook-folds.md`, `story-015-hook-trigger-steps-hero-slot-observers.md`

---

## Completion Notes
**Completed**: 2026-11-03 (started 23:02:49 UTC, ended 23:14:04 UTC)
**Criteria**: 3/3 passing (AC-1, AC-2, AC-41), no deferred items
- AC-1 — `card_effects_runtime_binding_test.gd`: `test_started_match_effects_is_an_effect_runtime_of_plain_data` (`assert_json_representable`), `test_effect_runtime_make_is_the_shape_match_state_starts_with`, `test_effect_runtime_is_runtime_rejects_extra_missing_and_object_fields`, `test_choice_request_make_has_the_adr_shape_and_matches_the_engine_record`
- AC-2 — `test_bind_runs_before_on_match_start_so_the_resolver_observes_it` (the hook reaches the resolver after both `deck_shuffled`, before any draw), `test_bind_installs_installers_in_order_and_registers_both_evaluators`, `test_end_match_unbinds_clearing_the_engine_reference_and_the_evaluators`, `test_unbind_without_bind_is_a_no_op`; `card_effects_resolver_teardown_test.gd`: `test_end_match_then_dropping_references_frees_the_engine` (`weakref(engine).get_ref() == null`), `test_an_ended_match_unbinds_itself_and_frees_on_release` (concede), and the control `test_without_unbind_the_cycle_keeps_the_engine_alive` — ADR-0007's `NOT SOURCEABLE — RefCounted cycle collection` is settled by observation on 4.7.2.
- AC-41 — `tests/integration/card_effects/card_effects_config_file_test.gd`: the shipped file loads through `DataLoader` with exactly `CONFIG_KEYS`, passes `validate_config`, holds the GDD Tuning Knobs current values; `CONFIG_INT_RANGES` / `CONFIG_ALLOWED_VALUES` equal the GDD safe-range column (parsed from the GDD text); no knob bound to a literal under `src/gameplay/effects/**`; no global RNG call under `src/gameplay` + `src/ai` (scanners seen firing on each planted form). `card_effects_config_validator_test.gd`: an error per missing / out-of-range / wrong-type / unknown knob. Resolver half: `test_knobs_are_read_from_the_injected_config_body`, memo tests `test_effects_of_reads_the_database_once_per_def_id`, `test_a_fresh_resolver_starts_with_an_empty_memo`.
- Watched fail: every new suite failed to load before the code existed (missing `EffectResolver`, `EffectValidator.CONFIG_KEYS`); then one mutation per run, each restored: `unbind` keeping `_engine` (all 3 teardown tests + the unbind binding test failed), `bind` not calling `set_evaluators` (both evaluator tests failed), shipped `max_repeat: 30` plus a `const MAX_REPEAT: int = 10` in `src/gameplay/effects/` (validator, current-value and literal-scan tests failed), `CAP_MAX_REPEAT` back to `"MAX_REPEAT"` (schema test's `repeat` cap test failed).
**Verification**: `godot --headless --path . --import` exit 0; full suite (`commands.test`) 837 test cases, 0 failures, exit 0; smoke `godot --headless --quit-after 5` exit 0, no SCRIPT ERROR; parse check of every changed `.gd` ok; `tools/lint/gates.sh` PASS, `tools/lint/no_global_rng.sh` 0 hits; the ADR-0007 G7 regex over `src/gameplay/effects/` 0 hits. The suite's 45 SCRIPT ERROR lines are other suites' intentional negative tests; card_effects suites emit none.
**Run result**: N/A — the resolver binding and the config validator run inside `RulesEngine.start` and Card Database load with nothing on screen; no match UI exists yet to show either.
**Deviations** (all ADVISORY):
- **Key spelling settled (DD-T01):** `card_effects.json` keys are snake_case (`max_repeat`), as `match_rules.json` and every fixture already were. `validate_config` and `validate_effects` read only that spelling; the interim UPPER_CASE fallback is gone, and an unknown key is now an `E_FX_SCHEMA` error. ADR-0007 / story 004 text writes `caps.EFFECT_STATIC_STEP_LIMIT` — read it as the GDD knob name for `caps.effect_static_step_limit`. The validator name is unchanged, so Boot's registration line stays `configs["card_effects"] = EffectValidator.validate_config` (boot.gd not edited; its doc comment still says "interim").
- **`resolve()` and `recompute_auras()` added as empty bodies** (`[]` / no-op), not in this story's Files: `RulesEngine.start` raises `on_draw` while dealing starting hands and the End step calls `recompute_auras`, so a real resolver cannot be bound without them. Stories 006 / 012 fill them.
- AC-41's "read once via `config("card_effects")` in `EffectResolver._init`": per ADR-0007 Key Interfaces and the manifest's `MatchDriver` order, `_init(db, effects_config)` receives the body the caller read with `db.config("card_effects")` and keeps that reference (pinned by `is_same`); the resolver never calls `config()` itself.
- `EffectRuntime` is a factory + shape check (`make`, `is_runtime`), not an instance class, so `MatchState.effects` stays a JSON-representable Dictionary. `MatchState.make_effect_runtime()` (match-rules) still builds the record; a test pins the two equal. Follow-up for match-rules: delegate to `EffectRuntime.make()`.
- Evaluator signatures take `entry: Dictionary` (ADR-0007 writes `HookEntry`; registry entries are Dictionaries, as `TestEffectResolver` already does).
- AC-41's knob and RNG scans read source files, so they sit in `tests/integration/card_effects/` (not in the story's Files list), like match-rules' AC-41 scan.
**Test Evidence**: `tests/unit/card_effects/card_effects_runtime_binding_test.gd`, `tests/unit/card_effects/card_effects_resolver_teardown_test.gd`, `tests/integration/card_effects/card_effects_config_file_test.gd`
**Reviewed by**: self, no independent review (lean: LP-CODE-REVIEW and QL-TEST-COVERAGE skipped — Lean mode; `/code-review` not run — due before M2 per the sprint-3 plan)
