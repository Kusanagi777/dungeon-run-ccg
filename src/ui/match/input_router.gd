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
## positions → `P`, targets → `T`, neither → `C`. A minion with a targeted Battlecry
## plays `P` then `T`: the chosen gap holds a ghost, the session goes on hands-free, and
## a cancel from there drops the whole play. `drag_release` follows the §7.4 table; a
## cancel never calls the engine.
## [codeblock]
## router.intent(&"drag_start", {"source": {"kind": "card", "id": 12}, "pos": press})
## router.intent(&"drag_move", {"pos": mouse})
## router.intent(&"drag_release", {"pos": mouse})
## [/codeblock]
##
## **`KeyTargeting`** is the same session with `entered_by` pointer or key (match-ui U5,
## targeting.md §6): a click under `CLICK_DRAG_PX`, a number key, `A` then a number, `H`,
## or `Enter` on a focused source opens it. A single click never plays anything: the
## second click follows the §7.4 click table, and `Enter` confirms the current stop.
## [codeblock]
## router.intent(&"select", {"source": {"kind": "card", "id": 12}, "pos": mouse, "entered_by": TargetingSession.ENTERED_KEY})
## router.intent(&"cycle", {"step": 1})
## router.intent(&"confirm")
## [/codeblock]
##
## **Keys** come in as [MatchInput] names, so a gamepad reads the same. `Space` and
## `Enter` end the turn only once the queue has been idle for `end_turn_arm_ms`
## (U5 arm guard); a click on the button never waits.
class_name InputRouter
extends Node

## The player asked for [param command]; `MatchView` forwards it to `MatchController.submit`.
signal command_requested(command: Dictionary)
## A drag session opened: `{source{kind, id}, phase, entries, positions, targets, gap,
## hovered, pos}`.
signal session_started(session: Dictionary)
## The pointer moved in a session; [param session] holds the new `pos`, `gap`, `hovered`.
signal session_moved(session: Dictionary)
## Phase P became Phase T: [param session] holds the chosen `position` and its targets.
signal session_phase_changed(session: Dictionary)
## The session ended; [param submitted] is true when a command follows.
signal session_ended(session: Dictionary, submitted: bool)
## `A` armed attacker selection: [param badges] maps entity id to its slot numeral, and
## is empty when the state disarms (targeting.md §7.1).
signal attackers_armed(badges: Dictionary)
## `Tab` in `Idle`: move keyboard focus [param step] stops.
signal focus_step_requested(step: int)
## `Esc` reached chain step 3 or 4, or the menu button: open the pause menu, or step
## back out of it.
signal menu_requested()
## `L`, or `Esc` / RMB with the drawer open: toggle the feed drawer.
signal feed_requested()

## The view states of match-ui States this router can be in.
const STATE_LOADING: StringName = &"Loading"
const STATE_MULLIGAN: StringName = &"Mulligan"
const STATE_IDLE: StringName = &"Idle"
const STATE_DRAGGING: StringName = &"Dragging"
const STATE_KEY_TARGETING: StringName = &"KeyTargeting"
const STATE_PLAYBACK: StringName = &"Playback"
const STATE_BOSS_TURN: StringName = &"BossTurn"
const STATE_CHOICE_OPEN: StringName = &"ChoiceOpen"
const STATE_MENU: StringName = &"Menu"
const STATE_ENDED: StringName = &"Ended"
const PHASE_MAIN: String = "main"
const INTENT_END_TURN: StringName = &"end_turn"
const INTENT_SKIP: StringName = &"skip"
const INTENT_DRAG_START: StringName = &"drag_start"
const INTENT_DRAG_MOVE: StringName = &"drag_move"
const INTENT_DRAG_RELEASE: StringName = &"drag_release"
const INTENT_CANCEL: StringName = &"cancel"
const INTENT_SELECT: StringName = &"select"
const INTENT_CYCLE: StringName = &"cycle"
const INTENT_CONFIRM: StringName = &"confirm"
const INTENT_CLICK: StringName = &"click"
const INTENT_FEED: StringName = &"feed"
const INTENT_MENU: StringName = &"menu"
const INTENT_CONCEDE: StringName = &"concede"
const INTENT_MULLIGAN_CONFIRM: StringName = &"mulligan_confirm"
## `source.kind` values.
const SOURCE_CARD: String = "card"
const SOURCE_ATTACKER: String = "attacker"
const SOURCE_HERO_POWER: String = "hero_power"
## The focus stop `Space` and `Enter` end the turn from.
const STOP_END_TURN: String = "end_turn"
## targeting.md §6 phases.
const SESSION_POSITION: StringName = TargetingSession.PHASE_POSITION
const SESSION_TARGET: StringName = TargetingSession.PHASE_TARGET
const SESSION_CAST: StringName = TargetingSession.PHASE_CAST
const NO_GAP: int = TargetingSession.NO_GAP
const NO_TARGET: int = TargetingSession.NO_TARGET
const DEFAULT_CLICK_DRAG_PX: float = 8.0
const DEFAULT_END_TURN_ARM_MS: int = 300
## How far [method escape] may run: RMB stops at the drawer (Escape / Cancel).
const CHAIN_POINTER: int = 2
const CHAIN_FULL: int = 4
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
var _end_turn_arm_ms: int = DEFAULT_END_TURN_ARM_MS
# `func() -> int`, the milliseconds the arm guard reads; a test passes a fake.
var _clock: Callable = Time.get_ticks_msec
var _idle_since_ms: int = 0
# `func() -> bool`: the feed drawer is open.
var _drawer_open: Callable = Callable()
# The open drag session; empty in every other state.
var _session: Dictionary = {}
# The source under the last press, until it becomes a drag or is released.
var _press_source: Dictionary = {}
var _press_pos: Vector2 = Vector2.ZERO
var _press_double: bool = false
# The press landed in a session, so its release is that session's click.
var _press_in_session: bool = false
# `A` is waiting for a number.
var _armed: bool = false
# The pause menu is up: the base takes nothing but the chain.
var _menu_open: bool = false
# The focused stop `{kind, id}`; empty is End Turn's default (U5).
var _focus: Dictionary = {}


## Gives the router the [param view_state] and [param queue] it reads.
func bind(view_state: MatchViewState, queue: AnimationQueue) -> void:
	_view = view_state
	_queue = queue
	_idle_since_ms = _clock.call()
	_queue.drained.connect(_on_drained)


## Gives the router the [param controller] it reads legality from.
func set_controller(controller: MatchController) -> void:
	_controller = controller


## Gives the router what a raw mouse event needs: [param hit] answers for pixels, and
## [param click_drag_px] is `CLICK_DRAG_PX`.
func set_hit_test(hit: MatchHitTest, click_drag_px: float) -> void:
	_hit = hit
	_click_drag_px = click_drag_px


## Sets the arm guard's [param arm_ms] and, for a test, the [param clock] it reads:
## `func() -> int`, in milliseconds.
func set_end_turn_arm(arm_ms: int, clock: Callable = Callable()) -> void:
	_end_turn_arm_ms = arm_ms
	if clock.is_valid():
		_clock = clock
		_idle_since_ms = _clock.call()


## Tells the router how to ask whether the feed drawer is open.
func set_drawer_check(is_open: Callable) -> void:
	_drawer_open = is_open


## Tells the router the pause menu opened or closed (States `Menu`).
func set_menu_open(on: bool) -> void:
	_menu_open = on


## The stop holding keyboard focus: `{kind, id}`, or `{}` for none. A source kind opens
## a session on `Enter`.
func set_focus_stop(stop: Dictionary) -> void:
	_focus = stop


## True while a session is open, however it was entered.
func in_session() -> bool:
	return not _session.is_empty()


## True while a session holds the pointer down: a drag, not a `KeyTargeting`.
func dragging() -> bool:
	return in_session() and _session.entered_by == TargetingSession.ENTERED_DRAG


## The open session, or `{}`.
func session() -> Dictionary:
	return _session


## Turns a raw event into intents: mouse by type, never by `device` (4.7), and every
## key or pad button through its [MatchInput] name.
func handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_on_mouse_button(event)
	elif event is InputEventMouseMotion:
		_on_mouse_motion(event)
	else:
		on_action(MatchInput.read(event), MatchInput.hand_slot(event))


## One [MatchInput] name, with the hand [param slot] when it is
## [constant MatchInput.HAND]. Any (state, input) pair not listed is ignored.
func on_action(action: StringName, slot: int = -1) -> void:
	if action == MatchInput.NONE:
		return
	if _menu_open:
		if action == MatchInput.CANCEL:
			escape()
		return
	if _armed:
		_on_armed_action(action, slot)
		return
	match action:
		MatchInput.CANCEL:
			escape()
		MatchInput.CONFIRM:
			_on_accept(true)
		MatchInput.END_TURN:
			_on_accept(false)
		MatchInput.NEXT:
			intent(INTENT_CYCLE, {"step": 1})
		MatchInput.PREVIOUS:
			intent(INTENT_CYCLE, {"step": -1})
		MatchInput.HERO_POWER:
			_pick({"kind": SOURCE_HERO_POWER, "id": -1})
		MatchInput.HAND:
			_pick_hand(slot)
		MatchInput.ATTACK:
			_arm_attackers()
		MatchInput.FEED:
			intent(INTENT_FEED)


## The `Esc` chain, first match wins (U5, Escape / Cancel): the session, the feed
## drawer, the top-most overlay with a cancel, then the pause menu. Mulligan and Choice
## have no cancel, so they fall through to the menu. [param max_step] stops the chain at
## the drawer for RMB; once `result` is set it opens nothing (DD-X09).
func escape(max_step: int = CHAIN_FULL) -> void:
	if in_session():
		_end_session(false)
	elif _menu_open:
		menu_requested.emit()
	elif _drawer_open.is_valid() and _drawer_open.call():
		feed_requested.emit()
	elif max_step > CHAIN_POINTER and _view != null and _view.result == null:
		menu_requested.emit()


## True once the queue has been idle for `end_turn_arm_ms`: a skip press landing on the
## frame the boss turn drains must not end the turn (U5 arm guard).
func end_turn_armed() -> bool:
	return can_end_turn() and int(_clock.call()) - _idle_since_ms >= _end_turn_arm_ms


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
	if _menu_open:
		return STATE_MENU
	if in_session():
		return STATE_DRAGGING if dragging() else STATE_KEY_TARGETING
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
		INTENT_SELECT:
			_select(args.get("source", {}), args.get("pos", Vector2.ZERO), args.get("entered_by", TargetingSession.ENTERED_KEY), args.get("first", false))
		INTENT_CYCLE:
			_cycle(int(args.get("step", 1)))
		INTENT_CONFIRM:
			_confirm()
		INTENT_CLICK:
			_session_click(args.get("pos", Vector2.ZERO), args.get("double", false))
		INTENT_FEED:
			if allows(INTENT_FEED):
				feed_requested.emit()
		INTENT_MENU:
			if _view.result == null:
				menu_requested.emit()
		INTENT_CONCEDE:
			if _view.result == null:
				command_requested.emit(MatchRecords.concede())
		CHOICE_INTENT:
			if _player_owes_choice():
				command_requested.emit(MatchRecords.choose(MatchViewState.SIDE_PLAYER, int(args.get("index", 0))))
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
		_disarm()
		escape(CHAIN_POINTER)
	elif event.button_index != MOUSE_BUTTON_LEFT:
		return
	elif event.pressed:
		_disarm()
		intent(INTENT_SKIP)
		_press_pos = event.position
		_press_double = event.double_click
		_press_in_session = in_session()
		_press_source = _hit.source_at(event.position) if view_state() == STATE_IDLE else {}
	else:
		_on_left_release(event.position)


func _on_left_release(pos: Vector2) -> void:
	var source: Dictionary = _press_source
	var in_click: bool = pos.distance_to(_press_pos) <= _click_drag_px
	_press_source = {}
	if dragging():
		intent(INTENT_DRAG_RELEASE, {"pos": pos})
	elif in_session():
		if _press_in_session and in_click:
			intent(INTENT_CLICK, {"pos": pos, "double": _press_double})
	elif not source.is_empty():
		intent(INTENT_SELECT, {"source": source, "pos": pos, "entered_by": TargetingSession.ENTERED_POINTER})
	_press_in_session = false


func _on_mouse_motion(event: InputEventMouseMotion) -> void:
	if in_session():
		intent(INTENT_DRAG_MOVE, {"pos": event.position})
	elif not _press_source.is_empty() and event.position.distance_to(_press_pos) > _click_drag_px:
		var source: Dictionary = _press_source
		_press_source = {}
		intent(INTENT_DRAG_START, {"source": source, "pos": event.position})


## `Space` and `Enter`: skip while the queue is busy; `Enter` confirms a session; in
## `Idle` they act on the focused stop (hud.md Focus Order). [param enter] is false for
## `Space`, which never opens a session.
func _on_accept(enter: bool) -> void:
	if in_session():
		if enter:
			intent(INTENT_CONFIRM)
		return
	if not _queue.is_idle():
		intent(INTENT_SKIP)
		return
	if view_state() != STATE_IDLE:
		return
	match str(_focus.get("kind", STOP_END_TURN)):
		STOP_END_TURN:
			if end_turn_armed():
				intent(INTENT_END_TURN)
		SOURCE_CARD, SOURCE_ATTACKER, SOURCE_HERO_POWER:
			if enter:
				_select(_focus, Vector2.ZERO, TargetingSession.ENTERED_KEY, false)
		FocusPresenter.KIND_FEED:
			intent(INTENT_FEED)
		FocusPresenter.KIND_MENU:
			intent(INTENT_MENU)


## `1`–`0`: the hand card at [param slot] into targeting; a slot past the hand is ignored.
func _pick_hand(slot: int) -> void:
	var hand: Array = _view.side(&"player").hand
	if slot >= 0 and slot < hand.size():
		_pick({"kind": SOURCE_CARD, "id": int(hand[slot].instance_id)})


## A key picks [param source]: from `Idle`, or as a re-select in a session. Its own
## source is ignored (§7.1 `H`).
func _pick(source: Dictionary) -> void:
	if in_session() and TargetingSession.same_source(source, _session.source):
		return
	_select(source, Vector2.ZERO, TargetingSession.ENTERED_KEY, false)


## `A`: badges on the legal attackers, by slot position counted from the left (§7.1).
func _arm_attackers() -> void:
	if view_state() != STATE_IDLE and not in_session():
		return
	var badges: Dictionary = _attacker_badges()
	if badges.is_empty():
		return
	_armed = true
	attackers_armed.emit(badges)


## The armed state takes the next input: a badged number picks, an unbadged one is
## ignored and stays armed, anything else disarms and is consumed, `Esc` included.
func _on_armed_action(action: StringName, slot: int) -> void:
	if action != MatchInput.HAND:
		_disarm()
		return
	var board: Array = _view.side(&"player").board
	if slot >= board.size():
		return
	var id: int = int(board[slot].entity_id)
	if not _attacker_badges().has(id):
		return
	_disarm()
	_pick({"kind": SOURCE_ATTACKER, "id": id})


func _disarm() -> void:
	if _armed:
		_armed = false
		attackers_armed.emit({})


func _attacker_badges() -> Dictionary:
	var legal: Array[Dictionary] = _session.legal if in_session() else player_commands()
	var badges: Dictionary = {}
	var board: Array = _view.side(&"player").board
	for i: int in board.size():
		var id: int = int(board[i].entity_id)
		if not _entries_for({"kind": SOURCE_ATTACKER, "id": id}, legal).is_empty():
			badges[id] = i + 1
	return badges


func _drag_start(source: Dictionary, pos: Vector2) -> void:
	if view_state() != STATE_IDLE or source.is_empty():
		return
	var legal: Array[Dictionary] = player_commands()
	var entries: Array[Dictionary] = _entries_for(source, legal)
	if entries.is_empty():
		return
	_session = TargetingSession.open(source, entries, legal, TargetingSession.ENTERED_DRAG, pos, _view)
	session_started.emit(_session)
	_drag_move(pos)


## Opens `KeyTargeting` on [param source], from `Idle` or as a re-select. A source with
## no legal entry opens nothing and leaves a session as it was (§6 "No legal entry").
## [param first] starts a pointer session on the first stop, not the nearest.
func _select(source: Dictionary, pos: Vector2, entered_by: StringName, first: bool) -> void:
	if source.is_empty() or (not in_session() and view_state() != STATE_IDLE):
		return
	var legal: Array[Dictionary] = _session.legal if in_session() else player_commands()
	var entries: Array[Dictionary] = _entries_for(source, legal)
	if entries.is_empty():
		return
	_end_session(false)
	_session = TargetingSession.open(source, entries, legal, entered_by, pos, _view)
	session_started.emit(_session)
	_enter_phase(pos, entered_by == TargetingSession.ENTERED_KEY or first)


## Puts the current stop on the phase just entered: the first stop or right-most gap
## from a key, the one nearest [param pos] from the pointer (§7.1).
func _enter_phase(pos: Vector2, from_key: bool) -> void:
	match _session.phase:
		SESSION_TARGET:
			_session.hovered = (_session.stops as Array[int])[0] if from_key else _nearest_stop(pos)
			_show_current(false)
		SESSION_POSITION:
			var last: int = (_session.positions as Array[int]).back()
			_session.gap = last if from_key or _hit == null else _hit.gap_at(pos, last)
			session_moved.emit(_session)


func _nearest_stop(pos: Vector2) -> int:
	var best: int = NO_TARGET
	var best_d: float = INF
	for stop: int in _session.stops:
		var d: float = pos.distance_squared_to(_stop_centre(stop)) if _hit != null else 0.0
		if d < best_d:
			best_d = d
			best = stop
	return best


## The arrow on the current stop. [param snap] tweens it (§10 "Arrow snap").
func _show_current(snap: bool) -> void:
	if _hit != null:
		_session.pos = _stop_centre(int(_session.hovered))
	_session.lit = true
	_session.snap = snap
	session_moved.emit(_session)
	_session.snap = false


func _stop_centre(stop: int) -> Vector2:
	if stop == TargetingSession.NO_TARGET_CHIP:
		return (_session.chip_rect as Rect2).get_center()
	return _hit.centre_of(stop)


func _cycle(step: int) -> void:
	if view_state() == STATE_IDLE:
		focus_step_requested.emit(step)
	if not in_session() or dragging():
		return
	match _session.phase:
		SESSION_TARGET:
			_session.hovered = TargetingSession.cycled(_session.stops, int(_session.hovered), step)
			_show_current(true)
		SESSION_POSITION:
			_session.gap = TargetingSession.cycled(_session.positions, int(_session.gap), step)
			session_moved.emit(_session)


## `Enter`: confirm the current stop; a drag is confirmed by its release.
func _confirm() -> void:
	if not in_session() or dragging():
		return
	match _session.phase:
		SESSION_TARGET:
			_submit(_target_entry())
		SESSION_POSITION:
			_place(int(_session.gap))
		SESSION_CAST:
			_submit((_session.entries as Array)[0])


## The entry of the current stop: the null one on the chip.
func _target_entry() -> Dictionary:
	if int(_session.hovered) != TargetingSession.NO_TARGET_CHIP:
		return _entry_where("target_id", int(_session.hovered))
	for entry: Dictionary in _session.entries:
		if entry.get("target_id") == null:
			return entry
	return {}


## Phase P chose [param gap]: submit it, or go on to Phase T with the gap held. A drag
## ends here, so its Phase T is a pointer session (§7.4 "or → Phase T").
func _place(gap: int) -> void:
	if not TargetingSession.narrows_to_target(_session, gap):
		_submit(_entry_where("position", gap))
		return
	TargetingSession.narrow(_session, gap, _view)
	var pos: Vector2 = _session.pos
	if dragging():
		_session.entered_by = TargetingSession.ENTERED_POINTER
	session_phase_changed.emit(_session)
	_enter_phase(pos, _session.entered_by == TargetingSession.ENTERED_KEY)


func _submit(chosen: Dictionary) -> void:
	_end_session(not chosen.is_empty())
	if not chosen.is_empty():
		command_requested.emit(chosen.duplicate(true))


## §7.4 click table: the first matching rank wins, whatever `entered_by` was.
func _session_click(pos: Vector2, double: bool) -> void:
	if not in_session() or dragging():
		return
	var phase: StringName = _session.phase
	if phase == SESSION_TARGET:
		var target: int = _target_under(pos)
		if target != NO_TARGET:
			_session.hovered = target
			_confirm()
			return
	if TargetingSession.same_source(_hit.source_at(pos), _session.source) or (_session.ghost_rect as Rect2).has_point(pos):
		if phase == SESSION_CAST and not double:
			_confirm()
		return
	var other: Dictionary = _other_source(pos)
	if not other.is_empty():
		_select(other, pos, TargetingSession.ENTERED_POINTER, false)
	elif phase == SESSION_POSITION and _hit.in_position_zone(pos):
		_session.gap = _hit.gap_at(pos, (_session.positions as Array).size() - 1)
		_confirm()
	elif phase == SESSION_CAST and _hit.in_cast_zone(pos):
		_confirm()
	elif not _hit.in_end_turn(pos):
		_end_session(false)


## The lit stop under [param pos], the chip included, or [constant NO_TARGET].
func _target_under(pos: Vector2) -> int:
	if bool(_session.null_allowed) and (_session.chip_rect as Rect2).has_point(pos):
		return TargetingSession.NO_TARGET_CHIP
	var target: int = _hit.target_at(pos) if _hit != null else NO_TARGET
	return target if _session.targets.has(target) else NO_TARGET


## §7.4 rank 3: a different legal source at [param pos], or `{}`. In Phase P the row is
## its m + 1 layout, so a player token there is the gap, never a source.
func _other_source(pos: Vector2) -> Dictionary:
	var source: Dictionary = _hit.source_at(pos)
	if source.is_empty() or TargetingSession.same_source(source, _session.source):
		return {}
	var hero: Variant = _view.side(&"player").hero.entity_id
	if _session.phase == SESSION_POSITION and str(source.kind) == SOURCE_ATTACKER and (hero == null or int(source.id) != int(hero)):
		return {}
	return source if not _entries_for(source, _session.legal).is_empty() else {}


func _drag_move(pos: Vector2) -> void:
	if not in_session():
		return
	match _session.entered_by:
		TargetingSession.ENTERED_DRAG:
			_move_drag(pos)
		TargetingSession.ENTERED_POINTER:
			_move_pointer(pos)


func _move_drag(pos: Vector2) -> void:
	_session.pos = pos
	match _session.phase:
		SESSION_TARGET:
			_session.hovered = _target_under(pos)
			_session.lit = _session.hovered != NO_TARGET
		SESSION_POSITION:
			if _hit != null and _hit.in_position_zone(pos):
				_session.gap = _hit.gap_at(pos, (_session.positions as Array).size() - 1)
	session_moved.emit(_session)


## Hover in a pointer session: a lit target or gap takes the ring; anywhere else the
## current stop holds and the affordance dims, over a rank-3 source too (§7.4).
func _move_pointer(pos: Vector2) -> void:
	var over_source: bool = not _other_source(pos).is_empty()
	match _session.phase:
		SESSION_TARGET:
			var target: int = _target_under(pos)
			if target != NO_TARGET:
				_session.hovered = target
				_show_current(false)
				return
			_session.lit = false
		SESSION_POSITION:
			if not over_source and _hit.in_position_zone(pos):
				_session.gap = _hit.gap_at(pos, (_session.positions as Array).size() - 1)
		SESSION_CAST:
			_session.dim_zone = over_source
	session_moved.emit(_session)


## §7.4 drag release: inside the zone or on a lit target submits, anything else cancels.
func _drag_release(pos: Vector2) -> void:
	if not dragging():
		return
	_drag_move(pos)
	var chosen: Dictionary = {}
	match _session.phase:
		SESSION_TARGET:
			chosen = _target_entry()
		SESSION_POSITION:
			if _hit.in_position_zone(pos):
				_place(int(_session.gap))
				return
		SESSION_CAST:
			if _hit.in_cast_zone(pos):
				chosen = (_session.entries as Array)[0]
	_submit(chosen)


func _end_session(submitted: bool) -> void:
	if not in_session():
		return
	var ended: Dictionary = _session
	_session = {}
	session_ended.emit(ended, submitted)


## The last entry whose [param field] is [param value].
func _entry_where(field: String, value: int) -> Dictionary:
	var found: Dictionary = {}
	for entry: Dictionary in _session.entries:
		if entry.get(field) != null and int(entry[field]) == value:
			found = entry
	return found


## The entries of [param source] in [param legal], the snapshot read on pickup.
func _entries_for(source: Dictionary, legal: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var index: int = _hand_index(int(source.get("id", -1)))
	for command: Dictionary in legal:
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


func _on_drained() -> void:
	_idle_since_ms = _clock.call()


func _player_owes_choice() -> bool:
	return _view.pending_choice != null and str(_view.pending_choice.side) == MatchViewState.SIDE_PLAYER
