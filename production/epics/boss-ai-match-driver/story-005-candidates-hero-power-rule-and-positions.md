# Story 005: Candidate set — op_value pre-filter, hero-power rule and position sensitivity

> **Epic**: Boss AI + Match Driver
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-04

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

## Readiness (`/story-readiness`, by hand, 2026-11-04)

**Verdict: READY.** Tier: workflow standard. ADR-0001 and ADR-0006 Accepted; TR-boss-ai-001 active; Manifest Version 2026-11-03 equals the manifest's; story 004 Complete (`243bb14`, same lane); no open markers; 3 criteria. QL-STORY-READY skipped — Lean mode.

- No Discover in the three fixtures (hero power `damage enemy_hero`; an `adjacent` Battlecry `buff`; `damage` spells and vanilla minions), so the BAI-010 gap does not reach this story.
- Applied from the match-rules 015/017 review (2026-11-04): candidates are only ever taken from `legal_commands()` (never synthesised), and every sandbox clone is ended.

---

## Acceptance Criteria

*From GDD `design/gdd/boss-ai.md` A12, A17 and C4, scoped to this story:*

- [x] **A12** GIVEN `rules.hero_power = spare_mana`, 3 mana and a 3-cost card in hand, WHEN scored, THEN the card is played and the hero power is not used; GIVEN 2 mana and no 2-cost card, THEN the hero power is used (`f_hp` +1 / −1 / 0 per F9: `always`, `spare_mana`, `never`, `value`).
- [x] **A17** GIVEN a minion whose own effect uses the `adjacent` selector (derived `position_sensitive`, C6), WHEN `legal_commands` offers 4 positions, THEN 4 candidates are simulated; GIVEN a plain minion, THEN exactly 1 position (rightmost, `position = board.size`) is simulated.
- [x] GIVEN `legal_commands()` yields more candidates than `budgets.max_evals_per_action`, WHEN `score_all` runs, THEN exactly `max_evals_per_action` candidates are simulated, chosen by `op_value × targets yielded` rank (C6), `end_turn` is always among them, and no candidate outside the simulated set is ever chosen (C4); the `ai_decision` alternatives list holds at most 3 entries.

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

- `src/ai/candidates.gd` (new)
- `src/ai/scorer.gd` (modified: `f_hp` from the F9 rule, `card_playable` context, `alternatives()`, public `selector_name` / `other_side`)
- `tests/unit/boss_ai/boss_ai_candidates_test.gd` (new, 11 tests)
- `tests/helpers/boss_ai_board.gd` (modified, story 004's helper: `hero_power` cards, `boss.hero_power`, fixture `budgets`)
- `tests/fixtures/boss_ai/hero_power_spare_mana.json`, `tests/fixtures/boss_ai/adjacent_minion.json`, `tests/fixtures/boss_ai/wide_hand_prefilter.json` (new)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/boss_ai/boss_ai_candidates_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] Created — 11 tests, passing (full suite 1343 / 0 failures, 2026-11-04)

---

## Dependencies

- Depends on: `production/epics/boss-ai-match-driver/story-004-scorer-features-and-board-value.md`
- Unlocks: `production/epics/boss-ai-match-driver/story-007-lethal-search.md`, `production/epics/boss-ai-match-driver/story-008-plan-turn-loop-and-turn-plan.md`

---

## Completion Notes
**Completed**: 2026-11-04 (start 05:15 UTC, work and verification done by about 05:25 UTC, committed 14:09 UTC after a session pause; lane 4 wave 3, branch `lane/s4-l4-w3`)
**Criteria**: 3/3 passing — A12 `test_spare_mana_plays_the_three_cost_card_instead_of_the_hero_power`, `test_spare_mana_uses_the_hero_power_when_no_card_is_playable`, `test_hero_power_feature_follows_each_f9_rule`, `test_scored_hero_power_carries_the_profile_rule_and_other_actions_carry_zero`; A17 `test_position_sensitive_minion_keeps_every_offered_position` (4 simulated vs 1 at `board.size`, counted by checkpoints); pre-filter `test_prefilter_keeps_exactly_max_evals_ranked_by_op_value_with_end_turn` (exactly `max_evals_per_action` from the profile, `end_turn` kept, every dropped command ranked ≤ every kept one, the best is a kept one, `Scorer.alternatives` = 3), `test_prefilter_keeps_end_turn_even_when_it_ranks_last`, boundary `test_prefilter_is_off_when_candidates_equal_max_evals`; plus `derive_annotations`, the per-instance memo, and `op_value` × targets / structural ops / unvalued 1.0. Each was seen failing against a mutated `candidates.gd` (positions kept, `spare_mana` → 0, forced `end_turn` dropped, rank reversed, memo off, targets multiplier off), then restored.
**Verification**: import exit 0; `commands.test` 1343 test cases, 0 errors, 0 failures, 0 orphans, exit 0, 85 `SCRIPT ERROR` lines (the known intentional negatives, unchanged); `commands.smoke` exit 0, no `SCRIPT ERROR`; `tools/lint/gates.sh` PASS.
**Run result**: N/A — headless rules-tier candidate filtering with no scene; nothing is on screen until the match driver (story 013) runs a boss turn.
**Deviations** (advisory):
- Signatures: `collect(sandbox, profile, budgets)` as planned; `op_value(command, sandbox)` is an instance method (it needs the board for "× targets yielded" and this instance's `db` / `op_values`), not `op_value(command, db, op_values)`; `def_value(def, sandbox, own)` is the per-definition half.
- The cap is applied after position filtering (only the rightmost position of a plain minion is a candidate at all, C6), and keeps `max_evals_per_action − 1` ranked commands plus `end_turn`.
- `op_value` of non-effect actions, which C6 leaves open: a minion body is C7's `buff × (attack + health) / 4`, a weapon play adds the `equip` row, an attack is one `damage` row on one target, `end_turn` 0. Selector target counts follow C6; `adjacent` counts up to 2 and `left_/right_neighbour` up to 1 of the owner's minions (Card Effects F6's bounds).
- `spare_mana`'s "no card is playable with the remaining mana" is read as "no `play_card` in the base sandbox's `legal_commands()`" (`Scorer.card_playable`, once per `score_all`).
- Same `state()`-on-clones deviation as story 004 (hand definitions, board sizes); candidates come only from `legal_commands()` (review note 6).
**Test Evidence**: `tests/unit/boss_ai/boss_ai_candidates_test.gd`
**Reviewed by**: self, no independent review (`/code-review` of BAI-004 at M3 covers `scorer.gd`; this story's own review is not scheduled in sprint-004.md) · `/code-review 2026-11-04 (independent, scratchpad reports/code-review-s4-bai004-006.md): NOT ASSESSED` (engine-specialist / qa-tester passes not spawnable; otherwise APPROVED WITH SUGGESTIONS) — fixed on `lane/s4-l4-w3-fix` (sprint 4, lane 4 review-fix slot): **S4** an attack is now `CandidateSet.attack_value` — one `damage` row, plus the `destroy` row when it kills its minion target, and `LETHAL_RANK` (∞) for a lethal face attack — so the pre-filter never drops a lethal attack; tested on `prefilter_lethal_attack.json`, the review's probe board (`c6f8648`); **S2** (candidates half) `adjacent` target count and weapon `equip` row pinned (`3d80389`). This supersedes the "attack is one `damage` row" deviation above. **Open (design)**: record the attack valuation in GDD C6 or Open Questions; a strong non-lethal face attack still ranks as one `damage` row *(resolved 2026-11-04, DD-X22: boss-ai C6 now records the attack valuation as built; a non-lethal face attack stays one `damage` row in the pre-filter, valued after simulation by F1 `f_face`, with the F1 vulnerability exception; no pre-filter code change; the exception is boss-ai story 009 A31)*; the rank tie order among equal values (mutant C3) is unpinned.
