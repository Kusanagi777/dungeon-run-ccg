## Unit tests for the Card Database state machine and visible failure
## (story card-database/story-008 AC-1, AC-2; card-database States and
## Transitions, CR-8; ADR-0002 Decision 7).
##
## gdUnit4 runs in a debug (editor) build, so the release branch is tested by
## injecting the build flag: `CardDatabase.new(loader, false)` behaves as a
## release build (log only), `CardDatabase.new(loader, true)` as a debug build
## (log, then assert). The debug assert sits after the push_error in the same
## function, so the runner's "Assertion failed: <message>" proves both ran.
## Fixture `three_errors/` (a copy of `clean/`): `match_ui.json` does not parse,
## `neutral_bog_lurker` (referenced by nothing) has the unknown keyword
## `bogus`, `hero_war.starter_deck[14]` names the missing card `neutral_ghost`.
## Validators are explicit `ValidatorStubs`; fixture roots are read-only.
extends GdUnitTestSuite

const DATA: String = "res://tests/fixtures/data/"
const NOT_LOADED: String = "E_NOT_LOADED: CardDatabase.%s() is illegal in state %s (queries answer in Ready only)"


## A loader that counts its runs (a second `load()` must not run it).
class CountingLoader:
	extends DataLoader

	var runs: int = 0

	func run(validators: Dictionary, db: CardDatabase = null) -> LoadResult:
		runs += 1
		return super.run(validators, db)


func _db(case_name: String, debug_build: bool) -> CardDatabase:
	return CardDatabase.new(DataLoader.new(DATA + case_name + "/"), debug_build)


## Every query of the CR-6 table plus `config`, `data_version` and
## `snapshot_handle`, as `[method name, Callable(db) -> Variant, expected value]`.
func _queries() -> Array:
	return [
		["has", func(db: CardDatabase) -> Variant: return db.has("war_iron_axe"), false],
		["card", func(db: CardDatabase) -> Variant: return db.card("war_iron_axe"), null],
		["hero", func(db: CardDatabase) -> Variant: return db.hero("hero_war"), null],
		["hero_power", func(db: CardDatabase) -> Variant: return db.hero_power("power_sharpen"), null],
		["boss", func(db: CardDatabase) -> Variant: return db.boss("boss_rot_warden"), null],
		["treasure", func(db: CardDatabase) -> Variant: return db.treasure("treasure_t01"), null],
		["bundle", func(db: CardDatabase) -> Variant: return db.bundle("bundle_war_steel"), null],
		["cards_by_set", func(db: CardDatabase) -> Variant: return db.cards_by_set("war"), []],
		["cards_by_type", func(db: CardDatabase) -> Variant: return db.cards_by_type("minion"), []],
		["cards_by_tag", func(db: CardDatabase) -> Variant: return db.cards_by_tag("weapons"), []],
		["cards_by_cost", func(db: CardDatabase) -> Variant: return db.cards_by_cost(2), []],
		["cards_by_rarity", func(db: CardDatabase) -> Variant: return db.cards_by_rarity("common"), []],
		["collectible_pool", func(db: CardDatabase) -> Variant: return db.collectible_pool("war"), []],
		["bundle_pool", func(db: CardDatabase) -> Variant: return db.bundle_pool("war"), []],
		["treasure_pool", func(db: CardDatabase) -> Variant: return db.treasure_pool(), []],
		["bosses_in_band", func(db: CardDatabase) -> Variant: return db.bosses_in_band(1), []],
		["heroes", func(db: CardDatabase) -> Variant: return db.heroes(), []],
		["config", func(db: CardDatabase) -> Variant: return db.config("match_rules"), null],
		["data_version", func(db: CardDatabase) -> Variant: return db.data_version(), ""],
		["snapshot_handle", func(db: CardDatabase) -> Variant: return db.snapshot_handle(), {}],
	]


## Runs every [method _queries] entry on [param db] and asserts, per call,
## the fallback value and the E_NOT_LOADED report: a push_error in a release
## build, the assert that follows it in a debug build.
func _assert_every_query_not_loaded(db: CardDatabase, debug_build: bool, state_name: String) -> void:
	for q: Array in _queries():
		var box: Dictionary = {"value": "untouched"}
		var message: String = NOT_LOADED % [q[0], state_name]
		var call: Callable = func() -> void: box.value = q[1].call(db)
		if debug_build:
			await assert_error(call).is_runtime_error("Assertion failed: " + message)
		else:
			await assert_error(call).is_push_error(message)
		assert_that(box.value).override_failure_message("%s returned %s" % [q[0], str(box.value)]).is_equal(q[2])


# --- AC-1: three errors, one report, nothing queryable ---------------------------------

func test_three_files_with_one_error_each_give_one_report_with_all_three() -> void:
	# Arrange
	var db: CardDatabase = _db("three_errors", false)

	# Act
	var report: ValidationReport = db.load(ValidatorStubs.accept_all())

	# Assert — no fail-fast: each file's error is there, and nothing else is
	var found: Array = report.errors().map(func(e: Dictionary) -> String:
		return "%s %s %s %s" % [e.code, e.file, str(e.record_id), str(e.field)])
	assert_array(found).contains_exactly_in_any_order([
		"E_PARSE match_ui.json <null> <null>",
		"E_BAD_ENUM cards_neutral.json neutral_bog_lurker keywords",
		"E_UNKNOWN_REF heroes.json hero_war starter_deck",
	])
	assert_int(db.state()).is_equal(CardDatabase.State.FAILED)
	assert_bool(is_same(db.report(), report)).is_true()
	assert_bool(db.report().has_errors()).is_true()


func test_three_errors_report_text_lists_each_entry_with_file_record_field_and_code() -> void:
	# Arrange
	var db: CardDatabase = _db("three_errors", false)

	# Act
	var lines: PackedStringArray = db.load(ValidatorStubs.accept_all()).to_text().split("\n")

	# Assert — errors first, in entries() order (file, then record id)
	assert_str(lines[0]).starts_with("[error] E_BAD_ENUM cards_neutral.json#neutral_bog_lurker.keywords — ")
	assert_str(lines[1]).starts_with("[error] E_UNKNOWN_REF heroes.json#hero_war.starter_deck — ")
	assert_str(lines[1]).contains("neutral_ghost")
	assert_str(lines[2]).starts_with("[error] E_PARSE match_ui.json — line ")
	for i: int in range(3, lines.size()):
		assert_str(lines[i]).starts_with("[warning] ")


func test_failed_database_answers_no_query_in_a_release_build() -> void:
	# Arrange
	var db: CardDatabase = _db("three_errors", false)
	db.load(ValidatorStubs.accept_all())

	# Act / Assert — card(id) null, every pool empty, one E_NOT_LOADED each
	await _assert_every_query_not_loaded(db, false, "FAILED")


func test_failed_database_asserts_on_a_query_in_a_debug_build() -> void:
	# Arrange
	var db: CardDatabase = _db("three_errors", true)
	db.load(ValidatorStubs.accept_all())

	# Act / Assert
	await _assert_every_query_not_loaded(db, true, "FAILED")


# --- AC-1 contract: ValidationReport.to_text() ---------------------------------------

func test_to_text_is_one_line_per_entry_errors_first_in_entries_order() -> void:
	# Arrange — added warning first, then errors out of file order
	var report: ValidationReport = ValidationReport.new()
	report.add(ValidationReport.SEVERITY_WARNING, ValidationReport.W_UNKNOWN_FILE, "a_stray.json", null, null, "not loaded")
	report.add(ValidationReport.SEVERITY_ERROR, ValidationReport.E_SCHEMA_VERSION, "heroes.json", null, "schema_version", "found 0, expected 1")
	report.add(ValidationReport.SEVERITY_ERROR, ValidationReport.E_COUNT, "heroes.json", "hero_war", "starter_deck", "found 14, expected 15")
	report.add(ValidationReport.SEVERITY_ERROR, ValidationReport.E_PARSE, "cards_war.json", null, null, "line 4: Expected '}'")

	# Act
	var text: String = report.to_text()

	# Assert
	assert_array(Array(text.split("\n"))).is_equal([
		"[error] E_PARSE cards_war.json — line 4: Expected '}'",
		"[error] E_SCHEMA_VERSION heroes.json.schema_version — found 0, expected 1",
		"[error] E_COUNT heroes.json#hero_war.starter_deck — found 14, expected 15",
		"[warning] W_UNKNOWN_FILE a_stray.json — not loaded",
	])


func test_to_text_of_an_empty_report_is_empty() -> void:
	assert_str(ValidationReport.new().to_text()).is_empty()


# --- AC-2: Unloaded, a second load -----------------------------------------------------

func test_unloaded_database_answers_no_query_in_a_release_build() -> void:
	await _assert_every_query_not_loaded(_db("clean", false), false, "UNLOADED")


func test_unloaded_database_asserts_on_a_query_in_a_debug_build() -> void:
	await _assert_every_query_not_loaded(_db("clean", true), true, "UNLOADED")


func test_unknown_id_in_ready_is_not_an_e_not_loaded_error() -> void:
	# Arrange — a Ready release database
	var db: CardDatabase = _db("clean", false)
	db.load(ValidatorStubs.accept_all())

	# Act / Assert — has() never logs for an unknown id; card() logs its own message
	await assert_error(func() -> void: db.has("no_such_id")).is_success()
	await assert_error(func() -> void: db.card("no_such_id")).is_push_error("CardDatabase.card(): no CardDef \"no_such_id\"")


func test_second_load_on_a_ready_release_database_changes_nothing() -> void:
	# Arrange
	var loader: CountingLoader = CountingLoader.new(DATA + "clean/")
	var db: CardDatabase = CardDatabase.new(loader, false)
	var first: ValidationReport = db.load(ValidatorStubs.accept_all())
	var snapshot: Dictionary = db.snapshot_handle()

	# Act
	var second: ValidationReport = db.load(ValidatorStubs.accept_all())

	# Assert — loads exactly once per process
	assert_int(loader.runs).is_equal(1)
	assert_bool(is_same(second, first)).is_true()
	assert_bool(is_same(db.snapshot_handle(), snapshot)).is_true()
	assert_int(db.state()).is_equal(CardDatabase.State.READY)


func test_second_load_on_a_debug_database_is_also_a_no_op() -> void:
	# Arrange — documented choice: only reload() rebuilds, in either build
	var loader: CountingLoader = CountingLoader.new(DATA + "three_errors/")
	var db: CardDatabase = CardDatabase.new(loader, true)
	var first: ValidationReport = db.load(ValidatorStubs.accept_all())

	# Act
	var second: ValidationReport = db.load(ValidatorStubs.accept_all())

	# Assert
	assert_int(loader.runs).is_equal(1)
	assert_bool(is_same(second, first)).is_true()
	assert_int(db.state()).is_equal(CardDatabase.State.FAILED)


func test_load_passes_through_loading_to_ready() -> void:
	# Arrange
	var calls: Dictionary = {}
	var map: Dictionary = ValidatorStubs.accept_all()
	map.unlock = ValidatorStubs.recording(calls, func(_k: StringName, _i: String, _v: Variant, db: CardDatabase, _c: Dictionary) -> Variant:
		return db.state())
	var db: CardDatabase = _db("clean", false)

	# Act
	db.load(map)

	# Assert
	assert_int(calls.calls[0].probe).is_equal(CardDatabase.State.LOADING)
	assert_int(db.state()).is_equal(CardDatabase.State.READY)


func test_snapshot_handle_in_ready_is_the_frozen_snapshot() -> void:
	# Arrange
	var db: CardDatabase = _db("clean", false)
	db.load(ValidatorStubs.accept_all())

	# Act
	var handle: Dictionary = db.snapshot_handle()

	# Assert
	assert_bool(handle.is_read_only()).is_true()
	assert_bool(is_same(handle.records_by_type.CardDef[handle.index_of["war_iron_axe"].position], db.card("war_iron_axe"))).is_true()
	assert_str(handle.data_version).is_equal(db.data_version())


func test_ready_report_names_the_record_count() -> void:
	# Arrange
	var db: CardDatabase = _db("clean", false)

	# Act
	var report: ValidationReport = db.load(ValidatorStubs.accept_all())

	# Assert — every definition record, all types
	assert_int(report.record_count()).is_equal(db.snapshot_handle().index_of.size())
	assert_int(report.record_count()).is_greater(0)


func test_failed_report_has_no_record_count() -> void:
	assert_int(_db("three_errors", false).load(ValidatorStubs.accept_all()).record_count()).is_equal(-1)
