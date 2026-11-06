## Unit tests for `InputBindings` (ADR-0004 addendum; design/gdd/meta-progression.md
## M9 `bindings`; TR-accessibility-requirements-001): the event round trip and what
## `apply` does to `InputMap`. Persistence across a restart is
## `tests/integration/save/input_bindings_restart_test.gd`.
##
## `InputMap` is global, so every test ends by restoring it through its own instance.
extends GdUnitTestSuite

const ACTION: StringName = &"ui_accept"
const CANCEL: StringName = &"ui_cancel"

var _bindings: InputBindings


func before_test() -> void:
	_bindings = InputBindings.new()


func after_test() -> void:
	_bindings.apply({})


func _key(keycode: Key) -> Dictionary:
	return {"type": "key", "keycode": keycode, "physical_keycode": KEY_NONE, "shift": false, "ctrl": false, "alt": false, "meta": false}


func _keycodes(action: StringName) -> Array:
	return InputMap.action_get_events(action).filter(func(event: InputEvent) -> bool: return event is InputEventKey) \
		.map(func(event: InputEventKey) -> int: return event.keycode)


# --- Round trip ----------------------------------------------------------------

func test_key_event_round_trips_with_its_modifiers() -> void:
	# Arrange
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_E
	event.physical_keycode = KEY_R
	event.shift_pressed = true
	event.ctrl_pressed = true
	event.alt_pressed = true
	event.meta_pressed = true

	# Act
	var back: InputEventKey = InputBindings.from_dict(InputBindings.to_dict(event))

	# Assert
	assert_int(back.keycode).is_equal(KEY_E)
	assert_int(back.physical_keycode).is_equal(KEY_R)
	assert_bool(back.shift_pressed and back.ctrl_pressed and back.alt_pressed and back.meta_pressed).is_true()


func test_mouse_event_round_trips() -> void:
	# Arrange
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_MIDDLE

	# Act
	var back: InputEventMouseButton = InputBindings.from_dict(InputBindings.to_dict(event))

	# Assert
	assert_int(back.button_index).is_equal(MOUSE_BUTTON_MIDDLE)


func test_joypad_button_round_trips() -> void:
	# Arrange
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_X

	# Act
	var back: InputEventJoypadButton = InputBindings.from_dict(InputBindings.to_dict(event))

	# Assert
	assert_int(back.button_index).is_equal(JOY_BUTTON_X)


func test_joypad_motion_round_trips_axis_and_sign() -> void:
	# Arrange
	var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_RIGHT_Y
	event.axis_value = -0.7

	# Act
	var stored: Dictionary = InputBindings.to_dict(event)
	var back: InputEventJoypadMotion = InputBindings.from_dict(stored)

	# Assert
	assert_int(stored.axis_sign).is_equal(-1)
	assert_int(back.axis).is_equal(JOY_AXIS_RIGHT_Y)
	assert_float(back.axis_value).is_equal(-1.0)


func test_to_dict_survives_json_with_every_field() -> void:
	# Arrange: the file stays JSON (ADR-0004 addendum 1); numbers come back as floats
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_F5
	event.ctrl_pressed = true
	var json_form: Variant = JSON.parse_string(JSON.stringify(InputBindings.to_dict(event)))

	# Act
	var back: InputEventKey = InputBindings.from_dict(json_form)

	# Assert
	assert_int(back.keycode).is_equal(KEY_F5)
	assert_bool(back.ctrl_pressed).is_true()


func test_to_dict_of_an_unsupported_event_is_empty() -> void:
	# Act / Assert
	assert_dict(InputBindings.to_dict(InputEventMouseMotion.new())).is_empty()


func test_from_dict_of_an_unknown_type_is_null() -> void:
	# Act / Assert
	assert_that(InputBindings.from_dict({"type": "gesture"})).is_null()
	assert_that(InputBindings.from_dict({})).is_null()


func test_from_dict_matches_every_device() -> void:
	# Act
	var event: InputEvent = InputBindings.from_dict(_key(KEY_E))

	# Assert: 4.7 keyboards report their own device id, so device 0 would not match
	assert_int(event.device).is_equal(InputBindings.ALL_DEVICES)


# --- apply ---------------------------------------------------------------------

func test_apply_replaces_an_action_events() -> void:
	# Act
	_bindings.apply({String(ACTION): [_key(KEY_E)]})

	# Assert
	assert_int(InputMap.action_get_events(ACTION).size()).is_equal(1)
	assert_array(_keycodes(ACTION)).is_equal([KEY_E])


func test_applied_event_matches_a_keypress_from_a_real_device_id() -> void:
	# Arrange
	_bindings.apply({String(ACTION): [_key(KEY_E)]})
	var press: InputEventKey = InputEventKey.new()
	press.keycode = KEY_E
	press.pressed = true
	press.device = 7

	# Act / Assert
	assert_bool(InputMap.event_is_action(press, ACTION)).is_true()


func test_apply_empty_map_restores_the_engine_defaults() -> void:
	# Arrange
	var defaults: Array = _keycodes(ACTION)
	_bindings.apply({String(ACTION): [_key(KEY_E)]})

	# Act
	_bindings.apply({})

	# Assert
	assert_array(_keycodes(ACTION)).is_equal(defaults)


func test_apply_leaves_an_action_not_in_the_map_on_its_default() -> void:
	# Arrange
	var defaults: Array = _keycodes(&"ui_left")

	# Act
	_bindings.apply({String(ACTION): [_key(KEY_E)]})

	# Assert
	assert_array(_keycodes(&"ui_left")).is_equal(defaults)


func test_apply_dropping_an_action_returns_it_to_its_default() -> void:
	# Arrange
	var defaults: Array = _keycodes(&"ui_left")
	_bindings.apply({"ui_left": [_key(KEY_E)]})

	# Act
	_bindings.apply({String(ACTION): [_key(KEY_E)]})

	# Assert
	assert_array(_keycodes(&"ui_left")).is_equal(defaults)


func test_apply_never_touches_ui_cancel() -> void:
	# Arrange
	var defaults: Array = _keycodes(CANCEL)

	# Act: a hand-edited map, past the store's clean
	_bindings.apply({String(CANCEL): [_key(KEY_E)]})

	# Assert (M9: cancel/Esc never rebindable)
	assert_array(_keycodes(CANCEL)).is_equal(defaults)
	assert_array(defaults).contains([KEY_ESCAPE])


func test_apply_ignores_an_unknown_action_name() -> void:
	# Act
	_bindings.apply({"no_such_action": [_key(KEY_E)]})

	# Assert
	assert_bool(InputMap.has_action(&"no_such_action")).is_false()


func test_apply_skips_an_event_that_does_not_parse_and_keeps_the_rest() -> void:
	# Act
	_bindings.apply({String(ACTION): [{"type": "gesture"}, 12, _key(KEY_E)]})

	# Assert
	assert_array(_keycodes(ACTION)).is_equal([KEY_E])
