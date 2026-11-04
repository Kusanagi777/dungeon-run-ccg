## PERFORMANCE SUITE — wall-clock budgets of RNG & Event Log. NOT part of the
## blocking run: `commands.test` ignores `res://tests/performance`
## (`-i res://tests/performance`) and the non-blocking `performance` job in
## `.github/workflows/tests.yml` runs this folder (continue-on-error, one
## retry, timings printed). `/test-flakiness` may quarantine it if the runner
## proves noisy.
##
## One gate per suite, so a failing gate cannot hide another (review S7): the
## restore gate is `rng_event_log_restore_perf_test.gd`.
##
## Story: production/epics/rng-event-log/story-010-determinism-contract-and-performance-budgets.md
## GDD: design/gdd/rng-event-log.md Acceptance Criteria "Performance"; F5, F7.
## Control manifest Foundation guardrail: `EventLog` 10,000 appends within
## 50 ms. A budget that fails is reported, never silently raised (story 010
## Engine Notes).
## Fixtures are built outside the timed window; each measured block runs once
## (the AC is per call, so no warm-up). `Time.get_ticks_usec()` is NOT
## SOURCEABLE against `docs/engine-reference/godot/` (ADR-0006 claim 17).
extends GdUnitTestSuite

## GDD AC "Performance": events appended, and the append + read budget.
const APPEND_COUNT: int = TestConstants.MAX_MATCH_EVENTS
const APPEND_BUDGET_USEC: int = 50_000
## GDD AC: "payloads ~200 bytes" (F7 `avg_event_bytes` estimate 200).
const PAYLOAD_BYTES: int = 200

var _measured: bool = false


## A test that ended before its measurement still leaves a line in the summary.
func after() -> void:
	if not _measured:
		print(PerfGate.not_assessed("rng_event_log append", "the test ended before its measurement"))


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
	_measured = true
	print("PERF rng_event_log append x%d + events_since(0): %d us (budget %d us, payload %d bytes)" % [APPEND_COUNT, elapsed, APPEND_BUDGET_USEC, JSON.stringify(payload).length()])

	# Assert
	assert_int(events.size()).is_equal(APPEND_COUNT)
	assert_int(elapsed).override_failure_message("10,000 appends + events_since(0) took %d us, budget %d us" % [elapsed, APPEND_BUDGET_USEC]).is_less(APPEND_BUDGET_USEC)
