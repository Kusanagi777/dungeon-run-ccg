# Story 012: Hidden-information purity (A4) and the src/ai CI gates (A29, thread symbols)

> **Epic**: Boss AI + Match Driver
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

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

- [ ] **A4** GIVEN a fixture where the player's hand contains a decoy "if the AI reads this, play X" card — drawn through the engine so its `card_drawn.card_id` is in the log — and the board is otherwise unchanged between forecast and boss turn, WHEN the boss plays, THEN the committed intent equals the forecast (`kept = true`), X is not played, and no decision payload references any player hand `def_id`; AND GIVEN a second fixture identical except for the player's hand and deck contents, THEN the `ai_decision` sequence is byte-identical.
- [ ] **A29** No hardcoded weights, budgets or delays in `src/ai/**` — a CI grep gate for numeric literals outside the named normaliser / range tables fails the build; every value in F1–F9 is read from `ai_profiles.json`.
- [ ] A CI grep gate fails when `WorkerThreadPool` or `Thread` appears outside `src/ai/*_planner_task.gd`, or when `signal.emit`, `get_tree(`, `Engine.get_main_loop(`, `extends Node` or `log.append(` (on anything but the clone's scratch log) appears under `src/ai/**`; the gate passes on the code written by Stories 001–011.

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

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/boss_ai/boss_ai_hidden_information_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later); the CI gate script's green run is additional evidence.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/boss-ai-match-driver/story-008-plan-turn-loop-and-turn-plan.md`, `production/epics/boss-ai-match-driver/story-011-forecast-and-telegraphing.md`
- Unlocks: None (gate story; every later story must keep it green)
