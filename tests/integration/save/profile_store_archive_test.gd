## Integration: the run slot and the archive on real files (design/gdd/meta-progression.md
## M8, F4, `archive_run` transition order; AC-10 to AC-13; Edge Cases "user://runs/ cannot
## be written", "`run_log_cap` is lowered"). The rules callback is a recording stand-in
## here: the fold and grants through it are `meta_facade_rules_test.gd`.
extends GdUnitTestSuite

const TOP_CARDS: int = 10
const DAMAGE_KEYS: int = 30
const CAP: int = 200
const HEAVY_KEYS: Array[String] = ["run_log", "rng_snapshot", "draft_state", "treasure_state"]

var _root: String
var _clock: ProfileFixtures.ManualClock
var _writer: ProfileFixtures.FaultWriter


func before_test() -> void:
	_root = ProfileFixtures.new_root()
	_clock = ProfileFixtures.ManualClock.new()
	_writer = ProfileFixtures.FaultWriter.new()


func after_test() -> void:
	ProfileFixtures.remove_root(_root)


func _path(file: String) -> String:
	return _root.path_join(file)


func _store(knob_overrides: Dictionary = {}) -> ProfileStore:
	var store: ProfileStore = ProfileFixtures.store(_root, _clock, knob_overrides, _writer)
	store.load_profile()
	return store


func _restart(store: ProfileStore, knob_overrides: Dictionary = {}) -> ProfileStore:
	store.release_lock()
	return _store(knob_overrides)


func _record_path(run_id: String) -> String:
	return _path(ProfileStore.RUNS_DIR).path_join(run_id + ".json")


func _seq_on_disk() -> int:
	return int(JSON.parse_string(FileAccess.get_file_as_string(_path("profile.json"))).write_seq)


## A profile on disk with [param count] archived runs `run_000`… and matching stats.
func _store_with_log(count: int, knob_overrides: Dictionary = {}) -> ProfileStore:
	var log: Array = []
	for index: int in count:
		log.append(ProfileFixtures.victory("run_%03d" % index))
	var stats: Dictionary = ProfileFixtures.stats({"runs_started": count, "runs_won": count})
	ProfileFixtures.write_profile(_root, ProfileFixtures.profile_dict({"run_log": log, "stats": stats}))
	return _store(knob_overrides)


# --- AC-10 ---------------------------------------------------------------------

func test_active_run_survives_a_restart_equal_to_the_one_saved() -> void:
	# Arrange
	var store: ProfileStore = _store()
	var record: Dictionary = ProfileFixtures.full_record("run_a")

	# Act
	var saved: Error = store.save_active_run(record)
	var restarted: ProfileStore = _restart(store)

	# Assert
	assert_int(saved).is_equal(OK)
	assert_dict(restarted.load_active_run()).is_equal(record)


func test_cleared_active_run_is_null_after_a_restart() -> void:
	# Arrange
	var store: ProfileStore = _store()
	store.save_active_run({"run_id": "run_a"})

	# Act
	store.clear_active_run()
	var restarted: ProfileStore = _restart(store)

	# Assert
	assert_that(restarted.load_active_run()).is_null()


func test_load_active_run_hands_out_a_copy() -> void:
	# Arrange
	var store: ProfileStore = _store()
	store.save_active_run({"run_id": "run_a", "deck": ["card_a"]})

	# Act
	store.load_active_run().deck.append("card_b")

	# Assert
	assert_array(store.load_active_run().deck).is_equal(["card_a"])


func test_save_active_run_keeps_its_own_copy_of_the_record() -> void:
	# Arrange
	var store: ProfileStore = _store()
	var record: Dictionary = {"run_id": "run_a", "deck": ["card_a"]}
	store.save_active_run(record)

	# Act
	record.deck.append("card_b")

	# Assert
	assert_array(store.load_active_run().deck).is_equal(["card_a"])


func test_clear_with_an_empty_slot_writes_nothing() -> void:
	# Arrange
	var store: ProfileStore = _store()

	# Act
	store.clear_active_run()

	# Assert
	assert_bool(FileAccess.file_exists(_path("profile.json"))).is_false()


# --- AC-11 ---------------------------------------------------------------------

func test_archive_stored_run_lacks_the_four_heavy_keys() -> void:
	# Arrange
	var store: ProfileStore = _store()

	# Act
	store.archive_run(ProfileFixtures.full_record("run_a", DAMAGE_KEYS))

	# Assert
	var stored: Dictionary = store.run_log_entry("run_a")
	for key: String in HEAVY_KEYS:
		assert_bool(stored.has(key)).override_failure_message(key).is_false()


func test_archive_truncates_each_summary_to_the_top_cards_plus_others() -> void:
	# Arrange
	var store: ProfileStore = _store()
	var record: Dictionary = ProfileFixtures.full_record("run_a", DAMAGE_KEYS)
	var damage: Dictionary = ProfileFixtures.damage_map(DAMAGE_KEYS)
	var dropped: int = 0
	for index: int in range(TOP_CARDS, DAMAGE_KEYS):
		dropped += int(damage["card_%02d" % index])

	# Act
	store.archive_run(record)

	# Assert
	var stored: Dictionary = store.run_log_entry("run_a")
	assert_int(stored.match_summaries.size()).is_equal(ProfileFixtures.FLOORS_PER_RUN)
	for summary: Dictionary in stored.match_summaries:
		assert_int(summary.damage_by_card.size()).is_equal(TOP_CARDS + 1)
		assert_int(summary.damage_by_card[ProfileStore.OTHERS_KEY]).is_equal(dropped)
		assert_int(summary.damage_by_card["card_00"]).is_equal(damage["card_00"])
		assert_bool(summary.damage_by_card.has("card_%02d" % TOP_CARDS)).is_false()


func test_archive_keeps_the_whole_run_totals() -> void:
	# Arrange
	var store: ProfileStore = _store()
	var record: Dictionary = ProfileFixtures.full_record("run_a", DAMAGE_KEYS)

	# Act
	store.archive_run(record)

	# Assert
	assert_dict(store.run_log_entry("run_a").totals.damage_by_card).is_equal(record.totals.damage_by_card)


func test_archive_keeps_everything_else_verbatim() -> void:
	# Arrange
	var store: ProfileStore = _store()
	var record: Dictionary = ProfileFixtures.full_record("run_a", DAMAGE_KEYS)

	# Act
	store.archive_run(record)

	# Assert
	var stored: Dictionary = store.run_log_entry("run_a")
	for key: String in ["run_id", "run_seed_hex", "seed_source", "hero_id", "boss_sequence", "deck", "treasures", "drafts",
			"match_attempts", "started_at", "ended_at", "play_seconds", "result", "schema_version", "data_version"]:
		assert_that(stored[key]).override_failure_message(key).is_equal(record[key])


func test_archive_breaks_a_damage_tie_by_card_id() -> void:
	# Arrange: top 5 of ten equal cards; a stable, seed-independent cut
	var store: ProfileStore = _store({"archive_top_cards": 5})
	var damage: Dictionary = {}
	for index: int in [3, 1, 2, 0, 9, 8, 7, 6, 5, 4]:
		damage["card_%d" % index] = 4
	var summary: Dictionary = ProfileFixtures.match_summary(ProfileFixtures.BOSS_A, true, damage)

	# Act
	var entry: Dictionary = store.archived_form(ProfileFixtures.run_record("run_a", {"match_summaries": [summary]}))

	# Assert
	var kept: Array = entry.match_summaries[0].damage_by_card.keys()
	assert_array(kept).contains_exactly_in_any_order(["card_0", "card_1", "card_2", "card_3", "card_4", ProfileStore.OTHERS_KEY])


func test_archive_a_short_damage_table_still_gets_others_zero() -> void:
	# Arrange
	var store: ProfileStore = _store()
	var summary: Dictionary = ProfileFixtures.match_summary(ProfileFixtures.BOSS_A, true, {"card_a": 9})

	# Act
	var entry: Dictionary = store.archived_form(ProfileFixtures.run_record("run_a", {"match_summaries": [summary]}))

	# Assert
	assert_dict(entry.match_summaries[0].damage_by_card).is_equal({"card_a": 9, ProfileStore.OTHERS_KEY: 0})


func test_archive_does_not_change_the_record_it_is_given() -> void:
	# Arrange
	var store: ProfileStore = _store()
	var record: Dictionary = ProfileFixtures.full_record("run_a", DAMAGE_KEYS)
	var before: Dictionary = record.duplicate(true)

	# Act
	store.archive_run(record)

	# Assert
	assert_dict(record).is_equal(before)


func test_archive_writes_the_complete_record_to_runs() -> void:
	# Arrange
	var store: ProfileStore = _store()
	var record: Dictionary = ProfileFixtures.full_record("run_a", DAMAGE_KEYS)

	# Act
	store.archive_run(record)

	# Assert
	var on_disk: Dictionary = ProfileSchema.normalised(JSON.parse_string(FileAccess.get_file_as_string(_record_path("run_a"))))
	assert_dict(on_disk).is_equal(record)


func test_archive_writes_the_run_record_before_the_profile() -> void:
	# Arrange: the profile write fails, the run record must already be there (M8.2)
	var store: ProfileStore = _store()
	store.save_profile()
	var seq_before: int = _seq_on_disk()
	_writer.fail_at("W7")

	# Act
	var outcome: Dictionary = store.archive_run(ProfileFixtures.full_record("run_a"))

	# Assert: the run record needs no rotation, so it is written; the profile is not
	assert_bool(outcome.ok).is_false()
	assert_bool(FileAccess.file_exists(_record_path("run_a"))).is_true()
	assert_int(_seq_on_disk()).is_equal(seq_before)


func test_archive_with_keep_run_records_off_writes_no_record() -> void:
	# Arrange
	var store: ProfileStore = _store()
	store.set_setting(&"keep_run_records", false)

	# Act
	store.archive_run(ProfileFixtures.full_record("run_a"))

	# Assert
	assert_bool(DirAccess.dir_exists_absolute(_path(ProfileStore.RUNS_DIR))).is_false()
	assert_int(store.run_log_count()).is_equal(1)


func test_archive_run_record_failure_does_not_block_the_profile_write() -> void:
	# Arrange: the first stage fails (the run record), the profile write then succeeds
	var store: ProfileStore = _store()
	_writer.fail_at("W4", 1)

	# Act
	var outcome: Dictionary = store.archive_run(ProfileFixtures.full_record("run_a"))

	# Assert (Edge Cases "user://runs/ cannot be written")
	assert_bool(outcome.ok).is_true()
	assert_bool(FileAccess.file_exists(_record_path("run_a"))).is_false()
	assert_int(_restart(store).run_log_count()).is_equal(1)


func test_clear_run_records_deletes_the_folder_contents() -> void:
	# Arrange
	var store: ProfileStore = _store()
	store.archive_run(ProfileFixtures.full_record("run_a"))
	store.archive_run(ProfileFixtures.full_record("run_b"))

	# Act
	var outcome: Error = store.clear_run_records()

	# Assert
	assert_int(outcome).is_equal(OK)
	assert_array(Array(DirAccess.get_files_at(_path(ProfileStore.RUNS_DIR)))).is_empty()
	assert_int(store.run_log_count()).is_equal(2)


# --- AC-12 ---------------------------------------------------------------------

func test_archive_at_the_cap_drops_index_zero_and_appends_last() -> void:
	# Arrange
	var store: ProfileStore = _store_with_log(CAP)

	# Act
	store.archive_run(ProfileFixtures.victory("run_new"), func(profile: Dictionary, _record: Dictionary) -> Array:
		profile.stats["runs_started"] = int(profile.stats.runs_started) + 1
		return [])

	# Assert
	var log: Array = store.run_log(0, CAP + 1)
	assert_int(log.size()).is_equal(CAP)
	assert_str(log[0].run_id).is_equal("run_001")
	assert_str(log[CAP - 1].run_id).is_equal("run_new")
	assert_that(store.run_log_entry("run_000")).is_null()
	assert_int(store.live_profile().stats.runs_started).is_equal(CAP + 1)


func test_archive_under_the_cap_prunes_nothing() -> void:
	# Arrange
	var store: ProfileStore = _store_with_log(CAP - 1)

	# Act
	store.archive_run(ProfileFixtures.victory("run_new"))

	# Assert
	assert_int(store.run_log_count()).is_equal(CAP)
	assert_str(store.run_log(0, 1)[0].run_id).is_equal("run_000")


func test_archive_prunes_to_a_lowered_cap_in_one_step() -> void:
	# Arrange (Edge Cases "`run_log_cap` is lowered in data")
	var store: ProfileStore = _store_with_log(30, {"run_log_cap": 20})

	# Act
	store.archive_run(ProfileFixtures.victory("run_new"))

	# Assert
	assert_int(store.run_log_count()).is_equal(20)
	assert_str(store.run_log(0, 1)[0].run_id).is_equal("run_011")


func test_pruning_leaves_stats_and_the_pruned_run_record_alone() -> void:
	# Arrange
	var store: ProfileStore = _store({"run_log_cap": 1})
	store.archive_run(ProfileFixtures.victory("run_a"))

	# Act
	store.archive_run(ProfileFixtures.victory("run_b"))

	# Assert (F4)
	assert_that(store.run_log_entry("run_a")).is_null()
	assert_bool(FileAccess.file_exists(_record_path("run_a"))).is_true()


# --- AC-13 ---------------------------------------------------------------------

func test_archive_twice_returns_ok_and_changes_nothing() -> void:
	# Arrange
	var store: ProfileStore = _store()
	var calls: Array = []
	var rules: Callable = func(_profile: Dictionary, _record: Dictionary) -> Array:
		calls.append(1)
		return ["a_key"]
	var record: Dictionary = ProfileFixtures.victory("run_a")
	store.archive_run(record, rules)
	var seq: int = _seq_on_disk()
	var before: Dictionary = store.live_profile().duplicate(true)

	# Act
	var again: Dictionary = store.archive_run(record, rules)

	# Assert
	assert_bool(again.ok).is_true()
	assert_array(again.unlocks_granted).is_empty()
	assert_int(calls.size()).is_equal(1)
	assert_int(_seq_on_disk()).is_equal(seq)
	assert_dict(store.live_profile()).is_equal(before)


func test_archive_retried_after_a_failed_write_writes_again() -> void:
	# Arrange
	var store: ProfileStore = _store()
	store.save_profile()
	_writer.fail_at("W7")
	var record: Dictionary = ProfileFixtures.victory("run_a")
	var first: Dictionary = store.archive_run(record)
	_writer.clear()

	# Act
	var second: Dictionary = store.archive_run(record)

	# Assert
	assert_bool(first.ok).is_false()
	assert_bool(second.ok).is_true()
	assert_int(_restart(store).run_log_count()).is_equal(1)


func test_archive_without_a_run_id_is_refused() -> void:
	# Arrange
	var store: ProfileStore = _store()

	# Act
	var outcome: Dictionary = store.archive_run({"hero_id": ProfileFixtures.HERO_WAR})

	# Assert
	assert_bool(outcome.ok).is_false()
	assert_int(store.run_log_count()).is_equal(0)


# --- Run log reads -------------------------------------------------------------

func test_run_log_pages_newest_last() -> void:
	# Arrange
	var store: ProfileStore = _store_with_log(5)

	# Act
	var page: Array = store.run_log(1, 2)

	# Assert
	assert_array(page.map(func(row: Dictionary) -> String: return row.run_id)).is_equal(["run_001", "run_002"])


func test_run_log_past_the_end_and_with_no_limit_is_empty() -> void:
	# Arrange
	var store: ProfileStore = _store_with_log(2)

	# Act / Assert
	assert_array(store.run_log(5, 2)).is_empty()
	assert_array(store.run_log(0, 0)).is_empty()


func test_run_log_rows_are_copies() -> void:
	# Arrange
	var store: ProfileStore = _store_with_log(1)

	# Act
	store.run_log(0, 1)[0]["run_id"] = "changed"
	store.run_log_entry("run_000")["hero_id"] = "changed"

	# Assert
	assert_str(store.run_log(0, 1)[0].run_id).is_equal("run_000")
	assert_str(store.run_log(0, 1)[0].hero_id).is_equal(ProfileFixtures.HERO_WAR)


func test_entry_newer_than_this_build_is_kept_opaque_and_flagged() -> void:
	# Arrange (M4.4, Edge Cases: "details unavailable")
	var newer: Dictionary = ProfileFixtures.victory("run_a")
	newer["schema_version"] = ProfileMigrations.RUN_RECORD_SCHEMA_VERSION + 1
	newer["future_field"] = "kept"
	ProfileFixtures.write_profile(_root, ProfileFixtures.profile_dict({"run_log": [newer]}))

	# Act
	var row: Dictionary = _store().run_log_entry("run_a")

	# Assert
	assert_bool(row.details_unavailable).is_true()
	assert_str(row.future_field).is_equal("kept")


func test_entry_of_this_build_is_not_flagged() -> void:
	# Arrange
	var store: ProfileStore = _store_with_log(1)

	# Act / Assert
	assert_bool(store.run_log_entry("run_000").has("details_unavailable")).is_false()
