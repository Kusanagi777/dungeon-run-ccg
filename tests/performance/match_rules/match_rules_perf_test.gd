## PERFORMANCE SUITE — the planner node gate of Match Rules. NOT part of the
## blocking run: `commands.test` ignores `res://tests/performance`
## (`-i res://tests/performance`) and the non-blocking `performance` job in
## `.github/workflows/tests.yml` runs this folder (continue-on-error, one
## retry, `PERF` lines in the job summary; exit 100 becomes a warning).
##
## One gate per suite, so a failing gate cannot hide another: gdUnit4 without
## `-c` stops a suite at its first failure (review S7). The other Match Rules
## gates are `match_rules_submit_perf_test.gd`,
## `match_rules_legal_commands_perf_test.gd` and `match_rules_fold_perf_test.gd`.
##
## Story: production/epics/match-rules/story-018-performance-budgets.md,
## story-019-rules-engine-performance-pass.md (AC-4)
## GDD: boss-ai F7 / ADR-0006 (`clone()` per look-ahead node against
## `planner_target_ms` 500 p95 per planner run, DD-X18); ADR-0007 Performance.
##
## Each Match Rules gate collects samples with `Time.get_ticks_usec()` around the
## call alone (fixtures and clones are built outside the timed window), prints
## median / p95 / max against the budget (the target) and asserts
## `median < GATE_FACTOR × budget` (the gate: "a regression above 2× the budget
## fails the performance job"). Numbers on a shared CI runner are indicative;
## the reference machine is the owner's (QA plan sprint 4, MR-018). The
## resolver is the scripted double with `recording = false`, so a sample is
## the engine plus the scripted effect passes, never the double's bookkeeping.
## The deterministic half (step counts, list identity, entry counts) is the
## blocking `tests/unit/match_rules/match_rules_hook_fold_budget_test.gd`.
## `Time.get_ticks_usec()` is NOT SOURCEABLE against
## `docs/engine-reference/godot/` (ADR-0006 claim 17); it predates 4.3.
extends GdUnitTestSuite

## Clones timed per state for the planner estimate.
const CLONE_SAMPLES: int = 100
## boss-ai F7: `planner_time ≈ (actions · evals + lethal_nodes) · t_sim`, with
## `t_sim = clone + one submit` measured here; the worked example uses 8 actions
## per turn. The per-band counts are read from `assets/data/ai_profiles.json`
## `bands.<n>.budgets`, and the target from its `runtime.planner_target_ms`
## ([method PerfGate.planner_target_usec]).
const F7_ACTIONS: int = 8
const AI_PROFILES_PATH: String = "res://assets/data/ai_profiles.json"
const BANDS: Array[String] = ["1", "2", "3"]
## The band whose F7 count the gate uses (story 019 AC-4; DD-X18). Band 3's counts
## are not targeted here: boss-ai F7 lowers them after the follow-up re-measure.
const GATE_BAND: String = "2"
## Story 019 AC-4: the node cost band 2 can afford. `planner_target_ms` 500 over
## F7's 1,460 band-2 nodes is 342.5 µs; 340 keeps the run at 496 ms. The test
## checks it against the shipped target and counts, so the data cannot drift past it.
const NODE_TARGET_USEC: int = 340
## Why a miss here does not settle AC-4: it is judged on the release template.
const GATE_MISS_NOTE: String = "AC-4 is judged on the release template; a miss on this build goes to the follow-up re-measure"

var _fx: MatchBudgetFixtures = MatchBudgetFixtures.new()
var _measured: bool = false


## A test that ended before its measurement still leaves a line in the summary.
func after() -> void:
	if not _measured:
		print(PerfGate.not_assessed("match_rules planner gate", "the test ended before its measurement"))


## The F7 node count per planned turn of [param band]:
## `F7_ACTIONS · max_evals_per_action + lethal_max_nodes`.
static func _f7_nodes(profiles: Dictionary, band: String) -> int:
	var budgets: Dictionary = profiles.config.bands[band].budgets
	return F7_ACTIONS * int(budgets.max_evals_per_action) + int(budgets.lethal_max_nodes)


## `[label, engine]` for every story 017 fixture state plus the two budget
## fixtures; a fixture that no longer reaches its state fails the test.
func _states() -> Array:
	var out: Array = []
	for path: String in MatchBudgetFixtures.fixture_paths():
		var fixture: Dictionary = MatchBudgetFixtures.read_fixture(path)
		var engine: RulesEngine = _fx.engine_for(fixture, false)
		assert_object(engine).override_failure_message(_fx.last_error).is_not_null()
		if engine == null:
			continue
		var mismatch: String = MatchBudgetFixtures.expectation_mismatch(engine, fixture)
		assert_str(mismatch).override_failure_message("%s: %s" % [fixture.name, mismatch]).is_empty()
		out.append([str(fixture.name), engine])
	out.append(["budget_full_board", _fx.make_full_board_engine(_fx.make_resolver(false))])
	out.append(["budget_chain", _fx.make_chain_engine(_fx.make_resolver(false))])
	return out


## Per state: [constant CLONE_SAMPLES] × (`clone()` timed, then the state's
## first `legal_commands()` entry submitted on the clone, timed) — the
## planner's per-candidate node (ADR-0006: clone, submit one command,
## discard). Prints each state's clone and clone+submit median / p95 / max,
## then F7's per-band node count against the count that fits
## `planner_target_ms` at the measured median node cost. Gate: the node cost may
## be at most [constant PerfGate.GATE_FACTOR] × [constant NODE_TARGET_USEC], per
## planner run (story 019 AC-4; DD-X18). The target is required: `ai_profiles.json`
## ships it, so a file without one fails here rather than passing unassessed.
func test_clone_and_one_command_node_cost_per_fixture_state_against_the_f7_planner_budget() -> void:
	# Arrange
	var profiles: Dictionary = MatchBudgetFixtures.read_fixture(AI_PROFILES_PATH)
	assert_bool(profiles.has("config")).override_failure_message("%s did not parse" % AI_PROFILES_PATH).is_true()
	var target_usec: int = PerfGate.planner_target_usec(profiles)
	assert_int(target_usec).override_failure_message("%s is not in the data" % PerfGate.PLANNER_TARGET_SOURCE).is_not_equal(PerfGate.NOT_SET)
	var states: Array = _states()
	var node_medians: Array[int] = []

	# Act
	for row: Array in states:
		var label: String = row[0]
		var engine: RulesEngine = row[1]
		var command: Dictionary = engine.legal_commands()[0]
		var clones: Array[int] = []
		var nodes: Array[int] = []
		for _i: int in CLONE_SAMPLES:
			var started: int = Time.get_ticks_usec()
			var sandbox: RulesEngine = engine.clone()
			var cloned: int = Time.get_ticks_usec()
			@warning_ignore("return_value_discarded")
			sandbox.submit(command)
			var done: int = Time.get_ticks_usec()
			clones.append(cloned - started)
			nodes.append(done - started)
			sandbox.end_match()
		var clone_stats: Dictionary = PerfGate.stats(clones)
		var node_stats: Dictionary = PerfGate.stats(nodes)
		node_medians.append(int(node_stats.median))
		print("PERF match_rules clone %s x%d: median %d us, p95 %d us, max %d us" % [label, CLONE_SAMPLES, clone_stats.median, clone_stats.p95, clone_stats.max])
		print("PERF match_rules clone+submit(%s) %s x%d: median %d us, p95 %d us, max %d us" % [command.type, label, CLONE_SAMPLES, node_stats.median, node_stats.p95, node_stats.max])
	var sorted: Array[int] = node_medians.duplicate()
	sorted.sort()
	var t_sim: int = sorted[sorted.size() / 2]
	for band: String in BANDS:
		print(PerfGate.planner_band_line(band, _f7_nodes(profiles, band), t_sim, target_usec))

	# Assert
	_measured = true
	var nodes: int = _f7_nodes(profiles, GATE_BAND)
	var gate: float = float(NODE_TARGET_USEC * PerfGate.GATE_FACTOR)
	print("PERF match_rules planner target band %s: %d us per node, %d nodes = %d ms per planner run" % [GATE_BAND, NODE_TARGET_USEC, nodes, nodes * NODE_TARGET_USEC / PerfGate.USEC_PER_MS])
	print(PerfGate.planner_gate_line(GATE_BAND, t_sim, target_usec, gate, GATE_MISS_NOTE))
	assert_int(nodes * NODE_TARGET_USEC).override_failure_message("%d us per node over %d band-%s nodes passes the %d us target" % [NODE_TARGET_USEC, nodes, GATE_BAND, target_usec]).is_less_equal(target_usec)
	assert_float(float(t_sim)).override_failure_message("node cost (clone + one submit) median %d us; band %s gate %.1f us: %s" % [t_sim, GATE_BAND, gate, GATE_MISS_NOTE]).is_less(gate)
	for row: Array in states:
		(row[1] as RulesEngine).end_match()
