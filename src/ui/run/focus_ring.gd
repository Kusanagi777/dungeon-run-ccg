## The one focus ring (run-ui U3; interaction-patterns Focus Management): four 2 px
## `state_actionable` corner marks 3 px off the focused control, at every `anim_speed`,
## the registration marks of a ledger page. One overlay that follows the viewport's focus
## owner, not a stylebox per widget.
## [codeblock]
## ring.configure(RunUiConfig.color(cfg, "state_actionable"))
## [/codeblock]
class_name FocusRing
extends Control

const WIDTH_PX: float = 2.0
const OFFSET_PX: float = 3.0
## How far each corner mark runs along its two sides.
const MARK_PX: float = 12.0

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
		var box: Rect2 = local.grow(OFFSET_PX)
		var arm: Vector2 = (box.size / 2.0).min(Vector2.ONE * MARK_PX)
		for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
			var at: Vector2 = box.position + box.size * corner
			var inward: Vector2 = Vector2.ONE - corner * 2.0
			draw_polyline([at + Vector2(arm.x * inward.x, 0), at, at + Vector2(0, arm.y * inward.y)], _ring_color, WIDTH_PX)
