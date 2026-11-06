## `controls` (Alpha; ADR-0004 addendum; accessibility Motor "Full input remapping"): one
## row per rebindable action, a conflict warning, and Reset to defaults. `Esc` is never
## bound and always cancels a capture, which is what keeps a bad rebind recoverable.
## Bindings are written through `set_binding`; the list rebinds when they change.
extends Screen

const MARGIN_PX: int = 48
const LABEL_W: float = 320.0
const KEYS_W: float = 360.0

var _capturing: String = ""
var _prompt: Label = null
var _order: Array[Control] = []


func bind(model: Dictionary) -> void:
	clear()
	cancel_intent = &"back"
	_capturing = ""
	_order.clear()
	add_child(UiKit.backdrop(color("bg_edge")))
	var frame: MarginContainer = UiKit.margin(MARGIN_PX)
	add_child(frame)
	var column: VBoxContainer = UiKit.vbox(10)
	frame.add_child(column)
	column.add_child(UiKit.label(tr("controls.title"), RunUiTheme.LABEL_TITLE))
	_prompt = UiKit.label(tr("controls.hint"), RunUiTheme.LABEL_MUTED)
	column.add_child(_prompt)
	var scroll: ScrollContainer = UiKit.scroll()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var rows: VBoxContainer = UiKit.vbox(6)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	for row: Dictionary in model.get("rows", []):
		rows.add_child(_row(row))
	var bar: HBoxContainer = UiKit.hbox(16)
	column.add_child(bar)
	var reset: Button = UiKit.button(tr("controls.reset"))
	reset.pressed.connect(send.bind(&"reset_bindings", {}))
	bar.add_child(reset)
	var back: Button = UiKit.button(tr("common.back"), true)
	back.pressed.connect(send.bind(&"back", {}))
	bar.add_child(back)
	_order.append_array([reset, back])
	UiKit.chain_focus(_order)


func default_focus() -> Control:
	return _order[0] if not _order.is_empty() else null


func handle_cancel() -> void:
	if _capturing.is_empty():
		super.handle_cancel()
	else:
		_stop_capture()


func _row(row: Dictionary) -> Control:
	var line: HBoxContainer = UiKit.hbox(12)
	var name_label: Label = UiKit.label(str(row.label), &"", true)
	name_label.custom_minimum_size.x = LABEL_W
	line.add_child(name_label)
	var keys: Label = UiKit.label(str(row["keys"]), RunUiTheme.LABEL_MUTED, true)
	keys.custom_minimum_size.x = KEYS_W
	line.add_child(keys)
	var rebind: Button = UiKit.button(tr("controls.rebind"))
	rebind.pressed.connect(_start_capture.bind(str(row.action), str(row.label)))
	line.add_child(rebind)
	_order.append(rebind)
	if bool(row.conflict):
		line.add_child(UiKit.label(tr("controls.conflict"), RunUiTheme.LABEL_DANGER))
	return line


func _start_capture(action: String, label: String) -> void:
	_capturing = action
	_prompt.text = tr("controls.capture").format({"action": label})


func _stop_capture() -> void:
	_capturing = ""
	_prompt.text = tr("controls.hint")


func _input(event: InputEvent) -> void:
	if _capturing.is_empty() or not event.is_pressed() or event.is_echo():
		return
	if not (event is InputEventKey or event is InputEventJoypadButton):
		return
	get_viewport().set_input_as_handled()
	if event.is_action(&"ui_cancel"):
		_stop_capture()
		return
	var action: String = _capturing
	_stop_capture()
	send(&"set_binding", {"action": action, "event": InputBindings.to_dict(event)})
