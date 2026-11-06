## Run Structure F1-F3 and R2: the layout and the boss sequence (design/gdd/
## run-structure.md AC-1 to AC-8, AC-31; against the AC fixture pool).
extends GdUnitTestSuite

const HERO: String = RunHarness.HERO_ID
const SEED_42: String = "42"
const SEED_43: String = "43"
const MVP_FLOORS: int = 4
const MVP_SPLIT: Array[int] = [2, 1, 1]
const BOSS_HEALTH: int = 40
const FLOOR_FIVE: int = 5

var _harnesses: Array[RunHarness] = []


func after_test() -> void:
	for harness: RunHarness in _harnesses:
		harness.release()
	_harnesses.clear()


func _harness(db_edit: Callable = Callable()) -> RunHarness:
	var harness := RunHarness.new(db_edit)
	_harnesses.append(harness)
	return harness


func _sequence(harness: RunHarness, seed_input: String, overrides: Dictionary = {}) -> Array:
	var run: RunMachine = harness.machine(overrides)
	assert_int(run.new_run(HERO, seed_input)).is_equal(OK)
	return Array(run.state.boss_sequence)


func _prefix_count(sequence: Array, prefix: String) -> int:
	return sequence.filter(func(id: String) -> bool: return id.begins_with(prefix)).size()


func _unique(ids: Array) -> Array:
	var seen: Dictionary = {}
	for id: Variant in ids:
		seen[id] = true
	return seen.keys()


# --- AC-1, AC-6: F1 ----------------------------------------------------------

func test_band_of_default_split_is_1_1_1_2_2_2_3_3() -> void:
	# Act
	var bands: Array = []
	for f: int in range(1, TestConstants.FLOORS_PER_RUN + 1):
		bands.append(RunState.band_of(f, TestConstants.BAND_SPLIT))

	# Assert
	assert_array(bands).is_equal([1, 1, 1, 2, 2, 2, 3, 3])


func test_first_floor_of_band_default_split_is_1_4_7() -> void:
	# Act
	var firsts: Array = [1, 2, 3].map(func(b: int) -> int: return RunState.first_floor_of_band(b, TestConstants.BAND_SPLIT))

	# Assert
	assert_array(firsts).is_equal([1, 4, 7])


func test_mvp_layout_comes_from_config_alone() -> void:
	# Arrange: AC-6 and AC-31, through data only
	var overrides: Dictionary = {"floors_per_run": MVP_FLOORS, "band_split": MVP_SPLIT, "treasure_floors": [1, 3, 5]}
	var run: RunMachine = _harness().machine(overrides)

	# Act
	assert_int(run.new_run(HERO, SEED_42)).is_equal(OK)

	# Assert
	var bands: Array = [1, 2, 3, 4].map(func(f: int) -> int: return run.state.band(f))
	assert_array(bands).is_equal([1, 1, 2, 3])
	assert_int(run.state.boss_sequence.size()).is_equal(MVP_FLOORS)
	assert_int(_prefix_count(Array(run.state.boss_sequence), "boss_a")).is_equal(2)
	assert_array(Array(run.state.effective_treasure_floors())).is_equal([1, 3])


# --- AC-2 to AC-5: F2 --------------------------------------------------------

func test_sequence_has_eight_distinct_ids_in_band_order() -> void:
	# Act
	var sequence: Array = _sequence(_harness(), SEED_42)

	# Assert
	assert_int(_unique(sequence).size()).is_equal(TestConstants.FLOORS_PER_RUN)
	for i: int in sequence.size():
		var prefix: String = RunHarness.BAND_PREFIXES[RunState.band_of(i + 1, TestConstants.BAND_SPLIT) - 1]
		assert_str(str(sequence[i])).starts_with(prefix)


func test_sequence_takes_three_shuffles_of_6_6_4_and_no_other_draw() -> void:
	# Arrange
	var run: RunMachine = _harness().machine()

	# Act
	assert_int(run.new_run(HERO, SEED_42)).is_equal(OK)

	# Assert
	var calls: Array = (run.rng as TestRngService).stream(RunMachine.STREAM_RUN).calls
	assert_array(calls.map(func(call: Dictionary) -> String: return call.method)).is_equal(["shuffle", "shuffle", "shuffle"])
	assert_array(calls.map(func(call: Dictionary) -> int: return int(call.args[0]))).is_equal(Array(RunHarness.POOL_SIZES))
	assert_int((run.rng as TestRngService).draws_outside([RunMachine.STREAM_RUN])).is_equal(0)


func test_same_seed_on_two_services_gives_the_same_sequence() -> void:
	# Act
	var first: Array = _sequence(_harness(), SEED_42)
	var second: Array = _sequence(_harness(), SEED_42)

	# Assert
	assert_array(second).is_equal(first)


func test_another_seed_differs_in_at_least_one_position() -> void:
	# Act
	var first: Array = _sequence(_harness(), SEED_42)
	var other: Array = _sequence(_harness(), SEED_43)

	# Assert
	assert_array(other).is_not_equal(first)


func test_short_band_wraps_and_warns_once() -> void:
	# Arrange: band 3 holds only boss_c1
	var harness: RunHarness = _harness(func(db: RunHarness.FakeDb) -> void: db.bands[3] = [db.records["boss_c1"]])
	var run: RunMachine = harness.machine()

	# Act
	var answer: Error = run.new_run(HERO, SEED_42)

	# Assert
	assert_int(answer).is_equal(OK)
	assert_str(run.state.boss_sequence[6]).is_equal("boss_c1")
	assert_str(run.state.boss_sequence[7]).is_equal("boss_c1")
	var warnings: Array = RunHarness.warnings_of(run.run_log, RunCodes.W_BOSS_POOL_SHORT)
	assert_int(warnings.size()).is_equal(1)
	assert_dict(warnings[0].payload.detail).is_equal({"band": 3, "needed": 2, "available": 1})
	assert_str(run.phase()).is_equal(RunState.STATUS_PRE_MATCH)


func test_empty_band_is_e_config_with_no_event_and_no_save() -> void:
	# Arrange
	var harness: RunHarness = _harness(func(db: RunHarness.FakeDb) -> void: db.bands[2] = [])
	var run: RunMachine = harness.machine()

	# Act
	var answer: Error = run.new_run(HERO, SEED_42)

	# Assert
	assert_int(answer).is_equal(RunCodes.E_CONFIG)
	assert_object(run.run_log).is_null()
	assert_array(harness.save_attempts).is_empty()


func test_split_not_summing_to_floors_is_e_config_with_no_event_and_no_save() -> void:
	# Arrange
	var harness: RunHarness = _harness()
	var run: RunMachine = harness.machine({"band_split": [3, 3, 3]})

	# Act
	var answer: Error = run.new_run(HERO, SEED_42)

	# Assert
	assert_int(answer).is_equal(RunCodes.E_CONFIG)
	assert_object(run.run_log).is_null()
	assert_array(harness.save_attempts).is_empty()


func test_a_zero_band_entry_is_e_config() -> void:
	# Arrange
	var run: RunMachine = _harness().machine({"band_split": [4, 0, 4]})

	# Act
	var answer: Error = run.new_run(HERO, SEED_42)

	# Assert
	assert_int(answer).is_equal(RunCodes.E_CONFIG)


# --- AC-7: F3 ----------------------------------------------------------------

func test_floor_health_bonus_adds_per_floor_into_the_band() -> void:
	# Arrange
	var boss: Dictionary = {"health": BOSS_HEALTH}

	# Act
	var with_bonus: int = RunState.boss_health_at(boss, FLOOR_FIVE, TestConstants.BAND_SPLIT, 2)
	var without: int = RunState.boss_health_at(boss, FLOOR_FIVE, TestConstants.BAND_SPLIT, 0)

	# Assert
	assert_int(with_bonus).is_equal(42)
	assert_int(without).is_equal(BOSS_HEALTH)


func test_match_config_carries_the_f3_health() -> void:
	# Arrange
	var harness: RunHarness = _harness()
	var run: RunMachine = harness.machine({"floor_health_bonus": 2})
	assert_int(run.new_run(HERO, SEED_42)).is_equal(OK)
	harness.advance_to(run, FLOOR_FIVE)

	# Act
	@warning_ignore("return_value_discarded")
	harness.begin(run)

	# Assert: band 2, one floor in
	assert_int(int(harness.configs.back().boss.health)).is_equal(RunHarness.BAND_HEALTH[1] + 2)


# --- AC-8: adjacency pass ----------------------------------------------------

## Tags [param sequence]'s first three so that seq[1] shares with seq[0] and seq[2] not.
func _tag_first_band(db: RunHarness.FakeDb, sequence: Array) -> void:
	(db.records[sequence[0]] as Dictionary)["tags"] = ["shared"]
	(db.records[sequence[1]] as Dictionary)["tags"] = ["shared"]
	(db.records[sequence[2]] as Dictionary)["tags"] = ["apart"]


func test_adjacency_pass_swaps_seq1_and_seq2_with_no_further_draw() -> void:
	# Arrange
	var plain: Array = _sequence(_harness(), SEED_42)
	var harness: RunHarness = _harness(func(db: RunHarness.FakeDb) -> void: _tag_first_band(db, plain))
	var run: RunMachine = harness.machine({"no_adjacent_shared_theme": true})

	# Act
	assert_int(run.new_run(HERO, SEED_42)).is_equal(OK)

	# Assert
	var expected: Array = plain.duplicate()
	expected[1] = plain[2]
	expected[2] = plain[1]
	assert_array(Array(run.state.boss_sequence)).is_equal(expected)
	assert_int((run.rng as TestRngService).stream(RunMachine.STREAM_RUN).calls.size()).is_equal(RunHarness.BAND_PREFIXES.size())


func test_adjacency_knob_off_leaves_the_same_tags_unswapped() -> void:
	# Arrange
	var plain: Array = _sequence(_harness(), SEED_42)
	var harness: RunHarness = _harness(func(db: RunHarness.FakeDb) -> void: _tag_first_band(db, plain))

	# Act
	var sequence: Array = _sequence(harness, SEED_42, {"no_adjacent_shared_theme": false})

	# Assert
	assert_array(sequence).is_equal(plain)


func test_adjacency_pass_with_no_partner_in_the_band_warns_and_leaves_it() -> void:
	# Arrange: all of band 1 shares a tag, so nothing in the band can swap in
	var harness: RunHarness = _harness(func(db: RunHarness.FakeDb) -> void:
		for boss: Dictionary in db.bands[1]:
			boss["tags"] = ["shared"])
	var run: RunMachine = harness.machine({"no_adjacent_shared_theme": true})

	# Act
	assert_int(run.new_run(HERO, SEED_42)).is_equal(OK)

	# Assert: floors 2 and 3 are flagged, and no boss left its band
	var floors: Array = RunHarness.warnings_of(run.run_log, RunCodes.W_THEME_ADJACENT).map(func(e: Dictionary) -> int: return int(e.payload.detail.floor))
	assert_array(floors).is_equal([2, 3])
	assert_int(_prefix_count(Array(run.state.boss_sequence).slice(0, 3), "boss_a")).is_equal(3)


func test_adjacency_pass_on_untagged_bosses_is_silent() -> void:
	# Arrange
	var harness: RunHarness = _harness()
	var run: RunMachine = harness.machine({"no_adjacent_shared_theme": true})

	# Act
	assert_int(run.new_run(HERO, SEED_42)).is_equal(OK)

	# Assert
	assert_array(RunHarness.warnings_of(run.run_log, RunCodes.W_THEME_ADJACENT)).is_empty()
