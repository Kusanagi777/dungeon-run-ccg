## Integration: the Alpha boss rules at run time, on the shipped data (content CN-3 B1
## rows, CN-2 Knowledge and Decay rows; card-effects C2, C5, C7, C9; match-rules C7;
## boss-ai C1, scorer `_threat_answered`).
##
## `card_effects_hook_triggers_observers_test.gd` proves each passive fires once. This
## suite holds them to what their printed text promises around the edges: what a passive
## must not touch, how it survives a clone, what the player actually pays. Then boss hero
## power seating through a real [MatchDriver], the AI's Freeze target, and Vault Golem and
## Raise Dead, the two rows whose value comes from a live tally.
extends GdUnitTestSuite

const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const SIDE_BOSS: String = MatchRecords.SIDE_BOSS
const HERO: String = "hero_war"
const MIRROR: String = "boss_mirror_sage"
const SHADOW: String = "boss_shadow_of_the_delve"
const TOLLMAN: String = "boss_iron_tollman"
const LICH: String = "boss_lich_archivist"
const HAG: String = "boss_frost_hag"
const HERMIT: String = "boss_cellar_hermit"
const POWERLESS: String = "boss_rat_king"
const PLAIN: String = HERMIT

const MINION: String = "neutral_tunnel_rat"
const STURDY: String = "neutral_dungeon_delver"
const OGRE: String = "neutral_ogre_porter"
const SPELL: String = "war_iron_resolve"
const WEAPON: String = "war_rusted_axe"
const RATS: String = "boss_rat_pack"
const RAT_TOKEN: String = "boss_rat"
const LURKER: String = "boss_lurker"
const CLEAVE: String = "war_cleave_through"
const CLEAVE_DAMAGE: int = 2
const LICH_BONUS: int = 2
const DRAIN_DAMAGE: int = 2
const TOLL: int = 1
const GOLEM: String = "knowledge_vault_golem"
const GOLEM_COST: int = 7
const RAISE_DEAD: String = "decay_raise_dead"
const HUSK: String = "decay_husk"
const SERVANT: String = "boss_hag_servant"
const HAND_SIZE: int = 10
const BOARD_SIZE: int = 7
const FREEZE_SEEDS: Array[int] = [1, 2, 3, 4, 5]
## Mana the boss needs to play anything in these cases.
const BOSS_MANA: int = 9

var _db: CardDatabase = null
var _game: ShippedMatch = null


func before() -> void:
	_db = ShippedMatch.database()


func after() -> void:
	_db = null


func after_test() -> void:
	if _game != null:
		_game.finish()
	_game = null


func _player_main(boss_id: String, hero_id: String = HERO) -> ShippedMatch:
	_game = ShippedMatch.new(_db, hero_id, boss_id)
	_game.to_player_main()
	return _game


func _boss_main(boss_id: String) -> ShippedMatch:
	_game = ShippedMatch.new(_db, HERO, boss_id)
	_game.to_boss_main()
	return _game


func _accept(command: Dictionary) -> void:
	var result: Dictionary = _game.submit(command)
	assert_bool(result.accepted).override_failure_message(str(result)).is_true()


func _play(side: String, hand_index: int = 0, target: Variant = null) -> void:
	var board: int = (_game.engine.state().players[side].board as Array).size()
	var card: Dictionary = _game.engine.state().players[side].hand[hand_index]
	var position: Variant = board if str(_db.card(str(card.def_id)).type) == "minion" else null
	_accept(MatchRecords.play_card(side, hand_index, position, target))


func _hand(side: String) -> Array:
	return _game.engine.state().players[side].hand


func _board(side: String) -> Array:
	return _game.engine.state().players[side].board


func _hand_ids(side: String) -> Array:
	return _hand(side).map(func(card: Dictionary) -> String: return str(card.def_id))


func _has(minion: Dictionary, keyword: String) -> bool:
	return EffectSelectors.has_keyword(minion, keyword)


func _kill(entity_id: int) -> void:
	_game.engine.run_action(func() -> void: _game.engine.destroy(entity_id))


# --- Mirror Sage: "Whenever the player plays a minion, the boss adds a copy of it to its hand."


func test_mirror_sage_copies_nothing_when_the_player_casts_a_spell() -> void:
	# Arrange
	_player_main(MIRROR)
	_game.set_hand(SIDE_PLAYER, [SPELL])

	# Act
	_play(SIDE_PLAYER)

	# Assert
	assert_array(_hand_ids(SIDE_BOSS)).is_empty()


func test_mirror_sage_copies_nothing_when_the_player_plays_a_weapon() -> void:
	# Arrange
	_player_main(MIRROR)
	_game.set_hand(SIDE_PLAYER, [WEAPON])

	# Act
	_play(SIDE_PLAYER)

	# Assert — the printed text says a minion
	assert_array(_hand_ids(SIDE_BOSS)).is_empty()


func test_mirror_sage_copies_nothing_when_a_minion_is_summoned_not_played() -> void:
	# Arrange
	_player_main(MIRROR)

	# Act
	@warning_ignore("return_value_discarded")
	_game.summon(SIDE_PLAYER, MINION)

	# Assert
	assert_array(_hand_ids(SIDE_BOSS)).is_empty()


func test_mirror_sage_ignores_the_bosss_own_minions() -> void:
	# Arrange
	_boss_main(MIRROR)
	_game.set_hand(SIDE_BOSS, [MINION])

	# Act
	_play(SIDE_BOSS)

	# Assert
	assert_array(_hand_ids(SIDE_BOSS)).is_empty()


func test_mirror_sage_copy_into_a_full_hand_burns() -> void:
	# Arrange
	_player_main(MIRROR)
	var full: Array = []
	full.resize(HAND_SIZE)
	full.fill(STURDY)
	_game.set_hand(SIDE_BOSS, full)
	_game.set_hand(SIDE_PLAYER, [MINION])
	var since: int = _game.last_seq()

	# Act
	_play(SIDE_PLAYER)

	# Assert
	var passes: Array = _game.of_type("effect_resolved", since).filter(func(e: Dictionary) -> bool: return str(e.payload.host_id) == MIRROR)
	assert_int(passes.size()).is_equal(1)
	assert_str(str(passes[0].payload.ops[0].outcome)).is_equal("burned")
	assert_int(_hand(SIDE_BOSS).size()).is_equal(HAND_SIZE)
	assert_int(_game.of_type("card_burned", since).size()).is_equal(1)


func test_mirror_sage_copy_is_playable_by_the_boss() -> void:
	# Arrange
	_player_main(MIRROR)
	_game.set_hand(SIDE_PLAYER, [MINION])
	_play(SIDE_PLAYER)
	_accept(MatchRecords.end_turn(SIDE_PLAYER))
	_game.engine.state().players[SIDE_BOSS].mana_current = BOSS_MANA
	var index: int = _hand_ids(SIDE_BOSS).find(MINION)

	# Act
	_play(SIDE_BOSS, index)

	# Assert
	assert_str(str(_board(SIDE_BOSS).back().def_id)).is_equal(MINION)


# --- Shadow of the Delve: "The boss's minions have Stealth." (a one-shot grant, DD-X16)


func test_shadow_stealths_a_token_summoned_by_a_battlecry() -> void:
	# Arrange
	_boss_main(SHADOW)
	_game.set_hand(SIDE_BOSS, [RATS])

	# Act
	_play(SIDE_BOSS)

	# Assert — the body played and both Rats
	assert_int(_board(SIDE_BOSS).size()).is_equal(3)
	for minion: Dictionary in _board(SIDE_BOSS):
		assert_bool(_has(minion, "stealth")).override_failure_message(str(minion.def_id)).is_true()


func test_shadow_leaves_the_players_minions_alone() -> void:
	# Arrange
	_player_main(SHADOW)
	_game.set_hand(SIDE_PLAYER, [MINION])

	# Act
	_play(SIDE_PLAYER)

	# Assert
	assert_bool(_has(_board(SIDE_PLAYER)[0], "stealth")).is_false()


func test_shadow_minion_cannot_be_chosen_or_attacked_by_the_player() -> void:
	# Arrange
	_player_main(SHADOW)
	var hidden: int = _game.summon(SIDE_BOSS, STURDY)
	var attacker: int = _game.summon(SIDE_PLAYER, STURDY)

	# Act
	var attack: Dictionary = _game.engine.can_attack(attacker, hidden)

	# Assert
	assert_bool(attack.ok).is_false()


func test_shadow_minion_loses_stealth_when_it_attacks_and_it_does_not_come_back() -> void:
	# Arrange — DD-X16: an aura would re-grant it, a one-shot grant does not
	_boss_main(SHADOW)
	var attacker: int = _game.summon(SIDE_BOSS, STURDY)
	var minion: Dictionary = _game.minion_of(attacker)
	assert_bool(_has(minion, "stealth")).is_true()

	# Act
	_accept(MatchRecords.attack(SIDE_BOSS, attacker, _game.hero_id(SIDE_PLAYER)))
	_accept(MatchRecords.end_turn(SIDE_BOSS))

	# Assert
	assert_bool(_has(minion, "stealth")).is_false()


func test_shadow_stealth_does_not_protect_from_an_all_enemies_spell() -> void:
	# Arrange — match-rules C12: Stealth stops a choice, not an area
	_player_main(SHADOW)
	var hidden: int = _game.summon(SIDE_BOSS, STURDY)
	_game.set_hand(SIDE_PLAYER, [CLEAVE])
	var health: int = _game.engine.health(_game.minion_of(hidden))

	# Act
	_play(SIDE_PLAYER)

	# Assert
	assert_int(_game.engine.health(_game.minion_of(hidden))).is_equal(health - CLEAVE_DAMAGE)


# --- Iron Tollman: "The player's minions cost (1) more."


func test_tollman_charges_the_player_the_raised_cost() -> void:
	# Arrange
	_player_main(TOLLMAN)
	_game.set_hand(SIDE_PLAYER, [MINION])
	var mana: int = int(_game.engine.state().players[SIDE_PLAYER].mana_current)
	var printed: int = int(_db.card(MINION).cost)

	# Act
	_play(SIDE_PLAYER)

	# Assert
	assert_int(int(_game.engine.state().players[SIDE_PLAYER].mana_current)).is_equal(mana - printed - TOLL)


func test_tollman_makes_a_card_at_exactly_printed_mana_unplayable() -> void:
	# Arrange
	_player_main(TOLLMAN)
	_game.set_hand(SIDE_PLAYER, [MINION])
	_game.engine.state().players[SIDE_PLAYER].mana_current = int(_db.card(MINION).cost)

	# Act
	var plays: Array = _game.engine.legal_commands().filter(func(c: Dictionary) -> bool: return str(c.type) == MatchRecords.CMD_PLAY_CARD)
	var result: Dictionary = _game.submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0))

	# Assert
	assert_array(plays).is_empty()
	assert_bool(result.accepted).is_false()


func test_tollman_leaves_spells_and_weapons_at_their_printed_cost() -> void:
	# Arrange
	_player_main(TOLLMAN)
	_game.set_hand(SIDE_PLAYER, [SPELL, WEAPON])

	# Act
	var spell: int = _game.engine.effective_cost(_hand(SIDE_PLAYER)[0], SIDE_PLAYER)
	var weapon: int = _game.engine.effective_cost(_hand(SIDE_PLAYER)[1], SIDE_PLAYER)

	# Assert
	assert_int(spell).is_equal(int(_db.card(SPELL).cost))
	assert_int(weapon).is_equal(int(_db.card(WEAPON).cost))


func test_tollman_toll_holds_on_a_clone() -> void:
	# Arrange — the planner sees the player's costs through a clone (ADR-0006)
	_player_main(TOLLMAN)
	_game.set_hand(SIDE_PLAYER, [MINION])

	# Act
	var clone: RulesEngine = _game.engine.clone()
	var cost: int = clone.effective_cost(clone.state().players[SIDE_PLAYER].hand[0], SIDE_PLAYER)
	clone.end_match()

	# Assert
	assert_int(cost).is_equal(int(_db.card(MINION).cost) + TOLL)


# --- Lich Archivist: "The boss's spells deal 2 more damage."


func test_lich_adds_two_to_every_target_of_a_boss_area_spell() -> void:
	# Arrange
	_boss_main(LICH)
	var first: int = _game.summon(SIDE_PLAYER, OGRE)
	var second: int = _game.summon(SIDE_PLAYER, OGRE)
	var health: int = _game.engine.health(_game.minion_of(first))
	_game.set_hand(SIDE_BOSS, [CLEAVE])

	# Act
	_play(SIDE_BOSS)

	# Assert
	assert_int(_game.engine.health(_game.minion_of(first))).is_equal(health - CLEAVE_DAMAGE - LICH_BONUS)
	assert_int(_game.engine.health(_game.minion_of(second))).is_equal(health - CLEAVE_DAMAGE - LICH_BONUS)


func test_lich_adds_nothing_to_the_players_spell() -> void:
	# Arrange
	_player_main(LICH)
	var target: int = _game.summon(SIDE_BOSS, OGRE)
	var health: int = _game.engine.health(_game.minion_of(target))
	_game.set_hand(SIDE_PLAYER, [CLEAVE])

	# Act
	_play(SIDE_PLAYER)

	# Assert
	assert_int(_game.engine.health(_game.minion_of(target))).is_equal(health - CLEAVE_DAMAGE)


func test_lich_adds_nothing_to_its_own_hero_power() -> void:
	# Arrange — a hero power is not a spell
	_boss_main(LICH)
	var target: int = _game.summon(SIDE_PLAYER, OGRE)
	var health: int = _game.engine.health(_game.minion_of(target))
	_game.set_hand(SIDE_BOSS, [])

	# Act
	_accept(MatchRecords.use_hero_power(SIDE_BOSS, target))

	# Assert
	assert_int(_game.engine.health(_game.minion_of(target))).is_equal(health - DRAIN_DAMAGE)


func test_lich_adds_nothing_to_a_minions_attack() -> void:
	# Arrange
	_boss_main(LICH)
	var attacker: int = _game.summon(SIDE_BOSS, STURDY)
	var hero: Dictionary = _game.engine.state().players[SIDE_PLAYER].hero
	var health: int = _game.engine.health(hero)
	var swing: int = _game.engine.attack(_game.minion_of(attacker))

	# Act
	_accept(MatchRecords.attack(SIDE_BOSS, attacker, _game.hero_id(SIDE_PLAYER)))

	# Assert
	assert_int(_game.engine.health(hero)).is_equal(health - swing)


func test_lich_bonus_holds_on_a_clone() -> void:
	# Arrange — a planner forecasting a boss spell must see the same number
	_boss_main(LICH)
	var target: int = _game.summon(SIDE_PLAYER, OGRE)
	var health: int = _game.engine.health(_game.minion_of(target))
	_game.set_hand(SIDE_BOSS, [CLEAVE])

	# Act
	var clone: RulesEngine = _game.engine.clone()
	var accepted: bool = clone.submit(MatchRecords.play_card(SIDE_BOSS, 0)).accepted
	var after_health: int = clone.health(clone.state().players[SIDE_PLAYER].board[0])
	clone.end_match()

	# Assert
	assert_bool(accepted).is_true()
	assert_int(after_health).is_equal(health - CLEAVE_DAMAGE - LICH_BONUS)


# --- Boss hero power seating (match-rules C7; `MatchConfig.boss.hero_power`)


## A [BossAiSimHarness] whose drivers are built here, without `Boot`.
func _harness() -> BossAiSimHarness:
	var db: CardDatabase = _db
	return BossAiSimHarness.new(db, func(planner_source: Callable) -> Callable:
		return func(config: Dictionary, clock: Callable) -> MatchDriver:
			return MatchDriver.new(config, db, {}, planner_source, clock))


func _seat(harness: BossAiSimHarness, boss_id: String, seed_value: int = 1) -> BossAiSimHarness.Seat:
	var boss: Dictionary = _db.boss(boss_id)
	return harness._seat(boss, seed_value, 1, int(boss.band), {"hero_id": HERO})


func test_driver_seats_the_power_of_a_boss_that_has_one() -> void:
	# Arrange
	var harness: BossAiSimHarness = _harness()

	# Act
	var seat: BossAiSimHarness.Seat = _seat(harness, LICH)
	var seated: String = str(seat.driver._engine.state().players[SIDE_BOSS].hero_power.def_id)
	seat.driver.shutdown()

	# Assert
	assert_str(seated).is_equal(str(_db.boss(LICH).hero_power))


func test_driver_seats_no_power_for_a_boss_without_one() -> void:
	# Arrange
	var harness: BossAiSimHarness = _harness()

	# Act
	var seat: BossAiSimHarness.Seat = _seat(harness, POWERLESS)
	var seated: String = str(seat.driver._engine.state().players[SIDE_BOSS].hero_power.def_id)
	seat.driver.shutdown()

	# Assert
	assert_str(seated).is_empty()


func test_every_powered_boss_uses_its_power_in_a_real_match() -> void:
	# Arrange
	var harness: BossAiSimHarness = _harness()
	var unused: Array[String] = []
	var bosses: Array = [HERMIT, LICH, "boss_scrap_golem", "boss_pyre_sergeant", "boss_dungeon_heart"]

	# Act
	for boss_id: String in bosses:
		var boss: Dictionary = _db.boss(boss_id)
		var used: bool = false
		for seed_value: int in FREEZE_SEEDS:
			var seat: BossAiSimHarness.Seat = harness._play(boss, seed_value, 1, int(boss.band), {"hero_id": HERO})
			used = used or seat.log.events_since(0).any(func(e: Dictionary) -> bool: return str(e.type) == "hero_power_used" and str(e.payload.side) == SIDE_BOSS and str(e.payload.power_id) == str(boss.hero_power))
			if used:
				break
		if not used:
			unused.append(boss_id)

	# Assert
	assert_array(unused).is_empty()


# --- The Freeze target


func test_frost_hag_passive_with_no_enemy_minion_is_no_target_and_draws_nothing() -> void:
	# Arrange
	_boss_main(HAG)
	var draws: int = (_game.engine.rng_match() as RngStream).draws
	var since: int = _game.last_seq()

	# Act
	_accept(MatchRecords.end_turn(SIDE_BOSS))

	# Assert
	var passes: Array = _game.of_type("effect_resolved", since).filter(func(e: Dictionary) -> bool: return str(e.payload.host_id) == HAG)
	assert_int(passes.size()).is_equal(1)
	assert_str(str(passes[0].payload.ops[0].outcome)).is_equal("no_target")
	assert_array(_game.of_type("frozen", since)).is_empty()
	assert_int((_game.engine.rng_match() as RngStream).draws).is_equal(draws)


func test_frost_hag_frozen_minion_misses_the_players_next_attack_then_thaws() -> void:
	# Arrange
	_boss_main(HAG)
	var victim: int = _game.summon(SIDE_PLAYER, STURDY)

	# Act
	_accept(MatchRecords.end_turn(SIDE_BOSS))
	var during: Dictionary = _game.engine.can_attack(victim, _game.hero_id(SIDE_BOSS))
	_accept(MatchRecords.end_turn(SIDE_PLAYER))

	# Assert
	assert_bool(during.ok).is_false()
	assert_bool(bool(_game.minion_of(victim).frozen)).is_false()


func test_boss_ai_freezes_the_highest_attack_minion_with_a_chosen_freeze() -> void:
	# Arrange — scorer: a Freeze answers the threat of what it stops; a 2/1 and a 5/6
	var harness: BossAiSimHarness = _harness()
	var wrong: Array[String] = []
	for seed_value: int in FREEZE_SEEDS:
		var seat: BossAiSimHarness.Seat = _seat(harness, HAG, seed_value)
		var engine: RulesEngine = seat.driver._engine
		@warning_ignore("return_value_discarded")
		harness._submit(seat, seat.driver.legal_commands()[0])
		var ids: Array[int] = [0, 0]
		engine.run_action(func() -> void:
			ids[0] = engine.summon_minion(SIDE_PLAYER, MINION, 0)
			ids[1] = engine.summon_minion(SIDE_PLAYER, OGRE, 1))
		var boss: Dictionary = engine.state().players[SIDE_BOSS]
		boss.hand.clear()
		boss.hand.append(MatchFactory.make_card_instance(MatchFactory.alloc_entity_id(engine.state()), SERVANT, "hand"))
		boss.turns_taken = BOSS_MANA

		# Act
		@warning_ignore("return_value_discarded")
		harness._submit(seat, MatchRecords.end_turn(SIDE_PLAYER))

		# Assert
		var frozen: Array = seat.log.events_since(0).filter(func(e: Dictionary) -> bool: return str(e.type) == "frozen" and str(e.payload.get("source_id")) != HAG)
		if frozen.is_empty() or int(frozen[0].payload.entity_id) != ids[1]:
			wrong.append("seed %d froze %s, ogre %d" % [seed_value, str(frozen), ids[1]])
		seat.driver.shutdown()
	assert_array(wrong).is_empty()


# --- Vault Golem: "Costs (1) less for each spell you've cast this turn."


func _golem_cost(index: int = 0) -> int:
	return _game.engine.effective_cost(_hand(SIDE_PLAYER)[index], SIDE_PLAYER)


func test_vault_golem_costs_its_printed_cost_before_any_spell() -> void:
	# Arrange
	_player_main(POWERLESS, "hero_knowledge")
	_game.set_hand(SIDE_PLAYER, [GOLEM])

	# Act
	_game.engine.run_action(func() -> void: pass)

	# Assert
	assert_int(_golem_cost()).is_equal(GOLEM_COST)


func test_vault_golem_loses_one_per_spell_cast_this_turn() -> void:
	# Arrange
	_player_main(POWERLESS, "hero_knowledge")
	_game.set_hand(SIDE_PLAYER, [SPELL, SPELL, GOLEM])

	# Act
	_play(SIDE_PLAYER)
	var after_one: int = _golem_cost(_hand_ids(SIDE_PLAYER).find(GOLEM))
	_play(SIDE_PLAYER)
	var after_two: int = _golem_cost(_hand_ids(SIDE_PLAYER).find(GOLEM))

	# Assert
	assert_int(after_one).is_equal(GOLEM_COST - 1)
	assert_int(after_two).is_equal(GOLEM_COST - 2)


func test_vault_golem_charges_the_reduced_cost() -> void:
	# Arrange
	_player_main(POWERLESS, "hero_knowledge")
	_game.set_hand(SIDE_PLAYER, [SPELL, GOLEM])
	_play(SIDE_PLAYER)
	var player: Dictionary = _game.engine.state().players[SIDE_PLAYER]
	player.mana_current = GOLEM_COST - 1
	var index: int = _hand_ids(SIDE_PLAYER).find(GOLEM)

	# Act
	_play(SIDE_PLAYER, index)

	# Assert
	assert_int(int(player.mana_current)).is_equal(0)
	assert_str(str(_board(SIDE_PLAYER)[0].def_id)).is_equal(GOLEM)


func test_vault_golem_reduction_is_gone_next_turn() -> void:
	# Arrange
	_player_main(POWERLESS, "hero_knowledge")
	_game.set_hand(SIDE_PLAYER, [SPELL, GOLEM])
	_play(SIDE_PLAYER)
	var golem: Dictionary = _hand(SIDE_PLAYER)[_hand_ids(SIDE_PLAYER).find(GOLEM)]

	# Act
	_accept(MatchRecords.end_turn(SIDE_PLAYER))
	_accept(MatchRecords.end_turn(SIDE_BOSS))

	# Assert
	assert_int(_game.engine.effective_cost(golem, SIDE_PLAYER)).is_equal(GOLEM_COST)


func test_two_vault_golems_each_lose_one_not_two() -> void:
	# Arrange — `targets: self`: each host reduces only itself
	_player_main(POWERLESS, "hero_knowledge")
	_game.set_hand(SIDE_PLAYER, [SPELL, GOLEM, GOLEM])

	# Act
	_play(SIDE_PLAYER)
	var golems: Array = _hand(SIDE_PLAYER).filter(func(card: Dictionary) -> bool: return str(card.def_id) == GOLEM)

	# Assert
	assert_int(golems.size()).is_equal(2)
	for golem: Dictionary in golems:
		assert_int(_game.engine.effective_cost(golem, SIDE_PLAYER)).is_equal(GOLEM_COST - 1)


func test_vault_golem_drawn_after_a_spell_arrives_already_reduced() -> void:
	# Arrange — Iron Resolve draws the Golem off the top
	_player_main(POWERLESS, "hero_knowledge")
	_game.set_hand(SIDE_PLAYER, [SPELL])
	var state: MatchState = _game.engine.state()
	(state.players[SIDE_PLAYER].deck as Array).insert(0, MatchFactory.make_card_instance(MatchFactory.alloc_entity_id(state), GOLEM, "deck"))

	# Act
	_play(SIDE_PLAYER)

	# Assert
	assert_array(_hand_ids(SIDE_PLAYER)).contains([GOLEM])
	assert_int(_golem_cost(_hand_ids(SIDE_PLAYER).find(GOLEM))).is_equal(GOLEM_COST - 1)


func test_vault_golem_reduction_holds_on_a_clone() -> void:
	# Arrange
	_player_main(POWERLESS, "hero_knowledge")
	_game.set_hand(SIDE_PLAYER, [SPELL, GOLEM])
	_play(SIDE_PLAYER)

	# Act
	var clone: RulesEngine = _game.engine.clone()
	var hand: Array = clone.state().players[SIDE_PLAYER].hand
	var golem: Dictionary = hand[hand.find_custom(func(card: Dictionary) -> bool: return str(card.def_id) == GOLEM)]
	var cost: int = clone.effective_cost(golem, SIDE_PLAYER)
	clone.end_match()

	# Assert
	assert_int(cost).is_equal(GOLEM_COST - 1)


# --- Raise Dead: "Summon a 1/1 Husk for each friendly minion that died this turn."


func _raise_dead_pass(since: int) -> Dictionary:
	var passes: Array = _game.of_type("effect_resolved", since).filter(func(e: Dictionary) -> bool: return str(e.payload.host_id) == RAISE_DEAD)
	assert_int(passes.size()).is_equal(1)
	return passes[0].payload.ops[0] if not passes.is_empty() else {}


func test_raise_dead_at_count_zero_summons_nothing_and_logs_applied() -> void:
	# Arrange
	_player_main(POWERLESS, "hero_decay")
	_game.set_hand(SIDE_PLAYER, [RAISE_DEAD])
	var since: int = _game.last_seq()

	# Act
	_play(SIDE_PLAYER)

	# Assert — legal to cast, nothing happens, and nothing is out of the closed set
	assert_array(_board(SIDE_PLAYER)).is_empty()
	assert_str(str(_raise_dead_pass(since).outcome)).is_equal("applied")
	assert_array(_game.of_type("minion_summoned", since)).is_empty()
	assert_array(_game.of_type("summon_failed", since)).is_empty()


func test_raise_dead_summons_one_husk_per_friendly_death_this_turn() -> void:
	# Arrange
	_player_main(POWERLESS, "hero_decay")
	var dead: Array[int] = [_game.summon(SIDE_PLAYER, MINION), _game.summon(SIDE_PLAYER, MINION)]
	for id: int in dead:
		_kill(id)
	_game.set_hand(SIDE_PLAYER, [RAISE_DEAD])
	var since: int = _game.last_seq()

	# Act
	_play(SIDE_PLAYER)

	# Assert
	assert_int(_board(SIDE_PLAYER).size()).is_equal(dead.size())
	for minion: Dictionary in _board(SIDE_PLAYER):
		assert_str(str(minion.def_id)).is_equal(HUSK)
	assert_str(str(_raise_dead_pass(since).outcome)).is_equal("applied")


func test_raise_dead_does_not_count_an_enemy_death() -> void:
	# Arrange
	_player_main(POWERLESS, "hero_decay")
	_kill(_game.summon(SIDE_BOSS, MINION))
	_game.set_hand(SIDE_PLAYER, [RAISE_DEAD])

	# Act
	_play(SIDE_PLAYER)

	# Assert
	assert_array(_board(SIDE_PLAYER)).is_empty()


func test_raise_dead_does_not_count_a_death_from_last_turn() -> void:
	# Arrange
	_player_main(POWERLESS, "hero_decay")
	_kill(_game.summon(SIDE_PLAYER, MINION))
	_accept(MatchRecords.end_turn(SIDE_PLAYER))
	_accept(MatchRecords.end_turn(SIDE_BOSS))
	_game.set_hand(SIDE_PLAYER, [RAISE_DEAD])

	# Act
	_play(SIDE_PLAYER)

	# Assert
	assert_array(_board(SIDE_PLAYER)).is_empty()


func test_raise_dead_with_room_for_one_is_partial() -> void:
	# Arrange — two deaths, six minions left: C5 Failure semantics, Edge Cases `partial`
	_player_main(POWERLESS, "hero_decay")
	var dead: Array[int] = [_game.summon(SIDE_PLAYER, MINION), _game.summon(SIDE_PLAYER, MINION)]
	for id: int in dead:
		_kill(id)
	for _i: int in BOARD_SIZE - 1:
		@warning_ignore("return_value_discarded")
		_game.summon(SIDE_PLAYER, STURDY)
	_game.set_hand(SIDE_PLAYER, [RAISE_DEAD])
	var since: int = _game.last_seq()

	# Act
	_play(SIDE_PLAYER)

	# Assert
	assert_int(_board(SIDE_PLAYER).size()).is_equal(BOARD_SIZE)
	assert_str(str(_raise_dead_pass(since).outcome)).is_equal("partial")
	assert_int(_game.of_type("summon_failed", since).size()).is_equal(1)
