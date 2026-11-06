# Sprint 5 W2 review: effects and treasures

Reviewer: lead-programmer, independent. Repo `C:\dungeon-run-ccg`, branch `bootstrap/ccgs-template` at `f4aff0e`.
All ten commits are ancestors of `f4aff0e` (checked). Line numbers are at `f4aff0e`.

**Method limit.** Static review only. Godot was not run, so no test result here is observed. Every "a test would fail" is reasoned from the code.

Finding labels: **DEFECT**, **DESIGN QUESTION** (owner), **NIT**. Confidence: VERIFIED means I read the code and traced it myself. Specialist claims I did not confirm were dropped or are marked.

## Verdicts

| Item | Commit | Depth | Verdict |
|---|---|---|---|
| CE-014 value hook folds | `d9932c7` | Full | APPROVED WITH SUGGESTIONS |
| CE-013 transform, copy, bounce, treasure aura | `868ebe4` | Full | APPROVED WITH SUGGESTIONS |
| TR-003 treasure validator | `91c79e1` | Full | CHANGES REQUIRED (two ACs unmet, owner decision; the code itself is sound) |
| TR-003 Boot registration | `ee42d77` | Full | APPROVED |
| CE-017 silence before destroy | `52c7b5e` | Summary | No correctness or contract risk found |
| content-010 Gravekeeper | `9ad66b2` | Summary | No correctness risk; Torchbearer swap awaits owner sign-off |
| DD-X26 absolute values | `9528225` | Summary | No correctness risk in the commit; see gap Q2 |
| DD-X27 summon position | `58f1530` | Summary | No risk found |
| DD-X28 taxman fixture | `22e8c64` | Summary | No risk found |
| Hero power fix | `068e3bb` | Summary | No risk found |

## Blocking

**B1. DESIGN QUESTION. TR-003 AC-5(d) and AC-T7b cannot be met through a load.** VERIFIED.
- `src/core/data/record_schemas.gd:138` makes treasure `rarity` a stage-4 enum, so `legendary` is `E_BAD_ENUM` and never reaches `E_TR_RARITY`.
- `src/core/data/record_schemas.gd:326` (`_check_text`, line 336) requires `text.en`, so the record is `E_MISSING_FIELD` and the load is `Failed`, where AC-T7b wants `W_TR_TEXT` and `OK`.
- `tests/unit/treasures/treasures_validator_test.gd:137` and `:364` pin today's behaviour, which is the opposite of the AC wording.
- The story records this honestly and keeps Status Ready. It cannot close until the owner chooses: stage 4 stays the gate (reword AC-5, T7, AC-T7b), or stage 4 hands the fields to 7b (change `record_schemas.gd` and its pinned test). No `DD-X` row decides it.

No other finding blocks. Nothing below breaks shipped data or an AC clause.

## Requested interaction checks

**`aura_hosts` in a clone: keeps and isolates. VERIFIED.** `MatchState.clone` runs `effects.duplicate(true)` (`match_state.gd`), which deep-copies the array and its dictionaries. A clone's resolver binds with no installers and reads hosts from the copied state (`effect_resolver.gd:428`). The keep half is tested (`card_effects_transform_copy_test.gd:590`). The isolate half has **no test**: `aura_hosts` appears in the suite only in two field-list pins. See S3.

**`auras_recomputed` with treasure hosts: correct. VERIFIED.** Traced first recompute (no aura held, so `before` is taken lazily by `apply_enchantment`, `rules_engine.gd:1134`) and later recomputes (strip branch). A String `source_entity_id` is never passed through `int()`. Hero, weapon and hand entries project correctly for the five aura records in `treasures_v1.json`. Silent re-application holds (`rules_engine.gd:1147`).

**CE-014 folds: deterministic and replay-safe. VERIFIED.** No fold path draws: `EffectValues` reads pools, never the stream. No path writes state; `_memo` is derived data. `_fold_run` and `_fold_view` are per resolver and cannot re-enter: nothing under `matches` or `holds` reaches `fold`. The second fold in `_hook_delta` (`ops.gd:353`) sees the same inputs as the engine's. It passes a different `side` when a source has left play, but `side` is unread for damage and heal.

**MR-019 caches and hooks: unaffected. VERIFIED.** R1 skips only when no write happened, and a hook change is invisible to that diff with or without R1 (both sides fold the same state), so R1 adds no new loss. R2 hints are id-checked. R3: both new CE-013 movers bump `_zone_serial` (`transform` at `rules_engine.gd:1413`; `return_to_hand` via `_index_zone`). See Q2 for the gap that predates R1, and P1 for what is unmeasured.

**`retrigger` with self-transform: no crash, one wrong read. VERIFIED.** Two queued entries on one source resolve safely: the second finds `self` gone and is `no_target`. See D1.

## Non-blocking findings

### Defects (latent: no shipped card reaches them)

**D1. DEFECT. After a self-transform, a queued pass stops reading its snapshot.** `src/gameplay/effects/values.gd:181`. `reads_snapshot` tests `run_source(run)`, which `rebind_source` (`effect_resolver.gd:518`) has moved to the new body, so it finds an entity and returns false. A retriggered Deathrattle `[transform self, damage {ref: counter.seen}]` then reads the new body's empty bucket. C6.5 says live only "while the source is still the same `entity_id`". Comparing against `snapshot.source_id` fixes it. No test covers a snapshot pass that transforms itself.

**D2. DEFECT. A self-transformed minion observes its own entry.** `effect_resolver.gd:588` guards on `subject == source_id`, but `_fire_observers` (`rules_engine.gd:2446`) passes the stale `_frame.id`, so the new body is not skipped. This breaks the Edge Case at card-effects line 936 if the new body has an `on_summon` or `on_play` observer. The story's open note covers only `trigger_subject`, not this. The fix is in `rules_engine.gd`.

**D3. DEFECT. The view cannot show a bounce or a transform.** `src/ui/match/match_view_state.gd:347` removes a token on `returned_entity_id` carried by `card_added_to_hand`, and the engine never sends it: `return_to_hand` emits `minion_returned` (`rules_engine.gd:1377`), which the view does not handle. `minion_transformed` is unprojected too (known, MUI story 001 line 102). CE-013 makes both reachable. Fix before content ships these ops. No shipped card uses `transform`, `copy_to_hand` or `return_to_hand` (searched `assets/data`).

**D4. DEFECT, small. `is_dying` in a value filter crashes on a view.** `selectors.gd:490` calls `engine.health(view)`, and `rules_engine.gd:1710` reads `character.base_health`, which `_fill_view` lacks. Trigger: `scope.source: {is_dying: false}` with a spell or weapon source. The validator allows the predicate. No record uses it. Reject it under value triggers, or guard with `has("base_health")`.

### Design questions for the owner

**Q1. Does an absent `side` in a value filter mean owner, or anyone?** `scope.gd:141` and `:157` apply no default, so a treasure with `card: {type: spell}` also discounts boss cards, and absent `who` reads `any`. ADR-0005 rule 3 says a plain discount "touches only its owner's cards". Every authored record states `side` explicitly, so nothing is wrong today, but the wrong authoring fails silently. Default it, or make the validator require it. ADR DRIFT (warning).

**Q2. How does a non-aura cost hook reach the view? (raised by CE-014, confirmed).** VERIFIED: `match_view_state.gd:576` is the only writer of `effective_cost` and it fires only on an `auras_recomputed` entry. `_recompute_auras` compares two reads of one state, so a hook change never appears. Treasures rates the discount display **Must**, and treasures AC-8 and AC-17 say "displayed" and "shows". Neither can be met from the log, so **decide this before treasures-005 in W3**. The hero-power button has the same gap.

**Q3. Torchbearer deck swap** goes beyond DD-X20's three decks. Owner sign-off is outstanding (content-010 notes).

**Q4. W_TR_POWER** stays unchecked pending story 013; the doc comment and a test say so. No action unless that changes.

### Nits

- **N1.** `docs/architecture/control-manifest.md:170` and the doc comment at `match_state.gd:187` still list four `EffectRuntime` fields. The manifest needs regenerating.
- **N2.** A retrigger pass with `[retrigger self, transform self]` then summons at the snapshot slot, left of the live new body. C5 does not cover it.
- **N3.** TR-003's story header and AC boxes still read Ready and unchecked though AC-REG is met at `ee42d77`.
- **N4.** `int(run_ctx.source_id)` at `ops.gd:638`, `:725` and `:736` is unreachable today (`run_hook_effect` is a stub), but `:622` reads a treasure's counter under its String id while `:638` writes under `int()` of it. CE-015 must use `run_source` or the id itself here.
- **N5.** `treasures_invalid/` copies 20+ shipped data files and will drift.

## ADR compliance

| ADR | Result |
|---|---|
| ADR-0002 | COMPLIANT. Stage-7b convention kept; no `config()` in stage 7; `db` used through `has` and `card`. The third `balance` argument is a recorded, story-requested deviation. |
| ADR-0005 | DRIFT. Rule 4 "allocates nothing": no authored record builds a container, but legal data does. `who: friendly` reaches `EffectSelectors.find` (`scope.gd:295`), contradicting the comment at `scope.gd:167`; `add` etc. build `args` (`values.gd:48`); single-string `has_keyword` builds an array (`selectors.gd:467`). `ref()` allocates temporary strings (`values.gd:84`) on every condition. Rule 3: see Q1. |
| ADR-0007 | COMPLIANT. All writes go through primitives; `aura_hosts` has a dated erratum and C6.8 note. |

## Standards and architecture

- **Standards: 5/6.** Doc comments, injection, data-driven values and interfaces hold. `Treasures` vocabularies are format knowledge, as the story allows. `_op_summon` and `matches` exceed the complexity bar but predate these commits.
- **Architecture: MINOR ISSUES.** D2 and D3 sit across the engine and view boundary.
- **SOLID: COMPLIANT.**
- **Engine specialist: ISSUES FOUND, reduced after checking.** The specialist hit its turn limit and reported from what it had traced; I covered what it did not reach (filter rules, `_tail` rebind, tag inputs). Its `self` digit-read claim is **dropped**: the validator rejects `self` on treasure and passive hosts (`effect_validator.gd:454`). `is_dying` is kept as D4; its `ops.gd` claim is kept as N4.

## Testability: GAPS

The test files are strong overall and their mutation records are credible, but those runs are the authors' claims; I could not repeat them. Gaps confirmed by reading:

- **S1.** No `E_TR_*` error is shown failing a load on its own. `treasures_validator_test.gd:110` asserts `FAILED`, but that root also holds stage-4 faults that force it. `:183` and `:237` are named `..._fail_a_real_load` and assert no state. Add a single-fault root through `RootOverlayLoader`.
- **S2.** `card_effects_value_hooks_test.gd:389`: no test has a condition that reads `context.value` and is true, so moving `run.value = value` (`effect_resolver.gd:490`) below `holds` survives.
- **S3.** No clone isolation test for `aura_hosts`. Add one: change the clone's copy, assert the live one is unchanged.
- **S4.** No test routes a treasure aura through `Treasures.installers_for`; `_treasure()` at `card_effects_transform_copy_test.gd:178` hand-builds the installer. treasures-008 (stretch) would cover it.
- **S5.** `test_ac31_counters_read_zero_when_the_bounced_minion_is_replayed` (`:464`) passes on any new id, so its claim is weak. `:452` carries the real assertion.

## Performance

**P1. NOT ASSESSED.** Neither figure covers the merged code:
- The 12-entry fold guardrail is measured against `TestEffectResolver` (`tests/performance/match_rules/match_rules_fold_perf_test.gd:29`), not `apply_value_hook`. The 19 µs in `production/qa/perf-match-rules-2026-11-05.md:14` is not the real evaluator.
- That record was taken at `17efca2`, which contains neither CE-013 nor CE-014 (checked with `git merge-base`). With any aura host, R1 no longer skips, so each drain pays two stat passes. The 340 µs gate has not been seen with a treasure aura or real hooks installed.

Re-run on trunk with real hooks and one aura host before MR-019's numbers are relied on.

## Positive observations

- `rebind_source` handles the `_tail` correctly across suspension and resume.
- `hook_delta` keeps the log shape identical when no hook fires, so goldens are safe.
- `run_source` removes a real digit-read bug class in the selector paths.
- The validator's "absent cap is one `E_DELEGATED`, never a check against nothing" follows the no-silent-pass rule.
- CE-017's arm and repeat walk matches C10, and `_collect_op_names` covers nested ops.
- TR-003's notes state the blocker plainly rather than claiming the ACs.

## Summary review notes

- **CE-017:** arms copied then merged, repeat walked twice, `target` folded into `chosen`, dedupe by reference and path. Matches C5 and C10. No new code.
- **content-010:** all four changed decks have 30 cards and 2 Gravekeeper (counted). `effects[]` matches C11 row 45. `text.en` differs from row 45 for the 90-character limit, recorded. `boss_rot_warden` holds one card at 3 copies, not touched by this commit, and I did not check whether that is allowed.
- **DD-X26:** absolute replace is idempotent; boss hand stays out of the log. Traced in engine and view.
- **DD-X27:** `index + placed + 1`; the departed-source path is unchanged.
- **DD-X28:** fixture only; agrees with `_card_in` under CE-014.
- **Hero power fix:** list and `submit` agree; `HERO_POWER_USED` reuse is documented in match-rules C7.

## Could not assess

- Any runtime result: tests, the golden logs on merged trunk, perf.
- Whether the authors' mutation runs happened as recorded.
- GDScript behaviour not in `docs/engine-reference/`, such as whether a Dictionary literal in `entity()` is folded to a constant (NOT SOURCEABLE).
- Full-review depth on the summary items: their tests were read only by name or diff.
- `boss_pressure` F4 recompute for content-010, which needs a run.
