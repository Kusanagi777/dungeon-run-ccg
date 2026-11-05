## `main_menu` (run-ui U2; AC-1): New Run, the Continue card when a run is saved, Run
## Log, Settings, Quit, the stats line and the one-time load-status line.
extends Screen

const COLUMN_W: float = 400.0

var _default: Button = null


func bind(model: Dictionary) -> void:
	clear()
	add_child(UiKit.backdrop(color("bg_edge")))
	var centre: CenterContainer = CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var column: VBoxContainer = UiKit.vbox(12)
	column.custom_minimum_size.x = COLUMN_W
	centre.add_child(column)
	var title: Label = UiKit.label(tr("menu.title"), RunUiTheme.LABEL_HERO)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var order: Array[Control] = []
	var card: Variant = model.get("continue_card")
	if card is Dictionary:
		var text: String = tr("menu.continue").format({"hero": card.hero_name, "n": card.floor, "f": card.floors, "phase": card.phase, "date": card.last_played})
		order.append(_add_button(column, text, &"continue_requested", true))
	var new_run: Button = _add_button(column, tr("menu.new_run"), &"new_run_requested", order.is_empty())
	order.append(new_run)
	order.append(_add_button(column, tr("menu.run_log"), &"open_run_log", false))
	order.append(_add_button(column, tr("menu.settings"), &"open_settings", false))
	order.append(_add_button(column, tr("menu.quit"), &"quit_requested", false))
	_default = order[0] as Button
	var stats: String = tr("menu.stats").format({"runs": model.get("runs", 0), "wins": model.get("wins", 0), "best": model.get("best_floor", 0)})
	var stats_label: Label = UiKit.label(stats, RunUiTheme.LABEL_MUTED)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(stats_label)
	for line: String in [str(model.get("load_line", "")), str(model.get("status_line", ""))]:
		if not line.is_empty():
			var status: Label = UiKit.label(line, RunUiTheme.LABEL_SMALL, true)
			status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			column.add_child(status)
	UiKit.chain_focus(order)


func default_focus() -> Control:
	return _default


func _add_button(column: Control, text: String, intent: StringName, primary: bool) -> Button:
	var button: Button = UiKit.button(text, primary)
	button.pressed.connect(send.bind(intent, {}))
	column.add_child(button)
	return button
