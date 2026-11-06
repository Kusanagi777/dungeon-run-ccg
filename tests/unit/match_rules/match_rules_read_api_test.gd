## The narrow value reads of `RulesEngine`, which `MatchQuery` and `MatchDriver` use
## instead of `state()` (ADR-0007 Decision 4; wave 3 review B1): `turn`, `side_snapshot`,
## `owner_of` and `hooks`. Nothing here may hand out a live record.
extends GdUnitTestSuite

const SIDE_PLAYER: String = MatchFactory.SIDE_PLAYER
const SIDE_BOSS: String = MatchFactory.SIDE_BOSS
const NO_SUCH_ID: int = 9_999_999

var _engine: RulesEngine


func before_test() -> void:
	_engine = MatchFactory.make_started_engine()


func after_test() -> void:
	_engine.end_match()


func _player(side: String) -> Dictionary:
	return _engine.state().players[side]


func test_turn_answers_the_match_turn() -> void:
	# Arrange
	var before: int = _engine.turn()

	# Act
	_engine.state().turn = 7

	# Assert
	assert_int(before).is_equal(0)
	assert_int(_engine.turn()).is_equal(7)


func test_hooks_answers_the_matchs_registry() -> void:
	# Act / Assert
	assert_object(_engine.hooks()).is_same(_engine.state().hooks)


func test_side_snapshot_holds_the_values_of_the_side() -> void:
	# Arrange
	var player: Dictionary = _player(SIDE_PLAYER)
	player.mana_current = 3
	player.mana_max = 5
	player.weapon = MatchRecords.weapon(NO_SUCH_ID - 1, "fixture_axe", 2, 2)
	@warning_ignore("return_value_discarded")
	MatchFactory.summon(_engine.state(), SIDE_PLAYER, 2, 3)

	# Act
	var side: Dictionary = _engine.side_snapshot(SIDE_PLAYER)

	# Assert
	assert_that(side.hero).is_equal(player.hero)
	assert_that(side.weapon).is_equal(player.weapon)
	assert_that(side.hero_power).is_equal(player.hero_power)
	assert_that(side.hand).is_equal(player.hand)
	assert_that(side.board).is_equal(player.board)
	assert_int(int(side.mana_current)).is_equal(3)
	assert_int(int(side.mana_max)).is_equal(5)
	assert_int(int(side.deck_count)).is_equal((player.deck as Array).size())


func test_side_snapshot_carries_no_deck() -> void:
	# Act
	var side: Dictionary = _engine.side_snapshot(SIDE_BOSS)

	# Assert: a count, and no order to read
	assert_bool(side.has("deck")).is_false()


func test_side_snapshot_is_a_value_copy() -> void:
	# Arrange
	var player: Dictionary = _player(SIDE_PLAYER)
	player.weapon = MatchRecords.weapon(NO_SUCH_ID - 1, "fixture_axe", 2, 2)
	@warning_ignore("return_value_discarded")
	MatchFactory.summon(_engine.state(), SIDE_PLAYER, 2, 3)
	var before: Dictionary = player.duplicate(true)
	var copy: Dictionary = _engine.side_snapshot(SIDE_PLAYER)

	# Act
	copy.hero.damage_taken = 99
	copy.weapon.attack = 99
	copy.hero_power.used_this_turn = true
	copy.hand[0].def_id = "mutated"
	copy.board[0].attacks_used = 99
	(copy.hand as Array).clear()
	(copy.board as Array).clear()

	# Assert
	assert_that(_player(SIDE_PLAYER)).is_equal(before)


func test_side_snapshot_of_an_empty_weapon_slot_is_null() -> void:
	# Act / Assert
	assert_object(_engine.side_snapshot(SIDE_PLAYER).weapon).is_null()


func test_owner_of_names_the_side_of_any_record() -> void:
	# Arrange
	var boss: Dictionary = _player(SIDE_BOSS)
	var player: Dictionary = _player(SIDE_PLAYER)
	var weapon: Dictionary = MatchRecords.weapon(NO_SUCH_ID - 1, "fixture_axe", 2, 2)
	boss.weapon = weapon

	# Act / Assert
	assert_str(_engine.owner_of(int(boss.hand[0].instance_id))).is_equal(SIDE_BOSS)
	assert_str(_engine.owner_of(int(boss.deck[0].instance_id))).is_equal(SIDE_BOSS)
	assert_str(_engine.owner_of(int(player.hand[0].instance_id))).is_equal(SIDE_PLAYER)
	assert_str(_engine.owner_of(int(player.hero.entity_id))).is_equal(SIDE_PLAYER)
	assert_str(_engine.owner_of(int(weapon.entity_id))).is_equal(SIDE_BOSS)


func test_owner_of_an_unknown_id_is_empty() -> void:
	# Act / Assert
	assert_str(_engine.owner_of(NO_SUCH_ID)).is_empty()
