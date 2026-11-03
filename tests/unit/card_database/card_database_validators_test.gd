## Unit tests for CR-5 stage 7, the delegated validators, and the stage-7
## lookup exception (story card-database/story-004; card-database CR-5 step 7,
## States table, Edge Cases "Versions and files" and "Runtime"; ADR-0002
## Decision 4; ADR-0007 Decision 8).
##
## Every validator here is a `ValidatorStubs` stub injected explicitly —
## never `Boot` (control manifest). Fixtures: `clean/` (loads `Ready` with
## `ValidatorStubs.accept_all()`) and `delegated_effects/` (`clean/` plus the
## spell `neutral_bogus_bolt` whose second op is `bogus`, and a
## `card_effects.json` body `{max_ops_per_effect: 8}`). Read-only fixture
## roots through an injected `DataLoader` root, as in stories 001-003.
extends GdUnitTestSuite

const FIXTURES: String = "res://tests/fixtures/data/"
## The stage-7 guard's message (CardDatabase): what a debug assert reports.
const GUARD_MESSAGE: String = "CardDatabase.%s() is illegal before Ready (only lookups are open during stage 7)"


func _db(case_name: String) -> CardDatabase:
	return CardDatabase.new(DataLoader.new(FIXTURES + case_name))


func _delegated(report: ValidationReport) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in report.entries():
		if e.code == ValidationReport.E_DELEGATED:
			out.append(e)
	return out


# --- AC-1: the effects validator -------------------------------------------------

func test_rejecting_effects_stub_yields_e_delegated_with_its_code_and_the_card_id() -> void:
	# Arrange
	var map: Dictionary = ValidatorStubs.accept_all()
	map.effects = ValidatorStubs.rejecting_effects("bogus", "E_FX_OP")
	var db: CardDatabase = _db("delegated_effects")

	# Act
	db.load(map)

	# Assert
	var hits: Array[Dictionary] = _delegated(db.report())
	assert_int(hits.size()).is_equal(1)
	assert_str(hits[0].record_id).is_equal("neutral_bogus_bolt")
	assert_str(hits[0].file).is_equal("cards_neutral.json")
	assert_str(hits[0].field).is_equal("effects")
	assert_str(hits[0].message).starts_with("E_FX_OP: ")
	assert_str(String(hits[0].severity)).is_equal(String(ValidationReport.SEVERITY_ERROR))
	assert_int(db.state()).is_equal(CardDatabase.State.FAILED)


func test_effects_validator_is_called_with_the_five_stage_7b_arguments() -> void:
	# Arrange
	var calls: Dictionary = {}
	var map: Dictionary = ValidatorStubs.accept_all()
	map.effects = ValidatorStubs.recording(calls)
	var db: CardDatabase = _db("delegated_effects")

	# Act
	db.load(map)

	# Assert — (host_kind, host_id, effects, db, configs)
	var bolt: Array = calls.calls.filter(func(c: Dictionary) -> bool: return c.host_id == "neutral_bogus_bolt")
	assert_int(bolt.size()).is_equal(1)
	assert_str(String(bolt[0].host_kind)).is_equal("card")
	assert_array(bolt[0].value).is_equal([{"trigger": "cast", "ops": [{"op": "damage", "amount": 1.0}, {"op": "bogus"}]}])
	assert_object(bolt[0].db).is_same(db)
	assert_dict(bolt[0].configs.card_effects).is_equal({"max_ops_per_effect": 8.0})


func test_effects_validator_covers_cards_powers_treasures_and_boss_passives() -> void:
	# Arrange
	var calls: Dictionary = {}
	var map: Dictionary = ValidatorStubs.accept_all()
	map.effects = ValidatorStubs.recording(calls)

	# Act
	_db("clean").load(map)

	# Assert — one call per card (14), power (1), treasure (10) and boss with
	# a passive (1, boss_bone_king, its passive wrapped as a one-effect list)
	var kinds: Dictionary = {}
	for c: Dictionary in calls.calls:
		kinds[String(c.host_kind)] = kinds.get(String(c.host_kind), 0) + 1
	assert_dict(kinds).is_equal({"card": 14, "hero_power": 1, "treasure": 10, "boss": 1})
	var boss: Array = calls.calls.filter(func(c: Dictionary) -> bool: return c.host_kind == &"boss")
	assert_str(boss[0].host_id).is_equal("boss_bone_king")
	assert_int(boss[0].value.size()).is_equal(1)


func test_record_validators_run_in_id_order_effects_before_treasure() -> void:
	# Arrange — one shared log for the two treasure-facing validators
	var calls: Dictionary = {}
	var map: Dictionary = ValidatorStubs.accept_all()
	map.effects = ValidatorStubs.recording(calls)
	map.treasure = ValidatorStubs.recording(calls)

	# Act
	_db("clean").load(map)

	# Assert — for each treasure the effects call precedes the treasure call (T7)
	var order: Array = calls.calls.filter(func(c: Dictionary) -> bool: return c.host_kind == &"treasure").map(
		func(c: Dictionary) -> String: return "%s %s" % [c.host_id, "fx" if c.value is Array else "tr"])
	assert_str(order[0]).is_equal("treasure_living_armory fx")
	assert_str(order[1]).is_equal("treasure_living_armory tr")
	assert_str(order[2]).is_equal("treasure_t01 fx")


# --- AC-2: a missing record validator ----------------------------------------------

func test_missing_ai_profile_validator_is_e_delegated_naming_the_owner_and_fails() -> void:
	# Arrange — this build is a debug build; the rule is the same in release
	var map: Dictionary = ValidatorStubs.accept_all()
	map.erase("ai_profile")
	var db: CardDatabase = _db("clean")

	# Act
	db.load(map)

	# Assert
	var hits: Array[Dictionary] = _delegated(db.report())
	assert_int(hits.size()).is_equal(1)
	assert_str(hits[0].field).is_equal("ai_profile")
	assert_str(hits[0].file).is_equal("ai_profiles.json")
	assert_str(hits[0].message).contains("Boss AI")
	assert_int(db.state()).is_equal(CardDatabase.State.FAILED)


func test_full_stub_map_raises_no_e_delegated_and_loads_ready() -> void:
	# Act
	var db: CardDatabase = _db("clean")
	db.load(ValidatorStubs.accept_all())

	# Assert
	assert_array(db.report().entries()).is_empty()
	assert_int(db.state()).is_equal(CardDatabase.State.READY)


func test_an_empty_map_names_every_missing_record_and_config_validator() -> void:
	# Act
	var db: CardDatabase = _db("clean")
	db.load({})

	# Assert — four record keys plus twelve config files; card_database is not one
	var hits: Array[Dictionary] = _delegated(db.report())
	var record_fields: Array = hits.filter(func(e: Dictionary) -> bool: return e.field != null).map(
		func(e: Dictionary) -> String: return e.field)
	var config_files: Array = hits.filter(func(e: Dictionary) -> bool: return e.field == null).map(
		func(e: Dictionary) -> String: return e.file)
	assert_array(record_fields).contains_exactly_in_any_order(Array(ValidatorStubs.RECORD_KEYS))
	assert_array(config_files).contains_exactly_in_any_order(
		ValidatorStubs.config_names().map(func(n: String) -> String: return n + ".json"))
	assert_bool(config_files.has("card_database.json")).is_false()
	assert_int(db.state()).is_equal(CardDatabase.State.FAILED)


func test_a_missing_validator_does_not_stop_the_present_ones() -> void:
	# Arrange — no ai_profile, no configs.run_ui; effects records its calls
	var calls: Dictionary = {}
	var map: Dictionary = ValidatorStubs.accept_all()
	map.erase("ai_profile")
	map.configs.erase("run_ui")
	map.effects = ValidatorStubs.recording(calls)

	# Act
	_db("clean").load(map)

	# Assert — no short-circuit
	assert_int(calls.calls.size()).is_greater(0)


func test_a_non_callable_validator_is_e_delegated() -> void:
	var map: Dictionary = ValidatorStubs.accept_all()
	map.unlock = "MetaProgression.validate_unlock_defs"
	var db: CardDatabase = _db("clean")
	db.load(map)
	var hits: Array[Dictionary] = _delegated(db.report())
	assert_int(hits.size()).is_equal(1)
	assert_str(hits[0].field).is_equal("unlock")


# --- AC-3: config validators ---------------------------------------------------------

func test_missing_match_rules_config_validator_is_e_delegated_naming_the_file() -> void:
	# Arrange
	var map: Dictionary = ValidatorStubs.accept_all()
	map.configs.erase("match_rules")
	var db: CardDatabase = _db("clean")

	# Act
	db.load(map)

	# Assert
	var hits: Array[Dictionary] = _delegated(db.report())
	assert_int(hits.size()).is_equal(1)
	assert_str(hits[0].file).is_equal("match_rules.json")
	assert_str(hits[0].message).contains("Match Rules")
	assert_int(db.state()).is_equal(CardDatabase.State.FAILED)


func test_config_validator_error_is_merged_as_e_delegated_with_the_owner_code_and_file() -> void:
	# Arrange
	var map: Dictionary = ValidatorStubs.accept_all()
	map.configs.run_ui = ValidatorStubs.config_returning([{"code": "E_X", "host_id": null, "field": "toast_ms", "message": "bad"}])
	var db: CardDatabase = _db("clean")

	# Act
	db.load(map)

	# Assert
	var hits: Array[Dictionary] = _delegated(db.report())
	assert_int(hits.size()).is_equal(1)
	assert_str(hits[0].file).is_equal("run_ui.json")
	assert_str(hits[0].field).is_equal("toast_ms")
	assert_object(hits[0].record_id).is_null()
	assert_str(hits[0].message).is_equal("E_X: bad")
	assert_int(db.state()).is_equal(CardDatabase.State.FAILED)


func test_several_entries_from_one_validator_are_all_reported() -> void:
	var map: Dictionary = ValidatorStubs.accept_all()
	map.configs.match_ui = ValidatorStubs.config_returning([
		{"code": "E_A", "field": "a", "message": "one"},
		{"code": "E_B", "field": "b", "message": "two"},
		{"code": "E_C", "field": "c", "message": "three"},
	])
	var report: ValidationReport = DataLoader.new(FIXTURES + "clean").run(map)
	assert_int(_delegated(report).size()).is_equal(3)


func test_report_shaped_entries_from_rules_engine_merge_the_same_way() -> void:
	# RulesEngine.validate_rules_config returns full report-shaped entries
	# ({severity, code, file, record_id, field, message}); clean/'s
	# match_rules.json body is {} so every knob is missing.
	var map: Dictionary = ValidatorStubs.accept_all()
	map.configs.match_rules = RulesEngine.validate_rules_config
	var hits: Array[Dictionary] = _delegated(DataLoader.new(FIXTURES + "clean").run(map).report)
	assert_int(hits.size()).is_equal(RulesEngine.CONFIG_KEYS.size())
	assert_str(hits[0].file).is_equal("match_rules.json")
	assert_str(hits[0].message).starts_with("E_RULES_MISSING_KNOB: ")


func test_owner_warning_codes_merge_as_warnings_and_do_not_fail_the_load() -> void:
	var map: Dictionary = ValidatorStubs.accept_all()
	map.effects = ValidatorStubs.record_returning([{"code": "W_FX_UNREACHABLE", "message": "never fires"}])
	var db: CardDatabase = _db("clean")
	db.load(map)
	var hits: Array[Dictionary] = _delegated(db.report())
	assert_int(hits.size()).is_greater(0)
	for e: Dictionary in hits:
		assert_str(String(e.severity)).is_equal(String(ValidationReport.SEVERITY_WARNING))
	assert_int(db.state()).is_equal(CardDatabase.State.READY)


func test_a_validator_returning_a_non_array_is_e_delegated() -> void:
	var map: Dictionary = ValidatorStubs.accept_all()
	map.configs.heroes_balance = func(_body: Dictionary, _db_arg: Variant) -> Variant: return null
	var hits: Array[Dictionary] = _delegated(DataLoader.new(FIXTURES + "clean").run(map).report)
	assert_int(hits.size()).is_equal(1)
	assert_str(hits[0].file).is_equal("heroes_balance.json")
	assert_str(hits[0].message).contains("expected an Array")


func test_card_database_json_needs_no_validator() -> void:
	assert_bool(ValidatorStubs.accept_all().configs.has("card_database")).is_false()
	assert_int(ValidatorStubs.config_names().size()).is_equal(12)
	assert_array(DataLoader.CONFIG_VALIDATOR_EXEMPT).is_equal(["card_database.json"])


# --- AC-4: stage-7 lookups ---------------------------------------------------------------

func test_record_validator_lookups_answer_from_the_staged_records_and_load_reaches_ready() -> void:
	# Arrange — the unlock validator probes the database on its first call
	var calls: Dictionary = {}
	var probe: Callable = func(_k: StringName, _id: String, _v: Variant, db: CardDatabase, _c: Dictionary) -> Dictionary:
		return {
			"state": db.state(),
			"has_axe": db.has("war_iron_axe"),
			"has_ghost": db.has("war_ghost"),
			"axe_name": db.card("war_iron_axe").name,
			"pool": db.collectible_pool("war").map(func(r: Dictionary) -> String: return r.id),
			"power": db.hero_power("power_sharpen").cost,
			"band_2": db.bosses_in_band(2).map(func(r: Dictionary) -> String: return r.id),
		}
	var map: Dictionary = ValidatorStubs.accept_all()
	map.unlock = ValidatorStubs.recording(calls, probe)
	var db: CardDatabase = _db("clean")

	# Act
	db.load(map)

	# Assert
	var seen: Dictionary = calls.calls[0].probe
	assert_int(seen.state).is_equal(CardDatabase.State.LOADING)
	assert_bool(seen.has_axe).is_true()
	assert_bool(seen.has_ghost).is_false()
	assert_str(seen.axe_name).is_equal("War Iron Axe")
	assert_array(seen.pool).is_equal([
		"neutral_arcane_spark", "neutral_bog_lurker", "neutral_ember_hound", "neutral_torch_imp",
		"war_axe_thrower", "war_battle_cry", "war_iron_axe", "war_iron_vanguard",
		"war_plate_squire", "war_shield_bearer", "war_whetstone",
	])
	assert_int(int(seen.power)).is_equal(2)
	assert_array(seen.band_2).is_equal(["boss_bone_king"])
	assert_int(db.state()).is_equal(CardDatabase.State.READY)


func test_config_and_data_version_during_stage_7_return_empty_and_the_guard_fires() -> void:
	# Arrange
	var calls: Dictionary = {}
	var probe: Callable = func(_k: StringName, _id: String, _v: Variant, db: CardDatabase, _c: Dictionary) -> Dictionary:
		return {"config": db.config("match_rules"), "version": db.data_version()}
	var map: Dictionary = ValidatorStubs.accept_all()
	map.ai_profile = ValidatorStubs.recording(calls, probe)
	var db: CardDatabase = _db("clean")

	# Act / Assert — a debug assert (the guard), a push_error in release
	if OS.is_debug_build():
		await assert_error(func() -> void: db.load(map)).is_runtime_error("Assertion failed: " + GUARD_MESSAGE % "config")
	else:
		await assert_error(func() -> void: db.load(map)).is_push_error(GUARD_MESSAGE % "config")

	# Assert — the calls returned null / "" and the load still reached Ready
	var seen: Dictionary = calls.calls[0].probe
	assert_that(seen.config).is_null()
	assert_str(seen.version).is_empty()
	assert_int(db.state()).is_equal(CardDatabase.State.READY)


func test_lookups_are_closed_again_after_stage_7() -> void:
	# Arrange
	var db: CardDatabase = _db("clean")
	db.load(ValidatorStubs.accept_all())

	# Assert — Ready: the flag is down, config() answers, lookups still answer
	assert_bool(db._stage7_lookups_open).is_false()
	assert_that(db.config("card_database")).is_not_null()
	assert_bool(db.has("hero_war")).is_true()
