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
## Story: production/epics/match-rules/story-018-performance-budgets.md
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
## The band whose F7 count the gate uses (F7's worked example, A22).
const GATE_BAND: String = "3"
## Band 3's counts are 4.4× over the target at the measured `t_sim` (boss-ai
## F7), so this gate misses until story 019 AC-4 moves it to band 2.
const GATE_MISS_NOTE: String = "expected until match-rules story 019 moves the gate to band 2; band 3's counts await R5"

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
## `planner_target_ms` at the measured median node cost. Gate: the band-3
## node cost may be at most [constant PerfGate.GATE_FACTOR] × the per-node share
## `planner_target / F7 nodes(band 3)`, per planner run (DD-X18). With no target
## in the data the measurements still print and the gate prints NOT ASSESSED.
func test_clone_and_one_command_node_cost_per_fixture_state_against_the_f7_planner_budget() -> void:
	# Arrange
	var profiles: Dictionary = MatchBudgetFixtures.read_fixture(AI_PROFILES_PATH)
	assert_bool(profiles.has("config")).override_failure_message("%s did not parse" % AI_PROFILES_PATH).is_true()
	var target_usec: int = PerfGate.planner_target_usec(profiles)
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
	if target_usec == PerfGate.NOT_SET:
		print(PerfGate.not_assessed("match_rules planner gate band %s" % GATE_BAND, "%s is not in the data" % PerfGate.PLANNER_TARGET_SOURCE))
	else:
		var gate: float = PerfGate.planner_gate_usec(target_usec, _f7_nodes(profiles, GATE_BAND), PerfGate.GATE_FACTOR)
		print(PerfGate.planner_gate_line(GATE_BAND, t_sim, target_usec, gate, GATE_MISS_NOTE))
		assert_float(float(t_sim)).override_failure_message("node cost (clone + one submit) median %d us; band %s gate %.1f us: %s" % [t_sim, GATE_BAND, gate, GATE_MISS_NOTE]).is_less(gate)
	for row: Array in states:
		(row[1] as RulesEngine).end_match()
