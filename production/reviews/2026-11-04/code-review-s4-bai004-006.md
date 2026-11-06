# Code Review: boss-ai-match-driver 004 (scorer), 005 (candidates), 006 (tie-break)

**Date**: 2026-11-04. **Reviewer**: independent session. `/code-review` was followed by hand from `.claude/skills/code-review/SKILL.md`, because the skill cannot be model-invoked.
**Commits**: `243bb14` (story 004), `274c23d` (story 005) and `e78c5e4` (story 006), merged at `55445b1` on `bootstrap/ccgs-template`. HEAD is `55445b1`, so every `file:line` below is at that commit.
**Standing approval**: the owner gave it. No questions were asked. No source, test or story file was edited, and nothing was committed. Every probe and mutant ran in a scratch snapshot.

---

## Verdict

| Story | Skill verdict | Substantive |
|---|---|---|
| **BAI-004** scorer, F1/F2/F3/F5 | **CHANGES REQUIRED** | **B1**: A18 is ticked, but on the merged decision path removal wins only 20 of 40 seeds. Should-fix: S1 random-effect peek, S2 untested features, S3 `state()` drift |
| **BAI-005** candidates, hero-power rule, positions | **NOT ASSESSED**: the engine-specialist and qa-tester passes could not run | No blocking defect. Should-fix: S4 the pre-filter drops every attack, S2 op_value rows untested |
| **BAI-006** tie-break and stream draws | **NOT ASSESSED**: same reasons | No blocking defect. Should-fix: S5 A3/A5 are not yet in story 008. Nits N1, N2 |

Under the skill's rule, NOT ASSESSED outranks both approvals because the engine-specialist review did not run. If that pass ran and agreed, BAI-005 and BAI-006 would read **APPROVED WITH SUGGESTIONS**.

**Verified clean, by computation rather than by reading the assertions:**
- A11, A13 and A14 match the GDD numbers.
- Determinism holds: two independent builds of all 9 fixtures with the same seed gave byte-identical scored lists and choices.
- Neither the live engine nor the base sandbox moves.
- Every trial clone is released: the object-count delta is 0 over 28 candidates, and the control of 5 unended clones gives +40.
- `rng_match` is never forked.
- Candidates come only from `legal_commands()`.
- `score_all` gives the same result under the immediate, time-sliced (9 yields) and worker-pool planner tasks.

---

## Inputs

| Input | Status |
|---|---|
| Stories 004, 005 and 006, incl. Completion Notes and 006's quick-design / QA-plan amendment | FOUND |
| `design/gdd/boss-ai.md`, read by section: C4, C5, C6, C9, F1–F3, F5, F7, F8, F9, the Edge Cases blocks (targets, board full, data and determinism), A2–A5 and A11–A18, A29 | FOUND |
| ADR-0006 Status/erratum, Decision, Key Interfaces, Guidelines | FOUND |
| ADR-0003 Decision 1–3 and errata | FOUND |
| ADR-0007 Decision 4 (the `state()` rule) | FOUND |
| Control manifest: header, Core Required/Forbidden/Guardrails (Boss AI rows), Forbidden "numeric literal" row, gates table | FOUND |
| `RulesEngine.clone()` doc comment (`rules_engine.gd:3405–3453`), `end_match()` (`:3066–3079`) | FOUND |
| Match-rules 015/017 review notes for BAI-004 (top section) | FOUND |
| Story `## QA Test Cases` | ABSENT: "N/A — no qa-lead specs at this tier" |
| Engine specialists (`godot-specialist`, `godot-gdscript-specialist`) and `qa-tester` | **NOT SPAWNABLE**: no Agent tool in this session. Substitutes were probes P1–P11 and mutants (below) |

## Baseline (main repo, no edits)

- `godot --headless --path . --import` exited 0.
- `commands.test` reported **1372 test cases, 0 errors, 0 failures, 0 orphans, exit 0**.
- That run printed 86 `SCRIPT ERROR` lines. Their origins: `card_database.gd` 44, `rng_stream.gd` 16, `card_database_freeze_test.gd` 7, `event_log.gd` 6, `rng_service.gd` 4, `boss_ai_planner_task_test.gd` 3, and one new `hook_registry.gd` frame. The new one is from `match_rules_choice_test.gd`'s refused setup Discover, which a later merge added. None is in `src/ai/**`.
- `commands.smoke` exited 0 with no `SCRIPT ERROR`.
- `tools/lint/gates.sh` passed with 0 hits on every gate.
- `git status` was clean afterwards.
- Logs: `scratchpad/rv4d_import.log`, `rv4d_suite.log`, `rv4d_smoke.log`, `rv4d_gates.log`.

## How behaviour was verified

- **Snapshot**: `scratchpad/rv4d_snap/` (`git archive HEAD`). Its import exited 0.
- **Probes**: `rv4d_snap/tests/rv4d_probe/rv4d_probe_test.gd`, P1–P11, 11/11 passing. Output is in `rv4d_probe.log`, `rv4d_probe2.log` and `rv4d_probe3.log`.
- **Mutants**: `scratchpad/rv4d_mut.py` applies one mutation per invocation, runs `tests/unit/boss_ai` (112 cases, 3 s), restores the file and asserts the restore. A final `cmp` of all three `src/ai` files against the repo was clean.

### Worked examples, computed

| Case | Hand computation (GDD weights from the resolved stub profile) | Scorer output |
|---|---|---|
| A11 trade | 1.5·0.4 + 1.0·1 + 2.0·3.5/12 + 0.8·1/3 = **2.450000** | 2.450000; features: f_board 0.4, f_trade 1, f_threat 0.2917, f_card 0.3333 |
| A11 play 4/4 | 1.5·0.8 + 1.0·4/6 = **1.866667** | 1.866667, unchanged after the trade |
| A11 end_turn | −6/6 = −1.0, then −2/6 = −0.333 | −1.000000 and −0.333333; order attack, play_card, end_turn |
| A13 | unseen 2·0.3 + 1/3 = 0.933333; seen −1/7 → 0.790476 | 0.933333 / 0.790476, difference = 1/7 exactly |
| A14 (control) | 6/6: 2.5·min(1.2,1) + 3·0.5 + 1 = **5.0**; 1/1: 0.5 + 0.25 + 1 = 1.75; face: 0.1 + 1 − 0.5 = 0.6 | 5.0 / 1.75 / 0.6. The 6/6's f_board is clamped 1.2 → 1.0 |
| A18 | removal 1.0·0.9 + (2.4·1.25)·1/12 = 1.15; face 2.2·4/8 = 1.10 | 1.15 / 1.10, **gap 0.04999999999999982 ≤ tie_epsilon 0.05** → see B1 |

### Mutants (each restored)

| Mutant | Result |
|---|---|
| S1 f_face ÷ max_health | killed (A18) |
| **S2 f_self sign flipped** (the boss likes damaging itself) | **SURVIVES** |
| **S3 f_heal ≡ 0** | **SURVIVES** |
| **S4 f_passive ≡ 0** (synergy) | **SURVIVES** |
| **S5 weapon BV dropped** | **SURVIVES** |
| **S6 Spell Damage flat bonus dropped** | **SURVIVES** |
| **S7 aura flat bonus dropped** | **SURVIVES** |
| S8 [−1, 1] clamp removed | SURVIVES (the lane's own choice is unpinned) |
| **S9 sandbox Choice placeholder disabled** | **SURVIVES** |
| S10 board-full test reads `after` | killed (A18) |
| **S11 DEFENSIVE never reaches `_measure`** | **SURVIVES** (only the static `board_value` is tested) |
| **S13 `aoe_seen_in` ignores the side** (the boss's own AoE sets `aoe_seen`) | **SURVIVES** |
| S14 `_better` index tie order reversed | survives (equivalent for the decision: TieBreak re-sorts canonically) |
| S15 f_threat sums BV, not threat | killed (A11) |
| **C1 `adjacent` yields 1 target** | **SURVIVES** |
| **C2 attack op_value 0** | **SURVIVES** |
| C3 rank tie order reversed | SURVIVES (the kept set among equal ranks is unpinned) |
| **C4 `equip` row dropped** | **SURVIVES** |
| T1 `-INF` guard removed from `tie_set` | survives (equivalent: `best − (−INF) = INF > ε`) |

---

## Findings

### Blocking

**B1. A18 is ticked, but on the merged decision path removal wins only half the time.**
- **Where**: `tests/unit/boss_ai/boss_ai_scorer_test.gd:264–283` and `tests/fixtures/boss_ai/player_board_full.json`. Story 004's A18 is `[x]`.
- **Evidence**: The fixture is calibrated so that the ×1.25 raise is `w_threat · 0.25 · f_threat = 2.4 · 0.25 · 1/12 = 0.05`, which is exactly `rules.tie_epsilon`. The scorer's sort does put removal first, and that is all the test asserts (`scored[0]`, `:281`).
- **Failure scenario**: The decision is made by F8. P2 ran `TieBreak.pick` (story 006, merged in the same lane) on that scored list: the tie set is `[play_card@1.15, attack@1.10]` because the gap is 0.04999999999999982 ≤ 0.05. The face attack was chosen in **20 of 40** `ai_1` seeds. So once story 008 calls `pick`, the "removal is chosen" behaviour that A18 requires is a coin flip.
- **Fragility**: Membership of the tie set also depends on float summation order, so a harmless refactor could flip it.
- **Design side**: In general, ×1.25 cannot break a tie when `0.25 · w_threat · threat/THREAT_NORM ≤ tie_epsilon`. With default weights that covers every target whose threat is ≤ 1.2. GDD A18 and F8 do not say which wins.
- **Fix (test and fixture only)**:
  1. Pick a target and weights whose raise is clearly above ε. For example, a 3/8 target gives threat 3 and a raise of 0.15. Re-balance `w_face` so the base scores stay equal.
  2. Assert through `TieBreak.pick(scored, tie_epsilon, stream)`: `ties.size() == 1` and `chosen == removal`.
  3. Add an advisory GDD note to A18 / Edge Cases: the raise must exceed `tie_epsilon` for the rule to decide.

### Should-fix

**S1. Trial sandboxes see the true outcome of random effects, which breaks C4's "not a peek at the live stream". No story yet owns the fix.**
- **Where**: `src/ai/scorer.gd:179`. Every trial clone copies `rng_match`. The deviation is noted at `:44–46` and in story 004's Completion Notes.
- **Evidence**: In P10, a "destroy a random enemy minion" spell was scored over 12 different live stream positions. The trial's outcome equalled the later live outcome **12 of 12** times. The giant was destroyed live in 5 of the 12 runs, so the result is not a constant.
- **Failure scenario**: When story 008 makes the scorer drive decisions, the boss plays a random-effect card exactly when the RNG will favour it. That is the "AI that cheats" that C4 excludes.
- **What is missing**:
  - Story 004 says there is "no public seam" to install a `sim_<turn>` fork on a clone.
  - `story-008-plan-turn-loop-and-turn-plan.md` mentions neither the fork installation nor the seam it needs. Only `:49` names forks, and only for counting.
- **Constraint on the fix**: The root plan sandbox must keep the real `rng_match` copy, or replay diverges (ADR-0006). Only the one-ply trials should draw from the fork.
- **Fix**:
  1. Add a match-rules seam, for example `clone(rng_override: RngStream = null)` or `clone_with_stream(stream)`, used for trials only.
  2. Add a criterion to story 008: a trial's random draw comes from `ai_<floor>/sim_<turn>`, and the live and root-sandbox `rng_match.draws` are unchanged.
  3. Until both land, list the gap under the story 008 readiness prerequisites.

**S2. Most F1/F2 terms and the C6 op rows can regress with no test failing.**
- **Where**:
  - Scorer: `scorer.gd:374` (f_self), `:394` (f_heal), `:401` (f_passive), `:250` / `:253` (Spell Damage and aura flat bonuses), `:430–435` (weapon BV), `:427` (DEFENSIVE through `_measure`), `:324` (`aoe_seen_in` side filter), `:182` / `:348–357` (Choice placeholder), `:402–403` (clamp).
  - Candidates: `candidates.gd:241` (adjacent count), `:148` (attack row), `:142` (equip row).
- **Evidence**: 13 of the 19 mutants above survive the full boss-ai unit suite. The two most consequential:
  - **S2**, the sign flip on `f_self`: the boss would rank self-damaging trades highest.
  - **S13**: a boss's own Flamestrike would switch on the player's over-extension cap. That is a C1.3 / F5 regression.
- **Fix**: Add one small board fixture per term, each asserting the feature value and the resulting score difference:
  - a minion that hits back, for f_self;
  - a heal on a damaged boss, for f_heal;
  - a `synergy_tags` profile with a tagged card, for f_passive;
  - a weapon play;
  - a Spell Damage minion and an aura minion on board;
  - `MODE_DEFENSIVE` through `score()`;
  - a *boss*-cast AoE that must leave `aoe_seen` false;
  - an overkill face hit, to pin the clamp;
  - an `adjacent` spell's and a weapon's `op_value`.
  The sandbox-Choice placeholder can use a resolver double that raises a boss Choice.

**S3. `src/ai/**` reads `RulesEngine.state()` (ADR DRIFT, ADR-0007 Decision 4).**
- **Where**: `scorer.gd:412–453`, `candidates.gd:96`, `:101`, `:131`, `:234`.
- **The rule**: ADR-0007 Decision 4 says "`state()` may be called only from `src/gameplay/effects/**`; `MatchQuery` and Boss AI keep using `snapshot_entity` / `clone()`". Story 004's own Engine Notes say "never reach into `MatchState` fields the match-rules API does not expose".
- **Why it is drift, not a violation**: The use is documented, read-only, and on clones only. The ADR's escape hatch does not exist: `state_snapshot(id)` cannot enumerate a board.
- **Concrete coupling**: `scorer.gd:432–434` re-derives weapon attack (base plus enchantment deltas), duplicating `RulesEngine.attack()` (`rules_engine.gd:1550–1559`). `_keywords` (`:456`) duplicates `_has_keyword`. A future aura on weapons or keywords would change the engine and silently not the scorer.
- **Fix**: Register a TD item and add an ADR-0007 erratum naming the read API Boss AI may use until `MatchQuery` exists. Read hero and weapon attack through engine functions, not fields.

**S4. With the C6 reading of attack as one `damage` row, the pre-filter drops every attack once it engages, a lethal face attack included.**
- **Where**: `candidates.gd:147–148` (an attack is `_row("damage")` = 1.0, whatever the attacker or target) and `:112–116` (ties keep `legal_commands()` order, where every `play_card` comes before every `attack`).
- **Evidence**: In P7 (the `wide_hand_prefilter` board, player hero at 1, a hand of a 3-target AoE plus five 3-target minion-only removal spells, cap 10), the kept set was `{play_card: 9, end_turn: 1}`. All 8 attacks were dropped, including the lethal face attack.
  - Best over all legal commands: the face attack, 1.50.
  - Best over the kept set: a 0.87 removal.
  - Every dropped command ranks equal to the kept ones, so the "dropped ≤ kept" assertion (`boss_ai_candidates_test.gd:224–230`) passes trivially.
- **Mitigation**: Lethal search (C3, every band ≠ `off`) would catch the lethal itself, but not a strong non-lethal face attack or trade.
- **Exposure**: Realistic at band 1 (cap 40). For example, 6 awake boss minions against 7 player minions is 48 attacks alone.
- **Fix (design call)**: Value an attack by its damage, for example `damage row × attack(attacker)` normalised like a spell, or a kill bonus. Or always keep the top-k attacks. Record the choice in GDD C6 or Open Questions. Then add a test where an attack must survive the cap.

**S5. Story 006 moved A3 and A5 to story 008, but story 008 does not have them.**
- **Where**: Story 006 records the move at `:299` and `:371`. `production/epics/boss-ai-match-driver/story-008-plan-turn-loop-and-turn-plan.md` contains no A3/A5 text; `grep` finds only `:49`.
- **Failure scenario**: The per-turn draw-accounting and live-stream criteria are dropped silently when story 008 closes.
- **Fix**: The orchestrator adds A3 and A5 to story 008, as story 006 asks. S1's fork criterion belongs in the same edit.

**S6. Budget tracking: re-measured cost per candidate.**
- **Where**: The cost comes from the structure of `scorer.gd:173–196`.
- **Measurement** (P11, debug build, headless):
  - 1.28 ms per candidate on a 28-candidate board, of which `clone + end_match` is 120 µs and `_measure` 38 µs (run twice per candidate).
  - At F7's band-2 cap (120) that is about 150 ms **per action**. At band 3 (250) it is about 320 ms per action.
- **Status**: Story 004 already says F7 needs revising, so this confirms that note rather than adding a new defect.
- **Small fixes**:
  - Hoist `before = _measure(sandbox_before)` and `effective_weights` out of `score()` into `score_all` (`:175`, `:195`).
  - Let `card_playable` reuse the candidate list instead of a second `legal_commands()` call (≈ 0.47 ms, `:145`, `:201`).

### Nits

- **N1** `tie_break.gd:36`: `KEY_FIELDS` has no `option_index`, so equal-scored `choose` candidates keep input order, not canonical order. P9: `[2,0,1]` stays `[2,0,1]`. The result is deterministic but not canonical, and `TYPE_ORDER` claims to cover `choose`. Add `option_index` before story 010 uses it.
- **N2** `boss_ai_tie_break_test.gd:114`: the expected draw count is derived from `decision.ties.size()`, which is the implementation's own output, so the check is circular. Pin it to the fixture's `expect.tie_size`.
- **N3** Scored over raw `legal_commands()`, a plain minion offers every position. P1 step 1 shows the 4/4 at positions 0 and 1 forming a size-2 tie set, which costs an extra `ai_<floor>` draw. Every test feeds `score_all` raw `legal_commands()` except the candidates suite, and nothing tests the composed `collect → score_all → pick` pipeline. Story 008 should test it end to end.
- **N4** `scorer.gd:211–215`: `alternatives()` takes the top 3 by score. After a tie-break picks a lower tie member, the chosen command may not be first or may not be listed. Define C9's relation between `chosen` and `alternatives` in story 008.
- **N5** `scorer.gd:174` / `candidates.gd:95`: the scoring side is `active_side()`. A forecast clone (story 011) taken in `PlayerTurn.Main` would score the player's moves unless it is first advanced to the boss turn. Consider an explicit `side` parameter.
- **N6** Literals outside `Scorer.NORMALISERS`: `candidates.gd:47` (`OP_UNVALUED`) and `:50` (`BODY_DIVISOR 4.0`).
  - GDD A29 allows numeric literals only "outside normalisers". The manifest Forbidden row says "never a numeric gameplay literal in `src/ai/**`".
  - The A29 grep gate does not exist in `tools/lint/gates.sh` yet, so nothing checks this.
  - GDD F2's variable table lists `taunt_bonus` and `flat_bonus` as "data file", while F9's closed schema has no key for them. That is a GDD inconsistency the lane resolved with the normaliser table. That table is acceptable (MINOR DEVIATION). Promote `board_full_threat` and `defensive_taunt_bv` to F9 `rules` when F9 is next revised: they are tuning, not normalisation.
- **N7** `scorer.gd:361–404` (`_features`, 44 lines) and `:412–453` (`_measure`, 42 lines) exceed the 40-line standard. `_ops_aoe` (`:472–499`) is at about cyclomatic 11.
- **N8** `scorer.gd` and `candidates.gd` reference each other: `CandidateSet.hero_power_feature` is called from the scorer, and `Scorer.is_aoe`, `selector_name`, `synergy_match` and `OP_CHOOSE_ONE` are called from candidates. Move the shared C6 derivations into one helper.
- **N9** `end_turn` is scored without a sandbox (`scorer.gd:178`, `:386–387`). Consequence: the boss's own end-of-turn triggers and "until end of turn" expiries are never valued. GDD C4's "`end_turn` is always simulated" needs the erratum the story implies.

### The lane's open GDD choices

| Choice | Assessment |
|---|---|
| Minion body = C7 `buff × (atk+hp)/4` | Reasonable. Documented in story 005. Record it in GDD C6 |
| Attack = one `damage` row | **S4**: systematically ranks attacks last among ties |
| Cap after position filter, `cap − 1` + `end_turn` | Correct reading of C6: a non-sensitive position is not a candidate. Only `cap − 1` are actually simulated, because `end_turn` is not simulated |
| `end_turn` scored without a sandbox | Acceptable, because simulating it would score the player's draw. Needs a GDD C4 erratum (N9) |
| Features clamped to [−1, 1] | Consistent with C5's "each `f_i ∈ [−1, 1]`" (F1 writes clamps on only 3). Visible effects: A14's f_board 1.2 → 1.0, and f_face saturates at lethal (P8). Unpinned by tests (S8 mutant) |
| Hard-coded `Scorer.NORMALISERS` | Sanctioned by A29's "outside normalisers". See N6 for the two rows that are really tuning values |

---

## Skill sections (Phase 8 shape)

### Engine Specialist Findings: NOT ASSESSED
- `godot-specialist` and `godot-gdscript-specialist` could not be spawned.
- What the reviewer checked directly on 4.7.2:
  - `await` on a non-coroutine `checkpoint()` returns at once.
  - A `TimeSlicedPlannerTask` whose clock forces a yield at every checkpoint resumes `score_all` 9 times and returns the identical result (P4).
  - `WorkerPoolPlannerTask` runs `score_all` off-thread on a clone, reading the `FakeCardDatabase`, with no error and an identical result (P4).
- Concurrent read-only `Dictionary` access stays NOT SOURCEABLE (story 017).

### Testability: GAPS
- Every AC has a test, and A11, A13 and A14 hold when computed.
- A18's test does not exercise F8 (B1).
- 13 surviving mutants (S2).
- The composed pipeline is untested (N3).

### ADR Compliance: DRIFT
- **ADR-0006**: COMPLIANT.
  - Only clones are scored.
  - Every trial is `end_match()`ed on the normal, rejected and overflow paths (P6 object delta 0).
  - One checkpoint per candidate; works under all three task shapes.
- **ADR-0003**: COMPLIANT on its rules.
  - No `rng_match.fork`; no `RandomNumberGenerator`.
  - `ai_<floor>` is drawn only in `TieBreak.pick`: 0 or 1 draws, verified.
  - Its TR-boss-ai-001 row ("memoised `fork("sim_<turn>")` gives the planner an isolated source") is not met yet: S1, ADR DRIFT.
- **ADR-0007** Decision 4: ADR DRIFT (S3).
- **ADR-0001**: COMPLIANT (`RefCounted`, no Node; gates G1–G6 at 0 hits).

### Standards Compliance: 4/6
- Passing: doc comments on public APIs, injected dependencies, and interfaces (`RefCounted` collaborators via `_init`).
- Failing: the method-length rule (N7), and data-driven configuration, which is partial (N6).
- Cyclomatic complexity is borderline for `_ops_aoe`.

### Architecture: MINOR ISSUES
Dependency direction `src/ai → src/gameplay` is correct. Issues: the circular `Scorer` ↔ `CandidateSet` references (N8) and the `state()` coupling (S3).

### SOLID: ISSUES FOUND (minor)
- SRP: C6 derivations are split across two classes (N8).
- OCP: a new feature means editing `_features`, which is acceptable for a closed eleven-key F1.

### Game-Specific Concerns
- No frame-time code; the scorer runs on the planner task.
- Allocations per candidate: `_measure` builds dictionaries twice per candidate (S6).
- Null handling: the db, an absent `def` and an empty hand index are guarded.
- Resource cleanup was verified (P6).

### Positive Observations
- Clone discipline is exemplary. `end_match()` sits on both exits of `score()` (`:186`, `:192`), and there is a test with weakrefs for the rejected path.
- The A11 numbers are exact to 6 dp, without fudge.
- `end_turn`, `-INF` and empty-list edges are handled deliberately in TieBreak.
- Draw accounting is exact, and ε-boundary tests use binary-exact values.
- Each story records honest deviations, including the budget warning.
- Determinism holds across independent builds (P3).

### Required Changes
- B1 (story 004).

### Suggestions
- S1–S6 and N1–N9.

---

## Scratch artefacts

All of these are in `/tmp/claude-0/-home-user-dungeon-run-ccg/cb1e7c62-c2a7-52ec-b886-47b571cec227/scratchpad/`:
- `rv4d_snap/`: a `git archive` of HEAD `55445b1`.
- `rv4d_snap/tests/rv4d_probe/rv4d_probe_test.gd`: probes P1–P11.
- `rv4d_mut.py`, with `rv4d_orig_scorer.gd`, `rv4d_orig_candidates.gd` and `rv4d_orig_tie_break.gd` as its restore sources, and `rv4d_mut_<id>.log` per mutant.
- `rv4d_probe.log`, `rv4d_probe2.log` and `rv4d_probe3.log`: the probe output.
- `rv4d_import.log`, `rv4d_suite.log`, `rv4d_smoke.log` and `rv4d_gates.log`: the baseline logs.
