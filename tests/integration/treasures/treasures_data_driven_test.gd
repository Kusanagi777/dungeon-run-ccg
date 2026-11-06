## Integration: every T8 magnitude comes from the data (treasures story 010;
## design/gdd/treasures.md T8, T9, Tuning Knobs, AC-30; ADR-0002 Decision 4).
##
## One database with the fixture's records edited in memory: each case changes a
## number in `effects` and reads the changed value off a real match, with no code
## change. The edited values sit inside the Tuning Knobs safe ranges. The half of
## AC-30 about F1's constants belongs to story 013, which is Blocked.
extends GdUnitTestSuite

const BOOT_SCRIPT := preload("res://src/core/boot.gd")
const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const SIDE_BOSS: String = MatchRecords.SIDE_BOSS
const CROWN: String = TreasureFixtures.CROWN
const SIGNET: String = TreasureFixtures.SIGNET
const CLOAK: String = TreasureFixtures.CLOAK
const CONSTITUTION: String = TreasureFixtures.CONSTITUTION
const SATCHEL: String = "treasure_bottomless_satchel"
const CHARM: String = "treasure_mending_charm"
const WHEEL: String = "treasure_whetstone_wheel"
## AC-30's edit, and an edit of each other knob, all from Tuning Knobs.
const CONSTITUTION_HEALTH: int = 5
const CROWN_CRYSTALS: int = 2
const SIGNET_COST: int = 0
const CLOAK_ARMOR: int = 2
const SATCHEL_DELTA: int = 1
const CHARM_HEAL: int = 3
const WHEEL_ATTACK: int = 2
const WOUND: int = 8
const HIT: int = 3
const BLADE_ATTACK: int = 1

var _edited: CardDatabase = null
var _game: TreasureFixtures.Match = null


## [param id]'s fixture `effects` with [param value] at `ops[0][key]` of its first effect.
func _with_op(id: String, key: String, value: int) -> Dictionary:
	var record: Dictionary = TreasureFixtures.records().filter(func(def: Dictionary) -> bool: return def.id == id)[0]
	var effects: Array = (record.effects as Array).duplicate(true)
	effects[0].ops[0][key] = value
	return {"effects": effects}


func before() -> void:
	_edited = TreasureFixtures.shipped_database({
		CONSTITUTION: _with_op(CONSTITUTION, "health", CONSTITUTION_HEALTH),
		CROWN: _with_op(CROWN, "amount", CROWN_CRYSTALS),
		SIGNET: _with_op(SIGNET, "set", SIGNET_COST),
		CLOAK: _with_op(CLOAK, "amount", CLOAK_ARMOR),
		SATCHEL: _with_op(SATCHEL, "delta", SATCHEL_DELTA),
		CHARM: _with_op(CHARM, "amount", CHARM_HEAL),
		WHEEL: _with_op(WHEEL, "attack", WHEEL_ATTACK),
	})


func after() -> void:
	_edited = null


func after_test() -> void:
	if _game != null:
		_game.end()
	_game = null


func _hero_id(side: String) -> int:
	return int(_game.engine.state().players[side].hero.entity_id)


func _damage_player(amount: int) -> void:
	_game.engine.run_action(func() -> void:
		@warning_ignore("return_value_discarded")
		_game.engine.apply_damage(_hero_id(SIDE_PLAYER), amount, _hero_id(SIDE_BOSS)))


func test_ac30_iron_constitution_edited_to_five_reads_thirty_five_of_thirty_five() -> void:
	# Arrange
	var base: int = int(_edited.hero(TreasureFixtures.HERO_WAR).health)

	# Act
	_game = TreasureFixtures.Match.new(_edited, [CONSTITUTION])

	# Assert
	assert_int(_game.engine.health(_game.player().hero)).is_equal(base + CONSTITUTION_HEALTH)
	assert_int(_game.engine.max_health(_game.player().hero)).is_equal(base + CONSTITUTION_HEALTH)


func test_ac30_the_crown_crystals_come_from_the_record() -> void:
	# Act
	_game = TreasureFixtures.Match.new(_edited, [CROWN])

	# Assert
	assert_int(int(_game.player().crystal_bonus)).is_equal(CROWN_CRYSTALS)


func test_ac30_the_signet_cost_comes_from_the_record() -> void:
	# Act
	_game = TreasureFixtures.Match.new(_edited, [SIGNET])

	# Assert
	assert_int(_game.engine.hero_power_cost(SIDE_PLAYER)).is_equal(SIGNET_COST)


func test_ac30_the_cloak_armour_comes_from_the_record() -> void:
	# Arrange
	_game = TreasureFixtures.Match.new(_edited, [CLOAK])
	_game.to_turn(1)

	# Act
	_damage_player(HIT)

	# Assert
	assert_int(int(_game.player().hero.armor)).is_equal(CLOAK_ARMOR)


func test_ac30_the_satchel_cards_come_from_the_record() -> void:
	# Arrange
	var base: int = int(_edited.config("match_rules").starting_hand_player)

	# Act
	_game = TreasureFixtures.Match.new(_edited, [SATCHEL])

	# Assert
	assert_int(_game.player().hand.size()).is_equal(base + SATCHEL_DELTA)


func test_ac30_the_charm_heal_comes_from_the_record() -> void:
	# Arrange
	_game = TreasureFixtures.Match.new(_edited, [CHARM])
	_game.to_turn(1)
	_damage_player(WOUND)
	var wounded: int = _game.engine.health(_game.player().hero)

	# Act
	_game.play(MatchRecords.end_turn(SIDE_PLAYER))

	# Assert
	assert_int(_game.engine.health(_game.player().hero)).is_equal(wounded + CHARM_HEAL)


func test_ac30_the_wheel_attack_comes_from_the_record() -> void:
	# Arrange
	_game = TreasureFixtures.Match.new(_edited, [WHEEL])
	_game.to_turn(2)

	# Act
	_game.play(MatchRecords.use_hero_power(SIDE_PLAYER))

	# Assert
	assert_int(_game.engine.attack(_game.player().hero)).is_equal(BLADE_ATTACK + WHEEL_ATTACK)


func test_ac30_the_shipped_records_are_the_t8_fixture_records() -> void:
	# Arrange
	var shipped: CardDatabase = TreasureFixtures.shipped_database()

	# Act and Assert
	var fixture: Array = TreasureFixtures.records()
	assert_int(shipped.treasure_pool().size()).is_equal(fixture.size())
	for def: Dictionary in fixture:
		assert_str(JSON.stringify(shipped.treasure(def.id).effects)).override_failure_message(str(def.id)).is_equal(JSON.stringify(def.effects))


# --- Story 010 AC-3: registration ------------------------------------------------

func test_ac3_boot_maps_treasures_balance_to_the_validator() -> void:
	# Arrange
	var boot: Node = auto_free(BOOT_SCRIPT.new())

	# Act
	var map: Dictionary = boot._collect_validators(null, true)

	# Assert
	assert_bool(map.configs.treasures_balance == Treasures.validate_config).is_true()
	assert_bool(BOOT_SCRIPT.PENDING_CONFIG_OWNERS.has("treasures_balance")).is_false()


func test_ac3_a_shipped_load_reports_no_pending_validator_for_the_balance_file() -> void:
	# Arrange
	var boot: Node = auto_free(BOOT_SCRIPT.new())
	var db: CardDatabase = CardDatabase.new(DataLoader.new(TreasureFixtures.SHIPPED_ROOT))

	# Act
	db.load(boot._collect_validators(null, true))

	# Assert
	assert_int(db.state()).is_equal(CardDatabase.State.READY)
	var pending: Array = db.report().entries().filter(func(row: Dictionary) -> bool: return str(row.get("code")) == "W_VALIDATOR_PENDING" and str(row).contains("treasures_balance"))
	assert_array(pending).is_empty()
