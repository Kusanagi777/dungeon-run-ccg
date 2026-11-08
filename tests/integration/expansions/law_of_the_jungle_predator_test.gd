## Predator prototype contract from design/expansions/law-of-the-jungle.md.
## Inline cards exercise the real validator, selectors, resolver, and match engine;
## this does not validate the unbuilt expansion pool, bosses, items, or unlocks.
extends GdUnitTestSuite

const PLAYER: String = MatchRecords.SIDE_PLAYER
const BOSS: String = MatchRecords.SIDE_BOSS
const PREDATOR: String = "neutral_test_canopy_stalker"
const PLANT: String = "neutral_test_prey_plant"
const STEALTH_PLANT: String = "neutral_test_hidden_plant"
const MIXED_PREY: String = "neutral_test_mixed_prey"
const PLANT_PREDATOR: String = "neutral_test_plant_predator"


class PrototypeDatabase:

	extends CardDatabase

	var prototypes: Dictionary = {}

	func has(id: String) -> bool:
		return prototypes.has(id) or super.has(id)

	func card(id: String) -> Variant:
		return prototypes[id] if prototypes.has(id) else super.card(id)


var _db: PrototypeDatabase
var _game: ShippedMatch


func before_test() -> void:
	_db = PrototypeDatabase.new()
	var report: ValidationReport = _db.load(ContentValidateCommand.boot_validators(true))
	assert_bool(report.has_errors()).override_failure_message(report.to_text()).is_false()
	_db.prototypes[PREDATOR] = CardFactory.make_minion(PREDATOR, 3, 3, 3, ["battlecry"], {
		"tribes": ["beast"],
		"effects": [{
			"trigger": "battlecry",
			"condition": {"exists": {"selector": "all_minions", "filter": {"tribe": "plant", "not_self": true}}},
			"targets": "self",
			"ops": [{"op": "buff", "attack": 1, "health": 1}],
		}],
	})
	_db.prototypes[PLANT] = CardFactory.make_minion(PLANT, 1, 1, 1, [], {"tribes": ["plant"], "token": true})
	_db.prototypes[STEALTH_PLANT] = CardFactory.make_minion(STEALTH_PLANT, 1, 1, 1, ["stealth"], {"tribes": ["plant"]})
	_db.prototypes[MIXED_PREY] = CardFactory.make_minion(MIXED_PREY, 1, 1, 1, [], {"tribes": ["beast", "plant"]})
	var plant_predator: Dictionary = _db.prototypes[PREDATOR].duplicate(true)
	plant_predator.id = PLANT_PREDATOR
	plant_predator.text.key = "card.%s.text" % PLANT_PREDATOR
	plant_predator.tribes = ["plant"]
	_db.prototypes[PLANT_PREDATOR] = plant_predator
	_game = ShippedMatch.new(_db, "hero_war", "boss_torchbearer")
	_game.to_player_main()
	_game.set_hand(PLAYER, [PREDATOR])


func after_test() -> void:
	if _game != null:
		_game.finish()
	_game = null
	_db = null


func _play(side: String = PLAYER) -> int:
	var position: int = _game.engine.state().players[side].board.size()
	var result: Dictionary = _game.submit(MatchRecords.play_card(side, 0, position))
	assert_bool(result.accepted).override_failure_message(str(result)).is_true()
	return int(_game.engine.state().players[side].board[position].entity_id) if result.accepted else RulesEngine.NO_ENTITY


func _assert_stats(entity_id: int, expected: int) -> void:
	var minion: Dictionary = _game.minion_of(entity_id)
	assert_bool(minion.is_empty()).is_false()
	assert_int(_game.engine.attack(minion)).is_equal(expected)
	assert_int(_game.engine.health(minion)).is_equal(expected)


func test_prototype_effect_and_printed_tribes_pass_current_schemas() -> void:
	var caps: Dictionary = EffectValidator.stage7_caps({
		"card_effects": _db.config("card_effects"), "match_rules": _db.config("match_rules"),
	})
	for id: String in _db.prototypes:
		var record: Dictionary = _db.prototypes[id]
		var report := ValidationReport.new()
		assert_bool(RecordSchemas.check_record("CardDef", "cards_neutral.json", 0, record, report)).override_failure_message(report.to_text()).is_true()
		assert_array(EffectValidator.validate_effects(&"card", id, record.effects, _db, caps)).is_empty()


func test_no_prey_keeps_the_baseline_body_and_pays_normal_cost() -> void:
	_assert_stats(_play(), 3)
	assert_int(_game.engine.state().players[PLAYER].mana_current).is_equal(7)


func test_a_different_tribe_does_not_enable_the_bonus() -> void:
	_game.summon(BOSS, "neutral_cellar_guard")
	_assert_stats(_play(), 3)


func test_friendly_prey_enables_the_bonus_without_being_consumed() -> void:
	var prey: int = _game.summon(PLAYER, PLANT)
	_assert_stats(_play(), 4)
	_assert_stats(prey, 1)
	var effects: Array = _game.of_type("effect_resolved")
	assert_dict(effects.back().payload.predator).is_equal({"friendly": true, "enemy": false})


func test_enemy_prey_enables_the_bonus_without_being_consumed() -> void:
	var prey: int = _game.summon(BOSS, PLANT)
	_assert_stats(_play(), 4)
	_assert_stats(prey, 1)
	var effects: Array = _game.of_type("effect_resolved")
	assert_dict(effects.back().payload.predator).is_equal({"friendly": false, "enemy": true})


func test_multiple_prey_on_both_boards_grant_only_one_bonus() -> void:
	_game.summon(PLAYER, PLANT)
	_game.summon(BOSS, PLANT)
	_game.summon(BOSS, PLANT)
	_assert_stats(_play(), 4)
	var effects: Array = _game.of_type("effect_resolved")
	assert_dict(effects.back().payload.predator).is_equal({"friendly": true, "enemy": true})


func test_a_predator_cannot_count_itself_as_prey() -> void:
	_game.set_hand(PLAYER, [PLANT_PREDATOR])
	_assert_stats(_play(), 3)


func test_another_predator_of_the_preferred_tribe_can_count_as_prey() -> void:
	_game.summon(BOSS, PLANT_PREDATOR)
	_assert_stats(_play(), 4)


func test_a_multi_tribe_minion_counts_if_one_tribe_matches() -> void:
	_game.summon(BOSS, MIXED_PREY)
	_assert_stats(_play(), 4)


func test_enemy_stealth_does_not_hide_prey_from_a_presence_check() -> void:
	_game.summon(BOSS, STEALTH_PLANT)
	_assert_stats(_play(), 4)


func test_silenced_prey_keeps_its_printed_tribe() -> void:
	var prey: int = _game.summon(BOSS, PLANT)
	_game.engine.run_action(func() -> void: _game.engine.silence(prey))
	_assert_stats(_play(), 4)


func test_prey_destroyed_before_play_no_longer_enables_the_bonus() -> void:
	var prey: int = _game.summon(BOSS, PLANT)
	_game.engine.run_action(func() -> void: _game.engine.destroy(prey))
	_assert_stats(_play(), 3)


func test_dying_prey_does_not_enable_the_bonus() -> void:
	var prey: int = _game.summon(BOSS, PLANT)
	_game.minion_of(prey).damage_taken = 1
	_assert_stats(_play(), 3)


func test_bounced_prey_is_not_on_the_battlefield() -> void:
	var prey: int = _game.summon(BOSS, PLANT)
	_game.engine.run_action(func() -> void: _game.engine.return_to_hand(prey))
	_assert_stats(_play(), 3)


func test_transformed_prey_uses_its_new_printed_tribe() -> void:
	var prey: int = _game.summon(BOSS, PLANT)
	_game.engine.run_action(func() -> void: _game.engine.transform(prey, "neutral_cellar_guard"))
	_assert_stats(_play(), 3)


func test_removing_prey_after_resolution_does_not_revoke_the_bonus() -> void:
	var prey: int = _game.summon(BOSS, PLANT)
	var predator: int = _play()
	_game.engine.run_action(func() -> void: _game.engine.destroy(prey))
	_assert_stats(predator, 4)


func test_silencing_a_buffed_predator_removes_the_buff() -> void:
	_game.summon(BOSS, PLANT)
	var predator: int = _play()
	_assert_stats(predator, 4)
	_game.engine.run_action(func() -> void: _game.engine.silence(predator))
	_assert_stats(predator, 3)


func test_direct_summons_do_not_trigger_predator() -> void:
	_game.summon(BOSS, PLANT)
	_assert_stats(_game.summon(PLAYER, PREDATOR), 3)


func test_transforming_into_a_predator_does_not_trigger_its_bonus() -> void:
	_game.summon(BOSS, PLANT)
	var original: int = _game.summon(PLAYER, "neutral_cellar_guard")
	var replacement: Array[int] = [RulesEngine.NO_ENTITY]
	_game.engine.run_action(func() -> void: replacement[0] = _game.engine.transform(original, PREDATOR))
	_assert_stats(replacement[0], 3)


func test_returning_and_replaying_a_predator_checks_prey_again() -> void:
	var prey: int = _game.summon(BOSS, PLANT)
	var predator: int = _play()
	_assert_stats(predator, 4)
	_game.engine.run_action(func() -> void:
		_game.engine.return_to_hand(predator)
		_game.engine.destroy(prey))
	_assert_stats(_play(), 3)
	assert_int(_game.engine.state().players[PLAYER].mana_current).is_equal(4)


func test_boss_play_can_use_player_prey() -> void:
	_game.to_boss_main()
	_game.summon(PLAYER, PLANT)
	_game.set_hand(BOSS, [PREDATOR])
	_assert_stats(_play(BOSS), 4)


func test_clone_predicts_the_same_result_without_changing_the_live_board() -> void:
	_game.summon(BOSS, PLANT)
	var sandbox: RulesEngine = _game.engine.clone()
	var command: Dictionary = MatchRecords.play_card(PLAYER, 0, 0)
	assert_bool(sandbox.submit(command).accepted).is_true()
	assert_int(_game.engine.state().players[PLAYER].board.size()).is_equal(0)
	_assert_stats(_play(), 4)
	assert_dict(sandbox.state().players).is_equal(_game.engine.state().players)
	assert_dict(sandbox.state().effects).is_equal(_game.engine.state().effects)
	sandbox.end_match()
