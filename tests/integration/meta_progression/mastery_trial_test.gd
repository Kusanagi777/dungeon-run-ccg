extends GdUnitTestSuite

const PREDATOR: String = "trial_fixture_predator"
const PREY: String = "trial_fixture_prey"
const FILLER: String = MatchDriverFixture.VANILLA
const KEY: String = "collection_law_of_the_jungle"
const BOOT_SCRIPT := preload("res://src/core/boot.gd")

class TrialDatabase:
	extends MatchDriverFixture.FixtureDatabase

	func data_version() -> String:
		return "trial_fixture_v1"

	func collections() -> Array:
		return [{"id": MasteryTrial.COLLECTION_ID, "name": "Law of the Jungle"}]

	func treasure_pool(_collection_id: String = "") -> Array:
		return [records.treasure_a, records.treasure_b, records.treasure_c]

	func treasure(id: String) -> Variant:
		return records.get(id)

	func hero(id: String) -> Variant:
		return records.get(id)

	func bundle_pool(_hero_set: String, _collection_id: String = "") -> Array:
		return []

	func collectible_pool(_hero_set: String, _collection_id: String = "") -> Array:
		return []

var _root: String
var _meta: MetaFacade
var _trial: MasteryTrial
var _db: TrialDatabase
var _writer: ProfileFixtures.FaultWriter
var _clock: ProfileFixtures.ManualClock


func before_test() -> void:
	_root = ProfileFixtures.new_root()
	_db = _database()
	_writer = ProfileFixtures.FaultWriter.new()
	_clock = ProfileFixtures.ManualClock.new()
	_meta = ProfileFixtures.facade(ProfileFixtures.store(_root, _clock, {}, _writer), _db)
	_meta.load_profile()
	_qualify()
	_trial = MasteryTrial.new(_db, _meta, func() -> PlannerTask: return ImmediatePlannerTask.new())


func after_test() -> void:
	_trial.shutdown()
	_meta.store().release_lock()
	ProfileFixtures.remove_root(_root)


func _qualify() -> void:
	_meta.store().live_profile().stats.runs_won = 20
	for hero_id: String in MasteryTrial.HERO_IDS:
		_meta.store().live_profile().stats.heroes[hero_id] = {"runs_won": 2}


func _database() -> TrialDatabase:
	var base: MatchDriverFixture.FixtureDatabase = MatchDriverFixture.database()
	var records: Dictionary = base.records.duplicate(true)
	var effect: Dictionary = CardFactory.make_effect("battlecry", [{"op": "buff", "attack": 1, "health": 1}], {"selector": "self"},
		{"condition": {"exists": {"selector": "all_minions", "filter": {"tribe": "plant", "not_self": true}}}})
	records[PREDATOR] = CardFactory.make_minion(PREDATOR, 0, 30, 4, ["battlecry", "charge"], {"effects": [effect]})
	records[PREY] = CardFactory.make_minion(PREY, 0, 0, 2, [], {"tribes": ["plant"]})
	for id: String in ["treasure_a", "treasure_b", "treasure_c"]:
		records[id] = CardFactory.make_treasure_def(id, "common", ["universal"], {"effects": []})
	var db: TrialDatabase = TrialDatabase.new(records)
	db.bodies = base.bodies.duplicate(true)
	db.bodies["profile_defaults"] = ProfileFixtures.defaults_body()
	db.bodies["rng_event_log"] = {"log_memory_budget_bytes": 2000000, "avg_event_bytes": 200}
	db.bodies["treasures_balance"] = {}
	var deck: Array = [PREDATOR, PREDATOR, PREDATOR]
	deck.append_array(MatchDriverFixture.deck_of(FILLER, 33))
	var encounters: Array = []
	for index: int in 3:
		encounters.append({"id": "encounter_%d" % index, "boss_id": MatchDriverFixture.BOSS_ID,
			"band": 1, "health": 20, "deck": MatchDriverFixture.deck_of(FILLER),
			"player_opening_board": [PREY], "enemy_opening_board": [PREY]})
	db.bodies[MasteryTrial.COLLECTION_ID + "/trial"] = {"id": MasteryTrial.TRIAL_ID,
		"collection": MasteryTrial.COLLECTION_ID, "hero_id": "hero_war", "deck": deck,
		"treasures": ["treasure_a", "treasure_b", "treasure_c"], "encounters": encounters}
	var gate: Dictionary = MasteryTrial.access_condition()
	gate.of.append({"type": "trial_completed", "trial_id": MasteryTrial.TRIAL_ID})
	db.bodies[MasteryTrial.COLLECTION_ID + "/unlock"] = {"key": KEY, "condition": gate}
	return db


func _play_predators(count: int = 3) -> void:
	var driver: MatchDriver = _trial.driver()
	assert_bool(driver.submit(driver.legal_commands()[0]).accepted).is_true()
	for _index: int in count:
		assert_bool(driver.submit(MatchRecords.play_card("player", 0, 0)).accepted).is_true()


func _win() -> void:
	for command: Dictionary in _trial.driver().legal_commands():
		if command.type == "attack" and command.target_id == _trial.driver().query().snapshot("boss").hero.entity_id:
			assert_bool(_trial.driver().submit(command).accepted).is_true()
			return
	assert_bool(false).override_failure_message("No legal lethal attack").is_true()


func test_access_requires_twenty_wins_and_each_explicit_hero() -> void:
	_meta.store().live_profile().stats.runs_won = 19
	assert_int(_trial.start()).is_equal(SaveErrors.E_RANGE)
	_meta.store().live_profile().stats.runs_won = 20
	_meta.store().live_profile().stats.heroes.hero_shadow.runs_won = 1
	assert_int(_trial.start()).is_equal(SaveErrors.E_RANGE)
	_meta.store().live_profile().stats.heroes.hero_shadow.runs_won = 2
	assert_int(_trial.start()).is_equal(OK)
	assert_bool(_meta.is_collection_unlocked(MasteryTrial.COLLECTION_ID)).is_false()


func test_debug_unlock_all_opens_a_locked_collection_but_not_an_unknown_one() -> void:
	# Arrange: the trial is not complete, so the real gate keeps the collection shut
	assert_bool(_meta.is_collection_unlocked(MasteryTrial.COLLECTION_ID)).is_false()

	# Act
	_meta.debug_unlock_all_collections = true

	# Assert
	assert_bool(_meta.is_collection_unlocked(MasteryTrial.COLLECTION_ID)).is_true()
	assert_bool(_meta.is_collection_unlocked("collection_that_does_not_exist")).is_false()
	assert_bool(_meta.is_unlocked("collection_law_of_the_jungle")).is_false()


func test_both_boards_count_one_successful_activation() -> void:
	assert_int(_trial.start()).is_equal(OK)
	_play_predators(1)
	assert_dict(_trial.view().objectives).is_equal({"predator": 1, "friendly": 1, "enemy": 1})


func test_three_friendly_only_bonuses_do_not_satisfy_enemy_objective() -> void:
	_db.bodies[MasteryTrial.COLLECTION_ID + "/trial"].encounters[0].enemy_opening_board = []
	assert_int(_trial.start()).is_equal(OK)
	_play_predators()
	assert_dict(_trial.view().objectives).is_equal({"predator": 3, "friendly": 3, "enemy": 0})
	_win()
	assert_str(_trial.view().status).is_equal("failed")


func test_condition_failure_does_not_count_a_predator_play() -> void:
	var encounter: Dictionary = _db.bodies[MasteryTrial.COLLECTION_ID + "/trial"].encounters[0]
	encounter.player_opening_board = []
	encounter.enemy_opening_board = []
	assert_int(_trial.start()).is_equal(OK)
	_play_predators()
	assert_dict(_trial.view().objectives).is_equal({"predator": 0, "friendly": 0, "enemy": 0})


func test_winning_without_objectives_fails_and_retry_is_immediate() -> void:
	assert_int(_trial.start()).is_equal(OK)
	_play_predators(1)
	_win()
	assert_str(_trial.view().status).is_equal("failed")
	assert_bool(_meta.is_collection_unlocked(MasteryTrial.COLLECTION_ID)).is_false()
	assert_int(_trial.retry()).is_equal(OK)
	assert_int(_trial.view().encounter_index).is_equal(0)
	assert_int(_trial.view().objectives.predator).is_equal(0)
	assert_int(_meta.get_stats().runs_won).is_equal(20)


func test_resume_replays_commands_and_ignores_forged_counters() -> void:
	assert_int(_trial.start()).is_equal(OK)
	_play_predators(1)
	var before: Dictionary = _trial.driver().query().snapshot("player")
	_meta.store().live_profile().active_trial["objectives"] = {"predator": 99, "friendly": 99, "enemy": 99}
	_meta.store().live_profile().active_trial["status"] = "completed"
	assert_int(_trial.resume()).is_equal(OK)
	assert_dict(_trial.driver().query().snapshot("player")).is_equal(before)
	assert_int(_trial.view().objectives.predator).is_equal(1)
	assert_bool(_trial.verified_complete()).is_false()
	assert_bool(_meta.is_collection_unlocked(MasteryTrial.COLLECTION_ID)).is_false()


func test_new_facade_resumes_the_persisted_attempt_from_disk() -> void:
	assert_int(_trial.start()).is_equal(OK)
	_play_predators(1)
	var before: Dictionary = _trial.driver().query().snapshot("player")
	var source: String = _trial.source_id()
	_trial.shutdown()
	_meta.store().release_lock()
	_meta = ProfileFixtures.facade(ProfileFixtures.store(_root, _clock), _db)
	_meta.load_profile()
	_trial = MasteryTrial.new(_db, _meta, func() -> PlannerTask: return ImmediatePlannerTask.new())
	assert_int(_trial.resume()).is_equal(OK)
	assert_str(_trial.source_id()).is_equal(source)
	assert_dict(_trial.driver().query().snapshot("player")).is_equal(before)
	assert_dict(_trial.view().objectives).is_equal({"predator": 1, "friendly": 1, "enemy": 1})
	assert_int(_meta.get_stats().runs_won).is_equal(20)


func test_interrupted_boss_plan_resumes_its_exact_remaining_commands() -> void:
	assert_int(_trial.start()).is_equal(OK)
	var original: MatchDriver = _trial.driver()
	assert_bool(original.submit(original.legal_commands()[0]).accepted).is_true()
	original.tick()
	assert_bool(original.submit(MatchRecords.end_turn("player")).accepted).is_true()
	# Script a real, engine-verified plan and interrupt between its accepted plays.
	original._release_task()
	var plan: TurnPlan = MatchDriverFixture.scripted_plan(original, [
		MatchRecords.play_card("boss", 0, 0), MatchRecords.play_card("boss", 0, 0), MatchRecords.end_turn("boss")])
	original._take_plan(plan)
	original._replay_one()
	var interrupted: Dictionary = _meta.load_trial()
	assert_int(interrupted.continuation.replay_index).is_equal(1)
	original._replay_one()
	original._replay_one()
	var expected_commands: Array = original.commands()
	var expected_player: Dictionary = original.query().snapshot("player")
	var expected_boss: Dictionary = original.query().snapshot("boss")
	_meta.store().live_profile().active_trial = ProfileSchema.normalised(JSON.parse_string(JSON.stringify(interrupted)))
	assert_int(_trial.resume()).is_equal(OK)
	var resumed: MatchDriver = _trial.driver()
	assert_bool(resumed._pending_plan != null).is_true()
	resumed._replay_one()
	resumed._replay_one()
	assert_array(resumed.commands()).is_equal(expected_commands)
	assert_dict(resumed.query().snapshot("player")).is_equal(expected_player)
	assert_dict(resumed.query().snapshot("boss")).is_equal(expected_boss)
	var faults: Array = resumed.events_since(0).filter(func(event: Dictionary) -> bool:
		return event.type == "ai_fault" and event.payload.get("reason") == MatchDriver.FAULT_REPLAY_DIVERGENCE)
	assert_array(faults).is_empty()


func test_save_settles_forecast_and_restores_its_intent_without_new_rng_draws() -> void:
	assert_int(_trial.start()).is_equal(OK)
	var driver: MatchDriver = _trial.driver()
	assert_bool(driver.submit(driver.legal_commands()[0]).accepted).is_true()
	assert_bool(driver._task != null).is_true()
	assert_int(_meta.save_trial(_trial)).is_equal(OK)
	assert_bool(driver._task == null).is_true()
	var saved: Dictionary = _meta.load_trial()
	assert_bool(saved.continuation.forecast is Dictionary).is_true()
	assert_int(_trial.resume()).is_equal(OK)
	assert_bool(_trial.driver()._task == null).is_true()
	assert_dict(_trial.driver()._boss_ai.last_forecast.to_dict()).is_equal(saved.continuation.forecast)
	assert_dict(_trial.record().ai_snapshot).is_equal(saved.ai_snapshot)


func test_three_encounters_grant_once_atomically_without_regular_run_stats() -> void:
	var grants: Array = []
	_meta.unlock_granted.connect(func(key: String, _kind: StringName, _id: String, _source: String, _retro: bool) -> void:
		var disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_root.path_join("profile.json")))
		grants.append([key, disk.stats.trials[MasteryTrial.TRIAL_ID].completed, disk.unlocks[key].unlocked]))
	_meta.store().live_profile()["unrelated"] = {"preserved": true}
	assert_int(_trial.start()).is_equal(OK)
	for index: int in 3:
		_play_predators()
		_win()
		if index < 2:
			assert_str(_trial.view().status).is_equal("encounter_won")
			assert_int(_trial.next_encounter()).is_equal(OK)
	assert_str(_trial.view().status).is_equal("completed")
	assert_bool(_meta.is_collection_unlocked(MasteryTrial.COLLECTION_ID)).is_true()
	assert_array(grants).is_equal([[KEY, true, true]])
	assert_int(_meta.get_stats().runs_won).is_equal(20)
	assert_int(_meta.run_log_count()).is_equal(0)
	assert_bool(_meta.store().live_profile().unrelated.preserved).is_true()
	assert_int(_trial.resume()).is_equal(OK)
	assert_array(grants).has_size(1)
	assert_int(_meta.pending_notifications().size()).is_equal(1)


func test_trial_completed_leaf_requires_authoritative_trial_stat() -> void:
	var evaluator: UnlockEvaluator = UnlockEvaluator.new(_db, ProfileFixtures.knobs())
	var condition: Dictionary = {"type": "trial_completed", "trial_id": MasteryTrial.TRIAL_ID}
	assert_bool(evaluator.met(condition, {"runs_won": 999})).is_false()
	assert_bool(evaluator.met(condition, {"trials": {MasteryTrial.TRIAL_ID: {"completed": true}}})).is_true()


func test_failed_completion_write_never_announces_or_partially_grants() -> void:
	var grants: Array = []
	_meta.unlock_granted.connect(func(key: String, _kind: StringName, _id: String, _source: String, _retro: bool) -> void: grants.append(key))
	assert_int(_trial.start()).is_equal(OK)
	for _index: int in 2:
		_play_predators()
		_win()
		assert_int(_trial.next_encounter()).is_equal(OK)
	_play_predators()
	_writer.fail_at("W4")
	_win()
	assert_array(grants).is_empty()
	assert_bool(_meta.is_collection_unlocked(MasteryTrial.COLLECTION_ID)).is_false()
	assert_bool(_meta.get_stats().trials.has(MasteryTrial.TRIAL_ID)).is_false()
	_writer.clear()
	assert_int(_trial.retry_save()).is_equal(OK)
	assert_array(grants).is_equal([KEY])
	assert_bool(_meta.is_collection_unlocked(MasteryTrial.COLLECTION_ID)).is_true()


func test_authored_loaner_can_complete_three_encounters_through_legal_play() -> void:
	var boot: Node = auto_free(BOOT_SCRIPT.new())
	var db: CardDatabase = CardDatabase.new()
	var report: ValidationReport = db.load(boot._collect_validators(null, true))
	assert_int(report.errors().size()).is_equal(0)
	if db.state() != CardDatabase.State.READY:
		return
	_trial.shutdown()
	_meta.store().release_lock()
	_meta = ProfileFixtures.facade(ProfileFixtures.store(_root, _clock), db)
	_meta.load_profile()
	_qualify()
	_trial = MasteryTrial.new(db, _meta, func() -> PlannerTask: return ImmediatePlannerTask.new())
	assert_int(_trial.start()).is_equal(OK)
	for index: int in 3:
		await _play_authored_encounter(db, index)
		var model: Dictionary = _trial.view()
		print("authored_trial_encounter{index:%d,status:%s,objectives:%s}" % [index, model.status, str(model.objectives)])
		print("authored_trial_terminal{index:%d,result:%s,player:%s,boss:%s}" % [index,
			str(_trial.driver()._engine.result()), str(_trial.driver().query().snapshot("player")), str(_trial.driver().query().snapshot("boss"))])
		assert_str(model.status).is_equal("completed" if index == 2 else "encounter_won")
		if model.status != "encounter_won":
			break
		assert_int(_trial.next_encounter()).is_equal(OK)
	assert_str(_trial.view().status).is_equal("completed")
	assert_bool(_meta.is_collection_unlocked(MasteryTrial.COLLECTION_ID)).is_true()
	assert_int(_meta.get_stats().runs_won).is_equal(20)


func _play_authored_encounter(db: CardDatabase, index: int) -> void:
	var driver: MatchDriver = _trial.driver()
	assert_bool(driver.submit(driver.legal_commands()[0]).accepted).is_true()
	var definitions: Dictionary = db.config(MasteryTrial.COLLECTION_ID + "/trial")
	var encounter: Dictionary = definitions.encounters[index]
	var profiles: Dictionary = db.config("ai_profiles")
	var boss: Dictionary = db.boss(str(encounter.boss_id))
	var hero_profile: Dictionary = boss.duplicate(true)
	hero_profile["ai_profile"] = "control"
	var profile: Dictionary = ProfileResolver.resolve(profiles, hero_profile, int(encounter.band))
	var hero_rng: RngService = RngService.new(913 + index, db.data_version())
	var hero_ai: BossAI = BossAI.new(boss, profile, int(encounter.band), hero_rng.stream("ai_1"),
		profiles.op_values, driver._log, db, profiles.keyword_values, "boss")
	for _step: int in 300:
		if _trial.view().status != "playing":
			return
		if driver.query().active_side() == "boss" or driver.query().phase() == MatchState.PHASE_CHOICE:
			driver.tick()
			if driver.query().phase() == MatchState.PHASE_CHOICE:
				var pending: Variant = driver.query().pending_choice()
				if pending is Dictionary and pending.get("side") == "player":
					driver.submit(MatchRecords.choose("player", 0))
			continue
		var sandbox: RulesEngine = driver._engine.clone()
		var plan: TurnPlan = await hero_ai.plan_turn(sandbox)
		sandbox.end_match()
		for command: Dictionary in plan.commands:
			if _trial.view().status != "playing" or driver.query().active_side() != "player":
				break
			# Delay face attacks until the mastery objective is met; every applied
			# action still goes through the driver's ordinary player channel.
			if command.type == "attack" and command.target_id == driver.query().snapshot("boss").hero.entity_id and not _trial._objectives_met():
				continue
			driver.submit(command)
		if _trial.view().status == "playing" and driver.query().active_side() == "player" and driver.query().phase() == MatchState.PHASE_MAIN:
			driver.submit(MatchRecords.end_turn("player"))
		driver.tick()
