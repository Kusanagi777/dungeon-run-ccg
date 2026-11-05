# Story 012: Hidden-information purity (A4) and the src/ai CI gates (A29, thread symbols)

> **Epic**: Boss AI + Match Driver
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-05
> **Readiness**: READY WITH NOTES (2026-11-05, by hand: stories 008 and 011 merged; ADR-0001, ADR-0003 and ADR-0006 Accepted; manifest 2026-11-04 adds no rule against it. The QA plan's three gaps are settled here: the scratch-log exception is dropped, the gate script gets its own test, and the gate re-runs after BAI-014. A4's fixture follows story 011's open note on C8.1.)

## Context

**GDD**: `design/gdd/boss-ai.md` (C1.2, C1.3, C9 "parameters tunable from data", A4, A29)
**Requirement**: `TR-boss-ai-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Rules / Presentation Split (grep gates in CI enforce the tier split; G2b allows exactly the `checkpoint()` await under `src/ai/**`); ADR-0006 (Validation Criteria: no `WorkerThreadPool` or `Thread` symbol outside `src/ai/*_planner_task.gd`); ADR-0003 (public vs hidden events)
**ADR Decision Summary**: The AI is a pure function of observable state: it never reads `player.hand[*].def_id`, deck order or the player's pending Discover options, and from the log reads only public events. CI grep gates make the tier rules and the no-literal rule visible failures rather than conventions.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (engine validation: `rg` 14.1.0 does not support look-around — exit 2 — so G2b-style gates must be written without look-ahead; ADR-0001 erratum)
**Engine Notes**: Gates run as shell steps in `.github/workflows/tests.yml` (ripgrep 14.1.0 on `ubuntu-latest`); use plain alternations and a second negative pass instead of look-around. A4's decoy must be drawn through the engine so `card_drawn.card_id` is in the log.

**Control Manifest Rules (this layer)**:
- Required: `src/ai/**` is rules tier: `RefCounted`, mutates only through `submit` (ADR-0001).
- Forbidden: Nothing in `src/ai/**` ever calls `signal.emit`, `log.append` on a live log, `get_tree()`, `Engine.get_main_loop()` or any `Node` method. No hardcoded weights, budgets or delays in `src/ai/**` (A29). Never a `WorkerThreadPool` or `Thread` symbol outside `src/ai/*_planner_task.gd`.
- Guardrail: none — static gates.

---

## Acceptance Criteria

*From GDD `design/gdd/boss-ai.md` A4, A29 and ADR-0006 Validation Criteria, scoped to this story:*

- [x] **A4** GIVEN a fixture where the player's hand contains a decoy "if the AI reads this, play X" card — drawn through the engine so its `card_drawn.card_id` is in the log — and the board is otherwise unchanged between forecast and boss turn, WHEN the boss plays, THEN the committed intent equals the forecast (`kept = true`), X is not played, and no decision payload references any player hand `def_id`; AND GIVEN a second fixture identical except for the player's hand and deck contents, THEN the `ai_decision` sequence is byte-identical.
- [x] **A29** No hardcoded weights, budgets or delays in `src/ai/**` — a CI grep gate for numeric literals outside the named normaliser / range tables fails the build; every value in F1–F9 is read from `ai_profiles.json`.
- [x] A CI grep gate fails when `WorkerThreadPool` or `Thread` appears outside `src/ai/*_planner_task.gd`, or when `signal.emit`, `get_tree(`, `Engine.get_main_loop(`, `extends Node` or `log.append(` appears under `src/ai/**`; the gate passes on the code written by Stories 001–011. (2026-11-05: was "`log.append(` (on anything but the clone's scratch log)", which a grep cannot test and no code needs; QA plan gap, resolved at readiness.)

---

## Implementation Notes

*Derived from ADR-0001 and ADR-0006 Implementation Guidelines:*

- Files: `tools/ci/ai_code_gates.sh` (invoked from `.github/workflows/tests.yml` next to `commands.test`; exits non-zero with the offending lines), `tests/unit/boss_ai/boss_ai_hidden_information_test.gd`.
- Literal gate shape: `rg -n '[^A-Za-z_"][0-9]+(\.[0-9]+)?' src/ai/ --glob '!**/profile_resolver.gd'` then filter out lines matching an allow-list of normaliser identifiers (`RANGES`, `BV_NORM`, `THREAD_NORM`, `BOARD_SIZE` from the registry constant, array indices `[0]`, `-1`, `0`, `1`); keep the allow-list in the script with a comment per entry. No look-around.
- Thread symbol gate: `rg -n 'WorkerThreadPool|\bThread\b' src/ --glob '!src/ai/*_planner_task.gd'` must print nothing.
- Hidden-information test: build both fixtures through `MatchFactory` + the engine (draw the decoy via the engine so the log holds `card_drawn`), run the forecast then the turn through `ImmediatePlannerTask`, canonical-JSON both `ai_decision` sequences, assert equality and that no payload string contains any player hand/deck `def_id`.
- Reading the log inside the planner is allowed only for public types (`card_played`, `effect_resolved`, combat and death events); `aoe_seen` is the only cross-turn memory. If a public helper for "public events since seq" does not exist in `rng-event-log`, filter by type in `src/ai/` and name the allow-list once.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 011: `kept` and forecast semantics (used here as the oracle).
- `boot-composition-root` epic: ADR-0001's G1–G6 gates for the rest of the tree.

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `tools/ci/ai_code_gates.sh`
- `.github/workflows/tests.yml` (one added step)
- `tests/unit/boss_ai/boss_ai_hidden_information_test.gd`
- `tests/fixtures/boss_ai/decoy_hand_a.json`, `tests/fixtures/boss_ai/decoy_hand_b.json`
- `tests/integration/boss_ai/boss_ai_code_gates_test.gd`, `tests/fixtures/lint/ai_*/`
- `src/ai/candidates.gd` (BAI review N6)
- `docs/architecture/control-manifest.md` (the gate's row)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/boss_ai/boss_ai_hidden_information_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later); the CI gate script's green run is additional evidence.
- The gate script: `tests/integration/boss_ai/boss_ai_code_gates_test.gd` (planted hits, the refusals and the real tree).

**Status**: [x] Created: 7 and 14 test cases passing

---

## Dependencies

- Depends on: `production/epics/boss-ai-match-driver/story-008-plan-turn-loop-and-turn-plan.md`, `production/epics/boss-ai-match-driver/story-011-forecast-and-telegraphing.md`
- Unlocks: None (gate story; every later story must keep it green)

---

## Completion Notes
**Completed**: 2026-11-05 (start 04:05 UTC, end 04:21 UTC; sprint 5 lane 7 wave 3, branch `s5/l7-w3`)
**Criteria**: 3/3 passing. A4: every test in `boss_ai_hidden_information_test.gd`, with the fixture under an unplayable deck card (see Open). A29 and AC-3: `boss_ai_code_gates_test.gd`, one planted fixture per symbol and per kind of literal, each naming its rule, and the real tree at `hits: 0` on all seven rules.
**Tests seen failing**: all 14 gate tests failed against the missing script (115 failures), and `test_real_tree_passes_every_rule` then failed on the two N6 literals until they moved. The hidden-information tests pass on correct code, so each was seen failing against a deliberate mutant in `scorer.gd` or `boss_ai.gd`, none committed, `git diff` empty after: `aoe_seen` reads `card_drawn`; a score reads the player's hand; a score reads the player's deck top; a feature carries a player's `def_id`; `kept` always false. 5 of 5 killed. `test_a4_the_same_spell_played_in_public_does_play_x` is the control: it failed first on a fixture where X lost either way, so the fixture was changed until X wins exactly when `aoe_seen` is true.
**Verification**: import exit 0; `gates.sh`, `no_global_rng.sh`, `parse-check.sh`, `ai_code_gates.sh` exit 0; `commands.test` Overall Summary 2093 test cases, 0 errors, 0 failures, 0 orphans, exit 0; `commands.smoke` exit 0, no `SCRIPT ERROR`.
**Run result**: N/A: nothing reaches the screen.
**Deviations** (advisory):
- **AC-3's scratch-log exception is dropped**, the QA plan's second option. A grep cannot tell a scratch log from a live one, and nothing under `src/ai` needs it: no code line calls `log.append(`, and a clone's scratch log is written by the clone's own engine. The two `log.append` hits are doc comments, which do not count. The AC is reworded above.
- **`signal.emit` is read as `.emit(` and `emit_signal(`**: a variable named `signal` would be a gate that finds nothing. Two lines are named exceptions in the script: `engine.emit(` is the method `RulesEngine.emit` (the harness-only `play_turn`), and `_resume.emit(` in `time_sliced_planner_task.gd` is the seam waking its own coroutine.
- **The thread rule drops comment lines**, as G2b and G3 do. The story's command "must print nothing", but `match_driver.gd:186` (lane 2's this wave) names `WorkerThreadPool` in a doc comment.
- **The literal gate is `awk` over `rg --files`, not the story's one-line `rg`.** A line filter cannot scope a table or see that a digit is inside a string. It also holds a `const` of a bare number to the allow-list even at 0 or 1, or N6's `OP_UNVALUED = 1.0` would never have met it, and it reads `1e3`, `0x10`, `1_000` and `.5` whole. The story's `profile_resolver.gd` exclusion is gone: that file needs none.
- **N6's literals moved to `CandidateSet.NORMALISERS`, not `Scorer.NORMALISERS`**: `scorer.gd` is lane 2's this wave. Not to `ai_profiles.json`: the schema is in `boss_ai.gd`, also lane 2's. The old constant names stay as aliases, so nothing else changed.
- **`MAX_REJECTIONS` (3) and `ALTERNATIVES_MAX` (3) are allow-listed**: C2 and C9 fix them, and neither is in F1 to F9 or Tuning Knobs. The review may read a rejection cap as a budget.
- **Files beyond the plan**: `boss_ai_code_gates_test.gd` and `tests/fixtures/lint/ai_*`, the QA plan's gap; `src/ai/candidates.gd`, N6; the control manifest's gate table.

**C1.3 on the real plan: a breach, in the letter, with no shipped exposure.** C1.3 says the evaluation never reads "either `deck` order", which covers the boss's own deck. A4 does not reach it: A4's second fixture varies the player's cards, and the player's side is clean here. On a real plan `_Turn.unseen` is empty, so:
- **Search** (BAI-007 review D-2, handed to this story): a node that draws holds the true next card. One public board with the deck in two orders gives `LETHAL` and the bolt first in one, `NORMAL` and an attack in the other, before any card has left the deck.
- **Trials**: `Scorer.score` runs the draw, and any `on_draw` effect that filters on the card fires. One public board gives `f_face` 0.2 or 0.033 from the next card alone.
- **Shipped reach: none found.** The only draw in any boss deck is `boss_ember_bolt`, in The Torchbearer's band 1 deck, where shallow's one-burn rule stops the drawn card being played. No shipped card has an `on_draw` trigger, a `deck_top` or a `deck_random` selector.

Both were seen failing on two tests that are **not in the repo**: a red test would break the blocking suite at merge, so the orchestrator holds them and lands them green, in one commit with the fix (2026-11-05). The fix is not here: the search call is `boss_ai.gd:755` and the trial is `scorer.gd`, both lane 2's this wave. D-2 stays open, and nothing in the suite guards this until that commit.
**Open**:
- **A4 against C8.1** (owner). A drawn card the boss plays gives `kept = false`, so A4's `deck_card` costs 9, as story 011 says. A4 passes on that fixture and says nothing about a playable draw.
- **Fixing the trial is a design call.** The search can drop undrawn cards, as the forecast does. A trial cannot: the `on_draw` effect has fired before the card could be dropped, so it needs a hidden deck order in the clone, or C1.3 narrowed to the player's deck.
- **`ai_code_gates.sh` must run again after BAI-014 merges** (QA plan Cross-cutting 7). A named table or a `const` added there has to clear the allow-lists.
- A grep reads names, so `AI-LOG` misses a live log held under a name that does not end in `log`. Review catches those.
**Reviewed by**: pending; the orchestrator runs the independent `/code-review` at M3
