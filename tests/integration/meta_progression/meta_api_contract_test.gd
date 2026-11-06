## Integration: the `MetaApi` contract, one suite over both implementations (ADR-0004
## Verification, "`MetaStub` and `MetaFacade` satisfy the same contract"; ADR-0011
## Decision 4). Every test runs each case on a `MetaStub` and on a `MetaFacade` over a
## scratch store: a consumer codes against `MetaApi` and never downcasts, so what is
## asserted here is what either one may be relied on for.
##
## It lives under `tests/integration/` because the facade side touches real files; the
## ADR's `tests/unit/meta/` path predates that rule. Behaviour only the facade has
## (grants, the fold, the log) is `meta_facade_rules_test.gd`.
extends GdUnitTestSuite

const HERO_STATS_KEYS: Array[String] = ["runs_started", "runs_won", "runs_lost", "best_floor_reached",
	"fastest_victory_s", "fewest_turns_victory", "last_played_at"]
const LOAD_STATUSES: Array[StringName] = [SaveErrors.STATUS_OK, SaveErrors.STATUS_RECOVERED_BAK, SaveErrors.STATUS_FRESH,
	SaveErrors.STATUS_FRESH_AFTER_CORRUPT, SaveErrors.STATUS_SCHEMA_NEWER, SaveErrors.STATUS_LOCKED]

var _root: String
var _clock: ProfileFixtures.ManualClock


func before_test() -> void:
	_root = ProfileFixtures.new_root()
	_clock = ProfileFixtures.ManualClock.new()


func after_test() -> void:
	ProfileFixtures.remove_root(_root)


## `[label, MetaApi]` rows, both loaded.
func _implementations() -> Array:
	var db: ProfileFixtures.UnlockDatabase = ProfileFixtures.m10_database()
	var stub: MetaApi = MetaStub.new(db)
	var facade: MetaApi = ProfileFixtures.facade(ProfileFixtures.store(_root, _clock), db)
	stub.load_profile()
	facade.load_profile()
	return [["MetaStub", stub], ["MetaFacade", facade]]


func test_load_profile_answers_a_known_status_with_a_profile() -> void:
	for row: Array in _implementations():
		# Act
		var loaded: Dictionary = row[1].load_profile()

		# Assert
		assert_array(LOAD_STATUSES).override_failure_message(row[0]).contains([loaded.status])
		assert_bool(loaded.profile is Dictionary).override_failure_message(row[0]).is_true()
		assert_str(String(row[1].load_status())).override_failure_message(row[0]).is_equal(String(loaded.status))


func test_load_profile_carries_settings_and_the_active_run() -> void:
	for row: Array in _implementations():
		# Act
		var profile: Dictionary = row[1].load_profile().profile

		# Assert
		assert_bool(profile.has("settings")).override_failure_message(row[0]).is_true()
		assert_bool(profile.has("active_run")).override_failure_message(row[0]).is_true()


func test_settings_bus_is_set() -> void:
	for row: Array in _implementations():
		# Act / Assert
		assert_object(row[1].settings_bus).override_failure_message(row[0]).is_not_null()


func test_save_profile_is_ok() -> void:
	for row: Array in _implementations():
		# Act / Assert
		assert_int(row[1].save_profile()).override_failure_message(row[0]).is_equal(OK)


func test_empty_slot_loads_null() -> void:
	for row: Array in _implementations():
		# Act / Assert
		assert_that(row[1].load_active_run()).override_failure_message(row[0]).is_null()


func test_active_run_round_trips_and_clears() -> void:
	# Arrange
	var record: Dictionary = {"run_id": "run_a", "deck": ["card_a"]}
	for row: Array in _implementations():
		# Act
		var saved: Error = row[1].save_active_run(record)
		var loaded: Variant = row[1].load_active_run()
		row[1].clear_active_run()

		# Assert
		assert_int(saved).override_failure_message(row[0]).is_equal(OK)
		assert_dict(loaded).override_failure_message(row[0]).is_equal(record)
		assert_that(row[1].load_active_run()).override_failure_message(row[0]).is_null()


func test_active_run_copies_in_and_out() -> void:
	for row: Array in _implementations():
		# Arrange
		var record: Dictionary = {"run_id": "run_a", "deck": ["card_a"]}
		row[1].save_active_run(record)

		# Act
		record.deck.append("changed_in")
		row[1].load_active_run().deck.append("changed_out")

		# Assert
		assert_array(row[1].load_active_run().deck).override_failure_message(row[0]).is_equal(["card_a"])


func test_archive_run_answers_ok_and_a_key_list() -> void:
	for row: Array in _implementations():
		# Act
		var outcome: Dictionary = row[1].archive_run(ProfileFixtures.victory("run_a"))

		# Assert
		assert_bool(outcome.ok).override_failure_message(row[0]).is_true()
		assert_bool(outcome.unlocks_granted is Array).override_failure_message(row[0]).is_true()


func test_archive_run_of_the_same_id_grants_nothing_the_second_time() -> void:
	# Arrange
	var record: Dictionary = ProfileFixtures.victory("run_a")
	for row: Array in _implementations():
		row[1].archive_run(record)

		# Act
		var again: Dictionary = row[1].archive_run(record)

		# Assert
		assert_dict(again).override_failure_message(row[0]).is_equal({"ok": true, "unlocks_granted": []})


func test_launch_heroes_are_unlocked_and_an_unknown_hero_is_not() -> void:
	for row: Array in _implementations():
		# Act / Assert
		for hero_id: String in ProfileFixtures.LAUNCH_HEROES:
			assert_bool(row[1].is_hero_unlocked(hero_id)).override_failure_message(row[0]).is_true()
		assert_bool(row[1].is_hero_unlocked("hero_nope")).override_failure_message(row[0]).is_false()


func test_open_treasure_is_available_and_an_unknown_treasure_is_not() -> void:
	for row: Array in _implementations():
		# Act / Assert
		assert_bool(row[1].is_treasure_unlocked(ProfileFixtures.OPEN_TREASURE)).override_failure_message(row[0]).is_true()
		assert_bool(row[1].is_treasure_unlocked("treasure_nope")).override_failure_message(row[0]).is_false()


func test_unlocked_ids_are_sorted_and_hold_the_open_records() -> void:
	for row: Array in _implementations():
		# Act
		var heroes: Array = row[1].unlocked_ids(&"hero")
		var treasures: Array = row[1].unlocked_ids(&"treasure")

		# Assert
		assert_array(heroes).override_failure_message(row[0]).contains(ProfileFixtures.LAUNCH_HEROES)
		assert_array(treasures).override_failure_message(row[0]).contains([ProfileFixtures.OPEN_TREASURE])
		GameAssertions.assert_sorted_ascending(heroes)
		GameAssertions.assert_sorted_ascending(treasures)


func test_unlocked_keys_is_a_sorted_array_of_strings() -> void:
	for row: Array in _implementations():
		# Act
		var keys: Array = row[1].unlocked_keys()

		# Assert
		assert_int(keys.filter(func(key: Variant) -> bool: return not key is String).size()).override_failure_message(row[0]).is_equal(0)
		GameAssertions.assert_sorted_ascending(keys)


func test_unlock_progress_has_the_f6_shape() -> void:
	for row: Array in _implementations():
		# Act
		var model: Dictionary = row[1].unlock_progress(ProfileFixtures.DECAY_WIN_KEY)

		# Assert
		assert_bool(model.met is bool).override_failure_message(row[0]).is_true()
		assert_bool(model.progress is float).override_failure_message(row[0]).is_true()
		assert_bool(model.parts is Array).override_failure_message(row[0]).is_true()


func test_unlock_hint_has_the_read_model_shape() -> void:
	for row: Array in _implementations():
		# Act
		var hint: Dictionary = row[1].unlock_hint(ProfileFixtures.TITHE)

		# Assert
		assert_array(hint.keys()).override_failure_message(row[0]).contains_exactly_in_any_order(["met", "text_key", "progress", "target"])


func test_set_setting_stores_and_emits_once() -> void:
	for row: Array in _implementations():
		# Arrange
		var emitted: Array = []
		row[1].settings_bus.settings_changed.connect(func(key: StringName, value: Variant) -> void: emitted.append([key, value]))

		# Act
		var outcome: Error = row[1].set_setting(&"gamma", 1.2)

		# Assert
		assert_int(outcome).override_failure_message(row[0]).is_equal(OK)
		assert_float(row[1].get_setting(&"gamma")).override_failure_message(row[0]).is_equal(1.2)
		assert_array(emitted).override_failure_message(row[0]).is_equal([[&"gamma", 1.2]])


func test_set_setting_out_of_range_is_e_range_with_no_store_and_no_emit() -> void:
	for row: Array in _implementations():
		# Arrange
		var emitted: Array = []
		row[1].settings_bus.settings_changed.connect(func(key: StringName, _value: Variant) -> void: emitted.append(key))

		# Act
		var outcome: Error = row[1].set_setting(&"gamma", 9.0)
		var unknown: Error = row[1].set_setting(&"no_such_key", 1)

		# Assert
		assert_int(outcome).override_failure_message(row[0]).is_equal(SaveErrors.E_RANGE)
		assert_int(unknown).override_failure_message(row[0]).is_equal(SaveErrors.E_RANGE)
		assert_float(row[1].get_setting(&"gamma")).override_failure_message(row[0]).is_equal(ProfileFixtures.settings_defaults().gamma)
		assert_array(emitted).override_failure_message(row[0]).is_empty()


func test_set_setting_bindings_drops_cancel() -> void:
	for row: Array in _implementations():
		# Act
		row[1].set_setting(&"bindings", {"cancel": [], "ui_cancel": [], "ui_accept": []})

		# Assert
		assert_array(row[1].get_setting(&"bindings").keys()).override_failure_message(row[0]).is_equal(["ui_accept"])


func test_get_setting_of_an_unknown_key_is_null() -> void:
	for row: Array in _implementations():
		# Act / Assert
		assert_that(row[1].get_setting(&"no_such_key")).override_failure_message(row[0]).is_null()


func test_get_settings_is_the_defaults_and_a_copy() -> void:
	for row: Array in _implementations():
		# Act
		var settings: Dictionary = row[1].get_settings()
		settings["gamma"] = 1.3

		# Assert
		assert_float(row[1].get_setting(&"gamma")).override_failure_message(row[0]).is_equal(ProfileFixtures.settings_defaults().gamma)
		assert_array(settings.keys()).override_failure_message(row[0]).contains(ProfileFixtures.settings_defaults().keys())


func test_stats_for_hero_has_the_hero_stats_keys() -> void:
	for row: Array in _implementations():
		# Act
		var hero: Dictionary = row[1].stats_for_hero(ProfileFixtures.HERO_KNOWLEDGE)

		# Assert
		assert_array(hero.keys()).override_failure_message(row[0]).contains_exactly_in_any_order(HERO_STATS_KEYS)


func test_nothing_played_reads_as_no_last_hero_and_an_empty_log() -> void:
	for row: Array in _implementations():
		# Act / Assert
		assert_that(row[1].last_hero_id()).override_failure_message(row[0]).is_null()
		assert_array(row[1].run_log(0, 10)).override_failure_message(row[0]).is_empty()
		assert_that(row[1].run_log_entry("run_nope")).override_failure_message(row[0]).is_null()
		assert_int(row[1].run_log_count()).override_failure_message(row[0]).is_equal(0)


func test_pending_notifications_starts_empty_and_an_unknown_ack_is_harmless() -> void:
	for row: Array in _implementations():
		# Act
		row[1].ack_notification("key_nope")

		# Assert
		assert_array(row[1].pending_notifications()).override_failure_message(row[0]).is_empty()


func test_validate_unlock_defs_of_nothing_is_empty() -> void:
	for row: Array in _implementations():
		# Act / Assert
		assert_array(row[1].validate_unlock_defs([])).override_failure_message(row[0]).is_empty()


func test_reset_profile_with_the_token_restores_settings_and_clears_the_run() -> void:
	for row: Array in _implementations():
		# Arrange
		row[1].set_setting(&"gamma", 1.2)
		row[1].save_active_run({"run_id": "run_a"})

		# Act
		var outcome: Error = row[1].reset_profile(ProfileFixtures.RESET_TOKEN)

		# Assert
		assert_int(outcome).override_failure_message(row[0]).is_equal(OK)
		assert_float(row[1].get_setting(&"gamma")).override_failure_message(row[0]).is_equal(ProfileFixtures.settings_defaults().gamma)
		assert_that(row[1].load_active_run()).override_failure_message(row[0]).is_null()


func test_reset_profile_with_a_wrong_token_changes_nothing() -> void:
	for row: Array in _implementations():
		# Arrange: MetaApi: "when confirm_token is the typed confirmation"
		row[1].set_setting(&"gamma", 1.2)
		row[1].save_active_run({"run_id": "run_a"})

		# Act
		var outcome: Error = row[1].reset_profile("not the token")

		# Assert
		assert_int(outcome).override_failure_message(row[0]).is_equal(SaveErrors.E_RANGE)
		assert_float(row[1].get_setting(&"gamma")).override_failure_message(row[0]).is_equal(1.2)
		assert_dict(row[1].load_active_run()).override_failure_message(row[0]).is_equal({"run_id": "run_a"})


func test_a_writable_session_is_not_read_only() -> void:
	for row: Array in _implementations():
		# Act / Assert
		assert_bool(row[1].is_read_only()).override_failure_message(row[0]).is_false()


func test_clear_run_records_is_ok() -> void:
	for row: Array in _implementations():
		# Act / Assert
		assert_int(row[1].clear_run_records()).override_failure_message(row[0]).is_equal(OK)


func test_get_stats_answers_a_dictionary_read_with_defaults() -> void:
	for row: Array in _implementations():
		# Act
		var stats: Variant = row[1].get_stats()

		# Assert: MetaApi's own example
		assert_bool(stats is Dictionary).override_failure_message(row[0]).is_true()
		assert_int(stats.get("runs_won", 0)).override_failure_message(row[0]).is_equal(0)
