## Impact moments on the table (match-ui Game Feel; story 023 AC-2). The durations are asserted
## in `animation_queue_impact_test`; this suite is what the presenters do with `live_impact`.
## How it feels stays for the lead's sign-off: coding-standards leaves feel unautomated.
extends GdUnitTestSuite

const FRAME_S: float = 1.0 / 60.0
const SHAKE_PX: float = 3.0
const DAMAGE: int = 8


func _hit_boss(view: MatchView, health_after: int) -> AnimStep:
	var boss: int = int(view.view_state().side(&"boss").hero.entity_id)
	var pops: Array[AnimStep] = []
	var listener: Callable = func(step: AnimStep, _d: float) -> void:
		if step.kind == AnimStep.DAMAGE_POP:
			pops.append(step)
	view.queue().step_started.connect(listener)
	MatchViewHarness.inject(view, "damage_dealt", {"target": boss, "source": 1, "dealt": DAMAGE, "prevented": 0, "health_after": health_after})
	MatchViewHarness.run(view, FRAME_S)
	view.queue().step_started.disconnect(listener)
	return pops[0]


func _impact(view: MatchView) -> ImpactPresenter:
	return view.find_child("Impact", true, false)


func _step_shake(view: MatchView, step: AnimStep, seconds: float) -> void:
	for tween: Tween in (_impact(view).get("_step_tweens") as Dictionary).get(step, []):
		tween.custom_step(seconds)


func test_heavy_hero_damage_shakes_the_table_within_3_px_and_it_settles() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player", [], {"anim_speed": "normal"})
	var step: AnimStep = _hit_boss(view, 22)

	# Act: an early swing of the 120 ms shake
	_step_shake(view, step, 0.015)
	var swing: Vector2 = view.offset_transform_position
	MatchViewHarness.settle(view)

	# Assert
	assert_float(swing.length()).is_between(0.01, SHAKE_PX)
	assert_object(view.offset_transform_position).is_equal(Vector2.ZERO)
	assert_array(MatchViewHarness.sync_lines(view)).is_empty()
	MatchViewHarness.close(view)


func test_a_skip_mid_shake_rests_the_table() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player", [], {"anim_speed": "normal"})
	var step: AnimStep = _hit_boss(view, 22)
	_step_shake(view, step, 0.015)

	# Act
	view.queue().skip_all()

	# Assert
	assert_object(view.offset_transform_position).is_equal(Vector2.ZERO)
	MatchViewHarness.close(view)


func test_reduce_motion_never_shakes() -> void:
	# Arrange / Act
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player", [], {"anim_speed": "normal", "reduce_motion": true})
	var step: AnimStep = _hit_boss(view, 22)

	# Assert
	assert_bool((_impact(view).get("_step_tweens") as Dictionary).has(step)).is_false()
	assert_object(view.offset_transform_position).is_equal(Vector2.ZERO)
	view.queue().skip_all()
	MatchViewHarness.close(view)


func test_fast_never_shakes() -> void:
	# Arrange / Act
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player", [], {"anim_speed": "fast"})
	var step: AnimStep = _hit_boss(view, 22)

	# Assert
	assert_bool((_impact(view).get("_step_tweens") as Dictionary).has(step)).is_false()
	view.queue().skip_all()
	MatchViewHarness.close(view)


func test_a_lethal_pop_holds_on_screen_for_the_slow_down_too() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player", [], {"anim_speed": "normal"})
	var step: AnimStep = _hit_boss(view, 0)
	var panel: HeroPresenter = view.find_child("BossPanel", true, false)
	var pop: NumberPop = view.find_children("*", "NumberPop", true, false)[0]
	var start: Vector2 = pop.position
	var d_base: float = float(view.ui_context().config.d_base.damage_pop)
	var slow_s: float = float(step.live_impact.slow_ms) / 1000.0
	var tween: Tween = ((panel.get("_step_tweens") as Dictionary)[step] as Array)[0]

	# Act: at the end of the base duration the pop has not finished rising
	tween.custom_step(d_base)
	var at_base: Vector2 = pop.position
	tween.custom_step(slow_s)

	# Assert
	assert_float(start.y - at_base.y).is_less(start.y - pop.position.y)
	view.queue().skip_all()
	MatchViewHarness.close(view)


func test_under_reduce_motion_a_pop_fades_in_place() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player", [], {"anim_speed": "normal", "reduce_motion": true})
	var step: AnimStep = _hit_boss(view, 22)
	var panel: HeroPresenter = view.find_child("BossPanel", true, false)
	var pop: NumberPop = view.find_children("*", "NumberPop", true, false)[0]
	var start: Vector2 = pop.position
	var tween: Tween = ((panel.get("_step_tweens") as Dictionary)[step] as Array)[0]

	# Act
	tween.custom_step(0.2)

	# Assert
	assert_object(pop.position).is_equal(start)
	assert_float(pop.modulate.a).is_less(1.0)
	view.queue().skip_all()
	MatchViewHarness.close(view)


func test_under_reduce_motion_the_lethal_banner_does_not_pulse() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player", [], {"anim_speed": "normal", "reduce_motion": true})
	var banner: IntentBanner = view.find_child("IntentBanner", true, false)
	var scale_seen: Array[Vector2] = []
	var plate: Control = banner.get("_plate")

	# Act
	MatchViewHarness.inject(view, "ai_intent_shown", {"boss_id": "boss_torchbearer", "intent_key": "lethal", "target_id": null, "amount": 9, "effective_mode": "full"})
	for i: int in 12:
		MatchViewHarness.run(view, FRAME_S)
		await view.get_tree().process_frame
		scale_seen.append(plate.scale)

	# Assert
	for scale: Vector2 in scale_seen:
		assert_object(scale).is_equal(Vector2.ONE)
	MatchViewHarness.close(view)


func test_reduce_motion_keeps_a_lunge_travelling_with_its_base_duration() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "targeting_taunt", [], {"anim_speed": "normal", "reduce_motion": true})
	await MatchViewHarness.frames(view, 2)
	var durations: Dictionary = {}
	view.queue().step_started.connect(func(step: AnimStep, d: float) -> void: durations[step.kind] = d)
	var attacker: int = int(view.view_state().side(&"player").board[0].entity_id)
	var defender: int = int(view.view_state().side(&"boss").board[2].entity_id)

	# Act
	MatchViewHarness.inject(view, "attack_declared", {"attacker": attacker, "defender": defender})
	MatchViewHarness.run(view, FRAME_S)

	# Assert: `d_base` unchanged, the travel still runs
	assert_float(float(durations[AnimStep.ATTACK_LUNGE])).is_equal(float(view.ui_context().config.d_base.attack_lunge))
	var row: BoardPresenter = view.find_child("PlayerRow", true, false)
	assert_int(((row.get("_step_tweens") as Dictionary).values() as Array).size()).is_equal(1)
	view.queue().skip_all()
	MatchViewHarness.close(view)


func test_the_hit_stop_lengthens_the_lunge_hold_by_its_milliseconds() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player", [], {"anim_speed": "normal"})
	var row: BoardPresenter = view.find_child("PlayerRow", true, false)
	var step := AnimStep.new(AnimStep.ATTACK_LUNGE, [], 0.35, 1, 1)
	var plain: float = row.lunge_hold_s(step, 0.35)

	# Act
	step.live_impact = {"hit_stop_ms": 60.0}

	# Assert
	assert_float(row.lunge_hold_s(step, 0.35) - plain).is_equal_approx(0.06, 0.0001)
	MatchViewHarness.close(view)
