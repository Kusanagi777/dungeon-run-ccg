## The UI's one way into a match (match-ui U1, U2, U4.7; ADR-0008 Key Interfaces,
## ADR-0001 three channels). It wraps the [MatchDriver] that Run Structure owns and
## passes every call through: it builds nothing, holds no match state and answers
## nothing of its own. Commands go in through [method submit], events come out
## through [method subscribe] and [method events_since], and reads go through
## [method query].
##
## The one thing it adds is U4.7: a command flushes the queue first, so the engine
## never receives a command built against a stale display. The queue it flushes is
## the `AnimationQueue` that `MatchView` hands it with [method bind_queue]; until
## then there is no display to flush.
## [codeblock]
## var controller := MatchController.new(driver)
## controller.bind_queue(queue)
## for event: Dictionary in controller.events_since(0):
##     project(event)
## controller.subscribe(project)
## var result: Dictionary = controller.submit(MatchRecords.end_turn("player"))
## # MatchView._process(delta):
## controller.tick()
## [/codeblock]
class_name MatchController
extends RefCounted

var _driver: MatchDriver
var _queue: AnimationQueue = null


## Wraps [param driver], which it does not own.
func _init(driver: MatchDriver) -> void:
	_driver = driver


## The queue [method submit] flushes (U4.7); `MatchView` owns it.
func bind_queue(queue: AnimationQueue) -> void:
	_queue = queue


## U4.7, then the channel in: `skip_all()` runs every pending `apply_final`, and only
## then does [param command] reach the driver. Answers the driver's `CommandResult`,
## unchanged. Synchronous: no `await` anywhere in this class.
## [codeblock]
## var result: Dictionary = controller.submit(MatchRecords.play_card("player", 0, 2))
## if not result.accepted: shake(result.rejection.code)
## [/codeblock]
func submit(command: Dictionary) -> Dictionary:
	if _queue != null:
		_queue.skip_all()
	return _driver.submit(command)


## The commands the live engine would accept now.
func legal_commands() -> Array:
	return _driver.legal_commands()


## The read model; every answer of it is a value copy.
func query() -> MatchQuery:
	return _driver.query()


## Registers [param callback] for every event, once each, in `seq` order.
func subscribe(callback: Callable) -> void:
	_driver.subscribe(callback)


## Every event after [param seq]: a fresh view projects `events_since(0)` first.
func events_since(seq: int) -> Array:
	return _driver.events_since(seq)


## Once per frame from `MatchView._process`.
func tick() -> void:
	_driver.tick()


## A setting moved (`SettingsBus.settings_changed`). The driver takes the keys it
## knows, `telegraph_mode` today, and ignores the rest. A dynamic call because the
## method arrives with `boss-ai-match-driver/story-014`.
func on_setting_changed(key: StringName, value: Variant) -> void:
	_driver.call(&"on_setting_changed", key, value)


## `MatchView._exit_tree`: ends the driver's use of the planner.
func shutdown() -> void:
	_driver.shutdown()


## True while the boss plans or a plan replays: a UI hint, not a lock.
func is_planning() -> bool:
	return _driver.is_planning()
