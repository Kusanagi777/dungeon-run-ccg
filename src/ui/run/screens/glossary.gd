## `glossary` (accessibility "Tutorial persistence"): the DD-M09 keywords with reminder
## text, reachable from pause and settings. Each row is a focus stop, so a keyboard can
## scroll the list.
extends Screen

const MARGIN_PX: int = 48

var _first: Control = null
var _back: Button = null


func bind(model: Dictionary) -> void:
	clear()
	cancel_intent = &"back"
	add_child(UiKit.backdrop(color("bg_edge")))
	var frame: MarginContainer = UiKit.margin(MARGIN_PX)
	add_child(frame)
	var column: VBoxContainer = UiKit.vbox(10)
	frame.add_child(column)
	column.add_child(UiKit.label(tr("glossary.title"), RunUiTheme.LABEL_TITLE))
	var scroll: ScrollContainer = UiKit.scroll()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var rows: VBoxContainer = UiKit.vbox(8)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	var order: Array[Control] = []
	for row: Dictionary in model.get("rows", []):
		var line: Label = UiKit.label(tr("glossary.row").format({"name": row.name, "text": row.text}), &"", true)
		UiKit.focus_row(line)
		rows.add_child(line)
		order.append(line)
	_back = UiKit.button(tr("common.back"), true)
	_back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_back.pressed.connect(send.bind(&"back", {}))
	column.add_child(_back)
	order.append(_back)
	_first = order[0]
	UiKit.chain_focus(order)


func default_focus() -> Control:
	return _back


func tab_entry() -> Control:
	return _first
