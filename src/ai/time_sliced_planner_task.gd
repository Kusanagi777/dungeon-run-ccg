## The fallback [PlannerTask]: runs the work as a coroutine on the main thread,
## one slice per [method poll] (ADR-0006 Decision and Key Interfaces).
##
## [method start] runs the work until the first [method checkpoint] at which the
## slice clock shows at least [member slice_usec] elapsed; the work suspends
## there. Each [method poll] restarts the slice clock and resumes the work
## synchronously, inside the call, until the next over-budget checkpoint or the
## end of the work. Selected by the composition root when
## `runtime.planner_mode == "time_sliced"` or `--ai-sync` is given.
##
## The slice clock is an injected `Callable() -> int` returning microseconds,
## default `Time.get_ticks_usec`; tests pass a scripted clock, so where the work
## suspends is deterministic. A slice overruns [member slice_usec] by at most
## the work done between two checkpoints (Probe A: 1,000-op chunks hold
## 2.09–2.11 ms; measured by the boss-ai perf job, not asserted in unit tests).
class_name TimeSlicedPlannerTask extends PlannerTask


## Emitted by [method poll] to resume work suspended in [method checkpoint].
## Private: nothing outside this task connects to it.
signal _resume

## Slice budget in microseconds: `runtime.slice_ms × 1000` from
## `ai_profiles.json`, never a literal (boss-ai A29).
var slice_usec: int

## Slice clock, microseconds.
var _clock: Callable

## Clock reading when the current slice began.
var _slice_start_usec: int = 0

## `true` once the work has returned.
var _done: bool = false


## Builds a task with a slice budget of [param budget_usec] microseconds and the
## slice clock [param clock] (`Callable() -> int`, microseconds).
func _init(budget_usec: int, clock: Callable = Time.get_ticks_usec) -> void:
	slice_usec = budget_usec
	_clock = clock


## Runs [param work] on the main thread until its first over-budget
## [method checkpoint], or to the end if it never goes over.
func start(work: Callable) -> void:
	_live = true
	_slice_start_usec = _clock.call()
	_run(work)  # coroutine; runs until the first over-budget checkpoint
	return


## `true` once the work has finished (and for a task never started). Otherwise
## restarts the slice clock, resumes the work for one slice and returns whether
## it finished in that slice.
func poll() -> bool:
	if _done or not _live:
		return true
	_slice_start_usec = _clock.call()
	_resume.emit()  # resumes the coroutine synchronously inside poll()
	return _done


## `true`: each [method poll] runs one slice of the work.
func slices_main_thread() -> bool:
	return true


## Suspends the work until the next [method poll] once the current slice has
## used [member slice_usec] or more; otherwise returns at once.
func checkpoint() -> void:
	if _clock.call() - _slice_start_usec >= slice_usec:
		await _resume
	return


## Coroutine body: stores the work's value (`null` when the work errored).
func _run(work: Callable) -> void:
	_result = await work.call()
	_done = true
	_live = false
	return
