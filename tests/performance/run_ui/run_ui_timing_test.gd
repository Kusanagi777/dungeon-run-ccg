## Run UI against the clock (run-ui AC-23, AC-26; F1). Wall time, so this lives with the
## performance suites, outside the normal run. AC-26 names a reference machine: until one
## is set, a number here is this machine's.
extends GdUnitTestSuite

## F1 path A at defaults, and AC-23's allowance.
const PATH_A_MS: float = 1350.0
const PATH_A_MARGIN: float = 1.15
## Path B's scripted human pause, and its ceiling.
const HUMAN_PICK_MS: int = 1500
const PATH_B_LIMIT_MS: int = 5000
## AC-26.
const SCREEN_BUILD_MS: int = 100
const SUMMARY_BUILD_MS: int = 50
const SCREENS: Array = [
	["fresh_profile", &"main_menu"], ["fresh_profile", &"hero_select"], ["mid_run_floor4", &"boss_intro"],
	["draft_treasure_sample", &"draft_treasure"], ["draft_bundle_sample", &"draft_bundle"],
	["victory_sample", &"summary_victory"], ["defeat_sample", &"summary_defeat"],
]
## The cap of Meta's run log: the most rows a screen can hold.
const LOG_ROWS: int = 200
const RECORD_FIXTURE: String = "res://tests/fixtures/run_ui/defeat_sample.json"

var _rig: RunUiRig = null


func before() -> void:
	RunUiRig.install_input()


func after() -> void:
	RunUiRig.restore_input()


func after_test() -> void:
	if _rig != null:
		_rig.finish()
		_rig = null


func _to_defeat() -> void:
	_rig = await RunUiRig.start(self, null, {"anim_speed": "normal"})
	_rig.intent(&"skip")
	await _rig.settle()
	_rig.intent(&"new_run_requested")
	_rig.intent(&"skip")
	await _rig.settle()
	_rig.intent(&"start_run", {"hero_id": "hero_war", "seed_input": ""})
	_rig.intent(&"skip")
	await _rig.settle()
	_rig.intent(&"skip")
	await _rig.settle()
	await _rig.lose_floor()
	_rig.intent(&"skip")
	await _rig.settle()


func _boss_frame() -> int:
	while _rig.shell.screen() != &"boss_intro":
		await get_tree().process_frame
	await get_tree().process_frame
	return Time.get_ticks_msec()


func test_ac23_path_a_from_enter_to_the_boss_intro() -> void:
	# Arrange
	await _to_defeat()

	# Act
	var began: int = Time.get_ticks_msec()
	_rig.top().default_focus().pressed.emit()
	var ended: int = await _boss_frame()

	# Assert
	var took: int = ended - began
	print("AC-23 path A: %d ms" % took)
	assert_int(took).is_less_equal(int(PATH_A_MS * PATH_A_MARGIN))
	assert_int(took).is_less_equal(int(RunUiRig.config().restart_budget_ms))


func test_ac23_path_b_through_hero_select_with_the_scripted_pause() -> void:
	# Arrange
	await _to_defeat()

	# Act
	var began: int = Time.get_ticks_msec()
	_rig.intent(&"go_hero_select")
	await get_tree().create_timer(HUMAN_PICK_MS / 1000.0).timeout
	_rig.intent(&"start_run", {"hero_id": "hero_war", "seed_input": ""})
	var ended: int = await _boss_frame()

	# Assert
	var took: int = ended - began
	print("AC-23 path B: %d ms" % took)
	assert_int(took).is_less_equal(PATH_B_LIMIT_MS)


func test_ac26_every_base_screen_builds_inside_the_budget() -> void:
	for row: Array in SCREENS:
		# Arrange
		var loader: RunDebugLoader = RunDebugLoader.new()
		var overrides: Dictionary = loader.load_fixture(row[0])
		_rig = await RunUiRig.start(self, overrides.meta, RunUiRig.INSTANT)

		# Act: warm once, then the time of a build and one frame
		loader.open(_rig.shell, row[1])
		await get_tree().process_frame
		var began: int = Time.get_ticks_usec()
		loader.open(_rig.shell, row[1])
		await get_tree().process_frame
		var took_ms: float = (Time.get_ticks_usec() - began) / 1000.0

		# Assert
		print("AC-26 %s: %.1f ms" % [row[1], took_ms])
		assert_float(took_ms).override_failure_message(String(row[1])).is_less_equal(float(SCREEN_BUILD_MS))
		_rig.finish()
		_rig = null


func test_ac26_the_victory_summary_model_builds_inside_its_budget() -> void:
	# Arrange
	var loader: RunDebugLoader = RunDebugLoader.new()
	var overrides: Dictionary = loader.load_fixture("victory_sample")
	_rig = await RunUiRig.start(self, overrides.meta, RunUiRig.INSTANT)
	loader.open(_rig.shell, &"summary_victory")
	await get_tree().process_frame

	# Act
	var began: int = Time.get_ticks_usec()
	var _model: Dictionary = _rig.controller._model_for(RunController.SCREEN_VICTORY)
	var took_ms: float = (Time.get_ticks_usec() - began) / 1000.0

	# Assert
	print("AC-26 summary model: %.2f ms" % took_ms)
	assert_float(took_ms).is_less_equal(float(SUMMARY_BUILD_MS))


func test_a_full_run_log_builds_its_page_inside_the_screen_budget() -> void:
	# Arrange: the log's cap of rows, one page of them
	var meta: RunUiRig.FakeMeta = RunUiRig.FakeMeta.new(RunUiRig.database())
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RECORD_FIXTURE))
	for i: int in LOG_ROWS:
		var row: Dictionary = RunRecord.normalised(parsed.record)
		row["run_id"] = "row-%03d" % i
		row["schema_version"] = RunRecord.SCHEMA_VERSION
		meta.log_rows.append(row)
	_rig = await RunUiRig.start(self, meta, RunUiRig.INSTANT)

	# Act
	var began: int = Time.get_ticks_usec()
	_rig.intent(&"open_run_log")
	await get_tree().process_frame
	var page_ms: float = (Time.get_ticks_usec() - began) / 1000.0
	began = Time.get_ticks_usec()
	for _i: int in LOG_ROWS / int(RunUiRig.config().run_log_page) - 1:
		_rig.intent(&"load_more")
	await get_tree().process_frame
	var all_ms: float = (Time.get_ticks_usec() - began) / 1000.0

	# Assert
	print("run_log first page: %.1f ms, the other 180 rows: %.1f ms" % [page_ms, all_ms])
	assert_float(page_ms).is_less_equal(float(SCREEN_BUILD_MS))
