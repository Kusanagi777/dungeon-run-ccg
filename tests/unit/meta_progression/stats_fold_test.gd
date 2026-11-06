## Unit tests for `StatsFold` (design/gdd/meta-progression.md M7, F2, F3;
## AC-15, AC-16, AC-17): a pure fold over `stats`, so no file and no clock here.
extends GdUnitTestSuite

const WAR: String = ProfileFixtures.HERO_WAR
const DECAY: String = ProfileFixtures.HERO_DECAY
const KNOWLEDGE: String = ProfileFixtures.HERO_KNOWLEDGE
const BOSS_X: String = "boss_x"
## AC-15's fixture values.
const WAR_TURNS: int = 61
const WAR_SECONDS: int = 1400
const CUSTOM_TURNS: int = 40
const CUSTOM_SECONDS: int = 900
const DECAY_FLOOR: int = 4
const KNOWLEDGE_FLOOR: int = 2


func _folded(records: Array, abandon_is_loss: bool = true) -> Dictionary:
	var stats: Dictionary = ProfileSchema.empty_stats()
	var fold: StatsFold = StatsFold.new(abandon_is_loss)
	for record: Dictionary in records:
		fold.fold(stats, record)
	return stats


## AC-15's five records.
func _ac15_records() -> Array:
	return [
		ProfileFixtures.victory("run_1", WAR, WAR_TURNS, WAR_SECONDS),
		ProfileFixtures.victory("run_2", WAR, CUSTOM_TURNS, CUSTOM_SECONDS, "custom"),
		ProfileFixtures.defeat("run_3", DECAY, DECAY_FLOOR, BOSS_X),
		ProfileFixtures.abandoned("run_4", KNOWLEDGE, KNOWLEDGE_FLOOR, "player"),
		ProfileFixtures.abandoned("run_5", KNOWLEDGE, KNOWLEDGE_FLOOR + 1, "data_version_mismatch"),
	]


# --- AC-15 ---------------------------------------------------------------------

func test_fold_ac15_global_counters_split_five_runs() -> void:
	# Act
	var stats: Dictionary = _folded(_ac15_records())

	# Assert
	assert_int(stats.runs_started).is_equal(5)
	assert_int(stats.runs_won).is_equal(2)
	assert_int(stats.runs_lost).is_equal(2)
	assert_int(stats.runs_void).is_equal(1)


func test_fold_ac15_custom_seed_counts_but_is_not_a_best() -> void:
	# Act
	var stats: Dictionary = _folded(_ac15_records())

	# Assert
	var war: Dictionary = stats.heroes[WAR]
	assert_int(war.runs_won).is_equal(2)
	assert_int(war.fastest_victory_s).is_equal(WAR_SECONDS)
	assert_int(war.fewest_turns_victory).is_equal(WAR_TURNS)
	assert_int(stats.bests.fastest_victory_s).is_equal(WAR_SECONDS)
	assert_int(stats.bests.fewest_turns_victory).is_equal(WAR_TURNS)


func test_fold_ac15_defeat_and_player_abandon_set_their_floors() -> void:
	# Act
	var stats: Dictionary = _folded(_ac15_records())

	# Assert
	assert_int(stats.heroes[DECAY].best_floor_reached).is_equal(DECAY_FLOOR)
	assert_int(stats.heroes[KNOWLEDGE].runs_lost).is_equal(1)
	assert_int(stats.heroes[KNOWLEDGE].best_floor_reached).is_equal(KNOWLEDGE_FLOOR)
	assert_int(stats.bosses[BOSS_X].defeated_by).is_equal(1)


# --- AC-16 ---------------------------------------------------------------------

func test_fold_player_abandon_is_void_when_abandon_is_not_a_loss() -> void:
	# Act
	var stats: Dictionary = _folded([ProfileFixtures.abandoned("run_1", WAR, 2, "player")], false)

	# Assert
	assert_int(stats.runs_void).is_equal(1)
	assert_int(stats.runs_lost).is_equal(0)
	assert_int(stats.heroes[WAR].runs_lost).is_equal(0)


func test_fold_player_abandon_is_a_loss_when_abandon_counts() -> void:
	# Act
	var stats: Dictionary = _folded([ProfileFixtures.abandoned("run_1", WAR, 2, "player")], true)

	# Assert
	assert_int(stats.runs_lost).is_equal(1)
	assert_int(stats.runs_void).is_equal(0)


func test_is_void_reads_the_abandon_knob_for_a_player_abandon_only() -> void:
	# Arrange
	var player: Dictionary = ProfileFixtures.abandoned("run_1", WAR, 2, "player")
	var system: Dictionary = ProfileFixtures.abandoned("run_2", WAR, 2, "save_corrupt")

	# Act / Assert
	assert_bool(StatsFold.new(true).is_void(player)).is_false()
	assert_bool(StatsFold.new(false).is_void(player)).is_true()
	assert_bool(StatsFold.new(true).is_void(system)).is_true()
	assert_bool(StatsFold.new(true).is_void(ProfileFixtures.victory("run_3"))).is_false()


# --- AC-17 / F3 ----------------------------------------------------------------

func test_floor_reached_of_a_victory_is_floors_per_run() -> void:
	# Arrange: result carries no floor_reached (an older record)
	var record: Dictionary = ProfileFixtures.run_record("run_1", {"result": {"outcome": "victory"}})

	# Act / Assert
	assert_int(StatsFold.floor_reached(record)).is_equal(ProfileFixtures.FLOORS_PER_RUN)


func test_floor_reached_of_a_defeat_is_the_result_floor() -> void:
	# Act / Assert
	assert_int(StatsFold.floor_reached(ProfileFixtures.defeat("run_1", WAR, 5, BOSS_X))).is_equal(5)


func test_floor_reached_falls_back_to_floors_cleared_plus_one() -> void:
	# Arrange
	var record: Dictionary = ProfileFixtures.run_record("run_1", {"result": {"outcome": "defeat", "floors_cleared": 3}})

	# Act / Assert
	assert_int(StatsFold.floor_reached(record)).is_equal(4)


func test_fold_sets_best_floor_from_a_victory_and_keeps_the_maximum() -> void:
	# Act
	var stats: Dictionary = _folded([ProfileFixtures.victory("run_1"), ProfileFixtures.defeat("run_2", WAR, 5, BOSS_X)])

	# Assert
	assert_int(stats.heroes[WAR].best_floor_reached).is_equal(ProfileFixtures.FLOORS_PER_RUN)


# --- F2 ------------------------------------------------------------------------

func test_fold_system_abandon_stops_after_started_and_void() -> void:
	# Arrange: a system abandon with everything a normal run would fold
	var record: Dictionary = ProfileFixtures.abandoned("run_1", WAR, 4, "save_corrupt")
	record["match_summaries"] = [ProfileFixtures.match_summary(BOSS_X, true)]
	record["drafts"] = [{"kind": "treasure", "picked_id": "treasure_a", "offered_ids": ["treasure_a"]}]
	record["totals"] = {"turns": 30, "damage_by_card": {}}
	record["play_seconds"] = 500

	# Act
	var stats: Dictionary = _folded([record])

	# Assert (M3.5, F2 "system abandon: stop here")
	assert_int(stats.runs_started).is_equal(1)
	assert_int(stats.runs_void).is_equal(1)
	assert_int(stats.total_turns).is_equal(0)
	assert_int(stats.total_play_seconds).is_equal(0)
	assert_dict(stats.bosses).is_empty()
	assert_dict(stats.treasures).is_empty()
	assert_int(stats.heroes[WAR].best_floor_reached).is_equal(0)


func test_fold_f2_example_decay_defeat_on_floor_four() -> void:
	# Arrange: F2's example
	var summaries: Array = [ProfileFixtures.match_summary("boss_1", true), ProfileFixtures.match_summary("boss_2", true),
		ProfileFixtures.match_summary("boss_3", true), ProfileFixtures.match_summary("boss_4", false)]

	# Act
	var stats: Dictionary = _folded([ProfileFixtures.defeat("run_1", DECAY, 4, "boss_4", summaries)])

	# Assert
	assert_int(stats.runs_started).is_equal(1)
	assert_int(stats.runs_lost).is_equal(1)
	for boss_id: String in ["boss_1", "boss_2", "boss_3"]:
		assert_int(stats.bosses[boss_id].defeated).is_equal(1)
	assert_int(stats.bosses["boss_4"].defeated).is_equal(0)
	assert_int(stats.bosses["boss_4"].defeated_by).is_equal(1)
	assert_that(stats.heroes[DECAY].fastest_victory_s).is_null()


func test_fold_reads_a_match_win_from_the_engine_winner_field() -> void:
	# Arrange: the log's reduction carries `winner`, which outranks `result`
	var won: Dictionary = ProfileFixtures.match_summary("boss_1", false)
	won["winner"] = "PLAYER"
	var lost: Dictionary = ProfileFixtures.match_summary("boss_2", true)
	lost["winner"] = "BOSS"

	# Act
	var stats: Dictionary = _folded([ProfileFixtures.run_record("run_1", {"match_summaries": [won, lost]})])

	# Assert
	assert_int(stats.bosses["boss_1"].defeated).is_equal(1)
	assert_bool(stats.bosses.has("boss_2")).is_false()


func test_fold_counts_treasure_picks_and_offers_and_skips_bundles() -> void:
	# Arrange
	var drafts: Array = [
		{"kind": "treasure", "picked_id": "treasure_a", "offered_ids": ["treasure_a", "treasure_b"]},
		{"kind": "bundle", "picked_id": "bundle_a", "offered_ids": ["bundle_a"]},
		{"kind": "treasure", "picked_id": null, "offered_ids": ["treasure_b"]},
	]

	# Act
	var stats: Dictionary = _folded([ProfileFixtures.run_record("run_1", {"drafts": drafts})])

	# Assert
	assert_int(stats.treasures["treasure_a"].picked).is_equal(1)
	assert_int(stats.treasures["treasure_a"].offered).is_equal(1)
	assert_int(stats.treasures["treasure_b"].picked).is_equal(0)
	assert_int(stats.treasures["treasure_b"].offered).is_equal(2)
	assert_bool(stats.treasures.has("bundle_a")).is_false()


func test_fold_sums_turns_and_play_seconds_of_non_void_runs() -> void:
	# Act
	var stats: Dictionary = _folded([ProfileFixtures.victory("run_1", WAR, 10, 100), ProfileFixtures.victory("run_2", WAR, 20, 200)])

	# Assert
	assert_int(stats.total_turns).is_equal(30)
	assert_int(stats.total_play_seconds).is_equal(300)


func test_fold_bests_only_go_down() -> void:
	# Act
	var stats: Dictionary = _folded([ProfileFixtures.victory("run_1", WAR, 40, 900), ProfileFixtures.victory("run_2", WAR, 60, 1200), ProfileFixtures.victory("run_3", WAR, 50, 800)])

	# Assert: each best takes its own minimum, from different runs
	assert_int(stats.heroes[WAR].fastest_victory_s).is_equal(800)
	assert_int(stats.heroes[WAR].fewest_turns_victory).is_equal(40)


func test_fold_only_custom_seeds_leaves_bests_null() -> void:
	# Act
	var stats: Dictionary = _folded([ProfileFixtures.victory("run_1", WAR, 40, 900, "custom")])

	# Assert (Edge Cases "If the only runs are custom-seed")
	assert_that(stats.heroes[WAR].fastest_victory_s).is_null()
	assert_that(stats.heroes[WAR].fewest_turns_victory).is_null()
	assert_that(stats.bests.fastest_victory_s).is_null()
	assert_int(stats.heroes[WAR].best_floor_reached).is_equal(ProfileFixtures.FLOORS_PER_RUN)


func test_fold_zero_match_abandon_reaches_floor_one_with_no_boss_counts() -> void:
	# Act
	var stats: Dictionary = _folded([ProfileFixtures.abandoned("run_1", WAR, 1, "player")])

	# Assert (Edge Cases "zero match_summaries")
	assert_int(stats.runs_lost).is_equal(1)
	assert_int(stats.heroes[WAR].best_floor_reached).is_equal(1)
	assert_dict(stats.bosses).is_empty()


func test_fold_stamps_last_played_with_the_record_end() -> void:
	# Arrange
	var record: Dictionary = ProfileFixtures.victory("run_1")

	# Act
	var stats: Dictionary = _folded([record])

	# Assert
	assert_int(stats.heroes[WAR].last_played_at).is_equal(record.ended_at)


# --- M7.5 rebuild --------------------------------------------------------------

func test_rebuilt_recounts_the_log_from_empty() -> void:
	# Arrange
	var log: Array = [ProfileFixtures.victory("run_1", WAR, 40, 900), ProfileFixtures.defeat("run_2", DECAY, 3, BOSS_X)]

	# Act
	var rebuilt: Dictionary = StatsFold.new(true).rebuilt(log, ProfileSchema.empty_stats())

	# Assert
	assert_int(rebuilt.runs_started).is_equal(2)
	assert_int(rebuilt.runs_won).is_equal(1)
	assert_int(rebuilt.runs_lost).is_equal(1)
	assert_int(rebuilt.bosses[BOSS_X].defeated_by).is_equal(1)


func test_rebuilt_keeps_the_larger_old_value_of_a_monotone_counter() -> void:
	# Arrange: the capped log under-counts the lifetime total
	var old: Dictionary = ProfileFixtures.stats({"runs_started": 50, "runs_won": 30, "heroes": {WAR: {"runs_won": 30, "best_floor_reached": 8}},
		"bosses": {"boss_gone": {"defeated": 7, "defeated_by": 1}}})

	# Act
	var rebuilt: Dictionary = StatsFold.new(true).rebuilt([ProfileFixtures.victory("run_1")], old)

	# Assert
	assert_int(rebuilt.runs_started).is_equal(50)
	assert_int(rebuilt.runs_won).is_equal(30)
	assert_int(rebuilt.heroes[WAR].runs_won).is_equal(30)
	assert_int(rebuilt.bosses["boss_gone"].defeated).is_equal(7)


func test_rebuilt_takes_the_log_value_of_a_best_over_the_old_one() -> void:
	# Arrange: a tampered best lower than any archived run
	var old: Dictionary = ProfileFixtures.stats({"heroes": {WAR: ProfileSchema.empty_hero_stats()},
		"bests": {"fastest_victory_s": 1, "fewest_turns_victory": 1}})
	old.heroes[WAR]["fastest_victory_s"] = 1
	old.heroes[WAR]["fewest_turns_victory"] = 1

	# Act
	var rebuilt: Dictionary = StatsFold.new(true).rebuilt([ProfileFixtures.victory("run_1", WAR, 44, 700)], old)

	# Assert (M7.5 "the rebuilt value for bests")
	assert_int(rebuilt.heroes[WAR].fastest_victory_s).is_equal(700)
	assert_int(rebuilt.heroes[WAR].fewest_turns_victory).is_equal(44)
	assert_int(rebuilt.bests.fastest_victory_s).is_equal(700)
	assert_int(rebuilt.bests.fewest_turns_victory).is_equal(44)


func test_rebuilt_skips_an_entry_newer_than_this_build() -> void:
	# Arrange
	var newer: Dictionary = ProfileFixtures.victory("run_1")
	newer["schema_version"] = ProfileMigrations.RUN_RECORD_SCHEMA_VERSION + 1

	# Act
	var rebuilt: Dictionary = StatsFold.new(true).rebuilt([newer], ProfileSchema.empty_stats())

	# Assert (M4.4: a newer entry is opaque)
	assert_int(rebuilt.runs_started).is_equal(0)
