# Story 017: clone() sandbox and replay equivalence

> **Epic**: Match Rules
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: L
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-04

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
- [ ] C2 clone isolation **GIVEN** a live match at `BossTurn.Main` with two treasures installed, a boss passive, a non-empty `state.effects` and a pending Discover, **WHEN** `clone()` is taken and 20 commands are submitted on the clone, **THEN** the live log's `seq` and the live `rng_match.draws` are unchanged, the live `MatchState` is unchanged (deep equality on `state_snapshot` of every entity and on `hooks.entries(point)` for every point), the clone's `hooks.entry_count()` equals the live one and its entries are not the same Dictionary objects, the clone's `pending_choice` and `state.effects.pending_choice` equal the live ones, the clone's resolver is a different instance bound with no installers (evaluators set on the clone's registry only), a `choose` on the clone resumes correctly, and the clone's scratch log is discarded with the clone (no reference held by the live engine); the clone's first `rng_match` draw equals what the live stream's next draw would be. **AND** (moved from card-effects story 002 AC-1, 2026-11-03) the clone's `state().effects` (`EffectRuntime`) is equal by value to the original's, and mutating a counter on the clone leaves the original unchanged.

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

- `src/gameplay/match/rules_engine.gd` — `clone()` (contract in its doc comment), `_fresh_resolver`, `_scratch_log`, `_copy_stream`; `load_state` / class docs updated
- `src/gameplay/match/match_state.gd` — `MatchState.clone(scratch_log, stream)`, the by-value state copy
- `tests/fixtures/match_states/01_mulligan.json` … `10_late_game.json` — 10 fixture scripts (new)
- `tests/helpers/test_effect_resolver.gd` — `clone_unbound()` (a fresh unbound double with the same scripted configuration; its own bound fixture Callables rebound), `last_clone` (weak reference) — additive
- `tests/unit/match_rules/match_rules_clone_replay_test.gd` — 12 tests (new)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/match_rules/match_rules_clone_replay_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later). `qa.level: standard` — BLOCKING.

**Status**: [x] Created and passing (12 test functions)

---

## Dependencies

- Depends on: `production/epics/match-rules/story-011-effective-cost-and-temporary-mana.md`, `production/epics/match-rules/story-014-combat-keywords.md`, `production/epics/match-rules/story-015-freeze-thaw-silence.md`, `production/epics/match-rules/story-016-choice-phase-and-discover.md`
- Unlocks: `production/epics/match-rules/story-018-performance-budgets.md`

---

## Readiness (2026-11-04, `/story-readiness` read by hand)

**Verdict: READY** (tier `workflow: full`). ADR-0003/0005/0006/0007 Accepted (2026-11-03, matching `ADR Version`); manifest 2026-11-03 current; TR-match-rules-002 and -003 active; dependencies 011, 014, 016 Complete and 015 Complete on this lane (`c382564`); 3 criteria, each observable; Out of Scope stated; no open markers; no asset references. The C2 clause moved from card-effects 002 AC-1 is present in the criterion (confirmed). Fixture loading: choice **(a)** confirmed — every one of the ten states is reachable by commands from `start` over a fixture card pool, so no `load_state` / `from_state` seam was added. QL-STORY-READY skipped — Lean mode.

## Implementation record (2026-11-04)

- **Resolver construction (the shape `architecture.md` §API Boundaries leaves open):** `_init` is unchanged. `clone()` builds `EffectResolver.new(db, live.effects_config(), live.player_hero_set())` when the live resolver is an `EffectResolver` (the hero set added by card-effects story 010, passed by value per the orchestrator note), and asks any other resolver (the test double) for `clone_unbound()`. No ADR addition: `clone() -> RulesEngine` is the API the architecture already names.
- **Scratch log:** a production `EventLog(scope match)` with the live log's remaining capacity as its cap and `set_turn(state.turn)`; `seq` restarts at 1 (the planner's checksum is over event types, ADR-0006).
- **Stream copy:** `RngStream.copy()` does not exist yet (rng-event-log, Out of Scope), so `_copy_stream` rebuilds the stream through its own construction seam (`_make_child(name, seed)`, which keeps a `TestRngStream`'s mode) and `restore(draws)`; it calls `copy()` instead once one exists.
- **Fixture format (option a):** `{name, sample_seed, decks, boss_health?, rules_overrides?, commands[], expect}`; a command is a literal C2 command, a pick `{pick, issuer?, card_id?, optional?}` of the first matching `legal_commands()` entry, or `{repeat, commands}`; `expect` is asserted so a fixture that stops reaching its state fails.
- **AC-38's command list** is recorded from a deterministic policy run on engine A (mulligan replacing one card, a rotating Discover pick, play → hero power → attack (minions first) → end turn, 199 commands, then `concede`), then replayed on a fresh engine B — instead of a hand-written 200-entry constant (Implementation Notes). The test asserts the list has 200 accepted commands with every required type and ends in `concede`.

## Completion Notes
**Completed**: 2026-11-04 (started 03:56:44 UTC, ended 04:11:08 UTC; trunk merged mid-story at the orchestrator's request — `042d5d4`)
**Criteria**: 3/3 passing —
- AC-38 `test_a_200_command_match_replays_byte_identical_with_an_equal_result` (canonical-JSON logs and `to_json()` identical, `CommandResult`s and `MatchResult`s equal);
- AC-39 `test_there_are_ten_fixture_states_and_each_reaches_its_expected_state`, `test_every_legal_command_of_every_fixture_state_is_accepted_on_a_fresh_clone`, `test_200_sampled_commands_absent_from_legal_commands_are_rejected_in_every_fixture_state`;
- C2 isolation `test_twenty_commands_on_a_clone_leave_the_live_match_log_and_stream_unchanged`, `test_a_clone_copies_hooks_by_value_and_binds_a_fresh_resolver_with_no_installers`, `test_a_clone_carries_the_pending_discover_and_choose_resumes_it_on_the_clone_only`, `test_the_clones_first_rng_draw_is_the_live_streams_next_draw`, `test_the_clones_scratch_log_is_detached_and_discarded_with_the_clone`, `test_a_clone_of_an_ended_match_is_ended_and_binds_no_resolver`, `test_a_clone_on_the_production_resolver_resumes_a_collectible_discover_and_draws_the_same_pool` (orchestrator-requested: real `EffectResolver`, `collectible` pool, hero set by value); the moved card-effects 002 AC-1 clause `test_a_clones_effect_runtime_is_equal_by_value_and_its_counters_are_isolated`.
- Seen failing: every clone test before `clone()` existed (`Nonexistent function 'clone'`); and under five one-at-a-time mutations — clone writes the live log / shares `players` shallowly (7 tests fail), shares `hooks` and `effects` (5), shares the live stream (2), binds the live resolver (2), builds the resolver without `player_hero_set` (the production-resolver test); AC-38's assertion fails with engine B on another seed. The first stream mutation passed the 20-command test (the clone drew nothing), so the fixture's Discover now shuffles its options with `rng_match` and the test asserts the clone drew.
**Deviations**:
- ADVISORY — AC-39 compares a sampled command with `legal_commands()` after dropping the arguments C2 ignores: `submit` accepts and ignores `position` on a spell or weapon play and a `target_id` on a `none`-targeting card or power (or on a Battlecry body whose required target has no legal choice), while `legal_commands()` lists only the null form. Read strictly, "every command absent from `legal_commands()` is rejected" fails for those shapes. Recorded for `/code-review` at M2: either C2 says these arguments are don't-care (as tested) or the engine rejects them (`INVALID_POSITION` / `ILLEGAL_TARGET`). The test also expects a non-keep-all Mulligan mask to be accepted although only keep-all is listed (C2), and does not sample `concede` (never listed, always accepted from the player).
- ADVISORY — `_copy_stream` reads `RngStream._stream_seed` / `_make_child` (private to rng-event-log) until `RngStream.copy()` exists; `_scratch_log` duck-types `TestEventLog` like the existing `_stamp_log_turn`.
- ADVISORY — the live stream's fork memo is not copied (the engine never forks, DD-T03); a planner that forks a clone's `rng_match` would take a fresh parent draw.
**Test Evidence**: `tests/unit/match_rules/match_rules_clone_replay_test.gd` (12 tests) and `tests/fixtures/match_states/` (10 states). Full suite after the trunk merge: 1301 test cases, 0 failures (exit 0); smoke exit 0, no SCRIPT ERROR; suite SCRIPT ERROR count 85, unchanged.
**Run result**: N/A — an engine sandbox with no scene or screen; its behaviour is observable only through state, the event logs and the stream the tests assert.
**Engine specialist check**: NOT ASSESSED — no agent spawning in this lane. `duplicate(true)` on plain containers (story Engine Notes), `WeakRef`, `Callable.get_object/get_method/get_bound_arguments/bindv` (test double only) predate 4.3; nothing post-cutoff.
**Reviewed by**: independent `/code-review` 2026-11-04 (by hand, `code-review-s4-mr015-017`): **NOT ASSESSED** (engine-specialist and qa-tester passes could not be spawned; perf guardrail had no data), substantively APPROVED WITH SUGGESTIONS; isolation and replay equivalence verified by probes. Fixes (sprint 4, lane 2 wave 3 review-fix slot): S5 a clone paused with triggers waiting in `suspended_queue` — `choose` on the clone leaves the live queue intact; review mutant M5 (shared queue) and a shallow-copy mutant both fail it — `3449b8a`; S6 per DD-X17 `submit` rejects arguments `legal_commands()` never lists — a `position` on a spell or weapon is `INVALID_POSITION`, a `target_id` on a `none` card or power or a target-less Battlecry is `ILLEGAL_TARGET` (DD-X17 names `INVALID_COMMAND`, which is not in C2's closed set; no code added); AC-39's test no longer canonicalises those away, only the Mulligan any-mask shape stays unlisted-but-accepted — `f5a75b8`; S7 public `RngStream.copy()` (reseed-and-discard, fork memo carried as child copies) used by `clone()`, which no longer reads private stream fields; a clone of a forked `rng_match` stays in step with live — `238df81`. S8 (clone/submit cost vs boss-ai F7) is routed to story 018 and a follow-up perf story, not changed here. Open nits: N4 (scratch-log cap and `_torn_down` copy untested — M8/M9 survive), N5, N6, N7; M6/M7/M11 survive as equivalent mutants (fields only reassigned). QL-TEST-COVERAGE skipped — Lean mode
