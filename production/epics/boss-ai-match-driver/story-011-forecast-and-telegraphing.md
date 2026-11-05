# Story 011: Forecast and telegraphing — Intent, intent keys, kept, effective_mode

> **Epic**: Boss AI + Match Driver
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-05
> **Readiness**: READY (2026-11-05, by hand: story 008 merged at M1; ADR-0006 and ADR-0008 Accepted; manifest 2026-11-04 adds no rule against it; the QA plan's Frozen gap followed as match-rules C13; BAI review N5 and the wave 1 findings folded in)

## Context

**GDD**: `design/gdd/boss-ai.md` (C8.1–C8.5, C1.4 `forecast`, States `Forecasting`, Interactions Meta Progression row, Edge Cases "forecast and the real turn disagree")
**Requirement**: `TR-boss-ai-004`, `TR-boss-ai-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008: Match Driver Ownership and the Run ↔ Match ↔ UI Hand-off (the driver starts the forecast task at `PlayerTurn.Main`, appends `ai_intent_shown` on the main thread, applies `telegraph_mode` through `boss_ai.set_telegraph_mode`); ADR-0006 (forecast uses the same seam and clone rule; a stale forecast is discarded)
**ADR Decision Summary**: `forecast(sandbox) -> Intent` runs the planner on a clone as if it were the boss's turn with next turn's mana, using `ai_stream.fork("forecast_<turn>")`, and returns the plan's dominant action as an `Intent {boss_id, intent_key, target_id, amount, effective_mode}`; the driver emits `ai_intent_shown`. At `BossTurn.Main` the real plan's first diagnostic is `ai_intent_committed {…, kept}` with `kept = true` when the committed intent class equals the forecast. `effective_mode = min(intent_mode, telegraph_mode)` over `full > class_only ≡ brief > hidden ≡ off`.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH / NOT SOURCEABLE
**Engine Notes**: Forecast runs on a worker while the main thread reads the frozen `CardDatabase` (`MatchQuery.card_text`) — concurrent read-only access is NOT SOURCEABLE and stress-tested in Story 017. `set_telegraph_mode` mutates a field on the shared `BossAI`; the driver only calls it when no task is live (ADR-0008 Decision 7), so no lock is needed.

**Control Manifest Rules (this layer)**:
- Required: `forecast` runs on a clone at `PlayerTurn.Main` with no gate on player input; a stale premise is discarded silently; `ai_intent_shown` is appended by the driver on the main thread. `telegraph_mode` is applied via `on_setting_changed` → `boss_ai.set_telegraph_mode` when no task is live, else deferred to `_on_task_done()`.
- Forbidden: The intent is never fabricated — it is a projection of a plan the planner would execute on the forecast state. Hidden: which card will be played, Discover picks, anything that would reveal the hand.
- Guardrail: Forecast is its own planner run off-thread, during the player's turn; A22 measures it separately from `play_turn`, each p95 ≤ 500 ms (2026-11-04, DD-X18); was "forecast doubles the per-round worker cost; A22 measures forecast + play_turn together". A forecast still running at End Turn is discarded (ADR-0008; boss-ai C8 tolerates "plan changed").

---

## Acceptance Criteria

*From GDD `design/gdd/boss-ai.md` A19, A21 and C8.1 / C8.4, scoped to this story:*

- [ ] **A19** GIVEN boss attackers 4 + 3 and `intent_mode = full`, WHEN the player's turn starts (`telegraph_mode = full`), THEN `ai_intent_shown {intent_key: attack_face, amount: 7, effective_mode: full}` is emitted; GIVEN `class_only`, THEN `amount` and `target_id` are null; GIVEN `intent_mode = full` and `telegraph_mode = brief`, THEN `effective_mode = class_only` and `amount`/`target_id` are null; GIVEN `telegraph_mode = off` (or a `boss_overrides` entry with `intent_mode = hidden`), THEN `effective_mode = hidden`, no `ai_intent_shown` is emitted and `ai_intent_committed` still is; GIVEN the band-1/2/3 overlays with no `boss_override`, THEN none resolves to `hidden`.
- [ ] **A21** GIVEN the player kills the boss's only attacker after an `attack_face` forecast, WHEN the boss turn starts, THEN `ai_intent_committed.kept = false` and the new `intent_key ≠ attack_face`; the forecast is never retro-edited.
- [ ] GIVEN `PlayerTurn.Main` at boss turn counter `t_side`, WHEN `forecast(sandbox)` runs, THEN the sandbox is planned with `mana_max_by_turn(t_side + 1)` (match-rules F4, so a boss `crystal_bonus` is forecast too) and its current hand, draws only from `ai_stream.fork("forecast_<turn>")`, and the `Intent` names the plan's dominant action — the first lethal step if lethal is proven, else the highest-scoring action class — from the closed key set `lethal, attack_face, attack_minion, play_big_minion (cost ≥ 5), develop_board, cast_removal, cast_aoe, heal, hero_power, equip_weapon, pass`.
- [ ] GIVEN no `telegraph_mode` setting at construction (MVP), WHEN `BossAI` is built, THEN the effective setting is `full`; GIVEN a Frozen boss board, THEN the intent is `develop_board` or `pass`, never a fabricated `attack_face`; `amount` counts only attackers that exist now (cards in hand are not revealed).

---

## Implementation Notes

*Derived from ADR-0008 Decisions 3 and 7, ADR-0006 Decision and GDD C8:*

- Files: `src/ai/intent.gd` (`class_name Intent extends RefCounted`, plain data `{boss_id, intent_key, target_id, amount, effective_mode}`, `to_dict()`), `src/ai/boss_ai.gd` additions: `forecast(sandbox) -> Intent` (coroutine — it awaits `plan_turn`-shaped planning), `set_telegraph_mode(mode)`, `intent_from_plan(plan) -> Intent`, `effective_mode()`; `plan_turn`'s first diagnostic becomes `ai_intent_committed {intent_key, target_id, amount, kept, effective_mode}` with `kept = (committed.intent_key == last_forecast.intent_key)`.
- Forecast state: plan on `engine.clone()` after advancing the clone's mana as if the boss's turn had begun with `mana_max_by_turn(t_side + 1)`; use match-rules' public API for that (never poke `MatchState`); thaw per match-rules C13 on the cloned state.
- Mode arithmetic: `intent_mode ∈ {full, class_only, hidden}` from the resolved profile (band overlays never set `hidden`; band 1 is always `full`); `effective_mode = min(intent_mode, telegraph_mode)` with `brief ≡ class_only`, `off ≡ hidden`. `class_only`/`hidden` null out `amount` and `target_id`; `hidden` suppresses `ai_intent_shown` only (the driver checks `effective_mode` before appending), `ai_intent_committed` always carries it.
- `last_forecast` is held on `BossAI` (`Idle` "holds the resolved profile and the last forecast only"); a discarded (stale) forecast is not stored — the driver tells the AI only when it appended `ai_intent_shown`.
- `presentation` timings (`intent_banner_s`, `plan_changed_s`) are Match UI's to read; nothing here waits.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 014: when the driver starts the forecast task, stale-premise discard, deferring `telegraph_mode` while a task is live.
- `match-ui` epic: the banner and "plan changed" rendering.
- `meta-progression` epic: storing the `telegraph_mode` setting (DD-X03).

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/ai/intent.gd` (new)
- `src/ai/boss_ai.gd` (`forecast`, `forecast_task`, `choose_task`, `note_forecast`, `set_telegraph_mode`, `effective_mode`, `intent_from_plan`, the commit)
- `src/ai/turn_plan.gd` (`intent_rows`, `INTENT_EVENTS`; the checksum skips them)
- `src/ai/scorer.gd` (`CONTEXT_SIDE`, `big_minion_cost`), `src/ai/chooser.gd` (`own`, `card_tags`), `src/ai/lethal_search.gd` (passes `own`)
- `tests/unit/boss_ai/boss_ai_forecast_test.gd` (new)
- `tests/unit/boss_ai/boss_ai_choose_test.gd`, `boss_ai_plan_task_shape_test.gd`, `boss_ai_plan_turn_test.gd`
- `tests/fixtures/boss_ai/attackers_4_3.json`, `tests/fixtures/boss_ai/forecast_then_attacker_killed.json`, `tests/fixtures/boss_ai/frozen_boss_board.json` (new)
- `production/epics/boss-ai-match-driver/story-014-match-driver-phase-schedule.md` (the task signatures)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/boss_ai/boss_ai_forecast_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] Created: `boss_ai_forecast_test.gd` 46 tests, passing

---

## Dependencies

- Depends on: `production/epics/boss-ai-match-driver/story-008-plan-turn-loop-and-turn-plan.md`
- Unlocks: `production/epics/boss-ai-match-driver/story-012-hidden-information-and-purity-gates.md`, `production/epics/boss-ai-match-driver/story-014-match-driver-phase-schedule.md`

---

## Completion Notes
**Completed**: 2026-11-05 (start 00:38 UTC, end 01:10 UTC; sprint 5 lane 2 wave 2, branch `s5/l2-w2`)
**Criteria**: 4/4 passing. A19 `test_a19_*`, `test_c8_4_effective_mode_is_the_lower_of_the_boss_and_the_setting`; A21 `test_a21_killing_the_only_attacker_commits_a_new_intent_and_kept_false`; forecast inputs `test_the_forecast_plans_with_next_turns_mana_and_a_boss_crystal_bonus`, `test_the_forecast_plans_the_current_hand_and_never_the_deck_top`, `test_the_forecast_takes_one_parent_draw_and_never_moves_the_live_game`, `test_a_minion_of_cost_five_is_big_and_of_cost_four_is_not`; defaults and Frozen `test_no_telegraph_setting_at_construction_is_full`, `test_a_frozen_board_*`, `test_amount_counts_only_the_attackers_that_exist_now`. A19's "no `ai_intent_shown` is emitted" is checked here as `Intent.is_shown()`, the driver's gate; the append itself is story 014's (closed 2026-11-05: `test_a19_*` in `match_driver_schedule_test.gd`). A22's forecast p95 is BAI-016's.
**Tests seen failing**: `boss_ai_forecast_test.gd` failed first against missing code (exit 105: `Intent` undeclared). Tests added once the code existed, and the rules worth pinning, were then seen failing against 16 deliberate mutants, all killed: drawn card kept, tie on the live stream, forecast not spent, log read for the wrong side, amount counting any attacker, checksum counting intents, chooser hard-coding the boss, `forecast_task` dropping the task, `choose_task` not yielding, cost `>` 5, scorer ignoring `side`, hand read for the active side, `class_only` keeping the amount, lethal rows unmarked, `effective_mode` as max, commit appended last.
**Verification**: import exit 0; `gates.sh`, `no_global_rng.sh`, `parse-check.sh` exit 0; `commands.test` Overall Summary 1776 test cases, 0 errors, 0 failures, 0 orphans, exit 0; `commands.smoke` exit 0, no `SCRIPT ERROR`.
**Run result**: N/A: nothing reaches the screen until the match driver runs a boss turn.
**Review findings closed here**: N5 (`Scorer.CONTEXT_SIDE`, `_measure` reads the scored side's hand, `forecast(sandbox, planner, side)`); `chooser.gd:70` (`Chooser.choose` takes a required `own`); `forecast_task` and `choose_task` exist and take the running task, required. `CandidateSet` keeps `active_side()`: it runs only at `_is_own_main`, where the two agree, and `legal_commands()` serves the side to move anyway.
**Deviations** (advisory):
- **How the clone reaches the boss's Main.** No public API sets mana alone, and `legal_commands()` / `submit` serve only the side to move, so the forecast submits the player's `end_turn` on a clone carrying the fork and lets the engine's End and Start steps do it: F4 mana with `crystal_bonus`, C13 thaw, reset attacks. Then `discard` drops every card that came from the deck, because C8.1 says "its current hand" and C1.3 hides deck order (at every point in the plan since review fix D1, below). No `rules_engine.gd` change. The player's End-step and boss Start-step triggers therefore run on the clone, drawing from the fork.
- `turn_plan.gd` is outside the planned Files. `ai_intent_committed` is no rule 12a diagnostic, so unflagged it would enter the live checksum and read as a replay divergence: `TurnPlan.checksum` now skips the intent events by type. BAI-015 needs no change for this.
- `forecast_task`, `choose_task` and `note_forecast` came forward from story 014 at the orchestrator's request; story 014 is updated. `choose_task` awaits one `checkpoint()`, so its required task is used.
- `_read_public_log` now names the player as the opponent: reading `active_side()` at `PlayerTurn.Main` would have looked for the boss's cards.
- `last_forecast` is spent by the commit, so a later turn whose forecast was discarded is not compared with an old one.

**Readings** (the GDD does not settle these; no number added beyond C8.3's 5, in `Scorer.NORMALISERS`):
- "Highest-scoring action class" is the single best-scoring action of the plan, the earlier on a tie, not a sum per class.
- `cost >= 5` reads the printed cost.
- A spell in no class (buff, draw, burn to the face) is `develop_board`: the closed set has no other home, and Frozen forbids a fabricated `attack_face`.
- `amount` uses each attacker's attack when the plan began, so a buff from hand reveals nothing.

**Open, for the owner**:
- **A4 against C8.1.** The forecast plans the current hand and the real turn has the drawn card, so a drawn card the boss plays gives `kept = false` on an unchanged board (`test_a_card_drawn_on_the_boss_turn_can_change_the_plan_with_the_board_unchanged`). A4 says `kept = true` there. BAI-012's A4 fixture needs an unplayable deck card until this is decided, and the player sees "plan changed" for a draw.
- **`kept` with no forecast is false**, per the story's formula. A forecast discarded as stale or still running at End Turn therefore gives "plan changed" with no banner shown. Story 014 / match-ui should decide whether that label shows.
- The boss-ai Edge Case "thaw at the player's End step" still needs correcting (QA plan gap); tests follow match-rules C13.

**Test Evidence**: `tests/unit/boss_ai/boss_ai_forecast_test.gd`
**Reviewed by**: independent review at M2, `s5-review-w2-bossai-mr019.md`: CHANGES REQUIRED, D1 fixed below; re-review is the orchestrator's.

**Review fix D1** (2026-11-05, start 02:43 UTC; on trunk `f4aff0e`): the forecast dropped new cards once, before the plan, so a mid-plan draw (shipped Ember Bolt) put the real deck card in front of the planner: the same public board gave `develop_board` or `attack_face 3` by an undrawn card. Worse than the review traced: `LethalSearch` nodes drew too, and a forecast read `lethal` through an undrawn Charge. `_Turn.unseen` now holds the deck's instance ids at the forecast's start, and `LethalSearch.drop_unseen` removes those cards after the Start step, after every accepted action or lethal step (`_settle`), and at every search node. A real plan's `unseen` is empty, so its draws stay. By deck origin rather than "new to the hand", so a bounced or generated card stays. Tests, each seen failing: `test_d1_a_card_drawn_mid_plan_never_shapes_the_forecast` and `test_d1_a_lethal_line_through_an_undrawn_card_is_not_forecast` (two deck orders, one public board, equal `to_dict()`) failed on the unfixed planner; `test_d1_only_cards_from_the_deck_are_dropped`, `test_d1_a_real_plan_keeps_and_plays_the_card_it_draws` and `test_d1_a_lethal_step_that_draws_and_aborts_leaves_no_deck_card_for_scoring` against mutants. 7 mutants killed; `no_drop_after_lethal_step` survived until the last of those tests was added. **Still open, not fixed here**: a one-ply trial keeps its draw for `f_card` and reads only the count, so an effect that reads a drawn card's identity in the same action (`on_draw` filter, `deck_top`, a `deck` Discover) would still see it; no shipped card has one. The **real** plan's `LethalSearch` and trials also draw from the true deck before the card is drawn, which C1.3 may forbid: that is one-search behaviour, left unchanged and raised for the owner. (2026-11-05: the search half is fixed, `boss_ai_real_plan_hidden_deck_test.gd`, C1.3 and BAI-012; the trial half stays the owner's, since an `on_draw` hook fires before a card can be dropped.) Verification: import, gates, no_global_rng, parse-check exit 0; commands.test Overall Summary 2045 test cases, 0 errors, 0 failures, 0 orphans, exit 0; commands.smoke exit 0, no SCRIPT ERROR (end 03:01 UTC).
