## Integration: `Boot`, the one autoload and lazy composition root
## (story boot-composition-root/story-004; ADR-0001 Decision 4, ADR-0011
## Decision 4).
##
## The autoload itself is only observed (QQ-04: it exists under `godot -s` and
## is not booted). Every boot is run on a fresh instance of the same script,
## `auto_free`d, so the suite never boots the shared autoload. Card Databases
## load real fixture roots through a real `DataLoader`; the happy path loads
## with explicit `func(...): return []` validator stubs (control manifest).
##
## `ConfigCardDatabase` adds the three queries `MetaStub` reads —
## `config()`, `heroes()`, `treasure_pool()` — over the stage 1-3 snapshot,
## because `CardDatabase` gains them only in card-database story 006.
## TODO(card-database story 006): use `CardDatabase` directly.
extends GdUnitTestSuite

const BOOT_SCRIPT := preload("res://src/core/boot.gd")
const BOOT_SCRIPT_PATH := "res://src/core/boot.gd"
const AUTOLOAD_PREFIX := "autoload/"
const READY_FIXTURE := "res://tests/fixtures/data/minimal/"
const FAILED_FIXTURE := "res://tests/fixtures/data/parse_error/"
const SERVICE_FIELDS: Array[String] = ["card_database", "profile_store", "meta", "settings_bus"]
## The only script variables Boot may declare: service handles and the flag.
const BOOT_FIELDS: Array[String] = ["booted", "_services", "_result"]


## A `CardDatabase` that also answers the queries `MetaStub` uses.
class ConfigCardDatabase:
	extends CardDatabase

	func config(config_name: String) -> Variant:
		return _snapshot.configs.get(config_name) if _snapshot != null else null

	func heroes() -> Array:
		return _snapshot.definitions.get("heroes.json", []) if _snapshot != null else []

	func treasure_pool() -> Array:
		return _snapshot.definitions.get("treasures.json", []) if _snapshot != null else []


func _fresh_boot() -> BOOT_SCRIPT:
	return auto_free(BOOT_SCRIPT.new())


## The full accept-all map (card-database story 004: a missing validator is
## `E_DELEGATED`; record validators take the five stage-7b arguments).
func _stub_validators() -> Dictionary:
	return ValidatorStubs.accept_all()


func _loaded_database() -> ConfigCardDatabase:
	var db: ConfigCardDatabase = ConfigCardDatabase.new(DataLoader.new(READY_FIXTURE))
	db.load(_stub_validators())
	return db


## Runs `call` and asserts it logged `message`: `boot()` reports an override
## problem as a push_error in debug builds (the test runner) and a
## push_warning in release.
func _assert_override_logged(call: Callable, message: String) -> void:
	if OS.is_debug_build():
		await assert_error(call).is_push_error(message)
	else:
		await assert_error(call).is_push_warning(message)


# --- AC 1: the one autoload, idle until boot() (QQ-04) -----------------------

# Ordering assumption: this test reads the one shared `/root/Boot` autoload,
# so it holds only while no suite in the run calls `Boot.boot()` on it (every
# test here boots a `_fresh_boot()` instance instead). A test anywhere under
# `tests/` that boots the autoload makes this fail when it runs first.
func test_boot_autoload_is_not_booted_before_boot_call() -> void:
	# Arrange -- the autoload instance the engine created at startup
	var autoload: Node = get_tree().root.get_node_or_null(NodePath("Boot"))

	# Act / Assert -- present under `godot -s`, idle: no flag, no bag, no child, no tick
	assert_object(autoload).is_not_null()
	assert_object(autoload).is_same(Boot)
	assert_str(autoload.get_script().resource_path).is_equal(BOOT_SCRIPT_PATH)
	assert_bool(Boot.booted).is_false()
	assert_object(Boot.services()).is_null()
	assert_int(autoload.get_child_count()).is_equal(0)
	assert_bool(autoload.is_processing()).is_false()
	assert_bool(autoload.is_physics_processing()).is_false()


func test_project_autoload_section_is_exactly_boot() -> void:
	# Arrange
	var entries: Dictionary = {}

	# Act
	for property: Dictionary in ProjectSettings.get_property_list():
		var setting_name: String = property.name
		if setting_name.begins_with(AUTOLOAD_PREFIX):
			entries[setting_name.trim_prefix(AUTOLOAD_PREFIX)] = ProjectSettings.get_setting(setting_name)

	# Assert -- one entry, a global singleton (`*`) over boot.gd
	assert_array(entries.keys()).contains_exactly(["Boot"])
	assert_str(entries["Boot"]).is_equal("*" + BOOT_SCRIPT_PATH)


func test_boot_script_extends_node() -> void:
	# Arrange / Act
	var boot: Node = _fresh_boot()

	# Assert
	assert_bool(boot is Node).is_true()
	assert_bool(boot.booted).is_false()


func test_boot_booted_refuses_outside_writes() -> void:
	# Arrange
	var boot: BOOT_SCRIPT = _fresh_boot()

	# Act / Assert -- a write before boot() is logged and does not stick
	await assert_error(func() -> void: boot.booted = true).is_push_error("Boot.booted is read-only; set by boot()")
	assert_bool(boot.booted).is_false()

	# Act / Assert -- nor can a write after boot() clear it
	boot.boot({"card_database": _loaded_database()})
	await assert_error(func() -> void: boot.booted = false).is_push_error("Boot.booted is read-only; set by boot()")
	assert_bool(boot.booted).is_true()


# --- AC 2: boot() composes once and is idempotent ------------------------------

func test_boot_twice_returns_same_services_without_reload() -> void:
	# Arrange
	var boot: BOOT_SCRIPT = _fresh_boot()
	var db: ConfigCardDatabase = _loaded_database()
	var report_before: ValidationReport = db.report()

	# Act
	var first: BootResult = boot.boot({"card_database": db})
	var first_services: Services = boot.services()
	var second: BootResult = boot.boot()

	# Assert -- same result, same bag, and load() never re-ran (it replaces the report)
	assert_bool(boot.booted).is_true()
	assert_object(second).is_same(first)
	assert_object(boot.services()).is_same(first_services)
	assert_object(db.report()).is_same(report_before)
	assert_object(second.report).is_same(report_before)
	assert_bool(second.ok).is_true()
	assert_str(String(second.load_status)).is_equal("Ready")


func test_boot_card_database_override_is_used() -> void:
	# Arrange
	var boot: BOOT_SCRIPT = _fresh_boot()
	var db: ConfigCardDatabase = _loaded_database()

	# Act
	var result: BootResult = boot.boot({"card_database": db})

	# Assert -- the given instance, and the MVP Meta line over it
	var services: Services = boot.services()
	assert_bool(result.ok).is_true()
	assert_object(result.report).is_same(db.report())
	assert_object(services.card_database).is_same(db)
	assert_bool(services.meta is MetaStub).is_true()
	assert_str(String(services.meta.load_status())).is_equal("FRESH")
	assert_object(services.profile_store).is_null()


func test_boot_unloaded_card_database_override_is_loaded_by_boot() -> void:
	# Arrange -- not loaded: Boot loads it with its own collected validators
	var boot: BOOT_SCRIPT = _fresh_boot()
	var db: ConfigCardDatabase = ConfigCardDatabase.new(DataLoader.new(READY_FIXTURE))

	# Act
	var result: BootResult = boot.boot({"card_database": db})

	# Assert
	assert_int(db.state()).is_equal(CardDatabase.State.READY)
	assert_bool(result.ok).is_true()
	assert_str(String(result.load_status)).is_equal("Ready")
	assert_object(boot.services().card_database).is_same(db)


func test_boot_settings_bus_is_shared_with_meta() -> void:
	# Arrange
	var boot: BOOT_SCRIPT = _fresh_boot()
	boot.boot({"card_database": _loaded_database()})
	var services: Services = boot.services()
	var received: Array = []
	services.settings_bus.settings_changed.connect(func(key: StringName, _value: Variant) -> void: received.append(key))

	# Act -- the owner publishes on its bus; the bag's bus is that object
	services.meta.settings_bus.publish(&"gamma", services.meta.get_setting(&"gamma"))

	# Assert
	assert_object(services.settings_bus).is_not_null()
	assert_object(services.settings_bus).is_same(services.meta.settings_bus)
	assert_array(received).contains_exactly([&"gamma"])


func test_boot_second_call_overrides_are_logged_and_not_used() -> void:
	# Arrange
	var boot: BOOT_SCRIPT = _fresh_boot()
	var first_db: ConfigCardDatabase = _loaded_database()
	var second_db: ConfigCardDatabase = ConfigCardDatabase.new(DataLoader.new(READY_FIXTURE))
	var first: BootResult = boot.boot({"card_database": first_db})
	var out: Dictionary = {}

	# Act
	await assert_error(func() -> void: out.result = boot.boot({"card_database": second_db})) \
		.is_push_warning("Boot.boot(): already booted; overrides [\"card_database\"] not used")

	# Assert -- the first call's result and bag; the second database never loaded
	assert_object(out.result).is_same(first)
	assert_object(boot.services().card_database).is_same(first_db)
	assert_int(second_db.state()).is_equal(CardDatabase.State.UNLOADED)


# --- AC 3: overrides and the Services bag ----------------------------------------

func test_boot_unknown_override_key_is_logged_and_not_used() -> void:
	# Arrange
	var boot: BOOT_SCRIPT = _fresh_boot()
	var db: ConfigCardDatabase = _loaded_database()
	var out: Dictionary = {}

	# Act
	await _assert_override_logged(func() -> void: out.result = boot.boot({"bogus": 1, "card_database": db}),
		"Boot.boot(): unknown override key \"bogus\" (known: meta, card_database)")

	# Assert -- the known key is still used
	assert_bool(out.result.ok).is_true()
	assert_object(boot.services().card_database).is_same(db)


func test_boot_wrong_type_meta_override_is_logged_and_not_used() -> void:
	# Arrange -- a CardDatabase where a MetaApi belongs
	var boot: BOOT_SCRIPT = _fresh_boot()
	var db: ConfigCardDatabase = _loaded_database()
	var out: Dictionary = {}

	# Act -- no typed-assignment runtime error: the value is dropped first
	await _assert_override_logged(func() -> void: out.result = boot.boot({"meta": db, "card_database": db}),
		"Boot.boot(): override \"meta\" has the wrong type (Object); not used")

	# Assert -- the MVP Meta line stands in
	assert_bool(out.result.ok).is_true()
	assert_object(boot.services().card_database).is_same(db)
	assert_bool(boot.services().meta is MetaStub).is_true()


func test_boot_wrong_type_card_database_override_is_logged_and_not_used() -> void:
	# Arrange -- an int where a CardDatabase belongs
	var boot: BOOT_SCRIPT = _fresh_boot()
	var out: Dictionary = {}

	# Act -- Boot falls back to its own CardDatabase over the shipped data
	await _assert_override_logged(func() -> void: out.result = boot.boot({"card_database": 42}),
		"Boot.boot(): override \"card_database\" has the wrong type (int); not used")

	# Assert -- booted with a real CardDatabase, whatever the shipped data's outcome
	assert_object(out.result).is_not_null()
	assert_bool(boot.booted).is_true()
	assert_bool(boot.services().card_database is CardDatabase).is_true()

func test_boot_meta_override_is_placed_in_services() -> void:
	# Arrange
	var boot: BOOT_SCRIPT = _fresh_boot()
	var db: ConfigCardDatabase = _loaded_database()
	var stub: MetaStub = MetaStub.new(db)

	# Act
	var result: BootResult = boot.boot({"meta": stub, "card_database": db})

	# Assert -- placed as given, and its bus is the bag's bus
	var services: Services = boot.services()
	assert_bool(result.ok).is_true()
	assert_object(services.meta).is_same(stub)
	assert_object(services.settings_bus).is_same(stub.settings_bus)


func test_services_bag_has_exactly_four_fields_and_no_methods() -> void:
	# Arrange
	var bag: Services = Services.new()
	var script: Script = bag.get_script()

	# Act
	var fields: Array[String] = []
	for property: Dictionary in script.get_script_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			fields.append(property.name)

	# Assert
	assert_array(fields).contains_exactly_in_any_order(SERVICE_FIELDS)
	assert_array(script.get_script_method_list()).is_empty()


# --- AC 4: a Failed load, no game state, the load budget ------------------------

func test_boot_failed_load_returns_not_ok_with_report() -> void:
	# Arrange -- a plain CardDatabase over a broken root: constructing MetaStub
	# over it would call config() and crash, so a pass proves none was built
	var boot: BOOT_SCRIPT = _fresh_boot()
	var db: CardDatabase = CardDatabase.new(DataLoader.new(FAILED_FIXTURE))

	# Act
	var result: BootResult = boot.boot({"card_database": db})

	# Assert
	assert_bool(result.ok).is_false()
	assert_str(String(result.load_status)).is_equal("Failed")
	assert_object(result.report).is_same(db.report())
	assert_bool(result.report.has_errors()).is_true()
	assert_bool(boot.booted).is_true()
	assert_object(boot.services().card_database).is_same(db)
	assert_object(boot.services().meta).is_null()
	assert_object(boot.services().settings_bus).is_null()


func test_boot_holds_no_game_state_fields() -> void:
	# Arrange
	var script: Script = _fresh_boot().get_script()

	# Act
	var fields: Array[String] = []
	for property: Dictionary in script.get_script_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			fields.append(property.name)

	# Assert -- service handles and the flag only: no match, run, deck, gold or floor
	assert_array(fields).contains_exactly_in_any_order(BOOT_FIELDS)


func test_boot_data_load_within_budget_ms() -> void:
	# Arrange -- the MVP data set does not exist yet (no assets/data/); the
	# minimal fixture root goes through the same Unloaded → Ready load
	var boot: BOOT_SCRIPT = _fresh_boot()
	var db: ConfigCardDatabase = ConfigCardDatabase.new(DataLoader.new(READY_FIXTURE))

	# Act
	var started_usec: int = Time.get_ticks_usec()
	var result: BootResult = boot.boot({"card_database": db})
	var elapsed_ms: float = (Time.get_ticks_usec() - started_usec) / 1000.0

	# Assert -- the load succeeds. The time is reported, never asserted: a
	# wall-clock assertion is time-dependent (coding-standards.md, Determinism);
	# the hard budget belongs to card-database story 009.
	assert_bool(result.ok).is_true()
	var line: String = "boot_composition_test: Boot.boot() data load %.2f ms (budget %d ms)" % [elapsed_ms, TestConstants.DATA_LOAD_BUDGET_MS]
	if elapsed_ms > float(TestConstants.DATA_LOAD_BUDGET_MS):
		push_warning(line + " -- over budget (advisory)")
	else:
		print(line)
