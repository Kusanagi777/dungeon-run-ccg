## Unit tests for the turn loop — C3 step 8, the C4 Start and End steps,
## F4 mana by turn, C5 permanent crystals and the C14 `TURN_CAP` end (story
## match-rules/story-005; design/gdd/match-rules.md C3, C4, C5, F4, C14,
## States and Transitions; ADR-0007 Decision 1, ADR-0005 Decision 4).
##
## Matches start through `MatchFactory.make_started_engine` and a "keep all"
## mulligan; turns advance with `end_turn` from the active side. The scripted
## `TestEffectResolver` records `ctx.candidates` per `resolve` call, and hook
## or trigger scripts emit marker events so their place in the log is visible.
extends GdUnitTestSuite

const SIDE_PLAYER: String = MatchFactory.SIDE_PLAYER
const SIDE_BOSS: String = MatchFactory.SIDE_BOSS
const HOOK_MARKER: StringName = &"test_hook_marker"
const TRIGGER_MARKER: StringName = &"test_trigger_marker"
## AC-06: each side takes this many turns.
const TURNS_EACH: int = 12
## AC-10's test TURN_CAP (below the shipped safe range on purpose).
const SMALL_TURN_CAP: int = 4
## F4 example: global turn 7 is the player's 4th own turn.
const F4_EXAMPLE_GLOBAL_TURN: int = 7
const F4_EXAMPLE_CRYSTALS: int = 4


# --- helpers -----------------------------------------------------------------

func _keep_all(engine: RulesEngine) -> Dictionary:
	return engine.submit(engine.legal_commands()[0])


## A started engine past the mulligan: turn 1, player Main.
func _engine_at_turn_one(log: TestEventLog = null, overrides: Dictionary = {}, rules_overrides: Dictionary = {}, resolver: TestEffectResolver = null) -> RulesEngine:
	var engine: RulesEngine = MatchFactory.make_started_engine(null, log, overrides, rules_overrides, resolver)
	assert_bool(_keep_all(engine).accepted).is_true()
	return engine


func _end_turn(engine: RulesEngine) -> Dictionary:
	return engine.submit(MatchRecords.end_turn(String(engine.active_side())))


## [param count] `end_turn`s from the active side, each asserted accepted;
## stops at the first rejection (bounded — never loops on a stuck engine).
func _end_turns(engine: RulesEngine, count: int) -> void:
	for i: int in count:
		var result: Dictionary = _end_turn(engine)
		assert_bool(result.accepted).override_failure_message("end_turn %d rejected: %s" % [i + 1, str(result.rejection)]).is_true()
		if not result.accepted:
			return


## Hook script: emits [constant HOOK_MARKER] for the side it ran on.
func _hook_marker(engine: RulesEngine, entry: Dictionary, side: StringName, _ctx: Dictionary) -> void:
	@warning_ignore("return_value_discarded")
	engine.emit(HOOK_MARKER, {"side": String(side), "effect_id": str(entry.effect_id)})


## Trigger script: emits [constant TRIGGER_MARKER] with the fired side.
func _trigger_marker(engine: RulesEngine, ctx: Dictionary) -> void:
	@warning_ignore("return_value_discarded")
	engine.emit(TRIGGER_MARKER, {"side": str(ctx.side)})


## Hook script: Hollow Crown — one permanent crystal for the hook's side.
func _crown(engine: RulesEngine, _entry: Dictionary, side: StringName, _ctx: Dictionary) -> void:
	engine.add_mana(String(side), 1, false)


## The event types from the first event of [param type] onward.
func _types_from(log: TestEventLog, type: String) -> Array[String]:
	var types: Array[String] = log.types()
	return types.slice(types.find(type))


## Per side, the `mana_max` of every `mana_refilled` in order.
func _refills(log: TestEventLog, side: String) -> Array[int]:
	var out: Array[int] = []
	for event: Dictionary in log.of_type(&"mana_refilled"):
		if event.payload.side == side:
			out.append(int(event.payload.mana_max))
	return out


func _count_side(log: TestEventLog, type: StringName, side: String) -> int:
	var n: int = 0
	for event: Dictionary in log.of_type(type):
		if event.payload.get("side", "") == side:
			n += 1
	return n


# --- AC-05: the first Start step ----------------------------------------------

func test_first_start_step_gives_turn_one_player_one_crystal_and_four_cards() -> void:
	# Arrange / Act
	var engine: RulesEngine = _engine_at_turn_one()
	var player: Dictionary = engine.state().players[SIDE_PLAYER]

	# Assert
	assert_int(engine.state().turn).is_equal(1)
	assert_str(String(engine.active_side())).is_equal(SIDE_PLAYER)
	assert_str(engine.phase()).is_equal(MatchState.PHASE_MAIN)
	assert_int(player.mana_current).is_equal(1)
	assert_int(player.mana_max).is_equal(1)
	assert_int(player.turns_taken).is_equal(1)
	assert_int(player.hand.size()).is_equal(TestConstants.STARTING_HAND_PLAYER + 1)
	assert_int(engine.state().players[SIDE_BOSS].mana_max).is_equal(0)


func test_first_start_step_events_follow_c4_order() -> void:
	# Arrange: one on_turn_start hook (player) and one turn_start trigger script
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	resolver.hook_scripts["t_dawn.0"] = _hook_marker
	resolver.scripts[&"turn_start"] = [_trigger_marker]
	var hook: HookInstaller = MatchFactory.make_hook_installer("t_dawn", SIDE_PLAYER, [&"on_turn_start"])

	# Act
	var engine: RulesEngine = _engine_at_turn_one(log, {"player": {"hook_installers": [hook]}}, {}, resolver)

	# Assert: match_started precedes turn_started; Start step in C4 order
	assert_array(_types_from(log, "mulligan_resolved")).is_equal([
		"mulligan_resolved", "match_started", "turn_started", "crystal_gained",
		"mana_refilled", "turn_reset", String(HOOK_MARKER), String(TRIGGER_MARKER),
		"card_drawn", "phase_changed",
	])
	var started: Dictionary = log.first(&"turn_started")
	assert_int(int(started.turn)).is_equal(1)
	assert_dict(started.payload).is_equal({"turn": 1, "side": SIDE_PLAYER})
	assert_dict(log.first(&"crystal_gained").payload).is_equal({"side": SIDE_PLAYER, "mana_max": 1, "gained": 1})
	assert_dict(log.first(&"mana_refilled").payload).is_equal({"side": SIDE_PLAYER, "mana_available": 1, "mana_max": 1})
	assert_dict(log.last().payload).is_equal({"phase": MatchState.PHASE_MAIN, "side": SIDE_PLAYER})
	var match_started: Dictionary = log.first(&"match_started")
	assert_int(int(match_started.payload.floor)).is_equal(1)
	assert_int(int(match_started.payload.player_deck_size)).is_equal(engine.state().players[SIDE_PLAYER].deck.size() + 1)
	# the setup events were stamped turn 0, the Start step's turn 1
	assert_int(int(log.first(&"mulligan_resolved").turn)).is_equal(0)
	assert_int(int(log.last().turn)).is_equal(1)


func test_turn_reset_clears_only_the_starting_sides_characters() -> void:
	# Arrange: one minion per side, both exhausted, the player's hero power used
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine_at_turn_one(log)
	var state: MatchState = engine.state()
	var mine: Dictionary = MatchFactory.summon(state, SIDE_PLAYER, 2, 2)
	var theirs: Dictionary = MatchFactory.summon(state, SIDE_BOSS, 2, 2)
	for minion: Dictionary in [mine, theirs]:
		minion.attacks_used = 1
	state.players[SIDE_PLAYER].hero.attacks_used = 1
	state.players[SIDE_PLAYER].hero_power.used_this_turn = true

	# Act: the boss's Start step, then the player's
	assert_bool(_end_turn(engine).accepted).is_true()
	var boss_reset: Dictionary = log.of_type(&"turn_reset")[1]
	var player_flags_mid: Array = [mine.attacks_used, mine.summoning_sick, state.players[SIDE_PLAYER].hero_power.used_this_turn]
	assert_bool(_end_turn(engine).accepted).is_true()
	var player_reset: Dictionary = log.of_type(&"turn_reset")[2]

	# Assert
	assert_array(boss_reset.payload.entity_ids).is_equal([int(state.players[SIDE_BOSS].hero.entity_id), int(theirs.entity_id)])
	assert_int(theirs.attacks_used).is_equal(0)
	assert_bool(theirs.summoning_sick).is_false()
	assert_array(player_flags_mid).is_equal([1, true, true])
	assert_array(player_reset.payload.entity_ids).is_equal([int(state.players[SIDE_PLAYER].hero.entity_id), int(mine.entity_id)])
	assert_int(mine.attacks_used).is_equal(0)
	assert_bool(mine.summoning_sick).is_false()
	assert_int(state.players[SIDE_PLAYER].hero.attacks_used).is_equal(0)
	assert_bool(state.players[SIDE_PLAYER].hero_power.used_this_turn).is_false()


# --- AC-06: F4 over twelve turns each, and a permanent crystal -------------------

func test_twelve_turns_each_follow_f4_and_cap_at_max_mana() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine_at_turn_one(log)

	# Act: turn 1 is done; 2 × 12 − 1 end_turns start the boss's 12th turn
	_end_turns(engine, 2 * TURNS_EACH - 1)

	# Assert: mana_max = min(turns_taken, MAX_MANA) at every Start step
	assert_int(engine.state().players[SIDE_BOSS].turns_taken).is_equal(TURNS_EACH)
	for side: String in [SIDE_PLAYER, SIDE_BOSS]:
		var expected: Array[int] = []
		for t: int in range(1, TURNS_EACH + 1):
			expected.append(mini(t, TestConstants.MAX_MANA_CRYSTALS))
		assert_array(_refills(log, side)).is_equal(expected)
		assert_int(_count_side(log, &"crystal_gained", side)).is_equal(TestConstants.MAX_MANA_CRYSTALS)
		assert_int(_count_side(log, &"mana_refilled", side)).is_equal(TURNS_EACH)
		assert_int(engine.state().players[side].mana_max).is_equal(TestConstants.MAX_MANA_CRYSTALS)
	assert_int(engine.state().turn).is_equal(2 * TURNS_EACH)


func test_global_turn_seven_is_the_players_fourth_turn() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine_at_turn_one(log)

	# Act: up to global turn 8
	_end_turns(engine, F4_EXAMPLE_GLOBAL_TURN)

	# Assert (F4 example): player 4 crystals at global turn 7, boss 4 at turn 8
	var at_seven: Array[Dictionary] = []
	for event: Dictionary in log.of_type(&"mana_refilled"):
		if int(event.turn) == F4_EXAMPLE_GLOBAL_TURN or int(event.turn) == F4_EXAMPLE_GLOBAL_TURN + 1:
			at_seven.append(event.payload)
	assert_array(at_seven).is_equal([
		{"side": SIDE_PLAYER, "mana_available": F4_EXAMPLE_CRYSTALS, "mana_max": F4_EXAMPLE_CRYSTALS},
		{"side": SIDE_BOSS, "mana_available": F4_EXAMPLE_CRYSTALS, "mana_max": F4_EXAMPLE_CRYSTALS},
	])


func test_permanent_crystal_from_on_match_start_raises_the_player_curve_only() -> void:
	# Arrange: Hollow Crown — an on_match_start hook calling add_mana(PLAYER, 1, false)
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	resolver.hook_scripts["t_crown.0"] = _crown
	var crown: HookInstaller = MatchFactory.make_hook_installer("t_crown", SIDE_PLAYER, [&"on_match_start"])
	var engine: RulesEngine = MatchFactory.make_started_engine(null, log, {"player": {"hook_installers": [crown]}}, {}, resolver)

	# Assert (setup): mana_added before the first card_drawn
	var types: Array[String] = log.types()
	assert_int(types.find("mana_added")).is_less(types.find("card_drawn"))
	assert_dict(log.first(&"mana_added").payload).is_equal({"side": SIDE_PLAYER, "n": 1, "temporary": false})
	assert_int(engine.state().players[SIDE_PLAYER].crystal_bonus).is_equal(1)
	assert_int(engine.state().players[SIDE_PLAYER].mana_max).is_equal(0)

	# Act
	assert_bool(_keep_all(engine).accepted).is_true()
	_end_turns(engine, 2 * TURNS_EACH - 1)

	# Assert: 2/2 on turn 1, 10/10 from the player's 9th turn; boss unchanged
	var player_curve: Array[int] = []
	var boss_curve: Array[int] = []
	for t: int in range(1, TURNS_EACH + 1):
		player_curve.append(mini(t + 1, TestConstants.MAX_MANA_CRYSTALS))
		boss_curve.append(mini(t, TestConstants.MAX_MANA_CRYSTALS))
	assert_array(_refills(log, SIDE_PLAYER)).is_equal(player_curve)
	assert_array(_refills(log, SIDE_BOSS)).is_equal(boss_curve)
	assert_int(player_curve.find(TestConstants.MAX_MANA_CRYSTALS)).is_equal(9 - 1)
	assert_int(_count_side(log, &"crystal_gained", SIDE_PLAYER)).is_equal(TestConstants.MAX_MANA_CRYSTALS - 1)
	assert_int(log.count(&"mana_added")).is_equal(1)


# --- AC-09: Main guard and the End step -----------------------------------------

func test_player_main_rejects_boss_play_card_and_a_second_mulligan() -> void:
	# Arrange
	var engine: RulesEngine = _engine_at_turn_one()

	# Act / Assert
	var boss_play: Dictionary = engine.submit(MatchRecords.command(MatchRecords.CMD_PLAY_CARD, SIDE_BOSS, {"hand_index": 0}))
	assert_bool(boss_play.accepted).is_false()
	assert_str(str(boss_play.rejection.code)).is_equal("NOT_YOUR_TURN")
	var mulligan: Dictionary = engine.submit(MatchRecords.mulligan([true, true, true, true]))
	assert_bool(mulligan.accepted).is_false()
	assert_str(str(mulligan.rejection.code)).is_equal("WRONG_PHASE")
	var boss_end: Dictionary = engine.submit(MatchRecords.end_turn(SIDE_BOSS))
	assert_str(str(boss_end.rejection.code)).is_equal("NOT_YOUR_TURN")


func test_end_turn_runs_the_end_step_in_c4_order_then_the_boss_start() -> void:
	# Arrange: a board on both sides, a player weapon, end_of_turn enchantments
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	resolver.scripts[&"turn_end"] = [_trigger_marker]
	resolver.hook_scripts["t_dusk.0"] = _hook_marker
	var dusk: HookInstaller = MatchFactory.make_hook_installer("t_dusk", SIDE_PLAYER, [&"on_turn_end"])
	var engine: RulesEngine = _engine_at_turn_one(log, {"player": {"hook_installers": [dusk]}}, {}, resolver)
	var state: MatchState = engine.state()
	var left: Dictionary = MatchFactory.summon(state, SIDE_PLAYER, 1, 1)
	var right: Dictionary = MatchFactory.summon(state, SIDE_PLAYER, 2, 2)
	var boss_minion: Dictionary = MatchFactory.summon(state, SIDE_BOSS, 3, 3)
	var axe: Dictionary = MatchFactory.make_weapon(MatchFactory.alloc_entity_id(state), 2, 2, "war_axe")
	state.players[SIDE_PLAYER].weapon = axe
	var expiring: Dictionary = MatchFactory.make_enchantment(1, 0, [], null, false, MatchRecords.EXPIRES_END_OF_TURN)
	var lasting: Dictionary = MatchFactory.make_enchantment(0, 1)
	right.enchantments.append(expiring)
	right.enchantments.append(lasting)
	boss_minion.enchantments.append(MatchFactory.make_enchantment(1, 0, [], null, false, MatchRecords.EXPIRES_END_OF_TURN))
	var hand_card: Dictionary = state.players[SIDE_PLAYER].hand[0]
	hand_card.cost_modifiers.append(MatchFactory.make_enchantment(0, 0, [], null, false, MatchRecords.EXPIRES_END_OF_TURN))
	var before: int = log.events.size()
	var auras_before: int = resolver.aura_recomputes

	# Act
	var result: Dictionary = engine.submit(MatchRecords.end_turn(SIDE_PLAYER))

	# Assert: End step order, then the boss's Start step
	assert_bool(result.accepted).is_true()
	var types: Array[String] = log.types().slice(before)
	assert_array(types.slice(0, 7)).is_equal([
		"turn_ending", String(TRIGGER_MARKER), String(HOOK_MARKER),
		"enchantment_removed", "enchantment_removed", "turn_ended", "turn_started",
	])
	var removed: Array[Dictionary] = log.of_type(&"enchantment_removed")
	assert_int(int(removed[0].payload.instance_id)).is_equal(int(right.entity_id))
	assert_int(int(removed[1].payload.instance_id)).is_equal(int(hand_card.instance_id))
	assert_array(right.enchantments).is_equal([lasting])
	assert_int(hand_card.cost_modifiers.size()).is_equal(0)
	assert_int(boss_minion.enchantments.size()).is_equal(1)
	assert_int(resolver.aura_recomputes).is_equal(auras_before + 1)
	assert_dict(log.first(&"turn_ending").payload).is_equal({"turn": 1, "side": SIDE_PLAYER})
	assert_dict(log.first(&"turn_ended").payload).is_equal({"turn": 1, "side": SIDE_PLAYER})
	assert_str(String(engine.active_side())).is_equal(SIDE_BOSS)
	assert_str(engine.phase()).is_equal(MatchState.PHASE_MAIN)
	assert_int(engine.state().turn).is_equal(2)
	# candidate order: player board L→R, player weapon, player hero, then boss
	var expected: Array = [
		int(left.entity_id), int(right.entity_id), int(axe.entity_id),
		int(state.players[SIDE_PLAYER].hero.entity_id),
		int(boss_minion.entity_id), int(state.players[SIDE_BOSS].hero.entity_id),
	]
	assert_array(resolver.candidates_for(&"turn_end")).is_equal([expected])
	# … and the same order at the boss's own Start step (player side first)
	var starts: Array = resolver.candidates_for(&"turn_start")
	assert_array(starts[starts.size() - 1]).is_equal(expected)
	assert_str(str(resolver.resolve_calls[resolver.resolve_calls.size() - 1].ctx.side)).is_equal(SIDE_BOSS)
	# the boss's minion enchantment expires at the boss's own End step
	assert_bool(_end_turn(engine).accepted).is_true()
	assert_int(boss_minion.enchantments.size()).is_equal(0)


func test_end_turn_result_spans_end_step_and_next_start_step() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine_at_turn_one(log)
	var first: int = int(log.last().seq) + 1

	# Act
	var result: Dictionary = _end_turn(engine)

	# Assert
	assert_array(result.events).is_equal([first, int(log.last().seq)])
	assert_str(log.events[first - 1].type).is_equal("turn_ending")
	assert_str(log.last().type).is_equal("phase_changed")


# --- AC-10: TURN_CAP -------------------------------------------------------------

func test_turn_cap_ends_the_match_for_the_boss_before_the_next_start_step() -> void:
	# Arrange: TURN_CAP = 4 through the injected rules config
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine_at_turn_one(log, {}, {"turn_cap": SMALL_TURN_CAP})

	# Act: four Start steps happen (turns 1–4); the 5th would begin
	for i: int in SMALL_TURN_CAP:
		assert_bool(_end_turn(engine).accepted).is_true()

	# Assert
	assert_str(engine.phase()).is_equal(MatchState.PHASE_ENDED)
	var outcome: Dictionary = engine.result()
	assert_str(str(outcome.winner)).is_equal(SIDE_BOSS)
	assert_str(str(outcome.reason)).is_equal("turn_cap")
	assert_str(str(outcome.result)).is_equal("loss")
	assert_int(int(outcome.turns)).is_equal(SMALL_TURN_CAP)
	assert_int(log.count(&"turn_started")).is_equal(SMALL_TURN_CAP)
	assert_str(log.last().type).is_equal("match_ended")
	assert_dict(log.last().payload).is_equal(outcome)
	assert_str(log.types()[log.events.size() - 2]).is_equal("turn_ended")
	# and the match takes no further command
	var late: Dictionary = engine.submit(MatchRecords.end_turn(SIDE_PLAYER))
	assert_str(str(late.rejection.code)).is_equal("MATCH_ENDED")


# --- add_mana, legal_commands -------------------------------------------------

func test_add_mana_permanent_raises_crystal_bonus_and_is_read_at_the_next_start() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine_at_turn_one(log)

	# Act
	engine.add_mana(SIDE_BOSS, 1, false)

	# Assert: no immediate mana; the boss's first Start reads 2/2
	assert_int(engine.state().players[SIDE_BOSS].crystal_bonus).is_equal(1)
	assert_int(engine.state().players[SIDE_BOSS].mana_max).is_equal(0)
	assert_dict(log.last().payload).is_equal({"side": SIDE_BOSS, "n": 1, "temporary": false})
	assert_bool(_end_turn(engine).accepted).is_true()
	assert_int(engine.state().players[SIDE_BOSS].mana_max).is_equal(2)
	assert_int(engine.state().players[SIDE_BOSS].mana_current).is_equal(2)


func test_legal_commands_in_main_is_end_turn_for_the_active_side() -> void:
	# Arrange
	var engine: RulesEngine = _engine_at_turn_one()

	# Act / Assert
	assert_array(engine.legal_commands()).is_equal([MatchRecords.end_turn(SIDE_PLAYER)])
	assert_bool(_end_turn(engine).accepted).is_true()
	assert_array(engine.legal_commands()).is_equal([MatchRecords.end_turn(SIDE_BOSS)])
