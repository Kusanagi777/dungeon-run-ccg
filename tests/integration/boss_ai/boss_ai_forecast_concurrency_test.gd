## Integration: the main thread reading while a real worker forecasts (ADR-0006 thread
## safety argument, concurrent read-only access to the frozen `CardDatabase` being NOT
## SOURCEABLE and so proven by stress; story 017 AC 3).
##
## A real [MatchDriver] on the shipped data with [WorkerPoolPlannerTask]s. While a task is
## live the main thread calls `MatchQuery.card_text`, and every answer must equal a
## single-threaded one taken before any worker started. The driver's clock is stopped, so
## the stress loop cannot read as `tick_over_budget`.
extends GdUnitTestSuite

const BOOT_SCRIPT := preload("res://src/core/boot.gd")
const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const HERO: String = "hero_war"
const BOSS: String = "boss_hollow_king"
const STRESS_CALLS: int = 10000
## A frame bound that a stuck task cannot wait out.
const MAX_FRAMES: int = 5000

var _db: CardDatabase = null
var _boot: Node = null
var _driver: MatchDriver = null


func before_test() -> void:
	_db = ShippedMatch.database()
	_boot = auto_free(BOOT_SCRIPT.new())
	var result: BootResult = _boot.boot({"card_database": _db, "meta": MetaStub.new(_db)})
	GameAssertions.fail_if(not result.ok, "the boot did not end Ready")
	var factory: Callable = _boot.driver_factory(func() -> PlannerTask: return WorkerPoolPlannerTask.new())
	var log: EventLog = EventLog.new(EventLog.max_events_for(_db.config("rng_event_log")), EventLog.SCOPE_MATCH)
	_driver = factory.call(ShippedMatch.match_config(_db, HERO, BOSS, log, ShippedMatch.DEFAULT_SEED, _db.hero(HERO).starter_deck, _db.boss(BOSS).deck), _still_clock)


func after_test() -> void:
	if _driver != null:
		await _finish_task()
		_driver.shutdown()
	_driver = null
	_db = null
	_boot = null


func _still_clock() -> int:
	return 0


func _finish_task() -> void:
	var frames: int = 0
	while _driver.is_planning() and frames < MAX_FRAMES:
		_driver.tick()
		frames += 1
		await get_tree().process_frame


## Every collectible and boss card id, for the reads to walk.
func _card_ids() -> Array[String]:
	var ids: Array[String] = []
	for card: Dictionary in _db.collectible_pool("war"):
		ids.append(str(card.id))
	for card: Dictionary in _db.cards_by_set("boss"):
		ids.append(str(card.id))
	return ids


func test_card_text_under_a_live_forecast_equals_the_single_threaded_answer() -> void:
	# Arrange
	var ids: Array[String] = _card_ids()
	var query: MatchQuery = _driver.query()
	var expected: Dictionary = {}
	for id: String in ids:
		expected[id] = query.card_text(id)
	MatchDriverFixture.past_mulligan(_driver)
	assert_bool(_driver.is_planning()).is_true()

	var running: WorkerPoolPlannerTask = _driver._task

	# Act
	var wrong: Array[String] = []
	var overlapped: int = 0
	for call_index: int in STRESS_CALLS:
		var id: String = ids[call_index % ids.size()]
		if query.card_text(id) != expected[id]:
			wrong.append(id)
		if not WorkerThreadPool.is_task_completed(running._task_id):
			overlapped += 1
	await _finish_task()

	# Assert — and at least some reads truly overlapped the worker
	assert_array(wrong).is_empty()
	assert_int(overlapped).is_greater(0)


func test_reload_is_busy_against_a_real_worker_task() -> void:
	# Arrange
	MatchDriverFixture.past_mulligan(_driver)
	var version: String = _db.data_version()

	# Act — the live state cannot change until a tick sees the task finish
	var refused: ValidationReport = _db.reload()
	await _finish_task()
	var after_finish: ValidationReport = _db.reload()

	# Assert
	assert_str(str(refused.entries()[0].code)).is_equal(String(ValidationReport.E_BUSY))
	assert_str(_db.data_version()).is_equal(version)
	assert_bool(after_finish.has_errors()).is_false()
