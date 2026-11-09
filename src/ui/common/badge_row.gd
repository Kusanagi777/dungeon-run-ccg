## The one keyword / state badge row every surface draws (art bible §4 keyword icon
## row; runtime-art "keyword icons are 12 px on an ink pill"): the board token, the
## card face and anything else that shows badges call [method draw], so a keyword
## looks the same wherever it appears. Each badge is its icon when the glyph
## exists, else its letter, chosen per badge: one missing icon never turns the
## whole row into letters. Icons shrink to fit the width, never below `icon_min_px`.
## [codeblock]
## var row: Array[Dictionary] = ui.badges(["taunt", "frozen"], true)
## BadgeRow.draw(self, row, Rect2(5, 78, 80, 14), BadgeRow.ALIGN_CENTER, ui)
## [/codeblock]
class_name BadgeRow
extends RefCounted

const ALIGN_CENTER: int = 0
const ALIGN_RIGHT: int = 1
const GAP_PX: float = 1.0
const PILL_PAD: Vector2 = Vector2(2.0, 1.0)
const LETTER_FONT_RATIO: float = 0.8
## A letter badge is wider than an icon: its text plus this padding.
const LETTER_PAD_PX: float = 2.0


## Draws [param badges] (`MatchUiContext.badges`) on [param canvas] inside
## [param area], on one `ink` pill. [param pops] maps a badge name to a scale (> 1
## while it is popping in); [param dim] multiplies every colour (a dimmed card).
static func draw(canvas: CanvasItem, badges: Array[Dictionary], area: Rect2, align: int, ui: MatchUiContext,
		pops: Dictionary = {}, dim: Color = Color.WHITE) -> void:
	if badges.is_empty():
		return
	var font: Font = canvas.get_theme_default_font()
	var side: float = minf(float(ui.fx("icon_px", 12)), area.size.y)
	var widths: Array[float] = []
	var total: float = 0.0
	for attempt: int in 2:
		widths.clear()
		total = 0.0
		for badge: Dictionary in badges:
			var w: float = side if badge.texture != null else font.get_string_size(str(badge.letter), HORIZONTAL_ALIGNMENT_LEFT, -1, int(side * LETTER_FONT_RATIO)).x + LETTER_PAD_PX
			widths.append(w)
			total += w
		total += GAP_PX * float(badges.size() - 1)
		if total <= area.size.x - PILL_PAD.x * 2.0:
			break
		side = maxf(float(ui.fx("icon_min_px", 8)), side * (area.size.x - PILL_PAD.x * 2.0) / total)
	var x: float = area.end.x - total - PILL_PAD.x if align == ALIGN_RIGHT else area.get_center().x - total / 2.0
	var y: float = area.end.y - side - PILL_PAD.y
	var ink: Color = ui.color("ink") * dim
	var light: Color = ui.color("text_light") * dim
	canvas.draw_rect(Rect2(Vector2(x, y) - PILL_PAD, Vector2(total, side) + PILL_PAD * 2.0), ink)
	for i: int in badges.size():
		var badge: Dictionary = badges[i]
		var scale: float = float(pops.get(badge.name, 1.0))
		var slot := Rect2(Vector2(x, y), Vector2(widths[i], side))
		if scale != 1.0:
			slot = Rect2(slot.get_center() - slot.size * scale / 2.0, slot.size * scale)
		var tint: Color = light if scale == 1.0 else ui.badge_flash(str(badge.name)) * dim
		if badge.texture != null:
			canvas.draw_texture_rect(badge.texture, slot, false, tint)
		else:
			var px: int = int(slot.size.y * LETTER_FONT_RATIO)
			var baseline: Vector2 = Vector2(slot.position.x, slot.position.y + (slot.size.y + font.get_ascent(px) - font.get_descent(px)) / 2.0)
			canvas.draw_string(font, baseline, str(badge.letter), HORIZONTAL_ALIGNMENT_CENTER, slot.size.x, px, tint)
		x += widths[i] + GAP_PX


## The letters of [param badges], joined: the row's text form (the accessible
## readout and what the tests read).
static func letters(badges: Array[Dictionary]) -> String:
	var parts: PackedStringArray = []
	for badge: Dictionary in badges:
		parts.append(str(badge.letter))
	return " ".join(parts)
