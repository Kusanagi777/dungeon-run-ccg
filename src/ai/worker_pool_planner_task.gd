## The default [PlannerTask]: runs the work on a `WorkerThreadPool` thread and
## is polled once per frame (ADR-0006 Decision and Key Interfaces).
##
## Pool protocol (Probe A, 4.7.2 by observation only — threading has no page in
## `docs/engine-reference/godot/`): `add_task(callable, false, "boss_ai")`, then
## one `is_task_completed(id)` per [method poll], then
## `wait_for_task_completion(id)` exactly once after completion. The wait
## releases the id; polling it afterwards prints `ERROR: Invalid Task ID`, so a
## finished task never touches the pool again.
##
## The work runs off the main thread and may touch only what it closes over: a
## `RulesEngine.clone()`, the `ai_<floor>` stream and the frozen `CardDatabase`.
## [method checkpoint] stays the base no-op, so the work never suspends here.
##
## The three pool calls are injected Callables defaulting to the real pool, so
## unit tests drive [method poll] with a scripted fake and never start a worker
## (`tests/unit/**` never starts one; the real pool is exercised by the
## boss-ai integration tests).
class_name WorkerPoolPlannerTask extends PlannerTask


## Pool task description passed to `add_task` (ADR-0006 Decision).
const TASK_DESCRIPTION: String = "boss_ai"

## Pool id of the running task; `-1` when none is held.
var _task_id: int = -1

## `add_task(callable: Callable, high_priority: bool, description: String) -> int`.
var _add_task: Callable

## `is_task_completed(id: int) -> bool`.
var _is_task_completed: Callable

## `wait_for_task_completion(id: int) -> Error`.
var _wait_for_task_completion: Callable


## Builds a task over the real pool, or over the three injected pool calls
## (signatures as on the fields above; tests only).
func _init(
		add_task: Callable = WorkerThreadPool.add_task,
		is_task_completed: Callable = WorkerThreadPool.is_task_completed,
		wait_for_task_completion: Callable = WorkerThreadPool.wait_for_task_completion
) -> void:
	_add_task = add_task
	_is_task_completed = is_task_completed
	_wait_for_task_completion = wait_for_task_completion


## Submits [param work] to the pool at normal priority. Returns at once.
func start(work: Callable) -> void:
	_live = true
	_task_id = _add_task.call(_run.bind(work), false, TASK_DESCRIPTION)
	return


## `false` while the pool reports the task running; on the first completed
## poll, waits once to release the id and returns `true`; `true` on every later
## call without touching the pool.
func poll() -> bool:
	if not _live:
		return true
	if not _is_task_completed.call(_task_id):  # poll BEFORE wait, never after
		return false
	_wait_for_task_completion.call(_task_id)  # releases the id (probe A: ERROR if polled after)
	_task_id = -1
	_live = false
	return true


## Pool-thread body: stores the work's value (`null` when the work errored).
func _run(work: Callable) -> void:
	_result = work.call()
	return
