# Story 016: Determinism replay, clone isolation, runtime bounds and performance budgets

> **Epic**: Card Effects
> **Status**: In Review
> **Layer**: Core
> **Type**: Integration
> **Estimate**: L
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/card-effects.md`
**Requirement**: `TR-card-effects-006` (F6 bound vs `RESOLUTION_STEP_CAP` at runtime), `TR-card-effects-002` (deterministic on a clone; C6.9 draws in resolution order)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Effect Resolver / Validator Boundary
**ADR Decision Summary**: `RulesEngine.clone()` deep-copies `MatchState` (including `state.effects` and `state.hooks.copy()`) and binds a fresh resolver; nothing is shared between live and clone except the immutable `CardDatabase` and the frozen config; the resolver adds no runtime cap — match-rules' `RESOLUTION_STEP_CAP` (passes) and rng-event-log's `max_match_events` are the authorities; draws come from `engine.rng_match()` in resolution order with F4/F5 counts.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (by version; the APIs used predate 4.3 and are LOW)
**Engine Notes**: ADR-0007 Engine Compatibility — no post-cutoff APIs. Timing assertions use `Time.get_ticks_usec()` on the CI runner (ubuntu-latest, Godot 4.7.2 headless); budgets are the manifest's, measured not assumed.

**Control Manifest Rules (this layer)**:
- Required: `RulesEngine.clone()` deep-copies `MatchState` including `state.effects` and `state.hooks.copy()` and binds a fresh `EffectResolver.new(db, effects_config)` with no installers; draws only through `engine.rng_match()`
- Forbidden: never share the live resolver with a clone; `RandomNumberGenerator` under `src/gameplay/effects/**`
- Guardrail: `RulesEngine.submit()` ≤ 5 ms worst case (50-step Deathrattle chain); `clone()` + empty resolver memo measured against `planner_target_ms` 50 p95; per-def memo bounded by the card pool

---

## Acceptance Criteria

*From GDD `design/gdd/card-effects.md` (C6.9, C6.10, F6, Edge Cases "Recursion and caps"; AC-37, AC-38, AC-40, AC-42), scoped to this story:*

- [ ] **AC-37** GIVEN the 100-command scripted match `tests/fixtures/replay_card_effects_100.json` (decks containing rows 9, 12, 13, 20, 22, 26 and 34; seed and command list in the file), WHEN replayed with the same seed and commands, THEN the two event logs are byte-identical (`EventLogAssertions.assert_replay_equal`), and the number of stream draws equals the sum of F4/F5 draw counts recomputed from the log (`discover_offered` option counts plus `random_*` pick counts plus `shuffle_into_deck random` / `discard random` picks).
- [ ] **AC-38** GIVEN a Deathrattle "summon a copy of this and deal 1 to it" and `RESOLUTION_STEP_CAP = 50` (match-rules config override for the test), WHEN it dies, THEN the match ends `resolution_overflow` within 50 steps (passes) and fewer than `max_match_events` events were logged; the resolver added no cap of its own (the limit is read from match-rules' config, not from `card_effects.json`).
- [ ] **AC-40** GIVEN a `clone()` of a mid-match state with a queued trigger and a counter, WHEN the same command is submitted on the clone and the original, THEN both produce identical event sequences and the original's `EffectRuntime` is unchanged by the clone's resolution; the clone's resolver is a different instance with an empty per-`def_id` memo, and `state.hooks` on the clone has evaluators bound to the clone's resolver.
- [ ] **AC-42** GIVEN a 16-target op (`all_characters` on full boards) with value expressions, WHEN `resolve` is timed on the CI runner, THEN under 2 ms; `validate_effects` over the full v1 fixture (story 005) under 50 ms; a 12-entry value fold under 0.05 ms (ADR-0005 guardrail, measured here because this is the epic's timing suite).

---

## Implementation Notes

*Derived from ADR-0007 Decisions 3, 7, 10 and GDD C6.9–C6.10:*

- The replay fixture is JSON `{seed, hero_set, player_deck[], boss_deck[], treasures[], commands[]}` with command dictionaries in match-rules' `submit` shape; build it with `MatchFactory.make_match_config` + `TestRngStream.seeded(seed)` + `TestEventLog`; run twice from fresh engines and compare `to_json` output. Recompute expected draws by walking the log.
- AC-38's chain: `{"trigger":"deathrattle","ops":[{"op":"summon","card_id":"<self id>","count":1},{"op":"damage","targets":"right_neighbour"... }]}` — author the fixture card so each death summons and kills one copy per pass; the engine's step cap ends the match (`match_ended{reason: resolution_overflow}`, boss wins). Assert the resolver source has no cap constant (grep, like AC-41).
- AC-40: build state with a queued `turn_end` observer and an `add_counter` already applied; `clone()`; submit `end_turn` on both; compare logs after the command; assert `original.state().effects` deep-equals its pre-command snapshot and `original.state().effects != clone.state().effects` by identity.
- Timing: warm up once, time 20 iterations, assert the median (CI noise); use `Time.get_ticks_usec()`; mark the test `@warning_ignore` free and skip nothing — a budget miss is a red test, not a quarantine.
- This story closes the epic's gate entry condition 5 evidence for the War starter deck once `production/epics/content/` batch 0 exists: add the War starter deck's cards to the replay fixture decks when they land (note the extension on `/dev-story`).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: the clone's `EffectRuntime` copy and rebind mechanics (this story proves them under load)
- match-rules: `RESOLUTION_STEP_CAP`, `resolution_overflow`; rng-event-log: `max_match_events`, `log_overflow`, replay equality helpers
- `production/epics/boss-ai-match-driver/`: the sim harness that measures `clone()` + memo against `planner_target_ms`

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `tests/fixtures/replay_card_effects_100.json`
- `tests/fixtures/cards_effects_test.json` (the AC-38 cycle card, `token: true`, excluded from the AC-01 zero-error set only if its bound exceeds 250 — it does not: `1 + 1 + 1 = 3`)
- `tests/integration/card_effects/card_effects_determinism_bounds_test.gd`
- `tests/integration/card_effects/card_effects_perf_budget_test.gd` (AC-42)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/card_effects/card_effects_determinism_bounds_test.gd` and `card_effects_perf_budget_test.gd` — must exist and pass (`/story-done` checks that they EXIST; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: every resolution story — `production/epics/card-effects/story-005-fixture-set-database-injection.md`, `story-006-play-triggers-one-pass.md`, `story-007-values-selectors-spell-damage.md`, `story-008-event-observers-queueing.md`, `story-009-deathrattle-snapshot-counters.md`, `story-010-discover-choose-one.md`, `story-012-auras-enchantments.md`, `story-014-value-hook-folds.md`, `story-015-hook-trigger-steps-hero-slot-observers.md`. Cross-epic: `production/epics/match-rules/` (`clone`, `RESOLUTION_STEP_CAP`), `production/epics/rng-event-log/` (`assert_replay_equal`, `max_match_events`).
- Unlocks: epic Definition of Done; `production/epics/boss-ai-match-driver/` look-ahead on a deterministic clone; `/gate-check production`
