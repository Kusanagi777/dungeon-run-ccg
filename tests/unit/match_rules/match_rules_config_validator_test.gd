## Unit tests for `RulesEngine.validate_rules_config` — the `match_rules`
## config validator (story match-rules/story-001; design/gdd/match-rules.md
## Tuning Knobs; card-database CR-5 stage 7a; ADR-0002 Decision 4).
##
## Bodies are built in memory from `MatchFactory.make_rules_config()` (the
## Tuning Knobs defaults via `TestConstants`); no file is read. Boundary values
## come from `RulesEngine.CONFIG_SAFE_RANGES`, whose rows the integration suite
## `match_rules_config_file_test.gd` pins to the GDD table.
extends GdUnitTestSuite

const BOOT_SCRIPT: GDScript = preload("res://src/core/boot.gd")
const ENTRY_KEYS: Array[String] = ["severity", "code", "file", "record_id", "field", "message"]


func _validate(body: Dictionary) -> Array:
	return RulesEngine.validate_rules_config(body, null)


## The shipped defaults without [param key].
func _body_without(key: String) -> Dictionary:
	var body: Dictionary = MatchFactory.make_rules_config().duplicate()
	body.erase(key)
	return body


func _codes(errors: Array) -> Array:
	return errors.map(func(e: Dictionary) -> StringName: return e.code)


func _fields(errors: Array) -> Array:
	return errors.map(func(e: Dictionary) -> Variant: return e.field)


func test_valid_body_with_the_tuning_knob_defaults_returns_no_errors() -> void:
	# Act
	var errors: Array = _validate(MatchFactory.make_rules_config())

	# Assert
	assert_array(errors).is_empty()


func test_every_safe_range_boundary_value_is_accepted() -> void:
	# Arrange — every knob at its minimum, then every knob at its maximum
	var at_min: Dictionary = {}
	var at_max: Dictionary = {}
	for key: String in RulesEngine.CONFIG_KEYS:
		at_min[key] = RulesEngine.CONFIG_SAFE_RANGES[key][0]
		at_max[key] = RulesEngine.CONFIG_SAFE_RANGES[key][1]
	for key: String in RulesEngine.CONFIG_BAND_KEYS:
		at_min[key] = (RulesEngine.CONFIG_BAND_SAFE_RANGES[key] as Array).map(func(b: Array) -> int: return int(b[0]))
		at_max[key] = (RulesEngine.CONFIG_BAND_SAFE_RANGES[key] as Array).map(func(b: Array) -> int: return int(b[1]))

	# Act / Assert
	assert_array(_validate(at_min)).is_empty()
	assert_array(_validate(at_max)).is_empty()


func test_whole_number_floats_from_json_are_accepted() -> void:
	# Arrange — JSON parses every number as float
	var body: Dictionary = {}
	for key: String in RulesEngine.CONFIG_KEYS:
		body[key] = float(MatchFactory.make_rules_config()[key])
	for key: String in RulesEngine.CONFIG_BAND_KEYS:
		body[key] = (MatchFactory.make_rules_config()[key] as Array).map(func(v: Variant) -> float: return float(v))

	# Act / Assert
	assert_array(_validate(body)).is_empty()


func test_missing_knob_reports_e_rules_missing_knob_naming_the_key() -> void:
	# Act
	var errors: Array = _validate(_body_without("hand_size"))

	# Assert
	assert_array(_codes(errors)).is_equal([RulesEngine.E_RULES_MISSING_KNOB])
	assert_str(errors[0].field).is_equal("hand_size")
	assert_str(errors[0].message).contains("hand_size")


func test_empty_body_reports_every_knob_missing_in_config_keys_order() -> void:
	# Act
	var errors: Array = _validate({})

	# Assert — the whole-number knobs, then the per-band knobs
	assert_array(_fields(errors)).is_equal(Array(RulesEngine.CONFIG_KEYS) + Array(RulesEngine.CONFIG_BAND_KEYS))
	for e: Dictionary in errors:
		assert_bool(e.code == RulesEngine.E_RULES_MISSING_KNOB).is_true()


func test_fractional_knob_reports_e_rules_not_integer() -> void:
	# Act
	var errors: Array = _validate(MatchFactory.make_rules_config({"board_size": 6.5}))

	# Assert
	assert_array(_codes(errors)).is_equal([RulesEngine.E_RULES_NOT_INTEGER])
	assert_str(errors[0].field).is_equal("board_size")
	assert_str(errors[0].message).contains("6.5")


func test_string_bool_and_null_knobs_report_e_rules_not_integer() -> void:
	# Arrange — `"7"` is a string in JSON, not a number
	var body: Dictionary = MatchFactory.make_rules_config({"board_size": "7", "max_mana": true, "turn_cap": null})

	# Act
	var errors: Array = _validate(body)

	# Assert — CONFIG_KEYS order: board_size, max_mana, turn_cap
	assert_array(_codes(errors)).is_equal([RulesEngine.E_RULES_NOT_INTEGER, RulesEngine.E_RULES_NOT_INTEGER, RulesEngine.E_RULES_NOT_INTEGER])
	assert_array(_fields(errors)).is_equal(["board_size", "max_mana", "turn_cap"])


func test_knob_one_past_either_bound_reports_e_rules_out_of_range() -> void:
	# Arrange — one past the maximum on one knob, one below the minimum on another
	var over: int = int(RulesEngine.CONFIG_SAFE_RANGES["max_attacks_cap"][1]) + 1
	var under: int = int(RulesEngine.CONFIG_SAFE_RANGES["hand_size"][0]) - 1
	var body: Dictionary = MatchFactory.make_rules_config({"max_attacks_cap": over, "hand_size": under})

	# Act
	var errors: Array = _validate(body)

	# Assert — CONFIG_KEYS order: hand_size before max_attacks_cap
	assert_array(_codes(errors)).is_equal([RulesEngine.E_RULES_OUT_OF_RANGE, RulesEngine.E_RULES_OUT_OF_RANGE])
	assert_array(_fields(errors)).is_equal(["hand_size", "max_attacks_cap"])
	assert_str(errors[1].message).contains(str(over))


# --- boss_starting_health_by_band (DD-M02; fix pass 2026-11-04) ---------------

const BAND_KEY: String = "boss_starting_health_by_band"


func test_band_health_defaults_are_the_dd_m02_values() -> void:
	# Act / Assert — band 1 = 30, band 2 = 40, band 3 = 50 (TestConstants, registry)
	assert_array(MatchFactory.make_rules_config()[BAND_KEY]).is_equal(Array(TestConstants.BOSS_STARTING_HEALTH_BY_BAND))
	assert_array(RulesEngine.CONFIG_BAND_KEYS).is_equal([BAND_KEY])


func test_missing_band_health_reports_e_rules_missing_knob() -> void:
	# Act
	var errors: Array = _validate(_body_without(BAND_KEY))

	# Assert
	assert_array(_codes(errors)).is_equal([RulesEngine.E_RULES_MISSING_KNOB])
	assert_str(errors[0].field).is_equal(BAND_KEY)


func test_band_health_that_is_not_one_entry_per_band_reports_e_rules_not_band_list() -> void:
	# Arrange — a scalar, a map, and a list one band short
	var bodies: Array = [
		MatchFactory.make_rules_config({BAND_KEY: 30}),
		MatchFactory.make_rules_config({BAND_KEY: {"1": 30, "2": 40, "3": 50}}),
		MatchFactory.make_rules_config({BAND_KEY: [30, 40]}),
	]

	# Act / Assert
	for body: Dictionary in bodies:
		var errors: Array = _validate(body)
		assert_array(_codes(errors)).is_equal([RulesEngine.E_RULES_NOT_BAND_LIST])
		assert_array(_fields(errors)).is_equal([BAND_KEY])


func test_band_health_entry_that_is_not_whole_reports_e_rules_not_integer() -> void:
	# Act
	var errors: Array = _validate(MatchFactory.make_rules_config({BAND_KEY: [30, 40.5, "50"]}))

	# Assert — one error per bad band, band order
	assert_array(_codes(errors)).is_equal([RulesEngine.E_RULES_NOT_INTEGER, RulesEngine.E_RULES_NOT_INTEGER])
	assert_str(errors[0].message).contains("band 2")
	assert_str(errors[1].message).contains("band 3")


func test_band_health_entry_one_past_its_band_range_reports_e_rules_out_of_range() -> void:
	# Arrange — band 1 one over its max, band 3 one under its min
	var ranges: Array = RulesEngine.CONFIG_BAND_SAFE_RANGES[BAND_KEY]
	var over: int = int(ranges[0][1]) + 1
	var under: int = int(ranges[2][0]) - 1

	# Act
	var errors: Array = _validate(MatchFactory.make_rules_config({BAND_KEY: [over, int(ranges[1][0]), under]}))

	# Assert
	assert_array(_codes(errors)).is_equal([RulesEngine.E_RULES_OUT_OF_RANGE, RulesEngine.E_RULES_OUT_OF_RANGE])
	assert_array(_fields(errors)).is_equal([BAND_KEY, BAND_KEY])
	assert_str(errors[0].message).contains("band 1")
	assert_str(errors[0].message).contains(str(over))
	assert_str(errors[1].message).contains("band 3")


func test_errors_have_the_validation_report_entry_shape() -> void:
	# Arrange — one of each problem
	var body: Dictionary = _body_without("fatigue_step")
	body["board_size"] = 1.5
	body["turn_cap"] = 1

	# Act
	var errors: Array = _validate(body)

	# Assert
	assert_int(errors.size()).is_equal(3)
	for e: Dictionary in errors:
		assert_array(e.keys()).contains_exactly_in_any_order(ENTRY_KEYS)
		assert_bool(e.severity == ValidationReport.SEVERITY_ERROR).is_true()
		assert_str(e.file).is_equal("match_rules.json")
		assert_object(e.record_id).is_null()
		assert_str(e.message).is_not_empty()


func test_boot_registers_the_validator_as_the_match_rules_config_validator() -> void:
	# Arrange — a fresh Boot instance; boot() is not called
	var boot: Node = auto_free(BOOT_SCRIPT.new())

	# Act
	var configs: Dictionary = boot._collect_validators(null).configs
	var registered: Callable = configs.get("match_rules", Callable())

	# Assert — the registered Callable is this validator
	assert_bool(registered.is_valid()).is_true()
	assert_array(registered.call(MatchFactory.make_rules_config(), null)).is_empty()
	assert_array(_codes(registered.call(_body_without("max_mana"), null))).is_equal([RulesEngine.E_RULES_MISSING_KNOB])
