## Event-log assertions for Dungeon Run CCG tests.
##
## The GDD acceptance criteria are written against the log ("`weapon_destroyed`
## then `trigger_resolved` then `weapon_equipped`", "the two `damage_dealt`
## events have consecutive `seq`", "`match_ended` is the last event", "the two
## logs are byte-identical"). Each helper below turns one of those phrasings
## into a single assertion. Every helper accepts either a `TestEventLog` or a
## plain Array of event Dictionaries (so the production log's `events_since(0)`
## result works unchanged).
##
## Failures go through `GameAssertions.fail_if` — gdUnit4's assertion API, never
## a bare `assert()`. Plain class: must not extend GdUnitTestSuite.
class_name EventLogAssertions
extends RefCounted

## rng-event-log rule 11 envelope keys.
const ENVELOPE_KEYS: Array[String] = ["seq", "turn", "type", "payload", "cause_seq"]


## Assert the events contain `types` as a subsequence, in that order (other
## events may sit between them). match-rules AC-14, AC-26, AC-28.
static func assert_order(source: Variant, types: Array, label: String = "log") -> void:
	var events: Array = _events_of(source)
	var cursor: int = 0
	var previous: String = "(start)"
	for wanted: Variant in types:
		var found: int = -1
		for i: int in range(cursor, events.size()):
			if events[i].type == String(wanted):
				found = i
				break
		if found < 0:
			GameAssertions.fail_if(true, "%s: expected '%s' after %s but it is absent; order seen: %s" % [label, String(wanted), previous, str(_types_of(events))])
			return
		previous = "'%s' (seq %s)" % [String(wanted), str(events[found].seq)]
		cursor = found + 1
	GameAssertions.fail_if(false, "")


## Assert the events contain `types` as adjacent events with consecutive `seq`
## and nothing between them. match-rules AC-16 ("no `minion_died` between").
static func assert_consecutive(source: Variant, types: Array, label: String = "log") -> void:
	var events: Array = _events_of(source)
	if types.is_empty():
		GameAssertions.fail_if(false, "")
		return
	for start: int in range(events.size()):
		if events[start].type != String(types[0]):
			continue
		var matched: bool = start + types.size() <= events.size()
		for k: int in range(types.size()):
			if not matched:
				break
			matched = events[start + k].type == String(types[k]) \
				and int(events[start + k].seq) == int(events[start].seq) + k
		if matched:
			GameAssertions.fail_if(false, "")
			return
	GameAssertions.fail_if(true, "%s: expected consecutive events %s; order seen: %s" % [label, str(types), str(_types_of(events))])


## Assert at least one event of `type` is present.
static func assert_contains_type(source: Variant, type: StringName, label: String = "log") -> void:
	GameAssertions.fail_if(count_type(source, type) == 0, "%s: expected an event of type '%s'; seen: %s" % [label, String(type), str(_types_of(_events_of(source)))])


## Assert no event of `type` is present ("no `healed` event", match-rules AC-22).
static func assert_not_contains_type(source: Variant, type: StringName, label: String = "log") -> void:
	GameAssertions.fail_if(count_type(source, type) > 0, "%s: expected no event of type '%s' but found %d" % [label, String(type), count_type(source, type)])


## Assert exactly `expected` events of `type` ("exactly two `card_drawn`").
static func assert_count(source: Variant, type: StringName, expected: int, label: String = "log") -> void:
	var n: int = count_type(source, type)
	GameAssertions.fail_if(n != expected, "%s: expected %d event(s) of type '%s' but found %d" % [label, expected, String(type), n])


## Assert the last event has `type` ("`match_ended` is the last event").
static func assert_last_type(source: Variant, type: StringName, label: String = "log") -> void:
	var events: Array = _events_of(source)
	var last_type: String = String(events[events.size() - 1].type) if not events.is_empty() else "(empty)"
	GameAssertions.fail_if(last_type != String(type), "%s: expected last event '%s' but it is '%s'" % [label, String(type), last_type])


## Assert the first event of `type` carries every key/value in `expected`
## (a subset match on the payload). match-rules AC-07 `mana_spent {amount: 2}`.
static func assert_payload(source: Variant, type: StringName, expected: Dictionary, label: String = "log") -> void:
	for event: Dictionary in _events_of(source):
		if event.type != String(type):
			continue
		var payload: Dictionary = event.payload
		for key: Variant in expected:
			if not payload.has(key) or payload[key] != expected[key]:
				GameAssertions.fail_if(true, "%s: '%s' payload %s does not carry %s" % [label, String(type), str(payload), str(expected)])
				return
		GameAssertions.fail_if(false, "")
		return
	GameAssertions.fail_if(true, "%s: no event of type '%s' to check a payload on" % [label, String(type)])


## Assert `seq` runs 1, 2, 3, … with no gap (F7 `seq(n) = n`).
static func assert_seq_contiguous(source: Variant, label: String = "log") -> void:
	var events: Array = _events_of(source)
	for i: int in range(events.size()):
		if int(events[i].seq) != i + 1:
			GameAssertions.fail_if(true, "%s: event at index %d has seq %s, expected %d" % [label, i, str(events[i].seq), i + 1])
			return
	GameAssertions.fail_if(false, "")


## Assert every `cause_seq` is in [0, seq - 1] (F7; Edge Cases "cause_seq < seq").
static func assert_cause_seq_valid(source: Variant, label: String = "log") -> void:
	for event: Dictionary in _events_of(source):
		var cause: int = int(event.cause_seq)
		if cause < 0 or cause >= int(event.seq):
			GameAssertions.fail_if(true, "%s: event seq %s has cause_seq %d outside [0, %d]" % [label, str(event.seq), cause, int(event.seq) - 1])
			return
	GameAssertions.fail_if(false, "")


## Assert every event has the rule 11 envelope and a rule 14 JSON-only payload.
static func assert_envelopes_valid(source: Variant, label: String = "log") -> void:
	for event: Dictionary in _events_of(source):
		for key: String in ENVELOPE_KEYS:
			if not event.has(key):
				GameAssertions.fail_if(true, "%s: event %s lacks envelope key '%s'" % [label, str(event), key])
				return
		var offender: Array = []
		if not GameAssertions.is_json_representable(event.payload, offender):
			GameAssertions.fail_if(true, "%s: event seq %s payload holds a non-JSON value at %s" % [label, str(event.seq), str(offender)])
			return
	GameAssertions.fail_if(false, "")


## F6 replay equivalence: canonical JSON of both event lists is identical.
## Reports the first differing index when it is not.
static func assert_replay_equal(a: Variant, b: Variant, label: String = "logs") -> void:
	var ea: Array = _events_of(a)
	var eb: Array = _events_of(b)
	var limit: int = mini(ea.size(), eb.size())
	for i: int in range(limit):
		if canonical_json(ea[i]) != canonical_json(eb[i]):
			GameAssertions.fail_if(true, "%s differ at index %d:\n  A: %s\n  B: %s" % [label, i, canonical_json(ea[i]), canonical_json(eb[i])])
			return
	GameAssertions.fail_if(ea.size() != eb.size(), "%s differ in length: %d vs %d" % [label, ea.size(), eb.size()])


## Number of events of `type` in `source`.
static func count_type(source: Variant, type: StringName) -> int:
	var n: int = 0
	for event: Dictionary in _events_of(source):
		if event.type == String(type):
			n += 1
	return n


## F6 `canonical_json`: keys sorted, floats printed with 6 decimals, StringName
## as String, no whitespace. Deterministic across machines for rule 14 values.
static func canonical_json(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if value else "false"
		TYPE_INT:
			return str(value)
		TYPE_FLOAT:
			return "%.6f" % value
		TYPE_STRING, TYPE_STRING_NAME:
			return JSON.stringify(String(value))
		TYPE_ARRAY:
			var parts: PackedStringArray = PackedStringArray()
			for item: Variant in value:
				parts.append(canonical_json(item))
			return "[" + ",".join(parts) + "]"
		TYPE_DICTIONARY:
			var keys: Array = value.keys().map(func(k: Variant) -> String: return String(k))
			keys.sort()
			var parts: PackedStringArray = PackedStringArray()
			for key: String in keys:
				var raw_key: Variant = key if value.has(key) else StringName(key)
				parts.append(JSON.stringify(key) + ":" + canonical_json(value[raw_key]))
			return "{" + ",".join(parts) + "}"
		_:
			return JSON.stringify("<unserializable:%s>" % type_string(typeof(value)))


static func _events_of(source: Variant) -> Array:
	if source is TestEventLog:
		return (source as TestEventLog).events
	if typeof(source) == TYPE_ARRAY:
		return source
	return []


static func _types_of(events: Array) -> Array:
	var names: Array = []
	for event: Dictionary in events:
		names.append(String(event.type))
	return names
