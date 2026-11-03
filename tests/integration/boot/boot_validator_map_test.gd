## Integration: Boot's stage-7 validator map (story card-database/story-004,
## code review 2026-11-03 CDB-004; ADR-0002 Decision 4: a missing validator
## never passes silently; control manifest Foundation).
##
## Pins `_collect_validators`: every manifest config name maps to a real or a
## pending validator, the pending ones are exactly `PENDING_CONFIG_OWNERS`, a
## pending validator reports one `W_VALIDATOR_PENDING` per file (per host kind
## for a record key) — a warning in a debug build, an error in an exported one —
## and the `effects` adapter refuses to run without a `card_effects` body.
## Each test builds the map from a fresh, `auto_free`d Boot instance (never the
## autoload) and loads committed read-only fixture roots.
extends GdUnitTestSuite

const BOOT_SCRIPT := preload("res://src/core/boot.gd")
const FIXTURES: String = "res://tests/fixtures/data/"
const READY_FIXTURE: String = FIXTURES + "minimal/"
const RECORDS_FIXTURE: String = FIXTURES + "clean/"
## The record validators that are real, not pending.
const REAL_RECORD_KEYS: Array[String] = ["effects", "unlock"]


func _map(debug_build: bool = true) -> Dictionary:
	var boot: Node = auto_free(BOOT_SCRIPT.new())
	return boot._collect_validators(null, debug_build)


## True when [param result] is exactly one `W_VALIDATOR_PENDING` entry.
func _is_pending(result: Variant) -> bool:
	return result is Array and (result as Array).size() == 1 \
		and (result as Array)[0] is Dictionary and (result as Array)[0].get("code") == ValidationReport.W_VALIDATOR_PENDING


func _pending_entries(report: ValidationReport) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in report.entries():
		if String(e.message).begins_with(String(ValidationReport.W_VALIDATOR_PENDING) + ": "):
			out.append(e)
	return out


func test_every_manifest_config_maps_to_a_validator_and_the_pending_ones_are_the_list() -> void:
	# Arrange
	var configs: Dictionary = _map().configs
	var pending: Array[String] = []

	# Act — call each with an empty body: a pending one answers W_VALIDATOR_PENDING
	for config_name: String in ValidatorStubs.config_names():
		var validator: Variant = configs.get(config_name)
		assert_bool(validator is Callable and (validator as Callable).is_valid()) \
			.override_failure_message("configs.%s is not a valid Callable" % config_name).is_true()
		if _is_pending((validator as Callable).call({}, null)):
			pending.append(config_name)

	# Assert — no extra keys; pending set is the constant; card_effects is real
	assert_array(configs.keys()).contains_exactly_in_any_order(ValidatorStubs.config_names())
	assert_array(pending).contains_exactly_in_any_order(Array(BOOT_SCRIPT.PENDING_CONFIG_OWNERS))
	assert_bool(BOOT_SCRIPT.PENDING_CONFIG_OWNERS.has("card_effects")).is_false()
	assert_array((configs.card_effects as Callable).call({}, null)).is_equal(EffectValidator.validate_config({}, null))


func test_every_record_key_maps_to_a_validator_and_the_pending_ones_are_the_list() -> void:
	# Arrange
	var map: Dictionary = _map()
	var pending: Array[String] = []

	# Act
	for key: String in DataLoader.RECORD_VALIDATORS:
		var validator: Variant = map.get(key)
		assert_bool(validator is Callable and (validator as Callable).is_valid()).is_true()
		if not REAL_RECORD_KEYS.has(key) and _is_pending((validator as Callable).call(&"boss", "boss_x", null, null, {})):
			pending.append(key)

	# Assert
	assert_array(pending).contains_exactly_in_any_order(Array(BOOT_SCRIPT.PENDING_RECORD_OWNERS))
	assert_int(pending.size() + REAL_RECORD_KEYS.size()).is_equal(DataLoader.RECORD_VALIDATORS.size())


func test_pending_config_validator_is_a_warning_in_debug_naming_the_owner() -> void:
	# Act
	var result: Array = (_map(true).configs.run_ui as Callable).call({"anything": 1}, null)

	# Assert
	assert_int(result.size()).is_equal(1)
	assert_str(String(result[0].severity)).is_equal(String(ValidationReport.SEVERITY_WARNING))
	assert_str(result[0].message).contains("configs.run_ui")
	assert_str(result[0].message).contains("Run UI")


func test_pending_config_validator_is_an_error_in_an_exported_build() -> void:
	# Act
	var result: Array = (_map(false).configs.run_ui as Callable).call({}, null)

	# Assert
	assert_str(String(result[0].severity)).is_equal(String(ValidationReport.SEVERITY_ERROR))


func test_pending_record_validator_reports_once_per_host_kind() -> void:
	# Arrange
	var treasure: Callable = _map().treasure

	# Act — three treasure records, then a second host kind
	var first: Array = treasure.call(&"treasure", "treasure_a", {}, null, {})
	var second: Array = treasure.call(&"treasure", "treasure_b", {}, null, {})
	var third: Array = treasure.call(&"treasure", "treasure_c", {}, null, {})
	var other_kind: Array = treasure.call(&"relic", "relic_a", {}, null, {})

	# Assert
	assert_bool(_is_pending(first)).is_true()
	assert_str(first[0].message).contains("Treasures")
	assert_array(second).is_empty()
	assert_array(third).is_empty()
	assert_bool(_is_pending(other_kind)).is_true()


func test_debug_map_loads_the_ready_fixture_with_one_pending_warning_per_config() -> void:
	# Arrange
	var db: CardDatabase = CardDatabase.new(DataLoader.new(READY_FIXTURE))

	# Act
	db.load(_map(true))

	# Assert — Ready; every pending config is reported, as a warning, by file
	assert_int(db.state()).is_equal(CardDatabase.State.READY)
	assert_array(db.report().errors()).override_failure_message(db.report().to_text()).is_empty()
	var files: Array = _pending_entries(db.report()).map(func(e: Dictionary) -> String: return e.file)
	var expected: Array = Array(BOOT_SCRIPT.PENDING_CONFIG_OWNERS).map(func(n: String) -> String: return n + ".json")
	assert_array(files).contains_exactly_in_any_order(expected)
	for e: Dictionary in _pending_entries(db.report()):
		assert_str(String(e.severity)).is_equal(String(ValidationReport.SEVERITY_WARNING))


func test_release_map_fails_the_ready_fixture_load() -> void:
	# Arrange
	var db: CardDatabase = CardDatabase.new(DataLoader.new(READY_FIXTURE))

	# Act
	db.load(_map(false))

	# Assert — the shipped-build severity: pending validators fail the load
	assert_int(db.state()).is_equal(CardDatabase.State.FAILED)
	assert_int(db.report().errors().size()).is_equal(BOOT_SCRIPT.PENDING_CONFIG_OWNERS.size())


func test_pending_record_validators_report_once_per_host_kind_in_a_load() -> void:
	# Arrange — clean/ has 2 bosses and several treasures; only the two pending
	# record keys come from Boot's map, the rest accept
	var map: Dictionary = ValidatorStubs.accept_all()
	var boot_map: Dictionary = _map(true)
	for key: String in BOOT_SCRIPT.PENDING_RECORD_OWNERS:
		map[key] = boot_map[key]

	# Act
	var report: ValidationReport = DataLoader.new(RECORDS_FIXTURE).run(map).report

	# Assert — one entry per key: ai_profile on bosses.json, treasure on treasures.json
	var fields: Array = _pending_entries(report).map(func(e: Dictionary) -> String: return "%s:%s" % [e.file, e.field])
	assert_array(fields).contains_exactly_in_any_order(["bosses.json:ai_profile", "treasures.json:treasure"])
	assert_bool(report.has_errors()).is_false()


func test_effects_adapter_without_a_card_effects_body_is_an_explicit_error() -> void:
	# Arrange — the bodies map as stage 7b passes it when card_effects failed 7a
	var effects: Callable = _map().effects

	# Act
	var result: Array = effects.call(&"card", "war_x", [], null, {"match_rules": {}})

	# Assert
	assert_int(result.size()).is_equal(1)
	assert_str(String(result[0].code)).is_equal(String(ValidationReport.E_DELEGATED))
	assert_str(result[0].message).contains("card_effects config failed stage 7a")


func test_card_effects_config_failure_fails_every_effects_host_with_the_adapter_error() -> void:
	# Arrange — clean/'s card_effects body is {}: the real 7a validator rejects it
	var map: Dictionary = ValidatorStubs.accept_all()
	var boot_map: Dictionary = _map(true)
	map.effects = boot_map.effects
	map.configs.card_effects = boot_map.configs.card_effects

	# Act
	var report: ValidationReport = DataLoader.new(RECORDS_FIXTURE).run(map).report

	# Assert — card_effects.json errors, and effects hosts carry the adapter error
	var config_errors: Array = report.errors().filter(func(e: Dictionary) -> bool: return e.file == "card_effects.json")
	assert_int(config_errors.size()).is_equal(EffectValidator.validate_config({}, null).size())
	var adapter_errors: Array = report.errors().filter(func(e: Dictionary) -> bool: return String(e.message).contains("card_effects config failed stage 7a"))
	assert_int(adapter_errors.size()).is_greater(0)
