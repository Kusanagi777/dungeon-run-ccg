## The `unlocks` read model over a real `MetaFacade`: `MetaStub` answers every key as met,
## so only a real evaluator shows the locked rows, their progress and the hero's name.
extends GdUnitTestSuite

const SHIPPED_GATED_RECORDS: int = 19


func after_test() -> void:
	RunUiRig.wipe_profiles()


func _rows(model: Dictionary) -> Dictionary:
	var by_id: Dictionary = {}
	for section: Dictionary in model.sections:
		for row: Dictionary in section.rows:
			by_id[str(row.id)] = row
	return by_id


func test_a_fresh_profile_lists_each_gated_treasure_locked_with_its_condition() -> void:
	# Arrange
	var db: CardDatabase = RunUiRig.database()
	var models: RunReadModels = RunReadModels.new(RunUiRig.facade("unlocks_fresh"), db, db.config("run_ui"))

	# Act
	var model: Dictionary = models.unlocks()
	var rows: Dictionary = _rows(model)

	# Assert
	assert_int(rows.size()).is_equal(SHIPPED_GATED_RECORDS)
	assert_str(str(model.count_line)).is_equal(tr("unlocks.count").format({"n": 0, "total": SHIPPED_GATED_RECORDS}))
	for row: Dictionary in rows.values():
		assert_bool(bool(row.unlocked)).override_failure_message(str(row.id)).is_false()
	assert_str(str(rows.treasure_living_armory.condition)).is_equal("Win a run")
	assert_str(str(rows.treasure_living_armory.progress)).is_equal("0 / 1")
	assert_str(str(rows.treasure_grave_tithe.condition)).is_equal("Win a run as Mother Wythe")
	assert_str(str(rows.treasure_plague_bell.condition)).is_equal("Reach floor 5 as Mother Wythe")
	assert_str(str(rows.treasure_plague_bell.progress)).is_equal("0 / 5")
