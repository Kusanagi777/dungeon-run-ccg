## Unit tests for playing minions, spells, weapons and the hero power (story
## match-rules/story-010; design/gdd/match-rules.md C6 Playing cards, C7 Hero
## power, C2 `play_card` / `use_hero_power` rows and `legal_commands()`, F1
## base, F7, Edge Cases "Targeting and playing"; card-effects C6.3 play order;
## ADR-0007 Decision 1 — `targeting_spec` / `legal_targets` are the
## resolver's, called by the engine during validation).
##
## Matches start through `MatchFactory.make_started_engine` and a "keep all"
## mulligan (turn 1, player Main). Each test replaces the player's hand with
## fixture cards and sets `mana_current` (fixture moves); targeting and the
## responders are scripted on the `TestEffectResolver` (`specs_by_def`,
## `targets_by_def`, `add_trigger`). Definitions come from a test-local
## [FixtureDb] built with `CardFactory` records.
extends GdUnitTestSuite

const SIDE_PLAYER: String = MatchFactory.SIDE_PLAYER
const SIDE_BOSS: String = MatchFactory.SIDE_BOSS
const HOOK_MARKER: StringName = &"test_hook_marker"
const MARKER: StringName = &"test_pass_marker"
## Fixture definitions (CR-2-valid ids) and their printed numbers.
const DEF_VANILLA: String = "neutral_test_vanilla_2_2"
const VANILLA_COST: int = 2
const DEF_SEEKER: String = "neutral_test_seeker"
const DEF_BOLT: String = "neutral_test_bolt"
const DEF_LEECH_BOLT: String = "neutral_test_leech_bolt"
const DEF_FLARE: String = "neutral_test_flare"
const DEF_STUDY: String = "neutral_test_study"
const DEF_SAGE: String = "neutral_test_sage"
const SAGE_SPELL_DAMAGE: int = 1
const DEF_OLD_BLADE: String = "neutral_test_old_blade"
const DEF_TWIN_AXE: String = "neutral_test_twin_axe"
const DEF_POWER: String = "power_test"
const DEF_DEAR: String = "neutral_test_dear"
## Cheap enough for every test's mana pool; DEAR is never affordable.
const CHEAP: int = 1
const DEAR_COST: int = 9
const BOLT_DAMAGE: int = 2
## A plentiful pool for tests that play more than one card.
const MANA_POOL: int = 10
## A target id no record carries.
const NO_SUCH_ID: int = 9999


class FixtureDb extends RefCounted:
	var cards: Dictionary = {}

	func has(id: String) -> bool:
		return cards.has(id)

	func card(id: String) -> Variant:
		return cards.get(id)


# --- helpers -----------------------------------------------------------------

func _db() -> FixtureDb:
	var db: FixtureDb = FixtureDb.new()
	db.cards[DEF_VANILLA] = CardFactory.make_minion(DEF_VANILLA, VANILLA_COST, 2, 2)
	db.cards[DEF_SEEKER] = CardFactory.make_minion(DEF_SEEKER, CHEAP, 1, 1, ["battlecry"])
	db.cards[DEF_SAGE] = CardFactory.make_minion(DEF_SAGE, CHEAP, 1, 1, ["spell_damage"], {"spell_damage": SAGE_SPELL_DAMAGE})
	db.cards[DEF_DEAR] = CardFactory.make_minion(DEF_DEAR, DEAR_COST, 9, 9)
	db.cards[DEF_BOLT] = CardFactory.make_spell(DEF_BOLT, CHEAP)
	db.cards[DEF_LEECH_BOLT] = CardFactory.make_spell(DEF_LEECH_BOLT, CHEAP, [], {"keywords": ["lifesteal"]})
	db.cards[DEF_FLARE] = CardFactory.make_spell(DEF_FLARE, CHEAP)
	db.cards[DEF_STUDY] = CardFactory.make_spell(DEF_STUDY, CHEAP)
	db.cards[DEF_OLD_BLADE] = CardFactory.make_weapon(DEF_OLD_BLADE, CHEAP, 1, 1)
	db.cards[DEF_TWIN_AXE] = CardFactory.make_weapon(DEF_TWIN_AXE, CHEAP, 2, 2, {"keywords": ["windfury"]})
	return db


## A started engine past the mulligan, the player's hand replaced by
## [param hand] (def ids, left to right) and its mana set to [param mana].
func _engine(log: TestEventLog, resolver: TestEffectResolver, hand: Array, mana: int, overrides: Dictionary = {}) -> RulesEngine:
	var engine: RulesEngine = MatchFactory.make_started_engine(null, log, overrides, {}, resolver, _db())
	assert_bool(engine.submit(engine.legal_commands()[0]).accepted).is_true()
	var state: MatchState = engine.state()
	var cards: Array = state.players[SIDE_PLAYER].hand
	cards.clear()
	for def_id: Variant in hand:
		cards.append(MatchFactory.make_card_instance(MatchFactory.alloc_entity_id(state), str(def_id), "hand"))
	state.players[SIDE_PLAYER].mana_current = mana
	state.players[SIDE_PLAYER].hero_power.def_id = DEF_POWER
	return engine


func _player(engine: RulesEngine, side: String = SIDE_PLAYER) -> Dictionary:
	return engine.state().players[side]


func _hero_id(engine: RulesEngine, side: String) -> int:
	return int(_player(engine, side).hero.entity_id)


func _fill_board(engine: RulesEngine, side: String, count: int) -> void:
	for _i: int in count:
		MatchFactory.summon(engine.state(), side, 1, 1)


func _types(events: Array) -> Array[String]:
	var out: Array[String] = []
	for event: Dictionary in events:
		out.append(String(event.type))
	return out


func _of(log: TestEventLog, before: int, types: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for event: Dictionary in log.events.slice(before):
		if types.has(String(event.type)):
			out.append(event)
	return out


## The points of the resolver's trigger-point fires after [param from] calls.
func _fired(resolver: TestEffectResolver, from: int) -> Array[String]:
	var out: Array[String] = []
	for call: Dictionary in resolver.resolve_calls.slice(from):
		if not call.ctx.get(RulesEngine.CTX_QUEUED, false):
			out.append(String(call.point))
	return out


func _calls(resolver: TestEffectResolver, point: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for call: Dictionary in resolver.resolve_calls:
		if call.point == point:
			out.append(call.ctx)
	return out


func _assert_rejected(result: Dictionary, code: String) -> void:
	assert_bool(result.accepted).is_false()
	if not result.accepted:
		assert_str(str(result.rejection.code)).is_equal(code)


func _required(resolver: TestEffectResolver, def_id: String, targets: Array) -> void:
	resolver.specs_by_def[def_id] = {"mode": RulesEngine.TARGETING_REQUIRED, "filter": {}}
	resolver.targets_by_def[def_id] = targets


func _hook_marker(engine: RulesEngine, entry: Dictionary, side: StringName, _ctx: Dictionary) -> void:
	@warning_ignore("return_value_discarded")
	engine.emit(HOOK_MARKER, {"side": String(side), "effect_id": str(entry.effect_id)})


func _mark(engine: RulesEngine, ctx: Dictionary) -> void:
	@warning_ignore("return_value_discarded")
	engine.emit(MARKER, {"effect_id": str(ctx.get("effect_id", ""))})


# --- AC-11: playing a minion ----------------------------------------------------

func test_minion_on_a_full_board_is_board_full() -> void:
	# Arrange
	var engine: RulesEngine = _engine(TestEventLog.new(), TestEffectResolver.new(), [DEF_VANILLA], MANA_POOL)
	_fill_board(engine, SIDE_PLAYER, TestConstants.BOARD_SIZE)

	# Act / Assert
	_assert_rejected(engine.submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0)), "BOARD_FULL")
	assert_int(int(_player(engine).mana_current)).is_equal(MANA_POOL)


func test_minion_position_outside_zero_to_board_size_is_invalid_position() -> void:
	# Arrange: a 2-minion board
	var engine: RulesEngine = _engine(TestEventLog.new(), TestEffectResolver.new(), [DEF_VANILLA], MANA_POOL)
	_fill_board(engine, SIDE_PLAYER, 2)

	# Act / Assert: 8 and −1 are rejected; board.size (2) is the rightmost slot
	_assert_rejected(engine.submit(MatchRecords.play_card(SIDE_PLAYER, 0, 8)), "INVALID_POSITION")
	_assert_rejected(engine.submit(MatchRecords.play_card(SIDE_PLAYER, 0, -1)), "INVALID_POSITION")
	_assert_rejected(engine.submit(MatchRecords.play_card(SIDE_PLAYER, 0)), "INVALID_POSITION")
	assert_bool(engine.submit(MatchRecords.play_card(SIDE_PLAYER, 0, 2)).accepted).is_true()


func test_played_minion_enters_the_slot_sick_and_runs_the_play_steps_in_order() -> void:
	# Arrange: a 2-minion board, an on_card_played hook, an on_minion_summoned hook
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	resolver.hook_scripts["t_herald.0"] = _hook_marker
	resolver.hook_scripts["t_herald.1"] = _hook_marker
	var herald: HookInstaller = MatchFactory.make_hook_installer("t_herald", SIDE_PLAYER, [&"on_card_played", &"on_minion_summoned"])
	var engine: RulesEngine = _engine(log, resolver, [DEF_VANILLA], MANA_POOL, {"player": {"hook_installers": [herald]}})
	_fill_board(engine, SIDE_PLAYER, 2)
	var card: Dictionary = _player(engine).hand[0]
	var stats_before: Dictionary = (_player(engine).stats as Dictionary).duplicate(true)
	var before: int = log.events.size()
	var calls_before: int = resolver.resolve_calls.size()

	# Act
	var result: Dictionary = engine.submit(MatchRecords.play_card(SIDE_PLAYER, 0, 2))

	# Assert: board[2], sick, unused, stamped with the turn
	assert_bool(result.accepted).is_true()
	var minion: Dictionary = _player(engine).board[2]
	assert_str(str(minion.def_id)).is_equal(DEF_VANILLA)
	assert_bool(minion.summoning_sick).is_true()
	assert_int(int(minion.attacks_used)).is_equal(0)
	assert_int(int(minion.summoned_on_turn)).is_equal(engine.state().turn)
	assert_bool(_player(engine).hand.is_empty()).is_true()
	assert_int(int(_player(engine).mana_current)).is_equal(MANA_POOL - VANILLA_COST)
	assert_int(int(_player(engine).stats.cards_played)).is_equal(int(stats_before.cards_played) + 1)
	assert_int(int(_player(engine).stats.minions_summoned)).is_equal(int(stats_before.minions_summoned) + 1)
	# events: mana_spent, card_played, minion_summoned, then the play steps
	var events: Array[Dictionary] = _of(log, before, ["mana_spent", "card_played", "minion_summoned", String(HOOK_MARKER)])
	assert_array(_types(events)).is_equal(["mana_spent", "card_played", "minion_summoned", String(HOOK_MARKER), String(HOOK_MARKER)])
	assert_dict(events[0].payload).is_equal({"side": SIDE_PLAYER, "amount": VANILLA_COST, "mana_current": MANA_POOL - VANILLA_COST})
	assert_dict(events[1].payload).is_equal({
		"side": SIDE_PLAYER, "instance_id": int(card.instance_id), "card_id": DEF_VANILLA,
		"type": "minion", "hand_index": 0, "target_id": null,
	})
	assert_int(int(events[2].payload.entity_id)).is_equal(int(minion.entity_id))
	assert_int(int(events[2].payload.position)).is_equal(2)
	assert_array([events[3].payload.effect_id, events[4].payload.effect_id]).is_equal(["t_herald.0", "t_herald.1"])
	# card-effects C6.3: battlecry → on_card_played hooks → on_card_played → on_play
	# → on_minion_summoned hooks → on_summon (each its own step)
	assert_array(_fired(resolver, calls_before)).is_equal(["battlecry", "on_card_played", "on_play", "on_summon"])
	var battlecry_ctx: Dictionary = _calls(resolver, &"battlecry")[0]
	assert_int(int(battlecry_ctx.source)).is_equal(int(minion.entity_id))
	assert_array(battlecry_ctx.candidates).is_equal([int(minion.entity_id)])
	assert_int(int(_calls(resolver, &"on_summon")[0].subject)).is_equal(int(minion.entity_id))


func test_play_card_checks_run_in_the_c6_order() -> void:
	# Arrange: two failures at once per row; the first in C6 order wins
	var resolver: TestEffectResolver = TestEffectResolver.new()
	_required(resolver, DEF_SEEKER, [NO_SUCH_ID])
	var engine: RulesEngine = _engine(TestEventLog.new(), resolver, [DEF_DEAR, DEF_VANILLA, DEF_SEEKER], VANILLA_COST)
	var mana: int = int(_player(engine).mana_current)

	# Act / Assert
	# phase/turn before index
	_assert_rejected(engine.submit(MatchRecords.play_card(SIDE_BOSS, 99, 0)), "NOT_YOUR_TURN")
	# index before cost
	_assert_rejected(engine.submit(MatchRecords.play_card(SIDE_PLAYER, 99, 0)), "INVALID_INDEX")
	# cost before board space
	_fill_board(engine, SIDE_PLAYER, TestConstants.BOARD_SIZE)
	_assert_rejected(engine.submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0)), "NOT_ENOUGH_MANA")
	# board space before position
	_assert_rejected(engine.submit(MatchRecords.play_card(SIDE_PLAYER, 1, 99)), "BOARD_FULL")
	# position before targeting
	_player(engine).board.clear()
	_assert_rejected(engine.submit(MatchRecords.play_card(SIDE_PLAYER, 2, 99)), "INVALID_POSITION")
	# targeting last
	_assert_rejected(engine.submit(MatchRecords.play_card(SIDE_PLAYER, 2, 0)), "TARGET_REQUIRED")
	# nothing moved
	assert_int(int(_player(engine).mana_current)).is_equal(mana)
	assert_int(_player(engine).hand.size()).is_equal(3)


# --- AC-13: targeting -----------------------------------------------------------

func test_required_target_spell_with_no_legal_target_is_not_playable() -> void:
	# Arrange: the only enemy minion has Stealth, so the resolver's filter finds none
	var resolver: TestEffectResolver = TestEffectResolver.new()
	_required(resolver, DEF_BOLT, [])
	var engine: RulesEngine = _engine(TestEventLog.new(), resolver, [DEF_BOLT], MANA_POOL)
	MatchFactory.summon(engine.state(), SIDE_BOSS, 1, 1, -1, ["stealth"])

	# Act
	var legal: Array = engine.legal_commands()
	var result: Dictionary = engine.submit(MatchRecords.play_card(SIDE_PLAYER, 0, null, _hero_id(engine, SIDE_BOSS)))

	# Assert: the spell is absent (the hero power and end_turn remain)
	assert_array(legal).is_equal([MatchRecords.use_hero_power(SIDE_PLAYER), MatchRecords.end_turn(SIDE_PLAYER)])
	_assert_rejected(result, "NO_LEGAL_TARGET")
	assert_int(int(_player(engine).mana_current)).is_equal(MANA_POOL)


func test_required_target_battlecry_with_no_legal_target_still_plays_its_body() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	_required(resolver, DEF_SEEKER, [])
	var engine: RulesEngine = _engine(log, resolver, [DEF_SEEKER], MANA_POOL)

	# Act
	var legal: Array = engine.legal_commands()
	var result: Dictionary = engine.submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0))

	# Assert: playable (null target), a body on the board, no battlecry at all
	assert_array(legal).is_equal([
		MatchRecords.play_card(SIDE_PLAYER, 0, 0), MatchRecords.use_hero_power(SIDE_PLAYER), MatchRecords.end_turn(SIDE_PLAYER),
	])
	assert_bool(result.accepted).is_true()
	assert_int(_player(engine).board.size()).is_equal(1)
	assert_array(_calls(resolver, &"battlecry")).is_empty()


func test_required_target_rules_target_required_and_illegal_target() -> void:
	# Arrange: the bolt may hit the boss hero only
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _engine(TestEventLog.new(), resolver, [DEF_BOLT], MANA_POOL)
	_required(resolver, DEF_BOLT, [_hero_id(engine, SIDE_BOSS)])

	# Act / Assert
	_assert_rejected(engine.submit(MatchRecords.play_card(SIDE_PLAYER, 0)), "TARGET_REQUIRED")
	_assert_rejected(engine.submit(MatchRecords.play_card(SIDE_PLAYER, 0, null, _hero_id(engine, SIDE_PLAYER))), "ILLEGAL_TARGET")
	assert_bool(engine.submit(MatchRecords.play_card(SIDE_PLAYER, 0, null, _hero_id(engine, SIDE_BOSS))).accepted).is_true()
	assert_int(int(_calls(resolver, &"on_cast")[0].target_id)).is_equal(_hero_id(engine, SIDE_BOSS))


func test_optional_target_accepts_null_and_none_ignores_target_id() -> void:
	# Arrange: flare is optional, study is none
	var resolver: TestEffectResolver = TestEffectResolver.new()
	resolver.specs_by_def[DEF_FLARE] = {"mode": RulesEngine.TARGETING_OPTIONAL, "filter": {}}
	var engine: RulesEngine = _engine(TestEventLog.new(), resolver, [DEF_FLARE, DEF_STUDY], MANA_POOL)

	# Act
	var flare: Dictionary = engine.submit(MatchRecords.play_card(SIDE_PLAYER, 0))
	var study: Dictionary = engine.submit(MatchRecords.play_card(SIDE_PLAYER, 0, null, NO_SUCH_ID))

	# Assert
	assert_bool(flare.accepted).is_true()
	assert_bool(study.accepted).is_true()
	var casts: Array[Dictionary] = _calls(resolver, &"on_cast")
	assert_that(casts[0].target_id).is_null()
	assert_that(casts[1].target_id).is_null()


func test_accepted_spell_resolves_from_the_resolving_zone_then_goes_to_the_graveyard() -> void:
	# Arrange: a Spell Damage +1 minion on board; the on_cast pass reads the card's zone
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _engine(log, resolver, [DEF_STUDY], MANA_POOL)
	var sage: Dictionary = MatchFactory.summon(engine.state(), SIDE_PLAYER, 1, 1, -1, ["spell_damage"], DEF_SAGE)
	var card: Dictionary = _player(engine).hand[0]
	var seen: Dictionary = {}
	resolver.scripts[&"on_cast"] = [func(e: RulesEngine, _ctx: Dictionary) -> void:
		seen["zone"] = str(card.zone)
		seen["resolving"] = (e.state().players[SIDE_PLAYER].resolving as Array).has(card)]
	var before: int = log.events.size()
	var calls_before: int = resolver.resolve_calls.size()

	# Act
	assert_bool(engine.submit(MatchRecords.play_card(SIDE_PLAYER, 0)).accepted).is_true()

	# Assert: spell_cast carries F7; on_cast → on_card_played → after_cast → graveyard
	assert_dict(seen).is_equal({"zone": "resolving", "resolving": true})
	var events: Array[Dictionary] = _of(log, before, ["mana_spent", "card_played", "spell_cast", "card_to_graveyard"])
	assert_array(_types(events)).is_equal(["mana_spent", "card_played", "spell_cast", "card_to_graveyard"])
	assert_dict(events[2].payload).is_equal({
		"side": SIDE_PLAYER, "instance_id": int(card.instance_id), "card_id": DEF_STUDY,
		"target_id": null, "spell_damage": SAGE_SPELL_DAMAGE,
	})
	assert_dict(events[3].payload).is_equal({"side": SIDE_PLAYER, "instance_id": int(card.instance_id), "card_id": DEF_STUDY})
	assert_array(_fired(resolver, calls_before)).is_equal(["on_cast", "on_card_played", "after_cast"])
	assert_int(engine.spell_damage(SIDE_PLAYER)).is_equal(SAGE_SPELL_DAMAGE)
	assert_str(str(card.zone)).is_equal("graveyard")
	assert_bool(_player(engine).graveyard.has(card)).is_true()
	assert_bool(_player(engine).resolving.is_empty()).is_true()
	assert_str(str(sage.def_id)).is_equal(DEF_SAGE)


func test_a_resolving_spell_is_the_damage_source_for_lifesteal_and_stats() -> void:
	# Arrange: a Lifesteal spell whose on_cast deals 2 to the boss hero, source = the spell
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _engine(TestEventLog.new(), resolver, [DEF_LEECH_BOLT], MANA_POOL)
	_player(engine).hero.damage_taken = BOLT_DAMAGE
	var boss_hero: int = _hero_id(engine, SIDE_BOSS)
	resolver.scripts[&"on_cast"] = [func(e: RulesEngine, ctx: Dictionary) -> void:
		e.apply_damage(boss_hero, BOLT_DAMAGE, ctx.source)]

	# Act
	assert_bool(engine.submit(MatchRecords.play_card(SIDE_PLAYER, 0)).accepted).is_true()

	# Assert: the card in zone resolving is found as the source — Lifesteal heals, stats attribute
	assert_int(int(_player(engine).hero.damage_taken)).is_equal(0)
	assert_int(int(_player(engine).stats.damage_dealt_by_card[DEF_LEECH_BOLT])).is_equal(BOLT_DAMAGE)


# --- AC-14: weapons -------------------------------------------------------------

func test_playing_a_weapon_destroys_the_old_one_and_resolves_its_deathrattle_first() -> void:
	# Arrange: the hero holds the old blade (a Deathrattle) and has attacked once
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	resolver.hook_scripts["t_herald.0"] = _hook_marker
	var herald: HookInstaller = MatchFactory.make_hook_installer("t_herald", SIDE_PLAYER, [&"on_card_played"])
	var engine: RulesEngine = _engine(log, resolver, [DEF_TWIN_AXE], MANA_POOL, {"player": {"hook_installers": [herald]}})
	var old_id: int = engine.equip_weapon(SIDE_PLAYER, DEF_OLD_BLADE)
	resolver.add_trigger(&"deathrattle", old_id, "dr.blade", _mark)
	var hero: Dictionary = _player(engine).hero
	hero.attacks_used = 1
	var before: int = log.events.size()
	var calls_before: int = resolver.resolve_calls.size()

	# Act
	assert_bool(engine.submit(MatchRecords.play_card(SIDE_PLAYER, 0)).accepted).is_true()

	# Assert: weapon_destroyed(old), its trigger_resolved, weapon_equipped(new), Battlecry, hook
	var events: Array[Dictionary] = _of(log, before, ["weapon_destroyed", "trigger_resolved", "weapon_equipped", String(HOOK_MARKER)])
	assert_array(_types(events)).is_equal(["weapon_destroyed", "trigger_resolved", "weapon_equipped", String(HOOK_MARKER)])
	assert_int(int(events[0].payload.entity_id)).is_equal(old_id)
	assert_int(int(events[1].payload.source_id)).is_equal(old_id)
	var new_id: int = int(events[2].payload.entity_id)
	assert_array(_fired(resolver, calls_before)).is_equal(["deathrattle", "battlecry", "on_card_played", "on_weapon_equipped"])
	assert_int(int(_calls(resolver, &"battlecry")[0].source)).is_equal(new_id)
	assert_bool(int(_of(log, before, ["weapon_equipped"])[0].seq) < int(events[3].seq)).is_true()
	# equipping never resets attacks_used: Windfury after one attack leaves one more
	assert_int(int(hero.attacks_used)).is_equal(1)
	assert_int(engine.attacks_remaining(hero)).is_equal(1)


# --- AC-15: the hero power ------------------------------------------------------

func test_hero_power_pays_marks_used_fires_and_is_once_per_turn() -> void:
	# Arrange: mana exactly the power's cost
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _engine(log, resolver, [], TestConstants.HERO_POWER_COST)
	var before: int = log.events.size()

	# Act
	var first: Dictionary = engine.submit(MatchRecords.use_hero_power(SIDE_PLAYER))
	var second: Dictionary = engine.submit(MatchRecords.use_hero_power(SIDE_PLAYER))

	# Assert: mana 0, hero_power_used, used_this_turn, trigger point hero_power from the hero
	assert_bool(first.accepted).is_true()
	assert_int(int(_player(engine).mana_current)).is_equal(0)
	assert_bool(_player(engine).hero_power.used_this_turn).is_true()
	var events: Array[Dictionary] = _of(log, before, ["mana_spent", "hero_power_used"])
	assert_array(_types(events)).is_equal(["mana_spent", "hero_power_used"])
	assert_dict(events[1].payload).is_equal({"side": SIDE_PLAYER, "power_id": DEF_POWER, "target_id": null})
	var power_ctx: Dictionary = _calls(resolver, &"hero_power")[0]
	assert_int(int(power_ctx.source)).is_equal(_hero_id(engine, SIDE_PLAYER))
	# once per turn, checked before cost (0 mana left): HERO_POWER_USED, not NOT_ENOUGH_MANA
	_assert_rejected(second, "HERO_POWER_USED")
	assert_bool(engine.legal_commands().has(MatchRecords.use_hero_power(SIDE_PLAYER))).is_false()


func test_hero_power_is_usable_again_after_the_next_own_start_step() -> void:
	# Arrange
	var engine: RulesEngine = _engine(TestEventLog.new(), TestEffectResolver.new(), [], TestConstants.HERO_POWER_COST)
	assert_bool(engine.submit(MatchRecords.use_hero_power(SIDE_PLAYER)).accepted).is_true()

	# Act: the boss's turn, then the player's turn 2 (mana 2)
	assert_bool(engine.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()
	assert_bool(engine.submit(MatchRecords.end_turn(SIDE_BOSS)).accepted).is_true()

	# Assert
	assert_bool(_player(engine).hero_power.used_this_turn).is_false()
	assert_bool(engine.legal_commands().has(MatchRecords.use_hero_power(SIDE_PLAYER))).is_true()
	assert_bool(engine.submit(MatchRecords.use_hero_power(SIDE_PLAYER)).accepted).is_true()


func test_required_target_hero_power_with_no_legal_target_is_not_usable() -> void:
	# Arrange
	var resolver: TestEffectResolver = TestEffectResolver.new()
	_required(resolver, DEF_POWER, [])
	var engine: RulesEngine = _engine(TestEventLog.new(), resolver, [], MANA_POOL)

	# Act / Assert
	assert_array(engine.legal_commands()).is_equal([MatchRecords.end_turn(SIDE_PLAYER)])
	_assert_rejected(engine.submit(MatchRecords.use_hero_power(SIDE_PLAYER)), "NO_LEGAL_TARGET")
	assert_bool(_player(engine).hero_power.used_this_turn).is_false()


# --- C2 legal_commands() --------------------------------------------------------

func test_legal_commands_expand_cards_positions_targets_and_the_hero_power() -> void:
	# Arrange: [vanilla, bolt (2 targets), dear (unaffordable)]; one friendly minion
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _engine(TestEventLog.new(), resolver, [DEF_VANILLA, DEF_BOLT, DEF_DEAR], DEAR_COST - 1)
	MatchFactory.summon(engine.state(), SIDE_PLAYER, 1, 1)
	var boss_hero: int = _hero_id(engine, SIDE_BOSS)
	var player_hero: int = _hero_id(engine, SIDE_PLAYER)
	_required(resolver, DEF_BOLT, [player_hero, boss_hero])

	# Act
	var legal: Array = engine.legal_commands()

	# Assert: hand order × positions × targets, then the hero power, then end_turn
	assert_array(legal).is_equal([
		MatchRecords.play_card(SIDE_PLAYER, 0, 0), MatchRecords.play_card(SIDE_PLAYER, 0, 1),
		MatchRecords.play_card(SIDE_PLAYER, 1, null, player_hero), MatchRecords.play_card(SIDE_PLAYER, 1, null, boss_hero),
		MatchRecords.use_hero_power(SIDE_PLAYER),
		MatchRecords.end_turn(SIDE_PLAYER),
	])
	# every listed play is accepted as listed (legality is not trial-submitted inside)
	assert_bool(engine.submit(legal[3]).accepted).is_true()
