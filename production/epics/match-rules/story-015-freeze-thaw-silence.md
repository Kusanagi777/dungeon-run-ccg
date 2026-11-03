# Story 015: Freeze, thaw and Silence

> **Epic**: Match Rules
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/match-rules.md` (C13 Freeze and Silence semantics; F6 Health, buff loss and Silence clamp; C4 End step 4 — thaw; C12 Freeze, Silence, Aura rows; Edge Cases "Keywords and status"; States — character status sub-states)
**Requirement**: `TR-match-rules-005` (`freeze`, `silence` primitives and their one event each)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Effect Resolver / Validator Boundary (the engine owns the primitives and never writes `base_*` after creation except via Silence or `transform`; the `silenced` flag is what the resolver reads to skip the definition's triggers)
**ADR Decision Summary**: `silence(target)` and `freeze(target)` are engine primitives; `silenced` is plain state the resolver consults (who responds: "not silenced"); aura *reception* is re-applied by `recompute_auras()` so Silence stops only the target's own aura emission.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: HIGH by version; APIs used predate 4.3. No engine-specific verification.

The thaw rule covers Hearthstone's three cases with one comparison and no hidden counter: at the controller's End step a character thaws if it was frozen before this turn began or had already used its attacks when frozen; otherwise it stays Frozen through the next turn. Silence is one step that strips keywords, enchantments, Deathrattles and triggers, then clamps `damage_taken` with F6 so a buffed, damaged minion keeps its current health where it can but never exceeds its new maximum.

**Control Manifest Rules (this layer)**:
- Required: `RulesEngine` owns … the 24 primitives (ADR-0007); one effect pass = one C10 step (ADR-0007)
- Forbidden: never write match state directly from `src/gameplay/effects/**` — `frozen`, `silenced` are in gate G7's field list (ADR-0007); never call the death check or `recompute_auras()` between ops (ADR-0007)
- Guardrail: `submit()` ≤ 5 ms worst case (ADR-0007, ADR-0001)

---

## Acceptance Criteria

*From GDD `design/gdd/match-rules.md`, scoped to this story:*

- [ ] AC-24 **GIVEN** a 2/2 minion with +2 health and `damage_taken 3`, **WHEN** Silenced, **THEN** `max_health 2`, `damage_taken 1`, `health 1`, keywords empty, `frozen false`, `silenced true`, `silenced` emitted once (F6: `damage_taken' = max(0, 3 − (4 − 2))`); **GIVEN** the same minion buffed by an aura instead, **WHEN** the aura source dies, **THEN** the minion dies in the same resolution loop, after the source (aura loss leaves `damage_taken` untouched); **GIVEN** a minion with Divine Shield, Taunt and a Deathrattle, **WHEN** Silenced, **THEN** all three are removed in one step and when it later dies no `trigger_resolved(deathrattle)` fires; a shield already popped is not restored.
- [ ] AC-25 **GIVEN** a minion Frozen during the opponent's turn, **WHEN** its controller's End step runs, **THEN** it thaws (`thawed`; `frozen_on_turn < turn`); **GIVEN** a minion Frozen during its own turn before attacking, **THEN** it is still Frozen after that End step and thaws at the following own End step; **GIVEN** a minion Frozen after it had used its attacks (`attacks_remaining == 0`), **THEN** it thaws at this End step; freezing an already-frozen character re-stamps `frozen_on_turn` and the thaw rule still evaluates once at the End step.
- [ ] C13 exclusions **GIVEN** a Frozen minion, **WHEN** Silenced, **THEN** it thaws immediately and may attack this turn if it has attacks remaining and is not summoning-sick; **AND** Silence does **not** clear `summoning_sick`, `attacks_used` or `pending_destroy` and does not restore health lost to damage; **GIVEN** a Silenced minion buffed by another minion's aura, **THEN** the received aura is re-applied by the next `recompute_auras()` (net no change to received auras; only its own emitted aura stops).

---

## Implementation Notes

*Derived from ADR-0007 Decision 1, 5 and GDD C13 / F6 / C4 End step 4:*

- `freeze(target)`: `frozen = true`, `frozen_on_turn = turn`, emit `frozen`. A frozen character fails `can_attack` (`ATTACKER_FROZEN`, story 012); a frozen hero keeps its weapon.
- Thaw rule (End step 4 for side S, every S character): thaw if `frozen_on_turn < turn` **or** `attacks_remaining(c) == 0`; set `frozen = false`, emit `thawed`. Otherwise it stays Frozen and thaws at the next own End step.
- `silence(target)` on a minion, in one step: (1) `old_max = max_health(t)`; remove every non-aura enchantment (one `enchantment_removed` each is **not** emitted here — the GDD's single `silenced` event is the one event for the step; record the removed ids in its payload); (2) clear all keywords, Deathrattles and triggered effects granted by the definition or enchantments — `keywords.clear()`; (3) `silenced = true` (the resolver skips the definition's triggers and Deathrattles for this entity; Deathrattles from enchantments were removed in 1); (4) `damage_taken = max(0, damage_taken − (old_max − max_health(t)))`; (5) `frozen = false`; (6) emit `silenced{target, removed_enchantments, removed_keywords}`. Aura enchantments it *receives* are stripped and re-applied by the loop's `recompute_auras()`; the resolver stops emitting the target's own aura because `silenced` is set.
- Silence never touches `summoning_sick`, `attacks_used`, `pending_destroy`, `base_*`.
- The resolver double honours `silenced` (skips scripted triggers for that `entity_id`) so the "no Deathrattle after Silence" case is observable with no Card Effects code.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 009: the loop that re-applies auras and kills the aura-dependent minion
- Story 012: `ATTACKER_FROZEN`
- Card Effects epic: the `freeze` / `silence` DSL ops and skipping silenced sources in `resolve`

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/gameplay/match/rules_engine.gd` (`freeze`, `silence` complete, thaw at End step 4)
- `tests/helpers/test_effect_resolver.gd` (skip triggers for `silenced` entities)
- `tests/unit/match_rules/match_rules_freeze_silence_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/match_rules/match_rules_freeze_silence_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later). `qa.level: standard` — BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/match-rules/story-013-attack-resolution.md`, `production/epics/match-rules/story-009-resolution-loop.md`
- Unlocks: `production/epics/match-rules/story-017-clone-and-replay.md`
