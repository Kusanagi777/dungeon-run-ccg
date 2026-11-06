## The test and sim-harness [PlannerTask]: runs the work to the end inside
## [method start] (ADR-0006 Key Interfaces). Production never uses it, so it
## lives with the test helpers.
##
## [method checkpoint] stays the base no-op, so a coroutine work never suspends
## and `work.call()` returns its value directly (engine validation 2026-11-03,
## claim 11). `tests/unit/**` and the sim harness inject this task and never
## start a worker.
##
## Usage:
## [codeblock]
## var task := ImmediatePlannerTask.new()
## task.start(func() -> Variant: return await plan(task))
## assert_bool(task.poll()).is_true()
## var plan: Variant = task.result()
## [/codeblock]
class_name ImmediatePlannerTask extends PlannerTask


## Runs [param work] synchronously; [method is_live] is `true` while it runs.
func start(work: Callable) -> void:
	_live = true
	_result = work.call()
	_live = false
	return


## Always `true`: the work finished inside [method start].
func poll() -> bool:
	return true
