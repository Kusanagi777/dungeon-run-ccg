# Story 011: Effective cost, mana payment and temporary crystals

> **Epic**: Match Rules
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-04

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

- [x] AC-07 **GIVEN** player Main with mana 3/3, **WHEN** a 2-cost card is played, **THEN** `mana_current == 1` and `mana_spent {amount: 2}` was emitted before any effect event; mana is never refunded (a Battlecry whose required target is absent still cost its mana); `mana_current` never exceeds `mana_max` and never drops below 0.
- [x] AC-08 **GIVEN** a 4-cost card with a −2 enchantment (`cost_modifiers[]`) and a `modify_cost` hook of −3, **WHEN** `effective_cost` is evaluated, **THEN** it is 0 (`max(0, 4 − 2 − 3)`) and the card is playable at 0 mana (F1); the modifier order is card enchantments → hand-scoped auras → `modify_cost` hooks in installation order; the hero power's `HERO_POWER_COST` goes through the same pipeline.
- [x] AC-45 **GIVEN** player Main on turn 3 with mana 1/3, **WHEN** an effect calls `add_mana(PLAYER, 2, temporary=true)`, **THEN** `mana_added {side: PLAYER, n: 2, temporary: true}` is emitted and the player reads 3/5; **WHEN** the player's End step runs, **THEN** the player reads `mana_max 3` and `mana_current ≤ 3` before `turn_ended`, no `crystal_gained` was emitted, and the next player Start step refills to 4/4 (F4, no `crystal_bonus` change); **GIVEN** mana 9/10, **WHEN** `add_mana(PLAYER, 2, temporary=true)` resolves, **THEN** the player reads 10/10 (clamped to `MAX_MANA`).

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

- `src/gameplay/match/rules_engine.gd` (`effective_cost(card, side)` with the `modify_cost` fold and one clamp, `hero_power_cost(side)`, `COST_KIND_*`, `add_mana` temporary branch, End step 5 expiry)
- `src/gameplay/match/match_state.gd` (`temporary_crystals` on `PlayerState`)
- `tests/unit/match_rules/match_rules_cost_test.gd` (new, 13 tests)
- `tests/unit/match_rules/match_rules_data_model_test.gd` (C1 PlayerState field list gains `temporary_crystals`)

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/match_rules/match_rules_cost_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later). `qa.level: standard` — BLOCKING.

**Status**: [x] Created — 13 tests, passing

---

## Dependencies

- Depends on: `production/epics/match-rules/story-010-play-card-and-hero-power.md`, `production/epics/match-rules/story-002-hook-registry.md`
- Unlocks: `production/epics/match-rules/story-017-clone-and-replay.md`

---

## Completion Notes
**Completed**: 2026-11-04 (started 02:44:02 UTC, ended 02:52 UTC; a per-run turn limit and a worktree move interrupted it once, no work lost)
**Readiness** (`/story-readiness` by hand, 2026-11-04): READY — ADR-0005 Accepted; TR-match-rules-005 / 006 active; Manifest Version 2026-11-03 current; dependencies 010 and 002 Complete; 3 testable criteria; no open markers. QL-STORY-READY skipped — Lean mode.
**Criteria**: 3/3 passing (`tests/unit/match_rules/match_rules_cost_test.gd`, 13 tests):
- AC-07: `test_a_two_cost_card_at_three_mana_leaves_one_and_pays_before_any_effect`, `test_a_battlecry_with_no_legal_target_still_costs_its_mana`, `test_a_card_whose_effective_cost_is_zero_is_playable_at_zero_mana` (never below 0), `test_temporary_mana_is_clamped_to_max_mana` (never above `mana_max`).
- AC-08: `test_effective_cost_folds_enchantment_then_hook_and_clamps_once_at_zero`, `test_a_card_whose_effective_cost_is_zero_is_playable_at_zero_mana`, `test_cost_hooks_fold_in_installation_order_with_no_clamp_between_entries`, `test_a_set_hook_then_a_delta_hook_apply_in_installation_order`, `test_a_hand_aura_modifier_is_counted_once_before_the_hooks`, `test_the_cost_fold_context_names_the_card_and_its_kind`, `test_the_hero_power_cost_goes_through_the_same_fold`, `test_a_raised_hero_power_cost_is_not_payable_at_the_printed_cost`.
- AC-45: `test_temporary_mana_raises_max_and_current_and_expires_at_the_end_step` (mana read inside a `turn_ended` subscriber), `test_temporary_mana_is_clamped_to_max_mana`, `test_temporary_crystals_cannot_take_current_mana_below_zero_at_expiry`.
Watched fail: the suite failed to parse against the story-010 engine (no `effective_cost(card, side)`, no `COST_KIND_*`). Mutants, one per run: the `modify_cost` fold removed from `effective_cost` → 6 tests fail; the End-step expiry skipped → 2 tests fail.
**Decisions recorded**:
- **`modify_cost` fold context** (contract for card-effects 014 and the real `apply_value_hook`): `ctx {card, kind}`, one reused Dictionary (the fold allocates nothing). `kind` is `RulesEngine.COST_KIND_CARD` (`card` = the hand `CardInstance`) or `COST_KIND_HERO_POWER` (`card` = `PlayerState.hero_power {def_id, used_this_turn}`), which is what the card-effects C2 `kind: hero_power | any` scope filter reads.
- `effective_cost(card, side = "")`: the engine's callers pass the side; `""` reads the holder from the state. New public `hero_power_cost(side)`. `legal_commands`, C6 / C7 validation and payment all use them, so display and payment agree.
- Hand-scoped auras are counted through `cost_modifiers` (`is_aura`), the same sum as the card's own enchantments, so each counts once.
- Temporary-crystal expiry runs inside the End step 5 step (after the `end_of_turn` enchantments) and emits nothing, per the story note (the GDD names no event).
**Deviations** (advisory):
- `tests/helpers/match_factory.gd` is not edited: `MatchFactory.make_player_state` builds through `MatchState.make_player_state`, so it has `temporary_crystals: 0` already. `match_rules_data_model_test.gd` (not in the planned file list) gains the field in its pinned C1 list.
- No separate `pay_mana(side, amount)` function: payment stays in `_accept_card` / `_accept_hero_power` (story 010), now paying `effective_cost` / `hero_power_cost`. `mana_spent` keeps its story-010 payload `{side, amount, mana_current}`; the note's `card` key is not added (C15 and AC-07 name none).
- Card-effects follow-up (not edited here): `src/gameplay/effects/ops.gd` `_op_mana` logs `applied` for `duration: this_turn`. With this story the engine accepts temporary crystals, so `applied` is correct again wherever lane 4 changed it to `skipped`.
- GDD C1's PlayerState list should gain `temporary_crystals` (owner: match-rules GDD).
**Test Evidence**: `tests/unit/match_rules/match_rules_cost_test.gd` (13 tests). Import exit 0. Full suite (`commands.test`): 1091 test cases, 0 failures, exit 0, 85 SCRIPT ERROR lines, all existing intentional negatives (none from match code). Smoke exit 0, no SCRIPT ERROR.
**Run result**: N/A — headless rules code; no scene or screen shows costs or mana yet (Match UI is a later epic).
**Reviewed by**: independent `/code-review` 2026-11-04 (by hand, `code-review-s4-mr011-016`): **NOT ASSESSED** (engine-specialist and qa-tester passes could not be spawned; perf guardrail had no match-rules data), substantively APPROVED WITH SUGGESTIONS. Fixes (sprint 4, lane 1 review-fix slot): S5 off-turn temporary crystals are discarded by the Start-step refill — `3c13408` (`test_temporary_crystals_granted_on_the_opponents_turn_never_cut_mana_below_f4`). Open nits: N6 (side-less `effective_cost` untested), N8 (`_cost_ctx` not re-entrant), N9 (clamped grant vs expiry wording). QL-TEST-COVERAGE skipped — Lean mode
