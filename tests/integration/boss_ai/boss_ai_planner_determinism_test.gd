## Integration: one match, three [PlannerTask] implementations, one log (boss-ai C1.5, C9,
## A1, A30's determinism clause; ADR-0006 Verification rows 1, 3, 6; story 017 AC 1).
##
## Each match runs through the real [MatchDriver] with a real `WorkerThreadPool` task, a
## real time-sliced task and the immediate one, in turn. The **driver's** clock is stopped
## by the factory's optional `clock` argument, so replay pacing and `tick_over_budget`
## cannot depend on a loaded machine. The slice task keeps the real clock on purpose:
## where a plan is cut must not change what it decides.
##
## The sample is always on; `SIM_FULL=1` plays the story's 1,000 boss turns (the seeds and
## boss turns played are asserted, not assumed). A real worker runs here, which is why this
## is an integration suite (story 017 Engine Notes).
extends GdUnitTestSuite

const SIDE_BOSS: String = MatchRecords.SIDE_BOSS
const HERO: String = "hero_war"
## One boss per band.
const BOSSES: Array[String] = ["boss_rat_king", "boss_rot_warden", "boss_lich_archivist"]
const KIND_IMMEDIATE: String = "immediate"
const KIND_WORKER: String = "worker"
const KIND_SLICED: String = "time_sliced"
const KINDS: Array[String] = [KIND_IMMEDIATE, KIND_WORKER, KIND_SLICED]
## A slice short enough that a band-3 plan is cut many times.
const SLICE_USEC: int = 500
const SAMPLE_BOSS_TURNS: int = 50
const FULL_BOSS_TURNS: int = 1000
const FIRST_FLOOR: int = 1
const EVENT_TURN_STARTED: String = "turn_started"

var _db: CardDatabase = null


## A planner source that keeps every plan each task returned, in order.
class Planner:
	extends RefCounted

	var kind: String
	## `TurnPlan.to_dict()`s, JSON, in the order the tasks finished.
	var plans: Array[String] = []
	var _tasks: Array[PlannerTask] = []
	## Whether a worker task actually ran off the main thread.
	var main_thread: int = OS.get_main_thread_id()

	func _init(planner_kind: String) -> void:
		kind = planner_kind

	func make() -> PlannerTask:
		var task: PlannerTask
		match kind:
			KIND_WORKER:
				task = WorkerPoolPlannerTask.new()
			KIND_SLICED:
				task = TimeSlicedPlannerTask.new(SLICE_USEC)
			_:
				task = ImmediatePlannerTask.new()
		_tasks.append(task)
		return task

	## Reads the plans out of the finished tasks and lets the tasks go.
	func collect() -> void:
		for task: PlannerTask in _tasks:
			var result: Variant = task.result()
			if result is TurnPlan:
				plans.append(EventLogAssertions.canonical_json((result as TurnPlan).to_dict()))
		_tasks.clear()


func before() -> void:
	_db = ShippedMatch.database()


func after() -> void:
	_db = null


## A harness whose drivers run on [param planner], with the caller's stopped clock.
func _harness(planner: Planner) -> BossAiSimHarness:
	var db: CardDatabase = _db
	return BossAiSimHarness.new(db, func(_source: Callable) -> Callable:
		return func(config: Dictionary, clock: Callable) -> MatchDriver:
			return MatchDriver.new(config, db, {}, planner.make, clock))


## One match of [param boss_id] on [param kind]: its plans, canonical log and counts.
func _played(boss_id: String, seed_value: int, kind: String) -> Dictionary:
	var planner: Planner = Planner.new(kind)
	var boss: Dictionary = _db.boss(boss_id)
	var seat: BossAiSimHarness.Seat = _harness(planner)._play(boss, seed_value, FIRST_FLOOR, int(boss.band), {"hero_id": HERO})
	planner.collect()
	var events: Array[Dictionary] = seat.log.events_since(0)
	return {
		"plans": planner.plans,
		"log": EventLogAssertions.canonical_json(events),
		"faults": events.filter(func(e: Dictionary) -> bool: return str(e.type) == BossAI.EVENT_FAULT).size(),
		"boss_turns": events.filter(func(e: Dictionary) -> bool: return str(e.type) == EVENT_TURN_STARTED and str(e.payload.side) == SIDE_BOSS).size(),
	}


## Plays seeds round-robin over [constant BOSSES] until [param boss_turns] boss turns have
## run, asserting the three kinds agree on each; the boss turns played.
func _compare_until(boss_turns: int) -> int:
	var played: int = 0
	var seed_value: int = 1
	while played < boss_turns:
		var boss_id: String = BOSSES[(seed_value - 1) % BOSSES.size()]
		var label: String = "%s seed %d" % [boss_id, seed_value]
		var reference: Dictionary = _played(boss_id, seed_value, KIND_IMMEDIATE)
		assert_int(int(reference.faults)).override_failure_message(label).is_equal(0)
		for kind: String in [KIND_WORKER, KIND_SLICED]:
			var other: Dictionary = _played(boss_id, seed_value, kind)
			assert_int(int(other.faults)).override_failure_message("%s %s faults" % [label, kind]).is_equal(0)
			assert_array(other.plans).override_failure_message("%s %s plans differ" % [label, kind]).is_equal(reference.plans)
			assert_str(str(other.log)).override_failure_message("%s %s log differs" % [label, kind]).is_equal(str(reference.log))
		played += int(reference.boss_turns)
		seed_value += 1
	return played


func test_three_planner_implementations_give_byte_identical_plans_and_logs() -> void:
	# Arrange
	var target: int = FULL_BOSS_TURNS if OS.get_environment("SIM_FULL") == "1" else SAMPLE_BOSS_TURNS

	# Act
	var played: int = _compare_until(target)

	# Assert — the comparison covered what it says it did
	assert_int(played).is_greater_equal(target)


func test_a_plan_is_recorded_for_every_boss_turn() -> void:
	# Act
	var match_run: Dictionary = _played(BOSSES[0], 1, KIND_WORKER)

	# Assert — an empty list would make the plan comparison above vacuous
	assert_int((match_run.plans as Array).size()).is_greater_equal(int(match_run.boss_turns))
	assert_int(int(match_run.boss_turns)).is_greater(0)


func test_a_different_seed_gives_a_different_log() -> void:
	# Act
	var first: Dictionary = _played(BOSSES[0], 1, KIND_IMMEDIATE)
	var second: Dictionary = _played(BOSSES[0], 2, KIND_IMMEDIATE)

	# Assert
	assert_str(str(first.log)).is_not_equal(str(second.log))
