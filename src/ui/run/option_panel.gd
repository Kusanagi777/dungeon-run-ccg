## One selectable option of a Pick One of N row (interaction-patterns "Pick One of N";
## run-ui U3): hero select's panels and both draft screens. Hover lifts it with no ring
## and never moves focus; focus and click select. Absolute-positioned, so the lift moves
## `position` and the F4 slot stays exact when it ends.
## [codeblock]
## var option := OptionPanel.new()
## option.setup(0, 8.0)
## option.activated.connect(_on_activated)
## [/codeblock]
class_name OptionPanel
extends PanelContainer

## `Enter` or a click on the option.
signal activated(index: int)
## A double click: the shortcut for select then confirm.
signal double_activated(index: int)
## The option took focus, or the pointer entered it.
signal highlighted(index: int)
## Focus or the pointer left it.
signal unhighlighted(index: int)

var _index: int = 0
var _lift_px: float = 0.0
var _rest_y: float = 0.0
var _lifted: bool = false


## Sets the [param index] this option reports, and how far [param lift_px] a hover lifts it.
func setup(index: int, lift_px: float) -> void:
	_index = index
	_lift_px = lift_px
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_pointer.bind(true))
	mouse_exited.connect(_on_pointer.bind(false))
	focus_entered.connect(func() -> void: highlighted.emit(_index))
	focus_exited.connect(func() -> void: unhighlighted.emit(_index))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		grab_focus()
		if event.double_click:
			double_activated.emit(_index)
		else:
			activated.emit(_index)
		accept_event()
	elif event.is_action_pressed(&"ui_accept"):
		activated.emit(_index)
		accept_event()


func _on_pointer(entered: bool) -> void:
	if entered and not _lifted:
		_rest_y = position.y
		position.y -= _lift_px
		_lifted = true
		highlighted.emit(_index)
	elif not entered and _lifted:
		position.y = _rest_y
		_lifted = false
		unhighlighted.emit(_index)
