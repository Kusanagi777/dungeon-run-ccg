## What one input event asks for (interaction-patterns Standard Shortcuts: `InputRouter`
## reads actions, never key codes). Keyboard and gamepad land on the same names, so the
## focus graph and the targeting session have one input surface. Mouse events are not
## read here: they are positions, and [InputRouter] takes them by type.
##
## `Space` is its own action because it is not a confirm (targeting.md §7.2): it sits on
## `ui_accept` too, so it is read first.
## [codeblock]
## match MatchInput.read(event):
##     MatchInput.CANCEL:
##         router.escape()
## var slot: int = MatchInput.hand_slot(event)   # 0 for `1`, 9 for `0`, -1 for none
## [/codeblock]
class_name MatchInput
extends RefCounted

## What [method read] answers; `&""` is nothing this view listens to.
const NONE: StringName = &""
const CANCEL: StringName = &"cancel"
const CONFIRM: StringName = &"confirm"
const END_TURN: StringName = &"end_turn"
const NEXT: StringName = &"next"
const PREVIOUS: StringName = &"previous"
const LEFT: StringName = &"left"
const RIGHT: StringName = &"right"
const UP: StringName = &"up"
const DOWN: StringName = &"down"
const HERO_POWER: StringName = &"hero_power"
const ATTACK: StringName = &"attack"
const FEED: StringName = &"feed"
const HAND: StringName = &"hand"
const HAND_SLOTS: int = 10
const HAND_ACTION: String = "match_hand_%d"
## Action to name, most specific first: `Shift+Tab` also matches `Tab`, and `Space`
## also matches `ui_accept`.
const ACTIONS: Dictionary = {
	&"ui_cancel": CANCEL,
	&"match_end_turn": END_TURN,
	&"ui_accept": CONFIRM,
	&"ui_focus_prev": PREVIOUS,
	&"ui_focus_next": NEXT,
	&"ui_left": LEFT,
	&"ui_right": RIGHT,
	&"ui_up": UP,
	&"ui_down": DOWN,
	&"match_hero_power": HERO_POWER,
	&"match_attack": ATTACK,
	&"match_feed": FEED,
}
const STICK_ACTIONS: Array[StringName] = [&"ui_left", &"ui_right", &"ui_up", &"ui_down"]

# The frame a stick last moved focus: motion events repeat while the stick is held.
static var _stick_frame: int = -1


## The name [param event] carries, or [constant NONE]. A number key reads as
## [constant HAND]; [method hand_slot] says which.
static func read(event: InputEvent) -> StringName:
	if event is InputEventJoypadMotion:
		return _read_stick(event)
	for action: StringName in ACTIONS:
		if event.is_action_pressed(action):
			return ACTIONS[action]
	return HAND if hand_slot(event) >= 0 else NONE


## The hand index a number key picks, or -1: `1` is 0, `9` is 8 and `0` is 9.
static func hand_slot(event: InputEvent) -> int:
	for i: int in HAND_SLOTS:
		if event.is_action_pressed(StringName(HAND_ACTION % (i + 1))):
			return i
	return -1


# A held stick reports every frame, so only its first crossing of the deadzone counts.
static func _read_stick(event: InputEvent) -> StringName:
	var frame: int = Engine.get_process_frames()
	if frame == _stick_frame:
		return NONE
	for action: StringName in STICK_ACTIONS:
		if event.is_action(action) and Input.is_action_just_pressed(action):
			_stick_frame = frame
			return ACTIONS[action]
	return NONE
