## Integration: how a match installs its treasures (treasures story 002;
## design/gdd/treasures.md T2.3, T3.4, F2, AC-2, AC-3, AC-7; ADR-0005 rules 2, 5, 7;
## ADR-0007 Decision 3).
##
## `MatchConfig` is built as `RunMachine.begin_match` builds it: the player's installers
## from `installers_for`, the boss's from `Treasures.passive_installer`, player first.
extends GdUnitTestSuite

const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const SIDE_BOSS: String = MatchRecords.SIDE_BOSS
const SIGNET: String = TreasureFixtures.SIGNET
const CROWN: String = TreasureFixtures.CROWN
const CLOAK: String = TreasureFixtures.CLOAK
const LEDGER: String = "treasure_quartermasters_ledger"
const TAXMAN: String = "boss_test_taxman"
const HITTER: String = "neutral_test_install_hitter"
const HITTER_COST: int = 1
const HITTER_ATTACK: int = 3
const HITTER_HEALTH: int = 5
## Worn Signet's `set` plus the taxman's `delta`: `fold(2) = set 1 -> +1 = 2`.
const SIGNET_THEN_TAX: int = 2

var _db: CardDatabase = null
var _game: TreasureFixtures.Match = null


func before() -> void:
	_db = TreasureFixtures.shipped_database({}, [CardFactory.make_minion(HITTER, HITTER_COST, HITTER_ATTACK, HITTER_HEALTH)])


func after() -> void:
	_db = null


func after_test() -> void:
	if _game != null:
		_game.end()
	_game = null


func _taxman_installers() -> Array:
	return Treasures.passive_installer(TreasureFixtures.make_boss_test_taxman())


func _treasures() -> Treasures:
	return Treasures.new(_db, _db.config("treasures_balance"))


func _hosts_on(point: StringName) -> Array:
	return _game.engine.hooks().entries(point).map(func(entry: Dictionary) -> String: return str(entry.host_id))


func _hero_id(engine: RulesEngine, side: String) -> int:
	return int(engine.state().players[side].hero.entity_id)


# --- AC-2: installation order ----------------------------------------------------

func test_ac2_modify_cost_holds_the_treasure_then_the_passive() -> void:
	# Act
	_game = TreasureFixtures.Match.new(_db, [SIGNET, CROWN], {"boss_installers": _taxman_installers()})

	# Assert
	assert_array(_hosts_on(&"modify_cost")).is_equal([SIGNET, TAXMAN])


func test_ac2_on_match_start_holds_the_crown() -> void:
	# Act
	_game = TreasureFixtures.Match.new(_db, [SIGNET, CROWN], {"boss_installers": _taxman_installers()})

	# Assert
	assert_array(_hosts_on(&"on_match_start")).is_equal([CROWN])


func test_ac2_the_displayed_hero_power_cost_folds_set_then_delta() -> void:
	# Act
	_game = TreasureFixtures.Match.new(_db, [SIGNET, CROWN], {"boss_installers": _taxman_installers()})

	# Assert
	assert_int(_game.engine.hero_power_cost(SIDE_PLAYER)).is_equal(SIGNET_THEN_TAX)


func test_ac2_pick_order_is_the_entry_order_with_no_sort() -> void:
	# Act: id order would put the ledger after nothing else, so read both orders
	_game = TreasureFixtures.Match.new(_db, [SIGNET, LEDGER])
	var signet_first: Array = _hosts_on(&"modify_cost")
	_game.end()
	_game = TreasureFixtures.Match.new(_db, [LEDGER, SIGNET])

	# Assert
	assert_array(signet_first).is_equal([SIGNET, LEDGER])
	assert_array(_hosts_on(&"modify_cost")).is_equal([LEDGER, SIGNET])


func test_ac2_hosts_list_every_installed_host_with_its_side() -> void:
	# Act
	_game = TreasureFixtures.Match.new(_db, [SIGNET, CROWN], {"boss_installers": _taxman_installers()})

	# Assert
	var hosts: Array = _game.engine.hooks().hosts().map(func(host: Dictionary) -> Array: return [str(host.host_id), str(host.side)])
	assert_array(hosts).is_equal([[SIGNET, SIDE_PLAYER], [CROWN, SIDE_PLAYER], [TAXMAN, SIDE_BOSS]])


# --- AC-3: the second guard ------------------------------------------------------

func _doubled_signet() -> Array:
	var one: Array[HookInstaller] = _treasures().installers_for([SIGNET], TreasureFixtures.NO_STATE)
	return [one[0], HookInstaller.from_dict(one[0].to_dict())]


func test_ac3_a_duplicate_that_reached_the_registry_installs_one_entry() -> void:
	# Act
	_game = TreasureFixtures.Match.new(_db, [], {"installers": _doubled_signet()})

	# Assert
	assert_array(_hosts_on(&"modify_cost")).is_equal([SIGNET])


func test_ac3_the_duplicate_logs_one_hook_install_skipped() -> void:
	# Act
	_game = TreasureFixtures.Match.new(_db, [], {"installers": _doubled_signet()})

	# Assert
	var skipped: Array = _game.of_type("hook_install_skipped")
	assert_int(skipped.size()).is_equal(1)
	assert_str(str(skipped[0].payload.host_id)).is_equal(SIGNET)
	assert_str(str(skipped[0].payload.reason)).is_equal(RulesEngine.SKIP_REASON_DUPLICATE)


func test_ac3_distinct_hosts_log_no_skip() -> void:
	# Act
	_game = TreasureFixtures.Match.new(_db, [SIGNET, CROWN])

	# Assert
	assert_array(_game.of_type("hook_install_skipped")).is_empty()


# --- AC-7: a clone's hooks -------------------------------------------------------

## `[crown, cloak]` at the boss's Main with a boss minion ready to swing.
func _at_the_boss_swing() -> int:
	_game = TreasureFixtures.Match.new(_db, [CROWN, CLOAK])
	_game.to_turn(1)
	var hitter: int = _game.summon(SIDE_BOSS, HITTER)
	_game.play(MatchRecords.end_turn(SIDE_PLAYER))
	return hitter


func _hero_reading(engine: RulesEngine) -> Dictionary:
	var player: Dictionary = engine.state().players[SIDE_PLAYER]
	return {
		"health": engine.health(player.hero),
		"armor": int(player.hero.armor),
		"crystal_bonus": int(player.crystal_bonus),
		"mana_max": int(player.mana_max),
	}


func test_ac7_a_clone_advanced_one_boss_action_reads_as_the_real_advance() -> void:
	# Arrange
	var hitter: int = _at_the_boss_swing()
	var command: Dictionary = MatchRecords.attack(SIDE_BOSS, hitter, _hero_id(_game.engine, SIDE_PLAYER))
	var trial: RulesEngine = _game.engine.clone()

	# Act
	var cloned: Dictionary = trial.submit(command)
	var clone_reading: Dictionary = _hero_reading(trial)
	var clone_gains: Array = trial.state().log.events_since(0).filter(func(e: Dictionary) -> bool: return str(e.type) == "armor_gained")
	trial.end_match()
	var before_real: int = _game.last_seq()
	_game.play(command)

	# Assert: the cloak fired on both, and the reading holds a real hit and armour
	assert_bool(bool(cloned.accepted)).is_true()
	assert_dict(clone_reading).is_equal(_hero_reading(_game.engine))
	assert_int(int(clone_reading.armor)).is_equal(1)
	assert_int(clone_gains.size()).is_equal(_game.of_type("armor_gained", before_real).size())
	assert_int(clone_gains.size()).is_equal(1)


func test_ac7_the_real_log_gains_no_event_while_the_clone_acts() -> void:
	# Arrange
	var hitter: int = _at_the_boss_swing()
	var size_before: int = _game.log.size()
	var trial: RulesEngine = _game.engine.clone()

	# Act
	@warning_ignore("return_value_discarded")
	trial.submit(MatchRecords.attack(SIDE_BOSS, hitter, _hero_id(_game.engine, SIDE_PLAYER)))
	trial.end_match()

	# Assert
	assert_int(_game.log.size()).is_equal(size_before)


func test_ac7_the_real_hero_is_unmoved_while_the_clone_acts() -> void:
	# Arrange
	var hitter: int = _at_the_boss_swing()
	var reading: Dictionary = _hero_reading(_game.engine)
	var trial: RulesEngine = _game.engine.clone()

	# Act
	@warning_ignore("return_value_discarded")
	trial.submit(MatchRecords.attack(SIDE_BOSS, hitter, _hero_id(_game.engine, SIDE_PLAYER)))
	trial.end_match()

	# Assert
	assert_dict(_hero_reading(_game.engine)).is_equal(reading)


func test_ac7_the_clone_copies_the_registry_by_value() -> void:
	# Arrange
	@warning_ignore("return_value_discarded")
	_at_the_boss_swing()

	# Act
	var trial: RulesEngine = _game.engine.clone()
	var entries: Array = trial.hooks().entries(&"on_hero_damaged")
	var same_object: bool = trial.hooks() == _game.engine.hooks()
	trial.end_match()

	# Assert
	assert_bool(same_object).is_false()
	assert_array(entries).is_equal(_game.engine.hooks().entries(&"on_hero_damaged"))
	assert_int(entries.size()).is_equal(1)


func test_ac7_the_crown_crystal_carries_into_a_clones_next_turn() -> void:
	# Arrange
	@warning_ignore("return_value_discarded")
	_at_the_boss_swing()
	var trial: RulesEngine = _game.engine.clone()

	# Act
	@warning_ignore("return_value_discarded")
	trial.submit(MatchRecords.end_turn(SIDE_BOSS))
	var clone_mana: int = int(trial.state().players[SIDE_PLAYER].mana_max)
	trial.end_match()
	_game.play(MatchRecords.end_turn(SIDE_BOSS))

	# Assert
	assert_int(clone_mana).is_equal(int(_game.player().mana_max))
