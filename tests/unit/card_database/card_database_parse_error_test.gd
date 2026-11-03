## Unit tests for CR-5 stage 2, parse (story card-database/story-001;
## ADR-0002 Decision 2 and Verification item 1).
##
## This suite is the proof of an engine claim the reference cannot source:
## that `JSON.new().parse()` on 4.7.2 reports a usable error line and message
## for a malformed file. Observed: `get_error_line()` is 0-based, so the loader
## reports it + 1 and the line asserted here is the 1-based line of the fault.
##
## Fixture `res://tests/fixtures/data/parse_error/` is `minimal/` plus three
## faults, read-only: `cards_war.json` (missing comma on line 4),
## `match_rules.json` (a missing value on line 1) and `run_ui.json`
## (`schema_version` 0, a stage-3 fault in a later file).
extends GdUnitTestSuite


const ROOT: String = "res://tests/fixtures/data/parse_error/"
## 1-based line of the missing comma in parse_error/cards_war.json.
const CARDS_WAR_FAULT_LINE: int = 4
## parse_error/match_rules.json is a one-line file.
const MATCH_RULES_FAULT_LINE: int = 1


func _report() -> ValidationReport:
	return DataLoader.new(ROOT).run({}).report


func _entries_for(report: ValidationReport, code: StringName, file_name: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in report.entries():
		if e.code == code and e.file == file_name:
			out.append(e)
	return out


## The 1-based line the loader wrote into an E_PARSE message, or -1.
func _line_of(message: String) -> int:
	var found: RegExMatch = RegEx.create_from_string("^line (\\d+)").search(message)
	return int(found.get_string(1)) if found != null else -1


func test_malformed_file_reports_e_parse_naming_the_file_and_its_fault_line() -> void:
	# Act
	var hits: Array[Dictionary] = _entries_for(_report(), ValidationReport.E_PARSE, "cards_war.json")

	# Assert
	assert_int(hits.size()).is_equal(1)
	assert_str(hits[0].severity).is_equal(String(ValidationReport.SEVERITY_ERROR))
	assert_int(_line_of(hits[0].message)).is_equal(CARDS_WAR_FAULT_LINE)


func test_malformed_file_message_carries_the_parser_message() -> void:
	# Act
	var hits: Array[Dictionary] = _entries_for(_report(), ValidationReport.E_PARSE, "cards_war.json")

	# Assert — "line N: <parser text>"; the parser gives a message on 4.7.2
	var prefix: String = "line %d: " % CARDS_WAR_FAULT_LINE
	assert_str(hits[0].message).starts_with(prefix)
	assert_int(hits[0].message.length()).is_greater(prefix.length())


func test_single_line_malformed_file_reports_a_non_zero_line() -> void:
	# Act
	var hits: Array[Dictionary] = _entries_for(_report(), ValidationReport.E_PARSE, "match_rules.json")

	# Assert — the engine says 0 here; the report must not
	assert_int(hits.size()).is_equal(1)
	assert_int(_line_of(hits[0].message)).is_equal(MATCH_RULES_FAULT_LINE)


func test_parse_error_does_not_stop_the_pipeline() -> void:
	# Act
	var report: ValidationReport = _report()

	# Assert — both malformed files reported, and stage 3 still ran on run_ui.json
	assert_int(report.errors().size()).is_equal(3)
	assert_int(_entries_for(report, ValidationReport.E_PARSE, "cards_war.json").size()).is_equal(1)
	assert_int(_entries_for(report, ValidationReport.E_PARSE, "match_rules.json").size()).is_equal(1)
	assert_int(_entries_for(report, ValidationReport.E_SCHEMA_VERSION, "run_ui.json").size()).is_equal(1)


func test_parse_error_entries_have_the_cr5_shape_and_file_order() -> void:
	# Act
	var entries: Array[Dictionary] = _report().entries()

	# Assert
	for e: Dictionary in entries:
		assert_array(e.keys()).contains_exactly_in_any_order(["severity", "code", "file", "record_id", "field", "message"])
	var files: Array = entries.map(func(e: Dictionary) -> String: return e.file)
	assert_array(files).is_equal(["cards_war.json", "match_rules.json", "run_ui.json"])


func test_parse_error_leaves_the_database_failed() -> void:
	# Arrange
	var db: CardDatabase = CardDatabase.new(DataLoader.new(ROOT))

	# Act
	db.load({})

	# Assert
	assert_int(db.state()).is_equal(CardDatabase.State.FAILED)
	assert_that(DataLoader.new(ROOT).run({}).snapshot).is_null()
