# Sprint 5 W3 independent code review: effects and gates

Reviewer: lead-programmer. Commit read: `74bc77c`, branch `bootstrap/ccgs-template`. Read-only: no Godot run and no test run.

Run for this review: `tools/lint/gates.sh .` (G1-G7, 0 hits), `tools/ci/ai_code_gates.sh .` (7 rules, 0 hits), and `ai_code_gates.sh` against throwaway trees in the scratchpad.

## Verdict summary

| Item | Verdict |
|---|---|
| CE-015 (`bcc6d53`) | APPROVED WITH SUGGESTIONS |
| BAI-012 (`52f746c`, `363e8e2`, gates) | CHANGES REQUIRED |
| Treasures 005 (`22d7d35`, `5682fab`), summary | APPROVED WITH SUGGESTIONS |
| Treasures 006 (`44d3bf4`), summary | APPROVED WITH SUGGESTIONS |
| DD-X29 (`26f7f47`), summary | APPROVED WITH SUGGESTIONS |

**Not assessed anywhere in this report:** every test pass count and mutant claim in the stories. Nothing was executed, so "passes" means reasoned from source. Also not assessed: the `< 2 ms per match` guardrail, and the two C1.3 tests held outside the repo.

---

## Code Review: CE-015 hook trigger steps and hero-slot observers

### Engine Specialist Findings: ISSUES FOUND
`godot-gdscript-specialist` ran on the diff. One finding, which I verified: `effect_resolver.gd:1211` `PLAY_SOURCE: int(run_ctx.source_id)` (S-1 below). Its other areas came back clean. Typed `Dictionary.get`, `Array[Array].resize` and Dictionary `!=` semantics are `NOT SOURCEABLE` from `docs/engine-reference/godot/`. In shipped paths every key reaching `rank.get` is an int, because `_queue_entry` always sets `candidate`, so the first of these does not matter there.

### Testability: GAPS
`qa-tester` ran. Order, count and source are properly asserted for AC-16, AC-25, AC-36 and AC-45. I checked each gap below myself.

- **AC-16 step count:** the test at line 372 counts `effect_resolved`, not `_steps`. Disclosed in the story. See Q-1.
- **AC-45 "no `E_FX_TRIGGER` at load":** the qa-tester called this unasserted. It is unasserted in this test file, because `_grave_tithe()` skips the validator. It is covered indirectly: `TreasureFixtures.database` fails unless the database reaches `READY`, and the record loads through it. Not a gap in substance.
- **`resume` stamping:** line 860 reads amounts only, so a `discover_picked` that lost its `source_id` would pass.
- **`outer` restore in `_continue_pass`:** no host-inside-host case exists. Rot Warden hitting a player `on_damage_taken` treasure reaches it once treasures ship.
- **Hero-slot triggers:** of the nine hook-less triggers, only `on_heal` and `on_minion_died` fire from the hero slot in tests. Every raise uses `_candidates_in_order()`, so by reading the rest work.
- **Weak assertions:** the `once_marked` check at line 618 is true by construction (the mark is set at queue time). Gatekeeper at line 1243 has no negative case. Line 729 `is_greater` compares against -1 if the event is missing.
- **AC-36 duplicate:** the duplicate host has only hook effects, so the `if hooks.install` guard on `_keep_hosted` has no test.

### ADR Compliance: DRIFT (minor)
- **ADR-0005:** rules 1-6, 8, 9 and 11 hold. Rule 7 holds, because clones bind with no installers and carry hosts in `effects`.
- **MINOR DEVIATION:** `hook_registry.gd:90` reads `scope.who`. The manifest says the registry evaluates nothing, and the ADR-0007 erratum (d) says it "reads the binding table only". It is an install-time classification, not an evaluation, but the erratum's sentence is not quite true (N-1).
- **ADR-0007:** errata (a) to (d) match the code. `RulesEngine.PRIMITIVES` is unchanged. `docs/architecture/control-manifest.md` has no row for `set_event_source`, String queue sources or `host_kind`, so it needs regenerating (N-2).

### Standards Compliance: 6/6 passing
Doc comments are present and no new method exceeds 40 lines or the complexity limit. Hard-coded numbers: none new.

### Architecture: MINOR ISSUES
`_event_source` is temporal coupling between resolver and engine. It is documented, ADR-recorded and contained. `HOOK_SCOPE_TRIGGERS` in the resolver is the reverse of `DSL_HOOK_POINTS` in the registry, and exists only for fixtures (N-3).

### SOLID: COMPLIANT

### Game-Specific Concerns
None in `_process` paths. `_collect_hero_slot` re-derives `_is_hero_slot_observer` per raise, including `StringName` construction, and runs on planner clones too. Small, not measured.

### The questions asked

**1. `rules_engine.gd` and `hook_registry.gd` edits: necessary and sound? Yes.**
- `install` keyed on the raw trigger, so `turn_start` landed on no point. Without `hook_point` no turn passive installs.
- `_enqueue` and `_execute_queued` refused a String `source_id`, so no hero-slot observer could queue.
- `emit` stamping is the least invasive way to give `armor_gained` and `minion_summoned` a source, since C15 has no such field.
- `transform` and `entered` close the CE-013 Edge Case.
- The story's "this story writes none of them" was wrong about what the work needed, and the deviation is recorded.

**2. Candidate-major death queue.** AC-45 needs it. Raise order gives R(A), T(A), R(B), and the treasure must follow both of row 11's triggers. C6.3 previously said nothing about several deaths, and C6.2 says candidate order, so the rule is a fair reading.

It is wider than AC-45 strictly needs, because it also reorders card observers. `design/gdd/card-effects.md:392` was edited by the implementer, and `design/gdd/match-rules.md:430` was not (Q-2).

**Goldens did not move because they do not reach this path.** Across all 16 golden files there are 7 checks with two or more deaths (`chain_submit` 1, `scripted_match` 6), with zero `on_minion_died` queued after them. The only observers are in `trigger_order.jsonl`, on one death, which takes the unchanged `dead.size() == 1` branch.

**Shipped reach exists but changes no state.** The observers are Gravekeeper (`cards_neutral.json:392`, `add_counter`) and Rot Warden. Two Gravekeepers, or one with Rot Warden, on a two-death check now log G, G, R, R where it was G, R, G, R. Counter adds and 1 damage commute, and C14 runs after the queue, so only log and animation order change. Raise-time reads are unaffected: the tallies, marks and collection still run per death.

The sort itself is exercised by AC-45's test. Order among two non-`once_per_turn` observers is not (S-3).

**3. Can `set_event_source` leak? No path found.**
- `_continue_pass` restores `outer` on every exit. It holds `engine` in a local, so an unbind during the pass is safe.
- On a Choice suspension it restores before `_offer`'s caller returns, so `_park` runs with null.
- `resume` clears after `_apply_pick`, then `_continue_pass` sets it again. The unconditional null is correct, because `resume` is never nested.
- Card passes never nest inside a host pass: raises only collect, and the only nesting is a host hook. Queued card triggers run from `_drain`, outside any pass.
- `_recompute_auras` and `_report_cost_changes` run outside passes.
- `clone()` asserts `not _resolving`.
- Consumers checked: `src/ui` and `src/ai` never `int()` a stamped `source_id`. `match_view_state.gd` `_ids()` skips non-numbers, and `damage_dealt.source` only reaches `var_to_str`.

**4. `aura_hosts`: isolation and replay determinism. Both right.** `MatchState.clone` uses `effects.duplicate(true)`. The clone's `bind` passes no installers, so nothing doubles. Effect ids are settled from the installer index at `_keep_hosted`, so a queue entry's index and its `once` key survive a clone. `pending_choice` carries `RUN_HOST_EFFECT` by value. Host order is installation order. Nothing writes the array after `bind`, and `_names_trigger_entity` is a derived memo.

**5. Five shipped passives: by my own trace all five install and fire at engine level.**

| Boss | Install | Path |
|---|---|---|
| `boss_torchbearer` `turn_end` | `on_turn_end` entry | End stage `STAGE_HOOK`, `run_hook_effect`, scope `side: owner` passes on the boss turn only, `damage` through effect-level `targets` (`ops.gd:587`), String source tolerated by `_apply_damage` |
| `boss_rat_king` `turn_start` | `on_turn_start` entry | Start stage, `summon` at `end`, `run_source` gives -1 so no slot lookup misreads the id |
| `boss_hollow_king` `turn_start` | `on_turn_start` entry | Same path, `buff` on `all_friendly_minions` for owner boss |
| `boss_rot_warden` `on_minion_died` | `aura_hosts` | `_collect` at the boss hero candidate, `who: friendly_minion` against the dead minion's side, empty snapshot, `_execute_queued` then `_run_queued` from `hosted_effects` |
| `boss_gatekeeper` `aura` | `aura_hosts` | `recompute_auras`, `_aura_run` with owner boss, `apply_enchantment` with `is_aura` |

The tests use `DataLoader` on shipped data and `Treasures.passive_installer`, which is the right level.

**Limit:** no code in `src/` builds a `MatchConfig`. `RunMachine` does not exist and `MatchDriver.new` has no `src/` caller, so `passive_installer` has no production caller. End-to-end firing is **NOT ASSESSED**. The risk sits in the run-structure epic, not here.

### Positive Observations
- The `_claim_once` signature change keeps one mark path for cards and hosts.
- `_enqueue` keeps the malformed-entry guard while admitting String sources.
- The Completion Notes disclose every deviation, including ones that do not flatter the work.
- Depth handling across the nested pass is correct.

### Required Changes
None.

### Suggestions
- **S-1 (defect, latent):** `effect_resolver.gd:1211` `int(run_ctx.source_id)` reads digits from a host id, the fault `selectors.gd` warns about. Trigger: a treasure or passive `discover ... then: "cast"`, which the validator accepts. No shipped or fixture record has one. One-line fix, plus `_run_play_from`.
- **S-2 (defect, low):** `hook_registry.gd:183-184` checks `_run_entry.is_valid()` once, before the loop. An `event_cap` inside the first of two inline entries unbinds, and the next iteration calls an empty Callable. CE-015 is the first real evaluator here. Runtime effect `NOT SOURCEABLE`. Check validity per entry.
- **S-3:** add one two-observer, two-death test (neither `once_per_turn`) and one golden, since C6.3 now states the order. Add host-in-host and `discover_picked` stamping tests, and a hosted duplicate for AC-36.
- **S-4:** a hosted `on_damage_taken` or `on_attack` with no scope defaults to `self` against -1 and silently never fires. Worth a validator warning.

### Design questions for the owner
- **Q-1:** AC-16 says the step counter rose by 2. `_steps` rises by 3, because the `turn_start` raise is a step, and a hook entry skipped by scope also counts. C6.0 says the cap counts passes, and the engine counts more than passes. AC-16 is ticked. Amend the AC, or decide what `_steps` means.
- **Q-2:** ratify the card-observer reorder and mirror it in match-rules C10, which owns the death check.
- **Q-3:** C2's closing prose and C9 still list `on_summon` as hook-less, against C2's table, C6.3 and this code. The GDD was edited in this commit but not there.
- **Q-4:** the story's open items stand: `on_turn_start` hooks read last turn's tallies, and hero-power event triggers are unhosted.

### Nits
- **N-1:** reword erratum (d).
- **N-2:** regenerate the manifest.
- **N-3:** `HOOK_SCOPE_TRIGGERS` is production code serving fixtures only.
- **N-4:** `str(effect).contains("trigger_s")` is a text scan of a dictionary. False positives only cost a copy.
- **N-5:** `rules_engine.gd:3188`, the `_death_check` doc, still reads as raise-per-death ordering.
- **N-6 (out of scope):** `match_view_state.gd:497` `_entity_id_of` gives 0 on `trigger_queued`, which has only `source_id`, for card triggers too.

### Verdict: APPROVED WITH SUGGESTIONS

---

## Code Review: BAI-012 hidden information and the `src/ai` gates

### Engine Specialist Findings: N/A
Shell and test code. Not sent to the specialist.

### BAI-012 — Testability: GAPS
`qa-tester` ran. A4 is covered, with the control test `test_a4_the_same_spell_played_in_public_does_play_x`. Limits: `kept = true` holds only because `deck_card` costs 9 (disclosed), and `ai_decision` is read from `plan.diagnostics`, not the log. AC-3 is covered per symbol. The "could not run" path of `AI-LITERAL` has no test (D-1).

### ADR Compliance: DRIFT
- ADR-0006 thread rule enforced.
- ADR-0001's rule "mutates only through `submit`" is not met by `boss_ai.gd:635`, `engine.emit(...)` in `play_turn` (Q-5). The gate exempts that line by name.

### Standards Compliance: N/A (script and tests)

### BAI-012 — Architecture: MINOR ISSUES
Header line 24 says "nothing under src/ai writes a log directly". `boss_ai.gd:635` does, through `RulesEngine.emit`.

### SOLID: N/A

### Can the gates be evaded or pass vacuously? Yes to both, verified by running the script.
A control tree proved the same script fires on the same shapes. The evasion tree printed `hits: 0` on all seven rules and exit 0.

| Shape | Result | Kind |
|---|---|---|
| `src/ai/` with no `.gd` files | every rule `hits: 0`, PASS, exit 0 | vacuous pass (D-1) |
| `const UNPRICED: float = 0.75` in any file | passes: names are not tied to a value or a file | evasion (D-2) |
| `const NORMALISERS = {"w_face_secret": 7.5}` or `const RANGES := {"lethal_budget": 4000}` in any file | passes | evasion (D-2) |
| `const W: float = +1.0`, `(1.0)`, `static var w = 1.0` | passes: the const rule needs a bare leading digit, and 0 and 1 are exempt elsewhere | evasion, by design for `var` |
| `"0.75".to_float()`, `int("4000")` | passes: strings are stripped first | deliberate only |
| `table[9]` | passes: any index, where the story allowed `[0]` | low |
| `var f := done.emit; f.call()`, `done . emit()`, `call("emit_signal", ...)` | passes | deliberate only |
| `engine.emit(&"x", {}); done.emit()` | whole line dropped by the exemption | evasion |
| `get_node(...)`, `add_child` | not a rule, though the manifest forbids "any `Node` method" | outside the AC's list |
| `events.call("append", ...)` | passes (the story admits the name limit) | deliberate only |

Most of these need intent, and a gate of this kind catches accidents, so I would not chase them all. D-1 and D-2 are different: the natural way to add a weight, a new key in `NORMALISERS`, passes silently, and the empty tree breaks the script's own header contract.

### `MAX_REJECTIONS` and `ALTERNATIVES_MAX`: legitimate, keep them in code
- `MAX_REJECTIONS` 3 is a fixed rule, not a budget: `design/gdd/boss-ai.md` C2 pseudocode line 113, the States tables at 322 and 334-335, and Edge Cases 614-616. It is not in Tuning Knobs, and A23 holds any rejection to be a bug.
- `ALTERNATIVES_MAX` 3 is C9's payload shape, `alternatives[≤3]`.
- Neither belongs in `ai_profiles.json`. Both should be pinned to their value in the gate (D-2).

### BAI-012 — Positive Observations
- `hits: <n>` per rule, with `could not run` printed instead of a count for rg-based rules.
- The tokeniser reads `1e3`, `0x10`, `1_000` and `.5` whole.
- The `const` rule closes the `OP_UNVALUED = 1.0` hole.
- The story discloses the C1.3 breach in plain terms and did not soften it.

### BAI-012 — Required Changes
- **D-1 (defect, blocking):** `tools/ci/ai_code_gates.sh:138-139`. `mapfile < <(rg --files ...)` discards rg's exit status, and `[ "${#files[@]}" -eq 0 ] && return 0` turns no input into `AI-LITERAL hits: 0`. The header promises exit 2 for "rg or awk erroring" and "a refusal never prints a hit count". Verified: an empty `src/ai` exits 0 with PASS. Fix: treat zero files or an rg failure as could-not-run, add a fixture.
- **D-2 (defect, blocking):** `ai_code_gates.sh:39,49`. Allow-lists match a name anywhere with any value. Scope `RANGES`, `NORMALISERS` and `BOARD_SELECTORS` to their files, and pin each `ALLOWED_CONSTS` entry to its file and value. The script comments already name those files. Also pin the `NORMALISERS` key set, or a new weight still passes unseen.
- **D-3 (defect, blocking):** `src/ai/scorer.gd:115,118-120`, ticked at `story-012...md:37`. A29 says every value in F1-F9 is read from `ai_profiles.json`. `design/gdd/boss-ai.md:466-467` gives `flat_bonus` and `taunt_bonus` the source "data file". They are literals in `Scorer.NORMALISERS`, and `ai_profiles.json` has no such keys. The gate passes only because the table's name is allow-listed. Either move them to data, or the owner amends F2's Source column. The AC cannot stay ticked as it reads. The schema is in `boss_ai.gd`, so this is the owning lane's.

### BAI-012 — Suggestions
- **S-5:** narrow the `engine.emit` exemption to the one line in `boss_ai.gd`, matching on file as the `_resume.emit` case does.
- **S-6:** record the C1.3 breach (Q-7 below) in `docs/tech-debt-register.md`. I found it only in stories and the review. The story says nothing in the suite guards it until the held tests land.

### BAI-012 — Design questions for the owner
- **Q-5:** does `play_turn` stay in `src/ai`? Its only callers are tests, and it writes to a log through `engine.emit`. Story 016 says the harness goes through the driver.
- **Q-6:** which `NORMALISERS` entries are normalisers? `windfury 0.5`, `weapon_bv 0.8` and `trade_even_band 0.2` are formula constants in F2 and F3 with no data source, and A29's "every value" covers them. `board_full_threat`, `defensive_taunt_bv`, `big_minion_cost` and the `cost_fit_*` pair come from prose outside F1-F9.
- **Q-7:** C1.3 on the real plan: the search and the trial read the boss's own deck order (BAI-007 D-2). Shipped reach, by the story's account: none. The trial fix is the design call the story names.
- **Q-8:** A4 against C8.1: a playable draw gives `kept = false`, and the AC says nothing about it.

### Verdict: CHANGES REQUIRED

---

## Summary review: treasures 005, 006

Test-only commits plus a story byte repair: no production change, confirmed from `--stat`.

**Contract risks:**
- `treasures.json` has **0 records**. Everything here is proven on `tests/fixtures/data/treasures_v1.json`, so shipped-treasure behaviour is `NOT ASSESSED`, as the QA plan says.
- The clean root's rules are `MatchFactory` bodies, not shipped knobs. `hero_power_cost` in these tests is therefore the fixture's.
- Hands are scripted by state edits except in AC-8, which goes through the real deal and log. Acceptable for fold tests.
- AC-8's "F1 event" is the `auras_recomputed` entry `{effective_cost: 0, hook_delta: -2}`, which matches `_cost_entry` and the DD-X29 GDD text.
- Against `boss_test_taxman`, `set 1` then `+1` nets to base, so no entry is logged. Correct by `_note_cost`.
- Story 005's open item (Banner still showing its discount during a Battlecry Discover pause) reads correctly from the code: the tally bumps at `on_card_played`, after the Battlecry stage. Display only, since nothing can be paid in `Choice`.
- Story 006's note is right that the hand clamp is proven only by `test_ac13_no_card_burns_during_the_deal`.

I found no assertion guarded so that it can pass empty, but I read these two files by scan, not line by line. **Verdict: APPROVED WITH SUGGESTIONS** (add a GIVEN clause to AC-16/17/19/23, as the QA plan notes).

---

## Summary review: DD-X29 cost logging

**Can the comparison state desync across a clone or replay? No desync found.**
- **Clone:** `rules_engine.gd:4114` copies `_shown_costs`, so a scratch log does not repeat what the live log said, and `TurnPlan.checksum`, which hashes event types, stays equal. A shallow copy is safe: entries are replaced, never written. `test_a_clone_inherits_what_was_reported_and_moves_on_alone` and the mulligan clone test cover it.
- **Single timeline:** `shown` is rebuilt from scratch at each pass, so stale keys clear. Mulligan is the one hand-to-deck move and erases its key (`:2539`). `return_to_hand` and `add_card_to_deck` mint new instances. Both no-loop rests report (`:610`, `:2958`).
- **Replay:** re-submitting commands reproduces the ledger. The view takes absolute values, and an absent `hook_delta` means 0.

**Risks:**
- **Q-9 (design question):** `_shown_costs` lives on `RulesEngine`, not `MatchState`. `MatchState.clone()` alone loses it, though the engine is its only caller. C6.8 promises a future `restore(log)` for `EffectRuntime`, and this ledger is not in it. A restore must rebuild it from the last `auras_recomputed`, or the first recompute repeats or drops entries. No `restore` exists today.
- **S-7 (performance, unmeasured):** any `modify_cost` hook makes `_costs_at_baseline` false for the whole match, so every `_recompute_auras`, on every planner clone, folds the hand and allocates three dictionaries per card. No file under `tests/performance` names `modify_cost`, so the 500 ms planner target with a cost treasure is `NOT ASSESSED`.

**Verdict: APPROVED WITH SUGGESTIONS**

---

## Could not assess
- Any test result or mutant claim: nothing was run.
- End-to-end passive firing: no `src/` code builds a `MatchConfig`.
- Shipped treasures: 0 records.
- Performance guardrails.
- The two held C1.3 tests, which are not in the repo.
- Godot semantics `NOT SOURCEABLE` from `docs/engine-reference/godot/`: typed `Dictionary.get` on a wrong key type, `Array[Array].resize`, and calling an empty `Callable`.
