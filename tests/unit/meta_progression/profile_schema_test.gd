## Unit tests for `ProfileSchema` (design/gdd/meta-progression.md M1.2, M5.3, M9;
## AC-18's clamps; ADR-0004 Decision 1): pure functions over Dictionaries.
extends GdUnitTestSuite

const HERO: String = ProfileFixtures.HERO_WAR
## M1.2's top-level keys, in file order.
const TOP_LEVEL_KEYS: Array[String] = ["schema_version", "profile_id", "created_at", "updated_at", "write_seq", "settings",
	"stats", "run_log", "unlocks", "pending_notifications", "active_run", "data_versions_seen"]


func _repaired(profile: Dictionary) -> int:
	return ProfileSchema.repair(profile, ProfileFixtures.settings_defaults(), ProfileFixtures.knobs())


func _hero_stats(overrides: Dictionary) -> Dictionary:
	var hero: Dictionary = ProfileSchema.empty_hero_stats()
	hero.merge(overrides, true)
	return hero


# --- M1.2 ----------------------------------------------------------------------

func test_new_profile_has_the_m1_2_keys_schema_version_first() -> void:
	# Act
	var profile: Dictionary = ProfileSchema.new_profile(1, ProfileFixtures.settings_defaults(), ProfileFixtures.START_TIME)

	# Assert
	assert_array(profile.keys()).is_equal(TOP_LEVEL_KEYS)


func test_new_profile_starts_empty() -> void:
	# Act
	var profile: Dictionary = ProfileSchema.new_profile(1, ProfileFixtures.settings_defaults(), ProfileFixtures.START_TIME)

	# Assert (AC-1)
	assert_int(profile.schema_version).is_equal(1)
	assert_array(profile.run_log).is_empty()
	assert_that(profile.active_run).is_null()
	assert_int(profile.write_seq).is_equal(0)
	assert_int(profile.created_at).is_equal(ProfileFixtures.START_TIME)
	assert_dict(profile.settings).is_equal(ProfileFixtures.settings_defaults())


func test_new_profile_copies_the_defaults() -> void:
	# Arrange
	var defaults: Dictionary = ProfileFixtures.settings_defaults()

	# Act
	var profile: Dictionary = ProfileSchema.new_profile(1, defaults, ProfileFixtures.START_TIME)
	profile.settings["gamma"] = 1.2

	# Assert
	assert_float(defaults.gamma).is_equal(1.0)


func test_new_profile_id_is_32_hex_characters_and_not_repeated() -> void:
	# Act
	var first: String = ProfileSchema.new_profile_id()
	var second: String = ProfileSchema.new_profile_id()

	# Assert
	assert_int(first.length()).is_equal(32)
	assert_bool(first.is_valid_hex_number()).is_true()
	assert_str(first).is_not_equal(second)


func test_empty_stats_has_the_m7_1_shape() -> void:
	# Act
	var stats: Dictionary = ProfileSchema.empty_stats()

	# Assert
	assert_array(stats.keys()).contains_exactly_in_any_order(["runs_started", "runs_won", "runs_lost", "runs_void",
		"total_turns", "total_play_seconds", "heroes", "bosses", "treasures", "bests"])


func test_empty_hero_stats_has_the_m7_1_shape_with_null_bests() -> void:
	# Act
	var hero: Dictionary = ProfileSchema.empty_hero_stats()

	# Assert
	assert_array(hero.keys()).contains_exactly_in_any_order(["runs_started", "runs_won", "runs_lost", "best_floor_reached",
		"fastest_victory_s", "fewest_turns_victory", "last_played_at"])
	assert_that(hero.fastest_victory_s).is_null()
	assert_that(hero.last_played_at).is_null()


# --- ADR-0004 Decision 1 -------------------------------------------------------

func test_normalised_turns_integral_floats_back_to_ints_at_any_depth() -> void:
	# Act
	var out: Dictionary = ProfileSchema.normalised({"a": 3.0, "b": [4.0, {"c": 5.0}], "d": 0.5, "e": "text", "f": null})

	# Assert
	assert_bool(out.a is int).is_true()
	assert_bool(out.b[0] is int).is_true()
	assert_bool(out.b[1].c is int).is_true()
	assert_bool(out.d is float).is_true()
	assert_float(out.d).is_equal(0.5)
	assert_str(out.e).is_equal("text")
	assert_that(out.f).is_null()


func test_normalised_leaves_a_float_above_two_to_the_53_alone() -> void:
	# Arrange: not exactly representable as a whole number from JSON (ADR-0003 probe E)
	var big: float = ProfileSchema.MAX_EXACT_INT * 2.0

	# Act / Assert
	assert_bool(ProfileSchema.normalised(big) is float).is_true()


# --- M9: check_setting ---------------------------------------------------------

func test_check_setting_takes_each_range_boundary() -> void:
	# Arrange: [key, boundary value]
	var inside: Array = [["volume_master", 0.0], ["volume_music", 1.0], ["gamma", 0.8], ["gamma", 1.4],
		["action_delay_ms", 0], ["action_delay_ms", 2000], ["text_scale", 1.25], ["text_scale", 1.5],
		["anim_speed", "instant"], ["telegraph_mode", "off"], ["fullscreen", true], ["language", "en"]]

	# Act / Assert
	for row: Array in inside:
		assert_bool(ProfileSchema.check_setting(row[0], row[1]).ok).override_failure_message(str(row)).is_true()


func test_check_setting_refuses_just_outside_each_range() -> void:
	# Arrange
	var outside: Array = [["volume_sfx", -0.01], ["volume_sfx", 1.01], ["gamma", 0.79], ["gamma", 1.41],
		["action_delay_ms", -1], ["action_delay_ms", 2001], ["action_delay_ms", 1.5], ["text_scale", 1.1],
		["anim_speed", "1.5"], ["telegraph_mode", "none"], ["fullscreen", 1], ["language", 3], ["bindings", []],
		["key_nobody_named", 1]]

	# Act / Assert
	for row: Array in outside:
		assert_bool(ProfileSchema.check_setting(row[0], row[1]).ok).override_failure_message(str(row)).is_false()


func test_check_setting_coerces_json_numbers_to_the_declared_kind() -> void:
	# Act
	var whole: Variant = ProfileSchema.check_setting("action_delay_ms", 700.0).value
	var fractional: Variant = ProfileSchema.check_setting("gamma", 1).value

	# Assert
	assert_bool(whole is int).is_true()
	assert_bool(fractional is float).is_true()


func test_check_setting_bindings_drops_the_unrebindable_actions() -> void:
	# Arrange
	var map: Dictionary = {"ui_accept": [], "cancel": [], "ui_cancel": []}

	# Act
	var stored: Dictionary = ProfileSchema.check_setting("bindings", map).value

	# Assert (ADR-0004 addendum 3)
	assert_array(stored.keys()).is_equal(["ui_accept"])


func test_clean_bindings_drops_left_and_right_mouse_and_keeps_the_rest() -> void:
	# Arrange
	var key: Dictionary = {"type": "key", "keycode": KEY_E}
	var middle: Dictionary = {"type": "mouse_button", "button_index": MOUSE_BUTTON_MIDDLE}
	var left: Dictionary = {"type": "mouse_button", "button_index": MOUSE_BUTTON_LEFT}
	var right: Dictionary = {"type": "mouse_button", "button_index": MOUSE_BUTTON_RIGHT}

	# Act
	var cleaned: Dictionary = ProfileSchema.clean_bindings({"ui_accept": [key, left, middle, right]})

	# Assert
	assert_array(cleaned.ui_accept).is_equal([key, middle])


func test_clean_bindings_drops_a_value_that_is_no_event_list() -> void:
	# Act
	var cleaned: Dictionary = ProfileSchema.clean_bindings({"ui_accept": "not a list", "ui_left": []})

	# Assert
	assert_array(cleaned.keys()).is_equal(["ui_left"])


# --- M9 / M5.3: repaired_setting -----------------------------------------------

func test_repaired_setting_clamps_a_number_and_defaults_an_enum() -> void:
	# Arrange
	var defaults: Dictionary = ProfileFixtures.settings_defaults()

	# Act / Assert
	assert_float(ProfileSchema.repaired_setting("volume_master", 7, defaults)).is_equal(1.0)
	assert_float(ProfileSchema.repaired_setting("gamma", 0.1, defaults)).is_equal(0.8)
	assert_int(ProfileSchema.repaired_setting("action_delay_ms", 5000, defaults)).is_equal(2000)
	assert_str(ProfileSchema.repaired_setting("anim_speed", "ludicrous", defaults)).is_equal(defaults.anim_speed)
	assert_float(ProfileSchema.repaired_setting("text_scale", 3.0, defaults)).is_equal(defaults.text_scale)
	assert_bool(ProfileSchema.repaired_setting("fullscreen", "yes", defaults)).is_equal(defaults.fullscreen)


func test_repaired_setting_keeps_an_unknown_key_verbatim() -> void:
	# Act / Assert
	assert_str(ProfileSchema.repaired_setting("from_the_future", "kept", ProfileFixtures.settings_defaults())).is_equal("kept")


func test_repaired_setting_bindings_of_the_wrong_type_is_the_empty_map() -> void:
	# Act / Assert
	assert_dict(ProfileSchema.repaired_setting("bindings", 12, ProfileFixtures.settings_defaults())).is_empty()


# --- M5.3: repair --------------------------------------------------------------

func test_repair_ac18_clamps_three_values_and_counts_three() -> void:
	# Arrange
	var profile: Dictionary = ProfileFixtures.profile_dict()
	profile.stats["runs_won"] = -3
	profile.stats.heroes[HERO] = _hero_stats({"best_floor_reached": 40})
	profile.settings["volume_master"] = 7

	# Act
	var repairs: int = _repaired(profile)

	# Assert
	assert_int(repairs).is_equal(3)
	assert_int(profile.stats.runs_won).is_equal(0)
	assert_int(profile.stats.heroes[HERO].best_floor_reached).is_equal(12)
	assert_float(profile.settings.volume_master).is_equal(1.0)


func test_repair_clean_profile_counts_none() -> void:
	# Act / Assert
	assert_int(_repaired(ProfileFixtures.profile_dict())).is_equal(0)


func test_repair_clamps_counts_and_durations_to_their_knobs() -> void:
	# Arrange
	var profile: Dictionary = ProfileFixtures.profile_dict()
	profile.stats["total_turns"] = 1000000
	profile.stats["total_play_seconds"] = 200000000

	# Act
	_repaired(profile)

	# Assert
	assert_int(profile.stats.total_turns).is_equal(999999)
	assert_int(profile.stats.total_play_seconds).is_equal(100000000)


func test_repair_keeps_a_value_on_each_clamp_boundary_without_a_repair() -> void:
	# Arrange
	var profile: Dictionary = ProfileFixtures.profile_dict()
	profile.stats["total_turns"] = 999999
	profile.stats["total_play_seconds"] = 100000000
	profile.stats.heroes[HERO] = _hero_stats({"best_floor_reached": 12})

	# Act / Assert
	assert_int(_repaired(profile)).is_equal(0)


func test_repair_raises_runs_started_to_the_sum_of_outcomes() -> void:
	# Arrange
	var profile: Dictionary = ProfileFixtures.profile_dict()
	profile.stats["runs_started"] = 1
	profile.stats["runs_won"] = 2
	profile.stats["runs_lost"] = 3
	profile.stats["runs_void"] = 4

	# Act
	var repairs: int = _repaired(profile)

	# Assert (Edge Cases "impossible counter")
	assert_int(profile.stats.runs_started).is_equal(9)
	assert_int(repairs).is_equal(1)


func test_repair_raises_a_heros_runs_started_to_its_outcomes() -> void:
	# Arrange
	var profile: Dictionary = ProfileFixtures.profile_dict()
	profile.stats.heroes[HERO] = _hero_stats({"runs_started": 0, "runs_won": 2, "runs_lost": 1})

	# Act
	_repaired(profile)

	# Assert
	assert_int(profile.stats.heroes[HERO].runs_started).is_equal(3)


func test_repair_replaces_a_wrong_type_and_counts_it() -> void:
	# Arrange
	var profile: Dictionary = ProfileFixtures.profile_dict({"stats": "not a map", "run_log": 3, "settings": []})

	# Act
	var repairs: int = _repaired(profile)

	# Assert
	assert_int(repairs).is_equal(3)
	assert_int(profile.stats.runs_started).is_equal(0)
	assert_array(profile.run_log).is_empty()
	assert_dict(profile.settings).is_equal(ProfileFixtures.settings_defaults())


func test_repair_fills_a_missing_key_without_counting_it() -> void:
	# Arrange
	var profile: Dictionary = ProfileFixtures.profile_dict()
	profile.erase("unlocks")
	profile.stats.erase("runs_void")
	profile.settings.erase("gamma")

	# Act
	var repairs: int = _repaired(profile)

	# Assert
	assert_int(repairs).is_equal(0)
	assert_dict(profile.unlocks).is_empty()
	assert_int(profile.stats.runs_void).is_equal(0)
	assert_float(profile.settings.gamma).is_equal(ProfileFixtures.settings_defaults().gamma)


func test_repair_keeps_unknown_keys_at_every_level() -> void:
	# Arrange
	var profile: Dictionary = ProfileFixtures.profile_dict({"future_top": {"a": 1}})
	profile.settings["future_setting"] = "x"
	profile.stats["future_stat"] = 5

	# Act
	var repairs: int = _repaired(profile)

	# Assert
	assert_int(repairs).is_equal(0)
	assert_dict(profile.future_top).is_equal({"a": 1})
	assert_str(profile.settings.future_setting).is_equal("x")
	assert_int(profile.stats.future_stat).is_equal(5)


func test_repair_treats_a_non_object_active_run_as_null_and_leaves_an_object_alone() -> void:
	# Arrange
	var bad: Dictionary = ProfileFixtures.profile_dict({"active_run": 12})
	var opaque: Dictionary = ProfileFixtures.profile_dict({"active_run": {"anything": ["goes", -1]}})

	# Act
	var bad_repairs: int = _repaired(bad)
	var opaque_repairs: int = _repaired(opaque)

	# Assert (M5.4: "object or null")
	assert_that(bad.active_run).is_null()
	assert_int(bad_repairs).is_equal(1)
	assert_dict(opaque.active_run).is_equal({"anything": ["goes", -1]})
	assert_int(opaque_repairs).is_equal(0)


func test_repair_honours_an_unlocked_true_entry() -> void:
	# Arrange
	var entry: Dictionary = {"unlocked": true, "at": 5, "by_run_id": "run_a", "retro": false}
	var profile: Dictionary = ProfileFixtures.profile_dict({"unlocks": {"some_key": entry.duplicate()}})

	# Act
	var repairs: int = _repaired(profile)

	# Assert (Edge Cases: an edited `unlocked: true` is honoured)
	assert_int(repairs).is_equal(0)
	assert_dict(profile.unlocks.some_key).is_equal(entry)


func test_repair_a_clamp_never_changes_an_unlock() -> void:
	# Arrange
	var profile: Dictionary = ProfileFixtures.profile_dict({"unlocks": {"some_key": {"unlocked": true, "at": 5, "by_run_id": null, "retro": false}}})
	profile.stats["runs_won"] = -3

	# Act
	_repaired(profile)

	# Assert (AC-18: no unlock changed state)
	assert_bool(profile.unlocks.some_key.unlocked).is_true()


func test_repair_rebuilds_a_malformed_unlock_entry_without_granting() -> void:
	# Arrange
	var profile: Dictionary = ProfileFixtures.profile_dict({"unlocks": {"odd_key": "yes"}})

	# Act
	var repairs: int = _repaired(profile)

	# Assert
	assert_int(repairs).is_equal(1)
	assert_bool(profile.unlocks.odd_key.unlocked).is_false()


func test_repair_drops_notifications_without_a_key_and_entries_that_are_no_objects() -> void:
	# Arrange
	var kept: Dictionary = {"key": "k", "kind": "treasure", "id": "t", "by_run_id": null}
	var profile: Dictionary = ProfileFixtures.profile_dict({"pending_notifications": [kept, 7, {"kind": "treasure"}], "run_log": [{"run_id": "a"}, 7]})

	# Act
	_repaired(profile)

	# Assert
	assert_array(profile.pending_notifications).is_equal([kept])
	assert_int(profile.run_log.size()).is_equal(1)


func test_repair_replaces_a_non_string_profile_id() -> void:
	# Arrange
	var profile: Dictionary = ProfileFixtures.profile_dict({"profile_id": 12})

	# Act
	_repaired(profile)

	# Assert
	assert_int((profile.profile_id as String).length()).is_equal(32)


func test_repair_keeps_a_null_best_and_clamps_a_negative_one() -> void:
	# Arrange
	var profile: Dictionary = ProfileFixtures.profile_dict()
	profile.stats.heroes[HERO] = _hero_stats({"fastest_victory_s": -5})

	# Act
	var repairs: int = _repaired(profile)

	# Assert
	assert_int(profile.stats.heroes[HERO].fastest_victory_s).is_equal(0)
	assert_that(profile.stats.heroes[HERO].fewest_turns_victory).is_null()
	assert_int(repairs).is_equal(1)


func test_repair_gamma_out_of_range_is_clamped() -> void:
	# Arrange
	var profile: Dictionary = ProfileFixtures.profile_dict()
	profile.settings["gamma"] = 9.0

	# Act
	_repaired(profile)

	# Assert (M9 "An out-of-range gamma is clamped to 0.8..1.4 on load")
	assert_float(profile.settings.gamma).is_equal(1.4)
