## PERFORMANCE SUITE — wall-clock budgets of RNG & Event Log. NOT part of the
## blocking run: `commands.test` ignores `res://tests/performance`
## (`-i res://tests/performance`) and the non-blocking `performance` job in
## `.github/workflows/tests.yml` runs this folder (continue-on-error, one
## retry, timings printed). `/test-flakiness` may quarantine it if the runner
## proves noisy.
##
## Story: production/epics/rng-event-log/story-010-determinism-contract-and-performance-budgets.md
## GDD: design/gdd/rng-event-log.md Acceptance Criteria "Performance"; F5, F7.
## Control manifest Foundation guardrails: `RngStream.restore` ≤ 5 ms per
## stream at 10,000 draws; `EventLog` 10,000 appends within 50 ms. A budget
## that fails is reported, never silently raised (story 010 Engine Notes).
## Fixtures are built outside the timed window; each measured block runs once
## (the AC is per call, so no warm-up). `Time.get_ticks_usec()` is NOT
## SOURCEABLE against `docs/engine-reference/godot/` (ADR-0006 claim 17).
## The output-equality half of the restore AC is deterministic and lives in the
## blocking `tests/unit/rng_event_log/rng_event_log_determinism_test.gd`.
extends GdUnitTestSuite

const SEED: int = TestConstants.DEFAULT_TEST_SEED
## GDD AC "Performance": events appended, and the append + read budget.
const APPEND_COUNT: int = TestConstants.MAX_MATCH_EVENTS
const APPEND_BUDGET_USEC: int = 50_000
## GDD AC "Performance" / F5: restore depth and budget.
const RESTORE_DRAWS: int = 10000
const RESTORE_BUDGET_USEC: int = 5_000
const NEXT: int = 20
## GDD AC: "payloads ~200 bytes" (F7 `avg_event_bytes` estimate 200).
const PAYLOAD_BYTES: int = 200


## A rule 14 payload whose JSON text is about [constant PAYLOAD_BYTES] long.
func _payload() -> Dictionary:
	var payload: Dictionary = {
		"source": 7, "target": 2, "requested": 3, "prevented": 0,
		"armor_absorbed": 0, "dealt": 3, "health_after": 27, "note": "",
	}
	var missing: int = PAYLOAD_BYTES - JSON.stringify(payload).length()
	payload.note = "x".repeat(maxi(missing, 0))
	return payload


func test_ten_thousand_appends_and_events_since_zero_fit_in_50_ms() -> void:
	# Arrange
	var log: EventLog = EventLog.new(APPEND_COUNT, EventLog.SCOPE_MATCH)
	var payload: Dictionary = _payload()

	# Act
	var started: int = Time.get_ticks_usec()
	for _i: int in range(APPEND_COUNT):
		log.append(&"damage_dealt", payload)
	var events: Array[Dictionary] = log.events_since(0)
	var elapsed: int = Time.get_ticks_usec() - started
	print("PERF rng_event_log append x%d + events_since(0): %d us (budget %d us, payload %d bytes)" % [APPEND_COUNT, elapsed, APPEND_BUDGET_USEC, JSON.stringify(payload).length()])

	# Assert
	assert_int(events.size()).is_equal(APPEND_COUNT)
	assert_int(elapsed).override_failure_message("10,000 appends + events_since(0) took %d us, budget %d us" % [elapsed, APPEND_BUDGET_USEC]).is_less(APPEND_BUDGET_USEC)


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
