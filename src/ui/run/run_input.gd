## The `InputMap` actions the interaction library names (Standard Shortcuts; accessibility
## Motor "Full input remapping") that the project file does not define, added before
## `Boot` so `InputBindings` records them as the defaults. Also puts the gamepad on the
## focus graph: `ui_accept`, `ui_cancel` and the d-pad are the engine's, and the shoulders
## walk `Tab` order (run-ui U3; interaction-patterns "Gamepad").
##
## The rebindable list the Controls page shows is `config("run_ui").controls.actions`.
## [codeblock]
## RunInput.install()
## Boot.boot()
## [/codeblock]
class_name RunInput
extends RefCounted

## Action to default key, per interaction-patterns Standard Shortcuts.
const KEY_DEFAULTS: Dictionary = {
	"option_1": KEY_1, "option_2": KEY_2, "option_3": KEY_3,
	"skip": KEY_SPACE, "end_turn": KEY_ENTER, "hero_power": KEY_H,
	"feed_toggle": KEY_L, "attacker_mode": KEY_A,
	"hand_1": KEY_1, "hand_2": KEY_2, "hand_3": KEY_3, "hand_4": KEY_4, "hand_5": KEY_5,
	"hand_6": KEY_6, "hand_7": KEY_7, "hand_8": KEY_8, "hand_9": KEY_9, "hand_10": KEY_0,
}
## Action to gamepad button.
const PAD_DEFAULTS: Dictionary = {
	"ui_focus_next": JOY_BUTTON_RIGHT_SHOULDER,
	"ui_focus_prev": JOY_BUTTON_LEFT_SHOULDER,
	"ui_accept": JOY_BUTTON_A,
	"ui_cancel": JOY_BUTTON_B,
}


## Adds the missing actions and the gamepad buttons. Safe to call twice.
static func install() -> void:
	for action: String in KEY_DEFAULTS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var key: InputEventKey = InputEventKey.new()
		key.keycode = KEY_DEFAULTS[action]
		key.device = InputBindings.ALL_DEVICES
		InputMap.action_add_event(action, key)
	for action: String in PAD_DEFAULTS:
		var button: InputEventJoypadButton = InputEventJoypadButton.new()
		button.button_index = PAD_DEFAULTS[action]
		button.device = InputBindings.ALL_DEVICES
		if not InputMap.action_has_event(action, button):
			InputMap.action_add_event(action, button)
