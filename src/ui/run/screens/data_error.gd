## `data_error` (run-ui U2, S2; AC-8): terminal over a `Failed` load. The report rows in
## a scrolling list, Copy report and Quit; nothing else is reachable. Row text is data,
## shown verbatim.
extends Screen

const MARGIN_PX: int = 48

var _quit: Button = null


func bind(model: Dictionary) -> void:
	clear()
	add_child(UiKit.backdrop(color("bg_edge")))
	var frame: MarginContainer = UiKit.margin(MARGIN_PX)
	add_child(frame)
	var column: VBoxContainer = UiKit.vbox(12)
	frame.add_child(column)
	column.add_child(UiKit.label(tr("error.title"), RunUiTheme.LABEL_TITLE))
	var rows: Array = model.get("rows", [])
	column.add_child(UiKit.label(tr("error.count").format({"n": rows.size()}), RunUiTheme.LABEL_MUTED))
	var scroll: ScrollContainer = UiKit.scroll()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var list: VBoxContainer = UiKit.vbox(6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for row: Dictionary in rows:
		list.add_child(UiKit.label("%s  %s  [%s]  %s" % [row.file, row.id, row.code, row.message], RunUiTheme.LABEL_SMALL, true))
	var bar: HBoxContainer = UiKit.hbox(16)
	column.add_child(bar)
	var report: String = str(model.get("report_text", ""))
	var copy: Button = UiKit.button(tr("error.copy"))
	copy.pressed.connect(func() -> void: DisplayServer.clipboard_set(report))
	bar.add_child(copy)
	_quit = UiKit.button(tr("menu.quit"), true)
	_quit.pressed.connect(send.bind(&"quit_requested", {}))
	bar.add_child(_quit)
	UiKit.chain_focus([copy, _quit])


func default_focus() -> Control:
	return _quit
