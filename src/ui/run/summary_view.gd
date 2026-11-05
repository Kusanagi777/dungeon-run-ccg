## The run summary layout (run-ui U9; run-summary.md §5), shared by the two end screens
## and the read-only `run_detail`: hero and facts, the damage table, the per-floor strip
## and the deck list. Display only; the action row belongs to the screen that hosts it.
## [codeblock]
## var view := SummaryView.new()
## parent.add_child(view)
## view.show_summary(cfg, model)
## view.focus_stops()   # Copy, the strip
## [/codeblock]
class_name SummaryView
extends Control

const MARGIN_PX: float = 40.0
const TOP_PX: float = 56.0
const LEFT_W: float = 360.0
const CENTRE_W: float = 400.0
const RIGHT_W: float = 392.0
const BODY_H: float = 560.0
const COLUMN_GAP: float = 24.0
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
	var x: float = MARGIN_PX
	add_child(_left_column(model))
	UiKit.place(get_child(get_child_count() - 1), Rect2(x, TOP_PX, LEFT_W, BODY_H))
	x += LEFT_W + COLUMN_GAP
	add_child(_damage_column(model))
	UiKit.place(get_child(get_child_count() - 1), Rect2(x, TOP_PX, CENTRE_W, BODY_H))
	x += CENTRE_W + COLUMN_GAP
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


func _left_column(model: Dictionary) -> Control:
	var scroll: ScrollContainer = UiKit.scroll()
	var column: VBoxContainer = UiKit.vbox(6)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	var top: HBoxContainer = UiKit.hbox(16)
	column.add_child(top)
	var neutral: Color = RunUiConfig.color(_cfg, "neutral")
	var hero_color: Color = RunUiConfig.color(_cfg, str(model.hero_color))
	var start: Color = neutral if str(model.outcome) == RunState.STATUS_VICTORY else hero_color.darkened(DEFEAT_DARKEN)
	_portrait = UiKit.portrait(start, str(model.hero_initial), PORTRAIT)
	top.add_child(_portrait)
	var who: Label = UiKit.label(str(model.hero_name), RunUiTheme.LABEL_HEADING, true)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(who)
	var reason: String = str(model.reason)
	if not reason.is_empty():
		column.add_child(UiKit.label(reason, &"", true))
	column.add_child(UiKit.label(tr("summary.floors").format({"n": int(model.floors_cleared), "f": int(model.floors)})))
	column.add_child(UiKit.label(tr("summary.matches").format({"m": int(model.matches), "t": int(model.turns)})))
	column.add_child(UiKit.label(str(model.duration), RunUiTheme.LABEL_MUTED))
	var seed_row: HBoxContainer = UiKit.hbox()
	column.add_child(seed_row)
	seed_row.add_child(UiKit.label(tr("summary.seed").format({"seed": model.seed}), RunUiTheme.LABEL_MUTED))
	var copy: Button = UiKit.button(tr("summary.copy"))
	copy.custom_minimum_size.x = UiKit.MIN_HIT_PX * 2.0
	copy.pressed.connect(_copy_seed)
	seed_row.add_child(copy)
	_stops.append(copy)
	_copied = UiKit.label("", RunUiTheme.LABEL_SMALL)
	seed_row.add_child(_copied)
	if bool(model.custom_seed):
		column.add_child(UiKit.label(tr("summary.custom_seed"), RunUiTheme.LABEL_SMALL))
	if not (model.treasures as Array).is_empty():
		var names: PackedStringArray = []
		for treasure: Dictionary in model.treasures:
			names.append(str(treasure.name))
		column.add_child(UiKit.label(tr("summary.treasures").format({"list": ", ".join(names)}), RunUiTheme.LABEL_SMALL, true))
	for line: String in model.unlocks:
		column.add_child(UiKit.label(line, &"", true))
	var status: String = str(model.status_line)
	if not status.is_empty():
		column.add_child(UiKit.label(tr("summary.status").format({"text": status}), RunUiTheme.LABEL_SMALL, true))
	return scroll


func _damage_column(model: Dictionary) -> Control:
	var column: VBoxContainer = UiKit.vbox(4)
	column.add_child(UiKit.label(tr("summary.damage"), RunUiTheme.LABEL_HEADING))
	var scroll: ScrollContainer = UiKit.scroll()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var rows: VBoxContainer = UiKit.vbox(4)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	if bool(model.no_damage):
		rows.add_child(UiKit.label(tr("summary.no_damage"), RunUiTheme.LABEL_MUTED))
		return column
	var shown: Array = (model.top_cards as Array).slice(0, VISIBLE_DAMAGE_ROWS)
	for i: int in shown.size():
		var line: HBoxContainer = UiKit.hbox()
		var name_label: Label = UiKit.label("%d  %s" % [i + 1, shown[i].name], &"", false)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.clip_text = true
		line.add_child(name_label)
		line.add_child(UiKit.label(str(shown[i].damage)))
		rows.add_child(line)
	var hidden: int = int(model.more_cards) + (model.top_cards as Array).size() - shown.size()
	if hidden > 0:
		rows.add_child(UiKit.label(tr("summary.more").format({"n": hidden}), RunUiTheme.LABEL_MUTED))
	return column


func _right_column(model: Dictionary) -> Control:
	var column: VBoxContainer = UiKit.vbox(6)
	column.add_child(UiKit.label(tr("summary.floors_title"), RunUiTheme.LABEL_HEADING))
	var strip: FloorStrip = FloorStrip.new()
	column.add_child(strip)
	strip.show_cells(_cfg, model.cells)
	_stops.append(strip)
	column.add_child(UiKit.label(tr("summary.deck").format({"n": (model.deck_rows as Array).size()}), RunUiTheme.LABEL_HEADING))
	var scroll: ScrollContainer = UiKit.scroll()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var rows: VBoxContainer = UiKit.vbox(2)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	for row: Dictionary in model.deck_rows:
		var text: String = "(%s) %s" % [row.cost, row.name]
		if row.get("drafted") != null:
			text = tr("deck.drafted").format({"card": text, "n": int(row.drafted)})
		rows.add_child(UiKit.label(text, RunUiTheme.LABEL_SMALL))
	return column


func _copy_seed() -> void:
	DisplayServer.clipboard_set(_seed)
	_copied.text = tr("summary.copied")
	get_tree().create_timer(float(_cfg.copied_flash_ms) / RunUiConfig.MS_PER_S).timeout.connect(func() -> void:
		if is_instance_valid(_copied):
			_copied.text = "")
