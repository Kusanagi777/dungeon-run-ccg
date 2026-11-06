## Integration: a real run through a real match (design/gdd/run-structure.md R3-R6,
## R9, AC-9 to AC-14, AC-28; ADR-0008 Decision 8; run-structure EPIC "a seeded run
## reproduces its boss sequence and drafts given the same picks, and resume after
## suspend regenerates the identical offer"). Shipped data, real `RewardDraft`,
## `Treasures` and `MatchDriver`; `MetaStub` holds the slot.
extends GdUnitTestSuite

const HERO: String = RunRealFixture.HERO_ID
const SEED: String = "42"
const OTHER_SEED: String = "43"
const LAST_FLOOR: int = TestConstants.FLOORS_PER_RUN
const FULL_DECK: int = 36
const NO_TREASURE_STATE: Dictionary = {"schema_version": 1, "by_treasure": {}}

var _db: CardDatabase = null
var _games: Array[RunRealFixture] = []


func before() -> void:
	_db = TreasureFixtures.shipped_database()


func after() -> void:
	_db = null


func after_test() -> void:
	for game: RunRealFixture in _games:
		game.release()
	_games.clear()


func _game(boss_health: int = RunRealFixture.ONE_BLOW) -> RunRealFixture:
	var game := RunRealFixture.new(_db)
	game.boss_health = boss_health
	_games.append(game)
	return game


func _started(game: RunRealFixture, meta: MetaApi, seed_input: String = SEED) -> RunMachine:
	var run: RunMachine = game.machine(meta)
	assert_int(run.new_run(HERO, seed_input)).is_equal(OK)
	return run


## Every `draft_offered` of a run, as text.
func _offers(run: RunMachine) -> Array:
	return RunHarness.events_of(run.run_log, RunCodes.EVENT_DRAFT_OFFERED).map(func(e: Dictionary) -> String: return JSON.stringify(e.payload))


func _full_run(game: RunRealFixture, meta: MetaApi, seed_input: String = SEED) -> RunMachine:
	var run: RunMachine = _started(game, meta, seed_input)
	for _f: int in LAST_FLOOR - 1:
		game.play_floor(run)
	game.play_out(run, game.begin(run))
	return run


# --- _on_match_ended through a real driver -----------------------------------

func test_hooks_answer_after_the_engine_is_torn_down() -> void:
	# Arrange
	var game: RunRealFixture = _game()
	var run: RunMachine = _started(game, MetaStub.new(_db))
	var driver: MatchDriver = game.begin(run)

	# Act
	game.concede(run, driver)

	# Assert
	assert_object(driver.hooks()).is_not_null()
	assert_bool(driver.hooks() is HookRegistry).is_true()


func test_a_played_concede_is_a_defeat_on_floor_one() -> void:
	# Arrange
	var game: RunRealFixture = _game()
	var meta := MetaStub.new(_db)
	var run: RunMachine = _started(game, meta)

	# Act
	game.concede(run, game.begin(run))

	# Assert
	assert_str(run.phase()).is_equal(RunState.STATUS_DEFEAT)
	assert_str(run.state.match_summaries[0].reason).is_equal(MatchRecords.REASON_CONCEDE)
	assert_str(run.state.match_summaries[0].result).is_equal(MatchRecords.RESULT_LOSS)
	assert_int(int(run.state.result.floors_cleared)).is_equal(0)
	assert_dict(run.state.treasure_state).is_equal(NO_TREASURE_STATE)
	assert_object(meta.load_active_run()).is_null()


func test_a_played_win_reaches_the_treasure_draft_with_the_s2_save_valid() -> void:
	# Arrange
	var game: RunRealFixture = _game()
	var meta := MetaStub.new(_db)
	var run: RunMachine = _started(game, meta)

	# Act
	game.play_out(run, game.begin(run))

	# Assert
	assert_str(run.phase()).is_equal(RunState.STATUS_POST_MATCH_REWARD)
	assert_str(str(run.state.reward_step)).is_equal(DraftRecord.KIND_TREASURE)
	assert_str(run.state.match_summaries[0].result).is_equal(MatchRecords.RESULT_WIN)
	assert_int(int(run.state.match_summaries[0].event_count)).is_greater(0)
	assert_int(int(run.state.match_summaries[0].turns)).is_greater(0)
	assert_int((run.current_offer().option_ids as Array).size()).is_equal(RunHarness.OFFER_SIZE)
	var saved: Variant = meta.load_active_run()
	assert_str(saved.status).is_equal(RunState.STATUS_POST_MATCH_REWARD)
	assert_bool((saved.rng_snapshot as Dictionary).is_empty()).is_false()
	assert_int(RunRecord.validate(JSON.parse_string(JSON.stringify(saved)), _db)).is_equal(OK)


func test_a_match_at_the_datas_own_health_runs_to_a_recorded_end() -> void:
	# Arrange: nothing lowered; whoever wins, the machine must leave in_match
	var game: RunRealFixture = _game(0)
	var run: RunMachine = _started(game, MetaStub.new(_db))

	# Act
	game.play_out(run, game.begin(run))

	# Assert
	assert_str(run.phase()).is_not_equal(RunState.STATUS_IN_MATCH)
	assert_int(run.state.match_summaries.size()).is_equal(1)
	assert_int(int(run.state.match_summaries[0].turns)).is_greater(1)
	assert_int(run.state.play_seconds).is_greater_equal(0)


func test_the_real_match_config_carries_the_boss_of_the_floor_at_its_data_health() -> void:
	# Arrange
	var game: RunRealFixture = _game(0)
	var run: RunMachine = _started(game, MetaStub.new(_db))

	# Act
	var _driver: MatchDriver = game.begin(run)

	# Assert
	var config: Dictionary = game.configs[0]
	var boss: Dictionary = _db.boss(run.state.boss_sequence[0])
	assert_str(config.boss.boss_def_id).is_equal(boss.id)
	assert_int(int(config.boss.health)).is_equal(int(boss.health))
	assert_str(config.boss.ai_id).is_equal(boss.ai_profile)
	assert_array(config.player.deck).is_equal(Array(_db.hero(HERO).starter_deck))


func test_the_drivers_engine_leaves_the_runs_deck_in_order() -> void:
	# Arrange
	var game: RunRealFixture = _game()
	var run: RunMachine = _started(game, MetaStub.new(_db))
	var before_match: Array = Array(run.state.deck).duplicate()

	# Act
	game.play_out(run, game.begin(run))

	# Assert
	assert_array(Array(run.state.deck)).is_equal(before_match)


# --- A whole run -------------------------------------------------------------

func test_a_full_played_run_ends_in_victory_with_the_36_card_deck() -> void:
	# Act
	var run: RunMachine = _full_run(_game(), MetaStub.new(_db))

	# Assert
	assert_str(run.phase()).is_equal(RunState.STATUS_VICTORY)
	assert_int(run.state.deck.size()).is_equal(FULL_DECK)
	assert_int(run.state.treasures.size()).is_equal(TestConstants.TREASURE_FLOORS.size())
	assert_int(int(run.state.totals.matches_played)).is_equal(LAST_FLOOR)
	assert_int(int(run.state.totals.cards_drafted)).is_equal(FULL_DECK - TestConstants.STARTER_DECK_SIZE)


func test_a_full_played_runs_record_validates_with_its_real_run_log() -> void:
	# Arrange
	var run: RunMachine = _full_run(_game(), MetaStub.new(_db))

	# Act
	var answer: Error = run.state.validate(_db)

	# Assert
	assert_int(answer).is_equal(OK)
	assert_str(str((run.state.run_log.events as Array).back().type)).is_equal(String(RunCodes.EVENT_RUN_ENDED))


func test_a_full_played_runs_record_round_trips_byte_identically() -> void:
	# Arrange
	var run: RunMachine = _full_run(_game(), MetaStub.new(_db))
	var first: String = JSON.stringify(RunRecord.to_dict(run.state))

	# Act
	var second: String = JSON.stringify(RunRecord.to_dict(RunRecord.from_dict(JSON.parse_string(first))))

	# Assert
	assert_str(second).is_equal(first)
	assert_int(first.to_utf8_buffer().size()).is_less(int(_db.config("run_structure").max_run_record_bytes))


func test_the_same_seed_and_picks_give_the_same_bosses_and_offers() -> void:
	# Act
	var first: RunMachine = _full_run(_game(), MetaStub.new(_db))
	var second: RunMachine = _full_run(_game(), MetaStub.new(_db))

	# Assert
	assert_array(Array(second.state.boss_sequence)).is_equal(Array(first.state.boss_sequence))
	assert_array(_offers(second)).is_equal(_offers(first))
	assert_array(Array(second.state.deck)).is_equal(Array(first.state.deck))


func test_another_seed_gives_other_offers() -> void:
	# Act
	var first: RunMachine = _full_run(_game(), MetaStub.new(_db))
	var other: RunMachine = _full_run(_game(), MetaStub.new(_db), OTHER_SEED)

	# Assert
	assert_array(_offers(other)).is_not_equal(_offers(first))


func test_suspend_and_resume_at_every_draft_change_nothing() -> void:
	# Arrange: the same run played straight through
	var straight: RunMachine = _full_run(_game(), MetaStub.new(_db))
	var game: RunRealFixture = _game()
	var meta := MetaStub.new(_db)
	var run: RunMachine = _started(game, meta)

	# Act: leave and come back in front of every offer
	for _f: int in LAST_FLOOR - 1:
		game.play_out(run, game.begin(run))
		while run.phase() == RunState.STATUS_POST_MATCH_REWARD:
			var shown: Array = (run.current_offer().option_ids as Array).duplicate()
			assert_int(run.suspend()).is_equal(OK)
			assert_int(run.resume()).is_equal(OK)
			assert_array(run.current_offer().option_ids).is_equal(shown)
			assert_int(run.draft_pick(StringName(run.state.reward_step), shown[0])).is_equal(OK)
	game.play_out(run, game.begin(run))

	# Assert
	assert_array(Array(run.state.deck)).is_equal(Array(straight.state.deck))
	assert_array(Array(run.state.treasures)).is_equal(Array(straight.state.treasures))


func test_a_treasure_taken_on_floor_one_is_installed_on_floor_two() -> void:
	# Arrange
	var game: RunRealFixture = _game()
	var run: RunMachine = _started(game, MetaStub.new(_db))
	game.play_floor(run)
	var id: String = run.state.treasures[0]

	# Act
	var driver: MatchDriver = game.begin(run)

	# Assert
	var installed: Array = game.configs[1].player.hook_installers
	assert_array(installed.map(func(i: HookInstaller) -> String: return i.host_id)).is_equal([id])
	assert_array(driver.hooks().hosts().filter(func(host: Dictionary) -> bool: return host.host_id == id)).has_size(1)


func test_the_read_model_never_shows_a_boss_ahead_of_the_floor() -> void:
	# Arrange
	var game: RunRealFixture = _game()
	var run: RunMachine = _started(game, MetaStub.new(_db))
	game.play_floor(run)

	# Act
	var model: Dictionary = run.read_model()

	# Assert
	assert_array(model.bosses_seen).is_equal(Array(run.state.boss_sequence.slice(0, 2)))
	assert_bool(JSON.stringify(model.floors).contains(run.state.boss_sequence[LAST_FLOOR - 1])).is_false()
