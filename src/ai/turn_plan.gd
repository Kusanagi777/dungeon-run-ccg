## One boss turn as plain data (ADR-0006 Key Interfaces; design/gdd/boss-ai.md
## C2, C9; rng-event-log rule 14; boss-ai-match-driver story 008).
##
## `BossAI.plan_turn` fills it on a sandbox and hands it back through the
## [PlannerTask]: the commands the sandbox accepted, the diagnostics raised while
## planning, a checksum of the sandbox's scratch-log event types, the `ai_<floor>`
## draws the turn took and its mode transitions. The driver replays it on the
## main thread: for each command index it appends the diagnostics routed there
## ([constant COMMAND_INDEX_KEY]; a rejected decision or an abort has no command
## of its own, so it rides on the next one), submits the command, and compares
## [method checksum] of what the live log gained with [member expected_checksum].
## The first diagnostic is `ai_intent_committed` (C2, C8.2), which rule 12a does not
## flag: it is an intent event, routed here like the others and left out of the
## checksum by type ([constant INTENT_EVENTS]).
## Diagnostics past the last command (`command_index == commands.size()`) follow
## it. Nothing here references an engine, a log or a stream.
## [codeblock]
## for index: int in plan.commands.size():
##     for diagnostic: Dictionary in plan.diagnostics_before(index):
##         log.append(diagnostic[TurnPlan.EVENT_KEY], TurnPlan.event_payload(diagnostic), 0)
##     engine.submit(plan.commands[index])
## [/codeblock]
class_name TurnPlan
extends RefCounted

## The diagnostic key naming the event to append (`ai_intent_committed`,
## `ai_decision`, `ai_plan_aborted`, `ai_fault`; rng-event-log rule 12a, §D).
const EVENT_KEY: String = "event"
## The diagnostic key holding the index in [member commands] it is appended
## before.
const COMMAND_INDEX_KEY: String = "command_index"
## The payload flag rule 12a sets on every diagnostic, which no checksum counts.
const DIAGNOSTIC_KEY: String = "diagnostic"
## The intent events: the live log holds them and a sandbox's never does, and they
## are not diagnostics (rule 12a), so [method checksum] skips them by type.
const INTENT_EVENTS: Array[String] = ["ai_intent_shown", "ai_intent_committed"]
## Separates the event types [method checksum] hashes.
const TYPE_SEPARATOR: String = "\n"

## The commands the sandbox accepted, in order; each is replayed as it stands.
var commands: Array = []
## Event payloads, each carrying [constant EVENT_KEY] and
## [constant COMMAND_INDEX_KEY], in the order they were raised: the intent first,
## then those with `diagnostic: true`.
var diagnostics: Array[Dictionary] = []
## [method checksum] of the sandbox's scratch log over the turn.
var expected_checksum: int = 0
## `ai_<floor>` draws this turn: tie-set draws + new fork labels (F8, C9).
var ai_draws: int = 0
## The modes entered this turn, in order, from `NORMAL` (ai-code "log every
## transition").
var mode_trace: Array[StringName] = []
## One row per action the sandbox accepted, `end_turn` and `choose` aside: `{key,
## target_id, face, score, lethal}`, what [method BossAI.intent_from_plan] folds.
## `face` counts attackers that existed when the plan began; `score` is `-INF` for
## an unscored step, so this stays out of [method to_dict].
var intent_rows: Array[Dictionary] = []


## Every diagnostic routed before the command at [param index], in order.
## [codeblock]
## plan.diagnostics_before(plan.commands.size())   # those after the last command
## [/codeblock]
func diagnostics_before(index: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for diagnostic: Dictionary in diagnostics:
		if int(diagnostic[COMMAND_INDEX_KEY]) == index:
			out.append(diagnostic)
	return out


## This plan as rule 14 data: a deep copy, `mode_trace` as Strings.
## [codeblock]
## GameAssertions.assert_json_representable(plan.to_dict())
## [/codeblock]
func to_dict() -> Dictionary:
	var trace: Array = []
	for mode: StringName in mode_trace:
		trace.append(String(mode))
	return {
		"commands": commands.duplicate(true),
		"diagnostics": diagnostics.duplicate(true),
		"expected_checksum": expected_checksum,
		"ai_draws": ai_draws,
		"mode_trace": trace,
	}


## The event payload of [param diagnostic]: a copy without the two routing keys.
static func event_payload(diagnostic: Dictionary) -> Dictionary:
	var payload: Dictionary = diagnostic.duplicate(true)
	@warning_ignore("return_value_discarded")
	payload.erase(EVENT_KEY)
	@warning_ignore("return_value_discarded")
	payload.erase(COMMAND_INDEX_KEY)
	return payload


## FNV-1a (rng-event-log F2, signed int64) over the types of [param events]
## (log envelopes, in order), skipping every diagnostic and [constant INTENT_EVENTS]:
## the live log carries the replayed `ai_decision`s and the intent, the sandbox log
## any `command_rejected`, and none of them is game state. The one implementation both sides of a replay share (story 015).
## [codeblock]
## var drift: bool = TurnPlan.checksum(log.events_since(seq)) != plan.expected_checksum
## [/codeblock]
static func checksum(events: Array) -> int:
	var types: PackedStringArray = PackedStringArray()
	for event: Dictionary in events:
		var payload: Dictionary = event.get("payload", {})
		if not bool(payload.get(DIAGNOSTIC_KEY, false)) and not INTENT_EVENTS.has(str(event.type)):
			types.append(str(event.type))
	return RngService.fnv1a64(TYPE_SEPARATOR.join(types).to_utf8_buffer())
