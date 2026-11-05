## Unit tests for the engine primitive API and the full `draw` (story
## match-rules/story-006; design/gdd/match-rules.md Interactions — Engine
## primitive API, C11 Hand, draw, burn and fatigue, F5, C15; ADR-0007
## Decision 1, 5, 6; ADR-0003 one event per mutation).
##
## Matches start through `MatchFactory.make_started_engine` and a "keep all"
## mulligan (turn 1, player Main); primitives are then called directly, the
## way `EffectResolver` calls them. Definitions for `summon_minion`,
## `transform` and `equip_weapon` come from [FixtureDb], a test-local stand-in
## for `CardDatabase.card(id)` built with `CardFactory` records.
extends GdUnitTestSuite

const SIDE_PLAYER: String = MatchFactory.SIDE_PLAYER
const SIDE_BOSS: String = MatchFactory.SIDE_BOSS
const HOOK_MARKER: StringName = &"test_hook_marker"
const TRIGGER_MARKER: StringName = &"test_trigger_marker"
## AC-32: four empty-deck draws.
const FATIGUE_DRAWS: int = 4
## AC-32 armour clause: armour before the first fatigue draw.
const FATIGUE_ARMOR: int = 2
## A config with a larger fatigue curve (F5 knobs, inside their safe ranges).
const STEEP_FATIGUE_BASE: int = 2
const STEEP_FATIGUE_STEP: int = 2
## Fixture definitions (CR-2-valid ids).
const DEF_GRUNT: String = "neutral_test_grunt"
const DEF_SHEEP: String = "neutral_test_sheep"
const DEF_AXE: String = "war_test_axe"
const DEF_BLADE: String = "war_test_blade"
const DEF_TOKEN: String = "neutral_test_token"
const GRUNT_ATTACK: int = 2
const GRUNT_HEALTH: int = 3
const SHEEP_STATS: int = 1
const AXE_ATTACK: int = 3
const AXE_DURABILITY: int = 2
const BLADE_ATTACK: int = 1
const BLADE_DURABILITY: int = 3
## An entity id no record carries.
const MISSING_ID: int = 9999


## `CardDatabase.has(id)` / `card(id)` stand-in: the definitions a test
## registers. Like the production `card()` (which asserts in debug on an
## unknown id, card-database story 006) an unknown lookup is a caller bug —
## recorded in [member unknown_lookups] instead of asserting.
class FixtureDb extends RefCounted:
	var cards: Dictionary = {}
	var unknown_lookups: Array[String] = []

	func has(id: String) -> bool:
		return cards.has(id)

	func card(id: String) -> Variant:
		if not cards.has(id):
			unknown_lookups.append(id)
		return cards.get(id)


# --- helpers -----------------------------------------------------------------

func _db() -> FixtureDb:
	var db: FixtureDb = FixtureDb.new()
	db.cards[DEF_GRUNT] = CardFactory.make_minion(DEF_GRUNT, 2, GRUNT_ATTACK, GRUNT_HEALTH, ["taunt"])
	db.cards[DEF_SHEEP] = CardFactory.make_minion(DEF_SHEEP, 1, SHEEP_STATS, SHEEP_STATS)
	db.cards[DEF_AXE] = CardFactory.make_weapon(DEF_AXE, 2, AXE_ATTACK, AXE_DURABILITY)
	db.cards[DEF_BLADE] = CardFactory.make_weapon(DEF_BLADE, 1, BLADE_ATTACK, BLADE_DURABILITY)
	return db


## A started engine past the mulligan: turn 1, player Main.
func _engine(log: TestEventLog, rng: TestRngService = null, overrides: Dictionary = {}, rules_overrides: Dictionary = {}, resolver: TestEffectResolver = null) -> RulesEngine:
	var engine: RulesEngine = MatchFactory.make_started_engine(rng, log, overrides, rules_overrides, resolver, _db())
	var kept: Dictionary = engine.submit(engine.legal_commands()[0])
	assert_bool(kept.accepted).is_true()
	return engine


func _player(engine: RulesEngine, side: String = SIDE_PLAYER) -> Dictionary:
	return engine.state().players[side]


func _hero_id(engine: RulesEngine, side: String) -> int:
	return int(_player(engine, side).hero.entity_id)


## The events appended after [param before] (a log size).
func _since(log: TestEventLog, before: int) -> Array[Dictionary]:
	return log.events.slice(before)


func _types(events: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for event: Dictionary in events:
		out.append(String(event.type))
	return out


## Asserts [param events] is exactly one event of [param type] with
## `cause_seq` [param cause_seq] and a JSON-representable payload; returns it.
func _assert_one(events: Array[Dictionary], type: String, cause_seq: int = 0) -> Dictionary:
	assert_array(_types(events)).is_equal([type])
	if events.size() != 1:
		return {}
	assert_int(int(events[0].cause_seq)).is_equal(cause_seq)
	GameAssertions.assert_json_representable(events[0].payload, "%s payload" % type)
	return events[0]


## Hook script: emits [constant HOOK_MARKER].
func _hook_marker(engine: RulesEngine, entry: Dictionary, side: StringName, _ctx: Dictionary) -> void:
	@warning_ignore("return_value_discarded")
	engine.emit(HOOK_MARKER, {"side": String(side), "effect_id": str(entry.effect_id)})


## Trigger script: emits [constant TRIGGER_MARKER] with the context subject.
func _trigger_marker(engine: RulesEngine, ctx: Dictionary) -> void:
	@warning_ignore("return_value_discarded")
	engine.emit(TRIGGER_MARKER, {"side": str(ctx.side), "subject": ctx.get("subject")})


func _hook_runs(resolver: TestEffectResolver, effect_id: String) -> int:
	var n: int = 0
	for call: Dictionary in resolver.hook_calls:
		if call.kind == "run" and call.effect_id == effect_id:
			n += 1
	return n


func _resolves(resolver: TestEffectResolver, point: StringName) -> int:
	var n: int = 0
	for call: Dictionary in resolver.resolve_calls:
		if call.point == point:
			n += 1
	return n


## Fills [param side]'s hand to `HAND_SIZE` from its deck (fixture moves).
func _fill_hand(engine: RulesEngine, side: String) -> void:
	while _player(engine, side).hand.size() < TestConstants.HAND_SIZE:
		assert_bool(MatchFactory.draw_top(engine.state(), side).is_empty()).is_false()


func _amounts(log: TestEventLog, side: String) -> Array[int]:
	var out: Array[int] = []
	for event: Dictionary in log.of_type(&"fatigue_damage"):
		if event.payload.side == side:
			out.append(int(event.payload.amount))
	return out


# --- AC-31: burn --------------------------------------------------------------

func test_starting_hand_and_mulligan_draws_fire_no_on_draw() -> void:
	# Arrange: an on_draw hook and an on_draw trigger script before setup
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	resolver.hook_scripts["t_quill.0"] = _hook_marker
	resolver.scripts[&"on_draw"] = [_trigger_marker]
	var quill: HookInstaller = MatchFactory.make_hook_installer("t_quill", SIDE_PLAYER, [&"on_draw"])
	var engine: RulesEngine = MatchFactory.make_started_engine(null, log, {"player": {"hook_installers": [quill]}}, {}, resolver, _db())
	var setup_hooks: int = _hook_runs(resolver, "t_quill.0")
	var setup_resolves: int = _resolves(resolver, &"on_draw")
	var replace_all: Array[bool] = []
	for _card: Dictionary in _player(engine).hand:
		replace_all.append(false)
	var hand_before: int = _player(engine).hand.size()

	# Act: replace the whole hand (C3 step 7), then the turn-1 Start-step draw
	assert_bool(engine.submit(MatchRecords.mulligan(replace_all)).accepted).is_true()

	# Assert (DD-X13): setup and mulligan draws fired nothing; the Start-step draw did
	assert_int(setup_hooks).is_equal(0)
	assert_int(setup_resolves).is_equal(0)
	assert_int(log.count(&"card_drawn")).is_equal(hand_before * 2 + TestConstants.STARTING_HAND_BOSS + 1)
	assert_int(_hook_runs(resolver, "t_quill.0")).is_equal(1)
	assert_int(_resolves(resolver, &"on_draw")).is_equal(1)


func test_draw_into_a_full_hand_burns_the_card_without_on_draw() -> void:
	# Arrange: an on_draw hook on the player's side, an on_draw trigger script
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	resolver.hook_scripts["t_quill.0"] = _hook_marker
	resolver.scripts[&"on_draw"] = [_trigger_marker]
	var quill: HookInstaller = MatchFactory.make_hook_installer("t_quill", SIDE_PLAYER, [&"on_draw"])
	var engine: RulesEngine = _engine(log, null, {"player": {"hook_installers": [quill]}}, {}, resolver)
	_fill_hand(engine, SIDE_PLAYER)
	var player: Dictionary = _player(engine)
	var deck_before: int = player.deck.size()
	var top: Dictionary = player.deck[0]
	var hooks_before: int = _hook_runs(resolver, "t_quill.0")
	var resolves_before: int = _resolves(resolver, &"on_draw")
	var before: int = log.events.size()

	# Act
	engine.draw(SIDE_PLAYER, 1)

	# Assert
	var event: Dictionary = _assert_one(_since(log, before), "card_burned")
	assert_dict(event.payload).is_equal({"side": SIDE_PLAYER, "instance_id": int(top.instance_id), "card_id": str(top.def_id)})
	assert_int(player.hand.size()).is_equal(TestConstants.HAND_SIZE)
	assert_int(player.deck.size()).is_equal(deck_before - 1)
	assert_bool(player.graveyard.has(top)).is_true()
	assert_str(str(top.zone)).is_equal("graveyard")
	assert_int(_hook_runs(resolver, "t_quill.0")).is_equal(hooks_before)
	assert_int(_resolves(resolver, &"on_draw")).is_equal(resolves_before)


func test_successful_draw_runs_on_draw_hooks_then_the_on_draw_trigger_point() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	resolver.hook_scripts["t_quill.0"] = _hook_marker
	resolver.scripts[&"on_draw"] = [_trigger_marker]
	var quill: HookInstaller = MatchFactory.make_hook_installer("t_quill", SIDE_PLAYER, [&"on_draw"])
	var engine: RulesEngine = _engine(log, null, {"player": {"hook_installers": [quill]}}, {}, resolver)
	var top: Dictionary = _player(engine).deck[0]
	var before: int = log.events.size()

	# Act
	engine.draw(SIDE_PLAYER, 1)

	# Assert: card_drawn, then the hook, then the trigger point (C11, hook table)
	var events: Array[Dictionary] = _since(log, before)
	assert_array(_types(events)).is_equal(["card_drawn", String(HOOK_MARKER), String(TRIGGER_MARKER)])
	assert_dict(events[0].payload).is_equal({
		"side": SIDE_PLAYER, "instance_id": int(top.instance_id), "card_id": str(top.def_id),
		"hand_size": _player(engine).hand.size(),
	})
	assert_int(int(events[2].payload.subject)).is_equal(int(top.instance_id))
	var last_resolve: Dictionary = resolver.resolve_calls[resolver.resolve_calls.size() - 1]
	assert_str(String(last_resolve.point)).is_equal("on_draw")
	assert_str(str(last_resolve.ctx.side)).is_equal(SIDE_PLAYER)


# --- AC-32: fatigue -----------------------------------------------------------

func test_four_empty_deck_draws_deal_fatigue_1_2_3_4() -> void:
	# Arrange: the player's deck emptied (fixture), hero at 30
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log)
	var player: Dictionary = _player(engine)
	player.deck.clear()
	var hero: Dictionary = player.hero

	# Act
	for _i: int in FATIGUE_DRAWS:
		engine.draw(SIDE_PLAYER, 1)

	# Assert (F5: FATIGUE_BASE + (k − 1) × FATIGUE_STEP)
	assert_array(_amounts(log, SIDE_PLAYER)).is_equal([1, 2, 3, 4])
	assert_int(engine.health(hero)).is_equal(TestConstants.PLAYER_STARTING_HEALTH - 10)
	assert_int(int(player.fatigue_counter)).is_equal(FATIGUE_DRAWS)
	assert_int(int(_player(engine, SIDE_BOSS).fatigue_counter)).is_equal(0)
	var last: Dictionary = log.last()
	assert_dict(last.payload).is_equal({"side": SIDE_PLAYER, "amount": 4, "counter": 4})
	# each fatigue hit went through apply_damage with no source (DD-X14)
	var hits: Array[Dictionary] = log.of_type(&"damage_dealt")
	assert_int(hits.size()).is_equal(FATIGUE_DRAWS)
	for hit: Dictionary in hits:
		assert_that(hit.payload.source).is_null()
		assert_int(int(hit.payload.target)).is_equal(int(hero.entity_id))


func test_fatigue_counter_is_per_side_and_never_resets_across_turns() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log)
	_player(engine).deck.clear()
	engine.draw(SIDE_PLAYER, 1)

	# Act: the boss's turn, then the player's Start-step draw
	assert_bool(engine.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()
	assert_bool(engine.submit(MatchRecords.end_turn(SIDE_BOSS)).accepted).is_true()

	# Assert: the Start-step draw is fatigue 2; the boss drew a card, no fatigue
	assert_array(_amounts(log, SIDE_PLAYER)).is_equal([1, 2])
	assert_array(_amounts(log, SIDE_BOSS)).is_equal([])
	assert_int(int(_player(engine).fatigue_counter)).is_equal(2)


func test_fatigue_amount_reads_the_fatigue_knobs() -> void:
	# Arrange: FATIGUE_BASE 2, FATIGUE_STEP 2 through the injected rules config
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log, null, {}, {"fatigue_base": STEEP_FATIGUE_BASE, "fatigue_step": STEEP_FATIGUE_STEP})
	_player(engine).deck.clear()

	# Act
	engine.draw(SIDE_PLAYER, 3)

	# Assert
	assert_array(_amounts(log, SIDE_PLAYER)).is_equal([2, 4, 6])


func test_armour_absorbs_fatigue_before_health() -> void:
	# Arrange: 2 armour before the first empty-deck draw
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log)
	var player: Dictionary = _player(engine)
	player.deck.clear()
	engine.apply_armor(SIDE_PLAYER, FATIGUE_ARMOR)

	# Act: fatigue 1 then 2
	engine.draw(SIDE_PLAYER, 2)

	# Assert: 3 damage, 2 absorbed → health 29, not 27
	assert_int(engine.health(player.hero)).is_equal(TestConstants.PLAYER_STARTING_HEALTH - 1)
	assert_int(int(player.hero.armor)).is_equal(0)
	var hits: Array[Dictionary] = log.of_type(&"damage_dealt")
	assert_int(int(hits[0].payload.armor_absorbed)).is_equal(1)
	assert_int(int(hits[1].payload.armor_absorbed)).is_equal(1)
	assert_int(int(hits[1].payload.dealt)).is_equal(2)


func test_empty_deck_at_match_start_applies_fatigue_1_2_3_before_the_mulligan() -> void:
	# Arrange / Act: a 0-card player deck (malformed config — not special-cased)
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = MatchFactory.make_started_engine(null, log, {"player": {"deck": []}})

	# Assert
	assert_array(_amounts(log, SIDE_PLAYER)).is_equal([1, 2, 3])
	assert_int(engine.health(_player(engine).hero)).is_equal(TestConstants.PLAYER_STARTING_HEALTH - 6)
	var types: Array[String] = log.types()
	assert_int(types.rfind("fatigue_damage")).is_less(types.find("mulligan_offered"))
	assert_array(log.first(&"mulligan_offered").payload.instance_ids).is_empty()


# --- AC-33: draw N is N draws -------------------------------------------------

func test_draw_two_with_one_card_left_draws_one_then_takes_fatigue_1() -> void:
	# Arrange: one card left
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log)
	var deck: Array = _player(engine).deck
	while deck.size() > 1:
		deck.pop_back()
	var before: int = log.events.size()

	# Act
	engine.draw(SIDE_PLAYER, 2)

	# Assert: one card_drawn, then fatigue 1 (its damage_dealt between)
	var events: Array[Dictionary] = _since(log, before)
	assert_array(_types(events)).is_equal(["card_drawn", "damage_dealt", "fatigue_damage"])
	assert_int(int(events[2].payload.amount)).is_equal(1)
	assert_bool(deck.is_empty()).is_true()


# --- Interactions / C15: one event per primitive -----------------------------

func test_primitive_api_lists_the_engine_primitives() -> void:
	# Arrange
	var engine: RulesEngine = _engine(TestEventLog.new())

	# Assert: 23 engine methods + recompute_auras via the loop = the 24 calls
	assert_int(RulesEngine.PRIMITIVES.size()).is_equal(23)
	for name: StringName in RulesEngine.PRIMITIVES:
		assert_bool(engine.has_method(name)).override_failure_message("RulesEngine lacks primitive %s" % name).is_true()


func test_apply_damage_emits_damage_dealt_with_the_f2_numbers() -> void:
	# Arrange: a 2/3 boss minion, a player minion as the source
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log)
	var target: Dictionary = MatchFactory.summon(engine.state(), SIDE_BOSS, 2, 3)
	var source: Dictionary = MatchFactory.summon(engine.state(), SIDE_PLAYER, 1, 1, -1, [], DEF_GRUNT)
	var before: int = log.events.size()

	# Act
	var dealt: int = engine.apply_damage(int(target.entity_id), 2, int(source.entity_id))

	# Assert
	var event: Dictionary = _assert_one(_since(log, before), "damage_dealt")
	assert_dict(event.payload).is_equal({
		"source": int(source.entity_id), "target": int(target.entity_id), "requested": 2,
		"prevented": 0, "armor_absorbed": 0, "dealt": 2, "health_after": 1,
	})
	assert_int(dealt).is_equal(2)
	assert_int(int(target.damage_taken)).is_equal(2)
	assert_int(int(_player(engine).stats.damage_dealt_by_card[DEF_GRUNT])).is_equal(2)
	assert_int(int(_player(engine, SIDE_BOSS).stats.damage_taken)).is_equal(2)


func test_apply_heal_emits_healed_with_the_restored_amount() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log)
	var hero: Dictionary = _player(engine).hero
	hero.damage_taken = 3
	var before: int = log.events.size()

	# Act
	var restored: int = engine.apply_heal(int(hero.entity_id), 2, int(hero.entity_id))

	# Assert
	var event: Dictionary = _assert_one(_since(log, before), "healed")
	assert_dict(event.payload).is_equal({"source": int(hero.entity_id), "target": int(hero.entity_id), "requested": 2, "amount": 2})
	assert_int(restored).is_equal(2)
	assert_int(int(hero.damage_taken)).is_equal(1)


func test_apply_armor_emits_armor_gained() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log)
	var before: int = log.events.size()

	# Act
	engine.apply_armor(SIDE_BOSS, 4)

	# Assert
	var event: Dictionary = _assert_one(_since(log, before), "armor_gained")
	assert_dict(event.payload).is_equal({"side": SIDE_BOSS, "entity_id": _hero_id(engine, SIDE_BOSS), "amount": 4, "armor": 4})


func test_apply_and_remove_enchantment_emit_one_event_each() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log)
	var minion: Dictionary = MatchFactory.summon(engine.state(), SIDE_PLAYER, 1, 1)
	var before: int = log.events.size()

	# Act
	engine.apply_enchantment(int(minion.entity_id), {"attack_delta": 2, "health_delta": 1, "keywords_added": ["taunt"]})
	var applied: Array[Dictionary] = _since(log, before)
	var mid: int = log.events.size()
	var buffed: Array = [engine.attack(minion), engine.health(minion)]
	engine.remove_enchantment(int(minion.entity_id), 0)

	# Assert
	var event: Dictionary = _assert_one(applied, "enchantment_applied")
	assert_dict(event.payload).is_equal({
		"instance_id": int(minion.entity_id), "attack_delta": 2, "health_delta": 1,
		"keywords_added": ["taunt"], "source_entity_id": null, "is_aura": false, "expires": null,
	})
	assert_array(buffed).is_equal([3, 2])
	var removed: Dictionary = _assert_one(_since(log, mid), "enchantment_removed")
	assert_str(str(removed.payload.reason)).is_equal(RulesEngine.REMOVE_REASON_EFFECT)
	assert_array(minion.enchantments).is_empty()


func test_summon_minion_inserts_a_sick_minion_from_its_definition() -> void:
	# Arrange: one minion already on the player's board
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log)
	var left: Dictionary = MatchFactory.summon(engine.state(), SIDE_PLAYER, 1, 1)
	var before: int = log.events.size()

	# Act: position 0 inserts left of it
	var id: int = engine.summon_minion(SIDE_PLAYER, DEF_GRUNT, 0)

	# Assert
	var board: Array = _player(engine).board
	var minion: Dictionary = board[0]
	var event: Dictionary = _assert_one(_since(log, before), "minion_summoned")
	assert_dict(event.payload).is_equal({
		"side": SIDE_PLAYER, "entity_id": id, "card_id": DEF_GRUNT, "position": 0,
		"attack": GRUNT_ATTACK, "health": GRUNT_HEALTH, "keywords": ["taunt"],
	})
	assert_int(int(minion.entity_id)).is_equal(id)
	assert_bool(board[1] == left).is_true()
	assert_bool(minion.summoning_sick).is_true()
	assert_int(int(minion.summoned_on_turn)).is_equal(engine.state().turn)
	assert_array(minion.keywords).is_equal(["taunt"])
	assert_int(int(_player(engine).stats.minions_summoned)).is_equal(2)


func test_summon_minion_past_the_end_goes_rightmost_and_a_full_board_fails() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log)
	MatchFactory.summon(engine.state(), SIDE_BOSS, 1, 1)

	# Act: an index beyond the end clamps to the rightmost slot
	var id: int = engine.summon_minion(SIDE_BOSS, DEF_SHEEP, 5)
	var board: Array = _player(engine, SIDE_BOSS).board
	var rightmost: int = int(board[board.size() - 1].entity_id)
	while board.size() < TestConstants.BOARD_SIZE:
		MatchFactory.summon(engine.state(), SIDE_BOSS, 1, 1)
	var before: int = log.events.size()
	var next_id: int = engine.state().next_entity_id
	var failed: int = engine.summon_minion(SIDE_BOSS, DEF_SHEEP, 0)

	# Assert
	assert_int(rightmost).is_equal(id)
	var event: Dictionary = _assert_one(_since(log, before), "summon_failed")
	assert_dict(event.payload).is_equal({"side": SIDE_BOSS, "card_id": DEF_SHEEP, "reason": "board_full"})
	assert_int(failed).is_equal(-1)
	assert_int(board.size()).is_equal(TestConstants.BOARD_SIZE)
	assert_int(engine.state().next_entity_id).is_equal(next_id)


func test_destroy_marks_pending_destroy_and_leaves_the_minion_in_play() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log)
	var minion: Dictionary = MatchFactory.summon(engine.state(), SIDE_BOSS, 5, 5)
	var before: int = log.events.size()

	# Act
	engine.destroy(int(minion.entity_id))

	# Assert: it dies in the next death check (minion_died, story 009)
	assert_bool(bool(minion.get("pending_destroy", false))).is_true()
	assert_bool(_player(engine, SIDE_BOSS).board.has(minion)).is_true()
	assert_array(_since(log, before)).is_empty()


func test_silence_and_freeze_emit_their_status_events() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log)
	var minion: Dictionary = MatchFactory.summon(engine.state(), SIDE_BOSS, 2, 2)
	var id: int = int(minion.entity_id)
	var before: int = log.events.size()

	# Act
	engine.silence(id)
	var mid: int = log.events.size()
	engine.freeze(id)

	# Assert
	var silenced: Dictionary = _assert_one(log.events.slice(before, mid), "silenced")
	# story 015 completes silence: the payload also lists what it stripped
	assert_dict(silenced.payload).is_equal({"entity_id": id, "removed_enchantments": [], "removed_keywords": []})
	assert_bool(minion.silenced).is_true()
	var frozen: Dictionary = _assert_one(_since(log, mid), "frozen")
	assert_dict(frozen.payload).is_equal({"entity_id": id, "frozen_on_turn": engine.state().turn})
	assert_bool(minion.frozen).is_true()
	assert_int(int(minion.frozen_on_turn)).is_equal(engine.state().turn)


func test_add_keyword_grants_it_through_an_enchantment_and_remove_keyword_strips_it() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log)
	var minion: Dictionary = MatchFactory.summon(engine.state(), SIDE_PLAYER, 2, 2, -1, ["taunt"])
	var id: int = int(minion.entity_id)
	var before: int = log.events.size()

	# Act
	engine.add_keyword(id, "divine_shield")
	var granted: Array[Dictionary] = _since(log, before)
	var mid: int = log.events.size()
	engine.remove_keyword(id, "taunt")
	var removed: Array[Dictionary] = _since(log, mid)
	var late: int = log.events.size()
	engine.remove_keyword(id, "stealth")

	# Assert
	var event: Dictionary = _assert_one(granted, "enchantment_applied")
	assert_array(event.payload.keywords_added).is_equal(["divine_shield"])
	assert_bool(MatchFactory.has_keyword(minion, "divine_shield")).is_true()
	var gone: Dictionary = _assert_one(removed, "keyword_removed")
	assert_dict(gone.payload).is_equal({"entity_id": id, "keyword": "taunt"})
	assert_bool(MatchFactory.has_keyword(minion, "taunt")).is_false()
	# a keyword the target does not hold: no mutation, no event
	assert_array(_since(log, late)).is_empty()


func test_return_to_hand_moves_a_fresh_card_instance_of_its_definition() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log)
	var minion: Dictionary = MatchFactory.summon(engine.state(), SIDE_PLAYER, 4, 4, -1, [], DEF_GRUNT)
	minion.damage_taken = 2
	var hand: Array = _player(engine).hand
	var before: int = log.events.size()

	# Act
	var instance_id: int = engine.return_to_hand(int(minion.entity_id))

	# Assert: one minion_returned (C15, code review 2026-11-03), no card_added_to_hand
	var event: Dictionary = _assert_one(_since(log, before), "minion_returned")
	assert_dict(event.payload).is_equal({
		"side": SIDE_PLAYER, "entity_id": int(minion.entity_id), "card_id": DEF_GRUNT,
		"instance_id": instance_id, "burned": false,
	})
	assert_bool(_player(engine).board.is_empty()).is_true()
	var card: Dictionary = hand[hand.size() - 1]
	assert_int(int(card.instance_id)).is_equal(instance_id)
	assert_str(str(card.def_id)).is_equal(DEF_GRUNT)
	assert_bool(instance_id != int(minion.entity_id)).is_true()


func test_return_to_hand_into_a_full_hand_burns_with_one_minion_returned() -> void:
	# Arrange: a full hand
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log)
	var minion: Dictionary = MatchFactory.summon(engine.state(), SIDE_PLAYER, 4, 4, -1, [], DEF_GRUNT)
	_fill_hand(engine, SIDE_PLAYER)
	var before: int = log.events.size()

	# Act
	var instance_id: int = engine.return_to_hand(int(minion.entity_id))

	# Assert: burned: true and no separate card_burned
	var event: Dictionary = _assert_one(_since(log, before), "minion_returned")
	assert_dict(event.payload).is_equal({
		"side": SIDE_PLAYER, "entity_id": int(minion.entity_id), "card_id": DEF_GRUNT,
		"instance_id": instance_id, "burned": true,
	})
	assert_int(_player(engine).hand.size()).is_equal(TestConstants.HAND_SIZE)
	var grave: Array = _player(engine).graveyard
	assert_int(int(grave[grave.size() - 1].instance_id)).is_equal(instance_id)
	assert_bool(_player(engine).board.is_empty()).is_true()


func test_summon_of_an_unknown_definition_asks_has_before_card() -> void:
	# Arrange: CardDatabase.card() asserts on an unknown id (card-database 006)
	var log: TestEventLog = TestEventLog.new()
	var db: FixtureDb = _db()
	var engine: RulesEngine = MatchFactory.make_started_engine(null, log, {}, {}, null, db)
	assert_bool(engine.submit(engine.legal_commands()[0]).accepted).is_true()
	var before: int = log.events.size()

	# Act
	var id: int = engine.summon_minion(SIDE_PLAYER, "neutral_test_missing", -1)

	# Assert: the documented no-op, and card() was never asked for the unknown id
	assert_int(id).is_equal(RulesEngine.NO_ENTITY)
	assert_array(_since(log, before)).is_empty()
	assert_array(db.unknown_lookups).is_empty()


func test_fatigue_folds_modify_damage_with_no_source() -> void:
	# Arrange: a player-side modify_damage hook; the player's deck is empty
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var effects: Array[Dictionary] = [{
		"id": "t_ward.0", "trigger": "modify_damage", "scope": {}, "condition": {},
		"ops": [{"op": TestEffectResolver.OP_MODIFY_VALUE, "delta": -1}], "once_per_turn": false,
	}]
	var ward: HookInstaller = HookInstaller.new(HookInstaller.HOST_KIND_TREASURE, "t_ward", &"player", effects)
	var engine: RulesEngine = _engine(TestEventLog.new(), null, {"player": {"hook_installers": [ward]}}, {}, resolver)
	_player(engine).deck.clear()
	var calls_before: int = resolver.hook_calls.size()

	# Act
	engine.draw(SIDE_PLAYER, 1)

	# Assert (DD-X14): the fold ran with ctx.source null, on the target's side
	var calls: Array[Dictionary] = resolver.hook_calls.slice(calls_before)
	assert_int(calls.size()).is_equal(1)
	if calls.size() == 1:
		assert_that(calls[0].ctx.source).is_null()
		assert_str(String(calls[0].side)).is_equal(SIDE_PLAYER)


func test_transform_replaces_the_minion_in_place_with_a_new_entity() -> void:
	# Arrange: a buffed, damaged, exhausted 2/2 between two others
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log)
	var state: MatchState = engine.state()
	MatchFactory.summon(state, SIDE_BOSS, 1, 1)
	var victim: Dictionary = MatchFactory.summon(state, SIDE_BOSS, 2, 2)
	MatchFactory.summon(state, SIDE_BOSS, 1, 1)
	victim.enchantments.append(MatchFactory.make_enchantment(3, 3))
	victim.damage_taken = 1
	victim.summoning_sick = false
	victim.attacks_used = 1
	var before: int = log.events.size()

	# Act
	var id: int = engine.transform(int(victim.entity_id), DEF_SHEEP)

	# Assert
	var sheep: Dictionary = _player(engine, SIDE_BOSS).board[1]
	var event: Dictionary = _assert_one(_since(log, before), "minion_transformed")
	assert_dict(event.payload).is_equal({
		"side": SIDE_BOSS, "entity_id": id, "from_card_id": "", "to_card_id": DEF_SHEEP,
		"old_entity_id": int(victim.entity_id), "position": 1,
	})
	assert_int(int(sheep.entity_id)).is_equal(id)
	assert_bool(id != int(victim.entity_id)).is_true()
	assert_array([engine.attack(sheep), engine.health(sheep)]).is_equal([SHEEP_STATS, SHEEP_STATS])
	assert_array(sheep.enchantments).is_empty()
	# no summoning-sickness reset (card-effects `transform` row)
	assert_bool(sheep.summoning_sick).is_false()
	assert_int(int(sheep.attacks_used)).is_equal(1)


func test_add_mana_emits_mana_added() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log)
	var before: int = log.events.size()

	# Act
	engine.add_mana(SIDE_PLAYER, 1, false)

	# Assert
	var event: Dictionary = _assert_one(_since(log, before), "mana_added")
	assert_dict(event.payload).is_equal({"side": SIDE_PLAYER, "n": 1, "temporary": false})


func test_equip_weapon_equips_and_replaces_the_old_weapon_first() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log)
	var before: int = log.events.size()

	# Act
	var axe_id: int = engine.equip_weapon(SIDE_PLAYER, DEF_AXE)
	var mid: int = log.events.size()
	var blade_id: int = engine.equip_weapon(SIDE_PLAYER, DEF_BLADE)

	# Assert
	var first: Dictionary = _assert_one(log.events.slice(before, mid), "weapon_equipped")
	assert_dict(first.payload).is_equal({
		"side": SIDE_PLAYER, "entity_id": axe_id, "card_id": DEF_AXE,
		"attack": AXE_ATTACK, "durability": AXE_DURABILITY,
	})
	var replaced: Array[Dictionary] = _since(log, mid)
	assert_array(_types(replaced)).is_equal(["weapon_destroyed", "weapon_equipped"])
	assert_dict(replaced[0].payload).is_equal({"side": SIDE_PLAYER, "entity_id": axe_id, "card_id": DEF_AXE, "reason": "replaced"})
	var weapon: Dictionary = _player(engine).weapon
	assert_int(int(weapon.entity_id)).is_equal(blade_id)
	assert_int(engine.attack(_player(engine).hero)).is_equal(BLADE_ATTACK)


func test_discover_creates_the_choice_request_and_emits_choice_requested() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log)
	var before: int = log.events.size()
	var options: Array = [DEF_GRUNT, DEF_SHEEP, DEF_TOKEN]

	# Act
	var request: Dictionary = engine.discover(SIDE_PLAYER, options, MatchRecords.CHOICE_DISCOVER, 7, "c_scout.0")

	# Assert
	var expected: Dictionary = {"side": SIDE_PLAYER, "kind": "discover", "options": options, "source_id": 7, "effect_id": "c_scout.0"}
	assert_dict(request).is_equal(expected)
	# match-rules story 016: raising the request also enters Choice first
	var events: Array[Dictionary] = _since(log, before)
	assert_array(_types(events)).is_equal(["phase_changed", "choice_requested"])
	var event: Dictionary = events[events.size() - 1]
	assert_dict(event.payload).is_equal(expected)
	assert_dict(engine.pending_choice()).is_equal(expected)


func test_add_card_to_hand_adds_or_burns_on_a_full_hand() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log)
	var hand: Array = _player(engine).hand
	var before: int = log.events.size()

	# Act
	var added: int = engine.add_card_to_hand(SIDE_PLAYER, DEF_TOKEN)
	var mid: int = log.events.size()
	_fill_hand(engine, SIDE_PLAYER)
	var late: int = log.events.size()
	var burned: int = engine.add_card_to_hand(SIDE_PLAYER, DEF_TOKEN)

	# Assert
	var event: Dictionary = _assert_one(log.events.slice(before, mid), "card_added_to_hand")
	assert_dict(event.payload).is_equal({"side": SIDE_PLAYER, "instance_id": added, "card_id": DEF_TOKEN, "hand_size": event.payload.hand_size})
	assert_int(int(event.payload.hand_size)).is_equal(TestConstants.STARTING_HAND_PLAYER + 2)
	var burn: Dictionary = _assert_one(_since(log, late), "card_burned")
	assert_dict(burn.payload).is_equal({"side": SIDE_PLAYER, "instance_id": burned, "card_id": DEF_TOKEN})
	assert_int(hand.size()).is_equal(TestConstants.HAND_SIZE)
	assert_int(int(_player(engine).graveyard[0].instance_id)).is_equal(burned)


func test_set_stats_sets_attack_and_health_without_writing_base_stats() -> void:
	# Arrange: a damaged 2/5
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log)
	var minion: Dictionary = MatchFactory.summon(engine.state(), SIDE_BOSS, 2, 5)
	minion.damage_taken = 3
	var before: int = log.events.size()

	# Act
	engine.set_stats(int(minion.entity_id), 4, 1)

	# Assert
	var event: Dictionary = _assert_one(_since(log, before), "enchantment_applied")
	assert_str(str(event.payload.reason)).is_equal(RulesEngine.ENCHANT_REASON_SET_STATS)
	assert_array([engine.attack(minion), engine.health(minion), engine.max_health(minion)]).is_equal([4, 1, 1])
	assert_array([int(minion.base_attack), int(minion.base_health)]).is_equal([2, 5])


func test_add_card_to_deck_places_top_bottom_and_random_with_one_match_draw() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var rng: TestRngService = TestRngService.new()
	var engine: RulesEngine = _engine(log, rng)
	var deck: Array = _player(engine).deck
	var stream: TestRngStream = rng.stream("match_1")
	var before: int = log.events.size()

	# Act
	var top: int = engine.add_card_to_deck(SIDE_PLAYER, DEF_TOKEN, MatchRecords.POSITION_TOP)
	var bottom: int = engine.add_card_to_deck(SIDE_PLAYER, DEF_TOKEN, MatchRecords.POSITION_BOTTOM)
	var ends: Array = [int(deck[0].instance_id), int(deck[deck.size() - 1].instance_id)]
	var draws_before: int = stream.count_calls("randi_range")
	var outside_before: int = rng.draws_outside(["match_1"])
	var mid: int = log.events.size()
	var random: int = engine.add_card_to_deck(SIDE_PLAYER, DEF_TOKEN, MatchRecords.POSITION_RANDOM)

	# Assert
	var placed: Array[Dictionary] = log.events.slice(before, mid)
	assert_array(_types(placed)).is_equal(["card_added_to_deck", "card_added_to_deck"])
	assert_array(ends).is_equal([top, bottom])
	var event: Dictionary = _assert_one(_since(log, mid), "card_added_to_deck")
	assert_int(int(deck[int(event.payload.index)].instance_id)).is_equal(random)
	assert_dict(event.payload).is_equal({
		"side": SIDE_PLAYER, "instance_id": random, "card_id": DEF_TOKEN, "position": "random",
		"index": event.payload.index, "deck_size": deck.size(),
	})
	assert_int(stream.count_calls("randi_range") - draws_before).is_equal(1)
	assert_int(rng.draws_outside(["match_1"]) - outside_before).is_equal(0)


func test_modify_durability_and_refresh_hero_power_emit_one_event_each() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log)
	var axe_id: int = engine.equip_weapon(SIDE_PLAYER, DEF_AXE)
	_player(engine).hero_power.used_this_turn = true
	var before: int = log.events.size()

	# Act
	engine.modify_durability(axe_id, -1)
	var mid: int = log.events.size()
	engine.refresh_hero_power(SIDE_PLAYER)
	var late: int = log.events.size()
	engine.refresh_hero_power(SIDE_PLAYER)

	# Assert
	var changed: Dictionary = _assert_one(log.events.slice(before, mid), "weapon_durability_changed")
	assert_dict(changed.payload).is_equal({"side": SIDE_PLAYER, "entity_id": axe_id, "delta": -1, "durability": AXE_DURABILITY - 1})
	var refreshed: Dictionary = _assert_one(log.events.slice(mid, late), "hero_power_refreshed")
	assert_dict(refreshed.payload).is_equal({"side": SIDE_PLAYER})
	assert_bool(_player(engine).hero_power.used_this_turn).is_false()
	# refreshing an unused power changes nothing and logs nothing
	assert_array(_since(log, late)).is_empty()


func test_discard_by_index_and_at_random_with_one_match_draw() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var rng: TestRngService = TestRngService.new()
	var engine: RulesEngine = _engine(log, rng)
	var player: Dictionary = _player(engine)
	var first: Dictionary = player.hand[0]
	var stream: TestRngStream = rng.stream("match_1")
	var before: int = log.events.size()

	# Act
	var discarded: int = engine.discard(SIDE_PLAYER, 0)
	var mid: int = log.events.size()
	var draws_before: int = stream.count_calls("randi_range")
	var outside_before: int = rng.draws_outside(["match_1"])
	var size_before: int = player.hand.size()
	var random: int = engine.discard(SIDE_PLAYER, MatchRecords.PICK_RANDOM)

	# Assert
	var event: Dictionary = _assert_one(log.events.slice(before, mid), "card_discarded")
	assert_dict(event.payload).is_equal({"side": SIDE_PLAYER, "instance_id": discarded, "card_id": str(first.def_id), "hand_index": 0})
	assert_int(discarded).is_equal(int(first.instance_id))
	assert_str(str(first.zone)).is_equal("graveyard")
	var pick: Dictionary = _assert_one(_since(log, mid), "card_discarded")
	assert_int(int(pick.payload.instance_id)).is_equal(random)
	assert_int(player.hand.size()).is_equal(size_before - 1)
	assert_int(player.graveyard.size()).is_equal(2)
	assert_int(stream.count_calls("randi_range") - draws_before).is_equal(1)
	assert_int(rng.draws_outside(["match_1"]) - outside_before).is_equal(0)


func test_primitive_on_a_missing_entity_is_a_no_op_without_an_event() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log)
	var before: int = log.events.size()

	# Act
	assert_int(engine.apply_damage(MISSING_ID, 3, null)).is_equal(0)
	assert_int(engine.apply_heal(MISSING_ID, 3, null)).is_equal(0)
	engine.freeze(MISSING_ID)
	engine.silence(MISSING_ID)
	engine.destroy(MISSING_ID)
	engine.apply_enchantment(MISSING_ID, {"attack_delta": 1})
	engine.modify_durability(MISSING_ID, 1)
	assert_int(engine.return_to_hand(MISSING_ID)).is_equal(-1)
	assert_int(engine.transform(MISSING_ID, DEF_SHEEP)).is_equal(-1)

	# Assert
	assert_array(_since(log, before)).is_empty()


func test_primitives_stamp_the_cause_seq_the_engine_holds_for_the_step() -> void:
	# Arrange: the engine attributes the current step to event 5 (story 009
	# sets this per queued step; a command's direct consequences carry 0)
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log)
	var minion: Dictionary = MatchFactory.summon(engine.state(), SIDE_BOSS, 2, 2)
	engine._cause_seq = 5
	var before: int = log.events.size()

	# Act
	engine.apply_damage(int(minion.entity_id), 1, null)
	engine.draw(SIDE_BOSS, 1)

	# Assert
	for event: Dictionary in _since(log, before):
		assert_int(int(event.cause_seq)).is_equal(5)
