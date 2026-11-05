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

## R1 (story 019 AC-1): the chain fixture has no aura source, so no recompute
## has anything to compare. Baseline on the unchanged engine: 122, two per
## recompute.
const CHAIN_STAT_MAP_PASSES: int = 0
## R1 (story 019 AC-1): at most these per recompute with an aura or a primitive:
## the `before` and `after` of [method RulesEngine._recompute_auras].
const MAX_STAT_MAP_PASSES_PER_RECOMPUTE: int = 2
## Quiet recomputes the R1 aura test runs after the last aura has gone.
const QUIET_RECOMPUTES: int = 3

var _fx: MatchBudgetFixtures = MatchBudgetFixtures.new()
var _golden: MatchGoldenLogs = MatchGoldenLogs.new()


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


# --- R1: `_recompute_auras` skips both stat passes when nothing can have moved ------

func test_the_chain_with_no_aura_source_makes_no_stat_map_pass() -> void:
	# Act
	var counts: Dictionary = _chain_counts()

	# Assert
	assert_int(int(counts.stat_map_passes)).is_equal(CHAIN_STAT_MAP_PASSES)


func _no_step() -> void:
	pass


func test_an_aura_board_passes_at_most_twice_per_recompute_and_never_once_the_aura_has_gone() -> void:
	# Arrange: the running stat-pass total, read inside every recompute
	var resolver: TestEffectResolver = _fx.make_resolver(false)
	var engine: RulesEngine = _fx.make_aura_board(resolver)
	var source_id: int = _fx.add_aura_source(resolver, engine)
	var totals: Array[int] = []
	resolver.aura_scripts.append(func(e: RulesEngine) -> void: totals.append(int(e.op_counts().stat_map_passes)))
	engine.reset_op_counts()

	# Act: applied, re-applied, Silenced (the last strip), then quiet recomputes
	engine.run_action(_no_step)
	engine.run_action(_no_step)
	engine.run_action(func() -> void: engine.silence(source_id))
	var before_quiet: int = int(engine.op_counts().stat_map_passes)
	for _i: int in QUIET_RECOMPUTES:
		engine.run_action(_no_step)
	var counts: Dictionary = engine.op_counts()

	# Assert: every gap between two recomputes holds at most one recompute's passes
	assert_int(totals.size()).is_greater_equal(QUIET_RECOMPUTES)
	for i: int in range(1, totals.size()):
		assert_int(totals[i] - totals[i - 1]).is_less_equal(MAX_STAT_MAP_PASSES_PER_RECOMPUTE)
	assert_int(int(counts.stat_map_passes)).override_failure_message("a recompute with no aura left made a stat pass").is_equal(before_quiet)
	engine.end_match()


func test_a_primitive_called_in_the_aura_pass_reports_the_auras_recomputed_of_its_golden() -> void:
	# Arrange: `{primitive: its golden auras_recomputed payloads}`
	var recorded: Dictionary = _golden_aura_payloads()
	var reported: int = 0
	for primitive: StringName in RulesEngine.PRIMITIVES:
		var log: TestEventLog = TestEventLog.new()
		var resolver: TestEffectResolver = _fx.make_resolver(false)
		var engine: RulesEngine = _fx.make_aura_board(resolver, log)
		var mark: int = log.events.size()
		resolver.aura_scripts.append(_golden.primitive_once.bind(primitive))

		# Act: no aura enchantment exists, so only the primitive can move a value
		engine.run_action(_no_step)

		# Assert
		var payloads: Array = []
		for event: Dictionary in log.events.slice(mark):
			if StringName(event.type) == &"auras_recomputed":
				payloads.append(EventLogAssertions.canonical_json(event.payload))
		assert_array(payloads).override_failure_message("%s in the aura pass" % primitive).is_equal(recorded.get(String(primitive), []))
		reported += payloads.size()
		engine.end_match()
	assert_int(reported).override_failure_message("no primitive reported a change: the test proves nothing").is_greater(0)


## The `auras_recomputed` payloads of each primitive scenario of the aura golden.
func _golden_aura_payloads() -> Dictionary:
	var out: Dictionary = {}
	var scenario: String = ""
	var text: String = FileAccess.get_file_as_string(MatchGoldenLogs.path_of(MatchGoldenLogs.AURAS))
	for line: String in text.split("\n", false):
		var row: Dictionary = JSON.parse_string(line)
		if row.has("scenario"):
			scenario = str(row.scenario)
		elif row.has("event") and str(row.event.type) == "auras_recomputed":
			if not out.has(scenario):
				out[scenario] = []
			# the line, not the parsed row: JSON numbers parse back as floats
			var payload: String = line.substr(line.find("\"payload\":") + "\"payload\":".length())
			(out[scenario] as Array).append(payload.left(payload.rfind(",\"seq\":")))
	return out


func test_the_op_counters_stay_out_of_the_log_the_snapshot_and_the_result() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _fx.make_chain_engine(_fx.make_resolver(false), log)

	# Act
	@warning_ignore("return_value_discarded")
	engine.submit(_fx.chain_command(engine))
	@warning_ignore("return_value_discarded")
	engine.submit(MatchRecords.concede(MatchRecords.SIDE_PLAYER))
	var seen: String = log.to_json() + str(engine.result()) + str(engine.state_snapshot(MatchFactory.PLAYER_HERO_ENTITY_ID))

	# Assert
	for counter: String in engine.op_counts():
		assert_bool(seen.contains(counter)).override_failure_message("%s reached the match record" % counter).is_false()
	engine.end_match()


func test_a_clone_starts_its_op_counts_at_zero() -> void:
	# Arrange
	var engine: RulesEngine = _fx.make_chain_engine(_fx.make_resolver(false))
	@warning_ignore("return_value_discarded")
	engine.legal_commands()
	var live_ran: RulesEngine = engine.clone()
	@warning_ignore("return_value_discarded")
	live_ran.submit(_fx.chain_command(live_ran))

	# Act
	var fresh: RulesEngine = live_ran.clone()

	# Assert
	for counter: String in fresh.op_counts():
		assert_int(int(fresh.op_counts()[counter])).override_failure_message(counter).is_equal(0)
	fresh.end_match()
	live_ran.end_match()
	engine.end_match()
