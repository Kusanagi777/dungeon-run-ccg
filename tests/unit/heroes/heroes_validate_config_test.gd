## Unit tests for `Heroes.validate_config`, the `heroes_balance.json` stage-7a
## validator (heroes story 004; heroes.md Formulas F1-F5, Tuning Knobs;
## card-database CR-1 / CR-5 stage 7; ADR-0002 Decision 4).
##
## Each case starts from the shipped body, read from the committed file, and changes
## one thing, so a row in a table below is a single fault. The numbers are the
## Tuning Knobs safe ranges and F-table bounds: boundary tests, the number is the
## point. AC-3, the Boot registration, is the orchestrator's line at merge.
extends GdUnitTestSuite

const SHIPPED: String = "res://assets/data/heroes_balance.json"

## `[dotted path, value outside the range]`: the Tuning Knobs safe ranges (AC-2)
## first, then the bounds the keys' meaning implies (story 004 notes). Each is
## exactly one `E_RANGE` naming the path, including those that also invert a pair.
const OUT_OF_RANGE: Array = [
	["starter_curve.avg_min", 2.1], ["starter_curve.avg_min", 3.3],
	["starter_curve.avg_max", 2.1], ["starter_curve.avg_max", 3.3],
	["starter_curve.max_cost", 3], ["starter_curve.max_cost", 7],
	["plan_min", 2], ["plan_min", 9],
	["plan_max", 2], ["plan_max", 9],
	["hp_value_min", 0.9], ["hp_value_min", 3.1],
	["hp_value_max", 0.9], ["hp_value_max", 3.1],
	["set_share_tol", 0.03], ["set_share_tol", 0.16],
	["synergy_min", 2], ["synergy_min", 9],
	["vanilla_2drop", 0.0], ["vanilla_2drop", -1.0],
	["p_kill", 0.29], ["p_kill", 0.61],
	["set_share.war.minion", -0.01], ["set_share.war.weapon", 1.01],
	["starter_curve.bucket.1", [-1, 4]], ["starter_curve.bucket.1", [3, 16]], ["starter_curve.bucket.1", [4, 3]],
]

## Sets of edits at the inclusive edges of each range, every one accepted.
const AT_THE_EDGES: Array = [
	{"starter_curve.avg_min": 2.2}, {"starter_curve.avg_max": 3.2},
	{"starter_curve.avg_min": 3.2, "starter_curve.avg_max": 3.2},
	{"starter_curve.avg_min": 2.2, "starter_curve.avg_max": 2.2},
	{"starter_curve.max_cost": 4}, {"starter_curve.max_cost": 6},
	{"plan_min": 3}, {"plan_max": 8}, {"plan_min": 8, "plan_max": 8}, {"plan_min": 3, "plan_max": 3},
	{"hp_value_min": 1.0}, {"hp_value_max": 3.0}, {"hp_value_min": 3.0, "hp_value_max": 3.0},
	{"hp_value_min": 1.0, "hp_value_max": 1.0},
	{"set_share_tol": 0.04}, {"set_share_tol": 0.15},
	{"synergy_min": 3}, {"synergy_min": 8},
	{"vanilla_2drop": 0.01},
	{"p_kill": 0.3}, {"p_kill": 0.6},
	{"set_share.war.minion": 0.0}, {"set_share.war.minion": 1.0},
	{"starter_curve.bucket.1": [0, 15]}, {"starter_curve.bucket.1": [7, 7]},
]

## `[low path, low value, high path, high value]`: a pair inverted inside its safe
## range is one `E_RANGE` naming the low key.
const INVERTED_PAIRS: Array = [
	["starter_curve.avg_min", 3.0, "starter_curve.avg_max", 2.5],
	["plan_min", 7, "plan_max", 4],
	["hp_value_min", 2.5, "hp_value_max", 1.5],
]

## Every key the format requires. A `plan_tags` or `set_share` set row is not one:
## the rows follow the heroes that ship (AC-19: a fourth hero is data only).
const REQUIRED_PATHS: Array = [
	"starter_curve", "starter_curve.avg_min", "starter_curve.avg_max", "starter_curve.max_cost",
	"starter_curve.bucket", "starter_curve.bucket.0", "starter_curve.bucket.1", "starter_curve.bucket.2",
	"starter_curve.bucket.3", "starter_curve.bucket.4", "starter_curve.bucket.5", "starter_curve.bucket.6_plus",
	"plan_min", "plan_max", "plan_tags", "hp_value_min", "hp_value_max", "vanilla_2drop", "p_kill",
	"set_share", "set_share.war.minion", "set_share.war.spell",
	"set_share.war.weapon", "set_share_tol", "synergy_min",
]

const UNKNOWN_PATHS: Array = [
	"extra_key", "starter_curve.extra_key", "starter_curve.bucket.7", "plan_tags.neutral",
	"set_share.boss", "set_share.war.artifact",
]

## `[dotted path, wrong value, the field the entry names]`.
const WRONG_SHAPE: Array = [
	["starter_curve", 5, "starter_curve"],
	["starter_curve.avg_min", "2.4", "starter_curve.avg_min"],
	["starter_curve.avg_min", true, "starter_curve.avg_min"],
	["starter_curve.max_cost", 5.5, "starter_curve.max_cost"],
	["starter_curve.bucket", [], "starter_curve.bucket"],
	["starter_curve.bucket.1", "3-4", "starter_curve.bucket.1"],
	["starter_curve.bucket.1", [3], "starter_curve.bucket.1"],
	["starter_curve.bucket.1", [3, 4, 5], "starter_curve.bucket.1"],
	["starter_curve.bucket.1", [3.5, 4], "starter_curve.bucket.1"],
	["plan_min", "4", "plan_min"],
	["plan_min", 4.5, "plan_min"],
	["plan_tags", [], "plan_tags"],
	["plan_tags", {}, "plan_tags"],
	["plan_tags.war", "weapons", "plan_tags.war"],
	["plan_tags.war", [], "plan_tags.war"],
	["plan_tags.war", [1], "plan_tags.war[0]"],
	["plan_tags.war", ["weapons", ""], "plan_tags.war[1]"],
	["set_share", 1, "set_share"],
	["set_share", {}, "set_share"],
	["set_share.war", 0.5, "set_share.war"],
	["set_share.war.minion", "half", "set_share.war.minion"],
]


## The shipped `config` body, as JSON parses it (every number a `float`).
func _body() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SHIPPED))
	return (parsed as Dictionary).config


## The object holding the last segment of [param path], and that segment.
func _parent(body: Dictionary, path: String) -> Array:
	var keys: PackedStringArray = path.split(".")
	var at: Dictionary = body
	for i: int in keys.size() - 1:
		at = at[keys[i]]
	return [at, keys[keys.size() - 1]]


func _with(path: String, value: Variant) -> Dictionary:
	var body: Dictionary = _body()
	var slot: Array = _parent(body, path)
	(slot[0] as Dictionary)[slot[1]] = value
	return body


func _codes_and_fields(rows: Array) -> Array:
	return rows.map(func(r: Dictionary) -> Array: return [String(r.code), str(r.field)])


# --- AC-1 ----------------------------------------------------------------------------

func test_the_shipped_body_is_valid() -> void:
	# Act
	var rows: Array = Heroes.validate_config(_body(), null)

	# Assert
	assert_array(rows).is_empty()


# --- AC-2: safe ranges ---------------------------------------------------------------

func test_each_knob_outside_its_range_is_one_range_entry_naming_it() -> void:
	for row: Array in OUT_OF_RANGE:
		# Arrange
		var path: String = row[0]

		# Act
		var rows: Array = Heroes.validate_config(_with(path, row[1]), null)

		# Assert
		assert_array(_codes_and_fields(rows)).override_failure_message("%s = %s gave %s" % [path, str(row[1]), str(rows)]) \
			.is_equal([["E_RANGE", path]])


func test_each_edge_of_each_range_is_accepted() -> void:
	for edits: Dictionary in AT_THE_EDGES:
		# Arrange
		var body: Dictionary = _body()
		for path: String in edits:
			var slot: Array = _parent(body, path)
			(slot[0] as Dictionary)[slot[1]] = edits[path]

		# Act
		var rows: Array = Heroes.validate_config(body, null)

		# Assert
		assert_array(rows).override_failure_message("%s gave %s" % [str(edits), str(rows)]).is_empty()


func test_an_inverted_pair_inside_its_range_is_one_range_entry_on_the_low_key() -> void:
	for row: Array in INVERTED_PAIRS:
		# Arrange
		var body: Dictionary = _with(row[0], row[1])
		var high: Array = _parent(body, row[2])
		(high[0] as Dictionary)[high[1]] = row[3]

		# Act
		var rows: Array = Heroes.validate_config(body, null)

		# Assert
		assert_array(_codes_and_fields(rows)).override_failure_message("%s gave %s" % [str(row), str(rows)]) \
			.is_equal([["E_RANGE", row[0]]])


# --- AC-2: the key list --------------------------------------------------------------

func test_each_required_key_removed_is_one_missing_field_entry_naming_it() -> void:
	for path: String in REQUIRED_PATHS:
		# Arrange
		var body: Dictionary = _body()
		var slot: Array = _parent(body, path)
		(slot[0] as Dictionary).erase(slot[1])

		# Act
		var rows: Array = Heroes.validate_config(body, null)

		# Assert
		assert_array(_codes_and_fields(rows)).override_failure_message("%s removed gave %s" % [path, str(rows)]) \
			.is_equal([["E_MISSING_FIELD", path]])


func test_each_extra_key_is_one_unknown_field_entry_naming_it() -> void:
	for path: String in UNKNOWN_PATHS:
		# Arrange — a value of a valid shape for the key, so only the name is wrong
		var value: Variant = _extra_value(path)

		# Act
		var rows: Array = Heroes.validate_config(_with(path, value), null)

		# Assert
		assert_array(_codes_and_fields(rows)).override_failure_message("%s added gave %s" % [path, str(rows)]) \
			.is_equal([["E_UNKNOWN_FIELD", path]])


func _extra_value(path: String) -> Variant:
	if path.begins_with("plan_tags."):
		return ["fixture_tag"]
	if path == "set_share.boss":
		return {"minion": 0.5, "spell": 0.5, "weapon": 0.0}
	return 1


func test_a_set_with_no_hero_yet_may_hold_a_row() -> void:
	# Arrange — AC-19: a fourth hero's rows are data, not a code change
	var body: Dictionary = _with("plan_tags.fortune", ["fixture_tag"])
	var slot: Array = _parent(body, "set_share.fortune")
	(slot[0] as Dictionary)[slot[1]] = {"minion": 0.5, "spell": 0.5, "weapon": 0.0}

	# Act
	var rows: Array = Heroes.validate_config(body, null)

	# Assert
	assert_array(rows).is_empty()


func test_each_wrong_shape_is_one_schema_entry_naming_the_field() -> void:
	for row: Array in WRONG_SHAPE:
		# Act
		var rows: Array = Heroes.validate_config(_with(row[0], row[1]), null)

		# Assert
		assert_array(_codes_and_fields(rows)).override_failure_message("%s = %s gave %s" % [row[0], str(row[1]), str(rows)]) \
			.is_equal([["E_SCHEMA", row[2]]])


# --- The stage-7a contract (ADR-0002 Decision 4) -------------------------------------

func test_a_whole_number_may_arrive_as_a_json_float_or_an_int() -> void:
	# Arrange
	var as_float: Dictionary = _with("plan_min", 5.0)
	var as_int: Dictionary = _with("plan_min", 5)

	# Act / Assert
	assert_array(Heroes.validate_config(as_float, null)).is_empty()
	assert_array(Heroes.validate_config(as_int, null)).is_empty()


func test_every_fault_is_reported_not_only_the_first() -> void:
	# Arrange
	var body: Dictionary = _with("synergy_min", 9)
	body.erase("plan_min")

	# Act
	var rows: Array = Heroes.validate_config(body, null)

	# Assert
	assert_array(_codes_and_fields(rows)).contains_exactly_in_any_order([["E_MISSING_FIELD", "plan_min"], ["E_RANGE", "synergy_min"]])


func test_an_empty_body_is_one_missing_field_entry_per_top_level_key() -> void:
	# Act
	var rows: Array = Heroes.validate_config({}, null)

	# Assert
	assert_int(rows.size()).is_equal(_body().size())
	for row: Dictionary in rows:
		assert_str(String(row.code)).is_equal("E_MISSING_FIELD")


func test_an_entry_has_the_adr_0002_shape_and_its_message_names_the_key() -> void:
	# Act
	var rows: Array = Heroes.validate_config(_with("synergy_min", 9), null)

	# Assert
	assert_array((rows[0] as Dictionary).keys()).contains_exactly_in_any_order(["code", "host_id", "field", "message"])
	assert_that(rows[0].host_id).is_null()
	assert_str(str(rows[0].message)).contains("synergy_min")


func test_validate_config_is_a_callable_with_the_stage_7a_arguments() -> void:
	# Arrange — how `Boot` registers it, and how `DataLoader` calls it
	var validator: Callable = Heroes.validate_config

	# Act
	var rows: Variant = validator.call(_body(), null)

	# Assert
	assert_bool(rows is Array).is_true()
	assert_array(rows as Array).is_empty()
