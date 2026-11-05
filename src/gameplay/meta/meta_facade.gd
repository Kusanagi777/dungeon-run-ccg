## The shipped `MetaApi`: `ProfileStore` for persistence, with the rules half on top
## (ADR-0004 Decision 9; ADR-0011 Decision 4; design/gdd/meta-progression.md M1.3).
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


## Builds the facade over [param store]; [member MetaApi.settings_bus] is the
## store's bus.
func _init(store: ProfileStore) -> void:
	_store = store
	settings_bus = store.settings_bus


## The shipped composition from a `Ready` [param db], for `Boot`: a store over
## `user://` from `config("profile_defaults")`. Nothing is loaded yet.
static func compose(db: CardDatabase) -> MetaFacade:
	return MetaFacade.new(ProfileStore.from_config(db.config("profile_defaults")))


## The store, for `Services.profile_store` and Boot's timers.
func store() -> ProfileStore:
	return _store


# --- Persistence subset (M1.3) -----------------------------------------------

## M5 / M6 load, then publishes every setting once. `{status, profile, repairs}`.
func load_profile() -> Dictionary:
	var loaded: Dictionary = _store.load_profile()
	_store.publish_settings()
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


## M3 + M7 + M8. `{ok, unlocks_granted}`.
func archive_run(record: Dictionary) -> Dictionary:
	return _store.archive_run(record)


# --- Unlocks (M2-M3) ----------------------------------------------------------

## True when [param hero_id] is playable. Until the rules land, no key gates it.
func is_hero_unlocked(_hero_id: String) -> bool:
	return true


## True when [param key] is granted in `unlocks{}`.
func is_unlocked(key: String) -> bool:
	var entry: Variant = (_store.live_profile().get("unlocks", {}) as Dictionary).get(key)
	return entry is Dictionary and entry.get("unlocked") == true


## The ids of every unlocked record of [param kind].
func unlocked_ids(_kind: StringName) -> Array:
	return []


## Every granted key, sorted.
func unlocked_keys() -> Array:
	var keys: Array = []
	var unlocks: Dictionary = _store.live_profile().get("unlocks", {})
	for key: Variant in unlocks:
		if is_unlocked(String(key)):
			keys.append(String(key))
	keys.sort()
	return keys


## True when [param _treasure_id] may be offered.
func is_treasure_unlocked(_treasure_id: String) -> bool:
	return true


## F6 read model.
func unlock_progress(_key: String) -> Dictionary:
	return {"met": false, "progress": 0.0, "parts": []}


## Run UI's read model.
func unlock_hint(_key_or_id: String) -> Dictionary:
	return {"met": false, "text_key": "", "progress": 0.0, "target": null}


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


## M2.4.
func validate_unlock_defs(_defs: Array) -> Array:
	return []


## Fresh profile on the typed confirmation (M1.1); publishes the reset settings.
func reset_profile(confirm_token: String) -> Error:
	var outcome: Error = _store.reset_profile(confirm_token)
	if outcome == OK or outcome == SaveErrors.E_IO:
		_store.publish_settings()
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
