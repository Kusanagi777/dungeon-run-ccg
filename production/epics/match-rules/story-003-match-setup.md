# Story 003: Match setup: bind, heroes, shuffle, starting hands

> **Epic**: Match Rules
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-03

## Context

**GDD**: `design/gdd/match-rules.md` (C3 Match setup steps 1–6 and 8; States `Setup` → `Mulligan`; Interactions `on_match_start`, `modify_starting_hand_size`)
**Requirement**: `TR-match-rules-004`, `TR-match-rules-003` (the "engine never seeds a stream" half)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Effect Resolver / Validator Boundary (Decision 2 — binding and lifetime); also ADR-0005 (Decision 11 — binding time), ADR-0003 (injected `rng_match`, one event per mutation)
**ADR Decision Summary**: `RulesEngine.start(config)` constructs `state.hooks = HookRegistry.new()` then calls `resolver.bind(self, config.player.hook_installers + config.boss.hook_installers)` as C3 step 1, before heroes, decks and `on_match_start`; `bind` installs the hook entries and registers the evaluators. `MatchConfig` is the engine's only input; the engine never creates, seeds or forks a stream.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: HIGH by version; APIs used predate 4.3. `NOT SOURCEABLE — RefCounted cycle collection`: `RulesEngine` holds `resolver`, `bind()` gives the resolver the engine — the cycle is broken by `resolver.unbind()` at `Ended` (story 008); keep the engine reference in the resolver double a plain field so the teardown test (card-effects epic) can observe `weakref.get_ref() == null`. RNG determinism on 4.7.2 was observed 2026-11-03 (probe D; seed 42 → 492690617, 1919685028, 3561993920).

`start(config)` is the only way a match begins. Everything it does is observable in the log: `deck_shuffled` per side with the instance order, `mana_added` from any `on_match_start` hook, `card_drawn` for each starting card, then `mulligan_offered`. Determinism comes from doing things in one fixed order with one injected stream — player deck shuffled before boss deck, player hand before boss hand. Because Match Rules must be testable without Card Effects (ADR-0007 Alt 1), this story also adds the scripted resolver double the rest of the suite uses.

**Control Manifest Rules (this layer)**:
- Required: `RulesEngine._init(db, rules_config, resolver)`; `start(config)` constructs `state.hooks = HookRegistry.new()` then calls `resolver.bind(self, config.player.hook_installers + config.boss.hook_installers)` as C3 step 1, before `on_match_start` (ADR-0007, ADR-0005); `install(installer)` returns `false` on a duplicate `host_id` and the engine appends `hook_install_skipped{host_id, reason: duplicate}` (ADR-0005); `EffectResolver` … draws only through `engine.rng_match()` (ADR-0007)
- Forbidden: never share the live resolver with a clone (ADR-0007); `EffectResolver` never calls `EventLog.append`, holds an `EventLog`, or touches a `RandomNumberGenerator` (ADR-0007); rules code never calls a global RNG function (ADR-0001 G6 / ADR-0003)
- Guardrail: `submit()` ≤ 5 ms worst case — setup is not a `submit`, but `start` must stay allocation-light (one `CardInstance` per deck entry, one shuffle per side)

---

## Acceptance Criteria

*From GDD `design/gdd/match-rules.md`, scoped to this story:*

- [ ] AC-01 **GIVEN** two `MatchConfig`s whose `rng_match` is a fresh `stream("match_1")` from an RNG service created with `run_seed = 42`, **WHEN** `start` runs on each, **THEN** both decks' instance orders and both starting hands are identical across the two runs, and the engine made no RNG call outside `rng_match` (the service's other streams report `draws = 0` — `TestRngService.draws_outside(["match_1"])`).
- [ ] AC-02 **GIVEN** setup complete, **WHEN** `mulligan_offered` is emitted, **THEN** the player hand has 3 cards, the boss hand has 4, both heroes have `mana 0/0`, player health 30, boss health equal to `MatchConfig.boss.health`; `phase == Mulligan`, `turn == 0`, `fatigue_counter == 0`, `armor == 0`, and the log order is `deck_shuffled(player)`, `deck_shuffled(boss)`, [`on_match_start` hook events], 3 × `card_drawn(player)`, 4 × `card_drawn(boss)`, `mulligan_offered`.
- [ ] AC-43 **GIVEN** `MatchConfig.boss.health = 42` (Run Structure's F3 with a floor bonus), **WHEN** `start` runs, **THEN** the boss hero's `max_health` is 42 regardless of the boss definition's own `health` field; **AND GIVEN** a `modify_starting_hand_size` hook returning 14 (AC-44's setup half), **THEN** the starting hand is exactly `HAND_SIZE` with no `card_burned` (engine clamps the fold once to `[0, HAND_SIZE]`); **AND GIVEN** two installers with the same `host_id`, **THEN** `hook_install_skipped{host_id, reason: duplicate}` is appended by the engine and only the first is installed.

---

## Implementation Notes

*Derived from ADR-0007 Decision 2 / Implementation Guidelines and ADR-0005 Decision 5, 11:*

- `start(config)` in order: (1) `state.hooks = HookRegistry.new()`, then `resolver.bind(self, player.hook_installers + boss.hook_installers)` — `bind` installs entries through `state.hooks.install(installer)` in installation order and calls `state.hooks.set_evaluators(apply_value_hook, run_hook_effect)`; for each `install` that returns `false` the **engine** emits `hook_install_skipped`. (2) Create heroes: player `base_health` = the hero record's `health` defaulting to `STARTING_HEALTH_PLAYER`; boss `base_health = config.boss.health` — never the boss definition's health. Armour 0, mana 0/0, `fatigue_counter` 0, `entity_id` from `next_entity_id`. (3) Instantiate each deck list to `CardInstance`s in list order, then `rng_match.shuffle(list)` — player first, then boss; emit `deck_shuffled` per side with the instance order. (4) `hooks.run_triggers(&"on_match_start", side, {})` for each side — before any card is drawn. (5) Starting hands: `n = clampi(hooks.fold(&"modify_starting_hand_size", side, STARTING_HAND_PLAYER | STARTING_HAND_BOSS, {}), 0, HAND_SIZE)`, then `draw(side, n)` player first, boss second. (6) `phase = Mulligan`; emit `mulligan_offered` listing the player's hand. Step 7 (the `mulligan` command) is story 004; step 8 (`match_started` + first Start step) is story 005.
- `rng_match` and `rng_ai` arrive as the memoised stream objects in `MatchConfig`; store `rng_match`, pass `rng_ai` through untouched; **there is no `seed` field** and no `RandomNumberGenerator.new()` anywhere under `src/gameplay/`. `rng_match()` returns the injected stream (ADR-0007 Key Interfaces).
- Every mutation emits exactly one event via `log.append(type, payload, cause_seq)` — `cause_seq = 0` during setup. Use the engine's `emit(type, payload)` wrapper so `log.append` call sites stay inside the engine.
- `draw(side, n)`: this story implements the happy path (deck non-empty, hand below `HAND_SIZE`) as the primitive stub; burn and fatigue branches are story 006. `card_drawn` payload carries `instance_id`, `def_id`, `side`.
- Resolver double: `tests/helpers/test_effect_resolver.gd` (`TestEffectResolver`) with the ADR-0007 surface — `bind(engine, installers)` (installs through `engine.state().hooks.install`, sets evaluators to its own `apply_value_hook` / `run_hook_effect`), `unbind()`, `resolve(point, ctx)` (scripted: a Dictionary of `point → Array[Callable]` the test fills; each Callable receives `(engine, ctx)` and may call primitives), `legal_targets`, `targeting_spec` (scripted per `def_id`), `recompute_auras()` (scripted aura table), `resume`, `apply_value_hook` (applies the entry's `effect.op` `delta | set | mul` when `entry.side` matches the scope; no clamp), `run_hook_effect`. Bound methods, not closures over mutable locals (lambdas capture by value — sourced).
- Boss health defaults for tests come from `MatchFactory.boss_health_for_band`; the `42` case uses `overrides`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 004: `submit`, the `mulligan` command, rejection codes
- Story 005: `match_started`, the first Start step, turn 1 mana and draw
- Story 006: burn and fatigue branches of `draw`; the remaining primitives
- Story 008: `resolver.unbind()` at `Ended`

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/gameplay/match/rules_engine.gd` — `start`, `emit`, `rng_match`, hero creation, deck instantiation and shuffle, `hook_install_skipped`, `draw` (happy path and burn branch)
- `src/gameplay/match/match_state.gd` — doc comments only (construction is now `RulesEngine.start`)
- `tests/helpers/test_effect_resolver.gd` — new `TestEffectResolver` (ADR-0007 surface, scripted)
- `tests/helpers/match_factory.gd` — `make_started_engine`, `make_started_config`, `make_boss_deck_ids`, `STARTED_BOSS_DECK_SIZE`
- `tests/unit/match_rules/match_rules_setup_test.gd` — 15 test functions

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/match_rules/match_rules_setup_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later). `qa.level: standard` — BLOCKING.

**Status**: [x] Created and passing (15 test functions)

---

## Dependencies

- Depends on: `production/epics/match-rules/story-001-data-model-and-rules-config.md`, `production/epics/match-rules/story-002-hook-registry.md`
- Unlocks: `production/epics/match-rules/story-004-command-channel-and-mulligan.md`

## Completion Notes
**Completed**: 2026-11-03 (started 21:00:30 UTC, ended 21:13 UTC)
**Criteria**: 3/3 passing — AC-01 (`test_start_twice_with_seed_42_gives_identical_decks_and_hands`, `test_start_uses_the_injected_stream_once_per_deck`, `test_start_shuffles_the_player_deck_before_the_boss_deck`), AC-02 (`test_setup_complete_state_is_mulligan_with_c3_values`, `test_setup_log_order_is_shuffles_hooks_draws_then_mulligan_offered`, `test_deck_shuffled_lists_the_instance_order_the_hand_is_drawn_from`), AC-43 (`test_boss_health_is_match_config_health`, `test_starting_hand_hook_over_hand_size_clamps_to_hand_size_without_burn`, `test_starting_hand_fold_is_clamped_once_after_the_whole_chain`, `test_duplicate_host_id_logs_hook_install_skipped_and_installs_the_first_only`). Watched fail: missing `start` (all), and one mutant removing the hand-size clamp, swapping the shuffle order and dropping the skip log (9 failures).
**Deviations** (advisory):
- Player hero health is `starting_health_player` and the hero power id is `""`: `CardDatabase` has no record queries yet (card-database story 006); `TODO(card-database story 006)` in `start`.
- `card_drawn` payload is `{side, instance_id, card_id, hand_size}` (rng-event-log catalogue and match-rules C15's `card_added_to_hand` "shaped like `card_drawn`"), not the story's `def_id`.
- `draw` also implements the burn branch (story 006 scope): without it the AC-43 clamp is unobservable, since a stub that skips full-hand draws masks a missing clamp. The fatigue branch and `on_draw` stay `TODO(story 006)`; an empty-deck draw is a no-op until then.
- `rng_match()` returns `RefCounted` (ADR-0007 Key Interfaces says `RngStream`) so the `TestRngStream` double fits; matches `MatchState.rng_match`'s type.
- `hook_install_skipped` is detected by the engine from the installer list after `bind` (the registry is fresh, so a skip is exactly an earlier equal `host_id`); the resolver emits nothing.
- The engine↔resolver `RefCounted` cycle is not broken yet (`unbind` at `Ended` is story 008); a run leaves a few more resources in use at exit (gdUnit4 already reports ~100), no orphan Nodes.
**Test Evidence**: `tests/unit/match_rules/match_rules_setup_test.gd` (15 tests); full suite 352 test cases, 0 failures, exit 0; smoke exit 0, no SCRIPT ERROR.
**Run result**: N/A — the story changes headless rules state and the event log only; no scene, node or screen renders it (Match UI is a later epic).
**Reviewed by**: self, no independent review (LP-CODE-REVIEW skipped — Lean mode; QL-TEST-COVERAGE skipped — Lean mode)
