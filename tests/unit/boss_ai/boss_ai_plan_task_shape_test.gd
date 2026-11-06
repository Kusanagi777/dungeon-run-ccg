## Parse-check for the planner's call shape (story
## boss-ai-match-driver/story-008; ADR-0006 erratum 2026-11-03, engine validation
## claim 12: "a parse-check test for the call shape is required").
##
## On 4.7.2 any function containing `await` is a coroutine and every statically
## resolved call to it must be `await`ed; the task Callable is the one dynamic hop.
## So the shape is checked twice: by running `plan_task(sandbox, task)` through each main-
## thread [PlannerTask] (a worker never starts in `tests/unit/**`), and by scanning
## `src/ai/` for a call to a planner coroutine that does not await it.
extends GdUnitTestSuite

const BOSS_AI_PATH: String = "res://src/ai/boss_ai.gd"
const AI_DIR: String = "res://src/ai/"
const TEST_DIR: String = "res://tests/unit/boss_ai/"
## The coroutines of the erratum, as a call site spells them.
const COROUTINE_CALLS: Array[String] = ["plan_turn(", "score_all(", ".search(", "_plan_pass(", "_run_loop(", "forecast("]
const SLICE_USEC: int = 1


# --- helpers -----------------------------------------------------------------

func _board(given: Dictionary = {}) -> Dictionary:
	var fixture: Dictionary = BossAiBoard.read("f1_worked_example") if given.is_empty() else given
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var engine: RulesEngine = BossAiBoard.engine(fixture, db)
	var stub: Dictionary = BossAiBoard.stub_config()
	var ai: BossAI = BossAI.new(CardFactory.make_boss_def("boss_test", int(fixture.band)), BossAiBoard.profile(fixture), int(fixture.band), TestRngStream.seeded("ai_1", 7), stub.op_values, null, db, stub.keyword_values)
	return {"engine": engine, "ai": ai}


## The non-comment source lines of [param path].
func _code_lines(path: String) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		if not line.strip_edges().begins_with("#"):
			lines.append(line)
	return lines


func _is_definition(line: String) -> bool:
	return line.strip_edges().begins_with("func ") or line.strip_edges().begins_with("static func ")


# --- the shape, by running it -----------------------------------------------------

func test_plan_task_returns_a_turn_plan_through_the_immediate_task() -> void:
	# Arrange
	var board: Dictionary = _board()
	var sandbox: RulesEngine = (board.engine as RulesEngine).clone()
	var task: ImmediatePlannerTask = ImmediatePlannerTask.new()

	# Act
	task.start((board.ai as BossAI).plan_task(sandbox, task))
	var plan: Variant = task.result()
	sandbox.end_match()

	# Assert
	assert_bool(task.poll()).is_true()
	assert_bool(plan is TurnPlan).is_true()
	assert_int((plan as TurnPlan).commands.size()).is_greater(0)


func test_plan_task_suspends_and_resumes_through_the_time_sliced_task() -> void:
	# Arrange — a clock that always reads past the slice: every checkpoint yields,
	# and the immediate result is the reference
	var reference: Dictionary = _board()
	var reference_sandbox: RulesEngine = (reference.engine as RulesEngine).clone()
	var expected: TurnPlan = await (reference.ai as BossAI).plan_turn(reference_sandbox)
	reference_sandbox.end_match()
	var board: Dictionary = _board()
	var sandbox: RulesEngine = (board.engine as RulesEngine).clone()
	var ticks: Array[int] = [0]
	var clock: Callable = func() -> int:
		ticks[0] += SLICE_USEC
		return ticks[0]
	var task: TimeSlicedPlannerTask = TimeSlicedPlannerTask.new(SLICE_USEC, clock)

	# Act
	task.start((board.ai as BossAI).plan_task(sandbox, task))
	var polls: int = 0
	while not task.poll():
		polls += 1
	sandbox.end_match()

	# Assert — it did yield, and the sliced run plans the same turn
	assert_int(polls).is_greater(0)
	var plan: Variant = task.result()
	assert_bool(plan is TurnPlan).is_true()
	assert_that((plan as TurnPlan).to_dict()).is_equal(expected.to_dict())


func test_plan_task_takes_the_task_with_no_default() -> void:
	# Arrange — a default is the trap: `plan_task(sandbox)` reads right, and a
	# time-sliced task then runs the whole plan inside `start()`
	var found: Array[Dictionary] = []

	# Act
	for method: Dictionary in load(BOSS_AI_PATH).get_script_method_list():
		if str(method.name) == "plan_task":
			found.append(method)

	# Assert
	assert_int(found.size()).is_equal(1)
	assert_int((found[0].args as Array).size()).is_equal(2)
	assert_array(found[0].default_args).is_empty()


func test_forecast_task_takes_the_task_with_no_default_and_no_choose_task_is_left() -> void:
	# Arrange — BAI-008 D-1 for the sibling: the same trap, the same cure. DD-X31 took
	# `choose_task` away: a Choice is answered inside a plan
	var expected_args: Dictionary = {"forecast_task": 2}
	var found: Dictionary = {}

	# Act
	var names: Array[String] = []
	for method: Dictionary in load(BOSS_AI_PATH).get_script_method_list():
		names.append(str(method.name))
		if expected_args.has(str(method.name)):
			found[str(method.name)] = method

	# Assert
	assert_array(names).not_contains(["choose_task"])
	assert_int(found.size()).is_equal(expected_args.size())
	for name: String in expected_args:
		assert_int((found[name].args as Array).size()).is_equal(int(expected_args[name]))
		assert_array(found[name].default_args).is_empty()


func test_forecast_task_returns_an_intent_through_the_immediate_task() -> void:
	# Arrange
	var board: Dictionary = _board(BossAiBoard.read("attackers_4_3"))
	var engine: RulesEngine = board.engine
	assert_bool(engine.submit(MatchRecords.end_turn(MatchRecords.SIDE_BOSS)).accepted).is_true()
	var sandbox: RulesEngine = engine.clone()
	var task: ImmediatePlannerTask = ImmediatePlannerTask.new()

	# Act
	task.start((board.ai as BossAI).forecast_task(sandbox, task))
	var intent: Variant = task.result()
	sandbox.end_match()

	# Assert
	assert_bool(intent is Intent).is_true()
	assert_str((intent as Intent).intent_key).is_equal(Intent.KEY_ATTACK_FACE)


func test_forecast_task_suspends_and_resumes_through_the_time_sliced_task() -> void:
	# Arrange — a clock always past the slice: every checkpoint yields
	var board: Dictionary = _board(BossAiBoard.read("attackers_4_3"))
	var engine: RulesEngine = board.engine
	assert_bool(engine.submit(MatchRecords.end_turn(MatchRecords.SIDE_BOSS)).accepted).is_true()
	var sandbox: RulesEngine = engine.clone()
	var ticks: Array[int] = [0]
	var clock: Callable = func() -> int:
		ticks[0] += SLICE_USEC
		return ticks[0]
	var task: TimeSlicedPlannerTask = TimeSlicedPlannerTask.new(SLICE_USEC, clock)

	# Act
	task.start((board.ai as BossAI).forecast_task(sandbox, task))
	var live_after_start: bool = task.is_live()
	var polls: int = 0
	while not task.poll():
		polls += 1
	sandbox.end_match()

	# Assert — it yielded, and the sliced forecast is the immediate one
	assert_bool(live_after_start).is_true()
	assert_int(polls).is_greater(0)
	assert_str((task.result() as Intent).intent_key).is_equal(Intent.KEY_ATTACK_FACE)
	assert_int(int((task.result() as Intent).amount)).is_equal(7)


func test_a_time_sliced_run_yields_inside_the_search_before_it_finishes() -> void:
	# Arrange — a lethal board, so the search's stack crosses real suspensions; a
	# clock always past the slice yields at every checkpoint
	var fixture: Dictionary = BossAiBoard.read("lethal_through_taunt")
	var reference: Dictionary = _board(fixture)
	var reference_sandbox: RulesEngine = (reference.engine as RulesEngine).clone()
	var expected: TurnPlan = await (reference.ai as BossAI).plan_turn(reference_sandbox)
	reference_sandbox.end_match()
	var board: Dictionary = _board(fixture)
	var sandbox: RulesEngine = (board.engine as RulesEngine).clone()
	var scratch: EventLog = sandbox.state().log
	var ticks: Array[int] = [0]
	var clock: Callable = func() -> int:
		ticks[0] += SLICE_USEC
		return ticks[0]
	var task: TimeSlicedPlannerTask = TimeSlicedPlannerTask.new(SLICE_USEC, clock)

	# Act
	task.start((board.ai as BossAI).plan_task(sandbox, task))
	var live_after_start: bool = task.is_live()
	var events_after_start: int = scratch.size()
	var polls: int = 0
	while not task.poll():
		polls += 1
	sandbox.end_match()

	# Assert — `start()` came back with nothing submitted, one yield per node at
	# least, and the sliced turn is the immediate one
	assert_bool(live_after_start).is_true()
	assert_int(events_after_start).is_equal(0)
	assert_int(polls).is_greater(0)
	assert_str(str(((task.result() as TurnPlan).diagnostics[1]).mode)).is_equal(String(Scorer.MODE_LETHAL))
	assert_that((task.result() as TurnPlan).to_dict()).is_equal(expected.to_dict())


# --- the shape, by source scan ----------------------------------------------------

func test_the_task_lambda_awaits_plan_turn() -> void:
	# Arrange
	var source: String = FileAccess.get_file_as_string(BOSS_AI_PATH)

	# Act
	var found: bool = source.contains("return func() -> Variant: return await plan_turn(sandbox")

	# Assert
	assert_bool(found).is_true()


func test_every_call_to_a_planner_coroutine_under_src_ai_is_awaited() -> void:
	# Arrange
	var offenders: Array[String] = []

	# Act
	for file: String in DirAccess.get_files_at(AI_DIR):
		if file.get_extension() != "gd":
			continue
		for line: String in _code_lines(AI_DIR.path_join(file)):
			if _is_definition(line):
				continue
			for call: String in COROUTINE_CALLS:
				if line.contains(call) and not line.contains("await "):
					offenders.append("%s: %s" % [file, line.strip_edges()])

	# Assert
	assert_array(offenders).is_empty()


func test_every_test_call_to_plan_turn_or_score_all_is_awaited() -> void:
	# Arrange — the erratum names the tests too; a quoted name is not a call
	var offenders: Array[String] = []

	# Act
	for file: String in DirAccess.get_files_at(TEST_DIR):
		if file.get_extension() != "gd":
			continue
		for line: String in _code_lines(TEST_DIR.path_join(file)):
			if _is_definition(line) or line.contains("\""):
				continue
			if (line.contains(".plan_turn(") or line.contains(".score_all(")) and not line.contains("await "):
				offenders.append("%s: %s" % [file, line.strip_edges()])

	# Assert
	assert_array(offenders).is_empty()
