## Unit tests for strict JSON at CR-5 stage 2 (story card-database/story-001;
## card-database CR-1, data-files.md; ADR-0002 Decision 2).
##
## The 4.7.2 `JSON` parser accepts a trailing comma and keeps the last of two
## duplicate keys silently (observed 2026-11-03). `DataLoader` reports both
## as `E_PARSE` with the fault's 1-based line, and leaves the file out of the
## later stages.
##
## Fixture `res://tests/fixtures/data/strict_json/` is `minimal/` plus, read-only:
## `cards_war.json` (duplicate `id` inside a record, line 4), `heroes.json`
## (duplicate top-level `schema_version`, line 3), `match_rules.json`
## (trailing comma in an object, line 4), `cards_neutral.json` (trailing
## comma in an array, line 4) and `bosses.json` — clean: the same key in
## sibling and nested objects, and commas, brackets and escaped quotes inside
## strings.
extends GdUnitTestSuite

const ROOT: String = "res://tests/fixtures/data/strict_json/"
## 1-based fault lines, one per faulty fixture file.
const FAULT_LINES: Dictionary = {
	"cards_war.json": 4,
	"heroes.json": 3,
	"match_rules.json": 4,
	"cards_neutral.json": 4,
}


func _report() -> ValidationReport:
	return DataLoader.new(ROOT).run(ValidatorStubs.accept_all()).report


func _entries_for(report: ValidationReport, file_name: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in report.entries():
		if e.file == file_name:
			out.append(e)
	return out


## The 1-based line the loader wrote into an E_PARSE message, or -1.
func _line_of(message: String) -> int:
	var found: RegExMatch = RegEx.create_from_string("^line (\\d+)").search(message)
	return int(found.get_string(1)) if found != null else -1


func test_duplicate_key_in_a_record_reports_e_parse_with_its_line_and_key() -> void:
	# Act
	var hits: Array[Dictionary] = _entries_for(_report(), "cards_war.json")

	# Assert
	assert_int(hits.size()).is_equal(1)
	assert_bool(hits[0].code == ValidationReport.E_PARSE).is_true()
	assert_int(_line_of(hits[0].message)).is_equal(FAULT_LINES["cards_war.json"])
	assert_str(hits[0].message).contains("duplicate key \"id\"")


func test_duplicate_top_level_key_reports_e_parse_not_a_schema_version_pass() -> void:
	# Act — both values are 1, so without the scan the envelope would pass
	var hits: Array[Dictionary] = _entries_for(_report(), "heroes.json")

	# Assert — one E_PARSE, and the file is not staged on to stage 3
	assert_int(hits.size()).is_equal(1)
	assert_bool(hits[0].code == ValidationReport.E_PARSE).is_true()
	assert_int(_line_of(hits[0].message)).is_equal(FAULT_LINES["heroes.json"])
	assert_str(hits[0].message).contains("duplicate key \"schema_version\"")


func test_trailing_comma_in_an_object_reports_e_parse_with_the_comma_line() -> void:
	# Act
	var hits: Array[Dictionary] = _entries_for(_report(), "match_rules.json")

	# Assert
	assert_int(hits.size()).is_equal(1)
	assert_bool(hits[0].code == ValidationReport.E_PARSE).is_true()
	assert_int(_line_of(hits[0].message)).is_equal(FAULT_LINES["match_rules.json"])
	assert_str(hits[0].message).contains("trailing comma before '}'")


func test_trailing_comma_in_an_array_reports_e_parse_with_the_comma_line() -> void:
	# Act
	var hits: Array[Dictionary] = _entries_for(_report(), "cards_neutral.json")

	# Assert
	assert_int(hits.size()).is_equal(1)
	assert_bool(hits[0].code == ValidationReport.E_PARSE).is_true()
	assert_int(_line_of(hits[0].message)).is_equal(FAULT_LINES["cards_neutral.json"])
	assert_str(hits[0].message).contains("trailing comma before ']'")


func test_repeated_keys_across_objects_and_punctuation_in_strings_are_not_faults() -> void:
	# Act
	var report: ValidationReport = _report()

	# Assert — bosses.json and every untouched minimal/ file are free of errors
	# (stage 8 may note that band health went unchecked: match_rules.json is
	# one of the faulty files here)
	assert_array(_entries_for(report, "bosses.json").filter(
		func(e: Dictionary) -> bool: return e.severity == ValidationReport.SEVERITY_ERROR)).is_empty()
	var faulty: Array = report.errors().map(func(e: Dictionary) -> String: return e.file)
	assert_array(_sorted(faulty)).is_equal(_sorted(FAULT_LINES.keys()))


func test_strict_json_fault_fails_the_load_with_no_snapshot() -> void:
	# Arrange
	var db: CardDatabase = CardDatabase.new(DataLoader.new(ROOT))

	# Act
	db.load(ValidatorStubs.accept_all())

	# Assert
	assert_int(db.state()).is_equal(CardDatabase.State.FAILED)
	assert_that(DataLoader.new(ROOT).run(ValidatorStubs.accept_all()).snapshot).is_null()


func _sorted(items: Array) -> Array:
	var out: Array = items.duplicate()
	out.sort()
	return out
