## Unit tests for `RulesEngine.start(config)` — match setup (story
## match-rules/story-003; design/gdd/match-rules.md C3 steps 1–6, States
## `Setup` → `Mulligan`, Interactions `on_match_start` /
## `modify_starting_hand_size`; ADR-0007 Decision 2, ADR-0005 Decision 5/11,
## ADR-0003).
##
## Engines are built through `MatchFactory.make_started_engine` /
## `make_started_config` with the scripted `TestEffectResolver`, a
## `TestRngService` (seed 42 by default — AC-01's seed) and a `TestEventLog`.
## Hook effects are card-effects C5 `modify_value` ops, applied by the double.
extends GdUnitTestSuite

const SIDE_PLAYER: String = MatchFactory.SIDE_PLAYER
const SIDE_BOSS: String = MatchFactory.SIDE_BOSS
## A hook-produced marker event (stands in for "[on_match_start hook events]").
const MARKER: StringName = &"test_hook_marker"
## AC-43's floor-bonus boss health (Run Structure F3 with a bonus).
const BOSS_HEALTH_WITH_BONUS: int = 42
## AC-44's setup half: a hook that asks for more than HAND_SIZE cards.
const OVERSIZED_HAND: int = 14


# --- helpers -----------------------------------------------------------------

func _instance_ids(cards: Array) -> Array[int]:
	var ids: Array[int] = []
	for card: Dictionary in cards:
		ids.append(int(card.instance_id))
	return ids


func _def_ids(cards: Array) -> Array[String]:
	var ids: Array[String] = []
	for card: Dictionary in cards:
		ids.append(str(card.def_id))
	return ids


## One installer on [param side] whose single effect is a value hook on
## [param point] with one `modify_value` op.
func _value_installer(host_id: String, side: String, point: StringName, op: Dictionary) -> HookInstaller:
	var effect: Dictionary = {
		"id": "%s.0" % host_id, "trigger": str(point), "scope": {}, "condition": {},
		"ops": [op], "once_per_turn": false,
	}
	return HookInstaller.new(HookInstaller.HOST_KIND_TREASURE, host_id, StringName(side), [effect])


## Hook script: emits [constant MARKER] for the side it ran on.
func _emit_marker(engine: RulesEngine, _entry: Dictionary, side: StringName, _ctx: Dictionary) -> void:
	@warning_ignore("return_value_discarded")
	engine.emit(MARKER, {"side": String(side)})


func _events_of(log: TestEventLog, type: StringName, side: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for event: Dictionary in log.of_type(type):
		if event.payload.get("side", "") == side:
			found.append(event)
	return found


# --- AC-01: determinism, one injected stream ---------------------------------

func test_start_twice_with_seed_42_gives_identical_decks_and_hands() -> void:
	# Arrange: two services created with run_seed = 42, fresh match_1 streams
	var rng_a: TestRngService = TestRngService.new(TestConstants.DEFAULT_TEST_SEED)
	var rng_b: TestRngService = TestRngService.new(TestConstants.DEFAULT_TEST_SEED)

	# Act
	var a: RulesEngine = MatchFactory.make_started_engine(rng_a, TestEventLog.new())
	var b: RulesEngine = MatchFactory.make_started_engine(rng_b, TestEventLog.new())

	# Assert: instance orders and hands identical across the two runs
	for side: String in [SIDE_PLAYER, SIDE_BOSS]:
		var pa: Dictionary = a.state().players[side]
		var pb: Dictionary = b.state().players[side]
		assert_array(_instance_ids(pa.deck)).is_equal(_instance_ids(pb.deck))
		assert_array(_def_ids(pa.deck)).is_equal(_def_ids(pb.deck))
		assert_array(_instance_ids(pa.hand)).is_equal(_instance_ids(pb.hand))
		assert_array(_def_ids(pa.hand)).is_equal(_def_ids(pb.hand))
	var log_a: TestEventLog = a.state().log
	var log_b: TestEventLog = b.state().log
	EventLogAssertions.assert_replay_equal(log_a, log_b)
	# and no RNG call outside rng_match (rng_ai untouched, no other stream drawn)
	assert_int(rng_a.draws_outside(["match_1"])).is_equal(0)
	assert_int(rng_b.draws_outside(["match_1"])).is_equal(0)


func test_start_uses_the_injected_stream_once_per_deck() -> void:
	# Arrange
	var rng: TestRngService = TestRngService.new()

	# Act
	var engine: RulesEngine = MatchFactory.make_started_engine(rng)

	# Assert: rng_match() is the injected memoised stream, never a new one;
	# exactly one Fisher-Yates shuffle per side (n − 1 draws each, F4)
	var stream: TestRngStream = rng.stream("match_1")
	assert_object(engine.rng_match()).is_same(stream)
	assert_int(stream.count_calls("shuffle")).is_equal(2)
	assert_int(stream.draws).is_equal((TestConstants.STARTER_DECK_SIZE - 1) + (MatchFactory.STARTED_BOSS_DECK_SIZE - 1))
	assert_int(rng.stream("ai_1").draws).is_equal(0)


func test_start_shuffles_the_player_deck_before_the_boss_deck() -> void:
	# Arrange: a scripted stream records each shuffle's size in call order
	var rng: TestRngService = TestRngService.new()
	var stream: TestRngStream = rng.install(TestRngStream.scripted("match_1", [7, 3, 11]))

	# Act
	@warning_ignore("return_value_discarded")
	MatchFactory.make_started_engine(rng)

	# Assert
	assert_int(stream.calls.size()).is_equal(2)
	assert_int(int(stream.calls[0].args[0])).is_equal(TestConstants.STARTER_DECK_SIZE)
	assert_int(int(stream.calls[1].args[0])).is_equal(MatchFactory.STARTED_BOSS_DECK_SIZE)


# --- AC-02: state and log at mulligan_offered --------------------------------

func test_setup_complete_state_is_mulligan_with_c3_values() -> void:
	# Arrange / Act
	var config_boss_health: int = MatchFactory.boss_health_for_band(1)
	var engine: RulesEngine = MatchFactory.make_started_engine()
	var state: MatchState = engine.state()
	var player: Dictionary = state.players[SIDE_PLAYER]
	var boss: Dictionary = state.players[SIDE_BOSS]

	# Assert
	assert_str(state.phase).is_equal(MatchState.PHASE_MULLIGAN)
	assert_int(state.turn).is_equal(0)
	assert_int(player.hand.size()).is_equal(TestConstants.STARTING_HAND_PLAYER)
	assert_int(boss.hand.size()).is_equal(TestConstants.STARTING_HAND_BOSS)
	assert_int(player.deck.size()).is_equal(TestConstants.STARTER_DECK_SIZE - TestConstants.STARTING_HAND_PLAYER)
	assert_int(boss.deck.size()).is_equal(MatchFactory.STARTED_BOSS_DECK_SIZE - TestConstants.STARTING_HAND_BOSS)
	for side_state: Dictionary in [player, boss]:
		assert_int(side_state.mana_current).is_equal(0)
		assert_int(side_state.mana_max).is_equal(0)
		assert_int(side_state.fatigue_counter).is_equal(0)
		assert_int(side_state.hero.armor).is_equal(0)
		for card: Dictionary in side_state.hand:
			assert_str(card.zone).is_equal("hand")
		for card: Dictionary in side_state.deck:
			assert_str(card.zone).is_equal("deck")
	assert_int(engine.health(player.hero)).is_equal(TestConstants.PLAYER_STARTING_HEALTH)
	assert_int(engine.max_health(boss.hero)).is_equal(config_boss_health)
	assert_str(player.hero.controller).is_equal(SIDE_PLAYER)
	assert_str(boss.hero.controller).is_equal(SIDE_BOSS)


func test_setup_log_order_is_shuffles_hooks_draws_then_mulligan_offered() -> void:
	# Arrange: one on_match_start hook per side, each emitting a marker
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var log: TestEventLog = TestEventLog.new()
	var player_hook: HookInstaller = MatchFactory.make_hook_installer("t_marker", SIDE_PLAYER, [&"on_match_start"])
	var boss_hook: HookInstaller = MatchFactory.make_hook_installer("boss_marker", SIDE_BOSS, [&"on_match_start"])
	resolver.hook_scripts["t_marker.0"] = _emit_marker
	resolver.hook_scripts["boss_marker.0"] = _emit_marker
	var overrides: Dictionary = {"player": {"hook_installers": [player_hook]}, "boss": {"hook_installers": [boss_hook]}}

	# Act
	var engine: RulesEngine = MatchFactory.make_started_engine(null, log, overrides, {}, resolver)

	# Assert: exact C3 order
	var expected: Array[String] = ["deck_shuffled", "deck_shuffled", String(MARKER), String(MARKER)]
	for i: int in TestConstants.STARTING_HAND_PLAYER + TestConstants.STARTING_HAND_BOSS:
		expected.append("card_drawn")
	expected.append("mulligan_offered")
	assert_array(log.types()).is_equal(expected)
	assert_str(log.events[0].payload.side).is_equal(SIDE_PLAYER)
	assert_str(log.events[1].payload.side).is_equal(SIDE_BOSS)
	assert_str(log.events[2].payload.side).is_equal(SIDE_PLAYER)
	assert_str(log.events[3].payload.side).is_equal(SIDE_BOSS)
	var draws: Array[Dictionary] = log.of_type(&"card_drawn")
	for i: int in draws.size():
		var expected_side: String = SIDE_PLAYER if i < TestConstants.STARTING_HAND_PLAYER else SIDE_BOSS
		assert_str(draws[i].payload.side).is_equal(expected_side)
	# mulligan_offered lists the player's hand
	var offered: Dictionary = log.last()
	assert_str(offered.payload.side).is_equal(SIDE_PLAYER)
	assert_array(offered.payload.instance_ids).is_equal(_instance_ids(engine.state().players[SIDE_PLAYER].hand))
	# setup events carry cause_seq 0 and turn 0
	for event: Dictionary in log.events:
		assert_int(int(event.cause_seq)).is_equal(0)
		assert_int(int(event.turn)).is_equal(0)
	EventLogAssertions.assert_envelopes_valid(log)
	GameAssertions.assert_json_representable(log.events)


func test_deck_shuffled_lists_the_instance_order_the_hand_is_drawn_from() -> void:
	# Arrange / Act
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = MatchFactory.make_started_engine(null, log)

	# Assert: the shuffled order, top first; the hand is its first cards and
	# the deck the rest; card_drawn carries instance_id, card_id, side
	for side: String in [SIDE_PLAYER, SIDE_BOSS]:
		var side_state: Dictionary = engine.state().players[side]
		var shuffled: Array = _events_of(log, &"deck_shuffled", side)[0].payload.instance_ids
		var hand_ids: Array[int] = _instance_ids(side_state.hand)
		var dealt: Array = []
		dealt.append_array(hand_ids)
		dealt.append_array(_instance_ids(side_state.deck))
		assert_array(shuffled).is_equal(dealt)
		var drawn: Array[Dictionary] = _events_of(log, &"card_drawn", side)
		for i: int in drawn.size():
			assert_int(int(drawn[i].payload.instance_id)).is_equal(hand_ids[i])
			assert_str(str(drawn[i].payload.card_id)).is_equal(str(side_state.hand[i].def_id))
			assert_int(int(drawn[i].payload.hand_size)).is_equal(i + 1)


func test_entity_ids_are_unique_and_heroes_come_first() -> void:
	# Arrange / Act
	var engine: RulesEngine = MatchFactory.make_started_engine()
	var state: MatchState = engine.state()

	# Assert: C1 — unique ids from next_entity_id; heroes before cards
	var ids: Array[int] = [int(state.players[SIDE_PLAYER].hero.entity_id), int(state.players[SIDE_BOSS].hero.entity_id)]
	assert_int(ids[0]).is_equal(MatchState.FIRST_ENTITY_ID)
	for side: String in [SIDE_PLAYER, SIDE_BOSS]:
		ids.append_array(_instance_ids(state.players[side].hand))
		ids.append_array(_instance_ids(state.players[side].deck))
	GameAssertions.assert_no_duplicates(ids)
	assert_int(state.next_entity_id).is_equal(ids.max() + 1)


func test_player_health_comes_from_rules_config() -> void:
	# Arrange: the knob, not a literal (C3 step 2 default STARTING_HEALTH_PLAYER)
	var raised: int = TestConstants.PLAYER_STARTING_HEALTH + 5

	# Act
	var engine: RulesEngine = MatchFactory.make_started_engine(null, null, {}, {"starting_health_player": raised})

	# Assert
	assert_int(engine.max_health(engine.state().players[SIDE_PLAYER].hero)).is_equal(raised)


# --- C3 step 1: bind before anything else -------------------------------------

func test_start_binds_the_resolver_with_player_then_boss_installers() -> void:
	# Arrange
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var t_a: HookInstaller = MatchFactory.make_hook_installer("t_a", SIDE_PLAYER, [&"on_turn_start"])
	var t_b: HookInstaller = MatchFactory.make_hook_installer("t_b", SIDE_PLAYER, [&"on_turn_end"])
	var passive: HookInstaller = MatchFactory.make_hook_installer("boss_p", SIDE_BOSS, [&"on_turn_start"])
	var overrides: Dictionary = {"player": {"hook_installers": [t_a, t_b]}, "boss": {"hook_installers": [passive]}}

	# Act
	var engine: RulesEngine = MatchFactory.make_started_engine(null, null, overrides, {}, resolver)

	# Assert
	assert_int(resolver.bind_calls.size()).is_equal(1)
	assert_array(resolver.bind_calls[0].installers).is_equal([t_a, t_b, passive])
	assert_object(resolver.engine).is_same(engine)
	assert_object(engine.state().hooks).is_not_null()
	var hosts: Array[String] = []
	for host: Dictionary in engine.state().hooks.hosts():
		hosts.append(str(host.host_id))
	assert_array(hosts).is_equal(["t_a", "t_b", "boss_p"])


func test_start_passes_bind_a_typed_hook_installer_array() -> void:
	# Arrange — TestEffectResolver.bind is typed as ADR-0007's
	# `installers: Array[HookInstaller]`; the config lists are plain Arrays
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var t_a: HookInstaller = MatchFactory.make_hook_installer("t_a", SIDE_PLAYER, [&"on_turn_start"])
	var passive: HookInstaller = MatchFactory.make_hook_installer("boss_p", SIDE_BOSS, [&"on_turn_start"])
	var overrides: Dictionary = {"player": {"hook_installers": [t_a]}, "boss": {"hook_installers": [passive]}}

	# Act
	MatchFactory.make_started_engine(null, null, overrides, {}, resolver)

	# Assert — the typed call path ran: one bind, with a typed array
	assert_int(resolver.bind_calls.size()).is_equal(1)
	var passed: Array = resolver.bind_calls[0].installers
	assert_bool(passed.is_typed()).is_true()
	assert_object(passed.get_typed_script()).is_same(HookInstaller)
	assert_array(passed).is_equal([t_a, passive])


# --- AC-43 -------------------------------------------------------------------

func test_boss_health_is_match_config_health() -> void:
	# Arrange
	var overrides: Dictionary = {"boss": {"health": BOSS_HEALTH_WITH_BONUS}}

	# Act
	var engine: RulesEngine = MatchFactory.make_started_engine(null, null, overrides)

	# Assert
	var boss_hero: Dictionary = engine.state().players[SIDE_BOSS].hero
	assert_int(engine.max_health(boss_hero)).is_equal(BOSS_HEALTH_WITH_BONUS)
	assert_int(engine.health(boss_hero)).is_equal(BOSS_HEALTH_WITH_BONUS)


func test_starting_hand_hook_over_hand_size_clamps_to_hand_size_without_burn() -> void:
	# Arrange: a player treasure `set 14` on modify_starting_hand_size
	var log: TestEventLog = TestEventLog.new()
	var hook: HookInstaller = _value_installer("t_big_hand", SIDE_PLAYER, &"modify_starting_hand_size", {"op": "modify_value", "set": OVERSIZED_HAND})

	# Act
	var engine: RulesEngine = MatchFactory.make_started_engine(null, log, {"player": {"hook_installers": [hook]}})

	# Assert: clamped once to HAND_SIZE; the boss (out of scope) unchanged
	assert_int(engine.state().players[SIDE_PLAYER].hand.size()).is_equal(TestConstants.HAND_SIZE)
	assert_int(engine.state().players[SIDE_BOSS].hand.size()).is_equal(TestConstants.STARTING_HAND_BOSS)
	EventLogAssertions.assert_not_contains_type(log, &"card_burned")
	assert_int(_events_of(log, &"card_drawn", SIDE_PLAYER).size()).is_equal(TestConstants.HAND_SIZE)
	assert_int(engine.state().players[SIDE_PLAYER].deck.size()).is_equal(TestConstants.STARTER_DECK_SIZE - TestConstants.HAND_SIZE)


func test_draw_into_a_full_hand_burns_the_top_card() -> void:
	# Arrange: the clamp above is only observable because a draw past
	# HAND_SIZE burns (C11, DD-M06) — pin that branch of the stub draw
	var log: TestEventLog = TestEventLog.new()
	var hook: HookInstaller = _value_installer("t_big_hand", SIDE_PLAYER, &"modify_starting_hand_size", {"op": "modify_value", "set": TestConstants.HAND_SIZE})
	var engine: RulesEngine = MatchFactory.make_started_engine(null, log, {"player": {"hook_installers": [hook]}})
	var player: Dictionary = engine.state().players[SIDE_PLAYER]
	var top: Dictionary = player.deck[0]

	# Act
	engine.draw(SIDE_PLAYER, 1)

	# Assert
	assert_int(player.hand.size()).is_equal(TestConstants.HAND_SIZE)
	assert_str(str(player.graveyard[0].def_id)).is_equal(str(top.def_id))
	assert_str(player.graveyard[0].zone).is_equal("graveyard")
	assert_dict(log.last().payload).is_equal({"side": SIDE_PLAYER, "instance_id": top.instance_id, "card_id": top.def_id})
	assert_str(log.last().type).is_equal("card_burned")


func test_starting_hand_hook_below_zero_clamps_to_zero() -> void:
	# Arrange: a boss passive `delta −(4 + 2)` — the fold goes negative
	var hook: HookInstaller = _value_installer("boss_no_hand", SIDE_BOSS, &"modify_starting_hand_size", {"op": "modify_value", "delta": -(TestConstants.STARTING_HAND_BOSS + 2)})

	# Act
	var engine: RulesEngine = MatchFactory.make_started_engine(null, null, {"boss": {"hook_installers": [hook]}})

	# Assert
	assert_int(engine.state().players[SIDE_BOSS].hand.size()).is_equal(0)
	assert_int(engine.state().players[SIDE_PLAYER].hand.size()).is_equal(TestConstants.STARTING_HAND_PLAYER)


func test_starting_hand_fold_is_clamped_once_after_the_whole_chain() -> void:
	# Arrange: set 14 then delta −6 → 8 (a per-step clamp would give 10 − 6 = 4)
	var over: HookInstaller = _value_installer("t_over", SIDE_PLAYER, &"modify_starting_hand_size", {"op": "modify_value", "set": OVERSIZED_HAND})
	var back: HookInstaller = _value_installer("t_back", SIDE_PLAYER, &"modify_starting_hand_size", {"op": "modify_value", "delta": -6})

	# Act
	var engine: RulesEngine = MatchFactory.make_started_engine(null, null, {"player": {"hook_installers": [over, back]}})

	# Assert
	assert_int(engine.state().players[SIDE_PLAYER].hand.size()).is_equal(OVERSIZED_HAND - 6)


func test_duplicate_host_id_logs_hook_install_skipped_and_installs_the_first_only() -> void:
	# Arrange: two installers with the same host_id, different effects
	var log: TestEventLog = TestEventLog.new()
	var first: HookInstaller = MatchFactory.make_hook_installer("treasure_twin", SIDE_PLAYER, [&"on_turn_start"])
	var second: HookInstaller = MatchFactory.make_hook_installer("treasure_twin", SIDE_PLAYER, [&"on_turn_end"])

	# Act
	var engine: RulesEngine = MatchFactory.make_started_engine(null, log, {"player": {"hook_installers": [first, second]}})

	# Assert: the engine appends the skip, before any setup event
	EventLogAssertions.assert_count(log, &"hook_install_skipped", 1)
	assert_str(log.events[0].type).is_equal("hook_install_skipped")
	assert_dict(log.events[0].payload).is_equal({"host_id": "treasure_twin", "reason": "duplicate"})
	var hooks: HookRegistry = engine.state().hooks
	assert_int(hooks.hosts().size()).is_equal(1)
	assert_int(hooks.entries(&"on_turn_start").size()).is_equal(1)
	assert_int(hooks.entries(&"on_turn_end").size()).is_equal(0)


func test_interleaved_duplicates_log_one_skip_each_in_installer_order() -> void:
	# Arrange: a, b, a, b — the third and fourth are refused by the registry
	var log: TestEventLog = TestEventLog.new()
	var a1: HookInstaller = MatchFactory.make_hook_installer("t_a", SIDE_PLAYER, [&"on_turn_start"])
	var b1: HookInstaller = MatchFactory.make_hook_installer("t_b", SIDE_PLAYER, [&"on_turn_start"])
	var a2: HookInstaller = MatchFactory.make_hook_installer("t_a", SIDE_PLAYER, [&"on_turn_end"])
	var b2: HookInstaller = MatchFactory.make_hook_installer("t_b", SIDE_BOSS, [&"on_turn_end"])
	var overrides: Dictionary = {"player": {"hook_installers": [a1, b1, a2]}, "boss": {"hook_installers": [b2]}}

	# Act
	var engine: RulesEngine = MatchFactory.make_started_engine(null, log, overrides)

	# Assert
	var skipped: Array = log.of_type(&"hook_install_skipped").map(func(e: Dictionary) -> String: return e.payload.host_id)
	assert_array(skipped).is_equal(["t_a", "t_b"])
	assert_int(engine.state().hooks.hosts().size()).is_equal(2)
	assert_int(engine.state().hooks.entries(&"on_turn_end").size()).is_equal(0)
