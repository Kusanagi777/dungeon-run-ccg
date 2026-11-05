## `boss_intro` (run-ui U2; AC-4, AC-29): the floor, band pips, portrait placeholder,
## name, intro line, the passive as the brightest block, boss health, hero power and deck
## size, with the strip above. Fight is anchored to the bottom and holds focus; `Esc`
## opens pause.
extends Screen

const PORTRAIT: Vector2 = Vector2(120, 160)
const PIP_PX: float = 12.0
const BODY_RECT: Rect2 = Rect2(240, 108, 800, 512)
const MENU_RECT: Rect2 = Rect2(1176, 4, 80, 44)
const FIGHT_POS: Vector2 = Vector2(560, 640)

var _fight: Button = null


func bind(model: Dictionary) -> void:
	clear()
	cancel_intent = &"open_pause"
	add_child(UiKit.backdrop(color("bg_edge")))
	var title: Label = UiKit.label(tr("boss.floor").format({"n": model.get("floor", 1), "f": model.get("floors", 0)}), RunUiTheme.LABEL_TITLE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	UiKit.place(title, Rect2(0, 4, float(cfg.design_width), 44))
	var strip: ProgressStrip = ProgressStrip.new()
	add_child(strip)
	strip.show_strip(cfg, model.get("strip", {}))
	var scroll: ScrollContainer = UiKit.scroll()
	add_child(scroll)
	UiKit.place(scroll, BODY_RECT)
	var column: VBoxContainer = UiKit.vbox(10)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	if int(model.get("attempt", 1)) > 1:
		column.add_child(UiKit.label(tr("boss.attempt").format({"n": model.attempt}), RunUiTheme.LABEL_MUTED))
	column.add_child(_pips(int(model.get("band", 1)), str(model.get("band_color", "neutral"))))
	var top: HBoxContainer = UiKit.hbox(16)
	column.add_child(top)
	top.add_child(UiKit.portrait(color(str(model.get("band_color", "neutral"))), str(model.get("boss_initial", "")), PORTRAIT))
	var facts: VBoxContainer = UiKit.vbox(6)
	facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(facts)
	facts.add_child(UiKit.label(str(model.get("boss_name", "")), RunUiTheme.LABEL_HEADING, true))
	facts.add_child(UiKit.label(str(model.get("intro_text", "")), RunUiTheme.LABEL_MUTED, true))
	facts.add_child(UiKit.label(tr("boss.health").format({"n": model.get("boss_health", 0)})))
	var passive_text: String = str(model.get("passive_text", ""))
	if not passive_text.is_empty():
		var plate: PanelContainer = UiKit.panel(RunUiTheme.PANEL_DARK)
		column.add_child(plate)
		plate.add_child(UiKit.label(passive_text, RunUiTheme.LABEL_HEADING, true))
	var power: String = str(model.get("power_name", ""))
	if not power.is_empty():
		column.add_child(UiKit.label(tr("boss.your_power").format({"cost": model.get("power_cost", ""), "name": power, "text": model.get("power_text", "")}), RunUiTheme.LABEL_SMALL, true))
	column.add_child(UiKit.label(tr("strip.deck").format({"n": model.get("deck_size", 0)}), RunUiTheme.LABEL_SMALL))
	_fight = UiKit.button(tr("boss.fight"), true)
	_fight.pressed.connect(send.bind(&"begin_match", {}))
	add_child(_fight)
	UiKit.place(_fight, Rect2(FIGHT_POS, _fight.custom_minimum_size))
	var menu: Button = UiKit.button(tr("common.menu"))
	menu.custom_minimum_size = MENU_RECT.size
	menu.pressed.connect(send.bind(&"open_pause", {}))
	add_child(menu)
	UiKit.place(menu, MENU_RECT)
	var order: Array[Control] = [_fight, menu]
	order.append_array(strip.focus_stops())
	UiKit.chain_focus(order)


func default_focus() -> Control:
	return _fight


func _pips(band: int, token: String) -> Control:
	var row: HBoxContainer = UiKit.hbox(6)
	for _i: int in band:
		var pip: ColorRect = ColorRect.new()
		pip.color = color(token)
		pip.custom_minimum_size = Vector2(PIP_PX, PIP_PX)
		row.add_child(pip)
	return row
