## Integration: seed 42, hero War, floor 1 won twice with one command sequence (rng-event-log
## rule 9, F6, AC 3; gate condition 6; story 011).
##
## The first run is played by a hero-script (the sim harness's seat) and its commands are
## recorded; the second submits exactly those. A third changes one player command. Every
## service is built here, never through `Boot`, on the shipped data; the driver's planner
## is the immediate task and its clock is stopped, the run's clocks fixed. Every run's boss
## is wounded the same way before the first command, see [constant BOSS_HEALTH_LEFT]. The
## worker half is ADR-0006's gate (story 017).
##
## The DD-R09 limit: after a changed command, later AI decisions are not expected to match,
## so the third run is compared only up to where it must differ.
extends GdUnitTestSuite

const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const SIDE_BOSS: String = MatchRecords.SIDE_BOSS
const HERO: String = "hero_war"
const SEED_INPUT: String = "42"
const FIRST_FLOOR: int = 1
const PILOT_SEED: int = 42
## What each run's boss starts on, so a floor can be won at all. Floor 1 of seed 42 beat
## the hero-script on every pilot seed tried, and this story is about logs, not balance.
const BOSS_HEALTH_LEFT: int = 1
const FIXED_UNIX: int = 1700000000
const FIXED_TICKS: int = 0
const EVENT_RUN_STARTED: String = "run_started"
const EVENT_DRAFT_OFFERED: String = "draft_offered"

var _db: CardDatabase = null


## A harness that remembers every command its seat submits.
class RecordingHarness:
	extends BossAiSimHarness

	var commands: Array[Dictionary] = []

	func _init(db: CardDatabase) -> void:
		super(db, func(_source: Callable) -> Callable: return Callable())

	func _submit(seat: Seat, command: Dictionary) -> bool:
		commands.append(command.duplicate(true))
		return super(seat, command)


## One run: the machine, the run log and the floor-1 driver and its match log.
class Played:
	extends RefCounted

	var machine: RunMachine
	var run_log: EventLog
	var driver: MatchDriver
	## Kept here: the machine drops it when the match ends.
	var match_log: EventLog

	func on_run_log(log: EventLog) -> void:
		run_log = log


func before() -> void:
	_db = ShippedMatch.database()


func after() -> void:
	_db = null


func _still_clock() -> int:
	return 0


func _started_run() -> Played:
	var db: CardDatabase = _db
	var meta: MetaStub = MetaStub.new(db)
	var treasures: Treasures = Treasures.new(db, db.config("treasures_balance"))
	var draft: RewardDraft = RewardDraft.new(db, treasures, meta, db.config("reward_draft"))
	var run_config: Dictionary = db.config("run_structure").duplicate(true)
	run_config["max_match_events"] = EventLog.max_events_for(db.config("rng_event_log"))
	run_config["engine_version"] = Engine.get_version_info().string
	var still: Callable = _still_clock
	var factory: Callable = func(config: Dictionary) -> MatchDriver:
		return MatchDriver.new(config, db, meta.get_settings(), func() -> PlannerTask: return ImmediatePlannerTask.new(), still)
	var played: Played = Played.new()
	played.machine = RunMachine.new(db, meta, draft, treasures, run_config, factory)
	played.machine.unix_clock = func() -> int: return FIXED_UNIX
	played.machine.ticks_clock = func() -> int: return FIXED_TICKS
	played.machine.run_log_opened.connect(played.on_run_log)
	assert_int(played.machine.new_run(HERO, SEED_INPUT)).is_equal(OK)
	played.driver = played.machine.begin_match()
	assert_object(played.driver).is_not_null()
	played.match_log = played.machine._match_log
	var boss_hero: Dictionary = played.driver._engine.state().players[SIDE_BOSS].hero
	boss_hero.damage_taken = played.driver._engine.health(boss_hero) - BOSS_HEALTH_LEFT
	return played


func _settle(driver: MatchDriver) -> void:
	while driver.is_planning():
		driver.tick()


## Plays [param played]'s floor with a hero-script and answers the commands it sent.
func _pilot_to_end(played: Played) -> Array[Dictionary]:
	var harness: RecordingHarness = RecordingHarness.new(_db)
	var seat: BossAiSimHarness.Seat = BossAiSimHarness.Seat.new()
	seat.driver = played.driver
	seat.log = played.match_log
	var rng: RngService = RngService.new(PILOT_SEED, _db.data_version())
	seat.pilot = harness._pilot({"id": HERO, "ai_profile": BossAiSimHarness.PILOT_PROFILE}, rng.stream(BossAiSimHarness.PILOT_STREAM % FIRST_FLOOR), seat.log)
	seat.driver.match_ended.connect(seat.on_match_ended)
	while seat.result == null:
		harness._settle(seat)
		if seat.result == null:
			harness._move(seat)
	return harness.commands


func _replay(played: Played, commands: Array[Dictionary]) -> void:
	_settle(played.driver)
	for command: Dictionary in commands:
		@warning_ignore("return_value_discarded")
		played.driver.submit(command)
		_settle(played.driver)


func _of_type(log: EventLog, type: String) -> Array:
	return log.events_since(0).filter(func(e: Dictionary) -> bool: return str(e.type) == type)


## Two runs through floor 1 with the same commands.
func _two_runs() -> Array[Played]:
	var first: Played = _started_run()
	var commands: Array[Dictionary] = _pilot_to_end(first)
	var second: Played = _started_run()
	_replay(second, commands)
	return [first, second]


func test_seed_42_war_wins_floor_one_with_the_hero_script() -> void:
	# Act
	var played: Played = _started_run()
	@warning_ignore("return_value_discarded")
	_pilot_to_end(played)

	# Assert — every other case here needs the floor won
	assert_str(played.machine.phase()).is_equal(RunState.STATUS_POST_MATCH_REWARD)


func test_two_runs_agree_on_the_boss_sequence_and_the_first_offer() -> void:
	# Act
	var runs: Array[Played] = _two_runs()

	# Assert
	var bosses: Array = _of_type(runs[0].run_log, EVENT_RUN_STARTED)
	var again: Array = _of_type(runs[1].run_log, EVENT_RUN_STARTED)
	assert_int(bosses.size()).is_equal(1)
	assert_array(bosses[0].payload.boss_ids).is_not_empty()
	assert_array(bosses[0].payload.boss_ids).is_equal(again[0].payload.boss_ids)
	var offers: Array = _of_type(runs[0].run_log, EVENT_DRAFT_OFFERED)
	var offers_again: Array = _of_type(runs[1].run_log, EVENT_DRAFT_OFFERED)
	assert_int(offers.size()).is_greater(0)
	assert_array(offers[0].payload.option_ids).is_not_empty()
	assert_array(offers[0].payload.option_ids).is_equal(offers_again[0].payload.option_ids)


func test_two_runs_serialise_byte_identical_logs() -> void:
	# Act
	var runs: Array[Played] = _two_runs()

	# Assert
	var first_match: EventLog = runs[0].match_log
	var second_match: EventLog = runs[1].match_log
	EventLogAssertions.assert_replay_equal(first_match, second_match, "match logs")
	EventLogAssertions.assert_replay_equal(runs[0].run_log, runs[1].run_log, "run logs")
	assert_str(first_match.to_json()).is_equal(second_match.to_json())
	assert_str(runs[0].run_log.to_json()).is_equal(runs[1].run_log.to_json())


func test_the_log_headers_name_one_data_and_engine_version() -> void:
	# Act
	var runs: Array[Played] = _two_runs()

	# Assert
	var first: Dictionary = runs[0].match_log.to_json_dict()
	var second: Dictionary = runs[1].match_log.to_json_dict()
	assert_str(str(first.data_version)).is_equal(_db.data_version())
	assert_str(str(first.data_version)).is_equal(str(second.data_version))
	assert_str(str(first.engine_version)).is_equal(str(second.engine_version))


func test_a_third_run_with_one_changed_command_diverges_at_or_after_it() -> void:
	# Arrange — the first play is replaced by ending the turn
	var first: Played = _started_run()
	var commands: Array[Dictionary] = _pilot_to_end(first)
	var changed_at: int = commands.find_custom(func(c: Dictionary) -> bool: return str(c.type) == MatchRecords.CMD_PLAY_CARD)
	assert_int(changed_at).is_greater_equal(0)
	var third: Played = _started_run()
	_replay(third, commands.slice(0, changed_at))
	var shared: int = third.match_log.events_since(0).size()

	# Act
	var result: Dictionary = third.driver.submit(MatchRecords.end_turn(SIDE_PLAYER))
	_settle(third.driver)
	third.driver.shutdown()

	# Assert — identical before the command, different from its first event on
	assert_bool(result.accepted).is_true()
	var theirs: Array[Dictionary] = third.match_log.events_since(0)
	var ours: Array[Dictionary] = first.match_log.events_since(0)
	EventLogAssertions.assert_replay_equal(ours.slice(0, shared), theirs.slice(0, shared), "the shared prefix")
	assert_str(EventLogAssertions.canonical_json(ours[shared])).is_not_equal(EventLogAssertions.canonical_json(theirs[shared]))
