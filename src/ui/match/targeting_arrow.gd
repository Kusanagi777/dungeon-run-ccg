## The targeting arrow and the drop affordances (ADR-0009 `targeting_arrow.tscn`;
## match-ui U7; targeting.md §5): a quadratic Bezier from the source to the cursor, its
## control point `arrow_lift_px` above the midpoint, with a triangular head, redrawn
## each frame while active; plus the dashed cast zone and summon slot. Widths come from
## data: 4.7 lines have no antialiasing feather. It is state, not animation, so it
## draws at every `anim_speed`.
## [codeblock]
## arrow.start_from(source_centre)
## arrow.update_end(mouse, over_a_target)
## arrow.stop()
## [/codeblock]
class_name TargetingArrow
extends Presenter

var _active: bool = false
var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO
var _lit: bool = false
var _zone: Rect2 = Rect2()
var _slot: Rect2 = Rect2()
var _zone_dim: bool = false
var _snap: Tween = null


func bind(_view_state: MatchViewState) -> void:
	return


func owns(_entity_ids: Array[int]) -> bool:
	return false


func on_step_started(_step: AnimStep, _d_eff: float) -> void:
	return


func apply_final(_step: AnimStep) -> void:
	return


func sync_report() -> Array[String]:
	return []


## True while the arrow is drawn.
func is_active() -> bool:
	return _active


## The arrow's two ends, `[from, to]`.
func ends() -> Array[Vector2]:
	return [_from, _to]


## Starts the arrow at [param from].
func start_from(from: Vector2) -> void:
	_active = true
	_from = from
	_to = from
	queue_redraw()


## Moves the head to [param to]; [param lit] says it is over a legal target.
func update_end(to: Vector2, lit: bool) -> void:
	_to = to
	_lit = lit
	queue_redraw()


## Moves the head to [param to] over [param seconds], for a key cycle (targeting.md §10
## "Arrow snap"); 0 s is immediate.
func snap_to(to: Vector2, lit: bool, seconds: float) -> void:
	if _snap != null:
		_snap.kill()
		_snap = null
	if seconds <= 0.0:
		update_end(to, lit)
		return
	_lit = lit
	_snap = create_tween()
	_snap.tween_method(func(head: Vector2) -> void:
		_to = head
		queue_redraw(), _to, to, seconds).set_ease(Tween.EASE_OUT)


## Shows the dashed zone [param zone], or none for an empty rect.
func show_cast_zone(zone: Rect2) -> void:
	_zone = zone
	_zone_dim = false
	queue_redraw()


## §7.4: over a source a click would re-select, the zone drops to `unlit_alpha`.
func set_zone_dim(dim: bool) -> void:
	_zone_dim = dim
	queue_redraw()


## Shows the dashed summon slot [param slot], or none for an empty rect.
func show_slot(slot: Rect2) -> void:
	_slot = slot
	queue_redraw()


## Ends the arrow and every affordance.
func stop() -> void:
	if _snap != null:
		_snap.kill()
		_snap = null
	_active = false
	_zone = Rect2()
	_slot = Rect2()
	queue_redraw()


## F: the U7 curve from [param from] to [param to] in [param segments] pieces.
static func curve(from: Vector2, to: Vector2, lift: float, segments: int) -> PackedVector2Array:
	var control: Vector2 = (from + to) / 2.0 - Vector2(0, lift)
	var points := PackedVector2Array()
	for i: int in segments + 1:
		var t: float = float(i) / float(segments)
		points.append(from.lerp(control, t).lerp(control.lerp(to, t), t))
	return points


func _draw() -> void:
	var cfg: Dictionary = ui.config.targeting
	var actionable: Color = ui.color("state_actionable")
	if _zone.has_area():
		var zone_color: Color = Color(actionable, float(cfg.unlit_alpha)) if _zone_dim else actionable
		_draw_dashed_rect(_zone, zone_color, float(cfg.outline_px), float(cfg.dash_px))
	if _slot.has_area():
		_draw_dashed_rect(_slot, actionable, float(cfg.outline_px), float(cfg.dash_px))
	if not _active:
		return
	var color: Color = ui.color("state_target")
	var points: PackedVector2Array = curve(_from, _to, float(cfg.arrow_lift_px), int(cfg.arrow_segments))
	draw_polyline(points, color, float(cfg.arrow_width_px))
	var head_color: Color = color if _lit else Color(color, float(cfg.unlit_alpha))
	var tail: Vector2 = points[points.size() - 2]
	var forward: Vector2 = (_to - tail).normalized()
	var side: Vector2 = forward.orthogonal()
	var head: float = float(cfg.head_px)
	draw_colored_polygon(PackedVector2Array([_to + forward * head / 2.0, _to - forward * head / 2.0 + side * head / 2.0, _to - forward * head / 2.0 - side * head / 2.0]), head_color)


func _draw_dashed_rect(rect: Rect2, color: Color, width: float, dash: float) -> void:
	var corners: Array[Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i: int in corners.size():
		draw_dashed_line(corners[i], corners[(i + 1) % corners.size()], color, width, dash)
