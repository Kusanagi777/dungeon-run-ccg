extends GdUnitTestSuite

const COLLECTION: String = "law-of-the-jungle"
var _rig: RunUiRig


func before() -> void:
	RunUiRig.install_input()


func after() -> void:
	RunUiRig.restore_input()


func after_test() -> void:
	if _rig != null:
		_rig.finish()
	_rig = null
	RunUiRig.wipe_profiles()


func test_locked_collection_is_visible_but_cannot_be_featured() -> void:
	_rig = await RunUiRig.start(self, RunUiRig.facade("jungle_locked"))
	_rig.intent(&"new_run_requested")
	await _rig.settle()
	var picker: OptionButton = _rig.shell.find_child("FeaturedCollection", true, false)
	assert_object(picker).is_not_null()
	assert_int(picker.item_count).is_equal(3)
	assert_bool(picker.is_item_disabled(1)).is_true()
	assert_str(str(picker.get_item_metadata(0))).is_equal("")


func test_collection_screen_exposes_requirements_and_the_real_loaner() -> void:
	_rig = await RunUiRig.start(self, RunUiRig.facade("jungle_trial_view"))
	_rig.intent(&"new_run_requested")
	await _rig.settle()
	_rig.intent(&"open_collections")
	await _rig.settle()
	assert_str(str(_rig.shell.screen())).is_equal("collections")
	var action: Button = _rig.shell.find_child("TrialAction", true, false)
	assert_object(action).is_not_null()
	assert_bool(action.disabled).is_true()
	var model: Dictionary = _rig.controller._model_for(RunController.SCREEN_COLLECTIONS)
	assert_bool(model.loaner.is_empty()).is_false()
	assert_bool(model.trial.access.met).is_false()
	_rig.intent(&"back")
	await _rig.settle()
	assert_str(str(_rig.shell.screen())).is_equal("hero_select")


func test_selected_unlocked_collection_reaches_the_saved_run() -> void:
	_rig = await RunUiRig.start(self)
	_rig.intent(&"new_run_requested")
	await _rig.settle()
	_rig.intent(&"start_run", {"hero_id": "hero_war", "seed_input": "jungle-ui", "collection_id": COLLECTION})
	await _rig.settle()
	assert_str(_rig.run.state.featured_collection_id).is_equal(COLLECTION)
	assert_str(str(_rig.meta.load_active_run().get("featured_collection_id", ""))).is_equal(COLLECTION)


func test_qualified_trial_opens_the_existing_match_view() -> void:
	_rig = await RunUiRig.start(self)
	var stats: Dictionary = ProfileSchema.empty_stats()
	stats.runs_won = 20
	for hero: Dictionary in _rig.db.heroes():
		stats.heroes[hero.id] = {"runs_won": 2}
	(_rig.meta as RunUiRig.FakeMeta).stats = stats
	_rig.intent(&"new_run_requested")
	await _rig.settle()
	_rig.intent(&"open_collections")
	await _rig.settle()
	_rig.intent(&"start_trial", {"trial_id": MasteryTrial.TRIAL_ID})
	await _rig.settle()
	assert_bool(_rig.controller._trial_match).is_true()
	assert_str(str(_rig.controller.state.base)).is_equal("match")
	assert_str(str(_rig.controller._trial.view().status)).is_equal("playing")


func test_collection_unlock_toast_uses_the_authored_name() -> void:
	_rig = await RunUiRig.start(self)
	var models: RunReadModels = RunReadModels.new(_rig.meta, _rig.db, _rig.db.config("run_ui"))
	var toast: Dictionary = models.unlock_toast("collection_law_of_the_jungle", "collection", COLLECTION)
	assert_str(toast.title).is_equal("New expansion unlocked: Law of the Jungle")
	assert_str(toast.subtitle).is_equal("Primal Crown completed.")


func test_completed_trial_with_failed_save_offers_save_retry() -> void:
	var screen: Screen = auto_free(preload("res://src/ui/run/screens/collections.gd").new())
	screen.cfg = RunUiRig.config()
	var sent: Array = []
	screen.intent_requested.connect(func(action: StringName, args: Dictionary) -> void: sent.append([action, args]))
	screen.bind({
		"collections": [{"name": "Law of the Jungle", "description": "", "unlocked": false, "trial_id": MasteryTrial.TRIAL_ID}],
		"trial": {"trial_id": MasteryTrial.TRIAL_ID, "status": "completed", "access": {"met": true}, "error": "Save failed"},
	})
	var button: Button = screen.find_child("TrialAction", true, false)
	assert_bool(button.disabled).is_false()
	assert_str(button.text).is_equal("Save trial completion")
	button.pressed.emit()
	assert_array(sent).is_equal([[&"retry_trial_save", {"trial_id": MasteryTrial.TRIAL_ID}]])
