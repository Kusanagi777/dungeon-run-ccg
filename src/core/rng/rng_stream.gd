## One named, seeded random stream (rng-event-log rules 4-6, F3, F4; ADR-0003
## Decision 1-2).
##
## Each stream owns one `RandomNumberGenerator` whose `seed` is set once in
## `_init`. `randi32()` is the only call that touches the generator, and every
## draw primitive is defined over it, so `draws` is exact and engine-independent:
## it is the number a snapshot records and a restore discards (F5, Story 003).
##
## Construction: `RngService.stream(name)` builds streams for the rules
## (Story 002); tests construct one directly with a literal seed:
## [codeblock]
## var rng: RngStream = RngStream.new("match_1", 42)
## var roll: int = rng.randi_range(1, 6)         # 1 draw
## rng.shuffle(deck)                             # deck.size() - 1 draws
## var pick: int = rng.weighted_pick([5, 0, 15]) # 1 draw; index or -1
## var sim: RngStream = rng.fork("sim_3")        # "match_1/sim_3", 1 parent draw
## [/codeblock]
##
## Invalid input (a bad range, bad weights, a bad fork label) is a caller bug:
## it asserts in debug builds and in release logs an error and returns the
## documented fallback without consuming a draw — never a silently corrected
## value.
##
## Single-thread-only: a stream is not locked. A worker thread uses its own
## fork or a cloned engine's streams, never a live stream (ADR-0006/0008).
##
## NOT SOURCEABLE: `RandomNumberGenerator`, its `seed` setter and `randi()`
## range, and signed-int64 wraparound have no page in
## `docs/engine-reference/godot/`; they are pinned on the installed engine by
## `tests/unit/rng_event_log/rng_engine_pins_test.gd` (ADR-0003 probe D).
class_name RngStream
extends RefCounted

## rng-event-log F4: largest `randi_range` span and `weighted_pick` total
## (modulo bias < 2^-16). A formula constant, not a tuning knob (GDD Tuning Knobs).
const MAX_RANGE_SPAN: int = 65536
## rng-event-log F2: FNV-1a 64 offset basis 0xCBF29CE484222325 as signed int64.
const FNV_OFFSET_BASIS: int = -3750763034362895579
## rng-event-log F2: FNV-1a 64 prime 0x00000100000001B3.
const FNV_PRIME: int = 1099511628211
## rng-event-log F2: SplitMix64 multiplier 0xBF58476D1CE4E5B9 as signed int64.
const MIX_MULT_A: int = -4658895280553007687
## rng-event-log F2: SplitMix64 multiplier 0x94D049BB133111EB as signed int64.
const MIX_MULT_B: int = -7723592293110705685
## `randf()` divisor, 2^32 (F4).
const _TWO_POW_32: float = 4294967296.0
## rng-event-log F3 variable table: a fork label is `[a-z0-9_]+`.
const _LABEL_PATTERN: String = "^[a-z0-9_]+$"

## [constant _LABEL_PATTERN], compiled once for every stream.
static var _label_regex: RegEx = RegEx.create_from_string(_LABEL_PATTERN)

## Stream name (rule 3), e.g. `"run"`, `"match_1"`, `"ai_1/sim_3"`.
## Example: `RngStream.new("run", 42).name == "run"`.
var name: String = ""
## Count of `randi32()` outputs consumed so far (rule 4). Never written by
## callers. Example: after `shuffle([a, b, c])`, `draws` has risen by 2.
var draws: int = 0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _forks: Dictionary = {}


## Creates the stream `stream_name` seeded with `stream_seed` (an F2 or F3
## output, or any literal in tests). Takes no draw.
## Example: `var s: RngStream = RngStream.new("draft_1", 42)`.
func _init(stream_name: String, stream_seed: int) -> void:
	name = stream_name
	_rng.seed = stream_seed


## The F4 primitive: one 32-bit generator output in [0, 2^32 - 1]; `draws`
## rises by 1. NOT for rules code — rules use the primitives below (lint-gated
## outside `src/core/rng/` by Story 004).
## Example: `var bits: int = stream.randi32()`.
func randi32() -> int:
	draws += 1
	return _rng.randi()


## F4: `lo + (randi32() mod (hi - lo + 1))`, inclusive, 1 draw. Requires
## `lo <= hi` and a span of at most 65,536; otherwise asserts (debug) or logs
## and returns `lo` with no draw (release).
## Example: `var damage: int = stream.randi_range(1, 3)`.
func randi_range(lo: int, hi: int) -> int:
	# hi - lo < 0 with lo <= hi means the span overflowed int64.
	if lo > hi or hi - lo < 0 or hi - lo >= MAX_RANGE_SPAN:
		_reject("RngStream.randi_range: bad range [%d, %d]" % [lo, hi])
		return lo
	return lo + (randi32() % (hi - lo + 1))


## F4: `randi32() / 2^32`, in [0, 1), 1 draw. For weight normalisation only —
## rules never compare floats for equality (rule 4).
## Example: `var share: float = stream.randf()`.
func randf() -> float:
	return float(randi32()) / _TWO_POW_32


## F4 Fisher-Yates, in place: for `i = n - 1` down to 1, `j = randi_range(0, i)`,
## swap `array[i]` and `array[j]`. Exactly `n - 1` draws; 0 for 0 or 1 elements.
## Example: `stream.shuffle(deck)` on a 30-card deck takes 29 draws.
func shuffle(array: Array) -> void:
	for i: int in range(array.size() - 1, 0, -1):
		# `self.` is load-bearing: a bare `randi_range(...)` resolves to the
		# @GlobalScope utility (the global RNG, no draw counted) on 4.7.2.
		var j: int = self.randi_range(0, i)
		var tmp: Variant = array[i]
		array[i] = array[j]
		array[j] = tmp


## F4: `total = sum(weights)`, `r = randi_range(0, total - 1)`, returns the
## smallest index whose cumulative weight exceeds `r`; 1 draw. Weights are
## integers (integral floats from JSON are accepted). An empty array, a weight
## that is not an `int` or a whole `float` (`2.5`, `"5"`, `true`), a negative
## weight, or a total of 0 or above 65,536 asserts (debug) or logs and returns
## -1 with no draw (release); callers never invent a fallback pick.
## Example: `stream.weighted_pick([5, 0, 15])` returns 0 or 2, never 1.
func weighted_pick(weights: Array) -> int:
	var total: int = 0
	for w: Variant in weights:
		if not _is_whole_number(w):
			total = -1
			break
		var weight: int = int(w)
		# A single weight above the cap already fails the total; checking it
		# here keeps the running sum far from int64 overflow.
		if weight < 0 or weight > MAX_RANGE_SPAN:
			total = -1
			break
		total += weight
	if total <= 0 or total > MAX_RANGE_SPAN:
		_reject("RngStream.weighted_pick: bad weights %s" % str(weights))
		return -1
	var r: int = self.randi_range(0, total - 1)  # `self.`: see shuffle()
	var cumulative: int = 0
	for i: int in range(weights.size()):
		cumulative += int(weights[i])
		if cumulative > r:
			return i
	return weights.size() - 1


## Rule 5 / F3: the child stream `"<name>/<label>"`. The first call with a
## label consumes one parent draw and seeds the child with
## `fork_seed(parent_draw, name, label)`; later calls with the same label
## return the same object and consume nothing. Child draws never touch the
## parent's generator. `label` matches `[a-z0-9_]+` (F3): anything else — `""`,
## `"a/b"` (whose name would collide with `fork("a").fork("b")` under a
## different seed), upper case, `-` — asserts (debug) or logs and returns
## `null` with no draw (release).
## Example: `var sim: RngStream = ai_stream.fork("sim_3")` → `"ai_1/sim_3"`.
func fork(label: String) -> RngStream:
	var found: RegExMatch = _label_regex.search(label)
	# Whole-string match: PCRE's `$` also matches before a trailing newline.
	if found == null or found.get_string() != label:
		_reject("RngStream.fork: bad label \"%s\"" % label.c_escape())
		return null
	var child_name: String = "%s/%s" % [name, label]
	if _forks.has(child_name):
		return _forks[child_name]
	var child: RngStream = RngStream.new(child_name, _fork_seed(randi32(), name, label))
	_forks[child_name] = child
	return child


## Whether `w` is a whole number: an `int`, or a finite `float` with no
## fractional part (JSON numbers arrive as floats).
static func _is_whole_number(w: Variant) -> bool:
	match typeof(w):
		TYPE_INT:
			return true
		TYPE_FLOAT:
			return is_finite(w) and w == floorf(w)
	return false


# --- F3 seed arithmetic --------------------------------------------------------
# TODO(rng-event-log story-002): the public static derivation moves to
# RngService (fork_seed, stream_seed_for); call it from fork() then. Signed
# int64 arithmetic with `>>>` emulated, exactly as TestRngStream.

## F3: `mix64(fnv1a64(le_bytes8(parent_draw) ++ utf8(parent_name + "/" + label)))`.
static func _fork_seed(parent_draw: int, parent_name: String, label: String) -> int:
	var bytes: PackedByteArray = PackedByteArray()
	for i: int in range(8):
		bytes.append((parent_draw >> (8 * i)) & 0xFF)
	bytes.append_array(("%s/%s" % [parent_name, label]).to_utf8_buffer())
	return _mix64(_fnv1a64(bytes))


## FNV-1a 64 over `bytes`, int64 wraparound arithmetic (F2).
static func _fnv1a64(bytes: PackedByteArray) -> int:
	var h: int = FNV_OFFSET_BASIS
	for b: int in bytes:
		h = (h ^ b) * FNV_PRIME
	return h


## SplitMix64 finaliser (F2 `mix64`).
static func _mix64(x: int) -> int:
	var z: int = (x ^ _ushr64(x, 30)) * MIX_MULT_A
	z = (z ^ _ushr64(z, 27)) * MIX_MULT_B
	return z ^ _ushr64(z, 31)


## Logical (unsigned) right shift of a signed int64 by `n` in 1..63.
static func _ushr64(x: int, n: int) -> int:
	return (x >> n) & ((1 << (64 - n)) - 1)


## Caller-bug report: asserts in debug builds (the assert aborts only this
## function, so the caller still returns its fallback), logs in release.
func _reject(message: String) -> void:
	assert(false, message)
	push_error(message)
