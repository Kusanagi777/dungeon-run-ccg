## `ToastLayer` (run-ui U5, F3; AC-15, AC-16, AC-25, AC-32). The clock is driven by hand:
## `_process` is off, so a duration here is an exact number of milliseconds.
extends GdUnitTestSuite

const CFG: Dictionary = {
	"toast_base_ms": 5000, "toast_per_char_ms": 30, "toast_min_ms": 5000, "toast_max_ms": 8000,
	"toast_gap_ms": 150, "toast_queue_max": 8,
	"transition_ms": {"toast_in_out": 200}, "speed_factor": {"instant": 0, "fast": 0.5, "normal": 1.0},
	"reduce_motion_factor": 0.5, "run_start_ms": 600,
	"palette": {"decay": "#355E3B"},
}
const TEN_CHARS: String = "0123456789"

var _shown: Array = []


func _layer() -> ToastLayer:
	_shown = []
	var layer: ToastLayer = auto_free(ToastLayer.new())
	add_child(layer)
	layer.set_process(false)
	layer.configure(CFG)
	layer.set_idle(true)
	layer.shown.connect(func(kind: StringName, key: String) -> void: _shown.append([kind, key]))
	return layer


func _tick(layer: ToastLayer, ms: float) -> void:
	layer._process(ms / RunUiConfig.MS_PER_S)


func _press(layer: ToastLayer, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	layer._panel.gui_input.emit(event)


func test_a_queued_toast_waits_for_idle() -> void:
	var layer: ToastLayer = _layer()
	layer.set_idle(false)
	layer.enqueue(&"warning", {"title": TEN_CHARS})
	_tick(layer, 1000.0)
	assert_bool(layer.is_showing()).is_false()
	layer.set_idle(true)
	_tick(layer, 1.0)
	assert_bool(layer.is_showing()).is_true()


func test_a_toast_lasts_exactly_t_toast() -> void:
	var layer: ToastLayer = _layer()
	layer.enqueue(&"warning", {"title": TEN_CHARS})
	_tick(layer, 1.0)
	_tick(layer, 5299.0)
	assert_bool(layer.is_showing()).is_true()
	_tick(layer, 1.0)
	assert_bool(layer.is_showing()).is_false()


func test_a_long_toast_stops_at_the_cap() -> void:
	var layer: ToastLayer = _layer()
	layer.enqueue(&"warning", {"title": "x".repeat(200)})
	_tick(layer, 1.0)
	_tick(layer, 7999.0)
	assert_bool(layer.is_showing()).is_true()
	_tick(layer, 1.0)
	assert_bool(layer.is_showing()).is_false()


func test_title_and_subtitle_both_count_as_reading_time() -> void:
	var layer: ToastLayer = _layer()
	layer.enqueue(&"unlock", {"key": "k", "title": TEN_CHARS, "subtitle": TEN_CHARS})
	_tick(layer, 1.0)
	assert_float(layer._left_ms).is_equal(5600.0)


func test_hovering_two_seconds_ends_it_two_seconds_later_than_its_twin() -> void:
	# Arrange
	var layer: ToastLayer = _layer()
	layer.enqueue(&"warning", {"title": TEN_CHARS})
	_tick(layer, 1.0)

	# Act: 1 s, then hovered for 2 s, then away
	_tick(layer, 1000.0)
	layer._panel.mouse_entered.emit()
	_tick(layer, 2000.0)
	layer._panel.mouse_exited.emit()

	# Assert: 4300 ms remain, not 2300
	_tick(layer, 4299.0)
	assert_bool(layer.is_showing()).is_true()
	_tick(layer, 1.0)
	assert_bool(layer.is_showing()).is_false()


func test_an_lmb_hold_pauses_and_the_release_dismisses() -> void:
	# Arrange: U5 "hover (or an LMB hold) pauses; a click dismisses"
	var layer: ToastLayer = _layer()
	layer.enqueue(&"warning", {"title": TEN_CHARS})
	_tick(layer, 1.0)

	# Act
	_press(layer, true)
	_tick(layer, 6000.0)

	# Assert
	assert_bool(layer.is_showing()).is_true()
	_press(layer, false)
	assert_bool(layer.is_showing()).is_false()


func test_only_one_toast_shows_and_the_gap_holds_the_next() -> void:
	# Arrange
	var layer: ToastLayer = _layer()
	layer.enqueue(&"warning", {"title": "first"})
	layer.enqueue(&"warning", {"title": "second"})
	_tick(layer, 1.0)
	assert_int(layer.queued().size()).is_equal(1)

	# Act / Assert: t_toast, then the 150 ms gap
	_tick(layer, 8000.0)
	assert_bool(layer.is_showing()).is_false()
	_tick(layer, 149.0)
	_tick(layer, 0.0)
	assert_bool(layer.is_showing()).is_false()
	_tick(layer, 1.0)
	_tick(layer, 1.0)
	assert_bool(layer.is_showing()).is_true()
	assert_int(layer.queued().size()).is_equal(0)


func test_the_queue_drains_in_arrival_order() -> void:
	var layer: ToastLayer = _layer()
	for key: String in ["a", "b", "c"]:
		layer.enqueue(&"unlock", {"key": key, "title": key})
	for _i: int in 3:
		_tick(layer, 1.0)
		_tick(layer, 8000.0)
		_tick(layer, 200.0)
	assert_array(_shown).is_equal([[&"unlock", "a"], [&"unlock", "b"], [&"unlock", "c"]])


func test_a_showing_toast_outlives_the_shell_going_busy() -> void:
	# AC-32: idle governs when a toast starts, not when a showing one stops
	var layer: ToastLayer = _layer()
	layer.enqueue(&"unlock", {"key": "k", "title": TEN_CHARS})
	_tick(layer, 1.0)
	layer.set_idle(false)
	_tick(layer, 5299.0)
	assert_bool(layer.is_showing()).is_true()
	_tick(layer, 1.0)
	assert_bool(layer.is_showing()).is_false()


func test_ac16_two_over_the_cap_drops_the_two_oldest_warnings_and_keeps_the_unlock() -> void:
	# Arrange
	var layer: ToastLayer = _layer()
	var cap: int = int(CFG.toast_queue_max)

	# Act
	for i: int in cap + 2:
		layer.enqueue(&"warning", {"title": "w%d" % i})
	layer.enqueue(&"unlock", {"key": "u", "title": "unlock"})

	# Assert
	var titles: Array = layer.queued().map(func(row: Dictionary) -> String: return str(row.title))
	assert_array(titles).not_contains(["w0", "w1"])
	assert_array(titles).contains(["w2", "unlock"])
	assert_int(titles.size()).is_equal(cap + 1)


func test_an_unlock_is_never_dropped_even_over_the_cap() -> void:
	var layer: ToastLayer = _layer()
	var cap: int = int(CFG.toast_queue_max)
	for i: int in cap + 3:
		layer.enqueue(&"unlock", {"key": "k%d" % i, "title": "t"})
	assert_int(layer.queued().size()).is_equal(cap + 3)


func test_a_key_in_both_the_signal_and_the_queue_shows_once() -> void:
	var layer: ToastLayer = _layer()
	layer.enqueue(&"unlock", {"key": "same", "title": "t"})
	layer.enqueue(&"unlock", {"key": "same", "title": "t"})
	assert_int(layer.queued().size()).is_equal(1)
	_tick(layer, 1.0)
	layer.enqueue(&"unlock", {"key": "same", "title": "t"})
	assert_int(layer.queued().size()).is_equal(0)


func test_two_warnings_with_the_same_text_both_queue() -> void:
	var layer: ToastLayer = _layer()
	layer.enqueue(&"warning", {"title": "same"})
	layer.enqueue(&"warning", {"title": "same"})
	assert_int(layer.queued().size()).is_equal(2)


func test_a_toast_takes_no_focus() -> void:
	var layer: ToastLayer = _layer()
	layer.enqueue(&"unlock", {"key": "k", "title": "t"})
	_tick(layer, 1.0)
	assert_int(layer._panel.focus_mode).is_equal(Control.FOCUS_NONE)
	for node: Node in layer._panel.find_children("*", "Control", true, false):
		assert_int((node as Control).focus_mode).is_equal(Control.FOCUS_NONE)


func test_an_unlock_shows_title_subtitle_and_its_swatch() -> void:
	var layer: ToastLayer = _layer()
	layer.enqueue(&"unlock", {"key": "k", "title": "New hero", "subtitle": "Win 1 runs", "swatch": "decay"})
	_tick(layer, 1.0)
	assert_array(RunUiRig.texts(layer)).contains(["New hero", "Win 1 runs"])
	var chips: Array = layer.find_children("*", "ColorRect", true, false)
	assert_int(chips.size()).is_equal(1)
	assert_object((chips[0] as ColorRect).color).is_equal(Color.html("#355E3B"))


func test_a_warning_is_muted_and_has_no_swatch() -> void:
	var layer: ToastLayer = _layer()
	layer.enqueue(&"warning", {"title": "Careful"})
	_tick(layer, 1.0)
	var label: Label = layer.find_children("*", "Label", true, false)[0]
	assert_str(String(label.theme_type_variation)).is_equal(String(RunUiTheme.LABEL_MUTED))
	assert_array(layer.find_children("*", "ColorRect", true, false)).is_empty()


func test_the_toast_fades_in_at_normal_and_appears_at_once_at_instant() -> void:
	var layer: ToastLayer = _layer()
	layer.enqueue(&"warning", {"title": "t"})
	_tick(layer, 1.0)
	assert_float(layer._panel.modulate.a).is_equal(0.0)
	var quick: ToastLayer = _layer()
	quick.set_motion(RunUiConfig.SPEED_INSTANT, false)
	quick.enqueue(&"warning", {"title": "t"})
	_tick(quick, 1.0)
	assert_float(quick._panel.modulate.a).is_equal(1.0)
