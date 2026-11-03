## Unit tests for the Card Database load pipeline, stages 1 and 3, and the
## report / state seam (story card-database/story-001; card-database CR-1,
## CR-5 steps 1-3, Edge Cases "Versions and files", States table; ADR-0002).
##
## File I/O note: these tests read committed, read-only fixture roots under
## `res://tests/fixtures/data/<case>/` through an injected `DataLoader` root —
## by design (QA plan CDB-001: the loader's own `FileAccess` path is the thing
## under test). No test writes a file. Each broken case is `minimal/` (every
## required manifest file, empty bodies) with one fault.
extends GdUnitTestSuite


const FIXTURES: String = "res://tests/fixtures/data/"

## DD-T01 / CR-1 file list in CR-1 table order (rng_event_log appended per
## ADR-0002 Decision 1). The test's own copy, so a manifest edit is a red test.
const EXPECTED_NAMES: Array[String] = [
	"cards_war.json", "cards_neutral.json", "cards_boss.json", "cards_decay.json",
	"cards_knowledge.json", "cards_fortune.json", "cards_order.json", "cards_shadow.json",
	"heroes.json", "hero_powers.json", "bosses.json", "treasures.json", "bundles.json",
	"match_rules.json", "card_effects.json", "ai_profiles.json", "run_structure.json",
	"reward_draft.json", "treasures_balance.json", "heroes_balance.json", "match_ui.json",
	"run_ui.json", "profile_defaults.json", "card_database.json", "content_budgets.json",
	"rng_event_log.json",
]
const OPTIONAL_SETS: Array[String] = [
	"cards_decay.json", "cards_knowledge.json", "cards_fortune.json", "cards_order.json", "cards_shadow.json",
]
const DEFINITION_TYPES: Dictionary = {
	"cards_war.json": "CardDef", "cards_neutral.json": "CardDef", "cards_boss.json": "CardDef",
	"cards_decay.json": "CardDef", "cards_knowledge.json": "CardDef", "cards_fortune.json": "CardDef",
	"cards_order.json": "CardDef", "cards_shadow.json": "CardDef",
	"heroes.json": "HeroDef", "hero_powers.json": "HeroPowerDef", "bosses.json": "BossDef",
	"treasures.json": "TreasureDef", "bundles.json": "BundleDef",
}
const ROW_KEYS: Array[String] = ["name", "class", "record_type", "required", "owner"]
const ENTRY_KEYS: Array[String] = ["severity", "code", "file", "record_id", "field", "message"]


func _load_case(case_name: String) -> CardDatabase:
	var db: CardDatabase = CardDatabase.new(DataLoader.new(FIXTURES + case_name))
	db.load(ValidatorStubs.accept_all())
	return db


func _run_case(case_name: String) -> DataLoader.LoadResult:
	return DataLoader.new(FIXTURES + case_name).run(ValidatorStubs.accept_all())


func _with_code(report: ValidationReport, code: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in report.entries():
		if e.code == code:
			out.append(e)
	return out


func _manifest_names() -> Array:
	return DataLoader.FILE_MANIFEST.map(func(row: Dictionary) -> String: return row.name)


# --- AC-1: FILE_MANIFEST -------------------------------------------------------

func test_file_manifest_every_row_has_exactly_the_five_keys() -> void:
	for row: Dictionary in DataLoader.FILE_MANIFEST:
		assert_int(row.size()).is_equal(ROW_KEYS.size())
		GameAssertions.assert_has_keys(row, ROW_KEYS, str(row.get("name")))


func test_file_manifest_names_match_dd_t01_in_cr1_order() -> void:
	assert_array(_manifest_names()).is_equal(EXPECTED_NAMES)
	GameAssertions.assert_no_duplicates(_manifest_names(), "FILE_MANIFEST names")


func test_file_manifest_only_optional_rows_are_the_five_later_sets() -> void:
	for row: Dictionary in DataLoader.FILE_MANIFEST:
		assert_bool(row.required).override_failure_message(row.name).is_equal(not OPTIONAL_SETS.has(row.name))


func test_file_manifest_definition_rows_carry_cr3_record_types_and_config_rows_null() -> void:
	var definitions: int = 0
	var configs: int = 0
	for row: Dictionary in DataLoader.FILE_MANIFEST:
		if DEFINITION_TYPES.has(row.name):
			definitions += 1
			assert_str(row["class"]).is_equal("definition")
			assert_str(row.record_type).is_equal(DEFINITION_TYPES[row.name])
		else:
			configs += 1
			assert_str(row["class"]).is_equal("config")
			assert_that(row.record_type).is_null()
		assert_str(row.owner).is_not_empty()
	assert_int(definitions).is_equal(DEFINITION_TYPES.size())
	assert_int(configs).is_equal(EXPECTED_NAMES.size() - DEFINITION_TYPES.size())


func test_file_manifest_rng_event_log_row_is_owned_by_rng_event_log() -> void:
	var rows: Array = DataLoader.FILE_MANIFEST.filter(func(r: Dictionary) -> bool: return r.name == "rng_event_log.json")
	assert_int(rows.size()).is_equal(1)
	assert_str(rows[0].owner).is_equal("RNG & Event Log")


# --- Clean root ------------------------------------------------------------------

func test_minimal_root_loads_ready_with_an_empty_report() -> void:
	# Arrange / Act
	var db: CardDatabase = _load_case("minimal")

	# Assert
	assert_int(db.state()).is_equal(CardDatabase.State.READY)
	assert_int(db.report().entries().size()).is_equal(0)


func test_minimal_root_snapshot_holds_every_required_file_by_class() -> void:
	# Act
	var result: DataLoader.LoadResult = _run_case("minimal")

	# Assert
	var snapshot: Dictionary = result.snapshot
	for row: Dictionary in DataLoader.FILE_MANIFEST:
		if not row.required:
			continue
		if row["class"] == "definition":
			assert_bool(snapshot.definitions.has(row.name)).override_failure_message(row.name).is_true()
		else:
			assert_bool(snapshot.configs.has(String(row.name).get_basename())).override_failure_message(row.name).is_true()


func test_optional_set_file_absent_is_skipped_silently() -> void:
	# Act — minimal/ has none of the five optional set files
	var result: DataLoader.LoadResult = _run_case("minimal")

	# Assert
	for file_name: String in OPTIONAL_SETS:
		assert_bool(result.snapshot.definitions.has(file_name)).is_false()
	assert_bool(result.report.has_errors()).is_false()


# --- AC-1: missing and unknown files ---------------------------------------------

func test_missing_card_database_json_reports_e_missing_file_naming_it() -> void:
	# Act
	var db: CardDatabase = _load_case("missing_config")

	# Assert
	var missing: Array[Dictionary] = _with_code(db.report(), ValidationReport.E_MISSING_FILE)
	assert_int(missing.size()).is_equal(1)
	assert_str(missing[0].file).is_equal("card_database.json")
	assert_str(missing[0].severity).is_equal(String(ValidationReport.SEVERITY_ERROR))
	assert_str(missing[0].message).contains("card_database.json")
	assert_str(missing[0].message).contains(str(ERR_FILE_NOT_FOUND))


func test_missing_card_database_json_fails_with_no_defaults_path() -> void:
	# Act
	var db: CardDatabase = _load_case("missing_config")
	var result: DataLoader.LoadResult = _run_case("missing_config")

	# Assert — Failed, and no snapshot: there is no built-in defaults fallback
	assert_int(db.state()).is_equal(CardDatabase.State.FAILED)
	assert_that(result.snapshot).is_null()


func test_required_set_file_absent_reports_e_missing_file_and_fails() -> void:
	# Act
	var db: CardDatabase = _load_case("missing_set")

	# Assert
	var missing: Array[Dictionary] = _with_code(db.report(), ValidationReport.E_MISSING_FILE)
	assert_int(missing.size()).is_equal(1)
	assert_str(missing[0].file).is_equal("cards_boss.json")
	assert_int(db.state()).is_equal(CardDatabase.State.FAILED)


func test_unknown_json_reports_w_unknown_file_naming_each_and_stays_ready() -> void:
	# Act
	var db: CardDatabase = _load_case("unknown_file")

	# Assert — stray.json and cards_foo.json (no such set in the manifest)
	var unknown: Array[Dictionary] = _with_code(db.report(), ValidationReport.W_UNKNOWN_FILE)
	var names: Array = unknown.map(func(e: Dictionary) -> String: return e.file)
	assert_array(names).contains_exactly_in_any_order(["stray.json", "cards_foo.json"])
	for e: Dictionary in unknown:
		assert_str(e.severity).is_equal(String(ValidationReport.SEVERITY_WARNING))
	assert_bool(db.report().has_errors()).is_false()
	assert_int(db.state()).is_equal(CardDatabase.State.READY)


func test_unknown_json_is_not_loaded_but_present_optional_set_is() -> void:
	# Act
	var result: DataLoader.LoadResult = _run_case("unknown_file")

	# Assert
	var definitions: Dictionary = result.snapshot.definitions
	assert_bool(definitions.has("stray.json")).is_false()
	assert_bool(definitions.has("cards_foo.json")).is_false()
	assert_bool(result.snapshot.configs.has("stray")).is_false()
	assert_bool(definitions.has("cards_decay.json")).is_true()


# --- AC-3: envelope ----------------------------------------------------------------

func test_schema_version_0_reports_e_schema_version_with_found_and_expected() -> void:
	# Act
	var db: CardDatabase = _load_case("schema_version_0")

	# Assert
	var bad: Array[Dictionary] = _with_code(db.report(), ValidationReport.E_SCHEMA_VERSION)
	assert_int(bad.size()).is_equal(1)
	assert_str(bad[0].file).is_equal("heroes.json")
	assert_str(bad[0].field).is_equal("schema_version")
	assert_str(bad[0].message).contains("found 0")
	assert_str(bad[0].message).contains("expected %d" % TestConstants.SCHEMA_VERSION_CURRENT)
	assert_int(db.state()).is_equal(CardDatabase.State.FAILED)


func test_schema_version_2_reports_e_schema_version_with_found_and_expected() -> void:
	# Act
	var db: CardDatabase = _load_case("schema_version_2")

	# Assert — newer fails exactly like older (no in-engine migration)
	var bad: Array[Dictionary] = _with_code(db.report(), ValidationReport.E_SCHEMA_VERSION)
	assert_int(bad.size()).is_equal(1)
	assert_str(bad[0].file).is_equal("match_ui.json")
	assert_str(bad[0].message).contains("found 2")
	assert_str(bad[0].message).contains("expected %d" % TestConstants.SCHEMA_VERSION_CURRENT)
	assert_int(db.state()).is_equal(CardDatabase.State.FAILED)


func test_definition_records_not_an_array_reports_e_parse_naming_the_file() -> void:
	# Act
	var report: ValidationReport = _load_case("bad_envelope").report()

	# Assert
	var hits: Array = _with_code(report, ValidationReport.E_PARSE).filter(
		func(e: Dictionary) -> bool: return e.file == "bosses.json")
	assert_int(hits.size()).is_equal(1)
	assert_str(hits[0].field).is_equal("records")


func test_config_file_carrying_records_instead_of_config_reports_e_parse() -> void:
	# Act
	var report: ValidationReport = _load_case("bad_envelope").report()

	# Assert
	var hits: Array = _with_code(report, ValidationReport.E_PARSE).filter(
		func(e: Dictionary) -> bool: return e.file == "run_structure.json")
	assert_int(hits.size()).is_equal(1)
	assert_str(hits[0].field).is_equal("config")
	assert_str(hits[0].message).contains("records")


func test_schema_version_missing_reports_e_schema_version() -> void:
	# Act
	var report: ValidationReport = _load_case("bad_envelope").report()

	# Assert
	var hits: Array = _with_code(report, ValidationReport.E_SCHEMA_VERSION).filter(
		func(e: Dictionary) -> bool: return e.file == "treasures.json")
	assert_int(hits.size()).is_equal(1)
	assert_str(hits[0].message).contains("missing")


func test_top_level_array_reports_e_parse() -> void:
	# Act
	var report: ValidationReport = _load_case("bad_envelope").report()

	# Assert
	var hits: Array = _with_code(report, ValidationReport.E_PARSE).filter(
		func(e: Dictionary) -> bool: return e.file == "cards_neutral.json")
	assert_int(hits.size()).is_equal(1)


func test_bad_envelope_root_fails_with_no_snapshot() -> void:
	# Act
	var db: CardDatabase = _load_case("bad_envelope")
	var result: DataLoader.LoadResult = _run_case("bad_envelope")

	# Assert — four faulty files, four errors, nothing else
	assert_int(db.report().errors().size()).is_equal(4)
	assert_int(db.state()).is_equal(CardDatabase.State.FAILED)
	assert_that(result.snapshot).is_null()


# --- Report shape and ordering (AC-2, no file I/O) ----------------------------------

func test_report_entries_have_the_six_cr5_keys() -> void:
	# Arrange
	var report: ValidationReport = _load_case("bad_envelope").report()

	# Assert
	for e: Dictionary in report.entries():
		assert_int(e.size()).is_equal(ENTRY_KEYS.size())
		GameAssertions.assert_has_keys(e, ENTRY_KEYS, "report entry")


func test_report_entries_sort_by_file_then_record_id_null_first() -> void:
	# Arrange — added out of order
	var report: ValidationReport = ValidationReport.new()
	var err: StringName = ValidationReport.SEVERITY_ERROR
	report.add(err, &"E_TEST", "b.json", "id_b", null, "4")
	report.add(err, &"E_TEST", "a.json", "id_z", null, "2")
	report.add(err, &"E_TEST", "b.json", null, null, "3")
	report.add(err, &"E_TEST", "a.json", "id_a", "field", "1")
	report.add(ValidationReport.SEVERITY_WARNING, &"W_TEST", "a.json", null, null, "0")

	# Act
	var messages: Array = report.entries().map(func(e: Dictionary) -> String: return e.message)

	# Assert
	assert_array(messages).is_equal(["0", "1", "2", "3", "4"])


func test_report_errors_warnings_and_has_errors_split_by_severity() -> void:
	# Arrange
	var report: ValidationReport = ValidationReport.new()
	report.add(ValidationReport.SEVERITY_WARNING, ValidationReport.W_UNKNOWN_FILE, "x.json", null, null, "w")

	# Assert — a warning alone is not a failure
	assert_bool(report.has_errors()).is_false()
	assert_int(report.warnings().size()).is_equal(1)
	assert_int(report.errors().size()).is_equal(0)

	# Act
	report.add(ValidationReport.SEVERITY_ERROR, ValidationReport.E_PARSE, "y.json", null, null, "e")

	# Assert
	assert_bool(report.has_errors()).is_true()
	assert_int(report.errors().size()).is_equal(1)
	assert_str(report.errors()[0].file).is_equal("y.json")


func test_report_entries_are_copies() -> void:
	# Arrange
	var report: ValidationReport = ValidationReport.new()
	report.add(ValidationReport.SEVERITY_ERROR, ValidationReport.E_PARSE, "y.json", null, null, "e")

	# Act
	report.entries()[0].message = "changed"

	# Assert
	assert_str(report.entries()[0].message).is_equal("e")


func test_report_to_text_lists_counts_and_each_entry() -> void:
	# Arrange
	var report: ValidationReport = ValidationReport.new()
	report.add(ValidationReport.SEVERITY_ERROR, ValidationReport.E_SCHEMA_VERSION, "heroes.json", null, "schema_version", "found 0, expected 1")
	report.add(ValidationReport.SEVERITY_WARNING, ValidationReport.W_UNKNOWN_FILE, "stray.json", null, null, "not loaded")

	# Act
	var text: String = report.to_text()

	# Assert
	var lines: PackedStringArray = text.split("\n")
	assert_int(lines.size()).is_equal(3)
	assert_str(lines[0]).contains("1 error(s), 1 warning(s)")
	assert_str(lines[1]).is_equal("error E_SCHEMA_VERSION heroes.json (schema_version): found 0, expected 1")
	assert_str(lines[2]).is_equal("warning W_UNKNOWN_FILE stray.json: not loaded")


# --- CardDatabase state seam ----------------------------------------------------------

func test_card_database_is_unloaded_with_an_empty_report_before_load() -> void:
	# Arrange / Act — default loader is built, nothing is read
	var db: CardDatabase = CardDatabase.new()

	# Assert
	assert_bool(db is RefCounted).is_true()
	assert_int(db.state()).is_equal(CardDatabase.State.UNLOADED)
	assert_int(db.report().entries().size()).is_equal(0)


func test_card_database_load_returns_the_report_it_keeps() -> void:
	# Arrange
	var db: CardDatabase = CardDatabase.new(DataLoader.new(FIXTURES + "schema_version_2"))

	# Act
	var returned: ValidationReport = db.load(ValidatorStubs.accept_all())

	# Assert
	assert_object(returned).is_same(db.report())
	assert_bool(returned.has_errors()).is_true()


func test_data_loader_default_root_is_assets_data_and_root_gets_a_trailing_slash() -> void:
	assert_str(DataLoader.new().root()).is_equal("res://assets/data/")
	assert_str(DataLoader.new(FIXTURES + "minimal").root()).is_equal(FIXTURES + "minimal/")
