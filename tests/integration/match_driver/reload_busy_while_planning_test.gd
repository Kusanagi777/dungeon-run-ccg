## Integration: `CardDatabase.reload()` is `E_BUSY` while a task of a driver from the
## composition root's `driver_factory` is live (boss-ai-match-driver story 019 AC 3;
## ADR-0006; ADR-0008 Decision 1).
##
## A real `Boot` instance over a real `CardDatabase`, and [FakePlannerTask]s through the
## factory's override, so a test decides when a task finishes and no worker starts
## (TD-012). `FakePlannerTask.polls_before_done` holds a task live across ticks.
extends GdUnitTestSuite

const BOOT_SCRIPT := preload("res://src/core/boot.gd")
const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const HERO: String = "hero_war"
const BOSS: String = "boss_rat_king"
## Long enough that only [method FakePlannerTask.finish] ends a task.
const STAY_LIVE: int = 1000

var _db: CardDatabase = null
var _driver: MatchDriver = null
var _tasks: MatchDriverFixture.TaskFactory = null


func before_test() -> void:
	_db = ShippedMatch.database()
	_tasks = MatchDriverFixture.TaskFactory.new()
	var boot: Node = auto_free(BOOT_SCRIPT.new())
	var result: BootResult = boot.boot({"card_database": _db, "meta": MetaStub.new(_db)})
	GameAssertions.fail_if(not result.ok, "the boot did not end Ready")
	var factory: Callable = boot.driver_factory(_live_task)
	var log: EventLog = EventLog.new(EventLog.max_events_for(_db.config("rng_event_log")), EventLog.SCOPE_MATCH)
	_driver = factory.call(ShippedMatch.match_config(_db, HERO, BOSS, log))


func after_test() -> void:
	if _driver != null:
		_driver.shutdown()
	_driver = null
	_tasks = null
	_db = null


func _live_task() -> PlannerTask:
	var task: FakePlannerTask = _tasks.make() as FakePlannerTask
	task.polls_before_done = STAY_LIVE
	return task


func _assert_refused() -> void:
	var version: String = _db.data_version()
	var report: ValidationReport = _db.reload()
	assert_int(report.entries().size()).is_equal(1)
	assert_str(str(report.entries()[0].code)).is_equal(String(ValidationReport.E_BUSY))
	assert_str(_db.data_version()).is_equal(version)
	assert_that(_db.last_reload_report()).is_null()


func _assert_swapped() -> void:
	var before: ValidationReport = _db.report()
	var report: ValidationReport = _db.reload()
	assert_bool(report.has_errors()).is_false()
	assert_int(_db.state()).is_equal(CardDatabase.State.READY)
	assert_bool(is_same(_db.report(), report)).is_true()
	assert_bool(is_same(_db.report(), before)).is_false()


func test_reload_is_busy_while_the_forecast_task_is_live() -> void:
	# Arrange — the keep-all mulligan starts the turn's forecast
	MatchDriverFixture.past_mulligan(_driver)
	assert_bool(_tasks.last().is_live()).is_true()

	# Act / Assert
	_assert_refused()


func test_reload_is_busy_while_the_plan_task_is_live() -> void:
	# Arrange — the stale forecast goes, and the boss's Main starts the plan task
	MatchDriverFixture.past_mulligan(_driver)
	_tasks.last().finish()
	_tasks.last().scripted_result = null
	_driver.tick()
	assert_bool(_driver.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()
	_driver.tick()
	assert_bool(_tasks.last().is_live()).is_true()

	# Act / Assert
	_assert_refused()


func test_reload_swaps_once_tick_sees_the_task_finish() -> void:
	# Arrange
	MatchDriverFixture.past_mulligan(_driver)
	_assert_refused()
	_tasks.last().finish()

	# Act
	_driver.tick()

	# Assert
	assert_bool(_tasks.last().is_live()).is_false()
	_assert_swapped()


func test_reload_is_allowed_between_matches() -> void:
	# Arrange — a match shut down mid-plan leaves nothing live
	MatchDriverFixture.past_mulligan(_driver)
	_driver.shutdown()
	_tasks.last().finish()
	@warning_ignore("return_value_discarded")
	_tasks.last().poll()

	# Act / Assert
	_assert_swapped()
