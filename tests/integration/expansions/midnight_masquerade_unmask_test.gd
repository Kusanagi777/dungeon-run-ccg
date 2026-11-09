## Unmask, the Midnight Masquerade bosses and run items, played through the shipped
## effect resolver and rules engine with the authored records
## (design/expansions/midnight-masquerade.md).
extends GdUnitTestSuite

const COLLECTION: String = "midnight-masquerade"
const PLAYER: String = MatchRecords.SIDE_PLAYER
const BOSS: String = MatchRecords.SIDE_BOSS
const REVELER: String = "neutral_masq_masked_reveler"
const UNVEILED: String = "neutral_masq_reveler_unveiled"
const FINERY: String = "neutral_masq_borrowed_finery"
const FOOTMAN: String = "neutral_masq_trembling_footman"
const DEBUTANTE: String = "order_masq_shielded_debutante"
const DUELIST: String = "neutral_masq_masked_duelist"
const DUELIST_REVEALED: String = "neutral_masq_duelist_revealed"
const GAMBLER: String = "fortune_masq_gamblers_mask"
const GAMBLER_FORMS: Array[String] = ["fortune_masq_gambler_heads", "fortune_masq_gambler_tails"]
const PAGE: String = "neutral_masq_candle_page"
const HOSTESS: String = "boss_masq_hostess"
const COUNT: String = "boss_masq_faceless_count"
const INVITATION: String = "treasure_masq_ballroom_invitation"
const BELL: String = "treasure_masq_hostess_bell"
const DANCE_CARD: String = "treasure_masq_dance_card"
const SALTS: String = "treasure_masq_smelling_salts"

var _db: CardDatabase


func before() -> void:
	_db = ShippedMatch.database()
	assert_bool(_db.report().has_errors()).override_failure_message(_db.report().to_text()).is_false()


func _game(seed_value: int = 42, boss_id: String = "boss_cellar_hermit", boss_deck: Array = []) -> ShippedMatch:
	return ShippedMatch.new(_db, "hero_war", boss_id, seed_value, [], boss_deck, COLLECTION)


func _hit(game: ShippedMatch, entity_id: int, amount: int) -> void:
	game.engine.run_action(func() -> void: game.engine.apply_damage(entity_id, amount, null))


func _board(game: ShippedMatch, side: String) -> Array:
	return game.engine.state().players[side].board.map(func(m: Dictionary) -> String: return str(m.def_id))


func _stats(game: ShippedMatch, side: String, index: int) -> Array:
	var minion: Dictionary = game.engine.state().players[side].board[index]
	return [game.engine.attack(minion), game.engine.health(minion)]


func _shielded(minion: Dictionary) -> bool:
	if (minion.keywords as Array).has(MatchRecords.KEYWORD_DIVINE_SHIELD):
		return true
	return (minion.enchantments as Array).any(func(e: Dictionary) -> bool: return (e.keywords_added as Array).has(MatchRecords.KEYWORD_DIVINE_SHIELD))


# --- The rule ---------------------------------------------------------------------------

func test_masked_minion_surviving_damage_unmasks_into_its_stronger_true_form() -> void:
	var game: ShippedMatch = _game()
	game.to_player_main()
	var id: int = game.summon(PLAYER, REVELER)
	_hit(game, id, 1)
	assert_array(_board(game, PLAYER)).is_equal([UNVEILED])
	assert_array(_stats(game, PLAYER, 0)).is_equal([4, 3])
	game.finish()


func test_masked_minion_can_unmask_into_a_weaker_true_form() -> void:
	var game: ShippedMatch = _game()
	game.to_player_main()
	var id: int = game.summon(PLAYER, FINERY)
	_hit(game, id, 1)
	assert_array(_board(game, PLAYER)).is_equal([FOOTMAN])
	assert_array(_stats(game, PLAYER, 0)).is_equal([1, 1])
	game.finish()


func test_lethal_damage_kills_the_mask_without_a_reveal() -> void:
	var game: ShippedMatch = _game()
	game.to_player_main()
	var id: int = game.summon(PLAYER, REVELER)
	_hit(game, id, 2)
	assert_array(_board(game, PLAYER)).is_empty()
	game.finish()


func test_silenced_mask_never_unmasks() -> void:
	var game: ShippedMatch = _game()
	game.to_player_main()
	var id: int = game.summon(PLAYER, FINERY)
	game.engine.run_action(func() -> void: game.engine.silence(id))
	_hit(game, id, 1)
	assert_array(_board(game, PLAYER)).is_equal([FINERY])
	game.finish()


func test_divine_shield_absorbs_the_hit_and_keeps_the_mask_on() -> void:
	var game: ShippedMatch = _game()
	game.to_player_main()
	var id: int = game.summon(PLAYER, DEBUTANTE)
	_hit(game, id, 1)
	assert_array(_board(game, PLAYER)).is_equal([DEBUTANTE])
	_hit(game, id, 1)
	assert_array(_board(game, PLAYER)).is_equal(["order_masq_debutante_revealed"])
	game.finish()


func test_a_true_form_never_unmasks_again() -> void:
	var game: ShippedMatch = _game()
	game.to_player_main()
	var id: int = game.summon(PLAYER, REVELER)
	_hit(game, id, 1)
	var revealed: int = int(game.engine.state().players[PLAYER].board[0].entity_id)
	_hit(game, revealed, 1)
	assert_array(_board(game, PLAYER)).is_equal([UNVEILED])
	assert_array(_stats(game, PLAYER, 0)).is_equal([4, 2])
	game.finish()


func test_unmask_keeps_the_board_position() -> void:
	var game: ShippedMatch = _game()
	game.to_player_main()
	game.summon(PLAYER, PAGE)
	var id: int = game.summon(PLAYER, REVELER)
	game.summon(PLAYER, PAGE)
	_hit(game, id, 1)
	assert_array(_board(game, PLAYER)).is_equal([PAGE, UNVEILED, PAGE])
	game.finish()


func test_enemy_masks_unmask_the_same_way() -> void:
	var game: ShippedMatch = _game()
	game.to_player_main()
	var id: int = game.summon(BOSS, FINERY)
	_hit(game, id, 1)
	assert_array(_board(game, BOSS)).is_equal([FOOTMAN])
	game.finish()


func test_combat_damage_unmasks_a_surviving_attacker() -> void:
	var game: ShippedMatch = _game()
	game.to_player_main()
	var attacker: int = game.summon(PLAYER, DUELIST)
	var defender: int = game.summon(BOSS, PAGE)
	assert_bool(game.submit(MatchRecords.attack(PLAYER, attacker, defender)).accepted).is_true()
	assert_array(_board(game, PLAYER)).is_equal([DUELIST_REVEALED])
	assert_array(_board(game, BOSS)).is_empty()
	game.finish()


func test_gamblers_mask_reveals_one_printed_form_and_replays_identically() -> void:
	var seen: Dictionary = {}
	for seed_value: int in [1, 2, 3, 4, 5, 6, 7, 8]:
		var forms: Array = []
		for _replay: int in 2:
			var game: ShippedMatch = _game(seed_value)
			game.to_player_main()
			var id: int = game.summon(PLAYER, GAMBLER)
			_hit(game, id, 1)
			forms.append(_board(game, PLAYER)[0])
			game.finish()
		assert_str(str(forms[0])).is_equal(str(forms[1]))
		assert_bool(GAMBLER_FORMS.has(str(forms[0]))).is_true()
		seen[forms[0]] = true
	assert_int(seen.size()).override_failure_message("eight seeds never produced both forms").is_equal(2)


# --- Bosses -------------------------------------------------------------------------------

func test_hostess_unmasks_one_of_her_own_masks_at_the_end_of_her_turn() -> void:
	var game: ShippedMatch = _game(19, HOSTESS, _db.boss(HOSTESS).deck)
	game.to_boss_main()
	game.summon(BOSS, REVELER)
	assert_bool(game.submit(MatchRecords.end_turn(BOSS)).accepted).is_true()
	assert_array(_board(game, BOSS)).is_equal([UNVEILED])
	game.finish()


func test_hostess_passive_does_nothing_without_a_masked_minion() -> void:
	var game: ShippedMatch = _game(19, HOSTESS, _db.boss(HOSTESS).deck)
	game.to_boss_main()
	game.summon(BOSS, PAGE)
	game.summon(PLAYER, REVELER)
	assert_bool(game.submit(MatchRecords.end_turn(BOSS)).accepted).is_true()
	assert_array(_board(game, BOSS)).is_equal([PAGE])
	assert_int(int(game.engine.state().players[BOSS].board[0].damage_taken)).is_equal(0)
	assert_array(_board(game, PLAYER)).is_equal([REVELER])
	game.finish()


func test_hostess_scenario_resolves_identically_on_replay() -> void:
	var runs: Array = []
	for _replay: int in 2:
		var game: ShippedMatch = _game(19, HOSTESS, _db.boss(HOSTESS).deck)
		game.to_boss_main()
		game.summon(BOSS, REVELER)
		game.summon(BOSS, FINERY)
		game.submit(MatchRecords.end_turn(BOSS))
		runs.append(game.events_after(0).map(func(e: Dictionary) -> String: return str(e.type) + str(e.get("payload", {}))))
		game.finish()
	assert_array(runs[0]).is_equal(runs[1])


func test_faceless_count_shields_an_unshielded_mask_at_the_start_of_its_turn() -> void:
	var game: ShippedMatch = _game(19, COUNT, _db.boss(COUNT).deck)
	game.to_player_main()
	var mask: int = game.summon(BOSS, FINERY)
	assert_bool(game.submit(MatchRecords.end_turn(PLAYER)).accepted).is_true()
	assert_bool(_shielded(game.minion_of(mask))).is_true()
	# Countered by popping the shield, then striking again: the weak true form appears.
	_hit(game, mask, 1)
	_hit(game, mask, 1)
	assert_array(_board(game, BOSS)).is_equal([FOOTMAN])
	game.finish()


func test_faceless_count_passive_does_nothing_without_a_masked_minion() -> void:
	var game: ShippedMatch = _game(19, COUNT, _db.boss(COUNT).deck)
	game.to_player_main()
	var page: int = game.summon(BOSS, PAGE)
	assert_bool(game.submit(MatchRecords.end_turn(PLAYER)).accepted).is_true()
	assert_bool(_shielded(game.minion_of(page))).is_false()
	game.finish()


# --- Run items ------------------------------------------------------------------------------

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


func test_invitation_starts_one_masked_reveler_in_play_even_when_duplicated() -> void:
	var game: ShippedMatch = _item_game([INVITATION, INVITATION])
	assert_array(_board(game, PLAYER)).is_equal([REVELER])
	game.finish()


func test_hand_bell_unmasks_a_friendly_mask_at_the_start_of_your_turn() -> void:
	var game: ShippedMatch = _item_game([BELL])
	game.summon(PLAYER, REVELER)
	game.submit(MatchRecords.end_turn(PLAYER))
	game.submit(MatchRecords.end_turn(BOSS))
	assert_array(_board(game, PLAYER)).is_equal([UNVEILED])
	game.finish()


func test_hand_bell_never_damages_an_unmasked_minion() -> void:
	var game: ShippedMatch = _item_game([BELL])
	game.summon(PLAYER, PAGE)
	game.submit(MatchRecords.end_turn(PLAYER))
	game.submit(MatchRecords.end_turn(BOSS))
	assert_int(int(game.engine.state().players[PLAYER].board[0].damage_taken)).is_equal(0)
	game.finish()


func test_dance_card_discovers_once_on_your_third_turn_without_masks() -> void:
	var game: ShippedMatch = _item_game([DANCE_CARD])
	var choices_by_turn: Array[int] = []
	for _turn: int in 4:
		var before_hand: int = game.engine.state().players[PLAYER].hand.size()
		game.submit(MatchRecords.end_turn(PLAYER))
		game.submit(MatchRecords.end_turn(BOSS))
		var pending: bool = game.engine.legal_commands().any(func(c: Dictionary) -> bool: return c.type == MatchRecords.CMD_CHOOSE)
		assert_bool(game.answer_choices()).is_true()
		choices_by_turn.append(game.engine.state().players[PLAYER].hand.size() - before_hand if pending else 0)
	# Player turns 2, 3, 4 and 5 start in this loop; only the third turn discovers.
	assert_array(choices_by_turn).is_equal([0, 2, 0, 0])
	game.finish()


func test_smelling_salts_heal_damaged_minions_at_the_end_of_your_turn() -> void:
	var game: ShippedMatch = _item_game([SALTS])
	var id: int = game.summon(PLAYER, "neutral_masq_velvet_usher")
	_hit(game, id, 3)
	game.submit(MatchRecords.end_turn(PLAYER))
	assert_int(int(game.minion_of(id).damage_taken)).is_equal(1)
	game.finish()


func test_unmasking_thaws_a_frozen_mask() -> void:
	var game: ShippedMatch = _game()
	game.to_player_main()
	var id: int = game.summon(PLAYER, REVELER)
	game.engine.run_action(func() -> void: game.engine.freeze(id))
	_hit(game, id, 1)
	var revealed: Dictionary = game.engine.state().players[PLAYER].board[0]
	assert_str(str(revealed.def_id)).is_equal(UNVEILED)
	# Transform makes a fresh minion, so the true form is not frozen.
	assert_bool(bool(revealed.frozen)).is_false()
	game.finish()
