## The append-only event log (rng-event-log rules 11-15, F7; ADR-0003
## Decision 5, 7, 8).
##
## One log per match (`scope` `"match"`) and one per run (`"run"`), built by
## `RunMachine` / `MatchDriver` on the rules side and by tests directly; never
## looked up through `Boot`, a static or an autoload. [method append] is the
## only writer. It stamps the rule 11 envelope
## `{seq, turn, type, payload, cause_seq}`: `seq` from 1, +1 per append (F7);
## `turn` from [method set_turn] (0 before the first call and on run logs);
## `type` stored as `String`; `payload` deep-copied. It stores the event, then
## notifies every subscriber synchronously, in registration order, on the
## calling thread. Event delivery uses no Godot signal (ADR-0003 Alternative 5).
##
## [codeblock]
## var log: EventLog = EventLog.new(max_events, EventLog.SCOPE_MATCH, meta)
## log.subscribe(func(event: Dictionary) -> void: view_state.apply(event))
## log.set_turn(1)
## var seq: int = log.append(&"turn_started", {"turn": 1, "side": "player"})
## log.append(&"card_drawn", {"side": "player", "instance_id": 12}, seq)
## log.events_since(seq)   # [the card_drawn event]
## log.append(&"match_ended", {"result": "win"})   # seals the log
## log.append(&"card_drawn", {})                    # -1: sealed (assert in debug)
## [/codeblock]
##
## Stored events are read-only (the envelope, the payload and every nested
## container): [method events_since] and subscribers receive them without a
## copy, and an edit is refused by the engine. [method snapshot] returns a
## writable deep copy.
##
## Payloads hold rule 14 values only. At append a `StringName` (value or key)
## becomes a `String`; any other non-JSON value (an Object, a `Vector2`, a
## `Color`, a `Callable`, a non-String key…) is a caller bug: reported, then
## replaced by `"<unserializable:ClassName>"` (a key by its `str()` form) and
## its key path listed in `payload._coerced` (Edge Cases), so a bug report
## always serialises. Diagnostics (`command_rejected`, `ai_decision`,
## `ai_plan_aborted`, `ai_fault`, `run_warning`) are ordinary appends with
## `payload.diagnostic = true` (rule 12a): there is no second channel and no
## filter here — filtering is `MatchViewState`'s job.
##
## [method to_json] is the bug-report attachment and replay input (rule 17);
## [method from_json] rebuilds a log from it. 64-bit values travel as 16-hex
## strings (`run_seed_hex`): JSON numbers are doubles, exact only to 2^53.
## Known limit: a float payload value with no fractional part (`2.0`) comes
## back as the `int` 2 — gameplay quantities are ints (Edge Cases).
##
## Caller bugs (an append to a sealed log, a re-entrant append, a non-JSON
## payload value) assert in debug builds and push a warning in release; the
## release behaviour is the one the GDD names, and it also runs in debug once
## the assert has been reported.
##
## Single-thread-only: the log has no lock. A worker plans on a clone with its
## own scratch log and never appends to or subscribes to the live log
## (ADR-0006, ADR-0008 Decision 5).
class_name EventLog
extends RefCounted

## The Faulted transition (rule 16): emitted once, after `log_overflow{cap,
## seq}` is stored and delivered. The engine answers by appending
## `match_ended{result: fault, winner: null, reason: event_cap}`, the one event
## a Faulted log still accepts. The one sanctioned signal on the log — events
## themselves are delivered through [method subscribe] (ADR-0003 Alt 5).
## Example: `log.overflowed.connect(func(cap: int, seq: int) -> void: engine.fault_event_cap())`.
signal overflowed(cap: int, seq: int)

## `scope` of a match log, sealed by `match_ended` (rule 15).
const SCOPE_MATCH: String = "match"
## `scope` of a run log, sealed by `run_ended` (rule 15).
const SCOPE_RUN: String = "run"
## rng-event-log rule 17 `log_schema_version` written by [method to_json] and
## the only one [method from_json] reads (older logs are migrated by Meta
## Progression first; newer ones are kept opaque — Edge Cases).
const LOG_SCHEMA_VERSION: int = 1
## The rule 11 envelope keys, in stamping order.
const ENVELOPE_KEYS: Array[String] = ["seq", "turn", "type", "payload", "cause_seq"]

## The DD-T01 file [method validate_config] reports against.
const CONFIG_FILE: String = "rng_event_log.json"
## rng-event-log Tuning Knobs "Safe range" column, `[min, max]` inclusive, for
## the two integer knobs (F7). Validation bounds, not knob values: like
## `DataLoader.SCHEMA_VERSION_CURRENT` they cannot come from the file they
## validate. The knob values themselves live only in `assets/data/`.
const CONFIG_SAFE_RANGES: Dictionary[String, Array] = {
	"log_memory_budget_bytes": [500_000, 20_000_000],
	"avg_event_bytes": [100, 400],
}
## The build types `keep_match_logs` carries a bool for (Tuning Knobs).
const KEEP_MATCH_LOGS_KEYS: Array[String] = ["debug", "release"]
## Validator code (ADR-0002 closed set): a knob is absent.
const E_MISSING_FIELD: StringName = &"E_MISSING_FIELD"
## Validator code (ADR-0002 closed set): a knob has the wrong type (not a
## whole number, not a bool, `keep_match_logs` not an object).
const E_SCHEMA: StringName = &"E_SCHEMA"
## Validator code: a whole-number knob lies outside [constant CONFIG_SAFE_RANGES].
const E_RANGE: StringName = &"E_RANGE"

## The log's lifecycle (GDD States and Transitions): `OPEN → SEALED`, or
## `OPEN → FAULTED → SEALED` on overflow (Story 007). Nothing returns to `OPEN`.
enum State { OPEN, FAULTED, SEALED }

## 2^63 as a float: a whole-number float at or beyond it does not fit an int64,
## so [method from_json] leaves it a float.
const _INT64_FLOAT_BOUND: float = 9223372036854775808.0

## The player's `side` value in match payloads (rng-event-log catalogue:
## `side` ∈ {player, boss}); [method reduce_to_summary] attributes damage and
## counts plays for this side only.
const _SIDE_PLAYER: String = "player"

## The type that seals a log of each scope (rule 15).
const _SEALING_TYPE: Dictionary[String, String] = {
	SCOPE_MATCH: "match_ended",
	SCOPE_RUN: "run_ended",
}

var _max_events: int
var _scope: String
var _meta: Dictionary
var _events: Array[Dictionary] = []
var _subscribers: Array[Callable] = []
var _turn: int = 0
var _state: State = State.OPEN
# Re-entrancy guard and delivery queue: events appended while subscribers are
# being notified wait here, so every subscriber still sees every event once,
# in `seq` order.
var _notifying: bool = false
var _pending: Array[Dictionary] = []


## A new, empty, open log. `max_events` is the F7 cap computed by the
## composition root (never read from config here); `scope` is
## [constant SCOPE_MATCH] or [constant SCOPE_RUN]; `meta` is
## `{engine_version, data_version, run_seed_hex, floor}` for the header.
## Example: `EventLog.new(EventLog.max_events_for(config), EventLog.SCOPE_MATCH, {"floor": 1})`.
func _init(max_events: int, scope: String, meta: Dictionary = {}) -> void:
	_max_events = max_events
	_scope = scope
	_meta = meta.duplicate(true)
	if not _SEALING_TYPE.has(scope):
		push_error("EventLog: unknown scope \"%s\" (expected \"%s\" or \"%s\")" % [scope, SCOPE_MATCH, SCOPE_RUN])


## Rule 13: appends one event and returns its `seq`; `-1` when the log is
## sealed (nothing stored, no subscriber notified; assert in debug, warning in
## release). `payload` is deep-copied with rule 14 coercion (see the class
## notes: a non-JSON value is reported, replaced and listed in `_coerced`);
## `cause_seq` is the `seq` of the event whose resolution emitted this one, 0
## for the direct result of a command.
## Appending the scope's sealing type (`match_ended` / `run_ended`) seals the
## log after this event. Overflow (rule 16, F7): an append to an Open log that
## already holds `max_events` events is dropped (`-1`, a pushed warning) and
## the log appends `log_overflow{cap, seq}` instead, enters Faulted and emits
## [signal overflowed]; a Faulted log accepts exactly one more event (Match
## Rules' `match_ended{result: fault, winner: null, reason: event_cap}`) and is
## then sealed. The log never appends a `match_ended` itself. A subscriber that appends re-enters: reported (assert
## in debug, warning in release), then accepted with the next `seq` and
## `payload._reentrant = true`, delivered after the event being delivered.
## Example: `var seq: int = log.append(&"minion_died", {"instance_id": 7}, 40)`.
func append(type: StringName, payload: Dictionary, cause_seq: int = 0) -> int:
	var type_name: String = String(type)
	if _state == State.SEALED:
		_caller_bug("EventLog.append: the log is sealed; '%s' dropped" % type_name)
		return -1
	if _state == State.OPEN and _events.size() >= _max_events:
		_overflow(type_name)
		return -1
	# Untyped on purpose: the list must compare equal to its JSON round trip.
	var coerced: Array = []
	var stored_payload: Dictionary = _json_copy(payload, "", coerced)
	if not coerced.is_empty():
		_caller_bug("EventLog.append: '%s' payload holds non-JSON values at %s" % [type_name, ", ".join(PackedStringArray(coerced))])
		stored_payload["_coerced"] = coerced
	if _notifying:
		_caller_bug("EventLog.append: re-entrant append of '%s' from a subscriber" % type_name)
		stored_payload["_reentrant"] = true
	var seq: int = _store(type_name, stored_payload, cause_seq)
	# Faulted accepts exactly one more event, whatever its type (ADR-0003 D8).
	if _state == State.FAULTED or type_name == _SEALING_TYPE.get(_scope, ""):
		_state = State.SEALED
	_deliver()
	return seq


## Rule 13 / match-rules C15: the turn stamped on every later append. Match
## Rules calls it immediately before appending `turn_started`; run logs leave
## it 0. Example: `log.set_turn(3)`.
func set_turn(turn: int) -> void:
	_turn = turn


## The turn the next append is stamped with (0 before the first
## [method set_turn]). Example: `log.current_turn()`.
func current_turn() -> int:
	return _turn


## Rule 13: registers `callback(event: Dictionary)`, called once per later
## event, in `seq` order, right after it is stored, on the appending thread.
## Registration only — delivery happens in [method append]. Callbacks run in
## registration order. Example: `log.subscribe(func(e: Dictionary) -> void: seen.append(e.seq))`.
func subscribe(callback: Callable) -> void:
	_subscribers.append(callback)


## Rule 13: every event whose `seq` is greater than `seq`, in order. `seq` at
## or past the last `seq` gives `[]`; a negative `seq` gives every event
## (Edge Cases: neither is an error). The events are the stored read-only
## Dictionaries. Example: `log.events_since(3)` after five appends → seq 4, 5.
func events_since(seq: int) -> Array[Dictionary]:
	# seq(n) = n (F7), so the slice starts at index max(seq, 0).
	return _events.slice(clampi(seq, 0, _events.size()))


## Number of events stored. Example: `log.size()`.
func size() -> int:
	return _events.size()


## True once the scope's sealing event was appended (rule 15).
## Example: `if log.is_sealed(): archive(log)`.
func is_sealed() -> bool:
	return _state == State.SEALED


## The lifecycle state ([enum State]). Example: `log.state() == EventLog.State.OPEN`.
func state() -> State:
	return _state


## [constant SCOPE_MATCH] or [constant SCOPE_RUN]. Example: `log.scope()`.
func scope() -> String:
	return _scope


## The cap this log was built with (F7). Example: `log.max_events()`.
func max_events() -> int:
	return _max_events


## Rule 13: the metadata block plus the full event array, as a writable deep
## copy: `{engine_version, data_version, run_seed_hex, scope, floor, events}`.
## A `meta` key the composition root did not supply is `""` (`floor`: 0).
## Example: `log.snapshot().events.size() == log.size()`.
func snapshot() -> Dictionary:
	var events: Array = []
	for event: Dictionary in _events:
		events.append(event.duplicate(true))
	return {
		"engine_version": String(_meta.get("engine_version", "")),
		"data_version": String(_meta.get("data_version", "")),
		"run_seed_hex": String(_meta.get("run_seed_hex", "")),
		"scope": _scope,
		"floor": int(_meta.get("floor", 0)),
		"events": events,
	}


## Rule 17: the log as tab-indented JSON text (`JSON.stringify(dict, "\t")`):
## `{log_schema_version, engine_version, data_version, run_seed_hex, scope,
## floor, events[]}`. Payloads are JSON-only by construction (append-time
## coercion), so this always succeeds. Compare logs with F6
## (`EventLogAssertions.canonical_json`), not by this text: its float
## formatting is the engine's, not F6's 6 decimals.
## Example: `var text: String = log.to_json()`.
func to_json() -> String:
	var header: Dictionary = snapshot()
	header["log_schema_version"] = LOG_SCHEMA_VERSION
	return JSON.stringify(header, "\t")


## Rules 18-19: the sealed match log reduced to its `match_summary` payload,
## `{floor, result, winner, reason, turns, event_count, cards_played,
## damage_by_card}` (the catalogue row). `result`, `winner`, `reason`, `turns`
## (and `floor`, else the header's) are copied from the `match_ended` payload
## (match-rules C14 `MatchResult`; a fault's `winner` is `null`);
## `event_count` is [method size]; `cards_played` counts the player's
## `card_played` events. `damage_by_card` (rule 19) sums `damage_dealt.dealt`
## — damage actually applied (match-rules C15), never `requested` — per
## `card_id`, over events whose `source` is a player-owned instance in the
## `instance_id → card_id` map built, in log order, from `minion_summoned`,
## `weapon_equipped` and `card_played` (`side == "player"`) and from
## `hero_power_used`, whose `power_id` is mapped under the player's hero
## instance (`match_started.hero_id`). A source with no entry (fatigue, a boss
## instance, an unknown id) attributes to nothing, silently. Reads only: the
## log is not changed and nothing is appended (Run Structure appends the
## summary to the run log). A log that is not a sealed match log is a caller
## bug: `push_error` and `{}` — never an assert on payload data.
## Example: `run_log.append(&"match_summary", match_log.reduce_to_summary())`.
func reduce_to_summary() -> Dictionary:
	var ended: Dictionary = {}
	if _scope == SCOPE_MATCH and is_sealed():
		for i: int in range(_events.size() - 1, -1, -1):
			if _events[i].type == _SEALING_TYPE[SCOPE_MATCH]:
				ended = _events[i].payload
				break
	if ended.is_empty():
		push_error("EventLog.reduce_to_summary: the match log is not sealed by match_ended")
		return {}
	var card_of: Dictionary = {}
	var player_hero: Variant = null
	var cards_played: int = 0
	var damage_by_card: Dictionary = {}
	for event: Dictionary in _events:
		var payload: Dictionary = event.payload
		var is_player: bool = payload.get("side") == _SIDE_PLAYER
		match event.type:
			"match_started":
				player_hero = _as_int(payload.get("hero_id"))
			"minion_summoned", "weapon_equipped", "card_played":
				var instance: Variant = _as_int(payload.get("instance_id"))
				if is_player and instance != null:
					card_of[instance] = payload.get("card_id")
				if is_player and event.type == "card_played":
					cards_played += 1
			"hero_power_used":
				if is_player and player_hero != null:
					card_of[player_hero] = payload.get("power_id")
			"damage_dealt":
				var source: Variant = _as_int(payload.get("source"))
				var dealt: Variant = _as_int(payload.get("dealt"))
				if source != null and dealt != null and card_of.has(source):
					var card_id: String = str(card_of[source])
					damage_by_card[card_id] = int(damage_by_card.get(card_id, 0)) + dealt
	return {
		"floor": ended.get("floor", _meta.get("floor", 0)),
		"result": ended.get("result"),
		"winner": ended.get("winner"),
		"reason": ended.get("reason"),
		"turns": ended.get("turns"),
		"event_count": _events.size(),
		"cards_played": cards_played,
		"damage_by_card": damage_by_card,
	}


## Rule 17: rebuilds a log from [method to_json] text, or returns `null` with
## a pushed error (never an assert) when `text` is not JSON (the message names
## the 1-based line), its top level is not an object, its
## `log_schema_version` is not [constant LOG_SCHEMA_VERSION], its `scope` is
## unknown, or an event is not a rule 11 envelope with `seq` = its position.
## Every integral number comes back as `int` (`seq`, `turn`, `cause_seq`,
## payload counts — JSON numbers parse as floats); the header's
## `engine_version`, `data_version`, `run_seed_hex` and `floor` become the
## rebuilt log's meta; the turn is the last event's; the log is sealed when its
## last event is the scope's sealing type. `max_events` caps further appends
## on an unsealed rebuilt log; 0 (default) takes the number of events read.
## Example: `var copy: EventLog = EventLog.from_json(log.to_json())`.
static func from_json(text: String, max_events: int = 0) -> EventLog:
	var parsed: Dictionary = JsonText.parse(text)
	if not parsed.ok:
		push_error("EventLog.from_json: line %d: %s" % [parsed.line, parsed.message])
		return null
	if typeof(parsed.data) != TYPE_DICTIONARY:
		push_error("EventLog.from_json: the top level is not an object")
		return null
	var header: Dictionary = _ints_from_json(parsed.data)
	var version: Variant = header.get("log_schema_version")
	if typeof(version) != TYPE_INT or version != LOG_SCHEMA_VERSION:
		push_error("EventLog.from_json: log_schema_version %s is not %d" % [str(version), LOG_SCHEMA_VERSION])
		return null
	var scope: Variant = header.get("scope")
	if typeof(scope) != TYPE_STRING or not _SEALING_TYPE.has(scope):
		push_error("EventLog.from_json: unknown scope %s" % str(scope))
		return null
	var raw_events: Variant = header.get("events")
	if typeof(raw_events) != TYPE_ARRAY:
		push_error("EventLog.from_json: `events` is not an array")
		return null
	var events: Array[Dictionary] = []
	for i: int in (raw_events as Array).size():
		var event: Variant = raw_events[i]
		if not _is_envelope(event, i + 1):
			push_error("EventLog.from_json: event at index %d is not a rule 11 envelope with seq %d" % [i, i + 1])
			return null
		events.append(event)
	var meta: Dictionary = {}
	for key: String in ["engine_version", "data_version", "run_seed_hex", "floor"]:
		if header.has(key):
			meta[key] = header[key]
	var log: EventLog = EventLog.new(max_events if max_events > 0 else events.size(), scope, meta)
	log._restore_events(events)
	return log


## F7: `max_match_events = floor(log_memory_budget_bytes / avg_event_bytes)`
## over the `rng_event_log` config body — the one place the composition root
## computes the cap it passes to [method _init] (10,000 at the shipped
## defaults, 2,500 at the minimum budget). Read once per log, never per
## append. A body without two positive whole-number knobs (one
## [method validate_config] would have rejected at load) pushes an error and
## returns 0: a log built with it faults on its first append — never a
## fallback cap. Example: `EventLog.new(EventLog.max_events_for(db.config("rng_event_log")), "match")`.
static func max_events_for(config: Dictionary) -> int:
	var budget: Variant = config.get("log_memory_budget_bytes")
	var average: Variant = config.get("avg_event_bytes")
	if not _is_whole_number(budget) or not _is_whole_number(average) or int(budget) <= 0 or int(average) <= 0:
		push_error("EventLog.max_events_for: log_memory_budget_bytes and avg_event_bytes must be positive whole numbers")
		return 0
	@warning_ignore("integer_division")
	return int(budget) / int(average)


## The `rng_event_log` config validator (card-database CR-5 stage 7a;
## ADR-0002 Decision 4: `call(body, db) -> Array`), registered by `Boot` as
## `configs.rng_event_log`. Static and pure: it reads `body` only (`_db` is
## the calling convention). Returns one error per problem in the
## `ValidationReport` entry shape `{severity, code, file, record_id, field,
## message}` (`file` [constant CONFIG_FILE], `record_id` `null`, `field` the
## key path); `[]` for a valid body. Never asserts, in any build:
## - a missing knob (or `keep_match_logs.debug` / `.release`) is [constant E_MISSING_FIELD];
## - a knob that is not a whole number, a `keep_match_logs` that is not an
##   object, or an entry in it that is not a bool is [constant E_SCHEMA];
## - a whole number outside its [constant CONFIG_SAFE_RANGES] row is [constant E_RANGE].
## [codeblock]
## EventLog.validate_config({"log_memory_budget_bytes": 100, "avg_event_bytes": 200,
##         "keep_match_logs": {"debug": true, "release": false}}, null)
## # [{code: &"E_RANGE", field: "log_memory_budget_bytes", …}]
## [/codeblock]
static func validate_config(body: Dictionary, _db: Variant) -> Array:
	var errors: Array[Dictionary] = []
	for key: String in CONFIG_SAFE_RANGES:
		if not body.has(key):
			errors.append(_config_error(E_MISSING_FIELD, key, "missing knob `%s` (rng-event-log Tuning Knobs)" % key))
			continue
		var raw: Variant = body[key]
		if not _is_whole_number(raw):
			errors.append(_config_error(E_SCHEMA, key, "`%s` must be a whole number, found %s (%s)" % [key, str(raw), type_string(typeof(raw))]))
			continue
		var bounds: Array = CONFIG_SAFE_RANGES[key]
		if int(raw) < int(bounds[0]) or int(raw) > int(bounds[1]):
			errors.append(_config_error(E_RANGE, key, "`%s` is %d, outside the safe range %d–%d" % [key, int(raw), int(bounds[0]), int(bounds[1])]))
	if not body.has("keep_match_logs"):
		errors.append(_config_error(E_MISSING_FIELD, "keep_match_logs", "missing knob `keep_match_logs` (rng-event-log Tuning Knobs)"))
	elif typeof(body.keep_match_logs) != TYPE_DICTIONARY:
		errors.append(_config_error(E_SCHEMA, "keep_match_logs", "`keep_match_logs` must be an object {debug: bool, release: bool}, found %s" % type_string(typeof(body.keep_match_logs))))
	else:
		var per_build: Dictionary = body.keep_match_logs
		for build: String in KEEP_MATCH_LOGS_KEYS:
			var field: String = "keep_match_logs.%s" % build
			if not per_build.has(build):
				errors.append(_config_error(E_MISSING_FIELD, field, "missing `%s`" % field))
			elif typeof(per_build[build]) != TYPE_BOOL:
				errors.append(_config_error(E_SCHEMA, field, "`%s` must be a bool, found %s (%s)" % [field, str(per_build[build]), type_string(typeof(per_build[build]))]))
	return errors


# Rule 16 / F7: the cap is reached. `dropped_type` is the append refused.
func _overflow(dropped_type: String) -> void:
	var seq: int = _events.size() + 1
	push_warning("EventLog.append: max_events %d reached; '%s' dropped, log_overflow appended at seq %d" % [_max_events, dropped_type, seq])
	_store("log_overflow", {"cap": _max_events, "seq": seq}, 0)
	_state = State.FAULTED
	_deliver()
	overflowed.emit(_max_events, seq)


# Installs events read by from_json and derives turn and state from them.
func _restore_events(events: Array[Dictionary]) -> void:
	for event: Dictionary in events:
		_freeze(event)
		_events.append(event)
		if event.type == "log_overflow":
			_state = State.FAULTED
	if _events.is_empty():
		return
	var last: Dictionary = _events.back()
	_turn = last.turn
	if last.type == _SEALING_TYPE[_scope] or (_state == State.FAULTED and last.type != "log_overflow"):
		_state = State.SEALED


# `value` as an int when it is a whole number (see _is_whole_number), else
# null — payload ids and amounts may arrive as JSON floats.
static func _as_int(value: Variant) -> Variant:
	return int(value) if _is_whole_number(value) else null


# Whether `value` is an int, or a finite float with no fractional part (JSON
# numbers arrive as floats).
static func _is_whole_number(value: Variant) -> bool:
	match typeof(value):
		TYPE_INT:
			return true
		TYPE_FLOAT:
			return is_finite(value) and value == floorf(value)
	return false


# One validate_config entry in the ValidationReport shape.
static func _config_error(code: StringName, field: String, message: String) -> Dictionary:
	return {
		"severity": ValidationReport.SEVERITY_ERROR,
		"code": code,
		"file": CONFIG_FILE,
		"record_id": null,
		"field": field,
		"message": message,
	}


# Whether `value` is a rule 11 envelope whose seq is `seq` (types as read
# back from JSON, after integral numbers became ints).
static func _is_envelope(value: Variant, seq: int) -> bool:
	if typeof(value) != TYPE_DICTIONARY or value.size() != ENVELOPE_KEYS.size():
		return false
	for key: String in ENVELOPE_KEYS:
		if not value.has(key):
			return false
	return typeof(value.seq) == TYPE_INT and value.seq == seq \
		and typeof(value.turn) == TYPE_INT \
		and typeof(value.type) == TYPE_STRING \
		and typeof(value.payload) == TYPE_DICTIONARY \
		and typeof(value.cause_seq) == TYPE_INT


# A rule 14 deep copy of `value`: StringName → String; every other non-JSON
# value (and any non-String key) is replaced and its path appended to
# `coerced`. `path` is the key path so far ("" at the payload's top level).
static func _json_copy(value: Variant, path: String, coerced: Array) -> Variant:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return value
		TYPE_STRING_NAME:
			return String(value)
		TYPE_ARRAY:
			var out: Array = []
			for i: int in (value as Array).size():
				out.append(_json_copy(value[i], "%s[%d]" % [path, i], coerced))
			return out
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			for key: Variant in value:
				var name: String
				match typeof(key):
					TYPE_STRING, TYPE_STRING_NAME:
						name = String(key)
					_:
						name = str(key)
						coerced.append("%s[key %s]" % [path, name])
				var child_path: String = name if path.is_empty() else "%s.%s" % [path, name]
				out[name] = _json_copy(value[key], child_path, coerced)
			return out
	coerced.append(path)
	return "<unserializable:%s>" % _class_name_of(value)


# The class name a coerced value is reported by: a script's global name, an
# Object's engine class, otherwise the Variant type name.
static func _class_name_of(value: Variant) -> String:
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		var script: Script = (value as Object).get_script()
		if script != null and not script.get_global_name().is_empty():
			return script.get_global_name()
		return (value as Object).get_class()
	return type_string(typeof(value))


# `value` read back from JSON with every whole-number float turned into an
# int (JSON numbers are doubles; the log's numbers are ints by design).
static func _ints_from_json(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			if is_finite(value) and value == floorf(value) and absf(value) < _INT64_FLOAT_BOUND:
				return int(value)
			return value
		TYPE_ARRAY:
			var out: Array = []
			for item: Variant in value:
				out.append(_ints_from_json(item))
			return out
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			for key: Variant in value:
				out[key] = _ints_from_json(value[key])
			return out
	return value


# Stamps, freezes and stores one event, and queues it for delivery.
func _store(type_name: String, payload: Dictionary, cause_seq: int) -> int:
	var seq: int = _events.size() + 1
	var event: Dictionary = {
		"seq": seq,
		"turn": _turn,
		"type": type_name,
		"payload": payload,
		"cause_seq": cause_seq,
	}
	_freeze(event)
	_events.append(event)
	_pending.append(event)
	return seq


# Notifies every subscriber of every queued event, in seq order. A nested
# append only queues its event; the outermost call drains the queue.
func _deliver() -> void:
	if _notifying:
		return
	_notifying = true
	var i: int = 0
	while i < _pending.size():
		var event: Dictionary = _pending[i]
		for callback: Callable in _subscribers:
			callback.call(event)
		i += 1
	_pending.clear()
	_notifying = false


# Makes `value` and every container inside it read-only.
static func _freeze(value: Variant) -> void:
	match typeof(value):
		TYPE_DICTIONARY:
			for key: Variant in value:
				_freeze(value[key])
			(value as Dictionary).make_read_only()
		TYPE_ARRAY:
			for item: Variant in value:
				_freeze(item)
			(value as Array).make_read_only()


# A caller bug: asserts in debug builds (the assert aborts only this function,
# so the caller still takes its release path), warns in release.
func _caller_bug(message: String) -> void:
	assert(false, message)
	push_warning(message)
