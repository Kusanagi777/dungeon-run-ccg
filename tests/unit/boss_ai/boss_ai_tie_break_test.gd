## Unit tests for the Boss AI tie-break and its `ai_<floor>` draw accounting
## (story boss-ai-match-driver/story-006, acceptance criteria as amended
## 2026-11-04 per the sprint-4 QA plan; design/gdd/boss-ai.md C9, F8;
## ADR-0003 rule 5; ADR-0006; TR-boss-ai-001).
##
## Streams are `TestRngStream.seeded` (the production generator), so `draws`
## is exact. The board is `tests/fixtures/boss_ai/tie_set_board.json` on the
## production `EffectResolver` ([BossAiBoard]); `tie_epsilon` is read from the
## resolved profile. The per-turn criteria (A3, A5) moved to story 008.
extends GdUnitTestSuite

const SIDE_BOSS: String = MatchRecords.SIDE_BOSS


# --- helpers -----------------------------------------------------------------

func _fixture(single: bool = false) -> Dictionary:
	var fixture: Dictionary = BossAiBoard.read("tie_set_board")
	if single:
		fixture.boss.hand = fixture.single_hand
	return fixture


## The scored candidates of the fixture's boss turn, and the live engine.
func _scored(fixture: Dictionary) -> Array:
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var engine: RulesEngine = BossAiBoard.engine(fixture, db)
	var base: RulesEngine = engine.clone()
	var scored: Array = await Scorer.new(db, BossAiBoard.keyword_values()).score_all(base, base.legal_commands(), BossAiBoard.profile(fixture), Scorer.MODE_NORMAL, {}, ImmediatePlannerTask.new())
	base.end_match()
	return [engine, scored]


func _stream(fixture: Dictionary, index: int) -> TestRngStream:
	return TestRngStream.seeded(str(fixture.ai_stream), int(fixture.ai_seeds[index]))


func _epsilon(fixture: Dictionary) -> float:
	return float(BossAiBoard.profile(fixture).rules.tie_epsilon)


func _entry(score: float, command: Dictionary) -> Dictionary:
	return {"command": command, "score": score, "features": {}}


# --- A2 (amended): size-2 tie set, two seeds -------------------------------------------

func test_size_two_tie_set_picks_differ_across_two_seeds_and_each_draws_once() -> void:
	# Arrange
	var fixture: Dictionary = _fixture()
	var result: Array = await _scored(fixture)
	var scored: Array = result[1]
	var first: TestRngStream = _stream(fixture, 0)
	var second: TestRngStream = _stream(fixture, 1)
	var first_draw: int = _stream(fixture, 0).randi_range(0, 1)
	var second_draw: int = _stream(fixture, 1).randi_range(0, 1)

	# Act
	var a: Dictionary = TieBreak.pick(scored, _epsilon(fixture), first)
	var b: Dictionary = TieBreak.pick(scored, _epsilon(fixture), second)

	# Assert — the fixture's seeds really do draw differently (precondition)
	assert_int(first_draw).override_failure_message("fixture ai_seeds draw alike; pick other seeds").is_not_equal(second_draw)
	assert_int(a.ties.size()).is_equal(int(fixture.expect.tie_size))
	assert_array(a.ties).is_equal(b.ties)
	assert_dict(a.chosen.command).is_not_equal(b.chosen.command)
	assert_dict(a.chosen).is_equal(a.ties[first_draw])
	assert_dict(b.chosen).is_equal(b.ties[second_draw])
	assert_int(first.draws).is_equal(1)
	assert_int(second.draws).is_equal(1)
	assert_int(a.draws).is_equal(1)


func test_size_one_tie_set_is_identical_across_seeds_and_draws_nothing() -> void:
	# Arrange
	var fixture: Dictionary = _fixture(true)
	var result: Array = await _scored(fixture)
	var scored: Array = result[1]
	var first: TestRngStream = _stream(fixture, 0)
	var second: TestRngStream = _stream(fixture, 1)

	# Act
	var a: Dictionary = TieBreak.pick(scored, _epsilon(fixture), first)
	var b: Dictionary = TieBreak.pick(scored, _epsilon(fixture), second)

	# Assert
	assert_int(a.ties.size()).is_equal(1)
	assert_dict(a.chosen.command).is_equal(b.chosen.command)
	assert_dict(a.chosen.command).is_equal(scored[0].command)
	assert_int(first.draws).is_equal(0)
	assert_int(second.draws).is_equal(0)
	assert_int(a.draws).is_equal(0)


# --- per-action draw accounting (amended; replaces A3 / A5 here) --------------------------

func test_one_action_moves_the_ai_stream_by_its_tie_draws_and_never_the_match_stream() -> void:
	# Arrange
	var fixture: Dictionary = _fixture()
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = BossAiBoard.engine(fixture, db, [], log)
	var ai: TestRngStream = _stream(fixture, 0)
	var match_draws: int = engine.rng_match().draws
	var events: int = log.events.size()

	# Act — one decision: score on a clone, then break the tie
	var base: RulesEngine = engine.clone()
	var scored: Array = await Scorer.new(db, BossAiBoard.keyword_values()).score_all(base, base.legal_commands(), BossAiBoard.profile(fixture), Scorer.MODE_NORMAL, {}, ImmediatePlannerTask.new())
	base.end_match()
	var decision: Dictionary = TieBreak.pick(scored, _epsilon(fixture), ai)

	# Assert
	assert_int(ai.draws).is_equal(1 if decision.ties.size() > 1 else 0)
	assert_int(ai.draws).is_equal(int(decision.draws))
	assert_int(engine.rng_match().draws).is_equal(match_draws)
	assert_int(log.events.size()).is_equal(events)


func test_a_turn_fork_label_takes_one_parent_draw_however_often_it_is_forked() -> void:
	# Arrange — ADR-0003 rule 5: one parent draw per new label
	var fixture: Dictionary = _fixture()
	var ai: TestRngStream = _stream(fixture, 0)
	var turn: int = 3

	# Act
	var sim: RngStream = ai.fork(TieBreak.sim_label(turn))
	var again: RngStream = ai.fork(TieBreak.sim_label(turn))
	var after_sim: int = ai.draws
	var forecast: RngStream = ai.fork(TieBreak.forecast_label(turn))
	var next_turn: RngStream = ai.fork(TieBreak.sim_label(turn + 1))

	# Assert
	assert_str(TieBreak.sim_label(turn)).is_equal("sim_3")
	assert_str(TieBreak.forecast_label(turn)).is_equal("forecast_3")
	assert_object(again).is_same(sim)
	assert_int(after_sim).is_equal(1)
	assert_object(forecast).is_not_same(sim)
	assert_object(next_turn).is_not_same(sim)
	assert_int(ai.draws).is_equal(3)


# --- F8 rules -------------------------------------------------------------------------

func test_tie_set_includes_scores_within_epsilon_and_excludes_beyond() -> void:
	# Arrange — boundary values (exact in binary): best 2ε, one at exactly ε below it, one 2ε below
	var fixture: Dictionary = _fixture()
	var epsilon: float = _epsilon(fixture)
	var scored: Array = [
		_entry(epsilon * 2.0, MatchRecords.play_card(SIDE_BOSS, 2, 0, null)),
		_entry(epsilon, MatchRecords.play_card(SIDE_BOSS, 1, 0, null)),
		_entry(0.0, MatchRecords.play_card(SIDE_BOSS, 0, 0, null)),
		_entry(-INF, MatchRecords.end_turn(SIDE_BOSS)),
	]

	# Act
	var ties: Array = TieBreak.tie_set(scored, epsilon)

	# Assert — canonical order: hand_index 1 before 2
	assert_int(ties.size()).is_equal(2)
	assert_int(int(ties[0].command.hand_index)).is_equal(1)
	assert_int(int(ties[1].command.hand_index)).is_equal(2)


func test_canonical_order_is_type_then_hand_attacker_target_position() -> void:
	# Arrange — F8 / C9 canonical command order
	var end_turn: Dictionary = _entry(0.0, MatchRecords.end_turn(SIDE_BOSS))
	var power: Dictionary = _entry(0.0, MatchRecords.use_hero_power(SIDE_BOSS, null))
	var attack_late: Dictionary = _entry(0.0, MatchRecords.attack(SIDE_BOSS, 9, 1))
	var attack_early: Dictionary = _entry(0.0, MatchRecords.attack(SIDE_BOSS, 5, 7))
	var play_target: Dictionary = _entry(0.0, MatchRecords.play_card(SIDE_BOSS, 0, null, 4))
	var play_untargeted: Dictionary = _entry(0.0, MatchRecords.play_card(SIDE_BOSS, 0, null, null))
	var play_right: Dictionary = _entry(0.0, MatchRecords.play_card(SIDE_BOSS, 1, 2, null))
	var play_left: Dictionary = _entry(0.0, MatchRecords.play_card(SIDE_BOSS, 1, 0, null))
	# target_id ranks before position: (target 3, position 1) precedes (target 5, position 0)
	var aimed_low: Dictionary = _entry(0.0, MatchRecords.play_card(SIDE_BOSS, 2, 1, 3))
	var aimed_high: Dictionary = _entry(0.0, MatchRecords.play_card(SIDE_BOSS, 2, 0, 5))

	# Act
	var ordered: Array = TieBreak.sort_canonical([end_turn, power, attack_late, attack_early, aimed_high, play_target, play_untargeted, aimed_low, play_right, play_left])

	# Assert — play_card < attack < use_hero_power < end_turn; nulls before numbers
	assert_array(ordered).is_equal([play_untargeted, play_target, play_left, play_right, aimed_low, aimed_high, attack_early, attack_late, power, end_turn])


func test_pick_on_an_empty_list_chooses_nothing_and_draws_nothing() -> void:
	# Arrange
	var ai: TestRngStream = _stream(_fixture(), 0)

	# Act
	var decision: Dictionary = TieBreak.pick([], 0.0, ai)

	# Assert
	assert_that(decision.chosen).is_null()
	assert_array(decision.ties).is_empty()
	assert_int(ai.draws).is_equal(0)


func test_equal_scored_choose_candidates_sort_by_option_index_whatever_their_input_order() -> void:
	# Arrange — C9 canonical order covers `choose` (code review 2026-11-04, nit N1)
	var options: Array = [2, 0, 1]
	var shuffled: Array = options.map(func(i: int) -> Dictionary: return _entry(1.0, MatchRecords.choose(SIDE_BOSS, i)))
	var reversed: Array = shuffled.duplicate()
	reversed.reverse()

	# Act
	var from_shuffled: Array = TieBreak.sort_canonical(shuffled).map(func(e: Dictionary) -> int: return int(e.command.option_index))
	var from_reversed: Array = TieBreak.sort_canonical(reversed).map(func(e: Dictionary) -> int: return int(e.command.option_index))

	# Assert
	var ascending: Array = options.duplicate()
	ascending.sort()
	assert_array(from_shuffled).is_equal(ascending)
	assert_array(from_reversed).is_equal(ascending)
