## A floating number on an `ink` pill (art bible §4 rule a; interaction-patterns
## Floating Number): `−n` in `state_danger`, `+n` in `state_buff`. A presenter child,
## spawned per step and freed at the step's `apply_final`.
## [codeblock]
## var pop: NumberPop = NUMBER_POP_SCENE.instantiate()
## add_child(pop)
## pop.show_number("−3", ui.color("state_danger"), ui.color("ink"), 22, centre)
## [/codeblock]
class_name NumberPop
extends Control

const PILL_SIZE: Vector2 = Vector2(56, 32)
const PILL_RADIUS: int = 8


## Draws [param text] in [param color] on a [param pill] of colour, centred on [param centre].
func show_number(text: String, color: Color, pill: Color, font_px: int, centre: Vector2) -> void:
	size = PILL_SIZE
	position = centre - PILL_SIZE / 2.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = pill
	style.set_corner_radius_all(PILL_RADIUS)
	box.add_theme_stylebox_override("panel", style)
	box.size = PILL_SIZE
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var label := Label.new()
	label.text = text
	label.size = PILL_SIZE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_px)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
