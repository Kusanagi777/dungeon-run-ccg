## Seeded-stream test double for RNG & Event Log (design/gdd/rng-event-log.md).
##
## Rules code receives randomness as an injected named stream (DD-T03) and
## never touches global RNG. Until the production RngService exists this
## double IS the stream a test hands to the code under test. It implements the
## GDD contract literally so draw counts are the GDD's draw counts:
##   - rule 4 / F4 draw API: `randi_range`, `randf`, `shuffle`, `weighted_pick`,
##     `fork`, every one defined over `randi32()` and advancing `draws`;
##   - F2 / F3 `stream_seed` and `fork_seed` (FNV-1a 64 + SplitMix64 finaliser),
##     pinned by the GDD's own example values in the self-test;
##   - F5 `restore(draws)`: reseed and discard.
## Three modes let a test pick what it needs:
##   - `seeded(name, seed)`     — deterministic sequence (match-rules AC-01);
##   - `scripted(name, values)` — `randi32()` returns the given values in order
##                                (wrapping), for algorithm traces (F4 example);
##   - `constant(name, value)`  — the "zero stub" of reward-draft AC-22.
## Every public call is recorded in `calls` so a test can assert "exactly three
## `shuffle` calls and no other draw" (run-structure AC-2).
##
## NOT SOURCEABLE: `RandomNumberGenerator` (`seed`, `randi()`) is not covered by
## `docs/engine-reference/godot/` (rng-event-log rule 6 says the same). The
## double depends only on "same seed, same sequence within one engine version",
## which the self-test verifies on the installed 4.7.2. Signed-int64 wraparound
## of the hash arithmetic is likewise unsourced and verified by the pinned
## example values.
##
## TODO(E1 story): swap the seeded mode to the production RngService stream once
## it exists; keep the scripted and constant modes as test doubles.
class_name TestRngStream
extends RefCounted

enum Mode { SEEDED, SCRIPTED, CONSTANT }

## rng-event-log rule 4: `hi - lo + 1 <= 65,536` (asserted in debug)
const MAX_RANGE_SPAN: int = 65536
## rng-event-log F2: FNV-1a 64 offset basis 0xCBF29CE484222325 as signed int64
const FNV_OFFSET_BASIS: int = -3750763034362895579
## rng-event-log F2: FNV-1a 64 prime 0x00000100000001B3
const FNV_PRIME: int = 1099511628211
## rng-event-log F2: SplitMix64 multiplier 0xBF58476D1CE4E5B9 as signed int64
const MIX_MULT_A: int = -4658895280553007687
## rng-event-log F2: SplitMix64 multiplier 0x94D049BB133111EB as signed int64
const MIX_MULT_B: int = -7723592293110705685
## rng-event-log rule 3 stream-name pattern
const STREAM_NAME_PATTERN: String = "^[a-z]+(_[0-9]+)?(/[a-z0-9_]+)*$"

## Stream name (rule 3), e.g. "run", "match_1", "ai_1/sim_3".
var name: String = ""
## Count of `randi32()` outputs consumed (rule 4; recorded by `snapshot()`).
var draws: int = 0
## Recorded public calls: `{method: String, args: Array}` in call order.
var calls: Array[Dictionary] = []
## The stream seed this instance was created with (seeded mode).
var stream_seed: int = 0

var _mode: Mode = Mode.SEEDED
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _script: Array[int] = []
var _script_index: int = 0
var _constant: int = 0
var _forks: Dictionary = {}


## A stream whose sequence is fixed by `seed_value` (F2 output, or any int).
static func seeded(stream_name: String, seed_value: int) -> TestRngStream:
	var stream: TestRngStream = TestRngStream.new()
	stream.name = stream_name
	stream.stream_seed = seed_value
	stream._mode = Mode.SEEDED
	stream._rng.seed = seed_value
	return stream


## A stream whose `randi32()` returns `values` in order, wrapping at the end.
static func scripted(stream_name: String, values: Array[int]) -> TestRngStream:
	var stream: TestRngStream = TestRngStream.new()
	stream.name = stream_name
	stream._mode = Mode.SCRIPTED
	stream._script = values.duplicate()
	return stream


## A stream whose `randi32()` always returns `value` (0 = reward-draft's zero stub).
static func constant(stream_name: String, value: int) -> TestRngStream:
	var stream: TestRngStream = TestRngStream.new()
	stream.name = stream_name
	stream._mode = Mode.CONSTANT
	stream._constant = value
	return stream


## One 32-bit generator output in [0, 2^32 - 1]; advances `draws` by 1 (F4).
func randi32() -> int:
	draws += 1
	match _mode:
		Mode.SEEDED:
			return _rng.randi()
		Mode.SCRIPTED:
			if _script.is_empty():
				return 0
			var value: int = _script[_script_index % _script.size()]
			_script_index += 1
			return value
		_:
			return _constant


## F4: `lo + (randi32() mod (hi - lo + 1))`, 1 draw. Edge case: `lo > hi` or a
## span above 65,536 is a caller bug — logged, `lo` returned, no draw taken.
func randi_range(lo: int, hi: int) -> int:
	_record("randi_range", [lo, hi])
	return _randi_range_unrecorded(lo, hi)


## F4: `randi32() / 2^32`, in [0, 1), 1 draw. Weight normalisation only.
func randf() -> float:
	_record("randf", [])
	return float(randi32()) / 4294967296.0


## F4 Fisher-Yates, in place, exactly `n - 1` draws (0 for 0 or 1 elements).
func shuffle(array: Array) -> void:
	_record("shuffle", [array.size()])
	for i: int in range(array.size() - 1, 0, -1):
		var j: int = _randi_range_unrecorded(0, i)
		var tmp: Variant = array[i]
		array[i] = array[j]
		array[j] = tmp


## F4: `r = randi_range(0, total - 1)`; smallest i with cumulative weight > r.
## 1 draw. Edge case: empty, negative weight, total 0 or > 65,536 → logged,
## returns -1 without a draw (rules never invent a fallback pick).
func weighted_pick(weights: Array) -> int:
	_record("weighted_pick", [weights.duplicate()])
	var total: int = 0
	for w: Variant in weights:
		if int(w) < 0:
			push_error("TestRngStream.weighted_pick: negative weight in %s" % str(weights))
			return -1
		total += int(w)
	if weights.is_empty() or total <= 0 or total > MAX_RANGE_SPAN:
		push_error("TestRngStream.weighted_pick: bad total %d for %s" % [total, str(weights)])
		return -1
	var r: int = _randi_range_unrecorded(0, total - 1)
	var cumulative: int = 0
	for i: int in range(weights.size()):
		cumulative += int(weights[i])
		if cumulative > r:
			return i
	return weights.size() - 1


## Rule 5 / F3: a memoised child stream named `<name>/<label>`. The first call
## consumes one parent draw; later calls with the same label return the same
## object and consume nothing. Scripted and constant parents produce a child in
## the same mode.
func fork(label: String) -> TestRngStream:
	_record("fork", [label])
	if _forks.has(label):
		return _forks[label]
	var child_name: String = "%s/%s" % [name, label]
	var parent_draw: int = randi32()
	var child: TestRngStream
	match _mode:
		Mode.SEEDED:
			child = TestRngStream.seeded(child_name, fork_seed(parent_draw, name, label))
		Mode.SCRIPTED:
			child = TestRngStream.scripted(child_name, _script)
		_:
			child = TestRngStream.constant(child_name, _constant)
	_forks[label] = child
	return child


## F5: reseed and discard `target_draws` outputs so the next output equals the
## original stream's next output after that many draws. Clears recorded calls.
func restore(target_draws: int) -> void:
	calls.clear()
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


# --- F1 / F2 / F3 seed arithmetic (static, pure) ------------------------------

## F1 deterministic branches of `run_seed` from the seed field. Hex (16 digits,
## optional 0x) parses as unsigned bits; a decimal (optionally negative) parses
## mod 2^64; anything else is `fnv1a64(utf8(input))`. The empty-input entropy
## branch is out of scope for a deterministic double and yields 0.
static func run_seed_from_input(input: String) -> int:
	var trimmed: String = input.strip_edges()
	if trimmed.is_empty():
		return 0
	var hex: RegEx = RegEx.create_from_string("^(0x)?[0-9A-Fa-f]{16}$")
	if hex.search(trimmed) != null:
		return parse_hex_u64(trimmed.trim_prefix("0x").trim_prefix("0X"))
	var dec: RegEx = RegEx.create_from_string("^-?[0-9]{1,19}$")
	if dec.search(trimmed) != null:
		return int(trimmed)
	return fnv1a64(trimmed.to_utf8_buffer())


## F2: `mix64(fnv1a64(le_bytes8(run_seed) ++ utf8(name)))`.
static func stream_seed_for(run_seed: int, stream_name: String) -> int:
	var bytes: PackedByteArray = le_bytes8(run_seed)
	bytes.append_array(stream_name.to_utf8_buffer())
	return mix64(fnv1a64(bytes))


## F3: `mix64(fnv1a64(le_bytes8(parent_draw) ++ utf8(parent_name + "/" + label)))`.
static func fork_seed(parent_draw: int, parent_name: String, label: String) -> int:
	var bytes: PackedByteArray = le_bytes8(parent_draw)
	bytes.append_array(("%s/%s" % [parent_name, label]).to_utf8_buffer())
	return mix64(fnv1a64(bytes))


## FNV-1a 64 over `bytes`, int64 wraparound arithmetic.
static func fnv1a64(bytes: PackedByteArray) -> int:
	var h: int = FNV_OFFSET_BASIS
	for b: int in bytes:
		h = (h ^ b) * FNV_PRIME
	return h


## SplitMix64 finaliser (F2 `mix64`); `>>>` emulated as a logical shift.
static func mix64(x: int) -> int:
	var z: int = (x ^ ushr64(x, 30)) * MIX_MULT_A
	z = (z ^ ushr64(z, 27)) * MIX_MULT_B
	return z ^ ushr64(z, 31)


## Logical (unsigned) right shift of a signed int64 by `n` in 1..63.
static func ushr64(x: int, n: int) -> int:
	return (x >> n) & ((1 << (64 - n)) - 1)


## The 8 little-endian bytes of an int64 (F2 `le_bytes8`).
static func le_bytes8(value: int) -> PackedByteArray:
	var bytes: PackedByteArray = PackedByteArray()
	for i: int in range(8):
		bytes.append((value >> (8 * i)) & 0xFF)
	return bytes


## Parse exactly 16 hex digits as the unsigned 64-bit pattern, stored signed.
static func parse_hex_u64(hex16: String) -> int:
	var value: int = 0
	for ch: String in hex16:
		value = (value << 4) | ("0123456789abcdef".find(ch.to_lower()))
	return value


## 16 uppercase hex digits, unsigned view of the bits (DD-R09 display form;
## rng-event-log F1 examples: 42 → 000000000000002A, -1 → FFFFFFFFFFFFFFFF).
static func to_hex_u64(value: int) -> String:
	var out: String = ""
	for i: int in range(15, -1, -1):
		out += "0123456789ABCDEF"[(value >> (4 * i)) & 0xF]
	return out


## True when `stream_name` matches rng-event-log rule 3.
static func is_valid_stream_name(stream_name: String) -> bool:
	return RegEx.create_from_string(STREAM_NAME_PATTERN).search(stream_name) != null


func _randi_range_unrecorded(lo: int, hi: int) -> int:
	if lo > hi or (hi - lo + 1) > MAX_RANGE_SPAN:
		push_error("TestRngStream.randi_range: bad range [%d, %d]" % [lo, hi])
		return lo
	return lo + (randi32() % (hi - lo + 1))


func _record(method: String, args: Array) -> void:
	calls.append({"method": method, "args": args})
