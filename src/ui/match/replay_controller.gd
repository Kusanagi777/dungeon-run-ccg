## A [MatchController] with no driver (architecture.md "Can defer"; rng-event-log rule 17):
## it hands a finished log to `MatchView` through the same channel a live match uses, so
## the existing projection, queue and presenters play it. No rules engine runs and no
## input reaches anything: [method submit] refuses, and `is_read_only` tells the view.
##
## Events are released from [method tick], only while the queue is idle, in the bursts a
## live match delivers them: one command group at a time, and a boss turn whole, so
## death groups, coalescing and F4 see what they would have seen.
## [codeblock]
## var controller := ReplayController.new(EventLog.from_json(text), db)
## view.set_controller(controller)
## [/codeblock]
class_name ReplayController
extends MatchController

## The `rejection.code` of every [method submit].
const CODE_READ_ONLY: String = "REPLAY_READ_ONLY"
const EVENT_TURN_STARTED: String = "turn_started"

var _events: Array[Dictionary] = []
var _cursor: int = 0
var _subscriber: Callable = Callable()
var _replay_query: ReplayQuery = null
# seq → the seq of its command root, as MatchViewState walks it.
var _roots: Dictionary = {}


## A replay of [param log]; [param db] answers card text.
func _init(log: EventLog, db: CardDatabase) -> void:
	super(null)
	_events = log.events_since(0)
	_replay_query = ReplayQuery.new(db)


func is_read_only() -> bool:
	return true


func bind_view(view_state: MatchViewState) -> void:
	_replay_query.bind_view(view_state)


## True once every event has been released.
func finished() -> bool:
	return _cursor >= _events.size()


## Refused, always. The queue is left alone: nothing is being played by hand.
func submit(_command: Dictionary) -> Dictionary:
	return {"accepted": false, "rejection": {"code": CODE_READ_ONLY}}


func legal_commands() -> Array:
	return []


func query() -> MatchQuery:
	return _replay_query


func subscribe(callback: Callable) -> void:
	_subscriber = callback


## Nothing up front: the view starts on an empty table and [method tick] plays the log.
func events_since(_seq: int) -> Array:
	return []


func tick() -> void:
	if _queue == null or not _subscriber.is_valid():
		return
	while not finished() and _queue.is_idle():
		_release_burst()


func on_setting_changed(_key: StringName, _value: Variant) -> void:
	return


func shutdown() -> void:
	return


func is_planning() -> bool:
	return false


## One command group, or from `turn_started{boss}` up to the player's next turn.
func _release_burst() -> void:
	var first: Dictionary = _events[_cursor]
	var boss_turn: bool = _is_turn_of(first, MatchViewState.SIDE_BOSS)
	var root: int = _root_of(first)
	_release(first)
	while not finished():
		var next: Dictionary = _events[_cursor]
		var ends: bool = _is_turn_of(next, MatchViewState.SIDE_PLAYER) if boss_turn else _root_of(next) != root
		if ends:
			return
		_release(next)


func _release(event: Dictionary) -> void:
	_cursor += 1
	_subscriber.call(event)


func _root_of(event: Dictionary) -> int:
	var seq: int = int(event.seq)
	var cause: int = int(event.cause_seq)
	var root: int = seq if cause == 0 else int(_roots.get(cause, cause))
	_roots[seq] = root
	return root


static func _is_turn_of(event: Dictionary, side: String) -> bool:
	return str(event.type) == EVENT_TURN_STARTED and str((event.payload as Dictionary).get("side", "")) == side
