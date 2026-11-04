## `EffectRuntime` — the Card Effects runtime state of one match
## (design/gdd/card-effects.md C6.8, C8.1; ADR-0007 Decision 1 and Key
## Interfaces): `{once_marks, counters, per_turn, pending_choice}`.
##
## The data lives in `MatchState.effects`; the code that reads and writes it
## lives in `EffectResolver`. It is plain data — Dictionaries, Arrays, ints,
## floats, bools, Strings and null — and never holds a Callable, a Node or any
## object reference, so `clone()` copies it by value with `duplicate(true)`
## and it passes `GameAssertions.assert_json_representable` (rng-event-log
## rule 14). Keys inside it are Strings (`counters` is keyed by
## `str(entity_id)`; int keys are not JSON-representable — DSL spike finding 10).
##
## A factory and a shape check, not a class with instances:
## `MatchState.make_effect_runtime()` (match-rules) builds the same empty
## record at C3 step 1, and the unit suite pins the two together.
## - `once_marks`: `once_per_turn` marks, `effect_id:source_id:turn → true`
##   ([method once_key]; C6.7, story 009). No reset: the turn moves on.
## - `counters`: `str(entity_id) → {key: int}` (C5 `add_counter` / `set_counter`;
##   story 009): [method counter], [method write_counter]. A bucket lives as
##   long as its `entity_id`, so a replayed minion starts at 0.
## - `per_turn`: per-turn tallies, `side → {key → int}` (C4, C6.8; story
##   007): `cards_played_this_turn`, `spells_cast_this_turn`,
##   `minions_died_this_turn`, kept by the resolver from the trigger points
##   it sees ([method bump]) and dropped at that side's Start step
##   ([method reset_turn]); an absent key reads 0 ([method tally]).
## - `pending_choice`: null, or the Discover / Choose One continuation (C8.1).
## [codeblock]
## var runtime: Dictionary = EffectRuntime.make()
## assert(EffectRuntime.is_runtime(engine.state().effects))
## [/codeblock]
class_name EffectRuntime
extends RefCounted

## The record's keys, exactly these (ADR-0007 Key Interfaces).
const FIELDS: Array[String] = ["once_marks", "counters", "per_turn", "pending_choice"]


## An empty runtime: three empty Dictionaries and no pending choice.
## Example: `state.effects = EffectRuntime.make()` (a fixture state).
static func make() -> Dictionary:
	return {"once_marks": {}, "counters": {}, "per_turn": {}, "pending_choice": null}


## True when [param value] is an `EffectRuntime`: a Dictionary with exactly
## [constant FIELDS], `once_marks` / `counters` / `per_turn` Dictionaries, and
## nothing but plain data anywhere inside (no Object, Callable, Signal, RID or
## other engine type, no non-String key). Text is `String` only: a
## `StringName` value or key does not survive JSON (it reads back as a
## `String`), so it is not plain data here (code review 2026-11-03).
## Example: `assert(EffectRuntime.is_runtime(clone.state().effects))`.
static func is_runtime(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var record: Dictionary = value
	if record.size() != FIELDS.size():
		return false
	for field: String in FIELDS:
		if not record.has(field):
			return false
	for field: String in ["once_marks", "counters", "per_turn"]:
		if not record[field] is Dictionary:
			return false
	return _is_plain(record)


## [param side]'s per-turn tally [param key] in [param runtime] (0 when
## never bumped this turn). Example: `EffectRuntime.tally(state.effects, "player", "cards_played_this_turn")`.
static func tally(runtime: Dictionary, side: String, key: String) -> int:
	var bucket: Variant = (runtime.per_turn as Dictionary).get(side)
	return int((bucket as Dictionary).get(key, 0)) if bucket is Dictionary else 0


## Adds 1 to [param side]'s tally [param key] — the resolver's own data
## (ADR-0007 Decision 5's exception; a tally is derivable from the log and
## emits nothing). Example: `EffectRuntime.bump(state.effects, "boss", "minions_died_this_turn")`.
static func bump(runtime: Dictionary, side: String, key: String) -> void:
	var per_turn: Dictionary = runtime.per_turn
	if not per_turn.get(side) is Dictionary:
		per_turn[side] = {}
	var bucket: Dictionary = per_turn[side]
	bucket[key] = int(bucket.get(key, 0)) + 1


## Drops every tally of [param side] (its Start step, C4).
## Example: `EffectRuntime.reset_turn(state.effects, "player")`.
static func reset_turn(runtime: Dictionary, side: String) -> void:
	(runtime.per_turn as Dictionary).erase(side)


## The `once_per_turn` mark key of effect [param effect_id] on source
## [param source_id] in [param turn] (C6.7: `effect_id:source_id:turn`; a
## treasure or passive id is the source of a hook host, story 015). A mark
## needs no reset: the next turn's key is another key.
## Example: `EffectRuntime.once_key("row_11.0", 12, 3) == "row_11.0:12:3"`.
static func once_key(effect_id: String, source_id: Variant, turn: int) -> String:
	return "%s:%s:%d" % [effect_id, str(source_id), turn]


## True when [param key] ([method once_key]) is marked in [param runtime].
## Example: `EffectRuntime.once_marked(state.effects, key)`.
static func once_marked(runtime: Dictionary, key: String) -> bool:
	return (runtime.once_marks as Dictionary).has(key)


## Sets the mark [param key] — the resolver's own data; a mark is derivable
## from the log and emits nothing (ADR-0007 Decision 5's exception).
## Example: `EffectRuntime.mark_once(state.effects, key)`.
static func mark_once(runtime: Dictionary, key: String) -> void:
	(runtime.once_marks as Dictionary)[key] = true


## The live counter [param key] of [param source_id] in [param runtime]: 0 when
## never set (C5). Example: `EffectRuntime.counter(state.effects, 12, "seen")`.
static func counter(runtime: Dictionary, source_id: Variant, key: String) -> int:
	return int(counters_of(runtime, source_id).get(key, 0))


## A value copy of [param source_id]'s counters (`{}` when it has none): what a
## raise-time snapshot stores (C6.5).
## Example: `EffectRuntime.counters_of(state.effects, 12)`.
static func counters_of(runtime: Dictionary, source_id: Variant) -> Dictionary:
	var bucket: Variant = (runtime.counters as Dictionary).get(str(source_id))
	return (bucket as Dictionary).duplicate() if bucket is Dictionary else {}


## Sets [param source_id]'s counter [param key] to [param value]. The op
## handlers call this, then emit `counter_changed` (C5, ADR-0007 Decision 5).
## Example: `EffectRuntime.write_counter(state.effects, 12, "seen", 3)`.
static func write_counter(runtime: Dictionary, source_id: Variant, key: String, value: int) -> void:
	var counters: Dictionary = runtime.counters
	var bucket_key: String = str(source_id)
	if not counters.get(bucket_key) is Dictionary:
		counters[bucket_key] = {}
	(counters[bucket_key] as Dictionary)[key] = value


static func _is_plain(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return true
		TYPE_ARRAY:
			for item: Variant in value:
				if not _is_plain(item):
					return false
			return true
		TYPE_DICTIONARY:
			for key: Variant in value:
				if typeof(key) != TYPE_STRING:
					return false
				if not _is_plain(value[key]):
					return false
			return true
	return false
