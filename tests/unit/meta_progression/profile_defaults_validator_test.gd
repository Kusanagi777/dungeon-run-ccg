## Unit tests for `ProfileDefaults.validate_config`, the stage-7a validator of
## `assets/data/profile_defaults.json` (design/gdd/meta-progression.md M9, Tuning
## Knobs, F7; ADR-0004 addendum 1).
extends GdUnitTestSuite

const KNOBS: String = ProfileStore.KNOBS_KEY


func _codes(rows: Array) -> Array:
	return rows.map(func(row: Dictionary) -> String: return String(row.code))


func _fields(rows: Array) -> Array:
	return rows.map(func(row: Dictionary) -> String: return row.field)


func _rows_with_knob(knob: String, value: Variant) -> Array:
	var body: Dictionary = ProfileFixtures.defaults_body()
	body[KNOBS][knob] = value
	return ProfileDefaults.validate_config(body, null)


func test_validate_config_accepts_the_gdd_defaults() -> void:
	# Act / Assert
	assert_array(ProfileDefaults.validate_config(ProfileFixtures.defaults_body(), null)).is_empty()


func test_validate_config_names_a_missing_setting() -> void:
	# Arrange
	var body: Dictionary = ProfileFixtures.defaults_body()
	body.erase("gamma")

	# Act
	var rows: Array = ProfileDefaults.validate_config(body, null)

	# Assert
	assert_array(_codes(rows)).is_equal([String(ValidationReport.E_MISSING_FIELD)])
	assert_array(_fields(rows)).is_equal(["gamma"])


func test_validate_config_refuses_each_setting_outside_m9() -> void:
	# Arrange
	var bad: Dictionary = {"volume_music": 1.5, "anim_speed": "1.5", "text_scale": 2.0, "gamma": 0.5,
		"action_delay_ms": 3000, "fullscreen": "no", "telegraph_mode": "maybe"}

	# Act / Assert
	for key: String in bad:
		var body: Dictionary = ProfileFixtures.defaults_body()
		body[key] = bad[key]
		var rows: Array = ProfileDefaults.validate_config(body, null)
		assert_array(_codes(rows)).override_failure_message(key).is_equal([String(ProfileDefaults.E_RANGE)])
		assert_array(_fields(rows)).is_equal([key])


func test_validate_config_refuses_a_key_m9_does_not_name() -> void:
	# Arrange
	var body: Dictionary = ProfileFixtures.defaults_body()
	body["mystery"] = 1

	# Act
	var rows: Array = ProfileDefaults.validate_config(body, null)

	# Assert
	assert_array(_codes(rows)).is_equal([String(ValidationReport.E_UNKNOWN_FIELD)])


func test_validate_config_refuses_bindings_in_the_defaults() -> void:
	# Arrange
	var body: Dictionary = ProfileFixtures.defaults_body()
	body["bindings"] = {}

	# Act
	var rows: Array = ProfileDefaults.validate_config(body, null)

	# Assert (ADR-0004 addendum 1)
	assert_array(_codes(rows)).is_equal([String(ValidationReport.E_UNKNOWN_FIELD)])
	assert_array(_fields(rows)).is_equal(["bindings"])


func test_validate_config_needs_the_knobs_object() -> void:
	# Arrange
	var body: Dictionary = ProfileFixtures.settings_defaults()

	# Act
	var rows: Array = ProfileDefaults.validate_config(body, null)

	# Assert
	assert_array(_codes(rows)).is_equal([String(ValidationReport.E_MISSING_FIELD)])
	assert_array(_fields(rows)).is_equal([KNOBS])


func test_validate_config_names_each_missing_knob() -> void:
	# Arrange
	for knob: String in ProfileDefaults.KNOB_RANGES:
		var body: Dictionary = ProfileFixtures.defaults_body()
		(body[KNOBS] as Dictionary).erase(knob)

		# Act
		var rows: Array = ProfileDefaults.validate_config(body, null)

		# Assert
		assert_array(_fields(rows)).override_failure_message(knob).contains(["%s.%s" % [KNOBS, knob]])


func test_validate_config_accepts_each_knob_at_both_ends_of_its_safe_range() -> void:
	# Arrange: the stale floor below follows the heartbeat, and the pair is its own test
	var coupled: Array[String] = ["lock_heartbeat_s", "lock_stale_s"]
	for knob: String in ProfileDefaults.KNOB_RANGES:
		if coupled.has(knob):
			continue
		var bounds: Array = ProfileDefaults.KNOB_RANGES[knob]

		# Act / Assert
		assert_array(_rows_with_knob(knob, bounds[0])).override_failure_message("%s low" % knob).is_empty()
		assert_array(_rows_with_knob(knob, bounds[1])).override_failure_message("%s high" % knob).is_empty()


func test_validate_config_refuses_each_knob_just_outside_its_safe_range() -> void:
	# Arrange
	for knob: String in ProfileDefaults.KNOB_RANGES:
		var bounds: Array = ProfileDefaults.KNOB_RANGES[knob]

		# Act
		var below: Array = _rows_with_knob(knob, int(bounds[0]) - 1)
		var above: Array = _rows_with_knob(knob, int(bounds[1]) + 1)

		# Assert
		var field: String = "%s.%s" % [KNOBS, knob]
		assert_array(_fields(below)).override_failure_message("%s below" % knob).contains([field])
		assert_array(_fields(above)).override_failure_message("%s above" % knob).contains([field])


func test_validate_config_knob_ranges_are_the_tuning_knobs_table() -> void:
	# Act / Assert: the table's own rows, boundary by boundary
	var table: Dictionary = {
		"run_log_cap": [20, 1000], "archive_top_cards": [5, 36], "max_profile_bytes": [1048576, 8388608],
		"max_save_ms": [16, 200], "backup_count": [1, 3], "io_retry_ms": [0, 2000],
		"settings_write_debounce_ms": [0, 2000], "lock_heartbeat_s": [10, 120], "lock_stale_s": [60, 600],
		"max_condition_depth": [2, 5], "max_condition_n": [1, 9999], "max_condition_fan_out": [2, 16],
		"max_repairs_before_rebuild": [5, 100],
	}
	for knob: String in table:
		assert_array(ProfileDefaults.KNOB_RANGES[knob]).override_failure_message(knob).is_equal(table[knob])


func test_validate_config_max_floor_clamp_must_be_the_top_of_floors_per_run() -> void:
	# Act / Assert (Tuning Knobs: "= top of run-structure floors_per_run range")
	assert_array(_rows_with_knob("max_floor_clamp", 12)).is_empty()
	assert_array(_codes(_rows_with_knob("max_floor_clamp", 11))).is_equal([String(ProfileDefaults.E_RANGE)])


func test_validate_config_refuses_a_fractional_knob() -> void:
	# Act
	var rows: Array = _rows_with_knob("run_log_cap", 200.5)

	# Assert
	assert_array(_codes(rows)).is_equal([String(ProfileDefaults.E_RANGE)])


func test_validate_config_stale_must_be_twice_the_heartbeat() -> void:
	# Arrange
	var body: Dictionary = ProfileFixtures.defaults_body()
	body[KNOBS]["lock_heartbeat_s"] = 40
	body[KNOBS]["lock_stale_s"] = 79

	# Act
	var short: Array = ProfileDefaults.validate_config(body, null)
	body[KNOBS]["lock_stale_s"] = 80
	var exact: Array = ProfileDefaults.validate_config(body, null)

	# Assert (F7)
	assert_array(_fields(short)).is_equal(["%s.lock_stale_s" % KNOBS])
	assert_array(exact).is_empty()


func test_validate_config_needs_a_non_empty_reset_token() -> void:
	# Act
	var empty: Array = _rows_with_knob(ProfileDefaults.TOKEN_KNOB, "")
	var number: Array = _rows_with_knob(ProfileDefaults.TOKEN_KNOB, 5)

	# Assert
	assert_int(empty.size()).is_equal(1)
	assert_int(number.size()).is_equal(1)


func test_validate_config_refuses_an_unknown_knob() -> void:
	# Act
	var rows: Array = _rows_with_knob("mystery_knob", 1)

	# Assert
	assert_array(_codes(rows)).is_equal([String(ValidationReport.E_UNKNOWN_FIELD)])


func test_validate_config_reports_every_problem_at_once() -> void:
	# Arrange
	var body: Dictionary = ProfileFixtures.defaults_body()
	body.erase("gamma")
	body["volume_music"] = 9
	body[KNOBS]["run_log_cap"] = 5

	# Act / Assert
	assert_int(ProfileDefaults.validate_config(body, null).size()).is_equal(3)
