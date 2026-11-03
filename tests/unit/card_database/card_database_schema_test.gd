## Unit tests for CR-5 stage 4, the per-record schema (story
## card-database/story-002; card-database CR-2, CR-3, CR-4, CR-5 step 4, Edge
## Cases "Enums and shapes" and "Pools and lists"; ADR-0002 Decision 3).
##
## File I/O note: like story 001's suites these read committed, read-only
## fixture roots under `res://tests/fixtures/data/<case>/` through an injected
## `DataLoader` root (QA plan CDB-002 File I/O note). `clean/` is a small,
## coherent data set (one hero, 14 cards, two bosses, ten treasures, three
## bundles) that loads with an empty report; every `schema_*` root is `clean/`
## plus the faulty records or knobs its test names.
extends GdUnitTestSuite

const FIXTURES: String = "res://tests/fixtures/data/"
## The stage-4 codes. Later stages add their own codes to the same report, so
## the per-record checks below look at these only.
const STAGE_4_CODES: Array[StringName] = [
	&"E_SCHEMA", &"E_MISSING_FIELD", &"E_UNKNOWN_FIELD", &"E_BAD_ENUM", &"E_SET_MISMATCH", &"E_TEXT_KEY",
]
## `schema_cards/cards_war.json`: each faulty CardDef → its one [code, field].
const CARD_FAULTS: Dictionary = {
	"war_typo_field": [&"E_UNKNOWN_FIELD", "durabilty"],
	"war_spell_attack": [&"E_UNKNOWN_FIELD", "attack"],
	"war_no_health": [&"E_MISSING_FIELD", "health"],
	"war_no_durability": [&"E_MISSING_FIELD", "durability"],
	"war_zero_health": [&"E_SCHEMA", "health"],
	"war_zero_durability": [&"E_SCHEMA", "durability"],
	"war_cost_eleven": [&"E_SCHEMA", "cost"],
	"war_cost_negative": [&"E_SCHEMA", "cost"],
	"war_cost_fraction": [&"E_SCHEMA", "cost"],
	"war_bad_keyword": [&"E_BAD_ENUM", "keywords"],
	"war_repeat_keyword": [&"E_SCHEMA", "keywords"],
	"war_spell_damage_alone": [&"E_SCHEMA", "spell_damage"],
	"war_keyword_alone": [&"E_SCHEMA", "spell_damage"],
	"War_Bad_Id": [&"E_SCHEMA", "id"],
	"war_set_neutral": [&"E_SET_MISMATCH", "set"],
	"neutral_in_war_file": [&"E_SET_MISMATCH", "id"],
	"war_text_key": [&"E_TEXT_KEY", "text.key"],
}
## `schema_cards/cards_war.json`: boundary and integral-float records that pass.
const CARD_PASSES: Array[String] = ["war_cost_zero", "war_cost_ten", "war_float_ok", "war_battle_cry", "war_recruit"]
const KNOB_KEYS: Array[String] = [
	"min_collectible_pool", "min_bundle_pool", "max_records", "data_load_budget_ms", "data_memory_budget_mb",
]


func _run(case_name: String) -> DataLoader.LoadResult:
	return DataLoader.new(FIXTURES + case_name).run({})


func _load(case_name: String) -> CardDatabase:
	var db: CardDatabase = CardDatabase.new(DataLoader.new(FIXTURES + case_name))
	db.load({})
	return db


## The stage-4 entries `report` holds for `record_id` in `file_name`.
func _stage4(report: ValidationReport, file_name: String, record_id: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in report.entries():
		if e.file == file_name and e.record_id == record_id and STAGE_4_CODES.has(StringName(e.code)):
			out.append(e)
	return out


func _for_file(report: ValidationReport, file_name: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in report.entries():
		if e.file == file_name:
			out.append(e)
	return out


## Asserts `report` holds exactly one stage-4 entry for `record_id`, with
## `code` and `field`, and returns it.
func _assert_one(report: ValidationReport, file_name: String, record_id: String, code: StringName, field: String) -> Dictionary:
	var hits: Array[Dictionary] = _stage4(report, file_name, record_id)
	var where: String = "%s [%s]: %s" % [file_name, record_id, str(hits)]
	assert_int(hits.size()).override_failure_message("expected one entry, " + where).is_equal(1)
	if hits.size() != 1:
		return {}
	assert_str(String(hits[0].code)).override_failure_message(where).is_equal(String(code))
	assert_str(str(hits[0].field)).override_failure_message(where).is_equal(field)
	assert_str(String(hits[0].severity)).is_equal(String(ValidationReport.SEVERITY_ERROR))
	return hits[0]


# --- the clean root -------------------------------------------------------------

func test_clean_root_loads_ready_with_an_empty_report() -> void:
	# Act
	var db: CardDatabase = _load("clean")

	# Assert
	assert_array(db.report().entries()).is_empty()
	assert_int(db.state()).is_equal(CardDatabase.State.READY)


func test_schema_enum_lists_match_the_card_factory_mirrors() -> void:
	# CR-4 lists live in RecordSchemas; CardFactory mirrors them for tests.
	assert_array(RecordSchemas.SETS).is_equal(CardFactory.SETS)
	assert_array(RecordSchemas.TYPES).is_equal(CardFactory.TYPES)
	assert_array(RecordSchemas.RARITIES).is_equal(CardFactory.RARITIES)
	assert_array(RecordSchemas.KEYWORDS).is_equal(CardFactory.KEYWORDS)
	assert_str(RecordSchemas.ID_PATTERN).is_equal(CardFactory.ID_PATTERN)


# --- AC-1: CardDef faults, all in one report --------------------------------------

func test_each_card_fault_raises_its_code_naming_file_record_and_field() -> void:
	# Act
	var report: ValidationReport = _run("schema_cards").report

	# Assert — one entry per faulty record, every one in the same report
	for record_id: String in CARD_FAULTS:
		var expected: Array = CARD_FAULTS[record_id]
		_assert_one(report, "cards_war.json", record_id, expected[0], expected[1])


func test_card_faults_are_collected_without_fail_fast() -> void:
	# Act
	var result: DataLoader.LoadResult = _run("schema_cards")

	# Assert — seventeen faulty records, seventeen errors, no snapshot
	var stage4: Array = _for_file(result.report, "cards_war.json").filter(
		func(e: Dictionary) -> bool: return STAGE_4_CODES.has(StringName(e.code)))
	assert_int(stage4.size()).is_equal(CARD_FAULTS.size())
	assert_that(result.snapshot).is_null()


func test_boundary_costs_and_integral_floats_pass_the_schema() -> void:
	# Act — cost 0 and 10, attack/health 99, cost 3.0 / attack 2.0 (JSON floats)
	var report: ValidationReport = _run("schema_cards").report

	# Assert
	for record_id: String in CARD_PASSES:
		assert_array(_stage4(report, "cards_war.json", record_id)).override_failure_message(record_id).is_empty()


func test_fractional_cost_message_says_it_is_not_a_whole_number() -> void:
	# Act
	var entry: Dictionary = _assert_one(_run("schema_cards").report, "cards_war.json", "war_cost_fraction", &"E_SCHEMA", "cost")

	# Assert — 3.5 is rejected, not truncated
	assert_str(entry.get("message", "")).contains("3.5")


func test_unknown_keyword_message_names_the_keyword() -> void:
	var entry: Dictionary = _assert_one(_run("schema_cards").report, "cards_war.json", "war_bad_keyword", &"E_BAD_ENUM", "keywords")
	assert_str(entry.get("message", "")).contains("flying")


func test_set_mismatch_messages_name_the_file_set() -> void:
	# Act
	var report: ValidationReport = _run("schema_cards").report

	# Assert
	var by_set: Dictionary = _assert_one(report, "cards_war.json", "war_set_neutral", &"E_SET_MISMATCH", "set")
	var by_prefix: Dictionary = _assert_one(report, "cards_war.json", "neutral_in_war_file", &"E_SET_MISMATCH", "id")
	assert_str(by_set.get("message", "")).contains("war")
	assert_str(by_prefix.get("message", "")).contains("war_")


func test_text_key_message_names_the_expected_key() -> void:
	var entry: Dictionary = _assert_one(_run("schema_cards").report, "cards_war.json", "war_text_key", &"E_TEXT_KEY", "text.key")
	assert_str(entry.get("message", "")).contains("card.war_text_key.text")


# --- AC-2: card_database.json, the one config body checked here --------------------

func test_min_bundle_pool_below_range_is_e_schema_naming_file_and_key_and_fails() -> void:
	# Act
	var db: CardDatabase = _load("schema_knobs")

	# Assert
	var hits: Array[Dictionary] = _for_file(db.report(), "card_database.json")
	assert_int(hits.size()).is_equal(1)
	assert_str(String(hits[0].code)).is_equal("E_SCHEMA")
	assert_str(str(hits[0].field)).is_equal("min_bundle_pool")
	assert_object(hits[0].record_id).is_null()
	assert_str(hits[0].message).contains("3")
	assert_str(hits[0].message).contains("30")
	assert_int(db.state()).is_equal(CardDatabase.State.FAILED)


func test_no_other_config_body_is_schema_checked_at_stage_4() -> void:
	# Act — run_ui.json holds arbitrary keys, match_ui.json a negative
	# `min_bundle_pool`; neither is the loader's to judge
	var report: ValidationReport = _run("schema_knobs").report

	# Assert
	assert_array(_for_file(report, "run_ui.json")).is_empty()
	assert_array(_for_file(report, "match_ui.json")).is_empty()


func test_missing_extra_and_fractional_knobs_are_each_e_schema() -> void:
	# Act
	var hits: Array[Dictionary] = _for_file(_run("schema_knob_shape").report, "card_database.json")

	# Assert
	var fields: Array = hits.map(func(e: Dictionary) -> String: return str(e.field))
	assert_array(fields).contains_exactly_in_any_order(["max_records", "min_tresure_pool", "data_load_budget_ms"])
	for e: Dictionary in hits:
		assert_str(String(e.code)).is_equal("E_SCHEMA")


func test_knobs_at_their_low_range_edges_raise_no_entry() -> void:
	# Act — 10 / 3 / 1 / 50 / 1
	var db: CardDatabase = _load("schema_knob_edges_low")

	# Assert
	assert_array(_for_file(db.report(), "card_database.json")).is_empty()
	assert_int(db.state()).is_equal(CardDatabase.State.READY)


func test_knobs_at_their_high_range_edges_raise_no_entry() -> void:
	# Act — 100 / 30 / 5000 / 1000 / 32
	var report: ValidationReport = _run("schema_knob_edges_high").report

	# Assert
	assert_array(_for_file(report, "card_database.json")).is_empty()


func test_knob_ranges_are_the_formulas_ranges() -> void:
	# Format knowledge (card-database Formulas), not tuning values.
	assert_array(RecordSchemas.KNOB_RANGES.keys()).contains_exactly_in_any_order(KNOB_KEYS)
	assert_array(RecordSchemas.KNOB_RANGES.min_collectible_pool).is_equal([10, 100])
	assert_array(RecordSchemas.KNOB_RANGES.min_bundle_pool).is_equal([3, 30])
	assert_array(RecordSchemas.KNOB_RANGES.data_load_budget_ms).is_equal([50, 1000])
	assert_array(RecordSchemas.KNOB_RANGES.data_memory_budget_mb).is_equal([1, 32])


# --- AC-3: unlock shapes and hero_power -----------------------------------------------

func test_bare_string_hero_unlock_is_a_schema_error_naming_unlock() -> void:
	# Act
	var report: ValidationReport = _run("schema_unlock").report

	# Assert
	var hits: Array = _stage4(report, "heroes.json", "hero_war").filter(func(e: Dictionary) -> bool: return e.field == "unlock")
	assert_int(hits.size()).is_equal(1)
	assert_str(String(hits[0].code)).is_equal("E_SCHEMA")
	assert_str(hits[0].message).contains("null")


func test_hero_power_null_on_a_hero_is_e_missing_field() -> void:
	# Act
	var report: ValidationReport = _run("schema_unlock").report

	# Assert
	var hits: Array = _stage4(report, "heroes.json", "hero_war").filter(func(e: Dictionary) -> bool: return e.field == "hero_power")
	assert_int(hits.size()).is_equal(1)
	assert_str(String(hits[0].code)).is_equal("E_MISSING_FIELD")


func test_bundle_unlock_object_passes_the_schema_stage() -> void:
	# Act — {key: "bundle_x", condition: {type: "always"}}; the body of
	# `condition` is Meta Progression's (stage 7)
	var report: ValidationReport = _run("schema_unlock").report

	# Assert
	assert_array(_stage4(report, "bundles.json", "bundle_war_weapons")).is_empty()


func test_bundle_unlock_object_without_condition_is_e_schema() -> void:
	var hits: Array[Dictionary] = _stage4(_run("schema_unlock").report, "bundles.json", "bundle_war_armor")
	assert_int(hits.size()).is_equal(1)
	assert_str(String(hits[0].code)).is_equal("E_SCHEMA")
	assert_str(str(hits[0].field)).is_equal("unlock")


func test_bundles_with_unlock_null_raise_no_error_or_warning() -> void:
	# Act — every clean bundle carries unlock: null
	var report: ValidationReport = _run("clean").report

	# Assert
	assert_array(_for_file(report, "bundles.json")).is_empty()


# --- AC-4: treasures, boss passive pairs ------------------------------------------------

func test_treasure_tags_and_boss_with_passive_and_text_pass() -> void:
	# Act — treasure_t01 tags ["war", "weapons"]; boss_bone_king has both
	var report: ValidationReport = _run("schema_boss").report

	# Assert
	assert_array(_for_file(report, "treasures.json")).is_empty()
	assert_array(_stage4(report, "bosses.json", "boss_bone_king")).is_empty()
	assert_array(_stage4(report, "bosses.json", "boss_rot_warden")).is_empty()


func test_boss_with_passive_and_no_passive_text_is_e_missing_field() -> void:
	_assert_one(_run("schema_boss").report, "bosses.json", "boss_mute_wraith", &"E_MISSING_FIELD", "passive_text")


func test_boss_with_null_passive_and_a_passive_text_is_e_unknown_field() -> void:
	_assert_one(_run("schema_boss").report, "bosses.json", "boss_chatter_ghoul", &"E_UNKNOWN_FIELD", "passive_text")


func test_boss_with_null_passive_and_null_hero_power_is_e_schema() -> void:
	_assert_one(_run("schema_boss").report, "bosses.json", "boss_empty_husk", &"E_SCHEMA", "hero_power")


func test_boss_band_deck_tags_and_passive_text_key_are_checked() -> void:
	# Act — band 4, deck [], tag "Undead", passive_text key of another boss
	var hits: Array[Dictionary] = _stage4(_run("schema_boss").report, "bosses.json", "boss_wrong_key")

	# Assert
	var found: Array = hits.map(func(e: Dictionary) -> String: return "%s %s" % [e.code, e.field])
	assert_array(found).contains_exactly_in_any_order([
		"E_SCHEMA band", "E_SCHEMA deck", "E_SCHEMA tags", "E_TEXT_KEY passive_text.key",
	])


# --- the other record types -------------------------------------------------------

func test_hero_set_health_list_entries_and_text_shape_are_checked() -> void:
	var hits: Array[Dictionary] = _stage4(_run("schema_types").report, "heroes.json", "hero_neutral")
	var found: Array = hits.map(func(e: Dictionary) -> String: return "%s %s" % [e.code, e.field])
	assert_array(found).contains_exactly_in_any_order([
		"E_BAD_ENUM set", "E_SCHEMA health", "E_SCHEMA starter_deck", "E_MISSING_FIELD text.en",
	])


func test_hero_power_cost_range_and_effects_shape_are_checked() -> void:
	var hits: Array[Dictionary] = _stage4(_run("schema_types").report, "hero_powers.json", "power_costly")
	var found: Array = hits.map(func(e: Dictionary) -> String: return "%s %s" % [e.code, e.field])
	assert_array(found).contains_exactly_in_any_order(["E_SCHEMA cost", "E_SCHEMA effects"])


func test_record_type_id_prefix_mismatch_is_e_set_mismatch() -> void:
	# Act — a HeroPowerDef named skill_…, a war bundle named bundle_neutral_…
	var report: ValidationReport = _run("schema_types").report

	# Assert
	_assert_one(report, "hero_powers.json", "skill_misnamed", &"E_SET_MISMATCH", "id")
	_assert_one(report, "bundles.json", "bundle_neutral_steel", &"E_SET_MISMATCH", "id")


func test_treasure_rarity_is_common_or_rare_and_tags_follow_the_tag_pattern() -> void:
	var hits: Array[Dictionary] = _stage4(_run("schema_types").report, "treasures.json", "treasure_epic")
	var found: Array = hits.map(func(e: Dictionary) -> String: return "%s %s" % [e.code, e.field])
	assert_array(found).contains_exactly_in_any_order(["E_BAD_ENUM rarity", "E_SCHEMA tags"])


func test_bundle_set_is_never_boss_and_bundles_carry_no_art() -> void:
	var hits: Array[Dictionary] = _stage4(_run("schema_types").report, "bundles.json", "bundle_boss_bones")
	var found: Array = hits.map(func(e: Dictionary) -> String: return "%s %s" % [e.code, e.field])
	assert_array(found).contains_exactly_in_any_order(["E_BAD_ENUM set", "E_UNKNOWN_FIELD art"])


func test_a_record_that_is_not_an_object_is_e_schema_with_no_record_id() -> void:
	# Act — cards_neutral.json records[4] is the string "not a record"
	var hits: Array = _for_file(_run("schema_types").report, "cards_neutral.json").filter(
		func(e: Dictionary) -> bool: return e.record_id == null and e.code == &"E_SCHEMA")

	# Assert
	assert_int(hits.size()).is_equal(1)
	assert_str(hits[0].message).contains("records[4]")


func test_a_record_without_an_id_names_its_index() -> void:
	# Act — cards_neutral.json records[5] has a name and a set, nothing else
	var hits: Array = _for_file(_run("schema_types").report, "cards_neutral.json").filter(
		func(e: Dictionary) -> bool: return e.record_id == null and e.field == "id")

	# Assert
	assert_int(hits.size()).is_equal(1)
	assert_str(String(hits[0].code)).is_equal("E_MISSING_FIELD")
	assert_str(hits[0].message).contains("records[5]")
