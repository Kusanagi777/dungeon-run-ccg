# Sprint 5 M1 code review: heroes 001-004, treasures 001 and 009

Reviewer: lead-programmer, independent. Date 2026-11-04. Branch `bootstrap/ccgs-template` at `8e21d44`.
Method: `.claude/skills/code-review/SKILL.md` by hand. Read-only.

## Verdicts

| Story | Scope | Verdict |
|---|---|---|
| heroes 001 (`cbd192b`) | Full | **CHANGES REQUIRED** |
| treasures 001 (`2151c68`) | Full | **APPROVED WITH SUGGESTIONS** |
| heroes 002 (`4f8bf5f`) | Summary | APPROVED WITH SUGGESTIONS |
| heroes 003 (`c1d5288`) | Summary | APPROVED WITH SUGGESTIONS |
| heroes 004 (`067aa0c`, `8e21d44`) | Summary | APPROVED WITH SUGGESTIONS |
| treasures 009 (`e41d79e`) | Summary | APPROVED WITH SUGGESTIONS |

Summary verdicts cover correctness and contract risk only. Architecture and SOLID were not assessed for those four.

Two findings outside these diffs gate M3, and one design question gates treasures 002 and 005. See "Cross-story items".

## What was not assessed

- **No test was run.** Godot was out of bounds. Every "passing" and "seen failing" claim in the stories is the authors', unverified. Mutation results below are by inspection.
- **`docs/engine-reference/` facts**: String versus StringName keys in Dictionary and typed-`for` conversion are NOT SOURCEABLE there. Both are low risk and no finding depends on them.
- **Runtime crash claims** (typed-local null assignment, debug asserts) are read from source, not observed.
- **Shipped-data half of treasures AC-MVP**: NOT ASSESSED. `assets/data/treasures.json` has 0 records until content 006 (the QA plan says so too).
- **Value-hook behaviour of the taxman**: `apply_value_hook` is a pass-through until CE-014, so cost outcomes are derived from the rules, not observed.

---

## Cross-story items

### X1. Defect, pre-existing: a side with no hero power is offered a paid no-op
`src/gameplay/match/rules_engine.gd:630-633` lists `use_hero_power` whenever the power is unused and affordable. It never checks that `def_id` is set. `_validate_hero_power` (:1965) does not check either. For `def_id == ""`, `_memo_entry` yields no effects and `derive_targeting_spec([])` no `chosen` spec, so the target list is `[null]` and the command is accepted: 2 mana spent, `hero_power_used{power_id: ""}`, nothing happens.

Reached by:
- **Every MVP boss.** All five have `hero_power: null` and `start` leaves `def_id` empty (pinned by `test_the_boss_hero_still_seats_from_the_config_health`). From 2 mana the boss can burn mana. Profiles with `hero_power: always` score it up (`scorer.gd:414`, `candidates.gd:235`).
- **`src/ai/candidates.gd:162`** calls `_db.hero_power("")` with no `has` guard. `_record` then goes to `_report_caller_bug(..., true)`, an assert in a debug build, when the pre-filter ranks candidates (`candidates.gd:110`). `lethal_search.gd:196,306` take the same route through `_power`.
- **The heroes 001 fallback**, which its Completion Notes call "unspecified".

Not introduced by `cbd192b`, but story 001 names BAI-016 real-data runs and the First Playable War match as what it unlocks. Those are where this bites. Confidence: VERIFIED by reading the path; not executed. Fix belongs to match-rules (a `def_id` guard in `legal_commands` and `_validate_hero_power`), with C7 stating the rule.

### X2. Defect, pre-existing: 3 of 5 shipped boss passives install nothing
`src/gameplay/match/hook_registry.gd:95` keys on the raw `trigger` and silently skips what is not a hook point. `turn_start` and `turn_end` are not; C2 binds them to `on_turn_start` and `on_turn_end`. Shipped: `boss_torchbearer` (`turn_end`, band 1, the batch-0 First Playable boss), `boss_rat_king` and `boss_hollow_king` (`turn_start`). Treasures Candle, Mending Charm and Cloak are the same.

The registry's doc comment treats a skipped trigger as a deliberate hook-less observer, so the drop looks intentional. Treasures 001's notes record this for CE-015, but `production/epics/card-effects/story-015-*.md` line 47 only says "event trigger with a hook column -> `install`", with no rename. The QA plan's AC-16 row words the treasure as `on_turn_start`, so a fixture written that way would pass while T8's `turn_start` stays broken. Carry the mapping into CE-015's ACs and test it on a shipped passive. Confidence: VERIFIED.

### X3. Design question for the owner: which side does `boss_test_taxman` tax?
Treasures GDD preamble and story AC-T3.1 say "friendly"; T2.4 makes that the boss's own cards. AC-2 and AC-16 need the player's hero power at 2, which needs `side: enemy` (card-effects row 36). The two cannot both hold. The fixture (`tests/helpers/treasure_fixtures.gd:83-90`) follows the story, so treasures 002 AC-2 and 005 AC-16 will read 1.

This is not a treasures 001 defect, and the author flagged it well. But the question lives only in a closed story's notes: not in stories 002 or 005, and not in the QA plan's "GDD and story contradictions" table. Reviewer's lean: `enemy`, since the numeric ACs and the name state the intent and only a preamble phrase disagrees. Owner decides before treasures 002 starts.

### X4. Design question: unknown `hero_def_id`
Fall back or fail the match? C3 covers health only. Story and QA plan both flag it. Needs a C3 line.

---

## Code Review: heroes 001, War hero seated from `HeroDef`

### Engine Specialist Findings: ISSUES FOUND
`godot-gdscript-specialist` ran. One finding held up for this story:
- **S1 (defect, low, VERIFIED)** `rules_engine.gd:471`. `has` is true for any record type (`card_database.gd`, "any type"), and `hero()` then fails on type. With `hero_def_id = "war_rusted_axe"` the guard passes and `_record` asserts in a debug build; the intended logged fallback never runs. In release it does reach the fallback. The comment at :469 says `has` prevents exactly this. No current producer sends such an id.

### Testability: GAPS
`qa-tester` ran; findings checked below.
- **T1 (defect, test gap, VERIFIED, REQUIRED)** AC-1 says the power is "read from the record". All heroes under test use `power_whetstone`, and it is the only power in either root (confirmed: fixture `heroes.json` and `hero_powers.json`). Replacing `str(hero_def.hero_power)` at `rules_engine.gd:478` with the literal passes all 14 tests. The test file's own header explains that 27 health exists because 30 cannot tell record from knob; the power has the same blind spot and no equivalent fixture. The 3 mutants in "Seen failing" do not cover it.
- **T2 (suggestion)** AC-8 (`heroes_war_match_seating_test.gd:269-291`) never asserts durability stays 2 or that no `weapon_equipped` fires. A Whetstone that also adds durability survives.
- **T3 (nit)** "Read once, never per command" has no test; acceptable, the read is plainly in `start`.
- Sound: 27/27 seating, knob versus record, boss health, unknown-id fallback, null-`db` seam, AC-7, cost from the rule, Frozen, Windfury, weapon over Blade, fourth hero on a `fortune` set. All QA plan rows have a test; the regression row is a procedure I could not run.
- Checked and true: fixture `power_whetstone` and `war_whetstone_blade` are the shipped records verbatim.

### ADR Compliance: COMPLIANT
ADR-0002 and ADR-0007. The record is read once and never written; cost stays `rule("hero_power_cost")` through the fold. AC-19: no hero id or hero value literal under `src/` (grep of non-comment code).

### Standards Compliance: 5/6
- `start` (`rules_engine.gd:453`) is now about 47 lines, over the 40-line limit, and this story's lines pushed it over. Extract `_seat_heroes(config)` (nit).

### Architecture: CLEAN
The cross-epic edit stays inside `start` and its doc comment, as the story scoped it.

### SOLID: COMPLIANT

### Game-Specific Concerns
- 460 `no HeroDef` errors per suite run, doubling output (author's figure), hide real errors. Worth seating null-`db` engines quietly (nit).

### Positive Observations
The story is honest about its gaps and about the second-turn deviation. The knob-versus-record test is exactly the right instinct, and the QA plan's Edge Case rows were all picked up.

### Required Changes
1. **T1**: add a fixture hero with a second `HeroPowerDef` and assert `def_id` equals that id. AC-1's power half is otherwise unproven.

### Suggestions
S1 (a type-aware check, shared with heroes 002); T2; the `start` extraction.

### Verdict: CHANGES REQUIRED

---

## Code Review: treasures 001, installers, passive, `collect_state`

### Engine Specialist Findings: ISSUES FOUND
- **S2 (defect, low, inferred, not run)** `treasures.gd:58` and `:66`. `by_treasure` is type-checked by nothing: `{schema_version: 1, by_treasure: null}` fails the typed assignment, and a non-Dictionary entry fails `host_state: Dictionary`. The code handles a hand-edited `schema_version` and has a test saying so, but not this. Run Structure treats the blob as opaque, so nothing upstream catches it. GDD: reset, never crash, is the pattern.
- Dropped after checking: StringName-in-loop and key concerns (NOT SOURCEABLE, no producer); fixture failure-path behaviour (test helper only).

### Testability: TESTABLE
All 4 ACs and all QA rows have tests that bite. The AC-4 and AC-10 channel is the recorded `installer_warnings`, as the QA plan directs.
- `test_the_taxman_fixture_adds_one_to_cards_and_the_hero_power` (`treasures_installers_test.gd:399-406`) does not pin `side`, so a side flip survives; deliberate, pending X3. Pin it once decided.
- `installers_for` and `installer_warnings` run separate dedupe loops, and no test ties them together or covers `[S, S, S]` (suggestion).
- No test runs `passive_installer` over shipped `bosses.json`, which is the story's First Playable claim and would have exposed X2 at the entry count (suggestion).
- `_named_in_code` cuts at any `#`, including inside a string (nit). "No event" is proven only by that scan; adequate, as the class holds no log.
- `test_collect_state_does_not_depend_on_the_match_result` is weak alone; the shape test carries it (nit).

### ADR Compliance: DRIFT
ADR-0005, Key Interfaces, rules 2, 3, 5, 8, 10.
- **MINOR DEVIATION** `collect_state(_hooks, _result: Dictionary)` (`treasures.gd:90`): the ADR types `result: MatchResult`, a class that does not exist (grep confirmed), so `Dictionary` is correct. The ADR needs an erratum.
- **MINOR DEVIATION** it does not read `hooks.hosts()`. Rule 8 calls that its input, but v1 is a constant; fine until a treasure persists state.
- `installer_warnings` is an addition the story explicitly allowed. It emits flat `{code, treasure_id}` where rng-event-log's catalogue says `code, detail{}`; story 011 must settle it.
- All other signatures match. Purity, pick order, first-kept, side and `[passive]` wrap confirmed.

### Standards Compliance: 6/6

### Architecture: CLEAN
No RunState, log, RNG or Node. Warnings via a pure helper keeps `installers_for` stateless, a good call.

### SOLID: COMPLIANT
Minor: the dedupe rule exists twice (see Testability).

### Game-Specific Concerns
A saved state with an unknown version is re-reported at every `begin_match` until `collect_state` rewrites it; a repeated id is re-reported every match. AC-4 and AC-10 say "one". Story 011 should decide when to log.

### Positive Observations
`treasures_v1.json` matches T8 and T9 on all 20 records (ids, rarity, tags, effects, unlock keys and M10 conditions; compared by hand), and `MVP_IDS` matches T8's column. The JSON float `schema_version` case was anticipated. Notes for later stories are the best in the batch.

### Required Changes
None in this story.

### Suggestions
S2; one shared dedupe; a shipped-passive test; ADR-0005 erratum for `MatchResult`.

### Verdict: APPROVED WITH SUGGESTIONS
(X2 and X3 must be carried forward. Neither is this story's to fix.)

---

## Summary reviews

### heroes 002: APPROVED WITH SUGGESTIONS
- **Defect, low, VERIFIED** `heroes.gd:108-111`. Same type-blind `has`: `plan_tags("war_iron_axe")` passes the guard, `hero()` asserts in debug and `.set` hits null. The doc comment at :102-103 promises "never an assert". Test covers only an absent id.
- `launch_heroes`, `hero`, config read once: correct. Unlock state correctly left out.

### heroes 003: APPROVED WITH SUGGESTIONS
- F2 and F5 are correct. Recomputed from shipped JSON independently: War 7; 17, 19, 19. All match the pinned tests.
- **Nit** `synergy` (`:157-171`) has no guard, so an unknown id is a runtime error. Fine for a design-time check, but say so in the doc.
- **Design question (raised by the author, stands)**: F2 and F5 have no report code and no signature marker, so nothing runs them in `validate.gd`.

### heroes 004: APPROVED WITH SUGGESTIONS
- All six safe ranges match heroes.md Tuning Knobs. Key list matches the shipped body. "Exactly one entry" holds for pairs. Bools are rejected; JSON floats accepted for ints.
- Boot: registration and pending list correct, in one commit. Remaining pending list matches the QA plan. `boot_validator_map_test` and the derived count in `boot_composition_test.gd:166-168` would both fail if it regressed.
- Fixture `heroes_balance.json` in both roots equals shipped (checked).
- **Design question, low**: `_check_set_map` (`:312`) accepts a body with no row for a hero that exists. Delete `plan_tags.war` and the load passes, then `plan_tags("hero_war")` logs and returns `[]`, so Reward Draft loses affinity silently. `_db` is unused here.

### treasures 009: APPROVED WITH SUGGESTIONS
- `pool` (`treasures.gd:104`) matches ADR-0005 rule 10 and Key Interfaces exactly. `unlock` is a required field, so `def.unlock` is safe. AC-11 revoked-unlock case is tested.
- **Contract risk**: `MetaApi.unlocked_keys()` returns Array, `pool` takes a Dictionary set, and meta-progression says Set. Noted in the doc comment; the first caller must convert. No caller exists yet.
- **Nit** story ACs still say "ids" while code and ADR return records. Correct the story wording.
- Shipped-data AC-MVP: NOT ASSESSED (see above).

---

## Specialist claims not carried forward
`Heroes._init` null `config` on a non-READY db and `_shares_a_tag` on an unknown card id: real only on caller misuse or data the loader already rejects. Dropped. `heroes_war_match_seating_test.gd:165` (default value) and shipped 30 equal to the knob: true but covered by the 27-health fixture. Not findings.
