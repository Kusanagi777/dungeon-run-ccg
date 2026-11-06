## `ShellState` and the `Screen` base (ADR-0011 Decision 1; run-ui U1, U4): the top of the
## stack, the `Esc` chain, intents out, and what a screen without options ignores.
extends GdUnitTestSuite

const CFG: Dictionary = {"palette": {"bg_edge": "#141820"}}


## The smallest concrete screen, and a drawer it can report open.
class FakeScreen:
	extends Screen

	var drawer_open: bool = false
	var bound: Array = []

	func bind(read_model: Dictionary) -> void:
		bound.append(read_model)

	func default_focus() -> Control:
		return null

	func close_drawer() -> bool:
		var was: bool = drawer_open
		drawer_open = false
		return was


func _screen() -> FakeScreen:
	var screen: FakeScreen = auto_free(FakeScreen.new())
	screen.cfg = CFG
	add_child(screen)
	return screen


func _sent(screen: Screen) -> Array:
	var rows: Array = []
	screen.intent_requested.connect(func(name: StringName, args: Dictionary) -> void: rows.append([name, args]))
	return rows


func test_top_is_the_base_with_no_overlay() -> void:
	var state: ShellState = ShellState.new()
	state.base = &"boss_intro"
	assert_str(String(state.top())).is_equal("boss_intro")


func test_top_is_the_last_overlay() -> void:
	var state: ShellState = ShellState.new()
	state.base = &"boss_intro"
	state.overlays.append(&"pause")
	state.overlays.append(&"confirm")
	assert_str(String(state.top())).is_equal("confirm")


func test_a_new_state_is_idle() -> void:
	var state: ShellState = ShellState.new()
	assert_bool(state.transitioning).is_false()
	assert_bool(state.committed).is_false()
	assert_str(String(state.top())).is_empty()


func test_send_carries_the_name_and_args() -> void:
	var screen: FakeScreen = _screen()
	var rows: Array = _sent(screen)
	screen.send(&"pick", {"index": 1})
	assert_array(rows).is_equal([[&"pick", {"index": 1}]])


func test_cancel_sends_the_cancel_intent() -> void:
	var screen: FakeScreen = _screen()
	screen.cancel_intent = &"back"
	var rows: Array = _sent(screen)
	screen.handle_cancel()
	assert_array(rows).is_equal([[&"back", {}]])


func test_cancel_closes_a_drawer_first_and_sends_nothing() -> void:
	var screen: FakeScreen = _screen()
	screen.cancel_intent = &"open_pause"
	screen.drawer_open = true
	var rows: Array = _sent(screen)
	screen.handle_cancel()
	assert_array(rows).is_empty()
	assert_bool(screen.drawer_open).is_false()
	screen.handle_cancel()
	assert_int(rows.size()).is_equal(1)


func test_cancel_with_no_intent_sends_nothing() -> void:
	var screen: FakeScreen = _screen()
	var rows: Array = _sent(screen)
	screen.handle_cancel()
	assert_array(rows).is_empty()


func test_a_screen_with_no_landing_says_so() -> void:
	assert_bool(_screen().play_landing(0, 27, 0.1, false)).is_false()


func test_tab_entry_falls_back_to_the_default_focus() -> void:
	assert_object(_screen().tab_entry()).is_null()


func test_clear_frees_the_children_at_once() -> void:
	var screen: FakeScreen = _screen()
	screen.add_child(Label.new())
	screen.add_child(Label.new())
	screen.clear()
	assert_int(screen.get_child_count()).is_equal(0)


func test_modal_body_dims_with_the_backdrop_alpha() -> void:
	var screen: FakeScreen = _screen()
	var column: VBoxContainer = screen.modal_body(400.0)
	var dim: ColorRect = screen.get_child(0)
	assert_float(dim.color.a).is_equal(Screen.DIM_ALPHA)
	assert_object(column).is_not_null()
	assert_float((column.get_parent() as Control).custom_minimum_size.x).is_equal(400.0)
