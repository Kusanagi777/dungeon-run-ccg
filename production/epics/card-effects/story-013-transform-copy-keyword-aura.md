# Story 013: Transform, copy-to-hand, bounce and keyword auras from a treasure host

> **Epic**: Card Effects
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-04
> **Last Updated**: 2026-11-04 (implemented, sprint 5 L5 W2)

## Context

**GDD**: `design/gdd/card-effects.md`
**Requirement**: `TR-card-effects-002`, `TR-card-effects-004` (a treasure `aura` is hosted on the owner's hero slot)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Effect Resolver / Validator Boundary (also ADR-0005: a treasure is a live source while installed; its static trigger is recomputed like any aura)
**ADR Decision Summary**: `transform`, `copy_to_hand` and `return_to_hand` are primitives (`transform(target, def_id)` → new `entity_id`, enchantments dropped, Battlecry does not fire; `add_card_to_hand(side, target.def_id)` copies the definition, never the instance; `return_to_hand` makes a fresh instance); a treasure's `aura` effect is re-applied by `recompute_auras()` from the hero slot.
**ADR Version**: 2026-11-03 (ADR-0007); 2026-11-03 (ADR-0005)

**Engine**: Godot 4.7.2 | **Risk**: HIGH (by version; the APIs used predate 4.3 and are LOW)
**Engine Notes**: ADR-0007 / ADR-0005 Engine Compatibility — no post-cutoff APIs.

**Control Manifest Rules (this layer)**:
- Required: mutate only through primitives; `HookRegistry` evaluates nothing itself — a treasure `aura` is not a hook entry but a static effect the resolver recomputes
- Forbidden: never compile treasure effects into card instances at `begin_match` (ADR-0005 Alt 3); never write `keywords` / `enchantments` directly (gate G7)
- Guardrail: `recompute_cost ≤ 16 × 16` per recompute

---

## Acceptance Criteria

*From GDD `design/gdd/card-effects.md` (C5 `transform` / `copy_to_hand` / `return_to_hand` / `aura keywords`, C6.5, C7, C9, Edge Cases "Summons, transforms and copies"; AC-30, AC-31, AC-32), scoped to this story:*

- [x] **AC-30** GIVEN row 31 ("Transform an enemy minion into a 1/1 Sheep") cast on an enemy 5/5 with Taunt and a Deathrattle, WHEN resolved, THEN the target is a new `entity_id` 1/1 Sheep with no keywords, no `battlecry` of the Sheep fires, and when the Sheep later dies no Deathrattle fires; a minion transformed during its own Battlecry has its remaining `self` ops land on the new body, and queued triggers of the old entity still resolve from their snapshot.
- [x] **AC-31** GIVEN row 32 ("Add a copy of a friendly minion to your hand") targeting a friendly minion buffed +2/+2 and damaged 1, WHEN resolved, THEN the card added to hand has the printed cost and, when played, printed stats and full health; `return_to_hand` on a minion with `until_end_of_turn` buffs yields a fresh instance at printed cost with the enchantments gone, and its counters read 0 when replayed.
- [x] **AC-32** GIVEN row 42 (treasure "Your minions have Rush", `aura` with `keywords: [rush]`) installed, WHEN a minion is played and attacks an enemy minion the same turn, THEN accepted; WHEN it attacks the hero, THEN `RUSH_CANNOT_HIT_HERO`; WHEN the treasure is absent, THEN `SUMMONING_SICK`; the minion's `auras_recomputed` entry lists `rush` in `keywords[]`, and `entity().enchantments[].source_id` is the treasure id (reworded 2026-11-04, DD-X26: a recompute emits no `enchantment_applied`).

---

## Implementation Notes

*Derived from ADR-0007 Decision 1, ADR-0005 Decision 9 and GDD C5, C7, C9:*

- `transform`: call `transform(target, def_id)`; the primitive assigns the new `entity_id`, drops enchantments, keeps board position and summoning-sickness state, and does not fire the new body's Battlecry. The resolver updates its in-pass `self` binding to the new entity (C6.5) so later ops in the same effect act on it. Validator (story 003) already rejects a non-minion `card_id`.
- `copy_to_hand`: `add_card_to_hand(side, target.def_id)` — the definition, never the instance; full hand → the engine burns (`burned`).
- `return_to_hand`: the primitive creates a fresh instance; nothing to copy. Counters keyed by the old `entity_id` are simply unreachable afterwards (story 009).
- Treasure aura: the treasure host is a live source while installed (never Silenced, never leaves play); `recompute_auras()` (story 012) walks treasure/passive auras after both boards, hosted on the owner's hero slot; `apply_enchantment(…, keywords_added: [rush], is_aura: true, source_id: treasure_id)`. Rush / summoning-sickness legality is match-rules C12 — this story only grants the keyword.
- Treasure auras are not `HookRegistry` entries (ADR-0005: the registry holds only hook-bound trigger and value effects); `bind` (story 002) must therefore route a treasure's `aura` effects to the resolver's aura source list, not to `install`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 012: aura recompute and stacking in general
- Story 014–015: hook-bound treasure effects
- `production/epics/treasures/`: `installers_for`, the treasure pool and magnitudes; match-rules: Rush / Charge legality, `transform` / `return_to_hand` primitives

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/gameplay/effects/ops.gd` (`transform`, `copy_to_hand`, `return_to_hand`)
- `src/gameplay/effects/effect_resolver.gd` (`rebind_source`; treasure aura sources in `bind` / `recompute_auras`)
- `src/gameplay/effects/effect_runtime.gd`, `src/gameplay/match/match_state.gd` (`aura_hosts`)
- `src/gameplay/effects/selectors.gd`, `src/gameplay/effects/values.gd` (`run_source`, `def_id_of`)
- `tests/unit/card_effects/card_effects_transform_copy_test.gd`
- `tests/unit/card_effects/card_effects_runtime_binding_test.gd`, `tests/unit/match_rules/match_rules_data_model_test.gd` (the `EffectRuntime` shape pins)
- `docs/architecture/adr-0007-effect-resolver-validator-boundary.md` (erratum), `design/gdd/card-effects.md` (C6.8 note)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/card_effects/card_effects_transform_copy_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] Created: 31 tests

---

## Dependencies

- Depends on: `production/epics/card-effects/story-009-deathrattle-snapshot-counters.md`, `production/epics/card-effects/story-012-auras-enchantments.md`. Cross-epic: `production/epics/match-rules/` (`transform`, `return_to_hand`, `add_card_to_hand`, Rush legality), `production/epics/treasures/` (`HookInstaller` carrying the treasure's `effects[]`).
- Unlocks: `production/epics/treasures/` stories that author `aura` treasures

---

## Readiness (2026-11-04, by hand, sprint 5 L5 W2)

**Verdict: READY**, after two gaps were resolved from the docs. Workflow `full` (card-effects override).

- Passing: requirement traced (C5, C6.5, C7, C9, AC-30/31/32); ADR-0005 and ADR-0007 Accepted; TR-card-effects-002 and 004 active; stories 009 and 012 Complete; `HookInstaller` on trunk; `transform`, `return_to_hand`, `add_card_to_hand` and Rush legality on trunk; 3 criteria; Logic evidence path named.
- **Manifest Version (was NEEDS WORK at `full`)**: set to 2026-11-04. The rows added since do not touch this story, except the one this story's erratum extends (`EffectRuntime`, below).
- **AC-32 (was untestable as written)**: reworded for DD-X26 before this lane. `entity()` is `MatchQuery`'s (MUI-003, not built), so the test reads the same field on the record, `enchantments[].source_entity_id`.
- QL-STORY-READY skipped — Lean mode.

---

## Completion Notes

**Completed**: 2026-11-04
**Started / ended (UTC)**: 01:03:33 / 01:14:30 (2026-11-05 UTC)
**Criteria**: 3/3 passing, all by automated test (none deferred)
**Test Evidence**: `tests/unit/card_effects/card_effects_transform_copy_test.gd` (31)
**Reviewed by**: self, no independent review (the orchestrator runs `/code-review` at M2; a lane does not review its own work)
**Run result**: N/A — a Logic story changes nothing visible; the full suite and `godot --headless --quit-after 5` are the evidence.

**Traceability**

| Criterion | Covered by |
|-----------|------------|
| AC-30 | `test_ac30_*`, `test_a_later_effect_of_the_same_play_point_acts_on_the_new_body`, `test_transform_does_not_reset_summoning_sickness` |
| AC-31 | `test_ac31_*`, `test_copy_to_hand_*`, `test_return_to_hand_*` |
| AC-32 | `test_ac32_*`, `test_a_treasure_aura_*`, `test_an_aura_on_a_boss_passive_covers_the_boss_side_only`, `test_a_duplicate_installer_applies_its_aura_once`, `test_a_clone_recomputes_a_treasure_aura_without_its_installer` |

**Seen failing first.** Against the code before this story, 25 of the first 30 tests failed; the 31st (`run_source`) could not parse there, so it was held out of that run. Those 5 and the 31st were each seen failing against a deliberate mutant, restored after the run: later effect keeps the old source, `self` not rebound, Rush on every player minion with no host, `aura` as a hook point, a StringName in the runtime, a refused duplicate keeping its aura, `run_source` reading digits, a copy going to the owner's hand, and a bounce ignoring a full hand. `test_transform_does_not_reset_summoning_sickness` was tightened to assert the new `def_id`, so it now fails against missing code too. Every mutant was killed.

**Deviations**

- **`EffectRuntime` gains a fifth field, `aura_hosts`** (ADR-0007 Key Interfaces, control manifest, C6.8 list four). The story says the resolver keeps an aura source list, but a clone's resolver is built by `rules_engine.gd` with no installers, and that file is MR-019's this wave, so a list on the resolver would lose treasure auras in every planner sandbox. ADR-0007 has a dated erratum, C6.8 a dated note. **The manifest row still says four fields**: regenerate it. `match_state.gd`'s `make_effect_runtime` changed with it (additive). Two exact-shape pins were extended by the one field and stay exact: `EffectRuntime.FIELDS` in `card_effects_runtime_binding_test.gd`, and `EFFECT_RUNTIME_FIELDS` in `match_rules_data_model_test.gd`.
- **`effect_resolved.source_id` of a self-transform is the new body**, because `self` is rebound on the run. The log ties the ids through `minion_transformed.old_entity_id`.
- **`self` also rebinds across later effects of the same play point**, which C6.5 does not name; only `self` rebinds, so a later op on `chosen` after transforming it is `no_target`, as C6.5 reads.
- **`transform` entries add `values.new_ids`**; `targets` stay the old ids. `copy_to_hand` entries add `values.card_ids`.
- **`EffectSelectors.run_source`** replaces `int(run.source_id)`: `int()` of a treasure id reads the digits in it as an entity id. Outside the story's file list, needed by any treasure source.

**Open, not settled here**

- After a self-transform in a Battlecry, the engine's later play stages still name the old entity (`played.id`), so an `on_play` observer's `trigger_subject` finds nothing. C2 and C6.5 do not cover it and the fix is `rules_engine.gd`. No crash; no v1 card transforms itself.
