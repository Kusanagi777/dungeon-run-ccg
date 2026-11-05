## The summary's compact per-floor strip (run-ui U9; run-summary.md §12 stop 8): one
## 24 px cell per floor at a 44 px pitch, read-only. It is one focus stop: `Left` /
## `Right` walk the cells and `Enter` does nothing. A cleared cell shows the boss initial
## on its band colour, the killing cell a `state_danger` ring (never a fill), later
## floors stay hollow, a retried floor carries "×n".
## [codeblock]
## var strip := FloorStrip.new()
## strip.show_cells(cfg, model.cells)
## [/codeblock]
class_name FloorStrip
extends Control

const PITCH_PX: float = 44.0
const ROW_H_PX: float = 44.0
const MARK_H_PX: float = 18.0
const RING_PX: float = 2.0

var _cfg: Dictionary = {}
var _cells: Array = []
var _index: int = 0
var _tip: Label = null


## Shows [param cells] (`RunReadModels.floor_cells`).
func show_cells(cfg: Dictionary, cells: Array) -> void:
	_cfg = cfg
	_cells = cells
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(cells.size() * PITCH_PX, ROW_H_PX + MARK_H_PX * 2.0)
	if _tip == null:
		_tip = UiKit.label("", RunUiTheme.LABEL_SMALL)
		add_child(_tip)
		UiKit.place(_tip, Rect2(0, ROW_H_PX + MARK_H_PX, cells.size() * PITCH_PX, MARK_H_PX))
	focus_entered.connect(_select.bind(0))
	focus_exited.connect(func() -> void: _tip.text = "")
	mouse_exited.connect(func() -> void: tooltip_text = "")
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hovered: int = int(event.position.x / PITCH_PX)
		if hovered >= 0 and hovered < _cells.size():
			tooltip_text = str(_cells[hovered].tip)
	elif event.is_action_pressed(&"ui_right") and _index < _cells.size() - 1:
		_select(_index + 1)
		accept_event()
	elif event.is_action_pressed(&"ui_left") and _index > 0:
		_select(_index - 1)
		accept_event()


func _select(index: int) -> void:
	_index = index
	if index < _cells.size():
		_tip.text = str(_cells[index].tip)
	queue_redraw()


func _draw() -> void:
	var font: Font = get_theme_default_font()
	var font_px: int = int(_cfg.get("font_px", {}).get("small", 13))
	var radius: float = float(_cfg.get("node_d", 24)) / 2.0
	for i: int in _cells.size():
		var cell: Dictionary = _cells[i]
		var centre: Vector2 = Vector2(PITCH_PX * (i + 0.5), ROW_H_PX / 2.0)
		var light: Color = RunUiConfig.color(_cfg, "text_light")
		match str(cell.state):
			RunReadModels.CELL_CLEARED:
				draw_circle(centre, radius, RunUiConfig.color(_cfg, str(cell.band_color)))
			RunReadModels.CELL_KILLED:
				draw_arc(centre, radius, 0.0, TAU, 32, RunUiConfig.color(_cfg, "state_danger"), RING_PX)
			_:
				draw_arc(centre, radius, 0.0, TAU, 32, RunUiConfig.color(_cfg, "neutral"), RING_PX)
		var initial: String = str(cell.initial)
		if not initial.is_empty():
			var width: float = font.get_string_size(initial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px).x
			draw_string(font, centre + Vector2(-width / 2.0, font_px / 2.5), initial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px, light)
		if int(cell.attempt) > 1:
			var mark: String = tr("summary.cell.mark").format({"n": int(cell.attempt)})
			draw_string(font, Vector2(PITCH_PX * i + 4.0, ROW_H_PX + MARK_H_PX - 4.0), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px, light)
