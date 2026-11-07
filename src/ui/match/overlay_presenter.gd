## The Choice overlay (ADR-0009 `choice_overlay.tscn`; match-ui U9; interaction-patterns
## Pick One of N): three full cards at 1.5x (Discover) or three labelled plates (Choose
## One) in the F6 row, select then Confirm, and no cancel. It draws
## `pending_choice` and stores nothing the view-state does not have but the cursor.
##
## Input is [MatchInput] names, so keys and a gamepad read alike: `1`–`3` select, the
## direction and `Tab` actions move focus, and a confirm selects the focused option, or
## sends it when it is already selected. `Esc` is not taken here: it falls through to the
## chain, which opens the pause menu over the overlay.
##
## A boss Choice shows the "boss discovers…" label on the boss portrait and no options.
## [codeblock]
## overlay.chosen.connect(func(index: int) -> void: router.intent(&"choose", {"index": index}))
## if overlay.is_open() and overlay.handle_action(MatchInput.read(event), MatchInput.hand_slot(event)):
##     return
## [/codeblock]
class_name OverlayPresenter
extends Presenter

## The player confirmed option [param index].
signal chosen(index: int)

const CARD_FRAME_SCENE: PackedScene = preload("res://src/ui/common/card_frame.tscn")
const KIND_DISCOVER: String = "discover"
const NO_OPTION: int = -1

var _view: MatchViewState = null
var _cfg: Dictionary = {}
var _open: bool = false
var _committed: bool = false
var _options: Array[Control] = []
var _rects: Array[Rect2] = []
var _focused: int = 0
var _selected: int = NO_OPTION
var _confirm: Button = null
var _boss_label: Label = null


## Builds the Confirm button and the boss label; the options come with each Choice.
func setup(context: MatchUiContext) -> void:
	super(context)
	_cfg = ui.config.choice
	visible = false
	_confirm = Button.new()
	_confirm.text = tr("choice.confirm")
	_confirm.focus_mode = Control.FOCUS_NONE
	_confirm.size = Vector2(float(_cfg.confirm_w), float(_cfg.confirm_h))
	var row: Rect2 = ui.rect("choice_row")
	_confirm.position = Vector2(row.get_center().x - _confirm.size.x / 2.0, row.end.y + float(_cfg.confirm_gap))
	_confirm.pressed.connect(_send)
	add_child(_confirm)
	var portrait: Rect2 = ui.rect("boss_portrait")
	_boss_label = Label.new()
	_boss_label.text = tr("choice.boss_discovers")
	_boss_label.position = portrait.position
	_boss_label.size = portrait.size
	_boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_boss_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_boss_label.add_theme_color_override("font_color", ui.color("text_light"))
	_boss_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_label.top_level = true
	_boss_label.visible = false
	add_child(_boss_label)


## Stores the projection [method sync_report] compares against.
func bind(view_state: MatchViewState) -> void:
	_view = view_state


func owns(_entity_ids: Array[int]) -> bool:
	return false


## These steps name no entity (U3).
func claims(step: AnimStep) -> bool:
	return step.kind in [AnimStep.OVERLAY_OPEN, AnimStep.OVERLAY_CLOSE, AnimStep.BOSS_DISCOVERS]


func on_step_started(step: AnimStep, d_eff: float) -> void:
	match step.kind:
		AnimStep.OVERLAY_OPEN:
			present(step.data.get("display", {}))
			modulate.a = 0.0
			step_tween(step).tween_property(self, "modulate:a", 1.0, d_eff)
		AnimStep.OVERLAY_CLOSE:
			step_tween(step).tween_property(self, "modulate:a", 0.0, d_eff)
		AnimStep.BOSS_DISCOVERS:
			_boss_label.visible = true


func apply_final(step: AnimStep) -> void:
	end_step(step)
	modulate.a = 1.0
	_boss_label.visible = false


func on_skipped() -> void:
	super()
	modulate.a = 1.0
	_boss_label.visible = false


func present(state: Dictionary) -> void:
	var pending: Variant = state.get("pending_choice")
	var mine: bool = pending != null and str(pending.side) == MatchViewState.SIDE_PLAYER
	if mine and not _open:
		_open_overlay(pending)
	elif not mine and _open:
		_close_overlay()


func sync_report() -> Array[String]:
	var pending: Variant = _view.pending_choice
	var mine: bool = pending != null and str(pending.side) == MatchViewState.SIDE_PLAYER
	if _open != mine:
		return ["choice open: shows %s, view-state %s" % [str(_open), str(mine)]]
	return []


## True while the overlay takes input.
func is_open() -> bool:
	return _open and not _committed


## The focused option; a test reads it.
func focused() -> int:
	return _focused


## The selected option, or -1.
func selected() -> int:
	return _selected


## Takes [param action]; true when it was the overlay's. `Esc` never is: a Choice has no
## cancel (U9).
func handle_action(action: StringName, slot: int) -> bool:
	match action:
		MatchInput.HAND:
			if slot < _options.size():
				_focused = slot
				_select(slot)
			return true
		MatchInput.CONFIRM:
			if _selected == _focused:
				_send()
			else:
				_select(_focused)
			return true
		MatchInput.LEFT, MatchInput.UP, MatchInput.PREVIOUS:
			_move_focus(-1)
			return true
		MatchInput.RIGHT, MatchInput.DOWN, MatchInput.NEXT:
			_move_focus(1)
			return true
	return false


## A refused `choose` (a race) gives the overlay back as it was.
func on_rejected() -> void:
	_committed = false


func _draw() -> void:
	if not _open:
		return
	var cfg: Dictionary = ui.config.targeting
	var width: float = float(cfg.outline_px)
	var color: Color = ui.color("state_actionable")
	if _selected != NO_OPTION:
		draw_rect(_rects[_selected].grow(width / 2.0), ui.color("state_target"), false, width)
	draw_rect(_rects[_focused].grow(float(ui.config.focus.ring_offset_px)), color, false, float(ui.config.focus.ring_px))


func _open_overlay(pending: Dictionary) -> void:
	_open = true
	_committed = false
	_focused = 0
	_selected = NO_OPTION
	visible = true
	var row: Rect2 = ui.rect("choice_row")
	var discover: bool = str(pending.kind) == KIND_DISCOVER
	var options: Array = pending.options
	var scale_by: float = float(_cfg.card_scale)
	var option_size: Vector2 = CardFrame.SIZE * scale_by
	var left: float = row.get_center().x - (options.size() * option_size.x + maxi(options.size() - 1, 0) * float(_cfg.gap)) / 2.0
	for i: int in options.size():
		var rect := Rect2(Vector2(left + i * (option_size.x + float(_cfg.gap)), row.position.y), option_size)
		var option: Control = _card(str(options[i]), rect) if discover else _plate(str(options[i]), rect)
		option.mouse_filter = Control.MOUSE_FILTER_STOP
		option.gui_input.connect(_on_option_input.bind(i))
		_options.append(option)
		_rects.append(rect)
	_refresh()


func _close_overlay() -> void:
	_open = false
	visible = false
	for option: Control in _options:
		option.queue_free()
	_options.clear()
	_rects.clear()
	queue_redraw()


func _card(card_id: String, rect: Rect2) -> Control:
	var frame: CardFrame = CARD_FRAME_SCENE.instantiate()
	add_child(frame)
	frame.configure(ui)
	frame.scale = Vector2.ONE * float(_cfg.card_scale)
	frame.set_text_zoom(float(_cfg.card_scale))
	frame.position = rect.position
	var face: Dictionary = ui.card_face(card_id)
	frame.show_card(face, int(face.get("cost", 0)) if face.get("cost") != null else 0)
	return frame


func _plate(label_key: String, rect: Rect2) -> Control:
	var plate := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = ui.color("parchment")
	style.set_border_width_all(int(ui.config.targeting.outline_px))
	style.border_color = ui.color("ink")
	style.set_corner_radius_all(int(_cfg.plate_corner_px))
	plate.add_theme_stylebox_override("panel", style)
	plate.position = rect.position
	plate.size = rect.size
	add_child(plate)
	var label := Label.new()
	label.text = tr(label_key)
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", int(_cfg.plate_font_px))
	label.add_theme_color_override("font_color", ui.color("text_ink"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(label)
	return plate


func _move_focus(step: int) -> void:
	if not _options.is_empty():
		_focused = posmod(_focused + step, _options.size())
		queue_redraw()


func _select(index: int) -> void:
	_selected = index
	_refresh()


func _refresh() -> void:
	_confirm.disabled = _selected == NO_OPTION
	queue_redraw()


## Sends the selection once; a second press does nothing.
func _send() -> void:
	if not is_open() or _selected == NO_OPTION:
		return
	_committed = true
	chosen.emit(_selected)


func _on_option_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_focused = index
		_select(index)
		if (event as InputEventMouseButton).double_click:
			_send()
