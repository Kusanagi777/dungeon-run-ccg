## Append-only event-log test double for RNG & Event Log rules 11-16.
##
## DD-T04: every mutation emits exactly one event and the UI renders from
## events, so most rules tests assert on the log rather than on state. Until
## the production log exists this double is the `log` a test passes in
## `MatchConfig`. It implements the GDD contract literally:
##   - rule 11 envelope `{seq, turn, type, payload, cause_seq}`, `seq` from 1,
##     +1 per append (F7); `turn` is stamped from the `turn` property;
##   - rule 13 `append` is the only writer, `subscribe` delivers each event once
##     in order after the append, `events_since(seq)` returns the later ones;
##   - rule 15 `match_ended` / `run_ended` seal the log; a later append is
##     dropped and counted in `dropped`;
##   - rule 16 / Edge Cases: at `max_events` the log appends `log_overflow`,
##     forces `match_ended{result: fault, reason: event_cap}` and seals (the
##     overflowing event itself is dropped). match-rules Edge Cases phrases the
##     cap slightly differently (Open Question) — the production log settles it.
## `type` is stored as a String (rule 14 serialises StringName as String), so
## `event.type == "card_drawn"` and `== &"card_drawn"` both hold.
##
## TODO(E1 story): swap to the production event log once it exists; keep this
## double for tests that need a tiny `max_events`.
class_name TestEventLog
extends RefCounted

## Scope label carried by `to_json()` (rule 17).
const SCOPE_MATCH: String = "match"
## rng-event-log rule 17 `log_schema_version`
const LOG_SCHEMA_VERSION: int = 1

## The appended events, in `seq` order (rule 13: never edited, never removed).
var events: Array[Dictionary] = []
## Match turn stamped on each append (0 during setup and mulligan, rule 11).
var turn: int = 0
## True once `match_ended` / `run_ended` was appended or the cap was hit.
var sealed: bool = false
## Hard cap (rule 16); tests lower it to exercise the overflow path.
var max_events: int = TestConstants.MAX_MATCH_EVENTS
## Appends refused because the log was sealed or capped.
var dropped: int = 0

var _subscribers: Array[Callable] = []


## Rule 13: append one event and return its `seq`; -1 when dropped.
func append(type: StringName, payload: Dictionary = {}, cause_seq: int = 0) -> int:
	if sealed:
		dropped += 1
		return -1
	if events.size() >= max_events:
		_overflow()
		dropped += 1
		return -1
	return _append_raw(type, payload, cause_seq)


## Rule 13: every event with a `seq` greater than `since_seq`; a negative
## argument returns every event (Edge Cases).
func events_since(since_seq: int) -> Array[Dictionary]:
	var later: Array[Dictionary] = []
	for event: Dictionary in events:
		if int(event.seq) > since_seq:
			later.append(event)
	return later


## Rule 13: `callback(event)` is called once per event, in order, after append.
func subscribe(callback: Callable) -> void:
	_subscribers.append(callback)


## Every event whose `type` equals `type`, in order.
func of_type(type: StringName) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for event: Dictionary in events:
		if event.type == String(type):
			found.append(event)
	return found


## Number of events of `type`.
func count(type: StringName) -> int:
	return of_type(type).size()


## The first event of `type`, or an empty Dictionary when there is none.
func first(type: StringName) -> Dictionary:
	var found: Array[Dictionary] = of_type(type)
	return found[0] if not found.is_empty() else {}


## The last appended event, or an empty Dictionary for an empty log.
func last() -> Dictionary:
	return events[events.size() - 1] if not events.is_empty() else {}


## The event types in order — the shape most ordering assertions read.
func types() -> Array[String]:
	var names: Array[String] = []
	for event: Dictionary in events:
		names.append(String(event.type))
	return names


## Rule 17: canonical JSON of the metadata block plus every event (F6 canonical
## form: sorted keys, floats to 6 decimals, StringName as String).
func to_json() -> String:
	return EventLogAssertions.canonical_json({
		"log_schema_version": LOG_SCHEMA_VERSION,
		"scope": SCOPE_MATCH,
		"events": events,
	})


## Rule 17: rebuild a log from `to_json()` output. JSON parsing yields floats
## for every number; whole-number floats are coerced back to int so the
## round-tripped log is `replay_equal` to the original (payload values are
## ints by design — rng-event-log Edge Cases "If a payload holds a float").
static func from_json(text: String) -> TestEventLog:
	var log: TestEventLog = TestEventLog.new()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return log
	for raw: Variant in parsed.get("events", []):
		var event: Dictionary = _coerce_integral_floats(raw)
		log.events.append(event)
	log.sealed = not log.events.is_empty() and (log.last().type == "match_ended" or log.last().type == "run_ended")
	return log


func _append_raw(type: StringName, payload: Dictionary, cause_seq: int) -> int:
	var seq: int = events.size() + 1
	var event: Dictionary = {
		"seq": seq,
		"turn": turn,
		"type": String(type),
		"payload": payload.duplicate(true),
		"cause_seq": cause_seq,
	}
	events.append(event)
	if type == &"match_ended" or type == &"run_ended":
		sealed = true
	for callback: Callable in _subscribers:
		callback.call(event)
	return seq


func _overflow() -> void:
	@warning_ignore("return_value_discarded")
	_append_raw(&"log_overflow", {"cap": max_events, "seq": events.size() + 1}, 0)
	@warning_ignore("return_value_discarded")
	_append_raw(&"match_ended", {"result": "fault", "reason": "event_cap"}, 0)


static func _coerce_integral_floats(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			return int(value) if is_equal_approx(value, floor(value)) else value
		TYPE_ARRAY:
			var out: Array = []
			for item: Variant in value:
				out.append(_coerce_integral_floats(item))
			return out
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			for key: Variant in value:
				out[key] = _coerce_integral_floats(value[key])
			return out
		_:
			return value
