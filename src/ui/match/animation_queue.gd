## The match-view animation scheduler (design/gdd/match-ui.md U4 rules 1-8,
## F3; ADR-0009 Decision 1-2 and Key Interfaces).
##
## Owns *timing* only. It holds the FIFO of `AnimStep`s the view-state
## produced, plays them on a clock that `MatchView._process` drives through
## [method advance] (fake deltas in tests — never `await`, `Timer` or
## `Engine.time_scale`), and ends every step — animated or skipped — by calling
## its idempotent `run_final()` (its `apply_final`), which is what makes the
## display equal the view-state. It never creates a Tween and never touches a
## Node: presenters tween on [signal step_started] and kill their tweens on
## [signal skipped]; a presenter that never responds still sees its step end at
## `d_eff` (the clock is authoritative, ADR-0009 verification item 2).
##
## Scheduling:
## - Steps play in enqueue (`seq`) order. A step flagged `parallel_ok` starts
##   with the step before it when both share a `group_id` (U4.2); the batch's
##   steps end in order, so every `apply_final` runs in `seq` order.
## - Coalescing at enqueue (U4.3): within the open group, damage / heal pops
##   from one source on more than `COALESCE_THRESHOLD` distinct targets become
##   one simultaneous step whose members' `apply_final`s run in `seq` order.
## - F3: `d_eff = 0` at `instant` (no [signal step_started]: `apply_final`
##   only), else `d_base / SPEED_DIV[anim_speed]`. Impact extras
##   (`{hit_stop_ms, shake_ms, slow_ms}`) are kept only at `normal` without
##   `reduce_motion`; hit-stop and slow-down extend the step's hold on the
##   queue-local clock, shake runs alongside.
## - [method skip_all] (U4.5): [signal skipped] first, then every remaining
##   `apply_final` in order in the same call, then [signal drained] — one
##   layout pass for presenters, not one per step.
##
## Divisors and the threshold come from `config("match_ui")`; `anim_speed` and
## `reduce_motion` from the DD-X07 settings dictionary (`SettingsBus` /
## `config("profile_defaults")`), never from literals here.
## [codeblock]
## var queue := AnimationQueue.new(db.config("match_ui"), {"anim_speed": bus.get_setting(&"anim_speed"),
##         "reduce_motion": bus.get_setting(&"reduce_motion")})
## queue.step_started.connect(presenter.on_step_started)
## for step: AnimStep in view.apply(event):
##     queue.enqueue(step)
## # MatchView._process(delta):
## queue.advance(delta)
## [/codeblock]
class_name AnimationQueue
extends RefCounted

## A step began playing for [param d_eff] seconds; presenters that own its
## entities tween toward the state its `apply_final` will set. Not emitted at
## `instant`.
signal step_started(step: AnimStep, d_eff: float)
## A step ended: its `apply_final` has just run.
signal step_finished(step: AnimStep)
## The queue went idle (after playback or a skip): every presenter equals the
## view-state (U4.6); presenters do their one layout pass here.
signal drained()
## [method skip_all] was called: presenters kill their live tweens now.
signal skipped()

## DD-X07 `anim_speed` labels with a meaning here: `instant` never divides
## (F3), and impact extras survive only at `normal`.
const SPEED_INSTANT: String = "instant"
const SPEED_NORMAL: String = "normal"
## The impact-extra keys of `AnimStep.impact`.
const IMPACT_KEYS: Array[String] = ["hit_stop_ms", "shake_ms", "slow_ms"]
## Extras that pause / stretch the step's clock (shake plays alongside).
const _HOLD_KEYS: Array[String] = ["hit_stop_ms", "slow_ms"]
const _POP_KINDS: Array[StringName] = [AnimStep.DAMAGE_POP, AnimStep.HEAL_POP]
const _MS_PER_S: float = 1000.0

var _speed_div: Dictionary = {}
var _threshold: int = 0
var _anim_speed: String = ""
var _reduce_motion: bool = false
var _pending: Array[AnimStep] = []
# The playing batch, and the seconds each of its steps has left (same order).
var _active: Array[AnimStep] = []
var _remaining: Array[float] = []
# Coalescing buckets of the open group: "kind|source" → {targets, members, merged}.
var _buckets: Dictionary = {}
var _bucket_group: int = -1
# True from the first enqueue until the next drained.
var _busy: bool = false


## A queue over the `config("match_ui")` body [param ui_config] (file keys
## `speed_div` and `coalesce_threshold` — the GDD's `SPEED_DIV` /
## `COALESCE_THRESHOLD` knobs, snake_case per DD-T01) and the settings [param settings] (`anim_speed`,
## `reduce_motion`; DD-X07 labels).
## [codeblock]
## var queue := AnimationQueue.new(db.config("match_ui"), {"anim_speed": "normal", "reduce_motion": false})
## [/codeblock]
func _init(ui_config: Dictionary, settings: Dictionary) -> void:
	_speed_div = (ui_config.get("speed_div", {}) as Dictionary).duplicate(true)
	_threshold = int(ui_config.get("coalesce_threshold", 0))
	if _threshold <= 0:
		push_error("AnimationQueue: config(\"match_ui\").coalesce_threshold is missing or not positive")
	set_speed(StringName(str(settings.get("anim_speed", ""))))
	set_reduce_motion(settings.get("reduce_motion", false) == true)


## Appends [param step] (U4.2), coalescing it into the open group's pop step
## from the same source once more than `COALESCE_THRESHOLD` distinct targets
## are pending (U4.3).
## [codeblock]
## for step: AnimStep in view.apply(event): queue.enqueue(step)
## [/codeblock]
func enqueue(step: AnimStep) -> void:
	_busy = true
	if step.group_id != _bucket_group:
		_buckets.clear()
		_bucket_group = step.group_id
	if not _coalesce(step):
		_pending.append(step)


## Advances the queue's clock by [param delta] seconds (U4.8): ends every step
## whose time is up, starts the next batch, and repeats within the same
## [param delta] — so a zero-length step (`instant`) ends in the call that
## starts it. O(active steps) per frame. Emits [signal drained] when the queue
## empties.
## [codeblock]
## func _process(delta: float) -> void: queue.advance(delta)
## [/codeblock]
func advance(delta: float) -> void:
	var budget: float = maxf(delta, 0.0)
	while true:
		if _active.is_empty():
			if _pending.is_empty():
				break
			_start_batch()
		_finish_leading()
		if _active.is_empty():
			continue
		if budget <= 0.0:
			break
		var dt: float = minf(budget, _remaining[0])
		for i: int in _remaining.size():
			_remaining[i] -= dt
		budget -= dt
	_drain_if_idle()


## U4.5 skip-all: emits [signal skipped] (presenters kill their tweens), then
## ends every playing and queued step in order in this call — each
## `apply_final` once — drops the coalescing buckets and impact holds, and
## emits [signal drained] if anything was queued. On an idle queue it emits
## [signal skipped] only.
## [codeblock]
## queue.skip_all()   # MatchController.submit calls this first (U4.7, story 003)
## [/codeblock]
func skip_all() -> void:
	skipped.emit()
	var rest: Array[AnimStep] = _active.duplicate()
	rest.append_array(_pending)
	_active.clear()
	_remaining.clear()
	_pending.clear()
	_buckets.clear()
	_bucket_group = -1
	for step: AnimStep in rest:
		step.run_final()
		step_finished.emit(step)
	_drain_if_idle()


## True when no step is playing or queued.
## [codeblock]
## end_turn_button.disabled = not queue.is_idle()
## [/codeblock]
func is_idle() -> bool:
	return _active.is_empty() and _pending.is_empty()


## Applies the DD-X07 label [param anim_speed] (`instant`, or a `SPEED_DIV`
## key) to steps that start from now on. An unknown label is reported and
## plays as `instant` (final states only — the display stays correct).
## [codeblock]
## bus.settings_changed.connect(func(key: StringName, value: Variant) -> void:
##     if key == &"anim_speed": queue.set_speed(StringName(value)))
## [/codeblock]
func set_speed(anim_speed: StringName) -> void:
	_anim_speed = String(anim_speed)
	if _anim_speed != SPEED_INSTANT and not _speed_div.has(_anim_speed):
		push_error("AnimationQueue: anim_speed '%s' is neither '%s' nor a speed_div key %s" % [_anim_speed, SPEED_INSTANT, _speed_div.keys()])


## [param on] drops every impact extra at every speed; base durations are
## unchanged (Tuning Knobs `reduce_motion`).
## [codeblock]
## queue.set_reduce_motion(true)
## [/codeblock]
func set_reduce_motion(on: bool) -> void:
	_reduce_motion = on


## F3: the seconds [param step] plays at the current speed —
## `0` at `instant` (or an unknown label), else `base_duration_s / SPEED_DIV[anim_speed]`.
## [codeblock]
## queue.effective_duration(lunge)   # 0.35 at normal, 0.175 at fast
## [/codeblock]
func effective_duration(step: AnimStep) -> float:
	var divisor: float = float(_speed_div.get(_anim_speed, 0.0))
	if _anim_speed == SPEED_INSTANT or divisor <= 0.0:
		return 0.0
	return step.base_duration_s / divisor


## F3 impact extras of [param step] at the current settings,
## `{hit_stop_ms, shake_ms, slow_ms}`: the step's own values (scaled by the
## `normal` divisor) at `normal`, all 0 at `fast`, `instant` or under
## `reduce_motion`.
## [codeblock]
## queue.effective_impact(pop).hit_stop_ms   # 60 at normal, 0 at fast
## [/codeblock]
func effective_impact(step: AnimStep) -> Dictionary:
	var keep: bool = _anim_speed == SPEED_NORMAL and not _reduce_motion and _speed_div.has(SPEED_NORMAL)
	var out: Dictionary = {}
	for key: String in IMPACT_KEYS:
		var value: float = float(step.impact.get(key, 0)) / float(_speed_div[SPEED_NORMAL]) if keep else 0.0
		out[key] = int(round(value))
	return out


## Boss-turn mode (F4 gap and compression) — match-ui story 010. No-op here.
## [codeblock]
## queue.enter_boss_turn({"intent_banner_s": 0.3, "ai_action_delay_s": 0.6, "max_turn_playback_s": 10.0, "MIN_ACTION_GAP_S": 0.15, "K_MIN": 0.25})
## [/codeblock]
func enter_boss_turn(_pacing: Dictionary) -> void:
	pass


## Leaves boss-turn mode — match-ui story 010. No-op here.
func exit_boss_turn() -> void:
	pass


# --- internals ---------------------------------------------------------------------

## Starts the next step and every following `parallel_ok` step of its group.
func _start_batch() -> void:
	var head: AnimStep = _pending.pop_front()
	_start(head)
	while not _pending.is_empty() and _pending[0].parallel_ok and _pending[0].group_id == head.group_id:
		_start(_pending.pop_front())


func _start(step: AnimStep) -> void:
	var d_eff: float = effective_duration(step)
	var hold: float = d_eff
	var extras: Dictionary = effective_impact(step)
	for key: String in _HOLD_KEYS:
		hold += float(extras[key]) / _MS_PER_S
	_active.append(step)
	_remaining.append(hold)
	if _anim_speed != SPEED_INSTANT:
		step_started.emit(step, d_eff)


## Ends the batch's leading steps whose time is up, in order: a step that
## finished early waits for the ones before it, so finals stay in `seq` order.
func _finish_leading() -> void:
	while not _active.is_empty() and _remaining[0] <= 0.0:
		var step: AnimStep = _active.pop_front()
		_remaining.pop_front()
		step.run_final()
		step_finished.emit(step)


func _drain_if_idle() -> void:
	if _busy and is_idle():
		_busy = false
		drained.emit()


## U4.3: true when [param step] joined (or became) a coalesced pop.
func _coalesce(step: AnimStep) -> bool:
	if not _POP_KINDS.has(step.kind) or step.entity_ids.size() != 1 or not step.data.has("source"):
		return false
	var key: String = "%s|%s" % [step.kind, var_to_str(step.data.source)]
	if not _buckets.has(key):
		_buckets[key] = {"targets": {}, "members": [], "merged": null}
	var bucket: Dictionary = _buckets[key]
	var target: int = step.entity_ids[0]
	if bucket.targets.has(target):
		return false
	var merged: Variant = bucket.merged
	if merged != null:
		if not _pending.has(merged):
			return false
		bucket.targets[target] = true
		(merged as AnimStep).members.append(step)
		(merged as AnimStep).entity_ids.append(target)
		return true
	bucket.targets[target] = true
	(bucket.members as Array).append(step)
	if (bucket.members as Array).size() <= _threshold:
		return false
	# One past the threshold: fold every still-queued member into one step.
	var members: Array[AnimStep] = []
	for member: AnimStep in bucket.members:
		if member != step and not _pending.has(member):
			return false
		members.append(member)
	var first: AnimStep = members[0]
	var pop: AnimStep = AnimStep.new(step.kind, [], first.base_duration_s, step.group_id, first.seq)
	pop.parallel_ok = first.parallel_ok
	pop.impact = first.impact.duplicate()
	pop.data = {"source": step.data.source, "coalesced": members.size()}
	pop.members = members
	for member: AnimStep in members:
		pop.entity_ids.append(member.entity_ids[0])
	var index: int = _pending.find(first)
	for member: AnimStep in members:
		_pending.erase(member)
	_pending.insert(index, pop)
	bucket.merged = pop
	return true
