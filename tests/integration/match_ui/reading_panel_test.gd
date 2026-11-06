## Card Inspect's reading panel (hand.md §5.1; hud.md §10.2): shown from 125 % text, beside the
## preview and toward the screen centre, bottom edge held, taking no input.
extends GdUnitTestSuite

const MID_SCALE: float = 1.25
const FULL_SCALE: float = 1.5
const FACE_WITH_TEXT: String = "war_sharpen"
## A preview left of centre and one right of it.
const PREVIEW_LEFT := Rect2(100, 300, 225, 315)
const PREVIEW_RIGHT := Rect2(900, 300, 225, 315)
const PREVIEW_FAR_RIGHT := Rect2(1040, 300, 225, 315)


func _panel(view: MatchView, scale: float) -> ReadingPanel:
	var panel: ReadingPanel = view.get("_reading")
	panel.set_scale_factor(scale)
	return panel


func _face(view: MatchView) -> Dictionary:
	return view.ui_context().card_face(FACE_WITH_TEXT)


func test_below_125_percent_no_panel_shows() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player")
	var panel: ReadingPanel = _panel(view, 1.0)

	# Act
	panel.show_face(_face(view), PREVIEW_LEFT)

	# Assert
	assert_bool(panel.visible).is_false()
	MatchViewHarness.close(view)


func test_from_125_percent_it_stands_right_of_a_preview_left_of_centre() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player")
	var panel: ReadingPanel = _panel(view, MID_SCALE)
	var cfg: Dictionary = view.ui_context().config.text_scale.reading

	# Act
	panel.show_face(_face(view), PREVIEW_LEFT)

	# Assert
	assert_bool(panel.visible).is_true()
	assert_float(panel.position.x).is_equal(PREVIEW_LEFT.end.x + float(cfg.gap))
	assert_float(panel.size.x).is_equal(float(cfg.w))
	MatchViewHarness.close(view)


func test_it_stands_left_of_a_preview_right_of_centre() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player")
	var panel: ReadingPanel = _panel(view, FULL_SCALE)
	var cfg: Dictionary = view.ui_context().config.text_scale.reading

	# Act
	panel.show_face(_face(view), PREVIEW_RIGHT)

	# Assert
	assert_float(panel.position.x).is_equal(PREVIEW_RIGHT.position.x - float(cfg.gap) - float(cfg.w))
	MatchViewHarness.close(view)


func test_its_edges_clamp_to_the_configured_band() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player")
	var panel: ReadingPanel = _panel(view, FULL_SCALE)
	var cfg: Dictionary = view.ui_context().config.text_scale.reading

	# Act
	panel.show_face(_face(view), Rect2(700, 300, 225, 315))
	var from_right: float = panel.position.x
	panel.show_face(_face(view), Rect2(560, 300, 225, 315).grow_individual(0, 0, -10, 0))
	var from_centre: float = panel.position.x
	panel.show_face(_face(view), Rect2(-400, 300, 225, 315))

	# Assert
	assert_float(from_right).is_greater_equal(float(cfg.left_min_x))
	assert_float(from_centre).is_less_equal(float(cfg.right_max_x))
	assert_float(panel.position.x).is_less_equal(float(cfg.right_max_x))
	MatchViewHarness.close(view)


func test_its_bottom_edge_holds_at_the_configured_line_whatever_its_height() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player")
	var panel: ReadingPanel = _panel(view, FULL_SCALE)
	var cfg: Dictionary = view.ui_context().config.text_scale.reading

	# Act
	panel.show_face(_face(view), PREVIEW_LEFT)
	await MatchViewHarness.frames(view)

	# Assert
	assert_float(panel.position.y + panel.size.y).is_equal_approx(float(cfg.bottom_y), 1.0)
	assert_float(panel.size.y).is_less_equal(float(cfg.max_h))
	MatchViewHarness.close(view)


func test_it_takes_no_input_and_draws_over_the_hand() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player")
	var panel: ReadingPanel = _panel(view, FULL_SCALE)

	# Act / Assert
	assert_int(panel.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_int(panel.z_index).is_greater(HandPresenter.DRAG_Z)
	MatchViewHarness.close(view)


func test_scaling_back_under_125_percent_hides_an_open_panel() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player")
	var panel: ReadingPanel = _panel(view, FULL_SCALE)
	panel.show_face(_face(view), PREVIEW_LEFT)

	# Act
	panel.set_scale_factor(1.0)

	# Assert
	assert_bool(panel.visible).is_false()
	MatchViewHarness.close(view)


func test_a_face_with_nothing_to_read_shows_no_panel() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player")
	var panel: ReadingPanel = _panel(view, FULL_SCALE)

	# Act
	panel.show_face({}, PREVIEW_LEFT)

	# Assert
	assert_bool(panel.visible).is_false()
	MatchViewHarness.close(view)


func test_focusing_a_hand_card_at_150_percent_opens_it_beside_the_preview() -> void:
	# Arrange / Act
	var view: MatchView = await MatchViewHarness.open(self, "treasure_tray_ts150", ["--pose=focus:0"])
	var panel: ReadingPanel = view.get("_reading")
	var preview: Rect2 = view.hand().preview_rect(MatchViewHarness.hand_id(view, 0))

	# Assert: card 0 is left of centre, so the panel takes its right
	assert_bool(panel.visible).is_true()
	assert_float(panel.position.x).is_greater_equal(preview.end.x)
	MatchViewHarness.close(view)


func test_leaving_idle_hides_it() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "treasure_tray_ts150", ["--pose=focus:0"], {"anim_speed": "normal"})
	var panel: ReadingPanel = view.get("_reading")
	MatchViewHarness.run(view, MatchViewHarness.FRAME_S)
	var before: bool = panel.visible

	# Act
	MatchViewHarness.press_end_turn(view)
	MatchViewHarness.run(view, MatchViewHarness.FRAME_S)

	# Assert
	assert_bool(before).is_true()
	assert_bool(panel.visible).is_false()
	view.queue().skip_all()
	MatchViewHarness.close(view)


func test_a_card_on_the_far_right_keeps_its_panel_on_screen() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player")
	var panel: ReadingPanel = _panel(view, FULL_SCALE)

	# Act
	panel.show_face(_face(view), PREVIEW_FAR_RIGHT)

	# Assert
	assert_float(panel.position.x + panel.size.x).is_less_equal(view.ui_context().rect("viewport").size.x)
	MatchViewHarness.close(view)
