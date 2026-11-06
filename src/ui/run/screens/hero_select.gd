## `hero_select` (run-ui U2, U7; hero-select.md §5): available heroes as lit panels at
## F4's slots, locked ones as grey silhouettes with their hint, the seed field with its
## echo, Start, Back and the deck drawer. Selection is local: no command until Start.
## Start is disabled while a locked panel holds focus (AC-3), and `start_run` carries the
## raw seed text, never the echo (AC-18).
extends Screen

const PANEL_SIZE: Vector2 = Vector2(340, 340)
const PANEL_Y: float = 72.0
const LOCKED_Y: float = 428.0
const LOCKED_H: float = 88.0
const LIFT_PX: float = 8.0
const SEED_LABEL_RECT: Rect2 = Rect2(280, 540, 260, 44)
const SEED_RECT: Rect2 = Rect2(548, 540, 332, 44)
const ECHO_RECT: Rect2 = Rect2(548, 584, 332, 24)
const BACK_POS: Vector2 = Vector2(40, 640)
const START_POS: Vector2 = Vector2(560, 640)
const DECK_POS: Vector2 = Vector2(1080, 640)
const PORTRAIT: Vector2 = Vector2(120, 160)
## §5.2's 125 % / 150 % stack: the plate shrinks and the full text moves to the reading panel.
const SCALED_PLATE_H: float = 56.0
const FULL_SCALE: float = 1.5
const LOCKED_H_FULL: float = 112.0
const SEED_SHIFT_FULL: float = 24.0

var _model: Dictionary = {}
var _heroes: Array = []
var _panels: Array[OptionPanel] = []
var _locked: Array[OptionPanel] = []
var _selected: int = -1
var _locked_focused: bool = false
var _start: Button = null
var _deck: Button = null
var _seed: LineEdit = null
var _echo: Label = null
var _drawers: Array[DeckDrawer] = []
var _scale: float = 1.0
var _reading: UiTooltip = null


func bind(model: Dictionary) -> void:
	clear()
	_model = model
	_heroes = model.get("heroes", [])
	_panels.clear()
	_locked.clear()
	_drawers.clear()
	_scale = float(model.get("text_scale", 1.0))
	cancel_intent = &"back"
	add_child(UiKit.backdrop(color("bg_edge")))
	var title: Label = UiKit.label(tr("hero.title"), RunUiTheme.LABEL_TITLE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	UiKit.place(title, Rect2(0, 8, float(cfg.design_width), 48))
	for i: int in _heroes.size():
		_add_hero(i, _heroes[i])
	var locked_rows: Array = model.get("locked", [])
	for i: int in locked_rows.size():
		_add_locked(i, locked_rows[i], locked_rows.size())
	_add_seed_row()
	_add_actions()
	_reading = UiTooltip.new()
	add_child(_reading)
	var reading: Dictionary = cfg.reading_panel
	_reading.configure(color("parchment"), color("text_ink"), roundi(float(reading.font_px) * _scale), float(reading.max_w), get_viewport_rect())
	_select_id(str(model.get("selected", "")))
	var order: Array[Control] = []
	order.assign(_panels)
	order.append_array(_locked)
	if _seed != null:
		order.append(_seed)
	order.append_array([_start, _back_button(), _deck])
	UiKit.chain_focus(order)


func default_focus() -> Control:
	return _start if _selected >= 0 else (_panels[0] if not _panels.is_empty() else null)


func close_drawer() -> bool:
	for drawer: DeckDrawer in _drawers:
		if drawer.is_open():
			drawer.toggle()
			_deck.grab_focus()
			return true
	return false


func handle_option_key(index: int) -> void:
	var all: Array[OptionPanel] = _panels.duplicate()
	if index < all.size():
		all[index].grab_focus()


func set_committed(on: bool) -> void:
	super.set_committed(on)
	_refresh_start()


func _add_hero(index: int, hero: Dictionary) -> void:
	var count: int = _heroes.size()
	var x: float = RunUiConfig.slot_x(index, count, int(PANEL_SIZE.x), int(cfg.option_gap.bundle), int(cfg.design_width))
	var panel: OptionPanel = OptionPanel.new()
	panel.setup(index, LIFT_PX)
	add_child(panel)
	UiKit.place(panel, Rect2(Vector2(x, PANEL_Y), PANEL_SIZE))
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color(str(hero.primary))
	style.border_color = color(str(hero.secondary))
	style.set_border_width_all(2)
	style.set_corner_radius_all(RunUiTheme.CORNER_PX)
	style.set_content_margin_all(RunUiTheme.PANEL_PADDING_PX * (2 if _scale < FULL_SCALE else 1))
	panel.add_theme_stylebox_override(&"panel", style)
	var scroll: ScrollContainer = UiKit.scroll()
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(scroll)
	var column: VBoxContainer = UiKit.vbox(6 if _scale < FULL_SCALE else 2)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(column)
	var top: HBoxContainer = UiKit.hbox(12)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(top)
	top.add_child(UiKit.portrait(color(str(hero.secondary)), str(hero.initial), PORTRAIT))
	var facts: VBoxContainer = UiKit.vbox(4)
	facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(facts)
	facts.add_child(UiKit.label(str(hero.name), &"", true))
	var health: Label = UiKit.label(tr("hero.health").format({"n": hero.health}), RunUiTheme.LABEL_SMALL)
	if _scale < FULL_SCALE:
		facts.add_child(health)
	facts.add_child(UiKit.label(str(hero.identity), RunUiTheme.LABEL_SMALL, true))
	var scaled: bool = _scale > 1.0
	var blurb: Label = UiKit.label(str(hero.blurb), RunUiTheme.LABEL_SMALL, _scale < FULL_SCALE)
	blurb.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var stats: Label = UiKit.label(str(hero.stats_short if _scale >= FULL_SCALE else hero.stats_line), RunUiTheme.LABEL_SMALL)
	(column if scaled else facts).add_child(blurb)
	if _scale >= FULL_SCALE:
		var line: HBoxContainer = UiKit.hbox(16)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(health)
		line.add_child(stats)
		column.add_child(line)
	else:
		(column if scaled else facts).add_child(stats)
	var plate: PanelContainer = UiKit.panel(RunUiTheme.PANEL_PARCHMENT)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(plate)
	var power_text: String = tr("hero.power").format({"cost": hero.power_cost, "name": hero.power_name, "text": hero.power_text})
	var power: Label = UiKit.label(power_text, RunUiTheme.LABEL_INK, true)
	plate.add_child(power)
	if scaled:
		plate.custom_minimum_size.y = SCALED_PLATE_H
		plate.clip_contents = true
		power.max_lines_visible = 1
		power.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		panel.highlighted.connect(_show_reading.bind(power_text, panel))
		panel.unhighlighted.connect(_hide_reading)
	column.add_child(UiKit.label(_curve_text(hero.curve), RunUiTheme.LABEL_SMALL))
	panel.activated.connect(_on_hero_activated)
	panel.double_activated.connect(func(i: int) -> void:
		_select(i)
		_on_start())
	panel.highlighted.connect(func(_i: int) -> void:
		_locked_focused = false
		_refresh_start())
	_panels.append(panel)
	var drawer: DeckDrawer = DeckDrawer.new()
	add_child(drawer)
	drawer.show_rows(tr("hero.deck_title").format({"n": (hero.deck_rows as Array).size()}), hero.deck_rows, [])
	_drawers.append(drawer)


# §5.2: focus or hover opens the whole power text, under the panel it belongs to.
func _show_reading(_index: int, text: String, panel: OptionPanel) -> void:
	_reading.show_below(Vector2(panel.get_global_rect().get_center().x, panel.get_global_rect().end.y), text)


func _hide_reading(_index: int) -> void:
	_reading.hide_now()


func _curve_text(curve: Array) -> String:
	var parts: PackedStringArray = []
	for cost: int in curve.size():
		parts.append("%d:%d" % [cost, int(curve[cost])])
	return tr("hero.curve").format({"list": "  ".join(parts)})


func _add_locked(index: int, row: Dictionary, count: int) -> void:
	var x: float = RunUiConfig.slot_x(index, count, int(PANEL_SIZE.x), int(cfg.option_gap.bundle), int(cfg.design_width))
	var panel: OptionPanel = OptionPanel.new()
	panel.setup(index, 0.0)
	panel.theme_type_variation = RunUiTheme.PANEL_NEUTRAL
	add_child(panel)
	UiKit.place(panel, Rect2(x, LOCKED_Y, PANEL_SIZE.x, LOCKED_H_FULL if _scale >= FULL_SCALE else LOCKED_H))
	var column: VBoxContainer = UiKit.vbox(2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	column.add_child(UiKit.label(tr("hero.locked").format({"name": row.name})))
	var hint: String = str(row.get("hint", ""))
	if not hint.is_empty():
		column.add_child(UiKit.label(hint, RunUiTheme.LABEL_SMALL, true))
	panel.highlighted.connect(func(_i: int) -> void:
		_locked_focused = true
		_refresh_start())
	panel.unhighlighted.connect(func(_i: int) -> void:
		_locked_focused = false
		_refresh_start())
	_locked.append(panel)


func _add_seed_row() -> void:
	_seed = null
	if not bool(_model.get("allow_custom_seed", false)):
		return
	var label: Label = UiKit.label(tr("hero.seed"))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(label)
	var shift := Vector2(0, SEED_SHIFT_FULL if _scale >= FULL_SCALE else 0.0)
	UiKit.place(label, Rect2(SEED_LABEL_RECT.position + shift, SEED_LABEL_RECT.size))
	_seed = LineEdit.new()
	_seed.placeholder_text = tr("hero.seed_placeholder")
	add_child(_seed)
	UiKit.place(_seed, Rect2(SEED_RECT.position + shift, SEED_RECT.size))
	_echo = UiKit.label(tr("hero.seed_random"), RunUiTheme.LABEL_SMALL)
	add_child(_echo)
	UiKit.place(_echo, Rect2(ECHO_RECT.position + shift, ECHO_RECT.size))
	_seed.text_changed.connect(_on_seed_changed)
	_seed.text_submitted.connect(func(_text: String) -> void: _on_start())


func _on_seed_changed(text: String) -> void:
	var preview: Callable = _model.get("seed_preview", Callable())
	var echo: String = str(preview.call(text)) if preview.is_valid() else ""
	_echo.text = tr("hero.seed_echo").format({"hex": echo}) if not echo.is_empty() else tr("hero.seed_random")


func _add_actions() -> void:
	var back: Button = UiKit.button(tr("common.back"))
	back.name = "Back"
	back.pressed.connect(send.bind(&"back", {}))
	add_child(back)
	UiKit.place(back, Rect2(BACK_POS, back.custom_minimum_size))
	_start = UiKit.button(tr("hero.start"), true)
	_start.pressed.connect(_on_start)
	add_child(_start)
	UiKit.place(_start, Rect2(START_POS, _start.custom_minimum_size))
	_deck = UiKit.button("")
	_deck.pressed.connect(_toggle_deck)
	add_child(_deck)
	UiKit.place(_deck, Rect2(DECK_POS, _deck.custom_minimum_size))


func _back_button() -> Control:
	return get_node("Back") as Control


func _on_hero_activated(index: int) -> void:
	if index == _selected:
		_on_start()
	else:
		_select(index)


func _select_id(id: String) -> void:
	for i: int in _heroes.size():
		if str(_heroes[i].id) == id:
			_select(i)
			return
	_refresh_start()


func _select(index: int) -> void:
	_selected = index
	for i: int in _panels.size():
		_panels[i].modulate.a = 1.0 if i == index else UiKit.DIM_ALPHA + (1.0 - UiKit.DIM_ALPHA) / 2.0
	_deck.text = tr("hero.deck").format({"n": (_heroes[index].deck_rows as Array).size()})
	_refresh_start()


func _refresh_start() -> void:
	_start.disabled = _selected < 0 or _locked_focused or _committed
	_deck.disabled = _selected < 0


func _toggle_deck() -> void:
	if _selected >= 0:
		_drawers[_selected].toggle()


func _on_start() -> void:
	if _selected >= 0 and not _locked_focused:
		send(&"start_run", {"hero_id": str(_heroes[_selected].id), "seed_input": _seed.text if _seed != null else ""})
