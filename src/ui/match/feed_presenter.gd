## The event feed (ADR-0009 `event_feed.tscn`; match-ui U10, F5; hud.md §5). A 3-line
## ticker, and on `L` or the top-bar button a drawer with every retained line, grouped
## under its command root, long groups collapsed to "+N more". Lines are view-state;
## the feed shows only those the display has reached, so it never tells a card's fate
## ahead of the table: `present` carries the count as `feed_total`.
##
## `Esc` and RMB close an open drawer first (hud.md `feed:open`, chain step 2). Story 019
## owns the rest of the chain and can call [method close].
## [codeblock]
## feed.set_names("hero_war", "boss_torchbearer")
## feed.open()
## [/codeblock]
class_name FeedPresenter
extends Presenter

const PANEL_MARGIN_PX: float = 8.0
const DRAWER_BORDER_PX: int = 2

var _view: MatchViewState = null
var _names: FeedNames = null
var _quiet: Dictionary = {}
var _collapse: int = 0
var _ticker_count: int = 0
var _font_px: int = 0
var _hero_def_id: String = ""
var _boss_def_id: String = ""
var _ticker: RichTextLabel = null
var _drawer: Panel = null
var _drawer_text: RichTextLabel = null
var _toggle: Button = null
var _open: bool = false
# group_id → true for a group the player opened.
var _expanded: Dictionary = {}
# `feed_total` the screen has reached, and the one the names have read.
var _shown_total: int = 0
var _learned_total: int = 0


## Builds the ticker, the drawer and the toggle at their rects.
func setup(context: MatchUiContext) -> void:
	super(context)
	_collapse = int(ui.config.feed_group_collapse)
	_ticker_count = int(ui.config.feed_ticker_lines)
	_font_px = int(ui.config.feed_font_px)
	_quiet = FeedLines.quiet_keys(ui.config.feed_quiet_types)
	_ticker = _rich_text(ui.rect("feed_ticker"), self)
	_ticker.scroll_active = false
	_ticker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rect: Rect2 = ui.rect("feed_drawer")
	var style := StyleBoxFlat.new()
	style.bg_color = ui.color("bg_edge")
	style.border_color = ui.color("stamp_ring")
	style.set_border_width_all(DRAWER_BORDER_PX)
	_drawer = Panel.new()
	_drawer.position = rect.position
	_drawer.size = rect.size
	_drawer.add_theme_stylebox_override("panel", style)
	_drawer.visible = false
	add_child(_drawer)
	var inner := Rect2(Vector2.ONE * PANEL_MARGIN_PX, rect.size - Vector2.ONE * PANEL_MARGIN_PX * 2.0)
	_drawer_text = _rich_text(inner, _drawer)
	_drawer_text.scroll_following = true
	_drawer_text.meta_clicked.connect(_on_meta_clicked)
	_drawer_text.gui_input.connect(_on_drawer_input)
	_build_toggle()


## Stores the projection the lines are read from.
func bind(view_state: MatchViewState) -> void:
	_view = view_state


## The heroes' names, from the `MatchConfig`; call before the first event.
func set_names(hero_def_id: String, boss_def_id: String) -> void:
	_hero_def_id = hero_def_id
	_boss_def_id = boss_def_id
	_names = null


func owns(_entity_ids: Array[int]) -> bool:
	return false


func on_step_started(_step: AnimStep, _d_eff: float) -> void:
	return


func apply_final(_step: AnimStep) -> void:
	return


func present(state: Dictionary) -> void:
	var total: int = int(state.get("feed_total", _shown_total))
	if total != _shown_total:
		_shown_total = total
		_refresh()


func sync_report() -> Array[String]:
	var report: Array[String] = []
	if _shown_total != _view.feed_total:
		report.append("feed: shows %d lines, view-state %d" % [_shown_total, _view.feed_total])
	return report


## True while the drawer is up.
func is_open() -> bool:
	return _open


## Opens the drawer, or closes an open one.
func toggle() -> void:
	if _open:
		close()
	else:
		open()


## U11 `feed:open`, `L` and the top-bar button.
func open() -> void:
	_open = true
	_drawer.visible = true
	_ticker.visible = false
	_refresh()


## Closes the drawer; a closed one stays closed.
func close() -> void:
	_open = false
	_drawer.visible = false
	_ticker.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if ui == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: Key = (event as InputEventKey).keycode
		if key == KEY_L:
			toggle()
			get_viewport().set_input_as_handled()
		elif key == KEY_ESCAPE and _open:
			close()
			get_viewport().set_input_as_handled()
	elif _is_right_press(event) and _open:
		close()
		get_viewport().set_input_as_handled()


func _on_drawer_input(event: InputEvent) -> void:
	if _is_right_press(event):
		close()
		_drawer_text.accept_event()


func _on_meta_clicked(meta: Variant) -> void:
	var group: int = int(str(meta))
	if _expanded.has(group):
		_expanded.erase(group)
	else:
		_expanded[group] = true
	_refresh()


static func _is_right_press(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT


func _build_toggle() -> void:
	var rect: Rect2 = ui.rect("feed_toggle")
	var style := StyleBoxFlat.new()
	style.bg_color = ui.color("table_dark")
	_toggle = Button.new()
	_toggle.text = tr("hud.feed")
	_toggle.position = rect.position
	_toggle.size = rect.size
	_toggle.focus_mode = Control.FOCUS_NONE
	for state: String in ["normal", "hover", "pressed"]:
		_toggle.add_theme_stylebox_override(state, style)
	_toggle.add_theme_color_override("font_color", ui.color("text_light"))
	_toggle.pressed.connect(toggle)
	add_child(_toggle)


func _rich_text(rect: Rect2, parent: Control) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_size_override("normal_font_size", _font_px)
	label.add_theme_color_override("default_color", ui.color("text_light"))
	parent.add_child(label)
	return label


## The lines the display has reached, oldest first, quiet ones gone.
func _reached_lines() -> Array[Dictionary]:
	var lines: Array = _view.feed_lines
	var ahead: int = maxi(_view.feed_total - _shown_total, 0)
	return FeedLines.shown(lines.slice(0, maxi(lines.size() - ahead, 0)), _quiet)


func _refresh() -> void:
	_learn()
	var lines: Array[Dictionary] = _reached_lines()
	var ticker: PackedStringArray = []
	for line: Dictionary in FeedLines.newest(lines, _ticker_count):
		ticker.append(_bbcode(line))
	_ticker.text = "\n".join(ticker)
	if _open:
		var rows: PackedStringArray = []
		for row: Dictionary in FeedLines.rows(lines, _collapse, _expanded):
			rows.append(_row_bbcode(row))
		_drawer_text.text = "\n".join(rows)


## Reads the ids of every new line. Nothing here is drawn, so it may run ahead.
func _learn() -> void:
	if _names == null:
		_names = FeedNames.new(ui.query.card_text if ui.query != null else Callable())
		_names.set_heroes(_hero_def_id, _boss_def_id)
		_learned_total = 0
	var lines: Array = _view.feed_lines
	var fresh: int = mini(_view.feed_total - _learned_total, lines.size())
	for line: Dictionary in lines.slice(lines.size() - fresh):
		_names.learn(line)
	_learned_total = _view.feed_total


func _row_bbcode(row: Dictionary) -> String:
	match row.kind:
		FeedLines.ROW_ROOT:
			return _bbcode(row.line)
		FeedLines.ROW_CHILD:
			return "[indent]%s[/indent]" % _bbcode(row.line)
	return "[indent][url=%d]%s[/url][/indent]" % [int(row.group_id), _escaped(FeedLines.more_text(int(row.hidden)))]


func _bbcode(line: Dictionary) -> String:
	var text: String = _escaped(FeedLines.text(line, _names))
	if str(line.get("key", "")).begins_with(MatchViewState.FEED_DIAG_PREFIX):
		return "[color=#%s]%s[/color]" % [ui.color("text_muted").to_html(false), text]
	return text


static func _escaped(text: String) -> String:
	return text.replace("[", "[lb]")
