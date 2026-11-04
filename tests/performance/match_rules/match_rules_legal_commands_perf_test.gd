## PERFORMANCE SUITE — the full-board `legal_commands()` budget. NOT part of the blocking
## run; the non-blocking `performance` job runs this folder (`tests/README.md`).
## One gate per suite: the method and the other gates are in
## `match_rules_perf_test.gd`.
##
## Story: production/epics/match-rules/story-018-performance-budgets.md
## GDD: design/gdd/match-rules.md Game Feel — Input Responsiveness (2 ms), AC-40.
extends GdUnitTestSuite

## design/gdd/match-rules.md Input Responsiveness table (ADR-0007 Performance).
## Not in `project.yaml` or `match_rules.json`: neither carries a per-call
## budget (story 018 deviation, recorded in the perf report).
const LEGAL_BUDGET_USEC: int = 2_000
## AC-40 sample count.
const LEGAL_SAMPLES: int = 100

var _fx: MatchBudgetFixtures = MatchBudgetFixtures.new()
var _measured: bool = false


## A test that ended before its measurement still leaves a line in the summary.
func after() -> void:
	if not _measured:
		print(PerfGate.not_assessed("match_rules legal_commands", "the test ended before its measurement"))


func test_full_board_legal_commands_median_is_within_twice_the_2_ms_budget() -> void:
	# Arrange
	var engine: RulesEngine = _fx.make_full_board_engine(_fx.make_resolver(false))
	var first: Array = engine.legal_commands()   # warm: the targeting memo (ADR-0007)
	var samples: Array[int] = []
	var differing: int = 0

	# Act
	for _i: int in LEGAL_SAMPLES:
		var started: int = Time.get_ticks_usec()
		var legal: Array = engine.legal_commands()
		samples.append(Time.get_ticks_usec() - started)
		if legal != first:
			differing += 1
	var stats: Dictionary = PerfGate.stats(samples)
	_measured = true
	print(PerfGate.match_rules_line("legal_commands full_board(%d commands) x%d" % [first.size(), LEGAL_SAMPLES], stats, LEGAL_BUDGET_USEC))

	# Assert
	assert_int(differing).is_equal(0)
	assert_int(int(stats.median)).override_failure_message("legal_commands median %d us, gate %d us" % [stats.median, LEGAL_BUDGET_USEC * PerfGate.GATE_FACTOR]).is_less(LEGAL_BUDGET_USEC * PerfGate.GATE_FACTOR)
