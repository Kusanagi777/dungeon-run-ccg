## Unit tests for DEFENSIVE mode, the F6 threat estimate and sandbox hook fidelity
## (story boss-ai-match-driver/story-009; design/gdd/boss-ai.md C2, F6, States
## "Modes", Edge Cases "Lethal and defence", A15, A20; ADR-0006; TR-boss-ai-001).
##
## Every board runs on the production `EffectResolver` ([BossAiBoard]). A20's hook is
## a real `boss.hook_installers` entry, folded in the sandbox by the production
## `apply_value_hook` (card-effects story 014): through `HookRegistry.copy()`, the
## clone's own resolver and the engine's `apply_heal`.
extends GdUnitTestSuite

const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const SIDE_BOSS: String = MatchRecords.SIDE_BOSS
const AI_SEED: int = 7
const PASSIVE_HOST: String = "boss_passive_mend"
## A multiplier no other weight can answer: the choice must follow it.
const OVERWHELMING: float = 100.0


## A [Scorer] that remembers each `score_all` profile and mode.
class SpyScorer:
	extends Scorer

	var profiles: Array[Dictionary] = []
	var modes: Array[StringName] = []

	func score_all(sandbox: RulesEngine, candidates: Array, profile: Dictionary, mode: StringName, context: Dictionary, planner: PlannerTask) -> Array:
		profiles.append(profile)
		modes.append(mode)
		return await super(sandbox, candidates, profile, mode, context, planner)


# --- helpers -----------------------------------------------------------------

func _fixture() -> Dictionary:
	return BossAiBoard.read("f6_defensive_board")


## [param fixture] laid out, with its `boss.health` and `player.turns_taken`.
func _board(fixture: Dictionary, keyword_values: Dictionary = {}) -> Dictionary:
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = BossAiBoard.engine(fixture, db, [], log)
	var state: MatchState = engine.state()
	var hero: Dictionary = state.players[SIDE_BOSS].hero
	hero.damage_taken = engine.max_health(hero) - int(fixture.boss.health)
	state.players[SIDE_PLAYER].turns_taken = int(fixture.player.get("turns_taken", 0))
	var stub: Dictionary = BossAiBoard.stub_config()
	var keywords: Dictionary = stub.keyword_values if keyword_values.is_empty() else keyword_values
	var profile: Dictionary = BossAiBoard.profile(fixture)
	var ai: BossAI = BossAI.new(CardFactory.make_boss_def("boss_test", int(fixture.band)), profile, int(fixture.band), TestRngStream.seeded("ai_1", AI_SEED), stub.op_values, log, db, keywords)
	return {"fixture": fixture, "db": db, "engine": engine, "profile": profile, "ai": ai}


func _plan(board: Dictionary) -> TurnPlan:
	var sandbox: RulesEngine = (board.engine as RulesEngine).clone()
	var plan: TurnPlan = await (board.ai as BossAI).plan_turn(sandbox)
	sandbox.end_match()
	return plan


func _decisions(plan: TurnPlan) -> Array:
	return plan.diagnostics.filter(func(d: Dictionary) -> bool: return str(d[TurnPlan.EVENT_KEY]) == BossAI.EVENT_DECISION)


func _hand_card(board: Dictionary, index: int) -> String:
	return str((board.engine as RulesEngine).state().players[SIDE_BOSS].hand[index].def_id)


## The board of A20 on the production resolver, the boss's passive in
## `boss.hook_installers` when [param with_passive].
func _heal_board(with_passive: bool) -> Dictionary:
	var fixture: Dictionary = BossAiBoard.read("heal_doubling_passive")
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var deck: Array = []
	for _i: int in BossAiBoard.DECK_SIZE:
		deck.append(str(fixture.deck_card))
	var installers: Array[HookInstaller] = []
	if with_passive:
		var effects: Array[Dictionary] = [{
			"id": "%s.0" % PASSIVE_HOST, "trigger": str(fixture.passive.point), "scope": fixture.passive.scope, "condition": {},
			"ops": [{"op": "modify_value", "mul": int(fixture.passive.mul)}], "once_per_turn": false,
		}]
		installers.append(HookInstaller.new(HookInstaller.HOST_KIND_PASSIVE, PASSIVE_HOST, StringName(SIDE_BOSS), effects))
	var config: Dictionary = MatchFactory.make_started_config(TestRngService.new(BossAiBoard.SETUP_SEED), TestEventLog.new(), {"player": {"deck": deck}, "boss": {"deck": deck.duplicate(), "hook_installers": installers}})
	var engine: RulesEngine = RulesEngine.new(db, MatchFactory.make_rules_config(), EffectResolver.new(db, BossAiBoard.effects_config(), ""))
	engine.start(config)
	assert_bool(engine.submit(engine.legal_commands()[0]).accepted).is_true()
	assert_bool(engine.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()
	BossAiBoard._lay_out(engine, fixture, db)
	engine.state().players[SIDE_BOSS].hero.damage_taken = int(fixture.boss.missing_health)
	return {"fixture": fixture, "db": db, "engine": engine}


func _f_heal(board: Dictionary) -> float:
	var engine: RulesEngine = board.engine
	var leech: int = BossAiBoard.ids_of(engine, SIDE_BOSS, "bai_leech")[0]
	var dummy: int = BossAiBoard.ids_of(engine, SIDE_PLAYER, "bai_dummy")[0]
	var sandbox: RulesEngine = engine.clone()
	var stub: Dictionary = BossAiBoard.stub_config()
	var scorer: Scorer = Scorer.new(board.db, stub.keyword_values, stub.op_values)
	var entry: Dictionary = scorer.score(MatchRecords.attack(SIDE_BOSS, leech, dummy), sandbox, BossAiBoard.profile(board.fixture), Scorer.MODE_NORMAL, {})
	sandbox.end_match()
	return float(entry.features.f_heal)


# --- F6: the threat estimate --------------------------------------------------

func test_f6_the_example_board_has_incoming_16() -> void:
	# Arrange
	var board: Dictionary = _board(_fixture())

	# Act
	var incoming: float = ThreatEstimate.incoming(board.engine, board.profile.rules, SIDE_BOSS)

	# Assert
	assert_float(incoming).is_equal(float(board.fixture.expect.incoming))


func test_f6_incoming_equal_to_the_line_is_defensive_and_one_below_is_not() -> void:
	# Arrange — 16 against health − 3: 19 is the equal case, 20 the one below
	var at_line: Dictionary = _fixture()
	at_line.boss.health = 19
	var above_line: Dictionary = _fixture()
	above_line.boss.health = 20

	# Act
	var equal: Dictionary = _board(at_line)
	var below: Dictionary = _board(above_line)

	# Assert
	assert_bool(ThreatEstimate.defensive(equal.engine, equal.profile.rules, SIDE_BOSS)).is_true()
	assert_bool(ThreatEstimate.defensive(below.engine, below.profile.rules, SIDE_BOSS)).is_false()


func test_f6_armor_counts_towards_the_line() -> void:
	# Arrange
	var board: Dictionary = _board(_fixture())
	(board.engine as RulesEngine).state().players[SIDE_BOSS].hero.armor = 2

	# Act
	var defensive: bool = ThreatEstimate.defensive(board.engine, board.profile.rules, SIDE_BOSS)

	# Assert — 16 against 18 + 2 − 3
	assert_bool(defensive).is_false()


func test_f6_burn_per_mana_is_read_from_the_rules_and_keeps_its_fraction() -> void:
	# Arrange
	var board: Dictionary = _board(_fixture())
	var rules: Dictionary = (board.profile.rules as Dictionary).duplicate()
	rules.burn_per_mana = 0.5

	# Act
	var incoming: float = ThreatEstimate.incoming(board.engine, rules, SIDE_BOSS)

	# Assert — 4 + 6 + 0.5 · 6; and 7 mana would be 13.5, with no rounding
	assert_float(incoming).is_equal(13.0)
	(board.engine as RulesEngine).state().players[SIDE_PLAYER].turns_taken = 6
	assert_float(ThreatEstimate.incoming(board.engine, rules, SIDE_BOSS)).is_equal(13.5)


func test_f6_frozen_and_summoning_sick_player_minions_count() -> void:
	# Arrange
	var board: Dictionary = _board(_fixture())
	var engine: RulesEngine = board.engine
	engine.freeze(BossAiBoard.ids_of(engine, SIDE_PLAYER, "bai_ogre")[0])
	engine.state().players[SIDE_PLAYER].board[1].summoning_sick = true

	# Act
	var incoming: float = ThreatEstimate.incoming(engine, board.profile.rules, SIDE_BOSS)

	# Assert
	assert_float(incoming).is_equal(float(board.fixture.expect.incoming))


func test_f6_the_player_weapon_counts() -> void:
	# Arrange
	var board: Dictionary = _board(_fixture())
	var engine: RulesEngine = board.engine
	engine.state().players[SIDE_PLAYER].weapon = MatchRecords.weapon(MatchFactory.alloc_entity_id(engine.state()), "bai_filler", 3, 2)

	# Act
	var incoming: float = ThreatEstimate.incoming(engine, board.profile.rules, SIDE_BOSS)

	# Assert
	assert_float(incoming).is_equal(float(board.fixture.expect.incoming) + 3.0)


# --- A15 ----------------------------------------------------------------------

func test_a15_band_three_logs_defensive_in_the_decision_and_the_trace() -> void:
	# Arrange
	var board: Dictionary = _board(_fixture())

	# Act
	var plan: TurnPlan = await _plan(board)

	# Assert
	assert_str(str(_decisions(plan)[0].mode)).is_equal(String(Scorer.MODE_DEFENSIVE))
	assert_bool(plan.mode_trace.has(Scorer.MODE_DEFENSIVE)).is_true()
	assert_dict(_decisions(plan)[0].mode_transition).is_equal({"from": String(Scorer.MODE_NORMAL), "to": String(Scorer.MODE_DEFENSIVE)})


func test_a15_the_taunt_is_played_before_a_non_taunt_of_equal_stats() -> void:
	# Arrange — `taunt` multiplies by 1 here, so only DEFENSIVE's +0.5 BV tells them
	# apart; the non-Taunt is first in hand, so a plain tie could not pick the Taunt
	# by order, and tie_epsilon is below the bonus's score
	var board: Dictionary = _board(_fixture(), {"taunt": 1.0})
	assert_str(_hand_card(board, 0)).is_equal("bai_brute")

	# Act
	var decision: Dictionary = _decisions(await _plan(board))[0]

	# Assert
	assert_int(int(decision.chosen.hand_index)).is_equal(1)
	assert_int(int(decision.get("tie_set_size"))).is_equal(1)


func test_a15_band_two_stays_normal_on_the_same_board() -> void:
	# Arrange
	var fixture: Dictionary = _fixture()
	fixture.band = 2
	var board: Dictionary = _board(fixture)

	# Act
	var plan: TurnPlan = await _plan(board)

	# Assert
	assert_bool(plan.mode_trace.has(Scorer.MODE_DEFENSIVE)).is_false()
	for decision: Dictionary in _decisions(plan):
		assert_str(str(decision.mode)).is_equal(String(Scorer.MODE_NORMAL))


func test_defensive_scores_with_the_multiplied_weights_and_leaves_the_profile_alone() -> void:
	# Arrange
	var board: Dictionary = _board(_fixture())
	var ai: BossAI = board.ai
	var spy: SpyScorer = SpyScorer.new(board.db, BossAiBoard.keyword_values(), BossAiBoard.stub_config().op_values)
	ai._scorer = spy
	var base: Dictionary = (board.profile.weights as Dictionary).duplicate()
	var multipliers: Dictionary = board.profile.rules.defensive_multipliers

	# Act
	var _plan_done: TurnPlan = await _plan(board)

	# Assert
	assert_str(String(spy.modes[0])).is_equal(String(Scorer.MODE_DEFENSIVE))
	for key: String in BossAI.WEIGHT_KEYS:
		var expected: float = float(base[key]) * float(multipliers.get(key, 1.0))
		assert_float(float(spy.profiles[0].weights[key])).is_equal_approx(expected, 0.0001)
	assert_dict(board.profile.weights).is_equal(base)


func test_the_choice_follows_the_defensive_multipliers() -> void:
	# Arrange — a boss attacker beside the same hand: by default the Taunt goes
	# first; with `w_face` multiplied past everything, the face attack does
	var plain: Dictionary = _fixture()
	plain.boss.board = ["bai_brute"]
	var mutated: Dictionary = _fixture()
	mutated.boss.board = ["bai_brute"]
	var default_board: Dictionary = _board(plain)
	var face_board: Dictionary = _board(mutated)
	var rules: Dictionary = (face_board.profile.rules as Dictionary).duplicate(true)
	rules.defensive_multipliers.w_face = OVERWHELMING
	face_board.profile.rules = rules

	# Act
	var default_first: Dictionary = _decisions(await _plan(default_board))[0]
	var face_first: Dictionary = _decisions(await _plan(face_board))[0]

	# Assert
	assert_str(str(default_first.chosen.type)).is_equal(MatchRecords.CMD_PLAY_CARD)
	assert_str(str(face_first.chosen.type)).is_equal(MatchRecords.CMD_ATTACK)


func test_a_successful_clear_drops_back_to_normal_within_the_turn() -> void:
	# Arrange — the 4/4 kills the 3/2 Windfury: incoming 4 + 6, under the line; a card
	# left to play gives the next pass something to score
	var fixture: Dictionary = _fixture()
	fixture.boss.board = ["bai_ogre"]
	fixture.boss.hand = ["bai_brute"]
	var board: Dictionary = _board(fixture)

	# Act
	var plan: TurnPlan = await _plan(board)

	# Assert
	assert_array(plan.mode_trace).is_equal([Scorer.MODE_NORMAL, Scorer.MODE_DEFENSIVE, Scorer.MODE_NORMAL])
	var decisions: Array = _decisions(plan)
	assert_str(str(decisions[0].mode)).is_equal(String(Scorer.MODE_DEFENSIVE))
	assert_dict(decisions[1].mode_transition).is_equal({"from": String(Scorer.MODE_DEFENSIVE), "to": String(Scorer.MODE_NORMAL)})


func test_a_turn_that_stays_defensive_logs_one_transition() -> void:
	# Arrange — two passes, the threat unmoved: the mode is re-evaluated, not re-entered
	var fixture: Dictionary = _fixture()
	fixture.boss.mana = 6
	var board: Dictionary = _board(fixture)

	# Act
	var plan: TurnPlan = await _plan(board)

	# Assert
	assert_int(_decisions(plan).size()).is_greater(1)
	assert_array(plan.mode_trace).is_equal([Scorer.MODE_NORMAL, Scorer.MODE_DEFENSIVE])


func test_a_doomed_boss_still_plays_its_best_defensive_action_and_may_race() -> void:
	# Arrange — boss at 5, nothing it holds moves the estimate, a 1/1 that can swing
	var fixture: Dictionary = _fixture()
	fixture.cards.append({"id": "bai_pup", "type": "minion", "cost": 1, "attack": 1, "health": 1})
	fixture.boss.health = 5
	fixture.boss.board = ["bai_pup"]
	fixture.boss.hand = []
	fixture.boss.mana = 0
	var board: Dictionary = _board(fixture)
	var hero: int = int((board.engine as RulesEngine).state().players[SIDE_PLAYER].hero.entity_id)

	# Act
	var plan: TurnPlan = await _plan(board)

	# Assert — it neither faults nor stalls; `f_face` is reduced by the weight, not zeroed
	var decisions: Array = _decisions(plan)
	assert_str(str(decisions[0].mode)).is_equal(String(Scorer.MODE_DEFENSIVE))
	assert_str(str(plan.commands.back().type)).is_equal(MatchRecords.CMD_END_TURN)
	assert_array(plan.diagnostics.filter(func(d: Dictionary) -> bool: return str(d[TurnPlan.EVENT_KEY]) == BossAI.EVENT_FAULT)).is_empty()
	var face: Array = (decisions[0].alternatives as Array).filter(func(a: Dictionary) -> bool: return a.command.get("target_id") == hero)
	assert_int(face.size()).is_equal(1)
	assert_float(float(face[0].features.f_face)).is_greater(0.0)


# --- A20 ----------------------------------------------------------------------

func test_a20_a_boss_passive_that_doubles_healing_reaches_the_sandbox() -> void:
	# Arrange
	var board: Dictionary = _heal_board(true)

	# Act
	var f_heal: float = _f_heal(board)

	# Assert
	assert_float(f_heal).is_equal_approx(float(board.fixture.expect.f_heal_doubled), float(board.fixture.expect.tolerance))


func test_a20_without_the_passive_the_same_heal_is_single() -> void:
	# Arrange
	var board: Dictionary = _heal_board(false)

	# Act
	var f_heal: float = _f_heal(board)

	# Assert
	assert_float(f_heal).is_equal_approx(float(board.fixture.expect.f_heal_plain), float(board.fixture.expect.tolerance))


func test_a20_lethal_wins_when_the_defensive_condition_holds_too() -> void:
	# Arrange — the F6 threat stands and the boss's 3/3 can finish a player at 3
	var fixture: Dictionary = _fixture()
	fixture.boss.board = ["bai_brute"]
	fixture.player.health = 3
	fixture.player.board = ["bai_sleeper"]
	var board: Dictionary = _board(fixture)
	var engine: RulesEngine = board.engine
	engine.state().players[SIDE_PLAYER].turns_taken = 20

	# Act
	var defensive: bool = ThreatEstimate.defensive(engine, board.profile.rules, SIDE_BOSS)
	var plan: TurnPlan = await _plan(board)

	# Assert
	assert_bool(defensive).is_true()
	assert_str(str(_decisions(plan)[0].mode)).is_equal(String(Scorer.MODE_LETHAL))
	assert_bool(plan.mode_trace.has(Scorer.MODE_DEFENSIVE)).is_false()
