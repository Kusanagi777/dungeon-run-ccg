## `main_menu` (run-ui U2; AC-1): New Run, the Continue card when a run is saved, Run
## Log, Unlocks, Settings, Quit and the one-time load-status line down the left, and the ledger's
## title sheet on the right: the lantern, a stamp per floor inked up to the best reached,
## and the stats line.
extends Screen

const COLUMN_RECT: Rect2 = Rect2(96, 72, 440, 576)
const SHEET_RECT: Rect2 = Rect2(728, 84, 396, 552)
const SHEET_TILT_DEG: float = 2.0
const SHEET_MARGIN_PX: int = 44
const SHADOW_PX: int = 24
const SHADOW_ALPHA: float = 0.55
const LANTERN_H: float = 192.0
const LANTERN_STAMP: String = "lantern"
const TALLY_PX: float = 30.0
const TALLY_GAP: float = 4.0
const TITLE_GAP: int = 24
const RULE_ALPHA: float = 0.25

## One stamp per floor, drawn: inked through the best floor reached, a ring past it.
class FloorTally:
	extends Control

	var floors: int = 0
	var best: int = 0
	var ink: Color = Color.BLACK
	var paper: Color = Color.WHITE
	var font_px: int = 13

	func _draw() -> void:
		var font: Font = UiFonts.serif(UiFonts.WEIGHT_BOLD)
		if font == null:
			font = get_theme_default_font()
		var pitch: float = TALLY_PX + TALLY_GAP
		var left: float = (size.x - pitch * floors + TALLY_GAP) / 2.0
		var radius: float = TALLY_PX / 2.0
		for i: int in floors:
			var centre: Vector2 = Vector2(left + pitch * i + radius, size.y / 2.0)
			var reached: bool = i < best
			if reached:
				draw_circle(centre, radius, ink)
			else:
				draw_arc(centre, radius, 0.0, TAU, 32, ink, 1.0, true)
			var baseline: Vector2 = centre + Vector2(-radius, font_px / 2.5)
			draw_string(font, baseline, str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, TALLY_PX, font_px, paper if reached else ink)


var _default: Button = null


func bind(model: Dictionary) -> void:
	clear()
	var backdrop: ColorRect = UiKit.backdrop(color("bg_edge"))
	add_child(backdrop)
	ArtLibrary.shared().mount_fill(backdrop, "table")
	_add_sheet(model)
	var column: VBoxContainer = UiKit.vbox(12)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(column)
	UiKit.place(column, COLUMN_RECT)
	var title: Label = UiKit.label(tr("menu.title"), RunUiTheme.LABEL_HERO)
	column.add_child(title)
	var gap: Control = Control.new()
	gap.custom_minimum_size.y = TITLE_GAP
	column.add_child(gap)
	var order: Array[Control] = []
	var card: Variant = model.get("continue_card")
	if card is Dictionary:
		var text: String = tr("menu.continue").format({"hero": card.hero_name, "n": card.floor, "f": card.floors, "phase": card.phase, "date": card.last_played})
		var resume: Button = _add_button(column, text, &"continue_requested", true)
		resume.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		order.append(resume)
	var new_run: Button = _add_button(column, tr("menu.new_run"), &"new_run_requested", order.is_empty())
	order.append(new_run)
	order.append(_add_button(column, tr("menu.run_log"), &"open_run_log", false))
	order.append(_add_button(column, tr("menu.unlocks"), &"open_unlocks", false))
	order.append(_add_button(column, tr("menu.settings"), &"open_settings", false))
	order.append(_add_button(column, tr("menu.quit"), &"quit_requested", false))
	_default = order[0] as Button
	for line: String in [str(model.get("load_line", "")), str(model.get("status_line", ""))]:
		if not line.is_empty():
			column.add_child(UiKit.label(line, RunUiTheme.LABEL_SMALL, true))
	UiKit.chain_focus(order)


func default_focus() -> Control:
	return _default


func _add_button(column: Control, text: String, intent: StringName, primary: bool) -> Button:
	var button: Button = UiKit.button(text, primary)
	button.pressed.connect(send.bind(intent, {}))
	column.add_child(button)
	return button


func _add_sheet(model: Dictionary) -> void:
	var shadow_style: StyleBoxFlat = StyleBoxFlat.new()
	shadow_style.bg_color = Color(color("ink"), SHADOW_ALPHA)
	shadow_style.shadow_color = Color(color("ink"), SHADOW_ALPHA)
	shadow_style.shadow_size = SHADOW_PX
	var shadow: Panel = Panel.new()
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.add_theme_stylebox_override(&"panel", shadow_style)
	add_child(shadow)
	UiKit.place(shadow, SHEET_RECT.grow(-4.0))
	var sheet: PanelContainer = UiKit.panel(RunUiTheme.PANEL_PARCHMENT)
	var paper: StyleBox = ArtLibrary.shared().parchment_sheet(SHEET_MARGIN_PX)
	if paper != null:
		sheet.add_theme_stylebox_override(&"panel", paper)
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sheet)
	UiKit.place(sheet, SHEET_RECT)
	for node: Control in [shadow, sheet]:
		node.pivot_offset = node.size / 2.0
		node.rotation_degrees = SHEET_TILT_DEG
	var page: VBoxContainer = UiKit.vbox(16)
	page.alignment = BoxContainer.ALIGNMENT_CENTER
	sheet.add_child(page)
	var lantern: Dictionary = ArtLibrary.shared().named_stamp(LANTERN_STAMP)
	if not lantern.is_empty():
		var art: TextureRect = TextureRect.new()
		art.texture = lantern.texture
		art.modulate = lantern.tint
		art.custom_minimum_size.y = LANTERN_H
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		page.add_child(art)
	page.add_child(UiKit.rule(Color(color("text_ink"), RULE_ALPHA)))
	var floors: int = int(model.get("floors", 0))
	if floors > 0:
		page.add_child(_tally(floors, int(model.get("best_floor", 0))))
	var stats: String = tr("menu.stats").format({"runs": model.get("runs", 0), "wins": model.get("wins", 0), "best": model.get("best_floor", 0)})
	var stats_label: Label = UiKit.label(stats, RunUiTheme.LABEL_INK_BODY, true)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(stats_label)


func _tally(floors: int, best: int) -> Control:
	var tally: FloorTally = FloorTally.new()
	tally.floors = floors
	tally.best = best
	tally.ink = color("text_ink")
	tally.paper = color("parchment")
	tally.font_px = int(cfg.font_px.small)
	tally.custom_minimum_size.y = TALLY_PX + 2.0
	tally.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tally
