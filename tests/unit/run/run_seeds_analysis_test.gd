## Run Structure R9-R10, F5, F6: seeds, totals and the analysis formulas
## (design/gdd/run-structure.md AC-24 to AC-27, AC-31; Edge Cases "Seeds and identity").
extends GdUnitTestSuite

const HERO: String = RunHarness.HERO_ID
const DECKDELVE: String = "deckdelve"
const DECKDELVE_HEX: String = TestConstants.EXPECTED_RUN_SEED_DECKDELVE_HEX
const LAST_FLOOR: int = TestConstants.FLOORS_PER_RUN
const MAX_MANA: int = 10
## F5's model: boss health by floor at bonus 0, and its turn counts per side.
const HEALTH_BY_FLOOR: Array[int] = [30, 30, 30, 40, 40, 40, 50, 50]
const TURNS_BY_FLOOR: Array[int] = [10, 10, 9, 10, 10, 10, 11, 10]
const P_REACH_8: float = 0.084
const EXPECTED_FLOORS: float = 3.27
## AC-26's measured set.
const RECORDS: int = 200
const REACHING_SEVEN: int = 25
const CARDS_DRAFTED: int = 21
const TREASURES_TAKEN: int = 3

var _h: RunHarness = null


func before_test() -> void:
	_h = RunHarness.new()


func after_test() -> void:
	_h.release()


func _shipped() -> Dictionary:
	return RunHarness.run_config()


func _record_reaching(floor_number: int, wins_through: int) -> Dictionary:
	var rows: Array = []
	for f: int in range(1, floor_number + 1):
		rows.append({"floor": f, "result": MatchRecords.RESULT_WIN if f <= wins_through else MatchRecords.RESULT_LOSS})
	return {"match_summaries": rows}


# --- AC-24 -------------------------------------------------------------------

func test_a_word_seed_hashes_to_the_gdd_hex_and_is_custom() -> void:
	# Arrange
	var run: RunMachine = _h.machine()

	# Act
	assert_int(run.new_run(HERO, DECKDELVE)).is_equal(OK)

	# Assert
	assert_str(run.state.run_seed_hex).is_equal(DECKDELVE_HEX)
	assert_str(run.state.seed_source).is_equal(RunState.SEED_CUSTOM)


func test_the_hex_form_re_parses_to_the_same_run() -> void:
	# Arrange
	var first: RunMachine = _h.machine()
	assert_int(first.new_run(HERO, DECKDELVE)).is_equal(OK)
	var second: RunMachine = RunHarness.new().machine()

	# Act
	assert_int(second.new_run(HERO, DECKDELVE_HEX)).is_equal(OK)

	# Assert
	assert_array(Array(second.state.boss_sequence)).is_equal(Array(first.state.boss_sequence))
	assert_str(second.state.run_seed_hex).is_equal(DECKDELVE_HEX)


func test_an_empty_seed_is_random_and_asks_entropy_once() -> void:
	# Arrange
	var run: RunMachine = _h.machine()
	var asked: Array = []
	run.entropy = func() -> int:
		asked.append(true)
		return 7

	# Act
	assert_int(run.new_run(HERO, "   ")).is_equal(OK)

	# Assert
	assert_str(run.state.seed_source).is_equal(RunState.SEED_RANDOM)
	assert_int(asked.size()).is_equal(1)
	assert_str(run.state.run_seed_hex).is_equal(RngService.to_hex_u64(7))


func test_a_seed_with_custom_seeds_off_is_ignored_and_warned() -> void:
	# Arrange
	var run: RunMachine = _h.machine({"allow_custom_seed": false})

	# Act
	assert_int(run.new_run(HERO, DECKDELVE)).is_equal(OK)

	# Assert
	assert_str(run.state.seed_source).is_equal(RunState.SEED_RANDOM)
	assert_str(run.state.run_seed_hex).is_equal(RngService.to_hex_u64(7))
	assert_int(RunHarness.warnings_of(run.run_log, RunCodes.W_SEED_IGNORED).size()).is_equal(1)


func test_run_id_is_the_hex_and_the_start_time() -> void:
	# Arrange
	var run: RunMachine = _h.machine()

	# Act
	assert_int(run.new_run(HERO, DECKDELVE)).is_equal(OK)

	# Assert
	assert_str(run.state.run_id).is_equal("%s-1000" % DECKDELVE_HEX)


func test_seed_preview_echoes_the_hex_and_is_empty_for_no_input() -> void:
	# Act
	var typed: String = RunMachine.seed_preview(DECKDELVE)
	var blank: String = RunMachine.seed_preview("  ")

	# Assert
	assert_str(typed).is_equal(DECKDELVE_HEX)
	assert_str(blank).is_empty()


func test_run_started_carries_the_catalogue_payload() -> void:
	# Arrange
	var run: RunMachine = _h.machine()

	# Act
	assert_int(run.new_run(HERO, DECKDELVE)).is_equal(OK)

	# Assert
	var payload: Dictionary = RunHarness.events_of(run.run_log, RunCodes.EVENT_RUN_STARTED)[0].payload
	assert_str(payload.run_seed_hex).is_equal(DECKDELVE_HEX)
	assert_str(payload.hero_id).is_equal(HERO)
	assert_str(payload.data_version).is_equal(RunHarness.DATA_VERSION)
	assert_int(int(payload.log_schema_version)).is_equal(EventLog.LOG_SCHEMA_VERSION)
	assert_array(payload.boss_ids).is_equal(Array(run.state.boss_sequence))


# --- AC-25 -------------------------------------------------------------------

func test_totals_of_a_full_victory_sum_the_scripted_summaries() -> void:
	# Arrange
	var run: RunMachine = _h.machine()
	assert_int(run.new_run(HERO, DECKDELVE)).is_equal(OK)
	var expected_turns: int = 0

	# Act: floor f takes f + 4 turns and deals f from card_a and 2 from card_b
	for f: int in range(1, LAST_FLOOR):
		expected_turns += f + 4
		_h.play_floor(run, f + 4, {"card_a": f, "card_b": 2})
	var _driver: MatchDriver = _h.begin(run)
	expected_turns += LAST_FLOOR + 4
	_h.finish_win(run, LAST_FLOOR + 4, {"card_a": LAST_FLOOR, "card_b": 2})

	# Assert
	var totals: Dictionary = run.state.totals
	assert_int(int(totals.matches_played)).is_equal(LAST_FLOOR)
	assert_int(int(totals.turns)).is_equal(expected_turns)
	assert_dict(totals.damage_by_card).is_equal({"card_a": 36, "card_b": 16})
	assert_int(int(totals.cards_drafted)).is_equal(CARDS_DRAFTED)
	assert_int(int(totals.treasures_taken)).is_equal(TREASURES_TAKEN)
	assert_int(int(run.state.result.total_turns)).is_equal(expected_turns)


func test_a_turn_one_concede_has_an_empty_damage_table_and_says_so() -> void:
	# Arrange
	var run: RunMachine = _h.machine()
	assert_int(run.new_run(HERO, DECKDELVE)).is_equal(OK)
	var _driver: MatchDriver = _h.begin(run)

	# Act
	_h.finish_loss(run, MatchRecords.REASON_CONCEDE, 1)

	# Assert
	assert_dict(run.state.totals.damage_by_card).is_empty()
	assert_bool(run.read_model().summary.no_damage).is_true()


func test_the_summary_shows_the_top_cards_and_how_many_more() -> void:
	# Arrange
	var run: RunMachine = _h.machine({"summary_top_cards": 2})
	assert_int(run.new_run(HERO, DECKDELVE)).is_equal(OK)
	var _driver: MatchDriver = _h.begin(run)

	# Act
	_h.finish(MatchRecords.match_result(MatchRecords.RESULT_LOSS, MatchRecords.SIDE_BOSS, MatchRecords.REASON_HERO_DEAD, 1, 5), {"a": 1, "b": 9, "c": 5})

	# Assert
	var summary: Dictionary = run.read_model().summary
	assert_array(summary.top_cards.map(func(row: Dictionary) -> String: return row.card_id)).is_equal(["b", "c"])
	assert_int(int(summary.more_cards)).is_equal(1)


# --- AC-26: F6 ---------------------------------------------------------------

func test_p_reach_of_the_last_floor_at_the_default_targets() -> void:
	# Act
	var reach: float = RunAnalysis.p_reach(_shipped().target_win_rate_by_floor, LAST_FLOOR)

	# Assert
	assert_float(reach).is_equal_approx(P_REACH_8, 0.001)


func test_expected_floors_cleared_at_the_default_targets() -> void:
	# Act
	var expected: float = RunAnalysis.expected_floors_cleared(_shipped().target_win_rate_by_floor)

	# Assert
	assert_float(expected).is_equal_approx(EXPECTED_FLOORS, 0.01)


func test_p_victory_is_reach_times_the_last_rate() -> void:
	# Arrange
	var rates: Array = _shipped().target_win_rate_by_floor

	# Act
	var victory: float = RunAnalysis.p_victory(rates)

	# Assert
	assert_float(victory).is_equal_approx(RunAnalysis.p_reach(rates, LAST_FLOOR) * float(rates.back()), 0.0000001)


func _measured() -> Array[Dictionary]:
	var records: Array = []
	for i: int in RECORDS:
		records.append(_record_reaching(7 if i < REACHING_SEVEN else 6, 6))
	return RunAnalysis.measured_win_rates(records, LAST_FLOOR, int(_shipped().min_sample))


func test_a_floor_under_min_sample_is_not_assessed() -> void:
	# Act
	var rows: Array[Dictionary] = _measured()

	# Assert
	assert_int(int(rows[6].matches)).is_equal(REACHING_SEVEN)
	assert_str(rows[6].status).is_equal(RunAnalysis.NOT_ASSESSED)
	assert_object(rows[6].rate).is_null()


func test_floors_over_min_sample_report_a_rate() -> void:
	# Act
	var rows: Array[Dictionary] = _measured()

	# Assert
	for i: int in range(6):
		assert_str(rows[i].status).is_equal(RunAnalysis.ASSESSED)
		assert_float(float(rows[i].rate)).is_equal_approx(1.0, 0.0000001)


func test_a_measured_rate_counts_losses() -> void:
	# Arrange: on floor 1, 30 wins, 10 losses
	var records: Array = []
	for i: int in 40:
		records.append(_record_reaching(1, 1 if i < 30 else 0))

	# Act
	var rows: Array[Dictionary] = RunAnalysis.measured_win_rates(records, 1, 30)

	# Assert
	assert_float(float(rows[0].rate)).is_equal_approx(0.75, 0.0000001)


# --- AC-27: F5 ---------------------------------------------------------------

func test_turns_to_lethal_matches_the_f5_table() -> void:
	# Act
	var turns: Array = []
	for i: int in LAST_FLOOR:
		turns.append(RunAnalysis.turns_to_lethal(HEALTH_BY_FLOOR[i], RunAnalysis.K_BASE + RunAnalysis.K_STEP * i, MAX_MANA))

	# Assert
	assert_array(turns).is_equal(Array(TURNS_BY_FLOOR))


func test_the_f5_floor_seven_example_is_four_point_six_minutes() -> void:
	# Act
	var minutes: float = RunAnalysis.match_minutes(7, 50, _shipped(), MAX_MANA)

	# Assert
	assert_float(minutes).is_equal_approx(4.6, 0.05)


func test_a_victory_run_is_35_to_45_minutes() -> void:
	# Act
	var minutes: float = RunAnalysis.run_minutes_victory(Array(HEALTH_BY_FLOOR), _shipped(), MAX_MANA)

	# Assert
	assert_float(minutes).is_between(35.0, 45.0)


func test_an_expected_run_is_18_to_26_minutes() -> void:
	# Act
	var minutes: float = RunAnalysis.run_minutes_expected(Array(HEALTH_BY_FLOOR), _shipped(), MAX_MANA)

	# Assert
	assert_float(minutes).is_between(18.0, 26.0)


# --- AC-31: every knob through validate_config -------------------------------

func _body() -> Dictionary:
	return RunHarness.shipped_body(RunHarness.SHIPPED_RUN_STRUCTURE)


func _codes(rows: Array) -> Array:
	return rows.filter(func(row: Dictionary) -> bool: return not row.has("severity")).map(func(row: Dictionary) -> String: return "%s:%s" % [row.code, row.field])


func test_the_shipped_config_passes_with_no_rows() -> void:
	# Act
	var rows: Array = RunMachine.validate_config(_body(), null)

	# Assert
	assert_array(rows).is_empty()


func test_the_shipped_config_holds_exactly_the_knobs() -> void:
	# Act
	var keys: Array = _body().keys()
	keys.sort()
	var known: Array = Array(RunMachine.CONFIG_KEYS).duplicate()
	known.sort()

	# Assert
	assert_array(keys).is_equal(known)


func test_each_knob_past_its_safe_range_is_e_range(key: String, value: int, test_parameters := [
		["floor_health_bonus", 6], ["floor_health_bonus", -1], ["min_sample", 19], ["min_sample", 201],
		["seconds_per_turn_pair", 14], ["seconds_per_turn_pair", 46], ["intro_s", 4], ["intro_s", 21],
		["draft_s", 14], ["draft_s", 61], ["select_s", 14], ["select_s", 61],
		["summary_top_cards", 4], ["summary_top_cards", 37],
		["max_run_record_bytes", 65535], ["max_run_record_bytes", 1048577]]) -> void:
	# Arrange
	var body: Dictionary = _body()
	body[key] = value

	# Act
	var codes: Array = _codes(RunMachine.validate_config(body, null))

	# Assert
	assert_array(codes).is_equal(["E_RANGE:%s" % key])


func test_each_range_end_is_accepted(key: String, value: int, test_parameters := [
		["floor_health_bonus", 5], ["min_sample", 20], ["min_sample", 200], ["seconds_per_turn_pair", 45],
		["intro_s", 5], ["draft_s", 60], ["select_s", 15], ["summary_top_cards", 36], ["max_run_record_bytes", 65536]]) -> void:
	# Arrange
	var body: Dictionary = _body()
	body[key] = value

	# Act
	var rows: Array = RunMachine.validate_config(body, null)

	# Assert
	assert_array(rows).is_empty()


func test_floors_per_run_outside_three_to_twelve_is_e_range() -> void:
	# Arrange
	var body: Dictionary = _body()
	body["floors_per_run"] = 13

	# Act
	var codes: Array = _codes(RunMachine.validate_config(body, null))

	# Assert
	assert_bool(codes.has("E_RANGE:floors_per_run")).is_true()


func test_a_bool_knob_of_the_wrong_type_is_e_bad_value(key: String, test_parameters := [["no_adjacent_shared_theme"], ["allow_custom_seed"], ["abandon_counts_as_loss"]]) -> void:
	# Arrange
	var body: Dictionary = _body()
	body[key] = 1

	# Act
	var codes: Array = _codes(RunMachine.validate_config(body, null))

	# Assert
	assert_array(codes).is_equal(["E_BAD_VALUE:%s" % key])


func test_a_missing_and_an_unknown_key_are_each_reported() -> void:
	# Arrange
	var body: Dictionary = _body()
	body.erase("min_sample")
	body["extra"] = 1

	# Act
	var codes: Array = _codes(RunMachine.validate_config(body, null))

	# Assert
	assert_bool(codes.has("%s:min_sample" % ValidationReport.E_MISSING_FIELD)).is_true()
	assert_bool(codes.has("%s:extra" % ValidationReport.E_UNKNOWN_FIELD)).is_true()


func test_a_band_split_off_floors_per_run_is_e_config(split: Array, test_parameters := [[[3, 3, 3]], [[3, 5]], [[8, 0, 0]], [[3.5, 2.5, 2]]]) -> void:
	# Arrange
	var body: Dictionary = _body()
	body["band_split"] = split

	# Act
	var codes: Array = _codes(RunMachine.validate_config(body, null))

	# Assert
	assert_array(codes).is_equal(["E_CONFIG:band_split"])


func test_a_treasure_floor_at_or_past_the_last_warns_and_passes() -> void:
	# Arrange
	var body: Dictionary = _body()
	body["treasure_floors"] = [1, LAST_FLOOR]

	# Act
	var rows: Array = RunMachine.validate_config(body, null)

	# Assert
	assert_array(_codes(rows)).is_empty()
	assert_int(rows.size()).is_equal(1)
	assert_str(str(rows[0].severity)).is_equal(str(ValidationReport.SEVERITY_WARNING))


func test_a_treasure_floor_below_one_is_e_range() -> void:
	# Arrange
	var body: Dictionary = _body()
	body["treasure_floors"] = [0, 3]

	# Act
	var codes: Array = _codes(RunMachine.validate_config(body, null))

	# Assert
	assert_array(codes).is_equal(["E_RANGE:treasure_floors"])


func test_win_rates_are_one_per_floor_in_range_and_never_rising(rates: Array, code: String, test_parameters := [
		[[0.9, 0.8], "E_CONFIG"],
		[[0.96, 0.85, 0.8, 0.7, 0.65, 0.6, 0.5, 0.4], "E_RANGE"],
		[[0.9, 0.85, 0.8, 0.7, 0.65, 0.6, 0.5, 0.1], "E_RANGE"],
		[[0.9, 0.85, 0.8, 0.7, 0.75, 0.6, 0.5, 0.4], "E_RANGE"]]) -> void:
	# Arrange
	var body: Dictionary = _body()
	body["target_win_rate_by_floor"] = rates

	# Act
	var codes: Array = _codes(RunMachine.validate_config(body, null))

	# Assert
	assert_array(codes).is_equal(["%s:target_win_rate_by_floor" % code])
