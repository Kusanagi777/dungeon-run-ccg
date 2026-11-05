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
## **Boss-turn mode** (U6, F4; ADR-0009 Decision 2; DD-X23). `MatchView` calls
## [method enter_boss_turn] on `turn_started{side: boss}` and
## [method exit_boss_turn] on `turn_started{side: player}`, before it enqueues that
## event's steps. The mode paces the plan, which is every step from the
## `ai_intent_committed` step ([constant AnimStep.INTENT_COMMIT]) up to the exit.
## Steps queued before the commit are the Start step's: they play at once, in FIFO
## order, and the plan's first group cannot pass them (U4.2).
##
## | Phase | Entered | Left when | Plan steps |
## |---|---|---|---|
## | `OFF` | start; the queue drained after the exit | [method enter_boss_turn] | not paced |
## | `BEAT` | [method enter_boss_turn] | plan here and `intent_banner_s` passed → `PLAYBACK`; no plan at `planner_target_s` → `THINKING`; [method skip_all] with the plan here, or the exit with no plan → `PLAYBACK` | held |
## | `THINKING` | the cap passed with no plan; [signal boss_thinking_changed] `true` | the plan arrives, or the exit → `PLAYBACK`; the signal `false` | held |
## | `PLAYBACK` | as above | the queue drained after the exit → `OFF` | paced |
##
## The commit step takes no time of its own: its time is the beat. F4 is computed
## when the first group would start, over the groups then queued, with
## `intent_banner_s` however long the beat ran: the stretch is planning time. Later
## groups reuse that `gap` and `k`. From that start a clock runs up from
## `intent_banner_s`, while a plan step is queued or playing: a wait with nothing to
## show, such as the player's own Choice and the re-plan after it, is not playback.
## When the clock reaches `max_turn_playback_s` the rest is skipped. At `instant`
## nothing is held and F4 is 0 (Edge Cases).
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
## The commit beat reached `planner_target_s` with no plan ([param on] `true`), or the
## wait ended (`false`). The intent banner shows "boss thinking" between the two
## (U6.2, DD-X23; rendered by story 015).
signal boss_thinking_changed(on: bool)

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
## What [method enter_boss_turn] needs. ADR-0009 names the first five; DD-X23 adds
## `planner_target_s`, the cap on the commit beat.
const PACING_KEYS: Array[String] = ["intent_banner_s", "ai_action_delay_s", "max_turn_playback_s", "MIN_ACTION_GAP_S", "K_MIN", "planner_target_s"]
## Below this, two times on the queue's clock are the same time.
const _EPSILON_S: float = 0.000001
const _NO_SEQ: int = -1
const _NO_GROUP: int = -1

## The boss-turn phases: see the table in the class description.
enum _BossPhase { OFF, BEAT, THINKING, PLAYBACK }

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
# The highest `seq` enqueued.
var _last_seq: int = _NO_SEQ
var _boss_phase: _BossPhase = _BossPhase.OFF
var _pacing: Dictionary = {}
var _beat_elapsed_s: float = 0.0
# The `seq` of the commit step, once it arrived: the plan starts there.
var _commit_seq: int = _NO_SEQ
# The last boss-turn `seq`, set by exit_boss_turn: later steps are not paced.
var _exit_seq: int = _NO_SEQ
var _exit_requested: bool = false
# F4, computed at the first group.
var _f4_ready: bool = false
var _gap_s: float = 0.0
var _k: float = 1.0
# Runs from `intent_banner_s` at the first group towards `max_turn_playback_s`.
var _turn_clock_s: float = 0.0
# The gap still to run since the last group ended, and that group.
var _gap_left_s: float = 0.0
var _last_group: int = _NO_GROUP


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
	_last_seq = maxi(_last_seq, step.seq)
	if _boss_phase != _BossPhase.OFF and _commit_seq == _NO_SEQ and step.kind == AnimStep.INTENT_COMMIT:
		_commit_seq = step.seq
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
		_finish_leading()
		_auto_skip_if_due()
		_update_boss_phase()
		if _active.is_empty() and not _pending.is_empty() and not _head_is_held():
			_start_batch()
			continue
		if budget <= 0.0:
			break
		var wait: float = _next_event_s()
		if is_inf(wait) and _boss_phase == _BossPhase.OFF:
			break
		var dt: float = minf(budget, wait)
		_run_clocks(dt)
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
	_skip_queued(_pending.size())


## U4.5 over what is playing and the first [param count] queued steps.
func _skip_queued(count: int) -> void:
	skipped.emit()
	var rest: Array[AnimStep] = _active.duplicate()
	rest.append_array(_pending.slice(0, count))
	_active.clear()
	_remaining.clear()
	_pending = _pending.slice(count)
	_buckets.clear()
	_bucket_group = -1
	_gap_left_s = 0.0
	if _commit_seq != _NO_SEQ and _boss_phase == _BossPhase.BEAT:
		_boss_phase = _BossPhase.PLAYBACK
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


## The [method enter_boss_turn] pacing of a turn (F4's table): Boss AI's
## `presentation` and `runtime` from [param ai_profiles], the `config("ai_profiles")`
## body, read-only; `MIN_ACTION_GAP_S` and `K_MIN` from [param ui_config], the
## `config("match_ui")` body; and `ai_action_delay_s` from [param settings]'
## `action_delay_ms` when present (DD-X07), else `presentation.action_delay_s`.
## [codeblock]
## queue.enter_boss_turn(AnimationQueue.boss_pacing(db.config("match_ui"), db.config("ai_profiles"), settings))
## [/codeblock]
static func boss_pacing(ui_config: Dictionary, ai_profiles: Dictionary, settings: Dictionary) -> Dictionary:
	var presentation: Dictionary = ai_profiles.presentation
	var delay_s: float = float(presentation.action_delay_s)
	if settings.get("action_delay_ms") != null:
		delay_s = float(settings.action_delay_ms) / _MS_PER_S
	return {
		"intent_banner_s": float(presentation.intent_banner_s),
		"ai_action_delay_s": delay_s,
		"max_turn_playback_s": float(presentation.max_turn_playback_s),
		"MIN_ACTION_GAP_S": float(ui_config.min_action_gap_s),
		"K_MIN": float(ui_config.k_min),
		"planner_target_s": float(ai_profiles.runtime.planner_target_ms) / _MS_PER_S,
	}


## Enters boss-turn mode with the [param pacing] of [method boss_pacing]: the commit
## beat starts now, at End Turn (DD-X23). See the class description.
## [codeblock]
## if event.type == "turn_started" and event.payload.side == "boss":
##     queue.enter_boss_turn(pacing)
## [/codeblock]
func enter_boss_turn(pacing: Dictionary) -> void:
	for key: String in PACING_KEYS:
		if not pacing.has(key):
			push_error("AnimationQueue: the boss pacing has no '%s'" % key)
	_pacing = pacing.duplicate()
	_boss_phase = _BossPhase.BEAT
	_beat_elapsed_s = 0.0
	_commit_seq = _NO_SEQ
	_exit_seq = _NO_SEQ
	_exit_requested = false
	_f4_ready = false
	_gap_s = 0.0
	_k = 1.0
	_turn_clock_s = 0.0
	_gap_left_s = 0.0
	_last_group = _NO_GROUP


## Asks to leave boss-turn mode. Every step enqueued from now on is the player's and
## plays unpaced; the mode ends when the queue drains (U6.5), so call this before
## enqueuing the steps of `turn_started{side: player}`. A turn that brought no plan
## stops waiting for one here. No-op outside the mode.
## [codeblock]
## if event.type == "turn_started" and event.payload.side == "player":
##     queue.exit_boss_turn()
## [/codeblock]
func exit_boss_turn() -> void:
	if _boss_phase == _BossPhase.OFF:
		return
	_exit_requested = true
	_exit_seq = _last_seq
	if _commit_seq == _NO_SEQ:
		_leave_wait()


## True from [method enter_boss_turn] until the queue drained after
## [method exit_boss_turn]: `InputRouter.controls_locked` reads it.
func boss_turn_active() -> bool:
	return _boss_phase != _BossPhase.OFF


## True while the commit beat runs.
func commit_beat_active() -> bool:
	return _boss_phase == _BossPhase.BEAT


## True while the "boss thinking" state shows: see [signal boss_thinking_changed].
func boss_thinking() -> bool:
	return _boss_phase == _BossPhase.THINKING


## F4 for a turn of [param groups] command groups and [param steps_s] seconds of steps
## (`A` and `D`), at the current pacing and speed: `{gap, total, k}`, `total` being
## `T` before `k`. All 0 but `k` at `instant`, where F4 degenerates to `T = 0`.
## [codeblock]
## queue.boss_turn_timing(5, 2.5)   # {gap: 0.6, total: 5.2, k: 1.0}
## [/codeblock]
func boss_turn_timing(groups: int, steps_s: float) -> Dictionary:
	if _is_instant():
		return {"gap": 0.0, "total": 0.0, "k": 1.0}
	var budget: float = float(_pacing.max_turn_playback_s)
	var banner: float = float(_pacing.intent_banner_s)
	var spans: int = maxi(groups - 1, 1)
	var room: float = (budget - banner - steps_s) / spans
	# The floor wins over a delay below it (F4 table, `ai_action_delay_s`).
	var gap: float = maxf(minf(room, float(_pacing.ai_action_delay_s)), float(_pacing.MIN_ACTION_GAP_S))
	var total: float = banner + steps_s + gap * (groups - 1)
	var k: float = 1.0
	if total > budget + _EPSILON_S:
		k = maxf(budget / total, float(_pacing.K_MIN))
	return {"gap": gap, "total": total, "k": k}


# --- internals ---------------------------------------------------------------------

## Starts the next step and every following `parallel_ok` step of its group.
func _start_batch() -> void:
	var head: AnimStep = _pending.pop_front()
	if _is_plan_group_step(head):
		if not _f4_ready:
			_compute_f4(head)
		_last_group = head.group_id
	_start(head)
	while not _pending.is_empty() and _pending[0].parallel_ok and _pending[0].group_id == head.group_id:
		_start(_pending.pop_front())


func _start(step: AnimStep) -> void:
	var scale: float = _k if _is_plan_group_step(step) else 1.0
	if _is_commit(step):
		scale = 0.0
	var d_eff: float = effective_duration(step) * scale
	var hold: float = d_eff
	var extras: Dictionary = effective_impact(step)
	step.live_impact = {}
	for key: String in IMPACT_KEYS:
		step.live_impact[key] = float(extras[key]) * scale
	for key: String in _HOLD_KEYS:
		hold += float(step.live_impact[key]) / _MS_PER_S
	_active.append(step)
	_remaining.append(hold)
	if _anim_speed != SPEED_INSTANT:
		step_started.emit(step, d_eff)


## Ends the batch's leading steps whose time is up, in order: a step that
## finished early waits for the ones before it, so finals stay in `seq` order. The
## last step of a plan group starts its gap.
func _finish_leading() -> void:
	while not _active.is_empty() and _remaining[0] <= 0.0:
		var step: AnimStep = _active.pop_front()
		_remaining.pop_front()
		if _active.is_empty() and _is_plan_group_step(step):
			_gap_left_s = _gap_s * _k
		step.run_final()
		step_finished.emit(step)


func _drain_if_idle() -> void:
	var idle: bool = is_idle()
	if idle and _exit_requested:
		_boss_phase = _BossPhase.OFF
		_exit_requested = false
	if _busy and idle:
		_busy = false
		drained.emit()


func _is_instant() -> bool:
	return _anim_speed == SPEED_INSTANT or float(_speed_div.get(_anim_speed, 0.0)) <= 0.0


## True for a step of the plan, the commit step included.
func _is_plan_step(step: AnimStep) -> bool:
	if _boss_phase == _BossPhase.OFF or _commit_seq == _NO_SEQ or step.seq < _commit_seq:
		return false
	return not _exit_requested or step.seq <= _exit_seq


func _is_commit(step: AnimStep) -> bool:
	return step.seq == _commit_seq and step.kind == AnimStep.INTENT_COMMIT and _is_plan_step(step)


## True for a step of a command group of the plan: F4's `A` and `D` count these.
func _is_plan_group_step(step: AnimStep) -> bool:
	return _is_plan_step(step) and not _is_commit(step)


## F4 over [param head] and the plan steps still queued behind it.
func _compute_f4(head: AnimStep) -> void:
	var groups: Dictionary = {head.group_id: true}
	var steps_s: float = effective_duration(head)
	for step: AnimStep in _pending:
		if _is_plan_group_step(step):
			groups[step.group_id] = true
			steps_s += effective_duration(step)
	var timing: Dictionary = boss_turn_timing(groups.size(), steps_s)
	_gap_s = float(timing.gap)
	_k = float(timing.k)
	_turn_clock_s = float(_pacing.intent_banner_s)
	_f4_ready = true


## The beat's own transitions: the table in the class description.
func _update_boss_phase() -> void:
	var plan_here: bool = _commit_seq != _NO_SEQ
	match _boss_phase:
		_BossPhase.BEAT:
			if plan_here and (_is_instant() or _beat_elapsed_s >= _banner_s() - _EPSILON_S):
				_boss_phase = _BossPhase.PLAYBACK
			elif not plan_here and _beat_elapsed_s >= _beat_cap_s() - _EPSILON_S:
				_boss_phase = _BossPhase.THINKING
				boss_thinking_changed.emit(true)
		_BossPhase.THINKING:
			if plan_here:
				_leave_wait()


## Ends the beat or the wait, and says so if "boss thinking" was showing.
func _leave_wait() -> void:
	var was_thinking: bool = _boss_phase == _BossPhase.THINKING
	_boss_phase = _BossPhase.PLAYBACK
	if was_thinking:
		boss_thinking_changed.emit(false)


func _banner_s() -> float:
	return float(_pacing.intent_banner_s)


## The longest the beat runs: `planner_target_s`, and never under the banner, which
## is its minimum (F4 table).
func _beat_cap_s() -> float:
	return maxf(float(_pacing.planner_target_s), _banner_s())


## True when the first queued step must wait: for the beat, or for its group's gap.
func _head_is_held() -> bool:
	var head: AnimStep = _pending[0]
	if not _is_plan_step(head) or _is_instant():
		return false
	if _boss_phase == _BossPhase.BEAT or _boss_phase == _BossPhase.THINKING:
		return true
	return _waits_for_gap(head)


func _waits_for_gap(head: AnimStep) -> bool:
	return _gap_left_s > 0.0 and _last_group != _NO_GROUP and head.group_id != _last_group


## F4's last rule: once the clock reaches `max_turn_playback_s`, what is left of the
## plan is skipped. A group a later tick added reaches the same rule with `k` above
## `K_MIN` (ADR-0009 Decision 2), and so does the banner's share of a compressed turn,
## since `k` was computed after the beat. The player's steps behind the plan play on.
func _auto_skip_if_due() -> void:
	if not _f4_ready or _boss_phase != _BossPhase.PLAYBACK:
		return
	if _turn_clock_s < float(_pacing.max_turn_playback_s) - _EPSILON_S:
		return
	var plan_left: int = 0
	while plan_left < _pending.size() and _is_plan_step(_pending[plan_left]):
		plan_left += 1
	var playing: bool = not _active.is_empty() and _remaining[0] > _EPSILON_S and _is_plan_step(_active[0])
	if playing or plan_left > 0:
		_skip_queued(plan_left)


## Seconds until something changes on the queue's clocks; `INF` when only time passes.
func _next_event_s() -> float:
	var wait: float = INF
	if not _active.is_empty():
		wait = _remaining[0]
	if _boss_phase == _BossPhase.BEAT:
		for mark: float in [_banner_s(), _beat_cap_s()]:
			if mark - _beat_elapsed_s > _EPSILON_S:
				wait = minf(wait, mark - _beat_elapsed_s)
	if _gap_left_s > 0.0:
		wait = minf(wait, _gap_left_s)
	if _f4_ready and _boss_phase == _BossPhase.PLAYBACK:
		var left: float = float(_pacing.max_turn_playback_s) - _turn_clock_s
		if left > _EPSILON_S:
			wait = minf(wait, left)
	return wait


func _run_clocks(dt: float) -> void:
	for i: int in _remaining.size():
		_remaining[i] -= dt
	_gap_left_s = maxf(_gap_left_s - dt, 0.0)
	if _boss_phase == _BossPhase.BEAT or _boss_phase == _BossPhase.THINKING:
		_beat_elapsed_s += dt
	elif _f4_ready and _boss_phase == _BossPhase.PLAYBACK and _plan_step_left():
		_turn_clock_s += dt


## True while a plan step plays or waits at the head of the queue.
func _plan_step_left() -> bool:
	if not _active.is_empty() and _is_plan_step(_active[0]):
		return true
	return not _pending.is_empty() and _is_plan_step(_pending[0])


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
