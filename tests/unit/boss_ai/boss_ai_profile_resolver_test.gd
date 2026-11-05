## Unit tests for `ProfileResolver.resolve` and the Boss AI data validators
## (story boss-ai-match-driver/story-002; design/gdd/boss-ai.md C8.4, C10, F9,
## Edge Cases "Data and determinism", A25, A26; ADR-0002 Decision 4 stage 7;
## ADR-0006 `runtime` block; TR-boss-ai-005).
##
## Every case starts from the committed stub `tests/fixtures/boss_ai/
## profiles_stub.json` (a small but complete `ai_profiles` config body), read
## fresh per call so a test that edits its copy changes nothing else. The stub
## is the "injected stub profile" of the Edge Cases: it never ships in the
## loader. Expected numbers are read from the stub where the test is about
## layering, and written out only where the number is the point (the F9
## example's 2.5 / 1.5, A26's 9 → 5, range boundaries).
##
## No test reads `assets/data/`: the shipped file is story 003's, checked by
## `tests/integration/boss_ai/boss_ai_profiles_data_test.gd`.
extends GdUnitTestSuite

const STUB_PATH: String = "res://tests/fixtures/boss_ai/profiles_stub.json"
const BOOT_SCRIPT: GDScript = preload("res://src/core/boot.gd")
const ENTRY_KEYS: Array[String] = ["severity", "code", "file", "record_id", "field", "message"]


## A stand-in for `CardDatabase` in `Loading` at stage 7: the one lookup
## `validate_profiles_config` asks for (ADR-0002 Decision 4 opens lookups to
## validator callbacks). Cards are grouped by CR-3 `type`.
class FakeLookupDb extends RefCounted:
	var by_type: Dictionary = {}

	func cards_by_type(card_type: String) -> Array:
		return by_type.get(card_type, [])


# --- helpers -----------------------------------------------------------------

## The stub's `config` body, freshly parsed.
func _stub() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STUB_PATH))
	GameAssertions.fail_if(not parsed is Dictionary, "fixture %s did not parse" % STUB_PATH)
	return (parsed as Dictionary)["config"]


## F2's data values among the rules (A29, review D-3).
const F2_RULES: Array[String] = ["taunt_bonus", "flat_spell_damage", "flat_deathrattle", "flat_aura"]


func _boss(ai_profile: Variant, band: int) -> Dictionary:
	return CardFactory.make_boss_def("boss_test", band, {"ai_profile": ai_profile})


func _validate(body: Dictionary) -> Array:
	return BossAI.validate_profiles_config(body, null)


func _codes(rows: Array) -> Array:
	return rows.map(func(e: Dictionary) -> StringName: return e.code)


func _fields(rows: Array) -> Array:
	return rows.map(func(e: Dictionary) -> Variant: return e.field)


func _only_code(rows: Array, code: StringName) -> void:
	assert_array(_codes(rows)).override_failure_message("rows: %s" % str(rows)).is_equal([code])


func _card_with_ops(id: String, ops: Array) -> Dictionary:
	return CardFactory.make_spell(id, 1, [CardFactory.make_effect("cast", ops)])


# --- resolve: layering (C10, F9) ----------------------------------------------

func test_resolve_rot_warden_example_layers_default_archetype_band_and_override() -> void:
	# Arrange — F9: boss_rot_warden {extends: passive_driven, synergy_tags: [deathrattle], weights: {w_self: 1.5}}
	var config: Dictionary = _stub()
	var boss: Dictionary = CardFactory.make_boss_def("boss_rot_warden", 2, {"ai_profile": "boss_rot_warden"})

	# Act
	var profile: Dictionary = ProfileResolver.resolve(config, boss, 2)

	# Assert
	assert_float(profile.weights.w_passive).is_equal(2.5)
	assert_float(profile.weights.w_self).is_equal(1.5)
	assert_float(profile.weights.w_face).is_equal(config.profiles.default.weights.w_face)
	assert_dict(profile.budgets).is_equal(config.bands["2"].budgets)
	assert_bool(profile.rules.defensive).is_equal(config.bands["2"].rules.defensive)
	assert_array(profile.synergy_tags).is_equal(["deathrattle"])
	assert_bool(profile.has("extends")).is_false()


func test_resolve_band_overlay_wins_over_archetype_and_keeps_its_other_keys() -> void:
	# Arrange
	var config: Dictionary = _stub()

	# Act — aggro at band 1
	var profile: Dictionary = ProfileResolver.resolve(config, _boss("aggro", 1), 1)

	# Assert — band 1 wins where it speaks, aggro and default stand elsewhere
	assert_float(profile.weights.w_trade).is_equal(config.bands["1"].weights.w_trade)
	assert_float(profile.weights.w_face).is_equal(config.profiles.aggro.weights.w_face)
	assert_float(profile.weights.w_heal).is_equal(config.profiles.default.weights.w_heal)
	assert_str(profile.rules.lethal_search).is_equal(config.bands["1"].rules.lethal_search)
	assert_float(profile.rules.trade_ratio).is_equal(config.profiles.aggro.rules.trade_ratio)
	assert_dict(profile.choice_preference).is_equal(config.profiles.aggro.choice_preference)
	assert_str(profile.intent_mode).is_equal("full")


func test_resolve_override_wins_over_band_overlay() -> void:
	# Arrange
	var config: Dictionary = _stub()
	config.boss_overrides["boss_test"] = {"extends": "aggro", "weights": {"w_trade": 0.9}, "intent_mode": "class_only"}

	# Act
	var profile: Dictionary = ProfileResolver.resolve(config, _boss("boss_test", 1), 1)

	# Assert
	assert_float(profile.weights.w_trade).is_equal(0.9)
	assert_str(profile.intent_mode).is_equal("class_only")
	assert_float(profile.weights.w_face).is_equal(config.profiles.aggro.weights.w_face)


func test_resolve_nested_rule_dictionary_is_replaced_whole_not_merged() -> void:
	# Arrange — shallow per section: rules.defensive_multipliers is one value
	var config: Dictionary = _stub()
	config.bands["3"].rules["defensive_multipliers"] = {"w_face": 0.5}

	# Act
	var profile: Dictionary = ProfileResolver.resolve(config, _boss("default", 3), 3)

	# Assert
	assert_dict(profile.rules.defensive_multipliers).is_equal({"w_face": 0.5})


func test_resolve_synergy_tags_are_replaced_not_concatenated() -> void:
	# Arrange
	var config: Dictionary = _stub()
	config.profiles.passive_driven["synergy_tags"] = ["swarm"]

	# Act
	var profile: Dictionary = ProfileResolver.resolve(config, _boss("boss_rot_warden", 2), 2)

	# Assert
	assert_array(profile.synergy_tags).is_equal(["deathrattle"])


func test_resolve_archetype_key_without_override_is_default_archetype_band() -> void:
	# Arrange
	var config: Dictionary = _stub()

	# Act
	var profile: Dictionary = ProfileResolver.resolve(config, _boss("aggro", 3), 3)

	# Assert
	assert_float(profile.weights.w_face).is_equal(config.profiles.aggro.weights.w_face)
	assert_float(profile.weights.w_trade).is_equal(config.profiles.default.weights.w_trade)
	assert_bool(profile.rules.defensive).is_true()
	assert_dict(profile.budgets).is_equal(config.bands["3"].budgets)


# --- resolve: fallbacks (A25, Edge Cases) -------------------------------------

func test_resolve_unknown_profile_key_falls_back_to_default_and_band() -> void:
	# Arrange — A25
	var config: Dictionary = _stub()

	# Act
	var profile: Dictionary = ProfileResolver.resolve(config, _boss("does_not_exist", 1), 1)

	# Assert — default's weights under band 1's overlay, no archetype
	assert_float(profile.weights.w_face).is_equal(config.profiles.default.weights.w_face)
	assert_float(profile.weights.w_board).is_equal(config.profiles.default.weights.w_board)
	assert_float(profile.weights.w_trade).is_equal(config.bands["1"].weights.w_trade)
	assert_dict(profile.budgets).is_equal(config.bands["1"].budgets)
	assert_str(profile.rules.hero_power).is_equal(config.bands["1"].rules.hero_power)
	assert_array(profile.synergy_tags).is_empty()


func test_resolve_missing_ai_profile_field_falls_back_to_default_and_band() -> void:
	# Arrange
	var config: Dictionary = _stub()
	var boss: Dictionary = _boss("aggro", 2)
	boss.erase("ai_profile")

	# Act
	var profile: Dictionary = ProfileResolver.resolve(config, boss, 2)

	# Assert
	assert_float(profile.weights.w_face).is_equal(config.profiles.default.weights.w_face)
	assert_dict(profile.budgets).is_equal(config.bands["2"].budgets)


func test_resolve_override_with_unknown_extends_falls_back_to_default_and_band() -> void:
	# Arrange
	var config: Dictionary = _stub()
	config.boss_overrides["boss_test"] = {"extends": "no_such_archetype", "weights": {"w_face": 4.0}}

	# Act
	var profile: Dictionary = ProfileResolver.resolve(config, _boss("boss_test", 1), 1)

	# Assert — the broken override is not applied (C10: any E_AI_* falls back to default)
	assert_float(profile.weights.w_face).is_equal(config.profiles.default.weights.w_face)
	assert_dict(profile.budgets).is_equal(config.bands["1"].budgets)


func test_resolve_with_an_empty_config_supplies_no_built_in_defaults() -> void:
	# Act — Edge Cases: no runtime default; the stub is injected by tests
	var profile: Dictionary = ProfileResolver.resolve({}, _boss("aggro", 1), 1)

	# Assert
	assert_dict(profile.weights).is_empty()
	assert_dict(profile.rules).is_empty()
	assert_dict(profile.budgets).is_empty()
	assert_bool(profile.has("intent_mode")).is_false()


# --- resolve: value sanitation (A26, C8.4) ------------------------------------

func test_resolve_weight_above_range_is_clamped_to_its_max_not_zeroed() -> void:
	# Arrange — A26: w_face = 9 → 5 (F1 range 0–5); w_trade 7 → 3 (0–3)
	var config: Dictionary = _stub()
	config.profiles.aggro.weights["w_face"] = 9.0
	config.profiles.aggro.weights["w_trade"] = 7.0

	# Act
	var profile: Dictionary = ProfileResolver.resolve(config, _boss("aggro", 2), 2)

	# Assert
	assert_float(profile.weights.w_face).is_equal(5.0)
	assert_float(profile.weights.w_trade).is_equal(3.0)


func test_resolve_value_below_range_is_clamped_to_its_min() -> void:
	# Arrange
	var config: Dictionary = _stub()
	config.profiles.aggro.weights["w_face"] = -2.0
	config.profiles.aggro.rules["trade_ratio"] = 0.1

	# Act
	var profile: Dictionary = ProfileResolver.resolve(config, _boss("aggro", 2), 2)

	# Assert — F1 w_face 0–5; F3 trade_ratio 0.5–2.0
	assert_float(profile.weights.w_face).is_equal(BossAI.RANGES.w_face.min)
	assert_float(profile.rules.trade_ratio).is_equal(BossAI.RANGES.trade_ratio.min)


func test_resolve_non_finite_or_non_number_value_keeps_the_earlier_layer() -> void:
	# Arrange — each is an E_AI_WEIGHT_RANGE at load; at runtime it falls back
	var config: Dictionary = _stub()
	config.profiles.aggro.weights["w_face"] = INF
	config.profiles.aggro.weights["w_board"] = NAN
	config.bands["2"]["weights"] = {"w_self": "high", "w_card": true}

	# Act
	var profile: Dictionary = ProfileResolver.resolve(config, _boss("aggro", 2), 2)

	# Assert
	var defaults: Dictionary = config.profiles.default.weights
	assert_float(profile.weights.w_face).is_equal(defaults.w_face)
	assert_float(profile.weights.w_board).is_equal(defaults.w_board)
	assert_float(profile.weights.w_self).is_equal(defaults.w_self)
	assert_float(profile.weights.w_card).is_equal(defaults.w_card)


func test_resolve_fractional_integral_knob_keeps_the_earlier_layer() -> void:
	# Arrange — overextend_cap_aoe is an int knob (F5)
	var config: Dictionary = _stub()
	config.profiles.aggro.rules["overextend_cap_aoe"] = 4.5

	# Act
	var profile: Dictionary = ProfileResolver.resolve(config, _boss("aggro", 1), 1)

	# Assert
	assert_float(profile.rules.overextend_cap_aoe).is_equal(config.profiles.default.rules.overextend_cap_aoe)


func test_resolve_hidden_intent_is_taken_only_from_a_boss_override() -> void:
	# Arrange — C8.4 / D-04: no band or archetype may set hidden
	var config: Dictionary = _stub()
	config.bands["3"]["intent_mode"] = "hidden"
	config.boss_overrides["boss_test"] = {"extends": "aggro", "intent_mode": "hidden"}

	# Act
	var from_band: Dictionary = ProfileResolver.resolve(config, _boss("aggro", 3), 3)
	var from_override: Dictionary = ProfileResolver.resolve(config, _boss("boss_test", 3), 3)

	# Assert
	assert_str(from_band.intent_mode).is_equal("full")
	assert_str(from_override.intent_mode).is_equal("hidden")


func test_resolve_no_band_overlay_resolves_to_hidden_without_an_override() -> void:
	# Arrange — A19 last clause
	var config: Dictionary = _stub()

	# Act / Assert
	for band: int in [1, 2, 3]:
		var profile: Dictionary = ProfileResolver.resolve(config, _boss("default", band), band)
		assert_str(profile.intent_mode).override_failure_message("band %d" % band).is_not_equal("hidden")


func test_resolve_never_writes_to_the_config_it_reads() -> void:
	# Arrange
	var config: Dictionary = _stub()
	config.profiles.aggro.weights["w_face"] = 9.0
	var before: Dictionary = config.duplicate(true)

	# Act — then edit the result's containers
	var profile: Dictionary = ProfileResolver.resolve(config, _boss("boss_rot_warden", 2), 2)
	profile.synergy_tags.append("edited")
	profile.weights["w_self"] = 0.0
	profile.rules.defensive_multipliers["w_face"] = 4.0

	# Assert
	assert_dict(config).is_equal(before)


# --- validate_profiles_config: the stub and the row shape ----------------------

func test_validate_stub_reports_no_rows() -> void:
	# Act
	var rows: Array = _validate(_stub())

	# Assert
	assert_array(rows).override_failure_message(str(rows)).is_empty()


func test_validate_rows_have_the_validation_report_entry_shape() -> void:
	# Arrange
	var config: Dictionary = _stub()
	config.profiles.aggro.weights["w_face"] = 9.0
	config["colour"] = "red"

	# Act
	var rows: Array = _validate(config)

	# Assert
	assert_int(rows.size()).is_equal(2)
	for e: Dictionary in rows:
		assert_array(e.keys()).contains_exactly_in_any_order(ENTRY_KEYS)
		assert_bool(e.severity == ValidationReport.SEVERITY_ERROR).is_true()
		assert_str(e.file).is_equal(BossAI.PROFILES_FILE)
		assert_str(e.message).is_not_empty()


# --- validate_profiles_config: ranges (A26) -----------------------------------

func test_validate_weight_above_range_reports_weight_range() -> void:
	# Arrange — A26
	var config: Dictionary = _stub()
	config.profiles.aggro.weights["w_face"] = 9.0

	# Act
	var rows: Array = _validate(config)

	# Assert
	_only_code(rows, BossAI.E_AI_WEIGHT_RANGE)
	assert_str(rows[0].record_id).is_equal("profiles.aggro")
	assert_str(rows[0].field).is_equal("weights.w_face")


func test_validate_non_finite_or_non_number_weight_reports_weight_range() -> void:
	# Arrange
	var config: Dictionary = _stub()
	config.profiles.aggro.weights["w_face"] = INF
	config.profiles.aggro.weights["w_board"] = NAN
	config.profiles.passive_driven.weights["w_passive"] = "2.5"
	config.bands["1"].weights["w_over"] = false

	# Act
	var rows: Array = _validate(config)

	# Assert
	assert_array(_codes(rows)).is_equal([BossAI.E_AI_WEIGHT_RANGE, BossAI.E_AI_WEIGHT_RANGE, BossAI.E_AI_WEIGHT_RANGE, BossAI.E_AI_WEIGHT_RANGE])


func test_validate_range_bounds_are_inclusive() -> void:
	# Arrange — boundary values: the exact number is the point
	var config: Dictionary = _stub()
	config.profiles.aggro.weights["w_face"] = BossAI.RANGES.w_face.max
	config.profiles.aggro.weights["w_board"] = BossAI.RANGES.w_board.min
	var over: Dictionary = _stub()
	over.profiles.aggro.weights["w_face"] = BossAI.RANGES.w_face.max + 0.001

	# Act / Assert
	assert_array(_validate(config)).is_empty()
	_only_code(_validate(over), BossAI.E_AI_WEIGHT_RANGE)


func test_validate_integral_knobs_accept_whole_floats_and_reject_fractions() -> void:
	# Arrange — JSON numbers are float (ADR-0002): 4.0 is an int knob's 4
	var whole: Dictionary = _stub()
	whole.profiles.aggro.rules["overextend_cap_aoe"] = 5.0
	whole.profiles.aggro.rules["defensive_margin"] = 2.0
	var fractional: Dictionary = _stub()
	fractional.profiles.aggro.rules["overextend_cap_aoe"] = 4.5
	fractional.bands["1"].budgets["lethal_max_nodes"] = 50.5

	# Act
	var rows: Array = _validate(fractional)

	# Assert
	assert_array(_validate(whole)).is_empty()
	assert_array(_codes(rows)).is_equal([BossAI.E_AI_WEIGHT_RANGE, BossAI.E_AI_WEIGHT_RANGE])
	assert_array(_fields(rows)).contains_exactly_in_any_order(["rules.overextend_cap_aoe", "budgets.lethal_max_nodes"])


func test_validate_op_keyword_preference_and_presentation_values_are_ranged() -> void:
	# Arrange — F9 op_values 0–5, F2 keyword multipliers 1.0–1.5, F9 choice_preference 0–1, Tuning Knobs presentation
	var config: Dictionary = _stub()
	config.op_values["damage"] = 6.0
	config.keyword_values["taunt"] = 0.9
	config.profiles.aggro.choice_preference["charge"] = 1.5
	config.presentation["action_delay_s"] = 3.0

	# Act
	var rows: Array = _validate(config)

	# Assert
	assert_array(_codes(rows)).is_equal([BossAI.E_AI_WEIGHT_RANGE, BossAI.E_AI_WEIGHT_RANGE, BossAI.E_AI_WEIGHT_RANGE, BossAI.E_AI_WEIGHT_RANGE])
	assert_array(_fields(rows)).contains_exactly_in_any_order(["op_values.damage", "keyword_values.taunt", "choice_preference.charge", "presentation.action_delay_s"])


func test_validate_default_profile_must_carry_every_weight_and_rule() -> void:
	# Arrange — no code default exists (A29), so default is the floor
	var config: Dictionary = _stub()
	config.profiles.default.weights.erase("w_hp")
	config.profiles.default.rules.erase("hero_power")

	# Act
	var rows: Array = _validate(config)

	# Assert
	assert_array(_codes(rows)).contains_exactly_in_any_order([BossAI.E_AI_WEIGHT_RANGE, BossAI.E_AI_UNKNOWN_FIELD])
	assert_array(_fields(rows)).contains_exactly_in_any_order(["weights.w_hp", "rules.hero_power"])


func test_validate_default_profile_must_carry_each_f2_bonus() -> void:
	for key: String in F2_RULES:
		# Arrange: A29: no code default exists for these either
		var config: Dictionary = _stub()
		config.profiles.default.rules.erase(key)

		# Act
		var rows: Array = _validate(config)

		# Assert
		assert_array(_codes(rows)).contains_exactly([BossAI.E_AI_WEIGHT_RANGE])
		assert_array(_fields(rows)).contains_exactly(["rules.%s" % key])


func test_validate_an_f2_bonus_holds_zero_to_three_and_no_further() -> void:
	for key: String in F2_RULES:
		# Arrange: F2's Range column
		var low: Dictionary = _stub()
		low.profiles.default.rules[key] = 0
		var high: Dictionary = _stub()
		high.profiles.default.rules[key] = 3
		var over: Dictionary = _stub()
		over.profiles.default.rules[key] = 3.5
		var under: Dictionary = _stub()
		under.profiles.default.rules[key] = -0.5

		# Act and Assert
		assert_array(_validate(low)).is_empty()
		assert_array(_validate(high)).is_empty()
		assert_array(_codes(_validate(over))).contains_exactly([BossAI.E_AI_WEIGHT_RANGE])
		assert_array(_codes(_validate(under))).contains_exactly([BossAI.E_AI_WEIGHT_RANGE])


func test_resolve_an_f2_bonus_is_tunable_by_a_band_like_any_rule() -> void:
	# Arrange
	var config: Dictionary = _stub()
	config.bands["3"].rules["taunt_bonus"] = 2.5

	# Act
	var tuned: Dictionary = ProfileResolver.resolve(config, _boss("default", 3), 3)
	var untouched: Dictionary = ProfileResolver.resolve(config, _boss("default", 2), 2)

	# Assert
	assert_float(float(tuned.rules.taunt_bonus)).is_equal(2.5)
	assert_float(float(untouched.rules.taunt_bonus)).is_equal(1.5)


func test_validate_every_band_must_carry_every_budget() -> void:
	# Arrange
	var config: Dictionary = _stub()
	config.bands["2"].budgets.erase("max_actions_per_turn")

	# Act
	var rows: Array = _validate(config)

	# Assert
	_only_code(rows, BossAI.E_AI_WEIGHT_RANGE)
	assert_str(rows[0].record_id).is_equal("bands.2")


# --- validate_profiles_config: closed field sets ------------------------------

func test_validate_unknown_field_at_every_level_reports_unknown_field() -> void:
	# Arrange
	var config: Dictionary = _stub()
	config["colour"] = "red"
	config.profiles.aggro["mood"] = "angry"
	config.profiles.aggro.weights["w_luck"] = 1.0
	config.profiles.aggro.rules["aggression"] = 2.0
	config.bands["1"].budgets["max_seconds"] = 3
	config.runtime["threads"] = 4
	config.presentation["fade_s"] = 0.5
	config.profiles.default.rules.defensive_multipliers["w_luck"] = 1.0

	# Act
	var rows: Array = _validate(config)

	# Assert
	assert_int(rows.size()).is_equal(8)
	for e: Dictionary in rows:
		assert_str(String(e.code)).override_failure_message(str(e)).is_equal(String(BossAI.E_AI_UNKNOWN_FIELD))


func test_validate_underscore_note_keys_are_unknown_fields() -> void:
	# Arrange — no `_note` escape: reasons live in content.md B2 (story 003)
	var config: Dictionary = _stub()
	config.boss_overrides.boss_rot_warden["_note"] = "deathrattle theme"

	# Act / Assert
	_only_code(_validate(config), BossAI.E_AI_UNKNOWN_FIELD)


func test_validate_bad_enum_values_report_unknown_field() -> void:
	# Arrange
	var config: Dictionary = _stub()
	config.profiles.aggro.rules["hero_power"] = "sometimes"
	config.bands["1"].rules["lethal_search"] = "deep"
	config.boss_overrides.boss_rot_warden["intent_mode"] = "loud"
	config.profiles.aggro.rules["assume_aoe"] = "yes"

	# Act
	var rows: Array = _validate(config)

	# Assert
	assert_array(_codes(rows)).is_equal([BossAI.E_AI_UNKNOWN_FIELD, BossAI.E_AI_UNKNOWN_FIELD, BossAI.E_AI_UNKNOWN_FIELD, BossAI.E_AI_UNKNOWN_FIELD])


func test_validate_hidden_intent_outside_boss_overrides_is_rejected() -> void:
	# Arrange — C8.4, D-04
	var config: Dictionary = _stub()
	config.profiles.aggro["intent_mode"] = "hidden"
	config.bands["3"]["intent_mode"] = "hidden"
	var in_override: Dictionary = _stub()
	in_override.boss_overrides.boss_rot_warden["intent_mode"] = "hidden"

	# Act
	var rows: Array = _validate(config)

	# Assert
	assert_array(_codes(rows)).is_equal([BossAI.E_AI_UNKNOWN_FIELD, BossAI.E_AI_UNKNOWN_FIELD])
	assert_array(rows.map(func(e: Dictionary) -> Variant: return e.record_id)).contains_exactly_in_any_order(["profiles.aggro", "bands.3"])
	assert_array(_validate(in_override)).is_empty()


func test_validate_extends_outside_boss_overrides_is_unknown_field() -> void:
	# Arrange
	var config: Dictionary = _stub()
	config.profiles.aggro["extends"] = "default"

	# Act / Assert
	_only_code(_validate(config), BossAI.E_AI_UNKNOWN_FIELD)


func test_validate_override_with_unknown_or_missing_extends_reports_profile_unknown() -> void:
	# Arrange
	var config: Dictionary = _stub()
	config.boss_overrides["boss_a"] = {"extends": "no_such_archetype"}
	config.boss_overrides["boss_b"] = {"weights": {"w_face": 2.0}}
	config.boss_overrides["boss_c"] = {"extends": "boss_rot_warden"}

	# Act
	var rows: Array = _validate(config)

	# Assert — an override extends a `profiles` key, never another override
	assert_array(_codes(rows)).is_equal([BossAI.E_AI_PROFILE_UNKNOWN, BossAI.E_AI_PROFILE_UNKNOWN, BossAI.E_AI_PROFILE_UNKNOWN])


func test_validate_missing_section_or_band_is_reported() -> void:
	# Arrange
	var no_bands: Dictionary = _stub()
	no_bands.erase("bands")
	var no_band_two: Dictionary = _stub()
	no_band_two.bands.erase("2")
	var no_default: Dictionary = _stub()
	no_default.profiles.erase("default")
	var extra_band: Dictionary = _stub()
	extra_band.bands["4"] = {}

	# Act / Assert
	_only_code(_validate(no_bands), BossAI.E_AI_UNKNOWN_FIELD)
	_only_code(_validate(no_band_two), BossAI.E_AI_UNKNOWN_FIELD)
	_only_code(_validate(no_default), BossAI.E_AI_UNKNOWN_FIELD)
	_only_code(_validate(extra_band), BossAI.E_AI_UNKNOWN_FIELD)


# --- validate_profiles_config: the runtime block (ADR-0006) -------------------

func test_validate_runtime_accepts_each_planner_mode() -> void:
	for mode: String in ["worker", "time_sliced", "immediate"]:
		# Arrange
		var config: Dictionary = _stub()
		config.runtime["planner_mode"] = mode

		# Act / Assert
		assert_array(_validate(config)).override_failure_message(mode).is_empty()


func test_validate_runtime_rejects_anything_else() -> void:
	# Arrange
	var bad_mode: Dictionary = _stub()
	bad_mode.runtime["planner_mode"] = "threaded"
	var zero_slice: Dictionary = _stub()
	zero_slice.runtime["slice_ms"] = 0
	var text_budget: Dictionary = _stub()
	text_budget.runtime["replay_budget_ms"] = "2"
	var missing_slice: Dictionary = _stub()
	missing_slice.runtime.erase("slice_ms")
	var no_runtime: Dictionary = _stub()
	no_runtime.erase("runtime")

	# Act / Assert
	_only_code(_validate(bad_mode), BossAI.E_AI_UNKNOWN_FIELD)
	_only_code(_validate(zero_slice), BossAI.E_AI_WEIGHT_RANGE)
	_only_code(_validate(text_budget), BossAI.E_AI_WEIGHT_RANGE)
	_only_code(_validate(missing_slice), BossAI.E_AI_WEIGHT_RANGE)
	_only_code(_validate(no_runtime), BossAI.E_AI_UNKNOWN_FIELD)


func test_validate_runtime_planner_target_accepts_its_range() -> void:
	for value: Variant in [50, 500, 1000]:
		# Arrange
		var config: Dictionary = _stub()
		config.runtime["planner_target_ms"] = value

		# Act / Assert
		assert_array(_validate(config)).override_failure_message(str(value)).is_empty()


func test_validate_runtime_planner_target_rejects_a_value_out_of_range_or_not_a_number() -> void:
	for value: Variant in [49, 1001, 49.9, 1000.1, 0, -500, "500", null, true, NAN, INF, -INF]:
		# Arrange
		var config: Dictionary = _stub()
		config.runtime["planner_target_ms"] = value

		# Act
		var rows: Array = _validate(config)

		# Assert
		_only_code(rows, BossAI.E_AI_WEIGHT_RANGE)
		assert_array(_fields(rows)).override_failure_message(str(value)).is_equal(["runtime.planner_target_ms"])


func test_validate_runtime_planner_target_is_required_like_the_other_runtime_keys() -> void:
	# Arrange
	var config: Dictionary = _stub()
	config.runtime.erase("planner_target_ms")

	# Act
	var rows: Array = _validate(config)

	# Assert
	_only_code(rows, BossAI.E_AI_WEIGHT_RANGE)
	assert_array(_fields(rows)).is_equal(["runtime.planner_target_ms"])


func test_planner_target_bounds_live_in_the_named_range_table() -> void:
	# Act
	var ranges: Dictionary = BossAI.RANGES
	var bounds: Dictionary = ranges.get("planner_target_ms", {})

	# Assert — boss-ai Tuning Knobs: safe range 50–1,000 (A29: no bare literal)
	assert_float(float(bounds.get("min", 0.0))).is_equal(50.0)
	assert_float(float(bounds.get("max", 0.0))).is_equal(1000.0)


# --- E_AI_OP_UNVALUED (Edge Cases) --------------------------------------------

func test_op_coverage_reports_each_unvalued_op_once_including_nested_ops() -> void:
	# Arrange — the stub values damage, heal, buff, summon, draw
	var op_values: Dictionary = _stub().op_values
	var cards: Array = [
		_card_with_ops("neutral_a", [CardFactory.make_op("discard", {"count": 1}), CardFactory.make_op("damage", {"amount": 1})]),
		_card_with_ops("neutral_b", [CardFactory.make_op("discard", {"count": 2})]),
		_card_with_ops("neutral_c", [CardFactory.make_op("conditional", {"if": {}, "then": [CardFactory.make_op("shuffle_into_deck")], "else": [CardFactory.make_op("draw")]})]),
		_card_with_ops("neutral_d", [CardFactory.make_op("repeat", {"times": 2, "ops": [CardFactory.make_op("weapon_durability")]})]),
		_card_with_ops("neutral_e", [CardFactory.make_op("choose_one", {"options": [{"label_key": "a", "ops": [CardFactory.make_op("add_counter")]}, {"label_key": "b", "ops": [CardFactory.make_op("heal")]}]})]),
	]

	# Act
	var rows: Array = BossAI.validate_op_coverage(op_values, cards)

	# Assert — once per op type, sorted by op name; structural ops are never rows
	assert_array(_codes(rows)).is_equal([BossAI.E_AI_OP_UNVALUED, BossAI.E_AI_OP_UNVALUED, BossAI.E_AI_OP_UNVALUED, BossAI.E_AI_OP_UNVALUED])
	assert_array(_fields(rows)).is_equal(["op_values.add_counter", "op_values.discard", "op_values.shuffle_into_deck", "op_values.weapon_durability"])


func test_op_coverage_values_aura_and_modify_value_as_buff() -> void:
	# Arrange — C6: aura and modify_value are valued as buff
	var op_values: Dictionary = _stub().op_values
	var cards: Array = [_card_with_ops("neutral_lord", [CardFactory.make_op("aura", {"attack": 1}), CardFactory.make_op("modify_value", {"delta": 1})])]
	var without_buff: Dictionary = op_values.duplicate()
	without_buff.erase("buff")

	# Act / Assert
	assert_array(BossAI.validate_op_coverage(op_values, cards)).is_empty()
	var rows: Array = BossAI.validate_op_coverage(without_buff, cards)
	_only_code(rows, BossAI.E_AI_OP_UNVALUED)
	assert_str(rows[0].field).is_equal("op_values.buff")


func test_validate_profiles_config_reads_cards_through_the_stage7_lookup() -> void:
	# Arrange
	var db: FakeLookupDb = FakeLookupDb.new()
	db.by_type = {
		"spell": [_card_with_ops("neutral_s", [CardFactory.make_op("discard")])],
		"minion": [CardFactory.make_minion("neutral_m", 1, 1, 1, [], {"effects": [CardFactory.make_effect("battlecry", [CardFactory.make_op("discard")])]})],
	}

	# Act
	var rows: Array = BossAI.validate_profiles_config(_stub(), db)

	# Assert — two cards, one op type, one row
	_only_code(rows, BossAI.E_AI_OP_UNVALUED)
	assert_str(rows[0].field).is_equal("op_values.discard")


# --- validate_ai_profile: the stage-7b record validator (A25) -----------------

func test_validate_ai_profile_accepts_profile_and_override_keys() -> void:
	# Arrange
	var configs: Dictionary = {"ai_profiles": _stub()}

	# Act / Assert
	for key: String in ["default", "aggro", "boss_rot_warden"]:
		assert_array(BossAI.validate_ai_profile(&"boss", "boss_test", key, null, configs)).override_failure_message(key).is_empty()


func test_validate_ai_profile_unknown_key_reports_profile_unknown() -> void:
	# Act — A25
	var rows: Array = BossAI.validate_ai_profile(&"boss", "boss_test", "does_not_exist", null, {"ai_profiles": _stub()})

	# Assert
	_only_code(rows, BossAI.E_AI_PROFILE_UNKNOWN)
	assert_array(rows[0].keys()).contains_exactly_in_any_order(ENTRY_KEYS)
	assert_str(rows[0].file).is_equal(BossAI.BOSSES_FILE)
	assert_str(rows[0].record_id).is_equal("boss_test")
	assert_str(rows[0].field).is_equal("ai_profile")


func test_validate_ai_profile_missing_or_non_string_key_reports_profile_unknown() -> void:
	# Arrange
	var configs: Dictionary = {"ai_profiles": _stub()}

	# Act / Assert
	_only_code(BossAI.validate_ai_profile(&"boss", "boss_test", null, null, configs), BossAI.E_AI_PROFILE_UNKNOWN)
	_only_code(BossAI.validate_ai_profile(&"boss", "boss_test", 3.0, null, configs), BossAI.E_AI_PROFILE_UNKNOWN)


func test_validate_ai_profile_without_the_ai_profiles_body_reports_instead_of_passing() -> void:
	# Act — the config failed 7a or was never loaded: the key cannot be resolved
	var rows: Array = BossAI.validate_ai_profile(&"boss", "boss_test", "aggro", null, {})

	# Assert
	_only_code(rows, BossAI.E_AI_PROFILE_UNKNOWN)


func test_validate_profile_key_is_the_pure_core_named_by_adr_0002() -> void:
	# Arrange
	var config: Dictionary = _stub()

	# Act / Assert
	assert_array(BossAI.validate_profile_key("aggro", config)).is_empty()
	_only_code(BossAI.validate_profile_key("nope", config), BossAI.E_AI_PROFILE_UNKNOWN)


# --- composition and the missing-file path ------------------------------------

func test_boot_registers_the_validator_as_the_ai_profiles_config_validator() -> void:
	# Arrange — a fresh Boot instance; boot() is not called
	var boot: Node = auto_free(BOOT_SCRIPT.new())
	var bad: Dictionary = _stub()
	bad.profiles.aggro.weights["w_face"] = 9.0

	# Act
	var registered: Callable = boot._collect_validators(null).configs.get("ai_profiles", Callable())

	# Assert — the registered Callable is this validator, in the 7a shape
	assert_bool(registered.is_valid()).is_true()
	assert_array(registered.call(_stub(), null)).is_empty()
	assert_array(_codes(registered.call(bad, null))).is_equal([BossAI.E_AI_WEIGHT_RANGE])


func test_ai_profiles_is_a_required_manifest_config_so_absence_is_e_missing_file() -> void:
	# Arrange — Edge Cases: the file's absence is CR-1's E_MISSING_FILE, not a runtime default
	var row: Dictionary = {}
	for candidate: Dictionary in DataLoader.FILE_MANIFEST:
		if candidate.name == BossAI.PROFILES_FILE:
			row = candidate

	# Assert
	assert_str(row.get("class", "")).is_equal("config")
	assert_bool(row.get("required", false)).is_true()


func test_ranges_table_names_a_formula_row_for_every_entry() -> void:
	for key: String in BossAI.RANGES:
		var entry: Dictionary = BossAI.RANGES[key]
		assert_bool(float(entry.min) <= float(entry.max)).override_failure_message(key).is_true()
		assert_str(String(entry.row)).override_failure_message(key).is_not_empty()
