# Control Manifest

> **Engine**: Godot 4.7.2 (pinned 4.7; GDScript; Forward+; Godot Physics 2D)
> **Last Updated**: 2026-11-04
> **Manifest Version**: 2026-11-04
> **ADRs Covered**: ADR-0001, ADR-0002, ADR-0003, ADR-0004, ADR-0005, ADR-0006, ADR-0007, ADR-0008, ADR-0009, ADR-0010, ADR-0011
> **ADRs Left Out**: None (11 of 11 Accepted)
> **Status**: Active — regenerate with `/create-control-manifest update` when ADRs change
> **Review**: TD-MANIFEST skipped — Lean mode (`review_mode: lean`, skill-gates=skip)

`Manifest Version` is the date this manifest was generated. Stories embed it when
they are written, and `/story-readiness` compares a story's version with this one
to find stories written against old rules. It always equals `Last Updated`: the
same date, for different readers.

This manifest is a programmer's quick reference taken from the Accepted ADRs, the
technical preferences and the engine reference docs. For the reason behind a rule,
read its ADR. Rules are extracted from each ADR's Decision (required), Alternatives
Considered (forbidden), Performance Implications (guardrails) and Engine
Compatibility (API constraints) sections only.

**Layer map used here** (the ADR's own `Layer` row): Foundation = ADR-0001, 0002,
0003, 0004, 0010 · Core = ADR-0005, 0006, 0007, 0008 · Presentation = ADR-0009,
0011. An ADR whose rules govern another layer's code (e.g. ADR-0008's `RunMachine`
in Feature, ADR-0001's UI channels in Presentation) has those rules repeated there.
Rows citing a `DD-xx` come from `design/design-decisions.md` (decisions the code
now enforces); rows citing a review come from the dated ADR Status errata.

**Changed in 2026-11-04** (regeneration after the sprint-4 errata; tell the team,
above all the new Forbidden rows): Boot responsibilities (gate condition 12,
`production/epics/boot-composition-root/boot-responsibilities.md`); ADR-0001 G2b
comment-line drop; ADR-0002 id-sorted fingerprint and the `ai_profile` 7b adapter;
ADR-0003 `fork_points`, root-only `stream()` names, `RngStream.copy()`; ADR-0005
in-primitive hooks (synchronous, re-entry fault, Discover refused); ADR-0006
`BossAI.plan_task`; ADR-0007 queue-entry shape, `player_hero_set`, `choice_made`
cause; ADR-0008 `MatchQuery` in the rules tier; the `RulesEngine.clone()`
contract; DD-X15, DD-X16, DD-X17; performance budgets from `project.yaml`.

---

## Foundation Layer Rules

*Applies to: `src/core/**` (data, rng, log, save, boot), engine start-up, evidence capture*

### Required Patterns

- **Every class under `src/gameplay/**`, `src/ai/**` and `src/core/**` `extends RefCounted`** (records may be plain Dictionaries with `to_dict()`/`from_dict()`); every collaborator arrives through `_init(...)` or an explicit `bind(...)` — source: ADR-0001
- **Only `src/core/**` touches `FileAccess`, `DirAccess`, `RandomNumberGenerator` and `user://`**; `src/core/log/` and `src/core/save/` are the only openers of `user://` — source: ADR-0001, ADR-0003
- **`Boot` (`src/core/boot.gd`, `extends Node`, **no `class_name`** — on 4.7.2 `class_name Boot` hides the autoload and fails to parse; ADR-0001 erratum 2026-11-03) is the one autoload and a lazy composition root**: `_ready()` does nothing; `boot(overrides)` is idempotent and returns `BootResult`; `services()` returns a plain `Services` bag `{card_database, profile_store, meta: MetaApi, settings_bus}`; `project.godot [autoload]` contains exactly `Boot` (gate G4) — source: ADR-0001
- **Boot responsibilities are exactly the "Boot does" rows of `production/epics/boot-composition-root/boot-responsibilities.md`** — MVP: lazy, idempotent `boot(overrides)` (a second call re-runs nothing, logs and ignores its overrides) running step 2 `CardDatabase.load(_collect_validators())`, step 3 `MetaStub` or the `meta` override (`Services.profile_store` stays `null`), step 4 the Meta implementation's own `settings_bus`; overrides checked against `OVERRIDE_KEYS` (`meta`, `card_database`; unknown key or wrong type logged, not used); `services()` only to scene roots and debug loaders; read-only `booted`; `BootResult.load_status` a `StringName`. Later, with their epics: each owner's validator line replacing its `PENDING_*_OWNERS` name, Meta's heartbeat / debounce `Timer`s and `release_lock()` exit hook started in `boot()`, the `MetaFacade` one-line switch, debug-loader override keys appended to `OVERRIDE_KEYS`, `bindings` → `InputMap` (Alpha). **A new duty is an ADR change, not a refactor** — source: ADR-0001 D4, ADR-0004 D6/D8/addendum item 2, ADR-0011 D4 (gate condition 12; guards TD-001, TD-009)
- **Scene roots (`MatchView`, `RunShell`, `main.tscn`) and `*_debug_loader.gd` are the only non-test callers of `Boot.services()`**; they pass services down by argument, never re-fetch deeper in the tree — source: ADR-0001
- **Interfaces with two implementations are `@abstract` base classes** (`MetaApi`, `Screen`, `Presenter`, `PlannerTask`); every override of a typed method ends in an explicit `return` (4.7 rule) — source: ADR-0001, ADR-0004, ADR-0006, ADR-0009, ADR-0011
- **Every rules file passes `.claude/scripts/godot-parse-check.gd` on its own** (no autoload present) — source: ADR-0001
- **Tests under `tests/unit/**` construct rules objects with `TestRngService`, `TestEventLog` and factory records directly**, never through `Boot` — source: ADR-0001, ADR-0003
- **All game data is JSON under `assets/data/`, loaded by one `CardDatabase` through `DataLoader`** from the code-owned `FILE_MANIFEST` (DD-T01 rows: `{name, class, record_type, required, owner}`); a `.json` not in the manifest is `W_UNKNOWN_FILE`; every read of `assets/data/*.json` in `src/` goes through `CardDatabase` — source: ADR-0002
- **Read `config(<name>)` once in the owner's `_init(...)` (or `bind`) and keep the reference** — source: ADR-0002
- **Parse with `JSON.new()` + `parse(text)`** (instance form, for `get_error_line()` / `get_error_message()`); a `null` from `FileAccess.open` reports `get_open_error()` as `E_MISSING_FILE` — source: ADR-0002, ADR-0004
- **Validate in the nine CR-5 stages with the closed code set**; `SCHEMA_VERSION_CURRENT = 1` is a `const` in `DataLoader`; both older and newer `schema_version` fail; offline migration lives in `tools/` — source: ADR-0002
- **Register a validator for every record field and every externally owned config file** via `load(validators: Dictionary)` (`{effects, ai_profile, unlock, treasure: Callable, configs: {<name>: Callable}}`); stage 7a calls config validators as `call(body, db)`, stage 7b calls record validators as `call(host_kind, host_id, value, db, configs)`; a missing validator is `E_DELEGATED` in every build type; every validator is a `static func`; tests inject `func(...): return []` stubs explicitly. **Record validators that need a config body are 7b adapters registered at `Boot`**: `effects` → `EffectValidator.validate_effects(…, configs["card_effects"])`, `ai_profile` → `BossAI.validate_ai_profile(host_kind, host_id, value, db, configs)` over the pure core `BossAI.validate_profile_key(key, configs["ai_profiles"])` — source: ADR-0002, ADR-0007 (ADR-0002 erratum 2026-11-04)
- **Freeze and fingerprint at stage 9**: sort every record list by id, `make_read_only()` recursively on every record and config body, compute `data_version` with one `HashingContext` (`HASH_SHA256`) over `name` + `JSON.stringify(body, "", true, true)` per manifest row in CR-1 order, `finish().hex_encode().substr(0, 16)`, hashing each body **after** the id sort (record order inside a file never changes `data_version`; known answer for `tests/fixtures/data/fingerprint/` on 4.7.2 Linux: `4667ce6e5d01302f`); `data_version` is always derived — source: ADR-0002 (erratum 2026-11-03, card-database 007)
- **Queries are pure reads on the frozen snapshot**; unknown id or config name returns `null` + `push_error`; data faults are `ValidationReport` entries; `load()` failure is visible (`state() == Failed`, `data_error` screen, validate command exits 1) — source: ADR-0002
- **Treat every returned Dictionary/Array as read-only**; a system that mutates takes `duplicate(true)` first (plain containers) — source: ADR-0002, ADR-0005
- **`effects[]`, `passive` and config bodies are plain JSON with no code references** — source: ADR-0002
- **`reload()` builds a new snapshot and swaps atomically in debug builds; returns `E_NOT_SUPPORTED` in release** — source: ADR-0002
- **`export_presets.cfg` keeps `include_filter="assets/data/*.json"`**; the smoke check asserts `data_version()` is non-empty in an exported build — source: ADR-0002
- **`RngService` / `RngStream` (`src/core/rng/`) and `EventLog` (`src/core/log/`) are concrete `RefCounted` classes constructed by `RunMachine` / `MatchDriver` and by tests directly** — source: ADR-0003
- **One `RandomNumberGenerator` per stream, `seed` set once** to `stream_seed(run_seed, name)` (F2) or `fork_seed(parent_draw, parent_name, label)` (F3) — FNV-1a 64 + SplitMix64 finaliser in signed `int` with `>>>` emulated; `randi32()` (= `RandomNumberGenerator.randi()`) is the only generator call; `stream(name)` is memoised; `fork(label)` consumes one parent draw on first call and is memoised. **`stream()` accepts root names only** (`ROOT_STREAM_NAME_PATTERN` `^[a-z]+(_[0-9]+)?$`): a `/` name is refused (assert in debug, `push_error` + `null` in release, no stream created) — `/` names come only from `fork()`; `run_seed` and `data_version` are read-only — source: ADR-0003 (erratum 2026-11-03, code review)
- **Snapshot and restore by reseed-and-discard**: `snapshot()` = `{run_seed, data_version, streams: {name: draws}, fork_points: {fork name: parent draws at fork}}` (`run_seed` an int in memory; `snapshot_to_json_dict()` persists `run_seed_hex`); `restore()` replays each fork at its recorded parent position, clears every fork memo, and rejects a `data_version` mismatch, another run seed or malformed entries with `ERR_INVALID_DATA`; `snapshot()` is refused between `begin_command()` / `end_command()` — source: ADR-0003 (erratum 2026-11-03, rng-event-log 003)
- **Copy a stream only with `RngStream.copy()`**: same name / seed / `forked_at`, reseeded and advanced `draws` outputs, fork memo carried as a copy of each child; takes no draw and shares nothing with the original — source: ADR-0003 Decision 3 / F5 (MR-017 code review S7, 2026-11-04; `src/core/rng/rng_stream.gd`)
- **64-bit values cross JSON as 16-hex strings** (`run_seed_hex`, any hash; `profile_id` as 32 hex); small integers are coerced back with `int()` on load — source: ADR-0003, ADR-0004
- **`EventLog.append(type, payload, cause_seq)` is the only writer**: stamps `seq` (1-based) and `turn`, stores `type` as `String`, deep-copies `payload`, notifies subscribers synchronously in registration order on the calling thread; returns `-1` when sealed — source: ADR-0003
- **Emit exactly one event per state mutation, after the mutation, with `cause_seq` = the outer event's `seq` during nested resolution** — source: ADR-0003
- **Diagnostics (`command_rejected`, `ai_decision`, `ai_plan_aborted`, `ai_fault`, `run_warning`) share the log with `payload.diagnostic = true`** — source: ADR-0003
- **Subscribers are synchronous, main-thread, by-value lambdas**; subscriber code that accumulates state closes over a Dictionary/object — source: ADR-0003
- **Overflow**: at `max_match_events = floor(log_memory_budget_bytes / avg_event_bytes)` append `log_overflow{cap, seq}`, emit `overflowed`, accept exactly one more event (Match Rules' `match_ended{result: fault, reason: event_cap}`), then sealed; `max_events`, `keep_match_logs`, `avg_event_bytes` come from `config("rng_event_log")` at the composition root — source: ADR-0003
- **Draw only while a command is being processed**; every primitive consumes exactly its F4 draw count — source: ADR-0003
- **`to_json()` = `JSON.stringify(dict, "\t")` with the `{log_schema_version, engine_version, data_version, run_seed_hex, scope, floor, events[]}` header**; logs go to `user://logs/<run_id>/floor_<n>_attempt_<k>.json` when `keep_match_logs`, and to `user://logs/faults/…` always on `log_overflow`, through `AtomicFileWriter` with `make_dir_recursive_absolute` first — source: ADR-0003
- **Profile format**: `user://profile.json`, UTF-8, `JSON.stringify(dict, "\t")`, `schema_version` built first and read by key; nothing pickled (`var_to_str` / `store_var` unused) — source: ADR-0004
- **Every file under `user://` is written through `AtomicFileWriter.write()`** in the W1–W9 order: `make_dir_recursive_absolute` → open `.tmp` WRITE → `store_string() == true` **and** `get_error() == OK` (after write and after `flush()`) → `close()` → size check → `rename_absolute(final, bak)` (retry once after `remove_absolute(bak)`) → `rename_absolute(tmp, final)` onto an absent path → `write_seq += 1`; any failure before W8 deletes the `.tmp` and leaves `profile.json` / `profile.bak` untouched; one retry after `io_retry_ms` (250) then `E_IO` — source: ADR-0004
- **Load order `profile.json` → `profile.bak` → fresh**; an unparseable file is copied to `profile.corrupt-<unix_ts>.json` (`DirAccess.copy_absolute`) before falling through; `schema_version > PROFILE_SCHEMA_VERSION` → `E_SCHEMA_NEWER`, `ReadOnly`, file never touched — source: ADR-0004
- **`ProfileLock` heartbeat**: `profile.lock = {instance_id, pid, heartbeat_at}`; a live lock (younger than `lock_stale_s`, 90) → `E_LOCKED`, profile `ReadOnly`, every mutator returns `E_READONLY`; `Boot` owns the `Timer` children for the heartbeat (`lock_heartbeat_s`, 30) and the settings debounce, and handles `NOTIFICATION_WM_CLOSE_REQUEST` / `_exit_tree` → `release_lock()`; timers start in `boot()`, not `_ready()` — source: ADR-0004
- **Migrations are `static func migrate(d: Dictionary) -> Dictionary` in `src/core/save/migrations/profile_v{k}_to_v{k+1}.gd`**, pure, one unit test each, applied in sequence then one atomic write; `PROFILE_SCHEMA_VERSION` is the one code literal — source: ADR-0004
- **Mutators (`save_active_run`, `clear_active_run`, `archive_run`, `ack_notification`, `reset_profile`) write synchronously on the main thread**; `set_setting` is debounced `settings_write_debounce_ms` (500); the run archive `user://runs/<run_id>.json` is written **before** the profile, its failure logged `run_warning{run_record_not_kept}` — source: ADR-0004
- **Every save knob comes from the `knobs` Dictionary the composition root built from `config("profile_defaults")`** — source: ADR-0004
- **Error vocabulary mapped once in `src/core/save/save_errors.gd`** (`E_IO` = `ERR_CANT_CREATE`, `E_READONLY` = `ERR_LOCKED`, `E_RANGE` = `ERR_PARAMETER_RANGE_ERROR`) — source: ADR-0004
- **The `RECOVERED_BAK` banner text ("restored from backup; the last save may be missing") is the sanctioned durability wording** — source: ADR-0004
- **Shipped renderer stays Forward+** (`project.godot` unchanged) — source: ADR-0010
- **UI/Visual evidence on Linux is produced only by `tools/capture.sh <scene> <out-dir> [frames] [-- <args>]`** (xvfb, `--rendering-driver opengl3` passed explicitly, `--write-movie`, `--quit-after ≥ 60`, last frame retained at 1280x720); use `--anim-speed=instant` or `--pause-at=<seq>` so the last frame is the intended state; every captured state is reached through a fixture (`--fixture`, `--run-ui-fixture`) and the real engine / `MetaStub`; stamp with `review-receipts.sh hash` and retain under `production/qa/evidence/<story-slug>/` — source: ADR-0010
- **Every UI story records a Windows playtest row confirming the Forward+ look** ("matches CI evidence / differs") — source: ADR-0010

### Forbidden Approaches

- **Never a service-locator autoload** (`Boot.card_database`, `Boot.rng` read on demand) — rules classes become untestable without the autoload and the parse check fails; it is TD-001 again — source: ADR-0001 (Alt 2)
- **Never a second autoload** — a sibling of `Boot` is an architecture change (new ADR); gate G4 — source: ADR-0001
- **Never give `Boot` game state, a rules tick, a `load()` (or any work) in `_ready()`, a per-service getter, a sibling autoload or a second composition path** — the "Boot never does" rows of `boot-responsibilities.md`, not to be softened; its script variables are exactly `booted`, `_services`, `_result` (`boot_composition_test.gd::test_boot_holds_no_game_state_fields`); no `_process` / `_physics_process` (`MatchDriver.tick()` is driven by `MatchView._process`) — source: ADR-0001 D4, Alt 1, Alt 2 (gate condition 12; TD-001, TD-009)
- **Never rules as `Node`s under a headless `SceneTree` with signals** — a node graph cannot be cloned thousands of times per boss turn and signals cannot be replayed from a log (TD-005) — source: ADR-0001 (Alt 3)
- **Never a second composition path** (`main.tscn` only, debug loaders re-implementing composition) — two paths is how TD-006 happened — source: ADR-0001 (Alt 1)
- **Never reference `Boot` or `Services` from `src/gameplay/**`, `src/ai/**`, `src/core/**` (minus `boot.gd`, `services.gd`, `boot_result.gd`; doc-comment lines `^\s*##` are not references)** — gate G3 — source: ADR-0001 (erratum 2026-11-03, code review)
- **Never `.tres` / `.res` `Resource` files with `@export` for game data** — no schema gate, needs the editor import step, nested-resource `duplicate()` deprecation, unreadable by tooling (TD-008) — source: ADR-0002 (Alt 1)
- **Never a per-system loader or any JSON parse outside `CardDatabase`** — `FileAccess.open("res://assets/data/…")`, `JSON.parse_string`, `JSON.new(` (any `JSON` instance, one line or two), `load("res://assets/data/…")` appear nowhere else in `src/` (`tools/content/validate.gd` composes `DataLoader` and is allowed) — cross-reference checks and the fingerprint need one parser — source: ADR-0002 (Alt 2)
- **Never one bundled `game_data.json`** — CN-6 batch ownership — source: ADR-0002 (Alt 3)
- **Never GDScript constants as game data** — source: ADR-0002 (Alt 4)
- **Never a numeric gameplay default in loader code** — `SCHEMA_VERSION_CURRENT` and `FILE_MANIFEST` are the only data-shaped literals in `src/core/data/`; a missing knob is `E_DELEGATED`, not a fallback — source: ADR-0002
- **Never call `config()` per frame, per command or per hook invocation** — source: ADR-0002
- **Never let a missing validator pass silently in any build**; `OS.is_debug_build()` does not relax it — source: ADR-0002
- **Never an accept-all placeholder validator in `Boot`**: an owner that has not shipped its validator is registered as a *pending* `static` validator returning one `W_VALIDATOR_PENDING` entry per config file (per host kind for a record key), a warning in a debug build and an error when `not OS.is_debug_build()`, so an exported load fails. **Release guardrail: `Boot.PENDING_CONFIG_OWNERS` and `Boot.PENDING_RECORD_OWNERS` are empty before a release build** (`/release-checklist` item; `tests/integration/boot/boot_validator_map_test.gd` pins the lists) — source: ADR-0002 Decision 4 (code review 2026-11-03, CDB-004)
- **Never `assert()` on data or throw in release paths** — source: ADR-0002
- **Never author a content-version string**; never depend on file order or authoring order — source: ADR-0002
- **Never express a card text in GDScript** — an inexpressible text is a card-effects GDD change — source: ADR-0002
- **Never a global seeded RNG** (`seed()` + `randi()` / `Array.shuffle()`) — one shared sequence shifts every later draw; TD-007 — source: ADR-0003 (Alt 1)
- **Never one `RandomNumberGenerator` with streams as counters** — streams are not independent; `fork` cannot be memoised — source: ADR-0003 (Alt 2)
- **Never copy a stream by reading its private fields (`_stream_seed`, `_make_child`) or its generator `state`** — use `RngStream.copy()` — source: ADR-0003 Decision 3 (MR-017 code review S7, 2026-11-04)
- **Never persist `RandomNumberGenerator.state` as the snapshot** — opaque, corrupted by `JSON.parse_string` above 2^53, ties the save to generator internals (permitted only as an optimisation a test proves equal) — source: ADR-0003 (Alt 3)
- **Never a hand-written PRNG in GDScript** — replay is scoped to one engine version by design — source: ADR-0003 (Alt 4)
- **Never Godot signals for event delivery** (`event_appended`) — connection flags can reorder; `subscribe(Callable)` keeps "once, in `seq` order, after append" testable (the `overflowed` signal is the one exception) — source: ADR-0003 (Alt 5)
- **Never trust `JSON.parse_string` to return an `int`** — it returns `float` for every number — source: ADR-0003, ADR-0004
- **Never a second event channel or a log filter in `src/core/log/`** — filtering is `MatchViewState`'s job — source: ADR-0003
- **Never draw in `_init`, in UI code, or in idle frames; never a "free" draw for convenience** — source: ADR-0003
- **Never append to or subscribe to the live log from a worker thread** — source: ADR-0003
- **Never hardcode `max_events`, `keep_match_logs` or `avg_event_bytes`** — source: ADR-0003
- **Never `ConfigFile` / `ResourceSaver` (`.tres`) for the profile** — a tampered file becomes a code path; not a readable bug-report attachment — source: ADR-0004 (Alt 1)
- **Never write the profile in place** (`FileAccess.open(final, WRITE)`) — `O_TRUNC` empties the file before the new bytes land — source: ADR-0004 (Alt 2)
- **Never rename `tmp → profile.json` over an existing file without the `.bak` rotation first; never `remove_absolute(final)` to make room** — Windows rename-over-existing semantics are NOT SOURCEABLE — source: ADR-0004 (Alt 3)
- **Never a background-thread save** — `run_log_cap` is the sanctioned lever if the 50 ms budget fails — source: ADR-0004 (Alt 4)
- **Never a socket or named mutex for single-instance detection** — the lock file is portable and testable headless — source: ADR-0004 (Alt 5)
- **Never `MetaStub` as an `in_memory` flag inside `MetaFacade`** — the seam is "inject a different object" — source: ADR-0004 (Alt 6)
- **Never delete, overwrite or migrate a file with `schema_version > PROFILE_SCHEMA_VERSION`; never delete a file that parsed but failed validation** — copy it to `profile.corrupt-<ts>.json` first — source: ADR-0004
- **Never ignore a `false` from `store_string()`; never write a partial profile to the final path** — source: ADR-0004
- **Never fall back to last-writer-wins on `E_LOCKED`** — source: ADR-0004
- **`ProfileStore` never holds a Node, a `Timer` or a `SceneTree` reference** — the heartbeat and exit hook are driven from `Boot` only — source: ADR-0004
- **Never hardcode `run_log_cap`, `io_retry_ms`, `lock_heartbeat_s`, `lock_stale_s` or the settings debounce** — source: ADR-0004
- **Never migrate in place inside the loader** — source: ADR-0004
- **Never claim power-loss durability in UI copy, docs or stories** — `flush()` / `close()` issue no `fsync` — source: ADR-0004
- **Never switch the project to `gl_compatibility`** without a product decision (supersede ADR-0010) — source: ADR-0010 (Alt 1)
- **Never install a software Vulkan ICD to capture on Forward+** — unverified; would still not show the D3D12 output — source: ADR-0010 (Alt 2)
- **Never `--headless` with `--write-movie`** (crashes, exit 134); never substitute a headless run for a screenshot — source: ADR-0010 (Alt 4)
- **Never rely on the silent Vulkan → OpenGL fallback** — pass `--rendering-driver opengl3` explicitly — source: ADR-0010 (Alt 5)
- **Never hand-write the `xvfb-run … godot` line in a story or skill; never build a view-state by hand for a screenshot; never treat the CI PNG as proof of Forward+ output** — source: ADR-0010
- **Never change `rendering/renderer/rendering_method`, `rendering/rendering_device/fallback_to_opengl3` or the viewport size** without superseding ADR-0010 (renderer) or noting the evidence-size change (viewport) — source: ADR-0010

### Performance Guardrails

- **Data load (`Boot.boot()` → `CardDatabase` `Unloaded → Ready`)**: ≤ `data_load_budget_ms` 200 (expected < 50 ms), synchronous at boot; frozen snapshot ≤ `data_memory_budget_mb` 4 — source: ADR-0002, ADR-0001
- **`RngStream.restore`**: ≤ 5 ms per stream at 10,000 draws — source: ADR-0003
- **`EventLog`**: 10,000 appends within the 80 ms AC (2026-11-04, DD-X19; was 50 ms); open match log ≤ `log_memory_budget_bytes` 2 MB (`max_match_events` 10,000 at defaults); typical 60–400 KB — source: ADR-0003
- **Profile save**: synchronous ≤ 50 ms at `run_log_cap` 200 (≈ 1.7 MB file, ≤ 2 MB); measured at Vertical Slice; `run_log_cap` drops if it cannot hold — source: ADR-0004
- **Evidence capture (offline tooling, not a frame budget)**: ~2.4 s for a simple scene on llvmpipe; a 60-frame full match scene expected in the 5–30 s range — source: ADR-0010

---

## Core Layer Rules

*Applies to: `src/gameplay/match/**`, `src/gameplay/effects/**`, `src/gameplay/run/match_driver.gd`, `src/ai/**`*

### Required Patterns

- **`RulesEngine` owns `MatchState`, `next_entity_id`, the phase machine, `win_loss_check`, the C10 loop (death check → `recompute_auras()` → queue pop), `RESOLUTION_STEP_CAP` and the 24 primitives**; it fires trigger points with `ctx.candidates` already in engine order — source: ADR-0007
- **`RulesEngine._init(db, rules_config, resolver)`; `start(config)` constructs `state.hooks = HookRegistry.new()` then calls `resolver.bind(self, config.player.hook_installers + config.boss.hook_installers)` as C3 step 1, before `on_match_start`**; `resolver.unbind()` when `phase` becomes `Ended` (breaks the `RefCounted` cycle) — source: ADR-0007, ADR-0005
- **`RulesEngine.clone()` contract**: taken between calls, never while resolving; deep-copies `MatchState` (including `state.effects`, `suspended_queue` and `state.hooks.copy()`); binds a fresh `EffectResolver.new(db, effects_config, player_hero_set)` (the live resolver's `effects_config()` / `player_hero_set()`) with no installers; a detached scratch `EventLog` (cap = the live log's remaining room); `rng_match` = `RngStream.copy()` of the live stream; a clone of an Ended match is Ended. **Every clone is ended with `end_match()` on every path, early returns included, then dropped** (clone and resolver form a `RefCounted` cycle) — source: ADR-0007 Decision 3 (erratum 2026-11-04), ADR-0006 (MR-015/017 code review 2026-11-04; `rules_engine.gd::clone`, `src/ai/scorer.gd`)
- **`EffectResolver._init(db, effects_config, player_hero_set = "")`**: composition passes the run hero's set (card-effects F4 `base(collectible)`); without it `pool: collectible` logs an error and offers nothing — source: ADR-0007 (erratum 2026-11-04)
- **`resolve(point, ctx)` returns the triggers it queues** as plain-data entries `{source_id, effect_id, point?, snapshot?}`; the engine fills a missing `snapshot` with a raise-time copy (a Deathrattle's death snapshot with `position`), appends them to Q, drops an entry whose source is no longer on the board / a hero / a weapon / in hand / in `resolving`, and runs a popped entry with `ctx.queued = true` and no `candidates` — source: ADR-0007 (errata 2026-11-03, DSL spike and match-rules 009)
- **`choice_made` is logged under the paused pass's `cause_seq`** (the same as its `choice_requested` / `discover_offered` / `discover_picked`), never cause 0 — source: ADR-0007 (erratum 2026-11-04)
- **`EffectResolver` mutates match state only through engine primitives, emits only through `engine.emit(type, payload)`, draws only through `engine.rng_match()`**; `RulesEngine.state()` is called only from `src/gameplay/effects/**` — source: ADR-0007
- **`EffectRuntime {once_marks, counters, per_turn, pending_choice}` is plain data in `MatchState.effects`** (Dictionaries, Arrays, ints, Strings); `clone()` copies it by value; `counter_changed` is emitted for each counter change — source: ADR-0007
- **One effect pass = one C10 step**; the resolver orders effects only *within* one entity (array order, definition before enchantment-granted) — source: ADR-0007
- **`EffectValidator.validate_effects(host_kind, host_id, effects, db, caps) -> Array` is `static`, pure, allocates its own report**; `caps` is the `card_effects` config body passed as a parameter; codes are the closed `E_FX_*` / `W_FX_*` set; `targeting_spec` is derived via `derive_targeting_spec`, memoised per `def_id` — source: ADR-0007
- **Tests inject the five-parameter accept-all stub `func(_k, _id, _fx, _db, _configs): return []` into `CardDatabase.load`** — source: ADR-0007, ADR-0002
- **`HookRegistry` is a plain `RefCounted` owned by `MatchState`**, created by `RulesEngine.start`, storing per hook point an `Array` of `HookEntry` dictionaries `{host_kind, host_id, side, effect_id, effect, state}` in installation order; it evaluates nothing itself — the resolver registers `set_evaluators(apply_value_hook, run_hook_effect)` at `bind` — source: ADR-0005
- **Hook catalogue = match-rules' table**: trigger points `on_match_start, on_turn_start, on_turn_end, on_card_played, on_minion_summoned, on_hero_damaged, on_draw`; value points `modify_cost, modify_damage, modify_heal, modify_starting_hand_size, modify_max_attacks`; gate points none in v1 (reserved: AND, short-circuit) — source: ADR-0005
- **In-primitive hooks (`on_draw`, `on_hero_damaged`, `on_minion_summoned`) run synchronously inside the primitive**, with no C10 loop between entries; a re-entry of the same hook point within one entry faults `resolution_overflow`; they cannot pause, so a Discover raised by one is refused with a logged reason (`push_error`), as is an `on_match_start` Discover (Setup has no `Choice` transition); step-boundary hooks still pause into `Choice` — source: ADR-0005 (errata 2026-11-03 match-rules 009, 2026-11-04 MR-016)
- **Ordering is installation order**: `MatchConfig.player.hook_installers` (treasures in pick order), each `effects[]` in array order, then `boss.hook_installers` (the passive) — source: ADR-0005
- **Value folds**: entry *n*'s output is entry *n+1*'s input (`delta` adds, `set` replaces, `mul` multiplies); the fold mutates and allocates nothing; **the engine clamps exactly once after the whole fold** with bounds from `config("match_rules")` (`HAND_SIZE`, `MAX_ATTACKS_CAP`, ≥ 0 for cost/damage/heal) — source: ADR-0005
- **`install(installer)` returns `false` and installs nothing on a duplicate `host_id`**; the engine appends `hook_install_skipped{host_id, reason: duplicate}` — source: ADR-0005
- **`side` is passed on every invocation**; the resolver evaluates the entry's `scope` relative to `entry.side` (scope is data) — source: ADR-0005
- **`copy()` is a by-value copy (`duplicate(true)` on plain containers) with evaluators unset**; `MatchState.clone()` calls it and the clone's resolver rebinds — source: ADR-0005
- **Hook-less treasure event triggers (`on_play`, `after_cast`, `on_attack`, `on_damage_dealt`, `on_heal`, `on_minion_died`, `on_hero_power`, `on_weapon_equipped`, non-hero `on_damage_taken`) are hero-slot observers queued by the resolver** — source: ADR-0005
- **Evaluator Callables take everything they need as arguments**; the resolver binds bound methods, not closures over mutable state — source: ADR-0005
- **Match-tier hook state (`once_per_turn` marks, counters) lives in `EffectRuntime` keyed by treasure id; run-tier state is the installer's read-only `state` blob returned by `hosts()`** — source: ADR-0005
- **The Boss AI plans on `RulesEngine.clone()` inside a `PlannerTask` and returns a `TurnPlan`** `{commands[], diagnostics[], expected_checksum, ai_draws, mode_trace}` (plain data); `MatchDriver.tick()` replays the commands into the live engine via `submit()` on the main thread, appending each `ai_decision` (`cause_seq = 0`, `diagnostic: true`) immediately before its command, and compares the event-type checksum after replay — source: ADR-0006, ADR-0008
- **The planner task Callable is built inside `src/ai/` by `BossAI.plan_task(sandbox) -> Callable`** (`func() -> Variant: return await boss_ai.plan_turn(sandbox)`, since `plan_turn` is a coroutine), so `match_driver.gd` stays `await`-free — source: ADR-0006 (erratum 2026-11-03, engine validation)
- **Planner randomness comes from the `ai_<floor>` stream's `sim_<turn>` fork; candidates come from the clone's `legal_commands()`**, never synthesised — source: ADR-0006, DD-X17 (MR-015/017 code review 2026-11-04; `src/ai/scorer.gd`)
- **Default `WorkerPoolPlannerTask`**: `WorkerThreadPool.add_task(callable, false, "boss_ai")`, one `is_task_completed(id)` per `tick()`, `wait_for_task_completion(id)` exactly once after completion; **fallback `TimeSlicedPlannerTask`** when `config("ai_profiles").runtime.planner_mode == "time_sliced"` or `--ai-sync`; **`ImmediatePlannerTask`** in `tests/unit/**` and the sim harness — source: ADR-0006
- **`BossAI` `await`s `planner.checkpoint()` between candidate evaluations (C4–C6 `score_all`) and between lethal-search nodes (C3)**; it is a no-op on the worker and a yield when time-sliced; `await` under `src/ai/**` is allowed only on the planner's own coroutines (`checkpoint()`, `plan_turn`, `score_all`, lethal search — gate G2b deny-list, ADR-0001/0006 errata 2026-11-03) — source: ADR-0006, ADR-0001
- **`poll()` is called at most once per frame and never again after it returned `true`**; replay is bounded by `replay_budget_ms` per tick (minimum one command) and carried to the next tick — source: ADR-0006, ADR-0008
- **A `concede` that arrives while a task is live is queued in a single slot** and returns `{accepted: false, rejection: {code: ENGINE_BUSY, detail: "concede_queued"}}`; `_on_task_done()` discards the task's result before submitting it — source: ADR-0006, ADR-0008
- **`forecast` runs on a clone at `PlayerTurn.Main` with no gate on player input**; a stale premise (`turn` / `phase` moved since the clone) is discarded silently; `ai_intent_shown` is appended by the driver on the main thread — source: ADR-0006, ADR-0008
- **Boss `Choice` with no task live → task `boss_ai.choose(sandbox, pending) -> int`, then `engine.submit(choose{issuer: boss, option_index})` on the main thread** — source: ADR-0008
- **`CardDatabase.reload()` returns `E_BUSY` while any `PlannerTask` is live** (debug builds) — source: ADR-0006
- **`MatchDriver.shutdown()` blocks on `poll()` until a live task ends and discards its result**; `MatchView._exit_tree` calls it (a `WorkerThreadPool` task cannot be cancelled) — source: ADR-0006, ADR-0008
- **`slice_ms`, `replay_budget_ms`, `planner_mode` come from the `ai_profiles.json` `runtime` block**, validated by `BossAI.validate_profiles_config` — source: ADR-0006
- **`MatchDriver` lives in `src/gameplay/run/`, obeys the rules tier (no Node, no autoload, no `await`), is the only caller of `RulesEngine.submit` from outside the rules tier, and stamps `issuer = "player"` on UI commands and `issuer = "boss"` on replayed plan commands** — source: ADR-0008
- **`MatchDriver._init(config, db, settings, planner_task)` builds, in order: `ProfileResolver.resolve(...)` → `EffectResolver.new(db, db.config("card_effects"), player_hero_set)` (third argument per the ADR-0007 erratum 2026-11-04) → `RulesEngine.new(db, db.config("match_rules"), resolver)` → `BossAI.new(boss_def, resolved_profile, band, config.rng_ai, op_values, config.log)` → `engine.start(config)` → `_after_engine_step()`** — source: ADR-0008
- **`_after_engine_step()` runs after every engine step and every replayed command** and reads `phase()` / `active_side()` / `pending_choice()` to schedule forecast, plan or choose tasks; on `Ended` it drops any pending plan, calls `engine.end_match()` and emits its own `match_ended(result)` only after the `match_ended` event has reached subscribers — source: ADR-0008
- **`subscribe(cb)` registers directly on the match `EventLog`; `events_since(seq)` is a pass-through; there is no event buffer** — the only replay is of commands — source: ADR-0008, ADR-0003
- **`query() -> MatchQuery` is built once over the live engine and answers at all times**; `MatchQuery` is a rules-tier read model (`class_name MatchQuery extends RefCounted`, `src/gameplay/match/match_query.gd`, Node-free, value copies); `MatchController` only forwards it; `is_planning()` is a UI hint ("boss thinking"), not a lock — source: ADR-0008 (erratum 2026-11-03, match-ui story authoring)
- **`submit` accepts only what `legal_commands()` lists**: a stray `position` (on a spell or weapon play) is rejected `INVALID_POSITION`, a stray `target_id` (on an untargeted card or hero power, or a Battlecry with no legal target) `ILLEGAL_TARGET`; C2's rejection set is closed. The one listed-vs-accepted gap kept is the Mulligan mask (only keep-all is listed; any mask is accepted) — source: DD-X17 (match-rules C2; MR-017 code review S6)
- **A hero swinging a weapon is the source of the `damage_dealt`** (for "whenever your hero deals damage" triggers, source-filtered hooks and damage stats); the weapon is never a damage source — source: DD-X15 (match-rules C8 step 5)
- **Settings during a match**: the driver snapshots settings at construction; `telegraph_mode` is applied via `on_setting_changed` → `boss_ai.set_telegraph_mode` when no task is live, else deferred to `_on_task_done()`; no other key reaches the rules — source: ADR-0008
- **`MatchDebugLoader` and the boss-ai sim harness build their driver through the same `driver_factory` with `ImmediatePlannerTask`, submit through `driver.submit`, and `tick()` until `is_planning()` is false** — source: ADR-0008, ADR-0009

### Forbidden Approaches

- **Never let the resolver own the C10 loop or the trigger queue** — the loop is match-rules' rule; Match Rules must be testable without Card Effects — source: ADR-0007 (Alt 1)
- **Never compile effects to GDScript Callables at load** — Callables cannot live in `MatchState`, so `clone()` and `restore(log)` break; a frozen record would carry code — source: ADR-0007 (Alt 2)
- **Never make the validator a `RefCounted` instance with cached database access** — instance state invites caching across `reload()`; purity becomes unprovable — source: ADR-0007 (Alt 3)
- **Never write match state directly from `src/gameplay/effects/**`** — gate G7: zero hits for `\.(board|hand|deck|graveyard|enchantments|keywords)\s*\.(append|erase|insert|remove_at|clear)\(|\.(damage_taken|base_attack|base_health|armor|mana_current|mana_max|frozen|silenced|attacks_used|durability|next_entity_id)\s*[+\-]?=|\[\s*["'](board|hand|deck|graveyard|enchantments|keywords)["']\s*\](\s+as\s+Array\s*\))?\s*\.(append|erase|insert|remove_at|clear)\(|\[\s*["'](damage_taken|base_attack|base_health|armor|mana_current|mana_max|frozen|silenced|attacks_used|durability|next_entity_id)["']\s*\]\s*[+\-]?=([^=]|$)` (subscript forms `x["field"] = …` / `(x["enchantments"] as Array).append(…)` added 2026-11-03, ADR-0007 erratum), `log\.append\(` and `RandomNumberGenerator` — source: ADR-0007
- **`EffectResolver` never calls `EventLog.append`, holds an `EventLog`, or touches a `RandomNumberGenerator`** — source: ADR-0007
- **Never share the live resolver with a clone** — source: ADR-0007
- **Never fork `rng_match` on a clone** — a fork the live stream has not taken costs the clone a parent draw live never takes, so the clone diverges; fork the `ai_<floor>` stream instead. **Never drop a clone without `end_match()`** — it leaks the engine↔resolver cycle — source: ADR-0003, ADR-0006, ADR-0007 (MR-015/017 code review 2026-11-04)
- **Never raise a Discover from an in-primitive hook or `on_match_start`** — it is refused; a card that needs one is a match-rules GDD change — source: ADR-0005 (erratum 2026-11-04)
- **Never accept and ignore an argument `legal_commands()` does not list; never add a C2 rejection code** (e.g. `INVALID_COMMAND`) — source: DD-X17
- **Never let an `aura` grant `stealth`** — the aura re-grants it after an attack and the attacker stays untargetable; `EffectValidator` rejects it (`E_FX_OP`); Stealth is printed or a one-shot grant only — source: DD-X16 (match-rules keywords, card-effects auras; MR-014 code review S2)
- **Never let an `aura` grant `divine_shield`** — the recompute re-grants it after every hit and the minion can never be damaged; `EffectValidator` rejects it (`E_FX_OP`); Divine Shield is printed or a one-shot grant only — source: DD-X25 (card-effects C5 `aura`, C10; card-effects 012 code review S2)
- **`EffectRuntime` never holds a Callable, a Node or an object reference** — source: ADR-0007
- **Never re-sort candidates across entities in the resolver; never call the death check or `recompute_auras()` between ops** — source: ADR-0007
- **Never add an `E_FX_*` / `W_FX_*` code without a card-effects GDD change; never read `targeting` from a stored field** (Card Database rejects it, CR-3) — source: ADR-0007
- **Never a global priority-ordered modifier manager** (the prototype's autoload with `Modifier` resources, ~36 hooks, `priority`, stacking, `Node`-typed parameters) — not owner-scoped, back-references the singleton, undefined tie order; porting is forbidden — source: ADR-0005 (Alt 1)
- **Never signals / an event bus for hooks** — value hooks need a return value and a defined order, and subscribers with behaviour cannot be copied by value in `clone()` — source: ADR-0005 (Alt 2)
- **Never compile treasure effects into card instances at `begin_match`** — cannot express reactive or conditional treasures, misses cards added mid-match, loses attribution — source: ADR-0005 (Alt 3)
- **Never let the registry evaluate the DSL itself** — DSL knowledge stays in `EffectResolver` (card-effects C9 ownership) — source: ADR-0005 (Alt 4)
- **`HookRegistry`, `HookEntry` and `HookInstaller` never reference `RulesEngine`, `EventLog`, `MatchState`, a Node, an autoload or the registry itself; an entry never has a method that calls back into its registry** (the TD-009 defect) — source: ADR-0005
- **Never sort hook entries or add a `priority`, `weight` or `order` field** — source: ADR-0005
- **Never add a hook point without a match-rules GDD change and a card-effects C2 row** — the prototype's 36-hook catalogue is not carried — source: ADR-0005
- **Never clamp inside the fold or inside a `modify_value` op** (`1 − 1 − 1 → 0`, not `0 → 0`) — source: ADR-0005
- **Never allocate in the fold** — no `duplicate()` of entries, no arrays built per invocation — source: ADR-0005
- **Never special-case "player only" in engine code** — scope is data — source: ADR-0005
- **Never append to a log from the registry** — source: ADR-0005
- **Never add hook-less treasure triggers to the registry "because they are treasure effects"** — source: ADR-0005
- **Never give an entry `is_enabled`, `duration_turns`, `stacks` or removal in v1**; future removal is `HookRegistry.remove_host(host_id)` called by the engine, never by an effect — source: ADR-0005
- **Never run `play_turn` against the live engine on the worker** — `match_ended` would be emitted and subscribers run off-thread; `forecast` could not run while the player acts — source: ADR-0006 (Alt 1), ADR-0008 (Alt 3)
- **Never a dedicated `Thread` per boss turn as the default** — more lifecycle to get wrong for the same result (kept as a drop-in `ThreadPlannerTask` behind the seam if the pool misbehaves on Windows) — source: ADR-0006 (Alt 2)
- **Never main-thread time-slicing as the sole implementation** — cannot bound one 5 ms `submit`; a band-3 turn would "think" for 0.7–1.3 s (retained as the fallback) — source: ADR-0006 (Alt 3)
- **Never compute one command per task and re-plan per command** — up to 30 round-trips per turn — source: ADR-0006 (Alt 4)
- **The worker is never handed the live `RulesEngine`, the live `EventLog`, `MatchDriver`, `MatchView`, `Boot` or any `Node`** — it receives `engine.clone()`, the `ai_<floor>` stream and the frozen `CardDatabase` — source: ADR-0006, ADR-0008
- **Nothing in `src/ai/**` ever calls `signal.emit`, `log.append` on a live log, `get_tree()`, `Engine.get_main_loop()` or any `Node` method** — the only log the planner writes is the clone's scratch log — source: ADR-0006
- **Never call `WorkerThreadPool.is_task_completed` after `wait_for_task_completion`** (`ERROR: Invalid Task ID`) — source: ADR-0006
- **Never continue replaying after a rejected command or a checksum mismatch** — append `ai_fault{reason: replay_divergence, at_index}` and submit `end_turn` — source: ADR-0006, ADR-0008
- **`tests/unit/**` and the sim harness never start a worker** (gdUnit4 runs headless; TD-012) — source: ADR-0006
- **Never Match UI owns the driver** (`MatchController` constructing the engine) — engine and AI construction in `src/ui/**`; headless simulation would need a UI; TD-006's shape — source: ADR-0008 (Alt 1)
- **Never `RulesEngine` drives the boss itself** (AI injected into the engine) — layer inversion; a synchronous `play_turn` inside `submit` blocks ≈ 60 ms; `clone()` would carry an AI — source: ADR-0008 (Alt 2)
- **Never suspend mid-match by serialising the event log** — deferred to Vertical Slice by run-structure R8.3; `RunMachine.suspend()` returns `E_BAD_PHASE` in `in_match`; no code saves, serialises or pauses a live match — source: ADR-0008 (Alt 4)
- **Never connect `RulesEngine.match_ended` in production** (it stays a unit-test convenience); never register a subscriber from a worker — source: ADR-0008
- **Never invoke a Boss AI entry point inline from `submit` or `tick`** — only through `PlannerTask.start` — source: ADR-0008
- **`MatchController` holds nothing but the driver reference** — source: ADR-0008

### Performance Guardrails

- **`RulesEngine.submit()`**: ≤ 5 ms worst case (50-step Deathrattle chain, includes resolver passes); **`legal_commands()`**: ≤ 2 ms (`targeting_spec` memoised per `def_id`) — source: ADR-0007, ADR-0001
- **Hook fold**: 12-entry fold < 0.05 ms; three treasures add < 2 ms per match; ≤ 12 entries per match (`entry_count()` asserted in debug); `copy()` ≤ 12 small `duplicate(true)` calls per Boss AI clone — source: ADR-0005
- **Boss AI main thread**: ≤ 2 ms per frame — one `is_task_completed` per frame plus replay bounded by `replay_budget_ms` (ADR-0006 default **2**; ADR-0008's Performance section says 4 — the data value in `ai_profiles.json runtime` governs; see Unresolved) — source: ADR-0006, ADR-0008
- **Boss AI worker**: 500 ms p95 target per planner run (A22), `play_turn` and `forecast` measured separately, off-thread; a run past the commit beat, which stretches over planning up to 500 ms (2026-11-04, DD-X23; was "the 300 ms banner beat"), shows "boss thinking"; budgets stay counts, never a runtime clock (boss-ai C9) (was 50 ms p95 per turn, ≈ 60–80 ms band-3 worst case — 2026-11-04, DD-X18) — source: ADR-0006
- **`clone()` + empty resolver memo per look-ahead node**: measured by the sim harness against `planner_target_ms` 500 p95 per planner run (was 50 — 2026-11-04, DD-X18; measured `t_sim` ≈ 0.37 ms release) — source: ADR-0007
- **Memory**: one extra `RulesEngine` clone per planned turn plus one `TurnPlan` (≤ 30 commands + ≤ 30 diagnostics); the per-def memo is bounded by the card pool (~120 + tokens); one driver graph per attempt, no event buffer — source: ADR-0006, ADR-0007, ADR-0008

---

## Feature Layer Rules

*Applies to: `src/gameplay/run/run_machine.gd`, `src/gameplay/draft/**`, `src/gameplay/treasures/**`, `src/gameplay/heroes/**`, `src/gameplay/meta/**`, config owners*

### Required Patterns

- **`RunMachine._init(db, meta, draft, treasures, run_config, driver_factory)`**; `begin_match()` builds `MatchConfig` per R3, creates a **fresh match `EventLog`** per attempt (`EventLog.new(max_match_events, "match", meta)`; the run-scope log is a different instance), calls the injected `driver_factory.call(config)`, and connects `driver.match_ended` **first** — source: ADR-0008, ADR-0003
- **`run_seed` comes from `RngService.run_seed_from_input(input, entropy)`**; the one permitted entropy call is Run Structure's run-creation command for the empty-seed branch, allow-listed by path in `tools/lint/no_global_rng.sh` — source: ADR-0003
- **`RunMachine._on_match_ended` runs `match_log.reduce_to_summary()`, `Treasures.collect_state(driver.hooks(), result)`, T6–T9 (save / status) and emits run-scope events before `RunShell` sees `match_view_finished`**; it drops `_driver` after `collect_state` — source: ADR-0008
- **A `RunState` of `in_match` found in a save is coerced to `pre_match` with `run_warning{coerced_status}`; the next `begin_match` increments `match_attempts[floor]` and restores the same `match_<floor>` / `ai_<floor>` streams at `draws = 0`** (R8.3) — source: ADR-0008
- **`Treasures.installers_for(treasure_ids, treasure_state)` is pure and idempotent, in pick order** (repeated id → first kept, caller logs `run_warning{duplicate_treasure}`; unknown `treasure_state.schema_version` → ignored, `run_warning{treasure_state_reset}`); `treasure_state` is read only in `installers_for` and written only in `collect_state` (v1 returns `{schema_version: 1, by_treasure: {}}`) — source: ADR-0005
- **`Treasures.pool(unlocked_keys, exclude_ids)` is the single membership predicate** over `CardDatabase.treasure_pool()`, id-ascending; `RewardDraft.init_run` calls it — source: ADR-0005
- **`Treasures.passive_installer(boss_def)` yields `[]` when `passive == null`, else one installer with `side "boss"`** — source: ADR-0005
- **`MetaApi` is `@abstract` in `src/gameplay/meta/meta_api.gd` with the full M1.3 surface, `signal unlock_granted(...)` and `var settings_bus: SettingsBus`**; two implementations: `MetaFacade` (`ProfileStore` + `UnlockEvaluator` + `StatsFold`) and `MetaStub`; `Boot.boot(overrides)` places one in `Services.meta`; the MVP ships `MetaStub`, the switch to `MetaFacade` is one line in `Boot` — source: ADR-0004, ADR-0011
- **`MetaStub._init(db, mirror = null)` is constructible with a `CardDatabase` alone**: `load_status()` = `FRESH`; every hero / treasure / unlock key reported unlocked; `save_active_run` / `load_active_run` / `clear_active_run` hold one record **in memory**; `archive_run` returns `{ok: true, unlocks_granted: []}`; `run_log()` / `pending_notifications()` = `[]`; `stats_for_hero` = zeros; `last_hero_id()` = null; settings from `config("profile_defaults")`, `set_setting` clamps per M9 and emits `settings_bus.settings_changed`; records every mutator in `calls`; `static from_fixture(db, fixture)` for `RunDebugLoader` — source: ADR-0011, ADR-0004
- **`RunMachine`, `RewardDraft` and `RunController` take `MetaApi` as a constructor argument and code against it only** — source: ADR-0004, ADR-0011
- **Every config owner reads its body once at construction and exposes a `static` validator registered at `Boot`** (`RulesEngine.validate_rules_config` (returns `ValidationReport` entry dictionaries; code-review fix 2026-11-03), `EffectValidator.validate_config`, `BossAI.validate_profiles_config`, `RunMachine.validate_config`, `RewardDraft.validate_config`, `Treasures.validate_config`, `Heroes.validate_config`, `MatchViewState.validate_config`, `RunController.validate_config`, `MetaProgression.validate_profile_defaults`, `ContentValidator.validate_config`, `EventLog.validate_config`) — source: ADR-0002
- **All Boss AI numbers (`slice_ms`, `replay_budget_ms`, `planner_mode`, profile values) come from `ai_profiles.json`** (boss-ai A29) — source: ADR-0006

### Forbidden Approaches

- **Never mutate `RunState` from `src/gameplay/treasures/`** — source: ADR-0005
- **Never re-implement the treasure pool membership predicate outside `Treasures.pool()`** — source: ADR-0005
- **Never a `MetaStub` that returns `E_READONLY` from persistence calls** — spurious `run_warning{save_failed}` toasts every MVP run; S23 suspend → Continue untestable — source: ADR-0011 (Alt 4)
- **Never block the Run UI epic on `ProfileStore` (no stub)** — the stub is required by run-ui U10 anyway — source: ADR-0011 (Alt 3)
- **Never downcast `MetaApi`; never reference `MetaStub` or `MetaFacade` by type outside `Boot`, debug loaders and tests** — source: ADR-0004, ADR-0011
- **Never a numeric gameplay literal in `src/ai/**` or run code** — source: ADR-0006
- **`RunDebugLoader` never builds a `MatchDriver`** (run-ui U10) — source: ADR-0008
- **Never save, serialise or pause a live match from `RunMachine`** — `suspend()` returns `E_BAD_PHASE` in `in_match` — source: ADR-0008

### Performance Guardrails

- **Run UI load budgets the Feature layer feeds**: `select_ready` ≤ 300 ms, `intro_ready` ≤ 300 ms; restart flow ≤ `restart_budget_ms` 5000 — source: ADR-0011
- **`MetaStub` memory**: one `RunRecord` and the settings record — source: ADR-0011

---

## Presentation Layer Rules

*Applies to: `src/ui/**`, `src/scenes/**` — rendering, UI, animation, input*

### Required Patterns

- **UI talks to the rules through exactly three channels**: commands in (`MatchController.submit(Command) -> CommandResult`, `RunController.intent(name, args)`), events out (`subscribe(Callable)` / `events_since(seq)` delivering `{seq, turn, type, payload, cause_seq}` in order), queries out (`MatchQuery.*`, `RunMachine.read_model()` — value copies only); presenters are projections of events and render numbers from events, not queries — source: ADR-0001
- **`queue_free` appears only under `src/ui/`**, and in Match UI only for presenter children (number pops, tokens on death) after `apply_final` — source: ADR-0001, ADR-0009
- **`AnimationQueue`, `MatchViewState` and `AnimStep` are `RefCounted` with no Node reference**; their unit tests run headless with a fake clock — source: ADR-0009
- **The queue schedules, presenters tween**: every step ends when the queue's clock (`advance(delta)` from `MatchView._process`) calls `step.apply_final` (idempotent, authoritative); presenters subscribe to `step_started`, check `owns(entity_ids)`, create tweens with `create_tween()` on themselves, and kill them on `skipped` and on `apply_final`; no tween outlives its step — source: ADR-0009
- **`Tween.tween_await()` (4.7) only inside a presenter and only on the presenter's own signals**; it never decides when a step ends — source: ADR-0009
- **Lifts and presses on children of a `Container` use `Control.offset_transform_*` (4.7)** — source: ADR-0009, ADR-0011
- **`MatchViewState.apply(event) -> Array[AnimStep]` is pure**; `group_id` = the `seq` of the event's command root (walk `cause_seq` to 0); groups play FIFO, `parallel_ok` steps start with the step before them; > `COALESCE_THRESHOLD` (8) pops on distinct targets from one source coalesce; `d_eff = 0` if skipped or `instant`, else `d_base / SPEED_DIV[anim_speed]`; impact extras are queue-local clock multipliers dropped at `fast` or `reduce_motion` — source: ADR-0009
- **Boss-turn mode**: entered on `turn_started{side: boss}`, exited when `turn_started{side: player}` has drained; the commit beat (`intent_banner_s`) plays first; F4's `gap` and `k` are computed when the first action group would start; auto-skip when the total would exceed `max_turn_playback_s` — source: ADR-0009
- **`MatchController.submit` calls `queue.skip_all()` before `driver.submit`** (U4.7); `skip_all()` kills every live tween, runs the remaining `apply_final`s in order within one frame, drops queued SFX, cancels hit-stop / slow-down — source: ADR-0009
- **Every presenter implements `sync_report() -> Array[String]`; `MatchView._assert_in_sync()` runs after every drain in debug builds** (`OS.is_debug_build()`) — source: ADR-0009
- **Scene partition is one scene per presenter** (`match_view.tscn`, `hand_fan.tscn`, `board_row.tscn` ×2, `hero_panel.tscn` ×2, `targeting_arrow.tscn`, `choice_overlay.tscn`, `event_feed.tscn`, `banner.tscn`, `mulligan_screen.tscn`, `pause_menu.tscn`) plus shared `src/ui/common/card_frame.tscn`; `@abstract class_name Presenter extends Control` declares `bind`, `owns`, `on_step_started`, `apply_final`, `sync_report`; `InputRouter extends Node` maps mouse / keyboard → intent → `command_requested` — source: ADR-0009
- **`AnimationPlayer` is allowed only for authored, target-free clips** (end banner flourish, intent banner crossfade) on `BannerPresenter`, fire-and-forget under the queue's clock — source: ADR-0009
- **`gamma` (DD-X10) is one `CanvasModulate`** (under `match_view.tscn` and under `run_shell.tscn`) updated from `settings_changed`; **`text_scale` is one of three discrete theme-override sets (1.0 / 1.25 / 1.5)**, each with a retained `_ts150` fixture screenshot — source: ADR-0009, ADR-0011
- **`anim_speed`, `reduce_motion`, `action_delay_ms`, `text_scale`, `high_contrast_states`, `gamma`, volumes and `fullscreen` are read from `SettingsBus` (`settings_changed`) and applied live**; session-local defaults come from `config("profile_defaults")` via `MetaApi` — source: ADR-0009, ADR-0011
- **Every duration, threshold, count and geometry value comes from `config("match_ui")` (read once in `MatchView._ready`) or `config("run_ui")`** (`transition_ms.*`, `run_start_ms`, `toast_*`, `restart_budget_ms`, F4 geometry) — source: ADR-0009, ADR-0011
- **The focus ring is drawn from keyboard focus (`focus_entered` / `focus_exited`); `grab_focus()` on each screen's `default_focus()` after every transition; hover is a lift and never moves focus** (4.6 dual focus) — source: ADR-0009, ADR-0011
- **Mouse / keyboard events are identified by type (`InputEventMouseButton`, `InputEventKey`)** or `InputEvent.DEVICE_ID_MOUSE` / `DEVICE_ID_KEYBOARD` — source: ADR-0009, ADR-0011
- **`MatchDebugLoader` (debug builds only) reads `OS.get_cmdline_user_args()`** (`--fixture`, `--pose`, `--pause-at`, `--anim-speed`, `--ai-debug`), loads `tests/fixtures/match_ui/<name>.json`, calls `Boot.boot()`, builds a real `MatchDriver` with `ImmediatePlannerTask`, runs the commands, then `MatchView` projects `events_since(0)` — the same JSON drives `tests/integration/match_ui/` — source: ADR-0009
- **`MatchView`**: `set_controller(MatchController)`; `_process` → `controller.tick()` + `queue.advance(delta)`; projects `events_since(0)` then subscribes; `_exit_tree` → `controller.shutdown()`; emits `match_view_finished(result)` after the end banner (click or `MATCH_END_AUTO_S`) — source: ADR-0008, ADR-0009
- **`RunShell extends Control` is the root of everything outside a match**: children in draw order `ScreenStack`, `ToastLayer`, `TransitionLayer` (`ColorRect`), `CanvasModulate`; `_ready()` calls `Boot.services()` once, constructs `RunController`, subscribes to `screen_requested` / `match_requested` / `toast`, opens `main_menu` (or `data_error` on a `Failed` load); `ShellState` `{base, overlays, transitioning, committed}` is the only state it owns; screens instantiate from `SCREENS: Dictionary[StringName, PackedScene]`; an outgoing base is freed after the transition except `match` (hidden, not freed) — source: ADR-0011
- **`RunController` is the only talker**: holds `RunMachine`, `RewardDraft`, `MetaApi`, `CardDatabase`, `config("run_ui")`; implements the U2 intent → command map and the S1–S23 table as one `match` over `(ShellState, intent)`; subscribes to the run `EventLog` and `MetaApi.unlock_granted`; emits `screen_requested(id, read_model)` only from an event handler; **buffers run-scope events during `match` and applies them in `seq` order on `match_view_finished`** (S11); on `begin_match` emits `match_requested(driver)` and `RunShell` instantiates `match_view.tscn` with `MatchController.new(driver)` — source: ADR-0011, ADR-0008
- **`@abstract class_name Screen extends Control`** with `bind(read_model)`, `default_focus() -> Control`, `set_committed(on)` and `signal intent_requested(name, args)`; a screen that sent a terminal intent (`pick`, `start_run`, `begin_match`, `continue`) is `committed` and ignores input until swapped out or uncommitted by a rejection; re-`bind` on every read-model change — source: ADR-0011
- **`Transition` (`RefCounted`, `src/ui/common/transition.gd`) runs F2's `t_transition = base_ms[kind] × speed_factor[anim_speed]` as one `Tween` on `TransitionLayer`**, sets `ShellState.transitioning`, ends early on `skip`; while transitioning every intent except `skip` is dropped with `ui_intent_rejected{reason: transitioning}`; the outgoing base's input is cut by the recursive Control disable (4.5) — source: ADR-0011
- **`ToastLayer extends Control` owns the U5 queue**: enqueue from `run_warning` and both unlock channels; `ack_notification(key)` exactly once **when shown**; one visible toast for `t_toast = clamp(toast_base_ms + chars × toast_per_char_ms, toast_min_ms, toast_max_ms)`, paused while hovered / focused; `toast_queue_max` 8 dropping the oldest *warning* first; a toast may start only while `transitioning == false` and `base ∉ {match, run_start, data_error}`; toast text built from `kind + id` through `CardDatabase` names — source: ADR-0011
- **All user-facing text is a `tr()` key**; data text follows Card Database's key-or-`text.en` rule — source: ADR-0011
- **Settings are written only through `MetaApi.set_setting` and read only through `SettingsBus` / `get_settings()`**; `MatchView` and `BossAI` apply their own keys — source: ADR-0011
- **Keyboard**: `1` / `2` / `3` move focus to option *n* on three-option screens; `Esc` → `back` / `close` / `cancel`; gamepad uses `ui_accept` / `ui_cancel` and d-pad neighbours; each screen declares `focus_neighbor_*` — source: ADR-0011
- **`RunDebugLoader` (debug builds only) reads `--run-ui-screen=<id> --run-ui-fixture=<name>`, builds `MetaStub` from `tests/fixtures/run_ui/<name>.json`, calls `Boot.boot({meta: stub})` and opens the screen with `t_transition = 0`** — source: ADR-0011
- **Renderer-neutral 2D UI in v1** (ADR-0010 rule 6): custom shaders are `canvas_item` shaders only and are captured under both renderers before their story closes; line and outline widths are explicit (4.7 removed the antialiasing feather); theme resources, fonts and `text_scale` are renderer-neutral — source: ADR-0010, ADR-0009
- **`FeedPresenter` uses `RichTextLabel`; if images are inlined, `add_image()` / `update_image()` take `width_unit` / `height_unit`** (4.7 rename) — source: ADR-0009
- **A UI scene may print `RenderingServer.get_current_rendering_method()` / `get_current_rendering_driver_name()` / `get_video_adapter_name()` once in debug builds** so the log names the capture path — source: ADR-0010

### Forbidden Approaches

- **Never hold a `MatchState`, `RunState` or a live rules object in `src/ui/**`; never call `.submit(` outside `*_controller.gd`, `*_driver.gd` and the `*_view.gd` input path** — gate G5 — source: ADR-0001
- **Never `AnimationPlayer` / `AnimationTree` per presenter for data-driven steps** — the timeline would become the authority and durations would move into `.tres` files — source: ADR-0009 (Alt 1)
- **Never let the queue own the tweens or end a step on `Tween.finished`** — the queue would become a Node and a stalled tween would stall the display — source: ADR-0009 (Alt 2)
- **Never a single monolithic `match_view.tscn`** — Run UI could not reuse `CardFrame` / `PauseMenu`; the U1 ownership table would have no file boundary (TD-010) — source: ADR-0009 (Alt 3)
- **Never let presenters poll `MatchQuery` to render numbers** — the display could not lag the engine during boss-turn playback (U2 / U3, DD-T04) — source: ADR-0009 (Alt 4)
- **A presenter never stores a value the view-state does not have** (U1) — source: ADR-0009
- **A Tween is never what finishes a step** — source: ADR-0009
- **Never `await`, `Timer` nodes per step, or `Engine.time_scale` for timing or hit-stop** — source: ADR-0009
- **Never `position` / `scale` for lifts inside a `Container`** — the container resets them on re-layout — source: ADR-0009
- **Never hardcoded setting defaults; the UI never parses JSON itself** — source: ADR-0009
- **Never draw the focus ring from hover; never `event.device == 0` to detect mouse or keyboard** — source: ADR-0009, ADR-0011
- **Fixtures never contain hand-built view-states; `MatchDebugLoader` and `RunDebugLoader` are never in release exports** (CI greps the exported `.pck`) — source: ADR-0009, ADR-0011
- **Never `yield()`, string-based `connect`, `$NodePath` in `_process` (cache with `@onready` / `%Unique`), or untyped `Array` / `Dictionary` in signatures** — source: ADR-0009, ADR-0011
- **Never one scene per screen with `change_scene_to_packed` and an autoload holding run state** — TD-001 / TD-009 again, a second autoload, toasts could not survive a scene change (S-05) — source: ADR-0011 (Alt 1)
- **Never let screens call Run Structure / Meta directly with a thin event bus** — the S1–S23 table and the U4 lock would be re-implemented per screen (U1.2) — source: ADR-0011 (Alt 2)
- **`Boot` / `Services` appear under `src/ui/run/` only in `run_shell.gd` and `run_debug_loader.gd`**; screens and `RunController` never reference them — source: ADR-0011
- **A `Screen` never holds a `RunState`, `RunRecord`, `MatchDriver` or `MetaApi`** — it renders only from the `bind` read model and sends every action as `intent_requested` — source: ADR-0011
- **`RunController` never emits `screen_requested` from the command it just issued (U1.3); never queues a dropped intent** — an unlisted `(state, intent)` pair is dropped with `ui_intent_rejected{reason: bad_state}` — source: ADR-0011
- **The shell never changes screen while `MatchView` is up** — source: ADR-0011
- **An unlock toast is never dropped from the queue** and survives base transitions on `ToastLayer` — source: ADR-0011
- **Run UI never passes settings to Match UI** — both read `SettingsBus` — source: ADR-0011
- **Never a continuous `text_scale`** — source: ADR-0011
- **`MatchView` never reads `RunState`, navigates, or knows about floors** — source: ADR-0008
- **Never `WorldEnvironment` glow, HDR, tonemapping, SSR / SSAO, `AreaLight3D`, 3D viewports, `SubViewport` with 3D content, or any Forward+-only project setting in v1**; MSAA / FXAA / SMAA 2D stay off; gamma is never a colour-token change — source: ADR-0010
- **Never a custom shader that is not a `canvas_item` shader, or one that uses features absent in the Compatibility backend** — source: ADR-0010

### Performance Guardrails

- **Skip-all → display = view-state ≤ 100 ms** (a 300-step recorded stream on the min-spec machine) — source: ADR-0009
- **`MatchQuery.*` ≤ 2 ms each**, called only on hover / drag — source: ADR-0009
- **`advance(delta)` is O(active steps) per frame; `MatchViewState.apply` is O(1) per event; tween count ≤ steps in flight (parallel group ≤ 8 pops after coalescing)**; the queue holds at most one boss turn of steps (≤ 30 groups); feed buffer `FEED_MAX_LINES` 200 — source: ADR-0009
- **11 scenes preloaded by `match_view.tscn`**, measured against the `intro_ready` / `begin_match` budgets once scenes exist — source: ADR-0009
- **`select_ready` ≤ 300 ms and `intro_ready` ≤ 300 ms** (run-ui F1); the `SCREENS` registry preload happens at `RunShell._ready` inside the boot budget; restart flow ≤ `restart_budget_ms` 5000 — source: ADR-0011
- **`RunController.read_model()` is built per screen change, never per frame**; `run_log` pages are read on demand; the idle shell costs nothing per frame beyond the toast timer and an active `Transition` tween — source: ADR-0011
- **Rule 6 (no post-processing, no AA) keeps the shipped 2D frame cheap on both renderers** — source: ADR-0010

---

## Global Rules (All Layers)

### Naming Conventions

| Element | Convention | Example | Source |
|---------|-----------|---------|--------|
| Classes | PascalCase | `RulesEngine`, `HookRegistry` | `naming.classes` in project.yaml |
| Variables (and functions) | snake_case | `run_seed`, `legal_commands()` | `naming.variables` in project.yaml; technical-preferences.md |
| Signals/Events | snake_case, past tense | `match_ended`, `settings_changed`, `step_started` | `naming.signals` (`past_tense`) in project.yaml |
| Files | snake_case matching the class | `rules_engine.gd`, `hook_registry.gd` | `naming.files` in project.yaml |
| Scenes | snake_case matching the file | `match_view.tscn`, `run_shell.tscn` | `naming.scenes` in project.yaml |
| Constants | SCREAMING_SNAKE | `RESOLUTION_STEP_CAP`, `PROFILE_SCHEMA_VERSION` | `naming.constants` in project.yaml |

### Performance Budgets

| Target | Value | Source |
|--------|-------|--------|
| Framerate | 60 fps | `performance.target_fps` in project.yaml |
| Frame budget | 16.6 ms | `performance.frame_budget_ms` in project.yaml |
| Draw calls | 500 (provisional until the first `/perf-profile`, gate entry condition 10) | `performance.draw_call_limit` in project.yaml |
| Memory ceiling | 1024 MB (provisional, as above) | `performance.memory_ceiling_mb` in project.yaml |
| Enforcement | `warn` | `performance.enforce` in project.yaml |

Per-system budgets live in the layer sections above and in `docs/registry/architecture.yaml` → `performance_budgets` (7 entries, all from ADRs).

### Approved Libraries / Addons

- **gdUnit4 v6.2.3** — approved for automated tests (installed at `addons/gdUnit4`, enabled in `project.godot`; runner `res://addons/gdUnit4/bin/GdUnitCmdTool.gd`; `commands.test` in project.yaml) — source: technical-preferences.md §Testing
- No other third-party library or addon is approved. technical-preferences.md §Allowed Libraries / Addons reads "[None configured yet]"; adding one is a technical-preferences change — source: technical-preferences.md

### Forbidden APIs (Godot 4.7.2)

These APIs are deprecated, renamed or removed for Godot 4.7.2. Only the rows that apply to what this project builds (a 2D, desktop-only, Forward+ card game UI with no 3D, tilemaps, navigation, skeletons or post-processing) are listed; the rest are left out or scoped below.

| Deprecated | Use instead | Since | Applies to |
|---|---|---|---|
| `yield()` | `await signal` | 4.0 | everywhere (and `await` is itself banned in the rules tier — ADR-0001 gate G2b) |
| `connect("signal", obj, "method")` (string-based) | `signal.connect(callable)` | 4.0 | everywhere |
| `instance()` / `PackedScene.instance()` | `instantiate()` | 4.0 | `src/ui/**`, `src/scenes/**` |
| `OS.get_ticks_msec()` | `Time.get_ticks_msec()` (`Time.get_ticks_usec()` in `TimeSlicedPlannerTask`) | 4.0 | everywhere |
| `duplicate()` for nested **Resources** | `duplicate_deep()` | 4.5 | only if nested `Resource` trees ever appear — the project's plain Dictionary/Array copies use `duplicate(true)` and are unaffected (ADR-0002, ADR-0005) |
| `AnimationPlayer.method_call_mode` / `.playback_active` | `AnimationMixer.callback_mode_method` / `.active` | 4.3 | `BannerPresenter`'s authored clips (ADR-0009) |
| `RichTextLabel.ImageUpdateMask.UPDATE_WIDTH_IN_PERCENT`; `add_image()` / `update_image()` `width_in_percent`, `height_in_percent` | `ImageUpdateMask.UPDATE_WIDTH_UNIT`; `width_unit`, `height_unit` (`RichTextLabel.ImageUnit`) | 4.7 | `FeedPresenter` (ADR-0009) |
| `Texture2D` in `Shader.set_default_texture_parameter()` / `get_default_texture_parameter()` | `Texture` base type | 4.4 | when a custom `canvas_item` shader sets a default texture (ADR-0010 rule 6) |
| `$NodePath` in `_process()` | `@onready var` cached reference (or `%Unique`) | pattern | `src/ui/**` |
| Untyped `Array` / `Dictionary` | `Array[Type]`, typed variables | pattern | everywhere (ADR-0003, ADR-0009, ADR-0011) |
| `event.device == 0` to detect mouse or keyboard | `event is InputEventMouse` / `InputEventKey`, or `InputEvent.DEVICE_ID_MOUSE` / `DEVICE_ID_KEYBOARD` | 4.7 | `InputRouter`, Run UI screens (ADR-0009, ADR-0011) |
| Installing addons from the editor's AssetLib tab | The editor's Asset Store workspace | 4.7 | editor workflow (gdUnit4 updates) |

Left out as not applicable: `TileMap`, `VisibilityNotifier3D`, `YSort`, `Navigation2D` / `Navigation3D`, `EditorSceneFormatImporterFBX`, `get_world()`, `Skeleton3D.bone_pose_updated`, `EditorSceneFormatImporter.IMPORT_*`, manual post-process viewport chains → `Compositor` (ADR-0010 forbids post-processing in v1), `GodotPhysics3D` → Jolt (3D only; `engine.physics` is Godot Physics 2D). See **Unresolved** for entries whose applicability could not be told.

Source: `docs/engine-reference/godot/deprecated-apis.md` (last verified 2026-10-17).

### Required Engine Patterns (Godot 4.5–4.7)

From `docs/engine-reference/godot/current-best-practices.md`; every row is a post-cutoff fact the model does not know:

- **An override of a typed method inherits its return type and needs an explicit `return`** (4.7) — applies to every `MetaApi`, `Screen`, `Presenter`, `PlannerTask`, `ValidationReport` override and every test double — source: current-best-practices.md §GDScript (4.7); ADR-0001, 0002, 0003, 0004, 0005, 0006, 0009, 0011
- **Lambdas capture locals by value** — share state through a Dictionary, Array or object; event subscribers and evaluator Callables take their inputs as arguments; a rest parameter `func(...args)` connects to a signal with any arity — source: current-best-practices.md §GDScript (4.5+); ADR-0001, 0003, 0005, 0008
- **`@abstract` classes and methods** for bases that must be inherited; an abstract method has no body — source: current-best-practices.md §GDScript (4.5+); ADR-0001
- **Variadic rest parameters are `...name`, last, typed `Array` or untyped** (`values: Variant...` and `...values: Array[int]` do not parse) — source: current-best-practices.md §GDScript (4.5+)
- **Writing one element of a packed array no longer calls the property's setter** (4.7) — assign the whole array where a setter must run — source: current-best-practices.md §GDScript (4.7)
- **`CanvasItem` lines are drawn without an antialiasing feather** (4.7) — set widths explicitly (`TargetingArrow`, outlines) — source: current-best-practices.md §Rendering (4.7); ADR-0009, ADR-0010
- **Dual-focus system** (4.6): mouse / touch focus is separate from keyboard / gamepad focus — focus ring = keyboard focus — source: current-best-practices.md §UI (4.6); ADR-0009, ADR-0011
- **`Control.offset_transform_*`** (4.7) for hover / press animation inside containers — source: current-best-practices.md §UI and Input (4.7); ADR-0009, ADR-0011
- **Mouse and keyboard events report `InputEvent.DEVICE_ID_MOUSE` / `DEVICE_ID_KEYBOARD`**, not device `0` (4.7) — source: current-best-practices.md §UI and Input (4.7)
- **`Tween.tween_await()`** (4.7) pauses a tween until a signal is emitted — presenter-internal only (ADR-0009) — source: current-best-practices.md §Animation (4.7)
- **Stretch settings**: this project keeps `display/window/stretch/mode = canvas_items` and `aspect = keep` at a 1280x720 base viewport (DD-T05); 4.7's new-project default `aspect = expand` is not adopted — source: current-best-practices.md §UI and Input (4.7); technical-preferences.md §Input & Platform; ADR-0010
- **`AudioStreamPlayer2D` / `3D` `area_mask` defaults to `0`** (4.7) — set to layer `1` where `audio_bus_override` areas are used — source: current-best-practices.md §Physics (4.7) *(scoped: only if audio areas are introduced; no audio ADR exists)*
- **ripgrep has no `gdscript` type** — use `rg --glob "*.gd"` (shell) or `glob: "*.gd"` (Grep tool), never `--type gdscript` — source: current-best-practices.md §Tooling; ADR-0001
- **Command line**: the test command is `godot --headless -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode` (exit 0 pass, 100 fail, 101 orphans / warnings, 103 headless refused, 105 parse error); a fresh clone needs `godot --headless --path . --import` first; `--check-only`, `--import` and `--quit-after` are **not** parse checks — the parse check is `godot --headless --path . -s res://.claude/scripts/godot-parse-check.gd -- res://<file>.gd` — source: current-best-practices.md §Command Line; ADR-0001

### Forbidden Patterns (technical-preferences.md)

- technical-preferences.md §Forbidden Patterns reads "[None configured yet — add as architectural decisions are made]". The ADR-derived forbidden rows above are the project's forbidden patterns until that section is populated — source: technical-preferences.md

### Cross-Cutting Constraints

- **Three tiers, one direction of dependency**: Presentation (`src/ui/**`, `src/scenes/**`, may hold Nodes) → Rules (`src/gameplay/**`, `src/ai/**`, `RefCounted`) → Foundation (`src/core/**`, `RefCounted`); dependencies point down only, events and signals travel up only; `Boot` is never named by rules code — source: ADR-0001
- **The rules tier never names** `Boot`, `Services`, `get_tree()`, `get_node()`, `$`, `%`, `queue_free`, `add_child`, `Node`, `Control`, `Tween`, `Timer`, `await` (except `await <planner>.checkpoint()` under `src/ai/**`), `preload` of a `.tscn`, or any global RNG call; rules state is plain data (`MatchState`, `RunState`); derived values are functions, never fields — source: ADR-0001
- **Grep gates (CI; `rg --glob "*.gd"`)** — each gate is run once against a deliberately broken file before it is trusted — source: ADR-0001 (G1–G6), ADR-0003 (lint), ADR-0007 (G7):

  | Gate | Pattern | Scope | Expected |
  |---|---|---|---|
  | G1 no Node in rules | `extends (Node\|Control\|Node2D\|CanvasItem\|Timer)` | `src/gameplay/**`, `src/ai/**` | 0 hits |
  | G2 no tree access in rules | `get_tree\(\|get_node\(\|\$[A-Za-z%]\|%[A-Z]\|queue_free\|add_child` | `src/gameplay/**`, `src/ai/**`, `src/core/**` (minus `boot.gd`) | 0 hits |
  | G2b no coroutines in rules | `\bawait\b` in `src/gameplay/**`, `src/core/**` (minus `boot.gd`); under `src/ai/**` the look-around-free deny-list `\bawait\b.*(get_tree|process_frame|physics_frame|create_timer|\.timeout|\.finished|tween|signal)` (ripgrep 14 rejects `(?!…)`; ADR-0001 erratum 2026-11-03); hit lines that are comments (`#` / `##`) are dropped, as G3 does (ADR-0001 erratum 2026-11-03, match-rules 003–005) | `src/gameplay/**`, `src/core/**`, `src/ai/**` | 0 hits |
  | G3 no composition root in rules | `\bBoot\b\|\bServices\b` | `src/gameplay/**`, `src/ai/**`, `src/core/**` (minus `boot.gd`, `services.gd`, `boot_result.gd`; hit lines that are doc comments, `^\s*##`, are dropped by a second filter — ripgrep has no look-around) | 0 hits |
  | G4 one autoload | `^[A-Za-z_]+=` lines under `[autoload]` in `project.godot` | — | exactly 1, named `Boot` |
  | G5 UI never mutates | `\.submit\(` outside `*_controller.gd`, `*_driver.gd`, `*_view.gd` input path; `MatchState\|RunState` type names | `src/ui/**` | 0 hits of state types; `submit` only via the controller |
  | G6 no global RNG in rules | `(^\|[^.\w])(randi\|randf\|randi_range\|randf_range\|seed\|randomize)\(\|\.shuffle\(\)\|pick_random\(` (ADR-0001 erratum 2026-11-03, code review) | `src/gameplay/**`, `src/ai/**` | 0 hits |
  | G7 no direct state writes from effects | the ADR-0007 field-write pattern, `log\.append\(`, `RandomNumberGenerator` | `src/gameplay/effects/**` | 0 hits |
  | Lint `tools/lint/no_global_rng.sh` | `(^\|[^.\w])(randi\|randf\|randi_range\|randf_range\|seed\|randomize)\(\|\.shuffle\(\)\|\.pick_random\(\|RandomNumberGenerator\.new\(` (regex, not fixed strings; ADR-0003 erratum 2026-11-03, code review) | `src/` minus `src/ui/`, `src/core/rng/`, and the allow-listed run-creation path | any hit fails the build |
  | Data-read gate | `FileAccess.open("res://assets/data/`, `JSON.parse_string`, `JSON.new(`, `load("res://assets/data/` | `src/` minus `src/core/data/` | 0 hits |

- **Threading**: everything runs on the main thread (input, player `submit`, `EventLog` subscribers, `AnimationQueue`, presenters, `ProfileStore` writes, data load) except the Boss AI planner, which runs over `RulesEngine.clone()` in a `PlannerTask` exposing only `start` / `poll` / `result`; no Node, autoload, signal emission or live-log append from the worker; the live engine is main-thread only — source: ADR-0006, ADR-0008, ADR-0003; architecture.md §Threading model
- **Gameplay values are data-driven**: every number comes from `assets/data/*.json` through `config(<name>)`, read once at the owner's construction; the only code literals are `SCHEMA_VERSION_CURRENT`, `FILE_MANIFEST` and `PROFILE_SCHEMA_VERSION` — source: ADR-0002, ADR-0004; coding-standards
- **64-bit values persist as 16-hex strings; integral floats are coerced to `int` on load** — binds every persisted 64-bit value in the project — source: ADR-0003, ADR-0004
- **Every Array is typed** (`Array[Dictionary]`, `Array[int]`, `Array[StringName]`) — source: ADR-0003, ADR-0005; deprecated-apis.md
- **Tests never go through `Boot`**: unit tests construct `RngService(seed_literal, "test")`, `EventLog`, `MetaStub`, `ImmediatePlannerTask` and factory records directly; suite-level determinism is `EventLogAssertions.replay_equal(a, b)` over a scripted sequence run twice; the F1/F2 seed pins run on every engine bump — source: ADR-0001, ADR-0003, ADR-0006, ADR-0011
- **Input**: mouse-first, every action also reachable by keyboard, gamepad a secondary (partial) path, no hover-only information; no touch; desktop only (Windows primary, Linux dev / CI); no web export — source: technical-preferences.md §Input & Platform
- **Evidence**: every player-observable change is launched and observed; the retained screenshot comes from `tools/capture.sh` and lives in `production/qa/evidence/<story-slug>/` with its stamp — source: ADR-0010; coding-standards
- **Knowledge risk is HIGH on every ADR** (4.5–4.7 are post-cutoff): re-validate on any engine upgrade or CI image change; `VERSION.md` and `docs/engine-reference/godot/` are checked before any version-qualified API claim; a NOT SOURCEABLE claim is closed by a probe or a test, never by training data — source: VERSION.md; ADR-0001 … ADR-0011 §Engine Compatibility

### Unresolved

Entries left out or scoped because whether they apply could not be told from the inputs:

- **`AudioEffectSpectrumAnalyzer.tap_back_pos` (removed 4.7)** — no audio ADR exists; left out until an audio decision names the effect chain — source: deprecated-apis.md
- **`DisplayServer.AccessibilityLiveMode` → `AccessibilityServer.AccessibilityLiveMode` (4.7)** — applies only if `Control.accessibility_live` is set (AccessKit, 4.5+); no ADR names it; scoped out — source: deprecated-apis.md
- **`VisibilityNotifier2D` → `VisibleOnScreenNotifier2D`** — 2D row, but no ADR uses an on-screen notifier; left out — source: deprecated-apis.md
- **Recursive Control disable (4.5)** — ADR-0011 relies on it for the transition input lock, but the exact property name is NOT SOURCEABLE from the reference; verify by `scene_runner()` test before the Run UI story closes — source: ADR-0011 §Engine Compatibility
- **`replay_budget_ms` default** — ADR-0006 Decision says 2 ms, ADR-0008 §Performance said "ADR-0006 default 4 ms" (corrected to 2 ms on 2026-11-03); the registry carries 2. The value is data (`ai_profiles.json runtime`); the manifest records 2 ms — source: ADR-0006, ADR-0008
- **`EffectResolver` third argument in ADR-0008** — ADR-0008 Decision 1 still shows `EffectResolver.new(db, db.config("card_effects"))`; the ADR-0007 erratum 2026-11-04 governs (pass `player_hero_set`). Text fix for ADR-0008 at its next revision — source: ADR-0007, ADR-0008
- **Clone fork memo wording** — `src/ai/scorer.gd`'s clone-discipline comment says a clone's fork memo is not carried; since `238df81` `RngStream.copy()` carries it (`rules_engine.gd::clone`). The rule "never fork `rng_match` on a clone" holds either way; the comment wants a one-line fix — source: MR-015/017 code review 2026-11-04
- **Export-preset exclusion of `*_debug_loader.gd`** — 4.7's preset syntax is NOT SOURCEABLE; CI greps the exported `.pck` listing instead — source: ADR-0009, ADR-0011
