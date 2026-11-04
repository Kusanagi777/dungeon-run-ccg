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
  performance/    # Wall-clock budgets — NOT in the blocking run (see "Performance suites")
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
godot --headless -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests -i res://tests/performance --ignoreHeadlessMode
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

CI and the command above both run every suite under `tests/` except
`tests/performance/` (the local command is exactly `commands.test` in
`project.yaml`).

### Performance suites (non-blocking)

A wall-clock assertion never gates (coding standards: no time-dependent
assertions in the blocking suite). Timed budgets live under
`tests/performance/<system>/`, keep their thresholds (a budget that is missed
fails the suite) and print a `PERF <what>: <n> us (budget <m> us)` line.
`commands.test` drops them with `-i res://tests/performance`: gdUnit4 6.2.3
skips every suite whose source path contains the `-i` value (observed
2026-11-03: the perf suite is not discovered, the other 724 tests run). Run them
on their own:

```bash
godot --headless -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/performance --ignoreHeadlessMode -c
```

In CI the `performance` job of `tests.yml` runs that command with
`continue-on-error: true` and one retry, and writes the `PERF` lines to the job
summary: read the timings there, not just the job colour. First suite:
`tests/performance/rng_event_log/rng_event_log_perf_test.gd` (rng-event-log
story 010).

`tests/performance/match_rules/match_rules_perf_test.gd` (match-rules story
018) times `submit()` on the 56-pass Deathrattle chain, `legal_commands()` on a
7 v 7 full board, a 12-entry `hooks.fold`, and `clone()` + one `submit` on
every `tests/fixtures/match_states/` state, against boss-ai F7's planner node
budget. Each test asserts `median < 2 × budget` (AC-40's gate) and prints
median / p95 / max. Results and the release-template comparison:
`production/qa/perf-match-rules-<date>.md`. Two rules for timing a scripted
match:
- Build its fixtures with `tests/helpers/match_budget_fixtures.gd`. The
  blocking `tests/unit/match_rules/match_rules_hook_fold_budget_test.gd` runs
  the same fixtures for the deterministic half: step counts, list identity,
  entry counts.
- Set `TestEffectResolver.recording = false`, so a sample does not pay for the
  double's deep-copied call records. Keep a reference to any resolver whose
  evaluators a `HookRegistry` holds: a Callable does not keep its object
  alive, and a freed evaluator turns `fold` into a silent no-op.

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
--quit-after 5`) launches `run/main_scene`, which is
`res://src/scenes/main.tscn` since 2026-11-04 (boot-composition-root story 006):
its root calls `Boot.boot()` on the shipped data and shows the `RunShell`
stub (`main_menu`, or `data_error` on a `Failed` load). `boot.tscn` (the
display-only boot screen, main scene from 2026-11-03) stays as the capture-rig
scene. Verified 2026-11-04: `timeout 60 godot --headless --quit-after 5` exits
0 and prints no `SCRIPT ERROR`. Keep the `timeout`: the command exits 0 even on
a parse error, so read its output, and a missing main scene makes it hang.
`tests/integration/boot/boot_scene_test.gd` asserts the main-scene setting and
loads the boot scene; `main_scene_test.gd` covers the `RunShell` states and
the debug `--boot-fail-fixture=<name>` override without booting the autoload.

## Run and observe (Linux/CI)

`.claude/docs/run-and-observe.md` is the procedure; `tools/capture.sh` is the
Linux/CI implementation of its Godot row:

```bash
bash tools/capture.sh <scene-res-path> <out-dir> [frames]
bash tools/capture.sh res://src/scenes/boot.tscn production/qa/evidence/<story-slug>
# → prints production/qa/evidence/<story-slug>/01-<scene-basename>.png
CAPTURE_LABEL=02-data_error bash tools/capture.sh res://src/scenes/main.tscn <out-dir> 60 -- --boot-fail-fixture=boot_data_error
# → <out-dir>/02-data_error.png; the arguments after `--` reach the scene's OS.get_cmdline_user_args()
```

It runs the command observed to work on this container
(`docs/architecture/spikes/2026-11-03-engine-probes.md`, Probe C):
`xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --windowed --resolution
1280x720 --rendering-driver opengl3 --write-movie <dir>/f.png --quit-after 60
res://<scene>.tscn`, keeps the **last** frame as `01-<scene-basename>.png`,
deletes the other frames and the `.wav`, and exits non-zero when Godot failed
(3) or when the frame is a single colour (4, a blank capture — checked by a
dependency-free PNG reader run with `python3 -I`). `frames` defaults to 60;
raise it for a scene that animates in.

Things to know:

- **CI evidence is Compatibility/llvmpipe output.** There is no Vulkan device
  under Xvfb, so every frame is rendered by the Compatibility (OpenGL 3)
  renderer on Mesa's software rasteriser, not the project's Forward+ renderer.
  2D `Control`/`Label`/`ColorRect` output matched expected colours exactly;
  anything Forward+-only (glow, HDR, 3D lighting) will differ or be absent.
- Frames are the project viewport size (1280x720), not `--resolution`.
- Never add `--headless`: `--headless --write-movie` crashes (exit 134).
- `production/.gdignore` keeps Godot from importing the evidence PNGs; the
  folder is versioned, so the kept frame is committed with the story.
- The first run of this rig is `production/qa/evidence/rig-check-2026-11-03/`
  (rig proof, not story evidence).
- Capturing an evidence frame does not replace looking at it: `Read` the PNG
  and compare it to the acceptance criteria (run-and-observe step 4).

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
| `match_budget_fixtures.gd` | `MatchBudgetFixtures` | Match-rules story 018 budget fixtures, as an instance: `make_chain_engine` + `chain_command` (the 56-pass Deathrattle chain), `make_full_board_engine` (7 v 7, a 10-card hand), `make_fold_registry` / `make_hooked_engine` (12 `modify_damage` entries), `engine_for(fixture)` (a `tests/fixtures/match_states/` state replayed from `start`, with story 017's pool and scripts), `deathrattle_passes(events)`. |
| `run_factory.gd` | `RunFactory` | R1 `make_run_state` (invariants hold by default), `make_draft_record`, `apply_bundle_pick` / `apply_treasure_pick`, `make_offer`, `make_match_summary`, the 6/6/4 fixture boss pool, `band_of`, `deck_size_at_floor`, `effective_treasure_floors`, `validate_invariants` / `assert_invariants`. |
| `treasure_fixtures.gd` | `TreasureFixtures` | The treasures GDD fixtures: `records()` (the 20 T8 records in `tests/fixtures/data/treasures_v1.json`), `database(ids)` (a `Ready` `CardDatabase` over them, or over a subset such as `MVP_IDS`, through the real pipeline), `make_boss_test_taxman()`. Exercised by `tests/unit/treasures/`. |
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
`Run GdUnit4 Tests` job — never the `Performance budgets (non-blocking)` job,
which runs `tests/performance/` with `continue-on-error` and uploads
`gdunit4-perf-report`.

### Content validate command

After gdUnit4 the same job runs the content validate command (content CN-6.3,
story 007):

```bash
godot --headless --path . -s res://tools/content/validate.gd [-- --data-root res://assets/data/]
```

It loads the data root through `DataLoader` + `CardDatabase` with the
validator map `Boot` registers (read from a fresh, never-booted `boot.gd`
instance), prints `ValidationReport.to_text()` and a summary line (load ms
next to `data_load_budget_ms`, an observation), and exits **0** `Ready`
(warnings printed), **1** `Failed`, **2** could not run (no such root, a bad
argument). It runs the editor binary, a debug build, so a pending owner's
`W_VALIDATOR_PENDING` row is a **warning** and the shipped data exits 0. A
release binary makes those rows errors: the same data would exit 1 until
`Boot.PENDING_CONFIG_OWNERS` / `PENDING_RECORD_OWNERS` are empty.
`tests/unit/content/` covers the command core in process;
`tests/integration/content/content_validate_process_test.gd` observes the
exit codes as a child process.

### Export is not run in CI (yet)

The Windows export (`commands.build` in `project.yaml`: `godot --headless
--path . --export-release 'Windows Desktop' build/windows/deckdelve.exe`) is
**not** part of `tests.yml`. The workflow runs `bash tools/setup.sh` without
`EXPORT_TEMPLATES=1`, so the runner has no export templates and the export
would fail there. The preset (`export_presets.cfg`, versioned on purpose — the
`.gitignore` un-ignores it; it holds no credentials) and the build command are
verified locally on Godot 4.7.2 (2026-11-03): `--export-release` and
`--export-pack` both exit 0; the first export after a fresh import once exited
134 after writing a complete file, the same first-run flakiness as `--import`
above, so a CI export job should run `--import` first and retry once. Adding an
export job means running `EXPORT_TEMPLATES=1 bash tools/setup.sh` (about 1 GB
download, 2 GB unpacked) and uploading `build/windows/` as an artifact.
`run/main_scene` is `res://src/scenes/boot.tscn` since 2026-11-03, so an
export now launches into the boot screen (the export itself was not re-run
after that change).
