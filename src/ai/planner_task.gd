## The seam the match driver drives to run Boss AI planning work (ADR-0006
## Key Interfaces; architecture.md §API Boundaries, Core — Boss AI).
##
## One task object runs one piece of planning work exactly once. The work is a
## `Callable` taking no arguments and returning the plan as a `Variant`. On
## Godot 4.7.2 planning work is a coroutine (it awaits [method checkpoint]), so
## the work is always built in `src/ai/` in this shape (ADR-0006 erratum
## 2026-11-03):
## [codeblock]
## func() -> Variant: return await boss_ai.plan_turn(sandbox)
## [/codeblock]
## Each implementation calls it dynamically through `work.call()`, which is what
## lets the call site skip the static coroutine check.
##
## Three implementations exist: [WorkerPoolPlannerTask] (the default, runs the
## work on a pool thread), [TimeSlicedPlannerTask] (the fallback, runs it on the
## main thread in slices) and `ImmediatePlannerTask` (tests and the sim harness
## only, under `tests/helpers/`). The composition root picks one from
## `runtime.planner_mode`; consumers code against this base and never downcast.
##
## Every override of a typed method here must end in an explicit `return`
## (Godot 4.7: an override of a typed method inherits its return type).
##
## Usage (the caller owns the task; one `poll()` per frame):
## [codeblock]
## task.start(boss_ai.plan_task(sandbox))
## # each frame:
## if task.poll():
##     var plan: Variant = task.result()
## [/codeblock]
@abstract class_name PlannerTask extends RefCounted

## Keeps this script alive through engine shutdown (TD-013): the engine clears it
## when its shutdown walk reaches this script, so a subclass's release cannot free
## this script mid-walk. `load()`, not the class name: naming the class here leaks
## the script at exit. Remove with the move to Godot 4.8 (godotengine/godot#117991).
static var _teardown_anchor: Script = load("res://src/ai/planner_task.gd")


## The work's return value once it finished; `null` before then and when the
## work errored. Written by the implementations, read through [method result].
var _result: Variant = null

## `true` from [method start] until the work has finished. Written by the
## implementations, read through [method is_live].
var _live: bool = false


## Starts [param work] (a `Callable() -> Variant`). Called exactly once per task
## object. Sets [method is_live] to `true` before the work begins.
@abstract func start(work: Callable) -> void


## Returns `true` once the work has finished (and on every later call), `false`
## while it is still running. Called at most once per frame by the driver.
## A task that was never started reports `true`: nothing is pending.
@abstract func poll() -> bool


## The work's return value. Valid only after [method poll] returned `true`;
## `null` when the work errored.
func result() -> Variant:
	return _result


## `true` from [method start] until the work has finished.
func is_live() -> bool:
	return _live


## Cooperative yield point. Planning code awaits it between candidate
## evaluations and between lethal-search nodes. The base (and the worker and
## immediate implementations) is a plain no-op with no await inside, so
## `await planner.checkpoint()` returns immediately; [TimeSlicedPlannerTask]
## overrides it to yield once the current slice is spent. Kept declared here so
## every call dispatches dynamically (engine validation 2026-11-03, (c)).
func checkpoint() -> void:
	return
