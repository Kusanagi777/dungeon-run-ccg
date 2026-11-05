## Unit tests for the Boss AI's hidden-information purity (story
## boss-ai-match-driver/story-012; design/gdd/boss-ai.md C1.2, C1.3, A4; ADR-0003,
## ADR-0006; TR-boss-ai-001).
##
## `decoy_hand_a` puts area spells in the player's hand through the engine, so each
## `card_drawn.card_id` is in the log the AI holds. Reading them as `aoe_seen` would
## charge the 5th grunt `f_over`, and X would be played instead. The control test
## plays the same spell in public and watches X played, so "X is not played" cannot
## pass on a board where nothing could have moved it. `decoy_hand_b` is the same
## game with no card of the player's in common.
##
## The forecast and the turn run as the driver runs them, through `forecast_task`
## and `plan_task` on an [ImmediatePlannerTask]: those are what read the live log.
extends GdUnitTestSuite

const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const SIDE_BOSS: String = MatchRecords.SIDE_BOSS
const AI_SEED: int = 7
const BOSS_ID: String = "boss_test"
const DECOY_A: String = "decoy_hand_a"
const DECOY_B: String = "decoy_hand_b"
## The `boss.turns_taken` that gives the boss 1 mana next turn: one card, X or the grunt.
const TURNS_TAKEN: int = 0
## The fixture keys allowed to differ between the two decoys.
const FREE_KEYS: Array[String] = ["name", "description", "player_drawn", "player_deck"]


## A [Scorer] that keeps each `score_all` result as canonical JSON, the forecast's
## included: a forecast returns only its [Intent].
class ScoreRecorder:
	extends Scorer

	var scored: Array[String] = []

	func score_all(sandbox: RulesEngine, candidates: Array, profile: Dictionary, mode: StringName, context: Dictionary, planner: PlannerTask) -> Array:
		var result: Array = await super(sandbox, candidates, profile, mode, context, planner)
		scored.append(EventLogAssertions.canonical_json(result))
		return result


# --- helpers -----------------------------------------------------------------

## [param fixture]'s game at the player's Main, the player's hand drawn through the
## engine. [param casts] are spells the player played in public on turn 1.
func _board(fixture: Dictionary, casts: Array = []) -> Dictionary:
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = BossAiBoard.engine(fixture, db, casts, log)
	var stream: RngStream = TestRngStream.seeded("ai_1", AI_SEED)
	var stub: Dictionary = BossAiBoard.stub_config()
	var band: int = int(fixture.band)
	var ai: BossAI = BossAI.new(CardFactory.make_boss_def(BOSS_ID, band), BossAiBoard.profile(fixture), band, stream, stub.op_values, log, db, stub.keyword_values)
	var recorder: ScoreRecorder = ScoreRecorder.new(db, BossAiBoard.keyword_values(), stub.op_values)
	ai._scorer = recorder
	_stack_player_deck(engine, fixture)
	assert_bool(engine.submit(MatchRecords.end_turn(SIDE_BOSS)).accepted).is_true()
	engine.draw(SIDE_PLAYER, (fixture.player_drawn as Array).size() - 1)
	engine.state().players[SIDE_BOSS].turns_taken = TURNS_TAKEN
	return {"fixture": fixture, "engine": engine, "log": log, "ai": ai, "recorder": recorder}


## The player's deck as [param fixture] orders it: `player_drawn` on top, the rest
## cycled from `player_deck`. The Start step and [method _board] draw the top cards.
func _stack_player_deck(engine: RulesEngine, fixture: Dictionary) -> void:
	var deck: Array = engine.state().players[SIDE_PLAYER].deck
	var drawn: Array = fixture.player_drawn
	var rest: Array = fixture.player_deck
	for index: int in deck.size():
		deck[index].def_id = str(drawn[index]) if index < drawn.size() else str(rest[index % rest.size()])


func _forecast(board: Dictionary) -> Intent:
	var sandbox: RulesEngine = (board.engine as RulesEngine).clone()
	var task: ImmediatePlannerTask = ImmediatePlannerTask.new()
	task.start((board.ai as BossAI).forecast_task(sandbox, task))
	sandbox.end_match()
	return task.result()


## The player's End step on the live engine, then the boss's plan.
func _plan(board: Dictionary) -> TurnPlan:
	var engine: RulesEngine = board.engine
	assert_bool(engine.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()
	var sandbox: RulesEngine = engine.clone()
	var task: ImmediatePlannerTask = ImmediatePlannerTask.new()
	task.start((board.ai as BossAI).plan_task(sandbox, task))
	sandbox.end_match()
	return task.result()


## Forecast, kept as the driver keeps it, then the turn: `{intent, plan}`.
func _play(board: Dictionary) -> Dictionary:
	var intent: Intent = _forecast(board)
	(board.ai as BossAI).note_forecast(intent)
	return {"intent": intent, "plan": _plan(board)}


func _diagnostics(plan: TurnPlan, event: StringName) -> Array:
	return plan.diagnostics.filter(func(d: Dictionary) -> bool: return StringName(str(d[TurnPlan.EVENT_KEY])) == event)


func _decision_bytes(plan: TurnPlan) -> String:
	return EventLogAssertions.canonical_json(_diagnostics(plan, BossAI.EVENT_DECISION))


## Whether [param plan] plays [param def_id] out of the boss hand of [param board]:
## the plan's commands, read against the hand it started from.
func _played(plan: TurnPlan, board: Dictionary, def_id: String) -> bool:
	var hand: Array = (board.engine as RulesEngine).state().players[SIDE_BOSS].hand
	for command: Dictionary in plan.commands:
		if str(command.type) == MatchRecords.CMD_PLAY_CARD and str(hand[int(command.hand_index)].def_id) == def_id:
			return true
	return false


func _hand_ids(engine: RulesEngine) -> Array:
	return (engine.state().players[SIDE_PLAYER].hand as Array).map(func(card: Dictionary) -> String: return str(card.def_id))


func _drawn_ids(log: TestEventLog) -> Array:
	var ids: Array = []
	for event: Dictionary in log.events_since(0):
		if StringName(str(event.type)) == &"card_drawn" and str(event.payload.side) == SIDE_PLAYER:
			ids.append(str(event.payload.card_id))
	return ids


# --- the fixtures are what A4 says they are -------------------------------------

func test_the_two_fixtures_differ_only_in_the_players_hand_and_deck() -> void:
	# Arrange
	var first: Dictionary = BossAiBoard.read(DECOY_A)
	var second: Dictionary = BossAiBoard.read(DECOY_B)
	var a_cards: Array = (first.player_drawn as Array) + (first.player_deck as Array)
	var b_cards: Array = (second.player_drawn as Array) + (second.player_deck as Array)

	# Act
	for key: String in FREE_KEYS:
		first.erase(key)
		second.erase(key)

	# Assert
	assert_str(EventLogAssertions.canonical_json(first)).is_equal(EventLogAssertions.canonical_json(second))
	assert_bool(a_cards.any(func(id: String) -> bool: return b_cards.has(id))).is_false()


func test_a4_the_decoy_hand_is_drawn_through_the_engine_and_is_in_the_log() -> void:
	# Arrange
	var fixture: Dictionary = BossAiBoard.read(DECOY_A)

	# Act
	var board: Dictionary = _board(fixture)

	# Assert
	assert_array(_hand_ids(board.engine)).is_equal(fixture.player_drawn)
	assert_array(_drawn_ids(board.log)).contains(fixture.player_drawn)


# --- A4 --------------------------------------------------------------------------

func test_a4_the_commit_equals_the_forecast_and_x_is_not_played() -> void:
	# Arrange
	var fixture: Dictionary = BossAiBoard.read(DECOY_A)
	var board: Dictionary = _board(fixture)

	# Act
	var played: Dictionary = _play(board)
	var committed: Dictionary = _diagnostics(played.plan, BossAI.EVENT_INTENT_COMMITTED)[0]

	# Assert
	assert_bool(bool(committed.kept)).is_true()
	assert_str(str(committed.intent_key)).is_equal((played.intent as Intent).intent_key)
	assert_bool(_played(played.plan, board, str(fixture.x_card))).is_false()


func test_a4_the_same_spell_played_in_public_does_play_x() -> void:
	# Arrange — the control: the card is revealed, so `aoe_seen` may hold it, and the
	# board that kept X in hand above now plays it
	var fixture: Dictionary = BossAiBoard.read(DECOY_A)
	var board: Dictionary = _board(fixture, [str(fixture.player_drawn[0])])

	# Act
	var played: Dictionary = _play(board)

	# Assert
	assert_bool(_played(played.plan, board, str(fixture.x_card))).is_true()


func test_a4_no_decision_names_a_card_of_the_players() -> void:
	for name: String in [DECOY_A, DECOY_B]:
		# Arrange
		var fixture: Dictionary = BossAiBoard.read(name)
		var board: Dictionary = _board(fixture)

		# Act
		var played: Dictionary = _play(board)
		var text: String = EventLogAssertions.canonical_json((played.plan as TurnPlan).to_dict())
		text += EventLogAssertions.canonical_json((played.intent as Intent).to_dict())
		for scored: String in (board.recorder as ScoreRecorder).scored:
			text += scored

		# Assert
		assert_bool(_diagnostics(played.plan, BossAI.EVENT_DECISION).is_empty()).is_false()
		for def_id: Variant in (fixture.player_drawn as Array) + (fixture.player_deck as Array):
			assert_str(text).not_contains(str(def_id))


func test_a4_the_players_hand_and_deck_leave_the_decisions_byte_identical() -> void:
	# Arrange
	var first: Dictionary = _board(BossAiBoard.read(DECOY_A))
	var second: Dictionary = _board(BossAiBoard.read(DECOY_B))

	# Act
	var plan_a: TurnPlan = _play(first).plan
	var plan_b: TurnPlan = _play(second).plan

	# Assert
	assert_bool(_diagnostics(plan_a, BossAI.EVENT_DECISION).is_empty()).is_false()
	assert_str(_decision_bytes(plan_a)).is_equal(_decision_bytes(plan_b))
	assert_str(EventLogAssertions.canonical_json(plan_a.to_dict())).is_equal(EventLogAssertions.canonical_json(plan_b.to_dict()))


func test_a4_the_players_hand_and_deck_leave_the_forecast_byte_identical() -> void:
	# Arrange — the forecast runs the player's real End step on its clone, so it is
	# held to the same bar as the plan (BAI-011 review, Game-Specific Concerns)
	var first: Dictionary = _board(BossAiBoard.read(DECOY_A))
	var second: Dictionary = _board(BossAiBoard.read(DECOY_B))

	# Act
	var intent_a: Intent = _forecast(first)
	var intent_b: Intent = _forecast(second)

	# Assert
	var scored_a: Array[String] = (first.recorder as ScoreRecorder).scored
	assert_array(scored_a).is_not_empty()
	assert_array(scored_a).is_equal((second.recorder as ScoreRecorder).scored)
	assert_dict(intent_a.to_dict()).is_equal(intent_b.to_dict())
