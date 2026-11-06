## Engine golden pin for RNG & Event Log (gate entry condition 7).
##
## Story: production/epics/rng-event-log/story-001-rng-stream-engine-pin-and-draw-primitives.md
## ADR-0003 Verification, probe D: "same seed => same `randi()` sequence;
## `randi()` in [0, 2^32 - 1]". This suite is the durable record of that probe.
##
## A FAILURE HERE MEANS THE ENGINE CHANGED, NOT THE CODE. Replay equivalence
## (rng-event-log rule 9) is scoped to one engine version by design. On an
## engine bump that changes `RandomNumberGenerator`, re-record GOLDEN_SEED_42
## from the new engine with a dated note below (ADR-0003 Validation Criteria);
## never edit the code under test to make this pass.
extends GdUnitTestSuite

## The seed the golden sequence is recorded at (ADR-0003 probe D).
const PIN_SEED: int = 42
## Number of `randi()` outputs pinned.
const PIN_LENGTH: int = 100
## Largest value `RandomNumberGenerator.randi()` may return (2^32 - 1).
const U32_MAX: int = 4294967295

## `RandomNumberGenerator.seed = 42` then 100 x `randi()`.
## Recorded 2026-11-03 on Godot 4.7.2.stable.official.ed1daf0bf, Linux x86_64.
## The first three values match engine validation probe D (same date).
const GOLDEN_SEED_42: Array[int] = [
	492690617, 1919685028, 3561993920, 683038915, 1183706632,
	413921556, 222559498, 436142503, 3736035009, 1116290151,
	1058873627, 2751175047, 2547725509, 4025794437, 530045929,
	1333599331, 593302951, 925240941, 2160814011, 4159442378,
	231587883, 1928126881, 210467999, 1796112158, 62880104,
	3816579799, 3950972827, 1040650675, 3465205661, 3630864215,
	1785929563, 3949348074, 3125352777, 644201059, 1880694512,
	95968067, 2512851934, 3295317029, 1856217290, 2112908573,
	3378497054, 1837459106, 2519870220, 963213795, 2706952389,
	693790815, 538966447, 1724751924, 2585469828, 120423510,
	3592459950, 4184012234, 2531511823, 645153842, 1974425390,
	3806117216, 1457503418, 1971130952, 1721086484, 1151723520,
	833950247, 1601179396, 2637998531, 3658392947, 3681576867,
	349051673, 2859268670, 505655986, 3717336297, 1155281720,
	3325509351, 3650329194, 2921640176, 1366315953, 958928748,
	2773460392, 1164184319, 345598294, 2164713717, 3141357490,
	536744086, 424246401, 1659211695, 1657475976, 4284656058,
	3712168498, 3135859286, 3078861802, 3164687685, 993409388,
	646528096, 2790227327, 3125270803, 2430977540, 1485375561,
	1264598456, 1988348928, 1916417870, 482409893, 3079066175,
]


func _draw_sequence(seed_value: int, count: int) -> Array[int]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var out: Array[int] = []
	for _i: int in range(count):
		out.append(rng.randi())
	return out


func _engine_failure(what: String) -> String:
	return ("ENGINE CHANGED, not the code: %s on Godot %s. Re-record the golden pin "
		+ "with a dated note (ADR-0003 Validation Criteria).") % [what, Engine.get_version_info().string]


func test_two_generators_same_seed_produce_identical_sequences() -> void:
	# Arrange / Act
	var a: Array[int] = _draw_sequence(PIN_SEED, PIN_LENGTH)
	var b: Array[int] = _draw_sequence(PIN_SEED, PIN_LENGTH)

	# Assert
	assert_int(a.size()).is_equal(PIN_LENGTH)
	assert_array(b).override_failure_message(
		_engine_failure("two RandomNumberGenerator instances seeded %d diverged" % PIN_SEED)
	).is_equal(a)


func test_seed_42_first_three_draws_match_probe_d() -> void:
	# Arrange / Act
	var seq: Array[int] = _draw_sequence(PIN_SEED, 3)

	# Assert
	assert_array(seq).override_failure_message(
		_engine_failure("seed 42 no longer yields 492690617, 1919685028, 3561993920 (got %s)" % str(seq))
	).is_equal([492690617, 1919685028, 3561993920])


func test_seed_42_hundred_draws_match_golden_sequence() -> void:
	# Arrange / Act
	var seq: Array[int] = _draw_sequence(PIN_SEED, PIN_LENGTH)

	# Assert
	assert_int(GOLDEN_SEED_42.size()).is_equal(PIN_LENGTH)
	for i: int in range(PIN_LENGTH):
		assert_int(seq[i]).override_failure_message(
			_engine_failure("seed 42 draw #%d is %d, golden is %d" % [i + 1, seq[i], GOLDEN_SEED_42[i]])
		).is_equal(GOLDEN_SEED_42[i])


func test_randi_values_lie_in_unsigned_32_bit_range() -> void:
	# Arrange / Act
	var seq: Array[int] = _draw_sequence(PIN_SEED, PIN_LENGTH)

	# Assert
	for value: int in seq:
		assert_int(value).override_failure_message(
			_engine_failure("randi() returned %d, outside [0, 2^32 - 1]" % value)
		).is_between(0, U32_MAX)
