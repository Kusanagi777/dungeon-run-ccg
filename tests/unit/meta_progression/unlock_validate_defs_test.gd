## Unit tests for the M2.4 unlock validator, `UnlockEvaluator.validate_defs`
## (design/gdd/meta-progression.md M2.1, M2.2, M2.4; AC-25's rules). The same rules
## through a real stage-7b load are `meta_unlock_stage7_test.gd`.
extends GdUnitTestSuite

const HOST: String = ProfileFixtures.TITHE


func _db() -> ProfileFixtures.UnlockDatabase:
	return ProfileFixtures.UnlockDatabase.new([ProfileFixtures.hero_record(ProfileFixtures.HERO_WAR)], [ProfileFixtures.treasure_record(HOST)], [ProfileFixtures.BOSS_A])


func _def(condition: Variant, key: String = "unlock.test_key", host_kind: StringName = &"treasure") -> Dictionary:
	return {"host_kind": host_kind, "host_id": HOST, "unlock": {"key": key, "condition": condition}}


func _codes(rows: Array) -> Array:
	return rows.map(func(row: Dictionary) -> String: return String(row.code))


func _validate(def: Dictionary, knob_overrides: Dictionary = {}) -> Array:
	return UnlockEvaluator.validate_defs([def], _db(), ProfileFixtures.knobs(knob_overrides))


## [param depth] levels of `all_of` above a leaf at depth `depth + 1`.
func _nested(depth: int) -> Dictionary:
	var condition: Dictionary = ProfileFixtures.runs_won(1)
	for _level: int in depth:
		condition = {"type": "all_of", "of": [condition]}
	return condition


func _members(count: int) -> Array:
	var members: Array = []
	for _index: int in count:
		members.append(ProfileFixtures.runs_won(1))
	return members


func test_validate_null_unlock_passes() -> void:
	# Act / Assert
	assert_array(UnlockEvaluator.validate_defs([{"host_kind": &"hero", "host_id": ProfileFixtures.HERO_WAR, "unlock": null}], _db(), ProfileFixtures.knobs())).is_empty()


func test_validate_every_grammar_form_passes() -> void:
	# Arrange
	var condition: Dictionary = {"type": "any_of", "of": [
		{"type": "always"},
		ProfileFixtures.runs_won(1, ProfileFixtures.HERO_WAR),
		ProfileFixtures.runs_won(1, UnlockEvaluator.HERO_EACH_LAUNCH),
		ProfileFixtures.boss_defeated("any", 2),
		ProfileFixtures.floor_reached(5),
		{"type": "boss_defeated", "boss_id": ProfileFixtures.BOSS_A},
		{"type": "all_of", "of": [{"type": "treasure_picked", "treasure_id": HOST}]},
	]}

	# Act / Assert: a host other than the picked treasure, so no W_UNLOCK_SELF
	assert_array(_validate(_def(condition, "unlock.test_key", &"hero"))).is_empty()


func test_validate_unknown_boss_is_e_unlock_unknown_id_naming_the_key() -> void:
	# Act
	var rows: Array = _validate(_def(ProfileFixtures.boss_defeated("boss_nope")))

	# Assert (AC-25)
	assert_array(_codes(rows)).is_equal([String(UnlockEvaluator.E_UNLOCK_UNKNOWN_ID)])
	assert_str(rows[0].message).contains("unlock.test_key")
	assert_str(rows[0].message).contains("boss_nope")


func test_validate_unknown_hero_and_treasure_are_unknown_ids() -> void:
	# Act
	var hero: Array = _validate(_def(ProfileFixtures.runs_won(1, "hero_nope")))
	var treasure: Array = _validate(_def({"type": "treasure_picked", "treasure_id": "treasure_nope"}))

	# Assert
	assert_array(_codes(hero)).is_equal([String(UnlockEvaluator.E_UNLOCK_UNKNOWN_ID)])
	assert_array(_codes(treasure)).is_equal([String(UnlockEvaluator.E_UNLOCK_UNKNOWN_ID)])


func test_validate_depth_limit_is_inclusive_at_three_levels() -> void:
	# Arrange: max_condition_depth 3 counts the root as level 1

	# Act
	var at_limit: Array = _validate(_def(_nested(2)))
	var over: Array = _validate(_def(_nested(3)))

	# Assert (AC-25: "a condition nested 4 deep")
	assert_array(at_limit).is_empty()
	assert_array(_codes(over)).is_equal([String(UnlockEvaluator.E_UNLOCK_SHAPE)])


func test_validate_depth_limit_comes_from_the_knob() -> void:
	# Act
	var rows: Array = _validate(_def(_nested(3)), {"max_condition_depth": 4})

	# Assert
	assert_array(rows).is_empty()


func test_validate_of_takes_one_to_fan_out_members() -> void:
	# Act
	var empty: Array = _validate(_def({"type": "all_of", "of": []}))
	var one: Array = _validate(_def({"type": "all_of", "of": _members(1)}))
	var eight: Array = _validate(_def({"type": "any_of", "of": _members(8)}))
	var nine: Array = _validate(_def({"type": "any_of", "of": _members(9)}))

	# Assert (M2.2 "`of` has 1-8 members")
	assert_array(_codes(empty)).is_equal([String(UnlockEvaluator.E_UNLOCK_SHAPE)])
	assert_array(one).is_empty()
	assert_array(eight).is_empty()
	assert_array(_codes(nine)).is_equal([String(UnlockEvaluator.E_UNLOCK_SHAPE)])


func test_validate_fan_out_limit_comes_from_the_knob() -> void:
	# Act
	var rows: Array = _validate(_def({"type": "any_of", "of": _members(9)}), {"max_condition_fan_out": 9})

	# Assert
	assert_array(rows).is_empty()


func test_validate_n_runs_from_one_to_the_knob() -> void:
	# Act
	var zero: Array = _validate(_def({"type": "runs_won", "n": 0}))
	var top: Array = _validate(_def({"type": "runs_won", "n": 999}))
	var over: Array = _validate(_def({"type": "runs_won", "n": 1000}))
	var fraction: Array = _validate(_def({"type": "floor_reached", "n": 1.5}))
	var missing: Array = _validate(_def({"type": "runs_won"}))

	# Assert
	assert_array(top).is_empty()
	for rows: Array in [zero, over, fraction, missing]:
		assert_array(_codes(rows)).is_equal([String(UnlockEvaluator.E_UNLOCK_SHAPE)])


func test_validate_n_is_optional_where_the_grammar_defaults_it() -> void:
	# Act
	var boss: Array = _validate(_def({"type": "boss_defeated", "boss_id": "any"}))
	var picked: Array = _validate(_def({"type": "treasure_picked", "treasure_id": HOST}, "unlock.test_key", &"hero"))

	# Assert
	assert_array(boss).is_empty()
	assert_array(picked).is_empty()


func test_validate_unknown_type_is_a_shape_error() -> void:
	# Act / Assert
	assert_array(_codes(_validate(_def({"type": "nonsense"})))).is_equal([String(UnlockEvaluator.E_UNLOCK_SHAPE)])


func test_validate_unlock_must_be_key_and_condition() -> void:
	# Arrange
	var string_form: Dictionary = {"host_kind": &"treasure", "host_id": HOST, "unlock": "a_key"}
	var no_condition: Dictionary = {"host_kind": &"treasure", "host_id": HOST, "unlock": {"key": "a_key"}}

	# Act / Assert
	assert_array(_codes(_validate(string_form))).is_equal([String(UnlockEvaluator.E_UNLOCK_SHAPE)])
	assert_array(_codes(_validate(no_condition))).is_equal([String(UnlockEvaluator.E_UNLOCK_SHAPE)])


func test_validate_key_is_snake_case_with_dots_allowed() -> void:
	# Act / Assert
	assert_array(_validate(_def(ProfileFixtures.runs_won(1), "unlock.hero_fortune"))).is_empty()
	assert_array(_validate(_def(ProfileFixtures.runs_won(1), "hero_decay_first_win"))).is_empty()
	assert_array(_codes(_validate(_def(ProfileFixtures.runs_won(1), "Bad Key")))).is_equal([String(UnlockEvaluator.E_UNLOCK_SHAPE)])
	assert_array(_codes(_validate(_def(ProfileFixtures.runs_won(1), "")))).is_equal([String(UnlockEvaluator.E_UNLOCK_SHAPE)])


func test_validate_key_repeated_in_one_call_is_a_shape_error() -> void:
	# Arrange
	var defs: Array = [_def(ProfileFixtures.runs_won(1), "shared_key"), _def(ProfileFixtures.runs_won(2), "shared_key")]

	# Act
	var rows: Array = UnlockEvaluator.validate_defs(defs, _db(), ProfileFixtures.knobs())

	# Assert
	assert_array(_codes(rows)).is_equal([String(UnlockEvaluator.E_UNLOCK_SHAPE)])


func test_validate_key_held_by_two_records_across_files_is_a_shape_error() -> void:
	# Arrange: a hero and a treasure carry one key (M2.1 "unique across all three files")
	var hero: Dictionary = ProfileFixtures.hero_record("hero_fortune", "shared_key", ProfileFixtures.runs_won(1))
	var treasure: Dictionary = ProfileFixtures.treasure_record(HOST, "shared_key", ProfileFixtures.runs_won(1))
	var db: ProfileFixtures.UnlockDatabase = ProfileFixtures.UnlockDatabase.new([hero], [treasure])

	# Act
	var rows: Array = UnlockEvaluator.validate_defs([_def(ProfileFixtures.runs_won(1), "shared_key")], db, ProfileFixtures.knobs())

	# Assert
	assert_array(_codes(rows)).is_equal([String(UnlockEvaluator.E_UNLOCK_SHAPE)])


func test_validate_treasure_requiring_its_own_pick_is_only_a_warning() -> void:
	# Act
	var rows: Array = _validate(_def({"type": "treasure_picked", "treasure_id": HOST}))

	# Assert
	assert_array(_codes(rows)).is_equal([String(UnlockEvaluator.W_UNLOCK_SELF)])


func test_validate_hero_picking_a_treasure_is_no_self_reference() -> void:
	# Act / Assert
	assert_array(_validate(_def({"type": "treasure_picked", "treasure_id": HOST}, "unlock.test_key", &"hero"))).is_empty()


func test_validate_rows_carry_the_host_and_the_unlock_field() -> void:
	# Act
	var row: Dictionary = _validate(_def(ProfileFixtures.boss_defeated("boss_nope")))[0]

	# Assert
	assert_str(row.host_id).is_equal(HOST)
	assert_str(row.field).is_equal("unlock")


func test_validate_without_a_database_skips_the_id_lookups() -> void:
	# Act
	var rows: Array = UnlockEvaluator.validate_defs([_def(ProfileFixtures.boss_defeated("boss_nope"))], null, ProfileFixtures.knobs())

	# Assert
	assert_array(rows).is_empty()
