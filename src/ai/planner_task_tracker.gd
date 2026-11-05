## Answers "is any [PlannerTask] live?" for `CardDatabase.reload()` (ADR-0006
## Implementation Guidelines; boss-ai-match-driver story 019).
##
## A driver gets a new task per plan (DD-X31), so no one task can stand for a driver. The
## composition root passes every task source through [method tracking], and hands
## [method any_live] to the database as its busy predicate, which keeps `src/core/` free
## of planner names (ADR-0001).
##
## It holds tasks by [WeakRef]: a task's work holds the [BossAI], which holds the
## database, so a strong reference from the predicate would be a `RefCounted` cycle. A
## task freed is a task not live, because the driver keeps its running task until it
## finished.
##
## Main thread only: [method any_live] reads what `start` and `poll` write there.
## [codeblock]
## var tracker := PlannerTaskTracker.new()
## db.set_reload_busy(tracker.any_live)
## var driver := MatchDriver.new(config, db, settings, tracker.tracking(source))
## [/codeblock]
class_name PlannerTaskTracker
extends RefCounted

## Every task made and not yet seen finished.
var _tasks: Array[WeakRef] = []


## [param source], a `Callable() -> PlannerTask`, with each task it makes remembered.
## [codeblock]
## var planner_factory: Callable = tracker.tracking(func() -> PlannerTask: return WorkerPoolPlannerTask.new())
## [/codeblock]
func tracking(source: Callable) -> Callable:
	return func() -> PlannerTask: return _remember(source.call())


## `true` while any task a [method tracking] source made is live.
## [codeblock]
## tracker.any_live()   # false between matches
## [/codeblock]
func any_live() -> bool:
	_forget_finished()
	return not _tasks.is_empty()


## Keeps [param task] and gives it back. The ones before it were started by the time this
## one is made, so a task that is not live has finished.
func _remember(task: PlannerTask) -> PlannerTask:
	_forget_finished()
	_tasks.append(weakref(task))
	return task


func _forget_finished() -> void:
	_tasks = _tasks.filter(func(held: WeakRef) -> bool:
		var task: PlannerTask = held.get_ref()
		return task != null and task.is_live())
