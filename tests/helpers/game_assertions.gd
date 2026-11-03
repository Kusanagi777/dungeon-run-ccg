## Game-specific assertion utilities for Dungeon Run CCG tests.
##
## Domain assertions built on gdUnit4's own assertion API, so a failing helper
## registers ONE red test and the suite continues (never a bare `assert()`,
## which halts the run and is stripped in release builds).
##
## Framework assertion form, resolved from the installed addon source rather
## than guessed (gdUnit4 6.2.3, `addons/gdUnit4/src/GdUnitTestSuite.gd`):
##   - `GdUnitTestSuite.assert_bool(current)` is a `static func` (line 651), so a
##     plain RefCounted helper can call it without a suite instance;
##   - `.override_failure_message(msg)` and `.is_false()` are on the returned
##     `GdUnitBoolAssert` (`src/asserts/GdUnitBoolAssertImpl.gd` lines 38, 80).
## That pair is the one failure call every helper below funnels through
## (`fail_if`). gdUnit4's API is not covered by `docs/engine-reference/`.
##
## This is a plain class — it must never extend GdUnitTestSuite, or the runner
## would discover it as a suite with zero tests.
##
## Usage (static — no instance needed):
##   GameAssertions.assert_in_range(health, 0, max_health, "health")
class_name GameAssertions
extends RefCounted


## The single framework failure call. Registers a failure with the runner when
## `condition` is true and lets the test continue; records a success otherwise
## (so `assert_failure(func(): ...)` can verify either outcome).
static func fail_if(condition: bool, message: String) -> void:
	@warning_ignore("return_value_discarded")
	GdUnitTestSuite.assert_bool(condition).override_failure_message(message).is_false()


## Assert a value is within the inclusive range [min_val, max_val].
## Use for any formula output that has defined bounds in a GDD Formulas table.
static func assert_in_range(value: float, min_val: float, max_val: float, label: String = "value") -> void:
	fail_if(
		not (value >= min_val and value <= max_val),
		"%s %s is outside expected range [%s, %s]" % [label, str(value), str(min_val), str(max_val)]
	)


## Assert a signal was emitted during a callable block.
## Usage: GameAssertions.assert_signal_emitted(engine, "match_ended", func(): engine.submit(cmd))
static func assert_signal_emitted(obj: Object, signal_name: String, action: Callable) -> void:
	var state: Dictionary = _run_and_watch(obj, signal_name, action)
	fail_if(not state.emitted, "Expected signal '%s' to be emitted, but it was not." % signal_name)


## Assert that a callable block does NOT emit a signal.
static func assert_signal_not_emitted(obj: Object, signal_name: String, action: Callable) -> void:
	var state: Dictionary = _run_and_watch(obj, signal_name, action)
	fail_if(state.emitted, "Expected signal '%s' NOT to be emitted, but it was." % signal_name)


## Assert a node exists at `path` under `parent` (scene/integration tests only;
## the rules layer has no Nodes, DD-T02).
static func assert_node_exists(parent: Node, path: NodePath) -> void:
	fail_if(not parent.has_node(path), "Expected node at path '%s' to exist." % str(path))


## Assert a value is JSON-representable per rng-event-log rule 14: int, float,
## bool, String, StringName, null, or Array/Dictionary of those. Every event
## payload and every RunState field must pass this.
static func assert_json_representable(value: Variant, label: String = "value") -> void:
	var offender: Array = []
	fail_if(
		not is_json_representable(value, offender),
		"%s holds a non-JSON value (%s) at %s" % [label, offender[1] if offender.size() > 1 else "?", offender[0] if offender.size() > 0 else "root"]
	)


## True when `value` is JSON-representable (rng-event-log rule 14). When a
## non-empty `offender` Array is passed it receives [path, type_name] of the
## first offending value, for the failure message.
static func is_json_representable(value: Variant, offender: Array = [], path: String = "root") -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME:
			return true
		TYPE_ARRAY:
			var index: int = 0
			for item: Variant in value:
				if not is_json_representable(item, offender, "%s[%d]" % [path, index]):
					return false
				index += 1
			return true
		TYPE_DICTIONARY:
			for key: Variant in value:
				if typeof(key) != TYPE_STRING and typeof(key) != TYPE_STRING_NAME:
					offender.assign([path, "non-string key %s" % type_string(typeof(key))])
					return false
				if not is_json_representable(value[key], offender, "%s.%s" % [path, str(key)]):
					return false
			return true
		_:
			offender.assign([path, type_string(typeof(value))])
			return false


## Assert an Array is strictly ascending (ids sorted, no duplicates) — Card
## Database CR-6 query order and reward-draft D6/D7 `option_ids` sorting.
static func assert_sorted_ascending(items: Array, label: String = "list") -> void:
	for i: int in range(1, items.size()):
		if not (items[i - 1] < items[i]):
			fail_if(true, "%s is not strictly ascending at index %d: %s >= %s" % [label, i, str(items[i - 1]), str(items[i])])
			return
	fail_if(false, "")


## Assert an Array holds no duplicate entries (DD-R05 no-duplicate offers,
## DD-R02 distinct bosses per band).
static func assert_no_duplicates(items: Array, label: String = "list") -> void:
	var seen: Dictionary = {}
	for item: Variant in items:
		if seen.has(item):
			fail_if(true, "%s holds a duplicate entry: %s" % [label, str(item)])
			return
		seen[item] = true
	fail_if(false, "")


## Assert a Dictionary carries every key in `keys` — shape checks on data
## models and event payloads (match-rules AC-42, card-effects AC-39).
static func assert_has_keys(dict: Dictionary, keys: Array, label: String = "dictionary") -> void:
	var missing: Array = []
	for key: Variant in keys:
		if not dict.has(key):
			missing.append(key)
	fail_if(not missing.is_empty(), "%s is missing keys %s" % [label, str(missing)])


## Connect a throw-away listener, run `action`, disconnect, and report whether
## the signal fired. A lambda captures locals by value, so the flag lives in a
## shared Dictionary; `...args` accepts any signal arity (4.5+ rest parameter,
## docs/engine-reference/godot/current-best-practices.md "GDScript (4.5+)").
static func _run_and_watch(obj: Object, signal_name: String, action: Callable) -> Dictionary:
	var state: Dictionary = {"emitted": false}
	var listener: Callable = func(...args: Array) -> void:
		state.emitted = true
	var sig: Signal = Signal(obj, signal_name)
	sig.connect(listener)
	action.call()
	if sig.is_connected(listener):
		sig.disconnect(listener)
	return state
