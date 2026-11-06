## Run Structure R1, R8.1: `RunRecord` and `DraftRecord` (design/gdd/run-structure.md
## AC-28; Edge Cases "If the save fails schema_version or structural validation").
## `validate` is given what a load gives it: a record that has been through JSON, all
## numbers floats. `from_dict` must take a damaged record and never fail.
extends GdUnitTestSuite

const HERO: String = RunHarness.HERO_ID
const SEED: String = "42"
## Above 2^53, where a JSON number would no longer hold it.
const WIDE_SEED_HEX: String = "FFFFFFFFFFFFFFF1"
const WIDE_SEED: int = -15
const SIGNED_HEX: String = "-00000000000002A"
const FLOOR_THREE: int = 3
const LAST_FLOOR: int = TestConstants.FLOORS_PER_RUN

var _h: RunHarness = null
var _run: RunMachine = null


func before_test() -> void:
	_h = RunHarness.new()
	_run = _h.machine()
	assert_int(_run.new_run(HERO, SEED)).is_equal(OK)


func after_test() -> void:
	_h.release()


## The record in the slot, as disk would give it.
func _loaded() -> Dictionary:
	return JSON.parse_string(JSON.stringify(_h.meta.load_active_run()))


func _validate(edit: Callable) -> Error:
	var record: Dictionary = _loaded()
	edit.call(record)
	return RunRecord.validate(record, _h.db)


## A record two floors in: picks in `drafts`, summaries, an attempts map.
func _played_record() -> Dictionary:
	_h.advance_to(_run, FLOOR_THREE)
	return _loaded()


func _full_run_record() -> Dictionary:
	_h.advance_to(_run, LAST_FLOOR)
	var _driver: MatchDriver = _h.begin(_run)
	_h.finish_win(_run, 10, {"card_x": 7})
	return _h.archived[0]


## The types JSON can hold, all the way down. Lists what is not.
func _non_json(value: Variant, path: String = "$") -> Array:
	var found: Array = []
	if value is Dictionary:
		for key: Variant in value:
			if not key is String:
				found.append("%s key %s" % [path, str(key)])
			found.append_array(_non_json(value[key], "%s.%s" % [path, str(key)]))
	elif value is Array:
		for i: int in (value as Array).size():
			found.append_array(_non_json(value[i], "%s[%d]" % [path, i]))
	elif not (value == null or value is bool or value is int or value is float or value is String):
		found.append("%s %s" % [path, type_string(typeof(value))])
	return found


# --- validate: a real record -------------------------------------------------

func test_a_fresh_saved_record_with_a_real_run_log_validates() -> void:
	# Act
	var answer: Error = RunRecord.validate(_loaded(), _h.db)

	# Assert
	assert_int(answer).is_equal(OK)


func test_a_mid_run_record_validates_after_json() -> void:
	# Act
	var answer: Error = RunRecord.validate(_played_record(), _h.db)

	# Assert
	assert_int(answer).is_equal(OK)


func test_state_validate_answers_for_the_live_state() -> void:
	# Arrange
	_h.play_floor(_run)

	# Act
	var answer: Error = _run.state.validate(_h.db)

	# Assert
	assert_int(answer).is_equal(OK)


func test_a_run_log_with_no_events_is_corrupt() -> void:
	# Act
	var answer: Error = _validate(func(r: Dictionary) -> void: (r.run_log as Dictionary).erase("events"))

	# Assert
	assert_int(answer).is_equal(RunCodes.E_CORRUPT)


func test_a_run_log_of_the_wrong_type_is_a_schema_fault() -> void:
	# Act
	var answer: Error = _validate(func(r: Dictionary) -> void: r["run_log"] = "lost")

	# Assert
	assert_int(answer).is_equal(RunCodes.E_SCHEMA)


# --- validate: schema_version ------------------------------------------------

func test_schema_version_as_a_whole_float_is_accepted() -> void:
	# Act
	var answer: Error = _validate(func(r: Dictionary) -> void: r["schema_version"] = 1.0)

	# Assert
	assert_int(answer).is_equal(OK)


func test_schema_version_mistyped_is_a_schema_fault(value: Variant, test_parameters := [["1"], [true], [1.5], [2], [0], [[1]], [{}]]) -> void:
	# Act
	var answer: Error = _validate(func(r: Dictionary) -> void: r["schema_version"] = value)

	# Assert
	assert_int(answer).is_equal(RunCodes.E_SCHEMA)


func test_schema_version_missing_or_null_is_a_schema_fault() -> void:
	# Act
	var missing: Error = _validate(func(r: Dictionary) -> void: r.erase("schema_version"))
	var nulled: Error = _validate(func(r: Dictionary) -> void: r["schema_version"] = null)

	# Assert
	assert_int(missing).is_equal(RunCodes.E_SCHEMA)
	assert_int(nulled).is_equal(RunCodes.E_SCHEMA)


func test_every_required_field_missing_is_a_schema_fault() -> void:
	# Arrange
	var answers: Dictionary = {}

	# Act
	for field: String in RunRecord.REQUIRED_FIELDS:
		var answer: Error = _validate(func(r: Dictionary) -> void: r.erase(field))
		if answer != RunCodes.E_SCHEMA:
			answers[field] = answer

	# Assert
	assert_dict(answers).is_empty()


func test_every_required_field_of_the_wrong_type_is_a_schema_fault() -> void:
	# Arrange: a bool is no field's type
	var answers: Dictionary = {}

	# Act
	for field: String in RunRecord.REQUIRED_FIELDS:
		var answer: Error = _validate(func(r: Dictionary) -> void: r[field] = true)
		if answer != RunCodes.E_SCHEMA:
			answers[field] = answer

	# Assert
	assert_dict(answers).is_empty()


# --- validate: run_seed_hex --------------------------------------------------

func _with_seed_hex(value: Variant) -> Callable:
	return func(r: Dictionary) -> void:
		r["run_seed_hex"] = value
		r.rng_snapshot["run_seed_hex"] = value


func test_run_seed_hex_as_a_number_is_a_schema_fault() -> void:
	# Act
	var answer: Error = _validate(_with_seed_hex(42))

	# Assert
	assert_int(answer).is_equal(RunCodes.E_SCHEMA)


func test_run_seed_hex_malformed_is_corrupt(value: String, test_parameters := [["2A"], ["000000000000002"], ["0000000000000002A"], ["ZZZZZZZZZZZZZZZZ"], ["0x000000000000002A"], ["0x0000000000002A"], [""]]) -> void:
	# Act
	var answer: Error = _validate(_with_seed_hex(value))

	# Assert
	assert_int(answer).is_equal(RunCodes.E_CORRUPT)


func test_run_seed_hex_with_a_sign_is_corrupt() -> void:
	# Act: 16 characters that `is_valid_hex_number` alone accepts
	var answer: Error = _validate(_with_seed_hex(SIGNED_HEX))

	# Assert
	assert_int(answer).is_equal(RunCodes.E_CORRUPT)


func test_is_seed_hex_is_exactly_sixteen_digits() -> void:
	# Act
	var accepted: bool = RunRecord.is_seed_hex("000000000000002A")
	var signed: bool = RunRecord.is_seed_hex("+00000000000002A")

	# Assert
	assert_bool(accepted).is_true()
	assert_bool(signed).is_false()


func test_a_snapshot_of_another_seed_is_corrupt() -> void:
	# Act
	var answer: Error = _validate(func(r: Dictionary) -> void: r.rng_snapshot["run_seed_hex"] = "000000000000002B")

	# Assert
	assert_int(answer).is_equal(RunCodes.E_CORRUPT)


# --- validate: order and ids -------------------------------------------------

func test_data_version_is_reported_before_ids_that_no_longer_resolve() -> void:
	# Act
	var answer: Error = _validate(func(r: Dictionary) -> void:
		r["data_version"] = "older"
		r["hero_id"] = "hero_gone")

	# Assert
	assert_int(answer).is_equal(RunCodes.E_DATA_VERSION)


func test_ids_are_reported_before_invariants() -> void:
	# Act
	var answer: Error = _validate(func(r: Dictionary) -> void:
		r["hero_id"] = "hero_gone"
		r["floor"] = 0)

	# Assert
	assert_int(answer).is_equal(RunCodes.E_UNKNOWN_ID)


func test_an_id_in_each_list_that_does_not_resolve_is_e_unknown_id(list: String, test_parameters := [["boss_sequence"], ["deck"]]) -> void:
	# Act
	var answer: Error = _validate(func(r: Dictionary) -> void: r[list][0] = "gone")

	# Assert
	assert_int(answer).is_equal(RunCodes.E_UNKNOWN_ID)


func test_a_treasure_that_does_not_resolve_is_e_unknown_id() -> void:
	# Arrange
	var record: Dictionary = _played_record()
	record.treasures[0] = "gone"

	# Act
	var answer: Error = RunRecord.validate(record, _h.db)

	# Assert
	assert_int(answer).is_equal(RunCodes.E_UNKNOWN_ID)


func test_a_picked_id_that_does_not_resolve_is_e_unknown_id() -> void:
	# Arrange
	var record: Dictionary = _played_record()
	record.drafts[0]["picked_id"] = "gone"

	# Act
	var answer: Error = RunRecord.validate(record, _h.db)

	# Assert
	assert_int(answer).is_equal(RunCodes.E_UNKNOWN_ID)


func test_a_number_in_an_id_list_is_e_unknown_id_not_a_crash() -> void:
	# Act
	var answer: Error = _validate(func(r: Dictionary) -> void: r.deck[0] = 7)

	# Assert
	assert_int(answer).is_equal(RunCodes.E_UNKNOWN_ID)


# --- validate: invariants ----------------------------------------------------

func test_the_r1_invariants_hold_or_corrupt(field: String, value: Variant, test_parameters := [
		["floor", 0], ["floor", 9], ["floors_per_run", 7], ["status", "lost"],
		["band_split", [3, 3]], ["band_split", [3, 3, 3]], ["band_split", [4, 0, 4]], ["band_split", [3, "3", 2]],
		["reward_step", "treasure"]]) -> void:
	# Act
	var answer: Error = _validate(func(r: Dictionary) -> void: r[field] = value)

	# Assert
	assert_int(answer).is_equal(RunCodes.E_CORRUPT)


func test_the_reward_phase_needs_a_reward_step() -> void:
	# Act
	var answer: Error = _validate(func(r: Dictionary) -> void: r["status"] = RunState.STATUS_POST_MATCH_REWARD)

	# Assert
	assert_int(answer).is_equal(RunCodes.E_CORRUPT)


func test_a_deck_that_does_not_match_its_picks_is_corrupt() -> void:
	# Arrange
	var record: Dictionary = _played_record()
	(record.deck as Array).pop_back()

	# Act
	var answer: Error = RunRecord.validate(record, _h.db)

	# Assert
	assert_int(answer).is_equal(RunCodes.E_CORRUPT)


func test_treasures_that_do_not_match_their_picks_are_corrupt() -> void:
	# Arrange
	var record: Dictionary = _played_record()
	(record.treasures as Array).append("t9")

	# Act
	var answer: Error = RunRecord.validate(record, _h.db)

	# Assert
	assert_int(answer).is_equal(RunCodes.E_CORRUPT)


func test_two_records_of_one_floor_and_kind_are_corrupt() -> void:
	# Arrange
	var record: Dictionary = _played_record()
	var rows: Array = record.drafts
	rows.append(rows[0].duplicate(true))
	(rows.back() as Dictionary)["picked_id"] = null
	(rows.back() as Dictionary)["card_ids_added"] = []

	# Act
	var answer: Error = RunRecord.validate(record, _h.db)

	# Assert
	assert_int(answer).is_equal(RunCodes.E_CORRUPT)


func test_draft_rows_of_the_wrong_shape_are_corrupt(field: String, value: Variant, test_parameters := [
		["floor", 0], ["floor", "1"], ["kind", "relic"], ["offered_ids", "t1"], ["offered_ids", [1]],
		["card_ids_added", 3], ["picked_id", 5]]) -> void:
	# Arrange
	var record: Dictionary = _played_record()
	record.drafts[0][field] = value

	# Act
	var answer: Error = RunRecord.validate(record, _h.db)

	# Assert
	assert_int(answer).is_equal(RunCodes.E_CORRUPT)


func test_a_draft_row_with_no_picked_id_key_is_corrupt_and_does_not_crash() -> void:
	# Arrange: the JSON an older or hand-edited writer leaves, `card_ids_added` empty
	var record: Dictionary = _played_record()
	(record.drafts[0] as Dictionary).erase("picked_id")
	record.drafts[0]["card_ids_added"] = []

	# Act
	var answer: Error = RunRecord.validate(record, _h.db)

	# Assert
	assert_int(answer).is_equal(RunCodes.E_CORRUPT)


func test_a_picked_id_that_was_not_offered_is_corrupt() -> void:
	# Arrange: `t2` resolves, and was not on this list
	var record: Dictionary = _played_record()
	record.drafts[0]["offered_ids"] = ["t3", "t4", "t5"]
	record.drafts[0]["picked_id"] = "t2"

	# Act
	var answer: Error = RunRecord.validate(record, _h.db)

	# Assert
	assert_int(answer).is_equal(RunCodes.E_CORRUPT)


func test_cards_added_with_no_pick_are_corrupt() -> void:
	# Arrange
	var record: Dictionary = _played_record()
	record.drafts[0]["picked_id"] = null
	record.drafts[0]["card_ids_added"] = ["c1"]

	# Act
	var answer: Error = RunRecord.validate(record, _h.db)

	# Assert
	assert_int(answer).is_equal(RunCodes.E_CORRUPT)


func test_a_malformed_summary_row_is_corrupt(row: Variant, test_parameters := [["lost"], [{"turns": []}], [{"turns": 3, "damage_by_card": "none"}], [{"turns": 3, "damage_by_card": {"c": []}}]]) -> void:
	# Arrange
	var record: Dictionary = _played_record()
	record.match_summaries[0] = row

	# Act
	var answer: Error = RunRecord.validate(record, _h.db)

	# Assert
	assert_int(answer).is_equal(RunCodes.E_CORRUPT)


func test_unusable_draft_and_treasure_states_are_repaired_on_resume_not_rejected() -> void:
	# Act
	var answer: Error = _validate(func(r: Dictionary) -> void:
		r["draft_state"] = {}
		r["treasure_state"] = {"schema_version": 99})

	# Assert
	assert_int(answer).is_equal(OK)


# --- from_dict: coercion -----------------------------------------------------

func test_from_dict_turns_json_floats_into_ints() -> void:
	# Arrange
	var record: Dictionary = _played_record()

	# Act
	var state: RunState = RunRecord.from_dict(record)

	# Assert
	assert_int(typeof(state.floor)).is_equal(TYPE_INT)
	assert_int(state.floor).is_equal(FLOOR_THREE)
	assert_int(typeof(state.band_split[0])).is_equal(TYPE_INT)
	assert_array(Array(state.band_split)).is_equal(Array(TestConstants.BAND_SPLIT))
	assert_int(typeof(state.drafts[0].floor)).is_equal(TYPE_INT)
	assert_int(typeof(state.match_summaries[0].turns)).is_equal(TYPE_INT)
	assert_int(typeof((state.treasure_state.schema_version))).is_equal(TYPE_INT)


func test_from_dict_rebuilds_run_seed_from_the_hex_past_two_to_the_53() -> void:
	# Arrange
	var record: Dictionary = _loaded()
	record["run_seed_hex"] = WIDE_SEED_HEX

	# Act
	var state: RunState = RunRecord.from_dict(record)

	# Assert
	assert_int(state.run_seed).is_equal(WIDE_SEED)


func test_to_dict_leaves_run_seed_out() -> void:
	# Act
	var record: Dictionary = RunRecord.to_dict(_run.state)

	# Assert
	assert_bool(record.has("run_seed")).is_false()
	assert_str(record.run_seed_hex).is_equal(_run.state.run_seed_hex)


func test_from_dict_gives_match_attempts_canonical_keys_whatever_arrived() -> void:
	# Arrange
	var record: Dictionary = _loaded()
	record["match_attempts"] = {"1": 2.0, 2: 1, 3.0: 4, "x": 1, "4": "many", "5.5": 1}

	# Act
	var state: RunState = RunRecord.from_dict(record)

	# Assert
	assert_dict(state.match_attempts).is_equal({"1": 2, "2": 1, "3": 4})
	assert_int(state.attempts_on(1)).is_equal(2)
	assert_int(state.attempts_on(3)).is_equal(4)


func test_from_dict_on_an_empty_record_gives_defaults_and_does_not_fail() -> void:
	# Act
	var state: RunState = RunRecord.from_dict({})

	# Assert
	assert_int(state.schema_version).is_equal(RunRecord.SCHEMA_VERSION)
	assert_int(state.floor).is_equal(1)
	assert_str(state.status).is_equal(RunState.STATUS_PRE_MATCH)
	assert_array(Array(state.deck)).is_empty()
	assert_object(state.reward_step).is_null()
	assert_object(state.result).is_null()


func test_from_dict_gives_wrong_shapes_their_defaults() -> void:
	# Arrange
	var damaged: Dictionary = {
		"floor": "three", "deck": "cards", "drafts": 12, "match_attempts": [1], "draft_state": "x",
		"band_split": [3, "3", 2.5, 2.0], "boss_sequence": ["boss_a1", 7], "reward_step": 4, "ended_at": "soon",
		"result": "lost", "match_summaries": ["row", {"turns": 2.0}], "run_seed_hex": "nope",
	}

	# Act
	var state: RunState = RunRecord.from_dict(damaged)

	# Assert
	assert_int(state.floor).is_equal(1)
	assert_array(Array(state.deck)).is_empty()
	assert_array(Array(state.drafts)).is_empty()
	assert_dict(state.match_attempts).is_empty()
	assert_dict(state.draft_state).is_empty()
	assert_array(Array(state.band_split)).is_equal([3, 2])
	assert_array(Array(state.boss_sequence)).is_equal(["boss_a1"])
	assert_object(state.reward_step).is_null()
	assert_object(state.ended_at).is_null()
	assert_object(state.result).is_null()
	assert_int(state.match_summaries.size()).is_equal(1)
	assert_int(state.run_seed).is_equal(0)


func test_from_dict_keeps_a_null_pick_null_and_drops_bad_list_items() -> void:
	# Act
	var record: DraftRecord = DraftRecord.from_dict({"floor": 2.0, "kind": "bundle", "offered_ids": ["b1", 3], "picked_id": 5, "card_ids_added": "x"})

	# Assert
	assert_int(record.floor).is_equal(2)
	assert_object(record.picked_id).is_null()
	assert_array(Array(record.offered_ids)).is_equal(["b1"])
	assert_array(Array(record.card_ids_added)).is_empty()


# --- AC-28, and copies -------------------------------------------------------

func test_the_full_run_record_round_trips_byte_identically() -> void:
	# Arrange
	var record: Dictionary = _full_run_record()
	var first: String = JSON.stringify(record)

	# Act
	var second: String = JSON.stringify(RunRecord.to_dict(RunRecord.from_dict(JSON.parse_string(first))))

	# Assert
	assert_str(second).is_equal(first)


func test_the_full_run_record_fits_max_run_record_bytes() -> void:
	# Act
	var bytes: int = JSON.stringify(_full_run_record()).to_utf8_buffer().size()

	# Assert
	assert_int(bytes).is_less(int(RunHarness.run_config().max_run_record_bytes))


func test_the_full_run_record_holds_only_json_values() -> void:
	# Act
	var found: Array = _non_json(_full_run_record())

	# Assert
	assert_array(found).is_empty()


func test_to_dict_lists_are_copies(field: String, test_parameters := [["deck"], ["treasures"], ["boss_sequence"], ["band_split"], ["treasure_floors"]]) -> void:
	# Arrange
	_h.play_floor(_run)
	var size: int = (RunRecord.to_dict(_run.state)[field] as Array).size()
	var record: Dictionary = RunRecord.to_dict(_run.state)

	# Act
	(record[field] as Array).clear()

	# Assert
	assert_int((RunRecord.to_dict(_run.state)[field] as Array).size()).is_equal(size)


func test_draft_record_to_dict_lists_are_copies() -> void:
	# Arrange
	var record: DraftRecord = DraftRecord.make(1, DraftRecord.KIND_BUNDLE, ["b1"], "b1", ["c1"])
	var row: Dictionary = record.to_dict()

	# Act
	(row.offered_ids as Array).clear()
	(row.card_ids_added as Array).clear()

	# Assert
	assert_int(record.offered_ids.size()).is_equal(1)
	assert_int(record.card_ids_added.size()).is_equal(1)


func test_read_model_lists_are_copies() -> void:
	# Arrange
	var model: Dictionary = _run.state.read_model(_h.db, RunHarness.run_config())

	# Act
	(model.deck as Array).clear()

	# Assert
	assert_int(_run.state.deck.size()).is_equal(TestConstants.STARTER_DECK_SIZE)


func test_offer_read_model_ids_are_a_copy() -> void:
	# Arrange
	var offer: Offer = Offer.new()
	offer.option_ids.assign(["a", "b"])
	var model: Dictionary = offer.read_model(15, TestConstants.BUNDLE_CARD_COUNT, false)

	# Act
	(model.option_ids as Array).clear()

	# Assert
	assert_int(offer.option_ids.size()).is_equal(2)


# --- Edge Cases: truncation --------------------------------------------------

func _damage(entries: int) -> Dictionary:
	var damage: Dictionary = {}
	for i: int in entries:
		damage["card_%02d" % i] = i + 1
	return damage


func test_truncation_keeps_the_top_twenty_and_buckets_the_rest() -> void:
	# Arrange: 23 entries of 1..23, so the three lowest sum to 6
	var record: Dictionary = {"match_summaries": [{"damage_by_card": _damage(RunRecord.TRUNCATED_DAMAGE_ENTRIES + 3)}]}

	# Act
	var changed: bool = RunRecord.truncate_summaries(record)

	# Assert
	var kept: Dictionary = record.match_summaries[0].damage_by_card
	assert_bool(changed).is_true()
	assert_int(kept.size()).is_equal(RunRecord.TRUNCATED_DAMAGE_ENTRIES + 1)
	assert_int(int(kept[RunRecord.TRUNCATED_DAMAGE_BUCKET])).is_equal(6)
	assert_bool(kept.has("card_02")).is_false()
	assert_bool(kept.has("card_03")).is_true()


func test_truncation_leaves_a_short_table_alone() -> void:
	# Arrange
	var record: Dictionary = {"match_summaries": [{"damage_by_card": _damage(RunRecord.TRUNCATED_DAMAGE_ENTRIES)}]}

	# Act
	var changed: bool = RunRecord.truncate_summaries(record)

	# Assert
	assert_bool(changed).is_false()
	assert_bool((record.match_summaries[0].damage_by_card as Dictionary).has(RunRecord.TRUNCATED_DAMAGE_BUCKET)).is_false()


func test_a_record_past_the_cap_is_cut_in_the_save_warned_once_and_totals_see_it_all() -> void:
	# Arrange: every record is over a cap of one byte
	var harness := RunHarness.new()
	var run: RunMachine = harness.machine({"max_run_record_bytes": 1})
	assert_int(run.new_run(HERO, SEED)).is_equal(OK)
	var wide: Dictionary = _damage(RunRecord.TRUNCATED_DAMAGE_ENTRIES + 3)

	# Act
	harness.play_floor(run, 10, wide)
	harness.play_floor(run, 10, wide)

	# Assert
	var log: EventLog = run.run_log
	assert_int(RunHarness.warnings_of(log, RunCodes.W_RECORD_TRUNCATED).size()).is_equal(1)
	assert_bool((harness.meta.load_active_run().match_summaries[0].damage_by_card as Dictionary).has(RunRecord.TRUNCATED_DAMAGE_BUCKET)).is_true()
	assert_int((run.state.compute_totals().damage_by_card as Dictionary).size()).is_equal(wide.size())
	harness.release()


func test_compute_totals_skips_damaged_rows_without_failing() -> void:
	# Arrange: a save on its way to the archive
	var state: RunState = RunState.new()
	state.match_summaries.assign([{"turns": ["x"], "damage_by_card": {"a": ["y"], "b": 2}}, {"turns": 3}])

	# Act
	var totals: Dictionary = state.compute_totals()

	# Assert
	assert_int(int(totals.turns)).is_equal(3)
	assert_dict(totals.damage_by_card).is_equal({"b": 2})
	assert_int(int(totals.matches_played)).is_equal(2)
