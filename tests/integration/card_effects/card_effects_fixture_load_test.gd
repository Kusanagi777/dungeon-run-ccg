## card-effects story 005 — the C11 fixture set and the real `EffectValidator`
## injected into Card Database stage 7b (design/gdd/card-effects.md C10, C11,
## Acceptance Criteria preamble; AC-01; ADR-0002 Decision 4; ADR-0007
## Decision 8; control manifest Core "tests inject the five-parameter
## accept-all stub").
##
## Composes `DataLoader` + `CardDatabase` + the real validator without booting:
## the full-fixture AC-01 case loads through Boot's own stage-7b `effects`
## adapter and 7a effect / rules validators, taken from the map
## `Boot._collect_validators` builds (`ContentValidateCommand.boot_validators`
## — code review 2026-11-04: a test-built adapter
## could not catch Boot's adapter regressing to `caps = bodies["card_effects"]`);
## the other cases build the stage-7b adapter here as
## `validate_effects(k, id, fx, db, EffectValidator.stage7_caps(configs))`. Fixtures (read only
## through the loader, or as the imported JSON resource — never `FileAccess`):
## - `tests/fixtures/cards_effects_test.json` — the flat list: one host per C11
##   row 1–46 (ids `<prefix>fx_row_NN_…`) plus the four tokens they name;
## - `tests/fixtures/data/card_effects_v1/` — a full DD-T01 folder holding
##   exactly those records, `CardFactory.make_fixture_card_set()`, one hero,
##   one boss card, and the shipped `card_effects.json` / `match_rules.json`;
## - `tests/fixtures/data/card_effects_bad_ref/` — a DD-T01 folder whose one
##   card `neutral_fx_bad_ref` carries `summon` with `card_id: "nope"`.
extends GdUnitTestSuite

const FIXTURES: String = "res://tests/fixtures/data/"
const V1: String = "card_effects_v1"
const BAD_REF: String = "card_effects_bad_ref"
const FLAT: String = "res://tests/fixtures/cards_effects_test.json"
const BAD_CARD: String = "neutral_fx_bad_ref"
## C11 rows 1–46 (card-effects C11 coverage table).
const C11_ROWS: int = 46
## How a fixture id names its C11 row: `war_fx_row_01_weapon_buff` → 1.
const ROW_PATTERN: String = "fx_row_(\\d\\d)_"


# --- helpers -------------------------------------------------------------------

func _database(case_name: String, debug_build: bool = OS.is_debug_build()) -> CardDatabase:
	return CardDatabase.new(DataLoader.new(FIXTURES + case_name), debug_build)


## The flat fixture list (imported JSON resource).
func _flat() -> Array:
	var resource: JSON = load(FLAT)
	return resource.data


## The stage-7b `effects` adapter over the real validator (ADR-0002 D4 call
## shape), recording each host's report into [param seen] (`host_id → Array`).
func _real_effects(seen: Dictionary) -> Callable:
	return func(kind: StringName, id: String, fx: Variant, db: Variant, configs: Dictionary) -> Array:
		var report: Array = EffectValidator.validate_effects(kind, id, fx, db, EffectValidator.stage7_caps(configs))
		seen[id] = report
		return report


## Stubs everywhere except `effects` (the real adapter) and the two config
## bodies the adapter's caps come from (their real stage-7a validators).
func _map(seen: Dictionary) -> Dictionary:
	var map: Dictionary = ValidatorStubs.accept_all()
	map.effects = _real_effects(seen)
	map.configs.card_effects = EffectValidator.validate_config
	map.configs.match_rules = RulesEngine.validate_rules_config
	return map


## [method _map] with Boot's own entries where this fixture exercises them:
## the stage-7b `effects` adapter (`Boot._effects_adapter`, wrapped only to
## record each host's report into [param seen], `host_id → Array`) and the
## `card_effects` / `match_rules` stage-7a validators, all taken from the map
## `Boot._collect_validators` builds (`ContentValidateCommand.boot_validators`).
## The folder's other config bodies are placeholders this fixture does not
## exercise, so their entries stay stubbed.
func _boot_map(seen: Dictionary) -> Dictionary:
	var boot_map: Dictionary = ContentValidateCommand.boot_validators(true)
	var map: Dictionary = _map(seen)
	for config_name: String in ["card_effects", "match_rules"]:
		map.configs[config_name] = boot_map.configs[config_name]
	var boot_effects: Callable = boot_map.effects
	map.effects = func(kind: StringName, id: String, fx: Variant, db: Variant, bodies: Dictionary) -> Array:
		var report: Array = boot_effects.call(kind, id, fx, db, bodies)
		seen[id] = report
		return report
	return map


func _fx_entries(report: ValidationReport) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in report.entries():
		if String(e.message).contains("E_FX_") or String(e.message).contains("W_FX_"):
			out.append(e)
	return out


## JSON-normal form (ints and floats alike), for comparing a loaded record
## with a built one.
func _normal(value: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(value)), "", true)


func _lookup(db: CardDatabase, id: String) -> Variant:
	if id.begins_with("power_"):
		return db.hero_power(id)
	if id.begins_with("treasure_"):
		return db.treasure(id)
	if id.begins_with("boss_fx_row_"):
		return db.boss(id)
	return db.card(id)


# --- AC-01: every C11 row is in the fixture and validates ----------------------

func test_every_c11_row_1_to_46_is_in_the_fixture_exactly_once() -> void:
	# Arrange
	var regex: RegEx = RegEx.create_from_string(ROW_PATTERN)
	var rows: Dictionary = {}

	# Act
	for record: Dictionary in _flat():
		var hit: RegExMatch = regex.search(str(record.id))
		if hit != null:
			var row: int = int(hit.get_string(1))
			rows[row] = int(rows.get(row, 0)) + 1

	# Assert
	var expected: Dictionary = {}
	for row: int in range(1, C11_ROWS + 1):
		expected[row] = 1
	assert_dict(rows).is_equal(expected)


func test_the_full_fixture_loads_ready_through_boots_validator_map_with_every_host_clean() -> void:
	# Arrange
	var seen: Dictionary = {}
	var db: CardDatabase = _database(V1)

	# Act
	var report: ValidationReport = db.load(_boot_map(seen))

	# Assert — Ready, no error, and no E_FX / W_FX entry of any severity
	# (C11 calls for no warning on any row).
	assert_array(report.errors()).override_failure_message(report.to_text()).is_empty()
	assert_int(db.state()).is_equal(CardDatabase.State.READY)
	assert_array(_fx_entries(report)).override_failure_message(report.to_text()).is_empty()
	# Every row host and every vanilla fixture card went through the real validator.
	var hosts: Array = []
	for record: Dictionary in _flat():
		hosts.append(str(record.id))
	for record: Dictionary in CardFactory.make_fixture_card_set():
		hosts.append(str(record.id))
	for id: String in hosts:
		assert_bool(seen.has(id)).override_failure_message("%s was never validated" % id).is_true()
		assert_array(seen.get(id, [null])).override_failure_message("%s: %s" % [id, str(seen.get(id))]).is_empty()


func test_the_loader_folder_holds_the_flat_records_and_the_factory_set_unchanged() -> void:
	# Arrange — drift guard: the folder and the flat list come from one source.
	var db: CardDatabase = _database(V1)
	db.load(_map({}))

	# Act / Assert
	for record: Dictionary in _flat():
		assert_str(_normal(_lookup(db, str(record.id)))).override_failure_message("drift: %s" % record.id).is_equal(_normal(record))
	for record: Dictionary in CardFactory.make_fixture_card_set():
		assert_str(_normal(db.card(str(record.id)))).override_failure_message("drift: %s" % record.id).is_equal(_normal(record))


func test_the_fixture_tokens_exist_so_no_reference_fails() -> void:
	var db: CardDatabase = _database(V1)
	db.load(_map({}))

	for id: String in ["decay_husk", "war_token_axe", "war_whetstone_blade", "neutral_sheep"]:
		assert_bool(db.has(id)).override_failure_message(id).is_true()
		assert_bool(bool(db.card(id).get("token", false))).override_failure_message(id).is_true()


# --- AC-2: a bad reference fails the load through E_DELEGATED --------------------

func test_a_summon_of_an_unknown_card_is_e_delegated_e_fx_ref_and_fails_the_load() -> void:
	# Arrange — the adapter records its arity and what `db` answers mid-call.
	var calls: Array = []
	var db: CardDatabase = _database(BAD_REF)
	var map: Dictionary = _map({})
	map.effects = func(...args: Array) -> Array:
		var stage_db: CardDatabase = args[3]
		calls.append({"arity": args.size(), "host_id": args[1], "state": stage_db.state(), "has": stage_db.has("neutral_test_vanilla_1_1")})
		return EffectValidator.validate_effects(args[0], args[1], args[2], args[3], EffectValidator.stage7_caps(args[4]))

	# Act
	var report: ValidationReport = db.load(map)

	# Assert — one E_DELEGATED error carrying the owner's code, the host, the
	# effect id and the path; the load Failed.
	var hits: Array[Dictionary] = _fx_entries(report)
	assert_int(hits.size()).override_failure_message(report.to_text()).is_equal(1)
	if not hits.is_empty():
		var hit: Dictionary = hits[0]
		assert_str(String(hit.code)).is_equal(String(ValidationReport.E_DELEGATED))
		assert_str(String(hit.severity)).is_equal(String(ValidationReport.SEVERITY_ERROR))
		assert_str(str(hit.record_id)).is_equal(BAD_CARD)
		assert_str(str(hit.field)).is_equal("effects")
		assert_str(str(hit.message)).starts_with("E_FX_REF: ")
		assert_str(str(hit.message)).contains("`nope`")
		assert_str(str(hit.message)).contains("%s.0" % BAD_CARD)
		assert_str(str(hit.message)).contains("(at effects/0/ops/0/card_id)")
	assert_int(db.state()).is_equal(CardDatabase.State.FAILED)
	# Five arguments on every call, during stage 7 (`Loading`, lookups open).
	var bad: Array = calls.filter(func(c: Dictionary) -> bool: return c.host_id == BAD_CARD)
	assert_int(bad.size()).is_equal(1)
	for call: Dictionary in calls:
		assert_int(int(call.arity)).is_equal(5)
		assert_int(int(call.state)).is_equal(CardDatabase.State.LOADING)
		assert_bool(call.has).is_true()


# --- AC-3: the accept-all stub, and a missing validator ---------------------------

func test_the_same_folder_with_the_accept_all_stub_reaches_ready_with_no_e_fx_entry() -> void:
	# Arrange — the manifest's five-parameter stub, verbatim.
	var map: Dictionary = ValidatorStubs.accept_all()
	map.effects = func(_k: StringName, _id: String, _fx: Variant, _db: Variant, _configs: Dictionary) -> Array: return []
	var db: CardDatabase = _database(BAD_REF)

	# Act
	var report: ValidationReport = db.load(map)

	# Assert
	assert_int(db.state()).is_equal(CardDatabase.State.READY)
	assert_array(report.errors()).override_failure_message(report.to_text()).is_empty()
	assert_array(_fx_entries(report)).is_empty()


func test_load_with_no_effects_validator_is_e_delegated_in_both_build_types() -> void:
	for debug_build: bool in [true, false]:
		# Arrange
		var db: CardDatabase = _database(BAD_REF, debug_build)

		# Act
		var report: ValidationReport = db.load({})

		# Assert — the `effects` key itself is reported, whatever the build
		var missing: Array = report.errors().filter(func(e: Dictionary) -> bool: return e.code == ValidationReport.E_DELEGATED and e.field == "effects")
		assert_int(missing.size()).override_failure_message("debug_build=%s: %s" % [debug_build, report.to_text()]).is_equal(1)
		assert_int(db.state()).is_equal(CardDatabase.State.FAILED)
