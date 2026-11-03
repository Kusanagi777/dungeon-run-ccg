# Story 004: F6 static step bound, `E_FX_BUDGET` and derived `targeting_spec`

> **Epic**: Card Effects
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/card-effects.md`
**Requirement**: `TR-card-effects-006` (F6 bound), `TR-card-effects-001` (targeting_spec derived, never stored), `TR-card-effects-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Effect Resolver / Validator Boundary (also ADR-0002: Card Database rejects a stored `targeting` field, CR-3)
**ADR Decision Summary**: `validate_effects` computes `effect_step_bound` per F6 and raises `E_FX_BUDGET` above `caps.EFFECT_STATIC_STEP_LIMIT`; the same function yields `targeting_spec` for the host — one derivation (`derive_targeting_spec`), two callers: the validator checks it, the resolver memoises it per `def_id`; `step_bound` is exposed for tests and `/balance-check`.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (by version; the APIs used predate 4.3 and are LOW)
**Engine Notes**: ADR-0007 Engine Compatibility — no post-cutoff APIs. Pure integer arithmetic on Dictionaries.

**Control Manifest Rules (this layer)**:
- Required: `targeting_spec` is derived via `derive_targeting_spec`, memoised per `def_id`; `legal_commands()` ≤ 2 ms relies on that memo
- Forbidden: never read `targeting` from a stored field (Card Database rejects it, CR-3)
- Guardrail: `legal_commands()` ≤ 2 ms (`targeting_spec` memoised per `def_id`)

---

## Acceptance Criteria

*From GDD `design/gdd/card-effects.md` (C1 rule 1, C3 `chosen`, C10, F6; AC-05, AC-07), scoped to this story:*

- [ ] **AC-05** GIVEN "deal 1 damage to all minions, 20 times" (`repeat` `times: 20` over `all_minions`), WHEN validated with `caps.EFFECT_STATIC_STEP_LIMIT = 250`, THEN `E_FX_BUDGET` with `bound = 321` in the message/values; with `times: 10` it passes (`161`). `EffectValidator.step_bound(effect, caps)` returns the F6 value for the C11 examples: row 34 → 3; a non-literal `count` on `summon` is taken at `caps.MAX_SUMMON_COUNT`, a non-literal `times` at `caps.MAX_REPEAT`, any other non-literal at `HAND_SIZE` (10); `steps(conditional) = max(Σ then, Σ else)`, `steps(choose_one) = max over options`.
- [ ] **AC-07** GIVEN row 18 (`chosen`, `kind: any`) and row 10 (`chosen` friendly minion, Battlecry), WHEN `targeting_spec` is queried, THEN row 18 → `{mode: required, filter: {kind: any}}`, a `chosen` with `optional: true` → `mode: optional`, a host with no `chosen` → `mode: none`; and `EffectResolver.legal_targets(def_id, source)` for row 18 lists every non-Stealth enemy character plus all friendly characters; row 10 on an empty friendly board → empty list, and match-rules' `legal_commands()` still lists the minion (a Battlecry with no legal target is still playable; the effect does not resolve — Edge Cases).
- [ ] **AC-3 (C10 `E_FX_OP_TARGET`)** GIVEN `discover` with `then: cast` whose `list` (or load-time pool after `filter`) contains a spell whose derived `targeting_spec.mode` is not `none`, WHEN validated, THEN `E_FX_OP_TARGET`; GIVEN `freeze` with `targets: hand`, THEN `E_FX_OP_TARGET` (a selector that can never yield a legal kind).

---

## Implementation Notes

*Derived from ADR-0007 Decision 8 and GDD F6 / C1 rule 1:*

- `static func step_bound(effect: Dictionary, caps: Dictionary) -> int` = `1 + Σ steps(op)`; `steps(leaf) = max_targets(op.targets or effect.targets) × count(op)`; `max_targets`: `all_*` 16, single 1, `adjacent` 2, `hand` 10, `random_* n` n, side-scoped 1. `steps(repeat) = times × Σ steps(inner)`.
- `static func derive_targeting_spec(effects: Array) -> Dictionary` scans play triggers (`battlecry`, `cast`, `hero_power`) for an effect-level `chosen` and returns `{mode, filter}`; `validate_effects` calls it (C1 rule 1 is where `E_FX_CHOSEN`'s "more than one" is detected — story 003 — and `targeting_spec` is the one derivation).
- `EffectResolver.targeting_spec(def_id)` memoises the derivation per `def_id` in the resolver-local Dictionary (story 002's memo); `legal_targets(def_id, source)` applies the filter over canonical order and excludes enemy Stealth minions for `chosen` (match-rules C12) — Stealth exclusion is the only runtime rule beyond the filter.
- The 10 for `HAND_SIZE` is match-rules' knob; the validator receives it through `caps` or the `configs` map (ADR-0002 D4 passes all parsed bodies; the 7b adapter may fold `configs["match_rules"].HAND_SIZE` into `caps`) — never a literal in the validator.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: every other `E_FX_*` code
- Story 006: the `chosen` target reaching the ops at runtime (`target` ref, `NO_LEGAL_TARGET` rejection path belongs to match-rules C6)
- Story 016: `RESOLUTION_STEP_CAP` at runtime (AC-38)

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/gameplay/effects/effect_validator.gd` (`step_bound`, `derive_targeting_spec`, `E_FX_BUDGET`, `E_FX_OP_TARGET`)
- `src/gameplay/effects/effect_resolver.gd` (`targeting_spec`, `legal_targets`)
- `src/gameplay/effects/selectors.gd` (canonical-order enumeration used by `legal_targets`; grown by story 007)
- `tests/unit/card_effects/card_effects_validator_bound_targeting_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/card_effects/card_effects_validator_bound_targeting_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/card-effects/story-003-validator-schema-codes.md`, `production/epics/card-effects/story-002-runtime-binding-config.md` (resolver memo). Cross-epic: `production/epics/match-rules/` (`legal_commands()` calling `targeting_spec(def_id)`; `HAND_SIZE` in `match_rules.json`).
- Unlocks: `production/epics/card-effects/story-005-fixture-set-database-injection.md`, `production/epics/card-effects/story-006-play-triggers-one-pass.md`
