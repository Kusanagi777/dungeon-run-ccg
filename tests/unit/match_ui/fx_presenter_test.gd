## The particle layer (design/ux/keyword-and-effect-grammar.md "Particles"): the
## shipped table is complete, each kind picks its effect, effects spawn, and
## `reduce_motion` and skip-all are honoured.
extends GdUnitTestSuite

const SHIPPED_MATCH_UI: String = "res://assets/data/match_ui.json"


func _config() -> Dictionary:
	return (JSON.parse_string(FileAccess.get_file_as_string(SHIPPED_MATCH_UI)) as Dictionary).config


func _fx(reduce_motion: bool = false) -> FxPresenter:
	var ui := MatchUiContext.new(_config(), null)
	ui.reduce_motion = reduce_motion
	ui.locate = func(_id: int) -> Vector2: return Vector2(100, 100)
	var fx: FxPresenter = auto_free(FxPresenter.new())
	add_child(fx)
	fx.setup(ui)
	return fx


func _step(kind: StringName, ids: Array[int] = [7], data: Dictionary = {}) -> AnimStep:
	var step := AnimStep.new(kind, ids, 0.3, 1, 1)
	step.data = data
	return step


func test_every_mapped_effect_exists_and_every_texture_loads() -> void:
	var particles: Dictionary = _config().particles
	for kind: String in particles.steps:
		assert_bool((particles.effects as Dictionary).has(str(particles.steps[kind]))).override_failure_message(kind).is_true()
	for key: String in particles.textures:
		assert_bool(ResourceLoader.exists(str(particles.textures[key]))).override_failure_message(key).is_true()
	for effect: String in particles.effects:
		for emitter: Dictionary in particles.effects[effect]:
			assert_bool((particles.textures as Dictionary).has(str(emitter.texture))).override_failure_message(effect).is_true()


func test_each_kind_of_change_picks_its_own_effect() -> void:
	var fx: FxPresenter = _fx()
	assert_str(fx.effect_for(_step(AnimStep.DAMAGE_POP, [7], {"amount": 1}))).is_equal("hit")
	assert_str(fx.effect_for(_step(AnimStep.DAMAGE_POP, [7], {"amount": 6}))).is_equal("hit_heavy")
	assert_str(fx.effect_for(_step(AnimStep.STAT_RECOLOUR, [7], {"up": true}))).is_equal("buff")
	assert_str(fx.effect_for(_step(AnimStep.STAT_RECOLOUR, [7], {"up": false}))).is_equal("debuff")
	assert_str(fx.effect_for(_step(AnimStep.BADGE, [7], {"added": ["frozen"]}))).is_equal("status_frozen")
	assert_str(fx.effect_for(_step(AnimStep.BADGE, [7], {"added": ["windfury"]}))).is_equal("status")
	assert_str(fx.effect_for(_step(AnimStep.BADGE, [7], {"added": [], "removed": ["frozen"]}))).is_equal("")
	assert_str(fx.effect_for(_step(AnimStep.TRANSFORM))).is_equal("unmask")
	assert_str(fx.effect_for(_step(AnimStep.TURN_BANNER))).is_equal("")


func test_a_step_with_an_effect_spawns_it_on_its_entity() -> void:
	var fx: FxPresenter = _fx()
	fx.on_step_started(_step(AnimStep.TRANSFORM), 0.3)
	assert_int(fx.get_child_count()).is_greater(0)


func test_reduce_motion_plays_no_effect() -> void:
	var fx: FxPresenter = _fx(true)
	fx.on_step_started(_step(AnimStep.DAMAGE_POP, [7], {"amount": 3}), 0.3)
	assert_int(fx.get_child_count()).is_equal(0)


func test_skip_all_clears_every_live_effect() -> void:
	var fx: FxPresenter = _fx()
	fx.on_step_started(_step(AnimStep.DEATH_GROUP), 0.3)
	fx.on_skipped()
	await get_tree().process_frame
	assert_int(fx.get_child_count()).is_equal(0)


func test_an_id_that_is_not_on_the_table_gets_no_effect() -> void:
	var fx: FxPresenter = _fx()
	var nowhere: Vector2 = fx.ui.rect("viewport").get_center()
	fx.ui.locate = func(_id: int) -> Vector2: return nowhere
	fx.on_step_started(_step(AnimStep.STAT_RECOLOUR, [90], {"up": true}), 0.3)
	assert_int(fx.get_child_count()).is_equal(0)
