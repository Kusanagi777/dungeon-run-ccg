# Story 016: Choice phase and Discover continuation

> **Epic**: Match Rules
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

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

- [ ] AC-36 **GIVEN** a Discover raised during the boss's turn (a scripted boss Battlecry calling `discover(BOSS, options)`), **WHEN** the player sends `play_card`, **THEN** `CHOICE_PENDING`; **WHEN** Boss AI sends `choose(1)`, **THEN** resolution resumes (`resolver.resume` called with the stored continuation and index 1), the chosen option is in the boss hand (via `add_card_to_hand`), `choice_made` is emitted, the C10 loop runs to stable, and `phase` returns to the originating `BossTurn.Main`.
- [ ] States `Choice` **GIVEN** `pending_choice` for side S, **WHEN** `choose` arrives from the other side, **THEN** `NOT_YOUR_TURN`; with `option_index` outside `0..options.size()−1`, **THEN** `INVALID_CHOICE`; `concede` from the player is accepted in `Choice` (→ `Ended`, reason `concede`); `legal_commands()` in `Choice` lists exactly one `choose` per option for side S (plus the player's `concede`); `phase_changed(Choice)` and `choice_requested{side, kind, options, source_id, effect_id}` were emitted when the request was raised (distinct from Card Effects' `discover_offered`, DD-X04).
- [ ] C2 / ADR-0007 **GIVEN** a `ChoiceRequest` raised mid-resolution with a trigger queue that is not empty, **WHEN** `Choice` is entered, **THEN** the remaining queue and the step count are preserved in plain data on `MatchState` (no Callable anywhere in `state.effects` or the queue — `assert_json_representable` on `state_snapshot` of the whole `MatchState` passes), and after `choose` the preserved queue resumes in order with the same `cause_seq` chain; `pending_choice()` returns a value copy of the request.

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

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/gameplay/match/rules_engine.gd` (`discover` suspend, `Choice` phase guards, `choose` handler, loop resume)
- `src/gameplay/match/match_state.gd` (`pending_choice`, `suspended_queue`, `suspended_steps`)
- `tests/helpers/test_effect_resolver.gd` (scripted Discover Battlecry; `resume` adds the option to hand)
- `tests/unit/match_rules/match_rules_choice_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/match_rules/match_rules_choice_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later). `qa.level: standard` — BLOCKING.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/match-rules/story-010-play-card-and-hero-power.md`
- Unlocks: `production/epics/match-rules/story-017-clone-and-replay.md`
