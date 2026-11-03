## One named, seeded random stream (rng-event-log rules 4-6, F3, F4; ADR-0003
## Decision 1-2).
##
## Each stream owns one `RandomNumberGenerator` whose `seed` is set once in
## `_init`. `randi32()` is the only call that touches the generator, and every
## draw primitive is defined over it, so `draws` is exact and engine-independent:
## it is the number a snapshot records and a restore discards (F5, Story 003):
## [method restore] reseeds the generator and discards that many outputs —
## never by copying `RandomNumberGenerator.state` (ADR-0003 Decision 3).
##
## Construction: `RngService.stream(name)` builds streams for the rules
## (Story 002); tests construct one directly with a literal seed:
## [codeblock]
## var rng: RngStream = RngStream.new("match_1", 42)
## var roll: int = rng.randi_range(1, 6)         # 1 draw
## rng.shuffle(deck)                             # deck.size() - 1 draws
## var pick: int = rng.weighted_pick([5, 0, 15]) # 1 draw; index or -1
## var sim: RngStream = rng.fork("sim_3")        # "match_1/sim_3", 1 parent draw
## rng.restore(37)                               # reseed, discard 37; forks dropped
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
## For a fork, the parent's `draws` just before the one parent draw that
## seeded it (rule 5); -1 for a root stream. Set by the parent's [method fork];
## `RngService.snapshot()` records it so `restore()` can replay the fork call
## at the same parent position (F3 seed reproduced). Never written by callers.
## Example: a fork taken when its parent had drawn 5 has `forked_at == 5`.
var forked_at: int = -1

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## The F2/F3 seed the generator was seeded with; [method restore] reseeds it.
var _stream_seed: int = 0
## The [method fork] memo, `"<name>/<label>" → child`. [method restore] clears
## it, or a fork after restore would return the pre-restore child without
## taking its parent draw (code review 2026-11-03).
var _forks: Dictionary = {}


## Creates the stream `stream_name` seeded with `stream_seed` (an F2 or F3
## output, or any literal in tests). Takes no draw.
## Example: `var s: RngStream = RngStream.new("draft_1", 42)`.
func _init(stream_name: String, stream_seed: int) -> void:
	name = stream_name
	_stream_seed = stream_seed
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
## `RngService.fork_seed(parent_draw, name, label)`; later calls with the same
## label return the same object and consume nothing. Child draws never touch
## the parent's generator. `label` matches `[a-z0-9_]+` (F3): anything else — `""`,
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
	var parent_position: int = draws
	var child: RngStream = _make_child(child_name, RngService.fork_seed(randi32(), name, label))
	child.forked_at = parent_position
	_forks[child_name] = child
	return child


## F5: reseed the generator with this stream's seed and discard
## `target_draws` outputs, so the next output is the one the stream gave after
## that many draws on a fresh run; `draws == target_draws` afterwards. Clears
## the fork memo: a fork after restore takes its parent draw and is seeded from
## it, exactly as on a fresh run (ADR-0003 erratum 2026-11-03). O(target_draws);
## budget ≤ 5 ms at 10,000 (measured by the non-blocking perf suite, story 010).
## A negative `target_draws` is a caller bug: asserts (debug) or logs (release)
## and restores to 0. Called by `RngService.restore()`; rules code never calls it.
## Example: `stream.restore(37)`.
func restore(target_draws: int) -> void:
	if target_draws < 0:
		_reject("RngStream.restore: negative draws %d" % target_draws)
	_forks.clear()
	_rng.seed = _stream_seed
	draws = 0
	_skip_to(maxi(target_draws, 0))


## Discards outputs until `draws == target_draws` (no-op when already there or
## past it). The one forward skip, for `RngService.restore()` replaying a fork
## at its recorded parent position; rules code never calls it (a skip is a
## "free" draw — ADR-0003 Implementation Guidelines).
func _skip_to(target_draws: int) -> void:
	while draws < target_draws:
		@warning_ignore("return_value_discarded")
		randi32()


## Builds the child [method fork] memoises, seeded with its F3 seed. The one
## construction seam: a test double (`TestRngStream`) returns a child of its
## own kind here (scripted parents give scripted children).
func _make_child(child_name: String, child_seed: int) -> RngStream:
	return RngStream.new(child_name, child_seed)


## Whether `w` is a whole number: an `int`, or a finite `float` with no
## fractional part (JSON numbers arrive as floats).
static func _is_whole_number(w: Variant) -> bool:
	match typeof(w):
		TYPE_INT:
			return true
		TYPE_FLOAT:
			return is_finite(w) and w == floorf(w)
	return false


## Caller-bug report: asserts in debug builds (the assert aborts only this
## function, so the caller still returns its fallback), logs in release.
func _reject(message: String) -> void:
	assert(false, message)
	push_error(message)
