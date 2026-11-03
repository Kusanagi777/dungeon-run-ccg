## A Node-free presenter double for `AnimationQueue` tests (match-ui story
## 002; ADR-0009 Key Interfaces `Presenter`: `bind`, `apply_final`,
## `sync_report`).
##
## It "displays" one value per entity — the `MatchViewState.entity(id)` copy —
## and changes it only in [method apply_final], from the view-state, for the
## step's `entity_ids` (the U1 rule: a presenter never stores a value the
## view-state does not have). [method bind] snapshots the display *before* a
## burst is projected, so until a step's `apply_final` runs its entities show
## the old values and [method sync_report] lists them. It also records the
## order and count of `apply_final` calls and the queue's signals.
## [codeblock]
## var presenter := FakePresenter.new()
## presenter.bind(view)                       # display = view-state now
## for step: AnimStep in view.apply(event):
##     presenter.bind_step(step)
##     queue.enqueue(step)
## presenter.listen(queue)
## queue.skip_all()
## assert(presenter.sync_report().is_empty())
## [/codeblock]
class_name FakePresenter
extends RefCounted

## `seq` of every `apply_final` call, in call order (coalesced members each count).
var final_seqs: Array[int] = []
## `apply_final` calls per step (keyed by the step's instance id).
var final_counts: Dictionary = {}
## `"started <kind>"` / `"finished <kind>"` per queue signal, in emission order.
var timeline: Array[String] = []
## `[step, d_eff]` per `step_started`.
var started: Array = []
var finished_count: int = 0
var skipped_count: int = 0
var drained_count: int = 0

var _view: MatchViewState
var _display: Dictionary = {}


## Takes the view-state's current entity values as the display.
func bind(view: MatchViewState) -> void:
	_view = view
	_display.clear()
	for id: int in view.entity_ids():
		_display[id] = view.entity(id)


## Binds [param step]'s `apply_final` (and its members') to this presenter.
func bind_step(step: AnimStep) -> void:
	step.apply_final = apply_final.bind(step)
	for member: AnimStep in step.members:
		bind_step(member)


## Connects to [param queue]'s four signals.
func listen(queue: AnimationQueue) -> void:
	queue.step_started.connect(_on_started)
	queue.step_finished.connect(_on_finished)
	queue.skipped.connect(_on_skipped)
	queue.drained.connect(_on_drained)


## Idempotent: sets the display of the step's entities to the view-state.
func apply_final(step: AnimStep) -> void:
	final_seqs.append(step.seq)
	var key: int = step.get_instance_id()
	final_counts[key] = int(final_counts.get(key, 0)) + 1
	if _view == null:
		return
	for id: int in step.entity_ids:
		var now: Dictionary = _view.entity(id)
		if now.is_empty():
			_display.erase(id)
		else:
			_display[id] = now


## `[]` when every displayed entity equals the view-state and nothing gone is
## still shown; else one line per difference.
func sync_report() -> Array[String]:
	var report: Array[String] = []
	for id: int in _view.entity_ids():
		var now: Dictionary = _view.entity(id)
		if not _display.has(id):
			report.append("entity %d: not shown, view-state %s" % [id, now])
		elif _display[id] != now:
			report.append("entity %d: shows %s, view-state %s" % [id, _display[id], now])
	for id: int in _display:
		if _view.entity(id).is_empty():
			report.append("entity %d: shown but gone from the view-state" % id)
	return report


func _on_started(step: AnimStep, d_eff: float) -> void:
	timeline.append("started %s" % step.kind)
	started.append([step, d_eff])


func _on_finished(step: AnimStep) -> void:
	timeline.append("finished %s" % step.kind)
	finished_count += 1


func _on_skipped() -> void:
	timeline.append("skipped")
	skipped_count += 1


func _on_drained() -> void:
	timeline.append("drained")
	drained_count += 1
