## One card face, shared with Run UI (ADR-0009; ADR-0011): the 150x210 slot layout of
## art bible §4, drawn flat with placeholder fills (art bible §7). Text is `tr()` keys.
## Everything is opaque: the not-playable dim is a value mix toward the hand fill
## (hand.md §5.3), never alpha, so a neighbour in a crowded fan never shows through.
## [codeblock]
## var frame: CardFrame = CARD_FRAME_SCENE.instantiate()
## parent.add_child(frame)
## frame.configure(ui)
## frame.show_card(ui.card_face("war_sharpen"), 1)
## frame.set_state(true, false, false)
## [/codeblock]
class_name CardFrame
extends Control

const SIZE: Vector2 = Vector2(150, 210)
const COST_CENTRE: Vector2 = Vector2(20, 20)
const ATTACK_CENTRE: Vector2 = Vector2(20, 190)
const HEALTH_CENTRE: Vector2 = Vector2(130, 190)
const STAMP_RADIUS: float = 17.0
const STAMP_RING_PX: float = 2.0
const NAME_RECT: Rect2 = Rect2(6, 40, 138, 22)
const ART_RECT: Rect2 = Rect2(8, 64, 134, 54)
const TEXT_RECT: Rect2 = Rect2(8, 122, 134, 58)
const SPELL_TEXT_RECT: Rect2 = Rect2(8, 122, 134, 78)
const NAME_FONT_PX: int = 14
const STAMP_FONT_PX: int = 20
const ART_FONT_PX: int = 24
const RULES_FONT_PX: int = 12
const BADGE_FONT_PX: int = 12
const BORDER_PX: int = 2
const CORNER_PX: int = 8
const NAME_PADDING_PX: float = 6.0
const TEXT_PADDING_PX: float = 6.0
const DIM_MIX: float = 0.4
const TYPE_INITIALS: Dictionary = {"minion": "M", "spell": "S", "weapon": "W"}
const TYPE_MINION: String = "minion"
const TYPE_WEAPON: String = "weapon"
const DASH_COUNT: int = 12

var _ui: MatchUiContext = null
var _face: Dictionary = {}
var _cost: int = 0
var _lit: bool = false
var _dimmed: bool = false
var _unaffordable: bool = false
var _fill: Color = Color.BLACK
var _name: Label = null
var _rules: Label = null
var _art: Label = null
var _cost_text: Label = null
var _attack_text: Label = null
var _health_text: Label = null
var _badges: Label = null


## Stores the palette source and builds the labels. Call once, in the tree or not.
func configure(context: MatchUiContext) -> void:
	_ui = context
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill = _ui.color("table_lit")
	_name = _label(NAME_RECT.grow_individual(-NAME_PADDING_PX, 0, 0, 0), NAME_FONT_PX)
	_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name.clip_text = true
	_art = _label(ART_RECT, ART_FONT_PX)
	_centre(_art)
	_badges = _label(ART_RECT, BADGE_FONT_PX)
	_badges.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_badges.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_rules = _label(TEXT_RECT.grow(-TEXT_PADDING_PX / 2.0), RULES_FONT_PX)
	_rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rules.clip_text = true
	_cost_text = _stamp_label(COST_CENTRE)
	_attack_text = _stamp_label(ATTACK_CENTRE)
	_health_text = _stamp_label(HEALTH_CENTRE)


## The rules text of [param face]: `""` for a vanilla card, whose text is an empty message
## that `tr` answers with its key.
static func rules_text(face: Dictionary) -> String:
	var key: String = str(face.get("text_key", ""))
	var text: String = TranslationServer.translate(key) if key != "" else ""
	return "" if text == key else text


## Shows [param face] (`MatchUiContext.card_face`) at [param effective_cost], the
## projection's cost (DD-X26): a cost off the printed one gets the modified stamp.
func show_card(face: Dictionary, effective_cost: int) -> void:
	_face = face
	_cost = effective_cost
	_name.text = tr(str(face.get("name_key", "")))
	_rules.text = rules_text(face)
	var type: String = str(face.get("type", ""))
	_art.text = str(TYPE_INITIALS.get(type, ""))
	_cost_text.text = str(effective_cost)
	var has_stats: bool = type == TYPE_MINION or type == TYPE_WEAPON
	_attack_text.visible = has_stats
	_health_text.visible = has_stats
	_rules.position = (TEXT_RECT if has_stats else SPELL_TEXT_RECT).position
	_rules.size = (TEXT_RECT if has_stats else SPELL_TEXT_RECT).size
	if has_stats:
		_attack_text.text = str(int(face.attack)) if face.get("attack") != null else ""
		var durability: Variant = face.get("durability", face.get("health"))
		_health_text.text = str(int(durability)) if durability != null else ""
	var glyphs: PackedStringArray = []
	for keyword: Variant in face.get("keywords", []):
		glyphs.append(_ui.glyph(str(keyword)))
	_badges.text = " ".join(glyphs)
	_refresh_colors()
	queue_redraw()


## [param lit]: the `state_actionable` outline. [param dimmed]: the 60 % value dim.
## [param unaffordable]: the notched cost ring.
func set_state(lit: bool, dimmed: bool, unaffordable: bool) -> void:
	if lit == _lit and dimmed == _dimmed and unaffordable == _unaffordable:
		return
	_lit = lit
	_dimmed = dimmed
	_unaffordable = unaffordable
	_refresh_colors()
	queue_redraw()


## The hand fill the dim mixes toward (`table_lit`, or `table_dark` on the boss's turn).
func set_fill(fill: Color) -> void:
	if fill != _fill:
		_fill = fill
		_refresh_colors()
		queue_redraw()


## True when the cost shown differs from the printed one.
func cost_modified() -> bool:
	return _face.get("cost") != null and _cost != int(_face.cost)


## The printed cost, for the Inspect "Printed cost n" line.
func printed_cost() -> int:
	return int(_face.get("cost", 0))


func _draw() -> void:
	if _face.is_empty():
		return
	var body := StyleBoxFlat.new()
	body.bg_color = _dim(_ui.color("parchment"))
	body.set_corner_radius_all(CORNER_PX)
	body.set_border_width_all(BORDER_PX)
	body.border_color = _dim(_face.get("primary", _ui.color("neutral")))
	draw_style_box(body, Rect2(Vector2.ZERO, SIZE))
	draw_rect(NAME_RECT, _dim(_ui.color("ink")))
	draw_rect(ART_RECT, _face.get("secondary", _ui.color("neutral")))
	if _attack_text.visible:
		_draw_stamp(ATTACK_CENTRE, _dim(_ui.color("ink")), _dim(_ui.color("stamp_ring")))
		_draw_stamp(HEALTH_CENTRE, _dim(_ui.color("ink")), _dim(_ui.color("stamp_ring")))
	var cost_fill: Color = _ui.color("ink") if cost_modified() else _ui.color("mana_stamp")
	_draw_stamp(COST_CENTRE, cost_fill, _ui.color("ink"))
	if _unaffordable:
		_draw_notches()
	if _lit:
		var outline := StyleBoxFlat.new()
		outline.draw_center = false
		outline.set_corner_radius_all(CORNER_PX)
		outline.set_border_width_all(BORDER_PX)
		outline.border_color = _ui.color("state_actionable")
		draw_style_box(outline, Rect2(Vector2.ZERO, SIZE))


func _draw_stamp(centre: Vector2, fill: Color, ring: Color) -> void:
	draw_circle(centre, STAMP_RADIUS, ring)
	draw_circle(centre, STAMP_RADIUS - STAMP_RING_PX, fill)


## hand.md §5.3: the dashed ring's gaps are cut through to the card body.
func _draw_notches() -> void:
	var body: Color = _dim(_ui.color("parchment"))
	for i: int in DASH_COUNT:
		var angle: float = TAU * float(i) / float(DASH_COUNT)
		var edge: Vector2 = COST_CENTRE + Vector2.from_angle(angle) * (STAMP_RADIUS - STAMP_RING_PX / 2.0)
		draw_circle(edge, STAMP_RING_PX, body)


func _dim(color: Color) -> Color:
	return color.lerp(_fill, DIM_MIX) if _dimmed else color


func _refresh_colors() -> void:
	var light: Color = _ui.color("text_light")
	_name.add_theme_color_override("font_color", _dim(light))
	_rules.add_theme_color_override("font_color", _dim(_ui.color("text_ink")))
	_art.add_theme_color_override("font_color", light)
	_badges.add_theme_color_override("font_color", _dim(light))
	_attack_text.add_theme_color_override("font_color", _dim(light))
	_health_text.add_theme_color_override("font_color", _dim(light))
	var cost_color: Color = light
	if cost_modified():
		cost_color = _ui.color("state_buff") if _cost < printed_cost() else _ui.color("state_danger")
	_cost_text.add_theme_color_override("font_color", cost_color)


func _label(rect: Rect2, font_px: int) -> Label:
	var label := Label.new()
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_size_override("font_size", font_px)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _stamp_label(centre: Vector2) -> Label:
	var side: float = STAMP_RADIUS * 2.0
	var label: Label = _label(Rect2(centre - Vector2(STAMP_RADIUS, STAMP_RADIUS), Vector2(side, side)), STAMP_FONT_PX)
	_centre(label)
	return label


func _centre(label: Label) -> void:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
