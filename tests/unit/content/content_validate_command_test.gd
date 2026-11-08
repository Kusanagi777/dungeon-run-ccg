## Unit: the validate command's testable core and the `content_budgets`
## validator (content story 007; content.md CN-6 steps 2-3, Tuning Knobs;
## card-database CR-8; ADR-0002 Key Interfaces "tools/content/validate.gd").
##
## AC-1 in process: `ContentValidateCommand.run(root, validators)` over
## committed read-only fixture roots with injected `ValidatorStubs` maps —
## exit 0 `Ready`, 1 `Failed`, 2 could not run, and the printed text is the
## report's `to_text()`. The subprocess exit codes (the SceneTree entry and
## `quit(code)` on 4.7.2) are pinned in
## `tests/integration/content/content_validate_process_test.gd`.
## AC-2: `ContentValidator.validate_config` over bodies built by
## [method _valid_body] (the CN-6 step 2 key list at its Tuning Knobs
## defaults); each fault test changes one key. Boundary values are the safe
## range ends on purpose (the number is the point).
extends GdUnitTestSuite

const FIXTURES: String = "res://tests/fixtures/data/"
## Loads `Ready` with accepting stubs (card-database fixture).
const READY_ROOT: String = FIXTURES + "minimal/"
## `card_database.json` absent → `E_MISSING_FILE`.
const MISSING_FILE_ROOT: String = FIXTURES + "missing_config/"
## A hero names an unknown card → `E_UNKNOWN_REF`.
const UNKNOWN_REF_ROOT: String = FIXTURES + "refs_unknown/"
const NO_ROOT: String = FIXTURES + "content_validate_no_such_root/"


## The CN-6 step 2 body at the content.md Tuning Knobs / F1-F6 defaults.
func _valid_body() -> Dictionary:
	return {
		"curve": {"avg_min": 2.9, "avg_max": 3.4, "bucket": [0.16, 0.22, 0.24, 0.18, 0.10, 0.10],
			"bucket_tol": 0.08, "early_max": 2.5, "mid_max": 4.0},
		"budget": {
			"tol": {"common": 1.5, "rare": 2.0, "legendary": 3.0},
			"keyword_tax": {"taunt": 1.0, "charge": 2.0, "spell_damage": 1.5},
			"effect_points": {"damage_targeted": 1.5, "draw": 2.5, "self_destroy": -3.0},
		},
		"pressure": {"band": [7.0, 9.0, 11.5], "tol": 1.0, "passive_cap": [2.0, 3.5, 6.0]},
		"coverage": {"kw_min": 2.0, "bundle_coverage_min": 0.9, "ops_exempt": ["remove_keyword", "discard"]},
		"text_max_chars": 90.0,
		"pick_rate": {"min": 0.15, "max": 0.55, "min_sample": 30.0},
		"time": {"t_card": 0.42, "t_boss_card": 0.33, "t_boss": 2.5, "t_bundle": 0.2, "t_balance": 4.0},
		"set_share": {"neutral": {"minion": 0.82, "spell": 0.11, "weapon": 0.07},
			"boss": {"minion": 0.56, "spell": 0.41, "weapon": 0.03}},
		"share_tol": 0.08,
	}


## Sets `path` ("a.b.c") in `body` to `value`, or erases the key when
## `erase` is true.
func _with(body: Dictionary, path: String, value: Variant, erase: bool = false) -> Dictionary:
	var parts: PackedStringArray = path.split(".")
	var node: Dictionary = body
	for i: int in parts.size() - 1:
		node = node[parts[i]]
	if erase:
		node.erase(parts[parts.size() - 1])
	else:
		node[parts[parts.size() - 1]] = value
	return body


## Asserts `rows` is exactly one entry with `code` naming `field`, in the
## `{code, host_id: null, field, message}` shape.
func _assert_one(rows: Array, code: StringName, field: String) -> void:
	assert_int(rows.size()).override_failure_message("rows: %s" % str(rows)).is_equal(1)
	if rows.size() != 1:
		return
	var row: Dictionary = rows[0]
	assert_array(row.keys()).contains_exactly_in_any_order(["code", "host_id", "field", "message"])
	assert_str(String(row.code)).is_equal(String(code))
	assert_that(row.host_id).is_null()
	assert_str(row.field).is_equal(field)
	assert_str(row.message).contains(field)


# --- AC-1: exit contract (in process) ---------------------------------------------

func test_run_ready_root_exits_0_with_the_report_text() -> void:
	# Act
	var out: Dictionary = ContentValidateCommand.run(READY_ROOT, ValidatorStubs.accept_all())

	# Assert
	assert_int(out.exit_code).is_equal(ContentValidateCommand.EXIT_READY)
	assert_int(ContentValidateCommand.EXIT_READY).is_equal(0)
	assert_str(out.state).is_equal("Ready")
	var db: CardDatabase = CardDatabase.new(DataLoader.new(READY_ROOT))
	db.load(ValidatorStubs.accept_all())
	# The printed report is the load's plus the content story 008 checks, merged.
	var expected: ValidationReport = ValidationReport.new()
	for e: Dictionary in db.report().entries() + ContentValidator.run_checks(db, db.config("content_budgets"), db.config("heroes_balance")):
		expected.add(e.severity, e.code, e.file, e.record_id, e.field, e.message)
	assert_str(out.report_text).starts_with(expected.to_text())


func test_run_missing_file_root_exits_1_and_prints_e_missing_file() -> void:
	# Act
	var out: Dictionary = ContentValidateCommand.run(MISSING_FILE_ROOT, ValidatorStubs.accept_all())

	# Assert
	assert_int(out.exit_code).is_equal(ContentValidateCommand.EXIT_FAILED)
	assert_int(ContentValidateCommand.EXIT_FAILED).is_equal(1)
	assert_str(out.state).is_equal("Failed")
	assert_str(out.report_text).contains("[error] E_MISSING_FILE card_database.json")


func test_run_unknown_ref_root_exits_1_and_prints_e_unknown_ref() -> void:
	# Act
	var out: Dictionary = ContentValidateCommand.run(UNKNOWN_REF_ROOT, ValidatorStubs.accept_all())

	# Assert
	assert_int(out.exit_code).is_equal(ContentValidateCommand.EXIT_FAILED)
	assert_str(out.report_text).contains("E_UNKNOWN_REF")


func test_run_missing_validator_exits_1_with_e_delegated() -> void:
	# Arrange — a map without the content_budgets validator (no silent pass)
	var map: Dictionary = ValidatorStubs.accept_all()
	(map.configs as Dictionary).erase("content_budgets")

	# Act
	var out: Dictionary = ContentValidateCommand.run(READY_ROOT, map)

	# Assert
	assert_int(out.exit_code).is_equal(ContentValidateCommand.EXIT_FAILED)
	assert_str(out.report_text).contains("[error] E_DELEGATED content_budgets.json")


func test_run_non_existent_root_exits_2_and_loads_nothing() -> void:
	# Act
	var out: Dictionary = ContentValidateCommand.run(NO_ROOT, ValidatorStubs.accept_all())

	# Assert
	assert_int(out.exit_code).is_equal(ContentValidateCommand.EXIT_NOT_RUN)
	assert_int(ContentValidateCommand.EXIT_NOT_RUN).is_equal(2)
	assert_str(out.state).is_equal("NotRun")
	assert_str(out.report_text).contains(NO_ROOT)


func test_run_prints_the_load_time_as_an_observation_line() -> void:
	# Act
	var out: Dictionary = ContentValidateCommand.run(READY_ROOT, ValidatorStubs.accept_all())

	# Assert — the time is printed, never judged (no wall-clock assertion)
	assert_str(out.report_text).contains("validate: Ready")
	assert_str(out.report_text).contains("load ms")
	assert_str(out.report_text).contains("data_load_budget_ms")
	assert_str(out.report_text).not_contains("over budget")


func test_parse_args_reads_data_root_in_both_spellings_and_defaults_to_assets_data() -> void:
	# Act / Assert
	assert_str(ContentValidateCommand.parse_args([]).data_root).is_equal("res://assets/data/")
	assert_str(ContentValidateCommand.parse_args(["--data-root", "res://x/"]).data_root).is_equal("res://x/")
	assert_str(ContentValidateCommand.parse_args(["--data-root=res://y/"]).data_root).is_equal("res://y/")


func test_parse_args_rejects_an_unknown_argument_or_a_missing_value() -> void:
	# Act / Assert
	assert_str(ContentValidateCommand.parse_args(["--bogus"]).error).contains("--bogus")
	assert_str(ContentValidateCommand.parse_args(["--data-root"]).error).contains("--data-root")
	assert_str(ContentValidateCommand.parse_args([]).error).is_empty()


# --- AC-2: the content_budgets validator ---------------------------------------------

func test_validate_config_accepts_the_default_body() -> void:
	# Act / Assert
	assert_array(ContentValidator.validate_config(_valid_body(), null)).is_empty()


func test_validate_config_accepts_the_safe_range_ends() -> void:
	# Arrange — boundary values: the Tuning Knobs safe-range ends
	var body: Dictionary = _valid_body()
	_with(body, "text_max_chars", 70.0)
	_with(body, "coverage.kw_min", 4.0)
	_with(body, "curve.bucket_tol", 0.15)

	# Act / Assert
	assert_array(ContentValidator.validate_config(body, null)).is_empty()


func test_validate_config_missing_top_level_key_is_one_e_missing_field() -> void:
	# Act
	var rows: Array = ContentValidator.validate_config(_with(_valid_body(), "share_tol", null, true), null)

	# Assert
	_assert_one(rows, ContentValidator.E_MISSING_FIELD, "share_tol")


func test_validate_config_missing_nested_key_is_one_e_missing_field() -> void:
	# Act
	var rows: Array = ContentValidator.validate_config(_with(_valid_body(), "time.t_boss", null, true), null)

	# Assert
	_assert_one(rows, ContentValidator.E_MISSING_FIELD, "time.t_boss")


func test_validate_config_wrong_type_is_one_e_schema() -> void:
	# Act
	var rows: Array = ContentValidator.validate_config(_with(_valid_body(), "curve.avg_min", "2.9"), null)

	# Assert
	_assert_one(rows, ContentValidator.E_SCHEMA, "curve.avg_min")


func test_validate_config_fractional_integer_knob_is_one_e_schema() -> void:
	# Act
	var rows: Array = ContentValidator.validate_config(_with(_valid_body(), "text_max_chars", 90.5), null)

	# Assert
	_assert_one(rows, ContentValidator.E_SCHEMA, "text_max_chars")


func test_validate_config_object_given_a_number_is_one_e_schema() -> void:
	# Act
	var rows: Array = ContentValidator.validate_config(_with(_valid_body(), "pick_rate", 0.15), null)

	# Assert
	_assert_one(rows, ContentValidator.E_SCHEMA, "pick_rate")


func test_validate_config_value_above_range_is_one_e_range() -> void:
	# Act — TEXT_MAX_CHARS safe range 70-110
	var rows: Array = ContentValidator.validate_config(_with(_valid_body(), "text_max_chars", 111.0), null)

	# Assert
	_assert_one(rows, ContentValidator.E_RANGE, "text_max_chars")


func test_validate_config_value_below_range_is_one_e_range() -> void:
	# Act — BUDGET_TOL safe range 1-4
	var rows: Array = ContentValidator.validate_config(_with(_valid_body(), "budget.tol.rare", 0.5), null)

	# Assert
	_assert_one(rows, ContentValidator.E_RANGE, "budget.tol.rare")


func test_validate_config_list_entry_out_of_range_names_the_index() -> void:
	# Act — PRESSURE_BAND safe range 5-14
	var body: Dictionary = _valid_body()
	body.pressure.band = [7.0, 15.0, 11.5]
	var rows: Array = ContentValidator.validate_config(body, null)

	# Assert
	_assert_one(rows, ContentValidator.E_RANGE, "pressure.band[1]")


func test_validate_config_list_of_wrong_length_is_one_e_schema() -> void:
	# Act — CN-6 step 2: bucket is [k1, k2, k3, k4, k5, k6_plus]
	var body: Dictionary = _valid_body()
	body.curve.bucket = [0.2, 0.2, 0.2, 0.2, 0.2]
	var rows: Array = ContentValidator.validate_config(body, null)

	# Assert
	_assert_one(rows, ContentValidator.E_SCHEMA, "curve.bucket")


func test_validate_config_unknown_top_level_key_is_one_e_unknown_field() -> void:
	# Act
	var rows: Array = ContentValidator.validate_config(_with(_valid_body(), "max_cards", 120.0), null)

	# Assert
	_assert_one(rows, ContentValidator.E_UNKNOWN_FIELD, "max_cards")


func test_validate_config_unknown_nested_key_is_one_e_unknown_field() -> void:
	# Act
	var rows: Array = ContentValidator.validate_config(_with(_valid_body(), "time.t_treasure", 0.2), null)

	# Assert
	_assert_one(rows, ContentValidator.E_UNKNOWN_FIELD, "time.t_treasure")


func test_validate_config_keyword_tax_for_a_non_dd_m09_keyword_is_one_e_unknown_field() -> void:
	# Act
	var rows: Array = ContentValidator.validate_config(_with(_valid_body(), "budget.keyword_tax.reborn", 2.0), null)

	# Assert
	_assert_one(rows, ContentValidator.E_UNKNOWN_FIELD, "budget.keyword_tax.reborn")


func test_validate_config_ops_exempt_naming_no_c5_op_is_one_e_schema() -> void:
	# Act
	var body: Dictionary = _valid_body()
	body.coverage.ops_exempt = ["discard", "teleport"]
	var rows: Array = ContentValidator.validate_config(body, null)

	# Assert
	_assert_one(rows, ContentValidator.E_SCHEMA, "coverage.ops_exempt[1]")


func test_validate_config_inverted_curve_band_is_one_e_range() -> void:
	# Act — avg_min must not exceed avg_max (both inside 2.6-3.8)
	var rows: Array = ContentValidator.validate_config(_with(_valid_body(), "curve.avg_min", 3.6), null)

	# Assert
	_assert_one(rows, ContentValidator.E_RANGE, "curve.avg_min")


func test_validate_config_reports_every_fault_not_only_the_first() -> void:
	# Arrange
	var body: Dictionary = _valid_body()
	_with(body, "share_tol", null, true)
	_with(body, "text_max_chars", 200.0)
	_with(body, "extra", true)

	# Act
	var rows: Array = ContentValidator.validate_config(body, null)

	# Assert
	var fields: Array = rows.map(func(r: Dictionary) -> String: return r.field)
	assert_array(fields).contains_exactly_in_any_order(["share_tol", "text_max_chars", "extra"])
