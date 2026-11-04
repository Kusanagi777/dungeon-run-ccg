# Story 006: Tie-break set, fork labels and ai_<floor> draw accounting

> **Epic**: Boss AI + Match Driver
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-04

## Context

**GDD**: `design/gdd/boss-ai.md` (C9 tie-breaks and draws, F8, C4 sandbox forks, C8.1 forecast fork)
**Requirement**: `TR-boss-ai-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Seeded RNG Service and Event Log (named streams, `fork(label)` costs one parent draw per new label — rule 5; replay by draw count); ADR-0006 (the worker is handed the `ai_<floor>` stream, which nothing else reads; `TurnPlan.ai_draws`)
**ADR Decision Summary**: The AI's only live `ai_<floor>` draws are one `randi_range` per tie set of size > 1 plus one parent draw per new fork label (`sim_<turn>`, `forecast_<turn>`); sandboxes draw from their forks. Draw count per turn is therefore deterministic given the state, which `restore()` relies on. The `match_<floor>` stream is never touched by the planner.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH / NOT SOURCEABLE
**Engine Notes**: ADR-0003 — one `RandomNumberGenerator` per stream, same seed ⇒ same sequence observed on 4.7.2 (Probe D); `randi_range` over `randi32()` per F4. Tests use `TestRngStream` (`tests/helpers/test_rng_stream.gd`) with exact `draws` counting and `fork`.

**Control Manifest Rules (this layer)**:
- Required: Tie-breaks from `ai_<floor>` and its forks; `ai_decision` diagnostics on the log (ADR-0003). The worker receives the clone, the `ai_<floor>` stream and the frozen `CardDatabase`.
- Forbidden: Nothing in `src/ai/**` touches a `RandomNumberGenerator` directly or the `match_<floor>` stream; never `log.append` on a live log from the planner.
- Guardrail: none beyond the draw accounting itself.

---

## Readiness (`/story-readiness`, by hand, 2026-11-04)

**First check: NEEDS WORK** — A2 not testable as written ("may differ" cannot fail) and A3/A5 not reachable without story 008 (QA plan § BAI-006). **Resolved from the docs** by the quick-design amendment below (A2 rewritten; A3/A5 moved to story 008; per-action accounting kept). **Re-check: READY.** Tier: workflow standard. ADR-0003 and ADR-0006 Accepted; TR-boss-ai-001 active; Manifest Version 2026-11-03 current; story 004 Complete (`243bb14`); `RngStream.fork` / `draws` done (rng-event-log); no open markers; 2 criteria after the amendment (≥ 2 at `balanced`). QL-STORY-READY skipped — Lean mode. The fixture raises no Discover.

---

## Acceptance Criteria

*From GDD `design/gdd/boss-ai.md` A2, A3, A5, scoped to this story — **amended 2026-11-04 per QA plan** (see the Quick-design amendment below):*

- [x] **A2 (amended 2026-11-04 per QA plan)** GIVEN a fixed size-2 tie set (`tests/fixtures/boss_ai/tie_set_board.json`) and two `ai_<floor>` streams whose seeds are chosen in the fixture so that their first `randi_range(0, 1)` draws differ, WHEN the tie-break picks on each, THEN the chosen commands differ, each is `ties[draw]` over the canonical order, and each stream's `draws` rose by exactly 1; AND GIVEN the same fixture with a tie set of size 1, THEN both streams choose the identical command and neither stream's `draws` moves.
- [x] **Per-action draw accounting (amended 2026-11-04 per QA plan, option (a); replaces A3/A5 in this story)** GIVEN a fixture board, WHEN one action is decided (`Scorer.score_all` on a clone, then the tie-break), THEN the `ai_<floor>` stream's `draws` rises by exactly (1 if the tie set has more than one entry, else 0), and the live `match_<floor>` stream's `draws` and the live log are unchanged; AND GIVEN a fork label `sim_<turn>` / `forecast_<turn>` built by `TieBreak.sim_label(turn)` / `forecast_label(turn)`, WHEN it is forked twice in one turn, THEN the parent `ai_<floor>` stream takes exactly one draw (ADR-0003 rule 5).
- **A3 and A5 — moved to story 008 (amended 2026-11-04 per QA plan, option (b) for the per-turn halves).** Both need `play_turn` / `plan_turn` and `TurnPlan.ai_draws`, which story 008 builds and which this story unlocks; they cannot be met here. Story 008 must carry them as written in the GDD: A3 (replayed match: per-turn `ai_<floor>` draw count equals the original, equals tie-set draws + new fork labels that turn, and equals `TurnPlan.ai_draws`) and A5 (`play_turn` leaves the live `match_<floor>` `draws` unchanged; `ai_<floor>` rises by exactly tie-set draws + new fork labels; `sim_<turn>` / `forecast_<turn>` created at most once per turn each). Story 008's file is not edited by this lane: the orchestrator adds the two criteria there.

### Quick-design amendment (Tweak, 2026-11-04)

**System**: Boss AI · **GDD Reference**: `design/gdd/boss-ai.md` Acceptance Criteria A2, A3, A5; C9; F8 · **Source**: `production/qa/qa-plan-sprint-004-2026-11-04.md` § BAI-006 and § "Acceptance criteria found untestable as written".

- **Change.** A2's "the chosen commands **may** differ" cannot fail, so it is replaced by a falsifiable statement on a fixed size-2 tie set with two seeds chosen to give different draws (the QA plan's rewrite, verbatim in substance). A3 and A5 need `play_turn` and `TurnPlan.ai_draws` from story 008, so the per-turn criteria move there; this story keeps the per-action slice it can prove (QA plan option (a)) and the fork-label-once rule.
- **Design delta.** None to the rules: F8 and C9 are unchanged (one `randi_range` per tie set of size > 1, none for size 1; one parent draw per new fork label). Only what this story's tests assert changes.
- **GDD update required?** Advisory: GDD A2's "may differ" wording could adopt the same rewrite; not edited by this lane.
- **Approval.** Owner standing approval for this sprint's lanes (lane-prompt-common), applied on the lead's instruction for lane 4 wave 3.

---

## Implementation Notes

*Derived from ADR-0003 and GDD C9 / F8:*

- Files: `src/ai/tie_break.gd` (`class_name TieBreak extends RefCounted`): `pick(scored: Array, tie_epsilon: float, ai_stream) -> {chosen, ties}`; `ties = sort_canonical({a : score(best) − score(a) ≤ tie_epsilon})`; canonical order is command type, then `hand_index`, `attacker_id`, `target_id`, `position`; `pick = ties[ai_stream.randi_range(0, |ties| − 1)]` only when `|ties| > 1`.
- Fork handling lives in `BossAI` (Story 008): `ai_stream.fork("sim_<turn>")` once per turn, shared by every sandbox that turn; `fork("forecast_<turn>")` once per forecast. Count both in `TurnPlan.ai_draws` (ADR-0006 `TurnPlan` field).
- `tie_epsilon` from `rules` (default 0.05) — data, never a literal.
- The test drives the planner with `TestRngStream.seeded` and asserts `draws` exactly; the `match_<floor>` double asserts `draws_outside([...])` is empty for the planner.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 008: `plan_turn`, which creates the forks and fills `TurnPlan.ai_draws`; A1 (10-turn byte-identical sequences).
- Story 017: the cross-implementation determinism run.

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/ai/tie_break.gd` (new)
- `tests/unit/boss_ai/boss_ai_tie_break_test.gd` (new, 7 tests)
- `tests/fixtures/boss_ai/tie_set_board.json` (new)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/boss_ai/boss_ai_tie_break_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] Created — 7 tests, passing (full suite 1350 / 0 failures, 2026-11-04)

---

## Dependencies

- Depends on: `production/epics/boss-ai-match-driver/story-004-scorer-features-and-board-value.md`; `rng-event-log` epic's `RngStream.fork` / draw counters (cross-epic)
- Unlocks: `production/epics/boss-ai-match-driver/story-008-plan-turn-loop-and-turn-plan.md`

---

## Completion Notes
**Completed**: 2026-11-04 (start 14:09 UTC, end 14:15 UTC; lane 4 wave 3 stretch, branch `lane/s4-l4-w3`)
**Criteria**: 2/2 passing (as amended 2026-11-04 per QA plan) — A2 `test_size_two_tie_set_picks_differ_across_two_seeds_and_each_draws_once` (with the seed precondition asserted) and `test_size_one_tie_set_is_identical_across_seeds_and_draws_nothing`; per-action accounting `test_one_action_moves_the_ai_stream_by_its_tie_draws_and_never_the_match_stream` and `test_a_turn_fork_label_takes_one_parent_draw_however_often_it_is_forked`; F8 extras: the ε boundary (exactly ε in, 2ε out), canonical order, empty list. Each was seen failing against a mutated `tie_break.gd` (size-1 draw, always-first pick, strict ε, swapped `target_id` / `position`), then restored. **A3 and A5 moved to story 008** (they need `play_turn` / `TurnPlan.ai_draws`); story 008's file still has to gain them — not edited by this lane. *(Done 2026-11-04 in the review-fix slot, `ae3b161`.)*
**Verification**: import exit 0; `commands.test` 1350 test cases, 0 errors, 0 failures, 0 orphans, exit 0, 85 `SCRIPT ERROR` lines (known intentional negatives, unchanged); `commands.smoke` exit 0, no `SCRIPT ERROR`; `tools/lint/gates.sh` PASS.
**Run result**: N/A — a pure tie-break over scored commands; nothing reaches the screen until the match driver runs a boss turn (story 013).
**Deviations** (advisory):
- `pick` returns `{chosen, ties, draws}` (`draws` added: 0 or 1, for `TurnPlan.ai_draws` in story 008). `sim_label` / `forecast_label` added as the one place the C4 / C8.1 label format lives; forking itself stays story 008's.
- A `-INF` (overflowed) candidate never joins a tie set unless all are `-INF`; then the canonically first is chosen with no draw (F8 is silent on it).
- The match-stream check compares `draws` before and after rather than `draws_outside([...])`.
**Test Evidence**: `tests/unit/boss_ai/boss_ai_tie_break_test.gd`
**Reviewed by**: self, no independent review (stretch story; no `/code-review` scheduled in sprint-004.md) · `/code-review 2026-11-04 (independent, scratchpad reports/code-review-s4-bai004-006.md): NOT ASSESSED` (engine-specialist / qa-tester passes not spawnable; otherwise APPROVED WITH SUGGESTIONS) — fixed on `lane/s4-l4-w3-fix` (sprint 4, lane 4 review-fix slot): **S5** A3 and A5 added to story 008 as "(moved from story 006, 2026-11-04)", with the C4 sandbox-stream criterion; **N1** `TieBreak.KEY_FIELDS` ends with `option_index` (`ae3b161`). **Open**: N2 (the draw-count check derived from `decision.ties.size()`) not addressed in this slot.
