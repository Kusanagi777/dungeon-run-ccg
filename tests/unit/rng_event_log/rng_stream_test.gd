## RngStream — F4 draw primitives, exact draw counts and memoised forks.
##
## Story: production/epics/rng-event-log/story-001-rng-stream-engine-pin-and-draw-primitives.md
## GDD: design/gdd/rng-event-log.md rules 4-6, F3, F4, Edge Cases (Streams).
## ADR-0003 Decision 1-2. Every stream here is built with a literal seed
## (determinism contract, ADR-0003 Decision 10a); no wall clock, no file I/O.
##
## Invalid inputs assert in debug builds and return the release fallback with
## no draw. The test runner is a debug build, so `_assert_rejected` expects the
## assert there and the `push_error` in a release build; the return value and
## `draws` are checked in both.
extends GdUnitTestSuite

## Seed used by every seeded stream in this suite (the golden-pin seed).
const SEED: int = 42
## rng-event-log F4: largest `randi_range` span / `weighted_pick` total.
const MAX_SPAN: int = 65536
## 2^32, the `randf` divisor (F4).
const TWO_POW_32: float = 4294967296.0
## AC: distribution sample size for `weighted_pick([5, 0, 15])`.
const DISTRIBUTION_DRAWS: int = 10000
## AC: accepted count band for index 2 (expected 7,500 = 15/20 of 10,000).
const INDEX_2_MIN: int = 7200
const INDEX_2_MAX: int = 7800


## RngStream whose `randi32()` returns scripted values in order (F4 example
## trace). Overrides the one generator call; every primitive still goes
## through it, so `draws` is the production count.
class ScriptedRngStream extends RngStream:
	var _values: Array[int] = []
	var _index: int = 0

	func _init(stream_name: String, values: Array[int]) -> void:
		super(stream_name, 0)
		_values = values

	func randi32() -> int:
		draws += 1
		var value: int = _values[_index % _values.size()]
		_index += 1
		return value


func _seeded(stream_name: String = "run") -> RngStream:
	return RngStream.new(stream_name, SEED)


func _raw_generator(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## Runs `call` and asserts it was rejected with `message`: an assert in a debug
## build, a push_error in release.
func _assert_rejected(call: Callable, message: String) -> void:
	if OS.is_debug_build():
		await assert_error(call).is_runtime_error("Assertion failed: " + message)
	else:
		await assert_error(call).is_push_error(message)


# --- construction and randi32 -------------------------------------------------

func test_init_sets_name_and_takes_no_draw() -> void:
	# Arrange / Act
	var stream: RngStream = _seeded("match_1")

	# Assert
	assert_str(stream.name).is_equal("match_1")
	assert_int(stream.draws).is_equal(0)


func test_randi32_matches_engine_generator_with_same_seed() -> void:
	# Arrange — a draw in _init would shift this sequence by one
	var stream: RngStream = _seeded()
	var raw: RandomNumberGenerator = _raw_generator(SEED)

	# Act / Assert
	for i: int in range(100):
		assert_int(stream.randi32()).is_equal(raw.randi())
	assert_int(stream.draws).is_equal(100)


func test_two_streams_same_seed_produce_same_sequence() -> void:
	# Arrange
	var a: RngStream = _seeded()
	var b: RngStream = _seeded()

	# Act / Assert
	for i: int in range(50):
		assert_int(a.randi_range(0, 99)).is_equal(b.randi_range(0, 99))


# --- randi_range --------------------------------------------------------------

func test_randi_range_is_lo_plus_draw_mod_span() -> void:
	# Arrange — 7 mod 3 = 1
	var stream: ScriptedRngStream = ScriptedRngStream.new("run", [7] as Array[int])

	# Act
	var value: int = stream.randi_range(3, 5)

	# Assert
	assert_int(value).is_equal(4)
	assert_int(stream.draws).is_equal(1)


func test_randi_range_consumes_one_draw_and_stays_in_bounds() -> void:
	# Arrange
	var stream: RngStream = _seeded()

	# Act / Assert
	for i: int in range(1000):
		assert_int(stream.randi_range(-3, 3)).is_between(-3, 3)
	assert_int(stream.draws).is_equal(1000)


func test_randi_range_single_value_span_consumes_one_draw() -> void:
	# Arrange
	var stream: RngStream = _seeded()

	# Act
	var value: int = stream.randi_range(9, 9)

	# Assert
	assert_int(value).is_equal(9)
	assert_int(stream.draws).is_equal(1)


func test_randi_range_max_span_is_accepted() -> void:
	# Arrange — boundary: span exactly 65,536
	var stream: RngStream = _seeded()

	# Act
	var value: int = stream.randi_range(0, MAX_SPAN - 1)

	# Assert
	assert_int(value).is_between(0, MAX_SPAN - 1)
	assert_int(stream.draws).is_equal(1)


func test_randi_range_lo_above_hi_returns_lo_without_draw() -> void:
	# Arrange — lambdas capture locals by value, so the result goes in a Dictionary
	var stream: RngStream = _seeded()
	var out: Dictionary = {}

	# Act
	await _assert_rejected(func() -> void: out.value = stream.randi_range(5, 1),
		"RngStream.randi_range: bad range [5, 1]")

	# Assert
	assert_int(out.value).is_equal(5)
	assert_int(stream.draws).is_equal(0)


func test_randi_range_span_above_max_returns_lo_without_draw() -> void:
	# Arrange — boundary: span 65,537
	var stream: RngStream = _seeded()
	var out: Dictionary = {}

	# Act
	await _assert_rejected(func() -> void: out.value = stream.randi_range(0, MAX_SPAN),
		"RngStream.randi_range: bad range [0, %d]" % MAX_SPAN)

	# Assert
	assert_int(out.value).is_equal(0)
	assert_int(stream.draws).is_equal(0)


func test_randi_range_overflowing_span_returns_lo_without_draw() -> void:
	# Arrange — hi - lo wraps past int64; must not reach a modulo by 0
	var stream: RngStream = _seeded()
	var lo: int = -9223372036854775807 - 1
	var hi: int = 9223372036854775807
	var out: Dictionary = {}

	# Act
	await _assert_rejected(func() -> void: out.value = stream.randi_range(lo, hi),
		"RngStream.randi_range: bad range [%d, %d]" % [lo, hi])

	# Assert
	assert_int(out.value).is_equal(lo)
	assert_int(stream.draws).is_equal(0)


# --- randf --------------------------------------------------------------------

func test_randf_is_draw_over_two_pow_32() -> void:
	# Arrange — 2^31 / 2^32 = 0.5 exactly
	var stream: ScriptedRngStream = ScriptedRngStream.new("run", [2147483648] as Array[int])

	# Act
	var value: float = stream.randf()

	# Assert
	assert_float(value).is_equal(0.5)
	assert_int(stream.draws).is_equal(1)


func test_randf_largest_draw_stays_below_one() -> void:
	# Arrange — boundary: 2^32 - 1
	var stream: ScriptedRngStream = ScriptedRngStream.new("run", [4294967295] as Array[int])

	# Act
	var value: float = stream.randf()

	# Assert
	assert_bool(value < 1.0).is_true()
	assert_float(value).is_equal(4294967295.0 / TWO_POW_32)


func test_randf_consumes_one_draw_and_stays_in_unit_interval() -> void:
	# Arrange
	var stream: RngStream = _seeded()

	# Act / Assert
	for i: int in range(1000):
		var value: float = stream.randf()
		assert_bool(value >= 0.0 and value < 1.0).is_true()
	assert_int(stream.draws).is_equal(1000)


# --- shuffle ------------------------------------------------------------------

func test_shuffle_f4_trace_gives_c_d_a_b_in_three_draws() -> void:
	# Arrange — scripted so j = 1 (mod 4), 0 (mod 3), 1 (mod 2): the F4 example
	var stream: ScriptedRngStream = ScriptedRngStream.new("run", [1, 0, 1] as Array[int])
	var cards: Array[String] = ["A", "B", "C", "D"]

	# Act
	stream.shuffle(cards)

	# Assert
	assert_array(cards).is_equal(["C", "D", "A", "B"])
	assert_int(stream.draws).is_equal(3)


func test_shuffle_consumes_n_minus_one_draws() -> void:
	# Arrange
	var sizes: Array[int] = [2, 3, 10, 36]

	for n: int in sizes:
		var stream: RngStream = _seeded()
		var items: Array[int] = []
		for i: int in range(n):
			items.append(i)

		# Act
		stream.shuffle(items)

		# Assert — same elements, n - 1 draws
		assert_int(stream.draws).is_equal(n - 1)
		var sorted: Array[int] = items.duplicate()
		sorted.sort()
		for i: int in range(n):
			assert_int(sorted[i]).is_equal(i)


func test_shuffle_empty_and_single_element_take_no_draw() -> void:
	# Arrange
	var stream: RngStream = _seeded()
	var empty: Array[int] = []
	var single: Array[int] = [7]

	# Act
	stream.shuffle(empty)
	stream.shuffle(single)

	# Assert
	assert_array(empty).is_empty()
	assert_array(single).is_equal([7])
	assert_int(stream.draws).is_equal(0)


func test_shuffle_same_seed_same_permutation() -> void:
	# Arrange
	var a: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
	var b: Array[int] = a.duplicate()

	# Act
	_seeded().shuffle(a)
	_seeded().shuffle(b)

	# Assert
	assert_array(a).is_equal(b)


# --- weighted_pick ------------------------------------------------------------

func test_weighted_pick_f4_trace_r_7_picks_index_2() -> void:
	# Arrange — total 20, r = 7 mod 20 = 7; cumulative 5, 5, 20
	var stream: ScriptedRngStream = ScriptedRngStream.new("run", [7] as Array[int])

	# Act
	var index: int = stream.weighted_pick([5, 0, 15])

	# Assert
	assert_int(index).is_equal(2)
	assert_int(stream.draws).is_equal(1)


func test_weighted_pick_r_boundaries_pick_smallest_index_above_r() -> void:
	# Arrange — r = 4 is the last value of index 0, r = 5 the first of index 2
	var low: ScriptedRngStream = ScriptedRngStream.new("run", [4] as Array[int])
	var high: ScriptedRngStream = ScriptedRngStream.new("run", [5] as Array[int])

	# Act / Assert
	assert_int(low.weighted_pick([5, 0, 15])).is_equal(0)
	assert_int(high.weighted_pick([5, 0, 15])).is_equal(2)


func test_weighted_pick_ten_thousand_draws_match_weights() -> void:
	# Arrange
	var stream: RngStream = _seeded()
	var counts: Array[int] = [0, 0, 0]

	# Act
	for i: int in range(DISTRIBUTION_DRAWS):
		counts[stream.weighted_pick([5, 0, 15])] += 1

	# Assert
	assert_int(counts[1]).is_equal(0)
	assert_int(counts[2]).is_between(INDEX_2_MIN, INDEX_2_MAX)
	assert_int(counts[0] + counts[2]).is_equal(DISTRIBUTION_DRAWS)
	assert_int(stream.draws).is_equal(DISTRIBUTION_DRAWS)


func test_weighted_pick_max_total_is_accepted() -> void:
	# Arrange — boundary: total exactly 65,536
	var stream: RngStream = _seeded()

	# Act
	var index: int = stream.weighted_pick([MAX_SPAN >> 1, MAX_SPAN >> 1])

	# Assert
	assert_int(index).is_between(0, 1)
	assert_int(stream.draws).is_equal(1)


func test_weighted_pick_integral_float_weights_are_accepted() -> void:
	# Arrange — JSON numbers arrive as floats; whole ones are valid weights
	var stream: RngStream = _seeded()

	# Act
	var index: int = stream.weighted_pick([5.0, 0.0, 15.0])

	# Assert
	assert_int(index).is_not_equal(1)
	assert_int(index).is_between(0, 2)
	assert_int(stream.draws).is_equal(1)


func test_weighted_pick_invalid_weights_return_minus_one_without_draw() -> void:
	# Arrange — empty, negative weight, total 0, total 65,537, a fractional
	# float, a numeric String, one weight above the cap, and int64 weights
	# whose sum wraps to a valid-looking total of 1
	var wrap: int = 9223372036854775807
	var cases: Array[Array] = [
		[[], "RngStream.weighted_pick: bad weights []"],
		[[3, -1, 4], "RngStream.weighted_pick: bad weights [3, -1, 4]"],
		[[0, 0], "RngStream.weighted_pick: bad weights [0, 0]"],
		[[MAX_SPAN, 1], "RngStream.weighted_pick: bad weights [%d, 1]" % MAX_SPAN],
		[[2.5, 1], "RngStream.weighted_pick: bad weights [2.5, 1]"],
		[["5", 1], "RngStream.weighted_pick: bad weights [\"5\", 1]"],
		[[70000], "RngStream.weighted_pick: bad weights [70000]"],
		[[wrap, wrap, 3], "RngStream.weighted_pick: bad weights [%d, %d, 3]" % [wrap, wrap]],
	]

	for c: Array in cases:
		var stream: RngStream = _seeded()
		var weights: Array = c[0]
		var out: Dictionary = {}

		# Act
		await _assert_rejected(func() -> void: out.value = stream.weighted_pick(weights), c[1])

		# Assert
		assert_int(out.value).is_equal(-1)
		assert_int(stream.draws).is_equal(0)


# --- fork ---------------------------------------------------------------------

func test_fork_twice_returns_same_child_and_costs_one_parent_draw() -> void:
	# Arrange
	var parent: RngStream = _seeded("ai_1")

	# Act
	var first: RngStream = parent.fork("x")
	var second: RngStream = parent.fork("x")

	# Assert
	assert_object(second).is_same(first)
	assert_str(first.name).is_equal("ai_1/x")
	assert_int(parent.draws).is_equal(1)
	assert_int(first.draws).is_equal(0)


func test_fork_child_is_seeded_by_f3_fork_seed() -> void:
	# Arrange — F3 reference arithmetic is the helper's (pinned to GDD examples)
	var parent: RngStream = _seeded("run")
	var parent_draw: int = _raw_generator(SEED).randi()
	var expected: RandomNumberGenerator = _raw_generator(
		TestRngStream.fork_seed(parent_draw, "run", "sim_3"))

	# Act
	var child: RngStream = parent.fork("sim_3")

	# Assert
	for i: int in range(20):
		assert_int(child.randi32()).is_equal(expected.randi())


func test_fork_new_labels_each_cost_one_draw_and_differ() -> void:
	# Arrange
	var parent: RngStream = _seeded("ai_1")

	# Act
	var a: RngStream = parent.fork("sim_1")
	var b: RngStream = parent.fork("sim_2")
	var a_again: RngStream = parent.fork("sim_1")

	# Assert
	assert_int(parent.draws).is_equal(2)
	assert_object(a_again).is_same(a)
	assert_object(b).is_not_same(a)
	assert_str(b.name).is_equal("ai_1/sim_2")


func test_fork_does_not_disturb_parent_sequence_beyond_one_draw() -> void:
	# Arrange
	var parent: RngStream = _seeded("run")
	var raw: RandomNumberGenerator = _raw_generator(SEED)
	@warning_ignore("return_value_discarded")
	raw.randi()  # the fork's parent draw

	# Act
	var child: RngStream = parent.fork("x")
	@warning_ignore("return_value_discarded")
	child.randi32()

	# Assert — child draws never touch the parent's generator
	assert_int(parent.randi32()).is_equal(raw.randi())
	assert_int(parent.draws).is_equal(2)
	assert_int(child.draws).is_equal(1)


func test_fork_bad_label_returns_null_without_draw() -> void:
	# Arrange — F3: a label is [a-z0-9_]+; "a/b" would name the same stream as
	# fork("a").fork("b") under a different seed
	var cases: Array[Array] = [
		["a/b", "RngStream.fork: bad label \"a/b\""],
		["", "RngStream.fork: bad label \"\""],
		["Sim_3", "RngStream.fork: bad label \"Sim_3\""],
		["sim-3", "RngStream.fork: bad label \"sim-3\""],
		["sim_3\n", "RngStream.fork: bad label \"sim_3\\n\""],
	]

	for c: Array in cases:
		var parent: RngStream = _seeded("ai_1")
		var label: String = c[0]
		var out: Dictionary = {}

		# Act
		await _assert_rejected(func() -> void: out.value = parent.fork(label), c[1])

		# Assert
		assert_object(out.value).is_null()
		assert_int(parent.draws).is_equal(0)


func test_fork_of_fork_names_full_path() -> void:
	# Arrange
	var parent: RngStream = _seeded("ai_1")

	# Act
	var grandchild: RngStream = parent.fork("sim_3").fork("leaf")

	# Assert
	assert_str(grandchild.name).is_equal("ai_1/sim_3/leaf")
	assert_int(parent.draws).is_equal(1)
