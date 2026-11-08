## The authored collection, played through the shipped effect resolver and rules.
extends GdUnitTestSuite

const COLLECTION: String = "law-of-the-jungle"
const PLAYER: String = MatchRecords.SIDE_PLAYER
const BOSS: String = MatchRecords.SIDE_BOSS
const COMPASS: String = "treasure_jungle_trailkeeper_compass"
const WATCHGLASS: String = "treasure_jungle_patient_watchglass"
const RATION: String = "treasure_jungle_last_ration"

var _db: CardDatabase


func before() -> void:
	_db = ShippedMatch.database()


func _cards() -> Array:
	var result: Array = []
	for set_id: String in RecordSchemas.SETS:
		for card: Dictionary in _db.cards_by_set(set_id):
			if card.get("collection_id") == COLLECTION and not card.get("token", false):
				result.append(card)
	return result


func _game(card: Dictionary, side: String, rich: bool) -> ShippedMatch:
	var hero: String = "hero_" + (str(card.set) if card.set != "neutral" else "war")
	var game := ShippedMatch.new(_db, hero, "boss_cellar_hermit", 42, [], [], COLLECTION)
	if side == PLAYER:
		game.to_player_main()
	else:
		game.to_boss_main()
	if rich:
		for id: String in ["neutral_jungle_seedling_keeper", "neutral_jungle_fern_hopper", "shadow_jungle_sap_viper", "shadow_jungle_veil_gecko", "neutral_jungle_fossil_sprout"]:
			game.summon(side, id)
		var other: String = BOSS if side == PLAYER else PLAYER
		for id: String in ["neutral_jungle_seedling_keeper", "neutral_jungle_fern_hopper", "neutral_dungeon_delver"]:
			var entity: int = game.summon(other, id)
			game.minion_of(entity).damage_taken = 1
			game.engine.run_action(func() -> void: game.engine.freeze(entity))
		game.engine.state().players[side].board[0].damage_taken = 1
		game.engine.run_action(func() -> void: game.engine.equip_weapon(side, "war_rusted_axe"))
	game.set_hand(side, [card.id])
	return game


func _trouble(game: ShippedMatch) -> String:
	for event: Dictionary in game.events_after(0):
		if event.type == "log_overflow" or (event.type == "match_ended" and event.payload.get("result") == "fault"):
			return str(event)
		if event.type == "effect_resolved":
			for operation: Dictionary in event.payload.ops:
				if not EffectOps.OUTCOMES.has(str(operation.outcome)) or operation.get("values", {}).has("unsupported"):
					return str(operation)
	return ""


func _sweep(side: String) -> void:
	var failures: Array[String] = []
	var played: Dictionary = {}
	for card: Dictionary in _cards():
		for rich: bool in [false, true]:
			var game: ShippedMatch = _game(card, side, rich)
			var plays: Array = game.engine.legal_commands().filter(func(c: Dictionary) -> bool: return c.type == MatchRecords.CMD_PLAY_CARD)
			if rich and plays.is_empty():
				failures.append("%s: no legal rich-board play" % card.id)
			if not plays.is_empty():
				var accepted: Dictionary = game.submit(plays[0])
				if not accepted.accepted or not game.answer_choices():
					failures.append("%s: rejected %s" % [card.id, str(accepted)])
				else:
					played[card.id] = true
					if rich:
						for effect: Dictionary in card.effects:
							if effect.trigger in ["cast", "battlecry"]:
								var found: bool = game.of_type("effect_resolved").any(func(event: Dictionary) -> bool: return event.payload.host_id == card.id and event.payload.trigger == effect.trigger)
								if not found:
									failures.append("%s: %s effect did not resolve" % [card.id, effect.trigger])
				# Trigger the printed Deathrattle, then both sides' turn events.
				if card.type == "minion" and card.keywords.has("deathrattle"):
					for minion: Dictionary in game.engine.state().players[side].board.duplicate():
						if minion.def_id == card.id:
							var entity: int = int(minion.entity_id)
							game.engine.run_action(func() -> void: game.engine.destroy(entity))
				for _turn: int in 2:
					if not game.answer_choices() or game.engine.phase() == MatchState.PHASE_ENDED:
						break
					var ended: Dictionary = game.submit(MatchRecords.end_turn(str(game.engine.active_side())))
					if not ended.accepted:
						failures.append("%s: turn rejected" % card.id)
				var trouble: String = _trouble(game)
				if not trouble.is_empty():
					failures.append("%s: %s" % [card.id, trouble])
			game.finish()
	assert_int(played.size()).is_equal(138)
	assert_array(failures).is_empty()


func test_all_138_authored_cards_play_for_each_of_their_classes() -> void:
	_sweep(PLAYER)


func test_all_138_authored_cards_play_for_the_enemy_with_both_prey_states() -> void:
	_sweep(BOSS)


func test_each_class_has_two_distinct_legendary_plans_and_real_nonlegendary_enablers() -> void:
	var metadata: Dictionary = _db.config(COLLECTION + "/collection").card_metadata
	for cls: String in ["war", "decay", "knowledge", "fortune", "order", "shadow"]:
		var legends: Array = _cards().filter(func(c: Dictionary) -> bool: return c.set == cls and c.rarity == "legendary")
		assert_int(legends.size()).is_equal(2)
		assert_str(str(metadata[legends[0].id].playstyle)).is_not_equal(str(metadata[legends[1].id].playstyle))
		for legend: Dictionary in legends:
			assert_int(metadata[legend.id].enablers.size()).is_greater_equal(2)
			for id: String in metadata[legend.id].enablers:
				assert_str(str(_db.card(id).rarity)).is_not_equal("legendary")
				assert_str(str(_db.card(id).set)).is_equal(cls)
	assert_int(_cards().filter(func(c: Dictionary) -> bool: return c.set == "neutral" and c.rarity == "legendary").size()).is_equal(0)


func test_package_engines_keep_generating_resources_or_board_value_on_later_turns() -> void:
	var examples: Dictionary = {
		"war_jungle_canopy_challenger": "on_attack",
		"decay_jungle_root_feaster": "on_minion_died",
		"knowledge_jungle_fossil_reader": "after_cast",
		"fortune_jungle_amber_appraiser": "on_minion_died",
		"shadow_jungle_shade_raptor": "on_attack",
	}
	for id: String in examples:
		var card: Dictionary = _db.card(id)
		var game: ShippedMatch = _game(card, PLAYER, false)
		game.set_hand(PLAYER, [])
		var source: int = game.summon(PLAYER, id)
		game.summon(PLAYER, "neutral_jungle_seedling_keeper")
		var since: int = game.last_seq()
		for _round: int in 2:
			if examples[id] == "on_attack":
				var attacks: Array = game.engine.legal_commands().filter(func(c: Dictionary) -> bool: return c.type == MatchRecords.CMD_ATTACK and c.attacker_id == source)
				assert_array(attacks).is_not_empty()
				if not attacks.is_empty():
					assert_bool(game.submit(attacks[0]).accepted).is_true()
			elif examples[id] == "on_minion_died":
				var prey_id: String = "neutral_jungle_seedling" if card.set == "decay" else "neutral_jungle_hatchling"
				var victim: int = game.summon(PLAYER, prey_id)
				game.engine.run_action(func() -> void: game.engine.destroy(victim))
			else:
				game.set_hand(PLAYER, ["neutral_jungle_scattered_seeds"])
				assert_bool(game.submit(MatchRecords.play_card(PLAYER, 0)).accepted).is_true()
			game.submit(MatchRecords.end_turn(PLAYER))
			game.submit(MatchRecords.end_turn(BOSS))
		var triggers: Array = game.of_type("effect_resolved", since).filter(func(e: Dictionary) -> bool: return e.payload.host_id == id and e.payload.trigger == examples[id])
		assert_int(triggers.size()).override_failure_message(id).is_equal(2)
		assert_str(_trouble(game)).is_empty()
		game.finish()


func test_both_actual_boss_decks_enable_predator_and_absent_prey_keeps_baselines() -> void:
	for boss_id: String in ["boss_briarjaw", "boss_veyra"]:
		var definition: Dictionary = _db.boss(boss_id)
		var predator_id: String = "neutral_jungle_canopy_stalker" if boss_id == "boss_briarjaw" else "neutral_jungle_reed_ambusher"
		var prey_id: String = "neutral_jungle_seedling_keeper" if boss_id == "boss_briarjaw" else "neutral_jungle_fern_hopper"
		assert_array(definition.deck).contains([predator_id, prey_id])
		for prey_side: String in ["none", PLAYER, BOSS]:
			var game := ShippedMatch.new(_db, "hero_order", boss_id, 19, [], definition.deck, COLLECTION)
			game.to_boss_main()
			# The real passive supplies prey; remove it for the explicit absent case.
			for minion: Dictionary in game.engine.state().players[BOSS].board.duplicate():
				var entity: int = int(minion.entity_id)
				game.engine.run_action(func() -> void: game.engine.destroy(entity))
			if prey_side != "none":
				game.summon(prey_side, prey_id)
			game.set_hand(BOSS, [predator_id])
			var since: int = game.last_seq()
			assert_bool(game.submit(MatchRecords.play_card(BOSS, 0, game.engine.state().players[BOSS].board.size())).accepted).is_true()
			var pred: Array = game.of_type("effect_resolved", since).filter(func(e: Dictionary) -> bool: return e.payload.get("predator") is Dictionary)
			assert_int(pred.size()).is_equal(0 if prey_side == "none" else 1)
			var unit: Dictionary = game.engine.state().players[BOSS].board.back()
			var base: int = int(_db.card(predator_id).attack)
			assert_int(game.engine.attack(unit)).is_equal(base + (0 if prey_side == "none" else 1))
			assert_str(_trouble(game)).is_empty()
			game.finish()


func _item_game(ids: Array) -> ShippedMatch:
	var game := ShippedMatch.new(_db, "hero_order", "boss_cellar_hermit", 42, [], [], COLLECTION)
	game.engine.end_match()
	game.log = EventLog.new(EventLog.max_events_for(_db.config("rng_event_log")), EventLog.SCOPE_MATCH)
	var config: Dictionary = ShippedMatch.match_config(_db, "hero_order", "boss_cellar_hermit", game.log)
	var treasures := Treasures.new(_db, _db.config("treasures_balance"))
	config.player.hook_installers = treasures.installers_for(ids, {})
	game.engine = RulesEngine.new(_db, _db.config("match_rules"), EffectResolver.new(_db, _db.config("card_effects"), "order", COLLECTION))
	game.engine.start(config)
	assert_bool(game.submit(game.engine.legal_commands()[0]).accepted).is_true()
	return game


func test_veyra_replenishes_missing_prey_without_an_unbounded_extra_swarm() -> void:
	var game := ShippedMatch.new(_db, "hero_order", "boss_veyra", 42, [], [], COLLECTION)
	game.to_boss_main()
	var beast: int = game.summon(BOSS, "neutral_jungle_fern_hopper")
	assert_bool(game.submit(MatchRecords.end_turn(BOSS)).accepted).is_true()
	assert_int(game.engine.state().players[BOSS].board.size()).is_equal(1)
	game.engine.run_action(func() -> void: game.engine.destroy(beast))
	assert_bool(game.submit(MatchRecords.end_turn(PLAYER)).accepted).is_true()
	assert_bool(game.submit(MatchRecords.end_turn(BOSS)).accepted).is_true()
	assert_int(game.engine.state().players[BOSS].board.size()).is_equal(1)
	assert_str(game.engine.state().players[BOSS].board[0].def_id).is_equal("neutral_jungle_hatchling")
	game.finish()


func test_compass_enables_friendly_predator_without_enemy_prey_and_deduplicates() -> void:
	var game: ShippedMatch = _item_game([COMPASS, COMPASS])
	assert_int(game.engine.state().players[PLAYER].board.size()).is_equal(1)
	assert_str(str(game.engine.state().players[PLAYER].board[0].def_id)).is_equal("neutral_jungle_seedling")
	assert_int(game.engine.state().players[PLAYER].hand.filter(func(c: Dictionary) -> bool: return c.def_id == "neutral_jungle_hatchling").size()).is_equal(1)
	game.set_hand(PLAYER, ["neutral_jungle_canopy_stalker"])
	var since: int = game.last_seq()
	assert_bool(game.submit(MatchRecords.play_card(PLAYER, 0, 1)).accepted).is_true()
	assert_int(game.of_type("effect_resolved", since).filter(func(e: Dictionary) -> bool: return e.payload.get("predator") is Dictionary).size()).is_equal(1)
	# No recurring summon or Predator-specific hidden trigger.
	assert_bool(game.submit(MatchRecords.end_turn(PLAYER)).accepted).is_true()
	assert_bool(game.submit(MatchRecords.end_turn(BOSS)).accepted).is_true()
	assert_int(game.engine.state().players[PLAYER].board.size()).is_equal(2)
	game.finish()


func test_compass_with_enemy_prey_still_grants_only_one_predator_bonus() -> void:
	var game: ShippedMatch = _item_game([COMPASS])
	game.summon(BOSS, "neutral_jungle_seedling_keeper")
	game.set_hand(PLAYER, ["neutral_jungle_canopy_stalker"])
	var since: int = game.last_seq()
	game.submit(MatchRecords.play_card(PLAYER, 0, 1))
	var unit: Dictionary = game.engine.state().players[PLAYER].board.back()
	assert_int(game.engine.attack(unit)).is_equal(4)
	assert_int(game.of_type("effect_resolved", since).filter(func(e: Dictionary) -> bool: return e.payload.get("predator") is Dictionary).size()).is_equal(1)
	game.finish()


func test_removing_compass_prey_turns_off_its_predator_enabling() -> void:
	var game: ShippedMatch = _item_game([COMPASS])
	var entity: int = int(game.engine.state().players[PLAYER].board[0].entity_id)
	game.engine.run_action(func() -> void: game.engine.destroy(entity))
	game.set_hand(PLAYER, ["neutral_jungle_canopy_stalker"])
	game.submit(MatchRecords.play_card(PLAYER, 0, 0))
	assert_int(game.engine.attack(game.engine.state().players[PLAYER].board[0])).is_equal(3)
	game.finish()


func test_each_actual_boss_passive_supplies_prey_on_a_window_the_player_can_deny() -> void:
	for boss_id: String in ["boss_briarjaw", "boss_veyra"]:
		var definition: Dictionary = _db.boss(boss_id)
		var game := ShippedMatch.new(_db, "hero_order", boss_id, 19, [], definition.deck, COLLECTION)
		game.to_boss_main()
		assert_int(game.engine.state().players[BOSS].board.size()).is_equal(0)
		game.submit(MatchRecords.end_turn(BOSS))
		assert_int(game.engine.state().players[BOSS].board.size()).is_equal(1)
		var entity: int = int(game.engine.state().players[BOSS].board[0].entity_id)
		game.engine.run_action(func() -> void: game.engine.destroy(entity))
		game.submit(MatchRecords.end_turn(PLAYER))
		assert_int(game.engine.state().players[BOSS].board.size()).is_equal(0)
		game.finish()


func test_watchglass_requires_two_unspent_mana_and_owner_end_turn_without_predator() -> void:
	for unspent: int in [0, 1, 2, 10]:
		var game: ShippedMatch = _item_game([WATCHGLASS, WATCHGLASS])
		game.engine.state().players[PLAYER].mana_current = unspent
		var before_armor: int = int(game.engine.state().players[PLAYER].hero.armor)
		game.submit(MatchRecords.end_turn(PLAYER))
		assert_int(int(game.engine.state().players[PLAYER].hero.armor) - before_armor).is_equal(2 if unspent >= 2 else 0)
		game.submit(MatchRecords.end_turn(BOSS))
		assert_int(int(game.engine.state().players[PLAYER].hero.armor) - before_armor).is_equal(2 if unspent >= 2 else 0)
		assert_int(game.engine.state().players[PLAYER].board.size()).is_equal(0)
		game.finish()


func test_ration_triggers_only_for_empty_hand_before_normal_draw_and_works_without_predator() -> void:
	for empty: bool in [true, false]:
		var game: ShippedMatch = _item_game([RATION, RATION])
		game.set_hand(PLAYER, [] if empty else ["neutral_tunnel_rat"])
		game.submit(MatchRecords.end_turn(PLAYER))
		var before_deck: int = game.engine.state().players[PLAYER].deck.size()
		game.submit(MatchRecords.end_turn(BOSS))
		assert_int(before_deck - game.engine.state().players[PLAYER].deck.size()).is_equal(2 if empty else 1)
		assert_int(game.engine.state().players[PLAYER].board.size()).is_equal(0)
		game.finish()
