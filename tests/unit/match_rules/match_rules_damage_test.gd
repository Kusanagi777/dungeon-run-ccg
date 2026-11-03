## Unit tests for the F2 damage pipeline, healing and armour (story
## match-rules/story-007; design/gdd/match-rules.md C9, F2, C12 Divine Shield /
## Poisonous / Lifesteal rows, Interactions `modify_damage`, `modify_heal`,
## `on_hero_damaged`; ADR-0005 Decision 4 — fold, then one clamp).
##
## Matches start through `MatchFactory.make_started_engine` and a "keep all"
## mulligan (turn 1, player Main). Characters are placed with
## `MatchFactory.summon`; value hooks are card-effects C5 `modify_value` ops
## the `TestEffectResolver` applies and records per entry (`fold_inputs`).
extends GdUnitTestSuite

const SIDE_PLAYER: String = MatchFactory.SIDE_PLAYER
const SIDE_BOSS: String = MatchFactory.SIDE_BOSS
const HOOK_MARKER: StringName = &"test_hook_marker"
## AC-23: boss armour, the Lifesteal hit, and the player hero's prior damage.
const BOSS_ARMOR: int = 2
const LIFESTEAL_HIT: int = 5
const PLAYER_PRIOR_DAMAGE: int = 6
## Fixture definition ids (CR-2-valid) for stats attribution.
const DEF_LEECH: String = "neutral_test_leech"
const DEF_ADDER: String = "neutral_test_adder"
const DEF_FANG: String = "war_test_fang"
## C9 Divine Shield: the incoming hit.
const SHIELD_HIT: int = 4
## AC-44: the heal, its hook, the damage chain.
const SMALL_HEAL: int = 2
const HEAL_HOOK_DELTA: int = -3
const CHAIN_DELTA: int = -1
const CHAIN_LENGTH: int = 3
const RAISE_DELTA: int = 2
## C9 healing: an over-heal on a hero at damage_taken 3.
const OVERHEAL: int = 10
const PRIOR_DAMAGE: int = 3
## Armour has no cap.
const BIG_ARMOR: int = 100


# --- helpers -----------------------------------------------------------------

func _engine(log: TestEventLog, overrides: Dictionary = {}, resolver: TestEffectResolver = null) -> RulesEngine:
	var engine: RulesEngine = MatchFactory.make_started_engine(null, log, overrides, {}, resolver)
	assert_bool(engine.submit(engine.legal_commands()[0]).accepted).is_true()
	return engine


func _hero(engine: RulesEngine, side: String) -> Dictionary:
	return engine.state().players[side].hero


func _since(log: TestEventLog, before: int) -> Array[Dictionary]:
	return log.events.slice(before)


func _types(events: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for event: Dictionary in events:
		out.append(String(event.type))
	return out


## An installer on [param side] with one value-hook effect per op in
## [param ops], each on [param point] (card-effects C1 shape).
func _value_installer(host_id: String, side: String, point: StringName, ops: Array[Dictionary]) -> HookInstaller:
	var effects: Array[Dictionary] = []
	for i: int in ops.size():
		effects.append({
			"id": "%s.%d" % [host_id, i], "trigger": str(point), "scope": {}, "condition": {},
			"ops": [ops[i]], "once_per_turn": false,
		})
	var kind: StringName = HookInstaller.HOST_KIND_TREASURE if side == SIDE_PLAYER else HookInstaller.HOST_KIND_PASSIVE
	return HookInstaller.new(kind, host_id, StringName(side), effects)


func _delta(n: int) -> Dictionary:
	return {"op": TestEffectResolver.OP_MODIFY_VALUE, "delta": n}


## Hook script: emits [constant HOOK_MARKER] with the hook context's numbers.
func _hook_marker(engine: RulesEngine, _entry: Dictionary, side: StringName, ctx: Dictionary) -> void:
	@warning_ignore("return_value_discarded")
	engine.emit(HOOK_MARKER, {"side": String(side), "amount_dealt": ctx.get("amount_dealt"), "source": ctx.get("source")})


func _resolves(resolver: TestEffectResolver, point: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for call: Dictionary in resolver.resolve_calls:
		if call.point == point:
			out.append(call.ctx)
	return out


# --- AC-23: armour, Lifesteal, on_hero_damaged, stats ------------------------

func test_lifesteal_hit_on_an_armoured_hero_absorbs_heals_dealt_and_fires_on_hero_damaged() -> void:
	# Arrange: boss hero with 2 armour and an on_hero_damaged passive hook; a
	# player Lifesteal minion; the player's hero already down 6
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	resolver.hook_scripts["p_spite.0"] = _hook_marker
	var spite: HookInstaller = MatchFactory.make_hook_installer("p_spite", SIDE_BOSS, [&"on_hero_damaged"])
	var engine: RulesEngine = _engine(log, {"boss": {"hook_installers": [spite]}}, resolver)
	var state: MatchState = engine.state()
	var boss_hero: Dictionary = _hero(engine, SIDE_BOSS)
	var player_hero: Dictionary = _hero(engine, SIDE_PLAYER)
	engine.apply_armor(SIDE_BOSS, BOSS_ARMOR)
	player_hero.damage_taken = PLAYER_PRIOR_DAMAGE
	var leech: Dictionary = MatchFactory.summon(state, SIDE_PLAYER, LIFESTEAL_HIT, 1, -1, [MatchRecords.KEYWORD_LIFESTEAL], DEF_LEECH)
	var boss_health: int = engine.health(boss_hero)
	var before: int = log.events.size()

	# Act
	var dealt: int = engine.apply_damage(int(boss_hero.entity_id), LIFESTEAL_HIT, int(leech.entity_id))

	# Assert: F2 — armor_absorbed 2, to_health 3, dealt 5; heal 5
	assert_int(dealt).is_equal(LIFESTEAL_HIT)
	assert_int(int(boss_hero.armor)).is_equal(0)
	assert_int(engine.health(boss_hero)).is_equal(boss_health - (LIFESTEAL_HIT - BOSS_ARMOR))
	assert_int(int(player_hero.damage_taken)).is_equal(PLAYER_PRIOR_DAMAGE - LIFESTEAL_HIT)
	var events: Array[Dictionary] = _since(log, before)
	assert_array(_types(events)).is_equal(["armor_lost", "damage_dealt", "healed", String(HOOK_MARKER)])
	assert_dict(events[0].payload).is_equal({"side": SIDE_BOSS, "entity_id": int(boss_hero.entity_id), "amount": BOSS_ARMOR, "armor": 0})
	assert_dict(events[1].payload).is_equal({
		"source": int(leech.entity_id), "target": int(boss_hero.entity_id), "requested": LIFESTEAL_HIT,
		"prevented": 0, "armor_absorbed": BOSS_ARMOR, "dealt": LIFESTEAL_HIT,
		"health_after": boss_health - (LIFESTEAL_HIT - BOSS_ARMOR),
	})
	assert_dict(events[2].payload).is_equal({
		"source": int(leech.entity_id), "target": int(player_hero.entity_id),
		"requested": LIFESTEAL_HIT, "amount": LIFESTEAL_HIT,
	})
	assert_dict(events[3].payload).is_equal({"side": SIDE_BOSS, "amount_dealt": LIFESTEAL_HIT, "source": int(leech.entity_id)})
	assert_int(int(state.players[SIDE_PLAYER].stats.damage_dealt_by_card[DEF_LEECH])).is_equal(LIFESTEAL_HIT)
	assert_int(int(state.players[SIDE_BOSS].stats.damage_taken)).is_equal(LIFESTEAL_HIT)


func test_lifesteal_on_a_weapon_heals_the_hero_holding_it() -> void:
	# Arrange: the player holds a Lifesteal weapon (the source of a hero attack)
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log)
	var state: MatchState = engine.state()
	var fang: Dictionary = MatchFactory.make_weapon(MatchFactory.alloc_entity_id(state), 2, 2, DEF_FANG, [MatchRecords.KEYWORD_LIFESTEAL])
	state.players[SIDE_PLAYER].weapon = fang
	var player_hero: Dictionary = _hero(engine, SIDE_PLAYER)
	player_hero.damage_taken = PRIOR_DAMAGE
	var target: Dictionary = MatchFactory.summon(state, SIDE_BOSS, 1, 5)

	# Act
	engine.apply_damage(int(target.entity_id), 2, int(fang.entity_id))

	# Assert
	assert_int(int(player_hero.damage_taken)).is_equal(PRIOR_DAMAGE - 2)
	assert_int(int(state.players[SIDE_PLAYER].stats.damage_dealt_by_card[DEF_FANG])).is_equal(2)


# --- AC-44: fold, then one clamp ----------------------------------------------

func test_modify_heal_below_zero_heals_zero_and_never_damages() -> void:
	# Arrange: a player modify_heal hook returning value − 3
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var balm: HookInstaller = _value_installer("t_balm", SIDE_PLAYER, &"modify_heal", [_delta(HEAL_HOOK_DELTA)])
	var engine: RulesEngine = _engine(log, {"player": {"hook_installers": [balm]}}, resolver)
	var hero: Dictionary = _hero(engine, SIDE_PLAYER)
	hero.damage_taken = PRIOR_DAMAGE
	var before: int = log.events.size()

	# Act
	var restored: int = engine.apply_heal(int(hero.entity_id), SMALL_HEAL, int(hero.entity_id))

	# Assert
	var events: Array[Dictionary] = _since(log, before)
	assert_array(_types(events)).is_equal(["healed"])
	assert_dict(events[0].payload).is_equal({"source": int(hero.entity_id), "target": int(hero.entity_id), "requested": SMALL_HEAL, "amount": 0})
	assert_int(restored).is_equal(0)
	assert_int(int(hero.damage_taken)).is_equal(PRIOR_DAMAGE)
	assert_array(resolver.fold_inputs(&"modify_heal")).is_equal([SMALL_HEAL])


func test_modify_damage_chain_is_folded_unclamped_then_clamped_once() -> void:
	# Arrange: delta −1, −1, −1 on the player's side; a requested 1 from a player minion
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var chain: Array[Dictionary] = []
	for _i: int in CHAIN_LENGTH:
		chain.append(_delta(CHAIN_DELTA))
	var dampers: HookInstaller = _value_installer("t_damper", SIDE_PLAYER, &"modify_damage", chain)
	var engine: RulesEngine = _engine(log, {"player": {"hook_installers": [dampers]}}, resolver)
	var state: MatchState = engine.state()
	var source: Dictionary = MatchFactory.summon(state, SIDE_PLAYER, 1, 1)
	var target: Dictionary = MatchFactory.summon(state, SIDE_BOSS, 1, 3)
	var before: int = log.events.size()

	# Act
	var dealt: int = engine.apply_damage(int(target.entity_id), 1, int(source.entity_id))

	# Assert: inputs 1, 0, −1 (never clamped between entries); the result −2 → 0
	assert_array(resolver.fold_inputs(&"modify_damage")).is_equal([1, 0, -1])
	assert_int(dealt).is_equal(0)
	assert_int(int(target.damage_taken)).is_equal(0)
	var events: Array[Dictionary] = _since(log, before)
	assert_array(_types(events)).is_equal(["damage_dealt"])
	assert_int(int(events[0].payload.requested)).is_equal(1)
	assert_int(int(events[0].payload.dealt)).is_equal(0)
	# the fold received the source's side and the {source, target} context
	var fold_call: Dictionary = resolver.hook_calls[resolver.hook_calls.size() - 1]
	assert_str(String(fold_call.side)).is_equal(SIDE_PLAYER)
	assert_dict(fold_call.ctx).is_equal({"source": int(source.entity_id), "target": int(target.entity_id)})


func test_modify_damage_may_raise_the_amount_above_the_request() -> void:
	# Arrange: +2 on the player's side
	var log: TestEventLog = TestEventLog.new()
	var boost: HookInstaller = _value_installer("t_whet", SIDE_PLAYER, &"modify_damage", [_delta(RAISE_DELTA)])
	var engine: RulesEngine = _engine(log, {"player": {"hook_installers": [boost]}})
	var state: MatchState = engine.state()
	var source: Dictionary = MatchFactory.summon(state, SIDE_PLAYER, 1, 1)
	var target: Dictionary = MatchFactory.summon(state, SIDE_BOSS, 1, 9)

	# Act
	var dealt: int = engine.apply_damage(int(target.entity_id), 1, int(source.entity_id))

	# Assert (F2 Output Range: dealt ∈ [0, amount], amount may exceed requested)
	assert_int(dealt).is_equal(1 + RAISE_DELTA)
	assert_int(int(log.last().payload.requested)).is_equal(1)


func test_boss_modify_damage_hook_does_not_fold_player_sourced_damage() -> void:
	# Arrange: a friendly-scoped boss hook; the damage comes from the player's side
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var boss_boost: HookInstaller = _value_installer("p_rage", SIDE_BOSS, &"modify_damage", [_delta(RAISE_DELTA)])
	var engine: RulesEngine = _engine(log, {"boss": {"hook_installers": [boss_boost]}}, resolver)
	var state: MatchState = engine.state()
	var source: Dictionary = MatchFactory.summon(state, SIDE_PLAYER, 1, 1)
	var target: Dictionary = MatchFactory.summon(state, SIDE_BOSS, 1, 9)

	# Act
	var dealt: int = engine.apply_damage(int(target.entity_id), 1, int(source.entity_id))

	# Assert: the fold side is the source's (ADR-0005 rule 3), so the entry is out of scope
	assert_int(dealt).is_equal(1)
	assert_str(String(resolver.hook_calls[resolver.hook_calls.size() - 1].side)).is_equal(SIDE_PLAYER)


# --- C9 Divine Shield ---------------------------------------------------------

func test_divine_shield_prevents_the_hit_and_blocks_poison_lifesteal_and_on_damage() -> void:
	# Arrange: a shielded boss minion; a Poisonous + Lifesteal player source
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _engine(log, {}, resolver)
	var state: MatchState = engine.state()
	var player_hero: Dictionary = _hero(engine, SIDE_PLAYER)
	player_hero.damage_taken = PRIOR_DAMAGE
	var shielded: Dictionary = MatchFactory.summon(state, SIDE_BOSS, 3, 5, -1, [MatchRecords.KEYWORD_DIVINE_SHIELD])
	var source: Dictionary = MatchFactory.summon(state, SIDE_PLAYER, 4, 4, -1, [MatchRecords.KEYWORD_POISONOUS, MatchRecords.KEYWORD_LIFESTEAL], DEF_ADDER)
	var on_damage_before: int = _resolves(resolver, &"on_damage").size()
	var before: int = log.events.size()

	# Act
	var dealt: int = engine.apply_damage(int(shielded.entity_id), SHIELD_HIT, int(source.entity_id))

	# Assert
	var events: Array[Dictionary] = _since(log, before)
	assert_array(_types(events)).is_equal(["divine_shield_popped", "damage_dealt"])
	assert_dict(events[0].payload).is_equal({"entity_id": int(shielded.entity_id), "prevented": SHIELD_HIT})
	assert_int(int(events[1].payload.prevented)).is_equal(SHIELD_HIT)
	assert_int(int(events[1].payload.dealt)).is_equal(0)
	assert_int(dealt).is_equal(0)
	assert_int(int(shielded.damage_taken)).is_equal(0)
	assert_bool(MatchFactory.has_keyword(shielded, MatchRecords.KEYWORD_DIVINE_SHIELD)).is_false()
	assert_bool(bool(shielded.get("pending_destroy", false))).is_false()
	assert_int(int(player_hero.damage_taken)).is_equal(PRIOR_DAMAGE)
	assert_int(_resolves(resolver, &"on_damage").size()).is_equal(on_damage_before)
	assert_bool(state.players[SIDE_PLAYER].stats.damage_dealt_by_card.has(DEF_ADDER)).is_false()


func test_zero_damage_does_not_pop_divine_shield() -> void:
	# Arrange: a shield granted by an enchantment
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log)
	var state: MatchState = engine.state()
	var shielded: Dictionary = MatchFactory.summon(state, SIDE_BOSS, 1, 1)
	shielded.enchantments.append(MatchFactory.make_enchantment(0, 0, [MatchRecords.KEYWORD_DIVINE_SHIELD]))
	var before: int = log.events.size()

	# Act
	engine.apply_damage(int(shielded.entity_id), 0, null)

	# Assert
	var events: Array[Dictionary] = _since(log, before)
	assert_array(_types(events)).is_equal(["damage_dealt"])
	assert_int(int(events[0].payload.dealt)).is_equal(0)
	assert_int(int(events[0].payload.prevented)).is_equal(0)
	assert_bool(MatchFactory.has_keyword(shielded, MatchRecords.KEYWORD_DIVINE_SHIELD)).is_true()


# --- C9 Poisonous, on_damage ----------------------------------------------------

func test_poisonous_marks_a_damaged_minion_but_not_a_hero() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log)
	var state: MatchState = engine.state()
	var adder: Dictionary = MatchFactory.summon(state, SIDE_PLAYER, 1, 1, -1, [MatchRecords.KEYWORD_POISONOUS], DEF_ADDER)
	var victim: Dictionary = MatchFactory.summon(state, SIDE_BOSS, 1, 5)
	var boss_hero: Dictionary = _hero(engine, SIDE_BOSS)

	# Act
	engine.apply_damage(int(victim.entity_id), 1, int(adder.entity_id))
	engine.apply_damage(int(boss_hero.entity_id), 1, int(adder.entity_id))

	# Assert: dies in the next death check regardless of health (story 009)
	assert_bool(bool(victim.get("pending_destroy", false))).is_true()
	assert_int(engine.health(victim)).is_equal(4)
	assert_bool(bool(boss_hero.get("pending_destroy", false))).is_false()


func test_damage_dealt_raises_on_damage_and_a_zero_hit_does_not() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _engine(log, {}, resolver)
	var state: MatchState = engine.state()
	var source: Dictionary = MatchFactory.summon(state, SIDE_PLAYER, 2, 2)
	var target: Dictionary = MatchFactory.summon(state, SIDE_BOSS, 1, 5)
	var before: int = _resolves(resolver, &"on_damage").size()

	# Act
	engine.apply_damage(int(target.entity_id), 2, int(source.entity_id))
	engine.apply_damage(int(target.entity_id), 0, int(source.entity_id))

	# Assert: one raise, with the target, the amount dealt and the source
	var raised: Array[Dictionary] = _resolves(resolver, &"on_damage")
	assert_int(raised.size()).is_equal(before + 1)
	var ctx: Dictionary = raised[raised.size() - 1]
	assert_int(int(ctx.subject)).is_equal(int(target.entity_id))
	assert_int(int(ctx.amount)).is_equal(2)
	assert_int(int(ctx.source)).is_equal(int(source.entity_id))
	assert_str(str(ctx.side)).is_equal(SIDE_BOSS)


func test_on_hero_damaged_does_not_run_for_a_minion_or_a_zero_hit() -> void:
	# Arrange: a boss on_hero_damaged hook
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	resolver.hook_scripts["p_spite.0"] = _hook_marker
	var spite: HookInstaller = MatchFactory.make_hook_installer("p_spite", SIDE_BOSS, [&"on_hero_damaged"])
	var engine: RulesEngine = _engine(log, {"boss": {"hook_installers": [spite]}}, resolver)
	var minion: Dictionary = MatchFactory.summon(engine.state(), SIDE_BOSS, 1, 5)

	# Act
	engine.apply_damage(int(minion.entity_id), 1, null)
	engine.apply_damage(int(_hero(engine, SIDE_BOSS).entity_id), 0, null)

	# Assert
	assert_array(resolver.run_contexts(&"on_hero_damaged")).is_empty()


# --- C9 healing and armour ------------------------------------------------------

func test_heal_restores_at_most_damage_taken_and_a_full_target_still_emits() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _engine(log, {}, resolver)
	var hero: Dictionary = _hero(engine, SIDE_PLAYER)
	hero.damage_taken = PRIOR_DAMAGE
	var heals_before: int = _resolves(resolver, &"on_heal").size()

	# Act
	var restored: int = engine.apply_heal(int(hero.entity_id), OVERHEAL, null)
	var before: int = log.events.size()
	var again: int = engine.apply_heal(int(hero.entity_id), OVERHEAL, null)

	# Assert
	assert_int(restored).is_equal(PRIOR_DAMAGE)
	assert_int(int(hero.damage_taken)).is_equal(0)
	assert_int(engine.health(hero)).is_equal(engine.max_health(hero))
	assert_int(again).is_equal(0)
	var events: Array[Dictionary] = _since(log, before)
	assert_array(_types(events)).is_equal(["healed"])
	assert_int(int(events[0].payload.amount)).is_equal(0)
	# on_heal observers see both heals, the 0 one included
	assert_int(_resolves(resolver, &"on_heal").size()).is_equal(heals_before + 2)


func test_apply_armor_is_uncapped() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log)

	# Act
	engine.apply_armor(SIDE_PLAYER, BIG_ARMOR)
	engine.apply_armor(SIDE_PLAYER, 4)

	# Assert
	assert_int(int(_hero(engine, SIDE_PLAYER).armor)).is_equal(BIG_ARMOR + 4)
	assert_dict(log.last().payload).is_equal({"side": SIDE_PLAYER, "entity_id": int(_hero(engine, SIDE_PLAYER).entity_id), "amount": 4, "armor": BIG_ARMOR + 4})
