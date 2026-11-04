## Unit tests for attack resolution (story match-rules/story-013;
## design/gdd/match-rules.md C8 resolution steps 1–7 — a defending hero never
## deals damage back, DD-X11 / N-05 — Interactions `on_attack`, Edge Cases
## "Combat", DD-M11 simultaneous damage; ADR-0007 the engine owns the steps;
## ADR-0003 consecutive `seq`).
##
## Matches start through `MatchFactory.make_started_engine` and a "keep all"
## mulligan (turn 1, player Main). Boards and weapons are fixture moves;
## `on_attack` responders are scripted on the `TestEffectResolver`
## (`add_on_attack_destroy`, `add_on_attack_summon`, `add_trigger`).
extends GdUnitTestSuite

const SIDE_PLAYER: String = MatchFactory.SIDE_PLAYER
const SIDE_BOSS: String = MatchFactory.SIDE_BOSS
const MARKER: StringName = &"test_on_attack_marker"
## AC-16: a 3/4 attacker and a 2/5 defender.
const AC16_ATTACK: int = 3
const AC16_HEALTH: int = 4
const AC16_DEFENDER_ATTACK: int = 2
const AC16_DEFENDER_HEALTH: int = 5
## AC-19: a 2/2 weapon against a 1/3 minion.
const AC19_WEAPON_ATTACK: int = 2
const AC19_WEAPON_DURABILITY: int = 2
const AC19_MINION_ATTACK: int = 1
const AC19_MINION_HEALTH: int = 3
## DD-X11: the defending hero holds a 3/2 weapon.
const DEFENDER_WEAPON_ATTACK: int = 3
const DEFENDER_WEAPON_DURABILITY: int = 2
## Generic fixture stats: a ready attacker and a defender that survives it.
const ATK: int = 2
const SAFE_HEALTH: int = 10
## The Taunt an `on_attack` trigger summons (AC-21).
const DEF_TAUNT: String = "neutral_test_taunt_0_5"
const TAUNT_COST: int = 1
## The three options a Discover raised by an `on_attack` trigger offers.
const DISCOVER_OPTIONS: Array[String] = ["neutral_test_pick_a", "neutral_test_pick_b", "neutral_test_pick_c"]


class FixtureDb extends RefCounted:
	var cards: Dictionary = {}

	func has(id: String) -> bool:
		return cards.has(id)

	func card(id: String) -> Variant:
		return cards.get(id)


# --- helpers -----------------------------------------------------------------

func _db() -> FixtureDb:
	var db: FixtureDb = FixtureDb.new()
	db.cards[DEF_TAUNT] = CardFactory.make_minion(DEF_TAUNT, TAUNT_COST, 0, SAFE_HEALTH, ["taunt"])
	return db


## A started engine past the mulligan (turn 1, player Main) over [param log]
## and [param resolver].
func _engine(log: TestEventLog, resolver: TestEffectResolver) -> RulesEngine:
	var engine: RulesEngine = MatchFactory.make_started_engine(null, log, {}, {}, resolver, _db())
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


func _equip(engine: RulesEngine, side: String, attack: int, durability: int) -> Dictionary:
	var weapon: Dictionary = MatchFactory.make_weapon(MatchFactory.alloc_entity_id(engine.state()), attack, durability, "neutral_test_axe")
	engine.state().players[side].weapon = weapon
	return weapon


func _attack(engine: RulesEngine, attacker_id: int, target_id: int) -> Dictionary:
	return engine.submit(MatchRecords.attack(SIDE_PLAYER, attacker_id, target_id))


func _since(log: TestEventLog, before: int) -> Array:
	return log.events.slice(before)


func _of(events: Array, type: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for event: Dictionary in events:
		if event.type == String(type):
			out.append(event)
	return out


## `on_attack` pass: emits [constant MARKER] (stands in for "[on_attack trigger events]").
func _emit_marker(engine: RulesEngine, _ctx: Dictionary) -> void:
	@warning_ignore("return_value_discarded")
	engine.emit(MARKER, {})


## `on_attack` pass: raises a Discover for the player (a real resolver would
## then return and keep the rest of its effect as its continuation).
func _discover_for_player(engine: RulesEngine, _ctx: Dictionary) -> void:
	@warning_ignore("return_value_discarded")
	engine.discover(SIDE_PLAYER, DISCOVER_OPTIONS, MatchRecords.CHOICE_DISCOVER, null, "oa.discover")


## Collecting `on_damage` script: when the damaged character is
## [param defender_id], drop its attack to 0 at once — a mutation inside the
## damage step, between the two hits.
func _debuff_when_hit(engine: RulesEngine, ctx: Dictionary, defender_id: int, amount: int) -> void:
	if ctx.get("subject") == defender_id:
		engine.apply_enchantment(defender_id, {"attack_delta": -amount})


# --- AC-16: simultaneous damage and the event order ------------------------------

func test_simultaneous_damage_lands_both_hits_in_one_step_in_the_c8_order() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _engine(log, resolver)
	var attacker: int = _minion(engine, SIDE_PLAYER, AC16_ATTACK, AC16_HEALTH)
	var defender: int = _minion(engine, SIDE_BOSS, AC16_DEFENDER_ATTACK, AC16_DEFENDER_HEALTH)
	resolver.add_trigger(&"on_attack", attacker, "oa.mark", _emit_marker, resolver.attacker_is.bind(attacker))
	var before: int = log.events.size()

	# Act
	var result: Dictionary = _attack(engine, attacker, defender)

	# Assert: the numbers
	assert_bool(result.accepted).is_true()
	assert_int(int(_record(engine, defender).damage_taken)).is_equal(AC16_ATTACK)
	assert_int(int(_record(engine, attacker).damage_taken)).is_equal(AC16_DEFENDER_ATTACK)
	assert_int(int(_record(engine, attacker).attacks_used)).is_equal(1)
	# the order: declared, on_attack triggers, A→D, D→A, the loop, resolved
	var events: Array = _since(log, before)
	EventLogAssertions.assert_order(events, [&"attack_declared", &"trigger_resolved", MARKER, &"damage_dealt", &"damage_dealt", &"attack_resolved"])
	EventLogAssertions.assert_consecutive(events, [&"damage_dealt", &"damage_dealt"])
	var hits: Array[Dictionary] = _of(events, &"damage_dealt")
	assert_int(hits.size()).is_equal(2)
	assert_int(int(hits[0].payload.source)).is_equal(attacker)
	assert_int(int(hits[0].payload.target)).is_equal(defender)
	assert_int(int(hits[1].payload.source)).is_equal(defender)
	assert_int(int(hits[1].payload.target)).is_equal(attacker)
	assert_str(String(log.last().type)).is_equal("attack_resolved")
	# the on_attack trigger point: fired once, attacker and defender named
	var fires: Array = resolver.candidates_for(&"on_attack")
	assert_int(fires.size()).is_equal(1)
	var ctx: Dictionary = resolver.resolve_calls.filter(func(c: Dictionary) -> bool: return c.point == &"on_attack")[0].ctx
	assert_int(int(ctx.attacker)).is_equal(attacker)
	assert_int(int(ctx.defender)).is_equal(defender)


# --- AC-19: hero weapon attacks -------------------------------------------------

func test_a_hero_weapon_attack_takes_the_minions_strike_back_and_spends_durability() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log, TestEffectResolver.new())
	var weapon: Dictionary = _equip(engine, SIDE_PLAYER, AC19_WEAPON_ATTACK, AC19_WEAPON_DURABILITY)
	var hero: int = _hero_id(engine, SIDE_PLAYER)
	var minion: int = _minion(engine, SIDE_BOSS, AC19_MINION_ATTACK, AC19_MINION_HEALTH)
	var before: int = log.events.size()

	# Act
	var first: Dictionary = _attack(engine, hero, minion)
	var again: Dictionary = _attack(engine, hero, minion)

	# Assert: the minion strikes back; durability spent in the damage step
	assert_bool(first.accepted).is_true()
	assert_int(int(_record(engine, minion).damage_taken)).is_equal(AC19_WEAPON_ATTACK)
	assert_int(int(_record(engine, hero).damage_taken)).is_equal(AC19_MINION_ATTACK)
	assert_int(int(weapon.durability)).is_equal(AC19_WEAPON_DURABILITY - 1)
	EventLogAssertions.assert_consecutive(_since(log, before), [&"damage_dealt", &"damage_dealt", &"weapon_durability_changed"])
	assert_str(str(again.rejection.code)).is_equal("CANNOT_ATTACK")
	# DD-X15: the hero, not the weapon, is the swing's damage source; the
	# strike back's source is the minion; the weapon is credited nothing
	var hits: Array[Dictionary] = _of(_since(log, before), &"damage_dealt")
	assert_int(int(hits[0].payload.source)).is_equal(hero)
	assert_int(int(hits[1].payload.source)).is_equal(minion)
	assert_bool(engine.state().players[SIDE_PLAYER].stats.damage_dealt_by_card.has(str(weapon.def_id))).is_false()


func test_a_hero_swing_with_a_poisonous_lifesteal_weapon_is_sourced_by_the_hero_and_keeps_the_keywords() -> void:
	# Arrange — DD-X15 (code review MR-013 S3): the hero is the source for
	# triggers, source-filtered hooks and stats; F2 still reads the weapon's
	# Poisonous and Lifesteal on that swing. A player `modify_damage` hook
	# (no ops) records the fold's ctx.
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var edge: HookInstaller = MatchFactory.make_hook_installer("t_edge", SIDE_PLAYER, [&"modify_damage"])
	var engine: RulesEngine = MatchFactory.make_started_engine(null, log, {"player": {"hook_installers": [edge]}}, {}, resolver, _db())
	assert_bool(engine.submit(engine.legal_commands()[0]).accepted).is_true()
	var weapon: Dictionary = MatchFactory.make_weapon(MatchFactory.alloc_entity_id(engine.state()), 1, AC19_WEAPON_DURABILITY, "neutral_test_fang", [MatchRecords.KEYWORD_POISONOUS, MatchRecords.KEYWORD_LIFESTEAL])
	engine.state().players[SIDE_PLAYER].weapon = weapon
	var hero: int = _hero_id(engine, SIDE_PLAYER)
	_record(engine, hero).damage_taken = AC19_MINION_HEALTH
	var minion: int = _minion(engine, SIDE_BOSS, AC19_MINION_ATTACK, SAFE_HEALTH)
	var before: int = log.events.size()
	var calls_before: int = resolver.resolve_calls.size()
	var folds_before: int = resolver.hook_calls.size()

	# Act
	assert_bool(_attack(engine, hero, minion).accepted).is_true()

	# Assert — the swing's source is the hero everywhere it is read
	var hits: Array[Dictionary] = _of(_since(log, before), &"damage_dealt")
	assert_int(int(hits[0].payload.source)).is_equal(hero)
	var fold_sources: Array = []
	for call: Dictionary in resolver.hook_calls.slice(folds_before):
		if call.kind == "fold" and call.point == "modify_damage":
			fold_sources.append(call.ctx.source)
	assert_array(fold_sources).contains([hero])
	assert_bool(fold_sources.has(int(weapon.entity_id))).is_false()
	var on_damage_sources: Array = []
	for call: Dictionary in resolver.resolve_calls.slice(calls_before):
		if call.point == &"on_damage" and not call.ctx.get(RulesEngine.CTX_QUEUED, false):
			on_damage_sources.append(call.ctx.source)
	assert_array(on_damage_sources).contains([hero])
	assert_bool(on_damage_sources.has(int(weapon.entity_id))).is_false()
	# … and the weapon's keywords still count: Poisonous kills the minion,
	# Lifesteal heals the hero by 1 (the minion's strike back takes 1 again)
	assert_bool(_record(engine, minion).is_empty()).is_true()
	assert_int(int(_record(engine, hero).damage_taken)).is_equal(AC19_MINION_HEALTH)
	assert_int(_of(_since(log, before), &"healed").size()).is_equal(1)


func test_a_heroes_weapon_keywords_count_only_for_its_swing() -> void:
	# Arrange — a Lifesteal weapon held, then damage the hero deals some other
	# way (a hero-power-style hit, source the hero): no Lifesteal
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log, TestEffectResolver.new())
	var weapon: Dictionary = MatchFactory.make_weapon(MatchFactory.alloc_entity_id(engine.state()), 1, AC19_WEAPON_DURABILITY, "neutral_test_fang", [MatchRecords.KEYWORD_LIFESTEAL])
	engine.state().players[SIDE_PLAYER].weapon = weapon
	var hero: int = _hero_id(engine, SIDE_PLAYER)
	_record(engine, hero).damage_taken = AC19_MINION_HEALTH
	var minion: int = _minion(engine, SIDE_BOSS, 0, SAFE_HEALTH)

	# Act
	engine.run_action(func() -> void: engine.apply_damage(minion, 1, hero))

	# Assert
	assert_int(int(_record(engine, hero).damage_taken)).is_equal(AC19_MINION_HEALTH)
	EventLogAssertions.assert_not_contains_type(log, &"healed")


func test_a_hero_weapon_attack_on_the_next_turn_kills_and_breaks_in_one_death_check() -> void:
	# Arrange: the AC-19 first swing, then the boss passes
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log, TestEffectResolver.new())
	@warning_ignore("return_value_discarded")
	_equip(engine, SIDE_PLAYER, AC19_WEAPON_ATTACK, AC19_WEAPON_DURABILITY)
	var hero: int = _hero_id(engine, SIDE_PLAYER)
	var minion: int = _minion(engine, SIDE_BOSS, AC19_MINION_ATTACK, AC19_MINION_HEALTH)
	assert_bool(_attack(engine, hero, minion).accepted).is_true()
	assert_bool(engine.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()
	assert_bool(engine.submit(MatchRecords.end_turn(SIDE_BOSS)).accepted).is_true()
	var before: int = log.events.size()

	# Act
	var second: Dictionary = _attack(engine, hero, minion)

	# Assert: the minion dies and the weapon breaks in the same death check,
	# right after that attack's two hits and its durability change
	assert_bool(second.accepted).is_true()
	assert_bool(_record(engine, minion).is_empty()).is_true()
	assert_object(engine.state().players[SIDE_PLAYER].weapon).is_null()
	assert_int(int(_record(engine, hero).damage_taken)).is_equal(2 * AC19_MINION_ATTACK)
	EventLogAssertions.assert_consecutive(_since(log, before), [&"damage_dealt", &"damage_dealt", &"weapon_durability_changed", &"minion_died", &"weapon_destroyed"])


# --- AC-21: on_attack changes the board ----------------------------------------

func test_an_on_attack_trigger_that_destroys_the_defender_cancels_the_attack() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _engine(log, resolver)
	var attacker: int = _minion(engine, SIDE_PLAYER, ATK, SAFE_HEALTH)
	var defender: int = _minion(engine, SIDE_BOSS, ATK, SAFE_HEALTH)
	resolver.add_on_attack_destroy(attacker, defender)
	var before: int = log.events.size()

	# Act
	var result: Dictionary = _attack(engine, attacker, defender)

	# Assert: cancelled, no damage, the swing still counted, resolved closes it
	var events: Array = _since(log, before)
	assert_bool(result.accepted).is_true()
	EventLogAssertions.assert_order(events, [&"attack_declared", &"trigger_resolved", &"minion_died", &"attack_cancelled", &"attack_resolved"])
	assert_int(_of(events, &"damage_dealt").size()).is_equal(0)
	assert_int(int(_record(engine, attacker).attacks_used)).is_equal(1)
	assert_int(int(_record(engine, attacker).damage_taken)).is_equal(0)
	assert_str(String(log.last().type)).is_equal("attack_resolved")


func test_an_on_attack_trigger_that_removes_the_attacker_cancels_the_attack() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _engine(log, resolver)
	var attacker: int = _minion(engine, SIDE_PLAYER, ATK, SAFE_HEALTH)
	var defender: int = _minion(engine, SIDE_BOSS, ATK, SAFE_HEALTH)
	resolver.add_on_attack_destroy(attacker, attacker)
	var before: int = log.events.size()

	# Act
	assert_bool(_attack(engine, attacker, defender).accepted).is_true()

	# Assert
	var events: Array = _since(log, before)
	EventLogAssertions.assert_order(events, [&"minion_died", &"attack_cancelled", &"attack_resolved"])
	assert_int(_of(events, &"damage_dealt").size()).is_equal(0)
	assert_int(int(_record(engine, defender).damage_taken)).is_equal(0)


func test_a_taunt_summoned_during_on_attack_does_not_redirect_the_declared_attack() -> void:
	# Arrange: no enemy Taunt at declaration; the trigger summons one
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _engine(log, resolver)
	var attacker: int = _minion(engine, SIDE_PLAYER, ATK, SAFE_HEALTH)
	var next_attacker: int = _minion(engine, SIDE_PLAYER, ATK, SAFE_HEALTH)
	resolver.add_on_attack_summon(attacker, SIDE_BOSS, DEF_TAUNT)
	var boss_hero: int = _hero_id(engine, SIDE_BOSS)

	# Act
	var result: Dictionary = _attack(engine, attacker, boss_hero)

	# Assert: the original target took the hit; the Taunt binds the next attack
	assert_bool(result.accepted).is_true()
	assert_int(int(_record(engine, boss_hero).damage_taken)).is_equal(ATK)
	var board: Array = engine.state().players[SIDE_BOSS].board
	assert_int(board.size()).is_equal(1)
	assert_int(int(board[0].damage_taken)).is_equal(0)
	assert_str(str(_attack(engine, next_attacker, boss_hero).rejection.code)).is_equal("MUST_ATTACK_TAUNT")


func test_a_discover_raised_by_an_on_attack_trigger_pauses_the_rest_of_the_attack_until_choose() -> void:
	# Arrange: the attacker's on_attack trigger raises a Discover
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _engine(log, resolver)
	var attacker: int = _minion(engine, SIDE_PLAYER, AC16_ATTACK, AC16_HEALTH)
	var defender: int = _minion(engine, SIDE_BOSS, AC16_DEFENDER_ATTACK, AC16_DEFENDER_HEALTH)
	resolver.add_trigger(&"on_attack", attacker, "oa.discover", _discover_for_player, resolver.attacker_is.bind(attacker))
	var before: int = log.events.size()

	# Act 1: the attack pauses in Choice
	var paused: Dictionary = _attack(engine, attacker, defender)

	# Assert: accepted, nothing after the trigger has run
	assert_bool(paused.accepted).is_true()
	assert_str(engine.phase()).is_equal(MatchState.PHASE_CHOICE)
	assert_int(_of(_since(log, before), &"damage_dealt").size()).is_equal(0)
	assert_int(_of(_since(log, before), &"attack_resolved").size()).is_equal(0)
	assert_int(int(_record(engine, attacker).attacks_used)).is_equal(0)

	# Act 2: the player picks; the parked attack steps run once
	var chosen: Dictionary = engine.submit(MatchRecords.choose(SIDE_PLAYER, 0))

	# Assert
	assert_bool(chosen.accepted).is_true()
	assert_str(engine.phase()).is_equal(MatchState.PHASE_MAIN)
	assert_int(resolver.resume_calls.size()).is_equal(1)
	assert_int(int(_record(engine, defender).damage_taken)).is_equal(AC16_ATTACK)
	assert_int(int(_record(engine, attacker).damage_taken)).is_equal(AC16_DEFENDER_ATTACK)
	assert_int(int(_record(engine, attacker).attacks_used)).is_equal(1)
	var events: Array = _since(log, before)
	assert_int(_of(events, &"damage_dealt").size()).is_equal(2)
	assert_int(_of(events, &"attack_resolved").size()).is_equal(1)
	EventLogAssertions.assert_order(events, [&"attack_declared", &"choice_requested", &"choice_made", &"damage_dealt", &"damage_dealt", &"attack_resolved"])
	assert_str(String(log.last().type)).is_equal("attack_resolved")


# --- C8 step 4 / DD-X11: the defending hero; the snapshot ------------------------

func test_a_defending_hero_never_deals_damage_back_even_with_a_weapon() -> void:
	# Arrange: the boss hero holds a 3/2 weapon and has attack 3
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log, TestEffectResolver.new())
	var boss_weapon: Dictionary = _equip(engine, SIDE_BOSS, DEFENDER_WEAPON_ATTACK, DEFENDER_WEAPON_DURABILITY)
	var boss_hero: int = _hero_id(engine, SIDE_BOSS)
	assert_int(engine.attack(_record(engine, boss_hero))).is_equal(DEFENDER_WEAPON_ATTACK)
	var attacker: int = _minion(engine, SIDE_PLAYER, ATK, SAFE_HEALTH)
	var before: int = log.events.size()

	# Act
	assert_bool(_attack(engine, attacker, boss_hero).accepted).is_true()

	# Assert: one hit, minion → hero; nothing back; the boss weapon untouched
	var events: Array = _since(log, before)
	var hits: Array[Dictionary] = _of(events, &"damage_dealt")
	assert_int(hits.size()).is_equal(1)
	assert_int(int(hits[0].payload.source)).is_equal(attacker)
	assert_int(int(hits[0].payload.target)).is_equal(boss_hero)
	assert_int(int(_record(engine, attacker).damage_taken)).is_equal(0)
	assert_int(int(boss_weapon.durability)).is_equal(DEFENDER_WEAPON_DURABILITY)
	assert_int(_of(events, &"weapon_durability_changed").size()).is_equal(0)


func test_the_defender_strikes_back_with_its_attack_snapshotted_at_the_damage_step() -> void:
	# Arrange: the first hit drops the defender's attack to 0 inside the step
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _engine(log, resolver)
	var attacker: int = _minion(engine, SIDE_PLAYER, ATK, SAFE_HEALTH)
	var defender: int = _minion(engine, SIDE_BOSS, AC16_DEFENDER_ATTACK, SAFE_HEALTH)
	resolver.scripts[&"on_damage"] = [_debuff_when_hit.bind(defender, AC16_DEFENDER_ATTACK)]

	# Act
	assert_bool(_attack(engine, attacker, defender).accepted).is_true()

	# Assert: attack 0 now, yet it dealt the value read at step 4
	assert_int(engine.attack(_record(engine, defender))).is_equal(0)
	assert_int(int(_record(engine, attacker).damage_taken)).is_equal(AC16_DEFENDER_ATTACK)
