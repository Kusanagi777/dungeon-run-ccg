## PERFORMANCE SUITE — the worst-case `submit()` budget. NOT part of the blocking
## run; the non-blocking `performance` job runs this folder (`tests/README.md`).
## One gate per suite: the method and the other gates are in
## `match_rules_perf_test.gd`.
##
## Story: production/epics/match-rules/story-018-performance-budgets.md
## GDD: design/gdd/match-rules.md Game Feel — Input Responsiveness (5 ms), AC-40.
extends GdUnitTestSuite

## design/gdd/match-rules.md Input Responsiveness table (ADR-0007 Performance).
## Not in `project.yaml` or `match_rules.json`: neither carries a per-call
## budget (story 018 deviation, recorded in the perf report).
const SUBMIT_BUDGET_USEC: int = 5_000
## AC-40 sample count.
const SUBMIT_SAMPLES: int = 100

var _fx: MatchBudgetFixtures = MatchBudgetFixtures.new()
var _measured: bool = false


## A test that ended before its measurement still leaves a line in the summary.
func after() -> void:
	if not _measured:
		print(PerfGate.not_assessed("match_rules submit", "the test ended before its measurement"))


func test_worst_case_deathrattle_chain_submit_median_is_within_twice_the_5_ms_budget() -> void:
	# Arrange
	var engine: RulesEngine = _fx.make_chain_engine(_fx.make_resolver(false))
	var samples: Array[int] = []
	var steps: int = 0

	# Act — a fresh clone per sample, so each is the first swing
	for i: int in SUBMIT_SAMPLES:
		var sandbox: RulesEngine = engine.clone()
		var command: Dictionary = _fx.chain_command(sandbox)
		var started: int = Time.get_ticks_usec()
		var result: Dictionary = sandbox.submit(command)
		samples.append(Time.get_ticks_usec() - started)
		assert_bool(result.accepted).is_true()
		if i == 0:
			steps = MatchBudgetFixtures.deathrattle_passes(sandbox.state().log.events_since(0))
		sandbox.end_match()
	var stats: Dictionary = PerfGate.stats(samples)
	_measured = true
	print(PerfGate.match_rules_line("submit deathrattle_chain(%d passes) x%d" % [steps, SUBMIT_SAMPLES], stats, SUBMIT_BUDGET_USEC))

	# Assert
	assert_int(steps).is_greater_equal(MatchBudgetFixtures.CHAIN_MIN_STEPS)
	assert_int(int(stats.median)).override_failure_message("submit median %d us, gate %d us (budget %d)" % [stats.median, SUBMIT_BUDGET_USEC * PerfGate.GATE_FACTOR, SUBMIT_BUDGET_USEC]).is_less(SUBMIT_BUDGET_USEC * PerfGate.GATE_FACTOR)
