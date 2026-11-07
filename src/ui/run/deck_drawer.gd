## The non-blocking deck drawer (draft-picker.md §5.2, reused by hero-select.md): at
## 960, 96, 320, 536, ending above the action row so its toggle stays reachable. Lists
## held treasures and the deck in acquisition order. `Esc` or RMB closes it.
## [codeblock]
## var drawer := DeckDrawer.new()
## add_child(drawer)
## drawer.show_rows(tr("draft.deck_title"), model.deck_rows, model.treasures)
## drawer.toggle()
## [/codeblock]
class_name DeckDrawer
extends PanelContainer

const RECT: Rect2 = Rect2(960, 96, 320, 536)

var _rows: VBoxContainer = null
var _first: Control = null


## True while the drawer is open.
func is_open() -> bool:
	return visible


## Opens or closes the drawer.
func toggle() -> void:
	visible = not visible
	if visible and _first != null:
		_first.grab_focus()


## Shows or hides the drawer without moving focus.
func set_open(on: bool) -> void:
	visible = on


## Fills the drawer: [param title], [param deck_rows] (`RunReadModels.deck_rows`) and
## [param treasures].
func show_rows(title: String, deck_rows: Array, treasures: Array) -> void:
	theme_type_variation = RunUiTheme.PANEL_DARK
	UiKit.place(self, RECT)
	visible = false
	var column: VBoxContainer = UiKit.vbox()
	add_child(column)
	column.add_child(UiKit.label(title, RunUiTheme.LABEL_HEADING))
	var scroll: ScrollContainer = UiKit.scroll()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_rows = UiKit.vbox(4)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	for treasure: Dictionary in treasures:
		_add_row(str(treasure.name))
	for row: Dictionary in deck_rows:
		var text: String = "(%s) %s" % [row.cost, row.name]
		if row.get("drafted") != null:
			text = tr("deck.drafted").format({"card": text, "n": int(row.drafted)})
		_add_row(text)


func _add_row(text: String) -> void:
	var row: Label = UiKit.label(text, RunUiTheme.LABEL_SMALL, true)
	UiKit.focus_row(row)
	_rows.add_child(row)
	if _first == null:
		_first = row
