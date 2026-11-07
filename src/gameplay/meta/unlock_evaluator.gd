## The unlock rules (design/gdd/meta-progression.md M2, M3, F1, F6): the definition
## table read from data, the pure `met` and `progress` functions over `stats`, and
## the M2.4 validator. Grants and persistence are `MetaFacade`'s.
##
## [codeblock]
## var evaluator := UnlockEvaluator.new(card_database, knobs)
## evaluator.met({"type": "runs_won", "n": 1, "hero": "hero_decay"}, stats)
## evaluator.newly_met(profile.stats, profile.unlocks)   # keys to grant, sorted
## [/codeblock]
class_name UnlockEvaluator
extends RefCounted

## M2.4 validator codes; `DataLoader` merges them by the `W_` prefix.
const E_UNLOCK_UNKNOWN_ID: StringName = &"E_UNLOCK_UNKNOWN_ID"
const E_UNLOCK_SHAPE: StringName = &"E_UNLOCK_SHAPE"
const W_UNLOCK_SELF: StringName = &"W_UNLOCK_SELF"

const HERO_ANY: String = "any"
const HERO_EACH_LAUNCH: String = "each_launch"
const BOSS_ANY: String = "any"
## Condition `type`s (M2.2).
const LEAF_FIELDS: Dictionary = {
	"always": [],
	"runs_won": ["n", "hero"],
	"boss_defeated": ["boss_id", "n"],
	"floor_reached": ["n", "hero"],
	"treasure_picked": ["treasure_id", "n"],
}
const GROUP_TYPES: Array[String] = ["all_of", "any_of"]
## `text_key` prefix of a condition's description (`unlock_hint`).
const TEXT_KEY_PREFIX: String = "unlock.condition."

var _db: CardDatabase
var _limits: Dictionary
var _defs: Dictionary = {}
var _records: Dictionary = {}
var _launch_heroes: Array[String] = []


## Reads every `unlock` field of [param db] (`Ready`) once. [param limits] gives
## `max_condition_depth`, `max_condition_n` and `max_condition_fan_out`.
func _init(db: CardDatabase, limits: Dictionary) -> void:
	_db = db
	_limits = limits
	for hero: Dictionary in db.heroes():
		_add_record(&"hero", hero)
		for extra: Variant in hero.get("extra_powers", []):
			_add_record(&"power", {"id": (extra as Dictionary).get("power", ""), "unlock": (extra as Dictionary).get("unlock")})
		if hero.get("unlock") == null:
			_launch_heroes.append(str(hero.get("id", "")))
	for treasure: Dictionary in db.treasure_pool():
		_add_record(&"treasure", treasure)
	for bundle: Dictionary in _bundles(db):
		_add_record(&"bundle", bundle)


## The CR-9 fingerprint of the data the table was read from (M3.1b).
func data_version() -> String:
	return _db.data_version()


## True when data defines [param key].
func has_key(key: String) -> bool:
	return _defs.has(key)


## `{kind, id, condition}` for [param key], or `{}`.
func definition(key: String) -> Dictionary:
	return _defs.get(key, {})


## True when a hero, treasure or bundle of [param record_id] exists in data.
func has_record(record_id: String) -> bool:
	return _records.has(record_id)


## The `unlock` key of [param record_id]; `""` for `unlock: null` or an unknown id.
func key_of(record_id: String) -> String:
	return str(_records.get(record_id, {}).get("key", ""))


## Every id of [param kind] in data, sorted.
func ids_of(kind: StringName) -> Array:
	var ids: Array = []
	for record_id: String in _records:
		if _records[record_id].kind == kind:
			ids.append(record_id)
	ids.sort()
	return ids


## M3.1: the defined keys met by [param stats] and not yet unlocked, sorted.
func newly_met(stats: Dictionary, unlocks: Dictionary) -> Array:
	var keys: Array = []
	for key: String in _defs:
		var entry: Variant = unlocks.get(key)
		var granted: bool = entry is Dictionary and entry.get("unlocked") == true
		if not granted and met(_defs[key].condition, stats):
			keys.append(key)
	keys.sort()
	return keys


## F1: whether [param condition] holds over [param stats]. A missing entry reads 0.
func met(condition: Dictionary, stats: Dictionary) -> bool:
	var type: String = str(condition.get("type", ""))
	match type:
		"always":
			return true
		"all_of":
			return (condition.get("of", []) as Array).all(func(part: Dictionary) -> bool: return met(part, stats))
		"any_of":
			return (condition.get("of", []) as Array).any(func(part: Dictionary) -> bool: return met(part, stats))
	return _current(condition, stats) >= _target(condition)


## F6: 0.0-1.0 display progress of [param condition] over [param stats].
func progress(condition: Dictionary, stats: Dictionary) -> float:
	var type: String = str(condition.get("type", ""))
	var parts: Array = condition.get("of", [])
	match type:
		"always":
			return 1.0
		"all_of":
			var total: float = 0.0
			for part: Dictionary in parts:
				total += progress(part, stats)
			return total / maxf(float(parts.size()), 1.0)
		"any_of":
			var best: float = 0.0
			for part: Dictionary in parts:
				best = maxf(best, progress(part, stats))
			return best
	return minf(1.0, float(_current(condition, stats)) / float(_target(condition)))


## `{met, progress, parts}` for [param condition] (F6). `parts` lists each leaf as
## `{type, current, target}`; an `each_launch` leaf lists one row per launch hero
## with `hero_id` (the per-hero ticks of UI Requirements).
func read_model(condition: Dictionary, stats: Dictionary) -> Dictionary:
	var parts: Array = []
	_collect_parts(condition, stats, parts)
	return {"met": met(condition, stats), "progress": progress(condition, stats), "parts": parts}


## The `target` of `unlock_hint`: the leaf's `n`, or `null` for a group or `always`.
func hint_target(condition: Dictionary) -> Variant:
	var type: String = str(condition.get("type", ""))
	if type == "always" or GROUP_TYPES.has(type):
		return null
	return _target(condition)


## The `text_key` of [param condition] for Run UI's `tr()`.
func hint_text_key(condition: Dictionary) -> String:
	return TEXT_KEY_PREFIX + str(condition.get("type", ""))


## M2.4 with this evaluator's data and limits. See [method validate_defs].
func validate(defs: Array) -> Array:
	return validate_defs(defs, _db, _limits)


## M2.4: validates `{host_kind, host_id, unlock}` [param defs]. Returns entries
## `{code, host_id, field, message}`; `unlock: null` passes. [param db] answers
## `has(id)`, and `heroes()` / `treasure_pool()` / `bundle_pool()` for key
## uniqueness across files; `null` skips those two checks. Stage 7 keeps working
## during a load: every lookup goes to the staging.
## Example: `UnlockEvaluator.validate_defs(defs, db, config.knobs)`.
static func validate_defs(defs: Array, db: Variant, limits: Dictionary) -> Array:
	var rows: Array = []
	var seen: Dictionary = {}
	for def: Dictionary in defs:
		var unlock: Variant = def.get("unlock")
		if unlock == null:
			continue
		var ctx: Dictionary = {"rows": rows, "db": db, "limits": limits, "def": def,
			"key": str(unlock.get("key", "")) if unlock is Dictionary else ""}
		if not unlock is Dictionary or not unlock.get("condition") is Dictionary:
			_row(ctx, E_UNLOCK_SHAPE, "`unlock` must be {key, condition}")
			continue
		if not _is_well_formed_key(ctx.key):
			_row(ctx, E_UNLOCK_SHAPE, "key must be snake_case, dots allowed")
		var held: int = (seen.get(ctx.key, 0) as int) + 1
		seen[ctx.key] = held
		if held > 1 or (db != null and _holders(db, ctx.key) > 1):
			_row(ctx, E_UNLOCK_SHAPE, "key is carried by more than one record")
		_check_condition(ctx, unlock.condition, 1)
	return rows


func _add_record(kind: StringName, record: Dictionary) -> void:
	var record_id: String = str(record.get("id", ""))
	var unlock: Variant = record.get("unlock")
	var key: String = ""
	if unlock is Dictionary:
		key = str(unlock.get("key", ""))
		_defs[key] = {"kind": kind, "id": record_id, "condition": unlock.get("condition", {})}
	_records[record_id] = {"kind": kind, "key": key}


func _collect_parts(condition: Dictionary, stats: Dictionary, parts: Array) -> void:
	var type: String = str(condition.get("type", ""))
	if GROUP_TYPES.has(type):
		for part: Dictionary in condition.get("of", []):
			_collect_parts(part, stats, parts)
		return
	if type == "always":
		return
	if condition.get("hero") == HERO_EACH_LAUNCH:
		for hero_id: String in _launch_heroes:
			var single: Dictionary = condition.duplicate()
			single["hero"] = hero_id
			parts.append({"type": type, "hero_id": hero_id, "current": _current(single, stats), "target": _target(condition)})
		return
	parts.append({"type": type, "current": _current(condition, stats), "target": _target(condition)})


## The left side of F1's comparison for a leaf.
func _current(condition: Dictionary, stats: Dictionary) -> int:
	match str(condition.get("type", "")):
		"runs_won":
			return _per_hero(condition, stats, "runs_won", int(stats.get("runs_won", 0)))
		"floor_reached":
			return _per_hero(condition, stats, "best_floor_reached", _best_floor(stats))
		"boss_defeated":
			return _bosses_defeated(str(condition.get("boss_id", BOSS_ANY)), stats)
		"treasure_picked":
			return int(_entry(stats, "treasures", str(condition.get("treasure_id", ""))).get("picked", 0))
	return 0


func _target(condition: Dictionary) -> int:
	return maxi(int(condition.get("n", 1)), 1)


## `wins` / `best` of F1: scoped to one hero, the minimum over launch heroes, or
## [param any_value] for `"any"`.
func _per_hero(condition: Dictionary, stats: Dictionary, field: String, any_value: int) -> int:
	var hero: String = str(condition.get("hero", HERO_ANY))
	if hero == HERO_ANY:
		return any_value
	if hero != HERO_EACH_LAUNCH:
		return int(_entry(stats, "heroes", hero).get(field, 0))
	if _launch_heroes.is_empty():
		return 0
	var lowest: int = int(_entry(stats, "heroes", _launch_heroes[0]).get(field, 0))
	for hero_id: String in _launch_heroes:
		lowest = mini(lowest, int(_entry(stats, "heroes", hero_id).get(field, 0)))
	return lowest


func _best_floor(stats: Dictionary) -> int:
	var best: int = 0
	var heroes: Dictionary = stats.get("heroes", {})
	for hero_id: Variant in heroes:
		best = maxi(best, int(heroes[hero_id].get("best_floor_reached", 0)))
	return best


func _bosses_defeated(boss_id: String, stats: Dictionary) -> int:
	if boss_id != BOSS_ANY:
		return int(_entry(stats, "bosses", boss_id).get("defeated", 0))
	var total: int = 0
	var bosses: Dictionary = stats.get("bosses", {})
	for id: Variant in bosses:
		total += int(bosses[id].get("defeated", 0))
	return total


func _entry(stats: Dictionary, map_name: String, id: String) -> Dictionary:
	return (stats.get(map_name, {}) as Dictionary).get(id, {})


## Bundles have no all-records query: a bundle is reachable through its hero set's
## pool, and neutral bundles sit in every pool.
static func _bundles(db: Variant) -> Array:
	var by_id: Dictionary = {}
	for hero: Dictionary in db.heroes():
		for bundle: Dictionary in db.bundle_pool(str(hero.get("set", ""))):
			by_id[bundle.get("id")] = bundle
	return by_id.values()


static func _holders(db: Variant, key: String) -> int:
	var count: int = 0
	var records: Array = []
	records.append_array(db.heroes())
	records.append_array(db.treasure_pool())
	records.append_array(_bundles(db))
	for record: Dictionary in records:
		var unlock: Variant = record.get("unlock")
		if unlock is Dictionary and unlock.get("key") == key:
			count += 1
	return count


static func _is_well_formed_key(key: String) -> bool:
	var pattern: RegEx = RegEx.create_from_string("^[a-z0-9_]+(\\.[a-z0-9_]+)*$")
	return pattern.search(key) != null


static func _check_condition(ctx: Dictionary, condition: Dictionary, depth: int) -> void:
	if depth > int(ctx.limits.max_condition_depth):
		_row(ctx, E_UNLOCK_SHAPE, "nested deeper than max_condition_depth")
		return
	var type: String = str(condition.get("type", ""))
	if GROUP_TYPES.has(type):
		var parts: Variant = condition.get("of")
		if not parts is Array or parts.is_empty() or parts.size() > int(ctx.limits.max_condition_fan_out):
			_row(ctx, E_UNLOCK_SHAPE, "`of` needs 1 to max_condition_fan_out members")
			return
		for part: Variant in parts:
			if part is Dictionary:
				_check_condition(ctx, part, depth + 1)
			else:
				_row(ctx, E_UNLOCK_SHAPE, "`of` member is not a condition")
		return
	if not LEAF_FIELDS.has(type):
		_row(ctx, E_UNLOCK_SHAPE, "unknown condition type \"%s\"" % type)
		return
	_check_count(ctx, condition, type)
	_check_ids(ctx, condition, type)


static func _check_count(ctx: Dictionary, condition: Dictionary, type: String) -> void:
	var required: bool = type == "runs_won" or type == "floor_reached"
	if not (LEAF_FIELDS[type] as Array).has("n") or (not required and not condition.has("n")):
		return
	var count: Variant = condition.get("n")
	var whole: bool = (count is int or count is float) and float(count) == floorf(count)
	if not whole or int(count) < 1 or int(count) > int(ctx.limits.max_condition_n):
		_row(ctx, E_UNLOCK_SHAPE, "`n` must be an int from 1 to max_condition_n, found %s" % str(count))


static func _check_ids(ctx: Dictionary, condition: Dictionary, type: String) -> void:
	if condition.has("hero") and not [HERO_ANY, HERO_EACH_LAUNCH].has(condition.hero):
		_check_id(ctx, condition.hero)
	if type == "boss_defeated" and condition.get("boss_id") != BOSS_ANY:
		_check_id(ctx, condition.get("boss_id"))
	if type == "treasure_picked":
		_check_id(ctx, condition.get("treasure_id"))
		if condition.get("treasure_id") == ctx.def.get("host_id") and str(ctx.def.get("host_kind", "")) == "treasure":
			_row(ctx, W_UNLOCK_SELF, "a treasure whose condition requires picking itself is reachable only by retro-grant")


static func _check_id(ctx: Dictionary, id: Variant) -> void:
	if not id is String:
		_row(ctx, E_UNLOCK_SHAPE, "id must be a string, found %s" % str(id))
	elif ctx.db != null and not ctx.db.has(id):
		_row(ctx, E_UNLOCK_UNKNOWN_ID, "\"%s\" is in no loaded record" % id)


static func _row(ctx: Dictionary, code: StringName, message: String) -> void:
	(ctx.rows as Array).append({
		"code": code,
		"host_id": ctx.def.get("host_id"),
		"field": "unlock",
		"message": "%s: %s" % [ctx.key, message],
	})
