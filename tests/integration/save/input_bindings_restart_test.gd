## Integration: a rebind through the profile, across a restart (ADR-0004 addendum;
## design/gdd/meta-progression.md M9 `bindings`; TR-accessibility-requirements-001).
## A real store on real files, and `InputMap` driven by what the reloaded profile holds,
## as `Boot` does it. `InputMap` is global: every test restores it.
extends GdUnitTestSuite

const ACTION: StringName = &"ui_accept"
const CANCEL: StringName = &"ui_cancel"

var _root: String
var _clock: ProfileFixtures.ManualClock
var _input: InputBindings


func before_test() -> void:
	_root = ProfileFixtures.new_root()
	_clock = ProfileFixtures.ManualClock.new()
	_input = InputBindings.new()


func after_test() -> void:
	_input.apply({})
	ProfileFixtures.remove_root(_root)


func _store() -> ProfileStore:
	var store: ProfileStore = ProfileFixtures.store(_root, _clock)
	store.load_profile()
	return store


func _restart(store: ProfileStore) -> ProfileStore:
	store.release_lock()
	return _store()


func _key_event(keycode: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	return event


func _rebound_map(action: StringName, keycode: Key) -> Dictionary:
	return {String(action): [InputBindings.to_dict(_key_event(keycode))]}


func _keycodes(action: StringName) -> Array:
	return InputMap.action_get_events(action).filter(func(event: InputEvent) -> bool: return event is InputEventKey) \
		.map(func(event: InputEventKey) -> int: return event.keycode)


func _apply_from(store: ProfileStore) -> void:
	var bindings: Variant = store.get_setting(&"bindings")
	_input.apply(bindings if bindings is Dictionary else {})


func test_rebind_survives_a_restart_and_applies_to_input_map() -> void:
	# Arrange
	var store: ProfileStore = _store()
	var outcome: Error = store.set_setting(&"bindings", _rebound_map(ACTION, KEY_E))
	var next: ProfileStore = _restart(store)

	# Act
	_apply_from(next)

	# Assert
	assert_int(outcome).is_equal(OK)
	assert_array(_keycodes(ACTION)).is_equal([KEY_E])


func test_rebind_round_trips_modifiers_through_the_file() -> void:
	# Arrange
	var event: InputEventKey = _key_event(KEY_F2)
	event.ctrl_pressed = true
	var store: ProfileStore = _store()
	store.set_setting(&"bindings", {String(ACTION): [InputBindings.to_dict(event)]})
	var next: ProfileStore = _restart(store)

	# Act
	_apply_from(next)

	# Assert
	var bound: InputEventKey = InputMap.action_get_events(ACTION)[0]
	assert_int(bound.keycode).is_equal(KEY_F2)
	assert_bool(bound.ctrl_pressed).is_true()


func test_rebind_stored_numbers_load_as_ints() -> void:
	# Arrange
	var store: ProfileStore = _store()
	store.set_setting(&"bindings", _rebound_map(ACTION, KEY_E))

	# Act
	var next: ProfileStore = _restart(store)

	# Assert
	assert_bool(next.get_setting(&"bindings")[String(ACTION)][0].keycode is int).is_true()


func test_rebinding_ui_cancel_is_dropped_and_never_reaches_the_file() -> void:
	# Arrange
	var store: ProfileStore = _store()
	var defaults: Array = _keycodes(CANCEL)
	var map: Dictionary = _rebound_map(CANCEL, KEY_E)
	map.merge(_rebound_map(ACTION, KEY_R))
	store.set_setting(&"bindings", map)
	var next: ProfileStore = _restart(store)

	# Act
	_apply_from(next)

	# Assert (M9: cancel/Esc never rebindable)
	assert_array(next.get_setting(&"bindings").keys()).is_equal([String(ACTION)])
	assert_array(_keycodes(CANCEL)).is_equal(defaults)
	assert_array(_keycodes(ACTION)).is_equal([KEY_R])


func test_hand_edited_cancel_in_the_file_is_dropped_on_load() -> void:
	# Arrange (ADR-0004 addendum 3: "a hand-edited profile cannot remove the one guaranteed key")
	var profile: Dictionary = ProfileFixtures.profile_dict()
	profile.settings["bindings"] = {"cancel": [], String(CANCEL): [], String(ACTION): []}
	ProfileFixtures.write_profile(_root, profile)

	# Act
	var store: ProfileStore = _store()

	# Assert
	assert_array(store.get_setting(&"bindings").keys()).is_equal([String(ACTION)])


func test_an_absent_map_means_engine_defaults() -> void:
	# Arrange
	var defaults: Array = _keycodes(ACTION)
	var store: ProfileStore = _store()
	store.save_profile()

	# Act
	_apply_from(_restart(store))

	# Assert
	assert_that(_store_setting_after_reload()).is_null()
	assert_array(_keycodes(ACTION)).is_equal(defaults)


func _store_setting_after_reload() -> Variant:
	var on_disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_root.path_join("profile.json")))
	return on_disk.settings.get("bindings")


func test_unknown_action_in_the_map_survives_the_file_and_is_ignored_when_applied() -> void:
	# Arrange
	var store: ProfileStore = _store()
	store.set_setting(&"bindings", _rebound_map(&"no_such_action", KEY_E))
	var next: ProfileStore = _restart(store)

	# Act
	_apply_from(next)

	# Assert
	assert_bool(next.get_setting(&"bindings").has("no_such_action")).is_true()
	assert_bool(InputMap.has_action(&"no_such_action")).is_false()
