## Negative tests for CR-5 stages 1-3 on malformed envelope values (story
## card-database/story-001; card-database CR-1, CR-5 steps 1-3; ADR-0002
## Decision 1-3).
##
## Fixture `res://tests/fixtures/data/bad_values/` is `minimal/` plus one fault
## per file, read-only: `heroes.json` (`schema_version` 1.5), `match_ui.json`
## (`schema_version` the string `"1"`), `run_ui.json` (`"config": []`),
## `bundles.json` (no `records` key), `reward_draft.json` (an empty file) and
## `cards_decay.json` (an optional set file that is present but malformed).
extends GdUnitTestSuite

const ROOT: String = "res://tests/fixtures/data/bad_values/"
const FAULTY_FILES: Array[String] = [
	"bundles.json", "cards_decay.json", "heroes.json", "match_ui.json", "reward_draft.json", "run_ui.json",
]


func _report() -> ValidationReport:
	return DataLoader.new(ROOT).run(ValidatorStubs.accept_all()).report


func _entries_for(report: ValidationReport, file_name: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in report.entries():
		if e.file == file_name:
			out.append(e)
	return out


func _only_entry(file_name: String) -> Dictionary:
	var hits: Array[Dictionary] = _entries_for(_report(), file_name)
	assert_int(hits.size()).override_failure_message("%s: expected one entry, got %s" % [file_name, str(hits)]).is_equal(1)
	return hits[0] if hits.size() == 1 else {}


func test_fractional_schema_version_reports_e_schema_version_not_an_integer() -> void:
	# Act
	var entry: Dictionary = _only_entry("heroes.json")

	# Assert — 1.5 is not truncated to 1
	assert_bool(entry.code == ValidationReport.E_SCHEMA_VERSION).is_true()
	assert_str(entry.field).is_equal("schema_version")
	assert_str(entry.message).contains("1.5 (not an integer)")


func test_string_schema_version_reports_e_schema_version_not_an_integer() -> void:
	# Act
	var entry: Dictionary = _only_entry("match_ui.json")

	# Assert — "1" is a string, not the number 1
	assert_bool(entry.code == ValidationReport.E_SCHEMA_VERSION).is_true()
	assert_str(entry.field).is_equal("schema_version")
	assert_str(entry.message).contains("(not an integer)")


func test_config_array_reports_e_parse_naming_the_config_field() -> void:
	# Act
	var entry: Dictionary = _only_entry("run_ui.json")

	# Assert
	assert_bool(entry.code == ValidationReport.E_PARSE).is_true()
	assert_str(entry.field).is_equal("config")
	assert_str(entry.message).contains("must be an object, found Array")


func test_missing_records_key_reports_e_parse_naming_the_records_field() -> void:
	# Act
	var entry: Dictionary = _only_entry("bundles.json")

	# Assert
	assert_bool(entry.code == ValidationReport.E_PARSE).is_true()
	assert_str(entry.field).is_equal("records")
	assert_str(entry.message).contains("must be an array, found missing")


func test_empty_file_reports_e_parse_on_line_one() -> void:
	# Act
	var entry: Dictionary = _only_entry("reward_draft.json")

	# Assert
	assert_bool(entry.code == ValidationReport.E_PARSE).is_true()
	assert_object(entry.field).is_null()
	assert_str(entry.message).starts_with("line 1")


func test_malformed_optional_set_file_reports_e_parse_rather_than_being_skipped() -> void:
	# Act — optional means "absent is fine", not "broken is fine"
	var entry: Dictionary = _only_entry("cards_decay.json")

	# Assert
	assert_bool(entry.code == ValidationReport.E_PARSE).is_true()
	assert_str(entry.message).starts_with("line ")


func test_bad_values_root_reports_one_error_per_faulty_file_and_fails() -> void:
	# Act
	var result: DataLoader.LoadResult = DataLoader.new(ROOT).run(ValidatorStubs.accept_all())

	# Assert — each fault reported once, nothing else, no snapshot
	var files: Array = result.report.errors().map(func(e: Dictionary) -> String: return e.file)
	assert_array(files).is_equal(Array(FAULTY_FILES))
	assert_array(result.report.warnings()).is_empty()
	assert_that(result.snapshot).is_null()
