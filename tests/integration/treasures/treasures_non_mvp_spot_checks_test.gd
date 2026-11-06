## Integration: the non-MVP treasures, one check each (treasures story 012;
## design/gdd/treasures.md T8 rows 10, 13, 16, 18, T9, Edge Cases, AC-25 to AC-28;
## card-effects C6.7; ADR-0005 rule 9).
##
## The records are the shipped ones, on the GDD's seed and hero. AC-28's feed line,
## "(no effect)", is Match UI's: this suite asserts the rules-tier `healed{amount: 0}`.
extends GdUnitTestSuite

const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const SIDE_BOSS: String = MatchRecords.SIDE_BOSS
const TITHE: String = "treasure_grave_tithe"
const ARMORY: String = "treasure_living_armory"
const PRISM: String = "treasure_focusing_prism"
const CHARM: String = "treasure_mending_charm"
const HUSK: String = "decay_husk"
## A 1/1 that one point of damage kills, and a body that survives it.
const FRAGILE: String = "neutral_test_spot_fragile"
const STURDY: String = "neutral_test_spot_sturdy"
const STURDY_HEALTH: int = 5
## A board watcher: when a friendly minion dies it summons a [constant STURDY], which
## resolves before the treasure's observer, so a slot the death opened is taken again.
const FEEDER: String = "neutral_test_spot_feeder"
## "Deal 1 damage to all enemy minions" (AC-27).
const BOLT: String = "neutral_test_spot_bolt"
const BOLT_DAMAGE: int = 1
const PRISM_BONUS: int = 1
const ENEMY_COUNT: int = 3
const CHARM_HEAL: int = 2
const CHARM_WOUND: int = 5
const STARTING_HAND: int = 3

var _db: CardDatabase = null
var _game: TreasureFixtures.Match = null


func _cards() -> Array:
	return [
		CardFactory.make_minion(FRAGILE, 1, 1, 1),
		CardFactory.make_minion(STURDY, 1, 1, STURDY_HEALTH),
		CardFactory.make_minion(FEEDER, 1, 1, STURDY_HEALTH, [], {"effects": [{
			"trigger": "on_minion_died", "scope": {"who": "friendly_minion"},
			"ops": [{"op": "summon", "card_id": STURDY, "count": 1, "position": "end"}],
		}]}),
		CardFactory.make_spell(BOLT, 1, [{
			"trigger": "cast", "targets": "all_enemy_minions",
			"ops": [{"op": "damage", "amount": BOLT_DAMAGE}],
		}]),
	]


func before() -> void:
	_db = TreasureFixtures.shipped_database({}, _cards())


func after() -> void:
	_db = null


func after_test() -> void:
	if _game != null:
		_game.end()
	_game = null


func _start(ids: Array, db: CardDatabase = _db) -> TreasureFixtures.Match:
	_game = TreasureFixtures.Match.new(db, ids)
	_game.to_turn(1)
	return _game


func _hero_id(side: String) -> int:
	return int(_game.engine.state().players[side].hero.entity_id)


## One action that deals 1 to each of [param ids].
func _hit(ids: Array) -> void:
	_game.engine.run_action(func() -> void:
		for id: int in ids:
			@warning_ignore("return_value_discarded")
			_game.engine.apply_damage(id, 1, _hero_id(SIDE_BOSS)))


func _husks_summoned(from_seq: int) -> Array:
	return _game.of_type("minion_summoned", from_seq).filter(func(e: Dictionary) -> bool: return str(e.payload.card_id) == HUSK)


func _husks_failed(from_seq: int) -> Array:
	return _game.of_type("summon_failed", from_seq).filter(func(e: Dictionary) -> bool: return str(e.payload.card_id) == HUSK)


# --- AC-25: Grave Tithe ----------------------------------------------------------

func test_ac25_two_deaths_in_one_action_summon_one_husk() -> void:
	# Arrange
	_start([TITHE])
	var pair: Array = [_game.summon(SIDE_PLAYER, FRAGILE), _game.summon(SIDE_PLAYER, FRAGILE)]
	var before_hit: int = _game.last_seq()

	# Act
	_hit(pair)

	# Assert
	var husks: Array = _husks_summoned(before_hit)
	assert_int(husks.size()).is_equal(1)
	assert_str(str(husks[0].payload.source_id)).is_equal(TITHE)


func test_ac25_the_husk_lands_at_the_right_end_of_the_board() -> void:
	# Arrange
	_start([TITHE])
	var doomed: int = _game.summon(SIDE_PLAYER, FRAGILE)
	@warning_ignore("return_value_discarded")
	_game.summon(SIDE_PLAYER, STURDY)
	@warning_ignore("return_value_discarded")
	_game.summon(SIDE_PLAYER, STURDY)

	# Act
	_hit([doomed])

	# Assert
	var ids: Array = _game.player().board.map(func(m: Dictionary) -> String: return str(m.def_id))
	assert_array(ids).is_equal([STURDY, STURDY, HUSK])


func test_ac25_a_second_death_that_turn_summons_no_second_husk() -> void:
	# Arrange
	_start([TITHE])
	var first: int = _game.summon(SIDE_PLAYER, FRAGILE)
	var second: int = _game.summon(SIDE_PLAYER, FRAGILE)
	_hit([first])
	var before_second: int = _game.last_seq()

	# Act
	_hit([second])

	# Assert
	assert_array(_husks_summoned(before_second)).is_empty()


func test_ac25_an_enemy_death_summons_nothing() -> void:
	# Arrange
	_start([TITHE])
	var enemy: int = _game.summon(SIDE_BOSS, FRAGILE)
	var before_hit: int = _game.last_seq()

	# Act
	_hit([enemy])

	# Assert
	assert_array(_husks_summoned(before_hit)).is_empty()


## A full board with [constant FRAGILE] about to die: six bodies, the feeder among them.
func _full_board_but_for_the_doomed() -> int:
	_start([TITHE])
	@warning_ignore("return_value_discarded")
	_game.summon(SIDE_PLAYER, FEEDER)
	for _i: int in _game.engine.rule("board_size") - 2:
		@warning_ignore("return_value_discarded")
		_game.summon(SIDE_PLAYER, STURDY)
	return _game.summon(SIDE_PLAYER, FRAGILE)


func test_ac25_a_full_board_fails_the_summon_as_board_full() -> void:
	# Arrange
	var doomed: int = _full_board_but_for_the_doomed()
	var before_hit: int = _game.last_seq()

	# Act
	_hit([doomed])

	# Assert
	var failed: Array = _husks_failed(before_hit)
	assert_int(failed.size()).is_equal(1)
	assert_str(str(failed[0].payload.reason)).is_equal(RulesEngine.SUMMON_FAILED_BOARD_FULL)
	assert_array(_husks_summoned(before_hit)).is_empty()


func test_ac25_after_a_full_board_failure_another_death_brings_no_husk_that_turn() -> void:
	# Arrange
	var doomed: int = _full_board_but_for_the_doomed()
	_hit([doomed])
	var before_more: int = _game.last_seq()

	# Act: the feeder fills the slot again, so an unspent Tithe would fail a second time
	_game.engine.run_action(func() -> void:
		@warning_ignore("return_value_discarded")
		_game.engine.apply_damage(int(_game.player().board.back().entity_id), STURDY_HEALTH, _hero_id(SIDE_BOSS)))

	# Assert
	assert_array(_husks_summoned(before_more)).is_empty()
	assert_array(_husks_failed(before_more)).is_empty()


func test_ac25_the_boss_turn_allows_another_husk() -> void:
	# Arrange
	_start([TITHE])
	var first: int = _game.summon(SIDE_PLAYER, FRAGILE)
	var second: int = _game.summon(SIDE_PLAYER, FRAGILE)
	_hit([first])
	_game.play(MatchRecords.end_turn(SIDE_PLAYER))
	var before_boss: int = _game.last_seq()

	# Act
	_hit([second])

	# Assert
	assert_int(_husks_summoned(before_boss).size()).is_equal(1)


# --- AC-26: Living Armory --------------------------------------------------------

func _legendary_minions(db: CardDatabase) -> Array:
	return db.collectible_pool("war").filter(func(card: Dictionary) -> bool: return card.rarity == "legendary" and card.type == "minion")


## The hand's card that no `card_drawn` put there.
func _armory_card() -> Dictionary:
	var drawn: Array = _game.of_type("card_drawn").map(func(e: Dictionary) -> int: return int(e.payload.instance_id))
	var added: Array = _game.player().hand.filter(func(card: Dictionary) -> bool: return not drawn.has(int(card.instance_id)))
	assert_int(added.size()).is_equal(1)
	return added[0]


func test_ac26_a_pool_with_no_legendary_minion_resolves_empty_pool() -> void:
	# Arrange
	var db: CardDatabase = TreasureFixtures.shipped_database({}, [], true)
	assert_array(_legendary_minions(db)).is_empty()

	# Act
	_game = TreasureFixtures.Match.new(db, [ARMORY])

	# Assert
	var passes: Array = _game.of_type("effect_resolved").filter(func(e: Dictionary) -> bool: return str(e.payload.source_id) == ARMORY)
	assert_int(passes.size()).is_equal(1)
	assert_str(str(passes[0].payload.ops[0].outcome)).is_equal("empty_pool")


func test_ac26_with_no_legendary_the_hand_is_the_starting_three() -> void:
	# Arrange
	var db: CardDatabase = TreasureFixtures.shipped_database({}, [], true)

	# Act
	_game = TreasureFixtures.Match.new(db, [ARMORY])

	# Assert
	assert_int(_game.player().hand.size()).is_equal(STARTING_HAND)


func test_ac26_the_full_pool_adds_a_legendary_minion_of_that_pool() -> void:
	# Arrange
	var pool: Array = _legendary_minions(_db).map(func(card: Dictionary) -> String: return str(card.id))
	assert_array(pool).is_not_empty()

	# Act
	_game = TreasureFixtures.Match.new(_db, [ARMORY])

	# Assert
	assert_int(_game.player().hand.size()).is_equal(STARTING_HAND + 1)
	assert_bool(pool.has(str(_armory_card().def_id))).is_true()


func test_ac26_the_same_seed_twice_adds_the_same_legendary() -> void:
	# Act
	_game = TreasureFixtures.Match.new(_db, [ARMORY])
	var first: String = str(_armory_card().def_id)
	_game.end()
	_game = TreasureFixtures.Match.new(_db, [ARMORY])

	# Assert
	assert_str(str(_armory_card().def_id)).is_equal(first)


# --- AC-27: Focusing Prism -------------------------------------------------------

## Three sturdy boss minions, then [constant BOLT] cast. Returns their ids.
func _cast_bolt_at_three(treasures: Array) -> Array:
	_start(treasures)
	var enemies: Array = []
	for _i: int in ENEMY_COUNT:
		enemies.append(_game.summon(SIDE_BOSS, STURDY))
	_game.script_hand([BOLT])
	_game.play(MatchRecords.play_card(SIDE_PLAYER, 0))
	return enemies


func test_ac27_each_of_three_enemy_minions_takes_two() -> void:
	# Act
	var enemies: Array = _cast_bolt_at_three([PRISM])

	# Assert
	var hits: Array = _game.of_type("damage_dealt").filter(func(e: Dictionary) -> bool: return enemies.has(int(e.payload.target)))
	assert_array(hits.map(func(e: Dictionary) -> int: return int(e.payload.dealt))).is_equal([2, 2, 2])
	for minion: Dictionary in _game.boss().board:
		assert_int(int(minion.damage_taken)).is_equal(BOLT_DAMAGE + PRISM_BONUS)


func test_ac27_without_the_prism_each_takes_one() -> void:
	# Act
	@warning_ignore("return_value_discarded")
	_cast_bolt_at_three([])

	# Assert
	for minion: Dictionary in _game.boss().board:
		assert_int(int(minion.damage_taken)).is_equal(BOLT_DAMAGE)


func test_ac27_effect_resolved_values_show_the_hook_delta_per_target() -> void:
	# Act
	var enemies: Array = _cast_bolt_at_three([PRISM])

	# Assert
	var passes: Array = _game.of_type("effect_resolved").filter(func(e: Dictionary) -> bool: return str(e.payload.source_id) == BOLT or e.payload.get("host_id") == BOLT)
	assert_int(passes.size()).is_equal(1)
	var rows: Array = passes[0].payload.ops
	assert_int(rows.size()).is_equal(1)
	assert_int(enemies.size()).is_equal(ENEMY_COUNT)
	assert_array(rows[0].values.hook_delta).is_equal([PRISM_BONUS, PRISM_BONUS, PRISM_BONUS])


func test_ac27_the_prism_leaves_a_hero_attack_alone() -> void:
	# Arrange
	_start([PRISM])
	var enemy: int = _game.summon(SIDE_BOSS, STURDY)
	var before_hit: int = _game.last_seq()

	# Act: damage from the hero slot, no spell in it
	_game.engine.run_action(func() -> void:
		@warning_ignore("return_value_discarded")
		_game.engine.apply_damage(enemy, BOLT_DAMAGE, _hero_id(SIDE_PLAYER)))

	# Assert
	assert_int(int(_game.of_type("damage_dealt", before_hit)[0].payload.dealt)).is_equal(BOLT_DAMAGE)


# --- AC-28: Mending Charm --------------------------------------------------------

func test_ac28_a_full_health_end_of_turn_logs_healed_zero_from_the_charm() -> void:
	# Arrange
	_start([CHARM])
	var before_end: int = _game.last_seq()

	# Act
	_game.play(MatchRecords.end_turn(SIDE_PLAYER))

	# Assert
	var healed: Array = _game.of_type("healed", before_end)
	assert_int(healed.size()).is_equal(1)
	assert_int(int(healed[0].payload.amount)).is_equal(0)
	assert_int(int(healed[0].payload.requested)).is_equal(CHARM_HEAL)
	assert_str(str(healed[0].payload.source_id)).is_equal(CHARM)
	assert_int(int(healed[0].payload.target)).is_equal(_hero_id(SIDE_PLAYER))


func test_ac28_a_wounded_owner_is_healed_for_two() -> void:
	# Arrange
	_start([CHARM])
	_game.engine.run_action(func() -> void:
		@warning_ignore("return_value_discarded")
		_game.engine.apply_damage(_hero_id(SIDE_PLAYER), CHARM_WOUND, _hero_id(SIDE_BOSS)))
	var wounded: int = _game.engine.health(_game.player().hero)

	# Act
	_game.play(MatchRecords.end_turn(SIDE_PLAYER))

	# Assert
	assert_int(_game.engine.health(_game.player().hero)).is_equal(wounded + CHARM_HEAL)


func test_ac28_the_boss_turn_end_heals_nothing() -> void:
	# Arrange
	_start([CHARM])
	_game.play(MatchRecords.end_turn(SIDE_PLAYER))
	var before_end: int = _game.last_seq()

	# Act
	_game.play(MatchRecords.end_turn(SIDE_BOSS))

	# Assert
	assert_array(_game.of_type("healed", before_end)).is_empty()
