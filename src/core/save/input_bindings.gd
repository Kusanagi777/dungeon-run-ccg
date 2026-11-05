## Applies `settings.bindings` to `InputMap` (ADR-0004 addendum; meta-progression
## M9; TR-accessibility-requirements-001), and turns events into the plain
## Dictionaries the profile stores: no `Resource`, the file stays JSON.
##
## An instance keeps the `InputMap` it found when built as the engine defaults, so
## an action dropped from the map goes back to them. Stored shapes:
## `{type: "key", keycode, physical_keycode, shift, ctrl, alt, meta}`,
## `{type: "mouse_button", button_index}`, `{type: "joypad_button", button_index}`,
## `{type: "joypad_motion", axis, axis_sign}`.
##
## Single-thread-only: `Boot` builds and calls it on the main thread.
##
## [codeblock]
## var bindings := InputBindings.new()
## bindings.apply({"ui_accept": [InputBindings.to_dict(key_event)]})
## [/codeblock]
class_name InputBindings
extends RefCounted

## `InputMap` matches an event's device unless it is this value (the engine's
## `ALL_DEVICES`, not exposed to scripts). It must be set: the default device is
## 0, and since 4.7 keyboard and mouse report their own device ids.
const ALL_DEVICES: int = -1

var _defaults: Dictionary = {}


## Records every action's current events as the defaults.
func _init() -> void:
	for action: StringName in InputMap.get_actions():
		_defaults[action] = InputMap.action_get_events(action)


## Restores the defaults, then replaces the events of each action in
## [param bindings]. An unknown action name is logged and ignored (M5.3), and so is
## an event that does not parse. The map is expected clean
## (`ProfileSchema.clean_bindings`); `cancel` is skipped here as well.
func apply(bindings: Dictionary) -> void:
	for action: StringName in _defaults:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
			for event: InputEvent in _defaults[action]:
				InputMap.action_add_event(action, event)
	for raw_action: Variant in bindings:
		var action: StringName = StringName(str(raw_action))
		if ProfileSchema.UNREBINDABLE_ACTIONS.has(String(action)):
			continue
		if not InputMap.has_action(action):
			push_warning("profile_repaired{path: settings.bindings.%s, from: <unknown action>, to: ignored}" % action)
			continue
		InputMap.action_erase_events(action)
		for stored: Variant in bindings[raw_action]:
			var event: InputEvent = from_dict(stored) if stored is Dictionary else null
			if event == null:
				push_warning("profile_repaired{path: settings.bindings.%s, from: %s, to: ignored}" % [action, str(stored)])
				continue
			InputMap.action_add_event(action, event)


## [param event] as a stored Dictionary, or `{}` for a type the map cannot hold.
## Example: `InputBindings.to_dict(key_event)`.
static func to_dict(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key: InputEventKey = event
		return {"type": "key", "keycode": key.keycode, "physical_keycode": key.physical_keycode,
			"shift": key.shift_pressed, "ctrl": key.ctrl_pressed, "alt": key.alt_pressed, "meta": key.meta_pressed}
	if event is InputEventMouseButton:
		return {"type": "mouse_button", "button_index": (event as InputEventMouseButton).button_index}
	if event is InputEventJoypadButton:
		return {"type": "joypad_button", "button_index": (event as InputEventJoypadButton).button_index}
	if event is InputEventJoypadMotion:
		var motion: InputEventJoypadMotion = event
		return {"type": "joypad_motion", "axis": motion.axis, "axis_sign": 1 if motion.axis_value >= 0.0 else -1}
	return {}


## The event a stored [param data] describes, on every device, or `null`.
## Example: `InputBindings.from_dict({"type": "key", "keycode": KEY_E})`.
static func from_dict(data: Dictionary) -> InputEvent:
	var event: InputEvent = null
	match data.get("type"):
		"key":
			var key: InputEventKey = InputEventKey.new()
			key.keycode = int(data.get("keycode", 0)) as Key
			key.physical_keycode = int(data.get("physical_keycode", 0)) as Key
			key.shift_pressed = data.get("shift", false) == true
			key.ctrl_pressed = data.get("ctrl", false) == true
			key.alt_pressed = data.get("alt", false) == true
			key.meta_pressed = data.get("meta", false) == true
			event = key
		"mouse_button":
			var mouse: InputEventMouseButton = InputEventMouseButton.new()
			mouse.button_index = int(data.get("button_index", 0)) as MouseButton
			event = mouse
		"joypad_button":
			var button: InputEventJoypadButton = InputEventJoypadButton.new()
			button.button_index = int(data.get("button_index", 0)) as JoyButton
			event = button
		"joypad_motion":
			var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
			motion.axis = int(data.get("axis", 0)) as JoyAxis
			motion.axis_value = float(data.get("axis_sign", 1))
			event = motion
	if event != null:
		event.device = ALL_DEVICES
	return event
