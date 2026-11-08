## Integration: the shipped `assets/data/` against the load-budget contract
## (story card-database/story-009 AC-4 as amended 2026-11-04 per the sprint-4
## QA plan; card-database Formulas "Validation cost and load budget").
##
## Deterministic only — the shipped budget knobs are present and equal their
## `TestConstants` mirror, and the shipped load's debug counters satisfy the
## formula over the shipped loaded set. The timed load and the memory figure
## are AC-1 / AC-2 in the non-blocking
## `tests/performance/card_database/card_database_load_budget_perf_test.gd`.
## The load uses the validator map a fresh `boot.gd` instance builds for a
## debug build (never the autoload), as `tests/integration/boot/main_scene_test.gd` does.
extends GdUnitTestSuite

const SHIPPED_ROOT: String = "res://assets/data/"
const BOOT_SCRIPT: GDScript = preload("res://src/core/boot.gd")


func _shipped_result() -> DataLoader.LoadResult:
	var boot: Node = auto_free(BOOT_SCRIPT.new())
	var loader: DataLoader = DataLoader.new(SHIPPED_ROOT)
	# The database only opens its stage-7 lookups for the real validators;
	# the loader is run directly so the test holds the LoadResult's counters.
	return loader.run(boot._collect_validators(null, true), CardDatabase.new(loader))


func test_shipped_budget_knobs_equal_their_test_constants_mirror() -> void:
	# Act
	var result: DataLoader.LoadResult = _shipped_result()

	# Assert
	assert_bool(result.report.has_errors()).override_failure_message(result.report.to_text()).is_false()
	var knobs: Dictionary = Dictionary(result.snapshot.config_bodies).get("card_database", {})
	assert_bool(RecordSchemas.is_whole_number(knobs.get("data_load_budget_ms"))).is_true()
	assert_bool(RecordSchemas.is_whole_number(knobs.get("data_memory_budget_mb"))).is_true()
	assert_int(int(knobs.data_load_budget_ms)).is_equal(TestConstants.DATA_LOAD_BUDGET_MS)
	assert_int(int(knobs.data_memory_budget_mb)).is_equal(TestConstants.DATA_MEMORY_BUDGET_MB)


func test_shipped_counters_equal_the_formula_over_the_shipped_set() -> void:
	# Act
	var result: DataLoader.LoadResult = _shipped_result()

	# Assert
	assert_bool(result.report.has_errors()).override_failure_message(result.report.to_text()).is_false()
	var records: Dictionary = result.snapshot.records_by_type
	var n_heroes: int = Array(records.HeroDef).size()
	var deck_total: int = 0
	var bosses_with_power: int = 0
	var extra_powers: int = 0
	for hero: Dictionary in records.HeroDef:
		extra_powers += hero.get("extra_powers", []).size()
	for boss: Dictionary in records.BossDef:
		deck_total += Array(boss["deck"]).size()
		if boss["hero_power"] != null:
			bosses_with_power += 1
	var expected_refs: int = n_heroes * TestConstants.STARTER_DECK_SIZE \
		+ Array(records.BundleDef).size() * TestConstants.BUNDLE_CARD_COUNT \
		+ deck_total + n_heroes + extra_powers + bosses_with_power
	for name: String in result.snapshot.config_bodies:
		if name.ends_with("/collection"):
			var metadata: Dictionary = result.snapshot.config_bodies[name].card_metadata
			expected_refs += metadata.size()
			for row: Dictionary in metadata.values():
				expected_refs += row.get("enablers", []).size()
	assert_int(result.n_records).is_equal(Dictionary(result.snapshot.index_of).size())
	assert_int(result.n_refs).is_equal(expected_refs)
	assert_bool(result.n_refs > 0).override_failure_message("shipped load checked no references").is_true()
