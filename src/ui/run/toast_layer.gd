## The toast queue (run-ui U5, F3; ADR-0011 Decision 3): one toast at a time, top
## right, above every screen and above the swapped-in `MatchView`. A queued toast may
## **start** only while the shell is idle; a showing one rides every transition until
## its `t_toast` elapses or a click dismisses it. Toasts take no focus: hover (or an LMB
## hold) pauses the timer, and the release of a click dismisses it. Beyond
## `toast_queue_max` warnings the oldest goes first; an unlock neither counts against the
## cap nor is ever dropped (AC-16), and a key in both the signal and the queue shows once.
## [codeblock]
## layer.configure(ui_config)
## layer.shown.connect(controller.on_toast_shown)
## layer.set_idle(true)
## layer.enqueue(&"unlock", {"key": "unlock.hero_decay", "title": "New hero unlocked: Mother Wythe"})
## [/codeblock]
class_name ToastLayer
extends Control

## A toast started showing; [param key] is empty for a warning. The controller acks here.
signal shown(kind: StringName, key: String)

const KIND_UNLOCK: StringName = &"unlock"
const KIND_WARNING: StringName = &"warning"
const TOAST_RECT: Rect2 = Rect2(856, 56, 400, 48)
const SWATCH_PX: float = 16.0

var _config: Dictionary = {}
var _queue: Array[Dictionary] = []
var _seen_keys: Dictionary = {}
var _idle: bool = false
var _panel: PanelContainer = null
## Milliseconds left on the showing toast.
var _left_ms: float = 0.0
## Milliseconds left of the gap before the next may start.
var _gap_ms: float = 0.0
var _hovered: bool = false
var _pressed: bool = false
var _speed: String = RunUiConfig.SPEED_NORMAL
var _reduce_motion: bool = false


## Reads the F3 knobs from [param ui_config].
func configure(ui_config: Dictionary) -> void:
	_config = ui_config


## Sets the `anim_speed` and `reduce_motion` the fade-in honours.
func set_motion(anim_speed: String, reduce_motion: bool) -> void:
	_speed = anim_speed
	_reduce_motion = reduce_motion


## Tells the layer whether a queued toast may start.
func set_idle(idle: bool) -> void:
	_idle = idle


## Queues a toast. [param payload] holds `title`, optional `subtitle` and `swatch` (a
## colour), and `key` for an unlock.
func enqueue(kind: StringName, payload: Dictionary) -> void:
	if kind == KIND_UNLOCK:
		var key: String = str(payload.get("key", ""))
		if _seen_keys.has(key):
			return
		_seen_keys[key] = true
	var row: Dictionary = payload.duplicate()
	row["kind"] = kind
	_queue.append(row)
	_enforce_cap()


## The toasts waiting, oldest first. Read only.
func queued() -> Array[Dictionary]:
	return _queue


## True while a toast is on screen.
func is_showing() -> bool:
	return _panel != null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	var delta_ms: float = delta * RunUiConfig.MS_PER_S
	if _panel != null:
		if not _hovered and not _pressed:
			_left_ms -= delta_ms
			if _left_ms <= 0.0:
				_dismiss()
		return
	if _gap_ms > 0.0:
		_gap_ms -= delta_ms
		return
	if _idle and not _queue.is_empty():
		_show(_queue.pop_front())


func _enforce_cap() -> void:
	var cap: int = int(_config.get("toast_queue_max", 0))
	var warnings: Array[int] = []
	for i: int in _queue.size():
		if _queue[i].kind == KIND_WARNING:
			warnings.append(i)
	var over: int = warnings.size() - cap
	for i: int in range(over - 1, -1, -1):
		_queue.remove_at(warnings[i])


func _show(row: Dictionary) -> void:
	var title: String = str(row.get("title", ""))
	var subtitle: String = str(row.get("subtitle", ""))
	_panel = UiKit.panel(RunUiTheme.PANEL_DARK)
	UiKit.place(_panel, TOAST_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.mouse_entered.connect(_on_hover.bind(true))
	_panel.mouse_exited.connect(_on_hover.bind(false))
	_panel.gui_input.connect(_on_panel_input)
	var rows: HBoxContainer = UiKit.hbox()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(rows)
	var swatch: Variant = row.get("swatch")
	if swatch is String:
		var chip: ColorRect = ColorRect.new()
		chip.color = RunUiConfig.color(_config, swatch)
		chip.custom_minimum_size = Vector2(SWATCH_PX, SWATCH_PX)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rows.add_child(chip)
	var text: VBoxContainer = UiKit.vbox(2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(text)
	var unlock: bool = row.kind == KIND_UNLOCK
	text.add_child(UiKit.label(title, &"" if unlock else RunUiTheme.LABEL_MUTED, true))
	if not subtitle.is_empty():
		text.add_child(UiKit.label(subtitle, RunUiTheme.LABEL_SMALL, true))
	add_child(_panel)
	_left_ms = float(RunUiConfig.t_toast(_config, title.length() + subtitle.length()))
	_hovered = false
	_pressed = false
	var fade_ms: int = RunUiConfig.t_transition(_config, RunUiConfig.KIND_TOAST, _speed, _reduce_motion)
	if fade_ms > 0:
		_panel.modulate.a = 0.0
		_panel.create_tween().tween_property(_panel, "modulate:a", 1.0, fade_ms / RunUiConfig.MS_PER_S)
	shown.emit(row.kind, str(row.get("key", "")))


func _on_hover(on: bool) -> void:
	_hovered = on


func _on_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressed = true
		elif _pressed:
			_dismiss()


func _dismiss() -> void:
	_panel.queue_free()
	_panel = null
	_gap_ms = float(_config.get("toast_gap_ms", 0))
