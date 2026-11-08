## `run_log`, `run_detail` and `replay_list` (run-ui U2; rng-event-log rules 17-18): paging
## newest first, the filter, opaque rows, the replay list and its return, refused logs,
## and what one row costs.
extends GdUnitTestSuite

const RECORD_FIXTURE: String = "res://tests/fixtures/run_ui/defeat_sample.json"
const COST_ROOT: String = "user://run_ui_rig/replay_cost/"
const ROWS: int = 25
const PAGE: int = 20

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
	RunUiRig.wipe(COST_ROOT)


func _record(index: int) -> Dictionary:
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RECORD_FIXTURE))
	var row: Dictionary = RunRecord.normalised(parsed.record)
	row["run_id"] = "row-%02d" % index
	row["ended_at"] = 1793000000 + index
	row["schema_version"] = RunRecord.SCHEMA_VERSION
	return row


func _meta_with(rows: int) -> RunUiRig.FakeMeta:
	var meta: RunUiRig.FakeMeta = RunUiRig.FakeMeta.new(RunUiRig.database())
	for i: int in rows:
		meta.log_rows.append(_record(i))
	return meta


func _start(meta: MetaApi) -> void:
	_rig = await RunUiRig.start(self, meta)


func _open_log() -> void:
	_rig.intent(&"open_run_log")
	await _rig.settle()


func _ids() -> Array:
	return (_rig.top()._model.rows as Array).map(func(row: Dictionary) -> String: return str(row.run_id))


func _top() -> String:
	return String(_rig.controller.state.top())


## Plays one real match and returns to the log.
func _played_run_on_the_log() -> void:
	await _start(RunUiRig.facade("replay_%d" % Time.get_ticks_usec()))
	await _rig.to_boss()
	await _rig.lose_floor()
	_rig.intent(&"go_main_menu")
	await _rig.settle()
	await _open_log()


func _open_replays() -> void:
	var row: Dictionary = _rig.top()._model.rows[0]
	_rig.intent(&"open_replays", {"run_id": row.run_id})
	await _rig.settle()


func _first_log_path() -> String:
	var run_id: String = str(_rig.controller._log_rows[0].run_id)
	return str(MatchReplay.archives(run_id)[0].path)


# --- The log ------------------------------------------------------------------------

func test_the_first_page_is_the_newest_runs_newest_first() -> void:
	await _start(_meta_with(ROWS))
	await _open_log()
	assert_int(_ids().size()).is_equal(PAGE)
	assert_str(str(_ids()[0])).is_equal("row-%02d" % (ROWS - 1))
	assert_str(str(_ids()[PAGE - 1])).is_equal("row-%02d" % (ROWS - PAGE))
	assert_bool(_rig.top()._more.visible).is_true()


func test_load_more_appends_the_older_runs_and_hides_itself() -> void:
	await _start(_meta_with(ROWS))
	await _open_log()
	_rig.intent(&"load_more")
	await _rig.settle()
	assert_int(_ids().size()).is_equal(ROWS)
	assert_str(str(_ids()[ROWS - 1])).is_equal("row-00")
	assert_bool(_rig.top()._more.visible).is_false()


func test_a_real_profile_lists_the_last_run_first() -> void:
	# Arrange
	await _start(RunUiRig.facade("order"))
	await _rig.to_boss("hero_war", "first")
	await _rig.lose_floor()
	var first_seed: String = _rig.run.state.run_seed_hex
	_rig.intent(&"go_hero_select")
	await _rig.settle()
	_rig.intent(&"start_run", {"hero_id": "hero_war", "seed_input": "second"})
	await _rig.settle()
	await _rig.lose_floor()
	var second_seed: String = _rig.run.state.run_seed_hex
	_rig.intent(&"go_main_menu")
	await _rig.settle()

	# Act
	await _open_log()

	# Assert
	var seeds: Array = (_rig.top()._model.rows as Array).map(func(row: Dictionary) -> String: return str(row.seed))
	assert_array(seeds).is_equal([second_seed, first_seed])


func test_a_row_shows_result_floors_seed_and_tags() -> void:
	await _start(_meta_with(1))
	await _open_log()
	var row: Dictionary = _rig.top()._model.rows[0]
	assert_str(str(row.result)).starts_with("Defeat on floor 5 by ")
	assert_str(str(row.floors)).is_equal("4 of 8")
	assert_bool(row.retried).is_true()
	assert_array(RunUiRig.texts(_rig.top()).filter(func(text: String) -> bool: return text.contains(tr("log.retried")))).is_not_empty()


func test_an_opaque_row_says_details_unavailable_and_has_no_open() -> void:
	# Arrange
	var meta: RunUiRig.FakeMeta = _meta_with(1)
	meta.log_rows[0]["schema_version"] = RunRecord.SCHEMA_VERSION + 1
	await _start(meta)

	# Act
	await _open_log()

	# Assert
	assert_str(str(_rig.top()._model.rows[0].result)).is_equal(tr("log.details_unavailable"))
	assert_object(RunUiRig.button(_rig.top(), tr("log.open"))).is_null()


func test_a_row_naming_removed_ids_still_opens() -> void:
	# Edge Cases "a run record in the log references an id that no longer exists"
	var meta: RunUiRig.FakeMeta = _meta_with(1)
	meta.log_rows[0]["hero_id"] = "hero_gone"
	await _start(meta)
	await _open_log()
	assert_str(str(_rig.top()._model.rows[0].hero)).is_equal(tr("common.removed").format({"id": "hero_gone"}))
	_rig.intent(&"open_run", {"run_id": "row-00"})
	await _rig.settle()
	assert_str(_top()).is_equal("run_detail")


func test_open_shows_the_detail_over_the_log_and_back_returns() -> void:
	await _start(_meta_with(2))
	await _open_log()
	_rig.intent(&"open_run", {"run_id": "row-00"})
	await _rig.settle()
	assert_str(_top()).is_equal("run_detail")
	assert_str(String(_rig.shell.screen())).is_equal("run_log")
	_rig.intent(&"back")
	await _rig.settle()
	assert_str(_top()).is_equal("run_log")


func test_the_filter_is_local_and_narrows_the_rows() -> void:
	# Arrange
	var meta: RunUiRig.FakeMeta = _meta_with(3)
	meta.log_rows[1]["hero_id"] = "hero_decay"
	await _start(meta)
	await _open_log()
	var screen: Screen = _rig.top()
	var calls: int = meta.calls.size()

	# Act
	var picker: OptionButton = screen.find_children("*", "OptionButton", true, false)[0]
	for index: int in picker.item_count:
		if str(picker.get_item_metadata(index)) == "hero_decay":
			picker.select(index)
			picker.item_selected.emit(index)
			break
	await _rig.settle()

	# Assert
	assert_int(screen._rows_box.get_child_count()).is_equal(1)
	assert_int(meta.calls.size()).is_equal(calls)
	assert_array(_rig.rejected).is_empty()


func test_zero_runs_shows_the_empty_line_with_new_run_focused() -> void:
	await _start(_meta_with(0))
	await _open_log()
	assert_array(RunUiRig.texts(_rig.top())).contains([tr("log.empty")])
	assert_str((_rig.focus() as Button).text).is_equal(tr("menu.new_run"))
	await _rig.key(KEY_ENTER)
	await _rig.settle()
	assert_str(String(_rig.shell.screen())).is_equal("hero_select")


# --- Replays ------------------------------------------------------------------------

func test_a_real_run_lists_its_match_and_plays_it_and_returns() -> void:
	# Arrange
	await _played_run_on_the_log()
	assert_int(int(_rig.top()._model.rows[0].replays)).is_equal(1)
	assert_object(RunUiRig.button(_rig.top(), tr("log.replays"))).is_not_null()

	# Act: the list
	await _open_replays()
	assert_str(_top()).is_equal("replay_list")
	var label: String = tr("replay.row").format({"floor": 1, "attempt": 1})
	var play: Button = RunUiRig.button(_rig.top(), label)
	assert_object(play).is_not_null()
	assert_object(_rig.focus()).is_same(play)

	# Act: the viewer
	await _rig.key(KEY_ENTER)
	await _rig.settle()
	var view: Control = _rig.view()
	assert_object(view).is_not_null()
	assert_bool(view._controller.is_read_only()).is_true()
	assert_bool(_rig.shell._stack.visible).is_false()
	assert_str(String(_rig.shell.screen())).is_equal("run_log")

	# Act: out of it
	view.close_replay()
	await _rig.settle()

	# Assert: back on the list, nothing moved, the row focused again
	assert_object(_rig.view()).is_null()
	assert_bool(_rig.shell._stack.visible).is_true()
	assert_str(_top()).is_equal("replay_list")
	assert_object(_rig.focus()).is_not_null()
	_rig.intent(&"back")
	await _rig.settle()
	assert_str(_top()).is_equal("run_log")


func test_input_goes_to_the_viewer_not_the_list_under_it() -> void:
	# Arrange
	await _played_run_on_the_log()
	await _open_replays()
	await _rig.key(KEY_ENTER)
	await _rig.settle()

	# Act
	await _rig.key(KEY_ESCAPE)
	await _rig.settle()

	# Assert
	assert_str(_top()).is_equal("replay_list")
	assert_array(_rig.rejected).is_empty()


func test_a_log_of_other_data_stays_listed_with_its_reason() -> void:
	# Arrange: the log says it was written on other data
	await _played_run_on_the_log()
	var path: String = _first_log_path()
	var text: String = FileAccess.get_file_as_string(path).replace(_rig.db.data_version(), "0000")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

	# Act
	await _open_replays()

	# Assert: no button for it; the label and the reason
	var label: String = tr("replay.row").format({"floor": 1, "attempt": 1})
	assert_object(RunUiRig.button(_rig.top(), label)).is_null()
	assert_array(RunUiRig.texts(_rig.top())).contains([label, tr(MatchReplay.KEY_DATA)])
	assert_str(tr(MatchReplay.KEY_DATA)).is_not_equal(MatchReplay.KEY_DATA)
	assert_str((_rig.focus() as Button).text).is_equal(tr("common.back"))


func test_a_refused_log_changes_nothing_when_asked_to_play() -> void:
	# Arrange
	await _played_run_on_the_log()
	var path: String = _first_log_path()
	var text: String = FileAccess.get_file_as_string(path).replace(_rig.db.data_version(), "0000")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	await _open_replays()
	var focus_before: Control = _rig.focus()

	# Act
	_rig.intent(&"play_replay", {"path": path, "hero_id": "hero_war", "boss_id": ""})
	await _rig.settle()

	# Assert
	assert_object(_rig.view()).is_null()
	assert_bool(_rig.shell._stack.visible).is_true()
	assert_str(_top()).is_equal("replay_list")
	assert_object(_rig.focus()).is_same(focus_before)


func test_a_log_that_is_gone_or_broken_is_refused_as_unreadable() -> void:
	# Arrange
	await _played_run_on_the_log()
	var path: String = _first_log_path()
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{not json")
	file.close()

	# Act
	var broken: Dictionary = MatchReplay.inspect(path, _rig.db)
	var gone: Dictionary = MatchReplay.inspect("user://run_ui_rig/no_such_log.json", _rig.db)
	_rig.shell.swap_in_replay("user://run_ui_rig/no_such_log.json", "hero_war", "")

	# Assert
	assert_bool(broken.replayable).is_false()
	assert_str(str(broken.reason_key)).is_equal(MatchReplay.KEY_UNREADABLE)
	assert_str(str(gone.reason_key)).is_equal(MatchReplay.KEY_UNREADABLE)
	assert_object(_rig.view()).is_null()


func test_a_run_with_no_archived_logs_has_no_replays_button() -> void:
	await _start(_meta_with(1))
	await _open_log()
	assert_int(int(_rig.top()._model.rows[0].replays)).is_equal(0)
	assert_object(RunUiRig.button(_rig.top(), tr("log.replays"))).is_null()


# --- Row cost -----------------------------------------------------------------------

func _touch(folder: String, file_name: String) -> void:
	var _made: Error = DirAccess.make_dir_recursive_absolute(folder)
	var file: FileAccess = FileAccess.open(folder.path_join(file_name), FileAccess.WRITE)
	file.store_string("{}")
	file.close()


func test_archive_counts_equal_archives_per_run() -> void:
	# Arrange: logs, fault-only logs, a fault beside a log, a look-alike id, and no files
	_touch(COST_ROOT + "run-a", "floor_1_attempt_1.json")
	_touch(COST_ROOT + "run-a", "floor_2_attempt_1.json")
	_touch(COST_ROOT + "run-b", "floor_1_attempt_1.json")
	var faults: String = COST_ROOT + EventLogArchive.FAULTS_FOLDER
	_touch(faults, "run-a_floor_2_attempt_1.json")
	_touch(faults, "run-a_floor_3_attempt_1.json")
	_touch(faults, "run-c_floor_1_attempt_2.json")
	_touch(faults, "run-c_x_floor_1_attempt_1.json")
	var ids: Array = ["run-a", "run-b", "run-c", "run-d"]

	# Act
	var counts: Dictionary = MatchReplay.archive_counts(ids, COST_ROOT)

	# Assert
	for run_id: String in ids:
		assert_int(int(counts[run_id])).override_failure_message(run_id).is_equal(MatchReplay.archives(run_id, COST_ROOT).size())
	assert_int(int(counts["run-a"])).is_equal(3)
	assert_int(int(counts["run-c"])).is_equal(1)
	assert_int(int(counts["run-d"])).is_equal(0)


func test_a_page_reads_the_faults_folder_once_not_once_per_row() -> void:
	# Arrange: the shape of a long profile; a listing is what grows
	var scans: Array[int] = [0]
	var models: RunReadModels = RunReadModels.new(RunUiRig.FakeMeta.new(RunUiRig.database()), RunUiRig.database(), RunUiRig.config())
	models.archive_counter = func(ids: Array) -> Dictionary:
		scans[0] += 1
		var counts: Dictionary = {}
		for run_id: Variant in ids:
			counts[run_id] = 2
		return counts
	var entries: Array = []
	for i: int in PAGE:
		entries.append(_record(i))

	# Act
	var model: Dictionary = models.run_log(entries, PAGE)

	# Assert
	assert_int(scans[0]).is_equal(1)
	assert_int(int(model.rows[PAGE - 1].replays)).is_equal(2)
