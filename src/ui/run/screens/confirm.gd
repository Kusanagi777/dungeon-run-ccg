## `confirm` (run-ui U2; AC-30): title, body, Confirm and Cancel, Cancel focused. With a
## `token` the typed field keeps Confirm disabled until it matches exactly.
extends Screen

const WIDTH_PX: float = 520.0

var _token: String = ""
var _confirm: Button = null
var _cancel: Button = null


func bind(model: Dictionary) -> void:
	clear()
	cancel_intent = &"cancel"
	_token = str(model.get("token", ""))
	var column: VBoxContainer = modal_body(WIDTH_PX)
	column.add_child(UiKit.label(str(model.get("title", "")), RunUiTheme.LABEL_HEADING, true))
	column.add_child(UiKit.label(str(model.get("body", "")), &"", true))
	var order: Array[Control] = []
	if not _token.is_empty():
		var field: LineEdit = LineEdit.new()
		field.custom_minimum_size.y = UiKit.MIN_HIT_PX
		field.text_changed.connect(_on_typed)
		column.add_child(field)
		order.append(field)
	var row: HBoxContainer = UiKit.hbox(16)
	column.add_child(row)
	_cancel = UiKit.button(tr("common.cancel"), true)
	_cancel.pressed.connect(send.bind(&"cancel", {}))
	row.add_child(_cancel)
	_confirm = UiKit.button(str(model.get("confirm_label", "")))
	_confirm.disabled = not _token.is_empty()
	_confirm.pressed.connect(send.bind(&"confirm", {}))
	row.add_child(_confirm)
	order.append_array([_cancel, _confirm])
	UiKit.chain_focus(order)


func default_focus() -> Control:
	return _cancel


func _on_typed(text: String) -> void:
	_confirm.disabled = text != _token
