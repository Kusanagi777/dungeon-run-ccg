## The pause menu (ADR-0009 `pause_menu.tscn`; match-ui U9, States `Menu`): Resume,
## Concede behind a confirm, and the settings quick-access. It knows no presenter, so Run
## UI can instance the scene: the caller hands it a style block and the [MetaApi] it
## writes through, and it applies nothing itself. A change goes to `MetaApi.set_setting`
## and comes back on `settings_changed` (ADR-0011).
##
## These are real Controls with real focus, so keyboard and gamepad walk them natively
## (`ui_up`, `ui_down`, `ui_accept`, a slider's `ui_left` / `ui_right`). Only this menu is
## focusable while it is up, which is the focus trap. Playback keeps running underneath.
## [codeblock]
## menu.configure({"rect": rect, "fill": fill, "text": text, "ring": ring, ...}, meta)
## menu.concede_confirmed.connect(_on_concede)
## menu.open()
## menu.back()   # `Esc`: confirm → Cancel, pause → Resume
## [/codeblock]
class_name PauseMenu
extends Control

## The menu closed, by Resume, `Esc` or a confirmed concede.
signal closed()
## The player confirmed concede; the menu has closed.
signal concede_confirmed()

const KEY_MASTER: StringName = &"volume_master"
const KEY_MUSIC: StringName = &"volume_music"
const KEY_SFX: StringName = &"volume_sfx"
const KEY_SPEED: StringName = &"anim_speed"
const KEY_REDUCE_MOTION: StringName = &"reduce_motion"
## `anim_speed` labels, in the selector's order (DD-X07).
const SPEEDS: Array[String] = ["normal", "fast", "instant"]
const VOLUME_STEP: float = 0.05
## Over the hand fan, whose cards draw above the table.
const MENU_Z: int = 320

var _meta: MetaApi = null
var _style: Dictionary = {}
var _panel: Panel = null
var _main: VBoxContainer = null
var _confirm: VBoxContainer = null
var _resume: Button = null
var _concede: Button = null
var _cancel: Button = null
var _sliders: Dictionary = {}
var _speed_buttons: Dictionary = {}
var _reduce: CheckButton = null
var _ring: Control = null
# True while the menu writes its own controls, so a refresh is not read as a change.
var _syncing: bool = false
var _open: bool = false
var _open_s: float = 0.0
var _close_s: float = 0.0
var _scale_from: float = 1.0
var _tween: Tween = null


## Builds the menu. [param style] is `{rect: Rect2, fill, text, muted, ring: Color,
## ring_px, ring_offset_px, row_h, gap, font_px, title_px}`; [param meta] takes the writes.
func configure(style: Dictionary, meta: MetaApi) -> void:
	_style = style
	_meta = meta
	visible = false
	z_index = MENU_Z
	mouse_filter = Control.MOUSE_FILTER_STOP
	_panel = Panel.new()
	var box := StyleBoxFlat.new()
	box.bg_color = style.fill
	box.set_corner_radius_all(4)
	_panel.add_theme_stylebox_override("panel", box)
	var rect: Rect2 = style.rect
	_panel.position = rect.position
	_panel.size = rect.size
	add_child(_panel)
	_build_main(rect.size)
	_build_confirm(rect.size)
	_ring = Control.new()
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ring.draw.connect(_draw_ring)
	add_child(_ring)


## True while the menu is up. A closing menu is not: it only fades.
func is_open() -> bool:
	return _open


## `overlay_open` / `overlay_close` in seconds, 0 for none, and the scale the panel opens
## from, 1 under `reduce_motion` (interaction-patterns Modal Dialog).
func set_motion(open_s: float, close_s: float, scale_from: float) -> void:
	_open_s = open_s
	_close_s = close_s
	_scale_from = scale_from


## Ends a running open or close at its end state, for a pose.
func finish_motion() -> void:
	if _tween != null:
		_tween.kill()
	_settle()


## Opens on the main page with focus on Resume.
func open() -> void:
	_sync()
	_open = true
	visible = true
	_show_main(_resume)
	_animate()


## Opens the concede confirm with focus on Cancel: a reflexive `Enter` is safe.
func show_concede_confirm() -> void:
	_main.visible = false
	_confirm.visible = true
	_cancel.grab_focus()


## `Esc`, the dialog's own cancel: the confirm goes back to the menu, the menu closes.
func back() -> void:
	if _confirm.visible:
		_show_main(_concede)
	else:
		close()


## Closes the menu and gives keyboard focus back.
func close() -> void:
	if not _open:
		return
	_open = false
	get_viewport().gui_release_focus()
	closed.emit()
	_animate()


func _animate() -> void:
	if _tween != null:
		_tween.kill()
	var seconds: float = _open_s if _open else _close_s
	_panel.pivot_offset = _panel.size / 2.0
	if seconds <= 0.0:
		_settle()
		return
	if _open:
		modulate.a = 0.0
		_panel.scale = Vector2.ONE * _scale_from
	_tween = create_tween().set_parallel().set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 1.0 if _open else 0.0, seconds)
	_tween.tween_property(_panel, "scale", Vector2.ONE * (1.0 if _open else _scale_from), seconds)
	_tween.chain().tween_callback(_settle)


func _settle() -> void:
	_tween = null
	modulate.a = 1.0
	_panel.scale = Vector2.ONE
	visible = _open


func _process(_delta: float) -> void:
	if visible:
		_ring.queue_redraw()


func _draw_ring() -> void:
	var owner_control: Control = get_viewport().gui_get_focus_owner()
	if owner_control != null and owner_control.is_visible_in_tree():
		var rect: Rect2 = owner_control.get_global_rect().grow(float(_style.ring_offset_px))
		_ring.draw_rect(rect, _style.ring, false, float(_style.ring_px))


func _build_main(area: Vector2) -> void:
	_main = _column(area)
	_main.add_child(_title("pause.title"))
	_resume = _button("pause.resume")
	_resume.pressed.connect(close)
	_main.add_child(_resume)
	_concede = _button("pause.concede")
	_concede.pressed.connect(show_concede_confirm)
	_main.add_child(_concede)
	for row: Array in [["pause.volume_master", KEY_MASTER], ["pause.volume_music", KEY_MUSIC], ["pause.volume_sfx", KEY_SFX]]:
		_main.add_child(_slider_row(str(row[0]), row[1]))
	_main.add_child(_speed_row())
	_reduce = CheckButton.new()
	_reduce.text = tr("pause.reduce_motion")
	_reduce.add_theme_font_size_override("font_size", int(_style.font_px))
	_reduce.add_theme_color_override("font_color", _style.text)
	_reduce.toggled.connect(func(on: bool) -> void: _write(KEY_REDUCE_MOTION, on))
	_main.add_child(_reduce)


func _build_confirm(area: Vector2) -> void:
	_confirm = _column(area)
	_confirm.visible = false
	_confirm.add_child(_title("pause.concede_title"))
	var body := _text("pause.concede_body")
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm.add_child(body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(_style.gap))
	_cancel = _button("pause.cancel")
	_cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cancel.pressed.connect(back)
	row.add_child(_cancel)
	var yes: Button = _button("pause.concede_confirm")
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes.pressed.connect(_on_concede)
	row.add_child(yes)
	_confirm.add_child(row)


func _column(area: Vector2) -> VBoxContainer:
	var column := VBoxContainer.new()
	var margin: float = float(_style.gap) * 2.0
	column.position = Vector2(margin, margin)
	column.size = area - Vector2(margin, margin) * 2.0
	column.add_theme_constant_override("separation", int(_style.gap))
	_panel.add_child(column)
	return column


func _title(key: String) -> Label:
	var label: Label = _text(key)
	label.add_theme_font_size_override("font_size", int(_style.title_px))
	UiFonts.apply(label)
	return label


func _text(key: String) -> Label:
	var label := Label.new()
	label.text = tr(key)
	label.add_theme_font_size_override("font_size", int(_style.font_px))
	label.add_theme_color_override("font_color", _style.text)
	return label


func _button(key: String) -> Button:
	var button := Button.new()
	button.text = tr(key)
	button.custom_minimum_size = Vector2(0, float(_style.row_h))
	button.add_theme_font_size_override("font_size", int(_style.font_px))
	return button


func _slider_row(key: String, setting: StringName) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label: Label = _text(key)
	label.custom_minimum_size = Vector2(float(_style.label_w), 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = VOLUME_STEP
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(func(value: float) -> void: _write(setting, value))
	row.add_child(slider)
	_sliders[setting] = slider
	return row


func _speed_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(_style.gap))
	var group := ButtonGroup.new()
	for speed: String in SPEEDS:
		var button: Button = _button("pause.speed.%s" % speed)
		button.toggle_mode = true
		button.button_group = group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void: _write(KEY_SPEED, speed))
		row.add_child(button)
		_speed_buttons[speed] = button
	return row


func _show_main(focus: Control) -> void:
	_confirm.visible = false
	_main.visible = true
	focus.grab_focus()


# The controls show the stored settings; no write comes of it.
func _sync() -> void:
	_syncing = true
	var settings: Dictionary = _meta.get_settings()
	for key: StringName in _sliders:
		(_sliders[key] as HSlider).value = float(settings.get(key, 0.0))
	var speed: String = str(settings.get(KEY_SPEED, ""))
	if _speed_buttons.has(speed):
		(_speed_buttons[speed] as Button).button_pressed = true
	_reduce.button_pressed = settings.get(KEY_REDUCE_MOTION) == true
	_syncing = false


func _write(key: StringName, value: Variant) -> void:
	if not _syncing:
		_meta.set_setting(key, value)


func _on_concede() -> void:
	close()
	concede_confirmed.emit()
