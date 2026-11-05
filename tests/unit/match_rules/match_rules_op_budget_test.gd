## Blocking op-count and allocation budgets of the rules engine (story
## match-rules/story-019 AC-1; design/gdd/match-rules.md C10, AC-40; ADR-0007
## Performance; ADR-0005). Deterministic: every assertion is a count from
## `RulesEngine.op_counts()` or an equality, never a wall clock. The timed half
## is `tests/performance/match_rules/`.
##
## The fixtures are `tests/helpers/match_budget_fixtures.gd`, shared with the
## timing suites, so both measure one thing. Allocation budgets are counted at
## their allocation sites because `docs/engine-reference/godot/` documents no
## allocation monitor for `Array` or `Dictionary` (story 019 Engine Notes).
extends GdUnitTestSuite

var _fx: MatchBudgetFixtures = MatchBudgetFixtures.new()


## The chain engine after one measured `submit`, and its `op_counts()`.
func _chain_counts() -> Dictionary:
	var engine: RulesEngine = _fx.make_chain_engine(_fx.make_resolver(false))
	var command: Dictionary = _fx.chain_command(engine)
	engine.reset_op_counts()
	var result: Dictionary = engine.submit(command)
	assert_bool(result.accepted).is_true()
	var counts: Dictionary = engine.op_counts()
	engine.end_match()
	return counts


func test_the_c10_loop_runs_one_recompute_per_drain_iteration_on_the_chain() -> void:
	# Act
	var counts: Dictionary = _chain_counts()

	# Assert: the loop's shape is unchanged (death check, recompute, queue pop)
	assert_int(int(counts.recompute_calls)).is_equal(int(counts.drain_iterations))
