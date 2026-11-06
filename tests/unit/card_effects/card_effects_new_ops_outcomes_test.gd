## The six ops added to v1 on 2026-11-03 and their `outcome` values: `set_stats`,
## `remove_keyword`, `weapon_durability`, `shuffle_into_deck`, `discard`,
## `hero_power_refresh` (design/gdd/card-effects.md C5, Interactions `effect_resolved`,
## F5; match-rules Interactions).
##
## A real `RulesEngine` bound to the real `EffectResolver`: each case casts a 0-cost spell
## whose `cast` effect is the op under test, through `submit`. In-memory definitions, no
## file I/O, no wall clock.
extends GdUnitTestSuite

const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const SIDE_BOSS: String = MatchRecords.SIDE_BOSS
const SPELL: String = "war_test_op_spell"
const VANILLA: String = "war_test_vanilla"
const TAUNT_MINION: String = "war_test_taunt"
const AXE: String = "war_test_axe"
const SHUFFLED: String = "war_test_shuffled"
const POWER: String = "power_test_refresh"
const EVENT_RESOLVED: String = "effect_resolved"
const VANILLA_ATTACK: int = 2
const VANILLA_HEALTH: int = 5
const AXE_ATTACK: int = 3
const AXE_DURABILITY: int = 2
const POWER_COST: int = 2
const START_MANA: int = 5


class FakeCardDatabase:
	extends CardDatabase

	var records: Dictionary = {}

	func _init(by_id: Dictionary) -> void:
		records = by_id

	func has(id: String) -> bool:
		return records.has(id)

	func card(id: String) -> Variant:
		return records.get(id)

	func hero_power(id: String) -> Variant:
		return records.get(id)


var _engine: RulesEngine = null
var _log: TestEventLog = null
var _rng: TestRngService = null


func after_test() -> void:
	if _engine != null:
		_engine.end_match()
	_engine = null
	_log = null
	_rng = null


func _effects_config() -> Dictionary:
	return {
		"discover_count": float(TestConstants.DISCOVER_COUNT),
		"discover_exclude_hand": false,
		"max_ops_per_effect": float(TestConstants.MAX_OPS_PER_EFFECT),
		"max_repeat": float(TestConstants.MAX_REPEAT),
		"max_summon_count": float(TestConstants.BOARD_SIZE),
		"effect_static_step_limit": float(TestConstants.EFFECT_STATIC_STEP_LIMIT),
		"spell_damage_default": "auto",
		"hooks_before_triggers": true,
	}


## The player's Main with an empty board, [param op] the only op of [constant SPELL],
## whose effect-level targets are [param targets], and the spell alone in hand.
func _main(op: Dictionary, targets: Variant = null) -> void:
	var effect: Dictionary = {"id": SPELL + ".0", "trigger": "cast", "ops": [op]}
	if targets != null:
		effect["targets"] = targets
	var db: FakeCardDatabase = FakeCardDatabase.new({
		SPELL: CardFactory.make_spell(SPELL, 0, [effect], {"set": "war"}),
		VANILLA: CardFactory.make_minion(VANILLA, 1, VANILLA_ATTACK, VANILLA_HEALTH),
		TAUNT_MINION: CardFactory.make_minion(TAUNT_MINION, 1, VANILLA_ATTACK, VANILLA_HEALTH, ["taunt"]),
		AXE: CardFactory.make_weapon(AXE, 1, AXE_ATTACK, AXE_DURABILITY),
		SHUFFLED: CardFactory.make_minion(SHUFFLED, 1, 1, 1),
		POWER: CardFactory.make_hero_power_def(POWER, [{"id": POWER + ".0", "trigger": "hero_power", "ops": [CardFactory.make_op("armor", {"amount": 1})]}]),
	})
	_log = TestEventLog.new()
	_rng = TestRngService.new()
	var config: Dictionary = MatchFactory.make_started_config(_rng, _log)
	_engine = RulesEngine.new(db, MatchFactory.make_rules_config(), EffectResolver.new(db, _effects_config()))
	_engine.start(config)
	assert_bool(_engine.submit(_engine.legal_commands()[0]).accepted).is_true()
	_set_hand(SIDE_PLAYER, [SPELL])
	_set_hand(SIDE_BOSS, [])


func _set_hand(side: String, def_ids: Array) -> void:
	var state: MatchState = _engine.state()
	var hand: Array = state.players[side].hand
	hand.clear()
	for def_id: Variant in def_ids:
		hand.append(MatchFactory.make_card_instance(MatchFactory.alloc_entity_id(state), str(def_id), "hand"))


func _summon(side: String, def_id: String = VANILLA) -> Dictionary:
	var id: Array[int] = [0]
	_engine.run_action(func() -> void: id[0] = _engine.summon_minion(side, def_id, (_engine.state().players[side].board as Array).size()))
	for minion: Dictionary in _engine.state().players[side].board:
		if int(minion.entity_id) == id[0]:
			return minion
	return {}


func _equip(side: String = SIDE_PLAYER) -> void:
	_engine.run_action(func() -> void: _engine.equip_weapon(side, AXE))


func _weapon(side: String = SIDE_PLAYER) -> Variant:
	return _engine.state().players[side].weapon


func _last_seq() -> int:
	return int(_log.events.back().seq)


func _since(seq: int, type: String) -> Array:
	return _log.events.filter(func(e: Dictionary) -> bool: return int(e.seq) > seq and str(e.type) == type)


## Casts the spell, at [param target], and returns its one `ops[]` entry.
func _cast(target: Variant = null) -> Dictionary:
	var before: int = _last_seq()
	var hand: Array = _engine.state().players[SIDE_PLAYER].hand
	var index: int = hand.find_custom(func(card: Dictionary) -> bool: return str(card.def_id) == SPELL)
	var result: Dictionary = _engine.submit(MatchRecords.play_card(SIDE_PLAYER, index, null, target))
	assert_bool(result.accepted).override_failure_message(str(result)).is_true()
	var resolved: Array = _since(before, EVENT_RESOLVED)
	assert_int(resolved.size()).is_equal(1)
	return resolved[0].payload.ops[0] if not resolved.is_empty() else {}


func _stream_draws() -> int:
	return (_engine.rng_match() as TestRngStream).count_calls("randi_range")


# --- set_stats ----------------------------------------------------------------------


func test_set_stats_sets_both_stats_and_logs_applied() -> void:
	# Arrange
	_main(CardFactory.make_op("set_stats", {"attack": 7, "health": 1}), "all_enemy_minions")
	var minion: Dictionary = _summon(SIDE_BOSS)

	# Act
	var entry: Dictionary = _cast()

	# Assert
	assert_str(str(entry.outcome)).is_equal("applied")
	assert_array(entry.targets).contains_exactly([int(minion.entity_id)])
	assert_int(_engine.attack(minion)).is_equal(7)
	assert_int(_engine.health(minion)).is_equal(1)
	assert_int(_engine.max_health(minion)).is_equal(1)


func test_set_stats_with_health_absent_keeps_the_wound() -> void:
	# Arrange
	_main(CardFactory.make_op("set_stats", {"attack": 7}), "all_enemy_minions")
	var minion: Dictionary = _summon(SIDE_BOSS)
	minion.damage_taken = 2

	# Act
	var entry: Dictionary = _cast()

	# Assert
	assert_str(str(entry.outcome)).is_equal("applied")
	assert_int(_engine.attack(minion)).is_equal(7)
	assert_int(_engine.health(minion)).is_equal(VANILLA_HEALTH - 2)


func test_set_stats_with_health_clears_the_wound() -> void:
	# Arrange
	_main(CardFactory.make_op("set_stats", {"health": 3}), "all_enemy_minions")
	var minion: Dictionary = _summon(SIDE_BOSS)
	minion.damage_taken = 2

	# Act
	@warning_ignore("return_value_discarded")
	_cast()

	# Assert
	assert_int(_engine.health(minion)).is_equal(3)
	assert_int(_engine.attack(minion)).is_equal(VANILLA_ATTACK)


func test_set_stats_swap_reads_both_refs_before_the_write() -> void:
	# Arrange — C5: "Swap Attack and Health"
	_main(CardFactory.make_op("set_stats", {"attack": {"ref": "target.health"}, "health": {"ref": "target.attack"}}), {"selector": "chosen", "filter": {"kind": "minion"}})
	var minion: Dictionary = _summon(SIDE_BOSS)

	# Act
	var entry: Dictionary = _cast(int(minion.entity_id))

	# Assert
	assert_str(str(entry.outcome)).is_equal("applied")
	assert_int(_engine.attack(minion)).is_equal(VANILLA_HEALTH)
	assert_int(_engine.health(minion)).is_equal(VANILLA_ATTACK)


func test_set_stats_on_an_empty_board_is_no_target() -> void:
	# Arrange
	_main(CardFactory.make_op("set_stats", {"attack": 7}), "all_enemy_minions")

	# Act
	var entry: Dictionary = _cast()

	# Assert
	assert_str(str(entry.outcome)).is_equal("no_target")
	assert_array(entry.targets).is_empty()


func test_set_stats_leaves_a_hero_alone_as_no_target() -> void:
	# Arrange — minions only (C5 Legal targets); the hero is the only thing selected
	_main(CardFactory.make_op("set_stats", {"attack": 7}), "enemy_hero")
	var hero: Dictionary = _engine.state().players[SIDE_BOSS].hero
	var health: int = _engine.health(hero)

	# Act
	var entry: Dictionary = _cast()

	# Assert
	assert_str(str(entry.outcome)).is_equal("no_target")
	assert_int(_engine.health(hero)).is_equal(health)
	assert_int(_engine.attack(hero)).is_equal(0)


# --- remove_keyword -----------------------------------------------------------------


func test_remove_keyword_strips_taunt_and_it_stops_blocking_attacks() -> void:
	# Arrange
	_main(CardFactory.make_op("remove_keyword", {"keyword": "taunt"}), "all_enemy_minions")
	var taunter: Dictionary = _summon(SIDE_BOSS, TAUNT_MINION)
	var attacker: Dictionary = _summon(SIDE_PLAYER)
	attacker.summoning_sick = false
	var boss_hero: int = int(_engine.state().players[SIDE_BOSS].hero.entity_id)
	assert_bool(_engine.can_attack(int(attacker.entity_id), boss_hero).ok).is_false()
	var before: int = _last_seq()

	# Act
	var entry: Dictionary = _cast()

	# Assert
	assert_str(str(entry.outcome)).is_equal("applied")
	var removed: Array = _since(before, "keyword_removed")
	assert_int(removed.size()).is_equal(1)
	assert_int(int(removed[0].payload.entity_id)).is_equal(int(taunter.entity_id))
	assert_str(str(removed[0].payload.keyword)).is_equal("taunt")
	assert_bool(_engine.can_attack(int(attacker.entity_id), boss_hero).ok).is_true()


func test_remove_keyword_not_held_is_skipped_with_no_event() -> void:
	# Arrange
	_main(CardFactory.make_op("remove_keyword", {"keyword": "taunt"}), "all_enemy_minions")
	@warning_ignore("return_value_discarded")
	_summon(SIDE_BOSS)
	var before: int = _last_seq()

	# Act
	var entry: Dictionary = _cast()

	# Assert
	assert_str(str(entry.outcome)).is_equal("skipped")
	assert_array(_since(before, "keyword_removed")).is_empty()


func test_remove_keyword_with_no_target_is_no_target() -> void:
	# Arrange
	_main(CardFactory.make_op("remove_keyword", {"keyword": "taunt"}), "all_enemy_minions")

	# Act
	var entry: Dictionary = _cast()

	# Assert
	assert_str(str(entry.outcome)).is_equal("no_target")


func test_remove_keyword_over_a_mixed_board_is_partial() -> void:
	# Arrange — one holder, one not: the per-target results fold
	_main(CardFactory.make_op("remove_keyword", {"keyword": "taunt"}), "all_enemy_minions")
	@warning_ignore("return_value_discarded")
	_summon(SIDE_BOSS, TAUNT_MINION)
	@warning_ignore("return_value_discarded")
	_summon(SIDE_BOSS)

	# Act
	var entry: Dictionary = _cast()

	# Assert
	assert_str(str(entry.outcome)).is_equal("partial")


# --- weapon_durability --------------------------------------------------------------


func test_weapon_durability_raises_durability_and_logs_applied() -> void:
	# Arrange
	_main(CardFactory.make_op("weapon_durability", {"amount": 1}), "owner_weapon")
	_equip()
	var before: int = _last_seq()

	# Act
	var entry: Dictionary = _cast()

	# Assert
	assert_str(str(entry.outcome)).is_equal("applied")
	assert_int(int(_weapon().durability)).is_equal(AXE_DURABILITY + 1)
	var changed: Array = _since(before, "weapon_durability_changed")
	assert_int(changed.size()).is_equal(1)
	assert_int(int(changed[0].payload.delta)).is_equal(1)
	assert_int(int(changed[0].payload.durability)).is_equal(AXE_DURABILITY + 1)


func test_weapon_durability_to_zero_breaks_the_weapon_in_the_death_check() -> void:
	# Arrange
	_main(CardFactory.make_op("weapon_durability", {"amount": -AXE_DURABILITY}), "owner_weapon")
	_equip()
	var before: int = _last_seq()

	# Act
	var entry: Dictionary = _cast()

	# Assert
	assert_str(str(entry.outcome)).is_equal("applied")
	assert_that(_weapon()).is_null()
	assert_int(_since(before, "weapon_destroyed").size()).is_equal(1)


func test_weapon_durability_with_no_weapon_is_no_target() -> void:
	# Arrange
	_main(CardFactory.make_op("weapon_durability", {"amount": 1}), "owner_weapon")
	var before: int = _last_seq()

	# Act
	var entry: Dictionary = _cast()

	# Assert
	assert_str(str(entry.outcome)).is_equal("no_target")
	assert_array(_since(before, "weapon_durability_changed")).is_empty()


# --- shuffle_into_deck --------------------------------------------------------------


func test_shuffle_into_deck_top_adds_at_index_zero_and_draws_no_rng() -> void:
	# Arrange
	_main(CardFactory.make_op("shuffle_into_deck", {"card_id": SHUFFLED, "count": 1, "position": "top"}))
	var deck: Array = _engine.state().players[SIDE_PLAYER].deck
	var size: int = deck.size()
	var draws: int = _stream_draws()

	# Act
	var entry: Dictionary = _cast()

	# Assert
	assert_str(str(entry.outcome)).is_equal("applied")
	assert_int(deck.size()).is_equal(size + 1)
	assert_str(str(deck[0].def_id)).is_equal(SHUFFLED)
	assert_int(_stream_draws()).is_equal(draws)


func test_shuffle_into_deck_bottom_adds_at_the_end() -> void:
	# Arrange
	_main(CardFactory.make_op("shuffle_into_deck", {"card_id": SHUFFLED, "count": 1, "position": "bottom"}))
	var deck: Array = _engine.state().players[SIDE_PLAYER].deck

	# Act
	var entry: Dictionary = _cast()

	# Assert
	assert_str(str(entry.outcome)).is_equal("applied")
	assert_str(str(deck.back().def_id)).is_equal(SHUFFLED)


func test_shuffle_into_deck_random_draws_one_index_per_copy() -> void:
	# Arrange — C5: `random` draws one `match_<floor>` index (F5)
	var copies: int = 3
	_main(CardFactory.make_op("shuffle_into_deck", {"card_id": SHUFFLED, "count": copies}))
	var size: int = (_engine.state().players[SIDE_PLAYER].deck as Array).size()
	var draws: int = _stream_draws()
	var before: int = _last_seq()

	# Act
	var entry: Dictionary = _cast()

	# Assert
	assert_str(str(entry.outcome)).is_equal("applied")
	assert_int(_stream_draws() - draws).is_equal(copies)
	assert_int(_since(before, "card_added_to_deck").size()).is_equal(copies)
	assert_int((_engine.state().players[SIDE_PLAYER].deck as Array).size()).is_equal(size + copies)


func test_shuffle_into_deck_on_an_empty_deck_never_fails() -> void:
	# Arrange
	_main(CardFactory.make_op("shuffle_into_deck", {"card_id": SHUFFLED, "count": 1}))
	(_engine.state().players[SIDE_PLAYER].deck as Array).clear()

	# Act
	var entry: Dictionary = _cast()

	# Assert
	assert_str(str(entry.outcome)).is_equal("applied")
	assert_int((_engine.state().players[SIDE_PLAYER].deck as Array).size()).is_equal(1)


func test_shuffle_into_deck_targets_form_adds_a_copy_of_each_minion() -> void:
	# Arrange
	_main(CardFactory.make_op("shuffle_into_deck", {"count": 1, "position": "top"}), "all_enemy_minions")
	@warning_ignore("return_value_discarded")
	_summon(SIDE_BOSS)

	# Act
	var entry: Dictionary = _cast()

	# Assert
	assert_str(str(entry.outcome)).is_equal("applied")
	assert_str(str(_engine.state().players[SIDE_PLAYER].deck[0].def_id)).is_equal(VANILLA)


func test_shuffle_into_deck_targets_form_with_nothing_left_is_no_target() -> void:
	# Arrange
	_main(CardFactory.make_op("shuffle_into_deck", {"count": 1}), "all_enemy_minions")
	var size: int = (_engine.state().players[SIDE_PLAYER].deck as Array).size()

	# Act
	var entry: Dictionary = _cast()

	# Assert
	assert_str(str(entry.outcome)).is_equal("no_target")
	assert_int((_engine.state().players[SIDE_PLAYER].deck as Array).size()).is_equal(size)


# --- discard ------------------------------------------------------------------------


func test_discard_moves_a_random_card_to_the_graveyard_with_one_draw() -> void:
	# Arrange
	_main(CardFactory.make_op("discard", {"count": 1, "random": true}))
	_set_hand(SIDE_PLAYER, [SPELL, VANILLA, VANILLA])
	var draws: int = _stream_draws()
	var before: int = _last_seq()

	# Act
	var entry: Dictionary = _cast()

	# Assert
	assert_str(str(entry.outcome)).is_equal("applied")
	assert_int((_engine.state().players[SIDE_PLAYER].hand as Array).size()).is_equal(1)
	assert_int(_since(before, "card_discarded").size()).is_equal(1)
	assert_int(_stream_draws() - draws).is_equal(1)
	assert_int(entry.targets.size()).is_equal(1)


func test_discard_side_opponent_empties_the_bosss_hand_card() -> void:
	# Arrange
	_main(CardFactory.make_op("discard", {"count": 1, "random": true, "side": "opponent"}))
	_set_hand(SIDE_BOSS, [VANILLA])

	# Act
	var entry: Dictionary = _cast()

	# Assert
	assert_str(str(entry.outcome)).is_equal("applied")
	assert_array(_engine.state().players[SIDE_BOSS].hand).is_empty()


func test_discard_from_an_empty_hand_is_no_target_with_no_draw() -> void:
	# Arrange — the spell leaves the hand on play, so the hand is empty at the op
	_main(CardFactory.make_op("discard", {"count": 1, "random": true}))
	var draws: int = _stream_draws()
	var before: int = _last_seq()

	# Act
	var entry: Dictionary = _cast()

	# Assert
	assert_str(str(entry.outcome)).is_equal("no_target")
	assert_int(_stream_draws()).is_equal(draws)
	assert_array(_since(before, "card_discarded")).is_empty()


func test_discard_two_from_a_hand_of_one_is_partial() -> void:
	# Arrange — `discard × count` and C5's "Empty hand → no_target": the second call has
	# no target, so the op folds as "Draw 2 with one card left" and summon's `partial` do
	_main(CardFactory.make_op("discard", {"count": 2, "random": true}))
	_set_hand(SIDE_PLAYER, [SPELL, VANILLA])

	# Act
	var entry: Dictionary = _cast()

	# Assert
	assert_str(str(entry.outcome)).is_equal("partial")
	assert_int(entry.targets.size()).is_equal(1)


# --- hero_power_refresh -------------------------------------------------------------


func _use_power() -> void:
	var player: Dictionary = _engine.state().players[SIDE_PLAYER]
	player.hero_power.def_id = POWER
	player.mana_current = START_MANA
	player.mana_max = START_MANA
	var result: Dictionary = _engine.submit(MatchRecords.use_hero_power(SIDE_PLAYER))
	assert_bool(result.accepted).override_failure_message(str(result)).is_true()


func test_hero_power_refresh_makes_a_used_power_usable_with_no_mana_back() -> void:
	# Arrange
	_main(CardFactory.make_op("hero_power_refresh"))
	_use_power()
	var player: Dictionary = _engine.state().players[SIDE_PLAYER]
	var mana: int = int(player.mana_current)
	var before: int = _last_seq()

	# Act
	var entry: Dictionary = _cast()

	# Assert
	assert_str(str(entry.outcome)).is_equal("applied")
	assert_bool(bool(player.hero_power.used_this_turn)).is_false()
	assert_int(int(player.mana_current)).is_equal(mana)
	assert_int(_since(before, "hero_power_refreshed").size()).is_equal(1)
	assert_bool(_engine.submit(MatchRecords.use_hero_power(SIDE_PLAYER)).accepted).is_true()


func test_hero_power_refresh_of_an_unused_power_is_skipped_with_no_event() -> void:
	# Arrange
	_main(CardFactory.make_op("hero_power_refresh"))
	var before: int = _last_seq()

	# Act
	var entry: Dictionary = _cast()

	# Assert
	assert_str(str(entry.outcome)).is_equal("skipped")
	assert_array(_since(before, "hero_power_refreshed")).is_empty()
