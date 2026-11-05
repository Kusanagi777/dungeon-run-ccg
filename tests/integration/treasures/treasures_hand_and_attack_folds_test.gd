## Integration: the hand-size and attack-count treasures and their post-fold clamps
## (treasures story 006; design/gdd/treasures.md T8 rows 7, 12, T9, F2, F3, Edge
## Cases "Value folds and clamps", AC-13, AC-19, AC-23; match-rules C3 step 5, C1
## `max_attacks`, F3; ADR-0005 rule 4).
##
## Every case runs the T8 records through the real `CardDatabase` pipeline,
## `Treasures.installers_for`, `MatchConfig`, `RulesEngine.start` and the real
## `EffectResolver`, on the GDD's seed and hero. A fixture passive goes through
## `Treasures.passive_installer`, and its scope reaches the player from the boss's
## side, because a scope reads relative to `entry.side` (T2.4).
##
## The clean root's `match_rules.json` and `card_effects.json` hold no knobs, so
## the bodies are `MatchFactory.make_rules_config()` and [method _effects_config].
## Bounds are read back through `RulesEngine.rule`.
extends GdUnitTestSuite

const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const SIDE_BOSS: String = MatchRecords.SIDE_BOSS
const ZONE_HAND: String = "hand"
## The treasures GDD's AC preamble: `run_seed_hex` 00000000000000A7, hero `hero_war`.
const RUN_SEED: int = 0x00000000000000A7
const HERO_WAR: String = "hero_war"
## A boss card of the clean root, for a boss deck the root can look up.
const BOSS_CARD: String = "boss_grave_rat"
## What `installers_for` is handed by a run with no treasure state (T4).
const NO_STATE: Dictionary = {"schema_version": Treasures.SCHEMA_VERSION, "by_treasure": {}}

const SATCHEL: String = "treasure_bottomless_satchel"
const TWIN_GRIP: String = "treasure_twin_grip"
## Bottomless Satchel's `delta` and Twin Grip's `set`, from T9.
const SATCHEL_DELTA: int = 2
const TWIN_GRIP_ATTACKS: int = 2
## AC-13's passive, and the delta that lifts Twin Grip past the attack cap.
const PASSIVE_HAND_DELTA: int = 6
const PASSIVE_ATTACK_DELTA: int = 6

## AC-13's fixture boss: scoped to the player's hand, or it would change its own.
const HAND_PASSIVE: Dictionary = {
	"trigger": "modify_starting_hand_size", "scope": {"side": "opponent"},
	"ops": [{"op": "modify_value", "delta": PASSIVE_HAND_DELTA}],
}
## A fixture boss that lifts the player's hero past `max_attacks_cap`.
const ATTACK_PASSIVE: Dictionary = {
	"trigger": "modify_max_attacks", "scope": {"who": "enemy"},
	"ops": [{"op": "modify_value", "delta": PASSIVE_ATTACK_DELTA}],
}

## The scripted weapons, each 1 mana so the first turn can equip it.
const WEAPON_COST: int = 1
const WEAPON_ATTACK: int = 2
const BLADE_1: String = "neutral_test_fold_blade_1"
const BLADE_2: String = "neutral_test_fold_blade_2"
const BLADE_5: String = "neutral_test_fold_blade_5"
const WINDFURY_BLADE: String = "neutral_test_fold_windfury_blade"
## `WINDFURY_BLADE`'s durability: past two swings, so only the count can stop a third.
const WINDFURY_DURABILITY: int = 4
const LONG_DURABILITY: int = 5

var _engine: RulesEngine = null
var _log: TestEventLog = null


func after_test() -> void:
	if _engine != null:
		_engine.end_match()
	_engine = null
	_log = null


# --- helpers -------------------------------------------------------------------

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


func _scripted_cards() -> Array:
	return [
		CardFactory.make_weapon(BLADE_1, WEAPON_COST, WEAPON_ATTACK, 1),
		CardFactory.make_weapon(BLADE_2, WEAPON_COST, WEAPON_ATTACK, 2),
		CardFactory.make_weapon(BLADE_5, WEAPON_COST, WEAPON_ATTACK, LONG_DURABILITY),
		CardFactory.make_weapon(WINDFURY_BLADE, WEAPON_COST, WEAPON_ATTACK, WINDFURY_DURABILITY, {"keywords": ["windfury"]}),
	]


## A match in `Mulligan`: [param treasure_ids] through `installers_for` over the 20
## T8 records, and a fixture boss holding [param passive] when it is not null.
func _start(treasure_ids: Array, passive: Variant = null) -> void:
	var db: CardDatabase = TreasureFixtures.database([], _scripted_cards())
	var hero: Dictionary = db.hero(HERO_WAR)
	var boss: Dictionary = CardFactory.make_boss_def("boss_test_fixture", 1, {"passive": passive})
	var treasures: Treasures = Treasures.new(db, db.config("treasures_balance"))
	var boss_deck: Array = []
	boss_deck.resize(MatchFactory.STARTED_BOSS_DECK_SIZE)
	boss_deck.fill(BOSS_CARD)
	_log = TestEventLog.new()
	var config: Dictionary = MatchFactory.make_started_config(TestRngService.new(RUN_SEED), _log, {
		"player": {
			"hero_def_id": HERO_WAR,
			"deck": Array(hero.starter_deck),
			"hook_installers": treasures.installers_for(treasure_ids, NO_STATE),
		},
		"boss": {
			"boss_def_id": str(boss.id),
			"deck": boss_deck,
			"hook_installers": Treasures.passive_installer(boss),
		},
	})
	_engine = RulesEngine.new(db, MatchFactory.make_rules_config(), EffectResolver.new(db, _effects_config(), str(hero.set)))
	_engine.start(config)


## Player Main of turn 1 with [param weapon_id] equipped by a real `play_card`.
## The hand is scripted (story 006's Implementation Notes).
func _armed(treasure_ids: Array, weapon_id: String, passive: Variant = null) -> void:
	_start(treasure_ids, passive)
	_submit(_engine.legal_commands()[0])
	var hand: Array = _player().hand
	hand.clear()
	hand.append(MatchFactory.make_card_instance(MatchFactory.alloc_entity_id(_engine.state()), weapon_id, ZONE_HAND))
	_engine.index_locations()
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0))


func _submit(command: Dictionary) -> void:
	var result: Dictionary = _engine.submit(command)
	assert_bool(result.accepted).override_failure_message("rejected: %s" % str(result.rejection)).is_true()


func _player() -> Dictionary:
	return _engine.state().players[SIDE_PLAYER]


func _boss() -> Dictionary:
	return _engine.state().players[SIDE_BOSS]


func _swing_command() -> Dictionary:
	return MatchRecords.attack(SIDE_PLAYER, int(_player().hero.entity_id), int(_boss().hero.entity_id))


func _swing() -> void:
	_submit(_swing_command())


func _of_type(type: String) -> Array:
	return _log.events.filter(func(e: Dictionary) -> bool: return str(e.type) == type)


func _legal_attacks() -> Array:
	return _engine.legal_commands().filter(func(cmd: Dictionary) -> bool: return str(cmd.type) == MatchRecords.CMD_ATTACK)


func _assert_rejected(result: Dictionary, code: String) -> void:
	assert_bool(result.accepted).is_false()
	assert_str(str(result.rejection.code)).is_equal(code)


func _keep_all(count: int) -> Array:
	var mask: Array = []
	mask.resize(count)
	mask.fill(true)
	return mask


func _player_base_hand() -> int:
	return _engine.rule("starting_hand_player")


# --- AC-19: Bottomless Satchel ---------------------------------------------------

func test_ac19_mulligan_offered_lists_the_five_cards_of_the_hand() -> void:
	# Act
	_start([SATCHEL])

	# Assert
	var offered: Array = _of_type("mulligan_offered")
	var hand_ids: Array = _player().hand.map(func(card: Dictionary) -> int: return int(card.instance_id))
	assert_int(hand_ids.size()).is_equal(_player_base_hand() + SATCHEL_DELTA)
	assert_int(offered.size()).is_equal(1)
	assert_array(Array(offered[0].payload.instance_ids)).is_equal(hand_ids)


func test_ac19_without_the_satchel_the_offer_is_the_base_hand() -> void:
	# Act
	_start([])

	# Assert — the control: the extra two are the treasure's doing
	assert_int(_player().hand.size()).is_equal(_player_base_hand())


func test_ac19_a_keep_mask_of_length_five_is_accepted() -> void:
	# Arrange
	_start([SATCHEL])

	# Act
	var result: Dictionary = _engine.submit(MatchRecords.mulligan(_keep_all(_player_base_hand() + SATCHEL_DELTA)))

	# Assert
	assert_bool(result.accepted).is_true()
	assert_str(_engine.phase()).is_equal(MatchState.PHASE_MAIN)


func test_ac19_a_keep_mask_of_length_three_is_invalid_mask() -> void:
	# Arrange
	_start([SATCHEL])

	# Act
	var result: Dictionary = _engine.submit(MatchRecords.mulligan(_keep_all(_player_base_hand())))

	# Assert — the mask follows the resulting hand, not the rule's base
	_assert_rejected(result, "INVALID_MASK")
	assert_str(_engine.phase()).is_equal(MatchState.PHASE_MULLIGAN)


func test_ac19_the_legal_mulligan_mask_follows_the_hand() -> void:
	# Arrange
	_start([SATCHEL])

	# Act
	var legal: Array = _engine.legal_commands()

	# Assert
	assert_int(legal.size()).is_equal(1)
	assert_array(Array(legal[0].keep_mask)).is_equal(_keep_all(_player_base_hand() + SATCHEL_DELTA))


func test_ac19_cards_thrown_back_from_the_five_are_replaced_one_for_one() -> void:
	# Arrange
	_start([SATCHEL])
	var mask: Array = _keep_all(_player_base_hand() + SATCHEL_DELTA)
	mask[0] = false
	mask[1] = false

	# Act
	_submit(MatchRecords.mulligan(mask))

	# Assert
	var resolved: Array = _of_type("mulligan_resolved")
	assert_int(Array(resolved[0].payload.replaced_instance_ids).size()).is_equal(2)
	var drawn_at_start: int = 1
	assert_int(_player().hand.size()).is_equal(_player_base_hand() + SATCHEL_DELTA + drawn_at_start)


func test_ac19_the_boss_still_draws_its_own_hand() -> void:
	# Act
	_start([SATCHEL])

	# Assert — `scope.side: owner` stops the fold on the boss's side
	assert_int(_boss().hand.size()).is_equal(_engine.rule("starting_hand_boss"))


# --- AC-13: the hand clamp --------------------------------------------------------

func test_ac13_satchel_and_passive_fill_the_hand_exactly_to_hand_size() -> void:
	# Act
	_start([SATCHEL], HAND_PASSIVE)

	# Assert — the fold reads one past the bound. `_draw`'s full-hand burn would also
	# stop at 10, so the no-burn case below is what tells the clamp from it
	var hand_size: int = _engine.rule("hand_size")
	assert_int(_player_base_hand() + SATCHEL_DELTA + PASSIVE_HAND_DELTA).is_greater(hand_size)
	assert_int(_player().hand.size()).is_equal(hand_size)


func test_ac13_the_passive_alone_folds_under_the_clamp() -> void:
	# Act
	_start([], HAND_PASSIVE)

	# Assert — it lands on the player's hand, and each delta counts
	assert_int(_player().hand.size()).is_equal(_player_base_hand() + PASSIVE_HAND_DELTA)


func test_ac13_no_card_burns_during_the_deal() -> void:
	# Act
	_start([SATCHEL], HAND_PASSIVE)

	# Assert
	assert_array(_of_type("card_burned")).is_empty()


func test_ac13_the_match_reaches_mulligan_without_a_fault() -> void:
	# Act
	_start([SATCHEL], HAND_PASSIVE)

	# Assert
	assert_str(_engine.phase()).is_equal(MatchState.PHASE_MULLIGAN)
	assert_array(_of_type("match_ended")).is_empty()
	assert_str(str(_log.events.back().type)).is_equal("mulligan_offered")


func test_ac13_a_passive_scoped_to_the_opponent_leaves_the_boss_hand() -> void:
	# Act
	_start([SATCHEL], HAND_PASSIVE)

	# Assert
	assert_int(_boss().hand.size()).is_equal(_engine.rule("starting_hand_boss"))


func test_ac13_the_mulligan_mask_follows_the_clamped_hand() -> void:
	# Arrange
	_start([SATCHEL], HAND_PASSIVE)

	# Act
	var result: Dictionary = _engine.submit(MatchRecords.mulligan(_keep_all(_engine.rule("hand_size"))))

	# Assert
	assert_bool(result.accepted).is_true()


# --- AC-23: Twin Grip -------------------------------------------------------------

func test_ac23_a_two_durability_weapon_swings_twice_and_breaks_on_the_second() -> void:
	# Arrange
	_armed([TWIN_GRIP], BLADE_2)

	# Act
	_swing()
	var broken_after_first: int = _of_type("weapon_destroyed").size()
	_swing()

	# Assert
	assert_int(_of_type("attack_resolved").size()).is_equal(TWIN_GRIP_ATTACKS)
	assert_int(broken_after_first).is_equal(0)
	assert_int(_of_type("weapon_destroyed").size()).is_equal(1)
	assert_that(_player().weapon).is_null()


func test_ac23_a_third_attack_after_the_weapon_broke_is_cannot_attack() -> void:
	# Arrange
	_armed([TWIN_GRIP], BLADE_2)
	_swing()
	_swing()

	# Act
	var result: Dictionary = _engine.submit(_swing_command())

	# Assert
	_assert_rejected(result, "CANNOT_ATTACK")
	assert_int(_of_type("attack_resolved").size()).is_equal(TWIN_GRIP_ATTACKS)


func test_ac23_a_third_attack_with_the_weapon_still_held_is_cannot_attack() -> void:
	# Arrange: durability left over, so the count alone stops the third swing
	_armed([TWIN_GRIP], BLADE_5)
	_swing()
	_swing()

	# Act
	var result: Dictionary = _engine.submit(_swing_command())

	# Assert
	_assert_rejected(result, "CANNOT_ATTACK")
	assert_int(int(_player().weapon.durability)).is_equal(LONG_DURABILITY - TWIN_GRIP_ATTACKS)
	assert_array(_legal_attacks()).is_empty()


func test_ac23_without_twin_grip_a_plain_weapon_swings_once() -> void:
	# Arrange
	_armed([], BLADE_5)
	_swing()

	# Act
	var result: Dictionary = _engine.submit(_swing_command())

	# Assert — the control: the second swing above is the treasure's doing
	_assert_rejected(result, "CANNOT_ATTACK")


func test_ac23_a_windfury_weapon_still_swings_only_twice() -> void:
	# Arrange
	_armed([TWIN_GRIP], WINDFURY_BLADE)
	_swing()
	_swing()

	# Act
	var result: Dictionary = _engine.submit(_swing_command())

	# Assert — F3: `set 2` replaces the base 2
	_assert_rejected(result, "CANNOT_ATTACK")
	assert_int(_engine.max_attacks(_player().hero)).is_equal(TWIN_GRIP_ATTACKS)
	assert_int(int(_player().weapon.durability)).is_equal(WINDFURY_DURABILITY - TWIN_GRIP_ATTACKS)


func test_ac23_each_swing_names_the_hero_as_the_damage_source() -> void:
	# Arrange
	_armed([TWIN_GRIP], BLADE_2)
	var hero_id: int = int(_player().hero.entity_id)

	# Act
	_swing()
	_swing()

	# Assert — DD-X15: the hero, not the weapon
	var sources: Array = _of_type("damage_dealt").map(func(e: Dictionary) -> int: return int(e.payload.source))
	assert_array(sources).is_equal([hero_id, hero_id])


func test_twin_grip_reaches_the_owner_hero_only() -> void:
	# Arrange
	_armed([TWIN_GRIP], BLADE_5)
	var minion: Dictionary = MatchFactory.summon(_engine.state(), SIDE_PLAYER, 1, 1)

	# Act
	var attacks: Array = [_engine.max_attacks(_player().hero), _engine.max_attacks(minion), _engine.max_attacks(_boss().hero)]

	# Assert — `who: owner_hero`, from the entry's side
	assert_array(attacks).is_equal([TWIN_GRIP_ATTACKS, 1, 1])


func test_a_fold_past_the_attack_cap_is_clamped_once_after_the_fold() -> void:
	# Arrange
	_armed([TWIN_GRIP], BLADE_5, ATTACK_PASSIVE)
	var cap: int = _engine.rule("max_attacks_cap")
	assert_int(TWIN_GRIP_ATTACKS + PASSIVE_ATTACK_DELTA).is_greater(cap)

	# Act
	var attacks: int = _engine.max_attacks(_player().hero)

	# Assert
	assert_int(attacks).is_equal(cap)


# --- Edge Cases "Value folds and clamps": the first swing breaks the weapon --------

func test_a_one_durability_weapon_leaves_an_attack_the_hero_cannot_use() -> void:
	# Arrange
	_armed([TWIN_GRIP], BLADE_1)

	# Act
	_swing()

	# Assert
	var hero: Dictionary = _player().hero
	assert_that(_player().weapon).is_null()
	assert_int(_engine.attack(hero)).is_equal(0)
	assert_int(_engine.attacks_remaining(hero)).is_equal(1)
	assert_array(_legal_attacks()).is_empty()


func test_the_leftover_attack_is_cannot_attack() -> void:
	# Arrange
	_armed([TWIN_GRIP], BLADE_1)
	_swing()

	# Act
	var result: Dictionary = _engine.submit(_swing_command())

	# Assert
	_assert_rejected(result, "CANNOT_ATTACK")
	assert_int(_of_type("attack_resolved").size()).is_equal(1)
