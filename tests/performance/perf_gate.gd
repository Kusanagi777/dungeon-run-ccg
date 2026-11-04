## Shared by the suites under `tests/performance/`: the `PERF` lines the
## `performance` job copies to its summary (`grep '^PERF '`) and the planner
## gate's arithmetic. Static functions behind a `class_name`, as
## `MatchBudgetFixtures` is: a suite that held this script in a constant or as
## its base would own it (TD-013, `boot_script_teardown_test.gd`).
##
## The deterministic checks are `tests/performance/perf_gate_harness_test.gd`.
class_name PerfGate
extends RefCounted

## [method planner_target_usec] when the data carries no usable target.
const NOT_SET: int = -1
const USEC_PER_MS: int = 1000
## The data key. The registry row for the same value is `ai_planner_target_ms`
## in `design/registry/entities.yaml`, which a Godot test does not parse.
const PLANNER_TARGET_KEY: String = "planner_target_ms"
const PLANNER_TARGET_SOURCE: String = "ai_profiles.json runtime.planner_target_ms"


## A gate that produced no verdict, in the form the job summary keeps.
static func not_assessed(what: String, reason: String) -> String:
	return "PERF %s: NOT ASSESSED (%s)" % [what, reason]


## The per-run planner target in µs from a parsed `ai_profiles.json`, or
## [constant NOT_SET] when the file does not carry a positive number. There is
## no fallback value: a target the data does not state is not assessed.
static func planner_target_usec(profiles: Dictionary) -> int:
	var config: Variant = profiles.get("config")
	if not config is Dictionary:
		return NOT_SET
	var runtime: Variant = (config as Dictionary).get("runtime")
	if not runtime is Dictionary:
		return NOT_SET
	var value: Variant = (runtime as Dictionary).get(PLANNER_TARGET_KEY)
	if not (value is int or value is float) or float(value) <= 0.0:
		return NOT_SET
	return int(value) * USEC_PER_MS


## [param factor] × the share of [param target_usec] one of [param nodes] gets.
static func planner_gate_usec(target_usec: int, nodes: int, factor: int) -> float:
	return float(target_usec) / nodes * factor


## One band's F7 run time at the measured [param t_sim]. Without a target it
## still states the measurement.
static func planner_band_line(band: String, nodes: int, t_sim: int, target_usec: int) -> String:
	var line: String = "PERF match_rules planner band %s: F7 nodes %d x t_sim %d us = %d ms per planner run" % [
		band, nodes, t_sim, nodes * t_sim / USEC_PER_MS]
	if target_usec == NOT_SET:
		return line
	return "%s (target %d ms per planner run, %s); nodes that fit %d" % [
		line, target_usec / USEC_PER_MS, PLANNER_TARGET_SOURCE, target_usec / maxi(1, t_sim)]


## The gate's verdict. [param miss_note] says why a miss is expected, if it is.
static func planner_gate_line(band: String, t_sim: int, target_usec: int, gate_usec: float, miss_note: String) -> String:
	var verdict: String = "PASS" if t_sim < gate_usec else "MISS (%s)" % miss_note
	return "PERF match_rules planner gate band %s: node median %d us, gate %.1f us (target %d ms per planner run, %s): %s" % [
		band, t_sim, gate_usec, target_usec / USEC_PER_MS, PLANNER_TARGET_SOURCE, verdict]
