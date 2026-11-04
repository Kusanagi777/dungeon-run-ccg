## Unit tests for the attack legality predicate (story match-rules/story-012;
## design/gdd/match-rules.md C8 legality bullets, F3 `can_attack`, C12 Taunt /
## Charge / Rush / Stealth / Windfury rows, C2 `attack` row and
## `legal_commands()`, Edge Cases "Combat"; ADR-0005 `modify_max_attacks`
## fold-then-clamp; ADR-0001 illegal moves are data).
##
## Matches start through `MatchFactory.make_started_engine` and a "keep all"
## mulligan (turn 1, player Main). Boards are fixture moves
## (`MatchFactory.summon`; a minion is summoning-sick until a test readies it).
## Defenders have enough health that no accepted attack kills anything, so
## these tests read the same once story 013 resolves the attack.
extends GdUnitTestSuite

const SIDE_PLAYER: String = MatchFactory.SIDE_PLAYER
const SIDE_BOSS: String = MatchFactory.SIDE_BOSS
## Fixture stats: an attacker that can swing, a defender that survives it.
const ATK: int = 2
const SAFE_HEALTH: int = 10
const WEAPON_ATTACK: int = 2
const WEAPON_DURABILITY: int = 2
## `modify_max_attacks` hook values (AC-17): `set 2`, a `set 9` past the cap,
## a negative `set`, and a `delta` pair whose net is 0 only without a clamp
## between entries.
const HOOK_SET_TWO: int = 2
const HOOK_SET_OVER_CAP: int = 9
const HOOK_SET_NEGATIVE: int = -3
const HOOK_DELTA_DOWN: int = -2
const HOOK_DELTA_UP: int = 2
## An entity id no record carries.
const NO_SUCH_ID: int = 9999


# --- helpers -----------------------------------------------------------------

## A started engine past the mulligan: turn 1, player Main.
func _engine(overrides: Dictionary = {}) -> RulesEngine:
	var engine: RulesEngine = MatchFactory.make_started_engine(null, null, overrides)
	assert_bool(engine.submit(engine.legal_commands()[0]).accepted).is_true()
	assert_str(engine.phase()).is_equal(MatchState.PHASE_MAIN)
	return engine


## A minion on [param side]'s board; [param ready] clears summoning sickness
## (it entered play on an earlier turn). Returns its entity id.
func _minion(engine: RulesEngine, side: String, attack: int, health: int, keywords: Array = [], ready: bool = true) -> int:
	var minion: Dictionary = MatchFactory.summon(engine.state(), side, attack, health, -1, keywords)
	if ready:
		minion.summoning_sick = false
	return int(minion.entity_id)


func _record(engine: RulesEngine, entity_id: int) -> Dictionary:
	return MatchFactory.find_entity(engine.state(), entity_id)


func _hero_id(engine: RulesEngine, side: String) -> int:
	return int(engine.state().players[side].hero.entity_id)


## Equips [param side]'s hero with a fixture weapon (a fixture move).
func _equip(engine: RulesEngine, side: String, keywords: Array = []) -> Dictionary:
	var weapon: Dictionary = MatchFactory.make_weapon(MatchFactory.alloc_entity_id(engine.state()), WEAPON_ATTACK, WEAPON_DURABILITY, "", keywords)
	engine.state().players[side].weapon = weapon
	return weapon


func _attack(engine: RulesEngine, attacker_id: int, target_id: int, issuer: String = SIDE_PLAYER) -> Dictionary:
	return engine.submit(MatchRecords.attack(issuer, attacker_id, target_id))


## "" for an accepted command, else its rejection code.
func _code(result: Dictionary) -> String:
	return "" if result.accepted else str(result.rejection.code)


## A player treasure whose one effect is a `modify_max_attacks` value hook.
func _max_attacks_hook(host_id: String, op: Dictionary) -> HookInstaller:
	var effect: Dictionary = {
		"id": "%s.0" % host_id, "trigger": "modify_max_attacks", "scope": {}, "condition": {},
		"ops": [op], "once_per_turn": false,
	}
	return HookInstaller.new(HookInstaller.HOST_KIND_TREASURE, host_id, StringName(SIDE_PLAYER), [effect])


func _hooked_engine(installers: Array) -> RulesEngine:
	return _engine({"player": {"hook_installers": installers}})


## Every hero and board minion of both sides.
func _all_characters(engine: RulesEngine) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for side: String in MatchRecords.SIDES:
		var player: Dictionary = engine.state().players[side]
		out.append(player.hero)
		out.append_array(player.board)
	return out


## The `attacker>target` pairs among [param commands]' `attack` commands.
func _attack_pairs(commands: Array) -> Array[String]:
	var out: Array[String] = []
	for command: Dictionary in commands:
		if command.type == MatchRecords.CMD_ATTACK:
			out.append("%d>%d" % [int(command.attacker_id), int(command.target_id)])
	return out


# --- AC-12: summoning sickness, Rush, Charge -----------------------------------

func test_minion_played_this_turn_without_charge_or_rush_is_summoning_sick() -> void:
	# Arrange
	var engine: RulesEngine = _engine()
	var sick: int = _minion(engine, SIDE_PLAYER, ATK, SAFE_HEALTH, [], false)
	var enemy: int = _minion(engine, SIDE_BOSS, 0, SAFE_HEALTH)

	# Act / Assert
	assert_str(_code(_attack(engine, sick, _hero_id(engine, SIDE_BOSS)))).is_equal("SUMMONING_SICK")
	assert_str(_code(_attack(engine, sick, enemy))).is_equal("SUMMONING_SICK")
	assert_int(int(_record(engine, sick).attacks_used)).is_equal(0)


func test_rush_minion_cannot_hit_the_hero_but_may_hit_a_minion() -> void:
	# Arrange
	var engine: RulesEngine = _engine()
	var rusher: int = _minion(engine, SIDE_PLAYER, ATK, SAFE_HEALTH, ["rush"], false)
	var enemy: int = _minion(engine, SIDE_BOSS, 0, SAFE_HEALTH)

	# Act / Assert
	assert_str(_code(_attack(engine, rusher, _hero_id(engine, SIDE_BOSS)))).is_equal("RUSH_CANNOT_HIT_HERO")
	assert_str(_code(_attack(engine, rusher, enemy))).is_equal("")


func test_charge_minion_may_hit_any_target_and_supersedes_rush() -> void:
	# Arrange
	var engine: RulesEngine = _engine()
	var charger: int = _minion(engine, SIDE_PLAYER, ATK, SAFE_HEALTH, ["charge"], false)
	var both: int = _minion(engine, SIDE_PLAYER, ATK, SAFE_HEALTH, ["charge", "rush"], false)
	var boss_hero: int = _hero_id(engine, SIDE_BOSS)

	# Act / Assert
	assert_str(_code(_attack(engine, charger, boss_hero))).is_equal("")
	assert_str(_code(_attack(engine, both, boss_hero))).is_equal("")


func test_summoning_sickness_is_gone_on_the_next_own_turn() -> void:
	# Arrange
	var engine: RulesEngine = _engine()
	var plain: int = _minion(engine, SIDE_PLAYER, ATK, SAFE_HEALTH, [], false)
	var rusher: int = _minion(engine, SIDE_PLAYER, ATK, SAFE_HEALTH, ["rush"], false)
	var boss_hero: int = _hero_id(engine, SIDE_BOSS)

	# Act: the player's turn ends, the boss passes, the player's next Start step
	assert_bool(engine.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()
	assert_bool(engine.submit(MatchRecords.end_turn(SIDE_BOSS)).accepted).is_true()

	# Assert: both attack anything, the Rush minion the hero included
	assert_str(String(engine.active_side())).is_equal(SIDE_PLAYER)
	assert_str(_code(_attack(engine, plain, boss_hero))).is_equal("")
	assert_str(_code(_attack(engine, rusher, boss_hero))).is_equal("")


# --- AC-17: Taunt, Stealth, targets, attack 0, modify_max_attacks ---------------

func test_a_taunt_minion_must_be_attacked_before_anything_else() -> void:
	# Arrange
	var engine: RulesEngine = _engine()
	var attacker: int = _minion(engine, SIDE_PLAYER, ATK, SAFE_HEALTH)
	var taunt: int = _minion(engine, SIDE_BOSS, 0, SAFE_HEALTH, ["taunt"])
	var plain: int = _minion(engine, SIDE_BOSS, 0, SAFE_HEALTH)

	# Act / Assert
	assert_str(_code(_attack(engine, attacker, plain))).is_equal("MUST_ATTACK_TAUNT")
	assert_str(_code(_attack(engine, attacker, _hero_id(engine, SIDE_BOSS)))).is_equal("MUST_ATTACK_TAUNT")
	assert_str(_code(_attack(engine, attacker, taunt))).is_equal("")


func test_a_stealth_taunt_is_not_a_taunter_and_cannot_be_attacked() -> void:
	# Arrange
	var engine: RulesEngine = _engine()
	var first: int = _minion(engine, SIDE_PLAYER, ATK, SAFE_HEALTH)
	var second: int = _minion(engine, SIDE_PLAYER, ATK, SAFE_HEALTH)
	var hidden_taunt: int = _minion(engine, SIDE_BOSS, 0, SAFE_HEALTH, ["taunt", "stealth"])
	var plain: int = _minion(engine, SIDE_BOSS, 0, SAFE_HEALTH)

	# Act / Assert: taunters = ∅, so anything but the stealthed minion
	assert_str(_code(_attack(engine, first, hidden_taunt))).is_equal("TARGET_STEALTHED")
	assert_str(_code(_attack(engine, first, plain))).is_equal("")
	assert_str(_code(_attack(engine, second, _hero_id(engine, SIDE_BOSS)))).is_equal("")


func test_a_friendly_or_not_in_play_target_is_an_illegal_target() -> void:
	# Arrange
	var engine: RulesEngine = _engine()
	var attacker: int = _minion(engine, SIDE_PLAYER, ATK, SAFE_HEALTH)
	var friend: int = _minion(engine, SIDE_PLAYER, ATK, SAFE_HEALTH)
	var hand_card: int = int(engine.state().players[SIDE_BOSS].hand[0].instance_id)

	# Act / Assert
	assert_str(_code(_attack(engine, attacker, friend))).is_equal("ILLEGAL_TARGET")
	assert_str(_code(_attack(engine, attacker, _hero_id(engine, SIDE_PLAYER)))).is_equal("ILLEGAL_TARGET")
	assert_str(_code(_attack(engine, attacker, hand_card))).is_equal("ILLEGAL_TARGET")
	assert_str(_code(_attack(engine, attacker, NO_SUCH_ID))).is_equal("ILLEGAL_TARGET")


func test_an_attacker_with_attack_zero_or_no_attacks_left_cannot_attack() -> void:
	# Arrange: a hero with no weapon and no buff; a minion debuffed to 0; a
	# minion that already attacked this turn
	var engine: RulesEngine = _engine()
	var debuffed: int = _minion(engine, SIDE_PLAYER, ATK, SAFE_HEALTH)
	_record(engine, debuffed).enchantments.append(MatchFactory.make_enchantment(-ATK))
	var spent: int = _minion(engine, SIDE_PLAYER, ATK, SAFE_HEALTH)
	_record(engine, spent).attacks_used = 1
	var boss_hero: int = _hero_id(engine, SIDE_BOSS)

	# Act / Assert
	assert_str(_code(_attack(engine, _hero_id(engine, SIDE_PLAYER), boss_hero))).is_equal("CANNOT_ATTACK")
	assert_str(_code(_attack(engine, debuffed, boss_hero))).is_equal("CANNOT_ATTACK")
	assert_str(_code(_attack(engine, spent, boss_hero))).is_equal("CANNOT_ATTACK")
	assert_str(_code(_attack(engine, NO_SUCH_ID, boss_hero))).is_equal("CANNOT_ATTACK")


func test_a_max_attacks_hook_set_two_lets_a_non_windfury_minion_attack_twice() -> void:
	# Arrange
	var engine: RulesEngine = _hooked_engine([_max_attacks_hook("t_twin", {"op": "modify_value", "set": HOOK_SET_TWO})])
	var attacker: int = _minion(engine, SIDE_PLAYER, ATK, SAFE_HEALTH)
	var boss_hero: int = _hero_id(engine, SIDE_BOSS)

	# Act / Assert
	assert_int(engine.max_attacks(_record(engine, attacker))).is_equal(HOOK_SET_TWO)
	assert_str(_code(_attack(engine, attacker, boss_hero))).is_equal("")
	assert_str(_code(_attack(engine, attacker, boss_hero))).is_equal("")
	assert_str(_code(_attack(engine, attacker, boss_hero))).is_equal("CANNOT_ATTACK")


func test_the_max_attacks_fold_is_clamped_once_to_zero_and_the_cap() -> void:
	# Arrange
	var over: RulesEngine = _hooked_engine([_max_attacks_hook("t_many", {"op": "modify_value", "set": HOOK_SET_OVER_CAP})])
	var under: RulesEngine = _hooked_engine([_max_attacks_hook("t_none", {"op": "modify_value", "set": HOOK_SET_NEGATIVE})])
	# 1 − 2 + 2 = 1 unclamped; a clamp after the first entry would give 0 + 2 = 2
	var chain: RulesEngine = _hooked_engine([
		_max_attacks_hook("t_down", {"op": "modify_value", "delta": HOOK_DELTA_DOWN}),
		_max_attacks_hook("t_up", {"op": "modify_value", "delta": HOOK_DELTA_UP}),
	])
	var over_id: int = _minion(over, SIDE_PLAYER, ATK, SAFE_HEALTH)
	var under_id: int = _minion(under, SIDE_PLAYER, ATK, SAFE_HEALTH)
	var chain_id: int = _minion(chain, SIDE_PLAYER, ATK, SAFE_HEALTH)

	# Act
	var boss_hero: int = _hero_id(over, SIDE_BOSS)
	var accepted: int = 0
	for _i: int in HOOK_SET_OVER_CAP:
		if _attack(over, over_id, boss_hero).accepted:
			accepted += 1

	# Assert: set 9 yields MAX_ATTACKS_CAP attacks, a negative set yields 0
	assert_int(accepted).is_equal(TestConstants.MAX_ATTACKS_CAP)
	assert_int(over.max_attacks(_record(over, over_id))).is_equal(TestConstants.MAX_ATTACKS_CAP)
	assert_int(under.max_attacks(_record(under, under_id))).is_equal(0)
	assert_str(_code(_attack(under, under_id, _hero_id(under, SIDE_BOSS)))).is_equal("CANNOT_ATTACK")
	assert_int(chain.max_attacks(_record(chain, chain_id))).is_equal(1)


func test_windfury_from_a_keyword_an_enchantment_or_the_hero_weapon_gives_two_attacks() -> void:
	# Arrange
	var engine: RulesEngine = _engine()
	var keyword: int = _minion(engine, SIDE_PLAYER, ATK, SAFE_HEALTH, ["windfury"])
	var granted: int = _minion(engine, SIDE_PLAYER, ATK, SAFE_HEALTH)
	_record(engine, granted).enchantments.append(MatchFactory.make_enchantment(0, 0, ["windfury"]))
	var plain: int = _minion(engine, SIDE_PLAYER, ATK, SAFE_HEALTH)
	var hero: Dictionary = _record(engine, _hero_id(engine, SIDE_PLAYER))

	# Act / Assert
	assert_int(engine.max_attacks(_record(engine, keyword))).is_equal(TestConstants.MAX_ATTACKS_WINDFURY)
	assert_int(engine.max_attacks(_record(engine, granted))).is_equal(TestConstants.MAX_ATTACKS_WINDFURY)
	assert_int(engine.max_attacks(_record(engine, plain))).is_equal(1)
	assert_int(engine.max_attacks(hero)).is_equal(1)
	_equip(engine, SIDE_PLAYER, ["windfury"])
	assert_int(engine.max_attacks(hero)).is_equal(TestConstants.MAX_ATTACKS_WINDFURY)


func test_windfury_granted_to_the_hero_weapon_by_an_enchantment_gives_two_attacks() -> void:
	# Arrange — a plain weapon, then "give your weapon Windfury" (card-effects
	# `give_keyword`: characters and weapons) lands in its enchantments (code
	# review MR-012 S1, probe P1)
	var engine: RulesEngine = _engine()
	var weapon: Dictionary = _equip(engine, SIDE_PLAYER)
	var hero: Dictionary = _record(engine, _hero_id(engine, SIDE_PLAYER))
	assert_int(engine.max_attacks(hero)).is_equal(1)

	# Act
	engine.add_keyword(int(weapon.entity_id), "windfury")

	# Assert
	assert_bool(engine.has_windfury(hero)).is_true()
	assert_int(engine.max_attacks(hero)).is_equal(TestConstants.MAX_ATTACKS_WINDFURY)


func test_keywords_from_enchantments_and_remove_keyword_are_read_at_the_next_evaluation() -> void:
	# Arrange: a Taunt granted by an enchantment; Charge granted to a sick minion
	var engine: RulesEngine = _engine()
	var attacker: int = _minion(engine, SIDE_PLAYER, ATK, SAFE_HEALTH)
	var charger: int = _minion(engine, SIDE_PLAYER, ATK, SAFE_HEALTH, [], false)
	_record(engine, charger).enchantments.append(MatchFactory.make_enchantment(0, 0, ["charge"]))
	var granted_taunt: int = _minion(engine, SIDE_BOSS, 0, SAFE_HEALTH)
	_record(engine, granted_taunt).enchantments.append(MatchFactory.make_enchantment(0, 0, ["taunt"]))
	var plain: int = _minion(engine, SIDE_BOSS, 0, SAFE_HEALTH)

	# Act / Assert
	assert_str(_code(_attack(engine, attacker, plain))).is_equal("MUST_ATTACK_TAUNT")
	engine.remove_keyword(granted_taunt, "taunt")
	assert_str(_code(_attack(engine, attacker, plain))).is_equal("")
	assert_str(_code(_attack(engine, charger, _hero_id(engine, SIDE_BOSS)))).is_equal("")


# --- AC-20: Freeze, legal_commands, the inactive side ----------------------------

func test_a_frozen_hero_with_a_weapon_is_attacker_frozen_and_keeps_its_durability() -> void:
	# Arrange
	var engine: RulesEngine = _engine()
	var weapon: Dictionary = _equip(engine, SIDE_PLAYER)
	var player: Dictionary = engine.state().players[SIDE_PLAYER]
	player.hero.frozen = true
	player.mana_current = TestConstants.HERO_POWER_COST

	# Act
	var result: Dictionary = _attack(engine, _hero_id(engine, SIDE_PLAYER), _hero_id(engine, SIDE_BOSS))

	# Assert: rejected, durability unchanged; the hero power is still usable
	assert_str(_code(result)).is_equal("ATTACKER_FROZEN")
	assert_int(int(weapon.durability)).is_equal(WEAPON_DURABILITY)
	assert_bool(engine.submit(MatchRecords.use_hero_power(SIDE_PLAYER)).accepted).is_true()


func test_legal_commands_lists_exactly_the_pairs_can_attack_accepts_for_the_active_side() -> void:
	# Arrange: ready, sick, Rush, frozen and 0-attack minions, an armed hero;
	# the boss has a plain minion, a Stealth minion and a ready attacker
	var engine: RulesEngine = _engine()
	var ready: int = _minion(engine, SIDE_PLAYER, ATK, SAFE_HEALTH)
	@warning_ignore("return_value_discarded")
	_minion(engine, SIDE_PLAYER, ATK, SAFE_HEALTH, [], false)
	var rusher: int = _minion(engine, SIDE_PLAYER, ATK, SAFE_HEALTH, ["rush"], false)
	var frozen: int = _minion(engine, SIDE_PLAYER, ATK, SAFE_HEALTH)
	_record(engine, frozen).frozen = true
	@warning_ignore("return_value_discarded")
	_minion(engine, SIDE_PLAYER, 0, SAFE_HEALTH)
	@warning_ignore("return_value_discarded")
	_equip(engine, SIDE_PLAYER)
	var plain: int = _minion(engine, SIDE_BOSS, ATK, SAFE_HEALTH)
	@warning_ignore("return_value_discarded")
	_minion(engine, SIDE_BOSS, ATK, SAFE_HEALTH, ["stealth"])
	var hero: int = _hero_id(engine, SIDE_PLAYER)
	var boss_hero: int = _hero_id(engine, SIDE_BOSS)

	# Act
	var commands: Array = engine.legal_commands()
	var listed: Array[String] = _attack_pairs(commands)
	var accepted: Array[String] = []
	for attacker: Dictionary in _all_characters(engine):
		for defender: Dictionary in _all_characters(engine):
			if engine.can_attack(int(attacker.entity_id), int(defender.entity_id)).ok:
				accepted.append("%d>%d" % [int(attacker.entity_id), int(defender.entity_id)])

	# Assert: the listed pairs are exactly can_attack's, none from the boss
	var expected: Array[String] = [
		"%d>%d" % [hero, boss_hero], "%d>%d" % [hero, plain],
		"%d>%d" % [ready, boss_hero], "%d>%d" % [ready, plain],
		"%d>%d" % [rusher, plain],
	]
	assert_array(listed).contains_exactly_in_any_order(expected)
	assert_array(accepted).contains_exactly_in_any_order(expected)
	assert_str(str(commands[commands.size() - 1].type)).is_equal(MatchRecords.CMD_END_TURN)
	assert_str(_code(_attack(engine, plain, hero, SIDE_BOSS))).is_equal("NOT_YOUR_TURN")


func test_legal_commands_under_a_taunt_lists_only_the_taunt_as_defender() -> void:
	# Arrange
	var engine: RulesEngine = _engine()
	var first: int = _minion(engine, SIDE_PLAYER, ATK, SAFE_HEALTH)
	var second: int = _minion(engine, SIDE_PLAYER, ATK, SAFE_HEALTH)
	var taunt: int = _minion(engine, SIDE_BOSS, 0, SAFE_HEALTH, ["taunt"])
	@warning_ignore("return_value_discarded")
	_minion(engine, SIDE_BOSS, 0, SAFE_HEALTH)

	# Act
	var listed: Array[String] = _attack_pairs(engine.legal_commands())

	# Assert
	assert_array(listed).contains_exactly_in_any_order(["%d>%d" % [first, taunt], "%d>%d" % [second, taunt]])


func test_attack_rejections_follow_the_f3_term_order() -> void:
	# Arrange: attackers failing several terms at once
	var engine: RulesEngine = _engine()
	var frozen_zero: int = _minion(engine, SIDE_PLAYER, 0, SAFE_HEALTH)
	_record(engine, frozen_zero).frozen = true
	var frozen_sick: int = _minion(engine, SIDE_PLAYER, ATK, SAFE_HEALTH, [], false)
	_record(engine, frozen_sick).frozen = true
	var sick: int = _minion(engine, SIDE_PLAYER, ATK, SAFE_HEALTH, [], false)
	var ready: int = _minion(engine, SIDE_PLAYER, ATK, SAFE_HEALTH)
	var friendly_stealth: int = _minion(engine, SIDE_PLAYER, ATK, SAFE_HEALTH, ["stealth"])
	@warning_ignore("return_value_discarded")
	_minion(engine, SIDE_BOSS, 0, SAFE_HEALTH, ["taunt"])
	var enemy_stealth: int = _minion(engine, SIDE_BOSS, 0, SAFE_HEALTH, ["stealth"])
	var boss_minion: int = _minion(engine, SIDE_BOSS, ATK, SAFE_HEALTH)

	# Act / Assert: the first false term names the code
	assert_str(_code(_attack(engine, frozen_zero, enemy_stealth))).is_equal("CANNOT_ATTACK")
	assert_str(_code(_attack(engine, frozen_sick, friendly_stealth))).is_equal("ATTACKER_FROZEN")
	assert_str(_code(_attack(engine, sick, friendly_stealth))).is_equal("SUMMONING_SICK")
	assert_str(_code(_attack(engine, ready, friendly_stealth))).is_equal("ILLEGAL_TARGET")
	assert_str(_code(_attack(engine, ready, enemy_stealth))).is_equal("TARGET_STEALTHED")
	# the phase term: an enemy character cannot attack in the player's Main
	assert_str(_code(_attack(engine, boss_minion, _hero_id(engine, SIDE_PLAYER)))).is_equal("NOT_YOUR_TURN")
	assert_str(str(engine.can_attack(boss_minion, _hero_id(engine, SIDE_PLAYER)).code)).is_equal("NOT_YOUR_TURN")
