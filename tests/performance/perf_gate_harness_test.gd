## The performance harness itself: deterministic checks, no timing. It lives
## beside the gates because it describes them, so it runs in the non-blocking
## `performance` job and `commands.test` drops it with the rest of this folder.
##
## Review: production/reviews/2026-11-04/code-review-s4-unreviewed.md S6.
## Decision: design/design-decisions.md DD-X18 (500 ms per planner run).
extends GdUnitTestSuite

const TARGET_MS: int = 500
const TARGET_USEC: int = 500_000
## boss-ai F7: nodes per run at bands 2 and 3 (`8·evals + lethal`).
const BAND_2_NODES: int = 1460
const BAND_3_NODES: int = 6000
const GATE_FACTOR: int = 2
const T_SIM_USEC: int = 400


func _profiles(runtime: Dictionary) -> Dictionary:
	return {"config": {"runtime": runtime}}


# --- S6: the planner target comes from the shipped data ---------------------------

func test_planner_target_read_from_runtime_planner_target_ms_is_in_usec() -> void:
	# Arrange — JSON numbers parse as floats
	var profiles: Dictionary = _profiles({"planner_target_ms": 500.0})

	# Act
	var target: int = PerfGate.planner_target_usec(profiles)

	# Assert
	assert_int(target).is_equal(TARGET_USEC)


func test_planner_target_ignores_the_registry_key_name() -> void:
	# Arrange — `ai_planner_target_ms` names the registry row, not the data key
	var profiles: Dictionary = _profiles({"ai_planner_target_ms": 500.0})

	# Act
	var target: int = PerfGate.planner_target_usec(profiles)

	# Assert
	assert_int(target).is_equal(PerfGate.NOT_SET)


func test_planner_target_is_not_set_when_the_data_does_not_carry_a_positive_number() -> void:
	# Arrange
	var cases: Array[Dictionary] = [
		{},
		{"config": {}},
		{"config": {"runtime": "worker"}},
		_profiles({}),
		_profiles({"planner_target_ms": null}),
		_profiles({"planner_target_ms": "500"}),
		_profiles({"planner_target_ms": true}),
		_profiles({"planner_target_ms": 0.0}),
		_profiles({"planner_target_ms": -500.0}),
	]

	# Act
	var targets: Array[int] = []
	for profiles: Dictionary in cases:
		targets.append(PerfGate.planner_target_usec(profiles))

	# Assert
	for target: int in targets:
		assert_int(target).is_equal(PerfGate.NOT_SET)


func test_planner_gate_is_the_factor_times_the_per_node_share_of_the_target() -> void:
	# Act
	var band_2: float = PerfGate.planner_gate_usec(TARGET_USEC, BAND_2_NODES, GATE_FACTOR)
	var band_3: float = PerfGate.planner_gate_usec(TARGET_USEC, BAND_3_NODES, GATE_FACTOR)

	# Assert — story 019 AC-4: 500 ms / 1,460 = 342.5 us; band 3 ≈ 83 us
	assert_float(band_2).is_equal_approx(684.93, 0.01)
	assert_float(band_3).is_equal_approx(166.67, 0.01)


func test_planner_band_line_states_the_per_run_target_and_names_its_source() -> void:
	# Act
	var line: String = PerfGate.planner_band_line("3", BAND_3_NODES, T_SIM_USEC, TARGET_USEC)

	# Assert
	assert_str(line).starts_with("PERF ")
	assert_str(line).contains("target %d ms per planner run" % TARGET_MS)
	assert_str(line).contains(PerfGate.PLANNER_TARGET_SOURCE)
	assert_str(line).contains("%d ms per planner run" % (BAND_3_NODES * T_SIM_USEC / PerfGate.USEC_PER_MS))
	assert_str(line).contains("nodes that fit %d" % (TARGET_USEC / T_SIM_USEC))
	assert_str(line).not_contains("per round")


func test_planner_band_line_without_a_target_still_reports_the_measured_run_time() -> void:
	# Act
	var line: String = PerfGate.planner_band_line("3", BAND_3_NODES, T_SIM_USEC, PerfGate.NOT_SET)

	# Assert
	assert_str(line).starts_with("PERF ")
	assert_str(line).contains("%d ms per planner run" % (BAND_3_NODES * T_SIM_USEC / PerfGate.USEC_PER_MS))
	assert_str(line).not_contains("nodes that fit")


func test_planner_gate_line_says_miss_only_at_or_above_the_gate() -> void:
	# Arrange
	var gate: float = PerfGate.planner_gate_usec(TARGET_USEC, BAND_3_NODES, GATE_FACTOR)

	# Act
	var over: String = PerfGate.planner_gate_line("3", T_SIM_USEC, TARGET_USEC, gate, "why")
	var under: String = PerfGate.planner_gate_line("3", 100, TARGET_USEC, gate, "why")

	# Assert
	assert_str(over).starts_with("PERF ")
	assert_str(over).contains("MISS (why)")
	assert_str(over).contains("target %d ms per planner run" % TARGET_MS)
	assert_str(under).contains("PASS")
	assert_str(under).not_contains("why")


func test_not_assessed_line_reaches_the_job_summary() -> void:
	# Act — the job copies `grep '^PERF '` to its summary
	var line: String = PerfGate.not_assessed("match_rules planner gate", "no target")

	# Assert
	assert_str(line).is_equal("PERF match_rules planner gate: NOT ASSESSED (no target)")
