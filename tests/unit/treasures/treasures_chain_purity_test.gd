## Unit: the hook chain holds no Node and no way back to its registry (treasures story
## 002; design/gdd/treasures.md T2.1, AC-6; ADR-0005 rules 6, 8).
##
## The registry is the one a real match built from `installers_for`, so `on_turn_start`
## runs through the real `EffectResolver`. Scholar's Candle fires on `match.turn` 3,
## the turn the chain is invoked on here. `tools/lint/gates.sh` G8 keeps the source of
## this chain Node-free; this suite reflects on the live objects.
extends GdUnitTestSuite

const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const CANDLE: String = TreasureFixtures.CANDLE
const SIGNET: String = TreasureFixtures.SIGNET
const CLOAK: String = TreasureFixtures.CLOAK
const CANDLE_TURN: int = 2
const POINT: StringName = &"on_turn_start"

var _db: CardDatabase = null
var _game: TreasureFixtures.Match = null


func before() -> void:
	_db = TreasureFixtures.shipped_database()


func after() -> void:
	_db = null


func after_test() -> void:
	if _game != null:
		_game.end()
	_game = null


## True when [param value] holds any Object, however deep in plain containers.
func _holds_object(value: Variant) -> bool:
	if value is Object:
		return true
	if value is Callable:
		return true
	if value is Dictionary:
		for key: Variant in value:
			if _holds_object(key) or _holds_object(value[key]):
				return true
	elif value is Array:
		for item: Variant in value:
			if _holds_object(item):
				return true
	return false


func _installers(ids: Array) -> Array[HookInstaller]:
	return Treasures.new(_db, _db.config("treasures_balance")).installers_for(ids, TreasureFixtures.NO_STATE)


func _invoke_turn_start() -> void:
	var hooks: HookRegistry = _game.engine.hooks()
	_game.engine.run_action(func() -> void: hooks.run_triggers(POINT, &"player", {}))


func test_the_object_probe_finds_an_object_two_containers_down() -> void:
	# Arrange
	var buried: Dictionary = {"effect": {"ops": [{"host": RefCounted.new()}]}}

	# Act and Assert
	assert_bool(_holds_object(buried)).is_true()
	assert_bool(_holds_object({"effect": {"ops": [{"host": "treasure"}]}})).is_false()


func test_ac6_on_turn_start_runs_the_entries_of_the_chain() -> void:
	# Arrange
	_game = TreasureFixtures.Match.new(_db, [CANDLE])
	_game.to_turn(CANDLE_TURN)
	var before_call: int = _game.last_seq()

	# Act
	_invoke_turn_start()

	# Assert
	var drawn: Array = _game.of_type("card_drawn", before_call)
	assert_int(drawn.size()).is_equal(1)
	assert_str(str(drawn[0].payload.source_id)).is_equal(CANDLE)


func test_ac6_every_entry_is_exactly_the_hook_entry_fields_and_holds_no_object() -> void:
	# Arrange
	_game = TreasureFixtures.Match.new(_db, [CANDLE, SIGNET, CLOAK])
	var hooks: HookRegistry = _game.engine.hooks()
	var seen: int = 0

	# Act and Assert
	for point: StringName in HookRegistry.TRIGGER_POINTS + HookRegistry.VALUE_POINTS:
		for entry: Dictionary in hooks.entries(point):
			seen += 1
			assert_array(entry.keys()).contains_exactly_in_any_order(Array(HookRegistry.ENTRY_FIELDS))
			assert_bool(_holds_object(entry)).override_failure_message("object in %s" % str(entry.host_id)).is_false()
	assert_int(seen).is_equal(3)


func test_ac6_the_hosts_list_holds_no_object() -> void:
	# Arrange
	_game = TreasureFixtures.Match.new(_db, [CANDLE, SIGNET])

	# Act
	var hosts: Array = _game.engine.hooks().hosts()

	# Assert
	assert_int(hosts.size()).is_equal(2)
	assert_bool(_holds_object(hosts)).is_false()


func test_ac6_every_installer_property_is_plain_data() -> void:
	# Arrange
	var installer: HookInstaller = _installers([CANDLE])[0]
	var checked: int = 0

	# Act and Assert
	for property: Dictionary in installer.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			checked += 1
			assert_bool(_holds_object(installer.get(property.name))).override_failure_message(str(property.name)).is_false()
	assert_int(checked).is_equal(HookInstaller.new().to_dict().size())


func test_ac6_the_evaluators_are_bound_to_no_node_and_not_to_the_registry() -> void:
	# Arrange
	_game = TreasureFixtures.Match.new(_db, [CANDLE])
	var hooks: HookRegistry = _game.engine.hooks()

	# Act
	var bound: Array = [hooks._fold_entry.get_object(), hooks._run_entry.get_object()]

	# Assert
	for host: Object in bound:
		assert_object(host).is_not_null()
		assert_bool(host is Node).is_false()
		assert_bool(host == hooks).is_false()


func test_ac6_the_chain_types_are_refcounted_not_nodes() -> void:
	# Arrange
	var treasures: Treasures = Treasures.new(_db, _db.config("treasures_balance"))

	# Act and Assert
	assert_bool(treasures is RefCounted).is_true()
	assert_bool(HookRegistry.new() is RefCounted).is_true()
	assert_bool(_installers([CANDLE])[0] is RefCounted).is_true()


func test_running_the_chain_leaves_its_entries_as_they_were() -> void:
	# Arrange
	_game = TreasureFixtures.Match.new(_db, [CANDLE])
	_game.to_turn(CANDLE_TURN)
	var before_call: Array = _game.engine.hooks().entries(POINT).duplicate(true)

	# Act
	_invoke_turn_start()

	# Assert
	assert_array(_game.engine.hooks().entries(POINT)).is_equal(before_call)


func test_an_installed_entry_does_not_follow_a_later_edit_of_its_installer() -> void:
	# Arrange
	var installer: HookInstaller = _installers([CANDLE])[0]
	var hooks: HookRegistry = HookRegistry.new()
	assert_bool(hooks.install(installer)).is_true()

	# Act
	installer.effects[0]["trigger"] = "turn_end"

	# Assert
	assert_str(str(hooks.entries(POINT)[0].effect.trigger)).is_equal("turn_start")
