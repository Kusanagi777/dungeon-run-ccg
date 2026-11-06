## Boss-turn pacing: F4, the commit beat over planning, the control lock (match-ui
## story 010; design/gdd/match-ui.md U6, F4, AC L8, L16; DD-X23; ADR-0009 Decision 2).
##
## Everything runs on a fake clock: a frame is `_frame()`, which raises [member _now]
## by [constant DT], lets [member _on_frame] act as `MatchController.tick()` would, then
## calls `queue.advance(DT)`, the order `MatchView._process` uses. The Boss AI knobs
## are the shipped `ai_profiles.json` body, read as an imported resource, so "at
## defaults" and the `planner_target_ms` cap are the data's values and no literal here.
extends GdUnitTestSuite

const AI_PROFILES: String = "res://assets/data/ai_profiles.json"
const DT: float = 0.005
## A frame's worth, plus float slack, for a time read at a frame boundary.
const NEAR: float = 0.0051
const TIGHT: float = 0.001
const BOSS: String = "boss"
const PLAYER: String = "player"
## The first `seq` a test's steps use; the turn's own events sit below it.
const FIRST_SEQ: int = 100
const COMMIT_GROUP: int = 99

var _now: float = 0.0
var _frames: int = 0
var _on_frame: Callable = Callable()
## True from `_plan_after` until its task answered.
var _awaiting_plan: bool = false
## `{kind, group, at, d_eff}` per `step_started`, in order.
var _starts: Array[Dictionary] = []
## `{seq, at}` per `step_finished`.
var _finishes: Array[Dictionary] = []
var _skips: int = 0
var _drains: int = 0
## `[on, at]` per `boss_thinking_changed`.
var _thinking: Array = []
var _next_seq: int = FIRST_SEQ


func before_test() -> void:
	_now = 0.0
	_frames = 0
	_on_frame = Callable()
	_awaiting_plan = false
	_starts = []
	_finishes = []
	_skips = 0
	_drains = 0
	_thinking = []
	_next_seq = FIRST_SEQ


# --- helpers -------------------------------------------------------------------------

func _profiles() -> Dictionary:
	return ((load(AI_PROFILES) as JSON).data as Dictionary).config


## The pacing of a turn with [param settings], over [param ui_config] when given.
func _pacing(settings: Dictionary = {}, ui_config: Dictionary = MatchUiTestConfig.body()) -> Dictionary:
	return AnimationQueue.boss_pacing(ui_config, _profiles(), settings)


## A queue already in boss-turn mode at `_now` = 0, watched by this suite.
func _boss_queue(settings: Dictionary = {}, ui_config: Dictionary = MatchUiTestConfig.body()) -> AnimationQueue:
	var queue: AnimationQueue = AnimationQueue.new(ui_config, MatchUiTestConfig.settings(settings))
	queue.step_started.connect(func(step: AnimStep, d_eff: float) -> void:
		_starts.append({"kind": step.kind, "group": step.group_id, "at": _now, "d_eff": d_eff}))
	queue.step_finished.connect(func(step: AnimStep) -> void:
		_finishes.append({"seq": step.seq, "at": _now}))
	queue.skipped.connect(func() -> void: _skips += 1)
	queue.drained.connect(func() -> void: _drains += 1)
	queue.boss_thinking_changed.connect(func(on: bool) -> void: _thinking.append([on, _now]))
	queue.enter_boss_turn(_pacing(settings, ui_config))
	return queue


func _step(kind: StringName, duration_s: float, group: int) -> AnimStep:
	_next_seq += 1
	return AnimStep.new(kind, [], duration_s, group, _next_seq)


## The `ai_intent_committed` step, which opens the plan.
func _commit(queue: AnimationQueue) -> void:
	queue.enqueue(_step(AnimStep.INTENT_COMMIT, 0.3, COMMIT_GROUP))


## [param count] command groups of one [param each_s] step, from group [param first].
func _groups(queue: AnimationQueue, count: int, each_s: float, first: int = 1000) -> void:
	for index: int in count:
		queue.enqueue(_step(AnimStep.PLAY_CARD, each_s, first + index))


## The plan as one burst: the commit, then the groups.
func _burst(queue: AnimationQueue, count: int, each_s: float) -> void:
	_commit(queue)
	_groups(queue, count, each_s)


func _frame(queue: AnimationQueue) -> void:
	_frames += 1
	_now = _frames * DT
	if _on_frame.is_valid():
		_on_frame.call()
	queue.advance(DT)


## Frames until [param seconds] on the clock.
func _run_to(queue: AnimationQueue, seconds: float) -> void:
	while _now < seconds - DT / 2.0:
		_frame(queue)


## Frames until the queue is idle, at most to [param limit_s].
func _run_until_idle(queue: AnimationQueue, limit_s: float = 40.0) -> void:
	_frame(queue)
	while (_awaiting_plan or not queue.is_idle()) and _now < limit_s:
		_frame(queue)


func _action_starts() -> Array[Dictionary]:
	return _starts.filter(func(row: Dictionary) -> bool: return row.kind == AnimStep.PLAY_CARD)


## A [FakePlannerTask] that answers `true` on the frame at [param ms]; on that frame
## [param plan] runs, as the replay of the plan would.
func _plan_after(ms: int, queue: AnimationQueue, plan: Callable) -> FakePlannerTask:
	var task: FakePlannerTask = FakePlannerTask.new()
	task.polls_before_done = roundi(ms / 1000.0 / DT) - 1
	task.start(Callable())
	_awaiting_plan = true
	_on_frame = func() -> void:
		if _awaiting_plan and task.poll():
			_awaiting_plan = false
			plan.call(queue)
	return task


func _first_action_at_for_planner(ms: int) -> float:
	var queue: AnimationQueue = _boss_queue()
	@warning_ignore("return_value_discarded")
	_plan_after(ms, queue, func(q: AnimationQueue) -> void: _burst(q, 2, 0.2))
	_run_until_idle(queue)
	return float(_action_starts()[0].at)


# --- L8: F4 at defaults --------------------------------------------------------------

@warning_ignore("unused_parameter")
func test_f4_gives_the_gdd_numbers_at_defaults(groups: int, seconds: float, gap: float, total: float, k: float, test_parameters: Array = [
	[12, 7.0, 0.245, 10.0, 1.0],
	[30, 15.0, 0.15, 19.65, 0.509],
	[5, 2.5, 0.6, 5.2, 1.0],
]) -> void:
	# Arrange
	var queue: AnimationQueue = _boss_queue()

	# Act
	var timing: Dictionary = queue.boss_turn_timing(groups, seconds)

	# Assert
	assert_float(float(timing.gap)).is_equal_approx(gap, TIGHT)
	assert_float(float(timing.total)).is_equal_approx(total, TIGHT)
	assert_float(float(timing.k)).is_equal_approx(k, TIGHT)


func test_a_busy_turn_of_12_groups_plays_in_10_seconds() -> void:
	# Arrange
	var queue: AnimationQueue = _boss_queue()
	_burst(queue, 12, 7.0 / 12.0)

	# Act
	_run_until_idle(queue)

	# Assert
	var starts: Array[Dictionary] = _action_starts()
	assert_float(float(starts[0].at)).is_equal_approx(0.3, NEAR)
	assert_float(float(starts[1].at) - float(starts[0].at)).is_equal_approx(7.0 / 12.0 + 0.245, 2.0 * NEAR)
	assert_float(_now).is_equal_approx(10.0, 2.0 * NEAR)
	assert_int(_skips).is_equal(0)


func test_a_degenerate_turn_of_30_groups_compresses_by_k_and_plays_in_10_seconds() -> void:
	# Arrange
	var queue: AnimationQueue = _boss_queue()
	_burst(queue, 30, 0.5)

	# Act
	_run_until_idle(queue)

	# Assert
	var starts: Array[Dictionary] = _action_starts()
	assert_float(float(starts[0].d_eff)).is_equal_approx(0.5 * 0.509, TIGHT)
	assert_float(float(starts[1].at) - float(starts[0].at)).is_equal_approx((0.5 + 0.15) * 0.509, 2.0 * NEAR)
	assert_float(_now).is_equal_approx(10.0, 2.0 * NEAR)


func test_a_typical_turn_of_5_groups_plays_in_5_2_seconds() -> void:
	# Arrange
	var queue: AnimationQueue = _boss_queue()
	_burst(queue, 5, 0.5)

	# Act
	_run_until_idle(queue)

	# Assert
	var starts: Array[Dictionary] = _action_starts()
	assert_float(float(starts[1].at) - float(starts[0].at)).is_equal_approx(0.5 + 0.6, 2.0 * NEAR)
	assert_float(_now).is_equal_approx(5.2, 2.0 * NEAR)


func test_one_group_divides_by_one_and_uses_no_gap() -> void:
	# Arrange
	var queue: AnimationQueue = _boss_queue()
	_burst(queue, 1, 0.5)

	# Act
	var timing: Dictionary = queue.boss_turn_timing(1, 0.5)
	_run_until_idle(queue)

	# Assert
	assert_float(float(timing.total)).is_equal_approx(0.8, TIGHT)
	assert_float(_now).is_equal_approx(0.8, 2.0 * NEAR)


func test_every_step_of_a_group_plays_with_no_gap_inside_it() -> void:
	# Arrange
	var queue: AnimationQueue = _boss_queue()
	_commit(queue)
	queue.enqueue(_step(AnimStep.PLAY_CARD, 0.5, 1000))
	queue.enqueue(_step(AnimStep.PLAY_CARD, 0.5, 1000))
	queue.enqueue(_step(AnimStep.PLAY_CARD, 0.5, 1001))

	# Act
	_run_until_idle(queue)

	# Assert: two groups, so one gap, and A counts groups rather than steps
	var starts: Array[Dictionary] = _action_starts()
	assert_float(float(starts[1].at) - float(starts[0].at)).is_equal_approx(0.5, 2.0 * NEAR)
	assert_float(float(starts[2].at) - float(starts[1].at)).is_equal_approx(0.5 + 0.6, 2.0 * NEAR)


# --- L16: the setting ----------------------------------------------------------------

func test_action_delay_ms_sets_the_gap_when_present() -> void:
	# Arrange
	var queue: AnimationQueue = _boss_queue({"action_delay_ms": 1200})

	# Act
	var timing: Dictionary = queue.boss_turn_timing(5, 2.5)

	# Assert
	assert_float(float(timing.gap)).is_equal_approx(1.2, TIGHT)
	assert_float(float(timing.total)).is_equal_approx(7.6, TIGHT)


func test_an_absent_setting_falls_back_to_the_boss_ai_value() -> void:
	# Arrange
	var pacing: Dictionary = _pacing({})

	# Act / Assert
	assert_float(float(pacing.ai_action_delay_s)).is_equal(float(_profiles().presentation.action_delay_s))


func test_a_delay_under_the_floor_still_gets_min_action_gap() -> void:
	# Arrange
	var queue: AnimationQueue = _boss_queue({"action_delay_ms": 0})

	# Act
	var timing: Dictionary = queue.boss_turn_timing(5, 2.5)

	# Assert
	assert_float(float(timing.gap)).is_equal_approx(float(MatchUiTestConfig.body().min_action_gap_s), TIGHT)


func test_the_gap_floor_and_k_min_come_from_the_config() -> void:
	# Arrange
	var body: Dictionary = MatchUiTestConfig.body()
	body.min_action_gap_s = 0.3
	body.k_min = 0.5
	var queue: AnimationQueue = _boss_queue({}, body)

	# Act
	var timing: Dictionary = queue.boss_turn_timing(30, 60.0)

	# Assert
	assert_float(float(timing.gap)).is_equal_approx(0.3, TIGHT)
	assert_float(float(timing.k)).is_equal_approx(0.5, TIGHT)


# --- anim_speed ----------------------------------------------------------------------

func test_instant_degenerates_to_t_zero_with_no_beat() -> void:
	# Arrange
	var queue: AnimationQueue = _boss_queue({"anim_speed": "instant"})
	_burst(queue, 5, 0.5)

	# Act
	var timing: Dictionary = queue.boss_turn_timing(5, 0.0)
	_frame(queue)

	# Assert
	assert_float(float(timing.total)).is_equal(0.0)
	assert_bool(queue.is_idle()).is_true()
	assert_int(_finishes.size()).is_equal(6)
	assert_float(_now).is_equal_approx(DT, TIGHT)


func test_fast_halves_d_and_keeps_the_gap() -> void:
	# Arrange
	var queue: AnimationQueue = _boss_queue({"anim_speed": "fast"})
	_burst(queue, 5, 0.5)

	# Act
	_run_until_idle(queue)

	# Assert: 0.3 + 5 x 0.25 + 4 x 0.6
	assert_float(_now).is_equal_approx(3.95, 2.0 * NEAR)


# --- the commit beat -----------------------------------------------------------------

func test_the_commit_beat_plays_before_the_first_group_and_the_commit_step_adds_no_time() -> void:
	# Arrange
	var queue: AnimationQueue = _boss_queue()
	_burst(queue, 2, 0.2)

	# Act
	_run_to(queue, 0.25)
	var during: int = _starts.size()
	var beat: bool = queue.commit_beat_active()
	_run_until_idle(queue)

	# Assert
	assert_int(during).override_failure_message("a plan step started inside the beat").is_equal(0)
	assert_bool(beat).is_true()
	assert_that(_starts[0].kind).is_equal(AnimStep.INTENT_COMMIT)
	assert_float(float(_starts[0].at)).is_equal_approx(0.3, NEAR)
	assert_float(float(_starts[0].d_eff)).is_equal(0.0)
	assert_float(float(_action_starts()[0].at)).is_equal_approx(0.3, NEAR)
	assert_bool(queue.commit_beat_active()).is_false()


func test_start_step_steps_play_inside_the_beat_and_fifo_holds_a_longer_one() -> void:
	# Arrange: the turn banner and the draw that precede any plan, 0.6 s in all
	var queue: AnimationQueue = _boss_queue()
	queue.enqueue(_step(AnimStep.TURN_BANNER, 0.4, 1))
	queue.enqueue(_step(AnimStep.DRAW, 0.2, 2))
	_burst(queue, 1, 0.2)

	# Act
	_run_until_idle(queue)

	# Assert
	assert_float(float(_starts[0].at)).is_equal_approx(DT, NEAR)
	assert_float(float(_action_starts()[0].at)).is_equal_approx(0.6, 2.0 * NEAR)


func test_groups_arriving_over_two_ticks_keep_the_gap_of_the_first_group() -> void:
	# Arrange: 2 groups at the first group give (10 - 0.3 - 1) / 1, clamped to 0.6
	var queue: AnimationQueue = _boss_queue({"action_delay_ms": 800})
	_burst(queue, 2, 0.5)
	_run_to(queue, 0.4)

	# Act: a second tick brings 8 more, enough that F4 over all ten would give less
	_groups(queue, 8, 1.0, 2000)
	var after: float = queue.boss_turn_timing(10, 9.0).gap
	_run_until_idle(queue)

	# Assert
	var starts: Array[Dictionary] = _action_starts()
	assert_float(after).is_less(0.8)
	assert_float(float(starts[2].at) - float(starts[1].at)).is_equal_approx(0.5 + 0.8, 2.0 * NEAR)
	assert_float(float(starts[3].at) - float(starts[2].at)).is_equal_approx(1.0 + 0.8, 2.0 * NEAR)


func test_a_gap_runs_while_the_queue_waits_for_the_next_tick() -> void:
	# Arrange
	var queue: AnimationQueue = _boss_queue()
	_burst(queue, 1, 0.2)
	_run_to(queue, 0.5)

	# Act: the group ended at 0.5; the next arrives 0.4 s into the 0.6 s gap
	_run_to(queue, 0.9)
	_groups(queue, 1, 0.2, 2000)
	_run_until_idle(queue)

	# Assert
	assert_float(float(_action_starts()[1].at)).is_equal_approx(1.1, 2.0 * NEAR)


func test_the_remainder_auto_skips_at_k_min_when_the_clock_reaches_the_budget() -> void:
	# Arrange: T = 64.65, so k = K_MIN = 0.25 and the turn would still take 16.1 s
	var queue: AnimationQueue = _boss_queue()
	_burst(queue, 30, 2.0)

	# Act
	_run_until_idle(queue)

	# Assert
	var starts: Array[Dictionary] = _action_starts()
	var seqs: Array = _finishes.map(func(row: Dictionary) -> int: return int(row.seq))
	var sorted: Array = seqs.duplicate()
	sorted.sort()
	assert_float(float(starts[0].d_eff)).is_equal_approx(2.0 * 0.25, TIGHT)
	assert_float(_now).is_equal_approx(10.0, 2.0 * NEAR)
	assert_int(_skips).is_equal(1)
	assert_int(_finishes.size()).is_equal(31)
	assert_that(seqs).is_equal(sorted)
	assert_int(_action_starts().size()).is_less(30)


func test_groups_a_late_tick_adds_past_the_budget_auto_skip_too() -> void:
	# Arrange: k = 1 at the first group, then a late burst that would run far past 10 s
	var queue: AnimationQueue = _boss_queue()
	_burst(queue, 1, 0.2)
	_run_to(queue, 0.6)
	_groups(queue, 30, 1.0, 2000)

	# Act
	_run_until_idle(queue)

	# Assert: 0.1 s of it was idle, which the turn clock does not count
	assert_float(_now).is_equal_approx(10.1, 2.0 * NEAR)
	assert_int(_skips).is_equal(1)


func test_skip_all_during_the_turn_flushes_the_plan_and_ends_the_beat() -> void:
	# Arrange
	var queue: AnimationQueue = _boss_queue()
	_burst(queue, 3, 0.5)
	_run_to(queue, 0.1)

	# Act
	queue.skip_all()

	# Assert
	assert_bool(queue.is_idle()).is_true()
	assert_int(_finishes.size()).is_equal(4)
	assert_bool(queue.commit_beat_active()).is_false()
	assert_bool(queue.boss_turn_active()).override_failure_message("skip must not end the turn").is_true()


# --- the control lock ----------------------------------------------------------------

func _router(queue: AnimationQueue, view: MatchViewState) -> InputRouter:
	var router: InputRouter = auto_free(InputRouter.new())
	router.bind(view, queue)
	return router


func _turn_started(view: MatchViewState, side: String, seq: int) -> Array[AnimStep]:
	return view.apply({"seq": seq, "turn": 2, "type": "turn_started", "payload": {"turn": 2, "side": side}, "cause_seq": 0})


func test_controls_lock_on_the_boss_turn_and_unlock_once_the_players_turn_has_drained() -> void:
	# Arrange
	var view: MatchViewState = MatchViewState.new(MatchUiTestConfig.body())
	var queue: AnimationQueue = AnimationQueue.new(MatchUiTestConfig.body(), MatchUiTestConfig.settings())
	var router: InputRouter = _router(queue, view)
	var before: bool = router.controls_locked()

	# Act
	queue.enter_boss_turn(_pacing())
	for step: AnimStep in _turn_started(view, BOSS, 10):
		queue.enqueue(step)
	var on_boss_turn: bool = router.controls_locked()
	_next_seq = 20
	_burst(queue, 1, 0.2)
	queue.exit_boss_turn()
	for step: AnimStep in _turn_started(view, PLAYER, 50):
		queue.enqueue(step)
	queue.enqueue(AnimStep.new(AnimStep.DRAW, [], 0.2, 51, 51))
	_run_to(queue, 0.6)
	var mid_draw: bool = router.controls_locked()
	_run_until_idle(queue)

	# Assert
	assert_bool(before).is_false()
	assert_bool(on_boss_turn).is_true()
	assert_bool(mid_draw).override_failure_message("unlocked before the queue drained").is_true()
	assert_bool(router.controls_locked()).is_false()
	assert_bool(queue.boss_turn_active()).is_false()


func test_a_locked_router_allows_skip_menu_and_feed_only() -> void:
	# Arrange
	var view: MatchViewState = MatchViewState.new(MatchUiTestConfig.body())
	var queue: AnimationQueue = _boss_queue()
	var router: InputRouter = _router(queue, view)

	# Act / Assert
	for intent: StringName in [&"skip", &"menu", &"feed"]:
		assert_bool(router.allows(intent)).override_failure_message("%s refused" % intent).is_true()
	for intent: StringName in [&"end_turn", &"select", &"drag_release", &"key_target"]:
		assert_bool(router.allows(intent)).override_failure_message("%s allowed" % intent).is_false()


func test_an_unlocked_router_allows_everything() -> void:
	# Arrange
	var view: MatchViewState = MatchViewState.new(MatchUiTestConfig.body())
	var queue: AnimationQueue = AnimationQueue.new(MatchUiTestConfig.body(), MatchUiTestConfig.settings())
	var router: InputRouter = _router(queue, view)

	# Act / Assert
	assert_bool(router.allows(&"end_turn")).is_true()


func test_the_players_steps_after_the_boss_turn_are_not_paced() -> void:
	# Arrange
	var queue: AnimationQueue = _boss_queue()
	_burst(queue, 30, 0.5)
	queue.exit_boss_turn()
	queue.enqueue(_step(AnimStep.DRAW, 0.2, 5000))
	var timing: Dictionary = queue.boss_turn_timing(30, 15.0)

	# Act
	_run_until_idle(queue)

	# Assert: F4 saw the 30 boss groups alone, and the auto-skip left the draw to play
	var draws: Array[Dictionary] = _starts.filter(func(row: Dictionary) -> bool: return row.kind == AnimStep.DRAW)
	assert_float(float(_action_starts()[0].d_eff)).is_equal_approx(0.5 * float(timing.k), TIGHT)
	assert_int(draws.size()).is_equal(1)
	assert_float(float(draws[0].d_eff)).is_equal_approx(0.2, TIGHT)
	assert_float(float(draws[0].at)).is_equal_approx(10.0, 2.0 * NEAR)
	assert_float(_now).is_equal_approx(10.2, 3.0 * NEAR)


func test_exit_on_an_idle_queue_ends_the_mode_at_the_next_advance() -> void:
	# Arrange
	var queue: AnimationQueue = _boss_queue()
	_burst(queue, 1, 0.2)
	_run_until_idle(queue)

	# Act
	queue.exit_boss_turn()
	var held: bool = queue.boss_turn_active()
	_frame(queue)

	# Assert
	assert_bool(held).is_true()
	assert_bool(queue.boss_turn_active()).is_false()


# --- a player's Choice on the boss's turn --------------------------------------------

func _player_choice(view: MatchViewState, seq: int) -> void:
	var payload: Dictionary = {"side": PLAYER, "kind": "discover", "source_id": 9, "effect_id": "x.0"}
	var offered: Dictionary = payload.duplicate()
	offered["option_card_ids"] = ["card_a"]
	var requested: Dictionary = payload.duplicate()
	requested["options"] = ["card_a"]
	@warning_ignore("return_value_discarded")
	view.apply({"seq": seq, "turn": 2, "type": "discover_offered", "payload": offered, "cause_seq": 5})
	@warning_ignore("return_value_discarded")
	view.apply({"seq": seq + 1, "turn": 2, "type": "choice_requested", "payload": requested, "cause_seq": 5})


func test_a_players_choice_on_the_boss_turn_lifts_the_lock_for_the_pick_alone() -> void:
	# Arrange: the boss's replay raised a Choice the player owes (States `ChoiceOpen`)
	var view: MatchViewState = MatchViewState.new(MatchUiTestConfig.body())
	var queue: AnimationQueue = _boss_queue()
	var router: InputRouter = _router(queue, view)
	@warning_ignore("return_value_discarded")
	_turn_started(view, BOSS, 10)
	var before: bool = router.controls_locked()

	# Act
	_player_choice(view, 20)
	var open: bool = router.controls_locked()
	var pick: bool = router.allows(&"choose")
	var end_turn: bool = router.allows(&"end_turn")
	var menu: bool = router.allows(&"menu")
	@warning_ignore("return_value_discarded")
	view.apply({"seq": 22, "turn": 2, "type": "choice_made", "payload": {"side": PLAYER, "option_index": 0}, "cause_seq": 5})

	# Assert
	assert_bool(before).is_true()
	assert_bool(open).override_failure_message("the player cannot answer their Choice").is_false()
	assert_bool(pick).is_true()
	assert_bool(end_turn).override_failure_message("a Choice has no other input").is_false()
	assert_bool(menu).is_true()
	assert_bool(router.controls_locked()).override_failure_message("the lock did not return").is_true()
	assert_bool(router.allows(&"choose")).is_false()


func test_a_boss_choice_keeps_the_lock() -> void:
	# Arrange
	var view: MatchViewState = MatchViewState.new(MatchUiTestConfig.body())
	var queue: AnimationQueue = _boss_queue()
	var router: InputRouter = _router(queue, view)
	@warning_ignore("return_value_discarded")
	_turn_started(view, BOSS, 10)

	# Act
	@warning_ignore("return_value_discarded")
	view.apply({"seq": 20, "turn": 2, "type": "choice_requested", "payload": {"side": BOSS, "kind": "discover", "options": ["card_a"], "source_id": 9, "effect_id": "x.0"}, "cause_seq": 5})

	# Assert
	assert_bool(router.controls_locked()).is_true()
	assert_bool(router.allows(&"choose")).is_false()


func test_the_turn_clock_stops_while_the_player_chooses_and_the_boss_replans() -> void:
	# Arrange: the first half of the turn has played, and the player takes 30 s to choose
	var queue: AnimationQueue = _boss_queue()
	_burst(queue, 2, 0.5)
	_run_until_idle(queue)
	var first_half: float = _now
	_run_to(queue, 30.0)

	# Act: the re-plan brings the second half
	_groups(queue, 3, 0.5, 2000)
	_run_until_idle(queue)

	# Assert
	assert_int(_skips).override_failure_message("the wait counted against the budget").is_equal(0)
	assert_int(_action_starts().size()).is_equal(5)
	assert_float(first_half).is_equal_approx(1.9, 2.0 * NEAR)
	assert_float(_now).is_equal_approx(30.0 + 3.0 * 0.5 + 2.0 * 0.6, 3.0 * NEAR)


func test_the_budget_still_bites_on_the_plan_after_a_choice() -> void:
	# Arrange
	var queue: AnimationQueue = _boss_queue()
	_burst(queue, 1, 0.5)
	_run_until_idle(queue)
	_run_to(queue, 30.0)

	# Act: 9.2 s of budget left from 0.8, and a second half far longer than that
	_groups(queue, 30, 1.0, 2000)
	_run_until_idle(queue, 60.0)

	# Assert
	assert_int(_skips).is_equal(1)
	assert_float(_now).is_equal_approx(30.0 + 9.2, 3.0 * NEAR)


# --- a boss Choice -------------------------------------------------------------------

func test_a_boss_choice_makes_one_step_of_0_4_seconds_with_no_options() -> void:
	# Arrange
	var view: MatchViewState = MatchViewState.new(MatchUiTestConfig.body())
	var boss_hero: int = 2
	view.apply({"seq": 1, "turn": 0, "type": "match_started", "payload": {"hero_id": 1, "boss_id": boss_hero}, "cause_seq": 0})
	var options: Array = ["card_a", "card_b", "card_c"]

	# Act
	var offered: Array[AnimStep] = view.apply({"seq": 6, "turn": 2, "type": "discover_offered", "payload": {"side": BOSS, "kind": "discover", "option_card_ids": options, "source_id": 9, "effect_id": "x.0"}, "cause_seq": 5})
	var requested: Array[AnimStep] = view.apply({"seq": 7, "turn": 2, "type": "choice_requested", "payload": {"side": BOSS, "kind": "discover", "options": options, "source_id": 9, "effect_id": "x.0"}, "cause_seq": 5})

	# Assert
	var steps: Array[AnimStep] = offered + requested
	assert_int(steps.size()).is_equal(1)
	assert_that(steps[0].kind).is_equal(AnimStep.BOSS_DISCOVERS)
	assert_float(steps[0].base_duration_s).is_equal_approx(0.4, TIGHT)
	assert_that(steps[0].entity_ids).is_equal([boss_hero] as Array[int])
	assert_bool(steps[0].data.is_empty()).override_failure_message("options on the step").is_true()
	assert_bool(view.pending_choice.has("options")).is_false()


func test_a_players_choice_makes_no_boss_discovers_step() -> void:
	# Arrange
	var view: MatchViewState = MatchViewState.new(MatchUiTestConfig.body())

	# Act
	var offered: Array[AnimStep] = view.apply({"seq": 6, "turn": 2, "type": "discover_offered", "payload": {"side": PLAYER, "kind": "discover", "option_card_ids": ["a"], "source_id": 9, "effect_id": "x.0"}, "cause_seq": 5})
	var requested: Array[AnimStep] = view.apply({"seq": 7, "turn": 2, "type": "choice_requested", "payload": {"side": PLAYER, "kind": "discover", "options": ["a"], "source_id": 9, "effect_id": "x.0"}, "cause_seq": 5})

	# Assert
	var steps: Array[AnimStep] = offered + requested
	assert_int(steps.size()).is_equal(1)
	assert_that(steps[0].kind).is_equal(AnimStep.OVERLAY_OPEN)


# --- NC-7, DD-X23: the beat stretches over planning ----------------------------------

@warning_ignore("unused_parameter")
func test_the_first_group_starts_at_the_longer_of_the_banner_and_the_planner(planner_ms: int, expected_s: float, test_parameters: Array = [
	[100, 0.3],
	[300, 0.3],
	[400, 0.4],
	[500, 0.5],
]) -> void:
	# Act
	var first: float = _first_action_at_for_planner(planner_ms)

	# Assert
	assert_float(first).is_equal_approx(expected_s, NEAR)
	assert_array(_thinking).override_failure_message("boss thinking inside the cap").is_empty()


func test_a_planner_past_the_cap_shows_boss_thinking_until_the_plan_arrives() -> void:
	# Arrange
	var queue: AnimationQueue = _boss_queue()
	var cap_s: float = float(_profiles().runtime.planner_target_ms) / 1000.0
	@warning_ignore("return_value_discarded")
	_plan_after(800, queue, func(q: AnimationQueue) -> void: _burst(q, 2, 0.2))

	# Act
	_run_to(queue, cap_s - 2.0 * DT)
	var before_cap: bool = queue.boss_thinking()
	_run_to(queue, cap_s + 2.0 * DT)
	var after_cap: bool = queue.boss_thinking()
	var beat_after_cap: bool = queue.commit_beat_active()
	_run_until_idle(queue)

	# Assert
	assert_bool(before_cap).is_false()
	assert_bool(after_cap).is_true()
	assert_bool(beat_after_cap).is_false()
	assert_bool(queue.boss_thinking()).is_false()
	assert_int(_thinking.size()).is_equal(2)
	assert_bool(bool(_thinking[0][0])).is_true()
	assert_float(float(_thinking[0][1])).is_equal_approx(cap_s, NEAR)
	assert_bool(bool(_thinking[1][0])).is_false()
	assert_float(float(_thinking[1][1])).is_equal_approx(0.8, NEAR)
	assert_float(float(_action_starts()[0].at)).is_equal_approx(0.8, NEAR)


@warning_ignore("unused_parameter")
func test_planning_time_never_counts_against_the_playback_budget(planner_ms: int, test_parameters: Array = [
	[100],
	[400],
	[800],
]) -> void:
	# Arrange: 12 groups, D = 7 s: F4 is exactly the budget, 9.7 s after the banner
	var queue: AnimationQueue = _boss_queue()
	var start_s: float = maxf(0.3, planner_ms / 1000.0)
	@warning_ignore("return_value_discarded")
	_plan_after(planner_ms, queue, func(q: AnimationQueue) -> void: _burst(q, 12, 7.0 / 12.0))

	# Act
	_run_until_idle(queue)

	# Assert
	var starts: Array[Dictionary] = _action_starts()
	assert_int(starts.size()).is_equal(12)
	assert_float(float(starts[1].at) - float(starts[0].at)).is_equal_approx(7.0 / 12.0 + 0.245, 2.0 * NEAR)
	assert_float(_now).is_equal_approx(start_s + 9.7, 3.0 * NEAR)
	assert_int(_skips).is_equal(0)


func test_a_plan_arriving_inside_the_beat_is_held_and_controls_stay_locked() -> void:
	# Arrange
	var view: MatchViewState = MatchViewState.new(MatchUiTestConfig.body())
	var queue: AnimationQueue = _boss_queue()
	var router: InputRouter = _router(queue, view)
	@warning_ignore("return_value_discarded")
	_plan_after(100, queue, func(q: AnimationQueue) -> void: _burst(q, 2, 0.2))

	# Act
	_run_to(queue, 0.2)

	# Assert
	assert_bool(queue.is_idle()).override_failure_message("the plan is not held in the queue").is_false()
	assert_array(_starts).is_empty()
	assert_bool(router.controls_locked()).is_true()


func test_plan_changed_still_opens_playback_after_a_thinking_wait() -> void:
	# Arrange: the label is the banner's; what the queue owes it is the commit step
	var view: MatchViewState = MatchViewState.new(MatchUiTestConfig.body())
	var queue: AnimationQueue = _boss_queue()
	@warning_ignore("return_value_discarded")
	_plan_after(800, queue, func(q: AnimationQueue) -> void:
		for step: AnimStep in view.apply({"seq": 150, "turn": 2, "type": "ai_intent_committed", "payload": {"kept": false, "intent_key": "attack_face", "effective_mode": "full"}, "cause_seq": 0}):
			q.enqueue(step)
		_next_seq = 200
		_groups(q, 1, 0.2))

	# Act
	_run_until_idle(queue)

	# Assert
	assert_that(_starts[0].kind).is_equal(AnimStep.INTENT_COMMIT)
	assert_float(float(_starts[0].at)).is_equal_approx(0.8, NEAR)
	assert_bool(bool(view.intent.kept)).is_false()
	assert_float(float(_action_starts()[0].at)).is_equal_approx(0.8, NEAR)


func test_a_turn_with_no_plan_clears_boss_thinking_and_does_not_hang() -> void:
	# Arrange: an empty plan logs `ai_fault` and ends the turn with no commit (DD-X31)
	var queue: AnimationQueue = _boss_queue()
	_run_to(queue, 0.7)
	var thinking: bool = queue.boss_thinking()

	# Act
	queue.exit_boss_turn()
	_next_seq = 300
	queue.enqueue(_step(AnimStep.DRAW, 0.2, 5000))
	_run_until_idle(queue, 2.0)

	# Assert
	assert_bool(thinking).is_true()
	assert_bool(queue.boss_thinking()).is_false()
	assert_bool(queue.is_idle()).is_true()
	assert_bool(queue.boss_turn_active()).is_false()


func test_skip_while_thinking_keeps_boss_thinking_until_the_plan_arrives() -> void:
	# Arrange
	var queue: AnimationQueue = _boss_queue()
	_run_to(queue, 0.6)

	# Act
	queue.skip_all()
	var after_skip: bool = queue.boss_thinking()
	_burst(queue, 1, 0.2)
	_run_until_idle(queue)

	# Assert
	assert_bool(after_skip).is_true()
	assert_bool(queue.boss_thinking()).is_false()
	assert_float(float(_action_starts()[0].at)).is_equal_approx(0.6 + DT, NEAR)


func test_the_cap_reads_the_data_not_a_literal() -> void:
	# Arrange
	var profiles: Dictionary = _profiles().duplicate(true)
	profiles.runtime.planner_target_ms = 400
	var queue: AnimationQueue = AnimationQueue.new(MatchUiTestConfig.body(), MatchUiTestConfig.settings())
	queue.enter_boss_turn(AnimationQueue.boss_pacing(MatchUiTestConfig.body(), profiles, {}))

	# Act
	_run_to(queue, 0.395)
	var before: bool = queue.boss_thinking()
	_run_to(queue, 0.41)

	# Assert
	assert_bool(before).is_false()
	assert_bool(queue.boss_thinking()).is_true()
