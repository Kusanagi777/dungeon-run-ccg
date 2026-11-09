## The authored Midnight Masquerade collection: structure, every card played
## through the shipped engine, collection pools, run access and the unlock gate
## (design/expansions/midnight-masquerade.md).
extends GdUnitTestSuite

const COLLECTION: String = "midnight-masquerade"
const PLAYER: String = MatchRecords.SIDE_PLAYER
const BOSS: String = MatchRecords.SIDE_BOSS
const CLASSES: Array[String] = ["war", "decay", "knowledge", "fortune", "order", "shadow"]
const UNLOCK_KEY: String = "collection_midnight_masquerade"


class CollectionMeta:
	extends MetaStub
	var collection_open: bool = false

	func is_collection_unlocked(id: String) -> bool:
		return collection_open and id == COLLECTION


var _db: CardDatabase


func before() -> void:
	_db = ShippedMatch.database()
	assert_bool(_db.report().has_errors()).override_failure_message(_db.report().to_text()).is_false()


func _cards() -> Array:
	var result: Array = []
	for set_id: String in RecordSchemas.SETS:
		for card: Dictionary in _db.cards_by_set(set_id):
			if card.get("collection_id") == COLLECTION and not card.get("token", false):
				result.append(card)
	return result


func _true_forms(card: Dictionary) -> Array[String]:
	var found: Array[String] = []
	var text: String = JSON.stringify(card.effects)
	for part: String in text.split("\"card_id\":\"").slice(1):
		found.append(part.get_slice("\"", 0))
	return found


func _masked(cards: Array) -> Array:
	return cards.filter(func(c: Dictionary) -> bool: return (c.tags as Array).has("masked"))


# --- Structure ----------------------------------------------------------------------------

func test_collection_has_48_collectibles_with_a_37_percent_neutral_share() -> void:
	var cards: Array = _cards()
	assert_int(cards.size()).is_equal(48)
	var neutral: int = cards.filter(func(c: Dictionary) -> bool: return c.set == "neutral").size()
	assert_int(neutral).is_equal(18)
	for cls: String in CLASSES:
		assert_int(cards.filter(func(c: Dictionary) -> bool: return c.set == cls).size()).is_equal(5)


func test_each_class_has_two_legendaries_with_different_playstyles_and_no_neutral_legendary() -> void:
	var metadata: Dictionary = _db.config(COLLECTION + "/collection").card_metadata
	for cls: String in CLASSES:
		var legends: Array = _cards().filter(func(c: Dictionary) -> bool: return c.set == cls and c.rarity == "legendary")
		assert_int(legends.size()).is_equal(2)
		assert_str(str(metadata[legends[0].id].playstyle)).is_not_equal(str(metadata[legends[1].id].playstyle))
		for legend: Dictionary in legends:
			assert_int(metadata[legend.id].enablers.size()).is_greater_equal(2)
			for id: String in metadata[legend.id].enablers:
				assert_str(str(_db.card(id).rarity)).is_not_equal("legendary")
				assert_bool(str(_db.card(id).set) in [cls, "neutral"]).is_true()
	assert_int(_cards().filter(func(c: Dictionary) -> bool: return c.set == "neutral" and c.rarity == "legendary").size()).is_equal(0)


func test_masks_reveal_both_stronger_and_weaker_true_forms() -> void:
	var up: int = 0
	var down: int = 0
	for card: Dictionary in _masked(_cards()):
		var forms: Array[String] = _true_forms(card)
		assert_array(forms).is_not_empty()
		for id: String in forms:
			var form: Dictionary = _db.card(id)
			assert_bool(bool(form.get("token", false))).override_failure_message(id + " is collectible").is_true()
			if int(form.attack) + int(form.health) > int(card.attack) + int(card.health):
				up += 1
			else:
				down += 1
	assert_int(up).is_greater_equal(5)
	assert_int(down).is_greater_equal(5)


func test_poisonous_and_lifesteal_each_get_at_least_two_support_cards() -> void:
	var metadata: Dictionary = _db.config(COLLECTION + "/collection").card_metadata
	for package: String in ["support_poisonous", "support_lifesteal"]:
		var n: int = metadata.keys().filter(func(id: String) -> bool: return metadata[id].package == package).size()
		assert_int(n).override_failure_message(package).is_greater_equal(2)


func test_two_bosses_with_full_decks_of_real_cards_that_include_masks() -> void:
	var bosses: Array = []
	for band: int in [1, 2, 3]:
		bosses += _db.bosses_in_band(band, COLLECTION).filter(func(b: Dictionary) -> bool: return b.get("collection_id") == COLLECTION)
	assert_int(bosses.size()).is_equal(2)
	for boss: Dictionary in bosses:
		assert_int(boss.deck.size()).is_equal(30)
		var masks: int = 0
		for id: String in boss.deck:
			assert_bool(_db.has(id)).is_true()
			if (_db.card(id).tags as Array).has("masked"):
				masks += 1
		assert_int(masks).is_greater_equal(8)


func test_run_items_form_two_distinct_groups_of_two() -> void:
	var groups: Dictionary = _db.config(COLLECTION + "/collection").item_groups
	assert_int(groups.mechanic_support.size()).is_equal(2)
	assert_int(groups.gap_fill.size()).is_equal(2)
	for id: String in groups.mechanic_support:
		assert_bool(groups.gap_fill.has(id)).is_false()
	for id: String in groups.mechanic_support + groups.gap_fill:
		assert_object(_db.treasure(id)).is_not_null()


# --- Every card plays -----------------------------------------------------------------------

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
			var hero: String = "hero_" + (str(card.set) if card.set != "neutral" else "war")
			var game := ShippedMatch.new(_db, hero, "boss_cellar_hermit", 42, [], [], COLLECTION)
			if side == PLAYER:
				game.to_player_main()
			else:
				game.to_boss_main()
			var other: String = BOSS if side == PLAYER else PLAYER
			if rich:
				for id: String in ["neutral_masq_masked_reveler", "neutral_masq_borrowed_finery", "neutral_dungeon_delver"]:
					game.summon(side, id)
					game.summon(other, id)
			game.set_hand(side, [card.id])
			var plays: Array = game.engine.legal_commands().filter(func(c: Dictionary) -> bool: return c.type == MatchRecords.CMD_PLAY_CARD)
			if rich and plays.is_empty():
				failures.append("%s: no legal rich-board play" % card.id)
			if not plays.is_empty():
				var accepted: Dictionary = game.submit(plays[0])
				if not accepted.accepted or not game.answer_choices():
					failures.append("%s: rejected %s" % [card.id, str(accepted)])
				else:
					played[card.id] = true
				for minion: Dictionary in game.engine.state().players[side].board.duplicate():
					if minion.def_id == card.id and (card.keywords as Array).has("deathrattle"):
						var entity: int = int(minion.entity_id)
						game.engine.run_action(func() -> void: game.engine.destroy(entity))
				for _turn: int in 2:
					if not game.answer_choices() or game.engine.phase() == MatchState.PHASE_ENDED:
						break
					if not game.submit(MatchRecords.end_turn(str(game.engine.active_side()))).accepted:
						failures.append("%s: turn rejected" % card.id)
				var trouble: String = _trouble(game)
				if not trouble.is_empty():
					failures.append("%s: %s" % [card.id, trouble])
			game.finish()
	assert_int(played.size()).is_equal(48)
	assert_array(failures).is_empty()


func test_all_48_cards_play_for_the_player_on_bare_and_crowded_boards() -> void:
	_sweep(PLAYER)


func test_all_48_cards_play_for_the_enemy_on_bare_and_crowded_boards() -> void:
	_sweep(BOSS)


# --- Collection pools and run access -------------------------------------------------------

func _machine(meta: MetaApi) -> RunMachine:
	var treasures: Treasures = Treasures.new(_db, _db.config("treasures_balance"))
	var draft: RewardDraft = RewardDraft.new(_db, treasures, meta, _db.config("reward_draft"))
	var config: Dictionary = _db.config("run_structure").duplicate(true)
	config["max_match_events"] = 10000
	config["engine_version"] = "masquerade-test"
	return RunMachine.new(_db, meta, draft, treasures, config, func(_config: Dictionary) -> MatchDriver: return null)


func test_collection_loads_without_a_trial_file() -> void:
	assert_object(_db.collection(COLLECTION)).is_not_null()
	assert_str(str(_db.config(COLLECTION + "/collection").get("trial_id", ""))).is_empty()
	assert_bool(FileAccess.file_exists("res://assets/data/%s/trial.json" % COLLECTION)).is_false()


func test_featured_pools_add_the_collection_only_when_selected() -> void:
	for cls: String in CLASSES:
		var core: Array = _db.collectible_pool(cls)
		var featured: Array = _db.collectible_pool(cls, COLLECTION)
		assert_int(featured.size() - core.size()).is_equal(23)
		assert_int(_db.bundle_pool(cls, COLLECTION).size() - _db.bundle_pool(cls).size()).is_equal(6)
	assert_int(_db.treasure_pool(COLLECTION).size() - _db.treasure_pool().size()).is_equal(4)
	assert_int(_db.bosses_in_band(1, COLLECTION).size() - _db.bosses_in_band(1).size()).is_equal(1)
	assert_int(_db.bosses_in_band(2, COLLECTION).size() - _db.bosses_in_band(2).size()).is_equal(1)
	assert_array(_db.collectible_pool("war", "law-of-the-jungle").filter(func(c: Dictionary) -> bool: return c.get("collection_id") == COLLECTION)).is_empty()


func test_locked_collection_cannot_start_a_run() -> void:
	var meta: CollectionMeta = CollectionMeta.new(_db)
	var machine: RunMachine = _machine(meta)
	assert_int(machine.new_run("hero_war", "seed", "", COLLECTION)).is_equal(RunCodes.E_COLLECTION_LOCKED)
	assert_object(meta.load_active_run()).is_null()


func test_unlocked_collection_run_saves_its_choice_and_resumes() -> void:
	var meta: CollectionMeta = CollectionMeta.new(_db)
	meta.collection_open = true
	var machine: RunMachine = _machine(meta)
	assert_int(machine.new_run("hero_order", "seed", "", COLLECTION)).is_equal(OK)
	assert_str(str(meta.load_active_run().featured_collection_id)).is_equal(COLLECTION)
	var resumed: RunMachine = _machine(meta)
	assert_int(resumed.resume()).is_equal(OK)
	assert_str(resumed.state.featured_collection_id).is_equal(COLLECTION)
	assert_array(resumed.state.boss_sequence).is_equal(machine.state.boss_sequence)


# --- Unlock gate ----------------------------------------------------------------------------

func _evaluator() -> UnlockEvaluator:
	return UnlockEvaluator.new(_db, ProfileFixtures.knobs())


func _stats(wins: int, sage_defeats: int) -> Dictionary:
	var stats: Dictionary = ProfileFixtures.profile_dict().stats.duplicate(true)
	stats.runs_won = wins
	stats.bosses = {"boss_mirror_sage": {"defeated": sage_defeats}} if sage_defeats > 0 else {}
	return stats


func test_unlock_needs_three_wins_and_a_mirror_sage_defeat() -> void:
	var evaluator: UnlockEvaluator = _evaluator()
	assert_bool(evaluator.newly_met(_stats(3, 1), {}).has(UNLOCK_KEY)).is_true()
	assert_bool(evaluator.newly_met(_stats(2, 1), {}).has(UNLOCK_KEY)).is_false()
	assert_bool(evaluator.newly_met(_stats(10, 0), {}).has(UNLOCK_KEY)).is_false()


func test_unlock_requirements_reference_real_content() -> void:
	var metadata: Dictionary = _db.config(COLLECTION + "/collection").unlock_metadata
	assert_str(str(metadata.unlock_mode)).is_equal("all")
	assert_bool(metadata.has("retroactive")).is_true()
	assert_object(_db.boss("boss_mirror_sage")).is_not_null()
	assert_dict(_db.config(COLLECTION + "/unlock")).is_equal(metadata.unlock)
