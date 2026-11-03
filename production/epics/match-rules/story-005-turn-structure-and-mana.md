# Story 005: Turn structure, mana curve and turn cap

> **Epic**: Match Rules
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-03

## Context

**GDD**: `design/gdd/match-rules.md` (C3 step 8; C4 Turn structure — Start, Main, End steps; C5 permanent crystals; F4 Mana available by turn; C14 `TURN_CAP`; States transition table; Interactions `on_turn_start` / `on_turn_end` hooks and `turn_start` / `turn_end` trigger points)
**Requirement**: `TR-match-rules-006` (trigger points and hooks the Start/End steps fire), `TR-match-rules-005` (`add_mana(side, n, temporary=false)`), `TR-match-rules-007` (`turn_cap` outcome)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Effect Resolver / Validator Boundary (the engine owns the phase machine and fires trigger points with `ctx.candidates` in engine order); also ADR-0005 (`run_triggers` at Start step 4 / End step 3, each entry one step)
**ADR Decision Summary**: The engine owns time and order: *when* a trigger point fires, *which* entities are candidates and in *what* order (board order, player side first) is the engine's; *who responds* is the resolver's. Hook trigger entries run synchronously as their own step at the hook point, each followed by the full C10 loop.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: HIGH by version; APIs used predate 4.3. The engine is synchronous — no `await` under `src/gameplay/**` (gate G2b); the Start step runs to completion inside the call that triggered it (`mulligan` or `end_turn`).

The turn loop is where the clock of the match lives: `turn` advances on every Start step for either side, each side's own `turns_taken` drives its mana (F4), and `TURN_CAP` guarantees termination for AI-vs-AI simulation. The candidate order the engine hands the resolver at `turn_start` / `turn_end` is **the** observer order used everywhere (player board left to right, player weapon, player hero power/hero enchantments, then the boss side — regardless of whose turn it is).

**Control Manifest Rules (this layer)**:
- Required: `RulesEngine` owns … the phase machine, `win_loss_check`, the C10 loop … it fires trigger points with `ctx.candidates` already in engine order (ADR-0007); hook catalogue trigger points include `on_turn_start`, `on_turn_end` (ADR-0005); value folds — the engine clamps exactly once after the whole fold with bounds from `config("match_rules")` (ADR-0005)
- Forbidden: never let the resolver own the C10 loop or the trigger queue (ADR-0007 Alt 1); never re-sort candidates across entities in the resolver (ADR-0007); never special-case "player only" in engine code — scope is data (ADR-0005)
- Guardrail: `submit()` ≤ 5 ms worst case — the `end_turn` handler runs End step + the other side's Start step inside one call; both must stay within it

---

## Acceptance Criteria

*From GDD `design/gdd/match-rules.md`, scoped to this story:*

- [ ] AC-05 **GIVEN** the mulligan resolved, **WHEN** the first Start step completes, **THEN** `turn == 1`, `active_side == PLAYER`, player mana `1/1`, player hand has 4 cards; `match_started` precedes `turn_started`, and the Start-step events are in C4 order: `turn_started`, `crystal_gained`, `mana_refilled`, `turn_reset` (one event listing the affected entity ids), [hook/trigger events], `card_drawn`, `phase_changed(Main)`.
- [ ] AC-06 **GIVEN** a match in progress, **WHEN** each side has taken 12 turns (scripted `end_turn`s), **THEN** `mana_max` is 10 for both and was `min(turns_taken + crystal_bonus, 10)` at every Start step (F4), `crystal_gained` was emitted only on Start steps where `mana_max` rose and `mana_refilled` on every one; **GIVEN** `crystal_bonus = 1` for the player (an `on_match_start` hook calling `add_mana(PLAYER, 1, temporary=false)`), **THEN** `mana_added {side: PLAYER, n: 1, temporary: false}` precedes the first `card_drawn`, the player reads 2/2 on turn 1 and 10/10 from turn 9, while the boss is unchanged.
- [ ] AC-09 **GIVEN** player Main, **WHEN** the boss side sends `play_card`, **THEN** rejection `NOT_YOUR_TURN`; **WHEN** the player sends `mulligan`, **THEN** rejection `WRONG_PHASE`; **AND** `end_turn` from the player runs `turn_ending`, `turn_end` triggers in candidate order (player side first, then boss, verified with a scripted resolver that records `ctx.candidates`), `on_turn_end` hooks, thaw, `end_of_turn` enchantment removal, `turn_ended`, then the boss's Start step with `active_side == BOSS`.
- [ ] AC-10 **GIVEN** `TURN_CAP = 4` in test config, **WHEN** the 5th Start step would begin, **THEN** `phase == Ended`, `result.winner == BOSS`, `result.reason == turn_cap`, `match_ended` is the last event (the `MatchResult` record shape is story 008's; this story sets `result` with at least `winner` and `reason`).

---

## Implementation Notes

*Derived from ADR-0007 Decision 1 / Implementation Guidelines, ADR-0005 Decision 4 and GDD C4 / F4:*

- **Start step** for side S (engine-initiated, no commands until Main): (0) if `turn + 1 > TURN_CAP` → end with winner BOSS, reason `turn_cap` (States row `*Turn.Start`, guard `turn > TURN_CAP`). (1) `phase = Start(S)`, `turn += 1`, `S.turns_taken += 1`, emit `turn_started`. (2) `mana_max = min(turns_taken + crystal_bonus, MAX_MANA)`, `mana_current = mana_max`; emit `crystal_gained` when `mana_max` rose, `mana_refilled` always. (3) Reset `attacks_used = 0` for every S character, `summoning_sick = false` for every S minion, `hero_power.used_this_turn = false`; one `turn_reset` event listing the affected entity ids (DD-T04 counts the bulk reset as one mutation). (4) `hooks.run_triggers(&"on_turn_start", S, {})` — each entry one step, C10 loop after each (story 009; before it, call the loop stub). (5) `resolver.resolve(&"turn_start", {side: S, candidates: _candidates_in_order()})` — candidates: player board left→right, player weapon, player hero, then boss board, boss weapon, boss hero — **player side first regardless of S**. (6) `draw(S, 1)` — on turn 1 too. (7) `win_loss_check()`; if not ended, `phase = Main(S)`, emit `phase_changed`.
- **End step** (entered by `end_turn`, phase = Main of issuer): (1) `phase = End(S)`, emit `turn_ending`; (2) `resolver.resolve(&"turn_end", …)` same candidate order; (3) `hooks.run_triggers(&"on_turn_end", S, {})`; (4) thaw rule to every S character (story 015 — stub as no-op with `TODO(story 015)`); (5) remove `expires = end_of_turn` enchantments on **every entity owned by S** — characters, weapon, and `cost_modifiers[]` on hand/deck card instances — one `enchantment_removed` each, then `recompute_auras()`; temporary crystals expire here (story 011); ownership is the recipient's current controller; (6) `win_loss_check()`, emit `turn_ended`, flip `active_side`, run the other side's Start step.
- `add_mana(side, n, temporary=false)`: at `on_match_start` raises `crystal_bonus` permanently and emits `mana_added {side, n, temporary: false}`; the Start step reads `crystal_bonus` every turn. The `temporary=true` branch is story 011.
- `match_started` is emitted at C3 step 8 after `mulligan_resolved`, before the first Start step.
- `turn` is 0 during Setup and Mulligan; the global counter advances on **every** Start step, so at global turn 7 the player is on its 4th own turn (F4 example).
- The resolver double records `ctx.candidates` per `resolve` call so the candidate order is asserted, not inferred.
- Every number (`MAX_MANA`, `TURN_CAP`) comes from `rules_config`; tests override `TURN_CAP` through the config Dictionary they pass to `_init`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 008: `MatchResult` record, `concede`, `win_loss_check` outcomes beyond `turn_cap`
- Story 009: the real C10 loop after each hook/trigger step
- Story 011: temporary crystals (`add_mana(..., temporary=true)`) and their End-step expiry
- Story 015: the thaw rule at End step 4

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/gameplay/match/rules_engine.gd` — C3 step 8 (`match_started`), `_start_step`, `_end_step`, `end_turn` handler, `_candidates_in_order`, `_fire_trigger_point` + engine queue `_queue`, `_expire_end_of_turn`, `add_mana` permanent branch, `TURN_CAP` guard and `_end_match`, `legal_commands` `end_turn` row, log turn stamping
- `tests/helpers/test_effect_resolver.gd` — unchanged here: `resolve_calls` / `candidates_for` already record `ctx.candidates` (added with the double in story 003)
- `tests/unit/match_rules/match_rules_command_channel_test.gd` — AC-03 test now reads the zones at `mulligan_resolved` (the Start step's draw follows it since this story)
- `tests/unit/match_rules/match_rules_turn_structure_test.gd` — 12 test functions

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/match_rules/match_rules_turn_structure_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later). `qa.level: standard` — BLOCKING.

**Status**: [x] Created and passing (12 test functions)

---

## Dependencies

- Depends on: `production/epics/match-rules/story-004-command-channel-and-mulligan.md`
- Unlocks: `production/epics/match-rules/story-006-primitives-draw-burn-fatigue.md`

## Completion Notes
**Completed**: 2026-11-03 (started 21:17:50 UTC, ended 21:28 UTC)
**Criteria**: 4/4 passing — AC-05 (`test_first_start_step_gives_turn_one_player_one_crystal_and_four_cards`, `test_first_start_step_events_follow_c4_order`, `test_turn_reset_clears_only_the_starting_sides_characters`), AC-06 (`test_twelve_turns_each_follow_f4_and_cap_at_max_mana`, `test_global_turn_seven_is_the_players_fourth_turn`, `test_permanent_crystal_from_on_match_start_raises_the_player_curve_only`, `test_add_mana_permanent_raises_crystal_bonus_and_is_read_at_the_next_start`), AC-09 (`test_player_main_rejects_boss_play_card_and_a_second_mulligan`, `test_end_turn_runs_the_end_step_in_c4_order_then_the_boss_start`, `test_end_turn_result_spans_end_step_and_next_start_step`), AC-10 (`test_turn_cap_ends_the_match_for_the_boss_before_the_next_start_step`). Watched fail: all 12 against the story-004 engine; mutant ordering candidates active-side-first and emitting `crystal_gained` every Start (3 tests fail); mutant with an off-by-one `TURN_CAP`, hooks after triggers and no end-of-turn expiry (3 tests fail).
**Deviations** (advisory):
- `turn_started` payload is `{turn, side}`: the rng-event-log catalogue row also lists `mana_max, mana_available`, but C4 emits `turn_started` before the mana step, so those values would be the previous turn's; they are carried by `crystal_gained {side, mana_max, gained}` and `mana_refilled {side, mana_available, mana_max}`.
- `enchantment_removed` payload is `{instance_id, attack_delta, health_delta, keywords_added, reason: "end_of_turn"}` (the removed enchantment's own values); the catalogue's derived `attack / health / max_health` fields are left to the primitive story (`remove_enchantment`), since a weapon or a hand card has none.
- The C10 loop and `win_loss_check` are stubs (`TODO(story 009)`, `TODO(story 008)`); trigger hooks run as one `run_triggers` call followed by the loop stub, not the loop after each entry (needs a per-entry seam in `HookRegistry`, story 009). Triggers `resolve()` returns are appended to the engine's `_queue`, not drained yet.
- `match_ended` carries `MatchRecords.match_result` with `turns_per_side` and `final_health` filled; the stats block and `resolver.unbind()` remain story 008.
- `legal_commands()` lists `end_turn` in Main (C2: "plus `end_turn`"); the rest of Main's expansion is stories 010–016.
- The log's turn is stamped through `set_turn(n)` when the log has it, else the `TestEventLog.turn` property (`TODO(rng-event-log story 005)`).
- Thaw at End step 4 is a no-op (`TODO(story 015)`); temporary crystals are story 011 (`add_mana(..., true)` logs an error and changes nothing).
- Shared-test change: story 004's AC-03 test now snapshots hand and deck at `mulligan_resolved`, because the Start-step draw now follows the mulligan in the same call.
**Test Evidence**: `tests/unit/match_rules/match_rules_turn_structure_test.gd` (12 tests); full suite 381 test cases, 0 failures, exit 0; smoke exit 0, no SCRIPT ERROR.
**Run result**: N/A — the story changes the headless turn loop and event log only; no scene, node or screen renders it (Match UI is a later epic).
**Reviewed by**: self, no independent review (LP-CODE-REVIEW skipped — Lean mode; QL-TEST-COVERAGE skipped — Lean mode)
