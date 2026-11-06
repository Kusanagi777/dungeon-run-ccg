# /code-review: sprint 3 stories with no independent review (2026-11-04, read-only)

Reviewer: an independent subagent that wrote none of this code. Config: Godot 4.7.2, review lean, workflow standard (match-rules and card-effects run at full).
**The skill's formal verdict is NOT ASSESSED for all 13 stories.** The skill needs engine-specialist and qa-tester agents, and this reviewer context has no Agent tool. I checked engine behaviour myself with headless probes instead (scratchpad `rvprobe/`). The verdicts below are code verdicts.

Runs on HEAD `ca890d1`:
- import: exit 0
- `commands.test -c`: 1078/1078 pass, exit 0. The 85 SCRIPT ERROR lines come from other suites' negative tests.
- `commands.smoke`: exit 0, no SCRIPT ERROR
- `validate.gd`: exit 0 on the shipped data, exit 1 on `refs_unknown/`

I could not run a mutation probe in a scratch copy because the permission was denied. The test gap under card-effects 005 is therefore based on grep, not on a mutation.
Severity scale: **blocking** (the story contract is wrong in production), **should-fix**, **nit**. Every finding below is VERIFIED unless it is marked otherwise.

## Verdicts
| # | Story | Code verdict |
|---|---|---|
| 1 | card-database 008 | APPROVED WITH SUGGESTIONS |
| 2 | card-effects 004 | APPROVED WITH SUGGESTIONS |
| 3 | card-effects 005 | APPROVED WITH SUGGESTIONS (1 should-fix) |
| 4 | card-effects 006 | APPROVED WITH SUGGESTIONS (2 should-fix) |
| 5 | card-database 007 | APPROVED |
| 6 | rng-event-log 003 | APPROVED WITH SUGGESTIONS |
| 7 | rng-event-log 008 | **CHANGES REQUIRED** (1 blocking) |
| 8 | rng-event-log 010 | APPROVED WITH SUGGESTIONS (owner decision on the append budget) |
| 9 | match-ui 001 | APPROVED WITH SUGGESTIONS (shares content 001's should-fix) |
| 10 | match-ui 002 | APPROVED WITH SUGGESTIONS (same) |
| 11 | content 001 | APPROVED WITH SUGGESTIONS (1 should-fix) |
| 12 | content 007 | APPROVED WITH SUGGESTIONS |
| 13 | boot-composition-root 006 | APPROVED WITH SUGGESTIONS |

## 1. card-database 008: state machine and debug reload (`0d43635`)
The transitions match the States table exactly. `reload()` swaps the snapshot in one assignment, so a pinned handle keeps the old data. Release builds get `E_NOT_SUPPORTED`. A failed reload from `Ready` keeps the old snapshot and the old `data_version`. Every caller-bug assert sits after the log line, so the release fallback still happens. The tests drive the release branch through the injected build flag.
- **should-fix (tracked)** `src/core/data/card_database.gd:132`: the control manifest's Core rule "`CardDatabase.reload()` returns `E_BUSY` while any `PlannerTask` is live" (ADR-0006) has no implementation and no story. The story flags it as out of scope. Fix: write the story already noted in active.md. Inject a "planner live" predicate (a Callable, or a counter `MatchDriver` sets). When it is true, `reload()` returns a one-entry `E_BUSY` report and touches nothing. Add a test for that case.
- nit `card_database.gd:138-141`: `reload()` called from a validator during `RELOADING` returns `E_NOT_LOADED` with the text "needs a finished load()", which is misleading during a reload. Name the actual state, e.g. "reload() is not re-entrant; state is RELOADING".
- nit: nothing pins `snapshot_handle()` yet. `RulesEngine` and `EffectResolver` call `db.card()` on the live database, so a debug reload in the middle of a match mixes the old and new data sets. The pinning belongs to `MatchDriver`; make sure its story says so.

## 2. card-effects 004: F6 step bound, E_FX_BUDGET / E_FX_OP_TARGET, derived targeting (`afe128a`)
I checked F6 against GDD §F6: 321 and 161 come out as the GDD says, conditional takes the max, choose_one takes the max, and the ceilings are right. The bound fails closed when `hand_size` is absent from caps. `derive_targeting_spec` is the only derivation, and the resolver memoises it per def_id. `legal_targets` checks enemy Stealth, dying characters and canonical order. `Boot._effects_adapter` now passes `stage7_caps` (boot.gd:200).
- nit `src/core/boot.gd:151`: the doc comment still says `caps = configs["card_effects"]`. Change it to `EffectValidator.stage7_caps(bodies)`.
- nit `effect_validator.gd:174`: `_check_budget` runs even when `_check_op` has already reported `times > max_repeat`, so one fault gives both `E_FX_OP` and `E_FX_BUDGET`, as the test notes record. Either skip the budget check on an effect that already has `E_FX_OP` or `E_FX_SCHEMA` entries, or document the double report.
- nit `rules_engine.gd:1513`: a spell aimed at an enemy Stealth minion is rejected as `ILLEGAL_TARGET`, never `TARGET_STEALTHED`, which exists in the closed rejection set. Match-rules may want the specific code for its UI feedback. This is a match-rules item.

## 3. card-effects 005: C11 fixture set through stage 7b (`d7a26c3`)
The C11 row enumeration, the drift guard against the flat file and `CardFactory`, the AC-2 five-argument adapter check and the `load({})` E_DELEGATED test in both build types are all sound.
- **should-fix** `tests/integration/card_effects/card_effects_fixture_load_test.gd:46-50,163`: the test builds its own stage-7b adapter (`validate_effects(..., stage7_caps(configs))`). Production uses `Boot._effects_adapter`. The only Boot adapter test, `boot_validator_map_test.gd:161`, covers the failure branch. No shipped card uses `hand` or a value-expression count, so if Boot's adapter went back to `bodies["card_effects"]`, every test would still pass. The story's own completion notes record that this regression existed until the orchestrator fixed it. Fix: run the v1 fixture through `ContentValidateCommand.boot_validators(true)`, or `load("res://src/core/boot.gd").new()._collect_validators(null, true)` with the instance freed afterwards, and assert `Ready` with zero `E_FX_*` entries. Alternatively, add a `boot_validator_map_test` case where a `hand`-targeted effect validates clean through Boot's adapter.

## 4. card-effects 006: play triggers in one pass (`a4fd978`)
Exactly one `effect_resolved` is emitted per pass, under the command's `cause_seq`. No death check or aura recompute runs between ops, a `chosen` target that is dying is still reachable, and the outcome set is closed. G7 is clean: ops only call primitives.
- **should-fix** `src/gameplay/effects/ops.gd:289-295`: `_op_mana` with `duration: this_turn` calls `engine.add_mana(side, n, true)`. On HEAD that pushes an error and does nothing (`rules_engine.gd:721-723`, "temporary crystals are match-rules story 011"), yet the op is still recorded as `outcome: applied`. The log and the UI would then report crystals that were never granted. No fixture row contains a `mana` op, so nothing tests this. Fix: until MR-011 lands, record `skipped` with `values.reason = "temporary_unsupported"` and add a test. Better, have `add_mana` return whether it applied anything and fold that into the outcome.
- **should-fix** `ops.gd:313-319`: a value expression (`{ref}`, `{count}`, …) becomes `0`, and the op still runs and reports `applied`. For example, `summon count: {ref}` summons nothing and reports `applied`. That contradicts the fail-closed choice this same story made for unsupported conditions, which fizzle. No shipped data uses one today (grep found no `"ref"` in assets/data). Fix: return a sentinel from `_int`, and have the handler record `skipped` with `values.unsupported_value` without calling the primitive, until story 007 lands.
- nit `effect_resolver.gd:242-254`: two play-trigger effects on one host both run inside a single engine `resolve` call, so no death check or aura recompute happens between them. C6.0 says one effect pass is one C10 step. No shipped or fixture host has two play effects (I checked with a script). Before content adds one, either raise each pass as its own engine step or record the rule in the GDD.

## 5. card-database 007: `data_version` fingerprint (`6afbaac`)
SHA-256 runs over the name plus the canonical JSON, with records sorted by id. The ADR-0002 erratum is recorded, the known answer matches an independent reference, and the fingerprint is computed only on a clean load. No defects.
- nit: the Windows cross-check of `4667ce6e5d01302f` is still open (epic DoD). Run it during the first Windows playtest.

## 6. rng-event-log 003: snapshot/restore with `fork_points` (`a3922db`)
Restore is validated as a whole before anything is mutated: run_seed, draws, fork points, shared points, orphan forks. Forks are replayed at their recorded parent positions in position order, the hex form round-trips correctly above 2^53, and the ADR-0003 erratum is recorded. Determinism holds.
- nit `src/core/rng/rng_service.gd:190`: `restore()` is not refused while a command is open, although `snapshot()` is. Restoring in the middle of a command would silently rewind streams the command is drawing from. Fix: apply the same `_open_commands > 0` guard (push_error, `ERR_BUSY`), plus one test.
- nit: when `restore()` drops a stream, any reference a caller still holds becomes a detached stream that is never snapshotted. This is documented; consider an `assert`/log the next time such a stream draws.

## 7. rng-event-log 008: match summary (`ca8a979`)
- **blocking** `src/core/log/event_log.gd:320-323`: the attribution map reads `payload.instance_id` from `minion_summoned` and `weapon_equipped`. The engine emits `entity_id` for both (`rules_engine.gd:946-948`, `1117-1119`, `1638-1640`). As a result, on a real `RulesEngine` log every minion attack and every weapon attack goes unattributed, and `damage_by_card` holds only spells (keyed by the `card_played` instance) and the hero power. The tests pass only because they build payloads in the RNG catalogue shape (`instance_id`). Match UI already reads both forms (`match_view_state.gd:687 _entity_id_of`). Fix:
  1. Read `payload.get("entity_id", payload.get("instance_id"))`, as Match UI does.
  2. Add a test that reduces a log from a real `RulesEngine` match (minion attack, weapon attack, spell, hero power) and checks `damage_by_card`.
  3. Have the producer reconcile the rng-event-log GDD catalogue rows 171/172 (`instance_id`) with what the engine emits (`entity_id`): one of the two documents changes.
- note: the hero-power key is the hero's entity id, so weapon swings by the hero would be credited to the power once it has been used (story deviation). Match-rules C15 needs to pin the `source` of hero attacks.

## 8. rng-event-log 010: determinism contract and the non-blocking perf job (`7803990`)
The F6 self-test is sound, including the negative bound-change case. The perf folder is excluded from the blocking run with `-i` and runs in a `continue-on-error` job with one retry and the timings in the job summary. The new `append()` fast path preserves the behaviour of the coercing path: a typed container, a non-String key or an Object falls back to it. I verified this by reading `_freeze_plain_children`, and the coercing branch has its own new test.
- owner decision (already open): event-log append takes 51–60 ms locally and 33–47 ms on CI, against the 50 ms budget.
- nit `.claude/docs/coding-standards.md` (CI/CD Rules): the Godot test command has no `-i res://tests/performance`. A reader who copies it brings the wall-clock suite back into a blocking run.
- nit: neither path rejects a non-finite float (`inf`, `nan`) in a payload, and `JSON.stringify` cannot represent one. This is a pre-existing gap in story 005.

## 9. match-ui 001: `MatchViewState` projection (`f219770`, fix `10c9980`)
The projection is pure: nothing in src/ui/match reads time, RNG or hashes. Boss card ids are hidden, and unknown types become `feed.unknown`. Entity ids are read from both `entity_id` and `instance_id`, which is correct. The fizzle fix is in.
- should-fix (shared with content 001): the `SPEED_DIV`, `COALESCE_THRESHOLD` and `FEED_MAX_LINES` config keys are read at `match_view_state.gd:126` and `animation_queue.gd:90-91`. See §11.
- nit: the 170-event fixture is hand-built in a mix of shapes. Re-record it from the engine when MR-012+ lands, as the story says. It would also have caught the §7 key mismatch for Match UI.

## 10. match-ui 002: `AnimationQueue` (`ba64aae`)
The clock is driven by `advance(delta)`, so it does not depend on frame rate. `skip_all` runs every final exactly once, in order. The coalescing threshold is strict and documented. `instant` and `reduce_motion` follow F3.
- should-fix: the config key casing (§11).
- nit `animation_queue.gd:273-314`: when a pop group coalesces, its members are moved to the position of the first member, ahead of any steps that were queued between them in the same group. Their finals then run before those steps' finals, against L6's "finals in seq order". UNVERIFIED: no test interleaves another kind inside a coalescing burst. Add one.

## 11. content 001: batch-0 data (`0513820`)
The shipped data loads Ready with 0 errors and 11 warnings. Every `text.en` is ≤ 90 characters. The starter deck has 15 cards with no tokens, and the Torchbearer deck has 30 cards per the B2 recipe with Ogre Porter ×2 standing in for the deferred Gravekeeper. Bundles hold 3 cards each in the bundle's set with its theme tag. The boss passive matches CN-3 B1.
- **should-fix** `assets/data/match_ui.json:38,42,47`: the keys `SPEED_DIV`, `COALESCE_THRESHOLD` and `FEED_MAX_LINES` break DD-T01's "snake_case keys" rule and `.claude/rules/data-files.md`. They are the only non-snake_case config keys in `assets/data/` (checked with a script); the story chose them deliberately to match the UI code. Since `match_ui` has no validator yet, this is the cheapest moment to fix it. Rename them to `speed_div`, `coalesce_threshold` and `feed_max_lines` in the JSON, in `tests/helpers/match_ui/match_ui_test_config.gd`, in `animation_queue.gd:90-93,181` and `match_view_state.gd:126`, and in the `boot_data_error/match_ui.json` fixture. Map the GDD's UPPER_CASE names to file keys the way `EffectValidator.CONFIG_KEYS` does.
- owner item (not a code defect): `neutral_gravekeeper` was deferred because `ai_profiles.json` `op_values` has no `add_counter` row (`E_AI_OP_UNVALUED` is an error). This is a Boss AI F9 GDD decision: add the row, or make the code a warning as its own Edge Cases line reads.

## 12. content 007: `validate.gd` and `ContentValidator.validate_config` (`fccab0e`)
The command reuses Boot's own validator map. I probed it: Callables to static methods stay valid after `boot.free()` (`rvprobe/probe_boot_map.gd`). Exit codes are 0, 1 and 2 as specified, the schemas match the loader, and the budgets validator reports every fault.
- nit `tools/content/content_validate_command.gd` (`boot_validators`): when `boot.gd` cannot be loaded it returns `{}`, the load then ends `E_DELEGATED` and the command exits 1. The contract says "2: could not run (no project)". Fix: in `run()` or `_initialize`, check for an empty map and exit with `EXIT_NOT_RUN`.
- nit: the headless runs end with "10 ObjectDB instances leaked / 4 resources still in use". `CardDatabase` and `DataLoader` are freed (probe `rvprobe/probe_leak.gd`), so the leak is static script state. It does no harm, but it is noise in CI logs. Run it once with `--verbose` to identify the owner.
- nit `content_validator.gd`: nothing checks that `curve.bucket` shares sum to about 1. Add the check if CN-6 intends it.

## 13. boot-composition-root 006: `main.tscn`, the RunShell stub and the data-error screen (`6ca5b5c`, `4d70cb1`)
The composition holds: `Boot.boot()` is called once, the shell gets the services by argument before `add_child`, and `Boot` is referenced only in main.gd and run_shell.gd. The `Failed` state is reached through the real Boot path with a debug-only, pattern-checked fixture argument. Both frames are retained and stamped; I read them by eye. The Windows row is recorded as `not yet run`, and the release-exports-open-on-data_error behaviour is documented and pinned by a test.
- nit `src/scenes/main.gd:41`: the returned `BootResult` is discarded and `RunShell` re-derives the state from `CardDatabase.state()`. Today the two are equivalent (`ok` means Ready). Branch on `BootResult.ok` instead, so the shell follows ADR-0001's "Boot hands the report to the scene root" if `ok` ever covers more than the database (for example the profile).
- nit `run_shell.gd`: "11 problems — fix the data files" counts warnings. The capture shows one error and ten warnings. Show "N errors, M warnings" instead.
- nit `main.gd:57`: `RegEx.create_from_string` is compiled per argument. Make it a static var.
