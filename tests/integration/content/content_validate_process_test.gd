## Integration: the headless validate command as a process, the shipped
## `content_budgets.json` against its validator, and the JSON Schema files
## against the loader (content story 007 AC-1, AC-2 shipped half, AC-3;
## sprint-3 QA plan "content 007 — placement": subprocess and shipped-file
## work lives here, the pure checks in tests/unit/content/).
##
## AC-1 spawns `godot --headless --path <project> -s res://tools/content/validate.gd
## [-- --data-root <root>]` with `OS.execute` and observes the exit code on
## 4.7.2 (the engine note asks for it to be observed, not assumed). The child
## is the editor binary, a debug build, so pending validators are warnings.
## AC-3 reads `tools/content/schemas/*.schema.json` (not game data) and checks
## the shipped records — read through `DataLoader` + `CardDatabase`, never by
## opening `assets/data/` here — with the small JSON Schema subset below.
extends GdUnitTestSuite

const SHIPPED: String = "res://assets/data/"
const FAILED_ROOT: String = "res://tests/fixtures/data/refs_unknown/"
const NO_ROOT: String = "res://tests/fixtures/data/content_validate_no_such_root/"
const VALIDATE_SCRIPT: String = "res://tools/content/validate.gd"
const SCHEMAS: String = "res://tools/content/schemas/"
## Schema file → the CR-3 record type the loader enforces for it. One
## `cards.schema.json` serves every `cards_<set>.json` (the set ↔ file rule
## is the loader's stage 4, `E_SET_MISMATCH`).
const RECORD_SCHEMAS: Dictionary = {
	"cards": "CardDef", "heroes": "HeroDef", "hero_powers": "HeroPowerDef",
	"bosses": "BossDef", "treasures": "TreasureDef", "bundles": "BundleDef",
}


## Runs validate.gd in a child Godot; returns `{exit_code, output}`.
func _validate(user_args: Array[String]) -> Dictionary:
	var args: Array[String] = ["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", VALIDATE_SCRIPT]
	if not user_args.is_empty():
		args.append("--")
		args.append_array(user_args)
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), args, output, true, false)
	return {"exit_code": code, "output": "\n".join(output)}


func _shipped_db() -> CardDatabase:
	var db: CardDatabase = CardDatabase.new(DataLoader.new(SHIPPED))
	db.load(ContentValidateCommand.boot_validators(true))
	return db


func _schema(name: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SCHEMAS + name + ".schema.json"))
	assert_bool(parsed is Dictionary).override_failure_message("%s.schema.json did not parse" % name).is_true()
	return parsed if parsed is Dictionary else {}


func _sorted(values: Array) -> Array:
	var out: Array = values.duplicate()
	out.sort()
	return out


# --- AC-1: exit contract, observed as a process ------------------------------------

func test_validate_on_shipped_data_exits_0_and_prints_the_report_with_pending_warnings() -> void:
	# Act
	var run: Dictionary = _validate([])

	# Assert — Ready in a debug binary: pending owners are warnings
	assert_int(run.exit_code).is_equal(0)
	assert_str(run.output).contains("validate: Ready — 0 errors")
	assert_str(run.output).contains("[warning] W_POOL_SIZE")
	assert_str(run.output).contains("W_VALIDATOR_PENDING")
	assert_str(run.output).not_contains("[error]")


func test_validate_on_a_failing_root_exits_1_and_prints_the_errors() -> void:
	# Act
	var run: Dictionary = _validate(["--data-root", FAILED_ROOT])

	# Assert
	assert_int(run.exit_code).is_equal(1)
	assert_str(run.output).contains("validate: Failed")
	assert_str(run.output).contains("[error] E_UNKNOWN_REF")


func test_validate_on_a_non_existent_root_exits_2() -> void:
	# Act
	var run: Dictionary = _validate(["--data-root=" + NO_ROOT])

	# Assert
	assert_int(run.exit_code).is_equal(2)
	assert_str(run.output).contains("could not run")


func test_validate_with_an_unknown_argument_exits_2_with_usage() -> void:
	# Act
	var run: Dictionary = _validate(["--strict"])

	# Assert
	assert_int(run.exit_code).is_equal(2)
	assert_str(run.output).contains("usage:")


func test_in_process_run_matches_boot_map_load_of_shipped_data() -> void:
	# Arrange — the command's map is Boot's own (no second map to drift)
	var db: CardDatabase = _shipped_db()

	# Act
	var out: Dictionary = ContentValidateCommand.run(SHIPPED, ContentValidateCommand.boot_validators(true))

	# Assert
	assert_int(out.exit_code).is_equal(0)
	assert_str(out.report_text).starts_with(db.report().to_text())


func test_release_map_makes_pending_validators_errors_and_exits_1() -> void:
	# Act — the release build's map (QA plan: assert debug, note release)
	var out: Dictionary = ContentValidateCommand.run(SHIPPED, ContentValidateCommand.boot_validators(false))

	# Assert — every still-pending config owner is an error row
	assert_int(out.exit_code).is_equal(1)
	for name: String in preload("res://src/core/boot.gd").PENDING_CONFIG_OWNERS:
		assert_str(out.report_text).contains("[error] E_DELEGATED %s.json — W_VALIDATOR_PENDING" % name)


# --- AC-2: the shipped body ---------------------------------------------------------

func test_shipped_content_budgets_passes_validate_config() -> void:
	# Arrange
	var db: CardDatabase = _shipped_db()

	# Act / Assert
	assert_array(ContentValidator.validate_config(db.config("content_budgets"), db)).is_empty()


# --- AC-3: schemas agree with the loader, shipped files conform -----------------------

func test_every_definition_schema_lists_the_cr3_fields_the_loader_enforces() -> void:
	for name: String in RECORD_SCHEMAS:
		# Arrange
		var fields: Dictionary = RecordSchemas.SCHEMAS[RECORD_SCHEMAS[name]].fields
		var required: Array = []
		for key: String in fields:
			if fields[key].required:
				required.append(key)

		# Act
		var items: Dictionary = _schema(name).properties.records.items

		# Assert
		assert_array(_sorted(items.required)).override_failure_message("%s required" % name).is_equal(_sorted(required))
		assert_array(_sorted(items.properties.keys())).override_failure_message("%s properties" % name).is_equal(_sorted(fields.keys()))
		assert_bool(items.additionalProperties).is_false()


func test_every_definition_file_of_the_manifest_has_a_schema() -> void:
	# Act / Assert — derived from FILE_MANIFEST, not a list kept here
	for row: Dictionary in DataLoader.FILE_MANIFEST:
		if row["class"] == "definition":
			var covered: bool = RECORD_SCHEMAS.values().has(row.record_type)
			assert_bool(covered).override_failure_message("%s (%s) has no schema" % [row.name, row.record_type]).is_true()
	for name: String in RECORD_SCHEMAS:
		assert_bool(FileAccess.file_exists(SCHEMAS + name + ".schema.json")).is_true()


func test_card_schema_carries_the_cr3_by_type_rule() -> void:
	# Arrange
	var items: Dictionary = _schema("cards").properties.records.items

	# Act — one if/then per card type
	var rules: Dictionary = {}
	for rule: Dictionary in items.allOf:
		rules[rule["if"].properties.type.const] = rule.then

	# Assert
	assert_array(_sorted(rules.keys())).is_equal(_sorted(RecordSchemas.CARD_BY_TYPE.keys()))
	for t: String in RecordSchemas.CARD_BY_TYPE:
		var need: Array = []
		for stat: String in RecordSchemas.CARD_BY_TYPE[t]:
			if RecordSchemas.CARD_BY_TYPE[t][stat]:
				need.append(stat)
		assert_array(_sorted(rules[t].get("required", []))).is_equal(_sorted(need))


func test_content_budgets_schema_lists_the_validator_keys_at_every_level() -> void:
	# Act / Assert
	_assert_budget_keys(_schema("content_budgets").properties.config, ContentValidator.BUDGETS_SPEC, "config")


func _assert_budget_keys(schema: Dictionary, fields: Dictionary, where: String) -> void:
	assert_array(_sorted(schema.required)).override_failure_message(where).is_equal(_sorted(fields.keys()))
	assert_array(_sorted(schema.properties.keys())).override_failure_message(where).is_equal(_sorted(fields.keys()))
	for key: String in fields:
		if fields[key].kind == ContentValidator.K_OBJECT:
			_assert_budget_keys(schema.properties[key], fields[key].fields, where + "." + key)


func test_every_shipped_record_conforms_to_its_schema() -> void:
	# Arrange
	var db: CardDatabase = _shipped_db()
	var by_type: Dictionary = db.snapshot_handle().records_by_type
	var problems: Array[String] = []

	# Act
	for name: String in RECORD_SCHEMAS:
		var item_schema: Dictionary = _schema(name).properties.records.items
		for rec: Dictionary in by_type[RECORD_SCHEMAS[name]]:
			_conform(rec, item_schema, "%s#%s" % [name, rec.id], problems)

	# Assert
	assert_array(problems).is_empty()


func test_shipped_content_budgets_conforms_to_its_schema() -> void:
	# Arrange
	var problems: Array[String] = []

	# Act
	_conform(_shipped_db().config("content_budgets"), _schema("content_budgets").properties.config, "content_budgets", problems)

	# Assert
	assert_array(problems).is_empty()


func test_schema_check_rejects_a_record_the_loader_would_reject() -> void:
	# Arrange — a spell with `health` (CR-3 by-type rule) and an unknown field
	var item_schema: Dictionary = _schema("cards").properties.records.items
	var bad: Dictionary = (_shipped_db().card("war_sharpen") as Dictionary).duplicate(true)
	bad["health"] = 2.0
	bad["flavour"] = "x"
	var problems: Array[String] = []

	# Act
	_conform(bad, item_schema, "bad", problems)

	# Assert — the checker is not a silent pass
	assert_int(problems.size()).is_greater_equal(2)
	assert_str(" ".join(problems)).contains("flavour")
	assert_str(" ".join(problems)).contains("then")


# --- A JSON Schema 2020-12 subset: the keywords the schema files use ------------------

func _conform(value: Variant, schema: Dictionary, path: String, problems: Array[String]) -> void:
	if schema.has("type") and not _type_ok(value, schema.type):
		problems.append("%s: type %s, expected %s" % [path, type_string(typeof(value)), str(schema.type)])
		return
	if schema.has("const") and not _same(value, schema.const):
		problems.append("%s: %s != const %s" % [path, str(value), str(schema.const)])
	if schema.has("enum") and not (schema.enum as Array).any(func(e: Variant) -> bool: return _same(value, e)):
		problems.append("%s: %s not in enum" % [path, str(value)])
	if value is String:
		var s: String = value
		if schema.has("minLength") and s.length() < int(schema.minLength):
			problems.append("%s: shorter than %d" % [path, int(schema.minLength)])
		if schema.has("maxLength") and s.length() > int(schema.maxLength):
			problems.append("%s: longer than %d" % [path, int(schema.maxLength)])
		if schema.has("pattern") and RegEx.create_from_string(schema.pattern).search(s) == null:
			problems.append("%s: \"%s\" does not match %s" % [path, s, schema.pattern])
	if _is_num(value):
		if schema.has("minimum") and float(value) < float(schema.minimum):
			problems.append("%s: %s < minimum %s" % [path, str(value), str(schema.minimum)])
		if schema.has("maximum") and float(value) > float(schema.maximum):
			problems.append("%s: %s > maximum %s" % [path, str(value), str(schema.maximum)])
	if value is Array:
		var a: Array = value
		if schema.has("minItems") and a.size() < int(schema.minItems):
			problems.append("%s: fewer than %d items" % [path, int(schema.minItems)])
		if schema.has("maxItems") and a.size() > int(schema.maxItems):
			problems.append("%s: more than %d items" % [path, int(schema.maxItems)])
		if schema.get("uniqueItems", false):
			var seen: Dictionary = {}
			for item: Variant in a:
				if seen.has(item):
					problems.append("%s: repeated %s" % [path, str(item)])
				seen[item] = true
		if schema.has("items"):
			for i: int in a.size():
				_conform(a[i], schema.items, "%s[%d]" % [path, i], problems)
	if value is Dictionary:
		var d: Dictionary = value
		for key: Variant in schema.get("required", []):
			if not d.has(key):
				problems.append("%s: missing %s" % [path, str(key)])
		var props: Dictionary = schema.get("properties", {})
		for key: Variant in d:
			if schema.has("propertyNames"):
				_conform(key, schema.propertyNames, "%s.<name %s>" % [path, str(key)], problems)
			if props.has(key):
				_conform(d[key], props[key], "%s.%s" % [path, str(key)], problems)
			elif schema.get("additionalProperties") is bool and not schema.additionalProperties:
				problems.append("%s: unknown field %s" % [path, str(key)])
			elif schema.get("additionalProperties") is Dictionary:
				_conform(d[key], schema.additionalProperties, "%s.%s" % [path, str(key)], problems)
	for sub: Dictionary in schema.get("allOf", []):
		_conform(value, sub, path, problems)
	if schema.has("if"):
		var probe: Array[String] = []
		_conform(value, schema["if"], path, probe)
		if probe.is_empty() and schema.has("then"):
			var then_problems: Array[String] = []
			_conform(value, schema.then, path, then_problems)
			for p: String in then_problems:
				problems.append("%s (then)" % p)
	if schema.has("not"):
		var probe: Array[String] = []
		_conform(value, schema["not"], path, probe)
		if probe.is_empty():
			problems.append("%s: matches a `not` schema %s (then)" % [path, JSON.stringify(schema["not"])])
	if schema.has("anyOf"):
		var any_ok: bool = false
		for sub: Dictionary in schema.anyOf:
			var probe: Array[String] = []
			_conform(value, sub, path, probe)
			any_ok = any_ok or probe.is_empty()
		if not any_ok:
			problems.append("%s: matches no anyOf branch" % path)


func _type_ok(value: Variant, expected: Variant) -> bool:
	var names: Array = expected if expected is Array else [expected]
	for t: String in names:
		match t:
			"object":
				if value is Dictionary:
					return true
			"array":
				if value is Array:
					return true
			"string":
				if value is String:
					return true
			"boolean":
				if value is bool:
					return true
			"null":
				if value == null:
					return true
			"number":
				if _is_num(value):
					return true
			"integer":
				if _is_num(value) and float(value) == floorf(float(value)):
					return true
	return false


func _is_num(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


func _same(a: Variant, b: Variant) -> bool:
	if _is_num(a) and _is_num(b):
		return float(a) == float(b)
	return typeof(a) == typeof(b) and a == b
