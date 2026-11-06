## Integration: [WorkerPoolPlannerTask] on the real `WorkerThreadPool` (ADR-0006 Key
## Interfaces, Probe A's polled-per-frame pattern; story 017 AC 2). The suite's own
## `await get_tree().process_frame` plays `MatchView._process`.
##
## The stderr half of the AC (no `Invalid Task ID`) is the run's output: a poll after the
## wait is what prints it, so [method test_poll_after_finish_does_not_touch_the_pool]
## counts the pool calls that would.
extends GdUnitTestSuite

const WORKLOAD_SIZE: int = 20000
const EXPECTED_SUM: int = 199990000
## A frame bound that a stuck task cannot wait out.
const MAX_FRAMES: int = 5000


## The RefCounted-only workload: a sum, and which thread ran it, and a checkpoint.
class Workload:
	extends RefCounted

	var thread_id: int = 0
	var checkpoint_awaited: bool = false

	func run(task: PlannerTask) -> Variant:
		thread_id = OS.get_thread_caller_id()
		var total: int = 0
		for index: int in WORKLOAD_SIZE:
			total += index
		await task.checkpoint()
		checkpoint_awaited = true
		return total


## Pool calls, scripted, so a poll count is exact.
class CountingPool:
	extends RefCounted

	var completed_asks: int = 0
	var waits: int = 0

	func add_task(work: Callable, _high_priority: bool, _description: String) -> int:
		work.call()
		return 1

	func is_task_completed(_id: int) -> bool:
		completed_asks += 1
		return true

	func wait_for_task_completion(_id: int) -> Error:
		waits += 1
		return OK


func _polled(task: PlannerTask) -> int:
	var frames: int = 0
	while not task.poll() and frames < MAX_FRAMES:
		frames += 1
		await get_tree().process_frame
	return frames


func test_worker_result_equals_the_immediate_result() -> void:
	# Arrange
	var on_worker: Workload = Workload.new()
	var worker: WorkerPoolPlannerTask = WorkerPoolPlannerTask.new()
	var at_once: Workload = Workload.new()
	var immediate: ImmediatePlannerTask = ImmediatePlannerTask.new()

	# Act
	worker.start(func() -> Variant: return await on_worker.run(worker))
	var frames: int = await _polled(worker)
	immediate.start(func() -> Variant: return await at_once.run(immediate))

	# Assert
	assert_int(frames).is_less(MAX_FRAMES)
	assert_int(int(worker.result())).is_equal(EXPECTED_SUM)
	assert_int(int(immediate.result())).is_equal(int(worker.result()))


func test_worker_work_runs_off_the_main_thread() -> void:
	# Arrange
	var workload: Workload = Workload.new()
	var task: WorkerPoolPlannerTask = WorkerPoolPlannerTask.new()

	# Act
	task.start(func() -> Variant: return await workload.run(task))
	@warning_ignore("return_value_discarded")
	await _polled(task)

	# Assert
	assert_int(workload.thread_id).is_not_equal(0)
	assert_int(workload.thread_id).is_not_equal(OS.get_main_thread_id())


func test_worker_checkpoint_does_not_yield_the_work() -> void:
	# Arrange
	var workload: Workload = Workload.new()
	var task: WorkerPoolPlannerTask = WorkerPoolPlannerTask.new()

	# Act
	task.start(func() -> Variant: return await workload.run(task))
	@warning_ignore("return_value_discarded")
	await _polled(task)

	# Assert — a yield would leave the work parked and the result null
	assert_bool(workload.checkpoint_awaited).is_true()
	assert_that(task.result()).is_not_null()


func test_task_is_live_until_a_poll_sees_it_finish() -> void:
	# Arrange
	var workload: Workload = Workload.new()
	var task: WorkerPoolPlannerTask = WorkerPoolPlannerTask.new()

	# Act
	task.start(func() -> Variant: return await workload.run(task))
	var live_after_start: bool = task.is_live()
	@warning_ignore("return_value_discarded")
	await _polled(task)

	# Assert
	assert_bool(live_after_start).is_true()
	assert_bool(task.is_live()).is_false()


func test_poll_after_finish_does_not_touch_the_pool() -> void:
	# Arrange — the protocol: one wait, and a finished task never asks again
	var pool: CountingPool = CountingPool.new()
	var task: WorkerPoolPlannerTask = WorkerPoolPlannerTask.new(pool.add_task, pool.is_task_completed, pool.wait_for_task_completion)
	task.start(func() -> Variant: return 1)

	# Act
	assert_bool(task.poll()).is_true()
	assert_bool(task.poll()).is_true()
	assert_bool(task.poll()).is_true()

	# Assert
	assert_int(pool.completed_asks).is_equal(1)
	assert_int(pool.waits).is_equal(1)
