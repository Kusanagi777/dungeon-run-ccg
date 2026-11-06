## CR-5 stage 4: the per-record schema tables and the `card_database.json`
## knob check (card-database CR-2, CR-3, CR-4, Formulas; ADR-0002 Decision 3).
##
## Static functions over plain Dictionaries; `DataLoader` calls them once per
## record and once for its own config body, and each one adds what it finds to
## the `ValidationReport` and returns whether the record passed (a record that
## fails is left out of stages 5-9; the rest go on).
##
## Everything here is **format knowledge**, not gameplay data: the CR-3 field
## tables, the CR-2 id pattern, the CR-4 enumerations (the keyword list is
## Match Rules' DD-M09 list, enforced here for membership only) and the knob
## **ranges** from Formulas. No knob **value** and no gameplay default lives
## here; the only defaults CR-3 states (`spell_damage` 0, `token` false, `art`
## `cards/<id>`) are for optional fields the loader does not fill in.
## `effects[]`, `passive`, `unlock.condition` and every other config body are
## opaque: checked as "an array" / "an object" only (stage-7 owners).
##
## [codeblock]
## var report: ValidationReport = ValidationReport.new()
## var ok: bool = RecordSchemas.check_record("CardDef", "cards_war.json", 0, record, report)
## var knobs_ok: bool = RecordSchemas.check_card_database_config(body, report)
## [/codeblock]
##
## Codes: `E_UNKNOWN_FIELD` (a field CR-3 does not list for the type, or one
## its by-type rule forbids), `E_MISSING_FIELD` (a required field absent or
## `null`), `E_SCHEMA` (wrong JSON type, out of range, pattern, repeated
## keyword, `spell_damage` disagreeing with its keyword, unlock shape, boss
## with neither passive nor power, a knob fault), `E_BAD_ENUM` (a value outside
## a CR-3 / CR-4 enumeration), `E_SET_MISMATCH` (card `set` vs its file, id
## prefix vs type or set — CR-2), `E_TEXT_KEY` (`text.key` not `card.<id>.text`,
## `passive_text.key` not `boss.<id>.passive`).
## Single-thread-only (lazily compiled `RegEx` statics).
class_name RecordSchemas
extends RefCounted

## card-database CR-2 id pattern.
const ID_PATTERN: String = "^[a-z][a-z0-9_]{2,47}$"
## card-database CR-3 theme-tag pattern (CardDef / BossDef / TreasureDef `tags`, BundleDef `theme`).
const TAG_PATTERN: String = "^[a-z_]+$"
## card-database CR-3 `set` enum (CR-2 prefixes).
const SETS: Array[String] = ["war", "decay", "knowledge", "neutral", "boss", "fortune", "order", "shadow"]
## card-database CR-3 `type` enum (DD-M08).
const TYPES: Array[String] = ["minion", "spell", "weapon"]
## card-database CR-4 rarity: three tiers.
const RARITIES: Array[String] = ["common", "rare", "legendary"]
## card-database CR-3 TreasureDef rarity in v1 (DD-H04).
const TREASURE_RARITIES: Array[String] = ["common", "rare"]
## card-database CR-4 keyword ids (DD-M09, owned by Match Rules; membership only).
const KEYWORDS: Array[String] = [
	"taunt", "charge", "rush", "divine_shield", "windfury", "stealth", "lifesteal",
	"poisonous", "freeze", "silence", "battlecry", "deathrattle", "spell_damage",
	"discover", "aura",
]
## The one parametrised keyword (CR-3 `spell_damage`).
const SPELL_DAMAGE_KEYWORD: String = "spell_damage"
## HeroDef `set`: a hero set — never `neutral` or `boss` (CR-3).
const HERO_SETS: Array[String] = ["war", "decay", "knowledge", "fortune", "order", "shadow"]
## BundleDef `set`: a hero set or `neutral` — never `boss` (CR-3).
const BUNDLE_SETS: Array[String] = ["war", "decay", "knowledge", "neutral", "fortune", "order", "shadow"]
## card-database Formulas: the `card_database.json` knobs and their ranges,
## `[min, max]` inclusive (`max_records` has no stated ceiling: `[1]`).
const KNOB_RANGES: Dictionary = {
	"min_collectible_pool": [10, 100],
	"min_bundle_pool": [3, 30],
	"max_records": [1],
	"data_load_budget_ms": [50, 1000],
	"data_memory_budget_mb": [1, 32],
}
## The `card_database.json` file name (its body is checked here, CR-1 row).
const CARD_DATABASE_FILE: String = "card_database.json"

## Field specs. `kind`: `id`, `string`, `enum`, `int`, `bool`, `array`
## (opaque), `object_or_null` (opaque), `string_or_null`, `string_list`,
## `tag_list`, `keyword_list`, `text`, `unlock`. `required` (bool); `min` /
## `max` for `int`; `min_len` / `max_len` for `string` / lists; `enum` for
## `enum`; `pattern` (`tag`) for `string`; `count` for a list whose exact
## length CR-3 fixes (checked at stage 6 as `E_COUNT`, not here).
const CARD_FIELDS: Dictionary = {
	"id": {"kind": "id", "required": true},
	"name": {"kind": "string", "required": true, "min_len": 1, "max_len": 32},
	"set": {"kind": "enum", "required": true, "enum": SETS},
	"type": {"kind": "enum", "required": true, "enum": TYPES},
	"cost": {"kind": "int", "required": true, "min": 0, "max": 10},
	"attack": {"kind": "int", "required": false, "min": 0, "max": 99},
	"health": {"kind": "int", "required": false, "min": 1, "max": 99},
	"durability": {"kind": "int", "required": false, "min": 1, "max": 9},
	"rarity": {"kind": "enum", "required": true, "enum": RARITIES},
	"keywords": {"kind": "keyword_list", "required": true},
	"spell_damage": {"kind": "int", "required": false, "min": 0, "max": 5},
	"effects": {"kind": "array", "required": true},
	"tags": {"kind": "tag_list", "required": true},
	"text": {"kind": "text", "required": true},
	"token": {"kind": "bool", "required": false},
	"art": {"kind": "string", "required": false, "min_len": 1},
}
## CardDef by-type rule (CR-3): `true` required, `false` must be absent.
const CARD_BY_TYPE: Dictionary = {
	"minion": {"attack": true, "health": true, "durability": false},
	"weapon": {"attack": true, "health": false, "durability": true},
	"spell": {"attack": false, "health": false, "durability": false},
}
const HERO_FIELDS: Dictionary = {
	"id": {"kind": "id", "required": true},
	"name": {"kind": "string", "required": true, "min_len": 1},
	"set": {"kind": "enum", "required": true, "enum": HERO_SETS},
	"health": {"kind": "int", "required": true, "min": 1},
	"hero_power": {"kind": "string", "required": true, "min_len": 1},
	"starter_deck": {"kind": "string_list", "required": true, "count": 15},  # DD-R03, counted at stage 6
	"unlock": {"kind": "unlock", "required": true},
	"text": {"kind": "text", "required": true},
	"art": {"kind": "string", "required": false, "min_len": 1},
}
const HERO_POWER_FIELDS: Dictionary = {
	"id": {"kind": "id", "required": true},
	"name": {"kind": "string", "required": true, "min_len": 1},
	"cost": {"kind": "int", "required": true, "min": 0, "max": 10},
	"effects": {"kind": "array", "required": true},
	"text": {"kind": "text", "required": true},
	"art": {"kind": "string", "required": false, "min_len": 1},
}
const BOSS_FIELDS: Dictionary = {
	"id": {"kind": "id", "required": true},
	"name": {"kind": "string", "required": true, "min_len": 1},
	"band": {"kind": "int", "required": true, "min": 1, "max": 3},
	"health": {"kind": "int", "required": true, "min": 1},
	"hero_power": {"kind": "string_or_null", "required": true, "min_len": 1},
	"passive": {"kind": "object_or_null", "required": true},
	"passive_text": {"kind": "text", "required": false},
	"deck": {"kind": "string_list", "required": true, "min_len": 1},
	"ai_profile": {"kind": "string", "required": true, "min_len": 1},
	"tags": {"kind": "tag_list", "required": true},
	"intro_text": {"kind": "text", "required": true},
	"art": {"kind": "string", "required": false, "min_len": 1},
}
const TREASURE_FIELDS: Dictionary = {
	"id": {"kind": "id", "required": true},
	"name": {"kind": "string", "required": true, "min_len": 1},
	"rarity": {"kind": "enum", "required": true, "enum": TREASURE_RARITIES},
	"tags": {"kind": "tag_list", "required": true},
	"effects": {"kind": "array", "required": true},
	"unlock": {"kind": "unlock", "required": true},
	"text": {"kind": "text", "required": true},
	"art": {"kind": "string", "required": false, "min_len": 1},
}
const BUNDLE_FIELDS: Dictionary = {
	"id": {"kind": "id", "required": true},
	"name": {"kind": "string", "required": true, "min_len": 1},
	"set": {"kind": "enum", "required": true, "enum": BUNDLE_SETS},
	"theme": {"kind": "string", "required": true, "pattern": "tag"},
	"cards": {"kind": "string_list", "required": true, "count": 3},  # DD-R04, counted at stage 6
	"unlock": {"kind": "unlock", "required": true},
	"text": {"kind": "text", "required": true},
}
## record_type → {fields, prefix}. `prefix` is the CR-2 id prefix; CardDef and
## BundleDef add their set to it (see [method check_record]).
const SCHEMAS: Dictionary = {
	"CardDef": {"fields": CARD_FIELDS, "prefix": ""},
	"HeroDef": {"fields": HERO_FIELDS, "prefix": "hero_"},
	"HeroPowerDef": {"fields": HERO_POWER_FIELDS, "prefix": "power_"},
	"BossDef": {"fields": BOSS_FIELDS, "prefix": "boss_"},
	"TreasureDef": {"fields": TREASURE_FIELDS, "prefix": "treasure_"},
	"BundleDef": {"fields": BUNDLE_FIELDS, "prefix": "bundle_"},
}

static var _id_regex: RegEx = null
static var _tag_regex: RegEx = null


## Checks one definition record of `record_type` (a CR-3 type from
## `DataLoader.FILE_MANIFEST`) found at `records[index]` of `file_name`, adds
## one entry per fault to `report`, and returns true when it added none.
## Every fault of the record is reported, not only the first.
## Example: `RecordSchemas.check_record("HeroDef", "heroes.json", 0, hero, report)`.
static func check_record(record_type: String, file_name: String, index: int, record: Variant, report: ValidationReport) -> bool:
	var ctx: Dictionary = {"report": report, "file": file_name, "id": null, "faults": 0}
	if not record is Dictionary:
		_fault(ctx, ValidationReport.E_SCHEMA, null,
			"records[%d] must be an object, found %s" % [index, type_string(typeof(record))])
		return false
	var rec: Dictionary = record
	var schema: Dictionary = SCHEMAS[record_type]
	var fields: Dictionary = schema.fields
	if rec.get("id") is String:
		ctx.id = rec["id"]
	var where: String = "" if ctx.id != null else "records[%d]: " % index

	for key: Variant in rec:
		if not fields.has(key):
			_fault(ctx, ValidationReport.E_UNKNOWN_FIELD, str(key),
				"%s`%s` is not a %s field (CR-3)" % [where, str(key), record_type])
	var good: Dictionary = {}
	for key: String in fields:
		var spec: Dictionary = fields[key]
		var value: Variant = rec.get(key)
		var nullable: bool = spec.kind in ["object_or_null", "string_or_null", "unlock"]
		if not rec.has(key) or (value == null and not nullable):
			if spec.required:
				_fault(ctx, ValidationReport.E_MISSING_FIELD, key, "%s`%s` is required (CR-3)" % [where, key])
			elif rec.has(key):
				_fault(ctx, ValidationReport.E_SCHEMA, key, "%s`%s` is null; omit it or give a value" % [where, key])
			continue
		if _check_field(ctx, key, spec, value, where):
			good[key] = true

	match record_type:
		"CardDef":
			_check_card_rules(ctx, rec, good, file_name, where)
		"BossDef":
			_check_boss_rules(ctx, rec, good, where)
		"BundleDef":
			if good.has("id") and good.has("set"):
				_check_prefix(ctx, rec["id"], "bundle_%s_" % rec["set"], "a %s bundle" % rec["set"])
		_:
			if good.has("id"):
				_check_prefix(ctx, rec["id"], schema.prefix, "a %s" % record_type)
	return ctx.faults == 0


## Checks the `card_database.json` body: exactly the five
## [constant KNOB_RANGES] keys, each a whole number inside its range. Adds one
## `E_SCHEMA` entry per missing, extra or bad key (file `card_database.json`,
## field the key) and returns true when it added none.
## Example: `RecordSchemas.check_card_database_config({"min_bundle_pool": 2.0, …}, report)`.
static func check_card_database_config(body: Dictionary, report: ValidationReport) -> bool:
	var ctx: Dictionary = {"report": report, "file": CARD_DATABASE_FILE, "id": null, "faults": 0}
	for key: Variant in body:
		if not KNOB_RANGES.has(key):
			_fault(ctx, ValidationReport.E_SCHEMA, str(key),
				"`%s` is not a card_database knob (expected exactly %s)" % [str(key), ", ".join(KNOB_RANGES.keys())])
	for key: String in KNOB_RANGES:
		if not body.has(key):
			_fault(ctx, ValidationReport.E_SCHEMA, key, "missing knob `%s` (card-database Formulas)" % key)
			continue
		var bounds: Array = KNOB_RANGES[key]
		_check_int(ctx, key, body[key], bounds[0], bounds[1] if bounds.size() > 1 else null, "")
	return ctx.faults == 0


## True when `value` is a JSON number with no fractional part (JSON parses
## every number as `float`; `3.0` is whole, `3.5` and `"3"` are not).
## Example: `RecordSchemas.is_whole_number(3.0) == true`.
static func is_whole_number(value: Variant) -> bool:
	var t: int = typeof(value)
	if t == TYPE_INT:
		return true
	return t == TYPE_FLOAT and is_finite(value) and float(value) == floorf(float(value))


static func _check_field(ctx: Dictionary, key: String, spec: Dictionary, value: Variant, where: String) -> bool:
	match String(spec.kind):
		"id":
			if not value is String:
				return _fault(ctx, ValidationReport.E_SCHEMA, key, "%s`id` must be a string" % where)
			if _id_re().search(value) == null:
				return _fault(ctx, ValidationReport.E_SCHEMA, key, "id \"%s\" does not match %s (CR-2)" % [value, ID_PATTERN])
		"string", "string_or_null":
			if value == null:
				return true
			if not value is String:
				return _fault(ctx, ValidationReport.E_SCHEMA, key, "%s`%s` must be a string, found %s" % [where, key, type_string(typeof(value))])
			var length: int = String(value).length()
			if length < int(spec.get("min_len", 0)) or (spec.has("max_len") and length > int(spec.max_len)):
				return _fault(ctx, ValidationReport.E_SCHEMA, key, "%s`%s` length %d outside %s" % [where, key, length, _len_range(spec)])
			if spec.get("pattern") == "tag" and _tag_re().search(value) == null:
				return _fault(ctx, ValidationReport.E_SCHEMA, key, "%s`%s` \"%s\" does not match %s" % [where, key, value, TAG_PATTERN])
		"enum":
			if not value is String or not Array(spec.enum).has(value):
				return _fault(ctx, ValidationReport.E_BAD_ENUM, key, "%s`%s` \"%s\" is not one of %s" % [where, key, str(value), ", ".join(spec.enum)])
		"int":
			return _check_int(ctx, key, value, spec.get("min"), spec.get("max"), where)
		"bool":
			if not value is bool:
				return _fault(ctx, ValidationReport.E_SCHEMA, key, "%s`%s` must be true or false, found %s" % [where, key, str(value)])
		"array":
			if not value is Array:
				return _fault(ctx, ValidationReport.E_SCHEMA, key, "%s`%s` must be an array, found %s" % [where, key, type_string(typeof(value))])
		"object_or_null":
			if value != null and not value is Dictionary:
				return _fault(ctx, ValidationReport.E_SCHEMA, key, "%s`%s` must be an object or null, found %s" % [where, key, type_string(typeof(value))])
		"string_list", "tag_list", "keyword_list":
			return _check_list(ctx, key, spec, value, where)
		"text":
			return _check_text(ctx, key, value, where)
		"unlock":
			return _check_unlock(ctx, key, value, where)
	return true


static func _check_int(ctx: Dictionary, key: String, value: Variant, low: Variant, high: Variant, where: String) -> bool:
	if not is_whole_number(value):
		return _fault(ctx, ValidationReport.E_SCHEMA, key, "%s`%s` must be a whole number, found %s" % [where, key, str(value)])
	var n: int = int(value)
	if (low != null and n < int(low)) or (high != null and n > int(high)):
		var bounds: String = ("%d–%d" % [low, high]) if high != null else ("≥ %d" % low)
		return _fault(ctx, ValidationReport.E_SCHEMA, key, "%s`%s` is %d, outside %s" % [where, key, n, bounds])
	return true


static func _check_list(ctx: Dictionary, key: String, spec: Dictionary, value: Variant, where: String) -> bool:
	if not value is Array:
		return _fault(ctx, ValidationReport.E_SCHEMA, key, "%s`%s` must be an array of strings, found %s" % [where, key, type_string(typeof(value))])
	var items: Array = value
	var ok: bool = true
	if items.size() < int(spec.get("min_len", 0)):
		ok = _fault(ctx, ValidationReport.E_SCHEMA, key, "%s`%s` needs at least %d entr%s, found %d" % [where, key, spec.min_len, "y" if spec.min_len == 1 else "ies", items.size()])
	var seen: Dictionary = {}
	for i: int in items.size():
		var item: Variant = items[i]
		if not item is String:
			ok = _fault(ctx, ValidationReport.E_SCHEMA, key, "%s`%s[%d]` must be a string, found %s" % [where, key, i, type_string(typeof(item))])
			continue
		match String(spec.kind):
			"tag_list":
				if _tag_re().search(item) == null:
					ok = _fault(ctx, ValidationReport.E_SCHEMA, key, "%s`%s[%d]` \"%s\" does not match %s" % [where, key, i, item, TAG_PATTERN])
			"keyword_list":
				if not KEYWORDS.has(item):
					ok = _fault(ctx, ValidationReport.E_BAD_ENUM, key, "%skeyword \"%s\" (keywords[%d]) is not in the DD-M09 list" % [where, item, i])
				elif seen.has(item):
					ok = _fault(ctx, ValidationReport.E_SCHEMA, key, "%skeyword \"%s\" is repeated (keywords[%d])" % [where, item, i])
				seen[item] = true
	return ok


## `text`-shaped objects: exactly `{key: String, en: String}` (`en` may be empty).
static func _check_text(ctx: Dictionary, key: String, value: Variant, where: String) -> bool:
	if not value is Dictionary:
		return _fault(ctx, ValidationReport.E_SCHEMA, key, "%s`%s` must be an object {key, en}, found %s" % [where, key, type_string(typeof(value))])
	var text: Dictionary = value
	var ok: bool = true
	for sub: Variant in text:
		if sub != "key" and sub != "en":
			ok = _fault(ctx, ValidationReport.E_UNKNOWN_FIELD, "%s.%s" % [key, str(sub)], "%s`%s` carries only `key` and `en`" % [where, key])
	for sub: String in ["key", "en"]:
		if not text.has(sub) or text[sub] == null:
			ok = _fault(ctx, ValidationReport.E_MISSING_FIELD, "%s.%s" % [key, sub], "%s`%s.%s` is required" % [where, key, sub])
		elif not text[sub] is String:
			ok = _fault(ctx, ValidationReport.E_SCHEMA, "%s.%s" % [key, sub], "%s`%s.%s` must be a string" % [where, key, sub])
	return ok


## DD-X01: `null` (always unlocked) or `{key: String, condition: object}`;
## the body of `condition` is Meta Progression's (stage 7).
static func _check_unlock(ctx: Dictionary, key: String, value: Variant, where: String) -> bool:
	if value == null:
		return true
	var shape_ok: bool = value is Dictionary and value.size() == 2 \
		and value.get("key") is String and not String(value.get("key")).is_empty() \
		and value.get("condition") is Dictionary
	if not shape_ok:
		return _fault(ctx, ValidationReport.E_SCHEMA, key,
			"%s`%s` must be null or {key: string, condition: object} (DD-X01), found %s" % [where, key, JSON.stringify(value)])
	return true


static func _check_card_rules(ctx: Dictionary, rec: Dictionary, good: Dictionary, file_name: String, where: String) -> void:
	if good.has("type"):
		var rule: Dictionary = CARD_BY_TYPE[rec["type"]]
		for stat: String in rule:
			if rule[stat] and not rec.has(stat):
				_fault(ctx, ValidationReport.E_MISSING_FIELD, stat, "%sa %s needs `%s` (CR-3)" % [where, rec["type"], stat])
			elif not rule[stat] and rec.has(stat):
				_fault(ctx, ValidationReport.E_UNKNOWN_FIELD, stat, "%sa %s carries no `%s` (CR-3)" % [where, rec["type"], stat])
	if good.has("keywords") and (good.has("spell_damage") or not rec.has("spell_damage")):
		var magnitude: int = int(rec.get("spell_damage", 0))
		var has_keyword: bool = Array(rec["keywords"]).has(SPELL_DAMAGE_KEYWORD)
		if magnitude > 0 and not has_keyword:
			_fault(ctx, ValidationReport.E_SCHEMA, "spell_damage",
				"%s`spell_damage` %d without the `spell_damage` keyword (CR-3)" % [where, magnitude])
		elif magnitude == 0 and has_keyword:
			_fault(ctx, ValidationReport.E_SCHEMA, "spell_damage",
				"%sthe `spell_damage` keyword needs `spell_damage` > 0 (CR-3)" % where)
	var file_set: String = _file_set(file_name)
	if good.has("set") and rec["set"] != file_set:
		_fault(ctx, ValidationReport.E_SET_MISMATCH, "set", "set \"%s\" but the card is in %s (set %s)" % [rec["set"], file_name, file_set])
	if good.has("id"):
		_check_prefix(ctx, rec["id"], file_set + "_", "a card in %s" % file_name)
		if good.has("text") and rec["text"]["key"] != "card.%s.text" % rec["id"]:
			_fault(ctx, ValidationReport.E_TEXT_KEY, "text.key", "text.key \"%s\", expected \"card.%s.text\"" % [rec["text"]["key"], rec["id"]])


static func _check_boss_rules(ctx: Dictionary, rec: Dictionary, good: Dictionary, where: String) -> void:
	if good.has("id"):
		_check_prefix(ctx, rec["id"], "boss_", "a BossDef")
	if not good.has("passive"):
		return
	var has_passive: bool = rec["passive"] != null
	if has_passive and not rec.has("passive_text"):
		_fault(ctx, ValidationReport.E_MISSING_FIELD, "passive_text", "%sa boss with a `passive` needs `passive_text` (CR-3)" % where)
	elif not has_passive and rec.has("passive_text"):
		_fault(ctx, ValidationReport.E_UNKNOWN_FIELD, "passive_text", "%s`passive_text` must be absent when `passive` is null (CR-3)" % where)
	elif has_passive and good.has("passive_text") and good.has("id") and rec["passive_text"]["key"] != "boss.%s.passive" % rec["id"]:
		_fault(ctx, ValidationReport.E_TEXT_KEY, "passive_text.key",
			"passive_text.key \"%s\", expected \"boss.%s.passive\"" % [rec["passive_text"]["key"], rec["id"]])
	if not has_passive and rec.has("hero_power") and rec["hero_power"] == null:
		_fault(ctx, ValidationReport.E_SCHEMA, "hero_power", "%s`hero_power` may be null only for a boss with a `passive` (CR-3)" % where)


static func _check_prefix(ctx: Dictionary, id: String, prefix: String, what: String) -> void:
	if not id.begins_with(prefix):
		_fault(ctx, ValidationReport.E_SET_MISMATCH, "id", "id \"%s\" must start with \"%s\" for %s (CR-2)" % [id, prefix, what])


## `cards_<set>.json` → `<set>`.
static func _file_set(file_name: String) -> String:
	return file_name.get_basename().trim_prefix("cards_")


static func _len_range(spec: Dictionary) -> String:
	if spec.has("max_len"):
		return "%d–%d" % [spec.get("min_len", 0), spec.max_len]
	return "≥ %d" % spec.get("min_len", 0)


static func _fault(ctx: Dictionary, code: StringName, field: Variant, message: String) -> bool:
	ctx.report.add(ValidationReport.SEVERITY_ERROR, code, ctx.file, ctx.id, field, message)
	ctx.faults += 1
	return false


static func _id_re() -> RegEx:
	if _id_regex == null:
		_id_regex = RegEx.create_from_string(ID_PATTERN)
	return _id_regex


static func _tag_re() -> RegEx:
	if _tag_regex == null:
		_tag_regex = RegEx.create_from_string(TAG_PATTERN)
	return _tag_regex
