## The engine↔resolver `RefCounted` cycle breaks at teardown (story
## card-effects/story-002 AC-2 second half; ADR-0007 Decision 2 and its
## Verification Required row — `NOT SOURCEABLE — RefCounted cycle collection`
## is settled here by observation, not by documentation).
##
## ADR-0007 names this test `tests/unit/effects/effect_resolver_teardown_test.gd`;
## the epic's test root is `tests/unit/card_effects/` (tests/README.md), so it
## lives here. The control test proves the weakref check can fail: without
## `unbind()` the cycle keeps the engine alive.
extends GdUnitTestSuite


func _effects_config() -> Dictionary:
	return {
		"discover_count": float(TestConstants.DISCOVER_COUNT),
		"discover_exclude_hand": false,
		"max_ops_per_effect": float(TestConstants.MAX_OPS_PER_EFFECT),
		"max_repeat": float(TestConstants.MAX_REPEAT),
		"max_summon_count": float(TestConstants.BOARD_SIZE),
		"effect_static_step_limit": float(TestConstants.EFFECT_STATIC_STEP_LIMIT),
		"spell_damage_default": "auto",
		"hooks_before_triggers": true,
	}


## A started engine with a treasure and a boss passive installed, so the
## registry holds the resolver's bound-method evaluators too.
func _started_engine(resolver: EffectResolver) -> RulesEngine:
	var config: Dictionary = MatchFactory.make_started_config(TestRngService.new(), TestEventLog.new(), {
		"player": {"hook_installers": [MatchFactory.make_hook_installer("treasure_signet", MatchFactory.SIDE_PLAYER, ["on_turn_start"])]},
		"boss": {"hook_installers": [MatchFactory.make_hook_installer("boss_test_passive", MatchFactory.SIDE_BOSS, ["modify_cost"])]},
	})
	var engine: RulesEngine = RulesEngine.new(null, MatchFactory.make_rules_config(), resolver)
	engine.start(config)
	return engine


func test_end_match_then_dropping_references_frees_the_engine() -> void:
	# Arrange
	var resolver: EffectResolver = EffectResolver.new(CardDatabase.new(), _effects_config())
	var engine: RulesEngine = _started_engine(resolver)
	var watch: WeakRef = weakref(engine)
	var resolver_watch: WeakRef = weakref(resolver)

	# Act — teardown entry, then the test lets go of both
	engine.end_match()
	engine = null
	resolver = null

	# Assert — nothing else held the engine or the resolver
	assert_bool(watch.get_ref() == null).is_true()
	assert_bool(resolver_watch.get_ref() == null).is_true()


func test_an_ended_match_unbinds_itself_and_frees_on_release() -> void:
	# Arrange — concede ends the match (C14): the engine unbinds at Ended
	var resolver: EffectResolver = EffectResolver.new(CardDatabase.new(), _effects_config())
	var engine: RulesEngine = _started_engine(resolver)
	var watch: WeakRef = weakref(engine)
	var result: Dictionary = engine.submit(MatchRecords.concede())
	assert_bool(result.accepted).is_true()
	assert_object(resolver.bound_engine()).is_null()

	# Act
	engine = null
	resolver = null

	# Assert
	assert_bool(watch.get_ref() == null).is_true()


func test_without_unbind_the_cycle_keeps_the_engine_alive() -> void:
	# Arrange — control: the weakref check above is able to fail
	var resolver: EffectResolver = EffectResolver.new(CardDatabase.new(), _effects_config())
	var engine: RulesEngine = _started_engine(resolver)
	var watch: WeakRef = weakref(engine)

	# Act — release the engine without the teardown call
	engine = null

	# Assert — the resolver's engine reference kept it alive; then break it.
	# A bool, not assert_object(get_ref()): gdUnit's assert keeps its value,
	# which would itself hold the engine.
	assert_bool(watch.get_ref() != null).is_true()
	resolver.unbind()
	resolver = null
	assert_bool(watch.get_ref() == null).is_true()
