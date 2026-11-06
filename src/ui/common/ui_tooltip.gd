## The one tooltip panel (interaction-patterns Tooltip): `parchment` with `text_ink`,
## never covering what it describes, flipped to stay on screen. It takes no focus and no
## clicks. Match UI and Run UI each hold one; it knows no presenter.
## [codeblock]
## var tip := UiTooltip.new()
## parent.add_child(tip)
## tip.configure(fill, ink, 14, 300.0, Rect2(0, 0, 1280, 720))
## tip.show_above(Vector2(640, 300), tr("reject.NOT_ENOUGH_MANA"))
## [/codeblock]
class_name UiTooltip
extends PanelContainer

const PADDING_PX: int = 8
const CORNER_PX: int = 4
const GAP_PX: float = 8.0
## Over the hand fan and the pause menu: nothing may cover a reason.
const TOOLTIP_Z: int = 340

var _label: Label = null
var _bounds: Rect2 = Rect2()
var _max_w: float = 300.0


## Styles the panel: [param fill] behind [param ink] text of [param font_px], at most
## [param max_w] wide, kept inside [param bounds].
func configure(fill: Color, ink: Color, font_px: int, max_w: float, bounds: Rect2) -> void:
	_max_w = max_w
	_bounds = bounds
	top_level = true
	visible = false
	z_index = TOOLTIP_Z
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(CORNER_PX)
	style.set_content_margin_all(PADDING_PX)
	add_theme_stylebox_override("panel", style)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", font_px)
	_label.add_theme_color_override("font_color", ink)
	add_child(_label)


## Shows [param text] with its bottom centre just above [param anchor], below it when
## there is no room, clamped to the bounds.
func show_above(anchor: Vector2, text: String) -> void:
	var box: Vector2 = _measure(text)
	var at := Vector2(anchor.x - box.x / 2.0, anchor.y - box.y - GAP_PX)
	if at.y < _bounds.position.y:
		at.y = anchor.y + GAP_PX
	_hold(Rect2(at.clamp(_bounds.position, _bounds.end - box), box))


## Shows [param text] with its top centre just below [param anchor], clamped to the bounds.
func show_below(anchor: Vector2, text: String) -> void:
	var box: Vector2 = _measure(text)
	_hold(Rect2(Vector2(anchor.x - box.x / 2.0, anchor.y + GAP_PX).clamp(_bounds.position, _bounds.end - box), box))


## Hides the panel.
func hide_now() -> void:
	visible = false


# The box [param text] needs. A wrapped label's own minimum is stale until the container
# has sorted, so the words are measured.
func _measure(text: String) -> Vector2:
	var inner: float = _max_w - 2.0 * PADDING_PX
	_label.text = text
	_label.custom_minimum_size = Vector2(inner, 0)
	var font_px: int = _label.get_theme_font_size(&"font_size")
	var words: Vector2 = _label.get_theme_font(&"font").get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, inner, font_px)
	return Vector2(_max_w, words.y + 2.0 * PADDING_PX)


# Sets [param rect] now and again once the container has sorted.
func _hold(rect: Rect2) -> void:
	visible = true
	_set_rect(rect)
	_set_rect.call_deferred(rect)


func _set_rect(rect: Rect2) -> void:
	size = rect.size
	position = rect.position
