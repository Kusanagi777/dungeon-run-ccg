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
##
## **A drag** opens a session on `drag_start`: legality is read from `legal_commands()`
## once, there, and the phase comes from those entries alone (targeting.md §6):
## targets → `T`, positions → `P`, neither → `C`. A minion with a targeted Battlecry
## is story 017's Phase P → T; here it plays as `T` at the row's end, so it stays
## playable. `drag_release` follows the §7.4 table; a cancel never calls the engine.
## An untargeted hero power is a Phase `C` source like a spell (MUI-025): drag is its
## only cast until story 017, and a click plays nothing (DD-X34).
## [codeblock]
## router.intent(&"drag_start", {"source": {"kind": "card", "id": 12}, "pos": press})
## router.intent(&"drag_move", {"pos": mouse})
## router.intent(&"drag_release", {"pos": mouse})
## [/codeblock]
class_name InputRouter
extends Node

## The player asked for [param command]; `MatchView` forwards it to `MatchController.submit`.
signal command_requested(command: Dictionary)
## A drag session opened: `{source{kind, id}, phase, entries, positions, targets, gap,
## hovered, pos}`.
signal session_started(session: Dictionary)
## The pointer moved in a session; [param session] holds the new `pos`, `gap`, `hovered`.
signal session_moved(session: Dictionary)
## The session ended; [param submitted] is true when a command follows.
signal session_ended(session: Dictionary, submitted: bool)

## The view states of match-ui States this router can be in.
const STATE_LOADING: StringName = &"Loading"
const STATE_MULLIGAN: StringName = &"Mulligan"
const STATE_IDLE: StringName = &"Idle"
const STATE_DRAGGING: StringName = &"Dragging"
const STATE_PLAYBACK: StringName = &"Playback"
const STATE_BOSS_TURN: StringName = &"BossTurn"
const STATE_CHOICE_OPEN: StringName = &"ChoiceOpen"
const STATE_ENDED: StringName = &"Ended"
const PHASE_MAIN: String = "main"
const INTENT_END_TURN: StringName = &"end_turn"
const INTENT_SKIP: StringName = &"skip"
const INTENT_DRAG_START: StringName = &"drag_start"
const INTENT_DRAG_MOVE: StringName = &"drag_move"
const INTENT_DRAG_RELEASE: StringName = &"drag_release"
const INTENT_CANCEL: StringName = &"cancel"
const INTENT_MULLIGAN_CONFIRM: StringName = &"mulligan_confirm"
## `source.kind` values.
const SOURCE_CARD: String = "card"
const SOURCE_ATTACKER: String = "attacker"
const SOURCE_HERO_POWER: String = "hero_power"
## targeting.md §6 phases.
const SESSION_POSITION: StringName = &"P"
const SESSION_TARGET: StringName = &"T"
const SESSION_CAST: StringName = &"C"
const NO_GAP: int = -1
const NO_TARGET: int = -1
const DEFAULT_CLICK_DRAG_PX: float = 8.0
## What a locked player can still do (story AC, States `BossTurn`). `menu` is the pause
## menu, which holds concede and settings, U6.1's other two.
const LOCKED_INTENTS: Array[StringName] = [&"skip", &"menu", &"feed"]
## The one intent a player's open Choice adds to them.
const CHOICE_INTENT: StringName = &"choose"

var _view: MatchViewState = null
var _queue: AnimationQueue = null
var _controller: MatchController = null
var _hit: MatchHitTest = null
var _click_drag_px: float = DEFAULT_CLICK_DRAG_PX
# The open drag session; empty in every other state.
var _session: Dictionary = {}
# The source under the last press, until it becomes a drag or is released.
var _press_source: Dictionary = {}
var _press_pos: Vector2 = Vector2.ZERO


## Gives the router the [param view_state] and [param queue] it reads.
func bind(view_state: MatchViewState, queue: AnimationQueue) -> void:
	_view = view_state
	_queue = queue


## Gives the router the [param controller] it reads legality from.
func set_controller(controller: MatchController) -> void:
	_controller = controller


## Gives the router what a raw mouse event needs: [param hit] answers for pixels, and
## [param click_drag_px] is `CLICK_DRAG_PX`.
func set_hit_test(hit: MatchHitTest, click_drag_px: float) -> void:
	_hit = hit
	_click_drag_px = click_drag_px


## True while a drag session is open.
func in_session() -> bool:
	return not _session.is_empty()


## The open session, or `{}`.
func session() -> Dictionary:
	return _session


## Turns a raw event into intents: mouse by type, never by `device` (4.7).
func handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_on_mouse_button(event)
	elif event is InputEventMouseMotion:
		_on_mouse_motion(event)
	elif event is InputEventKey:
		_on_key(event)


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
	if in_session():
		return STATE_DRAGGING
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
func intent(intent_name: StringName, args: Dictionary = {}) -> void:
	match intent_name:
		INTENT_DRAG_START:
			_drag_start(args.get("source", {}), args.get("pos", Vector2.ZERO))
		INTENT_DRAG_MOVE:
			_drag_move(args.get("pos", Vector2.ZERO))
		INTENT_DRAG_RELEASE:
			_drag_release(args.get("pos", Vector2.ZERO))
		INTENT_CANCEL:
			_end_session(false)
		INTENT_MULLIGAN_CONFIRM:
			if view_state() == STATE_MULLIGAN:
				command_requested.emit(MatchRecords.mulligan(args.get("keep_mask", [])))
		INTENT_END_TURN:
			if can_end_turn():
				command_requested.emit(MatchRecords.end_turn(MatchViewState.SIDE_PLAYER))
		INTENT_SKIP:
			if allows(INTENT_SKIP) and not _queue.is_idle():
				_queue.skip_all()


func _on_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		intent(INTENT_CANCEL)
	elif event.button_index != MOUSE_BUTTON_LEFT:
		return
	elif event.pressed:
		intent(INTENT_SKIP)
		_press_pos = event.position
		_press_source = _hit.source_at(event.position) if view_state() == STATE_IDLE else {}
	else:
		_press_source = {}
		if in_session():
			intent(INTENT_DRAG_RELEASE, {"pos": event.position})


func _on_mouse_motion(event: InputEventMouseMotion) -> void:
	if in_session():
		intent(INTENT_DRAG_MOVE, {"pos": event.position})
	elif not _press_source.is_empty() and event.position.distance_to(_press_pos) > _click_drag_px:
		var source: Dictionary = _press_source
		_press_source = {}
		intent(INTENT_DRAG_START, {"source": source, "pos": event.position})


func _on_key(event: InputEventKey) -> void:
	if not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_ESCAPE:
			intent(INTENT_CANCEL)
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			intent(INTENT_SKIP)


func _drag_start(source: Dictionary, pos: Vector2) -> void:
	if view_state() != STATE_IDLE or source.is_empty():
		return
	var entries: Array[Dictionary] = _entries_for(source)
	if entries.is_empty():
		return
	var positions: Array[int] = []
	var targets: Dictionary = {}
	for entry: Dictionary in entries:
		if entry.get("position") != null and not positions.has(int(entry.position)):
			positions.append(int(entry.position))
		if entry.get("target_id") != null:
			targets[int(entry.target_id)] = true
	var phase: StringName = SESSION_CAST
	if not targets.is_empty():
		phase = SESSION_TARGET
	elif not positions.is_empty():
		phase = SESSION_POSITION
	_session = {
		"source": source, "phase": phase, "entries": entries, "positions": positions,
		"targets": targets, "gap": NO_GAP, "hovered": NO_TARGET, "pos": pos,
	}
	session_started.emit(_session)
	_drag_move(pos)


func _drag_move(pos: Vector2) -> void:
	if not in_session():
		return
	_session.pos = pos
	match _session.phase:
		SESSION_TARGET:
			var target: int = _hit.target_at(pos) if _hit != null else NO_TARGET
			_session.hovered = target if _session.targets.has(target) else NO_TARGET
		SESSION_POSITION:
			if _hit != null and _hit.in_position_zone(pos):
				_session.gap = _hit.gap_at(pos, (_session.positions as Array).size() - 1)
	session_moved.emit(_session)


## §7.4 drag release: inside the zone or on a lit target submits, anything else cancels.
func _drag_release(pos: Vector2) -> void:
	if not in_session():
		return
	_drag_move(pos)
	var chosen: Dictionary = {}
	match _session.phase:
		SESSION_TARGET:
			chosen = _entry_where("target_id", _session.hovered)
		SESSION_POSITION:
			if _hit.in_position_zone(pos):
				chosen = _entry_where("position", _session.gap)
		SESSION_CAST:
			if _hit.in_cast_zone(pos):
				chosen = (_session.entries as Array)[0]
	_end_session(not chosen.is_empty())
	if not chosen.is_empty():
		command_requested.emit(chosen.duplicate(true))


func _end_session(submitted: bool) -> void:
	if not in_session():
		return
	var ended: Dictionary = _session
	_session = {}
	session_ended.emit(ended, submitted)


## The last entry whose [param field] is [param value], so a targeted minion lands at
## the row's end.
func _entry_where(field: String, value: int) -> Dictionary:
	var found: Dictionary = {}
	for entry: Dictionary in _session.entries:
		if entry.get(field) != null and int(entry[field]) == value:
			found = entry
	return found


## The `legal_commands()` entries of [param source]; read on pickup only.
func _entries_for(source: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var index: int = _hand_index(int(source.get("id", -1)))
	for command: Dictionary in player_commands():
		match str(source.kind):
			SOURCE_CARD:
				if str(command.type) == MatchRecords.CMD_PLAY_CARD and int(command.hand_index) == index:
					out.append(command)
			SOURCE_ATTACKER:
				if str(command.type) == MatchRecords.CMD_ATTACK and int(command.attacker_id) == int(source.id):
					out.append(command)
			SOURCE_HERO_POWER:
				if str(command.type) == MatchRecords.CMD_USE_HERO_POWER:
					out.append(command)
	return out


func _hand_index(instance_id: int) -> int:
	var hand: Array = _view.side(&"player").hand
	for i: int in hand.size():
		if int(hand[i].instance_id) == instance_id:
			return i
	return -1


func _player_owes_choice() -> bool:
	return _view.pending_choice != null and str(_view.pending_choice.side) == MatchViewState.SIDE_PLAYER
