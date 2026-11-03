# res://scripts/targeting_arrow.gd
class_name targeting_arrow
extends Node2D

## Arrow visual settings
@export var arrow_color: Color = Color.RED
@export var arrow_width: float = 4.0
@export var head_size: float = 15.0

## Bezier curve control
@export var curve_height: float = 50.0

## Start and end positions
var start_pos: Vector2
var end_pos: Vector2


func _ready() -> void:
	z_index = 1000


func _draw() -> void:
	if start_pos == Vector2.ZERO:
		return
	
	# Calculate bezier control point
	var mid_point := (start_pos + end_pos) / 2.0
	var control_point := mid_point + Vector2(0, -curve_height)
	
	# Draw bezier curve
	var points: PackedVector2Array = []
	var segments := 20
	
	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var point := _quadratic_bezier(start_pos, control_point, end_pos, t)
		points.append(point)
	
	# Draw the curve
	if points.size() >= 2:
		draw_polyline(points, arrow_color, arrow_width, true)
	
	# Draw arrowhead
	if points.size() >= 2:
		var direction := (points[-1] - points[-2]).normalized()
		var perpendicular := Vector2(-direction.y, direction.x)
		
		var tip := end_pos
		var left := tip - direction * head_size + perpendicular * head_size * 0.5
		var right := tip - direction * head_size - perpendicular * head_size * 0.5
		
		var arrow_points := PackedVector2Array([tip, left, right])
		draw_colored_polygon(arrow_points, arrow_color)


## Quadratic bezier interpolation
func _quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var q0 := p0.lerp(p1, t)
	var q1 := p1.lerp(p2, t)
	return q0.lerp(q1, t)


## Set the starting position
func start_from(pos: Vector2) -> void:
	start_pos = pos
	end_pos = pos
	queue_redraw()


## Update the end position
func update_end_position(pos: Vector2) -> void:
	end_pos = pos
	queue_redraw()
