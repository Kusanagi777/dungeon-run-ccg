## `RunText` (run-ui U1.4) and `RunInput` (U3; interaction-patterns Standard Shortcuts):
## the one `Translation`, and the action names everything else leans on.
extends GdUnitTestSuite

const KEY_A_NAME: String = "test.run_text.a"
const KEY_B_NAME: String = "test.run_text.b"
## interaction-patterns Standard Shortcuts, by action.
const KEYS: Dictionary = {
	"option_1": KEY_1, "option_2": KEY_2, "option_3": KEY_3, "skip": KEY_SPACE, "end_turn": KEY_ENTER,
	"hero_power": KEY_H, "feed_toggle": KEY_L, "attacker_mode": KEY_A, "hand_1": KEY_1, "hand_10": KEY_0,
}


func before_test() -> void:
	RunUiRig.install_input()


func after_test() -> void:
	RunUiRig.restore_input()
	if RunText._table != null:
		RunText._table.erase_message(KEY_A_NAME)
		RunText._table.erase_message(KEY_B_NAME)


func _tables() -> int:
	return TranslationServer.get_or_add_domain(&"").get_translations().size()


func test_install_twice_adds_one_translation_and_no_duplicate_messages() -> void:
	# Arrange
	RunText.install({"strings": {KEY_A_NAME: "one"}})
	var tables: int = _tables()
	var messages: int = RunText._table.get_message_count()

	# Act
	RunText.install({"strings": {KEY_A_NAME: "one"}})
	RunText.install({"strings": {KEY_A_NAME: "one"}})

	# Assert
	assert_int(_tables()).is_equal(tables)
	assert_int(RunText._table.get_message_count()).is_equal(messages)
	assert_str(RunText.t(KEY_A_NAME)).is_equal("one")


func test_a_later_install_adds_to_the_table_and_never_hides_it() -> void:
	# Arrange
	RunText.install({"strings": {KEY_A_NAME: "one"}})

	# Act: the shape of `FALLBACK_CONFIG`, with only some strings
	RunText.install({"strings": {KEY_B_NAME: "two"}})

	# Assert
	assert_str(RunText.t(KEY_A_NAME)).is_equal("one")
	assert_str(RunText.t(KEY_B_NAME)).is_equal("two")


func test_a_later_install_replaces_a_changed_string() -> void:
	RunText.install({"strings": {KEY_A_NAME: "one"}})
	RunText.install({"strings": {KEY_A_NAME: "uno"}})
	assert_str(RunText.t(KEY_A_NAME)).is_equal("uno")


func test_install_without_strings_changes_nothing() -> void:
	RunText.install({"strings": {KEY_A_NAME: "one"}})
	var messages: int = RunText._table.get_message_count()
	RunText.install({})
	assert_int(RunText._table.get_message_count()).is_equal(messages)


func test_t_fills_named_fields() -> void:
	RunText.install({"strings": {KEY_A_NAME: "Fell on floor {n}: {boss}"}})
	assert_str(RunText.t(KEY_A_NAME, {"n": 5, "boss": "Rat King"})).is_equal("Fell on floor 5: Rat King")


func test_data_prefers_a_translated_key_then_en_then_empty() -> void:
	RunText.install({"strings": {KEY_A_NAME: "translated"}})
	assert_str(RunText.data({"key": KEY_A_NAME, "en": "plain"})).is_equal("translated")
	assert_str(RunText.data({"key": "test.run_text.absent", "en": "plain"})).is_equal("plain")
	assert_str(RunText.data({"en": "plain"})).is_equal("plain")
	assert_str(RunText.data(null)).is_equal("")
	assert_str(RunText.data("text")).is_equal("")


# --- RunInput ---------------------------------------------------------------------

func test_install_adds_every_named_action_with_its_key() -> void:
	for action: String in KEYS:
		assert_bool(InputMap.has_action(action)).override_failure_message(action).is_true()
		var key: InputEventKey = InputEventKey.new()
		key.keycode = KEYS[action]
		key.pressed = true
		assert_bool(InputMap.event_is_action(key, action)).override_failure_message(action).is_true()


func test_every_hand_action_exists() -> void:
	for i: int in range(1, 11):
		assert_bool(InputMap.has_action("hand_%d" % i)).is_true()


func test_a_key_from_any_device_matches() -> void:
	# 4.7: a keyboard reports its own device id, so a default of 0 would not match
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_2
	key.device = 7
	key.pressed = true
	assert_bool(InputMap.event_is_action(key, &"option_2")).is_true()


func test_every_action_the_controls_page_lists_exists() -> void:
	var groups: Dictionary = RunUiRig.config().controls.actions
	for group: String in groups:
		for action: String in groups[group]:
			assert_bool(InputMap.has_action(action)).override_failure_message(action).is_true()


func test_escape_is_on_no_rebindable_list() -> void:
	var groups: Dictionary = RunUiRig.config().controls.actions
	for group: String in groups:
		assert_array(groups[group]).not_contains(["ui_cancel", "cancel"])


func test_install_puts_the_gamepad_on_the_focus_graph() -> void:
	for row: Array in [[&"ui_accept", JOY_BUTTON_A], [&"ui_cancel", JOY_BUTTON_B], [&"ui_focus_next", JOY_BUTTON_RIGHT_SHOULDER], [&"ui_focus_prev", JOY_BUTTON_LEFT_SHOULDER]]:
		var button: InputEventJoypadButton = InputEventJoypadButton.new()
		button.button_index = row[1]
		button.device = 2
		button.pressed = true
		assert_bool(InputMap.event_is_action(button, row[0])).override_failure_message(str(row[0])).is_true()


func test_the_dpad_walks_focus() -> void:
	for row: Array in [[&"ui_up", JOY_BUTTON_DPAD_UP], [&"ui_down", JOY_BUTTON_DPAD_DOWN], [&"ui_left", JOY_BUTTON_DPAD_LEFT], [&"ui_right", JOY_BUTTON_DPAD_RIGHT]]:
		var button: InputEventJoypadButton = InputEventJoypadButton.new()
		button.button_index = row[1]
		button.pressed = true
		assert_bool(InputMap.event_is_action(button, row[0])).override_failure_message(str(row[0])).is_true()


func test_install_twice_adds_nothing() -> void:
	# Arrange
	var before: Dictionary = {}
	for action: StringName in InputMap.get_actions():
		before[action] = InputMap.action_get_events(action).size()

	# Act
	RunInput.install()

	# Assert
	for action: StringName in InputMap.get_actions():
		assert_int(InputMap.action_get_events(action).size()).override_failure_message(str(action)).is_equal(int(before[action]))


func test_install_leaves_an_action_that_already_exists_alone() -> void:
	# Arrange: a rebind applied before a second install
	InputMap.action_erase_events(&"option_1")
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_Q
	InputMap.action_add_event(&"option_1", key)

	# Act
	RunInput.install()

	# Assert
	assert_int(InputMap.action_get_events(&"option_1").size()).is_equal(1)
	assert_int((InputMap.action_get_events(&"option_1")[0] as InputEventKey).keycode).is_equal(KEY_Q)
