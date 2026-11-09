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

## The localization key of a badge's name ("Taunt", "Masked", …).
const BADGE_NAME_KEY: String = "badge.%s"
const ICON_PX: float = 16.0
const ICON_GAP_PX: float = 4.0
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
# The badge icons above the keyword names, the same icons the token and card show.
var _icons: HBoxContainer = null
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
	_icons = HBoxContainer.new()
	_icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icons.add_theme_constant_override("separation", int(ICON_GAP_PX))
	column.add_child(_icons)
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
	var names: Array = (face.get("keywords", []) as Array).duplicate()
	if bool(face.get("masked", false)):
		names.append(MinionToken.FLAG_MASKED)
	var badges: Array[Dictionary] = _ui.badges(names, false)
	_show_badges(badges)
	var words: PackedStringArray = []
	for badge: Dictionary in badges:
		words.append(tr(BADGE_NAME_KEY % str(badge.name)))
	_keywords.text = ", ".join(words)
	var taxonomy: String = CardFrame.taxonomy_text(face)
	if not taxonomy.is_empty():
		_keywords.text = taxonomy + ("  " + _keywords.text if not words.is_empty() else "")
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


# One ink square per badge: its icon, or its letter when the icon is missing.
func _show_badges(badges: Array[Dictionary]) -> void:
	for child: Node in _icons.get_children():
		child.queue_free()
	_icons.visible = not badges.is_empty()
	for badge: Dictionary in badges:
		var cell := PanelContainer.new()
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ink := StyleBoxFlat.new()
		ink.bg_color = _ui.color("ink")
		ink.set_content_margin_all(1.0)
		cell.add_theme_stylebox_override("panel", ink)
		if badge.texture != null:
			var icon := TextureRect.new()
			icon.texture = badge.texture
			icon.modulate = _ui.color("text_light")
			icon.custom_minimum_size = Vector2.ONE * ICON_PX * _scale
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(icon)
		else:
			var letter := Label.new()
			letter.text = str(badge.letter)
			letter.add_theme_color_override("font_color", _ui.color("text_light"))
			letter.add_theme_font_size_override("font_size", int(ICON_PX * _scale * 0.8))
			cell.add_child(letter)
		_icons.add_child(cell)
