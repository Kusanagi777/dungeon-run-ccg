## L13: the projection budget (match-ui story 003; design/gdd/match-ui.md AC L13). Wall
## clock, so it lives here and never gates the blocking run. The `MatchQuery` budget is
## `match_query_perf_test.gd`, because each gate has its own suite: a failing gate stops
## its suite at the first failure, and must not hide another gate.
##
## Every line names the machine it ran on: the min-spec machine is not decided
## (`architecture.md` Performance budgets), so a number means little without it.
extends GdUnitTestSuite

const PROJECT_BUDGET_USEC: int = 50_000
## The event count L13 names.
const EVENT_COUNT: int = 2_000

var _measured: bool = false


## A test that ended before its measurement still leaves a line in the summary.
func after() -> void:
	if not _measured:
		print(PerfGate.not_assessed("match_ui project", "the test ended before its measurement"))


static func _machine() -> String:
	return "%s, %d cores" % [OS.get_processor_name(), OS.get_processor_count()]


func test_projecting_2000_events_fits_in_50_ms() -> void:
	# Arrange
	var stream: Array[Dictionary] = MatchUiTestConfig.full_match_events()
	var views: Array[MatchViewState] = []
	for _i: int in ceili(float(EVENT_COUNT) / stream.size()):
		views.append(MatchViewState.new(MatchUiTestConfig.body()))
	var projected: int = 0

	# Act
	var started: int = Time.get_ticks_usec()
	for view: MatchViewState in views:
		for event: Dictionary in stream:
			if projected == EVENT_COUNT:
				break
			@warning_ignore("return_value_discarded")
			view.apply(event)
			projected += 1
	var elapsed: int = Time.get_ticks_usec() - started
	_measured = true
	print("PERF match_ui project x%d events: %d us (budget %d us; %s)" % [projected, elapsed, PROJECT_BUDGET_USEC, _machine()])

	# Assert
	assert_int(projected).is_equal(EVENT_COUNT)
	assert_int(elapsed).override_failure_message("%d events took %d us, budget %d us" % [projected, elapsed, PROJECT_BUDGET_USEC]).is_less_equal(PROJECT_BUDGET_USEC)
