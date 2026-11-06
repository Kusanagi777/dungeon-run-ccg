## RngService — seed derivation (F1-F3), hex helpers and memoised named streams.
##
## Story: production/epics/rng-event-log/story-002-rng-service-seed-derivation-and-streams.md
## GDD: design/gdd/rng-event-log.md rules 1-3, 6; F1, F2, F3; Edge Cases
## (Seeds, Streams). ADR-0003 Decision 1-2, 4, 10(d): the F1/F2 example pins
## moved here from the helper self-test so they run against the production
## class on every engine bump — a failure here means the engine changed, not
## the code. Every service is built with a literal seed; no wall clock, no I/O.
extends GdUnitTestSuite

## rng-event-log F2 example seed.
const SEED: int = TestConstants.DEFAULT_TEST_SEED
## F2 / AC: span of the 100-draw sequence (`randi_range(0, 65535)`).
const SPAN_HI: int = RngStream.MAX_RANGE_SPAN - 1
## AC: draws per service in the identical-sequence check.
const SAMPLE: int = 100
## 2^53 + 1: above JSON's exact-integer range (probe E).
const ABOVE_TWO_POW_53: int = 9007199254740993
## The F2 example table for `run_seed = 42` (GDD F2 Example).
const F2_EXAMPLES_42: Dictionary[String, String] = {
	"run": TestConstants.EXPECTED_STREAM_SEED_42_RUN_HEX,
	"match_1": "8E28D71DC7508C82",
	"match_2": "3FC25FB4D7E5C7F5",
	"draft_1": "FFC74EA120AA040F",
	"ai_1": "89527D2C36D9A252",
}


func _no_entropy() -> int:
	fail("entropy must not be called for a non-empty seed field")
	return 0


func _raw_generator(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


# --- AC-1: same seed, same sequence -------------------------------------------

func test_two_services_seeded_42_draw_identical_100_value_run_sequences() -> void:
	# Arrange
	var a: RngService = RngService.new(SEED, "test")
	var b: RngService = RngService.new(SEED, "test")
	var seq_a: Array[int] = []
	var seq_b: Array[int] = []

	# Act
	for _i: int in range(SAMPLE):
		seq_a.append(a.stream("run").randi_range(0, SPAN_HI))
		seq_b.append(b.stream("run").randi_range(0, SPAN_HI))

	# Assert
	assert_array(seq_a).is_equal(seq_b)
	assert_int(a.stream("run").draws).is_equal(SAMPLE)
	assert_int(b.stream("run").draws).is_equal(SAMPLE)


func test_service_stream_is_seeded_by_f2_stream_seed() -> void:
	# Arrange — the generator a stream must be equivalent to (F2, rule 6)
	var service: RngService = RngService.new(SEED, "test")
	var expected: RandomNumberGenerator = _raw_generator(RngService.stream_seed_for(SEED, "match_1"))

	# Act
	var stream: RngStream = service.stream("match_1")

	# Assert
	assert_str(stream.name).is_equal("match_1")
	for _i: int in range(20):
		assert_int(stream.randi32()).is_equal(expected.randi())


func test_construction_takes_no_draw_and_keeps_seed_and_data_version() -> void:
	# Act
	var service: RngService = RngService.new(SEED, "abc")

	# Assert — rule 8: never draw in _init; streams are created on first use
	assert_int(service.run_seed).is_equal(SEED)
	assert_str(service.data_version).is_equal("abc")
	assert_bool(service.has_stream("run")).is_false()
	assert_int(service.stream("run").draws).is_zero()


# --- AC-2: F2 example pins (moved from the helper self-test) ---------------------

func test_stream_seed_matches_gdd_f2_examples() -> void:
	for stream_name: String in F2_EXAMPLES_42:
		assert_str(RngService.to_hex_u64(RngService.stream_seed_for(SEED, stream_name))) \
			.override_failure_message("F2 %s" % stream_name).is_equal(F2_EXAMPLES_42[stream_name])


func test_seed_zero_is_valid_and_matches_the_f2_example() -> void:
	assert_str(RngService.to_hex_u64(RngService.stream_seed_for(0, "run"))).is_equal("8AE616A7F56EA560")


func test_fnv1a64_intermediate_matches_the_f2_example() -> void:
	# F2 Example: fnv1a64(le8(42) ++ "run") = D2063F87976A8AC8 before mix64
	var bytes: PackedByteArray = RngService.le_bytes8(SEED)
	bytes.append_array("run".to_utf8_buffer())
	assert_str(RngService.to_hex_u64(RngService.fnv1a64(bytes))).is_equal("D2063F87976A8AC8")


# --- AC-3: F1 and the hex helpers -------------------------------------------------

func test_run_seed_from_input_matches_gdd_f1_examples() -> void:
	# rng-event-log F1 examples; run-structure AC-24 restates "deckdelve"
	var no_entropy: Callable = _no_entropy
	assert_str(RngService.to_hex_u64(RngService.run_seed_from_input("42", no_entropy))).is_equal("000000000000002A")
	assert_str(RngService.to_hex_u64(RngService.run_seed_from_input("-1", no_entropy))).is_equal("FFFFFFFFFFFFFFFF")
	assert_str(RngService.to_hex_u64(RngService.run_seed_from_input("deckdelve", no_entropy))).is_equal(TestConstants.EXPECTED_RUN_SEED_DECKDELVE_HEX)


func test_sixteen_hex_digits_with_or_without_0x_parse_to_the_same_bits() -> void:
	# Arrange
	var no_entropy: Callable = _no_entropy
	var deckdelve: int = RngService.run_seed_from_input("deckdelve", no_entropy)

	# Act / Assert
	assert_int(RngService.run_seed_from_input(TestConstants.EXPECTED_RUN_SEED_DECKDELVE_HEX, no_entropy)).is_equal(deckdelve)
	assert_int(RngService.run_seed_from_input("0x" + TestConstants.EXPECTED_RUN_SEED_DECKDELVE_HEX, no_entropy)).is_equal(deckdelve)
	assert_int(RngService.run_seed_from_input("0x48a10cc0b2ed54ec", no_entropy)).is_equal(deckdelve)
	assert_int(RngService.run_seed_from_input("0x000000000000002A", no_entropy)).is_equal(SEED)
	assert_int(RngService.run_seed_from_input("  42  ", no_entropy)).is_equal(SEED)


func test_decimal_input_is_taken_mod_two_pow_64() -> void:
	# F1: parse_i64(input) mod 2^64 — 19 digits may exceed int64 and wrap
	var no_entropy: Callable = _no_entropy
	assert_str(RngService.to_hex_u64(RngService.run_seed_from_input("9223372036854775807", no_entropy))).is_equal("7FFFFFFFFFFFFFFF")
	assert_str(RngService.to_hex_u64(RngService.run_seed_from_input("9223372036854775808", no_entropy))).is_equal("8000000000000000")
	assert_str(RngService.to_hex_u64(RngService.run_seed_from_input("-9223372036854775808", no_entropy))).is_equal("8000000000000000")
	assert_str(RngService.to_hex_u64(RngService.run_seed_from_input("9999999999999999999", no_entropy))).is_equal("8AC7230489E7FFFF")
	assert_int(RngService.run_seed_from_input("0", no_entropy)).is_zero()


func test_a_twenty_digit_number_and_other_text_take_the_fnv_branch() -> void:
	# Arrange — 20 digits is outside ^-?[0-9]{1,19}$; 15 hex digits outside the hex rule
	var no_entropy: Callable = _no_entropy
	var cases: Array[String] = ["18446744073709551615", "48A10CC0B2ED54E", "0X48A10CC0B2ED54EC", "4 2"]

	for input: String in cases:
		# Act / Assert
		assert_int(RngService.run_seed_from_input(input, no_entropy)).override_failure_message(input) \
			.is_equal(RngService.fnv1a64(input.to_utf8_buffer()))


func test_empty_or_whitespace_input_calls_entropy_exactly_once() -> void:
	for input: String in ["", "   ", "\t\n"]:
		# Arrange — lambdas capture by value: count through a Dictionary
		var calls: Dictionary = {"n": 0}
		var entropy: Callable = func() -> int:
			calls.n += 1
			return ABOVE_TWO_POW_53

		# Act
		var seed_value: int = RngService.run_seed_from_input(input, entropy)

		# Assert
		assert_int(calls.n).override_failure_message("input %s" % input.c_escape()).is_equal(1)
		assert_int(seed_value).is_equal(ABOVE_TWO_POW_53)


func test_non_empty_input_never_calls_entropy() -> void:
	# Arrange
	var calls: Dictionary = {"n": 0}
	var entropy: Callable = func() -> int:
		calls.n += 1
		return 0

	# Act
	for input: String in ["42", "-1", "deckdelve", TestConstants.EXPECTED_RUN_SEED_DECKDELVE_HEX, " x "]:
		RngService.run_seed_from_input(input, entropy)

	# Assert
	assert_int(calls.n).is_zero()


func test_hex_round_trip_holds_for_the_f1_examples_and_above_two_pow_53() -> void:
	for hex: String in ["000000000000002A", "FFFFFFFFFFFFFFFF", TestConstants.EXPECTED_RUN_SEED_DECKDELVE_HEX, RngService.to_hex_u64(ABOVE_TWO_POW_53)]:
		assert_str(RngService.to_hex_u64(RngService.parse_hex_u64(hex))).is_equal(hex)
	assert_int(RngService.parse_hex_u64("0020000000000001")).is_equal(ABOVE_TWO_POW_53)
	assert_int(RngService.parse_hex_u64("FFFFFFFFFFFFFFFF")).is_equal(-1)
	assert_int(RngService.parse_hex_u64("ffffffffffffffff")).is_equal(-1)


func test_parse_hex_u64_rejects_anything_but_sixteen_hex_digits() -> void:
	for bad: String in ["2A", "0x000000000000002A", "00000000000000ZZ", "00000000000000002A"]:
		# Arrange
		var out: Dictionary = {"value": -1}

		# Act / Assert — a data fault: pushed error and 0, never an assert
		await assert_error(func() -> void: out.value = RngService.parse_hex_u64(bad)) \
			.is_push_error("RngService.parse_hex_u64: \"%s\" is not 16 hex digits" % bad)
		assert_int(out.value).is_zero()


# --- AC-4: memoisation, names, forks ------------------------------------------------

func test_the_same_stream_name_returns_the_same_object_with_its_position_intact() -> void:
	# Arrange
	var service: RngService = RngService.new(SEED, "test")
	var first: RngStream = service.stream("match_3")
	for _i: int in range(5):
		first.randi32()

	# Act
	var second: RngStream = service.stream("match_3")

	# Assert
	assert_object(second).is_same(first)
	assert_int(second.draws).is_equal(5)
	assert_bool(service.has_stream("match_3")).is_true()


func test_a_name_outside_the_rule_3_pattern_is_reported_and_still_served() -> void:
	for bad: String in ["Match_1", "match-1", "match_1_2", "1run", "run\n", ""]:
		# Arrange
		var service: RngService = RngService.new(SEED, "test")
		var out: Dictionary = {}

		# Act / Assert
		await assert_error(func() -> void: out.stream = service.stream(bad)) \
			.is_push_error("RngService.stream: \"%s\" violates the rule 3 name pattern" % bad.c_escape())
		assert_object(out.stream).is_not_null()
		assert_str((out.stream as RngStream).name).is_equal(bad)


## A caller bug: a runtime assert in debug builds, a push_error in release.
func _assert_rejected(call: Callable, message: String) -> void:
	if OS.is_debug_build():
		await assert_error(call).is_runtime_error("Assertion failed: " + message)
	else:
		await assert_error(call).is_push_error(message)


func test_stream_refuses_a_fork_path_name_and_creates_no_stream() -> void:
	# Rule 3 (code review 2026-11-03): stream() takes root names only; a `/`
	# name would share "ai_1/x" with stream("ai_1").fork("x") under an F2
	# seed instead of the F3 one
	for bad: String in ["ai_1/x", "ai_1/sim_3/leaf", "run/", "/run"]:
		# Arrange
		var service: RngService = RngService.new(SEED, "test")
		var out: Dictionary = {}
		var message: String = "RngService.stream: \"%s\" is a fork path; stream() takes root names only, use stream(root).fork(label)" % bad

		# Act
		await _assert_rejected(func() -> void: out.stream = service.stream(bad), message)

		# Assert — null, nothing memoised, the parent untouched
		assert_object(out.get("stream")).is_null()
		assert_bool(service.has_stream(bad)).is_false()
		assert_bool(service.has_stream("ai_1")).is_false()


func test_the_fork_path_name_is_reachable_only_through_fork() -> void:
	# Arrange
	var service: RngService = RngService.new(SEED, "test")

	# Act
	var child: RngStream = service.stream("ai_1").fork("x")

	# Assert — the full rule 3 name, served by fork, not by stream()
	assert_str(child.name).is_equal("ai_1/x")
	assert_bool(RngService.is_valid_stream_name(child.name)).is_true()
	assert_bool(service.has_stream("ai_1/x")).is_false()


func test_run_seed_and_data_version_are_read_only() -> void:
	# Arrange
	var service: RngService = RngService.new(SEED, "v1")

	# Act / Assert — each write is logged and does not stick
	await assert_error(func() -> void: service.run_seed = SEED + 1) \
		.is_push_error("RngService.run_seed is read-only; set at construction")
	await assert_error(func() -> void: service.data_version = "v2") \
		.is_push_error("RngService.data_version is read-only; set at construction")
	assert_int(service.run_seed).is_equal(SEED)
	assert_str(service.data_version).is_equal("v1")


func test_rule_3_names_in_the_v1_table_are_valid() -> void:
	for good: String in ["run", "match_1", "match_8", "draft_3", "ai_2", "ai_1/sim_3", "ai_1/forecast_2/leaf"]:
		assert_bool(RngService.is_valid_stream_name(good)).override_failure_message(good).is_true()
	for bad: String in ["Match_1", "match_1_2", "run/", "run//x", "run/X", "run\n"]:
		assert_bool(RngService.is_valid_stream_name(bad)).override_failure_message(bad.c_escape()).is_false()


func test_fork_on_a_service_stream_is_the_memoised_child_seeded_by_f3() -> void:
	# Arrange
	var service: RngService = RngService.new(SEED, "test")
	var parent: RngStream = service.stream("ai_1")
	var parent_draw: int = _raw_generator(RngService.stream_seed_for(SEED, "ai_1")).randi()
	var expected: RandomNumberGenerator = _raw_generator(RngService.fork_seed(parent_draw, "ai_1", "x"))

	# Act
	var child: RngStream = service.stream("ai_1").fork("x")
	var again: RngStream = service.stream("ai_1").fork("x")

	# Assert
	assert_str(child.name).is_equal("ai_1/x")
	assert_object(again).is_same(child)
	assert_int(parent.draws).is_equal(1)
	assert_bool(RngService.is_valid_stream_name(child.name)).is_true()
	for _i: int in range(20):
		assert_int(child.randi32()).is_equal(expected.randi())


func test_fork_seed_is_the_f3_formula() -> void:
	# F3: mix64(fnv1a64(le_bytes8(parent_draw) ++ utf8(parent_name + "/" + label)))
	var bytes: PackedByteArray = RngService.le_bytes8(12345)
	bytes.append_array("ai_1/sim_3".to_utf8_buffer())
	assert_int(RngService.fork_seed(12345, "ai_1", "sim_3")).is_equal(RngService.mix64(RngService.fnv1a64(bytes)))
	assert_int(RngService.fork_seed(12345, "ai_1", "sim_3")).is_not_equal(RngService.fork_seed(12346, "ai_1", "sim_3"))
