## EventLog serialisation — to_json / from_json, payload coercion, diagnostics.
##
## Story: production/epics/rng-event-log/story-006-event-log-serialization-and-diagnostics.md
## GDD: design/gdd/rng-event-log.md rules 12a, 14, 17; F6; Edge Cases (Events).
## ADR-0003 Decision 4-6, 9. Logs are built directly with literal values; the
## JSON text is produced and read in memory (no file I/O, no wall clock).
##
## A non-JSON payload value is a caller bug: it asserts in debug builds and is
## coerced in release. The test runner is a debug build, so `_assert_reported`
## expects the assert there and the `push_warning` in release; the coerced
## value is checked in both (the log coerces after reporting in every build).
extends GdUnitTestSuite

## The cap every log in this suite is built with (F7 default via TestConstants).
const CAP: int = TestConstants.MAX_MATCH_EVENTS
## The seven header keys (rule 17).
const HEADER_KEYS: Array[String] = [
	"log_schema_version", "engine_version", "data_version", "run_seed_hex", "scope", "floor", "events",
]
## 2^53 + 1: the first integer `JSON` numbers cannot carry exactly (probe E).
const ABOVE_TWO_POW_53: int = 9007199254740993
## A non-integral payload value (F6 prints it with 6 decimals).
const RATIO: float = 0.25


func _meta(run_seed: int = TestConstants.DEFAULT_TEST_SEED) -> Dictionary:
	return {
		"engine_version": "4.7.2.stable",
		"data_version": "0123456789abcdef",
		"run_seed_hex": TestRngStream.to_hex_u64(run_seed),
		"floor": 3,
	}


## A sealed match log built by a fixed script of appends (match-rules shapes).
func _scripted_match_log(dealt: int = 5) -> EventLog:
	var log: EventLog = EventLog.new(CAP, EventLog.SCOPE_MATCH, _meta())
	log.append(&"match_started", {"floor": 3, "hero_id": "hero_a", "boss_id": "boss_a", "player_deck_size": 20, "boss_deck_size": 20})
	log.set_turn(1)
	var turn_seq: int = log.append(&"turn_started", {"turn": 1, "side": MatchFactory.SIDE_PLAYER, "mana_max": 1, "mana_available": 1})
	log.append(&"card_drawn", {"side": MatchFactory.SIDE_PLAYER, "instance_id": 12, "card_id": &"card_a", "hand_size": 4}, turn_seq)
	var died: int = log.append(&"minion_died", {"instance_id": 7, "card_id": "card_b", "side": MatchFactory.SIDE_BOSS, "board_index": 0})
	log.append(&"damage_dealt", {"source": 7, "target": 2, "requested": 6, "prevented": 1, "armor_absorbed": 0, "dealt": dealt, "health_after": 25}, died)
	log.append(&"enchantment_applied", {"instance_id": 12, "keywords_added": ["taunt"], "keywords_removed": [], "reason": null, "ratio": RATIO})
	log.append(&"match_ended", {"result": "win", "winner": "PLAYER", "reason": "hero_dead", "turns": 1})
	return log


## The parsed header of `text`, read the way a bug-report reader would.
func _parsed(text: String) -> Dictionary:
	var json: JSON = JSON.new()
	assert_int(json.parse(text)).is_equal(OK)
	return json.data


## Runs `call` and asserts it reported `message`: an assert in a debug build,
## a push_warning in release.
func _assert_reported(call: Callable, message: String) -> void:
	if OS.is_debug_build():
		await assert_error(call).is_runtime_error("Assertion failed: " + message)
	else:
		await assert_error(call).is_push_warning(message)


# --- AC-1: round trip, header, types ------------------------------------------

func test_to_json_then_from_json_is_replay_equal() -> void:
	# Arrange
	var log: EventLog = _scripted_match_log()

	# Act
	var copy: EventLog = EventLog.from_json(log.to_json())

	# Assert
	assert_object(copy).is_not_null()
	assert_int(copy.size()).is_equal(log.size())
	EventLogAssertions.assert_replay_equal(log.events_since(0), copy.events_since(0))
	EventLogAssertions.assert_envelopes_valid(copy.events_since(0))


func test_json_header_carries_the_seven_fields_from_meta() -> void:
	# Arrange
	var log: EventLog = _scripted_match_log()

	# Act
	var header: Dictionary = _parsed(log.to_json())

	# Assert
	assert_array(header.keys()).contains_exactly_in_any_order(HEADER_KEYS)
	assert_int(int(header.log_schema_version)).is_equal(EventLog.LOG_SCHEMA_VERSION)
	assert_str(header.engine_version).is_equal("4.7.2.stable")
	assert_str(header.data_version).is_equal("0123456789abcdef")
	assert_str(header.run_seed_hex).is_equal("000000000000002A")
	assert_str(header.scope).is_equal(EventLog.SCOPE_MATCH)
	assert_int(int(header.floor)).is_equal(3)
	assert_int((header.events as Array).size()).is_equal(log.size())


func test_to_json_is_tab_indented() -> void:
	# Act
	var text: String = _scripted_match_log().to_json()

	# Assert — JSON.stringify(dict, "\t") output
	assert_bool(text.contains("\n\t\"events\": [")).is_true()
	assert_bool(text.contains("\n\t\"scope\": \"match\"")).is_true()


func test_run_seed_above_two_pow_53_survives_as_run_seed_hex_bit_exactly() -> void:
	# Arrange
	var log: EventLog = EventLog.new(CAP, EventLog.SCOPE_MATCH, _meta(ABOVE_TWO_POW_53))
	log.append(&"match_started", {"floor": 3})

	# Act
	var copy: EventLog = EventLog.from_json(log.to_json())
	var hex: String = copy.snapshot().run_seed_hex

	# Assert
	assert_str(hex).is_equal("0020000000000001")
	assert_int(TestRngStream.parse_hex_u64(hex)).is_equal(ABOVE_TWO_POW_53)


func test_string_name_values_and_keys_are_stored_and_round_tripped_as_string() -> void:
	# Arrange
	var log: EventLog = EventLog.new(CAP, EventLog.SCOPE_MATCH, _meta())

	# Act
	log.append(&"card_drawn", {&"card_id": &"card_a", "ids": [&"x"]})
	var stored: Dictionary = log.events_since(0)[0].payload
	var copy: Dictionary = EventLog.from_json(log.to_json()).events_since(0)[0].payload

	# Assert — rule 14: StringName serialises as String, in memory too
	for payload: Dictionary in [stored, copy]:
		assert_int(typeof(payload.keys()[0])).is_equal(TYPE_STRING)
		assert_int(typeof(payload["card_id"])).is_equal(TYPE_STRING)
		assert_int(typeof(payload["ids"][0])).is_equal(TYPE_STRING)
	assert_array(stored.get("_coerced", [])).is_empty()


func test_seq_turn_cause_seq_and_integral_payload_numbers_come_back_as_int() -> void:
	# Arrange
	var log: EventLog = _scripted_match_log()

	# Act
	var events: Array[Dictionary] = EventLog.from_json(log.to_json()).events_since(0)
	var damage: Dictionary = events[4]

	# Assert
	for event: Dictionary in events:
		assert_int(typeof(event.seq)).is_equal(TYPE_INT)
		assert_int(typeof(event.turn)).is_equal(TYPE_INT)
		assert_int(typeof(event.cause_seq)).is_equal(TYPE_INT)
	assert_str(damage.type).is_equal("damage_dealt")
	assert_int(typeof(damage.payload.dealt)).is_equal(TYPE_INT)
	assert_int(damage.payload.dealt).is_equal(5)
	assert_int(damage.cause_seq).is_equal(4)
	assert_int(damage.turn).is_equal(1)


func test_float_payload_value_stays_float_and_prints_with_six_decimals() -> void:
	# Arrange
	var log: EventLog = _scripted_match_log()

	# Act
	var event: Dictionary = EventLog.from_json(log.to_json()).events_since(0)[5]

	# Assert
	assert_int(typeof(event.payload.ratio)).is_equal(TYPE_FLOAT)
	assert_bool(EventLogAssertions.canonical_json(event.payload).contains("\"ratio\":0.250000")).is_true()


func test_from_json_restores_scope_turn_and_sealed_state() -> void:
	# Arrange
	var sealed: EventLog = _scripted_match_log()
	var open_run: EventLog = EventLog.new(CAP, EventLog.SCOPE_RUN, _meta())
	open_run.append(&"run_started", {"hero_id": "hero_a"})

	# Act
	var sealed_copy: EventLog = EventLog.from_json(sealed.to_json())
	var open_copy: EventLog = EventLog.from_json(open_run.to_json(), CAP)

	# Assert
	assert_bool(sealed_copy.is_sealed()).is_true()
	assert_str(sealed_copy.scope()).is_equal(EventLog.SCOPE_MATCH)
	assert_int(sealed_copy.current_turn()).is_equal(1)
	assert_bool(open_copy.is_sealed()).is_false()
	assert_str(open_copy.scope()).is_equal(EventLog.SCOPE_RUN)
	assert_int(open_copy.max_events()).is_equal(CAP)
	assert_int(open_copy.append(&"run_floor_entered", {"floor": 1})).is_equal(2)


func test_from_json_rejects_malformed_text_with_the_error_line() -> void:
	# Arrange — a missing value on the 3rd line
	var text: String = "{\n\t\"scope\": \"match\",\n\t\"floor\": ,\n}"
	var probe: JSON = JSON.new()
	probe.parse(text)
	var expected: String = "EventLog.from_json: line %d: %s" % [probe.get_error_line() + 1, probe.get_error_message()]
	var out: Dictionary = {"log": "not called"}

	# Act / Assert
	await assert_error(func() -> void: out.log = EventLog.from_json(text)).is_push_error(expected)
	assert_object(out.log).is_null()
	assert_bool(expected.begins_with("EventLog.from_json: line 3: ")).is_true()


func test_from_json_rejects_a_non_log_document() -> void:
	# Arrange
	var out: Dictionary = {}

	# Act / Assert — a top-level array, an unknown schema, a broken envelope
	await assert_error(func() -> void: out.a = EventLog.from_json("[1, 2]")) \
		.is_push_error("EventLog.from_json: the top level is not an object")
	await assert_error(func() -> void: out.b = EventLog.from_json("{\"log_schema_version\": 2, \"scope\": \"match\", \"events\": []}")) \
		.is_push_error("EventLog.from_json: log_schema_version 2 is not %d" % EventLog.LOG_SCHEMA_VERSION)
	await assert_error(func() -> void: out.c = EventLog.from_json("{\"log_schema_version\": 1, \"scope\": \"match\", \"events\": [{\"seq\": 2}]}")) \
		.is_push_error("EventLog.from_json: event at index 0 is not a rule 11 envelope with seq 1")
	assert_object(out.a).is_null()
	assert_object(out.b).is_null()
	assert_object(out.c).is_null()


# --- AC-2: payload coercion ------------------------------------------------------

func test_vector2_payload_is_reported_coerced_listed_and_serialised() -> void:
	# Arrange
	var log: EventLog = EventLog.new(CAP, EventLog.SCOPE_MATCH, _meta())

	# Act / Assert — asserted in debug (warning in release)
	await _assert_reported(func() -> void: log.append(&"minion_summoned", {"instance_id": 3, "pos": Vector2(1, 2)}),
		"EventLog.append: 'minion_summoned' payload holds non-JSON values at pos")

	# Assert — coerced in every build; to_json succeeds
	var payload: Dictionary = log.events_since(0)[0].payload
	assert_str(payload.pos).is_equal("<unserializable:Vector2>")
	assert_array(payload._coerced).is_equal(["pos"])
	assert_int(payload.instance_id).is_equal(3)
	var copy: EventLog = EventLog.from_json(log.to_json())
	assert_str(copy.events_since(0)[0].payload.pos).is_equal("<unserializable:Vector2>")
	EventLogAssertions.assert_envelopes_valid(log.events_since(0))


func test_nested_and_object_values_are_coerced_with_their_key_paths() -> void:
	# Arrange
	var log: EventLog = EventLog.new(CAP, EventLog.SCOPE_MATCH, _meta())
	var payload: Dictionary = {"detail": {"tint": Color.RED}, "list": [1, RefCounted.new()], 7: "seven"}

	# Act
	await _assert_reported(func() -> void: log.append(&"run_warning", payload),
		"EventLog.append: 'run_warning' payload holds non-JSON values at detail.tint, list[1], [key 7]")

	# Assert
	var stored: Dictionary = log.events_since(0)[0].payload
	assert_str(stored.detail.tint).is_equal("<unserializable:Color>")
	assert_str(stored.list[1]).is_equal("<unserializable:RefCounted>")
	assert_int(stored.list[0]).is_equal(1)
	assert_str(stored["7"]).is_equal("seven")
	assert_array(stored._coerced).is_equal(["detail.tint", "list[1]", "[key 7]"])
	assert_bool(GameAssertions.is_json_representable(stored)).is_true()


func test_json_only_payload_is_not_reported_and_carries_no_coerced_list() -> void:
	# Arrange
	var log: EventLog = EventLog.new(CAP, EventLog.SCOPE_MATCH, _meta())

	# Act / Assert — no assert, no warning
	await assert_error(func() -> void: log.append(&"healed", {"amount": 2, "ok": true, "none": null, "ratio": RATIO, "list": [{"a": "b"}]})).is_success()
	assert_bool(log.events_since(0)[0].payload.has("_coerced")).is_false()


# --- AC-3: diagnostics share the log -------------------------------------------

func test_command_rejected_diagnostic_is_an_ordinary_event() -> void:
	# Arrange
	var log: EventLog = EventLog.new(CAP, EventLog.SCOPE_MATCH, _meta())
	var seen: Array = []
	log.subscribe(func(event: Dictionary) -> void: seen.append(event.type))
	log.append(&"turn_started", {"turn": 1, "side": MatchFactory.SIDE_PLAYER})

	# Act
	var seq: int = log.append(&"command_rejected", {"diagnostic": true, "side": MatchFactory.SIDE_PLAYER, "command": "play_card", "code": "not_enough_mana"}, 0)
	var caused: int = log.append(&"ai_decision", {"diagnostic": true, "choice": 0}, seq)
	var copy: EventLog = EventLog.from_json(log.to_json())

	# Assert — next seq, served by events_since, counted, a cause_seq target, round-trips
	assert_int(seq).is_equal(2)
	assert_int(log.size()).is_equal(3)
	assert_str(log.events_since(1)[0].type).is_equal("command_rejected")
	assert_bool(log.events_since(1)[0].payload.diagnostic).is_true()
	assert_int(log.events_since(caused - 1)[0].cause_seq).is_equal(seq)
	assert_array(seen).is_equal(["turn_started", "command_rejected", "ai_decision"])
	EventLogAssertions.assert_replay_equal(log.events_since(0), copy.events_since(0))


# --- AC-4: canonical equality (F6) -------------------------------------------------

func test_two_logs_from_the_same_script_are_byte_equal_in_canonical_form_and_to_json() -> void:
	# Arrange
	var a: EventLog = _scripted_match_log()
	var b: EventLog = _scripted_match_log()

	# Act / Assert
	assert_str(EventLogAssertions.canonical_json(a.events_since(0))).is_equal(EventLogAssertions.canonical_json(b.events_since(0)))
	assert_str(a.to_json()).is_equal(b.to_json())
	EventLogAssertions.assert_replay_equal(a.events_since(0), b.events_since(0))


func test_a_log_differing_in_one_payload_value_is_not_equal() -> void:
	# Arrange
	var a: EventLog = _scripted_match_log(5)
	var b: EventLog = _scripted_match_log(4)

	# Act / Assert
	assert_str(EventLogAssertions.canonical_json(a.events_since(0))).is_not_equal(EventLogAssertions.canonical_json(b.events_since(0)))
	assert_str(a.to_json()).is_not_equal(b.to_json())
	assert_failure(func() -> void: EventLogAssertions.assert_replay_equal(a.events_since(0), b.events_since(0))).is_failed()


func test_round_tripped_to_json_reproduces_the_same_canonical_form() -> void:
	# Arrange
	var log: EventLog = _scripted_match_log()

	# Act
	var once: EventLog = EventLog.from_json(log.to_json())
	var twice: EventLog = EventLog.from_json(once.to_json())

	# Assert
	assert_str(EventLogAssertions.canonical_json(twice.events_since(0))).is_equal(EventLogAssertions.canonical_json(log.events_since(0)))
