## `run_log` (run-ui U2; meta-progression AC-28): archived runs newest first, the
## per-hero stats header, a hero filter over the loaded pages, Load more, and per row
## Open and Copy seed. The filter is local (no command); zero runs shows one line with
## New Run focused.
extends Screen

const MARGIN_PX: int = 40
const COPY_W: float = 88.0

var _model: Dictionary = {}
var _filter: String = ""
var _rows_box: VBoxContainer = null
var _back: Button = null
var _new_run: Button = null
var _first_row: Control = null
var _copied: Label = null
var _order: Array[Control] = []
var _more: Button = null


func bind(model: Dictionary) -> void:
	clear()
	_model = model
	_filter = ""
	cancel_intent = &"back"
	add_child(UiKit.backdrop(color("bg_edge")))
	var frame: MarginContainer = UiKit.margin(MARGIN_PX)
	add_child(frame)
	var column: VBoxContainer = UiKit.vbox(8)
	frame.add_child(column)
	column.add_child(UiKit.label(tr("log.title"), RunUiTheme.LABEL_TITLE))
	for line: String in model.get("stats_lines", []):
		column.add_child(UiKit.label(line, RunUiTheme.LABEL_MUTED))
	column.add_child(UiKit.label(tr("log.bests_note"), RunUiTheme.LABEL_SMALL))
	var filters: HBoxContainer = UiKit.hbox()
	column.add_child(filters)
	_order.clear()
	_new_run = null
	var rows: Array = model.get("rows", [])
	if rows.is_empty():
		column.add_child(UiKit.label(tr("log.empty")))
		_new_run = UiKit.button(tr("menu.new_run"), true)
		_new_run.pressed.connect(send.bind(&"new_run_requested", {}))
		column.add_child(_new_run)
		_order.append(_new_run)
	else:
		_add_filter(filters, tr("log.filter_all"), "")
		for hero: Dictionary in model.get("filters", []):
			_add_filter(filters, str(hero.name), str(hero.id))
	var scroll: ScrollContainer = UiKit.scroll()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_rows_box = UiKit.vbox(6)
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows_box)
	var bar: HBoxContainer = UiKit.hbox(16)
	column.add_child(bar)
	_back = UiKit.button(tr("common.back"))
	_back.pressed.connect(send.bind(&"back", {}))
	bar.add_child(_back)
	_more = UiKit.button(tr("log.more"))
	_more.pressed.connect(send.bind(&"load_more", {}))
	_more.visible = bool(model.get("more", false))
	bar.add_child(_more)
	_copied = UiKit.label("", RunUiTheme.LABEL_SMALL)
	bar.add_child(_copied)
	_fill_rows()


func default_focus() -> Control:
	if _new_run != null:
		return _new_run
	return _first_row if _first_row != null else _back


func _add_filter(row: HBoxContainer, text: String, hero_id: String) -> void:
	var button: Button = UiKit.button(text)
	button.pressed.connect(func() -> void:
		_filter = hero_id
		_fill_rows()
		if _first_row != null:
			_first_row.grab_focus())
	row.add_child(button)
	_order.append(button)


func _fill_rows() -> void:
	for child: Node in _rows_box.get_children():
		_rows_box.remove_child(child)
		child.queue_free()
	_first_row = null
	var order: Array[Control] = _order.duplicate()
	for row: Dictionary in _model.get("rows", []):
		if _filter.is_empty() or str(row.hero_id) == _filter:
			order.append_array(_add_row(row))
	order.append(_back)
	if _more.visible:
		order.append(_more)
	UiKit.chain_focus(order)


func _add_row(row: Dictionary) -> Array[Control]:
	var line: PanelContainer = UiKit.panel(RunUiTheme.PANEL_DARK)
	_rows_box.add_child(line)
	var body: HBoxContainer = UiKit.hbox(12)
	line.add_child(body)
	var text: VBoxContainer = UiKit.vbox(2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(text)
	var head: String = tr("log.row").format({"date": row.date, "hero": row.hero, "result": row.result, "floors": row.floors})
	text.add_child(UiKit.label(head, &"", true))
	var tags: PackedStringArray = [tr("log.seed").format({"seed": row.seed})]
	if bool(row.details):
		tags.append(tr("log.deck").format({"n": int(row.deck_size)}))
	if bool(row.custom_seed):
		tags.append(tr("summary.custom_seed"))
	if bool(row.retried):
		tags.append(tr("log.retried"))
	text.add_child(UiKit.label("  ·  ".join(tags), RunUiTheme.LABEL_SMALL, true))
	if not str(row.top_cards).is_empty():
		text.add_child(UiKit.label(tr("log.top").format({"list": row.top_cards}), RunUiTheme.LABEL_SMALL, true))
	var stops: Array[Control] = []
	if bool(row.details):
		var open: Button = UiKit.button(tr("log.open"))
		open.custom_minimum_size.x = COPY_W
		open.pressed.connect(send.bind(&"open_run", {"run_id": row.run_id}))
		body.add_child(open)
		stops.append(open)
	var copy: Button = UiKit.button(tr("summary.copy"))
	copy.custom_minimum_size.x = COPY_W
	copy.pressed.connect(_copy.bind(str(row.seed)))
	body.add_child(copy)
	stops.append(copy)
	if _first_row == null:
		_first_row = stops[0]
	return stops


func _copy(seed_hex: String) -> void:
	DisplayServer.clipboard_set(seed_hex)
	_copied.text = tr("summary.copied")
	get_tree().create_timer(float(cfg.copied_flash_ms) / RunUiConfig.MS_PER_S).timeout.connect(func() -> void:
		if is_instance_valid(_copied):
			_copied.text = "")
