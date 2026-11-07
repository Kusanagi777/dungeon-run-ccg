## The MVP `MetaApi` implementation: everything unlocked, everything in memory
## (ADR-0011 Decision 4 — behaviour; ADR-0004 Decision 9 — path and role;
## design/gdd/meta-progression.md M1.3, M9, M10; systems-index §Circular
## Dependencies "the MVP ships a Meta stub").
##
## - `load_status()` is `FRESH`; heroes and treasures in data are unlocked;
##   `unlocked_keys()` answers from the `unlock` fields in data.
## - One active-run record is held in memory, so S23 suspend → Continue works
##   within a session; nothing persists across launches.
## - `archive_run` grants nothing and appends nothing; the run log and the
##   notification queue are always empty; hero stats are zero.
## - Settings start as the `config("profile_defaults")` body, copied once in
##   `_init`; [method set_setting] checks M9's range / enum and publishes on
##   [member MetaApi.settings_bus].
## - Every mutator call is appended to [member calls] for tests.
##
## Only the composition root, debug loaders and tests name this class; every
## other consumer holds it as a `MetaApi`.
##
## Usage:
## [codeblock]
## var meta: MetaApi = MetaStub.new(card_database)
## meta.settings_bus.settings_changed.connect(_on_settings_changed)
## meta.set_setting(&"gamma", 1.2)        # OK, emits once
## [/codeblock]
class_name MetaStub extends MetaApi


## M9 range / enum per settings key: the shared rules (ProfileSchema).
const SETTINGS_SCHEMA: Dictionary = ProfileSchema.SETTINGS

## The one `InputMap` action a `bindings` map may never carry (ADR-0004
## addendum 3: `cancel` / Esc is never rebindable).
const UNREBINDABLE_ACTION: String = "cancel"


## Every mutator call, in order, as `{method: String, args: Array}`
## (ADR-0004 Decision 9 "records calls for tests"; ADR-0011 Key Interfaces).
## Recorded mutators: save_active_run, clear_active_run, archive_run,
## set_setting, ack_notification, reset_profile.
var calls: Array[Dictionary] = []

var _db: CardDatabase
var _mirror: RefCounted
var _defaults: Dictionary
var _settings: Dictionary
var _active_run: Variant = null
## The `reset_confirm_token` knob; empty when the body carries no knobs.
var _reset_token: String = ""


## Builds the stub from [param db], a `Ready` `CardDatabase`, alone. Reads
## `config("profile_defaults")` once and keeps a writable deep copy of its M9
## keys as the settings record (the body itself is frozen, card-database CR-7); creates
## [member MetaApi.settings_bus]. [param mirror] (a `ProfileStore`) is stored
## for a later write-through build and unused here.
## [codeblock]
## var stub := MetaStub.new(card_database)
## [/codeblock]
func _init(db: CardDatabase, mirror: RefCounted = null) -> void:
	_db = db
	_mirror = mirror
	var body: Dictionary = db.config("profile_defaults")
	_defaults = ProfileStore.settings_defaults(body)
	_reset_token = str(Dictionary(body.get(ProfileStore.KNOBS_KEY, {})).get(ProfileDefaults.TOKEN_KNOB, ""))
	_settings = _defaults.duplicate(true)
	settings_bus = SettingsBus.new()


## Builds a stub for `RunDebugLoader` and tests from a fixture Dictionary:
## [code]fixture.settings[/code] merged over the defaults with M5.3 load repair
## (unknown keys preserved, wrong type → default, numbers clamped to M9's
## range, unknown enum label → default, `bindings.cancel` dropped), and
## [code]fixture.active_run[/code] (optional) as the in-memory active run.
## Nothing is emitted. No file is read here.
## [codeblock]
## var stub := MetaStub.from_fixture(card_database, {"settings": {"gamma": 1.2}})
## [/codeblock]
static func from_fixture(db: CardDatabase, fixture: Dictionary) -> MetaStub:
	var stub: MetaStub = MetaStub.new(db)
	var overrides: Dictionary = fixture.get("settings", {})
	for raw_key: Variant in overrides:
		var key: String = String(raw_key)
		stub._settings[key] = ProfileSchema.repaired_setting(key, overrides[raw_key], stub._defaults)
	var active_run: Variant = fixture.get("active_run")
	if active_run is Dictionary:
		stub._active_run = (active_run as Dictionary).duplicate(true)
	return stub


# --- Persistence subset (M1.3) -----------------------------------------------

## Returns `{status: &"FRESH", profile: {settings, active_run}}` — the stub has
## no file to load. (M1.3)
func load_profile() -> Dictionary:
	return {"status": load_status(), "profile": {"settings": get_settings(), "active_run": load_active_run()}}


## Nothing to write; returns `OK`. (M1.3)
func save_profile() -> Error:
	return OK


## Holds a deep copy of [param record] as the one active run; returns `OK`.
## Recorded in [member calls]. (M1.3; ADR-0011 S23 suspend → Continue)
func save_active_run(record: Dictionary) -> Error:
	_record(&"save_active_run", [record])
	_active_run = record.duplicate(true)
	return OK


## A deep copy of the held active run, or `null` when there is none. (M1.3)
func load_active_run() -> Variant:
	if _active_run == null:
		return null
	return (_active_run as Dictionary).duplicate(true)


## Drops the held active run. Recorded in [member calls]. (M1.3)
func clear_active_run() -> void:
	_record(&"clear_active_run", [])
	_active_run = null
	return


## Grants nothing and appends nothing to the run log; returns
## `{ok: true, unlocks_granted: []}`. Recorded in [member calls]. (M1.3, M10)
func archive_run(record: Dictionary) -> Dictionary:
	_record(&"archive_run", [record])
	return {"ok": true, "unlocks_granted": []}


# --- Unlocks (M10 MVP: trivially unlocked) -----------------------------------

## True for every hero id in `db.heroes()`. (M10)
func is_hero_unlocked(hero_id: String) -> bool:
	return _ids_of(_db.heroes()).has(hero_id)


## Every key counts as granted at MVP. (M10)
func is_unlocked(_key: String) -> bool:
	return true


## Hero ids for [code]&"hero"[/code], treasure ids for [code]&"treasure"[/code],
## sorted; `[]` for any other kind (no locked bundles in v1, M10). (M1.3)
func unlocked_ids(kind: StringName) -> Array:
	match kind:
		&"hero":
			return _ids_of(_db.heroes())
		&"treasure":
			return _ids_of(_db.treasure_pool())
	return []


## Every unlock key named by a hero or treasure `unlock` field in data, sorted
## and distinct — empty while every `unlock` is null (M10 MVP). (M1.3)
func unlocked_keys() -> Array:
	var keys: Array = []
	for records: Variant in [_db.heroes(), _db.treasure_pool()]:
		for record: Dictionary in records:
			var unlock: Variant = record.get("unlock")
			if unlock is Dictionary and not keys.has(unlock.get("key")):
				keys.append(unlock.get("key"))
	keys.sort()
	return keys


## True for every treasure id in `db.treasure_pool()`. (M10)
func is_treasure_unlocked(treasure_id: String) -> bool:
	return _ids_of(_db.treasure_pool()).has(treasure_id)


## Every power is open at the stub.
func is_power_unlocked(_power_id: String) -> bool:
	return true


## The F6 shape for a met condition: `{met: true, progress: 1.0, parts: []}`.
func unlock_progress(_key: String) -> Dictionary:
	return {"met": true, "progress": 1.0, "parts": []}


## Run UI's hint read model for a met condition:
## `{met: true, text_key: "", progress: 1.0, target: null}` — no condition
## text exists at MVP. (M1.3 "Name mapping", F6)
func unlock_hint(_key_or_id: String) -> Dictionary:
	return {"met": true, "text_key": "", "progress": 1.0, "target": null}


# --- Settings (M1.3, M9) -------------------------------------------------------

## Stores [param value] for [param key] and emits
## `settings_bus.settings_changed(key, stored)` once, returning `OK`, when the
## key is in M9 and the value is inside its range or enum. Otherwise returns
## `E_RANGE` (`ERR_PARAMETER_RANGE_ERROR`), stores nothing, emits nothing.
## An int-declared key accepts an integral float (JSON numbers are floats) and
## stores `int()`; a float key accepts an int and stores `float()`; a
## `bindings` map is stored without its `cancel` action. Recorded in
## [member calls] whatever the outcome.
## Note: ADR-0011 Decision 4 says the stub "clamps"; this follows M1.3's
## `OK | E_RANGE` (the GDD is the design authority — story 003 notes).
## [codeblock]
## meta.set_setting(&"anim_speed", "fast")   # OK
## meta.set_setting(&"gamma", 2.0)           # ERR_PARAMETER_RANGE_ERROR
## [/codeblock]
func set_setting(key: StringName, value: Variant) -> Error:
	_record(&"set_setting", [key, value])
	var name: String = String(key)
	var checked: Dictionary = ProfileSchema.check_setting(name, value)
	if not checked.ok:
		return SaveErrors.E_RANGE
	_settings[name] = checked.value
	settings_bus.publish(key, checked.value)
	return OK


## The current value of [param key], or `null` for a key not in the record.
func get_setting(key: StringName) -> Variant:
	var value: Variant = _settings.get(String(key))
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value


## A deep copy of the whole settings record (unknown keys preserved).
func get_settings() -> Dictionary:
	return _settings.duplicate(true)


# --- Statistics and run log (MVP: empty) ---------------------------------------

## A HeroStats record (M7.1) with zero counts; `fastest_victory_s`,
## `fewest_turns_victory` and `last_played_at` are `null` (nothing played).
func stats_for_hero(_hero_id: String) -> Dictionary:
	return {
		"runs_started": 0,
		"runs_won": 0,
		"runs_lost": 0,
		"best_floor_reached": 0,
		"fastest_victory_s": null,
		"fewest_turns_victory": null,
		"last_played_at": null,
	}


## Always `null`: no hero has been played (→ War pre-selected, DD-X02).
func last_hero_id() -> Variant:
	return null


## Always `[]`: the stub keeps no run log.
func run_log(_offset: int, _limit: int) -> Array:
	return []


## Always `null`: the stub keeps no run log.
func run_log_entry(_run_id: String) -> Variant:
	return null


# --- Notifications, validation, reset ------------------------------------------

## Always `[]`: the stub grants nothing, so nothing is pending.
func pending_notifications() -> Array:
	return []


## Nothing to drain. Recorded in [member calls]. (M3.6)
func ack_notification(key: String) -> void:
	_record(&"ack_notification", [key])
	return


## Returns `[]`: the stub has no rules. The M2.4 validator is
## `UnlockEvaluator.validate_defs`.
func validate_unlock_defs(_defs: Array) -> Array:
	return []


## Resets the in-memory record — settings back to the defaults, no active
## run — and returns `OK`; a token other than the `reset_confirm_token` knob is
## `E_RANGE` and changes nothing, as on `MetaFacade`. Emits nothing. Recorded in
## [member calls] whatever the outcome. (M1.3)
func reset_profile(confirm_token: String) -> Error:
	_record(&"reset_profile", [confirm_token])
	if not _reset_token.is_empty() and confirm_token != _reset_token:
		return SaveErrors.E_RANGE
	_settings = _defaults.duplicate(true)
	_active_run = null
	return OK


## Always [code]&"FRESH"[/code]: the stub never loads a file (ADR-0011).
func load_status() -> StringName:
	return &"FRESH"


## Always false: the stub has no lock to lose (M5.2, M6).
func is_read_only() -> bool:
	return false


## Empty: the stub counts nothing (M7.1).
func get_stats() -> Dictionary:
	return {}


## 0: the stub archives nothing (M8).
func run_log_count() -> int:
	return 0


## `OK`: the stub has no records to delete (M8.2).
func clear_run_records() -> Error:
	return OK


# --- Internals -------------------------------------------------------------------

func _record(method: StringName, args: Array) -> void:
	calls.append({"method": String(method), "args": args.duplicate(true)})


func _ids_of(records: Array) -> Array:
	var ids: Array = records.map(func(record: Dictionary) -> String: return record.get("id", ""))
	ids.sort()
	return ids
