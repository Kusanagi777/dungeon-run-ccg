# Story 011: Forecast and telegraphing — Intent, intent keys, kept, effective_mode

> **Epic**: Boss AI + Match Driver
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

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
- Guardrail: Forecast doubles the per-round worker cost off-thread (A22 measures forecast + play_turn together).

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

- `src/ai/intent.gd`
- `src/ai/boss_ai.gd` (`forecast`, `set_telegraph_mode`, `intent_from_plan`)
- `tests/unit/boss_ai/boss_ai_forecast_test.gd`
- `tests/fixtures/boss_ai/attackers_4_3.json`, `tests/fixtures/boss_ai/forecast_then_attacker_killed.json`, `tests/fixtures/boss_ai/frozen_boss_board.json`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/boss_ai/boss_ai_forecast_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/boss-ai-match-driver/story-008-plan-turn-loop-and-turn-plan.md`
- Unlocks: `production/epics/boss-ai-match-driver/story-012-hidden-information-and-purity-gates.md`, `production/epics/boss-ai-match-driver/story-014-match-driver-phase-schedule.md`
