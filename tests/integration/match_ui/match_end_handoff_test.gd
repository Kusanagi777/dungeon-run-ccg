## The end banner, `Ended` and the handoff (match-ui O13, O19, U9; match-end.md §6; ADR-0008
## Decision 8; story 011).
extends GdUnitTestSuite

const BANNER_RECT := Rect2(340, 260, 600, 200)
const ARM_S: float = 0.3
const AUTO_S: float = 4.0
const FRAME_S: float = 1.0 / 60.0
## The saturate ramp is a real tween of 0.4 s.
const RAMP_WAIT_MS: int = 500


func _banner(view: MatchView) -> BannerPresenter:
	return view.find_child("Banner", true, false)


func _spy_finished(view: MatchView) -> Array[Dictionary]:
	var got: Array[Dictionary] = []
	view.match_view_finished.connect(func(result: Dictionary) -> void: got.append(result))
	return got


func _open(fixture: String) -> MatchView:
	var view: MatchView = await MatchViewHarness.open(self, fixture)
	MatchViewHarness.settle(view)
	return view


func test_o13_each_ending_carries_its_own_copy_in_the_banner_rect() -> void:
	for pair: Array in [
		["match_end_victory", BannerPresenter.VARIANT_VICTORY], ["match_end_defeat", BannerPresenter.VARIANT_DEFEAT],
		["match_end_both_dead", BannerPresenter.VARIANT_BOTH_DEAD], ["match_end_concede", BannerPresenter.VARIANT_CONCEDE],
		["match_end_fault", BannerPresenter.VARIANT_FAULT],
	]:
		# Arrange / Act
		var view: MatchView = await _open(pair[0])
		var banner: BannerPresenter = _banner(view)

		# Assert
		assert_bool(banner.is_shown()).override_failure_message(pair[0]).is_true()
		assert_str(banner.variant()).override_failure_message(pair[0]).is_equal(pair[1])
		assert_str((banner.get("_title") as Label).text).is_equal(tr("end.%s.title" % pair[1]))
		assert_object((banner.get("_panel") as Control).get_global_rect()).is_equal(BANNER_RECT)
		MatchViewHarness.close(view)


func test_the_fault_copy_is_replayed_not_lost_on_a_neutral_frame() -> void:
	# Arrange / Act
	var view: MatchView = await _open("match_end_fault")
	var banner: BannerPresenter = _banner(view)
	var style: StyleBoxFlat = banner.get("_style")

	# Assert
	assert_str((banner.get("_line") as Label).text.to_lower()).contains("replayed")
	assert_object(style.border_color).is_equal(view.ui_context().color("text_muted"))
	MatchViewHarness.close(view)


func test_a_fault_plays_no_defeat_sting_and_no_victory_sting() -> void:
	# Arrange / Act
	var view: MatchView = await _open("match_end_fault")

	# Assert
	assert_bool(view.sfx.played(SfxStub.CUE_DEFEAT)).is_false()
	assert_bool(view.sfx.played(SfxStub.CUE_VICTORY)).is_false()
	MatchViewHarness.close(view)


func test_a_defeat_plays_the_defeat_sting_and_a_win_the_victory_one() -> void:
	# Arrange / Act
	var lost: MatchView = await _open("match_end_defeat")
	var won: MatchView = await _open("match_end_victory")

	# Assert
	assert_bool(lost.sfx.played(SfxStub.CUE_DEFEAT)).is_true()
	assert_bool(won.sfx.played(SfxStub.CUE_VICTORY)).is_true()
	assert_bool(won.sfx.played(SfxStub.CUE_DEFEAT)).is_false()
	MatchViewHarness.close(lost)
	MatchViewHarness.close(won)


func test_the_winner_saturates_to_its_primary_and_the_loser_stays_dim() -> void:
	# Arrange
	var view: MatchView = await _open("match_end_victory")
	var player: HeroPresenter = view.find_child("PlayerPanel", true, false)
	var boss: HeroPresenter = view.find_child("BossPanel", true, false)
	var boss_fill: Color = (boss.get("_portrait_style") as StyleBoxFlat).bg_color

	# Act
	await await_millis(RAMP_WAIT_MS)

	# Assert
	assert_object((player.get("_portrait_style") as StyleBoxFlat).bg_color).is_equal(player.get("_primary"))
	assert_object((boss.get("_portrait_style") as StyleBoxFlat).bg_color).is_equal(boss_fill)
	MatchViewHarness.close(view)


func test_a_fault_saturates_neither_portrait() -> void:
	# Arrange
	var view: MatchView = await _open("match_end_fault")
	var player: HeroPresenter = view.find_child("PlayerPanel", true, false)
	var boss: HeroPresenter = view.find_child("BossPanel", true, false)

	# Act
	await await_millis(RAMP_WAIT_MS)

	# Assert
	assert_object((player.get("_portrait_style") as StyleBoxFlat).bg_color).is_not_equal(player.get("_primary"))
	assert_object((boss.get("_portrait_style") as StyleBoxFlat).bg_color).is_not_equal(boss.get("_primary"))
	MatchViewHarness.close(view)


func test_ended_takes_no_command() -> void:
	# Arrange
	var view: MatchView = await _open("match_end_victory")
	var sent: Array[Dictionary] = MatchViewHarness.spy_commands(view)

	# Act
	view.router().intent(InputRouter.INTENT_END_TURN)
	view.router().intent(InputRouter.INTENT_CONCEDE)
	MatchViewHarness.press_end_turn(view)

	# Assert
	assert_str(String(view.router().view_state())).is_equal(String(InputRouter.STATE_ENDED))
	assert_array(sent).is_empty()
	MatchViewHarness.close(view)


func test_the_view_finishes_once_on_its_own_after_match_end_auto_s() -> void:
	# Arrange
	var view: MatchView = await _open("match_end_victory")
	var finished: Array[Dictionary] = _spy_finished(view)

	# Act
	MatchViewHarness.run(view, AUTO_S - FRAME_S * 2.0)
	var early: int = finished.size()
	MatchViewHarness.run(view, FRAME_S * 3.0)
	MatchViewHarness.run(view, AUTO_S)

	# Assert
	assert_int(early).is_equal(0)
	assert_int(finished.size()).is_equal(1)
	assert_str(str(finished[0].result)).is_equal("win")
	MatchViewHarness.close(view)


func test_a_click_after_the_guard_finishes_at_once_and_a_second_does_nothing() -> void:
	# Arrange
	var view: MatchView = await _open("match_end_victory")
	var finished: Array[Dictionary] = _spy_finished(view)
	MatchViewHarness.run(view, ARM_S + FRAME_S)

	# Act
	MatchViewHarness.click(view, Vector2(640, 360))
	MatchViewHarness.click(view, Vector2(640, 360))
	MatchViewHarness.run(view, AUTO_S)

	# Assert
	assert_int(finished.size()).is_equal(1)
	MatchViewHarness.close(view)


func test_enter_after_the_guard_finishes() -> void:
	# Arrange
	var view: MatchView = await _open("match_end_defeat")
	var finished: Array[Dictionary] = _spy_finished(view)
	MatchViewHarness.run(view, ARM_S + FRAME_S)

	# Act
	MatchViewHarness.action(view, &"ui_accept")

	# Assert
	assert_int(finished.size()).is_equal(1)
	MatchViewHarness.close(view)


func test_a_skip_burst_inside_the_guard_cannot_dismiss_the_banner() -> void:
	# Arrange
	var view: MatchView = await _open("match_end_victory")
	var finished: Array[Dictionary] = _spy_finished(view)

	# Act
	MatchViewHarness.click(view, Vector2(640, 360))
	MatchViewHarness.action(view, &"skip")

	# Assert
	assert_array(finished).is_empty()
	MatchViewHarness.close(view)


func test_the_countdown_ignores_anim_speed() -> void:
	# Arrange: reading time is never divided
	var view: MatchView = await MatchViewHarness.open(self, "match_end_victory", [], {"anim_speed": "fast"})
	MatchViewHarness.settle(view)
	var finished: Array[Dictionary] = _spy_finished(view)

	# Act
	MatchViewHarness.run(view, AUTO_S / 2.0)

	# Assert
	assert_array(finished).is_empty()
	MatchViewHarness.close(view)


func test_o19_esc_in_ended_changes_nothing_and_no_menu_opens() -> void:
	# Arrange
	var view: MatchView = await _open("match_end_victory")
	var pause: PauseMenu = view.get("_pause")

	# Act
	MatchViewHarness.action(view, &"ui_cancel")
	view.router().intent(InputRouter.INTENT_MENU)

	# Assert
	assert_str(String(view.router().view_state())).is_equal(String(InputRouter.STATE_ENDED))
	assert_bool(pause.is_open()).is_false()
	assert_bool(pause.visible).is_false()
	assert_bool((view.get("_menu_button") as Button).disabled).is_true()
	MatchViewHarness.close(view)


func test_rmb_in_ended_closes_an_open_drawer_and_opens_nothing_else() -> void:
	# Arrange
	var view: MatchView = await _open("match_end_victory")
	view.feed().open()

	# Act
	MatchViewHarness.click(view, Vector2(640, 360), MOUSE_BUTTON_RIGHT)

	# Assert
	assert_bool(view.feed().is_open()).is_false()
	assert_bool((view.get("_pause") as PauseMenu).is_open()).is_false()
	MatchViewHarness.close(view)


func test_the_feed_key_still_works_in_ended_and_does_not_finish_the_view() -> void:
	# Arrange
	var view: MatchView = await _open("match_end_victory")
	var finished: Array[Dictionary] = _spy_finished(view)
	MatchViewHarness.run(view, ARM_S + FRAME_S)

	# Act
	MatchViewHarness.action(view, &"feed_toggle")

	# Assert
	assert_bool(view.feed().is_open()).is_true()
	assert_array(finished).is_empty()
	MatchViewHarness.close(view)


func test_a_menu_open_when_the_match_ends_closes_with_the_drain() -> void:
	# Arrange: the end reaches a player who has the menu up
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player", [], {"anim_speed": "normal"})
	MatchViewHarness.run(view, FRAME_S)
	var pause: PauseMenu = view.get("_pause")
	view.router().intent(InputRouter.INTENT_MENU)
	var opened: bool = pause.is_open()

	# Act
	MatchViewHarness.inject(view, "match_ended", {"result": "win", "winner": "player", "reason": "hero_dead", "turns": 3, "final_health": {"player": 30, "boss": 0}})
	MatchViewHarness.settle(view)

	# Assert: nothing but the banner is left to read
	assert_bool(opened).is_true()
	assert_bool(pause.is_open()).is_false()
	assert_str(String(view.router().view_state())).is_equal(String(InputRouter.STATE_ENDED))
	assert_bool(_banner(view).is_shown()).is_true()
	MatchViewHarness.close(view)


# --- the handoff --------------------------------------------------------------------

## What a `RunShell` does: swap the view in, listen to it, and own nothing else of it.
class ShellDouble:
	extends RefCounted

	var trail: Array[String] = []
	var scene_changes: int = 0

	func listen(driver: MatchDriver, view: MatchView) -> void:
		driver.match_ended.connect(func(_result: Dictionary) -> void: trail.append("match_ended"))
		view.match_view_finished.connect(func(_result: Dictionary) -> void: trail.append("match_view_finished"))


func _driven_view(shell: ShellDouble) -> Array:
	var boot: Node = MatchViewHarness.fresh_boot({"anim_speed": "instant"})
	var loader := MatchDebugLoader.new(MatchViewHarness.immediate_planner(), boot)
	var controller: MatchController = loader.load_fixture("turn1_player")
	var driver: MatchDriver = controller.get("_driver")
	var view: MatchView = await MatchViewHarness.open_controller(self, boot, MatchController.new(driver), loader.match_info)
	shell.listen(driver, view)
	return [view, weakref(driver)]


func test_the_shell_hears_match_ended_before_the_view_finishes() -> void:
	# Arrange
	var shell := ShellDouble.new()
	var parts: Array = await _driven_view(shell)
	var view: MatchView = parts[0]
	var path: NodePath = view.get_path()

	# Act
	view.router().intent(InputRouter.INTENT_CONCEDE)
	MatchViewHarness.settle(view)
	MatchViewHarness.run(view, AUTO_S + FRAME_S)

	# Assert
	assert_array(shell.trail).is_equal(["match_ended", "match_view_finished"])
	assert_bool(view.is_inside_tree()).is_true()
	assert_object(get_node_or_null(path)).is_same(view)
	MatchViewHarness.close(view)


func test_the_driver_graph_is_freed_after_the_view_leaves_the_tree() -> void:
	# Arrange
	var shell := ShellDouble.new()
	var parts: Array = await _driven_view(shell)
	var view: MatchView = parts[0]
	var driver_ref: WeakRef = parts[1]
	view.router().intent(InputRouter.INTENT_CONCEDE)
	MatchViewHarness.settle(view)
	MatchViewHarness.run(view, AUTO_S + FRAME_S)
	shell = null
	parts.clear()

	# Act
	MatchViewHarness.close(view)
	view = null
	await get_tree().process_frame

	# Assert
	assert_object(driver_ref.get_ref()).is_null()
