## EventLog core — envelope, append, subscribe, events_since, turn, sealing.
##
## Story: production/epics/rng-event-log/story-005-event-log-core-append-subscribe-seal.md
## GDD: design/gdd/rng-event-log.md rules 11-15, F7, Edge Cases (Events).
## ADR-0003 Decision 5, 7, 8 (sealing). Every log here is built directly with
## `EventLog.new(max_events, scope)` (determinism contract, ADR-0003 Decision
## 10a); no wall clock, no file I/O.
##
## Caller bugs (an append to a sealed log, a re-entrant append) assert in debug
## builds and warn in release. The test runner is a debug build, so
## `_assert_reported` expects the assert there and the `push_warning` in a
## release build; what the log stores and returns is checked in both.
extends GdUnitTestSuite

## The cap every log in this suite is built with (F7 default, mirrored by
## TestConstants from the registry). Overflow is Story 007's suite.
const CAP: int = TestConstants.MAX_MATCH_EVENTS


func _match_log() -> EventLog:
	return EventLog.new(CAP, EventLog.SCOPE_MATCH)


## Runs `call` and asserts it reported `message`: an assert in a debug build,
## a push_warning in release.
func _assert_reported(call: Callable, message: String) -> void:
	if OS.is_debug_build():
		await assert_error(call).is_runtime_error("Assertion failed: " + message)
	else:
		await assert_error(call).is_push_warning(message)


# --- AC-1: seq, events_since, subscribers, envelope, deep copy --------------------

func test_five_appends_stamp_seq_one_to_five_and_events_since_three_returns_four_and_five() -> void:
	# Arrange
	var log: EventLog = _match_log()
	var returned: Array[int] = []

	# Act
	for i: int in range(5):
		returned.append(log.append(&"card_drawn", {"side": MatchFactory.SIDE_PLAYER, "instance_id": i + 10}))
	var later: Array[Dictionary] = log.events_since(3)

	# Assert
	assert_array(returned).is_equal([1, 2, 3, 4, 5])
	assert_int(log.size()).is_equal(5)
	assert_int(later.size()).is_equal(2)
	assert_int(later[0].seq).is_equal(4)
	assert_int(later[1].seq).is_equal(5)
	EventLogAssertions.assert_seq_contiguous(log.events_since(0))


func test_each_subscriber_receives_each_event_once_in_registration_and_seq_order() -> void:
	# Arrange — lambdas capture by value: accumulate through a shared Array
	var log: EventLog = _match_log()
	var received: Array = []
	log.subscribe(func(event: Dictionary) -> void: received.append("a%d" % int(event.seq)))
	log.subscribe(func(event: Dictionary) -> void: received.append("b%d" % int(event.seq)))

	# Act
	for i: int in range(5):
		log.append(&"card_drawn", {"instance_id": i})

	# Assert — after each append, a then b, once each, seq ascending
	assert_array(received).is_equal(["a1", "b1", "a2", "b2", "a3", "b3", "a4", "b4", "a5", "b5"])


func test_subscriber_is_called_after_the_event_is_stored() -> void:
	# Arrange
	var log: EventLog = _match_log()
	var seen: Dictionary = {"size": -1}
	log.subscribe(func(_event: Dictionary) -> void: seen.size = log.size())

	# Act
	log.append(&"turn_started", {"turn": 1})

	# Assert
	assert_int(seen.size).is_equal(1)


func test_every_event_has_the_five_field_envelope_with_a_string_type() -> void:
	# Arrange
	var log: EventLog = _match_log()

	# Act
	log.append(&"turn_started", {"turn": 1, "side": MatchFactory.SIDE_PLAYER})
	log.append(&"card_drawn", {"side": MatchFactory.SIDE_PLAYER, "card_id": "card_a"}, 1)
	var events: Array[Dictionary] = log.events_since(-1)

	# Assert
	EventLogAssertions.assert_envelopes_valid(events)
	for event: Dictionary in events:
		assert_array(event.keys()).contains_exactly_in_any_order(EventLogAssertions.ENVELOPE_KEYS)
		assert_int(typeof(event.type)).is_equal(TYPE_STRING)
	assert_bool(events[1].type == "card_drawn").is_true()


func test_mutating_the_callers_payload_after_append_leaves_the_stored_event_unchanged() -> void:
	# Arrange
	var log: EventLog = _match_log()
	var payload: Dictionary = {"side": MatchFactory.SIDE_PLAYER, "instance_ids": [3, 4], "detail": {"code": "a"}}

	# Act
	log.append(&"mulligan_offered", payload)
	payload.side = MatchFactory.SIDE_BOSS
	(payload.instance_ids as Array).append(5)
	(payload.detail as Dictionary).code = "b"
	var stored: Dictionary = log.events_since(0)[0].payload

	# Assert
	assert_str(stored.side).is_equal(MatchFactory.SIDE_PLAYER)
	assert_array(stored.instance_ids).is_equal([3, 4])
	assert_str(stored.detail.code).is_equal("a")


func test_stored_events_are_read_only_to_readers_and_subscribers() -> void:
	# Arrange
	var log: EventLog = _match_log()
	var delivered: Array = []
	log.subscribe(func(event: Dictionary) -> void: delivered.append(event))

	# Act
	log.append(&"card_drawn", {"ids": [1], "detail": {"a": 1}})
	var event: Dictionary = log.events_since(0)[0]

	# Assert — the envelope, the payload and its nested containers
	assert_bool(event.is_read_only()).is_true()
	assert_bool((event.payload as Dictionary).is_read_only()).is_true()
	assert_bool((event.payload.ids as Array).is_read_only()).is_true()
	assert_bool((event.payload.detail as Dictionary).is_read_only()).is_true()
	assert_bool((delivered[0] as Dictionary).is_read_only()).is_true()


# --- AC-2: cause_seq, events_since bounds --------------------------------------

func test_event_appended_while_event_forty_resolves_has_cause_forty_and_a_later_seq() -> void:
	# Arrange — 40 events, the 40th is the one resolving
	var log: EventLog = _match_log()
	for i: int in range(40):
		log.append(&"healed", {"amount": i})

	# Act
	var seq: int = log.append(&"trigger_resolved", {"instance_id": 7}, 40)
	var event: Dictionary = log.events_since(seq - 1)[0]

	# Assert
	assert_int(seq).is_greater(40)
	assert_int(event.cause_seq).is_equal(40)
	EventLogAssertions.assert_cause_seq_valid(log.events_since(0))


func test_events_since_at_or_past_the_last_seq_is_empty_and_negative_returns_every_event() -> void:
	# Arrange
	var log: EventLog = _match_log()
	for i: int in range(3):
		log.append(&"card_drawn", {"instance_id": i})

	# Act / Assert
	assert_array(log.events_since(3)).is_empty()
	assert_array(log.events_since(99)).is_empty()
	assert_int(log.events_since(-1).size()).is_equal(3)
	assert_int(log.events_since(-50).size()).is_equal(3)
	assert_int(log.events_since(0).size()).is_equal(3)


func test_events_since_on_an_empty_log_is_empty() -> void:
	assert_array(_match_log().events_since(-1)).is_empty()


# --- AC-3: turn stamp, sealing, snapshot ----------------------------------------

func test_turn_is_zero_before_set_turn_and_the_last_set_value_after() -> void:
	# Arrange
	var log: EventLog = _match_log()

	# Act
	log.append(&"mulligan_offered", {})
	log.set_turn(1)
	log.append(&"turn_started", {"turn": 1})
	log.set_turn(2)
	log.set_turn(3)
	log.append(&"turn_started", {"turn": 3})
	var events: Array[Dictionary] = log.events_since(0)

	# Assert
	assert_int(events[0].turn).is_equal(0)
	assert_int(events[1].turn).is_equal(1)
	assert_int(events[2].turn).is_equal(3)
	assert_int(log.current_turn()).is_equal(3)


func test_match_ended_seals_a_match_log() -> void:
	# Arrange
	var log: EventLog = _match_log()
	log.append(&"damage_dealt", {"dealt": 1})

	# Act
	assert_bool(log.is_sealed()).is_false()
	log.append(&"match_ended", {"result": "win"})

	# Assert
	assert_bool(log.is_sealed()).is_true()


func test_run_ended_seals_a_run_log() -> void:
	# Arrange
	var log: EventLog = EventLog.new(CAP, EventLog.SCOPE_RUN)
	log.append(&"run_started", {"hero_id": "hero_a"})

	# Act
	log.append(&"run_ended", {"result": {"outcome": "victory"}})

	# Assert
	assert_bool(log.is_sealed()).is_true()


func test_the_other_scopes_ending_event_does_not_seal() -> void:
	# Arrange
	var match_log: EventLog = _match_log()
	var run_log: EventLog = EventLog.new(CAP, EventLog.SCOPE_RUN)

	# Act — rule 15: match_ended seals a match log, run_ended a run log
	match_log.append(&"run_ended", {})
	run_log.append(&"match_ended", {})

	# Assert
	assert_bool(match_log.is_sealed()).is_false()
	assert_bool(run_log.is_sealed()).is_false()


func test_append_to_a_sealed_log_returns_minus_one_stores_nothing_and_notifies_no_one() -> void:
	# Arrange
	var log: EventLog = _match_log()
	var received: Array = []
	log.append(&"match_ended", {"result": "loss"})
	log.subscribe(func(event: Dictionary) -> void: received.append(event.seq))
	var out: Dictionary = {"seq": 0}

	# Act / Assert — reported (assert in debug, warning in release)
	await _assert_reported(func() -> void: out.seq = log.append(&"card_drawn", {}),
		"EventLog.append: the log is sealed; 'card_drawn' dropped")

	# Assert
	assert_int(out.seq).is_equal(-1)
	assert_int(log.size()).is_equal(1)
	assert_array(received).is_empty()
	EventLogAssertions.assert_last_type(log.events_since(0), &"match_ended")


func test_size_and_snapshot_report_the_sealed_contents() -> void:
	# Arrange
	var meta: Dictionary = {"engine_version": "4.7.2", "data_version": "abc123", "run_seed_hex": "000000000000002A", "floor": 2}
	var log: EventLog = EventLog.new(CAP, EventLog.SCOPE_MATCH, meta)
	log.append(&"match_started", {"floor": 2})
	log.set_turn(1)
	log.append(&"turn_started", {"turn": 1})
	log.append(&"match_ended", {"result": "win"})

	# Act
	var snap: Dictionary = log.snapshot()

	# Assert — metadata block plus the full event array
	assert_int(log.size()).is_equal(3)
	assert_str(snap.engine_version).is_equal("4.7.2")
	assert_str(snap.data_version).is_equal("abc123")
	assert_str(snap.run_seed_hex).is_equal("000000000000002A")
	assert_str(snap.scope).is_equal(EventLog.SCOPE_MATCH)
	assert_int(snap.floor).is_equal(2)
	assert_int((snap.events as Array).size()).is_equal(3)
	EventLogAssertions.assert_replay_equal(snap.events, log.events_since(-1))
	EventLogAssertions.assert_last_type(snap.events, &"match_ended")


func test_snapshot_is_a_copy_the_caller_may_edit() -> void:
	# Arrange
	var log: EventLog = _match_log()
	log.append(&"card_drawn", {"instance_id": 1})

	# Act
	var snap: Dictionary = log.snapshot()
	(snap.events as Array).clear()

	# Assert
	assert_int(log.size()).is_equal(1)


# --- AC-4: re-entrancy -----------------------------------------------------------

func test_reentrant_append_is_reported_takes_the_next_seq_and_is_tagged() -> void:
	# Arrange — a display-layer bug: a subscriber that appends
	var log: EventLog = _match_log()
	var state: Dictionary = {"nested_seq": 0}
	log.subscribe(func(event: Dictionary) -> void:
		if event.type == "card_drawn":
			state.nested_seq = log.append(&"healed", {"amount": 1}))

	# Act / Assert — asserted in debug (warning in release)
	await _assert_reported(func() -> void: log.append(&"card_drawn", {"instance_id": 1}),
		"EventLog.append: re-entrant append of 'healed' from a subscriber")

	# Assert — accepted, next seq, tagged
	var events: Array[Dictionary] = log.events_since(0)
	assert_int(state.nested_seq).is_equal(2)
	assert_int(events.size()).is_equal(2)
	assert_str(events[1].type).is_equal("healed")
	assert_bool(events[1].payload.get("_reentrant", false)).is_true()
	assert_bool(events[0].payload.has("_reentrant")).is_false()


func test_reentrant_event_reaches_every_subscriber_after_the_outer_event() -> void:
	# Arrange — the first subscriber appends; the second must still see seq 1 first
	var log: EventLog = _match_log()
	var received: Array = []
	log.subscribe(func(event: Dictionary) -> void:
		received.append("a%d" % int(event.seq))
		if event.type == "card_drawn":
			log.append(&"healed", {}))
	log.subscribe(func(event: Dictionary) -> void: received.append("b%d" % int(event.seq)))

	# Act
	await _assert_reported(func() -> void: log.append(&"card_drawn", {}),
		"EventLog.append: re-entrant append of 'healed' from a subscriber")

	# Assert — once each, in seq order, for every subscriber
	assert_array(received).is_equal(["a1", "b1", "a2", "b2"])


func test_append_after_notification_finished_is_not_reentrant() -> void:
	# Arrange
	var log: EventLog = _match_log()
	log.subscribe(func(_event: Dictionary) -> void: pass)

	# Act
	log.append(&"card_drawn", {})
	log.append(&"card_drawn", {})

	# Assert
	for event: Dictionary in log.events_since(0):
		assert_bool(event.payload.has("_reentrant")).is_false()
