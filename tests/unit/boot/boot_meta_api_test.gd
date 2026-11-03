## Unit tests for the MetaApi abstract seam (story boot-composition-root/story-002).
##
## This is ADR-0001 Engine Compatibility verification (1): the first test that
## instantiates a concrete subclass of an `@abstract` base on Godot 4.7.2.
##
## `@abstract` is enforced at parse time (engine-validation-2026-11-03.md,
## ADR-0006 claim 7): a statically typed `MetaApi.new()` is a parse error, so it
## cannot be written in this file. The refusal tests compile a throw-away
## GDScript from source and assert that `reload()` fails; gdUnit4's
## `assert_error(...).is_runtime_error(...)` captures the parse error. Each of
## those two compiles still prints one expected `SCRIPT ERROR: Parse Error` line.
extends GdUnitTestSuite


## The M1.3 surface plus `load_status()` — name → [Variant.Type, class_name] of
## the declared return (story 002 Implementation Notes, M1.3 literally).
## `Variant` returns report TYPE_NIL with PROPERTY_USAGE_NIL_IS_VARIANT; `void`
## reports TYPE_NIL without it; `Error` reports TYPE_INT with class_name Error.
const EXPECTED_RETURNS: Dictionary = {
	"load_profile": [TYPE_DICTIONARY, ""],
	"save_profile": [TYPE_INT, "Error"],
	"save_active_run": [TYPE_INT, "Error"],
	"load_active_run": [TYPE_NIL, "Variant"],
	"clear_active_run": [TYPE_NIL, "void"],
	"archive_run": [TYPE_DICTIONARY, ""],
	"is_hero_unlocked": [TYPE_BOOL, ""],
	"is_unlocked": [TYPE_BOOL, ""],
	"unlocked_ids": [TYPE_ARRAY, ""],
	"unlocked_keys": [TYPE_ARRAY, ""],
	"is_treasure_unlocked": [TYPE_BOOL, ""],
	"unlock_progress": [TYPE_DICTIONARY, ""],
	"unlock_hint": [TYPE_DICTIONARY, ""],
	"set_setting": [TYPE_INT, "Error"],
	"get_setting": [TYPE_NIL, "Variant"],
	"get_settings": [TYPE_DICTIONARY, ""],
	"stats_for_hero": [TYPE_DICTIONARY, ""],
	"last_hero_id": [TYPE_NIL, "Variant"],
	"run_log": [TYPE_ARRAY, ""],
	"run_log_entry": [TYPE_NIL, "Variant"],
	"pending_notifications": [TYPE_ARRAY, ""],
	"ack_notification": [TYPE_NIL, "void"],
	"validate_unlock_defs": [TYPE_ARRAY, ""],
	"reset_profile": [TYPE_INT, "Error"],
	"load_status": [TYPE_STRING_NAME, ""],
}


## Minimal concrete subclass: every override ends in an explicit `return`
## (Godot 4.7 typed-return rule, breaking-changes.md 4.6→4.7).
class ConcreteMeta:
	extends MetaApi

	func load_profile() -> Dictionary:
		return {}

	func save_profile() -> Error:
		return OK

	func save_active_run(_record: Dictionary) -> Error:
		return OK

	func load_active_run() -> Variant:
		return null

	func clear_active_run() -> void:
		return

	func archive_run(_record: Dictionary) -> Dictionary:
		return {}

	func is_hero_unlocked(_hero_id: String) -> bool:
		return true

	func is_unlocked(_key: String) -> bool:
		return true

	func unlocked_ids(_kind: StringName) -> Array:
		return []

	func unlocked_keys() -> Array:
		return []

	func is_treasure_unlocked(_treasure_id: String) -> bool:
		return true

	func unlock_progress(_key: String) -> Dictionary:
		return {}

	func unlock_hint(_key_or_id: String) -> Dictionary:
		return {}

	func set_setting(_key: StringName, _value: Variant) -> Error:
		return OK

	func get_setting(_key: StringName) -> Variant:
		return null

	func get_settings() -> Dictionary:
		return {}

	func stats_for_hero(_hero_id: String) -> Dictionary:
		return {}

	func last_hero_id() -> Variant:
		return null

	func run_log(_offset: int, _limit: int) -> Array:
		return []

	func run_log_entry(_run_id: String) -> Variant:
		return null

	func pending_notifications() -> Array:
		return []

	func ack_notification(_key: String) -> void:
		return

	func validate_unlock_defs(_defs: Array) -> Array:
		return []

	func reset_profile(_confirm_token: String) -> Error:
		return OK

	func load_status() -> StringName:
		return &"FRESH"


## Compiles `source` as a fresh GDScript and returns `reload()`'s Error.
func _compile(source: String) -> Error:
	var script: GDScript = GDScript.new()
	script.source_code = source
	return script.reload()


## The base's own methods (not inherited from RefCounted / Object).
func _declared_methods() -> Dictionary:
	var by_name: Dictionary = {}
	for method: Dictionary in (MetaApi as Script).get_script_method_list():
		by_name[method.name] = method
	return by_name


# --- AC-3: abstract refusal and a concrete subclass ----------------------------

func test_meta_api_script_reports_abstract() -> void:
	# Arrange
	var script: Script = MetaApi

	# Act
	var abstract: bool = script.is_abstract()

	# Assert
	assert_bool(abstract).is_true()


func test_meta_api_new_is_refused_at_parse_time() -> void:
	# Arrange — the parse error is captured by assert_error (else gdUnit4
	# reports it as a runtime error of the test)
	var source: String = "extends RefCounted\nfunc make() -> Variant:\n\treturn MetaApi.new()\n"
	var box: Dictionary = {"err": OK}

	# Act / Assert — the exact message Godot 4.7.2 prints (engine validation)
	await assert_error(func() -> void: box.err = _compile(source)) \
		.is_runtime_error('Parse Error: Cannot construct abstract class "MetaApi".')
	assert_int(box.err).is_not_equal(OK)


func test_subclass_missing_overrides_is_refused_at_parse_time() -> void:
	# Arrange — the message names a generated script path, so any text matches;
	# the reload() Error is the assertion that matters
	var source: String = "extends MetaApi\n"
	var box: Dictionary = {"err": OK}

	# Act / Assert
	await assert_error(func() -> void: box.err = _compile(source)).is_runtime_error(any_string())
	assert_int(box.err).is_not_equal(OK)


func test_concrete_subclass_instantiates_and_is_meta_api() -> void:
	# Arrange / Act
	var meta: Variant = ConcreteMeta.new()

	# Assert
	assert_object(meta).is_not_null()
	assert_bool(meta is MetaApi).is_true()
	assert_bool(meta is RefCounted).is_true()


func test_concrete_subclass_settings_bus_starts_null() -> void:
	# Arrange / Act — the base supplies no collaborator and no default
	var meta: MetaApi = ConcreteMeta.new()

	# Assert
	assert_object(meta.settings_bus).is_null()


# --- AC-1: every M1.3 method, abstract, with its typed return ------------------

func test_meta_api_declares_exactly_the_m13_methods_plus_load_status() -> void:
	# Arrange
	var expected: Array = EXPECTED_RETURNS.keys()
	expected.sort()

	# Act
	var declared: Array = _declared_methods().keys()
	declared.sort()

	# Assert
	assert_array(declared).is_equal(expected)


func test_meta_api_methods_carry_m13_typed_returns() -> void:
	# Arrange
	var declared: Dictionary = _declared_methods()

	for name: String in EXPECTED_RETURNS:
		# Act
		var ret: Dictionary = declared[name]["return"]
		var want_type: int = EXPECTED_RETURNS[name][0]
		var want_class: String = EXPECTED_RETURNS[name][1]

		# Assert
		assert_int(ret.type).override_failure_message("%s return type" % name).is_equal(want_type)
		match want_class:
			"Variant":
				assert_bool(ret.usage & PROPERTY_USAGE_NIL_IS_VARIANT != 0) \
					.override_failure_message("%s should return Variant" % name).is_true()
			"void":
				assert_bool(ret.usage & PROPERTY_USAGE_NIL_IS_VARIANT == 0) \
					.override_failure_message("%s should return void" % name).is_true()
			_:
				assert_str(String(ret.class_name)) \
					.override_failure_message("%s return class" % name).is_equal(want_class)


func test_every_meta_api_method_is_abstract() -> void:
	# Arrange — `@abstract func` sets METHOD_FLAG_VIRTUAL_REQUIRED on the
	# method (observed on 4.7.2; the parse-time refusal above is the sourced proof)
	var declared: Dictionary = _declared_methods()

	for name: String in declared:
		# Act
		var flags: int = declared[name].flags

		# Assert
		assert_bool(flags & METHOD_FLAG_VIRTUAL_REQUIRED != 0) \
			.override_failure_message("%s is not @abstract" % name).is_true()


# --- AC-2: the signal and the one field ---------------------------------------

func test_meta_api_declares_only_unlock_granted_with_five_typed_args() -> void:
	# Arrange
	var signals: Array[Dictionary] = (MetaApi as Script).get_script_signal_list()

	# Act
	var args: Array = signals[0].args if signals.size() == 1 else []
	var names: Array = args.map(func(a: Dictionary) -> String: return a.name)
	var types: Array = args.map(func(a: Dictionary) -> int: return a.type)

	# Assert
	assert_int(signals.size()).is_equal(1)
	assert_str(String(signals[0].name)).is_equal("unlock_granted")
	assert_array(names).is_equal(["key", "kind", "id", "by_run_id", "retro"])
	assert_array(types).is_equal([TYPE_STRING, TYPE_STRING_NAME, TYPE_STRING, TYPE_STRING, TYPE_BOOL])


func test_meta_api_declares_only_settings_bus_variable_typed_settings_bus() -> void:
	# Arrange
	var script_vars: Array = (MetaApi as Script).get_script_property_list().filter(
		func(p: Dictionary) -> bool: return p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE != 0)

	# Act
	var only: Dictionary = script_vars[0] if script_vars.size() == 1 else {}

	# Assert
	assert_int(script_vars.size()).is_equal(1)
	assert_str(only.get("name", "")).is_equal("settings_bus")
	assert_str(String(only.get("class_name", &""))).is_equal("SettingsBus")


func test_concrete_subclass_emits_base_unlock_granted() -> void:
	# Arrange — both implementations emit the base's signal (ADR-0011)
	var meta: MetaApi = ConcreteMeta.new()

	# Act / Assert
	GameAssertions.assert_signal_emitted(meta, "unlock_granted",
		func() -> void: meta.unlock_granted.emit("first_victory", &"treasure", "treasure_living_armory", "run_test", false))
