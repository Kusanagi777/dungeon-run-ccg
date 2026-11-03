# ADR-0004: Save Format and Atomic Profile Write

## Status

Accepted

> **Who may move this to `Accepted`: the user, or `technical-director` on the
> user's explicit confirmation. No other agent, and no skill on its own.**
> Stories referencing a `Proposed` ADR are set `Blocked`, and epics require
> `Accepted`, so the field needs a named owner. `technical-director` is the role
> `coordination-rules.md` already escalates technical conflicts to, and an ADR is
> that decision made durable. This does **not** relax the rule that
> `Status: Accepted` is never set without explicit user confirmation.

Review record for this run (2026-11-03, `/architecture-decision`, headless, no
`AskUserQuestion` answerer):

- TD-ADR skipped — Lean mode (`review_mode: lean`; TD-ADR is not a PHASE-GATE).
- Engine validation: **NOT ASSESSED** — `godot-specialist` was not spawned (no
  `Agent` tool in this run). Engine claims are sourced from
  `docs/engine-reference/godot/` or observed in
  `docs/architecture/spikes/2026-11-03-engine-probes.md` Probe B (and probe E
  of ADR-0003 for JSON); the rest is marked `NOT SOURCEABLE` with the test that
  will prove it.
- GDD sync: checked 3 referenced GDDs (`meta-progression.md`,
  `run-structure.md`, `rng-event-log.md`); no naming inconsistencies — the M1.3
  persistence API names, the companion file names (`profile.bak`,
  `profile.json.tmp`, `profile.lock`, `profile.corrupt-<unix_ts>.json`,
  `user://runs/<run_id>.json`), the load statuses and error codes match. Two
  class names are this ADR's (architecture.md's), not the GDD's:
  `ProfileStore` and `AtomicFileWriter` / `ProfileLock`; the GDD names only the
  system. No GDD edit needed.
- Numbering fixed by `design/design-decisions.md` DD-X08.
- **TD review 2026-11-03 (acceptance pass over ADR-0001..0011):** `load_status`
  added to the `MetaApi` method list — `architecture.md` §API Boundaries and
  ADR-0011 already carry it; no decision changed. Dependencies ADR-0001 and
  ADR-0003 were Accepted first.
- **Accepted 2026-11-03 by technical-director** on the owner's standing approval of the project plan (plan approved 2026-11-03; "accept each" step). Owner may revert to Proposed.

## Date

2026-11-03

## Last Verified

2026-11-03 — against Godot 4.7.2, `docs/architecture/architecture.md` v1,
`design/gdd/meta-progression.md` (Approved) and spike Probe B (Linux, ext2/3
family filesystem under `user://`). The Windows half is unverified (see
Verification) and must be re-stamped when the gated test runs on the Windows
export.

## Decision Makers

Jacob (owner, standing approval for the Foundation ADR set); authored by the
`/architecture-decision` run; `technical-director` acceptance pending.
`engine-programmer` owns the Windows gated test (meta-progression Open Question
"Rename atomicity … ADR must cite the 4.7 docs" — the docs do not cover it; this
ADR cites the probe instead and says so).

## Summary

Deckdelve keeps one player profile (`user://profile.json`: settings, stats,
unlocks, run log and the one active run) that must survive crashes, disk-full,
downgrades and a second game instance without ever losing the previous good
copy (meta-progression M1, M4–M6, M8; run-structure R7/R8). This ADR fixes the
on-disk format (pretty JSON, `schema_version` first, 64-bit values as hex),
`ProfileStore` + `AtomicFileWriter` under `src/core/save/` with the write
sequence *tmp → flush/close → size check → rename json→bak → rename tmp→json*
built so that the one rename that must succeed targets an **absent** path,
`DirAccess.make_dir_recursive_absolute` before any write, a `ProfileLock`
heartbeat for second-instance detection, pure-function migrations, corrupt-file
preservation, and the `MetaApi` abstract seam with `MetaStub` for the MVP. It
accepts and documents the crash-durability gap (no fsync is reachable from
GDScript) and gates the Windows rename semantics behind a test on the Windows
export.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (pinned 4.7; `docs/engine-reference/godot/VERSION.md`) |
| **Domain** | Core (file I/O) |
| **Layer** | Foundation |
| **Knowledge Risk** | MEDIUM for `FileAccess` (the 4.4 `store_*` → `bool` change is sourced); **NOT SOURCEABLE** for `DirAccess.rename_absolute` atomicity, Windows semantics, and fsync — no Core module page under `docs/engine-reference/godot/modules/`. Linux behaviour is **observed** (Probe B); Windows is gated. |
| **References Consulted** | `VERSION.md`; `breaking-changes.md` (4.3→4.4 Core row `FileAccess.store_*` return `bool`; 4.6→4.7 GDScript rows); `current-best-practices.md` (§GDScript 4.5+/4.7, §Command Line); `deprecated-apis.md` (`Time` over `OS.get_ticks_msec`, typed Arrays); `docs/architecture/spikes/2026-11-03-engine-probes.md` Probe B (+ strace) and verified API list; ADR-0003 probe E (JSON) |
| **Post-Cutoff APIs Used** | `FileAccess.store_string() -> bool` (4.4 change, sourced; checked on every write). `@abstract class_name MetaApi` and `@abstract func` (4.5, sourced in `current-best-practices.md`); overrides of its typed methods end in an explicit `return` (4.7, sourced). Nothing else post-4.3. |
| **Verification Required** | (1) Linux: `rename_absolute(tmp, final)` over an existing target returns `OK` and is one `rename(2)` — **observed Probe B**; `FileAccess.open(WRITE)` into a missing dir → `null`, `get_open_error() == ERR_FILE_NOT_FOUND (7)` — **observed**; missing source → `ERR_FAILED (1)` — **observed**. (2) **Windows**: rename over an existing `.bak`, behaviour under an antivirus/indexer lock, error code — **NOT SOURCEABLE**, gated test `tests/integration/save/atomic_write_platform_test.gd` run on the Windows export before Vertical Slice. (3) No `fsync` on `flush()`/`close()` (strace) — **observed**; crash durability therefore not claimed (see Decision 5). (4) `JSON.parse_string` precision loss above 2^53 — **observed** (ADR-0003 probe E). (5) The 50 ms synchronous save at `run_log_cap` 200 — measured at Vertical Slice (meta-progression AC-27). |

> Knowledge Risk is MEDIUM / NOT SOURCEABLE: re-validate on an engine upgrade,
> and re-run the platform test on every new export template.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (rules / presentation split: `ProfileStore` is Foundation code reached only through constructor injection from `Boot`); ADR-0003 (the `snapshot()` shape and the hex rule for 64-bit values that travel inside `RunRecord.rng_snapshot` and `run_log`) |
| **Enables** | ADR-0011 (the `MetaApi` seam `RunDebugLoader` injects `MetaStub` through); ADR-0008 (`RunMachine` calls `save_active_run` at S1–S4 and `archive_run` at S5) |
| **Blocks** | Epic "Foundation — Profile & Meta persistence"; Run Structure stories that save (R7); Run UI settings / Continue / Run Log screens (they can proceed against `MetaStub` once this ADR is Accepted) |
| **Ordering Note** | Write order 0001 → 0002 → 0003 → **0004** → 0010. ADR-0002 is not a dependency: `profile_defaults` and the save knobs reach `ProfileStore` as constructor arguments resolved by `Boot` from `CardDatabase.config("profile_defaults")`; the store never names the database. The Windows gated test does not block acceptance — acceptance records the Linux proof and the gap; the test blocks the Vertical Slice gate instead. |

## Context

### Problem Statement

The prototype kept run state as untyped `GameManager.set_meta("player_gold", …)`
strings with no schema, owner or persistence contract (TD-009). The production
design (meta-progression M1–M9, Approved) specifies one JSON profile with a
schema version, an atomic write protocol, backup rotation, load-order recovery,
corrupt-file preservation, tamper-tolerant validation, a lock file for a second
instance, and pure migrations; run-structure R7/R8 adds the five save points,
"`in_match` is never saved" and the resume semantics. The GDD left exactly the
engine-facing questions to an ADR: whether `DirAccess.rename_absolute` is atomic
and replaces an existing file on each target OS, how the sequence behaves if
it is not, what durability a GDScript write can actually promise, and how the
`MetaApi` seam lets the MVP ship an in-memory stub (systems-index Circular
Dependencies, architecture.md decision 4). It must be decided before any Run
Structure or Run UI story because both code against the persistence API.

### Current State

No `src/core/save/` exists. `tests/helpers/run_factory.gd` produces `RunRecord`
Dictionaries with the R1 field names (`TODO(E2)` swap). Probe B (2026-11-03,
this container, Godot 4.7.2, Linux, `user://` on an ext2/3-family filesystem)
measured the rename and open behaviour in the Engine Compatibility Details
table. No Windows machine was available; the Windows export preset exists
(`export_presets.cfg`, `commands.build`).

### Constraints

- Rules purity (DD-T02, ADR-0001): `ProfileStore`, `AtomicFileWriter`,
  `ProfileLock` are `RefCounted`; the only Node involvement is `Boot` driving
  the heartbeat timer and the exit hook.
- Only `src/core/save/` and `src/core/log/` open files under `user://`
  (architecture.md Persistence paths).
- Synchronous save ≤ `max_save_ms` (50) at `run_log_cap` (200); profile ≤
  `max_profile_bytes` (2 MB) (meta-progression M4.3, F5).
- GDScript exposes no `fsync`; `FileAccess.flush()` is a user-space flush
  (Probe B strace). Durability across power loss cannot be promised in-engine.
- `JSON.parse_string` returns `float` for numbers and loses precision above
  2^53 (ADR-0003 probe E); `run_seed` is 64-bit.
- Windows rename-over-existing semantics are NOT SOURCEABLE and untested here.
- Every knob (`run_log_cap`, `io_retry_ms`, `settings_write_debounce_ms`,
  `lock_heartbeat_s`, `lock_stale_s`, `max_repairs_before_rebuild`,
  `archive_top_cards`, `max_profile_bytes`, `max_save_ms`) comes from
  `config("profile_defaults")` (DD-T01).

### Requirements

- Must implement the M1.3 persistence API with the exact names and return codes
  (`OK | E_IO | E_READONLY`, `load_profile().status ∈ {OK, RECOVERED_BAK,
  FRESH, FRESH_AFTER_CORRUPT, E_SCHEMA_NEWER, E_LOCKED}`).
- Must never leave the player without a complete profile file after any single
  failure or kill point in the write sequence (M4.1 "previous files intact").
- Must never delete or overwrite a file that parsed but failed validation, nor a
  profile with a newer `schema_version` (M5).
- Must detect a second running instance and degrade to `ReadOnly` (M6).
- Must apply `migrate_v{k}_to_v{k+1}` as pure dict → dict functions, including
  `RUN_RECORD_SCHEMA_VERSION` and `log_schema_version` inside `active_run` and
  `run_log[]` (M4.4).
- Must store `active_run` as an opaque blob (`RunRecord.to_dict()`), validated
  only by Run Structure (M5.4, R8).
- Must offer one `MetaApi` the MVP's `MetaStub` and the real facade both
  implement, so Run UI and Run Structure code does not change at Vertical Slice.

## Decision

**`user://profile.json` written by a staged-rename `AtomicFileWriter`, loaded
by a recovering `ProfileStore`, guarded by a heartbeat `ProfileLock`, behind an
`@abstract MetaApi` with an in-memory `MetaStub` for the MVP.** Concretely:

1. **Format.** UTF-8, `JSON.stringify(dict, "\t")` (pretty-printed per M1.1),
   `schema_version` as the first key (`JSON.stringify` on 4.7.2 emits sorted
   keys — observed — so the store builds the top-level Dictionary with
   `schema_version` first *and* the loader reads it by key, not position).
   Top-level shape is M1.2 verbatim. **64-bit values are hex strings**:
   `run_seed_hex` inside `rng_snapshot` and the run log header (ADR-0003 rule),
   `profile_id` (128-bit) as 32 hex characters; every other number is an
   integral `float` on read and is coerced with `int()` by the validator (M5.3
   type-check pass). Nothing is pickled (`rng-event-log` rule 14; `var_to_str`
   / `store_var` are not used — a text diff of two profiles must be readable in
   a bug report).
2. **Files and directory.** `user://profile.json`, `user://profile.bak`,
   `user://profile.json.tmp`, `user://profile.lock`,
   `user://profile.corrupt-<unix_ts>.json` / `profile.bak.corrupt-<unix_ts>.json`,
   `user://runs/<run_id>.json` (M8.2, `keep_run_records`) and ADR-0003's
   `user://logs/<run_id>/…`. `AtomicFileWriter.write(path, text)` calls
   `DirAccess.make_dir_recursive_absolute(path.get_base_dir())` **before** opening
   the temp file: Probe B showed `FileAccess.open(WRITE)` does not create parent
   directories (`null`, `get_open_error() == 7`) and `make_dir_recursive_absolute`
   fixes it (`0`, write OK).
3. **Write sequence (M4.1, ordered so the critical rename targets an absent
   path).**
   ```
   W1 text = JSON.stringify(profile, "\t")
   W2 make_dir_recursive_absolute(dir)                       # OK or E_IO
   W3 f = FileAccess.open(tmp, WRITE); null → E_IO (get_open_error logged)
   W4 f.store_string(text) == true and f.get_error() == OK   # 4.4 bool return, sourced
   W5 f.flush(); f.close()
   W6 FileAccess.open(tmp, READ).get_length() == text.to_utf8_buffer().size()  # cheap truncation check
   W7 if file_exists(final): rename_absolute(final, bak)     # the only rename OVER an existing file (the old .bak)
        on ERR_FAILED: remove_absolute(bak); retry once; still failing → E_IO (final untouched)
   W8 rename_absolute(tmp, final)                            # target ABSENT after W7 — no over-existing semantics needed
   W9 write_seq += 1 in memory; return OK
   any failure before W8: remove_absolute(tmp); previous final/bak untouched; one retry of W1–W8 after io_retry_ms (250); then E_IO
   ```
   Why this order is safe without knowing the OS's rename-over-existing rules:
   after W7 and before W8 the only window exists in which `profile.json` is
   absent, and M5's load order falls through to `profile.bak` → status
   `RECOVERED_BAK`, which is a complete, previous-good file. A kill at any other
   point leaves `profile.json` complete. The one rename that overwrites (W7 over
   an old `.bak`) is allowed to fail and be retried after deleting the old
   `.bak` — losing the backup-of-the-backup, never the profile. On Linux, Probe
   B observed both renames as single `rename(2)` calls returning `OK`, over an
   existing target too, so the fallback branch never runs there.
4. **Load order and corruption (M5).** `profile.json` → parse (`JSON.new().parse()`
   for line/message on failure — observed) → `schema_version` present and ≤
   `PROFILE_SCHEMA_VERSION` → validate/repair (M5.3) → `OK`. Unparseable or
   missing `schema_version`: copy to `profile.corrupt-<unix_ts>.json`
   (`DirAccess.copy_absolute`), then try `profile.bak` the same way
   (`RECOVERED_BAK`; its corrupt copy is `profile.bak.corrupt-<ts>.json`), then
   fresh (`FRESH` if neither existed, `FRESH_AFTER_CORRUPT` otherwise). Nothing
   is deleted. `schema_version > PROFILE_SCHEMA_VERSION` → `E_SCHEMA_NEWER`,
   `ReadOnly`, file never touched. `active_run` passes through as an opaque
   Dictionary; `RunRecord.validate()` is Run Structure's.
5. **Crash durability: accepted gap, documented, mitigated.** `flush()`/`close()`
   issue no `fsync`/`fdatasync` (strace, Probe B) and GDScript exposes none, so
   a power loss shortly after W8 can, on some filesystems and mount options,
   leave `profile.json` zero-length or stale. The project **does not claim**
   power-loss durability. Mitigations that are in-engine: the `.bak` rotation
   (a zero-length `profile.json` is unparseable → `.bak` loads as
   `RECOVERED_BAK`), `write_seq` for diagnosis, and the run archive under
   `user://runs/` written **before** the profile write (M8.2) so a lost
   `archive_run` is recoverable by hand. The banner text for `RECOVERED_BAK`
   ("restored from backup; the last save may be missing") is the honest UX.
   This is recorded in `docs/architecture/architecture.md`'s open questions by
   `/architecture-review` as closed-with-gap, and in the Pre-Production gate
   notes.
6. **Second instance (M6).** `ProfileLock` writes `profile.lock =
   {instance_id, pid, heartbeat_at}` at `load_profile()`; a live lock
   (`heartbeat_at` younger than `lock_stale_s`, 90) → `E_LOCKED`, profile
   `ReadOnly`, every mutator returns `E_READONLY`; a stale lock is taken over
   with a console line. The heartbeat (`lock_heartbeat_s`, 30) and the clean-exit
   delete need a tick source and an exit hook that `RefCounted` cannot have:
   **`Boot` owns a `Timer` child** that calls `profile_store.heartbeat()` and
   handles `NOTIFICATION_WM_CLOSE_REQUEST` / `_exit_tree` by calling
   `profile_store.release_lock()`. This is the one place a Node drives Foundation
   code, and it is the composition root, which ADR-0001 permits. `Boot` stays
   lazy: the timer starts in `boot()`, not `_ready()`. `OS.get_process_id()` and
   `Time.get_unix_time_from_system()` supply `pid` / `heartbeat_at` (pre-4.3
   APIs; `Time` per `deprecated-apis.md`).
7. **Migrations (M4.4).** `src/core/save/migrations/profile_v{k}_to_v{k+1}.gd`,
   each a `static func migrate(d: Dictionary) -> Dictionary` with no I/O and its
   own unit test; `ProfileStore.load_profile()` applies them in sequence when
   `schema_version < PROFILE_SCHEMA_VERSION`, then performs one atomic write
   (the pre-migration file becomes `.bak`). `RUN_RECORD_SCHEMA_VERSION` and
   `log_schema_version` inside `active_run` / `run_log[]` migrate in the same
   pass through functions Run Structure and RNG & Event Log own but this store
   calls; an entry with a *newer* inner version is kept opaque. `PROFILE_SCHEMA_VERSION`
   is the one code literal (card-database CR-5 exemption pattern).
8. **Save points and debounce.** `save_active_run` / `clear_active_run` /
   `archive_run` / `ack_notification` / `reset_profile` write synchronously on
   the main thread (M4.3 — no spinner; if F5 cannot hold 50 ms, `run_log_cap`
   drops). `set_setting` is debounced `settings_write_debounce_ms` (500) via a
   `Boot`-owned one-shot `Timer`; a `save_active_run` arriving while a debounce
   is pending flushes the pending settings in the same write. Writes are
   serialised by being synchronous (Edge Cases "run ends during a save"). The
   archive (`user://runs/<run_id>.json`) is written first, through the same
   writer, and its failure is logged `run_warning{run_record_not_kept}` without
   blocking the profile write.
9. **`MetaApi` seam.** `@abstract class_name MetaApi extends RefCounted`
   declares the full M1.3 surface (persistence subset **and** rules half:
   `is_hero_unlocked`, `unlocked_keys`, `unlock_progress`, `stats_for_hero`,
   `validate_unlock_defs`, …). Two implementations: `MetaFacade`
   (`src/gameplay/meta/meta_facade.gd`) composes `ProfileStore` + `UnlockEvaluator`
   + `StatsFold` (architecture decision 4); `MetaStub`
   (`src/gameplay/meta/meta_stub.gd`) is in-memory, loads a fixture Dictionary,
   reports every hero/treasure unlocked, returns `OK` from every mutator and
   records calls for tests. `Boot.boot({meta: stub})` selects it (run-ui U10,
   `RunDebugLoader`); the MVP ships `MetaStub` behind the same `Services.meta`
   field (systems-index gate condition). Overrides of `MetaApi`'s typed methods
   end in an explicit `return` (4.7 rule, sourced).

### Architecture Diagram

```
Boot (autoload, composition root)                       assets/data/profile_defaults.json
 │ boot(): ProfileStore.new(defaults, knobs, writer, lock)      │ config("profile_defaults") → defaults + knobs
 │        Timer(lock_heartbeat_s) → store.heartbeat()           ▼
 │        Timer(settings_write_debounce_ms) → store.flush_settings()
 │        WM_CLOSE_REQUEST / _exit_tree → store.release_lock()
 ▼
Services.meta : MetaApi ──► MetaFacade{ProfileStore, UnlockEvaluator, StatsFold}   (Vertical Slice+)
                       └──► MetaStub{in-memory profile, fixture}                  (MVP, RunDebugLoader)
                                        │
RunMachine ─ save_active_run(RunRecord.to_dict()) ─► ProfileStore ─► AtomicFileWriter.write(user://profile.json, text)
RunMachine ─ archive_run(record) ──────────────────►   │  (runs/<run_id>.json first, then profile)
RunShell ─ set_setting / ack_notification / reset ───►   │
                                                          ▼
   W1 stringify  W2 mkdir -p  W3–W5 tmp write+flush+close  W6 size check
   W7 json → bak (over old bak; retry after remove)  W8 tmp → json (target absent)
                                                          │
load_profile(): json → bak → fresh ; corrupt copies kept ; newer schema → ReadOnly ; lock → ReadOnly
                                                          ▼
                       SettingsBus.settings_changed(key, value) → Match UI / Boss AI / Run UI
```

### Key Interfaces

Signatures match `docs/architecture/architecture.md` §API Boundaries
(Foundation `ProfileStore`) and meta-progression M1.3 names.

```gdscript
# src/core/save/profile_store.gd — meta-progression M1.3 (persistence subset), M4–M6, M8
class_name ProfileStore extends RefCounted
func _init(defaults: Dictionary, knobs: Dictionary, writer: AtomicFileWriter, lock: ProfileLock, clock: Callable = Time.get_unix_time_from_system) -> void
func load_profile() -> Dictionary               # {status: OK|RECOVERED_BAK|FRESH|FRESH_AFTER_CORRUPT|E_SCHEMA_NEWER|E_LOCKED, profile, repairs: int}
func save_profile() -> Error                    # OK | E_IO | E_READONLY — atomic (M4); one retry after io_retry_ms
func save_active_run(record: Dictionary) -> Error; func load_active_run() -> Variant; func clear_active_run() -> void
func set_setting(key: StringName, value: Variant) -> Error   # OK | E_RANGE; debounced write
func get_setting(key: StringName) -> Variant; func get_settings() -> Dictionary
func flush_settings() -> Error                  # called by Boot's debounce timer or before another write
func archive_run(record: Dictionary) -> Dictionary        # {ok, unlocks_granted[]} — delegates fold/unlocks to MetaProgression (gameplay/meta); idempotent on run_id
func run_log(offset: int, limit: int) -> Array; func run_log_entry(run_id: String) -> Variant
func pending_notifications() -> Array; func ack_notification(key: String) -> void
func reset_profile(confirm_token: String) -> Error
func is_read_only() -> bool; func heartbeat() -> void; func release_lock() -> void
var settings_bus: SettingsBus                    # settings_changed(key, value)
const PROFILE_SCHEMA_VERSION: int = 1            # the one literal

# src/core/save/atomic_file_writer.gd — M4.1 write protocol; also used by EventLog archives (ADR-0003)
class_name AtomicFileWriter extends RefCounted
func write(final_path: String, text: String, backup_path: String = "") -> Error   # W1–W9; OK | ERR_CANT_CREATE (→ E_IO)
func last_error_detail() -> String              # which step, which Error code, for the console line

# src/core/save/profile_lock.gd — M6
class_name ProfileLock extends RefCounted
func _init(lock_path: String, stale_s: int, clock: Callable) -> void
func acquire(instance_id: String) -> Error      # OK (fresh or stale taken over) | ERR_LOCKED (live lock)
func heartbeat() -> void; func release() -> void

# src/gameplay/meta/meta_api.gd — the seam (architecture decision 4; systems-index Run ↔ Meta)
@abstract
class_name MetaApi extends RefCounted
# the whole M1.3 surface as @abstract funcs: load_profile, save_profile, save_active_run, load_active_run,
# clear_active_run, archive_run, is_hero_unlocked, is_unlocked, is_treasure_unlocked, unlocked_ids,
# unlocked_keys, unlock_progress, unlock_hint, set_setting, get_setting, get_settings, stats_for_hero,
# last_hero_id, run_log, run_log_entry, pending_notifications, ack_notification, validate_unlock_defs, reset_profile,
# load_status (OK | RECOVERED_BAK | FRESH | FRESH_AFTER_CORRUPT | E_SCHEMA_NEWER | E_LOCKED — architecture.md §Presentation; ADR-0011)
# src/gameplay/meta/meta_facade.gd  — class_name MetaFacade extends MetaApi  (ProfileStore + UnlockEvaluator + StatsFold)
# src/gameplay/meta/meta_stub.gd    — class_name MetaStub extends MetaApi    (in-memory; fixture-loaded; everything unlocked)

# src/core/save/migrations/profile_v1_to_v2.gd (first real migration, M4.4 worked example)
static func migrate(profile: Dictionary) -> Dictionary   # pure; no I/O
```

Error vocabulary: `E_IO` = `ERR_CANT_CREATE`, `E_READONLY` = `ERR_LOCKED`
(reused from the lock), `E_RANGE` = `ERR_PARAMETER_RANGE_ERROR`, mapped once in
`src/core/save/save_errors.gd` so callers compare constants, not literals.

### Implementation Guidelines

- Must write every file under `user://` through `AtomicFileWriter.write()`;
  must never call `FileAccess.open(path, WRITE)` on a final path directly.
- Must call `DirAccess.make_dir_recursive_absolute()` before the temp-file open
  and treat its non-`OK` as `E_IO`.
- Must check `store_string() == true` **and** `get_error() == OK` after the
  write and again after `flush()` (4.4 bool return, sourced); must never ignore
  a `false`.
- Must rename `profile.json → profile.bak` **before** `tmp → profile.json`, so
  the final rename targets an absent path; must never `remove_absolute(final)`
  to make room — the `.bak` rotation is the only permitted delete-and-retry, and
  only of the old `.bak`.
- Must leave `profile.json` and `profile.bak` untouched on any failure before
  W8 and must delete the `.tmp`; must never write a partial profile to the
  final path.
- Must never delete, overwrite or migrate a file with `schema_version >
  PROFILE_SCHEMA_VERSION`; must never delete a file that parsed but failed
  validation — copy it to `profile.corrupt-<ts>.json` first.
- Must serialise 64-bit values as hex strings and coerce integral floats to
  `int` on load; must never assume `JSON.parse_string` returns `int`.
- Must keep migrations pure (`Dictionary` in, `Dictionary` out, no I/O) with
  one unit test each; must never migrate in place inside the loader.
- Must treat `E_LOCKED` as `ReadOnly`: every mutator returns `E_READONLY`;
  must never fall back to last-writer-wins.
- Must drive the heartbeat and the exit hook from `Boot` only; `ProfileStore`
  must never hold a Node, a `Timer` or a `SceneTree` reference.
- Must take every knob from the `knobs` Dictionary the composition root built
  from `config("profile_defaults")`; must never hardcode `run_log_cap`,
  `io_retry_ms`, `lock_heartbeat_s`, `lock_stale_s` or the debounce.
- Must code Run Structure and Run UI against `MetaApi` only; must never
  reference `MetaStub` or `MetaFacade` by type outside `Boot`, debug loaders and
  tests.
- Must not claim power-loss durability in UI copy, docs or stories; the
  `RECOVERED_BAK` banner text is the sanctioned wording.

### Decision addendum (2026-11-03) — input remapping storage

Closes `TR-accessibility-requirements-001` (`design/accessibility-requirements.md`
Motor "Full input remapping", Standard tier, due Alpha; Open Question "a
`bindings` map in meta M9, or `InputMap` serialised to `user://bindings.cfg`
by Run UI?"). Recorded by the post-review fix pass under the owner's standing
approval; no other decision in this ADR changes.

1. **Key bindings persist in the profile settings record**, not in a second
   file. `settings.bindings: {action: [InputEvent as Dictionary]}` — one key
   per `InputMap` action name, each value the action's event list serialised
   as plain Dictionaries (type tag plus the event's own fields: keycode /
   physical keycode and modifiers for `InputEventKey`, button index for
   `InputEventMouseButton` / `InputEventJoypadButton`, axis and sign for
   `InputEventJoypadMotion`). No `Resource`, no `var_to_str` blob — the
   profile stays JSON-only under Decision 1, 64-bit values as hex.
   `profile_defaults.json` carries no `bindings` key; an absent or empty map
   means "engine defaults" (the `project.godot` `InputMap`). The `bindings`
   key is added to meta-progression M9 and DD-X07 (same date).
2. **Applied at Boot, after the profile loads.** `Boot.boot()` step 3 loads
   the profile; step 4 (`SettingsBus` created, settings published once) then
   applies `settings.bindings` to `InputMap` — `action_erase_events` then
   `action_add_event` per listed action, unknown action names ignored with a
   `profile_repaired`-style log line (M5.3 tamper tolerance). Actions not in
   the map keep their defaults. Rebinding at runtime goes through
   `set_setting("bindings", map)` like any other key (debounced per Decision
   8, flushed by the same `AtomicFileWriter` path — W1–W9 unchanged);
   `settings_changed{bindings}` is consumed by `Boot`, which re-applies the
   map, and by the Controls page for its display. `InputRouter` (match) and
   `RunShell` (run) read actions, never key codes, so no other code changes.
3. **`cancel` / Esc is never rebindable** — the pattern library "Standard
   Shortcuts" and accessibility-requirements Motor state the same exception.
   The Controls page omits `cancel` from the rebindable list; `ProfileStore`
   enforces it on write (a `bindings.cancel` key is dropped and logged, so a
   hand-edited profile cannot remove the one guaranteed key). LMB / RMB are
   likewise fixed.
4. **Schema rule.** Adding `bindings` to `settings{}` is an additive key with
   an absent-means-default reading, so it does **not** bump
   `PROFILE_SCHEMA_VERSION` on its own; M5.2 "unknown keys preserved, known
   keys clamped" already tolerates it in both directions. If the event
   serialisation shape ever changes, that is a `schema_version` bump with a
   `profile_v{k}_to_v{k+1}` migration under Decision 7 — never an in-place
   rewrite.
5. **Alternative rejected.** `InputMap` serialised to `user://bindings.cfg`
   (`ConfigFile`) by Run UI: a second file with its own corruption, lock and
   `.bak` story, outside the M4/M5 atomic path and the single-instance rule,
   and one that would not travel with a profile reset or the MVP `MetaStub`
   fixtures. One file, one write path.

## Alternatives Considered

### Alternative 1: `ConfigFile` / `ResourceSaver` (`.tres`) for the profile
- **Description**: Save a `Resource` subclass with `ResourceSaver.save()` or a
  `ConfigFile`.
- **Pros**: Built-in; typed properties.
- **Cons**: `ResourceSaver` can embed script paths and executes `.tres` loading
  code paths (a tampered file is a code path, not data); neither is a readable
  bug-report attachment; migrations become class-shape migrations; the GDD and
  DD-T01 fix JSON.
- **Estimated Effort**: Similar.
- **Rejection Reason**: M1.1 specifies JSON; rule 14 "nothing is pickled";
  `/security-audit` robustness later treats the file as untrusted text.

### Alternative 2: Write in place (`FileAccess.open(final, WRITE)`, no temp, no rename)
- **Description**: Truncate and rewrite `profile.json` directly, keeping a `.bak`
  copied beforehand.
- **Pros**: No rename semantics to worry about on any OS.
- **Cons**: `O_TRUNC` (observed in strace for `WRITE`) empties the file before
  the new bytes land; any failure between open and close leaves a zero-length
  or partial `profile.json`; the window is the whole 2 MB write, not a rename.
- **Estimated Effort**: Lowest.
- **Rejection Reason**: Exactly the failure M4.1 forbids; the `.bak` would save
  the day on every disk-full, which turns a rare path into the common one.

### Alternative 3: Rely on rename-over-existing being atomic everywhere (tmp → json directly, no `.bak` rotation first)
- **Description**: Write tmp, then one `rename_absolute(tmp, final)` over the
  existing profile; copy `.bak` separately.
- **Pros**: One rename; on Linux it is a single `rename(2)` returning `OK`
  (observed).
- **Cons**: Windows semantics NOT SOURCEABLE — if the rename over an existing
  file fails or is non-atomic there, the fallback is delete-then-rename, which
  opens exactly the window Alternative 2 has; the `.bak` copy doubles the write
  cost (2 MB copy) inside the 50 ms budget.
- **Estimated Effort**: Same.
- **Rejection Reason**: The chosen order (rotate `.bak` by rename first, then
  rename onto an absent name) needs no over-existing guarantee for the file that
  matters, and rotating by rename is free.

### Alternative 4: Background-thread save
- **Description**: Serialise and write on a `WorkerThreadPool` task (verified
  available, spike Probe A) to keep the main thread under 2 ms.
- **Pros**: No main-thread stall even if F5 is wrong.
- **Cons**: Serialisation must snapshot the profile Dictionary first (deep copy
  of up to 2 MB anyway); two in-flight writes must be ordered; failure
  reporting becomes asynchronous while Run Structure's R7 contract is a
  synchronous return code; M4.3 explicitly chooses synchronous with the cap as
  the lever.
- **Estimated Effort**: Higher.
- **Rejection Reason**: Premature; the GDD's budget is measured at Vertical
  Slice (AC-27) and `run_log_cap` is the sanctioned fallback. Recorded as the
  escape hatch if the measurement fails on the minimum spec (meta-progression
  Open Question).

### Alternative 5: Single-instance enforcement via a socket / named mutex instead of a lock file
- **Description**: Bind a local TCP port or use an OS mutex to detect a second
  instance.
- **Pros**: No stale-lock window after a crash.
- **Cons**: A port can be in use by anything else; GDScript has no named-mutex
  API; firewalls prompt on listen; M6 chose the lock file with a 90 s stale
  window and a "Retry" banner deliberately.
- **Estimated Effort**: Higher, platform-specific.
- **Rejection Reason**: M6.2's trade-off stands; the lock file is portable and
  testable headless.

### Alternative 6: `MetaStub` as a flag inside `MetaFacade` rather than a second `MetaApi` implementation
- **Description**: One class with an `in_memory: bool` switch.
- **Pros**: One file.
- **Cons**: The stub would carry the real class's dependencies (`ProfileStore`,
  evaluator, fold) into every Run UI fixture test; the seam that run-ui U10 and
  the systems-index gate condition require is "inject a different object", not
  "flip a flag"; `@abstract` base classes are sourced (4.5+).
- **Estimated Effort**: Same.
- **Rejection Reason**: Architecture decision 4 already chose the abstract
  seam; it is what lets the MVP ship without `ProfileStore` at all.

## Consequences

### Positive
- No single failure or kill point in the write sequence leaves the player
  without a complete profile file; the only window is covered by `.bak` with an
  honest banner.
- The sequence is correct without knowing any OS's rename-over-existing rule;
  the Windows unknown is reduced to "does the `.bak` rotation need the
  delete-and-retry branch", which the gated test answers without risk to the
  profile.
- TD-009's run-state half is closed: run state is a typed `RunRecord` blob
  owned by Run Structure, persisted through one contract, never `set_meta`.
- The MVP ships against `MetaStub` through the same `Services.meta` field the
  Vertical Slice swaps for `MetaFacade` — no Run UI or Run Structure code
  changes at that point.
- Every file under `user://` goes through one writer, so ADR-0003's logs and
  M8's archives inherit the mkdir, size check and error reporting.

### Negative
- No power-loss durability guarantee; documented and accepted. A player on an
  unusual filesystem may lose the last save (never more) and see the
  `RECOVERED_BAK` banner.
- Synchronous 2 MB pretty-printed write on the main thread; if the 50 ms budget
  fails on the minimum spec the lever is `run_log_cap`, not UX, and the escape
  hatch (Alternative 4) is a new story, not a flag.
- The 90 s stale-lock window after a crash makes the next launch within 90 s
  `ReadOnly` until "Retry" (M6.2, accepted by the GDD).
- `Boot` grows two `Timer`s and an exit hook; it remains state-free but is no
  longer purely a constructor.
- Pretty-printing costs ~15 % file size (F5) in exchange for diffable bug
  reports.

### Neutral
- Error constants are reused engine `Error` values mapped once; callers see
  `E_IO` / `E_READONLY` / `E_RANGE` names, not numbers.
- The Windows gated test is a Vertical Slice gate item, not an acceptance
  blocker for this ADR — acceptance records what was proven (Linux) and what
  is pending (Windows).

## Risks
- **Windows rename over an existing `.bak` fails or is non-atomic.**
  *Mitigation*: by construction only the `.bak` rotation renames over an
  existing file; the delete-and-retry branch (W7) handles a refusal; the gated
  platform test on the Windows export proves which branch runs; a failure of
  the *tmp → json* rename on Windows (target absent) would be a surprise and
  halts the Vertical Slice gate.
- **Antivirus / indexer holds `profile.json` open on Windows** so W7 fails
  transiently. *Mitigation*: the single `io_retry_ms` retry; `E_IO` surfaces as
  `run_warning{save_failed}` and the next save point retries (R7).
- **Power loss after W8 on a filesystem without ordered metadata** leaves a
  zero-length `profile.json`. *Mitigation*: `.bak` recovery, archive written
  first, banner; no claim made.
- **`JSON.parse_string` precision loss** corrupts a 64-bit field someone adds
  later as a bare int. *Mitigation*: hex rule in both ADRs; `RunRecord` round-trip
  test includes a seed above 2^53; the validator rejects a non-string
  `run_seed_hex`.
- **Save exceeds 50 ms at cap 200** on the minimum spec. *Mitigation*: AC-27
  measurement at Vertical Slice; lower `run_log_cap` / `archive_top_cards` in
  data; Alternative 4 as the structural fallback.
- **A second mutator fires during the debounce** and the settings write races
  the run save. *Mitigation*: writes are synchronous; `save_active_run` flushes
  pending settings into its own write.

## GDD Requirements Addressed

TR-IDs are the provisional ids from `docs/architecture/architecture.md`
§Technical Requirements Baseline; `/architecture-review` registers them.

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| meta-progression.md | TR-meta-progression-001 — M1: one `user://profile.json`, M1.2 shape, M1.3 API | Decision 1–2 (format, files), `ProfileStore` + `MetaApi` with the exact names and codes |
| meta-progression.md | TR-meta-progression-002 — M4: tmp → flush → rename to `.bak` → rename to `profile.json`; `E_IO` leaves previous files intact; pure migrations | Decision 3 (W1–W9 with the absent-target ordering and the one retry), Decision 7 (migrations as static pure functions) |
| meta-progression.md | TR-meta-progression-003 — M5: load order json → bak → fresh; corrupt copies kept; newer schema → `ReadOnly`; tamper tolerance with repairs logged | Decision 4; validator pass coerces/clamps and counts `repairs`; `max_repairs_before_rebuild` triggers the M7.5 rebuild through `MetaFacade` |
| meta-progression.md | TR-meta-progression-004 — M6: `profile.lock` heartbeat; second instance `ReadOnly`, mutators `E_READONLY` | Decision 6: `ProfileLock` + `Boot`-owned heartbeat `Timer` and exit hook |
| meta-progression.md | TR-meta-progression-005 — M9 / DD-X07: settings record, defaults from `config("profile_defaults")`, `settings_changed{key, value}` | `set_setting` / `get_settings` with debounce, `SettingsBus`; defaults injected by `Boot`; MVP in-memory via `MetaStub` |
| meta-progression.md | TR-meta-progression-006 — F5 / M4.3: ≤ 2 MB, synchronous save ≤ 50 ms at `run_log_cap` | Decision 8 (synchronous, cap as the lever); `W_PROFILE_SIZE` on load; measured at Vertical Slice |
| run-structure.md | TR-run-structure-004 — R7/R8: save points S1–S5 through Meta's API; `in_match` never saved; resume restores RNG snapshot and reopens the run log | `save_active_run` / `load_active_run` / `clear_active_run` / `archive_run` contract; the blob is opaque here, validated by `RunRecord.validate()`; `rng_snapshot` carried with the hex seed |
| run-structure.md | TR-run-structure-001 — R1 `RunState` record schema (JSON-only) | Stored verbatim as `active_run`; the hex rule is the only format constraint imposed on it |
| rng-event-log.md | TR-rng-event-log-006 (rule 18 archives) and rule 17 `to_json` inside `run_log` | Same `AtomicFileWriter` for `user://logs/**`; `log_schema_version` migrated here (M4.4) |
| systems-index.md | TR-systems-index-001 — Run Structure ↔ Meta: Meta exposes M1.3, Run Structure owns R1; MVP ships a Meta stub | `MetaApi` + `MetaStub` (Decision 9) |
| design-decisions.md | TR-design-decisions-002 — DD-T01: `profile_defaults.json` under `assets/data/`, the profile at `user://profile.json`; DD-R08 save/resume | Paths fixed as in DD-T01; defaults are data |
| accessibility-requirements.md | TR-accessibility-requirements-001 — Motor "Full input remapping" (Standard tier, Alpha): every action rebindable except `cancel` / Esc; bindings persist across restarts; storage was undecided | Decision addendum (2026-11-03): `settings.bindings: {action: [InputEvent as Dictionary]}` in the profile settings record, applied to `InputMap` at Boot after the profile loads, written through the same debounced atomic path; `cancel` dropped on write; additive key, no `schema_version` bump |

## TD Items Retired

| TD | Prototype root cause | How this ADR rules it out |
|---|---|---|
| **TD-009** (run-state half; the modifier half is ADR-0005, the owner half ADR-0008) | Gold, deck, schedule, day index and flags in `GameManager.set_meta("…")` string keys with no schema or owner | Run state is a typed `RunRecord` owned by Run Structure, persisted only through `MetaApi.save_active_run()` as an opaque, schema-versioned blob; no `set_meta`, no global |
| TD-012 (persistence tests) — enabler | No tests, nothing headless | `ProfileStore`, `AtomicFileWriter`, `ProfileLock` and every migration are `RefCounted` with injected clock/paths; the integration suite runs against a scratch `user://` subfolder headless |

## Engine Compatibility Details

| Claim | Source / status |
|---|---|
| `FileAccess.store_string() -> bool` (was `void` before 4.4); `get_error()` after store and after flush is `OK` on success | **Sourced** `breaking-changes.md` 4.3→4.4 Core; **observed** Probe B |
| `DirAccess.rename_absolute(tmp, final)` with target absent → `OK`; with target present → `OK`, no error, final holds the new content, tmp gone; relative `DirAccess.open("user://").rename()` identical | **Observed** Probe B (Linux, 4.7.2) |
| Each rename is a single POSIX `rename(2)` on the globalised paths | **Observed** Probe B strace |
| M4 chain (json → bak, tmp → json) with and without an existing `.bak` → both `OK` | **Observed** Probe B |
| Missing source → `ERR_FAILED (1)`, target untouched; target in a missing directory → `ERR_FAILED (1)`, source kept | **Observed** Probe B |
| `FileAccess.open(WRITE)` into a missing directory → `null`, `get_open_error() == ERR_FILE_NOT_FOUND (7)`; parent dirs are not created; `make_dir_recursive_absolute()` → `OK` then the write succeeds | **Observed** Probe B |
| No `fsync` / `fdatasync` on `flush()` or `close()`; tmp opened `O_WRONLY|O_CREAT|O_TRUNC` | **Observed** Probe B strace |
| `JSON.stringify(d, "\t")` pretty-prints; `JSON.parse_string` returns `float` for every number, exact only to 2^53; `JSON.new().parse()` exposes `get_error_line()` / `get_error_message()` | **Observed** ADR-0003 probe E |
| `@abstract` classes / methods; typed overrides need `return` | **Sourced** `current-best-practices.md` §GDScript 4.5+/4.7; `breaking-changes.md` 4.6→4.7 |
| `Time.get_unix_time_from_system()`, `OS.get_process_id()`, `Timer`, `NOTIFICATION_WM_CLOSE_REQUEST`, `DirAccess.copy_absolute()`, `remove_absolute()`, `FileAccess.get_length()` | Pre-4.3 APIs, LOW risk; `Time` per `deprecated-apis.md`; `remove_absolute` / `get_files_at` in the spike's verified list; `copy_absolute` and `get_length` **NOT SOURCEABLE** — covered by the integration suite |
| **Windows**: `rename_absolute` over an existing file (MoveFileEx semantics, antivirus locks, error code) | **NOT SOURCEABLE** — no engine-reference page; not run here (no Windows host). Proof: `tests/integration/save/atomic_write_platform_test.gd`, skipped unless `OS.get_name() == "Windows"`, run on the Windows export before the Vertical Slice gate |
| Behaviour on exFAT / NTFS / network shares / cloud-synced folders | **NOT SOURCEABLE**; out of v1 scope (no cloud sync, M1.1) |
| Crash durability across power loss | **NOT TESTABLE** here; **not claimed** (Decision 5) |

## Verification — How We Know

| Question | Proof | Where |
|---|---|---|
| Rename over existing is `OK` and a single `rename(2)` on Linux | Probe B + strace (observed) | `docs/architecture/spikes/2026-11-03-engine-probes.md` § Probe B |
| The write sequence survives a failure injected at each step W2–W8 with `profile.json` or `.bak` always complete | Fault-injecting `AtomicFileWriter` subclass (`fail_at = "W4" …`) over a scratch `user://test_save_<pid>/` dir; after each run: parse succeeds on `profile.json` or `profile.bak`, never neither | `tests/integration/save/atomic_write_test.gd` (`test_failure_at_<step>_leaves_previous_profile_intact`) |
| Kill mid-sequence (process level) | Headless `-s` script writes 200 profiles in a loop while `timeout -s KILL` kills it at random points, 20 runs; the next load always returns `OK` or `RECOVERED_BAK` | `tools/qa/save_kill_test.sh` (Linux CI, nightly) |
| Windows rename semantics | Same `atomic_write_test.gd` cases plus `test_bak_rotation_over_existing_bak`, gated on `OS.get_name() == "Windows"`, run on the exported build | `tests/integration/save/atomic_write_platform_test.gd`; result recorded in `production/qa/evidence/save-platform-windows/` before Vertical Slice |
| Missing `user://runs/` is created | `write("user://runs/x.json")` on a fresh dir → `OK` | `atomic_write_test.gd` |
| Load order json → bak → fresh; corrupt copies kept; newer schema `ReadOnly` | GDD AC (M5) | `tests/integration/save/profile_store_load_test.gd` |
| Second instance `ReadOnly`; stale lock taken over; heartbeat refresh | Two `ProfileLock`s on one path with an injected clock | `tests/unit/save/profile_lock_test.gd` |
| Migrations pure, chained, written once | v1 → v2 worked example (M4.4) | `tests/unit/save/migrations/profile_v1_to_v2_test.gd` |
| 64-bit seed round-trips | `RunRecord` with `run_seed_hex` of a value > 2^53 → save → load → equal bits | `tests/integration/save/run_record_roundtrip_test.gd` |
| `set_setting` debounce and flush-on-save | Injected clock / manual `flush_settings()` | `tests/unit/save/profile_store_settings_test.gd` |
| `archive_run` idempotent on `run_id`; archive written before profile | M8.3 | `tests/integration/save/archive_run_test.gd` |
| 2 MB profile at `run_log_cap` 200 saves ≤ 50 ms | Perf test with threshold; measured on the minimum spec at Vertical Slice (AC-27) | `tests/integration/save/profile_store_perf_test.gd` + `production/qa/` note |
| `MetaStub` and `MetaFacade` satisfy the same contract | One contract suite parameterised over both | `tests/unit/meta/meta_api_contract_test.gd` |

## Performance Implications
- **CPU**: one `JSON.stringify` of ≤ 2 MB plus one file write and two renames
  per mutator (≈ 1.7 MB at defaults, F5); budget 50 ms synchronous, measured at
  Vertical Slice. `set_setting` is debounced so sliders do not write per tick.
  Load: one parse of ≤ 2 MB plus the validator's O(fields) pass; `restart_budget_ms`
  (run-ui F1) absorbs it.
- **Memory**: the profile Dictionary (~2 MB serialised, more in memory) held for
  the session; the `text` String transiently during a write.
- **Load Time**: boot pays one load; a migration pays one extra write once.
- **Network**: n/a (no cloud sync in v1).

## Migration Plan

Greenfield under `src/core/save/` and `src/gameplay/meta/`. Order: (1)
`AtomicFileWriter` + fault-injection tests; (2) `ProfileLock`; (3) `ProfileStore`
load/save/validate with the M5 statuses; (4) `MetaApi` + `MetaStub` (MVP ships
here); (5) `MetaFacade` with `UnlockEvaluator` / `StatsFold` at Vertical Slice;
(6) first migration file when `PROFILE_SCHEMA_VERSION` moves to 2. The
prototype's `set_meta` run state is not ported (TD-009).

**Rollback plan**: `MetaStub` is a complete in-memory implementation of the
contract; if the file layer proves wrong, the game runs on the stub (no
persistence) while the writer is fixed. A format change is a migration, never a
rewrite of `load_profile`; a change of the write protocol is a new ADR
superseding this one.

## Validation Criteria

Correct when: the fault-injection suite shows a complete profile after every
injected failure; the kill loop produces zero "neither file parses" outcomes
over 20 nightly runs; the Windows gated test passes on the exported build (or
documents which W7 branch ran) before the Vertical Slice gate; the measured
save at cap 200 is ≤ 50 ms on the minimum spec (or `run_log_cap` is lowered
in data with a note); two instances started 1 s apart yield one `OK` and one
`E_LOCKED`; and the `MetaApi` contract suite passes against both
implementations.

## Related
- Depends on: ADR-0001, ADR-0003. Enables: ADR-0008, ADR-0011.
- `design/gdd/meta-progression.md` M1, M4–M6, M8, M9, F5, Edge Cases, Open
  Questions (rename atomicity → this ADR; `max_save_ms` → Vertical Slice);
  `design/gdd/run-structure.md` R1, R7, R8; `design/gdd/rng-event-log.md` rules
  14, 17, 18; `design/gdd/systems-index.md` Circular Dependencies;
  `design/design-decisions.md` DD-T01, DD-R08, DD-X07, DD-X08, DD-X10.
- `docs/architecture/architecture.md` §Dependency injection and the composition
  root, §Data Flow 4–5, §API Boundaries (Foundation), §Persistence paths,
  §Performance budgets, §Tech-debt retirement mapping, Open Question QQ-02.
- `docs/architecture/spikes/2026-11-03-engine-probes.md` Probe B.
- `docs/tech-debt-register.md` TD-009, TD-012.
- Code (once implemented): `src/core/save/profile_store.gd`,
  `atomic_file_writer.gd`, `profile_lock.gd`, `save_errors.gd`, `migrations/`,
  `src/gameplay/meta/meta_api.gd`, `meta_facade.gd`, `meta_stub.gd`,
  `src/core/boot.gd` (timers, exit hook), `tests/unit/save/`,
  `tests/integration/save/`, `tools/qa/save_kill_test.sh`; today:
  `tests/helpers/run_factory.gd`.
