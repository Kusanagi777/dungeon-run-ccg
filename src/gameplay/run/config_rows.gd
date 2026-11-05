## The stage-7a config checks `RunMachine.validate_config` and
## `RewardDraft.validate_config` share (card-database CR-5; ADR-0002 Decision 4). Each
## appends rows in the shape `Heroes.validate_config` reports: `{code, host_id, field,
## message}`, and [method warning] adds a `severity` so a row need not fail the load.
## [codeblock]
## var rows: Array[Dictionary] = []
## ConfigRows.check_unknown_keys(rows, body, ["floors_per_run"])
## ConfigRows.check_int(rows, body, "floors_per_run", 3, 12)
## [/codeblock]
class_name ConfigRows
extends RefCounted

## A number outside its Tuning Knobs safe range; the code `Heroes` reports.
const E_RANGE: StringName = &"E_RANGE"
## A value of the wrong JSON type, or an enum value the knob does not have.
const E_BAD_VALUE: StringName = &"E_BAD_VALUE"
## A layout no run can play, or a value a shipping build refuses (run-structure Edge
## Cases; reward-draft D8).
const E_CONFIG: StringName = &"E_CONFIG"


## The row of a problem at [param field].
static func error(code: StringName, field: String, message: String) -> Dictionary:
	return {"code": code, "host_id": null, "field": field, "message": message}


## A row that reports without failing the load.
static func warning(code: StringName, field: String, message: String) -> Dictionary:
	var row: Dictionary = error(code, field, message)
	row["severity"] = ValidationReport.SEVERITY_WARNING
	return row


## One row per key of [param body] not in [param known], and per key of
## [param known] not in [param body].
static func check_unknown_keys(rows: Array[Dictionary], body: Dictionary, known: Array) -> void:
	for key: Variant in body:
		if not known.has(key):
			rows.append(error(ValidationReport.E_UNKNOWN_FIELD, str(key), "`%s` is not a key of this config" % str(key)))
	for key: Variant in known:
		if not body.has(key):
			rows.append(error(ValidationReport.E_MISSING_FIELD, str(key), "missing `%s`" % str(key)))


## True for a JSON whole number.
static func is_whole(value: Variant) -> bool:
	return value is int or (value is float and float(value) == floorf(float(value)))


## [param key] is a whole number in `low..high`, when it is there at all.
static func check_int(rows: Array[Dictionary], body: Dictionary, key: String, low: int, high: int) -> void:
	if not body.has(key):
		return
	if not is_whole(body[key]):
		rows.append(error(E_BAD_VALUE, key, "`%s` must be a whole number" % key))
	elif int(body[key]) < low or int(body[key]) > high:
		rows.append(error(E_RANGE, key, "`%s` is %s, outside %d-%d" % [key, str(body[key]), low, high]))


## [param key] is a JSON number in `low..high`, when it is there at all.
static func check_number(rows: Array[Dictionary], body: Dictionary, key: String, low: float, high: float) -> void:
	if not body.has(key):
		return
	var value: Variant = body[key]
	if not (value is int or value is float):
		rows.append(error(E_BAD_VALUE, key, "`%s` must be a number" % key))
	elif float(value) < low or float(value) > high:
		rows.append(error(E_RANGE, key, "`%s` is %s, outside %s-%s" % [key, str(value), str(low), str(high)]))


## [param key] is a bool, when it is there at all.
static func check_bool(rows: Array[Dictionary], body: Dictionary, key: String) -> void:
	if body.has(key) and not body[key] is bool:
		rows.append(error(E_BAD_VALUE, key, "`%s` must be true or false" % key))
