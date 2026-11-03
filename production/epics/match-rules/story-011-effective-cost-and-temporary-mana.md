# Story 011: Effective cost, mana payment and temporary crystals

> **Epic**: Match Rules
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/match-rules.md` (C5 Mana and costs; F1 Effective cost; C4 End step 5 — temporary crystals expire; Interactions `modify_cost`)
**Requirement**: `TR-match-rules-006` (`modify_cost` fold-then-clamp), `TR-match-rules-005` (`add_mana(side, n, temporary=true)`)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Owner-scoped hook registry (Decision 4 and Key Interfaces: `cost = clampi(hooks.fold(&"modify_cost", side, base_cost, {card: ci}), 0, …)`)
**ADR Decision Summary**: `modify_cost` is a value fold evaluated on every F1 evaluation (display and payment), entries in installation order, the engine flooring the result at 0 exactly once after the whole chain; the fold allocates nothing.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: HIGH by version; APIs used predate 4.3. `effective_cost` is evaluated for every hand card on every `legal_commands()` call — keep it a pure function over the card instance, the board and the registry with no allocation.

F1 is a fixed-order sum: card enchantments, hand-scoped auras, then the `modify_cost` hooks, floored at 0 once. Temporary crystals (Content's `decay_soul_tithe`, `neutral_treasure_map`) raise both `mana_max` and `mana_current` until the owner's End step and never touch `crystal_bonus`, so the next Start-step refill ignores them.

**Control Manifest Rules (this layer)**:
- Required: value folds — `delta` adds, `set` replaces, `mul` multiplies; the engine clamps exactly once after the whole fold (≥ 0 for cost) (ADR-0005); hook catalogue value points include `modify_cost` (ADR-0005)
- Forbidden: never clamp inside the fold or inside a `modify_value` op; never allocate in the fold; never special-case "player only" in engine code (ADR-0005)
- Guardrail: `legal_commands()` ≤ 2 ms — `effective_cost` is on its hot path (ADR-0007, ADR-0001)

---

## Acceptance Criteria

*From GDD `design/gdd/match-rules.md`, scoped to this story:*

- [ ] AC-07 **GIVEN** player Main with mana 3/3, **WHEN** a 2-cost card is played, **THEN** `mana_current == 1` and `mana_spent {amount: 2}` was emitted before any effect event; mana is never refunded (a Battlecry whose required target is absent still cost its mana); `mana_current` never exceeds `mana_max` and never drops below 0.
- [ ] AC-08 **GIVEN** a 4-cost card with a −2 enchantment (`cost_modifiers[]`) and a `modify_cost` hook of −3, **WHEN** `effective_cost` is evaluated, **THEN** it is 0 (`max(0, 4 − 2 − 3)`) and the card is playable at 0 mana (F1); the modifier order is card enchantments → hand-scoped auras → `modify_cost` hooks in installation order; the hero power's `HERO_POWER_COST` goes through the same pipeline.
- [ ] AC-45 **GIVEN** player Main on turn 3 with mana 1/3, **WHEN** an effect calls `add_mana(PLAYER, 2, temporary=true)`, **THEN** `mana_added {side: PLAYER, n: 2, temporary: true}` is emitted and the player reads 3/5; **WHEN** the player's End step runs, **THEN** the player reads `mana_max 3` and `mana_current ≤ 3` before `turn_ended`, no `crystal_gained` was emitted, and the next player Start step refills to 4/4 (F4, no `crystal_bonus` change); **GIVEN** mana 9/10, **WHEN** `add_mana(PLAYER, 2, temporary=true)` resolves, **THEN** the player reads 10/10 (clamped to `MAX_MANA`).

---

## Implementation Notes

*Derived from ADR-0005 Decision 4 / Key Interfaces and GDD C5 / F1:*

- `effective_cost(card_instance, side) -> int`: `base = db.card(def_id).cost`; `+ Σ card_instance.cost_modifiers[].cost_delta` (enchantments on the card while in hand, Card Effects' "costs 1 less this turn"); `+ Σ hand-scoped aura deltas` from minions in play whose aura scope is `hand` (the resolver's `recompute_auras` applies them as `cost_modifiers` tagged `is_aura` — so this term is already in `cost_modifiers`; document that they are counted once); then `cost = maxi(0, hooks.fold(&"modify_cost", side, cost_so_far, {card: card_instance}))` — the one clamp. Used for both display (`legal_commands`) and payment.
- `pay_mana(side, amount)`: `mana_current −= amount`, emit `mana_spent{side, amount, card}`; called at acceptance, before any effect step; never refunded.
- `add_mana(side, n, temporary)`: `temporary = false` → `crystal_bonus += n`, `mana_added{temporary: false}` (story 005). `temporary = true` → `temp = min(n, MAX_MANA − mana_max)`; `mana_max += temp`, `mana_current = min(mana_current + n, MAX_MANA)`, record `temporary_crystals += temp` on the `PlayerState`, emit `mana_added{side, n, temporary: true}`. At that side's End step 5: `mana_max −= temporary_crystals`, `mana_current = max(0, mana_current − temporary_crystals)`, `temporary_crystals = 0` (no event beyond the existing `turn_ending` / `turn_ended` pair — the GDD names none; if the UI needs one it is a C15 GDD change). The next Start step's F4 refill ignores them.
- `temporary_crystals` is a `PlayerState` field added by this story (plain int; `MatchFactory.make_player_state` gains it with default 0).
- `MAX_MANA`, `HERO_POWER_COST` from `rules_config`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 005: permanent `crystal_bonus` and the Start-step refill
- Story 010: the `play_card` handler that calls `effective_cost` / `pay_mana`
- Card Effects epic: the `mana` op with `duration: this_turn`, cost enchantments, hand auras

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/gameplay/match/rules_engine.gd` (`effective_cost` with the fold, `pay_mana`, `add_mana` temporary branch, End-step expiry)
- `src/gameplay/match/match_state.gd` (`temporary_crystals` on `PlayerState`)
- `tests/helpers/match_factory.gd` (`temporary_crystals: 0`)
- `tests/unit/match_rules/match_rules_cost_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/match_rules/match_rules_cost_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later). `qa.level: standard` — BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/match-rules/story-010-play-card-and-hero-power.md`, `production/epics/match-rules/story-002-hook-registry.md`
- Unlocks: `production/epics/match-rules/story-017-clone-and-replay.md`
