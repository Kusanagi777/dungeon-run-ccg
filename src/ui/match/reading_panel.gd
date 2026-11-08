## Card Inspect's reading panel (hand.md §5.1; hud.md §10.2): above 100 % text the card
## and the token keep their fixed slots, so the words go here, beside the preview and
## toward the screen centre, at the body size times `text_scale`. It takes no clicks.
## [codeblock]
## panel.configure(ui)
## panel.set_scale_factor(1.5)
## panel.show_face(ui.card_face("war_iron_axe"), preview_rect)
## [/codeblock]
class_name ReadingPanel
extends PanelContainer

const CORNER_PX: int = 4
const PADDING_PX: int = 8
const Z_INDEX: int = 280
const ROW_GAP_PX: float = 4.0

var _ui: MatchUiContext = null
var _cfg: Dictionary = {}
var _scale: float = 1.0
var _name: Label = null
var _rules: Label = null
var _keywords: Label = null
var _left: float = 0.0


## Builds the panel, hidden.
func configure(context: MatchUiContext) -> void:
	_ui = context
	_cfg = context.config.text_scale.reading
	top_level = true
	visible = false
	z_index = Z_INDEX
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBox = context.art().parchment_panel(PADDING_PX)
	if style == null:
		var flat := StyleBoxFlat.new()
		flat.bg_color = context.color("parchment")
		flat.set_corner_radius_all(CORNER_PX)
		flat.set_content_margin_all(PADDING_PX)
		style = flat
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	var band := PanelContainer.new()
	var band_style := StyleBoxFlat.new()
	band_style.bg_color = context.color("ink")
	band_style.set_content_margin_all(PADDING_PX / 2.0)
	band.add_theme_stylebox_override("panel", band_style)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(band)
	_name = _line("text_light")
	band.add_child(_name)
	_keywords = _line("text_ink")
	column.add_child(_keywords)
	_rules = _line("text_ink")
	column.add_child(_rules)


## The active step of `text_scale`: the panel shows only from `text_scale.reading.from`.
func set_scale_factor(scale: float) -> void:
	_scale = scale
	var font_px: int = roundi(float(_cfg.font_px) * scale)
	for label: Label in [_name, _keywords, _rules]:
		label.add_theme_font_size_override(&"font_size", font_px)
	if scale < float(_cfg.from):
		hide_now()


## Shows [param face] (`MatchUiContext.card_face`) beside [param preview], or nothing
## below `text_scale.reading.from`.
func show_face(face: Dictionary, preview: Rect2) -> void:
	if _scale < float(_cfg.from) or face.is_empty():
		hide_now()
		return
	_name.text = tr(str(face.get("name_key", "")))
	_rules.text = CardFrame.rules_text(face)
	var glyphs: PackedStringArray = []
	for keyword: Variant in face.get("keywords", []):
		glyphs.append(_ui.glyph(str(keyword)))
	_keywords.text = " ".join(glyphs)
	var taxonomy: String = CardFrame.taxonomy_text(face)
	if not taxonomy.is_empty():
		_keywords.text = taxonomy + ("  " + _keywords.text if not glyphs.is_empty() else "")
	_keywords.visible = not _keywords.text.is_empty()
	_rules.visible = _rules.text != ""
	if not _rules.visible and not _keywords.visible:
		hide_now()
		return
	var width: float = float(_cfg.w)
	for label: Label in [_name, _keywords, _rules]:
		label.custom_minimum_size.x = width - PADDING_PX * 3.0
	custom_minimum_size = Vector2(width, 0)
	visible = true
	var gap: float = float(_cfg.gap)
	_left = minf(preview.end.x + gap, float(_cfg.right_max_x))
	if preview.get_center().x >= _ui.rect("viewport").get_center().x:
		_left = maxf(preview.position.x - gap - width, float(_cfg.left_min_x))
	_fit()
	# A wrapped label's minimum is stale until the container has sorted.
	_fit.call_deferred()


## Hides the panel.
func hide_now() -> void:
	visible = false


# The height of the words themselves, so the panel's bottom edge holds at `bottom_y`.
func _fit() -> void:
	var height: float = PADDING_PX * 3.0
	for label: Label in [_name, _keywords, _rules]:
		if label.visible:
			var font_px: int = label.get_theme_font_size(&"font_size")
			height += label.get_theme_font(&"font").get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, label.custom_minimum_size.x, font_px).y + ROW_GAP_PX
	height = minf(height, float(_cfg.max_h))
	size = Vector2(float(_cfg.w), height)
	position = Vector2(_left, float(_cfg.bottom_y) - height)


func _line(token: String) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override(&"font_color", _ui.color(token))
	return label
