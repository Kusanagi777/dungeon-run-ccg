# Sprint 5 M1 code review: CE-009 and the L7 W1 fix buffer

Reviewer: lead-programmer, independent, 2026-11-04. Read-only: Godot was not run and nothing was edited, committed or merged in the repo.

| Item | Scope | Verdict |
|---|---|---|
| card-effects 009, `s5/l5-w1` (`5293b1b`) | Full | **APPROVED WITH SUGGESTIONS** |
| L7 W1 fix buffer, `s5/l7-w1` (`33d7bb1`..`f772991`) | Summary, extra care on S5 `retrigger` | **CHANGES REQUIRED** (one item, R1) |

**The one blocking finding is a merge hazard, not a defect in either branch alone.** Both branches merge cleanly as text, but the merged tree fails L7's own test until `EffectOps.run` gets a guard that neither branch contains.

## What this review rests on

- **Merged reading.** I built a three-way text merge of `effect_resolver.gd`, `ops.gd`, `rules_engine.gd`, `values.gd` and `selectors.gd` with `git merge-file` in the scratchpad (trunk, then L5, then L7). There were no conflicts. "merged" line numbers below refer to those files. Other line numbers are on the named branch.
- **Trunk moved during the review.** It went from `8e21d44` to `f96fc04` (lane 1, BAI-007 and 008). That merge touches `src/ai`, tests and docs, and none of the five files above, so the simulation still holds.
- **Specialists.** `godot-gdscript-specialist` and `qa-tester` both ran. I checked every finding of theirs that I report here against the code, unless it is marked UNVERIFIED.
- **Side effect to know about.** The `qa-tester` agent ran `git merge-tree`, which left dangling objects in `.git`, despite the read-only brief. `git fsck` shows dangling trees. Refs, branches and the working tree are untouched, and `git gc` will drop them.

## Could not assess

- **No test was run.** The story's "1442 cases, 0 failures" and its seen-failing and mutant tables are claims I could not reproduce. Every "red" or "green" below comes from reading the code.
- **The merged tree has never been executed.** Runtime behaviour after both merges is traced by hand.
- **Lane 1's new Boss AI tests against either branch.** See M3.
- **T1 and T2 tests (fix buffer):** I read the commits, not the test bodies. The `qa-tester` raised nothing on them.
- **`card-effects C13` does not exist.** That GDD stops at C11. I read match-rules C13, plus card-effects C3, C4, C5, C6, C7, C9 and C10 and its Edge Cases.

---

# Part 1: Code Review: card-effects 009

### Engine Specialist Findings: ISSUES FOUND (minor)

`godot-gdscript-specialist` found no parse, typing or shadowing problem. Its null-deref finding is R1 below. Its smaller points are S1, S2 and the fix buffer nits.

- `Array.find` on Dictionary elements compares by value, and `entity_id` keeps records distinct, so no wrong match occurs. UNVERIFIED against `docs/engine-reference/godot/`, which does not cover it; the specialist states it from general GDScript semantics.

### Testability: GAPS

**Acceptance criteria, against what code and tests do:**

| AC | Met | Evidence |
|---|---|---|
| AC-19 | Yes | `_claim_once` runs after `_responds`, so a scope mismatch spends nothing. Tests pin the key, the second source and the new turn. |
| AC-20 | Yes | `_death_check` copies the minion before auras are stripped; the test uses the real aura. |
| AC-21 | Yes | Real resolver, Deathrattle from the definition, so the `silenced` trap is actually exercised. |
| Match-rules AC-46 | Yes | Log order, `silence` then `destroy`, and lethal then `silence` are all pinned. |
| AC-46 | Yes | Values, `read_from` and the bounce reset are asserted. |

Option (b), narrowed to a `deathrattles_kept` marker, is the right call: reading `pending_destroy` alone would fire on `silence` then `destroy`. The GDD's C13 step 2 and DD-X21 are honoured.

**Weak or missing coverage (none of it blocks):**

- `test_ac46_a_deathrattle_granted_by_an_enchantment_is_kept_and_the_enchantment_goes`: the effect that fires is DR_TWO's printed one, so the test proves a keyword survives, not that a granted Deathrattle fires. The story's advisory says so honestly; the QA plan row reads stronger than that. v1 has no granted Deathrattle effect, so this is acceptable for now.
- `test_a_clone_carries_marks_and_counters_and_its_writes_leave_the_original`: the mark is already spent, so the sandbox never writes one, and `assert_dict(... once_marks).is_equal(marks)` cannot fail. Isolation is proved for counters only. Give the clone an unspent mark.
- Untested: `destroy`, `silence`, `silence` (see N1), and a Poisonous hit then Silence. Poison sets `pending_destroy`, so the Deathrattle is kept. That matches C13's letter, but no test pins it.

### ADR Compliance: COMPLIANT

ADR-0007 Decisions 1 and 5: `EffectRuntime` stays plain data, marks emit nothing, `counter_changed` goes through `engine.emit`, Q stays the engine's. The G7 pattern gives 0 hits on the merged effects tree and on L5's `effect_runtime.gd`. A planted control scored 4 of 4, so the run is real.

### Standards Compliance: 6/6 passing

`_write_counter` emitting from `ops.gd` is sanctioned by Decision 6, and the file header records it.

### Architecture: MINOR ISSUES

`deathrattles_kept` is a new minion field that match-rules C1 and States do not list (`pending_destroy` is in States, line 643). Add a line.

### SOLID: COMPLIANT

### Game-Specific Concerns

- **S1. The Readiness note overstates the performance result.** It says the snapshot "replaces the whole-record deep copy". `_enqueue` still runs `live.duplicate(true)` (merged `rules_engine:2911`) and then discards it, because the entry already has a snapshot. Each queue entry now costs the old copy plus the C6.5 build, plus an `Array.find` that runs even when `position` exists (`values.gd:165`, default argument evaluated eagerly). It is small, but nobody measured it. Copy only when the entry has no snapshot.
- **S2. `run.snapshot.counters` is unguarded** (`values.gd:100`). An engine-filled whole-record snapshot has no `counters`. Only a hand-built entry reaches this today.

### Positive Observations

- Option (b) narrowed well; the Silence-first guard is exactly what stops `silence`, `destroy`, `silence` from reviving a stripped Deathrattle.
- The snapshot test pins the exact C6.5 field list and asserts JSON representability.
- The advisories are candid, including the `has_trigger` question left for L7.
- The `_summon_index` rework correctly falls back to the rightmost slot when the former index is past the board end (match-rules Edge Cases).

### Required Changes

None against this branch alone. R1 (Part 3) changes lines CE-009 adds, and may land here or in L7's rebase.

### Suggestions

- **N1 (nit).** `destroy`, `silence`, `silence`: the second Silence clears the kept keyword and logs `deathrattle` in `removed_keywords` (`rules_engine.gd:1151`, `1166`), yet the Deathrattle still fires because `deathrattles_kept` stays set. The behaviour is right and the log is wrong. Fixture-only, since content cannot ship this order once CE-017 lands.
- **N2 (nit, CE-015 watch).** `_write_counter` forces `int(run_ctx.source_id)` (`ops.gd:475`) and `_claim_once` types it `int`, while the `EffectRuntime` helpers take a `Variant` and C9 keys these by "the treasure or passive id". If story 015 passes a non-integer id, buckets collapse. UNVERIFIED: story 015 decides the id's type.
- **N3 (nit).** `TestEffectResolver` does not honour `deathrattles_kept`, so a test on the double would see no Deathrattle. Already noted in the story.
- **N4 (out of scope, noted).** `trigger_subject.*` on a departed subject reads 0, where C3 says it reads the snapshot. No shipped record uses such a ref (grep of `assets/data`).
- Also S1, S2 and the two test fixes above.

### Verdict: APPROVED WITH SUGGESTIONS

---

# Part 2: Code Review: L7 W1 fix buffer (summary)

| Item | Result |
|---|---|
| S5 `retrigger` | Meets the C5 row. NC-1 runs on shipped data through the real resolver and asserts `reason`. See D1, D2, H1. |
| S1 `event_cap` | Sound on the L7 tree. The sweep asserts `effects.pending_choice` too, and `unbind` clears that. R1 is the one gap, and L7 predicted it. |
| S2 / DD-X25 | Done. Tested on card, treasure and passive hosts, and all three GDD sites plus the manifest are updated. |
| S4 `hand` selector | Done. `entities()` and `pick_count` now share `_picks`. No shipped record uses `hand` with `n`. |
| X1 / G7 | Done. The pattern is verbatim from ADR-0007 (string compare), and 0 hits on the merged tree. |
| T1, T2 | Commits cite the mutants; tests not read by me. |
| Records | 13 stories carry the verdict (the 14th, CE-006, is the G7 note). N7 is in CE-009's Readiness. |
| BAI S3 docs | ADR erratum and TD-014 present. |

### Engine Specialist Findings: ISSUES FOUND (R1; one nit)

- **N5 (nit).** `_op_retrigger` reads `run_ctx.resolver` with no guard (`ops.gd:421`), unlike `_scales`. Production always sets it.

### Testability: GAPS

No test covers: retrigger on a Silenced `pending_destroy` minion (H1), retrigger of a `once_per_turn` Deathrattle (D3), a `count: 2` `source_slot` summon with the source in play (D1), or a retriggered Gravekeeper reading its counter (the QA plan's optional case). The code path reads live, which is right.

`choices_test.gd:907-908` and `933-934`: `effect_resolved`, `damage_dealt` and `discover_picked` counts cannot fail after a cap, because `emit` is sealed once Ended. The `hand_before` assertion is the real one. Null-guard mutants die only through gdUnit's error monitor (`GodotGdErrorMonitor`), which the sweep depends on. `project.godot` holds no override, but I did not run it.

### ADR Compliance: COMPLIANT (minor drift)

`queue_triggers` is in the ADR erratum but not in the control manifest. ADR Consequences say the manifest must restrict engine-surface additions by directory.

### Standards Compliance: 6/6 passing

### Architecture: CLEAN. SOLID: COMPLIANT

`queue_triggers` keeps Q engine-owned. `retrigger_entries` reusing `_collect` is the right shape, and is also the cause of H1.

### Game-Specific Concerns

Mass Rites is live on a Boss AI clone: the clone test covers isolation. `op_values.retrigger` is unchanged.

### Positive Observations

- The S1 sweep found three sites the sprint-4 review missed, and runs on the production `EventLog`.
- L7 wrote the test that exposes R1 before CE-009 landed, and said so in the commit message.
- G7 has a planted fixture per alternative.

### Required Changes

R1, below.

### Suggestions

H1, N5, add `queue_triggers` to the manifest, resolve D1 to D3.

### Verdict: CHANGES REQUIRED

---

# Part 3: Interaction of the two branches

### R1: merge hazard, BLOCKING at M1

**`EffectOps.run` dereferences an unbound resolver when an op hits the event cap on a queued pass.**

- `s5/l5-w1` `src/gameplay/effects/ops.gd:165-169` (merged 170-174) calls `EffectValues.read_origin` **after** the handler returns.
- That reaches `src/gameplay/effects/values.gd:181`, `resolver.bound_engine().state()`.
- Trace: a Deathrattle with `amount: {ref: source.attack}`; the handler's `damage_dealt` hits the cap; `emit` faults; `_end_match` unbinds; `bound_engine()` is null; `.state()` on null.
- Conditions: the op has a `source.*` or `counter.*` value, and the pass has a snapshot. A play pass returns early at `values.gd:178`. `add_counter` and `set_counter` hit it the same way. `retrigger` does not: it has no value param.
- Consequence: `test_event_cap_sweep_over_a_queued_source_ref_op_touches_nothing_after_the_cap` goes red once L7 lands. Commit `e612dcd` expects this. **Neither branch has the guard**, and the sprint plan requires a green suite after each merge.
- Fix: work out `read_from` **before** the handler runs, which removes the deref and records the state the value was actually read in. Or guard on `bound_engine() != null`. Do it in CE-009 before it merges, or in L7's rebase.

### H1: merge hazard, not blocking

**`retrigger` answers for a Silenced minion that kept its Deathrattle.** `retrigger_entries` passes the live record as `ctx.snapshot` (`effect_resolver.gd:631` on L7). After CE-009, `_candidate_host` sees `deathrattles_kept` (`s5/l5-w1` `effect_resolver.gd:547`) and returns before the `silenced` check. So `[destroy, silence, retrigger]` on `chosen` queues the Deathrattle, and it fires again at the death check.

- This contradicts C3 ("live (unsilenced)"), `has_trigger`, and L7's own doc on `_op_retrigger`.
- CE-009's notes asked L7 to check this. L7 predates it.
- Unreachable on shipped data: Mass Rites uses `all_friendly_minions`, which excludes dying minions, and it is the only `retrigger` in `assets/data`.
- Fix: return `[]` from `retrigger_entries` for a `silenced` target, and add a test.

### M3: merge hazard, watch item

CE-009 changes a Deathrattle `summon` with no `position` from `end` to the former slot. `tests/fixtures/boss_ai/deathrattle_taunt_divergence.json` (`bai_bomb`), newly on trunk, relies on that default. The test asserts Taunt and the abort, not board order, so I expect it to hold, but I could not confirm it. The planned full suite after L5 settles it.

### Traced clean

- All other post-cap paths on the merged tree: `_op_retrigger` phase guard, `_enqueue`, `_queue_deathrattle`, `_raise`, `_collect`, `_claim_once` in `_run_play_from`.
- A retrigger entry's snapshot is a C6.5 value copy, with no aliasing of the live record.
- `test_a_retriggered_source_that_dies_first_still_resolves_from_its_snapshot` traces to 8 on the merged code.
- No L7 test asserts `values.position`, snapshot fields or a full `trigger_queued` payload.

### Design questions for the owner

The QA plan asked for these to be confirmed with game-designer **before** the op was written. They were recorded in content story 004 instead.

- **D1. Where does a `source_slot` summon land while its source is in play?** Today the Husk goes in at the Zombie's index, so three Zombies become `H Z H Z H Z`. A `count: 2` splits around the source, `[copy, source, copy]`, because `_summon_index` re-reads the source's index after the first insert (`ops.gd:572`, `576` on L5). Card-effects row 9 is that shape; no shipped card is. **Decide before MR-019 records its goldens on the M1 trunk,** if any golden covers Mass Rites.
- **D2. Is a mixed board `partial`?** That is the current behaviour, unpinned.
- **D3. Does retrigger spend `once_per_turn`?** Today it does: a real death later that turn is dropped, and a repeat reports `no_such_trigger` for a minion that has one. No shipped record uses this.
