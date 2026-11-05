## One minion on a row (art bible §4 token, 90x126): art box, attack and health stamps,
## and a badge row of letter glyphs, each glyph the non-colour backup of its state.
## It lives in a Container, so every lift and lunge is an `offset_transform_*` (4.7).
## [codeblock]
## var token: MinionToken = TOKEN_SCENE.instantiate()
## row.add_child(token)
## token.configure(ui)
## token.show_token(view.entity(id), ui.card_face(card_id))
## [/codeblock]
class_name MinionToken
extends Control

const ATTACK_CENTRE: Vector2 = Vector2(15, 111)
const HEALTH_CENTRE: Vector2 = Vector2(75, 111)
const STAMP_RADIUS: float = 13.0
const STAMP_RING_PX: float = 2.0
const STAMP_FONT_PX: int = 14
const BADGE_FONT_PX: int = 14
const ART_FONT_PX: int = 24
const ART_RECT: Rect2 = Rect2(5, 5, 80, 88)
const BADGE_RECT: Rect2 = Rect2(5, 74, 80, 18)
const CORNER_PX: int = 6
const FRAME_PX: int = 2
const FLAG_SICK: String = "summoning_sick"
const FLAG_FROZEN: String = "frozen"
const FLAG_SILENCED: String = "silenced"
const BURST_GROW_PX: float = 24.0

## The engine's id of this minion.
var entity_id: int = 0
## The card this minion was summoned from.
var card_id: String = ""
## The ring burst's progress, 0 to 1 (`divine_shield_popped`, no number).
var burst: float = 0.0:
	set(value):
		burst = value
		queue_redraw()

var _ui: MatchUiContext = null
var _shown: Dictionary = {}
var _face: Dictionary = {}
var _lit: bool = false
var _target: bool = false
var _ring: bool = false
var _sick: bool = false
var _art: Label = null
var _badges: Label = null
var _attack: Label = null
var _health: Label = null


## Stores the palette source and builds the labels.
func configure(context: MatchUiContext) -> void:
	_ui = context
	var board: Dictionary = _ui.config.board
	var token_size := Vector2(float(board.token_w), float(board.token_h))
	custom_minimum_size = token_size
	size = token_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	offset_transform_enabled = true
	offset_transform_pivot_ratio = Vector2(0.5, 0.5)
	_art = _label(ART_RECT, ART_FONT_PX)
	_centre(_art)
	_badges = _label(BADGE_RECT, BADGE_FONT_PX)
	_badges.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_attack = _stamp_label(ATTACK_CENTRE)
	_health = _stamp_label(HEALTH_CENTRE)


## Shows [param token], a `board` entry of the view-state; [param face] gives the
## printed stats and colours.
func show_token(token: Dictionary, face: Dictionary) -> void:
	entity_id = int(token.entity_id)
	card_id = str(token.card_id)
	_shown = token.duplicate(true)
	_face = face
	_art.text = tr(str(face.get("name_key", ""))).left(1)
	_attack.text = str(int(token.attack))
	_health.text = str(int(token.health))
	var printed_attack: int = int(face.get("attack", token.attack)) if face.get("attack") != null else int(token.attack)
	var attack_token: String = "state_buff" if int(token.attack) > printed_attack else "text_light"
	_attack.add_theme_color_override("font_color", _ui.color(attack_token))
	var health_token: String = "text_light"
	if int(token.health) < int(token.max_health):
		health_token = "state_danger"
	elif face.get("health") != null and int(token.max_health) > int(face.health):
		health_token = "state_buff"
	_health.add_theme_color_override("font_color", _ui.color(health_token))
	_refresh_badges()
	queue_redraw()


## The fields [method BoardPresenter.sync_report] compares.
func shown() -> Dictionary:
	return _shown


## [param lit]: the `state_actionable` can-attack outline.
func set_lit(lit: bool) -> void:
	_lit = lit
	queue_redraw()


## [param target]: the `state_target` outline; [param ring]: the 3 px hover ring (U7).
func set_target(target: bool, ring: bool) -> void:
	_target = target
	_ring = ring
	queue_redraw()


## The summoning-sick badge, read at `Idle` from the query: no event reports it.
func set_summoning_sick(sick: bool) -> void:
	_sick = sick
	_refresh_badges()


func _draw() -> void:
	if _face.is_empty():
		return
	var body := StyleBoxFlat.new()
	body.bg_color = _ui.color("ink")
	body.set_corner_radius_all(CORNER_PX)
	body.set_border_width_all(FRAME_PX)
	body.border_color = _face.get("primary", _ui.color("neutral"))
	draw_style_box(body, Rect2(Vector2.ZERO, size))
	draw_rect(ART_RECT, _face.get("secondary", _ui.color("neutral")))
	for centre: Vector2 in [ATTACK_CENTRE, HEALTH_CENTRE]:
		draw_circle(centre, STAMP_RADIUS, _ui.color("stamp_ring"))
		draw_circle(centre, STAMP_RADIUS - STAMP_RING_PX, _ui.color("ink"))
	var outline: Variant = null
	var width: int = int(_ui.config.targeting.outline_px)
	if _target:
		outline = _ui.color("state_target")
		if _ring:
			width = int(_ui.config.targeting.ring_px)
	elif bool(_shown.get(FLAG_FROZEN, false)):
		outline = _ui.color("state_freeze")
	elif _lit:
		outline = _ui.color("state_actionable")
	if outline != null:
		var frame := StyleBoxFlat.new()
		frame.draw_center = false
		frame.set_corner_radius_all(CORNER_PX)
		frame.set_border_width_all(width)
		frame.border_color = outline
		draw_style_box(frame, Rect2(Vector2.ZERO, size))
	if burst > 0.0:
		var grow: float = burst * BURST_GROW_PX
		draw_arc(size / 2.0, size.y / 2.0 + grow, 0.0, TAU, 32, _ui.color("text_light"), float(_ui.config.targeting.outline_px))


func _refresh_badges() -> void:
	var glyphs: PackedStringArray = []
	var known: Dictionary = _ui.config.get("glyphs", {})
	for keyword: Variant in _shown.get("keywords", []):
		if known.has(str(keyword)):
			glyphs.append(_ui.glyph(str(keyword)))
	if bool(_shown.get(FLAG_FROZEN, false)):
		glyphs.append(_ui.glyph(FLAG_FROZEN))
	if bool(_shown.get(FLAG_SILENCED, false)):
		glyphs.append(_ui.glyph(FLAG_SILENCED))
	if _sick:
		glyphs.append(_ui.glyph(FLAG_SICK))
	_badges.text = " ".join(glyphs)


func _label(rect: Rect2, font_px: int) -> Label:
	var label := Label.new()
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_size_override("font_size", font_px)
	label.add_theme_color_override("font_color", _ui.color("text_light"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _stamp_label(centre: Vector2) -> Label:
	var box := Vector2(STAMP_RADIUS, STAMP_RADIUS)
	var label: Label = _label(Rect2(centre - box, box * 2.0), STAMP_FONT_PX)
	_centre(label)
	return label


func _centre(label: Label) -> void:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
