# Code Review: sprint-4 stories that had no independent `/code-review`

**Date**: 2026-11-04. **Reviewer**: independent session. I followed `/code-review` by hand from `.claude/skills/code-review/SKILL.md`, because the skill cannot be model-invoked.

**Branch / HEAD**: `bootstrap/ccgs-template` @ `fca8476`.

**Standing approval**: the owner gave it. I asked no questions. I edited no source, test, data or story file, and I committed nothing. All probes and mutants ran in the scratch snapshot `scratchpad/rv4e_snap/` (`git archive HEAD`). After every mutant run, `cmp` against the repo was clean.

## Scope: how the list was confirmed

I took every sprint-4 story in `production/sprint-status.yaml` and read its story file for a "Reviewed by … `/code-review`" line. The stories with no such line are exactly the expected list:

| Story | Commit(s) | Merge |
|---|---|---|
| card-effects 010 Discover / Choose One | `bddd5a5` | `d5b81b1` |
| card-effects 012 auras, enchantments | `4127556` | `73074e1` |
| card-effects 007 values, selectors, Spell Damage | `a87b174` | `19c3752` |
| card-effects 008 observers, queueing | `71d7842` | `19c3752` |
| card-effects 011 hero powers | `02a5fa9` | `9f28bb9` |
| card-database 009 load / memory budget | `edee1e3` | `5b034ea` |
| boot-composition-root 007 Boot responsibilities | `08f851c` | `5b034ea` |
| content 002 War set | `48106a4` | `c9cd55b` |
| content 003 Rat King, Gatekeeper | `6000835` | `c9cd55b` |
| content 004 Rot Warden, Hollow King | `2df50d1` | `fc53d35` |
| content 005 bundles | `28819aa` | `fc53d35` |
| content 008 F1–F5 budget checks | `442f408` | `b1c714e` |
| match-rules 018 perf harness (story In Progress) | `dfc4ed4` | `d079e03` |

Excluded:

- MR-011…017 already have independent reviews.
- BAI-004, 005 and 006 already have independent reviews. BAI-005's line is "self … · `/code-review 2026-11-04 (independent …)`".
- CE-009 and CE-014 were not started.

## Inputs

| Input | Status |
|---|---|
| Story files (ACs, notes, deviations) | FOUND |
| card-effects GDD, read by section: C7, C8, F2–F4, C3 selector rows, C2 / scope, C11 rows 3/5/6/11/26/28, Edge Cases "Choices" | FOUND |
| content GDD: CN-2 War table, CN-3 B1/B2/B3, CN-4, F1–F5 | FOUND |
| match-rules GDD C10 `recompute_auras`; match-ui table row for `auras_recomputed` | FOUND |
| ADR-0007, read by section: Status/errata (incl. 2026-11-04 card-effects 010 and DD-X18) and Decision 1–9 | FOUND |
| Control manifest 2026-11-04 Core Required / Forbidden / Guardrails | FOUND |
| Diffs (`git show` per commit above) | FOUND |
| `## QA Test Cases` in every story | ABSENT ("N/A — no qa-lead specs at this tier") |
| `design/registry/entities.yaml` `ai_planner_target_ms` | FOUND (500, DD-X18) |

## Baseline (main repo, no edits)

| Run | Result |
|---|---|
| `godot --headless --path . --import` | exit 0 |
| `commands.test` | **1403 / 1403**, 0 errors, 0 failures, 0 orphans, exit 0 |
| `commands.smoke` (`--quit-after 5`) | exit 0, 0 `SCRIPT ERROR` |
| `tools/content/validate.gd` | exit 0: `Ready — 0 errors, 51 warnings (content checks 0 errors, 43 warnings), 69 records; load 36 ms / 200` |
| `tools/lint/gates.sh` | G1–G6 0 hits, PASS. `no_global_rng.sh` 0 hits |
| `tests/performance` (non-blocking) | see MR-018 |

The suite printed 86 `SCRIPT ERROR` lines. Sources: `card_database.gd` 44, `rng_stream.gd` 16, `card_database_freeze_test.gd` 7, `event_log.gd` 6, `rng_service.gd` 4, `boss_ai_planner_task_test.gd` 3, and 1 from the MR-016 fix tests' intentional Discover refusals. The stories' figure was 85. All 86 are intentional negatives; none comes from the reviewed code.

Logs are in `scratchpad/`: `rv4e_import.log`, `rv4e_suite.log`, `rv4e_smoke.log`, `rv4e_validate.log`, `rv4e_perf.log`, `rv4e_gates.log`.

## How behaviour was verified (substitute for the specialist passes)

**Probes.** These scratch suites extend the story suites, so the inherited tests ran too and passed:

- `rv4e_snap/tests/rv4e_probe/rv4e_ce010_probe_test.gd`: P1, P2, P5, P6. Inherited tests 17/17 passed.
- `rv4e_ce012_probe_test.gd`: P7, P10, P11. Inherited tests 14/14 passed.
- `rv4e_perf_rest_test.gd`: the three perf gates the suite abort hides.

Probe output is in `scratchpad/rv4e_ce010_probe.log`, `rv4e_ce012_probe3.log`, `rv4e_ce012_probe4.log` and `rv4e_perf_rest.log`.

**Mutants.** `scratchpad/rv4e_mut.py` applies one mutant per invocation, runs a suite, restores the file and checks the restore with `cmp`. The summary is in `scratchpad/rv4e_mut_summary.txt`.

| Mutant | `tests/unit/card_effects` | Other suite |
|---|---|---|
| A1 no extra death check after a recompute (`_any_minion_dying`) | killed | |
| A2 weapons are not aura sources | **SURVIVES** | |
| A3 boss board before player board as aura sources | **SURVIVES** | |
| A4 no per-target dedupe in `apply_aura` | survives (equivalent: pools yield distinct ids) | |
| A5 hand `cost_modifiers` not stripped | killed | |
| A6 aura `enchantment_applied` not silent during recompute | survives | killed by `match_rules` |
| D1 continuation drops the play tail | killed | |
| D2 resume runs under cause 0 | killed | |
| D3 parked Q not restored on `choose` | survives | killed by `match_rules` and by probe P2 |
| D4 `_depth` not restored on resume | **SURVIVES** (P2 prints the depth but asserts nothing) | |
| D5 F4 keeps the caster in the pool | killed | |
| D6 `CONT_SOURCE_SNAPSHOT` emptied | survives (equivalent: nothing reads it, N3) | |

---

## Verdicts

The engine-specialist (`godot-gdscript-specialist` / `godot-specialist`) and `qa-tester` passes **could not be spawned**. By the skill's verdict rule, every code-bearing story's overall verdict is therefore **NOT ASSESSED**. The verdict the review would otherwise give is in brackets.

Pure data and documentation stories have no `.gd` for a specialist to read. For those, the specialist row is N/A, and the verdict stands on the review.

| Story | Verdict | Blocking | Should-fix | Nits |
|---|---|---|---|---|
| **card-effects 010** | **NOT ASSESSED** [APPROVED WITH SUGGESTIONS] | 0 | S1, T1 | N1–N4 |
| **card-effects 012** | **NOT ASSESSED** [APPROVED WITH SUGGESTIONS] | 0 | S2, S3, T2 | N5 |
| **card-effects 007** | **NOT ASSESSED** [APPROVED WITH SUGGESTIONS] | 0 | S4, X1 | N6, N5 |
| **card-effects 008** | **NOT ASSESSED** [APPROVED WITH SUGGESTIONS] | 0 | X1 | N5, N7 |
| **card-effects 011** | **NOT ASSESSED** [APPROVED WITH SUGGESTIONS] | 0 | — | N6 |
| **card-database 009** | **NOT ASSESSED** [APPROVED WITH SUGGESTIONS] | 0 | — | N5, N8 |
| **boot-composition-root 007** | **APPROVED WITH SUGGESTIONS** (doc; specialist N/A) | 0 | — | N5, N9 |
| **content 002** | **APPROVED** (data; specialist N/A) | 0 | — | — |
| **content 003** | **APPROVED WITH SUGGESTIONS** (data) | 0 | — | N10 |
| **content 004** | **APPROVED WITH SUGGESTIONS** (data) | 0 | S5 (cross-epic) | — |
| **content 005** | **APPROVED** (data) | 0 | — | — |
| **content 008** | **NOT ASSESSED** [APPROVED WITH SUGGESTIONS] | 0 | — | N11 |
| **match-rules 018 harness** | **NOT ASSESSED** [APPROVED WITH SUGGESTIONS] | 0 | S6, S7 | N12 |

**No blocking defect was found.** The highest-risk areas behave correctly on the paths v1 content reaches:

- **Discover pass suspension (CE-010)** is correct for spell, Battlecry, Deathrattle-queued (P2) and End-step observer (P5) Discovers.
- **Aura recompute (CE-012)** is correct for Silence, departure and stacking.
- **Every content table** matches its GDD rows field by field.

The should-fix items fall into three groups:

- fault-path or latent holes: S1, S2, S4;
- cross-epic gaps that shipped data will hit: S3, S5;
- the perf harness reporting stale or missing gates: S6, S7.

---

## Findings — card-effects 010 (Discover and Choose One)

**What was checked.**

- F4 is implemented exactly:
  - `distinct_by_def_id(filter(base) \ {host})`;
  - the hand exclusion knob;
  - id-ascending order;
  - `min(n, |c|)` draws with removal, through `engine.rng_match()`.
- The continuation is plain data (no Callable). It holds the remaining work list, the entries so far, the run context and the owed play tail.
- `choice_made` is logged under the paused step's `cause_seq`, matching the ADR-0007 erratum.
- `clone()` passes `player_hero_set()` to the clone's resolver (`rules_engine.gd:3502–3508`).
- Probe P2 covered a Deathrattle Discover with a second Deathrattle queued behind it. The rest of Q parks (`suspended_queue` 1), and after `choose` the sequence is `discover_picked → card_added_to_hand → armor_gained → effect_resolved (dr_a, depth 1) → trigger_resolved (dr_b) → …`. Armor ends at 6, as expected.
- Probe P5 covered a `turn_end` observer Discover. The End step resumes, `turn_ended` is emitted exactly once, and the boss turn starts.
- Probe P6 covered `then: summon` onto a full board: `summon_failed`, outcome `board_full`, and no 8th minion.

**S1 (should-fix, fault edge). If an `event_cap` hits while a Discover is being offered or resumed, the Ended state keeps a stale `pending_choice` and the resolver dereferences a null `_engine`.**

- **Where**:
  - `rules_engine.gd:1358–1363`: `discover` sets `pending_choice`, then `_set_phase(CHOICE)` and `emit(choice_requested)`. It returns the request even when one of those emits ended the match.
  - `effect_resolver.gd:735–742`: `_engine.emit(discover_offered)`, then `_engine.state()`.
  - `:673–675`: `_ops.step(_engine, …)` and `_engine.emit(effect_resolved)`.
  - `:846/857` in `_apply_pick`.
- **Mechanism**: an emit that hits the cap runs `fault → _end_match → _unbind → resolver.unbind()` synchronously, and that sets `_engine = null` mid-pass.
- **Scenario (P1, VERIFIED)**: a Discover spell is cast with the log `k` events short of `max_match_events`.
  - With the cap on `phase_changed`, `choice_requested` or `discover_offered` (k = 3–5), the match ends `event_cap` with **`state.pending_choice` still non-null on the Ended state**. `pending_choice()` reports a Choice that can never be answered: the MR-016 S4 guarantee "nothing stays parked on the Ended state" is broken.
  - Each of these runs logs 3 `SCRIPT ERROR: Invalid call … in base 'Nil'` lines (`emit`, `state`, `spell_damage`).
  - With the cap on `discover_picked`, `card_added_to_hand` or `damage_dealt` (k = 8–10), the null calls repeat in `resume`.
  - The mid-pass case (k = 9–10) predates CE-010: story 006's `_run_pass` re-read `_engine` per op too. CE-010 adds the offer and resume paths.
- **Fix**:
  1. In `discover`, after each emit, if `_halted()`: clear `pending_choice` and `suspended_action`, and return `{}`.
  2. Make the resolver robust to an unbind during its own call. Either capture `var engine := _engine` at pass or resume entry and stop the work list once `engine.phase() == ENDED`, or have the engine defer `_unbind()` until the outermost `submit` / `run_action` returns. The manifest only requires unbinding when the phase becomes Ended, not inside the resolver's frame.
  3. Pin it with a regression test like P1 (sweep `k`; assert no `pending_choice` on Ended and no script error).

**T1 (should-fix, test gap).**

- No production-resolver test covers a **queued-pass** Discover (a Deathrattle or observer): D3 survives the card-effects suite, and only the match-rules double tests kill it.
- No test checks `effect_resolved.depth` of a resumed queued pass: D4 survives everywhere.
- Fix: add P2- and P5-shaped tests to `card_effects_choices_test.gd`, asserting the order and `depth == 1`.

**N1**: Choose One's inline option ops lose `values.branch` inside a `conditional`. `effect_resolver.gd:828` calls `EffectOps.work(…, item.condition, false, op_index)` without `item.branch`.

**N2**: the docs contradict each other. `rules_engine.gd:1310` says that on a refused request "the effect's later ops do not run". `_offer` (`effect_resolver.gd:703–705, 724–728`) records `skipped` and **continues**. The F4 draws are also taken before the refusal (`:717`). Pick one rule and align both comments.

**N3**: `CONT_SOURCE_SNAPSHOT` (`effect_resolver.gd:752`) is written and never read. The resumed pass uses `run.snapshot` instead. Drop the field, or read it.

**N4**: the story's AC boxes are checked. This is fine; listed only for contrast with N5.

## Findings — card-effects 012 (auras and enchantments)

**What was checked.**

- The strip site is the engine's, and the re-application is the resolver's in canonical order. Silenced sources are skipped, and there is one application per (source, target).
- `_left_out` under `RUN_AURA_RECOMPUTE` correctly treats the stripped transient `health ≤ 0` as alive.
- The added `_any_minion_dying` pass terminates: the board shrinks on each extra death check, because both use the same predicate.
- The clone recomputes from copied state.
- The engine change is 15 lines in `_drain`, additive, and covered by A1.

**S2 (should-fix, latent; same class as DD-X16). An aura granting Divine Shield re-grants it on every recompute, so the recipient never takes damage.**

- **Where**:
  - `effect_schema.gd:158`: `AURA_UNGRANTABLE_KEYWORDS = ["stealth"]` only.
  - `rules_engine.gd:3379–3382`: `_strip_keyword` erases the shield from the aura enchantment.
  - `rules_engine.gd:2975–2986` and `ops.gd` `apply_aura`: the next loop pass re-applies it.
- **Scenario (P7, VERIFIED)**: the validator accepts `{"op":"aura","keywords":["divine_shield"]}` (report `[]`). A 1/3 behind such an aura takes three separate 1-damage hits. The result is `divine_shield_popped` ×3, `dealt` `[0, 0, 0]` and health 3: permanent invulnerability.
- **Latency**: no shipped card has it. C7 allows "the keyword set `give_keyword` allows, less `stealth`".
- **Fix**: a DD-X16-style designer decision. Either add `divine_shield` to `AURA_UNGRANTABLE_KEYWORDS` (and to GDD C5/C7) or track a consumed shield per (source, target). Add a validator test.

**S3 (should-fix, cross-epic to match-rules C10 and match-ui). Keyword and hand-cost changes made by a recompute never reach the log, and the view drops aura stat changes as well.**

- **Where**:
  - `rules_engine.gd:2988–2995`: `auras_recomputed.changes` carries only `[attack, health, max_health]`.
  - `match_view_state.gd:475–476`: `"auras_recomputed": pass`.
  - The match-ui GDD (line 191) maps the event to "Stats, keywords, flags". match-rules C10 says "net stat changes". The two GDDs disagree.
- **Scenario (P10, VERIFIED)**: with a Taunt-aura source in play, a newly summoned 1/1 gains Taunt. The only log event is `minion_summoned`, so an event-projected board (ADR-0001) shows no Taunt badge.
- **Shipped consumers**:
  - `boss_gatekeeper`'s passive is exactly this aura (`bosses.json`), once card-effects 013/015 host passives.
  - `war_warlord`'s +1 Attack is projected by nothing today.
  - The row-24-style hand-cost auras also change nothing in the log.
- **Fix**: decide in the GDDs. Add `keywords` (and hand `cost`) deltas to `auras_recomputed.changes`, or emit per-entity events. Then project the event in `MatchViewState`.

**T2 (should-fix, test gap).** A2 (weapon aura sources) and A3 (player-before-boss source order) survive. Add one weapon-hosted aura test and one test where source order is observable, for example the enchantment order on a recipient buffed from both boards.

**Observation (not probed)**: `apply_aura` evaluates each source's selector against a board that already carries the earlier sources' auras. A stat-filtered aura selector would therefore be order-dependent. No shipped aura uses a stat filter.

## Findings — card-effects 007 (values, selectors, Spell Damage)

**What was checked.**

- `values.gd` evaluates the C4 closed set, and `{count}` / `{exists}` never draw.
- F1 `auto` scaling is read through `engine.spell_damage`, once per op.
- F5 random picks are `k = min(n, |pool|)` with removal.
- Canonical order is followed, and dying characters are left out of pools.
- The `repeat` / `conditional` work items match story 010's work list.

**S4 (should-fix, latent spec mismatch). The `hand` selector ignores `n`: `{selector: hand, n: 1}` targets the whole hand and draws nothing.**

- **Where**:
  - `selectors.gd:77–81`: `RANDOM_SELECTORS` lacks `hand`.
  - `selectors.gd:139–140`: `entities()` returns the whole pool for a non-random selector.
  - `pick_count` (`:228–232`) *does* treat `hand + n` as `min(n, |pool|)`. So `{count: {hand, n: 1}}` says 1 while the same selector targets N.
- **Scenario (P11, VERIFIED)**: a spell `targets {selector: hand, n: 1}`, `buff cost -1`, cast with 3 other cards in hand. All 3 are buffed, with 0 stream draws. The validator accepts it.
- C3 row 27 says: "`hand` … `n` (random) or `all` (default all)".
- **Fix**: in `entities()`, take F5 picks for `hand` when the selector has `n`, the same as for the random selectors. Add a test with two seeds.

**X1 (should-fix, cross-cutting, applies to 007 and 008). Gate G7 does not exist, yet two stories record it as passed.**

- CE-007 (`:117`) and CE-008 (`:111`) record "`tools/lint/gates.sh` PASS (G7 0 hits)". `gates.sh` runs **G1–G6 only** (its header says so), and no test or workflow implements ADR-0007 Decision 9 / manifest Core Forbidden G7.
- I ran the G7 regex by hand over `src/gameplay/effects/`: **0 hits**. The pattern does fire on a planted `x.board.append(1)`. The code is compliant, but nothing guards it.
- **Fix**: add G7 (pattern verbatim from the manifest, plus `log\.append\(` and `RandomNumberGenerator`) to `tools/lint/gates.sh`, with a planted-hit test in `boot_lint_gates_test.gd`. Correct the two completion notes.

**N6**: `values.gd:217–223` (`weapon_attack`) re-derives a weapon's attack from its enchantments. Since story 011, `RulesEngine.attack()` holds the same rule (C1: derived values are engine functions). Read it through the engine, so the two cannot drift.

## Findings — card-effects 008 (observers and queueing)

**What was checked.**

- The scope matcher matches the C2 table.
- The unstated defaults are recorded as deviations for game-designer.
- Candidate order is the engine's and is never re-sorted.
- Self-entry is excluded on the entry points.
- A Deathrattle reads the death snapshot, and a Silenced snapshot responds to nothing.
- The `once_per_turn` TODO (story 009) is harmless today: no shipped record sets `once_per_turn: true`.

**N7**: the C2 defaults chosen without a GDD row (`by: owner` on `on_play` / `after_cast`, `side: owner` on `on_weapon_equipped`, `attacker: self`) still await game-designer confirmation. Carry them into story 009 readiness.

X1 applies.

## Findings — card-effects 011 (hero powers)

**What was checked.**

- `buff cost` on a card instance in hand or deck goes through `CARD_INSTANCE_PARAMS`.
- `exists` over a reference selector (the Whetstone fix) works.
- The summon `end` fallback for a non-minion source works.
- `attack()` now adds the weapon's enchantments (2 lines, correct, and covered by the swing test).
- No defects found. N6 applies.

## Findings — card-database 009

**What was checked.**

- The counters reset per `run()`. `validation_checks()` is `n_records + n_refs`, and nothing branches on it.
- The perf thresholds are read from `config("card_database")`, and the `TestConstants` mirror is checked against the shipped file in integration.
- Current perf run: load median 20.1 ms (budget 200), `MEMORY_STATIC` delta 0.58 MB (budget 4), `validation_checks` 265 = 69 + 196 (logged).

**N8**: the GDD wording "`n_bosses` → bosses with a hero power" is still pending, as the story notes.

## Findings — boot-composition-root 007

**What was checked.**

- `boot-responsibilities.md` maps all 20 members of `src/core/boot.gd`. `boot.gd` is unchanged since `08f851c`.
- Every cited test exists. The wildcard rows resolve to `test_boot_wrong_type_{meta,card_database}_override_…`, `test_g3_*` and `test_g4_*`.
- The manifest 2026-11-04 carries the rows.

**N9**: Test Evidence still reads "[~] Pending — no smoke after the hand-over". `production/qa/smoke-2026-11-04-sprint-004.md` (PASS) now exists, so the status can be closed.

## Findings — content 002–005 (data)

- **002**: `scratchpad/rv4e_cn_check.py` compared all 25 War records against CN-2. Every field matches: id, name, type, cost, stats, keywords, text (all ≤ 90), rarity and tags. Each `effects[]` uses its C11 row shape (rows 3, 5, 6, 26, 28 checked verbatim). There is one extra record, the token `war_whetstone_blade`, as intended.
- **003**: the Rat King and Gatekeeper rows match B1, and the boss cards and token match B3. The decks are 30 cards, with no tokens, max cost 5, inside the recipe ids, plus the recorded Gravekeeper fallback (×3 boss cards).
- **004**: Rot Warden and Hollow King match B1/B3. The decks are 30 with the recorded fallbacks.
- **005**: all 10 MVP bundles match CN-4: id, name, theme, three cards, and the average-cost band (1.67 / 2.33 / 5.00 / 2.67 / 3.67 / 5.33 / 2.00 / 3.33 / 2.67 / 2.33).
- `validate.gd`: 0 errors.

**S5 (should-fix, cross-epic to card-effects; content 004). `boss_mass_rites` (×3 in the MVP Rot Warden deck) does nothing at runtime, and no story implements its op.**

- **Where**:
  - `cards_boss.json:251` uses `retrigger`.
  - `EffectSchema.OPS` accepts it (`effect_schema.gd:256`), so the validator passes it.
  - The resolver's dispatch table (`ops.gd:110–124`) has no `retrigger`, so `EffectOps.run` records it `skipped` (`ops.gd:140–141`).
  - No card-effects story (001–016) mentions `retrigger`.
  - `ai_profiles.json` values it at 1.5, so the planner prior expects an effect the engine never produces.
- **Scenario (VERIFIED by code read)**: the boss casts Mass Rites with Rot Zombies on board. The result is `effect_resolved{ops:[{op: retrigger, outcome: skipped}]}`, and no Deathrattle is queued.
- **Fix**: give C5 `retrigger` an owner. Story 009 is the natural host (Deathrattle snapshots), or write a new story, before the First Playable pool includes Rot Warden.
- **Related observation**: every MVP boss passive (turn_start, aura, on_minion_died) is inert until card-effects 013/015 host passives on the hero slot (`effect_resolver.gd:531–533`). That is tracked by story 015 (Ready).

**N10 (content 003)**: Rat King leaves out `neutral_smite_or_mend` "so the boss never holds a Choose One it cannot yet score (BAI-010)". Gatekeeper ships two copies. The sandbox scorer answers option 0 (`scorer.gd:359–370`), and the live boss `choose` is BAI-010 (Ready). Either align the rationale or make sure BAI-010 lands before a First Playable that includes Gatekeeper.

## Findings — content 008 (F1–F5 checks)

**What was checked.**

- Every check reports "not checked" under its own code when a knob is absent, never a silent pass.
- F2 bucket mapping: `clampi(cost − 1, 0, last)` gives buckets ≤1, 2, 3, 4, 5, ≥6, matching F2.
- The F3 budget shapes match the formula.
- The MVP/Alpha pool is derived from the HeroDefs, not a flag.
- The AC-4 literal scan was seen failing (per the story).

**N11**: F5 says `used_by` counts "cards + that batch's bosses and treasures". `check_coverage` (`content_validator.gd:447–453`) counts collectible cards only for the op set, and counts bosses and treasures only for `modify_value`. At MVP this is warnings only. Count boss passives and boss cards too, or reword F5.

## Findings — match-rules 018 harness

**What was checked.**

- The blocking half (`match_rules_hook_fold_budget_test.gd`, 8 tests) is deterministic. It asserts the 13th-entry debug assert through `assert_error(...).is_runtime_error`, and reports NOT ASSESSED in a release build.
- The fixture chain resolves 56 passes under the step cap, and the clone chain leaves the live board alone.
- The double's index preserves answers and order.

**S6 (should-fix). The planner-node gate uses retired numbers and claims a source it does not read.**

- **Where**: `tests/performance/match_rules/match_rules_perf_test.gd:42–50`. `PLANNER_TARGET_USEC: int = 50_000` is documented as "`design/registry/entities.yaml` `ai_planner_target_ms`", but it is a literal. The registry now reads **500** ms per planner run (DD-X18, `entities.yaml:1493–1499`).
- `F7_T_SIM_USEC = 10.0` is the t_sim DD-X18 retired.
- The story's Implementation record says that `planner_target_ms` is read "from the entity registry". It is not.
- **Effect**: the non-blocking job prints "target 50 ms" and gates on `50 ms / F7 nodes`. Measured: node median 646 µs against a gate of 16.7 µs. Even at 500 ms the gate (≈167 µs) fails, but the cause is now the band counts DD-X18 R5 has yet to re-derive, not the target.
- **Fix**: read `ai_planner_target_ms` (and the per-run semantics) from the registry. Mark the gate NOT ASSESSED until R5 lands, rather than failing on the retired assumption.

**S7 (should-fix). A failing perf gate hides the others: in this gdUnit run a failure aborts the rest of its suite.**

- **Evidence (VERIFIED)**: `tests/performance` reports `1 test cases` for `match_rules_perf_test.gd`. Only the submit test runs and fails (median **24.7 ms**, p95 37.5 ms, gate 10 ms). The same per-suite abort shows in the mutant runs (178 of 188 card-effects tests ran when one failed).
- Run without the submit test (`rv4e_perf_rest.log`):
  - `legal_commands` median 0.97 ms: PASS (2 ms);
  - fold 20 µs: PASS (50 µs);
  - planner node 646 µs: FAIL (S6).
- Until story 019 fixes submit, CI never measures those three. It also never says they did not run: the job just shows fewer tests (skill-authoring obligation 3).
- **Fix**: split the four gates into separate suites, or run the submit gate last. Have each gate print a `NOT ASSESSED` line when skipped.

**N12**: in `tests/helpers/test_effect_resolver.gd:146/244/256`, the index counts as valid whenever `_indexed == triggers.size()`. A test that removes one trigger directly and then calls `add_trigger` gets matching counts and a stale index. No test edits `triggers` directly today. Invalidate the index on direct edits, for example by keeping `triggers` behind a setter.

## Cross-story nits

**N5**: the AC checkboxes in CE-007, CE-008, CE-012, CDB-009 and BOOT-007 are `[ ]`, while each Completion Notes section reports N/N passing. Tick them, so `/story-done` and `/gate-check` read one answer.

---

## Engine Specialist Findings: NOT ASSESSED

`godot-gdscript-specialist` and `godot-specialist` could not be spawned. As a substitute, I verified the engine behaviour the reviewed code relies on, on Godot 4.7.2 with headless probes:

- typed `Array[Dictionary]` `assign` and `duplicate(true)` in the continuation (P2 resume is correct);
- lambdas capture by value (a probe bug I hit; the reviewed code does not rely on capture);
- the null-method call aborts the function with a `SCRIPT ERROR` rather than crashing (S1).

No post-cutoff API is used by any reviewed file.

## Testability: GAPS

There are no QA Test Cases in any story, and qa-tester was NOT ASSESSED. The gaps found are T1, T2 and the mutant survivors A2, A3 and D4.

## ADR Compliance

- **ADR-0007 Decisions 1–7: COMPLIANT.** All writes go through primitives, all emits through `engine.emit`, all draws through `rng_match`, and the continuation is plain data. The erratum (hero set, `choice_made` cause) is honoured.
- **ADR-0007 Decision 9 (gate G7): DRIFT.** The gate is not implemented (X1). The code itself passes it by hand.
- **ADR-0005 / ADR-0002: COMPLIANT** for CDB-009, BOOT-007 and MR-018.

## Standards Compliance

Doc comments, data-driven knobs and injection are present throughout.

- `_continue_pass`, `_offer` and `_apply_pick` each run about 45 lines, a minor overrun of the 40-line rule.
- The MR-018 perf budgets are cited literals. This is a recorded deviation; S6 shows the cost.

## Positive Observations

- The continuation design (a plain work list plus an owed play tail) is small and clone-safe. All seven of the story's own mutants and five of mine are killed.
- The C10 "one more death check" fix is minimal and correct.
- The content data is exact against the GDD tables. content 008 reports every "could not check" by name.
- The MR-018 harness surfaced the real budget miss with honest numbers, and the story left itself In Progress instead of closing on it.

## Required Changes

None blocking.

## Suggestions (priority order)

1. **S1**: the event-cap stale `pending_choice` and the null `_engine`.
2. **S5**: an owner for `retrigger`.
3. **S3**: auras' keyword and cost projection.
4. **X1**: add G7 to CI.
5. **S2**: the Divine Shield aura.
6. **S4**: `hand {n}`.
7. **S6** and **S7**: the perf harness.
8. **T1** and **T2**: the tests.
9. The nits.
