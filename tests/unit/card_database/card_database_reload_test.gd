## Unit tests for the debug `reload()` (story card-database/story-008 AC-3,
## AC-4; card-database States table "Reloading", Edge Cases "Runtime";
## ADR-0002 Decision 8).
##
## Each test copies the committed `clean/` root to a scratch directory under
## `user://` that it owns, edits the copy, and removes it in `after_test` (the
## story allows this integration-style cleanup in a unit test). The build flag
## is injected (`CardDatabase.new(loader, debug_build)`), so the release branch
## runs in the editor build gdUnit4 uses. Validators are explicit stubs.
extends GdUnitTestSuite

const SOURCE: String = "res://tests/fixtures/data/clean/"
const SCRATCH: String = "user://cdb2_reload_test/"
const CARD_ID: String = "war_shield_bearer"


## A loader that counts its runs (a release reload() must not run it).
class CountingLoader:
	extends DataLoader

	var runs: int = 0

	func run(validators: Dictionary, db: CardDatabase = null) -> LoadResult:
		runs += 1
		return super.run(validators, db)


func before_test() -> void:
	_remove_scratch()
	DirAccess.make_dir_recursive_absolute(SCRATCH)
	for file_name: String in DirAccess.get_files_at(SOURCE):
		if file_name.get_extension() == "json":
			_write(file_name, FileAccess.get_file_as_string(SOURCE + file_name))


func after_test() -> void:
	_remove_scratch()


func _remove_scratch() -> void:
	if not DirAccess.dir_exists_absolute(SCRATCH):
		return
	for file_name: String in DirAccess.get_files_at(SCRATCH):
		DirAccess.remove_absolute(SCRATCH + file_name)
	DirAccess.remove_absolute(SCRATCH)


func _write(file_name: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(SCRATCH + file_name, FileAccess.WRITE)
	GameAssertions.fail_if(file == null, "cannot write %s%s" % [SCRATCH, file_name])
	file.store_string(text)
	file.close()


## Sets [constant CARD_ID]'s `attack` to [param attack] in the scratch copy.
func _set_attack(attack: int) -> void:
	var body: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SCRATCH + "cards_war.json"))
	for rec: Dictionary in body.records:
		if rec.id == CARD_ID:
			rec.attack = attack
	_write("cards_war.json", JSON.stringify(body, "  "))


func _break_parse() -> void:
	_write("cards_war.json", "{\n  \"schema_version\": 1,\n  \"records\": [\n")


func _ready_db(debug_build: bool, validators: Dictionary = ValidatorStubs.accept_all()) -> CardDatabase:
	var db: CardDatabase = CardDatabase.new(DataLoader.new(SCRATCH), debug_build)
	db.load(validators)
	GameAssertions.fail_if(db.state() != CardDatabase.State.READY, "scratch copy did not load:\n%s" % db.report().to_text())
	return db


# --- AC-3: debug reload swaps atomically; a held handle keeps the old data -----------

func test_debug_reload_swaps_in_the_edited_value_and_the_held_handle_keeps_the_old() -> void:
	# Arrange — a "match in progress" holds the snapshot and a record
	var db: CardDatabase = _ready_db(true)
	var handle: Dictionary = db.snapshot_handle()
	var held_card: Dictionary = db.card(CARD_ID)
	var old_attack: int = int(held_card.attack)
	_set_attack(old_attack + 3)

	# Act
	var report: ValidationReport = db.reload()

	# Assert
	assert_int(db.state()).is_equal(CardDatabase.State.READY)
	assert_bool(report.has_errors()).override_failure_message(report.to_text()).is_false()
	assert_int(int(db.card(CARD_ID).attack)).is_equal(old_attack + 3)
	assert_int(int(held_card.attack)).is_equal(old_attack)
	var at: Dictionary = handle.index_of[CARD_ID]
	assert_int(int(handle.records_by_type.CardDef[at.position].attack)).is_equal(old_attack)
	assert_bool(is_same(db.snapshot_handle(), handle)).is_false()
	assert_bool(handle.is_read_only()).is_true()


func test_debug_reload_passes_through_reloading() -> void:
	# Arrange — the stub records the state on every call, load and reload
	var calls: Dictionary = {}
	var map: Dictionary = ValidatorStubs.accept_all()
	map.unlock = ValidatorStubs.recording(calls, func(_k: StringName, _i: String, _v: Variant, db: CardDatabase, _c: Dictionary) -> Variant:
		return db.state())
	var db: CardDatabase = _ready_db(true, map)
	var during_load: int = calls.calls.size()

	# Act
	db.reload()

	# Assert — the reload reused the load's validators, in state Reloading
	assert_int(calls.calls.size()).is_greater(during_load)
	assert_int(calls.calls.back().probe).is_equal(CardDatabase.State.RELOADING)
	assert_int(db.state()).is_equal(CardDatabase.State.READY)


func test_debug_reload_report_names_the_record_count() -> void:
	# Arrange
	var db: CardDatabase = _ready_db(true)

	# Act
	var report: ValidationReport = db.reload()

	# Assert
	assert_int(report.record_count()).is_equal(db.snapshot_handle().index_of.size())
	assert_int(report.record_count()).is_greater(0)
	assert_bool(is_same(db.last_reload_report(), report)).is_true()
	assert_bool(is_same(db.report(), report)).is_true()


func test_debug_reload_changes_data_version_when_a_value_changes() -> void:
	# Arrange
	var db: CardDatabase = _ready_db(true)
	var before: String = db.data_version()
	_set_attack(int(db.card(CARD_ID).attack) + 1)

	# Act
	db.reload()

	# Assert
	assert_str(db.data_version()).is_not_equal(before)


func test_release_reload_returns_e_not_supported_and_changes_nothing() -> void:
	# Arrange
	var loader: CountingLoader = CountingLoader.new(SCRATCH)
	var db: CardDatabase = CardDatabase.new(loader, false)
	db.load(ValidatorStubs.accept_all())
	var handle: Dictionary = db.snapshot_handle()
	var load_report: ValidationReport = db.report()
	_set_attack(int(db.card(CARD_ID).attack) + 1)

	# Act
	var report: ValidationReport = db.reload()

	# Assert — one entry, E_NOT_SUPPORTED; the loader never ran again
	var entries: Array[Dictionary] = report.entries()
	assert_int(entries.size()).is_equal(1)
	assert_str(String(entries[0].code)).is_equal(String(ValidationReport.E_NOT_SUPPORTED))
	assert_str(String(entries[0].severity)).is_equal(String(ValidationReport.SEVERITY_ERROR))
	assert_str(entries[0].file).is_empty()
	assert_int(loader.runs).is_equal(1)
	assert_int(db.state()).is_equal(CardDatabase.State.READY)
	assert_bool(is_same(db.snapshot_handle(), handle)).is_true()
	assert_bool(is_same(db.report(), load_report)).is_true()
	assert_that(db.last_reload_report()).is_null()


func test_reload_before_any_load_is_e_not_loaded_and_changes_nothing() -> void:
	# Arrange
	var loader: CountingLoader = CountingLoader.new(SCRATCH)
	var db: CardDatabase = CardDatabase.new(loader, true)

	# Act
	var report: ValidationReport = db.reload()

	# Assert
	assert_int(report.entries().size()).is_equal(1)
	assert_str(String(report.entries()[0].code)).is_equal(String(ValidationReport.E_NOT_LOADED))
	assert_int(loader.runs).is_equal(0)
	assert_int(db.state()).is_equal(CardDatabase.State.UNLOADED)


# --- AC-4: a failed reload keeps the previous snapshot; Failed → Ready -------------

func test_debug_reload_with_a_parse_error_keeps_the_previous_snapshot() -> void:
	# Arrange
	var db: CardDatabase = _ready_db(true)
	var handle: Dictionary = db.snapshot_handle()
	var version: String = db.data_version()
	var load_report: ValidationReport = db.report()
	var old_attack: int = int(db.card(CARD_ID).attack)
	_break_parse()

	# Act
	var report: ValidationReport = db.reload()

	# Assert — back to Ready on the old snapshot; the new report is exposed
	assert_int(db.state()).is_equal(CardDatabase.State.READY)
	assert_bool(report.errors().any(func(e: Dictionary) -> bool:
		return e.code == ValidationReport.E_PARSE and e.file == "cards_war.json")).is_true()
	assert_str(db.data_version()).is_equal(version)
	assert_bool(is_same(db.snapshot_handle(), handle)).is_true()
	assert_int(int(db.card(CARD_ID).attack)).is_equal(old_attack)
	assert_bool(is_same(db.last_reload_report(), report)).is_true()
	assert_bool(is_same(db.report(), load_report)).is_true()


func test_debug_reload_from_failed_that_succeeds_is_ready() -> void:
	# Arrange
	_break_parse()
	var db: CardDatabase = CardDatabase.new(DataLoader.new(SCRATCH), true)
	db.load(ValidatorStubs.accept_all())
	assert_int(db.state()).is_equal(CardDatabase.State.FAILED)
	_write("cards_war.json", FileAccess.get_file_as_string(SOURCE + "cards_war.json"))

	# Act
	var report: ValidationReport = db.reload()

	# Assert
	assert_bool(report.has_errors()).override_failure_message(report.to_text()).is_false()
	assert_int(db.state()).is_equal(CardDatabase.State.READY)
	assert_bool(db.has(CARD_ID)).is_true()
	assert_int(db.data_version().length()).is_equal(16)
	assert_bool(is_same(db.report(), report)).is_true()


func test_debug_reload_from_failed_that_fails_stays_failed_with_the_new_report() -> void:
	# Arrange
	_break_parse()
	var db: CardDatabase = CardDatabase.new(DataLoader.new(SCRATCH), true)
	db.load(ValidatorStubs.accept_all())

	# Act
	var report: ValidationReport = db.reload()

	# Assert
	assert_int(db.state()).is_equal(CardDatabase.State.FAILED)
	assert_bool(report.has_errors()).is_true()
	assert_bool(is_same(db.report(), report)).is_true()
	assert_bool(is_same(db.last_reload_report(), report)).is_true()
