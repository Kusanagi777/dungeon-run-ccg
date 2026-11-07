## The run summary layout (run-ui U9; run-summary.md §5), shared by the two end screens
## and the read-only `run_detail`: one ledger page of hero and facts, the damage table,
## the per-floor strip and the deck list. Display only; the action row belongs to the
## screen that hosts it.
## [codeblock]
## var view := SummaryView.new()
## parent.add_child(view)
## view.show_summary(cfg, model)
## view.focus_stops()   # Copy, the strip
## [/codeblock]
class_name SummaryView
extends Control

const SHEET_RECT: Rect2 = Rect2(24, 52, 1232, 580)
const MARGIN_PX: float = 56.0
const TOP_PX: float = 76.0
const LEFT_W: float = 336.0
const CENTRE_W: float = 360.0
const RIGHT_W: float = 392.0
const BODY_H: float = 532.0
const COLUMN_GAP: float = 32.0
const RULE_ALPHA: float = 0.22
const DECK_COLUMNS: int = 2
## A lost run's page is the same paper with less torch on it.
const DEFEAT_SHEET: Color = Color(0.8, 0.77, 0.74)
const PORTRAIT: Vector2 = Vector2(120, 160)
const SATURATE_S: float = 0.4
const DEFEAT_DARKEN: float = 0.4
const VISIBLE_DAMAGE_ROWS: int = 8

var _cfg: Dictionary = {}
var _stops: Array[Control] = []
var _copied: Label = null
var _portrait: ColorRect = null
var _seed: String = ""


## Lays out [param model] (`RunReadModels.summary`).
func show_summary(cfg: Dictionary, model: Dictionary) -> void:
	_cfg = cfg
	_seed = str(model.seed)
	var headline: Label = UiKit.label(str(model.headline), RunUiTheme.LABEL_TITLE)
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(headline)
	UiKit.place(headline, Rect2(0, 8, float(cfg.design_width), 44))
	var sheet: PanelContainer = UiKit.panel(RunUiTheme.PANEL_PARCHMENT)
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if str(model.outcome) != RunCodes.STATUS_VICTORY:
		sheet.modulate = DEFEAT_SHEET
	add_child(sheet)
	UiKit.place(sheet, SHEET_RECT)
	var x: float = MARGIN_PX
	add_child(_left_column(model))
	UiKit.place(get_child(get_child_count() - 1), Rect2(x, TOP_PX, LEFT_W, BODY_H))
	x += LEFT_W + COLUMN_GAP
	_add_divider(x - COLUMN_GAP / 2.0)
	add_child(_damage_column(model))
	UiKit.place(get_child(get_child_count() - 1), Rect2(x, TOP_PX, CENTRE_W, BODY_H))
	x += CENTRE_W + COLUMN_GAP
	_add_divider(x - COLUMN_GAP / 2.0)
	add_child(_right_column(model))
	UiKit.place(get_child(get_child_count() - 1), Rect2(x, TOP_PX, RIGHT_W, BODY_H))


## The focus stops inside the view, in run-summary.md's order.
func focus_stops() -> Array[Control]:
	return _stops


## Victory's one allowed saturation (art bible §4 rule b): the portrait ramps to its
## hero primary over 400 ms; [param instant] sets it at once.
func saturate_portrait(hero_color: Color, instant: bool) -> void:
	if instant:
		_portrait.color = hero_color
		return
	_portrait.create_tween().tween_property(_portrait, "color", hero_color, SATURATE_S)


func _add_divider(x: float) -> void:
	var line: ColorRect = UiKit.rule(_ink_rule())
	add_child(line)
	UiKit.place(line, Rect2(x, TOP_PX, 1.0, BODY_H))


func _ink_rule() -> Color:
	return Color(RunUiConfig.color(_cfg, "text_ink"), RULE_ALPHA)


func _left_column(model: Dictionary) -> Control:
	var scroll: ScrollContainer = UiKit.scroll()
	var column: VBoxContainer = UiKit.vbox(6)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	var top: HBoxContainer = UiKit.hbox(16)
	column.add_child(top)
	var neutral: Color = RunUiConfig.color(_cfg, "neutral")
	var hero_color: Color = RunUiConfig.color(_cfg, str(model.hero_color))
	var start: Color = neutral if str(model.outcome) == RunCodes.STATUS_VICTORY else hero_color.darkened(DEFEAT_DARKEN)
	var stamp: Dictionary = ArtLibrary.shared().portrait("heroes", str(model.get("hero_id", "")))
	_portrait = UiKit.portrait(start, str(model.hero_initial), PORTRAIT, stamp.get("texture"), stamp.get("tint", Color.WHITE))
	top.add_child(_portrait)
	var who: Label = UiKit.label(str(model.hero_name), RunUiTheme.LABEL_INK_HEADING, true)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(who)
	var reason: String = str(model.reason)
	if not reason.is_empty():
		column.add_child(UiKit.label(reason, RunUiTheme.LABEL_INK_BODY, true))
	column.add_child(UiKit.label(tr("summary.floors").format({"n": int(model.floors_cleared), "f": int(model.floors)}), RunUiTheme.LABEL_INK_BODY))
	column.add_child(UiKit.label(tr("summary.matches").format({"m": int(model.matches), "t": int(model.turns)}), RunUiTheme.LABEL_INK_BODY))
	column.add_child(UiKit.label(str(model.duration), RunUiTheme.LABEL_INK_MUTED))
	var seed_row: HBoxContainer = UiKit.hbox()
	column.add_child(seed_row)
	seed_row.add_child(UiKit.label(tr("summary.seed").format({"seed": model.seed}), RunUiTheme.LABEL_INK_MUTED))
	var copy: Button = UiKit.button(tr("summary.copy"))
	copy.custom_minimum_size.x = UiKit.MIN_HIT_PX * 2.0
	copy.pressed.connect(_copy_seed)
	seed_row.add_child(copy)
	_stops.append(copy)
	_copied = UiKit.label("", RunUiTheme.LABEL_INK)
	seed_row.add_child(_copied)
	if bool(model.custom_seed):
		column.add_child(UiKit.label(tr("summary.custom_seed"), RunUiTheme.LABEL_INK))
	if not (model.treasures as Array).is_empty():
		var names: PackedStringArray = []
		for treasure: Dictionary in model.treasures:
			names.append(str(treasure.name))
		column.add_child(UiKit.label(tr("summary.treasures").format({"list": ", ".join(names)}), RunUiTheme.LABEL_INK, true))
	for line: String in model.unlocks:
		column.add_child(UiKit.label(line, RunUiTheme.LABEL_INK_BODY, true))
	var status: String = str(model.status_line)
	if not status.is_empty():
		column.add_child(UiKit.label(tr("summary.status").format({"text": status}), RunUiTheme.LABEL_INK, true))
	return scroll


func _damage_column(model: Dictionary) -> Control:
	var column: VBoxContainer = UiKit.vbox(4)
	column.add_child(UiKit.label(tr("summary.damage"), RunUiTheme.LABEL_INK_HEADING))
	var scroll: ScrollContainer = UiKit.scroll()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var rows: VBoxContainer = UiKit.vbox(4)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	if bool(model.no_damage):
		rows.add_child(UiKit.label(tr("summary.no_damage"), RunUiTheme.LABEL_INK_MUTED))
		return column
	var shown: Array = (model.top_cards as Array).slice(0, VISIBLE_DAMAGE_ROWS)
	for i: int in shown.size():
		var line: HBoxContainer = UiKit.hbox()
		var name_label: Label = UiKit.label("%d  %s" % [i + 1, shown[i].name], RunUiTheme.LABEL_INK_BODY, false)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.clip_text = true
		line.add_child(name_label)
		var figure: Label = UiKit.label(str(shown[i].damage), RunUiTheme.LABEL_INK_BODY)
		UiFonts.apply(figure, UiFonts.WEIGHT_BOLD)
		line.add_child(figure)
		rows.add_child(line)
		rows.add_child(UiKit.rule(_ink_rule()))
	var hidden: int = int(model.more_cards) + (model.top_cards as Array).size() - shown.size()
	if hidden > 0:
		rows.add_child(UiKit.label(tr("summary.more").format({"n": hidden}), RunUiTheme.LABEL_INK_MUTED))
	return column


func _right_column(model: Dictionary) -> Control:
	var column: VBoxContainer = UiKit.vbox(6)
	column.add_child(UiKit.label(tr("summary.floors_title"), RunUiTheme.LABEL_INK_HEADING))
	var strip: FloorStrip = FloorStrip.new()
	column.add_child(strip)
	strip.show_cells(_cfg, model.cells)
	_stops.append(strip)
	column.add_child(UiKit.label(tr("summary.deck").format({"n": (model.deck_rows as Array).size()}), RunUiTheme.LABEL_INK_HEADING))
	var scroll: ScrollContainer = UiKit.scroll()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var rows: GridContainer = GridContainer.new()
	# Past 100 % text two columns would trim the names: the list scrolls instead.
	rows.columns = DECK_COLUMNS if get_theme_default_font_size() <= int(_cfg.font_px.body) else 1
	rows.add_theme_constant_override(&"h_separation", 12)
	rows.add_theme_constant_override(&"v_separation", 2)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	for row: Dictionary in model.deck_rows:
		var text: String = "(%s) %s" % [row.cost, row.name]
		if row.get("drafted") != null:
			text = tr("deck.drafted").format({"card": text, "n": int(row.drafted)})
		var entry: Label = UiKit.label(text, RunUiTheme.LABEL_INK)
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		entry.clip_text = true
		rows.add_child(entry)
	return column


func _copy_seed() -> void:
	DisplayServer.clipboard_set(_seed)
	_copied.text = tr("summary.copied")
	get_tree().create_timer(float(_cfg.copied_flash_ms) / RunUiConfig.MS_PER_S).timeout.connect(func() -> void:
		if is_instance_valid(_copied):
			_copied.text = "")
