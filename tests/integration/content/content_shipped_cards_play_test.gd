## Integration: every shipped card played through the real engine, so no record is valid
## only on paper (content CN-1; card-effects C5, C6; match-rules C2).
##
## Each play is its own match on [ShippedMatch], so one card's mess cannot hide another's.
## A card is played on a **rich** board (minions on both sides, one of each wounded, a
## weapon equipped) with every legal target, and on a **bare** one, where a card with no
## legal target is simply absent. After a play a Deathrattle host is destroyed and both
## sides end their turns, so turn triggers fire. An engine fault, a refused command, a
## printed play effect that logged nothing or an outcome outside the closed set fails the
## card, and the failure names it.
extends GdUnitTestSuite

const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const SIDE_BOSS: String = MatchRecords.SIDE_BOSS
## The hero whose set a card's Discover reads, per card set; `boss` cards use War's.
const HERO_OF_SET: Dictionary = {"war": "hero_war", "decay": "hero_decay", "knowledge": "hero_knowledge", "neutral": "hero_war"}
const HERO_DEFAULT: String = "hero_war"
const BOSS_SET: String = "boss"
## The one boss with no passive (content CN-3), so only the card's own effect runs.
const PLAIN_BOSS: String = "boss_cellar_hermit"
## Collectibles in the four sets swept below, including the five new archetypes.
const COLLECTIBLE_COUNT: int = 225
const ARCHETYPE_SETS: Dictionary = {"berserk": "war", "plague": "decay", "frost": "knowledge", "pack": "neutral", "salvage": "neutral"}
## Sturdy enough to carry a wound.
const BOARD_MINION: String = "neutral_dungeon_delver"
## A rich board's friendly Deathrattle, so Last Rites has a target.
const BOARD_RATTLE: String = "decay_carrion_crow"
const BOARD_WEAPON: String = "war_rusted_axe"
const EVENT_EFFECT: String = "effect_resolved"
const PLAY_TRIGGERS: Array[String] = ["cast", "battlecry"]
const BANDS: Array[int] = [1, 2, 3]
const WOUND: int = 1
const BOARD_SIZE: int = 2

var _db: CardDatabase = null


func before() -> void:
	_db = ShippedMatch.database()


func after() -> void:
	_db = null


func test_every_shipped_unit_and_spell_has_printed_taxonomy() -> void:
	for set_id: String in RecordSchemas.SETS:
		for card: Dictionary in _db.cards_by_set(set_id):
			if card.type == "weapon":
				assert_bool(card.has("tribes") or card.has("schools")).is_false()
				continue
			var field: String = "tribes" if card.type == "minion" else "schools"
			assert_array(card.get(field, [])).override_failure_message(card.id).is_not_empty()


func test_taxonomy_filters_read_printed_identity_and_support_dual_tags() -> void:
	var resolver := EffectResolver.new(_db, _db.config("card_effects"))
	var unit: Dictionary = {"def_id": "knowledge_shard_warden", "silenced": true}
	for tribe: String in ["construct", "elemental"]:
		assert_bool(EffectSelectors.matches(resolver, unit, {"tribe": tribe}, SIDE_PLAYER, -1)).is_true()
	assert_bool(EffectSelectors.matches(resolver, unit, {"tribe": "human"}, SIDE_PLAYER, -1)).is_false()
	unit.def_id = "neutral_sheep"
	assert_bool(EffectSelectors.matches(resolver, unit, {"tribe": "construct"}, SIDE_PLAYER, -1)).is_false()
	assert_bool(EffectSelectors.matches(resolver, unit, {"tribe": "beast"}, SIDE_PLAYER, -1)).is_true()
	for school: String in ["arcane", "frost"]:
		assert_bool(EffectSelectors.matches(resolver, {"def_id": "knowledge_cold_storage"}, {"school": school}, SIDE_PLAYER, -1)).is_true()
	assert_bool(EffectSelectors.matches(resolver, {"def_id": "knowledge_cold_storage"}, {"school": "fire"}, SIDE_PLAYER, -1)).is_false()
	assert_bool(EffectSelectors.matches(resolver, {}, {"tribe": "human"}, SIDE_PLAYER, -1)).is_false()


## The cards of [param set_id] that a side can hold.
func _playable(set_id: String) -> Array:
	return _db.cards_by_set(set_id).filter(func(card: Dictionary) -> bool: return card.get("token", false) != true and not card.has("collection_id"))


func _rich(game: ShippedMatch, side: String) -> void:
	var other: String = SIDE_BOSS if side == SIDE_PLAYER else SIDE_PLAYER
	for owner: String in [side, other]:
		for _i: int in BOARD_SIZE:
			@warning_ignore("return_value_discarded")
			game.summon(owner, BOARD_MINION)
		var board: Array = game.engine.state().players[owner].board
		(board[0] as Dictionary).damage_taken = WOUND
		var frozen: int = int((board[1] as Dictionary).entity_id)
		game.engine.run_action(func() -> void: game.engine.freeze(frozen))
	@warning_ignore("return_value_discarded")
	game.summon(side, BOARD_RATTLE)
	game.engine.run_action(func() -> void: game.engine.equip_weapon(side, BOARD_WEAPON))


func _match(card: Dictionary, side: String, rich: bool) -> ShippedMatch:
	var game := ShippedMatch.new(_db, str(HERO_OF_SET.get(str(card.set), HERO_DEFAULT)), PLAIN_BOSS)
	if side == SIDE_PLAYER:
		game.to_player_main()
	else:
		game.to_boss_main()
	if rich:
		_rich(game, side)
	game.set_hand(side, [card.id])
	return game


## The play commands of the hand card, one per distinct target.
func _plays(game: ShippedMatch) -> Array:
	var seen: Dictionary = {}
	var plays: Array = []
	for command: Dictionary in game.engine.legal_commands():
		if str(command.type) == MatchRecords.CMD_PLAY_CARD and not seen.has(str(command.target_id)):
			seen[str(command.target_id)] = true
			plays.append(command)
	return plays


## What the log says went wrong, or `""`.
func _trouble(game: ShippedMatch) -> String:
	for event: Dictionary in game.events_after(0):
		if str(event.type) == "log_overflow":
			return "log_overflow"
		if str(event.type) == "match_ended" and str(event.payload.get("result")) == "fault":
			return "fault %s" % str(event.payload)
		if str(event.type) == EVENT_EFFECT:
			for op: Dictionary in event.payload.ops:
				if not EffectOps.OUTCOMES.has(str(op.outcome)):
					return "outcome %s" % str(op)
	return ""


func _ended(game: ShippedMatch) -> bool:
	return game.engine.phase() == MatchState.PHASE_ENDED


## Each side ends its turn, answering any Choice.
func _pass_turns(game: ShippedMatch) -> String:
	for _i: int in MatchRecords.SIDES.size():
		if not game.answer_choices():
			return "a Choice was refused"
		if _ended(game):
			return ""
		var result: Dictionary = game.submit(MatchRecords.end_turn(str(game.engine.active_side())))
		if not result.accepted:
			return "end_turn refused: %s" % str(result)
	return "" if game.answer_choices() else "a Choice was refused"


## A printed `cast` or `battlecry` that logged no `effect_resolved` did not run. A
## Battlecry on `chosen` played with no target has nothing to run (match-rules C2).
func _unresolved_play_effects(game: ShippedMatch, card: Dictionary, since: int, target: Variant) -> String:
	var wanted: int = 0
	for effect: Dictionary in card.get("effects", []):
		var targets: Variant = effect.get("targets")
		var chosen: bool = targets is Dictionary and str(targets.get("selector")) == "chosen"
		if PLAY_TRIGGERS.has(str(effect.trigger)) and (target != null or not chosen):
			wanted += 1
	var ran: int = 0
	for event: Dictionary in game.of_type(EVENT_EFFECT, since):
		if str(event.payload.host_id) == str(card.id) and PLAY_TRIGGERS.has(str(event.payload.trigger)):
			ran += 1
	return "" if ran >= wanted else "%d play effects logged of %d" % [ran, wanted]


## Destroys the played minion if it printed a Deathrattle, and asks that the effect ran.
func _destroy_rattle_host(game: ShippedMatch, card: Dictionary) -> String:
	var rattles: bool = (card.get("effects", []) as Array).any(func(e: Dictionary) -> bool: return str(e.trigger) == "deathrattle")
	if not rattles or str(card.type) != "minion" or _ended(game):
		return ""
	for side: String in MatchRecords.SIDES:
		for minion: Dictionary in game.engine.state().players[side].board:
			if str(minion.def_id) == str(card.id):
				var since: int = game.last_seq()
				var id: int = int(minion.entity_id)
				game.engine.run_action(func() -> void: game.engine.destroy(id))
				if not game.answer_choices():
					return "a Deathrattle Choice was refused"
				var ran: bool = game.of_type(EVENT_EFFECT, since).any(func(e: Dictionary) -> bool: return str(e.payload.host_id) == str(card.id) and str(e.payload.trigger) == "deathrattle")
				return "" if ran else "the Deathrattle logged nothing"
	return ""


## Plays the [param index]th legal command on a fresh match and walks on from it: `""`,
## or what went wrong.
func _run_play(card: Dictionary, side: String, rich: bool, index: int) -> String:
	var game: ShippedMatch = _match(card, side, rich)
	var command: Dictionary = _plays(game)[index]
	var since: int = game.last_seq()
	var result: Dictionary = game.submit(command)
	var trouble: String = "" if result.accepted else "refused: %s" % str(result)
	if trouble.is_empty() and not game.answer_choices():
		trouble = "a Choice was refused"
	if trouble.is_empty():
		trouble = _unresolved_play_effects(game, card, since, command.target_id)
	if trouble.is_empty():
		trouble = _destroy_rattle_host(game, card)
	if trouble.is_empty():
		trouble = _pass_turns(game)
	if trouble.is_empty():
		trouble = _trouble(game)
	game.finish()
	if trouble.is_empty():
		return ""
	return "%s %s target %s: %s" % [card.id, "rich" if rich else "bare", str(command.target_id), trouble]


## Every failure of the cards of [param set_id] played from [param side].
func _sweep(set_id: String, side: String) -> Array[String]:
	var failures: Array[String] = []
	for card: Dictionary in _playable(set_id):
		for rich: bool in [true, false]:
			var probe: ShippedMatch = _match(card, side, rich)
			var plays: int = _plays(probe).size()
			probe.finish()
			if plays == 0 and rich:
				failures.append("%s: no legal play on a rich board" % card.id)
			for index: int in plays:
				var failure: String = _run_play(card, side, rich, index)
				if not failure.is_empty():
					failures.append(failure)
	return failures


func test_the_sweep_reaches_every_collectible_card_in_its_sets() -> void:
	# Act
	var total: int = 0
	for set_id: String in HERO_OF_SET:
		total += _playable(set_id).size()

	# Assert — a pool that shrank would make the sweeps below prove less
	assert_int(total).is_equal(COLLECTIBLE_COUNT)


func test_each_new_archetype_can_fill_every_bundle_slot_of_a_run() -> void:
	var draft_rounds: int = int(_db.config("run_structure").floors_per_run) - 1
	var plan_tags: Dictionary = _db.config("heroes_balance").plan_tags
	for theme: String in ARCHETYPE_SETS:
		var set_id: String = ARCHETYPE_SETS[theme]
		var cards: Array = _playable(set_id).filter(func(card: Dictionary) -> bool: return card.tags.has(theme))
		assert_int(cards.size()).override_failure_message(theme).is_equal(3 * draft_rounds)
		for type: String in ["minion", "spell"]:
			var finishers: Array = cards.filter(func(card: Dictionary) -> bool: return card.type == type and card.rarity == "legendary")
			assert_int(finishers.size()).override_failure_message("%s / %s finisher" % [theme, type]).is_equal(1)
		var card_ids: Array = cards.map(func(card: Dictionary) -> String: return str(card.id))
		for card_id: String in card_ids:
			assert_bool(ArtLibrary.shared().card_stamp(card_id).is_empty()).override_failure_message(card_id).is_false()
		for hero: Dictionary in _db.heroes():
			var bundles: Array = _db.bundle_pool(str(hero.set)).filter(func(bundle: Dictionary) -> bool: return bundle.theme == theme)
			var eligible: bool = set_id == "neutral" or set_id == str(hero.set)
			assert_int(bundles.size()).override_failure_message("%s / %s" % [hero.id, theme]).is_equal(draft_rounds if eligible else 0)
			if eligible:
				assert_array(plan_tags[hero.set]).contains([theme])
				var bundled: Array = []
				for bundle: Dictionary in bundles:
					bundled.append_array(bundle.cards)
				assert_array(bundled).contains_exactly_in_any_order(card_ids)


func _finisher_match(hero: String, boss_health: int) -> ShippedMatch:
	var game := ShippedMatch.new(_db, hero, PLAIN_BOSS)
	game.to_player_main()
	var health: int = game.engine.health(game.engine.state().players[SIDE_BOSS].hero)
	game.engine.run_action(func() -> void: game.engine.apply_damage(game.hero_id(SIDE_BOSS), health - boss_health, null))
	return game


func _assert_player_won(game: ShippedMatch) -> void:
	var ends: Array[Dictionary] = game.of_type("match_ended")
	assert_array(ends.map(func(event: Dictionary) -> String: return str(event.payload.winner))).is_equal([SIDE_PLAYER])
	game.finish()


func test_berserk_finishes_with_a_wounded_minion_attacking_twice() -> void:
	var game: ShippedMatch = _finisher_match("hero_war", 14)
	var fighter: int = game.summon(SIDE_PLAYER, BOARD_MINION)
	@warning_ignore("return_value_discarded")
	game.summon(SIDE_PLAYER, "war_pit_tyrant")
	game.engine.run_action(func() -> void: game.engine.apply_damage(fighter, 1, null))
	game.set_hand(SIDE_PLAYER, ["war_red_reckoning"])
	assert_bool(game.submit(MatchRecords.play_card(SIDE_PLAYER, 0)).accepted).is_true()
	for _hit: int in 2:
		assert_bool(game.submit(MatchRecords.attack(SIDE_PLAYER, fighter, game.hero_id(SIDE_BOSS))).accepted).is_true()
	_assert_player_won(game)


func test_plague_converts_enemy_minion_deaths_into_lethal_damage() -> void:
	var game: ShippedMatch = _finisher_match("hero_decay", 3)
	@warning_ignore("return_value_discarded")
	game.summon(SIDE_PLAYER, "decay_morbane")
	for _minion: int in 3:
		@warning_ignore("return_value_discarded")
		game.summon(SIDE_BOSS, "neutral_tunnel_rat")
	assert_bool(game.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()
	_assert_player_won(game)


func test_frost_turns_an_end_of_turn_freeze_into_lethal_damage() -> void:
	var game: ShippedMatch = _finisher_match("hero_knowledge", 4)
	@warning_ignore("return_value_discarded")
	game.summon(SIDE_PLAYER, "knowledge_rime_binder")
	@warning_ignore("return_value_discarded")
	game.summon(SIDE_PLAYER, "knowledge_ilyra")
	@warning_ignore("return_value_discarded")
	game.summon(SIDE_BOSS, BOARD_MINION)
	assert_bool(game.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()
	_assert_player_won(game)


func test_pack_overrun_counts_every_minion_toward_lethal() -> void:
	var game: ShippedMatch = _finisher_match("hero_order", 5)
	for _minion: int in 5:
		@warning_ignore("return_value_discarded")
		game.summon(SIDE_PLAYER, "neutral_burrow_pup")
	game.set_hand(SIDE_PLAYER, ["neutral_overrun"])
	assert_bool(game.submit(MatchRecords.play_card(SIDE_PLAYER, 0)).accepted).is_true()
	_assert_player_won(game)


func test_salvage_orla_turns_a_full_hand_into_lethal_damage() -> void:
	var game: ShippedMatch = _finisher_match("hero_shadow", 8)
	var hand: Array = ["neutral_orla"]
	for _card: int in 8:
		hand.append("neutral_tunnel_rat")
	game.set_hand(SIDE_PLAYER, hand)
	assert_bool(game.submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0)).accepted).is_true()
	_assert_player_won(game)


func test_every_war_card_plays_clean_from_the_players_side() -> void:
	# Act
	var failures: Array[String] = _sweep("war", SIDE_PLAYER)

	# Assert
	assert_array(failures).is_empty()


func test_every_decay_card_plays_clean_from_the_players_side() -> void:
	# Act
	var failures: Array[String] = _sweep("decay", SIDE_PLAYER)

	# Assert
	assert_array(failures).is_empty()


func test_every_knowledge_card_plays_clean_from_the_players_side() -> void:
	# Act
	var failures: Array[String] = _sweep("knowledge", SIDE_PLAYER)

	# Assert
	assert_array(failures).is_empty()


func test_every_neutral_card_plays_clean_from_the_players_side() -> void:
	# Act
	var failures: Array[String] = _sweep("neutral", SIDE_PLAYER)

	# Assert
	assert_array(failures).is_empty()


func test_every_boss_card_plays_clean_from_the_bosss_side() -> void:
	# Act
	var failures: Array[String] = _sweep(BOSS_SET, SIDE_BOSS)

	# Assert
	assert_array(failures).is_empty()


func test_every_boss_hero_power_runs_from_the_bosss_seat() -> void:
	# Arrange
	var failures: Array[String] = []
	for band: int in BANDS:
		for boss: Dictionary in _db.bosses_in_band(band):
			if boss.get("hero_power") == null:
				continue
			var game := ShippedMatch.new(_db, HERO_DEFAULT, str(boss.id))
			game.to_boss_main()
			_rich(game, SIDE_BOSS)
			game.set_hand(SIDE_BOSS, [])
			var powers: Array = game.engine.legal_commands().filter(func(c: Dictionary) -> bool: return str(c.type) == MatchRecords.CMD_USE_HERO_POWER)

			# Act
			if powers.is_empty():
				failures.append("%s: no legal %s" % [boss.id, boss.hero_power])
			else:
				var since: int = game.last_seq()
				var result: Dictionary = game.submit(powers[0])
				var ran: bool = game.of_type(EVENT_EFFECT, since).any(func(e: Dictionary) -> bool: return str(e.payload.host_id) == str(boss.hero_power))
				if not result.accepted or not ran:
					failures.append("%s: %s ran %s, %s" % [boss.id, boss.hero_power, ran, result])
			game.finish()

	# Assert
	assert_array(failures).is_empty()
