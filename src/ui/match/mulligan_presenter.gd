## The mulligan screen (ADR-0009 `mulligan_screen.tscn`; match-ui U8; mulligan.md). Opens
## on the `mulligan_offered` step over the dimmed table (`MatchView` steps the fill, so
## portraits and the passive plate keep their contrast) and offers any subset: replacing
## none or all is legal (DD-M05), so Confirm is always enabled. Cards toggle by click
## or number key, and Confirm sends `mulligan(keep_mask)` through the router. It has no
## cancel. Effective costs come from one `MatchQuery.hand` read at open (§8).
## [codeblock]
## mulligan.confirmed.connect(func(mask: Array) -> void: router.intent(&"mulligan_confirm", {"keep_mask": mask}))
## [/codeblock]
class_name MulliganPresenter
extends Presenter

## Confirm was pressed; [param keep_mask] holds one bool per card, `true` = keep.
signal confirmed(keep_mask: Array)

const CARD_FRAME_SCENE: PackedScene = preload("res://src/ui/common/card_frame.tscn")
const TITLE_FONT_PX: int = 28
const BODY_FONT_PX: int = 16
const PILL_FONT_PX: int = 14
const REPLACE_ALPHA: float = 0.45
const FLIP_HALF: float = 0.5
## The number row: `1`–`9`, then `0` for the tenth card (mulligan.md §7.2).
const NUMBER_KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]

var _view: MatchViewState = null
var _cfg: Dictionary = {}
var _title: Label = null
var _sub: Label = null
var _status: Label = null
var _confirm: Button = null
var _ids: Array[int] = []
var _cards: Array[CardFrame] = []
var _pills: Array[Button] = []
var _marks: Array[Label] = []
var _keep: Array[bool] = []
var _rests: Array[Vector2] = []
var _open: bool = false
var _committed: bool = false


## Builds the fixed parts of the screen.
func setup(context: MatchUiContext) -> void:
	super(context)
	_cfg = ui.config.mulligan
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title = _label(TITLE_FONT_PX, "text_light")
	_sub = _label(BODY_FONT_PX, "text_muted")
	_status = _label(BODY_FONT_PX, "text_light")
	_confirm = Button.new()
	_confirm.custom_minimum_size = Vector2(float(_cfg.confirm_w), float(_cfg.confirm_h))
	_confirm.size = _confirm.custom_minimum_size
	_confirm.focus_mode = Control.FOCUS_NONE
	var outline := StyleBoxFlat.new()
	outline.bg_color = ui.color("table_dark")
	outline.set_border_width_all(int(ui.config.targeting.outline_px))
	outline.border_color = ui.color("state_actionable")
	outline.set_corner_radius_all(4)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		_confirm.add_theme_stylebox_override(state, outline)
	_confirm.add_theme_color_override("font_color", ui.color("text_light"))
	_confirm.pressed.connect(confirm)
	add_child(_confirm)


## Stores the projection [method sync_report] compares against.
func bind(view_state: MatchViewState) -> void:
	_view = view_state


func owns(_entity_ids: Array[int]) -> bool:
	return false


func claims(step: AnimStep) -> bool:
	return step.kind == AnimStep.MULLIGAN_OPEN or step.kind == AnimStep.MULLIGAN_FLIP


func on_step_started(step: AnimStep, d_eff: float) -> void:
	if step.kind == AnimStep.MULLIGAN_FLIP:
		_flip(step, d_eff)


func apply_final(step: AnimStep) -> void:
	end_step(step)


func present(state: Dictionary) -> void:
	var offered: Variant = state.get("pending_mulligan")
	if offered != null and not _open:
		_open_screen(offered)
	elif offered == null and _open:
		_close_screen()


func sync_report() -> Array[String]:
	var report: Array[String] = []
	if _open != (_view.pending_mulligan != null):
		report.append("mulligan open: shows %s, view-state %s" % [str(_open), str(_view.pending_mulligan != null)])
	return report


## True while the screen takes input.
func is_open() -> bool:
	return _open and not _committed


## The current mask, one bool per offered card, `true` = keep.
func keep_mask() -> Array[bool]:
	return _keep.duplicate()


## Flips card [param index] between keep and replace; a click and `1`–`0` both land here.
func toggle(index: int) -> void:
	if not is_open() or index < 0 or index >= _keep.size():
		return
	_keep[index] = not _keep[index]
	_refresh(index)


## `1`–`0` toggle their card; a key past the hand is ignored. True when it was a card key.
func handle_key(keycode: Key) -> bool:
	var index: int = NUMBER_KEYS.find(keycode)
	if index < 0:
		return false
	toggle(index)
	return true


## Sends the mask once. A second press does nothing (mulligan.md §6 `Committed`).
func confirm() -> void:
	if not is_open():
		return
	_committed = true
	confirmed.emit(_keep.duplicate())


## A refused mulligan (a race) gives the screen back with its toggles as they were.
func on_rejected() -> void:
	_committed = false


func _open_screen(offered: Variant) -> void:
	_open = true
	_committed = false
	visible = true
	_clear_cards()
	_ids.clear()
	for id: Variant in offered:
		_ids.append(int(id))
	var n: int = _ids.size()
	var hand: Array = ui.query.hand(MatchViewState.SIDE_PLAYER)
	var fit: Dictionary = _fit(n)
	var scale_by: float = float(fit.scale)
	var card_size: Vector2 = CardFrame.SIZE * scale_by
	var gap: float = float(fit.gap)
	var left: float = float(_cfg.band_cx) - (n * card_size.x + maxi(n - 1, 0) * gap) / 2.0
	var top: float = float(_cfg.row_top)
	for i: int in n:
		var entry: Dictionary = _hand_entry(hand, _ids[i])
		var frame: CardFrame = CARD_FRAME_SCENE.instantiate()
		add_child(frame)
		frame.configure(ui)
		frame.scale = Vector2.ONE * scale_by
		frame.position = Vector2(left + i * (card_size.x + gap), top)
		frame.show_card(ui.card_face(str(entry.get("card_id", ""))), int(entry.get("effective_cost", 0)))
		frame.mouse_filter = Control.MOUSE_FILTER_STOP
		frame.gui_input.connect(_on_card_input.bind(i))
		_cards.append(frame)
		_rests.append(frame.position)
		_keep.append(true)
		_marks.append(_replace_mark(frame))
		_pills.append(_pill(i, frame.position, card_size))
	_layout_text(n, top + (card_size.y if n > 0 else CardFrame.SIZE.y * scale_by))
	for i: int in n:
		_refresh(i)
	if n == 0:
		_refresh_status()


func _close_screen() -> void:
	_open = false
	visible = false
	_clear_cards()


func _clear_cards() -> void:
	for node: Control in _cards:
		node.queue_free()
	for node: Control in _pills:
		node.queue_free()
	_cards.clear()
	_pills.clear()
	_marks.clear()
	_keep.clear()
	_rests.clear()


func _fit(n: int) -> Dictionary:
	var scales: Array = _cfg.scales
	for fit: Dictionary in scales:
		if n <= int(fit.max_n):
			return fit
	return scales[scales.size() - 1]


func _layout_text(n: int, row_bottom: float) -> void:
	var cx: float = float(_cfg.band_cx)
	_place_label(_title, tr("mulligan.title"), cx, float(_cfg.title_top))
	_place_label(_sub, tr("mulligan.sub" if n > 0 else "mulligan.sub_empty"), cx, float(_cfg.sub_top))
	var status_top: float = row_bottom + float(_cfg.pill_gap) + float(_cfg.pill_h) + float(_cfg.status_gap)
	_place_label(_status, "", cx, status_top)
	_confirm.text = tr("mulligan.confirm" if n > 0 else "mulligan.start")
	_confirm.position = Vector2(cx - float(_cfg.confirm_w) / 2.0, status_top + float(_cfg.status_h) + float(_cfg.confirm_gap))


func _place_label(label: Label, text: String, centre_x: float, top: float) -> void:
	var band: float = ui.rect("viewport").size.x
	label.text = text
	label.position = Vector2(centre_x - band / 2.0, top)
	label.size = Vector2(band, 0)


func _refresh(index: int) -> void:
	var keep: bool = _keep[index]
	_pills[index].text = tr("mulligan.keep" if keep else "mulligan.replace")
	_marks[index].visible = not keep
	_cards[index].position = _rests[index] + Vector2(0, 0.0 if keep else float(_cfg.replace_drop_px))
	_refresh_status()


func _refresh_status() -> void:
	var total: int = _keep.size()
	var replacing: int = _keep.count(false)
	if total == 0:
		_status.text = ""
	elif replacing == 0:
		_status.text = tr("mulligan.status_keep_all") % total
	elif replacing == total:
		_status.text = tr("mulligan.status_all") % total
	else:
		_status.text = tr("mulligan.status_some") % [replacing, total]


## `mulligan_resolved`: each replaced card flips in its own slot to the card drawn for it.
func _flip(step: AnimStep, d_eff: float) -> void:
	var display: Dictionary = step.data.get("display", {})
	var hand: Array = display.get("player", {}).get("hand", [])
	var drawn: int = hand.size() - step.entity_ids.size()
	for i: int in _ids.size():
		if not step.entity_ids.has(_ids[i]) or drawn >= hand.size():
			continue
		var card: Dictionary = hand[drawn]
		drawn += 1
		var frame: CardFrame = _cards[i]
		var full: float = frame.scale.x
		frame.pivot_offset = frame.size / 2.0
		var flip: Tween = step_tween(step)
		flip.tween_property(frame, "scale:x", 0.0, d_eff * FLIP_HALF)
		flip.tween_callback(_show_new_face.bind(i, card))
		flip.tween_property(frame, "scale:x", full, d_eff * FLIP_HALF)


func _show_new_face(index: int, card: Dictionary) -> void:
	_marks[index].visible = false
	var face: Dictionary = ui.card_face(str(card.get("card_id", "")))
	_cards[index].show_card(face, int(card.get("effective_cost", face.get("cost", 0))))


func _on_card_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		toggle(index)


func _hand_entry(hand: Array, id: int) -> Dictionary:
	for card: Dictionary in hand:
		if int(card.instance_id) == id:
			return card
	return {}


func _replace_mark(frame: CardFrame) -> Label:
	var mark := Label.new()
	mark.text = "✕"
	mark.position = CardFrame.ART_RECT.position
	mark.size = CardFrame.ART_RECT.size
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.add_theme_font_size_override("font_size", TITLE_FONT_PX)
	mark.add_theme_color_override("font_color", ui.color("text_light"))
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(mark)
	return mark


func _pill(index: int, card_at: Vector2, card_size: Vector2) -> Button:
	var pill := Button.new()
	pill.position = card_at + Vector2(0, card_size.y + float(_cfg.pill_gap))
	pill.custom_minimum_size = Vector2(card_size.x, float(_cfg.pill_h))
	pill.size = pill.custom_minimum_size
	pill.focus_mode = Control.FOCUS_NONE
	pill.add_theme_font_size_override("font_size", PILL_FONT_PX)
	pill.add_theme_color_override("font_color", ui.color("text_light"))
	var style := StyleBoxFlat.new()
	style.bg_color = ui.color("ink")
	style.set_corner_radius_all(int(_cfg.pill_h) / 2)
	for state: String in ["normal", "hover", "pressed"]:
		pill.add_theme_stylebox_override(state, style)
	pill.pressed.connect(toggle.bind(index))
	add_child(pill)
	return pill


func _label(font_px: int, token: String) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_px)
	label.add_theme_color_override("font_color", ui.color(token))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label
