## PERFORMANCE SUITE — the Card Database load and memory budget. NOT part of
## the blocking run: `commands.test` ignores `res://tests/performance`
## (`-i res://tests/performance`) and the non-blocking `performance` job in
## `.github/workflows/tests.yml` runs this folder (continue-on-error, one
## retry, `PERF` lines in the job summary).
##
## One gate per suite, so a failing gate cannot hide another (review S7): the
## memory gate is `card_database_memory_budget_perf_test.gd` and the logged
## check count `card_database_validation_checks_perf_test.gd`.
##
## Story: production/epics/card-database/story-009-load-and-memory-budget.md
## AC-1, AC-2 (amended 2026-11-04 per the sprint-4 QA plan); the
## deterministic half (synchronous return, counters, knob presence) is in
## `tests/unit/card_database/card_database_load_budget_test.gd` and
## `tests/integration/card_database/card_database_shipped_budget_test.gd`.
## GDD: design/gdd/card-database.md Formulas "Validation cost and load
## budget"; ADR-0002 Performance Implications (expected < 50 ms, budget 500).
## Control manifest Foundation guardrail: data load ≤ `data_load_budget_ms`,
## frozen snapshot ≤ `data_memory_budget_mb`.
##
## The shipped `assets/data/` is loaded through `CardDatabase` with the
## validator map a fresh `boot.gd` instance builds for a debug build (the
## real validators that exist plus the pending ones; never the autoload).
## One warm-up load (file cache, script first-call costs) is thrown away; the
## budget is compared with the **median** of [constant MEASURED_LOADS] loads,
## each on a fresh database, and min / median / max are printed. Both budgets
## are read from `config("card_database")` after the load — never literals.
##
## `Time.get_ticks_usec()` is NOT SOURCEABLE against
## `docs/engine-reference/godot/` (a pre-4.4 API; the story rates it LOW risk) —
## the numbers printed are what this build observed.
extends GdUnitTestSuite

const SHIPPED_ROOT: String = "res://assets/data/"
const BOOT_SCRIPT: GDScript = preload("res://src/core/boot.gd")
## Measured loads after the warm-up (an odd count, so the median is a sample).
const MEASURED_LOADS: int = 5
const USEC_PER_MS: int = 1000

var _measured: bool = false


## A test that ended before its measurement still leaves a line in the summary.
func after() -> void:
	if not _measured:
		print(PerfGate.not_assessed("card_database load", "the test ended before its measurement"))


func _validators() -> Dictionary:
	var boot: Node = auto_free(BOOT_SCRIPT.new())
	return boot._collect_validators(null, true)


## A fresh database over the shipped data, loaded once; fails the test with the
## report when the load is not `Ready` (a budget over a failed load means nothing).
func _loaded_db() -> CardDatabase:
	var db: CardDatabase = CardDatabase.new(DataLoader.new(SHIPPED_ROOT))
	var report: ValidationReport = db.load(_validators())
	assert_int(db.state()).override_failure_message(report.to_text()).is_equal(CardDatabase.State.READY)
	return db


func test_shipped_load_median_is_within_data_load_budget_ms() -> void:
	# Arrange — warm-up load, thrown away
	var warm: CardDatabase = _loaded_db()
	var budget_ms: int = int(warm.config("card_database").data_load_budget_ms)
	var samples: Array[int] = []

	# Act
	for _i: int in range(MEASURED_LOADS):
		var validators: Dictionary = _validators()
		var db: CardDatabase = CardDatabase.new(DataLoader.new(SHIPPED_ROOT))
		var started: int = Time.get_ticks_usec()
		db.load(validators)
		samples.append(Time.get_ticks_usec() - started)
		assert_int(db.state()).is_equal(CardDatabase.State.READY)
	samples.sort()
	var median: int = samples[MEASURED_LOADS / 2]
	_measured = true
	print("PERF card_database load (shipped, Boot debug map) x%d: min %d us, median %d us, max %d us (budget %d ms)"
		% [MEASURED_LOADS, samples[0], median, samples[-1], budget_ms])

	# Assert
	assert_int(median).override_failure_message("shipped load median %d us, budget %d ms" % [median, budget_ms]) \
		.is_less_equal(budget_ms * USEC_PER_MS)
