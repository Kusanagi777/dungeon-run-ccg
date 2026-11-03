## Stream test double for RNG & Event Log (design/gdd/rng-event-log.md).
##
## Rules code receives randomness as an injected named stream (DD-T03) and
## never touches global RNG. This double **is** a production [RngStream]
## (`extends RngStream`, ADR-0003 Migration Plan step 2: the `TODO(E1)` swap
## is a type change, not a rename), so it fits wherever rules code takes an
## `RngStream`. Every draw primitive, the draw counts, the fork rule (label
## check, one parent draw, memoised `"<name>/<label>"`, F3 seed via
## `RngService.fork_seed`) and the caller-bug handling (assert in debug) are
## the production code. What the double adds:
##   - three modes:
##     - `seeded(name, seed)`     — the production generator, seeded once
##                                  (match-rules AC-01);
##     - `scripted(name, values)` — `randi32()` returns the given values in
##                                  order (wrapping), for algorithm traces (F4);
##     - `constant(name, value)`  — the "zero stub" of reward-draft AC-22;
##     a fork of a scripted or constant stream is a stream of the same mode;
##   - `calls`: every public draw call (`randi_range`, `randf`, `shuffle`,
##     `weighted_pick`, `fork`) recorded once, so a test can assert "exactly
##     three `shuffle` calls and no other draw" (run-structure AC-2); calls a
##     primitive makes internally (`shuffle` → `randi_range`) are not recorded;
##   - `restore(draws)`: F5 reseed-and-discard on this stream (the production
##     service-level `snapshot()` / `restore()` are rng-event-log story 003);
##   - the F1/F2/F3 statics under their old names, delegating to
##     [RngService] (the GDD example pins live in
##     `tests/unit/rng_event_log/rng_service_test.gd`).
##
## NOT SOURCEABLE: `RandomNumberGenerator` is not covered by
## `docs/engine-reference/godot/`; the production stream is pinned on the
## installed 4.7.2 by `tests/unit/rng_event_log/rng_engine_pins_test.gd`.
class_name TestRngStream
extends RngStream

enum Mode { SEEDED, SCRIPTED, CONSTANT }

## rng-event-log rule 3 stream-name pattern (the production constant).
const STREAM_NAME_PATTERN: String = RngService.STREAM_NAME_PATTERN

## Recorded public calls: `{method: String, args: Array}` in call order.
var calls: Array[Dictionary] = []
## The stream seed this instance was created with (seeded mode).
var stream_seed: int = 0

var _mode: Mode = Mode.SEEDED
var _script: Array[int] = []
var _script_index: int = 0
var _constant: int = 0
# >0 while a recorded call runs, so its internal draw calls are not recorded.
var _depth: int = 0


## A seeded stream; prefer [method seeded], [method scripted] or [method constant].
func _init(stream_name: String = "", seed_value: int = 0) -> void:
	super(stream_name, seed_value)
	stream_seed = seed_value


## A stream whose sequence is fixed by `seed_value` (F2 output, or any int):
## the production generator. Example: `TestRngStream.seeded("match_1", 42)`.
static func seeded(stream_name: String, seed_value: int) -> TestRngStream:
	return TestRngStream.new(stream_name, seed_value)


## A stream whose `randi32()` returns `values` in order, wrapping at the end
## (0 forever when `values` is empty). Example: `TestRngStream.scripted("match_1", [1, 0, 1])`.
static func scripted(stream_name: String, values: Array[int]) -> TestRngStream:
	var stream: TestRngStream = TestRngStream.new(stream_name)
	stream._mode = Mode.SCRIPTED
	stream._script = values.duplicate()
	return stream


## A stream whose `randi32()` always returns `value` (0 = reward-draft's zero
## stub). Example: `TestRngStream.constant("draft_1", 0)`.
static func constant(stream_name: String, value: int) -> TestRngStream:
	var stream: TestRngStream = TestRngStream.new(stream_name)
	stream._mode = Mode.CONSTANT
	stream._constant = value
	return stream


## F4 primitive: the production generator output in seeded mode, else the
## next scripted value or the constant; `draws` rises by 1 in every mode.
func randi32() -> int:
	match _mode:
		Mode.SCRIPTED:
			draws += 1
			if _script.is_empty():
				return 0
			var value: int = _script[_script_index % _script.size()]
			_script_index += 1
			return value
		Mode.CONSTANT:
			draws += 1
			return _constant
	return super()


## Production `randi_range`, recorded.
func randi_range(lo: int, hi: int) -> int:
	_record("randi_range", [lo, hi])
	_depth += 1
	var value: int = super(lo, hi)
	_depth -= 1
	return value


## Production `randf`, recorded.
func randf() -> float:
	_record("randf", [])
	_depth += 1
	var value: float = super()
	_depth -= 1
	return value


## Production `shuffle`, recorded once with the array size.
func shuffle(array: Array) -> void:
	_record("shuffle", [array.size()])
	_depth += 1
	super(array)
	_depth -= 1


## Production `weighted_pick`, recorded with a copy of the weights.
func weighted_pick(weights: Array) -> int:
	_record("weighted_pick", [weights.duplicate()])
	_depth += 1
	var index: int = super(weights)
	_depth -= 1
	return index


## Production `fork` (rule 5 / F3), recorded; the child is a `TestRngStream`
## of this stream's mode. `null` for a bad label (assert in debug).
func fork(label: String) -> TestRngStream:
	_record("fork", [label])
	_depth += 1
	var child: TestRngStream = super(label)
	_depth -= 1
	return child


## F5: reseed and discard `target_draws` outputs so the next output equals the
## original stream's next output after that many draws. Clears recorded calls
## and the fork memo: a fork after restore consumes its parent draw and is
## seeded from it, as on a fresh run (code review 2026-11-03).
## Example: `stream.restore(37)`.
func restore(target_draws: int) -> void:
	calls.clear()
	_forks.clear()
	draws = 0
	_script_index = 0
	if _mode == Mode.SEEDED:
		_rng.seed = stream_seed
	for _i: int in range(target_draws):
		@warning_ignore("return_value_discarded")
		randi32()


## Number of recorded calls to `method` (e.g. "shuffle").
func count_calls(method: String) -> int:
	var n: int = 0
	for call: Dictionary in calls:
		if call.method == method:
			n += 1
	return n


# --- F1 / F2 / F3 seed arithmetic: delegates to RngService ---------------------

## F1 deterministic branches (RngService.run_seed_from_input); the empty-input
## entropy branch is out of scope for a deterministic double and yields 0.
static func run_seed_from_input(input: String) -> int:
	return RngService.run_seed_from_input(input, func() -> int: return 0)


## F2 (RngService.stream_seed_for).
static func stream_seed_for(run_seed: int, stream_name: String) -> int:
	return RngService.stream_seed_for(run_seed, stream_name)


## F3 (RngService.fork_seed).
static func fork_seed(parent_draw: int, parent_name: String, label: String) -> int:
	return RngService.fork_seed(parent_draw, parent_name, label)


## FNV-1a 64 (RngService.fnv1a64).
static func fnv1a64(bytes: PackedByteArray) -> int:
	return RngService.fnv1a64(bytes)


## SplitMix64 finaliser (RngService.mix64).
static func mix64(x: int) -> int:
	return RngService.mix64(x)


## Logical right shift (RngService.ushr64).
static func ushr64(x: int, n: int) -> int:
	return RngService.ushr64(x, n)


## The 8 little-endian bytes of an int64 (RngService.le_bytes8).
static func le_bytes8(value: int) -> PackedByteArray:
	return RngService.le_bytes8(value)


## 16 hex digits → the 64-bit pattern (RngService.parse_hex_u64).
static func parse_hex_u64(hex16: String) -> int:
	return RngService.parse_hex_u64(hex16)


## The 16-uppercase-hex-digit form (RngService.to_hex_u64).
static func to_hex_u64(value: int) -> String:
	return RngService.to_hex_u64(value)


## True when `stream_name` matches rng-event-log rule 3 (RngService.is_valid_stream_name).
static func is_valid_stream_name(stream_name: String) -> bool:
	return RngService.is_valid_stream_name(stream_name)


## The fork child, in this stream's mode (the production construction seam).
func _make_child(child_name: String, child_seed: int) -> RngStream:
	match _mode:
		Mode.SCRIPTED:
			return TestRngStream.scripted(child_name, _script)
		Mode.CONSTANT:
			return TestRngStream.constant(child_name, _constant)
	return TestRngStream.seeded(child_name, child_seed)


func _record(method: String, args: Array) -> void:
	if _depth == 0:
		calls.append({"method": method, "args": args})
