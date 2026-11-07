## `hero_select` (run-ui U2, U7; hero-select.md): a scrolling roster of class tabs, any
## number of them, and one detail page for the focused class with its three powers. A
## locked class stays focusable and shows what earns it; a locked power shows its
## condition and cannot be chosen. Selection is local: no command until Start, and
## `start_run` carries the raw seed text, never the echo (AC-18).
extends Screen

const ROSTER_RECT: Rect2 = Rect2(40, 72, 116, 448)
const DETAIL_RECT: Rect2 = Rect2(172, 72, 1068, 448)
const TAB_SIZE: Vector2 = Vector2(92, 62)
const TAB_GAP: int = 6
const PORTRAIT: Vector2 = Vector2(120, 160)
const LEFT_W: float = 480.0
const COLUMN_GAP: int = 24
const BARS_H: float = 112.0
const DETAIL_PADDING_PX: int = 16
const PANEL_ALPHA: float = 0.92
const HAIRLINE_ALPHA: float = 0.55
const SELECTED_BORDER_PX: int = 2
const IDENTITY_RULE_PX: float = 3.0
const PLATE_PADDING_PX: int = 12
## A tab that is not selected shades down; a locked class shades further.
const TAB_REST: Color = Color(0.68, 0.68, 0.68)
const TAB_LOCKED: Color = Color(0.4, 0.4, 0.4)
## A locked power's button reads as faint ink.
const POWER_LOCKED_ALPHA: float = 0.6
const SEED_LABEL_RECT: Rect2 = Rect2(280, 540, 260, 44)
const SEED_RECT: Rect2 = Rect2(548, 540, 332, 44)
const ECHO_RECT: Rect2 = Rect2(548, 584, 332, 24)
const BACK_POS: Vector2 = Vector2(40, 640)
const START_POS: Vector2 = Vector2(560, 640)
const DECK_POS: Vector2 = Vector2(1080, 640)
const HERO_STING: String = "hero_sting_%s"

var _model: Dictionary = {}
## Unlocked classes first, then locked ones. A locked row has no `powers`.
var _rows: Array = []
var _tabs: Array[OptionPanel] = []
var _tab_styles: Array[StyleBoxFlat] = []
var _tab_art: Array[Control] = []
var _current: int = -1
## class id -> the power chosen for it on this screen.
var _chosen: Dictionary = {}
var _detail: VBoxContainer = null
var _power_buttons: Array[Button] = []
var _plate_text: Label = null
var _start: Button = null
var _deck: Button = null
var _back: Button = null
var _seed: LineEdit = null
var _echo: Label = null
var _drawers: Dictionary = {}
var _scale: float = 1.0


func bind(model: Dictionary) -> void:
	clear()
	_model = model
	_rows = (model.get("heroes", []) as Array) + (model.get("locked", []) as Array)
	_tabs.clear()
	_tab_styles.clear()
	_tab_art.clear()
	_drawers.clear()
	_chosen.clear()
	_current = -1
	_scale = float(model.get("text_scale", 1.0))
	cancel_intent = &"back"
	var backdrop: ColorRect = UiKit.backdrop(color("bg_edge"))
	add_child(backdrop)
	ArtLibrary.shared().mount_fill(backdrop, "table")
	var title: Label = UiKit.label(tr("hero.title"), RunUiTheme.LABEL_TITLE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	UiKit.place(title, Rect2(0, 8, float(cfg.design_width), 48))
	_add_roster()
	_add_detail()
	_add_seed_row()
	_add_actions()
	for row: Dictionary in model.get("heroes", []):
		_chosen[str(row.id)] = str(row.selected_power)
		var drawer: DeckDrawer = DeckDrawer.new()
		add_child(drawer)
		drawer.show_rows(tr("hero.deck_title").format({"n": (row.deck_rows as Array).size()}), row.deck_rows, [])
		_drawers[str(row.id)] = drawer
	_show(_initial_row())


func default_focus() -> Control:
	return _start if not _is_locked() else (_tabs[0] if not _tabs.is_empty() else null)


func close_drawer() -> bool:
	for drawer: DeckDrawer in _drawers.values():
		if drawer.is_open():
			drawer.toggle()
			_deck.grab_focus()
			return true
	return false


func handle_option_key(index: int) -> void:
	if index < _tabs.size():
		_tabs[index].grab_focus()


func set_committed(on: bool) -> void:
	super.set_committed(on)
	_refresh_start()


func _initial_row() -> int:
	var wanted: String = str(_model.get("selected", ""))
	for i: int in _rows.size():
		if str(_rows[i].id) == wanted:
			return i
	return 0 if not _rows.is_empty() else -1


func _is_locked() -> bool:
	return _current < 0 or not (_rows[_current] as Dictionary).has("powers")


func _add_roster() -> void:
	var scroll: ScrollContainer = UiKit.scroll()
	add_child(scroll)
	UiKit.place(scroll, ROSTER_RECT)
	var column: VBoxContainer = UiKit.vbox(TAB_GAP)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	for i: int in _rows.size():
		column.add_child(_tab(i, _rows[i]))


func _tab(index: int, row: Dictionary) -> OptionPanel:
	var tab: OptionPanel = OptionPanel.new()
	tab.setup(index, 0.0)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.set_border_width_all(SELECTED_BORDER_PX)
	style.border_color = Color.TRANSPARENT
	style.set_corner_radius_all(RunUiTheme.CORNER_PX)
	style.set_content_margin_all(SELECTED_BORDER_PX + 1)
	tab.add_theme_stylebox_override(&"panel", style)
	var stamp: Dictionary = ArtLibrary.shared().portrait("heroes", str(row.id))
	var fill: Color = color(str(row.get("primary", "neutral")))
	var art: ColorRect = UiKit.portrait(fill, str(row.get("initial", str(row.name).left(1))), TAB_SIZE, stamp.get("texture"), stamp.get("tint", Color.WHITE))
	tab.add_child(art)
	tab.tooltip_text = str(row.name)
	tab.focus_entered.connect(_show.bind(index))
	tab.double_activated.connect(func(_i: int) -> void: _on_start())
	_tabs.append(tab)
	_tab_styles.append(style)
	_tab_art.append(art)
	return tab


func _add_detail() -> void:
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(color("ink"), PANEL_ALPHA)
	style.border_color = Color(color("neutral"), HAIRLINE_ALPHA)
	style.set_border_width_all(RunUiTheme.BORDER_PX)
	style.set_corner_radius_all(RunUiTheme.CORNER_PX)
	style.set_content_margin_all(DETAIL_PADDING_PX)
	panel.add_theme_stylebox_override(&"panel", style)
	add_child(panel)
	UiKit.place(panel, DETAIL_RECT)
	var scroll: ScrollContainer = UiKit.scroll()
	panel.add_child(scroll)
	_detail = UiKit.vbox(8)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_detail)


func _show(index: int) -> void:
	if index == _current or index < 0:
		return
	var open: bool = _drawers.values().any(func(drawer: DeckDrawer) -> bool: return drawer.is_open())
	_current = index
	var row: Dictionary = _rows[index]
	for i: int in _tabs.size():
		var chosen: bool = i == index
		var locked: bool = not (_rows[i] as Dictionary).has("powers")
		_tab_styles[i].border_color = color("state_actionable") if chosen else Color.TRANSPARENT
		_tab_art[i].modulate = TAB_LOCKED if locked else (Color.WHITE if chosen else TAB_REST)
	for child: Node in _detail.get_children():
		_detail.remove_child(child)
		child.queue_free()
	_power_buttons.clear()
	_plate_text = null
	if _is_locked():
		_fill_locked(row)
	else:
		sfx_requested.emit(StringName(HERO_STING % str(row.id)))
		_fill_hero(row)
		_deck.text = tr("hero.deck").format({"n": (row.deck_rows as Array).size()})
	# Each class has a drawer and Deck toggles the current one, so an open drawer follows.
	for id: String in _drawers:
		(_drawers[id] as DeckDrawer).set_open(open and id == str(row.id))
	_refresh_start()
	_chain()


func _heading(row: Dictionary, band_token: String) -> void:
	_detail.add_child(UiKit.label(str(row.name), RunUiTheme.LABEL_TITLE))
	var band: ColorRect = UiKit.rule(color(band_token))
	band.custom_minimum_size.y = IDENTITY_RULE_PX
	_detail.add_child(band)


func _fill_locked(row: Dictionary) -> void:
	_heading(row, "neutral")
	_detail.add_child(UiKit.label(tr("hero.locked").format({"name": row.name}), RunUiTheme.LABEL_HEADING))
	var hint: String = str(row.get("hint", ""))
	if not hint.is_empty():
		_detail.add_child(UiKit.label(hint, &"", true))


func _fill_hero(row: Dictionary) -> void:
	_heading(row, str(row.secondary))
	var columns: HBoxContainer = UiKit.hbox(COLUMN_GAP)
	columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.add_child(columns)
	columns.add_child(_left_column(row))
	columns.add_child(_right_column(row))


func _left_column(row: Dictionary) -> Control:
	var column: VBoxContainer = UiKit.vbox(8)
	column.custom_minimum_size.x = LEFT_W
	var top: HBoxContainer = UiKit.hbox(16)
	column.add_child(top)
	var stamp: Dictionary = ArtLibrary.shared().portrait("heroes", str(row.id))
	top.add_child(UiKit.portrait(color(str(row.primary)), str(row.initial), PORTRAIT, stamp.get("texture"), stamp.get("tint", Color.WHITE)))
	var facts: VBoxContainer = UiKit.vbox(4)
	facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(facts)
	facts.add_child(UiKit.label(tr("hero.health").format({"n": row.health}), RunUiTheme.LABEL_SMALL))
	facts.add_child(UiKit.label(str(row.identity), RunUiTheme.LABEL_SMALL, true))
	facts.add_child(UiKit.label(str(row.blurb), RunUiTheme.LABEL_MUTED, true))
	facts.add_child(UiKit.label(str(row.stats_line), RunUiTheme.LABEL_MUTED, true))
	column.add_child(UiKit.label(tr("hero.curve"), RunUiTheme.LABEL_MUTED))
	var bars: CurveBars = CurveBars.new()
	column.add_child(bars)
	bars.show_curve(row.curve, color("text_muted"), color("text_light"), roundi(float(cfg.font_px.small) * _scale), BARS_H)
	return column


func _right_column(row: Dictionary) -> Control:
	var column: VBoxContainer = UiKit.vbox(10)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(UiKit.label(tr("hero.power_title"), RunUiTheme.LABEL_HEADING))
	var buttons: HBoxContainer = UiKit.hbox(8)
	column.add_child(buttons)
	for power: Dictionary in row.powers:
		var button: Button = UiKit.button(str(power.name))
		button.custom_minimum_size.x = 0.0
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.clip_text = true
		if not bool(power.unlocked):
			button.modulate.a = POWER_LOCKED_ALPHA
		button.pressed.connect(_pick_power.bind(power))
		button.focus_entered.connect(_show_power_text.bind(power))
		button.mouse_entered.connect(_show_power_text.bind(power))
		button.mouse_exited.connect(_show_chosen_text)
		buttons.add_child(button)
		_power_buttons.append(button)
	var plate: PanelContainer = UiKit.panel(RunUiTheme.PANEL_PARCHMENT)
	var paper: StyleBox = ArtLibrary.shared().parchment_panel(PLATE_PADDING_PX)
	if paper != null:
		plate.add_theme_stylebox_override(&"panel", paper)
	column.add_child(plate)
	_plate_text = UiKit.label("", RunUiTheme.LABEL_INK_BODY, true)
	plate.add_child(_plate_text)
	_refresh_powers()
	_show_chosen_text()
	return column


func _chosen_power() -> Dictionary:
	var row: Dictionary = _rows[_current]
	for power: Dictionary in row.powers:
		if str(power.id) == str(_chosen.get(str(row.id), "")):
			return power
	return row.powers[0]


func _pick_power(power: Dictionary) -> void:
	if not bool(power.unlocked):
		_show_power_text(power)
		return
	_chosen[str((_rows[_current] as Dictionary).id)] = str(power.id)
	_refresh_powers()
	_show_chosen_text()


func _refresh_powers() -> void:
	var row: Dictionary = _rows[_current]
	var chosen: String = str(_chosen_power().id)
	for i: int in _power_buttons.size():
		var picked: bool = str(row.powers[i].id) == chosen
		_power_buttons[i].theme_type_variation = RunUiTheme.BUTTON_PRIMARY if picked else &""


func _show_chosen_text() -> void:
	if not _is_locked():
		_show_power_text(_chosen_power())


func _show_power_text(power: Dictionary) -> void:
	if _plate_text == null:
		return
	var text: String = tr("hero.power").format({"cost": power.cost, "name": power.name, "text": power.text})
	if not bool(power.unlocked):
		text += "\n" + tr("hero.power_locked").format({"condition": power.condition})
	_plate_text.text = text


func _add_seed_row() -> void:
	_seed = null
	if not bool(_model.get("allow_custom_seed", false)):
		return
	var label: Label = UiKit.label(tr("hero.seed"))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(label)
	UiKit.place(label, SEED_LABEL_RECT)
	_seed = LineEdit.new()
	_seed.placeholder_text = tr("hero.seed_placeholder")
	add_child(_seed)
	UiKit.place(_seed, SEED_RECT)
	_echo = UiKit.label(tr("hero.seed_random"), RunUiTheme.LABEL_SMALL)
	add_child(_echo)
	UiKit.place(_echo, ECHO_RECT)
	_seed.text_changed.connect(_on_seed_changed)
	_seed.text_submitted.connect(func(_text: String) -> void: _on_start())


func _on_seed_changed(text: String) -> void:
	var preview: Callable = _model.get("seed_preview", Callable())
	var echo: String = str(preview.call(text)) if preview.is_valid() else ""
	_echo.text = tr("hero.seed_echo").format({"hex": echo}) if not echo.is_empty() else tr("hero.seed_random")


func _add_actions() -> void:
	_back = UiKit.button(tr("common.back"))
	_back.name = "Back"
	_back.pressed.connect(send.bind(&"back", {}))
	add_child(_back)
	UiKit.place(_back, Rect2(BACK_POS, _back.custom_minimum_size))
	_start = UiKit.button(tr("hero.start"), true)
	_start.pressed.connect(_on_start)
	add_child(_start)
	UiKit.place(_start, Rect2(START_POS, _start.custom_minimum_size))
	_deck = UiKit.button("")
	_deck.pressed.connect(_toggle_deck)
	add_child(_deck)
	UiKit.place(_deck, Rect2(DECK_POS, _deck.custom_minimum_size))


func _chain() -> void:
	var order: Array[Control] = []
	order.assign(_tabs)
	order.append_array(_power_buttons)
	if _seed != null:
		order.append(_seed)
	order.append_array([_start, _back, _deck])
	UiKit.chain_focus(order)


func _refresh_start() -> void:
	_start.disabled = _is_locked() or _committed
	_deck.disabled = _is_locked()


func _toggle_deck() -> void:
	if not _is_locked():
		(_drawers[str((_rows[_current] as Dictionary).id)] as DeckDrawer).toggle()


func _on_start() -> void:
	if not _is_locked():
		var row: Dictionary = _rows[_current]
		send(&"start_run", {"hero_id": str(row.id), "seed_input": _seed.text if _seed != null else "", "power_id": str(_chosen_power().id)})
