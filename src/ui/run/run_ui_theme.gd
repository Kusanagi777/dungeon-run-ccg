## The Run UI `Theme` (art bible §4; ADR-0011 "three discrete theme-override sets"):
## type variations for text roles and surfaces, built once per `text_scale` and
## `high_contrast_states` value. Applied to the screen stack and toast layer only, so
## it never reaches the swapped-in `MatchView`.
## [codeblock]
## screen_stack.theme = RunUiTheme.build(cfg, 1.25, false)
## label.theme_type_variation = RunUiTheme.LABEL_TITLE
## [/codeblock]
class_name RunUiTheme
extends RefCounted

const LABEL_HERO: StringName = &"LabelHero"
const LABEL_TITLE: StringName = &"LabelTitle"
const LABEL_HEADING: StringName = &"LabelHeading"
const LABEL_SMALL: StringName = &"LabelSmall"
const LABEL_MUTED: StringName = &"LabelMuted"
const LABEL_INK: StringName = &"LabelInk"
const LABEL_DANGER: StringName = &"LabelDanger"
const BUTTON_PRIMARY: StringName = &"ButtonPrimary"
const PANEL_DARK: StringName = &"PanelDark"
const PANEL_LIT: StringName = &"PanelLit"
const PANEL_PARCHMENT: StringName = &"PanelParchment"
const PANEL_INK: StringName = &"PanelInk"
const PANEL_NEUTRAL: StringName = &"PanelNeutral"
## `font_px` key per label variation, and the colour token it reads.
const LABEL_ROLES: Dictionary = {
	LABEL_HERO: ["hero", "text_light"],
	LABEL_TITLE: ["title", "text_light"],
	LABEL_HEADING: ["heading", "text_light"],
	LABEL_SMALL: ["small", "text_light"],
	LABEL_MUTED: ["muted", "text_muted"],
	LABEL_INK: ["small", "text_ink"],
	LABEL_DANGER: ["small", "state_danger"],
}
const PANEL_ROLES: Dictionary = {
	PANEL_DARK: "table_dark",
	PANEL_LIT: "table_lit",
	PANEL_PARCHMENT: "parchment",
	PANEL_INK: "ink",
	PANEL_NEUTRAL: "neutral",
}
const PANEL_PADDING_PX: int = 8
const CORNER_PX: int = 4
const BORDER_PX: int = 2
const HOVER_LIGHTEN: float = 0.12
const PRESS_DARKEN: float = 0.2
const DISABLED_DARKEN: float = 0.3


## The theme for [param text_scale]: every font size is `font_px × scale`, rounded.
static func build(cfg: Dictionary, text_scale: float, high_contrast: bool) -> Theme:
	var theme: Theme = Theme.new()
	var sizes: Dictionary = cfg.font_px
	var body_px: int = roundi(float(sizes.body) * text_scale)
	var light: Color = RunUiConfig.color(cfg, "text_light", high_contrast)
	theme.default_font_size = body_px
	theme.set_color(&"font_color", &"Label", light)
	theme.set_font_size(&"font_size", &"Label", body_px)
	for role: StringName in LABEL_ROLES:
		var row: Array = LABEL_ROLES[role]
		theme.set_type_variation(role, &"Label")
		theme.set_font_size(&"font_size", role, roundi(float(sizes[row[0]]) * text_scale))
		theme.set_color(&"font_color", role, RunUiConfig.color(cfg, str(row[1]), high_contrast))
	for role: StringName in PANEL_ROLES:
		theme.set_type_variation(role, &"PanelContainer")
		theme.set_stylebox(&"panel", role, _box(RunUiConfig.color(cfg, str(PANEL_ROLES[role])), Color.TRANSPARENT))
	_add_button(theme, cfg, &"Button", "table_dark", "neutral", body_px, high_contrast)
	theme.set_type_variation(BUTTON_PRIMARY, &"Button")
	_add_button(theme, cfg, BUTTON_PRIMARY, "table_lit", "state_actionable", body_px, high_contrast)
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	for type: StringName in [&"Button", BUTTON_PRIMARY, &"LineEdit", &"HSlider", &"CheckBox"]:
		theme.set_stylebox(&"focus", type, empty)
	theme.set_color(&"font_color", &"LineEdit", light)
	theme.set_color(&"font_color", &"CheckBox", light)
	theme.set_font_size(&"font_size", &"LineEdit", body_px)
	theme.set_font_size(&"font_size", &"CheckBox", body_px)
	theme.set_stylebox(&"normal", &"LineEdit", _box(RunUiConfig.color(cfg, "ink"), RunUiConfig.color(cfg, "neutral")))
	return theme


static func _add_button(theme: Theme, cfg: Dictionary, type: StringName, fill: String, border: String, font_px: int, high_contrast: bool) -> void:
	var fill_color: Color = RunUiConfig.color(cfg, fill)
	var border_color: Color = RunUiConfig.color(cfg, border, high_contrast)
	var light: Color = RunUiConfig.color(cfg, "text_light", high_contrast)
	theme.set_font_size(&"font_size", type, font_px)
	theme.set_stylebox(&"normal", type, _box(fill_color, border_color))
	theme.set_stylebox(&"hover", type, _box(fill_color.lightened(HOVER_LIGHTEN), border_color))
	theme.set_stylebox(&"pressed", type, _box(fill_color.darkened(PRESS_DARKEN), border_color))
	theme.set_stylebox(&"disabled", type, _box(fill_color.darkened(DISABLED_DARKEN), Color.TRANSPARENT))
	for state: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color", &"font_hover_pressed_color"]:
		theme.set_color(state, type, light)
	theme.set_color(&"font_disabled_color", type, RunUiConfig.color(cfg, "text_muted", high_contrast))


static func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(BORDER_PX if border.a > 0.0 else 0)
	box.set_corner_radius_all(CORNER_PX)
	box.set_content_margin_all(PANEL_PADDING_PX)
	return box
