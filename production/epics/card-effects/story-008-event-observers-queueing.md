# Story 008: Event triggers — responder selection, scope and queueing order

> **Epic**: Card Effects
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-04

## Context

**GDD**: `design/gdd/card-effects.md`
**Requirement**: `TR-card-effects-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Effect Resolver / Validator Boundary
**ADR Decision Summary**: The engine decides *when* a trigger point fires, *which* entities are candidates and in *what order*; the resolver decides *who responds* (trigger bound, scope matches, source live, not silenced, `once_per_turn` clear) and the order among one entity's effects (array order, definition before enchantment-granted), and whether to queue or run now. The resolver never re-sorts candidates across entities.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (by version; the APIs used predate 4.3 and are LOW)
**Engine Notes**: ADR-0007 Engine Compatibility — no post-cutoff APIs.

**Control Manifest Rules (this layer)**:
- Required: `RulesEngine` owns the C10 loop and fires trigger points with `ctx.candidates` already in engine order; one effect pass = one C10 step; the resolver orders effects only within one entity
- Forbidden: never let the resolver own the C10 loop or the trigger queue; never re-sort candidates across entities
- Guardrail: `RulesEngine.submit()` ≤ 5 ms worst case including resolver passes

---

## Acceptance Criteria

*From GDD `design/gdd/card-effects.md` (C2 event class and scope keys, C6.2, C6.3 order table and observer candidate order, Edge Cases "Resolution order and the queue"; AC-17, AC-18, AC-22), scoped to this story:*

- [ ] **AC-17** GIVEN an observer with both `on_play` and `on_summon` ("+1/+1 to the played/summoned minion") and row 9 (Deathrattle: summon two Husks) dying, WHEN a minion is played from hand, THEN it receives +2/+2 (two `enchantment_applied`, two queued triggers — C6.3 rows 4 and 6); WHEN row 9's Husks are summoned, THEN each receives +1/+1 only (`on_summon`, no `on_play`, no `battlecry`).
- [ ] **AC-18** GIVEN a minion with `on_damage_taken: draw 1` at 1 health and a Deathrattle, WHEN hit for 1, THEN `card_drawn` precedes its `trigger_resolved{deathrattle}` (observers queued at the damage step, before the death check — match-rules AC-28 restated through the DSL).
- [ ] **AC-22** GIVEN row 21 ("Whenever you cast a spell, draw a card", `on_card_played` scope `by: owner`, `card.type: spell`) on board, WHEN the owner casts a spell, THEN `card_drawn` appears after `spell_cast` and after the spell's own `effect_resolved` (host `cast` first, then observers — C6.3 spell row); WHEN the opponent casts a spell, THEN no draw (scope `by: owner`); and a `turn_start` observer on the boss side with `scope.side: opponent` resolves during the player's Start step in the boss-side candidate position (C6.3 observer candidate order: player side first always).

---

## Implementation Notes

*Derived from ADR-0007 Decision 1 and GDD C6.2–C6.3:*

- `resolve(point, ctx)` for an event point walks `ctx.candidates` (engine order: player board L→R, player weapon, player hero slot, then the boss side) and for each candidate's live effects with a trigger bound to this point: match `scope` against `ctx` (C2 scope keys — `side`, `by`, `of`, `who`, `attacker`, `defender`, `card: filter`, `min_amount`), require the source in play (or in hand for `passive_hand`), not silenced, `once_per_turn` mark clear (story 009 sets marks); each kept effect is **queued** through the engine's queue API (`engine.queue_trigger(...)` or whatever match-rules C10 exposes — the resolver never owns Q) with its raise-time snapshot (story 009 fills the snapshot; this story stores at least `{source_id, def_id, owner}`).
- The engine pops a queued trigger, emits `trigger_resolved` with the raising event's `cause_seq`, and calls the resolver to run that one pass (story 006's `_run_pass`) as its own step.
- `on_damage` splits into `on_damage_taken` / `on_damage_dealt` by default scope; both bind to the one engine point (C2).
- Within one entity: `effects[]` index order, definition effects before enchantment-granted ones. Among hooks: installation order (story 015).
- A source must have been in play before the raising event: a just-summoned minion does not observe its own `on_summon` (Edge Cases).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 009: the full raise-time snapshot, `once_per_turn`, Silence-after-queue, counters
- Story 015: hook-hosted trigger steps and hero-slot observers (treasure / passive hosts)
- match-rules: the queue itself, DD-M11 Deathrattle order, `trigger_resolved` / `trigger_queued` events

---

## Files

- `src/gameplay/effects/effect_resolver.gd` — modified (`resolve` for event points: `_collect`, `_candidate_host`, `_responds`, `_queue_entry`, `_run_queued`; `effect_resolved.depth`)
- `src/gameplay/effects/scope.gd` — created (`EffectScope`: C2 scope-key matcher, `controller_of`, `subject_view`)
- `src/gameplay/effects/selectors.gd` — modified (`trigger_subject` / `trigger_source` references)
- `tests/unit/card_effects/card_effects_observers_test.gd` — created (9 tests)
- `tests/unit/card_effects/card_effects_play_triggers_test.gd` — modified (the every-play-row test counts play passes only)

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/card_effects/card_effects_observers_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] Created — 9 tests, passing in the full suite

---

## Readiness

`/story-readiness` (by hand, 2026-11-04, Tier: workflow full, review lean): **READY**.
Design Completeness: GDD C2/C6.2/C6.3/Edge Cases traced, ACs self-contained and testable.
Architecture Completeness: ADR-0007 Accepted (version 2026-11-03 = story); TR-card-effects-002
active; Manifest Version 2026-11-03 current; engine notes and layer rules present. Scope Clarity:
estimate M, Out of Scope and dependencies stated. Open Questions: no markers; story 006 Complete.
Asset References: none. Definition of Done: 3 ACs (balanced min 2), Logic type, test evidence
path named, perf guardrail stated. QL-STORY-READY skipped — Lean mode.

## Dependencies

- Depends on: `production/epics/card-effects/story-006-play-triggers-one-pass.md`. Cross-epic: `production/epics/match-rules/` (trigger points with `ctx.candidates`, the C10 queue, `trigger_resolved`).
- Unlocks: `production/epics/card-effects/story-007-values-selectors-spell-damage.md` (AC-23/24), `story-009-deathrattle-snapshot-counters.md`, `story-015-hook-trigger-steps-hero-slot-observers.md`

## Completion Notes
**Completed**: 2026-11-04 (started 02:46:18 UTC, ended 02:55 UTC; the lane's first worktree vanished mid-run with no work in it — re-attached as `.claude/worktrees/l3-ce-a`)
**Criteria**: 3/3 passing (AC-17, AC-18, AC-22), no deferred items
- AC-17 — `test_a_minion_played_from_hand_gets_both_observer_buffs_in_c6_3_order` (two `trigger_queued`, `trigger_resolved` `on_play` then `on_summon`, two `enchantment_applied` on the played minion, +2/+2), `test_husks_summoned_by_a_deathrattle_get_the_on_summon_buff_only` (row 9's Deathrattle, then one `on_summon` per Husk, each Husk +1/+1 with one enchantment), `test_a_summoned_observer_does_not_observe_its_own_entry` (Edge Cases).
- AC-18 — `test_on_damage_taken_draw_precedes_the_deathrattle_of_the_same_hit` (`trigger_queued` `on_damage` before `minion_died`, `card_drawn` before `trigger_resolved{deathrattle}`); scope: `test_on_damage_taken_below_min_amount_queues_nothing`, `test_a_silenced_observer_does_not_respond`.
- AC-22 — `test_row_21_draws_after_spell_cast_and_after_the_spells_own_effect_resolved` (`spell_cast` < host `effect_resolved{cast}` < `card_drawn`; the observer pass is caused by its `trigger_resolved`, `depth` 1), `test_row_21_does_not_draw_when_the_opponent_casts_a_spell`, `test_a_boss_side_opponent_turn_start_observer_resolves_in_its_candidate_position` (player-side `side: owner` observer, then the boss-side `side: opponent` one, at the player's Start step; neither at the boss's).
- Watched fail: 6 of 9 failed against the story-006 `resolve()` (event points queued nothing); the 4 negative tests pass there by construction, so each was mutated, one mutation per run, each restored: no self-entry check (self-entry test failed), Silence ignored (silenced test failed), `min_amount` ignored (min-amount test failed), `side`/`by: owner` always true (opponent-spell and turn-start tests failed).
**Verification**: `godot --headless --path . --import` exit 0; full suite (`commands.test`) 1087/1087, exit 0; smoke exit 0, no SCRIPT ERROR; `tools/lint/gates.sh` PASS (G7 0 hits), `no_global_rng.sh` 0 hits; parse check of the changed scripts ok. Every SCRIPT ERROR line in the suite comes from other systems' negative tests (event log, RNG, meta).
**Run result**: N/A — nothing renders: the real resolver is not yet composed into a playable match (no `MatchDriver`), and the match UI's playback is match-ui's.
**Engine edits**: none (`rules_engine.gd` unchanged; the C10 queue, `trigger_queued` / `trigger_resolved` and the death snapshot are the engine's, as the story requires).
**Deviations** (all ADVISORY):
- **Unstated C2 defaults chosen**: `by` on `on_play` / `after_cast` defaults to `owner` (C2 states `owner` for `on_card_played` / `on_hero_power` only), `side` on `on_weapon_equipped` defaults to `owner`, and `attacker` on `on_attack` defaults to `self` (C2 gives none). Recorded in `EffectScope`'s doc comment for game-designer to confirm.
- **Deathrattle responders supplied here**: the engine already raised `deathrattle` with the death snapshot; this story answers it (definition effects of the snapshot's `def_id`, unless the snapshot is Silenced) because AC-17 needs row 9's Husks. Story 009 still owns the full snapshot, `once_per_turn` and Silence-after-queue; `summon position: source_slot` still falls back to `end` (ops TODO(story 009)).
- **Hero candidates respond to nothing yet**: hero-slot observers (hero power, treasures, passive) are story 015; `_candidate_host` answers `{}` for a hero.
- **`depth`** = the raising pass's depth + 1 (1 when raised outside a pass — a turn step, a combat hit, a death check). It approximates "length of the `cause_seq` chain to the command" without walking the log.
- **Story 006's test adjusted**: `test_every_play_row_of_the_fixture_emits_one_well_formed_effect_resolved` now counts only play-trigger passes, because row 10's destroy of row 9 now resolves row 9's Deathrattle as an extra queued pass.
**Test Evidence**: `tests/unit/card_effects/card_effects_observers_test.gd`
**Reviewed by**: not reviewed — `/code-review` NOT ASSESSED (agent-requiring gate, lean lane run)
