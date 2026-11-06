## Integration: `MetaFacade`, the rules half over a real store on scratch files
## (design/gdd/meta-progression.md M3, M5.3, M7, M8, F6; AC-15, AC-20 to AC-24, AC-26;
## Edge Cases "Statistics and unlocks"). Definitions are M10's, from an in-memory
## database; `meta_unlock_stage7_test.gd` runs them through a real load.
##
## AC-24 note: its last clause says `unlock_hint("treasure_living_armory")` has
## `target == 16`. That clause predates D-03 / DD-X12: M10 and treasures.md T8 give
## Living Armory `first_victory` (`runs_won >= 1`), so its target is 1, and the 16 belongs
## to the reserved key. The tests here follow M10.
extends GdUnitTestSuite

## Counts `newly_met` calls: AC-22's "evaluates nothing".
class CountingEvaluator:
	extends UnlockEvaluator

	var calls: int = 0

	func newly_met(stats: Dictionary, unlocks: Dictionary) -> Array:
		calls += 1
		return super(stats, unlocks)


const WAR: String = ProfileFixtures.HERO_WAR
const DECAY: String = ProfileFixtures.HERO_DECAY
const KNOWLEDGE: String = ProfileFixtures.HERO_KNOWLEDGE
const NEW_VERSION: String = "1.1"
const STALE_S: int = 90
const RUN_ID: String = "run_a"

var _root: String
var _clock: ProfileFixtures.ManualClock
var _granted: Array


func before_test() -> void:
	_root = ProfileFixtures.new_root()
	_clock = ProfileFixtures.ManualClock.new()
	_granted = []


func after_test() -> void:
	ProfileFixtures.remove_root(_root)


func _path(file: String) -> String:
	return _root.path_join(file)


func _facade(db: CardDatabase = ProfileFixtures.m10_database(), abandon_is_loss: bool = true) -> MetaFacade:
	var meta: MetaFacade = ProfileFixtures.facade(ProfileFixtures.store(_root, _clock), db, {}, abandon_is_loss)
	meta.unlock_granted.connect(_on_granted)
	return meta


func _on_granted(key: String, kind: StringName, id: String, by_run_id: String, retro: bool) -> void:
	_granted.append({"key": key, "kind": kind, "id": id, "by_run_id": by_run_id, "retro": retro})


func _loaded(db: CardDatabase = ProfileFixtures.m10_database(), abandon_is_loss: bool = true) -> MetaFacade:
	var meta: MetaFacade = _facade(db, abandon_is_loss)
	meta.load_profile()
	return meta


## A clean exit, then a new process.
func _restart(meta: MetaFacade, db: CardDatabase = ProfileFixtures.m10_database()) -> MetaFacade:
	meta.store().release_lock()
	return _loaded(db)


## A profile on disk already seen under the fixture data version.
func _write(overrides: Dictionary = {}) -> void:
	var profile: Dictionary = ProfileFixtures.profile_dict({"data_versions_seen": [ProfileFixtures.DATA_VERSION]})
	profile.merge(overrides, true)
	ProfileFixtures.write_profile(_root, profile)


func _on_disk() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(_path("profile.json")))


func _keys(rows: Array) -> Array:
	return rows.map(func(row: Dictionary) -> String: return row.key)


# --- AC-20 ---------------------------------------------------------------------

func _archive_the_sixteenth_kill() -> Dictionary:
	_write({"stats": ProfileFixtures.stats({"bosses": ProfileFixtures.bosses_map(15, 8)})})
	var meta: MetaFacade = _loaded()
	var summaries: Array = [ProfileFixtures.match_summary(ProfileFixtures.BOSS_A, true), ProfileFixtures.match_summary(ProfileFixtures.BOSS_B, false)]
	var outcome: Dictionary = meta.archive_run(ProfileFixtures.defeat(RUN_ID, WAR, 2, ProfileFixtures.BOSS_B, summaries))
	return {"meta": meta, "outcome": outcome}


func test_archive_ac20_grants_exactly_the_key_the_run_completed() -> void:
	# Act
	var outcome: Dictionary = _archive_the_sixteenth_kill().outcome

	# Assert
	assert_bool(outcome.ok).is_true()
	assert_array(outcome.unlocks_granted).is_equal([ProfileFixtures.BOSSES_KEY])


func test_archive_ac20_writes_the_grant_with_its_run() -> void:
	# Act
	var meta: MetaFacade = _archive_the_sixteenth_kill().meta

	# Assert
	var entry: Dictionary = meta.store().live_profile().unlocks[ProfileFixtures.BOSSES_KEY]
	assert_dict(entry).is_equal({"unlocked": true, "at": _clock.now, "by_run_id": RUN_ID, "retro": false})
	assert_int(entry.at).is_greater(0)


func test_archive_ac20_queues_one_notification_and_emits_once() -> void:
	# Act
	var meta: MetaFacade = _archive_the_sixteenth_kill().meta

	# Assert
	assert_array(meta.pending_notifications()).is_equal([{"key": ProfileFixtures.BOSSES_KEY, "kind": "treasure",
		"id": ProfileFixtures.RESERVED_TREASURE, "by_run_id": RUN_ID}])
	assert_array(_granted).is_equal([{"key": ProfileFixtures.BOSSES_KEY, "kind": &"treasure",
		"id": ProfileFixtures.RESERVED_TREASURE, "by_run_id": RUN_ID, "retro": false}])


func test_archive_persists_grant_and_notification_in_the_same_write_before_the_event() -> void:
	# Arrange: the signal handler reads the file at emission
	_write()
	var meta: MetaFacade = _loaded()
	var seen_on_disk: Array = []
	meta.unlock_granted.connect(func(key: String, _kind: StringName, _id: String, _run: String, _retro: bool) -> void:
		var on_disk: Dictionary = _on_disk()
		seen_on_disk.append([on_disk.unlocks.has(key), on_disk.pending_notifications.size()]))

	# Act
	meta.archive_run(ProfileFixtures.victory(RUN_ID, KNOWLEDGE))

	# Assert (M3.6)
	assert_array(seen_on_disk).is_not_empty()
	assert_array(seen_on_disk[0]).is_equal([true, seen_on_disk.size()])


func test_archive_the_same_run_again_grants_and_folds_nothing() -> void:
	# Arrange
	_write()
	var meta: MetaFacade = _loaded()
	var record: Dictionary = ProfileFixtures.victory(RUN_ID, DECAY)
	meta.archive_run(record)
	var stats: Dictionary = meta.get_stats()
	var queue: Array = meta.pending_notifications()
	_granted.clear()

	# Act
	var again: Dictionary = meta.archive_run(record)

	# Assert (AC-13)
	assert_dict(again).is_equal({"ok": true, "unlocks_granted": []})
	assert_dict(meta.get_stats()).is_equal(stats)
	assert_array(meta.pending_notifications()).is_equal(queue)
	assert_array(_granted).is_empty()


# --- AC-15 ---------------------------------------------------------------------

func test_archive_ac15_folds_through_the_facade() -> void:
	# Arrange
	var meta: MetaFacade = _loaded()

	# Act
	meta.archive_run(ProfileFixtures.victory("run_1", WAR, 61, 1400))
	meta.archive_run(ProfileFixtures.victory("run_2", WAR, 40, 900, "custom"))
	meta.archive_run(ProfileFixtures.defeat("run_3", DECAY, 4, "boss_x"))
	meta.archive_run(ProfileFixtures.abandoned("run_4", KNOWLEDGE, 2, "player"))
	meta.archive_run(ProfileFixtures.abandoned("run_5", KNOWLEDGE, 3, "data_version_mismatch"))

	# Assert
	var stats: Dictionary = meta.get_stats()
	assert_int(stats.runs_started).is_equal(5)
	assert_int(stats.runs_won).is_equal(2)
	assert_int(stats.runs_lost).is_equal(2)
	assert_int(stats.runs_void).is_equal(1)
	assert_int(meta.stats_for_hero(WAR).fastest_victory_s).is_equal(1400)
	assert_int(meta.stats_for_hero(KNOWLEDGE).best_floor_reached).is_equal(2)
	assert_int(stats.bosses["boss_x"].defeated_by).is_equal(1)
	assert_int(meta.run_log_count()).is_equal(5)


func test_archive_ac16_reads_the_abandon_knob_it_was_built_with() -> void:
	# Arrange
	var meta: MetaFacade = _loaded(ProfileFixtures.m10_database(), false)

	# Act
	meta.archive_run(ProfileFixtures.abandoned("run_1", WAR, 2, "player"))

	# Assert
	assert_int(meta.get_stats().runs_void).is_equal(1)
	assert_int(meta.get_stats().runs_lost).is_equal(0)


func test_archive_stats_survive_a_restart() -> void:
	# Arrange
	var meta: MetaFacade = _loaded()
	meta.archive_run(ProfileFixtures.victory(RUN_ID))
	var stats: Dictionary = meta.get_stats()

	# Act
	var next: MetaFacade = _restart(meta)

	# Assert
	assert_dict(next.get_stats()).is_equal(stats)


func test_archive_folds_a_record_as_run_record_serialises_it() -> void:
	# Arrange: the field names this system reads are Run Structure's (R1), so a record goes
	# through the real to_dict, with a seed above 2^53
	var source: Dictionary = ProfileFixtures.defeat(RUN_ID, DECAY, 3, ProfileFixtures.BOSS_B,
		[ProfileFixtures.match_summary(ProfileFixtures.BOSS_A, true)])
	source["run_seed_hex"] = "FFFFFFFFFFFFFF01"
	var record: Dictionary = RunRecord.to_dict(RunRecord.from_dict(source))
	var meta: MetaFacade = _loaded()

	# Act
	meta.archive_run(record)
	var next: MetaFacade = _restart(meta)

	# Assert
	var stats: Dictionary = next.get_stats()
	assert_int(stats.runs_lost).is_equal(1)
	assert_int(stats.heroes[DECAY].best_floor_reached).is_equal(3)
	assert_int(stats.bosses[ProfileFixtures.BOSS_A].defeated).is_equal(1)
	assert_int(stats.bosses[ProfileFixtures.BOSS_B].defeated_by).is_equal(1)
	assert_str(next.run_log_entry(RUN_ID).run_seed_hex).is_equal("FFFFFFFFFFFFFF01")


# --- AC-21 / M3.4 --------------------------------------------------------------

func test_archive_ac21_custom_seed_first_win_grants_and_sets_no_best() -> void:
	# Arrange
	_write()
	var meta: MetaFacade = _loaded()

	# Act
	var outcome: Dictionary = meta.archive_run(ProfileFixtures.victory(RUN_ID, DECAY, 50, 600, "custom"))

	# Assert
	assert_array(outcome.unlocks_granted).contains([ProfileFixtures.DECAY_WIN_KEY, ProfileFixtures.FORTUNE_KEY])
	assert_bool(meta.is_treasure_unlocked(ProfileFixtures.TITHE)).is_true()
	assert_array(meta.unlocked_keys()).contains([ProfileFixtures.DECAY_WIN_KEY])
	assert_that(meta.stats_for_hero(DECAY).fastest_victory_s).is_null()


func test_archive_grants_every_key_one_run_completes_with_that_run_id() -> void:
	# Arrange: F1's example, "granted in the same archive_run"
	_write()
	var meta: MetaFacade = _loaded()

	# Act
	var outcome: Dictionary = meta.archive_run(ProfileFixtures.victory(RUN_ID, KNOWLEDGE))

	# Assert
	var expected: Array = [ProfileFixtures.FIRST_VICTORY_KEY, ProfileFixtures.KNOWLEDGE_WIN_KEY, ProfileFixtures.FORTUNE_KEY, ProfileFixtures.SHADOW_KEY]
	assert_array(outcome.unlocks_granted).contains_exactly_in_any_order(expected)
	assert_array(_keys(_granted)).contains_exactly_in_any_order(expected)


func test_archive_unlock_kinds_follow_the_hosting_file() -> void:
	# Arrange
	_write()
	var meta: MetaFacade = _loaded()

	# Act
	meta.archive_run(ProfileFixtures.victory(RUN_ID, WAR))

	# Assert
	var kinds: Dictionary = {}
	for note: Dictionary in meta.pending_notifications():
		kinds[note.key] = note.kind
	assert_str(kinds[ProfileFixtures.FORTUNE_KEY]).is_equal("hero")
	assert_str(kinds[ProfileFixtures.FIRST_VICTORY_KEY]).is_equal("treasure")


func test_archive_system_abandon_cannot_grant() -> void:
	# Arrange: a key already met, waiting for an evaluation point
	_write({"stats": ProfileFixtures.stats({"runs_started": 1, "runs_won": 1})})
	var meta: MetaFacade = _loaded()

	# Act
	var outcome: Dictionary = meta.archive_run(ProfileFixtures.abandoned(RUN_ID, WAR, 2, "save_corrupt"))

	# Assert (M3.5)
	assert_array(outcome.unlocks_granted).is_empty()
	assert_array(meta.unlocked_keys()).is_empty()
	assert_array(meta.pending_notifications()).is_empty()


func test_archive_a_later_normal_run_grants_what_was_waiting() -> void:
	# Arrange
	_write({"stats": ProfileFixtures.stats({"runs_started": 1, "runs_won": 1})})
	var meta: MetaFacade = _loaded()

	# Act
	var outcome: Dictionary = meta.archive_run(ProfileFixtures.defeat(RUN_ID, WAR, 2, ProfileFixtures.BOSS_A))

	# Assert (M3.1a: every key not yet unlocked)
	assert_array(outcome.unlocks_granted).contains([ProfileFixtures.FIRST_VICTORY_KEY])


func test_settings_and_resume_never_evaluate() -> void:
	# Arrange: an unmet-on-file key that stats would meet
	_write({"stats": ProfileFixtures.stats({"runs_started": 1, "runs_won": 1})})
	var meta: MetaFacade = _loaded()

	# Act
	meta.set_setting(&"gamma", 1.2)
	meta.save_active_run({"run_id": RUN_ID})
	meta.load_active_run()
	meta.clear_active_run()

	# Assert (M3.1)
	assert_array(meta.unlocked_keys()).is_empty()


# --- AC-22 ---------------------------------------------------------------------

func _v1_1_database() -> ProfileFixtures.UnlockDatabase:
	var db: ProfileFixtures.UnlockDatabase = ProfileFixtures.m10_database()
	db.version = NEW_VERSION
	return db


func _write_one_win_under_v1_0() -> void:
	var hero: Dictionary = ProfileSchema.empty_hero_stats()
	hero["runs_won"] = 1
	_write({"stats": ProfileFixtures.stats({"runs_started": 1, "runs_won": 1, "heroes": {WAR: hero}})})


func test_load_ac22_new_data_version_grants_retroactively() -> void:
	# Arrange
	_write_one_win_under_v1_0()

	# Act
	var meta: MetaFacade = _loaded(_v1_1_database())

	# Assert
	var entry: Dictionary = meta.store().live_profile().unlocks[ProfileFixtures.FORTUNE_KEY]
	assert_dict(entry).is_equal({"unlocked": true, "at": _clock.now, "by_run_id": null, "retro": true})
	assert_array(_keys(meta.pending_notifications())).contains([ProfileFixtures.FORTUNE_KEY])
	assert_array(meta.store().live_profile().data_versions_seen).is_equal([ProfileFixtures.DATA_VERSION, NEW_VERSION])


func test_load_ac22_grant_and_seen_version_reach_the_file_and_the_signal() -> void:
	# Arrange
	_write_one_win_under_v1_0()

	# Act
	_loaded(_v1_1_database())

	# Assert
	var on_disk: Dictionary = _on_disk()
	assert_bool(on_disk.unlocks[ProfileFixtures.FORTUNE_KEY].unlocked).is_true()
	assert_array(on_disk.data_versions_seen).contains([NEW_VERSION])
	var fortune: Array = _granted.filter(func(row: Dictionary) -> bool: return row.key == ProfileFixtures.FORTUNE_KEY)
	assert_int(fortune.size()).is_equal(1)
	assert_bool(fortune[0].retro).is_true()
	assert_str(fortune[0].by_run_id).is_empty()


func test_load_ac22_loading_again_under_the_same_version_evaluates_nothing() -> void:
	# Arrange
	_write_one_win_under_v1_0()
	_loaded(_v1_1_database()).store().release_lock()
	var db: ProfileFixtures.UnlockDatabase = _v1_1_database()
	var evaluator: CountingEvaluator = CountingEvaluator.new(db, ProfileFixtures.knobs())
	var meta: MetaFacade = MetaFacade.new(ProfileFixtures.store(_root, _clock), evaluator, StatsFold.new(true))

	# Act
	meta.load_profile()

	# Assert
	assert_int(evaluator.calls).is_equal(0)
	assert_array(meta.store().live_profile().data_versions_seen).is_equal([ProfileFixtures.DATA_VERSION, NEW_VERSION])


func test_load_of_a_seen_version_evaluates_nothing_even_when_a_key_is_met() -> void:
	# Arrange
	_write_one_win_under_v1_0()

	# Act
	var meta: MetaFacade = _loaded()

	# Assert (M3.1: two evaluation moments only)
	assert_array(meta.unlocked_keys()).is_empty()


func test_load_new_version_with_nothing_met_still_records_the_version_on_disk() -> void:
	# Arrange
	_write()

	# Act
	_loaded(_v1_1_database())

	# Assert
	assert_array(_on_disk().data_versions_seen).contains([NEW_VERSION])


func test_load_fresh_install_records_the_version_and_writes_no_file() -> void:
	# Act
	var meta: MetaFacade = _loaded()

	# Assert (AC-1 through the facade)
	assert_str(String(meta.load_status())).is_equal(String(SaveErrors.STATUS_FRESH))
	assert_array(meta.store().live_profile().data_versions_seen).is_equal([ProfileFixtures.DATA_VERSION])
	assert_bool(FileAccess.file_exists(_path("profile.json"))).is_false()


func test_load_retro_grant_under_read_only_stays_in_memory() -> void:
	# Arrange
	_write_one_win_under_v1_0()
	var before: PackedByteArray = ProfileFixtures.read_bytes(_path("profile.json"))
	ProfileFixtures.write_foreign_lock(_root, _clock, 10)

	# Act
	var meta: MetaFacade = _loaded(_v1_1_database())

	# Assert (States "Profile: Loading")
	assert_bool(meta.is_unlocked(ProfileFixtures.FORTUNE_KEY)).is_true()
	assert_bool(meta.is_read_only()).is_true()
	assert_array(Array(ProfileFixtures.read_bytes(_path("profile.json")))).is_equal(Array(before))


func test_load_retro_grant_is_not_redone_by_a_later_archive() -> void:
	# Arrange
	_write_one_win_under_v1_0()
	var meta: MetaFacade = _loaded(_v1_1_database())
	_granted.clear()

	# Act
	var outcome: Dictionary = meta.archive_run(ProfileFixtures.defeat(RUN_ID, WAR, 1, ProfileFixtures.BOSS_A))

	# Assert
	assert_array(outcome.unlocks_granted).is_empty()
	assert_bool(meta.store().live_profile().unlocks[ProfileFixtures.FORTUNE_KEY].retro).is_true()


# --- AC-23 / M3.3 --------------------------------------------------------------

func _granted_entry() -> Dictionary:
	return {"unlocked": true, "at": ProfileFixtures.START_TIME, "by_run_id": "run_old", "retro": false}


func test_unlock_stays_when_its_condition_is_no_longer_met() -> void:
	# Arrange: zero stats, condition unmet, data version new so load evaluates
	_write({"unlocks": {ProfileFixtures.FIRST_VICTORY_KEY: _granted_entry()}})

	# Act
	var meta: MetaFacade = _loaded(_v1_1_database())

	# Assert
	assert_bool(meta.is_unlocked(ProfileFixtures.FIRST_VICTORY_KEY)).is_true()
	assert_dict(meta.store().live_profile().unlocks[ProfileFixtures.FIRST_VICTORY_KEY]).is_equal(_granted_entry())


func test_unlock_stays_through_a_clamp_of_its_stat() -> void:
	# Arrange
	var stats: Dictionary = ProfileFixtures.stats({"runs_won": -3})
	_write({"stats": stats, "unlocks": {ProfileFixtures.FIRST_VICTORY_KEY: _granted_entry()}})

	# Act
	var meta: MetaFacade = _loaded()
	meta.archive_run(ProfileFixtures.defeat(RUN_ID, WAR, 1, ProfileFixtures.BOSS_A))

	# Assert
	assert_bool(meta.is_unlocked(ProfileFixtures.FIRST_VICTORY_KEY)).is_true()


func test_unlock_progress_of_a_granted_key_is_met_though_its_condition_is_not() -> void:
	# Arrange
	_write({"unlocks": {ProfileFixtures.FIRST_VICTORY_KEY: _granted_entry()}})

	# Act
	var model: Dictionary = _loaded().unlock_progress(ProfileFixtures.FIRST_VICTORY_KEY)

	# Assert
	assert_bool(model.met).is_true()
	assert_float(model.progress).is_equal(1.0)


func test_orphaned_key_is_kept_in_the_file_and_in_the_set() -> void:
	# Arrange: no definition carries it any more
	_write({"unlocks": {"orphan_key": _granted_entry()}})

	# Act
	var meta: MetaFacade = _loaded()
	meta.save_profile()

	# Assert (States "Unlock key: Orphaned")
	assert_bool(_on_disk().unlocks.orphan_key.unlocked).is_true()
	assert_bool(meta.is_unlocked("orphan_key")).is_true()
	assert_float(meta.unlock_progress("orphan_key").progress).is_equal(1.0)


func test_edited_unlocked_true_with_an_unmet_condition_is_honoured() -> void:
	# Arrange
	_write({"unlocks": {ProfileFixtures.DECAY_WIN_KEY: _granted_entry()}})

	# Act
	var meta: MetaFacade = _loaded()

	# Assert (Edge Cases)
	assert_bool(meta.is_treasure_unlocked(ProfileFixtures.TITHE)).is_true()


# --- AC-24 / M3.7 / F6 ---------------------------------------------------------

func test_is_hero_unlocked_ac24_locked_false_launch_true() -> void:
	# Arrange
	var meta: MetaFacade = _loaded()

	# Act / Assert
	assert_bool(meta.is_hero_unlocked("hero_fortune")).is_false()
	assert_bool(meta.is_hero_unlocked(WAR)).is_true()


func test_is_hero_unlocked_opens_with_its_key_and_is_false_for_an_unknown_id() -> void:
	# Arrange
	var meta: MetaFacade = _loaded()

	# Act
	meta.archive_run(ProfileFixtures.victory(RUN_ID, WAR))

	# Assert
	assert_bool(meta.is_hero_unlocked("hero_fortune")).is_true()
	assert_bool(meta.is_hero_unlocked("hero_nope")).is_false()


func test_unlock_progress_ac24_eight_of_sixteen_bosses() -> void:
	# Arrange
	_write({"stats": ProfileFixtures.stats({"bosses": ProfileFixtures.bosses_map(8, 8)})})

	# Act
	var model: Dictionary = _loaded().unlock_progress(ProfileFixtures.BOSSES_KEY)

	# Assert
	assert_bool(model.met).is_false()
	assert_float(model.progress).is_equal(0.5)
	assert_array(model.parts).is_equal([{"type": "boss_defeated", "current": 8, "target": ProfileFixtures.BOSSES_N}])


func test_unlock_hint_ac24_reserved_key_carrier_reports_the_same_progress_and_target_16() -> void:
	# Arrange: the AC's clause, on the record that carries the key today
	_write({"stats": ProfileFixtures.stats({"bosses": ProfileFixtures.bosses_map(8, 8)})})

	# Act
	var hint: Dictionary = _loaded().unlock_hint(ProfileFixtures.RESERVED_TREASURE)

	# Assert
	assert_float(hint.progress).is_equal(0.5)
	assert_int(hint.target).is_equal(ProfileFixtures.BOSSES_N)
	assert_str(hint.text_key).is_equal(UnlockEvaluator.TEXT_KEY_PREFIX + "boss_defeated")


func test_unlock_hint_living_armory_is_first_victory_with_target_one() -> void:
	# Arrange: M10 / DD-X12, which AC-24's `target == 16` predates
	_write({"stats": ProfileFixtures.stats({"bosses": ProfileFixtures.bosses_map(8, 8)})})

	# Act
	var hint: Dictionary = _loaded().unlock_hint(ProfileFixtures.ARMORY)

	# Assert
	assert_int(hint.target).is_equal(1)
	assert_float(hint.progress).is_equal(0.0)
	assert_bool(hint.met).is_false()


func test_unlock_hint_takes_a_hero_id_a_treasure_id_or_a_key() -> void:
	# Arrange
	var meta: MetaFacade = _loaded()

	# Act / Assert (M1.3 "accepts a hero/treasure id as well as a key")
	assert_int(meta.unlock_hint("hero_fortune").target).is_equal(1)
	assert_int(meta.unlock_hint(ProfileFixtures.BELL).target).is_equal(5)
	assert_int(meta.unlock_hint(ProfileFixtures.DECAY_FLOOR_KEY).target).is_equal(5)


func test_unlock_hint_of_an_open_record_is_met_with_no_text() -> void:
	# Act
	var hint: Dictionary = _loaded().unlock_hint(ProfileFixtures.OPEN_TREASURE)

	# Assert
	assert_bool(hint.met).is_true()
	assert_str(hint.text_key).is_empty()
	assert_that(hint.target).is_null()


func test_unlock_hint_of_an_unknown_name_is_unmet() -> void:
	# Act
	var hint: Dictionary = _loaded().unlock_hint("nothing_by_this_name")

	# Assert
	assert_bool(hint.met).is_false()
	assert_float(hint.progress).is_equal(0.0)


func test_unlocked_ids_lists_open_records_and_earned_ones() -> void:
	# Arrange
	var meta: MetaFacade = _loaded()
	var before: Array = meta.unlocked_ids(&"treasure")

	# Act
	meta.archive_run(ProfileFixtures.victory(RUN_ID, DECAY))

	# Assert
	assert_array(before).is_equal([ProfileFixtures.OPEN_TREASURE])
	# An 8-floor Decay win also reaches floor 5 (F3), so the Bell opens with it
	assert_array(meta.unlocked_ids(&"treasure")).contains_exactly_in_any_order([ProfileFixtures.OPEN_TREASURE, ProfileFixtures.TITHE,
		ProfileFixtures.BELL, ProfileFixtures.ARMORY])
	assert_array(meta.unlocked_ids(&"hero")).contains(ProfileFixtures.LAUNCH_HEROES)
	assert_array(meta.unlocked_ids(&"hero")).not_contains(["hero_order"])


func test_unlocked_keys_are_sorted() -> void:
	# Arrange
	var meta: MetaFacade = _loaded()

	# Act
	meta.archive_run(ProfileFixtures.victory(RUN_ID, KNOWLEDGE))

	# Assert
	GameAssertions.assert_sorted_ascending(meta.unlocked_keys())


func test_is_treasure_unlocked_is_false_for_a_locked_or_unknown_id() -> void:
	# Arrange
	var meta: MetaFacade = _loaded()

	# Act / Assert
	assert_bool(meta.is_treasure_unlocked(ProfileFixtures.TITHE)).is_false()
	assert_bool(meta.is_treasure_unlocked("treasure_nope")).is_false()
	assert_bool(meta.is_treasure_unlocked(ProfileFixtures.OPEN_TREASURE)).is_true()


# --- AC-26 ---------------------------------------------------------------------

func test_ack_ac26_queue_stays_empty_across_a_restart() -> void:
	# Arrange
	_write()
	var meta: MetaFacade = _loaded()
	meta.archive_run(ProfileFixtures.victory(RUN_ID, WAR))
	for note: Dictionary in meta.pending_notifications():
		meta.ack_notification(note.key)

	# Act
	var next: MetaFacade = _restart(meta)

	# Assert
	assert_array(next.pending_notifications()).is_empty()


func test_crash_before_the_ack_ac26_keeps_the_entry() -> void:
	# Arrange
	_write()
	var meta: MetaFacade = _loaded()
	var outcome: Dictionary = meta.archive_run(ProfileFixtures.victory(RUN_ID, WAR))

	# Act: no ack, no clean exit, the crashed lock goes stale
	_clock.advance(STALE_S)
	var next: MetaFacade = _loaded()

	# Assert
	assert_array(_keys(next.pending_notifications())).contains_exactly_in_any_order(outcome.unlocks_granted)


func test_load_drops_a_notification_of_a_key_no_data_defines() -> void:
	# Arrange
	var live: Dictionary = {"key": ProfileFixtures.DECAY_WIN_KEY, "kind": "treasure", "id": ProfileFixtures.TITHE, "by_run_id": "run_old"}
	var gone: Dictionary = {"key": "key_removed_from_data", "kind": "treasure", "id": "treasure_gone", "by_run_id": "run_old"}
	_write({"pending_notifications": [gone, live]})

	# Act
	var meta: MetaFacade = _loaded()

	# Assert (Edge Cases)
	assert_array(meta.pending_notifications()).is_equal([live])


func test_load_drops_a_post_v1_hero_notification_while_no_data_defines_the_key() -> void:
	# Arrange: shipped data has no Fortune; the key is named by the GDD, not by the data
	var db: ProfileFixtures.UnlockDatabase = ProfileFixtures.UnlockDatabase.new(
		[ProfileFixtures.hero_record(WAR)], [ProfileFixtures.treasure_record(ProfileFixtures.OPEN_TREASURE)])
	_write({"pending_notifications": [{"key": ProfileFixtures.FORTUNE_KEY, "kind": "hero", "id": "hero_fortune", "by_run_id": null}]})

	# Act
	var meta: MetaFacade = _loaded(db)

	# Assert (Edge Cases "holds a key no longer in data: dropped")
	assert_array(meta.pending_notifications()).is_empty()


# --- M5.3 rebuild --------------------------------------------------------------

## A stats record that repairs [param bad_counters] times, with bosses `boss_00`…
func _tampered_stats(bad_counters: int) -> Dictionary:
	var bosses: Dictionary = {}
	for index: int in bad_counters:
		bosses["boss_%02d" % index] = {"defeated": -1, "defeated_by": 0}
	return ProfileFixtures.stats({"runs_started": 9, "runs_won": 9, "bosses": bosses,
		"bests": {"fastest_victory_s": 1, "fewest_turns_victory": 1}})


func _rebuild_log() -> Array:
	return [ProfileFixtures.victory("run_1", DECAY, 44, 700), ProfileFixtures.defeat("run_2", WAR, 3, ProfileFixtures.BOSS_A)]


func test_load_above_max_repairs_rebuilds_stats_from_the_log_and_flags_it() -> void:
	# Arrange: one over max_repairs_before_rebuild (25)
	_write({"stats": _tampered_stats(26), "run_log": _rebuild_log()})

	# Act
	var meta: MetaFacade = _loaded()

	# Assert
	var stats: Dictionary = meta.get_stats()
	assert_int(stats.rebuilt_at).is_equal(_clock.now)
	assert_int(stats.heroes[DECAY].runs_won).is_equal(1)
	assert_int(stats.bosses[ProfileFixtures.BOSS_A].defeated_by).is_equal(1)
	assert_int(stats.heroes[WAR].best_floor_reached).is_equal(3)


func test_load_at_exactly_max_repairs_does_not_rebuild() -> void:
	# Arrange
	_write({"stats": _tampered_stats(25), "run_log": _rebuild_log()})

	# Act
	var meta: MetaFacade = _loaded()

	# Assert ("> max_repairs_before_rebuild")
	assert_bool(meta.get_stats().has("rebuilt_at")).is_false()
	assert_bool(meta.get_stats().heroes.has(DECAY)).is_false()


func test_rebuild_keeps_the_larger_monotone_counter_and_takes_rebuilt_bests() -> void:
	# Arrange: the log is capped, so it under-counts runs_won (M7.5)
	_write({"stats": _tampered_stats(26), "run_log": _rebuild_log()})

	# Act
	var stats: Dictionary = _loaded().get_stats()

	# Assert
	assert_int(stats.runs_won).is_equal(9)
	assert_int(stats.runs_started).is_equal(9)
	assert_int(stats.bests.fastest_victory_s).is_equal(700)
	assert_int(stats.bests.fewest_turns_victory).is_equal(44)


func test_rebuild_relocks_nothing() -> void:
	# Arrange
	_write({"stats": _tampered_stats(26), "run_log": [], "unlocks": {ProfileFixtures.BOSSES_KEY: _granted_entry()}})

	# Act
	var meta: MetaFacade = _loaded()

	# Assert
	assert_bool(meta.is_unlocked(ProfileFixtures.BOSSES_KEY)).is_true()


func test_rebuilt_stats_reach_the_file_on_the_next_write() -> void:
	# Arrange
	_write({"stats": _tampered_stats(26), "run_log": _rebuild_log()})
	var meta: MetaFacade = _loaded()

	# Act
	meta.save_profile()

	# Assert
	assert_int(int(_on_disk().stats.rebuilt_at)).is_equal(_clock.now)


# --- Reads ---------------------------------------------------------------------

func test_stats_for_hero_of_a_hero_never_played_is_zeros() -> void:
	# Act
	var hero: Dictionary = _loaded().stats_for_hero(KNOWLEDGE)

	# Assert
	assert_dict(hero).is_equal(ProfileSchema.empty_hero_stats())


func test_last_hero_id_is_the_latest_played_or_null() -> void:
	# Arrange
	var meta: MetaFacade = _loaded()
	var none: Variant = meta.last_hero_id()
	var earlier: Dictionary = ProfileFixtures.victory("run_1", DECAY)
	earlier["ended_at"] = ProfileFixtures.START_TIME + 5
	var later: Dictionary = ProfileFixtures.victory("run_2", WAR)
	later["ended_at"] = ProfileFixtures.START_TIME + 50
	var last: Dictionary = ProfileFixtures.victory("run_3", KNOWLEDGE)
	last["ended_at"] = ProfileFixtures.START_TIME + 20

	# Act
	meta.archive_run(earlier)
	meta.archive_run(later)
	meta.archive_run(last)

	# Assert: argmax of last_played_at, not the archive order
	assert_that(none).is_null()
	assert_str(meta.last_hero_id()).is_equal(WAR)


func test_get_stats_hands_out_a_copy() -> void:
	# Arrange
	var meta: MetaFacade = _loaded()

	# Act
	meta.get_stats()["runs_won"] = 500

	# Assert
	assert_int(meta.get_stats().runs_won).is_equal(0)


# --- Reset ---------------------------------------------------------------------

func test_reset_clears_unlocks_and_the_queue() -> void:
	# Arrange
	var meta: MetaFacade = _loaded()
	meta.archive_run(ProfileFixtures.victory(RUN_ID, WAR))

	# Act
	var outcome: Error = meta.reset_profile(ProfileFixtures.RESET_TOKEN)

	# Assert
	assert_int(outcome).is_equal(OK)
	assert_array(meta.unlocked_keys()).is_empty()
	assert_array(meta.pending_notifications()).is_empty()
	assert_int(meta.get_stats().runs_won).is_equal(0)


func test_reset_publishes_the_default_settings() -> void:
	# Arrange
	var meta: MetaFacade = _loaded()
	meta.set_setting(&"gamma", 1.2)

	# Act
	meta.reset_profile(ProfileFixtures.RESET_TOKEN)

	# Assert
	assert_float(meta.settings_bus.get_setting(&"gamma")).is_equal(ProfileFixtures.settings_defaults().gamma)


func test_reset_publishes_empty_bindings_so_input_map_returns_to_the_defaults() -> void:
	# Arrange: Boot re-applies on settings_changed{bindings}; a rebind must not outlive reset
	var meta: MetaFacade = _loaded()
	meta.set_setting(&"bindings", {"ui_accept": []})
	var published: Array = []
	meta.settings_bus.settings_changed.connect(func(key: StringName, value: Variant) -> void:
		if key == &"bindings":
			published.append(value))

	# Act
	meta.reset_profile(ProfileFixtures.RESET_TOKEN)

	# Assert
	assert_array(published).is_equal([{}])


func test_load_publishes_every_setting_for_late_consumers() -> void:
	# Arrange
	var profile: Dictionary = ProfileFixtures.profile_dict()
	profile.settings["gamma"] = 1.3
	ProfileFixtures.write_profile(_root, profile)

	# Act
	var meta: MetaFacade = _loaded()

	# Assert
	assert_float(meta.settings_bus.get_setting(&"gamma")).is_equal(1.3)


func test_settings_bus_is_the_stores_bus() -> void:
	# Arrange
	var meta: MetaFacade = _facade()

	# Act / Assert
	assert_object(meta.settings_bus).is_same(meta.store().settings_bus)
