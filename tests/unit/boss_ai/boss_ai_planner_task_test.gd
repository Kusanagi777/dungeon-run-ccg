## Unit tests for the PlannerTask seam and its three implementations
## (story boss-ai-match-driver/story-001; ADR-0006 Key Interfaces and erratum
## 2026-11-03; TR-boss-ai-003).
##
## No test here starts a worker thread (ADR-0006: `tests/unit/**` never does;
## TD-012). `WorkerPoolPlannerTask` is driven through a scripted fake pool
## injected as its three pool Callables; the real pool belongs to the boss-ai
## integration tests (story 017).
##
## No assertion reads a wall clock. `TimeSlicedPlannerTask` gets a scripted
## slice clock that reads `state.now`; the planning work advances it by
## EVAL_USEC per evaluation, one evaluation per `checkpoint()`, so where the
## work suspends is exact.
##
## Planning work has the shape ADR-0006's erratum fixes: a coroutine
## (`_plan` awaits `task.checkpoint()`) wrapped as
## `func() -> Variant: return await _plan(...)` and called by each task
## through `work.call()`.
##
## `@abstract` is enforced at parse time (engine-validation-2026-11-03.md,
## ADR-0006 claim 7), so the refusal tests compile throw-away GDScript from
## source and assert that `reload()` fails; each prints one expected
## `SCRIPT ERROR: Parse Error` line. The errored-work tests each print one
## expected `SCRIPT ERROR` line, captured by `assert_error`.
extends GdUnitTestSuite


## Slice budget for the scripted clock, microseconds.
const SLICE_USEC: int = 1000

## Scripted cost of one evaluation, microseconds. SLICE_USEC / EVAL_USEC = 4:
## the 4th checkpoint of a slice is the first whose elapsed time reaches the
## budget exactly (the `>=` boundary), the 3rd (750) is below it.
const EVAL_USEC: int = 250

## Evaluations per checkpoint-bounded slice with the constants above.
const EVALS_PER_SLICE: int = 4

## Evaluations in the standard fixture work: two full slices and a partial one.
const FIXTURE_EVALS: int = 10

## Pool id the fake pool hands out.
const FAKE_TASK_ID: int = 7

## Slice budget no fixture can reach with the default clock: one hour.
const UNREACHABLE_SLICE_USEC: int = 3_600_000_000


## Scripted stand-in for the pool: records every call, runs the submitted
## callable only when the test calls finish() (what a pool thread would do,
## here on the calling thread), and reports completion as scripted.
class FakePool:
	extends RefCounted

	## Every call in order: [name, arg...].
	var calls: Array = []
	## What is_task_completed() answers.
	var completed: bool = false
	## Set by wait_for_task_completion(); a later is_task_completed() is a bug.
	var waited: bool = false
	## True if is_task_completed() was called after the wait (ERROR: Invalid Task ID).
	var polled_after_wait: bool = false
	var _submitted: Callable

	func add_task(callable: Callable, high_priority: bool, description: String) -> int:
		calls.append(["add_task", high_priority, description])
		_submitted = callable
		return FAKE_TASK_ID

	func is_task_completed(id: int) -> bool:
		calls.append(["is_task_completed", id])
		if waited:
			polled_after_wait = true
		return completed

	func wait_for_task_completion(id: int) -> Error:
		calls.append(["wait_for_task_completion", id])
		waited = true
		return OK

	## Runs the submitted callable to the end and marks the task completed.
	func finish() -> void:
		_submitted.call()
		_submitted = Callable()
		completed = true

	func count(name: String) -> int:
		return calls.filter(func(c: Array) -> bool: return c[0] == name).size()


# --- fixtures ------------------------------------------------------------------

## Fresh shared state for one work run (lambdas capture by value, so the work
## reports through this Dictionary).
func _new_state() -> Dictionary:
	return {"now": 0, "evals": 0, "checkpoints_returned": 0, "live_seen": []}


## The planning coroutine: `evals` evaluations, each costing EVAL_USEC on the
## scripted clock, a checkpoint after each. Returns a deterministic total.
func _plan(task: PlannerTask, evals: int, state: Dictionary) -> int:
	var total: int = 0
	for i: int in evals:
		state["now"] += EVAL_USEC
		state["evals"] += 1
		state["live_seen"].append(task.is_live())
		total += (i + 1) * (i + 1)
		await task.checkpoint()
		state["checkpoints_returned"] += 1
	return total


## What _plan returns for `evals`, computed without any task.
func _plain_total(evals: int) -> int:
	var total: int = 0
	for i: int in evals:
		total += (i + 1) * (i + 1)
	return total


## The ADR-0006 erratum work shape over _plan.
func _work(task: PlannerTask, evals: int, state: Dictionary) -> Callable:
	return func() -> Variant: return await _plan(task, evals, state)


## Work that raises a script error (a method call on null).
func _erroring_work() -> Callable:
	return func() -> Variant:
		var nothing: Variant = null
		return nothing.plan()


func _time_sliced(state: Dictionary) -> TimeSlicedPlannerTask:
	return TimeSlicedPlannerTask.new(SLICE_USEC, func() -> int: return state["now"])


func _worker(pool: FakePool) -> WorkerPoolPlannerTask:
	return WorkerPoolPlannerTask.new(pool.add_task, pool.is_task_completed, pool.wait_for_task_completion)


## Compiles `source` as a fresh GDScript and returns `reload()`'s Error.
func _compile(source: String) -> Error:
	var script: GDScript = GDScript.new()
	script.source_code = source
	return script.reload()


## The base's own methods (not inherited from RefCounted / Object).
func _declared_methods() -> Dictionary:
	var by_name: Dictionary = {}
	for method: Dictionary in (PlannerTask as Script).get_script_method_list():
		by_name[method.name] = method
	return by_name


# --- AC-3: the @abstract seam --------------------------------------------------

func test_planner_task_script_reports_abstract() -> void:
	# Arrange
	var script: Script = PlannerTask

	# Act
	var abstract: bool = script.is_abstract()

	# Assert
	assert_bool(abstract).is_true()


func test_planner_task_start_and_poll_are_abstract_and_the_rest_concrete() -> void:
	# Arrange — `@abstract func` sets METHOD_FLAG_VIRTUAL_REQUIRED (observed on
	# 4.7.2; the parse-time refusals below are the sourced proof)
	var declared: Dictionary = _declared_methods()
	var flag_of: Callable = func(name: String) -> bool:
		return declared[name].flags & METHOD_FLAG_VIRTUAL_REQUIRED != 0

	# Act / Assert
	assert_bool(flag_of.call("start")).is_true()
	assert_bool(flag_of.call("poll")).is_true()
	assert_bool(flag_of.call("result")).is_false()
	assert_bool(flag_of.call("is_live")).is_false()
	assert_bool(flag_of.call("checkpoint")).is_false()


func test_planner_task_new_is_refused_at_parse_time() -> void:
	# Arrange
	var source: String = "extends RefCounted\nfunc make() -> Variant:\n\treturn PlannerTask.new()\n"
	var box: Dictionary = {"err": OK}

	# Act / Assert — the exact message Godot 4.7.2 prints (engine validation)
	await assert_error(func() -> void: box.err = _compile(source)) \
		.is_runtime_error('Parse Error: Cannot construct abstract class "PlannerTask".')
	assert_int(box.err).is_not_equal(OK)


func test_subclass_missing_both_overrides_is_refused_at_parse_time() -> void:
	# Arrange — the message names a generated script path, so any text matches;
	# the reload() Error is the assertion that matters
	var source: String = "extends PlannerTask\n"
	var box: Dictionary = {"err": OK}

	# Act / Assert
	await assert_error(func() -> void: box.err = _compile(source)).is_runtime_error(any_string())
	assert_int(box.err).is_not_equal(OK)


func test_subclass_missing_poll_override_is_refused_at_parse_time() -> void:
	# Arrange
	var source: String = "extends PlannerTask\nfunc start(_work: Callable) -> void:\n\treturn\n"
	var box: Dictionary = {"err": OK}

	# Act / Assert
	await assert_error(func() -> void: box.err = _compile(source)).is_runtime_error(any_string())
	assert_int(box.err).is_not_equal(OK)


func test_subclass_with_both_overrides_compiles() -> void:
	# Arrange — the control for the two refusals above
	var source: String = (
		"extends PlannerTask\nfunc start(_work: Callable) -> void:\n\treturn\n"
		+ "func poll() -> bool:\n\treturn true\n"
	)

	# Act
	var err: Error = _compile(source)

	# Assert
	assert_int(err).is_equal(OK)


func test_base_checkpoint_returns_immediately_without_suspending() -> void:
	# Arrange — a coroutine called dynamically: if checkpoint() suspended, the
	# line after the await would not have run when call() returns
	var task: PlannerTask = ImmediatePlannerTask.new()
	var state: Dictionary = {"after": false}
	var coroutine: Callable = func() -> void:
		await task.checkpoint()
		state["after"] = true

	# Act
	coroutine.call()

	# Assert
	assert_bool(state["after"]).is_true()


# --- AC-1: ImmediatePlannerTask ------------------------------------------------

func test_immediate_start_runs_coroutine_work_inside_start() -> void:
	# Arrange
	var task: ImmediatePlannerTask = ImmediatePlannerTask.new()
	var state: Dictionary = _new_state()

	# Act
	task.start(_work(task, FIXTURE_EVALS, state))

	# Assert — every evaluation and checkpoint ran before start() returned
	assert_int(state["evals"]).is_equal(FIXTURE_EVALS)
	assert_int(state["checkpoints_returned"]).is_equal(FIXTURE_EVALS)


func test_immediate_after_start_polls_true_not_live_and_returns_value() -> void:
	# Arrange
	var task: ImmediatePlannerTask = ImmediatePlannerTask.new()
	var state: Dictionary = _new_state()

	# Act
	task.start(_work(task, FIXTURE_EVALS, state))

	# Assert — the value itself, not a suspended function state (claim 11)
	assert_bool(task.poll()).is_true()
	assert_bool(task.is_live()).is_false()
	assert_int(typeof(task.result())).is_equal(TYPE_INT)
	assert_int(task.result()).is_equal(_plain_total(FIXTURE_EVALS))


func test_immediate_is_live_while_work_runs() -> void:
	# Arrange
	var task: ImmediatePlannerTask = ImmediatePlannerTask.new()
	var state: Dictionary = _new_state()

	# Act
	task.start(_work(task, FIXTURE_EVALS, state))

	# Assert — is_live() read inside the work, at every evaluation
	assert_array(state["live_seen"]).has_size(FIXTURE_EVALS).not_contains([false])


func test_immediate_before_start_polls_true_not_live_result_null() -> void:
	# Arrange
	var task: ImmediatePlannerTask = ImmediatePlannerTask.new()

	# Act
	var finished: bool = task.poll()

	# Assert
	assert_bool(finished).is_true()
	assert_bool(task.is_live()).is_false()
	assert_that(task.result()).is_null()


func test_immediate_errored_work_gives_null_result_and_finishes() -> void:
	# Arrange
	var task: ImmediatePlannerTask = ImmediatePlannerTask.new()
	var work: Callable = _erroring_work()

	# Act — the script error is expected and captured
	await assert_error(func() -> void: task.start(work)).is_runtime_error(any_string())

	# Assert
	assert_bool(task.poll()).is_true()
	assert_bool(task.is_live()).is_false()
	assert_that(task.result()).is_null()


# --- AC-2: TimeSlicedPlannerTask, scripted clock -------------------------------

func test_time_sliced_constructor_takes_slice_budget() -> void:
	# Arrange / Act
	var task: TimeSlicedPlannerTask = _time_sliced(_new_state())

	# Assert
	assert_int(task.slice_usec).is_equal(SLICE_USEC)


func test_time_sliced_start_yields_at_first_checkpoint_reaching_slice() -> void:
	# Arrange
	var state: Dictionary = _new_state()
	var task: TimeSlicedPlannerTask = _time_sliced(state)

	# Act
	task.start(_work(task, FIXTURE_EVALS, state))

	# Assert — checkpoints 1–3 (250, 500, 750 < 1000) returned; checkpoint 4
	# (elapsed exactly 1000) suspended the work
	assert_int(state["evals"]).is_equal(EVALS_PER_SLICE)
	assert_int(state["checkpoints_returned"]).is_equal(EVALS_PER_SLICE - 1)
	assert_bool(task.is_live()).is_true()
	assert_that(task.result()).is_null()

	# Cleanup — run the work out so no suspended state outlives the test
	while not task.poll():
		pass


func test_time_sliced_poll_resets_slice_clock_and_resumes_synchronously() -> void:
	# Arrange
	var state: Dictionary = _new_state()
	var task: TimeSlicedPlannerTask = _time_sliced(state)
	task.start(_work(task, FIXTURE_EVALS, state))

	# Act
	var finished: bool = task.poll()

	# Assert — the work ran inside poll() for one fresh slice: had the clock not
	# been reset, checkpoint 5 (elapsed 1250) would have suspended at once
	assert_bool(finished).is_false()
	assert_int(state["evals"]).is_equal(2 * EVALS_PER_SLICE)
	assert_int(state["checkpoints_returned"]).is_equal(2 * EVALS_PER_SLICE - 1)
	assert_bool(task.is_live()).is_true()

	# Cleanup
	while not task.poll():
		pass


func test_time_sliced_final_poll_returns_true_with_value_not_live() -> void:
	# Arrange
	var state: Dictionary = _new_state()
	var task: TimeSlicedPlannerTask = _time_sliced(state)
	task.start(_work(task, FIXTURE_EVALS, state))
	task.poll()

	# Act — evaluations 9–10 fit in the third slice
	var finished: bool = task.poll()

	# Assert
	assert_bool(finished).is_true()
	assert_bool(task.is_live()).is_false()
	assert_int(state["evals"]).is_equal(FIXTURE_EVALS)
	assert_int(task.result()).is_equal(_plain_total(FIXTURE_EVALS))


func test_time_sliced_is_live_inside_every_slice() -> void:
	# Arrange
	var state: Dictionary = _new_state()
	var task: TimeSlicedPlannerTask = _time_sliced(state)

	# Act
	task.start(_work(task, FIXTURE_EVALS, state))
	while not task.poll():
		pass

	# Assert
	assert_array(state["live_seen"]).has_size(FIXTURE_EVALS).not_contains([false])


func test_time_sliced_poll_after_finish_returns_true_without_resuming() -> void:
	# Arrange
	var state: Dictionary = _new_state()
	var task: TimeSlicedPlannerTask = _time_sliced(state)
	task.start(_work(task, FIXTURE_EVALS, state))
	while not task.poll():
		pass

	# Act
	var again: Array[bool] = [task.poll(), task.poll(), task.poll()]

	# Assert
	assert_array(again).not_contains([false])
	assert_int(state["evals"]).is_equal(FIXTURE_EVALS)
	assert_int(task.result()).is_equal(_plain_total(FIXTURE_EVALS))


func test_time_sliced_work_under_one_slice_finishes_inside_start() -> void:
	# Arrange — three evaluations reach 750 < SLICE_USEC
	var state: Dictionary = _new_state()
	var task: TimeSlicedPlannerTask = _time_sliced(state)

	# Act
	task.start(_work(task, EVALS_PER_SLICE - 1, state))

	# Assert
	assert_bool(task.is_live()).is_false()
	assert_bool(task.poll()).is_true()
	assert_int(task.result()).is_equal(_plain_total(EVALS_PER_SLICE - 1))


func test_time_sliced_default_clock_runs_unreachable_slice_in_start() -> void:
	# Arrange — default clock (no clock argument); no timing is asserted, only
	# that the default clock is callable and an unreachable budget never yields
	var state: Dictionary = _new_state()
	var task: TimeSlicedPlannerTask = TimeSlicedPlannerTask.new(UNREACHABLE_SLICE_USEC)

	# Act
	task.start(_work(task, FIXTURE_EVALS, state))

	# Assert
	assert_bool(task.is_live()).is_false()
	assert_int(task.result()).is_equal(_plain_total(FIXTURE_EVALS))


func test_time_sliced_before_start_polls_true_not_live() -> void:
	# Arrange
	var task: TimeSlicedPlannerTask = _time_sliced(_new_state())

	# Act
	var finished: bool = task.poll()

	# Assert
	assert_bool(finished).is_true()
	assert_bool(task.is_live()).is_false()
	assert_that(task.result()).is_null()


func test_time_sliced_errored_work_gives_null_result_and_finishes() -> void:
	# Arrange
	var task: TimeSlicedPlannerTask = _time_sliced(_new_state())
	var work: Callable = _erroring_work()

	# Act — the script error is expected and captured
	await assert_error(func() -> void: task.start(work)).is_runtime_error(any_string())

	# Assert
	assert_bool(task.poll()).is_true()
	assert_bool(task.is_live()).is_false()
	assert_that(task.result()).is_null()


# --- AC-4: WorkerPoolPlannerTask, fake pool ------------------------------------

func test_worker_start_submits_to_pool_at_normal_priority_as_boss_ai() -> void:
	# Arrange
	var pool: FakePool = FakePool.new()
	var task: WorkerPoolPlannerTask = _worker(pool)

	# Act
	task.start(_work(task, FIXTURE_EVALS, _new_state()))

	# Assert
	assert_array(pool.calls).is_equal([["add_task", false, "boss_ai"]])
	assert_bool(task.is_live()).is_true()


func test_worker_poll_returns_false_while_task_not_completed() -> void:
	# Arrange
	var pool: FakePool = FakePool.new()
	var task: WorkerPoolPlannerTask = _worker(pool)
	task.start(_work(task, FIXTURE_EVALS, _new_state()))

	# Act
	var polls: Array[bool] = [task.poll(), task.poll(), task.poll()]

	# Assert — one is_task_completed per poll, with the pool's id; no wait yet
	var one_poll: Array = ["is_task_completed", FAKE_TASK_ID]
	assert_array(polls).not_contains([true])
	assert_array(pool.calls.slice(1)).is_equal([one_poll, one_poll, one_poll])
	assert_int(pool.count("wait_for_task_completion")).is_equal(0)
	assert_bool(task.is_live()).is_true()


func test_worker_poll_waits_exactly_once_then_returns_true_with_value() -> void:
	# Arrange
	var pool: FakePool = FakePool.new()
	var task: WorkerPoolPlannerTask = _worker(pool)
	task.start(_work(task, FIXTURE_EVALS, _new_state()))
	task.poll()
	pool.finish()

	# Act
	var finished: bool = task.poll()

	# Assert
	assert_bool(finished).is_true()
	assert_bool(task.is_live()).is_false()
	assert_array(pool.calls.back()).is_equal(["wait_for_task_completion", FAKE_TASK_ID])
	assert_int(pool.count("wait_for_task_completion")).is_equal(1)
	assert_int(task.result()).is_equal(_plain_total(FIXTURE_EVALS))


func test_worker_polls_after_completion_never_touch_pool() -> void:
	# Arrange
	var pool: FakePool = FakePool.new()
	var task: WorkerPoolPlannerTask = _worker(pool)
	task.start(_work(task, FIXTURE_EVALS, _new_state()))
	pool.finish()
	task.poll()
	var calls_at_completion: int = pool.calls.size()

	# Act
	var again: Array[bool] = [task.poll(), task.poll(), task.poll(), task.poll()]

	# Assert — the id is released: no is_task_completed after the wait
	assert_array(again).not_contains([false])
	assert_int(pool.calls.size()).is_equal(calls_at_completion)
	assert_bool(pool.polled_after_wait).is_false()
	assert_int(pool.count("wait_for_task_completion")).is_equal(1)


func test_worker_before_start_polls_true_without_pool_calls() -> void:
	# Arrange
	var pool: FakePool = FakePool.new()
	var task: WorkerPoolPlannerTask = _worker(pool)

	# Act
	var finished: bool = task.poll()

	# Assert
	assert_bool(finished).is_true()
	assert_array(pool.calls).is_empty()
	assert_that(task.result()).is_null()


func test_worker_coroutine_work_returns_value_through_no_op_checkpoint() -> void:
	# Arrange
	var pool: FakePool = FakePool.new()
	var task: WorkerPoolPlannerTask = _worker(pool)
	var state: Dictionary = _new_state()
	task.start(_work(task, FIXTURE_EVALS, state))

	# Act — the pool body runs the work to the end in one call
	pool.finish()
	task.poll()

	# Assert — never suspended: every checkpoint returned, the value is an int
	assert_int(state["checkpoints_returned"]).is_equal(FIXTURE_EVALS)
	assert_int(typeof(task.result())).is_equal(TYPE_INT)
	assert_array(state["live_seen"]).not_contains([false])


func test_worker_errored_work_gives_null_result_and_finishes() -> void:
	# Arrange
	var pool: FakePool = FakePool.new()
	var task: WorkerPoolPlannerTask = _worker(pool)
	task.start(_erroring_work())

	# Act — the script error is expected and captured
	await assert_error(func() -> void: pool.finish()).is_runtime_error(any_string())
	var finished: bool = task.poll()

	# Assert
	assert_bool(finished).is_true()
	assert_bool(task.is_live()).is_false()
	assert_that(task.result()).is_null()


# --- all three: same work, same value -----------------------------------------

func test_same_work_gives_same_value_through_all_three_tasks() -> void:
	# Arrange
	var immediate: ImmediatePlannerTask = ImmediatePlannerTask.new()
	var sliced: TimeSlicedPlannerTask
	var sliced_state: Dictionary = _new_state()
	sliced = _time_sliced(sliced_state)
	var pool: FakePool = FakePool.new()
	var worker: WorkerPoolPlannerTask = _worker(pool)

	# Act
	immediate.start(_work(immediate, FIXTURE_EVALS, _new_state()))
	sliced.start(_work(sliced, FIXTURE_EVALS, sliced_state))
	while not sliced.poll():
		pass
	worker.start(_work(worker, FIXTURE_EVALS, _new_state()))
	pool.finish()
	worker.poll()

	# Assert
	assert_int(sliced.result()).is_equal(immediate.result())
	assert_int(worker.result()).is_equal(immediate.result())
