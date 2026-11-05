## `draft_treasure` and `draft_bundle` (run-ui U2, U8, F4; draft-picker.md §5): up to
## three options at the F4 slots, dimmed placeholders for the missing ones, the hint
## under the focused option, Pick, "Take nothing" under `allow_skip`, the deck drawer and
## the strip. Nothing is focused on open (U3): `Tab` enters at option 1. `Enter` on an
## option selects it, again confirms; a double click does both. Pick is dim until an
## option is held. A missing-id frame is not pickable (AC-21).
extends Screen

const HEADER_Y: float = 200.0
const TREASURE_H: float = 210.0
const BUNDLE_H: float = 320.0
const ROW_H: float = 64.0
## From a bundle panel's top to its first card row (draft-picker.md §5.1).
const ROW_TOP: float = 76.0
const HINT_RECT: Rect2 = Rect2(0, 462, 1280, 24)
const HINT2_RECT: Rect2 = Rect2(0, 488, 1280, 24)
const SKIP_POS: Vector2 = Vector2(40, 640)
const PICK_POS: Vector2 = Vector2(560, 640)
const DECK_POS: Vector2 = Vector2(1080, 640)
const MENU_RECT: Rect2 = Rect2(1176, 4, 80, 44)
const LIFT_PX: float = 8.0
const PREVIEW_GAP: float = 8.0

var _options: Array = []
var _panels: Array[OptionPanel] = []
var _selected: int = -1
var _held: int = -1
var _pick: Button = null
var _deck: Button = null
var _hint: Label = null
var _hint2: Label = null
var _drawer: DeckDrawer = null
var _preview: CardPreview = null
var _reveal_tween: Tween = null


func bind(model: Dictionary) -> void:
	clear()
	cancel_intent = &"open_pause"
	_options = model.get("options", [])
	_panels.clear()
	_selected = -1
	_held = -1
	add_child(UiKit.backdrop(color("bg_edge")))
	var bundle: bool = str(model.get("kind")) == DraftRecord.KIND_BUNDLE
	_add_title(model, bundle)
	var strip: ProgressStrip = ProgressStrip.new()
	add_child(strip)
	strip.show_strip(cfg, model.get("strip", {}))
	var slots: int = int(model.get("slots", _options.size()))
	var width: int = int(cfg.option_w.bundle if bundle else cfg.option_w.treasure)
	var gap: int = int(cfg.option_gap.bundle if bundle else cfg.option_gap.treasure)
	var top: float = float(cfg.option_y.bundle if bundle else cfg.option_y.treasure)
	var height: float = BUNDLE_H if bundle else TREASURE_H
	for slot: int in slots:
		var rect: Rect2 = Rect2(RunUiConfig.slot_x(slot, slots, width, gap, int(cfg.design_width)), top, width, height)
		if slot < _options.size():
			_add_option(slot, _options[slot], rect, bundle)
		else:
			_add_placeholder(rect)
	var reason: String = str(model.get("short_reason", ""))
	if not reason.is_empty():
		var line: Label = UiKit.label(reason, RunUiTheme.LABEL_MUTED)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(line)
		UiKit.place(line, Rect2(0, HEADER_Y if not bundle else HEADER_Y / 2.0 + 8.0, float(cfg.design_width), 24))
	_hint = _centred_label(HINT_RECT)
	_hint2 = _centred_label(HINT2_RECT)
	_add_actions(model, strip)
	_preview = CardPreview.new()
	add_child(_preview)
	_preview.setup()
	_refresh_pick()
	_reveal(int(model.get("reveal_step_ms", 0)))


func default_focus() -> Control:
	return null


func tab_entry() -> Control:
	return _panels[0] if not _panels.is_empty() else _pick


func close_drawer() -> bool:
	if _drawer.is_open():
		_drawer.toggle()
		_deck.grab_focus()
		return true
	return false


func handle_option_key(index: int) -> void:
	if index < _panels.size():
		_panels[index].grab_focus()


func set_committed(on: bool) -> void:
	super.set_committed(on)
	for i: int in _panels.size():
		_panels[i].modulate.a = UiKit.DIM_ALPHA if on and i != _current() else 1.0
	_refresh_pick()


func on_revealed() -> void:
	if _reveal_tween != null:
		_reveal_tween.kill()
		_reveal_tween = null
	for panel: OptionPanel in _panels:
		panel.modulate.a = 1.0


## F2's `draft_reveal`: the options fade in one [param step_ms] after another. Any input
## ends it with the transition, through [method on_revealed].
func _reveal(step_ms: int) -> void:
	if step_ms <= 0 or _panels.is_empty():
		return
	_reveal_tween = create_tween().set_parallel()
	var step_s: float = step_ms / RunUiConfig.MS_PER_S
	for i: int in _panels.size():
		_panels[i].modulate.a = 0.0
		_reveal_tween.tween_property(_panels[i], "modulate:a", 1.0, step_s).set_delay(i * step_s)


func _add_title(model: Dictionary, bundle: bool) -> void:
	var floor_label: Label = UiKit.label(tr("draft.floor").format({"n": model.get("floor", 1)}), RunUiTheme.LABEL_MUTED)
	add_child(floor_label)
	UiKit.place(floor_label, Rect2(40, 12, 160, 24))
	var key: String = "draft.step.bundle_only"
	if bool(model.get("two_step", false)):
		key = "draft.step.bundle" if bundle else "draft.step.treasure"
	var title: Label = UiKit.label(tr(key), RunUiTheme.LABEL_TITLE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	UiKit.place(title, Rect2(0, 4, float(cfg.design_width), 44))


func _add_option(index: int, option: Dictionary, rect: Rect2, bundle: bool) -> void:
	var panel: OptionPanel = OptionPanel.new()
	panel.setup(index, LIFT_PX)
	panel.theme_type_variation = RunUiTheme.PANEL_LIT if bundle else RunUiTheme.PANEL_PARCHMENT
	add_child(panel)
	UiKit.place(panel, rect)
	panel.clip_contents = true
	var column: VBoxContainer = UiKit.vbox(4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	if bool(option.get("missing", false)):
		column.add_child(UiKit.label(str(option.name), RunUiTheme.LABEL_DANGER, true))
		panel.focus_mode = Control.FOCUS_NONE
		panel.modulate.a = UiKit.DIM_ALPHA
		return
	if bundle:
		_fill_bundle(column, option, index, rect)
	else:
		column.add_child(UiKit.label(str(option.name), RunUiTheme.LABEL_INK, true))
		column.add_child(UiKit.label(str(option.rarity), RunUiTheme.LABEL_INK))
		column.add_child(UiKit.label(str(option.text), RunUiTheme.LABEL_INK, true))
	panel.activated.connect(_on_activated)
	panel.double_activated.connect(_confirm)
	panel.highlighted.connect(_on_highlighted)
	panel.unhighlighted.connect(_on_unhighlighted)
	_panels.append(panel)


func _fill_bundle(column: VBoxContainer, option: Dictionary, index: int, rect: Rect2) -> void:
	column.add_child(UiKit.label(str(option.name), RunUiTheme.LABEL_HEADING))
	column.add_child(UiKit.label(str(option.pitch), RunUiTheme.LABEL_SMALL, true))
	var scroll: ScrollContainer = UiKit.scroll()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var rows: VBoxContainer = UiKit.vbox(8)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	var cards: Array = option.get("cards", [])
	for i: int in cards.size():
		var card: Dictionary = cards[i]
		var row: PanelContainer = UiKit.panel(RunUiTheme.PANEL_DARK)
		row.custom_minimum_size.y = ROW_H
		UiKit.focus_row(row)
		row.add_child(UiKit.label("(%s) %s" % [card.cost, card.name], RunUiTheme.LABEL_SMALL, true))
		rows.add_child(row)
		var centre_y: float = rect.position.y + ROW_TOP + ROW_H / 2.0 + i * (ROW_H + 8.0)
		var left: float = _preview_left(index, rect)
		row.mouse_entered.connect(_show_preview.bind(card, left, centre_y))
		row.focus_entered.connect(_show_preview.bind(card, left, centre_y))
		row.mouse_exited.connect(_hide_preview)
		row.focus_exited.connect(_hide_preview)


func _preview_left(index: int, rect: Rect2) -> float:
	match index:
		0:
			return rect.end.x + PREVIEW_GAP
		1:
			return rect.get_center().x - CardPreview.SIZE_PX.x / 2.0
	return rect.position.x - PREVIEW_GAP - CardPreview.SIZE_PX.x


func _add_placeholder(rect: Rect2) -> void:
	var box: PanelContainer = UiKit.panel(RunUiTheme.PANEL_DARK)
	box.modulate.a = UiKit.DIM_ALPHA
	add_child(box)
	UiKit.place(box, rect)


func _centred_label(rect: Rect2) -> Label:
	var label: Label = UiKit.label("")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	UiKit.place(label, rect)
	return label


func _add_actions(model: Dictionary, strip: ProgressStrip) -> void:
	_pick = UiKit.button(tr("draft.pick"), true)
	_pick.pressed.connect(func() -> void: _confirm(_current()))
	add_child(_pick)
	UiKit.place(_pick, Rect2(PICK_POS, _pick.custom_minimum_size))
	var order: Array[Control] = []
	order.assign(_panels)
	order.append(_pick)
	if bool(model.get("allow_skip", false)):
		var skip: Button = UiKit.button(tr("draft.skip"))
		skip.pressed.connect(send.bind(&"skip_pick", {}))
		add_child(skip)
		UiKit.place(skip, Rect2(SKIP_POS, skip.custom_minimum_size))
		order.append(skip)
	_deck = UiKit.button(tr("draft.deck").format({"n": model.get("deck_size", 0)}))
	add_child(_deck)
	UiKit.place(_deck, Rect2(DECK_POS, _deck.custom_minimum_size))
	order.append(_deck)
	_drawer = DeckDrawer.new()
	add_child(_drawer)
	_drawer.show_rows(tr("draft.deck_title").format({"n": model.get("deck_size", 0)}), model.get("deck_rows", []), model.get("treasures", []))
	_deck.pressed.connect(_drawer.toggle)
	var menu: Button = UiKit.button(tr("common.menu"))
	menu.custom_minimum_size = MENU_RECT.size
	menu.pressed.connect(send.bind(&"open_pause", {}))
	add_child(menu)
	UiKit.place(menu, MENU_RECT)
	order.append(menu)
	order.append_array(strip.focus_stops())
	UiKit.chain_focus(order)


func _current() -> int:
	return _selected if _selected >= 0 else _held


func _on_activated(index: int) -> void:
	if index == _selected:
		_confirm(index)
		return
	_selected = index
	_refresh_pick()


func _confirm(index: int) -> void:
	if index >= 0:
		_selected = index
		send(&"pick", {"index": index})


func _on_highlighted(index: int) -> void:
	_held = index
	var option: Dictionary = _options[index]
	_hint.text = str(option.get("hint", ""))
	_hint2.text = str(option.get("hint2", ""))
	_refresh_pick()


func _on_unhighlighted(index: int) -> void:
	if _held == index:
		_held = -1
		_hint.text = ""
		_hint2.text = ""
		_refresh_pick()


func _refresh_pick() -> void:
	_pick.disabled = _current() < 0 or _committed


func _show_preview(card: Dictionary, left: float, centre_y: float) -> void:
	_preview.show_card(card, left, centre_y)


func _hide_preview() -> void:
	_preview.visible = false
