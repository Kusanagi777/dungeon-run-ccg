## The match hand-off (run-ui S10, S11, S11b, S16; AC-15, AC-29, AC-32) with a real
## `MatchView`, a real `MatchDriver` and the real end banner, and real unlocks from a
## `MetaFacade` on its own folder, not the `toast_sample` fixture.
extends GdUnitTestSuite

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


func _start(meta: MetaApi = null, settings: Dictionary = RunUiRig.INSTANT) -> RunUiRig:
	_rig = await RunUiRig.start(self, meta, settings)
	return _rig


func _base() -> String:
	return String(_rig.shell.screen())


## Faults the running match through the engine's own `event_cap` path.
func _fault(view: Control) -> void:
	var driver: MatchDriver = _rig.run._driver
	driver._engine.fault(MatchRecords.REASON_EVENT_CAP)
	driver._after_engine_step()
	await _rig.drain(view)


func _win_every_floor() -> void:
	for floor_number: int in range(1, 9):
		await _rig.win_floor()
		for _step: int in 2:
			if _base().begins_with("draft_"):
				_rig.intent(&"pick", {"index": 0})
				await _rig.settle()


# --- Hand-off -----------------------------------------------------------------------

func test_begin_match_hides_the_run_screens_and_shows_the_view() -> void:
	await _start()
	await _rig.to_boss()
	var view: Control = await _rig.begin()
	assert_object(view).is_not_null()
	assert_str(_base()).is_equal("match")
	assert_bool(_rig.shell._stack.visible).is_false()
	assert_bool(view.visible).is_true()


func test_a_real_win_through_the_banner_opens_the_treasure_draft() -> void:
	# Arrange
	await _start()
	await _rig.to_boss()
	_rig.boss_health = 1
	var view: Control = await _rig.begin()
	await _rig.play_out(view)

	# The run has already moved on, but the shell waits for the banner (S11)
	assert_str(_rig.run.phase()).is_equal(RunState.STATUS_POST_MATCH_REWARD)
	assert_str(_base()).is_equal("match")
	assert_bool(view._banner.is_shown()).is_true()

	# Act
	await _rig.continue_banner(view)

	# Assert
	assert_str(_base()).is_equal("draft_treasure")
	assert_object(_rig.view()).is_null()
	assert_bool(_rig.shell._stack.visible).is_true()


func test_the_banner_auto_advances_after_match_end_auto_s() -> void:
	# Arrange
	await _start()
	await _rig.to_boss()
	_rig.boss_health = 1
	var view: Control = await _rig.begin()
	await _rig.play_out(view)

	# Act: its clock, no press
	view._banner.tick(float(view._banner._auto_s))
	await _rig.settle()

	# Assert
	assert_str(_base()).is_equal("draft_treasure")


func test_a_concede_through_the_banner_opens_the_defeat_summary() -> void:
	await _start()
	await _rig.to_boss()
	await _rig.lose_floor()
	assert_str(_base()).is_equal("summary_defeat")
	assert_array(RunUiRig.texts(_rig.top())).contains([tr("summary.reason.defeat.concede")])
	assert_str(tr("summary.new_run")).is_equal((_rig.focus() as Button).text)


func test_a_full_win_opens_the_victory_summary() -> void:
	await _start()
	await _rig.to_boss()
	await _win_every_floor()
	assert_str(_base()).is_equal("summary_victory")
	assert_array(RunUiRig.texts(_rig.top())).contains([tr("summary.headline.victory").format({"f": 8})])


func test_the_last_event_decides_a_skipped_step_lands_on_the_boss_intro() -> void:
	# Arrange (S11b, D8c): a run whose offers come back empty skips both steps. Floor 2 has
	# no treasure step, and an exhausted bundle pool leaves no offer.
	await _start()
	await _rig.to_boss()
	await _rig.win_floor()
	_rig.intent(&"pick", {"index": 0})
	await _rig.settle()
	_rig.intent(&"pick", {"index": 0})
	await _rig.settle()
	assert_int(int(_rig.controller.read_model().floor)).is_equal(2)

	# Act: `run_floor_entered` alone in the buffer
	var view: Control = await _rig.begin()
	var enter: Dictionary = {"type": RunCodes.EVENT_FLOOR_ENTERED, "payload": {"floor": 2}}
	_rig.controller._on_event(enter)
	_rig.run.state.status = RunState.STATUS_PRE_MATCH
	view._finish_match()
	await _rig.settle()

	# Assert
	assert_str(_base()).is_equal("boss_intro")


# --- AC-29 ------------------------------------------------------------------------

func test_ac29_a_fault_replays_the_floor_with_attempt_two_and_a_warning() -> void:
	# Arrange
	await _start()
	await _rig.to_boss()
	var strip_before: Dictionary = RunReadModels.new(_rig.meta, _rig.db, RunUiRig.config()).strip(_rig.controller.read_model())
	var view: Control = await _rig.begin()
	_rig.screens.clear()

	# Act
	await _fault(view)

	# Assert: nothing until the banner is passed
	assert_str(_base()).is_equal("match")
	assert_array(_rig.toasts).is_empty()
	await _rig.continue_banner(view)

	assert_array(_rig.screens).is_equal([&"boss_intro"])
	assert_array(RunUiRig.texts(_rig.top())).contains([tr("boss.attempt").format({"n": 2}), tr("boss.floor").format({"n": 1, "f": 8})])
	var titles: Array = _rig.toasts.map(func(row: Array) -> String: return str(row[1].title))
	assert_array(titles).contains([tr("warning.match_faulted")])
	assert_str(str(_rig.toasts[0][0])).is_equal("warning")
	var strip_after: Dictionary = RunReadModels.new(_rig.meta, _rig.db, RunUiRig.config()).strip(_rig.controller.read_model())
	assert_dict(strip_after).is_equal(strip_before)


func test_ac29_no_draft_screen_shows_after_a_fault() -> void:
	await _start()
	await _rig.to_boss()
	var view: Control = await _rig.begin()
	await _fault(view)
	await _rig.continue_banner(view)
	assert_bool(_rig.screens.has(&"draft_treasure")).is_false()
	assert_bool(_rig.screens.has(&"draft_bundle")).is_false()
	assert_str(_rig.run.phase()).is_equal(RunState.STATUS_PRE_MATCH)


func test_after_a_fault_the_floor_can_be_fought_again() -> void:
	await _start()
	await _rig.to_boss()
	var view: Control = await _rig.begin()
	await _fault(view)
	await _rig.continue_banner(view)
	await _rig.win_floor()
	assert_str(_base()).is_equal("draft_treasure")


# --- Real unlocks -------------------------------------------------------------------

func test_ac15_a_real_unlock_waits_for_the_summary_and_is_acked_once() -> void:
	# Arrange: a real profile, and a concede on floor 1 of a run that would unlock nothing,
	# so the win is what grants.
	var facade: MetaFacade = RunUiRig.facade("ac15")
	await _start(facade)
	var granted: Array = []
	facade.unlock_granted.connect(func(key: String, _kind: StringName, _id: String, _run: String, _retro: bool) -> void: granted.append(key))
	var acked: Array = []
	_rig.shell._toasts.shown.connect(func(kind: StringName, key: String) -> void: acked.append([kind, key]))

	# Act
	await _rig.to_boss()
	_rig.intent(&"skip")
	await _win_until_last_match()
	var view: Control = await _rig.begin()
	await _rig.force_win(view)

	# Assert: granted during the match; no toast yet
	assert_array(granted).is_not_empty()
	assert_bool(_rig.shell._toasts.is_showing()).is_false()
	await get_tree().process_frame
	assert_bool(_rig.shell._toasts.is_showing()).is_false()
	assert_int(facade.pending_notifications().size()).is_equal(granted.size())

	await _rig.continue_banner(view)
	assert_str(_base()).is_equal("summary_victory")
	await _rig.settle()

	# The head of the queue shows here, and showing it acks it, once
	assert_bool(_rig.shell._toasts.is_showing()).is_true()
	assert_array(acked).is_equal([[&"unlock", granted[0]]])
	assert_int(facade.pending_notifications().size()).is_equal(granted.size() - 1)
	assert_int(_rig.sfx.events.count(RunShell.SFX_UNLOCK)).is_equal(1)
	assert_array(RunUiRig.texts(_rig.shell._toasts)).contains([str(_rig.toasts[0][1].title)])
	assert_str(str(_rig.toasts[0][1].title)).contains("unlocked: ")
	assert_str(str(_rig.toasts[0][1].subtitle)).is_not_empty()


func test_ac6_a_real_unlock_is_listed_on_the_summary() -> void:
	var facade: MetaFacade = RunUiRig.facade("ac6")
	await _start(facade)
	await _rig.to_boss()
	await _win_until_last_match()
	await _rig.win_floor()
	assert_int(_rig.run.unlocks_granted.size()).is_greater(0)
	var lines: Array = RunUiRig.texts(_rig.top()).filter(func(text: String) -> bool: return text.contains("unlocked: "))
	assert_int(lines.size()).is_equal(_rig.run.unlocks_granted.size())


func test_ac15_a_key_still_queued_at_the_next_boot_shows_once_and_acks_once() -> void:
	# Arrange: a grant whose toast never showed
	var facade: MetaFacade = RunUiRig.facade("ac15b")
	await _start(facade)
	await _rig.to_boss()
	await _win_until_last_match()
	var view: Control = await _rig.begin()
	await _rig.force_win(view)
	var pending: Array = facade.pending_notifications()
	assert_array(pending).is_not_empty()
	_rig.finish()
	_rig = null

	# Act: the next launch reads the queue on S1
	await _start(facade)
	_rig.controller.start()
	await _rig.settle()
	_rig.controller.start()
	await _rig.settle()

	# Assert: the head shows on the menu; a second read adds no second toast for it
	assert_bool(_rig.shell._toasts.is_showing()).is_true()
	assert_int(_rig.shell._toasts.queued().size()).is_equal(pending.size() - 1)


func test_ac32_an_unlock_showing_on_the_summary_rides_new_run_to_the_boss_intro() -> void:
	# Arrange
	var facade: MetaFacade = RunUiRig.facade("ac32")
	await _start(facade)
	await _rig.to_boss()
	await _win_until_last_match()
	await _rig.win_floor()
	await _rig.settle()
	assert_bool(_rig.shell._toasts.is_showing()).is_true()
	var panel: Control = _rig.shell._toasts._panel
	var left: float = _rig.shell._toasts._left_ms

	# Act
	_rig.intent(&"new_run_same_hero")
	await get_tree().process_frame
	var on_run_start: bool = _rig.shell._toasts.is_showing()
	await _rig.settle()

	# Assert: the same panel, its clock still running, acked once
	assert_bool(on_run_start).is_true()
	assert_str(_base()).is_equal("boss_intro")
	assert_object(_rig.shell._toasts._panel).is_same(panel)
	assert_float(_rig.shell._toasts._left_ms).is_less(left)
	_rig.shell._toasts._process(_rig.shell._toasts._left_ms / RunUiConfig.MS_PER_S)
	assert_bool(_rig.shell._toasts._panel == panel).is_false()


func test_ac15_toasts_are_held_during_a_match_and_on_run_start() -> void:
	# Arrange
	await _start()
	await _rig.to_boss()
	await _rig.begin()

	# Act
	_rig.controller.toast.emit(&"warning", {"title": "held"})
	await _rig.settle()

	# Assert
	assert_bool(_rig.shell._toasts.is_showing()).is_false()
	assert_int(_rig.shell._toasts.queued().size()).is_equal(1)


func test_a_toast_is_held_while_a_confirm_is_open_and_starts_after() -> void:
	# Edge Cases: "a toast (`save_failed`) arrives while a confirm dialog is open: it queues"
	await _start()
	await _rig.to_boss()
	_rig.intent(&"open_pause")
	await _rig.settle()
	_rig.intent(&"abandon")
	await _rig.settle()
	_rig.controller.toast.emit(&"warning", {"title": "held"})
	await _rig.settle()
	assert_bool(_rig.shell._toasts.is_showing()).is_false()
	_rig.intent(&"cancel")
	await _rig.settle()
	assert_bool(_rig.shell._toasts.is_showing()).is_true()


## Wins floors 1 to 7, stopping on the boss intro of floor 8.
func _win_until_last_match() -> void:
	for floor_number: int in range(1, 8):
		await _rig.win_floor()
		for _step: int in 2:
			if _base().begins_with("draft_"):
				_rig.intent(&"pick", {"index": 0})
				await _rig.settle()
