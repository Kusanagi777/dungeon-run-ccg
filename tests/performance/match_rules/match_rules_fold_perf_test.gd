## PERFORMANCE SUITE — the 12-entry hook fold budget. NOT part of the blocking
## run; the non-blocking `performance` job runs this folder (`tests/README.md`).
## One gate per suite: the method and the other gates are in
## `match_rules_perf_test.gd`.
##
## Story: production/epics/match-rules/story-018-performance-budgets.md
## ADR-0005 Decision 4 (12-entry fold < 0.05 ms), AC-40.
extends GdUnitTestSuite

## ADR-0005 Decision 4: a 12-entry fold < 0.05 ms.
const FOLD_BUDGET_USEC: float = 50.0
## AC-40 sample count.
const FOLD_SAMPLES: int = 1000

var _fx: MatchBudgetFixtures = MatchBudgetFixtures.new()
var _measured: bool = false


## A test that ended before its measurement still leaves a line in the summary.
func after() -> void:
	if not _measured:
		print(PerfGate.not_assessed("match_rules hooks.fold", "the test ended before its measurement"))


func test_twelve_entry_modify_damage_fold_median_is_within_twice_the_0_05_ms_budget() -> void:
	# Arrange — keep the resolver alive: the registry's evaluator Callables do
	# not hold it, and a freed one makes every fold a no-op (seen 2026-11-04:
	# a 0.19 us "fold" that never called an evaluator)
	var resolver: TestEffectResolver = _fx.make_resolver(false)
	var hooks: HookRegistry = _fx.make_fold_registry(resolver)
	var ctx: Dictionary = {"source": null, "target": MatchFactory.PLAYER_HERO_ENTITY_ID}
	var samples: Array[int] = []
	var expected: int = HookRegistry.DEBUG_MAX_ENTRIES * MatchBudgetFixtures.FOLD_DELTA
	var folded: int = hooks.fold(&"modify_damage", &"player", 0, ctx)

	# Act
	for _i: int in FOLD_SAMPLES:
		var started: int = Time.get_ticks_usec()
		@warning_ignore("return_value_discarded")
		hooks.fold(&"modify_damage", &"player", 0, ctx)
		samples.append(Time.get_ticks_usec() - started)
	var block_started: int = Time.get_ticks_usec()
	for _i: int in FOLD_SAMPLES:
		@warning_ignore("return_value_discarded")
		hooks.fold(&"modify_damage", &"player", 0, ctx)
	var mean: float = float(Time.get_ticks_usec() - block_started) / FOLD_SAMPLES
	var stats: Dictionary = PerfGate.stats(samples)
	_measured = true
	print(PerfGate.match_rules_line("hooks.fold modify_damage(%d entries) x%d" % [hooks.entry_count(), FOLD_SAMPLES], stats, FOLD_BUDGET_USEC))
	print("PERF match_rules hooks.fold modify_damage(%d entries) block mean: %.2f us over %d folds (budget %.1f us)" % [hooks.entry_count(), mean, FOLD_SAMPLES, FOLD_BUDGET_USEC])

	# Assert — a fold that ran no evaluator would time nothing
	assert_int(folded).is_equal(expected)
	assert_int(hooks.entry_count()).is_equal(HookRegistry.DEBUG_MAX_ENTRIES)
	assert_float(float(stats.median)).override_failure_message("fold median %d us, gate %.1f us" % [stats.median, FOLD_BUDGET_USEC * PerfGate.GATE_FACTOR]).is_less(FOLD_BUDGET_USEC * PerfGate.GATE_FACTOR)
