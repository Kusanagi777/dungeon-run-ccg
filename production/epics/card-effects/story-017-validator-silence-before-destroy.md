# Story 017: EffectValidator — Silence before destroy on one target (`E_FX_OP`, DD-X21)

> **Epic**: Card Effects
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-11-04
> **Last Updated**: 2026-11-04 (created, DD-X21)

## Context

**GDD**: `design/gdd/card-effects.md` (C5 "Silence before destroy", C10 `E_FX_OP` row, Edge Cases, AC-47) · `design/gdd/match-rules.md` (C12 Deathrattle row, C13 step 2 — why the order matters) · `design/gdd/content.md` (CN-6 step 6 style guide)
**Requirement**: `TR-card-effects-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Effect Resolver / Validator Boundary
**ADR Decision Summary**: `EffectValidator.validate_effects(host_kind, host_id, effects, db, caps) -> Array` is `static` and pure, and returns `[{code, host_id, effect_id, path, message}]` from the closed `E_FX_*` / `W_FX_*` set. The new check adds no code: it reports under the existing `E_FX_OP`, as DD-X16's aura-Stealth rule did.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (by version; no post-cutoff API — static GDScript over Dictionaries)
**Engine Notes**: none beyond story 003.

**Control Manifest Rules (this layer)**:
- Required: codes are the closed `E_FX_*` / `W_FX_*` set; the validator reads nothing but its arguments.
- Forbidden: never add an `E_FX_*` / `W_FX_*` code without a card-effects GDD change. This story adds none.
- Guardrail: `validate_effects` over the full v1 fixture under 50 ms (story 016).

**Why (owner decision DD-X21, 2026-11-04).** When one effect destroys a minion and then Silences it, the Deathrattle fires (match-rules C13 step 2; runtime in story 009). A card that means "and its Deathrattle does not fire" must list `silence` first. The content validator rejects the destroy-first order so that no card ships it by accident.

---

## Acceptance Criteria

*From GDD `design/gdd/card-effects.md` (C5, C10, AC-47), scoped to this story:*

- [ ] **AC-47 (destroy before silence)** GIVEN an effect with `targets: chosen` and ops `[destroy, silence]`, WHEN validated, THEN exactly one `E_FX_OP` whose message names both op paths (`ops[0]`, `ops[1]`). GIVEN `[silence, destroy]`, THEN no row.
- [ ] **AC-47 (reference, not search)** GIVEN `destroy` on `chosen` and `silence` with its own `targets: all_enemy_minions`, THEN no row (a search selector never yields a dying minion, C3). GIVEN both ops reaching `self`, `target`, `trigger_subject` or `trigger_source` (own `targets` or inherited), THEN `E_FX_OP` for each reference kind (one case per reference).
- [ ] **AC-47 (structure)** GIVEN a `repeat` holding `[silence, destroy]` on `chosen`, THEN `E_FX_OP` (iteration 2's silence follows iteration 1's destroy). GIVEN `destroy` in a `conditional`'s `then` and `silence` in its `else`, or in two `choose_one` options, THEN no row. GIVEN `destroy` inside a `conditional` `then` followed by a top-level `silence` on the same reference, THEN `E_FX_OP`.
- [ ] **Shipped data** GIVEN `assets/data/cards_*.json`, `bosses.json`, `treasures.json` and `hero_powers.json` as of 2026-11-04, WHEN loaded, THEN no new `E_FX_OP` row. No shipped record has both ops; the only `destroy` is `war_headsman` and the only `silence` is `neutral_hush_owl`.

---

## Implementation Notes

- Walk each effect's ops in execution order, carrying the effective target of each op: its own `targets`, else the effect's. Only explicit references (`chosen`, `self`, `target`, `trigger_subject`, `trigger_source`) are tracked; any other selector is ignored for this check.
- Branches: `conditional` `then` and `else` are walked as alternatives. Each sees the ops before the `conditional`, and the ops after it see the union. `choose_one` options are walked the same way. A `repeat` body is walked twice, which models iteration 2 following iteration 1.
- The rule is per effect. Two effects on one host are two passes with a death check between them (card-effects C6.0), so a later effect's `silence` cannot reach a minion the earlier one destroyed.
- The message text follows the DD-X16 row's style: "destroy before silence on one target (DD-X21): ops[i] destroy, ops[j] silence — list silence first".

---

## Out of Scope

- Story 009: the runtime (the Deathrattle fires on destroy-then-silence; match-rules AC-46).
- Damage-then-silence ordering: it is not statically checkable (the damage may not kill), and match-rules C13 leaves it unprotected by design.

---

## Files

- `src/gameplay/effects/effect_validator.gd` (the order check under `E_FX_OP`)
- `tests/unit/card_effects/card_effects_validator_schema_test.gd` (AC-47 cases; watch each fail before the check lands)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/card_effects/card_effects_validator_schema_test.gd` — the AC-47 cases exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/card-effects/story-003-validator-schema-codes.md`, `production/epics/card-effects/story-004-validator-step-bound-targeting.md` (both Complete)
- Independent of story 009 (it can land first)
- Unlocks: nothing blocking; content batches gain the check at their next validate run
