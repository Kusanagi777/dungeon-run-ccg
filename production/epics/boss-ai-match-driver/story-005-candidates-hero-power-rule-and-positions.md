# Story 005: Candidate set — op_value pre-filter, hero-power rule and position sensitivity

> **Epic**: Boss AI + Match Driver
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/boss-ai.md` (C4, C6, F7 `max_evals_per_action`, F9 `hero_power` values, Edge Cases "effect requires a target but none is legal")
**Requirement**: `TR-boss-ai-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Boss AI Planner Threading (candidates are read from the clone's `legal_commands()` inside the task); ADR-0001 (`src/ai/**` rules tier)
**ADR Decision Summary**: `legal_commands()` on the clone already expands every (card × target × position); the planner never synthesises commands. When the list exceeds `budgets.max_evals_per_action` it is pre-ranked by the cheap `op_value` estimate and only the top N are simulated; `end_turn` is always simulated. Three annotations (`position_sensitive`, `aoe`, `synergy_match`) are derived by Boss AI from the effect spec — Card Effects adds no AI-only fields.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH / NOT SOURCEABLE
**Engine Notes**: Reads card records and effect specs from the frozen `CardDatabase` snapshot (read-only after `load()`); concurrent read-only access from a worker is NOT SOURCEABLE and is stress-tested in Story 017. Memoise the derived annotations per `def_id` once per `BossAI` instance, not globally.

**Control Manifest Rules (this layer)**:
- Required: `legal_commands()` ≤ 2 ms with `targeting_spec` memoised per `def_id` (match-rules); the planner reads it on the clone only.
- Forbidden: Never read `targeting` from a stored field (derive via Card Effects' spec, CR-3). Never add AI-only fields to Card Effects. The worker is never handed a `Node` or the live engine.
- Guardrail: `max_evals_per_action` per band bounds simulated candidates (40 / 120 / 250, F7).

---

## Acceptance Criteria

*From GDD `design/gdd/boss-ai.md` A12, A17 and C4, scoped to this story:*

- [ ] **A12** GIVEN `rules.hero_power = spare_mana`, 3 mana and a 3-cost card in hand, WHEN scored, THEN the card is played and the hero power is not used; GIVEN 2 mana and no 2-cost card, THEN the hero power is used (`f_hp` +1 / −1 / 0 per F9: `always`, `spare_mana`, `never`, `value`).
- [ ] **A17** GIVEN a minion whose own effect uses the `adjacent` selector (derived `position_sensitive`, C6), WHEN `legal_commands` offers 4 positions, THEN 4 candidates are simulated; GIVEN a plain minion, THEN exactly 1 position (rightmost, `position = board.size`) is simulated.
- [ ] GIVEN `legal_commands()` yields more candidates than `budgets.max_evals_per_action`, WHEN `score_all` runs, THEN exactly `max_evals_per_action` candidates are simulated, chosen by `op_value × targets yielded` rank (C6), `end_turn` is always among them, and no candidate outside the simulated set is ever chosen (C4); the `ai_decision` alternatives list holds at most 3 entries.

---

## Implementation Notes

*Derived from ADR-0006 Decision and GDD C4, C6:*

- Files: `src/ai/candidates.gd` (`class_name CandidateSet extends RefCounted`): `collect(sandbox, profile, budgets) -> Array[Command]` (filters positions, applies the pre-filter), `op_value(command, db, op_values) -> float` (sum of inner ops for `conditional` / `repeat` / `choose_one`; `aura` and `modify_value` valued as `buff`; × targets the selector yields now), `derive_annotations(def) -> {position_sensitive, aoe, synergy_tags_hit}` memoised per `def_id`.
- `position_sensitive` = any effect on the card uses `adjacent`, `left_neighbour` or `right_neighbour`; the adjacency-lord case (effect on another minion) is accepted as missed at v1 (Open Questions).
- `aoe` = any `damage`, `destroy`, `freeze`, `silence` or negative `buff`/`set_stats` op whose selector is `all_enemy_minions`, `all_minions`, `all_enemy_characters` or `all_characters` from the caster's side.
- `f_hp`: `always` → +1 whenever legal; `spare_mana` → +1 only when no card is playable with the remaining mana, −1 otherwise; `never` → −1; `value` → 0 (ordinary candidate).
- A Battlecry minion offered with no target is scored as a body (`f_board` only); the planner never synthesises a target (Edge Cases).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 004: the feature arithmetic.
- Story 007: the damage-subset filter for lethal search (reuses `derive_annotations`).
- Story 010: `op_value` use for Discover options (C7).

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/ai/candidates.gd`
- `tests/unit/boss_ai/boss_ai_candidates_test.gd`
- `tests/fixtures/boss_ai/hero_power_spare_mana.json`, `tests/fixtures/boss_ai/adjacent_minion.json`, `tests/fixtures/boss_ai/wide_hand_prefilter.json`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/boss_ai/boss_ai_candidates_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/boss-ai-match-driver/story-004-scorer-features-and-board-value.md`
- Unlocks: `production/epics/boss-ai-match-driver/story-007-lethal-search.md`, `production/epics/boss-ai-match-driver/story-008-plan-turn-loop-and-turn-plan.md`
