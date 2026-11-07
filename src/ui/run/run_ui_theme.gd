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
const LABEL_INK_HEADING: StringName = &"LabelInkHeading"
const LABEL_INK_BODY: StringName = &"LabelInkBody"
const LABEL_INK_MUTED: StringName = &"LabelInkMuted"
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
	LABEL_INK_HEADING: ["heading", "text_ink"],
	LABEL_INK_BODY: ["body", "text_ink"],
	LABEL_INK_MUTED: ["muted", "text_ink"],
}
## Label roles set in the display face; the rest stay in the plain sans.
const DISPLAY_LABELS: Array[StringName] = [LABEL_HERO, LABEL_TITLE, LABEL_HEADING, LABEL_INK_HEADING]
const PANEL_ROLES: Dictionary = {
	PANEL_DARK: "table_dark",
	PANEL_LIT: "table_lit",
	PANEL_PARCHMENT: "parchment",
	PANEL_INK: "ink",
	PANEL_NEUTRAL: "neutral",
}
const PANEL_PADDING_PX: int = 8
const CORNER_PX: int = 4
const BORDER_PX: int = 1
## A sheet's inset: the torn parchment edge eats the first few pixels.
const PARCHMENT_PADDING_PX: int = 16
const HOVER_LIGHTEN: float = 0.08
const PRESS_DARKEN: float = 0.2
## Hairlines and buttons let a little of the table through. Panels never do: they sit over text.
const HAIRLINE_ALPHA: float = 0.55
const SURFACE_ALPHA: float = 0.9
const DISABLED_ALPHA: float = 0.5
## Ink on parchment at this alpha is still above 6:1, the art bible's `text_ink_muted`.
const INK_MUTED_ALPHA: float = 0.74
## A primary button is a slip of parchment: slightly shaded at rest, full when hovered.
const SLIP_REST: Color = Color(0.92, 0.92, 0.92)
const SLIP_PRESSED: Color = Color(0.78, 0.78, 0.78)
const SCROLL_PX: int = 2
## The display face runs small for its size: buttons take it up a step.
const BUTTON_FONT_BUMP_PX: int = 2


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
	theme.set_color(&"font_color", LABEL_INK_MUTED, Color(RunUiConfig.color(cfg, "text_ink"), INK_MUTED_ALPHA))
	var display: Font = UiFonts.serif()
	if display != null:
		for role: StringName in DISPLAY_LABELS:
			theme.set_font(&"font", role, display)
		for type: StringName in [&"Button", BUTTON_PRIMARY]:
			theme.set_font(&"font", type, display)
	var hairline: Color = Color(RunUiConfig.color(cfg, "neutral"), HAIRLINE_ALPHA)
	for role: StringName in PANEL_ROLES:
		theme.set_type_variation(role, &"PanelContainer")
		var panel: StyleBox = _box(RunUiConfig.color(cfg, str(PANEL_ROLES[role])), hairline)
		if role == PANEL_PARCHMENT:
			var parchment: StyleBox = ArtLibrary.shared().parchment_panel(PARCHMENT_PADDING_PX)
			if parchment != null:
				panel = parchment
		theme.set_stylebox(&"panel", role, panel)
	_add_button(theme, cfg, high_contrast)
	theme.set_type_variation(BUTTON_PRIMARY, &"Button")
	_add_primary(theme, cfg, high_contrast)
	for type: StringName in [&"Button", BUTTON_PRIMARY]:
		theme.set_font_size(&"font_size", type, body_px + BUTTON_FONT_BUMP_PX)
	_add_scrollbar(theme, hairline)
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	for type: StringName in [&"Button", BUTTON_PRIMARY, &"LineEdit", &"HSlider", &"CheckBox"]:
		theme.set_stylebox(&"focus", type, empty)
	theme.set_color(&"font_color", &"LineEdit", light)
	theme.set_color(&"font_color", &"CheckBox", light)
	theme.set_font_size(&"font_size", &"LineEdit", body_px)
	theme.set_font_size(&"font_size", &"CheckBox", body_px)
	theme.set_color(&"font_placeholder_color", &"LineEdit", RunUiConfig.color(cfg, "text_muted", high_contrast))
	theme.set_stylebox(&"normal", &"LineEdit", _box(RunUiConfig.color(cfg, "ink"), RunUiConfig.color(cfg, "neutral")))
	return theme


static func _add_button(theme: Theme, cfg: Dictionary, high_contrast: bool) -> void:
	var type: StringName = &"Button"
	var fill: Color = Color(RunUiConfig.color(cfg, "ink"), SURFACE_ALPHA)
	var edge: Color = RunUiConfig.color(cfg, "neutral", high_contrast)
	var light: Color = RunUiConfig.color(cfg, "text_light", high_contrast)
	theme.set_stylebox(&"normal", type, _box(fill, Color(edge, HAIRLINE_ALPHA)))
	theme.set_stylebox(&"hover", type, _box(fill.lightened(HOVER_LIGHTEN), edge))
	theme.set_stylebox(&"pressed", type, _box(fill.darkened(PRESS_DARKEN), light))
	theme.set_stylebox(&"disabled", type, _box(Color(fill, DISABLED_ALPHA), Color.TRANSPARENT))
	_set_font_colors(theme, type, light)
	theme.set_color(&"font_disabled_color", type, RunUiConfig.color(cfg, "text_muted", high_contrast))


## The screen's one bright control. Disabled it is a dark blank, so a dim Pick does not
## read as the thing to press.
static func _add_primary(theme: Theme, cfg: Dictionary, high_contrast: bool) -> void:
	var paper: Color = RunUiConfig.color(cfg, "parchment")
	var states: Dictionary = {&"normal": SLIP_REST, &"hover": Color.WHITE, &"pressed": SLIP_PRESSED}
	for state: StringName in states:
		var slip: StyleBox = ArtLibrary.shared().parchment_panel(PANEL_PADDING_PX)
		if slip != null:
			(slip as StyleBoxTexture).modulate_color = states[state]
		else:
			slip = _box(paper * (states[state] as Color), Color.TRANSPARENT)
		theme.set_stylebox(state, BUTTON_PRIMARY, slip)
	theme.set_stylebox(&"disabled", BUTTON_PRIMARY, _box(Color(RunUiConfig.color(cfg, "ink"), DISABLED_ALPHA), Color.TRANSPARENT))
	_set_font_colors(theme, BUTTON_PRIMARY, RunUiConfig.color(cfg, "text_ink"))
	theme.set_color(&"font_disabled_color", BUTTON_PRIMARY, RunUiConfig.color(cfg, "text_muted", high_contrast))


static func _set_font_colors(theme: Theme, type: StringName, ink: Color) -> void:
	for state: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color", &"font_hover_pressed_color"]:
		theme.set_color(state, type, ink)


static func _add_scrollbar(theme: Theme, grabber: Color) -> void:
	var track: StyleBoxEmpty = StyleBoxEmpty.new()
	track.set_content_margin_all(SCROLL_PX)
	theme.set_stylebox(&"scroll", &"VScrollBar", track)
	for state: StringName in [&"grabber", &"grabber_highlight", &"grabber_pressed"]:
		var thumb: StyleBoxFlat = StyleBoxFlat.new()
		thumb.bg_color = Color(grabber, 1.0)
		thumb.set_corner_radius_all(SCROLL_PX)
		thumb.set_content_margin_all(SCROLL_PX)
		theme.set_stylebox(state, &"VScrollBar", thumb)


static func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(BORDER_PX if border.a > 0.0 else 0)
	box.set_corner_radius_all(CORNER_PX)
	box.set_content_margin_all(PANEL_PADDING_PX)
	return box
