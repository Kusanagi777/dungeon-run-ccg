## The shipped `MetaApi`: `ProfileStore` for persistence, `UnlockEvaluator` and
## `StatsFold` for the rules half (ADR-0004 Decision 9; ADR-0011 Decision 4;
## design/gdd/meta-progression.md M1.3, M3, M7, M8).
##
## Only the composition root, debug loaders and tests name this class; every other
## consumer holds it as a `MetaApi`. `MetaStub` stays the fixture implementation.
## No file is touched here: `src/core/save/` is the only opener of `user://`.
##
## [codeblock]
## var meta: MetaFacade = MetaFacade.compose(card_database)
## var loaded: Dictionary = meta.load_profile()   # {status, profile, repairs}
## [/codeblock]
class_name MetaFacade
extends MetaApi

var _store: ProfileStore
var _evaluator: UnlockEvaluator
var _fold: StatsFold
var _loaded: bool = false
## Grants written by the current evaluation, emitted once they are persisted.
var _unannounced: Array[Dictionary] = []


## Builds the facade (ADR-0011 Decision 4); [member MetaApi.settings_bus] is the
## store's bus.
func _init(store: ProfileStore, evaluator: UnlockEvaluator, stats_fold: StatsFold) -> void:
	_store = store
	_evaluator = evaluator
	_fold = stats_fold
	settings_bus = store.settings_bus


## The shipped composition from a `Ready` [param db], for `Boot`: a store over
## `user://` from `config("profile_defaults")`. Nothing is loaded yet.
static func compose(db: CardDatabase) -> MetaFacade:
	var body: Dictionary = db.config("profile_defaults")
	var abandon_is_loss: bool = (db.config("run_structure") as Dictionary).get("abandon_counts_as_loss", true)
	var evaluator: UnlockEvaluator = UnlockEvaluator.new(db, body[ProfileStore.KNOBS_KEY])
	return MetaFacade.new(ProfileStore.from_config(body), evaluator, StatsFold.new(abandon_is_loss))


## The store, for `Services.profile_store` and Boot's timers.
func store() -> ProfileStore:
	return _store


# --- Persistence subset (M1.3) -----------------------------------------------

## The Loading state in order (M6, M5, M4.4 in the store; then the M5.3 rebuild,
## stale notifications and the M3.1b retro-grant here), then publishes every
## setting once. `{status, profile, repairs}`. A `Ready` profile answers from
## memory; under `ReadOnly` a grant stays in memory (States table).
func load_profile() -> Dictionary:
	if _loaded and not _store.is_read_only():
		return _store.load_profile()
	var loaded: Dictionary = _store.load_profile()
	_loaded = true
	var profile: Dictionary = _store.live_profile()
	if _store.load_repairs() > _store.max_repairs():
		profile["stats"] = _fold.rebuilt(profile.run_log, profile.stats)
		profile.stats["rebuilt_at"] = _store.now()
	_drop_stale_notifications(profile)
	_retro_grant(profile, loaded.status)
	_store.publish_settings()
	_announce()
	loaded["profile"] = profile.duplicate(true)
	return loaded


## Atomic write (M4). `OK`, `E_IO` or `E_READONLY`.
func save_profile() -> Error:
	return _store.save_profile()


## `OK`, `E_IO` or `E_READONLY` (Run Structure treats the last as `E_IO`, M6.1).
func save_active_run(record: Dictionary) -> Error:
	return _store.save_active_run(record)


## A deep copy of the active run, or `null`.
func load_active_run() -> Variant:
	return _store.load_active_run()


## Clears the slot and persists.
func clear_active_run() -> void:
	_store.clear_active_run()
	return


## M3 + M7 + M8, in the States transition order, one write at the end.
## `{ok, unlocks_granted}`; `unlock_granted` fires after the write.
func archive_run(record: Dictionary) -> Dictionary:
	var outcome: Dictionary = _store.archive_run(record, _apply_rules)
	_announce()
	return outcome


# --- Unlocks (M2-M3) ----------------------------------------------------------

## M3.7: `HeroDef.unlock == null` or its key granted; false for an id not in data.
func is_hero_unlocked(hero_id: String) -> bool:
	return _record_available(hero_id)


## True when [param key] is granted in `unlocks{}`.
func is_unlocked(key: String) -> bool:
	var entry: Variant = (_store.live_profile().get("unlocks", {}) as Dictionary).get(key)
	return entry is Dictionary and entry.get("unlocked") == true


## The ids of every available record of [param kind] (hero, treasure, bundle),
## sorted.
func unlocked_ids(kind: StringName) -> Array:
	return _evaluator.ids_of(kind).filter(_record_available)


## Every granted key, sorted. An orphaned key stays in the set: nothing asks for it.
func unlocked_keys() -> Array:
	var keys: Array = []
	var unlocks: Dictionary = _store.live_profile().get("unlocks", {})
	for key: Variant in unlocks:
		if is_unlocked(String(key)):
			keys.append(String(key))
	keys.sort()
	return keys


## M3.7: `TreasureDef.unlock == null` or its key granted.
func is_treasure_unlocked(treasure_id: String) -> bool:
	return _record_available(treasure_id)


## See [method MetaApi.is_power_unlocked].
func is_power_unlocked(power_id: String) -> bool:
	return _record_available(power_id)


## F6: `{met, progress, parts}`. A granted key stays met even if its condition
## later tightened (M3.3); a key no data defines reads as unmet, or met if granted.
func unlock_progress(key: String) -> Dictionary:
	var granted: bool = is_unlocked(key)
	if not _evaluator.has_key(key):
		return {"met": granted, "progress": 1.0 if granted else 0.0, "parts": []}
	var model: Dictionary = _evaluator.read_model(_evaluator.definition(key).condition, _stats())
	if granted:
		model["met"] = true
		model["progress"] = 1.0
	return model


## `{met, text_key, progress, target}` for a key, or a hero / treasure / bundle id.
## An always-available record is met with no text; an unknown name is unmet.
func unlock_hint(key_or_id: String) -> Dictionary:
	var key: String = key_or_id if _evaluator.has_key(key_or_id) else _evaluator.key_of(key_or_id)
	if key.is_empty():
		var available: bool = _evaluator.has_record(key_or_id)
		return {"met": available, "text_key": "", "progress": 1.0 if available else 0.0, "target": null}
	var model: Dictionary = unlock_progress(key)
	var condition: Dictionary = _evaluator.definition(key).condition
	return {"met": model.met, "text_key": _evaluator.hint_text_key(condition),
		"progress": model.progress, "target": _evaluator.hint_target(condition)}


# --- Settings (M9) -------------------------------------------------------------

## `OK`, `E_RANGE`, or `E_READONLY` (kept for the session, not saved; AC-7).
func set_setting(key: StringName, value: Variant) -> Error:
	return _store.set_setting(key, value)


## The value of [param key], or `null`.
func get_setting(key: StringName) -> Variant:
	return _store.get_setting(key)


## A deep copy of the settings record.
func get_settings() -> Dictionary:
	return _store.get_settings()


# --- Statistics and run log (M7, M8) -------------------------------------------

## The HeroStats of [param hero_id]; zeros when never played.
func stats_for_hero(hero_id: String) -> Dictionary:
	var heroes: Dictionary = _stats().get("heroes", {})
	if heroes.has(hero_id):
		return (heroes[hero_id] as Dictionary).duplicate(true)
	return ProfileSchema.empty_hero_stats()


## The hero with the latest `last_played_at`, or `null`.
func last_hero_id() -> Variant:
	var latest: Variant = null
	var latest_at: float = -INF
	var heroes: Dictionary = _stats().get("heroes", {})
	for hero_id: Variant in heroes:
		var played_at: Variant = heroes[hero_id].get("last_played_at")
		if played_at != null and float(played_at) > latest_at:
			latest_at = float(played_at)
			latest = String(hero_id)
	return latest


## Up to [param limit] archived runs from [param offset], newest last.
func run_log(offset: int, limit: int) -> Array:
	return _store.run_log(offset, limit)


## The archived run [param run_id], or `null`.
func run_log_entry(run_id: String) -> Variant:
	return _store.run_log_entry(run_id)


# --- Notifications, validation, reset -------------------------------------------

## Pending notifications, oldest first.
func pending_notifications() -> Array:
	return _store.pending_notifications()


## Drains [param key] from the queue and persists.
func ack_notification(key: String) -> void:
	_store.ack_notification(key)
	return


## M2.4 over the loaded data: `{code, host_id, field, message}` entries.
func validate_unlock_defs(defs: Array) -> Array:
	return _evaluator.validate(defs)


## Fresh profile on the typed confirmation (M1.1); publishes the reset settings.
func reset_profile(confirm_token: String) -> Error:
	var outcome: Error = _store.reset_profile(confirm_token)
	if outcome == OK or outcome == SaveErrors.E_IO:
		_retro_grant(_store.live_profile(), SaveErrors.STATUS_FRESH)
		_store.publish_settings()
		_announce()
	return outcome


## The status of the last load.
func load_status() -> StringName:
	return _store.load_status()


## True when the profile is `ReadOnly` (M5.2, M6).
func is_read_only() -> bool:
	return _store.is_read_only()


## A copy of the whole `stats` record (M7.1).
func get_stats() -> Dictionary:
	return _stats().duplicate(true)


## How many archived runs the log holds (M8).
func run_log_count() -> int:
	return _store.run_log_count()


## Deletes the full records under `user://runs/` (M8.2).
func clear_run_records() -> Error:
	return _store.clear_run_records()


func _stats() -> Dictionary:
	return _store.live_profile().get("stats", {})


func _record_available(record_id: String) -> bool:
	if not _evaluator.has_record(record_id):
		return false
	var key: String = _evaluator.key_of(record_id)
	return key.is_empty() or is_unlocked(key)


## The `archive_run` rules callback: fold (M7), then evaluate every locked key
## (M3.1a). A void run folds its counters and cannot grant (M3.5). Custom seeds
## count (M3.4).
func _apply_rules(profile: Dictionary, record: Dictionary) -> Array:
	_fold.fold(profile.stats, record)
	if _fold.is_void(record):
		return []
	return _grant(profile, str(record.get("run_id", "")), false)


## M3.1b: a `data_version` not yet seen re-evaluates every locked key. The file is
## written when a key was granted, or for an `OK` load so the version is seen once;
## a fresh profile stays off the disk until its first mutator (AC-1).
func _retro_grant(profile: Dictionary, status: StringName) -> void:
	var version: String = _evaluator.data_version()
	var seen: Array = profile.data_versions_seen
	if seen.has(version):
		return
	seen.append(version)
	var granted: Array = _grant(profile, "", true)
	if not granted.is_empty() or status == SaveErrors.STATUS_OK:
		_store.save_profile()


## M3.2 and M3.6: writes each newly met key and queues its notification in
## [param profile]. An empty [param run_id] is stored as `by_run_id: null`.
func _grant(profile: Dictionary, run_id: String, retro: bool) -> Array:
	var granted: Array = _evaluator.newly_met(profile.stats, profile.unlocks)
	var by_run_id: Variant = null if run_id.is_empty() else run_id
	for key: String in granted:
		var def: Dictionary = _evaluator.definition(key)
		profile.unlocks[key] = {"unlocked": true, "at": _store.now(), "by_run_id": by_run_id, "retro": retro}
		profile.pending_notifications.append({"key": key, "kind": String(def.kind), "id": def.id, "by_run_id": by_run_id})
		_unannounced.append({"key": key, "kind": def.kind, "id": def.id, "by_run_id": run_id, "retro": retro})
	return granted


## Edge Cases: a queued key no data defines has nothing to show.
func _drop_stale_notifications(profile: Dictionary) -> void:
	var kept: Array = []
	for entry: Dictionary in profile.pending_notifications:
		var key: String = str(entry.get("key"))
		if _evaluator.has_key(key):
			kept.append(entry)
		else:
			print("profile: dropped the notification of unknown key %s" % key)
	profile["pending_notifications"] = kept


func _announce() -> void:
	var grants: Array[Dictionary] = _unannounced
	_unannounced = []
	for grant: Dictionary in grants:
		unlock_granted.emit(grant.key, grant.kind, grant.id, grant.by_run_id, grant.retro)
