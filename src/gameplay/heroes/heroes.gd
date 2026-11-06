## Heroes: thin data access over `CardDatabase` (heroes story 002; heroes.md H-1,
## H-2, H-5, H-7; ADR-0002; architecture.md API Boundaries, Heroes row). A hero is
## pure data, so nothing hero-specific lives here: Run Structure copies the starter
## deck from [method hero], Reward Draft weights bundles by [method plan_tags] and
## Run UI lists [method launch_heroes].
##
## Unlock state is not part of this class. `MetaApi.is_hero_unlocked` is consulted
## by Run Structure and Run UI, which own `E_HERO_LOCKED` and the Locked display.
## [codeblock]
## var heroes := Heroes.new(db)
## var deck: Array = heroes.hero("hero_war").starter_deck
## [/codeblock]
class_name Heroes
extends RefCounted

## A number lies outside its range, or a min / max pair is inverted. The same code
## `ContentValidator` reports, so the load report reads the same across owners.
const E_RANGE: StringName = &"E_RANGE"

## [constant CONFIG_SPEC] kinds.
const K_OBJECT: StringName = &"object"          # nested `fields`, exactly those keys
const K_NUMBER: StringName = &"number"          # a JSON number in `range`, or above `above`
const K_INT: StringName = &"int"                # a whole JSON number in `range`
const K_COUNT_PAIR: StringName = &"count_pair"  # [low, high] whole numbers in `range`, low <= high
const K_TAG_LIST: StringName = &"tag_list"      # a non-empty list of non-empty strings
const K_SET_MAP: StringName = &"set_map"        # {<hero set>: `entry`}, non-empty

const BUCKET_ROW: Dictionary = {"kind": K_COUNT_PAIR, "range": [0, 15], "row": "BUCKET[k], counts in a 15-card starter, no safe range stated"}
const SHARE_ROW: Dictionary = {"kind": K_NUMBER, "range": [0.0, 1.0], "row": "a share, 0-1, no safe range stated"}

## The `heroes_balance.json` body, field to spec: format knowledge, the key list and
## each key's range and never a knob's value, which is the file's (ADR-0002). `range`
## is `[min, max]` inclusive, `null` meaning unbounded on that side. `row` names the
## source: a heroes.md Tuning Knobs safe range, or for a key with none the type and
## bound its meaning implies, and says so.
const CONFIG_SPEC: Dictionary = {
	"starter_curve": {"kind": K_OBJECT, "row": "F1", "fields": {
		"avg_min": {"kind": K_NUMBER, "range": [2.2, 3.2], "row": "AVG_MIN, safe 2.2-3.2"},
		"avg_max": {"kind": K_NUMBER, "range": [2.2, 3.2], "row": "AVG_MAX, safe 2.2-3.2"},
		"max_cost": {"kind": K_INT, "range": [4, 6], "row": "STARTER_MAX_COST, safe 4-6"},
		"bucket": {"kind": K_OBJECT, "row": "F1 BUCKET[k]", "fields": {
			"0": BUCKET_ROW, "1": BUCKET_ROW, "2": BUCKET_ROW, "3": BUCKET_ROW,
			"4": BUCKET_ROW, "5": BUCKET_ROW, "6_plus": BUCKET_ROW,
		}},
	}},
	"plan_min": {"kind": K_INT, "range": [3, 8], "row": "PLAN_MIN, safe 3-8"},
	"plan_max": {"kind": K_INT, "range": [3, 8], "row": "PLAN_MAX, safe 3-8"},
	"plan_tags": {"kind": K_SET_MAP, "entry": {"kind": K_TAG_LIST}, "row": "F2 PLAN_TAGS, per-set lists, no safe range stated"},
	"hp_value_min": {"kind": K_NUMBER, "range": [1.0, 3.0], "row": "HP_VALUE_MIN, safe 1.0-3.0"},
	"hp_value_max": {"kind": K_NUMBER, "range": [1.0, 3.0], "row": "HP_VALUE_MAX, safe 1.0-3.0"},
	"vanilla_2drop": {"kind": K_NUMBER, "above": 0.0, "row": "F3 VANILLA_2DROP, above 0, no safe range stated"},
	"p_kill": {"kind": K_NUMBER, "range": [0.3, 0.6], "row": "F3 p_kill, the variable's range 0.3-0.6"},
	"hero_set_size": {"kind": K_INT, "range": [1, null], "row": "F4 HERO_SET_SIZE, above 0, no safe range stated"},
	"hero_set_size_tol": {"kind": K_INT, "range": [1, null], "row": "F4 set size tolerance, above 0, no safe range stated"},
	"set_share": {"kind": K_SET_MAP, "row": "F4 SET_SHARE, no safe range stated", "entry": {"kind": K_OBJECT, "fields": {
		"minion": SHARE_ROW, "spell": SHARE_ROW, "weapon": SHARE_ROW,
	}}},
	"set_share_tol": {"kind": K_NUMBER, "range": [0.04, 0.15], "row": "SET_SHARE tolerance, safe 0.04-0.15"},
	"synergy_min": {"kind": K_INT, "range": [3, 8], "row": "SYNERGY_MIN, safe 3-8"},
}

## min / max pairs that must not be inverted: `[low path, high path]`.
const ORDERED_PAIRS: Array = [
	["starter_curve.avg_min", "starter_curve.avg_max"],
	["plan_min", "plan_max"],
	["hp_value_min", "hp_value_max"],
]

var _db: CardDatabase
## The frozen `heroes_balance` body, read once here (ADR-0002).
var _balance: Dictionary


## Keeps [param db], the frozen `CardDatabase`, and reads `heroes_balance` once.
func _init(db: CardDatabase) -> void:
	_db = db
	_balance = db.config("heroes_balance")


## The frozen `HeroDef` [param id], the record `db.hero(id)` returns: treat it as
## read-only, `duplicate(true)` for a writable copy (CR-7). An unknown id is `null`
## and whatever `db.hero` reports for it.
## [codeblock]
## heroes.hero("hero_war").health   # 30 with the shipped data
## [/codeblock]
func hero(id: String) -> Variant:
	return _db.hero(id)


## The launch heroes, id-ascending: every `HeroDef` with `unlock` null (H-2). A
## hero with an `unlock {key, condition}` object (H-7) is never listed, whatever
## Meta Progression reports for it.
## [codeblock]
## heroes.launch_heroes()   # the three `unlock: null` records with the shipped data (H-2)
## [/codeblock]
func launch_heroes() -> Array:
	return _db.heroes().filter(func(record: Dictionary) -> bool: return record.unlock == null)


## A writable copy of the plan tags of the set of [param hero_id]: the list at
## `heroes_balance.plan_tags[hero.set]` (H-5, reward-draft F3). An unknown hero, or
## a set with no row, is a logged error and `[]`, as `CardDatabase` answers a query
## it cannot, and never an assert.
## [codeblock]
## heroes.plan_tags("hero_war")   # ["weapons", "aggro", "armour"] with the shipped data
## [/codeblock]
func plan_tags(hero_id: String) -> Array:
	# `heroes`, not `has` and `hero`: `has` answers for any record type, and `hero`
	# asserts on an id that is no HeroDef (CR-6).
	var found: Array = _db.heroes().filter(func(record: Dictionary) -> bool: return record.id == hero_id)
	if found.is_empty():
		push_error("Heroes.plan_tags(): no HeroDef \"%s\"" % hero_id)
		return []
	var hero_set: String = str(found[0].set)
	var by_set: Dictionary = _balance.plan_tags
	if not by_set.has(hero_set):
		push_error("Heroes.plan_tags(): heroes_balance has no plan_tags row for set \"%s\"" % hero_set)
		return []
	return Array(by_set[hero_set]).duplicate()


# --- Story 003: the F2 and F5 design-time checks -------------------------------
#
# Static and pure, so the content validate command can compose them later the way
# it composes `ContentValidator`'s checks. They return a value and an in-band
# verdict and add no report code: F2 and F5 name none, and no record marks a
# signature card (heroes GDD gap, story 003 Completion Notes).


## Heroes F2: how many of [param starter_ids] carry at least one of [param tags],
## the `heroes_balance.plan_tags` list of the hero's set. It counts cards, not tags:
## a card with two plan tags counts once, and each copy in the starter counts.
## [codeblock]
## var body: Dictionary = db.config("heroes_balance")
## Heroes.plan_card_count(db.hero("hero_war").starter_deck, body.plan_tags.war, db)   # 7
## [/codeblock]
static func plan_card_count(starter_ids: Array, tags: Array, db: CardDatabase) -> int:
	var count: int = 0
	for card_id: Variant in starter_ids:
		if _shares_a_tag(db.card(str(card_id)), tags):
			count += 1
	return count


## Whether [param count] is inside F2's band, `[plan_min, plan_max]` of
## [param body], the `heroes_balance` config body.
## [codeblock]
## Heroes.plan_cards_in_band(8, db.config("heroes_balance"))   # false with the shipped data
## [/codeblock]
static func plan_cards_in_band(count: int, body: Dictionary) -> bool:
	return count >= int(body.plan_min) and count <= int(body.plan_max)


## Heroes F5: how many distinct cards of `set(hero) ∪ starter(hero)`, other than
## [param card_id], share a tag with it. `set(hero)` leaves tokens out; the
## starter's neutrals join through the union.
## [codeblock]
## Heroes.synergy("war_pit_champion", "hero_war", db)   # 19 with the shipped data
## [/codeblock]
static func synergy(card_id: String, hero_id: String, db: CardDatabase) -> int:
	var hero_record: Dictionary = db.hero(hero_id)
	var partners: Dictionary = {}
	for record: Dictionary in db.cards_by_set(str(hero_record.set)):
		if not record.get("token", false):
			partners[record.id] = record
	for starter_id: Variant in hero_record.starter_deck:
		partners[str(starter_id)] = db.card(str(starter_id))
	partners.erase(card_id)
	var tags: Array = Array(db.card(card_id).tags)
	var score: int = 0
	for partner: Dictionary in partners.values():
		if _shares_a_tag(partner, tags):
			score += 1
	return score


## Whether [param score] meets F5's `synergy_min` of [param body], the
## `heroes_balance` config body.
## [codeblock]
## Heroes.synergy_in_band(0, db.config("heroes_balance"))   # false with the shipped data
## [/codeblock]
static func synergy_in_band(score: int, body: Dictionary) -> bool:
	return score >= int(body.synergy_min)


static func _shares_a_tag(card: Dictionary, tags: Array) -> bool:
	return Array(card.tags).any(func(tag: Variant) -> bool: return tags.has(tag))


# --- Story 004: the `heroes_balance.json` stage-7a validator --------------------


## The stage-7a validator of `heroes_balance.json` (card-database CR-5 stage 7;
## ADR-0002 Decision 4: `call(body, db) -> Array`), registered by `Boot` as
## `configs.heroes_balance`. Static and pure, so the content validate command
## composes it without `Boot`; [param _db] is the calling convention and is unused.
## Returns `[]` for a body holding exactly the [constant CONFIG_SPEC] keys, of the
## right type and inside their ranges; otherwise one `{code, host_id: null, field,
## message}` entry per fault, `field` the dotted key path. Every fault is reported,
## not only the first. A min / max pair is compared only when neither end already
## has an entry, so a key outside its range is one entry, not two.
## [codeblock]
## Heroes.validate_config({"synergy_min": 9.0}, null)[0].code   # &"E_MISSING_FIELD"
## [/codeblock]
static func validate_config(body: Dictionary, _db: Variant) -> Array:
	var rows: Array[Dictionary] = []
	_check_object(rows, body, CONFIG_SPEC, "")
	for pair: Array in ORDERED_PAIRS:
		var low_path: String = pair[0]
		var high_path: String = pair[1]
		var low: Variant = _at(body, low_path)
		var high: Variant = _at(body, high_path)
		if not _is_number(low) or not _is_number(high):
			continue
		if rows.any(func(row: Dictionary) -> bool: return row.field == low_path or row.field == high_path):
			continue
		if float(low) > float(high):
			rows.append(_row(E_RANGE, low_path, "`%s` is %s, above `%s` %s (min must not exceed max)" % [low_path, str(low), high_path, str(high)]))
	return rows


## The value at the dotted [param path], or `null` when any step of it is absent or
## not an object: the body is unvalidated here.
static func _at(body: Dictionary, path: String) -> Variant:
	var value: Variant = body
	for key: String in path.split("."):
		if not value is Dictionary:
			return null
		value = (value as Dictionary).get(key)
	return value


static func _is_number(value: Variant) -> bool:
	return value is int or value is float


static func _row(code: StringName, field: String, message: String) -> Dictionary:
	return {"code": code, "host_id": null, "field": field, "message": message}


static func _check_object(rows: Array[Dictionary], body: Dictionary, fields: Dictionary, prefix: String) -> void:
	for key: Variant in body:
		if not fields.has(key):
			var path: String = prefix + str(key)
			rows.append(_row(ValidationReport.E_UNKNOWN_FIELD, path, "`%s` is not a heroes_balance key" % path))
	for key: String in fields:
		var path: String = prefix + key
		if not body.has(key):
			rows.append(_row(ValidationReport.E_MISSING_FIELD, path, "missing `%s` (%s)" % [path, fields[key].row]))
			continue
		_check_value(rows, body[key], fields[key], path)


static func _check_value(rows: Array[Dictionary], value: Variant, spec: Dictionary, path: String) -> void:
	match spec.kind:
		K_OBJECT:
			if not value is Dictionary:
				rows.append(_row(ValidationReport.E_SCHEMA, path, "`%s` must be an object, found %s" % [path, type_string(typeof(value))]))
				return
			_check_object(rows, value, spec.fields, path + ".")
		K_NUMBER, K_INT:
			_check_number(rows, value, spec, path)
		K_COUNT_PAIR:
			_check_count_pair(rows, value, spec, path)
		K_TAG_LIST:
			_check_tag_list(rows, value, path)
		K_SET_MAP:
			_check_set_map(rows, value, spec, path)


static func _check_number(rows: Array[Dictionary], value: Variant, spec: Dictionary, path: String) -> void:
	if not _is_number(value):
		rows.append(_row(ValidationReport.E_SCHEMA, path, "`%s` must be a number, found %s (%s)" % [path, str(value), type_string(typeof(value))]))
		return
	var number: float = float(value)
	if spec.kind == K_INT and number != floorf(number):
		rows.append(_row(ValidationReport.E_SCHEMA, path, "`%s` must be a whole number, found %s" % [path, str(value)]))
		return
	var above: Variant = spec.get("above")
	var bounds: Array = spec.get("range", [null, null])
	var too_low: bool = (above != null and number <= float(above)) or (bounds[0] != null and number < float(bounds[0]))
	var too_high: bool = bounds[1] != null and number > float(bounds[1])
	if too_low or too_high:
		rows.append(_row(E_RANGE, path, "`%s` is %s, outside %s" % [path, str(value), spec.row]))


## One row for the whole pair, whichever end is at fault: a bucket is one knob.
static func _check_count_pair(rows: Array[Dictionary], value: Variant, spec: Dictionary, path: String) -> void:
	var shaped: bool = value is Array and (value as Array).size() == 2
	if shaped:
		for count: Variant in value:
			shaped = shaped and _is_number(count) and float(count) == floorf(float(count))
	if not shaped:
		rows.append(_row(ValidationReport.E_SCHEMA, path, "`%s` must be a [low, high] pair of whole numbers, found %s" % [path, str(value)]))
		return
	var low: int = int(value[0])
	var high: int = int(value[1])
	if low < int(spec.range[0]) or high > int(spec.range[1]) or low > high:
		rows.append(_row(E_RANGE, path, "`%s` is %s, outside %s" % [path, str(value), spec.row]))


static func _check_tag_list(rows: Array[Dictionary], value: Variant, path: String) -> void:
	if not value is Array or (value as Array).is_empty():
		rows.append(_row(ValidationReport.E_SCHEMA, path, "`%s` must be a non-empty list of tags, found %s" % [path, str(value)]))
		return
	var tags: Array = value
	for i: int in tags.size():
		if not tags[i] is String or String(tags[i]).is_empty():
			var item: String = "%s[%d]" % [path, i]
			rows.append(_row(ValidationReport.E_SCHEMA, item, "`%s` must be a tag, found %s" % [item, str(tags[i])]))


## An object keyed by hero set. Which sets hold a row is data, so that a later
## hero's rows ship with its records (H-1); a key that is no hero set is a fault.
static func _check_set_map(rows: Array[Dictionary], value: Variant, spec: Dictionary, path: String) -> void:
	if not value is Dictionary or (value as Dictionary).is_empty():
		rows.append(_row(ValidationReport.E_SCHEMA, path, "`%s` must be a non-empty object keyed by hero set, found %s" % [path, str(value)]))
		return
	for key: Variant in value:
		var entry: String = "%s.%s" % [path, str(key)]
		if not RecordSchemas.HERO_SETS.has(key):
			rows.append(_row(ValidationReport.E_UNKNOWN_FIELD, entry, "`%s` names no hero set (card-database CR-3)" % entry))
			continue
		_check_value(rows, value[key], spec.entry, entry)
