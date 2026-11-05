## Unit: `Treasures.validate_treasure_defs` and its stage-7b entry
## `Treasures.validate_treasure_record` (story treasures/story-003; treasures T1,
## T7, Edge Cases "Data and validation", AC-5; card-database CR-3, CR-5 stage 7;
## ADR-0005 Key Interfaces; ADR-0002 Decision 4).
##
## The checks are called directly, and through a real load of the committed root
## `tests/fixtures/data/treasures_invalid/`: `clean/` with the shipped
## `card_effects.json`, `match_rules.json` and `treasures_balance.json`, and one
## treasure per fault. Boot's map still holds the pending `treasure` validator on
## this branch, so the load map is built here (the orchestrator registers the
## adapter at M2).
extends GdUnitTestSuite

const ROOT: String = "res://tests/fixtures/data/treasures_invalid/"
const KNOB: String = "max_effects_per_treasure"
## The shipped `treasures_balance.json` value of [constant KNOB].
const BALANCE: Dictionary = {KNOB: 3}
const BOSS_CARD: String = "boss_grave_rat"
const WAR_CARD: String = "war_iron_axe"


## `treasures_invalid/` with its `treasures.json` body replaced by [member _treasures].
class RootOverlayLoader:
	extends DataLoader

	var _treasures: Array = []

	func _init(treasures: Array) -> void:
		super(ROOT)
		_treasures = treasures

	func _read_and_parse(report: ValidationReport) -> Array[Dictionary]:
		var staged: Array[Dictionary] = super(report)
		for item: Dictionary in staged:
			if item.row.name == "treasures.json":
				item.body = CardFactory.make_definition_file(_treasures)
		return staged


# --- helpers -------------------------------------------------------------------

func _effect() -> Dictionary:
	return {"trigger": "on_match_start", "targets": "owner", "ops": [{"op": "armor", "amount": 1}]}


func _effects(count: int) -> Array:
	var effects: Array = []
	for i: int in count:
		effects.append(_effect())
	return effects


## A record every check accepts, with [param overrides] applied.
func _def(overrides: Dictionary = {}) -> Dictionary:
	var def: Dictionary = {
		"id": "treasure_test", "name": "Test", "rarity": "common", "tags": ["universal"],
		"effects": [_effect()], "unlock": null,
		"text": {"key": "treasure.treasure_test.text", "en": "Text."},
	}
	def.merge(overrides, true)
	return def


## The same record with one effect whose ops are [param ops].
func _def_with_ops(ops: Array) -> Dictionary:
	return _def({"effects": [{"trigger": "on_match_start", "targets": "owner", "ops": ops}]})


func _summon(card_id: String) -> Dictionary:
	return {"op": "summon", "card_id": card_id, "count": 1, "position": "end"}


func _codes(rows: Array) -> Array:
	return rows.map(func(row: Dictionary) -> String: return String(row.code))


func _validate(def: Dictionary, db: Variant = null, balance: Dictionary = BALANCE) -> Array:
	return _codes(Treasures.validate_treasure_defs([def], db, balance))


## The map of a real treasure load: the effects and treasure validators are real,
## everything else accepts.
func _validators() -> Dictionary:
	var map: Dictionary = ValidatorStubs.accept_all()
	map.effects = func(kind: StringName, id: String, effects: Variant, db: Variant, bodies: Dictionary) -> Array:
		return EffectValidator.validate_effects(kind, id, effects, db, EffectValidator.stage7_caps(bodies))
	map.treasure = Treasures.validate_treasure_record
	return map


func _load_root() -> CardDatabase:
	var db: CardDatabase = CardDatabase.new(DataLoader.new(ROOT))
	db.load(_validators())
	return db


## The owner codes of [param id]'s entries: a delegated entry's code leads its
## message (`DataLoader._merge_delegated`), a schema entry's is its own.
func _record_codes(report: ValidationReport, id: String) -> Array:
	var codes: Array = []
	for entry: Dictionary in report.entries():
		if entry.record_id == id:
			var delegated: bool = entry.code == ValidationReport.E_DELEGATED
			codes.append(String(entry.message).get_slice(":", 0) if delegated else String(entry.code))
	return codes


# --- AC-5 ----------------------------------------------------------------------

func test_ac5_bad_trigger_boss_token_and_two_affinities_each_report_their_code_and_the_load_fails() -> void:
	# Act
	var db: CardDatabase = _load_root()

	# Assert
	assert_int(db.state()).is_equal(CardDatabase.State.FAILED)
	assert_array(_record_codes(db.report(), "treasure_bad_trigger")).contains_exactly(["E_FX_TRIGGER"])
	assert_array(_record_codes(db.report(), "treasure_boss_token")).contains_exactly(["E_TR_TOKEN_REF"])
	assert_array(_record_codes(db.report(), "treasure_two_affinities")).contains_exactly(["E_TR_TAGS"])
	assert_array(_record_codes(db.report(), "treasure_valid")).is_empty()


func test_ac5_legendary_rarity_is_e_tr_rarity_from_the_validator() -> void:
	# Act
	var codes: Array = _validate(_def({"rarity": "legendary"}))

	# Assert
	assert_array(codes).contains_exactly(["E_TR_RARITY"])


func test_common_and_rare_are_accepted() -> void:
	assert_array(_validate(_def({"rarity": "common"}))).is_empty()
	assert_array(_validate(_def({"rarity": "rare"}))).is_empty()


## AC-5 (d) as DD-X30 reworded it: stage 4 stays the gate for `rarity`, so it
## drops the record and stage 7b never sees it.
func test_legendary_in_a_load_stops_at_the_stage_4_enum_before_the_validator() -> void:
	# Act
	var db: CardDatabase = _load_root()

	# Assert
	assert_int(db.state()).is_equal(CardDatabase.State.FAILED)
	assert_array(_record_codes(db.report(), "treasure_legendary")).contains_exactly(["E_BAD_ENUM"])


func test_dd_x25_shield_aura_is_e_fx_op_and_never_an_e_tr_code() -> void:
	# Act
	var db: CardDatabase = _load_root()

	# Assert
	assert_array(_record_codes(db.report(), "treasure_shield_aura")).contains_exactly(["E_FX_OP"])


# --- AC-T7a: effect count ------------------------------------------------------

func test_empty_effects_is_e_tr_effect_count() -> void:
	assert_array(_validate(_def({"effects": []}))).contains_exactly(["E_TR_EFFECT_COUNT"])


func test_four_effects_over_the_cap_is_e_tr_effect_count() -> void:
	assert_array(_validate(_def({"effects": _effects(4)}))).contains_exactly(["E_TR_EFFECT_COUNT"])


func test_exactly_the_cap_is_accepted() -> void:
	assert_array(_validate(_def({"effects": _effects(3)}))).is_empty()


func test_the_cap_is_read_from_the_balance_body() -> void:
	# Arrange
	var four: Dictionary = _def({"effects": _effects(4)})
	var three: Dictionary = _def({"effects": _effects(3)})

	# Act / Assert — the same records against other knob values
	assert_array(_validate(four, null, {KNOB: 4})).is_empty()
	assert_array(_validate(three, null, {KNOB: 2})).contains_exactly(["E_TR_EFFECT_COUNT"])


func test_a_json_float_cap_is_read_as_the_whole_number() -> void:
	assert_array(_validate(_def({"effects": _effects(3)}), null, {KNOB: 3.0})).is_empty()
	assert_array(_validate(_def({"effects": _effects(4)}), null, {KNOB: 3.0})).contains_exactly(["E_TR_EFFECT_COUNT"])


func test_effect_count_faults_fail_a_real_load_against_the_file_knob() -> void:
	# Act
	var db: CardDatabase = _load_root()

	# Assert
	assert_array(_record_codes(db.report(), "treasure_no_effects")).contains_exactly(["E_TR_EFFECT_COUNT"])
	assert_array(_record_codes(db.report(), "treasure_four_effects")).contains_exactly(["E_TR_EFFECT_COUNT"])


# --- AC-T7a: tags --------------------------------------------------------------

func test_an_unknown_tag_is_e_tr_tags() -> void:
	assert_array(_validate(_def({"tags": ["universal", "frobnicate"]}))).contains_exactly(["E_TR_TAGS"])


func test_plan_tags_with_no_affinity_are_e_tr_tags() -> void:
	assert_array(_validate(_def({"tags": ["weapons", "aggro"]}))).contains_exactly(["E_TR_TAGS"])


func test_no_tags_at_all_is_e_tr_tags() -> void:
	assert_array(_validate(_def({"tags": []}))).contains_exactly(["E_TR_TAGS"])


func test_two_affinities_are_e_tr_tags() -> void:
	assert_array(_validate(_def({"tags": ["war", "decay"]}))).contains_exactly(["E_TR_TAGS"])


func test_a_repeated_affinity_counts_as_two() -> void:
	assert_array(_validate(_def({"tags": ["war", "war"]}))).contains_exactly(["E_TR_TAGS"])


func test_three_more_tags_are_accepted_and_a_fourth_is_e_tr_tags() -> void:
	# Arrange
	var three: Array = ["war", "weapons", "aggro", "tempo"]
	var four: Array = ["war", "weapons", "aggro", "tempo", "value"]

	# Act / Assert
	assert_array(_validate(_def({"tags": three}))).is_empty()
	assert_array(_validate(_def({"tags": four}))).contains_exactly(["E_TR_TAGS"])


func test_every_t1_tag_is_known() -> void:
	# Arrange — T1's lists, spelled out here so a dropped word fails
	var affinities: Array = ["war", "decay", "knowledge", "universal"]
	var others: Array = ["weapons", "aggro", "armour", "deathrattle", "sacrifice", "husk", "spells",
		"spell_damage", "draw", "economy", "tempo", "value", "defensive", "wild"]

	# Act / Assert
	for affinity: String in affinities:
		assert_array(_validate(_def({"tags": [affinity]}))).override_failure_message(affinity).is_empty()
	for tag: String in others:
		assert_array(_validate(_def({"tags": ["universal", tag]}))).override_failure_message(tag).is_empty()


func test_tag_faults_fail_a_real_load() -> void:
	# Act
	var db: CardDatabase = _load_root()

	# Assert
	assert_array(_record_codes(db.report(), "treasure_unknown_tag")).contains_exactly(["E_TR_TAGS"])
	assert_array(_record_codes(db.report(), "treasure_no_affinity")).contains_exactly(["E_TR_TAGS"])


func test_the_20_record_fixture_has_no_e_tr_entry() -> void:
	# Arrange
	var db: CardDatabase = TreasureFixtures.database()

	# Act
	var rows: Array = Treasures.validate_treasure_defs(TreasureFixtures.records(), db, BALANCE)

	# Assert
	assert_array(rows).is_empty()


# --- E_TR_TOKEN_REF ------------------------------------------------------------

func test_each_card_op_on_a_boss_card_is_e_tr_token_ref() -> void:
	# Arrange
	var db: CardDatabase = TreasureFixtures.database()

	# Act / Assert
	for op_name: String in ["summon", "add_to_hand", "equip"]:
		var def: Dictionary = _def_with_ops([{"op": op_name, "card_id": BOSS_CARD}])
		assert_array(_validate(def, db)).override_failure_message(op_name).contains_exactly(["E_TR_TOKEN_REF"])


func test_a_card_op_on_a_card_outside_the_boss_set_is_accepted() -> void:
	# Arrange
	var db: CardDatabase = TreasureFixtures.database()

	# Act / Assert
	assert_array(_validate(_def_with_ops([_summon(WAR_CARD)]), db)).is_empty()


func test_another_op_with_a_boss_card_id_is_not_a_token_ref() -> void:
	# Arrange — T7 names summon, add_to_hand and equip only
	var db: CardDatabase = TreasureFixtures.database()

	# Act / Assert
	assert_array(_validate(_def_with_ops([{"op": "transform", "card_id": BOSS_CARD}]), db)).is_empty()


func test_a_boss_token_in_either_conditional_branch_is_found() -> void:
	# Arrange
	var db: CardDatabase = TreasureFixtures.database()
	var in_then: Dictionary = _def_with_ops([{"op": "conditional", "if": {}, "then": [_summon(BOSS_CARD)], "else": []}])
	var in_else: Dictionary = _def_with_ops([{"op": "conditional", "if": {}, "then": [], "else": [_summon(BOSS_CARD)]}])

	# Act / Assert
	assert_array(_validate(in_then, db)).contains_exactly(["E_TR_TOKEN_REF"])
	assert_array(_validate(in_else, db)).contains_exactly(["E_TR_TOKEN_REF"])


func test_a_boss_token_under_repeat_choose_one_or_nested_conditionals_is_found() -> void:
	# Arrange
	var db: CardDatabase = TreasureFixtures.database()
	var nested: Dictionary = {"op": "conditional", "if": {}, "then": [
		{"op": "conditional", "if": {}, "then": [], "else": [_summon(BOSS_CARD)]}], "else": []}
	var repeated: Dictionary = {"op": "repeat", "times": 2, "ops": [_summon(BOSS_CARD)]}
	var option: Dictionary = {"op": "choose_one", "options": [
		{"label_key": "a", "ops": [_summon(WAR_CARD)]}, {"label_key": "b", "ops": [_summon(BOSS_CARD)]}]}

	# Act / Assert
	for op: Dictionary in [nested, repeated, option]:
		assert_array(_validate(_def_with_ops([op]), db)).override_failure_message(str(op)).contains_exactly(["E_TR_TOKEN_REF"])


func test_a_token_ref_names_the_op_path() -> void:
	# Arrange
	var db: CardDatabase = TreasureFixtures.database()
	var def: Dictionary = _def_with_ops([{"op": "armor", "amount": 1},
		{"op": "conditional", "if": {}, "then": [], "else": [_summon(BOSS_CARD)]}])

	# Act
	var rows: Array = Treasures.validate_treasure_defs([def], db, BALANCE)

	# Assert
	assert_str(rows[0].message).contains("effects/0/ops/1/else/0/card_id")
	assert_str(rows[0].message).contains(BOSS_CARD)


func test_living_armorys_pool_add_to_hand_has_no_card_id_and_is_not_checked() -> void:
	# Arrange
	var db: CardDatabase = TreasureFixtures.database()
	var pool: Dictionary = {"op": "add_to_hand", "from": {"pool": "collectible"}, "count": 1}

	# Act / Assert
	assert_array(_validate(_def_with_ops([pool]), db)).is_empty()


func test_an_unknown_card_id_is_left_to_e_fx_ref() -> void:
	# Arrange
	var db: CardDatabase = TreasureFixtures.database()

	# Act / Assert — no E_FX_* code here, and no lookup that would log
	assert_array(_validate(_def_with_ops([_summon("nope")]), db)).is_empty()


func test_a_loader_run_with_no_database_is_left_to_e_fx_ref() -> void:
	# `DataLoader.run(validators)` passes `db = null`; `EffectValidator` reports
	# every `card_id` then, so nothing is passed unseen
	assert_array(_validate(_def_with_ops([_summon(BOSS_CARD)]), null)).is_empty()


# --- AC-T7b --------------------------------------------------------------------

func test_text_without_en_is_w_tr_text() -> void:
	# Act
	var rows: Array = Treasures.validate_treasure_defs([_def({"text": {"key": "treasure.treasure_test.text"}})], null, BALANCE)

	# Assert
	assert_array(_codes(rows)).contains_exactly(["W_TR_TEXT"])
	assert_bool(String(rows[0].code).begins_with("W_")).is_true()


func test_an_empty_en_is_present() -> void:
	assert_array(_validate(_def({"text": {"key": "treasure.treasure_test.text", "en": ""}}))).is_empty()


## AC-T7b as DD-X30 reworded it: stage 4 stays the gate for `text.en`, so a load
## fails before W_TR_TEXT can run.
func test_no_en_in_a_load_stops_at_stage_4_before_the_validator() -> void:
	# Act
	var db: CardDatabase = _load_root()

	# Assert
	assert_array(_record_codes(db.report(), "treasure_no_en")).contains_exactly(["E_MISSING_FIELD"])


# --- W_TR_POWER ----------------------------------------------------------------

func test_w_tr_power_is_not_checked_by_this_story() -> void:
	# Arrange — AC-29's Hollow Crown as common, out of band: story 013 is Blocked
	var crown: Dictionary = TreasureFixtures.records()[0]
	crown.rarity = "common"

	# Act / Assert
	assert_array(_validate(crown)).is_empty()


# --- Entry shape and the stage-7b entry ----------------------------------------

func test_entries_use_the_7b_shape_and_name_the_host() -> void:
	# Act
	var rows: Array = Treasures.validate_treasure_defs([_def({"rarity": "legendary", "tags": []})], null, BALANCE)

	# Assert
	assert_int(rows.size()).is_equal(2)
	for row: Dictionary in rows:
		assert_array(row.keys()).contains_exactly_in_any_order(["code", "host_id", "field", "message"])
		assert_str(row.host_id).is_equal("treasure_test")
	assert_str(rows[0].field).is_equal("rarity")
	assert_str(rows[1].field).is_equal("tags")


func test_every_def_in_the_array_is_checked() -> void:
	# Arrange
	var defs: Array = [_def({"id": "treasure_a", "rarity": "legendary"}), _def({"id": "treasure_b"}), _def({"id": "treasure_c", "tags": []})]

	# Act
	var rows: Array = Treasures.validate_treasure_defs(defs, null, BALANCE)

	# Assert
	assert_array(rows.map(func(row: Dictionary) -> String: return row.host_id)).contains_exactly(["treasure_a", "treasure_c"])


func test_the_record_entry_reads_the_balance_body_from_the_stage_7b_bodies() -> void:
	# Arrange
	var def: Dictionary = _def({"effects": _effects(4)})

	# Act
	var over: Array = Treasures.validate_treasure_record(&"treasure", def.id, def, null, {"treasures_balance": BALANCE})
	var raised: Array = Treasures.validate_treasure_record(&"treasure", def.id, def, null, {"treasures_balance": {KNOB: 4}})

	# Assert
	assert_array(_codes(over)).contains_exactly(["E_TR_EFFECT_COUNT"])
	assert_array(raised).is_empty()


func test_an_absent_balance_body_is_one_explicit_e_delegated_entry() -> void:
	# Arrange — the bodies as stage 7b passes them when the body failed 7a
	var def: Dictionary = _def()

	# Act
	var rows: Array = Treasures.validate_treasure_record(&"treasure", def.id, def, null, {"match_rules": {}})

	# Assert
	assert_array(_codes(rows)).contains_exactly(["E_DELEGATED"])
	assert_str(rows[0].host_id).is_equal(def.id)
	assert_str(rows[0].field).is_equal("effects")
	assert_str(rows[0].message).contains("not checked")


func test_a_body_without_the_knob_or_with_a_bad_one_is_the_same_entry() -> void:
	# Act / Assert — never a check against an empty or unreadable cap
	for balance: Dictionary in [{}, {KNOB: "3"}, {KNOB: 2.5}, {KNOB: null}]:
		assert_array(_validate(_def(), null, balance)).override_failure_message(str(balance)).contains_exactly(["E_DELEGATED"])


func test_the_checks_that_need_no_cap_still_run_without_one() -> void:
	# Act / Assert
	assert_array(_validate(_def({"rarity": "legendary"}), null, {})).contains_exactly_in_any_order(["E_TR_RARITY", "E_DELEGATED"])
	assert_array(_validate(_def({"effects": []}), null, {})).contains_exactly(["E_TR_EFFECT_COUNT"])


func test_a_load_whose_balance_file_lacks_the_knob_fails_with_one_entry_per_host() -> void:
	# Arrange — `clean/`'s `treasures_balance.json` is the empty body
	var db: CardDatabase = CardDatabase.new(TreasureFixtures.TreasureOverlayLoader.new([_def({"id": "treasure_a"}), _def({"id": "treasure_b"})]))
	var map: Dictionary = ValidatorStubs.accept_all()
	map.treasure = Treasures.validate_treasure_record

	# Act
	db.load(map)

	# Assert
	assert_int(db.state()).is_equal(CardDatabase.State.FAILED)
	assert_array(_record_codes(db.report(), "treasure_a")).contains_exactly(["E_DELEGATED"])
	assert_array(_record_codes(db.report(), "treasure_b")).contains_exactly(["E_DELEGATED"])


func test_a_load_of_one_valid_treasure_is_ready_with_nothing_on_the_record() -> void:
	# Arrange
	var def: Dictionary = _def({"id": "treasure_valid", "text": {"key": "treasure.treasure_valid.text", "en": "Text."}})
	var db: CardDatabase = CardDatabase.new(RootOverlayLoader.new([def]))

	# Act
	db.load(_validators())

	# Assert
	assert_array(db.report().errors()).override_failure_message(db.report().to_text()).is_empty()
	assert_int(db.state()).is_equal(CardDatabase.State.READY)
	assert_array(_record_codes(db.report(), "treasure_valid")).is_empty()
