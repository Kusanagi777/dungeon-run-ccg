# Test Infrastructure

**Engine**: Godot 4.7.2
**Test Framework**: GdUnit4
**CI**: `.github/workflows/tests.yml`
**Setup date**: 2026-11-03

## Directory Layout

```
tests/
  unit/           # Isolated unit tests (formulas, state machines, logic)
    framework/    #   framework_sanity_test.gd (runner seed) + test_helpers_test.gd (helper self-test)
  integration/    # Cross-system and save/load tests
  smoke/          # Critical path test list for /smoke-check gate
                  #   + project_boot_smoke_test.gd — automated boot smoke (see below)
  helpers/        # Shared assertions, factories, test doubles — see "Helpers" below
```

Seed suites: `tests/unit/framework/framework_sanity_test.gd` proves the runner
discovers and executes suites (delete it once a real system has its own suite);
`tests/smoke/project_boot_smoke_test.gd` is the automated boot smoke. Both run
with every `-a res://tests` run, locally and in CI.

```
production/qa/
  evidence/       # Screenshot logs and manual test sign-off records
```

> **Manual evidence lives under `production/qa/evidence/`, not `tests/`** — that
> is where every consumer reads it.

## Running Tests

```bash
godot --headless --path . --import
godot --headless -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode
```

Run the import first: a fresh clone has no `.godot/` class cache, and a run
without one exits 1 (`GdUnitCmdTool.gd` did not load, so no test ran). Exit 0:
every test passed. Exit 100: a test failed. Exit 101: every test passed but a
test leaked nodes (a warning). Exit 103 or 104: gdUnit4 could not run. Exit 105:
a test script does not parse. A run that finds no tests prints `No test cases
found` and exits 0, which is not a pass. The folder is `addons/gdUnit4/` with a
capital U.

Verified on Godot 4.7.2 with gdUnit4 6.2.3 (2026-11-03): the exit codes above
come from `GdUnitTestSessionRunner.gd` (`RETURN_SUCCESS = 0`, `RETURN_ERROR = 100`,
`RETURN_WARNING = 101`, `103` headless not supported, `104` Godot version not
supported, `105` script errors). The runner prints `Exit code: N` as its last
line and the orphan count in each suite's `Statistics:` line, so a 101 is easy to
spot. Use `auto_free(...)` on every Node a test creates (a child added to an
auto-freed parent is freed with it). `--remote-debug` prints two `ERROR:` lines
about port `127.0.0.1:0` on every run; they are expected.

CI and the command above both run every suite under `tests/` (the local command
is exactly `commands.test` in `project.yaml`).

### Reports

gdUnit4 writes `reports/report_<n>/` at the project root on every run
(default `-rd res://reports/`, keeps the last 20 via `-rc`): `results.xml`
(JUnit) and `index.html`. The runner prints both paths at the end of the run.
`reports/` is gitignored; CI uploads it as the `gdunit4-report` artifact.

### Smoke: automated vs launch-based

`tests/smoke/project_boot_smoke_test.gd` is a gdUnit4 suite that does **not**
need a main scene: it checks the project settings load, the gdUnit4 plugin is
enabled, and a Node can be added to the tree and freed headlessly. The
launch-based smoke in `project.yaml` (`commands.smoke`: `godot --headless
--quit-after 5`) needs `run/main_scene`, which is unset until the first UI story;
until then it prints `Can't run project: no main scene defined` and does not
exit, so run it under a timeout or skip it. Once a main scene exists,
`commands.smoke` becomes the real "game launches" check and entry 1 of
`smoke/critical-paths.md` should point at it.

## Helpers

`tests/helpers/` (written by `/test-helpers` on 2026-11-03) holds plain
`RefCounted` classes — none extends `GdUnitTestSuite`, so the runner never
sees them as empty suites. `class_name` makes them available in any test with
no import. Every helper asserts through gdUnit4's own API
(`GdUnitTestSuite.assert_bool(...)`, a `static func` in the installed addon),
never a bare `assert()`.

| File | Class | Use it for |
|---|---|---|
| `test_constants.gd` | `TestConstants` | The one source of gameplay numbers in tests; each constant names its `design/registry/entities.yaml` entry (board 7, hand 10, mana 10, health 30, hands 3/4, hero power 2, discover 3, floors 8, …). Never write these as literals in a test. |
| `game_assertions.gd` | `GameAssertions` | `fail_if`, `assert_in_range`, `assert_signal_emitted` / `_not_emitted`, `assert_json_representable` (rng-event-log rule 14), `assert_sorted_ascending`, `assert_no_duplicates`, `assert_has_keys`, `assert_node_exists`. |
| `test_rng_stream.gd` | `TestRngStream` | Injected named stream (DD-T03): `seeded`, `scripted` (fixed `randi32()` values) or `constant` ("zero stub"); F4 draw API with exact `draws`; `fork`; `restore`; F1/F2/F3 seed arithmetic pinned to the GDD examples; records `calls`. |
| `test_rng_service.gd` | `TestRngService` | `stream(name)` memoised per F2, `install(stream)` for a scripted stream, `snapshot()` / `restore()`, `draws_outside([...])` for "no RNG call outside `rng_match`". |
| `test_event_log.gd` | `TestEventLog` | Append-only log double: `append(type, payload, cause_seq)`, `events_since`, `subscribe`, sealing on `match_ended`, `max_events` overflow path, canonical `to_json` / `from_json`. |
| `event_log_assertions.gd` | `EventLogAssertions` | `assert_order`, `assert_consecutive`, `assert_contains_type`, `assert_count`, `assert_last_type`, `assert_payload`, `assert_seq_contiguous`, `assert_cause_seq_valid`, `assert_envelopes_valid`, `assert_replay_equal` (F6). Accepts a `TestEventLog` or an Array of events. |
| `card_factory.gd` | `CardFactory` | CR-3 records (`make_minion` / `make_spell` / `make_weapon` / `make_hero_def` / `make_boss_def` / `make_treasure_def` / `make_bundle_def`), C1 effects (`make_effect`, `make_op`), CR-1 envelopes, the match-rules fixture card set, `validate_card_def`. |
| `match_factory.gd` | `MatchFactory` | C1 data model as Dictionaries: `make_match_state`, `make_player_state`, `summon` (ids from `next_entity_id`, board-full returns `{}`), `deal_deck`, `draw_top`, `make_match_config(floor, rng, log)`, `make_command_result`, `make_match_result`, derived `health_of` / `max_health_of` / `attack_of`, `REJECTION_CODES`. |
| `run_factory.gd` | `RunFactory` | R1 `make_run_state` (invariants hold by default), `make_draft_record`, `apply_bundle_pick` / `apply_treasure_pick`, `make_offer`, `make_match_summary`, the 6/6/4 fixture boss pool, `band_of`, `deck_size_at_floor`, `effective_treasure_floors`, `validate_invariants` / `assert_invariants`. |
| `scene_runner_helper.gd` | `SceneRunnerHelper` | `load_scene_and_wait(self, path_or_packed_scene)` for UI integration tests; wrap the result in `auto_free`. |

The factories return plain Dictionaries with the GDD field names because
`src/` has no production classes yet; each file carries a
`TODO(E1/E2 story): swap to production class` marker for the story that adds
the real type. `tests/unit/framework/test_helpers_test.gd` exercises every
helper, including each failure path through `assert_failure(...)`, so a
helper that stops asserting shows up as a red test.

## Installing GdUnit4

```
1. Open Godot → Asset Store (AssetLib before Godot 4.7) → search "GdUnit4" → install it
2. Enable the plugin: Project → Project Settings → Plugins → GdUnit4 ✓
3. Restart the editor
4. Verify: res://addons/gdUnit4/bin/GdUnitCmdTool.gd exists (capital U)
```

## Test Naming

Names follow the engine's language (`.claude/rules/test-standards.md`):
- **Godot**: file `[system]_[feature]_test.gd`, function `test_[scenario]_[expected]`
  — `combat_damage_test.gd` → `test_base_attack_returns_expected_damage()`

## Story Type → Test Evidence

| Story Type | Required Evidence | Location |
|---|---|---|
| Logic | Automated unit test — must pass | `tests/unit/[system]/` |
| Integration | Integration test OR playtest doc | `tests/integration/[system]/` |
| Visual/Feel | Screenshot + lead sign-off | `production/qa/evidence/` |
| UI | Retained screenshot of each screen touched | `production/qa/evidence/` |
| Config/Data | Smoke check pass | `production/qa/smoke-*.md` |

## CI

Tests run automatically on every push to `main` and on every pull request.
A failed test suite blocks merging.

The workflow (`ubuntu-latest`) runs `bash tools/setup.sh` (installs Godot 4.7.2
from the official GitHub release into `~/.local/bin/godot`), imports the project
twice (the first import on a clean machine may exit 139; the second must exit
0), runs exactly `commands.test`, fails the job if the output contains
`No test cases found` or the exit code is non-zero (including 101, so node
leaks get fixed rather than ignored), and uploads `reports/` plus the runner
log as the `gdunit4-report` artifact. If you protect `main`, require the
`Run GdUnit4 Tests` job.
