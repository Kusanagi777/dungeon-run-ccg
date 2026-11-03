## `EffectValidator.validate_config` — the `card_effects` stage-7a config
## validator (story card-effects/story-002 AC-41, which settles it after the
## interim one of the 2026-11-03 code review; design/gdd/card-effects.md
## Tuning Knobs, F6; ADR-0002 Decision 4; DD-T01: snake_case keys).
##
## Bodies are built in the test from `TestConstants` (the GDD defaults); the
## safe-range bounds come from `EffectValidator.CONFIG_INT_RANGES`, which one
## test pins to the GDD table (the integration suite pins it to the GDD text).
## No file is read.
extends GdUnitTestSuite

## card-effects Tuning Knobs, Safe range column (boundary values are the point).
const GDD_INT_RANGES: Dictionary = {
	"discover_count": [1, 5],
	"max_ops_per_effect": [4, 12],
	"max_repeat": [2, 20],
	"max_summon_count": [1, 7],
	"effect_static_step_limit": [50, 1000],
}
## The knobs, in the report order (whole-number knobs, then the others).
const GDD_KNOBS: Array[String] = [
	"discover_count", "max_ops_per_effect", "max_repeat", "max_summon_count",
	"effect_static_step_limit", "discover_exclude_hand", "spell_damage_default",
	"hooks_before_triggers",
]


## The GDD-default body, snake_case keys, numbers as floats (as JSON parses them).
func _defaults() -> Dictionary:
	return {
		"discover_count": float(TestConstants.DISCOVER_COUNT),
		"discover_exclude_hand": false,
		"max_ops_per_effect": float(TestConstants.MAX_OPS_PER_EFFECT),
		"max_repeat": float(TestConstants.MAX_REPEAT),
		"max_summon_count": float(TestConstants.BOARD_SIZE),
		"effect_static_step_limit": float(TestConstants.EFFECT_STATIC_STEP_LIMIT),
		"spell_damage_default": "auto",
		"hooks_before_triggers": true,
	}


func _fields(errors: Array) -> Array:
	return errors.map(func(e: Dictionary) -> String: return e.field)


func test_validate_config_gdd_defaults_return_no_entries() -> void:
	# Arrange
	var body: Dictionary = _defaults()

	# Act
	var errors: Array = EffectValidator.validate_config(body, null)

	# Assert
	assert_array(errors).is_empty()


func test_validate_config_upper_case_gdd_names_are_not_file_keys() -> void:
	# Arrange — every key under its GDD spelling: DD-T01 keys are snake_case,
	# so the interim dual spelling is gone and each knob is missing
	var body: Dictionary = {}
	var defaults: Dictionary = _defaults()
	for key: String in defaults:
		body[key.to_upper()] = defaults[key]

	# Act
	var errors: Array = EffectValidator.validate_config(body, null)

	# Assert — each snake_case knob missing, then each GDD-cased key unknown
	var upper: Array = GDD_KNOBS.map(func(k: String) -> String: return k.to_upper())
	upper.sort()
	var unknown: Array = _fields(errors.slice(GDD_KNOBS.size()))
	unknown.sort()
	assert_array(_fields(errors.slice(0, GDD_KNOBS.size()))).is_equal(GDD_KNOBS)
	assert_array(unknown).is_equal(upper)


func test_validate_config_empty_body_reports_every_knob_missing() -> void:
	# Act
	var errors: Array = EffectValidator.validate_config({}, null)

	# Assert — one E_FX_SCHEMA error per knob, field the file key
	assert_array(_fields(errors)).is_equal(GDD_KNOBS)
	for e: Dictionary in errors:
		assert_str(String(e.code)).is_equal(String(EffectValidator.E_FX_SCHEMA))
		assert_str(e.message).contains("missing knob")
		assert_object(e.host_id).is_null()


func test_validate_config_one_missing_knob_is_one_error_naming_it() -> void:
	# Arrange
	var body: Dictionary = _defaults()
	body.erase("max_repeat")

	# Act
	var errors: Array = EffectValidator.validate_config(body, null)

	# Assert
	assert_array(_fields(errors)).is_equal(["max_repeat"])


func test_validate_config_int_range_bounds_pass_and_one_beyond_fails() -> void:
	for knob: String in EffectValidator.CONFIG_INT_RANGES:
		var bounds: Array = EffectValidator.CONFIG_INT_RANGES[knob]
		for value: int in [int(bounds[0]), int(bounds[1])]:
			var ok_body: Dictionary = _defaults()
			ok_body[knob] = float(value)
			assert_array(EffectValidator.validate_config(ok_body, null)) \
				.override_failure_message("%s = %d should pass" % [knob, value]).is_empty()
		for value: int in [int(bounds[0]) - 1, int(bounds[1]) + 1]:
			var bad_body: Dictionary = _defaults()
			bad_body[knob] = float(value)
			var errors: Array = EffectValidator.validate_config(bad_body, null)
			assert_array(_fields(errors)).is_equal([knob])
			assert_str(errors[0].message).contains("outside the safe range")


func test_validate_config_non_whole_numbers_fail() -> void:
	for raw: Variant in [8.5, "8", true, null]:
		# Arrange
		var body: Dictionary = _defaults()
		body["max_ops_per_effect"] = raw

		# Act
		var errors: Array = EffectValidator.validate_config(body, null)

		# Assert
		assert_array(_fields(errors)).is_equal(["max_ops_per_effect"])
		assert_str(errors[0].message).contains("whole number")


func test_validate_config_non_numeric_knobs_accept_only_their_safe_values() -> void:
	var cases: Array = [
		["discover_exclude_hand", "false"],
		["spell_damage_default", true],
		["spell_damage_default", "manual"],
		["hooks_before_triggers", false],
	]
	for c: Array in cases:
		# Arrange
		var body: Dictionary = _defaults()
		body[c[0]] = c[1]

		# Act
		var errors: Array = EffectValidator.validate_config(body, null)

		# Assert
		assert_array(_fields(errors)).is_equal([c[0]])
	var off: Dictionary = _defaults()
	off["spell_damage_default"] = false
	off["discover_exclude_hand"] = true
	assert_array(EffectValidator.validate_config(off, null)).is_empty()


func test_validate_config_reports_an_unknown_key() -> void:
	# Arrange — a misspelt knob is not silently ignored (it would leave the
	# real one at whatever the file failed to set)
	var body: Dictionary = _defaults()
	body["max_repeats"] = 10.0

	# Act
	var errors: Array = EffectValidator.validate_config(body, null)

	# Assert
	assert_array(_fields(errors)).is_equal(["max_repeats"])
	assert_str(errors[0].message).contains("unknown knob")


func test_validate_config_ranges_match_the_gdd_tuning_knobs_table() -> void:
	assert_dict(EffectValidator.CONFIG_INT_RANGES).is_equal(GDD_INT_RANGES)
	assert_array(EffectValidator.CONFIG_KEYS).is_equal(GDD_KNOBS)
