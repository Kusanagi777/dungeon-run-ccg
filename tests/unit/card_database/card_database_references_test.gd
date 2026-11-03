## Unit tests for CR-5 stages 5-6, id uniqueness and cross-references, and the
## id-sorted staging stage 7 reads (story card-database/story-003;
## card-database CR-2, CR-3, CR-5 steps 5-6, Edge Cases "Identity and
## references" and "Pools and lists"; ADR-0002 Decision 3).
##
## File I/O note: committed, read-only fixture roots through an injected
## `DataLoader` root, as in story 001/002. Every `dup_id/` and `refs_*/` root
## is `clean/` (which loads with an empty report) plus the faults its test
## names; the clean root itself carries a 15-card starter deck with repeated
## ids and a boss deck holding a War weapon, both of which must stay clean.
extends GdUnitTestSuite

const FIXTURES: String = "res://tests/fixtures/data/"
const RECORD_TYPES: Array[String] = ["CardDef", "HeroDef", "HeroPowerDef", "BossDef", "TreasureDef", "BundleDef"]


func _run(case_name: String) -> DataLoader.LoadResult:
	return DataLoader.new(FIXTURES + case_name).run(ValidatorStubs.accept_all())


func _with(report: ValidationReport, code: StringName, record_id: Variant = null) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in report.entries():
		if e.code == code and (record_id == null or e.record_id == record_id):
			out.append(e)
	return out


## The entries for `record_id` with `code` whose field is `field`.
func _hits(report: ValidationReport, code: StringName, record_id: String, field: String) -> Array:
	return _with(report, code, record_id).filter(func(e: Dictionary) -> bool: return e.field == field)


# --- AC-1: E_DUP_ID ----------------------------------------------------------------

func test_id_duplicated_into_a_second_set_file_is_one_e_dup_id_naming_both_files() -> void:
	# Act — war_iron_axe in cards_war.json [4] and cards_neutral.json [4]
	var result: DataLoader.LoadResult = _run("dup_id")

	# Assert
	var dups: Array[Dictionary] = _with(result.report, ValidationReport.E_DUP_ID, "war_iron_axe")
	assert_int(dups.size()).is_equal(1)
	assert_str(dups[0].file).is_equal("cards_war.json")
	assert_str(dups[0].field).is_equal("id")
	assert_str(dups[0].message).contains("cards_war.json records[4]")
	assert_str(dups[0].message).contains("cards_neutral.json records[4]")


func test_id_duplicated_inside_one_file_is_e_dup_id_with_both_indexes() -> void:
	var dups: Array[Dictionary] = _with(_run("dup_id").report, ValidationReport.E_DUP_ID, "neutral_torch_imp")
	assert_int(dups.size()).is_equal(1)
	assert_str(dups[0].message).contains("cards_neutral.json records[0]")
	assert_str(dups[0].message).contains("cards_neutral.json records[5]")


func test_boss_set_card_and_boss_def_sharing_an_id_is_e_dup_id() -> void:
	# CR-2: one namespace — `boss_<name>` for a boss-set card and for a BossDef.
	var dups: Array[Dictionary] = _with(_run("dup_id").report, ValidationReport.E_DUP_ID, "boss_rot_warden")
	assert_int(dups.size()).is_equal(1)
	assert_str(dups[0].message).contains("cards_boss.json")
	assert_str(dups[0].message).contains("bosses.json")


func test_duplicated_ids_fail_the_load_and_no_copy_is_staged() -> void:
	# Act
	var db: CardDatabase = CardDatabase.new(DataLoader.new(FIXTURES + "dup_id"))
	db.load(ValidatorStubs.accept_all())
	var result: DataLoader.LoadResult = _run("dup_id")

	# Assert — no "last one wins"
	assert_int(db.state()).is_equal(CardDatabase.State.FAILED)
	assert_that(result.snapshot).is_null()
	for id: String in ["war_iron_axe", "neutral_torch_imp", "boss_rot_warden"]:
		assert_bool(result.staging.index_of.has(id)).override_failure_message(id).is_false()


func test_reference_to_a_duplicated_id_is_reported_as_unknown() -> void:
	# The bundle and the boss deck reference war_iron_axe; neither copy stands.
	var report: ValidationReport = _run("dup_id").report
	assert_int(_hits(report, ValidationReport.E_UNKNOWN_REF, "bundle_war_weapons", "cards").size()).is_equal(1)


# --- AC-2: E_COUNT and E_UNKNOWN_REF -------------------------------------------------

func test_starter_deck_of_14_is_e_count_found_14_expected_15() -> void:
	var hits: Array = _hits(_run("refs_counts").report, ValidationReport.E_COUNT, "hero_war", "starter_deck")
	assert_int(hits.size()).is_equal(1)
	assert_str(hits[0].message).contains("found 14")
	assert_str(hits[0].message).contains("expected %d" % TestConstants.STARTER_DECK_SIZE)


func test_starter_deck_of_16_is_e_count_found_16() -> void:
	var hits: Array = _hits(_run("refs_counts").report, ValidationReport.E_COUNT, "hero_war_long", "starter_deck")
	assert_int(hits.size()).is_equal(1)
	assert_str(hits[0].message).contains("found 16")


func test_bundle_of_2_and_bundle_of_4_are_e_count_against_3() -> void:
	# Act
	var report: ValidationReport = _run("refs_counts").report

	# Assert
	var two: Array = _hits(report, ValidationReport.E_COUNT, "bundle_war_weapons", "cards")
	var four: Array = _hits(report, ValidationReport.E_COUNT, "bundle_war_quad", "cards")
	assert_int(two.size()).is_equal(1)
	assert_int(four.size()).is_equal(1)
	assert_str(two[0].message).contains("found 2")
	assert_str(four[0].message).contains("found 4")
	assert_str(two[0].message).contains("expected %d" % TestConstants.BUNDLE_CARD_COUNT)


func test_list_counts_come_from_the_cr3_schema_table() -> void:
	# DD-R03 / DD-R04 are CR-3 shape rules, held in the field table.
	assert_int(int(RecordSchemas.HERO_FIELDS.starter_deck["count"])).is_equal(TestConstants.STARTER_DECK_SIZE)
	assert_int(int(RecordSchemas.BUNDLE_FIELDS.cards["count"])).is_equal(TestConstants.BUNDLE_CARD_COUNT)


func test_starter_deck_with_repeated_ids_and_boss_deck_with_a_war_weapon_are_clean() -> void:
	# Act — clean/: hero_war holds seven ids twice (15 entries); boss_rot_warden's
	# deck holds war_iron_axe (any set is allowed in a boss deck)
	var result: DataLoader.LoadResult = _run("clean")

	# Assert
	assert_array(result.report.entries()).is_empty()


func test_unknown_ids_name_record_field_index_and_missing_id() -> void:
	# Act
	var report: ValidationReport = _run("refs_unknown").report

	# Assert — one per list kind
	var cases: Array = [
		["hero_war", "starter_deck", "starter_deck[3]", "war_ghost_card"],
		["bundle_war_weapons", "cards", "cards[1]", "war_ghost_blade"],
		["boss_rot_warden", "deck", "deck[0]", "boss_ghost_shard"],
		["boss_rot_warden", "hero_power", "hero_power", "power_ghost"],
	]
	for c: Array in cases:
		var hits: Array = _hits(report, ValidationReport.E_UNKNOWN_REF, c[0], c[1])
		assert_int(hits.size()).override_failure_message(str(c)).is_equal(1)
		if hits.size() == 1:
			assert_str(hits[0].message).contains(c[2])
			assert_str(hits[0].message).contains(c[3])


func test_hero_power_naming_a_card_is_e_unknown_ref() -> void:
	var hits: Array = _hits(_run("refs_unknown").report, ValidationReport.E_UNKNOWN_REF, "hero_war_alt", "hero_power")
	assert_int(hits.size()).is_equal(1)
	assert_str(hits[0].message).contains("HeroPowerDef")


# --- AC-3: E_TAG_MISMATCH and E_SET_MISMATCH ------------------------------------------

func test_bundle_card_lacking_the_theme_tag_names_bundle_card_and_tag() -> void:
	var hits: Array = _hits(_run("refs_sets_tags").report, ValidationReport.E_TAG_MISMATCH, "bundle_war_weapons", "cards")
	assert_int(hits.size()).is_equal(1)
	assert_str(hits[0].message).contains("war_shield_bearer")
	assert_str(hits[0].message).contains("weapons")
	assert_str(hits[0].file).is_equal("bundles.json")


func test_bundle_card_from_another_set_is_e_set_mismatch_naming_the_card() -> void:
	var hits: Array = _hits(_run("refs_sets_tags").report, ValidationReport.E_SET_MISMATCH, "bundle_neutral_fire", "cards")
	assert_int(hits.size()).is_equal(1)
	assert_str(hits[0].message).contains("war_fire_brand")


func test_starter_card_from_neither_hero_set_nor_neutral_is_e_set_mismatch() -> void:
	var hits: Array = _hits(_run("refs_sets_tags").report, ValidationReport.E_SET_MISMATCH, "hero_war", "starter_deck")
	assert_int(hits.size()).is_equal(1)
	assert_str(hits[0].message).contains("boss_bone_shard")


# --- AC-4: tokens, boss decks, hero set files ------------------------------------------

func test_token_in_boss_deck_starter_deck_and_bundle_is_e_token_in_list() -> void:
	# Act
	var report: ValidationReport = _run("refs_tokens").report

	# Assert
	var cases: Array = [
		["boss_rot_warden", "deck", "deck[2]", "war_recruit"],
		["hero_war", "starter_deck", "starter_deck[14]", "war_recruit"],
		["bundle_war_weapons", "cards", "cards[2]", "war_axe_token"],
	]
	for c: Array in cases:
		var hits: Array = _hits(report, ValidationReport.E_TOKEN_IN_LIST, c[0], c[1])
		assert_int(hits.size()).override_failure_message(str(c)).is_equal(1)
		if hits.size() == 1:
			assert_str(hits[0].message).contains(c[2])
			assert_str(hits[0].message).contains(c[3])


func test_hero_set_with_no_set_file_is_e_missing_file_naming_hero_and_file() -> void:
	# Act
	var hits: Array[Dictionary] = _with(_run("refs_missing_set_file").report, ValidationReport.E_MISSING_FILE, "hero_decay")

	# Assert
	assert_int(hits.size()).is_equal(1)
	assert_str(hits[0].file).is_equal("cards_decay.json")
	assert_str(hits[0].field).is_equal("set")


# --- staging: id-sorted lists and index_of (stage 7's lookup source) -------------------

func test_staging_lists_every_clean_record_sorted_by_id_per_type() -> void:
	# Act
	var staging: Dictionary = _run("clean").staging

	# Assert
	assert_array(staging.records.keys()).contains_exactly_in_any_order(RECORD_TYPES)
	var total: int = 0
	for record_type: String in RECORD_TYPES:
		var ids: Array = staging.records[record_type].map(func(r: Dictionary) -> String: return r.id)
		GameAssertions.assert_sorted_ascending(ids, record_type)
		total += ids.size()
	assert_int(staging.records.CardDef.size()).is_equal(14)
	assert_int(staging.index_of.size()).is_equal(total)


func test_staging_index_of_points_at_the_record_in_its_type_list() -> void:
	# Act
	var staging: Dictionary = _run("clean").staging

	# Assert
	for id: String in staging.index_of:
		var at: Dictionary = staging.index_of[id]
		assert_str(staging.records[at.type][at.position].id).is_equal(id)
		assert_str(staging.files[id]).is_not_empty()
	assert_str(staging.index_of.boss_rot_warden.type).is_equal("BossDef")


func test_staging_does_not_depend_on_file_order() -> void:
	# clean/ authors cards_war.json out of id order (shield_bearer before axe_thrower).
	var ids: Array = _run("clean").staging.records.CardDef.map(func(r: Dictionary) -> String: return r.id)
	assert_int(ids.find("war_axe_thrower")).is_less(ids.find("war_shield_bearer"))


func test_records_failing_stage_4_or_6_are_not_staged() -> void:
	# stage 4: schema_cards' war_typo_field; stage 6: refs_counts' hero_war
	assert_bool(_run("schema_cards").staging.index_of.has("war_typo_field")).is_false()
	assert_bool(_run("schema_cards").staging.index_of.has("war_float_ok")).is_true()
	assert_bool(_run("refs_counts").staging.index_of.has("hero_war")).is_false()
	assert_bool(_run("refs_counts").staging.index_of.has("bundle_war_armor")).is_true()
