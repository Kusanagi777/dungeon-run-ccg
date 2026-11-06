# Story 015: Trigger hooks as synchronous steps and hero-slot observers (treasures, boss passives)

> **Epic**: Card Effects
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-04
> **Last Updated**: 2026-11-04 (implemented, sprint 5 L5 W3)

## Readiness (2026-11-05 UTC, by hand, sprint 5 L5 W3)

**Verdict: READY**, after four gaps were resolved from the docs. Workflow `full` (card-effects override).

- Passing: requirement traced (C2, C6.0, C6.3, C9; AC-16, 25, 36, 45); ADR-0005 and ADR-0007 Accepted; TR-card-effects-004 active; stories 002, 008, 009, 013, 014 Complete; `HookInstaller`, `Treasures.passive_installer` and the 12 engine hook call sites on trunk; 4 criteria; Logic evidence path named.
- **Manifest Version (was NEEDS WORK)**: set to 2026-11-04.
- **Hook mapping (missing from the story, review X2)**: "event trigger with a hook column -> `install`" did not say the DSL word is not the point name. Added from C2 and the owner brief: `turn_start`, `turn_end`, `on_summon`, hero-scope `on_damage_taken`.
- **`damage_dealt.amount`**: the field is `dealt`, and its source is `source` (QA plan, GDD and story contradictions). Tests follow the GDD.
- **`on_summon`**: C2's table, C6.3, ADR-0005 rule 9 and this story bind it to `on_minion_summoned`; C2's closing prose and C9 list it as hook-less. C6.3 is "what a test asserts", so it is a hook here.
- QL-STORY-READY skipped: Lean mode.

---

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

- [x] **AC-16** GIVEN a treasure "at the start of your turn gain 1 Armor" (hook `on_turn_start`) and row 34 on the player's board, WHEN the player's Start step runs, THEN `armor_gained` precedes both `damage_dealt` events; exactly one `trigger_resolved{trigger: turn_start}` sits between `armor_gained` and the first `damage_dealt` (the hook step, then row 34's queued pass), and **no** `trigger_resolved` sits between the two `damage_dealt` (both pings are one pass, C6.0); the step counter rose by 2. At the End step the order is reversed: card `turn_end` observers first, then `on_turn_end` hooks (C6.3 — the one exception).
- [x] **AC-36** GIVEN row 38 (treasure "At the start of the match, gain 10 Armor", `on_match_start`) installed, WHEN `start` runs, THEN `armor_gained{10}` appears before the first `card_drawn`, with `source_id` equal to the treasure id; two treasures run in pick order and the boss passive after all treasures; a duplicate `host_id` installs nothing and the engine logs `hook_install_skipped{host_id, reason: duplicate}`.
- [x] **AC-25** GIVEN row 37 (boss passive "whenever the player heals, deal 1 to their hero", `on_heal` — no hook column) and a player minion "whenever you heal, gain +1/+1", WHEN the player heals, THEN the log reads `healed`, then the minion's `enchantment_applied`, then the passive's `damage_dealt{amount: 1}` with `source_id` equal to the passive id — two `trigger_resolved{trigger: on_heal}` in that order (player-side observers before the boss hero-slot observer).
- [x] **AC-45** GIVEN a treasure "whenever a friendly minion dies, summon a 1/1 Husk — once per turn" (`on_minion_died`, hero-slot observer, `once_per_turn`) and row 11 on board, WHEN two friendly minions die in one death check, THEN exactly one `minion_summoned{decay_husk}` with `source_id` equal to the treasure id, its `trigger_resolved` **after** row 11's two, and no `E_FX_TRIGGER` at load (the `once_per_turn` mark is keyed on the treasure id).

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

- `src/gameplay/effects/effect_resolver.gd` (`run_hook_effect`, `_keep_hosted`, `_collect_hero_slot`, trigger snapshots, refused Discover)
- `src/gameplay/effects/effect_runtime.gd` (`aura_hosts` holds hero-slot observers; `hosted_effects`)
- `src/gameplay/effects/ops.gd`, `selectors.gd`, `values.gd` (String host ids; C3 and C6.5 snapshots; a card instance as `trigger_subject`)
- `src/gameplay/match/hook_registry.gd` (`hook_point`, the C2 mapping)
- `src/gameplay/match/rules_engine.gd` (String `source_id` in Q, `set_event_source`, `_raise_deaths`, `entered`)
- `design/gdd/card-effects.md` (C6.3, C6.8 notes), `docs/architecture/adr-0007-effect-resolver-validator-boundary.md` (erratum)
- `tests/unit/card_effects/card_effects_hook_triggers_observers_test.gd`

`src/gameplay/effects/scope.gd` needed no change: a hook occurrence is rebuilt as a trigger `ctx`.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/card_effects/card_effects_hook_triggers_observers_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] Created, 51 tests passing

---

## Dependencies

- Depends on: `production/epics/card-effects/story-002-runtime-binding-config.md`, `production/epics/card-effects/story-008-event-observers-queueing.md`, `production/epics/card-effects/story-009-deathrattle-snapshot-counters.md` (`once_per_turn` keyed by treasure id), `production/epics/card-effects/story-014-value-hook-folds.md` (shared `scope.gd`, installer classification). Cross-epic: `production/epics/match-rules/` (`HookRegistry.run_triggers`, hook call sites, candidate order), `production/epics/treasures/` (`HookInstaller`, `passive_installer`).
- Unlocks: `production/epics/treasures/` trigger-hook and observer treasures; `production/epics/content/` boss passives; `production/epics/card-effects/story-016-determinism-clone-bounds-perf.md`

---

## Completion Notes

**Completed**: 2026-11-04
**Started / ended (UTC)**: 03:59:48 / 04:34:53 (2026-11-05 UTC)
**Criteria**: 4/4 passing, all by automated test (none deferred); AC-16's step count as noted below
**Test Evidence**: `tests/unit/card_effects/card_effects_hook_triggers_observers_test.gd` (51)
**Reviewed by**: self, no independent review (the orchestrator runs `/code-review` at M3; a lane does not review its own work)
**Run result**: N/A: a Logic story changes nothing visible; the full suite and `godot --headless --quit-after 5` are the evidence.

**Traceability**

| Criterion | Covered by |
|-----------|------------|
| AC-16 | `test_ac16_*`, `test_a_turn_hook_runs_only_on_its_owners_turn_by_default`, `test_a_side_opponent_hook_runs_on_the_opposing_turn` |
| AC-36 | `test_ac36_*` |
| AC-25 | `test_ac25_*`, `test_a_hero_slot_entry_names_its_host_in_every_queue_event`, `test_row_37_min_amount_does_not_fire_on_a_heal_restoring_zero`, `test_the_player_hero_slot_precedes_the_boss_board_in_candidate_order` |
| AC-45 | `test_ac45_*`, `test_a_full_board_fails_the_summon_and_still_spends_the_mark`, `test_once_per_turn_*` |
| Review X2, M3 blocker | `test_dsl_turn_triggers_install_on_their_c2_hook_points`, `test_on_damage_taken_is_a_hook_with_hero_scope_only`, `test_every_shipped_passive_lands_in_the_registry_or_on_the_hero_slot`, `test_shipped_*` (all five bosses, on the shipped data) |
| C6.3 rows the ACs skip | `test_the_on_card_played_hook_*`, `test_the_summon_hook_*`, `test_the_hero_damaged_hook_*`, `test_the_draw_hook_*`, `test_row_41_*` |
| C6.0 Discover from a hook | `test_a_turn_start_hook_pauses_*`, `test_an_on_card_played_hook_pauses_*`, `test_a_discover_in_an_on_draw_hook_*`, `test_a_discover_in_an_on_match_start_hook_*` |

**Seen failing first.** Against the code before this story, 43 of the first 52 tests failed. Some of those failed on a fixture slip (a minion played with no position, the turn-1 Start step not allowed for), so after fixing them the file was run against a mutant with `run_hook_effect` and the hero-slot observers switched off: 36 of 51 failed. The 15 that passed there had failed on the old code or were then seen failing against deliberate mutants: `on_heal` mapped to a hook, the hook `scope` check off, `min_amount` off, `todo.clear()` removed, `MatchState.clone` copying `effects` shallowly, the `entered` check removed, auras dropped at `bind`, one boss dropped from the list. A mutant queueing a death check in raise order fails `test_ac45_two_deaths_*`. Every mutant was restored and checked by hash.

**Deviations**

- **`hook_registry.gd` and `rules_engine.gd` changed**, though the story says it writes neither. The owner brief adds the mapping; Q refused a String `source_id`, so a hero-slot observer could not queue without the engine change.
- **Hero-slot observers live in `EffectRuntime.aura_hosts`**, not a resolver list: a clone's resolver has no installers. A sixth field would have changed every golden state log, so the existing field widened and its name now undersells it. Goldens are unchanged (ADR-0007 erratum).
- **Hero slot in `candidates`**: the resolver reads its observers where it sees that side's hero id. No sentinel, no engine change to the candidate list.
- **`source_id` on every event of a host's pass** comes from `emit` while `set_event_source` is set, because `armor_gained` and `minion_summoned` have no such field in C15 and AC-36 and AC-45 need it. Only host passes carry the extra key. `damage_dealt` keeps its C15 `source` as well.
- **A death check queues `on_minion_died` in candidate order across the check**, not death by death. AC-45 needs the treasure after row 11's two, and raise-by-raise order put it between them. Card observers with two deaths change order too: X(A), X(B), Y(A), Y(B). Noted in C6.3.
- **AC-16 "the step counter rose by 2"** is asserted as two passes (C6.0: the cap counts passes). The engine's `_steps` also counts the `turn_start` raise, so it rises by 3 there.
- **AC-16 and AC-25 `trigger_resolved{trigger: …}`**: the engine's field is `point`, as C15 has it.
- **`on_summon` on a host is a hook**, per C2's table, C6.3, ADR-0005 rule 9 and this story. C2's closing prose and C9 still list it as hook-less.
- **Refused Discover (review N2)** now stops the effect's later ops, as C6.0 and match-rules C3 step 4 say.
- **`trigger_subject` may be a card instance** in `EffectSelectors.entities`, which row 41 needs. The op's Legal targets still apply.

**CE-013 review items**

- Closed: `values.gd:181` (`reads_snapshot` compares the snapshot's own id, C6.5); `trigger_subject.*` / `trigger_source.*` on a departed entity read the raise-time snapshot (C3), kept only for effects that name one; the new body no longer observes its own entry (Edge Cases: in play before the raising event), through ctx `entered`.
- `aura_hosts` isolation between a clone and its source: tested in both directions.

**Open, not settled here**

- After a self-transform, `on_play` / `on_summon` observers still get the departed entity as `subject`, so `trigger_subject` finds nothing. C2, C3 and C6.5 do not say whether it should be the new body. No v1 card transforms itself.
- A hero power's event triggers are not hosted on the hero slot (C2 Hosts allows them). No shipped power has one.
- `on_turn_start` hooks run before `turn_start` resets the tallies, so a hook reads last turn's `*_this_turn`, and a death in that hook is wiped. C4 says only "at that side's Start step".
