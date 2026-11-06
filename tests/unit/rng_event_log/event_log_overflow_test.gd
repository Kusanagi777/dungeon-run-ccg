## EventLog overflow fault (`log_overflow` → Faulted → Sealed), the F7 cap and
## the `rng_event_log` config validator.
##
## Story: production/epics/rng-event-log/story-007-overflow-fault-and-config-knobs.md
## GDD: design/gdd/rng-event-log.md rule 16, F7, States and Transitions, Tuning
## Knobs, Edge Cases ("max_match_events"). ADR-0003 Decision 8; ADR-0002
## Decision 4 (stage 7a config validators). Config bodies are built in memory
## with `CardFactory.make_config_file` shapes; the shipped file itself is read
## by tests/integration/rng_event_log/event_log_config_file_test.gd.
extends GdUnitTestSuite

const BOOT_SCRIPT: GDScript = preload("res://src/core/boot.gd")
## A tiny cap so the overflow path is reached in five appends (story AC).
const TINY_CAP: int = 5
## rng-event-log Tuning Knobs defaults and safe ranges — boundary values, the
## exact numbers ARE the point (coding-standards "No hardcoded data" exception).
const DEFAULT_BUDGET: int = TestConstants.LOG_MEMORY_BUDGET_BYTES
const DEFAULT_AVG: int = 200
const MIN_BUDGET: int = 500000
const MAX_BUDGET: int = 20000000
const MIN_AVG: int = 100
const MAX_AVG: int = 400
## F7 at the minimum budget: floor(500,000 / 200).
const CAP_AT_MIN_BUDGET: int = 2500
const ENTRY_KEYS: Array[String] = ["severity", "code", "file", "record_id", "field", "message"]


func _full_log(cap: int = TINY_CAP, scope: String = EventLog.SCOPE_MATCH) -> EventLog:
	var log: EventLog = EventLog.new(cap, scope)
	for i: int in range(cap):
		log.append(&"healed", {"amount": i})
	return log


## The shipped `rng_event_log.json` body (story AC-2 values).
func _body() -> Dictionary:
	return CardFactory.make_config_file({
		"log_memory_budget_bytes": DEFAULT_BUDGET,
		"avg_event_bytes": DEFAULT_AVG,
		"keep_match_logs": {"debug": true, "release": false},
	}).config


func _fault_result() -> Dictionary:
	return {"result": "fault", "winner": null, "reason": "event_cap"}


func _codes(entries: Array) -> Array:
	return entries.map(func(e: Dictionary) -> StringName: return e.code)


func _fields(entries: Array) -> Array:
	return entries.map(func(e: Dictionary) -> Variant: return e.field)


# --- AC-1: overflow ------------------------------------------------------------

func test_append_at_the_cap_appends_log_overflow_and_drops_the_attempted_event() -> void:
	# Arrange
	var log: EventLog = _full_log()
	var out: Dictionary = {"seq": 0}

	# Act — the attempt is dropped with a warning (a rules fault, not an assert)
	await assert_error(func() -> void: out.seq = log.append(&"card_drawn", {"instance_id": 9})) \
		.is_push_warning("EventLog.append: max_events 5 reached; 'card_drawn' dropped, log_overflow appended at seq 6")

	# Assert
	var events: Array[Dictionary] = log.events_since(0)
	assert_int(out.seq).is_equal(-1)
	assert_int(log.size()).is_equal(TINY_CAP + 1)
	assert_str(events.back().type).is_equal("log_overflow")
	assert_dict(events.back().payload).is_equal({"cap": TINY_CAP, "seq": TINY_CAP + 1})
	assert_int(events.back().seq).is_equal(TINY_CAP + 1)
	EventLogAssertions.assert_not_contains_type(events, &"card_drawn")
	assert_int(log.state()).is_equal(EventLog.State.FAULTED)
	assert_bool(log.is_sealed()).is_false()


func test_overflowed_signal_fires_once_with_cap_and_seq() -> void:
	# Arrange — lambdas capture by value: record through a shared Array
	var log: EventLog = _full_log()
	var fired: Array = []
	log.overflowed.connect(func(cap: int, seq: int) -> void: fired.append([cap, seq]))

	# Act — overflow, the one further event, then the log is sealed
	log.append(&"card_drawn", {})
	log.append(&"match_ended", _fault_result())

	# Assert — once, for the Faulted transition only
	assert_array(fired).is_equal([[TINY_CAP, TINY_CAP + 1]])


func test_faulted_log_accepts_exactly_one_more_event_then_is_sealed() -> void:
	# Arrange
	var log: EventLog = _full_log()
	log.append(&"card_drawn", {})

	# Act — the test plays Match Rules and answers with match_ended(fault)
	var ended: int = log.append(&"match_ended", _fault_result())
	var out: Dictionary = {"seq": 0}
	if OS.is_debug_build():
		await assert_error(func() -> void: out.seq = log.append(&"turn_ended", {})) \
			.is_runtime_error("Assertion failed: EventLog.append: the log is sealed; 'turn_ended' dropped")
	else:
		await assert_error(func() -> void: out.seq = log.append(&"turn_ended", {})) \
			.is_push_warning("EventLog.append: the log is sealed; 'turn_ended' dropped")

	# Assert — Open → Faulted → Sealed
	assert_int(ended).is_equal(TINY_CAP + 2)
	assert_bool(log.is_sealed()).is_true()
	assert_int(out.seq).is_equal(-1)
	assert_int(log.size()).is_equal(TINY_CAP + 2)
	EventLogAssertions.assert_consecutive(log.events_since(0), [&"log_overflow", &"match_ended"])
	EventLogAssertions.assert_payload(log.events_since(0), &"match_ended", _fault_result())


func test_the_log_never_appends_match_ended_itself() -> void:
	# Arrange
	var log: EventLog = _full_log()

	# Act — overflow, and nobody answers
	log.append(&"card_drawn", {})

	# Assert
	EventLogAssertions.assert_count(log.events_since(0), &"match_ended", 0)
	EventLogAssertions.assert_last_type(log.events_since(0), &"log_overflow")


func test_the_one_further_event_may_be_any_type_and_still_seals() -> void:
	# Arrange
	var log: EventLog = _full_log()
	log.append(&"card_drawn", {})

	# Act
	var seq: int = log.append(&"resolution_overflow", {"steps": 1})

	# Assert
	assert_int(seq).is_equal(TINY_CAP + 2)
	assert_bool(log.is_sealed()).is_true()


func test_subscribers_receive_log_overflow_before_the_signal_fires() -> void:
	# Arrange
	var log: EventLog = _full_log()
	var order: Array = []
	log.subscribe(func(event: Dictionary) -> void: order.append(event.type))
	log.overflowed.connect(func(_cap: int, _seq: int) -> void: order.append("overflowed"))

	# Act
	log.append(&"card_drawn", {})

	# Assert
	assert_array(order).is_equal(["log_overflow", "overflowed"])


func test_match_ended_appended_from_the_overflowed_handler_is_accepted_untagged() -> void:
	# Arrange — the engine answers the Faulted transition from the signal
	var log: EventLog = _full_log()
	var answer: Dictionary = {"seq": 0}
	log.overflowed.connect(func(_cap: int, _seq: int) -> void:
		answer.seq = log.append(&"match_ended", _fault_result()))

	# Act
	log.append(&"card_drawn", {})

	# Assert
	assert_int(answer.seq).is_equal(TINY_CAP + 2)
	assert_bool(log.is_sealed()).is_true()
	assert_bool(log.events_since(0).back().payload.has("_reentrant")).is_false()


func test_a_faulted_log_round_trips_as_faulted() -> void:
	# Arrange
	var log: EventLog = _full_log()
	log.append(&"card_drawn", {})

	# Act
	var copy: EventLog = EventLog.from_json(log.to_json(), TINY_CAP)

	# Assert — Faulted survives; the one further append still seals
	assert_int(copy.state()).is_equal(EventLog.State.FAULTED)
	assert_int(copy.append(&"match_ended", _fault_result())).is_equal(TINY_CAP + 2)
	assert_bool(copy.is_sealed()).is_true()


func test_the_cap_applies_to_run_scope_logs_too() -> void:
	# Arrange
	var log: EventLog = _full_log(TINY_CAP, EventLog.SCOPE_RUN)

	# Act
	log.append(&"run_floor_entered", {"floor": 1})

	# Assert
	assert_int(log.state()).is_equal(EventLog.State.FAULTED)
	EventLogAssertions.assert_last_type(log.events_since(0), &"log_overflow")


# --- AC-2: F7 cap from config ---------------------------------------------------

func test_max_events_for_the_defaults_is_ten_thousand() -> void:
	assert_int(EventLog.max_events_for(_body())).is_equal(TestConstants.MAX_MATCH_EVENTS)


func test_max_events_for_the_minimum_budget_is_two_thousand_five_hundred() -> void:
	# Arrange
	var body: Dictionary = _body()
	body.log_memory_budget_bytes = MIN_BUDGET

	# Act / Assert
	assert_int(EventLog.max_events_for(body)).is_equal(CAP_AT_MIN_BUDGET)


func test_max_events_for_floors_the_quotient_and_accepts_json_floats() -> void:
	# Arrange — JSON numbers arrive as floats
	var body: Dictionary = {"log_memory_budget_bytes": float(DEFAULT_BUDGET + DEFAULT_AVG - 1), "avg_event_bytes": float(DEFAULT_AVG)}

	# Act / Assert
	assert_int(EventLog.max_events_for(body)).is_equal(TestConstants.MAX_MATCH_EVENTS)


func test_max_events_for_a_body_without_the_knobs_reports_and_returns_zero() -> void:
	# Arrange
	var out: Dictionary = {"cap": -1}

	# Act / Assert — a fault, never a fallback number
	await assert_error(func() -> void: out.cap = EventLog.max_events_for({})) \
		.is_push_error("EventLog.max_events_for: log_memory_budget_bytes and avg_event_bytes must be positive whole numbers")
	assert_int(out.cap).is_zero()


# --- AC-3: validate_config ----------------------------------------------------

func test_validate_config_accepts_the_shipped_body_and_the_range_bounds() -> void:
	# Arrange
	var at_min: Dictionary = _body()
	at_min.log_memory_budget_bytes = MIN_BUDGET
	at_min.avg_event_bytes = MIN_AVG
	var at_max: Dictionary = _body()
	at_max.log_memory_budget_bytes = float(MAX_BUDGET)
	at_max.avg_event_bytes = float(MAX_AVG)

	# Act / Assert
	assert_array(EventLog.validate_config(_body(), null)).is_empty()
	assert_array(EventLog.validate_config(at_min, null)).is_empty()
	assert_array(EventLog.validate_config(at_max, null)).is_empty()


func test_validate_config_reports_each_out_of_range_knob_once_by_key() -> void:
	# Arrange
	var cases: Array = [
		["log_memory_budget_bytes", MIN_BUDGET - 1],
		["log_memory_budget_bytes", MAX_BUDGET + 1],
		["avg_event_bytes", MIN_AVG - 1],
		["avg_event_bytes", MAX_AVG + 1],
	]

	for c: Array in cases:
		var body: Dictionary = _body()
		body[c[0]] = c[1]

		# Act
		var entries: Array = EventLog.validate_config(body, null)

		# Assert
		assert_array(_codes(entries)).override_failure_message("%s = %d" % c).is_equal([EventLog.E_RANGE])
		assert_array(_fields(entries)).is_equal([c[0]])


func test_validate_config_reports_a_missing_key_once_by_key() -> void:
	for key: String in ["log_memory_budget_bytes", "avg_event_bytes", "keep_match_logs"]:
		# Arrange
		var body: Dictionary = _body()
		body.erase(key)

		# Act
		var entries: Array = EventLog.validate_config(body, null)

		# Assert
		assert_array(_codes(entries)).override_failure_message(key).is_equal([EventLog.E_MISSING_FIELD])
		assert_array(_fields(entries)).is_equal([key])


func test_validate_config_reports_a_non_bool_or_missing_keep_match_logs_entry() -> void:
	# Arrange
	var not_bool: Dictionary = _body()
	not_bool.keep_match_logs = {"debug": "yes", "release": false}
	var missing: Dictionary = _body()
	missing.keep_match_logs = {"debug": true}
	var not_object: Dictionary = _body()
	not_object.keep_match_logs = true

	# Act
	var a: Array = EventLog.validate_config(not_bool, null)
	var b: Array = EventLog.validate_config(missing, null)
	var c: Array = EventLog.validate_config(not_object, null)

	# Assert
	assert_array(_codes(a)).is_equal([EventLog.E_SCHEMA])
	assert_array(_fields(a)).is_equal(["keep_match_logs.debug"])
	assert_array(_codes(b)).is_equal([EventLog.E_MISSING_FIELD])
	assert_array(_fields(b)).is_equal(["keep_match_logs.release"])
	assert_array(_codes(c)).is_equal([EventLog.E_SCHEMA])
	assert_array(_fields(c)).is_equal(["keep_match_logs"])


func test_validate_config_reports_a_non_whole_number_knob() -> void:
	# Arrange
	var fraction: Dictionary = _body()
	fraction.avg_event_bytes = 150.5
	var text: Dictionary = _body()
	text.log_memory_budget_bytes = "2000000"

	# Act / Assert
	assert_array(_codes(EventLog.validate_config(fraction, null))).is_equal([EventLog.E_SCHEMA])
	assert_array(_codes(EventLog.validate_config(text, null))).is_equal([EventLog.E_SCHEMA])


func test_validate_config_entries_have_the_validation_report_shape() -> void:
	# Act
	var entries: Array = EventLog.validate_config({}, null)

	# Assert — three missing keys, each a ValidationReport entry
	assert_int(entries.size()).is_equal(3)
	for e: Dictionary in entries:
		assert_array(e.keys()).contains_exactly_in_any_order(ENTRY_KEYS)
		assert_bool(e.severity == ValidationReport.SEVERITY_ERROR).is_true()
		assert_str(e.file).is_equal(EventLog.CONFIG_FILE)
		assert_object(e.record_id).is_null()
		assert_str(e.message).is_not_empty()


func test_validate_config_never_asserts_on_bad_data() -> void:
	# Arrange — wrong types everywhere
	var body: Dictionary = {"log_memory_budget_bytes": null, "avg_event_bytes": [], "keep_match_logs": {"debug": 1, "release": null}}

	# Act / Assert — no runtime error, no push_error; data faults are entries
	await assert_error(func() -> void: EventLog.validate_config(body, null)).is_success()
	assert_int(EventLog.validate_config(body, null).size()).is_equal(4)


func test_boot_registers_validate_config_as_the_rng_event_log_config_validator() -> void:
	# Arrange — a fresh Boot instance; boot() is not called
	var boot: Node = auto_free(BOOT_SCRIPT.new())

	# Act
	var configs: Dictionary = boot._collect_validators(null).configs
	var registered: Callable = configs.get("rng_event_log", Callable())

	# Assert — the registered Callable is this validator (static, call(body, db))
	assert_bool(registered.is_valid()).is_true()
	assert_array(registered.call(_body(), null)).is_empty()
	assert_array(_codes(registered.call({}, null))).is_equal([EventLog.E_MISSING_FIELD, EventLog.E_MISSING_FIELD, EventLog.E_MISSING_FIELD])
