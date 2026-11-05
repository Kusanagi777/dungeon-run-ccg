## Keyboard and gamepad focus on the table (match-ui U5 "Keyboard inspect"; hud.md Focus
## Order; interaction-patterns Focus Management): the live stop list, the one ring, and
## which stop a key inspects. The stops are logical, rebuilt from the view-state on every
## move, because cards and tokens come and go: no Control holds this focus, so hover can
## never move it and a ring can never come from hover (ADR-0009, 4.6 dual focus).
##
## A stop is `{kind, id}`. The source kinds are [InputRouter]'s, so `Enter` opens a session
## on the stop as it stands; the player portrait is an attacker stop with the hero's id.
## The ring draws in `Idle` only: in a session the target ring is the focus (targeting.md
## §5.3). The automatic stop on entering `Idle` draws the ring and opens nothing, or a
## mouse player would wear a card preview all turn; a key move opens the inspect.
## [codeblock]
## focus.configure(hand, player_row, boss_row, player_panel, boss_panel)
## focus.changed.connect(_on_focus_changed)
## focus.enter_idle(default_stop, new_turn)
## focus.move(1)
## [/codeblock]
class_name FocusPresenter
extends Presenter

## The focused stop moved; [param stop] is `{kind, id}`.
signal changed(stop: Dictionary)

const KIND_TREASURE: String = "treasure"
const KIND_FEED: String = "feed"
const KIND_MENU: String = "menu"
const KIND_BANNER: String = "banner"
const KIND_BOSS_TOKEN: String = "boss_token"
const KIND_BOSS_PORTRAIT: String = "boss_portrait"
const LAYOUT_FEED: String = "feed_toggle"
const LAYOUT_MENU: String = "menu_button"
const LAYOUT_BANNER: String = "intent_banner"
const RING_Z: int = 300
## How much a stop off to the side counts against one straight ahead in [method move_direction].
const OFF_AXIS_WEIGHT: float = 2.0

var _view: MatchViewState = null
var _hand: HandPresenter = null
var _player_row: BoardPresenter = null
var _boss_row: BoardPresenter = null
var _player_panel: HeroPresenter = null
var _boss_panel: HeroPresenter = null
# `func(index: int) -> Rect2`, the treasure chips' hit rects; [method set_treasures].
var _treasure_rect: Callable = Callable()
var _treasures: int = 0
# `func() -> Rect2` by stop kind, for a control that moves at a text scale.
var _live_rects: Dictionary = {}
var _stop: Dictionary = {}
var _card_index: int = -1
var _active: bool = false
var _inspecting: bool = false


## Gives the focus what owns the pixels of its stops.
func configure(hand: HandPresenter, player_row: BoardPresenter, boss_row: BoardPresenter, player_panel: HeroPresenter, boss_panel: HeroPresenter) -> void:
	_hand = hand
	_player_row = player_row
	_boss_row = boss_row
	_player_panel = player_panel
	_boss_panel = boss_panel


## [param rects] is `{stop kind: func() -> Rect2}`: the stops whose rect is not their layout's.
func set_live_rects(rects: Dictionary) -> void:
	_live_rects = rects


## The tray's [param count] chips, with [param rect_of]: `func(index: int) -> Rect2`.
func set_treasures(count: int, rect_of: Callable) -> void:
	_treasures = count
	_treasure_rect = rect_of


## Sets the ring above every element on the table.
func setup(context: MatchUiContext) -> void:
	super(context)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = RING_Z


## Stores the projection the stops are read from.
func bind(view_state: MatchViewState) -> void:
	_view = view_state


func owns(_entity_ids: Array[int]) -> bool:
	return false


func on_step_started(_step: AnimStep, _d_eff: float) -> void:
	return


func apply_final(_step: AnimStep) -> void:
	return


func sync_report() -> Array[String]:
	return []


## The focused stop, or `{}`.
func current() -> Dictionary:
	return _stop


## The stop a key opened, whose preview or tooltip stays up; `{}` when none.
func inspected() -> Dictionary:
	return _stop if _active and _inspecting else {}


## The stops in hud.md's Focus Order, as the view stands now.
func stops() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var player: Dictionary = _view.side(&"player")
	for card: Dictionary in player.hand:
		out.append({"kind": InputRouter.SOURCE_CARD, "id": int(card.instance_id)})
	for token: Dictionary in player.board:
		out.append({"kind": InputRouter.SOURCE_ATTACKER, "id": int(token.entity_id)})
	if _player_panel.power_rect().has_area():
		out.append({"kind": InputRouter.SOURCE_HERO_POWER, "id": -1})
	if player.hero.entity_id != null:
		out.append({"kind": InputRouter.SOURCE_ATTACKER, "id": int(player.hero.entity_id)})
	for i: int in _treasures:
		out.append({"kind": KIND_TREASURE, "id": i})
	out.append({"kind": InputRouter.STOP_END_TURN, "id": 0})
	_append_chrome(out, KIND_FEED, LAYOUT_FEED)
	_append_chrome(out, KIND_MENU, LAYOUT_MENU)
	_append_chrome(out, KIND_BANNER, LAYOUT_BANNER)
	var boss: Dictionary = _view.side(&"boss")
	for token: Dictionary in boss.board:
		out.append({"kind": KIND_BOSS_TOKEN, "id": int(token.entity_id)})
	out.append({"kind": KIND_BOSS_PORTRAIT, "id": 0})
	return out


## `Idle` began. A new turn takes [param default_stop]; otherwise the stop holds, and a
## card that left the hand hands focus to the card now at its index, else End Turn (U5).
func enter_idle(default_stop: Dictionary, new_turn: bool) -> void:
	_active = true
	_inspecting = false
	var live: Array[Dictionary] = stops()
	if new_turn or _stop.is_empty():
		_set_stop(default_stop)
	elif _index_of(live, _stop) < 0:
		_set_stop(_successor(live))
	changed.emit(_stop)
	queue_redraw()


## `Idle` ended: the ring and any inspect go.
func leave_idle() -> void:
	_active = false
	_inspecting = false
	queue_redraw()


## Moves focus [param step] stops along the order, wrapping, and opens the stop's inspect.
func move(step: int) -> void:
	var live: Array[Dictionary] = stops()
	if live.is_empty():
		return
	var index: int = _index_of(live, _stop)
	focus_stop(live[posmod(index + step, live.size())] if index >= 0 else live[0], true)


## d-pad and stick: the nearest stop in [param direction] (`focus_neighbor_*` by geometry,
## since the graph changes with the board). Nothing that way leaves the focus where it is.
func move_direction(direction: Vector2) -> void:
	var from: Vector2 = rect_of(_stop).get_center()
	var best: Dictionary = {}
	var best_score: float = INF
	for stop: Dictionary in stops():
		var delta: Vector2 = rect_of(stop).get_center() - from
		var along: float = delta.dot(direction)
		if along <= 0.0 or _same(stop, _stop):
			continue
		var score: float = along + absf(delta.cross(direction)) * OFF_AXIS_WEIGHT
		if score < best_score:
			best_score = score
			best = stop
	if not best.is_empty():
		focus_stop(best, true)


## Puts focus on [param stop]. [param inspect] opens its preview or tooltip: a key does,
## a click or a default does not.
func focus_stop(stop: Dictionary, inspect: bool) -> void:
	_set_stop(stop)
	_inspecting = inspect
	changed.emit(_stop)
	queue_redraw()


## The screen rect of [param stop].
func rect_of(stop: Dictionary) -> Rect2:
	var id: int = int(stop.get("id", 0))
	var kind: String = str(stop.get("kind", ""))
	if _live_rects.has(kind):
		return (_live_rects[kind] as Callable).call()
	match kind:
		InputRouter.SOURCE_CARD:
			var card: CardFrame = _hand.card(id)
			return card.get_global_rect() if card != null else Rect2()
		InputRouter.SOURCE_ATTACKER:
			var token: MinionToken = _player_row.token(id)
			return token.get_global_rect() if token != null else _player_panel.portrait_rect()
		InputRouter.SOURCE_HERO_POWER:
			return _player_panel.power_rect()
		KIND_TREASURE:
			return _treasure_rect.call(id) if _treasure_rect.is_valid() else Rect2()
		InputRouter.STOP_END_TURN:
			return ui.rect("end_turn")
		KIND_FEED:
			return ui.rect(LAYOUT_FEED)
		KIND_MENU:
			return ui.rect(LAYOUT_MENU)
		KIND_BANNER:
			return ui.rect(LAYOUT_BANNER)
		KIND_BOSS_TOKEN:
			var boss_token: MinionToken = _boss_row.token(id)
			return boss_token.get_global_rect() if boss_token != null else Rect2()
		KIND_BOSS_PORTRAIT:
			return _boss_panel.portrait_rect()
	return Rect2()


func _process(_delta: float) -> void:
	if _active:
		queue_redraw()


func _draw() -> void:
	if not _active:
		return
	var rect: Rect2 = rect_of(_stop)
	if rect.has_area():
		var cfg: Dictionary = ui.config.focus
		draw_rect(rect.grow(float(cfg.ring_offset_px)), ui.color("state_actionable"), false, float(cfg.ring_px))


func _set_stop(stop: Dictionary) -> void:
	_stop = stop
	if str(stop.get("kind", "")) == InputRouter.SOURCE_CARD:
		_card_index = _hand_index(int(stop.id))


func _successor(live: Array[Dictionary]) -> Dictionary:
	var hand: Array = _view.side(&"player").hand
	if str(_stop.get("kind", "")) == InputRouter.SOURCE_CARD and _card_index >= 0 and _card_index < hand.size():
		return {"kind": InputRouter.SOURCE_CARD, "id": int(hand[_card_index].instance_id)}
	for stop: Dictionary in live:
		if str(stop.kind) == InputRouter.STOP_END_TURN:
			return stop
	return {}


func _hand_index(id: int) -> int:
	var hand: Array = _view.side(&"player").hand
	for i: int in hand.size():
		if int(hand[i].instance_id) == id:
			return i
	return -1


func _append_chrome(out: Array[Dictionary], kind: String, layout_key: String) -> void:
	if (ui.config.layout as Dictionary).has(layout_key):
		out.append({"kind": kind, "id": 0})


static func _index_of(live: Array[Dictionary], stop: Dictionary) -> int:
	for i: int in live.size():
		if _same(live[i], stop):
			return i
	return -1


static func _same(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("kind", "")) == str(b.get("kind", "")) and int(a.get("id", 0)) == int(b.get("id", 0))
