## PERFORMANCE SUITE — wall-clock budgets of Match Rules. NOT part of the
## blocking run: `commands.test` ignores `res://tests/performance`
## (`-i res://tests/performance`) and the non-blocking `performance` job in
## `.github/workflows/tests.yml` runs this folder (continue-on-error, one
## retry, `PERF` lines in the job summary; exit 100 becomes a warning).
##
## Story: production/epics/match-rules/story-018-performance-budgets.md
## GDD: design/gdd/match-rules.md Game Feel — Input Responsiveness (`submit()`
## 5 ms, `legal_commands()` 2 ms), AC-40. ADR-0007 Performance; ADR-0005
## Decision 4 (12-entry fold < 0.05 ms); boss-ai F7 / ADR-0006 (`clone()` per
## look-ahead node against `planner_target_ms` 50 p95).
##
## Each test collects samples with `Time.get_ticks_usec()` around the call
## alone (fixtures and clones are built outside the timed window), prints
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

## design/gdd/match-rules.md Input Responsiveness table (ADR-0007 Performance).
## Not in `project.yaml` or `match_rules.json`: neither carries a per-call
## budget (story 018 deviation, recorded in the perf report).
const SUBMIT_BUDGET_USEC: int = 5_000
const LEGAL_BUDGET_USEC: int = 2_000
## ADR-0005 Decision 4: a 12-entry fold < 0.05 ms.
const FOLD_BUDGET_USEC: float = 50.0
## AC-40: "a regression above 2× the budget fails the performance job".
const GATE_FACTOR: int = 2
## AC-40 sample counts.
const SUBMIT_SAMPLES: int = 100
const LEGAL_SAMPLES: int = 100
const FOLD_SAMPLES: int = 1000
## Clones timed per state for the planner estimate.
const CLONE_SAMPLES: int = 100
## design/registry/entities.yaml `ai_planner_target_ms` (boss-ai Tuning
## Knobs; ADR-0006 Performance: 50 ms p95 per turn on the worker), in µs.
const PLANNER_TARGET_USEC: int = 50_000
## boss-ai F7: `planner_time ≈ (actions · evals + lethal_nodes) · t_sim`, with
## `t_sim = clone + one submit` assumed ≈ 0.01 ms; the worked example uses
## 8 actions per turn. The per-band counts are read from
## `assets/data/ai_profiles.json` `bands.<n>.budgets`.
const F7_ACTIONS: int = 8
const F7_T_SIM_USEC: float = 10.0
const AI_PROFILES_PATH: String = "res://assets/data/ai_profiles.json"
const BANDS: Array[String] = ["1", "2", "3"]
## The band whose F7 count the gate uses (F7's worked example, A22).
const GATE_BAND: String = "3"

var _fx: MatchBudgetFixtures = MatchBudgetFixtures.new()


## `{median, p95, max}` of [param samples] (nearest-rank, µs).
static func _stats(samples: Array[int]) -> Dictionary:
	var sorted: Array[int] = samples.duplicate()
	sorted.sort()
	var n: int = sorted.size()
	var p95_index: int = clampi(ceili(0.95 * n) - 1, 0, n - 1)
	return {"median": sorted[n / 2], "p95": sorted[p95_index], "max": sorted[n - 1]}


static func _line(what: String, stats: Dictionary, budget: Variant) -> String:
	return "PERF match_rules %s: median %d us, p95 %d us, max %d us (budget %s us, gate %s us)" % [
		what, int(stats.median), int(stats.p95), int(stats.max), str(budget), str(budget * GATE_FACTOR)]


# --- AC-40: worst-case submit ------------------------------------------------------

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
	var stats: Dictionary = _stats(samples)
	print(_line("submit deathrattle_chain(%d passes) x%d" % [steps, SUBMIT_SAMPLES], stats, SUBMIT_BUDGET_USEC))

	# Assert
	assert_int(steps).is_greater_equal(MatchBudgetFixtures.CHAIN_MIN_STEPS)
	assert_int(int(stats.median)).override_failure_message("submit median %d us, gate %d us (budget %d)" % [stats.median, SUBMIT_BUDGET_USEC * GATE_FACTOR, SUBMIT_BUDGET_USEC]).is_less(SUBMIT_BUDGET_USEC * GATE_FACTOR)


# --- AC-40 Input Responsiveness: legal_commands on a full board --------------------

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
	var stats: Dictionary = _stats(samples)
	print(_line("legal_commands full_board(%d commands) x%d" % [first.size(), LEGAL_SAMPLES], stats, LEGAL_BUDGET_USEC))

	# Assert
	assert_int(differing).is_equal(0)
	assert_int(int(stats.median)).override_failure_message("legal_commands median %d us, gate %d us" % [stats.median, LEGAL_BUDGET_USEC * GATE_FACTOR]).is_less(LEGAL_BUDGET_USEC * GATE_FACTOR)


# --- ADR-0005: a 12-entry fold ------------------------------------------------------

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
	var stats: Dictionary = _stats(samples)
	print(_line("hooks.fold modify_damage(%d entries) x%d" % [hooks.entry_count(), FOLD_SAMPLES], stats, FOLD_BUDGET_USEC))
	print("PERF match_rules hooks.fold modify_damage(%d entries) block mean: %.2f us over %d folds (budget %.1f us)" % [hooks.entry_count(), mean, FOLD_SAMPLES, FOLD_BUDGET_USEC])

	# Assert — a fold that ran no evaluator would time nothing
	assert_int(folded).is_equal(expected)
	assert_int(hooks.entry_count()).is_equal(HookRegistry.DEBUG_MAX_ENTRIES)
	assert_float(float(stats.median)).override_failure_message("fold median %d us, gate %.1f us" % [stats.median, FOLD_BUDGET_USEC * GATE_FACTOR]).is_less(FOLD_BUDGET_USEC * GATE_FACTOR)


# --- clone() and one-command sandbox nodes (boss-ai F7, ADR-0006) -----------------

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
## node cost may be at most [constant GATE_FACTOR] × the per-node share
## `planner_target / F7 nodes(band 3)` (= F7's 0.01 ms assumption, rounded).
func test_clone_and_one_command_node_cost_per_fixture_state_against_the_f7_planner_budget() -> void:
	# Arrange
	var profiles: Dictionary = MatchBudgetFixtures.read_fixture(AI_PROFILES_PATH)
	assert_bool(profiles.has("config")).override_failure_message("%s did not parse" % AI_PROFILES_PATH).is_true()
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
		var clone_stats: Dictionary = _stats(clones)
		var node_stats: Dictionary = _stats(nodes)
		node_medians.append(int(node_stats.median))
		print("PERF match_rules clone %s x%d: median %d us, p95 %d us, max %d us" % [label, CLONE_SAMPLES, clone_stats.median, clone_stats.p95, clone_stats.max])
		print("PERF match_rules clone+submit(%s) %s x%d: median %d us, p95 %d us, max %d us (F7 t_sim %.0f us)" % [command.type, label, CLONE_SAMPLES, node_stats.median, node_stats.p95, node_stats.max, F7_T_SIM_USEC])
	var sorted: Array[int] = node_medians.duplicate()
	sorted.sort()
	var t_sim: int = sorted[sorted.size() / 2]
	var fit: int = PLANNER_TARGET_USEC / maxi(1, t_sim)
	for band: String in BANDS:
		var f7: int = _f7_nodes(profiles, band)
		print("PERF match_rules planner band %s: F7 nodes %d x t_sim %d us = %d ms per turn (target %d ms); nodes that fit %d (%d per round, forecast + play_turn)" % [
			band, f7, t_sim, f7 * t_sim / 1000, PLANNER_TARGET_USEC / 1000, fit, fit / 2])

	# Assert
	var gate_share: float = float(PLANNER_TARGET_USEC) / _f7_nodes(profiles, GATE_BAND)
	assert_float(float(t_sim)).override_failure_message("node cost (clone + one submit) median %d us; band %s F7 share %.1f us, gate %.1f us" % [t_sim, GATE_BAND, gate_share, gate_share * GATE_FACTOR]).is_less(gate_share * GATE_FACTOR)
	for row: Array in states:
		(row[1] as RulesEngine).end_match()
