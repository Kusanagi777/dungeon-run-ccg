## PERFORMANCE SUITE — the Card Database validation check count, logged beside
## the GDD's v1 estimate. Not a budget: the figure is a log line. NOT part of the
## blocking run; the non-blocking `performance` job runs this folder
## (`tests/README.md`). It has a suite of its own so that a failure here cannot
## hide a gate, or a gate failure hide this line (review S7).
##
## Story: production/epics/card-database/story-009-load-and-memory-budget.md AC-3.
extends GdUnitTestSuite

const SHIPPED_ROOT: String = "res://assets/data/"
const BOOT_SCRIPT: GDScript = preload("res://src/core/boot.gd")

var _measured: bool = false


## A test that ended before its measurement still leaves a line in the summary.
func after() -> void:
	if not _measured:
		print(PerfGate.not_assessed("card_database validation_checks", "the test ended before its measurement"))


func _validators() -> Dictionary:
	var boot: Node = auto_free(BOOT_SCRIPT.new())
	return boot._collect_validators(null, true)


func test_shipped_validation_checks_logged_beside_the_v1_estimate() -> void:
	# Arrange
	var loader: DataLoader = DataLoader.new(SHIPPED_ROOT)

	# Act
	var result: DataLoader.LoadResult = loader.run(_validators(), CardDatabase.new(loader))
	_measured = true
	print("PERF card_database validation_checks (shipped): %d = n_records %d + n_refs %d (GDD v1 estimate %d; logged, not asserted)"
		% [result.validation_checks(), result.n_records, result.n_refs, TestConstants.VALIDATION_CHECKS_V1_ESTIMATE])

	# Assert — the figure is a log line (AC-3); only the identity is checked here
	assert_bool(result.report.has_errors()).override_failure_message(result.report.to_text()).is_false()
	assert_int(result.validation_checks()).is_equal(result.n_records + result.n_refs)
