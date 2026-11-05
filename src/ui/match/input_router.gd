## Mouse and keyboard to intent to command (match-ui U1, U5; ADR-0009 Key Interfaces).
## Any (state, input) pair not listed in match-ui States is ignored, never forwarded.
##
## **The lock** (U6.1, U6.5, States `BossTurn`) is derived and never stored: the view
## says whose turn the events have reached, and the queue says whether the boss turn
## has finished playing. So it holds from `turn_started{side: boss}` until
## `turn_started{side: player}` has drained, though the view runs ahead of the screen.
##
## **A Choice the player owes** comes first, whoever's turn it is (States `ChoiceOpen`,
## "any state except `Ended`"): the boss waits on the pick, so the lock lifts, and only
## `choose` joins what a locked player can do.
##
## **Q-5.** `legal_commands()` lists the boss's commands on the boss's turn, so
## [method player_commands] filters to `issuer == player` here, in the UI layer.
## [codeblock]
## router.bind(view_state, queue)
## router.set_controller(controller)
## router.command_requested.connect(_on_command)
## end_turn_button.disabled = not router.can_end_turn()
## router.intent(&"end_turn")
## [/codeblock]
class_name InputRouter
extends Node

## The player asked for [param command]; `MatchView` forwards it to `MatchController.submit`.
signal command_requested(command: Dictionary)

## The view states of match-ui States this router can be in.
const STATE_LOADING: StringName = &"Loading"
const STATE_MULLIGAN: StringName = &"Mulligan"
const STATE_IDLE: StringName = &"Idle"
const STATE_PLAYBACK: StringName = &"Playback"
const STATE_BOSS_TURN: StringName = &"BossTurn"
const STATE_CHOICE_OPEN: StringName = &"ChoiceOpen"
const STATE_ENDED: StringName = &"Ended"
const PHASE_MAIN: String = "main"
const INTENT_END_TURN: StringName = &"end_turn"
const INTENT_SKIP: StringName = &"skip"
## What a locked player can still do (story AC, States `BossTurn`). `menu` is the pause
## menu, which holds concede and settings, U6.1's other two.
const LOCKED_INTENTS: Array[StringName] = [&"skip", &"menu", &"feed"]
## The one intent a player's open Choice adds to them.
const CHOICE_INTENT: StringName = &"choose"

var _view: MatchViewState = null
var _queue: AnimationQueue = null
var _controller: MatchController = null


## Gives the router the [param view_state] and [param queue] it reads.
func bind(view_state: MatchViewState, queue: AnimationQueue) -> void:
	_view = view_state
	_queue = queue


## Gives the router the [param controller] it reads legality from.
func set_controller(controller: MatchController) -> void:
	_controller = controller


## True during the boss's turn and until its playback has drained, unless the player
## owes a Choice.
func controls_locked() -> bool:
	if _player_owes_choice():
		return false
	return _view.active_side == MatchViewState.SIDE_BOSS or _queue.boss_turn_active()


## True when [param intent] may be acted on now.
func allows(intent_name: StringName) -> bool:
	if _player_owes_choice():
		return intent_name == CHOICE_INTENT or LOCKED_INTENTS.has(intent_name)
	return not controls_locked() or LOCKED_INTENTS.has(intent_name)


## The view state now (match-ui States), derived, never stored.
func view_state() -> StringName:
	if _view == null or _controller == null:
		return STATE_LOADING
	if _view.result != null and _queue.is_idle():
		return STATE_ENDED
	if _view.pending_mulligan != null:
		return STATE_MULLIGAN
	if _player_owes_choice():
		return STATE_CHOICE_OPEN
	if controls_locked():
		return STATE_BOSS_TURN
	if not _queue.is_idle() or _view.result != null:
		return STATE_PLAYBACK
	if _view.phase == PHASE_MAIN and _view.active_side == MatchViewState.SIDE_PLAYER:
		return STATE_IDLE
	return STATE_PLAYBACK


## U5: End Turn is enabled only in `PlayerTurn.Main` with the queue idle and no overlay.
func can_end_turn() -> bool:
	return view_state() == STATE_IDLE


## The commands of `legal_commands()` the player may issue (Q-5), in engine order.
func player_commands() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _controller == null:
		return out
	for command: Dictionary in _controller.legal_commands():
		if str(command.get("issuer", "")) == MatchViewState.SIDE_PLAYER:
			out.append(command)
	return out


## Takes one intent. [param args] depends on the intent; an intent the current state
## does not list is ignored.
## [codeblock]
## router.intent(&"end_turn")
## [/codeblock]
func intent(intent_name: StringName, _args: Dictionary = {}) -> void:
	match intent_name:
		INTENT_END_TURN:
			if can_end_turn():
				command_requested.emit(MatchRecords.end_turn(MatchViewState.SIDE_PLAYER))
		INTENT_SKIP:
			if allows(INTENT_SKIP) and not _queue.is_idle():
				_queue.skip_all()


func _player_owes_choice() -> bool:
	return _view.pending_choice != null and str(_view.pending_choice.side) == MatchViewState.SIDE_PLAYER
