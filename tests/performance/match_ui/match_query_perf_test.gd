## L13: the `MatchQuery` and projection budgets (match-ui story 003; design/gdd/match-ui.md
## AC L13, U2 "≤ 2 ms each"). Wall clock, so it lives here and never gates the blocking
## run. The third L13 figure, skip-all, is `animation_queue_perf_test.gd`: 300 steps
## against the same 100 ms, a harder case than the 200 the criterion names.
##
## Every line names the machine it ran on: the min-spec machine is not decided
## (`architecture.md` Performance budgets), so a number means little without it.
extends GdUnitTestSuite

const QUERY_BUDGET_USEC: int = 2_000
const PROJECT_BUDGET_USEC: int = 50_000
## The event count L13 names.
const EVENT_COUNT: int = 2_000
## Calls per query, so `PerfGate.stats` has a p95 worth reading.
const SAMPLES: int = 200
const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const SIDE_BOSS: String = MatchRecords.SIDE_BOSS

var _measured: bool = false


## A test that ended before its measurement still leaves a line in the summary.
func after() -> void:
	if not _measured:
		print(PerfGate.not_assessed("match_ui query", "the test ended before its measurement"))


static func _machine() -> String:
	return "%s, %d cores" % [OS.get_processor_name(), OS.get_processor_count()]


## `{median, p95, max}` of [param call] over [constant SAMPLES] calls.
func _timed(call: Callable) -> Dictionary:
	var samples: Array[int] = []
	for _i: int in SAMPLES:
		var started: int = Time.get_ticks_usec()
		@warning_ignore("return_value_discarded")
		call.call()
		samples.append(Time.get_ticks_usec() - started)
	return PerfGate.stats(samples)


func test_every_match_query_call_fits_in_2_ms_on_a_7_v_7_board() -> void:
	# Arrange
	var fixtures: MatchBudgetFixtures = MatchBudgetFixtures.new()
	var engine: RulesEngine = fixtures.make_full_board_engine(fixtures.make_resolver(false))
	var query: MatchQuery = MatchQuery.new(engine, MatchDriverFixture.database(), {})
	var token: int = int(engine.state().players[SIDE_BOSS].board[0].entity_id)
	var calls: Dictionary = {
		"phase": query.phase,
		"pending_choice": query.pending_choice,
		"entity": query.entity.bind(token),
		"hand": query.hand.bind(SIDE_PLAYER),
		"card_text": query.card_text.bind(MatchDriverFixture.VANILLA),
		"legal_commands": query.legal_commands,
		"hero_power_state": query.hero_power_state.bind(SIDE_PLAYER),
	}

	# Act
	var measured: Dictionary = {}
	for name: String in calls:
		measured[name] = _timed(calls[name])
		print("PERF match_ui query %s: median %d us, p95 %d us, max %d us (budget %d us; %s)" % [
			name, int(measured[name].median), int(measured[name].p95), int(measured[name].max), QUERY_BUDGET_USEC, _machine()])
	_measured = true
	engine.end_match()

	# Assert
	for name: String in measured:
		assert_int(int(measured[name].p95)).override_failure_message("%s p95 %d us, budget %d us" % [name, int(measured[name].p95), QUERY_BUDGET_USEC]).is_less_equal(QUERY_BUDGET_USEC)


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
