# Story 008: Aura treasures — Whetstone Wheel and Stampede Horn on the hero slot

> **Epic**: Treasures
> **Status**: In Review
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: S
> **Manifest Version**: 2026-11-04
> **Last Updated**: [set by /dev-story when implementation begins]
> **First Playable path**: no

## Context

**GDD**: `design/gdd/treasures.md` (T1 "auras hosted on the owner's hero slot", T8 rows 11, 19; T9; Edge Cases "Silenced recipient"; AC-22, AC-24)
**Requirement**: `TR-treasures-001` (owner-scoped hosts; treasure auras are not registry entries)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Effect Resolver / Validator Boundary (most direct: `recompute_auras` walks treasure / passive auras on the hero slot after both boards); ADR-0005: Owner-scoped hook registry (the installer carries the aura effect; `side` scopes it)
**ADR Decision Summary**: An `aura`-trigger treasure effect is hosted on the owner's hero slot. The C10 loop's `recompute_auras()` strips every `is_aura` enchantment, then re-applies each live source in canonical order: player board, boss board, then treasure / passive auras. Each (source, target) gets one `is_aura` enchantment with `source_id` = the treasure id.
**ADR Version**: 2026-11-03 (ADR-0007); 2026-11-03 (ADR-0005)

**Engine**: Godot 4.7.2 | **Risk**: HIGH (by version); LOW for the APIs
**Engine Notes**: ADR-0007 Engine Compatibility — no post-cutoff API.

**Control Manifest Rules (this layer)**:
- Required: one effect pass = one C10 step; mutate only through primitives (`apply_enchantment` with `is_aura: true`)
- Forbidden: never let an `aura` grant `stealth` (DD-X16; `EffectValidator` rejects it); never call the death check or `recompute_auras()` between ops
- Guardrail: `RulesEngine.submit()` ≤ 5 ms

---

## Acceptance Criteria

*From GDD `design/gdd/treasures.md` (AC-22, AC-24), scoped to this story:*

- [ ] **AC-22** Whetstone Wheel: WHEN Whetstone equips the 1/2 blade, THEN the weapon reads 2 Attack via an `is_aura` enchantment with `source_id: treasure_whetstone_wheel` and the hero attacks for 2; WHEN the weapon is destroyed, THEN no aura enchantment remains; a later weapon gains it again.
- [ ] **AC-24** Stampede Horn: as card-effects AC-32 — a minion played this turn may attack an enemy minion and is `RUSH_CANNOT_HIT_HERO` against the hero; next turn it attacks freely; without the treasure the same play is `SUMMONING_SICK`.

---

## Implementation Notes

*Derived from ADR-0007 Decision 1 (aura recompute) and card-effects C7:*

- Installers come from `installers_for` (story 001), on seed `00000000000000A7` with hero `hero_war`, so Whetstone is the real War power on the shipped `power_whetstone` record (heroes story 001 seats it from data. Until that lands, set `hero_power.def_id` as card-effects 011 did and note it).
- The treasure-host aura path is card-effects 012 (canonical source order, Complete) plus 013 (the treasure host and keyword auras, AC-32). This story asserts the two T8 records end to end and changes no resolver code unless a test fails.
- Whetstone Wheel targets `owner_weapon` with `attack +1` only (card-effects C5 — weapon auras are attack-only). Whetstone's own `+1 this turn` buff is a separate enchantment. Do not fold the two together in assertions.
- The Silence row in Edge Cases (strip, re-apply at the next recompute, net no change) is generic aura behaviour proven in card-effects 012. Do not re-test it here.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Card-effects 012 / 013: aura recompute and treasure-host keyword auras
- Non-MVP auras (Sprinter's Boots, Plague Bell, Captured Standard): Alpha, with their Content batch

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `tests/integration/treasures/treasures_auras_test.gd`
- No production file planned

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/treasures/treasures_auras_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/treasures/story-001-installers-passive-and-collect-state.md`. Cross-epic: `production/epics/card-effects/story-013-transform-copy-keyword-aura.md`; Complete: `production/epics/card-effects/story-012-auras-enchantments.md`, `production/epics/card-effects/story-011-hero-powers.md`; soft: `production/epics/heroes/story-001-war-hero-seated-from-herodef.md`
- Unlocks: content story 006 behaviour sign-off for rows 11 and 19
