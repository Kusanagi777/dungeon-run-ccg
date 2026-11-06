## The pause menu, concede and the `Esc` chain (match-ui O15, O19, U9, States `Menu`;
## ADR-0008 `concede_queued`; ADR-0011; story 019).
extends GdUnitTestSuite

const MENU_RECT := Rect2(440, 160, 400, 400)
const FRAME_S: float = 1.0 / 60.0
const AUTO_S: float = 4.5


## Keeps what every submit answered.
class ResultSpy:
	extends MatchController

	var results: Array[Dictionary] = []

	func _init(driver: MatchDriver) -> void:
		super(driver)

	func submit(command: Dictionary) -> Dictionary:
		var result: Dictionary = super(command)
		results.append(result)
		return result


func _open(fixture: String, settings: Dictionary = {}) -> MatchView:
	var view: MatchView = await MatchViewHarness.open(self, fixture, [], settings)
	MatchViewHarness.run(view, FRAME_S)
	return view


func _pause(view: MatchView) -> PauseMenu:
	return view.get("_pause")


func _confirm_yes(view: MatchView) -> void:
	_pause(view).call("_on_concede")


func test_o15_the_settings_sit_in_the_menu_rect_over_a_dimmed_live_match() -> void:
	# Arrange / Act
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player", ["--pose=menu:settings"])
	var menu: PauseMenu = _pause(view)

	# Assert
	assert_object((menu.get("_panel") as Control).get_global_rect()).is_equal(MENU_RECT)
	assert_array((menu.get("_sliders") as Dictionary).keys()).contains([PauseMenu.KEY_MASTER, PauseMenu.KEY_SFX])
	assert_array((menu.get("_speed_buttons") as Dictionary).keys()).contains_exactly(PauseMenu.SPEEDS)
	assert_object(menu.get("_reduce")).is_not_null()
	assert_object((view.get("_table") as ColorRect).color).is_equal(view.ui_context().color("table_dark"))
	assert_bool(view.hand().visible).is_true()
	MatchViewHarness.close(view)


func test_the_concede_pose_opens_the_confirm_with_cancel_focused() -> void:
	# Arrange / Act
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player", ["--pose=menu:concede"])
	var menu: PauseMenu = _pause(view)

	# Assert: a reflexive `Enter` is safe
	assert_bool((menu.get("_confirm") as Control).visible).is_true()
	assert_object(view.get_viewport().gui_get_focus_owner()).is_same(menu.get("_cancel"))
	MatchViewHarness.close(view)


func test_concede_confirmed_on_the_players_turn_ends_the_match_as_concede() -> void:
	# Arrange
	var view: MatchView = await _open("turn1_player")
	view.router().intent(InputRouter.INTENT_MENU)
	_pause(view).show_concede_confirm()

	# Act
	_confirm_yes(view)
	MatchViewHarness.settle(view)

	# Assert
	assert_str(str(view.view_state().result.reason)).is_equal(MatchRecords.REASON_CONCEDE)
	assert_str(String(view.router().view_state())).is_equal(String(InputRouter.STATE_ENDED))
	assert_str((view.find_child("Banner", true, false) as BannerPresenter).variant()).is_equal(BannerPresenter.VARIANT_CONCEDE)
	MatchViewHarness.close(view)


func test_cancel_in_the_confirm_goes_back_with_no_concede() -> void:
	# Arrange
	var view: MatchView = await _open("turn1_player")
	var sent: Array[Dictionary] = MatchViewHarness.spy_commands(view)
	view.router().intent(InputRouter.INTENT_MENU)
	_pause(view).show_concede_confirm()

	# Act
	(_pause(view).get("_cancel") as Button).pressed.emit()

	# Assert
	assert_array(sent).is_empty()
	assert_bool(_pause(view).is_open()).is_true()
	assert_bool((_pause(view).get("_main") as Control).visible).is_true()
	MatchViewHarness.close(view)


func test_concede_during_a_live_planner_is_queued_and_the_boss_plays_nothing_more() -> void:
	# Arrange: the boss's turn with its plan held open
	var gate: Dictionary = {"held": false}
	var boot: Node = MatchViewHarness.fresh_boot({"anim_speed": "normal"})
	var loader := MatchDebugLoader.new(MatchViewHarness.gated_planner(gate), boot)
	var live: MatchController = loader.load_fixture("turn1_player")
	var spy := ResultSpy.new(live.get("_driver"))
	var view: MatchView = await MatchViewHarness.open_controller(self, boot, spy, loader.match_info)
	MatchViewHarness.run(view, FRAME_S)
	gate.held = true
	MatchViewHarness.press_end_turn(view)
	MatchViewHarness.run(view, FRAME_S)
	var boss_events_before: int = _boss_acts(view)
	assert_bool(spy.is_planning()).is_true()

	# Act
	view.router().intent(InputRouter.INTENT_MENU)
	_pause(view).show_concede_confirm()
	_confirm_yes(view)
	var answer: Dictionary = spy.results.back()
	gate.held = false
	MatchViewHarness.settle(view)

	# Assert
	assert_bool(answer.accepted).is_false()
	assert_str(str(answer.rejection.code)).is_equal(str(RulesEngine.R_ENGINE_BUSY))
	assert_str(str(answer.rejection.detail)).is_equal(MatchDriver.DETAIL_CONCEDE_QUEUED)
	assert_str(str(view.view_state().result.reason)).is_equal(MatchRecords.REASON_CONCEDE)
	assert_int(_boss_acts(view)).is_equal(boss_events_before)
	MatchViewHarness.close(view)


func _boss_acts(view: MatchView) -> int:
	var count: int = 0
	for type: String in MatchViewHarness.event_types(view):
		if type in ["card_played", "attack_declared", "hero_power_used"]:
			count += 1
	return count


func test_a_queued_concede_shows_no_rejection() -> void:
	# Arrange
	var gate: Dictionary = {"held": false}
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player", [], {"anim_speed": "normal"}, MatchViewHarness.gated_planner(gate))
	MatchViewHarness.run(view, FRAME_S)
	gate.held = true
	MatchViewHarness.press_end_turn(view)
	MatchViewHarness.run(view, FRAME_S)

	# Act
	view.router().intent(InputRouter.INTENT_CONCEDE)
	MatchViewHarness.run(view, FRAME_S)

	# Assert: it is not a refusal: no event, so no tooltip and no deny cue
	assert_bool(view.sfx.played(SfxStub.CUE_DENY)).is_false()
	assert_bool(((view.get("_reject") as RejectPresenter).get("_tooltip") as Control).visible).is_false()
	gate.held = false
	MatchViewHarness.settle(view)
	MatchViewHarness.close(view)


func test_o19_esc_over_the_choice_opens_the_menu_above_it_with_the_options_unchanged() -> void:
	# Arrange
	var view: MatchView = await _open("choice_discover")
	var options: Array = (view.view_state().pending_choice.options as Array).duplicate()
	view.choice().handle_action(MatchInput.HAND, 1)

	# Act
	MatchViewHarness.action(view, &"ui_cancel")

	# Assert
	assert_bool(_pause(view).is_open()).is_true()
	assert_bool(view.choice().is_open()).is_true()
	assert_array(view.view_state().pending_choice.options).is_equal(options)
	assert_int(view.choice().selected()).is_equal(1)
	assert_int(_pause(view).z_index).is_greater(view.choice().z_index)
	MatchViewHarness.close(view)


func test_o19_esc_again_closes_the_menu_and_gives_the_overlay_back() -> void:
	# Arrange
	var view: MatchView = await _open("choice_discover")
	MatchViewHarness.action(view, &"ui_cancel")

	# Act
	MatchViewHarness.action(view, &"ui_cancel")

	# Assert
	assert_bool(_pause(view).is_open()).is_false()
	assert_str(String(view.router().view_state())).is_equal(String(InputRouter.STATE_CHOICE_OPEN))
	assert_object((view.get("_table") as ColorRect).color).is_equal(view.ui_context().color("table_dark"))
	MatchViewHarness.close(view)


func test_o19_esc_over_the_mulligan_opens_the_menu_and_esc_closes_it() -> void:
	# Arrange
	var view: MatchView = await _open("mulligan")

	# Act
	MatchViewHarness.action(view, &"ui_cancel")
	var opened: bool = _pause(view).is_open()
	MatchViewHarness.action(view, &"ui_cancel")

	# Assert
	assert_bool(opened).is_true()
	assert_bool(_pause(view).is_open()).is_false()
	assert_bool(view.mulligan().is_open()).is_true()
	MatchViewHarness.close(view)


func test_the_keys_of_the_screen_under_the_menu_are_dead_while_it_is_up() -> void:
	# Arrange
	var view: MatchView = await _open("mulligan")
	MatchViewHarness.action(view, &"ui_cancel")

	# Act
	MatchViewHarness.action(view, &"hand_1")

	# Assert: the state is `Menu`, so the toggle never lands
	assert_array(view.mulligan().keep_mask()).is_equal([true, true, true])
	MatchViewHarness.close(view)


func test_esc_chain_session_then_drawer_then_menu_in_the_view() -> void:
	# Arrange
	var view: MatchView = await _open("treasure_tray")
	view.feed().open()
	view.router().on_action(MatchInput.HERO_POWER)

	# Act / Assert
	MatchViewHarness.action(view, &"ui_cancel")
	assert_bool(view.router().in_session()).is_false()
	assert_bool(view.feed().is_open()).is_true()
	MatchViewHarness.action(view, &"ui_cancel")
	assert_bool(view.feed().is_open()).is_false()
	assert_bool(_pause(view).is_open()).is_false()
	MatchViewHarness.action(view, &"ui_cancel")
	assert_bool(_pause(view).is_open()).is_true()
	MatchViewHarness.close(view)


func test_opening_the_menu_with_the_button_cancels_a_session() -> void:
	# Arrange
	var view: MatchView = await _open("treasure_tray")
	view.router().on_action(MatchInput.HERO_POWER)

	# Act
	(view.get("_menu_button") as Button).pressed.emit()

	# Assert
	assert_bool(view.router().in_session()).is_false()
	assert_bool(_pause(view).is_open()).is_true()
	MatchViewHarness.close(view)


func test_rmb_never_opens_the_menu_in_the_view() -> void:
	# Arrange
	var view: MatchView = await _open("turn1_player")

	# Act
	MatchViewHarness.click(view, Vector2(640, 360), MOUSE_BUTTON_RIGHT)

	# Assert
	assert_bool(_pause(view).is_open()).is_false()
	MatchViewHarness.close(view)


func test_playback_keeps_running_under_the_menu() -> void:
	# Arrange
	var view: MatchView = await _open("turn1_player", {"anim_speed": "normal"})
	MatchViewHarness.press_end_turn(view)
	MatchViewHarness.run(view, FRAME_S)
	view.router().intent(InputRouter.INTENT_MENU)
	var finished: Array[int] = []
	view.queue().step_finished.connect(func(_step: AnimStep) -> void: finished.append(1))

	# Act
	MatchViewHarness.run(view, 1.0)

	# Assert
	assert_bool(_pause(view).is_open()).is_true()
	assert_array(finished).is_not_empty()
	MatchViewHarness.close(view)


func test_is_open_and_visible_part_ways_while_a_closed_menu_fades() -> void:
	# Arrange: `visible` runs on through the fade, and only `is_open` says the menu is up
	var view: MatchView = await _open("turn1_player", {"anim_speed": "normal"})
	view.router().intent(InputRouter.INTENT_MENU)
	_pause(view).finish_motion()

	# Act
	_pause(view).back()

	# Assert
	assert_bool(_pause(view).is_open()).is_false()
	assert_bool(_pause(view).visible).is_true()
	assert_object((view.get("_table") as ColorRect).color).is_equal(view.ui_context().color("table_lit"))
	assert_str(String(view.router().view_state())).is_equal(String(InputRouter.STATE_IDLE))
	_pause(view).finish_motion()
	assert_bool(_pause(view).visible).is_false()
	MatchViewHarness.close(view)


func test_esc_during_the_fade_opens_the_menu_again_and_it_stays_open() -> void:
	# Arrange
	var view: MatchView = await _open("turn1_player", {"anim_speed": "normal"})
	view.router().intent(InputRouter.INTENT_MENU)
	_pause(view).finish_motion()
	_pause(view).back()

	# Act
	MatchViewHarness.action(view, &"ui_cancel")
	_pause(view).finish_motion()

	# Assert
	assert_bool(_pause(view).is_open()).is_true()
	assert_bool(_pause(view).visible).is_true()
	MatchViewHarness.close(view)


func test_a_settings_change_is_written_through_meta_and_comes_back_on_the_bus() -> void:
	# Arrange
	var view: MatchView = await _open("turn1_player")
	var stub: MetaStub = MatchViewHarness.meta(view)
	view.router().intent(InputRouter.INTENT_MENU)
	var fast: Button = (_pause(view).get("_speed_buttons") as Dictionary)["fast"]

	# Act
	fast.pressed.emit()

	# Assert
	assert_str(str(stub.get_setting(&"anim_speed"))).is_equal("fast")
	assert_str(String(view.get("_speed"))).is_equal("fast")
	assert_float(view.queue().effective_duration(AnimStep.new(AnimStep.TURN_BANNER, [], 0.4, 1, 1))).is_equal_approx(0.2, 0.001)
	MatchViewHarness.close(view)


func test_opening_the_menu_writes_nothing() -> void:
	# Arrange
	var view: MatchView = await _open("turn1_player")
	var stub: MetaStub = MatchViewHarness.meta(view)
	var calls_before: int = stub.calls.size()

	# Act: the controls take the stored values with no write of their own
	view.router().intent(InputRouter.INTENT_MENU)

	# Assert
	assert_int(stub.calls.size()).is_equal(calls_before)
	MatchViewHarness.close(view)


func test_the_menu_motion_follows_the_views_speed() -> void:
	# Arrange
	var view: MatchView = await _open("turn1_player", {"anim_speed": "fast"})

	# Act
	view.router().intent(InputRouter.INTENT_MENU)

	# Assert: `overlay_open` at `fast`
	assert_float(float(_pause(view).get("_open_s"))).is_equal_approx(0.1, 0.001)
	MatchViewHarness.close(view)


func test_reduce_motion_opens_the_menu_with_no_scale() -> void:
	# Arrange
	var view: MatchView = await _open("turn1_player", {"anim_speed": "normal", "reduce_motion": true})

	# Act
	view.router().intent(InputRouter.INTENT_MENU)

	# Assert
	assert_float(float(_pause(view).get("_scale_from"))).is_equal(1.0)
	MatchViewHarness.close(view)
