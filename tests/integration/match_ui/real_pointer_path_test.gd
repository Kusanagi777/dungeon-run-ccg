## The pointer through the viewport's real GUI path (owner playtest, 2026-11-06).
##
## `MatchViewHarness.send` calls `_unhandled_input` directly, so it cannot see a Control
## that swallows the event first. `MatchView` reads the mouse in `_unhandled_input`, so
## everything above it in the live scene must let the pointer through. These tests go
## through `Viewport.push_input`, which is the path a real mouse takes.
extends GdUnitTestSuite

const MAIN_SCENE: String = "res://src/scenes/main.tscn"
const SHELL_SCENE: String = "res://src/ui/run/run_shell.tscn"
const IDLE_FRAMES: int = 240

var _rig: RunUiRig = null


func before() -> void:
	RunUiRig.install_input()


func after() -> void:
	RunUiRig.restore_input()
	RunUiRig.wipe_profiles()


func after_test() -> void:
	if _rig != null:
		_rig.finish()
		_rig = null


## A live match at `Idle`, past the Mulligan.
func _open_match() -> MatchView:
	_rig = await RunUiRig.start(self)
	await _rig.to_boss()
	var view: MatchView = await _rig.begin()
	(view.get("_mulligan") as Object).call("confirm")
	await _to_idle(view)
	return view


## Until the player could act: `Idle` reached and legality shown. A skip straight after a
## command can land before that command's events arrive, so `Idle` alone proves nothing.
func _to_idle(view: MatchView) -> void:
	for _frame: int in IDLE_FRAMES:
		view.queue().skip_all()
		await get_tree().process_frame
		var ready: bool = view.router().view_state() == InputRouter.STATE_IDLE
		if ready and not (view.get("_end_turn") as Button).disabled:
			return


func _motion(at: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = _window_point(at)
	event.global_position = event.position
	return event


## [param at] in the coordinates a real pointer reports. The runner's headless window is
## not 1280x720, so game coordinates go through the stretch transform, as an OS pointer's do.
func _window_point(at: Vector2) -> Vector2:
	return _rig.shell.get_viewport().get_final_transform() * at


func _button(at: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = _window_point(at)
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	return event


func _push(event: InputEvent) -> void:
	_rig.shell.get_viewport().push_input(event)
	await get_tree().process_frame


## A card the player can afford, so a press may pick it up.
func _first_card(view: MatchView) -> Dictionary:
	var id: int = int(view.hand().get("_playable").keys()[0])
	return {"id": id, "at": (view.hand().card(id) as Control).get_global_rect().get_center()}


func test_main_lets_the_pointer_through_to_the_match_under_it() -> void:
	var main: Control = auto_free((load(MAIN_SCENE) as PackedScene).instantiate())
	assert_int(main.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


func test_the_run_shell_lets_the_pointer_through_to_the_match_under_it() -> void:
	var shell: Control = auto_free((load(SHELL_SCENE) as PackedScene).instantiate())
	assert_int(shell.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


func test_a_real_pointer_over_a_card_previews_it() -> void:
	# Arrange
	var view: MatchView = await _open_match()
	assert_str(String(view.router().view_state())).is_equal(String(InputRouter.STATE_IDLE))
	var card: Dictionary = _first_card(view)

	# Act
	await _push(_motion(card.at))

	# Assert
	assert_int(int(view.hand().get("_hovered"))).is_equal(int(card.id))


func test_a_real_click_on_a_card_selects_it() -> void:
	# Arrange: press + release under `CLICK_DRAG_PX` is a click (targeting.md)
	var view: MatchView = await _open_match()
	var card: Dictionary = _first_card(view)
	await _push(_motion(card.at))

	# Act
	await _push(_button(card.at, true))
	await _push(_button(card.at, false))

	# Assert
	assert_bool(view.router().in_session()).is_true()


func test_a_real_click_toggles_a_mulligan_card_and_a_real_click_confirms() -> void:
	# Arrange
	_rig = await RunUiRig.start(self)
	await _rig.to_boss()
	var view: MatchView = await _rig.begin()
	var mulligan: Object = view.get("_mulligan")
	var card: Control = mulligan.get("_cards")[0]
	var at: Vector2 = card.get_global_rect().get_center()

	# Act
	await _push(_motion(at))
	await _push(_button(at, true))
	await _push(_button(at, false))

	# Assert
	assert_bool(bool(mulligan.call("keep_mask")[0])).is_false()

	# Act
	var confirm: Vector2 = (mulligan.get("_confirm") as Control).get_global_rect().get_center()
	await _push(_motion(confirm))
	await _push(_button(confirm, true))
	await _push(_button(confirm, false))

	# Assert
	assert_bool(bool(mulligan.call("is_open"))).is_false()


func test_a_real_click_on_end_turn_passes_the_turn() -> void:
	# Arrange
	var view: MatchView = await _open_match()
	var button: Button = view.get("_end_turn")
	var at: Vector2 = button.get_global_rect().get_center()
	view.router().set_end_turn_arm(0)
	var before: int = view.view_state().turn

	# Act
	await _push(_motion(at))
	await _push(_button(at, true))
	await _push(_button(at, false))
	await _to_boss_turn(view, before)

	# Assert
	assert_int(view.view_state().turn).is_greater(before)


func _to_boss_turn(view: MatchView, turn: int) -> void:
	for _frame: int in IDLE_FRAMES:
		view.queue().skip_all()
		if view.view_state().turn > turn:
			return
		await get_tree().process_frame


func test_a_real_drag_plays_a_card_onto_the_board() -> void:
	# Arrange
	var view: MatchView = await _open_match()
	var from: Vector2 = _first_card(view).at
	var to: Vector2 = view.get_global_rect().get_center()
	var before: int = view.view_state().side(&"player").hand.size()

	# Act
	await _push(_motion(from))
	await _push(_button(from, true))
	await _push(_motion(to))
	await _push(_button(to, false))
	await _to_idle(view)

	# Assert
	assert_int(view.view_state().side(&"player").hand.size()).is_equal(before - 1)
