## `settings` (run-ui U2; DD-X07, DD-X10): the player-settings record, owned by Meta and
## edited here live through `set_setting`. Segmented choices are discrete on purpose:
## text scale offers exactly its three steps (AC-31). Controls and Glossary open on top;
## Clear run records and Reset profile go through `confirm`.
extends Screen

const MARGIN_PX: int = 48
const LABEL_W: float = 320.0
const SLIDER_W: float = 320.0
const SWATCH: Vector2 = Vector2(56, 28)
const PERCENT: float = 100.0
const GAMMA_TOKENS: Array[String] = ["bg_edge", "table_dark", "table_lit"]
const SPEEDS: Array[String] = ["instant", "fast", "normal"]
const TELEGRAPHS: Array[String] = ["full", "brief", "off"]
const TEXT_SCALES: Array[float] = [1.0, 1.25, 1.5]

var _values: Dictionary = {}
var _order: Array[Control] = []
var _rows: VBoxContainer = null
var _back: Button = null


func bind(model: Dictionary) -> void:
	clear()
	cancel_intent = &"back"
	_values = model.get("values", {})
	_order.clear()
	add_child(UiKit.backdrop(color("bg_edge")))
	var frame: MarginContainer = UiKit.margin(MARGIN_PX)
	add_child(frame)
	var column: VBoxContainer = UiKit.vbox(12)
	frame.add_child(column)
	column.add_child(UiKit.label(tr("settings.title"), RunUiTheme.LABEL_TITLE))
	var scroll: ScrollContainer = UiKit.scroll()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_rows = UiKit.vbox(10)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	var steps: Dictionary = cfg.settings_steps
	_add_slider("volume_master", 0.0, 1.0, float(steps.volume))
	_add_slider("volume_music", 0.0, 1.0, float(steps.volume))
	_add_slider("volume_sfx", 0.0, 1.0, float(steps.volume))
	_add_toggle("fullscreen")
	_add_slider("action_delay_ms", float(steps.action_delay_min), float(steps.action_delay_max), float(steps.action_delay))
	_add_segments("anim_speed", SPEEDS)
	_add_toggle("reduce_motion")
	_add_segments("text_scale", TEXT_SCALES)
	_add_segments("telegraph_mode", TELEGRAPHS)
	_add_toggle("high_contrast_states")
	_add_slider("gamma", float(steps.gamma_min), float(steps.gamma_max), float(steps.gamma))
	_add_gamma_swatches()
	_add_toggle("keep_run_records")
	_add_action(tr("settings.controls"), &"open_controls")
	_add_action(tr("settings.glossary"), &"open_glossary")
	_add_action(tr("settings.clear"), &"clear_run_records_requested")
	_add_action(tr("settings.reset"), &"reset_profile_requested")
	_back = UiKit.button(tr("common.back"), true)
	_back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_back.pressed.connect(send.bind(&"back", {}))
	column.add_child(_back)
	_order.append(_back)
	UiKit.chain_focus(_order)


func default_focus() -> Control:
	return _order[0] if not _order.is_empty() else null


func _row(key: String) -> HBoxContainer:
	var row: HBoxContainer = UiKit.hbox(12)
	var label: Label = UiKit.label(tr("settings.key.%s" % key), &"", true)
	label.custom_minimum_size.x = LABEL_W
	row.add_child(label)
	_rows.add_child(row)
	return row


func _add_slider(key: String, low: float, high: float, step: float) -> void:
	var row: HBoxContainer = _row(key)
	var slider: HSlider = HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = float(_values.get(key, low))
	slider.custom_minimum_size = Vector2(SLIDER_W, UiKit.MIN_HIT_PX)
	row.add_child(slider)
	var readout: Label = UiKit.label(_readout(key, slider.value), RunUiTheme.LABEL_MUTED)
	row.add_child(readout)
	slider.value_changed.connect(func(value: float) -> void:
		readout.text = _readout(key, value)
		send(&"set_setting", {"key": key, "value": int(value) if key == "action_delay_ms" else value}))
	_order.append(slider)


func _readout(key: String, value: float) -> String:
	if key == "action_delay_ms":
		return tr("settings.ms").format({"n": int(value)})
	if key == "gamma":
		return "%.2f" % value
	return tr("settings.percent").format({"n": roundi(value * PERCENT)})


func _add_toggle(key: String) -> void:
	var row: HBoxContainer = _row(key)
	var box: CheckBox = CheckBox.new()
	box.custom_minimum_size = Vector2(UiKit.MIN_HIT_PX, UiKit.MIN_HIT_PX)
	box.button_pressed = bool(_values.get(key, false))
	box.toggled.connect(func(on: bool) -> void: send(&"set_setting", {"key": key, "value": on}))
	row.add_child(box)
	_order.append(box)


func _add_segments(key: String, choices: Array) -> void:
	var row: HBoxContainer = _row(key)
	var group: ButtonGroup = ButtonGroup.new()
	for choice: Variant in choices:
		var button: Button = UiKit.button(_choice_label(key, choice))
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = _values.get(key) == choice
		button.pressed.connect(send.bind(&"set_setting", {"key": key, "value": choice}))
		row.add_child(button)
		_order.append(button)


func _choice_label(key: String, choice: Variant) -> String:
	if choice is float:
		return tr("settings.percent").format({"n": roundi(float(choice) * PERCENT)})
	return tr("settings.%s.%s" % [key, str(choice)])


func _add_gamma_swatches() -> void:
	var row: HBoxContainer = UiKit.hbox(4)
	row.add_child(UiKit.spacer())
	for token: String in GAMMA_TOKENS:
		var swatch: ColorRect = ColorRect.new()
		swatch.color = color(token)
		swatch.custom_minimum_size = SWATCH
		row.add_child(swatch)
	_rows.add_child(row)


func _add_action(text: String, intent: StringName) -> void:
	var button: Button = UiKit.button(text)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.pressed.connect(send.bind(intent, {}))
	_rows.add_child(button)
	_order.append(button)
