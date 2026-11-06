## `reload()` refuses with `E_BUSY` while the injected predicate answers `true`
## (boss-ai-match-driver story 019 AC 1-2; ADR-0006; ADR-0002 Decision 8). The predicate
## is a plain lambda: this suite names no AI class, as `CardDatabase` itself must not.
##
## The loader reads the committed `clean/` root, so nothing here writes a file. The build
## flag is injected, so the release branch runs in the editor build gdUnit4 uses.
extends GdUnitTestSuite

const CLEAN: String = "res://tests/fixtures/data/clean/"
const SOURCE_PATH: String = "res://src/core/data/card_database.gd"
const FORBIDDEN_NAMES: Array[String] = ["PlannerTask", "MatchDriver", "BossAI", "src/ai/"]
const ONE_ENTRY: int = 1


## A loader that counts its runs.
class CountingLoader:
	extends DataLoader

	var runs: int = 0

	func run(validators: Dictionary, db: CardDatabase = null) -> LoadResult:
		runs += 1
		return super.run(validators, db)


var _loader: CountingLoader = null


func _ready_db(debug_build: bool = true) -> CardDatabase:
	_loader = CountingLoader.new(CLEAN)
	var db: CardDatabase = CardDatabase.new(_loader, debug_build)
	db.load(ValidatorStubs.accept_all())
	return db


func _busy() -> bool:
	return true


func _idle() -> bool:
	return false


func _assert_only_entry(report: ValidationReport, code: StringName) -> void:
	assert_int(report.entries().size()).is_equal(ONE_ENTRY)
	assert_str(str(report.entries()[0].code)).is_equal(String(code))
	assert_str(str(report.entries()[0].severity)).is_equal(str(ValidationReport.SEVERITY_ERROR))


func test_reload_while_busy_is_e_busy_with_nothing_touched() -> void:
	# Arrange
	var db: CardDatabase = _ready_db()
	db.set_reload_busy(_busy)
	var runs: int = _loader.runs
	var snapshot: Dictionary = db.snapshot_handle()
	var report: ValidationReport = db.report()
	var version: String = db.data_version()

	# Act
	var refused: ValidationReport = db.reload()

	# Assert
	_assert_only_entry(refused, ValidationReport.E_BUSY)
	assert_int(_loader.runs).is_equal(runs)
	assert_int(db.state()).is_equal(CardDatabase.State.READY)
	assert_bool(is_same(db.snapshot_handle(), snapshot)).is_true()
	assert_bool(is_same(db.report(), report)).is_true()
	assert_str(db.data_version()).is_equal(version)
	assert_that(db.last_reload_report()).is_null()


func test_reload_with_an_idle_predicate_swaps_as_before() -> void:
	# Arrange
	var db: CardDatabase = _ready_db()
	db.set_reload_busy(_idle)
	var runs: int = _loader.runs
	var report: ValidationReport = db.report()

	# Act
	var result: ValidationReport = db.reload()

	# Assert
	assert_int(_loader.runs).is_equal(runs + 1)
	assert_bool(result.has_errors()).is_false()
	assert_bool(is_same(db.report(), result)).is_true()
	assert_bool(is_same(db.report(), report)).is_false()
	assert_int(db.state()).is_equal(CardDatabase.State.READY)


func test_reload_with_no_predicate_swaps_as_before() -> void:
	# Arrange
	var db: CardDatabase = _ready_db()

	# Act
	var result: ValidationReport = db.reload()

	# Assert
	assert_bool(result.has_errors()).is_false()
	assert_bool(is_same(db.last_reload_report(), result)).is_true()


func test_an_empty_callable_clears_the_predicate() -> void:
	# Arrange
	var db: CardDatabase = _ready_db()
	db.set_reload_busy(_busy)
	db.set_reload_busy(Callable())

	# Act
	var result: ValidationReport = db.reload()

	# Assert
	assert_bool(result.has_errors()).is_false()


func test_reload_before_load_is_e_not_loaded_even_when_busy() -> void:
	# Arrange — story 019's order: release, not loaded, then busy
	var db: CardDatabase = CardDatabase.new(CountingLoader.new(CLEAN), true)
	db.set_reload_busy(_busy)

	# Act
	var refused: ValidationReport = db.reload()

	# Assert
	_assert_only_entry(refused, ValidationReport.E_NOT_LOADED)


func test_a_release_build_is_e_not_supported_even_when_busy() -> void:
	# Arrange
	var db: CardDatabase = _ready_db(false)
	db.set_reload_busy(_busy)
	var runs: int = _loader.runs

	# Act
	var refused: ValidationReport = db.reload()

	# Assert
	_assert_only_entry(refused, ValidationReport.E_NOT_SUPPORTED)
	assert_int(_loader.runs).is_equal(runs)


func test_card_database_names_nothing_of_the_ai() -> void:
	# Arrange — story 019 AC 3 grep, comment lines excluded (ADR-0001)
	var code: Array[String] = []
	for line: String in FileAccess.get_file_as_string(SOURCE_PATH).split("\n"):
		if not line.strip_edges().begins_with("#"):
			code.append(line)
	var text: String = "\n".join(code)

	# Act / Assert
	for name: String in FORBIDDEN_NAMES:
		assert_bool(text.contains(name)).override_failure_message(name).is_false()
