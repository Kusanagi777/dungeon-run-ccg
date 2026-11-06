## The M1.2 profile shape, the M9 settings rules and the M5.3 repair pass: pure
## functions over Dictionaries, no I/O. `ProfileStore` and `MetaStub` share them,
## and the `profile_defaults` validator reads [constant SETTINGS].
##
## Ranges here are the GDD's declared M9 ranges, not tuning knobs: defaults and
## clamps come from `config("profile_defaults")`.
##
## [codeblock]
## var repairs: int = ProfileSchema.repair(profile, defaults, knobs)
## ProfileSchema.check_setting("gamma", 2.0).ok   # false
## [/codeblock]
class_name ProfileSchema
extends RefCounted

## M9 range / enum per settings key (DD-X07, DD-X10; `bindings` per the ADR-0004
## addendum). `language` is checked for type only (M9 lists `"en"`, no enum).
const SETTINGS: Dictionary = {
	"volume_master": {"kind": "float", "min": 0.0, "max": 1.0},
	"volume_music": {"kind": "float", "min": 0.0, "max": 1.0},
	"volume_sfx": {"kind": "float", "min": 0.0, "max": 1.0},
	"fullscreen": {"kind": "bool"},
	"anim_speed": {"kind": "enum", "values": ["instant", "fast", "normal"]},
	"reduce_motion": {"kind": "bool"},
	"text_scale": {"kind": "number_enum", "values": [1.0, 1.25, 1.5]},
	"high_contrast_states": {"kind": "bool"},
	"telegraph_mode": {"kind": "enum", "values": ["full", "brief", "off"]},
	"action_delay_ms": {"kind": "int", "min": 0, "max": 2000},
	"gamma": {"kind": "float", "min": 0.8, "max": 1.4},
	"keep_run_records": {"kind": "bool"},
	"language": {"kind": "string"},
	"bindings": {"kind": "bindings"},
}

## Actions a `bindings` map may never carry (ADR-0004 addendum 3): `cancel` is
## the design name, `ui_cancel` the engine action Esc is on.
const UNREBINDABLE_ACTIONS: Array[String] = ["cancel", "ui_cancel"]
## Mouse buttons that stay fixed (addendum 3: LMB / RMB).
const FIXED_MOUSE_BUTTONS: Array[int] = [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]

## The largest integer a JSON number carries exactly (ADR-0003 probe E).
const MAX_EXACT_INT: float = 9007199254740992.0
const COUNT_KEYS: Array[String] = ["runs_started", "runs_won", "runs_lost", "runs_void", "total_turns"]
const HERO_COUNT_KEYS: Array[String] = ["runs_started", "runs_won", "runs_lost"]


## A new profile in the M1.2 shape, `schema_version` first (M1.1). Nothing here
## is written: AC-1 keeps a fresh profile off the disk until the first mutator.
static func new_profile(schema_version: int, defaults: Dictionary, now: int) -> Dictionary:
	return {
		"schema_version": schema_version,
		"profile_id": new_profile_id(),
		"created_at": now,
		"updated_at": now,
		"write_seq": 0,
		"settings": defaults.duplicate(true),
		"stats": empty_stats(),
		"run_log": [],
		"unlocks": {},
		"pending_notifications": [],
		"active_run": null,
		"data_versions_seen": [],
	}


## 128 random bits as 32 hex characters (M1.2). Crypto, not an RNG stream: the
## id must not touch the seeded services.
static func new_profile_id() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()


## Zeroed `stats` (M7.1). `bests` holds the global random-seed bests (M7.4).
static func empty_stats() -> Dictionary:
	return {
		"runs_started": 0,
		"runs_won": 0,
		"runs_lost": 0,
		"runs_void": 0,
		"total_turns": 0,
		"total_play_seconds": 0,
		"heroes": {},
		"bosses": {},
		"treasures": {},
		"bests": {"fastest_victory_s": null, "fewest_turns_victory": null},
	}


## Zeroed HeroStats (M7.1).
static func empty_hero_stats() -> Dictionary:
	return {
		"runs_started": 0,
		"runs_won": 0,
		"runs_lost": 0,
		"best_floor_reached": 0,
		"fastest_victory_s": null,
		"fewest_turns_victory": null,
		"last_played_at": null,
	}


## [param value] with every integral float turned back into an `int`, at any
## depth (ADR-0004 Decision 1: JSON gives every number as a float). Returns a new
## container; opaque blobs keep their values.
static func normalised(value: Variant) -> Variant:
	if value is float and value == floorf(value) and absf(value) < MAX_EXACT_INT:
		return int(value)
	if value is Dictionary:
		var map: Dictionary = {}
		for key: Variant in value:
			map[key] = normalised(value[key])
		return map
	if value is Array:
		var list: Array = []
		for item: Variant in value:
			list.append(normalised(item))
		return list
	return value


## `{ok: bool, value}`: whether [param value] is acceptable for [param key] under
## M9, and the value to store (set_setting is strict: no clamp). An int key takes
## an integral float, a float key an int; a `bindings` map loses what
## [method clean_bindings] drops.
static func check_setting(key: String, value: Variant) -> Dictionary:
	var rejected: Dictionary = {"ok": false, "value": null}
	if not SETTINGS.has(key):
		return rejected
	var rule: Dictionary = SETTINGS[key]
	match rule.kind:
		"float":
			if not (value is float or value is int):
				return rejected
			var number: float = float(value)
			if number < rule.min or number > rule.max:
				return rejected
			return {"ok": true, "value": number}
		"int":
			if not (value is int or (value is float and float(value) == floorf(value))):
				return rejected
			var whole: int = int(value)
			if whole < rule.min or whole > rule.max:
				return rejected
			return {"ok": true, "value": whole}
		"bool":
			if not value is bool:
				return rejected
			return {"ok": true, "value": value}
		"enum":
			if not (value is String or value is StringName) or not (rule.values as Array).has(String(value)):
				return rejected
			return {"ok": true, "value": String(value)}
		"number_enum":
			if not (value is float or value is int):
				return rejected
			for allowed: float in rule.values:
				if is_equal_approx(float(value), allowed):
					return {"ok": true, "value": allowed}
			return rejected
		"string":
			if not (value is String or value is StringName):
				return rejected
			return {"ok": true, "value": String(value)}
		"bindings":
			if not value is Dictionary:
				return rejected
			return {"ok": true, "value": clean_bindings(value)}
	return rejected


## M5.3 load repair of one value: unknown keys verbatim; a value
## [method check_setting] accepts is kept; a number out of range is clamped;
## anything else becomes the default (or `{}` for `bindings`, which has none).
static func repaired_setting(key: String, value: Variant, defaults: Dictionary) -> Variant:
	if not SETTINGS.has(key):
		return value
	var checked: Dictionary = check_setting(key, value)
	if checked.ok:
		return checked.value
	var rule: Dictionary = SETTINGS[key]
	if rule.kind == "float" and (value is float or value is int):
		return clampf(float(value), rule.min, rule.max)
	if rule.kind == "int" and (value is float or value is int):
		return clampi(int(value), rule.min, rule.max)
	if rule.kind == "bindings":
		return {}
	return defaults.get(key)


## A copy of [param bindings] without the unrebindable actions, without values
## that are not event lists, and without LMB / RMB events; each drop is logged
## (ADR-0004 addendum 3). Unknown action names stay: they are ignored when the
## map is applied.
static func clean_bindings(bindings: Dictionary) -> Dictionary:
	var kept: Dictionary = {}
	for raw_action: Variant in bindings:
		var action: String = String(raw_action)
		var events: Variant = bindings[raw_action]
		if UNREBINDABLE_ACTIONS.has(action) or not events is Array:
			_log_repair("settings.bindings.%s" % action, "<events>", "absent")
			continue
		var list: Array = []
		for event: Variant in events:
			if event is Dictionary and _is_fixed_mouse_event(event):
				_log_repair("settings.bindings.%s" % action, event, "absent")
				continue
			list.append(event.duplicate(true) if event is Dictionary else event)
		kept[action] = list
	return kept


## M5.3: type-checks and clamps [param profile] in place, fills missing keys, and
## returns the repair count. Unknown keys stay; a missing key is not a repair; an
## integral float is not a repair. [param knobs] gives `max_count`,
## `max_duration_s` and `max_floor_clamp`. Nothing here re-locks an unlock (M3.3).
static func repair(profile: Dictionary, defaults: Dictionary, knobs: Dictionary) -> int:
	var ctx: Dictionary = {"repairs": 0, "knobs": knobs}
	for key: String in ["created_at", "updated_at", "write_seq"]:
		if not _is_number(profile.get(key, 0)):
			_note(ctx, key, profile[key], 0)
			profile[key] = 0
		profile[key] = int(profile.get(key, 0))
	if not profile.get("profile_id") is String:
		var fresh_id: String = new_profile_id()
		_note(ctx, "profile_id", profile.get("profile_id"), fresh_id)
		profile["profile_id"] = fresh_id
	profile["settings"] = _container(ctx, profile, "settings", {}, TYPE_DICTIONARY)
	_repair_settings(ctx, profile.settings, defaults)
	profile["stats"] = _container(ctx, profile, "stats", empty_stats(), TYPE_DICTIONARY)
	_repair_stats(ctx, profile.stats)
	profile["run_log"] = _dictionaries(ctx, _container(ctx, profile, "run_log", [], TYPE_ARRAY), "run_log")
	profile["unlocks"] = _container(ctx, profile, "unlocks", {}, TYPE_DICTIONARY)
	_repair_unlocks(ctx, profile.unlocks)
	var queue: Array = _dictionaries(ctx, _container(ctx, profile, "pending_notifications", [], TYPE_ARRAY), "pending_notifications")
	profile["pending_notifications"] = queue.filter(func(entry: Dictionary) -> bool: return entry.get("key") is String)
	var active: Variant = profile.get("active_run")
	if active != null and not active is Dictionary:
		_note(ctx, "active_run", active, null)
		active = null
	profile["active_run"] = active
	var seen: Array = _container(ctx, profile, "data_versions_seen", [], TYPE_ARRAY)
	profile["data_versions_seen"] = seen.filter(func(version: Variant) -> bool: return version is String)
	return ctx.repairs


static func _repair_settings(ctx: Dictionary, settings: Dictionary, defaults: Dictionary) -> void:
	for key: String in defaults:
		if not settings.has(key):
			settings[key] = defaults[key]
	for raw_key: Variant in settings.keys():
		var key: String = String(raw_key)
		if not SETTINGS.has(key):
			continue
		var value: Variant = settings[raw_key]
		var checked: Dictionary = check_setting(key, value)
		if checked.ok:
			settings[raw_key] = checked.value
			continue
		var repaired: Variant = repaired_setting(key, value, defaults)
		_note(ctx, "settings.%s" % key, value, repaired)
		settings[raw_key] = repaired


static func _repair_stats(ctx: Dictionary, stats: Dictionary) -> void:
	var count_max: int = ctx.knobs.max_count
	var duration_max: int = ctx.knobs.max_duration_s
	for key: String in COUNT_KEYS:
		_clamp_int(ctx, stats, key, "stats.", count_max)
	_clamp_int(ctx, stats, "total_play_seconds", "stats.", duration_max)
	var lowest_started: int = int(stats.runs_won) + int(stats.runs_lost) + int(stats.runs_void)
	if int(stats.runs_started) < lowest_started:
		_note(ctx, "stats.runs_started", stats.runs_started, lowest_started)
		stats["runs_started"] = lowest_started
	stats["heroes"] = _container(ctx, stats, "heroes", {}, TYPE_DICTIONARY)
	for hero_id: Variant in stats.heroes.keys():
		stats.heroes[hero_id] = _repair_hero(ctx, stats.heroes[hero_id], "stats.heroes.%s." % str(hero_id))
	stats["bosses"] = _container(ctx, stats, "bosses", {}, TYPE_DICTIONARY)
	_repair_counters(ctx, stats.bosses, ["defeated", "defeated_by"], "stats.bosses.")
	stats["treasures"] = _container(ctx, stats, "treasures", {}, TYPE_DICTIONARY)
	_repair_counters(ctx, stats.treasures, ["picked", "offered"], "stats.treasures.")
	stats["bests"] = _container(ctx, stats, "bests", empty_stats().bests, TYPE_DICTIONARY)
	_clamp_nullable(ctx, stats.bests, "fastest_victory_s", "stats.bests.", duration_max)
	_clamp_nullable(ctx, stats.bests, "fewest_turns_victory", "stats.bests.", count_max)


static func _repair_hero(ctx: Dictionary, raw: Variant, prefix: String) -> Dictionary:
	if not raw is Dictionary:
		_note(ctx, prefix.trim_suffix("."), raw, "zeros")
		return empty_hero_stats()
	var hero: Dictionary = raw
	for key: String in HERO_COUNT_KEYS:
		_clamp_int(ctx, hero, key, prefix, ctx.knobs.max_count)
	_clamp_int(ctx, hero, "best_floor_reached", prefix, ctx.knobs.max_floor_clamp)
	_clamp_nullable(ctx, hero, "fastest_victory_s", prefix, ctx.knobs.max_duration_s)
	_clamp_nullable(ctx, hero, "fewest_turns_victory", prefix, ctx.knobs.max_count)
	var last_played: Variant = hero.get("last_played_at")
	if last_played != null and not _is_number(last_played):
		_note(ctx, prefix + "last_played_at", last_played, null)
		last_played = null
	hero["last_played_at"] = last_played
	var lowest_started: int = int(hero.runs_won) + int(hero.runs_lost)
	if int(hero.runs_started) < lowest_started:
		_note(ctx, prefix + "runs_started", hero.runs_started, lowest_started)
		hero["runs_started"] = lowest_started
	return hero


static func _repair_counters(ctx: Dictionary, map: Dictionary, keys: Array, prefix: String) -> void:
	for id: Variant in map.keys():
		if not map[id] is Dictionary:
			_note(ctx, prefix + str(id), map[id], "zeros")
			map[id] = {}
		for key: String in keys:
			_clamp_int(ctx, map[id], key, "%s%s." % [prefix, str(id)], ctx.knobs.max_count)


## An edited entry keeps what it says: `unlocked: true` is honoured (Edge Cases).
## Only an entry that carries no boolean `true` reads as locked.
static func _repair_unlocks(ctx: Dictionary, unlocks: Dictionary) -> void:
	for key: Variant in unlocks.keys():
		var raw: Variant = unlocks[key]
		if not raw is Dictionary:
			var rebuilt: Dictionary = {"unlocked": raw is bool and raw, "at": null, "by_run_id": null, "retro": false}
			_note(ctx, "unlocks.%s" % str(key), raw, rebuilt)
			unlocks[key] = rebuilt
			continue
		var entry: Dictionary = raw
		if not entry.get("unlocked") is bool:
			_note(ctx, "unlocks.%s.unlocked" % str(key), entry.get("unlocked"), false)
			entry["unlocked"] = false
		if not entry.get("retro", false) is bool:
			_note(ctx, "unlocks.%s.retro" % str(key), entry.get("retro"), false)
			entry["retro"] = false


## [param holder]'s [param key] when it has [param type]; otherwise [param fallback]
## (a repair when the key was present with another type).
static func _container(ctx: Dictionary, holder: Dictionary, key: String, fallback: Variant, type: int) -> Variant:
	if not holder.has(key):
		return fallback
	if typeof(holder[key]) == type:
		return holder[key]
	_note(ctx, key, holder[key], fallback)
	return fallback


## The Dictionary entries of [param list]; anything else is dropped as a repair.
static func _dictionaries(ctx: Dictionary, list: Array, path: String) -> Array:
	var kept: Array = []
	for entry: Variant in list:
		if entry is Dictionary:
			kept.append(entry)
		else:
			_note(ctx, path, entry, "absent")
	return kept


static func _clamp_int(ctx: Dictionary, map: Dictionary, key: String, prefix: String, high: int) -> void:
	if not map.has(key):
		map[key] = 0
		return
	var value: Variant = map[key]
	if not _is_number(value):
		_note(ctx, prefix + key, value, 0)
		map[key] = 0
		return
	var clamped: int = clampi(int(value), 0, high)
	if float(clamped) != float(value):
		_note(ctx, prefix + key, value, clamped)
	map[key] = clamped


static func _clamp_nullable(ctx: Dictionary, map: Dictionary, key: String, prefix: String, high: int) -> void:
	if map.get(key) == null:
		map[key] = null
		return
	_clamp_int(ctx, map, key, prefix, high)


static func _is_number(value: Variant) -> bool:
	return value is int or value is float


static func _is_fixed_mouse_event(event: Dictionary) -> bool:
	return event.get("type") == "mouse_button" and FIXED_MOUSE_BUTTONS.has(int(event.get("button_index", 0)))


static func _note(ctx: Dictionary, path: String, from: Variant, to: Variant) -> void:
	ctx["repairs"] = int(ctx.repairs) + 1
	_log_repair(path, from, to)


static func _log_repair(path: String, from: Variant, to: Variant) -> void:
	push_warning("profile_repaired{path: %s, from: %s, to: %s}" % [path, str(from), str(to)])
