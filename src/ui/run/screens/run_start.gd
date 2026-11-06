## `run_start` (run-ui U2, S9): the hero colour and the seed for `run_start_ms`. No
## intent of its own: any input skips it, and the time running out does the same.
extends Screen


func bind(model: Dictionary) -> void:
	clear()
	add_child(UiKit.backdrop(color(str(model.get("hero_color", "neutral")))))
	var centre: CenterContainer = CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var column: VBoxContainer = UiKit.vbox(12)
	centre.add_child(column)
	column.add_child(UiKit.label(str(model.get("hero_name", "")), RunUiTheme.LABEL_TITLE))
	column.add_child(UiKit.label(tr("run_start.seed").format({"seed": model.get("seed", "")}), RunUiTheme.LABEL_MUTED))
	var ms: int = int(model.get("duration_ms", 0))
	if ms <= 0:
		send.call_deferred(&"skip", {})
	else:
		get_tree().create_timer(ms / RunUiConfig.MS_PER_S).timeout.connect(send.bind(&"skip", {}))


func default_focus() -> Control:
	return null
