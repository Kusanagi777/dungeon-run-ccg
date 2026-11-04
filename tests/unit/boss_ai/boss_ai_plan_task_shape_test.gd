## Parse-check for the planner's call shape (story
## boss-ai-match-driver/story-008; ADR-0006 erratum 2026-11-03, engine validation
## claim 12: "a parse-check test for the call shape is required").
##
## On 4.7.2 any function containing `await` is a coroutine and every statically
## resolved call to it must be `await`ed; the task Callable is the one dynamic hop.
## So the shape is checked twice: by running `plan_task(sandbox)` through each main-
## thread [PlannerTask] (a worker never starts in `tests/unit/**`), and by scanning
## `src/ai/` for a call to a planner coroutine that does not await it.
extends GdUnitTestSuite

const BOSS_AI_PATH: String = "res://src/ai/boss_ai.gd"
const AI_DIR: String = "res://src/ai/"
const TEST_DIR: String = "res://tests/unit/boss_ai/"
## The coroutines of the erratum, as a call site spells them.
const COROUTINE_CALLS: Array[String] = ["plan_turn(", "score_all(", ".search(", "_plan_pass("]
const SLICE_USEC: int = 1


# --- helpers -----------------------------------------------------------------

func _board() -> Dictionary:
	var fixture: Dictionary = BossAiBoard.read("f1_worked_example")
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
	task.start((board.ai as BossAI).plan_task(sandbox))
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
