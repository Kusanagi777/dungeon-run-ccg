## Live settings, text scale, gamma and the frame (match-ui O16, U11 settings variants; hud.md
## §10; ADR-0011; story 020 AC-1, AC-3, AC-4). "No text clips" on every `_ts150` capture and
## the pixels of a letterboxed frame are judged by eye from captures: this suite pins the
## geometry that makes them true.
extends GdUnitTestSuite

const GAMMA_LOW: float = 0.8
const GAMMA_HIGH: float = 1.4
const SCALE_FULL: float = 1.5
const SCALE_MID: float = 1.25
const BOSS_MANA_MOVED := Rect2(1196, 152, 56, 24)
const PLATE_RIGHT: float = 1256.0
const BASE_FONT_PX: int = 16
const VIEWPORT := Vector2i(1280, 720)


func _change(view: MatchView, key: StringName, value: Variant) -> void:
	assert_int(MatchViewHarness.meta(view).set_setting(key, value)).is_equal(OK)


func _gamma(view: MatchView) -> CanvasModulate:
	return view.find_child("Gamma", true, false)


func test_gamma_changes_the_one_canvas_modulate_and_no_token() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player")
	var tokens: Dictionary = (view.ui_context().get("_colors") as Dictionary).duplicate()

	# Act / Assert
	for value: float in [GAMMA_LOW, GAMMA_HIGH]:
		_change(view, &"gamma", value)
		assert_object(_gamma(view).color).is_equal(Color(value, value, value))
		assert_dict(view.ui_context().get("_colors")).is_equal(tokens)
	assert_int(view.find_children("*", "CanvasModulate", true, false).size()).is_equal(1)
	MatchViewHarness.close(view)


func test_a_gamma_from_the_profile_is_applied_at_launch() -> void:
	# Arrange / Act
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player", [], {"gamma": GAMMA_HIGH})

	# Assert
	assert_object(_gamma(view).color).is_equal(Color(GAMMA_HIGH, GAMMA_HIGH, GAMMA_HIGH))
	MatchViewHarness.close(view)


func test_every_read_setting_reaches_the_hud_on_its_change() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player")
	var step := AnimStep.new(AnimStep.TURN_BANNER, [], 0.4, 1, 1)
	step.impact = {"hit_stop_ms": 60}

	# Act
	_change(view, &"anim_speed", "normal")
	var at_normal: Dictionary = view.queue().effective_impact(step)
	_change(view, &"reduce_motion", true)
	var reduced: Dictionary = view.queue().effective_impact(step)
	_change(view, &"action_delay_ms", 1000)

	# Assert
	assert_int(int(at_normal.hit_stop_ms)).is_equal(60)
	assert_int(int(reduced.hit_stop_ms)).is_equal(0)
	assert_float(float((view.get("_boss_pacing") as Dictionary).ai_action_delay_s)).is_equal(1.0)
	assert_bool((view.get("_reject") as RejectPresenter).reduce_motion).is_true()
	MatchViewHarness.close(view)


func test_a_setting_the_view_does_not_read_changes_nothing_on_screen() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player")
	var before: StringName = view.get("_speed")

	# Act
	_change(view, &"volume_master", 0.5)

	# Assert
	assert_str(String(view.get("_speed"))).is_equal(String(before))
	MatchViewHarness.close(view)


func test_text_scale_is_absolute_and_a_second_change_never_compounds() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player")
	var label: Label = (view.find_child("PlayerPanel", true, false) as HeroPresenter).get("_health")
	var base: int = label.get_theme_font_size(&"font_size")

	# Act
	_change(view, &"text_scale", SCALE_FULL)
	_change(view, &"text_scale", SCALE_MID)
	_change(view, &"text_scale", SCALE_FULL)
	var scaled: int = label.get_theme_font_size(&"font_size")
	_change(view, &"text_scale", 1.0)

	# Assert
	assert_int(scaled).is_equal(roundi(base * SCALE_FULL))
	assert_int(label.get_theme_font_size(&"font_size")).is_equal(base)
	assert_int(view.theme.default_font_size).is_equal(BASE_FONT_PX)
	MatchViewHarness.close(view)


func test_cards_and_tokens_keep_their_fixed_slots_at_any_scale() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "midgame_full_board")
	var stamp: Label = (view.find_children("*", "MinionToken", true, false)[0] as MinionToken).get("_attack")
	var card_cost: Label = view.hand().card(MatchViewHarness.hand_id(view, 0)).get("_cost_text")
	var token_px: int = stamp.get_theme_font_size(&"font_size")
	var card_px: int = card_cost.get_theme_font_size(&"font_size")

	# Act
	_change(view, &"text_scale", SCALE_FULL)

	# Assert
	assert_int(stamp.get_theme_font_size(&"font_size")).is_equal(token_px)
	assert_int(card_cost.get_theme_font_size(&"font_size")).is_equal(card_px)
	MatchViewHarness.close(view)


func test_ts150_moves_the_boss_mana_into_the_portrait_and_the_strip_holds_the_count() -> void:
	# Arrange / Act
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player_ts150")
	var boss: HeroPresenter = view.find_child("BossPanel", true, false)
	var mana: Control = (boss.get("_mana_text") as Control).get_parent()
	var hand: Control = boss.get("_hand_box")
	var base: Rect2 = view.ui_context().rect("boss_hand_count")

	# Assert
	assert_object(mana.get_global_rect()).is_equal(BOSS_MANA_MOVED)
	assert_float(hand.get_global_rect().size.x).is_equal(base.size.x + view.ui_context().rect("boss_mana").size.x)
	MatchViewHarness.close(view)


func test_ts150_grows_the_intent_plate_left_with_its_right_edge_fixed() -> void:
	# Arrange / Act
	var view: MatchView = await MatchViewHarness.open(self, "boss_intent_full_ts150")
	MatchViewHarness.run(view, MatchViewHarness.FRAME_S)
	var plate: Rect2 = (view.find_child("IntentBanner", true, false) as IntentBanner).plate_rect()
	var floor_x: float = float(view.ui_context().config.text_scale.intent_min_x)

	# Assert
	assert_float(plate.end.x).is_equal(PLATE_RIGHT)
	assert_float(plate.position.x).is_less_equal(view.ui_context().rect("intent_banner").position.x)
	assert_float(plate.position.x).is_greater_equal(floor_x)
	MatchViewHarness.close(view)


func test_a_scale_back_to_100_puts_the_boss_mana_home() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player_ts150")
	var boss: HeroPresenter = view.find_child("BossPanel", true, false)
	var mana: Control = (boss.get("_mana_text") as Control).get_parent()

	# Act
	_change(view, &"text_scale", 1.0)

	# Assert
	assert_object(mana.get_global_rect()).is_equal(view.ui_context().rect("boss_mana"))
	MatchViewHarness.close(view)


func test_ts150_keeps_two_ticker_lines_and_widens_the_drawer() -> void:
	# Arrange / Act
	var view: MatchView = await MatchViewHarness.open(self, "fatigue_and_burn_ts150")
	var cfg: Dictionary = view.ui_context().config.text_scale

	# Assert
	assert_int(int(view.feed().get("_ticker_count"))).is_equal(int(cfg.feed_ticker_lines))
	assert_float((view.feed().get("_drawer") as Control).size.x).is_equal(float(cfg.feed_drawer_w))
	MatchViewHarness.close(view)


func test_end_turn_grows_to_its_cap_with_its_right_edge_fixed() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player")
	var button: Button = view.get("_end_turn")
	var right: float = button.get_global_rect().end.x

	# Act
	_change(view, &"text_scale", SCALE_FULL)

	# Assert: 140 x 1.5 is 210, past the cap of 200
	assert_float(button.size.x).is_equal(float(view.ui_context().config.text_scale.end_turn_max_w))
	assert_float(button.get_global_rect().end.x).is_equal(right)
	MatchViewHarness.close(view)


func test_a_rebuilt_label_after_the_change_takes_the_scale_on_the_next_drain() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player")
	_change(view, &"text_scale", SCALE_FULL)
	var fresh := Label.new()
	fresh.add_theme_font_size_override(&"font_size", BASE_FONT_PX)
	view.add_child(fresh)

	# Act
	view.call("_on_drained")

	# Assert
	assert_int(fresh.get_theme_font_size(&"font_size")).is_equal(roundi(BASE_FONT_PX * SCALE_FULL))
	MatchViewHarness.close(view)


func test_o16_the_project_scales_the_1280x720_grid_uniformly_and_letterboxes() -> void:
	# Arrange / Act
	var width: int = ProjectSettings.get_setting("display/window/size/viewport_width")
	var height: int = ProjectSettings.get_setting("display/window/size/viewport_height")
	var mode: String = ProjectSettings.get_setting("display/window/stretch/mode")
	var aspect: String = ProjectSettings.get_setting("display/window/stretch/aspect")

	# Assert: `canvas_items` with `keep` is what makes 1920x1080 and 1024x768 one grid
	assert_object(Vector2i(width, height)).is_equal(VIEWPORT)
	assert_str(mode).is_equal("canvas_items")
	assert_str(aspect).is_equal("keep")


func test_o16_every_f6_zone_lies_inside_the_grid() -> void:
	# Arrange
	var layout: Dictionary = MatchUiTestConfig.shipped().layout
	var grid := Rect2(Vector2.ZERO, Vector2(VIEWPORT))

	# Act / Assert
	for zone: String in layout:
		var r: Array = layout[zone]
		assert_bool(grid.encloses(Rect2(r[0], r[1], r[2], r[3]))).override_failure_message(zone).is_true()
