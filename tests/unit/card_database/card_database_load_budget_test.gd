## Unit tests for the deterministic half of the load budget (story
## card-database/story-009 AC-3, AC-4 as amended 2026-11-04 per the sprint-4
## QA plan; card-database Formulas "Validation cost and load budget", States
## `Loading`; ADR-0002 Performance Implications).
##
## Blocking suite: no wall-clock and no memory threshold here (coding
## standards, Determinism) — those are AC-1 / AC-2 in
## `tests/performance/card_database/card_database_load_budget_perf_test.gd`,
## outside `commands.test`. This file reads committed fixtures only, never
## `assets/data/` (the shipped knobs are pinned by
## `tests/integration/card_database/card_database_shipped_budget_test.gd`).
## Rules objects are constructed directly (control manifest, Foundation), with
## explicit `ValidatorStubs`: nothing here exercises a validator.
##
## Fixture `clean/`: 31 records (8 war + 4 neutral + 2 boss cards, 1 hero,
## 1 hero power, 2 bosses, 10 treasures, 3 bundles); one boss has
## `hero_power: null`, so the formula's boss term is the bosses holding one.
extends GdUnitTestSuite

const DATA: String = "res://tests/fixtures/data/"
## `clean/` known answer (counted from the fixture files, 2026-11-04): every
## record across the eight definition files.
const CLEAN_N_RECORDS: int = 31
## `clean/` known answer: 1 hero × (15 + 1) + 3 bundles × 3 + boss decks
## (2 + 2) + 1 boss hero power.
const CLEAN_N_REFS: int = 30


func _loader(case_name: String) -> DataLoader:
	return DataLoader.new(DATA + case_name + "/")


## Formulas `n_refs = n_heroes × 15 + n_bundles × 3 + Σ boss_deck_size +
## n_heroes + n_bosses`, computed from a loaded snapshot; `n_bosses` counts
## the bosses whose `hero_power` is not null (the reference that exists).
func _formula_refs(snapshot: Dictionary) -> int:
	var records: Dictionary = snapshot.records_by_type
	var n_heroes: int = Array(records.HeroDef).size()
	var n_bundles: int = Array(records.BundleDef).size()
	var deck_total: int = 0
	var bosses_with_power: int = 0
	for boss: Dictionary in records.BossDef:
		deck_total += Array(boss["deck"]).size()
		if boss["hero_power"] != null:
			bosses_with_power += 1
	return n_heroes * TestConstants.STARTER_DECK_SIZE + n_bundles * TestConstants.BUNDLE_CARD_COUNT \
		+ deck_total + n_heroes + bosses_with_power


# --- AC-3: synchronous return ---------------------------------------------------

func test_load_on_clean_fixture_returns_with_state_ready() -> void:
	# Arrange
	var db: CardDatabase = CardDatabase.new(_loader("clean"))

	# Act — no await: the call itself must leave the terminal state
	var report: ValidationReport = db.load(ValidatorStubs.accept_all())

	# Assert
	assert_int(db.state()).override_failure_message(report.to_text()).is_equal(CardDatabase.State.READY)


func test_load_on_parse_error_fixture_returns_with_state_failed() -> void:
	# Arrange
	var db: CardDatabase = CardDatabase.new(_loader("parse_error"))

	# Act
	db.load(ValidatorStubs.accept_all())

	# Assert
	assert_int(db.state()).is_equal(CardDatabase.State.FAILED)


# --- AC-3: the debug counters -----------------------------------------------------

func test_counters_on_clean_fixture_equal_the_formula_over_the_loaded_set() -> void:
	# Arrange
	var loader: DataLoader = _loader("clean")

	# Act
	var result: DataLoader.LoadResult = loader.run(ValidatorStubs.accept_all())

	# Assert
	assert_bool(result.report.has_errors()).override_failure_message(result.report.to_text()).is_false()
	var snapshot: Dictionary = result.snapshot
	assert_int(result.n_records).is_equal(Dictionary(snapshot.index_of).size())
	assert_int(result.n_refs).is_equal(_formula_refs(snapshot))
	assert_int(result.validation_checks()).is_equal(result.n_records + result.n_refs)


func test_counters_on_clean_fixture_match_the_known_answer() -> void:
	# Act
	var result: DataLoader.LoadResult = _loader("clean").run(ValidatorStubs.accept_all())

	# Assert
	assert_int(result.n_records).is_equal(CLEAN_N_RECORDS)
	assert_int(result.n_refs).is_equal(CLEAN_N_REFS)
	assert_int(result.validation_checks()).is_equal(CLEAN_N_RECORDS + CLEAN_N_REFS)


func test_counters_on_minimal_fixture_are_zero() -> void:
	# Act — `minimal/`: every definition file has `records: []`
	var result: DataLoader.LoadResult = _loader("minimal").run(ValidatorStubs.accept_all())

	# Assert
	assert_int(result.n_records).is_equal(0)
	assert_int(result.n_refs).is_equal(0)


func test_counters_are_per_run_not_cumulative() -> void:
	# Arrange
	var loader: DataLoader = _loader("clean")
	var first: DataLoader.LoadResult = loader.run(ValidatorStubs.accept_all())

	# Act
	var second: DataLoader.LoadResult = loader.run(ValidatorStubs.accept_all())

	# Assert
	assert_int(second.n_records).is_equal(first.n_records)
	assert_int(second.n_refs).is_equal(first.n_refs)


# --- AC-4: the budget knobs are present ----------------------------------------------

func test_budget_knobs_are_whole_numbers_in_config_card_database() -> void:
	# Arrange
	var db: CardDatabase = CardDatabase.new(_loader("clean"))
	db.load(ValidatorStubs.accept_all())

	# Act
	var knobs: Variant = db.config("card_database")

	# Assert — read from config, compared to the mirror; never a literal
	assert_bool(knobs is Dictionary).is_true()
	assert_bool(RecordSchemas.is_whole_number(knobs.get("data_load_budget_ms"))).is_true()
	assert_bool(RecordSchemas.is_whole_number(knobs.get("data_memory_budget_mb"))).is_true()
	assert_int(int(knobs.data_load_budget_ms)).is_equal(TestConstants.DATA_LOAD_BUDGET_MS)
	assert_int(int(knobs.data_memory_budget_mb)).is_equal(TestConstants.DATA_MEMORY_BUDGET_MB)
