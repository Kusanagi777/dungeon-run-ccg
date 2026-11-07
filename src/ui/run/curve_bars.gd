## A deck's cost curve as a small ruled chart: one bar per cost, its count above and the
## cost below. Display only.
## [codeblock]
## var bars := CurveBars.new()
## parent.add_child(bars)
## bars.show_curve(hero.curve, bar_color, label_color, 13, 72.0)
## [/codeblock]
class_name CurveBars
extends Control

const BAR_W_PX: float = 16.0
const LABEL_H_PX: float = 16.0
## A cost with no cards still marks its place on the line.
const EMPTY_BAR_PX: float = 1.0

var _curve: Array = []
var _bar: Color = Color.WHITE
var _text: Color = Color.WHITE
var _font_px: int = 13


## Shows [param curve], the card count at each cost from 0, [param height] tall.
func show_curve(curve: Array, bar: Color, text: Color, font_px: int, height: float) -> void:
	_curve = curve
	_bar = bar
	_text = text
	_font_px = font_px
	custom_minimum_size.y = height
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	if _curve.is_empty():
		return
	var font: Font = UiFonts.serif(UiFonts.WEIGHT_BOLD)
	if font == null:
		font = get_theme_default_font()
	var most: float = 1.0
	for count: Variant in _curve:
		most = maxf(most, float(count))
	var pitch: float = size.x / float(_curve.size())
	var base: float = size.y - LABEL_H_PX
	var tall: float = base - LABEL_H_PX
	for i: int in _curve.size():
		var count: int = int(_curve[i])
		var centre: float = pitch * (i + 0.5)
		var height: float = maxf(tall * float(count) / most, EMPTY_BAR_PX)
		draw_rect(Rect2(centre - BAR_W_PX / 2.0, base - height, BAR_W_PX, height), _bar)
		if count > 0:
			_centred(font, str(count), Vector2(centre, base - height - 3.0))
		_centred(font, str(i), Vector2(centre, size.y - 2.0))


func _centred(font: Font, text: String, baseline: Vector2) -> void:
	var half: float = size.x / float(_curve.size()) / 2.0
	draw_string(font, baseline - Vector2(half, 0), text, HORIZONTAL_ALIGNMENT_CENTER, half * 2.0, _font_px, _text)
