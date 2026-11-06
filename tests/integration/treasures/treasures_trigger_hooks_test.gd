## Integration: the trigger-hook treasures on a real match (treasures story 007;
## design/gdd/treasures.md T8 rows 1, 6, 8, 9, T9, AC-15, AC-18, AC-20, AC-21;
## match-rules C3 step 4, C4 Start, F4; ADR-0005 rule 4).
##
## The records, cards, `match_rules` and `card_effects` bodies are the shipped ones
## (`TreasureFixtures.Match`), on the GDD's seed and hero, and each turn is reached by
## real commands.
##
## Two GDD spellings differ from what is asserted, on purpose. `enchantment_added` is
## C15's `enchantment_applied` (DD-X04, story 007). AC-15 and AC-18 read "its
## `cause_seq` -> `effect_resolved`", but card-effects C6.6 emits `effect_resolved`
## after the ops with the same `cause_seq`, and rng-event-log F7 makes `cause_seq` point
## backwards, so the op event carries `source_id` and the pass that follows it names
## the same host.
extends GdUnitTestSuite

const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const SIDE_BOSS: String = MatchRecords.SIDE_BOSS
const CROWN: String = TreasureFixtures.CROWN
const CANDLE: String = TreasureFixtures.CANDLE
const CONSTITUTION: String = TreasureFixtures.CONSTITUTION
const CLOAK: String = TreasureFixtures.CLOAK
## T9 magnitudes.
const CROWN_CRYSTALS: int = 1
const CONSTITUTION_HEALTH: int = 10
const CLOAK_ARMOR: int = 1
## AC-20's damage, AC-21's hit.
const AC20_DAMAGE: int = 15
const AC21_HIT: int = 3
const HITTER: String = "neutral_test_hook_hitter"
const HITTER_COST: int = 1
const HITTER_HEALTH: int = 5
## AC-18's player turns: an extra card on these, none on the others of 1..5.
const CANDLE_TURNS: Array[int] = [2, 4]
const LAST_CANDLE_CHECK: int = 5

var _db: CardDatabase = null
var _game: TreasureFixtures.Match = null


func before() -> void:
	_db = TreasureFixtures.shipped_database({}, [CardFactory.make_minion(HITTER, HITTER_COST, AC21_HIT, HITTER_HEALTH)])


func after() -> void:
	_db = null


func after_test() -> void:
	if _game != null:
		_game.end()
	_game = null


func _start(ids: Array) -> TreasureFixtures.Match:
	_game = TreasureFixtures.Match.new(_db, ids)
	return _game


func _passes_of(host_id: String, from_seq: int = 0) -> Array:
	return _game.of_type("effect_resolved", from_seq).filter(func(e: Dictionary) -> bool: return str(e.payload.source_id) == host_id)


func _max_mana() -> int:
	return _game.engine.rule("max_mana")


func _hero_id(side: String) -> int:
	return int(_game.engine.state().players[side].hero.entity_id)


func _damage_player(amount: int) -> void:
	_game.engine.run_action(func() -> void:
		@warning_ignore("return_value_discarded")
		_game.engine.apply_damage(_hero_id(SIDE_PLAYER), amount, _hero_id(SIDE_BOSS)))


## The boss's minion, then the boss's turn, then its swing at the player hero. Returns
## the last `seq` before the swing.
func _boss_swings() -> int:
	var hitter: int = _game.summon(SIDE_BOSS, HITTER)
	_game.play(MatchRecords.end_turn(SIDE_PLAYER))
	var before_swing: int = _game.last_seq()
	_game.play(MatchRecords.attack(SIDE_BOSS, hitter, _hero_id(SIDE_PLAYER)))
	return before_swing


# --- AC-15: Hollow Crown ---------------------------------------------------------

func test_ac15_crown_logs_a_permanent_crystal_for_the_player() -> void:
	# Act
	_start([CROWN])

	# Assert
	var added: Array = _game.of_type("mana_added")
	assert_int(added.size()).is_equal(1)
	assert_str(str(added[0].payload.side)).is_equal(SIDE_PLAYER)
	assert_int(int(added[0].payload.n)).is_equal(CROWN_CRYSTALS)
	assert_bool(bool(added[0].payload.temporary)).is_false()
	assert_str(str(added[0].payload.source_id)).is_equal(CROWN)


func test_ac15_the_crystal_is_attributed_to_the_crown_pass_that_follows_it() -> void:
	# Act
	_start([CROWN])

	# Assert
	var added: Dictionary = _game.of_type("mana_added")[0]
	var passes: Array = _passes_of(CROWN)
	assert_int(passes.size()).is_equal(1)
	assert_int(int(passes[0].seq)).is_greater(int(added.seq))
	assert_int(int(passes[0].cause_seq)).is_equal(int(added.cause_seq))


func test_ac15_the_crystal_precedes_the_first_card_drawn() -> void:
	# Act
	_start([CROWN])

	# Assert
	assert_int(int(_game.of_type("mana_added")[0].seq)).is_less(int(_game.of_type("card_drawn")[0].seq))


func test_ac15_crystal_bonus_lands_on_the_player_only() -> void:
	# Act
	_start([CROWN])

	# Assert
	assert_int(int(_game.player().crystal_bonus)).is_equal(CROWN_CRYSTALS)
	assert_int(int(_game.boss().crystal_bonus)).is_equal(0)


func test_ac15_player_turn_one_reads_two_of_two_with_crystal_gained() -> void:
	# Arrange
	_start([CROWN])
	var before_turn: int = _game.last_seq()

	# Act
	_game.to_turn(1)

	# Assert
	assert_int(int(_game.player().mana_current)).is_equal(2)
	assert_int(int(_game.player().mana_max)).is_equal(2)
	var gained: Array = _game.of_type("crystal_gained", before_turn)
	assert_int(gained.size()).is_equal(1)
	assert_str(str(gained[0].payload.side)).is_equal(SIDE_PLAYER)
	assert_int(int(gained[0].payload.mana_max)).is_equal(2)


func test_ac15_without_the_crown_player_turn_one_reads_one_of_one() -> void:
	# Arrange
	_start([])

	# Act
	_game.to_turn(1)

	# Assert
	assert_int(int(_game.player().mana_max)).is_equal(1)


func test_ac15_player_turn_eight_reads_nine_of_nine() -> void:
	# Arrange
	_start([CROWN])

	# Act
	_game.to_turn(8)

	# Assert
	assert_int(int(_game.player().mana_max)).is_equal(9)
	assert_int(int(_game.player().mana_current)).is_equal(9)


func test_ac15_player_turns_nine_and_ten_read_the_mana_cap() -> void:
	# Arrange
	_start([CROWN])

	# Act and Assert
	_game.to_turn(9)
	assert_int(int(_game.player().mana_max)).is_equal(_max_mana())
	assert_int(int(_game.player().mana_current)).is_equal(_max_mana())
	_game.end_round()
	assert_int(int(_game.player().mana_max)).is_equal(_max_mana())
	assert_int(int(_game.player().mana_current)).is_equal(_max_mana())


func test_ac15_the_boss_turn_one_reads_one_of_one() -> void:
	# Arrange
	_start([CROWN])
	_game.to_turn(1)

	# Act
	_game.play(MatchRecords.end_turn(SIDE_PLAYER))

	# Assert
	assert_int(int(_game.boss().mana_max)).is_equal(1)
	assert_int(int(_game.boss().mana_current)).is_equal(1)


# --- AC-18: Scholar's Candle -----------------------------------------------------

## `{player turn: [card_drawn events of its Start]}` for turns 1..[constant LAST_CANDLE_CHECK].
func _draws_per_turn() -> Dictionary:
	var draws: Dictionary = {}
	var before_turn: int = _game.last_seq()
	_game.play(_game.engine.legal_commands()[0])
	draws[1] = _game.of_type("card_drawn", before_turn)
	for turn: int in range(2, LAST_CANDLE_CHECK + 1):
		_game.play(MatchRecords.end_turn(SIDE_PLAYER))
		before_turn = _game.last_seq()
		_game.play(MatchRecords.end_turn(SIDE_BOSS))
		draws[turn] = _game.of_type("card_drawn", before_turn).filter(func(e: Dictionary) -> bool: return str(e.payload.side) == SIDE_PLAYER)
	return draws


func test_ac18_player_turns_two_and_four_draw_one_extra_card() -> void:
	# Arrange
	_start([CANDLE])

	# Act
	var draws: Dictionary = _draws_per_turn()

	# Assert
	for turn: int in draws:
		var expected: int = 2 if CANDLE_TURNS.has(turn) else 1
		assert_int((draws[turn] as Array).size()).override_failure_message("player turn %d" % turn).is_equal(expected)


func test_ac18_the_extra_card_comes_before_the_natural_draw() -> void:
	# Arrange
	_start([CANDLE])

	# Act
	var draws: Dictionary = _draws_per_turn()

	# Assert
	for turn: int in CANDLE_TURNS:
		var pair: Array = draws[turn]
		assert_str(str(pair[0].payload.get("source_id"))).is_equal(CANDLE)
		assert_bool(pair[1].payload.has("source_id")).is_false()


func test_ac18_the_candle_draws_on_match_turns_three_and_seven() -> void:
	# Arrange
	_start([CANDLE])

	# Act
	@warning_ignore("return_value_discarded")
	_draws_per_turn()

	# Assert
	var turns: Array = _game.of_type("card_drawn").filter(func(e: Dictionary) -> bool: return e.payload.get("source_id") == CANDLE).map(func(e: Dictionary) -> int: return int(e.turn))
	assert_array(turns).is_equal([3, 7])


func test_ac18_each_extra_card_is_followed_by_the_candle_pass_of_its_turn() -> void:
	# Arrange
	_start([CANDLE])

	# Act
	@warning_ignore("return_value_discarded")
	_draws_per_turn()

	# Assert
	for drawn: Dictionary in _game.of_type("card_drawn").filter(func(e: Dictionary) -> bool: return e.payload.get("source_id") == CANDLE):
		var next: Dictionary = _game.event_at(int(drawn.seq) + 1)
		assert_str(str(next.type)).is_equal("effect_resolved")
		assert_str(str(next.payload.source_id)).is_equal(CANDLE)
		assert_int(int(next.cause_seq)).is_equal(int(drawn.cause_seq))


func test_ac18_the_boss_turn_draws_nothing_extra() -> void:
	# Arrange
	_start([CANDLE])
	_game.to_turn(2)
	_game.play(MatchRecords.end_turn(SIDE_PLAYER))

	# Assert: match.turn 4 is the boss's, so only the Start draw of that turn
	var boss_draws: Array = _game.of_type("card_drawn").filter(func(e: Dictionary) -> bool: return int(e.turn) == 4)
	assert_int(boss_draws.size()).is_equal(1)
	assert_str(str(boss_draws[0].payload.side)).is_equal(SIDE_BOSS)


# --- AC-20: Iron Constitution ----------------------------------------------------

func test_ac20_match_started_shows_the_hero_at_forty() -> void:
	# Arrange
	_start([CONSTITUTION])
	var base: int = int(_db.hero(TreasureFixtures.HERO_WAR).health)

	# Act
	_game.to_turn(1)

	# Assert
	var started: Dictionary = _game.of_type("match_started")[0]
	assert_int(int(started.payload.starting_health.player)).is_equal(base + CONSTITUTION_HEALTH)
	assert_int(_game.engine.health(_game.player().hero)).is_equal(base + CONSTITUTION_HEALTH)
	assert_int(_game.engine.max_health(_game.player().hero)).is_equal(base + CONSTITUTION_HEALTH)


func test_ac20_one_enchantment_names_the_treasure_and_its_ten_health() -> void:
	# Act
	_start([CONSTITUTION])

	# Assert
	var applied: Array = _game.of_type("enchantment_applied")
	assert_int(applied.size()).is_equal(1)
	assert_str(str(applied[0].payload.source_entity_id)).is_equal(CONSTITUTION)
	assert_int(int(applied[0].payload.health_delta)).is_equal(CONSTITUTION_HEALTH)
	assert_int(int(applied[0].payload.instance_id)).is_equal(_hero_id(SIDE_PLAYER))


func test_ac20_after_fifteen_damage_the_hero_reads_twenty_five_of_forty() -> void:
	# Arrange
	_start([CONSTITUTION])
	_game.to_turn(1)
	var top: int = _game.engine.max_health(_game.player().hero)

	# Act
	_damage_player(AC20_DAMAGE)

	# Assert
	assert_int(_game.engine.health(_game.player().hero)).is_equal(top - AC20_DAMAGE)
	assert_int(_game.engine.max_health(_game.player().hero)).is_equal(top)


func test_ac20_the_boss_hero_is_left_as_config_seated_it() -> void:
	# Arrange
	_start([])
	var plain: int = _game.engine.max_health(_game.boss().hero)
	_game.end()

	# Act
	_start([CONSTITUTION])

	# Assert
	assert_int(_game.engine.max_health(_game.boss().hero)).is_equal(plain)


# --- AC-21: Thornhide Cloak ------------------------------------------------------

func test_ac21_armor_gained_follows_damage_dealt_in_the_same_action() -> void:
	# Arrange
	_start([CLOAK])
	_game.to_turn(1)

	# Act
	var before_swing: int = _boss_swings()

	# Assert
	var hits: Array = _game.of_type("damage_dealt", before_swing).filter(func(e: Dictionary) -> bool: return int(e.payload.target) == _hero_id(SIDE_PLAYER))
	var gains: Array = _game.of_type("armor_gained", before_swing)
	assert_int(hits.size()).is_equal(1)
	assert_int(gains.size()).is_equal(1)
	assert_int(int(gains[0].seq)).is_greater(int(hits[0].seq))
	assert_int(int(gains[0].payload.amount)).is_equal(CLOAK_ARMOR)
	assert_str(str(gains[0].payload.source_id)).is_equal(CLOAK)


func test_ac21_the_hit_leaves_twenty_seven_health_and_one_armour() -> void:
	# Arrange
	_start([CLOAK])
	_game.to_turn(1)
	var base: int = _game.engine.health(_game.player().hero)

	# Act
	@warning_ignore("return_value_discarded")
	_boss_swings()

	# Assert
	assert_int(_game.engine.health(_game.player().hero)).is_equal(base - AC21_HIT)
	assert_int(int(_game.player().hero.armor)).is_equal(CLOAK_ARMOR)


func test_ac21_a_fatigue_tick_is_absorbed_and_a_new_armour_follows() -> void:
	# Arrange: an empty deck makes the next player Start draw a fatigue tick of 1
	_start([CLOAK])
	_game.to_turn(1)
	@warning_ignore("return_value_discarded")
	_boss_swings()
	var health_before: int = _game.engine.health(_game.player().hero)
	_game.player().deck.clear()
	var before_tick: int = _game.last_seq()

	# Act
	_game.play(MatchRecords.end_turn(SIDE_BOSS))

	# Assert
	var ticks: Array = _game.of_type("damage_dealt", before_tick)
	assert_int(ticks.size()).is_equal(1)
	assert_int(int(ticks[0].payload.armor_absorbed)).is_equal(CLOAK_ARMOR)
	var gains: Array = _game.of_type("armor_gained", before_tick)
	assert_int(gains.size()).is_equal(1)
	assert_int(int(gains[0].seq)).is_greater(int(ticks[0].seq))
	assert_int(_game.engine.health(_game.player().hero)).is_equal(health_before)
	assert_int(int(_game.player().hero.armor)).is_equal(CLOAK_ARMOR)


func test_ac21_without_the_cloak_the_hit_gives_no_armour() -> void:
	# Arrange
	_start([])
	_game.to_turn(1)

	# Act
	var before_swing: int = _boss_swings()

	# Assert
	assert_array(_game.of_type("armor_gained", before_swing)).is_empty()
	assert_int(int(_game.player().hero.armor)).is_equal(0)


func test_ac21_damage_to_the_boss_hero_gives_no_armour() -> void:
	# Arrange
	_start([CLOAK])
	_game.to_turn(1)
	var before_hit: int = _game.last_seq()

	# Act
	_game.engine.run_action(func() -> void:
		@warning_ignore("return_value_discarded")
		_game.engine.apply_damage(_hero_id(SIDE_BOSS), AC21_HIT, _hero_id(SIDE_PLAYER)))

	# Assert
	assert_array(_game.of_type("armor_gained", before_hit)).is_empty()
