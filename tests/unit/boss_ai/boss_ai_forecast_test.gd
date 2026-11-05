## Unit tests for the forecast and telegraphing of the Boss AI (story
## boss-ai-match-driver/story-011; design/gdd/boss-ai.md C8.1-C8.5, C1.4 `forecast`,
## States `Forecasting`, Edge Cases "forecast and the real turn disagree", A19, A21;
## ADR-0006, ADR-0008; TR-boss-ai-002, TR-boss-ai-004; BAI review N5).
##
## Boards are `tests/fixtures/boss_ai/` setups on the production `EffectResolver`
## ([BossAiBoard]), moved on to the player's Main. `ai_intent_shown` is appended by
## the driver (story 014): here its payload is [method Intent.to_dict] and the
## driver's gate is [method Intent.is_shown].
extends GdUnitTestSuite

const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const SIDE_BOSS: String = MatchRecords.SIDE_BOSS
const AI_SEED: int = 7
const BOSS_ID: String = "boss_test"
const OVERRIDE: String = "bai_concealed"
## The `boss.turns_taken` that gives [constant NEXT_MANA] mana on the boss's next turn.
const TURNS_TAKEN: int = 4
const NEXT_MANA: int = 5
const CRYSTAL_BONUS: int = 1
## The `boss.turns_taken` that gives the mid-plan-draw fixture its 4 forecast mana.
const MID_PLAN_TURNS_TAKEN: int = 3


## A [Scorer] that remembers each `score_all` context.
class SpyScorer:
	extends Scorer

	var contexts: Array[Dictionary] = []

	func score_all(sandbox: RulesEngine, candidates: Array, profile: Dictionary, mode: StringName, context: Dictionary, planner: PlannerTask) -> Array:
		contexts.append(context)
		return await super(sandbox, candidates, profile, mode, context, planner)


# --- helpers -----------------------------------------------------------------

## [param fixture] laid out, then moved on to the player's Main, with a [BossAI].
func _board(fixture: Dictionary, profile: Dictionary = {}) -> Dictionary:
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = BossAiBoard.engine(fixture, db, [], log)
	var stream: RngStream = TestRngStream.seeded("ai_1", AI_SEED)
	var stub: Dictionary = BossAiBoard.stub_config()
	var used: Dictionary = BossAiBoard.profile(fixture) if profile.is_empty() else profile
	var ai: BossAI = BossAI.new(CardFactory.make_boss_def(BOSS_ID, int(fixture.band)), used, int(fixture.band), stream, stub.op_values, log, db, stub.keyword_values)
	assert_bool(engine.submit(MatchRecords.end_turn(SIDE_BOSS)).accepted).is_true()
	assert_str(String(engine.active_side())).is_equal(SIDE_PLAYER)
	assert_str(engine.phase()).is_equal(MatchState.PHASE_MAIN)
	return {"fixture": fixture, "db": db, "engine": engine, "log": log, "stream": stream, "ai": ai}


func _named(name: String) -> Dictionary:
	return _board(BossAiBoard.read(name))


## The `attackers_4_3` fixture with [param hand], the attackers kept unless
## [param board] replaces them.
func _with_hand(hand: Array, board: Variant = null) -> Dictionary:
	var fixture: Dictionary = BossAiBoard.read("attackers_4_3")
	fixture.boss.hand = hand
	if board is Array:
		fixture.boss.board = board
	return fixture


func _forecast(board: Dictionary) -> Intent:
	var sandbox: RulesEngine = (board.engine as RulesEngine).clone()
	var intent: Intent = await (board.ai as BossAI).forecast(sandbox)
	sandbox.end_match()
	return intent


## Plays the player's End step on the live engine and plans the boss's turn.
func _commit(board: Dictionary) -> TurnPlan:
	var engine: RulesEngine = board.engine
	assert_bool(engine.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()
	var sandbox: RulesEngine = engine.clone()
	var plan: TurnPlan = await (board.ai as BossAI).plan_turn(sandbox)
	sandbox.end_match()
	return plan


func _committed(plan: TurnPlan) -> Dictionary:
	var found: Array = plan.diagnostics.filter(func(d: Dictionary) -> bool: return str(d[TurnPlan.EVENT_KEY]) == BossAI.EVENT_INTENT_COMMITTED)
	assert_int(found.size()).is_equal(1)
	return found[0]


## The resolved profile of a `boss_overrides` entry whose `intent_mode` is
## [param intent_mode], built the way a shipped override is (C10).
func _override_profile(intent_mode: String, band: int) -> Dictionary:
	var config: Dictionary = BossAiBoard.stub_config()
	config.boss_overrides[OVERRIDE] = {"extends": BossAI.DEFAULT_PROFILE, "intent_mode": intent_mode}
	return ProfileResolver.resolve(config, CardFactory.make_boss_def(BOSS_ID, band, {"ai_profile": OVERRIDE}), band)


func _set_next_mana(engine: RulesEngine, turns_taken: int, crystal_bonus: int = 0) -> void:
	var boss: Dictionary = engine.state().players[SIDE_BOSS]
	boss.turns_taken = turns_taken
	boss.crystal_bonus = crystal_bonus


# --- A19: the telegraph matrix ------------------------------------------------

func test_a19_full_names_attack_face_with_the_attackers_total() -> void:
	# Arrange
	var board: Dictionary = _named("attackers_4_3")

	# Act
	var intent: Intent = await _forecast(board)

	# Assert
	assert_dict(intent.to_dict()).is_equal({"boss_id": BOSS_ID, "intent_key": Intent.KEY_ATTACK_FACE, "target_id": null, "amount": int(board.fixture.expect.amount), "effective_mode": Intent.MODE_FULL})
	assert_bool(intent.is_shown()).is_true()


func test_a19_a_class_only_boss_shows_the_class_with_no_amount_or_target() -> void:
	# Arrange
	var fixture: Dictionary = BossAiBoard.read("attackers_4_3")
	var board: Dictionary = _board(fixture, _override_profile(Intent.MODE_CLASS_ONLY, int(fixture.band)))

	# Act
	var intent: Intent = await _forecast(board)

	# Assert
	assert_dict(intent.to_dict()).is_equal({"boss_id": BOSS_ID, "intent_key": Intent.KEY_ATTACK_FACE, "target_id": null, "amount": null, "effective_mode": Intent.MODE_CLASS_ONLY})


func test_a19_telegraph_brief_on_a_full_boss_is_class_only() -> void:
	# Arrange
	var board: Dictionary = _named("attackers_4_3")
	(board.ai as BossAI).set_telegraph_mode(BossAI.TELEGRAPH_BRIEF)

	# Act
	var intent: Intent = await _forecast(board)

	# Assert
	assert_str(intent.effective_mode).is_equal(Intent.MODE_CLASS_ONLY)
	assert_that(intent.amount).is_null()
	assert_that(intent.target_id).is_null()
	assert_bool(intent.is_shown()).is_true()


func test_a19_telegraph_off_hides_the_forecast_and_the_commit_still_carries_it() -> void:
	# Arrange
	var board: Dictionary = _named("attackers_4_3")
	(board.ai as BossAI).set_telegraph_mode(BossAI.TELEGRAPH_OFF)

	# Act
	var intent: Intent = await _forecast(board)
	(board.ai as BossAI).note_forecast(intent)
	var committed: Dictionary = _committed(await _commit(board))

	# Assert
	assert_str(intent.effective_mode).is_equal(Intent.MODE_HIDDEN)
	assert_bool(intent.is_shown()).is_false()
	assert_str(str(committed.effective_mode)).is_equal(Intent.MODE_HIDDEN)
	assert_that(committed.amount).is_null()
	assert_that(committed.target_id).is_null()
	assert_bool(bool(committed.kept)).is_true()


func test_a19_a_hidden_override_hides_the_forecast_and_the_commit_still_carries_it() -> void:
	# Arrange
	var fixture: Dictionary = BossAiBoard.read("attackers_4_3")
	var board: Dictionary = _board(fixture, _override_profile(Intent.MODE_HIDDEN, int(fixture.band)))

	# Act
	var intent: Intent = await _forecast(board)
	var committed: Dictionary = _committed(await _commit(board))

	# Assert
	assert_str(intent.effective_mode).is_equal(Intent.MODE_HIDDEN)
	assert_bool(intent.is_shown()).is_false()
	assert_str(str(committed.effective_mode)).is_equal(Intent.MODE_HIDDEN)


func test_a19_no_band_overlay_resolves_to_hidden() -> void:
	# Arrange
	var config: Dictionary = BossAiBoard.stub_config()

	for band: int in [1, 2, 3]:
		# Act
		var profile: Dictionary = ProfileResolver.resolve(config, CardFactory.make_boss_def(BOSS_ID, band), band)

		# Assert
		assert_str(str(profile.intent_mode)).is_not_equal(Intent.MODE_HIDDEN)


func test_c8_4_effective_mode_is_the_lower_of_the_boss_and_the_setting() -> void:
	# Arrange
	var fixture: Dictionary = BossAiBoard.read("attackers_4_3")
	var expected: Dictionary = {
		Intent.MODE_FULL: {BossAI.TELEGRAPH_FULL: Intent.MODE_FULL, BossAI.TELEGRAPH_BRIEF: Intent.MODE_CLASS_ONLY, BossAI.TELEGRAPH_OFF: Intent.MODE_HIDDEN},
		Intent.MODE_CLASS_ONLY: {BossAI.TELEGRAPH_FULL: Intent.MODE_CLASS_ONLY, BossAI.TELEGRAPH_BRIEF: Intent.MODE_CLASS_ONLY, BossAI.TELEGRAPH_OFF: Intent.MODE_HIDDEN},
		Intent.MODE_HIDDEN: {BossAI.TELEGRAPH_FULL: Intent.MODE_HIDDEN, BossAI.TELEGRAPH_BRIEF: Intent.MODE_HIDDEN, BossAI.TELEGRAPH_OFF: Intent.MODE_HIDDEN},
	}

	for intent_mode: String in expected:
		var ai: BossAI = _board(fixture, _override_profile(intent_mode, int(fixture.band))).ai
		for telegraph: String in expected[intent_mode]:
			# Act
			ai.set_telegraph_mode(telegraph)

			# Assert
			assert_str(ai.effective_mode()).is_equal(expected[intent_mode][telegraph])


func test_no_telegraph_setting_at_construction_is_full() -> void:
	# Arrange / Act
	var board: Dictionary = _named("attackers_4_3")

	# Assert
	assert_str((board.ai as BossAI).effective_mode()).is_equal(Intent.MODE_FULL)


func test_an_unknown_telegraph_setting_leaves_the_mode_as_it_was() -> void:
	# Arrange
	var ai: BossAI = _named("attackers_4_3").ai
	ai.set_telegraph_mode(BossAI.TELEGRAPH_BRIEF)

	# Act
	ai.set_telegraph_mode("loud")

	# Assert
	assert_str(ai.effective_mode()).is_equal(Intent.MODE_CLASS_ONLY)


# --- A21 and `kept` -----------------------------------------------------------

func test_a21_killing_the_only_attacker_commits_a_new_intent_and_kept_false() -> void:
	# Arrange
	var board: Dictionary = _named("forecast_then_attacker_killed")
	var engine: RulesEngine = board.engine
	var log: TestEventLog = board.log
	var intent: Intent = await _forecast(board)
	var shown: Dictionary = intent.to_dict()
	(board.ai as BossAI).note_forecast(intent)
	var shown_seq: int = log.append(BossAI.EVENT_INTENT_SHOWN, shown, 0)
	var slayer: int = BossAiBoard.ids_of(engine, SIDE_PLAYER, "bai_slayer")[0]
	var brute: int = BossAiBoard.ids_of(engine, SIDE_BOSS, "bai_brute")[0]

	# Act
	assert_bool(engine.submit(MatchRecords.attack(SIDE_PLAYER, slayer, brute)).accepted).is_true()
	var committed: Dictionary = _committed(await _commit(board))

	# Assert — the forecast was attack_face, and neither it nor its event moved
	assert_str(str(shown.intent_key)).is_equal(Intent.KEY_ATTACK_FACE)
	assert_bool(bool(committed.kept)).is_false()
	assert_str(str(committed.intent_key)).is_not_equal(Intent.KEY_ATTACK_FACE)
	assert_str(intent.intent_key).is_equal(Intent.KEY_ATTACK_FACE)
	var events: Array = log.events_since(shown_seq - 1)
	assert_dict(events[0].payload).is_equal(shown)


func test_an_unchanged_board_commits_the_forecast_with_kept_true() -> void:
	# Arrange
	var board: Dictionary = _named("attackers_4_3")
	var intent: Intent = await _forecast(board)
	(board.ai as BossAI).note_forecast(intent)

	# Act
	var committed: Dictionary = _committed(await _commit(board))

	# Assert
	assert_str(str(committed.intent_key)).is_equal(intent.intent_key)
	assert_bool(bool(committed.kept)).is_true()
	assert_int(int(committed.amount)).is_equal(int(intent.amount))
	assert_str(str(committed.effective_mode)).is_equal(Intent.MODE_FULL)


func test_the_commit_is_the_first_diagnostic_of_the_plan_and_is_routed_before_its_first_command() -> void:
	# Arrange
	var board: Dictionary = _named("attackers_4_3")

	# Act
	var plan: TurnPlan = await _commit(board)

	# Assert
	assert_str(str(plan.diagnostics[0][TurnPlan.EVENT_KEY])).is_equal(BossAI.EVENT_INTENT_COMMITTED)
	assert_int(int(plan.diagnostics[0][TurnPlan.COMMAND_INDEX_KEY])).is_equal(0)
	assert_str(str(plan.diagnostics[1][TurnPlan.EVENT_KEY])).is_equal(BossAI.EVENT_DECISION)


func test_the_commit_carries_the_catalogued_keys_and_is_no_diagnostic_event() -> void:
	# Arrange — rng-event-log §D; rule 12a lists the three diagnostic types only
	var plan: TurnPlan = await _commit(_named("attackers_4_3"))

	# Act
	var payload: Dictionary = TurnPlan.event_payload(_committed(plan))

	# Assert
	var keys: Array = payload.keys()
	keys.sort()
	assert_array(keys).is_equal(["amount", "effective_mode", "intent_key", "kept", "target_id"])


func test_a_plan_with_no_forecast_noted_commits_kept_false() -> void:
	# Arrange — a forecast the driver discarded is never noted
	var board: Dictionary = _named("attackers_4_3")
	var discarded: Intent = await _forecast(board)

	# Act
	var committed: Dictionary = _committed(await _commit(board))

	# Assert
	assert_str(discarded.intent_key).is_equal(str(committed.intent_key))
	assert_bool(bool(committed.kept)).is_false()


func test_a_noted_forecast_is_read_by_one_commit_only() -> void:
	# Arrange — a later turn's forecast may be discarded: the old one must not answer for it
	var board: Dictionary = _named("attackers_4_3")
	var ai: BossAI = board.ai
	ai.note_forecast(await _forecast(board))

	# Act
	var first: Dictionary = _committed(await _commit(board))
	var sandbox: RulesEngine = (board.engine as RulesEngine).clone()
	var second: Dictionary = _committed(await ai.plan_turn(sandbox))
	sandbox.end_match()

	# Assert
	assert_bool(bool(first.kept)).is_true()
	assert_bool(bool(second.kept)).is_false()
	assert_that(ai.last_forecast).is_null()


func test_forecast_alone_stores_nothing_on_the_ai() -> void:
	# Arrange
	var board: Dictionary = _named("attackers_4_3")

	# Act
	var intent: Intent = await _forecast(board)

	# Assert
	assert_that((board.ai as BossAI).last_forecast).is_null()
	(board.ai as BossAI).note_forecast(intent)
	assert_that((board.ai as BossAI).last_forecast).is_same(intent)


# --- forecast inputs ----------------------------------------------------------

func test_the_forecast_plans_with_next_turns_mana_and_a_boss_crystal_bonus() -> void:
	# Arrange — a 6-cost in hand: 5 next-turn crystals do not reach it, a bonus does
	var without: Dictionary = _board(_with_hand(["bai_titan"], []))
	_set_next_mana(without.engine, TURNS_TAKEN)
	var with_bonus: Dictionary = _board(_with_hand(["bai_titan"], []))
	_set_next_mana(with_bonus.engine, TURNS_TAKEN, CRYSTAL_BONUS)

	# Act
	var short: Intent = await _forecast(without)
	var reached: Intent = await _forecast(with_bonus)

	# Assert
	assert_int(Chooser.next_mana_max(without.engine, SIDE_BOSS)).is_equal(NEXT_MANA)
	assert_str(short.intent_key).is_equal(Intent.KEY_PASS)
	assert_str(reached.intent_key).is_equal(Intent.KEY_PLAY_BIG_MINION)


func test_a_minion_of_cost_five_is_big_and_of_cost_four_is_not() -> void:
	# Arrange
	var big: Dictionary = _board(_with_hand(["bai_giant"], []))
	_set_next_mana(big.engine, TURNS_TAKEN)
	var small: Dictionary = _board(_with_hand(["bai_ogre"], []))
	_set_next_mana(small.engine, TURNS_TAKEN)

	# Act
	var giant: Intent = await _forecast(big)
	var ogre: Intent = await _forecast(small)

	# Assert
	assert_str(giant.intent_key).is_equal(Intent.KEY_PLAY_BIG_MINION)
	assert_str(ogre.intent_key).is_equal(Intent.KEY_DEVELOP_BOARD)
	assert_that(giant.amount).is_null()
	assert_that(giant.target_id).is_null()


func test_the_forecast_plans_the_current_hand_and_never_the_deck_top() -> void:
	# Arrange — no board, no hand; the deck is 1-cost minions the Start step would draw
	var deck_only: Dictionary = _with_hand([], [])
	deck_only.deck_card = "bai_squib"
	var holding: Dictionary = _with_hand(["bai_squib"], [])

	# Act
	var without: Intent = await _forecast(_board(deck_only))
	var with_card: Intent = await _forecast(_board(holding))

	# Assert — the same card in hand is played
	assert_str(without.intent_key).is_equal(Intent.KEY_PASS)
	assert_str(with_card.intent_key).is_equal(Intent.KEY_DEVELOP_BOARD)


func test_a_card_drawn_on_the_boss_turn_can_change_the_plan_with_the_board_unchanged() -> void:
	# Arrange — C8.1 forecasts the current hand, so the draw is the one thing the
	# forecast cannot know: the real turn plays it and `kept` says so
	var fixture: Dictionary = _with_hand([], [])
	fixture.deck_card = "bai_squib"
	var board: Dictionary = _board(fixture)
	var intent: Intent = await _forecast(board)
	(board.ai as BossAI).note_forecast(intent)

	# Act
	var committed: Dictionary = _committed(await _commit(board))

	# Assert
	assert_str(intent.intent_key).is_equal(Intent.KEY_PASS)
	assert_str(str(committed.intent_key)).is_equal(Intent.KEY_DEVELOP_BOARD)
	assert_bool(bool(committed.kept)).is_false()


## [param board] with the first cards of the boss's deck set to [param order].
func _stack_deck(board: Dictionary, order: Array) -> void:
	var deck: Array = (board.engine as RulesEngine).state().players[SIDE_BOSS].deck
	for index: int in order.size():
		deck[index].def_id = str(order[index])


## The forecast of the mid-plan-draw fixture with the deck in [param order].
func _forecast_with_deck(fixture: Dictionary, order: Array) -> Intent:
	var board: Dictionary = _board(fixture.duplicate(true))
	_set_next_mana(board.engine, MID_PLAN_TURNS_TAKEN)
	_stack_deck(board, order)
	return await _forecast(board)


func test_d1_a_card_drawn_mid_plan_never_shapes_the_forecast() -> void:
	# Arrange — the same public board; the card under the Start draw is playable
	# with what the bolt leaves in one order, and not in the other
	var fixture: Dictionary = BossAiBoard.read("forecast_mid_plan_draw")

	# Act
	var first: Intent = await _forecast_with_deck(fixture, fixture.deck_orders[0])
	var second: Intent = await _forecast_with_deck(fixture, fixture.deck_orders[1])

	# Assert
	assert_dict(first.to_dict()).is_equal(second.to_dict())


func test_d1_a_lethal_line_through_an_undrawn_card_is_not_forecast() -> void:
	# Arrange — F4 passes on the board and the bolt alone, and only the Charge under
	# the Start draw finishes it: the search must not reach it through the bolt
	var fixture: Dictionary = BossAiBoard.read("forecast_mid_plan_draw")
	var case: Dictionary = fixture.lethal_case
	fixture.boss.board = case.boss_board
	fixture.player.health = case.player_health
	fixture.player.board = case.player_board

	# Act
	var through: Intent = await _forecast_with_deck(fixture, case.deck_orders[0])
	var without: Intent = await _forecast_with_deck(fixture, case.deck_orders[1])

	# Assert
	assert_str(through.intent_key).is_not_equal(Intent.KEY_LETHAL)
	assert_dict(through.to_dict()).is_equal(without.to_dict())


func test_d1_a_real_plan_keeps_and_plays_the_card_it_draws() -> void:
	# Arrange — on the boss's own turn the draw is real
	var fixture: Dictionary = BossAiBoard.read("forecast_mid_plan_draw")
	var board: Dictionary = _board(fixture)
	_set_next_mana(board.engine, MID_PLAN_TURNS_TAKEN)
	_stack_deck(board, ["bai_filler", "bai_delver"])
	var engine: RulesEngine = board.engine
	assert_bool(engine.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()
	var sandbox: RulesEngine = engine.clone()

	# Act — the Start step draws the filler, the bolt draws the delver
	var plan: TurnPlan = await (board.ai as BossAI).plan_turn(sandbox)
	var delver_on_board: bool = not BossAiBoard.ids_of(sandbox, SIDE_BOSS, "bai_delver").is_empty()
	sandbox.end_match()

	# Assert
	assert_bool(delver_on_board).is_true()
	assert_str(str(_committed(plan).intent_key)).is_equal(Intent.KEY_DEVELOP_BOARD)


func test_d1_a_lethal_step_that_draws_and_aborts_leaves_no_deck_card_for_scoring() -> void:
	# Arrange — a one-step "lethal" that draws and leaves the player alive: the plan
	# aborts and the turn scores on, so the drawn card must already be gone
	var fixture: Dictionary = BossAiBoard.read("forecast_mid_plan_draw")
	var board: Dictionary = _board(fixture)
	_set_next_mana(board.engine, MID_PLAN_TURNS_TAKEN)
	var engine: RulesEngine = board.engine
	assert_bool(engine.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()
	var sandbox: RulesEngine = engine.clone()
	var boss: Dictionary = sandbox.state().players[SIDE_BOSS]
	var turn: BossAI._Turn = BossAI._Turn.new(sandbox, ImmediatePlannerTask.new(), SIDE_BOSS, board.stream)
	turn.unseen = (boss.deck as Array).map(func(card: Dictionary) -> int: return int(card.instance_id))
	var bolt: Array = sandbox.legal_commands().filter(func(c: Dictionary) -> bool: return str(c.type) == MatchRecords.CMD_PLAY_CARD and int(c.hand_index) == 0)

	# Act
	(board.ai as BossAI)._execute_lethal(turn, bolt)
	var from_deck: Array = (boss.hand as Array).filter(func(card: Dictionary) -> bool: return turn.unseen.has(int(card.instance_id)))
	sandbox.end_match()

	# Assert
	assert_str(str(turn.plan.diagnostics.back().reason)).is_equal(BossAI.ABORT_NOT_LETHAL)
	assert_array(from_deck).is_empty()


func test_d1_only_cards_from_the_deck_are_dropped() -> void:
	# Arrange — a card the hand held and one a card effect made stay; the deck's goes
	var board: Dictionary = _named("attackers_4_3")
	var sandbox: RulesEngine = (board.engine as RulesEngine).clone()
	var boss: Dictionary = sandbox.state().players[SIDE_BOSS]
	var unseen: Array = (boss.deck as Array).map(func(card: Dictionary) -> int: return int(card.instance_id))
	var kept: Dictionary = BossAiBoard.add_to_hand(sandbox, SIDE_BOSS, "bai_ogre")
	sandbox.draw(SIDE_BOSS, 1)
	var made: Dictionary = BossAiBoard.add_to_hand(sandbox, SIDE_BOSS, "bai_brute")

	# Act
	LethalSearch.drop_unseen(sandbox, SIDE_BOSS, unseen)
	var left: Array = (boss.hand as Array).map(func(card: Dictionary) -> int: return int(card.instance_id))
	sandbox.end_match()

	# Assert
	assert_array(left).is_equal([int(kept.instance_id), int(made.instance_id)])


func test_the_forecast_takes_one_parent_draw_and_never_moves_the_live_game() -> void:
	# Arrange
	var board: Dictionary = _named("attackers_4_3")
	var engine: RulesEngine = board.engine
	var stream: RngStream = board.stream
	var match_draws: int = (engine.rng_match() as RngStream).draws
	var log_size: int = (board.log as TestEventLog).events.size()
	var hand: Array = (engine.state().players[SIDE_BOSS].hand as Array).duplicate(true)

	# Act
	var first: Intent = await _forecast(board)
	var draws_after_first: int = stream.draws
	var second: Intent = await _forecast(board)

	# Assert — the new label's one draw, then nothing: the same forecast again
	assert_int(draws_after_first).is_equal(1)
	assert_int(stream.draws).is_equal(1)
	assert_dict(second.to_dict()).is_equal(first.to_dict())
	assert_int((engine.rng_match() as RngStream).draws).is_equal(match_draws)
	assert_int((board.log as TestEventLog).events.size()).is_equal(log_size)
	assert_array(engine.state().players[SIDE_BOSS].hand as Array).is_equal(hand)
	assert_str(engine.phase()).is_equal(MatchState.PHASE_MAIN)
	assert_str(String(engine.active_side())).is_equal(SIDE_PLAYER)


func test_a_forecast_tie_draws_from_the_forecast_fork_and_not_the_live_stream() -> void:
	# Arrange — two identical plays score the same (tie_set_board)
	var board: Dictionary = _named("tie_set_board")
	_set_next_mana(board.engine, 1)
	var stream: RngStream = board.stream

	# Act
	var intent: Intent = await _forecast(board)

	# Assert
	assert_str(intent.intent_key).is_equal(Intent.KEY_DEVELOP_BOARD)
	assert_int(stream.draws).is_equal(1)


func test_every_score_all_of_a_forecast_gets_the_forecast_fork() -> void:
	# Arrange
	var board: Dictionary = _named("attackers_4_3")
	var ai: BossAI = board.ai
	var spy: SpyScorer = SpyScorer.new(board.db, BossAiBoard.keyword_values(), BossAiBoard.stub_config().op_values)
	ai._scorer = spy
	var turn: int = int((board.engine as RulesEngine).state().turn)

	# Act
	var _intent: Intent = await _forecast(board)

	# Assert
	assert_int(spy.contexts.size()).is_greater(0)
	for context: Dictionary in spy.contexts:
		assert_str((context[Scorer.CONTEXT_SIM_STREAM] as RngStream).name).is_equal("ai_1/%s" % TieBreak.forecast_label(turn))
		assert_str(str(context[Scorer.CONTEXT_SIDE])).is_equal(SIDE_BOSS)


func test_a_forecast_outside_the_players_main_gives_no_intent_and_no_draw() -> void:
	# Arrange — the boss's own Main
	var board: Dictionary = _named("attackers_4_3")
	var engine: RulesEngine = board.engine
	assert_bool(engine.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()

	# Act
	var intent: Intent = await _forecast(board)

	# Assert
	assert_that(intent).is_null()
	assert_int((board.stream as RngStream).draws).is_equal(0)


# --- the dominant action --------------------------------------------------------

func test_a_proven_lethal_is_the_dominant_action_with_its_face_damage() -> void:
	# Arrange — 3 + 2 + 2 against 6, all three bands search
	var fixture: Dictionary = BossAiBoard.read("lethal_open_face")
	var board: Dictionary = _board(fixture)

	# Act
	var intent: Intent = await _forecast(board)

	# Assert
	assert_str(intent.intent_key).is_equal(Intent.KEY_LETHAL)
	assert_int(int(intent.amount)).is_greater_equal(int(fixture.player.health))
	assert_that(intent.target_id).is_null()


func test_attacking_a_minion_names_the_target() -> void:
	# Arrange — f1_worked_example's 3/3 into the 2/3 Taunt, no card to play
	var fixture: Dictionary = BossAiBoard.read("f1_worked_example")
	fixture.boss.hand = []
	var board: Dictionary = _board(fixture)
	var taunt: int = BossAiBoard.ids_of(board.engine, SIDE_PLAYER, "bai_wall")[0]

	# Act
	var intent: Intent = await _forecast(board)

	# Assert
	assert_str(intent.intent_key).is_equal(Intent.KEY_ATTACK_MINION)
	assert_int(int(intent.target_id)).is_equal(taunt)
	assert_that(intent.amount).is_null()


func test_a_removal_spell_names_its_target_and_reveals_no_card() -> void:
	# Arrange — a bolt in hand, and a 5/1 worth removing
	var fixture: Dictionary = _with_hand(["bai_bolt"], [])
	fixture.player.board = ["bai_lancer"]
	var board: Dictionary = _board(fixture)
	var lancer: int = BossAiBoard.ids_of(board.engine, SIDE_PLAYER, "bai_lancer")[0]

	# Act
	var intent: Intent = await _forecast(board)

	# Assert
	assert_str(intent.intent_key).is_equal(Intent.KEY_CAST_REMOVAL)
	assert_int(int(intent.target_id)).is_equal(lancer)
	assert_bool(str(intent.to_dict()).contains("bai_bolt")).is_false()


func test_amount_counts_only_the_attackers_that_exist_now() -> void:
	# Arrange — a Charge 5/1 in hand joins the attack; face weighted over the board
	var fixture: Dictionary = _with_hand(["bai_lancer"])
	fixture["weights"] = {"w_board": 0, "w_face": 5}
	var board: Dictionary = _board(fixture)
	_set_next_mana(board.engine, TURNS_TAKEN)

	# Act
	var intent: Intent = await _forecast(board)
	var boss_plan: TurnPlan = await _commit(board)

	# Assert — the turn's plan does swing with the Charge: the amount leaves it out
	var swings: Array = boss_plan.commands.filter(func(c: Dictionary) -> bool: return str(c.type) == MatchRecords.CMD_ATTACK)
	assert_int(swings.size()).is_equal(3)
	assert_str(intent.intent_key).is_equal(Intent.KEY_ATTACK_FACE)
	assert_int(int(intent.amount)).is_equal(int(fixture.expect.amount))


func test_amount_sums_the_face_rows_of_the_plan_around_other_actions() -> void:
	# Arrange
	var plan: TurnPlan = TurnPlan.new()
	plan.intent_rows.append({"key": Intent.KEY_ATTACK_FACE, "target_id": null, "face": 4, "score": 0.3, "lethal": false})
	plan.intent_rows.append({"key": Intent.KEY_DEVELOP_BOARD, "target_id": null, "face": 0, "score": 0.1, "lethal": false})
	plan.intent_rows.append({"key": Intent.KEY_ATTACK_FACE, "target_id": null, "face": 3, "score": 0.2, "lethal": false})
	var ai: BossAI = _named("attackers_4_3").ai

	# Act
	var intent: Intent = ai.intent_from_plan(plan)

	# Assert
	assert_str(intent.intent_key).is_equal(Intent.KEY_ATTACK_FACE)
	assert_int(int(intent.amount)).is_equal(7)


func test_the_highest_scoring_action_is_dominant_whatever_its_place_in_the_plan() -> void:
	# Arrange
	var plan: TurnPlan = TurnPlan.new()
	plan.intent_rows.append({"key": Intent.KEY_ATTACK_MINION, "target_id": 9, "face": 0, "score": 0.5, "lethal": false})
	plan.intent_rows.append({"key": Intent.KEY_DEVELOP_BOARD, "target_id": null, "face": 0, "score": 1.5, "lethal": false})
	var ai: BossAI = _named("attackers_4_3").ai

	# Act
	var intent: Intent = ai.intent_from_plan(plan)

	# Assert
	assert_str(intent.intent_key).is_equal(Intent.KEY_DEVELOP_BOARD)
	assert_that(intent.target_id).is_null()


func test_a_plan_of_no_action_is_pass() -> void:
	# Arrange
	var ai: BossAI = _named("attackers_4_3").ai

	# Act
	var intent: Intent = ai.intent_from_plan(TurnPlan.new())

	# Assert
	assert_str(intent.intent_key).is_equal(Intent.KEY_PASS)
	assert_that(intent.amount).is_null()


func test_every_command_class_maps_inside_the_closed_key_set() -> void:
	# Arrange
	var fixture: Dictionary = BossAiBoard.read("attackers_4_3")
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var hero: int = 1
	var enemy_minion: int = 2
	var own_minion: int = 3
	var attacker: int = 5
	var enemy: Array = [enemy_minion]
	var rows: Array = [
		[MatchRecords.attack(SIDE_BOSS, attacker, hero), null, Intent.KEY_ATTACK_FACE],
		[MatchRecords.attack(SIDE_BOSS, attacker, enemy_minion), null, Intent.KEY_ATTACK_MINION],
		[MatchRecords.use_hero_power(SIDE_BOSS, null), null, Intent.KEY_HERO_POWER],
		[MatchRecords.end_turn(SIDE_BOSS), null, Intent.KEY_PASS],
		[MatchRecords.play_card(SIDE_BOSS, 0, 0, null), db.card("bai_giant"), Intent.KEY_PLAY_BIG_MINION],
		[MatchRecords.play_card(SIDE_BOSS, 0, 0, null), db.card("bai_ogre"), Intent.KEY_DEVELOP_BOARD],
		[MatchRecords.play_card(SIDE_BOSS, 0, null, null), db.card("bai_axe"), Intent.KEY_EQUIP_WEAPON],
		[MatchRecords.play_card(SIDE_BOSS, 0, null, enemy_minion), db.card("bai_bolt"), Intent.KEY_CAST_REMOVAL],
		[MatchRecords.play_card(SIDE_BOSS, 0, null, hero), db.card("bai_bolt"), Intent.KEY_DEVELOP_BOARD],
		[MatchRecords.play_card(SIDE_BOSS, 0, null, own_minion), db.card("bai_bolt"), Intent.KEY_DEVELOP_BOARD],
		[MatchRecords.play_card(SIDE_BOSS, 0, null, null), db.card("bai_nova"), Intent.KEY_CAST_AOE],
		[MatchRecords.play_card(SIDE_BOSS, 0, null, null), db.card("bai_salve"), Intent.KEY_HEAL],
	]

	for row: Array in rows:
		# Act
		var key: String = Intent.key_of(row[0], row[1], hero, enemy)

		# Assert
		assert_str(key).is_equal(row[2])
		assert_bool(Intent.KEYS.has(key)).is_true()


# --- Frozen -------------------------------------------------------------------

func test_a_frozen_board_with_nothing_to_play_is_pass_and_never_attack_face() -> void:
	# Arrange
	var board: Dictionary = _named("frozen_boss_board")
	var engine: RulesEngine = board.engine
	engine.freeze(BossAiBoard.ids_of(engine, SIDE_BOSS, "bai_brute")[0])

	# Act
	var intent: Intent = await _forecast(board)

	# Assert
	assert_str(intent.intent_key).is_equal(Intent.KEY_PASS)
	assert_that(intent.amount).is_null()


func test_a_frozen_board_with_a_card_to_play_is_develop_board() -> void:
	# Arrange
	var fixture: Dictionary = BossAiBoard.read("frozen_boss_board")
	fixture.boss.hand = fixture.develop_hand
	var board: Dictionary = _board(fixture)
	var engine: RulesEngine = board.engine
	engine.freeze(BossAiBoard.ids_of(engine, SIDE_BOSS, "bai_brute")[0])

	# Act
	var intent: Intent = await _forecast(board)

	# Assert
	assert_str(intent.intent_key).is_equal(Intent.KEY_DEVELOP_BOARD)


func test_the_same_board_unfrozen_is_attack_face() -> void:
	# Arrange — the control of the two above
	var board: Dictionary = _named("frozen_boss_board")

	# Act
	var intent: Intent = await _forecast(board)

	# Assert
	assert_str(intent.intent_key).is_equal(Intent.KEY_ATTACK_FACE)


# --- N5: the side ---------------------------------------------------------------

func test_n5_a_scored_clone_at_the_players_main_measures_the_boss_side() -> void:
	# Arrange — boss and player mana differ
	var board: Dictionary = _named("attackers_4_3")
	var engine: RulesEngine = board.engine
	var boss: Dictionary = engine.state().players[SIDE_BOSS]
	boss.mana_current = 1
	boss.mana_max = 4
	var scorer: Scorer = Scorer.new(board.db, BossAiBoard.keyword_values())
	var sandbox: RulesEngine = engine.clone()

	# Act
	var entry: Dictionary = scorer.score(MatchRecords.end_turn(SIDE_BOSS), sandbox, BossAiBoard.profile(board.fixture), Scorer.MODE_NORMAL, {Scorer.CONTEXT_SIDE: SIDE_BOSS})
	sandbox.end_match()

	# Assert — the boss's −1/4, not the player's mana
	assert_float(float(entry.features.f_mana)).is_equal_approx(-0.25, 0.0001)


func test_n5_a_scored_clone_reads_the_hand_of_the_side_it_scores() -> void:
	# Arrange — a synergy card in the player's hand at index 0 must not be read
	# for a boss `play_card`; the boss's own card at index 0 is
	var fixture: Dictionary = _with_hand(["bai_filler"])
	var board: Dictionary = _board(fixture)
	var engine: RulesEngine = board.engine
	(engine.state().players[SIDE_PLAYER].hand as Array).clear()
	BossAiBoard.add_to_hand(engine, SIDE_PLAYER, "bai_titan")
	var scorer: Scorer = Scorer.new(board.db, BossAiBoard.keyword_values())
	var measured: Dictionary = scorer._measure(engine, Scorer.MODE_NORMAL, SIDE_BOSS)

	# Act / Assert
	assert_array(measured[SIDE_BOSS].hand_defs as Array).is_equal(["bai_filler"])
	assert_array(measured[SIDE_PLAYER].hand_defs as Array).is_empty()


func test_n5_the_forecast_plans_the_boss_side_from_the_players_main() -> void:
	# Arrange — the player holds a big card the boss must not play
	var board: Dictionary = _board(_with_hand(["bai_ogre"], []))
	var engine: RulesEngine = board.engine
	_set_next_mana(engine, TURNS_TAKEN)
	(engine.state().players[SIDE_PLAYER].hand as Array).clear()
	BossAiBoard.add_to_hand(engine, SIDE_PLAYER, "bai_titan")
	var sandbox: RulesEngine = engine.clone()

	# Act
	var intent: Intent = await (board.ai as BossAI).forecast(sandbox, null, SIDE_BOSS)
	sandbox.end_match()

	# Assert
	assert_str(intent.intent_key).is_equal(Intent.KEY_DEVELOP_BOARD)


func test_the_public_log_is_read_for_the_players_cards_on_the_players_turn() -> void:
	# Arrange — a forecast task is built at the player's Main: the side to move is
	# the player, and the cards that count are still the player's
	var fixture: Dictionary = _with_hand([])
	fixture.boss.board = []
	var board: Dictionary = _board(fixture)
	var engine: RulesEngine = board.engine
	var log: TestEventLog = board.log
	@warning_ignore("return_value_discarded")
	log.append(&"card_played", {"side": SIDE_PLAYER, "card_id": "bai_nova"}, 0)
	var sandbox: RulesEngine = engine.clone()
	var task: ImmediatePlannerTask = ImmediatePlannerTask.new()

	# Act
	task.start((board.ai as BossAI).forecast_task(sandbox, task))
	sandbox.end_match()

	# Assert
	assert_bool((board.ai as BossAI)._aoe_seen).is_true()


# --- the replay checksum --------------------------------------------------------

func test_the_intent_events_count_in_no_replay_checksum() -> void:
	# Arrange — the sandbox log never holds them, and the live log does
	var plain: Array = [{"type": "turn_ended", "payload": {}}]
	var with_intents: Array = [
		{"type": BossAI.EVENT_INTENT_COMMITTED, "payload": {"kept": true}},
		{"type": "turn_ended", "payload": {}},
		{"type": BossAI.EVENT_INTENT_SHOWN, "payload": {}},
	]

	# Act / Assert
	assert_int(TurnPlan.checksum(with_intents)).is_equal(TurnPlan.checksum(plain))


func test_play_turn_appends_the_commit_first_and_unflagged() -> void:
	# Arrange
	var board: Dictionary = _named("attackers_4_3")
	var engine: RulesEngine = board.engine
	var log: TestEventLog = board.log
	assert_bool(engine.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()
	var start: int = log.events.size()

	# Act
	await (board.ai as BossAI).play_turn(engine)

	# Assert
	var gained: Array = log.events.slice(start)
	assert_str(str(gained[0].type)).is_equal(BossAI.EVENT_INTENT_COMMITTED)
	assert_bool((gained[0].payload as Dictionary).has(TurnPlan.DIAGNOSTIC_KEY)).is_false()
