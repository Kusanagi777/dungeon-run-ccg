## Unit tests for C1.3 "never reads either `deck` order" on the boss's **real** plan
## (design/gdd/boss-ai.md C1.3; story boss-ai-match-driver/story-012; BAI-007 review
## D-2, BAI-011 review D1).
##
## The forecast keeps undrawn cards out (`boss_ai_forecast_test.gd`, `test_d1_*`). So
## does a real plan's lethal search: a node that draws loses the card, since the boss
## has not drawn it. The test takes one public board with the deck in two orders and
## compares the first decision, which is made before any card leaves the deck, so
## nothing has been drawn that could honestly tell the orders apart. Once a card is
## really drawn the plans may differ: that is
## `test_d1_a_real_plan_keeps_and_plays_the_card_it_draws`.
##
## A one-ply trial is not covered here. An `on_draw` hook fires inside the draw, before
## a card can be dropped, so the trial's C1.3 breach is the owner's design call;
## `tests/fixtures/boss_ai/real_plan_undrawn_card.json` is that board.
extends GdUnitTestSuite

const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const SIDE_BOSS: String = MatchRecords.SIDE_BOSS
const AI_SEED: int = 7
const BOSS_ID: String = "boss_test"
## The `boss.turns_taken` that gives the boss 4 mana: the bolt, then the Charge.
const TURNS_TAKEN: int = 3


## The first `ai_decision` of the real plan of [param fixture] with the boss's deck
## starting [param order].
func _first_decision(fixture: Dictionary, order: Array) -> Dictionary:
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var engine: RulesEngine = BossAiBoard.engine(fixture, db)
	var stub: Dictionary = BossAiBoard.stub_config()
	var band: int = int(fixture.band)
	var stream: RngStream = TestRngStream.seeded("ai_1", AI_SEED)
	var ai: BossAI = BossAI.new(CardFactory.make_boss_def(BOSS_ID, band), BossAiBoard.profile(fixture), band, stream, stub.op_values, null, db, stub.keyword_values)
	assert_bool(engine.submit(MatchRecords.end_turn(SIDE_BOSS)).accepted).is_true()
	var boss: Dictionary = engine.state().players[SIDE_BOSS]
	boss.turns_taken = TURNS_TAKEN
	for index: int in order.size():
		boss.deck[index].def_id = str(order[index])
	assert_bool(engine.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()
	var sandbox: RulesEngine = engine.clone()
	var plan: TurnPlan = await ai.plan_turn(sandbox)
	sandbox.end_match()
	var decisions: Array = plan.diagnostics.filter(func(d: Dictionary) -> bool: return str(d[TurnPlan.EVENT_KEY]) == BossAI.EVENT_DECISION)
	assert_array(decisions).is_not_empty()
	return decisions[0]


func test_c1_3_the_lethal_search_of_a_real_plan_never_reads_an_undrawn_card() -> void:
	# Arrange — one public board: only the Charge under the bolt's draw makes lethal
	var fixture: Dictionary = BossAiBoard.read("forecast_mid_plan_draw")
	var case: Dictionary = fixture.lethal_case
	fixture.boss.board = case.boss_board
	fixture.player.health = case.player_health
	fixture.player.board = case.player_board

	# Act
	var through: Dictionary = await _first_decision(fixture, case.deck_orders[0])
	var without: Dictionary = await _first_decision(fixture, case.deck_orders[1])

	# Assert
	assert_str(EventLogAssertions.canonical_json(through)).is_equal(EventLogAssertions.canonical_json(without))
