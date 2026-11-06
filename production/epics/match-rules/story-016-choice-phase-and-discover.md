# Story 016: Choice phase and Discover continuation

> **Epic**: Match Rules
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-04

## Context

**GDD**: `design/gdd/match-rules.md` (C2 `choose` row, `CHOICE_PENDING`, `INVALID_CHOICE`; States `Choice` and its transition rows; C12 Discover row; Interactions `discover(side, options) → ChoiceRequest`; Edge Cases "If a Discover is raised during the boss's turn"; DD-X04 — `choice_requested` and `discover_offered` are distinct events)
**Requirement**: `TR-match-rules-002` (the `choose` command and its codes), `TR-match-rules-006` (a resolution paused mid-step and resumed as part of the C10 loop)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Effect Resolver / Validator Boundary (Decision 1 — the resolver stores the continuation in `EffectRuntime.pending_choice`; the engine owns the `Choice` phase and `pending_choice.side`; `resume(choice, option_index)` on `choose`); also ADR-0008 (Boss `Choice` with no task live → `boss_ai.choose(sandbox, pending)` then `engine.submit(choose{issuer: boss, option_index})`)
**ADR Decision Summary**: Discover / Choose One pauses a resolution: the resolver keeps its continuation as plain data in `MatchState.effects.pending_choice`, the engine enters `Choice` with `pending_choice.side`, accepts only `choose` from that side (and `concede`), and on `choose` calls `resolver.resume(choice, option_index)` and runs the loop to stable.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: HIGH by version; APIs used predate 4.3. The continuation must be plain data (no Callable — `EffectRuntime` never holds one) so `clone()` can carry it (story 017) and the Boss AI can choose on a sandbox.

`Choice` is the only phase a `submit` can leave a match in between calls, and it is reached from inside a resolution — a Battlecry or spell that Discovers. The engine does not know what is being chosen; it knows which side must answer, how many options there are, and that nothing else may happen until it does.

**Control Manifest Rules (this layer)**:
- Required: `EffectRuntime {once_marks, counters, per_turn, pending_choice}` is plain data in `MatchState.effects`; `clone()` copies it by value (ADR-0007); Boss `Choice` with no task live → task `boss_ai.choose(sandbox, pending) -> int`, then `engine.submit(choose{issuer: boss, option_index})` on the main thread (ADR-0008)
- Forbidden: `EffectRuntime` never holds a Callable, a Node or an object reference (ADR-0007); never invoke a Boss AI entry point inline from `submit` (ADR-0008)
- Guardrail: `submit()` ≤ 5 ms worst case — the `choose` call resumes and finishes the paused resolution inside the budget (ADR-0007)

---

## Acceptance Criteria

*From GDD `design/gdd/match-rules.md`, scoped to this story:*

- [x] AC-36 **GIVEN** a Discover raised during the boss's turn (a scripted boss Battlecry calling `discover(BOSS, options)`), **WHEN** the player sends `play_card`, **THEN** `CHOICE_PENDING`; **WHEN** Boss AI sends `choose(1)`, **THEN** resolution resumes (`resolver.resume` called with the stored continuation and index 1), the chosen option is in the boss hand (via `add_card_to_hand`), `choice_made` is emitted, the C10 loop runs to stable, and `phase` returns to the originating `BossTurn.Main`.
- [x] States `Choice` **GIVEN** `pending_choice` for side S, **WHEN** `choose` arrives from the other side, **THEN** `NOT_YOUR_TURN`; with `option_index` outside `0..options.size()−1`, **THEN** `INVALID_CHOICE`; `concede` from the player is accepted in `Choice` (→ `Ended`, reason `concede`); `legal_commands()` in `Choice` lists exactly one `choose` per option for side S (plus the player's `concede`); `phase_changed(Choice)` and `choice_requested{side, kind, options, source_id, effect_id}` were emitted when the request was raised (distinct from Card Effects' `discover_offered`, DD-X04).
- [x] C2 / ADR-0007 **GIVEN** a `ChoiceRequest` raised mid-resolution with a trigger queue that is not empty, **WHEN** `Choice` is entered, **THEN** the remaining queue and the step count are preserved in plain data on `MatchState` (no Callable anywhere in `state.effects` or the queue — `assert_json_representable` on `state_snapshot` of the whole `MatchState` passes), and after `choose` the preserved queue resumes in order with the same `cause_seq` chain; `pending_choice()` returns a value copy of the request.
- [x] Quick-design 2026-11-04 (sprint-4 plan gap) **GIVEN** a player spell whose effect list is `[discover(PLAYER, options), deal_damage(BOSS_HERO, 2)]`, **WHEN** the spell is cast and `Choice` is entered, **THEN** no `damage_dealt` event is emitted, boss hero health is unchanged, the spell stays in the `resolving` zone and no `after_cast` trigger has fired; **WHEN** the player sends `choose(0)`, **THEN** the chosen card is added to the player's hand first, then `damage_dealt{dealt: 2}` is emitted, then `after_cast` triggers fire, then the spell leaves `resolving` (`card_to_graveyard`), in that `seq` order (GDD C6), each exactly once. *(Order corrected 2026-11-04 to match C6; the first wording put the graveyard move before `after_cast`.)*

---

## Implementation Notes

*Derived from ADR-0007 Decision 1 / Implementation Guidelines, ADR-0008 Decision and GDD States / C2:*

- `discover(side, options) -> ChoiceRequest` (primitive, story 006 created the record): builds `{side, kind: discover | choose_one, options, source_id, effect_id}` (options are `def_id`s drawn by the resolver from `rng_match`, `DISCOVER_COUNT` = 3 from Card Effects' config — the engine does not draw them), stores it as `state.pending_choice`, sets `phase = Choice` (remembering the originating phase), emits `choice_requested`, and signals the loop to **suspend**: `run_action` stops popping `Q`, keeps `Q` and the step counter on `MatchState` (plain Arrays / ints), clears `_resolving`, and `submit` returns `accepted: true` for the command that raised it. The resolver stores its own continuation in `state.effects.pending_choice` (plain data).
- `choose{option_index}`: phase = Choice; issuer = `pending_choice.side` else `NOT_YOUR_TURN`; `0 <= option_index < options.size()` else `INVALID_CHOICE`. Accept: emit `choice_made{side, option_index}`, clear `state.pending_choice`, restore the originating phase, `resolver.resume(choice, option_index)` as the next step (the resolver calls primitives — e.g. `add_card_to_hand`), then continue the suspended loop (`Q`, step count) to stable, `win_loss_check`, return.
- Every other command in `Choice` → `CHOICE_PENDING` (except `concede` from the player → `Ended`). `legal_commands()` in `Choice` = `choose` × options for `pending_choice.side` (+ `concede`).
- Boss-side Discover: the engine does nothing special — the driver (ADR-0008) sees `pending_choice().side == BOSS` and submits the AI's `choose` later; tests submit it directly.
- `clone()` (story 017) must carry `pending_choice`, the suspended `Q` and `state.effects.pending_choice` by value; design the storage now as fields on `MatchState` (`pending_choice`, `suspended_queue`, `suspended_steps`) so the deep copy is a `duplicate(true)`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 017: copying the continuation in `clone()`
- Card Effects epic: drawing the options from `rng_match`, `discover_offered` / `discover_picked`, `resume` itself
- boss-ai-match-driver epic: `boss_ai.choose(sandbox, pending)` and when the driver submits it

---

## Files

- `src/gameplay/match/rules_engine.gd` (command handlers as plain-data stages; `discover` pauses into `Choice`; `choose` handler and validation (`INVALID_CHOICE`); `legal_commands` in `Choice`; `_run_step` / `_drain` stop at a pause; `_park` / `_do_choose` / `_abandon_choice` / `_abandon_stages`)
- `src/gameplay/match/match_state.gd` (`suspended_queue`, `suspended_steps`, `suspended_action`)
- `src/gameplay/match/match_records.gd` (`choose(issuer, option_index)` command builder)
- `tests/helpers/test_effect_resolver.gd` (additive: `resume_script`, run by `resume` after recording)
- `tests/unit/match_rules/match_rules_choice_test.gd` (new, 11 tests)
- `tests/unit/match_rules/match_rules_data_model_test.gd` (MatchState field list gains the three `suspended_*` fields)
- `tests/unit/match_rules/match_rules_primitives_test.gd` (the `discover` test expects `phase_changed` before `choice_requested`)

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/match_rules/match_rules_choice_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later). `qa.level: standard` — BLOCKING.

**Status**: [x] Created — 11 tests, passing

---

## Dependencies

- Depends on: `production/epics/match-rules/story-010-play-card-and-hero-power.md`
- Unlocks: `production/epics/match-rules/story-017-clone-and-replay.md`

---

## Completion Notes
**Completed**: 2026-11-04 (started 03:02:14 UTC, ended 03:14 UTC)
**Readiness** (`/story-readiness` by hand, 2026-11-04): READY — ADR-0007 and ADR-0008 Accepted; TR-match-rules-002 / 006 active; Manifest Version 2026-11-03 current; dependency 010 Complete; 4 testable criteria, including the quick-design 2026-11-04 after-cast criterion; no open markers. QL-STORY-READY skipped — Lean mode. No sprint-4 QA plan was on the branch, so the work followed the story ACs (Sprint-4 rules).
**Criteria**: 4/4 passing (`tests/unit/match_rules/match_rules_choice_test.gd`, 11 tests):
- AC-36: `test_a_boss_battlecry_discover_rejects_the_player_until_the_boss_chooses`, plus `test_a_discover_from_a_start_step_trigger_resumes_the_rest_of_the_start_step`.
- States `Choice`: `test_choice_guards_not_your_turn_invalid_choice_and_choice_pending`, `test_legal_commands_in_choice_are_one_choose_per_option_and_the_concede`, `test_raising_the_request_emits_phase_changed_and_choice_requested`, `test_concede_in_choice_ends_the_match_and_the_spell_leaves_resolving`.
- C2 / ADR-0007: `test_a_choice_raised_with_a_queue_parks_it_as_plain_data` (including `assert_json_representable` over every plain-data `MatchState` field, and the `pending_choice()` value copy), `test_after_choose_the_parked_queue_resumes_in_order_with_its_cause_seq`, `test_the_step_count_carries_across_the_pause_to_the_step_cap`.
- Quick-design 2026-11-04: `test_a_spell_paused_by_discover_runs_no_later_step_until_choose`, `test_choose_resumes_the_paused_spell_in_seq_order_and_once`.
Watched fail: 10 of 11 failed against the story-011 engine. The concede test passed there vacuously, because the old engine had already finished the spell. Mutants, one per run: `_run_stages` ignoring the pause → 3 tests fail; `choose` restarting the step count → 1 fails (the step cap); concede not abandoning the choice → 1 fails (the concede test).
**Decisions recorded** (the continuation shape card-effects 010 builds on; also in the `RulesEngine.discover` doc comment):
- **Every command handler is a list of plain-data stages** `{stage, side, …}` over one frame `{side, instance_id, def_id, target, cause, id}`, run by `_run_stages`. This covers play_card (minion, spell, weapon), the hero power, the mulligan, the C4 Start step and the C4 End step, with one stage per hook entry. A Discover can therefore pause any of them. A turn-start or turn-end Discover resumes the rest of that step (draw, Main) rather than soft-locking the match.
- **`discover()`** records `suspended_action {origin_phase, cause_seq}`, enters `Choice` (`phase_changed`, then `choice_requested`) and returns a copy of the request. A second request while one is pending is logged and refused (card-effects C8).
- **At the pause:** the resolver returns from its pass and keeps its later ops in `effects.pending_choice`. The engine runs no death check after that unfinished pass, runs no further step or stage, and skips C14. It parks Q (`suspended_queue`), the step count (`suspended_steps`) and the stages and frame (`suspended_action.stages` / `.frame`) on `MatchState`; `submit` returns accepted.
- **`choose`:** `choice_made {side, option_index}` (cause 0), then the origin phase is restored (`phase_changed`), along with Q and the step count. Next comes `resolver.resume(choice, index)` under the paused step's `cause_seq`, so the pick and the effect's later ops keep the spell / trigger as their cause. Then that step's C10 loop, the parked stages once each, and C14. A `resume` that raises another request pauses again the same way.
- **`concede` in `Choice`** drops the request and the parked action. A paused spell still leaves `resolving`, silently, like the fault path.
**Deviations** (advisory):
- **AC wording vs GDD C6 order:** the quick-design AC lists "the spell leaves `resolving` and `after_cast` triggers fire, in that `seq` order". GDD C6 (spells step 3) and story 010 run the `after_cast` observers first, then `card_to_graveyard`. The C6 order is kept. The test asserts that both come after `damage_dealt`, which comes after `card_added_to_hand`, and that `after_cast` precedes `card_to_graveyard`. *(Corrected 2026-11-04, code review S1: that last comparison was missing until `f429bcb`; mutant M1 had survived.)* If the AC meant graveyard-first, that is a C6 change for the match-rules GDD owner.
- `legal_commands()` in `Choice` lists the player's `concede`, as the AC says, although Main lists none (story 010).
- Edited outside the planned file list: `match_records.gd` (new `choose` builder), `match_rules_data_model_test.gd` (MatchState field list) and `match_rules_primitives_test.gd` (a raise now emits `phase_changed` before `choice_requested`). The shared helper edit is additive (`TestEffectResolver.resume_script`; `resume` unchanged when it is unset).
- Not staged: `start()` (C3 setup: `on_match_start` hooks) and `run_action` fixtures (the paused step's own drain and C14 only). Story 012's attack handler (lane 1, in flight) runs its steps directly. A Discover from an `on_attack` / `on_damage` trigger during an attack pauses correctly, but the attack's later direct steps are skipped rather than resumed until those steps are also built as stages. Hand-off note for MR-013 / the merge.
- GDD C1's MatchState list should gain `suspended_queue` / `suspended_steps` / `suspended_action` (owner: match-rules GDD). `clone()` (story 017) copies them with `duplicate(true)`.
**Test Evidence**: `tests/unit/match_rules/match_rules_choice_test.gd` (11 tests). Import exit 0. Full suite (`commands.test`): 1102 test cases, 0 failures, exit 0, 85 SCRIPT ERROR lines, all existing intentional negatives (none from `src/gameplay/match`). Smoke exit 0, no SCRIPT ERROR.
**Run result**: N/A — headless rules code; no Discover panel or screen exists yet (Match UI is a later epic).
**Reviewed by**: independent `/code-review` 2026-11-04 (by hand, `code-review-s4-mr011-016`): **NOT ASSESSED** (engine-specialist and qa-tester passes could not be spawned; no match-rules perf data), substantively APPROVED WITH SUGGESTIONS. Fixes (sprint 4, lane 1 review-fix slot), each in `match_rules_choice_test.gd` (now 16 tests): S1 `after_cast` before `card_to_graveyard` asserted, mutant M1 now fails here and in the story-010 spell test — `f429bcb`; S4 an event cap on `choice_made` still moves the paused spell out of `resolving` — `3305185`; S3 a Discover in Setup (`on_match_start`) is refused with a logged reason — `f6d3d5f`; S2 a Discover inside an in-primitive hook entry (`on_draw`, `on_hero_damaged`, `on_minion_summoned`) is refused with a logged reason, step-boundary hooks still pause — `99dfd3b`. N2 is resolved by card-effects 010 (`unbind` clears `effects.pending_choice`). Open nits: N1 (re-entry guard across a resumed hook entry), N3 (`choice` guard code for a non-side issuer), N5 (`_run_stage` length), N7 (End-step and second-Discover-in-resume tests). QL-TEST-COVERAGE skipped — Lean mode
