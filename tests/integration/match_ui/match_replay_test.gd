## The replay viewer (architecture.md "Can defer"; ADR-0003; rng-event-log rules 9, 16-18):
## `MatchReplay` and `ReplayController` playing a recorded log through the real view, and the
## refusal of a log from another engine or data. Files live under one `user://` folder that
## each test cleans up.
extends GdUnitTestSuite

const ROOT: String = "user://match_replay_test/"
const RUN_ID: String = "run_a"
const FILE_NAME: String = "floor_2_attempt_1.json"
const FRAME_S: float = 1.0 / 60.0
const SETTLE_S: float = 300.0
const HERO: String = "hero_war"
const BOSS: String = "boss_torchbearer"


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute(ROOT + RUN_ID)
	DirAccess.make_dir_recursive_absolute(ROOT + EventLogArchive.FAULTS_FOLDER)


func after_test() -> void:
	for folder: String in [ROOT + RUN_ID, ROOT + EventLogArchive.FAULTS_FOLDER]:
		for file: String in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder.path_join(file))
		DirAccess.remove_absolute(folder)
	DirAccess.remove_absolute(ROOT)


## The whole log of a finished fixture match as the JSON an archive holds.
func _recorded(engine: String, data_version: String) -> String:
	var boot: Node = auto_free(MatchViewHarness.fresh_boot())
	var loader := MatchDebugLoader.new(MatchViewHarness.immediate_planner(), boot)
	var controller: MatchController = loader.load_fixture("match_end_victory")
	var log := EventLog.new(100000, EventLog.SCOPE_MATCH, {"engine_version": engine, "data_version": data_version, "floor": 2, "run_seed_hex": "00"})
	for event: Dictionary in controller.events_since(0):
		log.append(StringName(str(event.type)), event.payload, int(event.cause_seq))
	controller.shutdown()
	return log.to_json()


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _good_path() -> String:
	var path: String = ROOT + RUN_ID + "/" + FILE_NAME
	_write(path, _recorded(Engine.get_version_info().string, MatchViewHarness.database().data_version()))
	return path


func _replay_view(path: String, settings: Dictionary = {"anim_speed": "fast"}) -> MatchView:
	var boot: Node = MatchViewHarness.fresh_boot(settings)
	var controller := ReplayController.new(EventLog.from_json(FileAccess.get_file_as_string(path)), MatchViewHarness.database())
	return await MatchViewHarness.open_controller(self, boot, controller, {"floor": 2, "boss_def_id": BOSS, "hero_def_id": HERO})


func test_archives_lists_a_runs_logs_by_floor_then_attempt_with_its_faults() -> void:
	# Arrange
	_write(ROOT + RUN_ID + "/floor_2_attempt_1.json", "{}")
	_write(ROOT + RUN_ID + "/floor_1_attempt_2.json", "{}")
	_write(ROOT + RUN_ID + "/notes.txt", "x")
	_write(ROOT + EventLogArchive.FAULTS_FOLDER + "/" + RUN_ID + "_floor_3_attempt_1.json", "{}")
	_write(ROOT + EventLogArchive.FAULTS_FOLDER + "/run_b_floor_9_attempt_1.json", "{}")

	# Act
	var found: Array[Dictionary] = MatchReplay.archives(RUN_ID, ROOT)

	# Assert
	assert_int(found.size()).is_equal(3)
	assert_array([int(found[0].floor), int(found[0].attempt)]).is_equal([1, 2])
	assert_array([int(found[1].floor), int(found[1].attempt)]).is_equal([2, 1])
	assert_bool(found[1].fault).is_false()
	assert_int(int(found[2].floor)).is_equal(3)
	assert_bool(found[2].fault).is_true()


func test_a_log_kept_in_both_folders_is_listed_once_as_the_runs() -> void:
	# Arrange
	_write(ROOT + RUN_ID + "/floor_2_attempt_1.json", "{}")
	_write(ROOT + EventLogArchive.FAULTS_FOLDER + "/" + RUN_ID + "_floor_2_attempt_1.json", "{}")

	# Act
	var found: Array[Dictionary] = MatchReplay.archives(RUN_ID, ROOT)

	# Assert
	assert_int(found.size()).is_equal(1)
	assert_bool(found[0].fault).is_false()


func test_a_run_with_no_folder_lists_nothing() -> void:
	# Act / Assert
	assert_array(MatchReplay.archives("no_such_run", ROOT)).is_empty()


func test_a_log_of_this_engine_and_data_can_play() -> void:
	# Arrange
	var path: String = _good_path()

	# Act
	var check: Dictionary = MatchReplay.inspect(path, MatchViewHarness.database())

	# Assert
	assert_dict(check).is_equal({"replayable": true, "reason_key": "", "floor": 2})


func test_a_log_of_another_engine_is_refused_by_name() -> void:
	# Arrange
	var path: String = ROOT + RUN_ID + "/" + FILE_NAME
	_write(path, _recorded("0.0.0.stable", MatchViewHarness.database().data_version()))

	# Act
	var check: Dictionary = MatchReplay.inspect(path, MatchViewHarness.database())

	# Assert
	assert_bool(check.replayable).is_false()
	assert_str(str(check.reason_key)).is_equal(MatchReplay.KEY_ENGINE)


func test_a_log_of_other_data_is_refused_by_name() -> void:
	# Arrange
	var path: String = ROOT + RUN_ID + "/" + FILE_NAME
	_write(path, _recorded(Engine.get_version_info().string, "not_this_data"))

	# Act
	var check: Dictionary = MatchReplay.inspect(path, MatchViewHarness.database())

	# Assert
	assert_str(str(check.reason_key)).is_equal(MatchReplay.KEY_DATA)


func test_a_file_that_is_no_log_is_refused_as_unreadable() -> void:
	# Arrange
	var path: String = ROOT + RUN_ID + "/" + FILE_NAME
	_write(path, "not json")

	# Act
	var check: Dictionary = {}
	check = MatchReplay.inspect(path, MatchViewHarness.database())
	# Assert
	assert_str(str(check.reason_key)).is_equal(MatchReplay.KEY_UNREADABLE)


func test_a_missing_file_is_refused_as_unreadable() -> void:
	# Act
	var check: Dictionary = MatchReplay.inspect(ROOT + "gone.json", MatchViewHarness.database())

	# Assert
	assert_str(str(check.reason_key)).is_equal(MatchReplay.KEY_UNREADABLE)


func test_create_view_refuses_a_log_that_cannot_play() -> void:
	# Arrange
	var path: String = ROOT + RUN_ID + "/" + FILE_NAME
	_write(path, _recorded("0.0.0.stable", MatchViewHarness.database().data_version()))
	var view: Array = []

	# Act / Assert
	await assert_error(func() -> void: view.append(MatchReplay.create_view(path, MatchViewHarness.database(), HERO, BOSS))).is_push_warning("MatchReplay: %s cannot play: %s" % [path, MatchReplay.KEY_ENGINE])
	assert_object(view[0]).is_null()


func test_the_controller_refuses_every_command_and_offers_none() -> void:
	# Arrange
	var log := EventLog.new(10, EventLog.SCOPE_MATCH, {})
	var controller := ReplayController.new(log, MatchViewHarness.database())

	# Act
	var answer: Dictionary = controller.submit(MatchRecords.end_turn("player"))

	# Assert
	assert_bool(answer.accepted).is_false()
	assert_str(str(answer.rejection.code)).is_equal(ReplayController.CODE_READ_ONLY)
	assert_array(controller.legal_commands()).is_empty()
	assert_array(controller.events_since(0)).is_empty()
	assert_bool(controller.is_read_only()).is_true()
	assert_bool(controller.is_planning()).is_false()


func test_a_replay_plays_the_log_through_the_view_to_its_result() -> void:
	# Arrange
	var path: String = _good_path()
	var view: MatchView = await _replay_view(path)
	var controller: ReplayController = view.get("_controller")

	# Act
	var left: float = SETTLE_S
	while left > 0.0 and not (controller.finished() and view.queue().is_idle()):
		MatchViewHarness.run(view, 0.5, 0.05)
		left -= 0.5

	# Assert
	assert_bool(controller.finished()).is_true()
	assert_str(str(view.view_state().result.result)).is_equal("win")
	assert_int(view.sync_failures).is_equal(0)
	assert_str(String(view.router().view_state())).is_equal(String(InputRouter.STATE_ENDED))
	MatchViewHarness.close(view)


func test_a_replay_releases_nothing_while_the_queue_is_busy() -> void:
	# Arrange
	var path: String = _good_path()
	var view: MatchView = await _replay_view(path)
	var controller: ReplayController = view.get("_controller")
	view.queue().enqueue(AnimStep.new(AnimStep.TURN_BANNER, [], 10.0, 1, 1))
	view.queue().advance(0.0)
	var cursor: int = controller.get("_cursor")

	# Act
	controller.tick()

	# Assert
	assert_int(int(controller.get("_cursor"))).is_equal(cursor)
	view.queue().skip_all()
	MatchViewHarness.close(view)


func test_a_replay_starts_on_an_empty_table_and_never_at_instant() -> void:
	# Arrange / Act
	var view: MatchView = await _replay_view(_good_path(), {"anim_speed": "instant"})

	# Assert
	assert_str(String(view.get("_speed"))).is_equal("normal")
	assert_int(view.view_state().turn).is_equal(0)
	MatchViewHarness.close(view)


func test_a_replay_lights_nothing_and_end_turn_stays_off() -> void:
	# Arrange
	var view: MatchView = await _replay_view(_good_path())
	var sent: Array[Dictionary] = MatchViewHarness.spy_commands(view)

	# Act: to a player's main phase of the replay
	for i: int in 400:
		MatchViewHarness.run(view, 0.1, 0.05)
		if view.view_state().phase == "main" and view.view_state().active_side == "player" and view.queue().is_idle():
			break
	view.router().intent(InputRouter.INTENT_END_TURN)
	view.call("_show_legality")

	# Assert
	assert_bool(view.router().can_end_turn()).is_false()
	assert_array(sent).is_empty()
	assert_dict(view.hand().get("_playable")).is_empty()
	MatchViewHarness.close(view)


func test_close_replay_finishes_the_view_once_with_an_empty_result_before_the_end() -> void:
	# Arrange
	var view: MatchView = await _replay_view(_good_path())
	var finished: Array[Dictionary] = []
	view.match_view_finished.connect(func(result: Dictionary) -> void: finished.append(result))

	# Act
	view.close_replay()
	view.close_replay()

	# Assert
	assert_array(finished).is_equal([{}])
	MatchViewHarness.close(view)


func test_create_view_attaches_the_replay_hud_and_its_exit_button_leaves() -> void:
	# Arrange
	var path: String = _good_path()
	var view: MatchView = MatchReplay.create_view(path, MatchViewHarness.database(), HERO, BOSS)
	assert_object(view).is_not_null()
	var boot: Node = MatchViewHarness.fresh_boot({"anim_speed": "fast"})
	view.set_launch(boot)
	view.add_child(boot)
	var finished: Array[Dictionary] = []
	view.match_view_finished.connect(func(result: Dictionary) -> void: finished.append(result))
	add_child(view)
	view.set_process(false)

	# Act
	var huds: Array[Node] = view.find_children("*", "ReplayHud", true, false)
	(huds[0].find_children("*", "Button", true, false)[0] as Button).pressed.emit()

	# Assert
	assert_int(huds.size()).is_equal(1)
	assert_int(finished.size()).is_equal(1)
	MatchViewHarness.close(view)
