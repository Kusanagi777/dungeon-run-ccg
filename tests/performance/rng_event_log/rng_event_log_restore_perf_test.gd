## PERFORMANCE SUITE — `RngService.restore` at depth. NOT part of the blocking
## run; the non-blocking `performance` job runs this folder (`tests/README.md`).
## One gate per suite: the append gate is `rng_event_log_perf_test.gd`.
##
## Story: production/epics/rng-event-log/story-010-determinism-contract-and-performance-budgets.md
## GDD: design/gdd/rng-event-log.md Acceptance Criteria "Performance"; F5.
## Control manifest Foundation guardrail: `RngStream.restore` ≤ 5 ms per stream
## at 10,000 draws. A budget that fails is reported, never silently raised
## (story 010 Engine Notes). The fixture is built outside the timed window and
## the measured block runs once (the AC is per call, so no warm-up).
## `Time.get_ticks_usec()` is NOT SOURCEABLE against
## `docs/engine-reference/godot/` (ADR-0006 claim 17). The output-equality half
## of the restore AC is deterministic and lives in the blocking
## `tests/unit/rng_event_log/rng_event_log_determinism_test.gd`.
extends GdUnitTestSuite

const SEED: int = TestConstants.DEFAULT_TEST_SEED
## GDD AC "Performance" / F5: restore depth and budget.
const RESTORE_DRAWS: int = 10000
const RESTORE_BUDGET_USEC: int = 5_000
const NEXT: int = 20

var _measured: bool = false


## A test that ended before its measurement still leaves a line in the summary.
func after() -> void:
	if not _measured:
		print(PerfGate.not_assessed("rng_event_log restore", "the test ended before its measurement"))


func test_restore_of_a_ten_thousand_draw_stream_fits_in_5_ms() -> void:
	# Arrange
	var original: RngService = RngService.new(SEED, "test")
	var stream: RngStream = original.stream("match_1")
	for _i: int in range(RESTORE_DRAWS):
		stream.randi32()
	var snap: Dictionary = original.snapshot()
	var restored: RngService = RngService.new(SEED, "test")

	# Act
	var started: int = Time.get_ticks_usec()
	var status: Error = restored.restore(snap)
	var elapsed: int = Time.get_ticks_usec() - started
	_measured = true
	print("PERF rng_event_log restore(draws=%d): %d us (budget %d us)" % [RESTORE_DRAWS, elapsed, RESTORE_BUDGET_USEC])

	# Assert
	assert_int(status).is_equal(OK)
	var expected: Array[int] = []
	var actual: Array[int] = []
	for _i: int in range(NEXT):
		expected.append(stream.randi32())
		actual.append(restored.stream("match_1").randi32())
	assert_array(actual).is_equal(expected)
	assert_int(elapsed).override_failure_message("restore at %d draws took %d us, budget %d us" % [RESTORE_DRAWS, elapsed, RESTORE_BUDGET_USEC]).is_less(RESTORE_BUDGET_USEC)
