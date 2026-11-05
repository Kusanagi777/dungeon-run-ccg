## The player's hand fan (ADR-0009 `hand_fan.tscn`; match-ui F1, F2; hand.md). A custom
## layout, not a Container, because F1 rotates and overlaps. Cards are [CardFrame]s
## with their pivot at the bottom centre. Later cards draw above earlier ones, which
## is what keeps every left-corner stamp visible in a crowded fan.
##
## Hover lifts in place and never moves a neighbour or keyboard focus. Pickup is
## immediate: no tween-in (Input Responsiveness).
class_name HandPresenter
extends Presenter

const CARD_FRAME_SCENE: PackedScene = preload("res://src/ui/common/card_frame.tscn")
const HOVER_Z: int = 100
const DRAG_Z: int = 200
## How far a travelling card shrinks: a deck pile and a board token are both smaller.
const TRAVEL_SCALE: float = 0.6

var _view: MatchViewState = null
var _zone_dim: ColorRect = null
var _cfg: Dictionary = {}
# instance_id → CardFrame.
var _cards: Dictionary = {}
# The hand shown, left to right.
var _order: Array[int] = []
var _shown_costs: Dictionary = {}
# instance_id → the F1 slot `{x, y, rot}` its card rests on.
var _slots: Dictionary = {}
var _hovered: int = -1
var _dragged: int = -1
var _parked: bool = false
var _hover_tween: Tween = null
# Cards a step is moving: present leaves them where the tween has them.
var _travelling: Dictionary = {}
var _playable: Dictionary = {}
var _mana: int = 0
var _idle: bool = false


## Reads the F1 / F2 knobs.
func setup(context: MatchUiContext) -> void:
	super(context)
	_cfg = ui.config.hand
	var zone: Rect2 = ui.rect("hand_zone")
	_zone_dim = ColorRect.new()
	_zone_dim.position = zone.position
	_zone_dim.size = zone.size
	_zone_dim.color = Color(ui.color("table_dark"), float(ui.config.hand_dim_alpha))
	_zone_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zone_dim.visible = false
	add_child(_zone_dim)
	move_child(_zone_dim, 0)


## Stores the projection [method sync_report] compares against.
func bind(view_state: MatchViewState) -> void:
	_view = view_state


func owns(entity_ids: Array[int]) -> bool:
	for id: int in entity_ids:
		if _cards.has(id) or _in_view_hand(id):
			return true
	return false


func on_step_started(step: AnimStep, d_eff: float) -> void:
	match step.kind:
		AnimStep.DRAW:
			present(step.data.get("display", {}))
			for id: int in step.entity_ids:
				_travel_in(step, id, d_eff)
		AnimStep.PLAY_CARD:
			for id: int in step.entity_ids:
				_travel_out(step, id, d_eff)


func apply_final(step: AnimStep) -> void:
	end_step(step)
	for id: int in step.entity_ids:
		_travelling.erase(id)


func on_skipped() -> void:
	super()
	_travelling.clear()


func present(state: Dictionary) -> void:
	if state.is_empty():
		return
	visible = state.get("pending_mulligan") == null
	var hand: Array = state.player.hand
	_mana = int(state.player.mana.available)
	var order: Array[int] = []
	var costs: Dictionary = {}
	for card: Dictionary in hand:
		var id: int = int(card.instance_id)
		order.append(id)
		costs[id] = _cost_of(card)
		if not _cards.has(id):
			_add_card(id, str(card.get("card_id", "")), int(costs[id]))
		elif int(_shown_costs.get(id, -1)) != int(costs[id]):
			(_cards[id] as CardFrame).show_card(ui.card_face(str(card.card_id)), int(costs[id]))
	for id: Variant in _cards.keys():
		if not costs.has(id):
			_remove_card(int(id))
	_order = order
	_shown_costs = costs
	_lay_out()


func sync_report() -> Array[String]:
	var report: Array[String] = []
	var truth: Array = _view.side(&"player").hand
	if truth.size() != _order.size():
		report.append("hand size: shows %d, view-state %d" % [_order.size(), truth.size()])
		return report
	for i: int in truth.size():
		var card: Dictionary = truth[i]
		if int(card.instance_id) != _order[i]:
			report.append("hand[%d]: shows %d, view-state %s" % [i, _order[i], str(card.instance_id)])
		elif int(_shown_costs.get(_order[i], -1)) != _cost_of(card):
			report.append("hand[%d] cost: shows %s, view-state %d" % [i, str(_shown_costs.get(_order[i])), _cost_of(card)])
	return report


## The top-most card under [param point], or -1. A hovered card tests at its preview.
func card_at(point: Vector2) -> int:
	if not visible:
		return -1
	if _hovered != -1 and _cards.has(_hovered) and HandLayout.contains(point, _hover_slot(_hovered), _cfg):
		return _hovered
	for i: int in range(_order.size() - 1, -1, -1):
		if _slots.has(_order[i]) and HandLayout.contains(point, _slots[_order[i]], _cfg):
			return _order[i]
	return -1


## Legality at `Idle`: [param playable] holds the instance ids `MatchQuery.hand` lit.
func set_playable(playable: Dictionary, idle: bool) -> void:
	_playable = playable
	_idle = idle
	_refresh_states()


## States `BossTurn`: the zone's fill drops one step behind the cards, whose own
## contrast stays. One step on enter and exit, no tween.
func set_zone_dim(on: bool) -> void:
	_zone_dim.visible = on


## The hand fill the opaque dim mixes toward.
func set_fill(fill: Color) -> void:
	for card: CardFrame in _cards.values():
		card.set_fill(fill)


## F2: previews card [param id], or none for -1, over `HOVER_IN_S`; 0 s is immediate.
## Neighbours never move.
func set_hover(id: int, duration_s: float = -1.0) -> void:
	if id == _hovered or _dragged != -1:
		return
	var seconds: float = float(_cfg.hover_in_s) if duration_s < 0.0 else duration_s
	if _hover_tween != null:
		_hover_tween.kill()
		_hover_tween = null
	var previous: int = _hovered
	_hovered = id
	if _cards.has(previous):
		_place(previous, _slots[previous], previous == id)
		_set_z(previous)
	if not _cards.has(id):
		return
	var card: CardFrame = _cards[id]
	card.z_index = HOVER_Z
	var slot: Dictionary = _hover_slot(id)
	if seconds <= 0.0:
		_place(id, slot, true)
		return
	_hover_tween = create_tween().set_parallel()
	_hover_tween.tween_property(card, "position", _position_for(slot), seconds)
	_hover_tween.tween_property(card, "rotation_degrees", float(slot.rot), seconds)
	_hover_tween.tween_property(card, "scale", Vector2.ONE * float(slot.scale), seconds)


## The card shown for [param id], or null.
func card(id: int) -> CardFrame:
	return _cards.get(id)


## Drag: [param id] leaves the fan at once, at 1.0x upright, and [param parked] holds
## it at its F1 x for a targeted play (targeting.md §5.2).
func begin_drag(id: int, parked: bool) -> void:
	set_hover(-1, 0.0)
	_dragged = id
	_parked = parked
	if not _cards.has(id):
		return
	var card_frame: CardFrame = _cards[id]
	card_frame.z_index = DRAG_Z
	if parked:
		_place(id, HandLayout.parked(float(_slots[id].x), _cfg), true)


## The screen centre of card [param id] as it stands, for the arrow's start.
func card_centre(id: int) -> Vector2:
	if not _cards.has(id):
		return Vector2.ZERO
	var frame: CardFrame = _cards[id]
	return frame.position + frame.size / 2.0


## The dragged card follows [param point] exactly; a parked card stays.
func follow(point: Vector2) -> void:
	if _dragged == -1 or _parked or not _cards.has(_dragged):
		return
	_place(_dragged, {"x": point.x, "y": point.y + float(_cfg.card_h) / 2.0, "rot": 0.0, "scale": 1.0}, true)


## The drag ended. A cancelled one tweens home over `return_s`; a submitted one stays
## put until its `play_card` step takes it.
func end_drag(submitted: bool) -> void:
	var id: int = _dragged
	_dragged = -1
	_parked = false
	if not _cards.has(id):
		return
	if submitted:
		_travelling[id] = true
		return
	_set_z(id)
	var slot: Dictionary = _slots.get(id, {})
	if slot.is_empty():
		return
	var back: Tween = create_tween().set_parallel()
	var seconds: float = float(_cfg.return_s)
	back.tween_property(_cards[id], "position", _position_for(slot), seconds)
	back.tween_property(_cards[id], "rotation_degrees", float(slot.rot), seconds)


## A submitted card the engine refused goes home.
func reset_card(id: int) -> void:
	_travelling.erase(id)
	if _cards.has(id):
		_set_z(id)
		_place(id, _slots[id], true)


func _lay_out() -> void:
	var slots: Array[Dictionary] = HandLayout.fan(_order.size(), _cfg)
	for i: int in _order.size():
		var id: int = _order[i]
		_slots[id] = slots[i]
		if _travelling.has(id) or id == _dragged:
			continue
		if id == _hovered:
			_place(id, _hover_slot(id), true)
		else:
			_place(id, slots[i], true)
			_set_z(id)
	_refresh_states()


func _refresh_states() -> void:
	for id: int in _order:
		if not _cards.has(id):
			continue
		var playable: bool = _playable.has(id)
		var unaffordable: bool = _idle and not playable and int(_shown_costs.get(id, 0)) > _mana
		(_cards[id] as CardFrame).set_state(_idle and playable, _idle and not playable, unaffordable)


func _hover_slot(id: int) -> Dictionary:
	return HandLayout.hover(float(_slots[id].x), _cfg)


func _position_for(slot: Dictionary) -> Vector2:
	return Vector2(float(slot.x) - float(_cfg.card_w) / 2.0, float(slot.y) - float(_cfg.card_h))


func _place(id: int, slot: Dictionary, snap: bool) -> void:
	if not snap or not _cards.has(id):
		return
	var card_frame: CardFrame = _cards[id]
	card_frame.position = _position_for(slot)
	card_frame.rotation_degrees = float(slot.rot)
	card_frame.scale = Vector2.ONE * float(slot.get("scale", 1.0))


func _set_z(id: int) -> void:
	if _cards.has(id):
		(_cards[id] as CardFrame).z_index = _order.find(id) + 1


func _add_card(id: int, card_id: String, cost: int) -> void:
	var frame: CardFrame = CARD_FRAME_SCENE.instantiate()
	add_child(frame)
	frame.configure(ui)
	frame.pivot_offset = Vector2(float(_cfg.card_w) / 2.0, float(_cfg.card_h))
	frame.show_card(ui.card_face(card_id), cost)
	_cards[id] = frame


func _remove_card(id: int) -> void:
	(_cards[id] as CardFrame).queue_free()
	_cards.erase(id)
	_slots.erase(id)
	_travelling.erase(id)
	if _hovered == id:
		_hovered = -1


## `draw`: the card slides from the deck pile into its slot.
func _travel_in(step: AnimStep, id: int, d_eff: float) -> void:
	if not _cards.has(id) or not _slots.has(id):
		return
	_travelling[id] = true
	var card_frame: CardFrame = _cards[id]
	var deck: Rect2 = ui.rect("player_deck")
	var slot: Dictionary = _slots[id]
	card_frame.position = deck.position
	card_frame.rotation_degrees = 0.0
	card_frame.scale = Vector2.ONE * TRAVEL_SCALE
	var slide: Tween = step_tween(step).set_parallel()
	slide.tween_property(card_frame, "position", _position_for(slot), d_eff)
	slide.tween_property(card_frame, "rotation_degrees", float(slot.rot), d_eff)
	slide.tween_property(card_frame, "scale", Vector2.ONE, d_eff)


## `play_card`: the card travels to the table's centre and leaves at the step's final.
func _travel_out(step: AnimStep, id: int, d_eff: float) -> void:
	if not _cards.has(id):
		return
	_travelling[id] = true
	var card_frame: CardFrame = _cards[id]
	var target: Vector2 = ui.rect("player_row").get_center() - Vector2(float(_cfg.card_w), float(_cfg.card_h)) / 2.0
	var slide: Tween = step_tween(step).set_parallel()
	slide.tween_property(card_frame, "position", target, d_eff)
	slide.tween_property(card_frame, "rotation_degrees", 0.0, d_eff)
	slide.tween_property(card_frame, "scale", Vector2.ONE * TRAVEL_SCALE, d_eff)


func _cost_of(card: Dictionary) -> int:
	if card.has("effective_cost"):
		return int(card.effective_cost)
	var face: Dictionary = ui.query.card_text(str(card.get("card_id", "")))
	return int(face.get("cost", 0)) if face.get("cost") != null else 0


func _in_view_hand(id: int) -> bool:
	for card_entry: Dictionary in _view.side(&"player").hand:
		if int(card_entry.instance_id) == id:
			return true
	return false
