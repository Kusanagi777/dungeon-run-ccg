## The epic's timing suite (card-effects AC-42; ADR-0005 guardrail; story 016).
##
## Each budget is the median of [constant RUNS] timed runs after one warm-up: a miss of the
## median is a red test. The budgets are the CI runner's, so this lives with the other
## budget suites, outside `-a res://tests -i res://tests/performance`: a debug binary on a
## machine running parallel lanes is not the measurement the budget is about. Story 016
## names `tests/integration/`; the move is the one change from it.
extends GdUnitTestSuite

const BOOT_SCRIPT := preload("res://src/core/boot.gd")
const FIXTURE_ROOT: String = "res://tests/fixtures/data/card_effects_v1/"
const SHIPPED_ROOT: String = "res://assets/data/"
const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const SIDE_BOSS: String = MatchRecords.SIDE_BOSS
const RUNS: int = 20
const USEC_PER_MSEC: float = 1000.0
const RESOLVE_BUDGET_MS: float = 2.0
const VALIDATE_BUDGET_MS: float = 50.0
const FOLD_BUDGET_MS: float = 0.05
const FOLD_ENTRIES: int = 12
const FULL_BOARD: int = 7
const SPELL: String = "neutral_test_all_hit"
const BODY: String = "neutral_test_body"
const BODY_HEALTH: int = 1000
const CARD_KIND: String = "card"


class FakeCardDatabase:
	extends CardDatabase

	var records: Dictionary = {}

	func _init(by_id: Dictionary) -> void:
		records = by_id

	func has(id: String) -> bool:
		return records.has(id)

	func card(id: String) -> Variant:
		return records.get(id)


func _median_ms(samples: Array[int]) -> float:
	var sorted: Array[int] = samples.duplicate()
	sorted.sort()
	return float(sorted[sorted.size() / 2]) / USEC_PER_MSEC


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


## An engine at the player's Main, both boards full of [constant BODY].
func _full_boards() -> RulesEngine:
	var op: Dictionary = CardFactory.make_op("damage", {"amount": {"sum": [1, {"ref": "owner.board_size"}]}, "spell_damage": false})
	var db: FakeCardDatabase = FakeCardDatabase.new({
		SPELL: CardFactory.make_spell(SPELL, 0, [{"id": SPELL + ".0", "trigger": "cast", "targets": "all_characters", "ops": [op]}]),
		BODY: CardFactory.make_minion(BODY, 0, 0, BODY_HEALTH),
	})
	var engine: RulesEngine = RulesEngine.new(db, MatchFactory.make_rules_config(), EffectResolver.new(db, _effects_config()))
	engine.start(MatchFactory.make_started_config(TestRngService.new(), TestEventLog.new()))
	assert_bool(engine.submit(engine.legal_commands()[0]).accepted).is_true()
	for side: String in MatchRecords.SIDES:
		for index: int in FULL_BOARD:
			engine.run_action(func() -> void: engine.summon_minion(side, BODY, index))
	return engine


func test_ac42_a_sixteen_target_op_resolves_under_two_ms() -> void:
	# Arrange
	var engine: RulesEngine = _full_boards()
	var state: MatchState = engine.state()
	var samples: Array[int] = []
	for run: int in RUNS + 1:
		var hand: Array = state.players[SIDE_PLAYER].hand
		hand.clear()
		hand.append(MatchFactory.make_card_instance(MatchFactory.alloc_entity_id(state), SPELL, "hand"))
		state.players[SIDE_PLAYER].hero.damage_taken = 0
		state.players[SIDE_BOSS].hero.damage_taken = 0

		# Act
		var before: int = Time.get_ticks_usec()
		var accepted: bool = engine.submit(MatchRecords.play_card(SIDE_PLAYER, 0)).accepted
		var elapsed: int = Time.get_ticks_usec() - before
		assert_bool(accepted).is_true()
		if run > 0:
			samples.append(elapsed)

	# Assert
	var median: float = _median_ms(samples)
	assert_float(median).override_failure_message("median %.3f ms" % median).is_less(RESOLVE_BUDGET_MS)
	engine.end_match()


func test_ac42_validate_effects_over_the_v1_fixture_is_under_fifty_ms() -> void:
	# Arrange
	var db: CardDatabase = CardDatabase.new(DataLoader.new(FIXTURE_ROOT))
	db.load(ValidatorStubs.accept_all())
	var caps: Dictionary = db.config("card_effects")
	var hosts: Array = []
	for set_id: String in ["war", "decay", "knowledge", "neutral", "boss"]:
		hosts.append_array(db.cards_by_set(set_id))
	assert_array(hosts).is_not_empty()
	var samples: Array[int] = []

	# Act
	for run: int in RUNS + 1:
		var before: int = Time.get_ticks_usec()
		for host: Dictionary in hosts:
			@warning_ignore("return_value_discarded")
			EffectValidator.validate_effects(&"card", str(host.id), host.get("effects", []), db, caps)
		if run > 0:
			samples.append(Time.get_ticks_usec() - before)

	# Assert
	var median: float = _median_ms(samples)
	assert_float(median).override_failure_message("median %.3f ms" % median).is_less(VALIDATE_BUDGET_MS)


func test_ac42_a_twelve_entry_value_fold_is_under_a_twentieth_of_a_ms() -> void:
	# Arrange
	var effects: Array = [{"trigger": "modify_cost", "scope": {"card": {"side": "friendly"}}, "ops": [{"op": "modify_value", "delta": 1}]}]
	var installers: Array[HookInstaller] = []
	for index: int in FOLD_ENTRIES:
		installers.append(HookInstaller.new(&"treasure", "treasure_fold_%d" % index, &"player", effects))
	var db: FakeCardDatabase = FakeCardDatabase.new({BODY: CardFactory.make_minion(BODY, 1, 1, 1)})
	var engine: RulesEngine = RulesEngine.new(db, MatchFactory.make_rules_config(), EffectResolver.new(db, _effects_config()))
	var config: Dictionary = MatchFactory.make_started_config(TestRngService.new(), TestEventLog.new(), {"player": {"hook_installers": installers}})
	engine.start(config)
	assert_int(engine.state().hooks.entry_count()).is_equal(FOLD_ENTRIES)
	assert_bool(engine.submit(engine.legal_commands()[0]).accepted).is_true()
	var card: Dictionary = MatchFactory.make_card_instance(MatchFactory.alloc_entity_id(engine.state()), BODY, "hand")
	(engine.state().players[SIDE_PLAYER].hand as Array).append(card)
	var samples: Array[int] = []

	# Act
	var cost: int = 0
	for run: int in RUNS + 1:
		var before: int = Time.get_ticks_usec()
		cost = engine.effective_cost(card, SIDE_PLAYER)
		if run > 0:
			samples.append(Time.get_ticks_usec() - before)

	# Assert — the fold really ran over all twelve
	assert_int(cost).is_equal(1 + FOLD_ENTRIES)
	var median: float = _median_ms(samples)
	assert_float(median).override_failure_message("median %.3f ms" % median).is_less(FOLD_BUDGET_MS)
	engine.end_match()
