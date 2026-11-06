## The reason dialog (run-ui Edge Cases "Saves and resume"; AC-13): a run that cannot be
## resumed says why, with one button, New Run. No `Esc`: it has no cancel.
extends Screen

const WIDTH_PX: float = 520.0

var _new_run: Button = null


func bind(model: Dictionary) -> void:
	clear()
	var column: VBoxContainer = modal_body(WIDTH_PX)
	column.add_child(UiKit.label(str(model.get("title", "")), RunUiTheme.LABEL_HEADING, true))
	column.add_child(UiKit.label(str(model.get("body", "")), &"", true))
	_new_run = UiKit.button(tr("menu.new_run"), true)
	_new_run.pressed.connect(send.bind(&"notice_new_run", {}))
	column.add_child(_new_run)


func default_focus() -> Control:
	return _new_run
