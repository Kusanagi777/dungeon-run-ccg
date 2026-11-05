## The floor progress strip (run-ui U6, F4; interaction-patterns Progress Strip): the F
## nodes, gem marks, held treasures at the left and the deck size at the right. Its row
## is y 48-96. A node is a 44x48 focus stop drawing the 24 px node in its middle; a
## focused or hovered node names itself in the tip line. Upcoming nodes show their band
## colour only, which is all the read model gives them.
## [codeblock]
## var strip := ProgressStrip.new()
## parent.add_child(strip)
## strip.show_strip(cfg, model.strip)
## var stops: Array[Control] = strip.focus_stops()
## [/codeblock]
class_name ProgressStrip
extends Control

const ROW_Y: float = 48.0
const ROW_H: float = 48.0
const NODE_HIT_W: float = 44.0
const CHIP_X: float = 40.0
const CHIP_PX: float = 44.0
const CHIP_GAP: float = 8.0
const DECK_RECT: Rect2 = Rect2(1080, 0, 160, 48)
const TIP_RECT: Rect2 = Rect2(0, 48, 1280, 20)
const CONNECTOR_PX: float = 2.0


## One floor node, drawn by state.
class StripNode:
	extends Control

	var data: Dictionary = {}
	var cfg: Dictionary = {}
	var show_initial: bool = true

	func _draw() -> void:
		var centre: Vector2 = size / 2.0
		var radius: float = float(cfg.node_d) / 2.0
		var band: Color = RunUiConfig.color(cfg, str(data.band_color))
		var light: Color = RunUiConfig.color(cfg, "text_light")
		var font: Font = get_theme_default_font()
		var font_px: int = int(cfg.font_px.small)
		match str(data.state):
			RunState.PIP_CLEARED:
				draw_circle(centre, radius, light)
				_draw_initial(font, font_px, RunUiConfig.color(cfg, "text_ink"), centre)
			RunState.PIP_CURRENT:
				draw_arc(centre, radius, 0.0, TAU, 32, band, 3.0)
				_draw_initial(font, font_px, light, centre)
			_:
				draw_arc(centre, radius, 0.0, TAU, 32, band, 2.0)
		if bool(data.get("gem", false)):
			draw_string(font, Vector2(centre.x - radius / 2.0, size.y), tr("strip.gem"), HORIZONTAL_ALIGNMENT_LEFT, -1, font_px, light)

	func _draw_initial(font: Font, font_px: int, ink: Color, centre: Vector2) -> void:
		if show_initial:
			var text: String = str(data.initial)
			var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px).x
			draw_string(font, centre + Vector2(-width / 2.0, font_px / 2.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px, ink)


var _stops: Array[Control] = []
var _tip: Label = null
var _segments: Array[Rect2] = []
var _segment_color: Color = Color.WHITE


## Lays out the strip from [param model] (`RunReadModels.strip`) on F4's geometry.
func show_strip(cfg: Dictionary, model: Dictionary) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_stops.clear()
	_segments.clear()
	_segment_color = RunUiConfig.color(cfg, "neutral")
	UiKit.place(self, Rect2(0, ROW_Y, float(cfg.design_width), ROW_H))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nodes: Array = model.get("nodes", [])
	var layout: Dictionary = RunUiConfig.strip_layout(cfg, nodes.size())
	for i: int in nodes.size():
		var row: Dictionary = nodes[i]
		var centre_x: float = float(RunUiConfig.node_cx(layout, int(row.floor)))
		var node: StripNode = StripNode.new()
		node.data = row
		node.cfg = cfg
		node.show_initial = bool(layout.initials)
		node.focus_mode = Control.FOCUS_ALL
		node.tooltip_text = str(row.tip)
		add_child(node)
		UiKit.place(node, Rect2(centre_x - NODE_HIT_W / 2.0, 0, NODE_HIT_W, ROW_H))
		node.focus_entered.connect(_show_tip.bind(str(row.tip)))
		node.focus_exited.connect(_show_tip.bind(""))
		_stops.append(node)
		if i > 0:
			var left: float = centre_x - float(layout.node_d) / 2.0 - float(layout.seg_len)
			_segments.append(Rect2(left, ROW_H / 2.0 - CONNECTOR_PX / 2.0, float(layout.seg_len), CONNECTOR_PX))
	var x: float = CHIP_X
	for treasure: Dictionary in model.get("treasures", []):
		var chip: Button = Button.new()
		chip.text = str(treasure.initial)
		chip.tooltip_text = "%s\n%s" % [treasure.name, treasure.text]
		add_child(chip)
		UiKit.place(chip, Rect2(x, (ROW_H - CHIP_PX) / 2.0, CHIP_PX, CHIP_PX))
		chip.focus_entered.connect(_show_tip.bind("%s: %s" % [treasure.name, treasure.text]))
		chip.focus_exited.connect(_show_tip.bind(""))
		_stops.append(chip)
		x += CHIP_PX + CHIP_GAP
	var deck: Label = UiKit.label(tr("strip.deck").format({"n": int(model.get("deck_size", 0))}))
	deck.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	deck.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(deck)
	UiKit.place(deck, DECK_RECT)
	_tip = UiKit.label("", RunUiTheme.LABEL_SMALL)
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_tip)
	UiKit.place(_tip, TIP_RECT)
	queue_redraw()


## Every focus stop, nodes then treasure chips, for the screen's Focus Order.
func focus_stops() -> Array[Control]:
	return _stops


func _show_tip(text: String) -> void:
	_tip.text = text


func _draw() -> void:
	for segment: Rect2 in _segments:
		draw_rect(segment, _segment_color)
