## `RunController` over a real `RunMachine` and `RunShell` (run-ui U1, U2, U4, S1-S23;
## AC-9 to AC-14, AC-17, AC-18, AC-20, AC-21, AC-28). Every match here is a real one.
extends GdUnitTestSuite

const SEED_TEXT: String = "deckdelve"
## RNG & Event Log F1's example for [constant SEED_TEXT].
const SEED_HEX: String = "48A10CC0B2ED54EC"
## U2's intent column, screen by screen. `run_log.new_run_requested` is the zero-runs
## button; `open_replays`, `play_replay` and `open_glossary` are the Alpha additions.
const U2: Dictionary = {
	&"main_menu": [&"new_run_requested", &"continue_requested", &"open_run_log", &"open_unlocks", &"open_settings", &"retry_lock", &"quit_requested"],
	&"resume_prompt": [&"continue", &"abandon", &"back"],
	&"hero_select": [&"start_run", &"back"],
	&"run_start": [],
	&"boss_intro": [&"begin_match", &"open_pause"],
	&"match": [],
	&"draft_treasure": [&"pick", &"skip_pick", &"open_pause"],
	&"draft_bundle": [&"pick", &"skip_pick", &"open_pause"],
	&"summary_victory": [&"new_run_same_hero", &"go_hero_select", &"go_main_menu"],
	&"summary_defeat": [&"new_run_same_hero", &"go_hero_select", &"go_main_menu"],
	&"summary_abandoned": [&"new_run_same_hero", &"go_main_menu"],
	&"run_log": [&"load_more", &"open_run", &"open_replays", &"new_run_requested", &"back"],
	&"run_detail": [&"back"],
	&"replay_list": [&"play_replay", &"back"],
	&"settings": [&"set_setting", &"clear_run_records_requested", &"reset_profile_requested", &"open_controls", &"open_glossary", &"back"],
	&"controls": [&"set_binding", &"reset_bindings", &"back"],
	&"glossary": [&"back"],
	&"unlocks": [&"back"],
	&"pause": [&"close", &"open_settings", &"open_glossary", &"set_setting", &"abandon", &"go_main_menu"],
	&"confirm": [&"confirm", &"cancel"],
	&"notice": [&"notice_new_run"],
	&"data_error": [&"quit_requested"],
}
const OVERLAYS: Array[StringName] = [&"resume_prompt", &"run_detail", &"replay_list", &"settings", &"controls", &"glossary", &"unlocks", &"pause", &"confirm", &"notice"]

var _rig: RunUiRig = null


func before() -> void:
	RunUiRig.install_input()


func after() -> void:
	RunUiRig.restore_input()


func after_test() -> void:
	if _rig != null:
		_rig.finish()
		_rig = null


func _start(settings: Dictionary = RunUiRig.INSTANT) -> RunUiRig:
	_rig = await RunUiRig.start(self, null, settings)
	return _rig


func _base() -> String:
	return String(_rig.shell.screen())


func _reasons(name: StringName) -> Array:
	return _rig.rejected.filter(func(row: Array) -> bool: return row[0] == name).map(func(row: Array) -> StringName: return row[1])


## Wins floor 1 and stops on its first draft.
func _to_draft() -> void:
	await _rig.to_boss()
	await _rig.win_floor()


## The menu to the boss intro at `normal`, each transition skipped.
func _normal_to_boss() -> void:
	_rig.intent(&"skip")
	await _rig.settle()
	_rig.intent(&"new_run_requested")
	_rig.intent(&"skip")
	await _rig.settle()
	_rig.intent(&"start_run", {"hero_id": "hero_war", "seed_input": SEED_TEXT})
	_rig.intent(&"skip")
	await _rig.settle()
	_rig.intent(&"skip")
	await _rig.settle()


func _reopen_draft() -> void:
	_rig.controller._open_screen(_rig.controller.state.base, RunUiConfig.KIND_FADE)
	await _rig.settle()


# --- AC-11 ------------------------------------------------------------------------

func test_ac11_the_legal_table_is_u2() -> void:
	for screen: StringName in U2:
		var legal: Array = (RunController.LEGAL.get(screen, []) as Array).duplicate()
		var expected: Array = (U2[screen] as Array).duplicate()
		legal.sort()
		expected.sort()
		assert_array(legal).override_failure_message(String(screen)).is_equal(expected)


func test_ac11_every_other_state_and_intent_is_rejected_bad_state_and_changes_nothing() -> void:
	# Arrange
	await _start()
	var meta: RunUiRig.FakeMeta = _rig.meta
	var universe: Array[StringName] = []
	for screen: StringName in U2:
		for name: StringName in U2[screen]:
			if not universe.has(name):
				universe.append(name)
	var state: ShellState = _rig.controller.state
	var calls_before: int = meta.calls.size()
	var phase_before: String = _rig.run.phase()

	# Act / Assert
	for screen: StringName in U2:
		state.base = &"boss_intro" if OVERLAYS.has(screen) else screen
		state.overlays.clear()
		if OVERLAYS.has(screen):
			state.overlays.append(screen)
		for name: StringName in universe:
			if (U2[screen] as Array).has(name):
				continue
			_rig.rejected.clear()
			_rig.intent(name)
			assert_array(_rig.rejected).override_failure_message("%s on %s" % [name, screen]).is_equal([[name, &"bad_state"]])
			assert_str(String(state.top())).is_equal(String(screen))
	assert_int(meta.calls.size()).is_equal(calls_before)
	assert_str(_rig.run.phase()).is_equal(phase_before)
	state.base = &"main_menu"
	state.overlays.clear()


func test_s4_continue_with_no_saved_run_is_refused() -> void:
	await _start()
	_rig.intent(&"continue_requested")
	assert_array(_reasons(&"continue_requested")).is_equal([&"bad_state"])
	assert_str(String(_rig.controller.state.top())).is_equal("main_menu")


# --- Menu to the first match ----------------------------------------------------------

func test_s3_new_run_opens_hero_select() -> void:
	await _start()
	_rig.intent(&"new_run_requested")
	await _rig.settle()
	assert_str(_base()).is_equal("hero_select")
	assert_str(_rig.run.phase()).is_equal(RunState.STATUS_HERO_SELECT)


func test_s7_s9_start_run_passes_run_start_and_lands_on_the_boss_intro() -> void:
	await _start()
	await _rig.to_boss()
	assert_array(_rig.screens).is_equal([&"hero_select", &"run_start", &"boss_intro"])
	assert_str(_base()).is_equal("boss_intro")
	assert_int(int(_rig.controller.read_model().floor)).is_equal(1)


func test_s8_a_refused_start_uncommits_and_says_why() -> void:
	# Arrange
	await _start()
	(_rig.meta as RunUiRig.FakeMeta).locked = ["hero_war"]
	_rig.intent(&"new_run_requested")
	await _rig.settle()

	# Act
	_rig.intent(&"start_run", {"hero_id": "hero_war", "seed_input": ""})
	await _rig.settle()

	# Assert
	assert_str(_base()).is_equal("hero_select")
	assert_bool(_rig.controller.state.committed).is_false()
	assert_int(_rig.toasts.size()).is_equal(1)
	assert_str(str(_rig.toasts[0][1].title)).is_equal(tr("rejected.E_HERO_LOCKED"))


func test_s23_back_from_hero_select_returns_to_the_menu() -> void:
	await _start()
	_rig.intent(&"new_run_requested")
	await _rig.settle()
	_rig.intent(&"back")
	await _rig.settle()
	assert_str(_base()).is_equal("main_menu")
	assert_str(_rig.run.phase()).is_equal("menu")


func test_s9_run_start_advances_by_itself_when_its_time_is_up() -> void:
	# Arrange
	await _start({"anim_speed": "fast"})
	_rig.intent(&"skip")
	await _rig.settle()
	_rig.intent(&"new_run_requested")
	_rig.intent(&"skip")
	await _rig.settle()

	# Act: no skip, no key
	_rig.intent(&"start_run", {"hero_id": "hero_war", "seed_input": ""})
	assert_str(_base()).is_equal("run_start")
	var limit: int = Time.get_ticks_msec() + 2000
	while _rig.shell.screen() == &"run_start" and Time.get_ticks_msec() < limit:
		await get_tree().process_frame

	# Assert
	assert_str(_base()).is_equal("boss_intro")


func test_s9_any_key_on_run_start_goes_straight_to_the_boss_intro() -> void:
	# Arrange
	await _start({"anim_speed": "normal"})
	_rig.intent(&"skip")
	await _rig.settle()
	_rig.intent(&"new_run_requested")
	_rig.intent(&"skip")
	await _rig.settle()
	_rig.intent(&"start_run", {"hero_id": "hero_war", "seed_input": ""})

	# Act
	await _rig.key(KEY_X)

	# Assert
	assert_str(_base()).is_equal("boss_intro")


# --- AC-18 ------------------------------------------------------------------------

func test_ac18_the_echo_shows_the_hex_and_start_passes_the_raw_text() -> void:
	# Arrange
	await _start()
	_rig.intent(&"new_run_requested")
	await _rig.settle()
	var screen: Screen = _rig.top()
	var sent: Array = []
	screen.intent_requested.connect(func(name: StringName, args: Dictionary) -> void: sent.append([name, args]))
	var field: LineEdit = screen.find_children("*", "LineEdit", true, false)[0]

	# Act
	field.grab_focus()
	field.text = SEED_TEXT
	field.text_changed.emit(SEED_TEXT)
	var echo: Array[String] = RunUiRig.texts(screen)
	_rig.top()._on_start()
	await _rig.settle()

	# Assert
	assert_array(echo).contains(["→ " + SEED_HEX])
	assert_str(str(sent[0][1].seed_input)).is_equal(SEED_TEXT)
	assert_str(_rig.run.state.run_seed_hex).is_equal(SEED_HEX)


func test_a_whitespace_seed_echoes_random() -> void:
	await _start()
	_rig.intent(&"new_run_requested")
	await _rig.settle()
	var field: LineEdit = _rig.top().find_children("*", "LineEdit", true, false)[0]
	field.text = "   "
	field.text_changed.emit("   ")
	assert_array(RunUiRig.texts(_rig.top())).contains([tr("hero.seed_random")])


# --- AC-9, AC-20 ----------------------------------------------------------------------

func test_ac9_pick_twice_on_a_bundle_is_one_draft_pick() -> void:
	# Arrange
	await _start()
	await _to_draft()
	_rig.intent(&"pick", {"index": 0})
	await _rig.settle()
	assert_str(_base()).is_equal("draft_bundle")
	var ids: Array = _rig.run.current_offer().option_ids
	var drafts: int = _rig.run.state.drafts.size()

	# Act
	_rig.intent(&"pick", {"index": 1})
	_rig.intent(&"pick", {"index": 1})

	# Assert
	assert_int(_rig.run.state.drafts.size()).is_equal(drafts + 1)
	assert_str(str(_rig.run.state.drafts[drafts].picked_id)).is_equal(str(ids[1]))
	assert_int(_reasons(&"pick").size()).is_equal(1)


func test_ac20_at_instant_committed_still_blocks_a_second_pick_across_the_swap() -> void:
	# Arrange: the treasure step, whose swap lands on another pickable screen
	await _start()
	await _to_draft()
	assert_str(_base()).is_equal("draft_treasure")

	# Act: both in one frame
	_rig.intent(&"pick", {"index": 0})
	_rig.intent(&"pick", {"index": 1})

	# Assert: the bundle step was not taken by the second press
	assert_int(_rig.run.state.drafts.size()).is_equal(1)
	assert_array(_reasons(&"pick")).is_equal([&"committed"])
	await _rig.settle()
	_rig.intent(&"pick", {"index": 1})
	assert_int(_rig.run.state.drafts.size()).is_equal(2)


func test_ac20_at_normal_a_pick_during_the_landing_is_blocked() -> void:
	# Arrange
	await _start({"anim_speed": "normal"})
	await _normal_to_boss()
	await _rig.win_floor()
	_rig.intent(&"skip")
	await _rig.settle()

	# Act
	_rig.intent(&"pick", {"index": 0})
	assert_bool(_rig.shell._landing).is_true()
	_rig.intent(&"pick", {"index": 1})

	# Assert
	assert_int(_rig.run.state.drafts.size()).is_equal(1)
	assert_array(_reasons(&"pick")).is_equal([&"committed"])


func test_u4_committed_ignores_every_further_intent_not_only_terminal_ones() -> void:
	await _start()
	await _rig.to_boss()
	_rig.controller.state.committed = true
	_rig.intent(&"open_pause")
	assert_array(_reasons(&"open_pause")).is_equal([&"committed"])
	assert_str(String(_rig.controller.state.top())).is_equal("boss_intro")
	_rig.controller.state.committed = false


func test_ac20_instant_reaches_the_same_screens_as_normal() -> void:
	# Arrange
	await _start()
	await _rig.to_boss()
	var instant: Array[StringName] = _rig.screens.duplicate()
	_rig.finish()

	# Act
	await _start({"anim_speed": "normal"})
	await _normal_to_boss()

	# Assert
	assert_array(_rig.screens).is_equal(instant)


# --- AC-10 ------------------------------------------------------------------------

func test_ac10_a_transition_drops_every_intent_but_skip() -> void:
	# Arrange
	await _start({"anim_speed": "normal"})
	_rig.intent(&"skip")
	await _rig.settle()
	_rig.intent(&"new_run_requested")
	assert_bool(_rig.controller.state.transitioning).is_true()
	var calls: int = (_rig.meta as RunUiRig.FakeMeta).calls.size()

	# Act
	_rig.intent(&"start_run", {"hero_id": "hero_war", "seed_input": ""})

	# Assert
	assert_array(_reasons(&"start_run")).is_equal([&"transitioning"])
	assert_int((_rig.meta as RunUiRig.FakeMeta).calls.size()).is_equal(calls)
	_rig.intent(&"skip")
	assert_bool(_rig.controller.state.transitioning).is_false()
	assert_float(_rig.shell._fade.modulate.a).is_equal(0.0)


# --- AC-12 ------------------------------------------------------------------------

func test_ac12_continue_into_a_draft_reoffers_the_same_ids_with_no_hero_select() -> void:
	# Arrange
	await _start()
	await _to_draft()
	var ids: Array = _rig.run.current_offer().option_ids.duplicate()
	_rig.intent(&"open_pause")
	await _rig.settle()
	_rig.intent(&"go_main_menu")
	await _rig.settle()
	assert_str(_base()).is_equal("main_menu")
	_rig.screens.clear()

	# Act
	_rig.intent(&"continue_requested")
	await _rig.settle()
	assert_str(String(_rig.controller.state.top())).is_equal("resume_prompt")
	_rig.intent(&"continue")
	await _rig.settle()

	# Assert
	assert_str(_base()).is_equal("draft_treasure")
	assert_array(_rig.screens).is_equal([&"draft_treasure"])
	assert_array(_rig.run.current_offer().option_ids).is_equal(ids)
	assert_array(_rig.controller.state.overlays).is_empty()


func test_continue_into_pre_match_opens_the_boss_intro() -> void:
	await _start()
	await _rig.to_boss()
	_rig.intent(&"open_pause")
	await _rig.settle()
	_rig.intent(&"go_main_menu")
	await _rig.settle()
	_rig.intent(&"continue_requested")
	await _rig.settle()
	_rig.intent(&"continue")
	await _rig.settle()
	assert_str(_base()).is_equal("boss_intro")


func test_resume_prompt_abandon_goes_through_confirm_and_ends_the_run() -> void:
	# Arrange
	await _start()
	await _rig.to_boss()
	_rig.intent(&"open_pause")
	await _rig.settle()
	_rig.intent(&"go_main_menu")
	await _rig.settle()
	_rig.intent(&"continue_requested")
	await _rig.settle()

	# Act / Assert
	_rig.intent(&"abandon")
	await _rig.settle()
	assert_str(String(_rig.controller.state.top())).is_equal("confirm")
	assert_int((_rig.meta as RunUiRig.FakeMeta).count("archive_run")).is_equal(0)
	_rig.intent(&"confirm")
	await _rig.settle()
	assert_str(_base()).is_equal("summary_abandoned")
	assert_array(RunUiRig.texts(_rig.top())).contains([tr("summary.abandoned.player")])


# --- AC-14 ------------------------------------------------------------------------

func _with_saved_run_on_hero_select() -> void:
	await _start()
	await _rig.to_boss()
	_rig.intent(&"open_pause")
	await _rig.settle()
	_rig.intent(&"go_main_menu")
	await _rig.settle()
	_rig.intent(&"new_run_requested")
	await _rig.settle()


func test_ac14_start_over_a_saved_run_asks_first_and_cancel_keeps_it() -> void:
	# Arrange
	await _with_saved_run_on_hero_select()
	var saved: Dictionary = _rig.meta.load_active_run()

	# Act
	_rig.intent(&"start_run", {"hero_id": "hero_war", "seed_input": ""})
	await _rig.settle()

	# Assert
	assert_str(String(_rig.controller.state.top())).is_equal("confirm")
	assert_object(_rig.run.state).is_null()
	_rig.intent(&"cancel")
	await _rig.settle()
	assert_str(String(_rig.controller.state.top())).is_equal("hero_select")
	assert_str(str(_rig.meta.load_active_run().run_id)).is_equal(str(saved.run_id))
	assert_int((_rig.meta as RunUiRig.FakeMeta).count("archive_run")).is_equal(0)


func test_ac14_confirm_starts_the_new_run_and_ends_the_old_one() -> void:
	# Arrange
	await _with_saved_run_on_hero_select()
	_rig.intent(&"start_run", {"hero_id": "hero_war", "seed_input": "other"})
	await _rig.settle()
	_rig.screens.clear()

	# Act
	_rig.intent(&"confirm")
	await _rig.settle()

	# Assert
	assert_array(_rig.screens).is_equal([&"run_start", &"boss_intro"])
	assert_int((_rig.meta as RunUiRig.FakeMeta).count("archive_run")).is_equal(1)


# --- AC-17 ------------------------------------------------------------------------

func test_ac17_new_run_same_hero_needs_no_confirm_and_a_random_seed() -> void:
	# Arrange
	await _start()
	await _rig.to_boss("hero_war", SEED_TEXT)
	await _rig.lose_floor()
	assert_str(_base()).is_equal("summary_defeat")
	_rig.screens.clear()

	# Act
	_rig.intent(&"new_run_same_hero")
	await _rig.settle()

	# Assert
	assert_array(_rig.screens).is_equal([&"run_start", &"boss_intro"])
	assert_str(_rig.run.state.hero_id).is_equal("hero_war")
	assert_str(_rig.run.state.seed_source).is_equal(RunCodes.SEED_RANDOM)
	assert_str(_rig.run.state.run_seed_hex).is_not_equal(SEED_HEX)


func test_s19_go_hero_select_and_go_main_menu_leave_a_summary() -> void:
	await _start()
	await _rig.to_boss()
	await _rig.lose_floor()
	_rig.intent(&"go_hero_select")
	await _rig.settle()
	assert_str(_base()).is_equal("hero_select")
	_rig.intent(&"start_run", {"hero_id": "hero_war", "seed_input": ""})
	await _rig.settle()
	await _rig.lose_floor()
	_rig.intent(&"go_main_menu")
	await _rig.settle()
	assert_str(_base()).is_equal("main_menu")
	assert_object(_rig.meta.load_active_run()).is_null()


func test_s17_abandon_from_pause_needs_confirm_and_opens_the_notice() -> void:
	await _start()
	await _rig.to_boss()
	_rig.intent(&"open_pause")
	await _rig.settle()
	_rig.intent(&"abandon")
	await _rig.settle()
	_rig.intent(&"cancel")
	await _rig.settle()
	assert_str(String(_rig.controller.state.top())).is_equal("pause")
	_rig.intent(&"abandon")
	await _rig.settle()
	_rig.intent(&"confirm")
	await _rig.settle()
	assert_str(_base()).is_equal("summary_abandoned")
	assert_array(_rig.controller.state.overlays).is_empty()
	assert_int(_rig.shell._overlays.size()).is_equal(0)


# --- AC-32 second half (C-12) -----------------------------------------------------

func test_ac32_quit_from_pause_suspends_and_the_menu_offers_the_same_floor() -> void:
	# Arrange
	await _start()
	await _rig.to_boss()
	var calls: RunUiRig.FakeMeta = _rig.meta
	var archived: int = calls.count("archive_run")
	var run_id: String = _rig.run.state.run_id
	_rig.intent(&"open_pause")
	await _rig.settle()

	# Act
	_rig.intent(&"go_main_menu")
	await _rig.settle()

	# Assert
	assert_object(_rig.run.state).is_null()
	assert_int(calls.count("archive_run")).is_equal(archived)
	assert_str(str(calls.load_active_run().run_id)).is_equal(run_id)
	var labels: Array = _rig.top().find_children("*", "Button", true, false).map(func(b: Button) -> String: return b.text)
	assert_str(str(labels[0])).starts_with("Continue: ")
	assert_str(str(labels[0])).contains("floor 1 of 8")


# --- AC-21, AC-28 -----------------------------------------------------------------

func test_ac21_a_missing_first_id_shows_its_frame_and_keeps_the_keys_on_their_slots() -> void:
	# Arrange
	await _start()
	await _to_draft()
	var offer: Offer = _rig.run._offer
	var kept: String = offer.option_ids[1]
	offer.option_ids[0] = "treasure_gone"
	_rig.toasts.clear()

	# Act
	await _reopen_draft()

	# Assert: the frame, and a warning (Edge Cases: `ui_data_missing`)
	assert_array(RunUiRig.texts(_rig.top())).contains([tr("draft.missing").format({"id": "treasure_gone"})])
	assert_int(_rig.toasts.size()).is_equal(1)
	assert_str(str(_rig.toasts[0][1].title)).is_equal(tr("warning.ui_data_missing"))
	assert_str(tr("warning.ui_data_missing")).is_not_equal("warning.ui_data_missing")

	# `1` lands on no option: its slot cannot be picked
	await _rig.key(KEY_1)
	assert_object(_rig.focus()).is_null()
	# `2` is the second slot, not the second pickable one
	await _rig.key(KEY_2)
	assert_int((_rig.focus() as OptionPanel)._index).is_equal(1)

	# Picking the missing slot issues nothing, picking the next does
	_rig.intent(&"pick", {"index": 0})
	assert_array(_reasons(&"pick")).is_equal([&"bad_index"])
	assert_int(_rig.run.state.drafts.size()).is_equal(0)
	_rig.intent(&"pick", {"index": 1})
	assert_str(str(_rig.run.state.drafts[0].picked_id)).is_equal(kept)


func test_ac28_a_short_offer_keeps_the_slots_and_refuses_the_empty_one() -> void:
	# Arrange
	await _start()
	await _to_draft()
	var offer: Offer = _rig.run._offer
	var b: String = offer.option_ids[1]
	offer.option_ids.resize(2)
	offer.per_option.resize(2)
	offer.flags.append(Offer.FLAG_SHORT)

	# Act
	await _reopen_draft()
	var cfg: Dictionary = RunUiRig.config()
	var panels: Array = _rig.top().find_children("*", "OptionPanel", true, false)

	# Assert: F4 slots 0 and 1, a placeholder with its reason
	assert_int(panels.size()).is_equal(2)
	for i: int in 2:
		var expected: int = RunUiConfig.slot_x(i, 3, int(cfg.option_w.treasure), int(cfg.option_gap.treasure), int(cfg.design_width))
		assert_float((panels[i] as Control).position.x).is_equal(float(expected))
	assert_array(RunUiRig.texts(_rig.top())).contains([tr("draft.short.treasure")])
	await _rig.key(KEY_3)
	assert_object(_rig.focus()).is_null()
	_rig.intent(&"pick", {"index": 2})
	assert_array(_reasons(&"pick")).is_equal([&"bad_index"])
	assert_int(_rig.run.state.drafts.size()).is_equal(0)
	_rig.intent(&"pick", {"index": 1})
	assert_str(str(_rig.run.state.drafts[0].picked_id)).is_equal(b)


func test_skip_pick_without_allow_skip_is_refused() -> void:
	await _start()
	await _to_draft()
	_rig.intent(&"skip_pick")
	assert_array(_reasons(&"skip_pick")).is_equal([&"bad_state"])
	assert_int(_rig.run.state.drafts.size()).is_equal(0)


func test_a_refused_pick_uncommits_the_screen_and_says_why() -> void:
	# Arrange (U8): the offer is pulled away after the screen drew it
	await _start()
	await _to_draft()
	_rig.toasts.clear()
	var kind: StringName = StringName(_rig.run._offer.kind)

	# Act
	_rig.controller._draft_pick(&"bundle" if kind == &"treasure" else &"treasure", "treasure_none")

	# Assert
	assert_bool(_rig.controller.state.committed).is_false()
	assert_str(str(_rig.toasts[0][1].title)).is_equal(tr("rejected.E_DRAFT_KIND"))
