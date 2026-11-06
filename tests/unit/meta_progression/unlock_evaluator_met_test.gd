## Unit tests for `UnlockEvaluator`'s pure reads (design/gdd/meta-progression.md M2,
## M3.1, F1, F6; AC-19, AC-24's arithmetic). The definitions are M10's, served by an
## in-memory database: what a real load does with them is
## `tests/integration/meta_progression/meta_unlock_stage7_test.gd`.
##
## AC-19 note: the expected sets below are AC-19's plus `first_victory`. D-03 / DD-X12
## moved Living Armory to `first_victory`, and the Open Questions row says "the M10
## table and AC-19 follow"; the AC text itself was not updated.
extends GdUnitTestSuite

const WAR: String = ProfileFixtures.HERO_WAR
const DECAY: String = ProfileFixtures.HERO_DECAY
const KNOWLEDGE: String = ProfileFixtures.HERO_KNOWLEDGE


func _evaluator() -> UnlockEvaluator:
	return UnlockEvaluator.new(ProfileFixtures.m10_database(), ProfileFixtures.knobs())


func _hero(wins: int, best_floor: int = 0) -> Dictionary:
	return {"runs_won": wins, "best_floor_reached": best_floor}


func _met_keys(stats: Dictionary) -> Array:
	return _evaluator().newly_met(stats, {})


func _sorted(keys: Array) -> Array:
	var copy: Array = keys.duplicate()
	copy.sort()
	return copy


# --- AC-19 ---------------------------------------------------------------------

func test_met_ac19_empty_stats_meet_nothing() -> void:
	# Act / Assert
	assert_array(_met_keys({})).is_empty()


func test_met_ac19_one_war_win() -> void:
	# Arrange
	var stats: Dictionary = {"runs_won": 1, "heroes": {WAR: _hero(1)}}

	# Act / Assert
	assert_array(_met_keys(stats)).is_equal(_sorted([ProfileFixtures.FIRST_VICTORY_KEY, ProfileFixtures.FORTUNE_KEY, ProfileFixtures.ORDER_KEY]))


func test_met_ac19_one_decay_win() -> void:
	# Arrange
	var stats: Dictionary = {"runs_won": 1, "heroes": {DECAY: _hero(1)}}

	# Act / Assert
	assert_array(_met_keys(stats)).is_equal(_sorted([ProfileFixtures.FIRST_VICTORY_KEY, ProfileFixtures.DECAY_WIN_KEY, ProfileFixtures.FORTUNE_KEY, ProfileFixtures.SHADOW_KEY]))


func test_met_ac19_floor_five_with_decay_and_knowledge() -> void:
	# Arrange
	var stats: Dictionary = {"heroes": {DECAY: _hero(0, 5), KNOWLEDGE: _hero(0, 5)}}

	# Act / Assert
	assert_array(_met_keys(stats)).is_equal([ProfileFixtures.DECAY_FLOOR_KEY])


func test_met_ac19_sixteen_kills_across_eight_bosses() -> void:
	# Arrange
	var stats: Dictionary = {"bosses": ProfileFixtures.bosses_map(16, 8)}

	# Act / Assert
	assert_array(_met_keys(stats)).is_equal([ProfileFixtures.BOSSES_KEY])


func test_met_ac19_fifteen_kills_across_sixteen_ids_is_cumulative_not_distinct() -> void:
	# Arrange
	var stats: Dictionary = {"bosses": ProfileFixtures.bosses_map(15, 16)}

	# Act / Assert
	assert_array(_met_keys(stats)).is_empty()


func test_met_ac19_three_wins_one_per_launch_hero() -> void:
	# Arrange
	var stats: Dictionary = {"runs_won": 3, "heroes": {WAR: _hero(1), DECAY: _hero(1), KNOWLEDGE: _hero(1)}}

	# Act / Assert
	assert_array(_met_keys(stats)).is_equal(_sorted([ProfileFixtures.FIRST_VICTORY_KEY, ProfileFixtures.DECAY_WIN_KEY, ProfileFixtures.KNOWLEDGE_WIN_KEY,
		ProfileFixtures.FORTUNE_KEY, ProfileFixtures.ORDER_KEY, ProfileFixtures.SHADOW_KEY]))


# --- F1 ------------------------------------------------------------------------

func test_met_always_holds_on_empty_stats() -> void:
	# Act / Assert
	assert_bool(_evaluator().met({"type": "always"}, {})).is_true()


func test_met_runs_won_compares_at_the_threshold() -> void:
	# Arrange
	var condition: Dictionary = ProfileFixtures.runs_won(2)

	# Act / Assert
	assert_bool(_evaluator().met(condition, {"runs_won": 1})).is_false()
	assert_bool(_evaluator().met(condition, {"runs_won": 2})).is_true()


func test_met_boss_defeated_default_n_is_one() -> void:
	# Arrange
	var condition: Dictionary = {"type": "boss_defeated", "boss_id": ProfileFixtures.BOSS_A}

	# Act / Assert
	assert_bool(_evaluator().met(condition, {"bosses": {ProfileFixtures.BOSS_B: {"defeated": 3}}})).is_false()
	assert_bool(_evaluator().met(condition, {"bosses": {ProfileFixtures.BOSS_A: {"defeated": 1}}})).is_true()


func test_met_treasure_picked_reads_the_pick_count() -> void:
	# Arrange
	var condition: Dictionary = {"type": "treasure_picked", "treasure_id": ProfileFixtures.TITHE, "n": 2}

	# Act / Assert
	assert_bool(_evaluator().met(condition, {"treasures": {ProfileFixtures.TITHE: {"picked": 1, "offered": 9}}})).is_false()
	assert_bool(_evaluator().met(condition, {"treasures": {ProfileFixtures.TITHE: {"picked": 2}}})).is_true()


func test_met_each_launch_needs_every_hero_with_a_null_unlock() -> void:
	# Arrange: Fortune has an unlock, so it is no launch hero and its zero does not count
	var condition: Dictionary = ProfileFixtures.runs_won(1, UnlockEvaluator.HERO_EACH_LAUNCH)
	var two_heroes: Dictionary = {"heroes": {WAR: _hero(1), DECAY: _hero(1)}}
	var three_heroes: Dictionary = {"heroes": {WAR: _hero(1), DECAY: _hero(1), KNOWLEDGE: _hero(1)}}

	# Act / Assert
	assert_bool(_evaluator().met(condition, two_heroes)).is_false()
	assert_bool(_evaluator().met(condition, three_heroes)).is_true()


func test_met_floor_reached_each_launch_takes_the_lowest_floor() -> void:
	# Arrange
	var condition: Dictionary = ProfileFixtures.floor_reached(5, UnlockEvaluator.HERO_EACH_LAUNCH)
	var stats: Dictionary = {"heroes": {WAR: _hero(0, 8), DECAY: _hero(0, 5), KNOWLEDGE: _hero(0, 4)}}

	# Act / Assert
	assert_bool(_evaluator().met(condition, stats)).is_false()
	stats.heroes[KNOWLEDGE]["best_floor_reached"] = 5
	assert_bool(_evaluator().met(condition, stats)).is_true()


func test_met_floor_reached_any_takes_the_best_of_any_hero() -> void:
	# Act / Assert
	assert_bool(_evaluator().met(ProfileFixtures.floor_reached(5), {"heroes": {DECAY: _hero(0, 6), WAR: _hero(0, 2)}})).is_true()
	assert_bool(_evaluator().met(ProfileFixtures.floor_reached(7), {"heroes": {DECAY: _hero(0, 6), WAR: _hero(0, 2)}})).is_false()


func test_met_all_of_needs_every_member_and_any_of_one() -> void:
	# Arrange
	var parts: Array = [ProfileFixtures.runs_won(1), ProfileFixtures.boss_defeated(ProfileFixtures.BOSS_A)]
	var stats: Dictionary = {"runs_won": 1}

	# Act / Assert
	assert_bool(_evaluator().met({"type": "all_of", "of": parts}, stats)).is_false()
	assert_bool(_evaluator().met({"type": "any_of", "of": parts}, stats)).is_true()


func test_met_f1_example_hero_shadow_turns_true_on_a_knowledge_win() -> void:
	# Arrange
	var evaluator: UnlockEvaluator = _evaluator()
	var condition: Dictionary = evaluator.definition(ProfileFixtures.SHADOW_KEY).condition
	var stats: Dictionary = {"heroes": {WAR: _hero(2), DECAY: _hero(0), KNOWLEDGE: _hero(0)}}

	# Act / Assert
	assert_bool(evaluator.met(condition, stats)).is_false()
	stats.heroes[KNOWLEDGE]["runs_won"] = 1
	assert_bool(evaluator.met(condition, stats)).is_true()


# --- M3.1 ----------------------------------------------------------------------

func test_newly_met_leaves_out_a_key_already_unlocked() -> void:
	# Arrange
	var unlocks: Dictionary = {ProfileFixtures.FORTUNE_KEY: {"unlocked": true}}

	# Act
	var keys: Array = _evaluator().newly_met({"runs_won": 1}, unlocks)

	# Assert
	assert_array(keys).is_equal([ProfileFixtures.FIRST_VICTORY_KEY])


func test_newly_met_includes_a_key_recorded_unlocked_false() -> void:
	# Arrange
	var unlocks: Dictionary = {ProfileFixtures.FIRST_VICTORY_KEY: {"unlocked": false}}

	# Act / Assert
	assert_array(_evaluator().newly_met({"runs_won": 1}, unlocks)).contains([ProfileFixtures.FIRST_VICTORY_KEY])


# --- Definition table ----------------------------------------------------------

func test_table_maps_records_to_their_keys_and_kinds() -> void:
	# Arrange
	var evaluator: UnlockEvaluator = _evaluator()

	# Act / Assert
	assert_str(evaluator.key_of(ProfileFixtures.ARMORY)).is_equal(ProfileFixtures.FIRST_VICTORY_KEY)
	assert_str(evaluator.key_of(WAR)).is_empty()
	assert_bool(evaluator.has_record(WAR)).is_true()
	assert_bool(evaluator.has_record("hero_nope")).is_false()
	assert_bool(evaluator.has_key("key_nope")).is_false()
	assert_str(String(evaluator.definition(ProfileFixtures.FORTUNE_KEY).kind)).is_equal("hero")
	assert_str(evaluator.definition(ProfileFixtures.DECAY_WIN_KEY).id).is_equal(ProfileFixtures.TITHE)


func test_ids_of_lists_a_kind_sorted() -> void:
	# Act
	var ids: Array = _evaluator().ids_of(&"hero")

	# Assert
	assert_int(ids.size()).is_equal(ProfileFixtures.m10_heroes().size())
	GameAssertions.assert_sorted_ascending(ids)


# --- F6 ------------------------------------------------------------------------

func test_progress_f6_example_eight_of_sixteen_is_a_half() -> void:
	# Arrange
	var evaluator: UnlockEvaluator = _evaluator()
	var condition: Dictionary = evaluator.definition(ProfileFixtures.BOSSES_KEY).condition

	# Act / Assert
	assert_float(evaluator.progress(condition, {"bosses": ProfileFixtures.bosses_map(8, 4)})).is_equal(0.5)


func test_progress_leaf_caps_at_one() -> void:
	# Act / Assert
	assert_float(_evaluator().progress(ProfileFixtures.runs_won(2), {"runs_won": 9})).is_equal(1.0)


func test_progress_always_is_one() -> void:
	# Act / Assert
	assert_float(_evaluator().progress({"type": "always"}, {})).is_equal(1.0)


func test_progress_all_of_is_the_mean_and_any_of_the_max() -> void:
	# Arrange
	var parts: Array = [ProfileFixtures.runs_won(2), ProfileFixtures.boss_defeated("any", 4)]
	var stats: Dictionary = {"runs_won": 2, "bosses": {ProfileFixtures.BOSS_A: {"defeated": 1}}}

	# Act / Assert: progresses 1.0 and 0.25
	assert_float(_evaluator().progress({"type": "all_of", "of": parts}, stats)).is_equal(0.625)
	assert_float(_evaluator().progress({"type": "any_of", "of": parts}, stats)).is_equal(1.0)


func test_progress_each_launch_is_the_minimum_across_launch_heroes() -> void:
	# Arrange
	var condition: Dictionary = ProfileFixtures.runs_won(4, UnlockEvaluator.HERO_EACH_LAUNCH)
	var stats: Dictionary = {"heroes": {WAR: _hero(4), DECAY: _hero(2), KNOWLEDGE: _hero(1)}}

	# Act / Assert
	assert_float(_evaluator().progress(condition, stats)).is_equal(0.25)


func test_read_model_lists_each_leaf_with_current_and_target() -> void:
	# Arrange
	var condition: Dictionary = {"type": "all_of", "of": [ProfileFixtures.runs_won(2), ProfileFixtures.boss_defeated(ProfileFixtures.BOSS_A, 3)]}
	var stats: Dictionary = {"runs_won": 1, "bosses": {ProfileFixtures.BOSS_A: {"defeated": 2}}}

	# Act
	var model: Dictionary = _evaluator().read_model(condition, stats)

	# Assert
	assert_bool(model.met).is_false()
	assert_array(model.parts).is_equal([
		{"type": "runs_won", "current": 1, "target": 2},
		{"type": "boss_defeated", "current": 2, "target": 3},
	])


func test_read_model_each_launch_lists_one_row_per_launch_hero() -> void:
	# Arrange
	var condition: Dictionary = ProfileFixtures.floor_reached(5, UnlockEvaluator.HERO_EACH_LAUNCH)

	# Act
	var parts: Array = _evaluator().read_model(condition, {"heroes": {DECAY: _hero(0, 3)}}).parts

	# Assert
	assert_array(parts.map(func(part: Dictionary) -> String: return part.hero_id)).contains_exactly_in_any_order(ProfileFixtures.LAUNCH_HEROES)
	var decay_row: Array = parts.filter(func(part: Dictionary) -> bool: return part.hero_id == DECAY)
	assert_int(decay_row[0].current).is_equal(3)


func test_hint_target_is_the_leaf_n_and_null_for_a_group_or_always() -> void:
	# Arrange
	var evaluator: UnlockEvaluator = _evaluator()

	# Act / Assert
	assert_int(evaluator.hint_target(ProfileFixtures.runs_won(3))).is_equal(3)
	assert_that(evaluator.hint_target({"type": "any_of", "of": [ProfileFixtures.runs_won(3)]})).is_null()
	assert_that(evaluator.hint_target({"type": "always"})).is_null()


func test_hint_text_key_names_the_condition_type() -> void:
	# Act / Assert
	assert_str(_evaluator().hint_text_key(ProfileFixtures.runs_won(3))).is_equal(UnlockEvaluator.TEXT_KEY_PREFIX + "runs_won")
