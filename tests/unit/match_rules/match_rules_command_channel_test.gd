## Unit tests for the command channel — `submit`, the phase guard, the closed
## rejection set, `Resolving` / `ENGINE_BUSY`, and the `mulligan` command
## (story match-rules/story-004; design/gdd/match-rules.md C2, C3 step 7,
## States and Transitions, C15 diagnostics; ADR-0001, ADR-0003 rule 12a).
##
## Engines start through `MatchFactory.make_started_engine` (phase Mulligan).
## Phases a command cannot reach yet in this story (Main, Choice, Ended) are
## fixture states installed with `load_state` over a `TestEventLog`.
extends GdUnitTestSuite

const SIDE_PLAYER: String = MatchFactory.SIDE_PLAYER
const SIDE_BOSS: String = MatchFactory.SIDE_BOSS


# --- helpers -----------------------------------------------------------------

func _instance_ids(cards: Array) -> Array[int]:
	var ids: Array[int] = []
	for card: Dictionary in cards:
		ids.append(int(card.instance_id))
	return ids


func _mask(values: Array) -> Array[bool]:
	var mask: Array[bool] = []
	mask.assign(values)
	return mask


## An engine over a fixture state in [param phase] with a fresh log.
func _engine_in_phase(phase: String, active_side: String = SIDE_PLAYER, pending_choice: Variant = null) -> RulesEngine:
	var state: MatchState = MatchFactory.make_match_state({"phase": phase, "active_side": active_side, "pending_choice": pending_choice})
	state.log = TestEventLog.new()
	var engine: RulesEngine = RulesEngine.new(null, MatchFactory.make_rules_config(), TestEffectResolver.new())
	engine.load_state(state)
	return engine


func _assert_rejected(result: Dictionary, code: String) -> void:
	assert_bool(result.accepted).is_false()
	assert_str(str(result.rejection.code)).is_equal(code)


# --- AC-03: mulligan -----------------------------------------------------------

func test_mulligan_returns_unkept_cards_before_the_redraw() -> void:
	# Arrange
	var rng: TestRngService = TestRngService.new()
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = MatchFactory.make_started_engine(rng, log)
	var player: Dictionary = engine.state().players[SIDE_PLAYER]
	var before_hand: Array[int] = _instance_ids(player.hand)
	var deck_size: int = player.deck.size()
	var all_ids: Array[int] = _instance_ids(player.hand + player.deck)
	all_ids.sort()
	var stream: TestRngStream = rng.stream("match_1")
	var shuffles_before: int = stream.calls.size()

	# Act
	var result: Dictionary = engine.submit(MatchRecords.mulligan(_mask([true, false, false])))

	# Assert
	assert_bool(result.accepted).is_true()
	assert_int(player.deck.size()).is_equal(deck_size)
	assert_int(player.hand.size()).is_equal(TestConstants.STARTING_HAND_PLAYER)
	assert_int(int(player.hand[0].instance_id)).is_equal(before_hand[0])
	# the returned cards went back into the deck before the one shuffle, so
	# they are in the deck or redrawn (DD-M05 — never asserted "not redrawn")
	assert_int(stream.calls.size()).is_equal(shuffles_before + 1)
	assert_int(int(stream.calls[shuffles_before].args[0])).is_equal(deck_size + 2)
	var now_ids: Array[int] = _instance_ids(player.hand + player.deck)
	now_ids.sort()
	assert_array(now_ids).is_equal(all_ids)
	for card: Dictionary in player.deck:
		assert_str(card.zone).is_equal("deck")
	for card: Dictionary in player.hand:
		assert_str(card.zone).is_equal("hand")
	var resolved: Dictionary = log.first(&"mulligan_resolved")
	assert_str(resolved.payload.side).is_equal(SIDE_PLAYER)
	assert_array(resolved.payload.replaced_instance_ids).is_equal([before_hand[1], before_hand[2]])


func test_mulligan_event_order_is_shuffle_redraws_then_resolved() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = MatchFactory.make_started_engine(null, log)
	var first_new: int = log.events.size()

	# Act
	@warning_ignore("return_value_discarded")
	engine.submit(MatchRecords.mulligan(_mask([true, false, false])))

	# Assert
	var types: Array[String] = log.types().slice(first_new, first_new + 4)
	assert_array(types).is_equal(["deck_shuffled", "card_drawn", "card_drawn", "mulligan_resolved"])
	assert_str(log.events[first_new].payload.side).is_equal(SIDE_PLAYER)


func test_mulligan_keep_all_is_legal_and_keeps_the_hand() -> void:
	# Arrange
	var engine: RulesEngine = MatchFactory.make_started_engine()
	var player: Dictionary = engine.state().players[SIDE_PLAYER]
	var before_hand: Array[int] = _instance_ids(player.hand)

	# Act
	var result: Dictionary = engine.submit(MatchRecords.mulligan(_mask([true, true, true])))

	# Assert
	assert_bool(result.accepted).is_true()
	assert_array(_instance_ids(player.hand).slice(0, before_hand.size())).is_equal(before_hand)


func test_second_mulligan_is_wrong_phase() -> void:
	# Arrange: MULLIGAN_ROUNDS = 1
	var engine: RulesEngine = MatchFactory.make_started_engine()
	@warning_ignore("return_value_discarded")
	engine.submit(MatchRecords.mulligan(_mask([true, true, true])))

	# Act
	var result: Dictionary = engine.submit(MatchRecords.mulligan(_mask([true, true, true])))

	# Assert
	_assert_rejected(result, "WRONG_PHASE")


# --- AC-04: INVALID_MASK as a diagnostic on the same log ------------------------

func test_short_mask_is_invalid_mask_and_only_command_rejected_is_appended() -> void:
	# Arrange
	var rng: TestRngService = TestRngService.new()
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = MatchFactory.make_started_engine(rng, log)
	var before: int = log.events.size()
	var last_seq: int = int(log.last().seq)
	var hand_before: Array[int] = _instance_ids(engine.state().players[SIDE_PLAYER].hand)
	var draws_before: int = rng.stream("match_1").draws
	var command: Dictionary = MatchRecords.mulligan(_mask([true, false]))

	# Act
	var result: Dictionary = engine.submit(command)

	# Assert: rejected, exactly one diagnostic event at the next seq, no mutation
	_assert_rejected(result, "INVALID_MASK")
	assert_int(log.events.size()).is_equal(before + 1)
	var rejected: Dictionary = log.last()
	assert_str(rejected.type).is_equal("command_rejected")
	assert_int(int(rejected.seq)).is_equal(last_seq + 1)
	assert_bool(rejected.payload.diagnostic).is_true()
	assert_str(str(rejected.payload.code)).is_equal("INVALID_MASK")
	assert_dict(rejected.payload.command).is_equal(command)
	assert_str(str(rejected.payload.side)).is_equal(SIDE_PLAYER)
	assert_array(result.events).is_equal([int(rejected.seq), int(rejected.seq)])
	assert_str(engine.phase()).is_equal(MatchState.PHASE_MULLIGAN)
	assert_array(_instance_ids(engine.state().players[SIDE_PLAYER].hand)).is_equal(hand_before)
	assert_int(rng.stream("match_1").draws).is_equal(draws_before)


func test_mask_with_non_bool_entries_is_invalid_mask() -> void:
	# Arrange
	var engine: RulesEngine = MatchFactory.make_started_engine()

	# Act
	var not_bools: Dictionary = engine.submit(MatchRecords.command(MatchRecords.CMD_MULLIGAN, SIDE_PLAYER, {"keep_mask": [1, 0, 1]}))
	var missing: Dictionary = engine.submit(MatchRecords.command(MatchRecords.CMD_MULLIGAN, SIDE_PLAYER))

	# Assert
	_assert_rejected(not_bools, "INVALID_MASK")
	_assert_rejected(missing, "INVALID_MASK")
	assert_str(engine.phase()).is_equal(MatchState.PHASE_MULLIGAN)


# --- AC-37: re-entrant submit -------------------------------------------------

## Subscriber: while armed, answers every non-diagnostic event — including
## the outer command's last one — with a nested mulligan submitted from inside
## the callback, and records each result and the hand size it left.
func _reenter_on_every_event(event: Dictionary, probe: Dictionary) -> void:
	if not probe.armed or event.type == "command_rejected":
		return
	var engine: RulesEngine = probe.engine
	probe.nested.append(engine.submit(MatchRecords.mulligan(_mask([true, true, true]))))
	probe.hand_sizes.append(engine.state().players[SIDE_PLAYER].hand.size())


func test_nested_submit_from_a_subscriber_is_engine_busy_and_outer_result_is_intact() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = MatchFactory.make_started_engine(null, log)
	var probe: Dictionary = {"armed": false, "engine": engine, "nested": [], "hand_sizes": []}
	log.subscribe(_reenter_on_every_event.bind(probe))
	var first_seq: int = int(log.last().seq) + 1
	probe.armed = true

	# Act
	var outer: Dictionary = engine.submit(MatchRecords.mulligan(_mask([true, false, false])))
	probe.armed = false

	# Assert: each nested call is ENGINE_BUSY, logged as a diagnostic …
	var own: Array[Dictionary] = []
	for event: Dictionary in log.events_since(first_seq - 1):
		if event.type != "command_rejected":
			own.append(event)
	assert_int(probe.nested.size()).is_equal(own.size())
	for nested: Dictionary in probe.nested:
		_assert_rejected(nested, "ENGINE_BUSY")
	var rejections: Array[Dictionary] = log.of_type(&"command_rejected")
	assert_int(rejections.size()).is_equal(own.size())
	for rejected: Dictionary in rejections:
		assert_bool(rejected.payload.diagnostic).is_true()
		assert_str(str(rejected.payload.code)).is_equal("ENGINE_BUSY")
	# … with no state change: the nested keep-all never ran (one resolution,
	# and the hand only ever shrank by the outer's two returns)
	assert_int(log.count(&"mulligan_resolved")).is_equal(1)
	assert_int(probe.hand_sizes[0]).is_equal(TestConstants.STARTING_HAND_PLAYER - 2)
	# … and the outer result is unaffected: accepted, its own event range,
	# whose last seq is its own last event, not the diagnostic after it
	assert_bool(outer.accepted).is_true()
	assert_that(outer.rejection).is_null()
	assert_array(outer.events).is_equal([int(own[0].seq), int(own[own.size() - 1].seq)])
	assert_int(int(own[0].seq)).is_equal(first_seq)
	assert_str(log.last().type).is_equal("command_rejected")


# --- C2 / States: phase guard, closed set, result shape ------------------------

func test_commands_outside_the_mulligan_set_are_wrong_phase() -> void:
	# Arrange
	var engine: RulesEngine = MatchFactory.make_started_engine()
	var commands: Array[Dictionary] = [
		MatchRecords.command(MatchRecords.CMD_PLAY_CARD, SIDE_PLAYER, {"hand_index": 0}),
		MatchRecords.command(MatchRecords.CMD_ATTACK, SIDE_PLAYER, {"attacker_id": 1, "target_id": 2}),
		MatchRecords.command(MatchRecords.CMD_USE_HERO_POWER, SIDE_PLAYER),
		MatchRecords.command(MatchRecords.CMD_CHOOSE, SIDE_PLAYER, {"option_index": 0}),
		MatchRecords.end_turn(SIDE_PLAYER),
		MatchRecords.mulligan(_mask([true, true, true]), SIDE_BOSS),
		MatchRecords.command("not_a_command", SIDE_PLAYER),
	]

	# Act / Assert
	for command: Dictionary in commands:
		_assert_rejected(engine.submit(command), "WRONG_PHASE")
	assert_str(engine.phase()).is_equal(MatchState.PHASE_MULLIGAN)


func test_main_phase_commands_from_the_inactive_side_are_not_your_turn() -> void:
	# Arrange: player Main
	var engine: RulesEngine = _engine_in_phase(MatchState.PHASE_MAIN, SIDE_PLAYER)

	# Act / Assert: right phase, wrong issuer
	_assert_rejected(engine.submit(MatchRecords.command(MatchRecords.CMD_PLAY_CARD, SIDE_BOSS, {"hand_index": 0})), "NOT_YOUR_TURN")
	_assert_rejected(engine.submit(MatchRecords.end_turn(SIDE_BOSS)), "NOT_YOUR_TURN")
	# and a command with no Main row is WRONG_PHASE
	_assert_rejected(engine.submit(MatchRecords.mulligan(_mask([true]))), "WRONG_PHASE")


func test_choice_phase_accepts_only_choose_from_the_named_side() -> void:
	# Arrange: the boss owes a choice
	var engine: RulesEngine = _engine_in_phase(MatchState.PHASE_CHOICE, SIDE_PLAYER, {"side": SIDE_BOSS, "options": [0, 1]})

	# Act / Assert
	_assert_rejected(engine.submit(MatchRecords.end_turn(SIDE_PLAYER)), "CHOICE_PENDING")
	_assert_rejected(engine.submit(MatchRecords.command(MatchRecords.CMD_PLAY_CARD, SIDE_PLAYER, {"hand_index": 0})), "CHOICE_PENDING")
	_assert_rejected(engine.submit(MatchRecords.command(MatchRecords.CMD_CHOOSE, SIDE_PLAYER, {"option_index": 0})), "NOT_YOUR_TURN")


func test_every_command_after_ended_is_match_ended() -> void:
	# Arrange
	var engine: RulesEngine = _engine_in_phase(MatchState.PHASE_ENDED)

	# Act / Assert
	_assert_rejected(engine.submit(MatchRecords.end_turn(SIDE_PLAYER)), "MATCH_ENDED")
	_assert_rejected(engine.submit(MatchRecords.mulligan(_mask([true]))), "MATCH_ENDED")


func test_rejection_code_set_is_the_closed_c2_set() -> void:
	# Assert: spelled and ordered exactly as C2 / MatchFactory (21 codes)
	assert_array(RulesEngine.REJECTION_CODES).is_equal(MatchFactory.REJECTION_CODES)
	assert_int(RulesEngine.REJECTION_CODES.size()).is_equal(21)


func test_command_result_has_the_c2_shape() -> void:
	# Arrange
	var engine: RulesEngine = MatchFactory.make_started_engine()

	# Act
	var rejected: Dictionary = engine.submit(MatchRecords.mulligan(_mask([true])))
	var accepted: Dictionary = engine.submit(MatchRecords.mulligan(_mask([true, true, true])))

	# Assert
	for result: Dictionary in [rejected, accepted]:
		assert_array(result.keys()).contains_exactly_in_any_order(["accepted", "rejection", "events"])
		assert_int(result.events.size()).is_equal(2)
		assert_bool(int(result.events[0]) <= int(result.events[1])).is_true()
	assert_array((rejected.rejection as Dictionary).keys()).contains_exactly_in_any_order(["code", "detail"])
	assert_that(accepted.rejection).is_null()


func test_rejection_cause_seq_is_zero_and_payload_is_json_representable() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = MatchFactory.make_started_engine(null, log)

	# Act
	@warning_ignore("return_value_discarded")
	engine.submit(MatchRecords.command(MatchRecords.CMD_PLAY_CARD, SIDE_PLAYER, {"hand_index": 0}))

	# Assert
	assert_int(int(log.last().cause_seq)).is_equal(0)
	GameAssertions.assert_json_representable(log.last())
	EventLogAssertions.assert_seq_contiguous(log)


# --- legal_commands and value getters -------------------------------------------

func test_legal_commands_in_mulligan_is_keep_all_and_it_is_accepted() -> void:
	# Arrange
	var engine: RulesEngine = MatchFactory.make_started_engine()

	# Act
	var legal: Array = engine.legal_commands()

	# Assert
	assert_int(legal.size()).is_equal(1)
	assert_dict(legal[0]).is_equal(MatchRecords.mulligan(_mask([true, true, true])))
	assert_bool(engine.submit(legal[0]).accepted).is_true()


func test_legal_commands_after_ended_is_empty() -> void:
	# Arrange
	var engine: RulesEngine = _engine_in_phase(MatchState.PHASE_ENDED)

	# Act / Assert
	assert_array(engine.legal_commands()).is_empty()


func test_value_getters_return_copies() -> void:
	# Arrange
	var engine: RulesEngine = _engine_in_phase(MatchState.PHASE_CHOICE, SIDE_PLAYER, {"side": SIDE_BOSS, "options": [0, 1]})
	engine.state().result = MatchFactory.make_match_result()

	# Act
	var choice: Dictionary = engine.pending_choice()
	choice.side = SIDE_PLAYER
	var result: Dictionary = engine.result()
	result.reason = "edited"

	# Assert
	assert_str(engine.phase()).is_equal(MatchState.PHASE_CHOICE)
	assert_str(String(engine.active_side())).is_equal(SIDE_PLAYER)
	assert_str(str(engine.state().pending_choice.side)).is_equal(SIDE_BOSS)
	assert_str(str(engine.state().result.reason)).is_equal("hero_dead")
