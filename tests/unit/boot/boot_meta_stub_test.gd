## Unit tests for MetaStub, the MVP MetaApi (story boot-composition-root/story-003).
##
## The stub is constructed with `FakeCardDatabase` below — a `CardDatabase`
## subclass (MetaStub takes a `CardDatabase`, card-database story 006) that
## answers the three queries MetaStub uses from in-memory data instead of a
## load: `config("profile_defaults")` frozen with `make_read_only()` (as CR-7
## freezes real bodies), and hero / treasure records from `CardFactory`. Never
## constructed through Boot (ADR-0001).
##
## Setting values: the defaults come from `_profile_defaults()`, a fixture
## factory mirroring meta-progression M9's declared defaults; range tests use
## M9's boundary values on purpose (boundary tests — the number is the point).
extends GdUnitTestSuite


## Injected stand-in: a `CardDatabase` whose three queries MetaStub uses answer
## from the records given here, with no load (CardFactory records need no
## fixture root).
class FakeCardDatabase:
	extends CardDatabase

	var _configs: Dictionary
	var _heroes: Array
	var _treasures: Array

	func _init(profile_defaults: Dictionary, heroes: Array, treasures: Array) -> void:
		var body: Dictionary = profile_defaults.duplicate(true)
		body.make_read_only()
		_configs = {"profile_defaults": body}
		_heroes = heroes
		_treasures = treasures

	func config(config_name: String) -> Variant:
		return _configs.get(config_name)

	func heroes() -> Array:
		return _heroes

	func treasure_pool(collection_id: String = "") -> Array:
		return _treasures


const HERO_IDS: Array = ["hero_decay", "hero_knowledge", "hero_war"]
const TREASURE_IDS: Array = ["treasure_alpha", "treasure_beta"]


## M9 defaults (meta-progression M9 / Tuning Knobs `profile_defaults` row);
## `bindings` is absent from defaults (ADR-0004 addendum).
func _profile_defaults() -> Dictionary:
	return {
		"volume_master": 1.0,
		"volume_music": 0.8,
		"volume_sfx": 1.0,
		"fullscreen": false,
		"anim_speed": "normal",
		"reduce_motion": false,
		"text_scale": 1.0,
		"high_contrast_states": false,
		"telegraph_mode": "full",
		"action_delay_ms": 600,
		"gamma": 1.0,
		"keep_run_records": true,
		"language": "en",
	}


func _heroes() -> Array:
	return [
		CardFactory.make_hero_def("hero_war", "war"),
		CardFactory.make_hero_def("hero_decay", "decay"),
		CardFactory.make_hero_def("hero_knowledge", "knowledge"),
	]


func _treasures() -> Array:
	return [CardFactory.make_treasure_def("treasure_beta"), CardFactory.make_treasure_def("treasure_alpha")]


## MVP data: every `unlock` is null (M10, DD-H06).
func _db() -> FakeCardDatabase:
	return FakeCardDatabase.new(_profile_defaults(), _heroes(), _treasures())


## Data with `unlock` keys present, to prove unlocked_keys() reads data.
func _db_with_unlock_keys() -> FakeCardDatabase:
	var heroes: Array = _heroes()
	heroes.append(CardFactory.make_hero_def("hero_fortune", "fortune",
		{"unlock": {"key": "unlock.hero_fortune", "condition": {}}}))
	var treasures: Array = _treasures()
	treasures.append(CardFactory.make_treasure_def("treasure_living_armory", "rare", ["universal"],
		{"unlock": {"key": "first_victory", "condition": {}}}))
	treasures.append(CardFactory.make_treasure_def("treasure_grave_tithe", "rare", ["decay"],
		{"unlock": {"key": "first_victory", "condition": {}}}))
	return FakeCardDatabase.new(_profile_defaults(), heroes, treasures)


func _stub() -> MetaStub:
	return MetaStub.new(_db())


## Counts `settings_changed` emits; a shared Dictionary because lambdas
## capture locals by value (4.5+).
func _record_emits(meta: MetaApi) -> Dictionary:
	var record: Dictionary = {"count": 0, "args": []}
	meta.settings_bus.settings_changed.connect(func(key: StringName, value: Variant) -> void:
		record.count += 1
		record.args.append([key, value]))
	return record


## Asserts set_setting(key, value) is rejected with E_RANGE, stores nothing and
## emits nothing.
func _assert_rejected(key: StringName, value: Variant) -> void:
	var meta: MetaStub = _stub()
	var before: Variant = meta.get_setting(key)
	var record: Dictionary = _record_emits(meta)

	var err: Error = meta.set_setting(key, value)

	assert_int(err).override_failure_message("%s=%s should be E_RANGE" % [key, value]) \
		.is_equal(ERR_PARAMETER_RANGE_ERROR)
	assert_that(meta.get_setting(key)).is_equal(before)
	assert_int(record.count).is_equal(0)


## Asserts set_setting(key, value) returns OK, stores `stored` and emits
## settings_changed(key, stored) exactly once.
func _assert_accepted(key: StringName, value: Variant, stored: Variant) -> void:
	var meta: MetaStub = _stub()
	var record: Dictionary = _record_emits(meta)

	var err: Error = meta.set_setting(key, value)

	assert_int(err).override_failure_message("%s=%s should be OK" % [key, value]).is_equal(OK)
	assert_that(meta.get_setting(key)).is_equal(stored)
	assert_int(record.count).is_equal(1)
	assert_that(record.args[0][0]).is_equal(key)
	assert_that(record.args[0][1]).is_equal(stored)


# --- AC-1: construction and the trivially-unlocked read surface ----------------

func test_stub_constructs_with_card_database_alone_and_is_meta_api() -> void:
	# Arrange / Act
	var meta: Variant = MetaStub.new(_db())

	# Assert
	assert_bool(meta is MetaApi).is_true()
	assert_object(meta.settings_bus).is_not_null()
	assert_bool(meta.settings_bus is SettingsBus).is_true()


func test_stub_accepts_optional_mirror_without_using_it() -> void:
	# Arrange — stand-in for a later ProfileStore
	var mirror: RefCounted = RefCounted.new()

	# Act
	var meta: MetaStub = MetaStub.new(_db(), mirror)

	# Assert
	assert_str(meta.load_status()).is_equal("FRESH")
	assert_array(meta.calls).is_empty()


func test_load_status_is_fresh() -> void:
	# Arrange
	var meta: MetaStub = _stub()

	# Act
	var status: StringName = meta.load_status()

	# Assert
	assert_that(status).is_equal(&"FRESH")


func test_load_profile_reports_fresh_with_settings() -> void:
	# Arrange
	var meta: MetaStub = _stub()

	# Act
	var loaded: Dictionary = meta.load_profile()

	# Assert
	assert_that(loaded.status).is_equal(&"FRESH")
	assert_dict(loaded.profile.settings).is_equal(_profile_defaults())
	assert_that(loaded.profile.active_run).is_null()


func test_save_profile_returns_ok_and_is_not_recorded() -> void:
	# Arrange
	var meta: MetaStub = _stub()

	# Act
	var err: Error = meta.save_profile()

	# Assert
	assert_int(err).is_equal(OK)
	assert_array(meta.calls).is_empty()


func test_is_hero_unlocked_true_for_every_hero_in_data() -> void:
	# Arrange
	var meta: MetaStub = _stub()

	for hero_id: String in HERO_IDS:
		# Act / Assert
		assert_bool(meta.is_hero_unlocked(hero_id)).override_failure_message(hero_id).is_true()


func test_is_hero_unlocked_false_for_id_not_in_data() -> void:
	# Arrange
	var meta: MetaStub = _stub()

	# Act
	var unlocked: bool = meta.is_hero_unlocked("hero_missing")

	# Assert
	assert_bool(unlocked).is_false()


func test_is_treasure_unlocked_true_for_every_treasure_in_data() -> void:
	# Arrange
	var meta: MetaStub = _stub()

	for treasure_id: String in TREASURE_IDS:
		# Act / Assert
		assert_bool(meta.is_treasure_unlocked(treasure_id)).override_failure_message(treasure_id).is_true()


func test_is_unlocked_true_for_any_key() -> void:
	# Arrange
	var meta: MetaStub = _stub()

	# Act / Assert
	assert_bool(meta.is_unlocked("first_victory")).is_true()


func test_unlocked_ids_lists_heroes_and_treasures_sorted() -> void:
	# Arrange
	var meta: MetaStub = _stub()

	# Act
	var heroes: Array = meta.unlocked_ids(&"hero")
	var treasures: Array = meta.unlocked_ids(&"treasure")

	# Assert
	assert_array(heroes).is_equal(HERO_IDS)
	assert_array(treasures).is_equal(TREASURE_IDS)
	assert_array(meta.unlocked_ids(&"bundle")).is_empty()


func test_unlocked_keys_empty_when_every_unlock_in_data_is_null() -> void:
	# Arrange — MVP data (M10)
	var meta: MetaStub = _stub()

	# Act
	var keys: Array = meta.unlocked_keys()

	# Assert
	assert_array(keys).is_empty()


func test_unlocked_keys_are_every_distinct_unlock_key_in_data() -> void:
	# Arrange
	var meta: MetaStub = MetaStub.new(_db_with_unlock_keys())

	# Act
	var keys: Array = meta.unlocked_keys()

	# Assert — hero and treasure keys, distinct, sorted
	assert_array(keys).is_equal(["first_victory", "unlock.hero_fortune"])


func test_stats_for_hero_returns_zero_counts() -> void:
	# Arrange
	var meta: MetaStub = _stub()

	# Act
	var stats: Dictionary = meta.stats_for_hero("hero_war")

	# Assert — M7.1 HeroStats keys; counts zero, nothing-played fields null
	GameAssertions.assert_has_keys(stats, ["runs_started", "runs_won", "runs_lost", "best_floor_reached",
		"fastest_victory_s", "fewest_turns_victory", "last_played_at"], "HeroStats")
	assert_int(stats.runs_started).is_zero()
	assert_int(stats.runs_won).is_zero()
	assert_int(stats.runs_lost).is_zero()
	assert_int(stats.best_floor_reached).is_zero()
	assert_that(stats.last_played_at).is_null()


func test_last_hero_id_is_null() -> void:
	# Arrange
	var meta: MetaStub = _stub()

	# Act / Assert
	assert_that(meta.last_hero_id()).is_null()


func test_run_log_and_pending_notifications_are_empty() -> void:
	# Arrange
	var meta: MetaStub = _stub()

	# Act / Assert
	assert_array(meta.run_log(0, 10)).is_empty()
	assert_that(meta.run_log_entry("run_any")).is_null()
	assert_array(meta.pending_notifications()).is_empty()


func test_unlock_progress_and_hint_report_met() -> void:
	# Arrange
	var meta: MetaStub = _stub()

	# Act
	var progress: Dictionary = meta.unlock_progress("bosses_defeated_16")
	var hint: Dictionary = meta.unlock_hint("treasure_alpha")

	# Assert — F6: met ⇔ progress == 1
	assert_bool(progress.met).is_true()
	assert_float(progress.progress).is_equal(1.0)
	assert_bool(hint.met).is_true()
	assert_float(hint.progress).is_equal(1.0)


func test_validate_unlock_defs_returns_no_errors() -> void:
	# Arrange
	var meta: MetaStub = _stub()

	# Act / Assert
	assert_array(meta.validate_unlock_defs([{"key": "first_victory"}])).is_empty()


# --- AC-2: in-memory active run, archive, calls recorder ----------------------

func test_load_active_run_null_before_any_save() -> void:
	# Arrange
	var meta: MetaStub = _stub()

	# Act / Assert
	assert_that(meta.load_active_run()).is_null()


func test_save_then_load_active_run_round_trips_record() -> void:
	# Arrange
	var meta: MetaStub = _stub()
	var record: Dictionary = RunFactory.make_run_state()

	# Act
	var err: Error = meta.save_active_run(record)
	var loaded: Variant = meta.load_active_run()

	# Assert
	assert_int(err).is_equal(OK)
	assert_dict(loaded).is_equal(record)


func test_saved_active_run_is_a_copy_of_the_record() -> void:
	# Arrange
	var meta: MetaStub = _stub()
	var record: Dictionary = {"run_id": "run_a", "floor": 1}
	meta.save_active_run(record)

	# Act — the caller mutates its own dictionary afterwards
	record["floor"] = 2

	# Assert
	assert_int(meta.load_active_run().floor).is_equal(1)


func test_clear_active_run_then_load_returns_null() -> void:
	# Arrange
	var meta: MetaStub = _stub()
	meta.save_active_run({"run_id": "run_a"})

	# Act
	meta.clear_active_run()

	# Assert
	assert_that(meta.load_active_run()).is_null()


func test_archive_run_returns_ok_grants_nothing_and_leaves_run_log_empty() -> void:
	# Arrange
	var meta: MetaStub = _stub()

	# Act
	var result: Dictionary = meta.archive_run({"run_id": "run_a", "outcome": "victory"})

	# Assert
	assert_dict(result).is_equal({"ok": true, "unlocks_granted": []})
	assert_array(meta.run_log(0, 10)).is_empty()


func test_every_mutator_call_is_recorded_in_order_with_args() -> void:
	# Arrange
	var meta: MetaStub = _stub()
	var record: Dictionary = {"run_id": "run_a"}

	# Act
	meta.save_active_run(record)
	meta.clear_active_run()
	meta.archive_run(record)
	meta.set_setting(&"gamma", 1.2)
	meta.ack_notification("first_victory")
	meta.reset_profile("RESET")

	# Assert
	var methods: Array = meta.calls.map(func(c: Dictionary) -> String: return c.method)
	assert_array(methods).is_equal(["save_active_run", "clear_active_run", "archive_run",
		"set_setting", "ack_notification", "reset_profile"])
	assert_array(meta.calls[0].args).is_equal([record])
	assert_array(meta.calls[1].args).is_empty()
	assert_array(meta.calls[3].args).is_equal([&"gamma", 1.2])
	assert_array(meta.calls[4].args).is_equal(["first_victory"])
	assert_array(meta.calls[5].args).is_equal(["RESET"])


func test_rejected_set_setting_is_still_recorded() -> void:
	# Arrange
	var meta: MetaStub = _stub()

	# Act
	meta.set_setting(&"brightness", 1.0)

	# Assert
	assert_int(meta.calls.size()).is_equal(1)
	assert_str(meta.calls[0].method).is_equal("set_setting")


func test_reads_are_not_recorded() -> void:
	# Arrange
	var meta: MetaStub = _stub()

	# Act
	meta.load_active_run()
	meta.get_settings()
	meta.unlocked_keys()

	# Assert
	assert_array(meta.calls).is_empty()


func test_reset_profile_restores_defaults_and_clears_active_run() -> void:
	# Arrange
	var meta: MetaStub = _stub()
	meta.set_setting(&"anim_speed", "fast")
	meta.save_active_run({"run_id": "run_a"})

	# Act
	var err: Error = meta.reset_profile("RESET")

	# Assert
	assert_int(err).is_equal(OK)
	assert_dict(meta.get_settings()).is_equal(_profile_defaults())
	assert_that(meta.load_active_run()).is_null()


# --- AC-3: settings from profile_defaults; set_setting OK | E_RANGE ------------

func test_settings_start_as_profile_defaults_body() -> void:
	# Arrange / Act
	var meta: MetaStub = _stub()

	# Assert
	assert_dict(meta.get_settings()).is_equal(_profile_defaults())
	assert_str(meta.get_setting(&"anim_speed")).is_equal("normal")
	assert_that(meta.get_setting(&"brightness")).is_null()


func test_set_setting_writes_copy_and_leaves_frozen_defaults_untouched() -> void:
	# Arrange — the db body is read-only, as CR-7 freezes it
	var db: FakeCardDatabase = _db()
	var meta: MetaStub = MetaStub.new(db)

	# Act
	var err: Error = meta.set_setting(&"gamma", 1.2)

	# Assert
	assert_int(err).is_equal(OK)
	assert_bool((db.config("profile_defaults") as Dictionary).is_read_only()).is_true()
	assert_float(db.config("profile_defaults").gamma).is_equal(_profile_defaults().gamma)


func test_get_settings_returns_a_copy() -> void:
	# Arrange
	var meta: MetaStub = _stub()

	# Act
	var settings: Dictionary = meta.get_settings()
	settings["gamma"] = 1.3

	# Assert
	assert_float(meta.get_setting(&"gamma")).is_equal(_profile_defaults().gamma)


func test_set_setting_in_range_float_returns_ok_stores_and_emits_once() -> void:
	_assert_accepted(&"gamma", 1.2, 1.2)


func test_set_setting_float_range_boundaries_are_accepted() -> void:
	_assert_accepted(&"gamma", 0.8, 0.8)
	_assert_accepted(&"gamma", 1.4, 1.4)
	_assert_accepted(&"volume_music", 0.0, 0.0)
	_assert_accepted(&"volume_master", 1, 1.0)


func test_set_setting_enum_label_returns_ok() -> void:
	_assert_accepted(&"anim_speed", "fast", "fast")
	_assert_accepted(&"telegraph_mode", &"off", "off")


func test_set_setting_text_scale_step_returns_ok() -> void:
	_assert_accepted(&"text_scale", 1.25, 1.25)
	_assert_accepted(&"text_scale", 1.5, 1.5)


func test_set_setting_int_range_and_integral_float_return_ok() -> void:
	_assert_accepted(&"action_delay_ms", 0, 0)
	_assert_accepted(&"action_delay_ms", 2000, 2000)
	# JSON-sourced numbers arrive as float; stored as int (ADR-0004)
	_assert_accepted(&"action_delay_ms", 900.0, 900)


func test_set_setting_bool_returns_ok() -> void:
	_assert_accepted(&"fullscreen", true, true)
	_assert_accepted(&"reduce_motion", true, true)


func test_set_setting_out_of_range_float_returns_e_range() -> void:
	_assert_rejected(&"gamma", 1.41)
	_assert_rejected(&"gamma", 0.79)
	_assert_rejected(&"volume_sfx", -0.1)
	_assert_rejected(&"volume_master", 1.5)


func test_set_setting_out_of_range_int_returns_e_range() -> void:
	_assert_rejected(&"action_delay_ms", 2001)
	_assert_rejected(&"action_delay_ms", -1)
	_assert_rejected(&"action_delay_ms", 600.5)


func test_set_setting_unknown_enum_label_returns_e_range() -> void:
	_assert_rejected(&"anim_speed", "slow")
	_assert_rejected(&"telegraph_mode", "partial")
	_assert_rejected(&"text_scale", 1.1)


func test_set_setting_unknown_key_returns_e_range() -> void:
	_assert_rejected(&"brightness", 1.0)


func test_set_setting_wrong_type_returns_e_range() -> void:
	_assert_rejected(&"fullscreen", "yes")
	_assert_rejected(&"gamma", "bright")
	_assert_rejected(&"anim_speed", 2)


func test_set_setting_bindings_drops_cancel_and_emits_stored_map() -> void:
	# Arrange — cancel / Esc is never rebindable (ADR-0004 addendum 3)
	var bindings: Dictionary = {"end_turn": [{"type": "key", "keycode": 69}], "cancel": [{"type": "key"}]}

	# Act / Assert
	_assert_accepted(&"bindings", bindings, {"end_turn": [{"type": "key", "keycode": 69}]})


func test_set_setting_publishes_value_bus_get_setting_returns_it() -> void:
	# Arrange
	var meta: MetaStub = _stub()

	# Act
	meta.set_setting(&"telegraph_mode", "brief")

	# Assert — a consumer connecting late reads it from the bus
	assert_str(meta.settings_bus.get_setting(&"telegraph_mode")).is_equal("brief")


func test_set_setting_emit_seen_by_game_assertions() -> void:
	# Arrange
	var meta: MetaStub = _stub()

	# Act / Assert
	GameAssertions.assert_signal_emitted(meta.settings_bus, "settings_changed",
		func() -> void: meta.set_setting(&"reduce_motion", true))
	GameAssertions.assert_signal_not_emitted(meta.settings_bus, "settings_changed",
		func() -> void: meta.set_setting(&"reduce_motion", "no"))


# --- AC-4: from_fixture ---------------------------------------------------------

func test_from_fixture_merges_settings_over_defaults_and_keeps_unknown_keys() -> void:
	# Arrange
	var fixture: Dictionary = {"settings": {"anim_speed": "instant", "text_scale": 1.5, "future_key": "kept"}}

	# Act
	var meta: MetaStub = MetaStub.from_fixture(_db(), fixture)

	# Assert
	var expected: Dictionary = _profile_defaults()
	expected.merge({"anim_speed": "instant", "text_scale": 1.5, "future_key": "kept"}, true)
	assert_dict(meta.get_settings()).is_equal(expected)


func test_from_fixture_clamps_out_of_range_numbers() -> void:
	# Arrange — M9 last sentence (gamma) and M5.3 (volumes, numbers clamped)
	var fixture: Dictionary = {"settings": {"gamma": 2.0, "volume_music": -1.0, "action_delay_ms": 5000.0}}

	# Act
	var meta: MetaStub = MetaStub.from_fixture(_db(), fixture)

	# Assert
	assert_float(meta.get_setting(&"gamma")).is_equal(1.4)
	assert_float(meta.get_setting(&"volume_music")).is_equal(0.0)
	assert_int(meta.get_setting(&"action_delay_ms")).is_equal(2000)


func test_from_fixture_replaces_unknown_enum_and_wrong_type_with_default() -> void:
	# Arrange — M9 "unknown value for an enum key is replaced by the default"; M5.3
	var fixture: Dictionary = {"settings": {"anim_speed": "warp", "fullscreen": "yes", "text_scale": 3.0}}
	var defaults: Dictionary = _profile_defaults()

	# Act
	var meta: MetaStub = MetaStub.from_fixture(_db(), fixture)

	# Assert
	assert_str(meta.get_setting(&"anim_speed")).is_equal(defaults.anim_speed)
	assert_bool(meta.get_setting(&"fullscreen")).is_equal(defaults.fullscreen)
	assert_float(meta.get_setting(&"text_scale")).is_equal(defaults.text_scale)


func test_from_fixture_coerces_json_float_to_int_for_int_key() -> void:
	# Arrange — JSON.parse_string returns float for every number (ADR-0004)
	var fixture: Dictionary = {"settings": {"action_delay_ms": 900.0}}

	# Act
	var meta: MetaStub = MetaStub.from_fixture(_db(), fixture)
	var value: Variant = meta.get_setting(&"action_delay_ms")

	# Assert
	assert_int(typeof(value)).is_equal(TYPE_INT)
	assert_int(value).is_equal(900)


func test_from_fixture_with_active_run_loads_it() -> void:
	# Arrange
	var active_run: Dictionary = RunFactory.make_run_state()
	var fixture: Dictionary = {"settings": {}, "active_run": active_run}

	# Act
	var meta: MetaStub = MetaStub.from_fixture(_db(), fixture)

	# Assert
	assert_dict(meta.load_active_run()).is_equal(active_run)


func test_from_fixture_without_active_run_loads_null() -> void:
	# Arrange
	var fixture: Dictionary = {"settings": {"gamma": 1.1}}

	# Act
	var meta: MetaStub = MetaStub.from_fixture(_db(), fixture)

	# Assert
	assert_that(meta.load_active_run()).is_null()
	assert_float(meta.get_setting(&"gamma")).is_equal(1.1)


func test_from_fixture_records_no_calls_and_status_stays_fresh() -> void:
	# Arrange
	var fixture: Dictionary = {"settings": {"gamma": 1.1}, "active_run": {"run_id": "run_a"}}

	# Act
	var meta: MetaStub = MetaStub.from_fixture(_db(), fixture)

	# Assert
	assert_array(meta.calls).is_empty()
	assert_that(meta.load_status()).is_equal(&"FRESH")
