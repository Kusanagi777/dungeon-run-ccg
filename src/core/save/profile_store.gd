## The owner of `user://profile.json` and its companions (ADR-0004; meta-progression
## M1, M4-M6, M8, M9). Storage only: the stats fold and unlock rules reach it as a
## Callable from `MetaFacade`, so Foundation names nothing in `src/gameplay/`.
##
## Load order (States table "Profile: Loading"): lock, then `profile.json`, then
## `profile.bak`, then fresh; then migration. Under `ReadOnly` the file is left
## alone, the in-memory profile behaves normally, and every mutator answers
## `E_READONLY`. The store holds no Node: `Boot`'s timers call [method heartbeat]
## and [method flush_settings], its exit hook [method release_lock].
##
## [codeblock]
## var store: ProfileStore = ProfileStore.from_config(db.config("profile_defaults"))
## var loaded: Dictionary = store.load_profile()   # {status, profile, repairs}
## store.save_active_run(record)                   # OK | E_IO | E_READONLY
## [/codeblock]
class_name ProfileStore
extends RefCounted

## Emitted when a setting changed and a debounced write is wanted (ADR-0004
## Decision 8). `Boot` restarts its one-shot timer on it.
signal settings_dirty

enum State { UNLOADED, READY, READ_ONLY }

## The one code literal (M1.2, AC-30).
const PROFILE_SCHEMA_VERSION: int = 1
## The `config("profile_defaults")` key holding the tuning knobs; every other key
## of that body is an M9 setting default.
const KNOBS_KEY: String = "knobs"
## The folder of full run records under the root (M8.2).
const RUNS_DIR: String = "runs"
## M8.1: fields an ArchivedRun does not keep.
const ARCHIVE_DROPPED_KEYS: Array[String] = ["run_log", "rng_snapshot", "draft_state", "treasure_state"]
const OTHERS_KEY: String = "_others"
## The M9 key absent from the defaults (ADR-0004 addendum 1).
const BINDINGS_KEY: String = "bindings"

## The channel every settings consumer reads (ADR-0004 Key Interfaces).
var settings_bus: SettingsBus = SettingsBus.new()

var _defaults: Dictionary
var _knobs: Dictionary
var _writer: AtomicFileWriter
var _lock: ProfileLock
var _clock: Callable
var _root: String
var _migrations: ProfileMigrations
var _instance_id: String = ProfileSchema.new_profile_id()
var _state: State = State.UNLOADED
var _status: StringName = SaveErrors.STATUS_FRESH
var _profile: Dictionary = {}
var _repairs: int = 0
var _settings_pending: bool = false
var _unsaved: bool = false
var _on_disk: bool = false
var _final_is_corrupt: bool = false


## [param defaults] are the M9 defaults, [param knobs] the tuning knobs; [param root]
## is a `user://`-equivalent directory (tests pass a scratch one, with
## [param lock] on the same path); [param migrations] defaults to the shipped chain.
func _init(defaults: Dictionary, knobs: Dictionary, writer: AtomicFileWriter, lock: ProfileLock,
		clock: Callable = Time.get_unix_time_from_system, root: String = "user://",
		migrations: ProfileMigrations = null) -> void:
	_defaults = defaults.duplicate(true)
	_knobs = knobs.duplicate(true)
	_writer = writer
	_lock = lock
	_clock = clock
	_root = root
	_migrations = migrations if migrations != null else ProfileMigrations.new(ProfileMigrations.shipped_steps(), PROFILE_SCHEMA_VERSION)


## A store over `user://` built from the `config("profile_defaults")` [param body].
static func from_config(body: Dictionary) -> ProfileStore:
	var knobs: Dictionary = body[KNOBS_KEY]
	var lock: ProfileLock = ProfileLock.new("user://profile.lock", int(knobs.lock_stale_s))
	return ProfileStore.new(settings_defaults(body), knobs, AtomicFileWriter.new(), lock)


## The M9 defaults of a `config("profile_defaults")` [param body], as a writable copy.
static func settings_defaults(body: Dictionary) -> Dictionary:
	var defaults: Dictionary = body.duplicate(true)
	defaults.erase(KNOBS_KEY)
	return defaults


## M5 / M6: returns `{status, profile, repairs}`. Runs once per session: a `Ready`
## store and an `E_SCHEMA_NEWER` one answer from memory; an `E_LOCKED` one re-checks
## the lock and loads again (the banner's "Retry", M6.2). AC-1: nothing is written
## on a fresh load.
func load_profile() -> Dictionary:
	var settled: bool = _state == State.READY or (_state == State.READ_ONLY and _status == SaveErrors.STATUS_SCHEMA_NEWER)
	if settled:
		return _load_result()
	var locked: bool = _lock.acquire(_instance_id) != OK
	var outcome: Dictionary = _read_chain(locked)
	_status = outcome.status
	_repairs = 0
	if outcome.status == SaveErrors.STATUS_SCHEMA_NEWER:
		_profile = _fresh_profile()
		_state = State.READ_ONLY
		return _load_result()
	if outcome.profile == null:
		_profile = _fresh_profile()
	else:
		_profile = ProfileSchema.normalised(outcome.profile)
		_repairs = ProfileSchema.repair(_profile, _defaults, _knobs)
		_on_disk = true
		_clear_finished_active_run()
	_final_is_corrupt = outcome.status == SaveErrors.STATUS_RECOVERED_BAK and FileAccess.file_exists(_path("profile.json"))
	_state = State.READ_ONLY if locked else State.READY
	if locked:
		_status = SaveErrors.STATUS_LOCKED
	elif outcome.migrated:
		save_profile()
	return _load_result()


## Writes the profile atomically (M4). `OK`, `E_IO` or `E_READONLY`.
func save_profile() -> Error:
	if _state == State.READ_ONLY:
		return SaveErrors.E_READONLY
	if _state == State.UNLOADED:
		push_error("ProfileStore.save_profile(): no profile loaded")
		return SaveErrors.E_IO
	return _write()


## Stores [param record] verbatim as the active run and persists it (M1.2, R7).
func save_active_run(record: Dictionary) -> Error:
	_profile["active_run"] = record.duplicate(true)
	return save_profile()


## A deep copy of the active run, or `null`.
func load_active_run() -> Variant:
	var active: Variant = _profile.get("active_run")
	if active == null:
		return null
	return (active as Dictionary).duplicate(true)


## Clears the active run and persists; an `E_IO` is logged by the write.
func clear_active_run() -> void:
	if _profile.get("active_run") == null:
		return
	_profile["active_run"] = null
	save_profile()
	return


## M8 and the `archive_run` transition order. Writes `runs/<run_id>.json` when
## `keep_run_records` is on, calls [param rules] (`func(profile, record) -> Array`,
## which folds and grants inside the profile and returns the granted keys), appends
## the ArchivedRun, prunes (F4) and persists once. Idempotent on `run_id` (M8.3),
## and a retry after a failed write writes again. Returns
## `{ok, unlocks_granted}`; `ok` is false on `E_IO` or `E_READONLY`, and the change
## then stays in memory (Edge Cases "disk full").
func archive_run(record: Dictionary, rules: Callable = Callable()) -> Dictionary:
	var run_id: String = str(record.get("run_id", ""))
	if run_id.is_empty() or _state == State.UNLOADED:
		push_error("ProfileStore.archive_run(): no run_id, or no profile loaded")
		return {"ok": false, "unlocks_granted": []}
	if _archived_index(run_id) >= 0:
		var retried: Error = save_profile() if _unsaved else OK
		return {"ok": retried == OK, "unlocks_granted": []}
	if _state == State.READY and get_setting(&"keep_run_records") == true:
		_write_run_record(run_id, record)
	var granted: Array = []
	if rules.is_valid():
		granted = rules.call(_profile, record)
	var entries: Array = _profile.run_log
	entries.append(archived_form(record))
	var cap: int = int(_knobs.run_log_cap)
	if entries.size() > cap:
		_profile["run_log"] = entries.slice(entries.size() - cap)
	return {"ok": save_profile() == OK, "unlocks_granted": granted}


## The ArchivedRun of [param record] (M8.1): the heavy fields dropped, each match's
## `damage_by_card` cut to its top `archive_top_cards` entries plus `_others`.
func archived_form(record: Dictionary) -> Dictionary:
	var entry: Dictionary = record.duplicate(true)
	for key: String in ARCHIVE_DROPPED_KEYS:
		entry.erase(key)
	for summary: Variant in entry.get("match_summaries", []):
		if summary is Dictionary and summary.get("damage_by_card") is Dictionary:
			summary["damage_by_card"] = _top_cards(summary.damage_by_card)
	return entry


## Up to [param limit] archived runs from [param offset], newest last (M8).
func run_log(offset: int, limit: int) -> Array:
	var entries: Array = _profile.get("run_log", [])
	if limit <= 0 or offset >= entries.size():
		return []
	var start: int = maxi(offset, 0)
	return entries.slice(start, start + limit).map(_public_row)


## How many archived runs the log holds: the page count's input.
func run_log_count() -> int:
	return (_profile.get("run_log", []) as Array).size()


## The archived run [param run_id], or `null`.
func run_log_entry(run_id: String) -> Variant:
	var index: int = _archived_index(run_id)
	if index < 0:
		return null
	return _public_row(_profile.run_log[index])


## Deletes every full record under `runs/` ("Clear run records", M8.2). Returns
## `OK`, `E_IO` when one could not go, or `E_READONLY`.
func clear_run_records() -> Error:
	if _state != State.READY:
		return SaveErrors.E_READONLY
	var dir: String = _path(RUNS_DIR)
	var outcome: Error = OK
	for file: String in DirAccess.get_files_at(dir):
		if DirAccess.remove_absolute(dir.path_join(file)) != OK:
			outcome = SaveErrors.E_IO
	return outcome


## Stores [param value] for the M9 [param key] and publishes it once on
## [member settings_bus]; the write is debounced (Decision 8). `E_RANGE` stores
## nothing. Under `ReadOnly` the session keeps the value and `E_READONLY` says it
## will not be saved (AC-7).
func set_setting(key: StringName, value: Variant) -> Error:
	var checked: Dictionary = ProfileSchema.check_setting(String(key), value)
	if not checked.ok:
		return SaveErrors.E_RANGE
	_profile.settings[String(key)] = checked.value
	settings_bus.publish(key, _copy(checked.value))
	if _state != State.READY:
		return SaveErrors.E_READONLY
	_settings_pending = true
	settings_dirty.emit()
	return OK


## The current value of [param key], or `null`.
func get_setting(key: StringName) -> Variant:
	return _copy((_profile.get("settings", {}) as Dictionary).get(String(key)))


## A deep copy of the settings record.
func get_settings() -> Dictionary:
	return (_profile.get("settings", {}) as Dictionary).duplicate(true)


## Publishes every setting once (Boot step 4): the bus then answers a consumer
## that mounts later. An absent `bindings` is published as `{}`, its M9 meaning, so
## `reset_profile` takes a rebind off `InputMap` (ADR-0004 addendum 2).
func publish_settings() -> void:
	var settings: Dictionary = get_settings()
	for key: Variant in settings:
		settings_bus.publish(StringName(str(key)), settings[key])
	if not settings.has(BINDINGS_KEY):
		settings_bus.publish(StringName(BINDINGS_KEY), {})


## Writes a pending settings change. `OK` when none is pending.
func flush_settings() -> Error:
	if not _settings_pending:
		return OK
	return save_profile()


## `settings_write_debounce_ms`, for the timer `Boot` owns.
func debounce_ms() -> int:
	return int(_knobs.settings_write_debounce_ms)


## `lock_heartbeat_s`, for the timer `Boot` owns.
func heartbeat_s() -> int:
	return int(_knobs.lock_heartbeat_s)


## Pending notifications, oldest first (M3.6).
func pending_notifications() -> Array:
	return (_profile.get("pending_notifications", []) as Array).duplicate(true)


## Drains [param key] from the queue and persists (M3.6).
func ack_notification(key: String) -> void:
	var queue: Array = _profile.get("pending_notifications", [])
	var kept: Array = queue.filter(func(entry: Dictionary) -> bool: return entry.get("key") != key)
	if kept.size() == queue.size():
		return
	_profile["pending_notifications"] = kept
	save_profile()
	return


## Starts a fresh profile when [param confirm_token] is the `reset_confirm_token`
## knob (M1.1). `OK`, `E_IO`, `E_READONLY`, or `E_RANGE` for a wrong token. The old
## file rotates to `.bak` like any other write.
func reset_profile(confirm_token: String) -> Error:
	if confirm_token != str(_knobs.reset_confirm_token):
		return SaveErrors.E_RANGE
	if _state != State.READY:
		return SaveErrors.E_READONLY
	var seq: int = int(_profile.get("write_seq", 0))
	_profile = _fresh_profile()
	_profile["write_seq"] = seq
	return _write()


## True when mutators answer `E_READONLY`.
func is_read_only() -> bool:
	return _state == State.READ_ONLY


## The status of the last load.
func load_status() -> StringName:
	return _status


## The repair count of the last load (`load.repairs`, M5.3).
func load_repairs() -> int:
	return _repairs


## `max_repairs_before_rebuild`: above it `MetaFacade` rebuilds `stats` (M5.3).
func max_repairs() -> int:
	return int(_knobs.max_repairs_before_rebuild)


## Unix seconds from the injected clock: every timestamp in the profile uses it.
func now() -> int:
	return int(_clock.call())


## The in-memory profile itself, for `MetaFacade` and its rules only: every other
## reader takes a copy through a named method.
func live_profile() -> Dictionary:
	return _profile


## Refreshes the lock. Losing it to another instance (this one slept past
## `lock_stale_s`) turns the session `ReadOnly`: last-writer-wins is never an option.
func heartbeat() -> void:
	if not _lock.heartbeat():
		_state = State.READ_ONLY
		_status = SaveErrors.STATUS_LOCKED
	return


## Writes a pending settings change, then deletes the lock (clean exit, M6.1).
func release_lock() -> void:
	flush_settings()
	_lock.release()
	return


func _path(file_name: String) -> String:
	return _root.path_join(file_name)


func _fresh_profile() -> Dictionary:
	return ProfileSchema.new_profile(_migrations.target(), _defaults, int(_clock.call()))


func _load_result() -> Dictionary:
	return {"status": _status, "profile": _profile.duplicate(true), "repairs": _repairs}


## M5.1: `profile.json`, then `profile.bak`. Returns
## `{status, profile: Dictionary or null, migrated: bool}`. A file that fails is
## copied aside unless another instance owns the files.
func _read_chain(locked: bool) -> Dictionary:
	var found_any: bool = false
	var slots: Array = [
		["profile.json", "profile.corrupt", SaveErrors.STATUS_OK],
		["profile.bak", "profile.bak.corrupt", SaveErrors.STATUS_RECOVERED_BAK],
	]
	for slot: Array in slots:
		var path: String = _path(slot[0])
		if not FileAccess.file_exists(path):
			continue
		found_any = true
		var data: Variant = _parsed(path)
		var version: Variant = data.get("schema_version") if data is Dictionary else null
		if version is float or version is int:
			if int(version) > _migrations.target():
				return {"status": SaveErrors.STATUS_SCHEMA_NEWER, "profile": null, "migrated": false}
			var migrated: Variant = _migrations.migrate(data) if int(version) >= 1 else null
			if migrated != null:
				return {"status": slot[2], "profile": migrated, "migrated": int(version) < _migrations.target()}
		if not locked:
			_keep_corrupt_copy(path, slot[1])
	var status: StringName = SaveErrors.STATUS_FRESH_AFTER_CORRUPT if found_any else SaveErrors.STATUS_FRESH
	return {"status": status, "profile": null, "migrated": false}


## The parsed file, or `null` when it does not parse; a file over
## `max_profile_bytes` logs `W_PROFILE_SIZE` (F5).
func _parsed(path: String) -> Variant:
	var text: String = FileAccess.get_file_as_string(path)
	if text.to_utf8_buffer().size() > int(_knobs.max_profile_bytes):
		push_warning("W_PROFILE_SIZE: %s is over max_profile_bytes" % path)
	return DataLoader.parse_text(text, path)


func _keep_corrupt_copy(path: String, stem: String) -> void:
	var copy: String = _path("%s-%d.json" % [stem, int(_clock.call())])
	var copied: Error = DirAccess.copy_absolute(path, copy)
	if copied != OK:
		push_error("profile: could not keep a corrupt copy of %s: %s" % [path, error_string(copied)])


## Edge Cases: an `active_run` already in `run_log[]` is the half-finished S5.
func _clear_finished_active_run() -> void:
	var active: Variant = _profile.active_run
	if active is Dictionary and _archived_index(str(active.get("run_id", ""))) >= 0:
		_profile["active_run"] = null


func _archived_index(run_id: String) -> int:
	var entries: Array = _profile.get("run_log", [])
	for index: int in entries.size():
		if str((entries[index] as Dictionary).get("run_id", "")) == run_id:
			return index
	return -1


## A copy of an archived [param entry]; a record newer than this build is flagged
## for the "details unavailable" row (Edge Cases, Versions and data).
func _public_row(entry: Dictionary) -> Dictionary:
	var row: Dictionary = entry.duplicate(true)
	if int(entry.get("schema_version", 0)) > ProfileMigrations.RUN_RECORD_SCHEMA_VERSION:
		row["details_unavailable"] = true
	return row


func _top_cards(damage: Dictionary) -> Dictionary:
	var ids: Array = damage.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool:
		if damage[a] != damage[b]:
			return damage[a] > damage[b]
		return str(a) < str(b))
	var top_n: int = int(_knobs.archive_top_cards)
	var kept: Dictionary = {}
	var others: int = 0
	for index: int in ids.size():
		if index < top_n:
			kept[ids[index]] = damage[ids[index]]
		else:
			others += int(damage[ids[index]])
	kept[OTHERS_KEY] = others
	return kept


## M8.2: the full record, before the profile write; a failure never blocks it.
func _write_run_record(run_id: String, record: Dictionary) -> void:
	var path: String = _path(RUNS_DIR).path_join(run_id.validate_filename() + ".json")
	if _writer.write(path, JSON.stringify(record, "\t", false, true)) != OK:
		push_warning("run_warning{run_record_not_kept}: %s" % _writer.last_error_detail())


## M4: serialise, stage, rotate, commit, with the one retry after `io_retry_ms`.
## `write_seq` moves in memory only after success.
func _write() -> Error:
	var started_usec: int = Time.get_ticks_usec()
	var final_path: String = _path("profile.json")
	if _on_disk and not FileAccess.file_exists(final_path):
		push_warning("profile.json is gone; the in-memory profile recreates it")
	var now: int = int(_clock.call())
	var seq: int = int(_profile.write_seq) + 1
	var text: String = _serialised(seq, now)
	# After RECOVERED_BAK the file at the final path is the corrupt one: it must not
	# rotate over the good backup (its copy is already kept).
	var backup_path: String = "" if _final_is_corrupt else _path("profile.bak")
	_rotate_older_backups()
	var written: Error = _writer.write(final_path, text, backup_path)
	if written != OK and int(_knobs.io_retry_ms) > 0:
		OS.delay_msec(int(_knobs.io_retry_ms))
		written = _writer.write(final_path, text, backup_path)
	if written != OK:
		push_error("profile write failed: %s" % _writer.last_error_detail())
		_unsaved = true
		return SaveErrors.E_IO
	_profile["write_seq"] = seq
	_profile["updated_at"] = now
	_unsaved = false
	_settings_pending = false
	_on_disk = true
	_final_is_corrupt = false
	var elapsed_ms: int = int((Time.get_ticks_usec() - started_usec) / 1000.0)
	if elapsed_ms > int(_knobs.max_save_ms):
		push_warning("profile write took %d ms, over max_save_ms" % elapsed_ms)
	return OK


## The JSON text, `schema_version` first (M1.1), keys in insertion order, floats at
## full precision so a load equals the save (AC-2).
func _serialised(seq: int, now: int) -> String:
	var ordered: Dictionary = {"schema_version": _profile.schema_version}
	ordered.merge(_profile)
	ordered["write_seq"] = seq
	ordered["updated_at"] = now
	return JSON.stringify(ordered, "\t", false, true)


## `backup_count` above 1: `.bak` copies down to `.bak2`, `.bak3` before the write.
func _rotate_older_backups() -> void:
	for tier: int in range(int(_knobs.backup_count), 1, -1):
		var source: String = _path("profile.bak" if tier == 2 else "profile.bak%d" % (tier - 1))
		if FileAccess.file_exists(source):
			DirAccess.copy_absolute(source, _path("profile.bak%d" % tier))


func _copy(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value
