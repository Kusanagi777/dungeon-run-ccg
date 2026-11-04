## The Content validator: static checks over the content data set (content.md
## CN-6 steps 2-3; ADR-0002 Key Interfaces, "configs.content_budgets →
## ContentValidator.validate_config").
##
## Story 007 ships [method validate_config], the stage-7a validator of
## `content_budgets.json`; story 008 adds the F1-F5 checks (`E_STARTER_CURVE`,
## `W_SET_SHARE`, `W_CURVE`, `W_BUDGET`, `E_TEXT_LENGTH`, `E_COVERAGE`) run by
## `tools/content/validate.gd`. Static functions only, no state, no file I/O:
## `Boot` registers [method validate_config] in its validator map and the
## validate command composes the same map, so the class lives under `src/`
## (exported) rather than `tools/` (`export_presets.cfg` excludes `tools/*`).
##
## Everything below is **format knowledge**: the CN-6 step 2 key list and the
## content.md Tuning Knobs **safe ranges** (the bounds a value is checked
## against). No knob value lives here; the values are `content_budgets.json`'s.
## A key whose Tuning Knobs row states no safe range is checked for type and
## the bound its meaning implies (a share in 0-1, a tolerance ≥ 0) and says so
## in its `row`.
##
## [codeblock]
## var rows: Array = ContentValidator.validate_config(db_body, null)   # [] when clean
## rows[0]   # {code: &"E_RANGE", host_id: null, field: "text_max_chars", message: "…"}
## [/codeblock]
## Single-thread-only is not required: the functions read only constants.
class_name ContentValidator
extends RefCounted

## A CN-6 step 2 key is absent.
const E_MISSING_FIELD: StringName = &"E_MISSING_FIELD"
## A key holds the wrong JSON type, a fractional integer knob, a list of the
## wrong length, or an `ops_exempt` entry that names no card-effects C5 op.
const E_SCHEMA: StringName = &"E_SCHEMA"
## A number lies outside its content.md Tuning Knobs safe range, or a
## min / max pair is inverted.
const E_RANGE: StringName = &"E_RANGE"
## A key the CN-6 step 2 list does not name (a typo is caught, not ignored).
const E_UNKNOWN_FIELD: StringName = &"E_UNKNOWN_FIELD"

## Spec kinds.
const K_OBJECT: StringName = &"object"        # nested `fields`, exactly those keys
const K_NUMBER: StringName = &"number"        # any finite JSON number in `range`
const K_INT: StringName = &"int"              # a whole JSON number in `range`
const K_NUMBER_LIST: StringName = &"number_list"  # exactly `size` numbers, each in `range`
const K_NUMBER_MAP: StringName = &"number_map"    # {<key>: number in `range`}; `keys` limits the keys
const K_OP_LIST: StringName = &"op_list"      # card-effects C5 op names (`EffectSchema.OPS`)

## Keys allowed in `budget.keyword_tax`: the DD-M09 keyword ids (card-database CR-4).
const KEYWORD_KEYS: StringName = &"keywords"

## The `content_budgets.json` body (content CN-6 step 2), field → spec.
## `range` is `[min, max]` inclusive; `null` means unbounded on that side.
## `row` names the GDD row the spec comes from.
const BUDGETS_SPEC: Dictionary = {
	"curve": {"kind": K_OBJECT, "row": "F2 / Tuning Knobs", "fields": {
		"avg_min": {"kind": K_NUMBER, "range": [2.6, 3.8], "row": "CURVE_AVG_MIN, safe 2.6-3.8"},
		"avg_max": {"kind": K_NUMBER, "range": [2.6, 3.8], "row": "CURVE_AVG_MAX, safe 2.6-3.8"},
		"bucket": {"kind": K_NUMBER_LIST, "size": 6, "range": [0.0, 1.0], "row": "CURVE_BUCKET[k1..k6_plus], a share 0-1"},
		"bucket_tol": {"kind": K_NUMBER, "range": [0.04, 0.15], "row": "BUCKET_TOL, safe 0.04-0.15"},
		"early_max": {"kind": K_NUMBER, "range": [2.0, 3.0], "row": "EARLY_MAX, safe 2-3"},
		"mid_max": {"kind": K_NUMBER, "range": [3.5, 5.0], "row": "MID_MAX, safe 3.5-5"},
	}},
	"budget": {"kind": K_OBJECT, "row": "F3 / Tuning Knobs", "fields": {
		"tol": {"kind": K_OBJECT, "row": "BUDGET_TOL", "fields": {
			"common": {"kind": K_NUMBER, "range": [1.0, 4.0], "row": "BUDGET_TOL common, safe 1-4"},
			"rare": {"kind": K_NUMBER, "range": [1.0, 4.0], "row": "BUDGET_TOL rare, safe 1-4"},
			"legendary": {"kind": K_NUMBER, "range": [1.0, 4.0], "row": "BUDGET_TOL legendary, safe 1-4"},
		}},
		"keyword_tax": {"kind": K_NUMBER_MAP, "keys": KEYWORD_KEYS, "range": [0.0, null], "row": "F3 keyword_tax (±50 % per entry is a review range, not a bound)"},
		"effect_points": {"kind": K_NUMBER_MAP, "range": [null, null], "row": "F3 effect_points (self-cost is negative)"},
	}},
	"pressure": {"kind": K_OBJECT, "row": "F4 / Tuning Knobs", "fields": {
		"band": {"kind": K_NUMBER_LIST, "size": 3, "range": [5.0, 14.0], "row": "PRESSURE_BAND[band], safe 5-14"},
		"tol": {"kind": K_NUMBER, "range": [0.0, null], "row": "PRESSURE_TOL (no safe range stated; ≥ 0)"},
		"passive_cap": {"kind": K_NUMBER_LIST, "size": 3, "range": [1.0, 8.0], "row": "PASSIVE_CAP[band], safe 1-8"},
	}},
	"coverage": {"kind": K_OBJECT, "row": "F5 / Tuning Knobs", "fields": {
		"kw_min": {"kind": K_INT, "range": [1, 4], "row": "KW_MIN, safe 1-4"},
		"bundle_coverage_min": {"kind": K_NUMBER, "range": [0.7, 1.0], "row": "BUNDLE_COVERAGE_MIN, safe 0.7-1.0"},
		"ops_exempt": {"kind": K_OP_LIST, "row": "F5 OPS_EXEMPT (card-effects C5 op names)"},
	}},
	"text_max_chars": {"kind": K_INT, "range": [70, 110], "row": "TEXT_MAX_CHARS, safe 70-110"},
	"pick_rate": {"kind": K_OBJECT, "row": "Tuning Knobs PICK_RATE_MIN / MAX", "fields": {
		"min": {"kind": K_NUMBER, "range": [0.05, 0.25], "row": "PICK_RATE_MIN, safe 0.05-0.25"},
		"max": {"kind": K_NUMBER, "range": [0.4, 0.7], "row": "PICK_RATE_MAX, safe 0.4-0.7"},
		"min_sample": {"kind": K_INT, "range": [20, 200], "row": "min_sample (run-structure Tuning Knobs, safe 20-200)"},
	}},
	"time": {"kind": K_OBJECT, "row": "F6", "fields": {
		"t_card": {"kind": K_NUMBER, "range": [0.3, 0.6], "row": "T_CARD, F6 0.3-0.6 h"},
		"t_boss_card": {"kind": K_NUMBER, "range": [0.2, 0.4], "row": "T_BOSS_CARD, F6 0.2-0.4 h"},
		"t_boss": {"kind": K_NUMBER, "range": [1.5, 4.0], "row": "T_BOSS, F6 1.5-4 h"},
		"t_bundle": {"kind": K_NUMBER, "range": [0.1, 0.3], "row": "T_BUNDLE, F6 0.1-0.3 h"},
		"t_balance": {"kind": K_NUMBER, "range": [2.0, 6.0], "row": "T_BALANCE, F6 2-6 h"},
	}},
	"neutral_set_size": {"kind": K_INT, "range": [35, 60], "row": "NEUTRAL_SET_SIZE, safe 35-60"},
	"set_share": {"kind": K_OBJECT, "row": "F1 SET_SHARE (neutral and boss rows)", "fields": {
		"neutral": {"kind": K_OBJECT, "row": "SET_SHARE[neutral]", "fields": {
			"minion": {"kind": K_NUMBER, "range": [0.0, 1.0], "row": "a share 0-1"},
			"spell": {"kind": K_NUMBER, "range": [0.0, 1.0], "row": "a share 0-1"},
			"weapon": {"kind": K_NUMBER, "range": [0.0, 1.0], "row": "a share 0-1"},
		}},
		"boss": {"kind": K_OBJECT, "row": "SET_SHARE[boss]", "fields": {
			"minion": {"kind": K_NUMBER, "range": [0.0, 1.0], "row": "a share 0-1"},
			"spell": {"kind": K_NUMBER, "range": [0.0, 1.0], "row": "a share 0-1"},
			"weapon": {"kind": K_NUMBER, "range": [0.0, 1.0], "row": "a share 0-1"},
		}},
	}},
	"share_tol": {"kind": K_NUMBER, "range": [0.04, 0.15], "row": "SHARE_TOL (heroes Tuning Knobs SET_SHARE tolerance, safe 0.04-0.15)"},
}

## min / max pairs that must not be inverted: `[low path, high path]`.
const ORDERED_PAIRS: Array = [
	["curve.avg_min", "curve.avg_max"],
	["curve.early_max", "curve.mid_max"],
	["pick_rate.min", "pick_rate.max"],
]


## Stage-7a validator of `content_budgets.json` (card-database CR-5 stage 7;
## ADR-0002 Decision 4: `call(body, db) -> Array`). Returns `[]` for a body
## that holds exactly the CN-6 step 2 keys with values of the right type
## inside their safe ranges; otherwise one `{code, host_id: null, field,
## message}` entry per fault — `field` is the dotted key path (list entries
## as `key[i]`) and the message names it. Every fault is reported, not only
## the first. [param _db] is unused (the body is self-contained).
## [codeblock]
## ContentValidator.validate_config({"text_max_chars": 200.0, …}, null)[0].code   # &"E_RANGE"
## [/codeblock]
static func validate_config(body: Dictionary, _db: Variant) -> Array:
	var rows: Array[Dictionary] = []
	_check_object(rows, body, BUDGETS_SPEC, "")
	for pair: Array in ORDERED_PAIRS:
		var low: Variant = _at(body, pair[0])
		var high: Variant = _at(body, pair[1])
		if _is_number(low) and _is_number(high) and float(low) > float(high):
			rows.append(_row(E_RANGE, pair[0], "`%s` is %s, above `%s` %s (min must not exceed max)" % [pair[0], str(low), pair[1], str(high)]))
	return rows


## Whether [param value] is a finite JSON number (`int` or `float`, never `bool`).
## Example: `ContentValidator.is_number(3.0) == true`.
static func is_number(value: Variant) -> bool:
	return _is_number(value)


static func _check_object(rows: Array[Dictionary], body: Dictionary, fields: Dictionary, prefix: String) -> void:
	for key: Variant in body:
		if not fields.has(key):
			var path: String = prefix + str(key)
			rows.append(_row(E_UNKNOWN_FIELD, path, "`%s` is not a content_budgets key (content CN-6 step 2)" % path))
	for key: String in fields:
		var path: String = prefix + key
		if not body.has(key):
			rows.append(_row(E_MISSING_FIELD, path, "missing `%s` (content CN-6 step 2; %s)" % [path, fields[key].row]))
			continue
		_check_value(rows, body[key], fields[key], path)


static func _check_value(rows: Array[Dictionary], value: Variant, spec: Dictionary, path: String) -> void:
	match spec.kind:
		K_OBJECT:
			if not value is Dictionary:
				rows.append(_row(E_SCHEMA, path, "`%s` must be an object, found %s" % [path, type_string(typeof(value))]))
				return
			_check_object(rows, value, spec.fields, path + ".")
		K_NUMBER, K_INT:
			_check_number(rows, value, spec, path)
		K_NUMBER_LIST:
			if not value is Array:
				rows.append(_row(E_SCHEMA, path, "`%s` must be an array of %d numbers, found %s" % [path, spec.size, type_string(typeof(value))]))
				return
			var items: Array = value
			if items.size() != int(spec.size):
				rows.append(_row(E_SCHEMA, path, "`%s` must hold exactly %d numbers, found %d (%s)" % [path, spec.size, items.size(), spec.row]))
				return
			for i: int in items.size():
				_check_number(rows, items[i], spec, "%s[%d]" % [path, i])
		K_NUMBER_MAP:
			if not value is Dictionary:
				rows.append(_row(E_SCHEMA, path, "`%s` must be an object of numbers, found %s" % [path, type_string(typeof(value))]))
				return
			for key: Variant in value:
				var entry_path: String = "%s.%s" % [path, str(key)]
				if spec.get("keys") == KEYWORD_KEYS and not RecordSchemas.KEYWORDS.has(key):
					rows.append(_row(E_UNKNOWN_FIELD, entry_path, "`%s` names no DD-M09 keyword (card-database CR-4)" % entry_path))
					continue
				_check_number(rows, value[key], spec, entry_path)
		K_OP_LIST:
			if not value is Array:
				rows.append(_row(E_SCHEMA, path, "`%s` must be an array of op names, found %s" % [path, type_string(typeof(value))]))
				return
			var ops: Array = value
			for i: int in ops.size():
				if not ops[i] is String or not EffectSchema.OPS.has(ops[i]):
					var item_path: String = "%s[%d]" % [path, i]
					rows.append(_row(E_SCHEMA, item_path, "`%s` \"%s\" is not a card-effects C5 op" % [item_path, str(ops[i])]))


static func _check_number(rows: Array[Dictionary], value: Variant, spec: Dictionary, path: String) -> void:
	if not _is_number(value):
		rows.append(_row(E_SCHEMA, path, "`%s` must be a number, found %s (%s)" % [path, str(value), type_string(typeof(value))]))
		return
	if spec.kind == K_INT and float(value) != floorf(float(value)):
		rows.append(_row(E_SCHEMA, path, "`%s` must be a whole number, found %s" % [path, str(value)]))
		return
	var bounds: Array = spec.range
	var low: Variant = bounds[0]
	var high: Variant = bounds[1]
	if (low != null and float(value) < float(low)) or (high != null and float(value) > float(high)):
		rows.append(_row(E_RANGE, path, "`%s` is %s, outside %s–%s (%s)" % [path, str(value),
			"−∞" if low == null else str(low), "∞" if high == null else str(high), spec.row]))


## The value at dotted [param path] in [param body], or `null`.
static func _at(body: Dictionary, path: String) -> Variant:
	var node: Variant = body
	for part: String in path.split("."):
		if not node is Dictionary or not (node as Dictionary).has(part):
			return null
		node = node[part]
	return node


static func _is_number(value: Variant) -> bool:
	var t: int = typeof(value)
	return (t == TYPE_INT or t == TYPE_FLOAT) and is_finite(float(value))


static func _row(code: StringName, field: String, message: String) -> Dictionary:
	return {"code": code, "host_id": null, "field": field, "message": message}
