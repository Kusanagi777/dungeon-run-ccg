## Impact Moments and the U11 pause on the queue's clock (match-ui Game Feel; story 023
## AC-1, AC-2; story 022 pause). The projection marks a step, the queue decides what plays:
## `live_impact` is the only thing a presenter reads, so a step that is held longer must
## say so there. All on a fake clock.
extends GdUnitTestSuite

const ATTACKER: int = 31
const DEFENDER: int = 51
const PLAYER_HERO: int = 1
const BOSS_HERO: int = 2
const HEAVY_DAMAGE: int = 5
const LIGHT_DAMAGE: int = 4
const FRAME_S: float = 1.0 / 60.0
const MS_PER_S: float = 1000.0
const EPSILON_S: float = 0.0001


func _body() -> Dictionary:
	return MatchUiTestConfig.body()


func _view() -> MatchViewState:
	var view := MatchViewState.new(_body())
	view.apply(_event(1, "match_started", {"hero_id": PLAYER_HERO, "boss_id": BOSS_HERO, "starting_health": {"player": 30, "boss": 30}}))
	return view


func _queue(settings: Dictionary = {}) -> AnimationQueue:
	return AnimationQueue.new(_body(), MatchUiTestConfig.settings(settings))


func _event(seq: int, type: String, payload: Dictionary, cause: int = 0) -> Dictionary:
	return {"seq": seq, "turn": 1, "type": type, "payload": payload, "cause_seq": cause}


func _hit(view: MatchViewState, target: int, dealt: int, health_after: int) -> Array[AnimStep]:
	var steps: Array[AnimStep] = view.apply(_event(10, "attack_declared", {"attacker": ATTACKER, "defender": target}))
	steps.append_array(view.apply(_event(11, "damage_dealt", {"target": target, "source": ATTACKER, "dealt": dealt, "prevented": 0, "health_after": health_after}, 10)))
	return steps


func _of_kind(steps: Array[AnimStep], kind: StringName) -> AnimStep:
	for step: AnimStep in steps:
		if step.kind == kind:
			return step
	return null


func _play_seconds(queue: AnimationQueue, step: AnimStep) -> float:
	queue.enqueue(step)
	var elapsed: float = 0.0
	queue.advance(0.0)
	while not queue.is_idle():
		queue.advance(FRAME_S)
		elapsed += FRAME_S
	return elapsed


func test_an_attack_on_a_minion_holds_60_ms_on_contact() -> void:
	# Arrange / Act
	var lunge: AnimStep = _of_kind(_hit(_view(), DEFENDER, 2, 1), AnimStep.ATTACK_LUNGE)

	# Assert
	assert_int(int(lunge.impact.hit_stop_ms)).is_equal(int(_body().impact_ms.hit_stop))


func test_heavy_hero_damage_holds_90_ms_and_shakes_for_120() -> void:
	# Arrange / Act
	var steps: Array[AnimStep] = _hit(_view(), BOSS_HERO, HEAVY_DAMAGE, 25)

	# Assert
	assert_int(int(_of_kind(steps, AnimStep.ATTACK_LUNGE).impact.hit_stop_ms)).is_equal(int(_body().impact_ms.hit_stop_heavy))
	assert_int(int(_of_kind(steps, AnimStep.DAMAGE_POP).impact.shake_ms)).is_equal(int(_body().impact_ms.shake))
	assert_bool(_of_kind(steps, AnimStep.DAMAGE_POP).impact.has("slow_ms")).is_false()


func test_hero_damage_under_the_threshold_neither_shakes_nor_holds_heavy() -> void:
	# Arrange / Act
	var steps: Array[AnimStep] = _hit(_view(), BOSS_HERO, LIGHT_DAMAGE, 26)

	# Assert
	assert_int(int(_of_kind(steps, AnimStep.ATTACK_LUNGE).impact.hit_stop_ms)).is_equal(int(_body().impact_ms.hit_stop))
	assert_dict(_of_kind(steps, AnimStep.DAMAGE_POP).impact).is_empty()


func test_heavy_damage_to_a_minion_is_not_heavy() -> void:
	# Arrange / Act: the threshold is hero damage
	var steps: Array[AnimStep] = _hit(_view(), DEFENDER, HEAVY_DAMAGE + 3, 0)

	# Assert
	assert_int(int(_of_kind(steps, AnimStep.ATTACK_LUNGE).impact.hit_stop_ms)).is_equal(int(_body().impact_ms.hit_stop))
	assert_dict(_of_kind(steps, AnimStep.DAMAGE_POP).impact).is_empty()


func test_a_lethal_hit_shakes_and_slows_whatever_its_size() -> void:
	# Arrange / Act
	var pop: AnimStep = _of_kind(_hit(_view(), BOSS_HERO, 1, 0), AnimStep.DAMAGE_POP)

	# Assert
	assert_int(int(pop.impact.shake_ms)).is_equal(int(_body().impact_ms.shake))
	assert_int(int(pop.impact.slow_ms)).is_equal(int(_body().impact_ms.slow))


func test_live_impact_carries_the_extras_at_normal() -> void:
	# Arrange
	var queue: AnimationQueue = _queue()
	var pop: AnimStep = _of_kind(_hit(_view(), BOSS_HERO, 1, 0), AnimStep.DAMAGE_POP)

	# Act
	queue.enqueue(pop)
	queue.advance(0.0)

	# Assert
	assert_float(float(pop.live_impact.slow_ms)).is_equal(float(_body().impact_ms.slow))
	assert_float(float(pop.live_impact.shake_ms)).is_equal(float(_body().impact_ms.shake))


func test_live_impact_is_zero_under_reduce_motion_at_normal() -> void:
	# Arrange
	var queue: AnimationQueue = _queue({"reduce_motion": true})
	var pop: AnimStep = _of_kind(_hit(_view(), BOSS_HERO, 1, 0), AnimStep.DAMAGE_POP)

	# Act
	queue.enqueue(pop)
	queue.advance(0.0)

	# Assert
	assert_dict(pop.live_impact).is_equal({"hit_stop_ms": 0.0, "shake_ms": 0.0, "slow_ms": 0.0})


func test_live_impact_is_zero_at_fast() -> void:
	# Arrange
	var queue: AnimationQueue = _queue({"anim_speed": "fast"})
	var pop: AnimStep = _of_kind(_hit(_view(), BOSS_HERO, 1, 0), AnimStep.DAMAGE_POP)

	# Act
	queue.enqueue(pop)
	queue.advance(0.0)

	# Assert
	assert_float(float(pop.live_impact.slow_ms)).is_equal(0.0)


func test_a_lethal_pop_holds_its_duration_plus_the_slow_down() -> void:
	# Arrange
	var pop: AnimStep = _of_kind(_hit(_view(), BOSS_HERO, 1, 0), AnimStep.DAMAGE_POP)
	var want: float = float(_body().d_base.damage_pop) + float(_body().impact_ms.slow) / MS_PER_S

	# Act
	var took: float = _play_seconds(_queue(), pop)

	# Assert
	assert_float(took).is_between(want - EPSILON_S, want + FRAME_S + EPSILON_S)


func test_reduce_motion_keeps_a_steps_base_duration_and_drops_the_hold() -> void:
	# Arrange
	var pop: AnimStep = _of_kind(_hit(_view(), BOSS_HERO, 1, 0), AnimStep.DAMAGE_POP)
	var want: float = float(_body().d_base.damage_pop)

	# Act
	var took: float = _play_seconds(_queue({"reduce_motion": true}), pop)

	# Assert: positional travel keeps `d_base`; only the extras go
	assert_float(took).is_between(want - EPSILON_S, want + FRAME_S + EPSILON_S)


func test_a_lunge_holds_its_duration_plus_the_hit_stop() -> void:
	# Arrange
	var lunge: AnimStep = _of_kind(_hit(_view(), DEFENDER, 2, 1), AnimStep.ATTACK_LUNGE)
	var want: float = float(_body().d_base.attack_lunge) + float(_body().impact_ms.hit_stop) / MS_PER_S

	# Act
	var took: float = _play_seconds(_queue(), lunge)

	# Assert
	assert_float(took).is_between(want - EPSILON_S, want + FRAME_S + EPSILON_S)


# --- U11 pause ---------------------------------------------------------------------

func _spaced_steps() -> Array[AnimStep]:
	var out: Array[AnimStep] = []
	for seq: int in [5, 6, 7]:
		out.append(AnimStep.new(AnimStep.TURN_BANNER, [], 0.4, seq, seq))
	return out


func test_pause_at_freezes_partway_through_that_steps_own_seq() -> void:
	# Arrange
	var queue: AnimationQueue = _queue()
	var fired: Array[int] = []
	var started: Array[int] = []
	queue.paused.connect(func() -> void: fired.append(1))
	queue.step_started.connect(func(step: AnimStep, _d: float) -> void: started.append(step.seq))
	queue.set_pause_at(6)
	for step: AnimStep in _spaced_steps():
		queue.enqueue(step)

	# Act
	for i: int in 300:
		queue.advance(FRAME_S)

	# Assert: 6 is on screen and held; 7 never starts
	assert_bool(queue.is_paused()).is_true()
	assert_int(fired.size()).is_equal(1)
	assert_array(started).is_equal([5, 6])
	assert_bool(queue.is_idle()).is_false()


func test_pause_at_a_seq_with_no_step_freezes_at_the_next_step() -> void:
	# Arrange
	var queue: AnimationQueue = _queue()
	var started: Array[int] = []
	queue.step_started.connect(func(step: AnimStep, _d: float) -> void: started.append(step.seq))
	queue.set_pause_at(4)
	for step: AnimStep in _spaced_steps():
		queue.enqueue(step)

	# Act
	for i: int in 300:
		queue.advance(FRAME_S)

	# Assert
	assert_bool(queue.is_paused()).is_true()
	assert_array(started).is_empty()


func test_skip_all_lifts_the_pause_and_runs_every_final() -> void:
	# Arrange
	var queue: AnimationQueue = _queue()
	var steps: Array[AnimStep] = _spaced_steps()
	var finals: Array[int] = []
	queue.step_finished.connect(func(step: AnimStep) -> void: finals.append(step.seq))
	queue.set_pause_at(6)
	for step: AnimStep in steps:
		queue.enqueue(step)
	for i: int in 300:
		queue.advance(FRAME_S)

	# Act
	queue.skip_all()

	# Assert
	assert_bool(queue.is_paused()).is_false()
	assert_bool(queue.is_idle()).is_true()
	assert_array(finals).is_equal([5, 6, 7])


func test_a_paused_queue_ignores_the_clock() -> void:
	# Arrange
	var queue: AnimationQueue = _queue()
	var finals: Array[int] = []
	queue.step_finished.connect(func(step: AnimStep) -> void: finals.append(step.seq))
	queue.set_pause_at(5)
	for step: AnimStep in _spaced_steps():
		queue.enqueue(step)
	for i: int in 60:
		queue.advance(FRAME_S)
	var frozen: int = finals.size()

	# Act
	queue.advance(100.0)

	# Assert
	assert_int(finals.size()).is_equal(frozen)
	assert_bool(queue.is_paused()).is_true()
