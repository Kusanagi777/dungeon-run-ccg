## Mouse and keyboard to intent to command (match-ui U1, U5; ADR-0009 Key Interfaces).
## This file holds the part `match-ui/story-010` needs: whether the player's controls
## are locked. Story 004 builds the rest of the router around it, and story 015
## renders the lock.
##
## **The lock** (U6.1, U6.5, States `BossTurn`) is derived and never stored: the view
## says whose turn the events have reached, and the queue says whether the boss turn
## has finished playing. So it holds from `turn_started{side: boss}` until
## `turn_started{side: player}` has drained, though the view runs ahead of the screen.
##
## **A Choice the player owes** comes first, whoever's turn it is (States `ChoiceOpen`,
## "any state except `Ended`"): the boss waits on the pick, so the lock lifts, and only
## `choose` joins what a locked player can do.
## [codeblock]
## router.bind(view_state, queue)
## end_turn_button.disabled = router.controls_locked()
## if router.allows(&"skip"): queue.skip_all()
## [/codeblock]
class_name InputRouter
extends Node

## What a locked player can still do (story AC, States `BossTurn`). `menu` is the pause
## menu, which holds concede and settings, U6.1's other two.
const LOCKED_INTENTS: Array[StringName] = [&"skip", &"menu", &"feed"]
## The one intent a player's open Choice adds to them.
const CHOICE_INTENT: StringName = &"choose"

var _view: MatchViewState = null
var _queue: AnimationQueue = null


## Gives the router the [param view_state] and [param queue] it reads.
func bind(view_state: MatchViewState, queue: AnimationQueue) -> void:
	_view = view_state
	_queue = queue


## True during the boss's turn and until its playback has drained, unless the player
## owes a Choice.
func controls_locked() -> bool:
	if _player_owes_choice():
		return false
	return _view.active_side == MatchViewState.SIDE_BOSS or _queue.boss_turn_active()


## True when [param intent] may be acted on now.
func allows(intent: StringName) -> bool:
	if _player_owes_choice():
		return intent == CHOICE_INTENT or LOCKED_INTENTS.has(intent)
	return not controls_locked() or LOCKED_INTENTS.has(intent)


func _player_owes_choice() -> bool:
	return _view.pending_choice != null and str(_view.pending_choice.side) == MatchViewState.SIDE_PLAYER
