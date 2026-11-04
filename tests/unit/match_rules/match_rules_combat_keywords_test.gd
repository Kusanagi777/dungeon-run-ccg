## Unit tests for Windfury, Stealth and Divine Shield in combat (story
## match-rules/story-014; design/gdd/match-rules.md C12 Windfury / Stealth /
## Divine Shield / Poisonous / Lifesteal rows, C8 Windfury paragraph and step 1,
## C9, Edge Cases "Combat" and "Keywords and status"; ADR-0007 keyword
## consequences that are match rules are engine behaviour in the log).
##
## Matches start through `MatchFactory.make_started_engine` and a "keep all"
## mulligan (turn 1, player Main). Keyworded minions are fixture moves
## (`MatchFactory.summon` with the keyword list); state is read back through
## `MatchFactory.find_entity`.
extends GdUnitTestSuite

const SIDE_PLAYER: String = MatchFactory.SIDE_PLAYER
const SIDE_BOSS: String = MatchFactory.SIDE_BOSS
## AC-18: a Windfury 2/5 against two enemy 1/1s.
const WINDFURY_ATTACK: int = 2
const WINDFURY_HEALTH: int = 5
const SMALL: int = 1
## AC-22: a Poisonous Lifesteal attacker hitting for 4; a shielded 2/3.
const VENOM_ATTACK: int = 4
const VENOM_HEALTH: int = 6
const SHIELDED_ATTACK: int = 2
const SHIELDED_HEALTH: int = 3
## AC-22 second half: a Poisonous 1/1 into a 2/5 that kills it.
const BRUISER_ATTACK: int = 2
const BRUISER_HEALTH: int = 5
## Generic fixture stats: a ready attacker and a defender that survives it.
const ATK: int = 2
const SAFE_HEALTH: int = 10
## An "area effect" hit on a stealthed minion (AC-26).
const AREA_DAMAGE: int = 1


# --- helpers -----------------------------------------------------------------

func _engine(log: TestEventLog) -> RulesEngine:
	var engine: RulesEngine = MatchFactory.make_started_engine(null, log)
	assert_bool(engine.submit(engine.legal_commands()[0]).accepted).is_true()
	return engine


## A ready (not summoning-sick) minion on [param side]'s board; its entity id.
func _minion(engine: RulesEngine, side: String, attack: int, health: int, keywords: Array = []) -> int:
	var minion: Dictionary = MatchFactory.summon(engine.state(), side, attack, health, -1, keywords)
	minion.summoning_sick = false
	return int(minion.entity_id)


func _record(engine: RulesEngine, entity_id: int) -> Dictionary:
	return MatchFactory.find_entity(engine.state(), entity_id)


func _hero_id(engine: RulesEngine, side: String) -> int:
	return int(engine.state().players[side].hero.entity_id)


func _attack(engine: RulesEngine, attacker_id: int, target_id: int, issuer: String = SIDE_PLAYER) -> Dictionary:
	return engine.submit(MatchRecords.attack(issuer, attacker_id, target_id))


func _code(result: Dictionary) -> String:
	return "" if result.accepted else str(result.rejection.code)


func _of(events: Array, type: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for event: Dictionary in events:
		if event.type == String(type):
			out.append(event)
	return out


## The player ends the turn and the boss's Main begins.
func _pass_to_boss(engine: RulesEngine) -> void:
	assert_bool(engine.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()
	assert_str(String(engine.active_side())).is_equal(SIDE_BOSS)


# --- AC-18: Windfury --------------------------------------------------------------

func test_a_windfury_minion_attacks_twice_as_two_commands_and_not_a_third_time() -> void:
	# Arrange: a Windfury 2/5; the enemy has a Taunt 1/1 and a plain 1/1
	var engine: RulesEngine = _engine(TestEventLog.new())
	var windfury: int = _minion(engine, SIDE_PLAYER, WINDFURY_ATTACK, WINDFURY_HEALTH, ["windfury"])
	var taunt: int = _minion(engine, SIDE_BOSS, SMALL, SMALL, ["taunt"])
	var plain: int = _minion(engine, SIDE_BOSS, SMALL, SMALL)
	assert_str(_code(_attack(engine, windfury, plain))).is_equal("MUST_ATTACK_TAUNT")

	# Act: the first target dies; the second command names a new legal target
	var first: Dictionary = _attack(engine, windfury, taunt)
	var after_first: int = int(_record(engine, windfury).damage_taken)
	var second: Dictionary = _attack(engine, windfury, plain)
	var third: Dictionary = _attack(engine, windfury, _hero_id(engine, SIDE_BOSS))

	# Assert: the Taunt rule was re-evaluated for the second command
	assert_bool(first.accepted).is_true()
	assert_bool(_record(engine, taunt).is_empty()).is_true()
	assert_int(after_first).is_equal(SMALL)
	assert_bool(second.accepted).is_true()
	assert_int(int(_record(engine, windfury).damage_taken)).is_equal(2 * SMALL)
	assert_int(int(_record(engine, windfury).attacks_used)).is_equal(TestConstants.MAX_ATTACKS_WINDFURY)
	assert_str(_code(third)).is_equal("CANNOT_ATTACK")


func test_attacks_used_resets_at_the_start_step() -> void:
	# Arrange
	var engine: RulesEngine = _engine(TestEventLog.new())
	var windfury: int = _minion(engine, SIDE_PLAYER, WINDFURY_ATTACK, WINDFURY_HEALTH, ["windfury"])
	var boss_hero: int = _hero_id(engine, SIDE_BOSS)
	assert_bool(_attack(engine, windfury, boss_hero).accepted).is_true()
	assert_bool(_attack(engine, windfury, boss_hero).accepted).is_true()

	# Act: the boss's turn passes; the player's Start step runs
	_pass_to_boss(engine)
	assert_bool(engine.submit(MatchRecords.end_turn(SIDE_BOSS)).accepted).is_true()

	# Assert
	assert_int(int(_record(engine, windfury).attacks_used)).is_equal(0)
	assert_int(engine.attacks_remaining(_record(engine, windfury))).is_equal(TestConstants.MAX_ATTACKS_WINDFURY)


func test_gaining_windfury_after_one_attack_grants_one_more() -> void:
	# Arrange: two minions attack once each, then gain Windfury — through
	# add_keyword and through an enchantment
	var engine: RulesEngine = _engine(TestEventLog.new())
	var by_keyword: int = _minion(engine, SIDE_PLAYER, ATK, SAFE_HEALTH)
	var by_enchantment: int = _minion(engine, SIDE_PLAYER, ATK, SAFE_HEALTH)
	var boss_hero: int = _hero_id(engine, SIDE_BOSS)
	assert_bool(_attack(engine, by_keyword, boss_hero).accepted).is_true()
	assert_bool(_attack(engine, by_enchantment, boss_hero).accepted).is_true()
	assert_str(_code(_attack(engine, by_keyword, boss_hero))).is_equal("CANNOT_ATTACK")

	# Act
	engine.run_action(func() -> void:
		engine.add_keyword(by_keyword, MatchRecords.KEYWORD_WINDFURY)
		engine.apply_enchantment(by_enchantment, {"keywords_added": [MatchRecords.KEYWORD_WINDFURY]}))

	# Assert: attacks_remaining is derived live — one more each
	assert_int(engine.attacks_remaining(_record(engine, by_keyword))).is_equal(1)
	assert_int(engine.attacks_remaining(_record(engine, by_enchantment))).is_equal(1)
	assert_bool(_attack(engine, by_keyword, boss_hero).accepted).is_true()
	assert_bool(_attack(engine, by_enchantment, boss_hero).accepted).is_true()
	assert_str(_code(_attack(engine, by_keyword, boss_hero))).is_equal("CANNOT_ATTACK")


func test_losing_windfury_after_one_attack_leaves_no_attacks() -> void:
	# Arrange
	var engine: RulesEngine = _engine(TestEventLog.new())
	var windfury: int = _minion(engine, SIDE_PLAYER, ATK, SAFE_HEALTH, ["windfury"])
	var boss_hero: int = _hero_id(engine, SIDE_BOSS)
	assert_bool(_attack(engine, windfury, boss_hero).accepted).is_true()

	# Act
	engine.run_action(func() -> void: engine.remove_keyword(windfury, MatchRecords.KEYWORD_WINDFURY))

	# Assert
	assert_int(engine.attacks_remaining(_record(engine, windfury))).is_equal(0)
	assert_str(_code(_attack(engine, windfury, boss_hero))).is_equal("CANNOT_ATTACK")


# --- AC-22: Divine Shield, Poisonous, Lifesteal ------------------------------------

func test_divine_shield_eats_a_poisonous_lifesteal_hit_and_the_attacker_still_takes_damage() -> void:
	# Arrange: the player hero is damaged so a Lifesteal heal would show
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log)
	var player_hero: Dictionary = engine.state().players[SIDE_PLAYER].hero
	player_hero.damage_taken = VENOM_ATTACK
	var venom: int = _minion(engine, SIDE_PLAYER, VENOM_ATTACK, VENOM_HEALTH, ["poisonous", "lifesteal"])
	var shielded: int = _minion(engine, SIDE_BOSS, SHIELDED_ATTACK, SHIELDED_HEALTH, ["divine_shield"])
	var before: int = log.events.size()

	# Act
	assert_bool(_attack(engine, venom, shielded).accepted).is_true()

	# Assert: popped, 0 dealt, no poison mark, no heal; the strike back lands
	var events: Array = log.events.slice(before)
	assert_int(_of(events, &"divine_shield_popped").size()).is_equal(1)
	var hit: Dictionary = _of(events, &"damage_dealt")[0]
	assert_int(int(hit.payload.target)).is_equal(shielded)
	assert_int(int(hit.payload.dealt)).is_equal(0)
	assert_int(int(hit.payload.prevented)).is_equal(VENOM_ATTACK)
	var survivor: Dictionary = _record(engine, shielded)
	assert_bool(survivor.is_empty()).is_false()
	assert_bool(bool(survivor.get("pending_destroy", false))).is_false()
	assert_bool(MatchFactory.has_keyword(survivor, "divine_shield")).is_false()
	assert_int(_of(events, &"healed").size()).is_equal(0)
	assert_int(int(player_hero.damage_taken)).is_equal(VENOM_ATTACK)
	assert_int(int(_record(engine, venom).damage_taken)).is_equal(SHIELDED_ATTACK)


func test_a_poisonous_attacker_killed_by_its_defender_still_poisons_it_and_both_die_together() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log)
	var poisoner: int = _minion(engine, SIDE_PLAYER, SMALL, SMALL, ["poisonous"])
	var bruiser: int = _minion(engine, SIDE_BOSS, BRUISER_ATTACK, BRUISER_HEALTH)
	var before: int = log.events.size()

	# Act
	assert_bool(_attack(engine, poisoner, bruiser).accepted).is_true()

	# Assert: one death check removes both, player board first (DD-M11)
	assert_bool(_record(engine, poisoner).is_empty()).is_true()
	assert_bool(_record(engine, bruiser).is_empty()).is_true()
	var events: Array = log.events.slice(before)
	EventLogAssertions.assert_consecutive(events, [&"damage_dealt", &"damage_dealt", &"minion_died", &"minion_died"])
	var deaths: Array[Dictionary] = _of(events, &"minion_died")
	assert_int(int(deaths[0].payload.entity_id)).is_equal(poisoner)
	assert_int(int(deaths[1].payload.entity_id)).is_equal(bruiser)


# --- AC-26: Stealth ---------------------------------------------------------------

func test_a_stealth_minion_loses_stealth_when_it_attacks_before_any_damage() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log)
	var lurker: int = _minion(engine, SIDE_PLAYER, ATK, SAFE_HEALTH, ["stealth"])
	var before: int = log.events.size()

	# Act
	assert_bool(_attack(engine, lurker, _hero_id(engine, SIDE_BOSS)).accepted).is_true()

	# Assert: attack_declared, stealth_lost, then the hit; the keyword is gone
	var events: Array = log.events.slice(before)
	EventLogAssertions.assert_consecutive(events, [&"attack_declared", &"stealth_lost"])
	EventLogAssertions.assert_order(events, [&"stealth_lost", &"damage_dealt"])
	assert_int(int(_of(events, &"stealth_lost")[0].payload.entity_id)).is_equal(lurker)
	assert_int(_of(events, &"keyword_removed").size()).is_equal(0)
	assert_bool(MatchFactory.has_keyword(_record(engine, lurker), "stealth")).is_false()


func test_a_minion_that_lost_stealth_is_attackable_and_its_taunt_binds_again() -> void:
	# Arrange: a Stealth Taunt that attacks on the player's turn
	var engine: RulesEngine = _engine(TestEventLog.new())
	var lurker: int = _minion(engine, SIDE_PLAYER, ATK, SAFE_HEALTH, ["stealth", "taunt"])
	var boss_minion: int = _minion(engine, SIDE_BOSS, ATK, SAFE_HEALTH)
	assert_bool(_attack(engine, lurker, _hero_id(engine, SIDE_BOSS)).accepted).is_true()

	# Act: the boss's turn
	_pass_to_boss(engine)
	var at_hero: Dictionary = _attack(engine, boss_minion, _hero_id(engine, SIDE_PLAYER), SIDE_BOSS)
	var at_lurker: Dictionary = _attack(engine, boss_minion, lurker, SIDE_BOSS)

	# Assert: no longer stealthed, it is a taunter and a legal target
	assert_str(_code(at_hero)).is_equal("MUST_ATTACK_TAUNT")
	assert_bool(at_lurker.accepted).is_true()


func test_a_stealth_taunt_that_has_not_attacked_does_not_bind_the_enemy() -> void:
	# Arrange: the player's Stealth Taunt stays hidden
	var engine: RulesEngine = _engine(TestEventLog.new())
	var lurker: int = _minion(engine, SIDE_PLAYER, ATK, SAFE_HEALTH, ["stealth", "taunt"])
	var boss_minion: int = _minion(engine, SIDE_BOSS, ATK, SAFE_HEALTH)

	# Act
	_pass_to_boss(engine)
	var at_lurker: Dictionary = _attack(engine, boss_minion, lurker, SIDE_BOSS)
	var at_hero: Dictionary = _attack(engine, boss_minion, _hero_id(engine, SIDE_PLAYER), SIDE_BOSS)

	# Assert
	assert_str(_code(at_lurker)).is_equal("TARGET_STEALTHED")
	assert_bool(at_hero.accepted).is_true()


func test_area_and_random_damage_still_hit_a_stealthed_minion() -> void:
	# Arrange
	var engine: RulesEngine = _engine(TestEventLog.new())
	var lurker: int = _minion(engine, SIDE_BOSS, ATK, SAFE_HEALTH, ["stealth"])

	# Act: apply_damage never checks Stealth
	engine.run_action(func() -> void:
		@warning_ignore("return_value_discarded")
		engine.apply_damage(lurker, AREA_DAMAGE, null))

	# Assert
	assert_int(int(_record(engine, lurker).damage_taken)).is_equal(AREA_DAMAGE)
	assert_bool(MatchFactory.has_keyword(_record(engine, lurker), "stealth")).is_true()
