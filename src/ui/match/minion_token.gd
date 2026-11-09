## One minion on a row (art bible §4 token, 90x126): art box, attack and health stamps,
## and the shared keyword / state badge row ([BadgeRow]), each badge the non-colour
## backup of its state. It lives in a Container, so every lift and lunge is an
## `offset_transform_*` (4.7).
##
## Persistent states draw from the shown entry (interaction-patterns Board Token):
## Taunt a thicker frame, Divine Shield a bubble, Stealth a shimmer, Silence a grey
## art box and a `state_freeze` outline, damaged a crack glyph, buffed an up-arrow,
## an armed trigger a rim glow. Step animations drive [member burst],
## [member status_pop], [member stat_pulse] and [member morph].
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
## The state glyphs beside the numerals: up-arrow right of attack, crack or
## up-arrow left of health (hud.md board tokens, art bible §4 table).
const ATTACK_MARK_AT: Vector2 = Vector2(30, 98)
const HEALTH_MARK_AT: Vector2 = Vector2(50, 98)
const CORNER_PX: int = 6
const FRAME_PX: int = 2
const FLAG_SICK: String = "summoning_sick"
const FLAG_ATTACKED: String = "attacked"
const FLAG_MASKED: String = "masked"
const KEYWORD_TAUNT: String = "taunt"
const KEYWORD_DIVINE_SHIELD: String = "divine_shield"
const KEYWORD_STEALTH: String = "stealth"
const FLAG_FROZEN: String = "frozen"
const FLAG_SILENCED: String = "silenced"
const BURST_GROW_PX: float = 24.0
const BUBBLE_INSET_PX: float = 3.0
const BUBBLE_RADIUS_PX: int = 14

## The engine's id of this minion.
var entity_id: int = 0
## The card this minion was summoned from.
var card_id: String = ""
## The ring burst's progress, 0 to 1 (`divine_shield_popped`, no number).
var burst: float = 0.0:
	set(value):
		burst = value
		queue_redraw()
## A status badge popping in or out, 0 to 1: its icon grows and flashes its status
## colour (the soft status cue). The names popping are set by [method pop_badges].
var status_pop: float = 0.0:
	set(value):
		status_pop = value
		queue_redraw()
## A stat change, 0 to 1: the numerals swell and settle.
var stat_pulse: float = 0.0:
	set(value):
		stat_pulse = value
		_pulse_numerals()
## A transform (Unmask), 0 to 1: a light flash that peaks at the swap.
var morph: float = 0.0:
	set(value):
		morph = value
		queue_redraw()

var _ui: MatchUiContext = null
var _shown: Dictionary = {}
var _face: Dictionary = {}
var _lit: bool = false
var _target: bool = false
var _ring: bool = false
var _sick: bool = false
var _armed: bool = false
var _player_side: bool = false
# The `A` numeral over this token, 0 for none.
var _attack_badge: int = 0
var _flash: bool = false
var _art: Label = null
var _badges: Label = null
var _attack: Label = null
var _health: Label = null
var _stamp: Dictionary = {}
var _badge_row: Array[Dictionary] = []
var _popping: Dictionary = {}
var _fading: Array[Dictionary] = []
var _shimmer_t: float = 0.0


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
	_art.add_theme_color_override("font_color", _ui.color("text_ink"))
	# The row's text form: never drawn (the icons are), kept for readers and tests.
	_badges = _label(BADGE_RECT, BADGE_FONT_PX)
	_badges.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badges.visible = false
	_attack = _stamp_label(ATTACK_CENTRE)
	_health = _stamp_label(HEALTH_CENTRE)
	_attack.pivot_offset = _attack.size / 2.0
	_health.pivot_offset = _health.size / 2.0
	set_process(false)


## Shows [param token], a `board` entry of the view-state; [param face] gives the
## printed stats, colours and tags.
func show_token(token: Dictionary, face: Dictionary) -> void:
	entity_id = int(token.entity_id)
	card_id = str(token.card_id)
	_shown = token.duplicate(true)
	_face = face
	_stamp = _ui.art().card_stamp(card_id, str(face.get("type", "minion")), str(face.get("set", "")))
	_art.visible = _stamp.is_empty()
	_art.text = tr(str(face.get("name_key", ""))).left(1)
	_attack.text = str(int(token.attack))
	_health.text = str(int(token.health))
	_attack.add_theme_color_override("font_color", _ui.color("state_buff" if _attack_buffed() else "text_light"))
	var health_token: String = "text_light"
	if _damaged():
		health_token = "state_danger"
	elif _health_buffed():
		health_token = "state_buff"
	_health.add_theme_color_override("font_color", _ui.color(health_token))
	_refresh_badges()
	_refresh_shimmer()
	queue_redraw()


## The fields [method BoardPresenter.sync_report] compares.
func shown() -> Dictionary:
	return _shown


## [param player]: this token is on the player's row, where "already attacked" shows.
func set_player_side(player: bool) -> void:
	_player_side = player
	_refresh_badges()


## [param lit]: the `state_actionable` can-attack outline.
func set_lit(lit: bool) -> void:
	_lit = lit
	_refresh_badges()
	queue_redraw()


## [param target]: the `state_target` outline; [param ring]: the 3 px hover ring (U7).
func set_target(target: bool, ring: bool) -> void:
	_target = target
	_ring = ring
	queue_redraw()


## Rejection Feedback's frame flash, in `state_danger`.
func set_flash(on: bool) -> void:
	_flash = on
	queue_redraw()


## The rim glow of an armed trigger source (`trigger_queued` until `trigger_resolved`).
func set_armed(on: bool) -> void:
	if _armed != on:
		_armed = on
		queue_redraw()


## True when this minion has Taunt, for the rejection flash.
func has_taunt() -> bool:
	return _keywords().has(KEYWORD_TAUNT)


## The `A` numeral [param number] in a pill over the token, 0 for none (targeting.md §5.3).
func set_attack_badge(number: int) -> void:
	_attack_badge = number
	queue_redraw()


## The summoning-sick badge, read at `Idle` from the query: no event reports it.
func set_summoning_sick(sick: bool) -> void:
	_sick = sick
	_refresh_badges()


## The badge names in the shown row, in table order.
func badge_names() -> PackedStringArray:
	var names: PackedStringArray = []
	for badge: Dictionary in _badge_row:
		names.append(str(badge.name))
	return names


## Marks the badges [member status_pop] animates: [param added] swell in and flash
## their status colour, [param removed] shrink out of the row (the soft status cue).
func pop_badges(added: Array, removed: Array = []) -> void:
	_popping.clear()
	for name: Variant in added:
		_popping[str(name)] = true
	_fading = _ui.badges(removed, true) if _ui != null else []


## The badge names this token would show for [param token] and [param face]: the
## keywords, then the states the entry and the query report.
func state_names(token: Dictionary, face: Dictionary) -> Array:
	var names: Array = (token.get("keywords", []) as Array).duplicate()
	var silenced: bool = bool(token.get(FLAG_SILENCED, false))
	if bool(face.get(FLAG_MASKED, false)) and not silenced:
		names.append(FLAG_MASKED)
	if bool(token.get(FLAG_FROZEN, false)):
		names.append(FLAG_FROZEN)
	if silenced:
		names.append(FLAG_SILENCED)
	if _sick:
		names.append(FLAG_SICK)
	elif _player_side and not _lit and int(token.get("attacks_used", 0)) > 0:
		names.append(FLAG_ATTACKED)
	return names


## Stops the Stealth shimmer, so a fade or a ghost owns this token's alpha.
func stop_shimmer() -> void:
	set_process(false)


func _process(delta: float) -> void:
	_shimmer_t += delta
	var band: Array = _ui.fx("stealth_alpha", [0.55, 0.85])
	var period: float = float(_ui.fx("shimmer_s", 1.6))
	var wave: float = (sin(_shimmer_t * TAU / period) + 1.0) / 2.0
	modulate.a = lerpf(float(band[0]), float(band[1]), wave)


func _refresh_shimmer() -> void:
	var stealthed: bool = _keywords().has(KEYWORD_STEALTH)
	var band: Array = _ui.fx("stealth_alpha", [0.55, 0.85])
	if not stealthed:
		set_process(false)
		if modulate.a < 1.0 and modulate.a >= float(band[0]) - 0.001:
			modulate.a = 1.0
		return
	if _ui.reduce_motion:
		set_process(false)
		modulate.a = (float(band[0]) + float(band[1])) / 2.0
	else:
		set_process(true)


func _draw() -> void:
	if _face.is_empty():
		return
	var body := StyleBoxFlat.new()
	var parchment: Texture2D = _ui.art().surface("parchment_card")
	if parchment != null:
		draw_texture_rect(parchment, Rect2(Vector2.ZERO, size), false)
		body.draw_center = false
	else:
		body.bg_color = _ui.color("parchment")
	body.set_corner_radius_all(CORNER_PX)
	body.set_border_width_all(int(_ui.fx("taunt_frame_px", 4)) if has_taunt() else FRAME_PX)
	body.border_color = _face.get("primary", _ui.color("neutral"))
	draw_style_box(body, Rect2(Vector2.ZERO, size))
	var silenced: bool = bool(_shown.get(FLAG_SILENCED, false))
	var wash: Color = (_face.get("secondary", _ui.color("neutral")) as Color).lerp(_ui.color("parchment"), CardFrame.ART_WASH)
	if silenced:
		var grey: float = wash.get_luminance()
		wash = wash.lerp(Color(grey, grey, grey), float(_ui.fx("silence_grey", 0.75)))
	draw_rect(ART_RECT, wash)
	if not _stamp.is_empty():
		var art: Texture2D = _stamp.texture
		var tint: Color = _stamp.tint
		if silenced:
			tint = Color(tint.get_luminance(), tint.get_luminance(), tint.get_luminance(), tint.a * 0.6)
		draw_texture_rect(art, ArtLibrary.fit_rect(art, ART_RECT, 1.0), false, tint)
	var pops: Dictionary = {}
	var row: Array[Dictionary] = _badge_row
	if status_pop > 0.0:
		var peak: float = float(_ui.fx("status_pop_scale", 1.8))
		for name: String in _popping:
			pops[name] = lerpf(1.0, peak, sin(status_pop * PI))
		if status_pop < 1.0 and not _fading.is_empty():
			row = _badge_row.duplicate()
			for badge: Dictionary in _fading:
				if not badge_names().has(str(badge.name)):
					row.append(badge)
					pops[badge.name] = maxf(1.0 - status_pop, 0.01)
	BadgeRow.draw(self, row, BADGE_RECT, BadgeRow.ALIGN_CENTER, _ui, pops)
	for centre: Vector2 in [ATTACK_CENTRE, HEALTH_CENTRE]:
		draw_circle(centre, STAMP_RADIUS, _ui.color("stamp_ring"))
		draw_circle(centre, STAMP_RADIUS - STAMP_RING_PX, _ui.color("ink"))
	_draw_stat_glyph("attack", ATTACK_CENTRE)
	_draw_stat_glyph("health", HEALTH_CENTRE)
	if _attack_buffed():
		_draw_mark("buffed", ATTACK_MARK_AT, "state_buff")
	if _damaged():
		_draw_mark("damaged", HEALTH_MARK_AT, "state_danger")
	elif _health_buffed():
		_draw_mark("buffed", HEALTH_MARK_AT, "state_buff")
	if _keywords().has(KEYWORD_DIVINE_SHIELD):
		var bubble := StyleBoxFlat.new()
		bubble.draw_center = false
		bubble.set_corner_radius_all(BUBBLE_RADIUS_PX)
		bubble.set_border_width_all(FRAME_PX)
		bubble.border_color = Color(_ui.color("text_light"), float(_ui.fx("shield_bubble_alpha", 0.55)))
		draw_style_box(bubble, Rect2(-Vector2.ONE * BUBBLE_INSET_PX, size + Vector2.ONE * BUBBLE_INSET_PX * 2.0))
	if _armed:
		var rim := StyleBoxFlat.new()
		rim.draw_center = false
		rim.set_corner_radius_all(CORNER_PX)
		rim.set_border_width_all(int(_ui.fx("rim_glow_px", 3)))
		rim.border_color = Color(_ui.color("state_actionable"), 0.6)
		draw_style_box(rim, Rect2(Vector2.ONE * 2.0, size - Vector2.ONE * 4.0))
	var outline: Variant = null
	var width: int = int(_ui.config.targeting.outline_px)
	if _flash:
		outline = _ui.color("state_danger")
	elif _target:
		outline = _ui.color("state_target")
		if _ring:
			width = int(_ui.config.targeting.ring_px)
	elif bool(_shown.get(FLAG_FROZEN, false)) or silenced:
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
	if morph > 0.0:
		var flash: float = sin(morph * PI) * float(_ui.fx("morph_flash", 0.85))
		draw_rect(Rect2(Vector2.ZERO, size), Color(_ui.color("text_light"), flash))
	if _attack_badge > 0:
		_draw_attack_badge()


func _draw_attack_badge() -> void:
	var cfg: Dictionary = _ui.config.targeting
	var side: float = float(cfg.badge_px)
	var pill := Rect2(Vector2((size.x - side) / 2.0, -side - float(cfg.badge_gap_px)), Vector2(side, side))
	draw_rect(pill, _ui.color("ink"))
	var font: Font = get_theme_default_font()
	var baseline: Vector2 = pill.position + Vector2(0, (side + font.get_ascent(BADGE_FONT_PX) - font.get_descent(BADGE_FONT_PX)) / 2.0)
	draw_string(font, baseline, str(_attack_badge), HORIZONTAL_ALIGNMENT_CENTER, side, BADGE_FONT_PX, _ui.color("text_light"))


# A state glyph beside a numeral, on a small ink square; its letter-free shape is the
# colour's backup. Missing art draws a sign instead.
func _draw_mark(glyph_name: String, at: Vector2, token: String) -> void:
	var side: float = float(_ui.fx("stat_glyph_px", 10))
	var box := Rect2(at, Vector2.ONE * side)
	draw_rect(box.grow(1.0), _ui.color("ink"))
	var tex: Texture2D = _ui.art().glyph_texture(glyph_name)
	if tex != null:
		draw_texture_rect(tex, box, false, _ui.color(token))
	else:
		var font: Font = get_theme_default_font()
		draw_string(font, at + Vector2(0, side), "−" if glyph_name == "damaged" else "+", HORIZONTAL_ALIGNMENT_CENTER, side, int(side), _ui.color(token))


func _refresh_badges() -> void:
	if _ui == null or _shown.is_empty():
		return
	_badge_row = _ui.badges(state_names(_shown, _face), true)
	_badges.text = BadgeRow.letters(_badge_row)
	queue_redraw()


func _keywords() -> Array:
	return _shown.get("keywords", [])


func _attack_buffed() -> bool:
	var printed: Variant = _face.get("attack")
	return printed != null and int(_shown.get("attack", 0)) > int(printed)


func _health_buffed() -> bool:
	var printed: Variant = _face.get("health")
	return printed != null and int(_shown.get("max_health", 0)) > int(printed)


func _damaged() -> bool:
	return int(_shown.get("health", 0)) < int(_shown.get("max_health", 0))


func _pulse_numerals() -> void:
	var peak: float = float(_ui.fx("stat_pulse_scale", 1.4)) if _ui != null else 1.4
	var scale_now: float = lerpf(1.0, peak, sin(stat_pulse * PI))
	for label: Label in [_attack, _health]:
		if label != null:
			label.scale = Vector2.ONE * scale_now


func _draw_stat_glyph(glyph_name: String, centre: Vector2) -> void:
	var tex: Texture2D = _ui.art().glyph_texture(glyph_name)
	if tex == null:
		return
	var side: float = STAMP_RADIUS * 1.5
	var at: Vector2 = centre - Vector2.ONE * side / 2.0
	draw_texture_rect(tex, Rect2(at, Vector2.ONE * side), false, Color(_ui.color("text_light"), CardFrame.GLYPH_ALPHA))


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
	UiFonts.apply(label, UiFonts.WEIGHT_BOLD)
	return label


func _centre(label: Label) -> void:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
