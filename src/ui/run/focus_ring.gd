## The one focus ring (run-ui U3; interaction-patterns Focus Management): a 2 px
## `state_actionable` outline 3 px off the focused control, at every `anim_speed`. One
## overlay that follows the viewport's focus owner, not a stylebox per widget.
## [codeblock]
## ring.configure(RunUiConfig.color(cfg, "state_actionable"))
## [/codeblock]
class_name FocusRing
extends Control

const WIDTH_PX: float = 2.0
const OFFSET_PX: float = 3.0

var _ring_color: Color = Color.WHITE
var _rect: Rect2 = Rect2()
var _shown: bool = false


## Sets the ring colour.
func configure(ring_color: Color) -> void:
	_ring_color = ring_color
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	var focused: Control = get_viewport().gui_get_focus_owner()
	var showing: bool = focused != null and focused.is_visible_in_tree()
	var rect: Rect2 = focused.get_global_rect() if showing else Rect2()
	if showing != _shown or rect != _rect:
		_shown = showing
		_rect = rect
		queue_redraw()


func _draw() -> void:
	if _shown:
		var local: Rect2 = Rect2(_rect.position - global_position, _rect.size)
		draw_rect(local.grow(OFFSET_PX), _ring_color, false, WIDTH_PX)
