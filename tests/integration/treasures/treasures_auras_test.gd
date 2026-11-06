## Integration: the aura treasures on a real match (treasures story 008;
## design/gdd/treasures.md T8 rows 5, 11, 15, 19, 20, T9, AC-22, AC-24; card-effects C5,
## C7, AC-32; ADR-0007 Decision 1).
##
## Whetstone is the shipped War power (`power_whetstone`), the 1/2 blade the shipped
## token, the auras the shipped T8 records, reached by real commands.
extends GdUnitTestSuite

const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const SIDE_BOSS: String = MatchRecords.SIDE_BOSS
const WHEEL: String = "treasure_whetstone_wheel"
const HORN: String = "treasure_stampede_horn"
const BOOTS: String = "treasure_sprinters_boots"
const STANDARD: String = "treasure_captured_standard"
const BELL: String = "treasure_plague_bell"
const HUSK: String = "decay_husk"
const KEYWORD_RUSH: String = "rush"
## The blade's Attack, and what the Wheel adds to it (T9).
const BLADE_ATTACK: int = 1
const WHEEL_ATTACK: int = 1
## The hero power's cost asks for this turn; the blade has two durability.
const POWER_TURN: int = 2
## Scripted minions; the id carries the printed cost.
const MINION_1: String = "neutral_test_aura_minion_1"
const MINION_3: String = "neutral_test_aura_minion_3"
const MINION_4: String = "neutral_test_aura_minion_4"
const COST_1: int = 1
const COST_3: int = 3
const COST_4: int = 4
const MINION_ATTACK: int = 2
const MINION_HEALTH: int = 6

var _db: CardDatabase = null
var _game: TreasureFixtures.Match = null


func before() -> void:
	_db = TreasureFixtures.shipped_database({}, [
		CardFactory.make_minion(MINION_1, COST_1, MINION_ATTACK, MINION_HEALTH),
		CardFactory.make_minion(MINION_3, COST_3, MINION_ATTACK, MINION_HEALTH),
		CardFactory.make_minion(MINION_4, COST_4, MINION_ATTACK, MINION_HEALTH),
	])


func after() -> void:
	_db = null


func after_test() -> void:
	if _game != null:
		_game.end()
	_game = null


func _start(ids: Array) -> TreasureFixtures.Match:
	_game = TreasureFixtures.Match.new(_db, ids)
	return _game


func _hero(side: String) -> Dictionary:
	return _game.engine.state().players[side].hero


func _hero_id(side: String) -> int:
	return int(_hero(side).entity_id)


func _equip() -> void:
	_game.play(MatchRecords.use_hero_power(SIDE_PLAYER))


func _swing() -> void:
	_game.play(MatchRecords.attack(SIDE_PLAYER, _hero_id(SIDE_PLAYER), _hero_id(SIDE_BOSS)))


func _auras_of(character: Dictionary) -> Array:
	return (character.enchantments as Array).filter(func(e: Dictionary) -> bool: return bool(e.is_aura))


func _weapon_attack() -> int:
	return _game.engine.attack(_hero(SIDE_PLAYER))


func _board() -> Array:
	return _game.player().board


## Plays the scripted [param def_id] as the hand's only card; returns its entity id.
func _play_minion(def_id: String) -> int:
	_game.script_hand([def_id])
	_game.play(MatchRecords.play_card(SIDE_PLAYER, 0, _board().size()))
	return int(_board().back().entity_id)


# --- AC-22: Whetstone Wheel ------------------------------------------------------

func test_ac22_the_equipped_blade_reads_two_attack() -> void:
	# Arrange
	_start([WHEEL])
	_game.to_turn(POWER_TURN)

	# Act
	_equip()

	# Assert
	assert_int(_weapon_attack()).is_equal(BLADE_ATTACK + WHEEL_ATTACK)


func test_ac22_the_attack_is_one_aura_enchantment_of_the_wheel() -> void:
	# Arrange
	_start([WHEEL])
	_game.to_turn(POWER_TURN)

	# Act
	_equip()

	# Assert
	var auras: Array = _auras_of(_game.player().weapon)
	assert_int(auras.size()).is_equal(1)
	assert_str(str(auras[0].source_entity_id)).is_equal(WHEEL)
	assert_int(int(auras[0].attack_delta)).is_equal(WHEEL_ATTACK)


func test_ac22_without_the_wheel_the_blade_reads_its_printed_attack() -> void:
	# Arrange
	_start([])
	_game.to_turn(POWER_TURN)

	# Act
	_equip()

	# Assert
	assert_int(_weapon_attack()).is_equal(BLADE_ATTACK)
	assert_array(_auras_of(_game.player().weapon)).is_empty()


func test_ac22_the_hero_attacks_for_two() -> void:
	# Arrange
	_start([WHEEL])
	_game.to_turn(POWER_TURN)
	_equip()
	var before_swing: int = _game.last_seq()

	# Act
	_swing()

	# Assert
	var hits: Array = _game.of_type("damage_dealt", before_swing).filter(func(e: Dictionary) -> bool: return int(e.payload.target) == _hero_id(SIDE_BOSS))
	assert_int(hits.size()).is_equal(1)
	assert_int(int(hits[0].payload.dealt)).is_equal(BLADE_ATTACK + WHEEL_ATTACK)


func test_ac22_a_destroyed_weapon_leaves_no_aura_anywhere() -> void:
	# Arrange: two swings on two turns spend the blade's two durability
	_start([WHEEL])
	_game.to_turn(POWER_TURN)
	_equip()
	_swing()
	_game.end_round()

	# Act
	_swing()

	# Assert
	assert_that(_game.player().weapon).is_null()
	assert_array(_auras_of(_hero(SIDE_PLAYER))).is_empty()


func test_ac22_a_later_weapon_gains_the_aura_again() -> void:
	# Arrange
	_start([WHEEL])
	_game.to_turn(POWER_TURN)
	_equip()
	_swing()
	_game.end_round()
	_swing()

	# Act: the slot is empty, so the power equips again rather than buffing
	_equip()

	# Assert
	assert_int(_weapon_attack()).is_equal(BLADE_ATTACK + WHEEL_ATTACK)
	assert_int(_auras_of(_game.player().weapon).size()).is_equal(1)


func test_ac22_whetstones_own_buff_is_a_second_enchantment_that_ends_with_the_turn() -> void:
	# Arrange
	_start([WHEEL])
	_game.to_turn(POWER_TURN)
	_equip()
	_game.end_round()

	# Act
	_equip()

	# Assert: T8's +1 this turn stacks on the aura, and only the aura stays
	assert_int(_weapon_attack()).is_equal(BLADE_ATTACK + WHEEL_ATTACK + 1)
	assert_int(_auras_of(_game.player().weapon).size()).is_equal(1)
	_game.end_round()
	assert_int(_weapon_attack()).is_equal(BLADE_ATTACK + WHEEL_ATTACK)


# --- AC-24: Stampede Horn --------------------------------------------------------

func test_ac24_a_minion_played_this_turn_may_attack_an_enemy_minion() -> void:
	# Arrange
	_start([HORN])
	_game.to_turn(1)
	var enemy: int = _game.summon(SIDE_BOSS, MINION_1)
	var mine: int = _play_minion(MINION_1)

	# Act
	var code: String = _game.rejection_of(MatchRecords.attack(SIDE_PLAYER, mine, enemy))

	# Assert
	assert_str(code).is_equal("")


func test_ac24_against_the_hero_it_is_rush_cannot_hit_hero() -> void:
	# Arrange
	_start([HORN])
	_game.to_turn(1)
	var mine: int = _play_minion(MINION_1)

	# Act
	var code: String = _game.rejection_of(MatchRecords.attack(SIDE_PLAYER, mine, _hero_id(SIDE_BOSS)))

	# Assert
	assert_str(code).is_equal("RUSH_CANNOT_HIT_HERO")


func test_ac24_next_turn_it_attacks_the_hero_freely() -> void:
	# Arrange
	_start([HORN])
	_game.to_turn(1)
	var mine: int = _play_minion(MINION_1)
	_game.end_round()

	# Act
	var code: String = _game.rejection_of(MatchRecords.attack(SIDE_PLAYER, mine, _hero_id(SIDE_BOSS)))

	# Assert
	assert_str(code).is_equal("")


func test_ac24_without_the_treasure_the_same_play_is_summoning_sick() -> void:
	# Arrange
	_start([])
	_game.to_turn(1)
	var enemy: int = _game.summon(SIDE_BOSS, MINION_1)
	var mine: int = _play_minion(MINION_1)

	# Act
	var code: String = _game.rejection_of(MatchRecords.attack(SIDE_PLAYER, mine, enemy))

	# Assert
	assert_str(code).is_equal("SUMMONING_SICK")


func test_ac24_the_horn_leaves_enemy_minions_without_rush() -> void:
	# Arrange
	_start([HORN])
	_game.to_turn(1)

	# Act
	var enemy: int = _game.summon(SIDE_BOSS, MINION_1)

	# Assert
	var minion: Dictionary = _game.boss().board.filter(func(m: Dictionary) -> bool: return int(m.entity_id) == enemy)[0]
	assert_array(_auras_of(minion)).is_empty()


# --- T8's other auras ------------------------------------------------------------

func test_sprinters_boots_rush_a_three_cost_minion() -> void:
	# Arrange
	_start([BOOTS])
	_game.to_turn(1)

	# Act
	var mine: int = _game.summon(SIDE_PLAYER, MINION_3)

	# Assert
	var minion: Dictionary = _board().filter(func(m: Dictionary) -> bool: return int(m.entity_id) == mine)[0]
	assert_array(_auras_of(minion).map(func(e: Dictionary) -> Array: return Array(e.keywords_added))).is_equal([[KEYWORD_RUSH]])


func test_sprinters_boots_pass_over_a_four_cost_minion() -> void:
	# Arrange
	_start([BOOTS])
	_game.to_turn(1)

	# Act
	var mine: int = _game.summon(SIDE_PLAYER, MINION_4)

	# Assert
	var minion: Dictionary = _board().filter(func(m: Dictionary) -> bool: return int(m.entity_id) == mine)[0]
	assert_array(_auras_of(minion)).is_empty()


func test_captured_standard_adds_one_attack_to_each_friendly_minion() -> void:
	# Arrange
	_start([STANDARD])
	_game.to_turn(1)

	# Act
	@warning_ignore("return_value_discarded")
	_game.summon(SIDE_PLAYER, MINION_1)
	@warning_ignore("return_value_discarded")
	_game.summon(SIDE_PLAYER, MINION_3)

	# Assert
	for minion: Dictionary in _board():
		assert_int(_game.engine.attack(minion)).is_equal(MINION_ATTACK + 1)


func test_plague_bell_adds_attack_to_husks_only() -> void:
	# Arrange
	_start([BELL])
	_game.to_turn(1)
	var husk_attack: int = int(_db.card(HUSK).attack)

	# Act
	@warning_ignore("return_value_discarded")
	_game.summon(SIDE_PLAYER, HUSK)
	@warning_ignore("return_value_discarded")
	_game.summon(SIDE_PLAYER, MINION_1)

	# Assert
	assert_int(_game.engine.attack(_board()[0])).is_equal(husk_attack + 1)
	assert_int(_game.engine.attack(_board()[1])).is_equal(MINION_ATTACK)
