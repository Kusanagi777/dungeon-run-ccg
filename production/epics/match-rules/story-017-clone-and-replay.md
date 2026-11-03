# Story 017: clone() sandbox and replay equivalence

> **Epic**: Match Rules
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/match-rules.md` (C2 — `MatchState.clone()` paragraph; C3 step 1 — the engine never seeds; Acceptance Criteria AC-38, AC-39; Definition of Done — replay equivalence)
**Requirement**: `TR-match-rules-003`, `TR-match-rules-002` (`legal_commands()` soundness and completeness, AC-39)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Owner-scoped hook registry (Decision 7 — `copy()` by value, evaluators unset, the clone's resolver rebinds); also ADR-0007 (Decision 3 — `clone()` deep-copies `MatchState` incl. `state.effects` and `state.hooks.copy()`, binds a fresh resolver with no installers), ADR-0006 (`clone()` and `submit()` are the Boss AI's only surface; scratch log detached), ADR-0003 (determinism contract F6: `replay_equal`)
**ADR Decision Summary**: `RulesEngine.clone()` deep-copies `MatchState` (including `state.effects` and `state.hooks.copy()`), constructs a fresh `EffectResolver.new(db, effects_config)` and binds it to the clone with no installers; the clone gets a detached scratch log and a copy of the `rng_match` stream state; nothing in the resolver is shared between live and clone except the immutable `CardDatabase` and the frozen config body. Nothing a clone does appends to the live log or advances the live stream.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: `duplicate(true)` on plain containers is the copy (the `duplicate_deep()` row in `deprecated-apis.md` concerns nested Resources and does not apply); an override of a typed method returns explicitly (4.7) — relevant to `clone()` if typed. Stream copy: ADR-0003 fixes snapshot/restore by reseed-and-discard (`draws` count), observed equal to `state` restore on 4.7.2 (probe D4/D5) — the clone's stream is a fresh `RngStream` rebuilt from `{name, draws}` through the service's documented path, never a shared generator. `NOT SOURCEABLE — RefCounted cycle collection` applies to the clone too: the planner drops it; `unbind` on the clone when its sandbox ends.

`clone()` is the Boss AI's whole world (ADR-0006): it must behave identically to the live engine — same hooks, same pending choice, same RNG future — while touching nothing live. Replay equivalence is the suite-level determinism rule (ADR-0003 F6): the same `MatchConfig` and command sequence yields a byte-identical event log twice. AC-39 is the soundness/completeness check for `legal_commands()` over fixture states.

**Control Manifest Rules (this layer)**:
- Required: `RulesEngine.clone()` deep-copies `MatchState` (including `state.effects` and `state.hooks.copy()`) and binds a fresh `EffectResolver.new(db, effects_config)` with no installers (ADR-0007); `copy()` is a by-value copy with evaluators unset; `MatchState.clone()` calls it and the clone's resolver rebinds (ADR-0005); the Boss AI plans on `RulesEngine.clone()` inside a `PlannerTask` (ADR-0006, ADR-0008)
- Forbidden: never share the live resolver with a clone (ADR-0007); the worker is never handed the live `RulesEngine`, the live `EventLog`, … — it receives `engine.clone()` (ADR-0006, ADR-0008); never run `play_turn` against the live engine on the worker (ADR-0006 Alt 1); nothing a clone's hook does reaches the live log or stream (ADR-0005)
- Guardrail: `clone()` + empty resolver memo per look-ahead node measured against `planner_target_ms` 50 p95; `copy()` ≤ 12 small `duplicate(true)` calls per clone; memory — one extra `RulesEngine` clone per planned turn (ADR-0005, ADR-0006, ADR-0007)

---

## Acceptance Criteria

*From GDD `design/gdd/match-rules.md`, scoped to this story:*

- [ ] AC-38 **GIVEN** any 200-command scripted match (the scripted sequence includes `mulligan`, plays, attacks, hero power, a Discover `choose`, `end_turn`s and ends in `concede` or a dead hero), **WHEN** replayed with the same seed and commands on a fresh engine, **THEN** the two event logs are byte-identical (`EventLogAssertions.assert_replay_equal`, canonical JSON; Pillar 4) and the two `MatchResult`s are equal.
- [ ] AC-39 **GIVEN** each of the 10 fixture states in `tests/fixtures/match_states/`, **WHEN** every command in `legal_commands()` is submitted on a fresh `clone()`, **THEN** each is accepted; **AND WHEN** 200 commands are generated from the fixture's stream by combining a random command type with random `entity_id`s, indices and positions, **THEN** every one that is absent from `legal_commands()` is rejected (the sample is seeded, so the test is deterministic).
- [ ] C2 clone isolation **GIVEN** a live match at `BossTurn.Main` with two treasures installed, a boss passive, a non-empty `state.effects` and a pending Discover, **WHEN** `clone()` is taken and 20 commands are submitted on the clone, **THEN** the live log's `seq` and the live `rng_match.draws` are unchanged, the live `MatchState` is unchanged (deep equality on `state_snapshot` of every entity and on `hooks.entries(point)` for every point), the clone's `hooks.entry_count()` equals the live one and its entries are not the same Dictionary objects, the clone's `pending_choice` and `state.effects.pending_choice` equal the live ones, the clone's resolver is a different instance bound with no installers (evaluators set on the clone's registry only), a `choose` on the clone resumes correctly, and the clone's scratch log is discarded with the clone (no reference held by the live engine); the clone's first `rng_match` draw equals what the live stream's next draw would be.

---

## Implementation Notes

*Derived from ADR-0007 Decision 3, ADR-0005 Decision 7, ADR-0006 Decision and ADR-0003 Decision 3, 10:*

- `clone() -> RulesEngine`: `var c = RulesEngine.new(db, rules_config, EffectResolver.new(db, effects_config))` (tests pass a resolver factory or the double's class — the engine takes the resolver *class/factory* it was given at `_init`, or `_init` receives an `effects_config` to construct one; pick the shape `architecture.md` §API Boundaries names and record it in the ADR summary if it is an addition); `c.state = state.duplicate_deep_plain()` — `duplicate(true)` on the plain-data `MatchState` with `hooks` replaced by `state.hooks.copy()` and `effects` copied by value; `c.log = ScratchLog.new()` (a detached `EventLog` with the same `turn` stamp; discarded with the clone — the planner reads it); `c.rng_match = rng_match.copy()` — a fresh `RngStream` with the same `{name, draws}` rebuilt by reseed-and-discard (ADR-0003 F5; `TestRngStream.restore` in tests); `c.resolver.bind(c, [])` (no installers — entries are already in the copied registry; `bind` re-registers evaluators); copy `pending_choice`, `suspended_queue`, `suspended_steps`, `_current_cause_seq`, phase, originating phase. Never copy `_resolving` as true (a clone is taken between calls).
- `MatchState.clone()` (the GDD's name) and `RulesEngine.clone()` (the ADR's) are the same operation; expose `RulesEngine.clone()` and have it call the state-level deep copy.
- Replay (AC-38): build two engines from `MatchFactory.make_match_config(1, TestRngService.new(42), TestEventLog.new())`, feed the same command Array, compare `TestEventLog.to_json()` canonical forms. The scripted sequence lives in the test as a constant Array (no inline magic numbers beyond the seed).
- AC-39 fixture states: `tests/fixtures/match_states/*.json` — 10 states (mulligan, early Main, full boards, Choice pending, Taunt/Stealth board, empty decks, frozen hero, weapon equipped, boss Main, late game). **The GDD does not say how a fixture state is loaded into an engine**; the candidates are (a) each fixture is a `{config_overrides, commands[]}` script replayed from `start` (no new engine API; preferred — keeps the engine free of a `load_state` seam), or (b) a debug-only `RulesEngine.from_state(dict)`. Choose (a) unless `/story-readiness` finds it cannot reach a required state; record the choice in this story's Implementation Notes at `/dev-story`.
- Random command generation for AC-39 draws from the fixture's own `TestRngStream` (`randi_range`) so the sample is reproducible; a generated command is compared structurally against `legal_commands()` and the rejection asserted when absent.
- `hooks.copy()` on a 12-entry registry is ≤ 12 `duplicate(true)` calls (guardrail); assert `entry_count()` equality rather than timing here (timing is story 018).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 018: timing `clone()` and `submit()`
- boss-ai-match-driver epic: `PlannerTask`, `TurnPlan`, replaying the plan into the live engine, checksum comparison
- rng-event-log epic: `RngStream.copy()` / snapshot-restore and `EventLog` canonical JSON (tests use the doubles until it lands)

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/gameplay/match/rules_engine.gd` (`clone`)
- `src/gameplay/match/match_state.gd` (deep copy)
- `tests/fixtures/match_states/` (10 fixture scripts, new)
- `tests/helpers/test_effect_resolver.gd` (constructible with no installers for the clone)
- `tests/unit/match_rules/match_rules_clone_replay_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/match_rules/match_rules_clone_replay_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later). `qa.level: standard` — BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/match-rules/story-011-effective-cost-and-temporary-mana.md`, `production/epics/match-rules/story-014-combat-keywords.md`, `production/epics/match-rules/story-015-freeze-thaw-silence.md`, `production/epics/match-rules/story-016-choice-phase-and-discover.md`
- Unlocks: `production/epics/match-rules/story-018-performance-budgets.md`
