## `unlocks`: the ledger of everything a profile can earn, from the main menu. A row per
## record whose `unlock` is set: its stamp, what it does, the condition and the progress.
## Read only. Each row is a focus stop, so a keyboard can scroll the list.
extends Screen

const TITLE_RECT: Rect2 = Rect2(0, 12, 1280, 44)
const COUNT_RECT: Rect2 = Rect2(0, 56, 1280, 24)
const SHEET_X: float = 180.0
const SHEET_Y: float = 92.0
const SHEET_W: float = 920.0
const SHEET_MAX_H: float = 536.0
const SHEET_PADDING_PX: float = 32.0
const SECTION_H: float = 44.0
const ROW_H: float = 72.0
const ICON_PX: float = 48.0
const STATUS_W: float = 280.0
const BACK_POS: Vector2 = Vector2(40, 640)
const RULE_ALPHA: float = 0.22
## A locked row's stamp is a faint impression: the ink has not landed yet.
const LOCKED_ICON_ALPHA: float = 0.35

var _first: Control = null
var _back: Button = null


func bind(model: Dictionary) -> void:
	clear()
	cancel_intent = &"back"
	var backdrop: ColorRect = UiKit.backdrop(color("bg_edge"))
	add_child(backdrop)
	ArtLibrary.shared().mount_fill(backdrop, "table")
	_add_centred(tr("unlocks.title"), RunUiTheme.LABEL_TITLE, TITLE_RECT)
	_add_centred(str(model.get("count_line", "")), RunUiTheme.LABEL_MUTED, COUNT_RECT)
	var sections: Array = model.get("sections", [])
	var sheet: PanelContainer = UiKit.panel(RunUiTheme.PANEL_PARCHMENT)
	add_child(sheet)
	UiKit.place(sheet, Rect2(SHEET_X, SHEET_Y, SHEET_W, _sheet_height(sections)))
	var scroll: ScrollContainer = UiKit.scroll()
	sheet.add_child(scroll)
	var page: VBoxContainer = UiKit.vbox(0)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(page)
	var order: Array[Control] = []
	if sections.is_empty():
		page.add_child(UiKit.label(tr("unlocks.none"), RunUiTheme.LABEL_INK_BODY))
	for section: Dictionary in sections:
		var heading: Label = UiKit.label(str(section.title), RunUiTheme.LABEL_INK_HEADING)
		heading.custom_minimum_size.y = SECTION_H
		heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		page.add_child(heading)
		for row: Dictionary in section.rows:
			page.add_child(UiKit.rule(Color(color("text_ink"), RULE_ALPHA)))
			var line: Control = _row(row)
			page.add_child(line)
			order.append(line)
	_back = UiKit.button(tr("common.back"))
	_back.pressed.connect(send.bind(&"back", {}))
	add_child(_back)
	UiKit.place(_back, Rect2(BACK_POS, _back.custom_minimum_size))
	order.append(_back)
	_first = order[0]
	UiKit.chain_focus(order)


func default_focus() -> Control:
	return _back


func tab_entry() -> Control:
	return _first


func _add_centred(text: String, variation: StringName, rect: Rect2) -> void:
	var label: Label = UiKit.label(text, variation)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	UiKit.place(label, rect)


# The sheet fits its rows up to the screen, then scrolls.
func _sheet_height(sections: Array) -> float:
	var height: float = SHEET_PADDING_PX + SECTION_H
	for section: Dictionary in sections:
		height += SECTION_H + (ROW_H + 1.0) * (section.rows as Array).size()
	return minf(height, SHEET_MAX_H)


func _row(row: Dictionary) -> Control:
	var line: HBoxContainer = UiKit.hbox(16)
	line.custom_minimum_size.y = ROW_H
	UiKit.focus_row(line)
	var earned: bool = bool(row.unlocked)
	line.add_child(_icon(row, earned))
	var what: VBoxContainer = UiKit.vbox(0)
	what.alignment = BoxContainer.ALIGNMENT_CENTER
	what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	what.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(what)
	var name_label: Label = UiKit.label(str(row.name), RunUiTheme.LABEL_INK_HEADING)
	what.add_child(name_label)
	var effect: String = str(row.get("text", ""))
	if not effect.is_empty():
		what.add_child(UiKit.label(effect, RunUiTheme.LABEL_INK, true))
	var status: VBoxContainer = UiKit.vbox(0)
	status.alignment = BoxContainer.ALIGNMENT_CENTER
	status.custom_minimum_size.x = STATUS_W
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(status)
	var state: Label = UiKit.label(tr("unlocks.done") if earned else str(row.progress), RunUiTheme.LABEL_INK_BODY)
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UiFonts.apply(state, UiFonts.WEIGHT_BOLD)
	status.add_child(state)
	var condition: Label = UiKit.label(str(row.condition), RunUiTheme.LABEL_INK_MUTED, true)
	condition.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.add_child(condition)
	return line


func _icon(row: Dictionary, earned: bool) -> Control:
	var stamp: Dictionary = {}
	match str(row.kind):
		"treasure":
			stamp = ArtLibrary.shared().treasure_stamp(str(row.id))
		"power":
			stamp = ArtLibrary.shared().power_stamp(str(row.id))
			if not stamp.is_empty():
				stamp.tint = color("text_ink")
		"hero":
			stamp = ArtLibrary.shared().portrait("heroes", str(row.id))
			if not stamp.is_empty():
				stamp.tint = color("text_ink")
	var icon: TextureRect = TextureRect.new()
	icon.custom_minimum_size = Vector2.ONE * ICON_PX
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not stamp.is_empty():
		icon.texture = stamp.texture
		icon.modulate = Color(stamp.tint, 1.0 if earned else LOCKED_ICON_ALPHA)
	return icon
