# Story 013: Transform, copy-to-hand, bounce and keyword auras from a treasure host

> **Epic**: Card Effects
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

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

- [ ] **AC-30** GIVEN row 31 ("Transform an enemy minion into a 1/1 Sheep") cast on an enemy 5/5 with Taunt and a Deathrattle, WHEN resolved, THEN the target is a new `entity_id` 1/1 Sheep with no keywords, no `battlecry` of the Sheep fires, and when the Sheep later dies no Deathrattle fires; a minion transformed during its own Battlecry has its remaining `self` ops land on the new body, and queued triggers of the old entity still resolve from their snapshot.
- [ ] **AC-31** GIVEN row 32 ("Add a copy of a friendly minion to your hand") targeting a friendly minion buffed +2/+2 and damaged 1, WHEN resolved, THEN the card added to hand has the printed cost and, when played, printed stats and full health; `return_to_hand` on a minion with `until_end_of_turn` buffs yields a fresh instance at printed cost with the enchantments gone, and its counters read 0 when replayed.
- [ ] **AC-32** GIVEN row 42 (treasure "Your minions have Rush", `aura` with `keywords: [rush]`) installed, WHEN a minion is played and attacks an enemy minion the same turn, THEN accepted; WHEN it attacks the hero, THEN `RUSH_CANNOT_HIT_HERO`; WHEN the treasure is absent, THEN `SUMMONING_SICK`; the minion's `auras_recomputed` entry lists `rush` in `keywords[]`, and `entity().enchantments[].source_id` is the treasure id (reworded 2026-11-04, DD-X26: a recompute emits no `enchantment_applied`).

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

- `src/gameplay/effects/ops.gd` (`transform`, `copy_to_hand`, `return_to_hand`, `aura` with `keywords`)
- `src/gameplay/effects/effect_resolver.gd` (`self` rebinding after transform; treasure aura sources in `bind` / `recompute_auras`)
- `tests/unit/card_effects/card_effects_transform_copy_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/card_effects/card_effects_transform_copy_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/card-effects/story-009-deathrattle-snapshot-counters.md`, `production/epics/card-effects/story-012-auras-enchantments.md`. Cross-epic: `production/epics/match-rules/` (`transform`, `return_to_hand`, `add_card_to_hand`, Rush legality), `production/epics/treasures/` (`HookInstaller` carrying the treasure's `effects[]`).
- Unlocks: `production/epics/treasures/` stories that author `aura` treasures
