## A scripted [PlannerTask] for the match driver's suites (ADR-0008 Validation
## Criteria; boss-ai-match-driver story 013). Its work never runs: [method start]
## only records the call, and [method poll] answers `false`
## [member polls_before_done] times and then `true`, handing back
## [member scripted_result]. A test therefore decides when a task "returns"
## relative to the player's commands, and no worker ever starts (`tests/unit/**`
## must not; ADR-0006).
##
## The work Callable is not kept: `BossAI.plan_task` builds it around this very
## task, so holding it would be a `RefCounted` cycle that outlives the test.
## [codeblock]
## var task := FakePlannerTask.new()
## task.polls_before_done = 2
## task.scripted_result = plan
## var driver := MatchDriver.new(config, db, {}, MatchDriverFixture.same_task(task))
## [/codeblock]
class_name FakePlannerTask extends PlannerTask

## How many times [method poll] answers `false` after each [method start].
var polls_before_done: int = 0
## What [method result] gives once the task finished.
var scripted_result: Variant = null
## Called at the top of every [method poll]; a test advances its clock here.
var on_poll: Callable = Callable()
## Calls to [method start].
var starts: int = 0
## Calls to [method poll], in every state.
var polls: int = 0
## Calls to [method poll] after it had answered `true` (the driver makes none).
var polls_after_done: int = 0

var _left: int = 0
var _done: bool = false


## Records the start; [param _work] is dropped (see the class description).
func start(_work: Callable) -> void:
	starts += 1
	_left = polls_before_done
	_done = false
	_result = null
	_live = true
	return


## Lets a running task finish at its next [method poll].
func finish() -> void:
	_left = 0
	return


## Re-reads [member polls_before_done] for a task already running and clears the poll
## counts: a test scripts a task the driver's schedule has started by itself.
func rearm() -> void:
	_left = polls_before_done
	polls = 0
	return


## The scripted answer. A task that was never started reports `true`, as the base
## contract says.
func poll() -> bool:
	polls += 1
	if on_poll.is_valid():
		on_poll.call()
	if _done:
		polls_after_done += 1
		return true
	if not _live:
		return true
	if _left > 0:
		_left -= 1
		return false
	_done = true
	_live = false
	_result = scripted_result
	return true
