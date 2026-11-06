## Unit: the `treasures_balance` stage-7a validator (treasures story 010;
## design/gdd/treasures.md Tuning Knobs; card-database CR-5 stage 7a; ADR-0002
## Decision 4).
##
## The safe ranges below are the GDD's rows, written here on their own so a drift in
## `Treasures.NUMBER_KNOB_RANGES` fails: `v_*` are the stated values +-50 %.
extends GdUnitTestSuite

const MAX_EFFECTS: String = "max_effects_per_treasure"
const COMMON: String = "common_band"
const RARE: String = "rare_band"
## Tuning Knobs: `V_CARD`, `V_DMG`, `V_HP`, `V_STAT`, `V_TOKEN`, `V_RUSH`.
const V_VALUES: Dictionary = {"v_card": 1.5, "v_dmg": 0.5, "v_hp": 0.35, "v_stat": 0.5, "v_token": 1.0, "v_rush": 0.5}
const V_SPREAD: float = 0.5
const ETA_KEYS: Array[String] = ["eta_mana", "eta_crystal", "eta_first", "eta_overheal"]
const ETA_LOW: float = 0.4
const ETA_HIGH: float = 1.0
const MAX_EFFECTS_LOW: int = 1
const MAX_EFFECTS_HIGH: int = 5
## Past a bound by more than rounding, less than any knob's step.
const JUST_OUTSIDE: float = 0.001

var _shipped: Dictionary = {}


func before() -> void:
	_shipped = TreasureFixtures.shipped_database().config("treasures_balance")


func _body(overrides: Dictionary = {}) -> Dictionary:
	var body: Dictionary = _shipped.duplicate(true)
	body.merge(overrides, true)
	return body


func _rows(overrides: Dictionary = {}) -> Array:
	return Treasures.validate_config(_body(overrides), null)


func _assert_one_row(rows: Array, code: StringName, field: String, label: String) -> void:
	assert_int(rows.size()).override_failure_message("%s: %s" % [label, str(rows)]).is_equal(1)
	if rows.size() == 1:
		assert_str(str(rows[0].code)).override_failure_message(label).is_equal(String(code))
		assert_str(str(rows[0].field)).override_failure_message(label).is_equal(field)


func _number_bounds() -> Dictionary:
	var bounds: Dictionary = {}
	for key: String in V_VALUES:
		var value: float = V_VALUES[key]
		bounds[key] = [value * (1.0 - V_SPREAD), value * (1.0 + V_SPREAD)]
	for key: String in ETA_KEYS:
		bounds[key] = [ETA_LOW, ETA_HIGH]
	return bounds


func test_ac1_the_shipped_body_is_clean() -> void:
	# Act and Assert
	assert_array(Treasures.validate_config(_shipped, null)).is_empty()


func test_ac2_max_effects_outside_one_to_five_is_one_range_row() -> void:
	# Act and Assert
	_assert_one_row(_rows({MAX_EFFECTS: MAX_EFFECTS_LOW - 1}), Treasures.E_RANGE, MAX_EFFECTS, "below")
	_assert_one_row(_rows({MAX_EFFECTS: MAX_EFFECTS_HIGH + 1}), Treasures.E_RANGE, MAX_EFFECTS, "above")


func test_ac2_max_effects_at_its_bounds_is_clean() -> void:
	# Act and Assert
	assert_array(_rows({MAX_EFFECTS: MAX_EFFECTS_LOW})).is_empty()
	assert_array(_rows({MAX_EFFECTS: MAX_EFFECTS_HIGH})).is_empty()


func test_max_effects_as_a_json_whole_float_is_accepted() -> void:
	# Act and Assert
	assert_array(_rows({MAX_EFFECTS: float(MAX_EFFECTS_HIGH)})).is_empty()


func test_max_effects_that_is_not_whole_is_a_schema_row() -> void:
	# Act and Assert
	_assert_one_row(_rows({MAX_EFFECTS: 2.5}), ValidationReport.E_SCHEMA, MAX_EFFECTS, "fraction")
	_assert_one_row(_rows({MAX_EFFECTS: "3"}), ValidationReport.E_SCHEMA, MAX_EFFECTS, "text")


func test_ac2_every_number_knob_outside_its_range_is_one_range_row_naming_it() -> void:
	# Arrange
	var bounds: Dictionary = _number_bounds()

	# Act and Assert
	for key: String in bounds:
		_assert_one_row(_rows({key: float(bounds[key][0]) - JUST_OUTSIDE}), Treasures.E_RANGE, key, "%s below" % key)
		_assert_one_row(_rows({key: float(bounds[key][1]) + JUST_OUTSIDE}), Treasures.E_RANGE, key, "%s above" % key)


func test_ac2_every_number_knob_just_inside_its_range_is_clean() -> void:
	# Arrange
	var bounds: Dictionary = _number_bounds()

	# Act and Assert
	for key: String in bounds:
		assert_array(_rows({key: float(bounds[key][0]) + JUST_OUTSIDE})).override_failure_message(key).is_empty()
		assert_array(_rows({key: float(bounds[key][1]) - JUST_OUTSIDE})).override_failure_message(key).is_empty()


func test_a_number_knob_of_the_wrong_type_is_a_schema_row() -> void:
	# Act and Assert
	_assert_one_row(_rows({"v_card": "1.5"}), ValidationReport.E_SCHEMA, "v_card", "text")


func test_ac2_overlapping_bands_are_one_range_row_on_common_band() -> void:
	# Act
	var rows: Array = _rows({COMMON: [1.5, 4.0]})

	# Assert
	_assert_one_row(rows, Treasures.E_RANGE, COMMON, "overlap")


func test_bands_that_touch_are_clean() -> void:
	# Act and Assert
	assert_array(_rows({COMMON: [1.5, 3.5], RARE: [3.5, 6.5]})).is_empty()


func test_ac2_a_band_narrower_than_one_is_one_range_row_naming_it() -> void:
	# Act and Assert
	_assert_one_row(_rows({COMMON: [2.0, 2.5]}), Treasures.E_RANGE, COMMON, "common")
	_assert_one_row(_rows({RARE: [4.0, 4.5]}), Treasures.E_RANGE, RARE, "rare")


func test_a_band_exactly_one_wide_is_clean() -> void:
	# Act and Assert
	assert_array(_rows({COMMON: [2.5, 3.5]})).is_empty()


func test_a_band_that_is_not_a_pair_of_numbers_is_a_schema_row() -> void:
	# Act and Assert
	_assert_one_row(_rows({COMMON: [1.5]}), ValidationReport.E_SCHEMA, COMMON, "short")
	_assert_one_row(_rows({RARE: ["low", "high"]}), ValidationReport.E_SCHEMA, RARE, "text")
	_assert_one_row(_rows({COMMON: 2.0}), ValidationReport.E_SCHEMA, COMMON, "scalar")


func test_ac2_each_removed_key_is_one_missing_field_row_naming_it() -> void:
	# Act and Assert
	for key: String in _shipped:
		var body: Dictionary = _body()
		body.erase(key)
		_assert_one_row(Treasures.validate_config(body, null), ValidationReport.E_MISSING_FIELD, key, key)


func test_ac2_an_extra_key_is_one_unknown_field_row_naming_it() -> void:
	# Act and Assert
	_assert_one_row(_rows({"v_mana": 1.0}), ValidationReport.E_UNKNOWN_FIELD, "v_mana", "extra")


func test_an_empty_body_reports_every_key_missing() -> void:
	# Act
	var rows: Array = Treasures.validate_config({}, null)

	# Assert
	assert_int(rows.size()).is_equal(_shipped.size())
	for row: Dictionary in rows:
		assert_str(str(row.code)).is_equal(String(ValidationReport.E_MISSING_FIELD))


func test_rows_name_no_host() -> void:
	# Act
	var rows: Array = _rows({"v_card": 9.0})

	# Assert
	assert_that(rows[0].host_id).is_null()


func test_the_validator_leaves_the_body_as_it_was() -> void:
	# Arrange
	var body: Dictionary = _body({"v_card": 9.0})
	var before_call: Dictionary = body.duplicate(true)

	# Act
	@warning_ignore("return_value_discarded")
	Treasures.validate_config(body, null)

	# Assert
	assert_dict(body).is_equal(before_call)
