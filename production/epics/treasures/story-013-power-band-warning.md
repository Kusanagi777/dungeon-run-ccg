# Story 013: `W_TR_POWER` — the F1 power-band warning at load

> **Epic**: Treasures
> **Status**: Blocked — BLOCKED: GDD gap. T7 has the load-time validator raise `W_TR_POWER` when "F1 power [is] outside the rarity's band", but F1 is "a design-time estimate … never computed at runtime". Its per-treasure computations (T8's Power column, F1's worked table) are hand-derived and are not a function of `effects[]`. No rule maps an effect to `n_triggers` / `value_per_trigger` / `efficiency`, and `treasures_balance.json` lacks F1's `V_MANA`, `T_TURNS`, `N_*`, `AOE_FACTOR`, `LEGENDARY_SURPLUS`. Resolve with a treasures GDD revision (`/quick-design` or `/design-system treasures`) that chooses one of: a per-record power source the validator can read, a mechanical effect→F1 mapping, or moving `W_TR_POWER` from load to `/balance-check`. Then edit this story's criteria to match
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-11-04
> **Last Updated**: [set by /dev-story when implementation begins]
> **First Playable path**: no

## Context

**GDD**: `design/gdd/treasures.md` (T7 `W_TR_POWER` row, F1, T8 Power column, AC-29, AC-30 second half)
**Requirement**: `TR-card-database-002` (carried: the `treasure` delegated validator)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Owner-scoped hook registry (`validate_treasure_defs` includes `W_TR_POWER` in its closed set)
**ADR Decision Summary**: `W_TR_POWER` is a warning in `Treasures.validate_treasure_defs`'s closed code set: an observation for `/balance-check`, never a block, so the load stays `OK`.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (by version); LOW for the APIs
**Engine Notes**: ADR-0005 Engine Compatibility — no post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: validators are static and pure; constants come from config bodies passed in (`configs["treasures_balance"]`), never `config()` during stage 7
- Forbidden: never a numeric gameplay literal (every F1 constant is data); never turn a warning into an error
- Guardrail: data load ≤ `data_load_budget_ms` 200

The ADR (ADR-0005) is Accepted. The block is on the design side only: the GDD asks for a load-time check of a value it says is never computed. This story is written now so the gap is tracked against the code set ADR-0005 already fixes.

---

## Acceptance Criteria

*From GDD `design/gdd/treasures.md` (AC-29, AC-30), scoped to this story:*

- [ ] **AC-29** GIVEN a fixture copy of Hollow Crown with `rarity: common`, WHEN loaded, THEN `W_TR_POWER` is reported and the load is `OK`.
- [ ] **AC-30 (second half)** Every F1 constant the check uses is read from `treasures_balance.json`; none is a literal in `src/`.

---

## Implementation Notes

*Derived from ADR-0005 Key Interfaces; to be revised with the GDD change that unblocks this story:*

- The check slots into story 003's `validate_treasure_defs` as one more warning. A boundary value takes the lower rarity (T8: "a value on the boundary takes the lower rarity"; Iron Constitution 3.5 → Common).
- Whatever power source the GDD revision picks, story 010's config spec gains the F1 constants in the same change (`treasures_balance.json` and `Treasures.validate_config`).
- Until this story is unblocked, `validate_treasure_defs` does not emit `W_TR_POWER`. Story 003 records that skip in its Completion Notes and in its doc comment, so a reader can tell "not checked" from "checked, in band" (skill-authoring rule 3: a skipped step announces itself).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: the other T7 codes; Story 010: the `treasures_balance` validator
- `/balance-check`: rarity re-tiering from run logs

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/gameplay/treasures/treasures.gd` — `W_TR_POWER` in `validate_treasure_defs`
- `assets/data/treasures_balance.json` — F1 constants (with the GDD change)
- `tests/unit/treasures/treasures_power_band_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/treasures/treasures_power_band_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: the treasures GDD revision named in Status; `production/epics/treasures/story-003-treasure-validator-at-stage-7b.md`, `production/epics/treasures/story-010-treasures-balance-validator-and-data-driven-magnitudes.md`
- Unlocks: None
